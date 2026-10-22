#import "IOSettingsViewController.h"

#import "IOTheme.h"
#import "IOSettings.h"
#import "IOFileIcons.h"
#import "IOHelpers.h"
#import "IODialog.h"
#import "IOTrash.h"
#import "IOProgressHUD.h"

@interface IOSettingsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tabla;
@property (nonatomic, strong) NSArray *secciones;
@property (nonatomic, strong) NSArray *clavesSwitch;
@property (nonatomic, strong) NSMutableDictionary *interruptores;

@end

@implementation IOSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Ajustes";
    self.view.backgroundColor = [IOTheme shared].background;
    self.interruptores = [NSMutableDictionary dictionary];

    [self construirModelo];

    self.tabla = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tabla.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabla.dataSource = self;
    self.tabla.delegate = self;
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

    [self aplicarTema];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)construirModelo {
    self.secciones = @[
        @{ @"t": @"Apariencia", @"filas": @[
            @{ @"t": @"Tema oscuro", @"tipo": @"switch", @"k": @"darkMode" }
        ]},
        @{ @"t": @"Visualizacion", @"filas": @[
            @{ @"t": @"Mostrar archivos ocultos", @"tipo": @"switch", @"k": @"showHidden" },
            @{ @"t": @"Carpetas antes que archivos", @"tipo": @"switch", @"k": @"foldersFirst" },
            @{ @"t": @"Mostrar detalles (tipo y tamano)", @"tipo": @"switch", @"k": @"showDetails" },
            @{ @"t": @"Miniaturas de imagenes", @"tipo": @"switch", @"k": @"thumbnails" },
            @{ @"t": @"Mostrar extensiones", @"tipo": @"switch", @"k": @"showExtensions" }
        ]},
        @{ @"t": @"Orden", @"filas": @[
            @{ @"t": @"Ordenar por", @"tipo": @"detalle", @"k": @"sortKey" },
            @{ @"t": @"Orden ascendente", @"tipo": @"switch", @"k": @"sortAscending" }
        ]},
        @{ @"t": @"Comportamiento", @"filas": @[
            @{ @"t": @"Confirmar antes de borrar", @"tipo": @"switch", @"k": @"confirmDelete" },
            @{ @"t": @"Avisar antes de sobrescribir", @"tipo": @"switch", @"k": @"askBeforeOverwrite" },
            @{ @"t": @"Abrir en la ultima carpeta", @"tipo": @"switch", @"k": @"openAtLastPath" }
        ]},
        @{ @"t": @"Papelera y almacenamiento", @"filas": @[
            @{ @"t": @"Mover a la papelera al borrar", @"tipo": @"switch", @"k": @"trashEnabled" },
            @{ @"t": @"Vaciar papelera", @"tipo": @"accion", @"k": @"emptyTrash" }
        ]},
        @{ @"t": @"Arranque", @"filas": @[
            @{ @"t": @"Carpeta de inicio", @"tipo": @"detalle", @"k": @"startPath" }
        ]},
        @{ @"t": @"Acerca de", @"filas": @[
            @{ @"t": @"Version", @"tipo": @"sololectura", @"k": @"version" },
            @{ @"t": @"Restablecer ajustes", @"tipo": @"accion", @"k": @"reset" }
        ]}
    ];

    NSMutableArray *claves = [NSMutableArray array];
    for (NSDictionary *seccion in self.secciones) {
        for (NSDictionary *fila in seccion[@"filas"]) {
            if ([fila[@"tipo"] isEqualToString:@"switch"]) {
                [claves addObject:fila[@"k"]];
            }
        }
    }
    self.clavesSwitch = claves;
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.view.backgroundColor = tema.background;
    self.tabla.backgroundColor = tema.background;
    UIView *fondo = [[UIView alloc] init];
    fondo.backgroundColor = tema.background;
    self.tabla.backgroundView = fondo;
    self.tabla.separatorColor = tema.separator;
    self.tabla.indicatorStyle = tema.dark ? UIScrollViewIndicatorStyleWhite
                                          : UIScrollViewIndicatorStyleDefault;
    for (UISwitch *interruptor in self.interruptores.allValues) {
        interruptor.onTintColor = tema.accent;
    }
    [self.tabla reloadData];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view
       forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *cabecera = (UITableViewHeaderFooterView *)view;
        cabecera.textLabel.textColor = [IOTheme shared].textTertiary;
        cabecera.textLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        cabecera.contentView.backgroundColor = [IOTheme shared].background;
    }
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.secciones.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.secciones[section][@"filas"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.secciones[section][@"t"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IOTheme *tema = [IOTheme shared];
    NSDictionary *fila = self.secciones[indexPath.section][@"filas"][indexPath.row];
    NSString *tipo = fila[@"tipo"];
    NSString *clave = fila[@"k"];
    IOSettings *ajustes = [IOSettings shared];

    UITableViewCell *celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                   reuseIdentifier:nil];
    celda.backgroundColor = tema.cardBackground;
    celda.contentView.backgroundColor = tema.cardBackground;
    celda.textLabel.text = fila[@"t"];
    celda.textLabel.font = [tema fontBody];
    celda.textLabel.textColor = tema.textPrimary;

    if ([tipo isEqualToString:@"switch"]) {
        UISwitch *interruptor = self.interruptores[clave];
        if (!interruptor) {
            interruptor = [[UISwitch alloc] init];
            interruptor.onTintColor = tema.accent;
            [interruptor addTarget:self action:@selector(cambioInterruptor:)
                  forControlEvents:UIControlEventValueChanged];
            self.interruptores[clave] = interruptor;
        }
        NSInteger indice = [self.clavesSwitch indexOfObject:clave];
        interruptor.tag = (indice == NSNotFound) ? 0 : indice;
        interruptor.on = [[ajustes valueForKey:clave] boolValue];
        celda.accessoryView = interruptor;
        celda.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if ([tipo isEqualToString:@"detalle"]) {
        celda.detailTextLabel.font = [tema fontSubhead];
        celda.detailTextLabel.textColor = tema.textSecondary;
        if ([clave isEqualToString:@"sortKey"]) {
            celda.detailTextLabel.text = [self nombreDeOrden:ajustes.sortKey];
            celda.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if ([clave isEqualToString:@"startPath"]) {
            celda.detailTextLabel.text = ajustes.startPath;
            celda.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if ([tipo isEqualToString:@"sololectura"]) {
        celda.detailTextLabel.font = [tema fontSubhead];
        celda.detailTextLabel.textColor = tema.textSecondary;
        NSString *version = [[NSBundle mainBundle]
                             objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        celda.detailTextLabel.text = version ?: @"1.0.0";
        celda.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        BOOL peligro = ([clave isEqualToString:@"reset"] ||
                        [clave isEqualToString:@"emptyTrash"]);
        celda.textLabel.textColor = peligro ? tema.danger : tema.accent;
        celda.textLabel.font = [tema fontHeadline];
        if ([clave isEqualToString:@"emptyTrash"]) {
            NSUInteger cantidad = [IOTrash shared].count;
            celda.textLabel.textAlignment = NSTextAlignmentLeft;
            celda.detailTextLabel.font = [tema fontSubhead];
            celda.detailTextLabel.textColor = tema.textSecondary;
            celda.detailTextLabel.text = cantidad
                ? [NSString stringWithFormat:@"%lu elementos", (unsigned long)cantidad]
                : @"Vacia";
            celda.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else {
            celda.textLabel.textAlignment = NSTextAlignmentCenter;
        }
        celda.selectionStyle = UITableViewCellSelectionStyleDefault;
    }

    UIView *fondoSeleccion = [[UIView alloc] init];
    fondoSeleccion.backgroundColor = tema.selectionFill;
    celda.selectedBackgroundView = fondoSeleccion;
    return celda;
}

- (NSString *)nombreDeOrden:(IOSortKey)clave {
    switch (clave) {
        case IOSortByName: return @"Nombre";
        case IOSortByKind: return @"Tipo";
        case IOSortByDate: return @"Fecha";
        case IOSortBySize: return @"Tamano";
    }
    return @"Nombre";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *fila = self.secciones[indexPath.section][@"filas"][indexPath.row];
    NSString *tipo = fila[@"tipo"];
    NSString *clave = fila[@"k"];

    if ([tipo isEqualToString:@"detalle"]) {
        if ([clave isEqualToString:@"sortKey"]) {
            [self preguntarOrden];
        } else if ([clave isEqualToString:@"startPath"]) {
            [self preguntarCarpetaInicio];
        }
    } else if ([tipo isEqualToString:@"accion"]) {
        if ([clave isEqualToString:@"reset"]) {
            [self confirmarReset];
        } else if ([clave isEqualToString:@"emptyTrash"]) {
            [self vaciarPapelera];
        }
    }
}

- (void)cambioInterruptor:(UISwitch *)interruptor {
    NSString *clave = self.clavesSwitch[interruptor.tag];
    [[IOSettings shared] setValue:@(interruptor.isOn) forKey:clave];

    if ([clave isEqualToString:@"darkMode"]) {
        // Fuera del propio evento del UISwitch: aplicar el tema recarga las
        // tablas y no conviene hacerlo a mitad de la animacion del control.
        BOOL oscuro = interruptor.isOn;
        dispatch_async(dispatch_get_main_queue(), ^{
            [IOTheme applyDark:oscuro];
        });
    } else if ([clave isEqualToString:@"thumbnails"]) {
        [[IOFileIcons shared] clearCache];
    }
    (void)[[IOSettings shared] valueForKey:clave];
}

- (void)preguntarOrden {
    IOSettings *ajustes = [IOSettings shared];
    NSMutableArray<IODialogAction *> *acciones = [NSMutableArray array];
    __weak IOSettingsViewController *debil = self;
    NSArray *opciones = @[ @[ @"Nombre", @(IOSortByName) ],
                           @[ @"Tipo", @(IOSortByKind) ],
                           @[ @"Fecha", @(IOSortByDate) ],
                           @[ @"Tamano", @(IOSortBySize) ] ];
    for (NSArray *opcion in opciones) {
        IOSortKey clave = (IOSortKey)[opcion[1] integerValue];
        BOOL activo = (ajustes.sortKey == clave);
        [acciones addObject:[IODialogAction actionWithTitle:
            [NSString stringWithFormat:@"%@%@", activo ? @"\u2713 " : @"", opcion[0]]
            style:(activo ? IODialogActionStyleSelected : IODialogActionStyleDefault)
            handler:^{
                ajustes.sortKey = clave;
                [debil.tabla reloadData];
            }]];
    }
    [IODialog showSheetIn:self title:@"Ordenar por" actions:acciones];
}

- (void)preguntarCarpetaInicio {
    IOSettings *ajustes = [IOSettings shared];
    IODialog *dialogo = [IODialog alertWithTitle:@"Carpeta de inicio" message:nil];
    UITextField *campo = [dialogo addTextFieldWithPlaceholder:@"/" text:ajustes.startPath];
    __weak IOSettingsViewController *debil = self;
    [dialogo addAction:@"Cancelar" style:IODialogActionStyleCancel handler:nil];
    [dialogo addAction:@"Guardar" style:IODialogActionStyleDefault handler:^{
        NSString *texto = campo.text;
        if (texto.length) {
            ajustes.startPath = texto;
            [debil.tabla reloadData];
        }
    }];
    [dialogo presentIn:self];
}

- (void)confirmarReset {
    __weak IOSettingsViewController *debil = self;
    [IODialog showConfirmIn:self
                      title:@"Restablecer ajustes"
                    message:@"Se borraran los ajustes, favoritos, recientes y el contenido de la papelera."
                destructive:YES
               confirmTitle:@"Restablecer"
                    handler:^{
        NSString *dominio = [[NSBundle mainBundle] bundleIdentifier];
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:dominio];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[IOTrash shared] emptyWithError:NULL];
        [IOTheme applyDark:NO];
        [debil.tabla reloadData];
    }];
}

- (void)vaciarPapelera {
    NSUInteger cantidad = [IOTrash shared].count;
    if (cantidad == 0) {
        [IODialog showAlertIn:self title:@"Papelera" message:@"La papelera ya esta vacia."];
        return;
    }
    unsigned long long tamano = [[IOTrash shared] totalSize];
    NSString *mensaje = [NSString stringWithFormat:
        @"Se borraran %lu elementos (%@) para siempre.",
        (unsigned long)cantidad, [IOHelpers humanSize:tamano]];
    __weak IOSettingsViewController *debil = self;
    [IODialog showConfirmIn:self
                      title:@"Vaciar papelera"
                    message:mensaje
                destructive:YES
               confirmTitle:@"Vaciar"
                    handler:^{
        IOSettingsViewController *fuerte = debil;
        if (!fuerte) { return; }
        [[IOProgressHUD shared] showInView:fuerte.view message:@"Vaciando papelera"];
        [[IOProgressHUD shared] updateProgress:-1.0];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = nil;
            BOOL ok = [[IOTrash shared] emptyWithError:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[IOProgressHUD shared] hide];
                if (!ok) { [IODialog showErrorIn:fuerte error:error]; }
                [fuerte.tabla reloadData];
            });
        });
    }];
}

@end
