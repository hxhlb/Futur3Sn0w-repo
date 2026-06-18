#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

static CGFloat const kSLTAlertCornerRadius = 30.0;
static CGFloat const kSLTAlertBorderWidth = 0.75;
static CGFloat const kSLTAlertContentHorizontalInset = 14.0;
static CGFloat const kSLTAlertHeaderTopInset = 10.0;
static CGFloat const kSLTAlertSequenceBottomInset = 10.0;
static CGFloat const kSLTActionHorizontalInset = 16.0;
static CGFloat const kSLTActionCompactHorizontalInset = 8.0;
static CGFloat const kSLTActionTopInset = 1.0;
static CGFloat const kSLTActionBottomInset = 6.0;

typedef NS_ENUM(NSInteger, SLTAlertActionStyle) {
    SLTAlertActionStyleDefault = 0,
    SLTAlertActionStyleCancel = 1,
    SLTAlertActionStyleDestructive = 2
};

static BOOL SLTStringMatchesConfirmatoryTitle(NSString *title) {
    if (title.length == 0) {
        return NO;
    }

    static NSSet<NSString *> *confirmatoryTitles;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        confirmatoryTitles = [NSSet setWithArray:@[
            @"ok",
            @"allow",
            @"continue",
            @"confirm",
            @"done",
            @"save",
            @"yes",
            @"open",
            @"join",
            @"send",
            @"retry"
        ]];
    });

    return [confirmatoryTitles containsObject:title.lowercaseString];
}

static BOOL SLTStringMatchesDestructiveTitle(NSString *title) {
    if (title.length == 0) {
        return NO;
    }

    static NSSet<NSString *> *destructiveTitles;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        destructiveTitles = [NSSet setWithArray:@[
            @"delete",
            @"remove",
            @"erase",
            @"discard",
            @"clear",
            @"reset"
        ]];
    });

    return [destructiveTitles containsObject:title.lowercaseString];
}

static UILabel *SLTFindFirstLabelInView(UIView *view) {
    if (!view) {
        return nil;
    }

    if ([view isKindOfClass:[UILabel class]]) {
        return (UILabel *)view;
    }

    for (UIView *subview in view.subviews) {
        UILabel *label = SLTFindFirstLabelInView(subview);
        if (label) {
            return label;
        }
    }

    return nil;
}

static BOOL SLTViewContainsLabel(UIView *view) {
    return SLTFindFirstLabelInView(view) != nil;
}

static BOOL SLTHasAncestorOfClass(UIView *view, Class ancestorClass) {
    UIView *currentView = view.superview;
    while (currentView) {
        if ([currentView isKindOfClass:ancestorClass]) {
            return YES;
        }
        currentView = currentView.superview;
    }

    return NO;
}

static UIView *SLTNearestAncestorOfClass(UIView *view, Class ancestorClass) {
    UIView *currentView = view;
    while (currentView) {
        if ([currentView isKindOfClass:ancestorClass]) {
            return currentView;
        }
        currentView = currentView.superview;
    }

    return nil;
}

static id SLTSafeValueForKey(id object, NSString *key) {
    if (!object || key.length == 0) {
        return nil;
    }

    @try {
        return [object valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSInteger SLTActionStyleForView(UIView *actionView) {
    id action = SLTSafeValueForKey(actionView, @"action");
    if (!action) {
        action = SLTSafeValueForKey(actionView, @"_action");
    }

    id styleValue = SLTSafeValueForKey(action, @"style");
    if (!styleValue) {
        styleValue = SLTSafeValueForKey(action, @"_style");
    }
    if (!styleValue) {
        styleValue = SLTSafeValueForKey(actionView, @"style");
    }

    return [styleValue respondsToSelector:@selector(integerValue)] ? [styleValue integerValue] : NSNotFound;
}

static NSString *SLTActionTitleForView(UIView *actionView) {
    id action = SLTSafeValueForKey(actionView, @"action");
    if (!action) {
        action = SLTSafeValueForKey(actionView, @"_action");
    }

    id titleValue = SLTSafeValueForKey(action, @"title");
    if (!titleValue) {
        titleValue = SLTSafeValueForKey(action, @"_title");
    }

    return [titleValue isKindOfClass:[NSString class]] ? titleValue : nil;
}

static BOOL SLTActionIsPreferred(UIView *actionView) {
    NSArray<NSString *> *keys = @[
        @"preferred",
        @"isPreferred",
        @"representsPreferredAction",
        @"_representsPreferredAction",
        @"preferredAction"
    ];

    for (NSString *key in keys) {
        id value = SLTSafeValueForKey(actionView, key);
        if ([value respondsToSelector:@selector(boolValue)] && [value boolValue]) {
            return YES;
        }
    }

    id action = SLTSafeValueForKey(actionView, @"action");
    if (!action) {
        action = SLTSafeValueForKey(actionView, @"_action");
    }

    for (NSString *key in keys) {
        id value = SLTSafeValueForKey(action, key);
        if ([value respondsToSelector:@selector(boolValue)] && [value boolValue]) {
            return YES;
        }
    }

    NSString *title = SLTActionTitleForView(actionView);
    return SLTStringMatchesConfirmatoryTitle(title);
}

static BOOL SLTActionIsDestructive(UIView *actionView) {
    NSInteger actionStyle = SLTActionStyleForView(actionView);
    if (actionStyle == SLTAlertActionStyleDestructive) {
        return YES;
    }

    NSString *title = SLTActionTitleForView(actionView);
    return SLTStringMatchesDestructiveTitle(title);
}

static void SLTStyleAlertTextLabels(UIView *view) {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if (!SLTHasAncestorOfClass(label, %c(_UIAlertControllerActionView))) {
                label.numberOfLines = 0;
                label.textColor = UIColor.labelColor;
                label.textAlignment = NSTextAlignmentLeft;
            }
        }

        SLTStyleAlertTextLabels(subview);
    }
}

static void SLTForceLabelTextColor(UILabel *label, UIColor *textColor) {
    if (!label || !textColor) {
        return;
    }

    label.textColor = textColor;
    label.tintColor = textColor;
    label.highlightedTextColor = textColor;

    if (label.attributedText.length > 0) {
        NSMutableAttributedString *mutableText = [[NSMutableAttributedString alloc] initWithAttributedString:label.attributedText];
        NSRange fullRange = NSMakeRange(0, mutableText.length);
        [mutableText addAttribute:NSForegroundColorAttributeName value:textColor range:fullRange];

        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentCenter;
        [mutableText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:fullRange];

        label.attributedText = mutableText;
    }
}

static void SLTLayoutActionLabelHost(UILabel *label, UIView *contentView) {
    if (!label || !contentView) {
        return;
    }

    UIView *labelHost = label.superview;
    if (!labelHost || labelHost == contentView) {
        CGSize fittingSize = [label sizeThatFits:contentView.bounds.size];
        CGFloat labelHeight = MIN(CGRectGetHeight(contentView.bounds), MAX(ceil(fittingSize.height), ceil(CGRectGetHeight(label.bounds))));
        CGFloat labelY = floor((CGRectGetHeight(contentView.bounds) - labelHeight) / 2.0);
        label.frame = CGRectIntegral(CGRectMake(0.0, labelY, CGRectGetWidth(contentView.bounds), labelHeight));
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        label.textAlignment = NSTextAlignmentCenter;
        return;
    }

    BOOL hostOnlyContainsLabel = YES;
    for (UIView *subview in labelHost.subviews) {
        if (subview != label && !subview.hidden && subview.alpha > 0.01) {
            hostOnlyContainsLabel = NO;
            break;
        }
    }

    if (hostOnlyContainsLabel) {
        labelHost.frame = contentView.bounds;
        labelHost.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    } else {
        CGSize fittingSize = [label sizeThatFits:contentView.bounds.size];
        CGFloat hostWidth = MIN(CGRectGetWidth(contentView.bounds), MAX(CGRectGetWidth(labelHost.bounds), ceil(fittingSize.width) + 24.0));
        CGFloat hostHeight = CGRectGetHeight(contentView.bounds);
        labelHost.frame = CGRectIntegral(CGRectMake((CGRectGetWidth(contentView.bounds) - hostWidth) / 2.0, 0.0, hostWidth, hostHeight));
    }

    CGSize fittingSize = [label sizeThatFits:labelHost.bounds.size];
    CGFloat labelHeight = MIN(CGRectGetHeight(labelHost.bounds), MAX(ceil(fittingSize.height), ceil(CGRectGetHeight(label.bounds))));
    CGFloat labelY = floor((CGRectGetHeight(labelHost.bounds) - labelHeight) / 2.0);
    label.frame = CGRectIntegral(CGRectMake(0.0, labelY, CGRectGetWidth(labelHost.bounds), labelHeight));
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    label.textAlignment = NSTextAlignmentCenter;
}

static void SLTApplyRoundedMask(UIView *view, CGRect roundedRect) {
    if (!view) {
        return;
    }

    CAShapeLayer *maskLayer = nil;
    if ([view.layer.mask isKindOfClass:[CAShapeLayer class]]) {
        maskLayer = (CAShapeLayer *)view.layer.mask;
    } else {
        maskLayer = [CAShapeLayer layer];
        view.layer.mask = maskLayer;
    }

    CGFloat cornerRadius = CGRectGetHeight(roundedRect) / 2.0;
    maskLayer.frame = view.bounds;
    maskLayer.path = [UIBezierPath bezierPathWithRoundedRect:roundedRect cornerRadius:cornerRadius].CGPath;
}

static void SLTStyleLabelHierarchy(UIView *view) {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.numberOfLines = 0;
            label.textColor = UIColor.labelColor;
        }

        SLTStyleLabelHierarchy(subview);
    }
}

static UIView *SLTFindDescendantViewMatchingClassName(UIView *hostView, NSString *classNameFragment) {
    if (!hostView || classNameFragment.length == 0) {
        return nil;
    }

    for (UIView *subview in hostView.subviews) {
        NSString *subviewClassName = NSStringFromClass(subview.class);
        if ([subviewClassName containsString:classNameFragment]) {
            return subview;
        }

        UIView *nestedMatch = SLTFindDescendantViewMatchingClassName(subview, classNameFragment);
        if (nestedMatch) {
            return nestedMatch;
        }
    }

    return nil;
}

static UIView *SLTFindActionContentView(UIView *hostView) {
    for (UIView *subview in hostView.subviews) {
        if (subview.hidden || subview.alpha < 0.01) {
            continue;
        }

        NSString *className = NSStringFromClass(subview.class);
        if ([className containsString:@"HighlightedBackground"]) {
            continue;
        }

        if (SLTViewContainsLabel(subview)) {
            return subview;
        }
    }

    UIView *visualEffectContentView = SLTFindDescendantViewMatchingClassName(hostView, @"_UIVisualEffectContentView");
    if (visualEffectContentView) {
        return visualEffectContentView;
    }

    return hostView.subviews.firstObject ?: hostView;
}

static UIColor *SLTCardBackgroundColor(void) {
    if (@available(iOS 13.0, *)) {
        return UIColor.secondarySystemBackgroundColor;
    }

    return UIColor.whiteColor;
}

static UIColor *SLTNeutralActionColor(void) {
    if (@available(iOS 13.0, *)) {
        return UIColor.tertiarySystemFillColor;
    }

    return [UIColor colorWithWhite:0.0 alpha:0.08];
}

static UIColor *SLTHighlightColor(BOOL isPreferred, BOOL isDestructive) {
    if (isPreferred) {
        return [UIColor.blackColor colorWithAlphaComponent:0.14];
    }

    if (isDestructive) {
        return [UIColor.systemRedColor colorWithAlphaComponent:0.12];
    }

    return [UIColor.labelColor colorWithAlphaComponent:0.12];
}

static UIView *SLTFindAlertContentRoot(UIView *alertView) {
    for (UIView *subview in alertView.subviews) {
        if (subview.hidden || subview.alpha < 0.01) {
            continue;
        }

        return subview;
    }

    return alertView.subviews.firstObject;
}

static void SLTInsetAlertContentSections(UIView *alertView) {
    UIView *contentRoot = SLTFindAlertContentRoot(alertView);
    if (!contentRoot) {
        return;
    }

    contentRoot.frame = alertView.bounds;
    contentRoot.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    for (UIView *subview in contentRoot.subviews) {
        if (subview.hidden || subview.alpha < 0.01) {
            continue;
        }

        NSString *className = NSStringFromClass(subview.class);
        CGRect frame = subview.frame;

        if ([className containsString:@"HeaderScrollView"]) {
            frame.origin.x = kSLTAlertContentHorizontalInset;
            frame.origin.y = kSLTAlertHeaderTopInset;
            frame.size.width = MAX(0.0, CGRectGetWidth(contentRoot.bounds) - (kSLTAlertContentHorizontalInset * 2.0));
            frame.size.height = MAX(0.0, CGRectGetHeight(frame) - kSLTAlertHeaderTopInset);
            subview.frame = CGRectIntegral(frame);
            subview.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            continue;
        }

        if ([className containsString:@"RepresentationsSequenceView"] ||
            [className containsString:@"SeparableSequenceView"] ||
            [className containsString:@"UIStackView"]) {
            frame.size.height = MAX(0.0, CGRectGetHeight(frame) - kSLTAlertSequenceBottomInset);
            subview.frame = CGRectIntegral(frame);
            subview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        }
    }
}

static CGFloat SLTActionHorizontalInsetForBounds(CGRect bounds) {
    return CGRectGetWidth(bounds) <= 150.0 ? kSLTActionCompactHorizontalInset : kSLTActionHorizontalInset;
}

static UIEdgeInsets SLTActionContentInsetsForView(UIView *actionView) {
    CGRect bounds = actionView.bounds;
    CGFloat horizontalInset = SLTActionHorizontalInsetForBounds(bounds);
    return UIEdgeInsetsMake(kSLTActionTopInset, horizontalInset, kSLTActionBottomInset, horizontalInset);
}

static CGRect SLTActionContentFrameForView(UIView *actionView) {
    return CGRectIntegral(UIEdgeInsetsInsetRect(actionView.bounds, SLTActionContentInsetsForView(actionView)));
}

static UIColor *SLTResolvedActionTextColor(BOOL isPreferred, BOOL isDestructive) {
    return isPreferred ? UIColor.whiteColor : (isDestructive ? UIColor.systemRedColor : UIColor.labelColor);
}

static UIColor *SLTResolvedActionTextColorForActionView(UIView *actionView) {
    NSInteger actionStyle = SLTActionStyleForView(actionView);
    BOOL isDestructive = SLTActionIsDestructive(actionView);
    BOOL isPreferred = !isDestructive && actionStyle != SLTAlertActionStyleCancel && SLTActionIsPreferred(actionView);
    return SLTResolvedActionTextColor(isPreferred, isDestructive);
}

static void SLTStyleAllActionLabelsInView(UIView *view, UIView *contentView, UIColor *textColor) {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.adjustsFontSizeToFitWidth = NO;
            label.minimumScaleFactor = 1.0;
            label.numberOfLines = 0;
            SLTLayoutActionLabelHost(label, contentView);
            SLTForceLabelTextColor(label, textColor);
        }

        SLTStyleAllActionLabelsInView(subview, contentView, textColor);
    }
}

%hook _UIAlertControllerView

- (void)layoutSubviews {
    %orig;

    UIView *alertView = (UIView *)self;
    alertView.layer.cornerRadius = kSLTAlertCornerRadius;
    alertView.layer.cornerCurve = kCACornerCurveContinuous;
    alertView.layer.masksToBounds = YES;
    alertView.layer.borderWidth = kSLTAlertBorderWidth;
    alertView.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.18].CGColor;
    alertView.backgroundColor = SLTCardBackgroundColor();

    SLTInsetAlertContentSections(alertView);
    SLTStyleLabelHierarchy(alertView);
    SLTStyleAlertTextLabels(alertView);
}

%end

%hook _UIAlertControllerActionView

- (void)layoutSubviews {
    %orig;

    UIView *actionView = (UIView *)self;
    UIView *contentView = SLTFindActionContentView(actionView);
    NSInteger actionStyle = SLTActionStyleForView(actionView);
    BOOL isDestructive = SLTActionIsDestructive(actionView);
    BOOL isPreferred = !isDestructive && actionStyle != SLTAlertActionStyleCancel && SLTActionIsPreferred(actionView);
    CGRect contentFrame = SLTActionContentFrameForView(actionView);
    CGFloat cornerRadius = CGRectGetHeight(contentFrame) / 2.0;
    UIColor *labelColor = SLTResolvedActionTextColor(isPreferred, isDestructive);

    actionView.backgroundColor = UIColor.clearColor;
    actionView.clipsToBounds = NO;

    if (contentView != actionView) {
        contentView.frame = contentFrame;
        contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }

    SLTApplyRoundedMask(contentView, contentView.bounds);
    contentView.layer.cornerRadius = cornerRadius;
    contentView.layer.cornerCurve = kCACornerCurveContinuous;
    contentView.layer.masksToBounds = YES;
    contentView.layer.borderWidth = 0.0;
    contentView.layer.borderColor = UIColor.clearColor.CGColor;
    contentView.backgroundColor = isPreferred ? UIColor.systemBlueColor : SLTNeutralActionColor();
    contentView.tintColor = labelColor;

    SLTStyleAllActionLabelsInView(actionView, contentView, labelColor);
    [contentView setNeedsLayout];
    [contentView layoutIfNeeded];
    SLTStyleAllActionLabelsInView(actionView, contentView, labelColor);
}

%end

%hook UILabel

- (void)layoutSubviews {
    %orig;

    UILabel *label = (UILabel *)self;
    UIView *actionView = SLTNearestAncestorOfClass(label, %c(_UIAlertControllerActionView));
    if (!actionView) {
        return;
    }

    UIView *contentView = SLTFindActionContentView(actionView);
    UIView *labelHost = label.superview;
    if (!contentView || !labelHost) {
        return;
    }

    UIColor *labelColor = SLTResolvedActionTextColorForActionView(actionView);
    SLTLayoutActionLabelHost(label, contentView);
    SLTForceLabelTextColor(label, labelColor);
}

- (void)setHighlighted:(BOOL)highlighted {
    %orig;

    UILabel *label = (UILabel *)self;
    UIView *actionView = SLTNearestAncestorOfClass(label, %c(_UIAlertControllerActionView));
    if (!actionView) {
        return;
    }

    UIColor *labelColor = SLTResolvedActionTextColorForActionView(actionView);
    SLTForceLabelTextColor(label, labelColor);
}

- (void)setTextColor:(UIColor *)textColor {
    UIView *actionView = SLTNearestAncestorOfClass((UIView *)self, %c(_UIAlertControllerActionView));
    if (!actionView) {
        %orig(textColor);
        return;
    }

    UIColor *resolvedColor = SLTResolvedActionTextColorForActionView(actionView);
    %orig(resolvedColor);
}

%end

%hook _UIAlertControlleriOSHighlightedBackgroundView

- (void)layoutSubviews {
    %orig;

    UIView *highlightView = (UIView *)self;
    UIView *actionView = highlightView.superview;
    if (!actionView) {
        return;
    }

    NSInteger actionStyle = SLTActionStyleForView(actionView);
    BOOL isDestructive = SLTActionIsDestructive(actionView);
    BOOL isPreferred = !isDestructive && actionStyle != SLTAlertActionStyleCancel && SLTActionIsPreferred(actionView);
    CGRect contentFrame = SLTActionContentFrameForView(actionView);
    CGFloat cornerRadius = CGRectGetHeight(contentFrame) / 2.0;

    highlightView.frame = contentFrame;
    highlightView.hidden = NO;
    highlightView.alpha = 1.0;
    highlightView.layer.cornerRadius = cornerRadius;
    highlightView.layer.cornerCurve = kCACornerCurveContinuous;
    highlightView.layer.masksToBounds = YES;
    highlightView.clipsToBounds = YES;
    highlightView.layer.zPosition = 999.0;
    highlightView.backgroundColor = SLTHighlightColor(isPreferred, isDestructive);
    [actionView bringSubviewToFront:highlightView];
}

%end
