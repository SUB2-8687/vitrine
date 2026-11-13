#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char kReachKey;
static NSString *const SGRKeyPlayerVolume = @"harness.volume";
static BOOL SGEnabled(NSString *key) { return YES; }
static void SGRPlayerPaintCover(UIView *stack) {}
#define SGLog(...) ((void)0)
void SGRPlayerLowerRow(UIView *row);

// Only drawing is absent: production creates and places this row against the actual button geometry.
@interface SGRVolumeRow : UIView
@end
@implementation SGRVolumeRow
@end
static UIView *SGRFindByIdentifier(UIView *view, NSString *identifier, const void *key) {
    if ([view.accessibilityIdentifier isEqual:identifier]) return view;
    for (UIView *child in view.subviews) {
        UIView *found = SGRFindByIdentifier(child, identifier, key);
        if (found) return found;
    }
    return nil;
}
static BOOL SGRPlayerLyricsFadeView(UIView *view, BOOL fits) {
    if (!fits) view.alpha = 0;
    return !fits;
}

// The layout needs window geometry, not an application or a visible desktop window.
@interface HarnessFooter : UIView
@property BOOL layoutRunning;
@end
@implementation HarnessFooter
- (UIWindow *)window { return self.layoutRunning ? (UIWindow *)self : nil; }
@end
@interface PlaybackControlsElementsUnit : UIViewController
@end
@implementation PlaybackControlsElementsUnit
@end

#include "volume-placement-production.inc"
#include "volume-layout-production.inc"

static BOOL checkPhone(CGSize size, CGFloat stackTop, BOOL expectsVolume) {
        UIView *host = [[UIView alloc] initWithFrame:(CGRect){CGPointZero, size}];
        UIStackView *stack = [[UIStackView alloc] initWithFrame:CGRectMake(0, stackTop, size.width, 240)];
        [host addSubview:stack];
        UIView *duration = [[UIView alloc] initWithFrame:CGRectMake(0, 67, size.width, 41)];
        UIControl *time = [[UIControl alloc] initWithFrame:CGRectMake(24, 26, size.width - 48, 15)];
        [duration addSubview:time];
        [stack addSubview:duration];
        PlaybackControlsElementsUnit *controls = [PlaybackControlsElementsUnit new];
        controls.view.frame = CGRectMake(0, 108, size.width, 88);
        UIControl *play = [[UIControl alloc] initWithFrame:CGRectMake((size.width - 64) / 2, 16, 64, 64)];
        play.accessibilityIdentifier = @"SPTNowPlayingPlayButton";
        [controls.view addSubview:play];
        [stack addSubview:controls.view];
        HarnessFooter *footer = [[HarnessFooter alloc] initWithFrame:CGRectMake(0, 196, size.width, 44)];
        [stack addSubview:footer];
        footer.layoutRunning = YES;
        SGRPlayerLowerRow(footer);
        footer.layoutRunning = NO;
        UIView *hit = [stack hitTest:CGPointMake(size.width / 2, 104) withEvent:nil];
        if (hit != time) {
            NSLog(@"FAIL volume layout covers time row: hit %@ instead of its control", NSStringFromClass(hit.class));
            return NO;
        }
        UIView *volume = nil;
        for (UIView *view in stack.subviews) if ([view isKindOfClass:SGRVolumeRow.class]) volume = view;
        if (!volume || (volume.alpha > 0.01) != expectsVolume) {
            NSLog(@"FAIL %@ volume should be %@", NSStringFromCGSize(size), expectsVolume ? @"shown" : @"omitted");
            return NO;
        }
        if (volume.alpha > 0.01 && (CGRectIntersectsRect(volume.frame, duration.frame) ||
            CGRectIntersectsRect(volume.frame, controls.view.frame) || CGRectIntersectsRect(volume.frame, footer.frame))) {
            NSLog(@"FAIL %@ volume overlaps another row", NSStringFromCGSize(size));
            return NO;
        }
        CGPoint playPoint = [play convertPoint:CGPointMake(32, 32) toView:stack];
        if ([stack hitTest:playPoint withEvent:nil] != play) {
            NSLog(@"FAIL %@ volume blocks playback controls", NSStringFromCGSize(size));
            return NO;
        }
        NSLog(@"PASS %@ real placement: volume %@, time and controls touchable", NSStringFromCGSize(size),
              expectsVolume ? @"shown without overlap" : @"omitted");
        return YES;
}

int main(void) {
    @autoreleasepool {
      @try {
        if (!checkPhone(CGSizeMake(402, 874), 572, YES)) return 1;
        // The SE has no bottom safe-area inset; the same Spotify units end at its 667 pt screen edge.
        if (!checkPhone(CGSizeMake(375, 667), 427, NO)) return 1;
      } @catch (NSException *exception) {
        NSLog(@"FAIL volume layout exception: %@", exception.reason);
        return 1;
      }
    }
    return 0;
}
