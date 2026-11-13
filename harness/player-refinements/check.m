// The player refinements of Redesigned/Kit/SGRRefinements.h, as a Mac Catalyst app; no simulator.
//
// Rolling time digits: the rules (SGRRefinements.m) and the real roll (SGRRollingDigits.m over SGRRestyle.m's monospaced
// label) on a label in a window: which characters roll, a change within 150 ms of the last shown at once, a label that
// moved into a window shown at once, the first value counted as a change, a right-to-left or mixed text shown at once,
// Reduce Motion a crossfade with no travel, the label's text and accessibility Spotify's. Star add button and Plain
// checkmark: the mapping and SGRPlainCheck.x through Logos on a player's and a row's add button, enabled and disabled.
//
// The launch arguments are the settings, read at launch as on the phone: `both` has Plain checkmark and Star add
// button on, `plain` Plain checkmark alone. Reduce Motion and the accent are test
// doubles (the system's setting cannot be set from here); everything else is the tweak's own code.
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "Redesigned/Kit/SGRRefinements.h"
#import "Redesigned/Kit/SGRAccent.h"
#import "Redesigned/Kit/SGRRestyle.h"
#import "Redesigned/Kit/SGRTokens.h"
#import "../harness-fail.h"

static NSUInteger sg_checks;
static BOOL sg_reduceMotion;
static NSString *sg_mode;

#define CHECK(condition, ...) do { sg_checks++; if (!(condition)) HARNESS_FAIL(__VA_ARGS__); } while (0)

#pragma mark - test doubles for the Kit around the code under test

BOOL SGRedesignedUI(void) { return YES; }
BOOL SGRReduceMotion(void) { return sg_reduceMotion; }
void SGRAnimate(SGRMotion motion, void (^animations)(void), void (^completion)(BOOL finished)) {
    [UIView animateWithDuration:SGRCrossfade animations:animations completion:completion];
}
const NSTimeInterval SGRCrossfade = 0.35;
const CGFloat SGRRadiusArtwork = 12;
UIColor *SGRPrimary(void) { return UIColor.whiteColor; }
UIColor *SGRSecondary(void) { return [UIColor colorWithWhite:1 alpha:0.65]; }
// The redesign's own green, in place of Spotify's.
UIColor *SGRAccent(void) { return [UIColor colorWithRed:0x37 / 255.0 green:0xF2 / 255.0 blue:0 alpha:1]; }
UIFont *SGMonospacedDigitsFont(UIFont *font) { return [UIFont monospacedDigitSystemFontOfSize:font.pointSize weight:UIFontWeightRegular]; }

#pragma mark - mocks of Spotify's classes

@interface _TtC20NowPlaying_ModesImpl23InformationElementsUnit : UIViewController @end
@implementation _TtC20NowPlaying_ModesImpl23InformationElementsUnit @end

static void settle(NSTimeInterval seconds) {
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

#pragma mark - rolling time digits: the rules

static void checkDigitRules(void) {
    struct { NSString *before, *after; NSArray<NSNumber *> *rolled; } cases[] = {
        {@"1:09", @"1:10", @[@2, @3]},
        {@"1:10", @"1:11", @[@3]},
        {@"0:59", @"1:00", @[@0, @2, @3]},
        {@"9:59", @"10:00", @[@0, @1, @2, @3, @4]},
        {@"-3:21", @"-3:20", @[@4]},
        {@"-10:00", @"-9:59", @[@0, @1, @2, @3, @4]},
        {@"2:00", @"2:00", @[]},
    };
    for (size_t i = 0; i < sizeof cases / sizeof *cases; i++) {
        NSMutableArray<NSNumber *> *got = [NSMutableArray array];
        [SGRDigitsRolled(cases[i].before, cases[i].after) enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) { [got addObject:@(index)]; }];
        CHECK([got isEqualToArray:cases[i].rolled], @"%@ -> %@ rolls %@, want %@", cases[i].before, cases[i].after, got, cases[i].rolled);
    }

    struct { NSString *before, *after; BOOL attached; NSTimeInterval since; BOOL reduce; SGRDigitsChange want; NSString *what; } rules[] = {
        {@"1:09", @"1:09", YES, 1, NO, SGRDigitsChangeNone, @"unchanged"},
        {@"", @"0:00", YES, -1, NO, SGRDigitsChangeJump, @"first value"},
        {@"1:09", @"1:10", NO, 1, NO, SGRDigitsChangeJump, @"just attached"},
        {@"1:09", @"2:45", YES, 0.016, NO, SGRDigitsChangeJump, @"a scrub's frame"},
        {@"1:09", @"1:10", YES, 0.149, NO, SGRDigitsChangeJump, @"149 ms after the last"},
        {@"1:09", @"1:10", YES, 0.15, NO, SGRDigitsChangeRoll, @"150 ms after the last"},
        {@"1:09", @"1:10", YES, 1, NO, SGRDigitsChangeRoll, @"a second's tick"},
        {@"1:09", @"1:10", YES, -1, NO, SGRDigitsChangeRoll, @"no change before"},
        {@"1:09", @"1:10", YES, 1, YES, SGRDigitsChangeFade, @"Reduce Motion"},
        {@"1:09", @"1:10", YES, 0.05, YES, SGRDigitsChangeJump, @"Reduce Motion, a scrub"},
    };
    for (size_t i = 0; i < sizeof rules / sizeof *rules; i++) {
        SGRDigitsChange got = SGRDigitsChangeFor(rules[i].before, rules[i].after, rules[i].attached, rules[i].since, rules[i].reduce);
        CHECK(got == rules[i].want, @"rule %@: got %ld, want %ld", rules[i].what, (long)got, (long)rules[i].want);
    }
}

#pragma mark - rolling time digits: the label

// The overlay SGRRollingDigits.m lays over the label, nil when none.
static UIView *overlayOver(UILabel *label) {
    NSArray<UIView *> *siblings = label.superview.subviews;
    NSUInteger index = [siblings indexOfObject:label];
    return index + 1 < siblings.count ? siblings[index + 1] : nil;
}

// The characters coming in (those ending visible) and going out.
static void glyphsOf(UIView *overlay, NSMutableString *incoming, NSMutableString *outgoing) {
    for (UILabel *glyph in overlay.subviews) [(glyph.alpha > 0.5 ? incoming : outgoing) appendString:glyph.text];
}

// The label says what Spotify set, and accessibility reads it as from a label of UIKit's own given the same text.
static void expectSpotifysText(UILabel *label, NSString *text, NSString *what) {
    UILabel *reference = [UILabel new];
    reference.text = text;
    BOOL same = [label.text isEqualToString:text]
        && (label.accessibilityLabel == reference.accessibilityLabel || [label.accessibilityLabel isEqualToString:reference.accessibilityLabel])
        && (label.accessibilityValue == reference.accessibilityValue || [label.accessibilityValue isEqualToString:reference.accessibilityValue])
        && label.isAccessibilityElement == reference.isAccessibilityElement;
    CHECK(same, @"%@: the label says \"%@\", accessibility \"%@\" / \"%@\", want \"%@\"", what, label.text, label.accessibilityLabel,
          label.accessibilityValue, text);
}

static void expectRoll(UILabel *label, NSString *text, NSString *wantIn, NSString *wantOut, BOOL travels, NSString *what) {
    label.text = text;
    UIView *overlay = overlayOver(label);
    CHECK(overlay != nil, @"%@: nothing rolls", what);
    CHECK(label.layer.mask != nil, @"%@: the label's changed columns are not masked", what);
    CHECK(overlay.accessibilityElementsHidden && !overlay.isAccessibilityElement && !overlay.userInteractionEnabled,
          @"%@: the overlay is reachable", what);
    NSMutableString *incoming = [NSMutableString string], *outgoing = [NSMutableString string];
    glyphsOf(overlay, incoming, outgoing);
    CHECK([incoming isEqualToString:wantIn], @"%@: rolls in \"%@\", want \"%@\"", what, incoming, wantIn);
    CHECK([outgoing isEqualToString:wantOut], @"%@: rolls out \"%@\", want \"%@\"", what, outgoing, wantOut);
    for (UILabel *glyph in overlay.subviews) {
        BOOL moving = [glyph.layer animationForKey:@"transform"] != nil;
        CHECK(moving == travels, @"%@: \"%@\" %@", what, glyph.text, travels ? @"does not travel" : @"travels under Reduce Motion");
        CHECK([glyph.layer animationForKey:@"opacity"] != nil, @"%@: \"%@\" does not fade", what, glyph.text);
    }
    expectSpotifysText(label, text, what);
}

static void expectJump(UILabel *label, NSString *text, NSString *what) {
    label.text = text;
    CHECK(overlayOver(label) == nil, @"%@: rolled", what);
    CHECK(label.layer.mask == nil, @"%@: the label is still masked", what);
    expectSpotifysText(label, text, what);
}

static void checkRollingLabel(UIWindow *window) {
    UIView *host = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 200, 40)];
    [window addSubview:host];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 80, 20)];
    label.font = [UIFont systemFontOfSize:12];
    label.accessibilityIdentifier = @"now-playing-time-take-label-internal";
    [host addSubview:label];
    SGRRollDigits(label);
    CHECK(SGRRollingDigitsWatched(label), @"the label is not watched");

    expectJump(label, @"1:30", @"the first value");
    expectJump(label, @"0:00", @"a scrub right after the first value");
    settle(0.2);
    expectRoll(label, @"0:01", @"1", @"0", YES, @"0:00 -> 0:01");
    expectJump(label, @"1:45", @"a seek 20 ms later");
    expectJump(label, @"1:46", @"the scrub's next frame");
    settle(0.2);
    expectRoll(label, @"1:47", @"7", @"6", YES, @"1:46 -> 1:47");
    settle(0.2);
    expectRoll(label, @"1:50", @"50", @"47", YES, @"1:47 -> 1:50");
    settle(0.2);
    // The roll before is still running: it is finished first, and this one stands alone.
    expectRoll(label, @"1:59", @"9", @"0", YES, @"1:50 -> 1:59");
    settle(0.2);
    expectRoll(label, @"2:00", @"200", @"159", YES, @"1:59 -> 2:00");
    settle(0.2);
    expectRoll(label, @"10:00", @"10:00", @"2:00", YES, @"2:00 -> 10:00 (length changes)");
    // The same text again, while that roll runs: nothing new, and the roll goes on.
    UIView *running = overlayOver(label);
    label.text = @"10:00";
    CHECK(running && overlayOver(label) == running && label.layer.mask, @"the same text again cut the running roll short");

    // Out of the window and back: the next value shows at once, the one after rolls.
    [label removeFromSuperview];
    CHECK(label.layer.mask == nil && overlayOver(label) == nil, @"leaving the window kept the roll");
    [host addSubview:label];
    settle(0.2);
    expectJump(label, @"10:01", @"the first change after attaching");
    settle(0.2);
    expectRoll(label, @"10:02", @"2", @"1", YES, @"10:01 -> 10:02 after attaching");

    // Off any window, nothing rolls.
    [label removeFromSuperview];
    UIView *loose = [UIView new];
    [loose addSubview:label];
    settle(0.2);
    expectJump(label, @"10:03", @"a label in no window");
    [label removeFromSuperview];
    [host addSubview:label];
    settle(0.2);
    expectJump(label, @"10:04", @"back in the window");

    sg_reduceMotion = YES;
    settle(0.2);
    expectRoll(label, @"10:05", @"5", @"4", NO, @"Reduce Motion crossfades");
    sg_reduceMotion = NO;

    // Right to left (a right-to-left mark before Arabic digits) and mixed (a Hebrew letter after the time): shown at
    // once, going in, between two such texts, and going out; a plain time rolls again after.
    settle(0.2);
    expectJump(label, @"\u200F-\u0663:\u0662\u0661", @"to a right-to-left text");
    settle(0.2);
    expectJump(label, @"\u200F-\u0663:\u0662\u0660", @"a right-to-left text's change");
    settle(0.2);
    expectJump(label, @"-3:21 \u05D0", @"to a mixed text");
    settle(0.2);
    expectJump(label, @"-3:20 \u05D0", @"a mixed text's change");
    settle(0.2);
    expectJump(label, @"-3:19", @"from a mixed text");
    settle(0.2);
    expectRoll(label, @"-3:18", @"8", @"9", YES, @"-3:19 -> -3:18 after them");

    // A label not marked keeps its digits one width and never rolls.
    UILabel *plain = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 20)];
    [host addSubview:plain];
    plain.text = @"0:01";
    SGRMonospacedDigits(plain);
    settle(0.2);
    expectJump(plain, @"0:02", @"an unmarked label");
    [host removeFromSuperview];
}

#pragma mark - the add button

static void checkAddMapping(void) {
    struct { BOOL saved, enabled, player, star, plain; SGRAddGlyph want; NSString *what; } cases[] = {
        {NO, YES, YES, YES, NO, SGRAddGlyphStarOutline, @"player, unsaved, star"},
        {YES, YES, YES, YES, NO, SGRAddGlyphStarFilled, @"player, saved, star"},
        {YES, YES, YES, YES, YES, SGRAddGlyphStarFilled, @"player, saved, star and plain check: star wins"},
        {NO, YES, YES, YES, YES, SGRAddGlyphStarOutline, @"player, unsaved, star and plain check: star wins"},
        {NO, NO, YES, YES, NO, SGRAddGlyphSpotify, @"player, unsaved, star, disabled"},
        {YES, NO, YES, YES, YES, SGRAddGlyphSpotify, @"player, saved, star and plain check, disabled"},
        {YES, YES, NO, YES, YES, SGRAddGlyphPlainCheck, @"row, saved, both: plain check keeps the rows"},
        {NO, YES, NO, YES, YES, SGRAddGlyphSpotify, @"row, unsaved, both"},
        {YES, YES, NO, YES, NO, SGRAddGlyphSpotify, @"row, saved, star only"},
        {YES, YES, YES, NO, YES, SGRAddGlyphPlainCheck, @"player, saved, plain check only"},
        {NO, YES, YES, NO, YES, SGRAddGlyphSpotify, @"player, unsaved, plain check only"},
        {YES, YES, YES, NO, NO, SGRAddGlyphSpotify, @"player, saved, neither"},
    };
    for (size_t i = 0; i < sizeof cases / sizeof *cases; i++) {
        SGRAddGlyph got = SGRAddGlyphFor(cases[i].saved, cases[i].enabled, cases[i].player, cases[i].star, cases[i].plain);
        CHECK(got == cases[i].want, @"add glyph %@: got %ld, want %ld", cases[i].what, (long)got, (long)cases[i].want);
    }
}

// Spotify's add button: a UIButton whose Lottie animation sits in a child view.
static UIButton *addButton(UIView *host, UIView **animation) {
    static Class lottie;
    if (!lottie) {
        lottie = objc_allocateClassPair(UIView.class, "Lottie.LottieAnimationView", 0);
        objc_registerClassPair(lottie);
    }
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, 48, 48);
    button.accessibilityIdentifier = @"Components.UI.AddToButton";
    button.accessibilityLabel = @"Add to Liked Songs";
    UIView *state = [[UIView alloc] initWithFrame:button.bounds];
    state.userInteractionEnabled = NO;
    *animation = [[lottie alloc] initWithFrame:state.bounds];
    [state addSubview:*animation];
    [button addSubview:state];
    [host addSubview:button];
    return button;
}

// The button has no image of its own, so its one image view is the Kit's glyph.
static UIImageView *glyphIn(UIButton *button) {
    for (UIView *view in button.subviews) {
        if ([view isKindOfClass:UIImageView.class]) return (UIImageView *)view;
    }
    return nil;
}

// What the button shows as it is, with no layout pass: "spotify" (the animation), or the symbol of the Kit's glyph,
// with its tint's name.
static NSString *shownNow(UIButton *button, UIView *animation) {
    UIImageView *glyph = glyphIn(button);
    BOOL drawn = glyph && glyph.alpha > 0.5;
    if (drawn == (animation.alpha > 0.5)) HARNESS_FAIL(@"the glyph and Spotify's animation both %@", drawn ? @"show" : @"hide");
    if (!drawn) return @"spotify";
    if (glyph.userInteractionEnabled || glyph.isAccessibilityElement) HARNESS_FAIL(@"the glyph takes touches or is an element");
    NSString *name = [glyph.image.description containsString:@"star.fill"] ? @"star.fill"
                   : [glyph.image.description containsString:@"star"] ? @"star"
                   : [glyph.image.description containsString:@"checkmark"] ? @"checkmark" : glyph.image.description;
    BOOL accent = [glyph.tintColor isEqual:SGRAccent()] && [glyph.accessibilityIdentifier isEqualToString:SGRPlainCheckIdentifier];
    // UIKit can expose the symbol's identifier when the view's own identifier is unset.
    UIImageView *reference = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"star"]];
    reference.accessibilityIdentifier = nil;
    BOOL unmarked = glyph.accessibilityIdentifier == reference.accessibilityIdentifier
        || [glyph.accessibilityIdentifier isEqualToString:reference.accessibilityIdentifier];
    BOOL primary = [glyph.tintColor isEqual:SGRPrimary()] && unmarked;
    return [name stringByAppendingString:accent ? @" accent" : primary ? @" primary" : @" ?"];
}

// What the button shows after its next layout pass.
static NSString *shown(UIButton *button, UIView *animation) {
    [button setNeedsLayout];
    [button layoutIfNeeded];
    return shownNow(button, animation);
}

static void expectShown(UIButton *button, UIView *animation, BOOL saved, NSString *want, NSString *what) {
    CGRect frame = button.frame;
    button.selected = saved;
    NSString *got = shown(button, animation);
    CHECK([got isEqualToString:want], @"%@: shows %@, want %@ (tint %@, primary %@, identifier %@)", what, got, want,
          glyphIn(button).tintColor, SGRPrimary(), glyphIn(button).accessibilityIdentifier);
    CHECK(button.isSelected == saved && CGRectEqualToRect(button.frame, frame) && [button.accessibilityLabel isEqualToString:@"Add to Liked Songs"]
          && button.userInteractionEnabled, @"%@: the button is no longer Spotify's", what);
}

static void checkAddButtons(UIWindow *window) {
    _TtC20NowPlaying_ModesImpl23InformationElementsUnit *unit = [_TtC20NowPlaying_ModesImpl23InformationElementsUnit new];
    unit.view.frame = CGRectMake(0, 200, 300, 60);
    [window addSubview:unit.view];
    UIView *titleRow = [[UIView alloc] initWithFrame:unit.view.bounds];
    [unit.view addSubview:titleRow];
    UIView *playerAnimation, *rowAnimation;
    UIButton *player = addButton(titleRow, &playerAnimation);
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 300, 300, 60)];
    [window addSubview:row];
    UIButton *rowButton = addButton(row, &rowAnimation);

    BOOL star = [sg_mode isEqualToString:@"both"];
    expectShown(player, playerAnimation, NO, star ? @"star primary" : @"spotify", @"the player's button, unsaved");
    expectShown(player, playerAnimation, YES, star ? @"star.fill accent" : @"checkmark accent", @"the player's button, saved");
    expectShown(player, playerAnimation, NO, star ? @"star primary" : @"spotify", @"the player's button, unsaved again");
    // Disabled: Spotify's own glyph, which shows it disabled, in place of the star, at once (no layout pass); the
    // star again once enabled.
    player.enabled = NO;
    NSString *got = shownNow(player, playerAnimation);
    CHECK([got isEqualToString:@"spotify"], @"the player's button, disabled: shows %@", got);
    player.selected = YES;
    NSString *want = star ? @"spotify" : @"checkmark accent";
    got = shownNow(player, playerAnimation);
    CHECK([got isEqualToString:want], @"the player's button, saved and disabled: shows %@, want %@", got, want);
    CHECK([shown(player, playerAnimation) isEqualToString:want], @"the player's button, saved and disabled, laid out: changed");
    player.enabled = YES;
    want = star ? @"star.fill accent" : @"checkmark accent";
    got = shownNow(player, playerAnimation);
    CHECK([got isEqualToString:want], @"the player's button, enabled again: shows %@, want %@", got, want);
    expectShown(rowButton, rowAnimation, YES, @"checkmark accent", @"a row's button, saved");
    expectShown(rowButton, rowAnimation, NO, @"spotify", @"a row's button, unsaved");
    [unit.view removeFromSuperview];
    [row removeFromSuperview];
}

#pragma mark - the app

static void run(UIWindow *window) {
    checkDigitRules();
    checkAddMapping();
    if ([sg_mode isEqualToString:@"both"]) checkRollingLabel(window);
    checkAddButtons(window);
    printf("[harness] player-refinements %s: %lu checks passed\n", sg_mode.UTF8String, (unsigned long)sg_checks);
    fflush(stdout);
    exit(0);
}

@interface PlayerRefinementsApp : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation PlayerRefinementsApp
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 390, 844)];
    self.window.rootViewController = [UIViewController new];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.window.windowScene) HARNESS_FAIL(@"the window never joined a scene");
        run(self.window);
    });
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        sg_mode = [NSUserDefaults.standardUserDefaults stringForKey:@"harness.mode"];
        if (![sg_mode isEqualToString:@"both"] && ![sg_mode isEqualToString:@"plain"]) {
            fprintf(stderr, "usage: -harness.mode both|plain with the settings as launch arguments\n");
            return 2;
        }
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(PlayerRefinementsApp.class));
    }
}
