#import <AVFoundation/AVFoundation.h>
#import "LocalMusicStore.h"
#import "LocalAudioImport.h"
#import "LocalFiles.h"
#import "LocalMusicPlayback.h"

NSNotificationName const SGLocalMusicFilesDidChangeNotification = @"spotifyglass.localFiles.importsDidChange";
NSNotificationName const SGLocalMusicIndexDidChangeNotification = @"spotifyglass.localFiles.indexDidChange";

// This is only the documented metadata identity used by the existing edit store. It is NOT an
// assigned Spotify URI or a playback capability; no URI constructed here is ever sent to the player.
static NSString *metadataIdentity(NSDictionary *tags) {
    NSMutableArray *parts = [NSMutableArray array];
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"];
    for (NSString *key in @[@"artist", @"album", @"title"]) {
        NSString *part = [tags[key] ?: @"" stringByAddingPercentEncodingWithAllowedCharacters:allowed];
        [parts addObject:[part stringByReplacingOccurrencesOfString:@"%20" withString:@"+"]];
    }
    [parts addObject:[tags[@"seconds"] ?: @0 stringValue]];
    return [@"spotify:local:" stringByAppendingString:[parts componentsJoinedByString:@":"]];
}

static NSDictionary *readFile(NSURL *url) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    NSMutableDictionary *tags = [NSMutableDictionary dictionary];
    NSString *artFormat;
    NSNumber *artItem;
    for (NSString *format in asset.availableMetadataFormats) {
        NSArray<AVMetadataItem *> *items = [asset metadataForFormat:format];
        for (NSUInteger index = 0; index < items.count; ++index) {
            AVMetadataItem *item = items[index];
            NSString *common = item.commonKey;
            NSString *identifier = item.identifier;
            NSString *field;
            if ([common isEqual:AVMetadataCommonKeyTitle]) field = @"title";
            else if ([common isEqual:AVMetadataCommonKeyArtist]) field = @"artist";
            else if ([common isEqual:AVMetadataCommonKeyAlbumName]) field = @"album";
            else if ([identifier isEqual:AVMetadataIdentifierID3MetadataBand] ||
                     [identifier isEqual:AVMetadataIdentifieriTunesMetadataAlbumArtist]) field = @"albumArtist";
            else if ([identifier isEqual:AVMetadataIdentifierID3MetadataPartOfASet]) field = @"disc";
            else if ([identifier isEqual:AVMetadataIdentifierID3MetadataTrackNumber]) field = @"track";
            if (field && item.stringValue.length) tags[field] = item.stringValue;
            if ([common isEqual:AVMetadataCommonKeyArtwork] && !artFormat) {
                artFormat = format;
                artItem = @(index);
            }
            // MP4 trkn/disk store big-endian 16-bit ordinal and total after two reserved bytes.
            if ([identifier isEqual:AVMetadataIdentifieriTunesMetadataTrackNumber] ||
                [identifier isEqual:AVMetadataIdentifieriTunesMetadataDiscNumber]) {
                NSData *data = item.dataValue;
                if (data.length >= 4) {
                    const uint8_t *bytes = data.bytes;
                    tags[[identifier isEqual:AVMetadataIdentifieriTunesMetadataTrackNumber] ? @"track" : @"disc"] = @((bytes[2] << 8) | bytes[3]);
                }
            }
        }
    }
    double seconds = CMTimeGetSeconds(asset.duration);
    if (isfinite(seconds) && seconds >= 0) tags[@"seconds"] = @((long long)seconds);
    NSMutableDictionary *result = [@{@"tags": tags} mutableCopy];
    if (artFormat) { result[@"artFormat"] = artFormat; result[@"artItem"] = artItem; }
    return result;
}

@implementation SGLocalMusicStore {
    dispatch_queue_t _queue;
    SGLocalMusicFileCache *_cache;
    NSArray *_observers;
    NSUInteger _generation;
}
+ (instancetype)sharedStore {
    static SGLocalMusicStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ store = [SGLocalMusicStore new]; });
    return store;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _queue = dispatch_queue_create("spotifyglass.localFiles.index", DISPATCH_QUEUE_SERIAL);
    _cache = [SGLocalMusicFileCache new];
    __weak typeof(self) weakSelf = self;
    NSMutableArray *observers = [NSMutableArray array];
    for (NSString *name in @[SGLocalMusicFilesDidChangeNotification, SGLocalFileEditsDidChangeNotification, SGLocalMusicPlaybackDidChangeNotification]) {
        [observers addObject:[NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
            if (NSThread.isMainThread) [weakSelf reload];
            else dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf reload]; });
        }]];
    }
    _observers = observers;
    return self;
}
- (void)dealloc {
    for (id observer in _observers) [NSNotificationCenter.defaultCenter removeObserver:observer];
}
- (void)reload {
    NSUInteger generation = ++_generation;
    dispatch_async(_queue, ^{
        NSURL *folder = SGLocalAudioFolder();
        NSArray *names = SGLocalAudioImportedNames(folder, NSUserDefaults.standardUserDefaults);
        NSMutableDictionary *identities = [NSMutableDictionary dictionary];
        NSMutableArray *songs = [NSMutableArray array];
        for (NSString *name in names) {
            @autoreleasepool {
                NSURL *url = [folder URLByAppendingPathComponent:name];
                NSDictionary *entry = [self->_cache entryForName:name identity:^{ return SGLocalMusicFileIdentity(url); }
                    read:^{ return readFile(url); }];
                if (!entry) continue;
                NSDictionary *file = entry[@"metadata"];
                NSMutableDictionary *tags = [file[@"tags"] mutableCopy];
                if (![tags[@"title"] length]) tags[@"title"] = name.lastPathComponent.stringByDeletingPathExtension;
                NSString *assignedURI = SGLocalMusicVerifiedURI(name, entry[@"identity"]);
                NSString *uri = assignedURI ?: metadataIdentity(tags);
                NSDictionary *edit = SGLocalFileEditFor(uri);
                SGLocalMusicArtworkReference *artwork;
                NSString *coverPath = SGLocalFileCoverPath(edit);
                if (coverPath) {
                    NSURL *coverURL = [NSURL fileURLWithPath:coverPath];
                    NSArray *identity = SGLocalMusicFileIdentity(coverURL);
                    if (identity) artwork = [[SGLocalMusicArtworkReference alloc] initWithURL:coverURL identity:identity format:nil item:0 edited:YES];
                } else if (file[@"artFormat"]) {
                    artwork = [[SGLocalMusicArtworkReference alloc] initWithURL:url identity:entry[@"identity"]
                        format:file[@"artFormat"] item:[file[@"artItem"] unsignedIntegerValue] edited:NO];
                }
                identities[name] = entry[@"identity"];
                SGLocalMusicSong *song = [[SGLocalMusicSong alloc] initWithName:name metadataURI:uri tags:tags edit:edit artwork:artwork];
                song.playbackURI = assignedURI;
                song.fileIdentity = entry[@"identity"];
                [songs addObject:song];
            }
        }
        [self->_cache retainNames:names];
        NSMutableArray *current = [NSMutableArray array];
        for (SGLocalMusicSong *song in songs) {
            if ([identities[song.name] isEqual:SGLocalMusicFileIdentity([folder URLByAppendingPathComponent:song.name])])
                [current addObject:song];
            else [self->_cache invalidateName:song.name];
        }
        SGLocalMusicIndex *index = [[SGLocalMusicIndex alloc] initWithSongs:current];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self->_generation) return;
            self->_index = index;
            [NSNotificationCenter.defaultCenter postNotificationName:SGLocalMusicIndexDidChangeNotification object:self];
        });
    });
}
@end
