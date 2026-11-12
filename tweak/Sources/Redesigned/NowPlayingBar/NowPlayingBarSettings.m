// The now playing bar's rows of the redesign, the Mini player section of the Player page
// (Redesigned/Player/PlayerSettings.m puts them there).
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Redesigned/Navbar/Navbar.h"
#import "NowPlayingBar.h"

NSArray<SGModRow *> *SGRNowPlayingBarRows(void) {
    // The tab bar reads the switch as each scroll goes; a bar minimized when it goes off grows back at once.
    SGModRow *minimize = SGSwitchRow(SGL(@"settings.nowplayingbar.minimize.title", @"Minimize while scrolling"), SGL(@"settings.nowplayingbar.minimize.subtitle", @"Between two tabs as a page scrolls down"), SGRKeyNavbarMinimize);
    minimize.changed = ^(BOOL on) {
        if (!on) SGRSetTabBarMinimized(NO, NO);
        SGRRefreshTabBar();
    };
    SGModRow *inlineConnect = SGOptionRow(SGL(@"settings.nowplayingbar.device_button.title", @"Device button when minimized"), SGL(@"settings.nowplayingbar.device_button.subtitle", @"Kept on the bar between the tabs"), SGRKeyBarInlineConnect);
    inlineConnect.waitsOn = SGRKeyNavbarMinimize;
    SGModRow *inlineArtist = SGOptionRow(SGL(@"settings.nowplayingbar.inline_artist.title", @"Artist under the title when minimized"), SGL(@"settings.nowplayingbar.inline_artist.subtitle", @"A second line on the bar between the tabs, when it fits"), SGRKeyBarInlineArtist);
    inlineArtist.waitsOn = SGRKeyNavbarMinimize;
    inlineArtist.changed = ^(BOOL on) { SGRNowPlayingBarFollowTabBar(); };
    SGModRow *next = SGOptionRow(SGL(@"settings.nowplayingbar.next_button.title", @"Next button"), SGL(@"settings.nowplayingbar.next_button.subtitle", @"After play on the full now playing bar"), SGRKeyBarNextButton);
    next.changed = ^(BOOL on) { SGRNowPlayingBarFollowTabBar(); };
    SGModRow *shape = SGChoiceRow(SGL(@"settings.nowplayingbar.artwork_shape.title", @"Artwork shape"), nil, SGRKeyBarArtworkShape,
                                  @[SGL(@"settings.nowplayingbar.artwork_shape.rounded_square", @"Rounded square"), SGL(@"settings.nowplayingbar.artwork_shape.circle", @"Circle")],
                                  SGRBarArtworkShapeCircle);
    shape.chosen = ^(NSInteger index) { SGRNowPlayingBarFollowTabBar(); };
    return @[
        minimize,
        inlineConnect,
        inlineArtist,
        next,
        shape,
        SGHideRow(SGL(@"settings.nowplayingbar.hide_device_button.title", @"Hide the device button"), SGL(@"settings.nowplayingbar.hide_device_button.subtitle", @"On the full now playing bar"), SGRHideBarConnect),
        // Spotify's own flag for the bar's save button, forced off: Spotify leaves the button out.
        SGKillRow(SGL(@"settings.nowplayingbar.hide_like.title", @"Hide the like button"), @"ios-feature-nowplayingbar.add_button"),
    ];
}
