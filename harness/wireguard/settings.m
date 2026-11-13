// UIKit integration fixture. Real settings controller/localization, stubbed tunnel service.
#import "Shared/WireGuard/SGWGSettingsController.h"
#import "Shared/WireGuard/SGWGCore.h"
#import "Settings/SGPageStyle.h"
#import "Core/SGGlass.h"
#import "../harness-fail.h"

@implementation SGPage
@end
// Settings/SGPageStyle.m pulls in the whole prefs layer, so the fixture carries the few functions the page draws with.
UIColor *SGGrey(void) { return [UIColor colorWithRed:0xEB / 255.0 green:0xEB / 255.0 blue:0xF5 / 255.0 alpha:0.6]; }
UIColor *SGGreen(void) { return [UIColor colorWithRed:0x1E / 255.0 green:0xD7 / 255.0 blue:0x60 / 255.0 alpha:1]; }
UIColor *SGOnAccent(void) { return UIColor.blackColor; }
UIColor *SGRed(void) { return [UIColor colorWithRed:0xFF / 255.0 green:0x45 / 255.0 blue:0x3A / 255.0 alpha:1]; }
UIColor *SGCardBackground(void) { return [UIColor colorWithRed:0x1C / 255.0 green:0x1C / 255.0 blue:0x1E / 255.0 alpha:1]; }
UIFont *SGTitleFont(void) { return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:13]]; }
UIFont *SGSubtitleFont(void) { return [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote] scaledFontForFont:[UIFont systemFontOfSize:11]]; }
UIFont *SGCappedFont(UIFont *font, CGFloat largest) { return font.pointSize > largest ? [font fontWithSize:largest] : font; }
CGFloat SGSectionHeaderHeight(void) { return MAX(38, ceil(SGSubtitleFont().lineHeight) + 14); }
const CGFloat SGSectionGap = 20;
void SGFillCell(UITableViewCell *cell, NSString *title, NSString *subtitle, UIColor *color, NSString *symbolName) {
    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = title;
    content.secondaryText = subtitle;
    content.textProperties.font = SGTitleFont();
    content.textProperties.color = color ?: UIColor.whiteColor;
    content.secondaryTextProperties.font = SGSubtitleFont();
    content.secondaryTextProperties.color = SGGrey();
    content.textToSecondaryTextVerticalPadding = 2;
    content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(11, 16, 11, 16);
    cell.contentConfiguration = content;
    cell.backgroundColor = SGCardBackground();
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
}
static CGFloat NoteHeight(UITableView *table, NSString *text) {
    return ceil([text boundingRectWithSize:CGSizeMake(table.bounds.size.width - 32, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: SGSubtitleFont()} context:nil].size.height);
}
UIView *SGSectionHeader(UITableView *table, NSString *title) {
    UILabel *label = [UILabel new];
    label.text = title.uppercaseString;
    label.font = SGSubtitleFont();
    label.textColor = SGGrey();
    CGFloat height = ceil(label.font.lineHeight);
    label.frame = CGRectMake(16, SGSectionHeaderHeight() - 7 - height, table.bounds.size.width - 32, height);
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, table.bounds.size.width, SGSectionHeaderHeight())];
    [header addSubview:label];
    return header;
}
CGFloat SGSectionFooterHeight(UITableView *table, NSString *text) { return 8 + NoteHeight(table, text) + 12; }
UIView *SGSectionFooter(UITableView *table, NSString *text) {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = SGSubtitleFont();
    label.textColor = SGGrey();
    label.numberOfLines = 0;
    label.frame = CGRectMake(16, 8, table.bounds.size.width - 32, NoteHeight(table, text));
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, table.bounds.size.width, SGSectionFooterHeight(table, text))];
    [footer addSubview:label];
    return footer;
}
void SGInsetForBars(UITableView *table) {}
void SGPresentDark(UIViewController *page) { page.overrideUserInterfaceStyle = UIUserInterfaceStyleDark; }
NSString *const SGWGKindWireGuard = @"wireguard", *const SGWGKindHTTP = @"http", *const SGWGKindHTTPS = @"https", *const SGWGKindSOCKS5 = @"socks5";
static BOOL enabled;
BOOL SGWGSettingEnabled(void) { return enabled; }
void SGWGSetSettingEnabled(BOOL value) { enabled = value; }
NSString *SGWGSettingKind(void) { return @"wireguard"; }
NSDictionary *SGWGSettingExternalProxy(void) { return @{}; }
BOOL SGWGHasStoredProxyPassword(void) { return NO; }
BOOL SGWGSaveConnection(NSString *k, NSString *h, NSString *p, NSString *u, NSString *pw, NSString **reason) { return YES; }
NSString *SGWGActiveKind(void) { return @""; }
BOOL SGWGActiveThisLaunch(void) { return NO; }
BOOL SGWGIsSupportedOS(void) { return YES; }
BOOL SGWGIsSupportedVersion(void) { return YES; }
BOOL SGWGReady(void) { return NO; }
BOOL SGWGGuardsInstalled(void) { return NO; }
SGWGState SGWGCurrentState(void) { return SGWGStateOff; }
BOOL SGWGHasProfile(void) { return NO; }
NSDictionary *SGWGStoredProfileSummary(void) { return nil; }
BOOL SGWGImportProfile(NSString *text, NSString **reason) { return NO; }
BOOL SGWGDeleteProfile(NSString **reason) { return YES; }
NSDictionary *SGWGEngineStatus(void) { return @{}; }
void SGWGLookupInTunnel(NSString *host, void (^completion)(NSDictionary *)) { completion(@{@"ok":@NO}); }
NSURLSession *SGWGTunnelSession(id<NSURLSessionDelegate> delegate) { return nil; }
NSString *SGWGDiagnosticsReport(NSDictionary *checks) { return @"fixture"; }
NSString *SGWGRedactText(NSString *text) { return text; }
NSArray *SGWGScanTransportClasses(void) { return @[]; }

@interface WGSettingsApp : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation WGSettingsApp
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    SGWGSettingsController *page = [SGWGSettingsController new];
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:page];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        HARNESS_CHECK([page numberOfSectionsInTableView:page.tableView] == 5);
        HARNESS_CHECK([page tableView:page.tableView numberOfRowsInSection:2] == 2);
        HARNESS_CHECK(((UITextField *)[page valueForKey:@"passField"]).secureTextEntry);
        HARNESS_CHECK(page.overrideUserInterfaceStyle == UIUserInterfaceStyleDark);
        // Change modes repeatedly: no constraints left attached to old cells, no hidden profile rows.
        UISegmentedControl *kind = [page valueForKey:@"kindControl"];
        for (NSInteger i=0; i<8; i++) {
            kind.selectedSegmentIndex = i%4;
            [kind sendActionsForControlEvents:UIControlEventValueChanged];
            [page.tableView layoutIfNeeded];
            HARNESS_CHECK([page tableView:page.tableView numberOfRowsInSection:2] == (i%4 ? 0 : 2));
        }
        if (![NSProcessInfo.processInfo.arguments containsObject:@"proxy"]) {
            kind.selectedSegmentIndex = 0;
            [kind sendActionsForControlEvents:UIControlEventValueChanged];
        }
        HARNESS_CHECK([page tableView:page.tableView numberOfRowsInSection:1] == (kind.selectedSegmentIndex ? 5 : 0));
        printf("PASS WireGuard settings: mode changes, secure password, dark style, localized rows\n");
        fflush(stdout);
    });
    return YES;
}
@end
int main(int argc, char **argv) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(WGSettingsApp.class)); }
}
