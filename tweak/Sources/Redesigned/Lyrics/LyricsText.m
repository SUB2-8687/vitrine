// What a line shows besides its words, as stored: the two switches of the lyrics menu and the order of
// sizes of the Lyrics page (LyricsText.h). The page itself is LyricsTextSettings.m.
#import "Core/SGCore.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/LockScreenLyrics/LockScreenLyrics.h"
#import "LyricsText.h"

NSNotificationName const SGRLyricsTextDidChangeNotification = @"spotifyglass.redesign.lyricsTextDidChange";

static NSString *keyOf(SGRLyricsText text) {
    switch (text) {
        case SGRLyricsTextLyrics: return @"lyrics";
        case SGRLyricsTextPronunciation: return @"pronunciation";
        case SGRLyricsTextTranslation: return @"translation";
    }
    return nil;
}

NSString *SGRLyricsTextName(SGRLyricsText text) {
    switch (text) {
        case SGRLyricsTextLyrics: return SGL(@"settings.lyricstext.choice.lyrics", @"Lyrics");
        case SGRLyricsTextPronunciation: return SGL(@"settings.lyricstext.choice.pronunciation", @"Pronunciation");
        case SGRLyricsTextTranslation: return SGL(@"settings.lyricstext.choice.translation", @"Translation");
    }
    return nil;
}

// A stored order is taken only as a full set of the three; anything else is Apple Music's.
NSArray<NSNumber *> *SGRLyricsTextOrder(void) {
    NSArray<NSNumber *> *fallback = @[@(SGRLyricsTextLyrics), @(SGRLyricsTextPronunciation), @(SGRLyricsTextTranslation)];
    id stored = [NSUserDefaults.standardUserDefaults arrayForKey:SGRKeyLyricsTextOrder];
    if (![stored isKindOfClass:NSArray.class] || [stored count] != fallback.count) return fallback;
    NSMutableArray<NSNumber *> *order = [NSMutableArray array];
    for (id key in stored) {
        for (NSNumber *text in fallback) {
            if ([key isEqual:keyOf(text.integerValue)] && ![order containsObject:text]) [order addObject:text];
        }
    }
    return order.count == fallback.count ? order : fallback;
}

// As the lyrics view's style takes them (SGRKaraokeView.m, styleNow): the pronunciation's place shows with the menu's
// switch or with Romanized on, and the first of the order is set largest.
SGRLyricsReading SGRLyricsReadingShown(BOOL *leads) {
    if (leads) *leads = NO;
    if (!SGRedesignedUI()) return SGRLyricsReadingNone;
    BOOL romanised = SGFlag(SGKeyLyricsRomanised, NO);
    if (!romanised && !SGFlag(SGRKeyLyricsPronunciation, NO)) return SGRLyricsReadingNone;
    NSArray<NSNumber *> *order = SGRLyricsTextOrder();
    if (leads) *leads = [order indexOfObject:@(SGRLyricsTextPronunciation)] < [order indexOfObject:@(SGRLyricsTextLyrics)];
    return romanised ? SGRLyricsReadingRomanised : SGRLyricsReadingSource;
}

void SGRSetLyricsTextOrder(NSArray<NSNumber *> *order) {
    NSMutableArray<NSString *> *keys = [NSMutableArray array];
    for (NSNumber *text in order) [keys addObject:keyOf(text.integerValue)];
    [NSUserDefaults.standardUserDefaults setObject:keys forKey:SGRKeyLyricsTextOrder];
    [NSNotificationCenter.defaultCenter postNotificationName:SGRLyricsTextDidChangeNotification object:nil];
}

static NSString *lookKey(SGRLyricsText text, NSString *part) {
    return [NSString stringWithFormat:@"%@.%@.%@", SGRKeyLyricsTextLook, keyOf(text), part];
}

SGRLyricsTextLook SGRLyricsTextLookDefault(SGRLyricsText text) {
    return (SGRLyricsTextLook){100, text == SGRLyricsTextTranslation ? 1 : 2, 100};
}

// A stored number is taken only within its range and on its step.
static NSInteger storedPart(NSString *key, NSInteger least, NSInteger most, NSInteger step, NSInteger fallback) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    if (![value isKindOfClass:NSNumber.class]) return fallback;
    double number = [value doubleValue];
    if (!(number >= least && number <= most) || fmod(number - least, step) != 0) return fallback;
    return (NSInteger)number;
}

SGRLyricsTextLook SGRLyricsTextLookOf(SGRLyricsText text) {
    SGRLyricsTextLook look = SGRLyricsTextLookDefault(text);
    if (!keyOf(text)) return look;
    look.scale = storedPart(lookKey(text, @"scale"), 80, 130, 5, look.scale);
    look.weight = storedPart(lookKey(text, @"weight"), 0, 2, 1, look.weight);
    if (text != SGRLyricsTextLyrics) look.brightness = storedPart(lookKey(text, @"brightness"), 40, 140, 10, look.brightness);
    return look;
}

BOOL SGRLyricsTextLookIsDefault(SGRLyricsText text) {
    SGRLyricsTextLook look = SGRLyricsTextLookOf(text), usual = SGRLyricsTextLookDefault(text);
    return look.scale == usual.scale && look.weight == usual.weight && look.brightness == usual.brightness;
}

void SGRSetLyricsTextLook(SGRLyricsText text, SGRLyricsTextLook look) {
    if (!keyOf(text)) return;
    SGRLyricsTextLook usual = SGRLyricsTextLookDefault(text);
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    void (^put)(NSString *, NSInteger, NSInteger) = ^(NSString *part, NSInteger value, NSInteger fallback) {
        if (value == fallback) [store removeObjectForKey:lookKey(text, part)];
        else [store setInteger:value forKey:lookKey(text, part)];
    };
    put(@"scale", look.scale, usual.scale);
    put(@"weight", look.weight, usual.weight);
    if (text != SGRLyricsTextLyrics) put(@"brightness", look.brightness, usual.brightness);
    [NSNotificationCenter.defaultCenter postNotificationName:SGRLyricsTextDidChangeNotification object:nil];
}

UIFontWeight SGRLyricsTextFontWeight(NSInteger weight) {
    return weight <= 0 ? UIFontWeightRegular : weight == 1 ? UIFontWeightSemibold : UIFontWeightBold;
}

NSArray<NSString *> *SGRLyricsTextWeightNames(void) {
    return @[SGL(@"settings.lyricstext.weight.choice.regular", @"Regular"), SGL(@"settings.lyricstext.weight.choice.semibold", @"Semibold"),
             SGL(@"settings.lyricstext.weight.choice.bold", @"Bold")];
}

void SGRSetLyricsTextShown(SGRLyricsText text, BOOL shown) {
    SGSetEnabled(text == SGRLyricsTextTranslation ? SGRKeyLyricsTranslation : SGRKeyLyricsPronunciation, shown);
    [NSNotificationCenter.defaultCenter postNotificationName:SGRLyricsTextDidChangeNotification object:nil];
}
