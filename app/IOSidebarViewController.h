#import <UIKit/UIKit.h>

@class IOSidebarViewController;

@protocol IOSidebarDelegate <NSObject>
- (void)sidebar:(IOSidebarViewController *)sidebar didSelectPath:(NSString *)path;

@optional
// Entrada "Inicio": vuelve a la pantalla principal de la app.
- (void)sidebarDidSelectHome:(IOSidebarViewController *)sidebar;
@end

// Panel lateral: Lugares, Favoritos y Recientes.
@interface IOSidebarViewController : UIViewController

@property (nonatomic, weak) id<IOSidebarDelegate> delegate;
@property (nonatomic, copy) NSString *selectedPath;

- (void)reloadData;

@end
