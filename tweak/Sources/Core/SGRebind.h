// Hooks a C function Spotify's binary imports, by pointing the binary's own import slot for it
// (its __got, or __la_symbol_ptr in an older build) at a replacement. Only calls Spotify's own code
// makes go through the new function; the system's frameworks keep calling the original. This is the
// fishhook technique, kept to Spotify's binary, for the few places no Objective-C method stands
// between Spotify and a system call (the audio output unit Music Haptics listens to). The binary is
// the image named Spotify (or named as the bundle's executable): the main executable, or under
// LiveContainer a dylib it dlopens. There it is expected to be loaded and bound before any %ctor runs
// (not yet confirmed by a LiveContainer log); if it is not, the log says so and nothing is rebound.
//
// Threading: call from a %ctor, before Spotify has run; the slots are written without a lock.
#import <Foundation/Foundation.h>
#import <stdatomic.h>

// Returns YES when at least one slot named `symbol` (without the leading underscore) was repointed.
// `original` receives what the first slot held, which is what the replacement calls on.
BOOL SGRebindImport(const char *symbol, void *replacement, void **original);

// Installation only, before Spotify runs. An app-bundled hooker is not a jailbreak.
BOOL SGJailbroken(void);
typedef struct {
    void *function;
    void *replacement;
    void **original;
    atomic_bool published;
} SGInlineHook;
// Each record starts zeroed and is installed once. The hooker writes a private slot; only after
// it returns is the trampoline release-published. Never seed original with the patched symbol.
BOOL SGHookFunctionInline(SGInlineHook *hook);
// Acquire-load before reading original, also when the lifecycle is not yet active. NULL means
// the replacement must return an explicit error without performing the operation or waiting.
void *SGInlineHookOriginal(const SGInlineHook *hook);
// Stops at the first failure. Hooks cannot be undone: replacements use their published original
// (or return an error while unpublished) until this returns YES. Put stop/dispose before start.
BOOL SGHookFunctionsInline(SGInlineHook *hooks, size_t count);
// Pure address comparison; the Spotify __TEXT range is prepared before installing any hook.
BOOL SGCalledFromMainExecutable(void *returnAddress);
