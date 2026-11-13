#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static inline BOOL SGWGMethodMatches(Method method, const char *result, NSArray<NSString *> *arguments) {
    if (!method || method_getNumberOfArguments(method) != arguments.count + 2) return NO;
    char *type = method_copyReturnType(method);
    BOOL valid = type && !strcmp(type, result);
    free(type);
    for (unsigned i = 0; valid && i < arguments.count + 2; i++) {
        const char *expected = i == 0 ? "@" : i == 1 ? ":" : arguments[i - 2].UTF8String;
        type = method_copyArgumentType(method, i);
        valid = type && !strcmp(type, expected);
        free(type);
    }
    return valid;
}
