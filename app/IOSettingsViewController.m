#import "IOSettingsViewController.h"

#import "IOTheme.h"
#import "IOSettings.h"
#import "IOFileIcons.h"
#import "IOHelpers.h"

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
    self.tabla.separatorColor = tema.separator;
    [self.tabla reloadData];
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
        celda.textLabel.textColor = [clave isEqualToString:@"reset"] ? tema.danger : tema.accent;
        celda.textLabel.font = [tema fontHeadline];
        celda.textLabel.textAlignment = NSTextAlignmentCenter;
        celda.selectionStyle = UITableViewCellSelectionStyleDefault;
    }

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
    } else if ([tipo isEqualToString:@"accion"] && [clave isEqualToString:@"reset"]) {
        [self confirmarReset];
    }
}

- (void)cambioInterruptor:(UISwitch *)interruptor {
    NSString *clave = self.clavesSwitch[interruptor.tag];
    [[IOSettings shared] setValue:@(interruptor.isOn) forKey:clave];

    if ([clave isEqualToString:@"darkMode"]) {
        [IOTheme applyDark:interruptor.isOn];
    } else if ([clave isEqualToString:@"thumbnails"]) {
        [[IOFileIcons shared] clearCache];
    }
    (void)[[IOSettings shared] valueForKey:clave];
}

- (void)preguntarOrden {
    IOSettings *ajustes = [IOSettings shared];
    UIAlertController *hoja = [UIAlertController
        alertControllerWithTitle:@"Ordenar por" message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *opciones = @[ @[ @"Nombre", @(IOSortByName) ],
                           @[ @"Tipo", @(IOSortByKind) ],
                           @[ @"Fecha", @(IOSortByDate) ],
                           @[ @"Tamano", @(IOSortBySize) ] ];
    for (NSArray *opcion in opciones) {
        [hoja addAction:[UIAlertAction actionWithTitle:opcion[0]
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *a) {
            ajustes.sortKey = (IOSortKey)[opcion[1] integerValue];
            [self.tabla reloadData];
        }]];
    }
    [hoja addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel
        handler:nil]];
    [self presentarHoja:hoja desdeIndice:[NSIndexPath indexPathForRow:0 inSection:2]];
}

- (void)preguntarCarpetaInicio {
    IOSettings *ajustes = [IOSettings shared];
    UIAlertController *alerta = [UIAlertController
        alertControllerWithTitle:@"Carpeta de inicio" message:nil
                  preferredStyle:UIAlertControllerStyleAlert];
    [alerta addTextFieldWithConfigurationHandler:^(UITextField *campo) {
        campo.text = ajustes.startPath;
        campo.placeholder = @"/";
    }];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel
        handler:nil]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Guardar" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            NSString *texto = alerta.textFields.firstObject.text;
            if (texto.length) {
                ajustes.startPath = texto;
                [self.tabla reloadData];
            }
        }]];
    [self presentViewController:alerta animated:YES completion:nil];
}

- (void)confirmarReset {
    UIAlertController *alerta = [UIAlertController
        alertControllerWithTitle:@"Restablecer ajustes"
                         message:@"Se borraran los ajustes, favoritos y recientes."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel
        handler:nil]];
    [alerta addAction:[UIAlertAction actionWithTitle:@"Restablecer"
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *a) {
            NSString *dominio = [[NSBundle mainBundle] bundleIdentifier];
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:dominio];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [IOTheme applyDark:NO];
            [self.tabla reloadData];
        }]];
    [self presentViewController:alerta animated:YES completion:nil];
}

- (void)presentarHoja:(UIAlertController *)hoja desdeIndice:(NSIndexPath *)indice {
    UIPopoverPresentationController *popover = hoja.popoverPresentationController;
    if (popover) {
        UITableViewCell *celda = [self.tabla cellForRowAtIndexPath:indice];
        if (celda) {
            popover.sourceView = celda;
            popover.sourceRect = celda.bounds;
        } else {
            popover.sourceView = self.view;
            popover.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds),
                                            CGRectGetMidY(self.view.bounds), 1, 1);
        }
    }
    [self presentViewController:hoja animated:YES completion:nil];
}

@end
