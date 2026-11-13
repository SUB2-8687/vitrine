#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "Shared/Haptics/Haptics.h"

// A command-line Catalyst check has no UIApplication to forward UIControl actions.
@interface HarnessSlider : UISlider
@end
@implementation HarnessSlider
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    ((void (*)(id, SEL, id))objc_msgSend)(target, action, self);
}
@end

static NSMutableArray *taps;
static BOOL controls = YES;
static double strength = 1;
BOOL SGEnabled(NSString *key) { return controls; }
double SGHapticsStrength(NSString *key) { return strength; }

static void tick(id self, SEL cmd) { [taps addObject:@"tick"]; }
static void impact(id self, SEL cmd, CGFloat intensity) {
    [taps addObject:[NSString stringWithFormat:@"impact:%.2f", intensity]];
}
static void move(UISlider *slider, float value) {
    slider.value = value;
    [slider sendActionsForControlEvents:UIControlEventValueChanged];
}
static BOOL expect(NSArray *wanted) {
    if ([taps isEqual:wanted]) return YES;
    NSLog(@"FAIL volume feedback %@, expected %@", taps, wanted);
    return NO;
}
int main(void) {
    @autoreleasepool {
        method_setImplementation(class_getInstanceMethod(UISelectionFeedbackGenerator.class, @selector(selectionChanged)), (IMP)tick);
        method_setImplementation(class_getInstanceMethod(UIImpactFeedbackGenerator.class, @selector(impactOccurredWithIntensity:)), (IMP)impact);
        taps = [NSMutableArray array];
        UISlider *slider = [HarnessSlider new];
        SGInstallVolumeFeedback(slider);
        SGInstallVolumeFeedback(slider);
        slider.value = 0.5;
        [slider sendActionsForControlEvents:UIControlEventTouchDown];
        move(slider, 0.563);
        move(slider, 0.562);
        move(slider, 0.57);
        move(slider, 1);
        move(slider, 1);
        move(slider, 0);
        move(slider, 0);
        [slider sendActionsForControlEvents:UIControlEventTouchUpInside];
        if (!expect(@[@"impact:0.70", @"tick", @"impact:0.60", @"impact:0.60", @"impact:0.80"])) return 1;
        // Passing directly from max to zero still reaches a different end, and must tap there too.
        [taps removeAllObjects];
        slider.value = 0.1;
        [slider sendActionsForControlEvents:UIControlEventTouchDown];
        move(slider, 0);
        move(slider, 0);
        [slider sendActionsForControlEvents:UIControlEventTouchUpInside];
        if (!expect(@[@"impact:0.70", @"impact:0.60", @"impact:0.80"])) return 1;
        [taps removeAllObjects];
        controls = NO;
        [slider sendActionsForControlEvents:UIControlEventTouchDown];
        move(slider, 0.5);
        move(slider, 1);
        [slider sendActionsForControlEvents:UIControlEventTouchUpInside];
        if (!expect(@[])) return 1;
        controls = YES;
        strength = 0.5;
        slider.value = 0.5;
        [slider sendActionsForControlEvents:UIControlEventTouchDown];
        move(slider, 0.57);
        move(slider, 1);
        [slider sendActionsForControlEvents:UIControlEventTouchCancel];
        move(slider, 0);
        if (!expect(@[@"impact:0.35", @"impact:0.25", @"impact:0.30"])) return 1;
        NSLog(@"PASS volume detents, endpoints, Controls off, strength and cancellation");
    }
    return 0;
}
