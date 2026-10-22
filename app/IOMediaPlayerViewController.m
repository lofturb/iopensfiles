#import "IOMediaPlayerViewController.h"

#import "IOTheme.h"
#import "IOHelpers.h"
#import "IOFileSystem.h"
#import "IOFileItem.h"
#import "IOFileIcons.h"
#import "IODialog.h"

#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <stdlib.h>

#pragma mark - Glifos del reproductor

typedef NS_ENUM(NSInteger, IOPlayerGlyph) {
    IOPlayerGlyphPlay = 0,
    IOPlayerGlyphPause,
    IOPlayerGlyphPrev,
    IOPlayerGlyphNext,
    IOPlayerGlyphShuffle,
    IOPlayerGlyphRepeat,
    IOPlayerGlyphRepeatOne,
    IOPlayerGlyphList
};

static UIImage *IOPlayerImage(IOPlayerGlyph glifo, CGFloat lado, UIColor *color) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(lado, lado), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, color.CGColor);
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGFloat s = lado;

    switch (glifo) {
        case IOPlayerGlyphPlay: {
            CGContextMoveToPoint(ctx, s * 0.32, s * 0.20);
            CGContextAddLineToPoint(ctx, s * 0.32, s * 0.80);
            CGContextAddLineToPoint(ctx, s * 0.80, s * 0.50);
            CGContextClosePath(ctx);
            CGContextFillPath(ctx);
            break;
        }
        case IOPlayerGlyphPause: {
            CGContextFillRect(ctx, CGRectMake(s * 0.29, s * 0.22, s * 0.15, s * 0.56));
            CGContextFillRect(ctx, CGRectMake(s * 0.56, s * 0.22, s * 0.15, s * 0.56));
            break;
        }
        case IOPlayerGlyphPrev: {
            CGContextFillRect(ctx, CGRectMake(s * 0.24, s * 0.22, s * 0.09, s * 0.56));
            CGContextMoveToPoint(ctx, s * 0.76, s * 0.22);
            CGContextAddLineToPoint(ctx, s * 0.76, s * 0.78);
            CGContextAddLineToPoint(ctx, s * 0.36, s * 0.50);
            CGContextClosePath(ctx);
            CGContextFillPath(ctx);
            break;
        }
        case IOPlayerGlyphNext: {
            CGContextFillRect(ctx, CGRectMake(s * 0.67, s * 0.22, s * 0.09, s * 0.56));
            CGContextMoveToPoint(ctx, s * 0.24, s * 0.22);
            CGContextAddLineToPoint(ctx, s * 0.24, s * 0.78);
            CGContextAddLineToPoint(ctx, s * 0.64, s * 0.50);
            CGContextClosePath(ctx);
            CGContextFillPath(ctx);
            break;
        }
        case IOPlayerGlyphShuffle: {
            CGContextMoveToPoint(ctx, s * 0.16, s * 0.72);
            CGContextAddLineToPoint(ctx, s * 0.34, s * 0.72);
            CGContextAddLineToPoint(ctx, s * 0.66, s * 0.28);
            CGContextAddLineToPoint(ctx, s * 0.82, s * 0.28);
            CGContextStrokePath(ctx);
            CGContextMoveToPoint(ctx, s * 0.16, s * 0.28);
            CGContextAddLineToPoint(ctx, s * 0.34, s * 0.28);
            CGContextAddLineToPoint(ctx, s * 0.66, s * 0.72);
            CGContextAddLineToPoint(ctx, s * 0.82, s * 0.72);
            CGContextStrokePath(ctx);
            CGContextMoveToPoint(ctx, s * 0.72, s * 0.18);
            CGContextAddLineToPoint(ctx, s * 0.84, s * 0.28);
            CGContextAddLineToPoint(ctx, s * 0.72, s * 0.38);
            CGContextStrokePath(ctx);
            CGContextMoveToPoint(ctx, s * 0.72, s * 0.62);
            CGContextAddLineToPoint(ctx, s * 0.84, s * 0.72);
            CGContextAddLineToPoint(ctx, s * 0.72, s * 0.82);
            CGContextStrokePath(ctx);
            break;
        }
        case IOPlayerGlyphRepeat:
        case IOPlayerGlyphRepeatOne: {
            CGContextMoveToPoint(ctx, s * 0.22, s * 0.34);
            CGContextAddLineToPoint(ctx, s * 0.22, s * 0.28);
            CGContextAddLineToPoint(ctx, s * 0.78, s * 0.28);
            CGContextAddLineToPoint(ctx, s * 0.78, s * 0.40);
            CGContextStrokePath(ctx);
            CGContextMoveToPoint(ctx, s * 0.66, s * 0.18);
            CGContextAddLineToPoint(ctx, s * 0.80, s * 0.30);
            CGContextAddLineToPoint(ctx, s * 0.66, s * 0.42);
            CGContextStrokePath(ctx);
            CGContextMoveToPoint(ctx, s * 0.78, s * 0.66);
            CGContextAddLineToPoint(ctx, s * 0.78, s * 0.72);
            CGContextAddLineToPoint(ctx, s * 0.22, s * 0.72);
            CGContextAddLineToPoint(ctx, s * 0.22, s * 0.60);
            CGContextStrokePath(ctx);
            CGContextMoveToPoint(ctx, s * 0.34, s * 0.58);
            CGContextAddLineToPoint(ctx, s * 0.20, s * 0.70);
            CGContextAddLineToPoint(ctx, s * 0.34, s * 0.82);
            CGContextStrokePath(ctx);
            if (glifo == IOPlayerGlyphRepeatOne) {
                NSDictionary *atributos = @{
                    NSForegroundColorAttributeName: color,
                    NSFontAttributeName: [UIFont systemFontOfSize:s * 0.30
                                                            weight:UIFontWeightBold]
                };
                [@"1" drawAtPoint:CGPointMake(s * 0.44, s * 0.38) withAttributes:atributos];
            }
            break;
        }
        case IOPlayerGlyphList: {
            for (int i = 0; i < 3; i++) {
                CGFloat y = s * (0.26 + i * 0.24);
                CGContextFillEllipseInRect(ctx, CGRectMake(s * 0.18, y - s * 0.035,
                                                           s * 0.07, s * 0.07));
                CGContextMoveToPoint(ctx, s * 0.36, y);
                CGContextAddLineToPoint(ctx, s * 0.84, y);
                CGContextStrokePath(ctx);
            }
            break;
        }
    }

    UIImage *imagen = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [imagen imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

#pragma mark - Reproductor

static void *IOPlayerStatusContext = &IOPlayerStatusContext;

@interface IOMediaPlayerViewController ()
@property (nonatomic, strong) NSArray<NSString *> *rutas;
@property (nonatomic, assign) NSInteger indice;

@property (nonatomic, strong) AVPlayer *reproductor;
@property (nonatomic, strong) AVPlayerItem *itemActual;
@property (nonatomic, strong) AVPlayerLayer *capa;

@property (nonatomic, strong) UIView *contenedorVideo;
@property (nonatomic, strong) UIImageView *fondo;
@property (nonatomic, strong) UIView *velo;
@property (nonatomic, strong) UIImageView *caratula;
@property (nonatomic, strong) UIActivityIndicatorView *cargando;

@property (nonatomic, strong) UIView *barraSuperior;
@property (nonatomic, strong) UIView *panel;
@property (nonatomic, strong) UILabel *titulo;
@property (nonatomic, strong) UILabel *subtitulo;
@property (nonatomic, strong) UILabel *tiempoActual;
@property (nonatomic, strong) UILabel *tiempoTotal;
@property (nonatomic, strong) UISlider *deslizador;

@property (nonatomic, strong) UIButton *botonCerrar;
@property (nonatomic, strong) UIButton *botonPlay;
@property (nonatomic, strong) UIButton *botonAnterior;
@property (nonatomic, strong) UIButton *botonSiguiente;
@property (nonatomic, strong) UIButton *botonAleatorio;
@property (nonatomic, strong) UIButton *botonRepetir;
@property (nonatomic, strong) UIButton *botonLista;
@property (nonatomic, strong) UIButton *botonVelocidad;

@property (nonatomic, assign) BOOL aleatorio;
@property (nonatomic, assign) NSInteger modoRepeticion;
@property (nonatomic, assign) CGFloat velocidad;
@property (nonatomic, assign) BOOL arrastrando;
@property (nonatomic, assign) BOOL controlesVisibles;
@property (nonatomic, assign) BOOL eraReproduciendo;
@property (nonatomic, assign) BOOL esVideo;
@property (nonatomic, assign) BOOL errorMostrado;

@property (nonatomic, strong) id observadorTiempo;
@property (nonatomic, assign) BOOL barraNavOcultaAntes;
@property (nonatomic, assign) BOOL ultimoEstadoReproduciendo;

@end

@implementation IOMediaPlayerViewController

- (instancetype)initWithPath:(NSString *)path {
    NSArray *lista = @[ path ];
    NSInteger indice = 0;
    NSString *carpeta = [path stringByDeletingLastPathComponent];
    NSArray *items = [[IOFileSystem shared] contentsOfDirectory:carpeta error:NULL];
    NSMutableArray *medios = [NSMutableArray array];
    for (IOFileItem *item in items) {
        if (item.isDirectory) { continue; }
        if (!([IOHelpers isVideoFile:item.path] || [IOHelpers isAudioFile:item.path])) {
            continue;
        }
        [medios addObject:item.path];
    }
    if (medios.count > 1) {
        [medios sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        NSUInteger encontrado = [medios indexOfObject:path];
        if (encontrado != NSNotFound) {
            lista = [medios copy];
            indice = (NSInteger)encontrado;
        }
    }
    return [self initWithPaths:lista startIndex:indice];
}

- (instancetype)initWithPaths:(NSArray<NSString *> *)paths startIndex:(NSInteger)index {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _rutas = paths.count ? [paths copy] : @[];
        _indice = (index >= 0 && index < (NSInteger)_rutas.count) ? index : 0;
        _aleatorio = NO;
        _modoRepeticion = 0;
        _velocidad = 1.0;
        _controlesVisibles = YES;
        _esVideo = _rutas.count ? [IOHelpers isVideoFile:_rutas[_indice]] : NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    self.contenedorVideo = [[UIView alloc] initWithFrame:self.view.bounds];
    self.contenedorVideo.backgroundColor = [UIColor blackColor];
    self.contenedorVideo.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                             UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.contenedorVideo];

    self.reproductor = [[AVPlayer alloc] init];
    self.reproductor.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    self.capa = [AVPlayerLayer playerLayerWithPlayer:self.reproductor];
    self.capa.videoGravity = AVLayerVideoGravityResizeAspect;
    self.capa.frame = self.contenedorVideo.bounds;
    [self.contenedorVideo.layer addSublayer:self.capa];

    self.fondo = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.fondo.contentMode = UIViewContentModeScaleAspectFill;
    self.fondo.clipsToBounds = YES;
    self.fondo.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                  UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:self.fondo aboveSubview:self.contenedorVideo];

    self.velo = [[UIView alloc] initWithFrame:self.view.bounds];
    self.velo.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
    self.velo.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                 UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:self.velo aboveSubview:self.fondo];

    self.caratula = [[UIImageView alloc] init];
    self.caratula.contentMode = UIViewContentModeScaleAspectFill;
    self.caratula.clipsToBounds = YES;
    self.caratula.layer.cornerRadius = 16.0;
    self.caratula.layer.masksToBounds = YES;
    self.caratula.hidden = YES;
    [self.view addSubview:self.caratula];

    self.cargando = [[UIActivityIndicatorView alloc]
                     initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [self.view addSubview:self.cargando];

    [self construirBarraSuperior];
    [self construirPanel];
    [self configurarGestos];
    [self crearObservadorTiempo];

    self.fondo.hidden = self.esVideo;
    self.velo.hidden = self.esVideo;
    self.caratula.hidden = self.esVideo;

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];

    [self cargarIndice:self.indice reproducir:YES];
    [self actualizarBotonesDeEstado];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self quitarObservadoresDelItem];
    if (self.observadorTiempo) {
        [self.reproductor removeTimeObserver:self.observadorTiempo];
        self.observadorTiempo = nil;
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.barraNavOcultaAntes = self.navigationController.navigationBarHidden;
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
    [self.reproductor play];
    if (self.velocidad != 1.0) { self.reproductor.rate = self.velocidad; }
    [self actualizarBotonPlay];
    [self reiniciarAutoOcultar];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.reproductor pause];
    [self.navigationController setNavigationBarHidden:self.barraNavOcultaAntes animated:YES];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [UIApplication sharedApplication].statusBarStyle = [IOTheme shared].dark
        ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat ancho = CGRectGetWidth(self.view.bounds);
    CGFloat alto = CGRectGetHeight(self.view.bounds);
    self.contenedorVideo.frame = self.view.bounds;
    self.capa.frame = self.contenedorVideo.bounds;
    self.fondo.frame = self.view.bounds;
    self.velo.frame = self.view.bounds;

    CGFloat altoBarra = 56.0;
    if ([UIApplication sharedApplication].statusBarFrame.size.height > 0) {
        altoBarra += [UIApplication sharedApplication].statusBarFrame.size.height;
    }
    if (altoBarra < 64.0) { altoBarra = 64.0; }
    self.barraSuperior.frame = CGRectMake(0, 0, ancho, altoBarra);

    CGFloat margen = 16.0;
    CGFloat altoPanel = 170.0;
    self.panel.frame = CGRectMake(margen, alto - altoPanel - margen,
                                  ancho - margen * 2.0, altoPanel);

    CGFloat xCerrar = 12.0;
    CGFloat ySuperior = altoBarra - 46.0;
    self.botonCerrar.frame = CGRectMake(xCerrar, ySuperior, 38, 38);
    self.botonVelocidad.frame = CGRectMake(ancho - 12 - 46, ySuperior, 46, 38);
    self.botonLista.frame = CGRectMake(ancho - 12 - 46 - 44, ySuperior, 44, 38);
    self.titulo.frame = CGRectMake(58, ySuperior + 1, ancho - 58 - 118, 21);
    self.subtitulo.frame = CGRectMake(58, ySuperior + 21, ancho - 58 - 118, 16);

    CGFloat anchoPanel = CGRectGetWidth(self.panel.bounds);
    self.deslizador.frame = CGRectMake(16, 16, anchoPanel - 32, 22);
    self.tiempoActual.frame = CGRectMake(16, 42, 70, 18);
    self.tiempoTotal.frame = CGRectMake(anchoPanel - 16 - 70, 42, 70, 18);

    CGFloat centroY = 112.0;
    self.botonPlay.frame = CGRectMake((anchoPanel - 56) / 2.0, centroY - 28, 56, 56);
    self.botonAleatorio.frame = CGRectMake(anchoPanel * 0.10 - 20, centroY - 20, 40, 40);
    self.botonAnterior.frame = CGRectMake(anchoPanel * 0.30 - 20, centroY - 20, 40, 40);
    self.botonSiguiente.frame = CGRectMake(anchoPanel * 0.70 - 20, centroY - 20, 40, 40);
    self.botonRepetir.frame = CGRectMake(anchoPanel * 0.90 - 20, centroY - 20, 40, 40);

    self.cargando.center = CGPointMake(ancho / 2.0,
        altoBarra + (CGRectGetMinY(self.panel.frame) - altoBarra) / 2.0);

    if (!self.esVideo) {
        CGFloat disponible = CGRectGetMinY(self.panel.frame) - altoBarra - 34.0;
        CGFloat lado = MIN(ancho - 80.0, MIN(300.0, disponible));
        lado = MAX(lado, 120.0);
        self.caratula.frame = CGRectMake((ancho - lado) / 2.0,
            altoBarra + (disponible - lado) / 2.0 + 10.0, lado, lado);
    }
}

#pragma mark - Construccion

- (void)construirBarraSuperior {
    self.barraSuperior = [[UIView alloc] initWithFrame:CGRectZero];
    self.barraSuperior.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.30];
    [self.view addSubview:self.barraSuperior];

    self.botonCerrar = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.botonCerrar setImage:[[IOFileIcons shared] glyph:IOGlyphChevronLeft
                                                    size:22.0 color:[UIColor whiteColor]]
                      forState:UIControlStateNormal];
    [self.botonCerrar addTarget:self action:@selector(cerrar)
               forControlEvents:UIControlEventTouchUpInside];
    [self.barraSuperior addSubview:self.botonCerrar];

    self.titulo = [[UILabel alloc] init];
    self.titulo.textColor = [UIColor whiteColor];
    self.titulo.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    self.titulo.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.barraSuperior addSubview:self.titulo];

    self.subtitulo = [[UILabel alloc] init];
    self.subtitulo.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
    self.subtitulo.font = [UIFont systemFontOfSize:11.0];
    self.subtitulo.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [self.barraSuperior addSubview:self.subtitulo];

    self.botonLista = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.botonLista setImage:IOPlayerImage(IOPlayerGlyphList, 22.0, [UIColor whiteColor])
                     forState:UIControlStateNormal];
    [self.botonLista addTarget:self action:@selector(mostrarLista)
              forControlEvents:UIControlEventTouchUpInside];
    [self.barraSuperior addSubview:self.botonLista];

    self.botonVelocidad = [UIButton buttonWithType:UIButtonTypeCustom];
    self.botonVelocidad.titleLabel.font = [UIFont systemFontOfSize:13.0
                                                           weight:UIFontWeightSemibold];
    [self.botonVelocidad setTitle:@"1x" forState:UIControlStateNormal];
    [self.botonVelocidad setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.botonVelocidad addTarget:self action:@selector(cambiarVelocidad)
                  forControlEvents:UIControlEventTouchUpInside];
    [self.barraSuperior addSubview:self.botonVelocidad];
}

- (void)construirPanel {
    self.panel = [[UIView alloc] initWithFrame:CGRectZero];
    self.panel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
    self.panel.layer.cornerRadius = 20.0;
    self.panel.layer.masksToBounds = YES;
    self.panel.layer.borderWidth = 0.5;
    self.panel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    [self.view addSubview:self.panel];

    self.deslizador = [[UISlider alloc] init];
    self.deslizador.minimumTrackTintColor = [IOTheme shared].accent;
    self.deslizador.maximumTrackTintColor = [UIColor colorWithWhite:1.0 alpha:0.22];
    [self.deslizador setThumbTintColor:[UIColor whiteColor]];
    [self.deslizador addTarget:self action:@selector(inicioArrastre)
              forControlEvents:UIControlEventTouchDown];
    [self.deslizador addTarget:self action:@selector(cambioDeslizador)
              forControlEvents:UIControlEventValueChanged];
    [self.deslizador addTarget:self action:@selector(finArrastre)
              forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.panel addSubview:self.deslizador];

    self.tiempoActual = [[UILabel alloc] init];
    self.tiempoActual.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    self.tiempoActual.font = [UIFont monospacedDigitSystemFontOfSize:11.0
                                                             weight:UIFontWeightRegular];
    self.tiempoActual.text = @"0:00";
    [self.panel addSubview:self.tiempoActual];

    self.tiempoTotal = [[UILabel alloc] init];
    self.tiempoTotal.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    self.tiempoTotal.font = [UIFont monospacedDigitSystemFontOfSize:11.0
                                                            weight:UIFontWeightRegular];
    self.tiempoTotal.textAlignment = NSTextAlignmentRight;
    self.tiempoTotal.text = @"0:00";
    [self.panel addSubview:self.tiempoTotal];

    self.botonAleatorio = [self botonConGlifo:IOPlayerGlyphShuffle
                                       accion:@selector(alternarAleatorio)];
    self.botonAnterior = [self botonConGlifo:IOPlayerGlyphPrev
                                      accion:@selector(irAnterior)];
    self.botonSiguiente = [self botonConGlifo:IOPlayerGlyphNext
                                       accion:@selector(irSiguiente:)];
    self.botonRepetir = [self botonConGlifo:IOPlayerGlyphRepeat
                                     accion:@selector(alternarRepeticion)];
    [self.panel addSubview:self.botonAleatorio];
    [self.panel addSubview:self.botonAnterior];
    [self.panel addSubview:self.botonSiguiente];
    [self.panel addSubview:self.botonRepetir];

    self.botonPlay = [UIButton buttonWithType:UIButtonTypeCustom];
    self.botonPlay.backgroundColor = [IOTheme shared].accent;
    self.botonPlay.layer.cornerRadius = 28.0;
    self.botonPlay.layer.masksToBounds = YES;
    [self.botonPlay addTarget:self action:@selector(alternarPlay)
             forControlEvents:UIControlEventTouchUpInside];
    [self.panel addSubview:self.botonPlay];
    [self actualizarBotonPlay];
}

- (UIButton *)botonConGlifo:(IOPlayerGlyph)glifo accion:(SEL)accion {
    UIButton *boton = [UIButton buttonWithType:UIButtonTypeCustom];
    [boton setImage:IOPlayerImage(glifo, 22.0, [UIColor colorWithWhite:1.0 alpha:0.85])
           forState:UIControlStateNormal];
    [boton addTarget:self action:accion forControlEvents:UIControlEventTouchUpInside];
    return boton;
}

- (void)configurarGestos {
    UITapGestureRecognizer *toque = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(alternarControles)];
    [self.contenedorVideo addGestureRecognizer:toque];

    UISwipeGestureRecognizer *derecha = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self action:@selector(irSiguiente:)];
    derecha.direction = UISwipeGestureRecognizerDirectionLeft;
    [self.contenedorVideo addGestureRecognizer:derecha];
}

- (void)aplicarTema {
    self.deslizador.minimumTrackTintColor = [IOTheme shared].accent;
    self.botonPlay.backgroundColor = [IOTheme shared].accent;
    [self actualizarBotonesDeEstado];
}

#pragma mark - Carga de pista

- (void)quitarObservadoresDelItem {
    if (!self.itemActual) { return; }
    @try {
        [self.itemActual removeObserver:self forKeyPath:@"status"
                                context:IOPlayerStatusContext];
    } @catch (NSException *excepcion) {
        (void)excepcion;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self
        name:AVPlayerItemDidPlayToEndTimeNotification object:self.itemActual];
    self.itemActual = nil;
}

- (void)cargarIndice:(NSInteger)nuevo reproducir:(BOOL)reproducir {
    if (self.rutas.count == 0) { return; }
    if (nuevo < 0) { nuevo = (NSInteger)self.rutas.count - 1; }
    if (nuevo >= (NSInteger)self.rutas.count) { nuevo = 0; }
    self.indice = nuevo;
    self.errorMostrado = NO;

    [self quitarObservadoresDelItem];

    NSString *ruta = self.rutas[nuevo];
    self.esVideo = [IOHelpers isVideoFile:ruta];
    self.fondo.hidden = self.esVideo;
    self.velo.hidden = self.esVideo;
    self.caratula.hidden = self.esVideo;

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:ruta]];
    self.itemActual = item;
    [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew
              context:IOPlayerStatusContext];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(finDeReproduccion:)
            name:AVPlayerItemDidPlayToEndTimeNotification object:item];

    if (self.reproductor) {
        [self.reproductor replaceCurrentItemWithPlayerItem:item];
    } else {
        self.reproductor = [AVPlayer playerWithPlayerItem:item];
    }

    self.deslizador.value = 0.0;
    self.tiempoActual.text = @"0:00";
    self.tiempoTotal.text = @"0:00";
    [self.cargando startAnimating];
    [self actualizarInfo];
    [self.view setNeedsLayout];

    if (!self.esVideo) {
        [self cargarCaratulaParaRuta:ruta];
    } else {
        self.fondo.image = nil;
        self.caratula.image = nil;
    }

    if (reproducir) {
        [self.reproductor play];
        if (self.velocidad != 1.0) { self.reproductor.rate = self.velocidad; }
    }
    [self actualizarBotonPlay];
    [self reiniciarAutoOcultar];
}

- (void)actualizarInfo {
    if (self.indice < 0 || self.indice >= (NSInteger)self.rutas.count) { return; }
    NSString *ruta = self.rutas[self.indice];
    self.titulo.text = [ruta lastPathComponent];
    self.subtitulo.text = [NSString stringWithFormat:@"%@ · %ld de %lu",
        [ruta stringByDeletingLastPathComponent],
        (long)(self.indice + 1), (unsigned long)self.rutas.count];
    self.title = [ruta lastPathComponent];
}

- (void)cargarCaratulaParaRuta:(NSString *)ruta {
    self.caratula.image = nil;
    self.fondo.image = nil;
    AVAsset *activo = [AVAsset assetWithURL:[NSURL fileURLWithPath:ruta]];
    NSString *rutaEsperada = ruta;
    __weak IOMediaPlayerViewController *debil = self;
    [activo loadValuesAsynchronouslyForKeys:@[ @"commonMetadata" ] completionHandler:^{
        AVKeyValueStatus estado = [activo statusOfValueForKey:@"commonMetadata" error:NULL];
        UIImage *imagen = nil;
        if (estado == AVKeyValueStatusLoaded) {
            for (AVMetadataItem *meta in activo.commonMetadata) {
                if (![meta.commonKey isEqualToString:AVMetadataCommonKeyArtwork]) { continue; }
                id valor = meta.value;
                NSData *datos = nil;
                if ([valor isKindOfClass:[NSData class]]) {
                    datos = valor;
                } else if ([valor isKindOfClass:[NSDictionary class]]) {
                    datos = ((NSDictionary *)valor)[@"data"];
                }
                if ([datos isKindOfClass:[NSData class]]) {
                    imagen = [UIImage imageWithData:datos];
                }
                break;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            IOMediaPlayerViewController *fuerte = debil;
            if (!fuerte) { return; }
            if (fuerte.indice < 0 || fuerte.indice >= (NSInteger)fuerte.rutas.count) { return; }
            if (![fuerte.rutas[fuerte.indice] isEqualToString:rutaEsperada]) { return; }
            fuerte.caratula.image = imagen;
            fuerte.fondo.image = imagen;
            fuerte.velo.hidden = (imagen == nil);
        });
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    if (context != IOPlayerStatusContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    AVPlayerItem *item = (AVPlayerItem *)object;
    if (item.status == AVPlayerItemStatusReadyToPlay) {
        [self.cargando stopAnimating];
    } else if (item.status == AVPlayerItemStatusFailed) {
        [self.cargando stopAnimating];
        if (self.errorMostrado) { return; }
        self.errorMostrado = YES;
        [IODialog showAlertIn:self title:@"No se puede reproducir"
                      message:item.error.localizedDescription ?: @"Formato no compatible."];
    }
}

#pragma mark - Reproduccion

- (void)crearObservadorTiempo {
    __weak IOMediaPlayerViewController *debil = self;
    CMTime intervalo = CMTimeMakeWithSeconds(0.5, NSEC_PER_SEC);
    self.observadorTiempo = [self.reproductor
        addPeriodicTimeObserverForInterval:intervalo
                                     queue:dispatch_get_main_queue()
                                usingBlock:^(CMTime tiempo) {
        [debil actualizarTiempo:tiempo];
    }];
}

- (void)actualizarTiempo:(CMTime)tiempo {
    CMTime duracion = self.itemActual.duration;
    if (CMTIME_IS_INVALID(duracion) || CMTIME_IS_INDEFINITE(duracion)) { return; }
    double total = CMTimeGetSeconds(duracion);
    double actual = CMTimeGetSeconds(tiempo);
    if (total <= 0 || isnan(total)) { return; }
    if (!self.arrastrando) {
        self.deslizador.value = (float)(actual / total);
    }
    self.tiempoActual.text = [self formatearTiempo:actual];
    self.tiempoTotal.text = [self formatearTiempo:total];
    [self actualizarBotonPlay];
}

- (NSString *)formatearTiempo:(double)segundos {
    if (isnan(segundos) || segundos < 0) { segundos = 0; }
    int total = (int)segundos;
    int h = total / 3600;
    int m = (total % 3600) / 60;
    int s = total % 60;
    if (h > 0) { return [NSString stringWithFormat:@"%d:%02d:%02d", h, m, s]; }
    return [NSString stringWithFormat:@"%d:%02d", m, s];
}

- (void)actualizarBotonPlay {
    BOOL reproduciendo = (self.reproductor.rate != 0.0);
    if (reproduciendo == self.ultimoEstadoReproduciendo && self.botonPlay.imageView.image) {
        return;
    }
    self.ultimoEstadoReproduciendo = reproduciendo;
    [self.botonPlay setImage:IOPlayerImage(reproduciendo ? IOPlayerGlyphPause
                                                         : IOPlayerGlyphPlay,
                                           26.0, [UIColor whiteColor])
                    forState:UIControlStateNormal];
}

- (void)alternarPlay {
    if (self.reproductor.rate != 0.0) {
        [self.reproductor pause];
    } else {
        CMTime duracion = self.itemActual.duration;
        if (CMTIME_IS_VALID(duracion) && !CMTIME_IS_INDEFINITE(duracion)) {
            double total = CMTimeGetSeconds(duracion);
            double actual = CMTimeGetSeconds(self.reproductor.currentTime);
            if (total > 0 && actual >= total - 0.2) {
                [self.reproductor seekToTime:kCMTimeZero];
            }
        }
        [self.reproductor play];
        if (self.velocidad != 1.0) { self.reproductor.rate = self.velocidad; }
    }
    [self actualizarBotonPlay];
    [self reiniciarAutoOcultar];
}

- (void)irAnterior {
    CMTime actual = self.reproductor.currentTime;
    if (CMTIME_IS_VALID(actual) && CMTimeGetSeconds(actual) > 3.0) {
        [self.reproductor seekToTime:kCMTimeZero];
        [self actualizarBotonPlay];
        return;
    }
    [self cargarIndice:self.indice - 1 reproducir:YES];
}

- (void)irSiguiente:(id)origen {
    [self avanzarAutomatico:NO];
}

- (void)avanzarAutomatico:(BOOL)automatico {
    if (self.rutas.count == 0) { return; }
    if (self.aleatorio && self.rutas.count > 1) {
        NSInteger nuevo = self.indice;
        while (nuevo == self.indice) {
            nuevo = arc4random_uniform((uint32_t)self.rutas.count);
        }
        [self cargarIndice:nuevo reproducir:YES];
        return;
    }
    NSInteger nuevo = self.indice + 1;
    if (nuevo >= (NSInteger)self.rutas.count) {
        if (self.modoRepeticion == 1 || !automatico) {
            nuevo = 0;
        } else {
            [self.reproductor pause];
            [self actualizarBotonPlay];
            return;
        }
    }
    [self cargarIndice:nuevo reproducir:YES];
}

- (void)finDeReproduccion:(NSNotification *)notificacion {
    if (self.modoRepeticion == 2) {
        [self.reproductor seekToTime:kCMTimeZero];
        [self.reproductor play];
        if (self.velocidad != 1.0) { self.reproductor.rate = self.velocidad; }
        [self actualizarBotonPlay];
        return;
    }
    [self avanzarAutomatico:YES];
}

#pragma mark - Controles

- (void)inicioArrastre {
    self.arrastrando = YES;
    self.eraReproduciendo = (self.reproductor.rate != 0.0);
}

- (void)cambioDeslizador {
    CMTime duracion = self.itemActual.duration;
    if (CMTIME_IS_INVALID(duracion) || CMTIME_IS_INDEFINITE(duracion)) { return; }
    double total = CMTimeGetSeconds(duracion);
    double nuevo = total * self.deslizador.value;
    self.tiempoActual.text = [self formatearTiempo:nuevo];
}

- (void)finArrastre {
    CMTime duracion = self.itemActual.duration;
    if (CMTIME_IS_INVALID(duracion) || CMTIME_IS_INDEFINITE(duracion)) {
        self.arrastrando = NO;
        return;
    }
    double total = CMTimeGetSeconds(duracion);
    double nuevo = total * self.deslizador.value;
    __weak IOMediaPlayerViewController *debil = self;
    [self.reproductor seekToTime:CMTimeMakeWithSeconds(nuevo, NSEC_PER_SEC)
        toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero
        completionHandler:^(BOOL terminado) {
        IOMediaPlayerViewController *fuerte = debil;
        if (!fuerte) { return; }
        fuerte.arrastrando = NO;
        if (fuerte.eraReproduciendo) {
            [fuerte.reproductor play];
            if (fuerte.velocidad != 1.0) { fuerte.reproductor.rate = fuerte.velocidad; }
        }
    }];
}

- (void)alternarAleatorio {
    self.aleatorio = !self.aleatorio;
    [self actualizarBotonesDeEstado];
}

- (void)alternarRepeticion {
    self.modoRepeticion = (self.modoRepeticion + 1) % 3;
    [self actualizarBotonesDeEstado];
}

- (void)actualizarBotonesDeEstado {
    IOTheme *tema = [IOTheme shared];
    UIColor *activo = tema.accent;
    UIColor *normal = [UIColor colorWithWhite:1.0 alpha:0.85];

    [self.botonAleatorio setImage:IOPlayerImage(IOPlayerGlyphShuffle, 22.0,
        self.aleatorio ? activo : normal) forState:UIControlStateNormal];

    IOPlayerGlyph glifo = IOPlayerGlyphRepeat;
    if (self.modoRepeticion == 2) { glifo = IOPlayerGlyphRepeatOne; }
    UIColor *colorRepetir = (self.modoRepeticion == 0) ? normal : activo;
    [self.botonRepetir setImage:IOPlayerImage(glifo, 22.0, colorRepetir)
                       forState:UIControlStateNormal];
}

- (void)cambiarVelocidad {
    NSArray *valores = @[ @0.5, @1.0, @1.5, @2.0 ];
    NSUInteger actual = 1;
    for (NSUInteger i = 0; i < valores.count; i++) {
        if (fabs([valores[i] doubleValue] - self.velocidad) < 0.01) { actual = i; break; }
    }
    actual = (actual + 1) % valores.count;
    self.velocidad = [valores[actual] doubleValue];
    NSString *texto = [NSString stringWithFormat:@"%gx", self.velocidad];
    [self.botonVelocidad setTitle:texto forState:UIControlStateNormal];
    if (self.reproductor.rate != 0.0) {
        self.reproductor.rate = self.velocidad;
    }
}

- (void)mostrarLista {
    if (self.rutas.count == 0) { return; }
    NSMutableArray *acciones = [NSMutableArray array];
    __weak IOMediaPlayerViewController *debil = self;
    NSUInteger limite = MIN(self.rutas.count, (NSUInteger)100);
    for (NSUInteger i = 0; i < limite; i++) {
        NSString *ruta = self.rutas[i];
        NSString *nombre = [ruta lastPathComponent];
        BOOL actual = ((NSInteger)i == self.indice);
        NSString *titulo = [NSString stringWithFormat:@"%@%@",
                            actual ? @"✓ " : @"", nombre];
        NSInteger indice = (NSInteger)i;
        [acciones addObject:[IODialogAction actionWithTitle:titulo
            style:(actual ? IODialogActionStyleSelected : IODialogActionStyleDefault)
            handler:^{ [debil cargarIndice:indice reproducir:YES]; }]];
    }
    [IODialog showSheetIn:self
                    title:[NSString stringWithFormat:@"Lista · %lu pistas",
                           (unsigned long)self.rutas.count]
                  actions:acciones];
}

- (void)alternarControles {
    if (!self.esVideo) { return; }
    self.controlesVisibles = !self.controlesVisibles;
    [UIView animateWithDuration:0.2 animations:^{
        self.barraSuperior.alpha = self.controlesVisibles ? 1.0 : 0.0;
        self.panel.alpha = self.controlesVisibles ? 1.0 : 0.0;
    }];
    self.barraSuperior.userInteractionEnabled = self.controlesVisibles;
    self.panel.userInteractionEnabled = self.controlesVisibles;
    if (self.controlesVisibles) { [self reiniciarAutoOcultar]; }
}

- (void)reiniciarAutoOcultar {
    if (!self.esVideo) { return; }
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(ocultarControles)
                                               object:nil];
    [self performSelector:@selector(ocultarControles) withObject:nil afterDelay:4.5];
}

- (void)ocultarControles {
    if (!self.esVideo || self.reproductor.rate == 0.0) { return; }
    self.controlesVisibles = NO;
    [UIView animateWithDuration:0.3 animations:^{
        self.barraSuperior.alpha = 0.0;
        self.panel.alpha = 0.0;
    }];
    self.barraSuperior.userInteractionEnabled = NO;
    self.panel.userInteractionEnabled = NO;
}

- (void)cerrar {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
