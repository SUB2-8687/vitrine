// What NowPlayingBar.x links against and the text split does not use: the glass, the press watcher, the tab bar's
// slot and the accent, none of which a placed page's text touches.
#import <UIKit/UIKit.h>
#import "Core/SGGlass.h"
#import "Core/SGUIMode.h"
#import "Settings/SGPageStyle.h"
#import "Redesigned/Kit/SGRAccent.h"
#import "Redesigned/Kit/SGRGlass.h"
#import "Redesigned/Kit/SGRPress.h"
#import "Redesigned/Kit/SGRRepaint.h"
#import "Redesigned/Navbar/Navbar.h"

__weak UIView *sgr_nowPlayingRoot;
NSHashTable<UIView *> *sgr_nowPlayingPainted;

BOOL SGRedesignedUI(void) { return NO; }
NSString *SGL(NSString *key, NSString *english) { return english; }
UIColor *SGRAccentColor(void) { return nil; }
// The app's text size, which the harness changes; production reads UIApplication.preferredContentSizeCategory.
// Catalyst's Mac idiom does not scale text, so the sizes are the phone's: the bar's two styles at Large, a point less
// below it, and capped at `largest` like SGCategoryCappedFont.
UIContentSizeCategory sg_harnessTextSize;
UIFont *SGCategoryCappedFont(UIFontTextStyle style, UIFontWeight weight, UIContentSizeCategory largest) {
    UIContentSizeCategory category = sg_harnessTextSize ?: UIContentSizeCategoryLarge;
    if (UIContentSizeCategoryCompareToCategory(category, largest) == NSOrderedDescending) category = largest;
    CGFloat atLarge = [style isEqual:UIFontTextStyleSubheadline] ? 15 : 13;
    BOOL below = UIContentSizeCategoryCompareToCategory(category, UIContentSizeCategoryLarge) == NSOrderedAscending;
    return [UIFont systemFontOfSize:atLarge - (below ? 1 : 0) weight:weight];
}
UIVisualEffectView *SGGlassFor(UIView *host, const void *key) { return nil; }
void SGShapeGlass(UIView *glass, CGFloat radius, BOOL capsule) {}
void SGRShowGlass(UIView *shape, BOOL shown) {}
void SGRPressWatch(UIView *view, SGRPressKind kind, BOOL (^begins)(UITouch *touch), void (^changed)(BOOL pressed, BOOL tapped)) {}
BOOL SGRPressOnSmallControl(UITouch *touch, UIView *container) { return NO; }
void SGRPressAnimateLayer(CALayer *layer, NSString *keyPath, id value, BOOL animated) {}
CGRect SGRTabBarInlineSlot(UIView *host, CGFloat height) { return CGRectNull; }
CGRect SGRTabBarGlassRow(UIView *view) { return CGRectNull; }
