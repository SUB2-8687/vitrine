// Real JSON transport and NetEase provider; only NSURLSession and the external keeper are doubles.
#import "Core/SGCore.h"
#import "Shared/LyricsSources/LyricsSources.h"
#import <stdatomic.h>
#import <objc/runtime.h>
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAILED line %d: %s\n", __LINE__, #c); exit(1); } } while (0)
static NSData *(^reply)(NSURLRequest *);
static NSInteger replyStatus = 200;
static NSError *replyError;
static _Atomic NSUInteger decoded;
static IMP originalJSON, originalLineStart, originalXML, originalMatches;
static BOOL watchModels;
static void checkedLineStart(id line, SEL selector, NSInteger start) {
    if (watchModels) CHECK(!NSThread.isMainThread);
    ((void (*)(id, SEL, NSInteger))originalLineStart)(line, selector, start);
}
static BOOL checkedXML(id object, SEL selector) {
    CHECK(!NSThread.isMainThread);
    return ((BOOL (*)(id, SEL))originalXML)(object, selector);
}
static id checkedMatches(NSRegularExpression *regex, SEL selector, NSString *text, NSMatchingOptions options, NSRange range) {
    if ([regex.pattern hasPrefix:@"<tr"]) CHECK(!NSThread.isMainThread);
    return ((id (*)(id, SEL, NSString *, NSMatchingOptions, NSRange))originalMatches)(regex, selector, text, options, range);
}

@interface TransportTask : NSObject
@property (nonatomic, copy) dispatch_block_t work;
- (void)resume;
@end
@implementation TransportTask
- (void)resume { dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), self.work); }
@end
@interface TransportSession : NSObject
@property (nonatomic, strong) id<NSURLSessionDataDelegate> delegate;
@property (nonatomic, strong) NSOperationQueue *queue;
+ (instancetype)sharedSession;
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue;
- (TransportTask *)dataTaskWithRequest:(NSURLRequest *)request;
- (void)finishTasksAndInvalidate;
- (TransportTask *)dataTaskWithRequest:(NSURLRequest *)request
                    completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))done;
@end
@implementation TransportSession
+ (instancetype)sharedSession { return [self new]; }
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue {
    CHECK(configuration.HTTPCookieStorage == nil && configuration.URLCache == nil);
    TransportSession *session = [self new];
    session.delegate = delegate;
    session.queue = queue ?: [NSOperationQueue new];
    session.queue.maxConcurrentOperationCount = 1;
    return session;
}
- (void)finishTasksAndInvalidate { self.delegate = nil; }
- (TransportTask *)dataTaskWithRequest:(NSURLRequest *)request {
    TransportTask *task = [TransportTask new];
    __weak TransportTask *weakTask = task;
    task.work = ^{
        TransportTask *activeTask = weakTask;
        NSData *data = reply(request);
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:replyStatus HTTPVersion:@"HTTP/1.1" headerFields:nil];
        [self.queue addOperationWithBlock:^{
            CHECK(!NSThread.isMainThread);
            [self.delegate URLSession:(id)self dataTask:(id)activeTask didReceiveResponse:response completionHandler:^(NSURLSessionResponseDisposition disposition) {
                CHECK(disposition == NSURLSessionResponseAllow);
                if (data) [self.delegate URLSession:(id)self dataTask:(id)activeTask didReceiveData:data];
                [self.delegate URLSession:(id)self task:(id)activeTask didCompleteWithError:replyError];
            }];
        }];
    };
    return task;
}
- (TransportTask *)dataTaskWithRequest:(NSURLRequest *)request
                    completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))done {
    TransportTask *task = [TransportTask new];
    task.work = ^{
        NSData *body = reply(request);
        done(body, [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:replyStatus HTTPVersion:@"HTTP/1.1"
            headerFields:@{@"Retry-After": @"7"}], replyError);
    };
    return task;
}
@end
@interface TransportJSON : NSObject
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)options error:(NSError **)error;
+ (BOOL)isValidJSONObject:(id)value;
+ (NSData *)dataWithJSONObject:(id)value options:(NSJSONWritingOptions)options error:(NSError **)error;
@end
@implementation TransportJSON
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)options error:(NSError **)error {
    CHECK(!NSThread.isMainThread);
    atomic_fetch_add(&decoded, 1);
    return ((id (*)(id, SEL, NSData *, NSJSONReadingOptions, NSError **))originalJSON)(NSJSONSerialization.class, _cmd, data, options, error);
}
+ (BOOL)isValidJSONObject:(id)value { return [NSJSONSerialization isValidJSONObject:value]; }
+ (NSData *)dataWithJSONObject:(id)value options:(NSJSONWritingOptions)options error:(NSError **)error {
    return [NSJSONSerialization dataWithJSONObject:value options:options error:error];
}
@end
static const NSTimeInterval kTimeout = 6;
#define NSURLSession TransportSession
#import "transport.inc"
// NetEase has its own 3-second request policy.
#define kTimeout kNetEaseTimeout
#import "Shared/LyricsSources/NetEase.m"
#undef kTimeout
#undef NSURLSession
@implementation SGLyricsResult
@end
@implementation SGLyricsQuery
@end
void SGLyricsPageLines(NSArray *lines, NSArray **starts, NSArray **texts) {
    NSMutableArray *at = [NSMutableArray array], *words = [NSMutableArray array];
    for (SGKaraokeLine *line in lines) { [at addObject:@(line.start)]; [words addObject:SGKaraokeLineText(line)]; }
    *starts = at; *texts = words;
}
static NSString *fixtureISRC;
void SGSpotifyISRC(NSString *uri, NSUInteger tries, void (^done)(NSString *)) { done(fixtureISRC); }
void SGSpotifyISRCWithOutcome(NSString *uri, NSUInteger tries, void (^done)(NSString *, BOOL)) { done(fixtureISRC, NO); }
NSString *SGLyricsTranslationLanguage(void) { return nil; }
static void waitFor(BOOL *finished) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!*finished && deadline.timeIntervalSinceNow > 0)
        [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    CHECK(*finished);
}
static NSData *json(id value) { return [NSJSONSerialization dataWithJSONObject:value options:0 error:nil]; }
int main(void) {
    @autoreleasepool {
        Method jsonMethod = class_getClassMethod(NSJSONSerialization.class, @selector(JSONObjectWithData:options:error:));
        originalJSON = method_setImplementation(jsonMethod, class_getMethodImplementation(object_getClass(TransportJSON.class), @selector(JSONObjectWithData:options:error:)));
        originalLineStart = method_setImplementation(class_getInstanceMethod(SGKaraokeLine.class, @selector(setStart:)), (IMP)checkedLineStart);
        originalXML = method_setImplementation(class_getInstanceMethod(NSXMLParser.class, @selector(parse)), (IMP)checkedXML);
        originalMatches = method_setImplementation(class_getInstanceMethod(NSRegularExpression.class, @selector(matchesInString:options:range:)), (IMP)checkedMatches);
        NSURL *url = [NSURL URLWithString:@"https://fixture.invalid/lyrics"];
        NSString *large = [@"a" stringByPaddingToLength:500000 withString:@"a" startingAtIndex:0];
        reply = ^NSData *(NSURLRequest *request) { return json(@{@"text": large, @"candidate": @17}); };
        __block BOOL finished = NO;
        SGLyricsGetJSONTransform(url, nil, ^id(id root) {
            CHECK(!NSThread.isMainThread);
            CHECK([root[@"text"] length] == 500000);
            return root[@"candidate"];
        }, ^(id value) { CHECK(NSThread.isMainThread && [value isEqual:@17]); finished = YES; });
        waitFor(&finished);
        CHECK(atomic_load(&decoded) == 1);
        finished = NO;
        SGLyricsPostJSON(url, nil, @{@"ask": @YES}, ^(id root) {
            CHECK(NSThread.isMainThread && [root[@"candidate"] isEqual:@17]); finished = YES;
        });
        waitFor(&finished);
        replyStatus = 429;
        finished = NO;
        SGLyricsGetJSONReply(url, nil, ^(id root, NSHTTPURLResponse *response) {
            CHECK(NSThread.isMainThread && response.statusCode == 429);
            CHECK([response.allHeaderFields[@"Retry-After"] isEqual:@"7"] && [root[@"candidate"] isEqual:@17]);
            finished = YES;
        });
        waitFor(&finished);
        CHECK(atomic_load(&sg_failures) == 1);
        replyStatus = 200;
        reply = ^NSData *(NSURLRequest *request) { return [@"{broken" dataUsingEncoding:NSUTF8StringEncoding]; };
        finished = NO;
        SGLyricsGetJSON(url, nil, ^(id root) { CHECK(NSThread.isMainThread && !root); finished = YES; });
        waitFor(&finished);
        finished = NO;
        SGLyricsPostJSON(url, nil, [NSObject new], ^(id root) { CHECK(NSThread.isMainThread && !root); finished = YES; });
        waitFor(&finished);
        finished = NO;
        SGLyricsGetText(url, ^(NSString *text) { CHECK(NSThread.isMainThread && [text isEqual:@"{broken"]); finished = YES; });
        waitFor(&finished);
        reply = ^NSData *(NSURLRequest *request) {
            CHECK(request.timeoutInterval == 3);
            if ([request.URL.path isEqual:@"/api/search/get"]) return json(@{@"result": @{@"songs": @[
                @{@"id": @1, @"name": @"Different", @"duration": @200000, @"artists": @[@{@"name": @"Singer"}]},
                @{@"id": @2, @"name": @"Fixture (Live)", @"duration": @200000, @"artists": @[@{@"name": @"Singer"}]},
                @{@"id": @3, @"name": @42, @"duration": @200000, @"artists": @[@{@"name": @"Singer"}]},
                @{@"id": @4, @"name": @" Fixture! ", @"duration": @200000, @"artists": @[@{@"name": @"Singer"}]}
            ]}});
            CHECK([request.URL.query containsString:@"id=4"]);
            return json(@{@"yrc": @{@"lyric": @"[1234,1000](1234,200,0)Hello"}});
        };
        SGLyricsQuery *query = [SGLyricsQuery new];
        query.title = @"Fixture"; query.artist = @"Singer"; query.seconds = 200;
        finished = NO;
        SGNetEaseAsk(query, ^(SGLyricsResult *result) {
            CHECK(NSThread.isMainThread && result.wordTimed);
            CHECK(result.karaokeLines[0].words[0].start == 1234 && result.karaokeLines[0].words[0].end == 1434);
            finished = YES;
        });
        waitFor(&finished);
        watchModels = YES;
        // Each real adapter sees the same captured query even if the source walk learns new names.
        for (NSUInteger provider = 0; provider < 6; provider++) {
            query.title = @"Fixture"; query.artist = @"Singer"; query.seconds = 200;
            query.trackID = provider == 5 ? @"1234567890123456789012" : @"fixture";
            fixtureISRC = provider == 5 ? @"ISRC123" : nil;
            reply = ^NSData *(NSURLRequest *request) {
                NSString *host = request.URL.host, *path = request.URL.path;
                if ([host isEqual:@"lrclib.net"]) {
                    NSDictionary *record = @{@"id": @7, @"trackName": @"Fixture", @"artistName": @"Singer", @"duration": @200, @"syncedLyrics": @"[00:01]Hello\n[00:02]"};
                    return json(provider == 1 ? @[record] : record);
                }
                if ([host hasPrefix:@"lyricsplus."]) return json(@{@"type": @"Word", @"lyrics": @[
                    @{@"text": @"Hello", @"time": @1000, @"duration": @1000, @"syllabus": @[
                        @{@"text": @"Hello", @"time": @1000, @"duration": @1000}]}]});
                if ([host isEqual:@"www.genie.co.kr"]) return [@"<tr class='list' songid='7'><a class='title' title='Fixture'>Fixture</a><a class='artist'>Singer</a></tr>" dataUsingEncoding:NSUTF8StringEncoding];
                if ([host isEqual:@"dn.genie.co.kr"]) return [@"callback({\"1000\":\"Hello\",\"2000\":\"\"})" dataUsingEncoding:NSUTF8StringEncoding];
                if ([host isEqual:@"lyrics-api.binimum.org"]) return json(@{@"results": @[
                    @{@"lyricsUrl": @"https://fixture.invalid/lyrics.ttml", @"timing_type": @"word", @"duration": @200}]});
                CHECK([path hasSuffix:@".ttml"]);
                return [@"<tt timing=\"Word\"><body><div><p begin=\"1s\" end=\"2s\"><span begin=\"1s\" end=\"2s\">Hello</span></p></div></body></tt>" dataUsingEncoding:NSUTF8StringEncoding];
            };
            finished = NO;
            void (^receive)(SGLyricsResult *) = ^(SGLyricsResult *result) {
                CHECK(NSThread.isMainThread && result.karaokeLines.count == 1);
                CHECK(result.karaokeLines.firstObject.start == 1000);
                CHECK([SGKaraokeLineText(result.karaokeLines.firstObject) isEqual:@"Hello"]);
                if (provider == 2 || provider >= 4) CHECK(result.wordTimed);
                finished = YES;
            };
            if (provider == 0) SGLrcLibAsk(query, receive);
            else if (provider == 1) {
                query.seconds = 0;
                SGLrcLibAsk(query, receive);
            } else if (provider == 2) SGLyricsPlusAsk(query, receive);
            else if (provider == 3) SGGenieAsk(query, receive);
            else SGBiniLyricsAsk(query, receive);
            query.title = @"Changed"; query.artist = @"Other"; query.seconds = 900;
            waitFor(&finished);
        }
        puts("Shared transport: worker decoding/models, main delivery, LRCLIB/LyricsPlus/Genie/BiniLyrics and NetEase passed");
    }
    return 0;
}
