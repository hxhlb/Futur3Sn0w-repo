#import "MFPRootListController.h"
#import <spawn.h>

static NSString * const kMFPPrefsDomain = @"com.futur3sn0w.muteflash.preferences";
extern char **environ;

@implementation MFPRootListController

static BOOL gMFPNeedsRespring = NO;

- (PSSpecifier *)groupSpecifierWithFooter:(NSString *)footerText {
	PSSpecifier *specifier = [PSSpecifier emptyGroupSpecifier];
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
	[specifier setProperty:kMFPPrefsDomain forKey:@"defaults"];
	[specifier setProperty:key forKey:@"key"];
	[specifier setProperty:@(defaultValue) forKey:@"default"];
	return specifier;
}

- (void)updateRespringButton {
	if (gMFPNeedsRespring) {
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
	Boolean value = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)key, (__bridge CFStringRef)kMFPPrefsDomain, &valid);
	return valid ? @(value) : defaultValue;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)kMFPPrefsDomain);
	CFPreferencesAppSynchronize((__bridge CFStringRef)kMFPPrefsDomain);

	gMFPNeedsRespring = YES;
	[self updateRespringButton];
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [@[
			[self groupSpecifierWithFooter:@"When enabled, the hardware ringer switch toggles the flashlight and does not change silent mode."],
			[self switchSpecifierWithName:@"Enabled" key:@"Enabled" defaultValue:YES],
			[self groupSpecifierWithFooter:@"To choose which physical switch direction turns the flashlight on, flip the hardware switch, then toggle the flashlight in Control Center."]
		] mutableCopy];
	}

	return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self updateRespringButton];
}

@end
