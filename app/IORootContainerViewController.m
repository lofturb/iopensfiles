#import "IORootContainerViewController.h"

#import "IOTheme.h"
#import "IOSettings.h"
#import "IOStore.h"
#import "IOFileSystem.h"
#import "IOFilesViewController.h"
#import "IOSidebarViewController.h"
#import "IOHomeViewController.h"

static const CGFloat IOAnchoLateral = 320.0;
static const CGFloat IOUmbralDiv = 900.0;

@interface IORootContainerViewController () <IOSidebarDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) IOSidebarViewController *lateral;
@property (nonatomic, strong) UINavigationController *navegador;
@property (nonatomic, strong) UIControl *atenuar;
@property (nonatomic, assign) BOOL lateralVisible;
@property (nonatomic, assign) BOOL modoDividido;
@property (nonatomic, assign) BOOL primeraVez;

@end

@implementation IORootContainerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.primeraVez = YES;
    self.view.backgroundColor = [IOTheme shared].background;

    [self construirLateral];
    [self construirNavegador];
    [self construirAtenuar];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(recargarLateral)
            name:@"IOSidebarNeedsReload" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];

    [self actualizarSeleccionLateral];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)construirLateral {
    self.lateral = [[IOSidebarViewController alloc] init];
    self.lateral.delegate = self;
    [self addChildViewController:self.lateral];
    [self.view addSubview:self.lateral.view];
    [self.lateral didMoveToParentViewController:self];
}

- (void)construirNavegador {
    IOSettings *ajustes = [IOSettings shared];

    IOHomeViewController *inicio = [[IOHomeViewController alloc] init];
    inicio.showsSidebarToggle = YES;
    __weak IORootContainerViewController *debil = self;
    inicio.onSidebarToggle = ^{ [debil alternarLateral]; };

    self.navegador = [[UINavigationController alloc] initWithRootViewController:inicio];
    self.navegador.delegate = self;
    self.navegador.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addChildViewController:self.navegador];
    [self.view addSubview:self.navegador.view];
    [self.navegador didMoveToParentViewController:self];

    [self aplicarTemaNavegacion];

    // Si el usuario activo "abrir en la ultima carpeta", se apila encima de la
    // pantalla de inicio: atras siempre vuelve al inicio. La raiz "/" no cuenta
    // como "ultima carpeta" para que el arranque normal muestre Inicio.
    if (ajustes.openAtLastPath && ajustes.lastPath.length &&
        ![ajustes.lastPath isEqualToString:@"/"]) {
        BOOL esDir = NO;
        if ([[IOFileSystem shared] fileExistsAtPath:ajustes.lastPath isDirectory:&esDir] && esDir) {
            IOFilesViewController *vc =
                [[IOFilesViewController alloc] initWithPath:ajustes.lastPath];
            vc.showsSidebarToggle = YES;
            vc.onSidebarToggle = ^{ [debil alternarLateral]; };
            [self.navegador pushViewController:vc animated:NO];
        }
    }
}

- (void)construirAtenuar {
    self.atenuar = [[UIControl alloc] initWithFrame:self.view.bounds];
    self.atenuar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.atenuar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.28];
    self.atenuar.alpha = 0.0;
    self.atenuar.hidden = YES;
    [self.atenuar addTarget:self action:@selector(cerrarLateral)
           forControlEvents:UIControlEventTouchUpInside];
    [self.view insertSubview:self.atenuar aboveSubview:self.navegador.view];

    // El lateral debe quedar por encima del contenido cuando se superpone.
    [self.view bringSubviewToFront:self.lateral.view];
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.view.backgroundColor = tema.background;
    [self aplicarTemaNavegacion];
    [self aplicarLayout:NO];
}

- (void)aplicarTemaNavegacion {
    IOTheme *tema = [IOTheme shared];
    UINavigationBar *barraNav = self.navegador.navigationBar;
    barraNav.translucent = NO;
    barraNav.barTintColor = tema.cardBackground;
    barraNav.tintColor = tema.accent;
    barraNav.barStyle = tema.dark ? UIBarStyleBlack : UIBarStyleDefault;
    barraNav.titleTextAttributes = @{ NSForegroundColorAttributeName: tema.textPrimary };
    [barraNav setNeedsLayout];
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self aplicarLayout:NO];
}

- (void)aplicarLayout:(BOOL)animado {
    CGFloat ancho = self.view.bounds.size.width;
    CGFloat alto = self.view.bounds.size.height;
    BOOL dividido = (ancho >= IOUmbralDiv);
    self.modoDividido = dividido;

    CGFloat lado = MIN(IOAnchoLateral, dividido ? ancho * 0.38 : ancho * 0.86);

    if (self.primeraVez) {
        self.lateralVisible = dividido;
        self.primeraVez = NO;
    }

    CGFloat xLateral = self.lateralVisible ? 0.0 : -lado;
    CGRect marcoLateral = CGRectMake(xLateral, 0, lado, alto);

    CGRect marcoContenido;
    if (dividido && self.lateralVisible) {
        marcoContenido = CGRectMake(lado, 0, ancho - lado, alto);
    } else {
        marcoContenido = CGRectMake(0, 0, ancho, alto);
    }

    BOOL mostrarAtenuar = (!dividido && self.lateralVisible);
    self.atenuar.hidden = !mostrarAtenuar;
    [self.view bringSubviewToFront:self.lateral.view];

    void (^cambios)(void) = ^{
        self.lateral.view.frame = marcoLateral;
        self.navegador.view.frame = marcoContenido;
        self.atenuar.alpha = mostrarAtenuar ? 1.0 : 0.0;
    };

    if (animado) {
        self.atenuar.hidden = NO;
        [UIView animateWithDuration:0.24 delay:0
             options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            cambios();
        } completion:^(BOOL terminado) {
            self.atenuar.hidden = !mostrarAtenuar;
        }];
    } else {
        cambios();
        self.atenuar.hidden = !mostrarAtenuar;
    }

    // Sombra del lateral cuando se superpone.
    self.lateral.view.layer.shadowColor = [UIColor blackColor].CGColor;
    self.lateral.view.layer.shadowOpacity = mostrarAtenuar ? 0.25 : 0.0;
    self.lateral.view.layer.shadowRadius = 18.0;
    self.lateral.view.layer.shadowOffset = CGSizeMake(2, 0);
}

- (void)alternarLateral {
    self.lateralVisible = !self.lateralVisible;
    [self aplicarLayout:YES];
}

- (void)cerrarLateral {
    if (self.modoDividido) { return; }
    self.lateralVisible = NO;
    [self aplicarLayout:YES];
}

#pragma mark - IOSidebarDelegate

- (void)sidebar:(IOSidebarViewController *)sidebar didSelectPath:(NSString *)path {
    [self.navegador popToRootViewControllerAnimated:NO];
    IOFilesViewController *vc = [[IOFilesViewController alloc] initWithPath:path];
    vc.showsSidebarToggle = YES;
    __weak IORootContainerViewController *debil = self;
    vc.onSidebarToggle = ^{ [debil alternarLateral]; };
    [self.navegador pushViewController:vc animated:YES];

    [IOSettings shared].lastPath = path;
    self.lateral.selectedPath = path;
    [self.lateral reloadData];

    if (!self.modoDividido) {
        self.lateralVisible = NO;
        [self aplicarLayout:YES];
    }
}

- (void)sidebarDidSelectHome:(IOSidebarViewController *)sidebar {
    // Inicio es la raiz del navegador: basta con volver al primer controlador.
    [self.navegador popToRootViewControllerAnimated:YES];
    self.lateral.selectedPath = nil;
    [self.lateral reloadData];

    if (!self.modoDividido) {
        self.lateralVisible = NO;
        [self aplicarLayout:YES];
    }
}

- (void)recargarLateral {
    [self.lateral reloadData];
}

- (void)actualizarSeleccionLateral {
    UIViewController *superior = self.navegador.topViewController;
    if ([superior isKindOfClass:[IOFilesViewController class]]) {
        NSString *ruta = ((IOFilesViewController *)superior).path;
        self.lateral.selectedPath = ruta;
    } else {
        self.lateral.selectedPath = nil;
    }
    [self.lateral reloadData];
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ([viewController isKindOfClass:[IOFilesViewController class]]) {
        NSString *ruta = ((IOFilesViewController *)viewController).path;
        self.lateral.selectedPath = ruta;
        [IOSettings shared].lastPath = ruta;
        [[IOStore shared] addRecent:ruta];
        [self.lateral reloadData];
    } else if ([viewController isKindOfClass:[IOHomeViewController class]]) {
        self.lateral.selectedPath = nil;
        [self.lateral reloadData];
    }
}

@end
