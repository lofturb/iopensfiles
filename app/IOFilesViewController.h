#import <UIKit/UIKit.h>

// Navegador de una carpeta. Se apilan instancias al entrar en subcarpetas.
@interface IOFilesViewController : UIViewController

@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) BOOL showsSidebarToggle;
@property (nonatomic, copy) void (^onSidebarToggle)(void);

- (instancetype)initWithPath:(NSString *)path;
- (void)reloadContents;

@end
