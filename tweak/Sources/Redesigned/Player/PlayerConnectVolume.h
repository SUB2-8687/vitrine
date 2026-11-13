#import <Foundation/Foundation.h>

// Main thread. NO leaves the caller on Spotify's/system volume path.
BOOL SGRConnectReadVolume(double *value);
BOOL SGRConnectSetVolume(double value);
extern NSNotificationName const SGRConnectVolumeChangedNotification;
