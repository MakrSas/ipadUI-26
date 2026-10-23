#import "PUListController.h"
#import <Preferences/PSSpecifier.h>
#import <rootless.h>
#import <spawn.h>
#import "../Sources/PUPrefs.h"

// Settings-style row icon: an SF Symbol on a rounded, coloured square, drawn on device.
static UIImage *PUSettingsIcon(NSString *symbol, UIColor *color) {
	CGSize size = CGSizeMake(29, 29);
	UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
	return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
		CGRect rect = {CGPointZero, size};
		[color setFill];
		[[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:6.5] fill];
		UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
		UIImage *image = [[UIImage systemImageNamed:symbol withConfiguration:config] imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
		CGSize imageSize = image.size;
		[image drawInRect:CGRectMake((size.width - imageSize.width) / 2, (size.height - imageSize.height) / 2, imageSize.width, imageSize.height)];
	}];
}

static void PUSpawn(NSArray<NSString *> *arguments) {
	char *argv[arguments.count + 1];
	for (NSUInteger i = 0; i < arguments.count; i++) argv[i] = (char *)arguments[i].fileSystemRepresentation;
	argv[arguments.count] = NULL;
	pid_t pid;
	posix_spawn(&pid, argv[0], NULL, NULL, argv, NULL);
}

static UIColor *PUColorNamed(NSString *name) {
	NSDictionary *colors = @{
		@"blue": UIColor.systemBlueColor, @"indigo": UIColor.systemIndigoColor, @"purple": UIColor.systemPurpleColor,
		@"orange": UIColor.systemOrangeColor, @"green": UIColor.systemGreenColor, @"teal": UIColor.systemTealColor,
		@"pink": UIColor.systemPinkColor, @"red": UIColor.systemRedColor, @"gray": UIColor.systemGrayColor,
	};
	return colors[name] ?: UIColor.systemBlueColor;
}

@implementation PUListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		NSString *plist = [self.specifier propertyForKey:@"pu_plist"] ?: @"Root";
		NSMutableArray *specifiers = [self loadSpecifiersFromPlistName:plist target:self];
		for (PSSpecifier *specifier in specifiers) {
			NSString *symbol = [specifier propertyForKey:@"pu_symbol"];
			if (symbol) [specifier setProperty:PUSettingsIcon(symbol, PUColorNamed([specifier propertyForKey:@"pu_color"])) forKey:@"iconImage"];
		}
		_specifiers = specifiers;
	}
	return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	return key ? PUPrefValue(key) : [super readPreferenceValue:specifier];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	[super setPreferenceValue:value specifier:specifier];
	NSString *key = [specifier propertyForKey:@"key"];
	if (!key) return;

	// Mirror into the jailbreak root so sandboxed apps can read the values too.
	NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:PUPrefsMirrorPath()] ?: [NSMutableDictionary dictionary];
	prefs[key] = value;
	[prefs writeToFile:PUPrefsMirrorPath() atomically:YES];
	PUPrefsReload();
	[NSNotificationCenter.defaultCenter postNotificationName:PUPrefsDidChangeNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	// Another page may have changed values: refresh switches and previews on this one.
	PUPrefsReload();
	[self reloadSpecifiers];
}

- (void)respring:(PSSpecifier *)specifier {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self localized:@"Respring"] message:[self localized:@"Changes are applied after SpringBoard restarts."] preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:[self localized:@"Cancel"] style:UIAlertActionStyleCancel handler:nil]];
	[alert addAction:[UIAlertAction actionWithTitle:[self localized:@"Respring"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
		[self performRespring];
	}]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)performRespring {
	// sbreload restarts SpringBoard cleanly; killall is the fallback when it is missing.
	NSString *sbreload = ROOT_PATH_NS(@"/usr/bin/sbreload");
	if ([NSFileManager.defaultManager isExecutableFileAtPath:sbreload]) {
		PUSpawn(@[sbreload]);
	} else {
		PUSpawn(@[ROOT_PATH_NS(@"/usr/bin/killall"), @"-9", @"SpringBoard"]);
	}
}

- (void)resetSettings:(PSSpecifier *)specifier {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self localized:@"Reset All Settings"] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
	alert.popoverPresentationController.sourceView = self.view;
	[alert addAction:[UIAlertAction actionWithTitle:[self localized:@"Reset All Settings"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
		[NSFileManager.defaultManager removeItemAtPath:PUPrefsMirrorPath() error:nil];
		for (NSString *key in PUDefaults()) {
			CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, (__bridge CFStringRef)PU_PREFS_DOMAIN);
		}
		CFPreferencesAppSynchronize((__bridge CFStringRef)PU_PREFS_DOMAIN);
		PUPrefsReload();
		[self reloadSpecifiers];
		[NSNotificationCenter.defaultCenter postNotificationName:PUPrefsDidChangeNotification object:nil];
	}]];
	[alert addAction:[UIAlertAction actionWithTitle:[self localized:@"Cancel"] style:UIAlertActionStyleCancel handler:nil]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)localized:(NSString *)key {
	return [[NSBundle bundleForClass:self.class] localizedStringForKey:key value:key table:@"Root"];
}

@end
