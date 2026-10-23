#import <UIKit/UIKit.h>
#import "PUHook.h"
#import "PUPrefs.h"

// Runs in SpringBoard and in apps: the status bar is drawn by every process itself.
void PUInitStatusBar(void) {
	__block IMP orig = NULL;
	SEL sel = NSSelectorFromString(@"visualProviderClassForScreen:visualProviderInfo:");
	PUHookMethod("_UIStatusBar", "visualProviderClassForScreen:visualProviderInfo:", YES, ^Class(id self, id screen, id info) {
		Class pad = NSClassFromString(@"_UIStatusBarVisualProvider_Pad_ForcedCellular");
		return pad ?: ((Class (*)(id, SEL, id, id))orig)(self, sel, screen, info);
	}, &orig);
}

// iPad layouts inside apps: sidebars, split views, popovers, iPad keyboard.
void PUInitAppIdiom(void) {
	PUHookReturnInteger("UIDevice", "userInterfaceIdiom", NO, UIUserInterfaceIdiomPad);
	PUHookReturnInteger("UIScreen", "_userInterfaceIdiom", NO, UIUserInterfaceIdiomPad);
}

BOOL PUIsAppExcluded(NSString *bundleID) {
	for (NSString *item in [PUPrefString(PUKeyAppsExcluded) componentsSeparatedByString:@","]) {
		NSString *trimmed = [item stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
		if (trimmed.length && [trimmed isEqualToString:bundleID]) return YES;
	}
	return NO;
}
