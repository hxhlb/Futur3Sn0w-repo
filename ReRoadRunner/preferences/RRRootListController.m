#import "../Common.h"
#import <UIKit/UIKit.h>
#import "RRSettingsListController.h"
#import <Preferences/Preferences.h>
#import <dlfcn.h>
#import "../SettingsKeys.h"
#import "RRAppListController.h"
#import "LocalizableKeys.h"

@interface PSSpecifier (RoadRunnerCompat)
- (void)setValues:(NSArray *)values titles:(NSArray *)titles;
@end

@interface RRRootListController : RRSettingsListController
@end

@implementation RRRootListController

- (NSArray *)specifiers {
    if (_specifiers)
        return _specifiers;

    NSMutableArray *specifiers = [NSMutableArray new];

    // --- Enabled ---
    PSSpecifier *specifier = [PSSpecifier groupSpecifierWithName:nil];
    [specifiers addObject:specifier];

    specifier = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:nil
                                                cell:PSSwitchCell
                                                edit:nil];
    [specifier setProperty:@YES forKey:@"default"];
    [specifier setProperty:kEnabled forKey:@"key"];
    [specifier setProperty:kEnabled forKey:@"id"];
    [specifier setProperty:@YES forKey:@"requiresRespring"];
    [specifiers addObject:specifier];

    // --- Mode ---
    PSSpecifier *modeGroup = [PSSpecifier groupSpecifierWithName:@"Mode"];
    [modeGroup setProperty:@"If \"Media apps\" is selected, only the now-playing app is kept alive through resprings. If \"Media & Other apps\" is selected, additional apps can be kept alive based on the whitelist or blacklist below."
                  forKey:@"footerText"];
    [specifiers addObject:modeGroup];

    PSSpecifier *modeSegment = [PSSpecifier preferenceSpecifierNamed:nil
                                                              target:self
                                                                 set:@selector(setPreferenceValue:specifier:)
                                                                 get:@selector(readPreferenceValue:)
                                                              detail:nil
                                                                cell:PSSegmentCell
                                                                edit:nil];
    [modeSegment setValues:@[@NO, @YES] titles:@[@"Media apps", @"Media & Other apps"]];
    [modeSegment setProperty:@NO forKey:@"default"];
    [modeSegment setProperty:kExcludeOtherApps forKey:@"key"];
    [modeSegment setProperty:kExcludeOtherApps forKey:@"id"];
    [modeSegment setProperty:@kSettingsChanged forKey:@"PostNotification"];
    [specifiers addObject:modeSegment];

    // --- Other Apps ---
    NSString *otherAppsFooter;
    PSSpecifier *otherAppsGroup = [PSSpecifier groupSpecifierWithName:@"Other Apps"];

    PSSpecifier *applistSpecifier = [PSSpecifier preferenceSpecifierNamed:@"Listed Apps"
                                                                   target:self
                                                                      set:@selector(setPreferenceValue:specifier:)
                                                                      get:@selector(readPreferenceValue:)
                                                                   detail:RRAppListController.class
                                                                     cell:PSLinkCell
                                                                     edit:nil];
    [applistSpecifier setProperty:kListedApps forKey:@"id"];

    if (dlopen("/var/jb/usr/lib/libapplist.dylib", RTLD_NOW) == NULL &&
        dlopen("/usr/lib/libapplist.dylib", RTLD_NOW) == NULL) {
        [applistSpecifier setProperty:@NO forKey:@"enabled"];
        otherAppsFooter = @"Whitelist: only listed apps will be kept alive.\n"
                           "Blacklist: all apps will be kept alive except listed ones.\n\n"
                           "Install AppList to configure the whitelist or blacklist.";
    } else {
        otherAppsFooter = @"Whitelist: only listed apps will be kept alive.\n"
                           "Blacklist: all apps will be kept alive except listed ones.";
    }
    [otherAppsGroup setProperty:otherAppsFooter forKey:@"footerText"];
    [specifiers addObject:otherAppsGroup];

    PSSpecifier *listTypeSegment = [PSSpecifier preferenceSpecifierNamed:nil
                                                                  target:self
                                                                     set:@selector(setPreferenceValue:specifier:)
                                                                     get:@selector(readPreferenceValue:)
                                                                  detail:nil
                                                                    cell:PSSegmentCell
                                                                    edit:nil];
    [listTypeSegment setValues:@[@YES, @NO] titles:@[@"Whitelist", @"Blacklist"]];
    [listTypeSegment setProperty:@YES forKey:@"default"];
    [listTypeSegment setProperty:kIsWhitelist forKey:@"key"];
    [listTypeSegment setProperty:kIsWhitelist forKey:@"id"];
    [listTypeSegment setProperty:@kSettingsChanged forKey:@"PostNotification"];
    [specifiers addObject:listTypeSegment];
    [specifiers addObject:applistSpecifier];

    // --- Respring ---
    PSSpecifier *respringGroup = [PSSpecifier groupSpecifierWithName:nil];
    [specifiers addObject:respringGroup];

    PSSpecifier *respringButton = [PSSpecifier preferenceSpecifierNamed:@"Respring"
                                                                target:self
                                                                   set:nil
                                                                   get:nil
                                                                detail:nil
                                                                  cell:PSButtonCell
                                                                  edit:nil];
    respringButton->action = @selector(respring);
    [specifiers addObject:respringButton];

    // --- Attribution ---
    PSSpecifier *attributionGroup = [PSSpecifier groupSpecifierWithName:nil];
    [attributionGroup setProperty:@"Original RoadRunner by Nosskirneh\nReRoadRunner (iOS 16 rootless rebuild) by futur3sn0w"
                          forKey:@"footerText"];
    [attributionGroup setProperty:@1 forKey:@"footerAlignment"]; // centered
    [specifiers addObject:attributionGroup];

    _specifiers = specifiers;
    return specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSString *key = [specifier propertyForKey:@"key"];

    if ([key isEqualToString:kExcludeOtherApps] && (!preferences[key] || ![preferences[key] boolValue])) {
        [super setEnabled:NO forSpecifierWithID:kListedApps];
        [super setEnabled:NO forSpecifierWithID:kIsWhitelist];
    }

    return [super readPreferenceValue:specifier];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:kExcludeOtherApps]) {
        BOOL enable = [value boolValue];
        [super setEnabled:enable forSpecifierWithID:kListedApps];
        [super setEnabled:enable forSpecifierWithID:kIsWhitelist];
    }
    [super setPreferenceValue:value specifier:specifier];
}

@end
