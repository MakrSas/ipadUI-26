#import <UIKit/UIKit.h>
#import "PUHook.h"
#import "PUPrefs.h"

// App switcher styles used by SBAppSwitcherSettings: 1 = iPhone card deck, 2 = iPad grid.
static const long long PUSwitcherStyleGrid = 2;

static void PUInitIdiom(void) {
	PUHookReturnInteger("UIDevice", "userInterfaceIdiom", NO, UIUserInterfaceIdiomPad);
}

static void PUInitFloatingDock(void) {
	PUHookReturnBool("SBFloatingDockController", "isFloatingDockSupported", YES, YES);
	PUHookReturnBool("SBFloatingDockController", "isFloatingDockSupported", NO, YES);
	PUHookReturnBool("SBHIconManager", "isFloatingDockSupported", NO, YES);

	BOOL recents = PUPrefBool(PUKeyDockRecents);
	PUHookReturnBool("SBFloatingDockDefaults", "recentsEnabled", NO, recents);
	PUHookReturnBool("SBFloatingDockSuggestionsModel", "recentsEnabled", NO, recents);

	BOOL appLibrary = PUPrefBool(PUKeyDockAppLibrary);
	PUHookReturnBool("SBFloatingDockDefaults", "appLibraryEnabled", NO, appLibrary);
	PUHookReturnBool("SBFloatingDockDefaults", "libraryPodEnabled", NO, appLibrary);
}

static void PUInitGridSwitcher(void) {
	PUHookReturnInteger("SBAppSwitcherSettings", "switcherStyle", NO, PUSwitcherStyleGrid);
	PUHookReturnInteger("SBAppSwitcherSettings", "effectiveSwitcherStyle", NO, PUSwitcherStyleGrid);

	__block IMP origSetStyle = NULL;
	SEL setStyle = @selector(setSwitcherStyle:);
	PUHookMethod("SBAppSwitcherSettings", "setSwitcherStyle:", NO, ^(id self, long long style) {
		((void (*)(id, SEL, long long))origSetStyle)(self, setStyle, PUSwitcherStyleGrid);
	}, &origSetStyle);
}

static void PUInitMultitasking(void) {
	PUHookReturnBool("SBApplication", "isMedusaCapable", NO, YES);
	PUHookReturnBool("SBApplication", "supportsMultitaskingShelf", NO, YES);
	PUHookReturnBool("SBApplicationInfo", "isMedusaCapable", NO, YES);
	PUHookReturnBool("SBMainWorkspace", "isMedusaEnabled", NO, YES);
	PUHookReturnBool("SBPlatformController", "isMedusaCapable", NO, YES);
}

static void PUInitStageManager(void) {
	const char *sbf = "/System/Library/PrivateFrameworks/SpringBoardFoundation.framework/SpringBoardFoundation";
	PUHookFunctionReturnBool(sbf, "SBFIsChamoisWindowingUIAvailable", YES);
	PUHookFunctionReturnBool(sbf, "SBFIsChamoisAvailable", YES);
	PUHookReturnBool("SBApplication", "supportsChamois", NO, YES);
	PUHookReturnBool("SBPlatformController", "isChamoisCapable", NO, YES);
}

static void PUInitHomeRotation(void) {
	PUHookReturnBool("SpringBoard", "homeScreenSupportsRotation", NO, YES);
	PUHookReturnInteger("SpringBoard", "homeScreenRotationStyle", NO, 2);
	PUHookReturnInteger("SBHomeScreenViewController", "supportedInterfaceOrientations", NO, UIInterfaceOrientationMaskAll);
}

void PUInitSpringBoard(void) {
	if (PUPrefBool(PUKeySpringBoardIdiom)) PUInitIdiom();
	if (PUPrefBool(PUKeyFloatingDock)) PUInitFloatingDock();
	if (PUPrefBool(PUKeyGridSwitcher)) PUInitGridSwitcher();
	if (PUPrefBool(PUKeyMultitasking)) PUInitMultitasking();
	if (PUPrefBool(PUKeyStageManager)) PUInitStageManager();
	if (PUPrefBool(PUKeyHomeRotation)) PUInitHomeRotation();
}
