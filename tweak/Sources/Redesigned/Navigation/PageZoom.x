#import "PageZoom.h"
#import "Core/SGCore.h"

%hook SPNavigationController
- (void)setDelegate:(id<UINavigationControllerDelegate>)delegate {
    %orig(SGRPageZoomDelegate((UINavigationController *)self, delegate));
}
- (void)pushViewController:(UIViewController *)page animated:(BOOL)animated {
    SGRPageZoomPrepare((UINavigationController *)self, page, animated);
    %orig;
}
%end

// Observe the existing event without adding a recognizer or changing Spotify's delivery.
%hook UIApplication
- (void)sendEvent:(UIEvent *)event {
    for (UITouch *touch in event.allTouches) {
        if (touch.phase == UITouchPhaseBegan || touch.phase == UITouchPhaseCancelled) SGRPageZoomCapture(nil);
        else if (touch.phase == UITouchPhaseEnded) SGRPageZoomCapture(touch.view);
    }
    %orig;
}
- (BOOL)sendAction:(SEL)action to:(id)target from:(id)sender forEvent:(UIEvent *)event {
    // VoiceOver and keyboard activation have no touch; the sender is still Spotify's actual control.
    if ([sender isKindOfClass:UIView.class]) SGRPageZoomCapture(sender);
    return %orig;
}
%end

%hook UICollectionViewCell
- (void)prepareForReuse {
    SGRPageZoomReuse((UIView *)self);
    %orig;
}
%end

%hook UITableViewCell
- (void)prepareForReuse {
    SGRPageZoomReuse((UIView *)self);
    %orig;
}
%end

// UIKit creates incoming platters after animateTransition: has started. Track the item,
// not every view in the shared navigation bar, so outgoing chrome is never concealed.
%hook _UIButtonBarButton
- (void)_configureFromBarItem:(UIBarButtonItem *)item appearanceDelegate:(id)delegate isBackButton:(BOOL)back useBreadcrumbStyle:(BOOL)breadcrumb {
    %orig;
    SGRPageZoomRecordBarButton((UIView *)self, item);
}
%end

%hook _UINavigationBarPlatterView
- (void)layoutSubviews {
    %orig;
    SGRPageZoomLayoutChrome((UIView *)self);
}
- (void)setAlpha:(CGFloat)alpha {
    %orig(SGRPageZoomChromeAlpha((UIView *)self, alpha));
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    if (@available(iOS 26.0, *)) {
        if (!SGFlag(SGRKeyPageZoom, NO)) return;
        %init;
        SGRequireClasses(@[@"SPNavigationController"]);
    }
}
