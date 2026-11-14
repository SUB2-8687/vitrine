// The redesign's Home page of Mod Settings: Top picks and where its cards come from, what stays on Home, and
// one switch per shelf Home has shown lately (HomeShelves.m). Every switch is read as Home lays out, so a
// change needs a restart (SGRestartNote). It leads with a preview of Home (Kit/SGRPagePreview.h) that follows them.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Redesigned/Kit/SGRTokens.h"
#import "Redesigned/Kit/SGRPalette.h"
#import "Redesigned/Kit/SGRPagePreview.h"
#import "Home.h"

#define kFirstShelf SGL(@"settings.home.shelf.first", @"First shelf")

// Top picks: large cards, each its cover over a footer in the cover's color (or the plain surface), under the
// shelf's heading while that is kept.
static const NSUInteger kLargeCards = 4;
static const CGFloat kLargeCard = 96, kLargeFooter = 30, kLargeRadius = 10, kLargeGap = 8, kFooterBar = 7, kFooterBarShare = 0.7;
static const CGFloat kHeadingFont = 13, kHeadingGap = 8;
// The shortcuts: two rows of two tiles, the first playing, so the DJ under them ends clear of the tab bar. With Glass
// shortcuts a tile is a pill of its cover's color with its name bold; without it, Spotify's tile with its cover at
// the leading end.
static const NSUInteger kShortcutRows = 2, kShortcutColumns = 2;
static const CGFloat kShortcut = 26, kShortcutGap = 6, kPillRadius = 7, kTileRadius = 4, kShortcutPad = 8;
static const CGFloat kShortcutBar = 7, kBoldBar = 8, kShortcutBarShare = 0.5, kPlaying = 11;
// The DJ's card.
static const NSUInteger kDJColor = 1;
static const CGFloat kDJ = 34, kDJRadius = 8, kDJFont = 15, kDJBar = 7, kDJBarShare = 0.35;
// Without a shelf seen yet, Home is drawn with this many shelves of no name.
static const NSUInteger kUnnamedShelves = 2, kCoversPerShelf = 2;

// Home from the top: the title, Top picks, the shortcuts, the DJ, the song suggestions and previews while they are
// asked for, then the shelves Home has shown lately, each gone while switched off and the one Top picks draws moved
// up into it; the tab bar over the foot.
static SGRPagePreview *homePreview(NSArray<NSString *> *shelves, NSDictionary<NSString *, NSString *> *names) {
    SGRPagePreview *card = [[SGRPagePreview alloc] initWithLabel:SGL(@"settings.home.preview.a11y", @"Preview of Home")];
    SGRPreviewTitle *title = SGRPreviewAddTitle(card, SGL(@"settings.home.title", @"Home"));

    // The shelves, by identity, or unnamed (NSNull) while none has been seen.
    NSMutableArray *identities = [NSMutableArray arrayWithArray:shelves];
    for (NSUInteger i = 0; !shelves.count && i < kUnnamedShelves; i++) [identities addObject:NSNull.null];

    UILabel *heading = SGRPreviewLabel(nil, SGRPrimary());
    NSMutableArray<NSArray<UIView *> *> *large = [NSMutableArray array];
    for (NSUInteger i = 0; i < kLargeCards; i++) {
        UIView *body = [UIView new];
        body.clipsToBounds = YES;
        body.layer.cornerCurve = kCACornerCurveContinuous;
        UIImageView *cover = SGRPreviewCover(i);
        UIView *bar = SGRPreviewBar(SGRPrimary());
        [body addSubview:cover];
        [body addSubview:bar];
        [large addObject:@[body, cover, bar]];
    }
    __block BOOL headingShown = NO;
    __block NSUInteger topFirstCover = 0;
    UIView *topPicks = [card addPartWithLayout:^CGFloat(UIView *part, CGFloat width, CGFloat unit) {
        heading.font = SGRPreviewFont(kHeadingFont, UIFontWeightBold, unit);
        CGFloat headingHeight = headingShown ? ceil(heading.font.lineHeight) + kHeadingGap * unit : 0;
        heading.frame = CGRectMake(SGRPagePreviewMargin, 0, width - 2 * SGRPagePreviewMargin, ceil(heading.font.lineHeight));
        heading.alpha = headingShown;
        CGFloat side = kLargeCard * unit, footer = kLargeFooter * unit;
        [large enumerateObjectsUsingBlock:^(NSArray<UIView *> *views, NSUInteger i, BOOL *stop) {
            views[0].frame = CGRectMake(SGRPagePreviewMargin + i * (side + kLargeGap * unit), headingHeight, side, side + footer);
            views[0].layer.cornerRadius = kLargeRadius * unit;
            views[1].frame = CGRectMake(0, 0, side, side);
            views[2].frame = CGRectMake(kShortcutPad * unit, side + (footer - kFooterBar * unit) / 2, side * kFooterBarShare, kFooterBar * unit);
        }];
        return headingHeight + side + footer;
    }];
    [topPicks addSubview:heading];
    for (NSArray<UIView *> *views in large) [topPicks addSubview:views[0]];
    topPicks.accessibilityLabel = names[SGRKeyHomeTopPicks];

    NSMutableArray<NSArray<UIView *> *> *tiles = [NSMutableArray array];
    for (NSUInteger i = 0; i < kShortcutRows * kShortcutColumns; i++) {
        UIView *tile = [UIView new];
        tile.clipsToBounds = YES;
        tile.layer.cornerCurve = kCACornerCurveContinuous;
        UIImageView *cover = SGRPreviewCover(i + kCoversPerShelf);
        UIView *bar = SGRPreviewBar(SGRPrimary());
        UIImageView *playing = SGRPreviewSymbol(@"chart.bar.fill", SGRAccent());
        playing.alpha = i == 0;
        for (UIView *view in @[cover, bar, playing]) [tile addSubview:view];
        [tiles addObject:@[tile, cover, bar, playing]];
    }
    __block BOOL glass = YES;
    UIView *shortcuts = [card addPartWithLayout:^CGFloat(UIView *part, CGFloat width, CGFloat unit) {
        CGFloat gap = kShortcutGap * unit, height = kShortcut * unit, pad = kShortcutPad * unit;
        CGFloat tileWidth = (width - 2 * SGRPagePreviewMargin - (kShortcutColumns - 1) * gap) / kShortcutColumns;
        [tiles enumerateObjectsUsingBlock:^(NSArray<UIView *> *views, NSUInteger i, BOOL *stop) {
            NSUInteger row = i / kShortcutColumns, column = i % kShortcutColumns;
            UIColor *color = SGRFieldColorFor(SGRPreviewColor(i + kCoversPerShelf));
            views[0].frame = CGRectMake(SGRPagePreviewMargin + column * (tileWidth + gap), row * (height + gap), tileWidth, height);
            views[0].layer.cornerRadius = (glass ? kPillRadius : kTileRadius) * unit;
            views[0].backgroundColor = glass ? SGRElevated(color) : SGRElevated(UIColor.blackColor);
            views[1].frame = CGRectMake(0, 0, height, height);
            views[1].alpha = !glass;
            CGFloat barHeight = (glass ? kBoldBar : kShortcutBar) * unit, x = glass ? pad : height + pad;
            views[2].frame = CGRectMake(x, (height - barHeight) / 2, (tileWidth - x) * kShortcutBarShare, barHeight);
            CGFloat glyph = kPlaying * unit;
            views[3].frame = CGRectMake(tileWidth - pad - glyph, (height - glyph) / 2, glyph, glyph);
            views[3].tintColor = SGRAccent();
        }];
        return kShortcutRows * height + (kShortcutRows - 1) * gap;
    }];
    for (NSArray<UIView *> *views in tiles) [shortcuts addSubview:views[0]];
    shortcuts.accessibilityLabel = names[SGRKeyHomeHideShortcuts];

    UIView *djCard = SGRPreviewGradient(@[SGRPreviewColor(kDJColor), SGRFieldColorFor(SGRPreviewColor(kDJColor))], CGPointZero, CGPointMake(1, 1));
    djCard.clipsToBounds = YES;
    djCard.layer.cornerCurve = kCACornerCurveContinuous;
    UILabel *djLabel = SGRPreviewLabel(names[SGRKeyHomeHideDJ], SGRPrimary());
    UIView *djBar = SGRPreviewBar(SGRSecondary());
    [djCard addSubview:djLabel];
    [djCard addSubview:djBar];
    UIView *dj = [card addPartWithLayout:^CGFloat(UIView *part, CGFloat width, CGFloat unit) {
        CGFloat height = kDJ * unit, pad = kShortcutPad * unit;
        djCard.frame = CGRectMake(SGRPagePreviewMargin, 0, width - 2 * SGRPagePreviewMargin, height);
        djCard.layer.cornerRadius = kDJRadius * unit;
        djLabel.font = SGRPreviewFont(kDJFont, UIFontWeightHeavy, unit);
        CGFloat labelWidth = ceil([djLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, height)].width);
        djLabel.frame = CGRectMake(pad, 0, labelWidth, height);
        djBar.frame = CGRectMake(CGRectGetMaxX(djLabel.frame) + pad, (height - kDJBar * unit) / 2, djCard.bounds.size.width * kDJBarShare, kDJBar * unit);
        return height;
    }];
    [dj addSubview:djCard];
    dj.accessibilityLabel = names[SGRKeyHomeHideDJ];

    UIView *suggestions = SGRPreviewAddShelf(card, nil, kShortcutRows * kShortcutColumns, SGRPreviewTilesSquare);
    suggestions.accessibilityLabel = names[SGRKeyHomeSongSuggestions];
    UIView *previews = SGRPreviewAddShelf(card, nil, kShortcutRows * kShortcutColumns + 1, SGRPreviewTilesTall);
    previews.accessibilityLabel = names[SGRKeyHomePreviews];

    NSMutableArray<UIView *> *shelfParts = [NSMutableArray array];
    [identities enumerateObjectsUsingBlock:^(id identity, NSUInteger i, BOOL *stop) {
        NSString *text = [identity isKindOfClass:NSString.class] ? identity : nil;
        UIView *shelf = SGRPreviewAddShelf(card, text, i * kCoversPerShelf, SGRPreviewTilesSquare);
        shelf.accessibilityLabel = text;
        [shelfParts addObject:shelf];
    }];

    [card addTabBarShowing:SGRPreviewTabHome];

    card.state = ^id<NSObject> {
        NSMutableDictionary *state = [NSMutableDictionary dictionary];
        state[SGRKeyHomeLook] = @(SGEnabled(SGRKeyHomeLook));
        state[SGRKeyHomeShortcutGlass] = @(SGRHomeShortcutGlassStored());
        state[SGRKeyHomeTopPicks] = @(SGEnabled(SGRKeyHomeTopPicks));
        state[SGRKeyHomeTopPicksColour] = @(SGEnabled(SGRKeyHomeTopPicksColour));
        state[SGRKeyHomeTopPicksHeading] = @(SGHidden(SGRKeyHomeTopPicksHeading));
        state[SGRKeyHomeKeepTitle] = @(SGHidden(SGRKeyHomeKeepTitle));
        state[SGRKeyHomeHideShortcuts] = @(SGHidden(SGRKeyHomeHideShortcuts));
        state[SGRKeyHomeHideDJ] = @(SGHidden(SGRKeyHomeHideDJ));
        state[SGRKeyHomeSongSuggestions] = @(SGHidden(SGRKeyHomeSongSuggestions));
        state[SGRKeyHomePreviews] = @(SGHidden(SGRKeyHomePreviews));
        state[SGRKeyHomeTopPicksFrom] = SGRHomeTopPicksFrom() ?: NSNull.null;
        for (NSString *identity in shelves) state[SGRHomeShelfHideKey(identity)] = @(SGRHomeShelfHidden(identity));
        return state;
    };
    card.apply = ^(SGRPagePreview *preview, NSDictionary *state) {
        BOOL (^on)(NSString *) = ^BOOL(NSString *key) { return [state[key] boolValue]; };
        BOOL (^shelfHidden)(id) = ^BOOL(id identity) { return [identity isKindOfClass:NSString.class] && on(SGRHomeShelfHideKey(identity)); };
        // Top picks draws the shelf Cards from names, else the first one shown; never one switched off (HomeTopPicks.x).
        id from = state[SGRKeyHomeTopPicksFrom];
        NSUInteger source = NSNotFound;
        if ([from isKindOfClass:NSString.class]) {
            if (!shelfHidden(from)) source = [identities indexOfObject:from];
        } else {
            source = [identities indexOfObjectPassingTest:^BOOL(id identity, NSUInteger i, BOOL *stop) { return !shelfHidden(identity); }];
        }
        BOOL look = on(SGRKeyHomeLook);
        if (glass != on(SGRKeyHomeShortcutGlass)) [preview revealPart:shortcuts];
        glass = on(SGRKeyHomeShortcutGlass);
        BOOL topShown = look && on(SGRKeyHomeTopPicks) && source != NSNotFound;
        if (title.inPill != look || title.hardEdge != on(SGRKeyHomeKeepTitle)) [preview revealPart:title.part];
        title.inPill = look;
        title.hardEdge = on(SGRKeyHomeKeepTitle);
        NSMutableArray<NSString *> *titleNames = [NSMutableArray array];
        if (look) [titleNames addObject:names[SGRKeyHomeLook]];
        if (title.hardEdge) [titleNames addObject:names[SGRKeyHomeKeepTitle]];
        title.part.accessibilityLabel = SGRPreviewList(titleNames);

        [preview setPart:topPicks shown:topShown];
        BOOL colour = on(SGRKeyHomeTopPicksColour);
        if (topShown) {
            id identity = identities[source];
            heading.text = [identity isKindOfClass:NSString.class] ? identity : kFirstShelf;
            topFirstCover = source * kCoversPerShelf;
            if (headingShown != on(SGRKeyHomeTopPicksHeading)) [preview revealPart:topPicks];
            headingShown = on(SGRKeyHomeTopPicksHeading);
            [large enumerateObjectsUsingBlock:^(NSArray<UIView *> *views, NSUInteger i, BOOL *stop) {
                UIColor *color = SGRPreviewColor(topFirstCover + i);
                ((UIImageView *)views[1]).image = SGRPreviewArt(topFirstCover + i);
                views[0].backgroundColor = colour ? SGRFieldColorFor(color) : SGRElevated(UIColor.blackColor);
            }];
        }
        // The page's color, from the first large card's cover, behind the title in the Home look (HomeHeader.x); gone
        // with the cards' colors, as HomeTopPicks.x clears both.
        preview.topTint = topShown && colour ? SGRFieldColorFor(SGRPreviewColor(topFirstCover)) : nil;
        [preview setPart:shortcuts shown:!on(SGRKeyHomeHideShortcuts)];
        [preview setPart:dj shown:!on(SGRKeyHomeHideDJ)];
        [preview setPart:suggestions shown:on(SGRKeyHomeSongSuggestions)];
        [preview setPart:previews shown:on(SGRKeyHomePreviews)];
        [shelfParts enumerateObjectsUsingBlock:^(UIView *shelf, NSUInteger i, BOOL *stop) {
            [preview setPart:shelf shown:!shelfHidden(identities[i]) && !(topShown && i == source)];
        }];
    };
    return card;
}

UIViewController *SGRHomeSettingsPage(void) {
    NSArray<NSString *> *shelves = SGRHomeShelvesSeen();
    NSArray<NSString *> *sources = [@[kFirstShelf] arrayByAddingObjectsFromArray:shelves];
    SGModRow *from = SGMenuRow(SGL(@"settings.home.cards_from.title", @"Cards from"), sources, ^NSString *{ return SGRHomeTopPicksFrom() ?: kFirstShelf; }, ^(NSInteger index) {
        if (index == 0) [NSUserDefaults.standardUserDefaults removeObjectForKey:SGRKeyHomeTopPicksFrom];
        else [NSUserDefaults.standardUserDefaults setObject:sources[(NSUInteger)index] forKey:SGRKeyHomeTopPicksFrom];
    });
    SGModRow *look = SGSwitchRow(SGL(@"settings.home.look.title", @"Home look"), SGL(@"settings.home.look.subtitle", @"Top picks and its color, and the title's glass pill; off, Home as the redesign had it"), SGRKeyHomeLook);
    SGModRow *glass = SGSwitchRow(SGL(@"settings.home.shortcut_glass.title", @"Glass shortcuts"), SGL(@"settings.home.shortcut_glass.subtitle", @"The shortcuts as tinted glass pills with bold names"), SGRKeyHomeShortcutGlass);
    // Unset, the switch is what the Home look is.
    glass.readSwitch = ^BOOL { return SGRHomeShortcutGlassStored(); };
    SGModRow *topPicks = SGRHomeTopPicksRow();
    topPicks.waitsOn = SGRKeyHomeLook;
    from.waitsOn = SGRKeyHomeTopPicks;
    SGModRow *colour = SGSwitchRow(SGL(@"settings.home.top_picks_color.title", @"Color behind Top picks"), nil, SGRKeyHomeTopPicksColour);
    colour.waitsOn = SGRKeyHomeTopPicks;
    SGModRow *heading = SGOptionRow(SGL(@"settings.home.top_picks_heading.title", @"Show Top picks heading"), SGL(@"settings.home.top_picks_heading.subtitle", @"The shelf's own heading over its cards"), SGRKeyHomeTopPicksHeading);
    heading.waitsOn = SGRKeyHomeTopPicks;

    NSMutableArray<SGModRow *> *rows = [NSMutableArray array];
    for (NSString *identity in shelves) [rows addObject:SGShownRow(identity, nil, SGRHomeShelfHideKey(identity))];
    if (!rows.count) [rows addObject:SGStatRow(SGL(@"settings.home.shelves.none", @"None seen yet"), ^NSString *{ return @""; })];

    NSArray<SGModRow *> *onHome = @[
        SGShownRow(SGL(@"settings.home.shortcuts.title", @"Shortcuts"), nil, SGRKeyHomeHideShortcuts),
        SGShownRow(SGL(@"settings.home.dj.title", @"DJ"), nil, SGRKeyHomeHideDJ),
        SGShownRow(SGL(@"settings.home.podcasts.title", @"Podcasts and audiobooks"), SGL(@"settings.home.podcasts.subtitle", @"The Podcasts and Audiobooks chips in Home's filter menu"), SGRKeyHomeHidePodcasts),
        SGOptionRow(SGL(@"settings.home.keep_title.title", @"Title stays on scroll"), SGL(@"settings.home.keep_title.subtitle", @"The title, the avatar and the pill stay at the top as Home scrolls under them"), SGRKeyHomeKeepTitle),
        SGOptionRow(SGL(@"settings.home.song_suggestions.title", @"Song suggestions"), SGL(@"settings.home.song_suggestions.subtitle", @"Spotify's carousel of songs to try, when Home offers one"), SGRKeyHomeSongSuggestions),
        SGOptionRow(SGL(@"settings.home.previews.title", @"Video and playlist previews"), SGL(@"settings.home.previews.subtitle", @"The cards that play as Home scrolls"), SGRKeyHomePreviews),
    ];
    // The card names what it shows by the rows' own titles, by their keys.
    NSMutableDictionary<NSString *, NSString *> *names = [NSMutableDictionary dictionary];
    for (SGModRow *row in [@[look, topPicks] arrayByAddingObjectsFromArray:onHome]) names[row.key] = row.title;

    return SGRPagePreviewPage(SGL(@"settings.home.title", @"Home"), homePreview(shelves, names), SGRestartNote, @[
        SGNotedSection(nil, @[look, glass, topPicks, from, colour, heading],
                       SGL(@"settings.home.top_picks_missing.note", @"A shelf Home does not show today leaves Top picks off until it is back.")),
        SGSection(SGL(@"settings.home.on_home.header", @"On Home"), onHome),
        SGNotedSection(SGL(@"settings.home.shelves.header", @"Shelves"), rows, SGL(@"settings.home.shelves.note", @"The shelves Home has shown in the last 30 days. A shelf is known by its heading, so one "
                                         @"Spotify names differently in another language is listed again.")),
    ]);
}
