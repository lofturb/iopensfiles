#import <UIKit/UIKit.h>

// Visor de imagenes a pantalla completa, con zoom y paso entre las imagenes de
// la carpeta.
@interface IOImageViewController : UIViewController

- (instancetype)initWithPaths:(NSArray<NSString *> *)paths startIndex:(NSInteger)index;

@end
