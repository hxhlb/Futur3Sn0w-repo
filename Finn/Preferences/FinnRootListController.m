#import "FinnRootListController.h"
#include <spawn.h>

static NSString * const kFinnPrefsID = @"com.futur3sn0w.finn";

@implementation FinnRootListController

- (NSArray *)specifiers {
    if (!_specifiers)
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    return _specifiers;
}

- (void)respring {
    UIView *snapshot = [[UIScreen mainScreen] snapshotViewAfterScreenUpdates:NO];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[[UIApplication sharedApplication].windows firstObject] addSubview:snapshot];
#pragma clang diagnostic pop
    [UIView animateWithDuration:0.4 animations:^{
        snapshot.alpha = 0;
    } completion:^(BOOL done) {
        pid_t pid;
        const char *args[] = {"killall", "-9", "SpringBoard", NULL};
        posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char **)args, NULL);
    }];
}

@end
