#import <Foundation/Foundation.h>

// Every hook is looked up at runtime and skipped if the class or selector does not
// exist on the running iOS version, so a renamed private API never crashes SpringBoard.

// Replaces a method with `block` (signature: ret ^(id self, args...)). The original
// implementation is stored in `orig` when non-NULL. Returns YES if the hook was installed.
BOOL PUHookMethod(const char *className, const char *selName, BOOL classMethod, id block, IMP *orig);

// Forces a BOOL-returning method to return `value`.
BOOL PUHookReturnBool(const char *className, const char *selName, BOOL classMethod, BOOL value);

// Forces an integer-returning method (NSInteger, long long, enum) to return `value`.
BOOL PUHookReturnInteger(const char *className, const char *selName, BOOL classMethod, long long value);

// Forces an exported C function returning BOOL to return `value`.
BOOL PUHookFunctionReturnBool(const char *imagePath, const char *symbol, BOOL value);
