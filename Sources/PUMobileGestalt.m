#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <substrate.h>
#import <ptrauth.h>
#import "PUHook.h"
#import "PUPrefs.h"

// MobileGestalt answers that make SpringBoard believe it runs on an iPad. Callers use
// either the plain key name or its obfuscated hash, so both spellings are listed.
static NSDictionary<NSString *, id> *gSpoofedAnswers;

static CFPropertyListRef (*orig_MGCopyAnswer_internal)(CFStringRef key, uint32_t *outType);
static CFPropertyListRef hook_MGCopyAnswer_internal(CFStringRef key, uint32_t *outType) {
	id answer = key ? gSpoofedAnswers[(__bridge NSString *)key] : nil;
	if (answer) return CFRetain((__bridge CFTypeRef)answer);
	return orig_MGCopyAnswer_internal(key, outType);
}

static CFPropertyListRef (*orig_MGCopyAnswer)(CFStringRef key);
static CFPropertyListRef hook_MGCopyAnswer(CFStringRef key) {
	id answer = key ? gSpoofedAnswers[(__bridge NSString *)key] : nil;
	if (answer) return CFRetain((__bridge CFTypeRef)answer);
	return orig_MGCopyAnswer(key);
}

// MGCopyAnswer is a two-instruction stub (`mov x1, #0; b _MGCopyAnswer_internal`),
// too short to hook reliably, so follow its branch to the real implementation.
static void *PUFindMGCopyAnswerInternal(void *stub) {
	uint32_t *insn = (uint32_t *)ptrauth_strip(stub, ptrauth_key_function_pointer);
	for (int i = 0; i < 4; i++) {
		if ((insn[i] & 0xFC000000) == 0x14000000) {
			int32_t imm26 = (int32_t)(insn[i] << 6) >> 6;
			void *target = (uint8_t *)&insn[i] + (int64_t)imm26 * 4;
			return ptrauth_sign_unauthenticated(target, ptrauth_key_function_pointer, 0);
		}
	}
	return NULL;
}

void PUInitMobileGestalt(void) {
	NSMutableDictionary *answers = [NSMutableDictionary dictionary];
	if (PUPrefBool(PUKeyDeviceClass)) {
		answers[@"DeviceClass"] = @"iPad";
		answers[@"+3Uf0Pm5F8Xy7Onyvko0vA"] = @"iPad";
		answers[@"DeviceClassNumber"] = @3;
		answers[@"mtrAoWJ3gsq+I90ZnQ0vQw"] = @3;
		answers[@"ipad"] = @YES;
		answers[@"uKc7FPnEO++lVhHWHFlGbQ"] = @YES;
	}
	if (PUPrefBool(PUKeyMultitasking)) {
		for (NSString *key in @[@"mG0AnH/Vy1veoqoLRAIgTA", @"UCG5MkVahJxG1YULbbd5Bg", @"ZYqko/XM5zD3XBfN5RmaXA", @"nVh/gwNpy7Jv1NOk00CMrw"]) {
			answers[key] = @YES;
		}
	}
	if (PUPrefBool(PUKeyStageManager)) {
		answers[@"DeviceSupportsEnhancedMultitasking"] = @YES;
		answers[@"qeaj75wk3HF4DwQ8qbIi7g"] = @YES;
	}
	if (!answers.count) return;
	gSpoofedAnswers = [answers copy];

	void *handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
	void *copyAnswer = handle ? dlsym(handle, "MGCopyAnswer") : NULL;
	if (!copyAnswer) {
		PULog(@"MGCopyAnswer not found, MobileGestalt spoofing disabled");
		return;
	}
	void *internal = PUFindMGCopyAnswerInternal(copyAnswer);
	if (internal) {
		MSHookFunction(internal, (void *)hook_MGCopyAnswer_internal, (void **)&orig_MGCopyAnswer_internal);
		PULog(@"hooked MGCopyAnswer_internal (%lu answers)", (unsigned long)answers.count);
	} else {
		MSHookFunction(copyAnswer, (void *)hook_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
		PULog(@"hooked MGCopyAnswer (%lu answers)", (unsigned long)answers.count);
	}
}
