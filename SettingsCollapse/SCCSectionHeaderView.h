#import <UIKit/UIKit.h>

@protocol SCCSectionHeaderViewDelegate <NSObject>

- (void)sccHeaderTappedForSection:(NSInteger)section;

@end

@interface SCCSectionHeaderView : UITableViewHeaderFooterView

@property (nonatomic, weak) id<SCCSectionHeaderViewDelegate> delegate;
@property (nonatomic, assign) NSInteger section;
@property (nonatomic, assign) CGFloat leadingInset;
@property (nonatomic, assign) CGFloat trailingInset;
@property (nonatomic, assign) CGFloat bottomInset;

- (void)configureWithTitle:(NSString *)title collapsed:(BOOL)collapsed;

@end
