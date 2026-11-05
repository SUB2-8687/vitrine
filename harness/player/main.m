// A mock of Spotify's full screen player under its own class names and accessibility identifiers, built
// from trees/clean/player/01.txt, so Redesigned/Player's lyrics state can be laid out, animated and
// looked at on the Mac. Tapping the lyrics glyph in the footer works exactly as it does on the phone;
// the harness also toggles it once by itself so a screenshot catches each state.
//
// HARNESS_SCENARIO (simctl launch passes it as SIMCTL_CHILD_HARNESS_SCENARIO) picks what it does:
//     lyrics   (default) the lyrics opened at 2 s, closed at 6, opened again at 10
//     look     one track playing, a second one from another album at 8 s, nothing opened
//     scroll   the list moved up and down in code; the log says whether it stayed at its top, then a scrub of
//              the progress bar begun and ended in code; the log says whether it held the list's pan
//     cover    the lyric preview given room under a smaller cover, as Spotify lays a track with lyrics out;
//              the log says whether the cover took that room back, PASS or FAIL
//     immersive the lyrics left alone: what fades, where the lines go, the tap that brings the controls
//              back, a scroll and the thumbnail; the log says PASS or FAIL
//     artwork  issue #58: tracks change while the covers on screen and the picture server lag behind,
//              checked by color at the end of each step; the log says PASS or FAIL
//     landscape the landscape lyrics at 3 s, a line's meanings over them, a pause and a resume; each
//              step logs whether the controls are up and what a touch on the lines lands on
//     motion   Animated artwork: a clip (HARNESS_CANVAS_FILE, an mp4) that comes in before the player has
//              laid out, then the field, the lyrics, a field built again, the menu's switch and the player
//              closed, each step checked; the log ends with motion checks n of m right -- PASS or FAIL
//     still    Animated's full-screen cover for a track with no clip: off first, then on, the 300 px rule, a late
//              cover, two quick skips, a late clip, black, the photo, the Visualizer and Low Power Mode; the log ends
//              with still checks n of m right -- PASS or FAIL
//     catalog  Apple Music's catalog behind a stub: the search term without the edition, the album of the same
//              name first, and the pause after a 429; the log says PASS or FAIL
//     settings the redesign's Player page (PlayerSettings.m) over the player with the clip of `motion`: Song
//              without a clip read from its two switches and each choice leaving the other off, the card pinned
//              and shrinking as the rows scroll, its demo, the card refreshed for another track with late clips
//              dropped, paused while covered and stopped once closed, the Buttons chips, the card and the chips
//              whole at narrow widths and the largest text, and no command sent to the player; the log ends
//              with settings checks n of m right -- PASS or FAIL, and the app exits with it
//     preview  the Player page's card picking Animated while the player has no clip (the background Still at
//              launch): the card looks the track's clip up itself, shows Fluid until it comes in 2 s late, then
//              the clip; the clip is in the store for the player, and asked for only while the page shows;
//              the log ends with preview checks n of m right -- PASS or FAIL
//     visualiser the Visualizer background (PlayerVisualiser.m) fed a song of the harness's own (stubs.m):
//              the hills moving, blurred behind the lyrics, settling and stopping on a pause, back on play,
//              and the ⋯ menu's switch to Fluid and back; the log ends with visualizer checks n of m right
//              -- PASS or FAIL
//     autoviz  Animated with "Visualizer when there's no clip": nothing while a lookup is out, the Visualizer
//              once it found no clip, down for a track change, a late clip, Low Power Mode, the full-screen cover
//              switch (each switches the other off), Fluid and black, and off again; needs HARNESS_CANVAS_FILE (an
//              mp4 taller than wide) for the late clip; the log ends with autoviz checks n of m right -- PASS or FAIL
//     shuffle  Shuffle styles: one pick per new track while the Visualizer is on screen (as the background, then as
//              the stand-in for a missing clip), none while hidden or for the same track, the user's own style back
//              when it is switched off; the log ends with shuffle checks n of m right -- PASS or FAIL
//     heat     Ignore heat warnings: the stand-down for each thermal state with and without it, the hills stopping and
//              moving on the switch, Low Power Mode still stopping them, and the stand-in for a missing clip; the log
//              ends with heat checks n of m right -- PASS or FAIL
//     options  the Player page's Header glass and Music app icons switched off and on with the player open, in it and
//              the AI DJ's, then Fluid's Grain at 0, 100 and 200% on Smooth and on Light; the log ends with options
//              checks n of m right -- PASS or FAIL
//     renderer the switch from Smooth to Light, read 0.2 to 4 s after it, five times; renderer checks n of m right
//     automix  AutoMix's transitions in the progress bar, the queue and the cover, and the AutoMix page's preview
//              (automix-scenario.m); automix checks n of m right -- PASS or FAIL, and the app exits with it
// HARNESS_VOLUME=0 leaves out the volume row the phone has (trees/clean/player/01.txt has none).
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <stdlib.h>
#import "Shared/Lyrics/Lyrics.h"
#import "Redesigned/Player/Player.h"
#import "Redesigned/Kit/SGRGlyph.h"
#import "Shared/AnimatedArtwork/AnimatedArtwork.h"
#import "Redesigned/Kit/SGRBridges.h"
#import "Redesigned/Kit/SGRField.h"
#import "Redesigned/Kit/SGRPalette.h"
#import "Redesigned/Lyrics/MeaningSheet.h"
#import "Redesigned/Lyrics/SGRKaraokeView.h"
#import "Core/SGPrefs.h"
#import "Redesigned/Kit/SGRFluid.h"
#import "Settings/SGModPage.h"
#import "Shared/Player/PlayerSettings.h"
#import "Shared/Player/PlayerState.h"
#import "Shared/Player/SGLastTrack.h"
#import "Redesigned/Kit/SGRRefinements.h"

@interface SGRPlayerMotionView : UIView
- (void)playFile:(NSURL *)file poster:(UIImage *)poster;
@end

void SGRHarnessPlayFrom(NSInteger ms);
void SGRHarnessSetTrack(NSString *uri, NSString *imageURI, BOOL paused);
// stubs.m: every clip lookup answers this many seconds late (0, the default, at once).
void SGRHarnessSetLookupDelay(NSTimeInterval seconds);
void SGRHarnessClearTrack(void);
// ../tabbar/touch.m: a finger's touches, through UIKit's own recognizers.
extern void SGHarnessHold(UIWindow *window, CGPoint point, NSTimeInterval seconds);
extern void SGHarnessTap(UIWindow *window, CGPoint point);
// stubs.m: the commands sent to the player.
NSUInteger SGRHarnessPlayerCommands(void);
// stubs.m: the last spotify: URI the mod asked Spotify's link dispatcher to open.
extern NSURL *SGRHarnessLastOpened;
// Low Power Mode as the process reports it, once reportPower has made it report this.
static BOOL sg_lowPower;
static void reportPower(void);

static NSString *scenario(void) {
    const char *value = getenv("HARNESS_SCENARIO");
    return value ? @(value) : @"lyrics";
}

#pragma mark - the picture server

// i.scdn.co as the harness wants it: each picture by the last 24 digits of its id, served after a delay
// of its own, or failed as if the phone were offline.
@interface SGRHarnessPicture : NSObject
@property (nonatomic, strong) UIImage *image;
@property (nonatomic) NSTimeInterval delay;
@property (nonatomic) BOOL fails;
@end
@implementation SGRHarnessPicture
@end

static NSMutableDictionary<NSString *, SGRHarnessPicture *> *sg_pictures;
static NSUInteger sg_served;
// How many times the clip itself was served.
static NSUInteger sg_canvasServed;
// The catalog scenario's Apple Music: the addresses asked, in order, what it answers, and the clips' playlists
// asked for after it.
static NSMutableArray<NSURL *> *sg_catalogAsked, *sg_canvasAsked;
static NSInteger sg_catalogStatus = 200;
static NSData *sg_catalogBody;

static void serve(NSString *imageURI, UIImage *image, NSTimeInterval delay, BOOL fails) {
    if (!sg_pictures) sg_pictures = [NSMutableDictionary dictionary];
    SGRHarnessPicture *picture = [SGRHarnessPicture new];
    picture.image = image;
    picture.delay = delay;
    picture.fails = fails;
    sg_pictures[[imageURI substringFromIndex:imageURI.length - 24]] = picture;
}

// For the automix scenario (automix-scenario.m).
void SGRHarnessServe(NSString *imageURI, UIImage *image) { serve(imageURI, image, 0, NO); }
void SGRHarnessRunAutoMix(UIWindow *window, UIViewController *durationUnit, UIView *tilt);

@interface SGRHarnessPictureServer : NSURLProtocol
@end

@implementation SGRHarnessPictureServer {
    BOOL _stopped;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ([request.URL.host isEqualToString:@"amp-api.music.apple.com"]) return sg_catalogAsked != nil;
    return [request.URL.host isEqualToString:@"i.scdn.co"] || [request.URL.host isEqualToString:@"canvas.harness"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    if ([self.request.URL.host isEqualToString:@"amp-api.music.apple.com"]) {
        @synchronized (sg_catalogAsked) { [sg_catalogAsked addObject:self.request.URL]; }
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:sg_catalogStatus HTTPVersion:@"HTTP/1.1"
                                                                headerFields:@{@"Content-Type": @"application/json"}];
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:sg_catalogBody ?: [NSData data]];
        [self.client URLProtocolDidFinishLoading:self];
        return;
    }
    if (sg_canvasAsked && [self.request.URL.path hasSuffix:@".m3u8"]) {
        @synchronized (sg_canvasAsked) { [sg_canvasAsked addObject:self.request.URL]; }
        [self answer:nil];
        return;
    }
    // The motion scenario's clip, at once, or HARNESS_CANVAS_DELAY seconds late.
    if ([self.request.URL.host isEqualToString:@"canvas.harness"]) {
        const char *file = getenv("HARNESS_CANVAS_FILE"), *delay = getenv("HARNESS_CANVAS_DELAY");
        NSData *data = file ? [NSData dataWithContentsOfFile:@(file)] : nil;
        // HARNESS_CANVAS_FAILS=n: the first n requests for it fail on the way, as a download iOS canceled.
        static int failing = -1;
        if (failing < 0) failing = getenv("HARNESS_CANVAS_FAILS") ? atoi(getenv("HARNESS_CANVAS_FAILS")) : 0;
        if (failing > 0) {
            failing--;
            data = nil;
            NSLog(@"[harness] canvas server: this request fails");
        }
        NSThread *thread = NSThread.currentThread;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay ? atof(delay) : 0) * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
            sg_canvasServed++;
            [self performSelector:@selector(answer:) onThread:thread withObject:data waitUntilDone:NO];
        });
        return;
    }
    NSString *name = self.request.URL.lastPathComponent;
    SGRHarnessPicture *picture = name.length >= 24 ? sg_pictures[[name substringFromIndex:name.length - 24]] : nil;
    NSThread *thread = NSThread.currentThread;
    NSLog(@"[harness] picture server: %@ asked for, %@", name, picture ? (picture.fails ? @"will fail" : [NSString stringWithFormat:@"answers in %.1f s", picture.delay]) : @"unknown");
    NSData *data = picture.fails ? nil : UIImagePNGRepresentation(picture.image);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(picture.delay * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        [self performSelector:@selector(answer:) onThread:thread withObject:data waitUntilDone:NO];
    });
}

- (void)answer:(NSData *)data {
    if (_stopped) return;
    if (!data) {
        [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]];
        return;
    }
    sg_served++;
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:200 HTTPVersion:@"HTTP/1.1"
                                                            headerFields:@{@"Content-Type": @"image/png"}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [self.client URLProtocol:self didLoadData:data];
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {
    _stopped = YES;
}

@end

// Every session the mod makes is handed the server first.
@implementation NSURLSessionConfiguration (SGRHarness)
+ (NSURLSessionConfiguration *)sgr_harnessDefault {
    NSURLSessionConfiguration *configuration = [self sgr_harnessDefault];
    configuration.protocolClasses = [@[SGRHarnessPictureServer.class] arrayByAddingObjectsFromArray:configuration.protocolClasses ?: @[]];
    return configuration;
}
@end

#pragma mark - pictures

static UIImage *solid(UIColor *color) {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = 1;
    return [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(300, 300) format:format] imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [color setFill];
        UIRectFill(CGRectMake(0, 0, 300, 300));
    }];
}

// The color a picture is, by the pixel in its middle, named the way the checks name them.
static NSString *colorName(UIImage *image) {
    if (!image.CGImage) return @"none";
    uint8_t px[4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(px, 1, 1, 8, 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGFloat w = CGImageGetWidth(image.CGImage), h = CGImageGetHeight(image.CGImage);
    CGContextDrawImage(context, CGRectMake(-w / 2, -h / 2, w, h), image.CGImage);
    CGContextRelease(context);
    int r = px[0] > 128, g = px[1] > 128, b = px[2] > 128;
    NSArray *names = @[@"black", @"blue", @"green", @"cyan", @"red", @"magenta", @"yellow", @"white"];
    return names[r << 2 | g << 1 | b];
}

// Sample the actual composed table, not a one-pixel render target that UIKit can cull or a half-pixel image.
static NSString *pixelAtPoint(UIView *view, CGPoint point) {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1;
    UIImage *snapshot = [[[UIGraphicsImageRenderer alloc] initWithSize:view.bounds.size format:format] imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [view drawViewHierarchyInRect:(CGRect){CGPointZero, view.bounds.size} afterScreenUpdates:YES];
    }];
    CGImageRef pixel = CGImageCreateWithImageInRect(snapshot.CGImage, CGRectMake(point.x - view.bounds.origin.x, point.y - view.bounds.origin.y, 1, 1));
    // Exact bytes matter: a darkened magenta row (38,0,38) is still visible, not an opaque black shield.
    uint8_t rgba[4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(rgba, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(bitmap, CGRectMake(0, 0, 1, 1), pixel);
    CGContextRelease(bitmap);
    CGColorSpaceRelease(space);
    CGImageRelease(pixel);
    return [NSString stringWithFormat:@"%u,%u,%u,%u", rgba[0], rgba[1], rgba[2], rgba[3]];
}

#pragma mark - Spotify's classes, by name

@interface _TtC19NowPlaying_ViewImpl24NowPlayingViewController : UIViewController @end
@implementation _TtC19NowPlaying_ViewImpl24NowPlayingViewController @end

@interface _TtC20NowPlaying_ModesImpl23InformationElementsUnit : UIViewController @end
@implementation _TtC20NowPlaying_ModesImpl23InformationElementsUnit @end

@interface _TtC20NowPlaying_ModesImpl19DurationElementUnit : UIViewController @end
@implementation _TtC20NowPlaying_ModesImpl19DurationElementUnit @end

@interface _TtC20NowPlaying_ModesImpl20FloatingElementsUnit : UIViewController @end
@implementation _TtC20NowPlaying_ModesImpl20FloatingElementsUnit @end

@interface _TtC20NowPlaying_ModesImpl28PlaybackControlsElementsUnit : UIViewController @end
@implementation _TtC20NowPlaying_ModesImpl28PlaybackControlsElementsUnit @end

@interface _TtC20NowPlaying_ModesImpl18HeaderElementsUnit : UIViewController @end
@implementation _TtC20NowPlaying_ModesImpl18HeaderElementsUnit @end

@interface _TtC20NowPlaying_ModesImpl18FooterElementsUnit : UIViewController @end
@implementation _TtC20NowPlaying_ModesImpl18FooterElementsUnit @end

@interface _TtC21NowPlaying_ScrollImpl23NPVScrollViewController : UIViewController <UIScrollViewDelegate> @end
@implementation _TtC21NowPlaying_ScrollImpl23NPVScrollViewController
- (void)scrollViewDidScroll:(UIScrollView *)list {}
@end

@interface _TtC35NowPlaying_ContentLayerPlatformImpl24AccessibleCollectionView : UICollectionView @end
@implementation _TtC35NowPlaying_ContentLayerPlatformImpl24AccessibleCollectionView @end

@interface _TtC28NowPlaying_ContentLayersImpl16CoverArtCellImpl : UICollectionViewCell @end
@implementation _TtC28NowPlaying_ContentLayersImpl16CoverArtCellImpl @end

@interface _TtC21NowPlaying_ScrollImpl27NPVBackgroundViewController : UIViewController @end
@implementation _TtC21NowPlaying_ScrollImpl27NPVBackgroundViewController @end

// One of the units Spotify shows its music video in (Switch to video); PlayerMotion.x hooks its video surface.
@interface _TtC22NowPlaying_ElementsKit14VideoElementUI : NSObject @end
@implementation _TtC22NowPlaying_ElementsKit14VideoElementUI
- (void)videoSurfaceDidAttachVideo:(id)surface {}
- (void)videoSurfaceDidDetachVideo:(id)surface {}
@end

@interface _TtC18NowPlaying_BarImpl27NowPlayingBarViewController : UIViewController @end
@implementation _TtC18NowPlaying_BarImpl27NowPlayingBarViewController @end

@interface _TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView : UIView
- (void)handleTap;
@end
@implementation _TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView
- (void)handleTap {}
@end

@interface _TtC22Lyrics_NPVContainerKit19LyricsContainerView : UIView @end
@implementation _TtC22Lyrics_NPVContainerKit19LyricsContainerView @end

// The progress bar's slider (01.txt:224), tracking without a touch so the harness can scrub it in code.
@interface _TtCO17NowPlaying_ECMKit11ProgressBar6Slider : UISlider @end
@implementation _TtCO17NowPlaying_ECMKit11ProgressBar6Slider
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event { return YES; }
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {}
- (void)cancelTrackingWithEvent:(UIEvent *)event {}
@end

// The play button's view, which PlayerControls.x hooks for its tap.
@interface _TtC28EncoreConsumerMobile_BaseKit14PlayButtonView : UIView @end
@implementation _TtC28EncoreConsumerMobile_BaseKit14PlayButtonView
- (void)uiButtonTapped {}
@end

@interface MockEncoreButton : UIControl @end
@implementation MockEncoreButton @end

// Spotify's glyph view (Headers/SPTEncoreIconView.h), the queue's in the footer: it draws its glyph in the foreground
// color, or the active one while the queue is on.
@interface SPTEncoreIconView : UIView
@property (nonatomic, strong) UIColor *foregroundColor, *activeForegroundColor;
@property (nonatomic) BOOL isActive;
@property (nonatomic, strong) id icon;   // the SPTEncoreIcon it was made with, nil for the queue's in the tree
@end
@implementation SPTEncoreIconView {
    UIImageView *_drawn;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _drawn = [[UIImageView alloc] initWithFrame:self.bounds];
    _drawn.image = [UIImage systemImageNamed:@"list.bullet"];
    _drawn.contentMode = UIViewContentModeScaleAspectFit;
    _drawn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_drawn];
    _foregroundColor = UIColor.whiteColor;
    _activeForegroundColor = UIColor.greenColor;
    [self paint];
    return self;
}
- (instancetype)initWithIcon:(id)icon {
    if (!(self = [self initWithFrame:CGRectZero])) return nil;
    _icon = icon;
    _drawn.image = [UIImage systemImageNamed:[icon symbol]];
    return self;
}
- (void)setForegroundColor:(UIColor *)color { _foregroundColor = color; [self paint]; }
- (void)setActiveForegroundColor:(UIColor *)color { _activeForegroundColor = color; [self paint]; }
- (void)setIsActive:(BOOL)active { _isActive = active; [self paint]; }
- (void)paint { _drawn.tintColor = _isActive ? _activeForegroundColor : _foregroundColor; }
@end

// Spotify's glyph catalog (+[SPTEncoreIcon lyrics] and the like): each glyph drawn here by an SF Symbol of its own, unlike
// the Music app's the redesign draws, so a screenshot tells the two apart.
@interface SPTEncoreIcon : NSObject
@property (nonatomic, copy) NSString *name, *symbol;
@end
@implementation SPTEncoreIcon
+ (instancetype)named:(NSString *)name symbol:(NSString *)symbol {
    SPTEncoreIcon *icon = [self new];
    icon.name = name;
    icon.symbol = symbol;
    return icon;
}
+ (instancetype)microphone { return [self named:@"microphone" symbol:@"mic"]; }
+ (instancetype)queue { return [self named:@"queue" symbol:@"text.line.first.and.arrowtriangle.forward"]; }
@end

// The AI DJ's header and footer units (SGRDJClass's mangled Endless_DJMusicImpl names), built by the options scenario.
@interface _TtC19Endless_DJMusicImpl35DJMHeaderElementsUnitViewController : UIViewController @end
@implementation _TtC19Endless_DJMusicImpl35DJMHeaderElementsUnitViewController @end
@interface _TtC19Endless_DJMusicImpl27DJMFooterUnitViewController : UIViewController @end
@implementation _TtC19Endless_DJMusicImpl27DJMFooterUnitViewController @end

#pragma mark - building the tree

static UIView *box(UIView *parent, Class cls, CGRect frame, NSString *identifier) {
    UIView *view = [[cls alloc] initWithFrame:frame];
    view.accessibilityIdentifier = identifier;
    [parent addSubview:view];
    return view;
}

static UILabel *marquee(UIView *parent, CGRect frame, NSString *text, CGFloat size, UIColor *color, NSString *identifier) {
    UIView *clip = box(parent, UIView.class, frame, identifier);
    clip.clipsToBounds = YES;
    UILabel *inner = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 900, frame.size.height)];
    inner.text = text;
    inner.font = [UIFont systemFontOfSize:size weight:UIFontWeightBold];
    inner.textColor = color;
    [inner sizeToFit];
    [clip addSubview:inner];
    return inner;
}

static UIView *glyphButton(UIView *parent, CGRect frame, NSString *symbol, NSString *identifier) {
    UIView *button = box(parent, MockEncoreButton.class, frame, identifier);
    UIImageView *glyph = [[UIImageView alloc] initWithFrame:CGRectInset(button.bounds, 10, 10)];
    glyph.image = [UIImage systemImageNamed:symbol];
    glyph.contentMode = UIViewContentModeScaleAspectFit;
    glyph.tintColor = UIColor.whiteColor;
    [button addSubview:glyph];
    return button;
}

static UIImage *artwork(void) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(354, 354)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGFloat components[] = {0.11, 0.06, 0.35, 1, 0.83, 0.15, 0.62, 1};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, NULL, 2);
        CGContextDrawLinearGradient(ctx.CGContext, gradient, CGPointZero, CGPointMake(354, 354), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        [[UIColor colorWithWhite:1 alpha:0.9] set];
        [@"LOOSE\nCANON" drawAtPoint:CGPointMake(28, 28) withAttributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:44 weight:UIFontWeightHeavy],
            NSForegroundColorAttributeName: [UIColor colorWithRed:1 green:0.92 blue:0.2 alpha:1],
        }];
    }];
}

// A second album, busier: a warm sky over teal water with a sun in it, for the track change.
static UIImage *secondArtwork(void) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(354, 354)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGFloat sky[] = {0.98, 0.55, 0.20, 1, 0.85, 0.22, 0.30, 1};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(space, sky, NULL, 2);
        CGContextDrawLinearGradient(c, gradient, CGPointZero, CGPointMake(0, 200), 0);
        CGGradientRelease(gradient);
        CGFloat sea[] = {0.05, 0.45, 0.50, 1, 0.02, 0.12, 0.22, 1};
        gradient = CGGradientCreateWithColorComponents(space, sea, NULL, 2);
        CGContextSaveGState(c);
        CGContextClipToRect(c, CGRectMake(0, 200, 354, 154));
        CGContextDrawLinearGradient(c, gradient, CGPointMake(0, 200), CGPointMake(0, 354), 0);
        CGContextRestoreGState(c);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
        [[UIColor colorWithRed:1 green:0.9 blue:0.55 alpha:1] setFill];
        CGContextFillEllipseInRect(c, CGRectMake(210, 110, 90, 90));
        [@"LOW\nTIDE" drawAtPoint:CGPointMake(26, 230) withAttributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:40 weight:UIFontWeightHeavy],
            NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.9],
        }];
    }];
}

// A song with words timed inside each line, the shape SGRKaraokeView draws.
static void loadLyrics(void) {
    NSArray<NSString *> *texts = @[
        @"Who got the 808 under the 809",
        @"Making everybody jump?",
        @"Easy, I'm motivated",
        @"I got the feeling this is overrated",
        @"Give me the respect or give me nothing",
        @"Running up the hill with a heavy load",
        @"Tell them that the kid never folded",
        @"Every single verse was a promise kept",
        @"Nobody was there when it started",
        @"Now everybody wanna say they knew",
    ];
    NSMutableArray<SGKaraokeLine *> *lines = [NSMutableArray array];
    NSInteger at = 0;
    for (NSString *text in texts) {
        NSArray<NSString *> *words = [text componentsSeparatedByString:@" "];
        NSMutableArray<SGKaraokeWord *> *built = [NSMutableArray array];
        NSInteger cursor = at;
        for (NSString *word in words) {
            SGKaraokeWord *w = [SGKaraokeWord new];
            w.text = word;
            w.start = cursor;
            cursor += 260 + word.length * 40;
            // Each line's last word is held, as sung lines often end, so the held-word glow shows.
            if (word == words.lastObject) cursor += 1600;
            w.end = cursor;
            [built addObject:w];
        }
        SGKaraokeLine *line = [SGKaraokeLine new];
        line.words = built;
        line.start = at;
        line.end = cursor;
        [lines addObject:line];
        at = cursor + 400;
    }
    SGKaraokeKeepLines(@"harness", lines);
}

#pragma mark - the harness

// PlayerArtwork.x's hold on the cover, whose badge the badge scenario shows and hides by hand.
@interface NSObject (SGRHarnessHold)
- (void)showBadge:(BOOL)shown on:(UIView *)cover;
@end

// PlayerLyrics.x's tap that brings the controls back and the thumbnail's, fired by hand.
@interface NSObject (SGRHarnessLyrics)
- (void)sgr_woke;
- (void)sgr_thumbTapped;
@end

@interface SGRHarnessDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SGRHarnessDelegate {
    NSArray<UIViewController *> *_units;
    NSUInteger _headerDowns;
    UIImageView *_cover, *_barCover;
    UIViewController *_bar;
    UICollectionView *_covers;
    UIScrollView *_list;
    UIView *_plane, *_host;
    UIViewController *_background;
    UIView *_tilt;
    NSUInteger _failures, _checks;
    float _dimAlone;   // the motion scenario's dim before the lyrics
    // The options scenario's views: the footer's Connect glyph and queue icon, the AI DJ's header and footer, the
    // glyph Spotify drew for Connect.
    UIImageView *_connectImage, *_djConnectImage;
    SPTEncoreIconView *_queueIcon;
    UIView *_djHeader, *_djFooter, *_djButton, *_djConnect, *_djShare;
    UIImage *_spotifyConnect, *_djSpotifyConnect;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    loadLyrics();
    SGRHarnessPlayFrom(2400);
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor colorWithRed:0.09 green:0.07 blue:0.17 alpha:1];
    self.window.rootViewController = root;

    CGFloat W = root.view.bounds.size.width, H = root.view.bounds.size.height;
    // The player's own numbers are the tree's 402x874; the simulator's screen is whatever it is, so the
    // rows are placed as shares of it, the way Spotify's layout puts them.
    CGFloat headerTop = 62, headerHeight = 48;
    CGFloat bandTop = headerTop + headerHeight;
    const char *volumeEnv = getenv("HARNESS_VOLUME");
    BOOL hasVolume = !(volumeEnv && volumeEnv[0] == '0');
    CGFloat bottomHeight = 236 + (hasVolume ? 44 : 0);   // the tree's rows plus a volume row, as the phone has it
    CGFloat bottomTop = H - bottomHeight - 61.33;
    CGFloat bandHeight = bottomTop - bandTop;
    CGFloat coverSide = MIN(354, W - 48);

    // NPVScrollViewController: the list the player is the header of.
    UIView *page = box(root.view, UIView.class, root.view.bounds, nil);
    UIScrollView *list = [[UIScrollView alloc] initWithFrame:page.bounds];
    list.accessibilityIdentifier = @"scrolling_npv_collection_view_accessibility_identifier";
    list.contentSize = CGSizeMake(W, H + 326);       // the player and a card's worth of cards under it
    [page addSubview:list];
    UIViewController *scrollUnit = [_TtC21NowPlaying_ScrollImpl23NPVScrollViewController new];
    scrollUnit.view = page;
    list.delegate = (id<UIScrollViewDelegate>)scrollUnit;
    _list = list;

    // NPVBackgroundViewController's plane, the field's home (trees/clean/player/01.txt:449), under the player.
    UIView *plane = box(list, UIView.class, CGRectMake(0, 0, W, H), nil);
    plane.backgroundColor = [UIColor colorWithRed:0.3 green:0.1 blue:0.3 alpha:1];
    UIViewController *background = [_TtC21NowPlaying_ScrollImpl27NPVBackgroundViewController new];
    background.view = plane;

    UIView *host = box(list, UIView.class, CGRectMake(0, 0, W, H), @"SPTNowPlayingView");

    // the content layers: the sideways list of covers
    UIView *layers = box(host, UIView.class, host.bounds, nil);
    UICollectionViewFlowLayout *flow = [UICollectionViewFlowLayout new];
    UICollectionView *covers = [[_TtC35NowPlaying_ContentLayerPlatformImpl24AccessibleCollectionView alloc]
                                initWithFrame:layers.bounds collectionViewLayout:flow];
    covers.accessibilityIdentifier = @"nowplaying-contentlayer-collectionview";
    covers.backgroundColor = UIColor.clearColor;
    [layers addSubview:covers];
    UIView *cell = box(covers, _TtC28NowPlaying_ContentLayersImpl16CoverArtCellImpl.class, covers.bounds, @"nowplaying-contentlayer-cell-0");
    UIView *band = box(cell, UIView.class, CGRectMake(0, bandTop, W, bandHeight), nil);
    UIView *inner = box(band, UIView.class, CGRectMake(24, 8, W - 48, bandHeight - 16), nil);
    UIView *tilt = box(inner, _TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView.class,
                       CGRectMake(0, round((inner.bounds.size.height - coverSide) / 2), coverSide, coverSide), nil);
    tilt.accessibilityLabel = @"Inspect cover art";
    _tilt = tilt;
    // The Encore.ImageView holding the picture (01.txt:40), which PlayerField.x reads the cover from.
    UIView *coverElement = box(tilt, UIView.class, tilt.bounds, @"Encore.ImageView");
    coverElement.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UIImage *picture = artwork();
    UIImageView *cover = [[UIImageView alloc] initWithFrame:coverElement.bounds];
    cover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    cover.image = picture;
    _cover = cover;
    cover.contentMode = UIViewContentModeScaleAspectFill;
    [coverElement addSubview:cover];
    box(inner, _TtC22Lyrics_NPVContainerKit19LyricsContainerView.class, CGRectMake(0, inner.bounds.size.height, coverSide, 0), nil);

    // the header row
    UIView *header = box(host, UIStackView.class, CGRectMake(0, headerTop, W, headerHeight), nil);
    glyphButton(header, CGRectMake(12, 0, 48, 48), @"chevron.down", @"now-playing-minimize-button");
    glyphButton(header, CGRectMake(W - 60, 0, 48, 48), @"ellipsis", @"Context menu");

    // the bottom stack: information, duration, controls, volume, footer
    UIView *bottom = box(host, UIStackView.class, CGRectMake(0, bottomTop, W, bottomHeight), @"npv.bottomStackView");

    UIView *floatingView = box(bottom, UIView.class, CGRectMake(0, -32, W, 32), nil);
    UIView *chip = box(floatingView, UIView.class, CGRectMake(24, 0, 148, 32), nil);
    chip.backgroundColor = [UIColor colorWithWhite:1 alpha:0.16];
    chip.layer.cornerRadius = 16;
    UILabel *chipLabel = [[UILabel alloc] initWithFrame:chip.bounds];
    chipLabel.text = @"  \u25B6  Switch to video";
    chipLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    chipLabel.textColor = UIColor.whiteColor;
    [chip addSubview:chipLabel];

    UIView *infoView = box(bottom, UIView.class, CGRectMake(0, 0, W, 64), nil);
    UIView *infoRow = box(infoView, UIStackView.class, CGRectMake(12, 8, W - 24, 48), nil);
    UIView *infoInner = box(infoRow, UIStackView.class, infoRow.bounds, nil);
    box(infoInner, UIView.class, CGRectMake(0, 24, 0, 0), nil);          // Spotify's own mini cover, unused
    box(infoInner, UIView.class, CGRectMake(0, 24, 12, 0), nil);         // the spacer after it
    CGFloat titleWidth = infoInner.bounds.size.width - 12 - 60;
    UIView *titleElement = box(infoInner, UIView.class, CGRectMake(12, 2.33, titleWidth, 43.33), nil);
    UIView *titleContainer = box(titleElement, UIView.class, titleElement.bounds, nil);
    marquee(titleContainer, CGRectMake(0, 0, titleWidth, 25.33), @"We Are The People - southstar Remix (Extended)", 21,
            UIColor.whiteColor, @"now-playing-title-label");
    marquee(titleContainer, CGRectMake(0, 25.33, titleWidth, 18), @"Canon", 13,
            [UIColor colorWithWhite:1 alpha:0.7], @"now-playing-subtitle-label");
    glyphButton(infoInner, CGRectMake(infoInner.bounds.size.width - 48, 0, 48, 48), @"star", @"Components.UI.AddToButton");

    UIView *durationView = box(bottom, UIView.class, CGRectMake(0, 64, W, 40), nil);
    UIView *track = box(durationView, UIView.class, CGRectMake(24, 8, W - 48, 6), nil);
    track.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
    track.layer.cornerRadius = 3;
    UIView *played = box(track, UIView.class, CGRectMake(0, 0, (W - 48) * 0.22, 6), nil);
    played.backgroundColor = [UIColor colorWithWhite:1 alpha:0.85];
    played.layer.cornerRadius = 3;

    UIView *controls = box(bottom, UIView.class, CGRectMake(0, 104, W, 88), nil);
    glyphButton(controls, CGRectMake(W / 2 - 130, 20, 48, 48), @"backward.fill", nil);
    glyphButton(controls, CGRectMake(W / 2 - 24, 14, 48, 60), @"pause.fill", nil);
    glyphButton(controls, CGRectMake(W / 2 + 82, 20, 48, 48), @"forward.fill", nil);

    if (hasVolume) {
        UIView *volume = box(bottom, UIView.class, CGRectMake(0, 192, W, 44), nil);
        UIView *volumeTrack = box(volume, UIView.class, CGRectMake(44, 19, W - 88, 6), nil);
        volumeTrack.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
        volumeTrack.layer.cornerRadius = 3;
    }

    UIView *footerView = box(bottom, UIView.class, CGRectMake(0, hasVolume ? 236 : 192, W, 44), nil);
    UIView *footerRow = box(footerView, UIStackView.class, CGRectMake(12, 0, W - 24, 44), nil);
    UIView *connect = box(footerRow, UIView.class, CGRectMake(0, 4, 153.67, 36), nil);
    UIView *connectHolder = box(connect, UIView.class, connect.bounds, @"Components.ConnectButtonOutputSwitcher");
    UIImageView *connectGlyph = [[UIImageView alloc] initWithFrame:CGRectMake(0, 8, 19, 19)];
    connectGlyph.image = [UIImage systemImageNamed:@"airpods.pro"];
    connectGlyph.tintColor = UIColor.whiteColor;
    [connectHolder addSubview:connectGlyph];
    _connectImage = connectGlyph;
    _spotifyConnect = connectGlyph.image;
    glyphButton(footerRow, CGRectMake(279, 0, 44, 44), @"square.and.arrow.up", @"ShareButtonNowPlayingView");
    // The queue control holds Spotify's 18x18 glyph view (out/rep/ptree.txt:1228-1279).
    UIView *queueButton = box(footerRow, MockEncoreButton.class, CGRectMake(323, 6, 47, 32), @"QueueButtonNowPlaying");
    _queueIcon = (SPTEncoreIconView *)box(queueButton, SPTEncoreIconView.class, CGRectMake(14.5, 7, 18, 18), @"Encore.IconView");

    // The options scenario's AI DJ: its header unit's two buttons over the status bar, and its footer (DJMFooterUnitView:
    // share, the DJ button and Connect, not in a stack) just under the player's header row.
    UIViewController *djHeaderUnit = nil, *djFooterUnit = nil;
    if ([scenario() isEqualToString:@"options"]) {
        _djHeader = box(host, UIView.class, CGRectMake(0, 8, W, headerHeight), nil);
        glyphButton(_djHeader, CGRectMake(W / 2 - 104, 0, 48, 48), @"chevron.down", @"now-playing-minimize-button");
        glyphButton(_djHeader, CGRectMake(W / 2 + 56, 0, 48, 48), @"ellipsis", @"Context menu");
        _djFooter = box(host, UIView.class, CGRectMake(0, bandTop, W, 44), nil);
        UIView *djConnectHolder = box(_djFooter, UIView.class, CGRectMake(16, 4, 153, 36), nil);
        UIView *djConnect = box(djConnectHolder, UIView.class, djConnectHolder.bounds, @"Components.ConnectButtonOutputSwitcher");
        _djConnect = djConnect;
        _djConnectImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 8, 19, 19)];
        _djConnectImage.image = [UIImage systemImageNamed:@"hifispeaker"];
        _djConnectImage.tintColor = UIColor.whiteColor;
        _djSpotifyConnect = _djConnectImage.image;
        [djConnect addSubview:_djConnectImage];
        UILabel *device = [[UILabel alloc] initWithFrame:CGRectMake(26, 8, 120, 19)];
        device.text = @"Living Room";
        device.textColor = UIColor.whiteColor;
        [djConnect addSubview:device];
        // Connect under the DJ button and the share button's holder over it, right where the footer puts the DJ button:
        // the order in which a holder given its touches back would take the DJ button's.
        UIView *djHolder = box(_djFooter, UIView.class, CGRectMake(W - 120, -2, 48, 48), nil);
        UIView *dj = box(djHolder, MockEncoreButton.class, djHolder.bounds, @"Components.UI.NeffleButtonNowPlayingContainerView");
        dj.backgroundColor = UIColor.systemBlueColor;
        dj.layer.cornerRadius = 24;
        dj.isAccessibilityElement = YES;
        dj.accessibilityLabel = @"DJ";
        _djButton = dj;
        UIView *shareHolder = box(_djFooter, UIView.class, CGRectMake(round(W * 0.8) - 22, 0, 44, 44), nil);
        _djShare = glyphButton(shareHolder, shareHolder.bounds, @"square.and.arrow.up", @"ShareButtonNowPlayingView");
        box(_djFooter, UIView.class, CGRectMake(W / 2, 0, 1, 44), nil);   // the empty view
        djHeaderUnit = [_TtC19Endless_DJMusicImpl35DJMHeaderElementsUnitViewController new];
        djHeaderUnit.view = _djHeader;
        djFooterUnit = [_TtC19Endless_DJMusicImpl27DJMFooterUnitViewController new];
        djFooterUnit.view = _djFooter;
    }

    // The now playing bar, off screen: the Kit reads its 40pt cover (SPTNowPlayingBar > Encore.ImageView >
    // UIImageView, trees/clean/artist/01.txt).
    UIView *barView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 64)];
    UIView *barCard = box(barView, UIView.class, CGRectMake(8, 8, W - 16, 48), @"SPTNowPlayingBar");
    UIView *barHolder = box(barCard, UIView.class, CGRectMake(8, 4, 40, 40), @"Encore.ImageView");
    UIImageView *barCover = [[UIImageView alloc] initWithFrame:barHolder.bounds];
    barCover.image = picture;
    [barHolder addSubview:barCover];
    _barCover = barCover;
    _bar = [_TtC18NowPlaying_BarImpl27NowPlayingBarViewController new];
    _bar.view = barView;

    [self.window makeKeyAndVisible];

    UIViewController *info = [_TtC20NowPlaying_ModesImpl23InformationElementsUnit new];
    info.view = infoView;
    UIViewController *duration = [_TtC20NowPlaying_ModesImpl19DurationElementUnit new];
    duration.view = durationView;
    UIViewController *floating = [_TtC20NowPlaying_ModesImpl20FloatingElementsUnit new];
    floating.view = floatingView;
    UIViewController *footer = [_TtC20NowPlaying_ModesImpl18FooterElementsUnit new];
    footer.view = footerView;
    UIViewController *playback = [_TtC20NowPlaying_ModesImpl28PlaybackControlsElementsUnit new];
    playback.view = controls;
    UIViewController *headerUnit = [_TtC20NowPlaying_ModesImpl18HeaderElementsUnit new];
    headerUnit.view = header;
    UIViewController *player = [_TtC19NowPlaying_ViewImpl24NowPlayingViewController new];
    player.view = host;
    _units = @[headerUnit, info, duration, floating, playback, footer, scrollUnit, background, player];
    _covers = covers;
    _plane = plane;
    _host = host;
    _background = background;
    // The player has not been opened yet: its background plane is laid out only when it is.
    if ([scenario() isEqualToString:@"motion"]) {
        [plane removeFromSuperview];
        _units = @[headerUnit, info, duration, floating, playback, footer, scrollUnit, player];
    }
    if (djHeaderUnit) _units = [_units arrayByAddingObjectsFromArray:@[djHeaderUnit, djFooterUnit]];
    [self start];
    [self layOut];
    // Spotify lays its units out again as a track's elements arrive, which is what the redesign's
    // transforms and narrowed labels have to survive. The options scenario leaves layout to UIKit, so a switch
    // on the Player page is seen to reach the open player by itself.
    if (![scenario() isEqualToString:@"options"] && ![scenario() isEqualToString:@"renderer"]) {
        [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *t) { [self layOut]; }];
    }

    NSLog(@"[harness] lyrics available: %d", SGRPlayerLyricsAvailable());
    // With the lines up, the row that rose into them must still be Spotify's to touch, and the lines
    // themselves must take the tap that seeks.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIView *star = nil;
        for (UIView *v in infoInner.subviews) if ([v.accessibilityIdentifier isEqualToString:@"Components.UI.AddToButton"]) star = v;
        CGPoint onStar = [self.window convertPoint:CGPointMake(CGRectGetMidX(star.bounds), CGRectGetMidY(star.bounds)) fromView:star];
        CGPoint onTitle = [self.window convertPoint:CGPointMake(40, 12) fromView:titleElement];
        CGPoint onLines = CGPointMake(W / 2, H * 0.45);
        NSLog(@"[harness] hit on the star: %@", NSStringFromClass([self.window hitTest:onStar withEvent:nil].class));
        NSLog(@"[harness] hit on the title: %@", NSStringFromClass([self.window hitTest:onTitle withEvent:nil].class));
        NSLog(@"[harness] hit on the lines: %@", NSStringFromClass([self.window hitTest:onLines withEvent:nil].class));
    });
    if ([scenario() isEqualToString:@"artwork"]) [self runArtworkChecks];
    else if ([scenario() isEqualToString:@"look"]) [self runLook];
    else if ([scenario() isEqualToString:@"scroll"]) [self runScrollChecks];
    else if ([scenario() isEqualToString:@"controls"]) [self runControlsChecks];
    else if ([scenario() isEqualToString:@"landscape"]) [self runLandscape];
    else if ([scenario() isEqualToString:@"motion"]) [self runMotionChecks];
    else if ([scenario() isEqualToString:@"still"]) [self runStillChecks];
    else if ([scenario() isEqualToString:@"catalog"]) [self runCatalogChecks];
    else if ([scenario() isEqualToString:@"badge"]) [self runBadgeChecks];
    else if ([scenario() isEqualToString:@"cover"]) [self runCoverChecks];
    else if ([scenario() isEqualToString:@"immersive"]) [self runImmersiveChecks];
    else if ([scenario() isEqualToString:@"settings"]) [self runSettingsChecks];
    else if ([scenario() isEqualToString:@"preview"]) [self runPreviewChecks];
    else if ([scenario() isEqualToString:@"seek"]) [self runSeekChecks];
    else if ([scenario() isEqualToString:@"visualiser"]) [self runVisualiserChecks];
    else if ([scenario() isEqualToString:@"autoviz"]) [self runAutoVisualiserChecks];
    else if ([scenario() isEqualToString:@"shuffle"]) [self runShuffleChecks];
    else if ([scenario() isEqualToString:@"heat"]) [self runHeatChecks];
    else if ([scenario() isEqualToString:@"header"]) [self runHeaderChecks];
    else if ([scenario() isEqualToString:@"options"]) [self runOptionsChecks];
    else if ([scenario() isEqualToString:@"renderer"]) [self runRendererChecks];
    else if ([scenario() isEqualToString:@"automix"]) SGRHarnessRunAutoMix(self.window, _units[2], _tilt);
    // Opened, closed and opened again, so a screenshot can be taken of each state and of the move itself.
    else for (NSNumber *at in @[@2, @6, @10]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(at.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSLog(@"[harness] %@ the lyrics", SGRPlayerLyricsOpen() ? @"closing" : @"opening");
            SGRPlayerToggleLyrics();
        });
    }
    return YES;
}

- (void)layOut {
    for (UIViewController *unit in _units) [unit viewDidLayoutSubviews];
}

#pragma mark - tracks

static NSString *imageURI(NSString *digits) {
    // 16 digits of size, then the picture's own 24 (padded here from a short name).
    NSString *hash = [[digits stringByPaddingToLength:24 withString:@"0" startingAtIndex:0] substringToIndex:24];
    return [@"spotify:image:ab67616d0000b273" stringByAppendingString:hash];
}

static UIViewController *unitOf(UIView *view) {
    UIResponder *next = view.nextResponder;
    return [next isKindOfClass:UIViewController.class] ? (UIViewController *)next : nil;
}

static UIView *firstOfClass(UIView *root, NSString *name);

// The alpha of a gradient's stop `index`.
static CGFloat stopAlpha(CAGradientLayer *gradient, NSUInteger index) {
    return CGColorGetAlpha((__bridge CGColorRef)gradient.colors[index]);
}

// Steps of @[delay, block], each run its delay after the one before it ran. Blocks all scheduled from one moment drift
// with dispatch_after's leeway, which grows with the delay, and two can fire together with no layout pass between.
static void runScript(NSArray<NSArray *> *script, NSUInteger index) {
    if (index >= script.count) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([script[index][0] doubleValue] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        ((dispatch_block_t)script[index][1])();
        runScript(script, index + 1);
    });
}

static void after(NSTimeInterval seconds, dispatch_block_t block) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}

// What Spotify's screens do when a track changes: the list of covers moves to the new cell and lays out,
// still showing whatever picture that cell had, and the bar's cover stays what it was, until the
// pictures load and are set on the image views -- which lays nothing out.
- (void)playTrack:(NSString *)uri image:(NSString *)image {
    NSLog(@"[harness] track %@ (picture %@)", uri, [image substringFromIndex:image.length - 24]);
    SGRHarnessSetTrack(uri, image, NO);
    [_covers setNeedsLayout];
    [_covers layoutIfNeeded];
}

- (void)showOnScreen:(UIImage *)picture {
    _cover.image = picture;
    _barCover.image = picture;
}

- (void)start {
    BOOL checks = [scenario() isEqualToString:@"artwork"];
    UIImage *first = checks ? solid(UIColor.redColor) : _cover.image;
    [self showOnScreen:first];
    serve(imageURI(@"aaaa"), first, 0.2, NO);
    // card: nothing plays; the Player page's card shows the last track played, or none.
    if ([scenario() isEqualToString:@"card"]) {
        after(1, ^{
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:SGRPlayerSettingsPage(@[])];
            nav.modalPresentationStyle = UIModalPresentationFullScreen;
            [self.window.rootViewController presentViewController:nav animated:NO completion:nil];
            after(2, ^{
                UIView *card = firstOfClass(((UITableViewController *)nav.topViewController).tableView, @"SGRPlayerPreview");
                UIImageView *cover = [card valueForKey:@"_cover"];
                NSLog(@"[harness] card: \"%@\", \"%@\", cover %.0fx%.0f", [[card valueForKey:@"_title"] text], [[card valueForKey:@"_artist"] text],
                      cover.image.size.width, cover.image.size.height);
            });
        });
        return;
    }
    [self playTrack:@"spotify:track:harnessA" image:imageURI(@"aaaa")];
    // The bar lays out once as the app comes up.
    [_bar viewDidLayoutSubviews];
}

#pragma mark - landscape

static UIViewController *landscapeScreen(void) {
    for (UIWindow *window in UIApplication.sharedApplication.connectedScenes.anyObject ? ((UIWindowScene *)UIApplication.sharedApplication.connectedScenes.anyObject).windows : @[]) {
        if (!window.hidden && [NSStringFromClass(window.rootViewController.class) isEqualToString:@"SGRLandscapeLyricsController"]) return window.rootViewController;
    }
    return nil;
}

// What a touch on the lines lands on, and whether the controls are up.
static void logLandscape(NSString *step, NSString *want) {
    UIViewController *screen = landscapeScreen();
    UIView *view = screen.view, *shield = [screen valueForKey:@"shield"];
    CGPoint onLine = CGPointMake(view.bounds.size.width * 0.7, view.bounds.size.height * 0.5);
    UIView *hit = [view hitTest:onLine withEvent:nil];
    CGFloat controls = [[screen valueForKey:@"controls"] alpha];
    NSString *got = hit == shield ? @"shield" : @"lines";
    NSLog(@"[harness] landscape %@: controls %.0f, a touch on the lines lands on %@ (%@) -- want %@: %@", step, controls,
          got, NSStringFromClass(hit.class), want, [got isEqualToString:want] ? @"ok" : @"WRONG");
}

// The landscape lyrics as a turned phone shows them: a line's meanings over them as a card on the bottom
// edge, the controls staying up behind the sheet and fading once it is gone, the shield taking the touch
// that brings them back, and a pause and a resume from elsewhere starting the clock again.
- (void)runLandscape {
    after(3, ^{ SGRPlayerShowLandscape(YES); });
    // The window comes up clear and fades in with the turn; it and what it presents are dark; the
    // controls say what they do and are 44pt.
    after(3.05, ^{
        UIWindow *window = landscapeScreen().view.window;
        NSLog(@"[harness] landscape window as it comes up: alpha %.2f -- want under 1: %@", window.alpha, window.alpha < 1 ? @"ok" : @"WRONG");
    });
    after(3.9, ^{
        UIViewController *screen = landscapeScreen();
        UIWindow *window = screen.view.window;
        NSLog(@"[harness] landscape window: alpha %.2f, %@ -- want 1, dark: %@", window.alpha,
              window.overrideUserInterfaceStyle == UIUserInterfaceStyleDark ? @"dark" : @"not dark",
              window.alpha == 1 && window.overrideUserInterfaceStyle == UIUserInterfaceStyleDark ? @"ok" : @"WRONG");
        NSMutableArray<UIButton *> *buttons = [[[screen valueForKey:@"controls"] arrangedSubviews] mutableCopy];
        [buttons addObject:[screen valueForKey:@"_close"]];
        for (UIButton *button in buttons) {
            BOOL ok = button.accessibilityLabel.length && button.bounds.size.width >= 44 && button.bounds.size.height >= 44;
            NSLog(@"[harness] landscape button \"%@\" %@ -- want a label, 44pt: %@", button.accessibilityLabel,
                  NSStringFromCGSize(button.bounds.size), ok ? @"ok" : @"WRONG");
        }
        UILabel *title = [screen valueForKey:@"_title"], *artist = [screen valueForKey:@"_artist"];
        NSLog(@"[harness] landscape text: title %.0fpt in %@, artist %.0fpt in %@, close %@", title.font.pointSize,
              NSStringFromCGRect(title.frame), artist.font.pointSize, NSStringFromCGRect(artist.frame),
              NSStringFromCGRect([[screen valueForKey:@"_close"] frame]));
    });
    after(4, ^{
        SGLyricsMeaning *meaning = [SGLyricsMeaning new];
        meaning.author = SGLyricsMeaningByArtist;
        meaning.body = @"A line of the harness's song, explained at the length Genius explains one, so the card has a body to show and to wrap.";
        meaning.url = @"https://genius.com";
        SGRShowMeanings(@"Harness line", @[meaning]);
    });
    after(6, ^{
        UIViewController *sheet = landscapeScreen().presentedViewController;
        UIView *window = sheet.view.window;
        NSLog(@"[harness] landscape meanings: %@ %@ in a window %@, height class %ld, edge attached %d",
              NSStringFromClass(sheet.class), NSStringFromCGRect([sheet.view convertRect:sheet.view.bounds toView:window]),
              NSStringFromCGSize(window.bounds.size), (long)sheet.traitCollection.verticalSizeClass,
              sheet.sheetPresentationController.prefersEdgeAttachedInCompactHeight);
    });
    after(8.5, ^{ logLandscape(@"with the sheet up past the rest", @"lines"); });
    after(9, ^{ [landscapeScreen() dismissViewControllerAnimated:YES completion:nil]; });
    after(14, ^{ logLandscape(@"rested after the sheet went", @"shield"); });
    after(14.5, ^{ SGRHarnessSetTrack(@"spotify:track:harnessA", imageURI(@"aaaa"), YES); });
    after(15, ^{ logLandscape(@"paused", @"lines"); });
    after(15.5, ^{ SGRHarnessSetTrack(@"spotify:track:harnessA", imageURI(@"aaaa"), NO); });
    after(17, ^{ logLandscape(@"just resumed", @"lines"); });
    after(21, ^{ logLandscape(@"rested after the resume", @"shield"); });
    // VoiceOver's escape turns the screen back, and the player is key once it has faded.
    after(22, ^{ NSLog(@"[harness] landscape escape answered %d", [landscapeScreen() accessibilityPerformEscape]); });
    after(23, ^{
        BOOL gone = !landscapeScreen(), key = self.window.isKeyWindow;
        NSLog(@"[harness] landscape after the escape: gone %d, the player key %d -- %@", gone, key, gone && key ? @"ok" : @"WRONG");
    });
}

#pragma mark - badge

// The hold's 2x badge: the Kit's glass capsule first in it with its effect on, the label over it, the
// glyph an attachment; a hold again while it fades out keeps it; let go, it goes.
- (void)runBadgeChecks {
    __block NSObject *hold = nil;
    for (UIGestureRecognizer *recognizer in _tilt.gestureRecognizers) {
        if ([NSStringFromClass(recognizer.class) isEqualToString:@"SGRCoverHold"]) hold = recognizer;
    }
    __block NSUInteger right = 0, checks = 0;
    void (^check)(NSString *, BOOL) = ^(NSString *step, BOOL ok) {
        checks++;
        if (ok) right++;
        NSLog(@"[harness] badge %@: %@", step, ok ? @"ok" : @"WRONG");
    };
    UIView *tilt = _tilt;
    UIView *(^badge)(void) = ^UIView *{ return [hold valueForKey:@"badge"]; };
    after(2, ^{ [hold showBadge:YES on:tilt]; });
    after(2.8, ^{
        UIView *shape = badge().subviews.firstObject;
        UILabel *label = [hold valueForKey:@"badgeLabel"];
        __block BOOL glyph = NO;
        [label.attributedText enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0, label.attributedText.length) options:0
                                      usingBlock:^(id value, NSRange range, BOOL *stop) { if (value) glyph = YES; }];
        check(@"up", badge().superview == tilt && [shape isKindOfClass:UIVisualEffectView.class]
              && ((UIVisualEffectView *)shape).effect && label.superview == badge() && label.alpha == 1
              && CGAffineTransformIsIdentity(badge().transform) && glyph);
        NSLog(@"[harness] badge %@ with %@ (%@), label %@ fits %d", NSStringFromCGRect(badge().frame), NSStringFromClass(shape.class),
              NSStringFromClass([(UIVisualEffectView *)shape effect].class), label.attributedText.string,
              label.intrinsicContentSize.width <= badge().bounds.size.width);
        [hold showBadge:NO on:tilt];
    });
    after(2.85, ^{ [hold showBadge:YES on:tilt]; });
    after(3.5, ^{
        check(@"held again while it faded", badge().superview == tilt && [(UIVisualEffectView *)badge().subviews.firstObject effect]);
        [hold showBadge:NO on:tilt];
    });
    after(4, ^{
        check(@"let go", !badge().superview);
        NSLog(@"[harness] badge checks: %lu of %lu right -- %@", (unsigned long)right, (unsigned long)checks, right == checks ? @"PASS" : @"FAIL");
    });
}

- (void)check:(NSString *)step want:(NSString *)want {
    NSString *uri = nil;
    UIImage *artwork = SGRNowPlayingArtwork(&uri, NULL);
    UIImage *drawn = [SGRPlayerField() valueForKey:@"image"];
    NSString *kit = colorName(artwork), *field = colorName(drawn);
    BOOL ok = [kit isEqualToString:want] && [field isEqualToString:want];
    _checks++;
    if (!ok) _failures++;
    NSLog(@"[harness] check %@: want %@, the Kit has %@ (for %@), the field draws %@ -- %@", step, want, kit, uri, field, ok ? @"ok" : @"WRONG");
}

// Issue #58: after a switch to another album the field kept the last one's picture until the next track.
- (void)runArtworkChecks {
    UIImage *green = solid(UIColor.greenColor), *blue = solid(UIColor.blueColor), *yellow = solid(UIColor.yellowColor),
            *magenta = solid(UIColor.magentaColor);
    after(1.5, ^{ [self check:@"1 first track" want:@"red"]; });

    // Another album: the screens go on showing the last picture for 3.5 s, well past the Kit's last look
    // at them, and the picture server answers in 1 s.
    after(2, ^{
        serve(imageURI(@"bbbb"), green, 1.0, NO);
        [self playTrack:@"spotify:track:harnessB" image:imageURI(@"bbbb")];
    });
    after(5.5, ^{ [self showOnScreen:green]; });
    after(7, ^{ [self check:@"2 album switch, the screens late" want:@"green"]; });

    // Two tracks in quick succession, the first one's picture answering last.
    after(7.5, ^{
        serve(imageURI(@"cccc"), blue, 2.0, NO);
        [self playTrack:@"spotify:track:harnessC" image:imageURI(@"cccc")];
    });
    after(7.7, ^{ [self showOnScreen:blue]; });
    after(7.8, ^{
        serve(imageURI(@"dddd"), yellow, 0.3, NO);
        [self playTrack:@"spotify:track:harnessD" image:imageURI(@"dddd")];
    });
    after(8.1, ^{ [self showOnScreen:yellow]; });
    after(11, ^{ [self check:@"3 skip twice, the older answer last" want:@"yellow"]; });

    // Offline: the server fails, and the screens show the new picture 0.8 s after the change.
    after(11.5, ^{
        serve(imageURI(@"eeee"), magenta, 0.1, YES);
        [self playTrack:@"spotify:track:harnessE" image:imageURI(@"eeee")];
    });
    after(12.3, ^{ [self showOnScreen:magenta]; });
    after(14.5, ^{ [self check:@"4 offline, the screens only" want:@"magenta"]; });

    after(15, ^{
        NSLog(@"[harness] artwork checks: %lu of %lu right -- %@", (unsigned long)(self->_checks - self->_failures), (unsigned long)self->_checks,
              self->_failures ? @"FAIL" : @"PASS");
    });
}

// Up must be taken back to the top, down (the dismissal's pull) left where it went.
#pragma mark - Animated artwork

BOOL SGPlayerMenuAnimatedArtwork(void);
void SGPlayerMenuSetAnimatedArtwork(BOOL on);

static UIView *motionView(void) {
    for (UIView *view in SGRPlayerField().subviews) {
        if ([NSStringFromClass(view.class) isEqualToString:@"SGRPlayerMotionView"]) return view;
    }
    return nil;
}

- (void)expect:(BOOL)ok step:(NSString *)step detail:(NSString *)detail {
    _checks++;
    if (!ok) _failures++;
    NSLog(@"[harness] %@ check %@: %@ -- %@", scenario(), step, detail, ok ? @"ok" : @"WRONG");
}

// The field covered by the clip, and its Fluid copies hidden for it.
static BOOL fieldCovered(void) {
    SGRArtworkField *field = SGRPlayerField();
    CALayer *fluid = [field valueForKey:@"_fluidLayer"];
    return field.covered && fluid && fluid.hidden;
}

// Green above the last 3% of rows, equal red/blue halves within them: the foot must
// render as opaque purple everywhere, not green, either edge's color, or vertical streaks.
static BOOL motionFootHasMeanColor(NSURL *file, NSString **detail) {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1;
    format.preferredRange = UIGraphicsImageRendererFormatRangeStandard;
    UIImage *poster = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(32, 100) format:format]
        imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            [UIColor.greenColor setFill];
            UIRectFill(CGRectMake(0, 0, 32, 100));
            [UIColor.redColor setFill];
            UIRectFill(CGRectMake(0, 97, 16, 3));
            [UIColor.blueColor setFill];
            UIRectFill(CGRectMake(16, 97, 16, 3));
        }];
    SGRPlayerMotionView *probe = [[SGRPlayerMotionView alloc] initWithFrame:CGRectMake(0, 0, 32, 120)];
    [probe playFile:file poster:poster];
    [probe layoutIfNeeded];
    CALayer *foot = [probe valueForKey:@"_foot"];
    uint8_t pixels[16 * 4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(pixels, 16, 1, 8, sizeof pixels, space,
                                                kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextScaleCTM(context, 16 / foot.bounds.size.width, 1 / foot.bounds.size.height);
    [foot renderInContext:context];
    CGContextRelease(context);
    for (NSUInteger x = 0; x < 16; x++) {
        uint8_t *pixel = pixels + x * 4;
        if (pixel[0] != 128 || pixel[1] != 0 || pixel[2] != 128 || pixel[3] != 255) {
            *detail = [NSString stringWithFormat:@"pixel %lu RGBA %u,%u,%u,%u; expected 128,0,128,255",
                       (unsigned long)x, pixel[0], pixel[1], pixel[2], pixel[3]];
            return NO;
        }
    }
    *detail = @"all 16 pixels RGBA 128,0,128,255";
    return YES;
}

- (void)runMotionChecks {
    // The clip comes in before the player has laid out, as for the track restored at launch.
    after(3, ^{
        [self expect:SGRPlayerMotionShowing() && !SGRPlayerField() step:@"before the player opened"
              detail:[NSString stringWithFormat:@"clip %@, field %@", SGRPlayerMotionShowing() ? @"in" : @"missing", SGRPlayerField() ? @"made" : @"not made"]];
    });
    after(4, ^{
        [self->_list insertSubview:self->_plane atIndex:0];
        self->_units = [self->_units arrayByAddingObject:self->_background];
        [self layOut];
    });
    after(5, ^{
        UIView *motion = motionView();
        CALayer *foot = [motion valueForKey:@"_foot"], *clip = [motion valueForKey:@"_clip"];
        UIVisualEffectView *seam = [motion valueForKey:@"_seamBlur"];
        // The lyrics' blur is a filter on the clip, there only while the lyrics are up.
        BOOL lyricsBlurred = ((UIView *)[motion valueForKey:@"_picture"]).layer.filters.count > 0;
        [self expect:motion != nil && self->_covers.layer.mask != nil step:@"the player opened"
              detail:[NSString stringWithFormat:@"clip %@ the field, cover %@", motion ? @"on" : @"not on", self->_covers.layer.mask ? @"hidden" : @"shown"]];
        CGFloat seamAt = round(clip.frame.size.height * 0.9);
        BOOL footDown = foot && fabs(foot.frame.origin.y - seamAt) < 1 && CGRectGetMaxY(foot.frame) >= self.window.bounds.size.height
            && foot.backgroundColor && CGColorGetAlpha(foot.backgroundColor) == 1;
        [self expect:footDown step:@"the foot"
              detail:[NSString stringWithFormat:@"clip %@, foot %@, opaque mean color %@",
                      NSStringFromCGRect(clip.frame), NSStringFromCGRect(foot.frame),
                      foot.backgroundColor ? [UIColor colorWithCGColor:foot.backgroundColor] : nil]];
        NSString *footDetail = @"clip URL unavailable";
        NSURL *file = ((AVURLAsset *)((AVPlayer *)[motion valueForKey:@"_player"]).currentItem.asset).URL;
        BOOL meanColor = file && motionFootHasMeanColor(file, &footDetail);
        [self expect:meanColor step:@"the foot's mean color" detail:footDetail];
        // The poster under the video, so the clip has a picture before its first frame is decoded; and the
        // Fluid field under it held still and, the clip being opaque, hidden.
        CALayer *still = clip.superlayer;
        [self expect:still.contents && CGRectEqualToRect(still.bounds, clip.frame) && still.mask && SGRPlayerField().motionHeld
                     && fieldCovered()
                step:@"the poster and the held field"
              detail:[NSString stringWithFormat:@"poster %@ at %@, video %@, fade %@, field %@, %@", still.contents ? @"in" : @"missing",
                      NSStringFromCGRect(still.frame), NSStringFromCGRect(clip.frame), still.mask ? @"on the poster" : @"missing",
                      SGRPlayerField().motionHeld ? @"held" : @"moving", fieldCovered() ? @"its Fluid copies hidden" : @"its Fluid copies drawn"]];
        [self expect:seam.effect && !lyricsBlurred step:@"the blur from the seam"
              detail:[NSString stringWithFormat:@"seam blur %@, from %@ of the height, lyrics blur %@", seam.effect ? @"on" : @"off",
                      [[seam.maskView.layer.sublayers.firstObject valueForKey:@"locations"] componentsJoinedByString:@" to "], lyricsBlurred ? @"on" : @"off"]];
        // Dimmed by its brightness: HARNESS_DIM is what the clip in HARNESS_CANVAS_FILE should get (0.54 for white,
        // 0.10 for black); the rule itself is checked at its ends.
        CAGradientLayer *dim = [motion valueForKey:@"_dim"];
        // Only where text is: whole at the top and from the seam's blur down, clear between (issue #101).
        BOOL banded = dim && stopAlpha(dim, 1) == 1 && stopAlpha(dim, 2) == 0 && stopAlpha(dim, 4) == 1;
        const char *expected = getenv("HARNESS_DIM");
        BOOL rule = fabs(SGRPlayerClipDim(1, NO, NO) - 0.54) < 0.01 && fabs(SGRPlayerClipDim(1, YES, NO) - 0.65) < 0.01
                    && SGRPlayerClipDim(0, NO, NO) == 0.10 && fabs(SGRPlayerClipDim(0, NO, YES) - 0.25) < 1e-6
                    && fabs(SGRPlayerClipDim(0.5, NO, NO) - 0.37) < 0.01;
        self->_dimAlone = dim.opacity;
        [self expect:rule && banded && dim && dim.superlayer == clip.superlayer.superlayer && (!expected || fabs(dim.opacity - atof(expected)) < 0.02)
                step:@"the dim" detail:[NSString stringWithFormat:@"rule %@, dim %.2f %@%@", rule ? @"right" : @"wrong", dim.opacity,
                                        banded ? [NSString stringWithFormat:@"whole to %@ and from %@", dim.locations[1], dim.locations[4]] : @"not banded",
                                        expected ? [NSString stringWithFormat:@", %s expected", expected] : @""]];
        NSLog(@"[harness] motion: screenshot the clip now");
    });
    after(7, ^{ SGRPlayerToggleLyrics(); });
    after(8.5, ^{
        BOOL lyricsBlurred = ((UIView *)[motionView() valueForKey:@"_picture"]).layer.filters.count > 0;
        UIView *thumb = nil;
        for (UIView *view in self->_host.subviews) {
            if ([NSStringFromClass(view.class) isEqualToString:@"SGRPlayerLyricsOverlay"]) thumb = [view valueForKey:@"thumb"];
        }
        BOOL away = thumb && !CGAffineTransformIsIdentity(thumb.transform) && thumb.alpha > 0.99;
        CAGradientLayer *shade = [motionView() valueForKey:@"_dim"];
        float dim = shade.opacity;
        // The lyrics run down the whole screen, so the dim covers all of it.
        BOOL whole = shade && stopAlpha(shade, 2) == 1;
        [self expect:whole && fabsf(dim - self->_dimAlone - 0.15f) < 0.01f step:@"the dim under the lyrics"
              detail:[NSString stringWithFormat:@"%.2f, %.2f without them", dim, self->_dimAlone]];
        [self expect:SGRPlayerLyricsOpen() && lyricsBlurred && away step:@"the lyrics"
              detail:[NSString stringWithFormat:@"lyrics %@, clip blurred %@, thumbnail %@ at alpha %.2f", SGRPlayerLyricsOpen() ? @"up" : @"down",
                      lyricsBlurred ? @"yes" : @"no", thumb && !CGAffineTransformIsIdentity(thumb.transform) ? @"in its corner" : @"at the cover", thumb.alpha]];
        NSLog(@"[harness] motion: screenshot the lyrics now");
    });
    after(10, ^{ SGRPlayerToggleLyrics(); });
    // Spotify builds the player's background again: the clip goes onto the new field.
    after(11.5, ^{
        UIView *old = SGRPlayerField();
        UIView *plane = [[UIView alloc] initWithFrame:self->_plane.frame];
        UIViewController *background = [_TtC21NowPlaying_ScrollImpl27NPVBackgroundViewController new];
        background.view = plane;
        [self->_plane removeFromSuperview];
        [self->_list insertSubview:plane atIndex:0];
        self->_plane = plane;
        NSMutableArray *units = [self->_units mutableCopy];
        [units replaceObjectAtIndex:[units indexOfObject:self->_background] withObject:background];
        self->_units = units;
        self->_background = background;
        [self layOut];
        [self expect:SGRPlayerField() != old && motionView() != nil && fieldCovered() step:@"a field built again"
              detail:[NSString stringWithFormat:@"%@, its Fluid copies %@", motionView() ? @"the clip moved onto it" : @"the clip left behind",
                      fieldCovered() ? @"hidden" : @"drawn"]];
    });
    // Switched off, the clip and the cover cross over: the clip's fade out and the cover's fade in start
    // together, over the same time.
    after(12.5, ^{
        SGPlayerMenuSetAnimatedArtwork(NO);
        UIView *fading = motionView();
        CALayer *picture = ((UIView *)[fading valueForKey:@"_picture"]).layer, *mask = self->_covers.layer.mask;
        CAAnimation *out = [picture animationForKey:@"opacity"], *in = [mask animationForKey:@"opacity"];
        [self expect:!SGRPlayerMotionShowing() && fading && out && in && fabs(out.duration - in.duration) < 0.01 && picture.opacity == 0
                     && mask.opacity == 1 && !SGRPlayerField().motionHeld && !fieldCovered()
                step:@"switched off, crossing over"
              detail:[NSString stringWithFormat:@"clip %@ to %.0f over %.2f s, cover to %.0f over %.2f s, field %@, its Fluid copies %@", fading ? @"fading" : @"gone",
                      picture.opacity, out.duration, mask.opacity, in.duration, SGRPlayerField().motionHeld ? @"held" : @"moving",
                      fieldCovered() ? @"hidden" : @"drawn"]];
    });
    after(13.2, ^{
        [self expect:!SGRPlayerMotionShowing() && !motionView() && !self->_covers.layer.mask && !SGPlayerMenuAnimatedArtwork()
                step:@"switched off from the menu" detail:[NSString stringWithFormat:@"clip %@, cover %@", motionView() ? @"still there" : @"gone",
                                                                 self->_covers.layer.mask ? @"hidden" : @"back"]];
        SGPlayerMenuSetAnimatedArtwork(YES);
    });
    after(14.7, ^{
        // Faded in on screen this time, so the field is covered once the fade has finished.
        [self expect:motionView() && self->_covers.layer.mask && fieldCovered() step:@"switched on again"
              detail:[NSString stringWithFormat:@"clip %@, cover %@, its Fluid copies %@", motionView() ? @"back" : @"missing",
                      self->_covers.layer.mask ? @"hidden" : @"shown", fieldCovered() ? @"hidden" : @"drawn"]];
        // The player closed: the cover list cannot be found, and switching off must still bring its cover back.
        [self->_host removeFromSuperview];
        SGPlayerMenuSetAnimatedArtwork(NO);
        [self expect:!self->_covers.layer.mask step:@"switched off with the player closed" detail:self->_covers.layer.mask ? @"cover still hidden" : @"cover back"];
        [self->_list addSubview:self->_host];
    });
    after(15.7, ^{ SGPlayerMenuSetAnimatedArtwork(YES); });
    // The song paused and played again: the clip holds its frame, then moves on.
    after(17.2, ^{
        AVPlayer *player = [motionView() valueForKey:@"_player"];
        AVPlayerLayer *clip = [motionView() valueForKey:@"_clip"];
        [self expect:player.rate > 0 && clip.readyForDisplay step:@"playing" detail:[NSString stringWithFormat:@"clip at rate %.1f, %@", player.rate,
              clip.readyForDisplay ? @"drawn" : @"not drawn"]];
        SGRHarnessSetTrack(@"spotify:track:harnessA", imageURI(@"aaaa"), YES);
        AVPlayer *paused = [motionView() valueForKey:@"_player"];
        [self expect:motionView() && paused.rate == 0 step:@"paused" detail:[NSString stringWithFormat:@"clip %@ at rate %.1f",
              motionView() ? @"there" : @"gone", paused.rate]];
        SGRHarnessSetTrack(@"spotify:track:harnessA", imageURI(@"aaaa"), NO);
        [self expect:paused.rate > 0 step:@"played again" detail:[NSString stringWithFormat:@"rate %.1f", paused.rate]];
    });
    // Spotify's music video comes and goes: the clip goes for it, and comes back after.
    __block id video = nil;
    after(17.5, ^{
        video = [NSClassFromString(@"_TtC22NowPlaying_ElementsKit14VideoElementUI") new];
        [video videoSurfaceDidAttachVideo:nil];
    });
    after(18.5, ^{
        [self expect:!SGRPlayerMotionShowing() step:@"Spotify's video showing" detail:SGRPlayerMotionShowing() ? @"the clip stayed" : @"the clip went"];
        [video videoSurfaceDidDetachVideo:nil];
    });
    after(19.5, ^{
        [self expect:SGRPlayerMotionShowing() && self->_covers.layer.mask step:@"Spotify's video gone"
              detail:SGRPlayerMotionShowing() ? @"the clip back" : @"no clip"];
        // A track whose first state names no Canvas, as on a skip before Spotify's extended metadata.
        unsetenv("HARNESS_CANVAS");
        SGRHarnessSetTrack(@"spotify:track:harnessB", imageURI(@"bbbb"), NO);
    });
    after(20.5, ^{
        [self expect:!SGRPlayerMotionShowing() step:@"a track with no Canvas yet" detail:SGRPlayerMotionShowing() ? @"a clip left" : @"no clip"];
        setenv("HARNESS_CANVAS", "https://canvas.harness/clip.mp4", 1);
        SGRHarnessSetTrack(@"spotify:track:harnessB", imageURI(@"bbbb"), NO);
    });
    // A skip to a track whose clip is in the store: the clip stays for the next one to cross over it.
    __block UIView *before = nil;
    after(21.5, ^{
        [self expect:SGRPlayerMotionShowing() step:@"its Canvas came late" detail:SGRPlayerMotionShowing() ? @"the clip in" : @"no clip"];
        before = motionView();
        SGRHarnessSetTrack(@"spotify:track:harnessC", imageURI(@"cccc"), NO);
    });
    after(21.6, ^{
        [self expect:SGRPlayerMotionShowing() && self->_covers.layer.mask step:@"skipped, the clip kept a moment"
              detail:SGRPlayerMotionShowing() ? @"a clip in" : @"the cover back"];
    });
    after(22.3, ^{
        CALayer *mask = self->_covers.layer.mask;
        [self expect:SGRPlayerMotionShowing() && motionView() != before && mask && mask.opacity == 0 step:@"the next clip over the last"
              detail:[NSString stringWithFormat:@"%@, cover %@", motionView() != before ? @"a new clip" : @"the same clip", mask && mask.opacity == 0 ? @"still hidden" : @"back"]];
    });
    // Low Power Mode (Reduce Motion takes the same path): the clip goes for Fluid and the cover, and comes back
    // once it is off. The simulator has no Low Power Mode, so the process says it is on.
    __block BOOL lowPower = NO;
    after(22.5, ^{
        Class info = object_getClass(NSProcessInfo.processInfo);
        for (NSString *name in @[@"isLowPowerModeEnabled", @"lowPowerModeEnabled"]) {
            Method method = class_getInstanceMethod(info, NSSelectorFromString(name));
            if (method) method_setImplementation(method, imp_implementationWithBlock(^BOOL(id process) { return lowPower; }));
        }
        lowPower = YES;
        [NSNotificationCenter.defaultCenter postNotificationName:NSProcessInfoPowerStateDidChangeNotification object:nil];    });
    after(23.5, ^{
        [self expect:!SGRPlayerMotionShowing() && !motionView() && !self->_covers.layer.mask step:@"Low Power Mode"
              detail:[NSString stringWithFormat:@"clip %@, cover %@", motionView() ? @"still there" : @"gone", self->_covers.layer.mask ? @"hidden" : @"back"]];
        lowPower = NO;
        [NSNotificationCenter.defaultCenter postNotificationName:NSProcessInfoPowerStateDidChangeNotification object:nil];
    });
    // A track change with the app in the background: the last clip goes at once, with no fade to come back to.
    __block UIApplicationState state = UIApplicationStateActive;
    after(24.5, ^{
        [self expect:SGRPlayerMotionShowing() && self->_covers.layer.mask step:@"Low Power Mode off"
              detail:SGRPlayerMotionShowing() ? @"the clip back" : @"no clip"];
        Method method = class_getInstanceMethod(UIApplication.class, @selector(applicationState));
        method_setImplementation(method, imp_implementationWithBlock(^UIApplicationState(id app) { return state; }));
        state = UIApplicationStateBackground;
        unsetenv("HARNESS_CANVAS");
        SGRHarnessSetTrack(@"spotify:track:harnessD", imageURI(@"dddd"), NO);
    });
    after(24.6, ^{
        CALayer *mask = self->_covers.layer.mask;
        [self expect:!SGRPlayerMotionShowing() && !motionView() && !mask step:@"a track change in the background"
              detail:[NSString stringWithFormat:@"clip %@, cover %@", motionView() ? @"still there" : @"gone at once",
                      mask ? [NSString stringWithFormat:@"hidden, at %.2f", mask.opacity] : @"back at once"]];
        state = UIApplicationStateActive;
    });
    after(25, ^{
        NSLog(@"[harness] motion checks: %lu of %lu right -- %@", (unsigned long)(self->_checks - self->_failures), (unsigned long)self->_checks,
              self->_failures ? @"FAIL" : @"PASS");
        exit(self->_failures ? 1 : 0);
    });
}

#pragma mark - the cover's still

// A picture of one color, `pixels` wide and tall at scale 1, so its pixel width is exactly that.
static UIImage *solidPixels(UIColor *color, CGFloat pixels) {
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = 1;
    return [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(pixels, pixels) format:format] imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [color setFill];
        UIRectFill(CGRectMake(0, 0, pixels, pixels));
    }];
}

// The still behind the player: the full-screen view with no video, or nil while a clip or nothing is there.
static UIView *stillView(void) {
    UIView *view = motionView();
    return view && ![view valueForKey:@"_player"] && SGRPlayerMotionShowing() ? view : nil;
}

static CGImageRef stillPicture(void) {
    return (__bridge CGImageRef)((CALayer *)[stillView() valueForKey:@"_still"]).contents;
}

// The scrim any motion view draws over the status bar and the header's controls: its top opacity and height, or
// nil where none shows.
static NSString *scrimShown(void) {
    for (UIView *view in SGRPlayerField().subviews) {
        if (![NSStringFromClass(view.class) isEqualToString:@"SGRPlayerMotionView"]) continue;
        [view layoutIfNeeded];
        CALayer *scrim = [view valueForKey:@"_scrim"];
        if (!scrim.hidden && scrim.opacity > 0) return [NSString stringWithFormat:@"%.2f to %.0f pt", scrim.opacity, scrim.frame.size.height];
    }
    return nil;
}

static NSString *stillName(void) {
    CGImageRef picture = stillPicture();
    return picture ? [NSString stringWithFormat:@"%@ %zu px", colorName([UIImage imageWithCGImage:picture]), CGImageGetWidth(picture)] : @"no still";
}

// Animated with the full-screen cover switch: off first (the ordinary cover, as before), then on for a track with no
// clip, and every rule the still follows. HARNESS_CANVAS_FILE is the clip a later Canvas brings.
- (void)runStillChecks {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    void (^setStill)(BOOL) = ^(BOOL on) {
        [store setBool:on forKey:SGRKeyPlayerAnimatedStill];
        SGRPlayerStillChanged();
    };
    void (^background)(SGRPlayerBackgroundKind) = ^(SGRPlayerBackgroundKind kind) {
        SGRSetPlayerBackground(kind);
        SGRPlayerBackgroundDidChange();
        [self layOut];
    };
    BOOL (^ordinary)(void) = ^BOOL { return !SGRPlayerMotionShowing() && !self->_covers.layer.mask; };
    __block UIView *first = nil;
    __block BOOL lowPower = NO;
    UIImage *green = solidPixels(UIColor.greenColor, 600), *blue = solidPixels(UIColor.blueColor, 600),
            *yellow = solidPixels(UIColor.yellowColor, 299), *thumb = solidPixels(UIColor.magentaColor, 120),
            *magenta = solidPixels(UIColor.magentaColor, 300), *cyan = solidPixels(UIColor.cyanColor, 600);
    runScript(@[
        @[@3, ^{
            [self expect:ordinary() && !SGRPlayerStillOn() && !scrimShown() step:@"switched off, a track with no clip"
                  detail:[NSString stringWithFormat:@"%@, scrim %@", ordinary() ? @"the ordinary cover over Fluid" : @"something over the cover",
                          scrimShown() ?: @"none"]];
            NSLog(@"[harness] still: screenshot the ordinary cover now");
        }],
        @[@2, ^{
            setStill(YES);
            UIView *still = stillView();
            [still layoutIfNeeded];
            CALayer *picture = [still valueForKey:@"_still"];
            BOOL own = stillPicture() && stillPicture() == SGRNowPlayingArtwork(NULL, NULL).CGImage;
            CGFloat width = picture.bounds.size.width, tall = picture.bounds.size.height;
            [self expect:still && own && self->_covers.layer.mask && fabs(tall - round(width * 4 / 3)) < 1 && [still valueForKey:@"_dim"]
                    step:@"switched on: the cover as the still"
                  detail:[NSString stringWithFormat:@"%@, the Kit's cover %@, cover %@, picture %.0fx%.0f", stillName(), own ? @"yes" : @"no",
                          self->_covers.layer.mask ? @"hidden" : @"shown", width, tall]];
            CGPoint middle = [self.window convertPoint:CGPointMake(CGRectGetMidX(self->_tilt.bounds), CGRectGetMidY(self->_tilt.bounds)) fromView:self->_tilt];
            UIView *hit = [self.window hitTest:middle withEvent:nil];
            [self expect:[hit isDescendantOfView:self->_tilt] step:@"a tap on the hidden cover"
                  detail:[NSString stringWithFormat:@"lands on %@", NSStringFromClass(hit.class)]];
            // 45% black at the top, gone 76 pt under the safe area's top (the design review's numbers).
            NSString *want = [NSString stringWithFormat:@"0.45 to %.0f pt", self.window.safeAreaInsets.top + 76];
            [self expect:[scrimShown() isEqualToString:want] step:@"the still's scrim"
                  detail:[NSString stringWithFormat:@"%@, want %@", scrimShown() ?: @"none", want]];
            first = still;
        }],
        @[@2, ^{
            UIVisualEffectView *seam = [stillView() valueForKey:@"_seamBlur"];
            [self expect:stillView() && fieldCovered() && seam.effect step:@"faded in" detail:[NSString stringWithFormat:@"field %@, seam blur %@",
                  fieldCovered() ? @"covered" : @"drawn", seam.effect ? @"on" : @"off"]];
            NSLog(@"[harness] still: screenshot the still now");
        }],
        // Time for the screenshot before the lyrics open.
        @[@4, ^{ SGRPlayerToggleLyrics(); }],
        @[@1.5, ^{
            BOOL blurred = ((UIView *)[stillView() valueForKey:@"_picture"]).layer.filters.count > 0;
            [self expect:SGRPlayerLyricsOpen() && blurred step:@"behind the lyrics" detail:blurred ? @"the still blurred" : @"the still sharp"];
            SGRPlayerToggleLyrics();
        }],
        @[@1.5, ^{
            // The same track and cover told again: the still is kept, not made again.
            SGRHarnessSetTrack(@"spotify:track:harnessA", imageURI(@"aaaa"), NO);
            SGRPlayerStillChanged();
            // A still made again would leave the first fading out beside a new one.
            NSUInteger views = [SGRPlayerField().subviews indexesOfObjectsPassingTest:^BOOL(UIView *view, NSUInteger i, BOOL *stop) {
                return [NSStringFromClass(view.class) isEqualToString:@"SGRPlayerMotionView"];
            }].count;
            [self expect:stillView() == first && views == 1 step:@"the same cover again"
                  detail:[NSString stringWithFormat:@"%@, %lu views", stillView() == first ? @"the same still" : @"another still", (unsigned long)views]];
            // Two skips in a row, each cover answering late, the first one's last.
            serve(imageURI(@"bbbb"), green, 1.0, NO);
            serve(imageURI(@"cccc"), blue, 1.5, NO);
            [self playTrack:@"spotify:track:harnessB" image:imageURI(@"bbbb")];
        }],
        @[@0.1, ^{ [self playTrack:@"spotify:track:harnessC" image:imageURI(@"cccc")]; }],
        @[@0.8, ^{
            [self expect:ordinary() step:@"skipped twice, the cover not in" detail:stillPicture() ? stillName() : @"the ordinary cover"];
        }],
        @[@1.6, ^{
            [self expect:[stillName() isEqualToString:@"blue 600 px"] step:@"the last track's cover in" detail:stillName()];
            serve(imageURI(@"dddd"), yellow, 0.2, NO);
            [self playTrack:@"spotify:track:harnessD" image:imageURI(@"dddd")];
            [self showOnScreen:yellow];
        }],
        @[@1.5, ^{
            [self expect:ordinary() && [colorName(SGRNowPlayingArtwork(NULL, NULL)) isEqualToString:@"yellow"] step:@"a cover 299 px wide"
                  detail:ordinary() ? @"the ordinary cover" : stillName()];
            // The screens' small cover first, the 300 px one late.
            serve(imageURI(@"eeee"), magenta, 2.0, NO);
            [self playTrack:@"spotify:track:harnessE" image:imageURI(@"eeee")];
            [self showOnScreen:thumb];
        }],
        @[@1, ^{
            UIImage *kit = SGRNowPlayingArtwork(NULL, NULL);
            [self expect:ordinary() && kit.size.width * kit.scale == 120 step:@"the 120 px thumbnail only"
                  detail:[NSString stringWithFormat:@"%@, the Kit's cover %.0f px", ordinary() ? @"the ordinary cover" : stillName(), kit.size.width * kit.scale]];
        }],
        @[@2, ^{
            [self expect:[stillName() isEqualToString:@"magenta 300 px"] step:@"the 300 px cover came late" detail:stillName()];
            // Its Canvas turns up: the clip replaces the still.
            setenv("HARNESS_CANVAS", [NSString stringWithFormat:@"https://canvas.harness/still-%d.mp4", getpid()].UTF8String, 1);
            SGRHarnessSetTrack(@"spotify:track:harnessE", imageURI(@"eeee"), NO);
        }],
        @[@2.5, ^{
            UIView *motion = motionView();
            BOOL clip = SGRPlayerMotionShowing() && motion && [motion valueForKey:@"_player"] && !stillView();
            [self expect:clip step:@"a clip came late" detail:clip ? @"the clip over the still's place" : stillName()];
            [self expect:clip && !scrimShown() step:@"no scrim over the clip" detail:scrimShown() ?: @"none"];
            unsetenv("HARNESS_CANVAS");
            serve(imageURI(@"ffff"), cyan, 0.2, NO);
            [self playTrack:@"spotify:track:harnessF" image:imageURI(@"ffff")];
        }],
        @[@1.5, ^{
            [self expect:[stillName() isEqualToString:@"cyan 600 px"] step:@"the next track without a clip" detail:stillName()];
            background(SGRPlayerBackgroundBlack);
        }],
        @[@1.5, ^{
            [self expect:!SGRPlayerMotionShowing() && SGRPlayerBackdropShowing() step:@"black wins"
                  detail:[NSString stringWithFormat:@"%@, black %@", stillName(), SGRPlayerBackdropShowing() ? @"over the field" : @"missing"]];
            background(SGRPlayerBackgroundPhoto);
        }],
        @[@1.5, ^{
            [self expect:!SGRPlayerMotionShowing() && SGRPlayerBackdropShowing() step:@"the photo wins" detail:stillName()];
            background(SGRPlayerBackgroundAnimated);
        }],
        @[@1.5, ^{
            [self expect:[stillName() isEqualToString:@"cyan 600 px"] step:@"Animated again" detail:stillName()];
            SGRPlayerMenuSetBackground(SGRPlayerBackgroundVisualiser);
        }],
        @[@1.5, ^{
            [self expect:!SGRPlayerMotionShowing() && SGRPlayerVisualiserShowing() step:@"the Visualizer, no still" detail:stillName()];
            SGRPlayerMenuSetBackground(SGRPlayerBackgroundAnimated);
        }],
        @[@1.5, ^{
            [self expect:[stillName() isEqualToString:@"cyan 600 px"] step:@"back from the Visualizer" detail:stillName()];
            // Low Power Mode, which the process is made to report (Reduce Motion takes the same path, motionAllowed).
            Class info = object_getClass(NSProcessInfo.processInfo);
            for (NSString *name in @[@"isLowPowerModeEnabled", @"lowPowerModeEnabled"]) {
                Method method = class_getInstanceMethod(info, NSSelectorFromString(name));
                if (method) method_setImplementation(method, imp_implementationWithBlock(^BOOL(id process) { return lowPower; }));
            }
            lowPower = YES;
            [NSNotificationCenter.defaultCenter postNotificationName:NSProcessInfoPowerStateDidChangeNotification object:nil];
        }],
        @[@1.5, ^{
            [self expect:ordinary() step:@"Low Power Mode keeps the cover" detail:ordinary() ? @"the ordinary cover" : stillName()];
            // The Kit telling of a cover meanwhile does not bring the still back either.
            [NSNotificationCenter.defaultCenter postNotificationName:SGRNowPlayingArtworkDidChangeNotification object:nil];
            [self expect:ordinary() step:@"a cover in under Low Power Mode" detail:ordinary() ? @"the ordinary cover" : stillName()];
            lowPower = NO;
            [NSNotificationCenter.defaultCenter postNotificationName:NSProcessInfoPowerStateDidChangeNotification object:nil];
        }],
        @[@1.5, ^{
            [self expect:[stillName() hasPrefix:@"cyan"] step:@"Low Power Mode off" detail:stillName()];
            setStill(NO);
        }],
        @[@1.5, ^{
            // Faded out with the still.
            [self expect:ordinary() && !scrimShown() step:@"switched off again"
                  detail:[NSString stringWithFormat:@"%@, scrim %@", ordinary() ? @"the ordinary cover" : stillName(), scrimShown() ?: @"none"]];
            NSLog(@"[harness] still checks: %lu of %lu right -- %@", (unsigned long)(self->_checks - self->_failures), (unsigned long)self->_checks,
                  self->_failures ? @"FAIL" : @"PASS");
            exit(self->_failures ? 1 : 0);
        }],
    ], 0);
}

#pragma mark - Apple Music's catalog

static NSData *catalogAlbums(NSArray<NSArray<NSString *> *> *albums) {
    NSMutableArray *data = [NSMutableArray array];
    for (NSArray<NSString *> *album in albums) {
        [data addObject:@{@"attributes": @{@"name": album[0], @"artistName": album[1],
                                           @"editorialVideo": @{@"motionTallVideo3x4": @{@"video": album[2]}}}}];
    }
    return [NSJSONSerialization dataWithJSONObject:@{@"results": @{@"albums": @{@"data": data}}} options:0 error:nil];
}

static NSString *termOf(NSURL *url) {
    for (NSURLQueryItem *item in [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO].queryItems) {
        if ([item.name isEqualToString:@"term"]) return item.value;
    }
    return nil;
}

// The album search's term without the edition, the album of the same name before another edition, and the pause
// after a 429: nothing asked of the catalog for the next album, which finds nothing at once.
- (void)runCatalogChecks {
    sg_catalogAsked = [NSMutableArray array];
    sg_canvasAsked = [NSMutableArray array];
    // A web player token that has not run out, so no browse page is read.
    NSString *(^part)(NSString *) = ^NSString *(NSString *json) {
        NSString *base = [[json dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
        return [[[base stringByReplacingOccurrencesOfString:@"+" withString:@"-"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"]
                stringByReplacingOccurrencesOfString:@"=" withString:@""];
    };
    NSString *token = [NSString stringWithFormat:@"%@.%@.c2ln", part(@"{\"alg\":\"none\"}"), part(@"{\"iss\":\"AMPWebPlay\",\"exp\":4102444800}")];
    [NSUserDefaults.standardUserDefaults setObject:token forKey:@"spotifyglass.motion.token"];

    NSDictionary<NSString *, NSString *> *names = @{
        @"Abbey Road (Remastered)": @"Abbey Road", @"Rumours - 2004 Remaster": @"Rumours", @"[Deluxe]": @"[Deluxe]",
        @"Thriller 25 [Super Deluxe Edition] (Remastered)": @"Thriller 25", @"Midnights": @"Midnights",
    };
    __block BOOL namesRight = YES;
    [names enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *searched, BOOL *stop) {
        if (![SGMotionSearchName(name) isEqualToString:searched]) {
            namesRight = NO;
            NSLog(@"[harness] catalog: %@ searched as \"%@\", not \"%@\"", name, SGMotionSearchName(name), searched);
        }
    }];
    [self expect:namesRight step:@"search names" detail:namesRight ? @"editions taken off" : @"see above"];

    sg_catalogBody = catalogAlbums(@[@[@"Midnights", @"Taylor Swift", @"https://canvas.harness/standard.m3u8"],
                                     @[@"Midnights (3am Edition)", @"Taylor Swift", @"https://canvas.harness/3am.m3u8"]]);
    after(1, ^{ SGMotionAlbumCover(@"Taylor Swift", @"Midnights (3am Edition)", 600, ^(NSURL *file) {}); });
    after(2.5, ^{
        NSString *term = termOf(sg_catalogAsked.firstObject), *master = sg_canvasAsked.firstObject.lastPathComponent;
        [self expect:sg_catalogAsked.count == 1 && [term isEqualToString:@"Taylor Swift Midnights"] step:@"the term"
              detail:[NSString stringWithFormat:@"%lu asked, \"%@\"", (unsigned long)sg_catalogAsked.count, term]];
        [self expect:[master isEqualToString:@"3am.m3u8"] step:@"the album of the same name first" detail:master ?: @"none asked"];
        sg_catalogStatus = 429;
        SGMotionAlbumCover(@"Artist X", @"Album One", 600, ^(NSURL *file) {});
    });
    __block BOOL answered = NO;
    after(4, ^{
        [self expect:sg_catalogAsked.count == 2 step:@"a 429" detail:[NSString stringWithFormat:@"%lu asked", (unsigned long)sg_catalogAsked.count]];
        sg_catalogStatus = 200;
        SGMotionAlbumCover(@"Artist X", @"Album Two", 600, ^(NSURL *file) { answered = !file; });
    });
    after(5, ^{
        [self expect:sg_catalogAsked.count == 2 && answered step:@"paused after it"
              detail:[NSString stringWithFormat:@"%lu asked, the next album %@", (unsigned long)sg_catalogAsked.count, answered ? @"found nothing at once" : @"waits"]];
        NSLog(@"[harness] catalog checks: %lu of %lu right -- %@", (unsigned long)(self->_checks - self->_failures), (unsigned long)self->_checks,
              self->_failures ? @"FAIL" : @"PASS");
    });
}

static UIView *firstOfClass(UIView *root, NSString *name) {
    if ([NSStringFromClass(root.class) isEqualToString:name]) return root;
    for (UIView *sub in root.subviews) {
        UIView *found = firstOfClass(sub, name);
        if (found) return found;
    }
    return nil;
}

// What the Player page's card (PlayerSettings.m, SGRPlayerPreview) draws that is cut off or in another part's room at its
// size: nil when the header, the cover and the words, the progress, the times and the transport row each sit whole in
// their own band, inside the card.
static NSString *cardClipping(UIView *card) {
    [card layoutIfNeeded];
    CGRect bounds = CGRectInset(card.bounds, -0.5, -0.5);
    NSMutableArray<NSString *> *wrong = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSValue *> *frames = [NSMutableDictionary dictionary];
    for (NSString *name in @[@"_close", @"_more", @"_cover", @"_chip", @"_title", @"_artist", @"_add", @"_progress", @"_elapsed", @"_remaining",
                             @"_shuffle", @"_previous", @"_play", @"_next", @"_repeat", @"_demoButton"]) {
        UIView *view = [card valueForKey:name];
        if (view.hidden || view.alpha < 0.01) continue;
        CGRect frame = [view.superview convertRect:view.frame toView:card];
        frames[name] = [NSValue valueWithCGRect:frame];
        if (!CGRectContainsRect(bounds, frame) || frame.size.width < 1 || frame.size.height < 1)
            [wrong addObject:[NSString stringWithFormat:@"%@ %@ not whole in the card", name, NSStringFromCGRect(frame)]];
    }
    CGRect (^at)(NSString *) = ^CGRect(NSString *name) { return frames[name] ? frames[name].CGRectValue : CGRectNull; };
    CGRect words = CGRectUnion(at(@"_chip"), CGRectUnion(at(@"_title"), at(@"_artist")));
    CGRect upper = CGRectUnion(words, at(@"_cover"));
    CGRect transport = CGRectNull;
    for (NSString *name in @[@"_shuffle", @"_previous", @"_play", @"_next", @"_repeat"]) transport = CGRectUnion(transport, at(name));
    if (CGRectGetMinY(upper) < CGRectGetMaxY(at(@"_close")) - 0.5) [wrong addObject:@"the cover or the words under the header"];
    if (CGRectGetMaxY(upper) > CGRectGetMinY(at(@"_progress")) + 0.5) [wrong addObject:@"the cover or the words over the progress"];
    if (CGRectGetMaxY(CGRectUnion(at(@"_elapsed"), at(@"_remaining"))) > CGRectGetMinY(transport) + 0.5) [wrong addObject:@"the times over the transport row"];
    if (CGRectGetMaxX(words) > CGRectGetMinX(at(@"_add")) + 0.5) [wrong addObject:@"the words under the add button"];
    if (CGRectIntersectsRect(CGRectInset(at(@"_cover"), 0.5, 0.5), words)) [wrong addObject:@"the cover over the words"];
    NSArray<NSString *> *row = @[@"_shuffle", @"_previous", @"_play", @"_next", @"_repeat"];
    for (NSUInteger i = 0; i + 1 < row.count; i++) {
        if (frames[row[i]] && frames[row[i + 1]] && CGRectIntersectsRect(at(row[i]), at(row[i + 1]))) [wrong addObject:[NSString stringWithFormat:@"%@ over %@", row[i], row[i + 1]]];
    }
    UILabel *chipLabel = [card valueForKey:@"_chipLabel"];
    if (frames[@"_chip"] && chipLabel.intrinsicContentSize.width > chipLabel.bounds.size.width + 0.5) [wrong addObject:@"Switch to video cut short"];
    return wrong.count ? [wrong componentsJoinedByString:@"; "] : nil;
}

// The track the player has and whether it is paused: what the card must never change.
static NSString *playerNow(void) {
    SPTPlayerState *state = SGPlayerState();
    return [NSString stringWithFormat:@"%@ %@", SGURIString(state.track.URI), state.isPaused ? @"paused" : @"playing"];
}

// The mod's stored settings, to tell which ones a step changed.
static NSDictionary<NSString *, id> *storedSettings(void) {
    NSMutableDictionary<NSString *, id> *settings = [NSMutableDictionary dictionary];
    [NSUserDefaults.standardUserDefaults.dictionaryRepresentation enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        if ([key hasPrefix:@"spotifyglass."] && ![key isEqualToString:@"spotifyglass.lastTrack"] && ![key isEqualToString:@"spotifyglass.settings.seenNew"]) settings[key] = value;
    }];
    return settings;
}

static NSArray<NSString *> *changedSettings(NSDictionary *before, NSDictionary *after) {
    NSMutableSet<NSString *> *keys = [NSMutableSet setWithArray:before.allKeys];
    [keys addObjectsFromArray:after.allKeys];
    NSMutableArray<NSString *> *changed = [NSMutableArray array];
    for (NSString *key in keys) if (![before[key] isEqual:after[key]]) [changed addObject:key];
    return [changed sortedArrayUsingSelector:@selector(compare:)];
}

// Moments both Song without a clip switches were stored on, counted as each write lands.
static NSUInteger sg_bothOn;

// Performance/lifetime probes at UIKit's layout/geometry and the palette service boundaries.
static BOOL sg_watchPreviewWork, sg_watchPreviewPalette, sg_insidePreviewArtwork;
static __weak UIView *sg_watchedPreview;
static NSHashTable<UIView *> *sg_watchedBackgrounds;
static NSHashTable<UIView *> *sg_watchedTextSizeViews;
static NSUInteger sg_previewLayouts, sg_backgroundResizes, sg_previewMeasurements, sg_previewPaletteRequests;

static void installSettingsWorkProbes(void) {
    Class preview = NSClassFromString(@"SGRPlayerPreview");
    Method layout = class_getInstanceMethod(preview, @selector(layoutSubviews));
    IMP oldLayout = method_getImplementation(layout);
    method_setImplementation(layout, imp_implementationWithBlock(^(UIView *view) {
        if (sg_watchPreviewWork && view == sg_watchedPreview) sg_previewLayouts++;
        ((void (*)(id, SEL))oldLayout)(view, @selector(layoutSubviews));
    }));
    for (NSString *name in @[@"setFrame:", @"setBounds:"]) {
        SEL selector = NSSelectorFromString(name);
        Method method = class_getInstanceMethod(UIView.class, selector);
        IMP original = method_getImplementation(method);
        method_setImplementation(method, imp_implementationWithBlock(^(UIView *view, CGRect rect) {
            CGSize before = view.bounds.size;
            ((void (*)(id, SEL, CGRect))original)(view, selector, rect);
            if (sg_watchPreviewWork && [sg_watchedBackgrounds containsObject:view] && !CGSizeEqualToSize(before, view.bounds.size))
                sg_backgroundResizes++;
        }));
    }
    for (Class type in @[UIButton.class, UILabel.class]) {
        SEL selector = @selector(sizeThatFits:);
        Method method = class_getInstanceMethod(type, selector);
        IMP original = method_getImplementation(method);
        IMP probe = imp_implementationWithBlock(^CGSize(UIView *view, CGSize size) {
            if (sg_watchPreviewWork && [sg_watchedTextSizeViews containsObject:view]) sg_previewMeasurements++;
            return ((CGSize (*)(id, SEL, CGSize))original)(view, selector, size);
        });
        if (!class_addMethod(type, selector, probe, method_getTypeEncoding(method))) method_setImplementation(method, probe);
    }
    Method artwork = class_getInstanceMethod(NSClassFromString(@"SGRVisualiserView"), @selector(artworkChanged));
    IMP oldArtwork = method_getImplementation(artwork);
    method_setImplementation(artwork, imp_implementationWithBlock(^(UIView *view) {
        BOOL previous = sg_insidePreviewArtwork;
        sg_insidePreviewArtwork = [[view valueForKey:@"sample"] boolValue];
        ((void (*)(id, SEL))oldArtwork)(view, @selector(artworkChanged));
        sg_insidePreviewArtwork = previous;
    }));
    SEL selector = @selector(paletteForImage:request:completion:);
    Method palette = class_getClassMethod(SGRPalette.class, selector);
    IMP oldPalette = method_getImplementation(palette);
    method_setImplementation(palette, imp_implementationWithBlock(^(id owner, UIImage *image, SGRPaletteRequest request, void (^done)(SGRPalette *)) {
        if (sg_watchPreviewPalette && sg_insidePreviewArtwork) sg_previewPaletteRequests++;
        ((void (*)(id, SEL, UIImage *, SGRPaletteRequest, void (^)(SGRPalette *)))oldPalette)(owner, selector, image, request, done);
    }));
}

// The redesign's Player page over the player, with the clip of `motion` in. Song without a clip: what it reads from
// the two switches, and each choice leaving the other off at every write; the pinned card, its demo, and that neither
// sends the player anything; the card refreshed for another track with late answers dropped, paused while the page
// is covered, stopped once it is closed; the Buttons chips; and the card and the chips laid out whole at narrow widths
// and the largest text. Each state a screenshot is asked for (`settings: screenshot <name> now`) holds two seconds.
- (void)runSettingsChecks {
    installSettingsWorkProbes();
    __block UINavigationController *nav;
    __block __weak UIView *closedCard;
    __block __weak UIView *closedDecoder;
    __block __weak UIView *closedVisualiser;
    __block NSUInteger latePreviewCallbacks = 0;
    SGModPage *(^page)(void) = ^{ return (SGModPage *)nav.viewControllers.firstObject; };
    UITableView *(^table)(void) = ^{ return page().tableView; };
    UIView *(^card)(void) = ^{ return firstOfClass(table(), @"SGRPlayerPreview"); };
    UISegmentedControl *(^segments)(void) = ^{ return (UISegmentedControl *)firstOfClass(table().tableHeaderView, @"UISegmentedControl"); };
    void (^pick)(NSUInteger) = ^(NSUInteger index) {
        segments().selectedSegmentIndex = (NSInteger)index;
        [segments() sendActionsForControlEvents:UIControlEventValueChanged];
    };
    SGModRow *(^rowTitled)(NSString *) = ^SGModRow *(NSString *title) {
        for (SGModSection *section in page().sections) for (SGModRow *row in section.rows) if ([row.title isEqualToString:title]) return row;
        return nil;
    };
    NSIndexPath *(^pathOf)(SGModRow *) = ^NSIndexPath *(SGModRow *row) {
        NSArray<NSArray *> *shown = [page() valueForKey:@"_shown"];
        for (NSUInteger s = 0; s < shown.count; s++) {
            NSUInteger r = [shown[s] indexOfObjectIdenticalTo:row];
            if (r != NSNotFound) return [NSIndexPath indexPathForRow:(NSInteger)r inSection:(NSInteger)s];
        }
        return nil;
    };
    UITableViewCell *(^cellOf)(SGModRow *) = ^UITableViewCell *(SGModRow *row) {
        NSIndexPath *path = pathOf(row);
        if (!path) return nil;
        [table() scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionBottom animated:NO];
        [table() layoutIfNeeded];
        return [table() cellForRowAtIndexPath:path];
    };
    SGModRow *(^noClip)(void) = ^{ return rowTitled(@"Song without a clip"); };
    // A choice of Song without a clip as its menu makes it: the row's block, then the page read again.
    void (^choose)(NSInteger) = ^(NSInteger index) {
        noClip().chosen(index);
        [table() reloadData];
    };
    void (^checkScrollWork)(void) = ^{
        sg_watchedPreview = card();
        sg_watchedBackgrounds = [NSHashTable weakObjectsHashTable];
        sg_watchedTextSizeViews = [NSHashTable weakObjectsHashTable];
        [sg_watchedTextSizeViews addObject:[card() valueForKey:@"_demoButton"]];
        [sg_watchedTextSizeViews addObject:[card() valueForKey:@"_chipLabel"]];
        for (NSString *type in @[@"SGRArtworkField", @"SGRPlayerMotionView", @"SGRVisualiserView"]) {
            UIView *view = firstOfClass(card(), type);
            if (view) [sg_watchedBackgrounds addObject:view];
        }
        [table() setContentOffset:CGPointMake(0, -table().adjustedContentInset.top) animated:NO];
        [page().view layoutIfNeeded];
        [card() layoutIfNeeded];
        sg_previewLayouts = sg_backgroundResizes = sg_previewMeasurements = 0;
        sg_watchPreviewWork = YES;
        for (NSInteger y = 0; y <= 280; y += 20) {
            [table() setContentOffset:CGPointMake(0, y - table().adjustedContentInset.top) animated:NO];
            [page().view setNeedsLayout];
            [page().view layoutIfNeeded];
            [card() layoutIfNeeded];
        }
        sg_watchPreviewWork = NO;
        [self expect:card().bounds.size.height == 236 && sg_backgroundResizes == 0 && sg_previewMeasurements == 0
                step:@"collapsing does no background resize or text measurement"
              detail:[NSString stringWithFormat:@"%lu resizes, %lu measurements", (unsigned long)sg_backgroundResizes, (unsigned long)sg_previewMeasurements]];
        sg_previewLayouts = sg_backgroundResizes = sg_previewMeasurements = 0;
        sg_watchPreviewWork = YES;
        for (NSInteger y = 300; y <= 600; y += 20) {
            [table() setContentOffset:CGPointMake(0, y - table().adjustedContentInset.top) animated:NO];
            [page().view setNeedsLayout];
            [page().view layoutIfNeeded];
            [card() layoutIfNeeded];
        }
        sg_watchPreviewWork = NO;
        [self expect:sg_previewLayouts == 0 && sg_backgroundResizes == 0 && sg_previewMeasurements == 0
                step:@"compact scrolling does no preview layout or background resize"
              detail:[NSString stringWithFormat:@"%lu layouts, %lu resizes, %lu measurements", (unsigned long)sg_previewLayouts,
                      (unsigned long)sg_backgroundResizes, (unsigned long)sg_previewMeasurements]];
        sg_watchedPreview = nil;
        sg_watchedBackgrounds = nil;
        sg_watchedTextSizeViews = nil;
    };
    SGModRow *(^buttonsRow)(void) = ^{ return rowTitled(@"Buttons"); };
    NSArray<UIButton *> *(^chips)(void) = ^NSArray<UIButton *> *{
        NSMutableArray<UIButton *> *found = [NSMutableArray array];
        for (UIView *view in cellOf(buttonsRow()).contentView.subviews) if ([view isKindOfClass:UIButton.class]) [found addObject:(UIButton *)view];
        return found;
    };
    UIView *(^motionOn)(void) = ^{ return firstOfClass(card(), @"SGRPlayerMotionView"); };
    UIView *(^hillsOn)(void) = ^{ return firstOfClass(card(), @"SGRVisualiserView"); };
    BOOL (^stillShown)(void) = ^BOOL { return ![[card() valueForKey:@"_still"] isHidden] && [[card() valueForKey:@"_cover"] alpha] < 0.01; };
    BOOL (^demo)(void) = ^BOOL { return [[card() valueForKey:@"demo"] boolValue]; };
    NSString *(^cardState)(void) = ^{
        SGRArtworkField *field = (SGRArtworkField *)firstOfClass(card(), @"SGRArtworkField");
        return [NSString stringWithFormat:@"card %@, demo %d, clip %@, hills %@, full-screen cover %@, field held %d; player %@, %lu commands; \"%@\"",
                NSStringFromCGRect(card().frame), demo(), motionOn() ? @"on" : @"off", hillsOn() ? @"on" : @"off", stillShown() ? @"on" : @"off",
                field.motionHeld, playerNow(), (unsigned long)SGRHarnessPlayerCommands(), [[card() valueForKey:@"_canvas"] accessibilityValue]];
    };
    BOOL (^stored)(NSString *) = ^BOOL(NSString *key) { return [NSUserDefaults.standardUserDefaults boolForKey:key]; };
    NSString *(^switches)(void) = ^{
        return [NSString stringWithFormat:@"full-screen cover %@, Visualizer %@", [NSUserDefaults.standardUserDefaults objectForKey:SGRKeyPlayerAnimatedStill] ?: @"unset",
                [NSUserDefaults.standardUserDefaults objectForKey:SGRKeyPlayerAnimatedVisualiser] ?: @"unset"];
    };
    void (^reread)(void) = ^{
        [page() viewWillAppear:NO];
        [table() layoutIfNeeded];
    };
    void (^open)(void) = ^{
        nav = [[UINavigationController alloc] initWithRootViewController:SGRPlayerSettingsPage(@[SGRPlayerButtonsSection()])];
        // Keep the real player in its window: its intentional old-clip handover must not reach the preview.
        nav.modalPresentationStyle = UIModalPresentationOverFullScreen;
        [self.window.rootViewController presentViewController:nav animated:NO completion:nil];
    };
    // Asked for once the state's crossfades are over.
    void (^shot)(NSString *) = ^(NSString *name) { after(1, ^{ NSLog(@"[harness] settings: screenshot %@ now", name); }); };
    // The card's height in the window, and its top against the navigation bar's foot.
    NSString *(^pinned)(void) = ^{
        CGRect frame = [card() convertRect:card().bounds toView:self.window];
        return [NSString stringWithFormat:@"card %@ in the window, bar's foot %.0f, offset %.0f", NSStringFromCGRect(frame),
                CGRectGetMaxY([nav.navigationBar convertRect:nav.navigationBar.bounds toView:self.window]), table().contentOffset.y];
    };
    CGFloat (^cardTop)(void) = ^CGFloat { return CGRectGetMinY([card() convertRect:card().bounds toView:self.window]); };
    CGFloat (^barFoot)(void) = ^CGFloat { return CGRectGetMaxY([nav.navigationBar convertRect:nav.navigationBar.bounds toView:self.window]); };
    __block NSString *playerBefore;
    __block NSDictionary *settingsBefore;
    __block NSURL *fileC;

    [NSNotificationCenter.defaultCenter addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        if (stored(SGRKeyPlayerAnimatedStill) && stored(SGRKeyPlayerAnimatedVisualiser)) sg_bothOn++;
    }];

    NSMutableArray<NSArray *> *script = [NSMutableArray array];
    void (^step)(NSTimeInterval, dispatch_block_t) = ^(NSTimeInterval delay, dispatch_block_t block) { [script addObject:@[@(delay), block]]; };

    // The clip is in by 3 s (the motion scenario's first step), and the page opens over the player then.
    step(3, ^{ open(); });
    step(1.5, ^{
        playerBefore = playerNow();
        CGFloat height = card().frame.size.height;
        BOOL inTable = card().window && card().superview.superview == table() && fabs(cardTop() - barFoot() - 8) < 1;
        BOOL under = CGRectGetMinY([segments() convertRect:segments().bounds toView:self.window]) > CGRectGetMaxY([card() convertRect:card().bounds toView:self.window]);
        [self expect:inTable && under && fabs(height - 480) < 1 && segments().numberOfSegments == 5 step:@"the card pinned over the rows, expanded, the backgrounds under it"
              detail:[NSString stringWithFormat:@"%@, height %.0f, segments %@", pinned(), height, NSStringFromCGRect(segments().frame)]];
        [self expect:motionOn() && !demo() && [[[card() valueForKey:@"_canvas"] accessibilityValue] isEqualToString:@"Animated background"]
                step:@"Animated: the player's clip on the card" detail:cardState()];
        [self expect:[[[card() valueForKey:@"_title"] text] isEqualToString:@"Loose Canon"]
                     && [[[card() valueForKey:@"_artist"] text] isEqualToString:@"Vitrine harness"]
                     && [[[card() valueForKey:@"_elapsed"] text] isEqualToString:@"1:15"]
                     && [[[card() valueForKey:@"_remaining"] text] isEqualToString:@"-2:45"]
                step:@"the actual current song, artist, elapsed and remaining time" detail:cardState()];
        NSString *clipping = cardClipping(card());
        [self expect:!clipping step:@"the expanded card whole" detail:clipping ?: @"every part in its band"];
        UIButton *toggle = [card() valueForKey:@"_demoButton"];
        [self expect:!toggle.hidden && (toggle.accessibilityTraits & UIAccessibilityTraitButton) && [toggle.accessibilityLabel isEqualToString:@"Preview without a clip"]
                     && [[card() valueForKey:@"_canvas"] isAccessibilityElement] && [[[card() valueForKey:@"_canvas"] accessibilityLabel] isEqualToString:@"Player preview"]
                step:@"VoiceOver: the card one element, the demo a button" detail:[NSString stringWithFormat:@"button \"%@\" traits %llu", toggle.accessibilityLabel, toggle.accessibilityTraits]];
        [self expect:[noClip().value() isEqualToString:@"Cover art"] && noClip().menu.count == 3 && pathOf(noClip()) && !rowTitled(@"Full-screen cover without a clip") && !rowTitled(@"Visualizer when there's no clip")
                step:@"one Song without a clip choice, Cover art with both switches unset" detail:[NSString stringWithFormat:@"reads %@ of %@; %@", noClip().value(), noClip().menu, switches()]];
        shot(@"expanded");
    });
    // Covered by another page, the card does nothing; the background's switches changed meanwhile, as elsewhere.
    step(2.5, ^{
        closedDecoder = motionOn();
        [nav pushViewController:[UIViewController new] animated:NO];
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:SGRKeyPlayerAnimatedStill];
    });
    step(0.5, ^{
        [self expect:![[card() valueForKey:@"_active"] boolValue] && !motionOn() && !hillsOn() step:@"covered: no clip or hills on the card" detail:cardState()];
        [self expect:!closedDecoder step:@"covered: the preview decoder is released" detail:closedDecoder ? @"still retained" : @"released"];
        [nav popViewControllerAnimated:NO];
    });
    step(0.5, ^{
        UIButton *menu = (UIButton *)cellOf(noClip()).accessoryView;
        [self expect:[noClip().value() isEqualToString:@"Full-screen cover"] && [menu.accessibilityValue isEqualToString:@"Full-screen cover"] && motionOn()
                step:@"back on the page: Full-screen cover from the switch stored meanwhile, the clip back" detail:[NSString stringWithFormat:@"row \"%@\", menu \"%@\"; %@", noClip().value(), menu.accessibilityValue, cardState()]];
        // Both on, as an older build could leave them: shown as the full-screen cover, and left stored as they are.
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:SGRKeyPlayerAnimatedVisualiser];
        reread();
        [self expect:[noClip().value() isEqualToString:@"Full-screen cover"] && stored(SGRKeyPlayerAnimatedStill) && stored(SGRKeyPlayerAnimatedVisualiser)
                step:@"both stored on: Full-screen cover, nothing rewritten" detail:switches()];
        [NSUserDefaults.standardUserDefaults setBool:NO forKey:SGRKeyPlayerAnimatedStill];
        reread();
        [self expect:[noClip().value() isEqualToString:@"Visualizer"] step:@"the Visualizer's switch alone: Visualizer" detail:switches()];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:SGRKeyPlayerAnimatedVisualiser];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:SGRKeyPlayerAnimatedStill];
        reread();
        sg_bothOn = 0;
    });
    // Each choice through the menu's own block: the other switch off at every write, and the card shows it.
    step(0.5, ^{
        choose(1);
        [self expect:stored(SGRKeyPlayerAnimatedStill) && !stored(SGRKeyPlayerAnimatedVisualiser) && demo() && stillShown() && !motionOn() && !hillsOn()
                     && [playerNow() isEqualToString:playerBefore] && SGRHarnessPlayerCommands() == 0
                step:@"Full-screen cover chosen: its switch alone on, the card shows it" detail:[NSString stringWithFormat:@"%@; %@", switches(), cardState()]];
        shot(@"demo-on");
    });
    step(2.5, ^{
        choose(2);
        [self expect:!stored(SGRKeyPlayerAnimatedStill) && stored(SGRKeyPlayerAnimatedVisualiser) && demo() && hillsOn() && !stillShown() && !motionOn()
                step:@"Visualizer chosen: its switch alone on, the hills on the card" detail:[NSString stringWithFormat:@"%@; %@", switches(), cardState()]];
        shot(@"demo-visualizer");
    });
    step(2.5, ^{
        choose(1);
        BOOL fullScreen = stored(SGRKeyPlayerAnimatedStill) && !stored(SGRKeyPlayerAnimatedVisualiser);
        choose(0);
        [self expect:fullScreen && !stored(SGRKeyPlayerAnimatedStill) && !stored(SGRKeyPlayerAnimatedVisualiser) && demo() && !hillsOn() && !stillShown() && !motionOn()
                step:@"Visualizer to Full-screen cover to Cover art: one switch on at most, then none" detail:[NSString stringWithFormat:@"%@; %@", switches(), cardState()]];
        choose(2);
        [self expect:sg_bothOn == 0 step:@"the two switches never stored on together" detail:[NSString stringWithFormat:@"%lu writes left both on", (unsigned long)sg_bothOn]];
    });
    // A tap on the card shows the song as it is again; its button shows it without a clip.
    step(0.5, ^{
        CGRect frame = [card() convertRect:card().bounds toView:self.window];
        SGHarnessTap(self.window, CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame)));
    });
    step(0.8, ^{
        [self expect:!demo() && motionOn() && !hillsOn() && [playerNow() isEqualToString:playerBefore] && SGRHarnessPlayerCommands() == 0
                step:@"a tap on the card: the clip again, the player untouched" detail:cardState()];
        shot(@"demo-off");
    });
    step(2.5, ^{
        UIView *toggle = [card() valueForKey:@"_demoButton"];
        CGRect frame = [toggle convertRect:toggle.bounds toView:self.window];
        SGHarnessTap(self.window, CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame)));
    });
    step(0.8, ^{
        UIButton *toggle = [card() valueForKey:@"_demoButton"];
        [self expect:demo() && hillsOn() && !motionOn() && (toggle.accessibilityTraits & UIAccessibilityTraitSelected)
                     && [[[card() valueForKey:@"_canvas"] accessibilityValue] isEqualToString:@"Animated background, without a clip: Visualizer"]
                     && [playerNow() isEqualToString:playerBefore] && SGRHarnessPlayerCommands() == 0
                step:@"the Without a clip button: the Visualizer, said as such, the player untouched" detail:cardState()];
        sg_lowPower = YES;
        reportPower();
        [NSNotificationCenter.defaultCenter postNotificationName:NSProcessInfoPowerStateDidChangeNotification object:nil];
    });
    step(0.8, ^{
        SGRArtworkField *field = (SGRArtworkField *)firstOfClass(card(), @"SGRArtworkField");
        [self expect:demo() && !hillsOn() && !stillShown() && !motionOn() && field.motionHeld step:@"Low Power Mode: the cover art held still, as the player shows" detail:cardState()];
        sg_lowPower = NO;
        [NSNotificationCenter.defaultCenter postNotificationName:NSProcessInfoPowerStateDidChangeNotification object:nil];
    });
    step(0.8, ^{
        BOOL back = demo() && hillsOn();
        pick(SGRPlayerBackgroundFluid);
        BOOL ended = !demo() && !hillsOn() && !motionOn();
        pick(SGRPlayerBackgroundAnimated);
        [self expect:back && ended && !demo() && [playerNow() isEqualToString:playerBefore] && SGRHarnessPlayerCommands() == 0
                step:@"Fluid ends the demo, and Animated again does not bring it back" detail:cardState()];
    });
    // Scrolled: compact, still under the bar, whole; the rows go under it.
    step(1, ^{
        // Half of the way the card shrinks: 122 pt of the 244 between 480 and 236.
        [table() setContentOffset:CGPointMake(0, 122 - table().adjustedContentInset.top) animated:NO];
        [table() layoutIfNeeded];
        NSString *halfway = cardClipping(card());
        CGFloat half = card().frame.size.height;
        [table() setContentOffset:CGPointMake(0, 600 - table().adjustedContentInset.top) animated:NO];
        [table() layoutIfNeeded];
        NSString *clipping = cardClipping(card());
        CGFloat height = card().frame.size.height;
        [self expect:card().window && fabs(half - 358) < 1 && !halfway && fabs(height - 236) < 1 && fabs(cardTop() - barFoot() - 8) < 1 && !clipping
                step:@"scrolled: the card shrinking whole, then compact under the bar" detail:[NSString stringWithFormat:@"halfway %.0f (%@); %@, height %.0f; %@", half,
                                                       halfway ?: @"whole", pinned(), height, clipping ?: @"every part in its band"]];
        CGPoint savedOffset = table().contentOffset;
        SGModRow *row = rowTitled(@"Header glass");
        UITableViewCell *cell = cellOf(row);
        CGRect rowFrame = [table() rectForRowAtIndexPath:pathOf(row)];
        // A visible-color marker on an actual row, scrolled under the status/navigation region.
        UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(20, 0, 80, cell.contentView.bounds.size.height)];
        marker.backgroundColor = UIColor.magentaColor;
        [cell.contentView addSubview:marker];
        CGFloat belowPreview = CGRectGetMaxY([card() convertRect:card().bounds toView:table()]) - table().bounds.origin.y + 40;
        [table() setContentOffset:CGPointMake(0, CGRectGetMidY(rowFrame) - belowPreview) animated:NO];
        [table() layoutIfNeeded];
        CGPoint exposedPoint = [marker convertPoint:CGPointMake(40, marker.bounds.size.height / 2) toView:table()];
        NSString *exposed = pixelAtPoint(table(), exposedPoint);
        [table() setContentOffset:CGPointMake(0, CGRectGetMidY(rowFrame) - 50) animated:NO];
        [table() layoutIfNeeded];
        CGPoint point = [marker convertPoint:CGPointMake(40, marker.bounds.size.height / 2) toView:table()];
        UIView *hit = [table() hitTest:point withEvent:nil];
        CGFloat screenY = point.y - table().bounds.origin.y;
        NSString *color = pixelAtPoint(table(), point);
        [self expect:cell.window && screenY > 0 && screenY < 116 && [exposed isEqualToString:@"255,0,255,255"]
                     && [color isEqualToString:@"0,0,0,255"] && ![hit isDescendantOfView:cell]
                step:@"scrolled rows above the preview bottom are neither visible nor hit-testable"
              detail:[NSString stringWithFormat:@"row y %.0f, exposed %@, covered %@, hit %@", screenY, exposed, color, NSStringFromClass(hit.class)]];
        [marker removeFromSuperview];
        [table() setContentOffset:savedOffset animated:NO];
        [table() layoutIfNeeded];
        shot(@"compact");
    });
    // Song without a clip's menu opened by a finger, for the screenshot, and closed by a tap on the bar.
    step(2.5, ^{
        UIView *menu = cellOf(noClip()).accessoryView;
        CGRect frame = [menu convertRect:menu.bounds toView:self.window];
        SGHarnessTap(self.window, CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame)));
    });
    step(1, ^{ shot(@"no-clip"); });
    step(2.5, ^{
        CGRect bar = [nav.navigationBar convertRect:nav.navigationBar.bounds toView:self.window];
        SGHarnessTap(self.window, CGPointMake(CGRectGetMidX(bar), CGRectGetMaxY(bar) - 10));
    });
    // The Buttons chips: each one its key alone, the card at once, kept when the page opens again.
    step(2.5, ^{
        NSArray<UIButton *> *found = chips();
        BOOL whole = found.count == 3;
        for (UIButton *chip in found) {
            whole = whole && chip.selected && chip.frame.size.height >= 44 && (chip.accessibilityTraits & UIAccessibilityTraitButton)
                    && (chip.accessibilityTraits & UIAccessibilityTraitSelected);
        }
        NSArray *labels = [found valueForKey:@"accessibilityLabel"];
        [self expect:whole && [labels isEqualToArray:@[@"Shuffle", @"Repeat", @"Video"]] && !rowTitled(@"Switch to video") && !rowTitled(@"Shuffle")
                step:@"three chips in the Buttons card, all selected, 44 pt, buttons" detail:[NSString stringWithFormat:@"%@ %@", labels, [found valueForKey:@"frame"]]];
        shot(@"chips");
    });
    step(2.5, ^{
        NSArray<NSString *> *keys = @[SGRKeyPlayerHideShuffle, SGRKeyPlayerHideRepeat, SGKeyHideVideoSwitch];
        BOOL alone = YES;
        NSMutableArray<NSString *> *seen = [NSMutableArray array];
        for (NSUInteger i = 0; i < 3; i++) {
            settingsBefore = storedSettings();
            [chips()[i] sendActionsForControlEvents:UIControlEventTouchUpInside];
            NSArray<NSString *> *changed = changedSettings(settingsBefore, storedSettings());
            alone = alone && [changed isEqualToArray:@[keys[i]]] && stored(keys[i]);
            [seen addObject:[changed componentsJoinedByString:@","]];
        }
        // Each chip's name whole once it is drawn unselected, its glyph changed.
        for (UIButton *chip in chips()) {
            if (chip.titleLabel.intrinsicContentSize.width > chip.titleLabel.bounds.size.width + 0.5 || chip.frame.size.height < 44) alone = NO;
            [seen addObject:[NSString stringWithFormat:@"%@ %@", chip.accessibilityLabel, NSStringFromCGRect(chip.frame)]];
        }
        UIView *preview = card();
        [preview layoutIfNeeded];
        CGFloat play = [[preview valueForKey:@"_play"] center].x, previous = [[preview valueForKey:@"_previous"] center].x;
        CGFloat slot = ([preview bounds].size.width - 2 * 16) / 5;
        BOOL drawn = [[preview valueForKey:@"_shuffle"] alpha] == 0 && [[preview valueForKey:@"_repeat"] alpha] == 0 && [[preview valueForKey:@"_chip"] isHidden]
                     && play - previous > slot + 1;
        [self expect:alone && drawn step:@"each chip its key alone, the card without the three, previous and next spread"
              detail:[NSString stringWithFormat:@"changed %@; previous %.0f pt from play, a slot %.0f", seen, play - previous, slot]];
        shot(@"chips-off");
    });
    step(2.5, ^{
        [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
        open();
    });
    step(1, ^{
        NSArray<UIButton *> *found = chips();
        BOOL kept = found.count == 3;
        for (UIButton *chip in found) kept = kept && !chip.selected && !(chip.accessibilityTraits & UIAccessibilityTraitSelected);
        [self expect:kept && [[card() valueForKey:@"_shuffle"] alpha] == 0 step:@"opened again: the three chips as left" detail:[[found valueForKey:@"selected"] description]];
        for (UIButton *chip in found) [chip sendActionsForControlEvents:UIControlEventTouchUpInside];
        [self expect:!stored(SGRKeyPlayerHideShuffle) && !stored(SGRKeyPlayerHideRepeat) && !stored(SGKeyHideVideoSwitch)
                step:@"the three chips selected again, the keys off" detail:[[chips() valueForKey:@"selected"] description]];
        [table() setContentOffset:CGPointMake(0, -table().adjustedContentInset.top) animated:NO];
        [table() layoutIfNeeded];
    });
    // Another track whose clip comes 1 s late, and before it comes a third whose clip comes 3 s late: the card drops the
    // first one's clip at once, never shows the second's, and shows the third's once it is in.
    step(1, ^{
        SGRHarnessSetLookupDelay(1);
        setenv("HARNESS_CANVAS", [NSString stringWithFormat:@"https://canvas.harness/b-%d.mp4", getpid()].UTF8String, 1);
        serve(imageURI(@"bbbb"), solid(UIColor.blueColor), 2, NO);
        [self playTrack:@"spotify:track:harnessB" image:imageURI(@"bbbb")];
    });
    step(0.3, ^{
        [self expect:!motionOn() && SGRPlayerMotionShowing() && [[card() valueForKey:@"_track"] isEqualToString:@"spotify:track:harnessB"]
                step:@"handover: no old preview clip while the real player keeps its clip" detail:cardState()];
        SGRHarnessSetLookupDelay(3);
        setenv("HARNESS_CANVAS", [NSString stringWithFormat:@"https://canvas.harness/c-%d.mp4", getpid()].UTF8String, 1);
        serve(imageURI(@"cccc"), solid(UIColor.greenColor), 0.2, NO);
        [self playTrack:@"spotify:track:harnessC" image:imageURI(@"cccc")];
    });
    step(1.5, ^{
        [self expect:!motionOn() && [[card() valueForKey:@"_track"] isEqualToString:@"spotify:track:harnessC"] step:@"the track before's clip, come after the next track, not shown" detail:cardState()];
        SGMotionFile([NSURL URLWithString:@(getenv("HARNESS_CANVAS"))], ^(NSURL *file) { fileC = file; });
    });
    step(3, ^{
        NSURL *playing = [motionOn() valueForKey:@"_file"];
        [self expect:playing && fileC && [playing isEqual:fileC] step:@"the track's own clip on the card once it is in"
              detail:[NSString stringWithFormat:@"card plays %@, the track's is %@", playing.lastPathComponent, fileC.lastPathComponent]];
        NSString *color = colorName([(UIImageView *)[card() valueForKey:@"_cover"] image]);
        [self expect:[color isEqualToString:@"green"] step:@"the current song's cover, not the preceding song's late blue image" detail:color];
        SGRHarnessSetLookupDelay(0);
    });
    step(0.5, ^{
        checkScrollWork();
        pick(SGRPlayerBackgroundVisualiser);
    });
    step(0.8, ^{
        checkScrollWork();
        pick(SGRPlayerBackgroundAnimated);
        choose(2); // the preview's hills only; the real player still has its clip
    });
    step(0.8, ^{
        closedVisualiser = hillsOn();
        [self expect:closedVisualiser != nil step:@"the visualizer preview is present before dismissal" detail:cardState()];
        [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
        nav = nil;
    });
    step(0.8, ^{
        sg_previewPaletteRequests = 0;
        sg_watchPreviewPalette = YES;
        [NSNotificationCenter.defaultCenter postNotificationName:SGRNowPlayingArtworkDidChangeNotification object:nil];
        sg_watchPreviewPalette = NO;
        [self expect:!closedVisualiser && sg_previewPaletteRequests == 0
                step:@"dismissed visualizer is deallocated and artwork requests no preview palette"
              detail:[NSString stringWithFormat:@"view %@, %lu requests", closedVisualiser ? @"retained" : @"released", (unsigned long)sg_previewPaletteRequests]];
        open();
    });
    // The card and the chips at an iPhone SE's width and this one's, at the default text size and the largest.
    step(0.5, ^{
        NSMutableArray<NSString *> *wrong = [NSMutableArray array];
        for (NSNumber *width in @[@288, @370]) {
            for (UIContentSizeCategory category in @[UIContentSizeCategoryLarge, UIContentSizeCategoryAccessibilityExtraExtraExtraLarge]) {
                UIView *probe = [[NSClassFromString(@"SGRPlayerPreview") alloc] initWithFrame:CGRectMake(-2000, 0, width.doubleValue, 236)];
                [self.window addSubview:probe];
                probe.traitOverrides.preferredContentSizeCategory = category;
                [probe updateTraitsIfNeeded];
                CGFloat least = [[probe valueForKey:@"minimumHeight"] doubleValue], compact = MAX(least, 236);
                // Include shorter screens' expanded heights as well as the full 480 pt preview.
                NSMutableArray<NSNumber *> *sizes = [NSMutableArray arrayWithObject:@(least)];
                for (NSNumber *expanded in @[@320, @400, @480])
                    for (NSUInteger step = 0; step <= 10; step++)
                        [sizes addObject:@(round(compact + (expanded.doubleValue - compact) * step / 10.0))];
                for (NSNumber *height in sizes) {
                    probe.frame = CGRectMake(-2000, 0, width.doubleValue, height.doubleValue);
                    NSString *clipping = cardClipping(probe);
                    if (clipping) [wrong addObject:[NSString stringWithFormat:@"card %@x%@ at %@: %@", width, height, category, clipping]];
                }
                if (least > 236) [wrong addObject:[NSString stringWithFormat:@"card %@ %@ needs %.0f compact", width, category, least]];
                [probe removeFromSuperview];

                UITableViewCell *cell = [[NSClassFromString(@"SGRPlayerButtonsCell") alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
                cell.frame = CGRectMake(-2000, 0, width.doubleValue, 44);
                [self.window addSubview:cell];
                cell.traitOverrides.preferredContentSizeCategory = category;
                [cell updateTraitsIfNeeded];
                [cell performSelector:@selector(readKeys)];
                CGFloat height = [cell systemLayoutSizeFittingSize:CGSizeMake(width.doubleValue, 0) withHorizontalFittingPriority:UILayoutPriorityRequired
                                                verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
                cell.frame = CGRectMake(-2000, 0, width.doubleValue, height);
                [cell layoutIfNeeded];
                CGRect inside = CGRectInset(cell.contentView.bounds, -0.5, -0.5);
                NSMutableArray<NSValue *> *placed = [NSMutableArray array];
                for (UIView *view in cell.contentView.subviews) {
                    if (![view isKindOfClass:UIButton.class]) continue;
                    UIButton *chip = (UIButton *)view;
                    BOOL whole = chip.titleLabel.intrinsicContentSize.width <= chip.titleLabel.bounds.size.width + 0.5;
                    if (!CGRectContainsRect(inside, chip.frame) || chip.frame.size.height < 44 || !whole)
                        [wrong addObject:[NSString stringWithFormat:@"chip %@ %@ at %@ %@ in %@", chip.accessibilityLabel, NSStringFromCGRect(chip.frame), width, category, NSStringFromCGRect(inside)]];
                    for (NSValue *other in placed) if (CGRectIntersectsRect(other.CGRectValue, chip.frame)) [wrong addObject:[NSString stringWithFormat:@"chip %@ over another", chip.accessibilityLabel]];
                    [placed addObject:[NSValue valueWithCGRect:chip.frame]];
                }
                [cell removeFromSuperview];
            }
        }
        [self expect:wrong.count == 0 step:@"the card at every height and the chips whole, 288 and 370 pt wide, default and largest text"
              detail:wrong.count ? [wrong componentsJoinedByString:@" | "] : @"all whole"];
    });
    // No playback: the actual last song, including its asynchronous image, still belongs in the preview.
    step(0.5, ^{
        pick(SGRPlayerBackgroundStill);
        serve(imageURI(@"dddd"), solid(UIColor.magentaColor), 0.4, NO);
        NSString *url = [@"https://i.scdn.co/image/" stringByAppendingString:[imageURI(@"dddd") substringFromIndex:14]];
        [NSUserDefaults.standardUserDefaults setObject:@{@"uri": @"spotify:track:lastD", @"title": @"Last song D", @"artwork": url}
                                               forKey:SGKeyLastTrack];
        SGRHarnessClearTrack();
    });
    step(1, ^{
        NSString *color = colorName([(UIImageView *)[card() valueForKey:@"_cover"] image]);
        [self expect:[color isEqualToString:@"magenta"] && [[[card() valueForKey:@"_title"] text] isEqualToString:@"Last song D"]
                step:@"no playback: the last song's title and delayed cover" detail:color];
        serve(imageURI(@"eeee"), solid(UIColor.blueColor), 1, NO);
        NSString *url = [@"https://i.scdn.co/image/" stringByAppendingString:[imageURI(@"eeee") substringFromIndex:14]];
        [NSUserDefaults.standardUserDefaults setObject:@{@"uri": @"spotify:track:lastE", @"title": @"Last song E", @"artwork": url}
                                               forKey:SGKeyLastTrack];
        SGRHarnessClearTrack();
    });
    step(0.1, ^{
        NSString *url = [@"https://i.scdn.co/image/" stringByAppendingString:[imageURI(@"dddd") substringFromIndex:14]];
        [NSUserDefaults.standardUserDefaults setObject:@{@"uri": @"spotify:track:lastF", @"title": @"Last song F", @"artwork": url}
                                               forKey:SGKeyLastTrack];
        SGRHarnessClearTrack();
    });
    step(1.5, ^{
        NSString *color = colorName([(UIImageView *)[card() valueForKey:@"_cover"] image]);
        [self expect:[color isEqualToString:@"magenta"] && [[[card() valueForKey:@"_title"] text] isEqualToString:@"Last song F"]
                step:@"a late last-song image cannot replace the song now shown" detail:color];
        // A last-song lookup belongs only to the preview, not the real player.
        SGRHarnessSetLookupDelay(1);
        NSString *canvas = [NSString stringWithFormat:@"https://canvas.harness/closed-%d.mp4", getpid()];
        [NSUserDefaults.standardUserDefaults setObject:@{@"uri": @"spotify:track:lastG", @"title": @"Last song G", @"canvas": canvas}
                                               forKey:SGKeyLastTrack];
        SGRHarnessClearTrack();
        pick(SGRPlayerBackgroundAnimated);
        SGRPlayerMotionPreview(^{ latePreviewCallbacks++; });
    });
    // Closed: the card does nothing more, whatever the player does.
    step(0.5, ^{
        closedCard = card();
        [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
        nav = nil;
    });
    step(1.5, ^{
        UIView *left = closedCard;
        BOOL stopped = !left || (![[left valueForKey:@"_active"] boolValue] && !firstOfClass(left, @"SGRPlayerMotionView") && !firstOfClass(left, @"SGRVisualiserView")
                                 && ![[left valueForKey:@"_track"] isEqualToString:@"spotify:track:harnessD"]);
        [self expect:stopped step:@"closed: the card stopped, not following the player"
              detail:left ? [NSString stringWithFormat:@"card kept, active %@, track %@", [left valueForKey:@"_active"], [left valueForKey:@"_track"]] : @"card gone"];
        [self expect:latePreviewCallbacks == 0 && SGRPlayerMotionPreview(nil) == nil
                step:@"dismissal cancels the pending preview result" detail:[NSString stringWithFormat:@"%lu late callbacks", (unsigned long)latePreviewCallbacks]];
        [self expect:SGRHarnessPlayerCommands() == 0 step:@"no command sent to the player" detail:[NSString stringWithFormat:@"%lu commands", (unsigned long)SGRHarnessPlayerCommands()]];
        NSLog(@"[harness] settings checks: %lu of %lu right -- %@", (unsigned long)(self->_checks - self->_failures), (unsigned long)self->_checks,
              self->_failures ? @"FAIL" : @"PASS");
        exit(self->_failures ? 1 : 0);
    });
    runScript(script, 0);
}

// The Player page opened with the player showing no clip, Animated picked on it: the card looks the clip up.
- (void)runPreviewChecks {
    __block UINavigationController *nav;
    UIView *(^showcase)(void) = ^{
        return firstOfClass(((UITableViewController *)nav.topViewController).tableView, @"SGRPlayerPreview");
    };
    void (^pick)(NSUInteger) = ^(NSUInteger index) {
        UISegmentedControl *segments = (UISegmentedControl *)firstOfClass(((UITableViewController *)nav.topViewController).tableView.tableHeaderView, @"UISegmentedControl");
        segments.selectedSegmentIndex = (NSInteger)index;
        [segments sendActionsForControlEvents:UIControlEventValueChanged];
    };
    NSString *(^card)(void) = ^{
        UIView *view = showcase();
        SGRArtworkField *field = (SGRArtworkField *)firstOfClass(view, @"SGRArtworkField");
        UIView *motion = firstOfClass(view, @"SGRPlayerMotionView");
        CALayer *still = [motion valueForKey:@"_still"];
        return [NSString stringWithFormat:@"card: clip %@ (poster %@), field fluid %d held %d; the player's clip %@; the clip served %lu times",
                motion ? @"in" : @"out", still.contents ? @"drawn" : @"none", field.fluid, field.motionHeld, SGRPlayerMotionShowing() ? @"in" : @"none",
                (unsigned long)sg_canvasServed];
    };
    BOOL (^clipIn)(void) = ^{ return (BOOL)(firstOfClass(showcase(), @"SGRPlayerMotionView") != nil); };
    after(1, ^{
        [self expect:sg_canvasServed == 0 && !SGRPlayerMotionShowing() step:@"before the page, nothing asked for"
              detail:[NSString stringWithFormat:@"the clip served %lu times, the player's clip %@", (unsigned long)sg_canvasServed, SGRPlayerMotionShowing() ? @"in" : @"none"]];
        nav = [[UINavigationController alloc] initWithRootViewController:SGRPlayerSettingsPage(@[])];
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
        [self.window.rootViewController presentViewController:nav animated:NO completion:nil];
    });
    after(2, ^{
        [self expect:!clipIn() && sg_canvasServed == 0 step:@"Still on the page, nothing asked for" detail:card()];
        pick(3);
    });
    after(2.5, ^{
        SGRArtworkField *field = (SGRArtworkField *)firstOfClass(showcase(), @"SGRArtworkField");
        [self expect:!clipIn() && field.fluid step:@"Animated picked, Fluid while the clip comes" detail:card()];
    });
    after(6, ^{
        SGRArtworkField *field = (SGRArtworkField *)firstOfClass(showcase(), @"SGRArtworkField");
        CALayer *still = [firstOfClass(showcase(), @"SGRPlayerMotionView") valueForKey:@"_still"];
        [self expect:clipIn() && still.contents && field.motionHeld && sg_canvasServed == 1 && !SGRPlayerMotionShowing()
                step:@"the clip in the card, the player left alone" detail:card()];
        NSLog(@"[harness] preview: screenshot the card now");
        // The player's walk asks the store the same way: it finds the file without asking the server again.
        SGMotionFile([NSURL URLWithString:@(getenv("HARNESS_CANVAS"))], ^(NSURL *file) {
            [self expect:file && sg_canvasServed == 1 step:@"the clip in the store for the player"
                  detail:[NSString stringWithFormat:@"%@, served %lu times", file.lastPathComponent ?: @"no file", (unsigned long)sg_canvasServed]];
        });
    });
    after(8, ^{ pick(2); });
    after(8.5, ^{
        [self expect:!clipIn() step:@"Fluid picked, the clip out" detail:card()];
        pick(3);
        [self expect:clipIn() && sg_canvasServed == 1 step:@"Animated again, the clip at once" detail:card()];
    });
    after(9.5, ^{
        NSLog(@"[harness] preview checks: %lu of %lu right -- %@", (unsigned long)(self->_checks - self->_failures), (unsigned long)self->_checks,
              self->_failures ? @"FAIL" : @"PASS");
    });
}

- (NSArray<UILabel *> *)labelsIn:(UIView *)view {
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:UILabel.class]) [labels addObject:(UILabel *)sub];
        [labels addObjectsFromArray:[self labelsIn:sub]];
    }
    return labels;
}

#pragma mark - the Visualizer

BOOL SGRHarnessReading(void);

static UIView *visualiserView(void) {
    for (UIView *view in SGRPlayerField().subviews) {
        if ([NSStringFromClass(view.class) isEqualToString:@"SGRVisualiserView"]) return view;
    }
    return nil;
}

// The tallest a hill stands over the screen's foot, in points, from its path's bounding box.
static CGFloat hillHeight(UIView *view, NSString *ivar) {
    CAShapeLayer *shape = [view valueForKey:ivar];
    if (!shape.path) return 0;
    return view.bounds.size.height > 0 ? [[view valueForKey:@"baseline"] doubleValue] - CGPathGetPathBoundingBox(shape.path).origin.y : 0;
}

- (void)runVisualiserChecks {
    after(3, ^{
        UIView *hills = visualiserView();
        CADisplayLink *link = [hills valueForKey:@"_link"];
        CGFloat front = hillHeight(hills, @"_frontShape"), back = hillHeight(hills, @"_backShape");
        [self expect:hills && SGRPlayerVisualiserShowing() && SGRPlayerField().fluid && SGRPlayerField().motionHeld && link && SGRHarnessReading() && front > 40
                step:@"playing"
              detail:[NSString stringWithFormat:@"hills %@, field fluid %d held %d, link %@ at up to %.0f fps, reader %@, front %.0f pt, back %.0f pt",
                      hills ? @"on the field" : @"missing", SGRPlayerField().fluid, SGRPlayerField().motionHeld, link ? @"running" : @"stopped",
                      link.preferredFrameRateRange.maximum, SGRHarnessReading() ? @"on" : @"off", front, back]];
        NSLog(@"[harness] visualizer: screenshot the hills now");
    });
    after(4, ^{ SGRPlayerToggleLyrics(); });
    after(5.5, ^{
        UIView *hills = visualiserView();
        UIVisualEffectView *blur = [hills valueForKey:@"_lyricsBlur"];
        CADisplayLink *link = [hills valueForKey:@"_link"];
        [self expect:SGRPlayerLyricsOpen() && blur.effect && link.preferredFrameRateRange.maximum == UIScreen.mainScreen.maximumFramesPerSecond step:@"behind the lyrics"
              detail:[NSString stringWithFormat:@"lyrics %@, blur %@, link at up to %.0f fps", SGRPlayerLyricsOpen() ? @"up" : @"down",
                      blur.effect ? @"on" : @"off", link.preferredFrameRateRange.maximum]];
        NSLog(@"[harness] visualizer: screenshot the lyrics now");
    });
    after(6.5, ^{ SGRPlayerToggleLyrics(); });
    after(7.5, ^{ SGRHarnessSetTrack(@"spotify:track:harnessA", imageURI(@"aaaa"), YES); });
    after(8, ^{
        CADisplayLink *link = [visualiserView() valueForKey:@"_link"];
        [self expect:link && !SGRHarnessReading() step:@"paused, settling"
              detail:[NSString stringWithFormat:@"link %@, reader %@", link ? @"still running" : @"stopped", SGRHarnessReading() ? @"on" : @"off"]];
    });
    after(12, ^{
        UIView *hills = visualiserView();
        CADisplayLink *link = [hills valueForKey:@"_link"];
        CGFloat front = hillHeight(hills, @"_frontShape");
        [self expect:!link && !SGRHarnessReading() && front < 15 step:@"paused, settled"
              detail:[NSString stringWithFormat:@"link %@, reader %@, front %.0f pt", link ? @"running" : @"stopped", SGRHarnessReading() ? @"on" : @"off", front]];
        NSLog(@"[harness] visualizer: screenshot the paused hills now");
        SGRHarnessSetTrack(@"spotify:track:harnessA", imageURI(@"aaaa"), NO);
    });
    after(13.5, ^{
        UIView *hills = visualiserView();
        [self expect:[hills valueForKey:@"_link"] && SGRHarnessReading() && hillHeight(hills, @"_frontShape") > 40 step:@"playing again"
              detail:[NSString stringWithFormat:@"front %.0f pt", hillHeight(hills, @"_frontShape")]];
        SGRPlayerMenuSetBackground(SGRPlayerBackgroundFluid);
    });
    after(14.2, ^{
        [self expect:!visualiserView() && !SGRPlayerVisualiserShowing() && !SGRPlayerField().motionHeld && !SGRHarnessReading()
                step:@"switched to Fluid from the menu"
              detail:[NSString stringWithFormat:@"hills %@, field %@, reader %@", visualiserView() ? @"still there" : @"gone",
                      SGRPlayerField().motionHeld ? @"held" : @"moving", SGRHarnessReading() ? @"on" : @"off"]];
        SGRPlayerMenuSetBackground(SGRPlayerBackgroundVisualiser);
    });
    after(15.5, ^{
        UIView *hills = visualiserView();
        [self expect:hills && SGRPlayerField().motionHeld && SGRHarnessReading() && hillHeight(hills, @"_frontShape") > 40 step:@"back from the menu"
              detail:[NSString stringWithFormat:@"hills %@, field %@, front %.0f pt", hills ? @"on the field" : @"missing",
                      SGRPlayerField().motionHeld ? @"held" : @"moving", hillHeight(hills, @"_frontShape")]];
        NSLog(@"[harness] visualizer checks: %lu of %lu right -- %@", (unsigned long)(self->_checks - self->_failures), (unsigned long)self->_checks,
              self->_failures ? @"FAIL" : @"PASS");
    });
}

#pragma mark - the Visualizer without a clip, shuffled styles, heat

// What NSProcessInfo reports as the thermal state and Low Power Mode, which the simulator has neither of.
static NSInteger sg_thermal;
static BOOL sg_lowPower;

static void reportPower(void) {
    Class info = object_getClass(NSProcessInfo.processInfo);
    for (NSString *name in @[@"isLowPowerModeEnabled", @"lowPowerModeEnabled"]) {
        Method method = class_getInstanceMethod(info, NSSelectorFromString(name));
        if (method) method_setImplementation(method, imp_implementationWithBlock(^BOOL(id process) { return sg_lowPower; }));
    }
    Method thermal = class_getInstanceMethod(info, @selector(thermalState));
    method_setImplementation(thermal, imp_implementationWithBlock(^NSInteger(id process) { return sg_thermal; }));
}

static void setThermal(NSProcessInfoThermalState state) {
    sg_thermal = state;
    [NSNotificationCenter.defaultCenter postNotificationName:NSProcessInfoThermalStateDidChangeNotification object:nil];
}

static NSString *finishChecks(NSUInteger checks, NSUInteger failures, NSString *name) {
    return [NSString stringWithFormat:@"%@ checks: %lu of %lu right -- %@", name, (unsigned long)(checks - failures), (unsigned long)checks, failures ? @"FAIL" : @"PASS"];
}

// Animated with "Visualizer when there's no clip" (SGRKeyPlayerAnimatedVisualiser). Every track's lookup takes 1.5 s
// (stubs.m), so the player can be looked at while it is out.
- (void)runAutoVisualiserChecks {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    void (^setFallback)(BOOL) = ^(BOOL on) {
        [store setBool:on forKey:SGRKeyPlayerAnimatedVisualiser];
        SGRPlayerAnimatedVisualiserChanged();
    };
    void (^setStill)(BOOL) = ^(BOOL on) {
        [store setBool:on forKey:SGRKeyPlayerAnimatedStill];
        SGRPlayerStillChanged();
    };
    void (^background)(SGRPlayerBackgroundKind) = ^(SGRPlayerBackgroundKind kind) {
        SGRSetPlayerBackground(kind);
        SGRPlayerBackgroundDidChange();
        [self layOut];
    };
    // The ordinary cover: no clip, no still, no hills (faded out and gone), the reader off.
    BOOL (^ordinary)(void) = ^BOOL { return !SGRPlayerMotionShowing() && !self->_covers.layer.mask && !visualiserView() && !SGRHarnessReading(); };
    // The hills as the background, over the ordinary cover and the field held still, the reader on.
    BOOL (^hills)(void) = ^BOOL {
        return visualiserView() && SGRPlayerVisualiserShowing() && !SGRPlayerMotionShowing() && !self->_covers.layer.mask
            && SGRPlayerField().motionHeld && SGRHarnessReading();
    };
    NSString *(^state)(void) = ^NSString *{
        return [NSString stringWithFormat:@"hills %@, clip or still %@, cover %@, reader %@", visualiserView() ? @"on" : @"off",
                SGRPlayerMotionShowing() ? @"on" : @"off", self->_covers.layer.mask ? @"hidden" : @"shown", SGRHarnessReading() ? @"on" : @"off"];
    };
    serve(imageURI(@"bbbb"), solidPixels(UIColor.greenColor, 600), 0.1, NO);
    serve(imageURI(@"cccc"), solidPixels(UIColor.blueColor, 600), 0.1, NO);
    runScript(@[
        @[@0.6, ^{
            [self expect:ordinary() && !SGRPlayerAnimatedVisualiserOn() step:@"switch off, lookup out" detail:state()];
            setFallback(YES);
            [self expect:ordinary() && !SGRPlayerVisualiserShowing() step:@"switched on while the lookup is out: no flash" detail:state()];
        }],
        @[@2.5, ^{
            [self expect:hills() step:@"the lookup found no clip: the Visualizer" detail:state()];
            NSLog(@"[harness] autoviz: screenshot the Visualizer now");
            [self playTrack:@"spotify:track:harnessB" image:imageURI(@"bbbb")];
        }],
        @[@0.9, ^{ [self expect:ordinary() step:@"a track change takes it down until the lookup ends" detail:state()]; }],
        @[@2, ^{
            [self expect:hills() step:@"the new track's lookup found no clip" detail:state()];
            // Its Canvas turns up late.
            setenv("HARNESS_CANVAS", [NSString stringWithFormat:@"https://canvas.harness/auto-%d.mp4", getpid()].UTF8String, 1);
            SGRHarnessSetTrack(@"spotify:track:harnessB", imageURI(@"bbbb"), NO);
        }],
        @[@0.9, ^{ [self expect:ordinary() step:@"a clip on its way: the lookup is out again" detail:state()]; }],
        @[@2.2, ^{
            [self expect:SGRPlayerMotionShowing() && !visualiserView() && !SGRHarnessReading() step:@"a late clip takes the Visualizer down" detail:state()];
            unsetenv("HARNESS_CANVAS");
            [self playTrack:@"spotify:track:harnessC" image:imageURI(@"cccc")];
        }],
        @[@3.2, ^{
            [self expect:hills() step:@"a track without a clip after a clip" detail:state()];
            reportPower();
            // Low Power Mode, with no notification and no new walk (as Reduce Motion is switched): the Visualizer is asked again.
            sg_lowPower = YES;
            SGRPlayerVisualiserUpdate();
        }],
        @[@1, ^{
            [self expect:ordinary() step:@"no clip wanted any more (Low Power Mode, no new walk): the Visualizer goes" detail:state()];
            sg_lowPower = NO;
            SGRPlayerVisualiserUpdate();
        }],
        @[@1, ^{
            [self expect:hills() step:@"a clip wanted again: the Visualizer is back" detail:state()];
            sg_lowPower = YES;
            [NSNotificationCenter.defaultCenter postNotificationName:NSProcessInfoPowerStateDidChangeNotification object:nil];
        }],
        // Reduce Motion takes the same path as Low Power Mode (motionAllowed); the process can be made to report the latter.
        @[@1.8, ^{
            [self expect:ordinary() step:@"Low Power Mode: the ordinary cover, not the still" detail:state()];
            [NSNotificationCenter.defaultCenter postNotificationName:SGRNowPlayingArtworkDidChangeNotification object:nil];
            [self expect:ordinary() step:@"a cover in under Low Power Mode" detail:state()];
            sg_lowPower = NO;
            [NSNotificationCenter.defaultCenter postNotificationName:NSProcessInfoPowerStateDidChangeNotification object:nil];
        }],
        @[@0.5, ^{ [self expect:ordinary() step:@"Low Power Mode off, lookup out" detail:state()]; }],
        @[@2.5, ^{
            [self expect:hills() step:@"Low Power Mode off, lookup ended" detail:state()];
            setStill(YES);
        }],
        @[@0.9, ^{
            [self expect:!SGRPlayerAnimatedVisualiserOn() && SGRPlayerStillOn() && SGRPlayerMotionShowing() && !visualiserView() && !SGRHarnessReading()
                    step:@"the still switched on: the Visualizer switch off, the still in"
                  detail:[NSString stringWithFormat:@"switch %d, still %d, %@", SGRPlayerAnimatedVisualiserOn(), SGRPlayerStillOn(), state()]];
            setFallback(YES);
        }],
        @[@0.9, ^{
            [self expect:SGRPlayerAnimatedVisualiserOn() && !SGRPlayerStillOn() && hills()
                    step:@"the Visualizer switched on: the still switch off, the hills in"
                  detail:[NSString stringWithFormat:@"switch %d, still %d, %@", SGRPlayerAnimatedVisualiserOn(), SGRPlayerStillOn(), state()]];
            setFallback(NO);
        }],
        @[@0.9, ^{
            [self expect:ordinary() && !SGRPlayerStillOn() step:@"both off" detail:state()];
            setFallback(YES);
            background(SGRPlayerBackgroundFluid);
        }],
        @[@1, ^{ [self expect:ordinary() && !SGRPlayerVisualiserShowing() step:@"Fluid chosen: no Visualizer" detail:state()]; background(SGRPlayerBackgroundBlack); }],
        @[@1.5, ^{
            [self expect:!visualiserView() && !SGRPlayerVisualiserShowing() && !SGRHarnessReading() step:@"black chosen: no Visualizer" detail:state()];
            background(SGRPlayerBackgroundAnimated);
        }],
        @[@3, ^{ [self expect:hills() step:@"Animated again" detail:state()]; setFallback(NO); }],
        @[@0.9, ^{
            [self expect:ordinary() step:@"switched off again: today's behavior" detail:state()];
            // Both saved on (an older build): the track has no clip, and the cover is the one wanted.
            [store setBool:YES forKey:SGRKeyPlayerAnimatedStill];
            [store setBool:YES forKey:SGRKeyPlayerAnimatedVisualiser];
            [self expect:!SGRPlayerVisualiserFallbackWanted() step:@"both saved on: the Visualizer is not wanted" detail:state()];
            SGRPlayerVisualiserUpdate();
            [self expect:SGRPlayerStillOn() && !SGRPlayerAnimatedVisualiserOn() && ![store boolForKey:SGRKeyPlayerAnimatedVisualiser]
                    step:@"both saved on: the cover stays, the Visualizer switch is off"
                  detail:[NSString stringWithFormat:@"still %d, switch %d", SGRPlayerStillOn(), [store boolForKey:SGRKeyPlayerAnimatedVisualiser]]];
        }],
        @[@0.9, ^{
            [self expect:!visualiserView() && !SGRPlayerVisualiserShowing() step:@"both saved on: no Visualizer after the cover" detail:state()];
            // The row's order: the switch written, then the callback.
            SGSetEnabled(SGRKeyPlayerAnimatedVisualiser, YES);
            SGRPlayerAnimatedVisualiserChanged();
        }],
        @[@0.9, ^{
            [self expect:SGRPlayerAnimatedVisualiserOn() && !SGRPlayerStillOn() && hills() step:@"the row switching the Visualizer on with the cover on: the Visualizer wins"
                  detail:state()];
            setFallback(NO);
            NSLog(@"[harness] %@", finishChecks(self->_checks, self->_failures, @"autoviz"));
            exit(self->_failures ? 1 : 0);
        }],
    ], 0);
}

// Shuffle styles, with the Visualizer as the background first, then standing in for a missing clip.
- (void)runShuffleChecks {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    __block NSUInteger changes = 0, picksBefore = 0;
    [NSNotificationCenter.defaultCenter addObserverForName:SGRVisualiserStyleDidChangeNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) { changes++; }];
    NSArray<NSString *> *all = @[@"builtin:hills", @"builtin:bars", @"builtin:nebula", @"builtin:halo", @"builtin:lyrics"];
    void (^background)(SGRPlayerBackgroundKind) = ^(SGRPlayerBackgroundKind kind) {
        SGRSetPlayerBackground(kind);
        SGRPlayerBackgroundDidChange();
        [self layOut];
    };
    runScript(@[
        @[@3, ^{
            [self expect:changes == 0 && [SGRVisualiserStyle() isEqualToString:@"builtin:hills"] step:@"off: no pick" detail:SGRVisualiserStyle()];
            SGRHarnessSetTrack(@"spotify:track:shuffleOff", imageURI(@"aaaa"), NO);
            [self expect:changes == 0 && [SGRVisualiserStyle() isEqualToString:@"builtin:hills"] step:@"off: a track change picks nothing" detail:SGRVisualiserStyle()];
            [store setBool:YES forKey:SGRKeyVisualiserShuffle];
            SGRVisualiserShuffleChanged();
            [self expect:changes == 0 && [[store stringForKey:SGRKeyVisualiserShuffleHome] isEqualToString:@"builtin:hills"]
                    step:@"switched on: the user's style remembered, nothing picked"
                  detail:[NSString stringWithFormat:@"home %@, %lu changes", [store stringForKey:SGRKeyVisualiserShuffleHome], (unsigned long)changes]];
            SGRHarnessSetTrack(@"spotify:track:shuffleA", imageURI(@"aaaa"), NO);
            [self expect:changes == 1 && ![SGRVisualiserStyle() isEqualToString:@"builtin:hills"] && [all containsObject:SGRVisualiserStyle()]
                    step:@"a track change on screen: one pick, not the current style"
                  detail:[NSString stringWithFormat:@"%lu changes, style %@", (unsigned long)changes, SGRVisualiserStyle()]];
            // The same song seen again: a pause and a play, then the same song reported once more.
            SGRHarnessSetTrack(@"spotify:track:shuffleA", imageURI(@"aaaa"), YES);
            SGRHarnessSetTrack(@"spotify:track:shuffleA", imageURI(@"aaaa"), NO);
            [self expect:changes == 1 step:@"the same track (pause, play): no pick" detail:[NSString stringWithFormat:@"%lu changes", (unsigned long)changes]];
        }],
        @[@0.5, ^{
            BOOL moved = YES;
            NSMutableSet *seen = [NSMutableSet set];
            for (int i = 0; i < 80; i++) {
                NSString *before = SGRVisualiserStyle();
                NSUInteger count = changes;
                SGRHarnessSetTrack([NSString stringWithFormat:@"spotify:track:shuffleMany%d", i], imageURI(@"aaaa"), NO);
                moved = moved && changes == count + 1 && ![SGRVisualiserStyle() isEqualToString:before];
                [seen addObject:SGRVisualiserStyle()];
            }
            [self expect:moved && seen.count == all.count step:@"80 track changes: each one pick, never the current style, every style turns up"
                  detail:[NSString stringWithFormat:@"%@, %lu styles seen", moved ? @"each moved" : @"a pick missed or repeated", (unsigned long)seen.count]];
            // Hidden: another background.
            background(SGRPlayerBackgroundFluid);
        }],
        @[@1, ^{
            NSUInteger count = changes;
            for (int i = 0; i < 5; i++) SGRHarnessSetTrack([NSString stringWithFormat:@"spotify:track:shuffleHidden%d", i], imageURI(@"aaaa"), NO);
            [self expect:changes == count step:@"hidden: track changes pick nothing" detail:[NSString stringWithFormat:@"%lu picks", (unsigned long)(changes - count)]];
            background(SGRPlayerBackgroundVisualiser);
        }],
        @[@1.2, ^{
            NSUInteger count = changes;
            [self expect:visualiserView() step:@"the Visualizer back" detail:@""];
            SGRHarnessSetTrack(@"spotify:track:shuffleHidden4", imageURI(@"aaaa"), NO);
            [self expect:changes == count step:@"back on screen, the same track: no pick" detail:[NSString stringWithFormat:@"%lu picks", (unsigned long)(changes - count)]];
            SGRHarnessSetTrack(@"spotify:track:shuffleNext", imageURI(@"aaaa"), NO);
            [self expect:changes == count + 1 step:@"the next track: a pick" detail:[NSString stringWithFormat:@"%lu picks", (unsigned long)(changes - count)]];
            // A style by hand becomes the one shuffle goes back to.
            SGRPickVisualiserStyle(@"builtin:bars");
            [self expect:[[store stringForKey:SGRKeyVisualiserShuffleHome] isEqualToString:@"builtin:bars"] step:@"a style by hand is remembered"
                  detail:[store stringForKey:SGRKeyVisualiserShuffleHome]];
            SGRHarnessSetTrack(@"spotify:track:shuffleAfterHand", imageURI(@"aaaa"), NO);
            [store setBool:NO forKey:SGRKeyVisualiserShuffle];
            SGRVisualiserShuffleChanged();
            [self expect:[SGRVisualiserStyle() isEqualToString:@"builtin:bars"] step:@"switched off: the user's own style is back" detail:SGRVisualiserStyle()];
            count = changes;
            SGRHarnessSetTrack(@"spotify:track:shuffleOffAgain", imageURI(@"aaaa"), NO);
            [self expect:changes == count step:@"off again: no pick" detail:SGRVisualiserStyle()];
            // The Visualizer for a missing clip: shuffle picks once the hills come in, not while the lookup is out.
            [store setBool:YES forKey:SGRKeyVisualiserShuffle];
            SGRVisualiserShuffleChanged();
            [store setBool:YES forKey:SGRKeyPlayerAnimatedVisualiser];
            SGRHarnessSetLookupDelay(1);
            background(SGRPlayerBackgroundAnimated);
        }],
        @[@2.5, ^{
            [self expect:visualiserView() && SGRPlayerVisualiserShowing() step:@"Animated: the Visualizer for the current track's missing clip" detail:@""];
            picksBefore = changes;
            SGRHarnessSetTrack(@"spotify:track:shuffleFallback", imageURI(@"aaaa"), NO);
        }],
        @[@2, ^{
            [self expect:changes == picksBefore + 1 && visualiserView() && SGRPlayerVisualiserShowing() step:@"Animated: the next track's Visualizer, one pick"
                  detail:[NSString stringWithFormat:@"%lu picks", (unsigned long)(changes - picksBefore)]];
        }],
        @[@0.1, ^{
            NSUInteger count = changes;
            SGRHarnessSetTrack(@"spotify:track:shuffleFallback", imageURI(@"aaaa"), YES);
            SGRHarnessSetTrack(@"spotify:track:shuffleFallback", imageURI(@"aaaa"), NO);
            [self expect:changes == count step:@"Animated: the same track again, no pick" detail:@""];
            // A song that changes while the iPhone is hot is not picked for when it cools.
            reportPower();
            setThermal(NSProcessInfoThermalStateSerious);
            SGRPlayerVisualiserUpdate();
        }],
        @[@0.4, ^{
            picksBefore = changes;
            SGRHarnessSetTrack(@"spotify:track:shuffleHot", imageURI(@"aaaa"), NO);
        }],
        @[@2.5, ^{
            [self expect:!visualiserView() && changes == picksBefore step:@"hot: the track's lookup ended, no Visualizer, no pick"
                  detail:[NSString stringWithFormat:@"%lu picks", (unsigned long)(changes - picksBefore)]];
            setThermal(NSProcessInfoThermalStateNominal);
            SGRPlayerVisualiserUpdate();
        }],
        @[@0.5, ^{
            [self expect:visualiserView() && changes == picksBefore step:@"cooled: the Visualizer is back for the track that changed while hot, no pick"
                  detail:[NSString stringWithFormat:@"%lu picks", (unsigned long)(changes - picksBefore)]];
            // Hot during the lookup of a track that changed while the hills could be seen.
            SGRHarnessSetTrack(@"spotify:track:shuffleDuringFirst", imageURI(@"aaaa"), NO);
        }],
        @[@0.3, ^{
            // The hills are down for the first song's lookup, so the second is waited on.
            SGRHarnessSetTrack(@"spotify:track:shuffleDuring", imageURI(@"aaaa"), NO);
            picksBefore = changes;
        }],
        @[@0.3, ^{
            setThermal(NSProcessInfoThermalStateSerious);
            SGRPlayerVisualiserUpdate();
        }],
        @[@2.5, ^{
            [self expect:!visualiserView() && changes == picksBefore step:@"hot during the lookup: no Visualizer, no pick"
                  detail:[NSString stringWithFormat:@"%lu picks", (unsigned long)(changes - picksBefore)]];
            setThermal(NSProcessInfoThermalStateNominal);
            SGRPlayerVisualiserUpdate();
        }],
        @[@0.5, ^{
            [self expect:visualiserView() && changes == picksBefore step:@"cooled: the Visualizer is back for the track that was waited on while hot, no pick"
                  detail:[NSString stringWithFormat:@"%lu picks", (unsigned long)(changes - picksBefore)]];
            SGRHarnessSetTrack(@"spotify:track:shuffleCool", imageURI(@"aaaa"), NO);
        }],
        @[@2.5, ^{
            [self expect:visualiserView() && changes == picksBefore + 1 step:@"cooled: the next track while shown, one pick"
                  detail:[NSString stringWithFormat:@"%lu picks", (unsigned long)(changes - picksBefore)]];
            NSLog(@"[harness] %@", finishChecks(self->_checks, self->_failures, @"shuffle"));
            exit(self->_failures ? 1 : 0);
        }],
    ], 0);
}

// Ignore heat warnings.
- (void)runHeatChecks {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    reportPower();
    void (^background)(SGRPlayerBackgroundKind) = ^(SGRPlayerBackgroundKind kind) {
        SGRSetPlayerBackground(kind);
        SGRPlayerBackgroundDidChange();
        [self layOut];
    };
    CADisplayLink * (^link)(void) = ^CADisplayLink *{ return [visualiserView() valueForKey:@"_link"]; };
    runScript(@[
        @[@3, ^{
            NSString *off = @"", *on = @"";
            BOOL right = YES;
            for (NSInteger level = NSProcessInfoThermalStateNominal; level <= NSProcessInfoThermalStateCritical; level++) {
                BOOL want = level >= NSProcessInfoThermalStateSerious;
                right = right && SGRVisualiserStandsDownFor(level) == want;
                off = [off stringByAppendingString:SGRVisualiserStandsDownFor(level) ? @"Y" : @"n"];
            }
            [self expect:right step:@"ignore off: serious and critical stand down, nominal and fair do not" detail:off];
            [store setBool:YES forKey:SGRKeyVisualiserIgnoreHeat];
            right = YES;
            for (NSInteger level = NSProcessInfoThermalStateNominal; level <= NSProcessInfoThermalStateCritical; level++) {
                right = right && !SGRVisualiserStandsDownFor(level);
                on = [on stringByAppendingString:SGRVisualiserStandsDownFor(level) ? @"Y" : @"n"];
            }
            [self expect:right step:@"ignore on: nothing stands down" detail:on];
            [store setBool:NO forKey:SGRKeyVisualiserIgnoreHeat];
            [self expect:link() && SGRHarnessReading() step:@"playing, cool" detail:@""];
            setThermal(NSProcessInfoThermalStateSerious);
        }],
        @[@0.6, ^{
            [self expect:visualiserView() && !link() && !SGRHarnessReading() step:@"hot: the hills stand down (still on the field)" detail:@""];
            [store setBool:YES forKey:SGRKeyVisualiserIgnoreHeat];
            SGRVisualiserIgnoreHeatChanged();
        }],
        @[@0.3, ^{
            [self expect:link() && SGRHarnessReading() step:@"hot, ignore switched on: moving at once" detail:@""];
            sg_lowPower = YES;
            [NSNotificationCenter.defaultCenter postNotificationName:NSProcessInfoPowerStateDidChangeNotification object:nil];
        }],
        @[@0.6, ^{
            [self expect:!link() && !SGRHarnessReading() step:@"hot, ignoring: Low Power Mode still stands it down" detail:@""];
            sg_lowPower = NO;
            [NSNotificationCenter.defaultCenter postNotificationName:NSProcessInfoPowerStateDidChangeNotification object:nil];
        }],
        @[@0.6, ^{
            [self expect:link() && SGRHarnessReading() step:@"Low Power Mode off, still hot and ignoring" detail:@""];
            [store setBool:NO forKey:SGRKeyVisualiserIgnoreHeat];
            SGRVisualiserIgnoreHeatChanged();
        }],
        @[@0.3, ^{
            [self expect:!link() && !SGRHarnessReading() step:@"ignore switched off while hot: stands down at once" detail:@""];
            setThermal(NSProcessInfoThermalStateNominal);
        }],
        @[@0.6, ^{
            [self expect:link() && SGRHarnessReading() step:@"cooled: moving again" detail:@""];
            // The Visualizer for a missing clip, which a hot iPhone gives back to the cover.
            [store setBool:YES forKey:SGRKeyPlayerAnimatedVisualiser];
            background(SGRPlayerBackgroundAnimated);
        }],
        @[@1.5, ^{
            [self expect:visualiserView() && SGRPlayerVisualiserShowing() step:@"Animated, no clip: the Visualizer" detail:@""];
            setThermal(NSProcessInfoThermalStateCritical);
        }],
        @[@1, ^{
            [self expect:!visualiserView() && !SGRPlayerVisualiserShowing() && !SGRPlayerMotionShowing() && !SGRHarnessReading()
                    step:@"hot: the ordinary cover" detail:@""];
            [store setBool:YES forKey:SGRKeyVisualiserIgnoreHeat];
            SGRVisualiserIgnoreHeatChanged();
        }],
        @[@0.3, ^{
            [self expect:visualiserView() && SGRPlayerVisualiserShowing() && SGRHarnessReading() step:@"hot, ignoring: the Visualizer stays" detail:@""];
            NSLog(@"[harness] %@", finishChecks(self->_checks, self->_failures, @"heat"));
            exit(self->_failures ? 1 : 0);
        }],
    ], 0);
}

- (void)runControlsChecks {
    static char ordinaryKey, djKey;
    UIView *owner = [UIView new];
    SGRGlyphView *glyph = SGRPlayerGlyphFor(owner, &ordinaryKey, @"backward.fill", 32);
    [self expect:glyph == SGRPlayerGlyphFor(owner, &ordinaryKey, @"pause.fill", 44)
            step:@"controls reuse the owner's glyph" detail:@"later symbol and size do not replace it"];
    [self expect:[glyph.symbol isEqualToString:@"backward.fill"]
            step:@"reuse preserves the original symbol" detail:glyph.symbol];
    [self expect:[glyph.preferredSymbolConfiguration isEqual:
                  [UIImageSymbolConfiguration configurationWithPointSize:32 weight:UIImageSymbolWeightRegular]]
            step:@"reuse preserves the original point size" detail:@"32pt regular, not the requested 44pt"];
    UIView *djGlyph = (UIView *)SGRPlayerGlyphFor(owner, &djKey, @"forward.fill", 32);
    [self expect:djGlyph != glyph step:@"controls keep association keys separate" detail:@"ordinary and DJ keys"];
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 60)];
    SGRPlayerPlaceGlyph(glyph, host, 0);
    [self expect:CGPointEqualToPoint(glyph.center, CGPointMake(50, 30))
            step:@"ordinary glyph is centered" detail:NSStringFromCGPoint(glyph.center)];
    SGRPlayerPlaceGlyph(djGlyph, host, 4);
    [self expect:CGPointEqualToPoint(djGlyph.center, CGPointMake(50, 34))
            step:@"DJ glyph retains its vertical offset" detail:NSStringFromCGPoint(djGlyph.center)];
    host.frame = CGRectMake(0, 0, 200, 100);
    [self expect:CGPointEqualToPoint(glyph.center, CGPointMake(100, 50))
            step:@"centered glyph follows host resizing" detail:NSStringFromCGPoint(glyph.center)];
    [host addSubview:[UIView new]];
    SGRPlayerPlaceGlyph(djGlyph, host, 4);
    [self expect:host.subviews.lastObject == djGlyph step:@"glyph returns above new content" detail:@"same host"];
    UIView *nextHost = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 80, 40)];
    SGRPlayerPlaceGlyph(djGlyph, nextHost, 4);
    [self expect:djGlyph.superview == nextHost && CGPointEqualToPoint(djGlyph.center, CGPointMake(40, 24))
            step:@"glyph moves to a new host" detail:NSStringFromCGPoint(djGlyph.center)];
    [self runSpreadChecks];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:SGRKeyPlayerHideShuffle];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:SGRKeyPlayerHideRepeat];
    NSLog(@"[harness] controls checks: %lu of %lu right -- %@", (unsigned long)(_checks - _failures),
          (unsigned long)_checks, _failures ? @"FAIL" : @"PASS");
    exit(_failures ? 1 : 0);
}

// One of the controls row's five holders (trees/clean/player/01.txt, .mixdog's phone tree): an arranged view `side`
// square holding a plain view that holds the button.
static UIView *controlSlot(UIStackView *row, CGFloat side, Class cls, NSString *identifier) {
    UIView *slot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, side, side)];
    [slot.widthAnchor constraintEqualToConstant:side].active = YES;
    [slot.heightAnchor constraintEqualToConstant:side].active = YES;
    UIView *inner = box(slot, UIView.class, slot.bounds, nil);
    UIView *button = box(inner, cls, inner.bounds, identifier);
    box(button, UIView.class, button.bounds, nil);   // the content view the skip glyphs go in
    [row addArrangedSubview:slot];
    return slot;
}

// Shuffle and repeat both hidden (switched on for this scenario at launch): previous and next spread a third of the
// 366 pt row (122 pt) either side of play, and stay spread while Spotify takes repeat out, lays the controls out and
// puts a new repeat in, or swaps repeat's end for a bare placeholder and then a new holder. The emptied ends take no
// touches meanwhile, so a touch on next where it overlaps repeat's end is next's. A landscape row and a row whose ends
// hold other controls (a podcast's) get Spotify's places and the ends' touches back.
- (void)runSpreadChecks {
    UIView *host = box(self.window.rootViewController.view, UIView.class, CGRectMake(0, 200, 390, 96), nil);
    UIStackView *row = [[UIStackView alloc] initWithFrame:CGRectMake(12, 16, 366, 64)];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.distribution = UIStackViewDistributionEqualSpacing;
    [host addSubview:row];
    UIView *shuffleEnd = controlSlot(row, 48, MockEncoreButton.class, @"Components.UI.ShuffleButton");
    UIView *previous = controlSlot(row, 56, MockEncoreButton.class, @"SPTNowPlayingPreviousTrackButton");
    UIView *play = controlSlot(row, 64, _TtC28EncoreConsumerMobile_BaseKit14PlayButtonView.class, @"SPTNowPlayingPlayButton");
    UIView *next = controlSlot(row, 56, MockEncoreButton.class, @"SPTNowPlayingNextTrackButton");
    __block UIView *repeatEnd = controlSlot(row, 48, MockEncoreButton.class, @"Nowplaying-RepeatButton");
    UIView *nextButton = next.subviews.firstObject.subviews.firstObject;
    UIViewController *unit = [_TtC20NowPlaying_ModesImpl28PlaybackControlsElementsUnit new];
    unit.view = host;
    // A pass of the unit as Spotify gives it, the row laid out by its constraints first.
    void (^pass)(void) = ^{
        [row setNeedsLayout];
        [row layoutIfNeeded];
        [unit viewDidLayoutSubviews];
    };
    // Where previous and next are drawn from play's middle, and whether a touch over the part of next that lies over
    // repeat's end (8 pt in from next's outer edge) reaches next.
    NSString *(^state)(BOOL *, BOOL) = ^NSString *(BOOL *right, BOOL spread) {
        CGFloat playX = play.center.x;
        CGFloat previousAt = previous.center.x + previous.transform.tx - playX, nextAt = next.center.x + next.transform.tx - playX;
        CGFloat side = nextAt < 0 ? -1 : 1;
        CGPoint outer = [self.window convertPoint:CGPointMake(next.center.x + next.transform.tx + side * 20, next.center.y) fromView:row];
        UIView *hit = [self.window hitTest:outer withEvent:nil];
        BOOL onNext = [hit isDescendantOfView:nextButton];
        BOOL quiet = !shuffleEnd.userInteractionEnabled && !repeatEnd.userInteractionEnabled;
        BOOL placed = spread ? fabs(fabs(previousAt) - 122) < 0.5 && fabs(fabs(nextAt) - 122) < 0.5 && previousAt * nextAt < 0
                             : CGAffineTransformIsIdentity(previous.transform) && CGAffineTransformIsIdentity(next.transform);
        *right = placed && (spread ? quiet && onNext : shuffleEnd.userInteractionEnabled && repeatEnd.userInteractionEnabled);
        return [NSString stringWithFormat:@"previous %+.1f, next %+.1f pt from play; ends %@; a touch on next over repeat's end lands on %@",
                previousAt, nextAt, quiet ? @"take no touches" : @"take touches", onNext ? @"next" : NSStringFromClass(hit.class)];
    };
    BOOL right = NO;
    NSString *seen;

    pass();
    seen = state(&right, YES);
    [self expect:right step:@"both hidden: previous and next spread" detail:seen];

    UIView *repeatHolder = repeatEnd.subviews.firstObject;
    [repeatHolder.subviews.firstObject removeFromSuperview];
    pass();
    seen = state(&right, YES);
    [self expect:right step:@"repeat taken out and the controls laid out: still spread" detail:seen];

    UIView *replacement = box(repeatHolder, MockEncoreButton.class, repeatHolder.bounds, @"Nowplaying-RepeatButton");
    [host layoutIfNeeded];
    seen = state(&right, YES);
    [self expect:right && replacement.alpha == 0 && !replacement.userInteractionEnabled step:@"a new repeat put in: hidden, still spread"
          detail:[seen stringByAppendingFormat:@"; the new repeat at alpha %.0f", replacement.alpha]];

    // Repeat's end swapped for a bare placeholder, as Spotify leaves where it has no repeat, then for a new holder.
    [row removeArrangedSubview:repeatEnd];
    [repeatEnd removeFromSuperview];
    UIView *placeholder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 48, 48)];
    [placeholder.widthAnchor constraintEqualToConstant:48].active = YES;
    [placeholder.heightAnchor constraintEqualToConstant:48].active = YES;
    [row addArrangedSubview:placeholder];
    repeatEnd = placeholder;
    pass();
    seen = state(&right, YES);
    [self expect:right step:@"repeat's end a bare placeholder: still spread" detail:seen];
    [row removeArrangedSubview:placeholder];
    [placeholder removeFromSuperview];
    repeatEnd = controlSlot(row, 48, MockEncoreButton.class, @"Nowplaying-RepeatButton");
    pass();
    seen = state(&right, YES);
    [self expect:right step:@"a new holder with a new repeat: spread" detail:seen];

    row.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    pass();
    seen = state(&right, YES);
    [self expect:right && next.center.x < play.center.x step:@"right to left: next spread to the left" detail:seen];
    row.semanticContentAttribute = UISemanticContentAttributeUnspecified;

    host.traitOverrides.verticalSizeClass = UIUserInterfaceSizeClassCompact;
    [host updateTraitsIfNeeded];
    pass();
    seen = state(&right, NO);
    [self expect:right step:@"landscape: Spotify's places, the ends' touches back" detail:seen];
    [host.traitOverrides removeTrait:UITraitVerticalSizeClass.class];
    [host updateTraitsIfNeeded];
    pass();
    seen = state(&right, YES);
    [self expect:right step:@"portrait again: spread" detail:seen];

    // A podcast's row in the same holders: other controls at the ends.
    for (UIView *end in @[shuffleEnd, repeatEnd]) {
        UIView *inner = end.subviews.firstObject;
        [inner.subviews.firstObject removeFromSuperview];
        box(inner, MockEncoreButton.class, inner.bounds, end == shuffleEnd ? @"podcast-speed-button" : @"podcast-sleep-timer-button");
    }
    pass();
    seen = state(&right, NO);
    [self expect:right step:@"a podcast's row in the same holders: Spotify's places, the ends' touches back" detail:seen];
    [host removeFromSuperview];
}

- (void)runScrollChecks {
    after(2, ^{
        UIScrollView *list = self->_list;
        CGFloat top = -list.adjustedContentInset.top;
        list.contentOffset = CGPointMake(0, top + 120);
        BOOL up = list.contentOffset.y == top;
        list.contentOffset = CGPointMake(0, top - 80);
        BOOL down = list.contentOffset.y == top - 80;
        [list setContentOffset:CGPointMake(0, top + 300) animated:NO];
        BOOL again = list.contentOffset.y == top;
        list.contentOffset = CGPointMake(0, top);
        NSLog(@"[harness] scroll checks: up %@, down %@, again %@ -- %@", up ? @"held" : @"moved", down ? @"kept" : @"lost",
              again ? @"held" : @"moved", up && down && again ? @"PASS" : @"FAIL");
        if (!(up && down && again)) exit(1);
    });
    // Issue #172: the list's pan is off while the progress bar is scrubbed, back once the scrub ends however
    // it ends, and a pan that was off already stays off.
    after(3, ^{
        UIView *duration = self->_units[1].view;
        UISlider *slider = [[_TtCO17NowPlaying_ECMKit11ProgressBar6Slider alloc] initWithFrame:CGRectMake(24, 0, duration.bounds.size.width - 48, 20)];
        slider.hidden = YES;
        [duration addSubview:slider];
        UIPanGestureRecognizer *pan = self->_list.panGestureRecognizer;
        UITouch *none = nil;   // the mock tracks without one
        NSMutableArray<NSString *> *wrong = [NSMutableArray array];
        void (^expect)(NSString *, BOOL) = ^(NSString *step, BOOL ok) { if (!ok) [wrong addObject:step]; };
        [slider beginTrackingWithTouch:none withEvent:nil];
        expect(@"held while scrubbing", !pan.enabled);
        [slider endTrackingWithTouch:none withEvent:nil];
        expect(@"back at the end", pan.enabled);
        [slider beginTrackingWithTouch:none withEvent:nil];
        [slider cancelTrackingWithEvent:nil];
        expect(@"back at a cancel", pan.enabled);
        [slider beginTrackingWithTouch:none withEvent:nil];
        [slider removeFromSuperview];
        expect(@"back when the slider left the window", pan.enabled);
        [duration addSubview:slider];
        pan.enabled = NO;
        [slider beginTrackingWithTouch:none withEvent:nil];
        [slider endTrackingWithTouch:none withEvent:nil];
        expect(@"off already, left off", !pan.enabled);
        pan.enabled = YES;
        [slider removeFromSuperview];
        NSLog(@"[harness] scrub checks: %@ -- %@", wrong.count ? [wrong componentsJoinedByString:@", "] : @"all right",
              wrong.count ? @"FAIL" : @"PASS");
        exit(wrong.count ? 1 : 0);
    });
}

#pragma mark - the cover's room

// Issue #77: Spotify keeps room for the lyric preview under the cover of a track with lyrics, so the cover
// was smaller and higher with a blank band under it. Here the cover is untouched first (a track without
// lyrics), then given Spotify's layout for one with lyrics, and must fill its room again.
- (void)runCoverChecks {
    __block NSUInteger right = 0, checks = 0;
    void (^check)(NSString *, BOOL, NSString *) = ^(NSString *step, BOOL ok, NSString *detail) {
        checks++;
        if (ok) right++;
        NSLog(@"[harness] cover %@: %@ -- %@", step, detail, ok ? @"ok" : @"WRONG");
    };
    UIView *tilt = _tilt, *room = tilt.superview;
    UIView *preview = nil;
    for (UIView *view in room.subviews) {
        if ([view isKindOfClass:_TtC22Lyrics_NPVContainerKit19LyricsContainerView.class]) preview = view;
    }
    CGFloat side = MIN(room.bounds.size.width, room.bounds.size.height);
    CGRect square = CGRectMake(round((room.bounds.size.width - side) / 2), round((room.bounds.size.height - side) / 2), side, side);
    after(1.5, ^{
        check(@"without lyrics", CGRectEqualToRect(tilt.frame, square), NSStringFromCGRect(tilt.frame));
        NSLog(@"[harness] cover: screenshot without lyrics now");
    });
    after(2, ^{
        // What Spotify does for a track with lyrics: the preview under the cover, the cover shrunk above it.
        CGFloat small = side - 72;
        tilt.frame = CGRectMake(round((room.bounds.size.width - small) / 2), 0, small, small);
        preview.frame = CGRectMake(0, small + 8, room.bounds.size.width, 64);
        [preview invalidateIntrinsicContentSize];
        [self->_covers setNeedsLayout];
        [self->_covers layoutIfNeeded];
    });
    after(2.5, ^{
        check(@"the preview takes no room", CGSizeEqualToSize(preview.frame.size, CGSizeZero)
              && CGSizeEqualToSize(preview.intrinsicContentSize, CGSizeZero) && CGSizeEqualToSize([preview sizeThatFits:room.bounds.size], CGSizeZero),
              [NSString stringWithFormat:@"frame %@, intrinsic %@", NSStringFromCGRect(preview.frame), NSStringFromCGSize(preview.intrinsicContentSize)]);
        check(@"with lyrics, the cover fills its room", CGRectEqualToRect(tilt.frame, square), NSStringFromCGRect(tilt.frame));
        CGRect drawn = SGRPlayerCoverFrameIn(room);
        check(@"the Kit sees it", CGRectEqualToRect(CGRectIntegral(drawn), square),
              [NSString stringWithFormat:@"%@, the picture %@", NSStringFromCGRect(drawn), NSStringFromCGSize(self->_cover.bounds.size)]);
        NSLog(@"[harness] cover: screenshot with lyrics now");
    });
    after(3, ^{
        NSLog(@"[harness] cover checks: %lu of %lu right -- %@", (unsigned long)right, (unsigned long)checks, right == checks ? @"PASS" : @"FAIL");
    });
}

#pragma mark - the lines on their own

static UIView *lyricsOverlay(UIView *host) {
    for (UIView *view in host.subviews) {
        if ([NSStringFromClass(view.class) isEqualToString:@"SGRPlayerLyricsOverlay"]) return view;
    }
    return nil;
}

// Whether the lines' own tap, the one that seeks, is on.
static BOOL linesSeek(SGRKaraokeView *lyrics) {
    BOOL on = NO;
    for (UIGestureRecognizer *recognizer in lyrics.gestureRecognizers) {
        if ([recognizer isKindOfClass:UITapGestureRecognizer.class]) on = on || recognizer.enabled;
    }
    return on;
}

// The lyrics up and left alone past the rest: only the controls under them fade, the lines grow down into
// their room and still scroll, a tap brings the controls back and is not a seek, a scroll hides them again
// and the thumbnail closes the lyrics from there.
- (void)runImmersiveChecks {
    __block NSUInteger right = 0, checks = 0;
    void (^check)(NSString *, BOOL, NSString *) = ^(NSString *step, BOOL ok, NSString *detail) {
        checks++;
        if (ok) right++;
        NSLog(@"[harness] immersive %@: %@ -- %@", step, detail, ok ? @"ok" : @"WRONG");
    };
    UIView *host = _host;
    UIView *info = _units[0].view, *duration = _units[1].view, *playback = _units[3].view, *footer = _units[4].view;
    UIGestureRecognizer *wake = nil;
    for (UIGestureRecognizer *recognizer in host.gestureRecognizers) {
        if ([NSStringFromClass(recognizer.class) isEqualToString:@"SGRPlayerWake"]) wake = recognizer;
    }
    __block CGRect withControls = CGRectNull;
    UIView *(^stage)(void) = ^UIView *{ return [lyricsOverlay(host) valueForKey:@"stage"]; };
    SGRKaraokeView *(^lines)(void) = ^SGRKaraokeView *{ return [lyricsOverlay(host) valueForKey:@"lyrics"]; };
    // Everything in the bottom stack but the title row and the chips: the volume row too, where there is one.
    NSMutableArray<UIView *> *lower = [NSMutableArray array];
    for (UIView *view in info.superview.subviews) {
        if (view != info && view != self->_units[2].view) [lower addObject:view];
    }
    BOOL (^lowerHidden)(void) = ^BOOL { for (UIView *v in lower) if (v.alpha != 0) return NO; return lower.count >= 3; };
    BOOL (^lowerShown)(void) = ^BOOL { for (UIView *v in lower) if (v.alpha != 1) return NO; return lower.count >= 3; };

    after(1.5, ^{ SGRPlayerToggleLyrics(); });
    after(3, ^{
        withControls = [host convertRect:stage().bounds fromView:stage()];
        check(@"open, with the controls", SGRPlayerLyricsOpen() && lowerShown() && !wake.enabled && linesSeek(lines()),
              [NSString stringWithFormat:@"lines %@, wake %d, lines seek %d", NSStringFromCGRect(withControls), wake.enabled, linesSeek(lines())]);
    });
    // kRest is 4 s from the open.
    after(7, ^{
        UIView *thumb = [lyricsOverlay(host) valueForKey:@"thumb"];
        check(@"only the controls under the lines fade", lowerHidden() && info.alpha == 1 && thumb.alpha == 1,
              [NSString stringWithFormat:@"%lu views under the title row %@, progress %.0f, buttons %.0f, footer %.0f, title row %.0f, thumbnail %.0f",
               (unsigned long)lower.count, lowerHidden() ? @"faded" : @"not all faded", duration.alpha, playback.alpha, footer.alpha, info.alpha, thumb.alpha]);
        CGRect alone = [host convertRect:stage().bounds fromView:stage()];
        CGRect safe = UIEdgeInsetsInsetRect(host.bounds, host.safeAreaInsets);
        check(@"the lines grow down only", CGRectGetMinY(alone) == CGRectGetMinY(withControls) && CGRectGetMaxY(alone) > CGRectGetMaxY(withControls)
              && CGRectGetMaxY(alone) <= CGRectGetMaxY(safe),
              [NSString stringWithFormat:@"%@ from %@, safe area to %.0f", NSStringFromCGRect(alone), NSStringFromCGRect(withControls), CGRectGetMaxY(safe)]);
        // Where the buttons were, the lines now take the touch: a drag scrolls them.
        CGPoint onButtons = [host convertPoint:CGPointMake(CGRectGetMidX(playback.bounds), CGRectGetMidY(playback.bounds)) fromView:playback];
        UIView *hit = [host hitTest:onButtons withEvent:nil];
        check(@"a touch on the lines lands on them", [hit isDescendantOfView:lines()],
              [NSString stringWithFormat:@"%@", NSStringFromClass(hit.class)]);
        CGPoint onThumb = [host convertPoint:CGPointMake(CGRectGetMidX(thumb.bounds), CGRectGetMidY(thumb.bounds)) fromView:thumb];
        UIView *thumbHit = [host hitTest:onThumb withEvent:nil];
        check(@"the thumbnail takes its touch", [thumbHit isDescendantOfView:thumb], NSStringFromClass(thumbHit.class));
        check(@"a tap wakes, the lines do not seek", wake.enabled && !linesSeek(lines()),
              [NSString stringWithFormat:@"wake %d, lines seek %d", wake.enabled, linesSeek(lines())]);
        NSLog(@"[harness] immersive: screenshot alone now");
    });
    after(8, ^{
        [wake sgr_woke];
        // Off still for the rest of this turn of the run loop, which the tap that woke is part of.
        check(@"the waking tap does not seek", lowerShown() && !linesSeek(lines()),
              [NSString stringWithFormat:@"controls %.0f, lines seek %d", duration.alpha, linesSeek(lines())]);
    });
    after(8.5, ^{
        check(@"woken", lowerShown() && !wake.enabled && linesSeek(lines()),
              [NSString stringWithFormat:@"controls %.0f, wake %d, lines seek %d", duration.alpha, wake.enabled, linesSeek(lines())]);
        // A scroll through the lines leaves them alone at once.
        lines().browsingBegan();
        check(@"a scroll hides the controls", lowerHidden() && wake.enabled, [NSString stringWithFormat:@"controls %.0f", duration.alpha]);
    });
    after(9.5, ^{
        [lyricsOverlay(host) sgr_thumbTapped];
        check(@"the thumbnail closes the lyrics while alone", !SGRPlayerLyricsOpen() && lowerShown() && !wake.enabled,
              [NSString stringWithFormat:@"lyrics %@, controls %.0f", SGRPlayerLyricsOpen() ? @"up" : @"down", duration.alpha]);
    });
    // A sheet over the player keeps the controls up past the rest, and the clock runs again behind it, so
    // they fade within a rest of the sheet going.
    after(11.5, ^{ SGRPlayerToggleLyrics(); });
    __block UIViewController *sheet = nil;
    after(12, ^{
        sheet = [UIViewController new];
        sheet.view.backgroundColor = UIColor.darkGrayColor;
        [self.window.rootViewController presentViewController:sheet animated:NO completion:nil];
    });
    after(17, ^{
        check(@"a sheet keeps the controls up", SGRPlayerLyricsOpen() && lowerShown(), [NSString stringWithFormat:@"controls %.0f", duration.alpha]);
        [sheet dismissViewControllerAnimated:NO completion:nil];
    });
    after(22, ^{
        check(@"they fade once the sheet has gone", lowerHidden(), [NSString stringWithFormat:@"controls %.0f", duration.alpha]);
        // Sing's mic stays with the lines on their own, and takes its own touch.
        UIView *mic = nil;
        for (UIView *view in lines().subviews) {
            if ([NSStringFromClass(view.class) isEqualToString:@"SGRSingButton"]) mic = view;
        }
        CGPoint onMic = [host convertPoint:CGPointMake(CGRectGetMidX(mic.bounds), CGRectGetMidY(mic.bounds)) fromView:mic];
        UIView *hit = [host hitTest:onMic withEvent:nil];
        CGRect drawn = [host convertRect:mic.bounds fromView:mic];
        check(@"the mic stays and takes its touch", mic && ![[mic valueForKey:@"tucked"] boolValue] && mic.userInteractionEnabled && [hit isDescendantOfView:mic]
              && CGRectGetMaxY(drawn) > CGRectGetMaxY(withControls),
              [NSString stringWithFormat:@"mic %@ at %@, hit %@", mic ? @"there" : @"missing", NSStringFromCGRect(drawn), NSStringFromClass(hit.class)]);
        NSLog(@"[harness] immersive: screenshot the mic alone now");
    });
    after(28, ^{ [wake sgr_woke]; });
    // A finger held on the player (Sing's slider) holds the clock, and lifting it starts the clock over.
    __block UIGestureRecognizer *watcher = nil;
    after(28.5, ^{
        for (UIGestureRecognizer *recognizer in host.gestureRecognizers) {
            if ([NSStringFromClass(recognizer.class) isEqualToString:@"SGRPlayerTouchWatcher"]) watcher = recognizer;
        }
        [watcher touchesBegan:[NSSet set] withEvent:[UIEvent new]];
    });
    after(34, ^{
        check(@"a finger held keeps the controls up", watcher && lowerShown(), [NSString stringWithFormat:@"controls %.0f", duration.alpha]);
        [watcher reset];
    });
    after(39, ^{
        check(@"lifted, the clock runs out", lowerHidden(), [NSString stringWithFormat:@"controls %.0f", duration.alpha]);
    });
    after(40, ^{
        NSLog(@"[harness] immersive checks: %lu of %lu right -- %@", (unsigned long)right, (unsigned long)checks, right == checks ? @"PASS" : @"FAIL");
    });
}

#pragma mark - tap to seek

// The tap around the progress bar (PlayerControls.x): where it lands, what it maps to, and how it seeks. The
// slider is the mock's, given Spotify's identifier, with the two times beside it. A tap is the recognizer's
// action with its starting point set, since the harness cannot make a touch.
- (void)runSeekChecks {
    __block NSUInteger right = 0, checks = 0;
    void (^check)(NSString *, BOOL, NSString *) = ^(NSString *step, BOOL ok, NSString *detail) {
        checks++;
        if (ok) right++;
        NSLog(@"[harness] seek %@: %@ -- %@", step, detail, ok ? @"ok" : @"WRONG");
    };
    UIViewController *durationUnit = _units[1];
    UIView *unit = durationUnit.view;
    CGFloat W = unit.bounds.size.width;
    UISlider *slider = [[_TtCO17NowPlaying_ECMKit11ProgressBar6Slider alloc] initWithFrame:CGRectMake(24, 2, W - 48, 14)];
    slider.accessibilityIdentifier = @"SPTNowPlayingSliderV2";
    slider.value = 0.22;
    [unit addSubview:slider];
    UILabel *taken = [[UILabel alloc] initWithFrame:CGRectMake(24, 20, 44, 16)];
    taken.accessibilityIdentifier = @"now-playing-time-take-label";
    UILabel *remaining = [[UILabel alloc] initWithFrame:CGRectMake(W - 24 - 44, 20, 44, 16)];
    remaining.accessibilityIdentifier = @"now-playing-time-remaning-label";
    [unit addSubview:taken];
    [unit addSubview:remaining];
    [durationUnit viewDidLayoutSubviews];
    [SGPlayerState() setValue:@200 forKey:@"duration"];

    UIGestureRecognizer *tap = nil;
    for (UIGestureRecognizer *recognizer in unit.gestureRecognizers) {
        if ([NSStringFromClass(recognizer.class) isEqualToString:@"SGRSeekTap"]) tap = recognizer;
    }
    CGRect bar = slider.frame;
    CGRect thumb = [unit convertRect:[slider thumbRectForBounds:slider.bounds trackRect:[slider trackRectForBounds:slider.bounds] value:slider.value] fromView:slider];
    check(@"on the duration unit", tap != nil, tap ? @"a recognizer there" : @"none");
    check(@"under the bar", SGRSeekTapLands(unit, slider, CGPointMake(W / 2, CGRectGetMaxY(bar) + 12)), @"12pt below the bar");
    check(@"past the ends", SGRSeekTapLands(unit, slider, CGPointMake(CGRectGetMinX(bar) - 10, 8)) && SGRSeekTapLands(unit, slider, CGPointMake(CGRectGetMaxX(bar) + 10, 8))
          && !SGRSeekTapLands(unit, slider, CGPointMake(CGRectGetMinX(bar) - 20, 8)), @"10pt past either end, not 20");
    check(@"not on the thumb", !SGRSeekTapLands(unit, slider, CGPointMake(CGRectGetMidX(thumb), CGRectGetMidY(thumb))), NSStringFromCGRect(thumb));
    check(@"not on the times", !SGRSeekTapLands(unit, slider, taken.center) && !SGRSeekTapLands(unit, slider, remaining.center), @"either time");
    CGFloat end = SGRSeekShareAt(slider, CGPointMake(slider.bounds.size.width - 1, 7)), start = SGRSeekShareAt(slider, CGPointMake(1, 7));
    CGFloat middle = SGRSeekShareAt(slider, CGPointMake(slider.bounds.size.width / 2, 7));
    check(@"the ends are the song's", end == 1 && start == 0 && fabs(middle - 0.5) < 0.001,
          [NSString stringWithFormat:@"start %.3f, middle %.3f, end %.3f", start, middle, end]);

    // A tap at three quarters of the thumb's travel, played to the slider as a drag.
    NSMutableArray<NSNumber *> *events = [NSMutableArray array];
    __block BOOL answers = NO;
    for (NSNumber *event in @[@(UIControlEventTouchDown), @(UIControlEventValueChanged), @(UIControlEventTouchUpInside)]) {
        [slider addAction:[UIAction actionWithHandler:^(UIAction *action) {
            [events addObject:event];
            if (answers && event.unsignedIntegerValue == UIControlEventTouchUpInside) SGKaraokeSeek((NSInteger)(slider.value * 200000));
        }] forControlEvents:event.unsignedIntegerValue];
    }
    CGFloat from = CGRectGetMidX([slider thumbRectForBounds:slider.bounds trackRect:[slider trackRectForBounds:slider.bounds] value:0]);
    CGFloat to = CGRectGetMidX([slider thumbRectForBounds:slider.bounds trackRect:[slider trackRectForBounds:slider.bounds] value:1]);
    void (^tapAt)(CGFloat) = ^(CGFloat share) {
        CGPoint point = [unit convertPoint:CGPointMake(from + share * (to - from), 7) fromView:slider];
        [tap setValue:[NSValue valueWithCGPoint:point] forKey:@"start"];
        ((void (*)(id, SEL))objc_msgSend)(tap, NSSelectorFromString(@"sgr_seek"));
    };
    tapAt(0.75);
    NSArray *drag = @[@(UIControlEventTouchDown), @(UIControlEventValueChanged), @(UIControlEventTouchUpInside)];
    check(@"played as a drag", [events isEqualToArray:drag] && fabs(slider.value - 0.75) < 0.001 && slider.isTracking,
          [NSString stringWithFormat:@"%lu events, value %.3f, tracking %d", (unsigned long)events.count, slider.value, slider.isTracking]);
    // Nothing seeked for it: after a second the tap seeks directly, and the slider lets go.
    after(1.3, ^{
        NSInteger at = SGKaraokePositionMs();
        check(@"a drag that did not seek is seeked", labs(at - 150000) < 1000 && !slider.isTracking,
              [NSString stringWithFormat:@"at %ld ms, tracking %d", (long)at, slider.isTracking]);
        // Spotify seeking for the drag: the slider lets go as the position arrives.
        answers = YES;
        tapAt(0.3);
        NSInteger now = SGKaraokePositionMs();
        check(@"the slider lets go once the position is there", labs(now - 60000) < 1000 && !slider.isTracking,
              [NSString stringWithFormat:@"at %ld ms, tracking %d", (long)now, slider.isTracking]);
    });
    after(2.6, ^{
        NSLog(@"[harness] seek checks: %lu of %lu right -- %@", (unsigned long)right, (unsigned long)checks, right == checks ? @"PASS" : @"FAIL");
    });
}

// One track, then another album's at 8 s, its picture on the screens 0.4 s later.
// The header's glass circles press in under a finger (PlayerHeader.x): held on the down arrow and then on the
// ⋯, each circle is smaller while the finger is down and whole again once it lifts.
- (void)headerDown:(UIControl *)control {
    _headerDowns++;
}

- (void)runHeaderChecks {
    __block NSUInteger right = 0, checks = 0;
    void (^check)(NSString *, BOOL, NSString *) = ^(NSString *step, BOOL ok, NSString *detail) {
        checks++;
        if (ok) right++;
        NSLog(@"[harness] header %@: %@ -- %@", step, detail, ok ? @"ok" : @"WRONG");
    };
    UIView *header = _units.firstObject.view;
    NSMutableArray<UIView *> *buttons = [NSMutableArray array];
    for (UIView *view in header.subviews) if ([view isKindOfClass:MockEncoreButton.class]) [buttons addObject:view];
    check(@"buttons", buttons.count == 2, [NSString stringWithFormat:@"%lu Encore buttons in the header", (unsigned long)buttons.count]);
    __block NSUInteger i = 0;
    __block void (^next)(void);
    next = ^{
        if (i == buttons.count) {
            NSLog(@"[harness] header checks: %lu of %lu right -- %@", (unsigned long)right, (unsigned long)checks, right == checks ? @"PASS" : @"FAIL");
            next = nil;
            return;
        }
        UIView *button = buttons[i++];
        NSString *name = button.accessibilityIdentifier;
        UIView *circle = button.subviews.firstObject;
        check(name, [circle isKindOfClass:UIVisualEffectView.class] && circle.bounds.size.width == 44, [NSString stringWithFormat:@"a 44pt glass circle first in it (%@)", NSStringFromClass(circle.class)]);
        CGPoint middle = [button convertPoint:CGPointMake(CGRectGetMidX(button.bounds), CGRectGetMidY(button.bounds)) toView:nil];
        check(name, [self.window hitTest:middle withEvent:nil] == button, @"a touch at its middle lands on the button");
        [(UIControl *)button addTarget:self action:@selector(headerDown:) forControlEvents:UIControlEventTouchDown];
        SGHarnessHold(self.window, middle, 0.5);
        after(0.4, ^{
            CGFloat scale = circle.transform.a;
            check(name, scale < 0.95, [NSString stringWithFormat:@"its circle pressed in while the finger is down (scale %.2f, touch down events %lu, tracking %d)", scale, (unsigned long)self->_headerDowns, ((UIControl *)button).tracking]);
        });
        after(1.2, ^{
            CGFloat scale = [[circle.layer.presentationLayer valueForKeyPath:@"transform.scale.x"] doubleValue];
            check(name, fabs(scale - 1) < 0.01 && CGAffineTransformIsIdentity(circle.transform), [NSString stringWithFormat:@"and whole again once it lifts (scale %.2f)", scale]);
            next();
        });
    };
    after(2, next);
}

#pragma mark - the Player page's look switches and Grain

// The Kit's glass circle in a header button (SGRGlassInside): the 44pt view in it that is not the button's glyph.
static UIView *circleIn(UIView *button) {
    for (UIView *sub in button.subviews) {
        if (![sub isKindOfClass:UIImageView.class] && CGSizeEqualToSize(sub.bounds.size, CGSizeMake(44, 44))) return sub;
    }
    return nil;
}

// The Music app's glyph a stand-in draws over a glyph view of Spotify's, or nil.
static UIView *standInIn(UIView *drawn) {
    for (UIView *sub in drawn.subviews) {
        if ([NSStringFromClass(sub.class) isEqualToString:@"SGRGlyphView"]) return sub;
    }
    return nil;
}

// The grabber over a header row: its 36x5 pill.
static UIView *grabberIn(UIView *header) {
    for (UIView *sub in header.subviews) {
        if (CGSizeEqualToSize(sub.bounds.size, CGSizeMake(36, 5))) return sub;
    }
    return nil;
}

static NSUInteger metalLayersIn(CALayer *layer) {
    NSUInteger count = [layer isKindOfClass:CAMetalLayer.class];
    for (CALayer *sublayer in layer.sublayers) count += metalLayersIn(sublayer);
    return count;
}

static CALayer *fluidLayerIn(CALayer *layer) {
    if ([NSStringFromClass(layer.class) isEqualToString:@"SGRFluidLayer"]) return layer;
    for (CALayer *sublayer in layer.sublayers) {
        CALayer *found = fluidLayerIn(sublayer);
        if (found) return found;
    }
    return nil;
}

// The field's top band, above the header row, drawn at one pixel a point (the Smooth renderer's own), as RGBA bytes.
static NSData *fieldBand(UIView *field) {
    CGSize size = CGSizeMake(round(field.bounds.size.width), 56);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.scale = 1;
    format.opaque = YES;
    UIImage *image = [[[UIGraphicsImageRenderer alloc] initWithSize:size format:format] imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [field drawViewHierarchyInRect:field.bounds afterScreenUpdates:YES];
    }];
    size_t width = (size_t)size.width, height = (size_t)size.height;
    NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(pixels.mutableBytes, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), image.CGImage);
    CGContextRelease(bitmap);
    return pixels;
}

// The grain in a band: how far each pixel's green is from its right-hand neighbor's, in eight-bit steps, on average. The
// blurred cover barely changes from one pixel to the next, so what is left is the noise.
static double grainIn(NSData *pixels, CGFloat width) {
    const uint8_t *p = pixels.bytes;
    size_t w = (size_t)width, rows = pixels.length / 4 / w;
    double total = 0;
    size_t count = 0;
    for (size_t y = 0; y < rows; y++) {
        for (size_t x = 0; x + 1 < w; x++) {
            total += abs((int)p[(y * w + x) * 4 + 1] - (int)p[(y * w + x + 1) * 4 + 1]);
            count++;
        }
    }
    return count ? total / count : 0;
}

// How far apart two bands are: the mean difference of their color channels, in eight-bit steps.
static double bandDiff(NSData *a, NSData *b) {
    if (a.length != b.length || !a.length) return INFINITY;
    const uint8_t *p = a.bytes, *q = b.bytes;
    double total = 0;
    for (NSUInteger i = 0; i < a.length; i++) {
        if (i % 4 != 3) total += abs((int)p[i] - (int)q[i]);
    }
    return total / (a.length / 4 * 3);
}

// The Light renderer's copies (SGRFluid.m) hidden, as a count of four.
static NSUInteger hiddenCopiesIn(CALayer *fluid) {
    NSUInteger hidden = 0;
    for (CALayer *sublayer in fluid.sublayers) {
        if (!sublayer.contentsGravity || ![sublayer.contentsGravity isEqualToString:kCAGravityResizeAspectFill]) continue;
        hidden += sublayer.hidden;
    }
    return hidden;
}

// The switch from Smooth to Light with the song paused, five times: the field read about 0.2, 0.5, 1 and 2 s after it (each
// read's own time logged), each compared with the band it settles on, read about 4 s after. Only Kit API the committed
// renderer has too, so the same scenario runs against HEAD's SGRFluid.m and SGRFluidGPU.m.
- (void)runRendererChecks {
    static const NSUInteger kCycles = 5;
    NSArray<NSNumber *> *offsets = @[@0.2, @0.5, @1, @2];
    NSMutableArray<NSArray *> *script = [NSMutableArray array];
    void (^step)(NSTimeInterval, dispatch_block_t) = ^(NSTimeInterval delay, dispatch_block_t block) { [script addObject:@[@(delay), block]]; };
    NSString *(^state)(void) = ^NSString *{
        UIView *field = (UIView *)SGRPlayerField();
        CALayer *fluid = fluidLayerIn(field.layer);
        return [NSString stringWithFormat:@"Smooth %@, %lu Metal layers, %lu of 4 copies hidden", [[fluid valueForKey:@"_gpuShown"] boolValue] ? @"showing" : @"not showing",
                (unsigned long)metalLayersIn(field.layer), (unsigned long)hiddenCopiesIn(fluid)];
    };
    step(2, ^{ SGRHarnessSetTrack(@"spotify:track:harnessA", imageURI(@"aaaa"), YES); });
    for (NSUInteger cycle = 0; cycle < kCycles; cycle++) {
        __block CFTimeInterval switchedAt = 0;
        NSMutableDictionary<NSNumber *, NSData *> *early = [NSMutableDictionary dictionary];
        NSMutableDictionary<NSNumber *, NSString *> *states = [NSMutableDictionary dictionary];
        step(1, ^{ SGRSetFluidRenderer(SGRFluidRendererSmooth); });
        step(3, ^{
            NSLog(@"[harness] renderer cycle %lu before the switch: %@", (unsigned long)cycle + 1, state());
            switchedAt = CACurrentMediaTime();
            SGRSetFluidRenderer(SGRFluidRendererLight);
        });
        __block double previous = 0;
        for (NSNumber *offset in offsets) {
            step(offset.doubleValue - previous, ^{
                early[offset] = fieldBand((UIView *)SGRPlayerField());
                states[offset] = [NSString stringWithFormat:@"read at +%.2f s, %@", CACurrentMediaTime() - switchedAt, state()];
            });
            previous = offset.doubleValue;
        }
        step(2, ^{
            NSData *settled = fieldBand((UIView *)SGRPlayerField());
            NSMutableArray<NSString *> *seen = [NSMutableArray array];
            for (NSNumber *offset in offsets) [seen addObject:[NSString stringWithFormat:@"%.3f steps off (%@)", bandDiff(early[offset], settled), states[offset]]];
            [self expect:[early[@1] isEqualToData:settled] step:[NSString stringWithFormat:@"cycle %lu, Light a second after the switch as it settles", (unsigned long)cycle + 1]
                  detail:[NSString stringWithFormat:@"settled at +%.2f s; %@", CACurrentMediaTime() - switchedAt, [seen componentsJoinedByString:@"; "]]];
        });
    }
    step(0.5, ^{
        NSLog(@"[harness] renderer checks: %lu of %lu right -- %@", (unsigned long)(self->_checks - self->_failures), (unsigned long)self->_checks,
              self->_failures ? @"FAIL" : @"PASS");
        exit(self->_failures ? 1 : 0);
    });
    runScript(script, 0);
}

// Header glass and Music app icons switched off and on again on the Player page while the player is open, in the ordinary
// player and the AI DJ's; then Grain at 0, 100 and 200% on the Smooth renderer, and on the Light one, which has none.
- (void)runOptionsChecks {
    __block UINavigationController *nav;
    SGModPage *(^page)(void) = ^{ return (SGModPage *)nav.topViewController; };
    UIView *header = _units.firstObject.view, *djHeader = _djHeader;
    NSMutableArray<UIView *> *buttons = [NSMutableArray array];
    for (UIView *row in @[header, djHeader]) {
        for (UIView *view in row.subviews) if ([view isKindOfClass:MockEncoreButton.class]) [buttons addObject:view];
    }
    UIImageView *connect = _connectImage, *djConnect = _djConnectImage;
    SPTEncoreIconView *queue = _queueIcon;
    UIImage *spotifyConnect = _spotifyConnect, *djSpotifyConnect = _djSpotifyConnect;

    void (^open)(void) = ^{
        nav = [[UINavigationController alloc] initWithRootViewController:SGRPlayerSettingsPage(@[])];
        // Over the player, which stays in the window and lays out as it would under Mod Settings.
        nav.modalPresentationStyle = UIModalPresentationOverFullScreen;
        [self.window.rootViewController presentViewController:nav animated:NO completion:nil];
    };
    void (^close)(void) = ^{ [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil]; };
    SGModRow *(^rowTitled)(NSString *) = ^SGModRow *(NSString *title) {
        for (SGModSection *section in page().sections) for (SGModRow *row in section.rows) if ([row.title isEqualToString:title]) return row;
        return nil;
    };
    NSIndexPath *(^pathOf)(SGModRow *) = ^NSIndexPath *(SGModRow *row) {
        NSArray<NSArray *> *shown = [page() valueForKey:@"_shown"];
        for (NSUInteger s = 0; s < shown.count; s++) {
            NSUInteger r = [shown[s] indexOfObject:row];
            if (r != NSNotFound) return [NSIndexPath indexPathForRow:(NSInteger)r inSection:(NSInteger)s];
        }
        return nil;
    };
    // A row's switch flipped as a finger flips it: the page's own handler stores it and tells the player.
    BOOL (^flip)(NSString *, BOOL) = ^BOOL(NSString *title, BOOL on) {
        NSIndexPath *path = pathOf(rowTitled(title));
        if (!path) return NO;
        UITableView *table = page().tableView;
        [table scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
        [table layoutIfNeeded];
        UIView *accessory = [table cellForRowAtIndexPath:path].accessoryView;
        UIControl *toggle = [accessory respondsToSelector:@selector(isOn)] ? (UIControl *)accessory : nil;
        for (UIView *sub in accessory.subviews) if (!toggle && [sub respondsToSelector:@selector(isOn)]) toggle = (UIControl *)sub;
        if (!toggle) return NO;
        [(UISwitch *)toggle setOn:on];
        [toggle sendActionsForControlEvents:UIControlEventValueChanged];
        return YES;
    };
    void (^expectGlass)(NSString *, BOOL) = ^(NSString *step, BOOL on) {
        NSMutableArray<NSString *> *seen = [NSMutableArray array];
        BOOL ok = buttons.count == 4;
        for (UIView *button in buttons) {
            UIView *circle = circleIn(button), *row = button.superview;
            CGPoint middle = CGPointMake(CGRectGetMidX(button.frame), CGRectGetMidY(button.frame));
            BOOL hits = [row hitTest:middle withEvent:nil] == button;
            BOOL shape = on ? [circle isKindOfClass:UIVisualEffectView.class] && button.subviews.firstObject == circle : circle == nil;
            BOOL kept = grabberIn(row) != nil && button.accessibilityIdentifier.length && !button.accessibilityElementsHidden && button.userInteractionEnabled;
            ok = ok && shape && hits && kept;
            [seen addObject:[NSString stringWithFormat:@"%@ %@: circle %@, touch %@, grabber %@", row == djHeader ? @"DJ" : @"player",
                             button.accessibilityIdentifier, circle ? NSStringFromClass(circle.class) : @"none", hits ? @"lands" : @"MISSES",
                             grabberIn(row) ? @"up" : @"gone"]];
        }
        [self expect:ok step:step detail:[seen componentsJoinedByString:@"; "]];
    };
    void (^expectIcons)(NSString *, BOOL, UIImage *) = ^(NSString *step, BOOL on, UIImage *spotify) {
        BOOL ordinary = on ? standInIn(connect) && connect.image != spotify : !standInIn(connect) && connect.image == spotify;
        BOOL dj = on ? standInIn(djConnect) && djConnect.image != djSpotifyConnect : !standInIn(djConnect) && djConnect.image == djSpotifyConnect;
        BOOL queued = on ? standInIn(queue) && [queue.foregroundColor isEqual:UIColor.clearColor]
                         : !standInIn(queue) && [queue.foregroundColor isEqual:UIColor.whiteColor] && [queue.activeForegroundColor isEqual:UIColor.greenColor];
        [self expect:ordinary && dj && queued step:step
              detail:[NSString stringWithFormat:@"Connect: stand-in %@, Spotify's glyph %@; DJ Connect: stand-in %@, Spotify's glyph %@; queue: stand-in %@, colors %@ / %@",
                      standInIn(connect) ? @"in" : @"out", connect.image == spotify ? @"shown" : @"cleared", standInIn(djConnect) ? @"in" : @"out",
                      djConnect.image == djSpotifyConnect ? @"shown" : @"cleared", standInIn(queue) ? @"in" : @"out", queue.foregroundColor, queue.activeForegroundColor]];
    };

    // Lyrics in both footers and the AI DJ's Queue: the Music app's symbol while the switch is on, Spotify's Encore glyph
    // (the mock's own symbol) in the symbol's color while it is off; the DJ button a waveform over its masked disc, or the disc.
    UIView *footerHost = _units[5].view, *djFooter = _djFooter, *djButton = _djButton, *djConnectView = _djConnect, *djShare = _djShare;
    SGRGlyphButton *(^titled)(UIView *, NSString *) = ^SGRGlyphButton *(UIView *host, NSString *title) {
        for (UIView *sub in host.subviews) if ([sub isKindOfClass:SGRGlyphButton.class] && [sub.accessibilityLabel isEqualToString:title]) return (SGRGlyphButton *)sub;
        return nil;
    };
    SPTEncoreIconView *(^encoreIn)(UIView *) = ^SPTEncoreIconView *(UIView *button) {
        for (UIView *sub in button.subviews) if ([sub isKindOfClass:SPTEncoreIconView.class]) return (SPTEncoreIconView *)sub;
        return nil;
    };
    SGRGlyphView *(^waveIn)(UIView *) = ^SGRGlyphView *(UIView *host) {
        for (UIView *sub in host.subviews) if ([sub isKindOfClass:SGRGlyphView.class] && [((SGRGlyphView *)sub).symbol isEqualToString:@"waveform"]) return (SGRGlyphView *)sub;
        return nil;
    };
    void (^expectGlyphs)(NSString *, BOOL) = ^(NSString *step, BOOL on) {
        NSMutableArray<NSString *> *seen = [NSMutableArray array];
        BOOL ok = YES;
        for (NSArray *drawn in @[@[footerHost, @"Lyrics", @"microphone"], @[djFooter, @"Lyrics", @"microphone"], @[djFooter, @"Queue", @"queue"]]) {
            SGRGlyphButton *button = titled(drawn[0], drawn[1]);
            SPTEncoreIconView *encore = encoreIn(button);
            BOOL right = button && (on ? !button.glyph.hidden && !encore
                                       : button.glyph.hidden && [[encore.icon name] isEqualToString:drawn[2]] && [encore.foregroundColor isEqual:button.glyph.tintColor]
                                         && !encore.userInteractionEnabled && encore.accessibilityElementsHidden);
            ok = ok && right;
            [seen addObject:[NSString stringWithFormat:@"%@ %@: %@", drawn[0] == djFooter ? @"DJ" : @"player", drawn[1],
                             !button ? @"NOT FOUND" : encore ? [NSString stringWithFormat:@"Encore %@", [encore.icon name]] : button.glyph.hidden ? @"nothing" : button.glyph.symbol]];
        }
        UIView *djHolder = djButton.superview;
        SGRGlyphView *wave = waveIn(djFooter);
        CGPoint drawnDJ = [djFooter convertPoint:CGPointMake(CGRectGetMidX(djButton.bounds), CGRectGetMidY(djButton.bounds)) fromView:djButton];
        BOOL disc = on ? wave && djHolder.layer.mask && !wave.userInteractionEnabled && hypot(wave.center.x - drawnDJ.x, wave.center.y - drawnDJ.y) < 1
                       : !wave && !djHolder.layer.mask;
        [seen addObject:[NSString stringWithFormat:@"DJ button: %@, %@", wave ? [NSString stringWithFormat:@"waveform %.0f pt from its middle",
                         hypot(wave.center.x - drawnDJ.x, wave.center.y - drawnDJ.y)] : @"no waveform", djHolder.layer.mask ? @"disc masked" : @"disc drawn"]];
        [self expect:ok && disc step:step detail:[seen componentsJoinedByString:@"; "]];
    };
    // Where a touch at the middle of what each of the AI DJ's four draws lands, with Spotify having given the share button and
    // its holder their alpha and touches back: Lyrics and Queue on the redesign's buttons, Connect and the DJ button on
    // Spotify's, and nothing of the share button drawn. VoiceOver still finds all four.
    void (^expectDJTouches)(NSString *) = ^(NSString *step) {
        UIView *shareHolder = djShare.superview;
        for (UIView *view in @[djShare, shareHolder]) {
            view.alpha = 1;
            view.userInteractionEnabled = YES;
        }
        UIWindow *window = djFooter.window;
        UIView *(^hitAt)(UIView *) = ^UIView *(UIView *view) {
            return [window hitTest:[window convertPoint:CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds)) fromView:view] withEvent:nil];
        };
        SGRGlyphButton *lyrics = titled(djFooter, @"Lyrics"), *queueButton = titled(djFooter, @"Queue");
        UIView *onLyrics = hitAt(lyrics), *onQueue = hitAt(queueButton), *onConnect = hitAt(djConnect), *onDJ = hitAt(djButton);
        BOOL lands = lyrics && queueButton && [onLyrics isDescendantOfView:lyrics] && [onQueue isDescendantOfView:queueButton]
                  && [onConnect isDescendantOfView:djConnectView] && [onDJ isDescendantOfView:djButton];
        CALayer *mask = shareHolder.layer.mask;
        BOOL away = mask && !mask.contents && CGRectIsEmpty(mask.bounds) && djShare.layer.mask;
        BOOL heard = lyrics.isAccessibilityElement && queueButton.isAccessibilityElement && djButton.isAccessibilityElement && !djButton.accessibilityElementsHidden
                  && [lyrics.accessibilityLabel isEqualToString:@"Lyrics"] && [queueButton.accessibilityLabel isEqualToString:@"Queue"];
        NSString *(^name)(UIView *) = ^NSString *(UIView *view) { return view.accessibilityIdentifier ?: view.accessibilityLabel ?: NSStringFromClass(view.class); };
        [self expect:lands && away && heard step:step
              detail:[NSString stringWithFormat:@"Lyrics on %@, Queue on %@, Connect on %@, the DJ button on %@; share %@; VoiceOver %@", name(onLyrics),
                      name(onQueue), name(onConnect), name(onDJ), away ? @"masked away" : @"DRAWN", heard ? @"finds all four" : @"MISSES ONE"]];
    };
    // A finger on the AI DJ's Queue, then on its Lyrics twice: the queue is asked for, and the lyrics open and close.
    __block BOOL lyricsBefore = NO;
    void (^tapDJ)(NSString *) = ^(NSString *title) {
        UIView *button = titled(djFooter, title);
        SGHarnessTap(djFooter.window, [djFooter.window convertPoint:CGPointMake(CGRectGetMidX(button.bounds), CGRectGetMidY(button.bounds)) fromView:button]);
    };

    // One step after another, each its delay after the one before it ran: every state a screenshot is asked for holds
    // two seconds or more, and a check reads a state the step before it set up once UIKit has laid it out.
    __block UIImage *device = nil;
    NSMutableArray<NSArray *> *script = [NSMutableArray array];
    void (^step)(NSTimeInterval, dispatch_block_t) = ^(NSTimeInterval delay, dispatch_block_t block) { [script addObject:@[@(delay), block]]; };
    step(2, ^{
        expectGlass(@"glass, as it stands", YES);
        expectIcons(@"Music app icons, as they stand", YES, spotifyConnect);
        expectGlyphs(@"the Music app's Lyrics, Queue and waveform, as they stand", YES);
        expectDJTouches(@"the AI DJ's four take their touches, the Music app's glyphs");
        NSLog(@"[harness] options: screenshot on now");
    });
    step(2.5, ^{
        SGRHarnessLastOpened = nil;
        tapDJ(@"Queue");
    });
    step(0.5, ^{
        [self expect:[SGRHarnessLastOpened.absoluteString isEqualToString:@"spotify:now-playing:queue"] step:@"the AI DJ's Queue tapped, the Music app's glyph"
              detail:SGRHarnessLastOpened.absoluteString ?: @"nothing opened"];
        open();
    });
    step(0.5, ^{
        BOOL flipped = flip(@"Header glass", NO) && flip(@"Music app icons", NO);
        [self expect:flipped && !SGEnabled(SGRKeyPlayerHeaderGlass) && !SGEnabled(SGRKeyPlayerMusicIcons) step:@"both switched off on the page"
              detail:[NSString stringWithFormat:@"switches %@", flipped ? @"flipped" : @"NOT FOUND"]];
    });
    step(0.5, ^{
        expectGlass(@"glass off, the page still up", NO);
        expectIcons(@"Music app icons off, the page still up", NO, spotifyConnect);
        expectGlyphs(@"Spotify's Lyrics and Queue glyphs and the DJ's disc, the page still up", NO);
        // Spotify draws another device's glyph while they are off: it stays Spotify's.
        device = [[UIImage systemImageNamed:@"hifispeaker.fill"] imageWithTintColor:UIColor.greenColor renderingMode:UIImageRenderingModeAlwaysOriginal];
        connect.image = device;
        close();
    });
    step(1, ^{
        expectIcons(@"a new device's glyph while off", NO, device);
        expectDJTouches(@"the AI DJ's four take their touches, Spotify's glyphs");
        NSLog(@"[harness] options: screenshot off now");
    });
    step(2.5, ^{
        SGRHarnessLastOpened = nil;
        tapDJ(@"Queue");
    });
    step(0.5, ^{
        [self expect:[SGRHarnessLastOpened.absoluteString isEqualToString:@"spotify:now-playing:queue"] step:@"the AI DJ's Queue tapped, Spotify's glyph"
              detail:SGRHarnessLastOpened.absoluteString ?: @"nothing opened"];
        lyricsBefore = SGRPlayerLyricsOpen();
        tapDJ(@"Lyrics");
    });
    step(0.5, ^{
        BOOL turned = SGRPlayerLyricsOpen() != lyricsBefore;
        tapDJ(@"Lyrics");
        [self expect:turned && titled(djFooter, @"Lyrics").enabled step:@"the AI DJ's Lyrics tapped, Spotify's glyph"
              detail:turned ? (lyricsBefore ? @"the lyrics closed" : @"the lyrics opened") : @"the lyrics did not turn"];
    });
    step(0.5, ^{
        [self expect:SGRPlayerLyricsOpen() == lyricsBefore && encoreIn(titled(djFooter, @"Lyrics")) step:@"tapped again, back as they were"
              detail:SGRPlayerLyricsOpen() ? @"open" : @"closed"];
        open();
    });
    step(0.5, ^{ flip(@"Header glass", YES); flip(@"Music app icons", YES); });
    step(0.5, ^{
        expectGlass(@"glass on again", YES);
        expectIcons(@"Music app icons on again", YES, device);
        expectGlyphs(@"the Music app's Lyrics, Queue and waveform on again", YES);
        NSLog(@"[harness] options: screenshot controls rows now");
    });
    step(2.5, ^{
        SGModRow *grain = rowTitled(@"Grain"), *style = rowTitled(@"Style");
        BOOL smooth = pathOf(grain) != nil;
        style.chosen(SGRFluidRendererLight);
        BOOL light = pathOf(grain) != nil;
        style.chosen(SGRFluidRendererSmooth);
        BOOL back = pathOf(grain) != nil;
        [self expect:grain && smooth && !light && back step:@"Grain shown only while Smooth draws"
              detail:[NSString stringWithFormat:@"Smooth %@, Light %@, Smooth again %@", smooth ? @"shown" : @"hidden", light ? @"shown" : @"hidden", back ? @"shown" : @"hidden"]];
    });
    step(1, ^{
        if (pathOf(rowTitled(@"Grain"))) [page().tableView scrollToRowAtIndexPath:pathOf(rowTitled(@"Grain")) atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
        NSLog(@"[harness] options: screenshot grain row now");
    });
    step(2.5, ^{
        close();
        // Held still, so every band read is one frame.
        SGRHarnessSetTrack(@"spotify:track:harnessA", imageURI(@"aaaa"), YES);
    });

    // What Spotify sets while the Music app's glyphs show is what comes back when they go, nil and all: Connect cleared, and
    // handed an image with no bitmap; the queue's two colors reset to nil; and a value Spotify set while they were out is
    // not overwritten by one recorded the time before.
    void (^icons)(BOOL) = ^(BOOL on) {
        SGSetEnabled(SGRKeyPlayerMusicIcons, on);
        SGRPlayerLookChanged();
    };
    UIImage *unbacked = [UIImage imageWithCIImage:[[CIImage imageWithColor:[CIColor colorWithRed:0 green:1 blue:0]] imageByCroppingToRect:CGRectMake(0, 0, 19, 19)]];
    NSString *(^iconState)(void) = ^NSString *{
        return [NSString stringWithFormat:@"Connect: stand-in %@, image %@; queue: stand-in %@, colors %@ / %@", standInIn(connect) ? @"in" : @"out",
                connect.image == unbacked ? @"the one with no bitmap" : connect.image ? (connect.image.CGImage ? @"a bitmap" : @"another") : @"nil",
                standInIn(queue) ? @"in" : @"out", queue.foregroundColor ?: @"nil", queue.activeForegroundColor ?: @"nil"];
    };
    step(0.5, ^{
        connect.image = nil;
        queue.foregroundColor = nil;
        queue.activeForegroundColor = nil;
        icons(NO);
    });
    step(0.5, ^{
        [self expect:!standInIn(connect) && !connect.image && !standInIn(queue) && !queue.foregroundColor && !queue.activeForegroundColor
                step:@"Connect cleared and the queue's colors reset while the glyphs showed, given back as nil" detail:iconState()];
        queue.foregroundColor = UIColor.whiteColor;
        icons(YES);
    });
    step(0.5, ^{
        [self expect:standInIn(connect) && standInIn(queue) && [queue.foregroundColor isEqual:UIColor.clearColor] step:@"the glyphs back over a cleared Connect"
              detail:iconState()];
        connect.image = unbacked;
        icons(NO);
    });
    step(0.5, ^{
        [self expect:!standInIn(connect) && connect.image == unbacked && [queue.foregroundColor isEqual:UIColor.whiteColor] && !queue.activeForegroundColor
                step:@"an image with no bitmap given back as Spotify set it" detail:iconState()];
        connect.image = nil;
        queue.foregroundColor = nil;
        icons(YES);
    });
    step(0.5, ^{ icons(NO); });
    step(0.5, ^{
        [self expect:!connect.image && !queue.foregroundColor && !queue.activeForegroundColor
                step:@"what Spotify set while they were out, not the record before" detail:iconState()];
        icons(YES);
    });

    // Each Grain set as the slider sets it, then the field read a second later. Light at 100 is the read a second after the
    // switch from Smooth, compared with the two read after it (the switch on its own: the `renderer` scenario).
    NSMutableDictionary<NSString *, NSNumber *> *grains = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSData *> *bands = [NSMutableDictionary dictionary];
    __block CFTimeInterval setAt = 0;
    NSArray<NSArray *> *grainSteps = @[@[@"Smooth", @0], @[@"Smooth", @100], @[@"Smooth", @200], @[@"Light", @100], @[@"Light", @0], @[@"Light", @200]];
    [grainSteps enumerateObjectsUsingBlock:^(NSArray *values, NSUInteger i, BOOL *stop) {
        NSString *renderer = values[0], *name = [NSString stringWithFormat:@"%@ %@", values[0], values[1]];
        step(i ? 2 : 1, ^{
            setAt = CACurrentMediaTime();
            SGRSetFluidRenderer([renderer isEqualToString:@"Smooth"] ? SGRFluidRendererSmooth : SGRFluidRendererLight);
            SGRSetFluidValue(SGRFluidGrain, [values[1] integerValue]);
        });
        step(1, ^{
            UIView *field = (UIView *)SGRPlayerField();
            CALayer *fluid = fluidLayerIn(field.layer);
            BOOL gpu = [[fluid valueForKey:@"_gpuShown"] boolValue];
            NSData *band = fieldBand(field);
            bands[name] = band;
            grains[name] = @(grainIn(band, round(field.bounds.size.width)));
            NSLog(@"[harness] options: %@ grain %.2f s after it was set, the Smooth renderer %@ (%lu Metal layers in the field) -- %.3f steps; screenshot %@ now",
                  name, CACurrentMediaTime() - setAt, gpu ? @"showing" : @"not showing", (unsigned long)metalLayersIn(field.layer), grains[name].doubleValue, name);
            if ([renderer isEqualToString:@"Smooth"] != gpu) {
                [self expect:NO step:[name stringByAppendingString:@" drawn by its renderer"] detail:gpu ? @"Smooth showing" : @"Smooth not showing"];
            }
        });
    }];
    step(1, ^{
        double s0 = grains[@"Smooth 0"].doubleValue, s100 = grains[@"Smooth 100"].doubleValue, s200 = grains[@"Smooth 200"].doubleValue;
        [self expect:s0 < s100 && s100 + 0.5 < s200 step:@"Smooth: none at 0, the dither at 100, a visible grain at 200"
              detail:[NSString stringWithFormat:@"%.3f, %.3f, %.3f steps", s0, s100, s200]];
        [self expect:[bands[@"Light 0"] isEqualToData:bands[@"Light 200"]] step:@"Light: the same at 0 and 200"
              detail:[NSString stringWithFormat:@"%.3f and %.3f steps", grains[@"Light 0"].doubleValue, grains[@"Light 200"].doubleValue]];
        [self expect:[bands[@"Light 100"] isEqualToData:bands[@"Light 0"]] step:@"Light a second after the switch from Smooth, as it settles"
              detail:[NSString stringWithFormat:@"%.3f steps from the settled band", bandDiff(bands[@"Light 100"], bands[@"Light 0"])]];
        NSLog(@"[harness] options checks: %lu of %lu right -- %@", (unsigned long)(self->_checks - self->_failures), (unsigned long)self->_checks,
              self->_failures ? @"FAIL" : @"PASS");
        exit(self->_failures ? 1 : 0);
    });
    runScript(script, 0);
}

- (void)runLook {
    UIImage *second = secondArtwork();
    // Issue #54: the footer row moved down past the bottom stack's bounds must still take its touches,
    // at the bottom edge of each glyph as well as the middle.
    after(3, ^{
        CGFloat bottom = 0;
        for (NSString *symbol in @[@"list.bullet", @"airpods.pro"]) {
            __block UIView *found = nil;
            NSMutableArray *queue = [NSMutableArray arrayWithObject:self.window];
            while (queue.count && !found) {
                UIView *v = queue.firstObject;
                [queue removeObjectAtIndex:0];
                if ([v isKindOfClass:UIImageView.class] && [((UIImageView *)v).image isEqual:[UIImage systemImageNamed:symbol]]) found = v;
                [queue addObjectsFromArray:v.subviews];
            }
            CGRect drawn = [found convertRect:found.bounds toView:self.window];
            bottom = CGRectGetMaxY(drawn);
            for (NSNumber *dy in @[@0, @8]) {
                CGPoint at = CGPointMake(CGRectGetMidX(drawn), CGRectGetMidY(drawn) + dy.doubleValue);
                UIView *hit = [self.window hitTest:at withEvent:nil];
                BOOL inRow = NO;
                for (UIView *v = hit; v; v = v.superview) inRow = inRow || [NSStringFromClass(unitOf(v).class) containsString:@"FooterElementsUnit"] || [v.accessibilityIdentifier isEqualToString:@"QueueButtonNowPlaying"];
                NSLog(@"[harness] touch on %@ at y %.0f (+%.0f): %@ -- %@", symbol, at.y, dy.doubleValue, NSStringFromClass(hit.class), inRow ? @"the footer's" : @"MISSED");
            }
        }
        NSLog(@"[harness] footer glyphs end at %.0f of %.0f", bottom, self.window.bounds.size.height);
    });
    after(8, ^{
        serve(imageURI(@"ffff"), second, 0.25, NO);
        [self playTrack:@"spotify:track:harnessF" image:imageURI(@"ffff")];
    });
    after(8.4, ^{ [self showOnScreen:second]; });
}

@end

// Before every %ctor, so the redesign's gate reads on, and every session gets the picture server.
__attribute__((constructor(101))) static void sgr_harnessDefaults(void) {
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"spotifyglass.redesign"];
    // Animated artwork, its clip served by the picture server to the shared session too.
    if ([scenario() isEqualToString:@"visualiser"]) [NSUserDefaults.standardUserDefaults setInteger:4 forKey:@"spotifyglass.redesign.player.background"];
    // Still at launch, so the player looks up no clip; an address of this run's own, so the store has none of it yet.
    if ([scenario() isEqualToString:@"preview"]) {
        [NSUserDefaults.standardUserDefaults setInteger:0 forKey:@"spotifyglass.redesign.player.background"];
        setenv("HARNESS_CANVAS", [NSString stringWithFormat:@"https://canvas.harness/preview-%d.mp4", getpid()].UTF8String, 1);
        setenv("HARNESS_CANVAS_DELAY", "2", 1);
        [NSURLProtocol registerClass:SGRHarnessPictureServer.class];
    }
    // card: HARNESS_BACKGROUND (an index, Fluid if unset), and with HARNESS_LAST=1 a last track played whose cover is
    // the picture server's first picture; without it, no track ever played.
    if ([scenario() isEqualToString:@"card"]) {
        NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
        const char *background = getenv("HARNESS_BACKGROUND");
        [store setInteger:background ? atoi(background) : 2 forKey:@"spotifyglass.redesign.player.background"];
        if (getenv("HARNESS_LAST")) {
            [store setObject:@{@"uri": @"spotify:track:last", @"title": @"Holocene, the Long Version Recorded Live at the Old Church",
                               @"artist": @"Bon Iver", @"artwork": [@"https://i.scdn.co/image/" stringByAppendingString:[imageURI(@"aaaa") substringFromIndex:14]],
                               @"canvas": [NSString stringWithFormat:@"https://canvas.harness/last-%d.mp4", getpid()]}
                      forKey:@"spotifyglass.lastTrack"];
        } else {
            [store removeObjectForKey:@"spotifyglass.lastTrack"];
        }
        [NSURLProtocol registerClass:SGRHarnessPictureServer.class];
    }
    // options: Fluid drawn Smooth, the look switches and Grain at their standard (the app's defaults outlive a run).
    if ([scenario() isEqualToString:@"options"] || [scenario() isEqualToString:@"renderer"]) {
        NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
        [store setInteger:SGRPlayerBackgroundFluid forKey:@"spotifyglass.redesign.player.background"];
        [store setInteger:SGRFluidRendererSmooth forKey:@"spotifyglass.redesign.fluid.renderer"];
        for (NSString *key in @[SGRKeyPlayerHeaderGlass, SGRKeyPlayerMusicIcons, @"spotifyglass.redesign.fluid.grain"]) [store removeObjectForKey:key];
    }
    // controls: shuffle and repeat both hidden, read at launch (runSpreadChecks), and taken off again before it exits.
    if ([scenario() isEqualToString:@"controls"]) {
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:SGRKeyPlayerHideShuffle];
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:SGRKeyPlayerHideRepeat];
    }
    // The shared session the catalog asks with.
    if ([scenario() isEqualToString:@"catalog"]) [NSURLProtocol registerClass:SGRHarnessPictureServer.class];
    // automix: Fluid behind the player, AutoMix and its three player options at their standard (all off) until the
    // scenario turns them on, so it starts from what a user who never opened the page has.
    if ([scenario() isEqualToString:@"automix"]) {
        NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
        [store setInteger:SGRPlayerBackgroundFluid forKey:@"spotifyglass.redesign.player.background"];
        for (NSString *key in @[@"spotifyglass.automix", @"spotifyglass.automix.style", @"spotifyglass.automix.show-progress",
                                @"spotifyglass.automix.show-queue", @"spotifyglass.automix.artwork"]) [store removeObjectForKey:key];
        [NSURLProtocol registerClass:SGRHarnessPictureServer.class];
    }
    // still: Animated with the full-screen cover off, and no Canvas until the scenario names one.
    if ([scenario() isEqualToString:@"still"]) {
        [NSUserDefaults.standardUserDefaults setInteger:SGRPlayerBackgroundAnimated forKey:@"spotifyglass.redesign.player.background"];
        [NSUserDefaults.standardUserDefaults setInteger:SGRPlayerBackgroundAnimated forKey:SGRKeyPlayerArtworkBackground];
        [NSUserDefaults.standardUserDefaults removeObjectForKey:SGRKeyPlayerAnimatedStill];
        unsetenv("HARNESS_CANVAS");
        [NSURLProtocol registerClass:SGRHarnessPictureServer.class];
    }
    // autoviz: Animated with the Visualizer-without-a-clip switch off, no Canvas until the scenario names one, every
    // lookup 1.5 s late. shuffle and heat: the Visualizer as the background (shuffle moves to Animated at the end),
    // their switches off, the style at its default.
    if ([scenario() isEqualToString:@"autoviz"] || [scenario() isEqualToString:@"shuffle"] || [scenario() isEqualToString:@"heat"]) {
        NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
        BOOL animated = [scenario() isEqualToString:@"autoviz"];
        SGRPlayerBackgroundKind kind = animated ? SGRPlayerBackgroundAnimated : SGRPlayerBackgroundVisualiser;
        [store setInteger:kind forKey:@"spotifyglass.redesign.player.background"];
        [store setInteger:kind forKey:SGRKeyPlayerArtworkBackground];
        for (NSString *key in @[SGRKeyPlayerAnimatedStill, SGRKeyPlayerAnimatedVisualiser, SGRKeyVisualiserShuffle, SGRKeyVisualiserShuffleHome,
                                SGRKeyVisualiserIgnoreHeat, SGRKeyVisualiserStyle]) [store removeObjectForKey:key];
        unsetenv("HARNESS_CANVAS");
        if (animated) SGRHarnessSetLookupDelay(1.5);
        [NSURLProtocol registerClass:SGRHarnessPictureServer.class];
    }
    // settings: Animated, Song without a clip, the Buttons chips and the look switches at their standard (the app's defaults
    // outlive a run).
    if ([scenario() isEqualToString:@"settings"]) {
        NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
        [store setInteger:SGRPlayerBackgroundAnimated forKey:SGRKeyPlayerArtworkBackground];
        for (NSString *key in @[SGRKeyPlayerAnimatedStill, SGRKeyPlayerAnimatedVisualiser, SGRKeyPlayerHideShuffle, SGRKeyPlayerHideRepeat,
                                SGKeyHideVideoSwitch, SGRKeyPlayerHeaderGlass, SGRKeyPlayerStarAdd]) [store removeObjectForKey:key];
    }
    if ([scenario() isEqualToString:@"motion"] || [scenario() isEqualToString:@"settings"]) {
        [NSUserDefaults.standardUserDefaults setInteger:3 forKey:@"spotifyglass.redesign.player.background"];
        setenv("HARNESS_CANVAS", "https://canvas.harness/clip.mp4", 1);
        [NSURLProtocol registerClass:SGRHarnessPictureServer.class];
    }
    Method original = class_getClassMethod(NSURLSessionConfiguration.class, @selector(defaultSessionConfiguration));
    Method harness = class_getClassMethod(NSURLSessionConfiguration.class, @selector(sgr_harnessDefault));
    method_exchangeImplementations(original, harness);
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(SGRHarnessDelegate.class));
    }
}
