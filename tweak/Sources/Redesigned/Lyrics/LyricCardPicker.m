// The lyric card's picker (LyricCardPicker.h): Show Pronunciation at the top where any line has one, then the
// song's lines, a tap picking one or putting it back; the card takes them in the song's order. With a card's
// worth picked, the lines left are dimmed and read as unavailable, and a tap on one says how many a card holds.
#import "Core/SGCore.h"
#import "Core/SGGlass.h"
#import "Core/SGLocalize.h"
#import "Settings/SGPageStyle.h"
#import "LyricCardPicker.h"

static NSString *const kLineCell = @"line", *const kOptionCell = @"option";

static NSString *mostLinesText(void) {
    return [NSString stringWithFormat:SGL(@"settings.lyrics.card.most", @"Choose up to %lu lines."), (unsigned long)SGRLyricCardMostLines];
}

@interface SGRLyricCardPicker : UITableViewController
@end

@implementation SGRLyricCardPicker {
    NSArray<SGRLyricCardLine *> *_lines;
    NSString *_track;
    NSMutableIndexSet *_picked;
    NSUInteger _first;   // the line held to open the picker, shown in the middle as it opens
    BOOL _hasPronunciation, _pronunciation, _sharing;
    UIBarButtonItem *_share;
}

- (instancetype)initWithLines:(NSArray<SGRLyricCardLine *> *)lines picked:(NSUInteger)picked pronunciation:(BOOL)pronunciation
                        track:(NSString *)track {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _lines = [lines copy];
    _track = [track copy];
    _first = picked;
    _picked = picked < lines.count ? [NSMutableIndexSet indexSetWithIndex:picked] : [NSMutableIndexSet indexSet];
    for (SGRLyricCardLine *line in lines) _hasPronunciation |= line.pronunciation.length > 0;
    _pronunciation = pronunciation && _hasPronunciation;
    self.title = SGL(@"settings.lyrics.card.title", @"Lyric Card");
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self action:@selector(cancel)];
    _share = [[UIBarButtonItem alloc] initWithTitle:SGL(@"settings.lyrics.card.share", @"Share") style:UIBarButtonItemStyleDone
                                             target:self action:@selector(share)];
    _share.accessibilityLabel = SGL(@"settings.lyrics.card.share.label", @"Share lyric card");
    self.navigationItem.rightBarButtonItem = _share;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:kLineCell];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:kOptionCell];
    [self updateShare];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_first >= _lines.count) return;
    [self.tableView layoutIfNeeded];
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger)_first inSection:[self linesSection]]
                          atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    _first = NSNotFound;
}

- (NSInteger)linesSection {
    return _hasPronunciation ? 1 : 0;
}

- (BOOL)isOption:(NSIndexPath *)path {
    return path.section != [self linesSection];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return [self linesSection] + 1;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    return section == [self linesSection] ? (NSInteger)_lines.count : 1;
}

- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    return section == [self linesSection] ? mostLinesText() : nil;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    if ([self isOption:path]) {
        UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:kOptionCell forIndexPath:path];
        UIListContentConfiguration *content = [UIListContentConfiguration cellConfiguration];
        content.text = SGL(@"settings.lyrics.card.pronunciation", @"Show Pronunciation");
        cell.contentConfiguration = content;
        UISwitch *toggle = [UISwitch new];
        toggle.on = _pronunciation;
        toggle.accessibilityLabel = content.text;
        [toggle addTarget:self action:@selector(pronunciationToggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:kLineCell forIndexPath:path];
    NSUInteger row = (NSUInteger)path.row;
    SGRLyricCardLine *line = _lines[row];
    BOOL picked = [_picked containsIndex:row];
    BOOL unavailable = !picked && _picked.count >= SGRLyricCardMostLines;
    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = line.text;
    content.secondaryText = _pronunciation ? line.pronunciation : nil;
    content.textProperties.color = unavailable ? UIColor.tertiaryLabelColor : UIColor.labelColor;
    content.secondaryTextProperties.color = unavailable ? UIColor.tertiaryLabelColor : UIColor.secondaryLabelColor;
    cell.contentConfiguration = content;
    cell.accessoryType = picked ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.accessibilityTraits = UIAccessibilityTraitButton | (picked ? UIAccessibilityTraitSelected : 0)
                             | (unavailable ? UIAccessibilityTraitNotEnabled : 0);
    return cell;
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if ([self isOption:path]) return;
    NSUInteger row = (NSUInteger)path.row;
    if ([_picked containsIndex:row]) {
        [_picked removeIndex:row];
    } else if (_picked.count < SGRLyricCardMostLines) {
        [_picked addIndex:row];
    } else {
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, mostLinesText());
        return;
    }
    // Every line shown: reaching the most a card holds, or leaving it, dims or brightens the rest.
    [table reconfigureRowsAtIndexPaths:table.indexPathsForVisibleRows];
    [self updateShare];
}

- (void)pronunciationToggled:(UISwitch *)toggle {
    _pronunciation = toggle.on;
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:[self linesSection]] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)updateShare {
    _share.enabled = _picked.count > 0 && !_sharing;
}

- (void)cancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)share {
    _sharing = YES;
    [self updateShare];
    __weak SGRLyricCardPicker *weakSelf = self;
    SGRShareLyricCard([_lines objectsAtIndexes:_picked], _pronunciation, _track, self, _share, ^(BOOL shared) {
        SGRLyricCardPicker *picker = weakSelf;
        if (!picker) return;
        picker->_sharing = NO;
        [picker updateShare];
        if (shared) [picker dismissViewControllerAnimated:YES completion:nil];
    });
}

@end

void SGRPresentLyricCardPicker(NSArray<SGRLyricCardLine *> *lines, NSUInteger picked, BOOL pronunciation, NSString *trackID) {
    UIViewController *top = SGTopController();
    if (!top || !lines.count) return;
    SGRLyricCardPicker *picker = [[SGRLyricCardPicker alloc] initWithLines:lines picked:picked pronunciation:pronunciation track:trackID];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:picker];
    navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    SGPresentDark(navigation);
    [top presentViewController:navigation animated:YES completion:nil];
}
