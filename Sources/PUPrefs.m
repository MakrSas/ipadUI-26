#import "PUPrefs.h"
#import <rootless.h>

NSString *PUPrefsMirrorPath(void) {
	return ROOT_PATH_NS(@"/var/mobile/Library/Preferences/" PU_PREFS_DOMAIN @".plist");
}

static NSDictionary *PULoadPrefs(void) {
	// The preference bundle mirrors its values into the jailbreak root, which every
	// process (including sandboxed apps) is allowed to read. cfprefsd is the fallback.
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PUPrefsMirrorPath()];
	if (prefs.count) return prefs;

	CFArrayRef keys = CFPreferencesCopyKeyList((__bridge CFStringRef)PU_PREFS_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	if (!keys) return @{};
	CFDictionaryRef values = CFPreferencesCopyMultiple(keys, (__bridge CFStringRef)PU_PREFS_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	CFRelease(keys);
	return values ? (__bridge_transfer NSDictionary *)values : @{};
}

static NSDictionary *gPrefs;

void PUPrefsReload(void) {
	gPrefs = PULoadPrefs();
}

static NSDictionary *PUPrefs(void) {
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		if (!gPrefs) PUPrefsReload();
	});
	return gPrefs;
}

NSDictionary *PUDefaults(void) {
	return @{
		PUKeyEnabled: @YES,
		PUKeySpringBoardIdiom: @YES,
		PUKeyDeviceClass: @YES,
		PUKeyFloatingDock: @YES,
		PUKeyDockRecents: @YES,
		PUKeyDockAppLibrary: @YES,
		PUKeyGridSwitcher: @YES,
		PUKeyMultitasking: @YES,
		PUKeyStageManager: @NO,
		PUKeyHomeRotation: @YES,
		PUKeyPadStatusBar: @YES,
		PUKeyAppsIdiom: @NO,
		PUKeyAppsExcluded: @"com.apple.AppStore, com.apple.camera, com.apple.mobilephone",
	};
}

id PUPrefValue(NSString *key) {
	return PUPrefs()[key] ?: PUDefaults()[key];
}

BOOL PUPrefBool(NSString *key) {
	id value = PUPrefValue(key);
	return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
}

NSString *PUPrefString(NSString *key) {
	id value = PUPrefValue(key);
	return [value isKindOfClass:NSString.class] ? value : @"";
}
