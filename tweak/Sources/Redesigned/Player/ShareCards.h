// Share cards (ShareCards.m): the song playing, or a few lines of its lyrics, drawn as an image over its cover
// blurred and handed to the system's share sheet, as the Music app shares lyrics. The player's ⋯ menu shares the
// song's (PlayerMenu.m), and holding a line of the lyrics opens the lines' picker (Redesigned/Lyrics/LyricCardPicker.h).
// Main thread; the drawing itself runs off it, from what the player already holds, with nothing asked of the network.
#import <UIKit/UIKit.h>

// A lyric card has room for this many lines with their pronunciation at a size that still reads.
enum { SGRLyricCardMostLines = 6 };

// A line on a lyric card: its words, its pronunciation (nil where it has none), and whether it reads right to left,
// which sets the side the line and its pronunciation keep to.
@interface SGRLyricCardLine : NSObject
@property (nonatomic, copy) NSString *text, *pronunciation;
@property (nonatomic) BOOL rightToLeft;
@end

// The playing song's card (its cover, title and artist) through the share sheet, anchored on `source` on iPad.
void SGRShareSongCard(UIView *source);
// A card of `lines` of `trackID`'s lyrics (as SGKaraokePlayingTrack names a track), each with its pronunciation
// under it when `pronunciation` is set, through the share sheet presented on `host` from `item`. `done` runs on the
// main thread with whether the image was shared.
void SGRShareLyricCard(NSArray<SGRLyricCardLine *> *lines, BOOL pronunciation, NSString *trackID, UIViewController *host,
                       UIBarButtonItem *item, void (^done)(BOOL shared));
