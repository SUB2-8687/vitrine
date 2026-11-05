#import "Settings/SGModPage.h"
#import "Core/SGPrefs.h"
#import "Native/Appearance/Appearance.h"
#import "Redesigned/Kit/SGRAccent.h"
#import "../harness-fail.h"

@implementation SGModRow @end
// In-memory settings boundary: row callbacks are real, no shared preferences domain is written.
static NSMutableDictionary *values;
NSInteger SGInt(NSString *key, NSInteger fallback) { return values[key] ? [values[key] integerValue] : fallback; }
BOOL SGFlag(NSString *key, BOOL fallback) { return values[key] ? [values[key] boolValue] : fallback; }
void SGSetInt(NSString *key, NSInteger value) { values[key] = @(value); }
void SGSetEnabled(NSString *key, BOOL on) { values[key] = @(on); }
void SGPrefsChanged(void) {}
NSString *SGL(NSString *key, NSString *english) { return english; }
SGModRow *SGMenuRow(NSString *title, NSArray *choices, NSString *(^value)(void), void (^chosen)(NSInteger)) {
    SGModRow *row = [SGModRow new]; row.title = title; row.menu = choices; row.value = value; row.chosen = chosen; return row;
}
SGModRow *SGStatActionRow(NSString *title, NSString *subtitle, NSString *(^value)(void), void (^action)(void)) {
    SGModRow *row = [SGModRow new]; row.title = title; row.value = value; row.action = action; return row;
}
SGModRow *SGSwitchRow(NSString *title, NSString *subtitle, NSString *key) {
    SGModRow *row = [SGModRow new]; row.title = title; row.subtitle = subtitle; row.key = key; row.defaultOn = YES; return row;
}
SGModRow *SGOptionRow(NSString *title, NSString *subtitle, NSString *key) {
    SGModRow *row = [SGModRow new]; row.title = title; row.subtitle = subtitle; row.key = key; return row;
}
SGModRow *SGWithSymbol(SGModRow *row, NSString *symbol) { row.symbol = symbol; return row; }
UIColor *SGColorRGB(NSInteger rgb) { return UIColor.blackColor; }
NSInteger SGAccentRGB(void) { return SGInt(SGKeyAccent, SGSpotifyGreen); }
NSInteger SGRAccentRGB(void) { return 0x00FFFF; } // a temporary automatic color must never enter picked history
NSInteger SGRPickedAccentRGB(void) { return SGInt(SGRKeyAccent, SGRDefaultAccent); }
void SGRAccentPreferencesChanged(void) { SGPrefsChanged(); }
void SGRefreshExplicitBadges(void) {}
void SGRRefreshExplicitBadges(void) {}
void SGPickAccent(NSString *title, NSInteger current, NSArray *recent, void (^chosen)(NSInteger)) {}
void SGRPickAccent(NSString *title, NSInteger current, NSArray *recent, void (^chosen)(NSInteger)) {}

static SGModRow *named(NSArray *rows, NSString *title) {
    for (SGModRow *row in rows) if ([row.title isEqualToString:title]) return row;
    return nil;
}
static NSUInteger checks;
static void expect(BOOL ok, NSString *name) { checks++; if (!ok) HARNESS_FAIL(@"%@", name); }
static void checkRecents(NSArray<NSNumber *> *(*from)(id),
                         NSArray<NSNumber *> *(*adding)(NSArray<NSNumber *> *, NSInteger, NSInteger),
                         NSInteger own) {
    expect([from(nil) isEqual:@[]], @"no saved colors");
    expect([from(@"#123456") isEqual:@[]], @"non-list history ignored");
    expect([from(@[@0x123456, @"#ABCDEF", @YES, @1.5, @(-1), @0x1000000, @(own), @{}, @0x123456, @0xABCDEF])
            isEqual:@[@0x123456, @0xABCDEF]], @"invalid, default and duplicate colors ignored");
    expect([from(@[@1, @2, @3, @4, @5, @6, @7, @8, @9, @10]) isEqual:@[@1, @2, @3, @4, @5, @6, @7, @8]], @"eight recent colors");
    expect([adding(@[], 0x112233, own) isEqual:@[@0x112233]], @"first color");
    expect([adding(@[@0xA, @0xB], 0xC, 0xA) isEqual:@[@0xC, @0xA, @0xB]], @"new color first");
    expect([adding(@[@0xA, @0xB, @0xC], 0xC, 0xA) isEqual:@[@0xC, @0xA, @0xB]], @"existing color moved first");
    expect([adding(@[@1, @2, @3, @4, @5, @6, @7, @8], 9, 1) isEqual:@[@9, @1, @2, @3, @4, @5, @6, @7]], @"oldest color evicted");
    expect([adding(@[@0xA, @0xB], 0xB, 0xB) isEqual:@[@0xA, @0xB]], @"same color leaves history alone");
    expect([adding(@[@0xA], own, 0xA) isEqual:@[@0xA]], @"default not saved");
    expect([adding(@[@0xA], -1, 0xA) isEqual:@[@0xA]], @"negative color not saved");
    expect([adding(@[@0xA], 0x1000000, 0xA) isEqual:@[@0xA]], @"out of range color not saved");
}
int main(void) {
    @autoreleasepool {
        checkRecents(SGAccentRecentFrom, SGAccentRecentAdding, 0x1ED760);
        checkRecents(SGRAccentRecentFrom, SGRAccentRecentAdding, 0x37F200);
        expect([SGRAccentRecentFrom(@[@0x1ED760, @0x37F200, @0xFA2D48]) isEqual:@[@0xFA2D48]], @"redesign omits both preset greens");
        expect([SGRAccentRecentAdding(@[], 0x1ED760, 0x37F200) isEqual:@[]], @"Spotify preset not saved");
        expect([SGAccentRecentAdding(@[], 0x37F200, 0x1ED760) isEqual:@[@0x37F200]], @"native history owns its colors");
        values = [@{SGRKeyAccent: @0x123456} mutableCopy];
        NSArray *native = SGNativeAppearanceRows(), *redesign = SGRAppearanceRows();
        SGModRow *mode = named(redesign, @"Accent source");
        expect([mode.menu isEqual:@[@"Picked", @"Automatic"]], @"exact automatic choices");
        expect([mode.value() isEqualToString:@"Picked"], @"Picked is the default");
        mode.chosen(1);
        expect(SGFlag(SGRKeyAccentAuto, NO), @"Automatic writes its redesign-only key");
        expect([named(redesign, @"Accent color").value() isEqualToString:@"#123456"], @"color row shows saved pick, not automatic tint");
        named(redesign, @"Accent color preset").chosen(1);
        expect(SGInt(SGRKeyAccentCustom, -1) == 0x123456, @"preset change keeps saved custom color, not automatic tint");
        mode.chosen(0);
        expect(!SGFlag(SGRKeyAccentAuto, YES), @"Picked disables automatic");
        expect(named(native, @"Accent source") == nil, @"Native has no automatic row");
        SGModRow *nativeBadge = named(native, @"Hide explicit badge"), *redesignBadge = named(redesign, @"Hide explicit badge");
        expect([nativeBadge.key isEqualToString:@"spotifyglass.hideExplicit"] && !nativeBadge.defaultOn, @"Native badge key and off default");
        expect([redesignBadge.key isEqualToString:@"spotifyglass.redesign.hideExplicit"] && !redesignBadge.defaultOn, @"redesign badge key and off default");
        printf("appearance rows: %lu checks passed\n", (unsigned long)checks);
    }
    return 0;
}
