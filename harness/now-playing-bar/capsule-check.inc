@interface HarnessPlatterView : UIView @end
@implementation HarnessPlatterView @end

static BOOL whiteTint(UIColor *color) {
    CGFloat r, g, b, a;
    return [color getRed:&r green:&g blue:&b alpha:&a] && r == 1 && g == 1 && b == 1 && a == 1;
}

static void checkCapsule(void) {
    UIWindow *window = [(id)UIApplication.sharedApplication.delegate window];
    UIViewController *root = window.rootViewController;
    root.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.09 blue:0.14 alpha:1];
    BOOL pad = window.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad;
    if (getenv("HARNESS_COMPACT")) window.traitOverrides.horizontalSizeClass = UIUserInterfaceSizeClassCompact;
    BOOL wide = pad && !getenv("HARNESS_COMPACT");
    BOOL rtl = getenv("HARNESS_RTL") != NULL;
    CGFloat width = root.view.bounds.size.width, height = wide ? 76 : 56;
    UIView *tabs = [[UIView alloc] initWithFrame:CGRectMake(rtl ? width - 304 : 24, root.view.bounds.size.height - 110, 280, height)];
    tabs.accessibilityIdentifier = @"elements-tabs-view-identifier";
    UIView *platter = [[HarnessPlatterView alloc] initWithFrame:tabs.bounds];
    platter.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    platter.layer.cornerRadius = height / 2;
    [tabs addSubview:platter];
    [root.view addSubview:tabs];
    UIViewController *container = [UIViewController new], *bar = [UIViewController new];
    [root addChildViewController:container];
    [root.view addSubview:container.view];
    container.view.frame = CGRectMake(wide ? (rtl ? 8 : width - 376) : 16, root.view.bounds.size.height - 110, wide ? 368 : width - 32, height);
    [container addChildViewController:bar];
    [container.view addSubview:bar.view];
    bar.view.frame = CGRectMake(8, 0, container.view.bounds.size.width - 16, height);
    UIView *card = [[UIView alloc] initWithFrame:bar.view.bounds];
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    card.backgroundColor = UIColor.darkGrayColor;
    [bar.view addSubview:card];
    CGFloat artSide = height - 16;
    UIImageView *cover = [[UIImageView alloc] initWithFrame:CGRectMake(rtl ? card.bounds.size.width - artSide - 8 : 8, 8, artSide, artSide)];
    if (rtl) cover.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    cover.image = [UIImage systemImageNamed:@"music.note"];
    cover.backgroundColor = UIColor.systemIndigoColor;
    cover.tintColor = UIColor.whiteColor;
    cover.layer.cornerRadius = 4;
    [card addSubview:cover];
    UILabel *title = [UILabel new];
    title.text = @"We Are The People";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    title.adjustsFontForContentSizeCategory = YES;
    UIStackView *buttons = [UIStackView new];
    UIButton *play = [UIButton buttonWithType:UIButtonTypeSystem];
    play.accessibilityIdentifier = kPlayId;
    play.accessibilityLabel = @"Play";
    if (!wide) play.tintColor = UIColor.whiteColor;
    [play setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    [play.widthAnchor constraintEqualToConstant:44].active = YES;
    [buttons addArrangedSubview:play];
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[title, buttons]];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:height - 8],
        [row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [row.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [row.heightAnchor constraintEqualToConstant:44]
    ]];
    sg_state = [SPTPlayerState new];
    sg_state.track = makeTrack(@"We Are The People", @"Canon");
    sg_state.options = [SPTPlayerOptions new];
    sg_player = [SGHarnessPlayer new];
    // A trait override alone leaves UIKit's semantic layout LTR on an English/Korean simulator.
    // Mirror the fixture's Spotify views together, as a right-to-left app locale does.
    if (rtl) SGForEachView(root.view, ^(UIView *view) {
        view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    });
    HARNESS_CHECK(bar.view.effectiveUserInterfaceLayoutDirection ==
                  (rtl ? UIUserInterfaceLayoutDirectionRightToLeft : UIUserInterfaceLayoutDirectionLeftToRight));
    [root.view layoutIfNeeded];
    styleNowPlayingBar(container);
    [root.view layoutIfNeeded];
    styleNowPlayingBar(container);
    [root.view layoutIfNeeded];
    NSArray *extras = objc_getAssociatedObject(bar.view, &kCapsuleKey);
    HARNESS_CHECK(wide ? extras.count == 4 : extras.count == 0);
    if (wide) {
        CGFloat radius = 0;
        CGRect capsule = SGRNowPlayingCardFrameIn(root.view, &radius);
        HARNESS_CHECK(fabs(radius - height / 2) < 1);
        HARNESS_CHECK(rtl ? CGRectGetMaxX(capsule) <= CGRectGetMinX(tabs.frame) - 16 :
                           CGRectGetMinX(capsule) >= CGRectGetMaxX(tabs.frame) + 16);
        HARNESS_CHECK(whiteTint(play.tintColor));
        HARNESS_CHECK(whiteTint(sg_shuffle.tintColor) && whiteTint(sg_repeat.tintColor));
        CGRect previous = [play convertRect:play.bounds toView:root.view];
        CGRect artwork = [cover convertRect:cover.bounds toView:root.view];
        for (UIButton *button in extras) {
            CGRect frame = [button convertRect:button.bounds toView:root.view];
            HARNESS_CHECK(button.accessibilityLabel.length && frame.size.width >= 44 && frame.size.height >= 44);
            HARNESS_CHECK(CGRectContainsRect(capsule, frame));
            HARNESS_CHECK(!CGRectIntersectsRect(artwork, frame));
            if (!(rtl ? CGRectGetMaxX(frame) <= CGRectGetMinX(previous) :
                        CGRectGetMinX(frame) >= CGRectGetMaxX(previous))) {
                HARNESS_FAIL(@"capsule order %@ [%.17g, %.17g] after [%.17g, %.17g]; bar direction %ld, row direction %ld, semantic %ld",
                    button.accessibilityIdentifier, CGRectGetMinX(frame), CGRectGetMaxX(frame),
                    CGRectGetMinX(previous), CGRectGetMaxX(previous), (long)bar.view.effectiveUserInterfaceLayoutDirection,
                    (long)row.effectiveUserInterfaceLayoutDirection, (long)row.semanticContentAttribute);
            }
            previous = frame;
            CGPoint center = CGPointMake(CGRectGetMidX(button.bounds), CGRectGetMidY(button.bounds));
            HARNESS_CHECK([bar.view hitTest:[button convertPoint:center toView:bar.view] withEvent:nil] == button);
            [button sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
        extern BOOL sg_harnessLyricsOpened, sg_harnessQueueOpened;
        HARNESS_CHECK(sg_state.options.shufflingContext && sg_state.options.repeatingContext);
        HARNESS_CHECK(sg_harnessLyricsOpened && sg_harnessQueueOpened);
        showPlayerOptions();
        HARNESS_CHECK([sg_shuffle.accessibilityValue isEqual:@"On"]);
        HARNESS_CHECK([sg_repeat.accessibilityValue isEqual:@"All"]);
        CGFloat r, g, b, a;
        for (UIButton *button in @[sg_shuffle, sg_repeat]) {
            HARNESS_CHECK([button.tintColor getRed:&r green:&g blue:&b alpha:&a] && g > r && g > b);
        }
        if (!getenv("HARNESS_OPTIONS_ACTIVE")) {
            [sg_shuffle sendActionsForControlEvents:UIControlEventTouchUpInside];
            [sg_repeat sendActionsForControlEvents:UIControlEventTouchUpInside];
            [sg_repeat sendActionsForControlEvents:UIControlEventTouchUpInside];
            showPlayerOptions();
            HARNESS_CHECK(!sg_state.options.shufflingContext && !sg_state.options.repeatingContext && !sg_state.options.repeatingTrack);
            HARNESS_CHECK(whiteTint(sg_shuffle.tintColor) && whiteTint(sg_repeat.tintColor));
        }
        NSLog(@"[harness] capsule options: shuffle %@, repeat %@", sg_shuffle.accessibilityValue, sg_repeat.accessibilityValue);
    }
    NSLog(@"[harness] capsule checks: PASS");
    fflush(stdout);
}
