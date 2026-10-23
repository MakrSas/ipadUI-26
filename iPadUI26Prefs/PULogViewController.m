#import "PULogViewController.h"
#import "../Sources/PULog.h"
#import "../Sources/PUPrefs.h"
#import <rootless.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>

#define PULocalized(key) [[NSBundle bundleForClass:PULogViewController.class] localizedStringForKey:key value:key table:@"Root"]

@implementation PULogViewController {
	UITextView *_textView;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = PULocalized(@"Log");
	self.view.backgroundColor = UIColor.systemBackgroundColor;

	_textView = [UITextView new];
	_textView.editable = NO;
	_textView.alwaysBounceVertical = YES;
	_textView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
	_textView.textContainerInset = UIEdgeInsetsMake(12, 8, 12, 8);
	_textView.frame = self.view.bounds;
	_textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_textView];

	UIBarButtonItem *share = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(share:)];
	UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload)];
	UIBarButtonItem *clear = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(clear)];
	self.navigationItem.rightBarButtonItems = @[share, refresh, clear];
	[self reload];
}

static NSString *PULoadedImageContaining(NSString *needle) {
	for (uint32_t i = 0; i < _dyld_image_count(); i++) {
		NSString *name = @(_dyld_get_image_name(i) ?: "");
		if ([name.lowercaseString containsString:needle.lowercaseString]) return name;
	}
	return nil;
}

// Checks every step tweak loading depends on, from the file on disk to injection into
// this very process, so an empty log can be explained without a Mac.
- (NSString *)diagnostics {
	NSMutableArray *lines = [NSMutableArray array];
	NSFileManager *manager = NSFileManager.defaultManager;
	[lines addObject:[NSString stringWithFormat:@"iOS %@, %@", UIDevice.currentDevice.systemVersion, NSProcessInfo.processInfo.processName]];

	NSString *dylib = ROOT_PATH_NS(@"/Library/MobileSubstrate/DynamicLibraries/iPadUI26.dylib");
	NSString *filter = [dylib.stringByDeletingPathExtension stringByAppendingPathExtension:@"plist"];
	[lines addObject:[NSString stringWithFormat:@"dylib on disk: %@", [manager fileExistsAtPath:dylib] ? @"yes" : @"NO"]];
	[lines addObject:[NSString stringWithFormat:@"filter on disk: %@", [manager fileExistsAtPath:filter] ? @"yes" : @"NO"]];
	NSString *resolved = [manager destinationOfSymbolicLinkAtPath:ROOT_PATH_NS(@"/Library/MobileSubstrate/DynamicLibraries") error:nil];
	if (resolved) [lines addObject:[NSString stringWithFormat:@"DynamicLibraries -> %@", resolved]];

	NSString *loader = PULoadedImageContaining(@"TweakLoader") ?: PULoadedImageContaining(@"ellekit") ?: PULoadedImageContaining(@"substrate");
	[lines addObject:[NSString stringWithFormat:@"tweak loader in this app: %@", loader ? loader.lastPathComponent : @"NO"]];

	NSString *tweak = PULoadedImageContaining(@"iPadUI26.dylib");
	[lines addObject:[NSString stringWithFormat:@"iPadUI26.dylib in this app: %@", tweak ? @"yes" : @"NO"]];
	if (!tweak && [manager fileExistsAtPath:dylib]) {
		void *handle = dlopen(dylib.fileSystemRepresentation, RTLD_NOW);
		const char *error = handle ? NULL : dlerror();
		[lines addObject:[NSString stringWithFormat:@"manual dlopen: %@", handle ? @"ok" : @(error ?: "failed")]];
	}

	[lines addObject:[NSString stringWithFormat:@"Enabled: %@", PUPrefBool(PUKeyEnabled) ? @"yes" : @"NO"]];
	BOOL writable = [manager isWritableFileAtPath:PULogPath()] || [manager isWritableFileAtPath:PULogPath().stringByDeletingLastPathComponent];
	[lines addObject:[NSString stringWithFormat:@"log writable: %@", writable ? @"yes" : @"NO"]];
	return [lines componentsJoinedByString:@"\n"];
}

- (void)reload {
	NSString *log = [NSString stringWithContentsOfFile:PULogPath() encoding:NSUTF8StringEncoding error:nil];
	NSString *body = log.length ? log : PULocalized(@"The log is empty. Respring and open this page again.");
	_textView.text = [NSString stringWithFormat:@"%@\n\n%@\n\n%@", [self diagnostics], PULogPath(), body];
	[_textView scrollRangeToVisible:NSMakeRange(_textView.text.length - 1, 1)];
}

- (void)clear {
	[NSData.data writeToFile:PULogPath() atomically:YES];
	[self reload];
}

- (void)share:(UIBarButtonItem *)sender {
	// Share the diagnostics together with the log, as plain text.
	UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[_textView.text ?: @""] applicationActivities:nil];
	activity.popoverPresentationController.barButtonItem = sender;
	[self presentViewController:activity animated:YES completion:nil];
}

@end
