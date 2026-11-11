#import "LyricsSources.h"

BOOL SGLyricsReplyFailed(NSURLResponse *response, NSError *error) {
    NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
    return error || status == 429 || status >= 500;
}

@implementation SGLyricsRequestContext {
    BOOL _failed;
    BOOL _nameSearchFailed;
    SGLyricsAsk _emptyNameSearch;
}
- (BOOL)failed { @synchronized (self) { return _failed; } }
- (SGLyricsAsk)emptyNameSearch { @synchronized (self) { return _nameSearchFailed ? nil : _emptyNameSearch; } }
- (void)setEmptyNameSearch:(SGLyricsAsk)search { @synchronized (self) { _emptyNameSearch = [search copy]; } }
- (void)noteFailure:(BOOL)failed { if (failed) @synchronized (self) { _failed = YES; } }
- (void)noteResponse:(NSURLResponse *)response error:(NSError *)error {
    [self noteFailure:SGLyricsReplyFailed(response, error)];
    NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
    if (error || (status && (status < 200 || status >= 300) && status != 404))
        @synchronized (self) { _nameSearchFailed = YES; }
}
@end

@implementation SGLyricsLease {
    BOOL _retired;
}
- (void)invalidate { @synchronized (self) { _retired = YES; } }
- (void)perform:(dispatch_block_t)work { @synchronized (self) { if (!_retired) work(); } }
@end
