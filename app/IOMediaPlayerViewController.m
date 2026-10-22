#import "IOMediaPlayerViewController.h"

#import "IOTheme.h"
#import "IOHelpers.h"
#import "IOFileIcons.h"

#import <AVFoundation/AVFoundation.h>

@interface IOMediaPlayerViewController ()
@property (nonatomic, copy) NSString *ruta;
@property (nonatomic, strong) AVPlayer *reproductor;
@property (nonatomic, strong) AVPlayerLayer *capa;
@property (nonatomic, strong) UIView *contenedor;
@property (nonatomic, strong) UIView *controles;
@property (nonatomic, strong) UIButton *botonPlay;
@property (nonatomic, strong) UISlider *deslizador;
@property (nonatomic, strong) UILabel *tiempoActual;
@property (nonatomic, strong) UILabel *tiempoTotal;
@property (nonatomic, strong) UIImageView *iconoAudio;
@property (nonatomic, assign) BOOL controlesVisibles;
@property (nonatomic, assign) BOOL arrastrando;
@property (nonatomic, strong) id observadorTiempo;
@property (nonatomic, assign) BOOL esVideo;
@end

@implementation IOMediaPlayerViewController

- (instancetype)initWithPath:(NSString *)path {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _ruta = [path copy];
        _esVideo = [IOHelpers isVideoFile:path];
        _controlesVisibles = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.title = [self.ruta lastPathComponent];

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:self.ruta]];
    self.reproductor = [AVPlayer playerWithPlayerItem:item];
    self.reproductor.actionAtItemEnd = AVPlayerActionAtItemEndNone;

    self.contenedor = [[UIView alloc] initWithFrame:self.view.bounds];
    self.contenedor.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.contenedor];

    self.capa = [AVPlayerLayer playerLayerWithPlayer:self.reproductor];
    self.capa.videoGravity = AVLayerVideoGravityResizeAspect;
    self.capa.frame = self.contenedor.bounds;
    [self.contenedor.layer addSublayer:self.capa];

    if (!self.esVideo) {
        self.iconoAudio = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 120, 120)];
        self.iconoAudio.center = self.view.center;
        self.iconoAudio.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
            UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin |
            UIViewAutoresizingFlexibleBottomMargin;
        self.iconoAudio.image = [[IOFileIcons shared] glyph:IOGlyphAudio size:110.0
                                                       color:[IOTheme shared].accent
                                                  lineWidth:4.0];
        [self.view addSubview:self.iconoAudio];
    }

    [self construirControles];

    UITapGestureRecognizer *toque = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(alternarControles)];
    [self.view addGestureRecognizer:toque];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(finDeReproduccion:)
            name:AVPlayerItemDidPlayToEndTimeNotification
            object:[self.reproductor currentItem]];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(tecladoInnecesario)
            name:IOThemeDidChangeNotification object:nil];

    [self iniciarObservadorTiempo];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.observadorTiempo) {
        [self.reproductor removeTimeObserver:self.observadorTiempo];
        self.observadorTiempo = nil;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.reproductor play];
    [self actualizarBotonPlay];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.reproductor pause];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.capa.frame = self.contenedor.bounds;
}

- (void)tecladoInnecesario {
    // Reaplica el color de acento por si cambio el tema.
    self.deslizador.minimumTrackTintColor = [IOTheme shared].accent;
}

- (void)construirControles {
    CGFloat alto = 44.0;
    self.controles = [[UIView alloc] initWithFrame:CGRectMake(0,
        CGRectGetHeight(self.view.bounds) - alto, CGRectGetWidth(self.view.bounds), alto)];
    self.controles.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.controles.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    [self.view addSubview:self.controles];

    self.botonPlay = [UIButton buttonWithType:UIButtonTypeSystem];
    self.botonPlay.frame = CGRectMake(6, 4, 36, 36);
    self.botonPlay.tintColor = [UIColor whiteColor];
    [self.botonPlay addTarget:self action:@selector(alternarPlay)
              forControlEvents:UIControlEventTouchUpInside];
    [self.controles addSubview:self.botonPlay];

    self.tiempoActual = [[UILabel alloc] initWithFrame:CGRectMake(48, 4, 46, 36)];
    self.tiempoActual.textColor = [UIColor whiteColor];
    self.tiempoActual.font = [UIFont monospacedDigitSystemFontOfSize:12.0
                                                             weight:UIFontWeightRegular];
    self.tiempoActual.text = @"0:00";
    [self.controles addSubview:self.tiempoActual];

    self.deslizador = [[UISlider alloc] init];
    self.deslizador.tintColor = [IOTheme shared].accent;
    self.deslizador.translatesAutoresizingMaskIntoConstraints = NO;
    [self.deslizador addTarget:self action:@selector(inicioArrastre)
              forControlEvents:UIControlEventTouchDown];
    [self.deslizador addTarget:self action:@selector(finArrastre)
              forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.deslizador addTarget:self action:@selector(cambioDeslizador)
              forControlEvents:UIControlEventValueChanged];
    [self.controles addSubview:self.deslizador];

    self.tiempoTotal = [[UILabel alloc] initWithFrame:CGRectMake(0, 4, 46, 36)];
    self.tiempoTotal.textColor = [UIColor whiteColor];
    self.tiempoTotal.font = [UIFont monospacedDigitSystemFontOfSize:12.0
                                                             weight:UIFontWeightRegular];
    self.tiempoTotal.textAlignment = NSTextAlignmentCenter;
    self.tiempoTotal.text = @"0:00";
    [self.controles addSubview:self.tiempoTotal];

    [self.controles addConstraints:@[
        [NSLayoutConstraint constraintWithItem:self.deslizador attribute:NSLayoutAttributeLeading
            relatedBy:NSLayoutRelationEqual toItem:self.controles
            attribute:NSLayoutAttributeLeading multiplier:1 constant:96],
        [NSLayoutConstraint constraintWithItem:self.deslizador attribute:NSLayoutAttributeCenterY
            relatedBy:NSLayoutRelationEqual toItem:self.controles
            attribute:NSLayoutAttributeCenterY multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.deslizador attribute:NSLayoutAttributeTrailing
            relatedBy:NSLayoutRelationEqual toItem:self.controles
            attribute:NSLayoutAttributeTrailing multiplier:1 constant:-56]
    ]];
    self.tiempoTotal.frame = CGRectMake(CGRectGetWidth(self.view.bounds) - 52, 4, 46, 36);
    self.tiempoTotal.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;

    [self actualizarBotonPlay];
}

- (void)actualizarBotonPlay {
    BOOL reproduciendo = (self.reproductor.rate != 0.0);
    NSString *titulo = reproduciendo ? @"\u23F8" : @"\u25B6";
    [self.botonPlay setTitle:titulo forState:UIControlStateNormal];
    self.botonPlay.titleLabel.font = [UIFont systemFontOfSize:24.0];
}

- (void)alternarPlay {
    if (self.reproductor.rate != 0.0) {
        [self.reproductor pause];
    } else {
        if (CMTIME_COMPARE_INLINE(self.reproductor.currentTime, >=,
                                  [self.reproductor currentItem].duration)) {
            [self.reproductor seekToTime:kCMTimeZero];
        }
        [self.reproductor play];
    }
    [self actualizarBotonPlay];
    [self reiniciarAutoOcultar];
}

- (void)alternarControles {
    self.controlesVisibles = !self.controlesVisibles;
    [UIView animateWithDuration:0.2 animations:^{
        self.controles.alpha = self.controlesVisibles ? 1.0 : 0.0;
    }];
}

- (void)reiniciarAutoOcultar {
    if (!self.esVideo) { return; }
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(ocultarControles)
                                               object:nil];
    [self performSelector:@selector(ocultarControles) withObject:nil afterDelay:4.0];
}

- (void)ocultarControles {
    if (self.reproductor.rate == 0.0) { return; }
    self.controlesVisibles = NO;
    [UIView animateWithDuration:0.3 animations:^{ self.controles.alpha = 0.0; }];
}

#pragma mark - Tiempo

- (void)iniciarObservadorTiempo {
    __weak IOMediaPlayerViewController *debil = self;
    CMTime intervalo = CMTimeMakeWithSeconds(0.5, NSEC_PER_SEC);
    self.observadorTiempo = [self.reproductor addPeriodicTimeObserverForInterval:intervalo
                                                                          queue:dispatch_get_main_queue()
                                                                     usingBlock:^(CMTime tiempo) {
        [debil actualizarTiempo:tiempo];
    }];
}

- (void)actualizarTiempo:(CMTime)tiempo {
    CMTime duracion = [self.reproductor currentItem].duration;
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
    if (h > 0) {
        return [NSString stringWithFormat:@"%d:%02d:%02d", h, m, s];
    }
    return [NSString stringWithFormat:@"%d:%02d", m, s];
}

- (void)inicioArrastre { self.arrastrando = YES; }

- (void)cambioDeslizador {
    CMTime duracion = [self.reproductor currentItem].duration;
    if (CMTIME_IS_INVALID(duracion) || CMTIME_IS_INDEFINITE(duracion)) { return; }
    double total = CMTimeGetSeconds(duracion);
    double nuevo = total * self.deslizador.value;
    self.tiempoActual.text = [self formatearTiempo:nuevo];
}

- (void)finArrastre {
    CMTime duracion = [self.reproductor currentItem].duration;
    if (CMTIME_IS_INVALID(duracion) || CMTIME_IS_INDEFINITE(duracion)) {
        self.arrastrando = NO;
        return;
    }
    double total = CMTimeGetSeconds(duracion);
    double nuevo = total * self.deslizador.value;
    [self.reproductor seekToTime:CMTimeMakeWithSeconds(nuevo, NSEC_PER_SEC)
        toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero
        completionHandler:^(BOOL terminado) {
        self.arrastrando = NO;
    }];
}

- (void)finDeReproduccion:(NSNotification *)notificacion {
    [self.reproductor seekToTime:kCMTimeZero];
    [self.reproductor pause];
    [self actualizarBotonPlay];
    self.controlesVisibles = YES;
    [UIView animateWithDuration:0.2 animations:^{ self.controles.alpha = 1.0; }];
}

@end
