#import "NSPRootListController.h"
#import <notify.h>
#import <spawn.h>

static NSString * const kNSPrefsDomain = @"com.futur3sn0w.noseparators.preferences";
static NSString * const kNSReloadNotification = @"com.futur3sn0w.noseparators/ReloadPrefs";
extern char **environ;

@implementation NSPRootListController

static BOOL gNSNeedsRespring = NO;

- (NSString *)prefsPath {
	return @"/var/mobile/Library/Preferences/com.futur3sn0w.noseparators.preferences.plist";
}

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
	[specifier setProperty:kNSPrefsDomain forKey:@"defaults"];
	[specifier setProperty:key forKey:@"key"];
	[specifier setProperty:@(defaultValue) forKey:@"default"];
	[specifier setProperty:kNSReloadNotification forKey:@"PostNotification"];
	return specifier;
}

- (BOOL)isGloballyEnabled {
	Boolean valid = false;
	Boolean value = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)@"Enabled", (__bridge CFStringRef)kNSPrefsDomain, &valid);
	return valid ? (BOOL)value : YES;
}

- (void)updateChildToggleAvailability {
	BOOL enabled = [self isGloballyEnabled];
	for (PSSpecifier *specifier in _specifiers) {
		NSString *key = [specifier propertyForKey:@"key"];
		if (key.length == 0 || [key isEqualToString:@"Enabled"]) {
			continue;
		}

		[specifier setProperty:@(enabled) forKey:PSEnabledKey];
	}
}

- (void)updateRespringButton {
	if (gNSNeedsRespring) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Respring"
			style:UIBarButtonItemStyleDone
			target:self
			action:@selector(respring)];
		return;
	}

	self.navigationItem.rightBarButtonItem = nil;
}

- (void)respring {
	pid_t pid;
	const char *args[] = {"killall", "-9", "SpringBoard", NULL};
	posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args, environ);
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	id defaultValue = [specifier propertyForKey:@"default"];
	Boolean valid = false;
	Boolean value = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)key, (__bridge CFStringRef)kNSPrefsDomain, &valid);
	return valid ? @(value) : defaultValue;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)kNSPrefsDomain);
	CFPreferencesAppSynchronize((__bridge CFStringRef)kNSPrefsDomain);
	notify_post([kNSReloadNotification UTF8String]);

	gNSNeedsRespring = YES;
	if ([key isEqualToString:@"Enabled"]) {
		[self updateChildToggleAvailability];
		[self reloadSpecifiers];
	}
	[self updateRespringButton];
}

- (NSArray *)specifiers {
	if (!_specifiers) {
			_specifiers = [@[
				[self groupSpecifierWithName:nil footer:@"Enables globally; disable individual elements below."],
				[self switchSpecifierWithName:@"Enabled" key:@"Enabled" defaultValue:YES],
				[self groupSpecifierWithName:@"Affected Areas" footer:nil],
				[self switchSpecifierWithName:@"Hide Table Separators" key:@"HideTableSeparators" defaultValue:YES],
				[self switchSpecifierWithName:@"Hide Tab Bar Top Border" key:@"HideTabBarTopBorder" defaultValue:NO],
				[self switchSpecifierWithName:@"Hide Header Bar Bottom Border" key:@"HideNavigationBarBottomBorder" defaultValue:NO],
				[self groupSpecifierWithName:nil footer:@"Respring to apply globally."]
			] mutableCopy];
		[self updateChildToggleAvailability];
	}

	return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self updateRespringButton];
}

@end
