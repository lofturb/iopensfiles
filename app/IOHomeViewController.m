#import "IOHomeViewController.h"

#import "IOTheme.h"
#import "IOSettings.h"
#import "IOStore.h"
#import "IOFileSystem.h"
#import "IOFileIcons.h"
#import "IOHelpers.h"
#import "IODialog.h"
#import "IOFilesViewController.h"
#import "IOAnalyzerViewController.h"
#import "IOInstallViewController.h"
#import "IOTrashViewController.h"
#import "IOTrash.h"
#import "IOSettingsViewController.h"

#import <sys/utsname.h>
#import <unistd.h>

#pragma mark - Tarjeta de almacenamiento

@interface IOStorageCardView : UIControl
@property (nonatomic, strong) UIImageView *icono;
@property (nonatomic, strong) UIView *fondoIcono;
@property (nonatomic, strong) UILabel *titulo;
@property (nonatomic, strong) UILabel *ruta;
@property (nonatomic, strong) UILabel *detalle;
@property (nonatomic, strong) UILabel *porcentaje;
@property (nonatomic, strong) UIView *barraFondo;
@property (nonatomic, strong) UIView *barraRelleno;
@property (nonatomic, strong) UIImageView *chevron;
@property (nonatomic, assign) double fraccion;
@property (nonatomic, strong) UIColor *tinte;
- (void)configurarConVolumen:(NSDictionary *)volumen;
- (void)aplicarTema;
@end

@implementation IOStorageCardView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = 16.0;
        self.layer.borderWidth = 0.5;
        self.fondoIcono = [[UIView alloc] init];
        self.fondoIcono.layer.cornerRadius = 11.0;
        self.fondoIcono.layer.masksToBounds = YES;
        [self addSubview:self.fondoIcono];

        self.icono = [[UIImageView alloc] init];
        self.icono.contentMode = UIViewContentModeCenter;
        [self.fondoIcono addSubview:self.icono];

        self.titulo = [[UILabel alloc] init];
        [self addSubview:self.titulo];
        self.ruta = [[UILabel alloc] init];
        self.ruta.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self addSubview:self.ruta];
        self.detalle = [[UILabel alloc] init];
        [self addSubview:self.detalle];
        self.porcentaje = [[UILabel alloc] init];
        self.porcentaje.textAlignment = NSTextAlignmentRight;
        [self addSubview:self.porcentaje];

        self.barraFondo = [[UIView alloc] init];
        self.barraFondo.layer.cornerRadius = 3.0;
        self.barraFondo.layer.masksToBounds = YES;
        [self addSubview:self.barraFondo];
        self.barraRelleno = [[UIView alloc] init];
        self.barraRelleno.layer.cornerRadius = 3.0;
        self.barraRelleno.layer.masksToBounds = YES;
        [self.barraFondo addSubview:self.barraRelleno];

        self.chevron = [[UIImageView alloc] init];
        self.chevron.contentMode = UIViewContentModeCenter;
        [self addSubview:self.chevron];

        [self aplicarTema];
    }
    return self;
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.backgroundColor = tema.cardBackground;
    self.layer.borderColor = tema.separator.CGColor;
    self.titulo.textColor = tema.textPrimary;
    self.titulo.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    self.ruta.textColor = tema.textSecondary;
    self.ruta.font = [tema fontSubhead];
    self.detalle.textColor = tema.textSecondary;
    self.detalle.font = [UIFont systemFontOfSize:11.0];
    self.porcentaje.textColor = tema.textTertiary;
    self.porcentaje.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    self.barraFondo.backgroundColor = tema.separator;
    self.chevron.image = [[IOFileIcons shared] glyph:IOGlyphChevronRight size:14.0
                                                 color:tema.textTertiary];
    [self configurarIcono];
}

- (void)configurarIcono {
    IOTheme *tema = [IOTheme shared];
    UIColor *color = self.tinte ?: tema.accent;
    self.fondoIcono.backgroundColor = [color colorWithAlphaComponent:0.15];
    self.icono.image = [[IOFileIcons shared] glyph:IOGlyphDisk size:24.0 color:color];
    self.barraRelleno.backgroundColor = color;
}

- (void)configurarConVolumen:(NSDictionary *)volumen {
    IOTheme *tema = [IOTheme shared];
    NSString *nombre = volumen[@"name"];
    self.tinte = [nombre isEqualToString:@"Datos"] ? tema.success : tema.accent;
    self.titulo.text = nombre;
    self.ruta.text = volumen[@"path"];

    unsigned long long total = [volumen[@"total"] unsignedLongLongValue];
    unsigned long long libre = [volumen[@"free"] unsignedLongLongValue];
    unsigned long long usado = total > libre ? total - libre : 0;
    self.fraccion = total > 0 ? (double)usado / (double)total : 0.0;
    self.detalle.text = [NSString stringWithFormat:@"%@ libres de %@",
                         [IOHelpers humanSize:libre], [IOHelpers humanSize:total]];
    self.porcentaje.text = [NSString stringWithFormat:@"%d%% usado",
                            (int)(self.fraccion * 100.0 + 0.5)];
    [self configurarIcono];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = CGRectGetWidth(self.bounds);
    self.fondoIcono.frame = CGRectMake(16, 18, 42, 42);
    self.icono.frame = self.fondoIcono.bounds;
    self.chevron.frame = CGRectMake(ancho - 28, 24, 16, 16);
    self.titulo.frame = CGRectMake(70, 16, ancho - 70 - 40, 22);
    self.ruta.frame = CGRectMake(70, 39, ancho - 70 - 40, 16);
    self.barraFondo.frame = CGRectMake(16, 76, ancho - 32, 6);
    self.barraRelleno.frame = CGRectMake(0, 0,
        CGRectGetWidth(self.barraFondo.bounds) * self.fraccion,
        CGRectGetHeight(self.barraFondo.bounds));
    self.detalle.frame = CGRectMake(16, 88, ancho - 32 - 90, 16);
    self.porcentaje.frame = CGRectMake(ancho - 16 - 100, 88, 100, 16);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.75 : 1.0;
}

@end

#pragma mark - Azulejo de accion

@interface IOActionTileView : UIControl
@property (nonatomic, strong) UIImageView *icono;
@property (nonatomic, strong) UIView *fondoIcono;
@property (nonatomic, strong) UILabel *titulo;
@property (nonatomic, strong) UILabel *detalle;
@property (nonatomic, assign) IOGlyph glifo;
@property (nonatomic, strong) UIColor *tinte;
- (void)configurarConTitulo:(NSString *)titulo detalle:(NSString *)detalle
                       glifo:(IOGlyph)glifo tinte:(UIColor *)tinte;
- (void)aplicarTema;
@end

@implementation IOActionTileView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = 16.0;
        self.layer.borderWidth = 0.5;
        self.fondoIcono = [[UIView alloc] init];
        self.fondoIcono.layer.cornerRadius = 10.0;
        self.fondoIcono.layer.masksToBounds = YES;
        [self addSubview:self.fondoIcono];
        self.icono = [[UIImageView alloc] init];
        self.icono.contentMode = UIViewContentModeCenter;
        [self.fondoIcono addSubview:self.icono];
        self.titulo = [[UILabel alloc] init];
        [self addSubview:self.titulo];
        self.detalle = [[UILabel alloc] init];
        [self addSubview:self.detalle];
        [self aplicarTema];
    }
    return self;
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.backgroundColor = tema.cardBackground;
    self.layer.borderColor = tema.separator.CGColor;
    self.titulo.textColor = tema.textPrimary;
    self.titulo.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    self.detalle.textColor = tema.textSecondary;
    self.detalle.font = [UIFont systemFontOfSize:11.0];
    [self refrescarIcono];
}

- (void)refrescarIcono {
    UIColor *color = self.tinte ?: [IOTheme shared].accent;
    self.fondoIcono.backgroundColor = [color colorWithAlphaComponent:0.15];
    self.icono.image = [[IOFileIcons shared] glyph:self.glifo size:22.0 color:color];
}

- (void)configurarConTitulo:(NSString *)titulo detalle:(NSString *)detalle
                       glifo:(IOGlyph)glifo tinte:(UIColor *)tinte {
    self.titulo.text = titulo;
    self.detalle.text = detalle;
    self.glifo = glifo;
    self.tinte = tinte;
    [self refrescarIcono];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = CGRectGetWidth(self.bounds);
    self.fondoIcono.frame = CGRectMake(14, 14, 36, 36);
    self.icono.frame = self.fondoIcono.bounds;
    self.titulo.frame = CGRectMake(14, 56, ancho - 28, 20);
    self.detalle.frame = CGRectMake(14, 75, ancho - 28, 15);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.75 : 1.0;
}

@end

#pragma mark - Fila de reciente

@interface IORecentRowView : UIControl
@property (nonatomic, strong) UIImageView *icono;
@property (nonatomic, strong) UILabel *titulo;
@property (nonatomic, strong) UILabel *ruta;
@property (nonatomic, strong) UIImageView *chevron;
- (void)configurarConRuta:(NSString *)ruta;
- (void)aplicarTema;
@end

@implementation IORecentRowView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = 14.0;
        self.layer.borderWidth = 0.5;
        self.icono = [[UIImageView alloc] init];
        self.icono.contentMode = UIViewContentModeCenter;
        [self addSubview:self.icono];
        self.titulo = [[UILabel alloc] init];
        [self addSubview:self.titulo];
        self.ruta = [[UILabel alloc] init];
        self.ruta.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self addSubview:self.ruta];
        self.chevron = [[UIImageView alloc] init];
        self.chevron.contentMode = UIViewContentModeCenter;
        [self addSubview:self.chevron];
        [self aplicarTema];
    }
    return self;
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.backgroundColor = tema.cardBackground;
    self.layer.borderColor = tema.separator.CGColor;
    self.titulo.textColor = tema.textPrimary;
    self.titulo.font = [tema fontBody];
    self.ruta.textColor = tema.textSecondary;
    self.ruta.font = [tema fontSubhead];
    self.icono.image = [[IOFileIcons shared] glyph:IOGlyphClock size:20.0
                                              color:tema.textTertiary];
    self.chevron.image = [[IOFileIcons shared] glyph:IOGlyphChevronRight size:14.0
                                                 color:tema.textTertiary];
}

- (void)configurarConRuta:(NSString *)ruta {
    NSString *nombre = [ruta lastPathComponent];
    self.titulo.text = nombre.length ? nombre : @"/";
    self.ruta.text = ruta;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = CGRectGetWidth(self.bounds);
    self.icono.frame = CGRectMake(14, (CGRectGetHeight(self.bounds) - 24) / 2.0, 24, 24);
    self.titulo.frame = CGRectMake(48, 10, ancho - 48 - 34, 20);
    self.ruta.frame = CGRectMake(48, 30, ancho - 48 - 34, 16);
    self.chevron.frame = CGRectMake(ancho - 26, (CGRectGetHeight(self.bounds) - 14) / 2.0, 14, 14);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.75 : 1.0;
}

@end

#pragma mark - Inicio

@interface IOHomeViewController () <UIScrollViewDelegate>
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView *contenido;
@property (nonatomic, strong) UIRefreshControl *refresco;

@property (nonatomic, strong) UILabel *tituloGrande;
@property (nonatomic, strong) UILabel *subtituloGrande;
@property (nonatomic, strong) UILabel *etiquetaVolumenes;
@property (nonatomic, strong) UILabel *etiquetaAcciones;
@property (nonatomic, strong) UILabel *etiquetaRecientes;
@property (nonatomic, strong) UILabel *sinRecientes;
@property (nonatomic, strong) UIButton *botonInicio;
@property (nonatomic, strong) UIButton *botonIr;
@property (nonatomic, strong) UIButton *botonSistema;

@property (nonatomic, strong) UILabel *tituloNav;
@property (nonatomic, strong) UILabel *subtituloNav;

@property (nonatomic, strong) NSArray<NSDictionary *> *volumenes;
@property (nonatomic, strong) NSArray<NSDictionary *> *acciones;
@property (nonatomic, strong) NSArray<NSString *> *recientes;
@property (nonatomic, strong) NSMutableArray<IOStorageCardView *> *tarjetas;
@property (nonatomic, strong) NSMutableArray<IOActionTileView *> *azulejos;
@property (nonatomic, strong) NSMutableArray<IORecentRowView *> *filas;
@property (nonatomic, weak) IOActionTileView *azulejoPapelera;
@end

@implementation IOHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [IOTheme shared].background;
    self.tarjetas = [NSMutableArray array];
    self.azulejos = [NSMutableArray array];
    self.filas = [NSMutableArray array];

    [self construirNavegacion];
    [self construirScroll];
    [self construirEstaticos];
    [self construirAcciones];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];

    [self aplicarTema];
    [self recargar];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self recargar];
}

#pragma mark - Construccion

- (void)construirNavegacion {
    if (self.showsSidebarToggle) {
        UIImage *imagen = [[IOFileIcons shared] glyph:IOGlyphMenu size:22.0
                                                color:[UIColor blackColor]];
        imagen = [imagen imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
            initWithImage:imagen style:UIBarButtonItemStylePlain
                   target:self action:@selector(pulsarLateral)];
    }

    UIImage *engranaje = [[IOFileIcons shared] glyph:IOGlyphGear size:22.0
                                               color:[UIColor blackColor]];
    engranaje = [engranaje imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithImage:engranaje style:UIBarButtonItemStylePlain
               target:self action:@selector(abrirAjustes)];

    UIView *contenedor = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 40)];
    self.tituloNav = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 220, 24)];
    self.tituloNav.text = @"IOpenFiles";
    self.tituloNav.textAlignment = NSTextAlignmentCenter;
    [contenedor addSubview:self.tituloNav];
    self.subtituloNav = [[UILabel alloc] initWithFrame:CGRectMake(0, 22, 220, 14)];
    self.subtituloNav.textAlignment = NSTextAlignmentCenter;
    [contenedor addSubview:self.subtituloNav];
    self.navigationItem.titleView = contenedor;
}

- (void)construirScroll {
    self.scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.alwaysBounceVertical = YES;
    self.scroll.delegate = self;
    [self.view addSubview:self.scroll];
    [self.view addConstraints:@[
        [NSLayoutConstraint constraintWithItem:self.scroll attribute:NSLayoutAttributeTop
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeTop multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.scroll attribute:NSLayoutAttributeLeading
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeLeading multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.scroll attribute:NSLayoutAttributeTrailing
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeTrailing multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.scroll attribute:NSLayoutAttributeBottom
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeBottom multiplier:1 constant:0]
    ]];

    self.refresco = [[UIRefreshControl alloc] init];
    [self.refresco addTarget:self action:@selector(recargar)
            forControlEvents:UIControlEventValueChanged];
    [self.scroll addSubview:self.refresco];

    self.contenido = [[UIView alloc] initWithFrame:CGRectZero];
    [self.scroll addSubview:self.contenido];
}

- (void)construirEstaticos {
    self.tituloGrande = [[UILabel alloc] init];
    self.tituloGrande.text = @"Almacenamiento";
    [self.contenido addSubview:self.tituloGrande];

    self.subtituloGrande = [[UILabel alloc] init];
    self.subtituloGrande.text = @"Todo tu iPad en un solo lugar";
    [self.contenido addSubview:self.subtituloGrande];

    self.etiquetaVolumenes = [[UILabel alloc] init];
    self.etiquetaVolumenes.text = @"VOLUMENES";
    [self.contenido addSubview:self.etiquetaVolumenes];

    self.etiquetaAcciones = [[UILabel alloc] init];
    self.etiquetaAcciones.text = @"ACCIONES RAPIDAS";
    [self.contenido addSubview:self.etiquetaAcciones];

    self.etiquetaRecientes = [[UILabel alloc] init];
    self.etiquetaRecientes.text = @"RECIENTES";
    [self.contenido addSubview:self.etiquetaRecientes];

    self.sinRecientes = [[UILabel alloc] init];
    self.sinRecientes.text = @"Aun no has abierto ninguna carpeta.";
    [self.contenido addSubview:self.sinRecientes];

    self.botonInicio = [UIButton buttonWithType:UIButtonTypeCustom];
    self.botonInicio.layer.cornerRadius = 19.0;
    self.botonInicio.layer.masksToBounds = YES;
    self.botonInicio.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    [self.botonInicio addTarget:self action:@selector(abrirCarpetaInicio)
               forControlEvents:UIControlEventTouchUpInside];
    [self.contenido addSubview:self.botonInicio];

    self.botonIr = [UIButton buttonWithType:UIButtonTypeCustom];
    self.botonIr.layer.cornerRadius = 19.0;
    self.botonIr.layer.borderWidth = 1.0;
    self.botonIr.layer.masksToBounds = YES;
    self.botonIr.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    [self.botonIr setTitle:@"Ir a una ruta..." forState:UIControlStateNormal];
    [self.botonIr addTarget:self action:@selector(irARuta)
           forControlEvents:UIControlEventTouchUpInside];
    [self.contenido addSubview:self.botonIr];

    self.botonSistema = [UIButton buttonWithType:UIButtonTypeCustom];
    self.botonSistema.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    [self.botonSistema setTitle:@"Informacion del sistema" forState:UIControlStateNormal];
    [self.botonSistema addTarget:self action:@selector(mostrarSistema)
                forControlEvents:UIControlEventTouchUpInside];
    [self.contenido addSubview:self.botonSistema];
}

- (void)construirAcciones {
    IOTheme *tema = [IOTheme shared];
    self.acciones = @[
        @{ @"t": @"Examinar y limpiar", @"d": @"Libera espacio",
           @"g": @(IOGlyphSearch), @"c": tema.accent, @"k": @"limpiar" },
        @{ @"t": @"Instalar IPA", @"d": @"Paquetes .ipa",
           @"g": @(IOGlyphDownload), @"c": tema.success, @"k": @"ipa" },
        @{ @"t": @"Papelera", @"d": @"Restaurar archivos",
           @"g": @(IOGlyphTrash), @"c": tema.danger, @"k": @"papelera" },
        @{ @"t": @"Favoritos", @"d": @"Tus carpetas",
           @"g": @(IOGlyphStar), @"c": [IOTheme colorWithHex:0xFFB300 alpha:1.0], @"k": @"favoritos" },
        @{ @"t": @"Recientes", @"d": @"Ultimas visitas",
           @"g": @(IOGlyphClock), @"c": [IOTheme colorWithHex:0x5E5CE6 alpha:1.0], @"k": @"recientes" },
        @{ @"t": @"Caches", @"d": @"Datos temporales",
           @"g": @(IOGlyphRefresh), @"c": tema.warning, @"k": @"caches" }
    ];
}

#pragma mark - Datos

- (void)reloadData {
    [self recargar];
}

- (void)recargar {
    self.volumenes = [[IOFileSystem shared] mountedVolumes];
    if (self.volumenes.count == 0) {
        self.volumenes = @[ @{ @"name": @"Sistema", @"path": @"/",
                               @"total": @([[IOFileSystem shared] totalSpaceAtPath:@"/"]),
                               @"free": @([[IOFileSystem shared] freeSpaceAtPath:@"/"]) } ];
    }
    NSArray *recientes = [IOStore shared].recents;
    self.recientes = [recientes subarrayWithRange:
        NSMakeRange(0, MIN((NSUInteger)5, recientes.count))];

    for (UIView *vista in self.tarjetas) { [vista removeFromSuperview]; }
    for (UIView *vista in self.azulejos) { [vista removeFromSuperview]; }
    for (UIView *vista in self.filas) { [vista removeFromSuperview]; }
    [self.tarjetas removeAllObjects];
    [self.azulejos removeAllObjects];
    [self.filas removeAllObjects];

    for (NSUInteger i = 0; i < self.volumenes.count; i++) {
        IOStorageCardView *tarjeta = [[IOStorageCardView alloc] initWithFrame:CGRectZero];
        tarjeta.tag = (NSInteger)i;
        [tarjeta addTarget:self action:@selector(tocarVolumen:)
          forControlEvents:UIControlEventTouchUpInside];
        [tarjeta configurarConVolumen:self.volumenes[i]];
        [self.contenido addSubview:tarjeta];
        [self.tarjetas addObject:tarjeta];
    }

    for (NSUInteger i = 0; i < self.acciones.count; i++) {
        NSDictionary *accion = self.acciones[i];
        IOActionTileView *azulejo = [[IOActionTileView alloc] initWithFrame:CGRectZero];
        azulejo.tag = (NSInteger)i;
        [azulejo configurarConTitulo:accion[@"t"] detalle:accion[@"d"]
                               glifo:(IOGlyph)[accion[@"g"] integerValue]
                               tinte:accion[@"c"]];
        [azulejo addTarget:self action:@selector(tocarAccion:)
          forControlEvents:UIControlEventTouchUpInside];
        [self.contenido addSubview:azulejo];
        [self.azulejos addObject:azulejo];
        if ([accion[@"k"] isEqualToString:@"papelera"]) {
            self.azulejoPapelera = azulejo;
        }
    }

    for (NSUInteger i = 0; i < self.recientes.count; i++) {
        IORecentRowView *fila = [[IORecentRowView alloc] initWithFrame:CGRectZero];
        fila.tag = (NSInteger)i;
        [fila configurarConRuta:self.recientes[i]];
        [fila addTarget:self action:@selector(tocarReciente:)
       forControlEvents:UIControlEventTouchUpInside];
        [self.contenido addSubview:fila];
        [self.filas addObject:fila];
    }

    self.sinRecientes.hidden = (self.recientes.count != 0);

    NSString *inicio = [IOSettings shared].startPath;
    if (inicio.length == 0) { inicio = @"/"; }
    NSString *nombreInicio = [inicio isEqualToString:@"/"] ? @"la raiz"
                                                          : [inicio lastPathComponent];
    [self.botonInicio setTitle:[NSString stringWithFormat:@"Abrir %@", nombreInicio]
                      forState:UIControlStateNormal];

    [self actualizarTamanoPapelera];
    [self aplicarTema];
    [self.view setNeedsLayout];
    [self.refresco endRefreshing];
}

- (void)actualizarTamanoPapelera {
    IOActionTileView *azulejo = self.azulejoPapelera;
    if (!azulejo) { return; }
    __weak IOActionTileView *debil = azulejo;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        unsigned long long tamano = [[IOTrash shared] totalSize];
        dispatch_async(dispatch_get_main_queue(), ^{
            IOActionTileView *fuerte = debil;
            if (!fuerte) { return; }
            fuerte.detalle.text = tamano > 0
                ? [IOHelpers humanSize:tamano]
                : @"Vacia";
        });
    });
}

#pragma mark - Tema

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.view.backgroundColor = tema.background;
    self.scroll.backgroundColor = tema.background;
    self.refresco.tintColor = tema.textSecondary;

    self.tituloNav.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    self.tituloNav.textColor = tema.textPrimary;
    self.subtituloNav.font = [UIFont systemFontOfSize:10.0];
    self.subtituloNav.textColor = tema.textSecondary;
    self.subtituloNav.text = [IOFileSystem shared].isRoot
        ? @"Gestor de archivos · root"
        : @"Gestor de archivos";

    self.tituloGrande.textColor = tema.textPrimary;
    self.tituloGrande.font = [UIFont systemFontOfSize:28.0 weight:UIFontWeightBold];
    self.subtituloGrande.textColor = tema.textSecondary;
    self.subtituloGrande.font = [tema fontSubhead];

    for (UILabel *etiqueta in @[ self.etiquetaVolumenes, self.etiquetaAcciones,
                                 self.etiquetaRecientes ]) {
        etiqueta.textColor = tema.textTertiary;
        etiqueta.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightSemibold];
    }

    self.sinRecientes.textColor = tema.textSecondary;
    self.sinRecientes.font = [tema fontSubhead];

    self.botonInicio.backgroundColor = tema.accentSoft;
    [self.botonInicio setTitleColor:tema.accent forState:UIControlStateNormal];
    self.botonIr.layer.borderColor = tema.separatorStrong.CGColor;
    self.botonIr.backgroundColor = [UIColor clearColor];
    [self.botonIr setTitleColor:tema.textPrimary forState:UIControlStateNormal];
    [self.botonSistema setTitleColor:tema.textTertiary forState:UIControlStateNormal];

    for (IOStorageCardView *tarjeta in self.tarjetas) { [tarjeta aplicarTema]; }
    for (IOActionTileView *azulejo in self.azulejos) { [azulejo aplicarTema]; }
    for (IORecentRowView *fila in self.filas) { [fila aplicarTema]; }
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self colocarContenido];
}

- (void)colocarContenido {
    CGFloat anchoTotal = CGRectGetWidth(self.scroll.bounds);
    CGFloat margen = 16.0;
    CGFloat ancho = anchoTotal - margen * 2.0;
    CGFloat y = 18.0;

    self.tituloGrande.frame = CGRectMake(margen, y, ancho, 34);
    y += 35.0;
    self.subtituloGrande.frame = CGRectMake(margen, y, ancho, 18);
    y += 30.0;

    self.etiquetaVolumenes.frame = CGRectMake(margen, y, ancho, 16);
    y += 24.0;

    for (IOStorageCardView *tarjeta in self.tarjetas) {
        tarjeta.frame = CGRectMake(margen, y, ancho, 112);
        y += 112.0 + 12.0;
    }

    y += 8.0;
    self.etiquetaAcciones.frame = CGRectMake(margen, y, ancho, 16);
    y += 24.0;

    NSInteger columnas = (ancho >= 620.0) ? 3 : 2;
    CGFloat separacion = 12.0;
    CGFloat anchoAzulejo = (ancho - separacion * (columnas - 1)) / columnas;
    for (NSUInteger i = 0; i < self.azulejos.count; i++) {
        NSInteger columna = (NSInteger)i % columnas;
        NSInteger fila = (NSInteger)i / columnas;
        IOActionTileView *azulejo = self.azulejos[i];
        azulejo.frame = CGRectMake(margen + columna * (anchoAzulejo + separacion),
                                   y + fila * (96.0 + separacion),
                                   anchoAzulejo, 96.0);
    }
    NSInteger filas = (self.azulejos.count + columnas - 1) / columnas;
    y += filas * (96.0 + separacion);

    CGFloat anchoInicio = ancho * 0.56;
    self.botonInicio.frame = CGRectMake(margen, y, anchoInicio, 38);
    self.botonIr.frame = CGRectMake(margen + anchoInicio + 10, y,
                                    ancho - anchoInicio - 10, 38);
    y += 38.0 + 18.0;

    self.etiquetaRecientes.frame = CGRectMake(margen, y, ancho, 16);
    y += 24.0;

    for (IORecentRowView *fila in self.filas) {
        fila.frame = CGRectMake(margen, y, ancho, 56);
        y += 56.0 + 10.0;
    }

    if (self.recientes.count == 0) {
        self.sinRecientes.frame = CGRectMake(margen, y, ancho, 40);
        y += 48.0;
    }

    y += 6.0;
    self.botonSistema.frame = CGRectMake(margen, y, ancho, 38);
    y += 38.0 + 28.0;

    self.contenido.frame = CGRectMake(0, 0, anchoTotal, y);
    self.scroll.contentSize = CGSizeMake(anchoTotal, y);
}

#pragma mark - Acciones

- (void)pulsarLateral {
    if (self.onSidebarToggle) { self.onSidebarToggle(); }
}

- (void)abrirAjustes {
    [self.navigationController pushViewController:[[IOSettingsViewController alloc] init]
                                        animated:YES];
}

- (void)tocarVolumen:(IOStorageCardView *)tarjeta {
    NSInteger indice = tarjeta.tag;
    if (indice < 0 || indice >= (NSInteger)self.volumenes.count) { return; }
    [self abrirRuta:self.volumenes[indice][@"path"]];
}

- (void)tocarAccion:(IOActionTileView *)azulejo {
    NSInteger indice = azulejo.tag;
    if (indice < 0 || indice >= (NSInteger)self.acciones.count) { return; }
    NSString *clave = self.acciones[indice][@"k"];

    if ([clave isEqualToString:@"limpiar"]) {
        [self.navigationController pushViewController:
            [[IOAnalyzerViewController alloc] initWithPath:@"/var/mobile"] animated:YES];
    } else if ([clave isEqualToString:@"ipa"]) {
        [self.navigationController pushViewController:
            [[IOInstallViewController alloc] init] animated:YES];
    } else if ([clave isEqualToString:@"papelera"]) {
        [self.navigationController pushViewController:
            [[IOTrashViewController alloc] init] animated:YES];
    } else if ([clave isEqualToString:@"favoritos"]) {
        [self mostrarLista:[IOStore shared].favorites titulo:@"Favoritos"];
    } else if ([clave isEqualToString:@"recientes"]) {
        [self mostrarLista:[IOStore shared].recents titulo:@"Recientes"];
    } else if ([clave isEqualToString:@"caches"]) {
        [self.navigationController pushViewController:
            [[IOAnalyzerViewController alloc] initWithPath:@"/var/mobile/Library/Caches"]
                                             animated:YES];
    }
}

- (void)tocarReciente:(IORecentRowView *)fila {
    NSInteger indice = fila.tag;
    if (indice < 0 || indice >= (NSInteger)self.recientes.count) { return; }
    [self abrirRuta:self.recientes[indice]];
}

- (void)mostrarLista:(NSArray<NSString *> *)rutas titulo:(NSString *)titulo {
    if (rutas.count == 0) {
        [IODialog showAlertIn:self
                        title:titulo
                      message:@"Todavia no hay nada en esta lista."];
        return;
    }
    NSMutableArray *acciones = [NSMutableArray array];
    __weak IOHomeViewController *debil = self;
    NSUInteger limite = MIN(rutas.count, (NSUInteger)25);
    for (NSUInteger i = 0; i < limite; i++) {
        NSString *ruta = rutas[i];
        NSString *nombre = [ruta lastPathComponent];
        if (nombre.length == 0) { nombre = ruta; }
        [acciones addObject:[IODialogAction actionWithTitle:nombre
            style:IODialogActionStyleDefault handler:^{
                [debil abrirRuta:ruta];
            }]];
    }
    [IODialog showSheetIn:self title:titulo actions:acciones];
}

- (void)abrirRuta:(NSString *)ruta {
    if (ruta.length == 0) { return; }
    IOFilesViewController *vc = [[IOFilesViewController alloc] initWithPath:ruta];
    vc.showsSidebarToggle = self.showsSidebarToggle;
    vc.onSidebarToggle = self.onSidebarToggle;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)abrirCarpetaInicio {
    NSString *ruta = [IOSettings shared].startPath;
    if (ruta.length == 0) { ruta = @"/"; }
    BOOL esDir = NO;
    if (![[IOFileSystem shared] fileExistsAtPath:ruta isDirectory:&esDir] || !esDir) {
        ruta = @"/";
    }
    [self abrirRuta:ruta];
}

- (void)irARuta {
    IODialog *dialogo = [IODialog alertWithTitle:@"Ir a una ruta"
                                         message:@"Escribe la ruta completa, por ejemplo /var/mobile/Media."];
    UITextField *campo = [dialogo addTextFieldWithPlaceholder:@"/var/mobile" text:@"/"];
    __weak IOHomeViewController *debil = self;
    [dialogo addAction:@"Cancelar" style:IODialogActionStyleCancel handler:nil];
    [dialogo addAction:@"Ir" style:IODialogActionStyleDefault handler:^{
        NSString *texto = campo.text;
        NSString *limpio = [[IOFileSystem shared] normalizePath:texto];
        BOOL esDir = NO;
        if (![[IOFileSystem shared] fileExistsAtPath:limpio isDirectory:&esDir] || !esDir) {
            [IODialog showAlertIn:debil title:@"Ruta no valida"
                          message:@"Esa carpeta no existe o no es accesible."];
            return;
        }
        [debil abrirRuta:limpio];
    }];
    [dialogo presentIn:self];
}

- (void)mostrarSistema {
    struct utsname info;
    uname(&info);
    NSString *modelo = info.machine[0] ? [NSString stringWithUTF8String:info.machine] : @"iPad";
    UIDevice *dispositivo = [UIDevice currentDevice];
    NSProcessInfo *proceso = [NSProcessInfo processInfo];

    double segundos = proceso.systemUptime;
    int horas = (int)(segundos / 3600.0);
    int minutos = (int)(((long)segundos % 3600) / 60);
    unsigned long long memoria = proceso.physicalMemory;
    unsigned long long libre = [[IOFileSystem shared] freeSpaceAtPath:@"/"];
    uid_t uid = geteuid();

    NSString *mensaje = [NSString stringWithFormat:
        @"%@ · %@ %@\n"
         "Modelo: %@\n"
         "Memoria: %@\n"
         "Encendido: %dh %02dm\n"
         "Usuario: %@ (%u)\n"
         "Libre en /: %@",
        dispositivo.model, dispositivo.systemName, dispositivo.systemVersion,
        modelo,
        [IOHelpers humanSize:memoria],
        horas, minutos,
        (uid == 0 ? @"root" : @"mobile"), (unsigned)uid,
        [IOHelpers humanSize:libre]];

    [IODialog showAlertIn:self title:@"Informacion del sistema" message:mensaje];
}

@end
