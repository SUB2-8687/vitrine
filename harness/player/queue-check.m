#import <UIKit/UIKit.h>
#import "Core/SGCore.h"
#import "Shared/Player/PlayerState.h"
#import "Redesigned/Player/PlayerMix.h"
#import "Redesigned/Kit/SGRKit.h"
#import "../harness-fail.h"

@implementation SPTPlayerTrack
@end
@implementation SPTPlayerState
@end
@interface QueueTrack : SPTPlayerTrack
@property NSString *UID;
@end
@implementation QueueTrack
@end
@interface QueueState : SPTPlayerState
@property NSString *queueRevision;
@property NSString *playbackId;
@end
@implementation QueueState
@end
@interface QueueSnapshot : NSObject
@property SPTPlayerTrack *track;
@property NSArray *prevTracks;
@property NSArray *nextTracks;
@end
@implementation QueueSnapshot
@end
@interface QueuePlayer : NSObject
@property QueueSnapshot *currentQueue;
@property BOOL withoutQueueAPI;
@end
@implementation QueuePlayer
- (BOOL)respondsToSelector:(SEL)selector {
    if (selector == @selector(fetchQueue:on:) && self.withoutQueueAPI) return NO;
    return [super respondsToSelector:selector];
}
- (void)fetchQueue:(void (^)(id))callback on:(dispatch_queue_t)queue { callback(self.currentQueue); }
- (id)skipToNextTrackWithOptions:(id)options track:(SPTPlayerTrack *)track {
    self.currentQueue.track = track; return nil;
}
- (id)skipToPreviousTrackWithOptions:(id)options track:(SPTPlayerTrack *)track {
    self.currentQueue.track = track; return nil;
}
@end

static QueueState *state;
static QueuePlayer *player;
static NSHashTable *observers;
static UITableViewController *screen;
static UIWindow *window;
static int checked;
SPTPlayerState *SGPlayerState(void) { return state; }
id SGPlayerInstance(void) { return player; }
void SGAddPlayerStateObserver(id<SGPlayerStateObserver> observer) {
    if (!observers) observers = [NSHashTable weakObjectsHashTable];
    [observers addObject:observer];
}
NSString *SGURIString(id uri) { return [uri isKindOfClass:NSURL.class] ? [uri absoluteString] : uri; }
NSArray *SGPlayerUpcomingTracks(SPTPlayerState *value, NSUInteger limit) { return value.future ?: @[]; }
NSString *SGL(NSString *key, NSString *english) { return english; }
void SGPresentDark(UIViewController *controller) { controller.overrideUserInterfaceStyle = UIUserInterfaceStyleDark; }
UIViewController *SGTopController(void) { return window.rootViewController; }
UIColor *SGRPrimary(void) { return UIColor.whiteColor; }
UIColor *SGRSecondary(void) { return UIColor.grayColor; }
const CGFloat SGRGrid = 8;
UIFont *SGCategoryCappedFont(UIFontTextStyle style, UIFontWeight weight, UIContentSizeCategory largest) {
    return [UIFont preferredFontForTextStyle:style];
}
SGTransitionFacts *SGAutoMixCurrentTransition(void) { return nil; }
BOOL SGRMixShowsQueue(void) { return NO; }
BOOL SGRMixTrackIs(SPTPlayerTrack *track, NSString *uri, NSString *uid) { return NO; }
BOOL SGTransitionSettingsRead(SGTransitionSettings *settings) { return NO; }
NSNotificationName const SGAutoMixTransitionDidChangeNotification = @"queue-test.mix";
NSNotificationName const SGAutoMixPlayerOptionsDidChangeNotification = @"queue-test.options";

static void check(BOOL condition, NSString *message) {
    checked++;
    printf("%s %s\n", condition ? "PASS" : "FAIL", message.UTF8String);
    fflush(stdout);
    if (!condition) exit(1);
}
static QueueTrack *song(NSString *uid, NSString *title) {
    QueueTrack *track = [QueueTrack new];
    track.UID = uid;
    [track setValue:@"spotify:track:duplicate" forKey:@"URI"];
    [track setValue:title forKey:@"trackTitle"];
    [track setValue:@"context" forKey:@"provider"];
    return track;
}
static NSIndexPath *row(NSInteger section, NSInteger index) {
    return [NSIndexPath indexPathForRow:index inSection:section];
}
static NSArray *titles(NSInteger section) {
    NSMutableArray *values = [NSMutableArray new];
    for (NSInteger i = 0; i < [screen tableView:screen.tableView numberOfRowsInSection:section]; i++) {
        UITableViewCell *cell = [screen tableView:screen.tableView cellForRowAtIndexPath:row(section, i)];
        [values addObject:((UIListContentConfiguration *)cell.contentConfiguration).text];
    }
    return values;
}
static void report(NSString *revision) {
    state.queueRevision = revision;
    for (id<SGPlayerStateObserver> observer in observers.allObjects) [observer playerStateDidReport:state];
}
static void run(void) {
    player = [QueuePlayer new];
    player.currentQueue = [QueueSnapshot new];
    player.currentQueue.track = song(@"current", @"Current");
    player.currentQueue.prevTracks = @[song(@"old", @"Earlier"), song(@"recent", @"Recent")];
    player.currentQueue.nextTracks = @[song(@"one", @"First occurrence"), song(@"two", @"Second occurrence")];
    state = [QueueState new]; state.playbackId = @"playback"; state.queueRevision = @"100";
    [state setValue:player.currentQueue.track forKey:@"track"];
    screen = [NSClassFromString(@"SGRPlayerQueueController") new];
    window.rootViewController = [[UINavigationController alloc] initWithRootViewController:screen];
    [screen loadViewIfNeeded];
    check([titles(0) isEqual:@[@"Earlier", @"Recent"]] && [titles(1) isEqual:@[@"Current"]] &&
          [titles(2) isEqual:@[@"First occurrence", @"Second occurrence"]], @"Spotify History appears chronologically above current and Up Next");
    UITableViewCell *history = [screen tableView:screen.tableView cellForRowAtIndexPath:row(0, 1)];
    [screen tableView:screen.tableView didSelectRowAtIndexPath:row(0, 1)];
    check(history.selectionStyle == UITableViewCellSelectionStyleNone &&
          history.accessibilityTraits == UIAccessibilityTraitStaticText &&
          [player.currentQueue.track.trackTitle isEqual:@"Current"], @"History is readable without changing playback");
    NSMutableArray *past = [NSMutableArray new];
    for (NSInteger i = 1; i <= 12; i++) {
        NSString *title = [NSString stringWithFormat:@"%ld", (long)i];
        [past addObject:song(title, title)];
    }
    player.currentQueue.prevTracks = past;
    report(@"101");
    check([titles(0) isEqual:@[@"3", @"4", @"5", @"6", @"7", @"8", @"9", @"10", @"11", @"12"]], @"queue reports show only the ten most recent songs");
    player.currentQueue.prevTracks = nil;
    report(@"102");
    check(titles(0).count == 0 && [screen tableView:screen.tableView titleForHeaderInSection:0] == nil,
          @"empty Spotify History has no heading or rows");
    QueueTrack *episode = song(@"episode", @"Podcast"), *local = song(@"local", @"Local recording");
    [episode setValue:@"spotify:episode:episode" forKey:@"URI"];
    [local setValue:@"spotify:local:artist:album:title:123" forKey:@"URI"];
    player.currentQueue.nextTracks = @[episode, local];
    report(@"103");
    check([titles(2) isEqual:@[@"Podcast", @"Local recording"]], @"whole queue preserves episode and local Up Next eligibility");
    for (NSNumber *missingAPI in @[@NO, @YES]) {
        player.withoutQueueAPI = missingAPI.boolValue;
        [state setValue:@[episode] forKey:@"future"];
        report(missingAPI.boolValue ? @"104" : nil);
        [state setValue:@[local, episode] forKey:@"future"];
        report(missingAPI.boolValue ? @"104" : nil);
        check([titles(2) isEqual:@[@"Local recording", @"Podcast"]], @"compatibility reports refresh changed future with the same current track");
    }
    [screen tableView:screen.tableView didSelectRowAtIndexPath:row(2, 1)];
    check([((QueueTrack *)player.currentQueue.track).UID isEqual:@"episode"], @"Up Next retains its episode skip action");
    printf("queue checks: %d of %d right -- PASS\n", checked, checked);
    fflush(stdout);
    exit(0);
}
@interface QueueApp : UIResponder <UIApplicationDelegate>
@end
@implementation QueueApp
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    window.rootViewController = [UIViewController new];
    [window makeKeyAndVisible];
    dispatch_async(dispatch_get_main_queue(), ^{ run(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        HARNESS_FAIL(@"queue checks did not finish");
    });
    return YES;
}
@end
int main(int argc, char **argv) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(QueueApp.class)); }
}
