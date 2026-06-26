#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const kSCPrefsDomain;
FOUNDATION_EXPORT NSString * const kSCReloadNotification;
FOUNDATION_EXPORT NSString * const kSCDetectedRootModeKey;
FOUNDATION_EXPORT NSString * const kSCDetectedGroupIdentifiersKey;

FOUNDATION_EXPORT NSArray<NSDictionary<NSString *, NSString *> *> *SCMajorGroupDefinitions(void);
FOUNDATION_EXPORT NSString *SCFriendlyTitleForGroupIdentifier(NSString *groupIdentifier);
FOUNDATION_EXPORT NSString *SCPreferenceKeyForGroupIdentifier(NSString *groupIdentifier);
FOUNDATION_EXPORT BOOL SCIsKnownMajorGroupIdentifier(NSString *groupIdentifier);
FOUNDATION_EXPORT BOOL SCIsCollapsibleGroupIdentifier(NSString *groupIdentifier);
FOUNDATION_EXPORT NSArray<NSString *> *SCDisplayableGroupIdentifiersFromDetectedGroups(NSArray<NSString *> *detectedGroups);
