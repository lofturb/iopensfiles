#import "IOImageViewController.h"

#import "IOTheme.h"
#import "IOFileIcons.h"
#import "IOHelpers.h"
#import "IODialog.h"

#import <ImageIO/ImageIO.h>

#pragma mark - Pagina con zoom

@interface IOImagePageViewController : UIViewController <UIScrollViewDelegate>
@property (nonatomic, copy) NSString *ruta;
@property (nonatomic, assign) NSInteger indice;
@property (nonatomic, assign) NSInteger total;
@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIImageView *imagenVista;
@property (nonatomic, strong) UILabel *pie;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation IOImagePageViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    self.scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scroll.delegate = self;
    self.scroll.minimumZoomScale = 1.0;
    self.scroll.maximumZoomScale = 5.0;
    self.scroll.showsHorizontalScrollIndicator = NO;
    self.scroll.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scroll];

    self.imagenVista = [[UIImageView alloc] initWithFrame:self.scroll.bounds];
    self.imagenVista.contentMode = UIViewContentModeScaleAspectFit;
    self.imagenVista.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.scroll addSubview:self.imagenVista];

    self.spinner = [[UIActivityIndicatorView alloc]
                    initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.center = self.view.center;
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.spinner];
    [self.spinner startAnimating];

    self.pie = [[UILabel alloc] initWithFrame:CGRectMake(0,
                  CGRectGetHeight(self.view.bounds) - 40, CGRectGetWidth(self.view.bounds), 30)];
    self.pie.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.pie.textAlignment = NSTextAlignmentCenter;
    self.pie.textColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    self.pie.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.pie.text = [NSString stringWithFormat:@"%@   (%ld/%ld)",
                     [self.ruta lastPathComponent], (long)(self.indice + 1), (long)self.total];
    [self.view addSubview:self.pie];

    UITapGestureRecognizer *dobleToco = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(dobleToco:)];
    dobleToco.numberOfTapsRequired = 2;
    [self.scroll addGestureRecognizer:dobleToco];

    [self cargarImagen];
}

- (void)cargarImagen {
    NSString *ruta = self.ruta;
    CGFloat maxPixeles = MAX(CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds));
    __weak IOImagePageViewController *debil = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *imagen = [IOImagePageViewController imagenParaRuta:ruta maxPixeles:maxPixeles];
        dispatch_async(dispatch_get_main_queue(), ^{
            [debil.spinner stopAnimating];
            if (imagen) { debil.imagenVista.image = imagen; }
        });
    });
}

+ (UIImage *)imagenParaRuta:(NSString *)ruta maxPixeles:(CGFloat)maxPixeles {
    CGImageSourceRef fuente = CGImageSourceCreateWithURL(
        (__bridge CFURLRef)[NSURL fileURLWithPath:ruta], NULL);
    if (!fuente) { return nil; }
    CGFloat escala = [UIScreen mainScreen].scale;
    NSDictionary *opciones = @{
        (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
        (id)kCGImageSourceShouldCacheImmediately: @YES,
        (id)kCGImageSourceThumbnailMaxPixelSize: @(maxPixeles * escala)
    };
    CGImageRef cg = CGImageSourceCreateThumbnailAtIndex(fuente, 0,
                                                        (__bridge CFDictionaryRef)opciones);
    CFRelease(fuente);
    if (!cg) { return nil; }
    UIImage *imagen = [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    return imagen;
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imagenVista;
}

- (void)dobleToco:(UITapGestureRecognizer *)gesto {
    if (self.scroll.zoomScale > 1.0) {
        [self.scroll setZoomScale:1.0 animated:YES];
        return;
    }
    CGPoint punto = [gesto locationInView:self.imagenVista];
    [self.scroll zoomToRect:CGRectMake(punto.x - 40, punto.y - 40, 80, 80) animated:YES];
}

@end

#pragma mark - Visor

@interface IOImageViewController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate>
@property (nonatomic, strong) NSArray<NSString *> *rutas;
@property (nonatomic, assign) NSInteger indice;
@property (nonatomic, strong) UIPageViewController *paginas;
@property (nonatomic, strong) UIToolbar *barra;
@property (nonatomic, strong) UIImage *imagenGuardando;
@property (nonatomic, assign) BOOL guardando;
@property (nonatomic, assign) BOOL abrirAjustesTrasGuardar;
@end

@implementation IOImageViewController

- (instancetype)initWithPaths:(NSArray<NSString *> *)paths startIndex:(NSInteger)index {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _rutas = paths.count ? [paths copy] : @[];
        _indice = MAX(0, MIN(index, (NSInteger)_rutas.count - 1));
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.navigationItem.leftBarButtonItem.tintColor = [UIColor whiteColor];

    self.paginas = [[UIPageViewController alloc]
        initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
          navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                        options:nil];
    self.paginas.dataSource = self;
    self.paginas.delegate = self;
    [self addChildViewController:self.paginas];
    self.paginas.view.frame = self.view.bounds;
    self.paginas.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.paginas.view];
    [self.paginas didMoveToParentViewController:self];

    [self construirBarra];
    self.navigationItem.rightBarButtonItem =
        [self itemGlifo:IOGlyphMore accion:@selector(mostrarAcciones)];
    [self actualizarTitulo];

    IOImagePageViewController *primera = [self paginaEnIndice:self.indice];
    if (primera) {
        [self.paginas setViewControllers:@[ primera ]
                               direction:UIPageViewControllerNavigationDirectionForward
                                animated:NO completion:nil];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];
    [self aplicarTema];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat altoBarra = CGRectGetHeight(self.barra.bounds);
    if (altoBarra <= 0) { altoBarra = 44.0; }
    CGFloat alto = CGRectGetHeight(self.view.bounds) - altoBarra;
    self.paginas.view.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), alto);
}

- (UIBarButtonItem *)itemGlifo:(IOGlyph)glifo accion:(SEL)accion {
    UIImage *imagen = [[IOFileIcons shared] glyph:glifo size:22.0
                                            color:[UIColor blackColor]];
    imagen = [imagen imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return [[UIBarButtonItem alloc] initWithImage:imagen
                                            style:UIBarButtonItemStylePlain
                                           target:self
                                           action:accion];
}

- (void)construirBarra {
    self.barra = [[UIToolbar alloc] init];
    self.barra.translatesAutoresizingMaskIntoConstraints = NO;
    self.barra.translucent = NO;
    [self.view addSubview:self.barra];

    UIBarButtonItem *(^flexible)(void) = ^UIBarButtonItem *(void) {
        return [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                 target:nil action:nil];
    };
    self.barra.items = @[
        flexible(),
        [self itemGlifo:IOGlyphShare accion:@selector(accionCompartir)],
        flexible(),
        [self itemGlifo:IOGlyphDownload accion:@selector(accionGuardar)],
        flexible(),
        [self itemGlifo:IOGlyphImage accion:@selector(accionUsarComoFondo)],
        flexible(),
        [self itemGlifo:IOGlyphInfo accion:@selector(accionInformacion)],
        flexible()
    ];

    [self.view addConstraints:@[
        [NSLayoutConstraint constraintWithItem:self.barra attribute:NSLayoutAttributeLeading
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeLeading multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.barra attribute:NSLayoutAttributeTrailing
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeTrailing multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.barra attribute:NSLayoutAttributeBottom
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeBottom multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.barra attribute:NSLayoutAttributeHeight
            relatedBy:NSLayoutRelationEqual toItem:nil
            attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:44]
    ]];
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.barra.barTintColor = tema.elevatedBackground;
    self.barra.tintColor = tema.accent;
    self.barra.translucent = NO;
    self.view.backgroundColor = [UIColor blackColor];
}

- (void)actualizarTitulo {
    if (self.indice < 0 || self.indice >= (NSInteger)self.rutas.count) { return; }
    self.title = [self.rutas[self.indice] lastPathComponent];
}

- (NSString *)rutaActual {
    if (self.indice < 0 || self.indice >= (NSInteger)self.rutas.count) { return nil; }
    return self.rutas[self.indice];
}

#pragma mark - Acciones

- (void)mostrarAcciones {
    __weak IOImageViewController *debil = self;
    NSMutableArray<IODialogAction *> *acciones = [NSMutableArray array];
    [acciones addObject:[IODialogAction actionWithTitle:@"Compartir"
        style:IODialogActionStyleDefault handler:^{ [debil accionCompartir]; }]];
    [acciones addObject:[IODialogAction actionWithTitle:@"Guardar en Fotos"
        style:IODialogActionStyleDefault handler:^{ [debil accionGuardar]; }]];
    [acciones addObject:[IODialogAction actionWithTitle:@"Usar como fondo de pantalla"
        style:IODialogActionStyleDefault handler:^{ [debil accionUsarComoFondo]; }]];
    [acciones addObject:[IODialogAction actionWithTitle:@"Informacion"
        style:IODialogActionStyleDefault handler:^{ [debil accionInformacion]; }]];
    [acciones addObject:[IODialogAction actionWithTitle:@"Cancelar"
        style:IODialogActionStyleCancel handler:nil]];
    [IODialog showSheetIn:self title:@"Opciones de imagen" actions:acciones];
}

- (void)accionCompartir {
    NSString *ruta = [self rutaActual];
    if (!ruta) { return; }
    UIActivityViewController *actividad = [[UIActivityViewController alloc]
        initWithActivityItems:@[ [NSURL fileURLWithPath:ruta] ]
        applicationActivities:nil];
    UIPopoverPresentationController *popover = actividad.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                        CGRectGetMidY(self.view.bounds), 1, 1);
    }
    [self presentViewController:actividad animated:YES completion:nil];
}

- (void)accionGuardar {
    self.abrirAjustesTrasGuardar = NO;
    [self guardarImagenActual];
}

- (void)accionUsarComoFondo {
    self.abrirAjustesTrasGuardar = YES;
    [self guardarImagenActual];
}

- (void)guardarImagenActual {
    if (self.guardando) { return; }
    NSString *ruta = [self rutaActual];
    if (!ruta) { return; }
    UIImage *imagen = [UIImage imageWithContentsOfFile:ruta];
    if (!imagen) {
        [IODialog showAlertIn:self title:@"No se puede guardar"
                      message:@"No se pudo leer la imagen."];
        self.abrirAjustesTrasGuardar = NO;
        return;
    }
    self.guardando = YES;
    self.imagenGuardando = imagen;
    UIImageWriteToSavedPhotosAlbum(imagen, self,
        @selector(imagen:didFinishSavingWithError:contextInfo:), NULL);
}

- (void)imagen:(UIImage *)imagen didFinishSavingWithError:(NSError *)error
    contextInfo:(void *)contextInfo {
    self.guardando = NO;
    self.imagenGuardando = nil;
    if (error) {
        self.abrirAjustesTrasGuardar = NO;
        [IODialog showErrorIn:self error:error];
        return;
    }
    if (self.abrirAjustesTrasGuardar) {
        self.abrirAjustesTrasGuardar = NO;
        [self abrirAjustesDeFondo];
        return;
    }
    [IODialog showAlertIn:self title:@"Imagen guardada"
                  message:@"La imagen se ha guardado en Fotos."];
}

- (void)abrirAjustesDeFondo {
    // iOS no permite fijar el fondo directamente desde una app. Se guarda en
    // Fotos y se lleva al usuario a la seccion de fondo de pantalla de Ajustes.
    NSArray<NSString *> *esquemas = @[
        @"prefs:root=Wallpaper",
        @"App-Prefs:root=Wallpaper",
        @"prefs:root=Wallpaper&path=Wallpaper"
    ];
    for (NSString *texto in esquemas) {
        NSURL *url = [NSURL URLWithString:texto];
        if (url && [[UIApplication sharedApplication] openURL:url]) { return; }
    }
    [IODialog showAlertIn:self title:@"Imagen guardada en Fotos"
                  message:@"Abre Ajustes > Fondo de pantalla y elige esta imagen "
                          @"para la pantalla de bloqueo o de inicio."];
}

- (void)accionInformacion {
    NSString *ruta = [self rutaActual];
    if (!ruta) { return; }

    NSDictionary *atributos = [[NSFileManager defaultManager]
        attributesOfItemAtPath:ruta error:NULL];
    unsigned long long bytes = atributos ? [atributos fileSize] : 0;

    size_t ancho = 0;
    size_t alto = 0;
    CGImageSourceRef fuente = CGImageSourceCreateWithURL(
        (__bridge CFURLRef)[NSURL fileURLWithPath:ruta], NULL);
    if (fuente) {
        NSDictionary *propiedades = (__bridge_transfer NSDictionary *)
            CGImageSourceCopyPropertiesAtIndex(fuente, 0, NULL);
        NSNumber *w = propiedades[(id)kCGImagePropertyPixelWidth];
        NSNumber *h = propiedades[(id)kCGImagePropertyPixelHeight];
        ancho = w.unsignedLongValue;
        alto = h.unsignedLongValue;
        CFRelease(fuente);
    }

    NSString *mensaje = [NSString stringWithFormat:
        @"%@\n\nDimensiones: %lu x %lu px\nTamano: %@\n\n%@",
        [ruta lastPathComponent],
        (unsigned long)ancho, (unsigned long)alto,
        [IOHelpers humanSize:bytes], ruta];
    [IODialog showAlertIn:self title:@"Informacion de la imagen" message:mensaje];
}

- (IOImagePageViewController *)paginaEnIndice:(NSInteger)indice {
    if (indice < 0 || indice >= (NSInteger)self.rutas.count) { return nil; }
    IOImagePageViewController *pagina = [[IOImagePageViewController alloc] init];
    pagina.ruta = self.rutas[indice];
    pagina.indice = indice;
    pagina.total = self.rutas.count;
    return pagina;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
      viewControllerAfterViewController:(UIViewController *)viewController {
    NSInteger indice = ((IOImagePageViewController *)viewController).indice + 1;
    return [self paginaEnIndice:indice];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController
     viewControllerBeforeViewController:(UIViewController *)viewController {
    NSInteger indice = ((IOImagePageViewController *)viewController).indice - 1;
    return [self paginaEnIndice:indice];
}

- (void)pageViewController:(UIPageViewController *)pageViewController
        didFinishAnimating:(BOOL)finished
   previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers
       transitionCompleted:(BOOL)completed {
    if (completed) {
        IOImagePageViewController *actual =
            (IOImagePageViewController *)pageViewController.viewControllers.firstObject;
        self.indice = actual.indice;
        [self actualizarTitulo];
    }
}

@end
