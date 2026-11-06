#import "LocalMusicShelf.h"
#import "Core/SGLocalize.h"

static const CGFloat kAlbumArtworkSidePoints = 140;

@interface SGLocalMusicAlbumTile : UICollectionViewCell
@property (nonatomic, strong) UIImageView *artwork;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) NSOperation *request;
@end
@implementation SGLocalMusicAlbumTile
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _artwork = [UIImageView new];
    _artwork.contentMode = UIViewContentModeScaleAspectFit;
    _artwork.clipsToBounds = YES;
    [_artwork.heightAnchor constraintEqualToConstant:kAlbumArtworkSidePoints].active = YES;
    _title = [UILabel new];
    _title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _title.adjustsFontForContentSizeCategory = YES;
    _title.numberOfLines = 2;
    _title.textColor = UIColor.whiteColor;
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_artwork, _title]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor],
    ]];
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    return self;
}
- (void)prepareForReuse {
    [super prepareForReuse];
    [self.request cancel];
    self.request = nil;
    self.artwork.image = nil;
}
@end

@interface SGLocalMusicShelf () <UICollectionViewDataSource, UICollectionViewDelegate>
@end
@implementation SGLocalMusicShelf {
    UICollectionView *_collection;
    NSArray<SGLocalMusicGroup *> *_albums;
    void (^_select)(SGLocalMusicGroup *);
    NSLayoutConstraint *_height;
}
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if (!(self = [super initWithStyle:style reuseIdentifier:identifier])) return nil;
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumLineSpacing = 12;
    _collection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collection.backgroundColor = UIColor.clearColor;
    _collection.dataSource = self;
    _collection.delegate = self;
    _collection.prefetchingEnabled = NO;
    [_collection registerClass:SGLocalMusicAlbumTile.class forCellWithReuseIdentifier:@"album"];
    _collection.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_collection];
    _height = [_collection.heightAnchor constraintEqualToConstant:200];
    [NSLayoutConstraint activateConstraints:@[
        [_collection.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [_collection.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [_collection.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [_collection.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12], _height,
    ]];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    return self;
}
- (void)showAlbums:(NSArray<SGLocalMusicGroup *> *)albums select:(void (^)(SGLocalMusicGroup *))select {
    _albums = albums;
    _select = [select copy];
    CGFloat height = kAlbumArtworkSidePoints + 8 + ceil([UIFont preferredFontForTextStyle:UIFontTextStyleCaption1].lineHeight * 2);
    ((UICollectionViewFlowLayout *)_collection.collectionViewLayout).itemSize = CGSizeMake(kAlbumArtworkSidePoints, height);
    _height.constant = height;
    [_collection reloadData];
}
- (NSInteger)collectionView:(UICollectionView *)collection numberOfItemsInSection:(NSInteger)section { return _albums.count; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)collection cellForItemAtIndexPath:(NSIndexPath *)path {
    SGLocalMusicAlbumTile *cell = [collection dequeueReusableCellWithReuseIdentifier:@"album" forIndexPath:path];
    SGLocalMusicGroup *album = _albums[path.item];
    cell.title.text = album.name.length ? album.name : SGL(@"settings.localmusic.unknown", @"Unknown");
    cell.accessibilityLabel = cell.title.text;
    cell.artwork.image = [UIImage systemImageNamed:@"opticaldisc"];
    return cell;
}
- (void)collectionView:(UICollectionView *)collection willDisplayCell:(UICollectionViewCell *)item forItemAtIndexPath:(NSIndexPath *)path {
    SGLocalMusicAlbumTile *cell = (id)item;
    [cell.request cancel];
    __weak SGLocalMusicAlbumTile *weakCell = cell;
    cell.request = [SGLocalMusicArtworkCache.sharedCache load:_albums[path.item].artwork
        pixelSize:(NSUInteger)ceil(kAlbumArtworkSidePoints * self.traitCollection.displayScale) completion:^(UIImage *image) {
            if (image) weakCell.artwork.image = image;
        }];
}
- (void)collectionView:(UICollectionView *)collection didEndDisplayingCell:(UICollectionViewCell *)item forItemAtIndexPath:(NSIndexPath *)path {
    SGLocalMusicAlbumTile *cell = (id)item;
    [cell.request cancel];
    cell.request = nil;
    cell.artwork.image = nil;
}
- (void)collectionView:(UICollectionView *)collection didSelectItemAtIndexPath:(NSIndexPath *)path { _select(_albums[path.item]); }
@end
