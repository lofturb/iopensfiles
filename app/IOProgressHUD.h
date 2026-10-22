#import <UIKit/UIKit.h>

// Tarjeta flotante de progreso: spinner o barra + mensaje + boton Cancelar.
@interface IOProgressHUD : UIView

+ (instancetype)shared;

- (void)showInView:(UIView *)view message:(NSString *)message;
- (void)updateMessage:(NSString *)message;
- (void)updateProgress:(double)progress;      // < 0 => indeterminado
- (void)setCancelHandler:(void (^)(void))handler;
- (void)hide;

@end
