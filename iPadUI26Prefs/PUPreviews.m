#import "PUPreviews.h"
#import "PUPreviewKit.h"
#import "../Sources/PUPrefs.h"

#define PULocalized(key) [[NSBundle bundleForClass:PUPreviewView.class] localizedStringForKey:key value:key table:@"Previews"]

@interface PUPreviewView ()
@property (nonatomic, readonly) PUWallpaperView *stage;
@property (nonatomic, readonly) NSInteger phase;
// Seconds between demo steps; 0 means the preview only changes with the settings.
+ (NSTimeInterval)phaseInterval;
// Positions every subview of the stage for the current settings and phase.
- (void)layoutStage:(CGRect)bounds;
@end

@interface PUOverviewPreview : PUPreviewView
@end
@interface PUHomePreview : PUPreviewView
@end
@interface PUDockPreview : PUPreviewView
@end
@interface PUSwitcherPreview : PUPreviewView
@end
@interface PUMultitaskingPreview : PUPreviewView
@end
@interface PUStageManagerPreview : PUPreviewView
@end
@interface PUStatusBarPreview : PUPreviewView
@end
@interface PURotationPreview : PUPreviewView
@end
@interface PUAppsPreview : PUPreviewView
@end

static void PUApplyHomeSettings(PUHomeScreenView *home) {
	home.padLayout = PUPrefBool(PUKeySpringBoardIdiom);
	home.padStatusBar = PUPrefBool(PUKeyPadStatusBar);
	home.floatingDock = PUPrefBool(PUKeyFloatingDock);
	home.dockRecents = PUPrefBool(PUKeyDockRecents);
	home.dockAppLibrary = PUPrefBool(PUKeyDockAppLibrary);
	[home setNeedsLayout];
	[home layoutIfNeeded];
}

// Largest rect of the given aspect ratio (width / height) centred in `bounds`.
static CGRect PUFit(CGRect bounds, CGFloat aspect) {
	CGFloat w = bounds.size.width;
	CGFloat h = w / aspect;
	if (h > bounds.size.height) {
		h = bounds.size.height;
		w = h * aspect;
	}
	return CGRectMake(CGRectGetMidX(bounds) - w / 2, CGRectGetMidY(bounds) - h / 2, w, h);
}

static CGRect PUInset(CGRect rect, CGFloat dx, CGFloat dy) {
	return CGRectInset(rect, dx, dy);
}

// A black-bezelled iPhone screen in landscape, used as the canvas for window previews.
static UIView *PUMakeScreen(void) {
	UIView *screen = [UIView new];
	screen.clipsToBounds = YES;
	screen.layer.cornerCurve = kCACornerCurveContinuous;
	screen.layer.borderColor = UIColor.blackColor.CGColor;
	PUWallpaperView *wallpaper = [PUWallpaperView new];
	wallpaper.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[screen addSubview:wallpaper];
	return screen;
}

static void PULayoutScreen(UIView *screen, CGRect frame) {
	screen.frame = frame;
	CGFloat shortSide = MIN(frame.size.width, frame.size.height);
	screen.layer.cornerRadius = shortSide * 0.13;
	screen.layer.borderWidth = MAX(2, shortSide * 0.03);
	screen.subviews.firstObject.frame = screen.bounds;
}

#pragma mark - Base

@implementation PUPreviewView {
	NSTimer *_timer;
}

+ (instancetype)previewForKind:(NSString *)kind {
	NSDictionary<NSString *, Class> *classes = @{
		@"overview": PUOverviewPreview.class,
		@"home": PUHomePreview.class,
		@"dock": PUDockPreview.class,
		@"switcher": PUSwitcherPreview.class,
		@"multitasking": PUMultitaskingPreview.class,
		@"stagemanager": PUStageManagerPreview.class,
		@"statusbar": PUStatusBarPreview.class,
		@"rotation": PURotationPreview.class,
		@"apps": PUAppsPreview.class,
	};
	Class cls = classes[kind] ?: PUOverviewPreview.class;
	return [cls new];
}

+ (NSTimeInterval)phaseInterval {
	return 0;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_stage = [PUWallpaperView new];
		_stage.clipsToBounds = YES;
		_stage.layer.cornerRadius = 18;
		_stage.layer.cornerCurve = kCACornerCurveContinuous;
		[self addSubview:_stage];
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(prefsChanged) name:PUPrefsDidChangeNotification object:nil];
	}
	return self;
}

- (void)dealloc {
	[NSNotificationCenter.defaultCenter removeObserver:self];
	[_timer invalidate];
}

- (void)didMoveToWindow {
	[super didMoveToWindow];
	[_timer invalidate];
	_timer = nil;
	NSTimeInterval interval = [self.class phaseInterval];
	if (!self.window || interval <= 0) return;
	__weak typeof(self) weakSelf = self;
	_timer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer *timer) {
		[weakSelf advancePhase];
	}];
}

- (void)advancePhase {
	if (UIAccessibilityIsReduceMotionEnabled()) return;
	_phase++;
	[self animateLayout];
}

- (void)prefsChanged {
	[self animateLayout];
}

- (void)animateLayout {
	[UIView animateWithDuration:0.6 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
		[self setNeedsLayout];
		[self layoutIfNeeded];
	} completion:nil];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	_stage.frame = CGRectInset(self.bounds, 16, 10);
	// A preview must never take the settings down: log the failure and leave it empty.
	@try {
		[self layoutStage:_stage.bounds];
	} @catch (NSException *exception) {
		NSLog(@"[iPadUI26] preview %@ failed: %@", self.class, exception);
		for (UIView *view in _stage.subviews) view.hidden = YES;
	}
}

- (void)layoutStage:(CGRect)bounds {
}

@end

#pragma mark - Overview

@implementation PUOverviewPreview {
	PUHomeScreenView *_home;
	NSArray<NSString *> *_keys;
	NSArray<UIImageView *> *_checks;
	NSArray<UILabel *> *_labels;
	PUGlassView *_listBackground;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_home = [PUHomeScreenView new];
		[self.stage addSubview:_home];

		_listBackground = [[PUGlassView alloc] initWithCornerRadius:14];
		[self.stage addSubview:_listBackground];

		_keys = @[PUKeySpringBoardIdiom, PUKeyFloatingDock, PUKeyGridSwitcher, PUKeyMultitasking, PUKeyStageManager, PUKeyPadStatusBar, PUKeyHomeRotation, PUKeyAppsIdiom];
		NSDictionary *titles = @{
			PUKeySpringBoardIdiom: @"iPad Home Screen",
			PUKeyFloatingDock: @"Floating Dock",
			PUKeyGridSwitcher: @"App Switcher Grid",
			PUKeyMultitasking: @"Split View & Slide Over",
			PUKeyStageManager: @"Stage Manager",
			PUKeyPadStatusBar: @"iPad Status Bar",
			PUKeyHomeRotation: @"Home Screen Rotation",
			PUKeyAppsIdiom: @"iPad Apps Layout",
		};
		NSMutableArray *checks = [NSMutableArray array];
		NSMutableArray *labels = [NSMutableArray array];
		for (NSString *key in _keys) {
			UIImageView *check = [UIImageView new];
			check.contentMode = UIViewContentModeScaleAspectFit;
			[_listBackground.contentView addSubview:check];
			[checks addObject:check];

			UILabel *label = [UILabel new];
			label.text = PULocalized(titles[key]);
			label.textColor = UIColor.labelColor;
			label.adjustsFontSizeToFitWidth = YES;
			label.minimumScaleFactor = 0.7;
			[_listBackground.contentView addSubview:label];
			[labels addObject:label];
		}
		_checks = checks;
		_labels = labels;
	}
	return self;
}

- (void)layoutStage:(CGRect)bounds {
	BOOL enabled = PUPrefBool(PUKeyEnabled);
	CGRect content = CGRectInset(bounds, 14, 14);
	CGRect phone = PUFit(CGRectMake(content.origin.x, content.origin.y, content.size.width * 0.42, content.size.height), 0.46);
	phone.origin.x = content.origin.x;
	_home.frame = phone;
	PUApplyHomeSettings(_home);
	_home.alpha = enabled ? 1 : 0.5;

	CGFloat listX = CGRectGetMaxX(phone) + 14;
	CGRect list = CGRectMake(listX, content.origin.y, CGRectGetMaxX(content) - listX, content.size.height);
	_listBackground.frame = list;

	CGFloat rowH = (list.size.height - 12) / _keys.count;
	CGFloat font = MIN(14, rowH * 0.5);
	[_keys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger i, BOOL *stop) {
		BOOL on = enabled && PUPrefBool(key);
		UIImageView *check = self->_checks[i];
		check.image = PUSymbol(on ? @"checkmark.circle.fill" : @"circle", font, UIFontWeightSemibold);
		check.tintColor = on ? UIColor.systemGreenColor : UIColor.tertiaryLabelColor;
		check.frame = CGRectMake(10, 6 + i * rowH + (rowH - font * 1.2) / 2, font * 1.2, font * 1.2);

		UILabel *label = self->_labels[i];
		label.font = [UIFont systemFontOfSize:font weight:UIFontWeightMedium];
		label.textColor = on ? UIColor.labelColor : UIColor.secondaryLabelColor;
		label.frame = CGRectMake(CGRectGetMaxX(check.frame) + 8, 6 + i * rowH, list.size.width - CGRectGetMaxX(check.frame) - 16, rowH);
	}];
}

@end

#pragma mark - Home screen

@implementation PUHomePreview {
	PUHomeScreenView *_home;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_home = [PUHomeScreenView new];
		[self.stage addSubview:_home];
	}
	return self;
}

- (void)layoutStage:(CGRect)bounds {
	_home.frame = PUFit(CGRectInset(bounds, 14, 14), 0.46);
	PUApplyHomeSettings(_home);
}

@end

#pragma mark - Dock

@implementation PUDockPreview {
	PUDockView *_dock;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_dock = [PUDockView new];
		[self.stage addSubview:_dock];
	}
	return self;
}

- (void)layoutStage:(CGRect)bounds {
	_dock.floating = PUPrefBool(PUKeyFloatingDock);
	_dock.recents = PUPrefBool(PUKeyDockRecents);
	_dock.appLibrary = PUPrefBool(PUKeyDockAppLibrary);

	CGFloat maxW = bounds.size.width - 28;
	CGFloat h = MIN(bounds.size.height * 0.5, 64);
	CGFloat w = maxW;
	if (_dock.floating) {
		w = [_dock floatingWidthForHeight:h];
		if (w > maxW) {
			h *= maxW / w;
			w = maxW;
		}
	} else {
		h = MIN(bounds.size.height * 0.55, maxW / 4.4);
	}
	_dock.frame = CGRectMake(CGRectGetMidX(bounds) - w / 2, CGRectGetMaxY(bounds) - h - (bounds.size.height - h) / 2, w, h);
	[_dock setNeedsLayout];
	[_dock layoutIfNeeded];
}

@end

#pragma mark - App switcher

@implementation PUSwitcherPreview {
	NSArray<PUAppCardView *> *_cards;
}

+ (NSTimeInterval)phaseInterval {
	return 3;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		NSMutableArray *cards = [NSMutableArray array];
		for (NSString *bundleID in @[@"com.apple.mobilesafari", @"com.apple.Maps", @"com.apple.mobilenotes", @"com.apple.Music", @"com.apple.mobilemail", @"com.apple.Preferences", @"com.apple.mobilecal", @"com.apple.weather"]) {
			PUAppCardView *card = [[PUAppCardView alloc] initWithBundleID:bundleID];
			card.showsLabel = YES;
			[self.stage addSubview:card];
			[cards addObject:card];
		}
		_cards = cards;
	}
	return self;
}

- (void)layoutStage:(CGRect)bounds {
	BOOL grid = PUPrefBool(PUKeyGridSwitcher);
	CGFloat aspect = 0.46;
	CGFloat labelSpace = 18;
	NSUInteger count = _cards.count;

	if (grid) {
		// iPad grid: two rows of evenly sized cards, newest top-left.
		CGFloat gap = 14;
		CGFloat cardH = (bounds.size.height - labelSpace * 2 - gap * 3) / 2;
		CGFloat cardW = cardH * aspect;
		NSUInteger columns = MIN(4, MAX(1, (NSUInteger)floor((bounds.size.width - gap) / (cardW + gap * 1.6))));
		CGFloat spacing = (bounds.size.width - columns * cardW) / (columns + 1);
		[_cards enumerateObjectsUsingBlock:^(PUAppCardView *card, NSUInteger i, BOOL *stop) {
			NSUInteger row = i / columns;
			NSUInteger column = i % columns;
			CGFloat x = spacing + column * (cardW + spacing);
			CGFloat y = gap + labelSpace + row * (cardH + labelSpace + gap);
			card.layer.zPosition = 0;
			card.bounds = CGRectMake(0, 0, cardW, cardH);
			card.center = CGPointMake(x + cardW / 2, y + cardH / 2);
			card.transform = CGAffineTransformIdentity;
			card.alpha = row < 2 ? 1 : 0;
			[card setNeedsLayout];
			[card layoutIfNeeded];
		}];
		return;
	}

	// iPhone deck: overlapping cards that grow toward the right, with a gentle swipe demo.
	CGFloat cardH = bounds.size.height - labelSpace - 24;
	CGFloat cardW = cardH * aspect;
	CGFloat step = cardW * 0.62;
	CGFloat offset = (self.phase % 2) ? step * 0.5 : 0;
	NSUInteger visible = 4;
	[_cards enumerateObjectsUsingBlock:^(PUAppCardView *card, NSUInteger i, BOOL *stop) {
		NSInteger position = (NSInteger)(count - 1 - i);
		CGFloat scale = 1 - MIN(position, 3) * 0.06;
		CGFloat x = CGRectGetMaxX(bounds) - cardW * 0.65 - position * step + offset;
		card.layer.zPosition = -position;
		card.bounds = CGRectMake(0, 0, cardW, cardH);
		card.center = CGPointMake(x, labelSpace + 12 + cardH / 2);
		card.transform = CGAffineTransformMakeScale(scale, scale);
		card.alpha = position < (NSInteger)visible ? 1 : 0;
		[card setNeedsLayout];
		[card layoutIfNeeded];
	}];
}

@end

#pragma mark - Split View and Slide Over

@implementation PUMultitaskingPreview {
	UIView *_screen;
	PUAppCardView *_primary;
	PUAppCardView *_secondary;
	PUAppCardView *_slideOver;
	UIView *_divider;
	UIView *_grabber;
	UIView *_slideOverGrabber;
}

+ (NSTimeInterval)phaseInterval {
	return 2.2;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_screen = PUMakeScreen();
		[self.stage addSubview:_screen];

		_primary = [[PUAppCardView alloc] initWithBundleID:@"com.apple.mobilesafari"];
		_secondary = [[PUAppCardView alloc] initWithBundleID:@"com.apple.mobilenotes"];
		_slideOver = [[PUAppCardView alloc] initWithBundleID:@"com.apple.MobileSMS"];
		_divider = [UIView new];
		_divider.backgroundColor = UIColor.blackColor;
		_grabber = [UIView new];
		_grabber.backgroundColor = UIColor.systemGrayColor;
		_slideOverGrabber = [UIView new];
		_slideOverGrabber.backgroundColor = UIColor.systemGray3Color;
		for (UIView *view in @[_primary, _secondary, _divider, _grabber, _slideOver]) [_screen addSubview:view];
		[_slideOver addSubview:_slideOverGrabber];
	}
	return self;
}

- (void)layoutStage:(CGRect)bounds {
	BOOL enabled = PUPrefBool(PUKeyMultitasking);
	CGRect frame = PUFit(CGRectInset(bounds, 14, 14), 2.16);
	PULayoutScreen(_screen, frame);
	CGRect screen = PUInset(_screen.bounds, frame.size.height * 0.03, frame.size.height * 0.03);

	if (!enabled) {
		_primary.frame = screen;
		_secondary.frame = CGRectMake(CGRectGetMaxX(screen), screen.origin.y, screen.size.width * 0.4, screen.size.height);
		_slideOver.frame = CGRectMake(CGRectGetMaxX(_screen.bounds) + 10, screen.origin.y + 10, screen.size.width * 0.28, screen.size.height - 20);
		_divider.alpha = 0;
		_grabber.alpha = 0;
		_secondary.alpha = 0;
		_slideOver.alpha = 0;
		[self layoutCards];
		return;
	}

	// Split View with a resizable divider, plus a Slide Over window that slides in and out.
	NSInteger step = self.phase % 4;
	CGFloat split = (step == 1 || step == 2) ? 0.62 : 0.5;
	BOOL slideOverVisible = step >= 2;
	CGFloat dividerW = MAX(4, screen.size.height * 0.035);
	CGFloat leftW = (screen.size.width - dividerW) * split;

	_primary.frame = CGRectMake(screen.origin.x, screen.origin.y, leftW, screen.size.height);
	_divider.frame = CGRectMake(CGRectGetMaxX(_primary.frame), screen.origin.y, dividerW, screen.size.height);
	_secondary.frame = CGRectMake(CGRectGetMaxX(_divider.frame), screen.origin.y, CGRectGetMaxX(screen) - CGRectGetMaxX(_divider.frame), screen.size.height);
	CGFloat grabberH = screen.size.height * 0.16;
	_grabber.frame = CGRectMake(CGRectGetMidX(_divider.frame) - dividerW * 0.2, CGRectGetMidY(screen) - grabberH / 2, dividerW * 0.4, grabberH);
	_grabber.layer.cornerRadius = dividerW * 0.2;

	CGFloat slideW = screen.size.width * 0.27;
	CGFloat slideX = slideOverVisible ? CGRectGetMaxX(screen) - slideW - screen.size.height * 0.05 : CGRectGetMaxX(_screen.bounds) + 10;
	_slideOver.frame = CGRectMake(slideX, screen.origin.y + screen.size.height * 0.05, slideW, screen.size.height * 0.9);

	_divider.alpha = 1;
	_grabber.alpha = 1;
	_secondary.alpha = 1;
	_slideOver.alpha = 1;
	[self layoutCards];
}

- (void)layoutCards {
	for (PUAppCardView *card in @[_primary, _secondary, _slideOver]) {
		[card setNeedsLayout];
		[card layoutIfNeeded];
	}
	CGFloat w = _slideOver.bounds.size.width * 0.3;
	_slideOverGrabber.frame = CGRectMake((_slideOver.bounds.size.width - w) / 2, 3, w, 3);
	_slideOverGrabber.layer.cornerRadius = 1.5;
}

@end

#pragma mark - Stage Manager

@implementation PUStageManagerPreview {
	UIView *_screen;
	NSArray<PUAppCardView *> *_stageWindows;
	NSArray<PUAppCardView *> *_stripWindows;
	PUDockView *_dock;
}

+ (NSTimeInterval)phaseInterval {
	return 2.6;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_screen = PUMakeScreen();
		[self.stage addSubview:_screen];

		NSMutableArray *strip = [NSMutableArray array];
		for (NSString *bundleID in @[@"com.apple.mobilemail", @"com.apple.Music", @"com.apple.Maps"]) {
			PUAppCardView *card = [[PUAppCardView alloc] initWithBundleID:bundleID];
			[_screen addSubview:card];
			[strip addObject:card];
		}
		_stripWindows = strip;

		NSMutableArray *windows = [NSMutableArray array];
		for (NSString *bundleID in @[@"com.apple.mobilesafari", @"com.apple.mobilenotes"]) {
			PUAppCardView *card = [[PUAppCardView alloc] initWithBundleID:bundleID];
			[_screen addSubview:card];
			[windows addObject:card];
		}
		_stageWindows = windows;

		_dock = [PUDockView new];
		_dock.floating = YES;
		[_screen addSubview:_dock];
	}
	return self;
}

- (void)layoutStage:(CGRect)bounds {
	BOOL enabled = PUPrefBool(PUKeyStageManager);
	CGRect frame = PUFit(CGRectInset(bounds, 14, 14), 2.16);
	PULayoutScreen(_screen, frame);
	CGRect screen = PUInset(_screen.bounds, frame.size.height * 0.05, frame.size.height * 0.05);
	CGFloat h = screen.size.height;

	// Recent windows sit in a strip on the left, tilted toward the centre stage.
	CGFloat stripW = screen.size.width * 0.13;
	CGFloat stripH = h * 0.22;
	CATransform3D tilt = CATransform3DIdentity;
	tilt.m34 = -1.0 / 300;
	tilt = CATransform3DRotate(tilt, M_PI / 7, 0, 1, 0);
	[_stripWindows enumerateObjectsUsingBlock:^(PUAppCardView *card, NSUInteger i, BOOL *stop) {
		card.layer.transform = CATransform3DIdentity;
		card.bounds = CGRectMake(0, 0, stripW, stripH);
		card.center = CGPointMake(screen.origin.x + stripW / 2 + (enabled ? 0 : -stripW * 2), screen.origin.y + h * 0.12 + i * (stripH + h * 0.06) + stripH / 2);
		card.layer.transform = tilt;
		card.alpha = enabled ? 1 : 0;
	}];

	NSInteger front = self.phase % 2;
	CGFloat stageX = screen.origin.x + stripW + screen.size.width * 0.06;
	CGFloat stageW = CGRectGetMaxX(screen) - stageX;
	[_stageWindows enumerateObjectsUsingBlock:^(PUAppCardView *card, NSUInteger i, BOOL *stop) {
		card.layer.transform = CATransform3DIdentity;
		if (!enabled) {
			card.frame = i == 0 ? PUInset(self->_screen.bounds, frame.size.height * 0.03, frame.size.height * 0.03) : CGRectZero;
			card.alpha = i == 0 ? 1 : 0;
			return;
		}
		// Two overlapping, freely sized windows; the demo brings each to the front in turn.
		CGRect window = i == 0
			? CGRectMake(stageX, screen.origin.y, stageW * 0.62, h * 0.8)
			: CGRectMake(stageX + stageW * 0.4, screen.origin.y + h * 0.12, stageW * 0.58, h * 0.72);
		card.frame = window;
		card.alpha = 1;
		card.layer.zPosition = (NSInteger)i == front ? 2 : 1;
	}];
	for (PUAppCardView *card in [_stripWindows arrayByAddingObjectsFromArray:_stageWindows]) {
		[card setNeedsLayout];
		[card layoutIfNeeded];
	}

	CGFloat dockH = h * 0.14;
	CGFloat dockW = MIN([_dock floatingWidthForHeight:dockH], screen.size.width * 0.6);
	_dock.frame = CGRectMake(CGRectGetMidX(screen) - dockW / 2, CGRectGetMaxY(screen) - dockH + (enabled ? 0 : dockH * 2), dockW, dockH);
	_dock.layer.zPosition = 3;
	_dock.alpha = enabled ? 1 : 0;
	[_dock setNeedsLayout];
	[_dock layoutIfNeeded];
}

@end

#pragma mark - Status bar

@implementation PUStatusBarPreview {
	UIView *_clip;
	PUHomeScreenView *_home;
	UILabel *_caption;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_clip = [UIView new];
		_clip.clipsToBounds = YES;
		[self.stage addSubview:_clip];
		_home = [PUHomeScreenView new];
		[_clip addSubview:_home];

		_caption = [UILabel new];
		_caption.textAlignment = NSTextAlignmentCenter;
		_caption.textColor = UIColor.whiteColor;
		_caption.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
		[self.stage addSubview:_caption];
	}
	return self;
}

- (void)layoutStage:(CGRect)bounds {
	// Only the top edge of a large home screen is shown, so the status bar reads clearly.
	CGFloat width = MIN(bounds.size.width - 40, 360);
	CGFloat height = width / 0.46;
	_clip.frame = CGRectMake(CGRectGetMidX(bounds) - width / 2, 14, width, bounds.size.height - 40);
	_home.frame = CGRectMake(0, 0, width, height);
	PUApplyHomeSettings(_home);

	BOOL pad = PUPrefBool(PUKeyPadStatusBar);
	_caption.text = PULocalized(pad ? @"iPad status bar: time, date and battery percentage" : @"Standard iPhone status bar");
	_caption.frame = CGRectMake(0, CGRectGetMaxY(bounds) - 24, bounds.size.width, 18);
}

@end

#pragma mark - Rotation

@implementation PURotationPreview {
	PUHomeScreenView *_home;
	UIImageView *_lock;
}

+ (NSTimeInterval)phaseInterval {
	return 2.4;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_home = [PUHomeScreenView new];
		[self.stage addSubview:_home];
		_lock = [[UIImageView alloc] initWithImage:PUSymbol(@"lock.rotation", 22, UIFontWeightSemibold)];
		_lock.tintColor = UIColor.whiteColor;
		[self.stage addSubview:_lock];
	}
	return self;
}

- (void)layoutStage:(CGRect)bounds {
	BOOL enabled = PUPrefBool(PUKeyHomeRotation);
	BOOL landscape = enabled && self.phase % 2;
	CGRect area = CGRectInset(bounds, 14, 14);
	CGRect portrait = PUFit(area, 0.46);
	CGRect frame = landscape ? PUFit(area, 1 / 0.46) : portrait;
	_home.frame = frame;
	PUApplyHomeSettings(_home);

	[_lock sizeToFit];
	_lock.center = CGPointMake(CGRectGetMaxX(portrait) + 34, CGRectGetMidY(bounds));
	_lock.alpha = enabled ? 0 : 1;
}

@end

#pragma mark - Apps

@implementation PUAppsPreview {
	UIView *_screen;
	UIView *_app;
	UIView *_sidebar;
	NSArray<UIView *> *_sidebarRows;
	UIView *_detail;
	NSArray<UIView *> *_detailRows;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_screen = PUMakeScreen();
		[self.stage addSubview:_screen];

		_app = [UIView new];
		_app.backgroundColor = UIColor.systemGroupedBackgroundColor;
		_app.clipsToBounds = YES;
		[_screen addSubview:_app];

		_sidebar = [UIView new];
		_sidebar.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
		[_app addSubview:_sidebar];

		NSArray *colors = @[UIColor.systemOrangeColor, UIColor.systemBlueColor, UIColor.systemGreenColor, UIColor.systemRedColor, UIColor.systemIndigoColor, UIColor.systemGrayColor];
		NSArray *symbols = @[@"airplane", @"wifi", @"antenna.radiowaves.left.and.right", @"bell.badge.fill", @"moon.fill", @"gear"];
		NSMutableArray *rows = [NSMutableArray array];
		for (NSUInteger i = 0; i < colors.count; i++) {
			UIView *row = [UIView new];
			UIImageView *tile = [[UIImageView alloc] initWithImage:PUSymbol(symbols[i], 9, UIFontWeightSemibold)];
			tile.tag = 1;
			tile.contentMode = UIViewContentModeCenter;
			tile.tintColor = UIColor.whiteColor;
			tile.backgroundColor = colors[i];
			tile.layer.cornerCurve = kCACornerCurveContinuous;
			UIView *bar = [UIView new];
			bar.tag = 2;
			bar.backgroundColor = UIColor.tertiaryLabelColor;
			[row addSubview:tile];
			[row addSubview:bar];
			[_app addSubview:row];
			[rows addObject:row];
		}
		_sidebarRows = rows;

		_detail = [UIView new];
		_detail.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
		_detail.layer.cornerCurve = kCACornerCurveContinuous;
		[_app addSubview:_detail];
		NSMutableArray *detailRows = [NSMutableArray array];
		for (int i = 0; i < 4; i++) {
			UIView *bar = [UIView new];
			bar.backgroundColor = UIColor.quaternaryLabelColor;
			[_detail addSubview:bar];
			[detailRows addObject:bar];
		}
		_detailRows = detailRows;
	}
	return self;
}

- (void)layoutStage:(CGRect)bounds {
	BOOL pad = PUPrefBool(PUKeyAppsIdiom);
	CGRect frame = PUFit(CGRectInset(bounds, 14, 14), 2.16);
	PULayoutScreen(_screen, frame);
	CGFloat inset = frame.size.height * 0.03;
	_app.frame = CGRectInset(_screen.bounds, inset, inset);
	_app.layer.cornerRadius = _screen.layer.cornerRadius - inset;

	CGRect app = _app.bounds;
	CGFloat top = app.size.height * 0.14;
	CGFloat rowH = (app.size.height - top - 8) / _sidebarRows.count;

	// iPad: sidebar with the list and a detail pane. iPhone: the list fills the screen.
	CGFloat sidebarW = pad ? app.size.width * 0.34 : app.size.width;
	_sidebar.frame = CGRectMake(0, 0, sidebarW, app.size.height);
	_sidebar.alpha = pad ? 1 : 0;
	CGFloat listInset = pad ? 8 : app.size.width * 0.12;

	[_sidebarRows enumerateObjectsUsingBlock:^(UIView *row, NSUInteger i, BOOL *stop) {
		row.frame = CGRectMake(listInset, top + i * rowH, sidebarW - listInset * 2, rowH);
		CGFloat tileSide = rowH * 0.66;
		UIView *tile = [row viewWithTag:1];
		tile.frame = CGRectMake(4, (rowH - tileSide) / 2, tileSide, tileSide);
		tile.layer.cornerRadius = tileSide * 0.25;
		UIView *bar = [row viewWithTag:2];
		CGFloat barH = MAX(2, rowH * 0.16);
		bar.frame = CGRectMake(CGRectGetMaxX(tile.frame) + 6, (rowH - barH) / 2, row.bounds.size.width * (pad ? 0.5 : 0.35), barH);
		bar.layer.cornerRadius = barH / 2;
		row.backgroundColor = (pad && i == 1) ? [UIColor.systemBlueColor colorWithAlphaComponent:0.25] : UIColor.clearColor;
		row.layer.cornerRadius = 6;
	}];

	CGFloat detailX = sidebarW + 12;
	_detail.frame = pad
		? CGRectMake(detailX, top, app.size.width - detailX - 12, rowH * 4)
		: CGRectMake(app.size.width + 12, top, app.size.width * 0.6, rowH * 4);
	_detail.layer.cornerRadius = 10;
	_detail.alpha = pad ? 1 : 0;
	[_detailRows enumerateObjectsUsingBlock:^(UIView *bar, NSUInteger i, BOOL *stop) {
		CGFloat barH = MAX(2, rowH * 0.16);
		bar.frame = CGRectMake(12, rowH * (i + 0.5) - barH / 2, self->_detail.bounds.size.width * (i % 2 ? 0.4 : 0.6), barH);
		bar.layer.cornerRadius = barH / 2;
	}];
}

@end
