#import <Foundation/Foundation.h>

#define PU_PREFS_DOMAIN @"com.makrsas.ipadui26"

// Keys stored by the preference bundle.
#define PUKeyEnabled          @"Enabled"
#define PUKeySpringBoardIdiom @"SpringBoardIdiom"
#define PUKeyDeviceClass      @"DeviceClass"
#define PUKeyFloatingDock     @"FloatingDock"
#define PUKeyDockRecents      @"DockRecents"
#define PUKeyDockAppLibrary   @"DockAppLibrary"
#define PUKeyGridSwitcher     @"GridSwitcher"
#define PUKeyMultitasking     @"Multitasking"
#define PUKeyStageManager     @"StageManager"
#define PUKeyHomeRotation     @"HomeRotation"
#define PUKeyPadStatusBar     @"PadStatusBar"
#define PUKeyAppsIdiom        @"AppsIdiom"
#define PUKeyAppsExcluded     @"AppsExcluded"

#define PUPrefsDidChangeNotification @"PUPrefsDidChangeNotification"

NSString *PUPrefsMirrorPath(void);
NSDictionary *PUDefaults(void);
void PUPrefsReload(void);
id PUPrefValue(NSString *key);
BOOL PUPrefBool(NSString *key);
NSString *PUPrefString(NSString *key);
