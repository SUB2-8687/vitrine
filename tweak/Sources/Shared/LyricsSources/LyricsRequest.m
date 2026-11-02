#import "LyricsSources.h"

BOOL SGLyricsReplyFailed(NSURLResponse *response, NSError *error) {
    NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
    return error || status == 429 || status >= 500;
}

@implementation SGLyricsRequestContext {
    BOOL _failed;
}
- (BOOL)failed { @synchronized (self) { return _failed; } }
- (void)noteFailure:(BOOL)failed { if (failed) @synchronized (self) { _failed = YES; } }
- (void)noteResponse:(NSURLResponse *)response error:(NSError *)error {
    [self noteFailure:SGLyricsReplyFailed(response, error)];
}
@end

@implementation SGLyricsLease {
    BOOL _retired;
}
- (void)invalidate { @synchronized (self) { _retired = YES; } }
- (void)perform:(dispatch_block_t)work { @synchronized (self) { if (!_retired) work(); } }
@end
