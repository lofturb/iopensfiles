#import "IOInstallViewController.h"

#import "IOTheme.h"
#import "IOIPAInstaller.h"
#import "IOFileIcons.h"
#import "IOHelpers.h"
#import "IODialog.h"
#import "IOProgressHUD.h"
#import "IOFilesViewController.h"

@interface IOInstallViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tabla;
@property (nonatomic, strong) UILabel *estadoVacio;
@property (nonatomic, strong) UIRefreshControl *refresco;
@property (nonatomic, strong) NSArray<NSDictionary *> *paquetes;

@end

@implementation IOInstallViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Instalar IPA";
    self.view.backgroundColor = [IOTheme shared].background;

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

    self.refresco = [[UIRefreshControl alloc] init];
    [self.refresco addTarget:self action:@selector(recargar)
            forControlEvents:UIControlEventValueChanged];
    [self.tabla addSubview:self.refresco];

    self.estadoVacio = [[UILabel alloc] init];
    self.estadoVacio.translatesAutoresizingMaskIntoConstraints = NO;
    self.estadoVacio.numberOfLines = 0;
    self.estadoVacio.textAlignment = NSTextAlignmentCenter;
    self.estadoVacio.text = @"No se encontraron archivos .ipa.\n\nDescarga el paquete en Medios o Documentos, o elige un archivo manualmente.";
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
            attribute:NSLayoutAttributeWidth multiplier:0.75 constant:0]
    ]];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Elegir..."
                                        style:UIBarButtonItemStylePlain
                                       target:self action:@selector(elegirArchivo)];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];

    [self aplicarTema];
    [self recargar];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.view.backgroundColor = tema.background;
    self.tabla.backgroundColor = tema.background;
    self.tabla.separatorColor = tema.separator;
    self.tabla.indicatorStyle = tema.dark ? UIScrollViewIndicatorStyleWhite
                                          : UIScrollViewIndicatorStyleDefault;
    self.refresco.tintColor = tema.textSecondary;
    self.estadoVacio.textColor = tema.textSecondary;
    self.estadoVacio.font = [tema fontBody];
    [self.tabla reloadData];
}

- (void)recargar {
    NSArray *carpetas = @[ @"/var/mobile/Media", @"/var/mobile/Documents",
                           @"/var/mobile/Downloads", @"/var/mobile/Media/Downloads" ];
    __weak IOInstallViewController *debil = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *encontrados = [[IOIPAInstaller shared] findIPAsInPaths:carpetas limit:200];
        dispatch_async(dispatch_get_main_queue(), ^{
            IOInstallViewController *fuerte = debil;
            if (!fuerte) { return; }
            fuerte.paquetes = encontrados;
            fuerte.estadoVacio.hidden = (encontrados.count != 0);
            [fuerte.tabla reloadData];
            [fuerte.refresco endRefreshing];
        });
    });
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.paquetes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IOTheme *tema = [IOTheme shared];
    UITableViewCell *celda = [tableView dequeueReusableCellWithIdentifier:@"ipa"];
    if (!celda) {
        celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:@"ipa"];
    }
    NSDictionary *paquete = self.paquetes[indexPath.row];
    celda.textLabel.text = paquete[@"name"];
    celda.textLabel.font = [tema fontHeadline];
    celda.textLabel.textColor = tema.textPrimary;
    NSDate *fecha = paquete[@"date"];
    celda.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@",
        [IOHelpers humanSize:[paquete[@"size"] unsignedLongLongValue]],
        [IOHelpers shortDateString:fecha]];
    celda.detailTextLabel.font = [tema fontSubhead];
    celda.detailTextLabel.textColor = tema.textSecondary;
    celda.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    celda.imageView.image = [[IOFileIcons shared] glyph:IOGlyphApp size:30.0 color:tema.accent];
    celda.imageView.contentMode = UIViewContentModeCenter;
    celda.backgroundColor = tema.cardBackground;
    celda.contentView.backgroundColor = tema.cardBackground;
    UIView *fondo = [[UIView alloc] init];
    fondo.backgroundColor = tema.selectionFill;
    celda.selectedBackgroundView = fondo;
    celda.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return celda;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *paquete = self.paquetes[indexPath.row];
    [self confirmarInstalacionDeRuta:paquete[@"path"]];
}

#pragma mark - Instalacion

- (void)elegirArchivo {
    IOFilesViewController *explorador =
        [[IOFilesViewController alloc] initWithPath:@"/var/mobile/Media"];
    explorador.title = @"Elegir IPA";
    explorador.pickerMode = YES;
    explorador.pickerExtensions = @[ @"ipa" ];
    __weak IOInstallViewController *debil = self;
    explorador.onPick = ^(NSString *ruta) {
        [debil.navigationController popToViewController:debil animated:YES];
        [debil performSelector:@selector(confirmarInstalacionDeRuta:) withObject:ruta afterDelay:0.35];
    };
    [self.navigationController pushViewController:explorador animated:YES];
}

- (void)confirmarInstalacionDeRuta:(NSString *)ruta {
    if (ruta.length == 0) { return; }
    NSString *nombre = [ruta lastPathComponent];
    NSError *errorTamano = nil;
    NSDictionary *atributos = [[NSFileManager defaultManager]
                               attributesOfItemAtPath:ruta error:&errorTamano];
    unsigned long long tamano = [atributos fileSize];
    NSString *detalle = [NSString stringWithFormat:
        @"Se instalara \"%@\" (%@).\n\nEl paquete se extrae en una carpeta temporal y se instala con los permisos del sistema.",
        nombre, [IOHelpers humanSize:tamano]];
    __weak IOInstallViewController *debil = self;
    [IODialog showConfirmIn:self
                      title:@"Instalar paquete"
                    message:detalle
                destructive:NO
               confirmTitle:@"Instalar"
                    handler:^{ [debil instalarRuta:ruta]; }];
}

- (void)instalarRuta:(NSString *)ruta {
    IOProgressHUD *hud = [IOProgressHUD shared];
    [hud showInView:self.view message:@"Preparando paquete..."];
    [hud updateProgress:-1.0];
    [hud setCancelHandler:nil];

    __weak IOInstallViewController *debil = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL exito = [[IOIPAInstaller shared] installIPAAtPath:ruta
            message:^(NSString *mensaje) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[IOProgressHUD shared] updateMessage:mensaje];
                });
            } error:&error];
        NSString *bundleID = [IOIPAInstaller shared].lastBundleIdentifier;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[IOProgressHUD shared] hide];
            IOInstallViewController *fuerte = debil;
            if (!fuerte) { return; }
            if (!exito) {
                [IODialog showErrorIn:fuerte
                    error:error ?: [NSError errorWithDomain:IOIPAInstallerErrorDomain
                                                       code:0
                                                   userInfo:@{ NSLocalizedDescriptionKey:
                                                               @"No se pudo instalar el paquete" }]];
                return;
            }
            IODialog *dialogo = [IODialog alertWithTitle:@"Instalado"
                                                 message:@"La aplicacion se instalo correctamente. Ya aparece en la pantalla de inicio."];
            if (bundleID.length) {
                __weak IOInstallViewController *debil2 = fuerte;
                [dialogo addAction:@"Abrir" style:IODialogActionStyleDefault handler:^{
                    [[IOIPAInstaller shared] launchBundleIdentifier:bundleID];
                    (void)debil2;
                }];
            }
            [dialogo addAction:@"Vale" style:IODialogActionStyleCancel handler:nil];
            [dialogo presentIn:fuerte];
            [fuerte recargar];
        });
    });
}

@end
