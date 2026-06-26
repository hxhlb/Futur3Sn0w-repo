#import "SCRootListController.h"

#import <Preferences/PSSpecifier.h>
#import <notify.h>
#import <spawn.h>

#import "../SCCommon.h"

extern char **environ;

@interface SCRootListController ()

@property (nonatomic, assign) BOOL needsApply;

@end

@implementation SCRootListController

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
	[specifier setProperty:kSCPrefsDomain forKey:@"defaults"];
	[specifier setProperty:key forKey:@"key"];
	[specifier setProperty:@(defaultValue) forKey:@"default"];
	return specifier;
}

- (BOOL)isGloballyEnabled {
	Boolean valid = false;
	Boolean value = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)@"Enabled", (__bridge CFStringRef)kSCPrefsDomain, &valid);
	return valid ? (BOOL)value : YES;
}

- (void)updateGroupAvailability {
	BOOL enabled = [self isGloballyEnabled];
	for (PSSpecifier *specifier in _specifiers) {
		NSString *key = [specifier propertyForKey:@"key"];
		if (key.length == 0 || [key isEqualToString:@"Enabled"]) {
			continue;
		}

		[specifier setProperty:@(enabled) forKey:PSEnabledKey];
	}
}

- (void)updateApplyButton {
	if (self.navigationItem.rightBarButtonItem == nil) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Apply"
			style:UIBarButtonItemStyleDone
			target:self
			action:@selector(applyChanges)];
	}

	self.navigationItem.rightBarButtonItem.enabled = self.needsApply;
}

- (void)applyChanges {
	if (!self.needsApply) {
		return;
	}

	notify_post(kSCReloadNotification.UTF8String);
	self.needsApply = NO;
	[self updateApplyButton];

	pid_t pid;
	const char *args[] = {"killall", "-9", "Preferences", NULL};
	posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args, environ);
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	id defaultValue = [specifier propertyForKey:@"default"];
	Boolean valid = false;
	Boolean value = CFPreferencesGetAppBooleanValue((__bridge CFStringRef)key, (__bridge CFStringRef)kSCPrefsDomain, &valid);
	return valid ? @(value) : defaultValue;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, (__bridge CFStringRef)kSCPrefsDomain);
	CFPreferencesAppSynchronize((__bridge CFStringRef)kSCPrefsDomain);

	self.needsApply = YES;
	if ([key isEqualToString:@"Enabled"]) {
		[self updateGroupAvailability];
		[self reloadSpecifiers];
	}
	[self updateApplyButton];
}

- (NSArray *)specifiers {
	if (_specifiers == nil) {
		NSMutableArray *specifiers = [NSMutableArray array];
		NSString *mode = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)kSCDetectedRootModeKey, (__bridge CFStringRef)kSCPrefsDomain));
		NSArray *detectedGroups = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)kSCDetectedGroupIdentifiersKey, (__bridge CFStringRef)kSCPrefsDomain));
		NSArray<NSString *> *displayGroups = SCDisplayableGroupIdentifiersFromDetectedGroups(detectedGroups);
		NSString *modeSummary = [mode isEqualToString:@"shuffle"] ? @"Shuffle-detected layout" : @"Stock layout";

		[specifiers addObject:[self groupSpecifierWithName:nil footer:[NSString stringWithFormat:@"Adds stable section labels now. Collapse behavior is still being hardened, so these switches currently mark which sections should become collapsible next. Current root detection: %@.", modeSummary]]];
		[specifiers addObject:[self switchSpecifierWithName:@"Enabled" key:@"Enabled" defaultValue:YES]];
		[specifiers addObject:[self groupSpecifierWithName:@"Collapsible Sections" footer:@"Changes are staged until you tap Apply. Apply will close Settings so the tweak can reload cleanly."]];

		for (NSString *identifier in displayGroups) {
			NSString *title = SCFriendlyTitleForGroupIdentifier(identifier);
			if (identifier.length == 0 || title.length == 0) {
				continue;
			}

			BOOL defaultValue = [identifier isEqualToString:@"MEDIA_GROUP"];
			[specifiers addObject:[self switchSpecifierWithName:title
				key:SCPreferenceKeyForGroupIdentifier(identifier)
				defaultValue:defaultValue]];
		}

		[specifiers addObject:[self groupSpecifierWithName:nil footer:@"ReSettings currently uses a deferred activation path because the Settings root page continues mutating briefly after launch on iOS 15/16."]];
		_specifiers = [specifiers mutableCopy];
		[self updateGroupAvailability];
	}

	return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	_specifiers = nil;
	[self reloadSpecifiers];
	[self updateApplyButton];
}

@end
