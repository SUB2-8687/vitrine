#import <Foundation/Foundation.h>

// Hold download completion with an offline installed-family set. nil restores the real service.
void SGHarnessHoldFontDownloads(NSArray<NSString *> *installed);
void SGHarnessFinishFontDownload(void);
