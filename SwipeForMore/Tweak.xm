#import <theos/IOSMacros.h>
#import <UIKit/UIColor+Private.h>
#import <notify.h>
#import <objc/runtime.h>
#import <math.h>
#import <version.h>
#import "CydiaHeader.h"
#import "SwipeActionController.h"

#define UCLocalize(key) [[NSBundle mainBundle] localizedStringForKey:@key value:nil table:nil]

@interface UINavigationController (Cydia)
- (UIViewController *)parentOrPresentingViewController;
@end

static void UpdateExternalStatus(uint64_t newStatus) {
    int notify_token;
    if (notify_register_check("com.saurik.Cydia.status", &notify_token) == NOTIFY_STATUS_OK) {
        notify_set_state(notify_token, newStatus);
        notify_cancel(notify_token);
    }
    notify_post("com.saurik.Cydia.status");
}

BOOL enabled;

#define SAC [SwipeActionController sharedInstance]

BOOL suppressCC = NO;

CFStringRef PreferencesNotification = CFSTR("com.PS.SwipeForMore.prefs");
NSString *format = @"%@\n%@";

static void prefs() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.PS.SwipeForMore.plist"];
    id val = prefs[@"enabled"];
    enabled = val ? [val boolValue] : YES;
    val = prefs[@"confirm"];
    SAC.autoPerform = [val boolValue];
    val = prefs[@"autoDismiss"];
    SAC.autoDismissWhenQueue = val ? [val boolValue] : YES;
    val = prefs[@"short"];
    SAC.shortLabel = val ? [val boolValue] : YES;
}

static void prefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    prefs();
}

#define cyDelegate ((Cydia *)[UIApplication sharedApplication])

CYPackageController *cy;
ProgressController *pc;

typedef NS_ENUM(NSInteger, SFMActionType) {
    SFMActionInstall,
    SFMActionRemove,
    SFMActionQueueInstallOrRemove,
    SFMActionQueueReinstall,
    SFMActionClear,
    SFMActionDowngrade,
};

static char SFMActionSheetPackageKey;
static char SFMActionSheetActionsKey;
static char SFMActionRailViewKey;
static char SFMButtonPackageKey;
static char SFMButtonActionKey;
static char SFMPanGestureKey;
static char SFMTapGestureKey;
static char SFMActiveIndexPathKey;
static char SFMPanIndexPathKey;
static char SFMPanStartProgressKey;
static char SFMSelectionSuppressUntilKey;
static char SFMCellSlidKey;

static const NSTimeInterval SFMActionRailAnimationDuration = 0.28;
static const NSTimeInterval SFMActionRailBounceOutDuration = 0.105;
static const NSTimeInterval SFMActionRailBounceSettleDuration = 0.34;
static const CGFloat SFMActionRailOpenThreshold = 0.42f;
static const CGFloat SFMActionRailBounceProgress = 0.045f;
static const CGFloat SFMActionRailMaxBounceProgress = 0.088f;
static const CGFloat SFMActionRailBounceVelocity = 520.0f;
static const CGFloat SFMActionRailMaxBounceVelocity = 1600.0f;
static const NSTimeInterval SFMSelectionSuppressDuration = 0.65;

static void SFMSetCellContentSlideForIndexPath(UITableView *tableView, NSIndexPath *indexPath, CGFloat distance, CGFloat progress, BOOL animated, NSTimeInterval duration);
static void SFMResetVisibleCellSlides(UITableView *tableView, NSIndexPath *exceptIndexPath, BOOL animated);
static void SFMRemoveActionRailAnimated(UITableView *tableView, BOOL animated);

static NSString *SFMInstallTitleForPackage(Package *package) {
    BOOL installed = ![package uninstalled];
    BOOL upgradable = [package upgradableAndEssential:NO];
    bool commercial = [package isCommercial];
    NSString *installTitle = installed ? (upgradable ? [SAC upgradeString] : [SAC reinstallString]) : (commercial ? [SAC buyString] : [SAC installString]);
    return [SAC normalizedString:installTitle];
}

static void SFMPerformPackageAction(id controller, Package *package, SFMActionType actionType) {
    Cydia *delegate = (Cydia *)[UIApplication sharedApplication];
    BOOL installed = ![package uninstalled];
    bool commercial = [package isCommercial];

    switch (actionType) {
        case SFMActionInstall:
            [SAC setFromSwipeAction:YES];
            [SAC setDismissAfterProgress:[SAC autoPerform] && (!commercial || (commercial && installed))];
            if (commercial && !installed) {
                [controller didSelectPackage:package];
                [cy performSelector:@selector(customButtonClicked) withObject:nil afterDelay:1.3];
            } else {
                [delegate installPackage:package];
            }
            break;
        case SFMActionRemove:
            [SAC setFromSwipeAction:YES];
            [SAC setDismissAfterProgress:[SAC autoDismissWhenQueue]];
            [delegate removePackage:package];
            break;
        case SFMActionQueueInstallOrRemove:
            [SAC setDismissAfterProgress:NO];
            [SAC setDismissAsQueue:[SAC autoDismissWhenQueue]];
            [SAC setFromSwipeAction:YES];
            if (installed)
                [delegate removePackage:package];
            else
                [delegate installPackage:package];
            break;
        case SFMActionQueueReinstall:
            [SAC setDismissAfterProgress:NO];
            [SAC setDismissAsQueue:[SAC autoDismissWhenQueue]];
            [SAC setFromSwipeAction:YES];
            [delegate installPackage:package];
            break;
        case SFMActionClear:
            [SAC setDismissAfterProgress:NO];
            [SAC setDismissAsQueue:YES];
            [SAC setFromSwipeAction:YES];
            [delegate clearPackage:package];
            break;
        case SFMActionDowngrade:
            [SAC setDismissAfterProgress:NO];
            [SAC setDismissAsQueue:NO];
            [SAC setFromSwipeAction:YES];
            [controller didSelectPackage:package];
            [cy performSelector:@selector(_clickButtonWithName:) withObject:@"DOWNGRADE" afterDelay:0.6];
            break;
    }
}

static void SFMAddSheetAction(UIActionSheet *sheet, NSMutableArray *actions, NSString *title, SFMActionType actionType) {
    [sheet addButtonWithTitle:title];
    [actions addObject:@(actionType)];
}

static UIColor *SFMColor(CGFloat red, CGFloat green, CGFloat blue) {
    return [UIColor colorWithRed:(red / 255.0) green:(green / 255.0) blue:(blue / 255.0) alpha:1.0];
}

static NSString *SFMButtonTitle(NSString *title) {
    return [title stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
}

static NSDictionary *SFMActionItem(NSString *title, SFMActionType actionType, UIColor *color) {
    return @{
        @"title": SFMButtonTitle(title),
        @"action": @(actionType),
        @"color": color,
    };
}

static NSArray *SFMActionItemsForPackage(Package *package) {
    NSMutableArray *items = [NSMutableArray array];
    BOOL installed = ![package uninstalled];
    BOOL isQueue = [package mode] != nil;
    NSString *installTitle = SFMInstallTitleForPackage(package);

    if (installed)
        [items addObject:SFMActionItem([SAC removeString], SFMActionRemove, SFMColor(224, 67, 54))];
    if (!isQueue)
        [items addObject:SFMActionItem(installTitle, SFMActionInstall, SFMColor(0, 122, 255))];
    if (installed && !isQueue)
        [items addObject:SFMActionItem([SAC queueString:installTitle], SFMActionQueueReinstall, SFMColor(255, 149, 0))];
    if (isQueue)
        [items addObject:SFMActionItem([SAC clearString], SFMActionClear, SFMColor(142, 142, 147))];
    else
        [items addObject:SFMActionItem([SAC queueString:(installed ? [SAC removeString] : installTitle)], SFMActionQueueInstallOrRemove, installed ? SFMColor(255, 204, 0) : SFMColor(52, 199, 89))];
    if (!isQueue && [[package downgrades] count])
        [items addObject:SFMActionItem([SAC downgradeString], SFMActionDowngrade, SFMColor(175, 82, 222))];

    return items;
}

static void SFMRemoveActionRailAnimated(UITableView *tableView, BOOL animated) {
    UIView *rail = objc_getAssociatedObject(tableView, &SFMActionRailViewKey);
    NSIndexPath *activeIndexPath = objc_getAssociatedObject(tableView, &SFMActiveIndexPathKey);
    if (activeIndexPath)
        SFMSetCellContentSlideForIndexPath(tableView, activeIndexPath, 0.0f, 0.0f, animated, animated ? 0.18 : 0.0);
    SFMResetVisibleCellSlides(tableView, activeIndexPath, animated);
    if (!rail) {
        objc_setAssociatedObject(tableView, &SFMActiveIndexPathKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    objc_setAssociatedObject(tableView, &SFMActionRailViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(tableView, &SFMActiveIndexPathKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (!animated) {
        [rail removeFromSuperview];
        return;
    }

    CGRect frame = rail.frame;
    frame.origin.x = tableView.bounds.size.width;
    [UIView animateWithDuration:0.18 delay:0.0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState animations:^{
        rail.frame = frame;
        rail.alpha = 0.0f;
    } completion:^(BOOL finished) {
        [rail removeFromSuperview];
    }];
}

static UITableView *SFMTableViewForView(UIView *view) {
    UIView *candidate = view;
    while (candidate) {
        if ([candidate isKindOfClass:[UITableView class]])
            return (UITableView *)candidate;
        candidate = candidate.superview;
    }
    return nil;
}

static UITableView *SFMTableViewForController(id controller) {
    if ([controller respondsToSelector:@selector(tableView)])
        return [controller performSelector:@selector(tableView)];
    if ([controller respondsToSelector:@selector(view)]) {
        UIView *view = [controller performSelector:@selector(view)];
        if ([view isKindOfClass:[UITableView class]])
            return (UITableView *)view;
        return SFMTableViewForView(view);
    }
    return nil;
}

static CGFloat SFMClampedProgress(CGFloat progress) {
    return MIN(1.0f, MAX(0.0f, progress));
}

static CGFloat SFMBounceProgressForVelocity(CGFloat velocityX) {
    CGFloat velocityFactor = MIN(1.0f, fabsf(velocityX) / SFMActionRailMaxBounceVelocity);
    return SFMActionRailBounceProgress + ((SFMActionRailMaxBounceProgress - SFMActionRailBounceProgress) * velocityFactor);
}

static CGFloat SFMDisplayProgress(CGFloat progress) {
    return MIN(1.0f + SFMActionRailMaxBounceProgress, MAX(-SFMActionRailMaxBounceProgress, progress));
}

static void SFMSuppressTableSelection(UITableView *tableView) {
    if (!tableView)
        return;
    NSTimeInterval suppressUntil = [NSDate timeIntervalSinceReferenceDate] + SFMSelectionSuppressDuration;
    objc_setAssociatedObject(tableView, &SFMSelectionSuppressUntilKey, @(suppressUntil), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL SFMShouldSuppressTableSelection(UITableView *tableView) {
    NSNumber *suppressUntilNumber = objc_getAssociatedObject(tableView, &SFMSelectionSuppressUntilKey);
    if (!suppressUntilNumber)
        return NO;

    if ([NSDate timeIntervalSinceReferenceDate] <= [suppressUntilNumber doubleValue])
        return YES;

    objc_setAssociatedObject(tableView, &SFMSelectionSuppressUntilKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return NO;
}

static void SFMSetCellContentSlide(UITableViewCell *cell, CGFloat distance, CGFloat progress, BOOL animated, NSTimeInterval duration) {
    if (!cell)
        return;

    CGFloat displayProgress = SFMDisplayProgress(progress);
    CGAffineTransform transform = CGAffineTransformMakeTranslation(-distance * displayProgress, 0.0f);
    void (^applyTransform)(void) = ^{
        cell.contentView.transform = transform;
    };

    objc_setAssociatedObject(cell, &SFMCellSlidKey, displayProgress != 0.0f ? @(YES) : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (animated) {
        [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:applyTransform completion:nil];
    } else {
        applyTransform();
    }
}

static void SFMSetCellContentSlideForIndexPath(UITableView *tableView, NSIndexPath *indexPath, CGFloat distance, CGFloat progress, BOOL animated, NSTimeInterval duration) {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    SFMSetCellContentSlide(cell, distance, progress, animated, duration);
}

static void SFMResetVisibleCellSlides(UITableView *tableView, NSIndexPath *exceptIndexPath, BOOL animated) {
    for (UITableViewCell *cell in [tableView visibleCells]) {
        NSIndexPath *indexPath = [tableView indexPathForCell:cell];
        if (exceptIndexPath && indexPath && [indexPath isEqual:exceptIndexPath])
            continue;
        if (objc_getAssociatedObject(cell, &SFMCellSlidKey))
            SFMSetCellContentSlide(cell, 0.0f, 0.0f, animated, animated ? 0.18 : 0.0);
    }
}

static CGFloat SFMTotalRailWidthForItems(UITableView *tableView, NSArray *items) {
    CGFloat maxWidth = floorf(tableView.bounds.size.width * 0.72);
    CGFloat railWidth = MIN(maxWidth, MAX(78.0f, (CGFloat)items.count * 74.0f));
    return railWidth;
}

static CGRect SFMFrameForRailProgress(UITableView *tableView, NSIndexPath *indexPath, CGFloat totalWidth, CGFloat progress) {
    CGRect rowRect = [tableView rectForRowAtIndexPath:indexPath];
    CGFloat closedX = CGRectGetMaxX(rowRect);
    CGFloat openX = closedX - totalWidth;
    CGFloat displayProgress = SFMDisplayProgress(progress);
    return CGRectMake(closedX - ((closedX - openX) * displayProgress), rowRect.origin.y, totalWidth, rowRect.size.height);
}

static void SFMAnimateActionRailToProgress(UITableView *tableView, NSIndexPath *indexPath, CGFloat totalWidth, CGFloat progress, NSTimeInterval duration, BOOL spring, CGFloat springVelocity, BOOL fadeRail, void (^completion)(BOOL)) {
    UIView *rail = objc_getAssociatedObject(tableView, &SFMActionRailViewKey);
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    CGRect targetFrame = SFMFrameForRailProgress(tableView, indexPath, totalWidth, progress);
    CGFloat displayProgress = SFMDisplayProgress(progress);
    CGAffineTransform targetTransform = CGAffineTransformMakeTranslation(-totalWidth * displayProgress, 0.0f);
    void (^animations)(void) = ^{
        if (rail) {
            rail.frame = targetFrame;
            rail.alpha = fadeRail ? 0.0f : 1.0f;
        }
        if (cell)
            cell.contentView.transform = targetTransform;
    };
    void (^finished)(BOOL) = ^(BOOL finished) {
        if (cell)
            objc_setAssociatedObject(cell, &SFMCellSlidKey, displayProgress != 0.0f ? @(YES) : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (completion)
            completion(finished);
    };

    if (spring) {
        [UIView animateWithDuration:duration delay:0.0 usingSpringWithDamping:0.54f initialSpringVelocity:springVelocity options:UIViewAnimationOptionBeginFromCurrentState animations:animations completion:finished];
    } else {
        [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:animations completion:finished];
    }
}

static void SFMBounceActionRailToProgress(UITableView *tableView, NSIndexPath *indexPath, CGFloat totalWidth, CGFloat targetProgress, CGFloat velocityX) {
    CGFloat bounceProgress = SFMBounceProgressForVelocity(velocityX);
    CGFloat overshootProgress = targetProgress > 0.0f ? 1.0f + bounceProgress : -bounceProgress;
    CGFloat springVelocity = MIN(1.25f, 0.25f + (fabsf(velocityX) / SFMActionRailMaxBounceVelocity));
    SFMAnimateActionRailToProgress(tableView, indexPath, totalWidth, overshootProgress, SFMActionRailBounceOutDuration, NO, 0.0f, NO, ^(BOOL finished) {
        SFMAnimateActionRailToProgress(tableView, indexPath, totalWidth, targetProgress, SFMActionRailBounceSettleDuration, YES, springVelocity, NO, ^(BOOL finished2) {
            if (targetProgress <= 0.0f)
                SFMRemoveActionRailAnimated(tableView, NO);
        });
    });
}

static void SFMSetActionRailProgress(id controller, UITableView *tableView, NSIndexPath *indexPath, CGFloat progress, BOOL animated) {
    if (IS_IOS_OR_NEWER(iOS_8_0))
        return;

    NSIndexPath *activeIndexPath = objc_getAssociatedObject(tableView, &SFMActiveIndexPathKey);
    UIView *rail = objc_getAssociatedObject(tableView, &SFMActionRailViewKey);
    BOOL reusingRail = rail && activeIndexPath && [activeIndexPath isEqual:indexPath];
    if (rail && !reusingRail)
        SFMRemoveActionRailAnimated(tableView, YES);

    Package *package = [controller packageAtIndexPath:indexPath];
    NSArray *items = SFMActionItemsForPackage(package);
    if (!items.count)
        return;

    CGRect rowRect = [tableView rectForRowAtIndexPath:indexPath];
    CGFloat totalWidth = SFMTotalRailWidthForItems(tableView, items);
    CGFloat buttonWidth = floorf(totalWidth / (CGFloat)items.count);
    CGRect targetFrame = SFMFrameForRailProgress(tableView, indexPath, totalWidth, progress);
    SFMResetVisibleCellSlides(tableView, indexPath, animated);
    SFMSetCellContentSlideForIndexPath(tableView, indexPath, totalWidth, progress, animated, SFMActionRailAnimationDuration);

    if (!reusingRail) {
        rail = [[UIView alloc] initWithFrame:SFMFrameForRailProgress(tableView, indexPath, totalWidth, 0.0f)];
        rail.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        rail.clipsToBounds = YES;
        rail.alpha = 0.96f;

        for (NSUInteger i = 0; i < items.count; i++) {
            NSDictionary *item = items[i];
            CGFloat x = (CGFloat)i * buttonWidth;
            CGFloat width = (i == items.count - 1) ? (totalWidth - x) : buttonWidth;
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.frame = CGRectMake(x, 0.0f, width, rowRect.size.height);
            button.backgroundColor = item[@"color"];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:12.0f];
            button.titleLabel.numberOfLines = 2;
            button.titleLabel.textAlignment = NSTextAlignmentCenter;
            button.titleLabel.adjustsFontSizeToFitWidth = YES;
            button.titleLabel.minimumScaleFactor = 0.72f;
            button.contentEdgeInsets = UIEdgeInsetsMake(0, 4, 0, 4);
            [button setTitle:item[@"title"] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.7] forState:UIControlStateHighlighted];
            [button addTarget:controller action:@selector(sfm_actionRailButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
            objc_setAssociatedObject(button, &SFMButtonPackageKey, package, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(button, &SFMButtonActionKey, item[@"action"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [rail addSubview:button];

            if (i > 0) {
                UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(x, 0.0f, 1.0f / [UIScreen mainScreen].scale, rowRect.size.height)];
                separator.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.22];
                separator.userInteractionEnabled = NO;
                [rail addSubview:separator];
            }
        }

        objc_setAssociatedObject(tableView, &SFMActionRailViewKey, rail, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(tableView, &SFMActiveIndexPathKey, indexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [tableView addSubview:rail];
    }

    if (animated) {
        [UIView animateWithDuration:SFMActionRailAnimationDuration delay:0.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
            rail.frame = targetFrame;
            rail.alpha = 1.0f;
        } completion:nil];
    } else {
        rail.frame = targetFrame;
        rail.alpha = 1.0f;
    }
}

static void SFMShowActionRail(id controller, UITableView *tableView, NSIndexPath *indexPath) {
    SFMSetActionRailProgress(controller, tableView, indexPath, 1.0f, YES);
}

static void SFMEnsureCustomGestures(id controller, UITableView *tableView) {
    if (IS_IOS_OR_NEWER(iOS_8_0) || !tableView)
        return;

    if (!objc_getAssociatedObject(tableView, &SFMPanGestureKey)) {
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:controller action:@selector(sfm_customPanGesture:)];
        pan.cancelsTouchesInView = YES;
        pan.delegate = (id<UIGestureRecognizerDelegate>)controller;
        [tableView addGestureRecognizer:pan];
        objc_setAssociatedObject(tableView, &SFMPanGestureKey, pan, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (!objc_getAssociatedObject(tableView, &SFMTapGestureKey)) {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:controller action:@selector(sfm_customTapGesture:)];
        tap.cancelsTouchesInView = YES;
        tap.delegate = (id<UIGestureRecognizerDelegate>)controller;
        [tableView addGestureRecognizer:tap];
        objc_setAssociatedObject(tableView, &SFMTapGestureKey, tap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%hook CYPackageController

- (id)initWithDatabase:(Database *)database forPackage:(Package *)package withReferrer:(id)referrer {
    self = %orig;
    cy = self;
    return self;
}

%end

%hook Cydia

- (bool)perform {
    [SAC setSuppressCC:[SAC fromSwipeAction] && [SAC dismissAsQueue]];
    bool value = %orig;
    [SAC setSuppressCC:NO];
    [SAC setFromSwipeAction:NO];
    return value;
}

- (ProgressController *)invokeNewProgress:(NSInvocation *)invocation forController:(UINavigationController *)navigation withTitle:(NSString *)title {
    [SAC setFromProgressInvoke:YES];
    ProgressController *cont = %orig;
    [SAC setFromProgressInvoke:NO];
    return cont;
}

%end

%hook ConfirmationController

- (void)dismissModalViewControllerAnimated:(BOOL)animated {
    if ([SAC suppressCC])
        return;
    %orig;
}

%end

%hook CydiaTabBarController

- (void)presentViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void (^)(void))completion {
    if ([vc isKindOfClass:[UINavigationController class]]) {
        if ([((UINavigationController *)vc).topViewController class] == NSClassFromString(@"ConfirmationController")) {
            ConfirmationController *cc = (ConfirmationController *)(((UINavigationController *)vc).topViewController);
            Ivar issuesIvar = class_getInstanceVariable([cc class], "issues_");
            NSMutableArray *issues = issuesIvar ? object_getIvar(cc, issuesIvar) : nil;
            if (issues.count) {
                // Problem detected, won't auto-dismiss here
                %orig;
                return;
            }
            if ([SAC fromSwipeAction]) {
                // some actions needed after package confirmation page presentation triggered by swipe actions
                if ([SAC dismissAsQueue]) {
                    if (completion)
                        completion();
                    [cc performSelector:@selector(_doContinue) withObject:nil afterDelay:0.06];
                    [SAC setDismissAsQueue:NO];
                    return;
                }
                void (^block)(void) = ^(void) {
                    if (completion)
                        completion();
                    else if ([SAC dismissAfterProgress]) {
                        [cc performSelector:@selector(confirmButtonClicked) withObject:nil afterDelay:0.2];
                    }
                    [SAC setFromSwipeAction:NO];
                };
                %orig(vc, animated, block);
                return;
            }
        }
    }
    %orig;
}

%end

%hook CydiaProgressData

- (void)setRunning:(bool)running {
    %orig;
    if (!running && [SAC dismissAfterProgress] && [SAC fromProgressInvoke]) {
        [SAC setDismissAfterProgress:NO];
        uint64_t status = -1;
        int notify_token;
        if (notify_register_check("com.saurik.Cydia.status", &notify_token) == NOTIFY_STATUS_OK) {
            notify_get_state(notify_token, &status);
            notify_cancel(notify_token);
        }
        if (status == 0) {
            UpdateExternalStatus(0);
            [cyDelegate returnToCydia];
            [[[pc navigationController] parentOrPresentingViewController] dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

%end

%hook ProgressController

- (id)initWithDatabase:(id)arg1 delegate:(id)arg2 {
    self = %orig;
    pc = self;
    return self;
}

%end

%hook UITableViewCell

- (void)prepareForReuse {
    %orig;
    if (objc_getAssociatedObject(self, &SFMCellSlidKey)) {
        self.contentView.transform = CGAffineTransformIdentity;
        objc_setAssociatedObject(self, &SFMCellSlidKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%end

%hook FilteredPackageListController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!IS_IOS_OR_NEWER(iOS_8_0))
        SFMEnsureCustomGestures(self, SFMTableViewForController(self));
}

%new(c@:@@)
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!IS_IOS_OR_NEWER(iOS_8_0)) {
        SFMEnsureCustomGestures(self, tableView);
        return NO;
    }
    return YES;
}

%new(@@:@@)
- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath_ {
    Package *package = [self packageAtIndexPath:indexPath_];
    NSMutableArray *actions = [NSMutableArray array];
    BOOL installed = ![package uninstalled];
    BOOL isQueue = [package mode] != nil;
    if (installed) {
        // uninstall action
        UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:[SAC removeString] handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
            SFMPerformPackageAction(self, package, SFMActionRemove);
        }];
        [actions addObject:deleteAction];
    }
    NSString *installTitle = SFMInstallTitleForPackage(package); // In some languages, localized "reinstall" string is too long
    if ((!installed || IS_IPAD || [SAC shortLabel]) && !isQueue) {
        // Install or reinstall or upgrade action
        UITableViewRowAction *installAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:installTitle handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
            SFMPerformPackageAction(self, package, SFMActionInstall);
        }];
        installAction.backgroundColor = [UIColor systemBlueColor];
        [actions addObject:installAction];
    }
    if (installed && !isQueue) {
        // Queue reinstall action
        NSString *queueReinstallTitle = [SAC queueString:installTitle];
        UITableViewRowAction *queueReinstallAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:queueReinstallTitle handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
            SFMPerformPackageAction(self, package, SFMActionQueueReinstall);
        }];
        queueReinstallAction.backgroundColor = [UIColor orangeColor];
        [actions addObject:queueReinstallAction];
    }
    if (isQueue) {
        // Clear action
        UITableViewRowAction *clearAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:[SAC clearString] handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
            SFMPerformPackageAction(self, package, SFMActionClear);
        }];
        clearAction.backgroundColor = [UIColor grayColor];
        [actions addObject:clearAction];
    } else {
        // Queue install/remove action
        NSString *queueTitle = [SAC queueString:(installed ? [SAC removeString] : installTitle)];
        UITableViewRowAction *queueAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:queueTitle handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
            SFMPerformPackageAction(self, package, SFMActionQueueInstallOrRemove);
        }];
        queueAction.backgroundColor = installed ? [UIColor systemYellowColor] : [UIColor systemGreenColor];
        [actions addObject:queueAction];
    }
    if (!isQueue) {
        NSArray *downgrades = [package downgrades];
        if (downgrades.count) {
            UITableViewRowAction *downgradeAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:[SAC downgradeString] handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
                SFMPerformPackageAction(self, package, SFMActionDowngrade);
            }];
            downgradeAction.backgroundColor = [UIColor purpleColor];
            [actions addObject:downgradeAction];
        }
    }
    return actions;
}

#ifdef __LP64__
%new(v@:@l@)
#else
%new(v@:@i@)
#endif
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && !IS_IOS_OR_NEWER(iOS_8_0)) {
        SFMShowActionRail(self, tableView, indexPath);
        return;
    }
    [tableView setEditing:NO animated:YES];
}

%new(c@:@)
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    UITableView *tableView = [gestureRecognizer.view isKindOfClass:[UITableView class]] ? (UITableView *)gestureRecognizer.view : SFMTableViewForView(gestureRecognizer.view);
    if (!tableView)
        return YES;

    if (gestureRecognizer == objc_getAssociatedObject(tableView, &SFMPanGestureKey)) {
        CGPoint velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:tableView];
        if (fabsf(velocity.x) <= fabsf(velocity.y) * 1.15f)
            return NO;
        if (velocity.x > 0.0f && !objc_getAssociatedObject(tableView, &SFMActionRailViewKey))
            return NO;
        SFMSuppressTableSelection(tableView);
        return YES;
    }

    if (gestureRecognizer == objc_getAssociatedObject(tableView, &SFMTapGestureKey)) {
        NSIndexPath *activeIndexPath = objc_getAssociatedObject(tableView, &SFMActiveIndexPathKey);
        if (!activeIndexPath)
            return NO;
        CGPoint location = [(UITapGestureRecognizer *)gestureRecognizer locationInView:tableView];
        NSIndexPath *tappedIndexPath = [tableView indexPathForRowAtPoint:location];
        BOOL shouldBegin = ![activeIndexPath isEqual:tappedIndexPath];
        if (shouldBegin)
            SFMSuppressTableSelection(tableView);
        return shouldBegin;
    }

    return YES;
}

%new(v@:@)
- (void)sfm_customPanGesture:(UIPanGestureRecognizer *)gesture {
    UITableView *tableView = [gesture.view isKindOfClass:[UITableView class]] ? (UITableView *)gesture.view : SFMTableViewForView(gesture.view);
    if (!tableView)
        return;

    if (gesture.state == UIGestureRecognizerStateBegan) {
        SFMSuppressTableSelection(tableView);
        CGPoint location = [gesture locationInView:tableView];
        NSIndexPath *indexPath = [tableView indexPathForRowAtPoint:location];
        NSIndexPath *activeIndexPath = objc_getAssociatedObject(tableView, &SFMActiveIndexPathKey);
        UIView *rail = objc_getAssociatedObject(tableView, &SFMActionRailViewKey);

        if (!indexPath && activeIndexPath)
            indexPath = activeIndexPath;
        if (!indexPath)
            return;

        CGFloat startProgress = (rail && activeIndexPath && [activeIndexPath isEqual:indexPath]) ? 1.0f : 0.0f;
        if (rail && (!activeIndexPath || ![activeIndexPath isEqual:indexPath]))
            SFMRemoveActionRailAnimated(tableView, YES);

        objc_setAssociatedObject(tableView, &SFMPanIndexPathKey, indexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(tableView, &SFMPanStartProgressKey, @(startProgress), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SFMSetActionRailProgress(self, tableView, indexPath, startProgress, NO);
        return;
    }

    NSIndexPath *indexPath = objc_getAssociatedObject(tableView, &SFMPanIndexPathKey);
    if (!indexPath)
        return;

    Package *package = [self packageAtIndexPath:indexPath];
    NSArray *items = SFMActionItemsForPackage(package);
    if (!items.count)
        return;

    CGFloat totalWidth = SFMTotalRailWidthForItems(tableView, items);
    CGFloat startProgress = [objc_getAssociatedObject(tableView, &SFMPanStartProgressKey) floatValue];
    CGFloat translationX = [gesture translationInView:tableView].x;
    CGFloat rawProgress = startProgress - (translationX / totalWidth);
    CGFloat progress = SFMClampedProgress(rawProgress);

    if (gesture.state == UIGestureRecognizerStateChanged) {
        SFMSuppressTableSelection(tableView);
        SFMSetActionRailProgress(self, tableView, indexPath, progress, NO);
        return;
    }

    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        SFMSuppressTableSelection(tableView);
        CGFloat velocityX = [gesture velocityInView:tableView].x;
        BOOL shouldOpen = progress > SFMActionRailOpenThreshold;
        if (velocityX < -320.0f)
            shouldOpen = YES;
        else if (velocityX > 320.0f)
            shouldOpen = NO;
        BOOL shouldBounce = fabsf(velocityX) > SFMActionRailBounceVelocity || rawProgress > 1.0f + SFMActionRailBounceProgress || rawProgress < -SFMActionRailBounceProgress;

        objc_setAssociatedObject(tableView, &SFMPanIndexPathKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(tableView, &SFMPanStartProgressKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        if (shouldOpen) {
            if (shouldBounce)
                SFMBounceActionRailToProgress(tableView, indexPath, totalWidth, 1.0f, velocityX);
            else
                SFMSetActionRailProgress(self, tableView, indexPath, 1.0f, YES);
        } else {
            if (shouldBounce)
                SFMBounceActionRailToProgress(tableView, indexPath, totalWidth, 0.0f, velocityX);
            else
                SFMRemoveActionRailAnimated(tableView, YES);
        }
    }
}

%new(v@:@)
- (void)sfm_customTapGesture:(UITapGestureRecognizer *)gesture {
    UITableView *tableView = [gesture.view isKindOfClass:[UITableView class]] ? (UITableView *)gesture.view : SFMTableViewForView(gesture.view);
    if (tableView) {
        SFMSuppressTableSelection(tableView);
        SFMRemoveActionRailAnimated(tableView, YES);
    }
}

%new(v@:@)
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (!IS_IOS_OR_NEWER(iOS_8_0) && [scrollView isKindOfClass:[UITableView class]])
        SFMRemoveActionRailAnimated((UITableView *)scrollView, YES);
}

%new(@@:@@)
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!IS_IOS_OR_NEWER(iOS_8_0) && SFMShouldSuppressTableSelection(tableView)) {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
        return nil;
    }
    return indexPath;
}

%new(v@:@@)
- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!IS_IOS_OR_NEWER(iOS_8_0))
        SFMShowActionRail(self, tableView, indexPath);
}

%new(v@:@@)
- (void)tableView:(UITableView *)tableView didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!IS_IOS_OR_NEWER(iOS_8_0))
        SFMRemoveActionRailAnimated(tableView, YES);
}

%new(v@:@)
- (void)sfm_actionRailButtonTapped:(UIButton *)button {
    UITableView *tableView = SFMTableViewForView(button);
    Package *package = objc_getAssociatedObject(button, &SFMButtonPackageKey);
    NSNumber *actionNumber = objc_getAssociatedObject(button, &SFMButtonActionKey);
    if (!package || !actionNumber)
        return;
    SFMRemoveActionRailAnimated(tableView, NO);
    [tableView setEditing:NO animated:YES];
    SFMPerformPackageAction(self, package, (SFMActionType)[actionNumber integerValue]);
}

%new(v@:@@)
- (void)sfm_presentActionSheetForTableView:(UITableView *)tableView indexPath:(NSIndexPath *)indexPath {
        Package *package = [self packageAtIndexPath:indexPath];
        BOOL installed = ![package uninstalled];
        BOOL isQueue = [package mode] != nil;
        NSString *installTitle = SFMInstallTitleForPackage(package);
        NSMutableArray *actions = [NSMutableArray array];
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[package name] delegate:(id<UIActionSheetDelegate>)self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];

        if (installed)
            SFMAddSheetAction(sheet, actions, [SAC removeString], SFMActionRemove);
        if (!isQueue)
            SFMAddSheetAction(sheet, actions, installTitle, SFMActionInstall);
        if (installed && !isQueue)
            SFMAddSheetAction(sheet, actions, [SAC queueString:installTitle], SFMActionQueueReinstall);
        if (isQueue)
            SFMAddSheetAction(sheet, actions, [SAC clearString], SFMActionClear);
        else
            SFMAddSheetAction(sheet, actions, [SAC queueString:(installed ? [SAC removeString] : installTitle)], SFMActionQueueInstallOrRemove);
        if (!isQueue && [[package downgrades] count])
            SFMAddSheetAction(sheet, actions, [SAC downgradeString], SFMActionDowngrade);

        [sheet addButtonWithTitle:UCLocalize("CANCEL") ?: @"Cancel"];
        sheet.cancelButtonIndex = sheet.numberOfButtons - 1;
        objc_setAssociatedObject(sheet, &SFMActionSheetPackageKey, package, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(sheet, &SFMActionSheetActionsKey, actions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [tableView setEditing:NO animated:YES];
        [sheet showInView:tableView];
    }

%new(@@:@@)
- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return !IS_IOS_OR_NEWER(iOS_8_0) ? @" " : nil;
}

#ifdef __LP64__
%new(v@:@q)
#else
%new(v@:@i)
#endif
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex)
        return;
    NSArray *actions = objc_getAssociatedObject(actionSheet, &SFMActionSheetActionsKey);
    if (buttonIndex < 0 || buttonIndex >= (NSInteger)actions.count)
        return;
    Package *package = objc_getAssociatedObject(actionSheet, &SFMActionSheetPackageKey);
    SFMPerformPackageAction(self, package, (SFMActionType)[actions[buttonIndex] integerValue]);
}

%end

%ctor {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &prefsChanged, PreferencesNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
    prefs();
    if (enabled) {
        %init;
    }
}
