// Adapted from upstream Vitrine's SGRStretchHero (21d46863), GPL-3.0.
// Rest-sized artwork is zoomed as one surface, so pulling never changes a bitmap renderer's inputs.
#import <UIKit/UIKit.h>

extern const CGFloat SGRStretchHeroDissolve;
// PCFF's container mirrors the overlay's offsets without using its own adjusted top inset.
// Follow the scrolling owner, not that mirrored container.
UIScrollView *SGRStretchHeroScrollAbove(UIView *view);

@interface SGRStretchHero : UIView
@property (nonatomic, readonly) UIView *content;
@property (nonatomic, readonly) CAGradientLayer *scrim;
@property (nonatomic) CGFloat restHeight;
@property (nonatomic, readonly) CGRect restBounds;
@property (nonatomic, readonly) CGFloat pull;
@property (nonatomic, readonly) CGFloat stretch;
// A square cover stays in its rest placement until a full-bleed animated cover takes over.
@property (nonatomic) BOOL stretchesContent;
@property (nonatomic) BOOL dissolves;
@property (nonatomic) CGFloat dissolveHeight;
- (void)sgr_place;
@end
