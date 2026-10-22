#import "IOTrashViewController.h"

#import "IOTheme.h"
#import "IOTrash.h"
#import "IOFileSystem.h"
#import "IOFileIcons.h"
#import "IOHelpers.h"
#import "IODialog.h"
#import "IOProgressHUD.h"

@interface IOTrashViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tabla;
@property (nonatomic, strong) UILabel *estadoVacio;
@property (nonatomic, strong) NSArray<NSString *> *nombres;
@property (nonatomic, strong) NSMutableDictionary *tamanos;
@property (nonatomic, strong) NSMutableArray *generaciones;

@end

@implementation IOTrashViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Papelera";
    self.view.backgroundColor = [IOTheme shared].background;
    self.tamanos = [NSMutableDictionary dictionary];

    self.tabla = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tabla.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabla.dataSource = self;
    self.tabla.delegate = self;
    self.tabla.rowHeight = 64.0;
    self.tabla.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tabla.contentInset = UIEdgeInsetsMake(0, 0, 24, 0);
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

    self.estadoVacio = [[UILabel alloc] init];
    self.estadoVacio.translatesAutoresizingMaskIntoConstraints = NO;
    self.estadoVacio.text = @"La papelera esta vacia.\nLos archivos que borres apareceran aqui.";
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
            attribute:NSLayoutAttributeCenterY multiplier:1 constant:-30],
        [NSLayoutConstraint constraintWithItem:self.estadoVacio attribute:NSLayoutAttributeWidth
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeWidth multiplier:0.7 constant:0]
    ]];

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

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.view.backgroundColor = tema.background;
    self.tabla.backgroundColor = tema.background;
    self.tabla.separatorColor = tema.separator;
    self.tabla.indicatorStyle = tema.dark ? UIScrollViewIndicatorStyleWhite
                                          : UIScrollViewIndicatorStyleDefault;
    self.estadoVacio.textColor = tema.textSecondary;
    self.estadoVacio.font = [tema fontBody];
    [self.tabla reloadData];
}

- (void)recargar {
    self.nombres = [[IOTrash shared] itemNames];
    self.estadoVacio.hidden = (self.nombres.count != 0);
    self.navigationItem.rightBarButtonItem = self.nombres.count
        ? [[UIBarButtonItem alloc] initWithTitle:@"Vaciar"
                                          style:UIBarButtonItemStylePlain
                                         target:self action:@selector(vaciar)]
        : nil;
    [self.tabla reloadData];

    NSArray *nombres = self.nombres;
    if (nombres.count == 0) { return; }
    __weak IOTrashViewController *debil = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableDictionary *calculados = [NSMutableDictionary dictionary];
        for (NSString *nombre in nombres) {
            NSString *ruta = [[IOTrash shared].directory stringByAppendingPathComponent:nombre];
            calculados[nombre] = @([[IOFileSystem shared] recursiveSizeOfPath:ruta]);
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            IOTrashViewController *fuerte = debil;
            if (!fuerte) { return; }
            fuerte.tamanos = calculados;
            [fuerte.tabla reloadData];
        });
    });
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.nombres.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IOTheme *tema = [IOTheme shared];
    UITableViewCell *celda = [tableView dequeueReusableCellWithIdentifier:@"papelera"];
    if (!celda) {
        celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:@"papelera"];
    }
    NSString *nombre = self.nombres[indexPath.row];
    NSString *original = [[IOTrash shared] originalPathForItemNamed:nombre] ?: nombre;
    NSString *nombreVisible = [original lastPathComponent];
    NSNumber *tamano = self.tamanos[nombre];

    celda.textLabel.text = nombreVisible;
    celda.textLabel.font = [tema fontHeadline];
    celda.textLabel.textColor = tema.textPrimary;
    NSString *carpeta = [original stringByDeletingLastPathComponent];
    if (tamano) {
        celda.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@",
                                      carpeta, [IOHelpers humanSize:tamano.unsignedLongLongValue]];
    } else {
        celda.detailTextLabel.text = carpeta;
    }
    celda.detailTextLabel.font = [tema fontSubhead];
    celda.detailTextLabel.textColor = tema.textSecondary;
    celda.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    celda.imageView.image = [[IOFileIcons shared] glyph:IOGlyphTrash size:24.0 color:tema.textTertiary];
    celda.imageView.contentMode = UIViewContentModeCenter;
    celda.backgroundColor = tema.cardBackground;
    celda.contentView.backgroundColor = tema.cardBackground;
    UIView *fondo = [[UIView alloc] init];
    fondo.backgroundColor = tema.selectionFill;
    celda.selectedBackgroundView = fondo;
    celda.accessoryType = UITableViewCellAccessoryNone;
    return celda;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *nombre = self.nombres[indexPath.row];
    NSString *original = [[IOTrash shared] originalPathForItemNamed:nombre] ?: nombre;
    __weak IOTrashViewController *debil = self;
    [IODialog showConfirmIn:self
                      title:@"Restaurar"
                    message:[NSString stringWithFormat:
                             @"Se devolvera \"%@\" a su carpeta original.",
                             [original lastPathComponent]]
                destructive:NO
               confirmTitle:@"Restaurar"
                    handler:^{
        NSError *error = nil;
        if (![[IOTrash shared] restoreItemNamed:nombre error:&error]) {
            [IODialog showErrorIn:debil error:error];
            return;
        }
        [debil recargar];
    }];
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView
                  editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *nombre = self.nombres[indexPath.row];
    __weak IOTrashViewController *debil = self;
    UITableViewRowAction *borrar = [UITableViewRowAction
        rowActionWithStyle:UITableViewRowActionStyleDestructive
                     title:@"Borrar"
                   handler:^(UITableViewRowAction *accion, NSIndexPath *indice) {
        [debil confirmarBorradoDeNombre:nombre];
    }];
    return @[ borrar ];
}

- (void)confirmarBorradoDeNombre:(NSString *)nombre {
    NSString *original = [[IOTrash shared] originalPathForItemNamed:nombre] ?: nombre;
    __weak IOTrashViewController *debil = self;
    [IODialog showConfirmIn:self
                      title:@"Borrar definitivamente"
                    message:[NSString stringWithFormat:
                             @"\"%@\" se borrara para siempre.",
                             [original lastPathComponent]]
                destructive:YES
               confirmTitle:@"Borrar"
                    handler:^{
        NSError *error = nil;
        if (![[IOTrash shared] deleteItemNamed:nombre error:&error]) {
            [IODialog showErrorIn:debil error:error];
            return;
        }
        [debil recargar];
    }];
}

- (void)vaciar {
    if (self.nombres.count == 0) { return; }
    unsigned long long total = 0;
    for (NSNumber *tamano in self.tamanos.allValues) {
        total += tamano.unsignedLongLongValue;
    }
    NSString *detalle = total > 0
        ? [NSString stringWithFormat:@"Se borraran %lu elementos (%@) para siempre.",
           (unsigned long)self.nombres.count, [IOHelpers humanSize:total]]
        : [NSString stringWithFormat:@"Se borraran %lu elementos para siempre.",
           (unsigned long)self.nombres.count];
    __weak IOTrashViewController *debil = self;
    [IODialog showConfirmIn:self
                      title:@"Vaciar papelera"
                    message:detalle
                destructive:YES
               confirmTitle:@"Vaciar"
                    handler:^{
        IOTrashViewController *fuerte = debil;
        if (!fuerte) { return; }
        [[IOProgressHUD shared] showInView:fuerte.view message:@"Vaciando papelera"];
        [[IOProgressHUD shared] updateProgress:-1.0];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = nil;
            BOOL ok = [[IOTrash shared] emptyWithError:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[IOProgressHUD shared] hide];
                if (!ok) {
                    [IODialog showErrorIn:fuerte error:error];
                }
                [fuerte recargar];
            });
        });
    }];
}

@end
