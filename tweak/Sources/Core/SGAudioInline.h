#import <AudioToolbox/AudioToolbox.h>
#import "SGRebind.h"

// These callbacks have different signatures. Keep the typed original and the nonblocking
// publication-window error in one guard, before either a processor or a trampoline can run.
#define SG_AUDIO_INLINE_ORIGINAL(name, hook, type) \
    type name = SGInlineHookOriginal(hook); \
    if (!name) return kAudioUnitErr_CannotDoInCurrentContext
