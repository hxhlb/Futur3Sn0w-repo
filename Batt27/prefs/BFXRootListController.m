#import "BFXRootListController.h"
#import <notify.h>

static NSString * const kBFXPrefsDomain = @"com.futur3sn0w.battfx.preferences";
static NSString * const kBFXReloadNotification = @"com.futur3sn0w.battfx/ReloadPrefs";

@interface PSSpecifier (BattFXPrivate)
- (void)setValues:(NSArray *)values titles:(NSArray *)titles;
@end

@implementation BFXRootListController

- (PSSpecifier *)groupSpecifierWithName:(NSString *)name footer:(NSString *)footerText {
	PSSpecifier *specifier = [PSSpecifier emptyGroupSpecifier];
	if (name.length > 0) {
		[specifier setProperty:name forKey:@"label"];
	}
	if (footerText.length > 0) {
		[specifier setProperty:footerText forKey:@"footerText"];
	}
	return specifier;
}

- (PSSpecifier *)switchSpecifierWithName:(NSString *)name key:(NSString *)key defaultValue:(BOOL)defaultValue {
	PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:name
		target:self
		set:@selector(setPreferenceValue:specifier:)
		get:@selector(readPreferenceValue:)
		detail:Nil
		cell:PSSwitchCell
		edit:Nil];
	[specifier setProperty:kBFXPrefsDomain forKey:@"defaults"];
	[specifier setProperty:key forKey:@"key"];
	[specifier setProperty:@(defaultValue) forKey:@"default"];
	[specifier setProperty:kBFXReloadNotification forKey:@"PostNotification"];
	return specifier;
}

- (PSSpecifier *)segmentSpecifierWithKey:(NSString *)key defaultValue:(NSInteger)defaultValue {
	PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:nil
		target:self
		set:@selector(setPreferenceValue:specifier:)
		get:@selector(readPreferenceValue:)
		detail:Nil
		cell:PSSegmentCell
		edit:Nil];
	[specifier setProperty:kBFXPrefsDomain forKey:@"defaults"];
	[specifier setProperty:key forKey:@"key"];
	[specifier setProperty:key forKey:@"id"];
	[specifier setProperty:@(defaultValue) forKey:@"default"];
	[specifier setValues:@[@0, @1, @2] titles:@[@"Modern", @"Juice", @"Sammy"]];
	[specifier setProperty:kBFXReloadNotification forKey:@"PostNotification"];
	return specifier;
}

- (BOOL)isGloballyEnabled {
	id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)@"Enabled", (__bridge CFStringRef)kBFXPrefsDomain));
	return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : YES;
}

- (void)updateChildSpecifierAvailability {
	BOOL enabled = [self isGloballyEnabled];
	for (PSSpecifier *specifier in _specifiers) {
		NSString *key = [specifier propertyForKey:@"key"];
		if (key.length == 0 || [key isEqualToString:@"Enabled"]) {
			continue;
		}

		[specifier setProperty:@(enabled) forKey:PSEnabledKey];
	}
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	id defaultValue = [specifier propertyForKey:@"default"];
	id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)kBFXPrefsDomain));
	return value ?: defaultValue;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)kBFXPrefsDomain);
	CFPreferencesAppSynchronize((__bridge CFStringRef)kBFXPrefsDomain);
	notify_post([kBFXReloadNotification UTF8String]);

	if ([key isEqualToString:@"Enabled"]) {
		[self updateChildSpecifierAvailability];
		[self reloadSpecifiers];
	}
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [@[
			[self groupSpecifierWithName:nil footer:@"Styles the battery indicator systemwide."],
			[self switchSpecifierWithName:@"Enabled" key:@"Enabled" defaultValue:YES],
			[self groupSpecifierWithName:@"Style" footer:@"Modern: max safe stock-like rounding.\nJuice: full pill with nub.\nSammy: full pill without nub."],
			[self segmentSpecifierWithKey:@"Style" defaultValue:1]
		] mutableCopy];
		[self updateChildSpecifierAvailability];
	}

	return _specifiers;
}

@end
