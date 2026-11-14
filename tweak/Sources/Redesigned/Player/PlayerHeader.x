// Player redesign: glass circles behind the header's close and more buttons, and the Music app's grabber over them.
//
// Glass is the control layer floating over the field, so it goes behind the round buttons only: the
// playlist name between them stays a label, and the row of playback controls stays bare glyphs
// (PlayerControls.x). Each circle is a subview of the button it sits behind (SGRGlassInside), below
// what the button draws and taking no touches, so the buttons stay Spotify's, with their actions, state
// and accessibility, and the circle follows the button wherever Spotify's row puts it. Circles placed
// from the unit's layout pass instead (a backing across the unit's view) were read before the row had
// laid the buttons out and sat 24pt up and to the side until a tap laid the unit out again
// (trees/continuous/1.txt, 2026-09-17: shapes at {-10, -22} and {320, -22}; the close button is at {12, 0}
// in the unit's view, so its circle belonged at {14, 2}).
//
// The add button keeps no circle: its glyph is a circle of its own, green and filled once the track is
// saved, and on glass it read as a disc on a disc (device test, 2026-09-17).
//
// The circles can be switched off on the Player page (SGRKeyPlayerHeaderGlass), which the open player follows at
// once: only the circles go, and each button draws as Spotify's own again. The arrow then shows Spotify's own press;
// the ⋯, whose touches the mod's button over it takes (ContextMenu.x), shows none.
//
// Tree (trees/clean/player/01.txt): HeaderElementsUnit's view is a 402x48 row holding
// id=now-playing-minimize-button 48x48 (:103) and id=Context menu 48x48 (:122), the playlist name
// between them. The down arrow and the ⋯ are a pair, as the Music app's are: the same circle, size and glass.
// 9.1.78 also carries mobile-nowplaying-close-button (strings in the binary), so the down arrow is looked for
// under either name; which view each circle went into is logged once, so a phone where the arrow has none
// says why.
//
// The circle presses in itself (scale, the Kit's press spring), from the control that takes the touches: the
// arrow's own, and for the ⋯ the mod's button over it (ContextMenu.x). Spotify draws a button's pressed look
// under its subviews, where the circle covers it (phone, 2026-10-06: the arrow closed the player but showed
// no ripple), and the ⋯'s touches no longer reach Spotify's button at all.
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Redesigned/ContextMenu/ContextMenu.h"
#import "Player.h"

static char kGlassKey, kCloseKey, kMoreKey, kPressKey, kGrabberKey;
static char kContextKey, kContextStateKey;
static const CGFloat kPressScale = 0.92;

static void contextVisibility(UIView *header) {
    // The recorded title container carries the accessibility label as well as the nested marquee.
    // Alpha preserves its stack slot; hidden would change Spotify's stack layout.
    UIView *context = SGRFindByIdentifier(header, @"now-playing-navigation-unit-title-label", &kContextKey);
    if (!context) return;
    NSArray<NSNumber *> *saved = objc_getAssociatedObject(context, &kContextStateKey);
    if (SGHidden(SGRKeyPlayerHideContext)) {
        if (!saved) {
            saved = @[@(context.alpha), @(context.isAccessibilityElement), @(context.accessibilityElementsHidden)];
            objc_setAssociatedObject(context, &kContextStateKey, saved, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        context.alpha = 0;
        context.isAccessibilityElement = NO;
        context.accessibilityElementsHidden = YES;
    } else if (saved) {
        context.alpha = saved[0].doubleValue;
        context.isAccessibilityElement = saved[1].boolValue;
        context.accessibilityElementsHidden = saved[2].boolValue;
        objc_setAssociatedObject(context, &kContextStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

@interface SGRHeaderPress : NSObject
@end
@implementation SGRHeaderPress
// The circle of the control pressed, or of the button under it (the ⋯'s front).
static UIView *circleOf(UIControl *control) {
    return objc_getAssociatedObject(control, &kGlassKey) ?: objc_getAssociatedObject(control.superview, &kGlassKey);
}
- (void)down:(UIControl *)control {
    UIView *circle = circleOf(control);
    SGRAnimate(SGRMotionPress, ^{ circle.transform = CGAffineTransformMakeScale(kPressScale, kPressScale); }, nil);
}
- (void)up:(UIControl *)control {
    UIView *circle = circleOf(control);
    SGRAnimate(SGRMotionPress, ^{ circle.transform = CGAffineTransformIdentity; }, nil);
}
@end

// `throughMenu`: the mod's ⋯, whose touch UIKit cancels as the menu comes up on it; the press holds until the
// menu ends, which the button reports as a touch up outside (ContextMenu.x), so its cancel is not listened to.
static void pressFrom(UIControl *control, BOOL throughMenu) {
    if (![control isKindOfClass:UIControl.class] || objc_getAssociatedObject(control, &kPressKey)) return;
    objc_setAssociatedObject(control, &kPressKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    static SGRHeaderPress *press;
    if (!press) press = [SGRHeaderPress new];
    [control addTarget:press action:@selector(down:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
    UIControlEvents up = UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchDragExit;
    [control addTarget:press action:@selector(up:) forControlEvents:throughMenu ? up : up | UIControlEventTouchCancel];
}

// The button's circle, taken out while the header glass is switched off (SGRKeyPlayerHeaderGlass); the next pass with
// it on makes a new one. Only the circle goes: the button, its press watcher and the ⋯'s handover stay.
static void dropCircle(UIView *button) {
    UIView *circle = objc_getAssociatedObject(button, &kGlassKey);
    if (!circle) return;
    [circle removeFromSuperview];
    objc_setAssociatedObject(button, &kGlassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// `identifiers` holds, for each button, the identifiers it may carry, the first found winning. `watchMenu`: the ⋯ is
// handed to PlayerMenu.m, which takes it for the ordinary player's; the AI DJ's ⋯ keeps Spotify's own menu.
static void glassInside(UIViewController *unit, NSArray<NSArray<NSString *> *> *identifiers, const void **findKeys, BOOL watchMenu) {
    UIView *host = unit.viewIfLoaded;
    if (!host) return;
    BOOL glass = SGEnabled(SGRKeyPlayerHeaderGlass);
    NSUInteger found = 0;
    for (NSUInteger i = 0; i < identifiers.count; i++) {
        UIView *button = nil;
        for (NSString *identifier in identifiers[i]) {
            if ((button = SGRFindByIdentifier(host, identifier, findKeys[i]))) break;
        }
        NSString *name = identifiers[i].firstObject;
        static NSMutableSet<NSString *> *said;
        if (!said) said = [NSMutableSet set];
        if (!button) {
            if (![said containsObject:name]) {
                [said addObject:name];
                SGLog(@"redesign player: %@ not found in %@, left as Spotify's", [identifiers[i] componentsJoinedByString:@" or "], NSStringFromClass(host.class));
            }
            continue;
        }
        UIView *circle = glass ? SGRGlassInside(button, &kGlassKey, SGRGlassCircleSize) : nil;
        if (!glass) dropCircle(button);
        if (![said containsObject:name] && button.bounds.size.width > 0) {
            [said addObject:name];
            SGLog(@"redesign player: %@ in %@ (id %@, %.0fx%.0f, %@)", circle ? [NSString stringWithFormat:@"a %.0fpt glass circle", circle.bounds.size.width] : @"no glass circle, switched off", NSStringFromClass(button.class),
                  button.accessibilityIdentifier, button.bounds.size.width, button.bounds.size.height,
                  button.hidden || button.alpha < 0.01 ? @"hidden" : @"shown");
        }
        if (watchMenu && [name isEqualToString:@"Context menu"]) {
            SGRPlayerMenuWatch(button);
        }
        UIControl *front = SGRSystemMenuFront(button);
        pressFrom(front ?: (UIControl *)button, front != nil);
        found++;
    }

    static NSMutableSet<NSString *> *logged;
    if (!logged) logged = [NSMutableSet set];
    NSString *unitName = NSStringFromClass(unit.class);
    if (![logged containsObject:unitName]) {
        [logged addObject:unitName];
        SGLog(@"redesign player: glass inside %lu of %lu buttons in %@", (unsigned long)found, (unsigned long)identifiers.count, unitName);
    }
}

#pragma mark - the grabber

// The Music app's grabber over its full screen player: a pill centered over the header row, taking no touches and
// read by nothing, the player's own close being the down arrow and the swipe down. It is a subview of the header
// unit's view, so it fades with the row while the lyrics have the player to themselves (PlayerLyrics.x fades that
// view by its alpha) and comes back with it. The view does not clip, so the pill may sit over the row's top.
//
// Where: under the safe area's top when the row leaves room for it there; else, under an island or a notch (a
// safe area top of 44pt or more, the cutout ending well above it), in the strip between the cutout and the row;
// else (a status bar of 20pt, nothing below it to sit in) just inside the row's top, over the middle where the
// playlist's name leaves a gap above itself.
static const CGSize kGrabberSize = {36, 5};
static const CGFloat kGrabberGap = 4;
static const CGFloat kCutoutSafeTop = 44;

static void placeGrabber(UIView *header) {
    UIWindow *window = header.window;
    if (!window) return;
    UIView *grabber = objc_getAssociatedObject(header, &kGrabberKey);
    if (!grabber) {
        grabber = [UIView new];
        grabber.userInteractionEnabled = NO;
        grabber.isAccessibilityElement = NO;
        grabber.accessibilityElementsHidden = YES;
        grabber.layer.cornerRadius = kGrabberSize.height / 2;
        grabber.layer.cornerCurve = kCACornerCurveContinuous;
        objc_setAssociatedObject(header, &kGrabberKey, grabber, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    grabber.backgroundColor = [UIColor colorWithWhite:1 alpha:SGRIncreaseContrast() ? 0.5 : 0.3];
    if (grabber.superview != header) [header addSubview:grabber];

    // Measured in the player's own full screen view (SPTNowPlayingView), whose top is the screen's once the player
    // is up: the window's coordinates would take in the player's open and close as it moves.
    UIView *player = window;
    for (UIView *v = header.superview; v && v != window; v = v.superview) {
        if (v.bounds.size.height >= window.bounds.size.height - 1) {
            player = v;
            break;
        }
    }
    CGFloat safeTop = player.safeAreaInsets.top;
    CGFloat rowTop = [header convertPoint:CGPointZero toView:player].y;
    CGFloat top;   // in the player
    if (rowTop - safeTop >= kGrabberSize.height + 2 * kGrabberGap) top = safeTop + kGrabberGap;
    else if (safeTop >= kCutoutSafeTop) top = rowTop - kGrabberSize.height - kGrabberGap;
    else top = rowTop + kGrabberGap / 2;
    CGFloat y = [header convertPoint:CGPointMake(0, top) fromView:player].y;
    CGRect frame = CGRectMake(round(CGRectGetMidX(header.bounds) - kGrabberSize.width / 2), round(y), kGrabberSize.width, kGrabberSize.height);
    if (!CGRectEqualToRect(grabber.frame, frame)) grabber.frame = frame;

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGLog(@"redesign player: grabber at %.0f in %@ (safe top %.0f, header row at %.0f)", top, NSStringFromClass(player.class), safeTop, rowTop);
    });
}

static void glassHeader(UIViewController *unit, BOOL watchMenu) {
    static const void *keys[] = {&kCloseKey, &kMoreKey};
    glassInside(unit, @[@[@"now-playing-minimize-button", @"mobile-nowplaying-close-button"], @[@"Context menu"]], keys, watchMenu);
    UIView *header = unit.viewIfLoaded;
    if (!header) return;
    contextVisibility(header);
    placeGrabber(header);
    SGRPlayerWatchLook(header);
}

%hook _TtC20NowPlaying_ModesImpl18HeaderElementsUnit
- (void)viewDidLayoutSubviews {
    %orig;
    glassHeader((UIViewController *)self, YES);
}
%end

// The AI DJ's player has a header unit of its own with the same two buttons, which the circles never reached.
// Its ⋯ gets the glass but is not watched: the menu it opens (feedback, language, voice) is not the player's.
%group SGRDJHeaderHooks
%hook SGRDJHeaderUnit
- (void)viewDidLayoutSubviews {
    %orig;
    glassHeader((UIViewController *)self, NO);
}
%end
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    Class djHeader = SGRDJClass(@"DJMHeaderElementsUnitViewController");
    if (djHeader) { %init(SGRDJHeaderHooks, SGRDJHeaderUnit = djHeader); }
    SGRequireClasses(@[@"_TtC20NowPlaying_ModesImpl18HeaderElementsUnit"]);
}
