#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const MFPrefsDomain = @"com.futur3sn0w.muteflash.preferences";
static NSString *const MFReason = @"com.futur3sn0w.muteflash";
static CFTimeInterval MFLastHandledTime = 0;

static BOOL MFEnabled(void) {
	Boolean valid = false;
	Boolean value = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)@"Enabled", (__bridge CFStringRef)MFPrefsDomain, &valid);
	return valid ? (BOOL)value : YES;
}

static id MFSharedFlashlightController(void) {
	Class cls = objc_getClass("SBUIFlashlightController");
	if (!cls || ![(id)cls respondsToSelector:@selector(sharedInstance)]) {
		return nil;
	}

	id (*sendSharedInstance)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
	return sendSharedInstance((id)cls, @selector(sharedInstance));
}

static BOOL MFBoolResult(id target, SEL selector, BOOL defaultValue) {
	if (!target || ![target respondsToSelector:selector]) {
		return defaultValue;
	}

	BOOL (*sendBool)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
	return sendBool(target, selector);
}

static NSUInteger MFUnsignedResult(id target, SEL selector, NSUInteger defaultValue) {
	if (!target || ![target respondsToSelector:selector]) {
		return defaultValue;
	}

	NSUInteger (*sendUnsigned)(id, SEL) = (NSUInteger (*)(id, SEL))objc_msgSend;
	return sendUnsigned(target, selector);
}

static void MFSendReasonCommand(id target, SEL selector) {
	void (*sendCommand)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
	sendCommand(target, selector, MFReason);
}

static void MFSetFlashlight(BOOL wantsOn, id controller) {
	BOOL isAvailable = MFBoolResult(controller, @selector(isAvailable), YES);
	BOOL isOverheated = MFBoolResult(controller, @selector(isOverheated), NO);

	if (!isAvailable || isOverheated) {
		return;
	}

	@try {
		if (wantsOn) {
			SEL selector = NSSelectorFromString(@"turnFlashlightOnForReason:");
			if ([controller respondsToSelector:selector]) {
				MFSendReasonCommand(controller, selector);
			} else if ([controller respondsToSelector:@selector(setLevel:)]) {
				void (*setLevel)(id, SEL, NSUInteger) = (void (*)(id, SEL, NSUInteger))objc_msgSend;
				setLevel(controller, @selector(setLevel:), 1);
			}
		} else {
			SEL selector = NSSelectorFromString(@"turnFlashlightOffForReason:");
			if ([controller respondsToSelector:selector]) {
				MFSendReasonCommand(controller, selector);
			} else if ([controller respondsToSelector:@selector(setLevel:)]) {
				void (*setLevel)(id, SEL, NSUInteger) = (void (*)(id, SEL, NSUInteger))objc_msgSend;
				setLevel(controller, @selector(setLevel:), 0);
			}
		}
	} @catch (NSException *exception) {
	}
}

static void MFToggleFlashlight(void) {
	id controller = MFSharedFlashlightController();
	if (!controller) {
		return;
	}

	NSUInteger currentLevel = MFUnsignedResult(controller, @selector(level), 0);
	BOOL wantsOn = currentLevel == 0;
	MFSetFlashlight(wantsOn, controller);
}

%hook SpringBoard

- (void)_ringerChanged:(void *)event {
	if (!MFEnabled()) {
		%orig(event);
		return;
	}

	CFTimeInterval now = CFAbsoluteTimeGetCurrent();
	CFTimeInterval elapsed = now - MFLastHandledTime;

	if (elapsed >= 0.35) {
		MFLastHandledTime = now;
		MFToggleFlashlight();
	}
}

%end
