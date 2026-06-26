#import "SCCommon.h"

NSString * const kSCPrefsDomain = @"com.futur3sn0w.resettings.preferences";
NSString * const kSCReloadNotification = @"com.futur3sn0w.resettings/ReloadPrefs";
NSString * const kSCDetectedRootModeKey = @"DetectedRootMode";
NSString * const kSCDetectedGroupIdentifiersKey = @"DetectedGroupIdentifiers";

NSArray<NSDictionary<NSString *, NSString *> *> *SCMajorGroupDefinitions(void) {
	static NSArray<NSDictionary<NSString *, NSString *> *> *definitions = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		definitions = @[
			@{@"identifier": @"SHUFFLE_GROUP", @"title": @"Apps"},
			@{@"identifier": @"PRIMARY_APPLE_ACCOUNT_GROUP", @"title": @"Apple Account"},
			@{@"identifier": @"DEVICE_TYPE_GROUP_ID", @"title": @"Device Type"},
			@{@"identifier": @"WIRELESS_GROUP", @"title": @"Wireless"},
			@{@"identifier": @"NOTIFICATIONS_GROUP_ID", @"title": @"Notifications"},
			@{@"identifier": @"GENERAL_GROUP", @"title": @"General"},
			@{@"identifier": @"APPLE_ACCOUNT_GROUP", @"title": @"Apple Account Services"},
			@{@"identifier": @"ACCOUNTS_GROUP", @"title": @"Accounts"},
			@{@"identifier": @"MEDIA_GROUP", @"title": @"Media"},
			@{@"identifier": @"VIDEO_SUBSCRIBER_GROUP", @"title": @"Video Subscriber"},
			@{@"identifier": @"THIRD_PARTY_GROUP", @"title": @"Third Party"},
		];
	});
	return definitions;
}

NSString *SCFriendlyTitleForGroupIdentifier(NSString *groupIdentifier) {
	if (groupIdentifier.length == 0) {
		return @"";
	}

	for (NSDictionary<NSString *, NSString *> *definition in SCMajorGroupDefinitions()) {
		if ([definition[@"identifier"] isEqualToString:groupIdentifier]) {
			return definition[@"title"] ?: @"";
		}
	}

	if ([groupIdentifier rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound) {
		return @"";
	}

	NSString *title = [groupIdentifier stringByReplacingOccurrencesOfString:@"_GROUP_ID" withString:@""];
	title = [title stringByReplacingOccurrencesOfString:@"_GROUP" withString:@""];
	title = [title stringByReplacingOccurrencesOfString:@"_" withString:@" "];
	title = title.lowercaseString.capitalizedString;
	return title;
}

NSString *SCPreferenceKeyForGroupIdentifier(NSString *groupIdentifier) {
	if (groupIdentifier.length == 0) {
		return @"";
	}

	return [NSString stringWithFormat:@"Group_%@", groupIdentifier];
}

BOOL SCIsKnownMajorGroupIdentifier(NSString *groupIdentifier) {
	return SCFriendlyTitleForGroupIdentifier(groupIdentifier).length > 0;
}

BOOL SCIsCollapsibleGroupIdentifier(NSString *groupIdentifier) {
	if (!SCIsKnownMajorGroupIdentifier(groupIdentifier)) {
		return NO;
	}

	if ([groupIdentifier isEqualToString:@"PRIMARY_APPLE_ACCOUNT_GROUP"]) {
		return NO;
	}

	return YES;
}

NSArray<NSString *> *SCDisplayableGroupIdentifiersFromDetectedGroups(NSArray<NSString *> *detectedGroups) {
	NSMutableOrderedSet<NSString *> *ordered = [NSMutableOrderedSet orderedSet];

	for (NSString *identifier in detectedGroups) {
		if (![identifier isKindOfClass:[NSString class]]) {
			continue;
		}

		if (SCIsCollapsibleGroupIdentifier(identifier)) {
			[ordered addObject:identifier];
		}
	}

	if (ordered.count > 0) {
		return ordered.array;
	}

	for (NSDictionary<NSString *, NSString *> *definition in SCMajorGroupDefinitions()) {
		NSString *identifier = definition[@"identifier"];
		if (identifier.length > 0 && SCIsCollapsibleGroupIdentifier(identifier) && ![identifier isEqualToString:@"SHUFFLE_GROUP"]) {
			[ordered addObject:identifier];
		}
	}

	return ordered.array;
}
