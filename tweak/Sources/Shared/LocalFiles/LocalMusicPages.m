#import "LocalMusicPages.h"
#import "LocalMusicStore.h"
#import "LocalFiles.h"
#import "Core/SGLocalize.h"
#import "Settings/SGPageStyle.h"
#import "LocalMusicShelf.h"
#import "LocalMusicPlayback.h"

static NSString *unknown(void) { return SGL(@"settings.localmusic.unknown", @"Unknown"); }
static NSString *groupTitle(SGLocalMusicGroup *group, NSString *kind) {
    if (group.name.length) return group.name;
    return [kind isEqual:@"folder"] ? SGL(@"settings.localmusic.imported", @"Imported") : unknown();
}
static UIColor *coverColour(UIImage *image) {
    if (!image.CGImage) return [UIColor colorWithWhite:0.16 alpha:1];
    uint8_t pixel[4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (!context) return [UIColor colorWithWhite:0.16 alpha:1];
    CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), image.CGImage);
    CGContextRelease(context);
    // A dark tint keeps the white title readable regardless of the cover's luminance.
    return [UIColor colorWithRed:pixel[0] / 510.0 green:pixel[1] / 510.0 blue:pixel[2] / 510.0 alpha:1];
}

@interface SGLocalMusicRowCell : UITableViewCell
@property (nonatomic, strong) NSOperation *artworkRequest;
@end
@implementation SGLocalMusicRowCell
- (void)prepareForReuse { [super prepareForReuse]; [self.artworkRequest cancel]; self.artworkRequest = nil; }
@end

@implementation SGLocalMusicPage {
    SGLocalMusicIndex *_index;
    BOOL _live, _allSongs;
    NSString *_kind;
    NSArray *_key;
    NSInteger _category;
    id _observer;
    UIStackView *_header;
    UIImageView *_artwork;
    UILabel *_initial;
    NSUInteger _artGeneration, _coverGeneration;
    NSOperation *_headerArtworkRequest;
}
- (instancetype)initWithIndex:(SGLocalMusicIndex *)index kind:(NSString *)kind key:(NSArray<NSString *> *)key {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _index = index;
    _live = index == nil;
    _kind = [kind copy];
    _key = [key copy];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
    [self.tableView registerClass:SGLocalMusicRowCell.class forCellReuseIdentifier:@"row"];
    [self.tableView registerClass:SGLocalMusicShelf.class forCellReuseIdentifier:@"shelf"];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:SGL(@"settings.localmusic.add", @"Add Files") style:UIBarButtonItemStylePlain
        target:self action:@selector(addFiles)];
    if (_live) {
        __weak typeof(self) weakSelf = self;
        _observer = [NSNotificationCenter.defaultCenter addObserverForName:SGLocalMusicIndexDidChangeNotification
            object:SGLocalMusicStore.sharedStore queue:nil usingBlock:^(NSNotification *note) {
                SGLocalMusicPage *page = weakSelf;
                if (!page) return;
                page->_index = SGLocalMusicStore.sharedStore.index;
                [page rebuild];
            }];
        _index = SGLocalMusicStore.sharedStore.index;
    }
    [self rebuild];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_live) [SGLocalMusicStore.sharedStore reload];
}
- (void)dealloc {
    if (_observer) [NSNotificationCenter.defaultCenter removeObserver:_observer];
}
- (void)addFiles { SGLocalAudioPresentPicker(self); }
- (NSArray<SGLocalMusicGroup *> *)groups {
    NSString *kind = [_kind isEqual:@"library"] ? @[@"artist", @"album", @"folder"][_category] : _kind;
    return [kind isEqual:@"artist"] ? _index.artists : [kind isEqual:@"album"] ? _index.albums : _index.folders;
}
- (SGLocalMusicGroup *)group {
    for (SGLocalMusicGroup *group in [self groups]) if ([group.key isEqual:_key]) return group;
    return nil;
}
- (UILabel *)label:(NSString *)text style:(UIFontTextStyle)style {
    UILabel *label = [UILabel new];
    label.text = text;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont preferredFontForTextStyle:style];
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 0;
    return label;
}
- (void)rebuild {
    ++_artGeneration;
    [_headerArtworkRequest cancel];
    SGLocalMusicGroup *group = [self group];
    BOOL library = [_kind isEqual:@"library"];
    self.title = library ? SGL(@"settings.localmusic.library", @"Local Library") : groupTitle(group, _kind);
    _header = [[UIStackView alloc] init];
    _header.axis = UILayoutConstraintAxisVertical;
    _header.spacing = 16;
    _header.layoutMargins = UIEdgeInsetsMake(24, 20, 24, 20);
    _header.layoutMarginsRelativeArrangement = YES;
    _header.layer.cornerRadius = 20;
    _header.clipsToBounds = YES;
    _header.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1];
    if (!library) {
        UIView *art = [UIView new];
        [art.heightAnchor constraintEqualToConstant:200].active = YES;
        _artwork = [UIImageView new];
        _artwork.contentMode = UIViewContentModeScaleAspectFit;
        _artwork.translatesAutoresizingMaskIntoConstraints = NO;
        [art addSubview:_artwork];
        _initial = [self label:self.title.length ? [self.title substringWithRange:[self.title rangeOfComposedCharacterSequenceAtIndex:0]] : @"" style:UIFontTextStyleLargeTitle];
        _initial.font = [UIFont systemFontOfSize:72 weight:UIFontWeightBold];
        _initial.textAlignment = NSTextAlignmentCenter;
        _initial.translatesAutoresizingMaskIntoConstraints = NO;
        [art addSubview:_initial];
        [NSLayoutConstraint activateConstraints:@[
            [_artwork.topAnchor constraintEqualToAnchor:art.topAnchor], [_artwork.bottomAnchor constraintEqualToAnchor:art.bottomAnchor],
            [_artwork.leadingAnchor constraintEqualToAnchor:art.leadingAnchor], [_artwork.trailingAnchor constraintEqualToAnchor:art.trailingAnchor],
            [_initial.centerXAnchor constraintEqualToAnchor:art.centerXAnchor], [_initial.centerYAnchor constraintEqualToAnchor:art.centerYAnchor],
        ]];
        [_header addArrangedSubview:art];
        [self showCover:nil generation:_artGeneration];
        NSUInteger generation = _artGeneration;
        __weak typeof(self) weakSelf = self;
        _headerArtworkRequest = [SGLocalMusicArtworkCache.sharedCache load:group.artwork
            pixelSize:(NSUInteger)ceil(200 * self.traitCollection.displayScale) completion:^(UIImage *image) {
                [weakSelf showCover:image generation:generation];
            }];
    }
    [_header addArrangedSubview:[self label:self.title style:UIFontTextStyleLargeTitle]];
    if (!SGLocalMusicPlaybackAvailable()) {
        UILabel *notice = [self label:SGL(@"settings.localmusic.browse", @"Browse only. Playback and queueing are not verified for these files in this Spotify version.") style:UIFontTextStyleFootnote];
        notice.textColor = [UIColor colorWithWhite:1 alpha:0.75];
        [_header addArrangedSubview:notice];
    } else if ([(library ? _index.songs : group.songs) filteredArrayUsingPredicate:
                [NSPredicate predicateWithBlock:^BOOL(SGLocalMusicSong *song, NSDictionary *bindings) {
                    return !song.playbackURI.length;
                }]].count) {
        UILabel *notice = [self label:SGL(@"settings.localmusic.verify_songs", @"To play unverified songs here, first play them once in Spotify's Local Files. Spoof Premium alone does not verify them.") style:UIFontTextStyleFootnote];
        notice.textColor = [UIColor colorWithWhite:1 alpha:0.75];
        [_header addArrangedSubview:notice];
    } else if (!library && SGLocalMusicCanPlaySongs(group.songs)) {
        __weak typeof(self) weakSelf = self;
        UIButton *play = [UIButton buttonWithType:UIButtonTypeSystem];
        [play setTitle:SGL(@"settings.localmusic.play", @"Play") forState:UIControlStateNormal];
        [play addAction:[UIAction actionWithHandler:^(UIAction *action) { [weakSelf playSongs:group.songs shuffle:NO]; }]
            forControlEvents:UIControlEventTouchUpInside];
        UIButton *shuffle = [UIButton buttonWithType:UIButtonTypeSystem];
        [shuffle setTitle:SGL(@"settings.localmusic.shuffle", @"Shuffle") forState:UIControlStateNormal];
        [shuffle addAction:[UIAction actionWithHandler:^(UIAction *action) { [weakSelf playSongs:group.songs shuffle:YES]; }]
            forControlEvents:UIControlEventTouchUpInside];
        UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[play, shuffle]];
        buttons.distribution = UIStackViewDistributionFillEqually;
        [buttons.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        [_header addArrangedSubview:buttons];
    }
    if (library) {
        UISegmentedControl *tabs = [[UISegmentedControl alloc] initWithItems:@[
            SGL(@"settings.localmusic.artists", @"Artists"), SGL(@"settings.localmusic.albums", @"Albums"), SGL(@"settings.localmusic.folders", @"Folders")]];
        tabs.selectedSegmentIndex = _category;
        [tabs addTarget:self action:@selector(categoryChanged:) forControlEvents:UIControlEventValueChanged];
        [_header addArrangedSubview:tabs];
    } else if ([_kind isEqual:@"album"]) {
        SGLocalMusicGroup *artist = [_index artistNamed:group.artist];
        if (artist) {
            __weak typeof(self) weakSelf = self;
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            [button setTitle:SGL(@"settings.localmusic.go_artist", @"Go to Artist") forState:UIControlStateNormal];
            [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
            [button addAction:[UIAction actionWithHandler:^(UIAction *action) { [weakSelf openGroup:artist kind:@"artist"]; }] forControlEvents:UIControlEventTouchUpInside];
            [_header addArrangedSubview:button];
        }
    }
    self.tableView.tableHeaderView = _header;
    [self fitHeader];
    [self.tableView reloadData];
}
- (void)showCover:(UIImage *)image generation:(NSUInteger)generation {
    if (generation != _artGeneration) return;
    NSUInteger coverGeneration = ++_coverGeneration;
    _artwork.image = image;
    _initial.hidden = image != nil;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        UIColor *colour = coverColour(image);
        dispatch_async(dispatch_get_main_queue(), ^{
            SGLocalMusicPage *page = weakSelf;
            if (page && generation == page->_artGeneration && coverGeneration == page->_coverGeneration)
                page->_header.backgroundColor = colour;
        });
    });
}
- (void)fitHeader {
    CGFloat width = self.tableView.bounds.size.width;
    CGSize size = [_header systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
        withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    if (_header.frame.size.width != width || _header.frame.size.height != size.height) {
        _header.frame = CGRectMake(0, 0, width, size.height);
        self.tableView.tableHeaderView = _header;
    }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    SGInsetForBars(self.tableView);
    [self fitHeader];
}
- (void)categoryChanged:(UISegmentedControl *)sender { _category = sender.selectedSegmentIndex; [self.tableView reloadData]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {
    return [_kind isEqual:@"artist"] && [_index albumsForArtist:[self group]].count ? 2 : 1;
}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {
    if ([_kind isEqual:@"library"]) return nil;
    return section == 1 ? SGL(@"settings.localmusic.albums", @"Albums") : SGL(@"settings.localmusic.songs", @"Songs");
}
- (NSArray<SGLocalMusicSong *> *)shownSongs {
    NSArray *songs = [self group].songs;
    return [_kind isEqual:@"artist"] && !_allSongs && songs.count > 5 ? [songs subarrayWithRange:NSMakeRange(0, 5)] : songs;
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {
    if ([_kind isEqual:@"library"]) return MAX([self groups].count, 1);
    if (section == 1) return 1;
    NSUInteger count = [self shownSongs].count;
    return MAX(count, 1) + ([_kind isEqual:@"artist"] && !_allSongs && [self group].songs.count > 5 ? 1 : 0);
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    if (path.section == 1) {
        SGLocalMusicShelf *cell = [table dequeueReusableCellWithIdentifier:@"shelf" forIndexPath:path];
        __weak typeof(self) weakSelf = self;
        [cell showAlbums:[_index albumsForArtist:[self group]] select:^(SGLocalMusicGroup *album) {
            [weakSelf openGroup:album kind:@"album"];
        }];
        return cell;
    }
    SGLocalMusicRowCell *cell = [table dequeueReusableCellWithIdentifier:@"row" forIndexPath:path];
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    UIListContentConfiguration *content = cell.defaultContentConfiguration;
    if ([_kind isEqual:@"library"] && [self groups].count) {
        SGLocalMusicGroup *group = [self groups][path.row];
        content.text = groupTitle(group, @[@"artist", @"album", @"folder"][_category]);
        content.secondaryText = _category == 1 ? (group.artist.length ? group.artist : unknown()) : nil;
        content.image = [UIImage systemImageNamed:@[@"person.crop.square", @"opticaldisc", @"folder"][_category]];
        content.imageProperties.maximumSize = CGSizeMake(48, 48);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (![_kind isEqual:@"library"] && [self shownSongs].count && (NSUInteger)path.row < [self shownSongs].count) {
        SGLocalMusicSong *song = [self shownSongs][path.row];
        content.text = song.title;
        content.secondaryText = song.artist.length ? song.artist : unknown();
        content.image = [UIImage systemImageNamed:@"music.note"];
        cell.selectionStyle = SGLocalMusicCanPlaySongs(@[song]) ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    } else if ([self shownSongs].count && ![_kind isEqual:@"library"]) {
        content.text = SGL(@"settings.localmusic.see_all", @"See All");
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        content.text = _index ? SGL(@"settings.localmusic.empty", @"No imported files") : SGL(@"settings.localmusic.loading", @"Loading local files…");
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    cell.contentConfiguration = content;
    return cell;
}
- (void)tableView:(UITableView *)table willDisplayCell:(UITableViewCell *)item forRowAtIndexPath:(NSIndexPath *)path {
    if (![_kind isEqual:@"library"] || ![self groups].count) return;
    SGLocalMusicRowCell *cell = (id)item;
    [cell.artworkRequest cancel];
    __weak UITableViewCell *weakCell = cell;
    cell.artworkRequest = [SGLocalMusicArtworkCache.sharedCache load:[self groups][path.row].artwork
        pixelSize:(NSUInteger)ceil(48 * self.traitCollection.displayScale) completion:^(UIImage *image) {
            UITableViewCell *shown = weakCell;
            if (!shown || !image) return;
            UIListContentConfiguration *content = [(UIListContentConfiguration *)shown.contentConfiguration copy];
            content.image = image;
            shown.contentConfiguration = content;
        }];
}
- (void)tableView:(UITableView *)table didEndDisplayingCell:(UITableViewCell *)item forRowAtIndexPath:(NSIndexPath *)path {
    if (![item isKindOfClass:SGLocalMusicRowCell.class]) return;
    SGLocalMusicRowCell *cell = (id)item;
    [cell.artworkRequest cancel];
    cell.artworkRequest = nil;
    UIListContentConfiguration *content = [(UIListContentConfiguration *)cell.contentConfiguration copy];
    content.image = nil;
    cell.contentConfiguration = content;
}
- (void)openGroup:(SGLocalMusicGroup *)group kind:(NSString *)kind {
    SGLocalMusicPage *page = [[SGLocalMusicPage alloc] initWithIndex:_live ? nil : _index kind:kind key:group.key];
    SGShowPage(self, page);
}
- (void)showPlaybackError:(NSError *)error {
    if (error) SGPresentInformation(self, SGLocalMusicFailureMessage(error), nil);
}
- (void)playSongs:(NSArray *)songs shuffle:(BOOL)shuffle {
    __weak typeof(self) weakSelf = self;
    SGLocalMusicPlay(songs, shuffle, ^(NSError *error) { [weakSelf showPlaybackError:error]; });
}
- (void)queueSong:(SGLocalMusicSong *)song next:(BOOL)next {
    __weak typeof(self) weakSelf = self;
    SGLocalMusicQueue(song, next, ^(NSError *error) { [weakSelf showPlaybackError:error]; });
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];
    if (path.section) return;
    if ([_kind isEqual:@"library"] && [self groups].count)
        [self openGroup:[self groups][path.row] kind:@[@"artist", @"album", @"folder"][_category]];
    else if ([_kind isEqual:@"artist"] && (NSUInteger)path.row == [self shownSongs].count && [self group].songs.count > 5) {
        _allSongs = YES;
        [table reloadData];
    } else if (![_kind isEqual:@"library"] && (NSUInteger)path.row < [self shownSongs].count) {
        SGLocalMusicSong *song = [self shownSongs][path.row];
        if (SGLocalMusicCanPlaySongs(@[song])) [self playSongs:@[song] shuffle:NO];
    }
}
- (UIContextMenuConfiguration *)tableView:(UITableView *)table contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)path point:(CGPoint)point {
    if ([_kind isEqual:@"library"] || path.section || (NSUInteger)path.row >= [self shownSongs].count) return nil;
    SGLocalMusicSong *song = [self shownSongs][path.row];
    SGLocalMusicGroup *artist = [_index artistNamed:song.artist];
    BOOL playable = SGLocalMusicCanPlaySongs(@[song]);
    if (!artist && !playable) return nil;
    __weak typeof(self) weakSelf = self;
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray *suggested) {
        NSMutableArray *actions = [NSMutableArray array];
        if (playable) {
            [actions addObject:[UIAction actionWithTitle:SGL(@"settings.localmusic.play_next", @"Play Next") image:[UIImage systemImageNamed:@"text.line.first.and.arrowtriangle.forward"] identifier:nil handler:^(UIAction *action) {
                [weakSelf queueSong:song next:YES];
            }]];
            [actions addObject:[UIAction actionWithTitle:SGL(@"settings.localmusic.queue", @"Add to Queue") image:[UIImage systemImageNamed:@"text.badge.plus"] identifier:nil handler:^(UIAction *action) {
                [weakSelf queueSong:song next:NO];
            }]];
        }
        if (artist) [actions addObject:[UIAction actionWithTitle:SGL(@"settings.localmusic.go_artist", @"Go to Artist") image:[UIImage systemImageNamed:@"person"] identifier:nil handler:^(UIAction *action) {
            [weakSelf openGroup:artist kind:@"artist"];
        }]];
        return [UIMenu menuWithChildren:actions];
    }];
}
@end

UIViewController *SGLocalMusicLibraryPage(void) {
    return [[SGLocalMusicPage alloc] initWithIndex:nil kind:@"library" key:nil];
}
