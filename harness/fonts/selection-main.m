#import <UIKit/UIKit.h>
#import "Core/SGCore.h"
#import "Shared/Fonts/Fonts.h"
#import "../harness-fail.h"

SGAppFont SGAppFontChosen(void) {
    NSInteger font = SGInt(SGKeyAppFont, SGAppFontSpotify);
    return font >= SGAppFontSpotify && font <= SGAppFontLibrary ? font : SGAppFontSpotify;
}
NSArray<NSString *> *SGAppFontNames(void) {
    return @[@"Default", @"San Francisco", @"SF Rounded", @"New York", @"SF Mono"];
}
NSArray<NSString *> *SGAppFontFamilies(void) { return @[@"Avenir Next", @"Georgia"]; }
void SGCheckFontSelection(void);

int main(void) {
    @autoreleasepool {
        SGCheckFontSelection();
        [NSRunLoop.mainRunLoop run];
        HARNESS_FAIL(@"font selection returned without completing");
    }
}
