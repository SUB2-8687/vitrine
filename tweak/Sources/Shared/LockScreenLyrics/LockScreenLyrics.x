// Spotify's now playing info passes through with the artist swapped for the current line, and a timer
// sends it again each time the line changes. Spotify itself only ever sees its own dictionary back.
//
// The timer runs only while the sound moves, and wakes once for the next time the line can change: the
// next start or end of a line or word the line shown hangs on. While the lyrics or the player's track
// are not in yet it looks four times a second. The lock screen keeps the line it was left on until the
// sound starts again.
#import <MediaPlayer/MediaPlayer.h>
#import <stdatomic.h>
#import "Core/SGCore.h"
#import "LockScreenLyrics.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/LyricsTranslation/LyricsTranslation.h"
#import "Headers/SPTPlayer.h"

// How often to look while the line cannot be worked out yet.
static const NSTimeInterval kTick = 0.25;
// About what the lock screen's artist row fits before it cuts the text off.
static const NSUInteger kMaxChars = 30;

// Spotify may set the info from any thread; the timer reads it on the main one.
static NSObject *sg_lock;
static NSDictionary *sg_spotifyInfo;
static CFAbsoluteTime sg_spotifyInfoAt;
static BOOL sg_refreshPending; // under sg_lock; a background setter burst needs one main refresh
static NSString *sg_shownLine;
static _Thread_local BOOL sg_resending;
static dispatch_source_t sg_timer;
static CFAbsoluteTime sg_due;
static void tick(BOOL force);

// Main-thread publication cache, separate from Romanise's worker-only preparation cache.
static SGKaraokeLine *preparedReading(NSString *track, NSArray<SGKaraokeLine *> *lines, NSInteger index) {
    static NSArray *source, *choices;
    static NSArray<SGLyricsPreparedExtras *> *prepared;
    static NSUInteger generation;
    NSString *language = SGLyricsTrackLanguage(track) ?: SGLyricsDetectedLanguage(lines);
    BOOL hangul = SGFlag(SGKeyLyricsPronunciationHangul, NO), hiragana = SGFlag(SGKeyLyricsJapaneseKana, NO);
    NSArray *key = @[track ?: @"", language ?: @"", @(hangul), @(hiragana)];
    if (source != lines || ![choices isEqual:key]) {
        source = lines;
        choices = key;
        prepared = nil;
        NSUInteger job = ++generation;
        SGLyricsPrepareReadingsAsync(lines, [language isEqual:@"ja"], hangul, hiragana,
                                    ^(NSArray<SGLyricsPreparedExtras *> *result) {
            if (job != generation) return;
            prepared = result;
            [NSNotificationCenter.defaultCenter postNotificationName:SGLyricsReadingsDidChangeNotification object:track];
        });
    }
    return prepared ? prepared[index].pronunciation : nil;
}

SGKaraokeLine *SGLyricsShownLine(NSString *track, NSArray<SGKaraokeLine *> *lines, NSInteger index, SGKaraokeLine **under) {
    if (under) *under = nil;
    if (index < 0 || index >= (NSInteger)lines.count) return nil;
    SGKaraokeLine *line = lines[index];
    BOOL leads = NO;
    SGRLyricsReading shown = SGRLyricsReadingShown(&leads);
    if (shown == SGRLyricsReadingNone) return line;
    SGKaraokeLine *reading = line.pronunciation;
    // Use the same preparation as the lyrics view, without entering its worker cache on main.
    if (!reading && shown == SGRLyricsReadingRomanised) {
        reading = preparedReading(track, lines, index);
    }
    if (!SGKaraokeLineText(reading).length) return line;
    if (under) *under = leads ? line : reading;
    return leads ? reading : line;
}

NSString *SGLyricsShownLineTag(void) {
    BOOL leads = NO;
    SGRLyricsReading shown = SGRLyricsReadingShown(&leads);
    if (shown == SGRLyricsReadingNone) return @"";
    return [NSString stringWithFormat:@"p%ld%d%d%d", (long)shown, leads, SGFlag(SGKeyLyricsPronunciationHangul, NO),
            SGFlag(SGKeyLyricsJapaneseKana, NO)];
}

static NSString *textOf(NSArray<SGKaraokeWord *> *words) {
    SGKaraokeLine *line = [SGKaraokeLine new];
    line.words = words;
    return SGKaraokeLineText(line);
}

// A line longer than the artist row holds, split into even pieces rather than a full one and a stub.
// Each piece shows from its first word's estimated start.
static NSArray<NSArray<SGKaraokeWord *> *> *piecesOf(SGKaraokeLine *line) {
    NSUInteger length = textOf(line.words).length;
    NSUInteger count = MAX((length + kMaxChars - 1) / kMaxChars, 1);
    NSUInteger target = (length + count - 1) / count;
    NSMutableArray<NSArray<SGKaraokeWord *> *> *pieces = [NSMutableArray array];
    NSMutableArray<SGKaraokeWord *> *piece = [NSMutableArray array];
    NSUInteger pieceLength = 0;
    for (SGKaraokeWord *word in line.words) {
        NSUInteger gap = pieceLength && !word.joined ? 1 : 0;
        NSUInteger withWord = pieceLength ? pieceLength + gap + word.text.length : word.text.length;
        if (pieceLength && (withWord > kMaxChars || (withWord > target && pieces.count + 1 < count))) {
            [pieces addObject:piece];
            piece = [NSMutableArray array];
            withWord = word.text.length;
        }
        [piece addObject:word];
        pieceLength = withWord;
    }
    if (piece.count) [pieces addObject:piece];
    return pieces;
}

// A translation has no word timing, so it is split into even pieces too: at spaces, or between characters for
// text without them (CJK).
static NSArray<NSString *> *translationPieces(NSString *text) {
    if (!text.length) return @[];
    NSUInteger count = MAX((text.length + kMaxChars - 1) / kMaxChars, 1);
    if (count == 1) return @[text];
    BOOL unspaced = SGKaraokeUnspacedScript(text);
    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    if (unspaced) {
        [text enumerateSubstringsInRange:NSMakeRange(0, text.length) options:NSStringEnumerationByComposedCharacterSequences
                              usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
            if (substring) [tokens addObject:substring];
        }];
    } else {
        // Split on whitespace rather than by words, so a punctuation mark stays with the word before it.
        NSCharacterSet *spaces = NSCharacterSet.whitespaceAndNewlineCharacterSet;
        for (NSString *token in [text componentsSeparatedByCharactersInSet:spaces]) {
            if (token.length) [tokens addObject:token];
        }
        if (!tokens.count) [tokens addObject:text];
    }
    if (tokens.count <= count) return tokens;
    NSUInteger target = (tokens.count + count - 1) / count;
    NSMutableArray<NSString *> *pieces = [NSMutableArray array];
    NSMutableArray<NSString *> *piece = [NSMutableArray array];
    for (NSString *token in tokens) {
        if (piece.count && piece.count + 1 > target && pieces.count + 1 < count) {
            [pieces addObject:[piece componentsJoinedByString:unspaced ? @"" : @" "]];
            piece = [NSMutableArray array];
        }
        [piece addObject:token];
    }
    if (piece.count) [pieces addObject:[piece componentsJoinedByString:unspaced ? @"" : @" "]];
    return pieces;
}

// Seconds into the track at `now`, run on from what Spotify last reported. A rate it left out runs at 1, as
// playingBy counts it: read as 0, every line written pinned the lock screen's time to Spotify's last report.
static double elapsedAt(NSDictionary *info, CFAbsoluteTime reportedAt, CFAbsoluteTime now) {
    NSNumber *reported = info[MPNowPlayingInfoPropertyPlaybackRate];
    double rate = reported ? reported.doubleValue : 1;
    return [info[MPNowPlayingInfoPropertyElapsedPlaybackTime] doubleValue] + rate * (now - reportedAt);
}

// nil between lines and for a track without synced lyrics, plain text included. Past a line's end by
// SGKaraokeBreakMs, with the next line at least that far off, the artist comes back. With translations on, a
// line that has one shows it instead. `wait` is the playback time in seconds until it can change: kTick while it
// cannot be worked out yet, negative for not again.
static NSString *lineFor(NSDictionary *info, double elapsed, NSTimeInterval *wait) {
    *wait = kTick;
    SPTPlayerState *state = [(id<SPTPlayer>)SGKaraokePlayer() state];
    // The player's track can lag behind the now playing info; its lyrics would then be another song's.
    if (![state.track.trackTitle isEqualToString:info[MPMediaItemPropertyTitle]]) return nil;
    NSString *trackID = SGKaraokePlayingTrack();
    NSArray<SGKaraokeLine *> *lines = SGKaraokeLinesForTrack(trackID);
    if (!lines) {
        SGKaraokeRequestLyrics(trackID);
        return nil;
    }
    *wait = -1;
    // Plain text has no line being sung to show.
    if (SGKaraokeLinesTiming(lines) == SGKaraokeTimingNone) return nil;
    NSInteger position = (NSInteger)(elapsed * 1000) - SGKaraokeDelayMs();
    NSInteger index = SGKaraokeLeadLine(lines, position);
    // The pieces below turn over at the shown line's word starts.
    NSInteger ms = SGKaraokeMsToChange(lines, position, index);
    // A ms on, past the truncation of `position` above.
    if (ms > 0) *wait = (ms + 1) / 1000.0;
    if (index < 0) return nil;
    BOOL nextFarOff = index + 1 == (NSInteger)lines.count || lines[index + 1].start - position > SGKaraokeBreakMs;
    if (position > lines[index].end + SGKaraokeBreakMs && nextFarOff) return nil;
    SGKaraokeLine *current = lines[index];
    BOOL wantTranslation = SGInt(SGKeyLockScreenLyricsLine, SGLockScreenLyricsLineOriginal) == SGLockScreenLyricsLineTranslation;
    // Translations wanted here: asked once a track and language, not every tick. Saved ones are synced first, so
    // a line that has one shows it even when no automatic translation runs.
    static NSString *translatedTrack, *translatedLanguage;
    static NSArray<SGKaraokeLine *> *translatedLines;
    if (wantTranslation) {
        NSString *language = SGLyricsGeminiLanguage();
        // A refined source hands over a new array for the same track: it needs the saved translations too.
        if (![translatedTrack isEqualToString:trackID] || ![translatedLanguage isEqualToString:language] || translatedLines != lines) {
            translatedTrack = trackID;
            translatedLanguage = language;
            translatedLines = lines;
            SGRAutoTranslateWithoutView(trackID, lines, ^BOOL {
                return [trackID isEqualToString:SGKaraokePlayingTrack()]
                    && lines == SGKaraokeLinesForTrack(trackID) && [language isEqual:SGLyricsGeminiLanguage()]
                    && SGInt(SGKeyLockScreenLyricsLine, SGLockScreenLyricsLineOriginal) == SGLockScreenLyricsLineTranslation;
            }, ^{
                sg_shownLine = nil;
                tick(NO);
            });
        }
    } else {
        translatedTrack = nil;
    }
    NSString *shownTranslation = wantTranslation ? SGLyricsShownTranslation(current) : nil;
    if (shownTranslation.length) {
        NSArray<NSString *> *pieces = translationPieces(shownTranslation);
        NSInteger start = current.start, end = MAX(SGKaraokeSungEnd(current), start);
        NSUInteger shownIndex = 0;
        for (NSUInteger i = 0; i < pieces.count; i++) {
            NSInteger boundary = start + (NSInteger)i * (end - start) / (NSInteger)pieces.count;
            if (boundary <= position) shownIndex = i;
            else {
                NSTimeInterval next = (boundary - position + 1) / 1000.0;
                if (*wait < 0 || next < *wait) *wait = next;
                break;
            }
        }
        return pieces[shownIndex];
    }
    // The larger of the line and its pronunciation, as the lyrics show them; the artist row has room for one.
    NSString *shown = nil;
    for (NSArray<SGKaraokeWord *> *piece in piecesOf(SGLyricsShownLine(trackID, lines, index, NULL))) {
        if (!shown || piece.firstObject.start <= position) shown = textOf(piece);
    }
    return shown;
}

// Spotify's info with the line in place of the artist, or its own artist for nil. The clock always moves
// on to `elapsed`: the system takes the elapsed time as now's, so the one Spotify reported a while ago
// would pull the progress bar back.
static NSDictionary *withLine(NSDictionary *info, NSString *line, double elapsed) {
    NSMutableDictionary *shown = [info mutableCopy];
    if (line) shown[MPMediaItemPropertyArtist] = line;
    shown[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(elapsed);
    return shown;
}

// The rate the song's time moves at; 1 for one Spotify left out, as elapsedAt counts it.
static double rateOf(NSDictionary *info) {
    NSNumber *rate = info[MPNowPlayingInfoPropertyPlaybackRate];
    return rate.doubleValue > 0 ? rate.doubleValue : 1;
}

static BOOL playingBy(NSDictionary *info);

// Main thread, as everything the timer touches is. Stops the timer, or arms it to look again `wait`
// seconds of the song's time from now; a negative wait leaves it to Spotify's next info.
static void lookIn(NSTimeInterval wait, NSDictionary *info) {
    if (wait < 0) {
        if (sg_timer) dispatch_source_cancel(sg_timer);
        sg_timer = nil;
        return;
    }
    if (!sg_timer) {
        // A strict GCD timer: the main run loop's timers are throttled while the screen is off, and the lines
        // stood still on a locked phone.
        sg_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, DISPATCH_TIMER_STRICT, dispatch_get_main_queue());
        dispatch_source_set_event_handler(sg_timer, ^{
            static int late;
            CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
            if (now - sg_due > 2 && late++ < 5) SGLog(@"%s: ticked %.1f s late", __FILE_NAME__, now - sg_due);
            tick(NO);
        });
        dispatch_resume(sg_timer);
    }
    NSTimeInterval seconds = wait / rateOf(info);
    sg_due = CFAbsoluteTimeGetCurrent() + seconds;
    dispatch_source_set_timer(sg_timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), DISPATCH_TIME_FOREVER, 10 * NSEC_PER_MSEC);
}

static void tick(BOOL force) {
    NSDictionary *info;
    CFAbsoluteTime reportedAt;
    @synchronized (sg_lock) {
        info = sg_spotifyInfo;
        reportedAt = sg_spotifyInfoAt;
    }
    NSDictionary *shown = info;
    NSString *line = nil;
    NSTimeInterval wait = -1;
    if (info[MPNowPlayingInfoPropertyElapsedPlaybackTime]) {
        double elapsed = elapsedAt(info, reportedAt, CFAbsoluteTimeGetCurrent());
        line = lineFor(info, elapsed, &wait);
        shown = withLine(info, line, elapsed);
    }
    // A queued setter must restore its latest snapshot even when the line is unchanged
    // (including nil), but refreshing a paused or empty snapshot never starts a timer.
    lookIn(playingBy(info) ? wait : -1, info);
    if (!force && (line == sg_shownLine || [line isEqualToString:sg_shownLine])) return;
    sg_shownLine = line;
    sg_resending = YES;
    MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo = shown;
    sg_resending = NO;
}

// Whether the sound is moving. A rate Spotify did not report at all counts as moving: the line would
// stand still either way, and a missing key is no reason to leave the feature switched off for good.
static BOOL playingBy(NSDictionary *info) {
    NSNumber *rate = info[MPNowPlayingInfoPropertyPlaybackRate];
    return !rate || rate.doubleValue > 0;
}

// Looks again at once while the sound moves, for something other than the clock that moves the line.
static void lookNow(void) {
    NSDictionary *info;
    @synchronized (sg_lock) {
        info = sg_spotifyInfo;
    }
    if (playingBy(info) && info[MPNowPlayingInfoPropertyElapsedPlaybackTime]) lookIn(0, info);
}

%hook MPNowPlayingInfoCenter
- (void)setNowPlayingInfo:(NSDictionary *)info {
    if (sg_resending) {
        %orig;
        return;
    }
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    BOOL needsRefresh = !NSThread.isMainThread || !info[MPNowPlayingInfoPropertyElapsedPlaybackTime];
    BOOL enqueueRefresh = NO;
    @synchronized (sg_lock) {
        sg_spotifyInfo = info;
        sg_spotifyInfoAt = now;
        if (needsRefresh && !sg_refreshPending) {
            sg_refreshPending = YES;
            enqueueRefresh = YES;
        }
    }
    BOOL playing = playingBy(info) && info[MPNowPlayingInfoPropertyElapsedPlaybackTime] != nil;
    // Karaoke's lyrics are main-thread state. Restore the latest snapshot on main even
    // when paused: an older tick may have republished its own snapshot after this setter.
    if (needsRefresh) {
        if (enqueueRefresh) dispatch_async(dispatch_get_main_queue(), ^{
            @synchronized (sg_lock) { sg_refreshPending = NO; }
            tick(YES);
        });
        %orig;
        return;
    }
    double elapsed = elapsedAt(info, now, now);
    NSTimeInterval wait;
    NSString *line = lineFor(info, elapsed, &wait);
    lookIn(playing ? wait : -1, info);
    sg_shownLine = line;
    %orig(withLine(info, line, elapsed));
}

- (NSDictionary *)nowPlayingInfo {
    NSDictionary *info;
    @synchronized (sg_lock) {
        info = sg_spotifyInfo;
    }
    return info ?: %orig;
}
%end

%ctor {
    if (!SGFlag(SGKeyLockScreenLyrics, NO)) return;
    sg_lock = [NSObject new];
    %init;
    // A translation saved while the player is paused has no tick to pick it up (Shared/LyricsTranslation).
    // Heard on the writing thread and handed to main without waiting (AGENTS.md).
    for (NSNotificationName name in @[SGLyricsTranslationSavedNotification, SGLyricsTranslationsDidChangeNotification]) {
    [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil
                                                usingBlock:^(NSNotification *note) {
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL saved = [note.name isEqual:SGLyricsTranslationSavedNotification];
            NSString *track = saved ? note.object : SGKaraokePlayingTrack();
            if (![track isEqualToString:SGKaraokePlayingTrack()]
                || (saved && ![note.userInfo[@"language"] isEqual:SGLyricsGeminiLanguage()])
                || SGInt(SGKeyLockScreenLyricsLine, SGLockScreenLyricsLineOriginal) != SGLockScreenLyricsLineTranslation) return;
            NSString *language = SGLyricsGeminiLanguage();
            NSArray *lines = SGKaraokeLinesForTrack(track);
            SGLyricsLoadTranslation(track, language, lines, ^BOOL {
                return [track isEqual:SGKaraokePlayingTrack()] && [language isEqual:SGLyricsGeminiLanguage()]
                    && lines == SGKaraokeLinesForTrack(track)
                    && SGInt(SGKeyLockScreenLyricsLine, SGLockScreenLyricsLineOriginal) == SGLockScreenLyricsLineTranslation;
            }, ^{
                sg_shownLine = nil;
                tick(NO);
            });
        });
    }];
    }
    // Lines kept for a track, or replaced by better timed ones, can change the line at once.
    for (NSNotificationName name in @[SGKaraokeLinesKeptNotification, SGLyricsReadingsDidChangeNotification,
                                      SGLyricsLanguageDidChangeNotification]) {
    [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
        if (!note.object || [note.object isEqual:SGKaraokePlayingTrack()]) tick(NO);
    }];
    }
    // The lyrics' delay applies at once, and moves the next change. Every write in the app posts this, so it is
    // compared on the writing thread and handed to main without waiting only when it moved (AGENTS.md).
    static _Atomic NSInteger delay;
    atomic_store(&delay, SGKaraokeDelayMs());
    // So does the lyrics' choice of pronunciation (SGLyricsShownLine), paused or not.
    static NSString *shownTag;
    shownTag = SGLyricsShownLineTag();
    [NSNotificationCenter.defaultCenter addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:nil
                                                usingBlock:^(NSNotification *note) {
        SGPrefsChanged();
        NSString *tag = SGLyricsShownLineTag();
        BOOL retagged;
        @synchronized (sg_lock) {
            retagged = ![tag isEqualToString:shownTag];
            shownTag = tag;
        }
        NSInteger now = SGKaraokeDelayMs();
        BOOL moved = atomic_exchange(&delay, now) != now;
        if (retagged) dispatch_async(dispatch_get_main_queue(), ^{ tick(NO); });
        else if (moved) dispatch_async(dispatch_get_main_queue(), ^{ lookNow(); });
    }];
    // The timer waits for Spotify to report a playing track; nothing before that has a line to show.
    SGLog(@"lock screen lyrics: on");
}
