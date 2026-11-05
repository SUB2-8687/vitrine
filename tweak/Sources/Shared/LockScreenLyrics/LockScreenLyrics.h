// The line being sung in place of the artist in the system's now playing: lock screen, Dynamic Island,
// Control Center, CarPlay. There is a Live Activity for it too (Shared/LiveActivity). The
// lines and the clock come from Karaoke.
#import <Foundation/Foundation.h>

#define SGKeyLockScreenLyrics @"spotifyglass.lockScreenLyrics"
// Which line the artist row shows, as the index of SGKeyLockScreenLyricsLine choices: 0 the original,
// 1 the translation where the line has one. Read on each tick.
#define SGKeyLockScreenLyricsLine @"spotifyglass.lockScreenLyrics.line"
typedef NS_ENUM(NSInteger, SGLockScreenLyricsLine) {
    SGLockScreenLyricsLineOriginal = 0,
    SGLockScreenLyricsLineTranslation,
};

// Automatic translation for a reader with no lyrics view on screen (the lock screen), on the main queue; declared
// here and defined high, in Redesigned/Lyrics/AutoTranslation.m (AGENTS.md, Where code goes). The lyrics view's
// conditions and ledger: no new request unless automatic translation is on, the song is one to translate (another
// language than SGLyricsGeminiLanguage(), or Translate any song, and its language rule allows translation), a
// service is available, and no job for the track and language runs or was tried this session. The saved
// translation is synced onto `lines` first, even with automatic translation off; the translations made go into
// `lines`, are saved and are posted to the lyrics views as theirs are. No view or foreground is required.
// `mayContinue` is asked before each service is started, NO to stop (an answer already on its way is still saved).
@class SGKaraokeLine;
void SGRAutoTranslateWithoutView(NSString *track, NSArray<SGKaraokeLine *> *lines, BOOL (^mayContinue)(void), void (^loaded)(void));
// What the redesign's lyrics show of a line besides its words, for the readers with no lyrics view (the artist row
// here, the lyric artwork, the Live Activity); declared here and defined high, in Redesigned/Lyrics/LyricsText.m. None
// in the native look, whose lyrics show no pronunciation. `leads`: the Lyrics page's order sets the pronunciation
// larger than the words. Any thread.
typedef NS_ENUM(NSInteger, SGRLyricsReading) {
    SGRLyricsReadingNone,
    SGRLyricsReadingSource,      // the source's own, where a line has one (the lyrics menu's Show Pronunciation)
    SGRLyricsReadingRomanised,   // the source's, else the reading in the alphabet chosen (Romanized lyrics)
};
SGRLyricsReading SGRLyricsReadingShown(BOOL *leads);
// Line `index` of `lines`, the lyrics of `track`, as those readers show it, by the lyrics view's own rule: while it shows
// a pronunciation for the line, the larger of the two (the words, or the pronunciation where the order leads with it),
// and in `under` the other; else the line, `under` nil. nil out of range. Main thread.
SGKaraokeLine *SGLyricsShownLine(NSString *track, NSArray<SGKaraokeLine *> *lines, NSInteger index, SGKaraokeLine **under);
// The choice above as a short tag, "" while no pronunciation shows: what those readers draw of every line changes with
// it. Any thread.
NSString *SGLyricsShownLineTag(void);
// Moving artwork with lyrics: the moving artwork clip found for the track `uri`, a local file, which
// LyricsArtwork.x draws the lines over while that track plays. Main queue.
void SGLyricsArtworkSetMotion(NSString *uri, NSURL *file);
