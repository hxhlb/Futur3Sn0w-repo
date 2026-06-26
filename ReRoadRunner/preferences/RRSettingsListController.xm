#import "RRSettingsListController.h"
#import <notify.h>
#import <objc/runtime.h>
#import <spawn.h>
#import "LocalizableKeys.h"

@interface FBSSystemService : NSObject
+ (id)sharedService;
- (void)sendActions:(NSSet *)actions withResult:(id)completion;
@end

@interface SBSRelaunchAction : NSObject
+ (id)actionWithReason:(NSString *)reason options:(int)options targetURL:(NSURL *)url;
@end

static void killProcess(const char *name) {
    pid_t pid;
    int status;
    const char *args[] = { "killall", "-9", name, NULL };
    posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args, NULL);
    waitpid(pid, &status, WEXITED);
}

static void doRespring(void) {
    if (objc_getClass("FBSSystemService")) {
        id action = [objc_getClass("SBSRelaunchAction") actionWithReason:@"RestartRenderServer"
                                                                  options:4  // FadeToBlackTransition
                                                                targetURL:nil];
        [[objc_getClass("FBSSystemService") sharedService] sendActions:[NSSet setWithObject:action]
                                                            withResult:nil];
    } else {
        killProcess("SpringBoard");
    }
}

@implementation RRSettingsListController

- (void)respring {
    killProcess("runningboardd");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        doRespring();
    });
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:kPrefPath];
    NSString *key = [specifier propertyForKey:@"key"];
    if (preferences[key])
        return preferences[key];
    return specifier.properties[@"default"];
}

- (void)savePreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSMutableDictionary *preferences = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefPath]
                                        ?: [NSMutableDictionary new];
    preferences[key] = value;
    [preferences writeToFile:kPrefPath atomically:YES];

    NSString *notification = specifier.properties[@"PostNotification"];
    if (notification)
        notify_post([notification UTF8String]);
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSNumber *requiresRespring = [specifier propertyForKey:@"requiresRespring"];
    if (requiresRespring && [requiresRespring boolValue]) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Restart Required"
                             message:@"This setting requires a respring to take effect."
                      preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:[UIAlertAction actionWithTitle:@"Respring Now"
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(UIAlertAction *a) {
            [self savePreferenceValue:value specifier:specifier];
            [self respring];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Later"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
            [self savePreferenceValue:value specifier:specifier];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    [self savePreferenceValue:value specifier:specifier];
}

- (void)setEnabled:(BOOL)enabled forSpecifierWithID:(NSString *)identifier {
    PSSpecifier *specifier = [self specifierForID:identifier];
    [self setEnabled:enabled forSpecifier:specifier];
}

- (void)setEnabled:(BOOL)enabled forSpecifier:(PSSpecifier *)specifier {
    if (!specifier)
        return;

    NSIndexPath *indexPath = [self indexPathForSpecifier:specifier];
    if (indexPath.row == NSNotFound)
        return;

    UITableViewCell *cell = [self tableView:self.table cellForRowAtIndexPath:indexPath];
    if (cell) {
        cell.userInteractionEnabled = enabled;
        cell.textLabel.enabled = enabled;
        cell.detailTextLabel.enabled = enabled;
        if ([cell isKindOfClass:[PSControlTableCell class]])
            ((PSControlTableCell *)cell).control.enabled = enabled;
    }
}

@end
