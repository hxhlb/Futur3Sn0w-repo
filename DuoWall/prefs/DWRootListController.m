#import "DWRootListController.h"
#import <Preferences/PSSpecifier.h>

static NSString * const DWStorageDirectory = @"/var/mobile/Library/Application Support/DuoWall";

@interface DWRootListController ()
@property (nonatomic, copy) NSString *pendingImageName;
@end

@implementation DWRootListController

- (NSString *)pathForImageName:(NSString *)name {
	return [DWStorageDirectory stringByAppendingPathComponent:name];
}

- (BOOL)hasImageNamed:(NSString *)name {
	return [[NSFileManager defaultManager] fileExistsAtPath:[self pathForImageName:name]];
}

- (PSSpecifier *)groupWithFooter:(NSString *)footer {
	PSSpecifier *specifier = [PSSpecifier emptyGroupSpecifier];
	[specifier setProperty:footer forKey:@"footerText"];
	return specifier;
}

- (PSSpecifier *)buttonNamed:(NSString *)name action:(SEL)action {
	PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:name
		target:self
		set:NULL
		get:NULL
		detail:Nil
		cell:PSButtonCell
		edit:Nil];
	specifier.buttonAction = action;
	return specifier;
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		NSString *lightStatus = [self hasImageNamed:@"Light.jpg"] ? @"Selected" : @"Not selected";
		NSString *darkStatus = [self hasImageNamed:@"Dark.jpg"] ? @"Selected" : @"Not selected";
		BOOL ready = [self hasImageNamed:@"Light.jpg"] && [self hasImageNamed:@"Dark.jpg"];
		NSString *footer = ready
			? @"Both images are ready. Open Wallpaper Settings, choose a new still wallpaper named DuoWall, and set it once. iOS will then follow every light and dark appearance change automatically."
			: @"Choose one image for each appearance. Your originals stay in Photos; DuoWall stores its own high-quality copies on the device.";

		_specifiers = [@[
			[self groupWithFooter:footer],
			[self buttonNamed:[NSString stringWithFormat:@"Choose Light Image  —  %@", lightStatus] action:@selector(chooseLightImage)],
			[self buttonNamed:[NSString stringWithFormat:@"Choose Dark Image  —  %@", darkStatus] action:@selector(chooseDarkImage)],
			[self groupWithFooter:@"After replacing either image, select DuoWall again so iOS refreshes its cached wallpaper copy."],
			[self buttonNamed:@"Open Wallpaper Settings" action:@selector(openWallpaperSettings)],
			[self buttonNamed:@"Reset Images" action:@selector(confirmReset)]
		] mutableCopy];
	}

	return _specifiers;
}

- (void)chooseLightImage {
	[self presentPickerForImageName:@"Light.jpg"];
}

- (void)chooseDarkImage {
	[self presentPickerForImageName:@"Dark.jpg"];
}

- (void)presentPickerForImageName:(NSString *)imageName {
	self.pendingImageName = imageName;
	PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
	configuration.filter = [PHPickerFilter imagesFilter];
	configuration.selectionLimit = 1;

	PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
	picker.delegate = self;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
	[picker dismissViewControllerAnimated:YES completion:nil];
	PHPickerResult *result = results.firstObject;
	NSString *imageName = self.pendingImageName;
	self.pendingImageName = nil;
	if (!result || imageName.length == 0) return;

	[result.itemProvider loadObjectOfClass:UIImage.class completionHandler:^(UIImage *image, NSError *error) {
		if (!image || error) {
			dispatch_async(dispatch_get_main_queue(), ^{ [self showError:error]; });
			return;
		}

		NSData *data = UIImageJPEGRepresentation(image, 0.94);
		NSError *directoryError = nil;
		[[NSFileManager defaultManager] createDirectoryAtPath:DWStorageDirectory
			withIntermediateDirectories:YES
			attributes:nil
			error:&directoryError];
		BOOL wrote = data && [data writeToFile:[self pathForImageName:imageName] options:NSDataWritingAtomic error:&directoryError];

		dispatch_async(dispatch_get_main_queue(), ^{
			if (!wrote) {
				[self showError:directoryError];
				return;
			}
			[self reloadSpecifiers];
		});
	}];
}

- (void)showError:(NSError *)error {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Couldn’t Save Image"
		message:error.localizedDescription ?: @"DuoWall could not create its wallpaper copy."
		preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)openWallpaperSettings {
	NSURL *url = [NSURL URLWithString:@"prefs:root=Wallpaper"];
	[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)confirmReset {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset DuoWall?"
		message:@"This removes DuoWall’s two stored image copies. It does not delete anything from Photos."
		preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
		NSFileManager *manager = [NSFileManager defaultManager];
		[manager removeItemAtPath:[self pathForImageName:@"Light.jpg"] error:nil];
		[manager removeItemAtPath:[self pathForImageName:@"Dark.jpg"] error:nil];
		[self reloadSpecifiers];
	}]];
	[self presentViewController:alert animated:YES completion:nil];
}

@end
