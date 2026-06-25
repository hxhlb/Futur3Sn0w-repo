#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <dispatch/dispatch.h>
#import <notify.h>
#import <objc/runtime.h>
#import <fcntl.h>
#import <unistd.h>

static CFStringRef const BFXSpringBoardPreferencesDomain = CFSTR("com.apple.springboard");
static NSString *const BFXSpringBoardPreferencesDirectoryPath = @"/var/mobile/Library/Preferences";
static CFStringRef const BFXPreferencesDomain = CFSTR("com.futur3sn0w.battfx.preferences");
static const char *BFXReloadNotification = "com.futur3sn0w.battfx/ReloadPrefs";

typedef NS_ENUM(NSInteger, BFXStyle) {
	BFXStyle27 = 0,
	BFXStyleJuice = 1,
	BFXStyleOneUI = 2
};

typedef struct {
	BOOL enabled;
	BOOL showsText;
	BFXStyle style;
} BFXConfiguration;

static NSHashTable<UIView *> *BFXTrackedBatteryViews = nil;
static BFXConfiguration BFXCurrentConfiguration = { YES, NO, BFXStyleJuice };
static BOOL BFXLastSeenSystemPercentageValue = NO;
static dispatch_source_t BFXSpringBoardPrefsSource = nil;
static int BFXSpringBoardPrefsFileDescriptor = -1;
static int BFXReloadNotifyToken = 0;

static BOOL BFXClassNameContains(id object, const char *fragment);
static BOOL BFXIsStatusBarBatteryView(UIView *batteryView);
static BOOL BFXShouldRoundBatteryView(UIView *batteryView);
static BOOL BFXIsControlCenterBatteryView(UIView *batteryView);
static BOOL BFXShouldCollapseControlCenterExternalPercentageView(UIView *view);
static void BFXEnumerateSubviews(UIView *view, void (^block)(UIView *subview));
static void BFXEnsureTrackedBatteryView(UIView *batteryView);
static void BFXRefreshTrackedBatteryViews(void);

@interface _UIBatteryView : UIView
- (void)setShowsPercentage:(BOOL)showsPercentage;
- (void)_updatePercentage;
- (void)_updatePercentageFont;
@end

@interface _UIStaticBatteryView : UIView
@end

@interface _UIStatusBarStringView : UIView
@property (nonatomic, copy) NSString *text;
@end

static BOOL BFXPreferenceBool(CFStringRef key, BOOL defaultValue) {
	CFPropertyListRef value = CFPreferencesCopyAppValue(key, BFXPreferencesDomain);
	id bridgedValue = CFBridgingRelease(value);
	if ([bridgedValue respondsToSelector:@selector(boolValue)]) {
		return [bridgedValue boolValue];
	}

	return defaultValue;
}

static NSInteger BFXPreferenceInteger(CFStringRef key, NSInteger defaultValue) {
	CFPropertyListRef value = CFPreferencesCopyAppValue(key, BFXPreferencesDomain);
	id bridgedValue = CFBridgingRelease(value);
	if ([bridgedValue respondsToSelector:@selector(integerValue)]) {
		return [bridgedValue integerValue];
	}

	return defaultValue;
}

static BOOL BFXSystemBatteryPercentageTextEnabled(void) {
	CFPropertyListRef value = CFPreferencesCopyValue(CFSTR("SBShowBatteryPercentage"), BFXSpringBoardPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	id bridgedValue = CFBridgingRelease(value);
	if ([bridgedValue respondsToSelector:@selector(boolValue)]) {
		return [bridgedValue boolValue];
	}

	return NO;
}

static void BFXReloadConfiguration(void) {
	NSInteger rawStyle = BFXPreferenceInteger(CFSTR("Style"), BFXStyleJuice);
	if (rawStyle < BFXStyle27 || rawStyle > BFXStyleOneUI) {
		rawStyle = BFXStyleJuice;
	}

	BFXCurrentConfiguration.enabled = BFXPreferenceBool(CFSTR("Enabled"), YES);
	BFXCurrentConfiguration.showsText = BFXSystemBatteryPercentageTextEnabled();
	BFXCurrentConfiguration.style = (BFXStyle)rawStyle;
}

static BOOL BFXStyleShowsPin(BFXStyle style) {
	return style != BFXStyleOneUI;
}

static void BFXEnumerateSubviews(UIView *view, void (^block)(UIView *subview)) {
	if (!view || !block) {
		return;
	}

	block(view);
	for (UIView *subview in view.subviews) {
		BFXEnumerateSubviews(subview, block);
	}
}

static BOOL BFXClassNameContains(id object, const char *fragment) {
	if (!object || fragment == NULL) {
		return NO;
	}

	const char *className = object_getClassName(object);
	return className != NULL && strstr(className, fragment) != NULL;
}

static BOOL BFXIsStatusBarBatteryView(UIView *batteryView) {
	if (!batteryView) {
		return NO;
	}

	for (UIView *ancestor = batteryView; ancestor != nil; ancestor = ancestor.superview) {
		if (BFXClassNameContains(ancestor, "_UIStatusBar") ||
			BFXClassNameContains(ancestor, "UIStatusBar") ||
			BFXClassNameContains(ancestor, "StatusBar")) {
			return YES;
		}
	}

	return NO;
}

static BOOL BFXShouldRoundBatteryView(UIView *batteryView) {
	if (!batteryView) {
		return NO;
	}

	CGRect bounds = batteryView.bounds;
	CGFloat width = CGRectGetWidth(bounds);
	CGFloat height = CGRectGetHeight(bounds);
	return width >= 20.0 && width <= 52.0 && height >= 10.0 && height <= 24.0;
}

static BOOL BFXIsControlCenterBatteryView(UIView *batteryView) {
	if (!batteryView) {
		return NO;
	}

	if (BFXClassNameContains(batteryView.window, "SBControlCenterWindow")) {
		return YES;
	}

	for (UIView *ancestor = batteryView; ancestor != nil; ancestor = ancestor.superview) {
		if (BFXClassNameContains(ancestor, "CCUIStatusBar") ||
			BFXClassNameContains(ancestor, "CCUIHeaderPocketView") ||
			BFXClassNameContains(ancestor, "ControlCenter")) {
			return YES;
		}
	}

	return NO;
}

static BOOL BFXShouldCollapseControlCenterExternalPercentageView(UIView *view) {
	if (!view ||
		!BFXCurrentConfiguration.enabled ||
		!BFXCurrentConfiguration.showsText ||
		!BFXClassNameContains(view, "StatusBarStringView") ||
		!BFXClassNameContains(view.window, "SBControlCenterWindow")) {
		return NO;
	}

	NSString *text = nil;
	if ([view respondsToSelector:@selector(text)]) {
		text = [(_UIStatusBarStringView *)view text];
	}
	if (text.length == 0 || [text rangeOfString:@"%"].location == NSNotFound) {
		return NO;
	}

	UIView *containerView = view.superview;
	if (!containerView) {
		return NO;
	}

	CGFloat stringMaxX = CGRectGetMaxX(view.frame);
	CGFloat stringMidY = CGRectGetMidY(view.frame);
	for (UIView *candidate in containerView.subviews) {
		if (![candidate isKindOfClass:objc_getClass("_UIStaticBatteryView")]) {
			continue;
		}

		CGRect batteryFrame = candidate.frame;
		BOOL sameRow = fabs(CGRectGetMidY(batteryFrame) - stringMidY) <= MAX(6.0, CGRectGetHeight(view.frame));
		BOOL rightOfString = CGRectGetMinX(batteryFrame) >= stringMaxX - 1.0;
		BOOL nearString = (CGRectGetMinX(batteryFrame) - stringMaxX) <= 48.0;
		if (sameRow && rightOfString && nearString) {
			return YES;
		}
	}

	return NO;
}

static void BFXEnsureTrackedBatteryView(UIView *batteryView) {
	if (!BFXIsStatusBarBatteryView(batteryView)) {
		return;
	}

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		BFXTrackedBatteryViews = [NSHashTable weakObjectsHashTable];
	});

	[BFXTrackedBatteryViews addObject:batteryView];
}

static void BFXTrackStatusBarBatteryViewsInView(UIView *view) {
	if (!view) {
		return;
	}

	Class batteryViewClass = objc_getClass("_UIBatteryView");
	Class staticBatteryViewClass = objc_getClass("_UIStaticBatteryView");
	BFXEnumerateSubviews(view, ^(UIView *subview) {
		if ((batteryViewClass && [subview isKindOfClass:batteryViewClass]) ||
			(staticBatteryViewClass && [subview isKindOfClass:staticBatteryViewClass])) {
			BFXEnsureTrackedBatteryView(subview);
		}
	});
}

static void BFXDiscoverStatusBarBatteryViews(void) {
	if (![NSThread isMainThread]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			BFXDiscoverStatusBarBatteryViews();
		});
		return;
	}

	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) {
			continue;
		}

		UIWindowScene *windowScene = (UIWindowScene *)scene;
		for (UIWindow *window in windowScene.windows) {
			BFXTrackStatusBarBatteryViewsInView(window);
		}
	}
}

static void BFXApplyPercentageTextVisibility(UIView *batteryView) {
	if (!BFXIsStatusBarBatteryView(batteryView) || !BFXCurrentConfiguration.enabled) {
		return;
	}

	BOOL showsText = BFXCurrentConfiguration.showsText;
	BFXEnumerateSubviews(batteryView, ^(UIView *subview) {
		if (![subview isKindOfClass:[UILabel class]]) {
			return;
		}

		subview.hidden = !showsText;
		subview.alpha = showsText ? 1.0 : 0.0;
	});
}

static CGFloat BFXCornerRadiusForHeight(CGFloat height) {
	switch (BFXCurrentConfiguration.style) {
		case BFXStyle27:
			// Fixed radii avoid the visible "snap" into a full pill on tiny battery geometries.
			return height >= 13.0 ? 4.0 : 3.0;
		case BFXStyleJuice:
		case BFXStyleOneUI:
		default:
			return height * 0.5;
	}
}

static BOOL BFXIsModernBatteryPinLayer(CALayer *layer) {
	CGRect frame = layer.frame;
	return CGRectGetWidth(frame) <= 3.0 && CGRectGetHeight(frame) <= 7.0 && CGRectGetHeight(frame) >= 3.0;
}

static void BFXApplyModernBatteryStyle(_UIBatteryView *batteryView) {
	if (!BFXShouldRoundBatteryView((UIView *)batteryView)) {
		return;
	}

	BOOL tweakEnabled = BFXCurrentConfiguration.enabled;
	BOOL showsPin = BFXStyleShowsPin(BFXCurrentConfiguration.style);
	for (CALayer *sublayer in batteryView.layer.sublayers) {
		if (![sublayer isKindOfClass:[CAShapeLayer class]]) {
			continue;
		}

		CAShapeLayer *shapeLayer = (CAShapeLayer *)sublayer;
		if (BFXIsModernBatteryPinLayer(shapeLayer)) {
			shapeLayer.hidden = tweakEnabled && !showsPin;
			if (tweakEnabled && showsPin) {
				shapeLayer.cornerRadius = CGRectGetHeight(shapeLayer.bounds) * 0.5;
				shapeLayer.masksToBounds = YES;
			}
			continue;
		}

		shapeLayer.hidden = NO;
		if (!tweakEnabled || !shapeLayer.path) {
			continue;
		}

		CGRect pathBounds = CGPathGetBoundingBox(shapeLayer.path);
		CGFloat width = CGRectGetWidth(pathBounds);
		CGFloat height = CGRectGetHeight(pathBounds);
		if (width < 18.0 || width > 48.0 || height < 8.0 || height > 22.0) {
			continue;
		}

		CGFloat aspectRatio = height > 0.0 ? (width / height) : 0.0;
		if (aspectRatio < 1.45 || aspectRatio > 2.60) {
			continue;
		}

		CGFloat radius = BFXCornerRadiusForHeight(height);
		UIBezierPath *roundedPath = [UIBezierPath bezierPathWithRoundedRect:pathBounds cornerRadius:radius];
		shapeLayer.path = roundedPath.CGPath;
		shapeLayer.lineJoin = kCALineJoinRound;
	}
}

static BOOL BFXShouldRoundStaticBodyWrapperLayer(CALayer *layer) {
	if (!layer) {
		return NO;
	}

	CGRect frame = layer.frame;
	CGFloat width = CGRectGetWidth(frame);
	CGFloat height = CGRectGetHeight(frame);
	return width >= 28.0 && width <= 32.0 && height >= 13.0 && height <= 15.5;
}

static BOOL BFXShouldRoundStaticInnerFillLayer(CALayer *layer) {
	if (!layer) {
		return NO;
	}

	CGRect frame = layer.frame;
	CGFloat width = CGRectGetWidth(frame);
	CGFloat height = CGRectGetHeight(frame);
	return width >= 23.0 && width <= 26.5 && height >= 13.0 && height <= 15.5;
}

static BOOL BFXShouldRoundStaticPinLayer(CALayer *layer) {
	if (!layer) {
		return NO;
	}

	CGRect frame = layer.frame;
	CGFloat width = CGRectGetWidth(frame);
	CGFloat height = CGRectGetHeight(frame);
	return width >= 1.0 && width <= 2.5 && height >= 4.0 && height <= 6.5;
}

static CALayer *BFXFindStaticBodyWrapperLayer(CALayer *rootLayer) {
	for (CALayer *candidate in rootLayer.sublayers) {
		if (BFXShouldRoundStaticBodyWrapperLayer(candidate)) {
			return candidate;
		}
	}

	return nil;
}

static CALayer *BFXFindStaticInnerFillLayer(CALayer *wrapperLayer) {
	for (CALayer *candidate in wrapperLayer.sublayers) {
		if (BFXShouldRoundStaticInnerFillLayer(candidate)) {
			return candidate;
		}
	}

	return nil;
}

static CALayer *BFXFindStaticPinLayer(CALayer *rootLayer) {
	for (CALayer *candidate in rootLayer.sublayers) {
		if (BFXShouldRoundStaticPinLayer(candidate)) {
			return candidate;
		}
	}

	return nil;
}

static void BFXApplyStaticBatteryStyle(CALayer *rootLayer) {
	if (!rootLayer) {
		return;
	}

	CALayer *wrapperLayer = BFXFindStaticBodyWrapperLayer(rootLayer);
	CALayer *fillLayer = wrapperLayer ? BFXFindStaticInnerFillLayer(wrapperLayer) : nil;
	CALayer *pinLayer = BFXFindStaticPinLayer(rootLayer);
	BOOL tweakEnabled = BFXCurrentConfiguration.enabled;
	BOOL showsPin = BFXStyleShowsPin(BFXCurrentConfiguration.style);

	if (pinLayer) {
		pinLayer.hidden = tweakEnabled && !showsPin;
		if (tweakEnabled && showsPin) {
			pinLayer.cornerRadius = CGRectGetHeight(pinLayer.bounds) * 0.5;
			pinLayer.masksToBounds = YES;
		} else {
			pinLayer.cornerRadius = 0.0;
			pinLayer.masksToBounds = NO;
		}
	}

	if (!wrapperLayer) {
		return;
	}

	if (!tweakEnabled || !fillLayer) {
		wrapperLayer.mask = nil;
		return;
	}

	CGFloat bodyHeight = CGRectGetHeight(wrapperLayer.bounds);
	CGFloat bodyWidth = CGRectGetWidth(wrapperLayer.bounds);
	if (pinLayer) {
		CGFloat pinMinX = CGRectGetMinX(pinLayer.frame);
		bodyWidth = MAX(CGRectGetWidth(fillLayer.frame), pinMinX - 1.0);
	}

	CGRect bodyRect = CGRectMake(0.0, 0.0, MIN(bodyWidth, CGRectGetWidth(wrapperLayer.bounds)), bodyHeight);
	CGFloat radius = BFXCornerRadiusForHeight(bodyHeight);
	UIBezierPath *roundedPath = [UIBezierPath bezierPathWithRoundedRect:bodyRect cornerRadius:radius];
	CAShapeLayer *maskLayer = [wrapperLayer.mask isKindOfClass:[CAShapeLayer class]] ? (CAShapeLayer *)wrapperLayer.mask : nil;
	if (!maskLayer) {
		maskLayer = [CAShapeLayer layer];
		wrapperLayer.mask = maskLayer;
	}
	maskLayer.frame = wrapperLayer.bounds;
	maskLayer.path = roundedPath.CGPath;

	fillLayer.cornerRadius = 0.0;
	fillLayer.masksToBounds = YES;
}

static void BFXApplyControlCenterExternalPercentageVisibility(_UIStaticBatteryView *batteryView) {
	if (!batteryView || !BFXIsControlCenterBatteryView((UIView *)batteryView)) {
		return;
	}

	UIView *containerView = batteryView.superview;
	if (!containerView) {
		return;
	}

	BOOL shouldHide = BFXCurrentConfiguration.enabled && BFXCurrentConfiguration.showsText;
	CGFloat batteryMinX = CGRectGetMinX(batteryView.layer.frame);
	CGFloat batteryMidY = CGRectGetMidY(batteryView.layer.frame);

	for (UIView *candidate in containerView.subviews) {
		if (candidate == (UIView *)batteryView || !BFXClassNameContains(candidate, "StatusBarStringView")) {
			continue;
		}

		CGRect frame = candidate.frame;
		BOOL sameRow = fabs(CGRectGetMidY(frame) - batteryMidY) <= MAX(6.0, CGRectGetHeight(frame));
		BOOL leftOfBattery = CGRectGetMaxX(frame) <= batteryMinX + 1.0;
		BOOL nearBattery = (batteryMinX - CGRectGetMaxX(frame)) <= 48.0;
		if (!sameRow || !leftOfBattery || !nearBattery) {
			continue;
		}

		if (shouldHide) {
			candidate.hidden = YES;
			candidate.alpha = 0.0;
		} else {
			candidate.hidden = NO;
			candidate.alpha = 1.0;
		}
	}

	[containerView setNeedsLayout];
	[containerView layoutIfNeeded];
}

static void BFXNudgeBatteryViewForDisplay(UIView *batteryView) {
	if (!batteryView) {
		return;
	}

	[batteryView setNeedsLayout];
	[batteryView layoutIfNeeded];
	[batteryView setNeedsDisplay];
	[batteryView.layer setNeedsDisplay];
}

static void BFXRefreshModernBatteryView(_UIBatteryView *batteryView) {
	if (!BFXIsStatusBarBatteryView((UIView *)batteryView)) {
		return;
	}

	BOOL showsPercentage = BFXCurrentConfiguration.enabled ? YES : BFXCurrentConfiguration.showsText;
	[batteryView setShowsPercentage:showsPercentage];
	if ([batteryView respondsToSelector:@selector(_updatePercentage)]) {
		[batteryView _updatePercentage];
	}
	if ([batteryView respondsToSelector:@selector(_updatePercentageFont)]) {
		[batteryView _updatePercentageFont];
	}
	BFXApplyModernBatteryStyle(batteryView);
	BFXApplyPercentageTextVisibility((UIView *)batteryView);
	BFXNudgeBatteryViewForDisplay((UIView *)batteryView);
}

static void BFXRefreshStaticBatteryView(_UIStaticBatteryView *batteryView) {
	if (!BFXIsStatusBarBatteryView((UIView *)batteryView)) {
		return;
	}

	BFXApplyStaticBatteryStyle(batteryView.layer);
	BFXApplyControlCenterExternalPercentageVisibility(batteryView);
	BFXNudgeBatteryViewForDisplay((UIView *)batteryView);
}

static void BFXRefreshTrackedBatteryViews(void) {
	if (![NSThread isMainThread]) {
		dispatch_async(dispatch_get_main_queue(), ^{
			BFXRefreshTrackedBatteryViews();
		});
		return;
	}

	BFXDiscoverStatusBarBatteryViews();

	Class batteryViewClass = objc_getClass("_UIBatteryView");
	Class staticBatteryViewClass = objc_getClass("_UIStaticBatteryView");
	for (UIView *batteryView in BFXTrackedBatteryViews) {
		if (batteryViewClass && [batteryView isKindOfClass:batteryViewClass]) {
			BFXRefreshModernBatteryView((_UIBatteryView *)batteryView);
			continue;
		}
		if (staticBatteryViewClass && [batteryView isKindOfClass:staticBatteryViewClass]) {
			BFXRefreshStaticBatteryView((_UIStaticBatteryView *)batteryView);
		}
	}
}

@interface BFXObserver : NSObject
@end

@implementation BFXObserver

- (instancetype)init {
	self = [super init];
	if (!self) {
		return nil;
	}

	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(handleRefreshNotification:) name:UIApplicationDidBecomeActiveNotification object:nil];
	[center addObserver:self selector:@selector(handleRefreshNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];
	[center addObserver:self selector:@selector(handleRefreshNotification:) name:NSUserDefaultsDidChangeNotification object:nil];
	return self;
}

- (void)handleRefreshNotification:(__unused NSNotification *)notification {
	BFXReloadConfiguration();
	BFXRefreshTrackedBatteryViews();
}

@end

static void BFXHandleSystemPreferenceFileChange(void) {
	BOOL currentSystemValue = BFXSystemBatteryPercentageTextEnabled();
	if (currentSystemValue == BFXLastSeenSystemPercentageValue) {
		return;
	}

	BFXLastSeenSystemPercentageValue = currentSystemValue;
	BFXReloadConfiguration();
	BFXRefreshTrackedBatteryViews();
}

static void BFXStartSpringBoardPreferenceWatcher(void) {
	if (BFXSpringBoardPrefsSource != nil) {
		return;
	}

	BFXSpringBoardPrefsFileDescriptor = open(BFXSpringBoardPreferencesDirectoryPath.fileSystemRepresentation, O_EVTONLY);
	if (BFXSpringBoardPrefsFileDescriptor < 0) {
		return;
	}

	unsigned long mask = DISPATCH_VNODE_WRITE | DISPATCH_VNODE_DELETE | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_ATTRIB;
	BFXSpringBoardPrefsSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, (uintptr_t)BFXSpringBoardPrefsFileDescriptor, mask, dispatch_get_main_queue());
	if (BFXSpringBoardPrefsSource == nil) {
		close(BFXSpringBoardPrefsFileDescriptor);
		BFXSpringBoardPrefsFileDescriptor = -1;
		return;
	}

	dispatch_source_set_event_handler(BFXSpringBoardPrefsSource, ^{
		BFXHandleSystemPreferenceFileChange();
	});

	dispatch_source_set_cancel_handler(BFXSpringBoardPrefsSource, ^{
		if (BFXSpringBoardPrefsFileDescriptor >= 0) {
			close(BFXSpringBoardPrefsFileDescriptor);
			BFXSpringBoardPrefsFileDescriptor = -1;
		}
	});

	dispatch_resume(BFXSpringBoardPrefsSource);
}

static void BFXStartReloadNotificationObserver(void) {
	if (BFXReloadNotifyToken != 0) {
		return;
	}

	notify_register_dispatch(BFXReloadNotification, &BFXReloadNotifyToken, dispatch_get_main_queue(), ^(__unused int token) {
		BFXReloadConfiguration();
		BFXRefreshTrackedBatteryViews();
	});
}

%group BattFXBatteryHooks
%hook _UIBatteryView

- (void)setShowsPercentage:(BOOL)showsPercentage {
	BOOL effectiveShowsPercentage = BFXCurrentConfiguration.enabled ? YES : showsPercentage;
	%orig(effectiveShowsPercentage);
	BFXEnsureTrackedBatteryView((UIView *)self);
	BFXApplyModernBatteryStyle(self);
	BFXApplyPercentageTextVisibility((UIView *)self);
}

- (void)didMoveToWindow {
	%orig;
	BFXEnsureTrackedBatteryView((UIView *)self);
	BFXApplyModernBatteryStyle(self);
	BFXApplyPercentageTextVisibility((UIView *)self);
}

- (void)layoutSubviews {
	%orig;
	BFXEnsureTrackedBatteryView((UIView *)self);
	BFXApplyModernBatteryStyle(self);
	BFXApplyPercentageTextVisibility((UIView *)self);
}

- (void)_updatePercentage {
	%orig;
}

- (void)_updatePercentageFont {
	%orig;
	BFXApplyPercentageTextVisibility((UIView *)self);
}

- (UIColor *)_batteryTextColor {
	UIColor *originalColor = %orig;
	if (!BFXCurrentConfiguration.enabled || BFXCurrentConfiguration.showsText) {
		return originalColor;
	}

	return [originalColor colorWithAlphaComponent:0.0];
}

%end

%hook _UIStaticBatteryView

- (void)didMoveToWindow {
	%orig;
	BFXEnsureTrackedBatteryView((UIView *)self);
	BFXApplyStaticBatteryStyle(self.layer);
	BFXApplyControlCenterExternalPercentageVisibility(self);
}

- (void)layoutSubviews {
	%orig;
	BFXEnsureTrackedBatteryView((UIView *)self);
	BFXApplyStaticBatteryStyle(self.layer);
	BFXApplyControlCenterExternalPercentageVisibility(self);
}

%end

%hook _UIStatusBarStringView

- (CGSize)sizeThatFits:(CGSize)size {
	if (BFXShouldCollapseControlCenterExternalPercentageView((UIView *)self)) {
		return CGSizeZero;
	}

	return %orig(size);
}

- (CGSize)intrinsicContentSize {
	if (BFXShouldCollapseControlCenterExternalPercentageView((UIView *)self)) {
		return CGSizeZero;
	}

	return %orig;
}

- (void)layoutSubviews {
	%orig;
	if (BFXShouldCollapseControlCenterExternalPercentageView((UIView *)self)) {
		self.hidden = YES;
		self.alpha = 0.0;
	} else {
		self.hidden = NO;
		self.alpha = 1.0;
	}
}

%end
%end

%ctor {
	BFXLastSeenSystemPercentageValue = BFXSystemBatteryPercentageTextEnabled();
	BFXReloadConfiguration();

	Class batteryViewClass = objc_getClass("_UIBatteryView");
	Class staticBatteryViewClass = objc_getClass("_UIStaticBatteryView");
	if (batteryViewClass &&
		class_getInstanceMethod(batteryViewClass, @selector(setShowsPercentage:)) &&
		class_getInstanceMethod(batteryViewClass, @selector(layoutSubviews)) &&
		staticBatteryViewClass &&
		class_getInstanceMethod(staticBatteryViewClass, @selector(didMoveToWindow))) {
		%init(BattFXBatteryHooks);
	}

	BFXStartSpringBoardPreferenceWatcher();
	BFXStartReloadNotificationObserver();

	__unused static BFXObserver *observer = nil;
	observer = [[BFXObserver alloc] init];
}
