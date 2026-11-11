// Whether a song a catalog offers is the track playing, for the searches that answer with whole songs
// and no id to match on: Genius's (Genius.m, LyricsMeanings/Meanings.m) and LRCLIB's (LrcLib.m). Genius's
// search is here too, since both of its askers share it.
#import "Core/SGCore.h"
#import "LyricsSources.h"

NSString *SGLyricsMatchKey(NSString *text) {
    static NSCharacterSet *dropped;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *building = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
        [building formUnionWithCharacterSet:NSCharacterSet.punctuationCharacterSet];
        [building formUnionWithCharacterSet:NSCharacterSet.symbolCharacterSet];
        dropped = [building copy];
    });
    if (![text isKindOfClass:NSString.class]) return @"";
    return [[text.lowercaseString componentsSeparatedByCharactersInSet:dropped] componentsJoinedByString:@""];
}

NSString *SGLyricsFoldedText(NSString *text) {
    static NSCharacterSet *kept;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ kept = NSCharacterSet.alphanumericCharacterSet; });
    NSString *plain = [text stringByFoldingWithOptions:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch | NSWidthInsensitiveSearch
                                                locale:nil];
    NSMutableString *out = [NSMutableString stringWithCapacity:plain.length];
    BOOL space = NO;
    for (NSUInteger i = 0; i < plain.length; i++) {
        unichar c = [plain characterAtIndex:i];
        if (c == '\'' || c == 0x2019 || c == 0x2018 || c == '`') continue;
        if ([kept characterIsMember:c]) {
            if (space && out.length) [out appendString:@" "];
            space = NO;
            [out appendFormat:@"%C", c];
        } else {
            space = YES;
        }
    }
    return out;
}

NSString *SGLyricsBareTitle(NSString *title) {
    return SGLyricsBareTitleWithOptions(title, NO);
}

NSString *SGLyricsBareTitleWithOptions(NSString *title, BOOL soundtrackOnly) {
    NSString *bare = title ?: @"";
    if (soundtrackOnly) {
        static NSRegularExpression *soundtrack;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSString *quoted = @"(?:\"[^\"]+\"|“[^”]+”|'[^']+'|‘[^’]+’)";
            NSString *tail = @"(?:(?!\\s[-–—]\\s)[^)\\]])*";
            NSString *annotation = [NSString stringWithFormat:@"(?:from\\s+(?:%@|the\\s+(?:motion\\s+picture|film|movie|series)\\b%@)|(?:original\\s+)?(?:motion\\s+picture\\s+)?soundtrack\\b%@|ost\\b%@)", quoted, tail, tail, tail];
            NSString *pattern = [NSString stringWithFormat:@"(?i)\\s*(?:[\\(\\[]\\s*%@\\s*[\\)\\]]|\\s[-–—]\\s*%@(?=\\s[-–—]\\s|$)|\\s+from\\s+%@(?=\\s[-–—]\\s|$)|\\s+OST$)", annotation, annotation, quoted];
            soundtrack = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        });
        if (![soundtrack numberOfMatchesInString:bare options:0 range:NSMakeRange(0, bare.length)]) return title;
        bare = [soundtrack stringByReplacingMatchesInString:bare options:0 range:NSMakeRange(0, bare.length) withTemplate:@""];
        bare = [bare stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        return bare.length ? bare : title;
    }
    NSRange dash = [bare rangeOfString:@" - "];
    if (dash.location != NSNotFound) bare = [bare substringToIndex:dash.location];
    static NSRegularExpression *brackets;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ brackets = [NSRegularExpression regularExpressionWithPattern:@"\\s*[\\(\\[][^\\)\\]]*[\\)\\]]" options:0 error:nil]; });
    bare = [brackets stringByReplacingMatchesInString:bare options:0 range:NSMakeRange(0, bare.length) withTemplate:@""];
    return [bare stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

// What a title says beyond the song's name: "Old Town Road - Remix" is {remix}, "Blinding Lights (Live)" {live}.
static NSSet<NSString *> *versionOf(NSString *title) {
    NSMutableSet<NSString *> *words = [NSMutableSet setWithArray:[SGLyricsFoldedText(title) componentsSeparatedByString:@" "]];
    [words minusSet:[NSSet setWithArray:[SGLyricsFoldedText(SGLyricsBareTitle(title)) componentsSeparatedByString:@" "]]];
    [words removeObject:@""];
    return words;
}

// The track's title without Spotify's "(feat. Billy Ray Cyrus)" or "(with Diplo)": who sings with the lead
// is not which recording it is. A catalog's titles keep theirs, so a version of its own with a guest stays apart.
static NSString *withoutGuests(NSString *title) {
    static NSRegularExpression *guests;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        guests = [NSRegularExpression regularExpressionWithPattern:@"\\s*[\\(\\[](feat\\.?|ft\\.?|featuring|with)\\s[^\\)\\]]*[\\)\\]]"
                                                            options:NSRegularExpressionCaseInsensitive error:nil];
    });
    return [guests stringByReplacingMatchesInString:title options:0 range:NSMakeRange(0, title.length) withTemplate:@""];
}

NSSet<NSString *> *SGLyricsTitleVersion(NSString *title) {
    return versionOf(withoutGuests(title ?: @""));
}

// Spotify joins a track's artists with ", ", which a name can hold too ("Tyler, The Creator"), so the
// lead artist is any run of the first names; a local file's tag may name the lead before " feat." instead.
static NSSet<NSString *> *leadNames(NSString *artist) {
    NSMutableSet<NSString *> *names = [NSMutableSet setWithObject:SGLyricsFoldedText(SGLyricsLeadArtist(artist))];
    NSString *run = @"";
    for (NSString *part in [artist componentsSeparatedByString:@", "]) {
        run = run.length ? [run stringByAppendingFormat:@" %@", SGLyricsFoldedText(part)] : SGLyricsFoldedText(part);
        if (run.length) [names addObject:run];
    }
    return names;
}

// A catalog writes several artists as one name, joined by punctuation ("A & B", "A/B", "A; B", "A, B") or a
// word ("A and B", "A x B"), in either order; LRCLIB has every one of these. Lowercase " x " only: " X " ends
// Lil Nas X.
static NSArray<NSString *> *namesJoinedIn(NSString *name) {
    NSMutableString *split = [name mutableCopy];
    for (NSString *joiner in @[@"&", @"/", @";", @"+", @"•", @",", @" and ", @" with ", @" vs ", @" vs. "]) {
        [split replaceOccurrencesOfString:joiner withString:@"\n" options:NSCaseInsensitiveSearch range:NSMakeRange(0, split.length)];
    }
    [split replaceOccurrencesOfString:@" x " withString:@"\n" options:0 range:NSMakeRange(0, split.length)];
    return [split componentsSeparatedByString:@"\n"];
}

// Whether one of the song's own artists is the track's lead, by either name of one written twice over
// ("BTS (방탄소년단)", "Дора (Dora)"), by the name before its " feat.", or by one of the names joined in it;
// a featured singer or a translation page's "Genius English Translations" never is.
static BOOL byLead(NSArray<NSString *> *songArtists, NSSet<NSString *> *leads) {
    for (NSString *name in songArtists) {
        if (![name isKindOfClass:NSString.class]) continue;
        NSArray<NSString *> *parts = [name componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"()"]];
        parts = [parts arrayByAddingObjectsFromArray:@[name, SGLyricsLeadArtist(name)]];
        for (NSString *part in [parts arrayByAddingObjectsFromArray:namesJoinedIn(name)]) {
            if ([leads containsObject:SGLyricsFoldedText(part)]) return YES;
        }
    }
    return NO;
}

NSInteger SGLyricsSongRank(NSString *title, NSString *artist, NSString *songTitle, NSArray<NSString *> *songArtists) {
    if (!title.length || !artist.length || ![songTitle isKindOfClass:NSString.class]) return 0;
    NSString *wantTitle = SGLyricsFoldedText(SGLyricsBareTitle(title));
    if (!wantTitle.length || ![SGLyricsFoldedText(SGLyricsBareTitle(songTitle)) isEqualToString:wantTitle]) return 0;
    if (!byLead(songArtists, leadNames(artist))) return 0;
    NSSet<NSString *> *version = versionOf(songTitle);
    return [version isEqualToSet:SGLyricsTitleVersion(title)] ? 3 : version.count == 0 ? 2 : 1;
}

// The provider matcher allows catalog aliases and joined credits, unlike the stricter song rank above.
// Short names may touch either edge, but never match only inside an unrelated name.
BOOL SGLyricsSameArtist(NSString *credited, NSString *artist) {
    NSString *name = SGLyricsMatchKey(credited), *lead = SGLyricsMatchKey(SGLyricsLeadArtist(artist));
    if (!name.length || !lead.length) return NO;
    NSString *shorter = name.length < lead.length ? name : lead;
    NSString *longer = name.length < lead.length ? lead : name;
    if (shorter.length >= 4) return [longer containsString:shorter];
    if ([longer hasPrefix:shorter] || [longer hasSuffix:shorter]) return YES;
    // A middle credit or parenthesized alias is explicit, not an interior substring.
    NSString *credit = name.length < lead.length ? SGLyricsLeadArtist(artist) : credited;
    for (NSString *component in namesJoinedIn(credit)) {
        NSArray *parts = [component componentsSeparatedByCharactersInSet:
            [NSCharacterSet characterSetWithCharactersInString:@"()（）、"]];
        for (NSString *part in parts)
            if ([SGLyricsMatchKey(part) isEqualToString:shorter]) return YES;
    }
    return NO;
}

static NSString *stringIn(id value) {
    return [value isKindOfClass:NSString.class] ? value : nil;
}

NSDictionary<NSString *, NSString *> *SGGeniusSearchQuery(NSString *title, NSString *artist) {
    return @{@"q": [NSString stringWithFormat:@"%@ %@", SGLyricsBareTitle(title), artist], @"per_page": @"10"};
}

NSNumber *SGGeniusSongIn(NSDictionary *response, NSString *title, NSString *artist) {
    if (![response isKindOfClass:NSDictionary.class] || !title.length || !artist.length) return nil;
    // Genius files a song's words under the song; a track with none sung would get them anyway.
    NSSet<NSString *> *version = SGLyricsTitleVersion(title);
    if ([version containsObject:@"instrumental"] || [version containsObject:@"karaoke"]) return nil;
    // Best first: the same version, then the plain song, then any other version of it.
    NSNumber *best = nil;
    NSInteger bestRank = 0;
    id sections = response[@"sections"];
    for (NSDictionary *section in [sections isKindOfClass:NSArray.class] ? sections : @[]) {
        id hits = [section isKindOfClass:NSDictionary.class] ? section[@"hits"] : nil;
        for (NSDictionary *hit in [hits isKindOfClass:NSArray.class] ? hits : @[]) {
            NSDictionary *song = [hit isKindOfClass:NSDictionary.class] ? hit[@"result"] : nil;
            if (![song isKindOfClass:NSDictionary.class] || ![song[@"id"] isKindOfClass:NSNumber.class]) continue;
            if ([song[@"instrumental"] isEqual:@YES]) continue;
            NSMutableArray<NSString *> *names = [NSMutableArray array];
            id primaries = song[@"primary_artists"];
            for (NSDictionary *primary in [primaries isKindOfClass:NSArray.class] ? primaries : @[]) {
                NSString *name = [primary isKindOfClass:NSDictionary.class] ? stringIn(primary[@"name"]) : nil;
                if (name) [names addObject:name];
            }
            NSInteger rank = SGLyricsSongRank(title, artist, stringIn(song[@"title"]), names);
            if (rank > bestRank) {
                best = song[@"id"];
                bestRank = rank;
            }
        }
    }
    return best;
}
