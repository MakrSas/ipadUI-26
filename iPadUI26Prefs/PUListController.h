#import <Preferences/PSListController.h>

// One controller drives every page; the plist is chosen by the `pu_plist` property of
// the link that opened it (Root when opened from the Settings app).
@interface PUListController : PSListController
@end
