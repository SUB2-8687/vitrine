#import "Settings/SGPage.h"
#import "LocalMusicIndex.h"

UIViewController *SGLocalMusicLibraryPage(void);
// The existing import picker, shared by settings and the browsing pages.
void SGLocalAudioPresentPicker(UIViewController *presenter);

// A supplied snapshot is useful for previews; live pages use the shared store instead.
@interface SGLocalMusicPage : SGPage
- (instancetype)initWithIndex:(SGLocalMusicIndex *)index kind:(NSString *)kind key:(NSArray<NSString *> *)key;
@end
