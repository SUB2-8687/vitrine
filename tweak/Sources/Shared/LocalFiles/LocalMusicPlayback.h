#import "LocalMusicIndex.h"

extern NSNotificationName const SGLocalMusicPlaybackDidChangeNotification;
BOOL SGLocalMusicSupportsVersion(NSString *version);
NSString *SGLocalMusicFailureMessage(NSError *error);
BOOL SGLocalMusicObservationContract(Class stateClass, Class trackClass);

// Captures a file identity once per Spotify track load, before any queued work.
@interface SGLocalMusicObservations : NSObject
- (NSDictionary *)captureURI:(NSString *)uri path:(NSString *)path playbackID:(id)playbackID
                readIdentity:(NSArray *(^)(void))readIdentity;
- (NSDictionary *)verifiedObservation:(NSDictionary *)observation currentIdentity:(NSArray *)identity;
@end

BOOL SGLocalMusicPlaybackAvailable(void);
NSString *SGLocalMusicVerifiedURI(NSString *name, NSArray *identity);
BOOL SGLocalMusicCanPlaySongs(NSArray<SGLocalMusicSong *> *songs);
// Main-thread commands. Queue operations deliberately accept exactly one song.
void SGLocalMusicPlay(NSArray<SGLocalMusicSong *> *songs, BOOL shuffle, void (^done)(NSError *));
void SGLocalMusicQueue(SGLocalMusicSong *song, BOOL next, void (^done)(NSError *));
