#import "../shared/redesigned-page-stubs.m"

// Shared/Fonts/FontImport.m: no font of the user's own in the harness.
NSString *SGRegisterCustomFont(void) { return nil; }

// MotionSources.m: Apple Music is on, as it is by default.
BOOL SGMotionAppleMusicOn(void) { return YES; }

// ListeningStats.x: the album's play counts read a log of the harness's own, in its temporary folder.
#import "Shared/ListeningStats/SGPlayLog.h"
SGPlayLog *SGListeningLog(void) {
    static SGPlayLog *log;
    if (!log) log = [[SGPlayLog alloc] initWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"plays.tsv"]];
    return log;
}

// Shared/AlbumQueue/AlbumQueueMenu.x: the ⋯ menu's album queue is a part of a native menu, not of the page.
void SGAlbumQueueMarkSource(UIView *view) {}

// Redesigned/Album/AlbumPlaysMenu.x: a track's plays in its ⋯ menu belong to the native menu, not to the page.
void SGRAlbumPlaysMarkMenu(NSString *album, NSString *title) {}
#import "Redesigned/Album/AlbumSpotifyCounts.h"
void SGRAlbumPlaysMarkSpotifyMenu(NSString *trackURI, SGRAlbumCountPage *page) {}
void SGSpotifyMetadataRequest(NSString *path, NSData *body, SGSpotifyMetadataReply done) {
    NSLog(@"[harness] unexpected Spotify network request");
    exit(1);
}

// SGPageStyle.m: the cover viewer is presented over whatever is on top of the harness's window.
UIViewController *SGTopController(void) {
    UIWindowScene *scene = (UIWindowScene *)UIApplication.sharedApplication.connectedScenes.anyObject;
    UIViewController *top = scene.windows.firstObject.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    return top;
}
