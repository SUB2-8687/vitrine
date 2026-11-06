#import <UIKit/UIKit.h>
#import "LocalMusicCache.h"

@interface SGLocalMusicSong : NSObject
@property (nonatomic, readonly, copy) NSString *name, *metadataURI, *title, *artist, *album, *folder;
@property (nonatomic, readonly) NSInteger disc, track;
@property (nonatomic, readonly, strong) SGLocalMusicArtworkReference *artwork;
// Attached by the store before publication, from Spotify's observed file identity.
@property (nonatomic, copy) NSString *playbackURI;
@property (nonatomic, copy) NSArray *fileIdentity;
// metadataURI is an edit/cover lookup identity, never evidence that Spotify can play a file.
- (instancetype)initWithName:(NSString *)name metadataURI:(NSString *)uri
                       tags:(NSDictionary *)tags edit:(NSDictionary *)edit artwork:(SGLocalMusicArtworkReference *)artwork;
@end

@interface SGLocalMusicGroup : NSObject
@property (nonatomic, readonly, copy) NSArray<NSString *> *key;
@property (nonatomic, readonly, copy) NSString *name, *artist;
@property (nonatomic, readonly, copy) NSArray<SGLocalMusicSong *> *songs;
@property (nonatomic, readonly, strong) SGLocalMusicArtworkReference *artwork;
@end

@interface SGLocalMusicIndex : NSObject
@property (nonatomic, readonly, copy) NSArray<SGLocalMusicSong *> *songs;
@property (nonatomic, readonly, copy) NSArray<SGLocalMusicGroup *> *artists, *albums, *folders;
- (instancetype)initWithSongs:(NSArray<SGLocalMusicSong *> *)songs;
- (SGLocalMusicGroup *)artistNamed:(NSString *)name;
- (NSArray<SGLocalMusicGroup *> *)albumsForArtist:(SGLocalMusicGroup *)artist;
@end
