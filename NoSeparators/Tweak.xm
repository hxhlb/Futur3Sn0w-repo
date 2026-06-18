#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import <UIKit/UIKit.h>

@interface _UIBarBackground : UIView
@end

@interface _UINavigationControllerManagedSearchPalette : UIView
@end

@interface UICollectionViewControllerWrapperView : UIView
@end

static CFStringRef const kPrefsDomain = CFSTR("com.futur3sn0w.noseparators.preferences");

static BOOL gEnabled = YES;
static BOOL gHideTableSeparators = YES;
static BOOL gHideTabBarTopBorder = NO;
static BOOL gHideNavigationBarBottomBorder = NO;

static BOOL NSPreferenceBool(NSString *key, BOOL defaultValue) {
	Boolean valid = false;
	Boolean value = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)key, kPrefsDomain, &valid);
	return valid ? (BOOL)value : defaultValue;
}

static void NSLoadPrefs(void) {
	CFPreferencesAppSynchronize(kPrefsDomain);
	gEnabled = NSPreferenceBool(@"Enabled", YES);
	gHideTableSeparators = NSPreferenceBool(@"HideTableSeparators", YES);
	gHideTabBarTopBorder = NSPreferenceBool(@"HideTabBarTopBorder", NO);
	gHideNavigationBarBottomBorder = NSPreferenceBool(@"HideNavigationBarBottomBorder", NO);
}

static BOOL NSShouldHideTableSeparator(UITableView *tableView) {
	return gEnabled && gHideTableSeparators && tableView.window != nil;
}

static void NSApplyTableSeparatorPreference(UITableView *tableView) {
	if (!NSShouldHideTableSeparator(tableView)) {
		return;
	}

	if (tableView.separatorStyle != UITableViewCellSeparatorStyleNone) {
		tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	}

	if (tableView.separatorColor != nil) {
		tableView.separatorColor = nil;
	}
}

static BOOL NSViewHasAncestorOfClass(UIView *view, Class targetClass) {
	for (UIView *current = view.superview; current != nil; current = current.superview) {
		if ([current isKindOfClass:targetClass]) {
			return YES;
		}
	}

	return NO;
}

static BOOL NSCurrentBundleIdentifierEquals(NSString *bundleIdentifier) {
	return [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:bundleIdentifier];
}

static BOOL NSIsBottomSeparatorImageView(UIView *view, UIView *rootView) {
	if (![view isKindOfClass:[UIImageView class]]) {
		return NO;
	}

	if (view.superview == nil) {
		return NO;
	}

	CGRect frame = [view.superview convertRect:view.frame toView:rootView];
	if (!(CGRectGetHeight(frame) > 0.0 && CGRectGetHeight(frame) <= 1.0 && CGRectGetWidth(frame) >= 40.0)) {
		return NO;
	}

	CGFloat edgeDistance = fabs(CGRectGetMaxY(frame) - CGRectGetHeight(rootView.bounds));
	return edgeDistance <= 3.0;
}

static BOOL NSIsTopSeparatorImageView(UIView *view, UIView *rootView) {
	if (![view isKindOfClass:[UIImageView class]]) {
		return NO;
	}

	if (view.superview == nil) {
		return NO;
	}

	CGRect frame = [view.superview convertRect:view.frame toView:rootView];
	if (!(CGRectGetHeight(frame) > 0.0 && CGRectGetHeight(frame) <= 1.0 && CGRectGetWidth(frame) >= 40.0)) {
		return NO;
	}

	CGFloat edgeDistance = fabs(CGRectGetMinY(frame));
	return edgeDistance <= 2.0;
}

static BOOL NSIsBottomSeparatorPlainView(UIView *view, UIView *rootView) {
	if ([view isKindOfClass:[UIImageView class]]) {
		return NO;
	}

	if (view.superview == nil) {
		return NO;
	}

	CGRect frame = [view.superview convertRect:view.frame toView:rootView];
	if (!(CGRectGetHeight(frame) > 0.0 && CGRectGetHeight(frame) <= 1.0 && CGRectGetWidth(frame) >= 40.0)) {
		return NO;
	}

	CGFloat edgeDistance = fabs(CGRectGetMaxY(frame) - CGRectGetHeight(rootView.bounds));
	return edgeDistance <= 4.0;
}

static void NSClearBottomSeparatorIfNeeded(UIView *candidate, UIView *rootView) {
	if (!NSIsBottomSeparatorImageView(candidate, rootView)) {
		return;
	}

	UIImageView *separatorView = (UIImageView *)candidate;
	separatorView.image = nil;
	separatorView.highlightedImage = nil;
	separatorView.layer.contents = nil;
	separatorView.backgroundColor = [UIColor clearColor];
}

static void NSClearTopSeparatorIfNeeded(UIView *candidate, UIView *rootView) {
	if (!NSIsTopSeparatorImageView(candidate, rootView)) {
		return;
	}

	UIImageView *separatorView = (UIImageView *)candidate;
	separatorView.image = nil;
	separatorView.highlightedImage = nil;
	separatorView.layer.contents = nil;
	separatorView.backgroundColor = [UIColor clearColor];
}

static void NSClearBottomPlainSeparatorIfNeeded(UIView *candidate, UIView *rootView) {
	if (!NSIsBottomSeparatorPlainView(candidate, rootView)) {
		return;
	}

	candidate.layer.contents = nil;
	candidate.backgroundColor = [UIColor clearColor];
}

static void NSScanBottomSeparatorCandidates(UIView *containerView, UIView *rootView, NSInteger remainingDepth) {
	for (UIView *subview in containerView.subviews) {
		NSClearBottomSeparatorIfNeeded(subview, rootView);

		if (remainingDepth <= 0) {
			continue;
		}

		NSScanBottomSeparatorCandidates(subview, rootView, remainingDepth - 1);
	}
}

static void NSScanTopSeparatorCandidates(UIView *containerView, UIView *rootView, NSInteger remainingDepth) {
	for (UIView *subview in containerView.subviews) {
		NSClearTopSeparatorIfNeeded(subview, rootView);

		if (remainingDepth <= 0) {
			continue;
		}

		NSScanTopSeparatorCandidates(subview, rootView, remainingDepth - 1);
	}
}

static void NSApplyNavigationBarBackgroundPreference(_UIBarBackground *backgroundView) {
	if (!gEnabled || !gHideNavigationBarBottomBorder || backgroundView.window == nil) {
		return;
	}

	if (!NSViewHasAncestorOfClass(backgroundView, [UINavigationBar class])) {
		return;
	}

	NSScanBottomSeparatorCandidates(backgroundView, backgroundView, 4);
}

static void NSApplyTabBarBackgroundPreference(_UIBarBackground *backgroundView) {
	if (!gEnabled || !gHideTabBarTopBorder || backgroundView.window == nil) {
		return;
	}

	if (!NSViewHasAncestorOfClass(backgroundView, [UITabBar class])) {
		return;
	}

	NSScanTopSeparatorCandidates(backgroundView, backgroundView, 1);
}

static void NSApplyTabBarPreference(UITabBar *tabBar) {
	if (!gEnabled || !gHideTabBarTopBorder || tabBar.window == nil) {
		return;
	}

	NSScanTopSeparatorCandidates(tabBar, tabBar, 2);
}

static void NSApplyNavigationBarPreference(UINavigationBar *navigationBar) {
	if (!gEnabled || !gHideNavigationBarBottomBorder || navigationBar.window == nil) {
		return;
	}

	NSScanBottomSeparatorCandidates(navigationBar, navigationBar, 2);
}

static void NSApplyManagedSearchPalettePreference(_UINavigationControllerManagedSearchPalette *paletteView) {
	if (!gEnabled || !gHideNavigationBarBottomBorder || paletteView.window == nil) {
		return;
	}

	NSScanBottomSeparatorCandidates(paletteView, paletteView, 3);
}

static void NSApplyWeatherBottomSeparatorPreference(UICollectionViewControllerWrapperView *wrapperView) {
	if (!gEnabled || !gHideTabBarTopBorder || wrapperView.window == nil) {
		return;
	}

	if (!NSCurrentBundleIdentifierEquals(@"com.apple.weather")) {
		return;
	}

	for (UIView *subview in wrapperView.subviews) {
		NSClearBottomPlainSeparatorIfNeeded(subview, wrapperView);
	}
}

%hook UITableView

- (void)didMoveToWindow {
	%orig;

	__weak UITableView *weakTableView = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		UITableView *strongTableView = weakTableView;
		if (!strongTableView) {
			return;
		}

		NSApplyTableSeparatorPreference(strongTableView);
	});
}

%end

%hook _UIBarBackground

- (void)layoutSubviews {
	%orig;
	NSApplyTabBarBackgroundPreference(self);
	NSApplyNavigationBarBackgroundPreference(self);

	__weak _UIBarBackground *weakBackgroundView = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		_UIBarBackground *strongBackgroundView = weakBackgroundView;
		if (!strongBackgroundView) {
			return;
		}

		NSApplyTabBarBackgroundPreference(strongBackgroundView);
		NSApplyNavigationBarBackgroundPreference(strongBackgroundView);
		dispatch_async(dispatch_get_main_queue(), ^{
			NSApplyTabBarBackgroundPreference(strongBackgroundView);
		});
	});
}

%end

%hook UINavigationBar

- (void)layoutSubviews {
	%orig;
	NSApplyNavigationBarPreference(self);

	__weak UINavigationBar *weakNavigationBar = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		UINavigationBar *strongNavigationBar = weakNavigationBar;
		if (!strongNavigationBar) {
			return;
		}

		NSApplyNavigationBarPreference(strongNavigationBar);
	});
}

%end

%hook UITabBar

- (void)layoutSubviews {
	%orig;
	NSApplyTabBarPreference(self);

	__weak UITabBar *weakTabBar = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		UITabBar *strongTabBar = weakTabBar;
		if (!strongTabBar) {
			return;
		}

		NSApplyTabBarPreference(strongTabBar);
	});
}

%end

%hook _UINavigationControllerManagedSearchPalette

- (void)layoutSubviews {
	%orig;
	NSApplyManagedSearchPalettePreference(self);

	__weak _UINavigationControllerManagedSearchPalette *weakPaletteView = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		_UINavigationControllerManagedSearchPalette *strongPaletteView = weakPaletteView;
		if (!strongPaletteView) {
			return;
		}

		NSApplyManagedSearchPalettePreference(strongPaletteView);
	});
}

%end

%hook UICollectionViewControllerWrapperView

- (void)layoutSubviews {
	%orig;
	NSApplyWeatherBottomSeparatorPreference(self);

	__weak UICollectionViewControllerWrapperView *weakWrapperView = self;
	dispatch_async(dispatch_get_main_queue(), ^{
		UICollectionViewControllerWrapperView *strongWrapperView = weakWrapperView;
		if (!strongWrapperView) {
			return;
		}

		NSApplyWeatherBottomSeparatorPreference(strongWrapperView);
	});
}

%end

%ctor {
	@autoreleasepool {
		NSLoadPrefs();
	}
}
