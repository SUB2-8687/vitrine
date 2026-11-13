// Real Connect hooks and routing, with Spotify doubles. Bad-signature processes never call the bad ABI.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Redesigned/Player/PlayerConnectVolume.h"

BOOL SGRedesignedUI(void) { return YES; }
BOOL SGRPlayerVolumeOn(void) { return YES; }
@protocol HarnessVolumeObserver <NSObject>
- (void)connectVolumeDidChangeToValue:(double)value;
- (void)remoteMediaSessionVolumeDidChangeToValue:(double)value;
- (void)groupedDeviceVolumeDidChangeToValue:(double)value groupDeviceIdentifier:(NSString *)identifier;
@end
@interface Device : NSObject
@property BOOL isSelf, isVolumeSupported;
@property NSString *connectStateIdentifier;
@end
@implementation Device
@end
@interface Aggregator : NSObject
@property BOOL isPlayingRemotely;
@property id activeConnectEntity;
@end
@implementation Aggregator
@end
@interface _TtC18Connect_VolumeImpl10VolumeImpl : NSObject
@property double connectVolume;
@property NSMutableArray *writes;
@property id<HarnessVolumeObserver> listener;
- (void)add:(id)listener;
- (void)setVolume:(double)value reason:(NSString *)reason;
@end
@implementation _TtC18Connect_VolumeImpl10VolumeImpl
- (void)add:(id)listener { self.listener = listener; }
- (void)setVolume:(double)value reason:(NSString *)reason {
    [self.writes addObject:@(value)];
    self.connectVolume = value;
    [self.listener connectVolumeDidChangeToValue:value];
}
@end
@interface _TtC18Connect_VolumeImpl17VolumeServiceImpl : NSObject
@property id volume;
@end
@implementation _TtC18Connect_VolumeImpl17VolumeServiceImpl
@end
@interface _TtC18Connect_VolumeImpl17VolumeServiceImpl (Providing)
- (id)provideVolumeImpl;
@end
@interface _TtC22Connect_AggregatorImpl24ConnectAggregatorService : NSObject
@property id aggregator;
- (id)provideConnectAggregatorLegacyAPI;
@end
@implementation _TtC22Connect_AggregatorImpl24ConnectAggregatorService
- (id)provideConnectAggregatorLegacyAPI { return self.aggregator; }
@end
@interface _TtC18Connect_VolumeImpl21AggregatorEventSource : NSObject
- (void)aggregator:(id)aggregator didUpdateActiveConnectEntity:(id)entity;
@end
@implementation _TtC18Connect_VolumeImpl21AggregatorEventSource
- (void)aggregator:(id)aggregator didUpdateActiveConnectEntity:(id)entity {}
@end
static NSUInteger badCalls;
@interface WrongDevice : NSObject
@property BOOL isVolumeSupported;
@property NSString *connectStateIdentifier;
- (double)isSelf;
@end
@implementation WrongDevice
- (double)isSelf { badCalls++; return 0; }
@end

static id provide(id self, SEL cmd) { return [self volume]; }
@interface HarnessSignatures : NSObject
@end
@implementation HarnessSignatures
+ (void)load {
    NSString *bad = NSProcessInfo.processInfo.environment[@"BAD_SIGNATURE"];
    class_addMethod(_TtC18Connect_VolumeImpl17VolumeServiceImpl.class, @selector(provideVolumeImpl),
        (IMP)provide, [bad isEqual:@"hook-return"] ? "d@:" : "@@:");
    Protocol *callbacks = objc_allocateProtocol("SPTConnectVolumeObserver");
    protocol_addMethodDescription(callbacks, @selector(connectVolumeDidChangeToValue:),
        [bad isEqual:@"callback-argument"] ? "v@:f" : "v@:d", YES, YES);
    protocol_addMethodDescription(callbacks, @selector(remoteMediaSessionVolumeDidChangeToValue:),
        [bad isEqual:@"callback-return"] ? "d@:d" : "v@:d", YES, YES);
    protocol_addMethodDescription(callbacks, @selector(groupedDeviceVolumeDidChangeToValue:groupDeviceIdentifier:),
        "v@:d@", NO, YES);
    objc_registerProtocol(callbacks);
}
@end
#define CHECK(condition, message) do { if (!(condition)) { NSLog(@"FAIL %@", message); return 1; } } while (0)

int main(void) {
    @autoreleasepool {
        CHECK(objc_getProtocol("SPTConnectVolumeObserver") != nil, @"Spotify observer protocol not registered");
        if (getenv("BAD_SIGNATURE")) {
            CHECK(!SGRConnectReadVolume(NULL) && !SGRConnectSetVolume(0.75), @"wrong-signature capability accepted");
            _TtC18Connect_VolumeImpl10VolumeImpl *original = [_TtC18Connect_VolumeImpl10VolumeImpl new];
            NSObject *listener = [NSObject new];
            [original add:listener];
            CHECK(original.listener == (id)listener, @"wrong-signature capability changed Spotify's observer");
            NSLog(@"PASS wrong signature %@ leaves capability off", NSProcessInfo.processInfo.environment[@"BAD_SIGNATURE"]);
            return 0;
        }
        _TtC18Connect_VolumeImpl10VolumeImpl *volume = [_TtC18Connect_VolumeImpl10VolumeImpl new];
        volume.writes = [NSMutableArray array];
        volume.connectVolume = 0.25;
        _TtC18Connect_VolumeImpl17VolumeServiceImpl *service = [_TtC18Connect_VolumeImpl17VolumeServiceImpl new];
        service.volume = volume;
        [service provideVolumeImpl];
        CHECK(volume.listener != nil, @"Connect observer not installed");
        Aggregator *aggregator = [Aggregator new];
        Device *device = [Device new];
        device.connectStateIdentifier = @"speaker-a";
        device.isVolumeSupported = YES;
        aggregator.activeConnectEntity = device;
        _TtC22Connect_AggregatorImpl24ConnectAggregatorService *provider = [_TtC22Connect_AggregatorImpl24ConnectAggregatorService new];
        provider.aggregator = aggregator;
        [provider provideConnectAggregatorLegacyAPI];
        CHECK(!SGRConnectSetVolume(0.7), @"local path intercepted");
        CHECK(volume.writes.count == 0, @"local volume sent to Connect");
        aggregator.isPlayingRemotely = YES;
        _TtC18Connect_VolumeImpl21AggregatorEventSource *events = [_TtC18Connect_VolumeImpl21AggregatorEventSource new];
        [events aggregator:aggregator didUpdateActiveConnectEntity:device];
        double value;
        CHECK(SGRConnectReadVolume(&value) && value == 0.25, @"Spotify remote state not selected");
        CHECK(SGRConnectSetVolume(0.75) && volume.connectVolume == 0.75, @"slider not sent to Connect API");
        // An unlabelled old-device callback must not replace the current service's value.
        device.connectStateIdentifier = @"speaker-b";
        volume.connectVolume = 0.25;
        [events aggregator:aggregator didUpdateActiveConnectEntity:device];
        [volume.listener connectVolumeDidChangeToValue:0.9];
        CHECK(SGRConnectReadVolume(&value) && value == 0.25, @"old-device callback replaced current volume");
        device.isVolumeSupported = NO;
        CHECK(!SGRConnectSetVolume(0.5), @"unsupported device accepted");
        device.isVolumeSupported = YES;
        WrongDevice *wrong = [WrongDevice new];
        wrong.isVolumeSupported = YES;
        wrong.connectStateIdentifier = @"wrong-signature";
        aggregator.activeConnectEntity = wrong;
        CHECK(!SGRConnectSetVolume(0.5) && badCalls == 0, @"wrong entity ABI invoked");
        aggregator.activeConnectEntity = device;
        [service provideVolumeImpl];
        [provider provideConnectAggregatorLegacyAPI];
        CHECK(!SGRConnectReadVolume(NULL) && !SGRConnectSetVolume(0.5), @"invalid ABI did not disable entire capability");
        NSLog(@"PASS Connect slider routing, current-device reads, local/unsupported fallback and permanent ABI rejection");
    }
    return 0;
}
