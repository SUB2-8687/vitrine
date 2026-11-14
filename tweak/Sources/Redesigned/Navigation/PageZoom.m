#import "PageZoom.h"
#import "Core/SGCore.h"

@interface UIViewController (SGRPageZoomPage)
- (NSURL *)URI;
@end

@interface SGRPageZoomSource : NSObject
@property (nonatomic, weak) UIImageView *artwork;
@property (nonatomic, weak) UIImage *image;
@property (nonatomic, weak) UIView *cell;
@property (nonatomic, strong) id generation;
@property (nonatomic, weak) UINavigationController *navigation;
@property (nonatomic, weak) UIViewController *page;
- (UIView *)visibleArtwork;
@end

static char reuseKey;
static char sourceKey;
static char proxyKey;
static char activeAnimatorKey;
static char chromeKey;
static NSMapTable<UIView *, UIBarButtonItem *> *barItems;
static SGRPageZoomSource *pending;
static const NSTimeInterval pageZoomDurationSeconds = 0.4;
static const CGFloat pageZoomBackgroundDimmingAlpha = 0.12;
static const CGFloat pageZoomSpringDampingRatio = 0.88;
static const NSTimeInterval pageZoomContentWaitSeconds = 0.6;
static const NSTimeInterval pageZoomContentFadeSeconds = 0.2;
static const NSTimeInterval pageZoomReadinessIntervalSeconds = 0.05;

@interface SGRPageZoomChrome : NSObject
@property (nonatomic, strong) UIView *view;
@property (nonatomic) CGFloat alpha;
@property (nonatomic) BOOL revealing;
@end
@implementation SGRPageZoomChrome
@end

void SGRPageZoomRecordBarButton(UIView *button, UIBarButtonItem *item) {
    if (!barItems) barItems = [NSMapTable weakToWeakObjectsMapTable];
    [barItems setObject:item forKey:button];
}

CGFloat SGRPageZoomChromeAlpha(UIView *chrome, CGFloat alpha) {
    SGRPageZoomChrome *state = objc_getAssociatedObject(chrome, &chromeKey);
    return state && !state.revealing ? 0 : alpha;
}

// These are destination content, not the navigation bar or PageLoader.LoadingView.
static BOOL pageContentLaidOut(UIView *view) {
    if (view.hidden || CGRectIsEmpty(view.bounds)) return NO;
    if ([view isKindOfClass:UICollectionView.class]) {
        UICollectionView *list = (UICollectionView *)view;
        if (list.visibleCells.count) return YES;
    }
    if ([NSStringFromClass(view.class) isEqualToString:@"_TtCO19LegacyUI_ECMCoreKit5Views10HeaderView"]) return YES;
    for (UIView *child in view.subviews) if (pageContentLaidOut(child)) return YES;
    return NO;
}

static CGFloat artworkCornerRadius(UIView *artwork) {
    CGFloat radius = artwork.layer.cornerRadius;
    for (UIView *view = artwork.superview; view; view = view.superview) {
        CGRect rect = [artwork convertRect:artwork.bounds toView:view];
        if (!CGRectEqualToRect(rect, view.bounds)) break;
        if (view.clipsToBounds) radius = MAX(radius, view.layer.cornerRadius);
    }
    return radius;
}

@implementation SGRPageZoomSource
- (UIView *)visibleArtwork {
    UIImageView *artwork = self.artwork;
    UIWindow *window = artwork.window;
    if (!window || !self.image || artwork.image != self.image) return nil;
    if (self.cell && objc_getAssociatedObject(self.cell, &reuseKey) != self.generation) return nil;
    CGRect visible = [artwork convertRect:artwork.bounds toView:window];
    for (UIView *view = artwork; view; view = view.superview) {
        if (view.hidden) return nil;
        if (view.clipsToBounds) visible = CGRectIntersection(visible, [view convertRect:view.bounds toView:window]);
    }
    return CGRectIsEmpty(CGRectIntersection(visible, window.bounds)) ? nil : artwork;
}
@end

@interface SGRPageZoomAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic, strong) SGRPageZoomSource *source;
@property (nonatomic) BOOL pushing;
@property (nonatomic, strong) CADisplayLink *readinessLink;
@property (nonatomic) CFTimeInterval startedAtSeconds;
@property (nonatomic) CFTimeInterval lastInspectionAtSeconds;
@property (nonatomic, weak) UINavigationController *navigation;
@property (nonatomic, strong) UINavigationItem *destinationItem;
@property (nonatomic, strong) UIBarButtonItem *backItem;
@property (nonatomic, strong) NSMutableArray<SGRPageZoomChrome *> *chrome;
@property (nonatomic) BOOL revealing;
@property (nonatomic, strong) UIImageView *snapshot;
@property (nonatomic, strong) UIView *page;
@property (nonatomic) CGFloat pageAlpha;
@property (nonatomic) BOOL springFinished;
@property (nonatomic) BOOL revealFinished;
@property (nonatomic, copy) void (^completion)(void);
- (void)captureChrome:(UIView *)view;
@end

void SGRPageZoomLayoutChrome(UIView *chrome) {
    for (UIResponder *responder = chrome; responder; responder = responder.nextResponder) {
        if (![responder isKindOfClass:UINavigationController.class]) continue;
        SGRPageZoomAnimator *animator = objc_getAssociatedObject(responder, &activeAnimatorKey);
        [animator captureChrome:chrome];
        break;
    }
}

static BOOL ownedBarItems(UIView *view, UINavigationItem *destination, UIBarButtonItem *back, BOOL *found) {
    for (UIBarButtonItem *custom in destination.leftBarButtonItems)
        if (custom.customView == view) *found = YES;
    for (UIBarButtonItem *custom in destination.rightBarButtonItems)
        if (custom.customView == view) *found = YES;
    UIBarButtonItem *item = [barItems objectForKey:view];
    if (item) {
        if (item != back && ![destination.leftBarButtonItems containsObject:item] &&
            ![destination.rightBarButtonItems containsObject:item]) return NO;
        *found = YES;
    }
    for (UIView *child in view.subviews)
        if (!ownedBarItems(child, destination, back, found)) return NO;
    return YES;
}

@implementation SGRPageZoomAnimator
- (void)captureChrome:(UIView *)view {
    if (!view || self.revealing || !self.chrome || objc_getAssociatedObject(view, &chromeKey)) return;
    if (view != self.destinationItem.titleView) {
        if (![NSStringFromClass(view.class) isEqualToString:@"_UINavigationBarPlatterView"]) return;
        BOOL found = NO;
        if (!ownedBarItems(view, self.destinationItem, self.backItem, &found) || !found) return;
    }
    SGRPageZoomChrome *state = [SGRPageZoomChrome new];
    state.view = view;
    state.alpha = view.alpha;
    [self.chrome addObject:state];
    objc_setAssociatedObject(view, &chromeKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    view.alpha = 0;
}
- (void)captureChromeIn:(UIView *)view {
    [self captureChrome:view];
    for (UIView *child in view.subviews) [self captureChromeIn:child];
}
- (void)restoreChrome {
    objc_setAssociatedObject(self.navigation, &activeAnimatorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (SGRPageZoomChrome *state in self.chrome) {
        objc_setAssociatedObject(state.view, &chromeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        state.view.alpha = state.alpha;
    }
    self.chrome = nil;
}
- (void)layoutArtworkInCarrier:(UIView *)carrier {
    CGFloat widthPoints = CGRectGetWidth(carrier.bounds);
    self.snapshot.frame = CGRectMake(0, 0, widthPoints, widthPoints);
}
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)context {
    return self.pushing ? pageZoomContentWaitSeconds + pageZoomContentFadeSeconds : pageZoomDurationSeconds;
}
- (void)finishIfReady {
    if (!self.springFinished || !self.revealFinished) return;
    [self.readinessLink invalidate];
    self.readinessLink = nil;
    [self restoreChrome];
    void (^completion)(void) = self.completion;
    self.completion = nil;
    completion();
    self.page = nil;
    self.snapshot = nil;
}
- (void)checkContent:(CADisplayLink *)link {
    CFTimeInterval now = CACurrentMediaTime();
    if (now - self.startedAtSeconds < pageZoomContentWaitSeconds) {
        if (now - self.lastInspectionAtSeconds < pageZoomReadinessIntervalSeconds) return;
        self.lastInspectionAtSeconds = now;
        if (!pageContentLaidOut(self.page)) return;
    }
    [self.readinessLink invalidate];
    self.readinessLink = nil;
    self.revealing = YES;
    for (SGRPageZoomChrome *state in self.chrome) state.revealing = YES;
    [UIView animateWithDuration:pageZoomContentFadeSeconds animations:^{
        self.page.alpha = self.pageAlpha;
        self.snapshot.alpha = 0;
        for (SGRPageZoomChrome *state in self.chrome) state.view.alpha = state.alpha;
    } completion:^(BOOL finished) {
        self.revealFinished = YES;
        [self finishIfReady];
    }];
}
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)context {
    self.startedAtSeconds = CACurrentMediaTime();
    UIView *container = context.containerView;
    UIViewController *to = [context viewControllerForKey:UITransitionContextToViewControllerKey];
    UIView *fromView = [context viewForKey:UITransitionContextFromViewKey];
    UIView *toView = [context viewForKey:UITransitionContextToViewKey];
    toView.frame = [context finalFrameForViewController:to];
    if (self.pushing) [container addSubview:toView];
    else [container insertSubview:toView belowSubview:fromView];
    [toView layoutIfNeeded];

    UIView *page = self.pushing ? toView : fromView;
    CGRect pageFrame = page.frame;
    UIView *artwork = self.source.visibleArtwork;
    CGRect sourceFrame = [artwork convertRect:artwork.bounds toView:container];
    BOOL zoom = artwork && !CGRectIsEmpty(sourceFrame) && !UIAccessibilityIsReduceMotionEnabled();
    // Encore's CATransformLayer root cannot be masked/flattened by UIKit's zoom portal.
    // Move the actual page into a CALayer-backed carrier; never replace its controller or root.
    UIView *carrier = [[UIView alloc] initWithFrame:pageFrame];
    carrier.clipsToBounds = YES;
    carrier.layer.cornerCurve = kCACornerCurveContinuous;
    [container addSubview:carrier];
    [carrier addSubview:page];
    page.frame = carrier.bounds;
    UIViewAutoresizing pageAutoresizing = page.autoresizingMask;
    if (self.pushing) page.autoresizingMask = UIViewAutoresizingNone;
    UIView *shade = [[UIView alloc] initWithFrame:container.bounds];
    shade.backgroundColor = UIColor.blackColor;
    shade.userInteractionEnabled = NO;
    shade.accessibilityElementsHidden = YES;
    [container insertSubview:shade belowSubview:carrier];
    shade.alpha = self.pushing ? 0 : pageZoomBackgroundDimmingAlpha;

    CGAffineTransform small = CGAffineTransformIdentity;
    CGPoint smallCenter = carrier.center;
    CGFloat radius = 0;
    if (zoom) {
        CGFloat scaleX = sourceFrame.size.width / pageFrame.size.width;
        CGFloat scaleY = sourceFrame.size.height / pageFrame.size.height;
        small = CGAffineTransformMakeScale(scaleX, scaleY);
        smallCenter = CGPointMake(CGRectGetMidX(sourceFrame), CGRectGetMidY(sourceFrame));
        radius = artwork.layer.cornerRadius / scaleX;
    }
    self.revealFinished = YES;
    if (self.pushing) {
        carrier.alpha = zoom ? 1 : 0;
        if (artwork) {
            carrier.backgroundColor = UIColor.blackColor;
            self.page = page;
            self.pageAlpha = page.alpha;
            page.alpha = 0;
            self.navigation = to.navigationController;
            self.destinationItem = to.navigationItem;
            self.backItem = [context viewControllerForKey:UITransitionContextFromViewControllerKey].navigationItem.backBarButtonItem;
            self.chrome = [NSMutableArray array];
            objc_setAssociatedObject(self.navigation, &activeAnimatorKey, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [self captureChromeIn:self.navigation.navigationBar];
            self.snapshot = [[UIImageView alloc] initWithImage:self.source.artwork.image];
            self.snapshot.contentMode = UIViewContentModeScaleAspectFill;
            self.snapshot.clipsToBounds = YES;
            self.snapshot.layer.cornerCurve = carrier.layer.cornerCurve;
            self.snapshot.accessibilityElementsHidden = YES;
            [carrier addSubview:self.snapshot];
            self.revealFinished = NO;
        }
        if (zoom) {
            // Animate bounds so the full-resolution image keeps its square aspect while growing.
            carrier.frame = sourceFrame;
            carrier.layer.cornerRadius = artworkCornerRadius(artwork);
        }
        self.snapshot.layer.cornerRadius = carrier.layer.cornerRadius;
        [self layoutArtworkInCarrier:carrier];
    }
    UIImageView *snapshot = self.snapshot;
    CGFloat pageAlpha = self.pageAlpha;
    self.completion = ^{
        BOOL completed = !context.transitionWasCancelled;
        carrier.transform = CGAffineTransformIdentity;
        if (snapshot) page.alpha = pageAlpha;
        page.frame = pageFrame;
        page.autoresizingMask = pageAutoresizing;
        [container insertSubview:page aboveSubview:carrier];
        [carrier removeFromSuperview];
        [shade removeFromSuperview];
        if (!completed) [toView removeFromSuperview];
        [context completeTransition:completed];
    };
    [UIView animateWithDuration:pageZoomDurationSeconds delay:0
        usingSpringWithDamping:pageZoomSpringDampingRatio initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseInOut animations:^{
            if (self.pushing) {
                carrier.frame = pageFrame;
                [self layoutArtworkInCarrier:carrier];
                self.snapshot.layer.cornerRadius = 0;
            } else {
                carrier.transform = small;
                carrier.center = smallCenter;
            }
            carrier.layer.cornerRadius = self.pushing ? 0 : radius;
            carrier.alpha = self.pushing || zoom ? 1 : 0;
            shade.alpha = self.pushing ? pageZoomBackgroundDimmingAlpha : 0;
        } completion:^(BOOL finished) {
            self.springFinished = YES;
            [self finishIfReady];
        }];
    if (!self.revealFinished) {
        self.readinessLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(checkContent:)];
        [self.readinessLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        [self checkContent:nil];
    }
}
@end

@interface SGRPageZoomDelegateProxy : NSProxy <UINavigationControllerDelegate>
@property (nonatomic, weak) id<UINavigationControllerDelegate> original;
@end

@implementation SGRPageZoomDelegateProxy
- (BOOL)respondsToSelector:(SEL)selector {
    return selector == @selector(navigationController:animationControllerForOperation:fromViewController:toViewController:) ||
           [self.original respondsToSelector:selector];
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [(NSObject *)self.original methodSignatureForSelector:selector];
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:self.original];
}
- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigation
        animationControllerForOperation:(UINavigationControllerOperation)operation
        fromViewController:(UIViewController *)from toViewController:(UIViewController *)to {
    SGRPageZoomSource *source = objc_getAssociatedObject(operation == UINavigationControllerOperationPush ? to : from, &sourceKey);
    if (source && (operation == UINavigationControllerOperationPush || operation == UINavigationControllerOperationPop)) {
        UIGestureRecognizerState state = navigation.interactivePopGestureRecognizer.state;
        if (operation == UINavigationControllerOperationPop &&
            (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged ||
             navigation.transitionCoordinator.isInteractive)) return nil;
        SGRPageZoomAnimator *animator = [SGRPageZoomAnimator new];
        animator.source = source;
        animator.pushing = operation == UINavigationControllerOperationPush;
        return animator;
    }
    if ([self.original respondsToSelector:_cmd])
        return [self.original navigationController:navigation animationControllerForOperation:operation fromViewController:from toViewController:to];
    return nil;
}
@end

id<UINavigationControllerDelegate> SGRPageZoomDelegate(UINavigationController *navigation, id<UINavigationControllerDelegate> delegate) {
    SGRPageZoomDelegateProxy *proxy = objc_getAssociatedObject(navigation, &proxyKey);
    if (!proxy || delegate == (id)proxy) return delegate;
    proxy.original = delegate;
    return (id)proxy;
}

static BOOL artworkHolder(UIView *view) {
    NSString *identifier = view.accessibilityIdentifier;
    return [identifier isEqualToString:@"Encore.ImageView"] ||
           [identifier isEqualToString:@"Artwork.Row.Library"] ||
           [identifier isEqualToString:@"Components.UI.CardLibrary.Artwork"];
}

// Only Spotify's artwork holders, never a Play glyph, badge or a row's More button.
static UIImageView *artworkIn(UIView *view, BOOL insideHolder) {
    insideHolder |= artworkHolder(view);
    if (insideHolder && [view isKindOfClass:UIImageView.class] && ((UIImageView *)view).image) return (UIImageView *)view;
    for (UIView *child in view.subviews) {
        UIImageView *image = artworkIn(child, insideHolder);
        if (image) return image;
    }
    return nil;
}

void SGRPageZoomCapture(UIView *sender) {
    pending = nil;
    if (!SGFlag(SGRKeyPageZoom, NO) || !sender.window) return;
    UIView *container = sender;
    while (container && ![container isKindOfClass:UIControl.class] &&
           ![container isKindOfClass:UICollectionViewCell.class] &&
           ![container isKindOfClass:UITableViewCell.class]) container = container.superview;
    if (!container) return;
    UIImageView *image = artworkIn(container, NO);
    if (!image) return;
    SGRPageZoomSource *source = [SGRPageZoomSource new];
    source.artwork = image;
    source.image = image.image;
    for (UIView *view = image; view; view = view.superview) {
        if ([view isKindOfClass:UICollectionViewCell.class] || [view isKindOfClass:UITableViewCell.class]) {
            source.cell = view;
            source.generation = objc_getAssociatedObject(view, &reuseKey);
            break;
        }
    }
    for (UIResponder *responder = sender; responder; responder = responder.nextResponder) {
        if (![responder isKindOfClass:UIViewController.class]) continue;
        UINavigationController *nav = ((UIViewController *)responder).navigationController;
        if (!nav) continue;
        source.navigation = nav;
        source.page = nav.topViewController;
        break;
    }
    if (source.navigation && source.visibleArtwork) pending = source;
}

void SGRPageZoomReuse(UIView *cell) {
    objc_setAssociatedObject(cell, &reuseKey, [NSObject new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void SGRPageZoomPrepare(UINavigationController *navigation, UIViewController *page, BOOL animated) {
    SGRPageZoomSource *source = pending;
    pending = nil;
    if (!SGFlag(SGRKeyPageZoom, NO) || !animated || !source ||
        source.navigation != navigation || source.page != navigation.topViewController ||
        !source.visibleArtwork || ![page respondsToSelector:@selector(URI)]) return;
    // IdentifiedPageHostingViewController has its URI before the push; spt_pageURI is still nil then.
    NSURL *uri = [page URI];
    if (![uri isKindOfClass:NSURL.class]) return;
    NSString *value = uri.absoluteString;
    if (![value hasPrefix:@"spotify:album:"] && ![value hasPrefix:@"spotify:playlist:"]) return;
    if (@available(iOS 26.0, *)) {
        objc_setAssociatedObject(page, &sourceKey, source, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SGRPageZoomDelegateProxy *proxy = objc_getAssociatedObject(navigation, &proxyKey);
        if (!proxy) {
            proxy = [SGRPageZoomDelegateProxy alloc];
            proxy.original = navigation.delegate;
            objc_setAssociatedObject(navigation, &proxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            navigation.delegate = (id)proxy;
        }
    }
}
