#import <UIKit/UIKit.h>

// Analiza una carpeta, agrupa los archivos por tipo con su peso y permite
// seleccionar y borrar solo lo que el usuario marque. Nunca borra solo.
@interface IOAnalyzerViewController : UIViewController

@property (nonatomic, copy) NSString *path;

- (instancetype)initWithPath:(NSString *)path;

@end
