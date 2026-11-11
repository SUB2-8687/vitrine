#import "Flags.h"
#import "Core/SGFlagForce.h"
#import "Core/SGPrefs.h"

static id badgeValue(NSString *key, BOOL main, BOOL likely) {
    if (!main) return nil;
    if ([key isEqualToString:@"ios-creator-impl.is_ai_persona_badge_enabled"] ||
        [key isEqualToString:@"ios-creator-impl.is_ai_attribution_enabled"] ||
        [key isEqualToString:@"ios-feature-search.ai_persona_badge_enabled"] ||
        [key isEqualToString:@"ios-listuxplatformconsumers-defaultrowslotplugins.ai_persona_badge_enabled"]) return @YES;
    if (likely && ([key isEqualToString:@"ios-creator-impl.is_likely_ai_persona_badge_enabled"] ||
                   [key isEqualToString:@"ios-feature-search.likely_ai_persona_badge_enabled"])) return @YES;
    return nil;
}

__attribute__((constructor)) static void registerBadges(void) {
    SGRegisterFlagForcer(YES, ^id(NSString *key) {
        static BOOL main, likely;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            main = SGFlag(SGKeyAIBadges, NO);
            likely = SGFlag(SGKeyLikelyAIBadges, NO);
        });
        return badgeValue(key, main, likely);
    }, ^id(NSString *key) {
        return badgeValue(key, SGFlag(SGKeyAIBadges, NO), SGFlag(SGKeyLikelyAIBadges, NO));
    });
}
