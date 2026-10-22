#import <UIKit/UIKit.h>

// Pantalla de inicio: tarjetas de almacenamiento (una por volumen) y accesos
// rapidos a limpieza, instalador de IPA, papelera, favoritos y recientes.
@interface IOHomeViewController : UIViewController

@property (nonatomic, assign) BOOL showsSidebarToggle;
@property (nonatomic, copy) void (^onSidebarToggle)(void);

- (void)reloadData;

@end
