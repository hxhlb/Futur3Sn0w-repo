// DockLibrary — swipe up from the dock to open the App Library.
// iOS 14–16, rootless. (c) 2026 futur3sn0w

#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - Private interfaces

@interface SBHIconManager : NSObject
@end

@interface SBIconController : NSObject
+ (instancetype)sharedInstance;
- (SBHIconManager *)iconManager;
- (void)presentLibraryOverlayForIconManager:(id)iconManager;
- (void)dismissLibraryOverlayAnimated:(BOOL)animated;
- (id)_rootFolderController;
- (id)overlayLibraryViewController;
- (id)_libraryViewControllerForWindowScene:(id)scene;
- (NSArray *)_libraryViewControllers;
- (NSArray *)libraryViewControllersForIconManager:(id)mgr;
- (void)presentLibraryForIconManager:(id)mgr windowScene:(id)scene animated:(BOOL)animated;
- (void)dismissLibraryForIconManager:(id)mgr windowScene:(id)scene animated:(BOOL)animated;
@end

@interface NSObject (DLLibraryInits)
- (id)initWithIconManager:(id)iconManager;
- (BOOL)isEditing;
@end

@interface FBSystemService : NSObject
+ (instancetype)sharedInstance;
- (void)exitAndRelaunch:(BOOL)relaunch;
@end

@interface SBDockView : UIView
- (UIView *)backgroundView;
@end

@interface SBRootFolderView : UIView
@end

#pragma mark - Prefs

static NSString * const kDLPrefsDomain = @"com.futur3sn0w.docklibrary";
static BOOL dlEnabled = YES;
static BOOL dlReplace = NO;
static NSInteger dlStyle = 0; // 0 = floating, 1 = immersive
static BOOL dlCloseOnLaunch = YES;

static void DLLoadPrefs(void) {
	CFPreferencesAppSynchronize((__bridge CFStringRef)kDLPrefsDomain);
	Boolean exists = NO;
	Boolean v = CFPreferencesGetAppBooleanValue(CFSTR("enabled"), (__bridge CFStringRef)kDLPrefsDomain, &exists);
	dlEnabled = exists ? (BOOL)v : YES;
	v = CFPreferencesGetAppBooleanValue(CFSTR("replaceLibrary"), (__bridge CFStringRef)kDLPrefsDomain, &exists);
	dlReplace = exists ? (BOOL)v : NO;
	v = CFPreferencesGetAppBooleanValue(CFSTR("closeOnLaunch"), (__bridge CFStringRef)kDLPrefsDomain, &exists);
	dlCloseOnLaunch = exists ? (BOOL)v : YES;
	CFPropertyListRef styleVal = CFPreferencesCopyAppValue(CFSTR("presentationStyle"), (__bridge CFStringRef)kDLPrefsDomain);
	if (styleVal) {
		if (CFGetTypeID(styleVal) == CFNumberGetTypeID()) {
			CFNumberGetValue((CFNumberRef)styleVal, kCFNumberNSIntegerType, &dlStyle);
		}
		CFRelease(styleVal);
	} else {
		dlStyle = 0;
	}
}

#pragma mark - Helpers

static UIView *DLFindSubview(UIView *root, NSInteger maxDepth, BOOL (^match)(UIView *v)) {
	if (!root || maxDepth < 0) return nil;
	for (UIView *sub in root.subviews) {
		if (match(sub)) return sub;
		UIView *found = DLFindSubview(sub, maxDepth - 1, match);
		if (found) return found;
	}
	return nil;
}

static void DLCollectScrollViews(UIView *root, NSInteger maxDepth, NSMutableArray *into) {
	if (!root || maxDepth < 0) return;
	for (UIView *sub in root.subviews) {
		if ([sub isKindOfClass:[UIScrollView class]]) [into addObject:sub];
		DLCollectScrollViews(sub, maxDepth - 1, into);
	}
}

static UIScrollView *DLFindScrollView(UIView *root, NSInteger maxDepth) {
	return (UIScrollView *)DLFindSubview(root, maxDepth, ^BOOL(UIView *v) {
		return [v isKindOfClass:[UIScrollView class]];
	});
}

static UIViewController *DLFindLibraryChildVC(UIViewController *root, NSInteger maxDepth) {
	if (!root || maxDepth < 0) return nil;
	for (UIViewController *child in root.childViewControllers) {
		if ([NSStringFromClass([child class]) isEqualToString:@"SBHLibraryViewController"]) return child;
		UIViewController *found = DLFindLibraryChildVC(child, maxDepth - 1);
		if (found) return found;
	}
	return nil;
}

static CGFloat DLClamp(CGFloat x, CGFloat lo, CGFloat hi) {
	return MAX(lo, MIN(hi, x));
}

static CGFloat DLLerp(CGFloat a, CGFloat b, CGFloat t) {
	return a + (b - a) * t;
}

// Companion tweak detection: if DockFull (which squares off the dock's own
// corners) is installed, the immersive drawer should start life square too
// instead of rounded, so it visually matches the dock it grows out of.
// Presence is cached with dispatch_once since it can't change without a
// respring.
static BOOL DLDockFullInstalled(void) {
	static BOOL installed = NO;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSArray<NSString *> *candidates = @[
			@"/var/jb/Library/MobileSubstrate/DynamicLibraries/DockFull.dylib",
			@"/Library/MobileSubstrate/DynamicLibraries/DockFull.dylib",
		];
		NSFileManager *fm = [NSFileManager defaultManager];
		for (NSString *path in candidates) {
			if ([fm fileExistsAtPath:path]) {
				installed = YES;
				break;
			}
		}
	});
	return installed;
}

#pragma mark - Controller

@interface DLController : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIView *dockView;
@property (nonatomic, weak) UIView *dockBackgroundView;
@property (nonatomic, weak) UIView *dockIconListView;
@property (nonatomic, weak) UIView *pagesScrollView;
@property (nonatomic, weak) UIWindow *window;

@property (nonatomic, strong) UIPanGestureRecognizer *dockPan;
@property (nonatomic, strong) UIPanGestureRecognizer *dismissPan;

@property (nonatomic, strong) UIView *libContainer;
@property (nonatomic, strong) UIView *panelBackgroundView;
@property (nonatomic, strong) UIViewController *libVC;
@property (nonatomic, strong) UIView *libView;
@property (nonatomic, weak) UIView *libViewOriginalSuperview;
@property (nonatomic, weak) UIViewController *libVCOriginalParent;
@property (nonatomic, assign) CGRect libViewOriginalFrame;
@property (nonatomic, weak) UIScrollView *libScrollView;

@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) BOOL open;
@property (nonatomic, assign) BOOL presentedOverlay;
@property (nonatomic, assign) BOOL reparentedPageVC;

@property (nonatomic, assign) CGRect originalBgFrame;
@property (nonatomic, assign) CGFloat dockBgTopInWindow;
@property (nonatomic, assign) CGFloat dockBgBottomInWindow;
@property (nonatomic, assign) CGRect bgFrameInWindow;
@property (nonatomic, assign) CGFloat openTop;
@property (nonatomic, assign) CGFloat lastProgress;
@property (nonatomic, assign) CGFloat dockCornerRadius;
@property (nonatomic, assign) BOOL sessionImmersive;

+ (instancetype)sharedController;
- (void)attachToDockView:(UIView *)dockView;
- (void)emergencyClose;
@end

@implementation DLController

+ (instancetype)sharedController {
	static DLController *shared;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		shared = [DLController new];
	});
	return shared;
}

- (void)attachToDockView:(UIView *)dockView {
	static void *kDLAttachedKey = &kDLAttachedKey;
	if (objc_getAssociatedObject(dockView, kDLAttachedKey)) return;
	objc_setAssociatedObject(dockView, kDLAttachedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	self.dockView = dockView;
	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDockPan:)];
	pan.delegate = self;
	pan.maximumNumberOfTouches = 1;
	[dockView addGestureRecognizer:pan];
	self.dockPan = pan;
	NSLog(@"[DockLibrary] attached pan to dock view %@", dockView);
}

#pragma mark Session lifecycle

- (SBIconController *)iconController {
	Class cls = objc_getClass("SBIconController");
	if (!cls) return nil;
	return [cls sharedInstance];
}

- (BOOL)beginSession {
	UIView *dock = self.dockView;
	UIWindow *win = dock.window;
	if (!dock || !win || self.active) return NO;
	self.window = win;

	// Locate dock background + icon list.
	UIView *bg = nil;
	if ([dock respondsToSelector:@selector(backgroundView)]) {
		@try {
			bg = ((UIView *(*)(id, SEL))objc_msgSend)(dock, @selector(backgroundView));
		} @catch (__unused NSException *e) {}
	}
	if (!bg) bg = DLFindSubview(dock, 3, ^BOOL(UIView *v) {
		NSString *cls = NSStringFromClass([v class]);
		return [cls rangeOfString:@"ackground"].location != NSNotFound
		    || [cls rangeOfString:@"MTMaterial"].location != NSNotFound;
	});
	UIView *iconList = DLFindSubview(dock, 3, ^BOOL(UIView *v) {
		return [NSStringFromClass([v class]) rangeOfString:@"IconListView"].location != NSNotFound;
	});
	if (!bg) bg = dock; // worst case: stretch the dock view itself
	self.dockBackgroundView = bg;
	self.dockIconListView = iconList;

	// Home screen pages (for a subtle fade behind the panel).
	UIView *pagesHost = dock.superview;
	self.pagesScrollView = pagesHost ? DLFindScrollView(pagesHost, 2) : nil;

	self.originalBgFrame = bg.frame;
	CGRect bgInWindow = [bg.superview convertRect:bg.frame toView:win];
	self.bgFrameInWindow = bgInWindow;
	self.dockBgTopInWindow = CGRectGetMinY(bgInWindow);
	self.dockBgBottomInWindow = CGRectGetMaxY(bgInWindow);
	self.sessionImmersive = (dlStyle == 1);
	self.openTop = self.sessionImmersive ? 0.0 : win.safeAreaInsets.top;

	if (![self acquireLibraryView]) {
		NSLog(@"[DockLibrary] failed to acquire App Library view controller");
		return NO;
	}

	// Container that clips the library content to the growing panel.
	UIView *container = [[UIView alloc] initWithFrame:bgInWindow];
	container.clipsToBounds = YES;
	container.backgroundColor = [UIColor clearColor];
	CGFloat radius = bg.layer.cornerRadius > 1 ? bg.layer.cornerRadius : 30.0;
	if (self.sessionImmersive && DLDockFullInstalled()) {
		// DockFull already squares off the real dock; match it instead of
		// growing a rounded drawer out of a square dock.
		radius = 0.0;
	}
	self.dockCornerRadius = radius;
	container.layer.cornerRadius = radius;
	container.layer.cornerCurve = kCACornerCurveContinuous;
	[win addSubview:container];
	self.libContainer = container;

	// Panel background: clone the dock's material so the panel IS the dock surface.
	UIView *panelBG = nil;
	Class mtCls = objc_getClass("MTMaterialView");
	if (mtCls && [bg isKindOfClass:mtCls]) {
		@try {
			NSInteger recipe = [[bg valueForKey:@"recipe"] integerValue];
			NSInteger configuration = 1;
			@try {
				configuration = [[bg valueForKey:@"configuration"] integerValue];
			} @catch (__unused NSException *e) {}
			SEL factorySel = NSSelectorFromString(@"materialViewWithRecipe:configuration:initialWeighting:");
			if ([mtCls respondsToSelector:factorySel]) {
				panelBG = ((UIView *(*)(id, SEL, long long, long long, double))objc_msgSend)(mtCls, factorySel, (long long)recipe, (long long)configuration, 1.0);
			}
		} @catch (__unused NSException *e) {
			panelBG = nil;
		}
	}
	if (!panelBG) {
		panelBG = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
	}
	panelBG.frame = container.bounds;
	panelBG.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[container addSubview:panelBG];
	self.panelBackgroundView = panelBG;

	self.libView.translatesAutoresizingMaskIntoConstraints = YES;
	self.libView.autoresizingMask = UIViewAutoresizingNone;
	@try {
		[container addSubview:self.libView];
	} @catch (NSException *e) {
		NSLog(@"[DockLibrary] add libView failed: %@", e);
		[container removeFromSuperview];
		self.libContainer = nil;
		self.panelBackgroundView = nil;
		[self restoreLibraryView];
		return NO;
	}
	self.libView.alpha = 0.0;
	self.libScrollView = DLFindScrollView(self.libView, 6);
	if (self.libScrollView) {
		// Belt-and-suspenders: the App Library content should only ever move
		// vertically. Even with the frame fix above, lock out horizontal pan/
		// bounce on its own scroll view so a stray sideways drag can't sneak in.
		self.libScrollView.alwaysBounceHorizontal = NO;
		self.libScrollView.showsHorizontalScrollIndicator = NO;
		self.libScrollView.directionalLockEnabled = YES;
	}

	self.active = YES;
	self.open = NO;
	[self applyProgress:0.0];
	return YES;
}

- (BOOL)acquireLibraryView {
	SBIconController *ic = [self iconController];
	if (!ic) return NO;
	UIViewController *vc = nil;
	self.presentedOverlay = NO;
	self.reparentedPageVC = NO;

	// 1. iOS 16: the per-window-scene library view controller (backs the trailing page).
	UIWindowScene *scene = self.window.windowScene;
	if (scene && [ic respondsToSelector:@selector(_libraryViewControllerForWindowScene:)]) {
		@try {
			vc = [ic _libraryViewControllerForWindowScene:scene];
		} @catch (__unused NSException *e) {
			vc = nil;
		}
	}
	if (!vc && [ic respondsToSelector:@selector(_libraryViewControllers)]) {
		@try {
			vc = [[ic _libraryViewControllers] firstObject];
		} @catch (__unused NSException *e) {
			vc = nil;
		}
	}
	if (!vc && [ic respondsToSelector:@selector(libraryViewControllersForIconManager:)]) {
		@try {
			vc = [[ic libraryViewControllersForIconManager:[ic iconManager]] firstObject];
		} @catch (__unused NSException *e) {
			vc = nil;
		}
	}
	if (vc) self.reparentedPageVC = YES;

	// 2. An overlay VC that already exists (e.g. left over from a previous session).
	if (!vc) {
		@try {
			if ([ic respondsToSelector:@selector(overlayLibraryViewController)]) {
				vc = [(id)ic valueForKey:@"overlayLibraryViewController"];
			}
		} @catch (__unused NSException *e) {}
	}

	// 3. Create our own instance if a friendly initializer exists.
	if (!vc) {
		Class libCls = objc_getClass("SBHLibraryViewController");
		if (libCls && [libCls instancesRespondToSelector:@selector(initWithIconManager:)]) {
			@try {
				vc = ((id (*)(id, SEL, id))objc_msgSend)([libCls alloc], @selector(initWithIconManager:), [ic iconManager]);
			} @catch (__unused NSException *e) {
				vc = nil;
			}
		}
	}

	// 4. Ask SpringBoard to build the overlay VC, then take its view over.
	if (!vc && [ic respondsToSelector:@selector(presentLibraryOverlayForIconManager:)]) {
		@try {
			[UIView performWithoutAnimation:^{
				[ic presentLibraryOverlayForIconManager:[ic iconManager]];
			}];
			if ([ic respondsToSelector:@selector(overlayLibraryViewController)]) {
				vc = [(id)ic valueForKey:@"overlayLibraryViewController"];
			}
			self.presentedOverlay = (vc != nil);
		} @catch (__unused NSException *e) {}
	}

	// 5. Last resort: scan the root folder controller's children.
	if (!vc) {
		id rfc = nil;
		@try {
			if ([ic respondsToSelector:@selector(_rootFolderController)]) rfc = [ic _rootFolderController];
		} @catch (__unused NSException *e) {}
		if ([rfc isKindOfClass:[UIViewController class]]) {
			vc = DLFindLibraryChildVC((UIViewController *)rfc, 6);
			self.reparentedPageVC = (vc != nil);
		}
	}

	if (!vc) return NO;

	self.libVC = vc;
	UIView *v = vc.view;
	if (!v) return NO;
	self.libViewOriginalSuperview = v.superview;
	self.libViewOriginalFrame = v.frame;
	self.libVCOriginalParent = vc.parentViewController;
	@try {
		// Proper containment: detach the VC from its parent while we borrow the
		// view, otherwise UIKit throws UIViewControllerHierarchyInconsistency
		// when the view enters a foreign hierarchy (crash seen 2026-07-02).
		if (vc.parentViewController) {
			[vc willMoveToParentViewController:nil];
			[vc removeFromParentViewController];
		}
		[v.layer removeAllAnimations];
		[v removeFromSuperview];
	} @catch (NSException *e) {
		NSLog(@"[DockLibrary] containment detach failed: %@", e);
		self.libVC = nil;
		return NO;
	}
	self.libView = v;
	NSLog(@"[DockLibrary] acquired %@ (overlay=%d reparented=%d)", NSStringFromClass([vc class]), self.presentedOverlay, self.reparentedPageVC);
	return YES;
}

- (void)applyProgress:(CGFloat)p {
	self.lastProgress = p;
	CGFloat clamped = DLClamp(p, 0.0, 1.0);
	CGFloat over = MAX(0.0, p - 1.0);
	CGFloat overshoot = 24.0 * (1.0 - 1.0 / (1.0 + over * 2.0));

	CGFloat travel = self.dockBgTopInWindow - self.openTop;
	CGFloat currentTop = self.dockBgTopInWindow - travel * clamped - overshoot;

	// The panel carries its own dock material; crossfade the real dock background
	// out underneath it so there's no double-blur seam.
	UIView *bg = self.dockBackgroundView;
	if (bg) {
		bg.alpha = 1.0 - DLClamp(clamped / 0.12, 0.0, 1.0);
	}

	// Panel container + library content.
	CGRect cf = self.bgFrameInWindow;
	if (self.sessionImmersive) {
		CGRect wb = self.window.bounds;
		CGFloat bottom = DLLerp(self.dockBgBottomInWindow, CGRectGetMaxY(wb), clamped);
		cf.origin.x = DLLerp(cf.origin.x, 0.0, clamped);
		cf.size.width = DLLerp(cf.size.width, wb.size.width, clamped);
		cf.origin.y = currentTop;
		cf.size.height = bottom - currentTop;
		self.libContainer.frame = cf;
		// Library content stays screen-aligned at its final size; the expanding
		// container just reveals more of it. The container/backdrop still runs
		// flush to the top of the screen, but the content itself gets a bit of
		// inset there so its search field doesn't sit behind the notch/Dynamic
		// Island once fully open.
		CGFloat immersiveContentTopInset = self.window.safeAreaInsets.top + 8.0;
		self.libView.frame = CGRectMake(-cf.origin.x, immersiveContentTopInset, wb.size.width, wb.size.height - immersiveContentTopInset);
		self.libContainer.layer.cornerRadius = DLLerp(self.dockCornerRadius, 0.0, clamped);
	} else {
		cf.origin.y = currentTop;
		cf.size.height = self.dockBgBottomInWindow - currentTop;
		self.libContainer.frame = cf;
		// Keep the library content at its natural full-window width, same as the
		// immersive branch above. Squeezing libView down to the dock's (narrower)
		// background width left its internal content -- sized for a full-width
		// App Library page -- wider than its own container, which is exactly what
		// gave it room to pan sideways. Keep it full width and shift it so the
		// (still narrower) clipping container reveals the right slice, instead of
		// squeezing the content itself.
		CGRect wbFloating = self.window.bounds;
		self.libView.frame = CGRectMake(-cf.origin.x, 0, wbFloating.size.width, self.dockBgBottomInWindow - self.openTop);
		self.libContainer.layer.cornerRadius = self.dockCornerRadius;
	}

	if (self.panelBackgroundView) {
		self.panelBackgroundView.alpha = DLClamp(clamped / 0.12, 0.0, 1.0);
	}
	self.libView.alpha = DLClamp((clamped - 0.05) / 0.30, 0.0, 1.0);
	if (self.dockIconListView) {
		self.dockIconListView.alpha = 1.0 - DLClamp(clamped / 0.35, 0.0, 1.0);
	}
	if (self.pagesScrollView) {
		self.pagesScrollView.alpha = 1.0 - 0.85 * DLClamp(clamped / 0.8, 0.0, 1.0);
	}
}

- (void)settleToOpen:(BOOL)shouldOpen velocity:(CGFloat)vy {
	CGFloat target = shouldOpen ? 1.0 : 0.0;
	__weak __typeof(self) weakSelf = self;
	[UIView animateWithDuration:0.45
	                      delay:0
	     usingSpringWithDamping:0.85
	      initialSpringVelocity:0
	                    options:(UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState)
	                 animations:^{
		[weakSelf applyProgress:target];
	} completion:^(__unused BOOL finished) {
		__typeof(self) self2 = weakSelf;
		if (!self2) return;
		if (shouldOpen) {
			self2.open = YES;
			[self2 installDismissPan];
		} else {
			[self2 teardown];
		}
	}];
}

- (void)installDismissPan {
	if (self.dismissPan || !self.libContainer) return;
	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissPan:)];
	pan.delegate = self;
	pan.maximumNumberOfTouches = 1;
	[self.libContainer addGestureRecognizer:pan];
	self.dismissPan = pan;

	// Make every scroll view inside the library defer to our dismiss pan.
	// While the library is at rest at the top, a downward drag then closes the
	// panel instead of rubber-banding into pull-to-search.
	NSMutableArray *scrollViews = [NSMutableArray array];
	DLCollectScrollViews(self.libView, 8, scrollViews);
	for (UIScrollView *sv in scrollViews) {
		@try {
			[sv.panGestureRecognizer requireGestureRecognizerToFail:pan];
		} @catch (__unused NSException *e) {}
	}
	NSLog(@"[DockLibrary] dismiss pan installed; %lu scroll views deferred", (unsigned long)scrollViews.count);
}

- (void)teardown {
	// Restore dock visuals.
	UIView *bg = self.dockBackgroundView;
	if (bg) bg.alpha = 1.0;
	if (self.dockIconListView) self.dockIconListView.alpha = 1.0;
	if (self.pagesScrollView) self.pagesScrollView.alpha = 1.0;

	[self restoreLibraryView];
	if (self.presentedOverlay) {
		SBIconController *ic = [self iconController];
		@try {
			if ([ic respondsToSelector:@selector(dismissLibraryOverlayAnimated:)]) {
				[ic dismissLibraryOverlayAnimated:NO];
			}
		} @catch (__unused NSException *e) {}
	}

	if (self.dismissPan) {
		[self.libContainer removeGestureRecognizer:self.dismissPan];
		self.dismissPan = nil;
	}
	[self.libContainer removeFromSuperview];
	self.libContainer = nil;
	self.panelBackgroundView = nil;
	self.libView = nil;
	self.libVC = nil;
	self.libScrollView = nil;
	self.presentedOverlay = NO;
	self.reparentedPageVC = NO;
	self.active = NO;
	self.open = NO;
}

- (NSString *)runSelfTest {
	NSMutableString *r = [NSMutableString string];
	if (self.active) {
		[r appendString:@"already active\n"];
		return r;
	}
	if (!self.dockView) {
		[r appendString:@"FAIL: no dock view captured\n"];
		return r;
	}
	BOOL ok = [self beginSession];
	[r appendFormat:@"beginSession=%d\n", ok];
	if (!ok) return r;
	[r appendFormat:@"libVC=%@\n", NSStringFromClass([self.libVC class])];
	[r appendFormat:@"libView=%@ frame=%@\n", NSStringFromClass([self.libView class]), NSStringFromCGRect(self.libView.frame)];
	[r appendFormat:@"bg=%@ orig=%@\n", NSStringFromClass([self.dockBackgroundView class]), NSStringFromCGRect(self.originalBgFrame)];
	[r appendFormat:@"overlay=%d reparent=%d openTop=%.1f dockTop=%.1f\n", self.presentedOverlay, self.reparentedPageVC, self.openTop, self.dockBgTopInWindow];
	[self settleToOpen:YES velocity:0];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		self.open = NO;
		[self settleToOpen:NO velocity:0];
	});
	return r;
}

- (void)restoreLibraryView {
	UIView *v = self.libView;
	UIViewController *vc = self.libVC;
	@try {
		if (v) {
			[v removeFromSuperview];
			v.alpha = 1.0;
			if (self.reparentedPageVC && self.libViewOriginalSuperview) {
				v.frame = self.libViewOriginalFrame;
				[self.libViewOriginalSuperview addSubview:v];
			}
		}
		// Re-attach the VC to its original parent (containment restore).
		UIViewController *parent = self.libVCOriginalParent;
		if (vc && parent && vc.parentViewController == nil) {
			[parent addChildViewController:vc];
			[vc didMoveToParentViewController:parent];
		}
	} @catch (NSException *e) {
		NSLog(@"[DockLibrary] restoreLibraryView failed: %@", e);
	}
	self.libVCOriginalParent = nil;
}

- (void)emergencyClose {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.active) [self teardown];
	});
}

#pragma mark Gestures

- (void)handleDockPan:(UIPanGestureRecognizer *)gr {
	UIWindow *win = self.window ?: self.dockView.window;
	switch (gr.state) {
		case UIGestureRecognizerStateBegan: {
			if (![self beginSession]) {
				gr.enabled = NO;
				gr.enabled = YES; // cancels this recognition pass
			}
			break;
		}
		case UIGestureRecognizerStateChanged: {
			if (!self.active) break;
			CGFloat ty = [gr translationInView:win].y;
			CGFloat travel = MAX(1.0, self.dockBgTopInWindow - self.openTop);
			[self applyProgress:(-ty / travel)];
			break;
		}
		case UIGestureRecognizerStateEnded:
		case UIGestureRecognizerStateCancelled:
		case UIGestureRecognizerStateFailed: {
			if (!self.active) break;
			CGFloat vy = [gr velocityInView:win].y;
			BOOL shouldOpen = (self.lastProgress > 0.35 && vy < 300.0) || vy < -600.0;
			if (self.lastProgress < 0.05) shouldOpen = NO;
			[self settleToOpen:shouldOpen velocity:vy];
			break;
		}
		default:
			break;
	}
}

- (void)handleDismissPan:(UIPanGestureRecognizer *)gr {
	UIWindow *win = self.window;
	switch (gr.state) {
		case UIGestureRecognizerStateChanged: {
			if (!self.active) break;
			CGFloat ty = [gr translationInView:win].y;
			CGFloat travel = MAX(1.0, self.dockBgTopInWindow - self.openTop);
			[self applyProgress:(1.0 - ty / travel)];
			break;
		}
		case UIGestureRecognizerStateEnded:
		case UIGestureRecognizerStateCancelled:
		case UIGestureRecognizerStateFailed: {
			if (!self.active) break;
			CGFloat vy = [gr velocityInView:win].y;
			BOOL shouldClose = (self.lastProgress < 0.65 && vy > -300.0) || vy > 600.0;
			self.open = NO;
			[self settleToOpen:!shouldClose velocity:vy];
			break;
		}
		default:
			break;
	}
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
	if (!dlEnabled) return NO;
	UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;

	if (pan == self.dockPan) {
		if (self.active) return NO;
		// Don't fight icon editing mode.
		SBIconController *ic = [self iconController];
		@try {
			id rfc = [ic respondsToSelector:@selector(_rootFolderController)] ? [ic _rootFolderController] : nil;
			if (rfc && [rfc respondsToSelector:@selector(isEditing)]) {
				BOOL editing = ((BOOL (*)(id, SEL))objc_msgSend)(rfc, @selector(isEditing));
				if (editing) return NO;
			}
		} @catch (__unused NSException *e) {}
		// Refuse while any dock icon gesture (long-press menu, drag) is engaged.
		__block BOOL iconGestureActive = NO;
		UIView *iconList = self.dockIconListView ?: self.dockView;
		if (iconList) {
			DLFindSubview(iconList, 4, ^BOOL(UIView *sub) {
				if ([NSStringFromClass([sub class]) rangeOfString:@"IconView"].location != NSNotFound) {
					for (UIGestureRecognizer *g in sub.gestureRecognizers) {
						if (g.state == UIGestureRecognizerStateBegan || g.state == UIGestureRecognizerStateChanged) {
							iconGestureActive = YES;
							return YES; // stop searching
						}
					}
				}
				return NO;
			});
		}
		if (iconGestureActive) return NO;
		CGPoint v = [pan velocityInView:pan.view];
		return (v.y < 0 && fabs(v.y) > fabs(v.x));
	}

	if (pan == self.dismissPan) {
		if (!self.open) return NO;
		CGPoint v = [pan velocityInView:pan.view];
		if (v.y <= 0 || fabs(v.x) > fabs(v.y)) return NO;
		CGPoint loc = [pan locationInView:self.libContainer];
		if (loc.y < 150.0) return YES;
		UIScrollView *sv = self.libScrollView;
		if (sv && sv.contentOffset.y <= -sv.adjustedContentInset.top + 1.0) return YES;
		return NO;
	}
	return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
	return NO;
}

@end

#pragma mark - Introspection dump (development aid)

static void DLDescribeViewTree(UIView *v, NSInteger depth, NSInteger maxDepth, NSMutableString *out) {
	if (!v || depth > maxDepth) return;
	[out appendFormat:@"%*s%@ frame=%@ alpha=%.2f hidden=%d\n", (int)(depth * 2), "", NSStringFromClass([v class]), NSStringFromCGRect(v.frame), v.alpha, v.isHidden];
	for (UIView *sub in v.subviews) {
		DLDescribeViewTree(sub, depth + 1, maxDepth, out);
	}
}

static void DLDescribeVCTree(UIViewController *vc, NSInteger depth, NSInteger maxDepth, NSMutableString *out) {
	if (!vc || depth > maxDepth) return;
	[out appendFormat:@"%*s%@\n", (int)(depth * 2), "", NSStringFromClass([vc class])];
	for (UIViewController *c in vc.childViewControllers) {
		DLDescribeVCTree(c, depth + 1, maxDepth, out);
	}
}

static void DLAppendMethods(NSMutableString *out, const char *clsName, NSArray<NSString *> *filters) {
	Class cls = objc_getClass(clsName);
	if (!cls) {
		[out appendFormat:@"(class %s not found)\n", clsName];
		return;
	}
	[out appendFormat:@"== %s ==\n", clsName];
	unsigned int count = 0;
	Method *methods = class_copyMethodList(cls, &count);
	for (unsigned int i = 0; i < count; i++) {
		NSString *sel = NSStringFromSelector(method_getName(methods[i]));
		BOOL matched = (filters.count == 0);
		for (NSString *f in filters) {
			if ([sel rangeOfString:f options:NSCaseInsensitiveSearch].location != NSNotFound) {
				matched = YES;
				break;
			}
		}
		if (matched) [out appendFormat:@"  -%@\n", sel];
	}
	free(methods);
}

static void DLWriteDump(void) {
	NSMutableString *out = [NSMutableString string];
	[out appendString:@"DockLibrary introspection dump\n\n"];

	DLAppendMethods(out, "SBIconController", @[@"librar", @"overlay", @"dock", @"present", @"dismiss"]);
	DLAppendMethods(out, "SBHLibraryViewController", @[@"init", @"icon", @"search", @"appear"]);
	DLAppendMethods(out, "SBDockView", @[]);
	DLAppendMethods(out, "SBRootFolderView", @[@"overscroll", @"librar", @"page"]);

	// Overlay machinery (iOS 16 presents the App Library as a home screen overlay).
	SBIconController *icTop = [objc_getClass("SBIconController") sharedInstance];
	@try {
		id overlay = nil;
		if ([icTop respondsToSelector:@selector(homeScreenOverlayController)]) {
			overlay = ((id (*)(id, SEL))objc_msgSend)(icTop, @selector(homeScreenOverlayController));
		}
		[out appendFormat:@"\n== homeScreenOverlayController: %@ ==\n", overlay ? NSStringFromClass([overlay class]) : @"(nil)"];
		if (overlay) {
			DLAppendMethods(out, class_getName([overlay class]), @[]);
		}
	} @catch (NSException *e) {
		[out appendFormat:@"overlay dump error: %@\n", e];
	}
	@try {
		if ([icTop respondsToSelector:@selector(_homeScreenOverlayControllerIfNeeded)]) {
			id ov2 = ((id (*)(id, SEL))objc_msgSend)(icTop, @selector(_homeScreenOverlayControllerIfNeeded));
			[out appendFormat:@"\n== _homeScreenOverlayControllerIfNeeded: %@ ==\n", ov2 ? NSStringFromClass([ov2 class]) : @"(nil)"];
			if (ov2) DLAppendMethods(out, class_getName([ov2 class]), @[]);
		}
	} @catch (NSException *e) {
		[out appendFormat:@"overlay2 dump error: %@\n", e];
	}

	[out appendString:@"\n== SB classes matching 'Overlay'/'Overscroll' ==\n"];
	unsigned int ovCount = 0;
	Class *ovClasses = objc_copyClassList(&ovCount);
	for (unsigned int i = 0; i < ovCount; i++) {
		const char *name = class_getName(ovClasses[i]);
		if ((strstr(name, "Overlay") || strstr(name, "Overscroll")) && (name[0] == 'S' && name[1] == 'B')) {
			[out appendFormat:@"  %s\n", name];
		}
	}
	free(ovClasses);

	DLAppendMethods(out, "SBRootFolderController", @[@"overlay", @"overscroll", @"custom", @"librar", @"today"]);
	DLAppendMethods(out, "SBRootFolderView", @[@"custom", @"overlay"]);

	[out appendString:@"\n== classes matching 'Library' ==\n"];
	unsigned int classCount = 0;
	Class *classes = objc_copyClassList(&classCount);
	for (unsigned int i = 0; i < classCount; i++) {
		const char *name = class_getName(classes[i]);
		if (strstr(name, "Library")) [out appendFormat:@"  %s\n", name];
	}
	free(classes);

	DLController *ctl = [DLController sharedController];
	if (ctl.dockView) {
		[out appendString:@"\n== dock view tree ==\n"];
		DLDescribeViewTree(ctl.dockView, 0, 5, out);
	}
	SBIconController *ic = [objc_getClass("SBIconController") sharedInstance];
	@try {
		id rfc = [ic respondsToSelector:@selector(_rootFolderController)] ? [ic _rootFolderController] : nil;
		if ([rfc isKindOfClass:[UIViewController class]]) {
			[out appendString:@"\n== root folder VC tree ==\n"];
			DLDescribeVCTree(rfc, 0, 6, out);
		}
	} @catch (__unused NSException *e) {}

	NSString *path = @"/var/mobile/Documents/DockLibrary-dump.txt";
	NSError *err = nil;
	[out writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err];
	NSLog(@"[DockLibrary] dump written to %@ (error: %@)", path, err);
}

#pragma mark - Hooks

%hook SBDockView

- (void)didMoveToWindow {
	%orig;
	if (self.window) {
		[[DLController sharedController] attachToDockView:(UIView *)self];
	}
}

%end

%hook SBHLibraryViewController

// Close the drawer once an app has been launched from it (optional).
- (void)_notifyObserversOfAppLaunchOfIcon:(id)icon fromLocation:(id)location {
	%orig;
	DLController *ctl = [DLController sharedController];
	if (dlEnabled && dlCloseOnLaunch && ctl.active) {
		// Give the launch transition time to cover the screen, then drop the
		// panel silently behind the app.
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[ctl emergencyClose];
		});
	}
}

%end

%hook SBRootFolderController

// iOS 16 presents the App Library by sliding the "trailing custom view" over
// the last page in response to overscroll events. Replace mode swallows them.
- (void)rootFolderView:(id)view didOverscrollOnLastPageByAmount:(double)amount {
	if (dlEnabled && dlReplace) {
		return;
	}
	%orig;
}

- (void)rootFolderView:(id)view didEndOverscrollOnLastPageWithVelocity:(double)velocity translation:(double)translation {
	if (dlEnabled && dlReplace) {
		return;
	}
	%orig;
}

%end

%hook SBRootFolderView

- (BOOL)_shouldIgnoreOverscrollOnLastPageForCurrentOrientation {
	BOOL orig = %orig;
	if (dlEnabled && dlReplace) {
		return YES;
	}
	return orig;
}

- (BOOL)_shouldIgnoreOverscrollOnLastPageForOrientation:(long long)orientation {
	BOOL orig = %orig;
	if (dlEnabled && dlReplace) {
		return YES;
	}
	return orig;
}

// iOS 16: the App Library is a real trailing custom page in the root scroll
// view (not an overscroll bounce), so replace mode removes that page.
- (unsigned long long)_trailingCustomPageCount {
	unsigned long long orig = %orig;
	if (dlEnabled && dlReplace) {
		return 0;
	}
	return orig;
}

- (BOOL)_trailingCustomViewShouldBeIndicatedInPageControl {
	BOOL orig = %orig;
	if (dlEnabled && dlReplace) {
		return NO;
	}
	return orig;
}

%end

%ctor {
	@autoreleasepool {
		DLLoadPrefs();
		int token = 0;
		notify_register_dispatch("com.futur3sn0w.docklibrary.prefs", &token, dispatch_get_main_queue(), ^(__unused int t) {
			DLLoadPrefs();
		});
		int token2 = 0;
		notify_register_dispatch("com.futur3sn0w.docklibrary.respring", &token2, dispatch_get_main_queue(), ^(__unused int t) {
			[[objc_getClass("FBSystemService") sharedInstance] exitAndRelaunch:YES];
		});
		int token3 = 0;
		notify_register_dispatch("com.futur3sn0w.docklibrary.close", &token3, dispatch_get_main_queue(), ^(__unused int t) {
			[[DLController sharedController] emergencyClose];
		});
		int token5 = 0;
		notify_register_dispatch("com.futur3sn0w.docklibrary.test", &token5, dispatch_get_main_queue(), ^(__unused int t) {
			NSString *r = [[DLController sharedController] runSelfTest];
			[r writeToFile:@"/var/mobile/Documents/DockLibrary-test.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
			NSLog(@"[DockLibrary] selftest: %@", r);
		});
		int token4 = 0;
		notify_register_dispatch("com.futur3sn0w.docklibrary.dump", &token4, dispatch_get_main_queue(), ^(__unused int t) {
			DLWriteDump();
		});
		NSLog(@"[DockLibrary] loaded (enabled=%d replace=%d)", dlEnabled, dlReplace);
	}
}
