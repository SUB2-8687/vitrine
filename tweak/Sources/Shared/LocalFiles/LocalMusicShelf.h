#import "LocalMusicIndex.h"

@interface SGLocalMusicShelf : UITableViewCell
- (void)showAlbums:(NSArray<SGLocalMusicGroup *> *)albums select:(void (^)(SGLocalMusicGroup *))select;
@end
