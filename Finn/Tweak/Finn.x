#import "Finn.h"

// gGhostFadeRunning: a ghost is actively animating right now.
// gEarlyFadeStarted: the early-dismiss path already kicked off a ghost this
//   cycle, so willMoveToWindow:nil shouldn't spawn a second one even if the
//   first ghost already finished by the time the container is removed.
static BOOL gGhostFadeRunning  = NO;
static BOOL gEarlyFadeStarted  = NO;

// Find _UIContextMenuContainerView in any on-screen window and start fading
// it immediately (before the system's dismiss animation even begins).
static void FinnStartEarlyBackdropFade(void) {
    if (gGhostFadeRunning) return;
    Class cls = NSClassFromString(@"_UIContextMenuContainerView");
    if (!cls) return;
    UIView *container = nil;
    NSMutableArray *queue = [NSMutableArray array];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *w in [UIApplication sharedApplication].windows)
        [queue addObjectsFromArray:w.subviews];
#pragma clang diagnostic pop
    for (NSUInteger i = 0; i < queue.count && !container; i++) {
        UIView *v = queue[i];
        if ([v isKindOfClass:cls]) { container = v; break; }
        [queue addObjectsFromArray:v.subviews];
    }
    if (!container) return;
    CGColorRef bg = container.layer.backgroundColor;
    if (!bg || CGColorGetAlpha(bg) <= 0.01) return;
    UIView *parent = container.superview;
    if (!parent) return;
    UIView *ghost = [[UIView alloc] initWithFrame:container.frame];
    ghost.backgroundColor = [UIColor colorWithCGColor:bg];
    ghost.userInteractionEnabled = NO;
    [parent insertSubview:ghost belowSubview:container];
    // Clear the real container's color immediately so the ghost is the only
    // thing carrying the tint — prevents the two layers from stacking alpha.
    container.backgroundColor = [UIColor clearColor];
    gGhostFadeRunning = YES;
    gEarlyFadeStarted = YES;
    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{ ghost.alpha = 0; }
                     completion:^(BOOL _){ [ghost removeFromSuperview]; gGhostFadeRunning = NO; }];
}

static void FinnTintViewTree(UIView *root, UIColor *color, int depth) {
    if (!root || depth <= 0) return;
    for (UIView *sub in root.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            [(UIVisualEffectView *)sub contentView].backgroundColor = color;
        } else {
            CGFloat a = sub.backgroundColor.CGColor
                ? CGColorGetAlpha(sub.backgroundColor.CGColor) : 0;
            if (a > 0.05) sub.backgroundColor = color;
        }
        FinnTintViewTree(sub, color, depth - 1);
    }
}

%group Finn

// ── iOS 13/14 entry point ────────────────────────────────────────────────────
%hook SBIconController
- (id)containerViewForPresentingContextMenuForIconView:(SBIconView *)iconView {
    if (FinnBool(kKeyEnabled, NO)) FinnUpdateColorsForIconView(iconView);
    return %orig;
}
%end

// ── iOS 15/16 entry points ───────────────────────────────────────────────────
%hook SBIconView
- (id)contextMenuInteraction:(id)interaction
    configurationForMenuAtLocation:(CGPoint)location {
    if (FinnBool(kKeyEnabled, NO)) FinnUpdateColorsForIconView(self);
    return %orig;
}
- (void)activateShortcut:(id)item withBundleIdentifier:(NSString *)bundleID
            forIconView:(id)iconView {
    gBackgroundColor = nil; gMenuColor = nil;
    %orig;
}
// Fires at the start of the dismiss animation on iOS 15/16 — earlier than
// willMoveToWindow:nil, giving the backdrop fade a head start.
- (void)contextMenuInteraction:(id)interaction
    willEndForConfiguration:(id)configuration
                   animator:(id)animator {
    if (FinnBool(kKeyEnabled, NO) && FinnBool(kKeyBGEnabled, YES))
        FinnStartEarlyBackdropFade();
    gBackgroundColor = nil; gMenuColor = nil;
    %orig;
}
%end

// ── Backdrop tint ────────────────────────────────────────────────────────────
%hook _UIContextMenuContainerView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    if (!newWindow) {
        // Only create a fallback ghost if the early-dismiss path didn't
        // already handle it (covers edge cases like home-button dismiss).
        if (!gGhostFadeRunning && !gEarlyFadeStarted) {
            CGColorRef bg = self.layer.backgroundColor;
            if (bg && CGColorGetAlpha(bg) > 0.01) {
                UIView *parent = self.superview;
                if (parent) {
                    UIView *ghost = [[UIView alloc] initWithFrame:self.frame];
                    ghost.backgroundColor = [UIColor colorWithCGColor:bg];
                    ghost.userInteractionEnabled = NO;
                    [parent insertSubview:ghost belowSubview:self];
                    gGhostFadeRunning = YES;
                    [UIView animateWithDuration:0.25
                                          delay:0
                                        options:UIViewAnimationOptionCurveEaseIn
                                     animations:^{ ghost.alpha = 0; }
                                     completion:^(BOOL _){ [ghost removeFromSuperview]; gGhostFadeRunning = NO; }];
                }
            }
        }
        %orig;
        return;
    }
    %orig;
    if (!FinnBool(kKeyEnabled, NO) || !FinnBool(kKeyBGEnabled, YES) || !gBackgroundColor) return;
    self.backgroundColor = [UIColor clearColor];
    [UIView animateWithDuration:0.25 delay:0.05
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{ self.backgroundColor = gBackgroundColor; }
                     completion:nil];
}
- (void)didMoveToWindow {
    %orig;
    if (!self.window) {
        self.backgroundColor = nil;
        gBackgroundColor = nil;
        gMenuColor = nil;
        gEarlyFadeStarted = NO;
    }
}
%end

// ── Action list card tint ─────────────────────────────────────────────────────
// iOS 13/14 used _UIContextMenuActionsListView; iOS 15/16 renamed it to
// _UIContextMenuListView. We hook both so the tweak works across versions.
%hook _UIContextMenuListView
- (void)didMoveToWindow {
    %orig;
    if (!self.window || !FinnBool(kKeyEnabled, NO) || !FinnBool(kKeyMenuEnabled, YES) || !gMenuColor) return;
    UIColor *color = gMenuColor;
    dispatch_async(dispatch_get_main_queue(), ^{
        FinnTintViewTree(self, color, 8);
    });
}
- (void)layoutSubviews {
    %orig;
    if (!self.window || !FinnBool(kKeyEnabled, NO) || !FinnBool(kKeyMenuEnabled, YES) || !gMenuColor) return;
    FinnTintViewTree(self, gMenuColor, 8);
}
%end

// Fallback for iOS 13/14.
%hook _UIContextMenuActionsListView
- (void)didMoveToWindow {
    %orig;
    if (!self.window || !FinnBool(kKeyEnabled, NO) || !FinnBool(kKeyMenuEnabled, YES) || !gMenuColor) return;
    UIColor *color = gMenuColor;
    dispatch_async(dispatch_get_main_queue(), ^{
        FinnTintViewTree(self, color, 8);
    });
}
- (void)layoutSubviews {
    %orig;
    if (!self.window || !FinnBool(kKeyEnabled, NO) || !FinnBool(kKeyMenuEnabled, YES) || !gMenuColor) return;
    FinnTintViewTree(self, gMenuColor, 8);
}
%end

%hook SBHIconManager
- (void)setEditing:(BOOL)editing {
    if (editing) { gBackgroundColor = nil; gMenuColor = nil; }
    %orig;
}
%end

%end // group Finn

%ctor {
    if (![[[NSBundle mainBundle] bundleIdentifier]
            isEqualToString:@"com.apple.springboard"]) return;
    %init(Finn);
}
