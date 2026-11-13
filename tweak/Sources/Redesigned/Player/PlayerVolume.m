// Player redesign: a volume slider under the controls, as the Music app has. It is MPVolumeView, as the HIG asks
// (sliders.md, playing-audio.md) for local playback, unchanged. On a supported Connect device a matching slider
// uses Spotify's volume service (PlayerConnectVolume.x). No route button: the footer's Connect glyph is the route.
//
// It sits in Spotify's bottom stack, outside its arranged views, between the controls and the footer row, so the
// lyrics fade it with the rest of the stack (PlayerLyrics.x) and its touches stay inside the stack. The footer's
// lowerRow (PlayerFooter.x) places it after the moves, and keeps the controls where Spotify put them to make the room.
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Player.h"
#import "PlayerConnectVolume.h"
#import "Shared/Haptics/Haptics.h"

// The track's height, the glyphs' point size and the gap between a glyph and the track.
static const CGFloat kRowHeight = 34, kGlyphSize = 13, kGlyphGap = 10, kTrack = 4;
// Half the footer glyphs' height: the row stops this far above their middle.
static const CGFloat kGlyphsHalf = 14;

// iOS 26's thumbless slider is the one the progress bar above and the Music app's volume use: it grows under the finger
// and drags from anywhere on the track. MPVolumeView makes its slider when it lays out and may make another later, so
// the style goes on after each of its layouts.
@interface SGRVolumeView : MPVolumeView
@end

@implementation SGRVolumeView

- (void)layoutSubviews {
    [super layoutSubviews];
    for (UISlider *slider in self.subviews) {
        if ([slider isKindOfClass:UISlider.class]) SGInstallVolumeFeedback(slider);
    }
    if (@available(iOS 26.0, *)) {
        for (UISlider *slider in self.subviews) {
            if (![slider isKindOfClass:UISlider.class] || slider.sliderStyle == UISliderStyleThumbless) continue;
            slider.sliderStyle = UISliderStyleThumbless;
            slider.minimumTrackTintColor = UIColor.whiteColor;
            slider.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.22];
        }
    }
    // The row's glyphs follow the slider, which this layout may have made or moved.
    [self.superview setNeedsLayout];
}

@end

@interface SGRVolumeRow : UIView
@end

@implementation SGRVolumeRow {
    MPVolumeView *_volume;
    UISlider *_remote;
    UIImageView *_quiet, *_loud;
}

static UIImage *trackImage(UIColor *color) {
    CGFloat side = kTrack;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side)];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [color setFill];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, side, side) cornerRadius:side / 2] fill];
    }];
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(0, side / 2, 0, side / 2)];
}

static UIImage *thumbImage(void) {
    CGFloat side = 14;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [UIColor.whiteColor setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, side, side)] fill];
    }];
}

static UIImageView *glyph(NSString *symbol) {
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:kGlyphSize weight:UIImageSymbolWeightSemibold];
    UIImageView *view = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol withConfiguration:configuration]];
    view.tintColor = [UIColor colorWithWhite:1 alpha:0.6];
    view.contentMode = UIViewContentModeCenter;
    view.isAccessibilityElement = NO;
    return view;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _volume = [SGRVolumeView new];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    _volume.showsRouteButton = NO;
#pragma clang diagnostic pop
    if (@available(iOS 26.0, *)) {
    } else {
        [_volume setMinimumVolumeSliderImage:trackImage(UIColor.whiteColor) forState:UIControlStateNormal];
        [_volume setMaximumVolumeSliderImage:trackImage([UIColor colorWithWhite:1 alpha:0.22]) forState:UIControlStateNormal];
        [_volume setVolumeThumbImage:thumbImage() forState:UIControlStateNormal];
    }
    _quiet = glyph(@"speaker.fill");
    _loud = glyph(@"speaker.wave.3.fill");
    [self addSubview:_quiet];
    [self addSubview:_volume];
    [self addSubview:_loud];
    _remote = [UISlider new];
    _remote.minimumTrackTintColor = UIColor.whiteColor;
    _remote.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.22];
    if (@available(iOS 26.0, *)) _remote.sliderStyle = UISliderStyleThumbless;
    else {
        [_remote setMinimumTrackImage:trackImage(UIColor.whiteColor) forState:UIControlStateNormal];
        [_remote setMaximumTrackImage:trackImage([UIColor colorWithWhite:1 alpha:0.22]) forState:UIControlStateNormal];
        [_remote setThumbImage:thumbImage() forState:UIControlStateNormal];
    }
    _remote.accessibilityLabel = SGL(@"player.volume", @"Volume");
    SGInstallVolumeFeedback(_remote);
    [_remote addTarget:self action:@selector(remoteChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:_remote];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVolume)
        name:SGRConnectVolumeChangedNotification object:nil];
    [self refreshVolume];
    return self;
}

- (void)refreshVolume {
    double value;
    BOOL remote = SGRConnectReadVolume(&value);
    _remote.hidden = !remote;
    _volume.hidden = remote;
    if (remote && !_remote.tracking) _remote.value = value;
}

- (void)remoteChanged:(UISlider *)slider {
    if (!SGRConnectSetVolume(slider.value)) [self refreshVolume];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    CGFloat side = kRowHeight, middle = CGRectGetMidY(bounds);
    CGFloat left = side / 2 + kGlyphSize / 2 + kGlyphGap, right = CGRectGetMaxX(bounds) - side / 2 - kGlyphSize - kGlyphGap;
    // MPVolumeView draws its slider at the top of its bounds, not in the middle: it gets the slider's own height,
    // centered, so the track lines up with the glyphs (it sat 9pt above them).
    CGFloat sliderHeight = MIN(side, [_volume sizeThatFits:CGSizeMake(MAX(0, right - left), side)].height ?: side);
    _volume.frame = CGRectMake(left, round(middle - sliderHeight / 2), MAX(0, right - left), sliderHeight);
    _remote.frame = _volume.frame;
    // MPVolumeView places its slider off its own middle (8pt above it on iOS 26, issue #86) and the track is centered
    // in the slider, so the glyphs stand on the slider's middle.
    CGFloat glyphs = middle;
    for (UISlider *slider in _volume.subviews) {
        if ([slider isKindOfClass:UISlider.class]) glyphs = CGRectGetMidY([_volume convertRect:slider.frame toView:self]);
    }
    _quiet.frame = CGRectMake(0, glyphs - side / 2, side / 2 + kGlyphSize / 2, side);
    _loud.frame = CGRectMake(CGRectGetMaxX(bounds) - side / 2 - kGlyphSize, glyphs - side / 2, side / 2 + kGlyphSize, side);
}

@end

static char kVolumeKey, kPlayKey, kSettleKey;
// Passes the footer's layout is asked for again while the row's place keeps changing, at most.
static const NSUInteger kSettlePasses = 6;

// Read at launch, as the player's other switches are: the footer asks on every layout pass.
BOOL SGRPlayerVolumeOn(void) {
    static BOOL on;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ on = SGEnabled(SGRKeyPlayerVolume); });
    return on;
}

// The footer lays out before Spotify's bottom stack has arranged its views the first time the player opens (the
// controls then stand near the stack's top), and nothing lays the footer out again once the stack has: the row was
// placed against the controls' old place and stayed there, over their buttons. A row that moved asks the footer's
// layout once more on the next turn of the run loop, which finds the settled places; one that did not move ends it.
static void settle(UIView *stack, UIView *row, BOOL moved, CGRect frame) {
    NSUInteger passes = [objc_getAssociatedObject(stack, &kSettleKey) unsignedIntegerValue];
    if (!moved) {
        if (passes) objc_setAssociatedObject(stack, &kSettleKey, @0, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (passes >= kSettlePasses) return;
    objc_setAssociatedObject(stack, &kSettleKey, @(passes + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (passes > 0) SGLog(@"redesign player: volume row placed again at %.0f (pass %lu)", frame.origin.y, (unsigned long)passes + 1);
    __weak UIView *weakStack = stack, *weakRow = row;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *settledStack = weakStack, *settledRow = weakRow;
        if (!settledStack.window || !settledRow.window) return;
        [settledStack layoutIfNeeded];
        SGRPlayerLowerRow(settledRow);
    });
}

BOOL SGRPlayerPlaceVolume(UIView *stack, UIView *controls, UIView *row, CGFloat margin) {
    SGRVolumeRow *volume = objc_getAssociatedObject(stack, &kVolumeKey);
    if (!SGRPlayerVolumeOn() || !controls) {
        SGRPlayerLyricsFadeView(volume, NO);
        return NO;
    }
    if (!volume) {
        volume = [SGRVolumeRow new];
        objc_setAssociatedObject(stack, &kVolumeKey, volume, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (volume.superview != stack) [stack addSubview:volume];
    // Halfway between the play button's bottom and the footer glyphs' top, each where it is drawn (convertRect: takes
    // the moves' transforms in). Without the button there is nothing to stand under: a guess from the controls' unit
    // put the row across the buttons on an iPhone 13 Pro with iOS 17 (issue #32) and took their taps, so no row.
    UIView *play = SGRFindByIdentifier(controls, @"SPTNowPlayingPlayButton", &kPlayKey);
    if (!play) {
        static BOOL logged;
        if (!logged) {
            logged = YES;
            SGLog(@"redesign player: no play button in %@, so no volume row", NSStringFromClass(controls.class));
        }
        SGRPlayerLyricsFadeView(volume, NO);
        return NO;
    }
    CGFloat above = CGRectGetMaxY([play convertRect:play.bounds toView:stack]);
    CGFloat below = [row convertPoint:CGPointMake(CGRectGetMidX(row.bounds), CGRectGetMidY(row.bounds)) toView:stack].y - kGlyphsHalf;
    CGFloat height = kRowHeight, room = below - above;
    CGRect frame = CGRectMake(margin, round((above + below - height) / 2), MAX(0, stack.bounds.size.width - 2 * margin), height);
    BOOL moved = !CGRectEqualToRect(volume.frame, frame);
    if (moved) volume.frame = frame;
    settle(stack, row, moved, frame);
    // The lyrics fade the stack's views by their alpha and bring back only the ones they faded.
    // The track and thumb are 14pt of the row's 34: it fits with the glyphs' and buttons' own clearance around it.
    BOOL fits = room >= height * 0.6;
    // A track change lays the stack out again while the lines are alone: the row must stay away from them until
    // the fade lets it go, rather than be shown here over the lyrics.
    BOOL faded = SGRPlayerLyricsFadeView(volume, fits);
    if (!faded && volume.alpha < 0.01 && controls.alpha > 0.99) volume.alpha = 1;
    return fits;
}
