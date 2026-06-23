#import "DWRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <dlfcn.h>
#import <spawn.h>
#import <sys/wait.h>

extern char **environ;

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleIdentifier;
@end

static NSString * const DWStorageDirectory = @"/var/mobile/Library/Application Support/DuoWall";
static NSString * const DWFriendlyNameFileName = @"WallpaperName.txt";
static NSString * const DWPosterCollectionsExtensionIdentifier = @"com.apple.WallpaperKit.CollectionsPoster";
static NSString * const DWDescriptorBackupDirectoryName = @"DescriptorBackups";
static NSString * const DWPendingCollectionsRefreshDefaultsKey = @"PendingCollectionsRefresh";
static NSString * const DWBackendLoggingEnabledDefaultsKey = @"BackendLoggingEnabled";

@interface DWPreviewButtonCell : PSTableCell
@property (nonatomic, strong) UIImageView *previewImageView;
@property (nonatomic, strong) UILabel *subtitleLabel;
@end

@interface DWSavedWallpaperCell : PSTableCell
@property (nonatomic, strong) UIImageView *lightPreviewImageView;
@property (nonatomic, strong) UIImageView *darkPreviewImageView;
@property (nonatomic, strong) UILabel *dwTitleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@end

@interface DWManageWallpapersController : PSListController
@property (nonatomic, copy) NSArray<NSDictionary *> *installedWallpapers;
@end

@interface DWRootListController ()
@property (nonatomic, copy) NSString *pendingImageName;
@property (nonatomic, strong) UIBarButtonItem *saveRefreshBarButtonItem;
@end

@implementation DWPreviewButtonCell

+ (CGFloat)preferredHeightForWidth:(CGFloat)width {
	#pragma unused(width)
	return 152.0;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
	if (!self) return nil;

	self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	self.selectionStyle = UITableViewCellSelectionStyleDefault;

	_previewImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_previewImageView.translatesAutoresizingMaskIntoConstraints = NO;
	_previewImageView.contentMode = UIViewContentModeScaleAspectFill;
	_previewImageView.clipsToBounds = YES;
	_previewImageView.layer.cornerRadius = 12.0;
	_previewImageView.layer.cornerCurve = kCACornerCurveContinuous;
	[self.contentView addSubview:_previewImageView];

	self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
	self.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];

	_subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
	_subtitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
	_subtitleLabel.textColor = [UIColor secondaryLabelColor];
	_subtitleLabel.numberOfLines = 2;
	[self.contentView addSubview:_subtitleLabel];

	[NSLayoutConstraint activateConstraints:@[
		[_previewImageView.leadingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
		[_previewImageView.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor constant:-26.0],
		[_previewImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
		[_previewImageView.heightAnchor constraintEqualToConstant:88.0],

		[self.titleLabel.leadingAnchor constraintEqualToAnchor:_previewImageView.leadingAnchor],
		[self.titleLabel.trailingAnchor constraintEqualToAnchor:_previewImageView.trailingAnchor],
		[self.titleLabel.topAnchor constraintEqualToAnchor:_previewImageView.bottomAnchor constant:10.0],

		[_subtitleLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
		[_subtitleLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
		[_subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:2.0],
		[_subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-12.0]
	]];

	[self refreshCellContentsWithSpecifier:specifier];
	return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
	[super refreshCellContentsWithSpecifier:specifier];

	self.titleLabel.text = [specifier propertyForKey:@"previewTitle"] ?: specifier.name;
	self.subtitleLabel.text = [specifier propertyForKey:@"previewSubtitle"] ?: @"";

	NSString *imagePath = [specifier propertyForKey:@"previewImagePath"];
	UIImage *image = imagePath.length ? [UIImage imageWithContentsOfFile:imagePath] : nil;
	if (image) {
		self.previewImageView.image = image;
		self.previewImageView.backgroundColor = [UIColor tertiarySystemFillColor];
	} else {
		self.previewImageView.image = nil;
		self.previewImageView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
	}
}

@end

static NSString *DWPrefsPosterBoardDataContainerPath(void) {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *applicationsRoot = @"/var/mobile/Containers/Data/Application";
	for (NSString *child in [fileManager contentsOfDirectoryAtPath:applicationsRoot error:nil] ?: @[]) {
		NSString *candidate = [applicationsRoot stringByAppendingPathComponent:child];
		NSString *metadataPath = [candidate stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
		NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
		if ([metadata[@"MCMMetadataIdentifier"] isEqualToString:@"com.apple.PosterBoard"]) {
			return candidate;
		}
	}
	return nil;
}

static NSString *DWPrefsPosterDescriptorStoreRootPath(void) {
	NSString *containerPath = DWPrefsPosterBoardDataContainerPath();
	if (!containerPath.length) return nil;
	NSString *storeBasePath = [containerPath stringByAppendingPathComponent:@"Library/Application Support/PRBPosterExtensionDataStore"];
	NSArray<NSString *> *sortedVersions = [[[[NSFileManager defaultManager] contentsOfDirectoryAtPath:storeBasePath error:nil] ?: @[] sortedArrayUsingComparator:^NSComparisonResult(NSString *lhs, NSString *rhs) {
		return [rhs compare:lhs options:NSNumericSearch];
	}] copy];
	for (NSString *version in sortedVersions) {
		NSString *candidate = [storeBasePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/Extensions/%@/descriptors", version, DWPosterCollectionsExtensionIdentifier]];
		BOOL isDirectory = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath:candidate isDirectory:&isDirectory] && isDirectory) {
			return candidate;
		}
	}
	return nil;
}

static NSString *DWPrefsTrimmedFileString(NSString *path) {
	NSString *value = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL DWPrefsDescriptorRepresentsDuoWall(NSDictionary *userInfo, NSString *wallpaperDirectoryName) {
	NSString *wallpaperFileName = [userInfo isKindOfClass:[NSDictionary class]] ? userInfo[@"wallpaperRepresentingFileName"] : nil;
	return [wallpaperFileName containsString:@".DuoWall-"] || [wallpaperDirectoryName containsString:@".DuoWall-"];
}

static void DWPrefsAppendBackendMarker(NSString *message) {
	typedef void (*DuoWallAppendMarkerFunction)(NSString *message);
	DuoWallAppendMarkerFunction function = (DuoWallAppendMarkerFunction)dlsym(RTLD_DEFAULT, "DuoWallAppendBackendLogMarker");
	if (function) function(message);
}

static void DWPrefsNotifyCollectionsChanged(NSString *reason) {
	typedef void (*DuoWallCollectionsChangedFunction)(NSString *reason);
	DuoWallCollectionsChangedFunction function = (DuoWallCollectionsChangedFunction)dlsym(RTLD_DEFAULT, "DuoWallNotifyCollectionsChanged");
	if (function) function(reason);
}

static NSUserDefaults *DWPrefsUserDefaults(void) {
	return [[NSUserDefaults alloc] initWithSuiteName:@"com.futur3sn0w.duowall"];
}

static BOOL DWPrefsHasPendingCollectionsRefresh(void) {
	return [DWPrefsUserDefaults() boolForKey:DWPendingCollectionsRefreshDefaultsKey];
}

static void DWPrefsSetPendingCollectionsRefresh(BOOL pending) {
	NSUserDefaults *defaults = DWPrefsUserDefaults();
	[defaults setBool:pending forKey:DWPendingCollectionsRefreshDefaultsKey];
	[defaults synchronize];
}

static BOOL DWPrefsBackendLoggingEnabled(void) {
	return [DWPrefsUserDefaults() boolForKey:DWBackendLoggingEnabledDefaultsKey];
}

static void DWPrefsSetBackendLoggingEnabled(BOOL enabled) {
	NSUserDefaults *defaults = DWPrefsUserDefaults();
	[defaults setBool:enabled forKey:DWBackendLoggingEnabledDefaultsKey];
	[defaults synchronize];
}

static NSUInteger DWPrefsDirectoryEntryCount(NSString *rootPath) {
	if (!rootPath.length) return 0;
	NSArray<NSString *> *children = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:rootPath error:nil] ?: @[];
	NSUInteger count = 0;
	for (NSString *child in children) {
		NSString *path = [rootPath stringByAppendingPathComponent:child];
		BOOL isDirectory = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory) {
			count += 1;
		}
	}
	return count;
}

static void DWPrefsLogDescriptorRoots(NSString *reason) {
	NSString *liveRoot = DWPrefsPosterDescriptorStoreRootPath();
	NSString *backupRoot = [DWStorageDirectory stringByAppendingPathComponent:DWDescriptorBackupDirectoryName];
	DWPrefsAppendBackendMarker([NSString stringWithFormat:@"Prefs descriptor roots %@ live=%@ (%lu) backup=%@ (%lu)",
		reason ?: @"(nil)",
		liveRoot ?: @"(nil)",
		(unsigned long)DWPrefsDirectoryEntryCount(liveRoot),
		backupRoot,
		(unsigned long)DWPrefsDirectoryEntryCount(backupRoot)]);
}

static NSArray<NSDictionary *> *DWPrefsInstalledDuoWallEntriesAtRoot(NSString *descriptorStoreRoot, NSString *sourceLabel) {
	if (!descriptorStoreRoot.length) return @[];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray<NSString *> *children = [[fileManager contentsOfDirectoryAtPath:descriptorStoreRoot error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)] ?: @[];
	NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];

	for (NSString *child in children) {
		NSString *descriptorPath = [descriptorStoreRoot stringByAppendingPathComponent:child];
		BOOL isDirectory = NO;
		if (![fileManager fileExistsAtPath:descriptorPath isDirectory:&isDirectory] || !isDirectory) continue;

		NSString *versionsRoot = [descriptorPath stringByAppendingPathComponent:@"versions"];
		NSArray<NSString *> *versionChildren = [[fileManager contentsOfDirectoryAtPath:versionsRoot error:nil] sortedArrayUsingSelector:@selector(localizedStandardCompare:)] ?: @[];
		NSString *selectedVersion = nil;
		NSString *contentsPath = nil;
		for (NSString *version in versionChildren) {
			NSString *candidateContentsPath = [[versionsRoot stringByAppendingPathComponent:version] stringByAppendingPathComponent:@"contents"];
			BOOL contentsIsDirectory = NO;
			if ([fileManager fileExistsAtPath:candidateContentsPath isDirectory:&contentsIsDirectory] && contentsIsDirectory) {
				selectedVersion = version;
				contentsPath = candidateContentsPath;
				break;
			}
		}
		if (!contentsPath.length) {
			NSString *fallbackContentsPath = [descriptorPath stringByAppendingPathComponent:@"versions/1/contents"];
			BOOL fallbackIsDirectory = NO;
			if ([fileManager fileExistsAtPath:fallbackContentsPath isDirectory:&fallbackIsDirectory] && fallbackIsDirectory) {
				selectedVersion = @"1";
				contentsPath = fallbackContentsPath;
			}
		}
		if (!contentsPath.length) continue;

		NSArray<NSString *> *contentsChildren = [fileManager contentsOfDirectoryAtPath:contentsPath error:nil] ?: @[];
		NSString *userInfoPath = [contentsPath stringByAppendingPathComponent:@"com.apple.posterkit.provider.contents.userInfo"];
		NSDictionary *userInfo = [NSDictionary dictionaryWithContentsOfFile:userInfoPath] ?: @{};
		NSString *wallpaperDirectoryName = userInfo[@"wallpaperRepresentingFileName"];
		if (![wallpaperDirectoryName isKindOfClass:[NSString class]] || !wallpaperDirectoryName.length) {
			for (NSString *contentChild in contentsChildren) {
				if ([[contentChild pathExtension] isEqualToString:@"wallpaper"]) {
					wallpaperDirectoryName = contentChild;
					break;
				}
			}
		}
		if (!DWPrefsDescriptorRepresentsDuoWall(userInfo, wallpaperDirectoryName)) continue;

		NSString *wallpaperPath = [contentsPath stringByAppendingPathComponent:wallpaperDirectoryName ?: @""];
		NSString *wallpaperPlistPath = [wallpaperPath stringByAppendingPathComponent:@"Wallpaper.plist"];
		NSDictionary *wallpaperPlist = [NSDictionary dictionaryWithContentsOfFile:wallpaperPlistPath] ?: @{};
		NSString *displayName = wallpaperPlist[@"name"];
		if (![displayName isKindOfClass:[NSString class]] || !displayName.length) displayName = @"DuoWall";

		NSString *identifierFile = DWPrefsTrimmedFileString([descriptorPath stringByAppendingPathComponent:@"com.apple.posterkit.provider.descriptor.identifier"]);
		NSString *lightPath = [wallpaperPath stringByAppendingPathComponent:@"Light.jpg"];
		NSString *darkPath = [wallpaperPath stringByAppendingPathComponent:@"Dark.jpg"];

		[entries addObject:@{
			@"displayName": displayName,
			@"descriptorPath": descriptorPath,
			@"descriptorName": child,
			@"identifierFile": identifierFile ?: @"",
			@"version": selectedVersion ?: @"",
			@"wallpaperPath": wallpaperPath,
			@"lightPath": lightPath,
			@"darkPath": darkPath,
			@"dwSource": sourceLabel ?: @"unknown"
		}];
	}

	return entries;
}

static NSArray<NSDictionary *> *DWPrefsInstalledDuoWallEntries(void) {
	DWPrefsLogDescriptorRoots(@"before-entry-scan");

	NSMutableArray<NSDictionary *> *entries = [NSMutableArray array];
	NSMutableSet<NSString *> *seenDescriptorNames = [NSMutableSet set];

	NSString *liveRoot = DWPrefsPosterDescriptorStoreRootPath();
	for (NSDictionary *entry in DWPrefsInstalledDuoWallEntriesAtRoot(liveRoot, @"live")) {
		NSString *descriptorName = entry[@"descriptorName"];
		if (descriptorName.length) [seenDescriptorNames addObject:descriptorName];
		[entries addObject:entry];
	}

	NSString *backupRoot = [DWStorageDirectory stringByAppendingPathComponent:DWDescriptorBackupDirectoryName];
	for (NSDictionary *entry in DWPrefsInstalledDuoWallEntriesAtRoot(backupRoot, @"backup")) {
		NSString *descriptorName = entry[@"descriptorName"];
		if (descriptorName.length && [seenDescriptorNames containsObject:descriptorName]) continue;
		if (descriptorName.length) [seenDescriptorNames addObject:descriptorName];
		[entries addObject:entry];
	}

	DWPrefsAppendBackendMarker([NSString stringWithFormat:@"Prefs installed entries result count=%lu", (unsigned long)entries.count]);

	return entries;
}

@implementation DWSavedWallpaperCell

+ (CGFloat)preferredHeightForWidth:(CGFloat)width {
	#pragma unused(width)
	return 138.0;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
	if (!self) return nil;

	self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	self.selectionStyle = UITableViewCellSelectionStyleDefault;
	self.titleLabel.hidden = YES;

	_lightPreviewImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	_darkPreviewImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	for (UIImageView *imageView in @[_lightPreviewImageView, _darkPreviewImageView]) {
		imageView.translatesAutoresizingMaskIntoConstraints = NO;
		imageView.contentMode = UIViewContentModeScaleAspectFill;
		imageView.clipsToBounds = YES;
		imageView.layer.cornerRadius = 12.0;
		imageView.layer.cornerCurve = kCACornerCurveContinuous;
		imageView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
		[self.contentView addSubview:imageView];
	}

	_dwTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_dwTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
	_dwTitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
	_dwTitleLabel.numberOfLines = 1;
	[self.contentView addSubview:_dwTitleLabel];

	_subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
	_subtitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
	_subtitleLabel.textColor = [UIColor secondaryLabelColor];
	_subtitleLabel.numberOfLines = 2;
	[self.contentView addSubview:_subtitleLabel];

	[NSLayoutConstraint activateConstraints:@[
		[_lightPreviewImageView.leadingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
		[_lightPreviewImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12.0],
		[_lightPreviewImageView.widthAnchor constraintEqualToConstant:96.0],
		[_lightPreviewImageView.heightAnchor constraintEqualToConstant:64.0],

		[_darkPreviewImageView.leadingAnchor constraintEqualToAnchor:_lightPreviewImageView.trailingAnchor constant:10.0],
		[_darkPreviewImageView.topAnchor constraintEqualToAnchor:_lightPreviewImageView.topAnchor],
		[_darkPreviewImageView.widthAnchor constraintEqualToAnchor:_lightPreviewImageView.widthAnchor],
		[_darkPreviewImageView.heightAnchor constraintEqualToAnchor:_lightPreviewImageView.heightAnchor],

		[_dwTitleLabel.leadingAnchor constraintEqualToAnchor:_lightPreviewImageView.leadingAnchor],
		[_dwTitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor constant:-30.0],
		[_dwTitleLabel.topAnchor constraintEqualToAnchor:_lightPreviewImageView.bottomAnchor constant:10.0],

		[_subtitleLabel.leadingAnchor constraintEqualToAnchor:_dwTitleLabel.leadingAnchor],
		[_subtitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor constant:-30.0],
		[_subtitleLabel.topAnchor constraintEqualToAnchor:_dwTitleLabel.bottomAnchor constant:2.0],
		[_subtitleLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-12.0]
	]];

	[self refreshCellContentsWithSpecifier:specifier];
	return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
	[super refreshCellContentsWithSpecifier:specifier];

	self.dwTitleLabel.text = [specifier propertyForKey:@"dwDisplayName"] ?: specifier.name;
	self.subtitleLabel.text = [specifier propertyForKey:@"dwSubtitle"] ?: @"";

	NSString *lightPath = [specifier propertyForKey:@"dwLightPath"];
	NSString *darkPath = [specifier propertyForKey:@"dwDarkPath"];
	self.lightPreviewImageView.image = lightPath.length ? [UIImage imageWithContentsOfFile:lightPath] : nil;
	self.darkPreviewImageView.image = darkPath.length ? [UIImage imageWithContentsOfFile:darkPath] : nil;
}

@end

@implementation DWManageWallpapersController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Saved DuoWalls";
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.installedWallpapers = DWPrefsInstalledDuoWallEntries();
	[self reloadSpecifiers];
	[self.table reloadData];
}

- (PSSpecifier *)groupWithFooter:(NSString *)footer {
	PSSpecifier *specifier = [PSSpecifier emptyGroupSpecifier];
	[specifier setProperty:footer forKey:@"footerText"];
	return specifier;
}

- (PSSpecifier *)specifierForWallpaperEntry:(NSDictionary *)entry {
	NSString *displayName = entry[@"displayName"] ?: @"DuoWall";
	NSString *identifierFile = entry[@"identifierFile"];
	NSString *source = entry[@"dwSource"];
	NSString *sourceSuffix = [source isEqualToString:@"backup"] ? @" • Backup copy" : @"";
	NSString *subtitle = identifierFile.length
		? [NSString stringWithFormat:@"Descriptor ID: %@%@", identifierFile, sourceSuffix]
		: [NSString stringWithFormat:@"Folder: %@%@", entry[@"descriptorName"] ?: @"(unknown)", sourceSuffix];
	PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:displayName
		target:self
		set:NULL
		get:NULL
		detail:Nil
		cell:PSButtonCell
		edit:Nil];
	[specifier setProperty:DWSavedWallpaperCell.class forKey:@"cellClass"];
	[specifier setProperty:displayName forKey:@"dwDisplayName"];
	[specifier setProperty:subtitle forKey:@"dwSubtitle"];
	[specifier setProperty:entry[@"lightPath"] ?: @"" forKey:@"dwLightPath"];
	[specifier setProperty:entry[@"darkPath"] ?: @"" forKey:@"dwDarkPath"];
	[specifier setProperty:entry[@"descriptorPath"] ?: @"" forKey:@"dwDescriptorPath"];
	return specifier;
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		NSMutableArray *specifiers = [NSMutableArray array];
		NSArray<NSDictionary *> *entries = self.installedWallpapers ?: @[];
		NSString *footer = entries.count
			? @"Swipe left to delete an installed DuoWall, or tap a row for actions and details."
			: @"No installed DuoWalls were found yet. Apply one from the main DuoWall page first.";
		[specifiers addObject:[self groupWithFooter:footer]];
		for (NSDictionary *entry in entries) {
			[specifiers addObject:[self specifierForWallpaperEntry:entry]];
		}
		_specifiers = [specifiers copy];
	}
	return _specifiers;
}

- (void)reloadSpecifiers {
	_specifiers = nil;
	[super reloadSpecifiers];
}

- (NSDictionary *)wallpaperEntryForSpecifier:(PSSpecifier *)specifier {
	NSString *descriptorPath = [specifier propertyForKey:@"dwDescriptorPath"];
	for (NSDictionary *entry in self.installedWallpapers ?: @[]) {
		if ([entry[@"descriptorPath"] isEqualToString:descriptorPath]) return entry;
	}
	return nil;
}

- (NSDictionary *)wallpaperEntryForRow:(NSInteger)row {
	NSArray<NSDictionary *> *entries = self.installedWallpapers ?: @[];
	if (row < 0 || row >= (NSInteger)entries.count) return nil;
	return entries[(NSUInteger)row];
}

- (void)showWallpaperActions:(PSSpecifier *)specifier {
	NSDictionary *entry = [self wallpaperEntryForSpecifier:specifier];
	if (!entry) return;

	NSString *displayName = entry[@"displayName"] ?: @"DuoWall";
	NSString *message = [NSString stringWithFormat:@"Light: %@\nDark: %@",
		[entry[@"lightPath"] lastPathComponent] ?: @"(missing)",
		[entry[@"darkPath"] lastPathComponent] ?: @"(missing)"];

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:displayName
		message:message
		preferredStyle:UIAlertControllerStyleActionSheet];
	[alert addAction:[UIAlertAction actionWithTitle:@"Delete from Collections" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
		[self deleteWallpaperEntry:entry];
	}]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	if (alert.popoverPresentationController) {
		UIView *sourceView = self.view;
		alert.popoverPresentationController.sourceView = sourceView;
		alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(sourceView.bounds), CGRectGetMidY(sourceView.bounds), 1.0, 1.0);
	}
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	#pragma unused(tableView)
	NSDictionary *entry = [self wallpaperEntryForRow:indexPath.row];
	if (!entry) return;
	NSString *descriptorPath = entry[@"descriptorPath"];
	if (!descriptorPath.length) return;
	PSSpecifier *specifier = [self specifierForWallpaperEntry:entry];
	[self showWallpaperActions:specifier];
}

- (void)deleteWallpaperEntry:(NSDictionary *)entry {
	NSString *descriptorPath = entry[@"descriptorPath"];
	NSString *descriptorName = entry[@"descriptorName"];
	if (!descriptorPath.length && !descriptorName.length) return;

	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSMutableArray<NSString *> *pathsToRemove = [NSMutableArray array];
	if (descriptorPath.length) [pathsToRemove addObject:descriptorPath];

	NSString *liveRoot = DWPrefsPosterDescriptorStoreRootPath();
	NSString *backupRoot = [DWStorageDirectory stringByAppendingPathComponent:DWDescriptorBackupDirectoryName];
	for (NSString *candidateRoot in @[liveRoot ?: @"", backupRoot ?: @""]) {
		if (!candidateRoot.length || !descriptorName.length) continue;
		NSString *candidatePath = [candidateRoot stringByAppendingPathComponent:descriptorName];
		if (![pathsToRemove containsObject:candidatePath]) {
			[pathsToRemove addObject:candidatePath];
		}
	}

	NSError *error = nil;
	BOOL removedAnything = NO;
	for (NSString *path in pathsToRemove) {
		if (![fileManager fileExistsAtPath:path]) continue;
		NSError *removeError = nil;
		if ([fileManager removeItemAtPath:path error:&removeError]) {
		removedAnything = YES;
			continue;
		}
		if (!error) error = removeError;
	}

	if (!removedAnything && error) {
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Couldn’t Delete DuoWall"
			message:error.localizedDescription ?: @"The saved DuoWall could not be removed."
			preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
		[self presentViewController:alert animated:YES completion:nil];
		return;
	}

	self.installedWallpapers = DWPrefsInstalledDuoWallEntries();
	DWPrefsSetPendingCollectionsRefresh(YES);
	[self reloadSpecifiers];
	[self.table reloadData];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	#pragma unused(tableView)
	return [self wallpaperEntryForRow:indexPath.row] != nil;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	#pragma unused(tableView)
	if (editingStyle != UITableViewCellEditingStyleDelete) return;
	NSDictionary *entry = [self wallpaperEntryForRow:indexPath.row];
	if (entry) [self deleteWallpaperEntry:entry];
}

@end

@implementation DWRootListController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.saveRefreshBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save"
		style:UIBarButtonItemStyleDone
		target:self
		action:@selector(saveAndRefreshWallpaperList)];
	self.navigationItem.rightBarButtonItem = self.saveRefreshBarButtonItem;
	[self refreshSaveButtonState];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	DWPrefsLogDescriptorRoots(@"root-viewWillAppear");
	[self refreshSaveButtonState];
}

- (NSString *)pathForImageName:(NSString *)name {
	return [DWStorageDirectory stringByAppendingPathComponent:name];
}

- (NSString *)friendlyNamePath {
	return [DWStorageDirectory stringByAppendingPathComponent:DWFriendlyNameFileName];
}

- (NSString *)normalizedFriendlyName:(NSString *)name {
	NSString *trimmed = [[name ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
	return trimmed.length ? trimmed : nil;
}

- (NSString *)currentFriendlyName {
	NSString *stored = [NSString stringWithContentsOfFile:[self friendlyNamePath]
		encoding:NSUTF8StringEncoding
		error:nil];
	return [self normalizedFriendlyName:stored];
}

- (BOOL)hasFriendlyName {
	return [self currentFriendlyName].length > 0;
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

- (PSSpecifier *)switchSpecifierNamed:(NSString *)name get:(SEL)getter set:(SEL)setter {
	return [PSSpecifier preferenceSpecifierNamed:name
		target:self
		set:setter
		get:getter
		detail:Nil
		cell:PSSwitchCell
		edit:Nil];
}

- (PSSpecifier *)previewSpecifierWithTitle:(NSString *)title
	imageName:(NSString *)imageName
	action:(SEL)action {
	BOOL hasImage = [self hasImageNamed:imageName];
	NSString *subtitle = hasImage
		? @"Tap anywhere here to choose a different image."
		: @"No image selected yet. Tap anywhere here to choose one.";
	PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:title
		target:self
		set:NULL
		get:NULL
		detail:Nil
		cell:PSButtonCell
		edit:Nil];
	specifier.buttonAction = action;
	[specifier setProperty:DWPreviewButtonCell.class forKey:@"cellClass"];
	[specifier setProperty:title forKey:@"previewTitle"];
	[specifier setProperty:subtitle forKey:@"previewSubtitle"];
	if (hasImage) {
		[specifier setProperty:[self pathForImageName:imageName] forKey:@"previewImagePath"];
	}
	return specifier;
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		BOOL ready = [self hasImageNamed:@"Light.jpg"] && [self hasImageNamed:@"Dark.jpg"];
		NSString *friendlyName = [self currentFriendlyName];
		NSString *footer = ready
			? @"Both images are ready. iOS should switch between them with system appearance once DuoWall is applied."
			: @"Choose one image for each appearance. Your originals stay in Photos; DuoWall stores its own high-quality copies on the device.";

		_specifiers = [@[
			[self groupWithFooter:footer],
			[self previewSpecifierWithTitle:@"Light Appearance Image" imageName:@"Light.jpg" action:@selector(chooseLightImage)],
			[self buttonNamed:@"Clear Light Image" action:@selector(clearLightImage)],
			[self previewSpecifierWithTitle:@"Dark Appearance Image" imageName:@"Dark.jpg" action:@selector(chooseDarkImage)],
			[self buttonNamed:@"Clear Dark Image" action:@selector(clearDarkImage)],
			[PSSpecifier emptyGroupSpecifier],
			[self groupWithFooter:(friendlyName.length
				? [NSString stringWithFormat:@"When you tap Apply, DuoWall will confirm the friendly name before saving. Current name: %@.", friendlyName]
				: @"When you tap Apply, DuoWall will first ask for the friendly name that should appear in Collections.")],
			[self buttonNamed:@"Name & Apply DuoWall" action:@selector(applyDuoWall)],
			[self groupWithFooter:@"Manage the DuoWalls already added to Collections. You can preview or delete saved entries here, then use Save & Refresh Wallpaper List below to push the current state through."],
			[PSSpecifier preferenceSpecifierNamed:@"Manage Saved DuoWalls"
				target:self
				set:NULL
				get:NULL
				detail:DWManageWallpapersController.class
				cell:PSLinkCell
				edit:Nil],
			[self groupWithFooter:@"Open the native wallpaper picker to see your DuoWalls under Collections, or reset the currently selected source images if you want to start over."],
			[self buttonNamed:@"Open Wallpaper Picker" action:@selector(openWallpaperSettings)],
			[self buttonNamed:@"Reset Images" action:@selector(confirmReset)],
			[self groupWithFooter:@"Backend logging is off by default. Turn this on only when we need a fresh DuoWall debug log."],
			[self switchSpecifierNamed:@"Enable Backend Logging" get:@selector(readBackendLoggingPreference:) set:@selector(setBackendLoggingPreference:specifier:)]
		] mutableCopy];
	}

	return _specifiers;
}

- (void)refreshSaveButtonState {
	BOOL pending = DWPrefsHasPendingCollectionsRefresh();
	self.saveRefreshBarButtonItem.enabled = pending;
	self.saveRefreshBarButtonItem.tintColor = pending ? nil : [UIColor systemGrayColor];
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
			[self invalidateModernWallpaper];
			[self reloadSpecifiers];
			[self refreshSaveButtonState];
		});
	}];
}

- (void)invalidateModernWallpaper {
	typedef void (*DuoWallInvalidateFunction)(void);
	DuoWallInvalidateFunction function = (DuoWallInvalidateFunction)dlsym(RTLD_DEFAULT, "DuoWallInvalidateModernWallpaper");
	if (function) function();
}

- (void)requestCollectionsProbeWithReason:(NSString *)reason delay:(NSTimeInterval)delay {
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		typedef void (*DuoWallProbeFunction)(NSString *reason);
		DuoWallProbeFunction function = (DuoWallProbeFunction)dlsym(RTLD_DEFAULT, "DuoWallLogCollectionsProbe");
		if (function) function(reason);
	});
}

- (void)performSaveAndRefreshWallpaperListInteractive:(BOOL)interactive {
	if (!DWPrefsHasPendingCollectionsRefresh()) {
		[self refreshSaveButtonState];
		return;
	}

	DWPrefsAppendBackendMarker(interactive
		? @"Save & Refresh Wallpaper List tapped in Preferences"
		: @"Auto Save & Refresh Wallpaper List triggered by apply");
	DWPrefsLogDescriptorRoots(interactive ? @"before-save-refresh" : @"before-auto-save-refresh");

	typedef void (*DuoWallForceRestoreFunction)(NSString *reason);
	DuoWallForceRestoreFunction restoreFunction = (DuoWallForceRestoreFunction)dlsym(RTLD_DEFAULT, "DuoWallForceRestoreDescriptorBackups");
	if (restoreFunction) restoreFunction(interactive ? @"prefs-save-refresh" : @"prefs-auto-save-refresh");

	DWPrefsNotifyCollectionsChanged(interactive ? @"prefs-save-refresh" : @"prefs-auto-save-refresh");
	[self requestCollectionsProbeWithReason:(interactive ? @"prefs-save-refresh-1s" : @"prefs-auto-save-refresh-1s") delay:1.0];
	[self requestCollectionsProbeWithReason:(interactive ? @"prefs-save-refresh-4s" : @"prefs-auto-save-refresh-4s") delay:4.0];

	void (^commitRefresh)(void) = ^{
		DWPrefsSetPendingCollectionsRefresh(NO);
		[self refreshSaveButtonState];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((interactive ? 0.75 : 1.5) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self restartWallpaperProcessesForRefresh];
		});
	};

	if (!interactive) {
		commitRefresh();
		return;
	}

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Refreshing Wallpaper List"
		message:@"DuoWall will now push the latest descriptor state through and restart the wallpaper-facing processes. Give it a moment, then open the wallpaper list and check Collections."
		preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"Continue" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
		commitRefresh();
	}]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (id)readBackendLoggingPreference:(PSSpecifier *)specifier {
	#pragma unused(specifier)
	return @(DWPrefsBackendLoggingEnabled());
}

- (void)setBackendLoggingPreference:(id)value specifier:(PSSpecifier *)specifier {
	#pragma unused(specifier)
	BOOL enabled = [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : NO;
	DWPrefsSetBackendLoggingEnabled(enabled);
	if (!enabled) {
		typedef void (*DuoWallResetLogFunction)(void);
		DuoWallResetLogFunction resetFunction = (DuoWallResetLogFunction)dlsym(RTLD_DEFAULT, "DuoWallResetBackendLog");
		if (resetFunction) {
			resetFunction();
		} else {
			[[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Documents/DuoWall-backend-log.txt" error:nil];
		}
	}
}

- (void)persistFriendlyName:(NSString *)name {
	NSString *normalized = [self normalizedFriendlyName:name];
	NSError *directoryError = nil;
	[[NSFileManager defaultManager] createDirectoryAtPath:DWStorageDirectory
		withIntermediateDirectories:YES
		attributes:nil
		error:&directoryError];
	if (!normalized.length || directoryError) {
		[self showError:directoryError ?: [NSError errorWithDomain:@"DuoWall" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Give this wallpaper a name before applying it."}]];
		return;
	}

	NSError *writeError = nil;
	[normalized writeToFile:[self friendlyNamePath] atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
	if (writeError) {
		[self showError:writeError];
		return;
	}

	[self invalidateModernWallpaper];
	[self reloadSpecifiers];
	[self refreshSaveButtonState];
}

- (void)promptForWallpaperNameAndApply {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Wallpaper Name"
		message:@"Choose the name DuoWall should use in Collections. Saving this will immediately apply it."
		preferredStyle:UIAlertControllerStyleAlert];
	[alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.placeholder = @"Aurora Night";
		textField.text = [self currentFriendlyName] ?: @"";
		textField.clearButtonMode = UITextFieldViewModeWhileEditing;
	}];
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
		NSString *name = [self normalizedFriendlyName:alert.textFields.firstObject.text];
		if (!name.length) {
			[self showError:[NSError errorWithDomain:@"DuoWall" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Please enter a name for this wallpaper."}]];
			return;
		}
		[self persistFriendlyName:name];
		[self applyDuoWallAfterNamePrompt];
	}]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)applyDuoWallAfterNamePrompt {
	if (![self hasImageNamed:@"Light.jpg"] || ![self hasImageNamed:@"Dark.jpg"]) {
		[self showError:[NSError errorWithDomain:@"DuoWall" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Choose both images before applying DuoWall."}]];
		return;
	}

	typedef void (*DuoWallApplyFunction)(void (^completion)(BOOL success, NSString *message));
	DuoWallApplyFunction function = (DuoWallApplyFunction)dlsym(RTLD_DEFAULT, "DuoWallApplyModernWallpaper");
	if (!function) {
		[self showError:[NSError errorWithDomain:@"DuoWall" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Close Settings completely, reopen DuoWall, and try again."}]];
		return;
	}
	typedef void (*DuoWallAppendMarkerFunction)(NSString *message);
	DuoWallAppendMarkerFunction appendMarker = (DuoWallAppendMarkerFunction)dlsym(RTLD_DEFAULT, "DuoWallAppendBackendLogMarker");
	if (appendMarker) appendMarker(@"Apply DuoWall tapped in Preferences");

	function(^(BOOL success, NSString *message) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (success) {
				DWPrefsSetPendingCollectionsRefresh(YES);
				[self refreshSaveButtonState];
			}
			[self requestCollectionsProbeWithReason:@"prefs-after-apply-1s" delay:1.0];
			[self requestCollectionsProbeWithReason:@"prefs-after-apply-4s" delay:4.0];
			UIAlertController *alert = [UIAlertController alertControllerWithTitle:success ? @"DuoWall Applied" : @"Couldn’t Apply DuoWall"
				message:(success
					? [NSString stringWithFormat:@"%@\n\nDuoWall is now automatically saving and refreshing the wallpaper list. Give it a moment, then check Collections.", message ?: @"DuoWall finished applying."]
					: message)
				preferredStyle:UIAlertControllerStyleAlert];
			[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
				if (!success) return;
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					[self performSaveAndRefreshWallpaperListInteractive:NO];
				});
			}]];
			[self presentViewController:alert animated:YES completion:nil];
		});
	});
}

- (BOOL)spawnDetachedCommandAtPath:(NSString *)launchPath arguments:(NSArray<NSString *> *)arguments {
	if (!launchPath.length) return NO;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if (![fileManager isExecutableFileAtPath:launchPath]) return NO;

	NSMutableArray<NSString *> *allArguments = [NSMutableArray arrayWithObject:launchPath];
	if (arguments.count) [allArguments addObjectsFromArray:arguments];

	char **argv = (char **)calloc(allArguments.count + 1, sizeof(char *));
	if (!argv) return NO;

	for (NSUInteger index = 0; index < allArguments.count; index++) {
		argv[index] = strdup([allArguments[index] UTF8String]);
	}
	argv[allArguments.count] = NULL;

	pid_t pid = 0;
	int status = posix_spawn(&pid, [launchPath fileSystemRepresentation], NULL, NULL, argv, environ);

	for (NSUInteger index = 0; index < allArguments.count; index++) {
		free(argv[index]);
	}
	free(argv);

	if (status != 0) return NO;

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
		int waitStatus = 0;
		waitpid(pid, &waitStatus, 0);
	});
	return YES;
}

- (void)restartWallpaperProcessesForRefresh {
	NSArray<NSString *> *killallPaths = @[@"/var/jb/usr/bin/killall", @"/usr/bin/killall"];
	NSArray<NSString *> *processNames = @[@"PosterBoard", @"WallpaperSettings", @"WallpaperAgent", @"WallpaperHelper", @"Wallpaper"];
	for (NSString *processName in processNames) {
		BOOL launched = NO;
		for (NSString *killallPath in killallPaths) {
			if ([self spawnDetachedCommandAtPath:killallPath arguments:@[@"-TERM", processName]]) {
				launched = YES;
				break;
			}
		}
		DWPrefsAppendBackendMarker([NSString stringWithFormat:@"Prefs refresh restart %@ launched=%@",
			processName,
			launched ? @"YES" : @"NO"]);
	}
}

- (void)saveAndRefreshWallpaperList {
	[self performSaveAndRefreshWallpaperListInteractive:YES];
}

- (void)applyDuoWall {
	if (![self hasImageNamed:@"Light.jpg"] || ![self hasImageNamed:@"Dark.jpg"]) {
		[self showError:[NSError errorWithDomain:@"DuoWall" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Choose both images before applying DuoWall."}]];
		return;
	}

	[self promptForWallpaperNameAndApply];
}

- (void)showError:(NSError *)error {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Couldn’t Save Image"
		message:error.localizedDescription ?: @"DuoWall could not create its wallpaper copy."
		preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)openWallpaperSettings {
	typedef void (*DuoWallAppendMarkerFunction)(NSString *message);
	DuoWallAppendMarkerFunction appendMarker = (DuoWallAppendMarkerFunction)dlsym(RTLD_DEFAULT, "DuoWallAppendBackendLogMarker");
	if (appendMarker) appendMarker(@"Open Wallpaper Picker tapped in Preferences");
	[self requestCollectionsProbeWithReason:@"prefs-before-open-wallpaper-settings" delay:0.0];

	Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
	LSApplicationWorkspace *workspace = [workspaceClass respondsToSelector:@selector(defaultWorkspace)] ? [workspaceClass defaultWorkspace] : nil;
	if ([workspace respondsToSelector:@selector(openApplicationWithBundleID:)] && [workspace openApplicationWithBundleID:@"com.apple.PosterBoard"]) {
		[self requestCollectionsProbeWithReason:@"prefs-after-open-posterboard-3s" delay:3.0];
		return;
	}

	NSArray<NSString *> *fallbackSchemes = @[@"App-prefs:root=Wallpaper", @"prefs:root=Wallpaper"];
	for (NSString *scheme in fallbackSchemes) {
		NSURL *url = [NSURL URLWithString:scheme];
		if ([[UIApplication sharedApplication] canOpenURL:url]) {
			[[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
			[self requestCollectionsProbeWithReason:@"prefs-after-open-wallpaper-settings-3s" delay:3.0];
			return;
		}
	}

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Open Wallpaper Manually"
		message:@"Open Settings → Wallpaper, or long-press the Lock Screen and tap the plus button."
		preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)writeCompatibilityDump {
	typedef void (*DuoWallDumpFunction)(void);
	DuoWallDumpFunction dumpFunction = (DuoWallDumpFunction)dlsym(RTLD_DEFAULT, "DuoWallWriteCompatibilityDump");
	if (dumpFunction) dumpFunction();

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:dumpFunction ? @"Settings Dump Written" : @"Dump Unavailable"
		message:dumpFunction
			? @"Look in /var/mobile/Documents for DuoWall-Preferences-method-dump.txt. Opening the wallpaper picker also creates a DuoWall-PosterBoard-method-dump.txt file."
			: @"Close Settings completely, reopen DuoWall, and try again."
		preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)clearImageNamed:(NSString *)imageName title:(NSString *)title {
	if (![self hasImageNamed:imageName]) {
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
			message:@"There isn’t an image saved for this mode right now."
			preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
		[self presentViewController:alert animated:YES completion:nil];
		return;
	}

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
		message:@"This removes DuoWall’s saved copy for just this appearance. It does not delete anything from Photos."
		preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
		[[NSFileManager defaultManager] removeItemAtPath:[self pathForImageName:imageName] error:nil];
		[self invalidateModernWallpaper];
		[self reloadSpecifiers];
		[self refreshSaveButtonState];
	}]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)clearLightImage {
	[self clearImageNamed:@"Light.jpg" title:@"Clear Light Image?"];
}

- (void)clearDarkImage {
	[self clearImageNamed:@"Dark.jpg" title:@"Clear Dark Image?"];
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
		[self invalidateModernWallpaper];
		[self reloadSpecifiers];
		[self refreshSaveButtonState];
	}]];
	[self presentViewController:alert animated:YES completion:nil];
}

@end
