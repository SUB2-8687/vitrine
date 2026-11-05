// Opt in only from harnesses whose contract excludes active picture in picture.
#import "Shared/LyricsPiP/LyricsPiP.h"

NSNotificationName const SGLyricsPiPDidChangeNotification = @"harness.lyricsPiPDidChange";
BOOL SGLyricsPiPEnabled(void) { return NO; }
BOOL SGLyricsPiPActive(void) { return NO; }
BOOL SGLyricsPiPStarting(void) { return NO; }
void SGLyricsPiPToggle(UIView *from) {}
