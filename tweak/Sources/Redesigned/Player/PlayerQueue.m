// Spotify owns the queue. History is a read-only list above the current song; Up Next keeps
// its existing skip-ahead action. Queue editing and History replay are not offered.
// History adapted from the GPL-3 jadetheda and michaelmelita1 forks.
// Threading: main thread only; Spotify delivers fetches on main.
#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/AutoMix/AutoMixPreview.h"
#import "PlayerMix.h"
#import "PlayerQueue.h"
#import <objc/message.h>

static const NSUInteger kMaxRows = 50;
static const NSUInteger kHistoryRows = 10;
static const CGFloat kBlendPadding = 8, kBlendGap = 6;

// Verified against Spotify 9.1.90's metadata and live runtime. Every optional surface is gated below.
@protocol SGRQueueSnapshot <NSObject>
@property (nonatomic, readonly) SPTPlayerTrack *track;
@property (nonatomic, readonly) NSArray *prevTracks;
@property (nonatomic, readonly) NSArray *nextTracks;
@end
@protocol SGRQueuePlayer <SPTPlayer>
- (void)fetchQueue:(void (^)(id<SGRQueueSnapshot>))callback on:(dispatch_queue_t)queue;
@end

static id queueValue(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    return [object respondsToSelector:selector] ? ((id (*)(id, SEL))objc_msgSend)(object, selector) : nil;
}

static NSArray *trackIdentity(SPTPlayerTrack *track) {
    if (![track isKindOfClass:NSClassFromString(@"SPTPlayerTrack")]) return nil;
    NSString *uri = SGURIString(track.URI), *uid = queueValue(track, @"UID");
    if (!uri.length || ![uid isKindOfClass:NSString.class] || !uid.length) return nil;
    return @[uri, uid, track.provider ?: @""];
}

static NSArray<SPTPlayerTrack *> *queueTracks(NSArray *tracks, NSUInteger limit, BOOL history) {
    NSMutableArray *songs = [NSMutableArray new];
    if (![tracks isKindOfClass:NSArray.class]) return songs;
    for (SPTPlayerTrack *track in tracks) {
        if (![track isKindOfClass:NSClassFromString(@"SPTPlayerTrack")] || !track.trackTitle.length ||
            !SGURIString(track.URI) || (history && ![SGURIString(track.URI) hasPrefix:@"spotify:track:"])) continue;
        [songs addObject:track];
        if (songs.count == limit) break;
    }
    return songs;
}

// The blend from the playing song into `next`; nil when the facts say nothing about that pair.
static NSString *blendInto(SPTPlayerTrack *next) {
    SGTransitionFacts *facts = SGAutoMixCurrentTransition();
    if (!SGRMixShowsQueue() || !facts || !SGRMixTrackIs(SGPlayerState().track, facts.fromURI, facts.fromUID)
        || !SGRMixTrackIs(next, facts.toURI, facts.toUID)) return nil;
    if (facts.kind == SGTransitionKindSpotifyAutomix) return SGL(@"settings.player.queue.blend.spotify", @"Spotify AutoMix");
    SGTransitionSettings settings;
    if (facts.kind != SGTransitionKindCrossfade || !SGTransitionSettingsRead(&settings)) return nil;
    return [NSString stringWithFormat:SGL(@"settings.player.queue.blend.crossfade", @"Crossfade, %ld s"), lround(settings.milliseconds / 1000.0)];
}

// The line over the first row: the merge glyph and the blend's name, read out as the name.
@interface SGRQueueBlendView : UIView
@property (nonatomic, readonly) UILabel *label;
@end

@implementation SGRQueueBlendView {
    UIImageView *_glyph;
}

- (instancetype)init {
    if (!(self = [super initWithFrame:CGRectZero])) return nil;
    _glyph = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.triangle.merge"]];
    _glyph.tintColor = SGRSecondary();
    _glyph.contentMode = UIViewContentModeScaleAspectFit;
    _label = [UILabel new];
    _label.textColor = SGRSecondary();
    _label.numberOfLines = 0;
    [self addSubview:_glyph];
    [self addSubview:_label];
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitStaticText;
    [self takeFont];
    return self;
}

- (void)takeFont {
    _label.font = SGCategoryCappedFont(UIFontTextStyleFootnote, UIFontWeightRegular, UIContentSizeCategoryAccessibilityMedium);
    _glyph.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithFont:_label.font];
}

- (void)setText:(NSString *)text {
    _label.text = text;
    self.accessibilityLabel = text;
    [self setNeedsLayout];
}

- (CGFloat)glyphWidth {
    return ceil(_glyph.intrinsicContentSize.width);
}

- (CGFloat)heightForWidth:(CGFloat)width {
    CGFloat text = width - self.layoutMargins.left - self.layoutMargins.right - [self glyphWidth] - kBlendGap;
    return ceil([_label sizeThatFits:CGSizeMake(text, CGFLOAT_MAX)].height) + 2 * kBlendPadding;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat x = self.layoutMargins.left, glyph = [self glyphWidth];
    CGFloat width = self.bounds.size.width - x - self.layoutMargins.right - glyph - kBlendGap;
    CGFloat height = ceil([_label sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    _glyph.frame = CGRectMake(x, kBlendPadding, glyph, _label.font.lineHeight);
    _label.frame = CGRectMake(x + glyph + kBlendGap, kBlendPadding, width, height);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    [self takeFont];
}

@end

// What a row shows, so a report that changed nothing in the list leaves it alone.
static NSArray<NSString *> *signatureOf(NSArray<SPTPlayerTrack *> *tracks) {
    NSMutableArray<NSString *> *signature = [NSMutableArray arrayWithCapacity:tracks.count];
    for (SPTPlayerTrack *track in tracks) {
        [signature addObject:[NSString stringWithFormat:@"%@\t%@\t%@\t%@", trackIdentity(track), SGURIString(track.URI), track.trackTitle, track.artistName ?: @""]];
    }
    return signature;
}

@interface SGRPlayerQueueController : UITableViewController <SGPlayerStateObserver>
@end

@implementation SGRPlayerQueueController {
    NSArray<SPTPlayerTrack *> *_tracks;
    NSArray *_signature;
    NSArray<SPTPlayerTrack *> *_history;
    SPTPlayerTrack *_current;
    NSArray *_reportedKey;
    BOOL _fetching;
    UILabel *_empty;
    SGRQueueBlendView *_blend;
    UIView *_upNextHeader;
    UILabel *_upNextTitle;
}

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = SGL(@"settings.player.queue.title", @"Playing Next");
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                                                         target:self action:@selector(close)];
    // From iOS 26 a sheet short of full height is Liquid Glass the system draws; a fill here would cover it.
    if (@available(iOS 26.0, *)) self.tableView.backgroundColor = UIColor.clearColor;
    _empty = [UILabel new];
    _empty.text = SGL(@"settings.player.queue.empty", @"Nothing is playing next.");
    _empty.font = SGCategoryCappedFont(UIFontTextStyleBody, UIFontWeightRegular, UIContentSizeCategoryAccessibilityMedium);
    _empty.textColor = SGRSecondary();
    _empty.textAlignment = NSTextAlignmentCenter;
    _empty.numberOfLines = 0;
    _blend = [SGRQueueBlendView new];
    _upNextHeader = [UIView new];
    _upNextTitle = [UILabel new];
    _upNextTitle.text = SGL(@"settings.player.queue.up_next", @"Up Next");
    _upNextTitle.textColor = SGRSecondary();
    [_upNextHeader addSubview:_upNextTitle];
    [_upNextHeader addSubview:_blend];
    self.tableView.accessibilityIdentifier = @"vitrine.queue";
    [self takeState:SGPlayerState()];
    SGAddPlayerStateObserver(self);
    // Both are posted on the main thread.
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    [center addObserver:self selector:@selector(showBlend) name:SGAutoMixTransitionDidChangeNotification object:nil];
    [center addObserver:self selector:@selector(showBlend) name:SGAutoMixPlayerOptionsDidChangeNotification object:nil];
}

// Only the upcoming section owns the transition from current to next, never History.
- (void)showBlend {
    NSString *text = blendInto(_tracks.firstObject);
    if (_blend.label.text == text || [_blend.label.text isEqualToString:text]) return;
    [_blend setText:text];
    [self fitBlend];
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
}

- (void)fitBlend {
    UITableView *table = self.tableView;
    CGFloat width = table.bounds.size.width;
    _blend.layoutMargins = UIEdgeInsetsMake(0, table.layoutMargins.left + SGRGrid * 2, 0, table.layoutMargins.right);
    _upNextTitle.font = SGCategoryCappedFont(UIFontTextStyleHeadline, UIFontWeightSemibold, UIContentSizeCategoryAccessibilityMedium);
    CGFloat left = _blend.layoutMargins.left;
    CGFloat heading = ceil(_upNextTitle.font.lineHeight) + 2 * kBlendPadding;
    _upNextTitle.frame = CGRectMake(left, kBlendPadding, width - left - table.layoutMargins.right, heading - 2 * kBlendPadding);
    BOOL showsBlend = _blend.label.text.length > 0;
    CGFloat blendHeight = showsBlend ? [_blend heightForWidth:width] : 0;
    _blend.hidden = !showsBlend;
    _blend.frame = CGRectMake(0, heading, width, blendHeight);
    _upNextHeader.frame = (CGRect){_upNextHeader.frame.origin, CGSizeMake(width, heading + blendHeight)};
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self fitBlend];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    _empty.font = SGCategoryCappedFont(UIFontTextStyleBody, UIFontWeightRegular, UIContentSizeCategoryAccessibilityMedium);
}

#pragma mark - the player

- (void)takeState:(SPTPlayerState *)state {
    if (!queueValue(state, @"queueRevision") || ![SGPlayerInstance() respondsToSelector:@selector(fetchQueue:on:)]) {
        [self showTracks:SGPlayerUpcomingTracks(state, kMaxRows)
                   past:[state.reverse isKindOfClass:NSArray.class] ? state.reverse.reverseObjectEnumerator.allObjects : @[]
                current:state.track];
        return;
    }
    NSArray *key = @[queueValue(state, @"playbackId") ?: NSNull.null,
                     queueValue(state, @"queueRevision") ?: NSNull.null,
                     trackIdentity(state.track) ?: SGURIString(state.track.URI) ?: @""];
    if ([_reportedKey isEqual:key]) return;
    if (_fetching) return;
    _reportedKey = key;
    [self refreshQueue];
}

- (void)showTracks:(NSArray *)next past:(NSArray *)past current:(SPTPlayerTrack *)current {
    _tracks = queueTracks(next, kMaxRows, NO);
    NSArray *history = queueTracks(past, NSUIntegerMax, YES);
    _history = history.count > kHistoryRows ? [history subarrayWithRange:NSMakeRange(history.count - kHistoryRows, kHistoryRows)] : history;
    _current = current;
    NSArray *signature = @[signatureOf(_history), signatureOf(current ? @[current] : @[]), signatureOf(_tracks)];
    if (![_signature isEqual:signature]) {
        _signature = signature;
        self.tableView.backgroundView = _tracks.count || _history.count || current ? nil : _empty;
        [self.tableView reloadData];
    }
    [self showBlend];
}

- (void)refreshQueue {
    id<SGRQueuePlayer> player = SGPlayerInstance();
    SPTPlayerState *state = SGPlayerState();
    [self showTracks:SGPlayerUpcomingTracks(state, kMaxRows)
               past:[state.reverse isKindOfClass:NSArray.class] ? state.reverse.reverseObjectEnumerator.allObjects : @[]
            current:state.track];
    if (![player respondsToSelector:@selector(fetchQueue:on:)]) return;
    _fetching = YES;
    NSArray *reported = _reportedKey;
    __weak typeof(self) weakSelf = self;
    [player fetchQueue:^(id<SGRQueueSnapshot> queue) {
        typeof(self) self = weakSelf;
        if (!self) return;
        self->_fetching = NO;
        if (![queue respondsToSelector:@selector(nextTracks)] || ![queue respondsToSelector:@selector(prevTracks)] ||
            ![queue respondsToSelector:@selector(track)] ||
            (queue.nextTracks && ![queue.nextTracks isKindOfClass:NSArray.class]) ||
            (queue.prevTracks && ![queue.prevTracks isKindOfClass:NSArray.class])) return;
        [self showTracks:queue.nextTracks past:queue.prevTracks current:queue.track];
        // A report received while fetching must not be lost.
        if ([self->_reportedKey isEqual:reported]) [self takeState:SGPlayerState()];
    } on:dispatch_get_main_queue()];
}

- (void)playerStateDidReport:(SPTPlayerState *)state {
    if (self.isViewLoaded) [self takeState:state];
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    if (self.isViewLoaded) [self takeState:state];
}

#pragma mark - the list

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table { return 3; }

- (UIView *)tableView:(UITableView *)table viewForHeaderInSection:(NSInteger)section {
    if (section != 2 || !_tracks.count) return nil;
    [self fitBlend];
    return _upNextHeader;
}

- (CGFloat)tableView:(UITableView *)table heightForHeaderInSection:(NSInteger)section {
    if (section != 2 || !_tracks.count) return UITableViewAutomaticDimension;
    [self fitBlend];
    return _upNextHeader.bounds.size.height;
}

- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return _history.count ? SGL(@"settings.player.queue.history", @"History") : nil;
    if (section == 1) return _current ? SGL(@"settings.player.queue.now", @"Now Playing") : nil;
    return _tracks.count ? SGL(@"settings.player.queue.up_next", @"Up Next") : nil;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? (NSInteger)_history.count : section == 1 ? (_current ? 1 : 0) : (NSInteger)_tracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"track"]
        ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"track"];
    cell.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    SPTPlayerTrack *track = path.section == 0 ? _history[(NSUInteger)path.row] : path.section == 1 ? _current : _tracks[(NSUInteger)path.row];
    NSString *title = track.trackTitle, *artist = track.artistName.length ? track.artistName : nil;
    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = title;
    content.secondaryText = artist;
    content.textProperties.color = SGRPrimary();
    content.textProperties.font = SGCategoryCappedFont(UIFontTextStyleBody, UIFontWeightRegular, UIContentSizeCategoryAccessibilityMedium);
    content.textProperties.numberOfLines = 1;
    content.secondaryTextProperties.color = SGRSecondary();
    content.secondaryTextProperties.font = SGCategoryCappedFont(UIFontTextStyleSubheadline, UIFontWeightRegular, UIContentSizeCategoryAccessibilityMedium);
    content.secondaryTextProperties.numberOfLines = 1;
    cell.contentConfiguration = content;
    cell.isAccessibilityElement = YES;
    cell.accessibilityLabel = artist ? [NSString stringWithFormat:@"%@, %@", title, artist] : title;
    BOOL playable = path.section == 2;
    cell.accessibilityTraits = playable ? UIAccessibilityTraitButton : UIAccessibilityTraitStaticText;
    cell.selectionStyle = playable ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section != 2 || path.row < 0 || path.row >= (NSInteger)_tracks.count) return;
    id<SPTPlayer> player = SGPlayerInstance();
    if (![player respondsToSelector:@selector(skipToNextTrackWithOptions:track:)]) return;
    [player skipToNextTrackWithOptions:nil track:_tracks[(NSUInteger)path.row]];
    [self close];
}

@end

#pragma mark - opening it

// The controller on top in `from`'s window, through whatever is presented over it; the key window's without one.
static UIViewController *topIn(UIView *from) {
    UIViewController *top = from.window.rootViewController;
    if (!top) return SGTopController();
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed) top = top.presentedViewController;
    return top;
}

void SGRPlayerShowQueue(UIView *from) {
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:[SGRPlayerQueueController new]];
    navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    SGPresentDark(navigation);
    UISheetPresentationController *sheet = navigation.sheetPresentationController;
    sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent, UISheetPresentationControllerDetent.largeDetent];
    sheet.prefersGrabberVisible = YES;
    sheet.prefersEdgeAttachedInCompactHeight = YES;
    sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
    // Picked from the system menu, which is still going away: the sheet waits for it, as the sound panel does.
    __weak UIView *weakFrom = from;
    __block int tries = 0;
    __block void (^present)(void);
    present = ^{
        UIViewController *top = topIn(weakFrom);
        if ((top.isBeingDismissed || top.isBeingPresented || top.transitionCoordinator) && ++tries < 20) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), present);
            return;
        }
        present = nil;
        if (!top) return;
        if ([top isKindOfClass:UINavigationController.class]
            && [((UINavigationController *)top).viewControllers.firstObject isKindOfClass:SGRPlayerQueueController.class]) return;
        [top presentViewController:navigation animated:YES completion:nil];
    };
    dispatch_async(dispatch_get_main_queue(), present);
}
