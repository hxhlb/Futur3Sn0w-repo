#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <substrate.h>
#import <unistd.h>

static NSString *const MMMuteModuleIdentifier = @"com.apple.control-center.MuteModule";
static NSString *const MMMuteModulePathFragment = @"/MuteModule.bundle";
static BOOL MMInstalledHooks = NO;
static BOOL MMStartedInstallLoop = NO;
static NSUInteger MMInstallAttemptCount = 0;

static NSUInteger (*MMOrigMetadataVisibilityPreference)(id, SEL);
static NSArray *(*MMOrigQueueFilterModuleMetadataByVisibilityPreference)(id, SEL, NSArray *);

static NSString *MMIdentifierForMetadata(id metadata) {
	if (!metadata || ![metadata respondsToSelector:@selector(moduleIdentifier)]) {
		return nil;
	}

	NSString *(*sendIdentifier)(id, SEL) = (NSString *(*)(id, SEL))objc_msgSend;
	return sendIdentifier(metadata, @selector(moduleIdentifier));
}

static NSURL *MMBundleURLForMetadata(id metadata) {
	if (!metadata || ![metadata respondsToSelector:@selector(moduleBundleURL)]) {
		return nil;
	}

	NSURL *(*sendURL)(id, SEL) = (NSURL *(*)(id, SEL))objc_msgSend;
	return sendURL(metadata, @selector(moduleBundleURL));
}

static BOOL MMMetadataIsMuteModule(id metadata) {
	NSString *identifier = MMIdentifierForMetadata(metadata);
	NSURL *bundleURL = MMBundleURLForMetadata(metadata);
	return [identifier isEqualToString:MMMuteModuleIdentifier] ||
		[identifier containsString:@"MuteModule"] ||
		[bundleURL.path containsString:MMMuteModulePathFragment];
}

static NSUInteger MMMetadataVisibilityPreference(id self, SEL sel) {
	if (MMMetadataIsMuteModule(self)) {
		return 0;
	}

	return MMOrigMetadataVisibilityPreference(self, sel);
}

static NSArray *MMQueueFilterModuleMetadataByVisibilityPreference(id self, SEL sel, NSArray *sourceMetadata) {
	NSArray *filteredMetadata = MMOrigQueueFilterModuleMetadataByVisibilityPreference(self, sel, sourceMetadata);
	if (![sourceMetadata isKindOfClass:[NSArray class]] || ![filteredMetadata isKindOfClass:[NSArray class]]) {
		return filteredMetadata;
	}

	id muteMetadata = nil;
	for (id metadata in sourceMetadata) {
		if (MMMetadataIsMuteModule(metadata)) {
			muteMetadata = metadata;
			break;
		}
	}

	if (!muteMetadata || [filteredMetadata containsObject:muteMetadata]) {
		return filteredMetadata;
	}

	NSMutableArray *restoredMetadata = [filteredMetadata mutableCopy];
	[restoredMetadata addObject:muteMetadata];
	return [restoredMetadata copy];
}

static void MMInstallHooks(void) {
	if (MMInstalledHooks) {
		return;
	}

	MMInstallAttemptCount++;
	Class metadataClass = objc_getClass("CCSModuleMetadata");
	Class repositoryClass = objc_getClass("CCSModuleRepository");
	if (!metadataClass || !repositoryClass) {
		return;
	}

	MMInstalledHooks = YES;
	MSHookMessageEx(metadataClass, @selector(visibilityPreference), (IMP)MMMetadataVisibilityPreference, (IMP *)&MMOrigMetadataVisibilityPreference);
	MSHookMessageEx(repositoryClass, @selector(_queue_filterModuleMetadataByVisibilityPreference:), (IMP)MMQueueFilterModuleMetadataByVisibilityPreference, (IMP *)&MMOrigQueueFilterModuleMetadataByVisibilityPreference);
}

static void MMScheduleHookInstall(void) {
	if (MMInstalledHooks || MMStartedInstallLoop) {
		return;
	}

	MMStartedInstallLoop = YES;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		for (NSUInteger attempt = 0; attempt < 200 && !MMInstalledHooks; attempt++) {
			MMInstallHooks();
			if (MMInstalledHooks) {
				break;
			}
			usleep(10000);
		}
	});
}

static BOOL MMImageNameIsControlCenterServices(const char *imageName) {
	return imageName && strstr(imageName, "ControlCenterServices.framework/ControlCenterServices");
}

static void MMImageAdded(const struct mach_header *header, intptr_t slide) {
	uint32_t imageCount = _dyld_image_count();
	for (uint32_t index = 0; index < imageCount; index++) {
		if (_dyld_get_image_header(index) == header && MMImageNameIsControlCenterServices(_dyld_get_image_name(index))) {
			MMScheduleHookInstall();
			return;
		}
	}
}

static void MMInstallHooksForLoadedImages(void) {
	uint32_t imageCount = _dyld_image_count();
	for (uint32_t index = 0; index < imageCount; index++) {
		if (MMImageNameIsControlCenterServices(_dyld_get_image_name(index))) {
			MMScheduleHookInstall();
			return;
		}
	}
}

%ctor {
	@autoreleasepool {
		_dyld_register_func_for_add_image(MMImageAdded);
		MMInstallHooksForLoadedImages();
	}
}
