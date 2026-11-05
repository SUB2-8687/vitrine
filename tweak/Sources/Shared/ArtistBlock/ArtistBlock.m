#import "ArtistBlock.h"
#import "Headers/SPTPlayer.h"
#import "Shared/Player/PlayerState.h"

NSString *const SGArtistURI = @"uri";
NSString *const SGArtistName = @"name";
NSString *const SGBlockedSongsDidChangeNotification = @"SGBlockedSongsDidChange";
static NSString *const kSongListKey = @"spotifyglass.blockedSongs";

NSDictionary<NSString *, NSArray<NSString *> *> *SGBlockedSongs(void) {
    return [NSUserDefaults.standardUserDefaults dictionaryForKey:kSongListKey] ?: @{};
}

BOOL SGSongBlocked(NSString *uri) {
    return uri.length && SGBlockedSongs()[uri] != nil;
}

void SGSetSongBlocked(NSString *uri, NSString *title, NSString *artist, BOOL blocked) {
    if (![uri hasPrefix:@"spotify:track:"] || uri.length <= @"spotify:track:".length) return;
    if (SGSongBlocked(uri) == blocked) return;
    NSMutableDictionary *songs = [SGBlockedSongs() mutableCopy];
    if (blocked) songs[uri] = @[title.length ? title : uri, artist ?: @""];
    else [songs removeObjectForKey:uri];
    [NSUserDefaults.standardUserDefaults setObject:songs forKey:kSongListKey];
    [NSNotificationCenter.defaultCenter postNotificationName:SGBlockedSongsDidChangeNotification object:uri];
}

static const NSInteger kMaxCredits = 32;

NSArray<NSDictionary *> *SGBlockedArtists(void) {
    NSArray *list = [NSUserDefaults.standardUserDefaults arrayForKey:SGKeyArtistBlockList];
    return list ?: @[];
}

static void save(NSArray<NSDictionary *> *list) {
    [NSUserDefaults.standardUserDefaults setObject:list forKey:SGKeyArtistBlockList];
}

BOOL SGArtistBlocked(NSString *uri) {
    if (!uri.length) return NO;
    for (NSDictionary *artist in SGBlockedArtists()) {
        if ([artist[SGArtistURI] isEqualToString:uri]) return YES;
    }
    return NO;
}

void SGBlockArtist(NSDictionary *artist) {
    if (SGArtistBlocked(artist[SGArtistURI])) return;
    save([SGBlockedArtists() arrayByAddingObject:artist]);
}

void SGUnblockArtist(NSString *uri) {
    NSPredicate *other = [NSPredicate predicateWithBlock:^BOOL(NSDictionary *artist, NSDictionary *bindings) {
        return ![artist[SGArtistURI] isEqualToString:uri];
    }];
    save([SGBlockedArtists() filteredArrayUsingPredicate:other]);
}

static void addArtist(NSMutableArray<NSDictionary *> *artists, NSString *uri, NSString *name) {
    if (![uri hasPrefix:@"spotify:artist:"]) return;
    for (NSDictionary *artist in artists) {
        if ([artist[SGArtistURI] isEqualToString:uri]) return;
    }
    [artists addObject:@{SGArtistURI: uri, SGArtistName: name.length ? name : uri}];
}

static NSString *nameString(id value) {
    return [value isKindOfClass:NSString.class] ? value : nil;
}

NSArray<NSDictionary *> *SGArtistsOfTrack(id object) {
    if (![object respondsToSelector:@selector(artistURI)] || ![object respondsToSelector:@selector(metadata)]) return @[];
    SPTPlayerTrack *track = object;
    NSDictionary *metadata = [track.metadata isKindOfClass:NSDictionary.class] ? track.metadata : nil;
    NSMutableArray<NSDictionary *> *artists = [NSMutableArray array];
    addArtist(artists, SGURIString(track.artistURI), nameString(track.artistName));
    addArtist(artists, SGURIString(metadata[@"artist_uri"]), nameString(metadata[@"artist_name"]));
    for (NSInteger i = 1; i < kMaxCredits; i++) {
        NSString *uri = SGURIString(metadata[[NSString stringWithFormat:@"artist_uri:%ld", (long)i]]);
        if (!uri) break;
        addArtist(artists, uri, nameString(metadata[[NSString stringWithFormat:@"artist_name:%ld", (long)i]]));
    }
    return artists;
}
