#import <UIKit/UIKit.h>

@class IOSidebarViewController;

@protocol IOSidebarDelegate <NSObject>
- (void)sidebar:(IOSidebarViewController *)sidebar didSelectPath:(NSString *)path;
@end

// Panel lateral: Lugares, Favoritos y Recientes.
@interface IOSidebarViewController : UIViewController

@property (nonatomic, weak) id<IOSidebarDelegate> delegate;
@property (nonatomic, copy) NSString *selectedPath;

- (void)reloadData;

@end
