// Adapted from upstream Vitrine's SGRStretchHero (21d46863), GPL-3.0.
#import "SGRStretchHero.h"

const CGFloat SGRStretchHeroDissolve = 0.46;
static const CGFloat kScrimHeight = 140, kScrimAlpha = 0.28;
static void *kListContext = &kListContext;

UIScrollView *SGRStretchHeroScrollAbove(UIView *view) {
    for (UIView *v = view.superview; v; v = v.superview) {
        if (![v isKindOfClass:UIScrollView.class]) continue;
        if (![v.accessibilityIdentifier isEqualToString:@"PCFFTabLayoutViewController.containerScrollView"])
            return (UIScrollView *)v;
        for (UIView *sibling in v.superview.subviews) {
            if ([sibling isKindOfClass:UIScrollView.class] &&
                [sibling.accessibilityIdentifier isEqualToString:@"PCFFTabLayoutViewController.overlayScrollView"])
                return (UIScrollView *)sibling;
        }
        return nil;
    }
    return nil;
}

@implementation SGRStretchHero {
    __weak UIScrollView *_list;
    CALayer *_mask, *_opaque;
    CAGradientLayer *_fade;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.clipsToBounds = YES;
    _restHeight = frame.size.height;
    _content = [[UIView alloc] initWithFrame:self.bounds];
    _content.userInteractionEnabled = NO;
    [self addSubview:_content];
    _scrim = [CAGradientLayer layer];
    _scrim.zPosition = 1;
    _scrim.colors = @[(id)[UIColor colorWithWhite:0 alpha:kScrimAlpha].CGColor,
                     (id)UIColor.clearColor.CGColor];
    [self.layer addSublayer:_scrim];
    _mask = [CALayer layer];
    _opaque = [CALayer layer];
    _opaque.backgroundColor = UIColor.blackColor.CGColor;
    [_mask addSublayer:_opaque];
    _fade = [CAGradientLayer layer];
    _fade.colors = @[(id)UIColor.blackColor.CGColor, (id)[UIColor colorWithWhite:0 alpha:0.28].CGColor,
                     (id)UIColor.clearColor.CGColor];
    _fade.locations = @[@0, @0.62, @1];
    [_mask addSublayer:_fade];
    _stretchesContent = YES;
    _dissolves = YES;
    _content.layer.mask = _mask;
    return self;
}

- (void)dealloc {
    [_list removeObserver:self forKeyPath:@"contentOffset" context:kListContext];
}

- (CGRect)restBounds {
    return CGRectMake(0, 0, self.bounds.size.width, _restHeight);
}

- (CGFloat)pull {
    if (!_list) return 0;
    CGFloat restOffset = -_list.adjustedContentInset.top;
    return MAX(0, restOffset - _list.contentOffset.y);
}

- (CGFloat)stretch {
    return MAX(0, self.bounds.size.height - _restHeight);
}

- (void)setDissolves:(BOOL)dissolves {
    if (_dissolves == dissolves) return;
    _dissolves = dissolves;
    _content.layer.mask = dissolves ? _mask : nil;
}

- (void)setStretchesContent:(BOOL)stretchesContent {
    if (_stretchesContent == stretchesContent) return;
    _stretchesContent = stretchesContent;
    [self setNeedsLayout];
}

- (void)setDissolveHeight:(CGFloat)dissolveHeight {
    if (_dissolveHeight == dissolveHeight) return;
    _dissolveHeight = dissolveHeight;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (_restHeight <= 0) return;
    CGFloat scale = _stretchesContent ? self.bounds.size.height / _restHeight : 1;
    CGRect rest = self.restBounds;
    CGFloat fade = (_dissolveHeight > 0 ? _dissolveHeight : round(_restHeight * SGRStretchHeroDissolve)) / scale;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _content.bounds = rest;
    _content.center = CGPointMake(CGRectGetMidX(rest), _stretchesContent ? self.bounds.size.height / 2
                                                                       : self.stretch + _restHeight / 2);
    _content.transform = CGAffineTransformMakeScale(scale, scale);
    _scrim.frame = CGRectMake(0, 0, rest.size.width, MIN(kScrimHeight, self.bounds.size.height));
    _mask.frame = rest;
    _opaque.frame = CGRectMake(0, 0, rest.size.width, _restHeight - fade);
    _fade.frame = CGRectMake(0, _restHeight - fade, rest.size.width, fade);
    [CATransaction commit];
}

- (void)sgr_place {
    if (!self.superview || _restHeight <= 0) return;
    CGFloat pull = self.pull;
    CGRect frame = CGRectMake(0, -pull, self.superview.bounds.size.width, _restHeight + pull);
    if (!CGRectEqualToRect(self.frame, frame)) self.frame = frame;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context != kListContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    if (self.pull > 0 || self.stretch > 0) [self sgr_place];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    UIScrollView *list = self.window ? SGRStretchHeroScrollAbove(self) : nil;
    if (list == _list) return;
    [_list removeObserver:self forKeyPath:@"contentOffset" context:kListContext];
    _list = list;
    [list addObserver:self forKeyPath:@"contentOffset" options:0 context:kListContext];
    [self sgr_place];
}
@end
