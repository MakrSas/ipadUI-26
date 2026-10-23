#import "PULogViewController.h"
#import "../Sources/PULog.h"

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

- (void)reload {
	NSString *log = [NSString stringWithContentsOfFile:PULogPath() encoding:NSUTF8StringEncoding error:nil];
	_textView.text = log.length ? log : PULocalized(@"The log is empty. Respring and open this page again.");
	if (log.length) [_textView scrollRangeToVisible:NSMakeRange(log.length - 1, 1)];
}

- (void)clear {
	[NSData.data writeToFile:PULogPath() atomically:YES];
	[self reload];
}

- (void)share:(UIBarButtonItem *)sender {
	NSURL *url = [NSURL fileURLWithPath:PULogPath()];
	if (![NSFileManager.defaultManager fileExistsAtPath:url.path]) return;
	UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
	activity.popoverPresentationController.barButtonItem = sender;
	[self presentViewController:activity animated:YES completion:nil];
}

@end
