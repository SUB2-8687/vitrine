// A line in the Latin alphabet, offline, by Apple's own transforms (ICU's under them). Japanese goes
// through the tokenizer's Latin transcription, which reads kanji the Japanese way: Any-Latin alone
// reads them as Mandarin (君の名前 as "jūnno míng qián" instead of "kimi no namae"). Pinyin keeps its
// tone marks; every other script is brought down to plain ASCII, which reads better sung along to
// than ICU's scholarly marks (Greek "Kalēméra", Thai "s̄wạs̄dī").
//
// ponytail: ICU transliterates rather than reads aloud: Arabic and Hebrew come out as their consonants
// ("mrhba"), Thai in ISO 11940's spelling rather than the one signs use, and a line mixing Latin with
// another script loses the Latin part's accents ("Café" as "Cafe"). A reading per language is the upgrade.
#import "Lyrics.h"

NSNotificationName const SGLyricsRomanisedDidChangeNotification = @"spotifyglass.lyricsRomanisedDidChange";

typedef NS_ENUM(NSUInteger, SGScript) { SGScriptKana, SGScriptNotLatin, SGScriptHan, SGScriptHiragana };

// Compiled once: every line on the page is looked at.
static BOOL has(NSString *text, SGScript script) {
    static NSRegularExpression *patterns[4];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray<NSString *> *sources = @[@"[\\p{Hiragana}\\p{Katakana}]", @"[\\p{L}&&[^\\p{Latin}]]", @"\\p{Han}", @"\\p{Hiragana}"];
        for (NSUInteger i = 0; i < 4; i++) patterns[i] = [NSRegularExpression regularExpressionWithPattern:sources[i] options:0 error:NULL];
    });
    return [patterns[script] rangeOfFirstMatchInString:text options:0 range:NSMakeRange(0, text.length)].location != NSNotFound;
}

static BOOL hasKana(NSString *text) {
    return has(text, SGScriptKana);
}

BOOL SGLyricsLooksJapanese(NSArray<SGKaraokeLine *> *lines) {
    for (SGKaraokeLine *line in lines) {
        if (hasKana(SGKaraokeLineText(line))) return YES;
    }
    return NO;
}

// The tokenizer's reading of each word, a space between words; what it has no reading for (punctuation,
// another script) is kept for the transform after it. In hiragana mode only words holding Han take a
// reading; kana, spaces and punctuation stay as written, including を rather than its Latin reading wo.
static NSString *readJapanese(NSString *text, BOOL hiragana) {
    NSMutableString *read = [NSMutableString string];
    CFLocaleRef japanese = CFLocaleCreate(NULL, CFSTR("ja"));
    CFStringTokenizerRef words = CFStringTokenizerCreate(NULL, (__bridge CFStringRef)text, CFRangeMake(0, text.length),
                                                         kCFStringTokenizerUnitWord, japanese);
    NSUInteger from = 0;
    while (CFStringTokenizerAdvanceToNextToken(words) != kCFStringTokenizerTokenNone) {
        CFRange range = CFStringTokenizerGetCurrentTokenRange(words);
        NSString *between = [text substringWithRange:NSMakeRange(from, range.location - from)];
        NSString *word = [text substringWithRange:NSMakeRange(range.location, range.length)];
        if (!hiragana || has(word, SGScriptHan)) {
            NSString *latin = CFBridgingRelease(CFStringTokenizerCopyCurrentTokenAttribute(words, kCFStringTokenizerAttributeLatinTranscription));
            word = (hiragana ? [latin stringByApplyingTransform:@"Latin-Hiragana" reverse:NO] : latin) ?: word;
        }
        if (!hiragana && read.length && !between.length) [read appendString:@" "];
        [read appendString:between];
        [read appendString:word];
        from = range.location + range.length;
    }
    [read appendString:[text substringFromIndex:from]];
    CFRelease(words);
    CFRelease(japanese);
    return read;
}

static const NSUInteger SGReadingMaximumInputUTF16Units = 4000;
// Every tokenizer/transform input stays bounded, without cutting a surrogate or combining sequence.
// A single grapheme larger than the budget is passed through unchanged, never fed to ICU.
static void readingSegments(NSString *text, void (^each)(NSRange range)) {
    NSUInteger from = 0;
    while (from < text.length) {
        NSUInteger end = from + MIN(SGReadingMaximumInputUTF16Units, text.length - from);
        NSRange last = [text rangeOfComposedCharacterSequenceAtIndex:end - 1];
        if (NSMaxRange(last) > end) end = last.location > from ? last.location : NSMaxRange(last);
        each(NSMakeRange(from, end - from));
        from = end;
    }
}
// Unicode Hangul syllable composition: initial × 21 vowels × 28 finals.
static const unichar SGHangulFirstSyllable = 0xAC00;
static const NSUInteger SGHangulVowelCount = 21, SGHangulFinalCount = 28;
static const NSUInteger SGHangulInitialCount = 19, SGHangulSilentInitial = 11;

static BOOL hangulSyllable(unichar c) {
    return c >= SGHangulFirstSyllable &&
        c < SGHangulFirstSyllable + SGHangulInitialCount * SGHangulVowelCount * SGHangulFinalCount;
}

static NSString *kanaHangul(NSString *text) {
    static NSDictionary<NSString *, NSString *> *syllables;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        syllables = @{
            @"あ":@"아", @"い":@"이", @"う":@"우", @"え":@"에", @"お":@"오",
            @"か":@"카", @"き":@"키", @"く":@"쿠", @"け":@"케", @"こ":@"코",
            @"さ":@"사", @"し":@"시", @"す":@"스", @"せ":@"세", @"そ":@"소",
            @"た":@"타", @"ち":@"치", @"つ":@"츠", @"て":@"테", @"と":@"토",
            @"な":@"나", @"に":@"니", @"ぬ":@"누", @"ね":@"네", @"の":@"노",
            @"は":@"하", @"ひ":@"히", @"ふ":@"후", @"へ":@"헤", @"ほ":@"호",
            @"ま":@"마", @"み":@"미", @"む":@"무", @"め":@"메", @"も":@"모",
            @"や":@"야", @"ゆ":@"유", @"よ":@"요",
            @"ら":@"라", @"り":@"리", @"る":@"루", @"れ":@"레", @"ろ":@"로",
            @"わ":@"와", @"ゐ":@"이", @"ゑ":@"에", @"を":@"오",
            @"が":@"가", @"ぎ":@"기", @"ぐ":@"구", @"げ":@"게", @"ご":@"고",
            @"ざ":@"자", @"じ":@"지", @"ず":@"즈", @"ぜ":@"제", @"ぞ":@"조",
            @"だ":@"다", @"ぢ":@"지", @"づ":@"즈", @"で":@"데", @"ど":@"도",
            @"ば":@"바", @"び":@"비", @"ぶ":@"부", @"べ":@"베", @"ぼ":@"보",
            @"ぱ":@"파", @"ぴ":@"피", @"ぷ":@"푸", @"ぺ":@"페", @"ぽ":@"포", @"ゔ":@"부",
            @"ぁ":@"아", @"ぃ":@"이", @"ぅ":@"우", @"ぇ":@"에", @"ぉ":@"오",
            @"ゃ":@"야", @"ゅ":@"유", @"ょ":@"요", @"ゎ":@"와", @"ゕ":@"카", @"ゖ":@"케",
            @"きゃ":@"캬", @"きゅ":@"큐", @"きょ":@"쿄", @"きぇ":@"켸",
            @"ぎゃ":@"갸", @"ぎゅ":@"규", @"ぎょ":@"교", @"ぎぇ":@"계",
            @"しゃ":@"샤", @"しゅ":@"슈", @"しょ":@"쇼", @"しぇ":@"셰",
            @"じゃ":@"자", @"じゅ":@"주", @"じょ":@"조", @"じぇ":@"제",
            @"ちゃ":@"차", @"ちゅ":@"추", @"ちょ":@"초", @"ちぇ":@"체",
            @"ぢゃ":@"자", @"ぢゅ":@"주", @"ぢょ":@"조", @"ぢぇ":@"제",
            @"にゃ":@"냐", @"にゅ":@"뉴", @"にょ":@"뇨", @"にぇ":@"녜",
            @"ひゃ":@"햐", @"ひゅ":@"휴", @"ひょ":@"효", @"ひぇ":@"혜",
            @"びゃ":@"뱌", @"びゅ":@"뷰", @"びょ":@"뵤", @"びぇ":@"볘",
            @"ぴゃ":@"퍄", @"ぴゅ":@"퓨", @"ぴょ":@"표", @"ぴぇ":@"폐",
            @"みゃ":@"먀", @"みゅ":@"뮤", @"みょ":@"묘", @"みぇ":@"몌",
            @"りゃ":@"랴", @"りゅ":@"류", @"りょ":@"료", @"りぇ":@"례",
            @"ふぁ":@"파", @"ふぃ":@"피", @"ふぇ":@"페", @"ふぉ":@"포", @"ふゅ":@"퓨",
            @"てぃ":@"티", @"てゅ":@"튜", @"とぅ":@"투",
            @"でぃ":@"디", @"でゅ":@"듀", @"どぅ":@"두",
            @"うぃ":@"위", @"うぇ":@"웨", @"うぉ":@"워", @"いぇ":@"예",
            @"くぁ":@"콰", @"くぃ":@"퀴", @"くぇ":@"퀘", @"くぉ":@"쿼", @"くゎ":@"콰",
            @"ぐぁ":@"과", @"ぐぃ":@"귀", @"ぐぇ":@"궤", @"ぐぉ":@"궈", @"ぐゎ":@"과",
            @"つぁ":@"차", @"つぃ":@"치", @"つぇ":@"체", @"つぉ":@"초",
            @"すぃ":@"시", @"ずぃ":@"지",
            @"ゔぁ":@"바", @"ゔぃ":@"비", @"ゔぇ":@"베", @"ゔぉ":@"보", @"ゔゅ":@"뷰"
        };
    });
    NSString *kana = [[text stringByApplyingTransform:@"Katakana-Hiragana" reverse:NO] precomposedStringWithCanonicalMapping];
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < kana.length; i++) {
        unichar c = [kana characterAtIndex:i];
        unichar previous = out.length ? [out characterAtIndex:out.length - 1] : 0;
        if (c == L'っ' || c == L'ん') {
            // No assimilation: ん is always ㄴ; small tsu is always final ㅅ.
            NSUInteger final = c == L'っ' ? 19 : 4;
            if (hangulSyllable(previous) && (previous - SGHangulFirstSyllable) % SGHangulFinalCount == 0) {
                unichar closed = previous + final;
                [out replaceCharactersInRange:NSMakeRange(out.length - 1, 1) withString:[NSString stringWithCharacters:&closed length:1]];
            } else {
                [out appendString:c == L'っ' ? @"ㅅ" : @"ㄴ"];
            }
            continue;
        }
        if (c == L'ー' && hangulSyllable(previous)) {
            // The vowel alone, not the y/w glide (ショー -> 쇼오).
            NSString *vowels = @"아애아애어에어에오아애에오우어에이우으이이";
            NSUInteger vowel = (previous - SGHangulFirstSyllable) / SGHangulFinalCount % SGHangulVowelCount;
            [out appendString:[vowels substringWithRange:NSMakeRange(vowel, 1)]];
            continue;
        }
        NSString *mapped = i + 1 < kana.length ? syllables[[kana substringWithRange:NSMakeRange(i, 2)]] : nil;
        if (mapped) i++;
        else mapped = syllables[[kana substringWithRange:NSMakeRange(i, 1)]];
        [out appendString:mapped ?: [kana substringWithRange:NSMakeRange(i, 1)]];
    }
    return out;
}

// Korean orthography's Chinese initial/final table. Keep ü distinct from u while removing tones.
static NSString *pinyinHangul(NSString *syllable) {
    static NSDictionary<NSString *, NSNumber *> *initials;
    static NSDictionary<NSString *, NSString *> *finals, *standalone;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        initials = @{@"b":@7, @"p":@17, @"m":@6, @"f":@17, @"d":@3, @"t":@16, @"n":@2, @"l":@5,
                     @"g":@0, @"k":@15, @"h":@18, @"j":@12, @"q":@14, @"x":@9,
                     @"zh":@12, @"ch":@14, @"sh":@9, @"r":@5, @"z":@13, @"c":@14, @"s":@10};
        finals = @{@"a":@"아", @"o":@"오", @"e":@"어", @"ê":@"에", @"i":@"이", @"u":@"우", @"ü":@"위",
                   @"ai":@"아이", @"ei":@"에이", @"ao":@"아오", @"ou":@"어우",
                   @"an":@"안", @"en":@"언", @"ang":@"앙", @"eng":@"엉", @"er":@"얼",
                   @"ia":@"야", @"ie":@"예", @"iao":@"야오", @"iu":@"유", @"iou":@"유",
                   @"ian":@"옌", @"in":@"인", @"iang":@"양", @"ing":@"잉",
                   @"ua":@"와", @"uo":@"워", @"uai":@"와이", @"ui":@"우이",
                   @"uan":@"완", @"un":@"운", @"uang":@"왕", @"ong":@"웅",
                   @"üe":@"웨", @"üan":@"위안", @"ün":@"윈", @"iong":@"융"};
        standalone = @{@"yi":@"이", @"ya":@"야", @"yo":@"요", @"ye":@"예", @"yai":@"야이",
                       @"yao":@"야오", @"you":@"유", @"yan":@"옌", @"yin":@"인", @"yang":@"양", @"ying":@"잉",
                       @"wu":@"우", @"wa":@"와", @"wo":@"워", @"wai":@"와이", @"wei":@"웨이",
                       @"wan":@"완", @"wen":@"원", @"wang":@"왕", @"weng":@"웡",
                       @"yu":@"위", @"yue":@"웨", @"yuan":@"위안", @"yun":@"윈", @"yong":@"융", @"r":@"얼"};
    });
    NSMutableString *plain = [NSMutableString string];
    NSString *decomposed = syllable.lowercaseString.decomposedStringWithCanonicalMapping;
    for (NSUInteger i = 0; i < decomposed.length; i++) {
        unichar c = [decomposed characterAtIndex:i];
        if (c == 0x0304 || c == 0x0301 || c == 0x030C || c == 0x0300) continue;
        [plain appendFormat:@"%C", c];
    }
    NSString *pinyin = plain.precomposedStringWithCanonicalMapping;
    if (standalone[pinyin]) return standalone[pinyin];
    NSString *initial = pinyin.length >= 2 && initials[[pinyin substringToIndex:2]] ? [pinyin substringToIndex:2] :
        pinyin.length && initials[[pinyin substringToIndex:1]] ? [pinyin substringToIndex:1] : @"";
    NSString *final = [pinyin substringFromIndex:initial.length];
    if (([initial isEqual:@"j"] || [initial isEqual:@"q"] || [initial isEqual:@"x"]) && [final hasPrefix:@"u"])
        final = [@"ü" stringByAppendingString:[final substringFromIndex:1]];
    NSString *reading = finals[final];
    if ([final isEqual:@"i"] && [@[@"zh", @"ch", @"sh", @"r", @"z", @"c", @"s"] containsObject:initial]) reading = @"으";
    if (!reading) return pinyin;
    if (!initial.length) return reading;
    NSUInteger onset = initials[initial].unsignedIntegerValue;
    unichar first = [reading characterAtIndex:0];
    NSUInteger vowel = (first - SGHangulFirstSyllable) / SGHangulFinalCount % SGHangulVowelCount;
    // After ㅈ/ㅉ/ㅊ, the table writes ㅑ/ㅖ/ㅛ/ㅠ as ㅏ/ㅔ/ㅗ/ㅜ.
    if (onset == 12 || onset == 13 || onset == 14) {
        if (vowel == 2 || vowel == 7 || vowel == 12 || vowel == 17) {
            NSUInteger plainVowel = vowel == 2 ? 0 : vowel == 7 ? 5 : vowel == 12 ? 8 : 13;
            first -= (vowel - plainVowel) * SGHangulFinalCount;
        }
    }
    first = first - SGHangulSilentInitial * SGHangulVowelCount * SGHangulFinalCount +
        onset * SGHangulVowelCount * SGHangulFinalCount;
    return [[NSString stringWithCharacters:&first length:1] stringByAppendingString:[reading substringFromIndex:1]];
}

// Transform only the source script's runs: an English word that happens to spell pinyin must not
// become Hangul, and any other script keeps the existing Latin transform.
static NSString *hangulReading(NSString *text, BOOL japanese) {
    static NSRegularExpression *kanaRuns, *hanRuns, *pinyinWords;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        kanaRuns = [NSRegularExpression regularExpressionWithPattern:@"[\\p{Hiragana}\\p{Katakana}ー][\\p{Hiragana}\\p{Katakana}ー\\p{M}]*" options:0 error:NULL];
        hanRuns = [NSRegularExpression regularExpressionWithPattern:@"\\p{Han}+" options:0 error:NULL];
        pinyinWords = [NSRegularExpression regularExpressionWithPattern:@"[\\p{L}\\p{M}]+" options:0 error:NULL];
    });
    NSString *source = japanese ? readJapanese(text, YES) : text;
    NSRegularExpression *runs = japanese ? kanaRuns : hanRuns;
    NSMutableString *out = [NSMutableString string];
    NSUInteger from = 0;
    for (NSTextCheckingResult *match in [runs matchesInString:source options:0 range:NSMakeRange(0, source.length)]) {
        NSString *between = [source substringWithRange:NSMakeRange(from, match.range.location - from)];
        [out appendString:[between stringByApplyingTransform:@"Any-Latin; Latin-ASCII" reverse:NO] ?: between];
        NSString *run = [source substringWithRange:match.range];
        if (japanese) {
            [out appendString:kanaHangul(run)];
        } else {
            NSString *latin = [run stringByApplyingTransform:(__bridge NSString *)kCFStringTransformMandarinLatin reverse:NO] ?: run;
            NSMutableString *reading = [latin mutableCopy];
            for (NSTextCheckingResult *word in [[pinyinWords matchesInString:latin options:0 range:NSMakeRange(0, latin.length)] reverseObjectEnumerator])
                [reading replaceCharactersInRange:word.range withString:pinyinHangul([latin substringWithRange:word.range])];
            [out appendString:reading];
        }
        from = NSMaxRange(match.range);
    }
    NSString *tail = [source substringFromIndex:from];
    [out appendString:[tail stringByApplyingTransform:@"Any-Latin; Latin-ASCII" reverse:NO] ?: tail];
    return [out stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

static NSString *romanisedWith(NSString *text, BOOL japanese, BOOL wantsHangul, BOOL wantsHiragana) {
    if (!text.length) return nil;
    if (text.length > SGReadingMaximumInputUTF16Units) {
        NSMutableString *whole = [NSMutableString string];
        __block BOOL changed = NO;
        BOOL kana = japanese || hasKana(text);
        readingSegments(text, ^(NSRange range) {
            NSString *part = [text substringWithRange:range];
            NSString *reading = part.length <= SGReadingMaximumInputUTF16Units ?
                romanisedWith(part, kana, wantsHangul, wantsHiragana) : nil;
            changed |= reading != nil;
            if (!reading) { [whole appendString:part]; return; }
            // The short-line transform trims its edges. Preserve separators between segments.
            NSUInteger head = 0, tail = part.length;
            NSCharacterSet *space = NSCharacterSet.whitespaceAndNewlineCharacterSet;
            while (head < tail && [space characterIsMember:[part characterAtIndex:head]]) head++;
            while (tail > head && [space characterIsMember:[part characterAtIndex:tail - 1]]) tail--;
            [whole appendString:[part substringToIndex:head]];
            [whole appendString:reading];
            [whole appendString:[part substringFromIndex:tail]];
        });
        return changed ? [whole stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : nil;
    }
    static NSCache<NSString *, NSString *> *kept;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ kept = [NSCache new]; kept.countLimit = 1000; });
    BOOL hangul = wantsHangul &&
        (japanese || hasKana(text) || has(text, SGScriptHan));
    BOOL hiragana = !wantsHangul && japanese && wantsHiragana;
    NSString *mode = hangul ? (japanese || hasKana(text) ? @"hangul-ja" : @"hangul-zh") :
        hiragana ? @"hiragana" : japanese ? @"ja" : @"latin";
    NSString *key = [NSString stringWithFormat:@"%@:%@", mode, text];
    NSString *romanised = [kept objectForKey:key];
    if (romanised) return romanised.length ? romanised : nil;
    // Cache Latin-only misses as well as readings.
    if (!has(text, SGScriptNotLatin)) {
        [kept setObject:@"" forKey:key];
        return nil;
    }
    if (hangul) {
        romanised = hangulReading(text, japanese || hasKana(text));
        if ([romanised caseInsensitiveCompare:text] == NSOrderedSame) romanised = @"";
        [kept setObject:romanised forKey:key];
        return romanised.length ? romanised : nil;
    }
    if (hiragana) {
        romanised = readJapanese(text, YES);
        if ([romanised isEqualToString:text]) romanised = @"";
        [kept setObject:romanised forKey:key];
        return romanised.length ? romanised : nil;
    }
    BOOL kana = japanese || hasKana(text);
    NSString *source = kana ? readJapanese(text, NO) : text;
    // Han left over is Chinese: its pinyin keeps the tones, and only its punctuation is made ASCII.
    NSString *transform = !kana && has(text, SGScriptHan) ? @"Any-Latin; [[:P:][:Zs:]] Latin-ASCII" : @"Any-Latin; Latin-ASCII";
    romanised = [[source stringByApplyingTransform:transform reverse:NO]
                 stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] ?: @"";
    if ([romanised caseInsensitiveCompare:text] == NSOrderedSame) romanised = @"";
    [kept setObject:romanised forKey:key];
    return romanised.length ? romanised : nil;
}

NSString *SGLyricsRomanised(NSString *text, BOOL japanese) {
    return romanisedWith(text, japanese,
        [NSUserDefaults.standardUserDefaults boolForKey:SGKeyLyricsPronunciationHangul],
        [NSUserDefaults.standardUserDefaults boolForKey:SGKeyLyricsJapaneseKana]);
}

@implementation SGLyricsRuby
@end

NSArray<SGLyricsRuby *> *SGLyricsFurigana(NSString *text) {
    if (!text.length) return @[];
    if (text.length > SGReadingMaximumInputUTF16Units) {
        NSMutableArray *whole = [NSMutableArray array];
        readingSegments(text, ^(NSRange range) {
            if (range.length > SGReadingMaximumInputUTF16Units) return;
            for (SGLyricsRuby *part in SGLyricsFurigana([text substringWithRange:range])) {
                SGLyricsRuby *ruby = [SGLyricsRuby new];
                ruby.range = NSMakeRange(range.location + part.range.location, part.range.length);
                ruby.reading = part.reading;
                [whole addObject:ruby];
            }
        });
        return [whole copy];
    }
    static NSCache<NSString *, NSArray<SGLyricsRuby *> *> *kept;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ kept = [NSCache new]; kept.countLimit = 1000; });
    NSArray *cached = [kept objectForKey:text];
    if (cached) return cached;
    NSMutableArray *runs = [NSMutableArray array];
    CFLocaleRef japanese = CFLocaleCreate(NULL, CFSTR("ja"));
    CFStringTokenizerRef words = CFStringTokenizerCreate(NULL, (__bridge CFStringRef)text, CFRangeMake(0, text.length),
                                                         kCFStringTokenizerUnitWord, japanese);
    while (CFStringTokenizerAdvanceToNextToken(words) != kCFStringTokenizerTokenNone) {
        CFRange token = CFStringTokenizerGetCurrentTokenRange(words);
        NSRange range = NSMakeRange(token.location, token.length);
        NSString *word = [text substringWithRange:range];
        if (!has(word, SGScriptHan)) continue;
        NSString *latin = CFBridgingRelease(CFStringTokenizerCopyCurrentTokenAttribute(words, kCFStringTokenizerAttributeLatinTranscription));
        NSString *reading = [latin stringByApplyingTransform:@"Latin-Hiragana" reverse:NO];
        if (!reading.length || !has(reading, SGScriptHiragana)) continue;
        // Compare kana in hiragana so a katakana affix can be trimmed too. Han never shares a
        // character with the reading, so these bounds cannot cut into the kanji's pronunciation.
        NSString *kana = [word stringByApplyingTransform:@"Katakana-Hiragana" reverse:NO];
        NSUInteger head = 0, tail = 0;
        while (head < kana.length && head < reading.length &&
               [kana characterAtIndex:head] == [reading characterAtIndex:head] &&
               hasKana([kana substringWithRange:NSMakeRange(head, 1)])) head++;
        while (tail < kana.length - head && tail < reading.length - head &&
               [kana characterAtIndex:kana.length - tail - 1] == [reading characterAtIndex:reading.length - tail - 1] &&
               hasKana([kana substringWithRange:NSMakeRange(kana.length - tail - 1, 1)])) tail++;
        // Some compound readings cannot be divided this way. Keep the token whole in that case.
        if (head + tail < reading.length && kana.length == word.length) {
            range.location += head;
            range.length -= head + tail;
            reading = [reading substringWithRange:NSMakeRange(head, reading.length - head - tail)];
        }
        SGLyricsRuby *ruby = [SGLyricsRuby new];
        ruby.range = range;
        ruby.reading = reading;
        [runs addObject:ruby];
    }
    CFRelease(words);
    CFRelease(japanese);
    NSArray *answer = [runs copy];
    [kept setObject:answer forKey:text];
    return answer;
}

@implementation SGLyricsPreparedExtras
- (instancetype)initWithPronunciation:(SGKaraokeLine *)pronunciation ranges:(NSArray<NSValue *> *)ranges
                          wordRanges:(NSArray<NSValue *> *)wordRanges ruby:(NSArray<SGLyricsRuby *> *)ruby {
    if ((self = [super init])) {
        _pronunciation = pronunciation;
        _sourceRanges = [ranges copy];
        _wordRanges = [wordRanges copy];
        _ruby = [ruby copy];
    }
    return self;
}
@end

NSNotificationName const SGLyricsReadingsDidChangeNotification = @"spotifyglass.lyrics.readingsDidChange";

void SGLyricsPrepareReadingsAsync(NSArray<SGKaraokeLine *> *lines, BOOL japanese, BOOL hangul, BOOL hiragana,
                                 void (^completion)(NSArray<SGLyricsPreparedExtras *> *extras)) {
    NSMutableArray *snapshot = [NSMutableArray arrayWithCapacity:lines.count];
    for (SGKaraokeLine *line in lines) [snapshot addObject:[line copy]];
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("spotifyglass.lyrics.readings", DISPATCH_QUEUE_SERIAL); });
    dispatch_async(queue, ^{
        NSMutableArray *prepared = [NSMutableArray arrayWithCapacity:snapshot.count];
        for (SGKaraokeLine *line in snapshot)
            [prepared addObject:SGLyricsPrepareExtras(line, japanese, hangul, hiragana, YES, NO)];
        NSArray *result = [prepared copy];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(result); });
    });
}

SGLyricsPreparedExtras *SGLyricsPrepareExtras(SGKaraokeLine *line, BOOL japanese, BOOL hangul,
                                             BOOL hiragana, BOOL pronunciation, BOOL ruby) {
    static NSCache *kept;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ kept = [NSCache new]; kept.countLimit = 1000; });
    NSString *text = SGKaraokeLineText(line) ?: @"";
    NSMutableArray *clocks = [NSMutableArray array];
    NSMutableArray<NSValue *> *wordRanges = [NSMutableArray array];
    NSUInteger offset = 0;
    for (SGKaraokeWord *word in line.words) {
        if (offset && !word.joined) offset++;
        [wordRanges addObject:[NSValue valueWithRange:NSMakeRange(offset, word.text.length)]];
        offset += word.text.length;
        [clocks addObject:@[word.text ?: @"", @(word.start), @(word.end), @(word.joined)]];
    }
    NSArray *key = @[clocks, @(line.start), @(line.end), @(line.timing), @(line.align),
                     @(japanese), @(hangul), @(hiragana), @(pronunciation), @(ruby)];
    // Only workers enter this section. Coalesce cold requests from the player and full-screen view.
    @synchronized (kept) {
        SGLyricsPreparedExtras *cached = [kept objectForKey:key];
        if (cached) return cached;
        NSMutableArray<SGKaraokeWord *> *spoken = [NSMutableArray array];
        NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
        __block BOOL changed = NO;
        __block NSUInteger lastSource = NSNotFound;
        BOOL kana = japanese || hasKana(text);
        void (^append)(NSRange, NSString *, BOOL) = ^(NSRange range, NSString *reading, BOOL gap) {
            NSString *original = [text substringWithRange:range];
            if (![original stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length) return;
            if (!reading.length) reading = romanisedWith(original, kana, hangul, hiragana) ?: original;
            changed |= ![original isEqualToString:reading];
            SGKaraokeWord *word = [SGKaraokeWord new];
            word.text = reading;
            word.joined = spoken.count && (gap || (kana && (hangul || hiragana))) &&
                NSMaxRange(ranges.lastObject.rangeValue) == range.location;
            BOOL anchored = NO;
            NSUInteger firstSource = NSNotFound, untilSource = NSNotFound;
            for (NSUInteger i = 0; i < wordRanges.count; i++) {
                if (!NSIntersectionRange(range, wordRanges[i].rangeValue).length) continue;
                if (firstSource == NSNotFound) firstSource = i;
                untilSource = i;
                SGKaraokeWord *source = line.words[i];
                if (!anchored) { word.start = source.start; word.end = source.end; anchored = YES; }
                else { word.start = MIN(word.start, source.start); word.end = MAX(word.end, source.end); }
            }
            if (!anchored) return;
            // A provider word is the finest clock we own. Tokens within that word share one
            // reading word rather than inventing sub-word times or duplicate sweep knots.
            if (spoken.count && firstSource <= lastSource) {
                SGKaraokeWord *previous = spoken.lastObject;
                previous.text = [NSString stringWithFormat:@"%@%@%@", previous.text, word.joined ? @"" : @" ", word.text];
                previous.start = MIN(previous.start, word.start);
                previous.end = MAX(previous.end, word.end);
                ranges[ranges.count - 1] = [NSValue valueWithRange:NSUnionRange(ranges.lastObject.rangeValue, range)];
                lastSource = untilSource;
                return;
            }
            lastSource = untilSource;
            [spoken addObject:word];
            [ranges addObject:[NSValue valueWithRange:range]];
        };
        if (pronunciation && has(text, SGScriptNotLatin)) {
            CFLocaleRef locale = CFLocaleCreate(NULL, kana ? CFSTR("ja") : CFSTR("und"));
            readingSegments(text, ^(NSRange segmentRange) {
                NSString *segment = [text substringWithRange:segmentRange];
                if (segment.length > SGReadingMaximumInputUTF16Units) {
                    append(segmentRange, segment, YES);
                    return;
                }
                CFStringTokenizerRef tokenizer = CFStringTokenizerCreate(NULL, (__bridge CFStringRef)segment,
                    CFRangeMake(0, segment.length), kCFStringTokenizerUnitWord, locale);
                NSUInteger from = segmentRange.location;
                while (CFStringTokenizerAdvanceToNextToken(tokenizer) != kCFStringTokenizerTokenNone) {
                    CFRange token = CFStringTokenizerGetCurrentTokenRange(tokenizer);
                    NSRange local = [segment rangeOfComposedCharacterSequencesForRange:NSMakeRange(token.location, token.length)];
                    NSRange range = NSMakeRange(segmentRange.location + local.location, local.length);
                    if (NSMaxRange(range) <= from) continue;
                    if (range.location < from) range = NSMakeRange(from, NSMaxRange(range) - from);
                    if (range.location > from) append(NSMakeRange(from, range.location - from), nil, YES);
                    NSString *original = [text substringWithRange:range], *reading = nil;
                    if (kana && (hasKana(original) || has(original, SGScriptHan))) {
                        NSString *latin = CFBridgingRelease(CFStringTokenizerCopyCurrentTokenAttribute(tokenizer,
                            kCFStringTokenizerAttributeLatinTranscription));
                        if (hangul) reading = kanaHangul([latin stringByApplyingTransform:@"Latin-Hiragana" reverse:NO] ?: original);
                        else if (hiragana) reading = has(original, SGScriptHan) ?
                            [latin stringByApplyingTransform:@"Latin-Hiragana" reverse:NO] : original;
                        else reading = [latin stringByApplyingTransform:@"Latin-ASCII" reverse:NO];
                    }
                    append(range, reading, segmentRange.location > 0 && range.location == segmentRange.location);
                    from = NSMaxRange(range);
                }
                if (from < NSMaxRange(segmentRange)) append(NSMakeRange(from, NSMaxRange(segmentRange) - from), nil, YES);
                CFRelease(tokenizer);
            });
            CFRelease(locale);
        }
        SGKaraokeLine *reading = nil;
        if (changed && spoken.count) {
            reading = [SGKaraokeLine new];
            reading.words = spoken;
            reading.start = line.start;
            reading.end = line.end;
            reading.timing = line.timing;
            reading.align = line.align;
        }
        SGLyricsPreparedExtras *result = [[SGLyricsPreparedExtras alloc] initWithPronunciation:reading
            ranges:reading ? ranges : @[] wordRanges:wordRanges ruby:ruby ? SGLyricsFurigana(text) : @[]];
        [kept setObject:result forKey:key];
        return result;
    }
}
