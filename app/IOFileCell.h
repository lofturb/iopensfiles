#import <UIKit/UIKit.h>
#import "IOFileItem.h"

// Fila de la lista de archivos: icono + nombre + tipo + tamano.
@interface IOFileCell : UITableViewCell

@property (nonatomic, strong) UIImageView *iconoVista;
@property (nonatomic, strong) UILabel *titulo;
@property (nonatomic, strong) UILabel *subtitulo;
@property (nonatomic, strong) UILabel *detalle;
@property (nonatomic, strong) UIImageView *chevron;

- (void)configurarConItem:(IOFileItem *)item;
- (void)aplicarTema;

@end
