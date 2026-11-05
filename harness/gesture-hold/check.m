// Host check for Shared/Gestures/GestureHold.m: the hold's switch (on unless switched off, apart from the
// double tap's), the speed choice (2x unset, an out-of-range index brought to the nearest valid one) and the words
// of the badge and the VoiceOver announcement. The press itself and the recognizer's enabling are device checks.
#import <Foundation/Foundation.h>
#import "Shared/Gestures/GestureHold.h"
#import "Core/SGPrefs.h"
#import "../harness-fail.h"

static void storeChoice(NSInteger index) {
    [NSUserDefaults.standardUserDefaults setInteger:index forKey:@"spotifyglass.gestures.hold.speed"];
    SGPrefsChanged();
}

int main(void) {
    @autoreleasepool {
        NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
        for (NSString *key in @[@"spotifyglass.gestures.hold", @"spotifyglass.gestures.hold.speed", @"spotifyglass.gestures", SGKeyStock])
            [store removeObjectForKey:key];
        SGPrefsChanged();

        // Unset: the hold works, at the speed it always had.
        HARNESS_CHECK(SGGestureHoldEnabled());
        HARNESS_CHECK(SGGestureHoldSpeedChoice() == 1);
        HARNESS_CHECK(SGGestureHoldSpeed() == 2);

        // Each index plays at its speed.
        double speeds[] = {1.5, 2, 3};
        for (NSInteger index = 0; index < 3; index++) {
            storeChoice(index);
            HARNESS_CHECK(SGGestureHoldSpeedChoice() == index);
            HARNESS_CHECK(SGGestureHoldSpeed() == speeds[index]);
        }

        // Out of range clamps to the nearest valid index.
        NSInteger stored[] = {-100, -1, 3, 4, 99};
        NSInteger clamped[] = {0, 0, 2, 2, 2};
        for (int i = 0; i < 5; i++) {
            storeChoice(stored[i]);
            HARNESS_CHECK(SGGestureHoldSpeedChoice() == clamped[i]);
            HARNESS_CHECK(SGGestureHoldSpeed() == speeds[clamped[i]]);
        }

        // The switch and the double tap's are independent.
        SGSetEnabled(SGKeyGestureHold, NO);
        HARNESS_CHECK(!SGGestureHoldEnabled());
        HARNESS_CHECK(!SGFlag(@"spotifyglass.gestures", NO));
        SGSetEnabled(@"spotifyglass.gestures", YES);
        HARNESS_CHECK(!SGGestureHoldEnabled());
        SGSetEnabled(SGKeyGestureHold, YES);
        SGSetEnabled(@"spotifyglass.gestures", NO);
        HARNESS_CHECK(SGGestureHoldEnabled());

        HARNESS_CHECK([SGGestureHoldSpeedLabel(1.5) isEqualToString:@"1.5×"]);
        HARNESS_CHECK([SGGestureHoldAnnouncement(1.5) isEqualToString:@"Playing at 1.5 times speed"]);

        for (NSString *key in @[@"spotifyglass.gestures.hold", @"spotifyglass.gestures.hold.speed", @"spotifyglass.gestures"])
            [store removeObjectForKey:key];
        SGPrefsChanged();
        printf("gesture-hold: all checks passed\n");
    }
    return 0;
}
