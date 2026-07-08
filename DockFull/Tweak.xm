#import <UIKit/UIKit.h>

static BOOL DFIsDockContainer(UIView *view) {
    if (!view) {
        return NO;
    }

    NSString *name = NSStringFromClass(view.class);
    return [name isEqualToString:@"SBDockView"] ||
           [name isEqualToString:@"SBFloatingDockPlatterView"] ||
           [name isEqualToString:@"SBFloatingDockView"];
}

static UIView *DFDockMaterialSubview(UIView *view) {
    for (UIView *subview in view.subviews) {
        NSString *name = NSStringFromClass(subview.class);
        if ([name isEqualToString:@"MTMaterialView"]) {
            return subview;
        }
    }
    return nil;
}

static UIView *DFDockIconListView(UIView *view) {
    for (UIView *subview in view.subviews) {
        NSString *name = NSStringFromClass(subview.class);
        if ([name containsString:@"DockIconListView"]) {
            return subview;
        }
    }
    return nil;
}

static void DFFlattenViewAppearance(UIView *view) {
    if (!view) {
        return;
    }

    view.maskView = nil;
    view.clipsToBounds = NO;
    view.layer.cornerRadius = 0.0;
    view.layer.masksToBounds = NO;
    view.layer.mask = nil;
}

static void DFExpandDock(UIView *dockView) {
    if (!DFIsDockContainer(dockView)) {
        return;
    }

    UIView *superview = dockView.superview;
    if (!superview) {
        return;
    }

    CGRect currentFrame = dockView.frame;
    CGFloat dockHeight = CGRectGetHeight(currentFrame);
    if (dockHeight <= 0.0) {
        dockHeight = CGRectGetHeight(dockView.bounds);
    }
    if (dockHeight <= 0.0) {
        dockHeight = CGRectGetHeight(superview.bounds);
    }

    CGRect desiredFrame = CGRectMake(0.0,
                                      CGRectGetHeight(superview.bounds) - dockHeight,
                                      CGRectGetWidth(superview.bounds),
                                      dockHeight);
    if (!CGRectEqualToRect(dockView.frame, desiredFrame)) {
        dockView.frame = desiredFrame;
    }

    dockView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    DFFlattenViewAppearance(dockView);

    UIView *materialView = DFDockMaterialSubview(dockView);
    if (!materialView) {
        return;
    }

    materialView.frame = dockView.bounds;
    materialView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    DFFlattenViewAppearance(materialView);

    UIView *iconListView = DFDockIconListView(dockView);
    if (iconListView) {
        // Previously this only adjusted origin.y/height and left the icon
        // list's x-origin/width untouched. That meant the icon list view
        // kept the narrower frame it had under the stock "inset" floating
        // dock while its container (dockView) had just been stretched to
        // full width. The mismatch between the icon list's stale frame and
        // its container's new bounds is what made the icon row appear to
        // slide/scroll horizontally as SpringBoard's own layout tried to
        // reconcile the two on every layout pass (most visible when
        // swiping into the App Library page). Snap the icon list to the
        // dock's full bounds instead of only touching y/height.
        iconListView.frame = dockView.bounds;
        iconListView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        // If the icon list is (or contains) a scroll view, make sure it
        // can't be dragged and that any stale horizontal offset/content
        // size left over from the old, narrower frame is cleared.
        if ([iconListView isKindOfClass:[UIScrollView class]]) {
            UIScrollView *scrollView = (UIScrollView *)iconListView;
            scrollView.scrollEnabled = NO;
            scrollView.bounces = NO;
            if (!CGPointEqualToPoint(scrollView.contentOffset, CGPointZero)) {
                scrollView.contentOffset = CGPointZero;
            }
            if (scrollView.contentSize.width > CGRectGetWidth(dockView.bounds)) {
                scrollView.contentSize = CGSizeMake(CGRectGetWidth(dockView.bounds), scrollView.contentSize.height);
            }
        }

        // Force the icon list to recompute its own subviews against the
        // corrected frame right away rather than waiting on the next
        // run-loop pass, which is what produced the visible drift.
        [iconListView setNeedsLayout];
        [iconListView layoutIfNeeded];
    }
}

%hook SBDockView

- (void)didMoveToWindow {
    %orig;
    DFExpandDock((UIView *)self);
}

- (void)layoutSubviews {
    %orig;
    DFExpandDock((UIView *)self);
}

- (void)layoutSublayersOfLayer:(CALayer *)layer {
    %orig(layer);
    DFExpandDock((UIView *)self);
}

%end

%hook SBFloatingDockPlatterView

- (void)didMoveToWindow {
    %orig;
    DFExpandDock((UIView *)self);
}

- (void)layoutSubviews {
    %orig;
    DFExpandDock((UIView *)self);
}

- (void)layoutSublayersOfLayer:(CALayer *)layer {
    %orig(layer);
    DFExpandDock((UIView *)self);
}

%end

%hook SBFloatingDockView

- (void)didMoveToWindow {
    %orig;
    DFExpandDock((UIView *)self);
}

- (void)layoutSubviews {
    %orig;
    DFExpandDock((UIView *)self);
}

- (void)layoutSublayersOfLayer:(CALayer *)layer {
    %orig(layer);
    DFExpandDock((UIView *)self);
}

%end
