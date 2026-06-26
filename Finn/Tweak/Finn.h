#import <UIKit/UIKit.h>

// ─── Preferences ────────────────────────────────────────────────────────────
// We use NSUserDefaults directly so we don't need Cephei / HBPreferences,
// keeping the dependency surface minimal for a rootless build.

static NSString * const kFinnPrefsID   = @"com.futur3sn0w.finn";
static NSString * const kKeyEnabled    = @"enabled";
static NSString * const kKeyBGEnabled  = @"enableBackgroundColoring";
static NSString * const kKeyBGAlpha    = @"backgroundAlpha";
static NSString * const kKeyBGColor    = @"selectedBackgroundColor";
static NSString * const kKeyMenuEnabled = @"enableMenuColoring";
static NSString * const kKeyMenuAlpha  = @"menuAlpha";
static NSString * const kKeyMenuColor  = @"selectedMenuColor";

// Global state written once per long-press and consumed by the view hooks.
static UIColor *gBackgroundColor = nil;  // dimming backdrop tint
static UIColor *gMenuColor       = nil;  // actions list tint

// Preference cache – refreshed on every context-menu trigger so a respring
// is not required after toggling options (PostNotification in prefs pane
// could refresh these, but a per-invocation read is cheap enough here).
static inline NSDictionary *FinnPrefs(void) {
    return [[NSUserDefaults standardUserDefaults]
            persistentDomainForName:kFinnPrefsID] ?: @{};
}
static inline BOOL FinnBool(NSString *key, BOOL def) {
    NSDictionary *p = FinnPrefs();
    return p[key] ? [p[key] boolValue] : def;
}
static inline double FinnDouble(NSString *key, double def) {
    NSDictionary *p = FinnPrefs();
    return p[key] ? [p[key] doubleValue] : def;
}
static inline int FinnInt(NSString *key, int def) {
    NSDictionary *p = FinnPrefs();
    return p[key] ? [p[key] intValue] : def;
}

// ─── Private SpringBoard/UIKit interfaces ───────────────────────────────────

// iOS 13-16: The outer container that covers the whole screen when a
// context menu is open.  Its backgroundColor is the dark dimming layer.
@interface _UIContextMenuContainerView : UIView
@end

// iOS 13-14: The rounded card that holds the action rows.
@interface _UIContextMenuActionsListView : UIView
@end

// iOS 15-16: Renamed from _UIContextMenuActionsListView.
@interface _UIContextMenuListView : UIView
@end

// ─── SpringBoard icon interfaces ─────────────────────────────────────────────

@interface SBIconImageView : UIView
- (UIImage *)displayedImage;
@end

@interface SBIcon : NSObject
- (NSString *)applicationBundleID;
@end

@interface SBFolder : NSObject
- (NSArray<SBIcon *> *)icons;
@end

@interface SBIconView : UIView
- (SBIcon *)icon;
- (id)folder;
- (SBIconImageView *)currentImageView;
@end

// iOS 13-14: context menu entry point on SBIconController.
// iOS 15+: SBIconController is renamed/restructured; the context menu is
// driven directly by SBIconView conforming to UIContextMenuInteractionDelegate.
// We hook SBIconController for 13/14 AND hook SBIconView for 15/16 so that
// gBackgroundColor/gMenuColor are always populated before the views appear.
@interface SBIconController : UIViewController
- (id)containerViewForPresentingContextMenuForIconView:(SBIconView *)iconView;
@end

// iOS 15+ – SBHIconManager took over some responsibilities from SBIconController.
@interface SBHIconManager : NSObject
@end

@interface UIImage (Finn)
+ (id)_applicationIconImageForBundleIdentifier:(id)arg1 format:(int)arg2 scale:(double)arg3;
@end

// ─── Color-extraction helper (inline, no libKitten dependency) ───────────────
//
// We extract dominant/primary/secondary colors ourselves using a fast
// scaled-down pixel-sampling approach.  This removes the love.litten.libkitten
// dependency entirely, which is handy because that library is not widely
// available on rootless repos.
//
// Algorithm:
//   1. Draw icon into a tiny 8×8 bitmap (fast, ~64 samples).
//   2. Collect all pixels, sort by perceived brightness bucket.
//   3. Return average of the most-populated bucket for each role.

typedef enum : int {
    FinnColorBackground = 0,   // darkest average
    FinnColorPrimary    = 1,   // most-common hue cluster
    FinnColorSecondary  = 2,   // second hue cluster
} FinnColorRole;

static UIColor *FinnColorFromImage(UIImage *image, FinnColorRole role) {
    if (!image) return nil;

    #define FINN_SAMPLE_SIZE 16
    const int size = FINN_SAMPLE_SIZE; // 16×16 → 256 samples, still very fast
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    unsigned char pixels[FINN_SAMPLE_SIZE * FINN_SAMPLE_SIZE * 4];
    CGContextRef ctx = CGBitmapContextCreate(pixels, size, size, 8,
                                             size * 4, cs,
                                             kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    if (!ctx) return nil;

    CGContextDrawImage(ctx, CGRectMake(0, 0, size, size), image.CGImage);
    CGContextRelease(ctx);

    // Collect (r,g,b) ignoring near-transparent pixels.
    NSMutableArray<UIColor *> *colors = [NSMutableArray array];
    for (int i = 0; i < size * size; i++) {
        unsigned char r = pixels[i*4+0];
        unsigned char g = pixels[i*4+1];
        unsigned char b = pixels[i*4+2];
        unsigned char a = pixels[i*4+3];
        if (a < 30) continue; // skip transparent
        [colors addObject:[UIColor colorWithRed:r/255.0
                                          green:g/255.0
                                           blue:b/255.0
                                          alpha:1.0]];
    }
    if (!colors.count) return nil;

    if (role == FinnColorBackground) {
        // Darkest perceived brightness
        UIColor *darkest = nil;
        CGFloat minBright = 2.0;
        for (UIColor *c in colors) {
            CGFloat h,s,b2,a2;
            [c getHue:&h saturation:&s brightness:&b2 alpha:&a2];
            if (b2 < minBright) { minBright = b2; darkest = c; }
        }
        return darkest;
    }

    // For Primary/Secondary: k-means-lite with k=2 on hue
    // Seed: first and middle color as cluster centres.
    UIColor *seed1 = colors[0];
    UIColor *seed2 = colors[colors.count / 2];

    for (int iter = 0; iter < 5; iter++) {
        CGFloat h1,s1,b1,a1, h2,s2,b2,a2;
        [seed1 getHue:&h1 saturation:&s1 brightness:&b1 alpha:&a1];
        [seed2 getHue:&h2 saturation:&s2 brightness:&b2 alpha:&a2];

        CGFloat rR1=0,rG1=0,rB1=0,rR2=0,rG2=0,rB2=0;
        int n1=0, n2=0;
        for (UIColor *c in colors) {
            CGFloat h,s,b,a;
            [c getHue:&h saturation:&s brightness:&b alpha:&a];
            CGFloat d1 = fabs(h-h1), d2 = fabs(h-h2);
            if (d1 > 0.5) d1 = 1.0 - d1; // wrap hue
            if (d2 > 0.5) d2 = 1.0 - d2;
            CGFloat r,g,bl;
            [c getRed:&r green:&g blue:&bl alpha:&a];
            if (d1 <= d2) { rR1+=r; rG1+=g; rB1+=bl; n1++; }
            else          { rR2+=r; rG2+=g; rB2+=bl; n2++; }
        }
        if (n1 > 0) seed1 = [UIColor colorWithRed:rR1/n1 green:rG1/n1 blue:rB1/n1 alpha:1];
        if (n2 > 0) seed2 = [UIColor colorWithRed:rR2/n2 green:rG2/n2 blue:rB2/n2 alpha:1];
    }

    // Determine which cluster is "larger" (more pixels → primary)
    CGFloat h1,s1,brt1,a1;
    [seed1 getHue:&h1 saturation:&s1 brightness:&brt1 alpha:&a1];
    int votes1 = 0;
    for (UIColor *c in colors) {
        CGFloat h,s,b,a;
        [c getHue:&h saturation:&s brightness:&b alpha:&a];
        CGFloat d1 = fabs(h-h1), d2 = 1.0; // placeholder
        CGFloat hh2,ss2,bb2,aa2;
        [seed2 getHue:&hh2 saturation:&ss2 brightness:&bb2 alpha:&aa2];
        d2 = fabs(h-hh2);
        if (d1 > 0.5) d1 = 1.0 - d1;
        if (d2 > 0.5) d2 = 1.0 - d2;
        if (d1 <= d2) votes1++;
    }
    BOOL seed1IsPrimary = (votes1 >= (int)colors.count / 2);
    if (role == FinnColorPrimary)
        return seed1IsPrimary ? seed1 : seed2;
    else // Secondary
        return seed1IsPrimary ? seed2 : seed1;
}

static UIColor *FinnPickColor(UIImage *image, int role, double alpha) {
    UIColor *c = FinnColorFromImage(image, (FinnColorRole)role);
    return c ? [c colorWithAlphaComponent:alpha] : nil;
}

// ─── Icon image extraction (mirrors koi's waterfall logic) ───────────────────

static UIImage *FinnImageForIconView(SBIconView *iconView) {
    // 1. Fastest path: cached image already in memory.
    SBIconImageView *iv = [iconView currentImageView];
    if (iv && [iv respondsToSelector:@selector(displayedImage)]) {
        UIImage *img = [iv displayedImage];
        if (img) return img;
    }
    // 2. Load via bundle identifier (folders use first icon's ID).
    NSString *bid = nil;
    id folder = [iconView folder];
    if (folder && [[folder icons] count])
        bid = [(SBIcon *)[[folder icons] firstObject] applicationBundleID];
    else
        bid = [[iconView icon] applicationBundleID];

    if (bid) {
        UIImage *img = [UIImage _applicationIconImageForBundleIdentifier:bid
                                                                  format:2
                                                                   scale:[UIScreen mainScreen].scale];
        if (img) return img;
    }
    // 3. Last resort: render the icon view into a bitmap.
    CGSize sz = iconView.bounds.size;
    if (sz.width < 1 || sz.height < 1) return nil;
    UIGraphicsBeginImageContextWithOptions(sz, NO, 0);
    [iconView drawViewHierarchyInRect:CGRectMake(0,0,sz.width,sz.height)
                   afterScreenUpdates:YES];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

// ─── Populate the global colors from a given icon view ───────────────────────

static void FinnUpdateColorsForIconView(SBIconView *iconView) {
    gBackgroundColor = nil;
    gMenuColor       = nil;

    UIImage *image = FinnImageForIconView(iconView);
    if (!image) return;

    if (FinnBool(kKeyBGEnabled, YES)) {
        int   role  = FinnInt(kKeyBGColor, 1);
        double alpha = FinnDouble(kKeyBGAlpha, 0.30);
        gBackgroundColor = FinnPickColor(image, role, alpha);
    }
    if (FinnBool(kKeyMenuEnabled, YES)) {
        int   role  = FinnInt(kKeyMenuColor, 0);
        double alpha = FinnDouble(kKeyMenuAlpha, 0.55);
        gMenuColor = FinnPickColor(image, role, alpha);
    }
}
