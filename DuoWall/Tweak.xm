#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>

static NSString * const DWStorageDirectory = @"/var/mobile/Library/Application Support/DuoWall";
static NSString * const DWLightImageName = @"Light.jpg";
static NSString * const DWDarkImageName = @"Dark.jpg";

@interface WKWallpaperBundle : NSObject
@property (nonatomic, retain) NSNumber *dw_duoWallMarker;
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
