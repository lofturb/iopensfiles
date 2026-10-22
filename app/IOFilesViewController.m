#import "IOFilesViewController.h"

#import "IOTheme.h"
#import "IOSettings.h"
#import "IOHelpers.h"
#import "IOFileItem.h"
#import "IOFileSystem.h"
#import "IOArchive.h"
#import "IOStore.h"
#import "IOFileIcons.h"
#import "IOFileCell.h"
#import "IOProgressHUD.h"
#import "IOPropertiesViewController.h"
#import "IOTextEditorViewController.h"
#import "IOImageViewController.h"
#import "IOMediaPlayerViewController.h"
#import "IOSettingsViewController.h"

#pragma mark - Token de cancelacion

@interface IOCancelToken : NSObject
@property (atomic, assign) BOOL cancelled;
@end
@implementation IOCancelToken
@end

#pragma mark -

@interface IOFilesViewController () <UITableViewDataSource, UITableViewDelegate,
                                      UISearchResultsUpdating, UIDocumentInteractionControllerDelegate>

@property (nonatomic, strong) UITableView *tabla;
@property (nonatomic, strong) UIToolbar *barra;
@property (nonatomic, strong) UILabel *estadoVacio;
@property (nonatomic, strong) NSArray<IOFileItem *> *items;
@property (nonatomic, strong) UISearchController *buscador;
@property (nonatomic, strong) UIDocumentInteractionController *docController;

@property (nonatomic, strong) NSMutableArray<IOFileItem *> *seleccionados;
@property (nonatomic, assign) BOOL modoSeleccion;

// Busqueda recursiva
@property (nonatomic, copy) NSString *consulta;
@property (nonatomic, assign) BOOL buscando;
@property (nonatomic, assign) NSInteger generacionBusqueda;
@property (nonatomic, strong) dispatch_queue_t colaBusqueda;

// Orden / refresco en curso
@property (nonatomic, assign) NSInteger generacionCarga;

@end

@implementation IOFilesViewController

#pragma mark - Ciclo de vida

- (instancetype)initWithPath:(NSString *)path {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _path = [[IOFileSystem shared] normalizePath:path];
        _items = @[];
        _seleccionados = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    IOTheme *tema = [IOTheme shared];
    self.view.backgroundColor = tema.background;
    self.colaBusqueda = dispatch_queue_create("com.lofturb.iopensfiles.search",
                                              DISPATCH_QUEUE_SERIAL);

    [self construirTabla];
    [self construirEstadoVacio];
    [self construirBuscador];
    [self construirBarras];
    [self configurarGestos];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];

    [self actualizarTitulo];
    [self reloadContents];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadContents];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (self.buscador) { self.buscador.view.hidden = YES; }
}

#pragma mark - Construccion de la interfaz

- (void)construirTabla {
    self.tabla = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tabla.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabla.dataSource = self;
    self.tabla.delegate = self;
    self.tabla.rowHeight = [IOTheme shared].rowHeight;
    self.tabla.separatorInset = UIEdgeInsetsMake(0, 70, 0, 0);
    self.tabla.allowsMultipleSelectionDuringEditing = YES;
    self.tabla.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    // Deja hueco para la barra inferior.
    self.tabla.contentInset = UIEdgeInsetsMake(0, 0, 48, 0);
    self.tabla.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 48, 0);
    self.tabla.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.tabla registerClass:[IOFileCell class] forCellReuseIdentifier:@"archivo"];
    [self.view addSubview:self.tabla];

    [self.view addConstraints:@[
        [NSLayoutConstraint constraintWithItem:self.tabla attribute:NSLayoutAttributeTop
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeTop multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.tabla attribute:NSLayoutAttributeLeading
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeLeading multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.tabla attribute:NSLayoutAttributeTrailing
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeTrailing multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.tabla attribute:NSLayoutAttributeBottom
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeBottom multiplier:1 constant:0]
    ]];
}

- (void)construirEstadoVacio {
    self.estadoVacio = [[UILabel alloc] init];
    self.estadoVacio.translatesAutoresizingMaskIntoConstraints = NO;
    self.estadoVacio.numberOfLines = 0;
    self.estadoVacio.textAlignment = NSTextAlignmentCenter;
    self.estadoVacio.hidden = YES;
    [self.view addSubview:self.estadoVacio];
    [self.view addConstraints:@[
        [NSLayoutConstraint constraintWithItem:self.estadoVacio attribute:NSLayoutAttributeCenterX
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeCenterX multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.estadoVacio attribute:NSLayoutAttributeCenterY
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeCenterY multiplier:1 constant:-40],
        [NSLayoutConstraint constraintWithItem:self.estadoVacio attribute:NSLayoutAttributeWidth
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeWidth multiplier:0.7 constant:0]
    ]];
}

- (void)construirBuscador {
    self.buscador = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.buscador.searchResultsUpdater = self;
    self.buscador.dimsBackgroundDuringPresentation = NO;
    self.buscador.searchBar.placeholder = @"Buscar (recursivo)";
    self.buscador.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.definesPresentationContext = YES;
    UISearchBar *barraBusqueda = self.buscador.searchBar;
    barraBusqueda.frame = CGRectMake(0, 0, self.view.bounds.size.width, 44);
    barraBusqueda.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.tabla.tableHeaderView = barraBusqueda;
}

- (void)construirBarras {
    // Boton derecho: menu.
    UIBarButtonItem *menu = [self itemGlifo:IOGlyphMore accion:@selector(presentarMenu:)];
    self.navigationItem.rightBarButtonItem = menu;

    if (self.showsSidebarToggle) {
        UIBarButtonItem *lateral = [self itemGlifo:IOGlyphMenu
                                            accion:@selector(pulsarLateral)];
        self.navigationItem.leftBarButtonItem = lateral;
    }

    self.barra = [[UIToolbar alloc] init];
    self.barra.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.barra];
    [self.view addConstraints:@[
        [NSLayoutConstraint constraintWithItem:self.barra attribute:NSLayoutAttributeLeading
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeLeading multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.barra attribute:NSLayoutAttributeTrailing
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeTrailing multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.barra attribute:NSLayoutAttributeBottom
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeBottom multiplier:1 constant:0]
    ]];
    [self actualizarBarra];
}

- (UIBarButtonItem *)itemGlifo:(IOGlyph)glifo accion:(SEL)accion {
    UIImage *imagen = [[IOFileIcons shared] glyph:glifo size:22.0
                                            color:[UIColor blackColor]];
    imagen = [imagen imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:imagen
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:accion];
    return item;
}

- (UIBarButtonItem *)flexible {
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                         target:nil action:nil];
}

- (void)configurarGestos {
    UILongPressGestureRecognizer *largo =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(pulsacionLarga:)];
    [self.tabla addGestureRecognizer:largo];
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.view.backgroundColor = tema.background;
    self.tabla.backgroundColor = tema.background;
    self.tabla.separatorColor = tema.separator;
    self.barra.barTintColor = tema.cardBackground;
    self.barra.tintColor = tema.accent;
    self.barra.barStyle = tema.dark ? UIBarStyleBlack : UIBarStyleDefault;
    self.estadoVacio.textColor = tema.textSecondary;
    self.estadoVacio.font = [tema fontBody];
    [self.tabla reloadData];
}

#pragma mark - Ruta y titulo

- (void)setPath:(NSString *)path {
    _path = [[IOFileSystem shared] normalizePath:path];
    [self actualizarTitulo];
    [self reloadContents];
}

- (void)actualizarTitulo {
    NSString *nombre = [self.path lastPathComponent];
    if (nombre.length == 0) { nombre = @"Raiz"; }

    UILabel *titulo = [[UILabel alloc] init];
    titulo.text = nombre;
    titulo.font = [IOTheme shared].fontNavTitle;
    titulo.textColor = [IOTheme shared].textPrimary;
    titulo.textAlignment = NSTextAlignmentCenter;

    UILabel *subtitulo = [[UILabel alloc] init];
    subtitulo.text = self.path;
    subtitulo.font = [UIFont systemFontOfSize:11.0];
    subtitulo.textColor = [IOTheme shared].textSecondary;
    subtitulo.textAlignment = NSTextAlignmentCenter;
    subtitulo.lineBreakMode = NSLineBreakByTruncatingMiddle;

    UIView *contenedor = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 40)];
    titulo.frame = CGRectMake(0, 0, 220, 22);
    subtitulo.frame = CGRectMake(0, 20, 220, 14);
    [contenedor addSubview:titulo];
    [contenedor addSubview:subtitulo];
    self.navigationItem.titleView = contenedor;
}

#pragma mark - Carga de contenido

- (void)reloadContents {
    NSString *ruta = self.path;
    self.generacionCarga++;
    NSInteger generacion = self.generacionCarga;

    __weak IOFilesViewController *debil = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSArray *items = [[IOFileSystem shared] contentsOfDirectory:ruta error:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            IOFilesViewController *fuerte = debil;
            if (!fuerte || generacion != fuerte.generacionCarga) { return; }
            if (![fuerte.path isEqualToString:ruta]) { return; }
            if (!items) {
                fuerte.items = @[];
                fuerte.estadoVacio.text = [NSString stringWithFormat:
                    @"No se pudo leer la carpeta.\n%@",
                    error.localizedDescription ?: @""];
                fuerte.estadoVacio.hidden = NO;
            } else {
                fuerte.items = [fuerte ordenarYFiltrar:items];
                fuerte.estadoVacio.text = @"Esta carpeta esta vacia";
                fuerte.estadoVacio.hidden = (fuerte.items.count != 0);
            }
            [fuerte.tabla reloadData];
            [fuerte actualizarBarra];
        });
    });
}

- (NSArray<IOFileItem *> *)ordenarYFiltrar:(NSArray<IOFileItem *> *)items {
    IOSettings *ajustes = [IOSettings shared];
    NSMutableArray *filtrados = [NSMutableArray arrayWithCapacity:items.count];
    for (IOFileItem *item in items) {
        if (!ajustes.showHidden && item.isHidden) { continue; }
        [filtrados addObject:item];
    }

    IOSortKey clave = ajustes.sortKey;
    BOOL ascendente = ajustes.sortAscending;
    BOOL carpetasPrimero = ajustes.foldersFirst;

    [filtrados sortUsingComparator:^NSComparisonResult(IOFileItem *a, IOFileItem *b) {
        if (carpetasPrimero && a.isDirectory != b.isDirectory) {
            return a.isDirectory ? NSOrderedAscending : NSOrderedDescending;
        }
        NSComparisonResult resultado = NSOrderedSame;
        switch (clave) {
            case IOSortByDate:
                resultado = [a.modificationDate compare:b.modificationDate];
                break;
            case IOSortBySize:
                if (a.size < b.size) { resultado = NSOrderedAscending; }
                else if (a.size > b.size) { resultado = NSOrderedDescending; }
                break;
            case IOSortByKind: {
                NSString *ka = [a kindDescription];
                NSString *kb = [b kindDescription];
                resultado = [ka localizedCaseInsensitiveCompare:kb];
                if (resultado == NSOrderedSame) {
                    resultado = [a.name localizedCaseInsensitiveCompare:b.name];
                }
                break;
            }
            case IOSortByName:
            default:
                resultado = [a.name localizedCaseInsensitiveCompare:b.name];
                break;
        }
        return ascendente ? resultado : (NSComparisonResult)(-resultado);
    }];
    return filtrados;
}

#pragma mark - Tabla: datos

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IOFileCell *celda = [tableView dequeueReusableCellWithIdentifier:@"archivo"
                                                       forIndexPath:indexPath];
    IOFileItem *item = self.items[indexPath.row];
    [celda aplicarTema];
    [celda configurarConItem:item];
    return celda;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.modoSeleccion) {
        [self.seleccionados addObject:self.items[indexPath.row]];
        [self actualizarBarra];
        return;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self abrirItem:self.items[indexPath.row]];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.modoSeleccion) { return; }
    IOFileItem *item = self.items[indexPath.row];
    [self.seleccionados removeObject:item];
    [self actualizarBarra];
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView
                  editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.modoSeleccion) { return nil; }
    IOFileItem *item = self.items[indexPath.row];
    __weak IOFilesViewController *debil = self;

    UITableViewRowAction *borrar = [UITableViewRowAction
        rowActionWithStyle:UITableViewRowActionStyleDestructive
                     title:@"Borrar"
                   handler:^(UITableViewRowAction *accion, NSIndexPath *indice) {
        [debil confirmarBorradoDeItems:@[ item ]];
    }];

    UITableViewRowAction *mas = [UITableViewRowAction
        rowActionWithStyle:UITableViewRowActionStyleNormal
                     title:@"Mas"
                   handler:^(UITableViewRowAction *accion, NSIndexPath *indice) {
        [debil.tabla setEditing:NO animated:YES];
        [debil presentarAccionesParaItem:item desdeIndice:indice];
    }];
    mas.backgroundColor = [IOTheme colorWithHex:0x8E8E93 alpha:1.0];

    UITableViewRowAction *renombrar = [UITableViewRowAction
        rowActionWithStyle:UITableViewRowActionStyleNormal
                     title:@"Renombrar"
                   handler:^(UITableViewRowAction *accion, NSIndexPath *indice) {
        [debil.tabla setEditing:NO animated:YES];
        [debil preguntarRenombrar:item];
    }];
    renombrar.backgroundColor = [IOTheme shared].accent;

    return @[ borrar, mas, renombrar ];
}

- (void)pulsacionLarga:(UILongPressGestureRecognizer *)gesto {
    if (gesto.state != UIGestureRecognizerStateBegan || self.modoSeleccion) { return; }
    CGPoint punto = [gesto locationInView:self.tabla];
    NSIndexPath *indice = [self.tabla indexPathForRowAtPoint:punto];
    if (!indice || indice.row >= (NSInteger)self.items.count) { return; }
    [self presentarAccionesParaItem:self.items[indice.row] desdeIndice:indice];
}

#pragma mark - Busqueda

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *texto = searchController.searchBar.text;
    if (texto.length < 2) {
        self.buscando = NO;
        self.generacionBusqueda++;
        [self reloadContents];
        return;
    }
    self.buscando = YES;
    self.consulta = texto;
    self.generacionBusqueda++;
    NSInteger generacion = self.generacionBusqueda;
    NSString *base = self.path;
    NSString *aguja = [texto lowercaseString];

    __weak IOFilesViewController *debil = self;
    dispatch_async(self.colaBusqueda, ^{
        NSMutableArray<IOFileItem *> *resultados = [NSMutableArray array];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSDirectoryEnumerator *enumerador =
            [fm enumeratorAtURL:[NSURL fileURLWithPath:base]
             includingPropertiesForKeys:nil
                                options:0
                           errorHandler:nil];
        for (NSURL *url in enumerador) {
            if (resultados.count >= 500) { break; }
            NSString *nombre = url.lastPathComponent;
            if ([nombre.lowercaseString rangeOfString:aguja].location == NSNotFound) {
                continue;
            }
            IOFileItem *item = [IOFileItem itemAtPath:url.path];
            if (item) { [resultados addObject:item]; }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            IOFilesViewController *fuerte = debil;
            if (!fuerte || generacion != fuerte.generacionBusqueda) { return; }
            fuerte.items = resultados;
            fuerte.estadoVacio.text = @"Sin resultados";
            fuerte.estadoVacio.hidden = (resultados.count != 0);
            [fuerte.tabla reloadData];
        });
    });
}

#pragma mark - Barra inferior

- (void)actualizarBarra {
    IOTheme *tema = [IOTheme shared];
    self.barra.barTintColor = tema.cardBackground;
    self.barra.tintColor = tema.accent;

    if (self.modoSeleccion) {
        NSUInteger n = self.seleccionados.count;
        UIBarButtonItem *compartir = [self itemGlifo:IOGlyphShare accion:@selector(accionCompartir)];
        UIBarButtonItem *copiar = [self itemGlifo:IOGlyphCopy accion:@selector(accionCopiarSeleccion)];
        UIBarButtonItem *mover = [self itemGlifo:IOGlyphPaste accion:@selector(accionCortarSeleccion)];
        UIBarButtonItem *comprimir = [self itemGlifo:IOGlyphArchive accion:@selector(accionComprimirSeleccion)];
        UIBarButtonItem *borrar = [self itemGlifo:IOGlyphTrash accion:@selector(accionBorrarSeleccion)];
        borrar.tintColor = tema.danger;
        compartir.enabled = (n > 0);
        copiar.enabled = (n > 0);
        mover.enabled = (n > 0);
        comprimir.enabled = (n > 0);
        borrar.enabled = (n > 0);
        self.barra.items = @[ compartir, [self flexible], copiar, [self flexible],
                              mover, [self flexible], comprimir, [self flexible], borrar ];
        self.navigationItem.title = [NSString stringWithFormat:@"%lu seleccionados", (unsigned long)n];
    } else {
        UIBarButtonItem *nuevaCarpeta = [self itemGlifo:IOGlyphNewFolder accion:@selector(accionNuevaCarpeta)];
        UIBarButtonItem *nuevoArchivo = [self itemGlifo:IOGlyphNewFile accion:@selector(accionNuevoArchivo)];
        UIBarButtonItem *pegar = [self itemGlifo:IOGlyphPaste accion:@selector(accionPegar)];
        UIBarButtonItem *ordenar = [self itemGlifo:IOGlyphFilter accion:@selector(presentarOrdenar:)];
        UIBarButtonItem *seleccionar = [self itemGlifo:IOGlyphSelect accion:@selector(activarSeleccion)];

        IOClipboard *porta = [IOClipboard shared];
        pegar.enabled = porta.hasItems;

        self.barra.items = @[ nuevaCarpeta, [self flexible], nuevoArchivo, [self flexible],
                              pegar, [self flexible], ordenar, [self flexible], seleccionar ];
        [self actualizarTitulo];
    }
}

#pragma mark - Modo seleccion

- (void)activarSeleccion {
    self.modoSeleccion = YES;
    [self.seleccionados removeAllObjects];
    self.tabla.editing = YES;
    UIBarButtonItem *cancelar = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                             target:self action:@selector(desactivarSeleccion)];
    self.navigationItem.rightBarButtonItem = cancelar;
    self.buscador.searchBar.hidden = YES;
    [self actualizarBarra];
}

- (void)desactivarSeleccion {
    self.modoSeleccion = NO;
    [self.seleccionados removeAllObjects];
    self.tabla.editing = NO;
    self.navigationItem.rightBarButtonItem = [self itemGlifo:IOGlyphMore
                                                      accion:@selector(presentarMenu:)];
    self.buscador.searchBar.hidden = NO;
    [self.tabla reloadData];
    [self actualizarBarra];
}

#pragma mark - Abrir elementos

- (void)abrirItem:(IOFileItem *)item {
    if (item.isDirectory) {
        IOFilesViewController *vc = [[IOFilesViewController alloc] initWithPath:item.path];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if ([IOHelpers isTextFile:item.path] || [IOHelpers isPlistFile:item.path]) {
        IOTextEditorViewController *vc =
            [[IOTextEditorViewController alloc] initWithPath:item.path];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if ([IOHelpers isImageFile:item.path]) {
        NSArray *imagenes = [self rutasDeImagenesEnCarpetaActual];
        NSInteger indice = [imagenes indexOfObject:item.path];
        IOImageViewController *vc = [[IOImageViewController alloc]
                                      initWithPaths:imagenes
                                         startIndex:(indice == NSNotFound ? 0 : indice)];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if ([IOHelpers isVideoFile:item.path] || [IOHelpers isAudioFile:item.path]) {
        IOMediaPlayerViewController *vc =
            [[IOMediaPlayerViewController alloc] initWithPath:item.path];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if ([IOHelpers isArchiveFile:item.path]) {
        [self presentarAccionesParaItem:item desdeIndice:nil];
        return;
    }
    [self compartirRuta:item.path desdeRect:CGRectMake(CGRectGetMidX(self.view.bounds),
                                                       CGRectGetMidY(self.view.bounds), 1, 1)];
}

- (NSArray<NSString *> *)rutasDeImagenesEnCarpetaActual {
    NSMutableArray *rutas = [NSMutableArray array];
    for (IOFileItem *item in self.items) {
        if (!item.isDirectory && [IOHelpers isImageFile:item.path]) {
            [rutas addObject:item.path];
        }
    }
    return rutas;
}

#pragma mark - Menu principal

- (void)presentarMenu:(id)origen {
    IOSettings *ajustes = [IOSettings shared];
    UIAlertController *hoja = [UIAlertController
        alertControllerWithTitle:nil
                         message:self.path
                  preferredStyle:UIAlertControllerStyleActionSheet];

    [hoja addAction:[UIAlertAction actionWithTitle:@"Ordenar..." style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) { [self presentarOrdenar:nil]; }]];

    NSString *marcaOcultos = ajustes.showHidden ? @"Ocultar archivos ocultos"
                                                : @"Mostrar archivos ocultos";
    [hoja addAction:[UIAlertAction actionWithTitle:marcaOcultos style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            ajustes.showHidden = !ajustes.showHidden;
            [self reloadContents];
        }]];

    NSString *marcaDetalles = ajustes.showDetails ? @"Ocultar detalles"
                                                  : @"Mostrar detalles";
    [hoja addAction:[UIAlertAction actionWithTitle:marcaDetalles style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            ajustes.showDetails = !ajustes.showDetails;
            [self.tabla reloadData];
        }]];

    NSString *marcaFav = [[IOStore shared] isFavorite:self.path]
        ? @"Quitar de favoritos" : @"Anadir a favoritos";
    [hoja addAction:[UIAlertAction actionWithTitle:marcaFav style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            [[IOStore shared] toggleFavorite:self.path];
            [[NSNotificationCenter defaultCenter]
                postNotificationName:@"IOSidebarNeedsReload" object:nil];
        }]];

    [hoja addAction:[UIAlertAction actionWithTitle:@"Ir a la raiz" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) { self.path = @"/"; }]];

    [hoja addAction:[UIAlertAction actionWithTitle:@"Ajustes" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            IOSettingsViewController *vc = [[IOSettingsViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }]];

    [hoja addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel
        handler:nil]];

    [self presentarHoja:hoja desdeOrigen:origen];
}

- (void)presentarOrdenar:(id)origen {
    IOSettings *ajustes = [IOSettings shared];
    UIAlertController *hoja = [UIAlertController
        alertControllerWithTitle:@"Ordenar por"
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *opciones = @[ @[ @"Nombre", @(IOSortByName) ],
                           @[ @"Tipo", @(IOSortByKind) ],
                           @[ @"Fecha", @(IOSortByDate) ],
                           @[ @"Tamano", @(IOSortBySize) ] ];
    for (NSArray *opcion in opciones) {
        NSString *titulo = opcion[0];
        IOSortKey clave = (IOSortKey)[opcion[1] integerValue];
        NSString *prefijo = (ajustes.sortKey == clave) ? @"\u2713 " : @"";
        [hoja addAction:[UIAlertAction
            actionWithTitle:[prefijo stringByAppendingString:titulo]
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *a) {
            ajustes.sortKey = clave;
            [self reloadContents];
        }]];
    }

    NSString *sentido = ajustes.sortAscending ? @"Descendente" : @"Ascendente";
    [hoja addAction:[UIAlertAction actionWithTitle:sentido style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            ajustes.sortAscending = !ajustes.sortAscending;
            [self reloadContents];
        }]];

    NSString *carpetas = ajustes.foldersFirst ? @"Archivos antes que carpetas"
                                              : @"Carpetas antes que archivos";
    [hoja addAction:[UIAlertAction actionWithTitle:carpetas style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            ajustes.foldersFirst = !ajustes.foldersFirst;
            [self reloadContents];
        }]];

    [hoja addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel
        handler:nil]];

    [self presentarHoja:hoja desdeOrigen:origen];
}

- (void)presentarHoja:(UIAlertController *)hoja desdeOrigen:(id)origen {
    UIPopoverPresentationController *popover = hoja.popoverPresentationController;
    if (popover) {
        if ([origen isKindOfClass:[UIView class]]) {
            popover.sourceView = origen;
            popover.sourceRect = ((UIView *)origen).bounds;
        } else if ([origen isKindOfClass:[UIBarButtonItem class]]) {
            popover.barButtonItem = origen;
        } else {
            popover.sourceView = self.view;
            popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                            CGRectGetMidY(self.view.bounds), 1, 1);
        }
    }
    [self presentViewController:hoja animated:YES completion:nil];
}

#pragma mark - Acciones sobre un elemento

- (void)presentarAccionesParaItem:(IOFileItem *)item desdeIndice:(NSIndexPath *)indice {
    UIAlertController *hoja = [UIAlertController
        alertControllerWithTitle:item.name
                         message:[item kindDescription]
                  preferredStyle:UIAlertControllerStyleActionSheet];

    BOOL previsualizable = (!item.isDirectory &&
        ([IOHelpers isImageFile:item.path] || [IOHelpers isVideoFile:item.path] ||
         [IOHelpers isAudioFile:item.path] || [IOHelpers isTextFile:item.path] ||
         [IOHelpers isPlistFile:item.path]));

    if (previsualizable) {
        [hoja addAction:[UIAlertAction actionWithTitle:@"Abrir" style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *a) { [self abrirItem:item]; }]];
    }
    if (item.isDirectory) {
        [hoja addAction:[UIAlertAction actionWithTitle:@"Abrir" style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *a) { [self abrirItem:item]; }]];
    }

    [hoja addAction:[UIAlertAction actionWithTitle:@"Copiar" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            [[IOClipboard shared] setPaths:@[ item.path ] cut:NO];
            [self actualizarBarra];
        }]];
    [hoja addAction:[UIAlertAction actionWithTitle:@"Cortar" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            [[IOClipboard shared] setPaths:@[ item.path ] cut:YES];
            [self actualizarBarra];
        }]];
    [hoja addAction:[UIAlertAction actionWithTitle:@"Renombrar" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) { [self preguntarRenombrar:item]; }]];
    [hoja addAction:[UIAlertAction actionWithTitle:@"Duplicar" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) { [self duplicarItem:item]; }]];
    [hoja addAction:[UIAlertAction actionWithTitle:@"Comprimir (ZIP)" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) { [self comprimirRutas:@[ item.path ]]; }]];

    if ([IOHelpers isArchiveFile:item.path]) {
        [hoja addAction:[UIAlertAction actionWithTitle:@"Extraer aqui" style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *a) { [self extraerArchivo:item.path enCarpetaNueva:NO]; }]];
        [hoja addAction:[UIAlertAction actionWithTitle:@"Extraer en carpeta nueva"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *a) { [self extraerArchivo:item.path enCarpetaNueva:YES]; }]];
        [hoja addAction:[UIAlertAction actionWithTitle:@"Ver contenido" style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *a) { [self verContenidoDeArchivo:item]; }]];
    }

    NSString *compartir = @"Compartir / Abrir con";
    [hoja addAction:[UIAlertAction actionWithTitle:compartir style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) { [self compartirItem:item desdeIndice:indice]; }]];

    NSString *fav = [[IOStore shared] isFavorite:item.path]
        ? @"Quitar de favoritos" : @"Anadir a favoritos";
    [hoja addAction:[UIAlertAction actionWithTitle:fav style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            [[IOStore shared] toggleFavorite:item.path];
            [[NSNotificationCenter defaultCenter]
                postNotificationName:@"IOSidebarNeedsReload" object:nil];
        }]];

    [hoja addAction:[UIAlertAction actionWithTitle:@"Propiedades" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            IOPropertiesViewController *vc =
                [[IOPropertiesViewController alloc] initWithPath:item.path];
            [self.navigationController pushViewController:vc animated:YES];
        }]];

    [hoja addAction:[UIAlertAction actionWithTitle:@"Borrar" style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *a) { [self confirmarBorradoDeItems:@[ item ]]; }]];

    [hoja addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel
        handler:nil]];

    [self presentarHoja:hoja desdeOrigen:(indice ? [self.tabla cellForRowAtIndexPath:indice] : nil)];
}

#pragma mark - Operaciones: crear

- (void)accionNuevaCarpeta {
    [self preguntarNombre:@"Nueva carpeta" valor:@"Sin titulo" accion:^(NSString *nombre) {
        [self crearCarpeta:nombre];
    }];
}

- (void)accionNuevoArchivo {
    [self preguntarNombre:@"Nuevo archivo" valor:@"Nuevo.txt" accion:^(NSString *nombre) {
        [self crearArchivo:nombre];
    }];
}

- (void)preguntarNombre:(NSString *)titulo valor:(NSString *)valor
                 accion:(void (^)(NSString *nombre))accion {
    UIAlertController *alerta = [UIAlertController
        alertControllerWithTitle:titulo message:nil
                  preferredStyle:UIAlertControllerStyleAlert];
    [alerta addTextFieldWithConfigurationHandler:^(UITextField *campo) {
        campo.text = valor;
        campo.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel
        handler:nil]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Crear" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            NSString *texto = alerta.textFields.firstObject.text;
            if (texto.length) { accion(texto); }
        }]];
    [self presentViewController:alerta animated:YES completion:nil];
}

- (void)crearCarpeta:(NSString *)nombre {
    NSString *ruta = [self.path stringByAppendingPathComponent:nombre];
    NSError *error = nil;
    if ([[IOFileSystem shared] createDirectoryAtPath:ruta error:&error]) {
        [self reloadContents];
    } else {
        [self mostrarError:error];
    }
}

- (void)crearArchivo:(NSString *)nombre {
    NSString *ruta = [self.path stringByAppendingPathComponent:nombre];
    NSError *error = nil;
    if ([[IOFileSystem shared] createFileAtPath:ruta contents:[NSData data] error:&error]) {
        [self reloadContents];
    } else {
        [self mostrarError:error];
    }
}

#pragma mark - Operaciones: renombrar, duplicar, borrar

- (void)preguntarRenombrar:(IOFileItem *)item {
    UIAlertController *alerta = [UIAlertController
        alertControllerWithTitle:@"Renombrar" message:nil
                  preferredStyle:UIAlertControllerStyleAlert];
    [alerta addTextFieldWithConfigurationHandler:^(UITextField *campo) {
        campo.text = item.name;
        campo.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel
        handler:nil]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Guardar" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            NSString *nombre = alerta.textFields.firstObject.text;
            NSError *error = nil;
            if ([[IOFileSystem shared] renameItemAtPath:item.path toName:nombre error:&error]) {
                [self reloadContents];
            } else {
                [self mostrarError:error];
            }
        }]];
    [self presentViewController:alerta animated:YES completion:nil];
}

- (void)duplicarItem:(IOFileItem *)item {
    NSString *carpeta = [item.path stringByDeletingLastPathComponent];
    NSString *destino = [[IOFileSystem shared] uniquePathForItemNamed:item.name
                                                         inDirectory:carpeta];
    __weak IOFilesViewController *debil = self;
    [self ejecutarOperacion:@"Duplicando" tarea:^BOOL(IOProgressBlock progreso,
                                                      IOCancelBlock cancelar,
                                                      NSError **error) {
        return [[IOFileSystem shared] copyItemAtPath:item.path toPath:destino
                                            progress:progreso cancel:cancelar error:error];
    } alTerminar:^(BOOL exito, NSError *error) {
        [debil terminarOperacion:exito error:error];
    }];
}

- (void)confirmarBorradoDeItems:(NSArray<IOFileItem *> *)items {
    if (items.count == 0) { return; }
    NSString *mensaje = (items.count == 1)
        ? [NSString stringWithFormat:@"Se borrara \"%@\".", items.firstObject.name]
        : [NSString stringWithFormat:@"Se borraran %lu elementos.",
           (unsigned long)items.count];

    if (![IOSettings shared].confirmDelete) {
        [self borrarItems:items];
        return;
    }
    UIAlertController *alerta = [UIAlertController
        alertControllerWithTitle:[items.firstObject isDirectory] ? @"Borrar carpeta" : @"Borrar"
                         message:mensaje
                  preferredStyle:UIAlertControllerStyleAlert];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel
        handler:nil]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Borrar" style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *a) { [self borrarItems:items]; }]];
    [self presentViewController:alerta animated:YES completion:nil];
}

- (void)borrarItems:(NSArray<IOFileItem *> *)items {
    NSArray *rutas = [items valueForKey:@"path"];
    __weak IOFilesViewController *debil = self;
    [self ejecutarOperacion:@"Borrando" tarea:^BOOL(IOProgressBlock progreso,
                                                    IOCancelBlock cancelar,
                                                    NSError **error) {
        for (NSString *ruta in rutas) {
            if (![[IOFileSystem shared] removeItemAtPath:ruta progress:progreso
                                                  cancel:cancelar error:error]) {
                return NO;
            }
        }
        return YES;
    } alTerminar:^(BOOL exito, NSError *error) {
        if (debil.modoSeleccion) { [debil desactivarSeleccion]; }
        [debil terminarOperacion:exito error:error];
    }];
}

#pragma mark - Operaciones: portapapeles

- (void)accionCopiarSeleccion {
    NSArray *rutas = [self.seleccionados valueForKey:@"path"];
    [[IOClipboard shared] setPaths:rutas cut:NO];
    [self desactivarSeleccion];
}

- (void)accionCortarSeleccion {
    NSArray *rutas = [self.seleccionados valueForKey:@"path"];
    [[IOClipboard shared] setPaths:rutas cut:YES];
    [self desactivarSeleccion];
}

- (void)accionCompartir {
    NSArray *rutas = [self.seleccionados valueForKey:@"path"];
    if (rutas.count == 0) { return; }
    [self compartirRutas:rutas desdeRect:CGRectMake(CGRectGetMidX(self.view.bounds),
                                                    CGRectGetMidY(self.view.bounds), 1, 1)];
}

- (void)accionComprimirSeleccion {
    NSArray *rutas = [self.seleccionados valueForKey:@"path"];
    [self comprimirRutas:rutas];
}

- (void)accionBorrarSeleccion {
    if (self.seleccionados.count == 0) { return; }
    [self confirmarBorradoDeItems:[self.seleccionados copy]];
}

- (void)accionPegar {
    IOClipboard *porta = [IOClipboard shared];
    if (!porta.hasItems) { return; }
    NSArray *rutas = [porta.paths copy];
    BOOL cortar = porta.isCut;
    __weak IOFilesViewController *debil = self;

    BOOL hayColision = NO;
    for (NSString *ruta in rutas) {
        NSString *destino = [self.path stringByAppendingPathComponent:[ruta lastPathComponent]];
        if ([[IOFileSystem shared] fileExistsAtPath:destino isDirectory:NULL]) {
            hayColision = YES;
            break;
        }
    }

    if (hayColision && [IOSettings shared].askBeforeOverwrite) {
        UIAlertController *alerta = [UIAlertController
            alertControllerWithTitle:@"Ya existe un elemento con ese nombre"
                             message:@"¿Que quieres hacer?"
                      preferredStyle:UIAlertControllerStyleAlert];
        [alerta addAction:[UIAlertAction actionWithTitle:@"Reemplazar"
            style:UIAlertActionStyleDestructive
            handler:^(UIAlertAction *a) { [debil ejecutarPegado:rutas cortar:cortar reemplazar:YES]; }]];
        [alerta addAction:[UIAlertAction actionWithTitle:@"Conservar ambos"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *a) { [debil ejecutarPegado:rutas cortar:cortar reemplazar:NO]; }]];
        [alerta addAction:[UIAlertAction actionWithTitle:@"Cancelar"
            style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alerta animated:YES completion:nil];
        return;
    }
    [self ejecutarPegado:rutas cortar:cortar reemplazar:NO];
}

- (void)ejecutarPegado:(NSArray *)rutas cortar:(BOOL)cortar reemplazar:(BOOL)reemplazar {
    NSString *destinoBase = self.path;
    __weak IOFilesViewController *debil = self;
    [self ejecutarOperacion:(cortar ? @"Moviendo" : @"Copiando")
        tarea:^BOOL(IOProgressBlock progreso, IOCancelBlock cancelar, NSError **error) {
        IOFileSystem *fs = [IOFileSystem shared];
        for (NSString *ruta in rutas) {
            if (cancelar && cancelar()) {
                if (error) { *error = [NSError errorWithDomain:IOFileSystemErrorDomain
                    code:IOFileSystemErrorCancelled
                    userInfo:@{NSLocalizedDescriptionKey: @"Cancelado"}]; }
                return NO;
            }
            NSString *destino = [destinoBase stringByAppendingPathComponent:[ruta lastPathComponent]];
            if ([fs fileExistsAtPath:destino isDirectory:NULL]) {
                if (reemplazar) {
                    if (![fs removeItemAtPath:destino error:error]) { return NO; }
                } else {
                    destino = [fs uniquePathForItemNamed:[ruta lastPathComponent]
                                            inDirectory:destinoBase];
                }
            }
            if (cortar) {
                if (![fs moveItemAtPath:ruta toPath:destino progress:progreso
                                 cancel:cancelar error:error]) {
                    return NO;
                }
            } else {
                if (![fs copyItemAtPath:ruta toPath:destino progress:progreso
                                 cancel:cancelar error:error]) {
                    return NO;
                }
            }
        }
        return YES;
    } alTerminar:^(BOOL exito, NSError *error) {
        if (exito) {
            IOClipboard *porta = [IOClipboard shared];
            if (porta.isCut && cortar) { [porta clear]; }
            [debil actualizarBarra];
        }
        [debil terminarOperacion:exito error:error];
    }];
}

#pragma mark - Operaciones: comprimir y extraer

- (void)comprimirRutas:(NSArray *)rutas {
    if (rutas.count == 0) { return; }
    NSString *nombre = (rutas.count == 1)
        ? [NSString stringWithFormat:@"%@.zip",
           [[rutas.firstObject lastPathComponent] stringByDeletingPathExtension]]
        : @"Archivo.zip";
    NSString *destino = [[IOFileSystem shared] uniquePathForItemNamed:nombre
                                                         inDirectory:self.path];
    __weak IOFilesViewController *debil = self;
    [self ejecutarOperacion:@"Comprimiendo" tarea:^BOOL(IOProgressBlock progreso,
                                                        IOCancelBlock cancelar,
                                                        NSError **error) {
        return [IOArchive createArchive:destino fromPaths:rutas progress:progreso
                                 cancel:cancelar error:error];
    } alTerminar:^(BOOL exito, NSError *error) {
        [debil terminarOperacion:exito error:error];
    }];
}

- (void)extraerArchivo:(NSString *)ruta enCarpetaNueva:(BOOL)nueva {
    NSString *destino = self.path;
    if (nueva) {
        NSString *base = [[ruta lastPathComponent] stringByDeletingPathExtension];
        if (base.length == 0) { base = @"Extraido"; }
        destino = [[IOFileSystem shared] uniquePathForItemNamed:base inDirectory:self.path];
        NSError *error = nil;
        if (![[IOFileSystem shared] createDirectoryAtPath:destino error:&error]) {
            [self mostrarError:error];
            return;
        }
    }
    __weak IOFilesViewController *debil = self;
    [self ejecutarOperacion:@"Extrayendo" tarea:^BOOL(IOProgressBlock progreso,
                                                      IOCancelBlock cancelar,
                                                      NSError **error) {
        return [IOArchive extractArchive:ruta toDirectory:destino progress:progreso
                                  cancel:cancelar error:error];
    } alTerminar:^(BOOL exito, NSError *error) {
        [debil terminarOperacion:exito error:error];
    }];
}

- (void)verContenidoDeArchivo:(IOFileItem *)item {
    NSError *error = nil;
    NSArray *entradas = [IOArchive listEntriesAtPath:item.path error:&error];
    if (!entradas) {
        [self mostrarError:error];
        return;
    }
    NSMutableArray *nombres = [NSMutableArray array];
    NSUInteger limite = MIN(entradas.count, (NSUInteger)30);
    for (NSUInteger i = 0; i < limite; i++) {
        NSDictionary *entrada = entradas[i];
        [nombres addObject:[NSString stringWithFormat:@"%@%@",
                            entrada[@"name"],
                            [entrada[@"isDirectory"] boolValue] ? @"/" : @""]];
    }
    NSString *mensaje = [nombres componentsJoinedByString:@"\n"];
    if (entradas.count > limite) {
        mensaje = [mensaje stringByAppendingFormat:@"\n... y %lu mas",
                   (unsigned long)(entradas.count - limite)];
    }
    UIAlertController *alerta = [UIAlertController
        alertControllerWithTitle:[NSString stringWithFormat:@"%lu entradas",
                                  (unsigned long)entradas.count]
                         message:mensaje
                  preferredStyle:UIAlertControllerStyleAlert];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cerrar" style:UIAlertActionStyleCancel
        handler:nil]];
    [self presentViewController:alerta animated:YES completion:nil];
}

#pragma mark - Compartir

- (void)compartirItem:(IOFileItem *)item desdeIndice:(NSIndexPath *)indice {
    CGRect rect;
    if (indice) {
        UITableViewCell *celda = [self.tabla cellForRowAtIndexPath:indice];
        rect = [celda convertRect:celda.bounds toView:self.view];
    } else {
        rect = CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    }
    [self compartirRutas:@[ item.path ] desdeRect:rect];
}

- (void)compartirRuta:(NSString *)ruta desdeRect:(CGRect)rect {
    [self compartirRutas:@[ ruta ] desdeRect:rect];
}

- (void)compartirRutas:(NSArray *)rutas desdeRect:(CGRect)rect {
    if (rutas.count == 0) { return; }
    if (rutas.count == 1) {
        self.docController =
            [UIDocumentInteractionController interactionControllerWithURL:
             [NSURL fileURLWithPath:rutas.firstObject]];
        self.docController.delegate = self;
        BOOL mostrado = [self.docController presentOptionsMenuFromRect:rect
                                                                 inView:self.view
                                                             animated:YES];
        if (!mostrado) {
            [self presentarActividadConRutas:rutas rect:rect];
        }
        return;
    }
    [self presentarActividadConRutas:rutas rect:rect];
}

- (void)presentarActividadConRutas:(NSArray *)rutas rect:(CGRect)rect {
    NSMutableArray *elementos = [NSMutableArray array];
    for (NSString *ruta in rutas) {
        [elementos addObject:[NSURL fileURLWithPath:ruta]];
    }
    UIActivityViewController *actividad =
        [[UIActivityViewController alloc] initWithActivityItems:elementos
                                          applicationActivities:nil];
    UIPopoverPresentationController *popover = actividad.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.view;
        popover.sourceRect = rect;
    }
    [self presentViewController:actividad animated:YES completion:nil];
}

#pragma mark - Ejecucion de operaciones

- (void)ejecutarOperacion:(NSString *)titulo
                    tarea:(BOOL (^)(IOProgressBlock progreso, IOCancelBlock cancelar,
                                    NSError **error))tarea
               alTerminar:(void (^)(BOOL exito, NSError *error))alTerminar {
    IOCancelToken *token = [[IOCancelToken alloc] init];
    __block NSInteger llamadas = 0;

    IOProgressBlock progreso = ^(double fraccion, NSString *ruta) {
        llamadas++;
        if ((llamadas % 6) != 0) { return; }
        NSString *nombre = ruta ? [ruta lastPathComponent] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[IOProgressHUD shared] updateProgress:fraccion];
            if (nombre) { [[IOProgressHUD shared] updateMessage:nombre]; }
        });
    };
    IOCancelBlock cancelar = ^BOOL { return token.cancelled; };

    [[IOProgressHUD shared] showInView:self.view message:titulo];
    [[IOProgressHUD shared] updateProgress:-1.0];
    [[IOProgressHUD shared] setCancelHandler:^{ token.cancelled = YES; }];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL exito = tarea(progreso, cancelar, &error);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[IOProgressHUD shared] hide];
            if (alTerminar) { alTerminar(exito, error); }
        });
    });
}

- (void)terminarOperacion:(BOOL)exito error:(NSError *)error {
    [self reloadContents];
    if (!exito && error) {
        if (error.code == IOFileSystemErrorCancelled ||
            [error.localizedDescription isEqualToString:@"Cancelado"]) {
            return;
        }
        [self mostrarError:error];
    }
}

- (void)mostrarError:(NSError *)error {
    NSString *mensaje = error.localizedDescription ?: @"Operacion no completada";
    UIAlertController *alerta = [UIAlertController
        alertControllerWithTitle:@"No se pudo completar"
                         message:mensaje
                  preferredStyle:UIAlertControllerStyleAlert];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Vale" style:UIAlertActionStyleDefault
        handler:nil]];
    [self presentViewController:alerta animated:YES completion:nil];
}

#pragma mark - Lateral

- (void)pulsarLateral {
    if (self.onSidebarToggle) { self.onSidebarToggle(); }
}

#pragma mark - UIDocumentInteractionControllerDelegate

- (UIViewController *)documentInteractionControllerViewControllerForPreview:
    (UIDocumentInteractionController *)controller {
    return self;
}

@end
