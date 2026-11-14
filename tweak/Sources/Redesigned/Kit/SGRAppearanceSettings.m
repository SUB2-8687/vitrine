#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "SGRAccent.h"
#import "SGRHeaderInfo.h"
#import "SGRHeroVeil.h"
#import "Redesigned/Navigation/PageZoom.h"

// The preset is read off the color stored, so the hooks keep the one key they read and a color set before
// presets existed stays in effect: Apple Music's red reads as Apple Music, Spotify's own (-1) as Spotify, and
// any other color as Custom, the redesign's own green when nothing is stored among them. The custom color
// is put aside while a preset is in place, so Custom brings it back.
static NSArray<NSString *> *presets(void) {
    return @[@"Spotify", @"Apple Music", SGL(@"settings.appearance.accent.choice.custom", @"Custom")];
}

static NSInteger preset(void) {
    NSInteger rgb = SGInt(SGRKeyAccent, SGRDefaultAccent);
    if (rgb < 0 || rgb > 0xFFFFFF) return 0;
    return rgb == SGAppleMusicRed ? 1 : 2;
}

static void choosePreset(NSInteger index) {
    if (preset() == 2) SGSetInt(SGRKeyAccentCustom, SGRPickedAccentRGB());
    NSInteger custom = SGInt(SGRKeyAccentCustom, SGRDefaultAccent);
    if (custom < 0 || custom > 0xFFFFFF) custom = SGRDefaultAccent;
    SGSetInt(SGRKeyAccent, index == 0 ? -1 : index == 1 ? SGAppleMusicRed : custom);
    SGRAccentPreferencesChanged();
}

// A color from the sheet, a swatch's or the picker's: Custom, and first among the recent colors when it is another.
static void chooseColor(NSInteger rgb) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    NSArray<NSNumber *> *recent = SGRAccentRecentFrom([store objectForKey:SGRKeyAccentRecent]);
    [store setObject:SGRAccentRecentAdding(recent, rgb, SGRPickedAccentRGB()) forKey:SGRKeyAccentRecent];
    SGSetInt(SGRKeyAccent, rgb);
    SGSetInt(SGRKeyAccentCustom, rgb);
    SGRAccentPreferencesChanged();
}

// The redesign's rows of the Appearance page (App/Pages.m): the preset from a menu, then the color in effect,
// which opens the sheet of recent colors and the picker; a color stored from there is Custom. AMOLED has no row:
// the redesign is always black.
NSArray<SGModRow *> *SGRAppearanceRows(void) {
    NSArray *modes = @[SGL(@"settings.appearance.accent.mode.picked", @"Picked"),
                       SGL(@"settings.appearance.accent.mode.automatic", @"Automatic")];
    SGModRow *mode = SGMenuRow(SGL(@"settings.appearance.accent.mode.title", @"Accent source"), modes,
        ^NSString *{ return modes[SGFlag(SGRKeyAccentAuto, NO) ? 1 : 0]; },
        ^(NSInteger index) { SGSetEnabled(SGRKeyAccentAuto, index == 1); SGRAccentPreferencesChanged(); });
    mode.subtitle = SGL(@"settings.appearance.accent.mode.subtitle", @"Automatic follows the page in front, then the playing cover. Picked restores your color");
    SGModRow *explicit = SGOptionRow(SGL(@"settings.appearance.hide_explicit.title", @"Hide explicit badge"),
        SGL(@"settings.appearance.hide_explicit.subtitle", @"Hide the E mark, without changing content restrictions or VoiceOver"), SGRKeyHideExplicit);
    explicit.changed = ^(BOOL on) { SGRRefreshExplicitBadges(); };
    SGModRow *menu = SGMenuRow(SGL(@"settings.appearance.accent_preset.title", @"Accent color preset"), presets(), ^NSString *{ return presets()[(NSUInteger)preset()]; },
                               ^(NSInteger index) { choosePreset(index); });
    SGModRow *colour = SGStatActionRow(SGL(@"settings.appearance.accent_color.title", @"Accent color"), nil, ^NSString *{ return [NSString stringWithFormat:@"#%06lX", (long)SGRPickedAccentRGB()]; }, ^{
        SGRPickAccent(SGL(@"settings.appearance.accent_picker.title", @"Accent color"), SGRPickedAccentRGB(),
                      SGRAccentRecentFrom([NSUserDefaults.standardUserDefaults objectForKey:SGRKeyAccentRecent]), ^(NSInteger rgb) { chooseColor(rgb); });
    });
    colour.swatch = ^UIColor *{ return SGColorRGB(SGRPickedAccentRGB()); };
    return @[
        SGWithSymbol(mode, @"paintbrush"),
        SGWithSymbol(menu, @"paintpalette"),
        SGWithSymbol(colour, @"eyedropper"),
        SGWithSymbol(SGOptionRow(SGL(@"settings.appearance.plain_checkmark.title", @"Plain checkmark"), SGL(@"settings.appearance.plain_checkmark.subtitle", @"A saved song's tick without its circle, in the accent"), SGRKeyPlainCheck), @"checkmark"),
        SGWithSymbol(explicit, @"e.square"),
        // The album, playlist and artist headers (Kit/SGRHeroVeil.h, Kit/SGRHeaderInfo.h), read at launch.
        SGWithSymbol(SGOptionRow(SGL(@"settings.appearance.scroll_veil.title", @"Blur covers on scroll"),
            SGL(@"settings.appearance.scroll_veil.subtitle", @"Album, playlist and artist pictures blur and dim into the page's color as you scroll, and the title is cut off under the top bar"),
            SGRKeyHeroScrollVeil), @"drop.halffull"),
        SGWithSymbol(SGSwitchRow(SGL(@"settings.appearance.scrolled_title.title", @"Page title when scrolled"),
            SGL(@"settings.appearance.scrolled_title.subtitle", @"Show the small title between Back and More on playlists, albums, artists and profiles"),
            SGRKeyPageTitleWhenScrolled), @"textformat"),
        SGWithSymbol(SGOptionRow(SGL(@"settings.appearance.page_zoom.title", @"Open pages from their artwork"),
            SGL(@"settings.appearance.page_zoom.subtitle", @"Albums and playlists grow from the cover you tap and return to it when you go back. Restart to apply"),
            SGRKeyPageZoom), @"arrow.up.left.and.arrow.down.right"),
        SGWithSymbol(SGSwitchRow(SGL(@"settings.appearance.play_page_color.title", @"Play in the page's color"),
            SGL(@"settings.appearance.play_page_color.subtitle", @"The Play button's symbol and word take the page's color. Off, they take the accent color"),
            SGRKeyPlayInPageColour), @"play.fill"),
        // Round artist Play lives on the Artists page with its cut-out (Artist/ArtistSettings.m).
    ];
}
