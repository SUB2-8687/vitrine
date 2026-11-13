#import <Foundation/Foundation.h>
@class SGTranslationFiles;

// ZIP32 stored output; stored/raw-deflate input. Archive names are never extracted.
// All work runs on the same executor as SGTranslationFiles.
@interface SGTranslationTransfer : NSObject
+ (NSArray<NSURL *> *)exportRecords:(NSArray<NSDictionary *> *)selection sessionRecords:(NSDictionary<NSString *, NSDictionary *> *)sessionRecords
                             store:(SGTranslationFiles *)store error:(NSError **)error;
+ (NSDictionary *)stageURL:(NSURL *)url store:(SGTranslationFiles *)store error:(NSError **)error;
+ (NSDictionary *)pendingStage:(SGTranslationFiles *)store error:(NSError **)error;
+ (BOOL)discardStage:(NSDictionary *)stage store:(SGTranslationFiles *)store error:(NSError **)error;
+ (BOOL)reclaimStaging:(SGTranslationFiles *)store error:(NSError **)error;
+ (NSDictionary *)applyStage:(NSDictionary *)stage replace:(BOOL)replace store:(SGTranslationFiles *)store
                     allowed:(BOOL (^)(void))allowed error:(NSError **)error;
@end
