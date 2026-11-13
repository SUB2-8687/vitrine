// Connect owns remote volume; MPVolumeView continues to own local volume. The observer reads the
// service again rather than caching an unlabelled callback's value across a device switch.
#import <objc/runtime.h>
#import "Core/SGCore.h"
#import "Player.h"
#import "PlayerConnectVolume.h"

@protocol SGRConnectEntity <NSObject>
- (BOOL)isSelf;
- (BOOL)isVolumeSupported;
- (NSString *)connectStateIdentifier;
@end
@protocol SGRConnectAggregator <NSObject>
- (id<SGRConnectEntity>)activeConnectEntity;
- (BOOL)isPlayingRemotely;
@end
@protocol SGRConnectVolume <NSObject>
- (double)connectVolume;
- (void)add:(id)observer;
- (void)setVolume:(double)value reason:(NSString *)reason;
@end
@protocol SGRConnectVolumeService
- (id)provideVolumeImpl;
@end
@protocol SGRConnectAggregatorService
- (id)provideConnectAggregatorLegacyAPI;
@end
@protocol SGRConnectAggregatorEvents
- (void)aggregator:(id)aggregator didUpdateActiveConnectEntity:(id)entity;
@end
@protocol SGRConnectVolumeCallbacks
- (void)connectVolumeDidChangeToValue:(double)value;
- (void)remoteMediaSessionVolumeDidChangeToValue:(double)value;
- (void)groupedDeviceVolumeDidChangeToValue:(double)value groupDeviceIdentifier:(NSString *)identifier;
@end

NSNotificationName const SGRConnectVolumeChangedNotification = @"SGRConnectVolumeChangedNotification";
static __weak id<SGRConnectVolume> sg_volume;
static __weak id<SGRConnectAggregator> sg_aggregator;
static BOOL sg_capable;

// Runtime encodings may name an object's class; it is still an Objective-C object, not a block.
static BOOL sameType(const char *actual, const char *expected) {
    if (actual[0] == '@' && (actual[1] == '\0' || actual[1] == '"') &&
        expected[0] == '@' && (expected[1] == '\0' || expected[1] == '"')) return YES;
    return strcmp(actual, expected) == 0;
}

static BOOL sameSignature(const char *actual, const char *expected) {
    if (!actual || !expected) return NO;
    NSMethodSignature *a = [NSMethodSignature signatureWithObjCTypes:actual];
    NSMethodSignature *e = [NSMethodSignature signatureWithObjCTypes:expected];
    if (a.numberOfArguments != e.numberOfArguments || !sameType(a.methodReturnType, e.methodReturnType)) return NO;
    for (NSUInteger i = 0; i < e.numberOfArguments; i++) {
        if (!sameType([a getArgumentTypeAtIndex:i], [e getArgumentTypeAtIndex:i])) return NO;
    }
    return YES;
}

static BOOL matchesContract(Class cls, Protocol *contract) {
    unsigned int count = 0;
    struct objc_method_description *methods = protocol_copyMethodDescriptionList(contract, YES, YES, &count);
    BOOL valid = cls != Nil;
    for (unsigned int i = 0; valid && i < count; i++) {
        Method method = class_getInstanceMethod(cls, methods[i].name);
        valid = method && sameSignature(method_getTypeEncoding(method), methods[i].types);
        if (!valid) SGLog(@"Connect volume disabled: %@ %@ signature", NSStringFromClass(cls), NSStringFromSelector(methods[i].name));
    }
    free(methods);
    return valid;
}

static BOOL acceptsObject(id object, Protocol *contract) {
    if (!sg_capable || !object) return NO;
    if (matchesContract(object_getClass(object), contract)) return YES;
    // A changed private API disables this capability for the process, including later valid providers.
    sg_capable = NO;
    sg_volume = nil;
    sg_aggregator = nil;
    [NSNotificationCenter.defaultCenter postNotificationName:SGRConnectVolumeChangedNotification object:nil];
    return NO;
}

static NSString *activeDevice(void) {
    if (!acceptsObject(sg_volume, @protocol(SGRConnectVolume)) ||
        !acceptsObject(sg_aggregator, @protocol(SGRConnectAggregator)) ||
        ![sg_aggregator isPlayingRemotely]) return nil;
    id<SGRConnectEntity> entity = [sg_aggregator activeConnectEntity];
    if (!acceptsObject(entity, @protocol(SGRConnectEntity)) || [entity isSelf] || ![entity isVolumeSupported]) return nil;
    NSString *key = [entity connectStateIdentifier];
    return [key isKindOfClass:NSString.class] && key.length ? key : nil;
}

BOOL SGRConnectReadVolume(double *value) {
    if (!NSThread.isMainThread) return NO;
    if (!activeDevice()) return NO;
    double current = [sg_volume connectVolume];
    if (!isfinite(current) || current < 0 || current > 1) return NO;
    if (value) *value = current;
    return YES;
}

BOOL SGRConnectSetVolume(double value) {
    if (!isfinite(value) || !SGRConnectReadVolume(NULL)) return NO;
    [sg_volume setVolume:MIN(1, MAX(0, value)) reason:@"DevicePickerUIImpl"];
    return YES;
}

static void onMain(dispatch_block_t block) {
    if (NSThread.isMainThread) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

static void volumeChanged(void) {
    [NSNotificationCenter.defaultCenter postNotificationName:SGRConnectVolumeChangedNotification object:nil];
}

@interface SGRConnectVolumeObserver : NSObject <SGRConnectVolumeCallbacks>
@end
@implementation SGRConnectVolumeObserver
+ (void)initialize {
    if (self != SGRConnectVolumeObserver.class) return;
    Protocol *protocol = objc_getProtocol("SPTConnectVolumeObserver");
    if (protocol) class_addProtocol(self, protocol);
}
- (void)connectVolumeDidChangeToValue:(double)value { onMain(^{ volumeChanged(); }); }
- (void)remoteMediaSessionVolumeDidChangeToValue:(double)value { onMain(^{ volumeChanged(); }); }
- (void)groupedDeviceVolumeDidChangeToValue:(double)value groupDeviceIdentifier:(NSString *)identifier {}
@end

static SGRConnectVolumeObserver *observer(void) {
    static SGRConnectVolumeObserver *value;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ value = [SGRConnectVolumeObserver new]; });
    return value;
}

static void provideVolume(id volume) {
    onMain(^{
        if (!sg_capable || volume == sg_volume) return;
        if (volume && !acceptsObject(volume, @protocol(SGRConnectVolume))) return;
        sg_volume = volume;
        [sg_volume add:observer()];
        volumeChanged();
    });
}

static void provideAggregator(id aggregator) {
    onMain(^{
        if (!sg_capable) return;
        if (aggregator && !acceptsObject(aggregator, @protocol(SGRConnectAggregator))) return;
        sg_aggregator = aggregator;
        volumeChanged();
    });
}

%group ConnectVolume
%hook _TtC18Connect_VolumeImpl17VolumeServiceImpl
- (id)provideVolumeImpl {
    id volume = %orig;
    provideVolume(volume);
    return volume;
}
%end
%hook _TtC18Connect_VolumeImpl10VolumeImpl
- (void)add:(id)value {
    %orig;
    provideVolume(self);
}
%end
%hook _TtC22Connect_AggregatorImpl24ConnectAggregatorService
- (id)provideConnectAggregatorLegacyAPI {
    id aggregator = %orig;
    provideAggregator(aggregator);
    return aggregator;
}
%end
%hook _TtC18Connect_VolumeImpl21AggregatorEventSource
- (void)aggregator:(id)aggregator didUpdateActiveConnectEntity:(id)entity {
    %orig;
    provideAggregator(aggregator);
}
%end
%end

%ctor {
    if (!SGRedesignedUI() || !SGRPlayerVolumeOn()) return;
    NSDictionary<NSString *, Protocol *> *contracts = @{
        @"_TtC18Connect_VolumeImpl17VolumeServiceImpl": @protocol(SGRConnectVolumeService),
        @"_TtC18Connect_VolumeImpl10VolumeImpl": @protocol(SGRConnectVolume),
        @"_TtC22Connect_AggregatorImpl24ConnectAggregatorService": @protocol(SGRConnectAggregatorService),
        @"_TtC18Connect_VolumeImpl21AggregatorEventSource": @protocol(SGRConnectAggregatorEvents),
    };
    for (NSString *name in contracts) {
        if (!matchesContract(NSClassFromString(name), contracts[name])) return;
    }
    Protocol *callbacks = objc_getProtocol("SPTConnectVolumeObserver");
    if (!callbacks) return;
    unsigned int count = 0;
    struct objc_method_description *methods = protocol_copyMethodDescriptionList(@protocol(SGRConnectVolumeCallbacks), YES, YES, &count);
    BOOL valid = YES;
    for (unsigned int i = 0; valid && i < count; i++) {
        struct objc_method_description actual = protocol_getMethodDescription(callbacks, methods[i].name, YES, YES);
        if (!actual.name) actual = protocol_getMethodDescription(callbacks, methods[i].name, NO, YES);
        valid = sameSignature(actual.types, methods[i].types);
        if (!valid) SGLog(@"Connect volume disabled: observer %@ signature", NSStringFromSelector(methods[i].name));
    }
    free(methods);
    if (!valid) return;
    sg_capable = YES;
    %init(ConnectVolume);
}
