#import <UIKit/UIKit.h>

#define SGRKeyPageZoom @"spotifyglass.redesign.pageZoom"

// Main thread only. Spotify still owns the selection, page and navigation stack.
void SGRPageZoomCapture(UIView *sender);
void SGRPageZoomPrepare(UINavigationController *navigation, UIViewController *page, BOOL animated);
void SGRPageZoomReuse(UIView *cell);
id<UINavigationControllerDelegate> SGRPageZoomDelegate(UINavigationController *navigation, id<UINavigationControllerDelegate> delegate);
void SGRPageZoomRecordBarButton(UIView *button, UIBarButtonItem *item);
void SGRPageZoomLayoutChrome(UIView *chrome);
CGFloat SGRPageZoomChromeAlpha(UIView *chrome, CGFloat alpha);
