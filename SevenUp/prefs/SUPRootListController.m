#import "SUPRootListController.h"

#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <UIKit/UIKit.h>

static NSString * const kSUPLogPath = @"/var/mobile/Documents/SevenUp-probe.log";
static NSString * const kSUPPrefsPath = @"/var/mobile/Library/Preferences/com.futur3sn0w.sevenup.plist";
static NSString * const kSUPPrefsChangedNotification = @"com.futur3sn0w.sevenup/prefs-changed";
static NSString * const kSUPDumpClassesNotification = @"com.futur3sn0w.sevenup/dump-classes";
static NSString * const kSUPDumpMethodsNotification = @"com.futur3sn0w.sevenup/dump-methods";

@interface SUPLogTextCell : PSTableCell
@property (nonatomic, strong) UITextView *textView;
@end

@implementation SUPLogTextCell

+ (CGFloat)preferredHeightForWidth:(CGFloat)width {
	#pragma unused(width)
	return 280.0;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
	if (!self) return nil;

	self.selectionStyle = UITableViewCellSelectionStyleNone;

	UITextView *textView = [[UITextView alloc] initWithFrame:CGRectZero];
	textView.translatesAutoresizingMaskIntoConstraints = NO;
	textView.editable = NO;
	textView.selectable = YES;
	textView.scrollEnabled = YES;
	textView.font = [UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightRegular];
	textView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
	textView.textColor = [UIColor labelColor];
	textView.layer.cornerRadius = 12.0;
	textView.textContainerInset = UIEdgeInsetsMake(12.0, 10.0, 12.0, 10.0);
	self.textView = textView;
	[self.contentView addSubview:textView];

	[NSLayoutConstraint activateConstraints:@[
		[textView.leadingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
		[textView.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],
		[textView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8.0],
		[textView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8.0]
	]];

	[self refreshCellContentsWithSpecifier:specifier];
	return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
	[super refreshCellContentsWithSpecifier:specifier];
	self.textView.text = [specifier propertyForKey:@"supLogText"] ?: @"";
}

@end

@interface SUPRootListController ()
@property (nonatomic, copy) NSString *cachedLogText;
@end

@implementation SUPRootListController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"SevenUp";
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self reloadLogAndUI];
}

#pragma mark - Prefs storage

- (id)readPreferenceValue:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kSUPPrefsPath] ?: @{};
	return prefs[key] ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	NSString *key = [specifier propertyForKey:@"key"];
	NSMutableDictionary *prefs = [[NSDictionary dictionaryWithContentsOfFile:kSUPPrefsPath] mutableCopy] ?: [NSMutableDictionary dictionary];
	prefs[key] = value;
	[prefs writeToFile:kSUPPrefsPath atomically:YES];
	[self postDarwinNotificationNamed:kSUPPrefsChangedNotification];
}

#pragma mark - Specifier helpers

- (PSSpecifier *)groupWithFooter:(NSString *)footer {
	PSSpecifier *specifier = [PSSpecifier emptyGroupSpecifier];
	if (footer.length > 0) {
		[specifier setProperty:footer forKey:@"footerText"];
	}
	return specifier;
}

- (PSSpecifier *)switchSpecifierWithName:(NSString *)name key:(NSString *)key defaultValue:(BOOL)defaultValue {
	PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:name
		target:self
		set:@selector(setPreferenceValue:specifier:)
		get:@selector(readPreferenceValue:)
		detail:Nil
		cell:PSSwitchCell
		edit:Nil];
	[specifier setProperty:key forKey:@"key"];
	[specifier setProperty:@(defaultValue) forKey:@"default"];
	return specifier;
}

- (PSSpecifier *)buttonSpecifierWithName:(NSString *)name action:(SEL)action {
	PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:name
		target:self
		set:NULL
		get:NULL
		detail:Nil
		cell:PSButtonCell
		edit:Nil];
	[specifier setButtonAction:action];
	[specifier setProperty:@YES forKey:@"isCentered"];
	return specifier;
}

- (PSSpecifier *)logSpecifier {
	PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:@"Debug Log"
		target:self
		set:NULL
		get:NULL
		detail:Nil
		cell:PSButtonCell
		edit:Nil];
	[specifier setProperty:SUPLogTextCell.class forKey:@"cellClass"];
	[specifier setProperty:self.cachedLogText ?: @"" forKey:@"supLogText"];
	return specifier;
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		NSMutableArray *specifiers = [NSMutableArray array];

		[specifiers addObject:[self groupWithFooter:@"The classic iOS 7/8 app switcher on iOS 16. Respring after toggling."]];
		[specifiers addObject:[self switchSpecifierWithName:@"Enabled" key:@"Enabled" defaultValue:YES]];

		[specifiers addObject:[self groupWithFooter:@"Probe tools write to /var/mobile/Documents/SevenUp-probe.log."]];
		[specifiers addObject:[self buttonSpecifierWithName:@"Dump Switcher Classes" action:@selector(dumpClassesTapped)]];
		[specifiers addObject:[self buttonSpecifierWithName:@"Dump Methods" action:@selector(dumpMethodsTapped)]];
		[specifiers addObject:[self buttonSpecifierWithName:@"Refresh Log" action:@selector(refreshLogTapped)]];
		[specifiers addObject:[self buttonSpecifierWithName:@"Copy Log" action:@selector(copyLogTapped)]];
		[specifiers addObject:[self buttonSpecifierWithName:@"Clear Log" action:@selector(clearLogTapped)]];

		[specifiers addObject:[self groupWithFooter:@"The live text box is trimmed to the most recent portion of the file so Preferences stays responsive."]];
		[specifiers addObject:[self logSpecifier]];

		_specifiers = [specifiers copy];
	}
	return _specifiers;
}

- (void)reloadSpecifiers {
	_specifiers = nil;
	[super reloadSpecifiers];
}

#pragma mark - Log handling

- (NSString *)trimmedLogTextFromString:(NSString *)text {
	if (text.length == 0) {
		return @"No log output yet.";
	}
	static NSUInteger const maxCharacters = 12000;
	if (text.length <= maxCharacters) {
		return text;
	}
	return [NSString stringWithFormat:@"... trimmed ...\n%@", [text substringFromIndex:text.length - maxCharacters]];
}

- (void)reloadLogAndUI {
	NSString *contents = [NSString stringWithContentsOfFile:kSUPLogPath encoding:NSUTF8StringEncoding error:nil];
	self.cachedLogText = [self trimmedLogTextFromString:contents];
	[self reloadSpecifiers];
	[self.table reloadData];
}

- (void)postDarwinNotificationNamed:(NSString *)name {
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
		(__bridge CFStringRef)name,
		NULL,
		NULL,
		true);
}

#pragma mark - Button actions

- (void)refreshLogTapped {
	[self reloadLogAndUI];
}

- (void)copyLogTapped {
	UIPasteboard.generalPasteboard.string = self.cachedLogText ?: @"";
}

- (void)clearLogTapped {
	[[NSFileManager defaultManager] removeItemAtPath:kSUPLogPath error:nil];
	self.cachedLogText = @"Log cleared.";
	[self reloadSpecifiers];
	[self.table reloadData];
}

- (void)dumpClassesTapped {
	[self postDarwinNotificationNamed:kSUPDumpClassesNotification];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self reloadLogAndUI];
	});
}

- (void)dumpMethodsTapped {
	[self postDarwinNotificationNamed:kSUPDumpMethodsNotification];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self reloadLogAndUI];
	});
}

@end
