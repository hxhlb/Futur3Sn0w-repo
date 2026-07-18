#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <FrontBoardServices/FBSSystemService.h>
#import <MobileCoreServices/LSApplicationWorkspace.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import <QuartzCore/QuartzCore.h>

static BOOL S15HEMIsSpringBoard(void) {
    static BOOL result, checked;
    if (!checked) {
        result = [NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.springboard"];
        checked = YES;
    }
    return result;
}

static void *kS15HEMActiveSheetKey = &kS15HEMActiveSheetKey;
static void *kS15HEMSheetPresentationWindowKey = &kS15HEMSheetPresentationWindowKey;
static void *kS15HEMWallpaperDimOverlayKey = &kS15HEMWallpaperDimOverlayKey;
static void *kS15HEMLastAppliedIconModeKey = &kS15HEMLastAppliedIconModeKey;
static void *kS15HEMApplyingManagedTransformKey = &kS15HEMApplyingManagedTransformKey;
static void *kS15HEMApplyingManagedAlphaKey = &kS15HEMApplyingManagedAlphaKey;
static NSString *const kS15HEMTransitionProbePath = @"/var/mobile/Documents/CustHome-transition-probe.log";
static NSUInteger sS15HEMTransitionProbeCount = 0;
static CFTimeInterval sS15HEMTransitionProbeStart = 0;
static BOOL sS15HEMLoggedIconLayoutSample = NO;
static BOOL sS15HEMLoggedImageLayoutSample = NO;

static NSString *const kS15HEMPrefsDomain = @"com.futur3sn0w.custhome";
static NSString *const kS15HEMEnabledKey = @"CustHomeEnabled";
static NSString *const kS15HEMAppearanceControlModeKey = @"CustHomeAppearanceControlMode";
static NSString *const kS15HEMIconSizeKey = @"CustomizeIconSizeMode";
static NSString *const kS15HEMWallpaperDimmingKey = @"CustomizeWallpaperDimmingMode";
static NSString *const kS15HEMAppearanceModeKey = @"CustomizeAppearanceMode";
static NSString *const kS15HEMWeatherHueKey = @"CustomizeWeatherHueValue";
static NSString *const kS15HEMWeatherBrightnessKey = @"CustomizeWeatherBrightnessValue";
static NSString *const kS15HEMSystemAppearanceDomain = @"com.apple.uikitservices.userInterfaceStyleMode";
static NSString *const kS15HEMSystemAppearanceModeValueKey = @"UserInterfaceStyleMode";
static NSString *const kS15HEMSystemMostRecentAutomaticModeKey = @"MostRecentAutomaticMode";
static const CGFloat kS15HEMEditingLabelFontDelta = -1.0;
static const CGFloat kS15HEMEditingLabelXOffset = 0.0;
static const CGFloat kS15HEMEditingLabelYOffset = 0.0;

static UIWindow *S15HEMHomeScreenWindow(void);

static NSArray<UIWindow *> *S15HEMAllWindows(void);
static void S15HEMApplyWallpaperDimmingToHomeScreen(void);
static void S15HEMApplyIconAppearanceToAllVisibleViews(BOOL animated);
static void S15HEMApplyAppearanceModeToSpringBoard(void);
static void S15HEMApplyAllCurrentSettings(void);
static void S15HEMRefreshHomeScreenIconLists(BOOL animated);
static void S15HEMApplyIconAppearanceInContainer(UIView *container, BOOL animated);
static void S15HEMHandleHomeScreenTraitChange(UITraitCollection *previousTraitCollection, UITraitCollection *currentTraitCollection);
static UIUserInterfaceStyle S15HEMResolvedSystemInterfaceStyle(void);
static UIView *S15HEMDirectIconImageView(UIView *iconView);
static UIView *S15HEMNearestIconViewForView(UIView *view);
static void S15HEMAppendTransitionProbe(NSString *phase, UIView *view, NSString *details);
static void S15HEMAppendTransitionProbeMessage(NSString *phase, NSString *details);
static void S15HEMLogVisibleIconHierarchySample(void);
static void S15HEMLogIOS15CompatibilityProbe(UIView *editingButton);
static BOOL S15HEMClassNameLooksLikeIconView(NSString *className);
static void S15HEMInstallWallpaperModalHooks(void);
static BOOL S15HEMLoadWallpaperSettingsFramework(void);
static void S15HEMRetainWallpaperModalController(id modalController);
static void S15HEMHandleWallpaperModalWillDismiss(id modalController, id response);
static void S15HEMHandleWallpaperModalDidDismiss(id modalController, id response);
static void S15HEMConfigureEditingWidgetButton(UIButton *button);
static void S15HEMUpdateEditingWidgetButtonVisuals(UIButton *button);
static void S15HEMUpdateAllEditingWidgetButtonVisuals(void);
static UILabel *S15HEMFindDoneLabelForEditingButton(UIButton *editButton);
static CGRect S15HEMExpandedEditingWidgetHitFrame(UIButton *button);

typedef NS_ENUM(NSInteger, S15HEMIconSizeMode) {
    S15HEMIconSizeModeSmall = 0,
    S15HEMIconSizeModeLarge = 1,
};

// Matches the real OS: wallpaper dimming is a plain on/off toggle, there is
// no "Auto" tri-state. (An earlier build here had an Auto mode that doesn't
// exist in the actual Settings UI — removed for fidelity.)
typedef NS_ENUM(NSInteger, S15HEMWallpaperDimmingMode) {
    S15HEMWallpaperDimmingModeOff = 0,
    S15HEMWallpaperDimmingModeOn = 1,
};

typedef NS_ENUM(NSInteger, S15HEMAppearanceMode) {
    S15HEMAppearanceModeLight = 0,
    S15HEMAppearanceModeDark = 1,
    S15HEMAppearanceModeAutomatic = 2,
    S15HEMAppearanceModeTinted = 3,
};

typedef NS_ENUM(NSInteger, S15HEMAppearanceControlMode) {
    S15HEMAppearanceControlModeSystemAppearance = 0,
    S15HEMAppearanceControlModeIconAppearanceOnly = 1,
};

static S15HEMAppearanceMode S15HEMAppearanceModePreference(void);
static void S15HEMAppearanceModeSetPreference(S15HEMAppearanceMode mode);

static BOOL S15HEMClassNameLooksLikeIconView(NSString *className) {
    if (className.length == 0) return NO;
    if (![className containsString:@"IconView"]) return NO;
    if ([className containsString:@"ImageView"]) return NO;
    return YES;
}

@interface S15HEMAppearanceButton : UIButton
@end

@implementation S15HEMAppearanceButton
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return [super pointInside:point withEvent:event];
}
@end

// Small circular "fill gauge" for the wallpaper-dimming glyph: 0 = blank,
// 0.5 = left half filled (there's no 1.0/full state in practice anymore —
// dimming is a plain on/off toggle matching the real OS, and "on" shows the
// half fill). The fill is left-anchored and grows left-to-right as
// _displayedFraction goes 0→1, so animating back down to 0 reads as the
// fill sliding back out to the left, matching the real Settings toggle.
//
// This used to be two plain UIViews (a circular masksToBounds container plus
// a rectangular fill pinned via Auto Layout). At a 6-8pt size that produced
// visible artifacts — a blurry, oval-looking half state and a 1-2pt gap at
// full fill — from sub-pixel Auto Layout frames interacting with a
// CALayer.cornerRadius clip. Drawing it directly with Core Graphics (exact
// ellipse fill + rect clip, both resolved at full device pixel scale) avoids
// that entirely. A CADisplayLink drives the grow/shrink animation between
// states without needing a custom animatable CALayer property.
@interface S15HEMSunGaugeView : UIView
@property (nonatomic, assign) CGFloat fillFraction; // 0...1, no animation
- (void)setFillFraction:(CGFloat)fillFraction animated:(BOOL)animated;
@end

@implementation S15HEMSunGaugeView {
    CGFloat _displayedFraction;
    CADisplayLink *_displayLink;
    CGFloat _animStartFraction;
    CGFloat _animTargetFraction;
    CFTimeInterval _animStartTime;
    NSTimeInterval _animDuration;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.contentMode = UIViewContentModeRedraw;
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)setFillFraction:(CGFloat)fillFraction {
    [self setFillFraction:fillFraction animated:NO];
}

- (void)setFillFraction:(CGFloat)fillFraction animated:(BOOL)animated {
    fillFraction = MAX(0.0, MIN(1.0, fillFraction));
    _fillFraction = fillFraction;

    if (!animated) {
        _displayLink.paused = YES;
        _displayedFraction = fillFraction;
        [self setNeedsDisplay];
        return;
    }

    _animStartFraction = _displayedFraction;
    _animTargetFraction = fillFraction;
    _animStartTime = CACurrentMediaTime();
    _animDuration = 0.22;
    if (!_displayLink) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleDisplayLink:)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    _displayLink.paused = NO;
}

- (void)handleDisplayLink:(CADisplayLink *)link {
    (void)link;
    CFTimeInterval elapsed = CACurrentMediaTime() - _animStartTime;
    CGFloat t = _animDuration > 0.0 ? MIN(1.0, elapsed / _animDuration) : 1.0;
    CGFloat eased = 1.0 - pow(1.0 - t, 3.0); // ease-out cubic
    _displayedFraction = _animStartFraction + (_animTargetFraction - _animStartFraction) * eased;
    [self setNeedsDisplay];
    if (t >= 1.0) {
        _displayedFraction = _animTargetFraction;
        [self setNeedsDisplay];
        _displayLink.paused = YES;
    }
}

- (void)tintColorDidChange {
    [super tintColorDidChange];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    (void)rect;
    if (_displayedFraction <= 0.001) return; // blank/off — draw nothing at all

    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGRect bounds = self.bounds;
    CGFloat diameter = MIN(bounds.size.width, bounds.size.height);
    CGRect circleRect = CGRectMake((bounds.size.width - diameter) / 2.0,
                                    (bounds.size.height - diameter) / 2.0,
                                    diameter, diameter);

    // Left-anchored: the visible fill always starts at the circle's left
    // edge and its width grows with _displayedFraction, so shrinking back to
    // 0 reads as the fill sliding out past the left edge (matching the real
    // Settings toggle's off animation) rather than shrinking in place.
    CGContextSaveGState(ctx);
    CGRect clipRect = CGRectMake(CGRectGetMinX(circleRect), CGRectGetMinY(circleRect), diameter * _displayedFraction, diameter);
    CGContextClipToRect(ctx, clipRect);
    CGContextSetFillColorWithColor(ctx, self.tintColor.CGColor);
    CGContextFillEllipseInRect(ctx, circleRect);
    CGContextRestoreGState(ctx);
}

@end

@interface S15HEMCustomizeSheetView : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIControl *dimmingView;
@property (nonatomic, strong) UIVisualEffectView *sheetView;
@property (nonatomic, strong) UIView *grabberView;
@property (nonatomic, strong) UIButton *dimmingModeButton;
@property (nonatomic, strong) UIImageView *dimmingSunGlyphView;
@property (nonatomic, strong) S15HEMSunGaugeView *dimmingGaugeView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UISegmentedControl *iconSizeControl;
@property (nonatomic, strong) UILabel *iconSizeDetailLabel;
@property (nonatomic, strong) UILabel *wallpaperTitleLabel;
@property (nonatomic, strong) UILabel *wallpaperDetailLabel;
@property (nonatomic, strong) UIView *headerRow;
@property (nonatomic, strong) UIView *appearanceRow;
@property (nonatomic, strong) UIView *sliderSection;
@property (nonatomic, strong) NSArray<UIButton *> *appearanceButtons;
@property (nonatomic, strong) UIButton *brushButton;
@property (nonatomic, strong) UIView *hueTrackView;
@property (nonatomic, strong) UIView *hueThumbView;
@property (nonatomic, strong) UIView *brightnessTrackView;
@property (nonatomic, strong) UIView *brightnessThumbView;
@property (nonatomic, assign) CGFloat restingY;
@property (nonatomic, assign) BOOL dismissing;
- (void)presentAnimated;
- (void)dismissAnimated;
@end

// Ground truth for both of these came from a headers dump on the test device
// (UIKitServices.framework / UIKitCore.framework, iOS 16.0 scope). The mode
// object internally observes the backing defaults (`_observingDefaults`) and
// calls the delegate back on change — that delegate callback, not KVO on
// modeValue, is the documented way to learn about an external appearance
// change (Settings.app, Control Center, Shortcuts, etc).
@protocol S15HEMUISUserInterfaceStyleModeDelegate <NSObject>
- (void)userInterfaceStyleModeDidChange:(id)mode;
@end

@interface UISUserInterfaceStyleMode : NSObject
@property (nonatomic) NSInteger modeValue;
@property (readonly, nonatomic) NSInteger suggestedAutomaticModeValue;
- (id)initWithDelegate:(id<S15HEMUISUserInterfaceStyleModeDelegate> _Nullable)delegate;
@end

static S15HEMIconSizeMode S15HEMIconSizePreference(void) {
    NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:kS15HEMIconSizeKey];
    return value == S15HEMIconSizeModeLarge ? S15HEMIconSizeModeLarge : S15HEMIconSizeModeSmall;
}

static void S15HEMSetIconSizePreference(S15HEMIconSizeMode mode) {
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:kS15HEMIconSizeKey];
}

static S15HEMWallpaperDimmingMode S15HEMWallpaperDimmingPreference(void) {
    NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:kS15HEMWallpaperDimmingKey];
    if (value != S15HEMWallpaperDimmingModeOn && value != S15HEMWallpaperDimmingModeOff) {
        return S15HEMWallpaperDimmingModeOff;
    }
    return (S15HEMWallpaperDimmingMode)value;
}

static void S15HEMSetWallpaperDimmingPreference(S15HEMWallpaperDimmingMode mode) {
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:kS15HEMWallpaperDimmingKey];
}

static BOOL S15HEMEnabledPreference(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kS15HEMEnabledKey] == nil) return YES;
    return [defaults boolForKey:kS15HEMEnabledKey];
}

static S15HEMAppearanceControlMode S15HEMAppearanceControlModePreference(void) {
    NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:kS15HEMAppearanceControlModeKey];
    return value == S15HEMAppearanceControlModeIconAppearanceOnly
        ? S15HEMAppearanceControlModeIconAppearanceOnly
        : S15HEMAppearanceControlModeSystemAppearance;
}

static BOOL S15HEMAppearanceButtonsDriveSystemAppearance(void) {
    if (!S15HEMEnabledPreference()) return NO;
    return S15HEMAppearanceControlModePreference() == S15HEMAppearanceControlModeSystemAppearance;
}

static NSInteger S15HEMCurrentSystemAppearanceModeValue(void) {
    Class styleModeClass = NSClassFromString(@"UISUserInterfaceStyleMode");
    if (styleModeClass) {
        @try {
            SEL initSel = NSSelectorFromString(@"initWithDelegate:");
            UISUserInterfaceStyleMode *styleMode = ((id (*)(id, SEL, id))objc_msgSend)([styleModeClass alloc], initSel, nil);
            if ([styleMode respondsToSelector:@selector(modeValue)]) {
                return styleMode.modeValue;
            }
        } @catch (__unused NSException *exception) {
        }
    }

    CFPropertyListRef rawValue = CFPreferencesCopyAppValue((CFStringRef)kS15HEMSystemAppearanceModeValueKey,
                                                           (CFStringRef)kS15HEMSystemAppearanceDomain);
    if (rawValue) {
        NSInteger value = [(__bridge id)rawValue integerValue];
        CFRelease(rawValue);
        return value;
    }

    return 100;
}

static NSInteger S15HEMSuggestedAutomaticSystemAppearanceModeValue(void) {
    Class styleModeClass = NSClassFromString(@"UISUserInterfaceStyleMode");
    if (styleModeClass) {
        @try {
            SEL initSel = NSSelectorFromString(@"initWithDelegate:");
            UISUserInterfaceStyleMode *styleMode = ((id (*)(id, SEL, id))objc_msgSend)([styleModeClass alloc], initSel, nil);
            if ([styleMode respondsToSelector:@selector(suggestedAutomaticModeValue)]) {
                NSInteger value = styleMode.suggestedAutomaticModeValue;
                if (value != 0) return value;
            }
        } @catch (__unused NSException *exception) {
        }
    }

    CFPropertyListRef rawValue = CFPreferencesCopyAppValue((CFStringRef)kS15HEMSystemMostRecentAutomaticModeKey,
                                                           (CFStringRef)kS15HEMSystemAppearanceDomain);
    if (rawValue) {
        NSInteger value = [(__bridge id)rawValue integerValue];
        CFRelease(rawValue);
        if (value != 0) return value;
    }

    return 100;
}

static S15HEMAppearanceMode S15HEMAppearanceModeForSystemModeValue(NSInteger value) {
    if (value == UIUserInterfaceStyleLight) return S15HEMAppearanceModeLight;
    if (value == UIUserInterfaceStyleDark) return S15HEMAppearanceModeDark;
    return S15HEMAppearanceModeAutomatic;
}

static NSInteger S15HEMSystemModeValueForAppearanceMode(S15HEMAppearanceMode mode) {
    switch (mode) {
        case S15HEMAppearanceModeLight:
            return UIUserInterfaceStyleLight;
        case S15HEMAppearanceModeDark:
            return UIUserInterfaceStyleDark;
        case S15HEMAppearanceModeAutomatic:
            return S15HEMSuggestedAutomaticSystemAppearanceModeValue();
        case S15HEMAppearanceModeTinted:
            break;
    }
    return S15HEMCurrentSystemAppearanceModeValue();
}

static BOOL S15HEMSetSystemAppearanceModeValue(NSInteger modeValue) {
    Class styleModeClass = NSClassFromString(@"UISUserInterfaceStyleMode");
    if (styleModeClass) {
        @try {
            SEL initSel = NSSelectorFromString(@"initWithDelegate:");
            UISUserInterfaceStyleMode *styleMode = ((id (*)(id, SEL, id))objc_msgSend)([styleModeClass alloc], initSel, nil);
            if ([styleMode respondsToSelector:@selector(setModeValue:)]) {
                styleMode.modeValue = modeValue;
                return YES;
            }
        } @catch (__unused NSException *exception) {
        }
    }

    CFPreferencesSetAppValue((CFStringRef)kS15HEMSystemAppearanceModeValueKey,
                             (__bridge CFPropertyListRef)@(modeValue),
                             (CFStringRef)kS15HEMSystemAppearanceDomain);
    if (modeValue >= 100) {
        CFPreferencesSetAppValue((CFStringRef)kS15HEMSystemMostRecentAutomaticModeKey,
                                 (__bridge CFPropertyListRef)@(modeValue),
                                 (CFStringRef)kS15HEMSystemAppearanceDomain);
    }
    return CFPreferencesAppSynchronize((CFStringRef)kS15HEMSystemAppearanceDomain);
}

static void S15HEMRefreshActiveSheetControlStateAnimated(BOOL animated) {
    UIWindow *window = S15HEMHomeScreenWindow();
    if (!window) return;
    id sheet = objc_getAssociatedObject(window, kS15HEMActiveSheetKey);
    if (!sheet || ![sheet respondsToSelector:@selector(refreshControlStateAnimated:)]) return;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(sheet, @selector(refreshControlStateAnimated:), animated);
}

static void S15HEMSynchronizeAppearancePreferenceFromSystemIfNeeded(void) {
    if (!S15HEMAppearanceButtonsDriveSystemAppearance()) return;
    S15HEMAppearanceMode currentMode = S15HEMAppearanceModePreference();
    if (currentMode == S15HEMAppearanceModeTinted) return;

    S15HEMAppearanceMode systemMode = S15HEMAppearanceModeForSystemModeValue(S15HEMCurrentSystemAppearanceModeValue());
    if (systemMode != currentMode) {
        S15HEMAppearanceModeSetPreference(systemMode);
    }
}

static CGFloat S15HEMCurrentIconScale(void) {
    return S15HEMIconSizePreference() == S15HEMIconSizeModeLarge ? 1.12 : 1.0;
}

static NSString *S15HEMShortViewSummary(UIView *view) {
    if (!view) return @"(nil)";
    return [NSString stringWithFormat:@"%@ frame=%@ alpha=%.2f hidden=%d",
            NSStringFromClass(view.class),
            NSStringFromCGRect(view.frame),
            view.alpha,
            view.hidden ? 1 : 0];
}

static NSString *S15HEMViewChainSummary(UIView *view, NSUInteger limit) {
    if (!view) return @"(nil)";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    UIView *current = view;
    NSUInteger depth = 0;
    while (current && depth < limit) {
        [parts addObject:S15HEMShortViewSummary(current)];
        current = current.superview;
        depth++;
    }
    return [parts componentsJoinedByString:@" <- "];
}

static void S15HEMAppendTransitionProbe(NSString *phase, UIView *view, NSString *details) {
    if (!view || sS15HEMTransitionProbeCount >= 250) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSFileManager defaultManager] removeItemAtPath:kS15HEMTransitionProbePath error:nil];
        sS15HEMTransitionProbeStart = CACurrentMediaTime();
    });

    sS15HEMTransitionProbeCount++;
    CFTimeInterval now = CACurrentMediaTime();
    CFTimeInterval elapsed = sS15HEMTransitionProbeStart > 0 ? (now - sS15HEMTransitionProbeStart) : 0;
    UIView *iconView = S15HEMNearestIconViewForView(view);
    NSString *line = [NSString stringWithFormat:@"t=%.3f %lu %@ view={%@} icon={%@} chain=%@ %@\n",
                      elapsed,
                      (unsigned long)sS15HEMTransitionProbeCount,
                      phase ?: @"(null)",
                      S15HEMShortViewSummary(view),
                      S15HEMShortViewSummary(iconView),
                      S15HEMViewChainSummary(view, 5),
                      details ?: @""];

    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    if (!data.length) return;
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:kS15HEMTransitionProbePath]) {
        [manager createFileAtPath:kS15HEMTransitionProbePath contents:nil attributes:nil];
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kS15HEMTransitionProbePath];
    if (!handle) return;
    [handle seekToEndOfFile];
    [handle writeData:data];
    [handle closeFile];
}

static void S15HEMAppendTransitionProbeMessage(NSString *phase, NSString *details) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSFileManager defaultManager] removeItemAtPath:kS15HEMTransitionProbePath error:nil];
        sS15HEMTransitionProbeStart = CACurrentMediaTime();
    });

    CFTimeInterval now = CACurrentMediaTime();
    CFTimeInterval elapsed = sS15HEMTransitionProbeStart > 0 ? (now - sS15HEMTransitionProbeStart) : 0;
    NSString *line = [NSString stringWithFormat:@"t=%.3f %@ %@\n",
                      elapsed,
                      phase ?: @"(null)",
                      details ?: @""];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    if (!data.length) return;
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:kS15HEMTransitionProbePath]) {
        [manager createFileAtPath:kS15HEMTransitionProbePath contents:nil attributes:nil];
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kS15HEMTransitionProbePath];
    if (!handle) return;
    [handle seekToEndOfFile];
    [handle writeData:data];
    [handle closeFile];
}

static void S15HEMLogVisibleIconHierarchySample(void) {
    static BOOL logged = NO;
    if (logged || !S15HEMIsSpringBoard()) return;
    logged = YES;

    NSUInteger emitted = 0;
    for (UIWindow *window in S15HEMAllWindows()) {
        if (!window || window.hidden || window.alpha <= 0.01) continue;
        NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:window];
        while (queue.count && emitted < 80) {
            UIView *candidate = queue.firstObject;
            [queue removeObjectAtIndex:0];
            [queue addObjectsFromArray:candidate.subviews];

            if (candidate.hidden || candidate.alpha <= 0.01) continue;
            NSString *className = NSStringFromClass(candidate.class);
            BOOL iconish = [className containsString:@"Icon"] ||
                           [className containsString:@"Folder"] ||
                           [className containsString:@"Label"];
            if (!iconish) continue;

            NSString *details = [NSString stringWithFormat:@"window=%@ respondsIcon=%d subviews=%lu",
                                 NSStringFromClass(window.class),
                                 [candidate respondsToSelector:@selector(icon)] ? 1 : 0,
                                 (unsigned long)candidate.subviews.count];
            S15HEMAppendTransitionProbe(@"hierarchy.sample", candidate, details);
            emitted++;
        }
    }
}

static NSString *S15HEMSelectorAvailabilitySummary(Class cls, NSArray<NSString *> *selectors) {
    if (!cls) return @"class=0";
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithObject:@"class=1"];
    for (NSString *selectorName in selectors) {
        SEL selector = NSSelectorFromString(selectorName);
        BOOL classResponds = [cls respondsToSelector:selector];
        BOOL instanceResponds = [cls instancesRespondToSelector:selector];
        [parts addObject:[NSString stringWithFormat:@"%@=%d/%d", selectorName, classResponds ? 1 : 0, instanceResponds ? 1 : 0]];
    }
    return [parts componentsJoinedByString:@","];
}

static void S15HEMLogIOS15CompatibilityProbe(UIView *editingButton) {
    static BOOL loggedLaunch = NO;
    static BOOL loggedButton = NO;

    if (!loggedLaunch) {
        loggedLaunch = YES;
        NSArray<NSString *> *classNames = @[
            @"SBHEditingWidgetButton",
            @"SBIconListPageControl",
            @"SBRootFolderView",
            @"SBWallpaperController",
            @"PRSService",
            @"PRUIModalController",
            @"PRUIModalEntryPointEditHomeScreen",
            @"UISUserInterfaceStyleMode"
        ];
        NSMutableArray<NSString *> *classParts = [NSMutableArray array];
        for (NSString *className in classNames) {
            [classParts addObject:[NSString stringWithFormat:@"%@=%d", className, NSClassFromString(className) ? 1 : 0]];
        }

        Class wallpaperControllerClass = NSClassFromString(@"SBWallpaperController");
        Class modalControllerClass = NSClassFromString(@"PRUIModalController");
        Class editButtonClass = NSClassFromString(@"SBHEditingWidgetButton");
        NSString *wallpaperSelectors = S15HEMSelectorAvailabilitySummary(wallpaperControllerClass, @[
            @"sharedInstance",
            @"homeScreenPosterConfiguration",
            @"wallpaperConfigurationManager"
        ]);
        NSString *modalSelectors = S15HEMSelectorAvailabilitySummary(modalControllerClass, @[
            @"initWithEntryPoint:",
            @"presentFromWindowScene:"
        ]);
        NSString *buttonSelectors = S15HEMSelectorAvailabilitySummary(editButtonClass, @[
            @"setMenu:",
            @"setShowsMenuAsPrimaryAction:",
            @"setChangesSelectionAsPrimaryAction:"
        ]);

        S15HEMAppendTransitionProbeMessage(@"ios15.compat",
                                           [NSString stringWithFormat:@"system=%@ classes={%@} wallpaper={%@} modal={%@} editButton={%@} wallpaperFramework=%d",
                                            UIDevice.currentDevice.systemVersion ?: @"(nil)",
                                            [classParts componentsJoinedByString:@","],
                                            wallpaperSelectors,
                                            modalSelectors,
                                            buttonSelectors,
                                            S15HEMLoadWallpaperSettingsFramework() ? 1 : 0]);
    }

    if (editingButton && !loggedButton) {
        loggedButton = YES;
        UIWindow *window = editingButton.window;
        CGRect windowFrame = window ? [editingButton.superview convertRect:editingButton.frame toView:window] : CGRectZero;
        UIEdgeInsets insets = window ? window.safeAreaInsets : UIEdgeInsetsZero;
        CGRect hitFrame = [editingButton convertRect:S15HEMExpandedEditingWidgetHitFrame((UIButton *)editingButton) toView:window];
        S15HEMAppendTransitionProbe(@"ios15.editButton",
                                    editingButton,
                                    [NSString stringWithFormat:@"windowFrame={%.1f,%.1f,%.1f,%.1f} safe={%.1f,%.1f,%.1f,%.1f} hit={%.1f,%.1f,%.1f,%.1f} hasDone=%d",
                                     windowFrame.origin.x,
                                     windowFrame.origin.y,
                                     windowFrame.size.width,
                                     windowFrame.size.height,
                                     insets.top,
                                     insets.left,
                                     insets.bottom,
                                     insets.right,
                                     hitFrame.origin.x,
                                     hitFrame.origin.y,
                                     hitFrame.size.width,
                                     hitFrame.size.height,
                                     S15HEMFindDoneLabelForEditingButton((UIButton *)editingButton) ? 1 : 0]);
    }
}

static CGFloat S15HEMTransformScaleX(CGAffineTransform transform) {
    return sqrt((transform.a * transform.a) + (transform.c * transform.c));
}

static CGFloat S15HEMTransformScaleY(CGAffineTransform transform) {
    return sqrt((transform.b * transform.b) + (transform.d * transform.d));
}

static BOOL S15HEMTransformAlreadyIncludesScale(CGAffineTransform transform, CGFloat scale) {
    if (scale <= 1.0) return YES;
    CGFloat scaleX = S15HEMTransformScaleX(transform);
    CGFloat scaleY = S15HEMTransformScaleY(transform);
    return fabs(scaleX - scale) < 0.02 && fabs(scaleY - scale) < 0.02;
}

static CGAffineTransform S15HEMManagedTransformForIncomingTransform(CGAffineTransform transform) {
    CGFloat scale = S15HEMCurrentIconScale();
    if (scale <= 1.0) return transform;
    if (S15HEMTransformAlreadyIncludesScale(transform, scale)) return transform;
    return CGAffineTransformScale(transform, scale, scale);
}

static CGSize S15HEMScaledIconSize(CGSize size) {
    CGFloat scale = S15HEMCurrentIconScale();
    if (scale == 1.0) return size;
    return CGSizeMake(size.width * scale, size.height * scale);
}

static BOOL S15HEMEffectiveWallpaperDimmingEnabled(UIUserInterfaceStyle style) {
    (void)style; // no longer trait-dependent now that Auto is gone — kept for call-site compatibility
    return S15HEMWallpaperDimmingPreference() == S15HEMWallpaperDimmingModeOn;
}

static NSArray<UIWindow *> *S15HEMAllWindows(void) {
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
    }
    NSArray *fallbackWindows = [UIApplication.sharedApplication valueForKey:@"windows"];
    for (UIWindow *window in fallbackWindows) {
        if (![windows containsObject:window]) [windows addObject:window];
    }
    return windows;
}

static S15HEMAppearanceMode S15HEMAppearanceModePreference(void) {
    NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:kS15HEMAppearanceModeKey];
    if (value < S15HEMAppearanceModeLight || value > S15HEMAppearanceModeTinted) {
        return S15HEMAppearanceModeAutomatic;
    }
    return (S15HEMAppearanceMode)value;
}

static void S15HEMAppearanceModeSetPreference(S15HEMAppearanceMode mode) {
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:kS15HEMAppearanceModeKey];
}

static NSString *S15HEMAppearanceModeTitle(S15HEMAppearanceMode mode) {
    switch (mode) {
        case S15HEMAppearanceModeLight: return @"Light";
        case S15HEMAppearanceModeDark: return @"Dark";
        case S15HEMAppearanceModeAutomatic: return @"Auto";
        case S15HEMAppearanceModeTinted:
        default: return @"Tinted";
    }
}

static CGFloat S15HEMFloatPreference(NSString *key, CGFloat fallback) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if ([value respondsToSelector:@selector(doubleValue)]) {
        CGFloat result = [value doubleValue];
        if (result >= 0.0 && result <= 1.0) return result;
    }
    return fallback;
}

static void S15HEMSetFloatPreference(NSString *key, CGFloat value) {
    [[NSUserDefaults standardUserDefaults] setDouble:MAX(0.0, MIN(1.0, value)) forKey:key];
}

static UIImage *S15HEMBaseWeatherIconImage(void) {
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        image = [UIImage imageWithContentsOfFile:@"/System/Library/AppPlaceholders/Weather.app/AppIcon60x60@2x.png"];
    });
    return image;
}

static CGFloat S15HEMWeatherHueValue(void) {
    return S15HEMFloatPreference(kS15HEMWeatherHueKey, 0.70);
}

static void S15HEMSetWeatherHueValue(CGFloat value) {
    S15HEMSetFloatPreference(kS15HEMWeatherHueKey, value);
}

static CGFloat S15HEMWeatherBrightnessValue(void) {
    return S15HEMFloatPreference(kS15HEMWeatherBrightnessKey, 0.08);
}

static void S15HEMSetWeatherBrightnessValue(CGFloat value) {
    S15HEMSetFloatPreference(kS15HEMWeatherBrightnessKey, value);
}

static UIColor *S15HEMColorForHue(CGFloat hue, CGFloat saturation) {
    return [UIColor colorWithHue:MAX(0.0, MIN(1.0, hue))
                      saturation:MAX(0.0, MIN(1.0, saturation))
                      brightness:1.0
                           alpha:1.0];
}

// Slightly-off white/black (#EEEEEE / #121212) instead of pure white/black —
// used for the top icon row glyphs (sun, paintbrush) and for the appearance
// row's unselected labels, so they read a hair softer than pure
// black/white. Selected labels use the pure version instead.
static UIColor *S15HEMOffWhiteBlackColor(UIUserInterfaceStyle style) {
    // Dialed down twice now — #EEEEEE/#121212, then 0.85/0.13 — both still
    // read as "basically pure" white/black at a glance.
    return style == UIUserInterfaceStyleDark
        ? [UIColor colorWithWhite:0.78 alpha:1.0]
        : [UIColor colorWithWhite:0.20 alpha:1.0];
}

static UIColor *S15HEMPureWhiteBlackColor(UIUserInterfaceStyle style) {
    return style == UIUserInterfaceStyleDark ? UIColor.whiteColor : UIColor.blackColor;
}

// Single source of truth for the sheet's internal vertical stack. These same
// values are used both here (to size the sheet) and in the constraint setup
// (to lay out its children) — previously they were independent magic numbers
// that didn't quite agree, which over-constrained the layout and left the
// collapsed sheet's content sitting ~16pt short of the card's actual bottom
// edge (i.e. the whole card appeared to float too high).
static const CGFloat kS15HEMSheetContentTopOffset = 18.0;
static const CGFloat kS15HEMSheetContentBottomOffset = 2.0;
static const CGFloat kS15HEMSheetIconRowHeight = 30.0;
// Bumped from 8/6 to 18/16 for more breathing room above/below the
// appearance (Light/Dark/Auto/Tinted) row. Both S15HEMCollapsedSheetHeight
// and S15HEMExpandedSheetHeight derive from these same constants (see
// S15HEMSheetHeightForSliderSectionHeight below), as do the actual
// appearanceRow/sliderSection layout constraints, so nothing needs
// independent updating or risks clipping.
static const CGFloat kS15HEMSheetIconRowToAppearanceGap = 18.0;
// Bumped from 94 to 98 to fit the label pill's new height (21->25) without
// clipping — see S15HEMCreateAppearanceButton.
static const CGFloat kS15HEMSheetAppearanceRowHeight = 98.0;
static const CGFloat kS15HEMSheetAppearanceToSliderGap = 16.0;
static const CGFloat kS15HEMSheetSliderSectionCollapsedHeight = 0.0;
static const CGFloat kS15HEMSheetSliderSectionExpandedHeight = 90.0;

static CGFloat S15HEMSheetHeightForSliderSectionHeight(CGFloat sliderSectionHeight) {
    return kS15HEMSheetContentTopOffset
        + kS15HEMSheetIconRowHeight
        + kS15HEMSheetIconRowToAppearanceGap
        + kS15HEMSheetAppearanceRowHeight
        + kS15HEMSheetAppearanceToSliderGap
        + sliderSectionHeight
        + kS15HEMSheetContentBottomOffset;
}

static CGFloat S15HEMCollapsedSheetHeight(void) {
    return S15HEMSheetHeightForSliderSectionHeight(kS15HEMSheetSliderSectionCollapsedHeight);
}

static CGFloat S15HEMExpandedSheetHeight(void) {
    // Match the visible content stack so the options row never has to compress.
    return S15HEMSheetHeightForSliderSectionHeight(kS15HEMSheetSliderSectionExpandedHeight);
}

// A screenshot pulled from the device (via the ios-mcp debug channel) showed
// the actual bug behind every "oval blob" / "keeps filling" report on the
// dimming gauge: SF Symbol "sun.max" bakes a permanently SOLID hub into the
// glyph itself — only the ray weight changes between the .fill/non-.fill
// variants, never the hub. S15HEMSunGaugeView was always drawing its
// off/half/on fraction on top of that already-opaque circle, so nothing it
// did could ever be visible; the "hub" area just always looked fully solid,
// regardless of dimming mode. This renders ONLY the 8 rays (no hub) as a
// template image, calibrated by eye against that screenshot, so the gauge
// sits in genuinely empty space it fully owns.
static UIImage *S15HEMSunRaysOnlyImage(CGFloat pointSize) {
    // The glyph's actual reach (hub + gap + ray length, based on ringWidth,
    // see below) works out to ~0.5775 * pointSize from center, plus another
    // ~0.07 for rayWidth's round line cap past each ray's tip — call it
    // ~0.65. A canvas sized exactly pointSize x pointSize (half-width 0.5)
    // clipped the tips of the cardinal (N/S/E/W) rays against the canvas
    // edge while leaving the diagonal rays (whose x/y projection is
    // reach*cos(45°), well under half of pointSize) untouched — the
    // diagonals only *looked* longer because the cardinals were silently
    // getting cut short. 1.6x gives half-width 0.8, comfortably above the
    // ~0.65 needed — recompute this margin by hand if hubRadius/ringWidth/
    // rayWidth/rayLength fractions change again. pointSize itself still
    // drives every proportion below unchanged, so the design's visual scale
    // is unaffected — only the bitmap it's drawn into is bigger, centered
    // the same way.
    CGFloat canvasSize = pointSize * 1.6;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(canvasSize, canvasSize) format:format];
    UIImage *raw = [renderer imageWithActions:^(UIGraphicsImageRendererContext *rendererContext) {
        CGContextRef ctx = rendererContext.CGContext;
        CGPoint center = CGPointMake(canvasSize / 2.0, canvasSize / 2.0);
        // Hub proportion history: 0.245 (original) made the hub gap nearly
        // half the glyph's footprint, so any fill state looked like a
        // dominant blob eating the ray bases. 0.13 fixed that but read as a
        // bare asterisk with no real "sun" center. 0.19 was a wider middle
        // ground but still just an open gap, not a "sun" — a stroked ring at
        // the hub boundary (same stroke weight as the rays) is what actually
        // reads as a sun rather than an asterisk. 0.22 widens the hub a
        // little further now that the ring anchors it visually.
        // S15HEMSunGaugeView's diameter is derived from hubRadius below
        // (inset by half the ring's stroke width so the fill sits flush
        // inside the ring instead of overlapping/overshooting it).
        CGFloat hubRadius = pointSize * 0.22;
        // Rays lengthened from 0.19 to 0.23, then trimmed back by 2pt (fixed
        // points, not a fraction) after a fidelity check against the real
        // glyph found them a touch too long.
        CGFloat rayLength = pointSize * 0.23 - 2.0;
        // ringWidth stays at the original 0.085 — it drives the ring stroke
        // and the gap between the ring and the rays (both unchanged).
        // rayWidth is thicker on its own (0.085 -> 0.14 was ~1pt too much ->
        // settled at 0.10, ~0.3pt thicker than original) without dragging
        // the ring or gap along with it. NOTE: gaugeDiameter in
        // S15HEMCustomizeSheetView's init still derives from ringWidth
        // (0.085), not this — nothing to update there since ringWidth itself
        // didn't change.
        CGFloat ringWidth = pointSize * 0.085;
        CGFloat rayWidth = pointSize * 0.10;
        // On the real glyph the rays float just outside the ring rather than
        // touching/overlapping it — there's a gap the same thickness as the
        // ring's own stroke between the ring's outer edge and where each ray
        // starts (ring outer edge sits at hubRadius + ringWidth/2, so rays
        // start one more ringWidth beyond that), PLUS another fixed 2pt
        // pushed out further — the same 2pt the rays were just shortened by,
        // so the ray tips land in roughly the same place while the gap
        // itself grows.
        CGFloat rayStartRadius = hubRadius + ringWidth * 1.5 + 2.0;
        CGContextSetLineWidth(ctx, rayWidth);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextSetStrokeColorWithColor(ctx, UIColor.blackColor.CGColor);
        for (NSInteger i = 0; i < 8; i++) {
            CGFloat angle = (CGFloat)i * (M_PI / 4.0);
            CGPoint start = CGPointMake(center.x + rayStartRadius * cos(angle), center.y + rayStartRadius * sin(angle));
            CGPoint end = CGPointMake(center.x + (rayStartRadius + rayLength) * cos(angle), center.y + (rayStartRadius + rayLength) * sin(angle));
            CGContextMoveToPoint(ctx, start.x, start.y);
            CGContextAddLineToPoint(ctx, end.x, end.y);
        }
        CGContextStrokePath(ctx);

        // Ring around the hub — same stroke weight it's always had
        // (ringWidth, not the now-thicker rayWidth) — is what makes this
        // read as a sun instead of a bare asterisk. The gauge fill
        // (S15HEMSunGaugeView) sits inside this ring's inner edge.
        CGRect ringRect = CGRectMake(center.x - hubRadius, center.y - hubRadius, hubRadius * 2.0, hubRadius * 2.0);
        CGContextSetLineWidth(ctx, ringWidth);
        CGContextStrokeEllipseInRect(ctx, ringRect);
    }];
    return [raw imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

static UIImage *S15HEMWeatherPreviewImageForMode(S15HEMAppearanceMode mode) {
    CGSize size = CGSizeMake(56.0, 56.0);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGRect rect = (CGRect){CGPointZero, size};
        UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:13.0];
        [clip addClip];
        UIImage *base = S15HEMBaseWeatherIconImage();
        if (base) {
            [base drawInRect:rect];
        } else {
            [[UIColor colorWithWhite:0.18 alpha:1.0] setFill];
            UIRectFill(rect);
        }

        CGContextRef cg = context.CGContext;
        switch (mode) {
            case S15HEMAppearanceModeLight: {
                break;
            }
            case S15HEMAppearanceModeDark: {
                CGContextSetFillColorWithColor(cg, [UIColor colorWithWhite:0.0 alpha:0.20].CGColor);
                CGContextFillRect(cg, rect);
                break;
            }
            case S15HEMAppearanceModeAutomatic: {
                CGContextSaveGState(cg);
                UIBezierPath *lightHalf = [UIBezierPath bezierPath];
                [lightHalf moveToPoint:CGPointMake(0.0, 0.0)];
                [lightHalf addLineToPoint:CGPointMake(0.0, rect.size.height)];
                [lightHalf addLineToPoint:CGPointMake(rect.size.width, rect.size.height)];
                [lightHalf addLineToPoint:CGPointMake(0.0, 0.0)];
                [lightHalf closePath];
                [lightHalf addClip];
                CGContextSetFillColorWithColor(cg, [UIColor colorWithRed:0.24 green:0.58 blue:0.95 alpha:0.16].CGColor);
                CGContextFillRect(cg, rect);
                CGContextRestoreGState(cg);

                CGContextSaveGState(cg);
                UIBezierPath *darkHalf = [UIBezierPath bezierPath];
                [darkHalf moveToPoint:CGPointMake(0.0, 0.0)];
                [darkHalf addLineToPoint:CGPointMake(rect.size.width, 0.0)];
                [darkHalf addLineToPoint:CGPointMake(rect.size.width, rect.size.height)];
                [darkHalf closePath];
                [darkHalf addClip];
                CGContextSetFillColorWithColor(cg, [UIColor colorWithWhite:0.0 alpha:0.18].CGColor);
                CGContextFillRect(cg, rect);
                CGContextRestoreGState(cg);
                break;
            }
            case S15HEMAppearanceModeTinted:
            default: {
                CGContextSetFillColorWithColor(cg, [UIColor colorWithRed:0.10 green:0.28 blue:0.86 alpha:0.20].CGColor);
                CGContextFillRect(cg, rect);
                break;
            }
        }
    }];
}

static BOOL S15HEMLoadWallpaperSettingsFramework(void) {
    static dispatch_once_t onceToken;
    static BOOL loaded = NO;
    dispatch_once(&onceToken, ^{
        const char *path = "/System/Library/PrivateFrameworks/Settings/WallpaperSettings.framework/WallpaperSettings";
        void *handle = dlopen(path, RTLD_NOW);
        loaded = (handle != NULL);
        if (loaded) {
            S15HEMInstallWallpaperModalHooks();
        }
    });
    return loaded;
}

static void *kS15HEMManagedWallpaperModalKey = &kS15HEMManagedWallpaperModalKey;

static NSMutableSet *S15HEMActiveWallpaperModalControllers(void) {
    static NSMutableSet *controllers = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controllers = [NSMutableSet set];
    });
    return controllers;
}

static UIWindow *S15HEMWindowForWallpaperModalController(id modalController) {
    if (!modalController) return nil;
    @try {
        Ivar windowIvar = class_getInstanceVariable(object_getClass(modalController), "_window");
        if (!windowIvar) return nil;
        id window = object_getIvar(modalController, windowIvar);
        return [window isKindOfClass:UIWindow.class] ? (UIWindow *)window : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static void S15HEMRecoverHomeScreenInteractionAfterWallpaperDismiss(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *homeWindow = S15HEMHomeScreenWindow();
        homeWindow.userInteractionEnabled = YES;
        S15HEMApplyAllCurrentSettings();
    });
}

static void S15HEMRetainWallpaperModalController(id modalController) {
    if (!modalController) return;
    objc_setAssociatedObject(modalController, kS15HEMManagedWallpaperModalKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [S15HEMActiveWallpaperModalControllers() addObject:modalController];
}

static BOOL S15HEMIsManagedWallpaperModalController(id modalController) {
    return [objc_getAssociatedObject(modalController, kS15HEMManagedWallpaperModalKey) boolValue];
}

static void S15HEMDisableWallpaperModalWindow(id modalController, NSString *phase) {
    (void)phase;
    UIWindow *modalWindow = S15HEMWindowForWallpaperModalController(modalController);
    if (!modalWindow) return;
    modalWindow.userInteractionEnabled = NO;
    modalWindow.hidden = YES;
}

static void S15HEMHandleWallpaperModalWillDismiss(id modalController, id response) {
    (void)response;
    if (!S15HEMIsManagedWallpaperModalController(modalController)) return;
}

static void S15HEMHandleWallpaperModalDidDismiss(id modalController, id response) {
    (void)response;
    if (!S15HEMIsManagedWallpaperModalController(modalController)) return;
    S15HEMDisableWallpaperModalWindow(modalController, @"wallpaper.modal.window.disable");
    [S15HEMActiveWallpaperModalControllers() removeObject:modalController];
    objc_setAssociatedObject(modalController, kS15HEMManagedWallpaperModalKey, nil, OBJC_ASSOCIATION_ASSIGN);
    S15HEMRecoverHomeScreenInteractionAfterWallpaperDismiss();
}

static UIWindowScene *S15HEMWindowSceneForButton(UIView *button) {
    UIWindowScene *scene = (UIWindowScene *)button.window.windowScene;
    if (scene) return scene;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
        if ([candidate isKindOfClass:UIWindowScene.class] &&
            candidate.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)candidate;
        }
    }
    return nil;
}

static id S15HEMCurrentHomeScreenPosterConfiguration(void) {
    @try {
        Class wallpaperControllerClass = NSClassFromString(@"SBWallpaperController");
        if (!wallpaperControllerClass) return nil;

        id wallpaperController = nil;
        SEL sharedSel = @selector(sharedInstance);
        if ([wallpaperControllerClass respondsToSelector:sharedSel]) {
            wallpaperController = ((id (*)(id, SEL))objc_msgSend)(wallpaperControllerClass, sharedSel);
        }

        SEL configSel = NSSelectorFromString(@"homeScreenPosterConfiguration");
        if (wallpaperController && [wallpaperController respondsToSelector:configSel]) {
            return ((id (*)(id, SEL))objc_msgSend)(wallpaperController, configSel);
        }
        return nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id S15HEMWallpaperConfigurationManager(void) {
    @try {
        Class wallpaperControllerClass = NSClassFromString(@"SBWallpaperController");
        if (!wallpaperControllerClass) return nil;
        SEL sharedSel = @selector(sharedInstance);
        if (![wallpaperControllerClass respondsToSelector:sharedSel]) return nil;
        id wallpaperController = ((id (*)(id, SEL))objc_msgSend)(wallpaperControllerClass, sharedSel);
        SEL managerSel = NSSelectorFromString(@"wallpaperConfigurationManager");
        if (!wallpaperController || ![wallpaperController respondsToSelector:managerSel]) return nil;
        return ((id (*)(id, SEL))objc_msgSend)(wallpaperController, managerSel);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static void S15HEMApplyWallpaperDimmingForStyle(UIUserInterfaceStyle style) {
    @try {
        id manager = S15HEMWallpaperConfigurationManager();
        SEL setSel = NSSelectorFromString(@"setEnableWallpaperDimming:");
        if (manager && [manager respondsToSelector:setSel]) {
            BOOL enabled = S15HEMEffectiveWallpaperDimmingEnabled(style);
            ((void (*)(id, SEL, BOOL))objc_msgSend)(manager, setSel, enabled);
        }
    } @catch (__unused NSException *exception) {
    }
}

static UIUserInterfaceStyle S15HEMResolvedSystemInterfaceStyle(void) {
    UIWindow *homeWindow = S15HEMHomeScreenWindow();
    UIUserInterfaceStyle style = homeWindow ? homeWindow.traitCollection.userInterfaceStyle : UIUserInterfaceStyleUnspecified;
    if (style != UIUserInterfaceStyleUnspecified) return style;

    for (UIWindow *window in S15HEMAllWindows()) {
        UIUserInterfaceStyle windowStyle = window.traitCollection.userInterfaceStyle;
        if (windowStyle != UIUserInterfaceStyleUnspecified) return windowStyle;
    }

    if (@available(iOS 13.0, *)) {
        return UIScreen.mainScreen.traitCollection.userInterfaceStyle;
    }
    return UIUserInterfaceStyleLight;
}

static UIWindow *S15HEMCoverSheetWindow(void) {
    // Lock screen / Notification Center pull-down (confirmed class name via
    // on-device header dump, SpringBoard.framework 16.0 scope). Wallpaper
    // dimming previously only ever touched SBHomeScreenWindow, so it silently
    // did nothing on the lock screen / cover sheet.
    for (UIWindow *window in S15HEMAllWindows()) {
        if ([NSStringFromClass(window.class) isEqualToString:@"SBCoverSheetWindow"]) return window;
    }
    return nil;
}

static void S15HEMApplyWallpaperDimmingOverlayToWindow(UIWindow *window, UIUserInterfaceStyle style) {
    if (!window) return;

    UIView *overlay = objc_getAssociatedObject(window, kS15HEMWallpaperDimOverlayKey);
    BOOL shouldDim = S15HEMEffectiveWallpaperDimmingEnabled(style);
    if (!overlay) {
        overlay = [[UIView alloc] initWithFrame:window.bounds];
        overlay.userInteractionEnabled = NO;
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:1.0];
        overlay.alpha = 0.0;
        [window insertSubview:overlay atIndex:0];
        objc_setAssociatedObject(window, kS15HEMWallpaperDimOverlayKey, overlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [UIView animateWithDuration:0.22 animations:^{
        overlay.alpha = shouldDim ? 0.38 : 0.0;
    }];
}

static void S15HEMApplyWallpaperDimmingToHomeScreen(void) {
    // Despite the name (kept to avoid touching every call site), this now
    // dims both the home screen and the lock screen / cover sheet so the
    // effect isn't home-screen-only.
    UIUserInterfaceStyle style = S15HEMResolvedSystemInterfaceStyle();
    S15HEMApplyWallpaperDimmingOverlayToWindow(S15HEMHomeScreenWindow(), style);
    S15HEMApplyWallpaperDimmingOverlayToWindow(S15HEMCoverSheetWindow(), style);
}

static UIView *S15HEMFindSubviewWithClassNameContaining(UIView *root, NSString *fragment) {
    if (!root) return nil;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    while (queue.count) {
        UIView *candidate = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([NSStringFromClass(candidate.class) containsString:fragment]) {
            return candidate;
        }
        [queue addObjectsFromArray:candidate.subviews];
    }
    return nil;
}

static BOOL S15HEMViewOrAncestorClassNameContains(UIView *view, NSString *fragment) {
    if (!view || fragment.length == 0) return NO;
    for (UIView *candidate = view; candidate; candidate = candidate.superview) {
        NSString *className = [NSString stringWithUTF8String:object_getClassName(candidate)];
        if ([className containsString:fragment]) {
            return YES;
        }
    }
    return NO;
}

static id S15HEMIconObjectForView(UIView *view) {
    for (UIView *candidate = view; candidate; candidate = candidate.superview) {
        if ([candidate respondsToSelector:@selector(icon)]) {
            id icon = ((id (*)(id, SEL))objc_msgSend)(candidate, @selector(icon));
            if (icon) return icon;
        }
    }
    return nil;
}

static UIView *S15HEMNearestIconViewForView(UIView *view) {
    for (UIView *candidate = view; candidate; candidate = candidate.superview) {
        NSString *className = NSStringFromClass(candidate.class);
        if (S15HEMClassNameLooksLikeIconView(className) &&
            [candidate respondsToSelector:@selector(icon)]) {
            return candidate;
        }
    }
    return nil;
}

static BOOL S15HEMIsFolderIconModelForView(UIView *view) {
    id icon = S15HEMIconObjectForView(view);
    if (icon && [icon respondsToSelector:@selector(isFolderIcon)]) {
        return ((BOOL (*)(id, SEL))objc_msgSend)(icon, @selector(isFolderIcon));
    }
    return NO;
}

static BOOL S15HEMIsWidgetIconModelForView(UIView *view) {
    id icon = S15HEMIconObjectForView(view);
    if (icon && [icon respondsToSelector:@selector(isWidgetIcon)]) {
        return ((BOOL (*)(id, SEL))objc_msgSend)(icon, @selector(isWidgetIcon));
    }
    return NO;
}

static BOOL S15HEMShouldProcessIconView(UIView *iconView) {
    if (!iconView) return NO;
    // Regular icons are always ~60pt wide. Widgets occupy multiple icon slots
    // and are always substantially wider. App-backed widgets use SBApplicationIcon
    // as their model so we can't rely on icon class alone — frame size is definitive.
    CGSize iconFrame = iconView.frame.size;
    if (iconFrame.width > 80.0 || iconFrame.height > 90.0) return NO;
    if (S15HEMViewOrAncestorClassNameContains(iconView, @"Widget")) return NO;
    id icon = S15HEMIconObjectForView(iconView);
    if (!icon) return NO;
    // Check the icon model's class name — more stable than the ancestor view chain
    // during layout transitions when widget views may be temporarily reparented
    NSString *iconModelClass = [NSString stringWithUTF8String:object_getClassName(icon)];
    if ([iconModelClass containsString:@"Widget"]) return NO;
    if (S15HEMIsWidgetIconModelForView(iconView)) return NO;
    if (S15HEMIsFolderIconModelForView(iconView)) return YES;
    if ([icon respondsToSelector:@selector(isApplicationIcon)]) {
        return ((BOOL (*)(id, SEL))objc_msgSend)(icon, @selector(isApplicationIcon));
    }
    NSString *className = [NSString stringWithUTF8String:object_getClassName(iconView)];
    if ([className containsString:@"Widget"] || [className containsString:@"Folder"]) {
        return NO;
    }
    // Don't scale anything we can't positively identify — safer than returning YES
    return NO;
}

static BOOL S15HEMShouldProcessContentView(UIView *contentView) {
    if (!contentView) return NO;
    // Widget image views live inside larger frames — regular icon image views are ~60pt
    CGSize contentFrame = contentView.frame.size;
    if (contentFrame.width > 80.0 || contentFrame.height > 80.0) return NO;
    if (S15HEMViewOrAncestorClassNameContains(contentView, @"Folder")) return NO;
    if (S15HEMViewOrAncestorClassNameContains(contentView, @"Widget")) return NO;
    if (S15HEMIsWidgetIconModelForView(contentView)) return NO;
    // Check icon model class name — stable regardless of transient hierarchy during layout
    id iconModel = S15HEMIconObjectForView(contentView);
    if (iconModel) {
        NSString *iconModelClass = [NSString stringWithUTF8String:object_getClassName(iconModel)];
        if ([iconModelClass containsString:@"Widget"]) return NO;
    }
    NSString *className = [NSString stringWithUTF8String:object_getClassName(contentView)];
    if (![className containsString:@"IconImageView"]) return NO;
    UIView *ownerIconView = S15HEMNearestIconViewForView(contentView);
    if (!ownerIconView) return NO;
    if (!S15HEMShouldProcessIconView(ownerIconView)) return NO;
    UIView *directImage = S15HEMDirectIconImageView(ownerIconView);
    if (directImage) return directImage == contentView;
    return [contentView.superview isEqual:ownerIconView] || [contentView.superview.superview isEqual:ownerIconView];
}

static UIView *S15HEMDirectIconImageView(UIView *iconView) {
    if (!iconView) return nil;
    SEL sel = NSSelectorFromString(@"_iconImageView");
    if ([iconView respondsToSelector:sel]) {
        id result = ((id (*)(id, SEL))objc_msgSend)(iconView, sel);
        if ([result isKindOfClass:UIView.class]) {
            return (UIView *)result;
        }
    }
    return nil;
}

static UIView *S15HEMVisibleIconContainerView(UIView *iconView) {
    if (!iconView) return nil;
    for (UIView *subview in iconView.subviews) {
        NSString *className = [NSString stringWithUTF8String:object_getClassName(subview)];
        if ([className containsString:@"TouchPassThrough"]) {
            return subview;
        }
    }
    return nil;
}

static BOOL S15HEMLabelCandidateShouldBeManaged(UIView *candidate) {
    if (!candidate) return NO;
    NSString *className = [NSString stringWithUTF8String:object_getClassName(candidate)];
    BOOL isLabelish = [className containsString:@"Label"] || [candidate isKindOfClass:UILabel.class];
    BOOL isChrome = [className containsString:@"ImageView"] || [className containsString:@"Badge"] ||
                    [className containsString:@"Editing"] || [className containsString:@"Shadow"];
    return isLabelish && !isChrome;
}

static NSInteger S15HEMViewDepthFromAncestor(UIView *view, UIView *ancestor) {
    if (!view || !ancestor) return NSNotFound;
    NSInteger depth = 0;
    for (UIView *current = view; current; current = current.superview) {
        if (current == ancestor) return depth;
        depth++;
    }
    return NSNotFound;
}

static BOOL S15HEMShouldForceHiddenForLabelView(UIView *labelView) {
    if (!labelView) return NO;
    if (S15HEMIconSizePreference() != S15HEMIconSizeModeLarge) return NO;
    if (!S15HEMLabelCandidateShouldBeManaged(labelView)) return NO;

    UIView *iconView = S15HEMNearestIconViewForView(labelView);
    if (!iconView) return NO;

    if (S15HEMShouldProcessIconView(iconView)) {
        return YES;
    }

    NSInteger depth = S15HEMViewDepthFromAncestor(labelView, iconView);
    return depth != NSNotFound && depth <= 2;
}

// maxDepth: how many levels to descend from root's subviews. -1 = unlimited (regular icons).
// Use 2 for widget SBIconViews to avoid reaching into widget content (clock digits, weather text, etc.).
static void S15HEMSetHiddenForLabelsInView(UIView *root, BOOL hidden, BOOL animate, NSInteger maxDepth) {
    if (!root) return;
    NSMutableArray<UIView *> *targets = [NSMutableArray array];
    NSMutableArray<UIView *> *currentLevel = [NSMutableArray arrayWithArray:root.subviews];
    NSInteger depth = 1;
    while (currentLevel.count > 0 && (maxDepth < 0 || depth <= maxDepth)) {
        NSMutableArray<UIView *> *nextLevel = [NSMutableArray array];
        for (UIView *candidate in currentLevel) {
            NSString *className = [NSString stringWithUTF8String:object_getClassName(candidate)];
            BOOL isLabelish = [className containsString:@"Label"] || [candidate isKindOfClass:UILabel.class];
            BOOL isChrome = [className containsString:@"ImageView"] || [className containsString:@"Badge"] ||
                            [className containsString:@"Editing"] || [className containsString:@"Shadow"];
            if (isLabelish && !isChrome) {
                [targets addObject:candidate];
                // Don't recurse into label views — children follow automatically
            } else if (!isChrome) {
                [nextLevel addObjectsFromArray:candidate.subviews];
            }
        }
        currentLevel = nextLevel;
        depth++;
    }
    if (targets.count == 0) return;
    CGFloat targetAlpha = hidden ? 0.0 : 1.0;
    void (^applyAlpha)(void) = ^{
        for (UIView *v in targets) {
            objc_setAssociatedObject(v, kS15HEMApplyingManagedAlphaKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            v.alpha = targetAlpha;
            objc_setAssociatedObject(v, kS15HEMApplyingManagedAlphaKey, nil, OBJC_ASSOCIATION_ASSIGN);
        }
    };
    if (animate) {
        [UIView animateWithDuration:0.22
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:applyAlpha
                         completion:nil];
    } else {
        applyAlpha();
    }
}

static void S15HEMApplyIconAppearanceToView(UIView *iconView) {
    if (!iconView) return;
    if (![iconView isKindOfClass:UIView.class]) return;
    if (!iconView.window) return;
    if (!S15HEMShouldProcessIconView(iconView)) return;

    S15HEMIconSizeMode mode = S15HEMIconSizePreference();
    BOOL large = mode == S15HEMIconSizeModeLarge;
    NSNumber *lastModeValue = objc_getAssociatedObject(iconView, kS15HEMLastAppliedIconModeKey);
    BOOL animate = lastModeValue != nil && lastModeValue.integerValue != mode;
    BOOL folderIcon = S15HEMIsFolderIconModelForView(iconView);

    UIView *containerView = S15HEMVisibleIconContainerView(iconView);
    UIView *contentView = S15HEMDirectIconImageView(iconView);
    if (!contentView) contentView = S15HEMFindSubviewWithClassNameContaining(iconView, @"IconImageView");
    if (!contentView && folderIcon) contentView = S15HEMFindSubviewWithClassNameContaining(iconView, @"FolderIconImageView");
    if (!contentView && folderIcon) contentView = S15HEMFindSubviewWithClassNameContaining(iconView, @"IconContent");
    if (!contentView) return;

    CGFloat scale = S15HEMCurrentIconScale();
    void (^changes)(void) = ^{
        if (containerView) {
            objc_setAssociatedObject(containerView, kS15HEMApplyingManagedTransformKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            containerView.transform = CGAffineTransformMakeScale(scale, scale);
            objc_setAssociatedObject(containerView, kS15HEMApplyingManagedTransformKey, nil, OBJC_ASSOCIATION_ASSIGN);
        }
        objc_setAssociatedObject(contentView, kS15HEMApplyingManagedTransformKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        contentView.transform = CGAffineTransformMakeScale(scale, scale);
        objc_setAssociatedObject(contentView, kS15HEMApplyingManagedTransformKey, nil, OBJC_ASSOCIATION_ASSIGN);
    };
    if (animate) {
        [UIView animateWithDuration:0.28
                              delay:0.0
             usingSpringWithDamping:0.82
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }

    SEL configureSizeSel = NSSelectorFromString(@"configureSize");
    if ([contentView respondsToSelector:configureSizeSel]) {
        ((void (*)(id, SEL))objc_msgSend)(contentView, configureSizeSel);
    } else if ([iconView respondsToSelector:configureSizeSel]) {
        ((void (*)(id, SEL))objc_msgSend)(iconView, configureSizeSel);
    }

    S15HEMSetHiddenForLabelsInView(iconView, large, animate, -1);
    objc_setAssociatedObject(iconView, kS15HEMLastAppliedIconModeKey, @(mode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void S15HEMApplyIconAppearanceToAllVisibleViews(BOOL animated) {
    (void)animated;
    for (UIWindow *window in S15HEMAllWindows()) {
        S15HEMApplyIconAppearanceInContainer(window, animated);
    }
}

static void S15HEMApplyIconAppearanceInContainer(UIView *container, BOOL animated) {
    if (!container) return;
    BOOL large = S15HEMIconSizePreference() == S15HEMIconSizeModeLarge;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:container];
    while (queue.count) {
        UIView *candidate = queue.firstObject;
        [queue removeObjectAtIndex:0];
        NSString *className = NSStringFromClass(candidate.class);
        if (S15HEMClassNameLooksLikeIconView(className) &&
            [candidate respondsToSelector:@selector(icon)]) {
            if (S15HEMShouldProcessIconView(candidate)) {
                S15HEMApplyIconAppearanceToView(candidate);
            } else {
                // Widget/non-processable: fade only the shallow app-name label (depth 2),
                // never widget content (clock digits, weather text, etc.).
                S15HEMSetHiddenForLabelsInView(candidate, large, animated, 2);
            }
        }
        [queue addObjectsFromArray:candidate.subviews];
    }
}

static void S15HEMInvokeNoArgSelectorIfPresent(id target, NSString *name) {
    if (!target || name.length == 0) return;
    SEL sel = NSSelectorFromString(name);
    if ([target respondsToSelector:sel]) {
        ((void (*)(id, SEL))objc_msgSend)(target, sel);
    }
}

static void S15HEMInvokeBoolSelectorIfPresent(id target, NSString *name, BOOL value) {
    if (!target || name.length == 0) return;
    SEL sel = NSSelectorFromString(name);
    if ([target respondsToSelector:sel]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(target, sel, value);
    }
}

static void S15HEMRefreshOneIconListView(UIView *listView, BOOL animated) {
    if (!listView) return;
    [listView setNeedsLayout];
    [listView layoutIfNeeded];

    for (NSString *selName in @[
        @"layoutIconsNow",
        @"layoutIconsIfNeeded",
        @"_layoutIconsNow",
        @"_layoutIconsIfNeeded",
        @"reloadIcons",
        @"reloadData",
        @"invalidateLayout",
        @"setNeedsLayout"
    ]) {
        S15HEMInvokeNoArgSelectorIfPresent(listView, selName);
    }

    for (NSString *selName in @[
        @"layoutIconsAnimated:",
        @"reloadIconsAnimated:",
        @"setAnimating:"
    ]) {
        S15HEMInvokeBoolSelectorIfPresent(listView, selName, animated);
    }
}

static void S15HEMRefreshHomeScreenIconLists(BOOL animated) {
    NSMutableArray<UIView *> *lists = [NSMutableArray array];
    for (UIWindow *window in S15HEMAllWindows()) {
        NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:window];
        while (queue.count) {
            UIView *candidate = queue.firstObject;
            [queue removeObjectAtIndex:0];
            NSString *className = NSStringFromClass(candidate.class);
            if (([className isEqualToString:@"SBRootIconListView"] ||
                 [className isEqualToString:@"SBDockIconListView"] ||
                 [className isEqualToString:@"SBIconListView"]) &&
                !candidate.hidden && candidate.alpha > 0.01) {
                [lists addObject:candidate];
            }
            [queue addObjectsFromArray:candidate.subviews];
        }
    }

    for (UIView *listView in lists) {
        S15HEMRefreshOneIconListView(listView, animated);
        [listView.superview setNeedsLayout];
        [listView.superview layoutIfNeeded];
    }

    Class icc = NSClassFromString(@"SBIconController");
    SEL sharedSel = NSSelectorFromString(@"sharedInstance");
    id controller = (icc && [icc respondsToSelector:sharedSel])
        ? ((id (*)(Class, SEL))objc_msgSend)(icc, sharedSel)
        : nil;
    for (NSString *selName in @[
        @"layoutIconViews",
        @"reloadIconViews",
        @"_reloadIconViews",
        @"_relayoutIconLists",
        @"relayoutIconLists"
    ]) {
        S15HEMInvokeNoArgSelectorIfPresent(controller, selName);
    }
}

static void S15HEMApplyAppearanceModeToSpringBoard(void) {
    UIUserInterfaceStyle style = UIUserInterfaceStyleUnspecified;
    if (S15HEMAppearanceButtonsDriveSystemAppearance()) {
        S15HEMAppearanceMode mode = S15HEMAppearanceModePreference();
        if (mode == S15HEMAppearanceModeLight) style = UIUserInterfaceStyleLight;
        else if (mode == S15HEMAppearanceModeDark) style = UIUserInterfaceStyleDark;
    }

    for (UIWindow *window in S15HEMAllWindows()) {
        window.overrideUserInterfaceStyle = style;
        [window setNeedsLayout];
        [window layoutIfNeeded];
    }
    S15HEMApplyWallpaperDimmingToHomeScreen();
}

static void S15HEMApplyAllCurrentSettings(void) {
    S15HEMSynchronizeAppearancePreferenceFromSystemIfNeeded();
    S15HEMApplyAppearanceModeToSpringBoard();
    UIUserInterfaceStyle style = S15HEMResolvedSystemInterfaceStyle();
    S15HEMApplyWallpaperDimmingForStyle(style);
    S15HEMApplyWallpaperDimmingToHomeScreen();
    S15HEMApplyIconAppearanceToAllVisibleViews(NO);
    S15HEMRefreshActiveSheetControlStateAnimated(NO);
}

// MARK: - Live system appearance sync
//
// The customize sheet can push its appearance choice into the system (see
// appearanceButtonTapped:), but nothing was listening for the *reverse*
// direction: the user flipping Dark Mode from Settings or Control Center.
// UISUserInterfaceStyleMode internally observes the backing defaults
// (_observingDefaults ivar, confirmed via on-device header dump) and calls
// -userInterfaceStyleModeDidChange: on its delegate when the real system
// value changes underneath it — Settings.app, Control Center, and Shortcuts
// all land here. We keep one persistent, delegate-registered instance alive
// for the life of SpringBoard so we actually receive that callback, plus a
// slow poll backstop in case the delegate ever silently stops firing.

static void S15HEMHandleSystemAppearanceModeChangedExternally(void);

@interface S15HEMSystemAppearanceObserver : NSObject <S15HEMUISUserInterfaceStyleModeDelegate>
@end

@implementation S15HEMSystemAppearanceObserver
- (void)userInterfaceStyleModeDidChange:(id)mode {
    (void)mode;
    dispatch_async(dispatch_get_main_queue(), ^{
        S15HEMHandleSystemAppearanceModeChangedExternally();
    });
}
@end

static id sS15HEMPersistentStyleMode = nil;
static S15HEMSystemAppearanceObserver *sS15HEMStyleModeObserver = nil;
static NSTimer *sS15HEMAppearancePollTimer = nil;
static NSInteger sS15HEMLastPolledSystemModeValue = NSIntegerMin;

static void S15HEMHandleSystemAppearanceModeChangedExternally(void) {
    if (!S15HEMIsSpringBoard()) return;
    S15HEMApplyAllCurrentSettings();
}

static void S15HEMPollSystemAppearanceModeForChange(void) {
    if (!S15HEMIsSpringBoard()) return;
    NSInteger currentValue = S15HEMCurrentSystemAppearanceModeValue();
    if (sS15HEMLastPolledSystemModeValue == NSIntegerMin) {
        sS15HEMLastPolledSystemModeValue = currentValue;
        return;
    }
    if (currentValue != sS15HEMLastPolledSystemModeValue) {
        sS15HEMLastPolledSystemModeValue = currentValue;
        S15HEMHandleSystemAppearanceModeChangedExternally();
    }
}

static void S15HEMInstallSystemAppearanceObserver(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!S15HEMIsSpringBoard()) return;

        Class styleModeClass = NSClassFromString(@"UISUserInterfaceStyleMode");
        if (styleModeClass) {
            @try {
                sS15HEMStyleModeObserver = [S15HEMSystemAppearanceObserver new];
                SEL initSel = NSSelectorFromString(@"initWithDelegate:");
                id styleMode = ((id (*)(id, SEL, id))objc_msgSend)([styleModeClass alloc], initSel, sS15HEMStyleModeObserver);
                if (styleMode && [styleMode respondsToSelector:@selector(modeValue)]) {
                    sS15HEMPersistentStyleMode = styleMode;
                } else {
                    sS15HEMStyleModeObserver = nil;
                }
            } @catch (__unused NSException *exception) {
                sS15HEMStyleModeObserver = nil;
            }
        }

        sS15HEMLastPolledSystemModeValue = S15HEMCurrentSystemAppearanceModeValue();
        sS15HEMAppearancePollTimer = [NSTimer scheduledTimerWithTimeInterval:1.5
                                                                      repeats:YES
                                                                        block:^(NSTimer *timer) {
            (void)timer;
            S15HEMPollSystemAppearanceModeForChange();
        }];
        [[NSRunLoop mainRunLoop] addTimer:sS15HEMAppearancePollTimer forMode:NSRunLoopCommonModes];
    });
}

static void S15HEMHandleHomeScreenTraitChange(UITraitCollection *previousTraitCollection, UITraitCollection *currentTraitCollection) {
    if (!currentTraitCollection) return;
    if (previousTraitCollection &&
        previousTraitCollection.userInterfaceStyle == currentTraitCollection.userInterfaceStyle) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        S15HEMAppearanceMode mode = S15HEMAppearanceModePreference();
        if (S15HEMAppearanceButtonsDriveSystemAppearance() &&
            (mode == S15HEMAppearanceModeAutomatic || mode == S15HEMAppearanceModeTinted)) {
            S15HEMApplyAppearanceModeToSpringBoard();
        }
        S15HEMApplyWallpaperDimmingForStyle(currentTraitCollection.userInterfaceStyle);
        S15HEMApplyWallpaperDimmingToHomeScreen();
    });
}

static id S15HEMCreateHomeScreenEntryPointWithServiceConfiguration(id serviceConfiguration) {
    @try {
        Class cls = NSClassFromString(@"PRUIModalEntryPointEditHomeScreen");
        if (!cls) return nil;

        id entryPoint = [cls alloc];
        SEL initSel = NSSelectorFromString(@"initWithServiceConfiguration:");
        if ([entryPoint respondsToSelector:initSel]) {
            if (!serviceConfiguration) return nil;
            entryPoint = ((id (*)(id, SEL, id))objc_msgSend)(entryPoint, initSel, serviceConfiguration);
        } else if ([entryPoint respondsToSelector:@selector(init)]) {
            entryPoint = ((id (*)(id, SEL))objc_msgSend)(entryPoint, @selector(init));
        }
        return entryPoint;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static BOOL S15HEMPresentHomeScreenWallpaperModalWithServiceConfiguration(UIView *button, id serviceConfiguration) {
    @try {
        if (!S15HEMLoadWallpaperSettingsFramework()) return NO;

        Class controllerClass = NSClassFromString(@"PRUIModalController");
        if (!controllerClass) return NO;

        id entryPoint = S15HEMCreateHomeScreenEntryPointWithServiceConfiguration(serviceConfiguration);
        if (!entryPoint) return NO;

        id modalController = nil;
        SEL initSel = @selector(initWithEntryPoint:);
        if ([controllerClass instancesRespondToSelector:initSel]) {
            modalController = ((id (*)(id, SEL, id))objc_msgSend)([controllerClass alloc], initSel, entryPoint);
        }
        if (!modalController) return NO;

        UIWindowScene *scene = S15HEMWindowSceneForButton(button);
        SEL presentSel = @selector(presentFromWindowScene:);
        if ([modalController respondsToSelector:presentSel] && scene) {
            ((void (*)(id, SEL, id))objc_msgSend)(modalController, presentSel, scene);
            S15HEMRetainWallpaperModalController(modalController);
            return YES;
        }
        return NO;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static BOOL S15HEMPresentHomeScreenWallpaperModal(UIView *button) {
    id serviceConfiguration = S15HEMCurrentHomeScreenPosterConfiguration();
    if (!serviceConfiguration) return NO;
    return S15HEMPresentHomeScreenWallpaperModalWithServiceConfiguration(button, serviceConfiguration);
}

static void S15HEMLaunchWallpaperFallback(void) {
    LSApplicationWorkspace *workspace = [LSApplicationWorkspace respondsToSelector:@selector(defaultWorkspace)]
        ? [LSApplicationWorkspace defaultWorkspace] : nil;

    if ([workspace respondsToSelector:@selector(openApplicationWithBundleID:)]) {
        @try {
            [workspace openApplicationWithBundleID:@"com.apple.PosterBoard"];
            return;
        } @catch (__unused NSException *exception) {
        }
    }

    FBSSystemService *service = [FBSSystemService sharedService];
    if (service) {
        mach_port_t port = [service createClientPort];
        NSURL *prefsURL = [NSURL URLWithString:@"App-prefs:root=Wallpaper"];
        if (prefsURL) {
            [service openURL:prefsURL
                 application:@"com.apple.Preferences"
                     options:@{}
                  clientPort:port
                  withResult:^(__unused NSError *error) {}];
        }
    }
}

static void S15HEMFetchActiveHomeScreenPosterConfiguration(void (^completion)(id configuration)) {
    Class prsServiceClass = NSClassFromString(@"PRSService");
    if (!prsServiceClass) { completion(nil); return; }

    id service = ((id (*)(id, SEL))objc_msgSend)([prsServiceClass alloc], @selector(init));
    if (!service) { completion(nil); return; }

    SEL fetchSel = NSSelectorFromString(@"fetchActivePosterConfiguration:");
    if (![service respondsToSelector:fetchSel]) { completion(nil); return; }

    __block id retainedService = service;
    void (^handler)(id) = ^(id activePosterConfiguration) {
        id homeConfig = nil;
        id lockConfig = nil;
        @try {
            SEL homeSel = NSSelectorFromString(@"homeScreenPosterConfiguration");
            if (activePosterConfiguration && [activePosterConfiguration respondsToSelector:homeSel]) {
                homeConfig = ((id (*)(id, SEL))objc_msgSend)(activePosterConfiguration, homeSel);
            }
            SEL lockSel = NSSelectorFromString(@"lockScreenPosterConfiguration");
            if (activePosterConfiguration && [activePosterConfiguration respondsToSelector:lockSel]) {
                lockConfig = ((id (*)(id, SEL))objc_msgSend)(activePosterConfiguration, lockSel);
            }
        } @catch (__unused NSException *exception) {
        }

        retainedService = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(homeConfig ?: lockConfig);
        });
    };

    ((void (*)(id, SEL, id))objc_msgSend)(service, fetchSel, handler);
}

static UIView *S15HEMFindVisibleSubview(UIView *root, NSString *className) {
    if (!root) return nil;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    UIView *best = nil;
    CGFloat bestWidth = 0.0;
    while (queue.count) {
        UIView *candidate = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([NSStringFromClass(candidate.class) isEqualToString:className] &&
            !candidate.hidden && candidate.alpha > 0.01 && CGRectGetWidth(candidate.bounds) > bestWidth) {
            best = candidate;
            bestWidth = CGRectGetWidth(candidate.bounds);
        }
        [queue addObjectsFromArray:candidate.subviews];
    }
    return best;
}

static UIWindow *S15HEMHomeScreenWindow(void) {
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            [windows addObjectsFromArray:((UIWindowScene *)scene).windows];
        }
    }
    NSArray *fallbackWindows = [UIApplication.sharedApplication valueForKey:@"windows"];
    for (UIWindow *window in fallbackWindows) {
        if (![windows containsObject:window]) [windows addObject:window];
    }

    for (UIWindow *window in windows) {
        if ([NSStringFromClass(window.class) isEqualToString:@"SBHomeScreenWindow"]) return window;
    }
    for (UIWindow *window in windows) {
        if (window.isKeyWindow) return window;
    }
    return windows.firstObject;
}

static CGFloat S15HEMHighestVisibleSpringBoardWindowLevel(void) {
    CGFloat level = UIWindowLevelNormal;
    for (UIWindow *window in S15HEMAllWindows()) {
        if (!window || window.hidden || window.alpha <= 0.01) continue;
        level = MAX(level, window.windowLevel);
    }
    return level;
}

static UIWindowScene *S15HEMActiveWindowSceneForButton(UIView *button) {
    UIWindowScene *scene = (UIWindowScene *)button.window.windowScene;
    if (scene) return scene;
    for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
        if ([candidate isKindOfClass:UIWindowScene.class] &&
            candidate.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)candidate;
        }
    }
    return nil;
}

static UIWindow *S15HEMCreatePresentationWindowForButton(UIView *button) {
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) {
        return button.window ?: S15HEMHomeScreenWindow();
    }

    UIWindowScene *scene = S15HEMActiveWindowSceneForButton(button);
    CGRect bounds = scene ? scene.coordinateSpace.bounds : UIScreen.mainScreen.bounds;
    UIWindow *window = nil;
    if (scene) {
        window = [[UIWindow alloc] initWithWindowScene:scene];
    } else {
        window = [[UIWindow alloc] initWithFrame:bounds];
    }
    window.frame = bounds;
    window.backgroundColor = UIColor.clearColor;
    window.windowLevel = S15HEMHighestVisibleSpringBoardWindowLevel() + 1.0;
    window.hidden = NO;
    window.userInteractionEnabled = YES;
    return window;
}

static UIView *S15HEMRootFolderViewForButton(UIView *button) {
    for (UIView *candidate = button; candidate; candidate = candidate.superview) {
        NSString *className = NSStringFromClass(candidate.class);
        if ([className isEqualToString:@"SBRootFolderView"] || [className containsString:@"RootFolderView"]) {
            return candidate;
        }
    }
    return nil;
}

static void S15HEMTriggerWidgetAction(UIView *button) {
    UIView *rootFolderView = S15HEMRootFolderViewForButton(button);
    SEL sel = NSSelectorFromString(@"widgetButtonTriggered:");
    if ([rootFolderView respondsToSelector:sel]) {
        ((void (*)(id, SEL, id))objc_msgSend)(rootFolderView, sel, button);
    }
}

static UIView *S15HEMPageControlForButton(UIView *button) {
    UIWindow *window = button.window ?: S15HEMHomeScreenWindow();
    UIView *pageControl = S15HEMFindVisibleSubview(window, @"SBIconListPageControl");
    if (pageControl) return pageControl;
    UIView *rootFolderView = S15HEMRootFolderViewForButton(button);
    return S15HEMFindVisibleSubview(rootFolderView ?: window, @"SBIconListPageControl");
}

static void S15HEMTriggerEditPages(UIView *button) {
    UIView *pageControl = S15HEMPageControlForButton(button);
    SEL tapSel = NSSelectorFromString(@"tapGestureDidUpdate:");
    if (pageControl && [pageControl respondsToSelector:tapSel]) {
        UITapGestureRecognizer *tap = nil;
        for (UIGestureRecognizer *candidate in pageControl.gestureRecognizers) {
            if (![candidate isKindOfClass:UITapGestureRecognizer.class]) continue;
            NSString *desc = candidate.description ?: @"";
            if ([desc containsString:@"tapGestureDidUpdate:"]) {
                tap = (UITapGestureRecognizer *)candidate;
                break;
            }
        }
        if (!tap) {
            for (UIGestureRecognizer *candidate in pageControl.gestureRecognizers) {
                if ([candidate isKindOfClass:UITapGestureRecognizer.class]) {
                    tap = (UITapGestureRecognizer *)candidate;
                    break;
                }
            }
        }
        if (tap) {
            @try {
                [tap setValue:@(UIGestureRecognizerStateEnded) forKey:@"state"];
            } @catch (__unused NSException *exception) {}
            ((void (*)(id, SEL, id))objc_msgSend)(pageControl, tapSel, tap);
            return;
        }
    }

    UIView *rootFolderView = S15HEMRootFolderViewForButton(button);
    NSArray *folderCandidates = @[
        @"showPageEditingInterface:",
        @"_showPageEditingInterface:",
        @"beginEditingPagesAnimated:",
        @"_beginEditingPages",
        @"togglePageEditorAnimated:",
        @"_togglePageReorderingMode",
        @"_openPageManager",
    ];
    for (NSString *s in folderCandidates) {
        SEL sel = NSSelectorFromString(s);
        if ([rootFolderView respondsToSelector:sel]) {
            IMP imp = [rootFolderView methodForSelector:sel];
            if ([s hasSuffix:@":"]) ((void (*)(id, SEL, id))imp)(rootFolderView, sel, nil);
            else                   ((void (*)(id, SEL))imp)(rootFolderView, sel);
            return;
        }
    }

    Class icc = NSClassFromString(@"SBIconController");
    SEL si = NSSelectorFromString(@"sharedInstance");
    id ic = (icc && [icc respondsToSelector:si])
        ? ((id (*)(Class, SEL))objc_msgSend)(icc, si) : nil;
    for (NSString *s in @[@"_togglePageEditing", @"presentPageEditingViewController",
                          @"showPageEditor", @"_showPageEditingInterface"]) {
        SEL sel = NSSelectorFromString(s);
        if ([ic respondsToSelector:sel]) {
            ((void (*)(id, SEL))objc_msgSend)(ic, sel);
            return;
        }
    }
}

static void S15HEMTriggerWallpaper(UIView *button) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (S15HEMPresentHomeScreenWallpaperModal(button)) return;

        S15HEMFetchActiveHomeScreenPosterConfiguration(^(id configuration) {
            if (configuration && S15HEMPresentHomeScreenWallpaperModalWithServiceConfiguration(button, configuration)) return;
            S15HEMLaunchWallpaperFallback();
        });
    });
}

static void *kS15HEMAppearanceButtonImageKey = &kS15HEMAppearanceButtonImageKey;
static void *kS15HEMAppearanceButtonLabelKey = &kS15HEMAppearanceButtonLabelKey;
static void *kS15HEMAppearanceButtonLabelPillKey = &kS15HEMAppearanceButtonLabelPillKey;
static void *kS15HEMAppearanceButtonTileKey = &kS15HEMAppearanceButtonTileKey;
static void *kS15HEMAppearanceButtonBorderKey = &kS15HEMAppearanceButtonBorderKey;

static UIImageView *S15HEMAppearanceButtonImageView(UIButton *button) {
    return objc_getAssociatedObject(button, kS15HEMAppearanceButtonImageKey);
}

static UILabel *S15HEMAppearanceButtonTitleLabel(UIButton *button) {
    return objc_getAssociatedObject(button, kS15HEMAppearanceButtonLabelKey);
}

static UIView *S15HEMAppearanceButtonTile(UIButton *button) {
    return objc_getAssociatedObject(button, kS15HEMAppearanceButtonTileKey);
}

static UIView *S15HEMAppearanceButtonLabelPill(UIButton *button) {
    return objc_getAssociatedObject(button, kS15HEMAppearanceButtonLabelPillKey);
}

static UIView *S15HEMAppearanceButtonBorder(UIButton *button) {
    return objc_getAssociatedObject(button, kS15HEMAppearanceButtonBorderKey);
}

static UIButton *S15HEMCreateAppearanceButton(S15HEMCustomizeSheetView *sheet, S15HEMAppearanceMode mode) {
    UIButton *button = [[S15HEMAppearanceButton alloc] initWithFrame:CGRectZero];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tag = mode;
    button.configuration = nil;
    button.tintColor = UIColor.labelColor;
    button.layer.cornerRadius = 0.0;
    button.layer.masksToBounds = NO;
    button.backgroundColor = UIColor.clearColor;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    // Matches kS15HEMSheetAppearanceRowHeight below (bumped from 94 to 98 to
    // fit the taller label pill without clipping it).
    [[button.heightAnchor constraintEqualToConstant:kS15HEMSheetAppearanceRowHeight] setActive:YES];

    UIView *iconTile = [[UIView alloc] initWithFrame:CGRectZero];
    iconTile.translatesAutoresizingMaskIntoConstraints = NO;
    iconTile.userInteractionEnabled = NO;
    iconTile.backgroundColor = UIColor.clearColor;
    iconTile.layer.cornerRadius = 14.0;
    iconTile.layer.cornerCurve = kCACornerCurveContinuous;
    iconTile.layer.masksToBounds = NO;
    [button addSubview:iconTile];
    objc_setAssociatedObject(button, kS15HEMAppearanceButtonTileKey, iconTile, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIView *borderView = [[UIView alloc] initWithFrame:CGRectZero];
    borderView.translatesAutoresizingMaskIntoConstraints = NO;
    borderView.userInteractionEnabled = NO;
    borderView.backgroundColor = UIColor.clearColor;
    borderView.layer.cornerRadius = 16.0;
    borderView.layer.cornerCurve = kCACornerCurveContinuous;
    borderView.layer.borderWidth = 7.0;
    borderView.layer.borderColor = UIColor.clearColor.CGColor;
    [iconTile addSubview:borderView];
    objc_setAssociatedObject(button, kS15HEMAppearanceButtonBorderKey, borderView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIImageView *imageView = [[UIImageView alloc] initWithImage:S15HEMWeatherPreviewImageForMode(mode)];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.userInteractionEnabled = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.clipsToBounds = YES;
    imageView.layer.cornerCurve = kCACornerCurveContinuous;
    [iconTile addSubview:imageView];
    objc_setAssociatedObject(button, kS15HEMAppearanceButtonImageKey, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = S15HEMAppearanceModeTitle(mode);
    label.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.adjustsFontForContentSizeCategory = NO;

    UIView *labelPill = [[UIView alloc] initWithFrame:CGRectZero];
    labelPill.translatesAutoresizingMaskIntoConstraints = NO;
    labelPill.userInteractionEnabled = NO;
    labelPill.backgroundColor = UIColor.clearColor;
    // A full capsule (radius == height/2) looked pointy before because the
    // pill was only as wide as it needed to be to hug the text — barely
    // wider than its own height. Now that it's pinned to the icon tile's
    // width (56pt, well over 2x the 25pt height), radius == height/2 reads
    // as a proper wide pill instead of a pointy lozenge.
    labelPill.layer.cornerRadius = 12.5;
    labelPill.layer.cornerCurve = kCACornerCurveContinuous;
    [button addSubview:labelPill];
    [labelPill addSubview:label];
    objc_setAssociatedObject(button, kS15HEMAppearanceButtonLabelPillKey, labelPill, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, kS15HEMAppearanceButtonLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [NSLayoutConstraint activateConstraints:@[
        [iconTile.topAnchor constraintEqualToAnchor:button.topAnchor constant:7.0],
        [iconTile.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [iconTile.widthAnchor constraintEqualToConstant:56.0],
        [iconTile.heightAnchor constraintEqualToConstant:56.0],

        [borderView.topAnchor constraintEqualToAnchor:iconTile.topAnchor constant:-2.0],
        [borderView.leadingAnchor constraintEqualToAnchor:iconTile.leadingAnchor constant:-2.0],
        [borderView.trailingAnchor constraintEqualToAnchor:iconTile.trailingAnchor constant:2.0],
        [borderView.bottomAnchor constraintEqualToAnchor:iconTile.bottomAnchor constant:2.0],

        [imageView.centerXAnchor constraintEqualToAnchor:iconTile.centerXAnchor],
        [imageView.centerYAnchor constraintEqualToAnchor:iconTile.centerYAnchor],
        [imageView.widthAnchor constraintEqualToConstant:54.0],
        [imageView.heightAnchor constraintEqualToConstant:54.0],

        [labelPill.topAnchor constraintEqualToAnchor:iconTile.bottomAnchor constant:8.0],
        [labelPill.centerXAnchor constraintEqualToAnchor:button.centerXAnchor],
        [labelPill.widthAnchor constraintEqualToAnchor:iconTile.widthAnchor],
        [labelPill.heightAnchor constraintEqualToConstant:25.0],
        [labelPill.bottomAnchor constraintEqualToAnchor:button.bottomAnchor constant:-2.0],

        [label.topAnchor constraintEqualToAnchor:labelPill.topAnchor],
        [label.leadingAnchor constraintEqualToAnchor:labelPill.leadingAnchor constant:6.0],
        [label.trailingAnchor constraintEqualToAnchor:labelPill.trailingAnchor constant:-6.0],
        [label.centerYAnchor constraintEqualToAnchor:labelPill.centerYAnchor],
    ]];

    [button addTarget:sheet action:@selector(appearanceButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    // Tinted is a no-op for v1 — kept visible but inert; refreshControlStateAnimated:
    // applies the dimmed alpha once the button's subviews exist.
    if (mode == S15HEMAppearanceModeTinted) {
        button.userInteractionEnabled = NO;
    }

    return button;
}


@implementation S15HEMCustomizeSheetView {
    NSLayoutConstraint *_sheetHeightConstraint;
    NSLayoutConstraint *_sheetBottomConstraint;
    NSLayoutConstraint *_sliderSectionHeightConstraint;
    CAGradientLayer *_hueGradientLayer;
    CAGradientLayer *_brightnessGradientLayer;
    BOOL _slidersExpanded;
    CGFloat _dimmingGlyphRotation;
}

- (void)updateMaterialForCurrentTraitAnimated:(BOOL)animated {
    UIBlurEffectStyle style = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? UIBlurEffectStyleSystemChromeMaterialDark
        : UIBlurEffectStyleSystemChromeMaterialLight;
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:style];
    self.grabberView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.26 : 0.34)];

    if (animated) {
        [UIView animateWithDuration:0.20 animations:^{
            self.sheetView.effect = effect;
        }];
    } else {
        self.sheetView.effect = effect;
    }
}

- (void)refreshControlStateAnimated:(BOOL)animated {
    self.iconSizeControl.selectedSegmentIndex = S15HEMIconSizePreference() == S15HEMIconSizeModeLarge ? 1 : 0;
    S15HEMWallpaperDimmingMode dimMode = S15HEMWallpaperDimmingPreference();
    // Deliberately never touch dimmingModeButton.selected: on this iOS
    // version, setting .selected = YES on a plain UIButtonTypeSystem (with no
    // configuration) silently creates an internal resizable "selected"
    // background image as a private subview — a small ~10x17pt capsule that
    // isn't clipped to our circular button and renders as a solid dark blob
    // dead center, stomping the sun glyph/gauge underneath it. Every "huge
    // oval / keeps filling" report going all the way back traced to THIS,
    // not to S15HEMSunGaugeView or S15HEMSunRaysOnlyImage — confirmed by
    // hiding both custom subviews and finding the blob was still there,
    // then dumping dimmingModeButton.subviews to catch the extra
    // _UIResizableImage-backed UIImageView UIKit added on its own. All
    // visual "selected" feedback is handled manually below instead — though
    // per fidelity check against the real OS, that "selected" feedback is
    // now just the fill/rotation animation; there's no background circle
    // behind the button on the real glyph, so it's been removed entirely.
    self.dimmingModeButton.backgroundColor = UIColor.clearColor;

    // Matches the real OS: wallpaper dimming is just off/on, and "on" shows
    // a half fill (not a full disc) — there's no third "auto" state anymore.
    // The half fill sits on the LEFT and is left-anchored (grows from the
    // left edge outward), so turning it off reads as the fill sliding back
    // out to the left rather than shrinking symmetrically in place.
    CGFloat gaugeFillFraction = dimMode == S15HEMWallpaperDimmingModeOn ? 0.5 : 0.0;
    [self.dimmingGaugeView setFillFraction:gaugeFillFraction animated:animated];

    UIColor *offColor = S15HEMOffWhiteBlackColor(self.traitCollection.userInterfaceStyle);
    self.dimmingModeButton.tintColor = offColor;
    self.dimmingSunGlyphView.tintColor = offColor;
    self.dimmingGaugeView.tintColor = offColor;
    self.brushButton.tintColor = offColor;

    S15HEMAppearanceMode currentMode = S15HEMAppearanceModePreference();
    [self.appearanceButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger idx, BOOL *stop) {
        BOOL selected = idx == (NSUInteger)currentMode;
        UIColor *outlineColor = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor.whiteColor colorWithAlphaComponent:0.20]
            : [UIColor.blackColor colorWithAlphaComponent:0.20];
        UIImageView *imageView = S15HEMAppearanceButtonImageView(button);
        UILabel *label = S15HEMAppearanceButtonTitleLabel(button);
        UIView *tile = S15HEMAppearanceButtonTile(button);
        UIView *border = S15HEMAppearanceButtonBorder(button);
        UIView *labelPill = S15HEMAppearanceButtonLabelPill(button);
        button.selected = selected;
        border.layer.borderWidth = 4.0;
        border.layer.borderColor = selected ? outlineColor.CGColor : UIColor.clearColor.CGColor;
        tile.backgroundColor = UIColor.clearColor;
        BOOL isTinted = (S15HEMAppearanceMode)idx == S15HEMAppearanceModeTinted;
        button.alpha = isTinted ? 0.35 : 1.0;
        imageView.alpha = 1.0;
        if (selected) {
            labelPill.backgroundColor = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:1.0 alpha:0.16]
                : [UIColor colorWithWhite:0.0 alpha:0.10];
        } else {
            labelPill.backgroundColor = UIColor.clearColor;
        }
        // Selected label: pure white/black, full opacity. Unselected: the
        // off-color AND a touch of transparency layered on top — the
        // combination sells the "dimmed/inactive" look better than either
        // alone.
        label.textColor = selected
            ? S15HEMPureWhiteBlackColor(self.traitCollection.userInterfaceStyle)
            : [S15HEMOffWhiteBlackColor(self.traitCollection.userInterfaceStyle) colorWithAlphaComponent:0.82];
    }];

    [self updateSliderSectionStateAnimated:animated];
    [self updateSheetHeightAnimated:animated];
}

- (void)refreshControlState {
    [self refreshControlStateAnimated:NO];
}

- (void)iconSizeChanged:(UISegmentedControl *)control {
    S15HEMSetIconSizePreference(control.selectedSegmentIndex == 1 ? S15HEMIconSizeModeLarge : S15HEMIconSizeModeSmall);
    S15HEMApplyIconAppearanceToAllVisibleViews(YES);
    S15HEMRefreshHomeScreenIconLists(YES);
    dispatch_async(dispatch_get_main_queue(), ^{
        S15HEMApplyIconAppearanceToAllVisibleViews(YES);
        S15HEMRefreshHomeScreenIconLists(YES);
    });
    [self refreshControlState];
}

- (void)cycleWallpaperDimmingMode {
    S15HEMWallpaperDimmingMode mode = S15HEMWallpaperDimmingPreference();
    BOOL turningOn = mode == S15HEMWallpaperDimmingModeOff;
    mode = turningOn ? S15HEMWallpaperDimmingModeOn : S15HEMWallpaperDimmingModeOff;
    S15HEMSetWallpaperDimmingPreference(mode);
    S15HEMApplyWallpaperDimmingForStyle(self.traitCollection.userInterfaceStyle);
    S15HEMApplyWallpaperDimmingToHomeScreen();

    // Matches the real OS: turning dimming ON rotates the glyph clockwise;
    // turning it OFF rotates back counter-clockwise to the original
    // orientation. Only the sun glyph rotates — dimmingGaugeView is a
    // separate sibling subview of the button, so this transform never
    // touches the fill indicator. (CGAffineTransformMakeRotation uses
    // UIKit's y-down coordinate space, where a positive angle is clockwise.)
    _dimmingGlyphRotation = turningOn ? M_PI_4 : 0.0;
    CGFloat targetRotation = _dimmingGlyphRotation;
    UIImageView *glyphView = self.dimmingSunGlyphView;
    [UIView animateWithDuration:0.32
                          delay:0.0
         usingSpringWithDamping:0.72
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        glyphView.transform = CGAffineTransformMakeRotation(targetRotation);
    } completion:nil];

    [self refreshControlState];
}

- (void)appearanceButtonTapped:(UIControl *)control {
    NSUInteger index = (NSUInteger)control.tag;
    if (index >= self.appearanceButtons.count) return;
    S15HEMAppearanceMode mode = (S15HEMAppearanceMode)index;
    // Tinted is a no-op for v1 — kept visible but inert (see refreshControlStateAnimated:
    // for the dimmed styling and userInteractionEnabled=NO on the button itself).
    if (mode == S15HEMAppearanceModeTinted) return;
    S15HEMAppearanceModeSetPreference(mode);
    if (S15HEMAppearanceButtonsDriveSystemAppearance() &&
        mode != S15HEMAppearanceModeTinted) {
        S15HEMSetSystemAppearanceModeValue(S15HEMSystemModeValueForAppearanceMode(mode));
    }
    S15HEMApplyAllCurrentSettings();
    [self refreshControlStateAnimated:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
        S15HEMApplyAllCurrentSettings();
        [self refreshControlStateAnimated:YES];
    });
}

- (void)updateSliderSectionStateAnimated:(BOOL)animated {
    BOOL expanded = S15HEMAppearanceModePreference() == S15HEMAppearanceModeTinted;
    if (_slidersExpanded == expanded && self.sliderSection.hidden == !expanded) {
        return;
    }

    _slidersExpanded = expanded;
    _sliderSectionHeightConstraint.constant = expanded ? 90.0 : 0.0;
    self.sliderSection.hidden = NO;
    NSTimeInterval duration = animated ? 0.28 : 0.0;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.sliderSection.alpha = expanded ? 1.0 : 0.0;
        self.sliderSection.transform = expanded ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0.0, 8.0);
        [self layoutIfNeeded];
    } completion:^(__unused BOOL finished) {
        self.sliderSection.hidden = !expanded;
    }];
}

- (void)updateSheetHeightAnimated:(BOOL)animated {
    BOOL expanded = S15HEMAppearanceModePreference() == S15HEMAppearanceModeTinted;
    CGFloat targetHeight = expanded ? S15HEMExpandedSheetHeight() : S15HEMCollapsedSheetHeight();
    if (fabs(_sheetHeightConstraint.constant - targetHeight) < 0.5) {
        return;
    }
    _sheetHeightConstraint.constant = targetHeight;
    if (animated) {
        [UIView animateWithDuration:0.32
                              delay:0.0
             usingSpringWithDamping:0.92
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
            [self layoutIfNeeded];
        } completion:nil];
    } else {
        [self layoutIfNeeded];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat hue = S15HEMWeatherHueValue();
    CGFloat saturation = 1.0 - S15HEMWeatherBrightnessValue();
    _brightnessGradientLayer.colors = @[
        (id)S15HEMColorForHue(hue, 1.0).CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor
    ];
    self.hueThumbView.backgroundColor = S15HEMColorForHue(hue, 1.0);
    self.brightnessThumbView.backgroundColor = S15HEMColorForHue(hue, saturation);
    [self layoutGradientBar:self.hueTrackView gradientLayer:_hueGradientLayer thumbView:self.hueThumbView value:S15HEMWeatherHueValue()];
    [self layoutGradientBar:self.brightnessTrackView gradientLayer:_brightnessGradientLayer thumbView:self.brightnessThumbView value:S15HEMWeatherBrightnessValue()];
}

- (void)layoutGradientBar:(UIView *)barView
            gradientLayer:(CAGradientLayer *)gradientLayer
                 thumbView:(UIView *)thumbView
                     value:(CGFloat)value {
    if (!barView || !gradientLayer || !thumbView) return;
    gradientLayer.frame = barView.bounds;
    CGFloat thumbSize = 32.0;
    CGFloat x = CGRectGetMinX(barView.frame) + floor((CGRectGetWidth(barView.frame) - thumbSize) * MAX(0.0, MIN(1.0, value)));
    CGFloat y = CGRectGetMidY(barView.frame) - thumbSize * 0.5;
    thumbView.frame = CGRectMake(x, y, thumbSize, thumbSize);
}

- (void)installSliderGestures {
    for (UIView *view in @[self.hueTrackView, self.hueThumbView, self.brightnessTrackView, self.brightnessThumbView]) {
        view.userInteractionEnabled = YES;
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSliderPan:)];
        [view addGestureRecognizer:pan];
    }
}

- (void)updateSliderValueForPoint:(CGPoint)point inView:(UIView *)view saveKey:(NSString *)key {
    CGFloat width = MAX(1.0, CGRectGetWidth(view.bounds) - 22.0);
    CGFloat value = (point.x - 11.0) / width;
    value = MAX(0.0, MIN(1.0, value));
    if ([key isEqualToString:kS15HEMWeatherBrightnessKey]) {
        S15HEMSetWeatherBrightnessValue(value);
    } else {
        S15HEMSetWeatherHueValue(value);
    }
    [self setNeedsLayout];
}

- (void)handleSliderPan:(UIPanGestureRecognizer *)pan {
    UIView *view = pan.view;
    if (!view) return;

    UIView *trackView = (view == self.brightnessTrackView || view == self.brightnessThumbView) ? self.brightnessTrackView : self.hueTrackView;
    NSString *key = (trackView == self.brightnessTrackView) ? kS15HEMWeatherBrightnessKey : kS15HEMWeatherHueKey;
    CGPoint converted = [pan locationInView:trackView];
    if (pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged) {
        [self updateSliderValueForPoint:converted inView:trackView saveKey:key];
        [self layoutIfNeeded];
    }
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    self.dimmingView = [[UIControl alloc] initWithFrame:self.bounds];
    self.dimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.dimmingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.0];
    [self.dimmingView addTarget:self action:@selector(dismissAnimated) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.dimmingView];

    UIBlurEffectStyle style = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
        ? UIBlurEffectStyleSystemChromeMaterialDark
        : UIBlurEffectStyleSystemChromeMaterialLight;
    self.sheetView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:style]];
    self.sheetView.translatesAutoresizingMaskIntoConstraints = NO;
    self.sheetView.layer.cornerRadius = 28.0;
    self.sheetView.layer.cornerCurve = kCACornerCurveContinuous;
    self.sheetView.layer.masksToBounds = YES;
    self.sheetView.clipsToBounds = YES;
    [self addSubview:self.sheetView];

    self.grabberView = [[UIView alloc] initWithFrame:CGRectZero];
    self.grabberView.translatesAutoresizingMaskIntoConstraints = NO;
    self.grabberView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:(self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.26 : 0.34)];
    self.grabberView.layer.cornerRadius = 2.5;
    self.grabberView.hidden = YES;
    [self.sheetView.contentView addSubview:self.grabberView];

    UIView *content = [[UIView alloc] initWithFrame:CGRectZero];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sheetView.contentView addSubview:content];

    self.dimmingModeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.dimmingModeButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.dimmingModeButton.tintColor = UIColor.labelColor;
    // Deliberately no UIButtonConfiguration/no configuration.image here: a
    // configuration-backed button rebuilds its internal image view on every
    // state change (touch down/up), which stomped our manual rotation
    // transform and made the glyph blink out every other tap. The glyph is
    // instead a plain UIImageView we own outright (dimmingSunGlyphView,
    // below) that nothing else ever touches.
    // 34pt wide/tall (see width/height constraints below) — radius = half the
    // side length so the selected-state background renders as a true circle.
    self.dimmingModeButton.layer.cornerRadius = 17.0;
    self.dimmingModeButton.layer.masksToBounds = YES;
    [self.dimmingModeButton addTarget:self action:@selector(cycleWallpaperDimmingMode) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:self.dimmingModeButton];

    // Base glyph is a custom rays-only render (see S15HEMSunRaysOnlyImage) —
    // deliberately NOT the "sun.max" SF Symbol, whose hub is permanently
    // solid regardless of variant. The fill *level* (empty/half/full) is
    // drawn entirely by dimmingGaugeView, which now owns that hub space
    // outright instead of fighting a glyph that was always opaque there.
    // Bumped from 18 to 21 for a slightly larger overall glyph (still well
    // clear of the 34pt circular button's edge).
    CGFloat sunGlyphPointSize = 21.0;
    self.dimmingSunGlyphView = [[UIImageView alloc] initWithImage:S15HEMSunRaysOnlyImage(sunGlyphPointSize)];
    self.dimmingSunGlyphView.translatesAutoresizingMaskIntoConstraints = NO;
    self.dimmingSunGlyphView.userInteractionEnabled = NO;
    self.dimmingSunGlyphView.tintColor = UIColor.labelColor;
    self.dimmingSunGlyphView.contentMode = UIViewContentModeCenter;
    [self.dimmingModeButton addSubview:self.dimmingSunGlyphView];
    [NSLayoutConstraint activateConstraints:@[
        [self.dimmingSunGlyphView.centerXAnchor constraintEqualToAnchor:self.dimmingModeButton.centerXAnchor],
        [self.dimmingSunGlyphView.centerYAnchor constraintEqualToAnchor:self.dimmingModeButton.centerYAnchor],
    ]];

    // Sized to sit flush inside the ring baked into S15HEMSunRaysOnlyImage:
    // ring center radius is pointSize*0.22, ring stroke width is
    // pointSize*0.085 (that's ringWidth there, unchanged even after rayWidth
    // was thickened separately — see the note there), so the ring's inner
    // edge radius is 0.22 - 0.085/2 = 0.1775. The flush-inset size left a
    // visible gap between the fill and the ring at this point size, so it's
    // nudged out by 2pt (to the ring's center radius, slightly under the
    // ring's outer edge) so the fill reads as fully meeting the ring.
    CGFloat gaugeDiameter = sunGlyphPointSize * (0.22 - 0.085 / 2.0) * 2.0 + 2.0;
    self.dimmingGaugeView = [[S15HEMSunGaugeView alloc] initWithFrame:CGRectZero];
    self.dimmingGaugeView.translatesAutoresizingMaskIntoConstraints = NO;
    self.dimmingGaugeView.tintColor = UIColor.labelColor;
    [self.dimmingModeButton addSubview:self.dimmingGaugeView];
    [NSLayoutConstraint activateConstraints:@[
        [self.dimmingGaugeView.centerXAnchor constraintEqualToAnchor:self.dimmingModeButton.centerXAnchor],
        [self.dimmingGaugeView.centerYAnchor constraintEqualToAnchor:self.dimmingModeButton.centerYAnchor],
        [self.dimmingGaugeView.widthAnchor constraintEqualToConstant:gaugeDiameter],
        [self.dimmingGaugeView.heightAnchor constraintEqualToConstant:gaugeDiameter],
    ]];

    self.iconSizeControl = [[UISegmentedControl alloc] initWithItems:@[@"Small", @"Large"]];
    self.iconSizeControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.iconSizeControl addTarget:self action:@selector(iconSizeChanged:) forControlEvents:UIControlEventValueChanged];
    self.iconSizeControl.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    self.iconSizeControl.selectedSegmentTintColor = [UIColor colorWithWhite:1.0 alpha:0.22];
    self.iconSizeControl.layer.cornerRadius = 16.0;
    self.iconSizeControl.layer.masksToBounds = YES;
    [content addSubview:self.iconSizeControl];

    UIButton *appearanceLight = S15HEMCreateAppearanceButton(self, S15HEMAppearanceModeLight);
    UIButton *appearanceDark = S15HEMCreateAppearanceButton(self, S15HEMAppearanceModeDark);
    UIButton *appearanceAuto = S15HEMCreateAppearanceButton(self, S15HEMAppearanceModeAutomatic);
    UIButton *appearanceTinted = S15HEMCreateAppearanceButton(self, S15HEMAppearanceModeTinted);
    self.appearanceButtons = @[appearanceLight, appearanceDark, appearanceAuto, appearanceTinted];

    self.headerRow = [[UIView alloc] initWithFrame:CGRectZero];
    self.headerRow.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.headerRow];

    self.brushButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.brushButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.brushButton.tintColor = UIColor.labelColor;
    self.brushButton.configuration = [UIButtonConfiguration plainButtonConfiguration];
    self.brushButton.configuration.contentInsets = NSDirectionalEdgeInsetsMake(6.0, 6.0, 6.0, 6.0);
    self.brushButton.configuration.imagePadding = 0.0;
    [self.brushButton setImage:[UIImage systemImageNamed:@"paintbrush.pointed.fill"] forState:UIControlStateNormal];
    self.brushButton.layer.cornerRadius = 14.0;
    self.brushButton.layer.masksToBounds = YES;
    // No-op for v1: kept visible (per design) but inert and visually dimmed.
    self.brushButton.userInteractionEnabled = NO;
    self.brushButton.alpha = 0.35;
    [self.headerRow addSubview:self.brushButton];

    UIView *appearanceContainer = [[UIView alloc] initWithFrame:CGRectZero];
    appearanceContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:appearanceContainer];
    self.appearanceRow = appearanceContainer;

    self.sliderSection = [[UIView alloc] initWithFrame:CGRectZero];
    self.sliderSection.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.sliderSection];

    UIStackView *appearanceButtonsRow = [[UIStackView alloc] initWithArrangedSubviews:self.appearanceButtons];
    appearanceButtonsRow.translatesAutoresizingMaskIntoConstraints = NO;
    appearanceButtonsRow.axis = UILayoutConstraintAxisHorizontal;
    appearanceButtonsRow.alignment = UIStackViewAlignmentTop;
    appearanceButtonsRow.distribution = UIStackViewDistributionFillEqually;
    appearanceButtonsRow.spacing = 8.0;
    [appearanceButtonsRow setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [appearanceButtonsRow setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [appearanceContainer addSubview:appearanceButtonsRow];

    [appearanceContainer setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [appearanceContainer setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.appearanceButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger idx, BOOL *stop) {
        [button setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
        [button setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    }];

    self.hueTrackView = [[UIView alloc] initWithFrame:CGRectZero];
    self.hueTrackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.hueTrackView.layer.cornerRadius = 16.0;
    self.hueTrackView.layer.masksToBounds = YES;
    self.hueTrackView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    [self.sliderSection addSubview:self.hueTrackView];

    self.brightnessTrackView = [[UIView alloc] initWithFrame:CGRectZero];
    self.brightnessTrackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.brightnessTrackView.layer.cornerRadius = 16.0;
    self.brightnessTrackView.layer.masksToBounds = YES;
    self.brightnessTrackView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    [self.sliderSection addSubview:self.brightnessTrackView];

    self.hueThumbView = [[UIView alloc] initWithFrame:CGRectZero];
    self.hueThumbView.translatesAutoresizingMaskIntoConstraints = YES;
    self.hueThumbView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
    self.hueThumbView.layer.cornerRadius = 16.0;
    self.hueThumbView.layer.borderWidth = 2.0;
    self.hueThumbView.layer.borderColor = UIColor.whiteColor.CGColor;
    self.hueThumbView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.hueThumbView.layer.shadowOpacity = 0.20;
    self.hueThumbView.layer.shadowRadius = 8.0;
    self.hueThumbView.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    [self.sliderSection addSubview:self.hueThumbView];

    self.brightnessThumbView = [[UIView alloc] initWithFrame:CGRectZero];
    self.brightnessThumbView.translatesAutoresizingMaskIntoConstraints = YES;
    self.brightnessThumbView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
    self.brightnessThumbView.layer.cornerRadius = 16.0;
    self.brightnessThumbView.layer.borderWidth = 2.0;
    self.brightnessThumbView.layer.borderColor = UIColor.whiteColor.CGColor;
    self.brightnessThumbView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.brightnessThumbView.layer.shadowOpacity = 0.20;
    self.brightnessThumbView.layer.shadowRadius = 8.0;
    self.brightnessThumbView.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    [self.sliderSection addSubview:self.brightnessThumbView];

    _hueGradientLayer = [CAGradientLayer layer];
    _hueGradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.96 green:0.43 blue:0.31 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.95 green:0.80 blue:0.26 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.36 green:0.84 blue:0.34 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.23 green:0.77 blue:0.95 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.36 green:0.41 blue:0.97 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.93 green:0.32 blue:0.88 alpha:1.0].CGColor
    ];
    _hueGradientLayer.startPoint = CGPointMake(0.0, 0.5);
    _hueGradientLayer.endPoint = CGPointMake(1.0, 0.5);
    [self.hueTrackView.layer addSublayer:_hueGradientLayer];

    _brightnessGradientLayer = [CAGradientLayer layer];
    _brightnessGradientLayer.colors = @[
        (id)[UIColor colorWithRed:0.10 green:0.58 blue:0.97 alpha:1.0].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:1.0].CGColor
    ];
    _brightnessGradientLayer.startPoint = CGPointMake(0.0, 0.5);
    _brightnessGradientLayer.endPoint = CGPointMake(1.0, 0.5);
    [self.brightnessTrackView.layer addSublayer:_brightnessGradientLayer];

    CGFloat maxHeight = MIN(320.0, CGRectGetHeight(UIScreen.mainScreen.bounds) * 0.38);
    _sheetHeightConstraint = [self.sheetView.heightAnchor constraintEqualToConstant:maxHeight];
    // Leading/trailing above are pinned to self's plain bounds, not the safe
    // area. Bottom must match that (self.bottomAnchor, not
    // safeAreaLayoutGuide.bottomAnchor) or the home-indicator safe-area
    // inset (~34pt) stacks on top of the -12 constant, leaving the sheet
    // sitting well above where the equal side/bottom gap implies.
    _sheetBottomConstraint = [self.sheetView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:maxHeight + 40.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.sheetView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12.0],
        [self.sheetView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12.0],
        _sheetHeightConstraint,
        _sheetBottomConstraint,

        [self.grabberView.topAnchor constraintEqualToAnchor:self.sheetView.contentView.topAnchor constant:10.0],
        [self.grabberView.centerXAnchor constraintEqualToAnchor:self.sheetView.contentView.centerXAnchor],
        [self.grabberView.widthAnchor constraintEqualToConstant:36.0],
        [self.grabberView.heightAnchor constraintEqualToConstant:5.0],

        [content.topAnchor constraintEqualToAnchor:self.sheetView.contentView.topAnchor constant:kS15HEMSheetContentTopOffset],
        [content.leadingAnchor constraintEqualToAnchor:self.sheetView.contentView.leadingAnchor constant:14.0],
        [content.trailingAnchor constraintEqualToAnchor:self.sheetView.contentView.trailingAnchor constant:-14.0],
        [content.bottomAnchor constraintEqualToAnchor:self.sheetView.contentView.bottomAnchor constant:-kS15HEMSheetContentBottomOffset],

        [self.dimmingModeButton.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [self.dimmingModeButton.centerYAnchor constraintEqualToAnchor:self.iconSizeControl.centerYAnchor],
        [self.dimmingModeButton.widthAnchor constraintEqualToConstant:34.0],
        [self.dimmingModeButton.heightAnchor constraintEqualToConstant:34.0],

        [self.iconSizeControl.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [self.iconSizeControl.topAnchor constraintEqualToAnchor:content.topAnchor constant:0.0],
        [self.iconSizeControl.widthAnchor constraintEqualToConstant:150.0],
        [self.iconSizeControl.heightAnchor constraintEqualToConstant:kS15HEMSheetIconRowHeight],

        [self.brushButton.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [self.brushButton.centerYAnchor constraintEqualToAnchor:self.iconSizeControl.centerYAnchor],
        [self.brushButton.widthAnchor constraintEqualToConstant:34.0],
        [self.brushButton.heightAnchor constraintEqualToConstant:34.0],

        [self.appearanceRow.topAnchor constraintEqualToAnchor:self.iconSizeControl.bottomAnchor constant:kS15HEMSheetIconRowToAppearanceGap],
        [self.appearanceRow.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [self.appearanceRow.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [self.appearanceRow.heightAnchor constraintEqualToConstant:kS15HEMSheetAppearanceRowHeight],

        [appearanceButtonsRow.topAnchor constraintEqualToAnchor:self.appearanceRow.topAnchor],
        [appearanceButtonsRow.leadingAnchor constraintEqualToAnchor:self.appearanceRow.leadingAnchor],
        [appearanceButtonsRow.trailingAnchor constraintEqualToAnchor:self.appearanceRow.trailingAnchor],
        [appearanceButtonsRow.bottomAnchor constraintEqualToAnchor:self.appearanceRow.bottomAnchor],

        [self.sliderSection.topAnchor constraintEqualToAnchor:self.appearanceRow.bottomAnchor constant:kS15HEMSheetAppearanceToSliderGap],
        [self.sliderSection.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [self.sliderSection.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [self.sliderSection.widthAnchor constraintEqualToAnchor:content.widthAnchor],
    ]];

    // Slider section's height alone (not a bottom-to-content pin) determines
    // how far content extends — the sheet height itself
    // (S15HEMCollapsedSheetHeight / S15HEMExpandedSheetHeight) is what
    // guarantees content ends exactly at the card's bottom edge, so we don't
    // double-pin the same edge two different ways.
    _sliderSectionHeightConstraint = [self.sliderSection.heightAnchor constraintEqualToConstant:kS15HEMSheetSliderSectionCollapsedHeight];
    _sliderSectionHeightConstraint.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [self.hueTrackView.topAnchor constraintEqualToAnchor:self.sliderSection.topAnchor constant:1.0],
        [self.hueTrackView.leadingAnchor constraintEqualToAnchor:self.sliderSection.leadingAnchor],
        [self.hueTrackView.trailingAnchor constraintEqualToAnchor:self.sliderSection.trailingAnchor],
        [self.hueTrackView.heightAnchor constraintEqualToConstant:32.0],

        [self.brightnessTrackView.topAnchor constraintEqualToAnchor:self.hueTrackView.bottomAnchor constant:8.0],
        [self.brightnessTrackView.leadingAnchor constraintEqualToAnchor:self.sliderSection.leadingAnchor],
        [self.brightnessTrackView.trailingAnchor constraintEqualToAnchor:self.sliderSection.trailingAnchor],
        [self.brightnessTrackView.heightAnchor constraintEqualToConstant:32.0],
    ]];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.delegate = self;
    [self.sheetView addGestureRecognizer:pan];
    [self refreshControlState];
    [self installSliderGestures];
    return self;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

- (void)presentAnimated {
    if (self.dismissing) return;
    [self layoutIfNeeded];
    _sheetBottomConstraint.constant = -12.0;
    [UIView animateWithDuration:0.42
                          delay:0.0
         usingSpringWithDamping:0.88
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.dimmingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.18];
        [self layoutIfNeeded];
    } completion:nil];
}

- (void)dismissAnimated {
    if (self.dismissing) return;
    self.dismissing = YES;
    UIWindow *hostWindow = (UIWindow *)self.superview;
    UIWindow *presentationWindow = objc_getAssociatedObject(self, kS15HEMSheetPresentationWindowKey);
    _sheetBottomConstraint.constant = _sheetHeightConstraint.constant + 40.0;
    [UIView animateWithDuration:0.24
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.dimmingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.0];
        [self layoutIfNeeded];
    } completion:^(__unused BOOL finished) {
        if (hostWindow) {
            objc_setAssociatedObject(hostWindow, kS15HEMActiveSheetKey, nil, OBJC_ASSOCIATION_ASSIGN);
        }
        objc_setAssociatedObject(UIApplication.sharedApplication, kS15HEMActiveSheetKey, nil, OBJC_ASSOCIATION_ASSIGN);
        [self removeFromSuperview];
        if (presentationWindow && UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            presentationWindow.hidden = YES;
        }
        objc_setAssociatedObject(self, kS15HEMSheetPresentationWindowKey, nil, OBJC_ASSOCIATION_ASSIGN);
    }];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self];
    CGPoint velocity = [pan velocityInView:self];
    if (pan.state == UIGestureRecognizerStateChanged) {
        _sheetBottomConstraint.constant = MAX(-12.0, -12.0 + translation.y);
        self.dimmingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:MAX(0.0, 0.18 - translation.y / 700.0)];
        [self layoutIfNeeded];
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        if (translation.y > 90.0 || velocity.y > 900.0) {
            [self dismissAnimated];
            return;
        }
        _sheetBottomConstraint.constant = -12.0;
        [UIView animateWithDuration:0.3
                              delay:0.0
             usingSpringWithDamping:0.84
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            self.dimmingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.18];
            [self layoutIfNeeded];
        } completion:nil];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        [self updateMaterialForCurrentTraitAnimated:YES];
        // Dimming is a fixed on/off user choice now (no more Auto), so it no
        // longer needs to be re-applied when the system trait changes.
    }
    [self refreshControlStateAnimated:YES];
}

@end

static void S15HEMPresentCustomizeSheet(UIView *button) {
    S15HEMCustomizeSheetView *globalExisting = objc_getAssociatedObject(UIApplication.sharedApplication, kS15HEMActiveSheetKey);
    if (globalExisting && globalExisting.superview) return;

    UIWindow *window = S15HEMCreatePresentationWindowForButton(button);
    if (!window) return;
    S15HEMCustomizeSheetView *existing = objc_getAssociatedObject(window, kS15HEMActiveSheetKey);
    if (existing && existing.superview) return;

    S15HEMCustomizeSheetView *sheet = [[S15HEMCustomizeSheetView alloc] initWithFrame:window.bounds];
    objc_setAssociatedObject(sheet, kS15HEMSheetPresentationWindowKey, window, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(window, kS15HEMActiveSheetKey, sheet, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(UIApplication.sharedApplication, kS15HEMActiveSheetKey, sheet, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [window addSubview:sheet];
    [sheet presentAnimated];
}

static UIMenu *S15HEMMenuForButton(UIView *button) {
    __weak UIView *weakButton = button;

    UIAction *addWidget = [UIAction actionWithTitle:@"Add Widget"
                                              image:[UIImage systemImageNamed:@"plus.circle"]
                                         identifier:nil
                                            handler:^(__kindof UIAction *a) {
        S15HEMTriggerWidgetAction(weakButton);
    }];

    UIAction *customize = [UIAction actionWithTitle:@"Customize"
                                              image:[UIImage systemImageNamed:@"paintbrush"]
                                         identifier:nil
                                            handler:^(__kindof UIAction *a) {
        S15HEMPresentCustomizeSheet(weakButton);
    }];

    UIAction *editPages = [UIAction actionWithTitle:@"Edit Pages"
                                              image:[UIImage systemImageNamed:@"square.grid.3x1.below.line.grid.1x2"]
                                         identifier:nil
                                            handler:^(__kindof UIAction *a) {
        S15HEMTriggerEditPages(weakButton);
    }];

    UIAction *editWallpaper = [UIAction actionWithTitle:@"Edit Wallpaper"
                                                  image:[UIImage systemImageNamed:@"photo.on.rectangle"]
                                             identifier:nil
                                                handler:^(__kindof UIAction *a) {
        S15HEMTriggerWallpaper(weakButton);
    }];

    return [UIMenu menuWithTitle:@"" children:@[addWidget, customize, editWallpaper, editPages]];
}

%group S15HEMPRUIHooks

%hook PRUIModalController

- (void)modalRemoteViewController:(id)remoteViewController willDismissWithResponse:(id)response {
    S15HEMHandleWallpaperModalWillDismiss((id)self, response);
    %orig(remoteViewController, response);
}

- (void)modalRemoteViewController:(id)remoteViewController didDismissWithResponse:(id)response {
    %orig(remoteViewController, response);
    S15HEMHandleWallpaperModalDidDismiss((id)self, response);
}

%end

%end

static void S15HEMInstallWallpaperModalHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class modalControllerClass = NSClassFromString(@"PRUIModalController");
        if (!modalControllerClass) {
            return;
        }
        %init(S15HEMPRUIHooks, PRUIModalController = modalControllerClass);
    });
}

static void *kS15HEMEditingLabelOverlayKey = &kS15HEMEditingLabelOverlayKey;
static void *kS15HEMEditingLabelEffectViewKey = &kS15HEMEditingLabelEffectViewKey;

static BOOL S15HEMViewLooksLikeEditingGlyph(UIView *view) {
    if (!view) return NO;
    if ([view isKindOfClass:UIImageView.class]) return YES;
    NSString *className = NSStringFromClass(view.class);
    return [className containsString:@"Symbol"] ||
           [className containsString:@"Glyph"] ||
           [className containsString:@"Image"];
}

static void S15HEMHideEditingGlyphSubviews(UIView *root) {
    for (UIView *subview in root.subviews) {
        if (S15HEMViewLooksLikeEditingGlyph(subview)) {
            subview.alpha = 0.0;
        }
        S15HEMHideEditingGlyphSubviews(subview);
    }
}

static UILabel *S15HEMFindVisibleLabelWithText(UIView *root, NSString *text) {
    if (!root || text.length == 0) return nil;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    while (queue.count) {
        UIView *candidate = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if (candidate.hidden || candidate.alpha <= 0.01) continue;
        if ([candidate isKindOfClass:UILabel.class]) {
            UILabel *label = (UILabel *)candidate;
            if ([label.text isEqualToString:text]) return label;
        }
        [queue addObjectsFromArray:candidate.subviews];
    }
    return nil;
}

static UIButton *S15HEMFindVisibleButtonWithTitle(UIView *root, NSString *title) {
    if (!root || title.length == 0) return nil;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    while (queue.count) {
        UIView *candidate = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if (candidate.hidden || candidate.alpha <= 0.01) continue;
        if ([candidate isKindOfClass:UIButton.class]) {
            UIButton *button = (UIButton *)candidate;
            NSString *buttonTitle = [button titleForState:UIControlStateNormal] ?: button.titleLabel.text;
            if ([buttonTitle isEqualToString:title]) return button;
        }
        [queue addObjectsFromArray:candidate.subviews];
    }
    return nil;
}

static UILabel *S15HEMFindDoneLabelForEditingButton(UIButton *editButton) {
    for (UIWindow *window in S15HEMAllWindows()) {
        if (!window || window.hidden || window.alpha <= 0.01) continue;
        UILabel *label = S15HEMFindVisibleLabelWithText(window, @"Done");
        if (label) return label;
        UIButton *doneButton = S15HEMFindVisibleButtonWithTitle(window, @"Done");
        if (doneButton.titleLabel) return doneButton.titleLabel;
    }
    return nil;
}

static UIVisualEffect *S15HEMEditingLabelVibrancyEffect(void) {
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialLight];
    if ([UIVibrancyEffect respondsToSelector:@selector(effectForBlurEffect:style:)]) {
        return [UIVibrancyEffect effectForBlurEffect:blurEffect style:UIVibrancyEffectStyleLabel];
    }
    return [UIVibrancyEffect effectForBlurEffect:blurEffect];
}

static void S15HEMApplyDoneStyleToEditingLabel(UILabel *label, UIButton *editButton) {
    UILabel *doneLabel = S15HEMFindDoneLabelForEditingButton(editButton);
    if (doneLabel) {
        CGFloat pointSize = MAX(1.0, doneLabel.font.pointSize + kS15HEMEditingLabelFontDelta);
        UIFontDescriptor *descriptor = doneLabel.font.fontDescriptor;
        NSDictionary *traits = [descriptor objectForKey:UIFontDescriptorTraitsAttribute];
        CGFloat weight = [traits[UIFontWeightTrait] doubleValue];
        UIFontDescriptor *weightedDescriptor = [descriptor fontDescriptorByAddingAttributes:@{
            UIFontDescriptorTraitsAttribute: @{ UIFontWeightTrait: @(MIN(weight + 0.08, 1.0)) }
        }];
        label.font = [UIFont fontWithDescriptor:weightedDescriptor size:pointSize];
        label.textAlignment = doneLabel.textAlignment;
    } else {
        label.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
        label.textAlignment = NSTextAlignmentCenter;
    }
    label.textColor = UIColor.labelColor;
}

static UILabel *S15HEMEditingLabelOverlayForButton(UIButton *button) {
    UILabel *label = objc_getAssociatedObject(button, kS15HEMEditingLabelOverlayKey);
    if (!label) {
        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.text = @"Edit";
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
        label.textColor = UIColor.labelColor;
        label.backgroundColor = UIColor.clearColor;
        label.userInteractionEnabled = NO;
        label.hidden = YES;
        objc_setAssociatedObject(button, kS15HEMEditingLabelOverlayKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    S15HEMApplyDoneStyleToEditingLabel(label, button);
    return label;
}

static UIVisualEffectView *S15HEMEditingLabelEffectViewForButton(UIButton *button) {
    UIVisualEffectView *effectView = objc_getAssociatedObject(button, kS15HEMEditingLabelEffectViewKey);
    if (!effectView) {
        effectView = [[UIVisualEffectView alloc] initWithEffect:S15HEMEditingLabelVibrancyEffect()];
        effectView.backgroundColor = UIColor.clearColor;
        effectView.userInteractionEnabled = NO;
        effectView.hidden = YES;
        effectView.clipsToBounds = NO;
        objc_setAssociatedObject(button, kS15HEMEditingLabelEffectViewKey, effectView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        effectView.effect = S15HEMEditingLabelVibrancyEffect();
    }
    return effectView;
}

static void S15HEMRemoveEditingLabelOverlay(UIButton *button) {
    UILabel *label = objc_getAssociatedObject(button, kS15HEMEditingLabelOverlayKey);
    if (label) {
        label.hidden = YES;
        [label removeFromSuperview];
    }
    UIVisualEffectView *effectView = objc_getAssociatedObject(button, kS15HEMEditingLabelEffectViewKey);
    if (effectView) {
        effectView.hidden = YES;
        [effectView removeFromSuperview];
    }
}

static BOOL S15HEMShouldShowEditingLabelForButton(UIButton *button) {
    if (!button || !button.window || !button.superview) return NO;
    if (button.hidden || button.alpha <= 0.01 || !button.userInteractionEnabled) return NO;
    if (CGRectIsEmpty(button.bounds)) return NO;
    for (UIView *ancestor = button.superview; ancestor && ancestor != button.window; ancestor = ancestor.superview) {
        if (ancestor.hidden || ancestor.alpha <= 0.01) return NO;
    }
    return YES;
}

static void S15HEMUpdateEditingWidgetButtonVisuals(UIButton *button) {
    if (!S15HEMShouldShowEditingLabelForButton(button)) {
        S15HEMRemoveEditingLabelOverlay(button);
        return;
    }

    UILabel *label = S15HEMEditingLabelOverlayForButton(button);
    UIVisualEffectView *effectView = S15HEMEditingLabelEffectViewForButton(button);
    if (effectView.superview != button.superview) {
        [effectView removeFromSuperview];
        [button.superview addSubview:effectView];
    }
    if (label.superview != effectView.contentView) {
        [label removeFromSuperview];
        [effectView.contentView addSubview:label];
    }

    [label sizeToFit];
    CGFloat width = MAX(48.0, ceil(label.bounds.size.width) + 18.0);
    CGFloat height = MAX(CGRectGetHeight(button.bounds), ceil(label.bounds.size.height) + 8.0);
    CGPoint center = CGPointMake(CGRectGetMidX(button.frame) + kS15HEMEditingLabelXOffset,
                                 CGRectGetMidY(button.frame) + kS15HEMEditingLabelYOffset);
    label.frame = CGRectMake(round(center.x - width * 0.5),
                             round(center.y - height * 0.5),
                             width,
                             height);
    effectView.frame = label.frame;
    label.frame = effectView.bounds;
    effectView.hidden = NO;
    label.hidden = NO;
    [button.superview bringSubviewToFront:effectView];
}

static void S15HEMUpdateEditingWidgetButtonsInView(UIView *root) {
    if (!root) return;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    Class editingButtonClass = NSClassFromString(@"SBHEditingWidgetButton");
    while (queue.count) {
        UIView *candidate = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ((editingButtonClass && [candidate isKindOfClass:editingButtonClass]) ||
            [NSStringFromClass(candidate.class) isEqualToString:@"SBHEditingWidgetButton"]) {
            S15HEMUpdateEditingWidgetButtonVisuals((UIButton *)candidate);
        }
        [queue addObjectsFromArray:candidate.subviews];
    }
}

static void S15HEMUpdateAllEditingWidgetButtonVisuals(void) {
    for (UIWindow *window in S15HEMAllWindows()) {
        if (!window || window.hidden || window.alpha <= 0.01) continue;
        S15HEMUpdateEditingWidgetButtonsInView(window);
    }
}

static void S15HEMStyleEditingWidgetButtonAsEdit(UIButton *button) {
    if (!button) return;
    button.userInteractionEnabled = YES;
    [button setTitle:nil forState:UIControlStateNormal];
    [button setTitleColor:UIColor.clearColor forState:UIControlStateNormal];
    button.tintColor = UIColor.clearColor;
    button.imageView.alpha = 0.0;
    S15HEMHideEditingGlyphSubviews(button);
    S15HEMUpdateEditingWidgetButtonVisuals(button);
}

static void S15HEMConfigureEditingWidgetButton(UIButton *button) {
    if (!button.window) return;
    if (![button respondsToSelector:@selector(setMenu:)] ||
        ![button respondsToSelector:@selector(setShowsMenuAsPrimaryAction:)]) {
        return;
    }

    S15HEMStyleEditingWidgetButtonAsEdit(button);
    button.backgroundColor = UIColor.clearColor;
    button.menu = S15HEMMenuForButton(button);
    button.showsMenuAsPrimaryAction = YES;
    if ([button respondsToSelector:@selector(setChangesSelectionAsPrimaryAction:)]) {
        button.changesSelectionAsPrimaryAction = NO;
    }
}

static CGRect S15HEMExpandedEditingWidgetHitFrame(UIButton *button) {
    UIWindow *window = button.window;
    if (!window || !button.superview) return CGRectInset(button.bounds, -24.0, -18.0);

    CGRect windowBounds = window.bounds;
    CGRect buttonFrame = [button.superview convertRect:button.frame toView:window];
    CGFloat safeTop = window.safeAreaInsets.top;
    CGFloat height = MAX(CGRectGetMaxY(buttonFrame) + 18.0, safeTop + 58.0);
    height = MIN(height, CGRectGetHeight(windowBounds));
    CGFloat width = MIN(MAX(150.0, CGRectGetWidth(windowBounds) * 0.44), CGRectGetWidth(windowBounds));
    BOOL buttonOnRight = CGRectGetMidX(buttonFrame) > CGRectGetMidX(windowBounds);
    CGFloat x = buttonOnRight ? CGRectGetWidth(windowBounds) - width : 0.0;
    CGRect earFrame = CGRectMake(x, 0.0, width, height);
    return [window convertRect:earFrame toView:button];
}

%hook SBHEditingWidgetButton

- (void)didMoveToWindow {
    %orig;
    if (!S15HEMIsSpringBoard()) return;
    if (!((UIButton *)self).window) {
        S15HEMRemoveEditingLabelOverlay((UIButton *)self);
        return;
    }
    S15HEMLogIOS15CompatibilityProbe((UIView *)self);
    S15HEMConfigureEditingWidgetButton((UIButton *)self);
    __weak UIButton *weakButton = (UIButton *)self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIButton *button = weakButton;
        if (button.window) S15HEMUpdateEditingWidgetButtonVisuals(button);
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIButton *button = weakButton;
        if (button.window) S15HEMUpdateEditingWidgetButtonVisuals(button);
    });
}

- (void)layoutSubviews {
    %orig;
    if (!S15HEMIsSpringBoard()) return;
    S15HEMHideEditingGlyphSubviews((UIView *)self);
    S15HEMUpdateEditingWidgetButtonVisuals((UIButton *)self);
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (!S15HEMIsSpringBoard()) return %orig(point, event);
    UIButton *button = (UIButton *)self;
    if (!button.window || button.hidden || button.alpha <= 0.01) return %orig(point, event);
    return CGRectContainsPoint(S15HEMExpandedEditingWidgetHitFrame(button), point);
}

- (void)setHidden:(BOOL)hidden {
    %orig(hidden);
    if (!S15HEMIsSpringBoard()) return;
    if (hidden) S15HEMRemoveEditingLabelOverlay((UIButton *)self);
    else S15HEMUpdateEditingWidgetButtonVisuals((UIButton *)self);
}

- (void)setAlpha:(CGFloat)alpha {
    %orig(alpha);
    if (!S15HEMIsSpringBoard()) return;
    if (alpha <= 0.01) S15HEMRemoveEditingLabelOverlay((UIButton *)self);
    else S15HEMUpdateEditingWidgetButtonVisuals((UIButton *)self);
}

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled {
    %orig(userInteractionEnabled);
    if (!S15HEMIsSpringBoard()) return;
    if (!userInteractionEnabled) S15HEMRemoveEditingLabelOverlay((UIButton *)self);
    else S15HEMUpdateEditingWidgetButtonVisuals((UIButton *)self);
}

// SpringBoard occasionally reasserts its own default (widgets-only) menu on
// this same button well after didMoveToWindow already fired -- that method
// only runs once per add-to-window, but the reset happens on some other,
// later internal pass. The install above used to be one-shot (guarded by an
// "already installed" flag), so whichever of us touched .menu last simply
// won -- which made the "+" button intermittently pop the system's own
// widgets-only menu instead of ours, with no consistent trigger. Intercepting
// setMenu:/setShowsMenuAsPrimaryAction: directly instead means our
// configuration wins unconditionally, no matter when or how many times
// SpringBoard tries to reassert its own -- there's no longer a race to lose.
- (void)setMenu:(UIMenu *)menu {
    if (!S15HEMIsSpringBoard()) {
        %orig(menu);
        return;
    }
    %orig(S15HEMMenuForButton((UIButton *)self));
}

- (void)setShowsMenuAsPrimaryAction:(BOOL)showsMenuAsPrimaryAction {
    if (!S15HEMIsSpringBoard()) {
        %orig(showsMenuAsPrimaryAction);
        return;
    }
    %orig(YES);
}

%end

%hook SBIconView

- (void)didMoveToWindow {
    %orig;
    if (!S15HEMIsSpringBoard()) return;
    __weak UIView *weakIconView = (UIView *)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *iconView = weakIconView;
        if (!iconView || !iconView.window) return;
        S15HEMApplyIconAppearanceToView(iconView);
    });
}

- (void)configureSize {
    %orig;
    if (!S15HEMIsSpringBoard()) return;
    S15HEMApplyIconAppearanceToView((UIView *)self);
}

- (void)layoutSubviews {
    %orig;
    if (!S15HEMIsSpringBoard()) return;
    UIView *iconView = (UIView *)self;
    if (!sS15HEMLoggedIconLayoutSample) {
        sS15HEMLoggedIconLayoutSample = YES;
        S15HEMAppendTransitionProbe(@"SBIconView.layoutSubviews.sample",
                                    iconView,
                                    [NSString stringWithFormat:@"mode=%ld transform={%.3f,%.3f,%.3f,%.3f}",
                                     (long)S15HEMIconSizePreference(),
                                     iconView.transform.a,
                                     iconView.transform.b,
                                     iconView.transform.c,
                                     iconView.transform.d]);
    }
    if (S15HEMShouldProcessIconView(iconView)) {
        S15HEMApplyIconAppearanceToView(iconView);
        return;
    }
    // Non-processable (widget) views: hide their labels in large mode too.
    // Animate only when the mode actually changes, same logic as the regular icon path.
    {
        S15HEMIconSizeMode currentMode = S15HEMIconSizePreference();
        BOOL large = currentMode == S15HEMIconSizeModeLarge;
        NSNumber *lastModeVal = objc_getAssociatedObject(iconView, kS15HEMLastAppliedIconModeKey);
        BOOL modeChanged = lastModeVal != nil && (NSInteger)lastModeVal.integerValue != (NSInteger)currentMode;
        S15HEMSetHiddenForLabelsInView(iconView, large, modeChanged, 2);
        objc_setAssociatedObject(iconView, kS15HEMLastAppliedIconModeKey, @(currentMode), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // Defensive reset: a widget whose SBIconView frame was still small on an earlier
    // layout pass may have had our scale incorrectly applied. Now that its frame is
    // properly large, detect and undo our specific scale transform.
    CGFloat scale = S15HEMCurrentIconScale();
    if (scale > 1.0) {
        CGAffineTransform t = iconView.transform;
        if (fabs(t.a - scale) < 0.01 && fabs(t.d - scale) < 0.01) {
            iconView.transform = CGAffineTransformIdentity;
        }
        for (UIView *sub in iconView.subviews) {
            CGAffineTransform st = sub.transform;
            if (fabs(st.a - scale) < 0.01 && fabs(st.d - scale) < 0.01) {
                sub.transform = CGAffineTransformIdentity;
            }
        }
    }
}

%end

%hook UIView

- (void)setTransform:(CGAffineTransform)transform {
    if (!S15HEMIsSpringBoard()) {
        %orig(transform);
        return;
    }

    UIView *selfView = (UIView *)self;
    BOOL applyingManagedTransform = [objc_getAssociatedObject(selfView, kS15HEMApplyingManagedTransformKey) boolValue];
    if (!applyingManagedTransform) {
        NSString *className = [NSString stringWithUTF8String:object_getClassName(selfView)];
        if ([className containsString:@"TouchPassThrough"]) {
            UIView *ownerIconView = S15HEMNearestIconViewForView(selfView);
            if (ownerIconView && S15HEMShouldProcessIconView(ownerIconView) &&
                S15HEMIconSizePreference() == S15HEMIconSizeModeLarge) {
                CGFloat incomingScaleX = S15HEMTransformScaleX(transform);
                CGFloat incomingScaleY = S15HEMTransformScaleY(transform);
                if (fabs(incomingScaleX - 1.0) < 0.03 || fabs(incomingScaleY - 1.0) < 0.03) {
                    S15HEMAppendTransitionProbe(@"UIView.setTransform.container",
                                                selfView,
                                                [NSString stringWithFormat:@"incoming={%.3f,%.3f} outgoing={%.3f,%.3f}",
                                                 incomingScaleX, incomingScaleY,
                                                 S15HEMTransformScaleX(S15HEMManagedTransformForIncomingTransform(transform)),
                                                 S15HEMTransformScaleY(S15HEMManagedTransformForIncomingTransform(transform))]);
                }
                transform = S15HEMManagedTransformForIncomingTransform(transform);
            }
        }
    }

    %orig(transform);
}

%end

%hook SBIconImageView

- (CGSize)intrinsicContentSize {
    CGSize original = %orig;
    if (!S15HEMIsSpringBoard()) return original;
    if (!S15HEMShouldProcessContentView((UIView *)self)) return original;
    return S15HEMScaledIconSize(original);
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize original = %orig(size);
    if (!S15HEMIsSpringBoard()) return original;
    if (!S15HEMShouldProcessContentView((UIView *)self)) return original;
    return S15HEMScaledIconSize(original);
}

- (void)setTransform:(CGAffineTransform)transform {
    if (!S15HEMIsSpringBoard()) {
        %orig(transform);
        return;
    }

    UIView *selfView = (UIView *)self;
    BOOL applyingManagedTransform = [objc_getAssociatedObject(selfView, kS15HEMApplyingManagedTransformKey) boolValue];
    if (!applyingManagedTransform &&
        S15HEMShouldProcessContentView(selfView) &&
        S15HEMIconSizePreference() == S15HEMIconSizeModeLarge) {
        CGFloat incomingScaleX = S15HEMTransformScaleX(transform);
        CGFloat incomingScaleY = S15HEMTransformScaleY(transform);
        if (fabs(incomingScaleX - 1.0) < 0.03 || fabs(incomingScaleY - 1.0) < 0.03) {
            S15HEMAppendTransitionProbe(@"SBIconImageView.setTransform",
                                        selfView,
                                        [NSString stringWithFormat:@"incoming={%.3f,%.3f} outgoing={%.3f,%.3f}",
                                         incomingScaleX, incomingScaleY,
                                         S15HEMTransformScaleX(S15HEMManagedTransformForIncomingTransform(transform)),
                                         S15HEMTransformScaleY(S15HEMManagedTransformForIncomingTransform(transform))]);
        }
        transform = S15HEMManagedTransformForIncomingTransform(transform);
    }

    %orig(transform);
}

- (void)layoutSubviews {
    %orig;
    if (!S15HEMIsSpringBoard()) return;
    UIView *selfView = (UIView *)self;
    if (!sS15HEMLoggedImageLayoutSample) {
        sS15HEMLoggedImageLayoutSample = YES;
        S15HEMAppendTransitionProbe(@"SBIconImageView.layoutSubviews.sample",
                                    selfView,
                                    [NSString stringWithFormat:@"transform={%.3f,%.3f,%.3f,%.3f}",
                                     selfView.transform.a,
                                     selfView.transform.b,
                                     selfView.transform.c,
                                     selfView.transform.d]);
    }
    if (S15HEMShouldProcessContentView(selfView)) {
        CGFloat scale = S15HEMCurrentIconScale();
        objc_setAssociatedObject(selfView, kS15HEMApplyingManagedTransformKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        selfView.transform = CGAffineTransformMakeScale(scale, scale);
        objc_setAssociatedObject(selfView, kS15HEMApplyingManagedTransformKey, nil, OBJC_ASSOCIATION_ASSIGN);
        return;
    }
    // Defensive reset: undo our specific scale if it was incorrectly applied to a widget.
    // BUT: skip the reset if the owning SBIconView is a legitimate icon (folder, app icon, etc.)
    // — SBFolderIconImageView and live-icon subclasses hit this branch because ShouldProcessContentView
    // returns NO for them, but their parent SBIconView path already applied the correct scale.
    UIView *ownerIconView = S15HEMNearestIconViewForView(selfView);
    if (ownerIconView && S15HEMShouldProcessIconView(ownerIconView)) {
        return; // owner is a valid icon — SBIconView path handled it, don't touch the transform
    }
    CGFloat scale = S15HEMCurrentIconScale();
    if (scale > 1.0) {
        CGAffineTransform t = selfView.transform;
        if (fabs(t.a - scale) < 0.01 && fabs(t.d - scale) < 0.01) {
            selfView.transform = CGAffineTransformIdentity;
        }
    }
}

%end

%hook UIView

- (void)setAlpha:(CGFloat)alpha {
    if (!S15HEMIsSpringBoard()) {
        %orig(alpha);
        return;
    }

    UIView *selfView = (UIView *)self;
    BOOL applyingManagedAlpha = [objc_getAssociatedObject(selfView, kS15HEMApplyingManagedAlphaKey) boolValue];
    if (!applyingManagedAlpha && S15HEMShouldForceHiddenForLabelView(selfView)) {
        if (alpha > 0.01) {
            S15HEMAppendTransitionProbe(@"labelView.setAlpha",
                                        selfView,
                                        [NSString stringWithFormat:@"incoming=%.3f forced=0.000 class=%@",
                                         alpha,
                                         NSStringFromClass(selfView.class)]);
        }
        alpha = 0.0;
    }

    %orig(alpha);
}

- (void)setHidden:(BOOL)hidden {
    if (!S15HEMIsSpringBoard()) {
        %orig(hidden);
        return;
    }

    UIView *selfView = (UIView *)self;
    NSString *className = NSStringFromClass(selfView.class);
    BOOL applyingManagedAlpha = [objc_getAssociatedObject(selfView, kS15HEMApplyingManagedAlphaKey) boolValue];
    if (!applyingManagedAlpha && S15HEMShouldForceHiddenForLabelView(selfView)) {
        hidden = YES;
    }

    %orig(hidden);

    if ([className containsString:@"HomeScreen"] ||
        [className containsString:@"RootFolder"] ||
        [className containsString:@"FolderContainer"] ||
        [className containsString:@"IconContent"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            S15HEMUpdateAllEditingWidgetButtonVisuals();
        });
    }
}

%end

%hook UIWindow

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!S15HEMIsSpringBoard()) return;

    UIWindow *window = (UIWindow *)self;
    NSString *className = NSStringFromClass(window.class);
    if (![className isEqualToString:@"SBHomeScreenWindow"] && window != S15HEMHomeScreenWindow()) return;
    S15HEMHandleHomeScreenTraitChange(previousTraitCollection, window.traitCollection);
    S15HEMUpdateAllEditingWidgetButtonVisuals();
}

%end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    S15HEMInstallSystemAppearanceObserver();
    S15HEMLogIOS15CompatibilityProbe(nil);
    S15HEMAppendTransitionProbeMessage(@"SpringBoard.launch",
                                       [NSString stringWithFormat:@"bundle=%@ mode=%ld scale=%.2f",
                                        NSBundle.mainBundle.bundleIdentifier ?: @"(nil)",
                                        (long)S15HEMIconSizePreference(),
                                        S15HEMCurrentIconScale()]);
    dispatch_async(dispatch_get_main_queue(), ^{
        S15HEMLogVisibleIconHierarchySample();
        S15HEMApplyAllCurrentSettings();
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        S15HEMLogVisibleIconHierarchySample();
    });
}

- (void)applicationDidBecomeActive:(id)application {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        S15HEMApplyAllCurrentSettings();
    });
}

%end

%ctor {
    %init;
}
