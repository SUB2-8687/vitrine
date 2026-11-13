// The taps of Vibrations > Controls, one per kind of control, from UIKit's feedback generators, so they
// feel like the rest of iOS: impacts for a press that does something, selection ticks for a value moving
// under the finger (Apple's Playing haptics: impact complements a physical action, selection a changing
// value). Starting playback is a crisp tap and stopping it a soft one, so the two can be told apart
// without looking.
//
// Controls' strength scales every impact's intensity. A selection tick has no intensity to scale, so under
// 100% it becomes a rigid impact, the nearest thing UIKit has to it, at about a tick's weight times the
// strength; at 100% it stays the system's own tick.
#import "Core/SGCore.h"
#import "Haptics.h"
#import <objc/runtime.h>

typedef struct {
    NSInteger style;      // a UIImpactFeedbackStyle, or kSelection
    CGFloat intensity;
} Tap;

static const NSInteger kSelection = -1;
// A rigid impact at this intensity stands in for a selection tick (a bet: UIKit gives the tick no number).
static const CGFloat kTickIntensity = 0.5;

static Tap tapFor(SGFeedback feedback) {
    switch (feedback) {
        case SGFeedbackPlay: return (Tap){UIImpactFeedbackStyleRigid, 0.8};
        case SGFeedbackPause: return (Tap){UIImpactFeedbackStyleSoft, 1};
        case SGFeedbackSkip: return (Tap){UIImpactFeedbackStyleLight, 1};
        case SGFeedbackToggle: return (Tap){kSelection, 1};
        case SGFeedbackAdd: return (Tap){UIImpactFeedbackStyleMedium, 0.8};
        case SGFeedbackGrab: return (Tap){UIImpactFeedbackStyleLight, 0.7};
        case SGFeedbackDetent: return (Tap){kSelection, 1};
        case SGFeedbackEdge: return (Tap){UIImpactFeedbackStyleRigid, 0.6};
        case SGFeedbackRelease: return (Tap){UIImpactFeedbackStyleSoft, 0.8};
    }
    return (Tap){kSelection, 1};
}

static Tap tapAtStrength(SGFeedback feedback) {
    Tap tap = tapFor(feedback);
    double strength = SGHapticsStrength(SGKeyControlStrength);
    if (strength >= 1) return tap;
    if (tap.style == kSelection) return (Tap){UIImpactFeedbackStyleRigid, kTickIntensity * strength};
    return (Tap){tap.style, tap.intensity * strength};
}

static UIFeedbackGenerator *generatorFor(NSInteger style) {
    static NSMutableDictionary<NSNumber *, UIFeedbackGenerator *> *generators;
    if (!generators) generators = [NSMutableDictionary dictionary];
    UIFeedbackGenerator *generator = generators[@(style)];
    if (!generator) {
        generator = style == kSelection ? [UISelectionFeedbackGenerator new] : [[UIImpactFeedbackGenerator alloc] initWithStyle:(UIImpactFeedbackStyle)style];
        generators[@(style)] = generator;
    }
    return generator;
}

void SGPlayFeedback(SGFeedback feedback) {
    if (!SGEnabled(SGKeyControlHaptics)) return;
    Tap tap = tapAtStrength(feedback);
    UIFeedbackGenerator *generator = generatorFor(tap.style);
    if (tap.style == kSelection) [(UISelectionFeedbackGenerator *)generator selectionChanged];
    else [(UIImpactFeedbackGenerator *)generator impactOccurredWithIntensity:tap.intensity];
}

void SGPrepareFeedback(SGFeedback feedback) {
    if (!SGEnabled(SGKeyControlHaptics)) return;
    [generatorFor(tapAtStrength(feedback).style) prepare];
}

// The hardware buttons' sixteen steps, with hysteresis so resting a finger on a boundary does not chatter.
static const CGFloat kVolumeSteps = 16, kVolumeHysteresis = 0.004;

@interface SGVolumeFeedback : NSObject
@end

@implementation SGVolumeFeedback {
    NSInteger _step, _end;
    BOOL _dragging;
}
- (void)begin:(UISlider *)slider {
    _step = (NSInteger)floor(slider.value * kVolumeSteps);
    _end = slider.value <= 0 ? -1 : slider.value >= 1 ? 1 : 0;
    _dragging = YES;
    SGPlayFeedback(SGFeedbackGrab);
    SGPrepareFeedback(SGFeedbackDetent);
}
- (void)changed:(UISlider *)slider {
    if (!_dragging) return;
    CGFloat value = slider.value;
    NSInteger end = value <= 0 ? -1 : value >= 1 ? 1 : 0;
    if (end != _end) {
        _end = end;
        if (end) SGPlayFeedback(SGFeedbackEdge);
    }
    NSInteger step = (NSInteger)floor(value * kVolumeSteps);
    if (step != _step && fabs(value * kVolumeSteps - MAX(step, _step)) > kVolumeHysteresis * kVolumeSteps) {
        _step = step;
        if (!end) SGPlayFeedback(SGFeedbackDetent);
    }
}
- (void)end:(UISlider *)slider {
    if (_dragging) SGPlayFeedback(SGFeedbackRelease);
    _dragging = NO;
}
- (void)cancel:(UISlider *)slider { _dragging = NO; }
@end

void SGInstallVolumeFeedback(UISlider *slider) {
    static char key;
    if (!slider || objc_getAssociatedObject(slider, &key)) return;
    SGVolumeFeedback *feedback = [SGVolumeFeedback new];
    objc_setAssociatedObject(slider, &key, feedback, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [slider addTarget:feedback action:@selector(begin:) forControlEvents:UIControlEventTouchDown];
    [slider addTarget:feedback action:@selector(changed:) forControlEvents:UIControlEventValueChanged];
    [slider addTarget:feedback action:@selector(end:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [slider addTarget:feedback action:@selector(cancel:) forControlEvents:UIControlEventTouchCancel];
}
