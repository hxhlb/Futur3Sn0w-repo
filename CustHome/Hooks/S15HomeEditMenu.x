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

static void *kS15HEMMenuInstalledKey = &kS15HEMMenuInstalledKey;
static void *kS15HEMActiveSheetKey = &kS15HEMActiveSheetKey;
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
static NSString *const kS15HEMIconSizeKey = @"CustomizeIconSizeMode";
static NSString *const kS15HEMWallpaperDimmingKey = @"CustomizeWallpaperDimmingMode";
static NSString *const kS15HEMAppearanceModeKey = @"CustomizeAppearanceMode";
static NSString *const kS15HEMWeatherHueKey = @"CustomizeWeatherHueValue";
static NSString *const kS15HEMWeatherBrightnessKey = @"CustomizeWeatherBrightnessValue";
static NSString *const kS15HEMSystemAppearanceDomain = @"com.apple.uikitservices.userInterfaceStyleMode";
static NSString *const kS15HEMSystemAppearanceModeValueKey = @"UserInterfaceStyleMode";
static NSString *const kS15HEMSystemMostRecentAutomaticModeKey = @"MostRecentAutomaticMode";

static UIWindow *S15HEMHomeScreenWindow(void);

static NSArray<UIWindow *> *S15HEMAllWindows(void);
static void S15HEMApplyWallpaperDimmingToHomeScreen(void);
static void S15HEMApplyIconAppearanceToAllVisibleViews(BOOL animated);
static void S15HEMApplyAppearanceModeToSpringBoard(void);
static void S15HEMRefreshHomeScreenIconLists(BOOL animated);
static void S15HEMApplyIconAppearanceInContainer(UIView *container, BOOL animated);
static void S15HEMHandleHomeScreenTraitChange(UITraitCollection *previousTraitCollection, UITraitCollection *currentTraitCollection);
static UIUserInterfaceStyle S15HEMResolvedSystemInterfaceStyle(void);
static UIView *S15HEMDirectIconImageView(UIView *iconView);
static UIView *S15HEMNearestIconViewForView(UIView *view);
static void S15HEMAppendTransitionProbe(NSString *phase, UIView *view, NSString *details);
static void S15HEMLogVisibleIconHierarchySample(void);
static BOOL S15HEMClassNameLooksLikeIconView(NSString *className);

typedef NS_ENUM(NSInteger, S15HEMIconSizeMode) {
    S15HEMIconSizeModeSmall = 0,
    S15HEMIconSizeModeLarge = 1,
};

typedef NS_ENUM(NSInteger, S15HEMWallpaperDimmingMode) {
    S15HEMWallpaperDimmingModeAuto = 0,
    S15HEMWallpaperDimmingModeOn = 1,
    S15HEMWallpaperDimmingModeOff = 2,
};

typedef NS_ENUM(NSInteger, S15HEMAppearanceMode) {
    S15HEMAppearanceModeLight = 0,
    S15HEMAppearanceModeDark = 1,
    S15HEMAppearanceModeAutomatic = 2,
    S15HEMAppearanceModeTinted = 3,
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

@interface S15HEMCustomizeSheetView : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIControl *dimmingView;
@property (nonatomic, strong) UIVisualEffectView *sheetView;
@property (nonatomic, strong) UIView *grabberView;
@property (nonatomic, strong) UIButton *dimmingModeButton;
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

@interface UISUserInterfaceStyleMode : NSObject
@property (nonatomic) NSInteger modeValue;
@property (readonly, nonatomic) NSInteger suggestedAutomaticModeValue;
- (id)initWithDelegate:(id _Nullable)delegate;
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
    if (value < S15HEMWallpaperDimmingModeAuto || value > S15HEMWallpaperDimmingModeOff) {
        return S15HEMWallpaperDimmingModeAuto;
    }
    return (S15HEMWallpaperDimmingMode)value;
}

static void S15HEMSetWallpaperDimmingPreference(S15HEMWallpaperDimmingMode mode) {
    [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:kS15HEMWallpaperDimmingKey];
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
    switch (S15HEMWallpaperDimmingPreference()) {
        case S15HEMWallpaperDimmingModeOn:
            return YES;
        case S15HEMWallpaperDimmingModeOff:
            return NO;
        case S15HEMWallpaperDimmingModeAuto:
        default:
            return style == UIUserInterfaceStyleDark;
    }
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

static CGFloat S15HEMCollapsedSheetHeight(void) {
    return 174.0;
}

static CGFloat S15HEMExpandedSheetHeight(void) {
    // Match the visible content stack so the options row never has to compress.
    return 250.0;
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
    });
    return loaded;
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

static void S15HEMApplyWallpaperDimmingToHomeScreen(void) {
    UIWindow *window = S15HEMHomeScreenWindow();
    if (!window) return;

    UIView *overlay = objc_getAssociatedObject(window, kS15HEMWallpaperDimOverlayKey);
    BOOL shouldDim = S15HEMEffectiveWallpaperDimmingEnabled(window.traitCollection.userInterfaceStyle);
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
    S15HEMAppearanceMode mode = S15HEMAppearanceModePreference();
    UIUserInterfaceStyle style = UIUserInterfaceStyleUnspecified;
    if (mode == S15HEMAppearanceModeLight) style = UIUserInterfaceStyleLight;
    else if (mode == S15HEMAppearanceModeDark) style = UIUserInterfaceStyleDark;

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

static void S15HEMHandleHomeScreenTraitChange(UITraitCollection *previousTraitCollection, UITraitCollection *currentTraitCollection) {
    if (!currentTraitCollection) return;
    if (previousTraitCollection &&
        previousTraitCollection.userInterfaceStyle == currentTraitCollection.userInterfaceStyle) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        S15HEMAppearanceMode mode = S15HEMAppearanceModePreference();
        if (mode == S15HEMAppearanceModeAutomatic || mode == S15HEMAppearanceModeTinted) {
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
    [[button.heightAnchor constraintEqualToConstant:94.0] setActive:YES];

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
    label.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.adjustsFontForContentSizeCategory = NO;

    UIView *labelPill = [[UIView alloc] initWithFrame:CGRectZero];
    labelPill.translatesAutoresizingMaskIntoConstraints = NO;
    labelPill.userInteractionEnabled = NO;
    labelPill.backgroundColor = UIColor.clearColor;
    labelPill.layer.cornerRadius = 11.0;
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
        [labelPill.heightAnchor constraintEqualToConstant:21.0],
        [labelPill.leadingAnchor constraintGreaterThanOrEqualToAnchor:button.leadingAnchor constant:6.0],
        [labelPill.trailingAnchor constraintLessThanOrEqualToAnchor:button.trailingAnchor constant:-6.0],
        [labelPill.bottomAnchor constraintEqualToAnchor:button.bottomAnchor constant:-2.0],

        [label.topAnchor constraintEqualToAnchor:labelPill.topAnchor],
        [label.leadingAnchor constraintEqualToAnchor:labelPill.leadingAnchor constant:8.0],
        [label.trailingAnchor constraintEqualToAnchor:labelPill.trailingAnchor constant:-8.0],
        [label.centerYAnchor constraintEqualToAnchor:labelPill.centerYAnchor],
    ]];

    [button addTarget:sheet action:@selector(appearanceButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}


@implementation S15HEMCustomizeSheetView {
    NSLayoutConstraint *_sheetHeightConstraint;
    NSLayoutConstraint *_sheetBottomConstraint;
    NSLayoutConstraint *_sliderSectionHeightConstraint;
    CAGradientLayer *_hueGradientLayer;
    CAGradientLayer *_brightnessGradientLayer;
    BOOL _slidersExpanded;
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
    self.dimmingModeButton.selected = dimMode == S15HEMWallpaperDimmingModeAuto;
    BOOL dimEnabled = S15HEMEffectiveWallpaperDimmingEnabled(self.traitCollection.userInterfaceStyle);
    NSString *sunImageName = dimEnabled ? @"sun.max.fill" : @"sun.max";
    [self.dimmingModeButton setImage:[UIImage systemImageNamed:sunImageName] forState:UIControlStateNormal];
    self.dimmingModeButton.backgroundColor = self.dimmingModeButton.selected
        ? [UIColor colorWithWhite:1.0 alpha:0.14]
        : UIColor.clearColor;

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
        button.alpha = 1.0;
        imageView.alpha = 1.0;
        if (selected) {
            labelPill.backgroundColor = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
                ? [UIColor colorWithWhite:1.0 alpha:0.16]
                : [UIColor colorWithWhite:0.0 alpha:0.10];
        } else {
            labelPill.backgroundColor = UIColor.clearColor;
        }
        label.textColor = selected
            ? UIColor.labelColor
            : [UIColor.labelColor colorWithAlphaComponent:0.72];
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
    mode = (mode + 1) % 3;
    S15HEMSetWallpaperDimmingPreference(mode);
    S15HEMApplyWallpaperDimmingForStyle(self.traitCollection.userInterfaceStyle);
    S15HEMApplyWallpaperDimmingToHomeScreen();
    [self refreshControlState];
}

- (void)appearanceButtonTapped:(UIControl *)control {
    NSUInteger index = (NSUInteger)control.tag;
    if (index >= self.appearanceButtons.count) return;
    S15HEMAppearanceMode mode = (S15HEMAppearanceMode)index;
    S15HEMAppearanceModeSetPreference(mode);
    if (mode != S15HEMAppearanceModeTinted) {
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
    self.dimmingModeButton.configuration = [UIButtonConfiguration plainButtonConfiguration];
    self.dimmingModeButton.configuration.contentInsets = NSDirectionalEdgeInsetsMake(6.0, 6.0, 6.0, 6.0);
    self.dimmingModeButton.configuration.imagePadding = 0.0;
    [self.dimmingModeButton setImage:[UIImage systemImageNamed:@"sun.max.fill"] forState:UIControlStateNormal];
    self.dimmingModeButton.layer.cornerRadius = 14.0;
    self.dimmingModeButton.layer.masksToBounds = YES;
    self.dimmingModeButton.tintColor = UIColor.labelColor;
    [self.dimmingModeButton addTarget:self action:@selector(cycleWallpaperDimmingMode) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:self.dimmingModeButton];

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
    _sheetBottomConstraint = [self.sheetView.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:maxHeight + 40.0];

    [NSLayoutConstraint activateConstraints:@[
        [self.sheetView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12.0],
        [self.sheetView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12.0],
        _sheetHeightConstraint,
        _sheetBottomConstraint,

        [self.grabberView.topAnchor constraintEqualToAnchor:self.sheetView.contentView.topAnchor constant:10.0],
        [self.grabberView.centerXAnchor constraintEqualToAnchor:self.sheetView.contentView.centerXAnchor],
        [self.grabberView.widthAnchor constraintEqualToConstant:36.0],
        [self.grabberView.heightAnchor constraintEqualToConstant:5.0],

        [content.topAnchor constraintEqualToAnchor:self.sheetView.contentView.topAnchor constant:18.0],
        [content.leadingAnchor constraintEqualToAnchor:self.sheetView.contentView.leadingAnchor constant:14.0],
        [content.trailingAnchor constraintEqualToAnchor:self.sheetView.contentView.trailingAnchor constant:-14.0],
        [content.bottomAnchor constraintEqualToAnchor:self.sheetView.contentView.bottomAnchor constant:-2.0],

        [self.dimmingModeButton.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [self.dimmingModeButton.centerYAnchor constraintEqualToAnchor:self.iconSizeControl.centerYAnchor],
        [self.dimmingModeButton.widthAnchor constraintEqualToConstant:34.0],
        [self.dimmingModeButton.heightAnchor constraintEqualToConstant:34.0],

        [self.iconSizeControl.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [self.iconSizeControl.topAnchor constraintEqualToAnchor:content.topAnchor constant:0.0],
        [self.iconSizeControl.widthAnchor constraintEqualToConstant:150.0],
        [self.iconSizeControl.heightAnchor constraintEqualToConstant:30.0],

        [self.brushButton.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [self.brushButton.centerYAnchor constraintEqualToAnchor:self.iconSizeControl.centerYAnchor],
        [self.brushButton.widthAnchor constraintEqualToConstant:34.0],
        [self.brushButton.heightAnchor constraintEqualToConstant:34.0],

        [self.appearanceRow.topAnchor constraintEqualToAnchor:self.iconSizeControl.bottomAnchor constant:8.0],
        [self.appearanceRow.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [self.appearanceRow.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [self.appearanceRow.heightAnchor constraintEqualToConstant:94.0],

        [appearanceButtonsRow.topAnchor constraintEqualToAnchor:self.appearanceRow.topAnchor],
        [appearanceButtonsRow.leadingAnchor constraintEqualToAnchor:self.appearanceRow.leadingAnchor],
        [appearanceButtonsRow.trailingAnchor constraintEqualToAnchor:self.appearanceRow.trailingAnchor],
        [appearanceButtonsRow.bottomAnchor constraintEqualToAnchor:self.appearanceRow.bottomAnchor],

        [self.sliderSection.topAnchor constraintEqualToAnchor:self.appearanceRow.bottomAnchor constant:6.0],
        [self.sliderSection.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [self.sliderSection.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [self.sliderSection.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
        [self.sliderSection.widthAnchor constraintEqualToAnchor:content.widthAnchor],
    ]];

    _sliderSectionHeightConstraint = [self.sliderSection.heightAnchor constraintEqualToConstant:90.0];
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
    _sheetBottomConstraint.constant = -8.0;
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
        [self removeFromSuperview];
    }];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self];
    CGPoint velocity = [pan velocityInView:self];
    if (pan.state == UIGestureRecognizerStateChanged) {
        _sheetBottomConstraint.constant = MAX(-8.0, -8.0 + translation.y);
        self.dimmingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:MAX(0.0, 0.18 - translation.y / 700.0)];
        [self layoutIfNeeded];
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        if (translation.y > 90.0 || velocity.y > 900.0) {
            [self dismissAnimated];
            return;
        }
        _sheetBottomConstraint.constant = -8.0;
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
        if (S15HEMWallpaperDimmingPreference() == S15HEMWallpaperDimmingModeAuto) {
            S15HEMApplyWallpaperDimmingForStyle(self.traitCollection.userInterfaceStyle);
            S15HEMApplyWallpaperDimmingToHomeScreen();
        }
    }
    [self refreshControlStateAnimated:YES];
}

@end

static void S15HEMPresentCustomizeSheet(UIView *button) {
    UIWindow *window = button.window ?: S15HEMHomeScreenWindow();
    if (!window) return;
    S15HEMCustomizeSheetView *existing = objc_getAssociatedObject(window, kS15HEMActiveSheetKey);
    if (existing && existing.superview) return;

    S15HEMCustomizeSheetView *sheet = [[S15HEMCustomizeSheetView alloc] initWithFrame:window.bounds];
    objc_setAssociatedObject(window, kS15HEMActiveSheetKey, sheet, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

    UIAction *editWallpaper = [UIAction actionWithTitle:@"Edit Wallpaper"
                                                  image:[UIImage systemImageNamed:@"photo.on.rectangle"]
                                             identifier:nil
                                                handler:^(__kindof UIAction *a) {
        S15HEMTriggerWallpaper(weakButton);
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

    return [UIMenu menuWithTitle:@"" children:@[addWidget, customize, editWallpaper, editPages]];
}

%hook SBHEditingWidgetButton

- (void)didMoveToWindow {
    %orig;
    if (!S15HEMIsSpringBoard()) return;

    UIButton *button = (UIButton *)self;
    if (!button.window) return;
    if ([objc_getAssociatedObject(button, kS15HEMMenuInstalledKey) boolValue]) return;
    if (![button respondsToSelector:@selector(setMenu:)] ||
        ![button respondsToSelector:@selector(setShowsMenuAsPrimaryAction:)]) {
        return;
    }

    button.menu = S15HEMMenuForButton(button);
    button.showsMenuAsPrimaryAction = YES;
    if ([button respondsToSelector:@selector(setChangesSelectionAsPrimaryAction:)]) {
        button.changesSelectionAsPrimaryAction = NO;
    }

    objc_setAssociatedObject(button, kS15HEMMenuInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
    BOOL applyingManagedAlpha = [objc_getAssociatedObject(selfView, kS15HEMApplyingManagedAlphaKey) boolValue];
    if (!applyingManagedAlpha && S15HEMShouldForceHiddenForLabelView(selfView)) {
        hidden = YES;
    }

    %orig(hidden);
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
}

%end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
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
}
