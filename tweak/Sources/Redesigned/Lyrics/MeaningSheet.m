#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"
#import "MeaningSheet.h"
#import "Redesigned/Kit/SGRTokens.h"
#import "Shared/LyricsTranslation/LyricsTranslation.h"

static const CGFloat kSide = 24, kTop = 28, kGap = 12;
// The footer's row is drawn 22pt tall; its buttons take touches over 44, centered on it.
static const CGFloat kRow = 22, kTouch = 44;
// One annotation's translation is asked for only when its reader taps for it, and the sheet keeps this many.
static const NSUInteger kKeptTranslations = 24;

static NSString *authorName(SGLyricsMeaningAuthor author) {
    switch (author) {
        case SGLyricsMeaningByArtist: return SGL(@"settings.lyrics.meanings.choice.artist", @"From the artist");
        case SGLyricsMeaningByEditors: return SGL(@"settings.lyrics.meaning.by_editors", @"Genius editors");
        case SGLyricsMeaningByCommunity: return SGL(@"settings.lyrics.meaning.by_community", @"Genius community");
    }
    return nil;
}

static NSString *authorSymbol(SGLyricsMeaningAuthor author) {
    return author == SGLyricsMeaningByArtist ? @"checkmark.seal.fill" : author == SGLyricsMeaningByEditors ? @"checkmark.circle" : @"person.2";
}

// The annotation's text with each web address in it made a link. Only http and https ones are, so an
// address-like bit of text never opens anything else.
static NSAttributedString *linkedBody(NSString *body) {
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody],
                                 NSForegroundColorAttributeName: SGRPrimary()};
    NSMutableAttributedString *out = [[NSMutableAttributedString alloc] initWithString:body ?: @"" attributes:attributes];
    static NSDataDetector *detector;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil]; });
    for (NSTextCheckingResult *match in [detector matchesInString:out.string options:0 range:NSMakeRange(0, out.length)]) {
        NSString *scheme = match.URL.scheme.lowercaseString;
        if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"])
            [out addAttribute:NSLinkAttributeName value:match.URL range:match.range];
    }
    return out;
}

@interface SGRMeaningSheet : UIViewController
@end

@implementation SGRMeaningSheet {
    NSString *_lineText;
    NSArray<SGLyricsMeaning *> *_meanings;
    NSUInteger _index;
    UIScrollView *_scroll;
    UILabel *_quote, *_count, *_status;
    UITextView *_body;
    UIButton *_author, *_next, *_open, *_translate;
    // The sheet's own: an explanation's translation lives as long as this sheet does, never as a song's line.
    // Each is @[body, quote] for one keyOnScreen.
    NSMutableDictionary<NSArray *, NSArray<NSString *> *> *_translations;
    NSMutableArray<NSArray *> *_translationOrder;
    NSMutableSet<NSArray *> *_inFlight;
    // Only the latest failure needs a message, not an unbounded history of failed languages.
    NSArray *_failedKey;
    // The annotation on screen shows its own words rather than its translation.
    BOOL _original;
}

- (instancetype)initWithLine:(NSString *)lineText meanings:(NSArray<SGLyricsMeaning *> *)meanings {
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    _lineText = [lineText copy];
    _meanings = [meanings copy];
    _translations = [NSMutableDictionary dictionary];
    _translationOrder = [NSMutableArray array];
    _inFlight = [NSMutableSet set];
    self.modalPresentationStyle = UIModalPresentationPageSheet;
    SGPresentDark(self);
    UISheetPresentationController *sheet = self.sheetPresentationController;
    sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent, UISheetPresentationControllerDetent.largeDetent];
    sheet.prefersGrabberVisible = YES;
    sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
    // On the landscape lyrics (compact height) the sheet would otherwise cover the whole screen with no
    // grabber and nothing to pull down; edge attached it is a card on the bottom edge, inside the safe area.
    sheet.prefersEdgeAttachedInCompactHeight = YES;
    return self;
}

- (UILabel *)labelWithFont:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.numberOfLines = 0;
    label.font = font;
    label.textColor = color;
    label.adjustsFontForContentSizeCategory = YES;
    [_scroll addSubview:label];
    return label;
}

- (UIButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
    config.title = title;
    config.contentInsets = NSDirectionalEdgeInsetsZero;
    config.baseForegroundColor = SGRAccent();
    __weak SGRMeaningSheet *weakSelf = self;
    config.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
        NSMutableDictionary *out = [attributes mutableCopy];
        out[NSFontAttributeName] = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
            scaledFontForFont:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]
            compatibleWithTraitCollection:weakSelf.traitCollection];
        return out;
    };
    UIButton *button = [UIButton buttonWithConfiguration:config primaryAction:nil];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [_scroll addSubview:button];
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // From iOS 26 a sheet short of full height is Liquid Glass, which the system draws and turns opaque
    // itself at the large detent and under Reduce Transparency; a fill here would cover it.
    if (@available(iOS 26.0, *)) {
    } else {
        self.view.backgroundColor = UIColor.systemBackgroundColor;
    }
    _scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.alwaysBounceVertical = YES;
    [self.view addSubview:_scroll];

    _quote = [self labelWithFont:[UIFont systemFontOfSize:20 weight:UIFontWeightBold] color:SGRPrimary()];
    UIButtonConfiguration *badge = [UIButtonConfiguration filledButtonConfiguration];
    badge.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    badge.buttonSize = UIButtonConfigurationSizeMini;
    badge.imagePadding = 4;
    badge.contentInsets = NSDirectionalEdgeInsetsMake(4, 10, 4, 10);
    badge.baseBackgroundColor = [SGRAccent() colorWithAlphaComponent:0.2];
    badge.baseForegroundColor = SGRAccent();
    _author = [UIButton buttonWithConfiguration:badge primaryAction:nil];
    _author.userInteractionEnabled = NO;
    [_scroll addSubview:_author];
    // A text view rather than a label so the links in an annotation (Genius's text carries bare URLs) can be
    // tapped. It never scrolls or edits; the sheet's scroll view does the scrolling.
    _body = [UITextView new];
    _body.editable = NO;
    _body.selectable = YES;
    _body.scrollEnabled = NO;
    _body.backgroundColor = UIColor.clearColor;
    _body.textContainerInset = UIEdgeInsetsZero;
    _body.textContainer.lineFragmentPadding = 0;
    _body.adjustsFontForContentSizeCategory = YES;
    _body.linkTextAttributes = @{NSForegroundColorAttributeName: SGRAccent(),
                                 NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)};
    [_scroll addSubview:_body];
    _count = [self labelWithFont:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular] color:SGRTertiary()];
    _count.numberOfLines = 1;
    // Said under the words rather than in place of them, so a translation is never taken for Genius's own text.
    _status = [self labelWithFont:[UIFont systemFontOfSize:13 weight:UIFontWeightRegular] color:SGRTertiary()];
    _status.numberOfLines = 0;
    // The target language and the services are read per drawing: another language's answer is not this
    // language's, and a service that goes is no longer offered.
    for (NSNotificationName name in @[SGLyricsTranslationsDidChangeNotification, SGLyricsTranslationServiceSettingsDidChangeNotification]) {
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(settingsChanged) name:name object:nil];
    }
    _next = [self buttonWithTitle:SGL(@"settings.lyrics.meaning.next", @"Next") action:@selector(showNext)];
    _open = [self buttonWithTitle:SGL(@"settings.lyrics.meaning.genius", @"View on Genius") action:@selector(openGenius)];
    _translate = [self buttonWithTitle:SGL(@"settings.lyrics.meaning.translate", @"Translate") action:@selector(toggleTranslation)];
    [self show];
}

- (void)show {
    SGLyricsMeaning *meaning = _meanings[_index];
    NSArray *key = [self keyOnScreen];
    NSArray<NSString *> *translated = _original ? nil : _translations[key];
    NSString *body = translated.count == 2 ? translated[0] : meaning.body;
    NSString *quote = translated.count == 2 ? translated[1] : _lineText;
    _quote.text = [NSString stringWithFormat:@"“%@”", quote ?: @""];
    UIButtonConfiguration *badge = _author.configuration;
    badge.title = authorName(meaning.author);
    badge.image = [UIImage systemImageNamed:authorSymbol(meaning.author)
                          withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold]];
    _author.configuration = badge;
    _body.attributedText = linkedBody(body);
    // The Genius writing above stays Genius's own: a translation says so, and the action says how to go back.
    // A refused one says so under the words, and the action stays for another try.
    _status.text = translated.count == 2 ? SGL(@"settings.lyrics.meaning.status.translated", @"Translated")
                  : [_failedKey isEqual:key]
                      ? SGL(@"settings.lyrics.meaning.error.translate", @"Couldn't translate") : nil;
    UIButtonConfiguration *action = _translate.configuration;
    action.title = translated.count == 2 ? SGL(@"settings.lyrics.meaning.showoriginal", @"Show Original")
                                        : SGL(@"settings.lyrics.meaning.translate", @"Translate");
    _translate.configuration = action;
    // Offered only while a translator the user set up takes the target language: nothing is asked for otherwise.
    _translate.hidden = !SGLyricsTranslateTextsAvailable();
    _count.text = _meanings.count > 1 ? [NSString stringWithFormat:@"Genius · %lu of %lu", (unsigned long)_index + 1, (unsigned long)_meanings.count]
                                      : @"Genius";
    _next.hidden = _meanings.count < 2;
    _open.hidden = !meaning.url.length;
    [self.view setNeedsLayout];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // A sheet as wide as a landscape screen reaches under the sensor housing, which the safe area keeps clear.
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGFloat left = kSide + safe.left, width = self.view.bounds.size.width - left - kSide - safe.right;
    CGFloat y = kTop;
    _quote.frame = CGRectMake(left, y, width, [_quote sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    y = CGRectGetMaxY(_quote.frame) + kGap;
    CGSize badge = [_author sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    _author.frame = CGRectMake(left, y, MIN(width, badge.width), badge.height);
    y = CGRectGetMaxY(_author.frame) + kGap + 4;
    _body.frame = CGRectMake(left, y, width, [_body sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    y = CGRectGetMaxY(_body.frame) + kGap;
    CGFloat statusHeight = _status.text.length ? [_status sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height : 0;
    _status.frame = CGRectMake(left, y, width, statusHeight);
    if (statusHeight) y += statusHeight + kGap;
    if (_translate.isHidden) {
        _translate.frame = CGRectZero;
    } else {
        CGFloat actionWidth = MAX(kTouch, [_translate sizeThatFits:CGSizeZero].width);
        _translate.frame = CGRectMake(left, y, MIN(width, actionWidth), kTouch);
        y += kTouch;
    }
    y += kGap;
    _count.frame = CGRectMake(left, y, [_count sizeThatFits:CGSizeMake(width, kRow)].width, kRow);
    CGFloat right = left + width, touchTop = y - (kTouch - kRow) / 2;
    if (!_next.hidden) {
        CGFloat side = MAX(kTouch, [_next sizeThatFits:CGSizeZero].width);
        _next.frame = CGRectMake(right - side, touchTop, side, kTouch);
        right = CGRectGetMinX(_next.frame) - 20;
    }
    if (!_open.hidden) {
        CGFloat side = MAX(kTouch, [_open sizeThatFits:CGSizeZero].width);
        _open.frame = CGRectMake(right - side, touchTop, side, kTouch);
    }
    _scroll.contentSize = CGSizeMake(self.view.bounds.size.width, touchTop + kTouch + kTop + self.view.safeAreaInsets.bottom);
}

- (void)showNext {
    _index = (_index + 1) % _meanings.count;
    // Another annotation shows its own cached answer, if one is available.
    _original = NO;
    [UIView transitionWithView:_scroll duration:0.2 options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{ [self show]; [self.view layoutIfNeeded]; } completion:nil];
    [_scroll setContentOffset:CGPointMake(0, -_scroll.adjustedContentInset.top) animated:NO];
}

#pragma mark - the translation

// A translation already kept for this annotation shows, or the annotation's own words come back. Otherwise the
// explanation and the line it quotes leave the phone once, on this tap alone; a second tap while that is running
// does nothing.
- (void)toggleTranslation {
    if (!SGLyricsTranslateTextsAvailable()) return;
    SGLyricsMeaning *meaning = _meanings[_index];
    NSString *language = SGLyricsGeminiLanguage();
    NSArray *key = [self keyOnScreen];
    if (_translations[key]) {
        _original = !_original;
        [self show];
        [_scroll setContentOffset:CGPointMake(0, -_scroll.adjustedContentInset.top) animated:NO];
        return;
    }
    if ([_inFlight containsObject:key]) return;
    NSString *body = meaning.body ?: @"";
    if (!body.length) return;
    [_inFlight addObject:key];
    _failedKey = nil;
    _original = NO;
    [self show];
    __weak SGRMeaningSheet *weakSelf = self;
    SGLyricsTranslateTexts(@[body, _lineText ?: @""], language, self.view, ^(NSArray<NSString *> *translations, NSString *error) {
        SGRMeaningSheet *self = weakSelf;
        if (!self) return;
        [self->_inFlight removeObject:key];
        // Only a sheet still on screen with this annotation in it is redrawn; the answer is kept for its own
        // either way, so coming back to it needs no second request.
        BOOL shown = self.viewIfLoaded.window != nil && !self.isBeingDismissed && [[self keyOnScreen] isEqual:key];
        if (!translations || error) {
            self->_failedKey = key;
            if (shown) [self show];
            return;
        }
        if ([self->_failedKey isEqual:key]) self->_failedKey = nil;
        [self keep:translations forKey:key];
        if (!shown) return;
        [self show];
        [self->_scroll setContentOffset:CGPointMake(0, -self->_scroll.adjustedContentInset.top) animated:NO];
    });
}

// The target language or the services changed: the words drawn again are the ones the sheet now has to offer.
- (void)settingsChanged {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self settingsChanged]; }); return; }
    if (self.viewIfLoaded.window && !self.isBeingDismissed) [self show];
}

// The index identifies this annotation within the sheet; the tuple cannot collide on delimiters in prose.
- (NSArray *)keyOnScreen {
    SGLyricsMeaning *meaning = _meanings[_index];
    return @[@(_index), meaning.url ?: @"", meaning.fragment ?: @"", meaning.body ?: @"",
             _lineText ?: @"", SGLyricsGeminiLanguage()];
}

// Bounded: the oldest answer goes once the sheet holds this many, so a long read cannot grow without end.
- (void)keep:(NSArray<NSString *> *)translated forKey:(NSArray *)key {
    if (!_translations[key] && _translationOrder.count >= kKeptTranslations) {
        NSArray *oldest = _translationOrder.firstObject;
        [_translationOrder removeObjectAtIndex:0];
        [_translations removeObjectForKey:oldest];
    }
    [_translationOrder removeObject:key];
    [_translationOrder addObject:key];
    _translations[key] = translated;
}

- (void)openGenius {
    NSURL *url = [NSURL URLWithString:_meanings[_index].url];
    if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

@end

void SGRShowMeanings(NSString *lineText, NSArray<SGLyricsMeaning *> *meanings) {
    if (!meanings.count) return;
    UIViewController *top = SGTopController();
    if (!top || [top isKindOfClass:SGRMeaningSheet.class]) return;
    [top presentViewController:[[SGRMeaningSheet alloc] initWithLine:lineText meanings:meanings] animated:YES completion:nil];
}
