#import "IOPlaylistViewController.h"

#import "IOTheme.h"
#import "IOFileIcons.h"
#import "IOFileSystem.h"
#import "IODialog.h"

@interface IOPlaylistViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIView *barra;
@property (nonatomic, strong) UILabel *titulo;
@property (nonatomic, strong) UILabel *detalle;
@property (nonatomic, strong) UIButton *cerrar;
@property (nonatomic, strong) UITableView *tabla;
@property (nonatomic, strong) UILabel *vacio;
@end

@implementation IOPlaylistViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [IOTheme shared].background;

    self.barra = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.barra];

    self.titulo = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titulo.text = @"Lista de reproduccion";
    [self.barra addSubview:self.titulo];

    self.detalle = [[UILabel alloc] initWithFrame:CGRectZero];
    [self.barra addSubview:self.detalle];

    self.cerrar = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *imagenCerrar = [[IOFileIcons shared] glyph:IOGlyphClose
                                                   size:20.0 color:[UIColor blackColor]];
    [self.cerrar setImage:[imagenCerrar imageWithRenderingMode:
                             UIImageRenderingModeAlwaysTemplate]
                 forState:UIControlStateNormal];
    [self.cerrar addTarget:self action:@selector(cerrarPantalla)
          forControlEvents:UIControlEventTouchUpInside];
    [self.barra addSubview:self.cerrar];

    self.tabla = [[UITableView alloc] initWithFrame:CGRectZero
                                             style:UITableViewStylePlain];
    self.tabla.dataSource = self;
    self.tabla.delegate = self;
    self.tabla.rowHeight = 64.0;
    self.tabla.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tabla.contentInset = UIEdgeInsetsMake(0, 0, 24, 0);
    self.tabla.tableFooterView = [self pieDeTabla];
    [self.view addSubview:self.tabla];

    self.vacio = [[UILabel alloc] initWithFrame:CGRectZero];
    self.vacio.text = @"La lista esta vacia.";
    self.vacio.textAlignment = NSTextAlignmentCenter;
    self.vacio.numberOfLines = 0;
    [self.view addSubview:self.vacio];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];
    [self aplicarTema];
    [self actualizarContador];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UIView *)pieDeTabla {
    UIView *pie = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 54)];
    UILabel *texto = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, 288, 34)];
    texto.text = @"Desliza una pista para quitarla de la lista o borrar el archivo.";
    texto.numberOfLines = 2;
    texto.textAlignment = NSTextAlignmentCenter;
    texto.font = [UIFont systemFontOfSize:12.0];
    texto.textColor = [IOTheme shared].textTertiary;
    texto.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [pie addSubview:texto];
    return pie;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [UIApplication sharedApplication].statusBarStyle = [IOTheme shared].dark
        ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
    [self aplicarTema];
    [self.tabla reloadData];
    [self actualizarContador];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // Se vuelve al reproductor, que siempre usa barra de estado clara.
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat ancho = CGRectGetWidth(self.view.bounds);
    CGFloat alto = CGRectGetHeight(self.view.bounds);
    CGFloat estado = [UIApplication sharedApplication].statusBarFrame.size.height;
    CGFloat altoBarra = MAX((CGFloat)52.0, (CGFloat)52.0);
    CGFloat yTabla = estado + altoBarra;

    self.barra.frame = CGRectMake(0, 0, ancho, yTabla);
    self.titulo.frame = CGRectMake(18, estado + 7, ancho - 86, 23);
    self.detalle.frame = CGRectMake(18, estado + 29, ancho - 86, 16);
    self.cerrar.frame = CGRectMake(ancho - 52, estado + 6, 44, 44);

    self.tabla.frame = CGRectMake(0, yTabla, ancho, MAX(0, alto - yTabla));
    self.vacio.frame = CGRectMake(20, yTabla, ancho - 40, MAX(0, alto - yTabla));
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.view.backgroundColor = tema.background;
    self.barra.backgroundColor = tema.elevatedBackground;
    self.titulo.font = [tema fontHeadline];
    self.titulo.textColor = tema.textPrimary;
    self.detalle.font = [tema fontSubhead];
    self.detalle.textColor = tema.textSecondary;
    self.cerrar.tintColor = tema.accent;

    self.tabla.backgroundColor = tema.background;
    UIView *fondo = [[UIView alloc] init];
    fondo.backgroundColor = tema.background;
    self.tabla.backgroundView = fondo;
    self.tabla.separatorColor = tema.separator;
    self.tabla.indicatorStyle = tema.dark ? UIScrollViewIndicatorStyleWhite
                                          : UIScrollViewIndicatorStyleBlack;

    self.vacio.font = [tema fontBody];
    self.vacio.textColor = tema.textSecondary;

    for (UIView *vista in self.tabla.tableFooterView.subviews) {
        if ([vista isKindOfClass:[UILabel class]]) {
            ((UILabel *)vista).textColor = tema.textTertiary;
        }
    }
    [self.tabla reloadData];
}

- (void)actualizarContador {
    NSInteger total = self.dataSource ? [self.dataSource playlistNumberOfItems] : 0;
    self.detalle.text = [NSString stringWithFormat:@"%ld %@",
        (long)total, total == 1 ? @"pista" : @"pistas"];
    self.vacio.hidden = (total > 0);
    self.tabla.hidden = (total == 0);
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource ? [self.dataSource playlistNumberOfItems] : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *celda = [tableView dequeueReusableCellWithIdentifier:@"pista"];
    if (!celda) {
        celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"pista"];
    }

    IOTheme *tema = [IOTheme shared];
    NSString *ruta = [self.dataSource playlistPathAtIndex:indexPath.row];
    NSInteger actual = [self.dataSource playlistCurrentIndex];
    BOOL esActual = (indexPath.row == actual);

    celda.textLabel.text = [ruta lastPathComponent];
    celda.textLabel.font = [tema fontBody];
    celda.textLabel.textColor = esActual ? tema.accent : tema.textPrimary;

    NSString *carpeta = [ruta stringByDeletingLastPathComponent];
    celda.detailTextLabel.text = [NSString stringWithFormat:@"%@%@",
                                  esActual ? @"▶ " : @"", carpeta];
    celda.detailTextLabel.font = [tema fontSubhead];
    celda.detailTextLabel.textColor = tema.textSecondary;
    celda.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;

    celda.backgroundColor = tema.cardBackground;
    celda.contentView.backgroundColor = tema.cardBackground;
    UIView *seleccion = [[UIView alloc] init];
    seleccion.backgroundColor = tema.selectionFill;
    celda.selectedBackgroundView = seleccion;

    celda.accessoryType = UITableViewCellAccessoryDetailButton;
    celda.tintColor = esActual ? tema.accent : tema.textTertiary;
    return celda;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!self.dataSource) { return; }
    [self.dataSource playlistSelectIndex:indexPath.row];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView
    accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    NSString *ruta = [self.dataSource playlistPathAtIndex:indexPath.row];
    if (!ruta) { return; }

    __weak IOPlaylistViewController *debil = self;
    NSInteger indice = indexPath.row;
    NSMutableArray<IODialogAction *> *acciones = [NSMutableArray array];
    [acciones addObject:[IODialogAction actionWithTitle:@"Reproducir ahora"
        style:IODialogActionStyleDefault handler:^{
        [debil.dataSource playlistSelectIndex:indice];
        [debil dismissViewControllerAnimated:YES completion:nil];
    }]];
    [acciones addObject:[IODialogAction actionWithTitle:@"Quitar de la lista"
        style:IODialogActionStyleDefault handler:^{
        [debil quitarEnIndice:indice];
    }]];
    [acciones addObject:[IODialogAction actionWithTitle:@"Borrar permanentemente"
        style:IODialogActionStyleDestructive handler:^{
        [debil borrarEnIndice:indice];
    }]];
    [acciones addObject:[IODialogAction actionWithTitle:@"Cancelar"
        style:IODialogActionStyleCancel handler:nil]];
    [IODialog showSheetIn:self title:[ruta lastPathComponent] actions:acciones];
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView
                  editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    __weak IOPlaylistViewController *debil = self;

    UITableViewRowAction *quitar = [UITableViewRowAction
        rowActionWithStyle:UITableViewRowActionStyleNormal
                     title:@"Quitar"
                   handler:^(UITableViewRowAction *accion, NSIndexPath *indice) {
        [debil quitarEnIndice:indice.row];
    }];
    quitar.backgroundColor = [IOTheme shared].warning;

    UITableViewRowAction *borrar = [UITableViewRowAction
        rowActionWithStyle:UITableViewRowActionStyleDestructive
                     title:@"Borrar"
                   handler:^(UITableViewRowAction *accion, NSIndexPath *indice) {
        [debil borrarEnIndice:indice.row];
    }];
    return @[ borrar, quitar ];
}

- (void)quitarEnIndice:(NSInteger)indice {
    if (!self.dataSource) { return; }
    NSInteger total = [self.dataSource playlistNumberOfItems];
    if (indice < 0 || indice >= total) { return; }
    [self.dataSource playlistRemoveIndex:indice];
    [self.tabla reloadData];
    [self actualizarContador];
}

- (void)borrarEnIndice:(NSInteger)indice {
    if (!self.dataSource) { return; }
    NSInteger total = [self.dataSource playlistNumberOfItems];
    if (indice < 0 || indice >= total) { return; }
    NSString *ruta = [self.dataSource playlistPathAtIndex:indice];
    if (!ruta) { return; }

    __weak IOPlaylistViewController *debil = self;
    [IODialog showConfirmIn:self
                      title:@"Borrar permanentemente"
                    message:[NSString stringWithFormat:
                        @"Se borrara \"%@\" del almacenamiento. No se puede deshacer.",
                        [ruta lastPathComponent]]
                destructive:YES
               confirmTitle:@"Borrar"
                    handler:^{
        NSError *error = nil;
        BOOL borrado = [[IOFileSystem shared] removeItemAtPath:ruta error:&error];
        if (!borrado) {
            [IODialog showErrorIn:debil error:error];
            return;
        }
        [debil quitarEnIndice:indice];
    }];
}

- (void)cerrarPantalla {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
