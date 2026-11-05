// Core/SGOptionalWork.m's load-ahead switch read through the real SGPrefs.m: the same default, stock-reset and
// wrong-kind rules as the switch on the settings page that shows it. Only the OS environment is replaced (a path
// monitor that is satisfied at once, no Low Power Mode, a cool device).
#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <objc/runtime.h>
#import "Core/SGOptionalWork.h"
#import "Core/SGPrefs.h"
#import "../harness-fail.h"

static BOOL lowPowerOff(id self, SEL selector) { return NO; }
static NSProcessInfoThermalState cool(id self, SEL selector) { return NSProcessInfoThermalStateNominal; }

void nw_path_monitor_start(nw_path_monitor_t monitor) {}
void nw_path_monitor_set_update_handler(nw_path_monitor_t monitor, nw_path_monitor_update_handler_t handler) {
    handler((nw_path_t)[NSObject new]);
}
nw_path_status_t nw_path_get_status(nw_path_t path) { return nw_path_status_satisfied; }
bool nw_path_is_constrained(nw_path_t path) { return false; }
bool nw_path_is_expensive(nw_path_t path) { return false; }

int main(void) {
    @autoreleasepool {
        // Each blocker wins over the lower-priority blockers, without copying the decision rule.
        HARNESS_CHECK(SGOptionalWorkReasonForInputs(YES, NSProcessInfoThermalStateCritical, NO, YES, YES, NO) == SGOptionalWorkLowPower);
        HARNESS_CHECK(SGOptionalWorkReasonForInputs(NO, NSProcessInfoThermalStateSerious, NO, YES, YES, NO) == SGOptionalWorkHeat);
        HARNESS_CHECK(SGOptionalWorkReasonForInputs(NO, NSProcessInfoThermalStateCritical, YES, NO, NO, YES) == SGOptionalWorkHeat);
        HARNESS_CHECK(SGOptionalWorkReasonForInputs(NO, NSProcessInfoThermalStateNominal, NO, YES, YES, NO) == SGOptionalWorkNoPath);
        HARNESS_CHECK(SGOptionalWorkReasonForInputs(NO, NSProcessInfoThermalStateNominal, YES, YES, YES, NO) == SGOptionalWorkConstrained);
        HARNESS_CHECK(SGOptionalWorkReasonForInputs(NO, NSProcessInfoThermalStateNominal, YES, NO, YES, NO) == SGOptionalWorkExpensive);
        HARNESS_CHECK(SGOptionalWorkReasonForInputs(NO, NSProcessInfoThermalStateFair, YES, NO, YES, YES) == SGOptionalWorkAllowed);
        HARNESS_CHECK(SGOptionalWorkReasonForInputs(NO, NSProcessInfoThermalStateNominal, YES, NO, NO, NO) == SGOptionalWorkAllowed);
        method_setImplementation(class_getInstanceMethod(NSProcessInfo.class, @selector(isLowPowerModeEnabled)), (IMP)lowPowerOff);
        method_setImplementation(class_getInstanceMethod(NSProcessInfo.class, @selector(thermalState)), (IMP)cool);
        NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
        [store removeObjectForKey:SGKeyLoadAhead];
        [store removeObjectForKey:SGKeyStock];
        // Catch an exception so a reader that sends boolValue to a container fails the check instead of crashing.
        @try {
            HARNESS_CHECK(SGOptionalWorkMayRun(YES));   // unset: on
            HARNESS_CHECK(SGOptionalWorkMayRun(NO));
            [store setBool:NO forKey:SGKeyLoadAhead];
            HARNESS_CHECK(!SGOptionalWorkMayRun(YES));
            HARNESS_CHECK(!SGOptionalWorkMayRun(NO));
            [store setBool:YES forKey:SGKeyLoadAhead];
            HARNESS_CHECK(SGOptionalWorkMayRun(YES));
            HARNESS_CHECK(SGOptionalWorkMayRun(NO));
            [store removeObjectForKey:SGKeyLoadAhead];
            // A backup can store any kind under a key that was unset: it reads as unset, not as a crash.
            for (id invalid in @[@[], @{}, [NSData data], [NSDate dateWithTimeIntervalSince1970:0]]) {
                [store setObject:invalid forKey:SGKeyLoadAhead];
                HARNESS_CHECK(SGOptionalWorkMayRun(YES));
            }
            // Reset to stock turns the switch off, and the work with it, until it is turned on.
            [store removeObjectForKey:SGKeyLoadAhead];
            [store setBool:YES forKey:SGKeyStock];
            HARNESS_CHECK(!SGOptionalWorkMayRun(YES));
            [store setBool:YES forKey:SGKeyLoadAhead];
            HARNESS_CHECK(SGOptionalWorkMayRun(YES));
        } @catch (NSException *exception) {
            HARNESS_FAIL(@"Load ahead raised %@", exception.reason);
        }
        [store removeObjectForKey:SGKeyLoadAhead];
        [store removeObjectForKey:SGKeyStock];
        puts("optional work: ok");
    }
    return 0;
}
