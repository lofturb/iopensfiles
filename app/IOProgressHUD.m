#import "IOProgressHUD.h"
#import "IOTheme.h"

@interface IOProgressHUD ()
@property (nonatomic, strong) UIView *tarjeta;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *etiqueta;
@property (nonatomic, strong) UIProgressView *barra;
@property (nonatomic, strong) UIButton *botonCancelar;
@property (nonatomic, copy) void (^cancelHandler)(void);
@property (nonatomic, assign) BOOL visible;
@end

@implementation IOProgressHUD

+ (instancetype)shared {
    static IOProgressHUD *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IOProgressHUD alloc] initWithFrame:CGRectZero];
    });
    return instancia;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self construir];
    }
    return self;
}

- (void)construir {
    self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.25];

    self.tarjeta = [[UIView alloc] init];
    self.tarjeta.translatesAutoresizingMaskIntoConstraints = NO;
    self.tarjeta.layer.cornerRadius = 18.0;
    self.tarjeta.layer.shadowColor = [UIColor blackColor].CGColor;
    self.tarjeta.layer.shadowOpacity = 0.22;
    self.tarjeta.layer.shadowRadius = 24.0;
    self.tarjeta.layer.shadowOffset = CGSizeMake(0, 10);
    [self addSubview:self.tarjeta];

    self.spinner = [[UIActivityIndicatorView alloc]
                    initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.hidesWhenStopped = YES;
    [self.tarjeta addSubview:self.spinner];

    self.etiqueta = [[UILabel alloc] init];
    self.etiqueta.translatesAutoresizingMaskIntoConstraints = NO;
    self.etiqueta.numberOfLines = 2;
    self.etiqueta.textAlignment = NSTextAlignmentCenter;
    [self.tarjeta addSubview:self.etiqueta];

    self.barra = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.barra.translatesAutoresizingMaskIntoConstraints = NO;
    self.barra.hidden = YES;
    self.barra.progressTintColor = [IOTheme shared].accent;
    [self.tarjeta addSubview:self.barra];

    self.botonCancelar = [UIButton buttonWithType:UIButtonTypeSystem];
    self.botonCancelar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.botonCancelar setTitle:@"Cancelar" forState:UIControlStateNormal];
    [self.botonCancelar addTarget:self action:@selector(pulsarCancelar)
                 forControlEvents:UIControlEventTouchUpInside];
    [self.tarjeta addSubview:self.botonCancelar];

    [self.tarjeta addConstraint:[NSLayoutConstraint constraintWithItem:self.tarjeta
        attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual
        toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:260]];

    [self.tarjeta addConstraints:@[
        [NSLayoutConstraint constraintWithItem:self.spinner attribute:NSLayoutAttributeTop
            relatedBy:NSLayoutRelationEqual toItem:self.tarjeta
            attribute:NSLayoutAttributeTop multiplier:1 constant:26],
        [NSLayoutConstraint constraintWithItem:self.spinner attribute:NSLayoutAttributeCenterX
            relatedBy:NSLayoutRelationEqual toItem:self.tarjeta
            attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],

        [NSLayoutConstraint constraintWithItem:self.etiqueta attribute:NSLayoutAttributeTop
            relatedBy:NSLayoutRelationEqual toItem:self.spinner
            attribute:NSLayoutAttributeBottom multiplier:1 constant:14],
        [NSLayoutConstraint constraintWithItem:self.etiqueta attribute:NSLayoutAttributeLeading
            relatedBy:NSLayoutRelationEqual toItem:self.tarjeta
            attribute:NSLayoutAttributeLeading multiplier:1 constant:20],
        [NSLayoutConstraint constraintWithItem:self.etiqueta attribute:NSLayoutAttributeTrailing
            relatedBy:NSLayoutRelationEqual toItem:self.tarjeta
            attribute:NSLayoutAttributeTrailing multiplier:1 constant:-20],

        [NSLayoutConstraint constraintWithItem:self.barra attribute:NSLayoutAttributeTop
            relatedBy:NSLayoutRelationEqual toItem:self.etiqueta
            attribute:NSLayoutAttributeBottom multiplier:1 constant:14],
        [NSLayoutConstraint constraintWithItem:self.barra attribute:NSLayoutAttributeLeading
            relatedBy:NSLayoutRelationEqual toItem:self.tarjeta
            attribute:NSLayoutAttributeLeading multiplier:1 constant:20],
        [NSLayoutConstraint constraintWithItem:self.barra attribute:NSLayoutAttributeTrailing
            relatedBy:NSLayoutRelationEqual toItem:self.tarjeta
            attribute:NSLayoutAttributeTrailing multiplier:1 constant:-20],

        [NSLayoutConstraint constraintWithItem:self.botonCancelar attribute:NSLayoutAttributeTop
            relatedBy:NSLayoutRelationEqual toItem:self.barra
            attribute:NSLayoutAttributeBottom multiplier:1 constant:14],
        [NSLayoutConstraint constraintWithItem:self.botonCancelar attribute:NSLayoutAttributeCenterX
            relatedBy:NSLayoutRelationEqual toItem:self.tarjeta
            attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.botonCancelar attribute:NSLayoutAttributeBottom
            relatedBy:NSLayoutRelationEqual toItem:self.tarjeta
            attribute:NSLayoutAttributeBottom multiplier:1 constant:-20]
    ]];

    [self addConstraint:[NSLayoutConstraint constraintWithItem:self.tarjeta
        attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual
        toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:self.tarjeta
        attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual
        toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.tarjeta.backgroundColor = tema.cardBackground;
    self.etiqueta.textColor = tema.textPrimary;
    self.etiqueta.font = [tema fontBody];
    self.spinner.color = tema.textSecondary;
    self.botonCancelar.tintColor = tema.accent;
}

- (void)showInView:(UIView *)view message:(NSString *)message {
    if (!view) { return; }
    [self aplicarTema];

    self.frame = view.bounds;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.etiqueta.text = message ?: @"";
    self.barra.hidden = YES;
    self.barra.progress = 0.0;
    self.botonCancelar.hidden = YES;
    self.cancelHandler = nil;
    [self.spinner startAnimating];

    if (self.superview != view) {
        [self removeFromSuperview];
        [view addSubview:self];
    }
    [view bringSubviewToFront:self];
    self.visible = YES;
    if (self.alpha < 0.01) {
        self.alpha = 0.0;
        [UIView animateWithDuration:0.18 animations:^{ self.alpha = 1.0; }];
    } else {
        self.alpha = 1.0;
    }
}

- (void)updateMessage:(NSString *)message {
    self.etiqueta.text = message ?: @"";
}

- (void)updateProgress:(double)progress {
    if (progress < 0.0) {
        self.barra.hidden = YES;
        [self.spinner startAnimating];
    } else {
        self.barra.hidden = NO;
        [self.spinner stopAnimating];
        self.barra.progress = (float)progress;
    }
}

- (void)setCancelHandler:(void (^)(void))handler {
    _cancelHandler = [handler copy];
    self.botonCancelar.hidden = (_cancelHandler == nil);
}

- (void)pulsarCancelar {
    if (self.cancelHandler) { self.cancelHandler(); }
}

- (void)hide {
    if (!self.visible) {
        [self removeFromSuperview];
        return;
    }
    self.visible = NO;
    __weak IOProgressHUD *debil = self;
    [UIView animateWithDuration:0.18 animations:^{
        debil.alpha = 0.0;
    } completion:^(BOOL terminado) {
        [debil.spinner stopAnimating];
        [debil removeFromSuperview];
    }];
}

@end
