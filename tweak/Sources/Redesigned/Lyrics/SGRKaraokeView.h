// The redesign's Apple Music style lyrics view, always on, over Spotify's full screen lyrics page
// (KaraokePage.x) and in the redesigned player itself (Redesigned/Player/PlayerLyrics.x). A track
// without synced lyrics keeps Spotify's own lines, where there are any next to it. The lines and the
// clock are Shared/Lyrics/Lyrics.h's.
//
// A player view takes the whole of whatever it is put in and dims every other view in there while it
// has lines to show, so a host it shares with anything else needs a view of its own for it. Sample
// previews leave their siblings alone.
#import <UIKit/UIKit.h>
#import "Shared/Lyrics/Lyrics.h"
#import "LyricsLook.h"

@interface SGRKaraokeView : UIView
// The Lyrics page's preview: `lines` played on a clock of its own, round and round every `length` ms, in
// the look the page sets. It takes no touches and asks nothing of the player, the sources, Genius or Sing.
- (instancetype)initWithSampleLines:(NSArray<SGKaraokeLine *> *)lines length:(NSInteger)length;
// Workshop comparison cards only: nil follows the stored style, as every ordinary preview does.
// Ignored on a player view. Never changes the stored choice.
@property (nonatomic, copy) NSString *sampleStyleIdentifier;
// Hides Spotify's own lyrics next to this view while it has lyrics to show, and brings them back when not.
- (void)syncSiblings;
// Called as a finger starts to scroll the lines, for a host that hides its controls then.
@property (nonatomic, copy) void (^browsingBegan)(void);
// The pronunciation and translation button goes with the host's controls when they are hidden, and Sing's
// mic with it unless keepsSing is set.
@property (nonatomic) BOOL extrasHidden;
// The mic stays when the extras go, for a host that lets it take its own touches while its controls are
// hidden (the player's lines on their own, Redesigned/Player/PlayerLyrics.x), so Sing is always in reach.
@property (nonatomic) BOOL keepsSing;
// The place it shows in: its words take the size chosen for that place (LyricsLook.h), and follow a change of it at
// once. SGRLyricsPlaceNone, the look's size, until set.
@property (nonatomic) SGRLyricsPlace sizePlace;
@end

// What sharing a held line says: the line, then "— <title> · <artist>" on the next line, and the song's public
// link on the one after that only while the lyrics are the playing song's own and it is not a local file's.
// A missing title or artist drops it, and with no title the second line goes too. No timestamp.
NSString *SGRLyricsShareText(NSString *line, NSString *title, NSString *artist, NSString *trackID, BOOL playing);
