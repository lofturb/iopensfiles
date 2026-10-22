#import <UIKit/UIKit.h>

// Se emite cada vez que cambia el tema (claro <-> oscuro) o al arrancar.
extern NSString * const IOThemeDidChangeNotification;

// Sistema de diseno de IOpenFiles: colores, tipografia y medidas.
// Todo el aspecto de la app sale de aqui, asi que cambiar de tema es cambiar
// una sola bandera.
@interface IOTheme : NSObject

+ (instancetype)shared;

// Cambia el tema en toda la app y avisa por notificacion.
+ (void)applyDark:(BOOL)dark;

@property (nonatomic, assign) BOOL dark;

// --- Colores ---
@property (nonatomic, readonly) UIColor *background;
@property (nonatomic, readonly) UIColor *cardBackground;
@property (nonatomic, readonly) UIColor *elevatedBackground;
@property (nonatomic, readonly) UIColor *sidebarBackground;
@property (nonatomic, readonly) UIColor *textPrimary;
@property (nonatomic, readonly) UIColor *textSecondary;
@property (nonatomic, readonly) UIColor *textTertiary;
@property (nonatomic, readonly) UIColor *separator;
@property (nonatomic, readonly) UIColor *accent;
@property (nonatomic, readonly) UIColor *accentSoft;
@property (nonatomic, readonly) UIColor *danger;
@property (nonatomic, readonly) UIColor *success;
@property (nonatomic, readonly) UIColor *warning;
@property (nonatomic, readonly) UIColor *controlFill;
@property (nonatomic, readonly) UIColor *selectionFill;

// --- Medidas ---
@property (nonatomic, readonly) CGFloat cornerRadius;
@property (nonatomic, readonly) CGFloat largeCornerRadius;
@property (nonatomic, readonly) CGFloat rowHeight;
@property (nonatomic, readonly) CGFloat gutter;
@property (nonatomic, readonly) CGFloat sidebarWidth;

// --- Tipografia ---
- (UIFont *)fontNavTitle;
- (UIFont *)fontTitle;
- (UIFont *)fontHeadline;
- (UIFont *)fontBody;
- (UIFont *)fontSubhead;
- (UIFont *)fontCaption;
- (UIFont *)fontMono:(CGFloat)size;

// Utilidad: color desde 0xRRGGBB.
+ (UIColor *)colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha;

@end
