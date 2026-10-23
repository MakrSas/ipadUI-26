#import <Foundation/Foundation.h>
#import "PUHook.h"
#import "PULog.h"
#import "PUPrefs.h"

void PUInitMobileGestalt(void);
void PUInitSpringBoard(void);
void PUInitStatusBar(void);
void PUInitAppIdiom(void);
BOOL PUIsAppExcluded(NSString *bundleID);

__attribute__((constructor)) static void PUInit(void) {
	@autoreleasepool {
		NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
		NSString *executable = NSProcessInfo.processInfo.arguments.firstObject;

		// Logged before anything else so the log shows whether injection works at all.
		BOOL enabled = PUPrefBool(PUKeyEnabled);
		PULog(@"loaded into %@ (enabled: %@)", bundleID ?: executable, enabled ? @"yes" : @"no");
		if (!enabled) return;

		if ([bundleID isEqualToString:@"com.apple.springboard"]) {
			PUInitMobileGestalt();
			PUInitSpringBoard();
			if (PUPrefBool(PUKeyPadStatusBar)) PUInitStatusBar();
			return;
		}

		// Only real apps: daemons and extensions also link UIKit but must stay untouched.
		BOOL isApp = [executable containsString:@".app/"] && ![executable containsString:@".appex/"];
		if (!isApp || !bundleID || PUIsAppExcluded(bundleID)) return;
		if (PUPrefBool(PUKeyPadStatusBar)) PUInitStatusBar();
		if (PUPrefBool(PUKeyAppsIdiom)) PUInitAppIdiom();
	}
}
