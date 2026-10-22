#import <UIKit/UIKit.h>

// Navegador de una carpeta. Se apilan instancias al entrar en subcarpetas.
@interface IOFilesViewController : UIViewController

@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) BOOL showsSidebarToggle;
@property (nonatomic, copy) void (^onSidebarToggle)(void);

// Modo selector: solo deja elegir archivos con estas extensiones.
@property (nonatomic, assign) BOOL pickerMode;
@property (nonatomic, copy) NSArray<NSString *> *pickerExtensions;
@property (nonatomic, copy) void (^onPick)(NSString *path);

- (instancetype)initWithPath:(NSString *)path;
- (void)reloadContents;

@end
