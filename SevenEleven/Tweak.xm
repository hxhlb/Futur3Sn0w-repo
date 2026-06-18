#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>

#import <SpringBoard/SBAppSwitcherController.h>
#import <SpringBoard/SBDeckSwitcherViewController.h>
#import <SpringBoard/SBAppSwitcherSnapshotView.h>
#import <SpringBoard/SBWallpaperController.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoardFoundation/SBFStaticWallpaperView.h>

static BOOL const kSEVEnableManualHomeCard = NO;
static BOOL const kSEVEnableCardSizingPrototype = NO;
static BOOL const kSEVEnableEdgeFadePrototype = NO;
static BOOL const kSEVEnableFlattenedScrollingPrototype = NO;
static BOOL const kSEVEnableRightToLeftPrototype = NO;
static BOOL const kSEVEnableMetadataLayoutPrototype = NO;
static BOOL const kSEVEnableDebugOverlay = NO;
static BOOL const kSEVEnableRuntimeMethodDump = NO;

static BOOL const kSEVEnableSettingsDrivenScale = YES;
static BOOL const kSEVEnableSettingsDrivenDepthPadding = NO;
static BOOL const kSEVEnablePersonalityScaleFlattening = YES;
static BOOL const kSEVEnablePersonalityDepthFlattening = YES;
static BOOL const kSEVEnablePersonalityLeadingOffsetSpacing = YES;
static BOOL const kSEVEnablePersonalityFrameBias = NO;
static BOOL const kSEVEnablePersonalityRestingOffsetCompensation = NO;
static BOOL const kSEVEnablePersonalityIndexOffsetCompensation = NO;
static BOOL const kSEVEnablePersonalityActiveGestureOffsetCompensation = NO;
static BOOL const kSEVEnableFluidAdjustedOffsetCompensation = NO;
static BOOL const kSEVDisablePersonalityActiveGestureOffsetAdjustment = YES;
static CGFloat const kSEVDeckPageScaleMultiplier = 0.84;
static CGFloat const kSEVGridPageScaleMultiplier = 0.90;
static CGFloat const kSEVDeckDepthPaddingMultiplier = 0.75;
static CGFloat const kSEVPersonalityScaleVariationMultiplier = 0.18;
static CGFloat const kSEVPersonalityDepthVariationMultiplier = 0.35;
static CGFloat const kSEVPersonalityLeadingOffsetMultiplier = 1.14;
static CGFloat const kSEVPersonalityFrameBiasX = -18.0;
static CGFloat const kSEVPersonalityRestingOffsetXMultiplier = 1.08;
static CGFloat const kSEVPersonalityIndexOffsetXMultiplier = 1.08;
static CGFloat const kSEVPersonalityActiveGestureOffsetXMultiplier = 1.08;
static CGFloat const kSEVFluidAdjustedOffsetXMultiplier = 1.08;
static NSString *const kSEVMethodDumpFilePath = @"/var/mobile/Documents/SevenEleven-method-dump.txt";

static NSInteger const kSEVHomeCardTag = 711011;
static CGFloat const kSEVMinimumCardWidth = 120.0;
static CGFloat const kSEVMinimumCardHeight = 180.0;
static CGFloat const kSEVDefaultCardSpacing = 24.0;
static CGFloat const kSEVMaximumReasonableSpacing = 64.0;
static CGFloat const kSEVCardScale = 0.96;
static CGFloat const kSEVCardCornerRadius = 12.0;
static CGFloat const kSEVMetadataTopSpacing = 10.0;
static CGFloat const kSEVMetadataIconSize = 34.0;
static CGFloat const kSEVMetadataLabelTopSpacing = 5.0;
static char kSEVAdjustedInsetKey;
static char kSEVRightToLeftAppliedKey;
static char kSEVMirroredWrapperKey;
static char kSEVDebugBadgeKey;
static char kSEVDebugBorderKey;
static char kSEVBaseTransformKey;
static char kSEVBaseTransformCapturedKey;

static void SEVHandleHomeCardTap(void);
static void SEVWriteLogLine(NSString *line);

static void SEVDumpMethodsForClassNamed(NSString *className);
static void SEVDumpInterestingSwitcherClasses(void);
static void SEVRunRuntimeMethodDumpIfRequested(void);

@interface SBAppSwitcherSettings : NSObject
@end

@interface SBDeckSwitcherPersonality : NSObject
@end

@interface SEVHomeCardView : UIControl
@property (nonatomic, strong) UIImageView *previewView;
@property (nonatomic, strong) UIView *bottomPlate;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *glyphContainer;
@property (nonatomic, strong) CAGradientLayer *topTintLayer;
- (void)updateWallpaperPreview;
- (void)handlePress;
@end

@implementation SEVHomeCardView

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self) {
		return nil;
	}

	self.tag = kSEVHomeCardTag;
	self.clipsToBounds = YES;
	self.layer.cornerRadius = 14.0;
	if (@available(iOS 13.0, *)) {
		self.layer.cornerCurve = kCACornerCurveContinuous;
	}
	self.layer.shadowColor = [UIColor blackColor].CGColor;
	self.layer.shadowOpacity = 0.16;
	self.layer.shadowRadius = 20.0;
	self.layer.shadowOffset = CGSizeMake(0.0, 8.0);
	self.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];

	_previewView = [[UIImageView alloc] initWithFrame:self.bounds];
	_previewView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_previewView.contentMode = UIViewContentModeScaleAspectFill;
	_previewView.clipsToBounds = YES;
	[self addSubview:_previewView];

	_topTintLayer = [CAGradientLayer layer];
	_topTintLayer.colors = @[
		(__bridge id)[UIColor colorWithWhite:1.0 alpha:0.08].CGColor,
		(__bridge id)[UIColor colorWithWhite:0.0 alpha:0.18].CGColor
	];
	_topTintLayer.startPoint = CGPointMake(0.5, 0.0);
	_topTintLayer.endPoint = CGPointMake(0.5, 1.0);
	_topTintLayer.frame = self.bounds;
	[self.layer addSublayer:_topTintLayer];

	UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
	UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
	blurView.frame = CGRectMake(0.0, CGRectGetHeight(self.bounds) - 56.0, CGRectGetWidth(self.bounds), 56.0);
	blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	[self addSubview:blurView];
	self.bottomPlate = blurView;

	_glyphContainer = [[UIView alloc] initWithFrame:CGRectMake(12.0, CGRectGetHeight(self.bounds) - 42.0, 28.0, 28.0)];
	_glyphContainer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
	_glyphContainer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.28];
	_glyphContainer.layer.cornerRadius = 8.0;
	if (@available(iOS 13.0, *)) {
		_glyphContainer.layer.cornerCurve = kCACornerCurveContinuous;
	}
	[self addSubview:_glyphContainer];

	UIView *homeBar = [[UIView alloc] initWithFrame:CGRectMake(7.0, 7.0, 14.0, 14.0)];
	homeBar.backgroundColor = [UIColor whiteColor];
	homeBar.layer.cornerRadius = 4.0;
	if (@available(iOS 13.0, *)) {
		homeBar.layer.cornerCurve = kCACornerCurveContinuous;
	}
	[_glyphContainer addSubview:homeBar];

	_titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(48.0, CGRectGetHeight(self.bounds) - 43.0, CGRectGetWidth(self.bounds) - 60.0, 28.0)];
	_titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	_titleLabel.text = @"Home";
	_titleLabel.textColor = [UIColor whiteColor];
	_titleLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
	_titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.18];
	_titleLabel.shadowOffset = CGSizeMake(0.0, 1.0);
	[self addSubview:_titleLabel];

	[self updateWallpaperPreview];

	return self;
}

- (void)handlePress {
	SEVHandleHomeCardTap();
}

- (void)layoutSubviews {
	[super layoutSubviews];
	self.topTintLayer.frame = self.bounds;
	self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:self.layer.cornerRadius].CGPath;
}

- (void)updateWallpaperPreview {
	UIImage *wallpaperImage = nil;
	SBWallpaperController *wallpaperController = [%c(SBWallpaperController) sharedInstance];
	if (wallpaperController != nil) {
		[wallpaperController beginRequiringWithReason:@"SevenEleven"];
		SBFStaticWallpaperView *wallpaperView = wallpaperController.homescreenWallpaperView;
		if ([wallpaperView respondsToSelector:@selector(snapshotImage)]) {
			wallpaperImage = [wallpaperView snapshotImage];
		}
		if (wallpaperImage == nil && [wallpaperView respondsToSelector:@selector(wallpaperImage)]) {
			wallpaperImage = wallpaperView.wallpaperImage;
		}
		[wallpaperController endRequiringWithReason:@"SevenEleven"];
	}

	if (wallpaperImage != nil) {
		self.previewView.image = wallpaperImage;
		return;
	}

	UIGraphicsBeginImageContextWithOptions(CGSizeMake(32.0, 64.0), YES, 0.0);
	CGContextRef context = UIGraphicsGetCurrentContext();
	UIColor *top = [UIColor colorWithRed:0.40 green:0.70 blue:1.0 alpha:1.0];
	UIColor *bottom = [UIColor colorWithRed:0.20 green:0.30 blue:0.55 alpha:1.0];
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	NSArray *colors = @[(__bridge id)top.CGColor, (__bridge id)bottom.CGColor];
	CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, NULL);
	CGContextDrawLinearGradient(context, gradient, CGPointZero, CGPointMake(0.0, 64.0), 0);
	CGGradientRelease(gradient);
	CGColorSpaceRelease(colorSpace);
	UIImage *fallbackImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	self.previewView.image = fallbackImage;
}

@end

static BOOL SEVClassNameContainsFragment(id object, const char *fragment) {
	if (object == nil || fragment == NULL) {
		return NO;
	}

	const char *className = object_getClassName(object);
	if (className == NULL) {
		return NO;
	}

	return strstr(className, fragment) != NULL;
}

static BOOL SEVObjectLooksSwitcherRelated(id object) {
	return SEVClassNameContainsFragment(object, "Switcher") ||
		SEVClassNameContainsFragment(object, "Deck") ||
		SEVClassNameContainsFragment(object, "Snapshot") ||
		SEVClassNameContainsFragment(object, "Expose");
}

static BOOL SEVViewHasSwitcherContext(UIView *view) {
	for (UIResponder *responder = view; responder != nil; responder = responder.nextResponder) {
		if (SEVObjectLooksSwitcherRelated(responder)) {
			return YES;
		}
	}

	for (UIView *ancestor = view.superview; ancestor != nil; ancestor = ancestor.superview) {
		if (SEVObjectLooksSwitcherRelated(ancestor)) {
			return YES;
		}
	}

	return NO;
}

static void SEVApplyDebugMarkerToView(UIView *view, NSString *text) {
	if (!kSEVEnableDebugOverlay || view == nil) {
		return;
	}

	view.layer.borderWidth = 3.0;
	view.layer.borderColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.15 alpha:1.0].CGColor;
	objc_setAssociatedObject(view, &kSEVDebugBorderKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	UILabel *badge = objc_getAssociatedObject(view, &kSEVDebugBadgeKey);
	if (![badge isKindOfClass:[UILabel class]]) {
		badge = [[UILabel alloc] initWithFrame:CGRectMake(8.0, 8.0, 72.0, 22.0)];
		badge.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
		badge.backgroundColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.15 alpha:0.92];
		badge.textColor = [UIColor whiteColor];
		badge.font = [UIFont boldSystemFontOfSize:12.0];
		badge.textAlignment = NSTextAlignmentCenter;
		badge.layer.cornerRadius = 6.0;
		badge.clipsToBounds = YES;
		[view addSubview:badge];
		objc_setAssociatedObject(view, &kSEVDebugBadgeKey, badge, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	badge.text = text;
	[view bringSubviewToFront:badge];
}

static void SEVCollectScrollViews(UIView *view, NSMutableArray<UIScrollView *> *scrollViews) {
	if ([view isKindOfClass:[UIScrollView class]]) {
		UIScrollView *scrollView = (UIScrollView *)view;
		if (CGRectGetWidth(scrollView.bounds) > 200.0 && CGRectGetHeight(scrollView.bounds) > 150.0) {
			[scrollViews addObject:scrollView];
		}
	}

	for (UIView *subview in view.subviews) {
		SEVCollectScrollViews(subview, scrollViews);
	}
}

static void SEVCollectSnapshotViews(UIView *view, NSMutableArray<UIView *> *snapshotViews) {
	if ([view isKindOfClass:%c(SBAppSwitcherSnapshotView)] || SEVClassNameContainsFragment(view, "Snapshot")) {
		if (CGRectGetWidth(view.bounds) >= kSEVMinimumCardWidth * 0.6 &&
			CGRectGetHeight(view.bounds) >= kSEVMinimumCardHeight * 0.6) {
			[snapshotViews addObject:view];
		}
	}

	for (UIView *subview in view.subviews) {
		SEVCollectSnapshotViews(subview, snapshotViews);
	}
}

static NSArray<UIView *> *SEVFindSnapshotViews(UIView *rootView) {
	NSMutableArray<UIView *> *snapshotViews = [NSMutableArray array];
	SEVCollectSnapshotViews(rootView, snapshotViews);

	return [snapshotViews sortedArrayUsingComparator:^NSComparisonResult(UIView *left, UIView *right) {
		CGFloat leftX = CGRectGetMinX([left convertRect:left.bounds toView:rootView]);
		CGFloat rightX = CGRectGetMinX([right convertRect:right.bounds toView:rootView]);
		if (leftX < rightX) {
			return NSOrderedAscending;
		}
		if (leftX > rightX) {
			return NSOrderedDescending;
		}
		return NSOrderedSame;
	}];
}

static UIScrollView *SEVFindSwitcherScrollView(UIView *rootView) {
	NSMutableArray<UIScrollView *> *scrollViews = [NSMutableArray array];
	SEVCollectScrollViews(rootView, scrollViews);

	UIScrollView *bestMatch = nil;
	CGFloat bestScore = 0.0;
	for (UIScrollView *scrollView in scrollViews) {
		if (!SEVViewHasSwitcherContext(scrollView)) {
			continue;
		}

		CGFloat score = CGRectGetWidth(scrollView.bounds) * CGRectGetHeight(scrollView.bounds);
		if (scrollView.contentSize.width > CGRectGetWidth(scrollView.bounds) + 20.0) {
			score *= 1.5;
		}
		if (SEVClassNameContainsFragment(scrollView, "Switcher") || SEVClassNameContainsFragment(scrollView, "Deck")) {
			score *= 1.2;
		}
		if (score > bestScore) {
			bestScore = score;
			bestMatch = scrollView;
		}
	}

	return bestMatch;
}

static BOOL SEVIsLikelyCardView(UIView *view) {
	if (view.hidden || view.alpha <= 0.01 || view.tag == kSEVHomeCardTag) {
		return NO;
	}

	CGRect bounds = view.bounds;
	CGFloat width = CGRectGetWidth(bounds);
	CGFloat height = CGRectGetHeight(bounds);
	if (width < kSEVMinimumCardWidth || height < kSEVMinimumCardHeight) {
		return NO;
	}

	CGFloat aspectRatio = width / height;
	if (aspectRatio < 0.45 || aspectRatio > 0.85) {
		return NO;
	}

	if ([view isKindOfClass:[UIScrollView class]] || [view isKindOfClass:[UIControl class]]) {
		return NO;
	}

	if (view.superview == nil) {
		return NO;
	}

	NSString *className = NSStringFromClass([view class]);
	if ([className containsString:@"Snapshot"] ||
		[className containsString:@"Card"] ||
		[className containsString:@"Deck"] ||
		[className containsString:@"Switcher"] ||
		[className containsString:@"Item"]) {
		return YES;
	}

	return view.subviews.count > 0;
}

static void SEVCollectLikelyCardViews(UIView *view, NSMutableArray<UIView *> *views) {
	if (SEVIsLikelyCardView(view)) {
		[views addObject:view];
	}

	for (UIView *subview in view.subviews) {
		SEVCollectLikelyCardViews(subview, views);
	}
}

static NSArray<UIView *> *SEVFindSwitcherCards(UIScrollView *scrollView) {
	NSMutableArray<UIView *> *candidates = [NSMutableArray array];
	for (UIView *subview in scrollView.subviews) {
		SEVCollectLikelyCardViews(subview, candidates);
	}

	if (candidates.count == 0) {
		return @[];
	}

	NSMutableDictionary<NSString *, NSMutableArray<UIView *> *> *buckets = [NSMutableDictionary dictionary];
	for (UIView *candidate in candidates) {
		CGRect frame = [candidate convertRect:candidate.bounds toView:scrollView];
		NSString *bucketKey = [NSString stringWithFormat:@"%d:%d",
			(int)lrint(CGRectGetWidth(frame) / 12.0),
			(int)lrint(CGRectGetHeight(frame) / 12.0)];
		NSMutableArray<UIView *> *bucket = buckets[bucketKey];
		if (bucket == nil) {
			bucket = [NSMutableArray array];
			buckets[bucketKey] = bucket;
		}
		[bucket addObject:candidate];
	}

	NSArray<UIView *> *bestBucket = nil;
	CGFloat bestAreaScore = 0.0;
	for (NSArray<UIView *> *bucket in buckets.allValues) {
		if (bucket.count == 0) {
			continue;
		}

		CGRect frame = [bucket.firstObject convertRect:((UIView *)bucket.firstObject).bounds toView:scrollView];
		CGFloat areaScore = CGRectGetWidth(frame) * CGRectGetHeight(frame);
		if (bestBucket == nil || bucket.count > bestBucket.count || (bucket.count == bestBucket.count && areaScore > bestAreaScore)) {
			bestBucket = bucket;
			bestAreaScore = areaScore;
		}
	}

	if (bestBucket.count == 0) {
		return @[];
	}

	return [bestBucket sortedArrayUsingComparator:^NSComparisonResult(UIView *left, UIView *right) {
		CGRect leftFrame = [left convertRect:left.bounds toView:scrollView];
		CGRect rightFrame = [right convertRect:right.bounds toView:scrollView];
		if (CGRectGetMinX(leftFrame) < CGRectGetMinX(rightFrame)) {
			return NSOrderedAscending;
		}
		if (CGRectGetMinX(leftFrame) > CGRectGetMinX(rightFrame)) {
			return NSOrderedDescending;
		}
		return NSOrderedSame;
	}];
}

static UIView *SEVNearestDirectChildOfScrollView(UIScrollView *scrollView, UIView *descendant) {
	UIView *candidate = descendant;
	while (candidate != nil && candidate.superview != nil && candidate.superview != scrollView) {
		candidate = candidate.superview;
	}

	return candidate.superview == scrollView ? candidate : nil;
}

static NSArray<UIView *> *SEVFindPresentationViewsForRootView(UIView *rootView, UIScrollView *scrollView) {
	NSArray<UIView *> *snapshotViews = SEVFindSnapshotViews(rootView);
	if (snapshotViews.count == 0) {
		return @[];
	}

	NSMutableOrderedSet<UIView *> *presentationViews = [NSMutableOrderedSet orderedSet];
	for (UIView *snapshotView in snapshotViews) {
		UIView *presentationView = scrollView != nil ? SEVNearestDirectChildOfScrollView(scrollView, snapshotView) : snapshotView;
		if (presentationView == nil) {
			presentationView = snapshotView;
		}

		if (presentationView != nil) {
			[presentationViews addObject:presentationView];
		}
	}

	return presentationViews.array;
}

static BOOL SEVIsLikelyMetadataLabel(UIView *view) {
	if (![view isKindOfClass:[UILabel class]] || view.hidden || view.alpha <= 0.01) {
		return NO;
	}

	UILabel *label = (UILabel *)view;
	if (label.text.length == 0) {
		return NO;
	}

	CGRect bounds = view.bounds;
	return CGRectGetHeight(bounds) >= 10.0 &&
		CGRectGetHeight(bounds) <= 28.0 &&
		CGRectGetWidth(bounds) >= 30.0 &&
		CGRectGetWidth(bounds) <= 220.0;
}

static BOOL SEVIsLikelyMetadataIcon(UIView *view) {
	if (view.hidden || view.alpha <= 0.01) {
		return NO;
	}

	CGRect bounds = view.bounds;
	CGFloat width = CGRectGetWidth(bounds);
	CGFloat height = CGRectGetHeight(bounds);
	if (width < 16.0 || width > 60.0 || height < 16.0 || height > 60.0) {
		return NO;
	}

	CGFloat aspectRatio = height > 1.0 ? width / height : 0.0;
	if (aspectRatio < 0.8 || aspectRatio > 1.2) {
		return NO;
	}

	NSString *className = NSStringFromClass([view class]);
	return [view isKindOfClass:[UIImageView class]] ||
		[className containsString:@"Icon"] ||
		[className containsString:@"Image"];
}

static UIView *SEVFindBestMetadataLabel(UIView *searchRoot, CGRect cardFrameInRoot) {
	UIView *bestLabel = nil;
	CGFloat bestScore = CGFLOAT_MAX;

	NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:searchRoot];
	while (stack.count > 0) {
		UIView *view = stack.lastObject;
		[stack removeLastObject];

		if (SEVIsLikelyMetadataLabel(view)) {
			CGRect frame = [view.superview convertRect:view.frame toView:searchRoot];
			CGFloat verticalDistance = MIN(fabs(CGRectGetMinY(frame) - CGRectGetMinY(cardFrameInRoot)),
				fabs(CGRectGetMinY(frame) - CGRectGetMaxY(cardFrameInRoot)));
			CGFloat horizontalDistance = fabs(CGRectGetMidX(frame) - CGRectGetMidX(cardFrameInRoot));
			CGFloat score = verticalDistance + (horizontalDistance * 0.35);
			if (verticalDistance <= 120.0 && horizontalDistance <= CGRectGetWidth(cardFrameInRoot) * 0.8 && score < bestScore) {
				bestScore = score;
				bestLabel = view;
			}
		}

		for (UIView *subview in view.subviews) {
			[stack addObject:subview];
		}
	}

	return bestLabel;
}

static UIView *SEVFindBestMetadataIcon(UIView *searchRoot, CGRect cardFrameInRoot, UIView *labelView) {
	UIView *bestIcon = nil;
	CGFloat bestScore = CGFLOAT_MAX;
	CGRect labelFrame = CGRectZero;
	BOOL hasLabel = labelView != nil;
	if (hasLabel) {
		labelFrame = [labelView.superview convertRect:labelView.frame toView:searchRoot];
	}

	NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:searchRoot];
	while (stack.count > 0) {
		UIView *view = stack.lastObject;
		[stack removeLastObject];

		if (view != labelView && SEVIsLikelyMetadataIcon(view)) {
			CGRect frame = [view.superview convertRect:view.frame toView:searchRoot];
			CGFloat horizontalDistance = fabs(CGRectGetMidX(frame) - CGRectGetMidX(cardFrameInRoot));
			CGFloat verticalAnchor = hasLabel ? CGRectGetMidY(labelFrame) : CGRectGetMaxY(cardFrameInRoot);
			CGFloat verticalDistance = fabs(CGRectGetMidY(frame) - verticalAnchor);
			CGFloat score = verticalDistance + (horizontalDistance * 0.4);
			if (horizontalDistance <= CGRectGetWidth(cardFrameInRoot) * 0.7 && verticalDistance <= 120.0 && score < bestScore) {
				bestScore = score;
				bestIcon = view;
			}
		}

		for (UIView *subview in view.subviews) {
			[stack addObject:subview];
		}
	}

	return bestIcon;
}

static void SEVApplyMetadataLayoutForSnapshot(UIView *snapshotView, UIView *rootView) {
	if (!kSEVEnableMetadataLayoutPrototype || snapshotView.superview == nil) {
		return;
	}

	UIView *containerView = snapshotView.superview;
	UIView *searchRoot = containerView.superview ?: rootView;
	if (searchRoot == nil) {
		searchRoot = rootView;
	}

	CGRect cardFrameInRoot = [snapshotView.superview convertRect:snapshotView.frame toView:searchRoot];
	UIView *labelView = SEVFindBestMetadataLabel(searchRoot, cardFrameInRoot);
	UIView *iconView = SEVFindBestMetadataIcon(searchRoot, cardFrameInRoot, labelView);
	if (labelView == nil && iconView == nil) {
		return;
	}

	if (containerView.superview != nil) {
		containerView.superview.clipsToBounds = NO;
	}
	containerView.clipsToBounds = NO;

	CGFloat cardMidX = CGRectGetMidX(cardFrameInRoot);
	CGFloat nextY = CGRectGetMaxY(cardFrameInRoot) + kSEVMetadataTopSpacing;

	if (iconView != nil) {
		CGRect iconFrame = [iconView.superview convertRect:iconView.frame toView:searchRoot];
		CGFloat iconSize = MAX(CGRectGetWidth(iconFrame), CGRectGetHeight(iconFrame));
		if (iconSize < kSEVMetadataIconSize) {
			iconSize = kSEVMetadataIconSize;
		}
		iconSize = MIN(iconSize, 44.0);
		iconFrame.size = CGSizeMake(iconSize, iconSize);
		iconFrame.origin.x = round(cardMidX - (iconSize / 2.0));
		iconFrame.origin.y = round(nextY);
		iconView.frame = [iconView.superview convertRect:iconFrame fromView:searchRoot];
		iconView.hidden = NO;
		iconView.alpha = 1.0;
		nextY = CGRectGetMaxY(iconFrame) + kSEVMetadataLabelTopSpacing;
	}

	if (labelView != nil) {
		CGRect labelFrame = [labelView.superview convertRect:labelView.frame toView:searchRoot];
		CGFloat labelWidth = MIN(MAX(CGRectGetWidth(labelFrame), 64.0), CGRectGetWidth(cardFrameInRoot) + 60.0);
		labelFrame.origin.x = round(cardMidX - (labelWidth / 2.0));
		labelFrame.origin.y = round(nextY);
		labelFrame.size.width = labelWidth;
		labelView.frame = [labelView.superview convertRect:labelFrame fromView:searchRoot];
		labelView.hidden = NO;
		labelView.alpha = 1.0;

		if ([labelView isKindOfClass:[UILabel class]]) {
			UILabel *label = (UILabel *)labelView;
			label.textAlignment = NSTextAlignmentCenter;
			label.numberOfLines = 1;
			label.adjustsFontSizeToFitWidth = YES;
			label.minimumScaleFactor = 0.75;
		}
	}
}

static NSValue *SEVTransformValue(CGAffineTransform transform) {
	return [NSValue valueWithBytes:&transform objCType:@encode(CGAffineTransform)];
}

static CGAffineTransform SEVTransformFromValue(NSValue *value) {
	CGAffineTransform transform = CGAffineTransformIdentity;
	if (value != nil) {
		[value getValue:&transform];
	}
	return transform;
}

static void SEVCaptureBaseTransformIfNeeded(UIView *view) {
	if ([objc_getAssociatedObject(view, &kSEVBaseTransformCapturedKey) boolValue]) {
		return;
	}

	objc_setAssociatedObject(view, &kSEVBaseTransformKey, SEVTransformValue(view.transform), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(view, &kSEVBaseTransformCapturedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SEVApplyRelativeScaleToView(UIView *view, CGFloat scale) {
	SEVCaptureBaseTransformIfNeeded(view);
	CGAffineTransform baseTransform = SEVTransformFromValue(objc_getAssociatedObject(view, &kSEVBaseTransformKey));
	view.transform = CGAffineTransformScale(baseTransform, scale, scale);
}

static CGFloat SEVCardSpacingForCards(NSArray<UIView *> *cards, UIScrollView *scrollView) {
	if (cards.count < 2) {
		return kSEVDefaultCardSpacing;
	}

	UIView *firstCard = cards[0];
	UIView *secondCard = cards[1];
	CGRect firstFrame = [firstCard convertRect:firstCard.bounds toView:scrollView];
	CGRect secondFrame = [secondCard convertRect:secondCard.bounds toView:scrollView];
	CGFloat spacing = CGRectGetMinX(secondFrame) - CGRectGetMaxX(firstFrame);
	if (spacing < 8.0 || spacing > kSEVMaximumReasonableSpacing) {
		return kSEVDefaultCardSpacing;
	}

	return spacing;
}

static void SEVApplyPrototypeCardStyling(UIScrollView *scrollView, NSArray<UIView *> *cards) {
	if (!kSEVEnableCardSizingPrototype && !kSEVEnableEdgeFadePrototype && !kSEVEnableFlattenedScrollingPrototype) {
		if (!kSEVEnableDebugOverlay) {
			return;
		}
	}

	scrollView.clipsToBounds = NO;
	if (scrollView.superview != nil) {
		scrollView.superview.clipsToBounds = NO;
	}

	for (UIView *card in cards) {
		if (kSEVEnableCardSizingPrototype) {
			SEVApplyRelativeScaleToView(card, kSEVCardScale);
			card.layer.cornerRadius = kSEVCardCornerRadius;
			if (@available(iOS 13.0, *)) {
				card.layer.cornerCurve = kCACornerCurveContinuous;
			}
			card.layer.masksToBounds = YES;
		} else {
			card.layer.masksToBounds = NO;
		}

		if (kSEVEnableFlattenedScrollingPrototype) {
			card.layer.transform = CATransform3DIdentity;
		}

		if (kSEVEnableEdgeFadePrototype) {
			card.alpha = 1.0;
			card.layer.opacity = 1.0f;
		}

		if (kSEVEnableDebugOverlay) {
			SEVApplyDebugMarkerToView(card, @"SEV");
		}
	}
}

static void SEVApplyRightToLeftLayout(UIScrollView *scrollView, NSArray<UIView *> *cards) {
	if (!kSEVEnableRightToLeftPrototype) {
		return;
	}

	if (![objc_getAssociatedObject(scrollView, &kSEVRightToLeftAppliedKey) boolValue]) {
		scrollView.transform = CGAffineTransformScale(scrollView.transform, -1.0, 1.0);
		scrollView.showsHorizontalScrollIndicator = NO;
		objc_setAssociatedObject(scrollView, &kSEVRightToLeftAppliedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	NSMutableOrderedSet<UIView *> *wrappers = [NSMutableOrderedSet orderedSet];
	for (UIView *wrapper in SEVFindPresentationViewsForRootView(scrollView, scrollView)) {
		[wrappers addObject:wrapper];
	}

	if (wrappers.count == 0) {
		for (UIView *card in cards) {
			UIView *wrapper = SEVNearestDirectChildOfScrollView(scrollView, card);
			if (wrapper != nil) {
				[wrappers addObject:wrapper];
			}
		}
	}

	for (UIView *wrapper in wrappers) {
		if ([objc_getAssociatedObject(wrapper, &kSEVMirroredWrapperKey) boolValue]) {
			if (kSEVEnableCardSizingPrototype) {
				wrapper.transform = CGAffineTransformMakeScale(-kSEVCardScale, kSEVCardScale);
			}
			continue;
		}

		wrapper.transform = CGAffineTransformScale(wrapper.transform, -1.0, 1.0);
		objc_setAssociatedObject(wrapper, &kSEVMirroredWrapperKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
}

static void SEVHandleHomeCardTap(void) {
	SpringBoard *springBoard = (SpringBoard *)[%c(SpringBoard) sharedApplication];
	if ([springBoard respondsToSelector:@selector(_simulateHomeButtonPress)]) {
		[springBoard _simulateHomeButtonPress];
	}
}

static void SEVWriteLogLine(NSString *line) {
	if (line.length == 0) {
		return;
	}

	NSLog(@"%@", line);

	NSString *lineWithNewline = [line stringByAppendingString:@"\n"];
	NSData *data = [lineWithNewline dataUsingEncoding:NSUTF8StringEncoding];
	if (data == nil) {
		return;
	}

	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *directoryPath = [kSEVMethodDumpFilePath stringByDeletingLastPathComponent];
	if (![fileManager fileExistsAtPath:directoryPath]) {
		[fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
	}

	if (![fileManager fileExistsAtPath:kSEVMethodDumpFilePath]) {
		[fileManager createFileAtPath:kSEVMethodDumpFilePath contents:nil attributes:nil];
	}

	NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:kSEVMethodDumpFilePath];
	if (fileHandle == nil) {
		return;
	}

	@try {
		[fileHandle seekToEndOfFile];
		[fileHandle writeData:data];
	} @catch (__unused NSException *exception) {
	} @finally {
		[fileHandle closeFile];
	}
}

static void SEVDumpMethodsForClassNamed(NSString *className) {
	Class cls = objc_getClass(className.UTF8String);
	if (cls == Nil) {
		SEVWriteLogLine([NSString stringWithFormat:@"[SevenEleven] method-dump missing class %@", className]);
		return;
	}

	SEVWriteLogLine([NSString stringWithFormat:@"[SevenEleven] method-dump begin class=%@ superclass=%@", className, NSStringFromClass(class_getSuperclass(cls))]);

	unsigned int instanceMethodCount = 0;
	Method *instanceMethods = class_copyMethodList(cls, &instanceMethodCount);
	for (unsigned int index = 0; index < instanceMethodCount; index++) {
		SEL selector = method_getName(instanceMethods[index]);
		const char *types = method_getTypeEncoding(instanceMethods[index]);
		SEVWriteLogLine([NSString stringWithFormat:@"[SevenEleven] instance %@ %@", className, NSStringFromSelector(selector)]);
		if (types != NULL) {
			SEVWriteLogLine([NSString stringWithFormat:@"[SevenEleven] types %@ %s", NSStringFromSelector(selector), types]);
		}
	}
	free(instanceMethods);

	Class metaClass = object_getClass(cls);
	unsigned int classMethodCount = 0;
	Method *classMethods = class_copyMethodList(metaClass, &classMethodCount);
	for (unsigned int index = 0; index < classMethodCount; index++) {
		SEL selector = method_getName(classMethods[index]);
		const char *types = method_getTypeEncoding(classMethods[index]);
		SEVWriteLogLine([NSString stringWithFormat:@"[SevenEleven] class %@ +[%@ %@]", className, className, NSStringFromSelector(selector)]);
		if (types != NULL) {
			SEVWriteLogLine([NSString stringWithFormat:@"[SevenEleven] class-types %@ %s", NSStringFromSelector(selector), types]);
		}
	}
	free(classMethods);

	SEVWriteLogLine([NSString stringWithFormat:@"[SevenEleven] method-dump end class=%@ instanceMethods=%u classMethods=%u", className, instanceMethodCount, classMethodCount]);
}

static void SEVDumpInterestingSwitcherClasses(void) {
	int classCount = objc_getClassList(NULL, 0);
	if (classCount <= 0) {
		return;
	}

	Class *classes = (Class *)calloc((size_t)classCount, sizeof(Class));
	if (classes == NULL) {
		return;
	}

	classCount = objc_getClassList(classes, classCount);
	NSMutableArray<NSString *> *matches = [NSMutableArray array];
	for (int index = 0; index < classCount; index++) {
		Class cls = classes[index];
		if (cls == Nil) {
			continue;
		}

		NSString *name = NSStringFromClass(cls);
		if (![name hasPrefix:@"SB"]) {
			continue;
		}

		if ([name containsString:@"Switcher"] || [name containsString:@"Deck"]) {
			[matches addObject:name];
		}
	}
	free(classes);

	[matches sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	SEVWriteLogLine([NSString stringWithFormat:@"[SevenEleven] runtime-switcher-class-count=%lu", (unsigned long)matches.count]);
	for (NSString *name in matches) {
		SEVWriteLogLine([NSString stringWithFormat:@"[SevenEleven] runtime-switcher-class %@", name]);
	}
}

static void SEVRunRuntimeMethodDumpIfRequested(void) {
	if (!kSEVEnableRuntimeMethodDump) {
		return;
	}

	[[NSFileManager defaultManager] removeItemAtPath:kSEVMethodDumpFilePath error:nil];
	SEVWriteLogLine([NSString stringWithFormat:@"[SevenEleven] runtime method dump start file=%@", kSEVMethodDumpFilePath]);
	SEVDumpInterestingSwitcherClasses();

	NSArray<NSString *> *targetClasses = @[
		@"SBAppSwitcherSettings",
		@"SBDeckSwitcherPersonality",
		@"SBFluidSwitcherViewController",
		@"SBMainSwitcherViewController",
		@"SBFluidSwitcherItemContainer",
		@"SBFluidSwitcherIconImageContainerView",
		@"SBDeckSwitcherViewController",
		@"SBAppSwitcherSnapshotView"
	];

	for (NSString *className in targetClasses) {
		SEVDumpMethodsForClassNamed(className);
	}

	SEVWriteLogLine(@"[SevenEleven] runtime method dump end");
}

static BOOL SEVShouldRunViewMutationPass(void) {
	return kSEVEnableManualHomeCard ||
		kSEVEnableCardSizingPrototype ||
		kSEVEnableEdgeFadePrototype ||
		kSEVEnableFlattenedScrollingPrototype ||
		kSEVEnableRightToLeftPrototype ||
		kSEVEnableMetadataLayoutPrototype ||
		kSEVEnableDebugOverlay;
}

static void SEVApplySwitcherPass(UIView *rootView) {
	if (!SEVShouldRunViewMutationPass()) {
		return;
	}

	UIScrollView *scrollView = SEVFindSwitcherScrollView(rootView);
	if (scrollView == nil) {
		return;
	}

	NSArray<UIView *> *cards = SEVFindSwitcherCards(scrollView);
	if (cards.count == 0) {
		cards = SEVFindSnapshotViews(rootView);
		if (cards.count == 0) {
			return;
		}
	}

	SEVApplyPrototypeCardStyling(scrollView, cards);
	SEVApplyRightToLeftLayout(scrollView, cards);
	if (kSEVEnableMetadataLayoutPrototype) {
		for (UIView *snapshotView in SEVFindSnapshotViews(rootView)) {
			SEVApplyMetadataLayoutForSnapshot(snapshotView, rootView);
		}
	}

	if (!kSEVEnableManualHomeCard) {
		return;
	}

	NSArray<UIView *> *presentationViews = SEVFindPresentationViewsForRootView(rootView, scrollView);
	UIView *firstCard = presentationViews.firstObject ?: cards.firstObject;
	CGRect firstCardFrame = [firstCard convertRect:firstCard.bounds toView:scrollView];
	if (CGRectGetWidth(firstCardFrame) < kSEVMinimumCardWidth || CGRectGetHeight(firstCardFrame) < kSEVMinimumCardHeight) {
		return;
	}

	CGFloat spacing = SEVCardSpacingForCards(cards, scrollView);
	CGFloat insetAmount = CGRectGetWidth(firstCardFrame) + spacing;

	SEVHomeCardView *homeCard = (SEVHomeCardView *)[scrollView viewWithTag:kSEVHomeCardTag];
	if (![homeCard isKindOfClass:[SEVHomeCardView class]]) {
		homeCard = [[SEVHomeCardView alloc] initWithFrame:firstCardFrame];
		[homeCard addTarget:homeCard action:@selector(handlePress) forControlEvents:UIControlEventTouchUpInside];
		[scrollView addSubview:homeCard];
	}

	homeCard.frame = CGRectOffset(firstCardFrame, -(CGRectGetWidth(firstCardFrame) + spacing), 0.0);
	[homeCard updateWallpaperPreview];
	if ([objc_getAssociatedObject(homeCard, &kSEVMirroredWrapperKey) boolValue] == NO && kSEVEnableRightToLeftPrototype) {
		homeCard.transform = CGAffineTransformScale(homeCard.transform, -1.0, 1.0);
		objc_setAssociatedObject(homeCard, &kSEVMirroredWrapperKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	[scrollView bringSubviewToFront:homeCard];

	UIEdgeInsets contentInset = scrollView.contentInset;
	if (contentInset.left < insetAmount) {
		contentInset.left = insetAmount;
		scrollView.contentInset = contentInset;
		scrollView.scrollIndicatorInsets = contentInset;
	}

	NSNumber *didAdjustInset = objc_getAssociatedObject(scrollView, &kSEVAdjustedInsetKey);
	if (![didAdjustInset boolValue] && !scrollView.dragging && !scrollView.decelerating && !scrollView.tracking) {
		scrollView.contentOffset = CGPointMake(-contentInset.left, scrollView.contentOffset.y);
		objc_setAssociatedObject(scrollView, &kSEVAdjustedInsetKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
}

static void SEVRefreshSwitcher(UIViewController *controller) {
	if (controller == nil || controller.view == nil || controller.view.window == nil) {
		return;
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		SEVApplySwitcherPass(controller.view);
	});
}

static void SEVRefreshSwitcherFromView(UIView *view) {
	if (view == nil || view.window == nil || !SEVViewHasSwitcherContext(view)) {
		return;
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		UIView *rootView = view;
		while (rootView.superview != nil && rootView.superview.window != nil) {
			rootView = rootView.superview;
		}
		SEVApplySwitcherPass(rootView);
	});
}

@interface SBFluidSwitcherViewController : UIViewController
@end

@interface SBMainSwitcherViewController : UIViewController
@end

%group SevenElevenSettingsHooks

%hook SBAppSwitcherSettings

- (double)deckSwitcherPageScale {
	double originalValue = %orig;
	return kSEVEnableSettingsDrivenScale ? (originalValue * kSEVDeckPageScaleMultiplier) : originalValue;
}

- (double)depthPadding {
	double originalValue = %orig;
	return kSEVEnableSettingsDrivenDepthPadding ? (originalValue * kSEVDeckDepthPaddingMultiplier) : originalValue;
}

- (double)gridSwitcherPageScale {
	double originalValue = %orig;
	return kSEVEnableSettingsDrivenScale ? (originalValue * kSEVGridPageScaleMultiplier) : originalValue;
}

%end

%end

%group SevenElevenDeckPersonalityHooks

%hook SBDeckSwitcherPersonality

- (double)_scaleInSwitcherViewForIndex:(NSUInteger)index stackedProgress:(double)stackedProgress scrollProgress:(double)scrollProgress {
	double originalValue = %orig;
	if (!kSEVEnablePersonalityScaleFlattening) {
		return originalValue;
	}

	// Reduce scale spread by pulling values partway back toward 1.0 instead of replacing them.
	return 1.0 + ((originalValue - 1.0) * kSEVPersonalityScaleVariationMultiplier);
}

- (double)_depthForIndex:(NSUInteger)index displayItemsCount:(NSUInteger)displayItemsCount scrollProgress:(double)scrollProgress ignoreInsertionsAndRemovals:(BOOL)ignoreInsertionsAndRemovals {
	double originalValue = %orig;
	if (!kSEVEnablePersonalityDepthFlattening) {
		return originalValue;
	}

	// Reduce depth spread without zeroing it out, to preserve deck geometry stability.
	return originalValue * kSEVPersonalityDepthVariationMultiplier;
}

- (double)_leadingOffsetForIndex:(NSUInteger)index displayItemsCount:(NSUInteger)displayItemsCount stackedProgress:(double)stackedProgress scrollProgress:(double)scrollProgress ignoreInsertionsAndRemovals:(BOOL)ignoreInsertionsAndRemovals {
	double originalValue = %orig;
	if (!kSEVEnablePersonalityLeadingOffsetSpacing) {
		return originalValue;
	}

	// Spread cards back out by scaling the stock leading offset instead of inventing a new layout.
	return originalValue * kSEVPersonalityLeadingOffsetMultiplier;
}

- (CGRect)frameForIndex:(NSUInteger)index mode:(NSInteger)mode {
	CGRect originalValue = %orig;
	if (!kSEVEnablePersonalityFrameBias) {
		return originalValue;
	}

	originalValue.origin.x += kSEVPersonalityFrameBiasX;
	return originalValue;
}

- (BOOL)shouldAdjustContentOffsetForActiveGesture {
	if (kSEVDisablePersonalityActiveGestureOffsetAdjustment) {
		return NO;
	}

	return %orig;
}

- (BOOL)_shouldAccountForScaleWhenAdjustingContentOffsetForActiveGesture {
	if (kSEVDisablePersonalityActiveGestureOffsetAdjustment) {
		return NO;
	}

	return %orig;
}

- (CGPoint)contentOffsetForActiveGesture {
	CGPoint originalValue = %orig;
	if (kSEVDisablePersonalityActiveGestureOffsetAdjustment) {
		return CGPointZero;
	}

	if (!kSEVEnablePersonalityActiveGestureOffsetCompensation) {
		return originalValue;
	}

	return CGPointMake(originalValue.x * kSEVPersonalityActiveGestureOffsetXMultiplier, originalValue.y);
}

- (CGPoint)restingOffsetForScrollOffset:(CGPoint)scrollOffset velocity:(CGPoint)velocity {
	CGPoint originalValue = %orig;
	if (!kSEVEnablePersonalityRestingOffsetCompensation) {
		return originalValue;
	}

	return CGPointMake(originalValue.x * kSEVPersonalityRestingOffsetXMultiplier, originalValue.y);
}

- (CGPoint)contentOffsetForIndex:(NSUInteger)index ignoreInsertionsAndRemovals:(BOOL)ignoreInsertionsAndRemovals {
	CGPoint originalValue = %orig;
	if (!kSEVEnablePersonalityIndexOffsetCompensation) {
		return originalValue;
	}

	return CGPointMake(originalValue.x * kSEVPersonalityIndexOffsetXMultiplier, originalValue.y);
}

%end

%end

%hook SBDeckSwitcherViewController

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	SEVRefreshSwitcher(self);
}

- (void)viewDidLayoutSubviews {
	%orig;
	SEVRefreshSwitcher(self);
}

%end

%hook SBAppSwitcherController

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	SEVRefreshSwitcher(self);
}

- (void)viewDidLayoutSubviews {
	%orig;
	SEVRefreshSwitcher(self);
}

%end

%hook SBAppSwitcherSnapshotView

- (void)didMoveToWindow {
	%orig;
	SEVApplyDebugMarkerToView(self, @"CARD");
	SEVRefreshSwitcherFromView(self);
}

- (void)layoutSubviews {
	%orig;
	SEVApplyDebugMarkerToView(self, @"CARD");
	SEVRefreshSwitcherFromView(self);
}

%end

%hook UIScrollView

- (void)didMoveToWindow {
	%orig;
	if (SEVViewHasSwitcherContext(self)) {
		SEVApplyDebugMarkerToView(self, @"SCROLL");
		SEVRefreshSwitcherFromView(self);
	}
}

- (void)layoutSubviews {
	%orig;
	if (SEVViewHasSwitcherContext(self)) {
		SEVApplyDebugMarkerToView(self, @"SCROLL");
		SEVRefreshSwitcherFromView(self);
	}
}

%end

%group SevenElevenDynamicSwitcherHooks

%hook SBFluidSwitcherViewController

- (CGPoint)_scrollView:(UIScrollView *)scrollView adjustedOffsetForOffset:(CGPoint)offset translation:(CGPoint)translation startPoint:(CGPoint)startPoint locationInView:(CGPoint)locationInView horizontalVelocity:(double *)horizontalVelocity verticalVelocity:(double *)verticalVelocity {
	CGPoint originalValue = %orig;
	if (!kSEVEnableFluidAdjustedOffsetCompensation) {
		return originalValue;
	}

	return CGPointMake(originalValue.x * kSEVFluidAdjustedOffsetXMultiplier, originalValue.y);
}

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	SEVRefreshSwitcher(self);
	if (kSEVEnableDebugOverlay) {
		SEVApplyDebugMarkerToView(self.view, @"FLUID");
	}
}

- (void)viewDidLayoutSubviews {
	%orig;
	SEVRefreshSwitcher(self);
	if (kSEVEnableDebugOverlay) {
		SEVApplyDebugMarkerToView(self.view, @"FLUID");
	}
}

%end

%hook SBMainSwitcherViewController

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	SEVRefreshSwitcher(self);
	if (kSEVEnableDebugOverlay) {
		SEVApplyDebugMarkerToView(self.view, @"MAIN");
	}
}

- (void)viewDidLayoutSubviews {
	%orig;
	SEVRefreshSwitcher(self);
	if (kSEVEnableDebugOverlay) {
		SEVApplyDebugMarkerToView(self.view, @"MAIN");
	}
}

%end

%end

%ctor {
	SEVRunRuntimeMethodDumpIfRequested();

	Class settingsClass = objc_getClass("SBAppSwitcherSettings");
	if (settingsClass != Nil) {
		%init(SevenElevenSettingsHooks, SBAppSwitcherSettings=settingsClass);
	}

	Class deckPersonalityClass = objc_getClass("SBDeckSwitcherPersonality");
	if (deckPersonalityClass != Nil) {
		%init(SevenElevenDeckPersonalityHooks, SBDeckSwitcherPersonality=deckPersonalityClass);
	}

	if (SEVShouldRunViewMutationPass()) {
		%init;

		Class fluidSwitcherClass = objc_getClass("SBFluidSwitcherViewController");
		Class mainSwitcherClass = objc_getClass("SBMainSwitcherViewController");
		if (fluidSwitcherClass != Nil || mainSwitcherClass != Nil) {
			%init(SevenElevenDynamicSwitcherHooks);
		}
	}
}
