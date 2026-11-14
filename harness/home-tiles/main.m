// Real tile styling, image observation, tint cache and Home preferences (HomeShelves.m); the palette is a test double
// answering one color per strength.
#import <UIKit/UIKit.h>
#import "Core/SGCore.h"
#import "Redesigned/Home/Home.h"
#import "Redesigned/Kit/SGRPalette.h"
#import "../harness-fail.h"

CFTimeInterval SGRHomeProbeBegin(void) { return 0; }
void SGRHomeProbeEnd(SGRHomeProbe probe, CFTimeInterval began) {}
UIColor *SGRAccentColor(void) { return nil; }
// Kit/SGRRestyle.m rolls the player's digits, which no tile has.
void SGRRollingDigitsMovedToWindow(UILabel *label) {}
void SGRRollingDigitsTextChanged(UILabel *label, NSAttributedString *before) {}
BOOL SGRRollingDigitsWatched(UILabel *label) { return NO; }

static UIColor *strongTint(void) { return UIColor.redColor; }
static UIColor *weakTint(void) { return UIColor.blueColor; }

@implementation SGRPalette
+ (void)tintForImage:(UIImage *)image surface:(UIColor *)surface strong:(BOOL)strong completion:(void (^)(UIColor *))completion {
    completion(strong ? strongTint() : weakTint());
}
@end

static void setPreference(NSString *key, NSNumber *on) {
    if (on) [NSUserDefaults.standardUserDefaults setBool:on.boolValue forKey:key];
    else [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
    SGPrefsChanged();
}

// Glass shortcuts: unset, it is what the Home look is, on or off; set, its own whatever the look.
static void checkShortcutGlassPreference(void) {
    setPreference(SGRKeyHomeShortcutGlass, nil);
    setPreference(SGRKeyHomeLook, @NO);
    HARNESS_CHECK(!SGRHomeShortcutGlassStored());
    setPreference(SGRKeyHomeLook, @YES);
    HARNESS_CHECK(SGRHomeShortcutGlassStored());
    setPreference(SGRKeyHomeShortcutGlass, @NO);
    HARNESS_CHECK(!SGRHomeShortcutGlassStored());
    setPreference(SGRKeyHomeLook, @NO);
    setPreference(SGRKeyHomeShortcutGlass, @YES);
    HARNESS_CHECK(SGRHomeShortcutGlassStored());
    // As an existing user has it, neither key written: the launch read is glass, which the tiles below are styled with.
    setPreference(SGRKeyHomeShortcutGlass, nil);
    setPreference(SGRKeyHomeLook, nil);
    HARNESS_CHECK(SGRHomeShortcutGlass());
    NSLog(@"[harness] PASS Glass shortcuts follows the Home look until set");
}

static UIColor *tintFor(UIImage *image, BOOL strong) {
    __block UIColor *answer;
    SGRHomeTintForCover(image, strong, ^(UIColor *color) { answer = color; });
    return answer;
}

// One cover asked for at both strengths: Top picks' strong tint is not the shortcuts' weak one cached first, nor the
// other way round.
static void checkTintStrengths(void) {
    UIImage *cover = [[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(8, 8)] imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [UIColor.greenColor setFill];
        [context fillRect:CGRectMake(0, 0, 8, 8)];
    }];
    HARNESS_CHECK([tintFor(cover, NO) isEqual:weakTint()]);
    HARNESS_CHECK([tintFor(cover, YES) isEqual:strongTint()]);
    HARNESS_CHECK([tintFor(cover, NO) isEqual:weakTint()]);
    NSLog(@"[harness] PASS a cover's tint is kept apart per strength");
}

static void checkReuse(BOOL measured) {
    UIView *tile = [[UIView alloc] initWithFrame:CGRectMake(0, 0, measured ? 181 : 0, 48)];
    tile.accessibilityIdentifier = @"Shortcut.Card.Home";
    UIView *fill = [[UIView alloc] initWithFrame:tile.bounds];
    [tile addSubview:fill];
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 181, 48)];
    [tile addSubview:row];
    UIView *square = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 48, 48)];
    [row addSubview:square];
    UIView *holder = [[UIView alloc] initWithFrame:square.bounds];
    holder.accessibilityIdentifier = @"Encore.ImageView";
    [square addSubview:holder];
    UIImageView *cover = [[UIImageView alloc] initWithFrame:holder.bounds];
    [holder addSubview:cover];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(56, 0, 100, 48)];
    title.accessibilityIdentifier = @"Shortcut.Card.Home.Content.title-internal";
    title.text = @"Shortcut";
    [row addSubview:title];

    SGRHomeStyleTile(tile);
    if (measured) HARNESS_CHECK(!CGAffineTransformIsIdentity(square.transform));
    tile.accessibilityIdentifier = @"Components.UI.HomeCard";
    SGRHomeUnstyleTile(tile);
    tile.bounds = CGRectMake(0, 0, 181, 48);
    fill.frame = tile.bounds;
    cover.image = [UIImage systemImageNamed:@"music.note"];
    HARNESS_CHECK(tile.subviews.count == 2);
    HARNESS_CHECK(CGAffineTransformIsIdentity(square.transform));
    HARNESS_CHECK(CGAffineTransformIsIdentity(title.transform));
    HARNESS_CHECK(title.alpha == 1);
    NSLog(@"[harness] PASS image update leaves %@ reused card unstyled", measured ? @"measured" : @"not-yet-measured");

    tile.accessibilityIdentifier = @"Shortcut.Card.Home";
    SGRHomeStyleTile(tile);
    HARNESS_CHECK(!CGAffineTransformIsIdentity(square.transform));
    NSLog(@"[harness] PASS reused card can become a shortcut again");
}

@interface HomeTilesController : UIViewController
@end
@implementation HomeTilesController
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    checkShortcutGlassPreference();
    checkTintStrengths();
    checkReuse(YES);
    checkReuse(NO);
    NSLog(@"[harness] done");
    exit(0);
}
@end

@interface HomeTilesDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation HomeTilesDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [HomeTilesController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(HomeTilesDelegate.class));
    }
}
