#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>

static NSString * const DWStorageDirectory = @"/var/mobile/Library/Application Support/DuoWall";
static NSString * const DWLightImageName = @"Light.jpg";
static NSString * const DWDarkImageName = @"Dark.jpg";
static NSString * const DWModernCollectionIdentifier = @"com.futur3sn0w.duowall.collection";
static id gDWModernWallpaperBundle = nil;
static id gDWModernWallpaperCollection = nil;

@interface WKWallpaperBundle : NSObject
@property (nonatomic, retain) NSNumber *dw_duoWallMarker;
+ (instancetype)createTemporaryWallpaperBundleWithImages:(NSDictionary *)images
	videoAssetURLs:(NSDictionary *)videoAssetURLs
	wallpaperOptions:(NSDictionary *)wallpaperOptions
	error:(NSError **)error;
@end

@interface SBFWallpaperOptions : NSObject
- (void)setWallpaperMode:(NSInteger)wallpaperMode;
- (void)setName:(NSString *)name;
- (void)setParallaxFactor:(double)parallaxFactor;
@end

@interface WKWallpaperBundleDownloadManager : NSObject
+ (instancetype)defaultManager;
@end

@interface WKWallpaperRepresentingCollection : NSObject
- (instancetype)initWithWallpaperCollectionIdentifier:(NSString *)identifier
	displayName:(NSString *)displayName
	previewWallpaperRepresenting:(id)previewWallpaper
	wallpapersShareBaseAppearance:(BOOL)sharesAppearance
	wallpaperRepresentingCollection:(id)wallpapers
	downloadManager:(id)downloadManager;
@end

@interface WKWallpaperRepresentingCollectionsManager : NSObject
- (NSInteger)numberOfWallpaperCollections;
- (id)wallpaperCollectionAtIndex:(NSInteger)index;
- (id)wallpaperCollectionWithIdentifier:(NSString *)identifier;
@end

@interface WKSystemShellWallpaperManager : NSObject
+ (instancetype)sharedManager;
- (void)setLockScreenWallpaperRepresenting:(id)wallpaper mirrorToHomeScreen:(BOOL)mirror completion:(dispatch_block_t)completion;
@end

@interface WKWallpaperBundleCollection : NSObject
@property (nonatomic, assign) unsigned long long wallpaperType;
- (long long)numberOfItems;
- (id)wallpaperBundleAtIndex:(unsigned long long)index;
@end

@interface WKStillWallpaper : NSObject
- (id)initWithIdentifier:(unsigned long long)identifier
	name:(NSString *)name
	thumbnailImageURL:(NSURL *)thumbnailURL
	fullsizeImageURL:(NSURL *)fullsizeURL;
- (id)initWithIdentifier:(unsigned long long)identifier
	name:(NSString *)name
	thumbnailImageURL:(NSURL *)thumbnailURL
	fullsizeImageURL:(NSURL *)fullsizeURL
	renderedImageURL:(NSURL *)renderedURL;
@end

static NSString *DWImagePath(BOOL dark) {
	return [DWStorageDirectory stringByAppendingPathComponent:dark ? DWDarkImageName : DWLightImageName];
}

static BOOL DWWallpapersReady(void) {
	NSFileManager *manager = [NSFileManager defaultManager];
	return [manager fileExistsAtPath:DWImagePath(NO)] && [manager fileExistsAtPath:DWImagePath(YES)];
}

static void DWWriteBackendLog(NSString *message) {
	NSString *line = [NSString stringWithFormat:@"%@\n", message ?: @"(no message)"];
	[line writeToFile:@"/var/mobile/Documents/DuoWall-backend-log.txt"
		atomically:YES
		encoding:NSUTF8StringEncoding
		error:nil];
}

__attribute__((visibility("default"))) extern "C" void DuoWallInvalidateModernWallpaper(void) {
	gDWModernWallpaperCollection = nil;
	gDWModernWallpaperBundle = nil;
}

static SBFWallpaperOptions *DWOptions(NSString *name) {
	Class optionsClass = NSClassFromString(@"SBFWallpaperOptions");
	SBFWallpaperOptions *options = optionsClass ? [[optionsClass alloc] init] : nil;
	if ([options respondsToSelector:@selector(setWallpaperMode:)]) [options setWallpaperMode:1];
	if ([options respondsToSelector:@selector(setName:)]) [options setName:name];
	if ([options respondsToSelector:@selector(setParallaxFactor:)]) [options setParallaxFactor:1.0];
	return options;
}

static id DWModernWallpaperBundle(void) {
	if (gDWModernWallpaperBundle) return gDWModernWallpaperBundle;
	if (!DWWallpapersReady()) return nil;

	Class bundleClass = NSClassFromString(@"WKWallpaperBundle");
	SEL creator = @selector(createTemporaryWallpaperBundleWithImages:videoAssetURLs:wallpaperOptions:error:);
	if (![bundleClass respondsToSelector:creator]) {
		DWWriteBackendLog(@"WKWallpaperBundle temporary-bundle constructor is unavailable.");
		return nil;
	}

	UIImage *lightImage = [UIImage imageWithContentsOfFile:DWImagePath(NO)];
	UIImage *darkImage = [UIImage imageWithContentsOfFile:DWImagePath(YES)];
	if (!lightImage || !darkImage) {
		DWWriteBackendLog(@"DuoWall could not decode one or both selected images.");
		return nil;
	}

	NSDictionary *images = @{@"light": lightImage, @"dark": darkImage};
	SBFWallpaperOptions *lightOptions = DWOptions(@"DuoWall Light");
	SBFWallpaperOptions *darkOptions = DWOptions(@"DuoWall Dark");
	NSDictionary *options = (lightOptions && darkOptions) ? @{@"light": lightOptions, @"dark": darkOptions} : @{};
	NSError *error = nil;

	@try {
		gDWModernWallpaperBundle = [bundleClass createTemporaryWallpaperBundleWithImages:images
			videoAssetURLs:@{}
			wallpaperOptions:options
			error:&error];
	} @catch (NSException *exception) {
		DWWriteBackendLog([NSString stringWithFormat:@"Temporary bundle exception: %@ — %@", exception.name, exception.reason]);
		return nil;
	}

	if (!gDWModernWallpaperBundle) {
		DWWriteBackendLog([NSString stringWithFormat:@"Temporary bundle failed: %@", error.localizedDescription ?: @"unknown error"]);
		return nil;
	}

	DWWriteBackendLog([NSString stringWithFormat:@"Temporary appearance-aware bundle created: %@", gDWModernWallpaperBundle]);
	return gDWModernWallpaperBundle;
}

static id DWModernWallpaperCollection(void) {
	if (gDWModernWallpaperCollection) return gDWModernWallpaperCollection;
	id bundle = DWModernWallpaperBundle();
	Class collectionClass = NSClassFromString(@"WKWallpaperRepresentingCollection");
	if (!bundle || !collectionClass) return nil;

	@try {
		id downloadManager = [NSClassFromString(@"WKWallpaperBundleDownloadManager") defaultManager];
		gDWModernWallpaperCollection = [[collectionClass alloc]
			initWithWallpaperCollectionIdentifier:DWModernCollectionIdentifier
			displayName:@"DuoWall"
			previewWallpaperRepresenting:bundle
			wallpapersShareBaseAppearance:YES
			wallpaperRepresentingCollection:@[bundle]
			downloadManager:downloadManager];
	} @catch (NSException *exception) {
		DWWriteBackendLog([NSString stringWithFormat:@"Collection exception: %@ — %@", exception.name, exception.reason]);
		return nil;
	}
	return gDWModernWallpaperCollection;
}

__attribute__((visibility("default"))) extern "C" void DuoWallApplyModernWallpaper(void (^completion)(BOOL success, NSString *message)) {
	dispatch_async(dispatch_get_main_queue(), ^{
		id bundle = DWModernWallpaperBundle();
		Class managerClass = NSClassFromString(@"WKSystemShellWallpaperManager");
		id manager = [managerClass respondsToSelector:@selector(sharedManager)] ? [managerClass sharedManager] : nil;
		SEL setter = @selector(setLockScreenWallpaperRepresenting:mirrorToHomeScreen:completion:);
		if (!bundle || ![manager respondsToSelector:setter]) {
			NSString *message = bundle ? @"The iOS 16 wallpaper manager is unavailable." : @"iOS rejected the temporary DuoWall bundle. See DuoWall-backend-log.txt in /var/mobile/Documents.";
			DWWriteBackendLog(message);
			if (completion) completion(NO, message);
			return;
		}

		@try {
			[manager setLockScreenWallpaperRepresenting:bundle mirrorToHomeScreen:YES completion:^{
				DWWriteBackendLog(@"WKSystemShellWallpaperManager completed the DuoWall apply request.");
				if (completion) completion(YES, @"DuoWall was applied to the Lock and Home Screens.");
			}];
		} @catch (NSException *exception) {
			NSString *message = [NSString stringWithFormat:@"Apply exception: %@ — %@", exception.name, exception.reason];
			DWWriteBackendLog(message);
			if (completion) completion(NO, message);
		}
	});
}

static BOOL DWClassNameIsRelevant(const char *rawName) {
	if (!rawName) return NO;
	NSString *name = [NSString stringWithUTF8String:rawName];
	NSString *lowercaseName = name.lowercaseString;
	return [lowercaseName containsString:@"wallpaper"] ||
		[lowercaseName containsString:@"poster"] ||
		[name hasPrefix:@"PRS"] ||
		[name hasPrefix:@"PRB"] ||
		[name hasPrefix:@"WK"] ||
		[name hasPrefix:@"WPU"];
}

static void DWAppendMethods(NSMutableString *dump, Class cls, BOOL classMethods) {
	Class target = classMethods ? object_getClass(cls) : cls;
	unsigned int methodCount = 0;
	Method *methods = class_copyMethodList(target, &methodCount);
	for (unsigned int index = 0; index < methodCount; index++) {
		SEL selector = method_getName(methods[index]);
		const char *types = method_getTypeEncoding(methods[index]);
		[dump appendFormat:@"  %@ %@  [%s]\n", classMethods ? @"+" : @"-", NSStringFromSelector(selector), types ?: "?"];
	}
	free(methods);
}

__attribute__((visibility("default"))) extern "C" void DuoWallWriteCompatibilityDump(void) {
	@autoreleasepool {
		NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
		NSString *safeProcessName = [processName stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
		NSString *path = [NSString stringWithFormat:@"/var/mobile/Documents/DuoWall-%@-method-dump.txt", safeProcessName];
		NSMutableString *dump = [NSMutableString string];
		[dump appendFormat:@"DuoWall compatibility dump\nProcess: %@\nBundle: %@\niOS: %@\n\nLoaded wallpaper frameworks:\n",
			processName,
			NSBundle.mainBundle.bundleIdentifier ?: @"(none)",
			UIDevice.currentDevice.systemVersion ?: @"(unknown)"];

		uint32_t imageCount = _dyld_image_count();
		for (uint32_t index = 0; index < imageCount; index++) {
			const char *rawImageName = _dyld_get_image_name(index);
			if (!rawImageName) continue;
			NSString *imageName = [NSString stringWithUTF8String:rawImageName];
			NSString *lowercaseName = imageName.lowercaseString;
			if ([lowercaseName containsString:@"wallpaper"] ||
				[lowercaseName containsString:@"poster"] ||
				[lowercaseName containsString:@"springboardui"] ||
				[lowercaseName containsString:@"posterkit"]) {
				[dump appendFormat:@"%@\n", imageName];
			}
		}

		[dump appendString:@"\nRelevant runtime classes and methods:\n"];
		int classCount = objc_getClassList(NULL, 0);
		if (classCount > 0) {
			Class *classes = (__unsafe_unretained Class *)calloc((size_t)classCount, sizeof(Class));
			classCount = objc_getClassList(classes, classCount);
			NSMutableArray<NSString *> *classNames = [NSMutableArray array];
			for (int index = 0; index < classCount; index++) {
				const char *name = class_getName(classes[index]);
				if (DWClassNameIsRelevant(name)) [classNames addObject:[NSString stringWithUTF8String:name]];
			}
			[classNames sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
			for (NSString *className in classNames) {
				Class cls = NSClassFromString(className);
				[dump appendFormat:@"\n%@\n", className];
				DWAppendMethods(dump, cls, YES);
				DWAppendMethods(dump, cls, NO);
			}
			free(classes);
		}

		NSError *error = nil;
		[dump writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
		if (error) NSLog(@"[DuoWall] Could not write compatibility dump: %@", error);
	}
}

static void DWScheduleCompatibilityDumps(void) {
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		DuoWallWriteCompatibilityDump();
	});
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		DuoWallWriteCompatibilityDump();
	});
}

static id DWWallpaper(BOOL dark) {
	Class wallpaperClass = NSClassFromString(@"WKStillWallpaper");
	if (!wallpaperClass) return nil;

	NSURL *lightURL = [NSURL fileURLWithPath:DWImagePath(NO)];
	NSURL *imageURL = [NSURL fileURLWithPath:DWImagePath(dark)];
	id instance = [wallpaperClass alloc];
	SEL renderedSelector = @selector(initWithIdentifier:name:thumbnailImageURL:fullsizeImageURL:renderedImageURL:);

	if ([instance respondsToSelector:renderedSelector]) {
		return [(WKStillWallpaper *)instance initWithIdentifier:0x44555741
			name:@"DuoWall"
			thumbnailImageURL:lightURL
			fullsizeImageURL:imageURL
			renderedImageURL:nil];
	}

	return [(WKStillWallpaper *)instance initWithIdentifier:0x44555741
		name:@"DuoWall"
		thumbnailImageURL:lightURL
		fullsizeImageURL:imageURL];
}

%hook WKWallpaperBundleCollection

- (long long)numberOfItems {
	long long original = %orig;
	return (self.wallpaperType == 0 && DWWallpapersReady()) ? original + 1 : original;
}

- (id)wallpaperBundleAtIndex:(unsigned long long)index {
	if (self.wallpaperType == 0 && DWWallpapersReady() && index == (unsigned long long)([self numberOfItems] - 1)) {
		WKWallpaperBundle *bundle = [[%c(WKWallpaperBundle) alloc] init];
		bundle.dw_duoWallMarker = @YES;
		return bundle;
	}

	return %orig;
}

%end

%hook WKWallpaperRepresentingCollectionsManager

- (NSInteger)numberOfWallpaperCollections {
	NSInteger original = %orig;
	return DWModernWallpaperCollection() ? original + 1 : original;
}

- (id)wallpaperCollectionAtIndex:(NSInteger)index {
	id collection = DWModernWallpaperCollection();
	if (collection && index == [self numberOfWallpaperCollections] - 1) return collection;
	return %orig;
}

- (id)wallpaperCollectionWithIdentifier:(NSString *)identifier {
	if ([identifier isEqualToString:DWModernCollectionIdentifier]) return DWModernWallpaperCollection();
	return %orig;
}

%end

%ctor {
	dispatch_async(dispatch_get_main_queue(), ^{
		DWScheduleCompatibilityDumps();
	});
}

%hook WKWallpaperBundle

%property (nonatomic, retain) NSNumber *dw_duoWallMarker;

- (NSString *)name {
	return self.dw_duoWallMarker.boolValue ? @"DuoWall" : %orig;
}

- (NSString *)family {
	return self.dw_duoWallMarker.boolValue ? @"DuoWall" : %orig;
}

- (unsigned long long)version {
	return self.dw_duoWallMarker.boolValue ? 1 : %orig;
}

- (unsigned long long)identifier {
	return self.dw_duoWallMarker.boolValue ? 0x44555741 : %orig;
}

- (BOOL)hasDistintWallpapersForLocations {
	return self.dw_duoWallMarker.boolValue ? NO : %orig;
}

- (BOOL)isDynamicWallpaperBundle {
	return self.dw_duoWallMarker.boolValue ? NO : %orig;
}

- (BOOL)isAppearanceAware {
	return self.dw_duoWallMarker.boolValue ? YES : %orig;
}

- (NSURL *)thumbnailImageURL {
	return self.dw_duoWallMarker.boolValue ? [NSURL fileURLWithPath:DWImagePath(NO)] : %orig;
}

- (NSMutableDictionary *)_defaultAppearanceWallpapers {
	if (!self.dw_duoWallMarker.boolValue) return %orig;
	id wallpaper = DWWallpaper(NO);
	return wallpaper ? [@{@"WKWallpaperLocationCoverSheet": wallpaper} mutableCopy] : [NSMutableDictionary dictionary];
}

- (NSMutableDictionary *)_darkAppearanceWallpapers {
	if (!self.dw_duoWallMarker.boolValue) return %orig;
	id wallpaper = DWWallpaper(YES);
	return wallpaper ? [@{@"WKWallpaperLocationCoverSheet": wallpaper} mutableCopy] : [NSMutableDictionary dictionary];
}

- (id)fileBasedWallpaperForLocation:(id)location andAppearance:(id)appearance {
	if (!self.dw_duoWallMarker.boolValue) return %orig;
	return DWWallpaper([appearance isEqual:@"dark"]);
}

- (id)valueBasedWallpaperForLocation:(id)location andAppearance:(id)appearance {
	if (!self.dw_duoWallMarker.boolValue) return %orig;
	return DWWallpaper([appearance isEqual:@"dark"]);
}

- (id)fileBasedWallpaperForLocation:(id)location {
	if (!self.dw_duoWallMarker.boolValue) return %orig;
	return DWWallpaper(NO);
}

- (id)valueBasedWallpaperForLocation:(id)location {
	if (!self.dw_duoWallMarker.boolValue) return %orig;
	return DWWallpaper(NO);
}

%end

%hook WKStillWallpaper

%new
- (UIImage *)thumbnailImage {
	return [[UIImage alloc] init];
}

%new
- (id)wallpaperValue {
	return nil;
}

%end
