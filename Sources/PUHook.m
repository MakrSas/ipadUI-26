#import "PUHook.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <substrate.h>

void PULog(NSString *format, ...) {
	va_list args;
	va_start(args, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	NSLog(@"[iPadUI26] %@", message);
}

static Method PUFindMethod(const char *className, const char *selName, BOOL classMethod, Class *outClass) {
	Class cls = objc_getClass(className);
	if (!cls) {
		PULog(@"skip %c[%s %s]: class not found", classMethod ? '+' : '-', className, selName);
		return NULL;
	}
	if (classMethod) cls = object_getClass(cls);
	Method method = class_getInstanceMethod(cls, sel_registerName(selName));
	if (!method) {
		PULog(@"skip %c[%s %s]: selector not found", classMethod ? '+' : '-', className, selName);
		return NULL;
	}
	if (outClass) *outClass = cls;
	return method;
}

static BOOL PUReturnTypeIs(Method method, const char *allowed, const char *className, const char *selName) {
	char type[16] = {0};
	method_getReturnType(method, type, sizeof(type));
	if (type[0] && strchr(allowed, type[0])) return YES;
	PULog(@"skip [%s %s]: unexpected return type %s", className, selName, type);
	return NO;
}

BOOL PUHookMethod(const char *className, const char *selName, BOOL classMethod, id block, IMP *orig) {
	Class cls = Nil;
	if (!PUFindMethod(className, selName, classMethod, &cls)) return NO;
	MSHookMessageEx(cls, sel_registerName(selName), imp_implementationWithBlock(block), orig);
	PULog(@"hooked %c[%s %s]", classMethod ? '+' : '-', className, selName);
	return YES;
}

BOOL PUHookReturnBool(const char *className, const char *selName, BOOL classMethod, BOOL value) {
	Method method = PUFindMethod(className, selName, classMethod, NULL);
	if (!method || !PUReturnTypeIs(method, "Bc", className, selName)) return NO;
	return PUHookMethod(className, selName, classMethod, ^BOOL(id self) {
		return value;
	}, NULL);
}

BOOL PUHookReturnInteger(const char *className, const char *selName, BOOL classMethod, long long value) {
	Method method = PUFindMethod(className, selName, classMethod, NULL);
	if (!method || !PUReturnTypeIs(method, "qQlLiI", className, selName)) return NO;
	return PUHookMethod(className, selName, classMethod, ^long long(id self) {
		return value;
	}, NULL);
}

static BOOL PUReturnYes(void) { return YES; }
static BOOL PUReturnNo(void) { return NO; }

BOOL PUHookFunctionReturnBool(const char *imagePath, const char *symbol, BOOL value) {
	void *handle = dlopen(imagePath, RTLD_LAZY | RTLD_NOLOAD) ?: dlopen(imagePath, RTLD_LAZY);
	void *function = handle ? dlsym(handle, symbol) : NULL;
	if (!function) {
		PULog(@"skip %s(): symbol not found", symbol);
		return NO;
	}
	MSHookFunction(function, (void *)(value ? PUReturnYes : PUReturnNo), NULL);
	PULog(@"hooked %s()", symbol);
	return YES;
}
