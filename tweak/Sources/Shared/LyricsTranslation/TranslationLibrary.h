#import <UIKit/UIKit.h>

@class SGModRow;
typedef void (^SGLyricsSavedCompletion)(BOOL durable, NSError *error);
UIViewController *SGSavedTranslationsPage(void);
void SGSavedRecords(NSString *after, void (^done)(NSArray<NSDictionary *> *records, NSString *next, NSDictionary *summary, NSString *warning));
void SGSavedExport(NSArray<NSDictionary *> *selection, void (^done)(NSArray<NSURL *> *files, NSError *error));
void SGSavedImport(NSURL *file, BOOL replace, BOOL preview, void (^done)(NSDictionary *report, NSError *error));
void SGSavedDiscardPreview(void (^done)(NSError *error));
void SGSavedRemove(NSArray<NSDictionary *> *selection, BOOL all, void (^done)(NSError *error));
void SGSavedRestore(NSDictionary *record, void (^done)(NSError *error));
void SGSavedRetry(void (^done)(NSError *error));
