#import "IODialog.h"
#import "IOTheme.h"

@implementation IODialogAction
+ (instancetype)actionWithTitle:(NSString *)title
                          style:(IODialogActionStyle)style
                        handler:(void (^)(void))handler {
    IODialogAction *accion = [[IODialogAction alloc] init];
    accion.title = title;
    accion.style = style;
    accion.enabled = YES;
    accion.handler = handler;
    return accion;
}
@end

#pragma mark - Boton

@interface IODialogButton : UIButton
@end

@implementation IODialogButton
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor = highlighted ? [[IOTheme shared] controlFill]
                                       : [UIColor clearColor];
}
@end

#pragma mark - Dialogo

@interface IODialog () <UITextFieldDelegate>
@property (nonatomic, strong) UIControl *fondo;
@property (nonatomic, strong) UIView *tarjeta;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UILabel *titulo;
@property (nonatomic, strong) UILabel *mensaje;
@property (nonatomic, strong) NSMutableArray<UITextField *> *campos;
@property (nonatomic, strong) NSMutableArray<IODialogAction *> *acciones;
@property (nonatomic, strong) NSMutableArray<IODialogButton *> *botones;
@property (nonatomic, strong) NSMutableArray<UIView *> *separadores;
@property (nonatomic, assign) BOOL cerrando;
@property (nonatomic, assign) BOOL presentado;
- (void)agregarAccionObjeto:(IODialogAction *)accion;
@end

@implementation IODialog

+ (instancetype)alertWithTitle:(NSString *)title message:(NSString *)message {
    IODialog *d = [[IODialog alloc] init];
    // Forzar la vista antes de escribir en las etiquetas: si no, titulo y
    // mensaje se asignan a nil y el dialogo sale vacio.
    (void)d.view;
    d.style = IODialogStyleAlert;
    d.titulo.text = title;
    d.mensaje.text = message;
    return d;
}

+ (instancetype)sheetWithTitle:(NSString *)title message:(NSString *)message {
    IODialog *d = [[IODialog alloc] init];
    (void)d.view;
    d.style = IODialogStyleSheet;
    d.titulo.text = title;
    d.mensaje.text = message;
    return d;
}

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _style = IODialogStyleAlert;
        _campos = [NSMutableArray array];
        _acciones = [NSMutableArray array];
        _botones = [NSMutableArray array];
        _separadores = [NSMutableArray array];
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.accessibilityViewIsModal = YES;

    self.fondo = [[UIControl alloc] initWithFrame:self.view.bounds];
    self.fondo.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.fondo addTarget:self action:@selector(tocarFondo)
         forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.fondo];

    self.tarjeta = [[UIView alloc] initWithFrame:CGRectZero];
    self.tarjeta.layer.cornerRadius = 18.0;
    self.tarjeta.layer.masksToBounds = YES;
    self.tarjeta.layer.borderWidth = 0.5;
    [self.view addSubview:self.tarjeta];

    self.scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scroll.alwaysBounceVertical = NO;
    self.scroll.showsVerticalScrollIndicator = YES;
    [self.tarjeta addSubview:self.scroll];

    self.titulo = [[UILabel alloc] init];
    self.titulo.numberOfLines = 0;
    self.titulo.textAlignment = NSTextAlignmentCenter;
    [self.scroll addSubview:self.titulo];

    self.mensaje = [[UILabel alloc] init];
    self.mensaje.numberOfLines = 0;
    self.mensaje.textAlignment = NSTextAlignmentCenter;
    [self.scroll addSubview:self.mensaje];

    [self aplicarTema];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(tecladoCambia:)
            name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(tecladoOculta:)
            name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray<UITextField *> *)textFields {
    return [self.campos copy];
}

- (NSArray<IODialogAction *> *)actions {
    return [self.acciones copy];
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.fondo.backgroundColor = tema.overlay;
    self.tarjeta.backgroundColor = tema.elevatedBackground;
    self.tarjeta.layer.borderColor = tema.separatorStrong.CGColor;

    self.titulo.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    self.titulo.textColor = tema.textPrimary;
    self.mensaje.font = [tema fontSubhead];
    self.mensaje.textColor = tema.textSecondary;

    for (UITextField *campo in self.campos) {
        campo.backgroundColor = tema.fieldBackground;
        campo.textColor = tema.textPrimary;
        campo.tintColor = tema.accent;
        campo.keyboardAppearance = tema.dark ? UIKeyboardAppearanceDark
                                             : UIKeyboardAppearanceLight;
        campo.attributedPlaceholder = [[NSAttributedString alloc]
            initWithString:campo.placeholder ?: @""
                attributes:@{ NSForegroundColorAttributeName: tema.textTertiary }];
    }

    for (UIView *linea in self.separadores) {
        linea.backgroundColor = tema.separator;
    }

    for (NSUInteger i = 0; i < self.botones.count; i++) {
        IODialogButton *boton = self.botones[i];
        IODialogAction *accion = self.acciones[i];
        UIColor *color = tema.textPrimary;
        UIFont *fuente = [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
        if (accion.style == IODialogActionStyleDestructive) { color = tema.danger; }
        if (accion.style == IODialogActionStyleSelected) {
            color = tema.accent;
            fuente = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
        }
        if (accion.style == IODialogActionStyleCancel) {
            color = tema.accent;
            fuente = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
        }
        if (!accion.enabled) { color = tema.textTertiary; }
        [boton setTitle:accion.title forState:UIControlStateNormal];
        [boton setTitleColor:color forState:UIControlStateNormal];
        [boton setTitleColor:color forState:UIControlStateDisabled];
        [boton setTitleColor:color forState:UIControlStateHighlighted];
        boton.titleLabel.font = fuente;
        boton.enabled = accion.enabled;
    }

    [self.view setNeedsLayout];
}

#pragma mark - Construccion

- (IODialogAction *)addAction:(NSString *)title
                        style:(IODialogActionStyle)style
                      handler:(void (^)(void))handler {
    IODialogAction *accion = [IODialogAction actionWithTitle:title style:style handler:handler];
    [self agregarAccionObjeto:accion];
    return accion;
}

- (void)agregarAccionObjeto:(IODialogAction *)accion {
    NSUInteger indice = self.acciones.count;
    [self.acciones addObject:accion];

    UIView *linea = [[UIView alloc] init];
    [self.scroll addSubview:linea];
    [self.separadores addObject:linea];

    IODialogButton *boton = [IODialogButton buttonWithType:UIButtonTypeCustom];
    boton.tag = (NSInteger)indice;
    boton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    boton.contentEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 20);
    [boton addTarget:self action:@selector(pulsarBoton:)
    forControlEvents:UIControlEventTouchUpInside];
    [self.scroll addSubview:boton];
    [self.botones addObject:boton];

    [self aplicarTema];
}

- (UITextField *)addTextFieldWithPlaceholder:(NSString *)placeholder text:(NSString *)text {
    UITextField *campo = [[UITextField alloc] init];
    campo.borderStyle = UITextBorderStyleNone;
    campo.layer.cornerRadius = 10.0;
    campo.layer.masksToBounds = YES;
    campo.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 42)];
    campo.leftViewMode = UITextFieldViewModeAlways;
    campo.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 42)];
    campo.rightViewMode = UITextFieldViewModeAlways;
    campo.clearButtonMode = UITextFieldViewModeWhileEditing;
    campo.returnKeyType = UIReturnKeyDone;
    campo.autocorrectionType = UITextAutocorrectionTypeNo;
    campo.autocapitalizationType = UITextAutocapitalizationTypeNone;
    campo.font = [[IOTheme shared] fontBody];
    campo.placeholder = placeholder;
    campo.text = text;
    campo.delegate = self;
    [self.scroll addSubview:campo];
    [self.campos addObject:campo];
    [self aplicarTema];
    return campo;
}

#pragma mark - Disposicion

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGRect limites = self.view.bounds;
    CGFloat anchoMaximo = (self.style == IODialogStyleAlert) ? 380.0 : 560.0;
    CGFloat margen = (self.style == IODialogStyleAlert) ? 56.0 : 24.0;
    CGFloat ancho = MIN(anchoMaximo, CGRectGetWidth(limites) - margen);
    CGFloat pad = 20.0;
    CGFloat anchoTexto = ancho - pad * 2.0;
    CGFloat y = 0.0;

    BOOL hayTexto = (self.titulo.text.length > 0 || self.mensaje.text.length > 0);
    y = hayTexto ? 20.0 : 6.0;

    if (self.titulo.text.length > 0) {
        CGSize tam = [self.titulo sizeThatFits:CGSizeMake(anchoTexto, CGFLOAT_MAX)];
        self.titulo.frame = CGRectMake(pad, y, anchoTexto, tam.height);
        y = CGRectGetMaxY(self.titulo.frame) + 6.0;
    } else {
        self.titulo.frame = CGRectZero;
    }

    if (self.mensaje.text.length > 0) {
        CGSize tam = [self.mensaje sizeThatFits:CGSizeMake(anchoTexto, CGFLOAT_MAX)];
        self.mensaje.frame = CGRectMake(pad, y, anchoTexto, tam.height);
        y = CGRectGetMaxY(self.mensaje.frame) + 10.0;
    } else {
        self.mensaje.frame = CGRectZero;
    }

    for (UITextField *campo in self.campos) {
        campo.frame = CGRectMake(pad, y, anchoTexto, 42.0);
        y += 42.0 + 10.0;
    }
    if (self.campos.count > 0) { y += 4.0; }

    for (NSUInteger i = 0; i < self.acciones.count; i++) {
        UIView *linea = self.separadores[i];
        IODialogButton *boton = self.botones[i];
        linea.frame = CGRectMake(0, y, ancho, 0.5);
        y += 0.5;
        boton.frame = CGRectMake(0, y, ancho, 52.0);
        y += 52.0;
    }

    if (self.acciones.count == 0) { y += 10.0; }
    if (self.style == IODialogStyleSheet) { y += 8.0; }

    self.scroll.contentSize = CGSizeMake(ancho, y);

    CGFloat altoMaximo = CGRectGetHeight(limites) * 0.85;
    CGFloat alto = MIN(y, altoMaximo);

    CGFloat x = (CGRectGetWidth(limites) - ancho) / 2.0;
    CGFloat yTarjeta;
    if (self.style == IODialogStyleSheet) {
        yTarjeta = CGRectGetHeight(limites) - alto - 12.0;
    } else {
        yTarjeta = (CGRectGetHeight(limites) - alto) / 2.0;
    }
    self.tarjeta.frame = CGRectMake(x, yTarjeta, ancho, alto);
    self.scroll.frame = self.tarjeta.bounds;
}

#pragma mark - Presentacion

- (void)presentIn:(UIViewController *)viewController {
    if (!viewController || self.presentado) { return; }
    self.presentado = YES;

    __weak IODialog *debil = self;
    [viewController presentViewController:self animated:NO completion:^{
        IODialog *fuerte = debil;
        if (!fuerte) { return; }
        fuerte.view.alpha = 0.0;
        if (fuerte.style == IODialogStyleSheet) {
            fuerte.tarjeta.transform = CGAffineTransformMakeTranslation(0, 60);
        } else {
            fuerte.tarjeta.transform = CGAffineTransformMakeScale(1.06, 1.06);
        }
        [UIView animateWithDuration:0.22 delay:0
             options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            fuerte.view.alpha = 1.0;
            fuerte.tarjeta.transform = CGAffineTransformIdentity;
        } completion:nil];

        if (fuerte.campos.count > 0) {
            [fuerte.campos.firstObject becomeFirstResponder];
        }
    }];
}

- (void)pulsarBoton:(IODialogButton *)boton {
    NSInteger indice = boton.tag;
    if (indice < 0 || indice >= (NSInteger)self.acciones.count) { return; }
    [self cerrarConAccion:self.acciones[indice]];
}

- (void)tocarFondo {
    for (IODialogAction *accion in self.acciones) {
        if (accion.style == IODialogActionStyleCancel) {
            [self cerrarConAccion:accion];
            return;
        }
    }
}

- (void)cerrarConAccion:(IODialogAction *)accion {
    if (self.cerrando) { return; }
    self.cerrando = YES;
    [self.view endEditing:YES];
    void (^manejador)(void) = accion.handler;

    __weak IODialog *debil = self;
    [UIView animateWithDuration:0.16 animations:^{
        debil.view.alpha = 0.0;
        debil.tarjeta.transform = CGAffineTransformMakeScale(0.97, 0.97);
    } completion:^(BOOL terminado) {
        IODialog *fuerte = debil;
        if (!fuerte) {
            if (manejador) { manejador(); }
            return;
        }
        [fuerte dismissViewControllerAnimated:NO completion:^{
            if (manejador) { manejador(); }
        }];
    }];
}

#pragma mark - Teclado

- (void)tecladoCambia:(NSNotification *)notificacion {
    CGRect marco = [notificacion.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect enVista = [self.view convertRect:marco fromView:nil];
    CGFloat solape = CGRectGetMaxY(self.tarjeta.frame) - CGRectGetMinY(enVista) + 16.0;
    solape = MAX(0.0, solape);
    [UIView animateWithDuration:0.2 animations:^{
        self.tarjeta.transform = CGAffineTransformMakeTranslation(0, -solape);
    }];
}

- (void)tecladoOculta:(NSNotification *)notificacion {
    [UIView animateWithDuration:0.2 animations:^{
        self.tarjeta.transform = CGAffineTransformIdentity;
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    for (IODialogAction *accion in self.acciones) {
        if (accion.style != IODialogActionStyleCancel && accion.enabled) {
            [self cerrarConAccion:accion];
            return YES;
        }
    }
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Atajos

+ (void)showAlertIn:(UIViewController *)vc title:(NSString *)title message:(NSString *)message {
    IODialog *d = [IODialog alertWithTitle:title message:message];
    [d addAction:@"Entendido" style:IODialogActionStyleCancel handler:nil];
    [d presentIn:vc];
}

+ (void)showErrorIn:(UIViewController *)vc error:(NSError *)error {
    NSString *texto = error.localizedDescription ?: @"No se pudo completar la operacion.";
    [IODialog showAlertIn:vc title:@"Ha ocurrido un problema" message:texto];
}

+ (void)showConfirmIn:(UIViewController *)vc
                title:(NSString *)title
              message:(NSString *)message
          destructive:(BOOL)destructive
         confirmTitle:(NSString *)confirmTitle
              handler:(void (^)(void))handler {
    IODialog *d = [IODialog alertWithTitle:title message:message];
    [d addAction:@"Cancelar" style:IODialogActionStyleCancel handler:nil];
    [d addAction:confirmTitle
           style:(destructive ? IODialogActionStyleDestructive : IODialogActionStyleDefault)
         handler:handler];
    [d presentIn:vc];
}

+ (void)showSheetIn:(UIViewController *)vc
              title:(NSString *)title
            actions:(NSArray<IODialogAction *> *)actions {
    IODialog *d = [IODialog sheetWithTitle:title message:nil];
    BOOL hayCancelar = NO;
    for (IODialogAction *accion in actions) {
        [d agregarAccionObjeto:accion];
        if (accion.style == IODialogActionStyleCancel) { hayCancelar = YES; }
    }
    if (!hayCancelar) {
        [d addAction:@"Cancelar" style:IODialogActionStyleCancel handler:nil];
    }
    [d presentIn:vc];
}

@end
