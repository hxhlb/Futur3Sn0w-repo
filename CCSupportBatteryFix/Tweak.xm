#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>

static CFStringRef const CSBFSpringBoardPreferencesDomain = CFSTR("com.apple.springboard");

static BOOL CSBFBatteryPercentageEnabled(void) {
	CFPropertyListRef value = CFPreferencesCopyValue(CFSTR("SBShowBatteryPercentage"), CSBFSpringBoardPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	id bridgedValue = CFBridgingRelease(value);
	if ([bridgedValue respondsToSelector:@selector(boolValue)]) {
		return [bridgedValue boolValue];
	}

	return NO;
}

%group CSBFBatteryViewHooks
%hook _UIBatteryView

- (void)setShowsPercentage:(BOOL)showsPercentage {
	%orig(showsPercentage || CSBFBatteryPercentageEnabled());
}

%end
%end

%ctor {
	Class batteryViewClass = objc_getClass("_UIBatteryView");
	if (batteryViewClass && class_getInstanceMethod(batteryViewClass, @selector(setShowsPercentage:))) {
		%init(CSBFBatteryViewHooks);
	}
}
