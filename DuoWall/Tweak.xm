#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
