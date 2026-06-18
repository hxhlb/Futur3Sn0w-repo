#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

@interface SBIconListView : UIView
- (NSUInteger)iconColumnsForCurrentOrientation;
@end

static const void *kCLRPendingCenterKey = &kCLRPendingCenterKey;

static BOOL CLRClassNameContainsFragment(id object, const char *fragment) {
	if (object == nil || fragment == NULL) {
		return NO;
	}

	const char *className = object_getClassName(object);
	if (className == NULL) {
		return NO;
	}

	return strstr(className, fragment) != NULL;
}

static BOOL CLRHasAncestorWithClassFragment(UIView *view, const char *fragment) {
	for (UIView *ancestor = view.superview; ancestor != nil; ancestor = ancestor.superview) {
		if (CLRClassNameContainsFragment(ancestor, fragment)) {
			return YES;
		}
	}

	return NO;
}

static BOOL CLRIsDockIconListView(UIView *view) {
	return CLRClassNameContainsFragment(view, "Dock") || CLRHasAncestorWithClassFragment(view, "Dock");
}

static BOOL CLRIsCandidateIconView(UIView *view) {
	if (view.hidden || view.alpha <= 0.01 || CGRectIsEmpty(view.bounds)) {
		return NO;
	}

	const char *className = object_getClassName(view);
	if (className == NULL || strstr(className, "IconView") == NULL) {
		return NO;
	}

	if (strstr(className, "Image") != NULL ||
		strstr(className, "Label") != NULL ||
		strstr(className, "List") != NULL ||
		strstr(className, "Page") != NULL) {
		return NO;
	}

	return YES;
}

static void CLRCollectIconViews(UIView *view, NSMutableArray<UIView *> *iconViews) {
	if (CLRIsCandidateIconView(view)) {
		[iconViews addObject:view];
		return;
	}

	for (UIView *subview in view.subviews) {
		CLRCollectIconViews(subview, iconViews);
	}
}

static NSArray<NSArray<UIView *> *> *CLRBuildRows(NSArray<UIView *> *iconViews) {
	NSArray<UIView *> *sortedIconViews = [iconViews sortedArrayUsingComparator:^NSComparisonResult(UIView *left, UIView *right) {
		CGFloat leftY = CGRectGetMinY(left.frame);
		CGFloat rightY = CGRectGetMinY(right.frame);
		if (fabs(leftY - rightY) > 8.0) {
			return leftY < rightY ? NSOrderedAscending : NSOrderedDescending;
		}

		CGFloat leftX = CGRectGetMidX(left.frame);
		CGFloat rightX = CGRectGetMidX(right.frame);
		if (leftX < rightX) {
			return NSOrderedAscending;
		}

		if (leftX > rightX) {
			return NSOrderedDescending;
		}

		return NSOrderedSame;
	}];

	NSMutableArray<NSMutableArray<UIView *> *> *rows = [NSMutableArray array];
	for (UIView *iconView in sortedIconViews) {
		CGFloat iconY = CGRectGetMinY(iconView.frame);
		NSMutableArray<UIView *> *matchingRow = nil;

		for (NSMutableArray<UIView *> *row in rows) {
			UIView *referenceView = row.firstObject;
			if (fabs(CGRectGetMinY(referenceView.frame) - iconY) <= 8.0) {
				matchingRow = row;
				break;
			}
		}

		if (matchingRow == nil) {
			matchingRow = [NSMutableArray array];
			[rows addObject:matchingRow];
		}

		[matchingRow addObject:iconView];
	}

	for (NSMutableArray<UIView *> *row in rows) {
		[row sortUsingComparator:^NSComparisonResult(UIView *left, UIView *right) {
			CGFloat leftX = CGRectGetMidX(left.frame);
			CGFloat rightX = CGRectGetMidX(right.frame);
			if (leftX < rightX) {
				return NSOrderedAscending;
			}

			if (leftX > rightX) {
				return NSOrderedDescending;
			}

			return NSOrderedSame;
		}];
	}

	return rows;
}

static NSUInteger CLRColumnCountForListView(SBIconListView *listView, NSArray<NSArray<UIView *> *> *rows) {
	NSUInteger columnCount = 0;

	if ([listView respondsToSelector:@selector(iconColumnsForCurrentOrientation)]) {
		columnCount = ((NSUInteger (*)(id, SEL))objc_msgSend)(listView, @selector(iconColumnsForCurrentOrientation));
	}

	if (columnCount > 0) {
		return columnCount;
	}

	for (NSArray<UIView *> *row in rows) {
		columnCount = MAX(columnCount, row.count);
	}

	return columnCount;
}

static CGFloat CLRHorizontalStepForRows(NSArray<NSArray<UIView *> *> *rows, CGRect bounds, NSUInteger columnCount) {
	for (NSArray<UIView *> *row in rows) {
		if (row.count < 2) {
			continue;
		}

		CGFloat totalStep = 0.0;
		NSUInteger segmentCount = 0;
		for (NSUInteger index = 1; index < row.count; index++) {
			CGFloat previousX = CGRectGetMidX(((UIView *)row[index - 1]).frame);
			CGFloat currentX = CGRectGetMidX(((UIView *)row[index]).frame);
			CGFloat delta = currentX - previousX;
			if (delta > 1.0) {
				totalStep += delta;
				segmentCount++;
			}
		}

		if (segmentCount > 0) {
			return totalStep / (CGFloat)segmentCount;
		}
	}

	if (columnCount > 1) {
		return CGRectGetWidth(bounds) / (CGFloat)columnCount;
	}

	return 0.0;
}

static void CLCenterLastRowIfNeeded(SBIconListView *listView) {
	if (CLRIsDockIconListView(listView)) {
		return;
	}

	NSMutableArray<UIView *> *iconViews = [NSMutableArray array];
	for (UIView *subview in listView.subviews) {
		CLRCollectIconViews(subview, iconViews);
	}

	if (iconViews.count == 0) {
		return;
	}

	NSArray<NSArray<UIView *> *> *rows = CLRBuildRows(iconViews);
	if (rows.count == 0) {
		return;
	}

	NSUInteger columnCount = CLRColumnCountForListView(listView, rows);
	if (columnCount < 2) {
		return;
	}

	NSArray<UIView *> *lastRow = rows.lastObject;
	NSUInteger lastRowCount = lastRow.count;
	if (lastRowCount == 0 || lastRowCount >= columnCount) {
		return;
	}

	CGFloat horizontalStep = CLRHorizontalStepForRows(rows, listView.bounds, columnCount);
	if (horizontalStep <= 1.0) {
		return;
	}

	CGFloat listMidX = CGRectGetMidX(listView.bounds);
	CGFloat startingOffset = ((CGFloat)lastRowCount - 1.0) / 2.0;
	for (NSUInteger index = 0; index < lastRowCount; index++) {
		UIView *iconView = lastRow[index];
		CGFloat targetCenterX = listMidX + (((CGFloat)index - startingOffset) * horizontalStep);
		iconView.center = CGPointMake(targetCenterX, iconView.center.y);
	}
}

static void CLScheduleCenterLastRowIfNeeded(SBIconListView *listView) {
	if (listView == nil) {
		return;
	}

	NSNumber *isPending = objc_getAssociatedObject(listView, kCLRPendingCenterKey);
	if (isPending.boolValue) {
		return;
	}

	objc_setAssociatedObject(listView, kCLRPendingCenterKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	dispatch_async(dispatch_get_main_queue(), ^{
		objc_setAssociatedObject(listView, kCLRPendingCenterKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

		if (listView.window == nil) {
			return;
		}

		CLCenterLastRowIfNeeded(listView);
	});
}

%hook SBIconListView

- (void)layoutSubviews {
	%orig;
	CLScheduleCenterLastRowIfNeeded(self);
}

- (void)didMoveToWindow {
	%orig;
	CLScheduleCenterLastRowIfNeeded(self);
}

- (void)setFrame:(CGRect)frame {
	%orig(frame);
	CLScheduleCenterLastRowIfNeeded(self);
}

- (void)setBounds:(CGRect)bounds {
	%orig(bounds);
	CLScheduleCenterLastRowIfNeeded(self);
}

- (void)layoutIconsNow {
	%orig;
	CLScheduleCenterLastRowIfNeeded(self);
}

- (void)layoutIconsIfNeeded {
	%orig;
	CLScheduleCenterLastRowIfNeeded(self);
}

%end
