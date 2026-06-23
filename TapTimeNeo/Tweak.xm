#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface _UIStatusBarStringView : UIView
- (NSString *)text;
- (void)setText:(NSString *)text;
- (NSString *)originalText;
- (void)setOriginalText:(NSString *)text;
- (NSString *)alternateText;
- (void)setAlternateText:(NSString *)text;
- (void)setShowsAlternateText:(BOOL)showsAlternateText;
@end

static const void *kTTNLatestClockTextKey = &kTTNLatestClockTextKey;
static const void *kTTNDisplayTimerKey = &kTTNDisplayTimerKey;
static const void *kTTNShowingDateKey = &kTTNShowingDateKey;
static const void *kTTNSuppressInterceptionKey = &kTTNSuppressInterceptionKey;
static const void *kTTNContainerTapRecognizerKey = &kTTNContainerTapRecognizerKey;
static const void *kTTNActiveClockViewKey = &kTTNActiveClockViewKey;

static NSString *TTNCurrentDateString(void) {
	static NSDateFormatter *formatter = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		formatter = [[NSDateFormatter alloc] init];
		formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
		formatter.timeZone = [NSTimeZone localTimeZone];
		formatter.dateFormat = @"MM/dd";
	});

	return [formatter stringFromDate:[NSDate date]];
}

static NSString *TTNNormalizedString(NSString *string) {
	if (![string isKindOfClass:[NSString class]]) {
		return nil;
	}

	NSString *normalized = [string stringByReplacingOccurrencesOfString:@"\u200e" withString:@""];
	normalized = [normalized stringByReplacingOccurrencesOfString:@"\u200f" withString:@""];
	return [normalized stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL TTNLooksLikeTimeString(NSString *string) {
	NSString *normalized = TTNNormalizedString(string);
	if (normalized.length < 4 || normalized.length > 12) {
		return NO;
	}

	NSRange colonRange = [normalized rangeOfString:@":"];
	if (colonRange.location == NSNotFound) {
		return NO;
	}

	static NSRegularExpression *expression = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		expression = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]{1,2}:[0-9]{2}([[:space:]]?[AP]M)?$" options:NSRegularExpressionCaseInsensitive error:nil];
	});

	return [expression numberOfMatchesInString:normalized options:0 range:NSMakeRange(0, normalized.length)] > 0;
}

static BOOL TTNBoolForKey(id object, const void *key) {
	return [objc_getAssociatedObject(object, key) boolValue];
}

static void TTNSetBoolForKey(id object, const void *key, BOOL value) {
	objc_setAssociatedObject(object, key, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void TTNSetTextBypassingHook(_UIStatusBarStringView *view, NSString *text) {
	if (view == nil) {
		return;
	}

	TTNSetBoolForKey(view, kTTNSuppressInterceptionKey, YES);
	[view setText:text];
	TTNSetBoolForKey(view, kTTNSuppressInterceptionKey, NO);
}

static _UIStatusBarStringView *TTNActiveClockViewForContainer(UIView *container) {
	return objc_getAssociatedObject(container, kTTNActiveClockViewKey);
}

static void TTNSetActiveClockViewForContainer(UIView *container, _UIStatusBarStringView *view) {
	if (container == nil) {
		return;
	}

	objc_setAssociatedObject(container, kTTNActiveClockViewKey, view, OBJC_ASSOCIATION_ASSIGN);
}

static NSString *TTNPreferredClockText(_UIStatusBarStringView *view) {
	NSString *text = TTNNormalizedString([view text]);
	if (text.length > 0) {
		return text;
	}

	if ([view respondsToSelector:@selector(originalText)]) {
		NSString *originalText = TTNNormalizedString([view originalText]);
		if (originalText.length > 0) {
			return originalText;
		}
	}

	return nil;
}

static BOOL TTNClassNameContains(id object, const char *fragment) {
	if (object == nil || fragment == NULL) {
		return NO;
	}

	const char *className = object_getClassName(object);
	return className != NULL && strstr(className, fragment) != NULL;
}

static UIView *TTNTapContainerForClockView(_UIStatusBarStringView *view) {
	for (UIView *ancestor = view.superview; ancestor != nil; ancestor = ancestor.superview) {
		if (TTNClassNameContains(ancestor, "_UIStatusBarForegroundView") ||
			TTNClassNameContains(ancestor, "_UIStatusBar") ||
			TTNClassNameContains(ancestor, "UIStatusBar_Modern")) {
			return ancestor;
		}
	}

	return view.superview ?: view;
}

static BOOL TTNIsUsableClockView(_UIStatusBarStringView *view) {
	if (view == nil || view.window == nil || view.hidden || view.alpha <= 0.01) {
		return NO;
	}

	if (CGRectIsEmpty(view.bounds) || CGRectIsEmpty(view.frame)) {
		return NO;
	}

	return TTNLooksLikeTimeString(TTNPreferredClockText(view));
}

@interface TTNTapGestureHandler : NSObject <UIGestureRecognizerDelegate>
+ (instancetype)sharedInstance;
- (void)handleTap:(UITapGestureRecognizer *)gesture;
@end

static void TTNInvalidateTimer(_UIStatusBarStringView *view) {
	NSTimer *timer = objc_getAssociatedObject(view, kTTNDisplayTimerKey);
	if (timer != nil) {
		[timer invalidate];
		objc_setAssociatedObject(view, kTTNDisplayTimerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
}

static void TTNRevertToClock(_UIStatusBarStringView *view, BOOL animated) {
	if (view == nil) {
		return;
	}

	TTNInvalidateTimer(view);
	TTNSetBoolForKey(view, kTTNShowingDateKey, NO);

	NSString *clockText = objc_getAssociatedObject(view, kTTNLatestClockTextKey);
	if (clockText.length == 0) {
		clockText = [view text];
	}

	void (^applyClockText)(void) = ^{
		if ([view respondsToSelector:@selector(setShowsAlternateText:)]) {
			[view setShowsAlternateText:NO];
		} else {
			TTNSetTextBypassingHook(view, clockText);
		}
	};

	if (!animated || view.window == nil) {
		applyClockText();
		view.alpha = 1.0;
		return;
	}

	[UIView animateWithDuration:0.15 animations:^{
		view.alpha = 0.0;
	} completion:^(__unused BOOL finished) {
		applyClockText();
		[UIView animateWithDuration:0.18 animations:^{
			view.alpha = 1.0;
		}];
	}];
}

static void TTNStartRevertTimer(_UIStatusBarStringView *view) {
	TTNInvalidateTimer(view);

	__weak _UIStatusBarStringView *weakView = view;
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:5.0 repeats:NO block:^(__unused NSTimer *timer) {
		_UIStatusBarStringView *strongView = weakView;
		if (strongView != nil) {
			TTNRevertToClock(strongView, YES);
		}
	}];

	objc_setAssociatedObject(view, kTTNDisplayTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void TTNShowDate(_UIStatusBarStringView *view) {
	if (view == nil) {
		return;
	}

	NSString *currentText = TTNNormalizedString([view text]);
	if (TTNLooksLikeTimeString(currentText)) {
		objc_setAssociatedObject(view, kTTNLatestClockTextKey, currentText, OBJC_ASSOCIATION_COPY_NONATOMIC);
	}

	TTNSetBoolForKey(view, kTTNShowingDateKey, YES);
	NSString *dateString = TTNCurrentDateString();

	if (view.window == nil) {
		if ([view respondsToSelector:@selector(setAlternateText:)] && [view respondsToSelector:@selector(setShowsAlternateText:)]) {
			[view setAlternateText:dateString];
			[view setShowsAlternateText:YES];
		} else {
			TTNSetTextBypassingHook(view, dateString);
		}
		view.alpha = 1.0;
		TTNStartRevertTimer(view);
		return;
	}

	[UIView animateWithDuration:0.15 animations:^{
		view.alpha = 0.0;
	} completion:^(__unused BOOL finished) {
		if ([view respondsToSelector:@selector(setAlternateText:)] && [view respondsToSelector:@selector(setShowsAlternateText:)]) {
			[view setAlternateText:dateString];
			[view setShowsAlternateText:YES];
			view.alpha = 1.0;
		} else {
			TTNSetTextBypassingHook(view, dateString);
			[UIView animateWithDuration:0.18 animations:^{
				view.alpha = 1.0;
			}];
		}
		TTNStartRevertTimer(view);
	}];
}

@implementation TTNTapGestureHandler

+ (instancetype)sharedInstance {
	static TTNTapGestureHandler *handler = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		handler = [[self alloc] init];
	});
	return handler;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
	UIView *container = gestureRecognizer.view;
	if (![container isKindOfClass:[UIView class]]) {
		return NO;
	}

	_UIStatusBarStringView *view = TTNActiveClockViewForContainer(container);
	if (![view isKindOfClass:objc_getClass("_UIStatusBarStringView")] || view.hidden || view.alpha <= 0.01) {
		return NO;
	}

	CGPoint location = [touch locationInView:container];
	CGRect viewFrameInContainer = [view convertRect:view.bounds toView:container];
	return CGRectContainsPoint(CGRectInset(viewFrameInContainer, -12.0, -8.0), location);
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
	if (gesture.state != UIGestureRecognizerStateEnded) {
		return;
	}

	UIView *container = gesture.view;
	if (![container isKindOfClass:[UIView class]]) {
		return;
	}

	_UIStatusBarStringView *view = TTNActiveClockViewForContainer(container);
	if (![view isKindOfClass:objc_getClass("_UIStatusBarStringView")] || view.hidden || view.alpha <= 0.01) {
		return;
	}

	if (TTNBoolForKey(view, kTTNShowingDateKey)) {
		TTNRevertToClock(view, YES);
	} else {
		TTNShowDate(view);
	}
}

@end

static void TTNEnsureContainerTapRecognizer(_UIStatusBarStringView *view) {
	UIView *container = TTNTapContainerForClockView(view);
	if (container == nil) {
		return;
	}

	if (!TTNBoolForKey(container, kTTNContainerTapRecognizerKey)) {
		container.userInteractionEnabled = YES;
		UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:[TTNTapGestureHandler sharedInstance] action:@selector(handleTap:)];
		tapRecognizer.numberOfTapsRequired = 1;
		tapRecognizer.cancelsTouchesInView = NO;
		tapRecognizer.delegate = [TTNTapGestureHandler sharedInstance];
		[container addGestureRecognizer:tapRecognizer];
		TTNSetBoolForKey(container, kTTNContainerTapRecognizerKey, YES);
	}

	TTNSetActiveClockViewForContainer(container, view);
}

%hook _UIStatusBarStringView

- (void)didMoveToWindow {
	%orig;

	if (TTNIsUsableClockView(self)) {
		TTNEnsureContainerTapRecognizer(self);
	}
}

- (void)layoutSubviews {
	%orig;

	if (TTNIsUsableClockView(self)) {
		TTNEnsureContainerTapRecognizer(self);
	}
}

- (void)setText:(NSString *)text {
	if (TTNBoolForKey(self, kTTNSuppressInterceptionKey)) {
		%orig(text);
		return;
	}

	if (TTNLooksLikeTimeString(text)) {
		NSString *normalized = TTNNormalizedString(text);
		if (normalized.length > 0) {
			objc_setAssociatedObject(self, kTTNLatestClockTextKey, normalized, OBJC_ASSOCIATION_COPY_NONATOMIC);
		}

		TTNEnsureContainerTapRecognizer(self);

		if (TTNBoolForKey(self, kTTNShowingDateKey)) {
			if ([self respondsToSelector:@selector(setAlternateText:)] && [self respondsToSelector:@selector(setShowsAlternateText:)]) {
				[self setAlternateText:TTNCurrentDateString()];
				%orig(text);
			} else {
				%orig(TTNCurrentDateString());
			}
			return;
		}
	}

	%orig(text);
}

- (void)setOriginalText:(NSString *)text {
	%orig(text);

	if (TTNLooksLikeTimeString(text)) {
		NSString *normalized = TTNNormalizedString(text);
		if (normalized.length > 0) {
			objc_setAssociatedObject(self, kTTNLatestClockTextKey, normalized, OBJC_ASSOCIATION_COPY_NONATOMIC);
		}

		if (TTNIsUsableClockView(self)) {
			TTNEnsureContainerTapRecognizer(self);
		}
	}
}

%end
