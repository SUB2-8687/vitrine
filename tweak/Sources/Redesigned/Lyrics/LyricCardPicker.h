// The lyric card's picker (LyricCardPicker.m): the song's lines in a sheet, up to SGRLyricCardMostLines of them
// picked, with or without their pronunciation, and shared as a card (Redesigned/Player/ShareCards.h).
#import "Redesigned/Player/ShareCards.h"

// Opens the picker over the top controller with `lines` of `trackID`'s lyrics, the line at `picked` already picked
// (NSNotFound for none). `pronunciation` is whether the card starts with the pronunciation shown. Main thread.
void SGRPresentLyricCardPicker(NSArray<SGRLyricCardLine *> *lines, NSUInteger picked, BOOL pronunciation, NSString *trackID);
