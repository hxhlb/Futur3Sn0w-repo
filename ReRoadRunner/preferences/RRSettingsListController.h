#import <Preferences/Preferences.h>
#import "../SettingsKeys.h"

@interface RRSettingsListController : PSListController
- (void)respring;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)savePreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
- (void)setEnabled:(BOOL)enabled forSpecifierWithID:(NSString *)identifier;
- (void)setEnabled:(BOOL)enabled forSpecifier:(PSSpecifier *)specifier;
@end
