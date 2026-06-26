#import "SCCSectionHeaderView.h"

#import <QuartzCore/QuartzCore.h>

@interface SCCSectionHeaderView ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIView *dividerView;
@property (nonatomic, assign) BOOL collapsed;

@end

static UIColor *SCCBubbleForegroundColor(void) {
	if (@available(iOS 13.0, *)) {
		return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
			if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
				return [UIColor colorWithWhite:1.0 alpha:0.96];
			}

			return [UIColor colorWithWhite:0.20 alpha:0.92];
		}];
	}

	return [UIColor colorWithWhite:0.20 alpha:0.92];
}

static UIColor *SCCBubbleBackgroundColor(void) {
	if (@available(iOS 13.0, *)) {
		return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
			if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
				return [UIColor colorWithWhite:1.0 alpha:0.18];
			}

			return [UIColor colorWithWhite:0.0 alpha:0.08];
		}];
	}

	return [UIColor colorWithWhite:0.0 alpha:0.08];
}

static CGFloat SCCollapseButtonSlotWidth(CGFloat maxHeight) {
	UIButton *expandButton = [UIButton buttonWithType:UIButtonTypeSystem];
	UIButton *collapseButton = [UIButton buttonWithType:UIButtonTypeSystem];

	if (@available(iOS 15.0, *)) {
		UIButtonConfiguration *expandConfiguration = [UIButtonConfiguration plainButtonConfiguration];
		expandConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(5.0, 10.0, 5.0, 10.0);
		expandConfiguration.title = @"EXPAND";
		expandButton.configuration = expandConfiguration;

		UIButtonConfiguration *collapseConfiguration = [UIButtonConfiguration plainButtonConfiguration];
		collapseConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(5.0, 10.0, 5.0, 10.0);
		collapseConfiguration.title = @"COLLAPSE";
		collapseButton.configuration = collapseConfiguration;
	} else {
		[expandButton setTitle:@"EXPAND" forState:UIControlStateNormal];
		[collapseButton setTitle:@"COLLAPSE" forState:UIControlStateNormal];
	}

	CGSize expandSize = [expandButton sizeThatFits:CGSizeMake(CGFLOAT_MAX, maxHeight)];
	CGSize collapseSize = [collapseButton sizeThatFits:CGSizeMake(CGFLOAT_MAX, maxHeight)];
	return MAX(MAX(ceil(expandSize.width), 74.0), MAX(ceil(collapseSize.width), 74.0));
}

static UIColor *SCCDividerColor(void) {
	if (@available(iOS 13.0, *)) {
		return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
			if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
				return [UIColor colorWithWhite:1.0 alpha:0.16];
			}

			return [UIColor colorWithWhite:0.0 alpha:0.12];
		}];
	}

	return [UIColor colorWithWhite:0.0 alpha:0.12];
}

@implementation SCCSectionHeaderView

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithReuseIdentifier:reuseIdentifier];
	if (self == nil) {
		return nil;
	}

	self.contentView.backgroundColor = [UIColor clearColor];
	_leadingInset = 0.0;
	_trailingInset = 0.0;
	_bottomInset = 0.0;

	_titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
	_titleLabel.textColor = [UIColor secondaryLabelColor];
	_titleLabel.numberOfLines = 1;
	[self.contentView addSubview:_titleLabel];

	_toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
	_toggleButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
	[_toggleButton addTarget:self action:@selector(togglePressed) forControlEvents:UIControlEventTouchUpInside];
	[self.contentView addSubview:_toggleButton];

	_dividerView = [[UIView alloc] initWithFrame:CGRectZero];
	_dividerView.backgroundColor = SCCDividerColor();
	_dividerView.hidden = YES;
	[self.contentView addSubview:_dividerView];

	return self;
}

- (void)configureWithTitle:(NSString *)title collapsed:(BOOL)collapsed {
	self.collapsed = collapsed;
	self.titleLabel.text = title.length > 0 ? title : @"Section";
	self.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];

	NSString *buttonTitle = collapsed ? @"EXPAND" : @"COLLAPSE";
	UIImage *chevronImage = nil;
	if (@available(iOS 13.0, *)) {
		UIImageSymbolConfiguration *symbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:9.0 weight:UIImageSymbolWeightSemibold];
		chevronImage = [UIImage systemImageNamed:(collapsed ? @"chevron.right" : @"chevron.down") withConfiguration:symbolConfiguration];
	}

	if (@available(iOS 15.0, *)) {
		UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
		configuration.contentInsets = NSDirectionalEdgeInsetsMake(5.0, 10.0, 5.0, 10.0);
		configuration.baseForegroundColor = SCCBubbleForegroundColor();
		configuration.background.backgroundColor = SCCBubbleBackgroundColor();
		configuration.background.cornerRadius = 11.0;
		configuration.image = chevronImage;
		configuration.imagePlacement = NSDirectionalRectEdgeTrailing;
		configuration.imagePadding = 5.0;
		configuration.title = buttonTitle;
		configuration.attributedTitle = [[NSAttributedString alloc] initWithString:buttonTitle attributes:@{
			NSFontAttributeName: [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold],
			NSKernAttributeName: @0.5
		}];
		self.toggleButton.configuration = configuration;
	} else {
		[self.toggleButton setTitle:buttonTitle forState:UIControlStateNormal];
		[self.toggleButton setTitleColor:SCCBubbleForegroundColor() forState:UIControlStateNormal];
		self.toggleButton.titleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
		self.toggleButton.backgroundColor = SCCBubbleBackgroundColor();
		self.toggleButton.layer.cornerRadius = 11.0;
	}

	self.dividerView.hidden = !collapsed;
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGRect bounds = self.contentView.bounds;
	CGFloat leadingMargin = self.leadingInset;
	CGFloat trailingMargin = self.trailingInset;
	CGFloat spacing = 12.0;
	CGSize buttonSize = [self.toggleButton sizeThatFits:CGSizeMake(CGFLOAT_MAX, bounds.size.height)];
	buttonSize.width = MAX(ceil(buttonSize.width), 74.0);
	buttonSize.height = MIN(MAX(ceil(buttonSize.height), 24.0), bounds.size.height);

	CGFloat buttonSlotWidth = SCCollapseButtonSlotWidth(bounds.size.height);
	CGFloat buttonSlotX = CGRectGetMaxX(bounds) - trailingMargin - buttonSlotWidth;
	CGFloat buttonX = buttonSlotX + floor((buttonSlotWidth - buttonSize.width) * 0.5);
	CGFloat buttonY = floor(bounds.size.height - self.bottomInset - buttonSize.height);
	buttonY = MAX(0.0, buttonY);
	self.toggleButton.frame = CGRectMake(buttonX, buttonY, buttonSize.width, buttonSize.height);

	CGFloat labelWidth = MAX(0.0, buttonX - spacing - leadingMargin);
	self.titleLabel.frame = CGRectMake(leadingMargin, 0.0, labelWidth, bounds.size.height);

	CGFloat dividerHeight = 1.0 / MAX(UIScreen.mainScreen.scale, 1.0);
	CGFloat dividerX = leadingMargin;
	CGFloat dividerWidth = MAX(0.0, bounds.size.width - leadingMargin - trailingMargin);
	CGFloat dividerY = MAX(0.0, bounds.size.height - dividerHeight);
	self.dividerView.frame = CGRectMake(dividerX, dividerY, dividerWidth, dividerHeight);
	self.dividerView.hidden = !self.collapsed;
}

- (void)togglePressed {
	id<SCCSectionHeaderViewDelegate> delegate = self.delegate;
	if (delegate != nil && [delegate respondsToSelector:@selector(sccHeaderTappedForSection:)]) {
		[delegate sccHeaderTappedForSection:self.section];
	}
}

@end
