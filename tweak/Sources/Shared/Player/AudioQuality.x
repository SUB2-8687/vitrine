// The audio quality badge and its details (AudioQuality.h). No hooks: the looks place the badge, and the player's
// reports come through PlayerState.x.
#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"
#import "AudioQuality.h"
#import "PlayerEvents.h"
#import "PlayerState.h"

// The Music app's badge: semibold caption type in a capsule, a glyph before Lossless.
static const CGFloat kFontSize = 11, kFontMax = 15, kPadX = 7, kPadY = 2, kGlyphGap = 3;
// Kept clear between the badge and either time, and around the badge for a finger.
static const CGFloat kTimeGap = 8, kTouchOutset = 4;
static const NSTimeInterval kFade = 0.25;
static const CGFloat kPanelWidth = 280, kPanelMargin = 16, kPanelRowGap = 10;

// What the badge shows for the song playing, all zero while it shows nothing.
typedef struct {
    SGAudioTier tier;
    SGAudioSource source;
    long long playingHz, hardwareHz;
    BOOL resampled;
} SGQualityShown;

static BOOL sg_on;
static SGQualityShown sg_shown;
// The track sg_shown is for, nil while it shows nothing.
static NSString *sg_shownTrack;
// The duration units laid out while the switch is on, and every badge made, to hide when it goes off.
static NSHashTable<UIView *> *sg_units;
static NSHashTable<UIView *> *sg_badges;
static NSString *sg_loggedFacts;
static char kBadgeKey, kTakeKey, kRemainingKey;

static void checkDetails(void);

static BOOL sameShown(SGQualityShown a, SGQualityShown b) {
    return a.tier == b.tier && a.source == b.source && a.playingHz == b.playingHz && a.hardwareHz == b.hardwareHz
        && a.resampled == b.resampled;
}

#pragma mark - Spotify's report

static long long integerIn(id object, NSString *key) {
    if (![object respondsToSelector:NSSelectorFromString(key)]) return 0;
    id value = [object valueForKey:key];
    return [value isKindOfClass:NSNumber.class] ? [value longLongValue] : 0;
}

// Every field of the report once per change, so the values a song really plays at are in the log.
static void logFacts(NSString *uri, id quality) {
    NSMutableArray<NSString *> *facts = [NSMutableArray arrayWithObject:uri ?: @"no track"];
    for (NSString *key in @[@"bitrateLevel", @"hifiStatus", @"strategy", @"fileOrigin", @"playingSampleRateHz",
                            @"hardwareSampleRateHz", @"isResampled", @"qualityRestrictionReason"]) {
        id value = [quality respondsToSelector:NSSelectorFromString(key)] ? [quality valueForKey:key] : nil;
        [facts addObject:[NSString stringWithFormat:@"%@ %@", key, value ?: @"-"]];
    }
    NSString *line = [facts componentsJoinedByString:@", "];
    if ([line isEqualToString:sg_loggedFacts]) return;
    sg_loggedFacts = line;
    SGLog(@"audio quality: %@", line);
}

static void update(SPTPlayerState *state) {
    SGQualityShown shown = {0};
    NSString *track = nil;
    if (sg_on && state) {
        id quality = [state respondsToSelector:NSSelectorFromString(@"playbackQuality")] ? [state valueForKey:@"playbackQuality"] : nil;
        NSString *uri = SGURIString(state.track.URI);
        logFacts(uri, quality);
        shown.tier = SGAudioTierShown(YES, SGPlayerPlaybackIsLocal(), uri, integerIn(quality, @"bitrateLevel"));
        if (shown.tier != SGAudioTierNone) {
            track = uri;
            shown.source = SGAudioSourceForStrategy(integerIn(quality, @"strategy"));
            shown.playingHz = integerIn(quality, @"playingSampleRateHz");
            shown.hardwareHz = integerIn(quality, @"hardwareSampleRateHz");
            shown.resampled = integerIn(quality, @"isResampled") != 0;
        }
    }
    if (sameShown(shown, sg_shown) && (track == sg_shownTrack || [track isEqualToString:sg_shownTrack])) return;
    sg_shown = shown;
    sg_shownTrack = [track copy];
    checkDetails();
    for (UIView *unit in sg_units.allObjects) [unit setNeedsLayout];
}

static void hideBadge(UIView *badge);

// Every view controller's view on screen that holds the player's times: the looks place the badge from those units'
// layout, which a unit laid out before the switch came on does not run again by itself.
static void layOutUnitsOnScreen(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            SGForEachView(window, ^(UIView *view) {
                if (![view.accessibilityIdentifier isEqualToString:@"now-playing-time-take-label"]) return;
                for (UIView *v = view.superview; v; v = v.superview) {
                    if ([v.nextResponder isKindOfClass:UIViewController.class]) {
                        [v setNeedsLayout];
                        break;
                    }
                }
            });
        }
    }
}

void SGAudioQualitySettingChanged(void) {
    BOOL on = SGFlag(SGKeyPlayerAudioQuality, NO);
    if (on == sg_on) return;
    sg_on = on;
    update(SGPlayerState());
    if (on) {
        layOutUnitsOnScreen();
        return;
    }
    // Off, the looks' layout passes return at once, so the badges go here and the units are forgotten.
    for (UIView *badge in sg_badges.allObjects) hideBadge(badge);
    [sg_units removeAllObjects];
}

@interface SGAudioQualityWatcher : NSObject <SGPlayerStateObserver>
@end

@implementation SGAudioQualityWatcher
- (void)playerStateDidReport:(SPTPlayerState *)state {
    update(state);
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
}
@end

#pragma mark - the details

static NSString *yesNo(BOOL yes) {
    return yes ? SGL(@"player.audio_quality.yes", @"Yes") : SGL(@"player.audio_quality.no", @"No");
}

// The details follow the song they were opened for while it plays (a rate Spotify reports late fills in) and are
// dismissed once they no longer describe it (SGAudioQualityDetailsStay).
@interface SGAudioQualityPanel : UIViewController
@property (nonatomic, copy, readonly) NSString *track;
@property (nonatomic, weak, readonly) UIView *badge;
- (instancetype)initWithTrack:(NSString *)track badge:(UIView *)badge;
- (void)showQuality:(SGQualityShown)shown;
- (void)close;
@end

static __weak SGAudioQualityPanel *sg_panel;

@implementation SGAudioQualityPanel {
    SGQualityShown _shown;
    UIStackView *_stack;
}

- (instancetype)initWithTrack:(NSString *)track badge:(UIView *)badge {
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _track = [track copy];
    _badge = badge;
    _shown = sg_shown;
    return self;
}

- (void)showQuality:(SGQualityShown)shown {
    if (sameShown(shown, _shown)) return;
    _shown = shown;
    if (self.isViewLoaded) [self fill];
}

- (void)close {
    if (self.presentingViewController && !self.isBeingDismissed) [self dismissViewControllerAnimated:YES completion:nil];
}

// A name on the leading side and its value on the trailing one; a row whose value Spotify did not report is left out.
- (UIView *)rowNamed:(NSString *)name value:(NSString *)value {
    if (!value) return nil;
    UILabel *nameLabel = [UILabel new], *valueLabel = [UILabel new];
    nameLabel.text = name;
    nameLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    nameLabel.textColor = UIColor.secondaryLabelColor;
    valueLabel.text = value;
    valueLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]];
    valueLabel.textColor = UIColor.labelColor;
    valueLabel.textAlignment = NSTextAlignmentNatural;
    for (UILabel *label in @[nameLabel, valueLabel]) {
        label.adjustsFontForContentSizeCategory = YES;
        label.numberOfLines = 0;
    }
    [valueLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [nameLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[nameLabel, valueLabel]];
    row.spacing = kPanelMargin;
    row.alignment = UIStackViewAlignmentFirstBaseline;
    row.isAccessibilityElement = YES;
    row.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", name, value];
    return row;
}

- (void)fill {
    for (UIView *row in _stack.arrangedSubviews) [row removeFromSuperview];
    for (UIView *row in [self rows]) [_stack addArrangedSubview:row];
    [_stack setCustomSpacing:kPanelRowGap + 4 afterView:_stack.arrangedSubviews.firstObject];
    CGSize size = [_stack systemLayoutSizeFittingSize:CGSizeMake(kPanelWidth, 0)
                        withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    self.preferredContentSize = CGSizeMake(kPanelWidth, ceil(size.height));
}

- (NSArray<UIView *> *)rows {
    UILabel *title = [UILabel new];
    title.text = SGL(@"player.audio_quality.title", @"Audio Quality");
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    title.textColor = UIColor.labelColor;
    title.adjustsFontForContentSizeCategory = YES;
    title.accessibilityTraits = UIAccessibilityTraitHeader;
    BOOL rates = _shown.playingHz > 0 && _shown.hardwareHz > 0;
    NSMutableArray<UIView *> *rows = [NSMutableArray arrayWithObject:title];
    for (UIView *row in @[
        [self rowNamed:SGL(@"player.audio_quality.quality", @"Quality") value:SGAudioTierName(_shown.tier)] ?: NSNull.null,
        [self rowNamed:SGL(@"player.audio_quality.playing_rate", @"Sample rate") value:SGAudioSampleRateText(_shown.playingHz)] ?: NSNull.null,
        [self rowNamed:SGL(@"player.audio_quality.hardware_rate", @"Output") value:SGAudioSampleRateText(_shown.hardwareHz)] ?: NSNull.null,
        [self rowNamed:SGL(@"player.audio_quality.resampled", @"Resampled") value:rates ? yesNo(_shown.resampled) : nil] ?: NSNull.null,
        [self rowNamed:SGL(@"player.audio_quality.source", @"Source") value:SGAudioSourceName(_shown.source)] ?: NSNull.null,
    ]) {
        if ([row isKindOfClass:UIView.class]) [rows addObject:row];
    }
    return rows;
}

- (void)loadView {
    _stack = [UIStackView new];
    _stack.axis = UILayoutConstraintAxisVertical;
    _stack.spacing = kPanelRowGap;
    _stack.layoutMargins = UIEdgeInsetsMake(kPanelMargin, kPanelMargin, kPanelMargin, kPanelMargin);
    _stack.layoutMarginsRelativeArrangement = YES;
    _stack.backgroundColor = UIColor.clearColor;
    self.view = _stack;
    [self fill];
}
@end

// Whether the badge the details point at is placed and drawn (defined with the badge).
static BOOL badgeShown(UIView *badge);

static void checkDetails(void) {
    SGAudioQualityPanel *panel = sg_panel;
    if (!panel) return;
    if (SGAudioQualityDetailsStay(panel.track, sg_shownTrack, sg_shown.tier, badgeShown(panel.badge))) [panel showQuality:sg_shown];
    else [panel close];
}

#pragma mark - the badge

@class SGAudioQualityBadge;

// The badge's tap. The unit after the times (the controls) overlaps the bottom of their row and lies over it, so a
// touch on the badge lands in that unit's view: the tap sits on the view holding both units, which sees every touch
// in either, and takes only the ones on a badge that draws. The badge itself takes no touches, and the tap cancels
// none of the views under it.
@interface SGAudioQualityTap : UITapGestureRecognizer <UIGestureRecognizerDelegate>
@property (nonatomic, weak) SGAudioQualityBadge *badge;
@end

// Drawn rather than built of labels: a look that walks the time unit's labels (the native look's time font) leaves it be.
@interface SGAudioQualityBadge : UIView
@property (nonatomic) SGAudioTier tier;
// Placed, faded in and fitting between the times.
@property (nonatomic) BOOL shown;
@property (nonatomic, strong) SGAudioQualityTap *tap;
- (void)sg_open;
@end

@implementation SGAudioQualityTap
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
    SGAudioQualityBadge *badge = self.badge;
    return badgeShown(badge) && [badge pointInside:[touch locationInView:badge] withEvent:nil];
}

- (void)sg_tapped {
    [self.badge sg_open];
}
@end

@implementation SGAudioQualityBadge

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.opaque = NO;
    self.backgroundColor = UIColor.clearColor;
    self.contentMode = UIViewContentModeRedraw;
    self.userInteractionEnabled = NO;
    // The player is dark under either look, whatever the system's style.
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    self.accessibilityHint = SGL(@"player.audio_quality.hint", @"Shows the details");
    _tap = [[SGAudioQualityTap alloc] initWithTarget:nil action:nil];
    [_tap addTarget:_tap action:@selector(sg_tapped)];
    _tap.delegate = _tap;
    _tap.badge = self;
    _tap.cancelsTouchesInView = NO;
    return self;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    // The player closing takes the badge out of the window, and its details with it.
    if (!self.window) checkDetails();
}

- (void)setShown:(BOOL)shown {
    _shown = shown;
    self.isAccessibilityElement = shown;
    self.accessibilityElementsHidden = !shown;
}

- (BOOL)accessibilityActivate {
    [self sg_open];
    return YES;
}

- (void)setTier:(SGAudioTier)tier {
    if (tier == _tier) return;
    _tier = tier;
    NSString *name = SGAudioTierName(tier);
    self.accessibilityLabel = name ? [NSString stringWithFormat:SGL(@"player.audio_quality.accessibility", @"Audio quality, %@"), name] : nil;
    [self setNeedsDisplay];
}

- (UIFont *)font {
    return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption2] scaledFontForFont:[UIFont systemFontOfSize:kFontSize weight:UIFontWeightSemibold]
                                                                       maximumPointSize:kFontMax compatibleWithTraitCollection:self.traitCollection];
}

- (UIImage *)glyphIn:(UIFont *)font {
    if (!SGAudioTierIsLossless(_tier)) return nil;
    return [UIImage systemImageNamed:@"waveform" withConfiguration:[UIImageSymbolConfiguration configurationWithFont:font scale:UIImageSymbolScaleSmall]];
}

- (CGSize)sizeThatFits:(CGSize)size {
    UIFont *font = self.font;
    UIImage *glyph = [self glyphIn:font];
    CGFloat text = [SGAudioTierName(_tier) ?: @"" sizeWithAttributes:@{NSFontAttributeName: font}].width;
    CGFloat glyphWidth = glyph ? glyph.size.width + kGlyphGap : 0;
    return CGSizeMake(ceil(2 * kPadX + glyphWidth + text), ceil(font.lineHeight + 2 * kPadY));
}

- (void)drawRect:(CGRect)rect {
    CGRect bounds = self.bounds;
    UITraitCollection *traits = self.traitCollection;
    UIColor *ink = [UIColor.secondaryLabelColor resolvedColorWithTraitCollection:traits];
    [[UIColor.quaternaryLabelColor resolvedColorWithTraitCollection:traits] setFill];
    [[UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:bounds.size.height / 2] fill];

    UIFont *font = self.font;
    NSString *text = SGAudioTierName(_tier) ?: @"";
    NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: ink};
    CGSize textSize = [text sizeWithAttributes:attributes];
    UIImage *glyph = [self glyphIn:font];
    CGFloat glyphWidth = glyph ? glyph.size.width + kGlyphGap : 0;
    CGFloat x = round(CGRectGetMidX(bounds) - (glyphWidth + textSize.width) / 2);
    BOOL rightToLeft = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    CGFloat glyphX = rightToLeft ? x + textSize.width + kGlyphGap : x, textX = rightToLeft ? x : x + glyphWidth;
    if (glyph) {
        CGRect glyphRect = CGRectMake(glyphX, CGRectGetMidY(bounds) - glyph.size.height / 2, glyph.size.width, glyph.size.height);
        [[glyph imageWithTintColor:ink renderingMode:UIImageRenderingModeAlwaysOriginal] drawInRect:glyphRect];
    }
    [text drawAtPoint:CGPointMake(textX, CGRectGetMidY(bounds) - font.lineHeight / 2) withAttributes:attributes];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return CGRectContainsPoint(CGRectInset(self.bounds, -kTouchOutset, -kTouchOutset), point);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if (![previous.preferredContentSizeCategory isEqualToString:self.traitCollection.preferredContentSizeCategory]) {
        [self setNeedsDisplay];
        [self.superview setNeedsLayout];
    }
}

- (void)sg_open {
    if (!badgeShown(self) || sg_shown.tier == SGAudioTierNone || sg_panel) return;
    SGAudioQualityPanel *panel = [[SGAudioQualityPanel alloc] initWithTrack:sg_shownTrack badge:self];
    sg_panel = panel;
    SGPresentPopover(panel, self);
}
@end

static BOOL badgeShown(UIView *view) {
    SGAudioQualityBadge *badge = [view isKindOfClass:SGAudioQualityBadge.class] ? (SGAudioQualityBadge *)view : nil;
    return badge.shown && badge.window && SGAudioQualityViewDrawn((id<SGAudioQualityViewChain>)badge);
}

static void hideBadge(UIView *view) {
    SGAudioQualityBadge *badge = (SGAudioQualityBadge *)view;
    badge.shown = NO;
    badge.alpha = 0;
    checkDetails();
}

#pragma mark - placing it

// Where `view` stands in `unit` with its own transform left out (the redesign lowers the times while a finger scrubs).
static CGRect untransformedIn(UIView *view, UIView *unit) {
    CGSize size = view.bounds.size;
    CGRect frame = CGRectMake(view.center.x - size.width / 2, view.center.y - size.height / 2, size.width, size.height);
    return [view.superview convertRect:frame toView:unit];
}

static BOOL timeShown(UIView *time, UIView *unit) {
    return time.window && time.alpha > 0.01 && SGShownUnder(time, unit);
}

// The scene's orientation, not the size class: a landscape window of regular height (an iPad's) is landscape too.
static BOOL landscape(UIView *view) {
    return UIInterfaceOrientationIsLandscape(view.window.windowScene.interfaceOrientation);
}

void SGAudioQualityPlaceBadge(UIView *unit) {
    // Off, nothing is looked up or remembered; SGAudioQualitySettingChanged hid the badges made before.
    if (!sg_on || !unit) return;
    if (!sg_units) sg_units = [NSHashTable weakObjectsHashTable];
    [sg_units addObject:unit];
    SGAudioQualityBadge *badge = objc_getAssociatedObject(unit, &kBadgeKey);
    SGAudioTier tier = sg_shown.tier;
    if (!badge && tier == SGAudioTierNone) return;
    UIView *take = SGFindIdentifier(unit, @"now-playing-time-take-label", &kTakeKey);
    UIView *remaining = SGFindIdentifier(unit, @"now-playing-time-remaning-label", &kRemainingKey);
    if (!badge) {
        badge = [SGAudioQualityBadge new];
        badge.alpha = 0;
        objc_setAssociatedObject(unit, &kBadgeKey, badge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (!sg_badges) sg_badges = [NSHashTable weakObjectsHashTable];
        [sg_badges addObject:badge];
        SGLog(@"audio quality: a badge in %@, times %@", NSStringFromClass(unit.nextResponder.class), take && remaining ? @"found" : @"not found");
    }
    if (badge.superview != unit) [unit addSubview:badge];
    else if (unit.subviews.lastObject != badge) [unit bringSubviewToFront:badge];
    UIView *units = unit.superview;
    if (badge.tap.view != units) {
        [badge.tap.view removeGestureRecognizer:badge.tap];
        [units addGestureRecognizer:badge.tap];
    }

    BOOL wasShown = badge.alpha > 0;
    BOOL retitled = tier != SGAudioTierNone && tier != badge.tier;
    BOOL shown = tier != SGAudioTierNone && !landscape(unit) && timeShown(take, unit) && timeShown(remaining, unit);
    if (shown) {
        CGRect a = untransformedIn(take, unit), b = untransformedIn(remaining, unit);
        CGRect leading = CGRectGetMidX(a) <= CGRectGetMidX(b) ? a : b, trailing = CGRectGetMidX(a) <= CGRectGetMidX(b) ? b : a;
        // Under the middle of the bar, whose ends the two times line up with.
        CGFloat middle = (CGRectGetMinX(leading) + CGRectGetMaxX(trailing)) / 2;
        CGFloat room = 2 * MIN(middle - CGRectGetMaxX(leading), CGRectGetMinX(trailing) - middle) - 2 * kTimeGap;
        void (^retitle)(void) = ^{
            badge.tier = tier;
            CGSize size = [badge sizeThatFits:CGSizeZero];
            badge.bounds = CGRectMake(0, 0, size.width, size.height);
        };
        if (retitled && wasShown && badge.window) {
            [UIView transitionWithView:badge duration:kFade options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction
                            animations:retitle completion:nil];
        } else {
            retitle();
        }
        CGSize size = badge.bounds.size;
        shown = size.width <= room;
        // Edges on whole points, so the text stays crisp.
        CGPoint origin = CGPointMake(round(middle - size.width / 2), round(CGRectGetMidY(a) - size.height / 2));
        badge.center = CGPointMake(origin.x + size.width / 2, origin.y + size.height / 2);
    }
    badge.shown = shown;
    if (!shown) checkDetails();
    CGFloat alpha = shown ? 1 : 0;
    if (badge.alpha == alpha) return;
    if (!badge.window || UIAccessibilityIsReduceMotionEnabled()) {
        badge.alpha = alpha;
        return;
    }
    [UIView animateWithDuration:kFade delay:0 options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{ badge.alpha = alpha; } completion:nil];
}

UIView *SGAudioQualityShownBadge(UIView *unit) {
    SGAudioQualityBadge *badge = objc_getAssociatedObject(unit, &kBadgeKey);
    return badge.superview == unit && badgeShown(badge) ? badge : nil;
}

static SGAudioQualityWatcher *sg_watcher;

%ctor {
    sg_on = SGFlag(SGKeyPlayerAudioQuality, NO);
    sg_watcher = [SGAudioQualityWatcher new];
    SGAddPlayerStateObserver(sg_watcher);
    // Posted on main (PlayerState.x); another device taking the song over takes the badge away.
    [NSNotificationCenter.defaultCenter addObserverForName:SGPlayerPlaybackLocationDidChangeNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) { update(SGPlayerState()); }];
    // Posted on main as the player opens or closes; the details are only up while it is open.
    [NSNotificationCenter.defaultCenter addObserverForName:SGPlayerTransitionNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) { [sg_panel close]; }];
    // The unit's first layout can come before its times have theirs, and opening the player does not lay the unit
    // out again on its own (seen on an iPhone 13 Pro, 9.1.90): once the player is up, the badge is placed again.
    [NSNotificationCenter.defaultCenter addObserverForName:SGPlayerTransitionEndedNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) {
        if (!sg_on) return;
        for (UIView *unit in sg_units.allObjects) [unit setNeedsLayout];
    }];
}
