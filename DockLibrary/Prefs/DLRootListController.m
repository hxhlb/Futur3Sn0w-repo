#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <notify.h>

@interface DLRootListController : PSListController
@end

@implementation DLRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}
	return _specifiers;
}

- (void)respring {
	notify_post("com.futur3sn0w.docklibrary.respring");
}

@end
