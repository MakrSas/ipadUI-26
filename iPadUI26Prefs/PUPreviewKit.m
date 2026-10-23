#import "PUPreviewKit.h"
#import <objc/message.h>

UIImage *PUAppIcon(NSString *bundleID) {
	static NSCache *cache;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cache = [NSCache new];
	});
	UIImage *icon = [cache objectForKey:bundleID];
	if (icon) return icon;

	// Same private API Settings uses for its own app rows; format 2 is the 60pt icon.
	SEL sel = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
	if ([UIImage respondsToSelector:sel]) {
		icon = ((UIImage *(*)(Class, SEL, NSString *, int, CGFloat))objc_msgSend)(UIImage.class, sel, bundleID, 2, UIScreen.mainScreen.scale);
	}
	if (!icon) icon = PUSymbol(@"app.fill", 40, UIFontWeightRegular);
	[cache setObject:icon forKey:bundleID];
	return icon;
}

UIImage *PUSymbol(NSString *name, CGFloat pointSize, UIFontWeight weight) {
	UIImageSymbolWeight symbolWeight = weight >= UIFontWeightSemibold ? UIImageSymbolWeightSemibold : UIImageSymbolWeightRegular;
	UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:symbolWeight];
	return [UIImage systemImageNamed:name withConfiguration:config];
}

UIVisualEffect *PUGlassEffect(void) {
	// iOS 26 Liquid Glass when available, the system thin material otherwise.
	Class glass = NSClassFromString(@"UIGlassEffect");
	if (glass) return [glass new];
	return [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
}

NSArray<NSString *> *PUStockApps(void) {
	return @[
		@"com.apple.mobilesafari", @"com.apple.MobileSMS", @"com.apple.mobilemail", @"com.apple.Music",
		@"com.apple.mobilenotes", @"com.apple.mobilecal", @"com.apple.Maps", @"com.apple.mobileslideshow",
		@"com.apple.Preferences", @"com.apple.AppStore", @"com.apple.weather", @"com.apple.camera",
		@"com.apple.reminders", @"com.apple.podcasts", @"com.apple.facetime", @"com.apple.DocumentsApp",
		@"com.apple.mobiletimer", @"com.apple.calculator", @"com.apple.Health", @"com.apple.tv",
		@"com.apple.stocks", @"com.apple.findmy", @"com.apple.shortcuts", @"com.apple.Passbook",
	];
}

#pragma mark - Wallpaper

@implementation PUWallpaperView

+ (Class)layerClass {
	return CAGradientLayer.class;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		CAGradientLayer *layer = (CAGradientLayer *)self.layer;
		layer.startPoint = CGPointMake(0, 0);
		layer.endPoint = CGPointMake(1, 1);
		[self updateColors];
	}
	return self;
}

- (void)updateColors {
	BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
	NSArray *colors = dark
		? @[[UIColor colorWithRed:0.05 green:0.10 blue:0.30 alpha:1], [UIColor colorWithRed:0.28 green:0.08 blue:0.40 alpha:1], [UIColor colorWithRed:0.55 green:0.20 blue:0.18 alpha:1]]
		: @[[UIColor colorWithRed:0.35 green:0.62 blue:1.00 alpha:1], [UIColor colorWithRed:0.70 green:0.52 blue:0.98 alpha:1], [UIColor colorWithRed:1.00 green:0.70 blue:0.55 alpha:1]];
	// Not via KVC: UIColor stopped answering valueForKey:@"CGColor" on iOS 26.
	NSMutableArray *cgColors = [NSMutableArray array];
	for (UIColor *color in colors) [cgColors addObject:(__bridge id)color.CGColor];
	((CAGradientLayer *)self.layer).colors = cgColors;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
	[super traitCollectionDidChange:previous];
	[self updateColors];
}

@end

#pragma mark - Icons and glass

@implementation PUIconView

- (instancetype)initWithBundleID:(NSString *)bundleID {
	if ((self = [super initWithImage:PUAppIcon(bundleID)])) {
		self.contentMode = UIViewContentModeScaleAspectFill;
		self.clipsToBounds = YES;
		self.layer.cornerCurve = kCACornerCurveContinuous;
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	self.layer.cornerRadius = self.bounds.size.width * 0.225;
}

@end

@implementation PUGlassView

- (instancetype)initWithCornerRadius:(CGFloat)radius {
	if ((self = [super initWithEffect:PUGlassEffect()])) {
		self.clipsToBounds = YES;
		self.layer.cornerCurve = kCACornerCurveContinuous;
		self.cornerRadius = radius;
	}
	return self;
}

- (void)setCornerRadius:(CGFloat)cornerRadius {
	_cornerRadius = cornerRadius;
	self.layer.cornerRadius = cornerRadius;
}

@end

@implementation PUAppLibraryTile {
	NSArray<PUIconView *> *_icons;
}

- (instancetype)initWithCornerRadius:(CGFloat)radius {
	if ((self = [super initWithCornerRadius:radius])) {
		NSMutableArray *icons = [NSMutableArray array];
		for (NSString *bundleID in @[@"com.apple.weather", @"com.apple.Health", @"com.apple.stocks", @"com.apple.tv"]) {
			PUIconView *icon = [[PUIconView alloc] initWithBundleID:bundleID];
			[self.contentView addSubview:icon];
			[icons addObject:icon];
		}
		_icons = icons;
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	self.cornerRadius = self.bounds.size.width * 0.225;
	CGFloat inset = self.bounds.size.width * 0.14;
	CGFloat gap = self.bounds.size.width * 0.08;
	CGFloat side = (self.bounds.size.width - inset * 2 - gap) / 2;
	[_icons enumerateObjectsUsingBlock:^(PUIconView *icon, NSUInteger i, BOOL *stop) {
		icon.frame = CGRectMake(inset + (i % 2) * (side + gap), inset + (i / 2) * (side + gap), side, side);
	}];
}

@end

#pragma mark - Status bar

@implementation PUStatusBarView {
	UILabel *_time;
	UILabel *_date;
	UIImageView *_cellular;
	UIImageView *_wifi;
	UIImageView *_battery;
	UILabel *_batteryPercent;
	NSTimer *_clock;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_time = [UILabel new];
		_date = [UILabel new];
		_batteryPercent = [UILabel new];
		_cellular = [UIImageView new];
		_wifi = [UIImageView new];
		_battery = [UIImageView new];
		for (UIView *view in @[_time, _date, _batteryPercent, _cellular, _wifi, _battery]) {
			view.tintColor = UIColor.whiteColor;
			if ([view isKindOfClass:UILabel.class]) ((UILabel *)view).textColor = UIColor.whiteColor;
			view.contentMode = UIViewContentModeScaleAspectFit;
			[self addSubview:view];
		}
		_batteryPercent.text = @"100%";
		[self tick];
	}
	return self;
}

- (void)didMoveToWindow {
	[super didMoveToWindow];
	[_clock invalidate];
	_clock = nil;
	if (!self.window) return;
	__weak typeof(self) weakSelf = self;
	_clock = [NSTimer scheduledTimerWithTimeInterval:15 repeats:YES block:^(NSTimer *timer) {
		[weakSelf tick];
	}];
}

- (void)tick {
	NSDate *now = [NSDate date];
	_time.text = [NSDateFormatter localizedStringFromDate:now dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle];
	NSDateFormatter *formatter = [NSDateFormatter new];
	[formatter setLocalizedDateFormatFromTemplate:@"EEEdMMM"];
	_date.text = [formatter stringFromDate:now];
	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat h = self.bounds.size.height;
	CGFloat w = self.bounds.size.width;
	CGFloat font = h * 0.62;

	_time.font = [UIFont systemFontOfSize:font weight:UIFontWeightSemibold];
	_date.font = [UIFont systemFontOfSize:font weight:UIFontWeightSemibold];
	_batteryPercent.font = [UIFont systemFontOfSize:font * 0.85 weight:UIFontWeightSemibold];
	_cellular.image = [PUSymbol(@"cellularbars", font, UIFontWeightSemibold) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	_wifi.image = [PUSymbol(@"wifi", font, UIFontWeightSemibold) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	_battery.image = [PUSymbol(@"battery.100", font, UIFontWeightRegular) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[_time sizeToFit];
	[_date sizeToFit];
	[_batteryPercent sizeToFit];

	CGFloat symbol = h * 0.8;
	CGFloat midY = h / 2;
	CGSize batterySize = CGSizeMake(symbol * 1.6, symbol);

	if (self.padStyle) {
		// iPad: time and date on the left edge, Wi-Fi, percentage and battery on the right.
		CGFloat x = h * 0.6;
		_time.center = CGPointMake(x + _time.bounds.size.width / 2, midY);
		_date.center = CGPointMake(CGRectGetMaxX(_time.frame) + h * 0.35 + _date.bounds.size.width / 2, midY);
		_date.alpha = 1;
		_cellular.alpha = 0;
		_batteryPercent.alpha = 1;

		CGFloat right = w - h * 0.6;
		_battery.frame = CGRectMake(right - batterySize.width, midY - symbol / 2, batterySize.width, symbol);
		_batteryPercent.center = CGPointMake(CGRectGetMinX(_battery.frame) - h * 0.2 - _batteryPercent.bounds.size.width / 2, midY);
		_wifi.frame = CGRectMake(CGRectGetMinX(_batteryPercent.frame) - h * 0.35 - symbol, midY - symbol / 2, symbol, symbol);
		_cellular.frame = _wifi.frame;
	} else {
		// iPhone: time centred in the left ear, signal, Wi-Fi and battery in the right ear.
		_time.center = CGPointMake(w * 0.2, midY);
		_date.center = _time.center;
		_date.alpha = 0;
		_cellular.alpha = 1;
		_batteryPercent.alpha = 0;

		CGFloat total = symbol * 2 + batterySize.width + h * 0.5;
		CGFloat x = w * 0.8 - total / 2;
		_cellular.frame = CGRectMake(x, midY - symbol / 2, symbol, symbol);
		_wifi.frame = CGRectMake(CGRectGetMaxX(_cellular.frame) + h * 0.25, midY - symbol / 2, symbol, symbol);
		_battery.frame = CGRectMake(CGRectGetMaxX(_wifi.frame) + h * 0.25, midY - symbol / 2, batterySize.width, symbol);
		_batteryPercent.center = _battery.center;
	}
}

@end

#pragma mark - Dock

static const NSUInteger PUDockPinnedCount = 5;
static const NSUInteger PUDockClassicCount = 4;
static const NSUInteger PUDockRecentsCount = 3;

@implementation PUDockView {
	PUGlassView *_background;
	NSArray<PUIconView *> *_pinned;
	NSArray<PUIconView *> *_recentIcons;
	UIView *_divider;
	PUAppLibraryTile *_library;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_background = [[PUGlassView alloc] initWithCornerRadius:0];
		[self addSubview:_background];

		NSMutableArray *pinned = [NSMutableArray array];
		for (NSString *bundleID in @[@"com.apple.mobilesafari", @"com.apple.MobileSMS", @"com.apple.mobilemail", @"com.apple.Music", @"com.apple.mobilenotes"]) {
			PUIconView *icon = [[PUIconView alloc] initWithBundleID:bundleID];
			[self addSubview:icon];
			[pinned addObject:icon];
		}
		_pinned = pinned;

		_divider = [UIView new];
		_divider.backgroundColor = [UIColor colorWithWhite:1 alpha:0.45];
		[self addSubview:_divider];

		NSMutableArray *recents = [NSMutableArray array];
		for (NSString *bundleID in @[@"com.apple.Maps", @"com.apple.mobileslideshow", @"com.apple.Preferences"]) {
			PUIconView *icon = [[PUIconView alloc] initWithBundleID:bundleID];
			[self addSubview:icon];
			[recents addObject:icon];
		}
		_recentIcons = recents;

		_library = [[PUAppLibraryTile alloc] initWithCornerRadius:0];
		[self addSubview:_library];
	}
	return self;
}

- (CGFloat)iconSizeForHeight:(CGFloat)height {
	return height * 0.72;
}

- (CGFloat)floatingWidthForHeight:(CGFloat)height {
	CGFloat icon = [self iconSizeForHeight:height];
	CGFloat gap = icon * 0.28;
	CGFloat pad = (height - icon) / 2;
	NSUInteger trailing = (self.recents ? PUDockRecentsCount : 0) + (self.appLibrary ? 1 : 0);
	CGFloat width = pad * 2 + PUDockPinnedCount * icon + (PUDockPinnedCount - 1) * gap;
	if (trailing) width += gap * 2 + 1 + trailing * icon + (trailing - 1) * gap;
	return width;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect bounds = self.bounds;
	CGFloat h = bounds.size.height;
	CGFloat icon = [self iconSizeForHeight:h];
	CGFloat y = (h - icon) / 2;

	_background.frame = bounds;
	_background.cornerRadius = self.floating ? h * 0.32 : h * 0.38;

	if (!self.floating) {
		// Classic iPhone dock: four evenly spaced icons, no recents or App Library.
		CGFloat spacing = (bounds.size.width - PUDockClassicCount * icon) / (PUDockClassicCount + 1);
		[_pinned enumerateObjectsUsingBlock:^(PUIconView *view, NSUInteger i, BOOL *stop) {
			if (i < PUDockClassicCount) {
				view.frame = CGRectMake(spacing + i * (icon + spacing), y, icon, icon);
				view.alpha = 1;
			} else {
				view.frame = CGRectMake(bounds.size.width, y, icon, icon);
				view.alpha = 0;
			}
		}];
		for (UIView *view in [(NSArray<UIView *> *)_recentIcons arrayByAddingObjectsFromArray:@[_divider, _library]]) {
			view.alpha = 0;
			view.frame = CGRectMake(bounds.size.width - icon, y, icon, icon);
		}
		return;
	}

	CGFloat gap = icon * 0.28;
	CGFloat x = y;
	for (PUIconView *view in _pinned) {
		view.frame = CGRectMake(x, y, icon, icon);
		view.alpha = 1;
		x += icon + gap;
	}

	BOOL trailing = self.recents || self.appLibrary;
	_divider.alpha = trailing ? 1 : 0;
	_divider.frame = CGRectMake(x, y + icon * 0.12, 1, icon * 0.76);
	if (trailing) x += gap + 1;

	for (PUIconView *view in _recentIcons) {
		view.alpha = self.recents ? 1 : 0;
		view.frame = CGRectMake(x, y, icon, icon);
		if (self.recents) x += icon + gap;
	}
	_library.alpha = self.appLibrary ? 1 : 0;
	_library.frame = CGRectMake(x, y, icon, icon);
}

@end

#pragma mark - App card

@implementation PUAppCardView {
	UIView *_surface;
	UIView *_toolbar;
	PUIconView *_icon;
	NSArray<UIView *> *_lines;
	UILabel *_label;
}

- (instancetype)initWithBundleID:(NSString *)bundleID {
	if ((self = [super initWithFrame:CGRectZero])) {
		_surface = [UIView new];
		_surface.backgroundColor = UIColor.systemBackgroundColor;
		_surface.clipsToBounds = YES;
		_surface.layer.cornerCurve = kCACornerCurveContinuous;
		[self addSubview:_surface];

		self.layer.shadowColor = UIColor.blackColor.CGColor;
		self.layer.shadowOpacity = 0.25;
		self.layer.shadowOffset = CGSizeMake(0, 3);
		self.layer.shadowRadius = 8;

		_toolbar = [UIView new];
		_toolbar.backgroundColor = UIColor.secondarySystemBackgroundColor;
		[_surface addSubview:_toolbar];

		NSMutableArray *lines = [NSMutableArray array];
		for (int i = 0; i < 4; i++) {
			UIView *line = [UIView new];
			line.backgroundColor = UIColor.tertiarySystemFillColor;
			line.layer.cornerCurve = kCACornerCurveContinuous;
			[_surface addSubview:line];
			[lines addObject:line];
		}
		_lines = lines;

		_icon = [[PUIconView alloc] initWithBundleID:bundleID];
		[_surface addSubview:_icon];

		_label = [UILabel new];
		_label.textColor = UIColor.whiteColor;
		_label.textAlignment = NSTextAlignmentCenter;
		_label.text = [self displayNameForBundleID:bundleID];
		[self addSubview:_label];
	}
	return self;
}

- (NSString *)displayNameForBundleID:(NSString *)bundleID {
	// LSApplicationProxy is what Settings itself uses to show localized app names.
	Class proxyClass = NSClassFromString(@"LSApplicationProxy");
	SEL sel = NSSelectorFromString(@"applicationProxyForIdentifier:");
	if ([proxyClass respondsToSelector:sel]) {
		id proxy = ((id (*)(Class, SEL, NSString *))objc_msgSend)(proxyClass, sel, bundleID);
		NSString *name = [proxy respondsToSelector:@selector(localizedName)] ? ((NSString *(*)(id, SEL))objc_msgSend)(proxy, @selector(localizedName)) : nil;
		if (name.length) return name;
	}
	return bundleID.pathExtension;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect b = self.bounds;
	CGFloat radius = MIN(b.size.width, b.size.height) * 0.09;
	_surface.frame = b;
	_surface.layer.cornerRadius = radius;
	self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:b cornerRadius:radius].CGPath;

	CGFloat bar = b.size.height * 0.14;
	_toolbar.frame = CGRectMake(0, 0, b.size.width, bar);

	CGFloat icon = MIN(b.size.width, b.size.height) * 0.3;
	_icon.frame = CGRectMake((b.size.width - icon) / 2, bar + (b.size.height - bar) * 0.18, icon, icon);

	CGFloat lineH = MAX(2, b.size.height * 0.045);
	CGFloat lineY = CGRectGetMaxY(_icon.frame) + lineH * 2;
	[_lines enumerateObjectsUsingBlock:^(UIView *line, NSUInteger i, BOOL *stop) {
		CGFloat width = b.size.width * (i % 2 ? 0.5 : 0.72);
		line.frame = CGRectMake((b.size.width - width) / 2, lineY + i * lineH * 1.9, width, lineH);
		line.layer.cornerRadius = lineH / 2;
		line.hidden = CGRectGetMaxY(line.frame) > b.size.height - lineH;
	}];

	CGFloat font = MAX(8, b.size.width * 0.1);
	_label.font = [UIFont systemFontOfSize:font weight:UIFontWeightSemibold];
	_label.frame = CGRectMake(-b.size.width * 0.2, -font * 1.7, b.size.width * 1.4, font * 1.3);
	_label.alpha = self.showsLabel ? 1 : 0;
}

@end

#pragma mark - Home screen

@implementation PUHomeScreenView {
	PUWallpaperView *_wallpaper;
	PUStatusBarView *_statusBar;
	UIView *_island;
	PUGlassView *_widget;
	UILabel *_widgetDay;
	UILabel *_widgetDate;
	NSArray<PUIconView *> *_icons;
	PUDockView *_dock;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.clipsToBounds = YES;
		self.layer.cornerCurve = kCACornerCurveContinuous;
		self.layer.borderColor = UIColor.blackColor.CGColor;

		_wallpaper = [PUWallpaperView new];
		[self addSubview:_wallpaper];

		_widget = [[PUGlassView alloc] initWithCornerRadius:0];
		_widgetDay = [UILabel new];
		_widgetDay.textColor = UIColor.systemRedColor;
		_widgetDate = [UILabel new];
		_widgetDate.textColor = UIColor.whiteColor;
		NSDateFormatter *formatter = [NSDateFormatter new];
		[formatter setLocalizedDateFormatFromTemplate:@"EEEE"];
		_widgetDay.text = [formatter stringFromDate:[NSDate date]].uppercaseString;
		[formatter setLocalizedDateFormatFromTemplate:@"d"];
		_widgetDate.text = [formatter stringFromDate:[NSDate date]];
		[_widget.contentView addSubview:_widgetDay];
		[_widget.contentView addSubview:_widgetDate];
		[self addSubview:_widget];

		NSMutableArray *icons = [NSMutableArray array];
		for (NSString *bundleID in PUStockApps()) {
			PUIconView *icon = [[PUIconView alloc] initWithBundleID:bundleID];
			[self addSubview:icon];
			[icons addObject:icon];
		}
		_icons = icons;

		_dock = [PUDockView new];
		[self addSubview:_dock];

		_statusBar = [PUStatusBarView new];
		[self addSubview:_statusBar];

		_island = [UIView new];
		_island.backgroundColor = UIColor.blackColor;
		[self addSubview:_island];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect b = self.bounds;
	CGFloat w = b.size.width;
	CGFloat h = b.size.height;
	BOOL landscape = w > h;
	CGFloat shortSide = MIN(w, h);

	self.layer.cornerRadius = shortSide * 0.13;
	self.layer.borderWidth = MAX(2, shortSide * 0.025);
	_wallpaper.frame = b;

	// Status bar and Dynamic Island.
	CGFloat statusH = shortSide * 0.055;
	CGFloat statusTop = shortSide * 0.045;
	_statusBar.padStyle = self.padStatusBar;
	_statusBar.frame = CGRectMake(landscape ? shortSide * 0.12 : 0, statusTop, landscape ? w - shortSide * 0.24 : w, statusH);
	if (landscape) {
		CGFloat islandW = shortSide * 0.075;
		_island.frame = CGRectMake(shortSide * 0.04, (h - shortSide * 0.27) / 2, islandW, shortSide * 0.27);
		_island.layer.cornerRadius = islandW / 2;
	} else {
		CGFloat islandW = w * 0.3;
		_island.frame = CGRectMake((w - islandW) / 2, statusTop - statusH * 0.05, islandW, statusH * 1.15);
		_island.layer.cornerRadius = _island.frame.size.height / 2;
	}

	// Dock.
	_dock.floating = self.floatingDock;
	_dock.recents = self.dockRecents;
	_dock.appLibrary = self.dockAppLibrary;
	CGFloat dockH = shortSide * (self.floatingDock ? 0.15 : 0.22);
	CGFloat margin = shortSide * 0.04;
	CGFloat dockW = self.floatingDock ? MIN([_dock floatingWidthForHeight:dockH], w - margin * 2) : w - margin * 2;
	if (self.floatingDock) dockH = MIN(dockH, dockH * (w - margin * 2) / [_dock floatingWidthForHeight:dockH]);
	_dock.frame = CGRectMake((w - dockW) / 2, h - dockH - margin * (self.floatingDock ? 1.4 : 1), dockW, dockH);

	// Icon grid: iPad packs more, smaller icons with a widget; iPhone shows a 4-column grid.
	CGFloat insetX = landscape ? shortSide * 0.18 : shortSide * 0.08;
	CGFloat gridTop = statusTop + statusH + shortSide * 0.06;
	CGFloat gridBottom = CGRectGetMinY(_dock.frame) - shortSide * 0.05;
	NSUInteger columns = self.padLayout ? (landscape ? 8 : 5) : (landscape ? 6 : 4);
	CGFloat cellW = (w - insetX * 2) / columns;
	CGFloat iconSide = cellW * (self.padLayout ? 0.66 : 0.72);
	NSUInteger rows = MAX(1, (NSUInteger)floor((gridBottom - gridTop) / (cellW * (self.padLayout ? 1.0 : 1.15))));
	CGFloat cellH = (gridBottom - gridTop) / rows;

	// The widget covers a 2x2 block of cells in the top-left corner.
	BOOL widget = self.padLayout && rows >= 3;
	_widget.alpha = widget ? 1 : 0;
	CGFloat widgetSide = MIN(cellW, cellH) * 2 - (cellW - iconSide);
	_widget.frame = CGRectMake(insetX + (cellW - iconSide) / 2, gridTop + (cellH - iconSide) / 2, widgetSide, widgetSide);
	_widget.cornerRadius = widgetSide * 0.2;
	_widgetDay.font = [UIFont systemFontOfSize:widgetSide * 0.12 weight:UIFontWeightBold];
	_widgetDate.font = [UIFont systemFontOfSize:widgetSide * 0.42 weight:UIFontWeightLight];
	[_widgetDay sizeToFit];
	[_widgetDate sizeToFit];
	_widgetDay.frame = CGRectMake(widgetSide * 0.12, widgetSide * 0.1, widgetSide * 0.8, _widgetDay.bounds.size.height);
	_widgetDate.frame = CGRectMake(widgetSide * 0.1, CGRectGetMaxY(_widgetDay.frame), widgetSide * 0.8, _widgetDate.bounds.size.height);

	__block NSUInteger slot = 0;
	[_icons enumerateObjectsUsingBlock:^(PUIconView *icon, NSUInteger i, BOOL *stop) {
		NSUInteger row, column;
		do {
			row = slot / columns;
			column = slot % columns;
			slot++;
		} while (widget && row < 2 && column < 2);

		CGRect cell = CGRectMake(insetX + column * cellW, gridTop + row * cellH, cellW, cellH);
		icon.frame = CGRectMake(CGRectGetMidX(cell) - iconSide / 2, CGRectGetMidY(cell) - iconSide / 2, iconSide, iconSide);
		icon.alpha = row < rows ? 1 : 0;
	}];
}

@end
