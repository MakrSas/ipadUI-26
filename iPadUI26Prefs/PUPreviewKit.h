#import <UIKit/UIKit.h>

// Building blocks for the live previews. Everything here is composed from real UIKit
// views (system materials, SF Symbols, the device's own app icons), so the previews are
// rendered by iOS itself and follow the current appearance, Dynamic Type and tint.

UIImage *PUAppIcon(NSString *bundleID);
UIImage *PUSymbol(NSString *name, CGFloat pointSize, UIFontWeight weight);
UIVisualEffect *PUGlassEffect(void);

// Bundle identifiers of stock apps, used to fill home screens, docks and switchers.
NSArray<NSString *> *PUStockApps(void);

@interface PUWallpaperView : UIView
@end

@interface PUIconView : UIImageView
- (instancetype)initWithBundleID:(NSString *)bundleID;
@end

@interface PUGlassView : UIVisualEffectView
- (instancetype)initWithCornerRadius:(CGFloat)radius;
@property (nonatomic) CGFloat cornerRadius;
@end

// The iPad App Library dock tile: four tiny real icons in a glass square.
@interface PUAppLibraryTile : PUGlassView
@end

@interface PUStatusBarView : UIView
@property (nonatomic) BOOL padStyle;
@end

@interface PUDockView : UIView
@property (nonatomic) BOOL floating;
@property (nonatomic) BOOL recents;
@property (nonatomic) BOOL appLibrary;
// Width the dock wants for a given height; the classic dock always fills its container.
- (CGFloat)floatingWidthForHeight:(CGFloat)height;
@end

// A miniature app window: title bar, icon and placeholder content.
@interface PUAppCardView : UIView
- (instancetype)initWithBundleID:(NSString *)bundleID;
@property (nonatomic) BOOL showsLabel;
@property (nonatomic, readonly) UILabel *label;
@end

// A whole home screen: status bar, icon grid, widget and dock. Re-lays itself out for
// portrait and landscape, which is what the rotation preview animates.
@interface PUHomeScreenView : UIView
@property (nonatomic) BOOL padLayout;
@property (nonatomic) BOOL padStatusBar;
@property (nonatomic) BOOL floatingDock;
@property (nonatomic) BOOL dockRecents;
@property (nonatomic) BOOL dockAppLibrary;
@end
