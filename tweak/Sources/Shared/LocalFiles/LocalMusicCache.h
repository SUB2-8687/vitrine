#import <UIKit/UIKit.h>

// Device/inode/size and nanosecond modification/change times. Nil for a missing or non-regular file.
NSArray<NSNumber *> *SGLocalMusicFileIdentity(NSURL *url);

// Serial-worker owner of raw metadata, never decoded images.
@interface SGLocalMusicFileCache : NSObject
- (NSDictionary *)entryForName:(NSString *)name identity:(NSArray *(^)(void))identity
                         read:(NSDictionary *(^)(void))read;
- (void)retainNames:(NSArray<NSString *> *)names;
- (void)invalidateName:(NSString *)name;
@end

@interface SGLocalMusicArtworkReference : NSObject
@property (nonatomic, readonly, strong) NSURL *url;
@property (nonatomic, readonly, copy) NSArray *identity;
@property (nonatomic, readonly, copy) NSString *format;
@property (nonatomic, readonly) NSUInteger item;
@property (nonatomic, readonly) BOOL edited;
- (instancetype)initWithURL:(NSURL *)url identity:(NSArray *)identity format:(NSString *)format
                      item:(NSUInteger)item edited:(BOOL)edited;
- (NSArray *)cacheKeyForPixelSize:(NSUInteger)pixels;
@end

@interface SGLocalMusicArtworkCache : NSObject
+ (instancetype)sharedCache;
// Only displayed views request work; cancel the returned operation when a view leaves/reuses.
- (NSOperation *)load:(SGLocalMusicArtworkReference *)reference pixelSize:(NSUInteger)pixels
          completion:(void (^)(UIImage *))completion;
// Synchronous worker entry, with the decoder boundary supplied for the pure cache check.
- (UIImage *)imageForReference:(SGLocalMusicArtworkReference *)reference pixelSize:(NSUInteger)pixels
                       decode:(UIImage *(^)(void))decode;
- (void)purge;
@end
