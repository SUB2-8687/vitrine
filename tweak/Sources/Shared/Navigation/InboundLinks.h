#import <Foundation/Foundation.h>

@protocol SGLinkCancellation <NSObject>
- (void)cancel;
@end
typedef void (^SGLinkResolved)(NSURL *url, NSError *error);
typedef id<SGLinkCancellation> (^SGLinkResolver)(NSURL *url, SGLinkResolved completion);

id<SGLinkCancellation> SGResolveSpotifyPublicLink(NSURL *url, SGLinkResolved completion);
BOOL SGSupportsSpotifyLinkDispatch(Class dispatcherClass, Class reasonClass);

// The ingress owner. acceptURL:, readiness and the opener run on main; resolver replies may arrive anywhere.
@interface SGInboundLinks : NSObject
- (instancetype)initWithResolver:(SGLinkResolver)resolver opener:(BOOL (^)(NSURL *))opener;
- (BOOL)acceptURL:(NSURL *)url;
- (void)setReady:(BOOL)ready;
@end
