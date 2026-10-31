// The header's text and controls, the redesign's own. Laid out top down from where the content has to start
// for its bottom to sit SGRHeaderInfoBottom above the view's.
#import "Core/SGCore.h"
#import "SGRHeaderInfo.h"
#import "SGRActionRow.h"
#import "SGRRestyle.h"
#import "SGRTokens.h"

const CGFloat SGRHeaderInfoBottom = 14;
const CGFloat SGRHeaderInfoTitleRise = 56;

BOOL SGRPageFullCover(NSString *key) {
    NSUserDefaults *prefs = NSUserDefaults.standardUserDefaults;
    id legacy = [prefs objectForKey:SGRKeyFullBleedCovers];
    if (![prefs boolForKey:SGRKeyFullCoverMigrated]) {
        if (legacy) {
            for (NSString *destination in @[SGRKeyAlbumFullCover, SGRKeyPlaylistFullCover]) {
                if (![prefs objectForKey:destination]) [prefs setObject:legacy forKey:destination];
            }
        }
        // Older builds still own this key. Keep it unchanged for rollback, but never consult it again.
        [prefs setBool:YES forKey:SGRKeyFullCoverMigrated];
        SGPrefsChanged();
    }
    return SGEnabled(key);
}

static BOOL playInPageColour(void) {
    static BOOL on;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ on = SGEnabled(SGRKeyPlayInPageColour); });
    return on;
}

static BOOL cutOutPlay(void) {
    static BOOL on;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ on = SGFlag(SGRKeyArtistCutOutPlay, NO); });
    return on;
}

static BOOL accentPlay(void) {
    static BOOL on;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ on = SGFlag(SGRKeyAccentPlay, NO); });
    return on;
}

// The text kSide in from the edges; Play at least kPlayWidth wide, the Music app's; the gaps between.
static const CGFloat kSide = 20, kPlayWidth = 148, kRowSpacing = 16, kRowAbove = 16, kAboutAbove = 14;
// Round Play: the row as tall as the circle, and the round buttons either side this far off it.
static const CGFloat kRoundRow = 64, kRoundSpacing = 20;
// The pinned top bar under the top safe area, how far past its line the content goes before it is clipped, and how
// far under the line the clip fades in, clear at the line and opaque from there.
static const CGFloat kTopBar = 44, kUnderBar = 0.5, kBarFade = 14;

static UILabel *infoLabel(UIView *parent, UIFont *font, UIColor *color, NSInteger lines, NSTextAlignment alignment) {
    UILabel *label = [UILabel new];
    label.font = font;
    label.textColor = color;
    label.numberOfLines = lines;
    label.textAlignment = alignment;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.hidden = YES;
    [parent addSubview:label];
    return label;
}

static BOOL setText(UILabel *label, NSString *text) {
    if ([label.text ?: @"" isEqualToString:text ?: @""]) return NO;
    label.text = text;
    label.hidden = text.length == 0;
    return YES;
}

// The most a title picture takes: a share of the text's width, and a height near three lines of the title.
static const CGFloat kLogoWidthShare = 0.8, kLogoMaxHeight = 64;
// Between the creator's picture and the name.
static const CGFloat kPictureGap = 8;

// A face is at least this wide, and square give or take a point.
static const CGFloat kMinFace = 16;
// The creator's faces (-showCreatorFaces:from:): how many at most, the most a circle is across, how far on each next one
// starts as a share of that, and the clear ring cut around the one before out of it.
static const NSUInteger kMaxFaces = 3;
static const CGFloat kMaxFaceSide = 22, kFaceStep = 0.85, kFaceRing = 1.5;

static BOOL squareFace(UIView *v) {
    CGSize size = v.bounds.size;
    return size.width >= kMinFace && fabs(size.width - size.height) <= 1;
}

static BOOL faceSized(UIView *v) {
    return [v isKindOfClass:UIImageView.class] && squareFace(v);
}

// The avatar an image view on Spotify's creator line draws a face in: the outermost of the square views running up from
// it, short of `root`. Spotify's avatar is a square that clips the picture (which may be wider than it, a portrait
// filled across it) and holds the artist's initial under it; the image view counts as its own avatar only when it is
// square itself. nil when neither it nor the view it sits in is a face's square.
static UIView *avatarOf(UIImageView *image, UIView *root) {
    UIView *avatar = squareFace(image) ? image : nil;
    for (UIView *up = image.superview; up && up != root && squareFace(up); up = up.superview) avatar = up;
    return avatar;
}

// Where `v` starts in `root`, on the side a line in its direction starts from.
static CGFloat leadingEdge(UIView *v, UIView *root, BOOL rtl) {
    return [v convertPoint:CGPointMake(rtl ? v.bounds.size.width : 0, 0) toView:root].x;
}

UIImageView *SGRCreatorPicture(UIView *root) {
    if (!root) return nil;
    // The faces of a facepile overlap, the leading one first to the eye.
    BOOL rtl = root.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    __block UIImageView *found = nil;
    __block CGFloat edge = 0;
    SGForEachView(root, ^(UIView *v) {
        if (!faceSized(v)) return;
        CGFloat x = leadingEdge(v, root, rtl);
        if (!found || (rtl ? x > edge : x < edge)) found = (UIImageView *)v, edge = x;
    });
    return found;
}

static BOOL shownIn(UIView *v, UIView *root) {
    for (UIView *up = v; up; up = up.superview) {
        if (up.hidden || up.alpha < 0.01) return NO;
        if (up == root) return YES;
    }
    return NO;
}

NSArray<UIImageView *> *SGRCreatorFaces(UIView *root) {
    if (!root) return @[];
    BOOL rtl = root.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    // Every avatar, its picture shown or not, so its initial is never the name; and each one with a shown image view,
    // the first of them, its face.
    NSHashTable<UIView *> *avatars = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
    NSMapTable<UIView *, UIImageView *> *shownFaces = [NSMapTable strongToStrongObjectsMapTable];
    NSMutableArray<UIView *> *found = [NSMutableArray array];
    SGForEachView(root, ^(UIView *v) {
        if (![v isKindOfClass:UIImageView.class]) return;
        UIView *avatar = avatarOf((UIImageView *)v, root);
        if (!avatar) return;
        [avatars addObject:avatar];
        if (!shownIn(v, root) || [shownFaces objectForKey:avatar]) return;
        [shownFaces setObject:(UIImageView *)v forKey:avatar];
        [found addObject:avatar];
    });
    // The name: the first label shown with text that is not an avatar's initial.
    __block UILabel *name = nil;
    SGForEachView(root, ^(UIView *v) {
        if (name || ![v isKindOfClass:UILabel.class] || !shownIn(v, root)) return;
        for (UIView *up = v.superview; up && up != root; up = up.superview) {
            if ([avatars containsObject:up]) return;
        }
        if ([((UILabel *)v).text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length) name = (UILabel *)v;
    });
    // With no name shown there is nothing to tell a face from a badge after it by: none.
    if (!name) return @[];
    CGFloat nameEdge = leadingEdge(name, root, rtl);
    NSMutableArray<UIImageView *> *faces = [NSMutableArray array];
    NSMapTable<UIView *, NSNumber *> *edges = [NSMapTable strongToStrongObjectsMapTable];
    for (UIView *avatar in found) {
        CGFloat x = leadingEdge(avatar, root, rtl);
        if (rtl ? x <= nameEdge : x >= nameEdge) continue;
        UIImageView *face = [shownFaces objectForKey:avatar];
        [faces addObject:face];
        [edges setObject:@(x) forKey:face];
    }
    return [faces sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(UIView *one, UIView *other) {
        NSComparisonResult order = [[edges objectForKey:one] compare:[edges objectForKey:other]];
        return rtl ? -order : order;
    }];
}

@implementation SGRHeaderInfo {
    UILabel *_title, *_creator, *_length, *_about;
    UIImageView *_logo;
    UIImageView *_picture;   // the creator's, round, before the name
    __weak UIImageView *_pictureSource;
    // The creator's faces (-showCreatorFaces:from:), made with the first of them: the circles in a view of their own
    // before the name, Spotify's image views they are read from (weakly), the line and the name they belong to, and the
    // pictures they show. A rebuild is pending while facesPending is set.
    UIView *_faces;
    NSPointerArray *_faceSources;
    __weak UIView *_faceParent;
    NSString *_faceName;
    NSArray<UIImage *> *_faceImages;
    BOOL _facesPending;
    // What the faces' circles and cut rings were last made for (-sgr_placeFaces:rtl:).
    CGFloat _placedSide, _placedStep;
    BOOL _placedRTL;
    NSUInteger _placedCount;
    UIImage *_titleImage;   // what the title's place is laid out for; the logo keeps its picture while it fades out
    SGRMirrorButton *_shuffle, *_trailing;
    SGRPlayCapsule *_play;
    __weak UIView *_creatorLink;
    // contentHeightForWidth:'s last answer, for _measuredWidth; a negative width is none. Cleared when the text or
    // the title picture changes, the only things it measures.
    CGFloat _measuredWidth, _measuredHeight;
    // Where the content starts, as last laid out; and the mask that clips it under the top bar (-clipUnderTopBar).
    CGFloat _contentTop;
    CAGradientLayer *_barClip;
    BOOL _clipsUnderBar;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _measuredWidth = -1;
    _title = infoLabel(self, SGCategoryCappedFont(UIFontTextStyleTitle2, UIFontWeightBold, UIContentSizeCategoryExtraLarge),
                       SGRPrimary(), 2, NSTextAlignmentCenter);
    _title.accessibilityTraits = UIAccessibilityTraitHeader;
    _creator = infoLabel(self, SGCategoryCappedFont(UIFontTextStyleBody, UIFontWeightRegular, UIContentSizeCategoryExtraLarge),
                         SGRSecondary(), 1, NSTextAlignmentCenter);
    _length = infoLabel(self, SGCategoryCappedFont(UIFontTextStyleFootnote, UIFontWeightRegular, UIContentSizeCategoryExtraLarge),
                        SGRTertiary(), 1, NSTextAlignmentCenter);
    _about = infoLabel(self, SGCategoryCappedFont(UIFontTextStyleFootnote, UIFontWeightRegular, UIContentSizeCategoryExtraLarge),
                       SGRSecondary(), 2, NSTextAlignmentNatural);
    _picture = [UIImageView new];
    _picture.contentMode = UIViewContentModeScaleAspectFill;
    _picture.clipsToBounds = YES;
    _picture.hidden = YES;
    [self addSubview:_picture];

    _shuffle = [[SGRMirrorButton alloc] initWithFrame:CGRectZero];
    _shuffle.fallbackGlyph = [UIImage systemImageNamed:@"shuffle"];
    // White like the buttons beside it while off -- Spotify's off gray read as a disabled button next to the
    // white download (issue #65) -- and the accent while on, so its state still shows.
    _shuffle.glyphColor = SGRPrimary();
    _shuffle.onGlyphColor = SGRAccent();
    _play = [[SGRPlayCapsule alloc] initWithFrame:CGRectZero];
    [self sgr_fillPlay];
    _trailing = [[SGRMirrorButton alloc] initWithFrame:CGRectZero];
    for (UIView *button in @[_shuffle, _play, _trailing]) {
        button.hidden = YES;
        [self addSubview:button];
    }
    return self;
}

// Touches only for the buttons and, where there is one, the creator line: the rest of the text lets a
// pull or a tap through to the page under it.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    // The creator label is the width of the view, so the label itself answers a touch well away from the
    // name; both it and the view answer only where the name is drawn.
    if (hit == self || hit == _creator) return [self sgr_creatorHit:point];
    return hit;
}

// The picture often arrives from the network with the page already on screen. There the picture and the
// title cross over, and the block makes room for the picture in one move rather than in a frame, the picture
// growing out of the title's place; out of a window it all happens at once.
- (void)showTitleImage:(UIImage *)image {
    if (_titleImage == image) return;
    if (!_logo) {
        _logo = [UIImageView new];
        _logo.contentMode = UIViewContentModeScaleAspectFit;
        _logo.isAccessibilityElement = YES;
        _logo.accessibilityTraits = UIAccessibilityTraitHeader;
        _logo.alpha = 0;
        [self addSubview:_logo];
    }
    _titleImage = image;
    _measuredWidth = -1;
    _title.accessibilityElementsHidden = image != nil;
    if (image) {
        if (!_logo.image) [UIView performWithoutAnimation:^{ self->_logo.frame = self->_title.frame; }];
        _logo.image = image;
        _logo.hidden = NO;
    }
    [self setNeedsLayout];
    void (^fade)(void) = ^{
        self->_logo.alpha = image ? 1 : 0;
        self->_title.alpha = image ? 0 : 1;
    };
    void (^faded)(BOOL) = ^(BOOL finished) {
        if (self->_titleImage) return;
        self->_logo.image = nil;
        self->_logo.hidden = YES;
    };
    if (!self.window) {
        fade();
        faded(YES);
        return;
    }
    SGRAnimate(SGRMotionFade, fade, faded);
    SGRAnimateLayout(self, ^{ [self layoutIfNeeded]; }, nil);
}

// The space under a line: a picture needs more room under it than a line of text does.
- (CGFloat)sgr_gapAfter:(UILabel *)label {
    if (label == _title && _titleImage) return 8;
    return label == _creator ? 4 : 2;
}

// The title's line: the picture's fitted height where there is a picture, the label's otherwise.
- (CGSize)sgr_sizeOf:(UILabel *)label width:(CGFloat)text {
    if (label != _title || !_titleImage) return [label sizeThatFits:CGSizeMake(text, CGFLOAT_MAX)];
    CGSize image = _titleImage.size;
    if (image.width <= 0 || image.height <= 0) return CGSizeZero;
    CGFloat scale = MIN(text * kLogoWidthShare / image.width, kLogoMaxHeight / image.height);
    return CGSizeMake(round(image.width * scale), round(image.height * scale));
}

- (BOOL)showTitle:(NSString *)title creator:(NSString *)creator length:(NSString *)length about:(NSString *)about {
    BOOL changed = NO;
    changed |= setText(_title, title);
    changed |= setText(_creator, creator);
    changed |= setText(_length, length);
    changed |= setText(_about, about);
    if (changed) {
        _measuredWidth = -1;
        [self setNeedsLayout];
    }
    return changed;
}

// The creator line, tappable. The label is as wide as the view and centered, so the target is narrowed to
// the text itself -- a tap either side of a short name belongs to the page under it, which a pull down
// starts on. Spotify's own control stays concealed where it is and only fires.
- (void)showCreatorLink:(UIView *)control {
    _creatorLink = control;
    BOOL live = control != nil;
    if (_creator.userInteractionEnabled == live) return;
    _creator.userInteractionEnabled = live;
    _creator.accessibilityTraits = live ? UIAccessibilityTraitButton : UIAccessibilityTraitStaticText;
    if (!live || _creator.gestureRecognizers.count) return;
    [_creator addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sgr_creatorTapped)]];
}

- (void)sgr_creatorTapped {
    SGRActivate(_creatorLink);
}

- (void)showCreatorPicture:(UIImageView *)source {
    if (source != _pictureSource) {
        _pictureSource = source;
        __weak SGRHeaderInfo *weakSelf = self;
        if (source) SGRObserveImage(source, ^(UIImageView *view) {
            SGRHeaderInfo *info = weakSelf;
            if (info && view == info->_pictureSource) [info sgr_takePicture:view.image];
        });
    }
    [self sgr_takePicture:source.image];
}

// The picture fades in where it lands with the page on screen; the name makes room for it in the same move.
- (void)sgr_takePicture:(UIImage *)image {
    if (image == _picture.image) return;
    BOOL appears = image && !_picture.image;
    _picture.image = image;
    _picture.hidden = image == nil;
    [self setNeedsLayout];
    if (!appears || !self.window) return;
    _picture.alpha = 0;
    SGRAnimate(SGRMotionFade, ^{ self->_picture.alpha = 1; }, nil);
    SGRAnimateLayout(self, ^{ [self layoutIfNeeded]; }, nil);
}

- (void)showCreatorFaces:(NSArray<UIImageView *> *)sources from:(UIView *)parent {
    NSString *name = _creator.text ?: @"";
    if (parent != _faceParent || ![name isEqualToString:_faceName]) {
        // Another album's line, or the header reused for one: what was drawn is not its faces.
        _faceParent = parent;
        _faceName = name;
        [self sgr_setFaces:@[]];
    }
    if (![_faceSources.allObjects isEqualToArray:sources ?: @[]]) {
        _faceSources = [NSPointerArray weakObjectsPointerArray];
        __weak SGRHeaderInfo *weakSelf = self;
        for (UIImageView *source in sources) {
            [_faceSources addPointer:(__bridge void *)source];
            SGRObserveImage(source, ^(UIImageView *view) { [weakSelf sgr_faceChanged:view]; });
        }
    }
    [self sgr_updateFaces];
}

// A picture set on one of the faces' image views, Spotify's: the faces are drawn again once for all that land together.
- (void)sgr_faceChanged:(UIImageView *)view {
    if (_facesPending || ![_faceSources.allObjects containsObject:view]) return;
    _facesPending = YES;
    __weak SGRHeaderInfo *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        SGRHeaderInfo *info = weakSelf;
        if (!info) return;
        info->_facesPending = NO;
        [info sgr_updateFaces];
    });
}

- (void)sgr_updateFaces {
    // Shown as they are now, not as they were at the header's pass: a picture can land in a view hidden since.
    UIView *parent = _faceParent;
    NSMutableArray<UIImage *> *images = [NSMutableArray array];
    NSUInteger shown = 0;
    for (UIImageView *source in _faceSources.allObjects) {
        if (!parent || !shownIn(source, parent)) continue;
        shown++;
        if (source.image && images.count < kMaxFaces) [images addObject:source.image];
    }
    // Spotify empties its image views before it fills them again: the faces drawn stay while shown ones wait for theirs.
    if (!images.count && shown) return;
    [self sgr_setFaces:images];
}

// The faces fade in where they land with the page on screen, the name making room for them in the same move.
- (void)sgr_setFaces:(NSArray<UIImage *> *)images {
    if ([_faceImages ?: @[] isEqualToArray:images]) return;
    BOOL appears = images.count && !_faceImages.count;
    _faceImages = images.count ? images : nil;
    if (!_faces && images.count) {
        _faces = [UIView new];
        _faces.userInteractionEnabled = NO;
        _faces.accessibilityElementsHidden = YES;
        [self addSubview:_faces];
    }
    while (_faces.subviews.count < images.count) {
        UIImageView *face = [UIImageView new];
        face.contentMode = UIViewContentModeScaleAspectFill;
        face.clipsToBounds = YES;
        [_faces addSubview:face];
    }
    [_faces.subviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger i, BOOL *stop) {
        UIImageView *face = (UIImageView *)view;
        face.image = i < images.count ? images[i] : nil;
        face.hidden = face.image == nil;
    }];
    _faces.hidden = !images.count;
    [self setNeedsLayout];
    if (!appears || !self.window) return;
    _faces.alpha = 0;
    SGRAnimate(SGRMotionFade, ^{ self->_faces.alpha = 1; }, nil);
    SGRAnimateLayout(self, ^{ [self layoutIfNeeded]; }, nil);
}

// The circles a line's height and a point across, at most kMaxFaceSide.
- (CGFloat)sgr_faceSide {
    return MIN(ceil(_creator.font.lineHeight) + 1, kMaxFaceSide);
}

- (CGFloat)sgr_facesWidth {
    CGFloat side = [self sgr_faceSide];
    return side + (_faceImages.count - 1) * round(side * kFaceStep);
}

// The faces in `frame`, the leading one at the leading edge; each next one has the ring around the one before cut out.
- (void)sgr_placeFaces:(CGRect)frame rtl:(BOOL)rtl {
    _faces.frame = frame;
    CGFloat side = frame.size.height, step = round(side * kFaceStep);
    NSUInteger count = _faceImages.count;
    for (NSUInteger i = 0; i < count; i++) {
        UIImageView *face = _faces.subviews[i];
        CGFloat x = rtl ? frame.size.width - side - i * step : i * step;
        face.frame = CGRectMake(x, 0, side, side);
    }
    // The circles and their cut rings follow from these alone (kFaceRing is fixed): made again only when one changes.
    if (side == _placedSide && step == _placedStep && rtl == _placedRTL && count == _placedCount) return;
    _placedSide = side;
    _placedStep = step;
    _placedRTL = rtl;
    _placedCount = count;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (NSUInteger i = 0; i < count; i++) {
        UIImageView *face = _faces.subviews[i];
        face.layer.cornerRadius = side / 2;
        if (i == 0) {
            face.layer.mask = nil;
            continue;
        }
        // The one before, its centre in this one's bounds, rtl to the right of it.
        CGPoint before = CGPointMake(side / 2 + (rtl ? step : -step), side / 2);
        UIBezierPath *cut = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, side, side)];
        CGFloat ring = side / 2 + kFaceRing;
        [cut appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(before.x - ring, before.y - ring, 2 * ring, 2 * ring)]];
        CAShapeLayer *mask = [face.layer.mask isKindOfClass:CAShapeLayer.class] ? (CAShapeLayer *)face.layer.mask : nil;
        if (!mask) {
            mask = [CAShapeLayer layer];
            mask.fillRule = kCAFillRuleEvenOdd;
            face.layer.mask = mask;
        }
        mask.frame = CGRectMake(0, 0, side, side);
        mask.path = cut.CGPath;
    }
    [CATransaction commit];
}

// The creator line takes a touch only where its text and its picture are; everything else of the view is the
// page's. The label is laid out at the text's own width (-layoutSubviews).
- (UIView *)sgr_creatorHit:(CGPoint)point {
    if (!_creator.userInteractionEnabled || _creator.hidden) return nil;
    CGRect line = _picture.hidden ? _creator.frame : CGRectUnion(_creator.frame, _picture.frame);
    if (_faces && !_faces.hidden) line = CGRectUnion(line, _faces.frame);
    return CGRectContainsPoint(CGRectInset(line, -8, -6), point) ? _creator : nil;
}

- (void)showShuffle:(UIView *)shuffle play:(UIView *)play trailing:(UIView *)trailing
   trailingFallback:(UIImage *)trailingFallback playColor:(UIColor *)playColor {
    _trailing.fallbackGlyph = trailingFallback;
    if (_trailing.readState != self.trailingState) {
        _trailing.readState = self.trailingState;
        _trailing.stateOffSymbol = self.trailingOffSymbol;
        _trailing.stateOnSymbol = self.trailingOnSymbol;
    }
    if (shuffle) [_shuffle feedFrom:shuffle];
    if (play) {
        if (playColor && playInPageColour()) _play.contentColor = playColor;
        // The accent as it is now: Automatic moves it with the page.
        if (_play.cutOut) [self sgr_fillPlay];
        [_play feedFrom:play];
    }
    // Another of Spotify's buttons in the trailing place (save becoming download once the playlist is saved) is
    // a crossfade, a change of what the button is rather than a move.
    if (trailing && _trailing.source && trailing != _trailing.source && !_trailing.hidden && self.window) {
        [UIView transitionWithView:_trailing duration:SGRCrossfade options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{ [self->_trailing feedFrom:trailing]; } completion:nil];
    }
    else if (trailing) [_trailing feedFrom:trailing];

    BOOL changed = NO;
    NSArray<UIView *> *buttons = @[_shuffle, _play, _trailing];
    NSArray<NSNumber *> *shown = @[@(shuffle != nil), @(play != nil), @(trailing != nil)];
    for (NSUInteger i = 0; i < buttons.count; i++) {
        BOOL hide = !shown[i].boolValue;
        if (buttons[i].hidden != hide) {
            buttons[i].hidden = hide;
            changed = YES;
        }
    }
    if (changed) [self setNeedsLayout];
}

- (void)trailingStateChanged {
    if (_trailing.source) [_trailing feedFrom:_trailing.source];
}

- (void)setRoundPlay:(BOOL)roundPlay {
    if (_roundPlay == roundPlay) return;
    _roundPlay = roundPlay;
    _play.round = roundPlay;
    _play.cutOut = roundPlay && cutOutPlay();
    [self sgr_fillPlay];
    _measuredWidth = -1;
    [self setNeedsLayout];
}

// Play's fill: white, or the accent for a cut-out Play while SGRKeyAccentPlay is on.
- (void)sgr_fillPlay {
    _play.fillColor = _play.cutOut && accentPlay() ? SGRAccent() : UIColor.whiteColor;
}

- (CGFloat)sgr_rowHeight {
    return _roundPlay ? kRoundRow : SGRActionHeight;
}

- (void)clipUnderTopBar {
    _clipsUnderBar = YES;
    CALayer *mask = self.layer.mask;
    if (mask && mask != _barClip) return;
    UIWindow *window = self.window;
    CGFloat line = [self convertPoint:CGPointMake(0, window.safeAreaInsets.top + kTopBar) fromView:nil].y;
    BOOL under = window && line - _contentTop >= kUnderBar;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (!under) {
        if (mask) self.layer.mask = nil;
    } else {
        if (!_barClip) {
            _barClip = [CAGradientLayer layer];
            _barClip.colors = @[(id)UIColor.clearColor.CGColor, (id)UIColor.blackColor.CGColor];
        }
        // Sized and graded once per header size: as tall as the header, and at least the fade, so it covers all of
        // the header under any line in it and the fade keeps its length. A scroll only moves its top edge to the line.
        CGSize size = self.bounds.size;
        CGRect bounds = CGRectMake(0, 0, size.width, MAX(kBarFade, size.height));
        if (!CGRectEqualToRect(_barClip.bounds, bounds)) {
            _barClip.bounds = bounds;
            _barClip.locations = @[@0, @(kBarFade / bounds.size.height)];
        }
        CGPoint position = CGPointMake(CGRectGetMidX(bounds), line + CGRectGetMidY(bounds));
        if (!CGPointEqualToPoint(_barClip.position, position)) _barClip.position = position;
        if (!mask) self.layer.mask = _barClip;
    }
    [CATransaction commit];
}

- (CGFloat)contentHeightForWidth:(CGFloat)width {
    if (width == _measuredWidth) return _measuredHeight;
    CGFloat text = MAX(0, width - 2 * kSide), height = 0;
    UILabel *previous = nil;
    for (UILabel *label in @[_title, _creator, _length]) {
        if (label.hidden) continue;
        if (previous) height += [self sgr_gapAfter:previous];
        height += ceil([self sgr_sizeOf:label width:text].height);
        previous = label;
    }
    if (previous) height += kRowAbove;
    height += [self sgr_rowHeight];
    if (!_about.hidden) height += kAboutAbove + ceil([_about sizeThatFits:CGSizeMake(text, CGFLOAT_MAX)].height);
    _measuredWidth = width;
    _measuredHeight = height;
    return height;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.bounds.size.width, text = MAX(0, width - 2 * kSide);
    CGFloat content = [self contentHeightForWidth:width];
    CGFloat y = round(self.bounds.size.height - SGRHeaderInfoBottom - content);
    if (self.pinnedTop > 0 && self.pinnedTop + content <= self.bounds.size.height) y = round(self.pinnedTop);
    _contentTop = y;
    // No name, no picture: it belongs to the line.
    _picture.hidden = !_picture.image || _creator.hidden;
    BOOL faces = _faceImages.count && !_creator.hidden;
    _faces.hidden = !faces;

    UILabel *previous = nil;
    for (UILabel *label in @[_title, _creator, _length]) {
        if (label.hidden) continue;
        if (previous) y += [self sgr_gapAfter:previous];
        CGSize size = [self sgr_sizeOf:label width:text];
        CGFloat height = ceil(size.height);
        label.frame = CGRectMake(kSide, y, text, height);
        // The name at its own width, so a tap beside it is the page's (-sgr_creatorHit:), and before it the
        // picture, a line high so the line keeps its height, the two centered together. The picture leads, so it
        // is on the right in a right-to-left language.
        // The faces, where the creator has them, take the picture's place: centred on the line, which keeps its height.
        if (label == _creator) {
            CGFloat lead = faces ? [self sgr_facesWidth] : height;
            CGFloat picture = faces || !_picture.hidden ? lead + kPictureGap : 0;
            CGFloat named = MIN(ceil(size.width), MAX(0, text - picture));
            CGFloat x = round((width - picture - named) / 2);
            BOOL rtl = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
            CGFloat leadX = rtl ? x + named + kPictureGap : x;
            if (faces) {
                CGFloat side = [self sgr_faceSide], scale = self.traitCollection.displayScale ?: UIScreen.mainScreen.scale;
                [self sgr_placeFaces:CGRectMake(leadX, y + round((height - side) / 2 * scale) / scale, lead, side) rtl:rtl];
            } else {
                _picture.frame = CGRectMake(leadX, y, height, height);
                _picture.layer.cornerRadius = height / 2;
            }
            label.frame = CGRectMake(rtl ? x : x + picture, y, named, height);
        }
        if (label == _title && _titleImage) {
            _logo.frame = CGRectMake(round((width - size.width) / 2), y, size.width, height);
            _logo.accessibilityLabel = _title.text;
        }
        y += height;
        previous = label;
    }
    if (previous) y += kRowAbove;

    // Play on the middle of the page, the other two hung off its sides, so it holds its place whether both
    // are there or not.
    CGFloat row = [self sgr_rowHeight];
    if (_roundPlay) {
        // The circle the row's height; the round buttons level with its middle.
        CGFloat side = SGRGlassCircleSize, level = y + round((row - side) / 2);
        CGRect play = CGRectMake(round((width - row) / 2), y, row, row);
        _play.frame = play;
        _shuffle.frame = CGRectMake(CGRectGetMinX(play) - kRoundSpacing - side, level, side, side);
        _trailing.frame = CGRectMake(CGRectGetMaxX(play) + kRoundSpacing, level, side, side);
    } else {
        CGFloat side = row;
        // As wide as its word, short of pushing the other two off the page.
        CGFloat playWidth = MIN(MAX(kPlayWidth, [_play sgr_width]), width - 2 * (kSide + side + kRowSpacing));
        CGRect play = CGRectMake(round((width - playWidth) / 2), y, playWidth, side);
        _play.frame = play;
        _shuffle.frame = CGRectMake(CGRectGetMinX(play) - kRowSpacing - side, y, side, side);
        _trailing.frame = CGRectMake(CGRectGetMaxX(play) + kRowSpacing, y, side, side);
    }
    y += row;

    if (!_about.hidden) {
        y += kAboutAbove;
        _about.frame = CGRectMake(kSide, y, text, ceil([_about sizeThatFits:CGSizeMake(text, CGFLOAT_MAX)].height));
    }
    if (_clipsUnderBar) [self clipUnderTopBar];
}

@end
