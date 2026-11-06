#import "LocalMusicCache.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#include <sys/stat.h>

NSArray<NSNumber *> *SGLocalMusicFileIdentity(NSURL *url) {
    struct stat info;
    if (lstat(url.fileSystemRepresentation, &info) || !S_ISREG(info.st_mode)) return nil;
    return @[@(info.st_dev), @(info.st_ino), @(info.st_size),
             @(info.st_mtimespec.tv_sec), @(info.st_mtimespec.tv_nsec),
             @(info.st_ctimespec.tv_sec), @(info.st_ctimespec.tv_nsec)];
}

@implementation SGLocalMusicFileCache {
    NSMutableDictionary *_entries;
}
- (instancetype)init {
    if ((self = [super init])) _entries = [NSMutableDictionary dictionary];
    return self;
}
- (NSDictionary *)entryForName:(NSString *)name identity:(NSArray *(^)(void))identity read:(NSDictionary *(^)(void))read {
    NSArray *before = identity();
    NSDictionary *entry = _entries[name];
    NSDictionary *metadata = before && [entry[@"identity"] isEqual:before] ? entry[@"metadata"] : before ? read() : nil;
    if (!metadata || ![before isEqual:identity()]) {
        [_entries removeObjectForKey:name];
        return nil;
    }
    entry = @{@"identity": before, @"metadata": metadata};
    _entries[name] = entry;
    return entry;
}
- (void)retainNames:(NSArray<NSString *> *)names {
    NSSet *keep = [NSSet setWithArray:names];
    for (NSString *name in _entries.allKeys) if (![keep containsObject:name]) [_entries removeObjectForKey:name];
}
- (void)invalidateName:(NSString *)name { [_entries removeObjectForKey:name]; }
@end

@implementation SGLocalMusicArtworkReference
- (instancetype)initWithURL:(NSURL *)url identity:(NSArray *)identity format:(NSString *)format item:(NSUInteger)item edited:(BOOL)edited {
    if (!(self = [super init])) return nil;
    _url = url; _identity = [identity copy]; _format = [format copy]; _item = item; _edited = edited;
    return self;
}
- (NSArray *)cacheKeyForPixelSize:(NSUInteger)pixels {
    return @[self.url.path, self.identity, self.format ?: @"", @(self.item), @(pixels)];
}
@end

static UIImage *decodeArtwork(SGLocalMusicArtworkReference *reference, NSUInteger pixels) {
    CGImageSourceRef source = NULL;
    if (reference.format) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:reference.url options:nil];
        NSArray<AVMetadataItem *> *items = [asset metadataForFormat:reference.format];
        if (reference.item >= items.count) return nil;
        NSData *data = items[reference.item].dataValue;
        if (data.length) source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    } else source = CGImageSourceCreateWithURL((__bridge CFURLRef)reference.url, NULL);
    if (!source) return nil;
    NSDictionary *options = @{(id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                              (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
                              (id)kCGImageSourceThumbnailMaxPixelSize: @(pixels),
                              (id)kCGImageSourceShouldCacheImmediately: @YES};
    CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    if (!image) return nil;
    UIImage *result = [UIImage imageWithCGImage:image];
    CGImageRelease(image);
    return result;
}

static const NSUInteger kArtworkCacheByteLimit = 16 * 1024 * 1024;
@implementation SGLocalMusicArtworkCache {
    NSCache<NSArray *, UIImage *> *_images;
    NSOperationQueue *_queue;
    id _memoryWarning;
    NSUInteger _epoch;
}
+ (instancetype)sharedCache {
    static SGLocalMusicArtworkCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [SGLocalMusicArtworkCache new]; });
    return cache;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _images = [NSCache new];
    _images.totalCostLimit = kArtworkCacheByteLimit;
    _queue = [NSOperationQueue new];
    _queue.maxConcurrentOperationCount = 1;
    _queue.qualityOfService = NSQualityOfServiceUtility;
    __weak typeof(self) weakSelf = self;
    _memoryWarning = [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [weakSelf purge];
    }];
    return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:_memoryWarning]; }
- (void)purge {
    @synchronized(self) { ++_epoch; [_images removeAllObjects]; }
    [_queue cancelAllOperations];
}
- (UIImage *)imageForReference:(SGLocalMusicArtworkReference *)reference pixelSize:(NSUInteger)pixels decode:(UIImage *(^)(void))decode {
    NSArray *key = [reference cacheKeyForPixelSize:pixels];
    NSUInteger epoch;
    @synchronized(self) {
        UIImage *cached = [_images objectForKey:key];
        if (cached) return cached;
        epoch = _epoch;
    }
    UIImage *image = decode();
    if (image.CGImage) {
        NSUInteger bytes = CGImageGetBytesPerRow(image.CGImage) * CGImageGetHeight(image.CGImage);
        @synchronized(self) {
            if (epoch == _epoch) [_images setObject:image forKey:key cost:bytes];
        }
    }
    return image;
}
- (NSOperation *)load:(SGLocalMusicArtworkReference *)reference pixelSize:(NSUInteger)pixels completion:(void (^)(UIImage *))completion {
    if (!reference || !pixels) { completion(nil); return nil; }
    NSBlockOperation *operation = [NSBlockOperation new];
    __weak NSBlockOperation *weakOperation = operation;
    [operation addExecutionBlock:^{
        NSBlockOperation *request = weakOperation;
        if (!request || request.cancelled) return;
        UIImage *image;
        if ([SGLocalMusicFileIdentity(reference.url) isEqual:reference.identity]) {
            image = [self imageForReference:reference pixelSize:pixels decode:^{ return decodeArtwork(reference, pixels); }];
            if (![SGLocalMusicFileIdentity(reference.url) isEqual:reference.identity]) image = nil;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!request.cancelled) completion(image);
        });
    }];
    [_queue addOperation:operation];
    return operation;
}
@end
