#import "IOPropertiesViewController.h"

#import "IOTheme.h"
#import "IOHelpers.h"
#import "IOFileItem.h"
#import "IOFileSystem.h"
#import "IOFileIcons.h"
#import "IOProgressHUD.h"

@interface IOPropertiesViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, copy) NSString *ruta;
@property (nonatomic, strong) IOFileItem *item;
@property (nonatomic, strong) UITableView *tabla;

@property (nonatomic, strong) NSArray *informacion;   // pares @[titulo, valor]
@property (nonatomic, strong) NSArray *fechas;

@property (nonatomic, strong) UITextField *campoOctal;
@property (nonatomic, strong) UITextField *campoDueno;
@property (nonatomic, strong) UITextField *campoGrupo;
@property (nonatomic, strong) UISwitch *interruptorRecursivo;

@property (nonatomic, assign) unsigned long long tamanoRecursivo;
@property (nonatomic, assign) BOOL tamanoListo;
@property (nonatomic, strong) UIDocumentInteractionController *docController;

@end

@implementation IOPropertiesViewController

- (instancetype)initWithPath:(NSString *)path {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _ruta = [path copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Propiedades";
    self.view.backgroundColor = [IOTheme shared].background;

    self.item = [IOFileItem itemAtPath:self.ruta computeChildCount:YES];

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

    [self construirCampos];
    [self construirInformacion];
    [self aplicarTema];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];

    if (self.item.isDirectory) {
        [self calcularTamanoRecursivo];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)construirCampos {
    self.campoOctal = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 110, 30)];
    self.campoOctal.textAlignment = NSTextAlignmentRight;
    self.campoOctal.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    self.campoOctal.borderStyle = UITextBorderStyleNone;
    self.campoOctal.text = self.item ? [IOHelpers octalString:self.item.mode] : @"";

    self.campoDueno = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 110, 30)];
    self.campoDueno.textAlignment = NSTextAlignmentRight;
    self.campoDueno.keyboardType = UIKeyboardTypeNumberPad;
    self.campoDueno.borderStyle = UITextBorderStyleNone;
    self.campoDueno.text = self.item ? [NSString stringWithFormat:@"%u", (unsigned)self.item.uid] : @"";

    self.campoGrupo = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 110, 30)];
    self.campoGrupo.textAlignment = NSTextAlignmentRight;
    self.campoGrupo.keyboardType = UIKeyboardTypeNumberPad;
    self.campoGrupo.borderStyle = UITextBorderStyleNone;
    self.campoGrupo.text = self.item ? [NSString stringWithFormat:@"%u", (unsigned)self.item.gid] : @"";

    self.interruptorRecursivo = [[UISwitch alloc] init];
    self.interruptorRecursivo.on = self.item.isDirectory;
    [self.interruptorRecursivo addTarget:self action:@selector(cambioRecursivo)
                        forControlEvents:UIControlEventValueChanged];
}

- (void)construirInformacion {
    IOFileItem *item = self.item;
    NSMutableArray *info = [NSMutableArray array];
    [info addObject:@[ @"Nombre", item.name ?: self.ruta.lastPathComponent ]];
    [info addObject:@[ @"Tipo", [item kindDescription] ]];
    if (item.isDirectory) {
        [info addObject:@[ @"Tamano", self.tamanoListo
                           ? [IOHelpers humanSize:self.tamanoRecursivo] : @"Calculando..."]];
        [info addObject:@[ @"Elementos", item.childCountComputed
                           ? [NSString stringWithFormat:@"%lu", (unsigned long)item.childCount]
                           : @"—" ]];
    } else {
        [info addObject:@[ @"Tamano", [IOHelpers humanSize:item.size] ]];
        [info addObject:@[ @"En disco", [IOHelpers humanSize:item.allocatedSize] ]];
    }
    NSString *magia = item.isDirectory ? nil : [IOHelpers magicDescriptionForPath:self.ruta];
    if (magia.length) { [info addObject:@[ @"Formato", magia ]]; }
    if (item.isSymlink) {
        NSString *destino = [NSFileManager.defaultManager
                             destinationOfSymbolicLinkAtPath:self.ruta error:NULL];
        [info addObject:@[ @"Enlace a", destino ?: @"?" ]];
    }
    [info addObject:@[ @"Ruta", self.ruta ]];
    [info addObject:@[ @"Oculto", item.isHidden ? @"Si" : @"No" ]];
    self.informacion = info;

    self.fechas = @[
        @[ @"Creado", [IOHelpers dateString:item.creationDate] ],
        @[ @"Modificado", [IOHelpers dateString:item.modificationDate] ]
    ];
}

- (void)calcularTamanoRecursivo {
    __weak IOPropertiesViewController *debil = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        unsigned long long tam = [[IOFileSystem shared] recursiveSizeOfPath:self.ruta];
        dispatch_async(dispatch_get_main_queue(), ^{
            debil.tamanoRecursivo = tam;
            debil.tamanoListo = YES;
            [debil construirInformacion];
            [debil.tabla reloadData];
        });
    });
}

- (void)cambioRecursivo {
    // Solo afecta al boton Aplicar.
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.view.backgroundColor = tema.background;
    self.tabla.backgroundColor = tema.background;
    self.tabla.separatorColor = tema.separator;
    self.campoOctal.textColor = tema.accent;
    self.campoDueno.textColor = tema.accent;
    self.campoGrupo.textColor = tema.accent;
    [self.tabla reloadData];
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) { return self.informacion.count; }
    if (section == 1) { return self.fechas.count; }
    if (section == 2) { return 6; }
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) { return @"Informacion"; }
    if (section == 1) { return @"Fechas"; }
    if (section == 2) { return @"Propietario y permisos"; }
    return @"Acciones";
}

- (UITableViewCell *)celdaDetalle {
    UITableViewCell *celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                   reuseIdentifier:nil];
    return celda;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IOTheme *tema = [IOTheme shared];
    UITableViewCell *celda = nil;

    if (indexPath.section == 0 || indexPath.section == 1) {
        NSArray *fila = (indexPath.section == 0) ? self.informacion[indexPath.row]
                                                 : self.fechas[indexPath.row];
        celda = [self celdaDetalle];
        celda.textLabel.text = fila[0];
        celda.detailTextLabel.text = fila[1];
        celda.textLabel.font = [tema fontBody];
        celda.textLabel.textColor = tema.textPrimary;
        celda.detailTextLabel.font = [tema fontSubhead];
        celda.detailTextLabel.textColor = tema.textSecondary;
        celda.detailTextLabel.numberOfLines = 2;
        celda.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == 2) {
        celda = [self celdaDetalle];
        celda.textLabel.font = [tema fontBody];
        celda.textLabel.textColor = tema.textPrimary;
        celda.selectionStyle = UITableViewCellSelectionStyleNone;
        switch (indexPath.row) {
            case 0:
                celda.textLabel.text = @"Modo";
                celda.detailTextLabel.text = [IOHelpers permissionsString:self.item.mode];
                celda.detailTextLabel.font = [tema fontMono:15.0];
                celda.detailTextLabel.textColor = tema.textSecondary;
                break;
            case 1:
                celda.textLabel.text = @"Octal";
                celda.accessoryView = self.campoOctal;
                break;
            case 2:
                celda.textLabel.text = [NSString stringWithFormat:@"Dueno (%@)",
                                        [IOHelpers ownerNameForUID:self.item.uid]];
                celda.accessoryView = self.campoDueno;
                break;
            case 3:
                celda.textLabel.text = [NSString stringWithFormat:@"Grupo (%@)",
                                        [IOHelpers groupNameForGID:self.item.gid]];
                celda.accessoryView = self.campoGrupo;
                break;
            case 4:
                celda.textLabel.text = @"Aplicar a subcarpetas";
                celda.accessoryView = self.interruptorRecursivo;
                break;
            default:
                celda.textLabel.text = @"Aplicar cambios";
                celda.textLabel.textColor = tema.accent;
                celda.textLabel.font = [tema fontHeadline];
                celda.accessoryType = UITableViewCellAccessoryNone;
                celda.selectionStyle = UITableViewCellSelectionStyleDefault;
                break;
        }
    } else {
        celda = [self celdaDetalle];
        celda.textLabel.text = @"Compartir / Abrir con";
        celda.textLabel.textColor = tema.accent;
        celda.textLabel.font = [tema fontHeadline];
        celda.selectionStyle = UITableViewCellSelectionStyleDefault;
    }

    celda.backgroundColor = tema.cardBackground;
    celda.contentView.backgroundColor = tema.cardBackground;
    return celda;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 2 && indexPath.row == 5) {
        [self aplicarCambios];
    } else if (indexPath.section == 3) {
        self.docController =
            [UIDocumentInteractionController interactionControllerWithURL:
             [NSURL fileURLWithPath:self.ruta]];
        [self.docController presentOptionsMenuFromRect:self.view.bounds
                                                inView:self.view
                                              animated:YES];
    }
}

- (void)aplicarCambios {
    [self.view endEditing:YES];
    BOOL recursivo = self.interruptorRecursivo.isOn;
    mode_t modo = [IOHelpers modeFromOctalString:self.campoOctal.text];
    uid_t uid = (uid_t)[self.campoDueno.text intValue];
    gid_t gid = (gid_t)[self.campoGrupo.text intValue];

    NSError *error = nil;
    BOOL ok = [[IOFileSystem shared] setMode:modo atPath:self.ruta recursive:recursivo
                                       error:&error];
    if (ok) {
        ok = [[IOFileSystem shared] setOwner:uid group:gid atPath:self.ruta
                                   recursive:recursivo error:&error];
    }

    if (ok) {
        self.item = [IOFileItem itemAtPath:self.ruta computeChildCount:YES];
        [self construirInformacion];
        [self.tabla reloadData];
        UIAlertController *alerta = [UIAlertController
            alertControllerWithTitle:@"Aplicado"
                             message:@"Permisos y propietario actualizados."
                      preferredStyle:UIAlertControllerStyleAlert];
        [alerta addAction:[UIAlertAction actionWithTitle:@"Vale" style:UIAlertActionStyleDefault
            handler:nil]];
        [self presentViewController:alerta animated:YES completion:nil];
    } else {
        UIAlertController *alerta = [UIAlertController
            alertControllerWithTitle:@"No se pudo aplicar"
                             message:error.localizedDescription
                      preferredStyle:UIAlertControllerStyleAlert];
        [alerta addAction:[UIAlertAction actionWithTitle:@"Vale" style:UIAlertActionStyleDefault
            handler:nil]];
        [self presentViewController:alerta animated:YES completion:nil];
    }
}

@end
