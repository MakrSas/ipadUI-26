#import <UIKit/UIKit.h>

// A live preview shown inside a settings cell. It re-lays itself out with a spring
// animation whenever a preference changes, and some previews loop a short demo.
@interface PUPreviewView : UIView
+ (instancetype)previewForKind:(NSString *)kind;
@end
