#import "LocalMusicIndex.h"
#import "LocalFiles.h"

static NSString *text(id value) {
    return [value isKindOfClass:NSString.class] ? [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
}

@interface SGLocalMusicSong ()
@property (nonatomic, readwrite, strong) SGLocalMusicArtworkReference *artwork;
@end
@implementation SGLocalMusicSong
- (instancetype)initWithName:(NSString *)name metadataURI:(NSString *)uri tags:(NSDictionary *)tags edit:(NSDictionary *)edit artwork:(SGLocalMusicArtworkReference *)artwork {
    if (!(self = [super init])) return nil;
    _name = [name copy];
    _metadataURI = [uri copy];
    NSMutableDictionary *values = [(tags.count ? tags : SGLocalFileTags(uri) ?: @{}) mutableCopy];
    for (NSString *field in @[@"title", @"artist", @"album", @"albumArtist"]) {
        if (text(edit[field]).length) values[field] = edit[field];
    }
    _title = text(values[@"title"]);
    if (!_title.length) _title = name.lastPathComponent.stringByDeletingPathExtension;
    _artist = text(values[@"albumArtist"]);
    if (!_artist.length) _artist = text(values[@"artist"]);
    _album = text(values[@"album"]);
    _folder = [name stringByDeletingLastPathComponent];
    if ([_folder isEqual:@"."]) _folder = @"";
    _disc = [values[@"disc"] integerValue];
    _track = [values[@"track"] integerValue];
    _artwork = artwork;
    return self;
}
@end

@interface SGLocalMusicGroup ()
@property (nonatomic, readwrite, copy) NSArray<NSString *> *key;
@property (nonatomic, readwrite, copy) NSString *name, *artist;
@property (nonatomic, readwrite, copy) NSArray<SGLocalMusicSong *> *songs;
@property (nonatomic, readwrite, strong) SGLocalMusicArtworkReference *artwork;
@end
@implementation SGLocalMusicGroup
@end

static NSArray<SGLocalMusicGroup *> *groups(NSArray<SGLocalMusicSong *> *songs, NSString *kind) {
    NSMutableDictionary<NSArray *, NSMutableArray *> *buckets = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSArray *, NSArray *> *labels = [NSMutableDictionary dictionary];
    for (SGLocalMusicSong *song in songs) {
        NSString *name = [kind isEqual:@"artist"] ? song.artist : [kind isEqual:@"album"] ? song.album : song.folder;
        NSArray *key = [kind isEqual:@"album"] ? @[name.lowercaseString, song.artist.lowercaseString] : @[name.lowercaseString];
        if (!buckets[key]) { buckets[key] = [NSMutableArray array]; labels[key] = @[name, song.artist]; }
        [buckets[key] addObject:song];
    }
    NSMutableArray *result = [NSMutableArray array];
    for (NSArray *key in buckets) {
        SGLocalMusicGroup *group = [SGLocalMusicGroup new];
        group.key = key;
        group.name = labels[key][0];
        group.artist = labels[key][1];
        group.songs = [buckets[key] sortedArrayUsingComparator:^NSComparisonResult(SGLocalMusicSong *a, SGLocalMusicSong *b) {
            if ([kind isEqual:@"album"]) {
                if (a.disc != b.disc) return a.disc < b.disc ? NSOrderedAscending : NSOrderedDescending;
                if (a.track != b.track) return a.track < b.track ? NSOrderedAscending : NSOrderedDescending;
            }
            NSComparisonResult order = [a.title localizedStandardCompare:b.title];
            return order == NSOrderedSame ? [a.name compare:b.name] : order;
        }];
        for (SGLocalMusicSong *song in group.songs) if (song.artwork) { group.artwork = song.artwork; break; }
        [result addObject:group];
    }
    return [result sortedArrayUsingComparator:^NSComparisonResult(SGLocalMusicGroup *a, SGLocalMusicGroup *b) {
        NSComparisonResult order = [a.name localizedStandardCompare:b.name];
        return order == NSOrderedSame ? [a.artist localizedStandardCompare:b.artist] : order;
    }];
}

@implementation SGLocalMusicIndex
- (instancetype)initWithSongs:(NSArray<SGLocalMusicSong *> *)songs {
    if (!(self = [super init])) return nil;
    _songs = [songs copy];
    _albums = groups(songs, @"album");
    for (SGLocalMusicGroup *album in _albums) {
        if (!album.name.length) continue;
        SGLocalMusicArtworkReference *shared;
        for (SGLocalMusicSong *song in album.songs) if (song.artwork && !song.artwork.edited) { shared = song.artwork; break; }
        for (SGLocalMusicSong *song in album.songs) if (!song.artwork.edited) song.artwork = shared;
    }
    _artists = groups(songs, @"artist");
    _folders = groups(songs, @"folder");
    return self;
}
- (SGLocalMusicGroup *)artistNamed:(NSString *)name {
    if (!name.length) return nil;
    for (SGLocalMusicGroup *artist in self.artists)
        if ([artist.name caseInsensitiveCompare:name] == NSOrderedSame) return artist;
    return nil;
}
- (NSArray<SGLocalMusicGroup *> *)albumsForArtist:(SGLocalMusicGroup *)artist {
    if (!artist) return @[];
    NSPredicate *match = [NSPredicate predicateWithBlock:^BOOL(SGLocalMusicGroup *album, NSDictionary *bindings) {
        return [album.artist caseInsensitiveCompare:artist.name] == NSOrderedSame;
    }];
    return [self.albums filteredArrayUsingPredicate:match];
}
@end
