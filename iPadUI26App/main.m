#import <UIKit/UIKit.h>
#import <rootless.h>

// Standalone launcher for the settings: loads the preference bundle and shows its root
// page, so the settings are reachable even when PreferenceLoader is not working.
@interface PUAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation PUAppDelegate

- (UIViewController *)settingsController {
	NSBundle *bundle = [NSBundle bundleWithPath:ROOT_PATH_NS(@"/Library/PreferenceBundles/iPadUI26Prefs.bundle")];
	Class controllerClass = [bundle load] ? bundle.principalClass : Nil;
	if (!controllerClass) {
		UIViewController *error = [UIViewController new];
		UILabel *label = [UILabel new];
		label.text = @"iPadUI26Prefs.bundle not found";
		label.textAlignment = NSTextAlignmentCenter;
		label.frame = UIScreen.mainScreen.bounds;
		error.view.backgroundColor = UIColor.systemBackgroundColor;
		[error.view addSubview:label];
		return error;
	}
	UIViewController *controller = [controllerClass new];
	return controller;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
	UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:[self settingsController]];
	navigation.navigationBar.prefersLargeTitles = YES;
	self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
	self.window.rootViewController = navigation;
	[self.window makeKeyAndVisible];
	return YES;
}

@end

int main(int argc, char *argv[]) {
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass(PUAppDelegate.class));
	}
}
