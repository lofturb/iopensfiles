#import "IOImageViewController.h"

#import "IOTheme.h"
#import "IOFileIcons.h"

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

    IOImagePageViewController *primera = [self paginaEnIndice:self.indice];
    if (primera) {
        [self.paginas setViewControllers:@[ primera ]
                               direction:UIPageViewControllerNavigationDirectionForward
                                animated:NO completion:nil];
    }
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
    }
}

@end
