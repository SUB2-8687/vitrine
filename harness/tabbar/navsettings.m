// The Tab bar page (Redesigned/Navbar/NavbarSettings.m) over the harness's bar, `navsettings`: its fade switch starts
// on, its preview reads the fade, and flipping the switch takes the fade off the real bar under the page at once and
// out of the preview.
#import <UIKit/UIKit.h>
#import "../harness-fail.h"
#import "Core/SGViewTree.h"
#import "Core/SGPrefs.h"
#import "Redesigned/Navbar/Navbar.h"

@class SGHarnessChrome;

static UISwitch *fadeSwitch(UIView *root) {
    __block UISwitch *found = nil;
    for (UITableViewCell *cell in ((UITableView *)root).visibleCells) {
        __block BOOL named = NO;
        SGForEachView(cell, ^(UIView *view) {
            if ([view isKindOfClass:UILabel.class] && [((UILabel *)view).text isEqualToString:@"Fade under the bar"]) named = YES;
        });
        if (named && [cell.accessoryView isKindOfClass:UISwitch.class]) found = (UISwitch *)cell.accessoryView;
    }
    return found;
}

static UIView *previewIn(UIView *root) {
    __block UIView *found = nil;
    SGForEachView(root, ^(UIView *view) {
        if (!found && [view.accessibilityLabel isEqualToString:@"Tab bar preview"]) found = view;
    });
    return found;
}

static void expectPreview(UIView *preview, BOOL on, NSString *moment) {
    if ([preview.accessibilityValue containsString:@"Fade under the bar"] != on) HARNESS_FAIL(@"%@: the preview reads \"%@\"", moment, preview.accessibilityValue);
    printf("PASS %s: the preview reads \"%s\"\n", moment.UTF8String, preview.accessibilityValue.UTF8String);
    fflush(stdout);
}

void SGHarnessRunNavbarPage(SGHarnessChrome *chrome, void (^barChecked)(BOOL on)) {
    UIViewController *owner = (UIViewController *)chrome;
    // What Navbar.x records off Spotify's bar, which the harness does not compile: the mock's tabs.
    SGRSetNavbarStock(@[@"Home", @"Search", @"Your Library", @"Create"]);
    SGSetEnabled(SGRKeyNavbarHideLabels, NO);
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:SGRNavbarSettingsPage()];
    nav.modalPresentationStyle = UIModalPresentationOverFullScreen;
    [owner presentViewController:nav animated:NO completion:nil];
    [nav.view layoutIfNeeded];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    UITableView *table = ((UITableViewController *)nav.topViewController).tableView;
    UISwitch *toggle = fadeSwitch(table);
    UIView *preview = previewIn(table.tableHeaderView);
    if (!toggle || !toggle.on || !preview) HARNESS_FAIL(@"the fade switch %@, the preview %@", toggle ? (toggle.on ? @"on" : @"off") : @"missing", preview);
    expectPreview(preview, YES, @"switch on");
    barChecked(YES);
    toggle.on = NO;
    [toggle sendActionsForControlEvents:UIControlEventValueChanged];
    if (SGEnabled(SGRKeyNavbarFade)) HARNESS_FAIL(@"the switch did not store %@", SGRKeyNavbarFade);
    [owner.view layoutIfNeeded];
    barChecked(NO);
    expectPreview(preview, NO, @"switch off");
    UIView *labels = [table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]].contentView.subviews.firstObject;
    UIControl *iconsOnly = ((UIStackView *)labels).arrangedSubviews.lastObject;
    HARNESS_CHECK(iconsOnly);
    [iconsOnly sendActionsForControlEvents:UIControlEventTouchUpInside];
    HARNESS_CHECK(SGEnabled(SGRKeyNavbarHideLabels));
    UISwitch *custom = (UISwitch *)[table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].accessoryView;
    HARNESS_CHECK(custom);
    custom.on = NO;
    [custom sendActionsForControlEvents:UIControlEventValueChanged];
    HARNESS_CHECK(!SGEnabled(SGRKeyNavbar));
    custom.on = YES;
    [custom sendActionsForControlEvents:UIControlEventValueChanged];
    NSIndexPath *homePath = nil;
    for (NSInteger section = 0; section < table.numberOfSections; section++) {
        for (NSInteger row = 0; row < [table numberOfRowsInSection:section]; row++) {
            NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
            UITableViewCell *cell = [table.dataSource tableView:table cellForRowAtIndexPath:path];
            if ([((UIListContentConfiguration *)cell.contentConfiguration).text isEqual:@"Home"]) homePath = path;
        }
    }
    HARNESS_CHECK(homePath);
    [table scrollToRowAtIndexPath:homePath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    [table layoutIfNeeded];
    UITableViewCell *home = [table cellForRowAtIndexPath:homePath];
    __block UIButton *hide;
    SGForEachView(home.contentView, ^(UIView *view) {
        if ([view isKindOfClass:UIButton.class]) hide = (UIButton *)view;
    });
    HARNESS_CHECK(hide);
    [hide sendActionsForControlEvents:UIControlEventTouchUpInside];
    HARNESS_CHECK([SGRNavbarLayout().firstObject[SGRNavbarHidden] boolValue]);
    printf("PASS all navsettings\n");
    fflush(stdout);
    exit(0);
}
