// SevenUp v0.2.0 — first visual pass
// Flat uniform cards, iOS 7 corner radius, unblurred switcher background.
// Probe + snapshot infrastructure retained for remote iteration.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <notify.h>

typedef struct {
	CGFloat a;
	CGFloat b;
	CGFloat c;
	CGFloat d;
} SURectCornerRadii;

@interface SBDeckSwitcherModifier : NSObject
@end

@interface SBFluidSwitcherViewController : UIViewController
@end

@interface SBDeckSwitcherViewController : SBFluidSwitcherViewController
+ (instancetype)getInstance;
@end

@interface UIImage (SevenUpPrivate)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end

@interface SBFluidSwitcherItemContainerHeaderView : UIView
@end

@interface SBFluidSwitcherContentView : UIView
@end

@interface SBAppSwitcherScrollView : UIScrollView
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstanceIfExists;
- (id)applicationWithBundleIdentifier:(NSString *)bundleIdentifier;
@end

@interface SBSwitcherController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)toggleMainSwitcherNoninteractivelyWithSource:(NSInteger)source animated:(BOOL)animated windowScene:(id)scene;
- (BOOL)activateMainSwitcherNoninteractivelyWithSource:(NSInteger)source animated:(BOOL)animated;
@end

static NSString * const kSULogPath = @"/var/mobile/Documents/SevenUp-probe.log";
static NSString * const kSUSnapPath = @"/var/mobile/Documents/SevenUp-snap.png";
static NSString * const kSUPrefsID = @"com.futur3sn0w.sevenup";

// iOS 7 measurements (approx, from the real thing):
// card scale ~0.60 of screen, corner radius ~7pt on the scaled card.
static CGFloat const kSUCardScale = 0.60;
static CGFloat const kSUCardGap = 30.0;
static CGFloat const kSUCardCornerRadius = 7.0;

#pragma mark - Prefs

static BOOL gSUEnabled = YES;

static void SULoadPrefs(void) {
	CFPreferencesAppSynchronize((__bridge CFStringRef)kSUPrefsID);
	Boolean keyExists = false;
	Boolean value = CFPreferencesGetAppBooleanValue(CFSTR("Enabled"), (__bridge CFStringRef)kSUPrefsID, &keyExists);
	gSUEnabled = keyExists ? (BOOL)value : YES;
}

#pragma mark - Logging

static void SULog(NSString *format, ...) {
	va_list args;
	va_start(args, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);

	NSDateFormatter *formatter = [NSDateFormatter new];
	formatter.dateFormat = @"HH:mm:ss.SSS";
	NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [formatter stringFromDate:[NSDate date]], message];

	NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kSULogPath];
	if (!handle) {
		[[NSFileManager defaultManager] createFileAtPath:kSULogPath contents:nil attributes:nil];
		handle = [NSFileHandle fileHandleForWritingAtPath:kSULogPath];
	}
	if (!handle) return;
	@try {
		[handle seekToEndOfFile];
		[handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
	} @catch (__unused NSException *e) {}
	[handle closeFile];
}

#pragma mark - Probes

// Dump every loaded class whose name mentions the switcher machinery.
static void SUDumpSwitcherClasses(void) {
	SULog(@"===== CLASS DUMP BEGIN =====");
	unsigned int count = 0;
	Class *classes = objc_copyClassList(&count);
	NSArray<NSString *> *needles = @[ @"Switcher", @"AppLayout", @"Snapshot", @"Wallpaper" ];
	NSMutableArray *hits = [NSMutableArray array];
	for (unsigned int i = 0; i < count; i++) {
		const char *name = class_getName(classes[i]);
		if (!name) continue;
		NSString *className = @(name);
		for (NSString *needle in needles) {
			if ([className containsString:needle]) {
				[hits addObject:className];
				break;
			}
		}
	}
	free(classes);
	[hits sortUsingSelector:@selector(compare:)];
	for (NSString *className in hits) {
		Class cls = objc_getClass(className.UTF8String);
		Class superclass = class_getSuperclass(cls);
		SULog(@"%@ : %@", className, superclass ? @(class_getName(superclass)) : @"(root)");
	}
	SULog(@"===== CLASS DUMP END (%lu classes) =====", (unsigned long)hits.count);
}

static void SUDumpMethodsForClassNamed(NSString *className) {
	Class cls = objc_getClass(className.UTF8String);
	if (!cls) {
		SULog(@"-- %@: NOT PRESENT", className);
		return;
	}
	SULog(@"-- %@ (super: %s) --", className, class_getName(class_getSuperclass(cls)));

	unsigned int methodCount = 0;
	Method *methods = class_copyMethodList(cls, &methodCount);
	NSMutableArray *lines = [NSMutableArray array];
	for (unsigned int i = 0; i < methodCount; i++) {
		const char *sel = sel_getName(method_getName(methods[i]));
		const char *types = method_getTypeEncoding(methods[i]);
		[lines addObject:[NSString stringWithFormat:@"  -%s | %s", sel, types ?: "?"]];
	}
	free(methods);

	// Class methods too
	Class meta = object_getClass(cls);
	methods = class_copyMethodList(meta, &methodCount);
	for (unsigned int i = 0; i < methodCount; i++) {
		const char *sel = sel_getName(method_getName(methods[i]));
		[lines addObject:[NSString stringWithFormat:@"  +%s", sel]];
	}
	free(methods);

	[lines sortUsingSelector:@selector(compare:)];
	for (NSString *line in lines) SULog(@"%@", line);

	// Properties
	unsigned int propCount = 0;
	objc_property_t *props = class_copyPropertyList(cls, &propCount);
	for (unsigned int i = 0; i < propCount; i++) {
		SULog(@"  @property %s", property_getName(props[i]));
	}
	free(props);
}

static void SUDumpInterestingMethods(void) {
	SULog(@"===== METHOD DUMP BEGIN =====");
	// If a class list file exists, dump those instead of the built-in list.
	NSString *listPath = @"/var/mobile/Documents/SevenUp-probe-classes.txt";
	NSString *fileContents = [NSString stringWithContentsOfFile:listPath encoding:NSUTF8StringEncoding error:nil];
	if (fileContents.length > 0) {
		for (NSString *rawLine in [fileContents componentsSeparatedByString:@"\n"]) {
			NSString *name = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if (name.length > 0) SUDumpMethodsForClassNamed(name);
		}
		SULog(@"===== METHOD DUMP END (from file) =====");
		return;
	}
	NSArray *candidates = @[
		// Top-level switcher controllers
		@"SBMainSwitcherViewController",
		@"SBFluidSwitcherViewController",
		@"SBFluidSwitcherRootViewController",
		// Layout modifiers (deck = non-home-button paged switcher)
		@"SBSwitcherModifier",
		@"SBDeckSwitcherModifier",
		@"SBGridSwitcherModifier",
		@"SBMainSwitcherModifier",
		@"SBBaseDeckSwitcherModifier",
		@"SBDeckSwitcherPageContentProvider",
		// Per-card container: icon header, title, snapshot
		@"SBFluidSwitcherItemContainer",
		@"SBFluidSwitcherIconImageContainerView",
		@"SBAppLayoutView",
		@"SBReusableSnapshotItemContainer",
		// Background / wallpaper
		@"SBHomeScreenBackdropView",
		@"SBWallpaperEffectView",
		// Settings domains (often the cleanest override point)
		@"SBAppSwitcherSettings",
		@"SBFluidSwitcherSettings",
		@"SBFluidSwitcherAnimationSettings"
	];
	for (NSString *name in candidates) SUDumpMethodsForClassNamed(name);
	SULog(@"===== METHOD DUMP END =====");
}

#pragma mark - Remote snapshot (render SpringBoard windows to PNG)

static void SUWriteSnapshot(void) {
	UIWindow *keyWindow = nil;
	NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
	for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) continue;
		for (UIWindow *window in ((UIWindowScene *)scene).windows) {
			if (!window.hidden && window.alpha > 0.01) [windows addObject:window];
			if (window.isKeyWindow) keyWindow = window;
		}
	}
	(void)keyWindow;
	if (windows.count == 0) { SULog(@"snapshot: no visible windows"); return; }
	[windows sortUsingComparator:^NSComparisonResult(UIWindow *a, UIWindow *b) {
		if (a.windowLevel == b.windowLevel) return NSOrderedSame;
		return a.windowLevel < b.windowLevel ? NSOrderedAscending : NSOrderedDescending;
	}];

	CGRect bounds = [UIScreen mainScreen].bounds;
	UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
	format.scale = 1.0; // keep the file small; points are plenty for layout checks
	UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:bounds format:format];
	UIImage *image = [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *ctx) {
		for (UIWindow *window in windows) {
			[window drawViewHierarchyInRect:window.frame afterScreenUpdates:NO];
		}
	}];
	NSData *png = UIImagePNGRepresentation(image);
	[png writeToFile:kSUSnapPath atomically:YES];
	SULog(@"snapshot: wrote %lu bytes (%lu windows)", (unsigned long)png.length, (unsigned long)windows.count);
}

#pragma mark - Layout hooks

// Debug instrumentation: "mode-stock" = pass everything through but log the
// original values; "mode-active" = apply SevenUp layout. Capped log flood.
static BOOL gSUStockMode = NO;
static int gSULogBudget = 0;
static CGFloat gSULastAbsProgress = 0;
static NSUInteger gSULastCount = 0;

static void SUTrace(NSString *format, ...) {
	if (gSULogBudget <= 0) return;
	gSULogBudget--;
	va_list args;
	va_start(args, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	SULog(@"%@", message);
}

// Only bend layout while the switcher is actually on screen — the same
// modifier/container machinery drives app-launch animations, and touching
// those causes glitches all over SpringBoard.
static BOOL gSUSwitcherVisible = NO;
static __weak UIView *gSUContentView = nil;

// Runtime bisect flags (flip via darwin notifications, no rebuild needed)
static BOOL gSUReverseOrder = YES;
static BOOL gSUCustomCardSize = YES;

static BOOL SUActive(void) {
	return gSUEnabled && !gSUStockMode && gSUSwitcherVisible;
}

@interface SUFrameTracker : NSObject
+ (instancetype)sharedTracker;
- (void)start;
- (void)stop;
@end

static UIScrollView *SUFindSwitcherScrollView(UIView *root, int depth) {
	if (depth > 6 || !root) return nil;
	Class scrollClass = objc_getClass("SBAppSwitcherScrollView");
	if ([root isKindOfClass:scrollClass]) return (UIScrollView *)root;
	for (UIView *subview in root.subviews) {
		UIScrollView *found = SUFindSwitcherScrollView(subview, depth + 1);
		if (found) return found;
	}
	return nil;
}

%hook SBFluidSwitcherViewController

- (void)viewWillAppear:(BOOL)animated {
	gSUSwitcherVisible = YES;
	[[SUFrameTracker sharedTracker] start];
	%orig;
}

// iOS 7 opening frame: home-card sliver at the left, current app centered.
- (void)viewDidAppear:(BOOL)animated {
	%orig;
	if (!SUActive()) return;
	UIScrollView *scrollView = SUFindSwitcherScrollView(self.viewIfLoaded, 0);
	if (!scrollView) return;
	CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
	CGFloat slot = screenWidth * kSUCardScale + kSUCardGap;
	// Leading slack for the home card slot, then frame: [home sliver][current app centered]
	UIEdgeInsets insets = scrollView.contentInset;
	insets.left = MAX(insets.left, slot);
	scrollView.contentInset = insets;
	CGFloat target = -((screenWidth - screenWidth * kSUCardScale) / 2.0);
	[scrollView setContentOffset:CGPointMake(target, scrollView.contentOffset.y) animated:NO];
	SULog(@"opening offset -> %.1f (inset.left=%.1f)", target, insets.left);
}

- (void)viewDidDisappear:(BOOL)animated {
	gSUSwitcherVisible = NO;
	[[SUFrameTracker sharedTracker] stop];
	%orig;
}

%end

#pragma mark - Force the iPad grid switcher

// The root modifier creates a "floor" modifier: deck on iPhone, grid on iPad.
// Swap in the grid one. (Gated on the pref only — this runs before the
// switcher is visible.)
%hook SBMainSwitcherRootSwitcherModifier

static id SUSwapDeckForGrid(id modifier, const char *where) {
	if (!gSUEnabled || gSUStockMode || !modifier) return modifier;
	Class deckClass = objc_getClass("SBDeckSwitcherModifier");
	Class gridClass = objc_getClass("SBGridSwitcherModifier");
	SULog(@"floor(%s): %@", where, [modifier class]);
	if (gridClass && [modifier isKindOfClass:deckClass] && ![modifier isKindOfClass:gridClass]) {
		@try {
			id grid = [[gridClass alloc] init];
			if (grid) {
				SULog(@"floor(%s): swapped %@ -> %@", where, [modifier class], [grid class]);
				return grid;
			}
		} @catch (NSException *e) {
			SULog(@"floor(%s): swap failed: %@", where, e);
		}
	}
	return modifier;
}

- (id)_createNewDefaultFloorModifier {
	return SUSwapDeckForGrid(%orig, "create");
}

- (id)floorModifierForTransitionEvent:(id)event {
	return SUSwapDeckForGrid(%orig, "transition");
}

- (void)_updateFloorModifierWithProposedFloorModifier:(id)proposed {
	%orig(SUSwapDeckForGrid(proposed, "proposed"));
}

%end

// iPad grid uses 2 rows; iOS 7 wants exactly 1.
%hook SBFluidSwitcherViewController

- (NSUInteger)numberOfRowsInGridSwitcher {
	if (!gSUEnabled || gSUStockMode) return %orig;
	return 1;
}

%end

#pragma mark - Grid layout: iOS 7 card size, spacing, corners, reversed order

@interface SBGridLayoutSwitcherModifier : NSObject
- (CGSize)_contentSize;
- (NSUInteger)_numberOfColumns;
@end

%hook SBGridLayoutSwitcherModifier

- (CGSize)_scaledCardSize {
	CGSize size = %orig;
	SUTrace(@"grid _scaledCardSize -> {%.1f,%.1f}", size.width, size.height);
	if (!SUActive() || !gSUCustomCardSize) return size;
	CGRect screen = [UIScreen mainScreen].bounds;
	return CGSizeMake(screen.size.width * kSUCardScale, screen.size.height * kSUCardScale);
}

- (CGFloat)_horizontalSpacing {
	CGFloat value = %orig;
	SUTrace(@"grid _horizontalSpacing -> %.1f", value);
	if (!SUActive() || !gSUCustomCardSize) return value;
	return kSUCardGap;
}

- (CGFloat)_cornerRadius {
	if (!SUActive()) return %orig;
	return kSUCardCornerRadius;
}

// The rendered card size is screen * scaleForIndex; the slot layout derives
// from it too. Single source of truth for the iOS 7 card scale.
- (CGFloat)scaleForIndex:(NSUInteger)index {
	CGFloat value = %orig;
	SUTrace(@"grid scaleForIndex:%lu -> %.4f", (unsigned long)index, value);
	if (!SUActive() || !gSUCustomCardSize) return value;
	return kSUCardScale;
}

- (CGRect)frameForIndex:(NSUInteger)index {
	CGRect frame = %orig;
	SUTrace(@"grid frameForIndex:%lu -> {%.1f,%.1f %.1fx%.1f}", (unsigned long)index,
		frame.origin.x, frame.origin.y, frame.size.width, frame.size.height);
	return frame;
}

- (CGSize)_contentSize {
	CGSize size = %orig;
	SUTrace(@"grid _contentSize -> {%.1f,%.1f}", size.width, size.height);
	return size;
}

- (NSUInteger)_numberOfColumns {
	NSUInteger value = %orig;
	SUTrace(@"grid _numberOfColumns -> %lu", (unsigned long)value);
	return value;
}

// Reverse visual order by mirroring the column assignment (newest leftmost).
// Mirroring here keeps culling and tap indices consistent.
- (NSUInteger)_columnForIndex:(NSUInteger)index {
	NSUInteger column = %orig;
	if (!SUActive() || !gSUReverseOrder) return column;
	NSUInteger columns = [self _numberOfColumns];
	if (columns < 2) return column;
	return columns - 1 - column;
}

%end

#pragma mark - Grid modifier styling (background, corners, opacity)

%hook SBGridSwitcherModifier

// Reserve the leading slot for the home screen card.
- (UIEdgeInsets)contentViewInsets {
	UIEdgeInsets insets = %orig;
	if (!SUActive()) return insets;
	CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
	insets.left += screenWidth * kSUCardScale + kSUCardGap;
	return insets;
}

// Reverse the data order: newest app leftmost, older apps extending right
// (iOS 7 order). All geometry stays stock-consistent since indices reverse
// with the array.
- (CGFloat)opacityForIndex:(NSUInteger)index scrollProgress:(CGFloat)progress {
	if (!SUActive()) return %orig;
	return 1.0;
}

- (SURectCornerRadii)cornerRadiiForIndex:(NSUInteger)index {
	SURectCornerRadii radii = %orig;
	if (!SUActive()) return radii;
	radii.a = radii.b = radii.c = radii.d = kSUCardCornerRadius;
	return radii;
}

- (CGFloat)homeScreenBackdropBlurProgress {
	if (!SUActive()) return %orig;
	return 0.0;
}

- (CGFloat)homeScreenDimmingAlpha {
	if (!SUActive()) return %orig;
	return 0.25;
}

- (CGFloat)homeScreenAlpha {
	if (!SUActive()) return %orig;
	return 0.0;
}

%end

%hook SBDeckSwitcherModifier

// The deck floor modifier is created with a bare [[SBDeckSwitcherModifier
// alloc] init]. Swapping the alloc gives us the iPad grid switcher instead.
+ (id)alloc {
	if (gSUEnabled && !gSUStockMode && self == objc_getClass("SBDeckSwitcherModifier")) {
		Class gridClass = objc_getClass("SBGridSwitcherModifier");
		if (gridClass) {
			SULog(@"alloc swap: deck -> grid");
			return [gridClass alloc];
		}
	}
	return %orig;
}

- (CGRect)frameForIndex:(NSUInteger)index {
	CGRect frame = %orig;
	{} // muted 
	return frame;
}

- (CGRect)_frameForIndex:(NSUInteger)index displayItemsCount:(NSUInteger)count scrollProgress:(CGFloat)progress ignoringScrollOffset:(BOOL)ignoring {
	CGRect frame = %orig;
	{} // muted 
	return frame;
}

- (CGFloat)scaleForIndex:(NSUInteger)index {
	CGFloat value = %orig;
	{} // muted 
	if (!SUActive()) return value;
	return kSUCardScale;
}

// iOS 7 flat list: uniform spacing, extending to the RIGHT (reversed vs deck).
// Slot 0 is left free for the home screen card.
- (CGFloat)leadingOffsetForIndex:(NSUInteger)index displayItemsCount:(NSUInteger)count scrollProgress:(CGFloat)progress {
	CGFloat value = %orig;
	if (index == 0) { gSULastAbsProgress = progress; gSULastCount = count; }
	if (!SUActive()) return value;
	CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
	CGFloat slot = screenWidth * kSUCardScale + kSUCardGap;
	return -((CGFloat)index + progress) * slot;
}

- (CGFloat)_scaleForTransformForIndex:(NSUInteger)index scrollProgress:(CGFloat)progress {
	CGFloat value = %orig;
	{} // muted 
	return value;
}

// The settled layout runs x-origins through this scale transform, which
// multiplies our slot spacing by the card scale (re-stacking the cards).
// Replace the scaling with a plain centering shift so spacing survives.
- (CGFloat)_scaleTransformedXOrigin:(CGFloat)x scrollProgress:(CGFloat)progress {
	CGFloat value = %orig;
	{} // muted 
	if (!SUActive()) return value;
	CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
	return x + (screenWidth - screenWidth * kSUCardScale) / 2.0;
}

- (CGFloat)depthForIndex:(NSUInteger)index displayItemsCount:(NSUInteger)count scrollProgress:(CGFloat)progress {
	CGFloat value = %orig;
	{} // muted 
	return value;
}

- (CGFloat)contentViewScale {
	CGFloat value = %orig;
	{} // muted 
	return value;
}

- (CGFloat)_scrollProgress {
	CGFloat value = %orig;
	{} // muted 
	return value;
}

- (CGFloat)_scrollProgressForContentOffset:(CGPoint)offset {
	CGFloat value = %orig;
	SUTrace(@"_scrollProgressForContentOffset:{%.1f,%.1f} -> %.4f", offset.x, offset.y, value);
	return value;
}

- (CGPoint)_contentOffsetForScrollProgress:(CGFloat)progress {
	CGPoint value = %orig;
	SUTrace(@"_contentOffsetForScrollProgress:%.4f -> {%.1f,%.1f}", progress, value.x, value.y);
	return value;
}

- (CGPoint)restingOffsetForScrollOffset:(CGPoint)offset velocity:(CGPoint)velocity {
	CGPoint value = %orig;
	SUTrace(@"restingOffsetForScrollOffset:{%.1f,%.1f} velocity:{%.1f,%.1f} -> {%.1f,%.1f}",
		offset.x, offset.y, velocity.x, velocity.y, value.x, value.y);
	return value;
}

- (CGFloat)_restingScrollProgressForProgress:(CGFloat)progress velocity:(CGPoint)velocity {
	CGFloat value = %orig;
	SUTrace(@"_restingScrollProgressForProgress:%.4f velocity:{%.1f,%.1f} -> %.4f", progress, velocity.x, velocity.y, value);
	if (!SUActive()) return value;
	// One-card-at-a-time paging, iOS 7 style. Relative drag progress per slot
	// is tiny (~0.11) so weight it up; velocity decides on flicks.
	CGFloat target = progress * 6.0 + velocity.x * 0.4;
	CGFloat snapped = 0;
	if (fabs(target) >= 0.25) snapped = (target > 0) ? 1.0 : -1.0;
	SULog(@"resting override: p=%.4f v=%.2f -> %.1f", progress, velocity.x, snapped);
	return snapped;
}

- (CGFloat)_scrollMin {
	return %orig;
}

- (CGFloat)opacityForIndex:(NSUInteger)index scrollProgress:(CGFloat)progress {
	CGFloat value = %orig;
	{} // muted 
	if (!SUActive()) return value;
	return 1.0;
}

- (SURectCornerRadii)cornerRadiiForIndex:(NSUInteger)index {
	SURectCornerRadii radii = %orig;
	{} // muted 
	if (!SUActive()) return radii;
	radii.a = radii.b = radii.c = radii.d = kSUCardCornerRadius;
	return radii;
}

// iOS 7 background: the wallpaper, unblurred, lightly dimmed.
- (CGFloat)homeScreenBackdropBlurProgress {
	if (!SUActive()) return %orig;
	return 0.0;
}

- (CGFloat)homeScreenDimmingAlpha {
	if (!SUActive()) return %orig;
	return 0.25;
}

// iOS 7 showed only the wallpaper behind the cards — hide the icon plane.
- (CGFloat)homeScreenAlpha {
	if (!SUActive()) return %orig;
	return 0.0;
}

%end

#pragma mark - Per-card footer: big icon + label with parallax

static char kSUFooterKey;
static CGFloat const kSUFooterIconSize = 60.0;
static CGFloat const kSUFooterSpacing = 22.0;
static CGFloat const kSUParallax = 0.25;

@interface SBReusableSnapshotItemContainer : UIView
- (id)appLayout;
@end

static NSString *SUBundleIDForContainer(SBReusableSnapshotItemContainer *container) {
	@try {
		id appLayout = [container respondsToSelector:@selector(appLayout)] ? [container appLayout] : nil;
		if (!appLayout) return nil;
		id items = [appLayout respondsToSelector:@selector(allItems)] ? [appLayout performSelector:@selector(allItems)] : nil;
		id item = nil;
		if ([items respondsToSelector:@selector(anyObject)]) item = [items performSelector:@selector(anyObject)];
		else if ([items respondsToSelector:@selector(firstObject)]) item = [items performSelector:@selector(firstObject)];
		if ([item respondsToSelector:@selector(bundleIdentifier)]) return [item performSelector:@selector(bundleIdentifier)];
	} @catch (NSException *e) {
		SULog(@"bundleID: exception %@", e);
	}
	return nil;
}

static char kSUFooterBundleKey;

static UIView *SUFooterForContainer(SBReusableSnapshotItemContainer *container, BOOL createIfNeeded) {
	UIView *footer = objc_getAssociatedObject(container, &kSUFooterKey);
	NSString *bundleID = SUBundleIDForContainer(container);

	// Containers are recycled between apps — rebuild the footer if stale.
	if (footer) {
		NSString *footerBundleID = objc_getAssociatedObject(footer, &kSUFooterBundleKey);
		if (bundleID && ![footerBundleID isEqualToString:bundleID]) {
			[footer removeFromSuperview];
			objc_setAssociatedObject(container, &kSUFooterKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			footer = nil;
		}
	}
	if (footer || !createIfNeeded) return footer;
	if (!bundleID) return nil;

	footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 120, kSUFooterIconSize + 26)];
	footer.userInteractionEnabled = NO;

	UIImage *iconImage = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:2 scale:[UIScreen mainScreen].scale];
	UIImageView *iconView = [[UIImageView alloc] initWithImage:iconImage];
	iconView.frame = CGRectMake((120 - kSUFooterIconSize) / 2.0, 0, kSUFooterIconSize, kSUFooterIconSize);
	iconView.contentMode = UIViewContentModeScaleAspectFit;
	[footer addSubview:iconView];

	NSString *name = bundleID;
	id app = [[objc_getClass("SBApplicationController") sharedInstanceIfExists] applicationWithBundleIdentifier:bundleID];
	if ([app respondsToSelector:@selector(displayName)]) name = [app performSelector:@selector(displayName)] ?: bundleID;
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(-40, kSUFooterIconSize + 6, 200, 16)];
	label.text = name;
	label.font = [UIFont systemFontOfSize:13.0];
	label.textColor = [UIColor whiteColor];
	label.textAlignment = NSTextAlignmentCenter;
	[footer addSubview:label];

	objc_setAssociatedObject(footer, &kSUFooterBundleKey, bundleID, OBJC_ASSOCIATION_COPY_NONATOMIC);
	objc_setAssociatedObject(container, &kSUFooterKey, footer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return footer;
}

static char kSUFooterBaselineYKey;

// Position a footer beneath a card rect (presentation-layer accurate).
// Fades the footer out as the card is swiped upward to be killed.
static void SUPositionFooter(UIView *footer, UIView *superview, CGRect cardRect) {
	CGFloat screenCenter = superview.bounds.size.width / 2.0;
	CGFloat parallax = (CGRectGetMidX(cardRect) - screenCenter) * kSUParallax;
	footer.center = CGPointMake(CGRectGetMidX(cardRect) + parallax,
		CGRectGetMaxY(cardRect) + kSUFooterSpacing + footer.bounds.size.height / 2.0);

	NSNumber *baseline = objc_getAssociatedObject(footer, &kSUFooterBaselineYKey);
	if (!baseline || cardRect.origin.y > baseline.doubleValue) {
		baseline = @(cardRect.origin.y);
		objc_setAssociatedObject(footer, &kSUFooterBaselineYKey, baseline, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	CGFloat lift = baseline.doubleValue - cardRect.origin.y; // >0 while swiping up
	CGFloat alpha = 1.0 - MIN(MAX(lift / 90.0, 0.0), 1.0);
	footer.alpha = alpha;
}

static void SUUpdateFooterForContainer(SBReusableSnapshotItemContainer *container) {
	if (!SUActive()) return;
	UIView *superview = container.superview;
	if (!superview) return;
	UIView *footer = SUFooterForContainer(container, YES);
	if (!footer) return;
	if (footer.superview != superview) [superview addSubview:footer];
	SUPositionFooter(footer, superview, container.frame);
}

#pragma mark - Home screen card (blurred wallpaper, no icon/label)

static char kSUHomeCardKey;

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)handleHomeButtonSinglePressUpForWindowScene:(id)windowScene;
@end

@interface SUHomeCardTapHandler : NSObject
+ (instancetype)sharedHandler;
- (void)handleTap:(UITapGestureRecognizer *)recognizer;
@end

@implementation SUHomeCardTapHandler

+ (instancetype)sharedHandler {
	static SUHomeCardTapHandler *handler;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ handler = [SUHomeCardTapHandler new]; });
	return handler;
}

- (void)handleTap:(UITapGestureRecognizer *)recognizer {
	@try {
		id scene = recognizer.view.window.windowScene;
		SBUIController *controller = [objc_getClass("SBUIController") sharedInstance];
		if ([controller respondsToSelector:@selector(handleHomeButtonSinglePressUpForWindowScene:)]) {
			[controller handleHomeButtonSinglePressUpForWindowScene:scene];
			SULog(@"home card tapped -> home");
		}
	} @catch (NSException *e) {
		SULog(@"home card tap: exception %@", e);
	}
}

@end

static void SUUpdateHomeCard(UIView *contentView, CGRect leadingCardFrame) {
	UIView *homeCard = objc_getAssociatedObject(contentView, &kSUHomeCardKey);
	if (!homeCard) {
		UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
		blurView.layer.cornerRadius = kSUCardCornerRadius;
		blurView.layer.cornerCurve = kCACornerCurveContinuous;
		blurView.clipsToBounds = YES;
		blurView.userInteractionEnabled = YES;
		UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:[SUHomeCardTapHandler sharedHandler] action:@selector(handleTap:)];
		[blurView addGestureRecognizer:tap];
		homeCard = blurView;
		objc_setAssociatedObject(contentView, &kSUHomeCardKey, homeCard, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	if (homeCard.superview != contentView) {
		[contentView insertSubview:homeCard atIndex:0];
	}
	homeCard.frame = leadingCardFrame;
	homeCard.hidden = NO;
}

static void SUSweepContentView(UIView *contentView) {
	if (!SUActive() || !contentView) return;
	Class containerClass = objc_getClass("SBReusableSnapshotItemContainer");
	CGRect trailingFrame = CGRectNull;
	for (UIView *subview in contentView.subviews) {
		if ([subview isKindOfClass:containerClass]) {
			// Clear any stray mirror transform from older builds.
			if (subview.transform.a < 0) subview.transform = CGAffineTransformScale(subview.transform, -1.0, 1.0);
			SUUpdateFooterForContainer((SBReusableSnapshotItemContainer *)subview);
			if (CGRectIsNull(trailingFrame) || subview.frame.origin.x < trailingFrame.origin.x) {
				trailingFrame = subview.frame;
			}
		}
	}
	// Home slot sits one slot left of the leading card.
	if (!CGRectIsNull(trailingFrame)) {
		CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
		CGRect homeFrame = trailingFrame;
		homeFrame.origin.x -= screenWidth * kSUCardScale + kSUCardGap;
		SUUpdateHomeCard(contentView, homeFrame);
	}
}

#pragma mark - Per-frame tracking (footers + home card follow animations)

@implementation SUFrameTracker {
	CADisplayLink *_link;
}

+ (instancetype)sharedTracker {
	static SUFrameTracker *tracker;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ tracker = [SUFrameTracker new]; });
	return tracker;
}

- (void)start {
	if (_link) return;
	_link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
	[_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stop {
	[_link invalidate];
	_link = nil;
}

- (void)tick:(__unused CADisplayLink *)link {
	UIView *contentView = gSUContentView;
	if (!SUActive() || !contentView || !contentView.window) return;
	Class containerClass = objc_getClass("SBReusableSnapshotItemContainer");
	CGRect leadingPresented = CGRectNull;
	for (UIView *subview in contentView.subviews) {
		if (![subview isKindOfClass:containerClass]) continue;
		UIView *footer = SUFooterForContainer((SBReusableSnapshotItemContainer *)subview, NO);
		CALayer *presentation = subview.layer.presentationLayer ?: subview.layer;
		CGRect rect = presentation.frame;
		if (footer && footer.superview) SUPositionFooter(footer, contentView, rect);
		if (CGRectIsNull(leadingPresented) || rect.origin.x < leadingPresented.origin.x) {
			leadingPresented = rect;
		}
	}
	UIView *homeCard = objc_getAssociatedObject(contentView, &kSUHomeCardKey);
	if (homeCard && !CGRectIsNull(leadingPresented)) {
		CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
		CGRect homeFrame = leadingPresented;
		homeFrame.origin.x -= screenWidth * kSUCardScale + kSUCardGap;
		homeCard.frame = homeFrame;
	}
}

@end

%hook SBFluidSwitcherContentView

- (void)layoutSubviews {
	%orig;
	gSUContentView = self;
	SUSweepContentView(self);
}

- (void)didAddSubview:(UIView *)subview {
	%orig;
	SUSweepContentView(self);
}

%end

%hook SBReusableSnapshotItemContainer

- (void)didMoveToSuperview {
	%orig;
	if (!self.superview) {
		UIView *footer = objc_getAssociatedObject(self, &kSUFooterKey);
		[footer removeFromSuperview];
		objc_setAssociatedObject(self, &kSUFooterKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	} else {
		SUUpdateFooterForContainer(self);
	}
}

- (void)removeFromSuperview {
	UIView *footer = objc_getAssociatedObject(self, &kSUFooterKey);
	[footer removeFromSuperview];
	objc_setAssociatedObject(self, &kSUFooterKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	%orig;
}

%end

#pragma mark - Hide the stock header (small icon + title above each card)

%hook SBFluidSwitcherItemContainerHeaderView

- (void)didMoveToWindow {
	%orig;
	if (SUActive() && self.window) self.alpha = 0.0;
}

- (void)setAlpha:(CGFloat)alpha {
	if (SUActive() && self.window && alpha > 0.0) alpha = 0.0;
	%orig(alpha);
}

%end

#pragma mark - Notification triggers (drive these over SSH with notifyutil -p)

static void SURegisterProbeTriggers(void) {
	int token = 0;
	notify_register_dispatch("com.futur3sn0w.sevenup/dump-classes", &token, dispatch_get_main_queue(), ^(__unused int t) {
		SUDumpSwitcherClasses();
	});
	static int token2 = 0;
	notify_register_dispatch("com.futur3sn0w.sevenup/dump-methods", &token2, dispatch_get_main_queue(), ^(__unused int t) {
		SUDumpInterestingMethods();
	});
	static int token3 = 0;
	notify_register_dispatch("com.futur3sn0w.sevenup/snapshot", &token3, dispatch_get_main_queue(), ^(__unused int t) {
		SUWriteSnapshot();
	});
	static int token7 = 0;
	notify_register_dispatch("com.futur3sn0w.sevenup/mode-stock", &token7, dispatch_get_main_queue(), ^(__unused int t) {
		gSUStockMode = YES;
		gSULogBudget = 400;
		SULog(@"mode: stock (passthrough, logging next 400 values)");
	});
	static int token8 = 0;
	notify_register_dispatch("com.futur3sn0w.sevenup/mode-active", &token8, dispatch_get_main_queue(), ^(__unused int t) {
		gSUStockMode = NO;
		gSULogBudget = 0;
		SULog(@"mode: active");
	});
	static int token9 = 0;
	notify_register_dispatch("com.futur3sn0w.sevenup/log-burst", &token9, dispatch_get_main_queue(), ^(__unused int t) {
		gSULogBudget = 400;
		SULog(@"log burst armed (400 lines)");
	});
	static int token11 = 0;
	notify_register_dispatch("com.futur3sn0w.sevenup/flip-reverse", &token11, dispatch_get_main_queue(), ^(__unused int t) {
		gSUReverseOrder = !gSUReverseOrder;
		SULog(@"reverseOrder=%d", gSUReverseOrder);
	});
	static int token12 = 0;
	notify_register_dispatch("com.futur3sn0w.sevenup/flip-size", &token12, dispatch_get_main_queue(), ^(__unused int t) {
		gSUCustomCardSize = !gSUCustomCardSize;
		SULog(@"customCardSize=%d", gSUCustomCardSize);
	});
	static int token10 = 0;
	notify_register_dispatch("com.futur3sn0w.sevenup/dump-hierarchy", &token10, dispatch_get_main_queue(), ^(__unused int t) {
		@try {
			UIView *root = gSUContentView;
			for (int i = 0; i < 8 && root.superview; i++) root = root.superview;
			if (!root) { SULog(@"dump-hierarchy: no known content view"); return; }
			SULog(@"===== HIERARCHY BEGIN =====");
			// Iterative BFS with depth cap to keep output manageable.
			NSMutableArray *queue = [NSMutableArray arrayWithObject:@[root, @0]];
			NSUInteger emitted = 0;
			while (queue.count > 0 && emitted < 250) {
				NSArray *entry = queue.firstObject;
				[queue removeObjectAtIndex:0];
				UIView *view = entry[0];
				NSInteger depth = [entry[1] integerValue];
				if (depth > 7) continue;
				NSString *pad = [@"" stringByPaddingToLength:depth * 2 withString:@" " startingAtIndex:0];
				CGRect f = view.frame;
				SULog(@"%@%s frame={%.0f,%.0f %.0fx%.0f} hidden=%d alpha=%.2f", pad,
					class_getName(view.class), f.origin.x, f.origin.y, f.size.width, f.size.height,
					view.hidden, view.alpha);
				emitted++;
				for (UIView *sub in view.subviews) [queue addObject:@[sub, @(depth + 1)]];
			}
			SULog(@"===== HIERARCHY END (%lu views) =====", (unsigned long)emitted);
		} @catch (NSException *e) {
			SULog(@"dump-hierarchy: exception %@", e);
		}
	});
	static int token6 = 0;
	notify_register_dispatch("com.futur3sn0w.sevenup/snapshot-switcher", &token6, dispatch_get_main_queue(), ^(__unused int t) {
		@try {
			UIView *view = gSUContentView;
			for (int i = 0; i < 8 && view.superview; i++) view = view.superview;
			if (!view || !view.window) { SULog(@"snapshot-switcher: no live switcher view"); return; }
			UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
			format.scale = 1.0;
			UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:view.bounds format:format];
			UIImage *image = [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *ctx) {
				[view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
			}];
			NSData *png = UIImagePNGRepresentation(image);
			[png writeToFile:kSUSnapPath atomically:YES];
			SULog(@"snapshot-switcher: wrote %lu bytes", (unsigned long)png.length);
		} @catch (NSException *e) {
			SULog(@"snapshot-switcher: exception %@", e);
		}
	});
	static int token4 = 0;
	notify_register_dispatch("com.futur3sn0w.sevenup/prefs-changed", &token4, dispatch_get_main_queue(), ^(__unused int t) {
		SULoadPrefs();
		SULog(@"prefs reloaded: enabled=%d", gSUEnabled);
	});
	static int token5 = 0;
	notify_register_dispatch("com.futur3sn0w.sevenup/toggle-switcher", &token5, dispatch_get_main_queue(), ^(__unused int t) {
		@try {
			SEL toggleSel = NSSelectorFromString(@"toggleMainSwitcherNoninteractivelyWithSource:animated:windowScene:");
			id controller = nil;
			for (NSString *name in @[ @"SBMainSwitcherControllerCoordinator", @"SBSwitcherController" ]) {
				Class cls = objc_getClass(name.UTF8String);
				if (!cls) continue;
				id candidate = nil;
				if ([cls respondsToSelector:@selector(sharedInstance)]) candidate = [cls sharedInstance];
				if (candidate && [candidate respondsToSelector:toggleSel]) { controller = candidate; break; }
				SULog(@"toggle-switcher: %@ instance=%@ responds=NO", name, candidate);
			}
			if (!controller) { SULog(@"toggle-switcher: no responder found"); return; }
			NSMethodSignature *sig = [controller methodSignatureForSelector:toggleSel];
			NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
			inv.target = controller;
			inv.selector = toggleSel;
			NSInteger source = 1;
			BOOL animated = YES;
			id scene = nil;
			[inv setArgument:&source atIndex:2];
			[inv setArgument:&animated atIndex:3];
			[inv setArgument:&scene atIndex:4];
			[inv invoke];
			BOOL result = NO;
			[inv getReturnValue:&result];
			SULog(@"toggle-switcher: %@ result=%d", [controller class], result);
		} @catch (NSException *e) {
			SULog(@"toggle-switcher: exception %@", e);
		}
	});
}

%ctor {
	@autoreleasepool {
		SULoadPrefs();
		SURegisterProbeTriggers();
		SULog(@"SevenUp v0.2.0 loaded in %@ (iOS %@, enabled=%d)",
			[NSProcessInfo processInfo].processName,
			[UIDevice currentDevice].systemVersion,
			gSUEnabled);
	}
}
