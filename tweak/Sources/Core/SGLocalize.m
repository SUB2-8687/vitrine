#import "SGLocalize.h"

static NSString *const kBundleName = @"Vitrine.bundle";

static NSBundle *resourceBundle(void) {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    NSString *inApp = [NSBundle.mainBundle pathForResource:@"Vitrine" ofType:@"bundle"];
    if (inApp) [paths addObject:inApp];
    [paths addObject:[@"/var/jb/Library/Application Support" stringByAppendingPathComponent:kBundleName]];
    [paths addObject:[@"/Library/Application Support" stringByAppendingPathComponent:kBundleName]];
    for (NSString *path in paths) {
        NSBundle *bundle = [NSBundle bundleWithPath:path];
        if (bundle) return bundle;
    }
    return nil;
}

// Spotify's own language, which iOS picks from the languages Spotify has and the one set for it in Settings. An app
// with one localization (a harness) has no such choice, so the user's first language stands in for it.
static NSString *appLanguage(void) {
    NSBundle *main = NSBundle.mainBundle;
    if (main.localizations.count > 1) {
        NSString *language = main.preferredLocalizations.firstObject;
        if (language.length) return language;
    }
    return NSLocale.preferredLanguages.firstObject ?: @"en";
}

// The bundle's localization for that language: the identifier itself (zh-Hans), then language and script, then the
// language code alone (ko for ko-KR). Nothing matching means English.
static NSString *matchLanguage(NSString *wanted, NSArray<NSString *> *available) {
    NSString *normal = [wanted stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
    if ([available containsObject:normal]) return normal;
    NSDictionary<NSString *, NSString *> *parts = [NSLocale componentsFromLocaleIdentifier:normal];
    NSString *code = parts[NSLocaleLanguageCode], *script = parts[NSLocaleScriptCode];
    if (code.length && script.length) {
        NSString *withScript = [NSString stringWithFormat:@"%@-%@", code, script];
        if ([available containsObject:withScript]) return withScript;
    }
    if (code.length && [available containsObject:code]) return code;
    return @"en";
}

// What each argument of a format string is read as, by its position: the length modifier and conversion ("@", "ld",
// "llu", ".1f" -> "f"), and "*" for a width or precision read from the arguments. A translation is used only when it
// reads the same arguments as the same types as the English, so it may reorder them with positions (%2$@) but never
// read one the English does not pass. Two reads of one position as different types give nil, which matches nothing.
// A % followed by anything else, a space included, is text ("100% of"). scripts/check-strings.py reads them the same way.
static NSDictionary<NSNumber *, NSString *> *specifiers(NSString *format) {
    NSMutableDictionary<NSNumber *, NSString *> *found = [NSMutableDictionary dictionary];
    NSInteger next = 1;
    NSUInteger length = format.length;
    BOOL (^read)(NSInteger, NSString *) = ^BOOL(NSInteger position, NSString *type) {
        NSString *before = found[@(position)];
        if (before && ![before isEqualToString:type]) return NO;
        found[@(position)] = type;
        return YES;
    };
    for (NSUInteger i = 0; i < length; i++) {
        if ([format characterAtIndex:i] != '%') continue;
        NSUInteger j = i + 1;
        if (j < length && [format characterAtIndex:j] == '%') { i = j; continue; }
        NSInteger position = 0;
        NSUInteger digits = j;
        while (digits < length && [format characterAtIndex:digits] >= '0' && [format characterAtIndex:digits] <= '9') {
            position = position * 10 + ([format characterAtIndex:digits] - '0');
            digits++;
        }
        if (digits > j && digits < length && [format characterAtIndex:digits] == '$') j = digits + 1;
        else position = 0;
        NSInteger stars = 0;
        while (j < length && [format characterAtIndex:j] < 128 && strchr("0123456789.-+#*", [format characterAtIndex:j])) {
            if ([format characterAtIndex:j] == '*') stars++;
            j++;
        }
        NSUInteger start = j;
        while (j < length && [format characterAtIndex:j] < 128 && strchr("hlqLzjt", [format characterAtIndex:j])) j++;
        if (j >= length) continue;
        unichar conversion = [format characterAtIndex:j];
        if (conversion >= 128 || !strchr("@dDiuUxXoOfFeEgGaAcCsSp", conversion)) continue;
        if (!position) {
            for (NSInteger s = 0; s < stars; s++) if (!read(next++, @"*")) return nil;
        } else if (stars) {
            return nil;   // a positional conversion with a * width: nothing here uses one, so it is never trusted
        }
        if (!read(position ?: next, [format substringWithRange:NSMakeRange(start, j + 1 - start)])) return nil;
        next = (position ?: next) + 1;
        i = j;
    }
    return found;
}

static NSString *sg_language = @"en";
static NSDictionary<NSString *, NSString *> *sg_table;
static NSInteger sg_loadedChoice;
static BOOL sg_loaded;

static NSRecursiveLock *localizationLock(void) {
    static NSRecursiveLock *lock;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ lock = [NSRecursiveLock new]; });
    return lock;
}

static void load(void) {
    NSRecursiveLock *lock = localizationLock();
    [lock lock];
    NSInteger choice = [NSUserDefaults.standardUserDefaults integerForKey:SGKeyLanguage];
    if (sg_loaded && choice == sg_loadedChoice) { [lock unlock]; return; }

    NSBundle *bundle = resourceBundle();
    NSString *wanted = choice == 1 ? @"en" : choice == 2 ? @"ko" : appLanguage();
    NSString *language = bundle ? matchLanguage(wanted, bundle.localizations) : @"en";
    NSMutableDictionary<NSString *, NSString *> *table = [NSMutableDictionary dictionary];
    if (![language isEqualToString:@"en"]) {
        // Localizable.strings is the mod's own table; the others sit beside it in the same .lproj so a page's words can
        // be edited as a language pack of their own (WireGuard.strings: settings.wireguard.*). A key is looked for in all.
        for (NSString *name in @[@"Localizable", @"WireGuard"]) {
            NSString *path = [bundle pathForResource:name ofType:@"strings" inDirectory:nil forLocalization:language];
            NSDictionary *part = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
            if ([part isKindOfClass:NSDictionary.class]) [table addEntriesFromDictionary:part];
        }
    }
    sg_table = table.count ? [table copy] : nil;
    sg_language = table.count ? language : @"en";
    sg_loadedChoice = choice;
    sg_loaded = YES;
    [lock unlock];
}

BOOL SGSetLanguageChoice(NSInteger choice) {
    if (choice < 0 || choice > 2) choice = 0;
    NSRecursiveLock *lock = localizationLock();
    [lock lock];
    NSInteger previous = sg_loaded ? sg_loadedChoice : [NSUserDefaults.standardUserDefaults integerForKey:SGKeyLanguage];
    [NSUserDefaults.standardUserDefaults setInteger:choice forKey:SGKeyLanguage];
    BOOL changed = !sg_loaded || previous != choice;
    if (changed) sg_loaded = NO;
    [lock unlock];
    if (changed) load();
    return changed;
}

NSString *SGL(NSString *key, NSString *english) {
    load();
    if (!key) return english;
    NSRecursiveLock *lock = localizationLock();
    [lock lock];
    id value = sg_table[key];
    NSString *text = [value isKindOfClass:NSString.class] ? [value copy] : nil;
    [lock unlock];
    if (![text isKindOfClass:NSString.class] || ![text length]) return english;
    if ([english rangeOfString:@"%"].location != NSNotFound || [text rangeOfString:@"%"].location != NSNotFound) {
        NSDictionary *wanted = specifiers(english), *read = specifiers(text);
        if (!wanted || !read || ![wanted isEqualToDictionary:read]) return english;
    }
    return text;
}

NSString *SGLanguage(void) {
    load();
    NSRecursiveLock *lock = localizationLock();
    [lock lock];
    NSString *language = [sg_language copy];
    [lock unlock];
    return language;
}
