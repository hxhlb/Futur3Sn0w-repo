#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import "SCCSectionHeaderView.h"
#import "SCCommon.h"

@interface PSSpecifier : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;

@end

@interface PSListController : UIViewController

- (NSArray *)specifiers;
- (NSRange)rangeOfSpecifiersInGroupID:(id)groupID;
- (NSIndexPath *)indexPathForSpecifier:(PSSpecifier *)specifier;
- (PSSpecifier *)specifier;
- (void)reloadSpecifier:(id)specifier animated:(BOOL)animated;
- (void)reloadSpecifierAtIndex:(NSInteger)index animated:(BOOL)animated;

@end

@interface PSUIPrefsListController : PSListController <SCCSectionHeaderViewDelegate>

- (UITableView *)table;
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;

@end

@interface SCShuffleOverlayTapProxy : NSObject

@property (nonatomic, weak) PSUIPrefsListController *controller;
@property (nonatomic, assign) NSInteger section;

- (void)handleTap:(UIButton *)button;

@end

static NSString *const kSCCLogPath = @"/var/mobile/Documents/ReSettings-log.txt";
static const void *kSCCDeferredCollapseEnabledKey = &kSCCDeferredCollapseEnabledKey;
static const void *kSCShuffleDetectedKey = &kSCShuffleDetectedKey;
static const void *kSCShuffleProbeLoggedKey = &kSCShuffleProbeLoggedKey;
static const void *kSCShuffleOverlayInstalledKey = &kSCShuffleOverlayInstalledKey;
static const void *kSCShuffleButtonSectionKey = &kSCShuffleButtonSectionKey;
static const void *kSCShuffleButtonProxyKey = &kSCShuffleButtonProxyKey;
static const void *kSCControllerActiveKey = &kSCControllerActiveKey;
static const void *kSCAppearanceGenerationKey = &kSCAppearanceGenerationKey;
static const void *kSCCollapseSuppressionDepthKey = &kSCCollapseSuppressionDepthKey;
static const void *kSCForcedExpandedForSystemMutationKey = &kSCForcedExpandedForSystemMutationKey;
static const void *kSCPendingShuffleRecollapseKey = &kSCPendingShuffleRecollapseKey;
static const void *kSCShuffleReloadScheduledKey = &kSCShuffleReloadScheduledKey;
static BOOL gSCEnabled = YES;
static BOOL gSCShuffleDylibLoaded = NO;
static BOOL gSCHeaderHooksInitialized = NO;
static Class gSCPrefsListControllerClass = Nil;
static NSMutableDictionary<NSString *, NSValue *> *gSCLastKnownRowRects = nil;
static NSMutableDictionary<NSString *, NSNumber *> *gSCLastKnownHeaderGaps = nil;
static NSMutableDictionary<NSString *, NSNumber *> *gSCLastKnownHeaderCenterOffsets = nil;
static const NSInteger kSCShuffleOverlayLabelTag = 0x53434f4c;
static const NSInteger kSCShuffleOverlayButtonTag = 0x53434f42;
static const NSInteger kSCShuffleOverlayDividerTag = 0x53434f44;
static const CGFloat kSCShuffleHeaderTopPadding = 1.0;
static const CGFloat kSCShuffleHeaderVerticalLift = 7.0;

static void SCAppendLog(NSString *message);
static BOOL SCShuffleDetected(PSUIPrefsListController *controller);
static BOOL SCShuffleProbeLogged(PSUIPrefsListController *controller);
static void SCLogShuffleProbe(PSUIPrefsListController *controller, NSString *phase);
static void SCInstallShuffleOverlayLabels(PSUIPrefsListController *controller, NSString *phase);
static void SCReloadShuffleTableAndOverlaySoon(PSUIPrefsListController *controller, NSString *phase);
static void SCApplyPendingShuffleRecollapseSoon(PSUIPrefsListController *controller, NSString *phase, NSTimeInterval delay);
static void SCSetShuffleOverlayHidden(PSUIPrefsListController *controller, BOOL hidden);
static void SCConfigureCollapseButton(UIButton *button, BOOL collapsed);
static UIView *SCFindShuffleOverlaySubview(UIView *container, NSString *identifier, Class expectedClass);
static UIView *SCShuffleOverlayContainer(UITableView *tableView);
static NSArray *SCGroupsForController(PSUIPrefsListController *controller);
static NSString *SCGroupIdentifierForSection(PSUIPrefsListController *controller, NSInteger section);
static BOOL SCIsGroupCollapsed(NSString *groupIdentifier);
static void SCSetDeferredCollapseEnabled(PSUIPrefsListController *controller, BOOL enabled);
static void SCSetShuffleOverlayInstalled(PSUIPrefsListController *controller, BOOL installed);
static void SCSetShuffleProbeLogged(PSUIPrefsListController *controller, BOOL logged);
static BOOL SCShuffleOverlayHasVisibleSubviews(PSUIPrefsListController *controller);
static BOOL SCShouldPreserveShuffleOverlayDuringReload(PSUIPrefsListController *controller, NSString *phase);

static BOOL SCApplicationIsForegroundActive(void) {
	UIApplication *application = UIApplication.sharedApplication;
	if (![application isKindOfClass:[UIApplication class]]) {
		return YES;
	}

	return application.applicationState == UIApplicationStateActive;
}

static BOOL SCControllerIsActive(PSUIPrefsListController *controller) {
	NSNumber *value = objc_getAssociatedObject(controller, kSCControllerActiveKey);
	return value == nil ? NO : value.boolValue;
}

static void SCSetControllerActive(PSUIPrefsListController *controller, BOOL active) {
	objc_setAssociatedObject(controller, kSCControllerActiveKey, @(active), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSUInteger SCAppearanceGeneration(PSUIPrefsListController *controller) {
	NSNumber *value = objc_getAssociatedObject(controller, kSCAppearanceGenerationKey);
	return value != nil ? value.unsignedIntegerValue : 0;
}

static NSUInteger SCBumpAppearanceGeneration(PSUIPrefsListController *controller) {
	NSUInteger nextValue = SCAppearanceGeneration(controller) + 1;
	objc_setAssociatedObject(controller, kSCAppearanceGenerationKey, @(nextValue), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return nextValue;
}

static BOOL SCAppearanceGenerationMatches(PSUIPrefsListController *controller, NSUInteger generation) {
	return SCAppearanceGeneration(controller) == generation;
}

static BOOL SCControllerCanMutateVisibleTable(PSUIPrefsListController *controller) {
	if (![controller isKindOfClass:[UIViewController class]]) {
		return NO;
	}

	if (!SCControllerIsActive(controller)) {
		return NO;
	}

	if (!SCApplicationIsForegroundActive()) {
		return NO;
	}

	UIView *view = controller.view;
	if (![view isKindOfClass:[UIView class]] || view.window == nil) {
		return NO;
	}

	UITableView *tableView = [controller table];
	if (![tableView isKindOfClass:[UITableView class]] || tableView.window == nil) {
		return NO;
	}

	UINavigationController *navigationController = controller.navigationController;
	if ([navigationController isKindOfClass:[UINavigationController class]] &&
		navigationController.topViewController != controller) {
		return NO;
	}

	return YES;
}

static NSUInteger SCCollapseSuppressionDepth(PSUIPrefsListController *controller) {
	NSNumber *value = objc_getAssociatedObject(controller, kSCCollapseSuppressionDepthKey);
	return value != nil ? value.unsignedIntegerValue : 0;
}

static BOOL SCCollapseSuppressed(PSUIPrefsListController *controller) {
	return SCCollapseSuppressionDepth(controller) > 0;
}

static void SCSetCollapseSuppressionDepth(PSUIPrefsListController *controller, NSUInteger depth) {
	objc_setAssociatedObject(controller, kSCCollapseSuppressionDepthKey, @(depth), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SCBeginCollapseSuppression(PSUIPrefsListController *controller, NSString *reason) {
	NSUInteger depth = SCCollapseSuppressionDepth(controller);
	SCSetCollapseSuppressionDepth(controller, depth + 1);
	if (depth == 0) {
		SCAppendLog([NSString stringWithFormat:@"collapse suppression begin %@", reason ?: @"(unknown)"]);
	}
}

static void SCEndCollapseSuppression(PSUIPrefsListController *controller, NSString *reason) {
	NSUInteger depth = SCCollapseSuppressionDepth(controller);
	if (depth == 0) {
		return;
	}

	depth -= 1;
	SCSetCollapseSuppressionDepth(controller, depth);
	if (depth == 0) {
		SCAppendLog([NSString stringWithFormat:@"collapse suppression end %@", reason ?: @"(unknown)"]);
	}
}

static void SCResetCollapseSuppression(PSUIPrefsListController *controller, NSString *reason) {
	if (SCCollapseSuppressionDepth(controller) == 0) {
		return;
	}

	SCSetCollapseSuppressionDepth(controller, 0);
	SCAppendLog([NSString stringWithFormat:@"collapse suppression reset %@", reason ?: @"(unknown)"]);
}

static BOOL SCForcedExpandedForSystemMutation(PSUIPrefsListController *controller) {
	NSNumber *value = objc_getAssociatedObject(controller, kSCForcedExpandedForSystemMutationKey);
	return value != nil ? value.boolValue : NO;
}

static void SCSetForcedExpandedForSystemMutation(PSUIPrefsListController *controller, BOOL forced) {
	objc_setAssociatedObject(controller, kSCForcedExpandedForSystemMutationKey, @(forced), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL SCPendingShuffleRecollapse(PSUIPrefsListController *controller) {
	NSNumber *value = objc_getAssociatedObject(controller, kSCPendingShuffleRecollapseKey);
	return value != nil ? value.boolValue : NO;
}

static void SCSetPendingShuffleRecollapse(PSUIPrefsListController *controller, BOOL pending) {
	objc_setAssociatedObject(controller, kSCPendingShuffleRecollapseKey, @(pending), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL SCShuffleReloadScheduled(PSUIPrefsListController *controller) {
	NSNumber *value = objc_getAssociatedObject(controller, kSCShuffleReloadScheduledKey);
	return value != nil ? value.boolValue : NO;
}

static void SCSetShuffleReloadScheduled(PSUIPrefsListController *controller, BOOL scheduled) {
	objc_setAssociatedObject(controller, kSCShuffleReloadScheduledKey, @(scheduled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation SCShuffleOverlayTapProxy

- (void)handleTap:(UIButton *)button {
	@try {
		SCAppendLog([NSString stringWithFormat:@"shuffle proxy tap section=%ld button=%@ controller=%@",
			(long)self.section,
			button ? NSStringFromClass([button class]) : @"(nil)",
			self.controller ? NSStringFromClass([self.controller class]) : @"(nil)"]);
		[self.controller sccHeaderTappedForSection:self.section];
	} @catch (NSException *exception) {
		SCAppendLog([NSString stringWithFormat:@"shuffle proxy tap exception: %@", exception]);
	}
}

@end

static NSString *SCStringValue(id value) {
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSString *SCGroupIdentifierForSection(PSUIPrefsListController *controller, NSInteger section);

static NSString *SCCollapsedPreferenceKeyForGroupIdentifier(NSString *groupIdentifier) {
	if (groupIdentifier.length == 0) {
		return @"";
	}

	return [NSString stringWithFormat:@"Collapsed_%@", groupIdentifier];
}

static BOOL SCControllerHasCollapsedGroups(PSUIPrefsListController *controller) {
	NSArray *groups = SCGroupsForController(controller);
	if (![groups isKindOfClass:[NSArray class]]) {
		return NO;
	}

	for (NSInteger section = 0; section < (NSInteger)groups.count; section++) {
		NSString *groupIdentifier = SCGroupIdentifierForSection(controller, section);
		if (SCIsCollapsibleGroupIdentifier(groupIdentifier) && SCIsGroupCollapsed(groupIdentifier)) {
			return YES;
		}
	}

	return NO;
}

static BOOL SCIsGroupCollapsed(NSString *groupIdentifier) {
	if (groupIdentifier.length == 0) {
		return NO;
	}

	Boolean valid = false;
	Boolean value = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)SCCollapsedPreferenceKeyForGroupIdentifier(groupIdentifier),
		(__bridge CFStringRef)kSCPrefsDomain,
		&valid);
	return valid ? (BOOL)value : NO;
}

static void SCSetGroupCollapsed(NSString *groupIdentifier, BOOL collapsed) {
	if (groupIdentifier.length == 0) {
		return;
	}

	CFPreferencesSetAppValue((__bridge CFStringRef)SCCollapsedPreferenceKeyForGroupIdentifier(groupIdentifier),
		collapsed ? kCFBooleanTrue : kCFBooleanFalse,
		(__bridge CFStringRef)kSCPrefsDomain);
	CFPreferencesAppSynchronize((__bridge CFStringRef)kSCPrefsDomain);
}

static BOOL SCBeginForcedExpansionForSystemMutation(PSUIPrefsListController *controller, NSString *reason) {
	if (!SCShuffleDetected(controller) || SCForcedExpandedForSystemMutation(controller)) {
		return NO;
	}

	if (!SCControllerHasCollapsedGroups(controller)) {
		return NO;
	}

	UITableView *tableView = [controller table];
	if (![tableView isKindOfClass:[UITableView class]]) {
		return NO;
	}

	SCSetForcedExpandedForSystemMutation(controller, YES);
	SCAppendLog([NSString stringWithFormat:@"forced expansion begin %@", reason ?: @"(unknown)"]);
	NSString *prepareReason = reason.length > 0 ? [reason stringByAppendingString:@" prepare"] : @"forced expansion prepare";
	SCBeginCollapseSuppression(controller, prepareReason);
	[UIView performWithoutAnimation:^{
		[tableView reloadData];
		[tableView layoutIfNeeded];
	}];
	SCEndCollapseSuppression(controller, prepareReason);
	return YES;
}

static void SCRestoreForcedExpansionAfterSystemMutation(PSUIPrefsListController *controller, NSString *reason) {
	if (!SCForcedExpandedForSystemMutation(controller)) {
		return;
	}

	SCSetForcedExpandedForSystemMutation(controller, NO);
	SCAppendLog([NSString stringWithFormat:@"forced expansion end %@", reason ?: @"(unknown)"]);
	if (SCControllerCanMutateVisibleTable(controller) && !SCCollapseSuppressed(controller)) {
		SCSetPendingShuffleRecollapse(controller, NO);
		SCReloadShuffleTableAndOverlaySoon(controller, reason ?: @"restore");
	} else if (SCShuffleDetected(controller)) {
		SCSetPendingShuffleRecollapse(controller, YES);
		SCAppendLog([NSString stringWithFormat:@"queued pending shuffle recollapse %@", reason ?: @"(unknown)"]);
	}
}

static void SCRefreshShuffleOverlaySoon(PSUIPrefsListController *controller, NSString *phase) {
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if (!SCControllerCanMutateVisibleTable(controller)) {
			SCAppendLog([NSString stringWithFormat:@"skipping shuffle overlay refresh %@ because controller is not visible",
				phase ?: @"(null)"]);
			return;
		}
		if (SCShuffleDetected(controller) && SCShuffleProbeLogged(controller)) {
			SCSetShuffleOverlayHidden(controller, NO);
			SCLogShuffleProbe(controller, phase);
			SCInstallShuffleOverlayLabels(controller, phase);
		}
	});
}

static void SCApplyPendingShuffleRecollapseSoonWithRetries(PSUIPrefsListController *controller, NSString *phase, NSTimeInterval delay, NSInteger retriesRemaining) {
	NSUInteger generation = SCAppearanceGeneration(controller);
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if (!SCAppearanceGenerationMatches(controller, generation)) {
			SCAppendLog([NSString stringWithFormat:@"skipping stale pending shuffle recollapse %@", phase ?: @"(null)"]);
			return;
		}
		if (!SCPendingShuffleRecollapse(controller)) {
			return;
		}
		if (!SCControllerCanMutateVisibleTable(controller) || SCCollapseSuppressed(controller)) {
			SCAppendLog([NSString stringWithFormat:@"pending shuffle recollapse not ready %@", phase ?: @"(null)"]);
			if (retriesRemaining > 0) {
				SCApplyPendingShuffleRecollapseSoonWithRetries(controller, phase, 0.18, retriesRemaining - 1);
			}
			return;
		}

		SCAppendLog([NSString stringWithFormat:@"applying pending shuffle recollapse %@", phase ?: @"(null)"]);
		SCSetPendingShuffleRecollapse(controller, NO);
		SCSetDeferredCollapseEnabled(controller, YES);
		SCSetShuffleOverlayInstalled(controller, YES);
		SCSetShuffleProbeLogged(controller, YES);
		SCReloadShuffleTableAndOverlaySoon(controller, phase ?: @"pending-recollapse");
	});
}

static void SCApplyPendingShuffleRecollapseSoon(PSUIPrefsListController *controller, NSString *phase, NSTimeInterval delay) {
	SCApplyPendingShuffleRecollapseSoonWithRetries(controller, phase, delay, 6);
}

static BOOL SCShouldBypassRowLevelSpecifierReload(PSUIPrefsListController *controller) {
	return SCShuffleDetected(controller) && SCControllerHasCollapsedGroups(controller);
}

static void SCScheduleSafeSpecifierRefresh(PSUIPrefsListController *controller, NSString *reason) {
	if (!SCShuffleDetected(controller)) {
		if (SCControllerCanMutateVisibleTable(controller)) {
			UITableView *tableView = [controller table];
			if ([tableView isKindOfClass:[UITableView class]]) {
				[tableView reloadData];
			}
		}
		return;
	}

	if (SCControllerCanMutateVisibleTable(controller) && !SCCollapseSuppressed(controller)) {
		SCAppendLog([NSString stringWithFormat:@"safe specifier refresh %@", reason ?: @"(unknown)"]);
		SCSetDeferredCollapseEnabled(controller, YES);
		SCSetShuffleOverlayInstalled(controller, YES);
		SCReloadShuffleTableAndOverlaySoon(controller, reason ?: @"safe-specifier-refresh");
		return;
	}

	SCSetPendingShuffleRecollapse(controller, YES);
	SCAppendLog([NSString stringWithFormat:@"queued safe specifier refresh %@", reason ?: @"(unknown)"]);
}

static CGFloat SCRoundToScreenScale(CGFloat value) {
	CGFloat scale = UIScreen.mainScreen.scale;
	if (scale <= 0.0) {
		return round(value);
	}

	return round(value * scale) / scale;
}

static void SCReloadShuffleTableAndOverlaySoon(PSUIPrefsListController *controller, NSString *phase) {
	if (!SCControllerCanMutateVisibleTable(controller)) {
		SCAppendLog([NSString stringWithFormat:@"skipping shuffle table reload %@ because controller is not visible",
			phase ?: @"(null)"]);
		return;
	}

	if (SCShuffleReloadScheduled(controller)) {
		SCAppendLog([NSString stringWithFormat:@"coalescing shuffle table reload %@", phase ?: @"(null)"]);
		return;
	}

	UITableView *tableView = [controller table];
	if (![tableView isKindOfClass:[UITableView class]]) {
		return;
	}

	SCSetShuffleReloadScheduled(controller, YES);
	BOOL preserveOverlay = SCShouldPreserveShuffleOverlayDuringReload(controller, phase);
	if (!preserveOverlay) {
		SCSetShuffleOverlayHidden(controller, YES);
	} else {
		SCAppendLog([NSString stringWithFormat:@"preserving visible shuffle overlay during reload %@",
			phase ?: @"(null)"]);
	}
	CGPoint preservedOffset = tableView.contentOffset;
	[UIView performWithoutAnimation:^{
		[tableView reloadData];
		[tableView layoutIfNeeded];
		if (isfinite(preservedOffset.x) && isfinite(preservedOffset.y)) {
			[tableView setContentOffset:preservedOffset animated:NO];
		}
	}];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		SCSetShuffleReloadScheduled(controller, NO);
		SCRefreshShuffleOverlaySoon(controller, phase);
	});
}

static CGSize SCCollapseButtonFittingSize(UIButton *button, CGFloat maxHeight) {
	if (![button isKindOfClass:[UIButton class]]) {
		return CGSizeZero;
	}

	CGFloat resolvedMaxHeight = MAX(18.0, maxHeight);
	CGSize fittingSize = [button sizeThatFits:CGSizeMake(CGFLOAT_MAX, resolvedMaxHeight)];
	CGFloat width = ceil(fittingSize.width);
	CGFloat height = ceil(fittingSize.height);

	if (width <= 0.0) {
		width = 76.0;
	}
	if (height <= 0.0) {
		height = 22.0;
	}

	width = MAX(width, 74.0);
	height = MIN(MAX(height, 18.0), resolvedMaxHeight);
	return CGSizeMake(width, height);
}

static void SCRememberRowRect(NSString *groupIdentifier, CGRect rect) {
	if (groupIdentifier.length == 0 || CGRectIsNull(rect) || CGRectIsEmpty(rect) || CGRectGetWidth(rect) <= 0.0) {
		return;
	}

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		gSCLastKnownRowRects = [NSMutableDictionary dictionary];
	});
	gSCLastKnownRowRects[groupIdentifier] = [NSValue valueWithCGRect:rect];
}

static CGRect SCCachedRowRect(NSString *groupIdentifier) {
	if (groupIdentifier.length == 0 || gSCLastKnownRowRects == nil) {
		return CGRectNull;
	}

	NSValue *value = gSCLastKnownRowRects[groupIdentifier];
	return value != nil ? value.CGRectValue : CGRectNull;
}

static void SCRememberHeaderGap(NSString *groupIdentifier, CGFloat gap) {
	if (groupIdentifier.length == 0 || gap <= 0.0) {
		return;
	}

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		gSCLastKnownHeaderGaps = [NSMutableDictionary dictionary];
	});
	gSCLastKnownHeaderGaps[groupIdentifier] = @(gap);
}

static CGFloat SCCachedHeaderGap(NSString *groupIdentifier) {
	if (groupIdentifier.length == 0 || gSCLastKnownHeaderGaps == nil) {
		return 0.0;
	}

	NSNumber *value = gSCLastKnownHeaderGaps[groupIdentifier];
	return value != nil ? value.doubleValue : 0.0;
}

static void SCRememberHeaderCenterOffset(NSString *groupIdentifier, CGFloat offset) {
	if (groupIdentifier.length == 0 || offset <= 0.0) {
		return;
	}

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		gSCLastKnownHeaderCenterOffsets = [NSMutableDictionary dictionary];
	});
	gSCLastKnownHeaderCenterOffsets[groupIdentifier] = @(offset);
}

static void SCCaptureLiveShuffleHeaderCenterOffset(PSUIPrefsListController *controller, NSInteger section) {
	UITableView *tableView = [controller table];
	if (![tableView isKindOfClass:[UITableView class]]) {
		return;
	}

	UIView *container = SCShuffleOverlayContainer(tableView);
	if (![container isKindOfClass:[UIView class]]) {
		return;
	}

	NSString *groupIdentifier = SCGroupIdentifierForSection(controller, section);
	if (groupIdentifier.length == 0) {
		return;
	}

	NSString *labelIdentifier = [NSString stringWithFormat:@"SCShuffleLabel_%ld", (long)section];
	NSString *buttonIdentifier = [NSString stringWithFormat:@"SCShuffleToggle_%ld", (long)section];
	UILabel *label = (UILabel *)SCFindShuffleOverlaySubview(container, labelIdentifier, [UILabel class]);
	UIButton *button = (UIButton *)SCFindShuffleOverlaySubview(container, buttonIdentifier, [UIButton class]);
	CGRect headerRect = [tableView rectForHeaderInSection:section];
	if (CGRectIsEmpty(headerRect)) {
		return;
	}

	CGFloat centerY = 0.0;
	if ([button isKindOfClass:[UIButton class]] && !CGRectIsEmpty(button.frame)) {
		centerY = CGRectGetMidY(button.frame);
	} else if ([label isKindOfClass:[UILabel class]] && !CGRectIsEmpty(label.frame)) {
		centerY = CGRectGetMidY(label.frame);
	}

	if (centerY > 0.0) {
		SCRememberHeaderCenterOffset(groupIdentifier, SCRoundToScreenScale(centerY - CGRectGetMinY(headerRect)));
		SCAppendLog([NSString stringWithFormat:@"captured live shuffle center section=%ld group=%@ centerY=%0.2f",
			(long)section,
			groupIdentifier,
			centerY]);
	}
}

static UIColor *SCBubbleForegroundColor(void) {
	if (@available(iOS 13.0, *)) {
		return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
			if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
				return [UIColor colorWithWhite:1.0 alpha:0.96];
			}

			return [UIColor colorWithWhite:0.20 alpha:0.92];
		}];
	}

	return [UIColor colorWithWhite:0.20 alpha:0.92];
}

static UIColor *SCBubbleBackgroundColor(void) {
	if (@available(iOS 13.0, *)) {
		return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
			if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
				return [UIColor colorWithWhite:1.0 alpha:0.18];
			}

			return [UIColor colorWithWhite:0.0 alpha:0.08];
		}];
	}

	return [UIColor colorWithWhite:0.0 alpha:0.08];
}

static UIColor *SCDividerColor(void) {
	if (@available(iOS 13.0, *)) {
		return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
			if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
				return [UIColor colorWithWhite:1.0 alpha:0.16];
			}

			return [UIColor colorWithWhite:0.0 alpha:0.12];
		}];
	}

	return [UIColor colorWithWhite:0.0 alpha:0.12];
}

static void SCConfigureCollapseButton(UIButton *button, BOOL collapsed) {
	NSString *buttonTitle = collapsed ? @"EXPAND" : @"COLLAPSE";
	UIImage *chevronImage = nil;
	if (@available(iOS 13.0, *)) {
		UIImageSymbolConfiguration *symbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:9.0 weight:UIImageSymbolWeightSemibold];
		chevronImage = [UIImage systemImageNamed:(collapsed ? @"chevron.right" : @"chevron.down") withConfiguration:symbolConfiguration];
	}

	if (@available(iOS 15.0, *)) {
		UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
		configuration.contentInsets = NSDirectionalEdgeInsetsMake(4.0, 10.0, 4.0, 10.0);
		configuration.baseForegroundColor = SCBubbleForegroundColor();
		configuration.background.backgroundColor = SCBubbleBackgroundColor();
		configuration.background.cornerRadius = 11.0;
		configuration.image = chevronImage;
		configuration.imagePlacement = NSDirectionalRectEdgeTrailing;
		configuration.imagePadding = 5.0;
		configuration.title = buttonTitle;
		configuration.attributedTitle = [[NSAttributedString alloc] initWithString:buttonTitle attributes:@{
			NSFontAttributeName: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold],
			NSKernAttributeName: @0.5
		}];
		button.configuration = configuration;
	} else {
		[button setTitle:buttonTitle forState:UIControlStateNormal];
		[button setTitleColor:SCBubbleForegroundColor() forState:UIControlStateNormal];
		button.titleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
		button.backgroundColor = SCBubbleBackgroundColor();
		button.layer.cornerRadius = 11.0;
	}
}

static void SCAppendLog(NSString *message) {
	@try {
		NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], message ?: @"(null)"];
		NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
		if (data == nil) {
			return;
		}

		if (![[NSFileManager defaultManager] fileExistsAtPath:kSCCLogPath]) {
			[data writeToFile:kSCCLogPath atomically:YES];
			return;
		}

		NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kSCCLogPath];
		[handle seekToEndOfFile];
		[handle writeData:data];
		[handle closeFile];
	} @catch (__unused NSException *exception) {
	}
}

static id SCSafeValueForKey(id object, NSString *key) {
	if (object == nil || key.length == 0) {
		return nil;
	}

	@try {
		return [object valueForKey:key];
	} @catch (__unused NSException *exception) {
		return nil;
	}
}

static NSString *SCSafeSpecifierString(PSSpecifier *specifier, NSString *selectorName, NSString *fallbackKey) {
	if (specifier == nil) {
		return nil;
	}

	SEL selector = NSSelectorFromString(selectorName);
	if ([specifier respondsToSelector:selector]) {
		NSString *value = SCStringValue(((id (*)(id, SEL))objc_msgSend)(specifier, selector));
		if (value.length > 0) {
			return value;
		}
	}

	return SCStringValue(SCSafeValueForKey(specifier, fallbackKey));
}

static NSArray *SCGroupsForController(PSUIPrefsListController *controller) {
	id groups = SCSafeValueForKey(controller, @"_groups");
	return [groups isKindOfClass:[NSArray class]] ? groups : nil;
}

static void SCLogControllerStructure(PSUIPrefsListController *controller) {
	@try {
		NSArray *groups = SCGroupsForController(controller);
		NSArray *specifiers = [controller specifiers];
		SCAppendLog([NSString stringWithFormat:@"structure class=%@ groups=%lu specifiers=%lu",
			NSStringFromClass([controller class]),
			(unsigned long)groups.count,
			(unsigned long)([specifiers isKindOfClass:[NSArray class]] ? specifiers.count : 0)]);

		if (![groups isKindOfClass:[NSArray class]] || ![specifiers isKindOfClass:[NSArray class]]) {
			return;
		}

		NSUInteger limit = MIN(groups.count, 16);
		for (NSUInteger section = 0; section < limit; section++) {
			id groupIndexValue = groups[section];
			if (![groupIndexValue isKindOfClass:[NSNumber class]]) {
				SCAppendLog([NSString stringWithFormat:@"section=%lu groupIndex=(invalid:%@)",
					(unsigned long)section,
					NSStringFromClass([groupIndexValue class])]);
				continue;
			}

			NSInteger groupIndex = [groupIndexValue integerValue];
			if (groupIndex < 0 || groupIndex >= (NSInteger)specifiers.count) {
				SCAppendLog([NSString stringWithFormat:@"section=%lu groupIndex=%ld out-of-range",
					(unsigned long)section,
					(long)groupIndex]);
				continue;
			}

			PSSpecifier *specifier = specifiers[(NSUInteger)groupIndex];
			NSString *identifier = SCSafeSpecifierString(specifier, @"identifier", @"identifier") ?: @"";
			NSString *name = SCSafeSpecifierString(specifier, @"name", @"name") ?: @"";
			SCAppendLog([NSString stringWithFormat:@"section=%lu groupIndex=%ld identifier=%@ name=%@",
				(unsigned long)section,
				(long)groupIndex,
				identifier,
				name]);
		}
	} @catch (NSException *exception) {
		SCAppendLog([NSString stringWithFormat:@"structure exception on %@: %@", NSStringFromClass([controller class]), exception]);
	}
}

static void SCPersistDetectedControllerStructure(PSUIPrefsListController *controller, BOOL shuffleDetected) {
	@try {
		NSArray *groups = SCGroupsForController(controller);
		NSArray *specifiers = [controller specifiers];
		if (![groups isKindOfClass:[NSArray class]] || ![specifiers isKindOfClass:[NSArray class]]) {
			return;
		}

		NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
		NSUInteger limit = MIN(groups.count, 24);
		for (NSUInteger section = 0; section < limit; section++) {
			id groupIndexValue = groups[section];
			if (![groupIndexValue isKindOfClass:[NSNumber class]]) {
				continue;
			}

			NSInteger groupIndex = [groupIndexValue integerValue];
			if (groupIndex < 0 || groupIndex >= (NSInteger)specifiers.count) {
				continue;
			}

			PSSpecifier *specifier = specifiers[(NSUInteger)groupIndex];
			NSString *identifier = SCSafeSpecifierString(specifier, @"identifier", @"identifier");
			NSString *name = SCSafeSpecifierString(specifier, @"name", @"name");
			NSString *groupValue = identifier.length > 0 ? identifier : name;
			if (groupValue.length > 0) {
				[identifiers addObject:groupValue];
			}
		}

		CFPreferencesSetAppValue((__bridge CFStringRef)kSCDetectedRootModeKey,
			(__bridge CFStringRef)(shuffleDetected ? @"shuffle" : @"stock"),
			(__bridge CFStringRef)kSCPrefsDomain);
		CFPreferencesSetAppValue((__bridge CFStringRef)kSCDetectedGroupIdentifiersKey,
			(__bridge CFArrayRef)identifiers,
			(__bridge CFStringRef)kSCPrefsDomain);
		CFPreferencesAppSynchronize((__bridge CFStringRef)kSCPrefsDomain);
	} @catch (__unused NSException *exception) {
	}
}

static void SCPersistDetectedVisibleSections(PSUIPrefsListController *controller, UITableView *tableView, NSString *mode) {
	@try {
		if (![tableView isKindOfClass:[UITableView class]]) {
			return;
		}

		NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
		NSInteger sectionCount = [tableView numberOfSections];
		for (NSInteger section = 0; section < sectionCount; section++) {
			NSString *groupIdentifier = SCGroupIdentifierForSection(controller, section);
			if (SCIsCollapsibleGroupIdentifier(groupIdentifier)) {
				[identifiers addObject:groupIdentifier];
			}
		}

		if (identifiers.count == 0) {
			return;
		}

		CFPreferencesSetAppValue((__bridge CFStringRef)kSCDetectedRootModeKey,
			(__bridge CFStringRef)(mode ?: @"stock"),
			(__bridge CFStringRef)kSCPrefsDomain);
		CFPreferencesSetAppValue((__bridge CFStringRef)kSCDetectedGroupIdentifiersKey,
			(__bridge CFArrayRef)identifiers,
			(__bridge CFStringRef)kSCPrefsDomain);
		CFPreferencesAppSynchronize((__bridge CFStringRef)kSCPrefsDomain);
		SCAppendLog([NSString stringWithFormat:@"persisted visible sections mode=%@ groups=%@",
			mode ?: @"stock",
			[identifiers componentsJoinedByString:@","]]);
	} @catch (NSException *exception) {
		SCAppendLog([NSString stringWithFormat:@"persist visible sections exception: %@", exception]);
	}
}

static BOOL SCControllerHasShuffleSignature(PSUIPrefsListController *controller) {
	NSArray *groups = SCGroupsForController(controller);
	NSArray *specifiers = [controller specifiers];
	if (![groups isKindOfClass:[NSArray class]] || ![specifiers isKindOfClass:[NSArray class]]) {
		return NO;
	}

	NSUInteger limit = MIN(groups.count, 8);
	for (NSUInteger section = 0; section < limit; section++) {
		id groupIndexValue = groups[section];
		if (![groupIndexValue isKindOfClass:[NSNumber class]]) {
			continue;
		}

		NSInteger groupIndex = [groupIndexValue integerValue];
		if (groupIndex < 0 || groupIndex >= (NSInteger)specifiers.count) {
			continue;
		}

		PSSpecifier *specifier = specifiers[(NSUInteger)groupIndex];
		NSString *identifier = SCSafeSpecifierString(specifier, @"identifier", @"identifier");
		NSString *name = SCSafeSpecifierString(specifier, @"name", @"name");

		if ([identifier isEqualToString:@"SHUFFLE_GROUP"] || [name isEqualToString:@"Apps"]) {
			return YES;
		}
	}

	return NO;
}

static NSString *SCGroupIdentifierForSection(PSUIPrefsListController *controller, NSInteger section) {
	NSArray *groups = SCGroupsForController(controller);
	NSArray *specifiers = [controller specifiers];
	if (section < 0 || section >= (NSInteger)groups.count || ![specifiers isKindOfClass:[NSArray class]]) {
		return nil;
	}

	NSNumber *groupIndexNumber = groups[section];
	if (![groupIndexNumber isKindOfClass:[NSNumber class]]) {
		return nil;
	}

	NSInteger groupIndex = groupIndexNumber.integerValue;
	if (groupIndex < 0 || groupIndex >= (NSInteger)specifiers.count) {
		return nil;
	}

	PSSpecifier *groupSpecifier = specifiers[groupIndex];
	NSString *identifier = SCSafeSpecifierString(groupSpecifier, @"identifier", @"identifier");
	if (identifier.length > 0) {
		return identifier;
	}

	NSString *name = SCSafeSpecifierString(groupSpecifier, @"name", @"name");
	if (name.length > 0) {
		return [NSString stringWithFormat:@"name:%@", name];
	}

	return [NSString stringWithFormat:@"section:%ld", (long)section];
}

static BOOL SCDeferredCollapseEnabled(PSUIPrefsListController *controller) {
	NSNumber *value = objc_getAssociatedObject(controller, kSCCDeferredCollapseEnabledKey);
	return value.boolValue;
}

static void SCSetDeferredCollapseEnabled(PSUIPrefsListController *controller, BOOL enabled) {
	objc_setAssociatedObject(controller, kSCCDeferredCollapseEnabledKey, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL SCShuffleDetected(PSUIPrefsListController *controller) {
	NSNumber *value = objc_getAssociatedObject(controller, kSCShuffleDetectedKey);
	return value.boolValue;
}

static void SCSetShuffleDetected(PSUIPrefsListController *controller, BOOL detected) {
	objc_setAssociatedObject(controller, kSCShuffleDetectedKey, @(detected), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL SCShuffleProbeLogged(PSUIPrefsListController *controller) {
	NSNumber *value = objc_getAssociatedObject(controller, kSCShuffleProbeLoggedKey);
	return value.boolValue;
}

static void SCSetShuffleProbeLogged(PSUIPrefsListController *controller, BOOL logged) {
	objc_setAssociatedObject(controller, kSCShuffleProbeLoggedKey, @(logged), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL SCShuffleOverlayInstalled(PSUIPrefsListController *controller) {
	NSNumber *value = objc_getAssociatedObject(controller, kSCShuffleOverlayInstalledKey);
	return value.boolValue;
}

static void SCSetShuffleOverlayInstalled(PSUIPrefsListController *controller, BOOL installed) {
	objc_setAssociatedObject(controller, kSCShuffleOverlayInstalledKey, @(installed), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL SCEnsureShuffleDetection(PSUIPrefsListController *controller) {
	BOOL detected = SCControllerHasShuffleSignature(controller);
	if (detected && !SCShuffleDetected(controller)) {
		SCSetShuffleDetected(controller, YES);
		SCAppendLog([NSString stringWithFormat:@"shuffle signature detected on %@", NSStringFromClass([controller class])]);
	}
	return detected;
}

static void SCLoadPrefs(void) {
	Boolean valid = false;
	Boolean enabled = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)@"Enabled", (__bridge CFStringRef)kSCPrefsDomain, &valid);
	gSCEnabled = valid ? (BOOL)enabled : YES;
}

static NSString *SCClassName(id object) {
	return object ? NSStringFromClass([object class]) : @"(nil)";
}

static NSString *SCViewTextSummary(UIView *view) {
	if ([view respondsToSelector:@selector(text)]) {
		id text = ((id (*)(id, SEL))objc_msgSend)(view, @selector(text));
		if ([text isKindOfClass:[NSString class]] && [text length] > 0) {
			return text;
		}
	}

	if ([view respondsToSelector:@selector(currentTitle)]) {
		id title = ((id (*)(id, SEL))objc_msgSend)(view, @selector(currentTitle));
		if ([title isKindOfClass:[NSString class]] && [title length] > 0) {
			return title;
		}
	}

	return @"";
}

static UIView *SCShuffleOverlayContainer(UITableView *tableView) {
	for (UIView *subview in tableView.subviews) {
		if ([NSStringFromClass([subview class]) isEqualToString:@"UITableViewWrapperView"]) {
			return subview;
		}
	}

	return tableView;
}

static UIView *SCFindShuffleOverlaySubview(UIView *container, NSString *identifier, Class expectedClass) {
	if (identifier.length == 0 || ![container isKindOfClass:[UIView class]]) {
		return nil;
	}

	for (UIView *subview in container.subviews) {
		if (expectedClass != Nil && ![subview isKindOfClass:expectedClass]) {
			continue;
		}

		if ([subview.accessibilityIdentifier isEqualToString:identifier]) {
			return subview;
		}
	}

	return nil;
}

static void SCSetShuffleOverlayHidden(PSUIPrefsListController *controller, BOOL hidden) {
	UITableView *tableView = [controller table];
	if (![tableView isKindOfClass:[UITableView class]]) {
		return;
	}

	UIView *container = SCShuffleOverlayContainer(tableView);
	if (![container isKindOfClass:[UIView class]]) {
		return;
	}

	for (UIView *subview in container.subviews) {
		if (subview.tag != kSCShuffleOverlayLabelTag &&
			subview.tag != kSCShuffleOverlayButtonTag &&
			subview.tag != kSCShuffleOverlayDividerTag) {
			continue;
		}

		subview.hidden = hidden;
	}
}

static BOOL SCShuffleOverlayHasVisibleSubviews(PSUIPrefsListController *controller) {
	UITableView *tableView = [controller table];
	if (![tableView isKindOfClass:[UITableView class]]) {
		return NO;
	}

	UIView *container = SCShuffleOverlayContainer(tableView);
	if (![container isKindOfClass:[UIView class]]) {
		return NO;
	}

	for (UIView *subview in container.subviews) {
		if (subview.tag != kSCShuffleOverlayLabelTag &&
			subview.tag != kSCShuffleOverlayButtonTag &&
			subview.tag != kSCShuffleOverlayDividerTag) {
			continue;
		}

		if (!subview.hidden && subview.alpha > 0.01) {
			return YES;
		}
	}

	return NO;
}

static BOOL SCShouldPreserveShuffleOverlayDuringReload(PSUIPrefsListController *controller, NSString *phase) {
	if (!SCShuffleDetected(controller) || !SCShuffleOverlayHasVisibleSubviews(controller)) {
		return NO;
	}

	if ([phase isKindOfClass:[NSString class]] &&
		[phase rangeOfString:@"willBecomeActive"].location != NSNotFound) {
		return YES;
	}

	return NO;
}

static void SCRemoveStaleShuffleOverlaySubviews(UIView *container, NSSet<NSString *> *liveIdentifiers) {
	NSArray<UIView *> *subviews = [container.subviews copy];
	for (UIView *subview in subviews) {
		if (subview.tag != kSCShuffleOverlayLabelTag && subview.tag != kSCShuffleOverlayButtonTag && subview.tag != kSCShuffleOverlayDividerTag) {
			continue;
		}

		NSString *identifier = subview.accessibilityIdentifier ?: @"";
		if (![liveIdentifiers containsObject:identifier]) {
			[subview removeFromSuperview];
		}
	}
}

static CGRect SCFirstRowRectForSection(UITableView *tableView, NSInteger section) {
	if (section < 0 || section >= [tableView numberOfSections]) {
		return CGRectNull;
	}

	if ([tableView numberOfRowsInSection:section] <= 0) {
		return CGRectNull;
	}

	return [tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:section]];
}

static CGRect SCResolvedFirstRowRectForSection(UITableView *tableView, NSInteger section) {
	CGRect rowRect = SCFirstRowRectForSection(tableView, section);
	if (section < 0 || section >= [tableView numberOfSections]) {
		return rowRect;
	}

	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:section];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	if (cell != nil && !cell.hidden && cell.superview != nil) {
		CGRect liveRect = [tableView convertRect:cell.frame fromView:cell.superview];
		if (!CGRectIsEmpty(liveRect)) {
			return liveRect;
		}
	}

	return rowRect;
}

static BOOL SCShouldShowCollapseControlForSection(PSUIPrefsListController *controller, NSInteger section) {
	if (!gSCEnabled) {
		return NO;
	}

	NSString *groupIdentifier = SCGroupIdentifierForSection(controller, section);
	return SCIsCollapsibleGroupIdentifier(groupIdentifier);
}

static SCCSectionHeaderView *SCConfiguredHeaderView(UITableView *tableView, PSUIPrefsListController *controller, NSInteger section) {
	if (![tableView isKindOfClass:[UITableView class]]) {
		return nil;
	}

	NSString *groupIdentifier = SCGroupIdentifierForSection(controller, section);
	NSString *title = SCFriendlyTitleForGroupIdentifier(groupIdentifier);
	if (title.length == 0) {
		return nil;
	}

	SCCSectionHeaderView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"SCCSectionHeaderView"];
	if (headerView == nil) {
		headerView = [[SCCSectionHeaderView alloc] initWithReuseIdentifier:@"SCCSectionHeaderView"];
	}

	headerView.section = section;
	headerView.delegate = (id<SCCSectionHeaderViewDelegate>)controller;
	headerView.leadingInset = 16.0;
	headerView.trailingInset = 16.0;
	headerView.bottomInset = 4.0;
	[headerView configureWithTitle:title collapsed:SCIsGroupCollapsed(groupIdentifier)];
	return headerView;
}

static void SCInstallShuffleOverlayLabels(PSUIPrefsListController *controller, NSString *phase) {
	@try {
		if (!SCControllerCanMutateVisibleTable(controller)) {
			SCAppendLog([NSString stringWithFormat:@"skipping shuffle overlay install %@ because controller is not visible",
				phase ?: @"(null)"]);
			return;
		}

		UITableView *tableView = [controller table];
		if (![tableView isKindOfClass:[UITableView class]]) {
			return;
		}

		UIView *container = SCShuffleOverlayContainer(tableView);
		if (![container isKindOfClass:[UIView class]]) {
			return;
		}
		container.clipsToBounds = NO;

		SCPersistDetectedVisibleSections(controller, tableView, @"shuffle");
		NSMutableSet<NSString *> *liveIdentifiers = [NSMutableSet set];

		NSInteger sectionCount = [tableView numberOfSections];
		for (NSInteger section = 0; section < sectionCount; section++) {
			if (!SCShouldShowCollapseControlForSection(controller, section)) {
				continue;
			}

			NSString *groupIdentifier = SCGroupIdentifierForSection(controller, section);
			CGRect headerRect = [tableView rectForHeaderInSection:section];
			if (CGRectIsEmpty(headerRect) || headerRect.size.height < 10.0) {
				continue;
			}

			NSInteger rowCount = [tableView numberOfRowsInSection:section];
			CGRect firstRowRect = CGRectNull;
			CGRect widthReferenceRect = SCCachedRowRect(groupIdentifier);
			if (rowCount > 0) {
				firstRowRect = SCResolvedFirstRowRectForSection(tableView, section);
				if (!CGRectIsNull(firstRowRect) && CGRectGetWidth(firstRowRect) > 0.0) {
					SCRememberRowRect(groupIdentifier, firstRowRect);
					widthReferenceRect = firstRowRect;
				} else {
					widthReferenceRect = SCCachedRowRect(groupIdentifier);
					firstRowRect = CGRectNull;
				}
			}
			CGFloat labelX = 16.0;
			CGFloat labelWidth = CGRectGetWidth(container.bounds);
			if (!CGRectIsNull(widthReferenceRect) && CGRectGetWidth(widthReferenceRect) > 0.0) {
				labelX = CGRectGetMinX(widthReferenceRect);
				labelWidth = CGRectGetWidth(widthReferenceRect);
			}

			CGFloat gapHeight = MAX(16.0, CGRectGetHeight(headerRect) + 2.0);
			if (!CGRectIsNull(firstRowRect) && CGRectGetMinY(firstRowRect) > CGRectGetMinY(headerRect)) {
				gapHeight = MAX(16.0, CGRectGetMinY(firstRowRect) - CGRectGetMinY(headerRect));
				SCRememberHeaderGap(groupIdentifier, gapHeight);
			}
			NSString *labelIdentifier = [NSString stringWithFormat:@"SCShuffleLabel_%ld", (long)section];
			[liveIdentifiers addObject:labelIdentifier];
			UILabel *label = (UILabel *)SCFindShuffleOverlaySubview(container, labelIdentifier, [UILabel class]);
			BOOL newLabel = (label == nil);
			if (newLabel) {
				label = [[UILabel alloc] initWithFrame:CGRectZero];
				label.tag = kSCShuffleOverlayLabelTag;
				label.accessibilityIdentifier = labelIdentifier;
				label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
				label.textColor = [UIColor secondaryLabelColor];
				label.adjustsFontSizeToFitWidth = YES;
				label.minimumScaleFactor = 0.8;
				label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
				label.alpha = 0.0;
				label.transform = CGAffineTransformMakeTranslation(0.0, 4.0);
				[container addSubview:label];
			}
			label.text = [SCFriendlyTitleForGroupIdentifier(groupIdentifier) uppercaseString];

			UIButton *measurementButton = [UIButton buttonWithType:UIButtonTypeSystem];
			CGFloat trailingInset = 34.0;
			CGFloat buttonMaxHeight = MIN(MAX(gapHeight - 2.0, 20.0), 24.0);
			BOOL groupCollapsed = SCIsGroupCollapsed(groupIdentifier);
			if (groupCollapsed && rowCount == 0) {
				gapHeight = MAX(gapHeight, 32.0);
				CGFloat cachedHeaderGap = SCCachedHeaderGap(groupIdentifier);
				if (cachedHeaderGap > 0.0) {
					gapHeight = MAX(gapHeight, cachedHeaderGap + 6.0);
				}
			}
			SCConfigureCollapseButton(measurementButton, groupCollapsed);
			CGSize buttonSize = SCCollapseButtonFittingSize(measurementButton, buttonMaxHeight);
			CGFloat buttonWidth = buttonSize.width;
			CGFloat buttonHeight = buttonSize.height;
			CGFloat labelHeight = 12.0;
			CGFloat buttonX = MAX(labelX, CGRectGetMaxX(widthReferenceRect) - trailingInset - buttonWidth);
			if (CGRectIsNull(widthReferenceRect) || CGRectGetWidth(widthReferenceRect) <= 0.0) {
				buttonX = MAX(labelX, labelX + labelWidth - trailingInset - buttonWidth);
			}
			buttonX = SCRoundToScreenScale(buttonX);
			CGFloat contentBottom = CGRectGetMinY(headerRect) + gapHeight - 6.0;
			CGFloat cachedHeaderGap = SCCachedHeaderGap(groupIdentifier);
			if (!CGRectIsNull(firstRowRect) && CGRectGetWidth(firstRowRect) > 0.0) {
				contentBottom = CGRectGetMinY(firstRowRect) - 4.0;
			} else if (groupCollapsed && rowCount == 0 && cachedHeaderGap > 0.0) {
				contentBottom = CGRectGetMinY(headerRect) + MAX(gapHeight, cachedHeaderGap + 6.0) - 4.0;
			}

			CGFloat minCenterY = CGRectGetMinY(headerRect) + ceil(MAX(labelHeight, buttonHeight) * 0.5) + 1.0;
			CGFloat preferredCenterY = CGRectGetMinY(headerRect) + kSCShuffleHeaderTopPadding + (buttonHeight * 0.5);
			CGFloat maxCenterY = contentBottom - (buttonHeight * 0.5);
			CGFloat centerY = preferredCenterY;
			if (maxCenterY > 0.0) {
				centerY = MIN(centerY, maxCenterY);
			}
			centerY = MAX(centerY, minCenterY);
			centerY -= kSCShuffleHeaderVerticalLift;
			centerY = SCRoundToScreenScale(centerY);
			SCRememberHeaderCenterOffset(groupIdentifier, centerY - CGRectGetMinY(headerRect));

			CGFloat labelY = SCRoundToScreenScale(centerY - (labelHeight * 0.5));
			CGFloat buttonY = SCRoundToScreenScale(centerY - (buttonHeight * 0.5));
			CGRect labelFrame = CGRectMake(labelX, labelY, labelWidth, labelHeight);
			CGRect buttonFrame = CGRectMake(buttonX, buttonY, buttonWidth, buttonHeight);
			NSString *buttonIdentifier = [NSString stringWithFormat:@"SCShuffleToggle_%ld", (long)section];
			[liveIdentifiers addObject:buttonIdentifier];
			UIButton *button = (UIButton *)SCFindShuffleOverlaySubview(container, buttonIdentifier, [UIButton class]);
			BOOL newButton = (button == nil);
			if (newButton) {
				button = [UIButton buttonWithType:UIButtonTypeSystem];
				button.tag = kSCShuffleOverlayButtonTag;
				button.accessibilityIdentifier = buttonIdentifier;
				button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
				button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
				objc_setAssociatedObject(button, kSCShuffleButtonSectionKey, @(section), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
				SCShuffleOverlayTapProxy *proxy = [SCShuffleOverlayTapProxy new];
				proxy.controller = controller;
				proxy.section = section;
				objc_setAssociatedObject(button, kSCShuffleButtonProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
				[button addTarget:proxy action:@selector(handleTap:) forControlEvents:UIControlEventTouchUpInside];
				button.alpha = 0.0;
				button.transform = CGAffineTransformMakeTranslation(0.0, 4.0);
				[container addSubview:button];
			}
			SCConfigureCollapseButton(button, groupCollapsed);

			NSString *dividerIdentifier = [NSString stringWithFormat:@"SCShuffleDivider_%ld", (long)section];
			if (groupCollapsed) {
				[liveIdentifiers addObject:dividerIdentifier];
			}
			UIView *divider = (UIView *)SCFindShuffleOverlaySubview(container, dividerIdentifier, [UIView class]);
			BOOL newDivider = (divider == nil);
			CGFloat dividerHeight = 1.0 / MAX(UIScreen.mainScreen.scale, 1.0);
			CGFloat dividerLeadingInset = 10.0;
			CGFloat dividerTrailingInset = 10.0;
			CGFloat dividerX = MAX(labelX - 6.0, dividerLeadingInset);
			CGFloat dividerMaxX = MAX(dividerX, CGRectGetWidth(container.bounds) - dividerTrailingInset);
			CGFloat dividerWidth = MAX(0.0, dividerMaxX - dividerX);
			CGFloat dividerY = SCRoundToScreenScale(CGRectGetMaxY(headerRect) + (groupCollapsed ? 10.0 : 0.0));
			CGRect dividerFrame = CGRectMake(dividerX, dividerY, dividerWidth, dividerHeight);
			if (newDivider && groupCollapsed) {
				divider = [[UIView alloc] initWithFrame:dividerFrame];
				divider.tag = kSCShuffleOverlayDividerTag;
				divider.accessibilityIdentifier = dividerIdentifier;
				divider.backgroundColor = SCDividerColor();
				divider.alpha = 0.0;
				[container addSubview:divider];
			}

			[UIView animateWithDuration:0.18
				delay:0.0
				options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
				animations:^{
					label.frame = labelFrame;
					label.alpha = 1.0;
					label.transform = CGAffineTransformIdentity;
					button.frame = buttonFrame;
					button.alpha = 1.0;
					button.transform = CGAffineTransformIdentity;
					if (groupCollapsed && divider != nil) {
						divider.frame = dividerFrame;
						divider.alpha = 1.0;
					}
				}
				completion:nil];

			SCAppendLog([NSString stringWithFormat:@"shuffle overlay %@ section=%ld group=%@ title=%@ rect=%@",
				phase,
				(long)section,
				groupIdentifier ?: @"",
				SCFriendlyTitleForGroupIdentifier(groupIdentifier),
				NSStringFromCGRect(headerRect)]);
			SCAppendLog([NSString stringWithFormat:@"shuffle overlay frame %@ section=%ld labelFrame=%@ firstRowRect=%@ centerY=%0.2f container=%@",
				phase,
				(long)section,
				NSStringFromCGRect(label.frame),
				CGRectIsNull(firstRowRect) ? @"(null)" : NSStringFromCGRect(firstRowRect),
				centerY,
				NSStringFromCGRect(container.bounds)]);
			SCAppendLog([NSString stringWithFormat:@"shuffle overlay button %@ section=%ld buttonFrame=%@ gapHeight=%0.2f",
				phase,
				(long)section,
				NSStringFromCGRect(button.frame),
				gapHeight]);
		}

		SCRemoveStaleShuffleOverlaySubviews(container, liveIdentifiers);
	} @catch (NSException *exception) {
		SCAppendLog([NSString stringWithFormat:@"shuffle overlay exception %@: %@", phase, exception]);
	}
}

static void SCLogViewTreeOneLevel(UIView *rootView, NSString *prefix) {
	NSArray<UIView *> *subviews = rootView.subviews ?: @[];
	NSUInteger limit = MIN(subviews.count, 12);
	for (NSUInteger index = 0; index < limit; index++) {
		UIView *subview = subviews[index];
		NSString *textSummary = SCViewTextSummary(subview);
		SCAppendLog([NSString stringWithFormat:@"%@ subview[%lu] class=%@ frame=%@ text=%@",
			prefix,
			(unsigned long)index,
			SCClassName(subview),
			NSStringFromCGRect(subview.frame),
			textSummary]);
	}
}

static void SCLogShuffleProbe(PSUIPrefsListController *controller, NSString *phase) {
	@try {
		UITableView *tableView = [controller table];
		if (![tableView isKindOfClass:[UITableView class]]) {
			SCAppendLog([NSString stringWithFormat:@"shuffle probe %@ table=%@", phase, SCClassName(tableView)]);
			return;
		}

		SCAppendLog([NSString stringWithFormat:@"shuffle probe %@ tableClass=%@ style=%ld delegate=%@ dataSource=%@ sections=%ld visibleRows=%lu",
			phase,
			SCClassName(tableView),
			(long)tableView.style,
			SCClassName(tableView.delegate),
			SCClassName(tableView.dataSource),
			(long)[tableView numberOfSections],
			(unsigned long)tableView.indexPathsForVisibleRows.count]);

		NSArray<NSIndexPath *> *visibleRows = tableView.indexPathsForVisibleRows ?: @[];
		NSUInteger rowLimit = MIN(visibleRows.count, 16);
		for (NSUInteger index = 0; index < rowLimit; index++) {
			NSIndexPath *indexPath = visibleRows[index];
			UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
			NSString *text = cell.textLabel.text ?: @"";
			NSString *detail = cell.detailTextLabel.text ?: @"";
			SCAppendLog([NSString stringWithFormat:@"shuffle probe row section=%ld row=%ld cellClass=%@ text=%@ detail=%@",
				(long)indexPath.section,
				(long)indexPath.row,
				SCClassName(cell),
				text,
				detail]);
		}

		NSInteger sectionLimit = MIN([tableView numberOfSections], 16);
		for (NSInteger section = 0; section < sectionLimit; section++) {
			UIView *headerView = [tableView headerViewForSection:section];
			CGRect headerRect = [tableView rectForHeaderInSection:section];
			SCAppendLog([NSString stringWithFormat:@"shuffle probe section=%ld headerClass=%@ headerRect=%@ rows=%ld",
				(long)section,
				SCClassName(headerView),
				NSStringFromCGRect(headerRect),
				(long)[tableView numberOfRowsInSection:section]]);

			if ([headerView isKindOfClass:[UIView class]]) {
				SCLogViewTreeOneLevel(headerView, [NSString stringWithFormat:@"shuffle probe header[%ld]", (long)section]);
			}
		}

		SCLogViewTreeOneLevel(tableView, [NSString stringWithFormat:@"shuffle probe table %@",
			phase]);

		NSArray<UIViewController *> *children = controller.childViewControllers ?: @[];
		NSUInteger childLimit = MIN(children.count, 8);
		for (NSUInteger index = 0; index < childLimit; index++) {
			UIViewController *child = children[index];
			SCAppendLog([NSString stringWithFormat:@"shuffle probe child[%lu] class=%@ view=%@",
				(unsigned long)index,
				SCClassName(child),
				SCClassName(child.view)]);
		}
	} @catch (NSException *exception) {
		SCAppendLog([NSString stringWithFormat:@"shuffle probe exception %@: %@", phase, exception]);
	}
}

static BOOL SCIsShuffleImagePath(const char *imagePath) {
	if (imagePath == NULL) {
		return NO;
	}

	NSString *path = [NSString stringWithUTF8String:imagePath];
	if (path.length == 0) {
		return NO;
	}

	return [path localizedCaseInsensitiveContainsString:@"shuffle"];
}

static BOOL SCDetectShuffleDylibLoaded(void) {
	uint32_t imageCount = _dyld_image_count();
	for (uint32_t index = 0; index < imageCount; index++) {
		const char *imageName = _dyld_get_image_name(index);
		if (SCIsShuffleImagePath(imageName)) {
			SCAppendLog([NSString stringWithFormat:@"shuffle dylib image=%s", imageName]);
			return YES;
		}
	}

	return NO;
}

%group SettingsCollapseHeaderHooks

%hook PSUIPrefsListController

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	@try {
		UIView *originalView = %orig;
		if (!SCShouldShowCollapseControlForSection(self, section) || SCEnsureShuffleDetection(self)) {
			return originalView;
		}

		SCCSectionHeaderView *headerView = SCConfiguredHeaderView(tableView, self, section);
		return headerView ?: originalView;
	} @catch (NSException *exception) {
		SCAppendLog([NSString stringWithFormat:@"viewForHeader exception on %@ section %ld: %@",
			NSStringFromClass([self class]),
			(long)section,
			exception]);
		return %orig;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	@try {
		CGFloat originalHeight = %orig;
		if (!SCShouldShowCollapseControlForSection(self, section)) {
			return originalHeight;
		}

		return MAX(originalHeight, 24.0);
	} @catch (NSException *exception) {
		SCAppendLog([NSString stringWithFormat:@"heightForHeader exception on %@ section %ld: %@",
			NSStringFromClass([self class]),
			(long)section,
			exception]);
		return %orig;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	@try {
		NSString *originalTitle = %orig;
		if (originalTitle.length > 0) {
			return originalTitle;
		}

		if (!gSCEnabled) {
			return originalTitle;
		}

		if (SCEnsureShuffleDetection(self)) {
			return originalTitle;
		}

		NSString *groupIdentifier = SCGroupIdentifierForSection(self, section);
		if (!SCIsCollapsibleGroupIdentifier(groupIdentifier)) {
			return originalTitle;
		}

		NSString *friendlyTitle = SCFriendlyTitleForGroupIdentifier(groupIdentifier);
		if (friendlyTitle.length > 0) {
			SCAppendLog([NSString stringWithFormat:@"header title section=%ld group=%@ title=%@",
				(long)section,
				groupIdentifier ?: @"",
				friendlyTitle]);
		}
		return friendlyTitle;
	} @catch (NSException *exception) {
		SCAppendLog([NSString stringWithFormat:@"titleForHeader exception on %@ section %ld: %@",
			NSStringFromClass([self class]),
			(long)section,
			exception]);
		return %orig;
	}
}

%end
%end

%group SettingsCollapseBaseHooks

%hook PSUIPrefsListController

- (void)viewDidLoad {
	@try {
		SCAppendLog([NSString stringWithFormat:@"viewDidLoad enter %@", NSStringFromClass([self class])]);
		%orig;
		SCSetControllerActive(self, NO);
		SCResetCollapseSuppression(self, @"viewDidLoad");
		SCSetDeferredCollapseEnabled(self, NO);
		SCSetShuffleOverlayInstalled(self, NO);
		SCSetPendingShuffleRecollapse(self, NO);
		SCSetShuffleReloadScheduled(self, NO);
		SCLoadPrefs();
		BOOL shuffleDetected = SCEnsureShuffleDetection(self);
		if (!shuffleDetected && !gSCHeaderHooksInitialized && gSCPrefsListControllerClass != Nil) {
			%init(SettingsCollapseHeaderHooks, PSUIPrefsListController = gSCPrefsListControllerClass);
			gSCHeaderHooksInitialized = YES;
			SCAppendLog(@"header hook init complete (lazy)");
		}

		UITableView *tableView = [self table];
		if ([tableView isKindOfClass:[UITableView class]]) {
			[tableView registerClass:[SCCSectionHeaderView class] forHeaderFooterViewReuseIdentifier:@"SCCSectionHeaderView"];
		}

		SCLogControllerStructure(self);
		SCPersistDetectedControllerStructure(self, shuffleDetected);

		SCAppendLog([NSString stringWithFormat:@"viewDidLoad exit %@", NSStringFromClass([self class])]);
	} @catch (NSException *exception) {
		SCAppendLog([NSString stringWithFormat:@"viewDidLoad exception on %@: %@", NSStringFromClass([self class]), exception]);
	}
}

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	SCSetControllerActive(self, YES);
	SCResetCollapseSuppression(self, @"viewDidAppear");
	NSUInteger appearanceGeneration = SCBumpAppearanceGeneration(self);
	SCAppendLog([NSString stringWithFormat:@"viewDidAppear active %@", NSStringFromClass([self class])]);

	if (SCShuffleDetected(self) && SCPendingShuffleRecollapse(self)) {
		SCApplyPendingShuffleRecollapseSoon(self, @"viewDidAppear", 0.05);
		return;
	}

	if (SCDeferredCollapseEnabled(self)) {
		if (SCShuffleDetected(self) && SCShuffleOverlayInstalled(self)) {
			SCSetShuffleOverlayHidden(self, NO);
			if (!SCShuffleOverlayHasVisibleSubviews(self)) {
				SCRefreshShuffleOverlaySoon(self, @"reappear");
			}
		}
		return;
	}

	if (SCShuffleDetected(self)) {
		if (SCShuffleOverlayInstalled(self) && SCShuffleProbeLogged(self)) {
			SCAppendLog([NSString stringWithFormat:@"refreshing existing shuffle overlay %@", NSStringFromClass([self class])]);
			SCSetDeferredCollapseEnabled(self, YES);
			SCSetShuffleOverlayHidden(self, NO);
			if (!SCShuffleOverlayHasVisibleSubviews(self)) {
				SCRefreshShuffleOverlaySoon(self, @"reappear");
			}
			return;
		}
		SCAppendLog([NSString stringWithFormat:@"skipping deferred collapse because Shuffle is active on %@", NSStringFromClass([self class])]);
		if (!SCShuffleProbeLogged(self)) {
			SCSetShuffleProbeLogged(self, YES);
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				if (!SCAppearanceGenerationMatches(self, appearanceGeneration) || !SCControllerCanMutateVisibleTable(self)) {
					SCAppendLog(@"skipping stale shuffle phase1");
					return;
				}
				SCLogShuffleProbe(self, @"phase1");
			});
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.90 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				if (!SCAppearanceGenerationMatches(self, appearanceGeneration) || !SCControllerCanMutateVisibleTable(self)) {
					SCAppendLog(@"skipping stale shuffle phase2");
					return;
				}
				SCSetDeferredCollapseEnabled(self, YES);
				SCSetShuffleOverlayInstalled(self, YES);
				SCAppendLog(@"shuffle collapse ready; reloading table");
				SCReloadShuffleTableAndOverlaySoon(self, @"phase2");
			});
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.50 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				if (!SCAppearanceGenerationMatches(self, appearanceGeneration) || !SCControllerCanMutateVisibleTable(self)) {
					SCAppendLog(@"skipping stale shuffle phase3");
					return;
				}
				SCLogShuffleProbe(self, @"phase3");
				SCInstallShuffleOverlayLabels(self, @"phase3");
			});
		}
		return;
	}

	SCAppendLog([NSString stringWithFormat:@"viewDidAppear scheduling deferred collapse %@", NSStringFromClass([self class])]);

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if (!SCAppearanceGenerationMatches(self, appearanceGeneration) || !SCControllerCanMutateVisibleTable(self)) {
			SCAppendLog(@"skipping stale deferred collapse");
			return;
		}
		if (SCDeferredCollapseEnabled(self)) {
			return;
		}

		SCSetDeferredCollapseEnabled(self, YES);
		SCAppendLog([NSString stringWithFormat:@"deferred collapse enabled %@", NSStringFromClass([self class])]);

		UITableView *tableView = [self table];
		[tableView reloadData];
	});
}

- (void)viewWillDisappear:(BOOL)animated {
	%orig;

	@try {
		SCSetControllerActive(self, NO);
		SCBumpAppearanceGeneration(self);
		if (SCShuffleDetected(self)) {
			if (SCApplicationIsForegroundActive()) {
				SCAppendLog([NSString stringWithFormat:@"viewWillDisappear preserving live shuffle overlay %@", NSStringFromClass([self class])]);
				return;
			}

			SCSetShuffleReloadScheduled(self, NO);
			SCAppendLog([NSString stringWithFormat:@"viewWillDisappear preserving background shuffle overlay state %@", NSStringFromClass([self class])]);
		}
		SCSetDeferredCollapseEnabled(self, NO);
	} @catch (NSException *exception) {
		SCAppendLog([NSString stringWithFormat:@"viewWillDisappear exception on %@: %@",
			NSStringFromClass([self class]),
			exception]);
	}
}

- (void)didEnterBackground {
	SCSetControllerActive(self, NO);
	SCSetShuffleReloadScheduled(self, NO);
	SCBeginForcedExpansionForSystemMutation(self, @"didEnterBackground");
	SCBeginCollapseSuppression(self, @"didEnterBackground");
	%orig;
	SCEndCollapseSuppression(self, @"didEnterBackground");
}

- (void)willBecomeActive {
	SCBeginCollapseSuppression(self, @"willBecomeActive");
	%orig;
	SCSetControllerActive(self, YES);
	SCEndCollapseSuppression(self, @"willBecomeActive");
	SCRestoreForcedExpansionAfterSystemMutation(self, @"willBecomeActive");
	if (SCShuffleDetected(self) && SCPendingShuffleRecollapse(self)) {
		SCApplyPendingShuffleRecollapseSoon(self, @"willBecomeActive", 0.12);
	}
}

- (void)reloadSpecifiers {
	BOOL forcedExpansion = SCBeginForcedExpansionForSystemMutation(self, @"reloadSpecifiers");
	SCBeginCollapseSuppression(self, @"reloadSpecifiers");
	%orig;
	SCEndCollapseSuppression(self, @"reloadSpecifiers");
	if (forcedExpansion) {
		SCRestoreForcedExpansionAfterSystemMutation(self, @"reloadSpecifiers");
	}
}

- (void)checkDeveloperSettingsState {
	BOOL forcedExpansion = SCBeginForcedExpansionForSystemMutation(self, @"checkDeveloperSettingsState");
	SCBeginCollapseSuppression(self, @"checkDeveloperSettingsState");
	%orig;
	SCEndCollapseSuppression(self, @"checkDeveloperSettingsState");
	if (forcedExpansion) {
		SCRestoreForcedExpansionAfterSystemMutation(self, @"checkDeveloperSettingsState");
	}
}

- (void)reloadSpecifier:(id)specifier animated:(BOOL)animated {
	if (SCShouldBypassRowLevelSpecifierReload(self)) {
		SCAppendLog(@"bypassing row-level reloadSpecifier for collapsed Shuffle state");
		SCScheduleSafeSpecifierRefresh(self, @"reloadSpecifier bypass");
		return;
	}

	SCBeginCollapseSuppression(self, @"reloadSpecifier");
	%orig;
	SCEndCollapseSuppression(self, @"reloadSpecifier");
}

- (void)reloadSpecifierAtIndex:(NSInteger)index animated:(BOOL)animated {
	if (SCShouldBypassRowLevelSpecifierReload(self)) {
		SCAppendLog([NSString stringWithFormat:@"bypassing row-level reloadSpecifierAtIndex index=%ld for collapsed Shuffle state",
			(long)index]);
		SCScheduleSafeSpecifierRefresh(self, @"reloadSpecifierAtIndex bypass");
		return;
	}

	SCBeginCollapseSuppression(self, @"reloadSpecifierAtIndex");
	%orig;
	SCEndCollapseSuppression(self, @"reloadSpecifierAtIndex");
}

- (void)viewDidLayoutSubviews {
	%orig;
}

%new
- (void)sccHeaderTappedForSection:(NSInteger)section {
	@try {
		SCAppendLog([NSString stringWithFormat:@"header tap received section=%ld class=%@ shuffle=%@",
			(long)section,
			NSStringFromClass([self class]),
			SCShuffleDetected(self) ? @"YES" : @"NO"]);
		SCLoadPrefs();
		if (!SCShouldShowCollapseControlForSection(self, section)) {
			SCAppendLog([NSString stringWithFormat:@"header tap ignored section=%ld", (long)section]);
			return;
		}

		NSString *groupIdentifier = SCGroupIdentifierForSection(self, section);
		BOOL wasCollapsed = SCIsGroupCollapsed(groupIdentifier);
		UITableView *tableView = [self table];
		BOOL collapsed = !SCIsGroupCollapsed(groupIdentifier);
		SCSetDeferredCollapseEnabled(self, YES);
		if (SCShuffleDetected(self)) {
			SCCaptureLiveShuffleHeaderCenterOffset(self, section);
		}
		SCSetGroupCollapsed(groupIdentifier, collapsed);
		SCAppendLog([NSString stringWithFormat:@"toggled section=%ld group=%@ collapsed=%@",
			(long)section,
			groupIdentifier ?: @"",
			collapsed ? @"YES" : @"NO"]);

		if (wasCollapsed != collapsed) {
			if (SCShuffleDetected(self)) {
				@try {
					SCAppendLog(@"animating shuffle section after toggle");
					[tableView reloadSections:[NSIndexSet indexSetWithIndex:(NSUInteger)section] withRowAnimation:UITableViewRowAnimationAutomatic];
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.18 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
						SCRefreshShuffleOverlaySoon(self, @"toggle");
					});
					SCAppendLog(@"animated shuffle section after toggle");
				} @catch (NSException *animationException) {
					SCAppendLog([NSString stringWithFormat:@"shuffle animation fallback on section %ld: %@",
						(long)section,
						animationException]);
					SCAppendLog(@"reloading shuffle table after toggle");
					SCReloadShuffleTableAndOverlaySoon(self, @"toggle");
					SCAppendLog(@"reloaded shuffle table after toggle");
				}
			} else {
				SCAppendLog(@"animating table after toggle");
				[tableView reloadSections:[NSIndexSet indexSetWithIndex:(NSUInteger)section] withRowAnimation:UITableViewRowAnimationAutomatic];
				SCAppendLog(@"animated table after toggle");
			}
		} else {
			SCAppendLog(@"reloading table after toggle");
			[tableView reloadData];
			SCAppendLog(@"reloaded table after toggle");
		}

		UIView *headerView = [tableView headerViewForSection:section];
		if ([headerView isKindOfClass:[SCCSectionHeaderView class]]) {
			[(SCCSectionHeaderView *)headerView configureWithTitle:SCFriendlyTitleForGroupIdentifier(groupIdentifier) collapsed:collapsed];
		}
		if (SCShuffleDetected(self)) {
			SCRefreshShuffleOverlaySoon(self, @"toggle");
		}
	} @catch (NSException *exception) {
		SCAppendLog([NSString stringWithFormat:@"toggle exception on %@ section %ld: %@",
			NSStringFromClass([self class]),
			(long)section,
			exception]);
	}
}

%new
- (void)sccShuffleOverlayButtonPressed:(UIButton *)button {
	@try {
		NSNumber *sectionValue = objc_getAssociatedObject(button, kSCShuffleButtonSectionKey);
		SCAppendLog([NSString stringWithFormat:@"shuffle overlay button pressed section=%@",
			sectionValue ?: @"(null)"]);
		if (![sectionValue isKindOfClass:[NSNumber class]]) {
			return;
		}

		[self sccHeaderTappedForSection:sectionValue.integerValue];
	} @catch (NSException *exception) {
		SCAppendLog([NSString stringWithFormat:@"shuffle overlay button press exception: %@", exception]);
	}
}

%new
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
	(void)scrollView;
	(void)decelerate;
}

%new
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	(void)scrollView;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	@try {
		NSInteger originalCount = %orig;
		if (!SCControllerIsActive(self) || !SCApplicationIsForegroundActive() || SCCollapseSuppressed(self) || SCForcedExpandedForSystemMutation(self)) {
			return originalCount;
		}
		BOOL collapseReady = SCDeferredCollapseEnabled(self) || SCShuffleOverlayInstalled(self);
		if (!collapseReady) {
			return originalCount;
		}

		if (SCShouldShowCollapseControlForSection(self, section)) {
			NSString *groupIdentifier = SCGroupIdentifierForSection(self, section);
			if (SCIsGroupCollapsed(groupIdentifier)) {
				return 0;
			}
		}

		return originalCount;
	} @catch (NSException *exception) {
		SCAppendLog([NSString stringWithFormat:@"numberOfRows exception on %@ section %ld: %@",
			NSStringFromClass([self class]),
			(long)section,
			exception]);
		return %orig;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return %orig;
}

%end
%end

%ctor {
	SCAppendLog(@"loaded");

	Class prefsListControllerClass = objc_getClass("PSUIPrefsListController");
	SCAppendLog([NSString stringWithFormat:@"PSUIPrefsListController=%@", prefsListControllerClass ? NSStringFromClass(prefsListControllerClass) : @"(null)"]);

	if (prefsListControllerClass == Nil) {
		SCAppendLog(@"skipping hook init because PSUIPrefsListController is missing");
		return;
	}

	gSCPrefsListControllerClass = prefsListControllerClass;
	gSCShuffleDylibLoaded = SCDetectShuffleDylibLoaded();
	%init(SettingsCollapseBaseHooks, PSUIPrefsListController = prefsListControllerClass);
	SCAppendLog(@"base hook init complete");

	if (!gSCShuffleDylibLoaded) {
		SCAppendLog(@"header hook init deferred until non-Shuffle controller is confirmed");
	} else {
		SCAppendLog(@"skipping header hook init because Shuffle dylib is loaded");
	}
}
