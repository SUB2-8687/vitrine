// Spotify 9.1.90 puts its scrolled title in _UINavigationBarTitleControl under SPNavigationBar.
// Its Back and grouped action buttons are separate _UIButtonBarButton trees, never visited here.
#import "Core/SGCore.h"
#import "SGRHeaderInfo.h"
#import "Redesigned/Playlist/Playlist.h"
#import "Redesigned/Artist/Artist.h"

@interface SGAlbumQueuePage : NSObject
+ (NSString *)albumURI:(id)controller;
@end

static char kTitleStateKey, kTransitionKey, kPageKey;
static NSHashTable<UIView *> *sg_titles;
static BOOL sg_showTitles;

@interface SGRScrolledTitleState : NSObject
@property (nonatomic, strong) CALayer *originalMask, *concealment;
@property (nonatomic) BOOL accessibilityHidden, interactive;
@end
@implementation SGRScrolledTitleState
@end

static UINavigationController *navigationOf(UIView *title) {
    for (UIResponder *r = title; r; r = r.nextResponder) {
        if ([r isKindOfClass:UINavigationController.class]) return (UINavigationController *)r;
    }
    return nil;
}

static BOOL containsPage(UIView *view) {
    if (!view) return NO;
    static Class profile;
    if (!profile) profile = NSClassFromString(@"_TtC18Profile_CommonImpl11ProfileView");
    // The Creative Work styling predicate also accepts episodes; use the existing album model reader.
    UIResponder *owner = view.nextResponder;
    BOOL album = [owner isKindOfClass:UIViewController.class] && [NSClassFromString(@"SGAlbumQueuePage") albumURI:owner] != nil;
    if ([view isKindOfClass:profile] || SGRPlaylistPageOf(view) || album || SGRArtistPageOf(view)) return YES;
    for (UIView *child in view.subviews) if (containsPage(child)) return YES;
    return NO;
}

static BOOL isContentPage(UIViewController *page) {
    if (!page) return NO;
    if (objc_getAssociatedObject(page, &kPageKey)) return YES;
    if (!containsPage(page.viewIfLoaded)) return NO;
    objc_setAssociatedObject(page, &kPageKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static void concealTitle(UIView *title) {
    SGRScrolledTitleState *state = objc_getAssociatedObject(title, &kTitleStateKey);
    if (!state) {
        state = [SGRScrolledTitleState new];
        state.concealment = [CALayer layer];
        state.accessibilityHidden = title.accessibilityElementsHidden;
        state.interactive = title.userInteractionEnabled;
        objc_setAssociatedObject(title, &kTitleStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // Spotify can update its own mask while scrolling; keep that latest mask for restoration.
    if (title.layer.mask != state.concealment) {
        state.originalMask = title.layer.mask;
        title.layer.mask = state.concealment;
    }
    title.accessibilityElementsHidden = YES;
    title.userInteractionEnabled = NO;
}

static void restoreTitle(UIView *title) {
    SGRScrolledTitleState *state = objc_getAssociatedObject(title, &kTitleStateKey);
    if (!state) return;
    if (title.layer.mask == state.concealment) title.layer.mask = state.originalMask;
    title.accessibilityElementsHidden = state.accessibilityHidden;
    title.userInteractionEnabled = state.interactive;
    objc_setAssociatedObject(title, &kTitleStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void applyTitle(UIView *title) {
    if (!title) return;
    if (sg_showTitles && !objc_getAssociatedObject(title, &kTitleStateKey)) return;
    UINavigationController *navigation = navigationOf(title);
    id<UIViewControllerTransitionCoordinator> transition = navigation.transitionCoordinator;
    if (transition) {
        // A bar may hold the outgoing and incoming titles together. Keep existing concealment,
        // and decide ownership again only after a completed or cancelled push/pop has settled.
        if (objc_getAssociatedObject(title, &kTitleStateKey)) concealTitle(title);
        if (!objc_getAssociatedObject(title, &kTransitionKey)) {
            objc_setAssociatedObject(title, &kTransitionKey, transition, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            __weak UIView *weakTitle = title;
            [transition animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
                UIView *liveTitle = weakTitle;
                if (!liveTitle) return;
                objc_setAssociatedObject(liveTitle, &kTransitionKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [liveTitle setNeedsLayout];
            }];
        }
        return;
    }
    if (!sg_showTitles && isContentPage(navigation.topViewController)) concealTitle(title);
    else restoreTitle(title);
}

%hook _UINavigationBarTitleControl
- (void)didMoveToWindow {
    %orig;
    UIView *title = (UIView *)self;
    [sg_titles addObject:title];
    applyTitle(title);
}

- (void)layoutSubviews {
    %orig;
    applyTitle((UIView *)self);
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    sg_showTitles = SGEnabled(SGRKeyPageTitleWhenScrolled);
    sg_titles = [NSHashTable weakObjectsHashTable];
    [NSNotificationCenter.defaultCenter addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:nil
                                               usingBlock:^(NSNotification *notification) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SGPrefsChanged();
            BOOL shown = SGEnabled(SGRKeyPageTitleWhenScrolled);
            if (shown == sg_showTitles) return;
            sg_showTitles = shown;
            for (UIView *title in sg_titles) {
                applyTitle(title);
                [title setNeedsLayout];
            }
        });
    }];
    %init;
    SGRequireClasses(@[@"_UINavigationBarTitleControl"]);
}
