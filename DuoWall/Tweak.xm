#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>
#import <substrate.h>

static NSString * const DWStorageDirectory = @"/var/mobile/Library/Application Support/DuoWall";
static NSString * const DWLightImageName = @"Light.jpg";
static NSString * const DWDarkImageName = @"Dark.jpg";
static NSString * const DWFriendlyNameFileName = @"WallpaperName.txt";
static NSString * const DWModernCollectionIdentifier = @"com.futur3sn0w.duowall.collection";
static NSString * const DWLogicalScreenClassCachePath = @"/var/mobile/Library/Application Support/DuoWall/LogicalScreenClass.txt";
static NSString * const DWPosterBoardBundleIdentifier = @"com.apple.PosterBoard";
static NSString * const DWPosterCollectionsExtensionIdentifier = @"com.apple.WallpaperKit.CollectionsPoster";
static CFStringRef const DWApplyRequestNotification = CFSTR("com.futur3sn0w.duowall.apply-request");
static CFStringRef const DWCollectionsChangedNotification = CFSTR("com.futur3sn0w.duowall.collections-changed");
static id gDWModernWallpaperBundle = nil;
static NSString *gDWObservedLogicalScreenClass = nil;
static NSString *gDWGeneratedWallpaperBundlePath = nil;
static id gDWCachedAggregateCollection = nil;
static NSString *gDWCachedAggregateCollectionSignature = nil;
static __thread BOOL gDWTracingTemporaryBundle = NO;
static __thread BOOL gDWInsideDictionaryProbe = NO;
static BOOL gDWBuildingModernWallpaper = NO;
static BOOL gDWRegisteredApplyObserver = NO;
static BOOL gDWRegisteredCollectionsObserver = NO;
static IMP gDWOriginalDictionaryInitializer = NULL;
static id DWWallpaper(BOOL dark);
static void DWWriteBackendLog(NSString *message);
static void DWApplyModernWallpaperInCurrentProcess(void (^completion)(BOOL success, NSString *message));
static NSArray *DWCollectionsByAppendingDuoWallIfNeeded(id collections);
static id DWCollectionLookupByAppendingDuoWallIfNeeded(id lookup);
static NSArray<NSString *> *DWCollectionPublishCandidatePaths(void);
static void DWInjectDuoWallIntoCollectionsManager(id manager, NSString *source);
static NSString *DWSummarizeWallpaperCollection(id collection);
static void DWLogCollectionsManagerSnapshot(NSString *reason);
static BOOL DWCopyBundleAtPathToPath(NSString *sourcePath, NSString *destinationPath, NSError **error);
static NSString *DWEnsureGeneratedWallpaperBundlePath(void);
static NSString *DWPosterBoardDataContainerPath(void);
static NSString *DWPosterDescriptorStoreRootPath(void);
static NSData *DWPosterProviderInfoData(void);
static NSData *DWPosterGalleryOptionsData(void);
static NSData *DWPosterConfigurableOptionsData(void);
static NSDictionary *DWWallpaperCollectionMetadata(NSString *collectionIdentifier, NSString *displayName, NSString *wallpaperIdentifierString, NSNumber *wallpaperIdentifierNumber);
static NSDictionary *DWPosterDescriptorSummaryAtPath(NSString *descriptorPath);
static BOOL DWInstallPosterBoardDescriptor(NSError **error);
static NSString *DWDescriptorBackupRootPath(void);
static BOOL DWMigrateDescriptorCollectionMetadataIfNeeded(NSString *descriptorPath, NSString *reason);
static NSUInteger DWMigrateMissingCollectionMetadataAtRoot(NSString *rootPath, NSString *reason);
static void DWBackupDescriptorDirectoryIfNeeded(NSString *descriptorDirectoryPath);
static void DWRestoreBackedUpDescriptorsIfNeeded(NSString *reason);
static void DWSetValueSafely(id object, NSString *key, id value);
static NSString *DWResolvedFriendlyNameForInstall(NSString *baseName);
static void DWLogPosterDescriptorStoreSnapshot(NSString *reason);
static BOOL DWProcessNameMatchesProbeTarget(NSString *processName);
static void DWLogProcessProbeSnapshot(NSString *reason);
static void DWLogPreferenceClassSummary(NSString *reason);
static void DWLogPreferenceTargetedSelectors(NSString *reason);
static void DWInstallSwiftCoordinatorHooks(void);
static BOOL DWVerboseDiagnosticsEnabled(void);
static NSString *DWCurrentFriendlyName(void);
static id DWAugmentedWallpapersForCollectionsCategory(id wallpapers, NSString *identifier, NSString *displayName);
static id DWRuntimeSelectorValue(id object, SEL selector);
static NSArray *DWInstalledDuoWallCollections(void);
static BOOL DWDuoWallCollectionIdentifierMatches(NSString *identifier);
static BOOL DWIsAggregateDuoWallCollectionIdentifier(NSString *identifier);
static void DWRefreshCollectionsManagers(NSString *reason);
static void DWPostCollectionsChangedNotification(NSString *reason);
static BOOL DWShouldObserveCollectionsNotificationsForProcess(NSString *processName);

@interface WKWallpaperBundle : NSObject
@property (nonatomic, retain) NSNumber *dw_duoWallMarker;
+ (instancetype)createTemporaryWallpaperBundleWithImages:(NSDictionary *)images
	videoAssetURLs:(NSDictionary *)videoAssetURLs
	wallpaperOptions:(NSDictionary *)wallpaperOptions
	error:(NSError **)error;
+ (instancetype)_createWallpaperBundleInDirectory:(NSURL *)directoryURL
	version:(NSInteger)version
	identifier:(NSInteger)identifier
	name:(NSString *)name
	family:(NSString *)family
	disableParallax:(BOOL)disableParallax
	isOffloaded:(BOOL)isOffloaded
	logicalScreenClass:(id)logicalScreenClass
	thumbnailImageURL:(NSURL *)thumbnailImageURL
	assetMapping:(NSDictionary *)assetMapping;
- (instancetype)initWithURL:(NSURL *)url;
- (NSString *)logicalScreenClass;
@end

@interface SBFWallpaperOptions : NSObject
- (void)setWallpaperMode:(NSInteger)wallpaperMode;
- (void)setName:(NSString *)name;
- (void)setParallaxFactor:(double)parallaxFactor;
@end

@interface UIImage (DuoWallWallpaperKit)
+ (UIImage *)wk_imageWithLightAppearanceImage:(UIImage *)lightAppearanceImage
	darkAppearanceImage:(UIImage *)darkAppearanceImage;
@end

@interface WKWallpaperBundleDownloadManager : NSObject
+ (instancetype)defaultManager;
@end

@interface WKDefaultWallpaperManager : NSObject
+ (instancetype)defaultWallpaperManager;
+ (NSURL *)defaultWallpaperLookupURL;
- (NSString *)deviceLogicalScreenClass;
- (id)defaultWallpaperBundle;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleIdentifier;
@end

@interface WKWallpaperRepresentingCollection : NSObject
- (NSString *)wallpaperCollectionIdentifier;
- (instancetype)initWithURL:(NSURL *)url downloadManager:(id)downloadManager;
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
- (id)_wallpaperCollections;
- (void)set_wallpaperCollections:(id)collections;
- (id)_wallpaperCollectionLookupTable;
- (void)set_wallpaperCollectionLookupTable:(id)lookupTable;
@end

@interface WKSystemShellWallpaperManager : NSObject
+ (instancetype)sharedManager;
- (void)setHomeScreenWallpaperRepresenting:(id)wallpaper completion:(dispatch_block_t)completion;
- (void)setLockScreenWallpaperRepresenting:(id)wallpaper mirrorToHomeScreen:(BOOL)mirror completion:(dispatch_block_t)completion;
@end

@interface WKCurrentWallpaperManager : NSObject
+ (instancetype)sharedCurrentWallpaperManager;
- (void)setWallpaperRepresenting:(id)wallpaper forWallpaperLocation:(id)location completion:(dispatch_block_t)completion;
- (void)setWallpaperRepresenting:(id)wallpaper
	forWallpaperLocation:(id)location
	desiredCropRect:(CGRect)cropRect
	wallpaperOptions:(id)wallpaperOptions
	completion:(dispatch_block_t)completion;
- (NSURL *)wallpaperCollectionsDirectoryURL;
@end

@interface WKWallpaperBundleCollection : NSObject
@property (nonatomic, assign) unsigned long long wallpaperType;
- (long long)numberOfItems;
- (id)wallpaperBundleAtIndex:(unsigned long long)index;
@end

@interface PBUIWallpaperServer : NSObject
- (void)setWallpaperImage:(id)image
	adjustedImage:(id)adjustedImage
	thumbnailData:(id)thumbnailData
	imageHashData:(id)imageHashData
	wallpaperOptions:(id)wallpaperOptions
	forLocations:(unsigned long long)locations
	currentWallpaperMode:(long long)wallpaperMode;
- (void)setWallpaperColor:(id)color darkColor:(id)darkColor forLocations:(unsigned long long)locations;
- (void)setWallpaperGradient:(id)gradient forLocations:(unsigned long long)locations;
- (void)restoreDefaultWallpaper;
@end

@interface PBUIWallpaperUserDefaultsDataStore : NSObject
- (void)setWallpaperImage:(id)image forVariant:(unsigned long long)variant wallpaperMode:(long long)wallpaperMode;
- (void)setWallpaperOptions:(id)options forVariant:(unsigned long long)variant wallpaperMode:(long long)wallpaperMode;
- (void)setWallpaperThumbnailData:(id)thumbnailData forVariant:(unsigned long long)variant wallpaperMode:(long long)wallpaperMode;
- (void)setWallpaperOriginalImage:(id)image forVariant:(unsigned long long)variant wallpaperMode:(long long)wallpaperMode;
@end

@interface PBUIWallpaperDefaults : NSObject
- (void)setWallpaperOptions:(id)options forLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode;
- (void)setWallpaperKitData:(id)data forLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode;
- (void)setName:(id)name forLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode;
- (void)setCropRect:(CGRect)cropRect forLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode;
- (void)setZoomScale:(double)zoomScale forLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode;
@end

@interface WSWallpaperSettingsCoordinator : NSObject
- (void)start;
- (void)runTestWithTestName:(id)testName options:(id)options;
@end

@interface WallpaperSettings_WallpaperPreviewCoordinator : NSObject
- (void)wallpaperPreviewViewControllerSetButtonPressed:(id)controller;
@end

@interface WallpaperSettings_CurrentSystemShellWallpaperPreviewCoordinator : NSObject
- (void)start;
- (void)wallpaperPreviewViewControllerSetButtonPressed:(id)controller;
@end

@interface PBUIWallpaperDefaultsWrapper : NSObject
- (void)setWallpaperKitData:(id)data;
- (void)setWallpaperOptions:(id)options;
@end

@interface PBUIWallpaperConfigurationManager : NSObject
- (void)beginChangeBatch;
- (void)endChangeBatch;
- (void)notifyDelegateOfChangesToVariants:(unsigned long long)variants;
- (void)setWallpaperBundle:(id)bundle appearance:(long long)appearance;
- (void)setWallpaperImage:(id)image
	adjustedImage:(id)adjustedImage
	thumbnailData:(id)thumbnailData
	imageHashData:(id)imageHashData
	wallpaperOptions:(id)wallpaperOptions
	forVariants:(unsigned long long)variants
	wallpaperMode:(long long)wallpaperMode;
- (void)setWallpaperOptions:(id)options
	forVariants:(unsigned long long)variants
	wallpaperMode:(long long)wallpaperMode;
@end

@interface PBUIWallpaperViewController : NSObject
- (void)setWallpaperConfigurationManager:(id)manager;
- (void)wallpaperConfigurationManager:(id)manager didChangeWallpaperConfigurationForVariants:(unsigned long long)variants;
- (void)updateWallpaperForLocations:(unsigned long long)locations withCompletion:(id)completion;
- (void)updateWallpaperForLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode withCompletion:(id)completion;
- (void)noteWallpapersDidUpdate;
@end

@interface PBUIWallpaperRemoteViewController : NSObject
- (void)setWallpaperConfigurationManager:(id)manager;
- (void)wallpaperConfigurationManager:(id)manager didChangeWallpaperConfigurationForVariants:(unsigned long long)variants;
- (void)updateWallpaperForLocations:(unsigned long long)locations withCompletion:(id)completion;
- (void)updateWallpaperForLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode withCompletion:(id)completion;
@end

@interface PBUIPosterWallpaperRemoteViewController : NSObject
- (void)setWallpaperConfigurationManager:(id)manager;
- (void)wallpaperConfigurationManager:(id)manager didChangeWallpaperConfigurationForVariants:(unsigned long long)variants;
- (void)setConfiguration:(id)configuration withAnimationSettings:(id)animationSettings;
- (void)setAssociatedPosterConfiguration:(id)configuration withAnimationSettings:(id)animationSettings;
- (void)triggerSceneUpdate;
@end

@interface PBUIPosterWallpaperViewController : NSObject
- (void)setWallpaperStyle:(id)style forPriority:(long long)priority forVariant:(unsigned long long)variant;
- (void)updateConfiguration:(id)configuration withAnimationSettings:(id)animationSettings;
- (void)updateAssociatedPosterConfiguration:(id)configuration withAnimationSettings:(id)animationSettings;
- (void)triggerSceneUpdate;
@end

@interface PBUIPosterViewController : NSObject
- (void)updateConfiguration:(id)configuration;
- (void)updateAssociatedPosterConfiguration:(id)configuration;
- (void)updatePoster:(id)poster;
- (void)updateLegacyPoster;
@end

@interface SBSUIWallpaperPreviewViewController : NSObject
- (void)userDidTapOnSetButton:(id)sender;
- (void)setWallpaperForLocations:(unsigned long long)locations;
- (void)setWallpaperForLocations:(unsigned long long)locations completionHandler:(id)completionHandler;
- (void)_setWallpaperForLocationsOnMainThread:(unsigned long long)locations completionHandler:(id)completionHandler;
- (void)setWallpaperImages:(id)images
	options:(id)options
	locations:(unsigned long long)locations
	completionHandler:(id)completionHandler;
- (void)_setWallpaperImagesOnMainThread:(id)images
	options:(id)options
	locations:(unsigned long long)locations
	completionHandler:(id)completionHandler;
@end

@interface WKAbstractWallpaper : NSObject
- (BOOL)supportsCopying;
- (BOOL)supportsSerialization;
- (unsigned long long)type;
- (unsigned long long)representedType;
- (unsigned long long)backingType;
- (NSURL *)thumbnailImageURL;
@end

@interface WKStillWallpaper : WKAbstractWallpaper
- (id)initWithIdentifier:(unsigned long long)identifier
	name:(NSString *)name
	type:(unsigned long long)type
	thumbnailImageURL:(NSURL *)thumbnailURL
	fullsizeImageURL:(NSURL *)fullsizeURL;
- (id)initWithIdentifier:(unsigned long long)identifier
	name:(NSString *)name
	thumbnailImageURL:(NSURL *)thumbnailURL
	fullsizeImageURL:(NSURL *)fullsizeURL;
- (id)initWithIdentifier:(unsigned long long)identifier
	name:(NSString *)name
	thumbnailImageURL:(NSURL *)thumbnailURL
	fullsizeImageURL:(NSURL *)fullsizeURL
	renderedImageURL:(NSURL *)renderedURL;
- (NSURL *)fullsizeImageURL;
- (BOOL)copyWallpaperContentsToDestinationDirectoryURL:(NSURL *)destinationURL error:(NSError **)error;
@end

static NSString *DWImagePath(BOOL dark) {
	return [DWStorageDirectory stringByAppendingPathComponent:dark ? DWDarkImageName : DWLightImageName];
}

static NSString *DWFriendlyNamePath(void) {
	return [DWStorageDirectory stringByAppendingPathComponent:DWFriendlyNameFileName];
}

static NSString *DWNormalizeFriendlyName(NSString *name) {
	NSString *trimmed = [[name ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
	if (!trimmed.length) return @"DuoWall";
	return trimmed;
}

static NSString *DWCurrentFriendlyName(void) {
	NSString *stored = [NSString stringWithContentsOfFile:DWFriendlyNamePath()
		encoding:NSUTF8StringEncoding
		error:nil];
	return DWNormalizeFriendlyName(stored);
}

static BOOL DWBackendLoggingEnabled(void) {
	NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.futur3sn0w.duowall"];
	return [defaults boolForKey:@"BackendLoggingEnabled"];
}

static BOOL DWVerboseDiagnosticsEnabled(void) {
	static BOOL cachedValue = NO;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSString *flagPath = [DWStorageDirectory stringByAppendingPathComponent:@"EnableVerboseDiagnostics"];
		cachedValue = [[NSFileManager defaultManager] fileExistsAtPath:flagPath];
	});
	return cachedValue;
}

static BOOL DWWallpapersReady(void) {
	NSFileManager *manager = [NSFileManager defaultManager];
	return [manager fileExistsAtPath:DWImagePath(NO)] && [manager fileExistsAtPath:DWImagePath(YES)];
}

static NSString *DWCachedLogicalScreenClass(void) {
	@synchronized([NSObject class]) {
		if (gDWObservedLogicalScreenClass.length) return gDWObservedLogicalScreenClass;
		NSString *stored = [NSString stringWithContentsOfFile:DWLogicalScreenClassCachePath
			encoding:NSUTF8StringEncoding
			error:nil];
		stored = [stored stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (stored.length) {
			gDWObservedLogicalScreenClass = [stored copy];
			DWWriteBackendLog([NSString stringWithFormat:@"Loaded cached logicalScreenClass=%@", gDWObservedLogicalScreenClass]);
		}
		return gDWObservedLogicalScreenClass;
	}
}

static void DWRememberLogicalScreenClass(NSString *logicalScreenClass, NSString *source) {
	if (![logicalScreenClass isKindOfClass:[NSString class]] || !logicalScreenClass.length) return;

	@synchronized([NSObject class]) {
		if ([gDWObservedLogicalScreenClass isEqualToString:logicalScreenClass]) return;
		gDWObservedLogicalScreenClass = [logicalScreenClass copy];
		[[NSFileManager defaultManager] createDirectoryAtPath:DWStorageDirectory withIntermediateDirectories:YES attributes:nil error:nil];
		[gDWObservedLogicalScreenClass writeToFile:DWLogicalScreenClassCachePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
	}

	DWWriteBackendLog([NSString stringWithFormat:@"Captured logicalScreenClass=%@ source=%@", logicalScreenClass, source ?: @"(unknown)"]);
}

static void DWCaptureLogicalScreenClassFromBundle(id bundle, NSString *source) {
	if (!bundle || gDWBuildingModernWallpaper) return;
	if (![bundle respondsToSelector:@selector(logicalScreenClass)]) return;

	@try {
		DWRememberLogicalScreenClass([bundle logicalScreenClass], source);
	} @catch (NSException *exception) {
		DWWriteBackendLog([NSString stringWithFormat:@"logicalScreenClass probe exception source=%@ name=%@ reason=%@",
			source ?: @"(unknown)",
			exception.name ?: @"(nil)",
			exception.reason ?: @"(nil)"]);
	}
}

static void DWCaptureLogicalScreenClassFromObject(id object, NSString *source) {
	if (!object || gDWBuildingModernWallpaper) return;

	if ([object isKindOfClass:[NSArray class]]) {
		for (id item in (NSArray *)object) {
			DWCaptureLogicalScreenClassFromObject(item, source);
		}
		return;
	}

	DWCaptureLogicalScreenClassFromBundle(object, source);
}

static void DWWarmLogicalScreenClassInSystemProcess(void) {
	if (DWCachedLogicalScreenClass().length) return;

	NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
	if (![processName isEqualToString:@"SpringBoard"] && ![processName isEqualToString:@"PosterBoard"]) return;

	@try {
		Class managerClass = NSClassFromString(@"WKDefaultWallpaperManager");
		id defaultWallpaperManager = [managerClass respondsToSelector:@selector(defaultWallpaperManager)]
			? [managerClass defaultWallpaperManager]
			: nil;
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] Warmup defaultWallpaperManager=%@",
			processName,
			defaultWallpaperManager ? NSStringFromClass([defaultWallpaperManager class]) : @"nil"]);
		NSString *logicalScreenClass = [defaultWallpaperManager respondsToSelector:@selector(deviceLogicalScreenClass)]
			? [defaultWallpaperManager deviceLogicalScreenClass]
			: nil;
		if (!logicalScreenClass.length) {
			id defaultBundle = [defaultWallpaperManager respondsToSelector:@selector(defaultWallpaperBundle)]
				? [defaultWallpaperManager defaultWallpaperBundle]
				: nil;
			if ([defaultBundle respondsToSelector:@selector(logicalScreenClass)]) {
				logicalScreenClass = [defaultBundle logicalScreenClass];
			}
		}
		if (logicalScreenClass.length) {
			DWRememberLogicalScreenClass(logicalScreenClass, [NSString stringWithFormat:@"%@ warmup", processName]);
		} else {
			DWWriteBackendLog([NSString stringWithFormat:@"[%@] Warmup could not resolve logicalScreenClass.", processName]);
		}
	} @catch (NSException *exception) {
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] Warmup exception: %@ — %@",
			processName,
			exception.name ?: @"(nil)",
			exception.reason ?: @"(nil)"]);
	}
}

static void DWWriteBackendLog(NSString *message) {
	if (!DWBackendLoggingEnabled()) return;
	@synchronized([NSFileManager class]) {
		NSString *path = @"/var/mobile/Documents/DuoWall-backend-log.txt";
		NSString *line = [NSString stringWithFormat:@"%@\n", message ?: @"(no message)"];
		NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
		if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
			[data writeToFile:path atomically:YES];
			return;
		}

		NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
		[handle seekToEndOfFile];
		[handle writeData:data];
		[handle closeFile];
	}
}

static BOOL DWProcessNameMatchesProbeTarget(NSString *processName) {
	if (!processName.length) return NO;
	NSSet<NSString *> *targets = [NSSet setWithArray:@[
		@"Preferences",
		@"SpringBoard",
		@"WallpaperSettings",
		@"WallpaperAgent",
		@"WallpaperHelper",
		@"Wallpaper"
	]];
	return [targets containsObject:processName];
}

static BOOL DWShouldObserveCollectionsNotificationsForProcess(NSString *processName) {
	if (!processName.length) return NO;
	NSSet<NSString *> *targets = [NSSet setWithArray:@[
		@"SpringBoard",
		@"Preferences",
		@"PosterBoard",
		@"WallpaperSettings",
		@"WallpaperAgent",
		@"WallpaperHelper",
		@"Wallpaper"
	]];
	return [targets containsObject:processName];
}

static void DWLogProcessProbeSnapshot(NSString *reason) {
	NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
	if (!DWProcessNameMatchesProbeTarget(processName)) return;

	NSMutableArray<NSString *> *interestingImages = [NSMutableArray array];
	uint32_t imageCount = _dyld_image_count();
	for (uint32_t index = 0; index < imageCount; index++) {
		const char *rawImageName = _dyld_get_image_name(index);
		if (!rawImageName) continue;
		NSString *imageName = [NSString stringWithUTF8String:rawImageName];
		NSString *lowercaseName = imageName.lowercaseString;
		if ([lowercaseName containsString:@"wallpaper"] ||
			[lowercaseName containsString:@"poster"]) {
			[interestingImages addObject:imageName];
		}
	}

	DWWriteBackendLog([NSString stringWithFormat:@"[%@] Probe snapshot reason=%@ pid=%d bundleID=%@ executablePath=%@ bundlePath=%@ interestingImages=%@",
		processName,
		reason ?: @"(none)",
		[NSProcessInfo processInfo].processIdentifier,
		NSBundle.mainBundle.bundleIdentifier ?: @"(none)",
		NSBundle.mainBundle.executablePath ?: @"(none)",
		NSBundle.mainBundle.bundlePath ?: @"(none)",
		interestingImages]);
}

typedef id (*DWDictionaryInitializer)(id, SEL, const id __unsafe_unretained *, const id<NSCopying> __unsafe_unretained *, NSUInteger);

static id DWProbeDictionaryInitializer(id receiver, SEL selector,
	const id __unsafe_unretained *objects,
	const id<NSCopying> __unsafe_unretained *keys,
	NSUInteger count) {
	BOOL shouldSubstituteMissingObjects = NO;
	if (gDWTracingTemporaryBundle && !gDWInsideDictionaryProbe) {
		gDWInsideDictionaryProbe = YES;
		NSMutableString *details = [NSMutableString stringWithFormat:@"WallpaperKit dictionary construction count=%lu", (unsigned long)count];
		BOOL containsNil = NO;
		for (NSUInteger index = 0; index < count; index++) {
			id key = keys ? keys[index] : nil;
			id object = objects ? objects[index] : nil;
			if (!key || !object) containsNil = YES;
			[details appendFormat:@"\n  [%lu] key=%@ <%@> object=%@ <%@>",
				(unsigned long)index,
				key ?: @"(nil)",
				key ? NSStringFromClass([key class]) : @"nil",
				object ?: @"(nil)",
				object ? NSStringFromClass([object class]) : @"nil"];
		}
		if (containsNil) {
			[details appendFormat:@"\ncallStack=%@", NSThread.callStackSymbols];
			DWWriteBackendLog(details);
			shouldSubstituteMissingObjects = YES;
		}
		gDWInsideDictionaryProbe = NO;
	}

	if (shouldSubstituteMissingObjects) {
		id __unsafe_unretained *replacementObjects = (id __unsafe_unretained *)calloc(count, sizeof(id));
		id<NSCopying> __unsafe_unretained *replacementKeys = (id<NSCopying> __unsafe_unretained *)calloc(count, sizeof(id));
		NSMutableArray *retainedReplacements = [NSMutableArray array];
		for (NSUInteger index = 0; index < count; index++) {
			id key = keys ? keys[index] : nil;
			id object = objects ? objects[index] : nil;
			if (!key) {
				key = [NSString stringWithFormat:@"DuoWallProbeMissingKey%lu", (unsigned long)index];
				[retainedReplacements addObject:key];
			}
			if (!object) {
				object = [NSError errorWithDomain:@"DuoWallProbe"
					code:700 + (NSInteger)index
					userInfo:@{NSLocalizedDescriptionKey: @"WallpaperKit omitted its underlying error."}];
				[retainedReplacements addObject:object];
			}
			replacementKeys[index] = key;
			replacementObjects[index] = object;
		}
		DWWriteBackendLog(@"Substituting a probe NSError so WallpaperKit can finish constructing its outer error.");
		id result = ((DWDictionaryInitializer)gDWOriginalDictionaryInitializer)(receiver, selector, replacementObjects, replacementKeys, count);
		free(replacementObjects);
		free(replacementKeys);
		return result;
	}

	return ((DWDictionaryInitializer)gDWOriginalDictionaryInitializer)(receiver, selector, objects, keys, count);
}

static void DWInstallDictionaryProbe(void) {
	Class placeholderClass = NSClassFromString(@"__NSPlaceholderDictionary");
	SEL selector = @selector(initWithObjects:forKeys:count:);
	Method method = class_getInstanceMethod(placeholderClass, selector);
	if (!method || gDWOriginalDictionaryInitializer) return;
	gDWOriginalDictionaryInitializer = method_getImplementation(method);
	method_setImplementation(method, (IMP)DWProbeDictionaryInitializer);
}

static NSString *DWSummarizeDictionary(NSDictionary *dictionary) {
	if (!dictionary) return @"(nil)";
	NSMutableArray<NSString *> *entries = [NSMutableArray array];
	for (id key in dictionary) {
		id value = dictionary[key];
		NSString *valueSummary = nil;
		if ([value isKindOfClass:[NSDictionary class]]) {
			valueSummary = [NSString stringWithFormat:@"%@ %@", NSStringFromClass([value class]), DWSummarizeDictionary(value)];
		} else if ([value isKindOfClass:[NSArray class]]) {
			NSMutableArray *classes = [NSMutableArray array];
			for (id item in value) [classes addObject:NSStringFromClass([item class])];
			valueSummary = [NSString stringWithFormat:@"%@ itemClasses=%@", NSStringFromClass([value class]), classes];
		} else {
			valueSummary = [NSString stringWithFormat:@"%@ %@", value ? NSStringFromClass([value class]) : @"nil", value ?: @""];
		}
		[entries addObject:[NSString stringWithFormat:@"%@ <%@> = %@", key, NSStringFromClass([key class]), valueSummary]];
	}
	return [NSString stringWithFormat:@"{%@}", [entries componentsJoinedByString:@"; "]];
}

__attribute__((visibility("default"))) extern "C" void DuoWallResetBackendLog(void) {
	[[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Documents/DuoWall-backend-log.txt" error:nil];
}

__attribute__((visibility("default"))) extern "C" void DuoWallAppendBackendLogMarker(NSString *message) {
	DWWriteBackendLog([NSString stringWithFormat:@"===== %@ =====", message ?: @"DuoWall marker"]);
}

__attribute__((visibility("default"))) extern "C" void DuoWallInvalidateModernWallpaper(void) {
	gDWModernWallpaperBundle = nil;
	if (gDWGeneratedWallpaperBundlePath.length) {
		[[NSFileManager defaultManager] removeItemAtPath:gDWGeneratedWallpaperBundlePath error:nil];
	}
	[[NSFileManager defaultManager] removeItemAtPath:[DWStorageDirectory stringByAppendingPathComponent:@"Generated"] error:nil];
	[[NSFileManager defaultManager] removeItemAtPath:[DWStorageDirectory stringByAppendingPathComponent:@"Generated.wallpaper"] error:nil];
	gDWGeneratedWallpaperBundlePath = nil;
	DWWriteBackendLog(@"DuoWall invalidated generated wallpaper bundle cache.");
}

__attribute__((visibility("default"))) extern "C" void DuoWallLogCollectionsProbe(NSString *reason) {
	DWLogCollectionsManagerSnapshot(reason ?: @"external-probe");
}

__attribute__((visibility("default"))) extern "C" void DuoWallForceRestoreDescriptorBackups(NSString *reason) {
	NSString *label = reason.length ? reason : @"external-force";
	DWWriteBackendLog([NSString stringWithFormat:@"===== Force Restore Descriptor Backups: %@ =====", label]);
	DWRestoreBackedUpDescriptorsIfNeeded([NSString stringWithFormat:@"forced-%@", label]);
	DWLogPosterDescriptorStoreSnapshot([NSString stringWithFormat:@"forced-%@", label]);
}

__attribute__((visibility("default"))) extern "C" void DuoWallNotifyCollectionsChanged(NSString *reason) {
	DWPostCollectionsChangedNotification(reason ?: @"external");
}

static SBFWallpaperOptions *DWOptions(NSString *name, NSInteger wallpaperMode) {
	Class optionsClass = NSClassFromString(@"SBFWallpaperOptions");
	SBFWallpaperOptions *options = optionsClass ? [[optionsClass alloc] init] : nil;
	if ([options respondsToSelector:@selector(setWallpaperMode:)]) [options setWallpaperMode:wallpaperMode];
	if ([options respondsToSelector:@selector(setName:)]) [options setName:name];
	if ([options respondsToSelector:@selector(setParallaxFactor:)]) [options setParallaxFactor:1.0];
	return options;
}

static id DWCreateFileBackedWallpaperBundle(void) {
	Class bundleClass = NSClassFromString(@"WKWallpaperBundle");
	SEL builder = @selector(_createWallpaperBundleInDirectory:version:identifier:name:family:disableParallax:isOffloaded:logicalScreenClass:thumbnailImageURL:assetMapping:);
	if (![bundleClass respondsToSelector:builder]) {
		DWWriteBackendLog(@"WallpaperKit's file-backed bundle builder is unavailable.");
		return nil;
	}

	id lightWallpaper = DWWallpaper(NO);
	id darkWallpaper = DWWallpaper(YES);
	if (!lightWallpaper || !darkWallpaper) {
		DWWriteBackendLog(@"DuoWall could not create file-backed WKStillWallpaper objects.");
		return nil;
	}

	NSString *bundlePath = [DWStorageDirectory stringByAppendingPathComponent:@"Generated"];
	NSURL *bundleURL = [NSURL fileURLWithPath:bundlePath isDirectory:YES];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	[fileManager removeItemAtURL:bundleURL error:nil];
	[fileManager removeItemAtPath:[DWStorageDirectory stringByAppendingPathComponent:@"Generated.wallpaper"] error:nil];
	[fileManager createDirectoryAtPath:DWStorageDirectory withIntermediateDirectories:YES attributes:nil error:nil];
	[fileManager createDirectoryAtPath:bundlePath withIntermediateDirectories:YES attributes:nil error:nil];

	NSDictionary *assetMapping = @{
		@"WKWallpaperLocationCoverSheet": @{
			@"default": lightWallpaper,
			@"dark": darkWallpaper
		}
	};

	id bundle = nil;
	NSString *logicalScreenClass = DWCachedLogicalScreenClass();
	if (!logicalScreenClass.length) {
		DWWriteBackendLog(@"No cached logicalScreenClass is available yet, so DuoWall cannot finish the file-backed bundle build in Preferences.");
		return nil;
	}
	DWWriteBackendLog([NSString stringWithFormat:@"Using cached logicalScreenClass=%@ generatedIdentifier=%u", logicalScreenClass, 0x44555741u]);
	@try {
		bundle = [bundleClass _createWallpaperBundleInDirectory:bundleURL
			version:1
			identifier:0x44555741
			name:DWCurrentFriendlyName()
			family:DWCurrentFriendlyName()
			disableParallax:NO
			isOffloaded:NO
			logicalScreenClass:logicalScreenClass
			thumbnailImageURL:[NSURL fileURLWithPath:DWImagePath(NO)]
			assetMapping:assetMapping];
	} @catch (NSException *exception) {
		DWWriteBackendLog([NSString stringWithFormat:@"File-backed bundle builder exception: %@ — %@", exception.name, exception.reason]);
		return nil;
	}

	NSString *generatedBundlePath = nil;
	NSError *childrenError = nil;
	NSArray<NSString *> *children = [fileManager contentsOfDirectoryAtPath:bundlePath error:&childrenError];
	for (NSString *child in children) {
		if ([[child pathExtension].lowercaseString isEqualToString:@"wallpaper"]) {
			generatedBundlePath = [bundlePath stringByAppendingPathComponent:child];
			break;
		}
	}

	if (generatedBundlePath) {
		NSString *generatedDarkPath = [generatedBundlePath stringByAppendingPathComponent:DWDarkImageName];
		if (![fileManager fileExistsAtPath:generatedDarkPath]) {
			NSError *darkCopyError = nil;
			BOOL copiedDark = [fileManager copyItemAtPath:DWImagePath(YES) toPath:generatedDarkPath error:&darkCopyError];
			DWWriteBackendLog([NSString stringWithFormat:@"Ensured generated dark asset copied=%@ destination=%@ error=%@",
				copiedDark ? @"YES" : @"NO",
				generatedDarkPath,
				darkCopyError ?: @"(nil)"]);
		}
	}

	NSString *loadableBundlePath = generatedBundlePath;
	NSString *publishedCollectionPath = nil;
	if (generatedBundlePath) {
		for (NSString *candidatePath in DWCollectionPublishCandidatePaths()) {
			if (!candidatePath.length) continue;
			[fileManager createDirectoryAtPath:[candidatePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
			[fileManager removeItemAtPath:candidatePath error:nil];
			NSError *publishError = nil;
			BOOL published = DWCopyBundleAtPathToPath(generatedBundlePath, candidatePath, &publishError);
			DWWriteBackendLog([NSString stringWithFormat:@"Published DuoWall collection bundle published=%@ destination=%@ error=%@",
				published ? @"YES" : @"NO",
				candidatePath,
				publishError ?: @"(nil)"]);
			if (published) {
				publishedCollectionPath = candidatePath;
				loadableBundlePath = candidatePath;
				break;
			}
		}
	}

	if (loadableBundlePath) {
		gDWGeneratedWallpaperBundlePath = [loadableBundlePath copy];
		@try {
			bundle = [[bundleClass alloc] initWithURL:[NSURL fileURLWithPath:loadableBundlePath isDirectory:YES]];
		} @catch (NSException *exception) {
			DWWriteBackendLog([NSString stringWithFormat:@"Generated child bundle load exception: %@ — %@", exception.name, exception.reason]);
		}
	}

	NSError *contentsError = nil;
	NSArray *contents = [fileManager subpathsOfDirectoryAtPath:bundlePath error:&contentsError];
	NSDictionary *metadata = loadableBundlePath
		? [NSDictionary dictionaryWithContentsOfFile:[loadableBundlePath stringByAppendingPathComponent:@"Wallpaper.plist"]]
		: nil;
	DWWriteBackendLog([NSString stringWithFormat:@"File-backed builder resultClass=%@ result=%@ parentPath=%@ generatedBundlePath=%@ loadableBundlePath=%@ publishedCollectionPath=%@ childrenError=%@ contents=%@ contentsError=%@ metadata=%@",
		bundle ? NSStringFromClass([bundle class]) : @"nil",
		bundle ?: @"(nil)",
		bundlePath,
		generatedBundlePath ?: @"(nil)",
		loadableBundlePath ?: @"(nil)",
		publishedCollectionPath ?: @"(nil)",
		childrenError ?: @"(nil)",
		contents ?: @"(none)",
		contentsError ?: @"(nil)",
		metadata ?: @"(nil)"]);
	return bundle;
}

static id DWModernWallpaperBundle(void) {
	if (gDWModernWallpaperBundle) return gDWModernWallpaperBundle;
	if (gDWBuildingModernWallpaper) return nil;
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

	UIImage *appearanceImage = nil;
	SEL appearanceImageSelector = @selector(wk_imageWithLightAppearanceImage:darkAppearanceImage:);
	if ([UIImage respondsToSelector:appearanceImageSelector]) {
		appearanceImage = [UIImage wk_imageWithLightAppearanceImage:lightImage darkAppearanceImage:darkImage];
	}
	if (!appearanceImage) {
		UITraitCollection *lightTraits = [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight];
		UITraitCollection *darkTraits = [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark];
		UIImageAsset *asset = [[UIImageAsset alloc] init];
		[asset registerImage:lightImage withTraitCollection:lightTraits];
		[asset registerImage:darkImage withTraitCollection:darkTraits];
		appearanceImage = [asset imageWithTraitCollection:lightTraits];
	}
	if (!appearanceImage) {
		DWWriteBackendLog(@"DuoWall could not create an appearance-aware UIImage.");
		return nil;
	}

	// The temporary constructor takes location -> UIImage. The UIImage itself
	// carries the light/dark trait variants.
	NSDictionary *images = @{@"WKWallpaperLocationCoverSheet": appearanceImage};
	NSString *friendlyName = DWCurrentFriendlyName();
	SBFWallpaperOptions *lightOptions = DWOptions([NSString stringWithFormat:@"%@ Light", friendlyName], 1);
	NSDictionary *options = lightOptions ? @{@"WKWallpaperLocationCoverSheet": lightOptions} : @{};
	NSError *error = nil;

	@try {
		gDWTracingTemporaryBundle = YES;
		gDWModernWallpaperBundle = [bundleClass createTemporaryWallpaperBundleWithImages:images
			videoAssetURLs:@{}
			wallpaperOptions:options
			error:&error];
	} @catch (NSException *exception) {
		DWWriteBackendLog([NSString stringWithFormat:@"Temporary bundle exception: %@ — %@", exception.name, exception.reason]);
		return nil;
	} @finally {
		gDWTracingTemporaryBundle = NO;
	}

	if (!gDWModernWallpaperBundle) {
		DWWriteBackendLog([NSString stringWithFormat:@"Temporary bundle failed: %@", error.localizedDescription ?: @"unknown error"]);
		DWWriteBackendLog(@"Falling back to WallpaperKit's file-backed bundle builder.");
		gDWBuildingModernWallpaper = YES;
		@try {
			gDWModernWallpaperBundle = DWCreateFileBackedWallpaperBundle();
		} @finally {
			gDWBuildingModernWallpaper = NO;
		}
		if (!gDWModernWallpaperBundle) return nil;
	}

	DWWriteBackendLog([NSString stringWithFormat:@"Temporary appearance-aware bundle created: %@", gDWModernWallpaperBundle]);
	return gDWModernWallpaperBundle;
}

static BOOL DWSummaryRepresentsDuoWallDescriptor(NSDictionary *summary) {
	NSString *wallpaperFileName = [summary[@"userInfo"] isKindOfClass:[NSDictionary class]] ? summary[@"userInfo"][@"wallpaperRepresentingFileName"] : nil;
	NSString *wallpaperDirectoryName = summary[@"wallpaperDirectoryName"];
	NSDictionary *wallpaperCollectionMetadata = [summary[@"wallpaperCollectionMetadata"] isKindOfClass:[NSDictionary class]] ? summary[@"wallpaperCollectionMetadata"] : nil;
	NSString *collectionIdentifier = [wallpaperCollectionMetadata[@"wallpaperCollectionIdentifier"] isKindOfClass:[NSString class]] ? wallpaperCollectionMetadata[@"wallpaperCollectionIdentifier"] : nil;
	return ([wallpaperFileName containsString:@".DuoWall-"] ||
		[wallpaperDirectoryName containsString:@".DuoWall-"] ||
		DWDuoWallCollectionIdentifierMatches(collectionIdentifier));
}

static NSString *DWDuoWallDisplayNameForSummary(NSDictionary *summary) {
	NSDictionary *wallpaperCollectionMetadata = [summary[@"wallpaperCollectionMetadata"] isKindOfClass:[NSDictionary class]] ? summary[@"wallpaperCollectionMetadata"] : nil;
	NSString *collectionDisplayName = DWNormalizeFriendlyName(wallpaperCollectionMetadata[@"displayName"]);
	if (collectionDisplayName.length) return collectionDisplayName;
	NSDictionary *wallpaperPlist = [summary[@"wallpaperPlist"] isKindOfClass:[NSDictionary class]] ? summary[@"wallpaperPlist"] : nil;
	return DWNormalizeFriendlyName(wallpaperPlist[@"name"]);
}

static BOOL DWDuoWallCollectionIdentifierMatches(NSString *identifier) {
	if (![identifier isKindOfClass:[NSString class]] || !identifier.length) return NO;
	return [identifier isEqualToString:DWModernCollectionIdentifier] ||
		[identifier hasPrefix:[DWModernCollectionIdentifier stringByAppendingString:@"."]];
}

static BOOL DWIsAggregateDuoWallCollectionIdentifier(NSString *identifier) {
	return [identifier isKindOfClass:[NSString class]] && [identifier isEqualToString:DWModernCollectionIdentifier];
}

static NSString *DWDuoWallWallpaperBundlePathForSummary(NSDictionary *summary) {
	NSString *descriptorStoreRoot = DWPosterDescriptorStoreRootPath();
	NSString *descriptorName = summary[@"descriptorName"];
	NSString *selectedVersion = summary[@"selectedVersion"];
	NSString *wallpaperDirectoryName = summary[@"wallpaperDirectoryName"];
	if (!descriptorStoreRoot.length || !descriptorName.length || !selectedVersion.length || !wallpaperDirectoryName.length) return nil;
	return [[[[descriptorStoreRoot stringByAppendingPathComponent:descriptorName]
		stringByAppendingPathComponent:@"versions"]
		stringByAppendingPathComponent:selectedVersion]
		stringByAppendingPathComponent:[@"contents" stringByAppendingPathComponent:wallpaperDirectoryName]];
}

static id DWDuoWallBundleForSummary(NSDictionary *summary) {
	Class bundleClass = NSClassFromString(@"WKWallpaperBundle");
	if (!bundleClass) return nil;

	NSString *bundlePath = DWDuoWallWallpaperBundlePathForSummary(summary);
	if (!bundlePath.length) return nil;

	id bundle = nil;
	@try {
		bundle = [[bundleClass alloc] initWithURL:[NSURL fileURLWithPath:bundlePath]];
	} @catch (NSException *exception) {
		DWWriteBackendLog([NSString stringWithFormat:@"DuoWall collection bundle load exception path=%@ name=%@ reason=%@",
			bundlePath,
			exception.name ?: @"(nil)",
			exception.reason ?: @"(nil)"]);
		return nil;
	}
	if (!bundle) return nil;
	return bundle;
}

static NSString *DWAggregateDescriptorSignature(NSArray<NSString *> *children, NSString *descriptorStoreRoot) {
	if (!children.count || !descriptorStoreRoot.length) return @"";
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSMutableArray<NSString *> *parts = [NSMutableArray array];
	for (NSString *child in children) {
		NSString *descriptorPath = [descriptorStoreRoot stringByAppendingPathComponent:child];
		BOOL isDirectory = NO;
		if (![fileManager fileExistsAtPath:descriptorPath isDirectory:&isDirectory] || !isDirectory) continue;
		NSDictionary *summary = DWPosterDescriptorSummaryAtPath(descriptorPath);
		if (!DWSummaryRepresentsDuoWallDescriptor(summary)) continue;
		NSString *name = DWDuoWallDisplayNameForSummary(summary) ?: @"(unnamed)";
		NSString *bundlePath = DWDuoWallWallpaperBundlePathForSummary(summary) ?: @"(no-bundle)";
		NSString *identifierFile = [summary[@"identifierFile"] isKindOfClass:[NSString class]] ? summary[@"identifierFile"] : @"(no-id)";
		[parts addObject:[NSString stringWithFormat:@"%@|%@|%@", child, name, identifierFile.length ? identifierFile : bundlePath]];
	}
	return [parts componentsJoinedByString:@"||"];
}

__attribute__((unused)) static id DWAggregateDuoWallCollection(void) {
	Class collectionClass = NSClassFromString(@"WKWallpaperRepresentingCollection");
	Class downloadManagerClass = NSClassFromString(@"WKWallpaperBundleDownloadManager");
	if (!collectionClass) return nil;

	NSString *descriptorStoreRoot = DWPosterDescriptorStoreRootPath();
	if (!descriptorStoreRoot.length) return nil;

	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray<NSString *> *children = [[fileManager contentsOfDirectoryAtPath:descriptorStoreRoot error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)] ?: @[];
	NSString *signature = DWAggregateDescriptorSignature(children, descriptorStoreRoot);
	if (gDWCachedAggregateCollection && gDWCachedAggregateCollectionSignature && [gDWCachedAggregateCollectionSignature isEqualToString:signature]) {
		return gDWCachedAggregateCollection;
	}
	NSMutableArray *bundles = [NSMutableArray array];
	NSMutableDictionary *lookup = [NSMutableDictionary dictionary];
	NSString *latestDisplayName = @"DuoWall";
	id previewBundle = nil;

	for (NSString *child in children) {
		NSString *descriptorPath = [descriptorStoreRoot stringByAppendingPathComponent:child];
		BOOL isDirectory = NO;
		if (![fileManager fileExistsAtPath:descriptorPath isDirectory:&isDirectory] || !isDirectory) continue;
		NSDictionary *summary = DWPosterDescriptorSummaryAtPath(descriptorPath);
		if (!DWSummaryRepresentsDuoWallDescriptor(summary)) continue;
		id bundle = DWDuoWallBundleForSummary(summary);
		if (!bundle) continue;
		[bundles addObject:bundle];
		latestDisplayName = DWDuoWallDisplayNameForSummary(summary) ?: latestDisplayName;
		previewBundle = bundle;

		NSString *bundleIdentifierString = nil;
		NSNumber *bundleIdentifierNumber = nil;
		@try {
			id rawIdentifier = [bundle valueForKey:@"identifier"];
			if ([rawIdentifier isKindOfClass:[NSNumber class]]) {
				bundleIdentifierNumber = rawIdentifier;
				bundleIdentifierString = [rawIdentifier stringValue];
			} else if ([rawIdentifier isKindOfClass:[NSString class]]) {
				bundleIdentifierString = rawIdentifier;
				bundleIdentifierNumber = @([(NSString *)rawIdentifier integerValue]);
			}
		} @catch (__unused NSException *exception) {}
		if (!bundleIdentifierString.length) {
			NSString *identifierFile = [summary[@"identifierFile"] isKindOfClass:[NSString class]] ? summary[@"identifierFile"] : nil;
			if (identifierFile.length && ![identifierFile isEqualToString:@"(nil)"]) {
				bundleIdentifierString = identifierFile;
				bundleIdentifierNumber = @([identifierFile integerValue]);
			}
		}
		if (bundleIdentifierString.length) lookup[bundleIdentifierString] = bundle;
		if (bundleIdentifierNumber) lookup[bundleIdentifierNumber] = bundle;
	}

	if (!bundles.count || !previewBundle) return nil;

	id downloadManager = [downloadManagerClass respondsToSelector:@selector(defaultManager)] ? [downloadManagerClass defaultManager] : nil;
	id collection = nil;
	@try {
		collection = [[collectionClass alloc] initWithWallpaperCollectionIdentifier:DWModernCollectionIdentifier
			displayName:@"DuoWall"
			previewWallpaperRepresenting:previewBundle
			wallpapersShareBaseAppearance:YES
			wallpaperRepresentingCollection:bundles
			downloadManager:downloadManager];
	} @catch (NSException *exception) {
		DWWriteBackendLog([NSString stringWithFormat:@"Aggregate DuoWall collection creation exception name=%@ reason=%@",
			exception.name ?: @"(nil)",
			exception.reason ?: @"(nil)"]);
		return nil;
	}

	if ([collection respondsToSelector:@selector(setWallpaperCollectionIdentifier:)]) {
		((void (*)(id, SEL, id))objc_msgSend)(collection, @selector(setWallpaperCollectionIdentifier:), DWModernCollectionIdentifier);
	}
	DWSetValueSafely(collection, @"displayName", @"DuoWall");
	DWSetValueSafely(collection, @"previewWallpaperRepresenting", previewBundle);
	if ([collection respondsToSelector:@selector(set_wallpaperBundles:)]) {
		((void (*)(id, SEL, id))objc_msgSend)(collection, @selector(set_wallpaperBundles:), bundles);
	}
	if ([collection respondsToSelector:@selector(set_wallpaperLookupTable:)]) {
		((void (*)(id, SEL, id))objc_msgSend)(collection, @selector(set_wallpaperLookupTable:), lookup);
	}

	DWWriteBackendLog([NSString stringWithFormat:@"[%@] Built aggregate DuoWall collection bundleCount=%@ latestDisplayName=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		@(bundles.count),
		latestDisplayName ?: @"(nil)"]);
	gDWCachedAggregateCollection = collection;
	gDWCachedAggregateCollectionSignature = [signature copy];
	return collection;
}

static NSArray *DWInstalledDuoWallBundles(void) {
	NSString *descriptorStoreRoot = DWPosterDescriptorStoreRootPath();
	if (!descriptorStoreRoot.length) return @[];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray<NSString *> *children = [[fileManager contentsOfDirectoryAtPath:descriptorStoreRoot error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)] ?: @[];
	NSMutableArray *bundles = [NSMutableArray array];
	NSMutableArray *names = [NSMutableArray array];
	for (NSString *child in children) {
		NSString *descriptorPath = [descriptorStoreRoot stringByAppendingPathComponent:child];
		BOOL isDirectory = NO;
		if (![fileManager fileExistsAtPath:descriptorPath isDirectory:&isDirectory] || !isDirectory) continue;
		NSDictionary *summary = DWPosterDescriptorSummaryAtPath(descriptorPath);
		if (!DWSummaryRepresentsDuoWallDescriptor(summary)) continue;
		id bundle = DWDuoWallBundleForSummary(summary);
		if (bundle) {
			[bundles addObject:bundle];
			[names addObject:DWDuoWallDisplayNameForSummary(summary) ?: @"(unnamed)"];
		}
	}

	DWWriteBackendLog([NSString stringWithFormat:@"[%@] Installed DuoWall bundle scan count=%@ names=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		@(bundles.count),
		names ?: @[]]);
	return bundles;
}

static NSArray *DWInstalledDuoWallCollections(void) {
	Class collectionClass = NSClassFromString(@"WKWallpaperRepresentingCollection");
	Class downloadManagerClass = NSClassFromString(@"WKWallpaperBundleDownloadManager");
	if (!collectionClass) return @[];

	NSString *descriptorStoreRoot = DWPosterDescriptorStoreRootPath();
	if (!descriptorStoreRoot.length) return @[];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray<NSString *> *children = [[fileManager contentsOfDirectoryAtPath:descriptorStoreRoot error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)] ?: @[];
	NSMutableArray *collections = [NSMutableArray array];
	id downloadManager = [downloadManagerClass respondsToSelector:@selector(defaultManager)] ? [downloadManagerClass defaultManager] : nil;

	for (NSString *child in children) {
		NSString *descriptorPath = [descriptorStoreRoot stringByAppendingPathComponent:child];
		BOOL isDirectory = NO;
		if (![fileManager fileExistsAtPath:descriptorPath isDirectory:&isDirectory] || !isDirectory) continue;
		NSDictionary *summary = DWPosterDescriptorSummaryAtPath(descriptorPath);
		if (!DWSummaryRepresentsDuoWallDescriptor(summary)) continue;
		id bundle = DWDuoWallBundleForSummary(summary);
		if (!bundle) continue;

		NSString *displayName = DWDuoWallDisplayNameForSummary(summary) ?: @"DuoWall";
		NSString *collectionIdentifier = [DWModernCollectionIdentifier stringByAppendingFormat:@".%@", child];

		id collection = nil;
		BOOL usedURLBackedCollection = NO;
		if ([collectionClass instancesRespondToSelector:@selector(initWithURL:downloadManager:)]) {
			@try {
				collection = [[collectionClass alloc] initWithURL:[NSURL fileURLWithPath:descriptorPath] downloadManager:downloadManager];
				usedURLBackedCollection = (collection != nil);
			} @catch (NSException *exception) {
				DWWriteBackendLog([NSString stringWithFormat:@"URL-backed DuoWall collection creation exception path=%@ id=%@ name=%@ reason=%@",
					descriptorPath,
					collectionIdentifier,
					displayName,
					exception.reason ?: exception.name]);
				collection = nil;
			}
			if (!collection && DWMigrateDescriptorCollectionMetadataIfNeeded(descriptorPath, [NSString stringWithFormat:@"url-init-%@", collectionIdentifier])) {
				@try {
					collection = [[collectionClass alloc] initWithURL:[NSURL fileURLWithPath:descriptorPath] downloadManager:downloadManager];
					usedURLBackedCollection = (collection != nil);
					DWWriteBackendLog([NSString stringWithFormat:@"URL-backed DuoWall collection retry path=%@ id=%@ name=%@ success=%@",
						descriptorPath,
						collectionIdentifier,
						displayName,
						collection ? @"YES" : @"NO"]);
				} @catch (NSException *exception) {
					DWWriteBackendLog([NSString stringWithFormat:@"URL-backed DuoWall collection retry exception path=%@ id=%@ name=%@ reason=%@",
						descriptorPath,
						collectionIdentifier,
						displayName,
						exception.reason ?: exception.name]);
					collection = nil;
				}
			}
		}

		if (!collection) {
		@try {
			collection = [[collectionClass alloc] initWithWallpaperCollectionIdentifier:collectionIdentifier
				displayName:displayName
				previewWallpaperRepresenting:bundle
				wallpapersShareBaseAppearance:YES
				wallpaperRepresentingCollection:@[bundle]
				downloadManager:downloadManager];
		} @catch (NSException *exception) {
			DWWriteBackendLog([NSString stringWithFormat:@"Sibling DuoWall collection creation exception id=%@ name=%@ reason=%@",
				collectionIdentifier,
				displayName,
				exception.reason ?: exception.name]);
			continue;
		}
		}

		if ([collection respondsToSelector:@selector(setWallpaperCollectionIdentifier:)]) {
			((void (*)(id, SEL, id))objc_msgSend)(collection, @selector(setWallpaperCollectionIdentifier:), collectionIdentifier);
		}
		DWSetValueSafely(collection, @"displayName", displayName);
		DWSetValueSafely(collection, @"previewWallpaperRepresenting", bundle);
		if ([collection respondsToSelector:@selector(set_wallpaperBundles:)]) {
			((void (*)(id, SEL, id))objc_msgSend)(collection, @selector(set_wallpaperBundles:), @[bundle]);
		}
		if ([collection respondsToSelector:@selector(set_wallpaperLookupTable:)]) {
			NSMutableDictionary *lookup = [NSMutableDictionary dictionary];
			@try {
				id rawIdentifier = [bundle valueForKey:@"identifier"];
				if ([rawIdentifier isKindOfClass:[NSNumber class]]) {
					lookup[rawIdentifier] = bundle;
					lookup[[rawIdentifier stringValue]] = bundle;
				} else if ([rawIdentifier isKindOfClass:[NSString class]]) {
					lookup[rawIdentifier] = bundle;
				}
			} @catch (__unused NSException *exception) {}
			((void (*)(id, SEL, id))objc_msgSend)(collection, @selector(set_wallpaperLookupTable:), lookup);
		}

		DWWriteBackendLog([NSString stringWithFormat:@"[%@] Prepared DuoWall collection id=%@ name=%@ descriptorPath=%@ mode=%@",
			NSProcessInfo.processInfo.processName ?: @"Unknown",
			collectionIdentifier,
			displayName,
			descriptorPath,
			usedURLBackedCollection ? @"url-backed" : @"manual"]);
		[collections addObject:collection];
	}

	DWWriteBackendLog([NSString stringWithFormat:@"[%@] Built sibling DuoWall collections count=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		@(collections.count)]);
	return collections;
}

static NSArray *DWCollectionsByAppendingDuoWallIfNeeded(id collections) {
	if (![collections isKindOfClass:[NSArray class]]) return collections;

	NSArray *baseCollections = (NSArray *)collections;
	NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
	NSMutableArray *augmentedCollections = [NSMutableArray array];
	for (id collection in baseCollections) {
		@try {
			if ([collection respondsToSelector:@selector(wallpaperCollectionIdentifier)]) {
				NSString *identifier = [collection wallpaperCollectionIdentifier];
				if (DWDuoWallCollectionIdentifierMatches(identifier)) continue;
			}
		} @catch (__unused NSException *exception) {}
		[augmentedCollections addObject:collection];
	}

	NSMutableArray<NSString *> *addedNames = [NSMutableArray array];
	for (id collection in DWInstalledDuoWallCollections()) {
		[augmentedCollections addObject:collection];
		@try {
			NSString *displayName = [collection valueForKey:@"displayName"];
			[addedNames addObject:displayName ?: @"DuoWall"];
		} @catch (__unused NSException *exception) {
			[addedNames addObject:@"DuoWall"];
		}
	}

	DWWriteBackendLog([NSString stringWithFormat:@"[%@] Augmented collection list original=%@ added=%@ final=%@ names=%@",
		processName,
		@(baseCollections.count),
		@(addedNames.count),
		@(augmentedCollections.count),
		addedNames ?: @[]]);
	return augmentedCollections;
}

static id DWCollectionLookupByAppendingDuoWallIfNeeded(id lookup) {
	NSMutableDictionary *dictionaryLookup = nil;
	id mapTableLookup = nil;
	Class mapTableClass = NSClassFromString(@"NSMapTable");
	if ([lookup isKindOfClass:[NSDictionary class]]) {
		dictionaryLookup = [((NSDictionary *)lookup) mutableCopy];
	} else if (mapTableClass && [lookup isKindOfClass:mapTableClass]) {
		mapTableLookup = lookup;
	}
	if (!dictionaryLookup && !mapTableLookup) return lookup;

	NSMutableArray *keysToRemove = [NSMutableArray array];
	if (dictionaryLookup) {
		for (id key in dictionaryLookup.allKeys) {
			if (DWDuoWallCollectionIdentifierMatches(key)) [keysToRemove addObject:key];
		}
		[dictionaryLookup removeObjectsForKeys:keysToRemove];
	} else if (mapTableLookup) {
		for (id key in @[
			DWModernCollectionIdentifier
		]) {
			[mapTableLookup removeObjectForKey:key];
		}
	}

	NSUInteger addedCount = 0;
	for (id collection in DWInstalledDuoWallCollections()) {
		NSString *identifier = nil;
		@try {
			if ([collection respondsToSelector:@selector(wallpaperCollectionIdentifier)]) {
				identifier = [collection wallpaperCollectionIdentifier];
			}
		} @catch (__unused NSException *exception) {}
		if (!identifier.length) continue;
		if (dictionaryLookup) {
			dictionaryLookup[identifier] = collection;
		} else if (mapTableLookup) {
			[mapTableLookup setObject:collection forKey:identifier];
		}
		addedCount += 1;
	}

	DWWriteBackendLog([NSString stringWithFormat:@"[%@] Augmented collection lookup added=%@ backingClass=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		@(addedCount),
		lookup ? NSStringFromClass([lookup class]) : @"nil"]);
	return dictionaryLookup ?: mapTableLookup ?: lookup;
}

static id DWAugmentedWallpapersForCollectionsCategory(id wallpapers, NSString *identifier, NSString *displayName) {
	BOOL matchesCollectionsBucket = [displayName isKindOfClass:[NSString class]] && [displayName caseInsensitiveCompare:@"Collections"] == NSOrderedSame;
	if (!matchesCollectionsBucket) return wallpapers;

	NSArray *duoWallBundles = DWInstalledDuoWallBundles();
	if (!duoWallBundles.count) return wallpapers;

	NSMutableArray *mutableWallpapers = [NSMutableArray array];
	if ([wallpapers isKindOfClass:[NSArray class]]) {
		[mutableWallpapers addObjectsFromArray:(NSArray *)wallpapers];
	} else if ([wallpapers respondsToSelector:@selector(numberOfItems)] && [wallpapers respondsToSelector:@selector(wallpaperBundleAtIndex:)]) {
		long long count = ((long long (*)(id, SEL))objc_msgSend)(wallpapers, @selector(numberOfItems));
		for (long long index = 0; index < count; index++) {
			id bundle = ((id (*)(id, SEL, unsigned long long))objc_msgSend)(wallpapers, @selector(wallpaperBundleAtIndex:), (unsigned long long)index);
			if (bundle) [mutableWallpapers addObject:bundle];
		}
	}

	NSMutableSet *existingPaths = [NSMutableSet set];
	for (id existing in mutableWallpapers) {
		@try {
			id url = [existing valueForKey:@"url"];
			if ([url respondsToSelector:@selector(path)] && [url path]) [existingPaths addObject:[url path]];
		} @catch (__unused NSException *exception) {}
	}

	for (id bundle in duoWallBundles) {
		NSString *path = nil;
		@try {
			id url = [bundle valueForKey:@"url"];
			if ([url respondsToSelector:@selector(path)]) path = [url path];
		} @catch (__unused NSException *exception) {}
		if (path.length && [existingPaths containsObject:path]) continue;
		if (path.length) [existingPaths addObject:path];
		[mutableWallpapers addObject:bundle];
	}

	DWWriteBackendLog([NSString stringWithFormat:@"[%@] Augmented Collections bucket identifier=%@ displayName=%@ originalClass=%@ originalCount=%@ augmentedCount=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		identifier ?: @"(nil)",
		displayName ?: @"(nil)",
		wallpapers ? NSStringFromClass([wallpapers class]) : @"nil",
		[wallpapers respondsToSelector:@selector(count)] ? @([wallpapers count]) : ([wallpapers respondsToSelector:@selector(numberOfItems)] ? @(((long long (*)(id, SEL))objc_msgSend)(wallpapers, @selector(numberOfItems))) : @"(n/a)"),
		@(mutableWallpapers.count)]);

	return mutableWallpapers;
}

static NSString *DWSummarizeWallpaperCollection(id collection) {
	if (!collection) return @"(nil)";
	NSString *identifier = nil;
	NSString *displayName = nil;
	id wallpapers = nil;
	@try {
		if ([collection respondsToSelector:@selector(wallpaperCollectionIdentifier)]) {
			identifier = [collection wallpaperCollectionIdentifier];
		}
		if ([collection respondsToSelector:NSSelectorFromString(@"displayName")]) {
			displayName = ((id (*)(id, SEL))objc_msgSend)(collection, NSSelectorFromString(@"displayName"));
		} else {
			@try { displayName = [collection valueForKey:@"displayName"]; } @catch (__unused NSException *e) {}
		}
		if ([collection respondsToSelector:NSSelectorFromString(@"wallpaperRepresentingCollection")]) {
			wallpapers = ((id (*)(id, SEL))objc_msgSend)(collection, NSSelectorFromString(@"wallpaperRepresentingCollection"));
		} else {
			@try { wallpapers = [collection valueForKey:@"wallpaperRepresentingCollection"]; } @catch (__unused NSException *e) {}
		}
	} @catch (__unused NSException *exception) {}
	return [NSString stringWithFormat:@"<%@ identifier=%@ displayName=%@ wallpapersClass=%@ wallpapersCount=%@>",
		NSStringFromClass([collection class]),
		identifier ?: @"(nil)",
		displayName ?: @"(nil)",
		wallpapers ? NSStringFromClass([wallpapers class]) : @"nil",
		[wallpapers respondsToSelector:@selector(count)] ? @([wallpapers count]) : @"(n/a)"];
}

static void DWLogCollectionsManagerSnapshot(NSString *reason) {
	Class managerClass = NSClassFromString(@"WKWallpaperRepresentingCollectionsManager");
	NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
	if (!managerClass) {
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] Collections probe reason=%@ managerClass=nil",
			processName, reason ?: @"(unknown)"]);
		return;
	}

	NSArray<NSString *> *factories = @[@"defaultManager", @"defaultLegacyManager"];
	for (NSString *factoryName in factories) {
		SEL factorySEL = NSSelectorFromString(factoryName);
		if (![managerClass respondsToSelector:factorySEL]) continue;
		id manager = ((id (*)(id, SEL))objc_msgSend)(managerClass, factorySEL);
		NSInteger count = [manager respondsToSelector:@selector(numberOfWallpaperCollections)] ? ((NSInteger (*)(id, SEL))objc_msgSend)(manager, @selector(numberOfWallpaperCollections)) : NSNotFound;
		id lookup = [manager respondsToSelector:@selector(_wallpaperCollectionLookupTable)] ? ((id (*)(id, SEL))objc_msgSend)(manager, @selector(_wallpaperCollectionLookupTable)) : nil;
		id collections = [manager respondsToSelector:@selector(_wallpaperCollections)] ? ((id (*)(id, SEL))objc_msgSend)(manager, @selector(_wallpaperCollections)) : nil;
		id duoWallCollection = nil;
		NSMutableArray<NSString *> *samples = [NSMutableArray array];
		NSInteger sampleCount = (count == NSNotFound) ? 0 : MIN((NSInteger)3, count);
		for (NSInteger index = 0; index < sampleCount; index++) {
			id collection = [manager respondsToSelector:@selector(wallpaperCollectionAtIndex:)] ? ((id (*)(id, SEL, NSInteger))objc_msgSend)(manager, @selector(wallpaperCollectionAtIndex:), index) : nil;
			[samples addObject:DWSummarizeWallpaperCollection(collection)];
		}
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] Collections probe reason=%@ factory=%@ manager=%@ count=%@ collectionsClass=%@ collectionsCount=%@ lookupClass=%@ lookupCount=%@ duoWallCollection=%@ samples=%@",
			processName,
			reason ?: @"(unknown)",
			factoryName,
			manager ?: @"(nil)",
			(count == NSNotFound) ? @"(n/a)" : @(count),
			collections ? NSStringFromClass([collections class]) : @"nil",
			[collections respondsToSelector:@selector(count)] ? @([collections count]) : @"(n/a)",
			lookup ? NSStringFromClass([lookup class]) : @"nil",
			[lookup respondsToSelector:@selector(count)] ? @([lookup count]) : @"(n/a)",
			DWSummarizeWallpaperCollection(duoWallCollection),
			samples]);
	}
}

static NSArray<NSString *> *DWCollectionPublishCandidatePaths(void) {
	NSMutableOrderedSet<NSString *> *paths = [NSMutableOrderedSet orderedSet];

	Class currentManagerClass = NSClassFromString(@"WKCurrentWallpaperManager");
	id currentManager = [currentManagerClass respondsToSelector:@selector(sharedCurrentWallpaperManager)] ? [currentManagerClass sharedCurrentWallpaperManager] : nil;
	NSURL *collectionsDirectoryURL = [currentManager respondsToSelector:@selector(wallpaperCollectionsDirectoryURL)] ? [currentManager wallpaperCollectionsDirectoryURL] : nil;
	if (collectionsDirectoryURL.path.length) {
		[paths addObject:[collectionsDirectoryURL.path stringByAppendingPathComponent:@"DuoWall.wallpaper"]];
	}

	Class defaultManagerClass = NSClassFromString(@"WKDefaultWallpaperManager");
	NSURL *defaultLookupURL = [defaultManagerClass respondsToSelector:@selector(defaultWallpaperLookupURL)] ? [defaultManagerClass defaultWallpaperLookupURL] : nil;
	if (defaultLookupURL.path.length) {
		NSString *lookupPath = defaultLookupURL.path;
		NSString *lookupDir = [lookupPath stringByDeletingLastPathComponent];
		NSString *parentDir = [lookupDir stringByDeletingLastPathComponent];
		[paths addObject:[lookupDir stringByAppendingPathComponent:@"DuoWall.wallpaper"]];
		[paths addObject:[lookupDir stringByAppendingPathComponent:@"Collections/DuoWall.wallpaper"]];
		[paths addObject:[lookupDir stringByAppendingPathComponent:@"WallpaperCollections/DuoWall.wallpaper"]];
		[paths addObject:[parentDir stringByAppendingPathComponent:@"WallpaperCollections/DuoWall.wallpaper"]];
		[paths addObject:[parentDir stringByAppendingPathComponent:@"Collections/DuoWall.wallpaper"]];
		DWWriteBackendLog([NSString stringWithFormat:@"defaultWallpaperLookupURL=%@", defaultLookupURL]);
	}

	DWWriteBackendLog([NSString stringWithFormat:@"Collection publish candidate paths=%@", paths.array]);
	return paths.array;
}

static BOOL DWCopyBundleAtPathToPath(NSString *sourcePath, NSString *destinationPath, NSError **error) {
	if (!sourcePath.length || !destinationPath.length) {
		if (error) {
			*error = [NSError errorWithDomain:@"DuoWall"
				code:701
				userInfo:@{NSLocalizedDescriptionKey: @"Missing source or destination path while publishing DuoWall collection bundle."}];
		}
		return NO;
	}

	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL sourceIsDirectory = NO;
	if (![fileManager fileExistsAtPath:sourcePath isDirectory:&sourceIsDirectory] || !sourceIsDirectory) {
		if (error) {
			*error = [NSError errorWithDomain:@"DuoWall"
				code:702
				userInfo:@{
					NSLocalizedDescriptionKey: @"Source DuoWall wallpaper bundle no longer exists before publish attempt.",
					NSFilePathErrorKey: sourcePath
				}];
		}
		return NO;
	}

	if (![fileManager createDirectoryAtPath:destinationPath withIntermediateDirectories:YES attributes:nil error:error]) {
		return NO;
	}

	NSArray<NSString *> *children = [fileManager contentsOfDirectoryAtPath:sourcePath error:error];
	if (!children) return NO;

	for (NSString *child in children) {
		NSString *sourceChild = [sourcePath stringByAppendingPathComponent:child];
		NSString *destinationChild = [destinationPath stringByAppendingPathComponent:child];
		[fileManager removeItemAtPath:destinationChild error:nil];

		BOOL childIsDirectory = NO;
		[fileManager fileExistsAtPath:sourceChild isDirectory:&childIsDirectory];
		BOOL copied = childIsDirectory
			? DWCopyBundleAtPathToPath(sourceChild, destinationChild, error)
			: [fileManager copyItemAtPath:sourceChild toPath:destinationChild error:error];
		if (!copied) return NO;
	}

	return YES;
}

static NSString *DWDescriptorBackupRootPath(void) {
	return [DWStorageDirectory stringByAppendingPathComponent:@"DescriptorBackups"];
}

static BOOL DWIsStartupRestoreReason(NSString *reason) {
	return [reason isEqualToString:@"ctor"];
}

static NSInteger DWSanitizedCollectionOrderValue(NSString *collectionIdentifier, NSString *wallpaperIdentifierString, NSNumber *wallpaperIdentifierNumber) {
	NSInteger orderValue = wallpaperIdentifierNumber ? [wallpaperIdentifierNumber integerValue] : 0;
	if (orderValue <= 0 && wallpaperIdentifierString.length) {
		orderValue = [wallpaperIdentifierString integerValue];
	}
	if (orderValue < 0) {
		orderValue = llabs((long long)orderValue);
	}
	if (orderValue <= 0 && collectionIdentifier.length) {
		orderValue = llabs((long long)collectionIdentifier.hash);
	}
	if (orderValue <= 0) {
		orderValue = 1;
	}
	return ((orderValue - 1) % 999) + 1;
}

static BOOL DWMigrateDescriptorCollectionMetadataIfNeeded(NSString *descriptorPath, NSString *reason) {
	if (!descriptorPath.length) return NO;

	NSDictionary *summary = DWPosterDescriptorSummaryAtPath(descriptorPath);
	if (!DWSummaryRepresentsDuoWallDescriptor(summary)) return NO;

	NSDictionary *existingMetadata = [summary[@"wallpaperCollectionMetadata"] isKindOfClass:[NSDictionary class]] ? summary[@"wallpaperCollectionMetadata"] : nil;
	NSString *existingIdentifier = [existingMetadata[@"wallpaperCollectionIdentifier"] isKindOfClass:[NSString class]] ? existingMetadata[@"wallpaperCollectionIdentifier"] : nil;
	NSString *existingDisplayName = [existingMetadata[@"displayName"] isKindOfClass:[NSString class]] ? existingMetadata[@"displayName"] : nil;
	id existingOrder = existingMetadata[@"order"];
	BOOL hasValidOrder = [existingOrder isKindOfClass:[NSNumber class]] ? ([existingOrder integerValue] > 0) : NO;
	if (!hasValidOrder && [existingOrder isKindOfClass:[NSString class]]) {
		hasValidOrder = ([(NSString *)existingOrder integerValue] > 0);
	}
	if (existingIdentifier.length && existingDisplayName.length && hasValidOrder) return NO;

	NSString *descriptorName = [summary[@"descriptorName"] isKindOfClass:[NSString class]] ? summary[@"descriptorName"] : [descriptorPath lastPathComponent];
	if (!descriptorName.length) return NO;

	NSString *collectionIdentifier = [DWModernCollectionIdentifier stringByAppendingFormat:@".%@", descriptorName];
	NSString *displayName = DWDuoWallDisplayNameForSummary(summary) ?: @"DuoWall";
	NSString *identifierString = [summary[@"identifierFile"] isKindOfClass:[NSString class]] ? summary[@"identifierFile"] : nil;
	if ([identifierString isEqualToString:@"(nil)"]) identifierString = nil;
	NSNumber *identifierNumber = identifierString.length ? @([identifierString integerValue]) : nil;
	NSInteger sanitizedOrder = DWSanitizedCollectionOrderValue(collectionIdentifier, identifierString, identifierNumber);
	if (existingIdentifier.length && existingDisplayName.length && hasValidOrder) {
		NSInteger existingOrderValue = [existingOrder respondsToSelector:@selector(integerValue)] ? [existingOrder integerValue] : 0;
		if (existingOrderValue == sanitizedOrder) return NO;
	}
	NSDictionary *metadata = DWWallpaperCollectionMetadata(collectionIdentifier, displayName, identifierString, identifierNumber);
	NSString *metadataPath = [descriptorPath stringByAppendingPathComponent:@"WallpaperCollection.plist"];
	BOOL wrote = [metadata writeToFile:metadataPath atomically:YES];
	DWWriteBackendLog([NSString stringWithFormat:@"Migrate DuoWall collection metadata reason=%@ wrote=%@ descriptorPath=%@ metadata=%@",
		reason ?: @"(nil)",
		wrote ? @"YES" : @"NO",
		descriptorPath,
		metadata ?: @{}]);
	return wrote;
}

static NSUInteger DWMigrateMissingCollectionMetadataAtRoot(NSString *rootPath, NSString *reason) {
	if (!rootPath.length) return 0;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDirectory = NO;
	if (![fileManager fileExistsAtPath:rootPath isDirectory:&isDirectory] || !isDirectory) return 0;

	NSArray<NSString *> *children = [[fileManager contentsOfDirectoryAtPath:rootPath error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)] ?: @[];
	NSUInteger migratedCount = 0;
	for (NSString *child in children) {
		NSString *descriptorPath = [rootPath stringByAppendingPathComponent:child];
		BOOL childIsDirectory = NO;
		if (![fileManager fileExistsAtPath:descriptorPath isDirectory:&childIsDirectory] || !childIsDirectory) continue;
		if (DWMigrateDescriptorCollectionMetadataIfNeeded(descriptorPath, reason)) {
			migratedCount += 1;
		}
	}

	if (migratedCount > 0) {
		DWWriteBackendLog([NSString stringWithFormat:@"Migrated %@ DuoWall descriptor metadata files root=%@ reason=%@",
			@(migratedCount),
			rootPath,
			reason ?: @"(nil)"]);
	}
	return migratedCount;
}

static void DWBackupDescriptorDirectoryIfNeeded(NSString *descriptorDirectoryPath) {
	if (!descriptorDirectoryPath.length) return;
	NSString *descriptorName = [descriptorDirectoryPath lastPathComponent];
	if (!descriptorName.length) return;

	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *backupRoot = DWDescriptorBackupRootPath();
	[fileManager createDirectoryAtPath:backupRoot withIntermediateDirectories:YES attributes:nil error:nil];
	NSString *backupPath = [backupRoot stringByAppendingPathComponent:descriptorName];
	[fileManager removeItemAtPath:backupPath error:nil];
	NSError *error = nil;
	BOOL copied = DWCopyBundleAtPathToPath(descriptorDirectoryPath, backupPath, &error);
	DWWriteBackendLog([NSString stringWithFormat:@"Backed up DuoWall descriptor copied=%@ source=%@ destination=%@ error=%@",
		copied ? @"YES" : @"NO",
		descriptorDirectoryPath,
		backupPath,
		error ?: @"(nil)"]);
}

static void DWRestoreBackedUpDescriptorsIfNeeded(NSString *reason) {
	NSString *descriptorStoreRoot = DWPosterDescriptorStoreRootPath();
	if (!descriptorStoreRoot.length) return;

	NSString *backupRoot = DWDescriptorBackupRootPath();
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL backupIsDirectory = NO;
	if (![fileManager fileExistsAtPath:backupRoot isDirectory:&backupIsDirectory] || !backupIsDirectory) return;

	NSUInteger migratedBackupCount = DWMigrateMissingCollectionMetadataAtRoot(backupRoot, [NSString stringWithFormat:@"backup-%@", reason ?: @"(nil)"]);
	NSUInteger migratedLiveCountPreRestore = DWMigrateMissingCollectionMetadataAtRoot(descriptorStoreRoot, [NSString stringWithFormat:@"live-pre-%@", reason ?: @"(nil)"]);

	NSArray<NSString *> *backups = [[fileManager contentsOfDirectoryAtPath:backupRoot error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)] ?: @[];
	NSUInteger restoredCount = 0;
	for (NSString *child in backups) {
		NSString *backupPath = [backupRoot stringByAppendingPathComponent:child];
		BOOL backupChildIsDirectory = NO;
		if (![fileManager fileExistsAtPath:backupPath isDirectory:&backupChildIsDirectory] || !backupChildIsDirectory) continue;
		NSString *destinationPath = [descriptorStoreRoot stringByAppendingPathComponent:child];
		if ([fileManager fileExistsAtPath:destinationPath]) continue;

		NSError *error = nil;
		BOOL copied = DWCopyBundleAtPathToPath(backupPath, destinationPath, &error);
		DWWriteBackendLog([NSString stringWithFormat:@"Restore DuoWall descriptor reason=%@ copied=%@ source=%@ destination=%@ error=%@",
			reason ?: @"(nil)",
			copied ? @"YES" : @"NO",
			backupPath,
			destinationPath,
			error ?: @"(nil)"]);
		if (copied) restoredCount += 1;
	}

	NSUInteger migratedLiveCountPostRestore = DWMigrateMissingCollectionMetadataAtRoot(descriptorStoreRoot, [NSString stringWithFormat:@"live-post-%@", reason ?: @"(nil)"]);
	if (restoredCount > 0 || migratedLiveCountPreRestore > 0 || migratedLiveCountPostRestore > 0) {
		NSError *touchError = nil;
		[fileManager setAttributes:@{NSFileModificationDate: [NSDate date]}
					 ofItemAtPath:descriptorStoreRoot
							error:&touchError];
		DWWriteBackendLog([NSString stringWithFormat:@"Restored %@ backed up DuoWall descriptors reason=%@",
			@(restoredCount),
			reason ?: @"(nil)"]);
		if (migratedBackupCount > 0 || migratedLiveCountPreRestore > 0 || migratedLiveCountPostRestore > 0) {
			DWWriteBackendLog([NSString stringWithFormat:@"Metadata migration summary reason=%@ backup=%@ livePre=%@ livePost=%@",
				reason ?: @"(nil)",
				@(migratedBackupCount),
				@(migratedLiveCountPreRestore),
				@(migratedLiveCountPostRestore)]);
		}
		if (touchError) {
			DWWriteBackendLog([NSString stringWithFormat:@"Descriptor store touch failed reason=%@ path=%@ error=%@",
				reason ?: @"(nil)",
				descriptorStoreRoot,
				touchError]);
		}
		if (DWIsStartupRestoreReason(reason)) {
			DWWriteBackendLog([NSString stringWithFormat:@"Skipping startup restore refresh reason=%@ to avoid early SpringBoard collections reload.",
				reason ?: @"(nil)"]);
			return;
		}
		NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
		dispatch_async(dispatch_get_main_queue(), ^{
			DWRefreshCollectionsManagers([NSString stringWithFormat:@"restore-%@", reason ?: @"(nil)"]);
			if (DWShouldObserveCollectionsNotificationsForProcess(processName)) {
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					DWPostCollectionsChangedNotification([NSString stringWithFormat:@"restore-%@", reason ?: @"(nil)"]);
				});
			}
		});
	}
}

static NSString *DWEnsureGeneratedWallpaperBundlePath(void) {
	if (gDWGeneratedWallpaperBundlePath.length && [[NSFileManager defaultManager] fileExistsAtPath:gDWGeneratedWallpaperBundlePath]) {
		return gDWGeneratedWallpaperBundlePath;
	}

	if (gDWBuildingModernWallpaper) return nil;
	gDWBuildingModernWallpaper = YES;
	@try {
		DWCreateFileBackedWallpaperBundle();
	} @finally {
		gDWBuildingModernWallpaper = NO;
	}
	if ([[NSFileManager defaultManager] fileExistsAtPath:gDWGeneratedWallpaperBundlePath]) {
		return gDWGeneratedWallpaperBundlePath;
	}
	return nil;
}

static NSString *DWPosterBoardDataContainerPath(void) {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *applicationsRoot = @"/var/mobile/Containers/Data/Application";
	NSArray<NSString *> *children = [fileManager contentsOfDirectoryAtPath:applicationsRoot error:nil];
	for (NSString *child in children) {
		NSString *candidate = [applicationsRoot stringByAppendingPathComponent:child];
		NSString *metadataPath = [candidate stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
		NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
		NSString *identifier = metadata[@"MCMMetadataIdentifier"];
		if ([identifier isEqualToString:DWPosterBoardBundleIdentifier]) {
			DWWriteBackendLog([NSString stringWithFormat:@"Resolved PosterBoard data container via metadata: %@", candidate]);
			return candidate;
		}
	}

	for (NSString *child in children) {
		NSString *candidate = [applicationsRoot stringByAppendingPathComponent:child];
		NSString *storeRoot = [candidate stringByAppendingPathComponent:@"Library/Application Support/PRBPosterExtensionDataStore"];
		BOOL isDirectory = NO;
		if ([fileManager fileExistsAtPath:storeRoot isDirectory:&isDirectory] && isDirectory) {
			DWWriteBackendLog([NSString stringWithFormat:@"Resolved PosterBoard data container via store fallback: %@", candidate]);
			return candidate;
		}
	}

	DWWriteBackendLog(@"Could not resolve PosterBoard data container under /var/mobile/Containers/Data/Application.");
	return nil;
}

static NSString *DWPosterDescriptorStoreRootPath(void) {
	NSString *containerPath = DWPosterBoardDataContainerPath();
	if (!containerPath.length) return nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *storeBasePath = [containerPath stringByAppendingPathComponent:@"Library/Application Support/PRBPosterExtensionDataStore"];
	NSArray<NSString *> *versionChildren = [fileManager contentsOfDirectoryAtPath:storeBasePath error:nil];
	NSArray<NSString *> *sortedVersions = [versionChildren sortedArrayUsingComparator:^NSComparisonResult(NSString *lhs, NSString *rhs) {
		return [rhs compare:lhs options:NSNumericSearch];
	}];
	for (NSString *version in sortedVersions) {
		NSString *candidate = [storeBasePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/Extensions/%@/descriptors", version, DWPosterCollectionsExtensionIdentifier]];
		BOOL isDirectory = NO;
		if ([fileManager fileExistsAtPath:candidate isDirectory:&isDirectory] && isDirectory) {
			DWWriteBackendLog([NSString stringWithFormat:@"Resolved PosterBoard descriptor store dynamically: %@", candidate]);
			return candidate;
		}
	}

	NSString *fallbackVersion = @"59";
	if (@available(iOS 17.0, *)) {
		fallbackVersion = @"61";
	}
	NSString *fallbackPath = [storeBasePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/Extensions/%@/descriptors", fallbackVersion, DWPosterCollectionsExtensionIdentifier]];
	DWWriteBackendLog([NSString stringWithFormat:@"Using fallback PosterBoard descriptor store path: %@", fallbackPath]);
	return fallbackPath;
}

static NSData *DWPosterProviderInfoData(void) {
	NSDictionary *providerInfo = @{};
	NSError *archiveError = nil;
	NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:providerInfo requiringSecureCoding:NO error:&archiveError];
	if (!archived) {
		DWWriteBackendLog([NSString stringWithFormat:@"Poster providerInfo archive error=%@", archiveError ?: @"(nil)"]);
	}
	return archived;
}

static NSDictionary *DWWallpaperCollectionMetadata(NSString *collectionIdentifier, NSString *displayName, NSString *wallpaperIdentifierString, NSNumber *wallpaperIdentifierNumber) {
	NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
	if (collectionIdentifier.length) {
		metadata[@"wallpaperCollectionIdentifier"] = collectionIdentifier;
		metadata[@"identifier"] = collectionIdentifier;
	}
	if (displayName.length) {
		metadata[@"displayName"] = displayName;
		metadata[@"name"] = displayName;
	}

	NSMutableArray *representedIdentifiers = [NSMutableArray array];
	if (wallpaperIdentifierString.length) {
		metadata[@"previewWallpaperIdentifier"] = wallpaperIdentifierString;
		[representedIdentifiers addObject:wallpaperIdentifierString];
	}
	if (wallpaperIdentifierNumber) {
		metadata[@"previewWallpaperNumericIdentifier"] = wallpaperIdentifierNumber;
		[representedIdentifiers addObject:wallpaperIdentifierNumber];
	}
	if (representedIdentifiers.count) {
		metadata[@"wallpaperRepresentingIdentifiers"] = representedIdentifiers;
	}

	NSInteger orderValue = DWSanitizedCollectionOrderValue(collectionIdentifier, wallpaperIdentifierString, wallpaperIdentifierNumber);
	metadata[@"order"] = @(orderValue);
	metadata[@"wallpapersShareBaseAppearance"] = @YES;
	metadata[@"categoryDisplayName"] = @"Collections";
	metadata[@"source"] = @"DuoWall";
	return metadata;
}

static void DWSetValueSafely(id object, NSString *key, id value) {
	if (!object || !key.length) return;
	@try {
		[object setValue:value forKey:key];
	} @catch (NSException *exception) {
		DWWriteBackendLog([NSString stringWithFormat:@"KVC set failed class=%@ key=%@ value=%@ exception=%@",
			NSStringFromClass([object class]),
			key,
			value ?: @"(nil)",
			exception.reason ?: exception.name]);
	}
}

static NSData *DWArchivePosterSidecarObject(id object, NSString *label) {
	if (!object) return nil;
	NSError *error = nil;
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:NO error:&error];
	if (!data) {
		DWWriteBackendLog([NSString stringWithFormat:@"%@ archive failed error=%@", label ?: @"Poster sidecar", error ?: @"(nil)"]);
	}
	return data;
}

static NSData *DWPosterGalleryOptionsData(void) {
	Class galleryOptionsClass = NSClassFromString(@"ATXPosterDescriptorGalleryOptions");
	id galleryOptions = galleryOptionsClass ? [[galleryOptionsClass alloc] init] : nil;
	if (!galleryOptions) {
		DWWriteBackendLog(@"ATXPosterDescriptorGalleryOptions unavailable; galleryOptions sidecar will remain empty.");
		return nil;
	}

	DWSetValueSafely(galleryOptions, @"displayNameLocalizationKey", DWCurrentFriendlyName());
	DWSetValueSafely(galleryOptions, @"descriptiveTextLocalizationKey", nil);
	DWSetValueSafely(galleryOptions, @"spokenNameLocalizationKey", nil);
	DWSetValueSafely(galleryOptions, @"inlineComplication", nil);
	DWSetValueSafely(galleryOptions, @"modularComplications", nil);
	DWSetValueSafely(galleryOptions, @"focus", @0);
	DWSetValueSafely(galleryOptions, @"hero", @0);
	DWSetValueSafely(galleryOptions, @"photoSubtype", @0);
	DWSetValueSafely(galleryOptions, @"featuredConfidenceLevel", @1);
	DWSetValueSafely(galleryOptions, @"onlyEligibleForMadeForFocusSection", @0);
	DWSetValueSafely(galleryOptions, @"shouldShowAsShuffleStack", @0);
	DWSetValueSafely(galleryOptions, @"allowsSystemSuggestedComplications", @0);
	return DWArchivePosterSidecarObject(galleryOptions, @"galleryOptions");
}

static NSData *DWPosterConfigurableOptionsData(void) {
	Class configurableOptionsClass = NSClassFromString(@"PRPosterConfigurableOptions");
	id configurableOptions = configurableOptionsClass ? [[configurableOptionsClass alloc] init] : nil;
	if (!configurableOptions) {
		DWWriteBackendLog(@"PRPosterConfigurableOptions unavailable; configurableOptions sidecar will remain empty.");
		return nil;
	}

	Class homeScreenConfigurationClass = NSClassFromString(@"PRPosterDescriptorHomeScreenConfiguration");
	id homeScreenConfiguration = homeScreenConfigurationClass ? [[homeScreenConfigurationClass alloc] init] : nil;
	if (homeScreenConfiguration) {
		DWSetValueSafely(homeScreenConfiguration, @"allowsModifyingLegibilityBlur", @1);
		DWSetValueSafely(homeScreenConfiguration, @"preferredGradientColors", nil);
		DWSetValueSafely(homeScreenConfiguration, @"preferredSolidColors", nil);
		DWSetValueSafely(homeScreenConfiguration, @"preferredStyle", @0);
	}

	DWSetValueSafely(configurableOptions, @"displayNameLocalizationKey", nil);
	DWSetValueSafely(configurableOptions, @"preferredTitleColors", @[]);
	DWSetValueSafely(configurableOptions, @"preferredTimeFontConfigurations", @[]);
	if (homeScreenConfiguration) {
		DWSetValueSafely(configurableOptions, @"preferredHomeScreenConfiguration", homeScreenConfiguration);
	}

	return DWArchivePosterSidecarObject(configurableOptions, @"configurableOptions");
}

static NSString *DWStringFromFileIfPresent(NSString *path) {
	if (!path.length) return nil;
	NSError *error = nil;
	NSString *string = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
	if (!string.length && error) {
		DWWriteBackendLog([NSString stringWithFormat:@"Descriptor text read error path=%@ error=%@", path, error]);
	}
	return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static id DWUnarchiveObjectAtPathIfPresent(NSString *path) {
	NSData *data = [NSData dataWithContentsOfFile:path];
	if (!data.length) return nil;
	NSError *error = nil;
	id object = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:
		[NSDictionary class],
		[NSArray class],
		[NSString class],
		[NSNumber class],
		[NSDate class],
		[NSData class],
		nil]
		fromData:data
		error:&error];
	if (!object && error) {
		DWWriteBackendLog([NSString stringWithFormat:@"Descriptor archive read error path=%@ error=%@", path, error]);
	}
	return object;
}

static NSDictionary *DWPosterDescriptorSummaryAtPath(NSString *descriptorPath) {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *descriptorName = [descriptorPath lastPathComponent] ?: @"(unknown)";
	NSArray<NSString *> *topLevelChildren = [fileManager contentsOfDirectoryAtPath:descriptorPath error:nil] ?: @[];
	NSString *versionsRoot = [descriptorPath stringByAppendingPathComponent:@"versions"];
	NSArray<NSString *> *versionChildren = [[fileManager contentsOfDirectoryAtPath:versionsRoot error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)] ?: @[];
	NSString *contentsPath = nil;
	NSString *selectedVersion = nil;
	for (NSString *versionChild in versionChildren) {
		NSString *candidateContentsPath = [[versionsRoot stringByAppendingPathComponent:versionChild] stringByAppendingPathComponent:@"contents"];
		BOOL isDirectory = NO;
		if ([fileManager fileExistsAtPath:candidateContentsPath isDirectory:&isDirectory] && isDirectory) {
			contentsPath = candidateContentsPath;
			selectedVersion = versionChild;
			break;
		}
	}
	if (!contentsPath.length) {
		contentsPath = [descriptorPath stringByAppendingPathComponent:@"versions/1/contents"];
		selectedVersion = @"1";
	}
	NSArray<NSString *> *contentsChildren = [fileManager contentsOfDirectoryAtPath:contentsPath error:nil] ?: @[];
	NSString *wallpaperDirectoryName = nil;
	for (NSString *child in contentsChildren) {
		if ([[child pathExtension] isEqualToString:@"wallpaper"]) {
			wallpaperDirectoryName = child;
			break;
		}
	}
	NSString *wallpaperPlistPath = wallpaperDirectoryName.length
		? [[contentsPath stringByAppendingPathComponent:wallpaperDirectoryName] stringByAppendingPathComponent:@"Wallpaper.plist"]
		: nil;
	NSDictionary *wallpaperPlist = wallpaperPlistPath.length ? [NSDictionary dictionaryWithContentsOfFile:wallpaperPlistPath] : nil;
	NSDictionary *userInfo = [NSDictionary dictionaryWithContentsOfFile:[contentsPath stringByAppendingPathComponent:@"com.apple.posterkit.provider.contents.userInfo"]];
	id galleryOptions = [NSDictionary dictionaryWithContentsOfFile:[contentsPath stringByAppendingPathComponent:@"com.apple.posterkit.provider.contents.galleryOptions"]];
	if (!galleryOptions) {
		galleryOptions = [NSArray arrayWithContentsOfFile:[contentsPath stringByAppendingPathComponent:@"com.apple.posterkit.provider.contents.galleryOptions"]];
	}
	if (!galleryOptions) {
		galleryOptions = DWUnarchiveObjectAtPathIfPresent([contentsPath stringByAppendingPathComponent:@"com.apple.posterkit.provider.contents.galleryOptions"]);
	}
	id configurableOptions = [NSDictionary dictionaryWithContentsOfFile:[contentsPath stringByAppendingPathComponent:@".com.apple.posterkit.provider.contents.configurableOptions.plist"]];
	if (!configurableOptions) {
		configurableOptions = [NSArray arrayWithContentsOfFile:[contentsPath stringByAppendingPathComponent:@".com.apple.posterkit.provider.contents.configurableOptions.plist"]];
	}
	if (!configurableOptions) {
		configurableOptions = DWUnarchiveObjectAtPathIfPresent([contentsPath stringByAppendingPathComponent:@".com.apple.posterkit.provider.contents.configurableOptions.plist"]);
	}
	id providerInfo = DWUnarchiveObjectAtPathIfPresent([descriptorPath stringByAppendingPathComponent:@"providerInfo.plist"]);
	NSDictionary *wallpaperCollectionMetadata = [NSDictionary dictionaryWithContentsOfFile:[descriptorPath stringByAppendingPathComponent:@"WallpaperCollection.plist"]];

	return @{
		@"descriptorName": descriptorName,
		@"identifierFile": DWStringFromFileIfPresent([descriptorPath stringByAppendingPathComponent:@"com.apple.posterkit.provider.descriptor.identifier"]) ?: @"(nil)",
		@"roleFile": DWStringFromFileIfPresent([descriptorPath stringByAppendingPathComponent:@"com.apple.posterkit.role.identifier"]) ?: @"(nil)",
		@"topLevelChildren": topLevelChildren,
		@"versionChildren": versionChildren,
		@"selectedVersion": selectedVersion ?: @"(nil)",
		@"contentsChildren": contentsChildren,
		@"wallpaperDirectoryName": wallpaperDirectoryName ?: @"(nil)",
		@"wallpaperPlist": wallpaperPlist ?: @{},
		@"wallpaperCollectionMetadata": wallpaperCollectionMetadata ?: @{},
		@"userInfo": userInfo ?: @{},
		@"galleryOptions": galleryOptions ?: @"(nil)",
		@"configurableOptions": configurableOptions ?: @"(nil)",
		@"providerInfo": providerInfo ?: @"(nil)"
	};
}

static NSString *DWResolvedFriendlyNameForInstall(NSString *baseName) {
	NSString *normalizedBaseName = DWNormalizeFriendlyName(baseName);
	NSString *descriptorStoreRoot = DWPosterDescriptorStoreRootPath();
	if (!descriptorStoreRoot.length) return normalizedBaseName;

	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray<NSString *> *children = [fileManager contentsOfDirectoryAtPath:descriptorStoreRoot error:nil] ?: @[];
	NSUInteger matchCount = 0;
	for (NSString *child in children) {
		NSString *descriptorPath = [descriptorStoreRoot stringByAppendingPathComponent:child];
		BOOL isDirectory = NO;
		if (![fileManager fileExistsAtPath:descriptorPath isDirectory:&isDirectory] || !isDirectory) continue;
		NSDictionary *summary = DWPosterDescriptorSummaryAtPath(descriptorPath);
		if (!DWSummaryRepresentsDuoWallDescriptor(summary)) continue;
		NSDictionary *wallpaperPlist = [summary[@"wallpaperPlist"] isKindOfClass:[NSDictionary class]] ? summary[@"wallpaperPlist"] : nil;
		NSString *existingName = DWNormalizeFriendlyName(wallpaperPlist[@"name"]);
		if ([existingName isEqualToString:normalizedBaseName]) {
			matchCount += 1;
		}
	}

	if (matchCount == 0) return normalizedBaseName;
	return [NSString stringWithFormat:@"%@ (%lu)", normalizedBaseName, (unsigned long)(matchCount + 1)];
}

static void DWLogPosterDescriptorStoreSnapshot(NSString *reason) {
	NSString *descriptorStoreRoot = DWPosterDescriptorStoreRootPath();
	if (!descriptorStoreRoot.length) {
		DWWriteBackendLog([NSString stringWithFormat:@"Descriptor store snapshot skipped reason=%@ root=(nil)",
			reason ?: @"(unknown)"]);
		return;
	}

	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray<NSString *> *children = [[fileManager contentsOfDirectoryAtPath:descriptorStoreRoot error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)] ?: @[];
	NSMutableArray<NSString *> *duoWallDescriptors = [NSMutableArray array];
	NSMutableArray<NSString *> *nativeDescriptors = [NSMutableArray array];
	NSMutableDictionary<NSString *, NSDictionary *> *summariesByPath = [NSMutableDictionary dictionary];
	for (NSString *child in children) {
		NSString *fullPath = [descriptorStoreRoot stringByAppendingPathComponent:child];
		BOOL isDirectory = NO;
		if (![fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory] || !isDirectory) continue;
		NSDictionary *summary = DWPosterDescriptorSummaryAtPath(fullPath);
		summariesByPath[fullPath] = summary ?: @{};
		NSString *wallpaperFileName = summary[@"userInfo"][@"wallpaperRepresentingFileName"];
		if ([child containsString:@".DuoWall-"] || [wallpaperFileName containsString:@".DuoWall-"]) {
			[duoWallDescriptors addObject:fullPath];
		} else {
			[nativeDescriptors addObject:fullPath];
		}
	}

	NSString *(^bestDescriptorPath)(NSArray<NSString *> *) = ^NSString *(NSArray<NSString *> *paths) {
		NSString *bestPath = nil;
		NSUInteger bestScore = 0;
		for (NSString *path in paths) {
			NSDictionary *summary = summariesByPath[path] ?: @{};
			NSUInteger score = 0;
			score += [summary[@"contentsChildren"] respondsToSelector:@selector(count)] ? [summary[@"contentsChildren"] count] : 0;
			score += [summary[@"wallpaperPlist"] respondsToSelector:@selector(count)] ? [summary[@"wallpaperPlist"] count] : 0;
			score += [summary[@"userInfo"] respondsToSelector:@selector(count)] ? [summary[@"userInfo"] count] : 0;
			if (!bestPath || score > bestScore) {
				bestPath = path;
				bestScore = score;
			}
		}
		return bestPath;
	};

	NSString *sampleNativePath = bestDescriptorPath(nativeDescriptors);
	NSString *sampleDuoWallPath = bestDescriptorPath(duoWallDescriptors);
	NSDictionary *sampleNative = sampleNativePath.length ? summariesByPath[sampleNativePath] : nil;
	NSDictionary *sampleDuoWall = sampleDuoWallPath.length ? summariesByPath[sampleDuoWallPath] : nil;
	DWWriteBackendLog([NSString stringWithFormat:@"Descriptor store snapshot reason=%@ root=%@ total=%@ duoWallCount=%@ nativeCount=%@ duoWallNames=%@ nativeNames=%@ sampleNative=%@ sampleDuoWall=%@",
		reason ?: @"(unknown)",
		descriptorStoreRoot,
		@(children.count),
		@(duoWallDescriptors.count),
		@(nativeDescriptors.count),
		[duoWallDescriptors valueForKey:@"lastPathComponent"] ?: @[],
		[nativeDescriptors valueForKey:@"lastPathComponent"] ?: @[],
		sampleNative ?: @"(nil)",
		sampleDuoWall ?: @"(nil)"]);
}

static BOOL DWInstallPosterBoardDescriptor(NSError **error) {
	NSString *sourceBundlePath = DWEnsureGeneratedWallpaperBundlePath();
	if (!sourceBundlePath.length) {
		if (error) {
			*error = [NSError errorWithDomain:@"DuoWall" code:740 userInfo:@{NSLocalizedDescriptionKey: @"No generated DuoWall wallpaper bundle is available for PosterBoard descriptor installation."}];
		}
		return NO;
	}

	NSString *descriptorStoreRoot = DWPosterDescriptorStoreRootPath();
	if (!descriptorStoreRoot.length) {
		if (error) {
			*error = [NSError errorWithDomain:@"DuoWall" code:741 userInfo:@{NSLocalizedDescriptionKey: @"Could not resolve the PosterBoard descriptor store path."}];
		}
		return NO;
	}

	NSFileManager *fileManager = [NSFileManager defaultManager];
	if (![fileManager createDirectoryAtPath:descriptorStoreRoot withIntermediateDirectories:YES attributes:nil error:error]) {
		return NO;
	}

	NSString *logicalScreenClass = DWCachedLogicalScreenClass();
	if (!logicalScreenClass.length) logicalScreenClass = @"375w-812h@3x~iphone";
	NSString *requestedFriendlyName = DWCurrentFriendlyName();
	NSString *friendlyName = DWResolvedFriendlyNameForInstall(requestedFriendlyName);

	u_int32_t descriptorID = (u_int32_t)(10000 + arc4random_uniform(89999));
	NSString *descriptorIDString = [NSString stringWithFormat:@"%u", descriptorID];
	NSString *descriptorDirectoryName = [[[NSUUID UUID] UUIDString] uppercaseString];
	NSString *uniqueFamily = [NSString stringWithFormat:@"DuoWall-%@", descriptorDirectoryName];
	NSString *wallpaperBaseName = [NSString stringWithFormat:@"%@.DuoWall-%@", descriptorIDString, logicalScreenClass];
	NSString *wallpaperFileName = [wallpaperBaseName stringByAppendingPathExtension:@"wallpaper"];
	NSString *descriptorDirectoryPath = [descriptorStoreRoot stringByAppendingPathComponent:descriptorDirectoryName];
	[fileManager removeItemAtPath:descriptorDirectoryPath error:nil];

	NSString *contentsPath = [descriptorDirectoryPath stringByAppendingPathComponent:@"versions/1/contents"];
	NSString *wallpaperDestinationPath = [contentsPath stringByAppendingPathComponent:wallpaperFileName];
	if (![fileManager createDirectoryAtPath:contentsPath withIntermediateDirectories:YES attributes:nil error:error]) {
		return NO;
	}

	if (!DWCopyBundleAtPathToPath(sourceBundlePath, wallpaperDestinationPath, error)) {
		return NO;
	}

	NSString *wallpaperPlistPath = [wallpaperDestinationPath stringByAppendingPathComponent:@"Wallpaper.plist"];
	NSMutableDictionary *wallpaperPlist = [[NSDictionary dictionaryWithContentsOfFile:wallpaperPlistPath] mutableCopy];
	if (wallpaperPlist) {
		wallpaperPlist[@"identifier"] = @(descriptorID);
		wallpaperPlist[@"name"] = friendlyName;
		wallpaperPlist[@"family"] = uniqueFamily;
		NSMutableDictionary *assets = [wallpaperPlist[@"assets"] isKindOfClass:[NSDictionary class]] ? [wallpaperPlist[@"assets"] mutableCopy] : nil;
		NSMutableDictionary *lockAndHome = [assets[@"lockAndHome"] isKindOfClass:[NSDictionary class]] ? [assets[@"lockAndHome"] mutableCopy] : nil;
		NSMutableDictionary *defaultAsset = [lockAndHome[@"default"] isKindOfClass:[NSDictionary class]] ? [lockAndHome[@"default"] mutableCopy] : nil;
		NSMutableDictionary *darkAsset = [lockAndHome[@"dark"] isKindOfClass:[NSDictionary class]] ? [lockAndHome[@"dark"] mutableCopy] : nil;
		if (defaultAsset) {
			defaultAsset[@"identifier"] = @(descriptorID);
			defaultAsset[@"name"] = [NSString stringWithFormat:@"%@ Light", friendlyName];
			lockAndHome[@"default"] = defaultAsset;
		}
		if (darkAsset) {
			darkAsset[@"identifier"] = @(descriptorID + 1);
			darkAsset[@"name"] = [NSString stringWithFormat:@"%@ Dark", friendlyName];
			lockAndHome[@"dark"] = darkAsset;
		}
		if (lockAndHome) {
			assets[@"lockAndHome"] = lockAndHome;
			wallpaperPlist[@"assets"] = assets;
		}
		[wallpaperPlist writeToFile:wallpaperPlistPath atomically:YES];
	}

	NSDictionary *userInfo = @{
		@"wallpaperRepresentingFileName": wallpaperFileName,
		@"wallpaperRepresentingIdentifier": descriptorIDString
	};
	NSString *collectionIdentifier = [DWModernCollectionIdentifier stringByAppendingFormat:@".%@", descriptorDirectoryName];
	NSDictionary *wallpaperCollectionMetadata = DWWallpaperCollectionMetadata(collectionIdentifier, friendlyName, descriptorIDString, @(descriptorID));
	NSString *userInfoPath = [contentsPath stringByAppendingPathComponent:@"com.apple.posterkit.provider.contents.userInfo"];
	if (![userInfo writeToFile:userInfoPath atomically:YES]) {
		if (error) {
			*error = [NSError errorWithDomain:@"DuoWall" code:742 userInfo:@{NSLocalizedDescriptionKey: @"Could not write poster descriptor userInfo."}];
		}
		return NO;
	}

	if (![descriptorIDString writeToFile:[descriptorDirectoryPath stringByAppendingPathComponent:@"com.apple.posterkit.provider.descriptor.identifier"]
		atomically:YES
		encoding:NSUTF8StringEncoding
		error:error]) {
		return NO;
	}

	NSString *collectionMetadataPath = [descriptorDirectoryPath stringByAppendingPathComponent:@"WallpaperCollection.plist"];
	if (![wallpaperCollectionMetadata writeToFile:collectionMetadataPath atomically:YES]) {
		DWWriteBackendLog([NSString stringWithFormat:@"Could not write WallpaperCollection metadata path=%@ metadata=%@",
			collectionMetadataPath,
			wallpaperCollectionMetadata ?: @{}]);
	}

	NSString *galleryOptionsPath = [contentsPath stringByAppendingPathComponent:@"com.apple.posterkit.provider.contents.galleryOptions"];
	NSData *galleryOptionsData = DWPosterGalleryOptionsData();
	if (galleryOptionsData.length) {
		if (![galleryOptionsData writeToFile:galleryOptionsPath atomically:YES]) {
			DWWriteBackendLog([NSString stringWithFormat:@"Could not write gallery options sidecar path=%@",
				galleryOptionsPath]);
		}
	} else if (![@{} writeToFile:galleryOptionsPath atomically:YES]) {
		DWWriteBackendLog([NSString stringWithFormat:@"Could not write fallback gallery options sidecar path=%@",
			galleryOptionsPath]);
	}

	NSString *configurableOptionsPath = [contentsPath stringByAppendingPathComponent:@".com.apple.posterkit.provider.contents.configurableOptions.plist"];
	NSData *configurableOptionsData = DWPosterConfigurableOptionsData();
	if (configurableOptionsData.length) {
		if (![configurableOptionsData writeToFile:configurableOptionsPath atomically:YES]) {
			DWWriteBackendLog([NSString stringWithFormat:@"Could not write configurable options sidecar path=%@",
				configurableOptionsPath]);
		}
	} else if (![@{} writeToFile:configurableOptionsPath atomically:YES]) {
		DWWriteBackendLog([NSString stringWithFormat:@"Could not write fallback configurable options sidecar path=%@",
			configurableOptionsPath]);
	}

	NSData *providerInfoData = DWPosterProviderInfoData();
	if (providerInfoData) {
		[providerInfoData writeToFile:[descriptorDirectoryPath stringByAppendingPathComponent:@"providerInfo.plist"] atomically:YES];
	}

	NSDictionary *loggedWallpaperPlist = [NSDictionary dictionaryWithContentsOfFile:wallpaperPlistPath] ?: @{};
	NSDictionary *loggedWallpaperCollectionMetadata = [NSDictionary dictionaryWithContentsOfFile:collectionMetadataPath] ?: @{};
	NSDictionary *loggedUserInfo = [NSDictionary dictionaryWithContentsOfFile:userInfoPath] ?: @{};
	DWBackupDescriptorDirectoryIfNeeded(descriptorDirectoryPath);
	DWWriteBackendLog([NSString stringWithFormat:@"Installed PosterBoard descriptor id=%@ requestedFriendlyName=%@ resolvedFriendlyName=%@ uniqueFamily=%@ collectionIdentifier=%@ root=%@ descriptorDirectory=%@ wallpaperFileName=%@ sourceBundle=%@ wallpaperPlist=%@ collectionMetadata=%@ userInfo=%@ providerInfoBytes=%@",
		descriptorIDString,
		requestedFriendlyName,
		friendlyName,
		uniqueFamily,
		collectionIdentifier,
		descriptorStoreRoot,
		descriptorDirectoryPath,
		wallpaperFileName,
		sourceBundlePath,
		loggedWallpaperPlist,
		loggedWallpaperCollectionMetadata,
		loggedUserInfo,
		providerInfoData ? @([providerInfoData length]) : @"(nil)"]);
	return YES;
}

static void DWInjectDuoWallIntoCollectionsManager(id manager, NSString *source) {
	if (!manager) return;

	SEL collectionsGetter = @selector(_wallpaperCollections);
	SEL collectionsSetter = @selector(set_wallpaperCollections:);
	SEL lookupGetter = @selector(_wallpaperCollectionLookupTable);
	SEL lookupSetter = @selector(set_wallpaperCollectionLookupTable:);

	id collections = [manager respondsToSelector:collectionsGetter] ? [manager _wallpaperCollections] : nil;
	id augmentedCollections = DWCollectionsByAppendingDuoWallIfNeeded(collections);
	if (augmentedCollections && augmentedCollections != collections && [manager respondsToSelector:collectionsSetter]) {
		[manager set_wallpaperCollections:augmentedCollections];
	}

	id lookup = [manager respondsToSelector:lookupGetter] ? [manager _wallpaperCollectionLookupTable] : nil;
	id augmentedLookup = DWCollectionLookupByAppendingDuoWallIfNeeded(lookup);
	if (augmentedLookup && augmentedLookup != lookup && [manager respondsToSelector:lookupSetter]) {
		[manager set_wallpaperCollectionLookupTable:augmentedLookup];
	}

	DWWriteBackendLog([NSString stringWithFormat:@"[%@] Minimal collections injection source=%@ collections=%@ augmentedCollections=%@ lookup=%@ augmentedLookup=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		source ?: @"(unknown)",
		[collections respondsToSelector:@selector(count)] ? @([collections count]) : @"(n/a)",
		[augmentedCollections respondsToSelector:@selector(count)] ? @([augmentedCollections count]) : @"(n/a)",
		[lookup respondsToSelector:@selector(count)] ? @([lookup count]) : @"(n/a)",
		[augmentedLookup respondsToSelector:@selector(count)] ? @([augmentedLookup count]) : @"(n/a)"]);
}

static void DWRefreshCollectionsManagers(NSString *reason) {
	Class managerClass = NSClassFromString(@"WKWallpaperRepresentingCollectionsManager");
	if (!managerClass) return;

	NSArray<NSString *> *factoryNames = @[@"defaultManager", @"defaultLegacyManager"];
	for (NSString *factoryName in factoryNames) {
		SEL factorySelector = NSSelectorFromString(factoryName);
		if (![managerClass respondsToSelector:factorySelector]) continue;
		id manager = ((id (*)(id, SEL))objc_msgSend)(managerClass, factorySelector);
		if (!manager) continue;

		for (NSString *reloadName in @[@"_loadSystemWallpaperCollections", @"_loadLegacySystemWallpaperCollections", @"_loadCollections"]) {
			SEL reloadSelector = NSSelectorFromString(reloadName);
			if ([manager respondsToSelector:reloadSelector]) {
				((void (*)(id, SEL))objc_msgSend)(manager, reloadSelector);
			}
		}
		DWInjectDuoWallIntoCollectionsManager(manager, [NSString stringWithFormat:@"refresh-%@-%@", reason ?: @"(unknown)", factoryName]);
	}

	DWWriteBackendLog([NSString stringWithFormat:@"[%@] Refreshed wallpaper collections managers reason=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		reason ?: @"(unknown)"]);
}

static void DWPostCollectionsChangedNotification(NSString *reason) {
	NSString *label = reason ?: @"(unknown)";
	DWWriteBackendLog([NSString stringWithFormat:@"[%@] Posting DuoWall collections-changed notification reason=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		label]);
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
		DWCollectionsChangedNotification,
		NULL,
		NULL,
		YES);
	DWRefreshCollectionsManagers([NSString stringWithFormat:@"post-%@", label]);
	if ([label isEqualToString:@"post-install"]) {
		NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			DWRefreshCollectionsManagers([NSString stringWithFormat:@"%@-post-install-1s", processName]);
		});
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			DWRefreshCollectionsManagers([NSString stringWithFormat:@"%@-post-install-4s", processName]);
		});
	}
}

static void DWApplyModernWallpaperInCurrentProcess(void (^completion)(BOOL success, NSString *message)) {
	dispatch_async(dispatch_get_main_queue(), ^{
		DWLogPosterDescriptorStoreSnapshot(@"before-install");
		NSString *friendlyName = DWCurrentFriendlyName();
		NSError *descriptorError = nil;
		if (DWInstallPosterBoardDescriptor(&descriptorError)) {
			DWLogPosterDescriptorStoreSnapshot(@"after-install");
			DWPostCollectionsChangedNotification(@"post-install");
			DWWriteBackendLog(@"Poster descriptor path succeeded. DuoWall is ready in the wallpaper list.");
			if (completion) completion(YES, [NSString stringWithFormat:@"\"%@\" was added successfully. Open the wallpaper list and look in Collections to add it.", friendlyName]);
			return;
		}
		DWWriteBackendLog([NSString stringWithFormat:@"Poster descriptor installation failed, falling back to direct apply. error=%@",
			descriptorError ?: @"(nil)"]);

		id bundle = DWModernWallpaperBundle();
		Class currentManagerClass = NSClassFromString(@"WKCurrentWallpaperManager");
		id currentManager = [currentManagerClass respondsToSelector:@selector(sharedCurrentWallpaperManager)] ? [currentManagerClass sharedCurrentWallpaperManager] : nil;
		SEL currentSetter = @selector(setWallpaperRepresenting:forWallpaperLocation:completion:);
		Class shellManagerClass = NSClassFromString(@"WKSystemShellWallpaperManager");
		id shellManager = [shellManagerClass respondsToSelector:@selector(sharedManager)] ? [shellManagerClass sharedManager] : nil;
		SEL shellHomeSetter = @selector(setHomeScreenWallpaperRepresenting:completion:);
		SEL shellSetter = @selector(setLockScreenWallpaperRepresenting:mirrorToHomeScreen:completion:);
		if (!bundle || (![shellManager respondsToSelector:shellHomeSetter] && ![shellManager respondsToSelector:shellSetter] && ![currentManager respondsToSelector:currentSetter])) {
			NSString *message = bundle ? @"The iOS 16 wallpaper manager is unavailable." : @"iOS rejected the temporary DuoWall bundle. See DuoWall-backend-log.txt in /var/mobile/Documents.";
			DWWriteBackendLog(message);
			if (completion) completion(NO, message);
			return;
		}

		@try {
			if ([shellManager respondsToSelector:shellHomeSetter] || [shellManager respondsToSelector:shellSetter]) {
				__block NSInteger remainingShellCalls = 0;
				dispatch_block_t shellCompletion = ^{
					remainingShellCalls--;
					DWWriteBackendLog([NSString stringWithFormat:@"WKSystemShellWallpaperManager completion remaining=%ld", (long)remainingShellCalls]);
					if (remainingShellCalls == 0 && completion) completion(YES, @"DuoWall was applied through WKSystemShellWallpaperManager.");
				};
				DWWriteBackendLog(@"Trying WKSystemShellWallpaperManager direct home/lock setters.");
				if ([shellManager respondsToSelector:shellHomeSetter]) {
					remainingShellCalls++;
					[shellManager setHomeScreenWallpaperRepresenting:bundle completion:shellCompletion];
				}
				if ([shellManager respondsToSelector:shellSetter]) {
					remainingShellCalls++;
					[shellManager setLockScreenWallpaperRepresenting:bundle mirrorToHomeScreen:NO completion:shellCompletion];
				}
				if (remainingShellCalls > 0) return;
			}

			if ([currentManager respondsToSelector:currentSetter]) {
				__block NSInteger remainingCurrentCalls = 2;
				dispatch_block_t currentCompletion = ^{
					remainingCurrentCalls--;
					DWWriteBackendLog([NSString stringWithFormat:@"WKCurrentWallpaperManager completion remaining=%ld", (long)remainingCurrentCalls]);
					if (remainingCurrentCalls == 0 && completion) completion(YES, @"DuoWall was applied through WKCurrentWallpaperManager.");
				};
				DWWriteBackendLog(@"Trying WKCurrentWallpaperManager for both lock and home locations.");
				[currentManager setWallpaperRepresenting:bundle forWallpaperLocation:@"WKWallpaperLocationCoverSheet" completion:currentCompletion];
				[currentManager setWallpaperRepresenting:bundle forWallpaperLocation:@"WKWallpaperLocationHomeScreen" completion:currentCompletion];
				return;
			}

			[shellManager setLockScreenWallpaperRepresenting:bundle mirrorToHomeScreen:YES completion:^{
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

static void DWHandleApplyRequestNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	#pragma unused(center, observer, name, object, userInfo)
	DWWriteBackendLog([NSString stringWithFormat:@"[%@] Received DuoWall apply request notification.",
		NSProcessInfo.processInfo.processName ?: @"Unknown"]);
	DWApplyModernWallpaperInCurrentProcess(nil);
}

static void DWHandleCollectionsChangedNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
	#pragma unused(center, observer, name, object, userInfo)
	NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
	DWWriteBackendLog([NSString stringWithFormat:@"[%@] Received DuoWall collections-changed notification.",
		processName]);
	dispatch_async(dispatch_get_main_queue(), ^{
		DWRefreshCollectionsManagers(@"collections-changed-notification");
		if (DWShouldObserveCollectionsNotificationsForProcess(processName)) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				DWRefreshCollectionsManagers([NSString stringWithFormat:@"%@-collections-changed-1s", processName]);
			});
		}
	});
}

__attribute__((visibility("default"))) extern "C" void DuoWallApplyModernWallpaper(void (^completion)(BOOL success, NSString *message)) {
	NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
	if ([processName isEqualToString:@"SpringBoard"] || [processName isEqualToString:@"PosterBoard"]) {
		DWApplyModernWallpaperInCurrentProcess(completion);
		return;
	}

	DWWriteBackendLog([NSString stringWithFormat:@"[%@] Forwarding DuoWall apply request to SpringBoard.", processName]);
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
		DWApplyRequestNotification,
		NULL,
		NULL,
		YES);
	if (completion) completion(YES, @"DuoWall apply request was sent to SpringBoard. Check the Lock Screen, and use the backend log if it still doesn’t appear.");
}

static BOOL DWClassNameIsRelevant(const char *rawName) {
	if (!rawName) return NO;
	NSString *name = [NSString stringWithUTF8String:rawName];
	NSString *lowercaseName = name.lowercaseString;
	return [lowercaseName containsString:@"wallpaper"] ||
		[lowercaseName containsString:@"poster"] ||
		[lowercaseName containsString:@"settings"] ||
		[lowercaseName containsString:@"collection"] ||
		[lowercaseName containsString:@"picker"] ||
		[lowercaseName containsString:@"preview"] ||
		[name hasPrefix:@"PRS"] ||
		[name hasPrefix:@"PRB"] ||
		[name hasPrefix:@"PB"] ||
		[name hasPrefix:@"WK"] ||
		[name hasPrefix:@"WPU"] ||
		[name hasPrefix:@"WPS"];
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

static void DWLogSelectorsForClassNamed(NSString *className) {
	Class cls = NSClassFromString(className);
	if (!cls) {
		DWWriteBackendLog([NSString stringWithFormat:@"Runtime class %@ is unavailable.", className]);
		return;
	}

	NSMutableArray<NSString *> *selectors = [NSMutableArray array];
	unsigned int classMethodCount = 0;
	Method *classMethods = class_copyMethodList(object_getClass(cls), &classMethodCount);
	for (unsigned int index = 0; index < classMethodCount; index++) {
		[selectors addObject:[NSString stringWithFormat:@"+ %@", NSStringFromSelector(method_getName(classMethods[index]))]];
	}
	free(classMethods);

	unsigned int instanceMethodCount = 0;
	Method *instanceMethods = class_copyMethodList(cls, &instanceMethodCount);
	for (unsigned int index = 0; index < instanceMethodCount; index++) {
		[selectors addObject:[NSString stringWithFormat:@"- %@", NSStringFromSelector(method_getName(instanceMethods[index]))]];
	}
	free(instanceMethods);

	[selectors sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	DWWriteBackendLog([NSString stringWithFormat:@"Runtime selectors for %@:\n%@", className, [selectors componentsJoinedByString:@"\n"]]);
}

static void DWLogPreferenceClassSummary(NSString *reason) {
	NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
	if (![processName isEqualToString:@"Preferences"]) return;

	int classCount = objc_getClassList(NULL, 0);
	if (classCount <= 0) return;

	Class *classes = (__unsafe_unretained Class *)calloc((size_t)classCount, sizeof(Class));
	classCount = objc_getClassList(classes, classCount);
	NSMutableArray<NSString *> *classNames = [NSMutableArray array];
	for (int index = 0; index < classCount; index++) {
		const char *name = class_getName(classes[index]);
		if (!DWClassNameIsRelevant(name)) continue;
		NSString *className = [NSString stringWithUTF8String:name];
		if ([className hasPrefix:@"NS"] || [className hasPrefix:@"UI"]) continue;
		[classNames addObject:className];
	}
	free(classes);

	[classNames sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	if (classNames.count > 80) {
		classNames = [[classNames subarrayWithRange:NSMakeRange(0, 80)] mutableCopy];
	}

	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] Preference-class summary reason=%@ count=%lu classes=%@",
		reason ?: @"(none)",
		(unsigned long)classNames.count,
		classNames]);
}

static void DWLogPreferenceTargetedSelectors(NSString *reason) {
	NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
	if (![processName isEqualToString:@"Preferences"]) return;

	NSMutableOrderedSet<NSString *> *targetNames = [NSMutableOrderedSet orderedSetWithArray:@[
		@"_PBUIWallpaperRemoteViewControllerSceneModeAssertion",
		@"_PBUIWallpaperViewControllerAssertion"
	]];

	int classCount = objc_getClassList(NULL, 0);
	if (classCount > 0) {
		Class *classes = (__unsafe_unretained Class *)calloc((size_t)classCount, sizeof(Class));
		classCount = objc_getClassList(classes, classCount);
		for (int index = 0; index < classCount; index++) {
			const char *rawName = class_getName(classes[index]);
			if (!rawName) continue;
			NSString *className = [NSString stringWithUTF8String:rawName];
			NSString *lowercaseName = className.lowercaseString;
			if ([className hasPrefix:@"PBUI"] ||
				([className hasPrefix:@"PR"] && [lowercaseName containsString:@"poster"]) ||
				([className hasPrefix:@"WPS"]) ||
				([lowercaseName containsString:@"wallpapersettings"]) ||
				([lowercaseName containsString:@"wallpaper"] && [lowercaseName containsString:@"controller"]) ||
				([lowercaseName containsString:@"wallpaper"] && [lowercaseName containsString:@"provider"]) ||
				([lowercaseName containsString:@"wallpaper"] && [lowercaseName containsString:@"model"]) ||
				([lowercaseName containsString:@"poster"] && [lowercaseName containsString:@"controller"]) ||
				([lowercaseName containsString:@"poster"] && [lowercaseName containsString:@"provider"])) {
				[targetNames addObject:className];
			}
		}
		free(classes);
	}

	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] Targeted selector classes reason=%@ count=%lu classes=%@",
		reason ?: @"(none)",
		(unsigned long)targetNames.count,
		targetNames.array]);
	for (NSString *className in targetNames.array) {
		DWLogSelectorsForClassNamed(className);
	}
}

static void (*gOrigWallpaperPreviewCoordinatorSetButtonPressed)(id, SEL, id) = NULL;
static void DWWallpaperPreviewCoordinatorSetButtonPressed(id self, SEL _cmd, id controller) {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] WallpaperPreviewCoordinator setButtonPressed controller=%@",
		controller ?: @"(nil)"]);
	if (gOrigWallpaperPreviewCoordinatorSetButtonPressed) {
		gOrigWallpaperPreviewCoordinatorSetButtonPressed(self, _cmd, controller);
	}
}

static void (*gOrigCurrentSystemShellWallpaperPreviewCoordinatorStart)(id, SEL) = NULL;
static void DWCurrentSystemShellWallpaperPreviewCoordinatorStart(id self, SEL _cmd) {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] CurrentSystemShellWallpaperPreviewCoordinator start self=%@",
		self]);
	if (gOrigCurrentSystemShellWallpaperPreviewCoordinatorStart) {
		gOrigCurrentSystemShellWallpaperPreviewCoordinatorStart(self, _cmd);
	}
}

static void (*gOrigCurrentSystemShellWallpaperPreviewCoordinatorSetButtonPressed)(id, SEL, id) = NULL;
static void DWCurrentSystemShellWallpaperPreviewCoordinatorSetButtonPressed(id self, SEL _cmd, id controller) {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] CurrentSystemShellWallpaperPreviewCoordinator setButtonPressed controller=%@",
		controller ?: @"(nil)"]);
	if (gOrigCurrentSystemShellWallpaperPreviewCoordinatorSetButtonPressed) {
		gOrigCurrentSystemShellWallpaperPreviewCoordinatorSetButtonPressed(self, _cmd, controller);
	}
}

static id (*gOrigPosterDescriptorGalleryAssetLookupInfoImageFromBundle)(id, SEL, id, id, NSError **) = NULL;
static id DWPosterDescriptorGalleryAssetLookupInfoImageFromBundle(id self, SEL _cmd, id bundle, id traitCollection, NSError **error) {
	id result = nil;
	if (gOrigPosterDescriptorGalleryAssetLookupInfoImageFromBundle) {
		result = gOrigPosterDescriptorGalleryAssetLookupInfoImageFromBundle(self, _cmd, bundle, traitCollection, error);
	}
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PRPosterDescriptorGalleryAssetLookupInfo imageFromBundle bundle=%@ traitCollection=%@ result=%@ error=%@",
		bundle ?: @"(nil)",
		traitCollection ?: @"(nil)",
		result ?: @"(nil)",
		(error && *error) ? *error : @"(nil)"]);
	return result;
}

static id (*gOrigPUWallpaperPosterControllerLoadAssetFromWallpaperURL)(id, SEL, id, NSError **) = NULL;
static id DWPUWallpaperPosterControllerLoadAssetFromWallpaperURL(id self, SEL _cmd, id url, NSError **error) {
	id result = nil;
	if (gOrigPUWallpaperPosterControllerLoadAssetFromWallpaperURL) {
		result = gOrigPUWallpaperPosterControllerLoadAssetFromWallpaperURL(self, _cmd, url, error);
	}
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PUWallpaperPosterController _loadAssetFromWallpaperURL url=%@ result=%@ error=%@",
		url ?: @"(nil)",
		result ?: @"(nil)",
		(error && *error) ? *error : @"(nil)"]);
	return result;
}

static id (*gOrigPRPosterPathUtilitiesLoadHomeScreenConfigurationForPath)(id, SEL, id, NSError **) = NULL;
static id DWPRPosterPathUtilitiesLoadHomeScreenConfigurationForPath(id self, SEL _cmd, id path, NSError **error) {
	id result = nil;
	if (gOrigPRPosterPathUtilitiesLoadHomeScreenConfigurationForPath) {
		result = gOrigPRPosterPathUtilitiesLoadHomeScreenConfigurationForPath(self, _cmd, path, error);
	}
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PRPosterPathUtilities loadHomeScreenConfiguration path=%@ result=%@ error=%@",
		path ?: @"(nil)",
		result ?: @"(nil)",
		(error && *error) ? *error : @"(nil)"]);
	return result;
}

static id (*gOrigPRPosterPathUtilitiesLoadPosterDescriptorGalleryOptionsForPath)(id, SEL, id, NSError **) = NULL;
static id DWPRPosterPathUtilitiesLoadPosterDescriptorGalleryOptionsForPath(id self, SEL _cmd, id path, NSError **error) {
	id result = nil;
	if (gOrigPRPosterPathUtilitiesLoadPosterDescriptorGalleryOptionsForPath) {
		result = gOrigPRPosterPathUtilitiesLoadPosterDescriptorGalleryOptionsForPath(self, _cmd, path, error);
	}
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PRPosterPathUtilities loadPosterDescriptorGalleryOptions path=%@ result=%@ error=%@",
		path ?: @"(nil)",
		result ?: @"(nil)",
		(error && *error) ? *error : @"(nil)"]);
	return result;
}

static id (*gOrigPRPosterPathUtilitiesLoadRenderingConfigurationForPath)(id, SEL, id, NSError **) = NULL;
static id DWPRPosterPathUtilitiesLoadRenderingConfigurationForPath(id self, SEL _cmd, id path, NSError **error) {
	id result = nil;
	if (gOrigPRPosterPathUtilitiesLoadRenderingConfigurationForPath) {
		result = gOrigPRPosterPathUtilitiesLoadRenderingConfigurationForPath(self, _cmd, path, error);
	}
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PRPosterPathUtilities loadRenderingConfiguration path=%@ result=%@ error=%@",
		path ?: @"(nil)",
		result ?: @"(nil)",
		(error && *error) ? *error : @"(nil)"]);
	return result;
}

static id (*gOrigPRPosterPathUtilitiesLoadOtherMetadataForPath)(id, SEL, id, NSError **) = NULL;
static id DWPRPosterPathUtilitiesLoadOtherMetadataForPath(id self, SEL _cmd, id path, NSError **error) {
	id result = nil;
	if (gOrigPRPosterPathUtilitiesLoadOtherMetadataForPath) {
		result = gOrigPRPosterPathUtilitiesLoadOtherMetadataForPath(self, _cmd, path, error);
	}
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PRPosterPathUtilities loadOtherMetadata path=%@ result=%@ error=%@",
		path ?: @"(nil)",
		result ?: @"(nil)",
		(error && *error) ? *error : @"(nil)"]);
	return result;
}

static void (*gOrigPosterBoardUICoordinatorSceneDidCompleteUpdateWithContextError)(id, SEL, id, id, id) = NULL;
static void DWPosterBoardUICoordinatorSceneDidCompleteUpdateWithContextError(id self, SEL _cmd, id scene, id context, id error) {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PosterBoardUICoordinator sceneDidCompleteUpdate scene=%@ context=%@ error=%@",
		scene ?: @"(nil)",
		context ?: @"(nil)",
		error ?: @"(nil)"]);
	if (gOrigPosterBoardUICoordinatorSceneDidCompleteUpdateWithContextError) {
		gOrigPosterBoardUICoordinatorSceneDidCompleteUpdateWithContextError(self, _cmd, scene, context, error);
	}
}

static void (*gOrigPosterBoardUICoordinatorSnapshotSourceFailedToReadSnapshotAtURLError)(id, SEL, id, id, id) = NULL;
static void DWPosterBoardUICoordinatorSnapshotSourceFailedToReadSnapshotAtURLError(id self, SEL _cmd, id snapshotSource, id url, id error) {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PosterBoardUICoordinator failedToReadSnapshot source=%@ url=%@ error=%@",
		snapshotSource ?: @"(nil)",
		url ?: @"(nil)",
		error ?: @"(nil)"]);
	if (gOrigPosterBoardUICoordinatorSnapshotSourceFailedToReadSnapshotAtURLError) {
		gOrigPosterBoardUICoordinatorSnapshotSourceFailedToReadSnapshotAtURLError(self, _cmd, snapshotSource, url, error);
	}
}

static void (*gOrigPosterBoardUICoordinatorSnapshotSourceFailedToReadColorStatisticsAtURLError)(id, SEL, id, id, id) = NULL;
static void DWPosterBoardUICoordinatorSnapshotSourceFailedToReadColorStatisticsAtURLError(id self, SEL _cmd, id snapshotSource, id url, id error) {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PosterBoardUICoordinator failedToReadColorStatistics source=%@ url=%@ error=%@",
		snapshotSource ?: @"(nil)",
		url ?: @"(nil)",
		error ?: @"(nil)"]);
	if (gOrigPosterBoardUICoordinatorSnapshotSourceFailedToReadColorStatisticsAtURLError) {
		gOrigPosterBoardUICoordinatorSnapshotSourceFailedToReadColorStatisticsAtURLError(self, _cmd, snapshotSource, url, error);
	}
}

static void DWInstallHookIfMethodExists(const char *className, SEL selector, IMP replacement, IMP *originalOut) {
	Class cls = objc_getClass(className);
	if (!cls) return;
	Method method = class_getInstanceMethod(cls, selector);
	if (!method) return;
	MSHookMessageEx(cls, selector, replacement, originalOut);
}

static void DWInstallClassHookIfMethodExists(const char *className, SEL selector, IMP replacement, IMP *originalOut) {
	Class cls = objc_getClass(className);
	if (!cls) return;
	Class meta = object_getClass(cls);
	if (!meta) return;
	Method method = class_getClassMethod(cls, selector);
	if (!method) return;
	MSHookMessageEx(meta, selector, replacement, originalOut);
}

static void DWInstallSwiftCoordinatorHooks(void) {
	NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
	if (![processName isEqualToString:@"Preferences"]) return;
	if (!DWVerboseDiagnosticsEnabled()) return;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		DWInstallHookIfMethodExists("WallpaperSettings.WallpaperPreviewCoordinator",
			@selector(wallpaperPreviewViewControllerSetButtonPressed:),
			(IMP)DWWallpaperPreviewCoordinatorSetButtonPressed,
			(IMP *)&gOrigWallpaperPreviewCoordinatorSetButtonPressed);
		DWInstallHookIfMethodExists("WallpaperSettings.CurrentSystemShellWallpaperPreviewCoordinator",
			@selector(start),
			(IMP)DWCurrentSystemShellWallpaperPreviewCoordinatorStart,
			(IMP *)&gOrigCurrentSystemShellWallpaperPreviewCoordinatorStart);
		DWInstallHookIfMethodExists("WallpaperSettings.CurrentSystemShellWallpaperPreviewCoordinator",
			@selector(wallpaperPreviewViewControllerSetButtonPressed:),
			(IMP)DWCurrentSystemShellWallpaperPreviewCoordinatorSetButtonPressed,
			(IMP *)&gOrigCurrentSystemShellWallpaperPreviewCoordinatorSetButtonPressed);
		DWInstallHookIfMethodExists("WallpaperSettings.PosterBoardUICoordinator",
			@selector(scene:didCompleteUpdateWithContext:error:),
			(IMP)DWPosterBoardUICoordinatorSceneDidCompleteUpdateWithContextError,
			(IMP *)&gOrigPosterBoardUICoordinatorSceneDidCompleteUpdateWithContextError);
		DWInstallHookIfMethodExists("WallpaperSettings.PosterBoardUICoordinator",
			@selector(snapshotSource:failedToReadSnapshotAtURL:error:),
			(IMP)DWPosterBoardUICoordinatorSnapshotSourceFailedToReadSnapshotAtURLError,
			(IMP *)&gOrigPosterBoardUICoordinatorSnapshotSourceFailedToReadSnapshotAtURLError);
		DWInstallHookIfMethodExists("WallpaperSettings.PosterBoardUICoordinator",
			@selector(snapshotSource:failedToReadColorStatisticsAtURL:error:),
			(IMP)DWPosterBoardUICoordinatorSnapshotSourceFailedToReadColorStatisticsAtURLError,
			(IMP *)&gOrigPosterBoardUICoordinatorSnapshotSourceFailedToReadColorStatisticsAtURLError);
		DWInstallHookIfMethodExists("PRPosterDescriptorGalleryAssetLookupInfo",
			@selector(imageFromBundle:traitCollection:error:),
			(IMP)DWPosterDescriptorGalleryAssetLookupInfoImageFromBundle,
			(IMP *)&gOrigPosterDescriptorGalleryAssetLookupInfoImageFromBundle);
		DWInstallHookIfMethodExists("PUWallpaperPosterController",
			@selector(_loadAssetFromWallpaperURL:error:),
			(IMP)DWPUWallpaperPosterControllerLoadAssetFromWallpaperURL,
			(IMP *)&gOrigPUWallpaperPosterControllerLoadAssetFromWallpaperURL);
		DWInstallClassHookIfMethodExists("PRPosterPathUtilities",
			@selector(loadHomeScreenConfigurationForPath:error:),
			(IMP)DWPRPosterPathUtilitiesLoadHomeScreenConfigurationForPath,
			(IMP *)&gOrigPRPosterPathUtilitiesLoadHomeScreenConfigurationForPath);
		DWInstallClassHookIfMethodExists("PRPosterPathUtilities",
			@selector(loadPosterDescriptorGalleryOptionsForPath:error:),
			(IMP)DWPRPosterPathUtilitiesLoadPosterDescriptorGalleryOptionsForPath,
			(IMP *)&gOrigPRPosterPathUtilitiesLoadPosterDescriptorGalleryOptionsForPath);
		DWInstallClassHookIfMethodExists("PRPosterPathUtilities",
			@selector(loadRenderingConfigurationForPath:error:),
			(IMP)DWPRPosterPathUtilitiesLoadRenderingConfigurationForPath,
			(IMP *)&gOrigPRPosterPathUtilitiesLoadRenderingConfigurationForPath);
		DWInstallClassHookIfMethodExists("PRPosterPathUtilities",
			@selector(loadOtherMetadataForPath:error:),
			(IMP)DWPRPosterPathUtilitiesLoadOtherMetadataForPath,
			(IMP *)&gOrigPRPosterPathUtilitiesLoadOtherMetadataForPath);
	});
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
	NSString *processName = NSProcessInfo.processInfo.processName;
	if (!DWProcessNameMatchesProbeTarget(processName)) return;
	if (!DWVerboseDiagnosticsEnabled()) return;

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		DWLogProcessProbeSnapshot(@"delayed-2s");
		DWLogPreferenceClassSummary(@"delayed-2s");
		DWLogPreferenceTargetedSelectors(@"delayed-2s");
		DuoWallWriteCompatibilityDump();
	});
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		DWLogProcessProbeSnapshot(@"delayed-12s");
		DWLogPreferenceClassSummary(@"delayed-12s");
		DWLogPreferenceTargetedSelectors(@"delayed-12s");
		DuoWallWriteCompatibilityDump();
	});
}

static void DWRegisterApplyNotificationIfNeeded(void) {
	NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
	if ([processName isEqualToString:@"SpringBoard"] && !gDWRegisteredApplyObserver) {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
			NULL,
			DWHandleApplyRequestNotification,
			DWApplyRequestNotification,
			NULL,
			CFNotificationSuspensionBehaviorDeliverImmediately);
		gDWRegisteredApplyObserver = YES;
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] Registered DuoWall apply notification observer.", processName]);
	}

	if (!gDWRegisteredCollectionsObserver &&
		DWShouldObserveCollectionsNotificationsForProcess(processName)) {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
			NULL,
			DWHandleCollectionsChangedNotification,
			DWCollectionsChangedNotification,
			NULL,
			CFNotificationSuspensionBehaviorDeliverImmediately);
		gDWRegisteredCollectionsObserver = YES;
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] Registered DuoWall collections-changed observer.", processName]);
	}
}

static void DWLogManagerSelectorsIfNeeded(void) {
	NSString *processName = NSProcessInfo.processInfo.processName ?: @"Unknown";
	if (![processName isEqualToString:@"SpringBoard"]) return;

	DWLogSelectorsForClassNamed(@"WKSystemShellWallpaperManager");
	DWLogSelectorsForClassNamed(@"WKCurrentWallpaperManager");
	DWLogSelectorsForClassNamed(@"WKWallpaperRepresentingCollectionsManager");
	DWLogSelectorsForClassNamed(@"WKWallpaperRepresentingCollection");
	DWLogSelectorsForClassNamed(@"WKWallpaperBundleCollection");
}

static id DWWallpaper(BOOL dark) {
	Class wallpaperClass = NSClassFromString(@"WKStillWallpaper");
	if (!wallpaperClass) return nil;

	NSURL *lightURL = [NSURL fileURLWithPath:DWImagePath(NO)];
	NSURL *imageURL = [NSURL fileURLWithPath:DWImagePath(dark)];
	id instance = [wallpaperClass alloc];
	SEL typedSelector = @selector(initWithIdentifier:name:type:thumbnailImageURL:fullsizeImageURL:);
	SEL renderedSelector = @selector(initWithIdentifier:name:thumbnailImageURL:fullsizeImageURL:renderedImageURL:);
	unsigned long long identifier = 0x44555741 + (dark ? 1 : 0);

	if ([instance respondsToSelector:typedSelector]) {
		return [(WKStillWallpaper *)instance initWithIdentifier:identifier
			name:dark ? [NSString stringWithFormat:@"%@ Dark", DWCurrentFriendlyName()] : [NSString stringWithFormat:@"%@ Light", DWCurrentFriendlyName()]
			type:0
			thumbnailImageURL:lightURL
			fullsizeImageURL:imageURL];
	}

	if ([instance respondsToSelector:renderedSelector]) {
		return [(WKStillWallpaper *)instance initWithIdentifier:identifier
			name:dark ? [NSString stringWithFormat:@"%@ Dark", DWCurrentFriendlyName()] : [NSString stringWithFormat:@"%@ Light", DWCurrentFriendlyName()]
			thumbnailImageURL:lightURL
			fullsizeImageURL:imageURL
			renderedImageURL:nil];
	}

	return [(WKStillWallpaper *)instance initWithIdentifier:identifier
		name:dark ? [NSString stringWithFormat:@"%@ Dark", DWCurrentFriendlyName()] : [NSString stringWithFormat:@"%@ Light", DWCurrentFriendlyName()]
		thumbnailImageURL:lightURL
		fullsizeImageURL:imageURL];
}

static id DWRuntimeSelectorValue(id object, SEL selector) {
	if (!object || !selector || ![object respondsToSelector:selector]) return nil;
	id (*typedMsgSend)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
	return typedMsgSend(object, selector);
}

%hook WKWallpaperBundleCollection

- (long long)numberOfItems {
	long long original = %orig;
	NSString *displayName = nil;
	id previewBundle = nil;
	@try {
		displayName = DWRuntimeSelectorValue(self, NSSelectorFromString(@"displayName"));
		previewBundle = DWRuntimeSelectorValue(self, NSSelectorFromString(@"previewBundle"));
	} @catch (__unused NSException *exception) {}
	BOOL isAggregateDuoWall = [displayName isEqualToString:@"DuoWall"];
	if (!isAggregateDuoWall && previewBundle) {
		@try {
			NSString *bundleName = [previewBundle valueForKey:@"name"];
			NSString *bundleFamily = [previewBundle valueForKey:@"family"];
			NSString *bundlePath = [[previewBundle valueForKey:@"url"] path];
			isAggregateDuoWall = [bundleName isEqualToString:@"DuoWall"] ||
				[bundleFamily isEqualToString:@"DuoWall"] ||
				[bundlePath containsString:@"/Application Support/DuoWall/"];
		} @catch (__unused NSException *exception) {}
	}
	if (isAggregateDuoWall) {
		NSArray *bundles = DWInstalledDuoWallBundles();
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] WKWallpaperBundleCollection aggregate numberOfItems original=%lld overridden=%@ displayName=%@",
			NSProcessInfo.processInfo.processName ?: @"Unknown",
			original,
			@(bundles.count),
			displayName ?: @"(nil)"]);
		return (long long)bundles.count;
	}
	if (self.wallpaperType == 0) {
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] WKWallpaperBundleCollection numberOfItems original=%lld ready=%@",
			NSProcessInfo.processInfo.processName ?: @"Unknown",
			original,
			DWWallpapersReady() ? @"YES" : @"NO"]);
	}
	return original;
}

- (id)wallpaperBundleAtIndex:(unsigned long long)index {
	NSString *displayName = nil;
	id previewBundle = nil;
	@try {
		displayName = DWRuntimeSelectorValue(self, NSSelectorFromString(@"displayName"));
		previewBundle = DWRuntimeSelectorValue(self, NSSelectorFromString(@"previewBundle"));
	} @catch (__unused NSException *exception) {}
	BOOL isAggregateDuoWall = [displayName isEqualToString:@"DuoWall"];
	if (!isAggregateDuoWall && previewBundle) {
		@try {
			NSString *bundleName = [previewBundle valueForKey:@"name"];
			NSString *bundleFamily = [previewBundle valueForKey:@"family"];
			NSString *bundlePath = [[previewBundle valueForKey:@"url"] path];
			isAggregateDuoWall = [bundleName isEqualToString:@"DuoWall"] ||
				[bundleFamily isEqualToString:@"DuoWall"] ||
				[bundlePath containsString:@"/Application Support/DuoWall/"];
		} @catch (__unused NSException *exception) {}
	}
	if (isAggregateDuoWall) {
		NSArray *bundles = DWInstalledDuoWallBundles();
		if (index < (unsigned long long)bundles.count) {
			id bundle = bundles[(NSUInteger)index];
			DWWriteBackendLog([NSString stringWithFormat:@"[%@] WKWallpaperBundleCollection aggregate wallpaperBundleAtIndex index=%llu bundle=%@ displayName=%@",
				NSProcessInfo.processInfo.processName ?: @"Unknown",
				index,
				bundle ?: @"(nil)",
				displayName ?: @"(nil)"]);
			return bundle;
		}
	}
	id bundle = %orig;
	if (self.wallpaperType == 0) {
		DWCaptureLogicalScreenClassFromBundle(bundle, @"WKWallpaperBundleCollection wallpaperBundleAtIndex");
	}
	return bundle;
}

- (id)wallpaperBundleWithIdentifier:(id)identifier {
	NSString *displayName = nil;
	id previewBundle = nil;
	@try {
		displayName = DWRuntimeSelectorValue(self, NSSelectorFromString(@"displayName"));
		previewBundle = DWRuntimeSelectorValue(self, NSSelectorFromString(@"previewBundle"));
	} @catch (__unused NSException *exception) {}
	BOOL isAggregateDuoWall = [displayName isEqualToString:@"DuoWall"];
	if (!isAggregateDuoWall && previewBundle) {
		@try {
			NSString *bundleName = [previewBundle valueForKey:@"name"];
			NSString *bundleFamily = [previewBundle valueForKey:@"family"];
			NSString *bundlePath = [[previewBundle valueForKey:@"url"] path];
			isAggregateDuoWall = [bundleName isEqualToString:@"DuoWall"] ||
				[bundleFamily isEqualToString:@"DuoWall"] ||
				[bundlePath containsString:@"/Application Support/DuoWall/"];
		} @catch (__unused NSException *exception) {}
	}
	if (isAggregateDuoWall) {
		NSArray *bundles = DWInstalledDuoWallBundles();
		for (id bundle in bundles) {
			@try {
				id rawIdentifier = [bundle valueForKey:@"identifier"];
				if ((identifier && [rawIdentifier isEqual:identifier]) ||
					([identifier isKindOfClass:[NSString class]] && [[rawIdentifier description] isEqualToString:identifier]) ||
					([rawIdentifier isKindOfClass:[NSString class]] && [[identifier description] isEqualToString:rawIdentifier])) {
					return bundle;
				}
			} @catch (__unused NSException *exception) {}
		}
	}
	return %orig;
}

%end

%hook WKWallpaperRepresentingCollectionsManager

+ (id)defaultManager {
	id manager = %orig;
	DWWriteBackendLog([NSString stringWithFormat:@"[%@] WKWallpaperRepresentingCollectionsManager defaultManager=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		manager]);
	DWInjectDuoWallIntoCollectionsManager(manager, @"defaultManager");
	return manager;
}

+ (id)defaultLegacyManager {
	id manager = %orig;
	DWWriteBackendLog([NSString stringWithFormat:@"[%@] WKWallpaperRepresentingCollectionsManager defaultLegacyManager=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		manager]);
	DWInjectDuoWallIntoCollectionsManager(manager, @"defaultLegacyManager");
	return manager;
}

- (void)_loadCollections {
	%orig;
	DWInjectDuoWallIntoCollectionsManager(self, @"_loadCollections");
}

- (void)_loadSystemWallpaperCollections {
	%orig;
	DWInjectDuoWallIntoCollectionsManager(self, @"_loadSystemWallpaperCollections");
}

- (void)_loadLegacySystemWallpaperCollections {
	%orig;
	DWInjectDuoWallIntoCollectionsManager(self, @"_loadLegacySystemWallpaperCollections");
}

- (NSInteger)numberOfWallpaperCollections {
	NSInteger original = %orig;
	id collections = [self respondsToSelector:@selector(_wallpaperCollections)] ? [self _wallpaperCollections] : nil;
	NSInteger surfacedCount = [collections respondsToSelector:@selector(count)] ? [collections count] : original;
	DWWriteBackendLog([NSString stringWithFormat:@"[%@] WKWallpaperRepresentingCollectionsManager numberOfWallpaperCollections original=%ld hasDuoWall=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		(long)original,
		(surfacedCount > original) ? @"YES" : @"NO"]);
	return surfacedCount;
}

- (id)wallpaperCollectionAtIndex:(NSInteger)index {
	id collection = %orig;
	if (!collection) {
		id collections = [self respondsToSelector:@selector(_wallpaperCollections)] ? [self _wallpaperCollections] : nil;
		if ([collections respondsToSelector:@selector(count)] && index >= 0 && index < [collections count]) {
			collection = [collections objectAtIndex:index];
		}
	}
	DWWriteBackendLog([NSString stringWithFormat:@"[%@] wallpaperCollectionAtIndex index=%ld collection=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		(long)index,
		DWSummarizeWallpaperCollection(collection)]);
	return collection;
}

- (id)wallpaperCollectionWithIdentifier:(NSString *)identifier {
	id collection = %orig;
	DWWriteBackendLog([NSString stringWithFormat:@"[%@] wallpaperCollectionWithIdentifier identifier=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		identifier ?: @"(nil)"]);
	if (collection) return collection;
	if (!identifier.length) return nil;

	id lookup = [self respondsToSelector:@selector(_wallpaperCollectionLookupTable)] ? [self _wallpaperCollectionLookupTable] : nil;
	if ([lookup isKindOfClass:[NSDictionary class]]) {
		return lookup[identifier];
	}

	Class mapTableClass = NSClassFromString(@"NSMapTable");
	if (mapTableClass && [lookup isKindOfClass:mapTableClass]) {
		return [lookup objectForKey:identifier];
	}

	return nil;
}

- (id)_wallpaperCollections {
	id collections = %orig;
	id augmentedCollections = DWCollectionsByAppendingDuoWallIfNeeded(collections);
	DWWriteBackendLog([NSString stringWithFormat:@"[%@] _wallpaperCollections originalClass=%@ originalCount=%@ augmentedCount=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		collections ? NSStringFromClass([collections class]) : @"nil",
		[collections respondsToSelector:@selector(count)] ? @([collections count]) : @"(n/a)",
		[augmentedCollections respondsToSelector:@selector(count)] ? @([augmentedCollections count]) : @"(n/a)"]);
	return augmentedCollections;
}

- (id)_wallpaperCollectionLookupTable {
	id lookup = %orig;
	id augmentedLookup = DWCollectionLookupByAppendingDuoWallIfNeeded(lookup);
	DWWriteBackendLog([NSString stringWithFormat:@"[%@] _wallpaperCollectionLookupTable originalClass=%@ originalCount=%@ augmentedCount=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		lookup ? NSStringFromClass([lookup class]) : @"nil",
		[lookup respondsToSelector:@selector(count)] ? @([lookup count]) : @"(n/a)",
		[augmentedLookup respondsToSelector:@selector(count)] ? @([augmentedLookup count]) : @"(n/a)"]);
	return augmentedLookup;
}

%end

%hook WKWallpaperRepresentingCollection

- (id)initWithWallpaperCollectionIdentifier:(NSString *)identifier
	displayName:(NSString *)displayName
	previewWallpaperRepresenting:(id)previewWallpaper
	wallpapersShareBaseAppearance:(BOOL)sharesAppearance
	wallpaperRepresentingCollection:(id)wallpapers
	downloadManager:(id)downloadManager {
	id augmentedWallpapers = DWAugmentedWallpapersForCollectionsCategory(wallpapers, identifier, displayName);
	id result = %orig(identifier, displayName, previewWallpaper, sharesAppearance, augmentedWallpapers, downloadManager);
	DWCaptureLogicalScreenClassFromObject(previewWallpaper, @"WKWallpaperRepresentingCollection previewWallpaperRepresenting");
	DWCaptureLogicalScreenClassFromObject(augmentedWallpapers, @"WKWallpaperRepresentingCollection wallpaperRepresentingCollection");
	DWWriteBackendLog([NSString stringWithFormat:@"[%@] WKWallpaperRepresentingCollection init identifier=%@ displayName=%@ wallpapersClass=%@ augmentedClass=%@",
		NSProcessInfo.processInfo.processName ?: @"Unknown",
		identifier ?: @"(nil)",
		displayName ?: @"(nil)",
		wallpapers ? NSStringFromClass([wallpapers class]) : @"nil",
		augmentedWallpapers ? NSStringFromClass([augmentedWallpapers class]) : @"nil"]);
	return result;
}

- (id)previewWallpaperRepresenting {
	id result = %orig;
	NSString *identifier = nil;
	@try {
		if ([self respondsToSelector:@selector(wallpaperCollectionIdentifier)]) {
			identifier = [self wallpaperCollectionIdentifier];
		}
	} @catch (__unused NSException *exception) {}
	if (DWIsAggregateDuoWallCollectionIdentifier(identifier)) {
		NSArray *bundles = DWInstalledDuoWallBundles();
		if (bundles.count) return [bundles lastObject];
	}
	return result;
}

- (id)_wallpaperBundles {
	id result = %orig;
	NSString *identifier = nil;
	@try {
		if ([self respondsToSelector:@selector(wallpaperCollectionIdentifier)]) {
			identifier = [self wallpaperCollectionIdentifier];
		}
	} @catch (__unused NSException *exception) {}
	if (DWIsAggregateDuoWallCollectionIdentifier(identifier)) {
		NSArray *bundles = DWInstalledDuoWallBundles();
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] _wallpaperBundles aggregate identifier=%@ count=%@",
			NSProcessInfo.processInfo.processName ?: @"Unknown",
			identifier ?: @"(nil)",
			@(bundles.count)]);
		return bundles;
	}
	return result;
}

- (id)_wallpaperLookupTable {
	id result = %orig;
	NSString *identifier = nil;
	@try {
		if ([self respondsToSelector:@selector(wallpaperCollectionIdentifier)]) {
			identifier = [self wallpaperCollectionIdentifier];
		}
	} @catch (__unused NSException *exception) {}
	if (DWIsAggregateDuoWallCollectionIdentifier(identifier)) {
		NSArray *bundles = DWInstalledDuoWallBundles();
		NSMutableDictionary *lookup = [NSMutableDictionary dictionary];
		for (id bundle in bundles) {
			@try {
				id rawIdentifier = [bundle valueForKey:@"identifier"];
				if ([rawIdentifier isKindOfClass:[NSNumber class]]) {
					lookup[rawIdentifier] = bundle;
					lookup[[rawIdentifier stringValue]] = bundle;
				} else if ([rawIdentifier isKindOfClass:[NSString class]]) {
					lookup[rawIdentifier] = bundle;
				}
			} @catch (__unused NSException *exception) {}
		}
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] _wallpaperLookupTable aggregate identifier=%@ count=%@",
			NSProcessInfo.processInfo.processName ?: @"Unknown",
			identifier ?: @"(nil)",
			@(lookup.count)]);
		return lookup;
	}
	return result;
}

- (NSInteger)numberOfWallpapers {
	NSString *identifier = nil;
	@try {
		if ([self respondsToSelector:@selector(wallpaperCollectionIdentifier)]) {
			identifier = [self wallpaperCollectionIdentifier];
		}
	} @catch (__unused NSException *exception) {}
	if (DWIsAggregateDuoWallCollectionIdentifier(identifier)) {
		NSArray *bundles = DWInstalledDuoWallBundles();
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] numberOfWallpapers aggregate identifier=%@ count=%@",
			NSProcessInfo.processInfo.processName ?: @"Unknown",
			identifier ?: @"(nil)",
			@(bundles.count)]);
		return (NSInteger)bundles.count;
	}
	return %orig;
}

- (id)wallpaperBundleAtIndex:(NSInteger)index {
	NSString *identifier = nil;
	@try {
		if ([self respondsToSelector:@selector(wallpaperCollectionIdentifier)]) {
			identifier = [self wallpaperCollectionIdentifier];
		}
	} @catch (__unused NSException *exception) {}
	if (DWIsAggregateDuoWallCollectionIdentifier(identifier)) {
		NSArray *bundles = DWInstalledDuoWallBundles();
		if (index >= 0 && index < (NSInteger)bundles.count) {
			id bundle = bundles[(NSUInteger)index];
			DWWriteBackendLog([NSString stringWithFormat:@"[%@] wallpaperBundleAtIndex aggregate identifier=%@ index=%ld bundle=%@",
				NSProcessInfo.processInfo.processName ?: @"Unknown",
				identifier ?: @"(nil)",
				(long)index,
				bundle ?: @"(nil)"]);
			return bundle;
		}
	}
	return %orig;
}

- (id)wallpaperRepresentingWithIdentifier:(id)representedIdentifier {
	NSString *identifier = nil;
	@try {
		if ([self respondsToSelector:@selector(wallpaperCollectionIdentifier)]) {
			identifier = [self wallpaperCollectionIdentifier];
		}
	} @catch (__unused NSException *exception) {}
	if (DWIsAggregateDuoWallCollectionIdentifier(identifier)) {
		NSArray *bundles = DWInstalledDuoWallBundles();
		for (id bundle in bundles) {
			@try {
				id rawIdentifier = [bundle valueForKey:@"identifier"];
				if ((representedIdentifier && [rawIdentifier isEqual:representedIdentifier]) ||
					([representedIdentifier isKindOfClass:[NSString class]] && [[rawIdentifier description] isEqualToString:representedIdentifier]) ||
					([rawIdentifier isKindOfClass:[NSString class]] && [[representedIdentifier description] isEqualToString:rawIdentifier])) {
					return bundle;
				}
			} @catch (__unused NSException *exception) {}
		}
	}
	return %orig;
}

- (BOOL)containsWallpaperRepresentingWithIdentifier:(id)representedIdentifier {
	NSString *identifier = nil;
	@try {
		if ([self respondsToSelector:@selector(wallpaperCollectionIdentifier)]) {
			identifier = [self wallpaperCollectionIdentifier];
		}
	} @catch (__unused NSException *exception) {}
	if (DWIsAggregateDuoWallCollectionIdentifier(identifier)) {
		NSArray *bundles = DWInstalledDuoWallBundles();
		for (id bundle in bundles) {
			@try {
				id rawIdentifier = [bundle valueForKey:@"identifier"];
				if ((representedIdentifier && [rawIdentifier isEqual:representedIdentifier]) ||
					([representedIdentifier isKindOfClass:[NSString class]] && [[rawIdentifier description] isEqualToString:representedIdentifier]) ||
					([rawIdentifier isKindOfClass:[NSString class]] && [[representedIdentifier description] isEqualToString:rawIdentifier])) {
					return YES;
				}
			} @catch (__unused NSException *exception) {}
		}
		return NO;
	}
	return %orig;
}

%end

%ctor {
	DWInstallDictionaryProbe();
	DWInstallSwiftCoordinatorHooks();
	DWWriteBackendLog([NSString stringWithFormat:@"[%@] DuoWall loaded", NSProcessInfo.processInfo.processName ?: @"Unknown"]);
	if (DWVerboseDiagnosticsEnabled()) {
		DWLogProcessProbeSnapshot(@"ctor");
		DWLogPreferenceClassSummary(@"ctor");
		DWLogPreferenceTargetedSelectors(@"ctor");
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		DWRegisterApplyNotificationIfNeeded();
		DWLogManagerSelectorsIfNeeded();
		DWScheduleCompatibilityDumps();
		DWRestoreBackedUpDescriptorsIfNeeded(@"ctor");
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			DWWarmLogicalScreenClassInSystemProcess();
		});
	});
}

%hook WKWallpaperBundle

%property (nonatomic, retain) NSNumber *dw_duoWallMarker;

+ (instancetype)createTemporaryWallpaperBundleWithImages:(NSDictionary *)images
	videoAssetURLs:(NSDictionary *)videoAssetURLs
	wallpaperOptions:(NSDictionary *)wallpaperOptions
	error:(NSError **)error {
	if (DWVerboseDiagnosticsEnabled()) {
		DWWriteBackendLog([NSString stringWithFormat:@"\n[%@] WKWallpaperBundle temporary constructor INPUT\nimages=%@\nvideoAssetURLs=%@\nwallpaperOptions=%@",
			NSProcessInfo.processInfo.processName,
			DWSummarizeDictionary(images),
			DWSummarizeDictionary(videoAssetURLs),
			DWSummarizeDictionary(wallpaperOptions)]);
	}
	id result = %orig;
	if (DWVerboseDiagnosticsEnabled()) {
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] WKWallpaperBundle temporary constructor OUTPUT\nresultClass=%@\nresult=%@\nerror=%@\n",
			NSProcessInfo.processInfo.processName,
			result ? NSStringFromClass([result class]) : @"nil",
			result ?: @"(nil)",
			(error && *error) ? *error : @"(nil)"]);
	}
	return result;
}

- (id)initWithURL:(NSURL *)url {
	id result = %orig;
	if (!self.dw_duoWallMarker.boolValue) {
		DWCaptureLogicalScreenClassFromBundle(result, [NSString stringWithFormat:@"WKWallpaperBundle initWithURL %@", url.path ?: @"(nil)"]);
	}
	return result;
}

- (NSString *)name {
	return self.dw_duoWallMarker.boolValue ? DWCurrentFriendlyName() : %orig;
}

- (NSString *)family {
	return self.dw_duoWallMarker.boolValue ? DWCurrentFriendlyName() : %orig;
}

- (NSString *)logicalScreenClass {
	NSString *logicalScreenClass = %orig;
	if (!self.dw_duoWallMarker.boolValue) {
		DWRememberLogicalScreenClass(logicalScreenClass, @"WKWallpaperBundle logicalScreenClass");
	}
	return logicalScreenClass;
}

- (unsigned long long)version {
	return self.dw_duoWallMarker.boolValue ? 1 : %orig;
}

- (unsigned long long)identifier {
	return self.dw_duoWallMarker.boolValue ? 0x44555741 : %orig;
}

- (BOOL)hasDistinctWallpapersForLocations {
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

%hook WKSystemShellWallpaperManager

- (void)setHomeScreenWallpaperRepresenting:(id)wallpaper completion:(id)completion {
	if (DWVerboseDiagnosticsEnabled()) {
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] system-shell home setter wallpaperClass=%@ wallpaper=%@",
			NSProcessInfo.processInfo.processName,
			wallpaper ? NSStringFromClass([wallpaper class]) : @"nil",
			wallpaper ?: @"(nil)"]);
	}
	%orig;
}

- (void)setLockScreenWallpaperRepresenting:(id)wallpaper mirrorToHomeScreen:(BOOL)mirror completion:(id)completion {
	if (DWVerboseDiagnosticsEnabled()) {
		DWWriteBackendLog([NSString stringWithFormat:@"[%@] system-shell setter wallpaperClass=%@ mirror=%@ wallpaper=%@",
			NSProcessInfo.processInfo.processName,
			wallpaper ? NSStringFromClass([wallpaper class]) : @"nil",
			mirror ? @"YES" : @"NO",
			wallpaper ?: @"(nil)"]);
	}
	%orig;
}

%end

%hook WKStillWallpaper

- (BOOL)copyWallpaperContentsToDestinationDirectoryURL:(NSURL *)destinationURL error:(NSError **)error {
	if (gDWTracingTemporaryBundle) {
		DWWriteBackendLog([NSString stringWithFormat:@"WKStillWallpaper COPY input thumbnail=%@ fullsize=%@ destination=%@",
			[self thumbnailImageURL] ?: @"(nil)",
			[self fullsizeImageURL] ?: @"(nil)",
			destinationURL ?: @"(nil)"]);
	}
	BOOL result = %orig;
	if (gDWTracingTemporaryBundle) {
		DWWriteBackendLog([NSString stringWithFormat:@"WKStillWallpaper COPY output result=%@ error=%@",
			result ? @"YES" : @"NO",
			(error && *error) ? *error : @"(nil)"]);
	}
	return result;
}

%new
- (UIImage *)thumbnailImage {
	return [[UIImage alloc] init];
}

%new
- (id)wallpaperValue {
	return nil;
}

%end

%hook WKAbstractWallpaper

- (BOOL)supportsCopying {
	BOOL original = %orig;
	if (!gDWTracingTemporaryBundle) return original;
	DWWriteBackendLog([NSString stringWithFormat:@"%@ supportsCopying original=%@ type=%llu representedType=%llu backingType=%llu thumbnail=%@; temporarily returning YES",
		NSStringFromClass([self class]),
		original ? @"YES" : @"NO",
		[self type],
		[self representedType],
		[self backingType],
		[self thumbnailImageURL] ?: @"(nil)"]);
	return YES;
}

- (BOOL)supportsSerialization {
	BOOL original = %orig;
	if (!gDWTracingTemporaryBundle) return original;
	DWWriteBackendLog([NSString stringWithFormat:@"%@ supportsSerialization original=%@; temporarily returning YES",
		NSStringFromClass([self class]),
		original ? @"YES" : @"NO"]);
	return YES;
}

%end

%hook WSWallpaperSettingsCoordinator

- (void)start {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] WSWallpaperSettingsCoordinator start self=%@",
		self]);
	%orig;
}

- (void)runTestWithTestName:(id)testName options:(id)options {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] WSWallpaperSettingsCoordinator runTestWithTestName=%@ options=%@",
		testName ?: @"(nil)",
		options ?: @"(nil)"]);
	%orig;
}

%end

%hook PBUIWallpaperServer

- (void)setWallpaperImage:(id)image
	adjustedImage:(id)adjustedImage
	thumbnailData:(id)thumbnailData
	imageHashData:(id)imageHashData
	wallpaperOptions:(id)wallpaperOptions
	forLocations:(unsigned long long)locations
	currentWallpaperMode:(long long)wallpaperMode {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperServer setWallpaperImage image=%@ adjustedImage=%@ thumbnailBytes=%@ hashBytes=%@ options=%@ locations=%llu mode=%lld",
		image ?: @"(nil)",
		adjustedImage ?: @"(nil)",
		[thumbnailData respondsToSelector:@selector(length)] ? @([thumbnailData length]) : @"(n/a)",
		[imageHashData respondsToSelector:@selector(length)] ? @([imageHashData length]) : @"(n/a)",
		wallpaperOptions ?: @"(nil)",
		locations,
		wallpaperMode]);
	%orig;
}

- (void)setWallpaperColor:(id)color darkColor:(id)darkColor forLocations:(unsigned long long)locations {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperServer setWallpaperColor color=%@ darkColor=%@ locations=%llu",
		color ?: @"(nil)",
		darkColor ?: @"(nil)",
		locations]);
	%orig;
}

- (void)setWallpaperGradient:(id)gradient forLocations:(unsigned long long)locations {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperServer setWallpaperGradient gradient=%@ locations=%llu",
		gradient ?: @"(nil)",
		locations]);
	%orig;
}

- (void)restoreDefaultWallpaper {
	DWWriteBackendLog(@"[Preferences] PBUIWallpaperServer restoreDefaultWallpaper");
	%orig;
}

%end

%hook PBUIWallpaperUserDefaultsDataStore

- (void)setWallpaperImage:(id)image forVariant:(unsigned long long)variant wallpaperMode:(long long)wallpaperMode {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperUserDefaultsDataStore setWallpaperImage image=%@ variant=%llu mode=%lld",
		image ?: @"(nil)",
		variant,
		wallpaperMode]);
	%orig;
}

- (void)setWallpaperOptions:(id)options forVariant:(unsigned long long)variant wallpaperMode:(long long)wallpaperMode {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperUserDefaultsDataStore setWallpaperOptions options=%@ variant=%llu mode=%lld",
		options ?: @"(nil)",
		variant,
		wallpaperMode]);
	%orig;
}

- (void)setWallpaperThumbnailData:(id)thumbnailData forVariant:(unsigned long long)variant wallpaperMode:(long long)wallpaperMode {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperUserDefaultsDataStore setWallpaperThumbnailData bytes=%@ variant=%llu mode=%lld",
		[thumbnailData respondsToSelector:@selector(length)] ? @([thumbnailData length]) : @"(n/a)",
		variant,
		wallpaperMode]);
	%orig;
}

- (void)setWallpaperOriginalImage:(id)image forVariant:(unsigned long long)variant wallpaperMode:(long long)wallpaperMode {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperUserDefaultsDataStore setWallpaperOriginalImage image=%@ variant=%llu mode=%lld",
		image ?: @"(nil)",
		variant,
		wallpaperMode]);
	%orig;
}

%end

%hook PBUIWallpaperDefaults

- (void)setWallpaperOptions:(id)options forLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperDefaults setWallpaperOptions options=%@ locations=%llu mode=%lld",
		options ?: @"(nil)",
		locations,
		wallpaperMode]);
	%orig;
}

- (void)setWallpaperKitData:(id)data forLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperDefaults setWallpaperKitData data=%@ locations=%llu mode=%lld",
		data ?: @"(nil)",
		locations,
		wallpaperMode]);
	%orig;
}

- (void)setName:(id)name forLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperDefaults setName name=%@ locations=%llu mode=%lld",
		name ?: @"(nil)",
		locations,
		wallpaperMode]);
	%orig;
}

- (void)setCropRect:(CGRect)cropRect forLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperDefaults setCropRect cropRect=%@ locations=%llu mode=%lld",
		NSStringFromCGRect(cropRect),
		locations,
		wallpaperMode]);
	%orig;
}

- (void)setZoomScale:(double)zoomScale forLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperDefaults setZoomScale zoomScale=%g locations=%llu mode=%lld",
		zoomScale,
		locations,
		wallpaperMode]);
	%orig;
}

%end

%hook PBUIWallpaperDefaultsWrapper

- (void)setWallpaperKitData:(id)data {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperDefaultsWrapper setWallpaperKitData data=%@",
		data ?: @"(nil)"]);
	%orig;
}

- (void)setWallpaperOptions:(id)options {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperDefaultsWrapper setWallpaperOptions options=%@",
		options ?: @"(nil)"]);
	%orig;
}

%end

%hook PBUIWallpaperConfigurationManager

- (void)beginChangeBatch {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperConfigurationManager beginChangeBatch self=%@",
		self]);
	%orig;
}

- (void)endChangeBatch {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperConfigurationManager endChangeBatch self=%@",
		self]);
	%orig;
}

- (void)notifyDelegateOfChangesToVariants:(unsigned long long)variants {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperConfigurationManager notifyDelegateOfChanges variants=%llu",
		variants]);
	%orig;
}

- (void)setWallpaperBundle:(id)bundle appearance:(long long)appearance {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperConfigurationManager setWallpaperBundle bundle=%@ appearance=%lld",
		bundle ?: @"(nil)",
		appearance]);
	%orig;
}

- (void)setWallpaperImage:(id)image
	adjustedImage:(id)adjustedImage
	thumbnailData:(id)thumbnailData
	imageHashData:(id)imageHashData
	wallpaperOptions:(id)wallpaperOptions
	forVariants:(unsigned long long)variants
	wallpaperMode:(long long)wallpaperMode {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperConfigurationManager setWallpaperImage image=%@ adjustedImage=%@ thumbnailBytes=%@ hashBytes=%@ options=%@ variants=%llu mode=%lld",
		image ?: @"(nil)",
		adjustedImage ?: @"(nil)",
		[thumbnailData respondsToSelector:@selector(length)] ? @([thumbnailData length]) : @"(n/a)",
		[imageHashData respondsToSelector:@selector(length)] ? @([imageHashData length]) : @"(n/a)",
		wallpaperOptions ?: @"(nil)",
		variants,
		wallpaperMode]);
	%orig;
}

- (void)setWallpaperOptions:(id)options
	forVariants:(unsigned long long)variants
	wallpaperMode:(long long)wallpaperMode {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperConfigurationManager setWallpaperOptions options=%@ variants=%llu mode=%lld",
		options ?: @"(nil)",
		variants,
		wallpaperMode]);
	%orig;
}

%end

%hook PBUIWallpaperViewController

- (void)setWallpaperConfigurationManager:(id)manager {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperViewController setWallpaperConfigurationManager manager=%@",
		manager ?: @"(nil)"]);
	%orig;
}

- (void)wallpaperConfigurationManager:(id)manager didChangeWallpaperConfigurationForVariants:(unsigned long long)variants {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperViewController didChangeWallpaperConfiguration manager=%@ variants=%llu",
		manager ?: @"(nil)",
		variants]);
	%orig;
}

- (void)updateWallpaperForLocations:(unsigned long long)locations withCompletion:(id)completion {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperViewController updateWallpaperForLocations locations=%llu completion=%@",
		locations,
		completion ?: @"(nil)"]);
	%orig;
}

- (void)updateWallpaperForLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode withCompletion:(id)completion {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperViewController updateWallpaperForLocations locations=%llu mode=%lld completion=%@",
		locations,
		wallpaperMode,
		completion ?: @"(nil)"]);
	%orig;
}

- (void)noteWallpapersDidUpdate {
	DWWriteBackendLog(@"[Preferences] PBUIWallpaperViewController noteWallpapersDidUpdate");
	%orig;
}

%end

%hook PBUIWallpaperRemoteViewController

- (void)setWallpaperConfigurationManager:(id)manager {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperRemoteViewController setWallpaperConfigurationManager manager=%@",
		manager ?: @"(nil)"]);
	%orig;
}

- (void)wallpaperConfigurationManager:(id)manager didChangeWallpaperConfigurationForVariants:(unsigned long long)variants {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperRemoteViewController didChangeWallpaperConfiguration manager=%@ variants=%llu",
		manager ?: @"(nil)",
		variants]);
	%orig;
}

- (void)updateWallpaperForLocations:(unsigned long long)locations withCompletion:(id)completion {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperRemoteViewController updateWallpaperForLocations locations=%llu completion=%@",
		locations,
		completion ?: @"(nil)"]);
	%orig;
}

- (void)updateWallpaperForLocations:(unsigned long long)locations wallpaperMode:(long long)wallpaperMode withCompletion:(id)completion {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] PBUIWallpaperRemoteViewController updateWallpaperForLocations locations=%llu mode=%lld completion=%@",
		locations,
		wallpaperMode,
		completion ?: @"(nil)"]);
	%orig;
}

%end

%hook SBSUIWallpaperPreviewViewController

- (void)userDidTapOnSetButton:(id)sender {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] SBSUIWallpaperPreviewViewController userDidTapOnSetButton sender=%@",
		sender ?: @"(nil)"]);
	%orig;
}

- (void)setWallpaperForLocations:(unsigned long long)locations {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] SBSUIWallpaperPreviewViewController setWallpaperForLocations locations=%llu",
		locations]);
	%orig;
}

- (void)setWallpaperForLocations:(unsigned long long)locations completionHandler:(id)completionHandler {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] SBSUIWallpaperPreviewViewController setWallpaperForLocations locations=%llu completion=%@",
		locations,
		completionHandler ?: @"(nil)"]);
	%orig;
}

- (void)_setWallpaperForLocationsOnMainThread:(unsigned long long)locations completionHandler:(id)completionHandler {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] SBSUIWallpaperPreviewViewController _setWallpaperForLocationsOnMainThread locations=%llu completion=%@",
		locations,
		completionHandler ?: @"(nil)"]);
	%orig;
}

- (void)setWallpaperImages:(id)images
	options:(id)options
	locations:(unsigned long long)locations
	completionHandler:(id)completionHandler {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] SBSUIWallpaperPreviewViewController setWallpaperImages images=%@ options=%@ locations=%llu completion=%@",
		images ?: @"(nil)",
		options ?: @"(nil)",
		locations,
		completionHandler ?: @"(nil)"]);
	%orig;
}

- (void)_setWallpaperImagesOnMainThread:(id)images
	options:(id)options
	locations:(unsigned long long)locations
	completionHandler:(id)completionHandler {
	DWWriteBackendLog([NSString stringWithFormat:@"[Preferences] SBSUIWallpaperPreviewViewController _setWallpaperImagesOnMainThread images=%@ options=%@ locations=%llu completion=%@",
		images ?: @"(nil)",
		options ?: @"(nil)",
		locations,
		completionHandler ?: @"(nil)"]);
	%orig;
}

%end
