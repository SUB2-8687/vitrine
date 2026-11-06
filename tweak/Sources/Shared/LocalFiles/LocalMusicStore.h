#import "LocalMusicIndex.h"

// Import/delete callers post on main after the existing operation completes.
extern NSNotificationName const SGLocalMusicFilesDidChangeNotification;
extern NSNotificationName const SGLocalMusicIndexDidChangeNotification;

@interface SGLocalMusicStore : NSObject
@property (nonatomic, readonly, strong) SGLocalMusicIndex *index;
+ (instancetype)sharedStore;
// Main-thread entry; enumeration, tags, artwork references and grouping run on a serial worker.
- (void)reload;
@end
