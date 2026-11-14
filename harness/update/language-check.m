#import "Core/SGLocalize.h"
#import "../harness-fail.h"

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        HARNESS_CHECK(argc == 4);
        NSString *choice = @(argv[1]);
        NSMutableDictionary *defaults = [@{@"AppleLanguages": @[@(argv[3])]} mutableCopy];
        if (![choice isEqualToString:@"absent"]) defaults[SGKeyLanguage] = @([choice integerValue]);
        [NSUserDefaults.standardUserDefaults setVolatileDomain:defaults forName:NSArgumentDomain];
        NSString *expected = @(argv[2]);
        HARNESS_CHECK([SGL(@"common.cancel", @"Cancel") isEqualToString:expected]);
        // A preference change waits for the next process, rather than mixing languages mid-launch.
        defaults[SGKeyLanguage] = @1;
        [NSUserDefaults.standardUserDefaults setVolatileDomain:defaults forName:NSArgumentDomain];
        HARNESS_CHECK([SGL(@"common.cancel", @"Cancel") isEqualToString:expected]);
        HARNESS_CHECK([SGL(@"harness.missing", @"English fallback") isEqualToString:@"English fallback"]);
        NSLog(@"[harness] language %@ PASS", choice);
    }
    return 0;
}
