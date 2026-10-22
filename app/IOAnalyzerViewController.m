#import "IOAnalyzerViewController.h"

#import "IOTheme.h"
#import "IOHelpers.h"
#import "IOFileItem.h"
#import "IOFileSystem.h"
#import "IOFileIcons.h"
#import "IOFilesViewController.h"
#import "IODialog.h"
#import "IOProgressHUD.h"

#pragma mark - Modelo

@interface IOAnalyzerGroup : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) IOGlyph glyph;
@property (nonatomic, assign) unsigned long long bytes;
@property (nonatomic, strong) NSMutableArray<IOFileItem *> *files;
@end

@implementation IOAnalyzerGroup
- (instancetype)init {
    self = [super init];
    if (self) { _files = [NSMutableArray array]; }
    return self;
}
@end

@interface IOAnalyzerToken : NSObject
@property (atomic, assign) BOOL cancelled;
@end
@implementation IOAnalyzerToken
@end

#pragma mark - Celda de categoria

@interface IOAnalyzerCell : UITableViewCell
@property (nonatomic, strong) UIImageView *icono;
@property (nonatomic, strong) UILabel *titulo;
@property (nonatomic, strong) UILabel *detalle;
@property (nonatomic, strong) UILabel *tamano;
@property (nonatomic, strong) UIView *barraFondo;
@property (nonatomic, strong) UIView *barraRelleno;
@property (nonatomic, assign) double fraccion;
- (void)configurarConGrupo:(IOAnalyzerGroup *)grupo total:(unsigned long long)total;
- (void)aplicarTema;
@end

@implementation IOAnalyzerCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
               reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.icono = [[UIImageView alloc] init];
        self.icono.contentMode = UIViewContentModeCenter;
        [self.contentView addSubview:self.icono];

        self.titulo = [[UILabel alloc] init];
        [self.contentView addSubview:self.titulo];

        self.detalle = [[UILabel alloc] init];
        [self.contentView addSubview:self.detalle];

        self.tamano = [[UILabel alloc] init];
        self.tamano.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:self.tamano];

        self.barraFondo = [[UIView alloc] init];
        self.barraFondo.layer.cornerRadius = 2.0;
        self.barraFondo.layer.masksToBounds = YES;
        [self.contentView addSubview:self.barraFondo];

        self.barraRelleno = [[UIView alloc] init];
        self.barraRelleno.layer.cornerRadius = 2.0;
        self.barraRelleno.layer.masksToBounds = YES;
        [self.barraFondo addSubview:self.barraRelleno];

        [self aplicarTema];
    }
    return self;
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.backgroundColor = tema.cardBackground;
    self.contentView.backgroundColor = tema.cardBackground;
    self.titulo.textColor = tema.textPrimary;
    self.titulo.font = [tema fontHeadline];
    self.detalle.textColor = tema.textSecondary;
    self.detalle.font = [tema fontSubhead];
    self.tamano.textColor = tema.textPrimary;
    self.tamano.font = [tema fontSubhead];
    self.barraFondo.backgroundColor = tema.separator;
    UIView *fondo = [[UIView alloc] init];
    fondo.backgroundColor = tema.selectionFill;
    self.selectedBackgroundView = fondo;
}

- (void)configurarConGrupo:(IOAnalyzerGroup *)grupo total:(unsigned long long)total {
    IOTheme *tema = [IOTheme shared];
    self.titulo.text = grupo.title;
    self.detalle.text = [NSString stringWithFormat:@"%lu archivos",
                         (unsigned long)grupo.files.count];
    self.tamano.text = [IOHelpers humanSize:grupo.bytes];
    self.icono.image = [[IOFileIcons shared] glyph:grupo.glyph size:26.0
                                             color:[IOFileIcons colorForGlyph:grupo.glyph]];
    self.barraRelleno.backgroundColor = [IOFileIcons colorForGlyph:grupo.glyph];
    self.fraccion = total > 0 ? (double)grupo.bytes / (double)total : 0.0;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat ancho = CGRectGetWidth(self.contentView.bounds);
    self.icono.frame = CGRectMake(14, (CGRectGetHeight(self.contentView.bounds) - 34) / 2.0,
                                  34, 34);
    self.tamano.frame = CGRectMake(ancho - 100, 12, 86, 20);
    self.titulo.frame = CGRectMake(60, 11, ancho - 60 - 108, 22);
    self.detalle.frame = CGRectMake(60, 33, ancho - 60 - 108, 16);
    self.barraFondo.frame = CGRectMake(60, 54, ancho - 60 - 16, 4);
    self.barraRelleno.frame = CGRectMake(0, 0,
        CGRectGetWidth(self.barraFondo.bounds) * self.fraccion, 4);
}

@end

#pragma mark - Analizador

@interface IOAnalyzerCategoryViewController : UIViewController
@property (nonatomic, copy) void (^onDelete)(void);
- (instancetype)initWithTitle:(NSString *)title files:(NSArray<IOFileItem *> *)files;
@end

@interface IOAnalyzerViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tabla;
@property (nonatomic, strong) NSArray<IOAnalyzerGroup *> *grupos;
@property (nonatomic, strong) NSArray<IOFileItem *> *grandes;
@property (nonatomic, assign) unsigned long long totalBytes;
@property (nonatomic, assign) NSUInteger totalArchivos;
@property (nonatomic, strong) UILabel *tituloTamano;
@property (nonatomic, strong) UILabel *detalleTamano;
@property (nonatomic, strong) UILabel *aviso;
@property (nonatomic, strong) UIButton *botonCarpeta;
@property (nonatomic, assign) BOOL analizando;
@property (nonatomic, strong) IOAnalyzerToken *token;
@end

@implementation IOAnalyzerViewController

- (instancetype)initWithPath:(NSString *)path {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _path = path.length ? [path copy] : @"/var/mobile";
        _grupos = @[];
        _grandes = @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Examinar y limpiar";
    self.view.backgroundColor = [IOTheme shared].background;

    self.tabla = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tabla.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabla.dataSource = self;
    self.tabla.delegate = self;
    self.tabla.rowHeight = 68.0;
    self.tabla.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
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

    [self construirCabecera];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                      target:self action:@selector(iniciarAnalisis)];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];

    [self aplicarTema];
    [self iniciarAnalisis];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.token.cancelled = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.analizando) {
        self.token.cancelled = YES;
        [[IOProgressHUD shared] hide];
        self.analizando = NO;
    }
}

- (void)construirCabecera {
    UIView *cabecera = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 172)];

    UILabel *etiqueta = [[UILabel alloc] initWithFrame:CGRectMake(18, 16, 260, 16)];
    etiqueta.text = @"ESPACIO ANALIZADO";
    etiqueta.tag = 101;
    [cabecera addSubview:etiqueta];

    self.tituloTamano = [[UILabel alloc] initWithFrame:CGRectMake(18, 34, 300, 38)];
    self.tituloTamano.text = @"Calculando...";
    [cabecera addSubview:self.tituloTamano];

    self.detalleTamano = [[UILabel alloc] initWithFrame:CGRectMake(18, 74, 300, 18)];
    self.detalleTamano.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [cabecera addSubview:self.detalleTamano];

    self.aviso = [[UILabel alloc] initWithFrame:CGRectMake(18, 98, 300, 34)];
    self.aviso.numberOfLines = 2;
    self.aviso.text = @"Se omiten las carpetas del sistema y los datos de apps. Nada se borra sin que lo elijas.";
    [cabecera addSubview:self.aviso];

    self.botonCarpeta = [UIButton buttonWithType:UIButtonTypeCustom];
    self.botonCarpeta.frame = CGRectMake(18, 136, 170, 30);
    self.botonCarpeta.layer.cornerRadius = 15.0;
    self.botonCarpeta.layer.masksToBounds = YES;
    [self.botonCarpeta setTitle:@"Cambiar carpeta" forState:UIControlStateNormal];
    self.botonCarpeta.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
    self.botonCarpeta.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    [self.botonCarpeta addTarget:self action:@selector(elegirCarpeta)
                forControlEvents:UIControlEventTouchUpInside];
    [cabecera addSubview:self.botonCarpeta];

    cabecera.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    for (UIView *sub in cabecera.subviews) {
        sub.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    }
    self.tabla.tableHeaderView = cabecera;
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.view.backgroundColor = tema.background;
    self.tabla.backgroundColor = tema.background;
    self.tabla.separatorColor = tema.separator;
    self.tabla.indicatorStyle = tema.dark ? UIScrollViewIndicatorStyleWhite
                                          : UIScrollViewIndicatorStyleDefault;

    UILabel *etiqueta = [self.tabla.tableHeaderView viewWithTag:101];
    etiqueta.textColor = tema.textTertiary;
    etiqueta.font = [tema fontCaption];

    self.tituloTamano.textColor = tema.textPrimary;
    self.tituloTamano.font = [UIFont systemFontOfSize:30.0 weight:UIFontWeightBold];
    self.detalleTamano.textColor = tema.textSecondary;
    self.detalleTamano.font = [tema fontSubhead];
    self.aviso.textColor = tema.textTertiary;
    self.aviso.font = [UIFont systemFontOfSize:11.0];
    self.botonCarpeta.backgroundColor = tema.accentSoft;
    [self.botonCarpeta setTitleColor:tema.accent forState:UIControlStateNormal];

    [self.tabla reloadData];
}

- (void)actualizarCabecera {
    self.tituloTamano.text = [IOHelpers humanSize:self.totalBytes];
    self.detalleTamano.text = [NSString stringWithFormat:@"%lu archivos · %@",
                               (unsigned long)self.totalArchivos, self.path];
}

#pragma mark - Analisis

- (void)iniciarAnalisis {
    if (self.analizando) { return; }
    self.analizando = YES;
    self.grupos = @[];
    self.grandes = @[];
    self.totalBytes = 0;
    self.totalArchivos = 0;
    self.tituloTamano.text = @"Analizando...";
    self.detalleTamano.text = self.path;
    [self.tabla reloadData];

    IOAnalyzerToken *token = [[IOAnalyzerToken alloc] init];
    self.token = token;

    [[IOProgressHUD shared] showInView:self.view message:@"Analizando almacenamiento..."];
    [[IOProgressHUD shared] updateProgress:-1.0];
    __weak IOAnalyzerViewController *debil = self;
    [[IOProgressHUD shared] setCancelHandler:^{ token.cancelled = YES; }];

    NSString *raiz = self.path;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSDirectoryEnumerator *enumerador = [fm
            enumeratorAtURL:[NSURL fileURLWithPath:raiz]
 includingPropertiesForKeys:@[ NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey,
                               NSURLFileSizeKey, NSURLContentModificationDateKey ]
                    options:0 errorHandler:^BOOL(NSURL *url, NSError *error) { return YES; }];

        NSMutableDictionary<NSString *, IOAnalyzerGroup *> *mapa =
            [NSMutableDictionary dictionary];
        NSMutableArray<IOFileItem *> *todos = [NSMutableArray array];
        unsigned long long total = 0;
        NSUInteger cuenta = 0;
        NSUInteger procesados = 0;

        for (NSURL *url in enumerador) {
            if (token.cancelled) { break; }
            if (cuenta >= 80000) { break; }

            NSNumber *esDir = nil;
            NSNumber *esEnlace = nil;
            [url getResourceValue:&esDir forKey:NSURLIsDirectoryKey error:NULL];
            [url getResourceValue:&esEnlace forKey:NSURLIsSymbolicLinkKey error:NULL];
            if (esEnlace.boolValue) { continue; }

            NSString *ruta = url.path;
            if (esDir.boolValue) {
                if ([[IOFileSystem shared] isProtectedPath:ruta]) {
                    [enumerador skipDescendants];
                }
                continue;
            }
            if ([[IOFileSystem shared] isProtectedPath:ruta]) { continue; }

            NSNumber *tamano = nil;
            [url getResourceValue:&tamano forKey:NSURLFileSizeKey error:NULL];
            unsigned long long bytes = tamano.unsignedLongLongValue;
            if (bytes == 0) { continue; }

            IOFileItem *item = [[IOFileItem alloc] init];
            item.name = url.lastPathComponent;
            item.path = ruta;
            item.size = bytes;
            item.isDirectory = NO;
            NSDate *fecha = nil;
            [url getResourceValue:&fecha forKey:NSURLContentModificationDateKey error:NULL];
            item.modificationDate = fecha;

            IOAnalyzerGroup *grupo = [self grupoParaRuta:ruta mapa:mapa];
            grupo.bytes += bytes;
            [grupo.files addObject:item];
            [todos addObject:item];

            total += bytes;
            cuenta++;
            procesados++;

            if ((procesados % 300) == 0) {
                NSUInteger parcial = cuenta;
                unsigned long long totalParcial = total;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[IOProgressHUD shared] updateMessage:
                        [NSString stringWithFormat:@"%@ · %lu archivos",
                         [IOHelpers humanSize:totalParcial], (unsigned long)parcial]];
                });
            }
        }

        NSMutableArray *ordenados = [NSMutableArray array];
        for (IOAnalyzerGroup *grupo in mapa.allValues) {
            if (grupo.files.count == 0) { continue; }
            [grupo.files sortUsingComparator:^NSComparisonResult(IOFileItem *a, IOFileItem *b) {
                if (a.size < b.size) { return NSOrderedDescending; }
                if (a.size > b.size) { return NSOrderedAscending; }
                return [a.name localizedCaseInsensitiveCompare:b.name];
            }];
            [ordenados addObject:grupo];
        }
        [ordenados sortUsingComparator:^NSComparisonResult(IOAnalyzerGroup *a, IOAnalyzerGroup *b) {
            if (a.bytes < b.bytes) { return NSOrderedDescending; }
            if (a.bytes > b.bytes) { return NSOrderedAscending; }
            return [a.title compare:b.title];
        }];

        [todos sortUsingComparator:^NSComparisonResult(IOFileItem *a, IOFileItem *b) {
            if (a.size < b.size) { return NSOrderedDescending; }
            if (a.size > b.size) { return NSOrderedAscending; }
            return [a.name localizedCaseInsensitiveCompare:b.name];
        }];
        NSArray *grandes = [todos subarrayWithRange:
            NSMakeRange(0, MIN((NSUInteger)15, todos.count))];

        dispatch_async(dispatch_get_main_queue(), ^{
            [[IOProgressHUD shared] hide];
            IOAnalyzerViewController *fuerte = debil;
            if (!fuerte) { return; }
            fuerte.analizando = NO;
            fuerte.grupos = ordenados;
            fuerte.grandes = grandes;
            fuerte.totalBytes = total;
            fuerte.totalArchivos = cuenta;
            [fuerte actualizarCabecera];
            [fuerte.tabla reloadData];
            if (ordenados.count == 0) {
                fuerte.tituloTamano.text = @"Sin archivos";
            }
        });
    });
}

- (IOAnalyzerGroup *)grupoParaRuta:(NSString *)ruta
                              mapa:(NSMutableDictionary *)mapa {
    NSString *minusculas = [ruta lowercaseString];
    NSString *clave = @"Otros";
    IOGlyph glifo = IOGlyphFile;

    if (([minusculas rangeOfString:@"/caches/"].location != NSNotFound) ||
        ([minusculas rangeOfString:@"/tmp/"].location != NSNotFound) ||
        ([minusculas rangeOfString:@"/logs/"].location != NSNotFound) ||
        ([minusculas rangeOfString:@".cache"].location != NSNotFound)) {
        clave = @"Cache";
        glifo = IOGlyphRefresh;
    } else if ([IOHelpers isVideoFile:ruta]) {
        clave = @"Videos"; glifo = IOGlyphVideo;
    } else if ([IOHelpers isImageFile:ruta]) {
        clave = @"Imagenes"; glifo = IOGlyphImage;
    } else if ([IOHelpers isAudioFile:ruta]) {
        clave = @"Audio"; glifo = IOGlyphAudio;
    } else if ([IOHelpers isArchiveFile:ruta]) {
        clave = @"Comprimidos"; glifo = IOGlyphArchive;
    } else if ([IOHelpers isTextFile:ruta] || [IOHelpers isPlistFile:ruta] ||
               [self esDocumento:ruta]) {
        clave = @"Documentos"; glifo = IOGlyphText;
    }

    IOAnalyzerGroup *grupo = mapa[clave];
    if (!grupo) {
        grupo = [[IOAnalyzerGroup alloc] init];
        grupo.title = clave;
        grupo.glyph = glifo;
        mapa[clave] = grupo;
    }
    return grupo;
}

- (BOOL)esDocumento:(NSString *)ruta {
    static NSSet *extensiones = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        extensiones = [NSSet setWithArray:@[ @"pdf", @"doc", @"docx", @"xls", @"xlsx",
            @"ppt", @"pptx", @"rtf", @"csv", @"epub", @"mobi", @"json", @"xml",
            @"html", @"htm", @"md", @"pages", @"numbers", @"key" ]];
    });
    return [extensiones containsObject:[ruta pathExtension].lowercaseString];
}

#pragma mark - Tabla

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) { return self.grupos.count; }
    return self.grandes.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) { return @"Por tipo"; }
    return self.grandes.count ? @"Archivos mas grandes" : nil;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view
       forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *cabecera = (UITableViewHeaderFooterView *)view;
        cabecera.textLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        cabecera.textLabel.textColor = [IOTheme shared].textTertiary;
        cabecera.contentView.backgroundColor = [IOTheme shared].background;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 1 && self.grandes.count == 0) { return 0; }
    return 30.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IOTheme *tema = [IOTheme shared];
    if (indexPath.section == 0) {
        IOAnalyzerCell *celda = [tableView dequeueReusableCellWithIdentifier:@"grupo"];
        if (!celda) {
            celda = [[IOAnalyzerCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:@"grupo"];
        }
        IOAnalyzerGroup *grupo = self.grupos[indexPath.row];
        [celda aplicarTema];
        [celda configurarConGrupo:grupo total:self.totalBytes];
        return celda;
    }

    UITableViewCell *celda = [tableView dequeueReusableCellWithIdentifier:@"grande"];
    if (!celda) {
        celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:@"grande"];
    }
    IOFileItem *item = self.grandes[indexPath.row];
    celda.textLabel.text = item.name;
    celda.textLabel.font = [tema fontHeadline];
    celda.textLabel.textColor = tema.textPrimary;
    celda.detailTextLabel.text = [item.path stringByDeletingLastPathComponent];
    celda.detailTextLabel.font = [tema fontSubhead];
    celda.detailTextLabel.textColor = tema.textSecondary;
    celda.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    celda.imageView.image = [[IOFileIcons shared] fileIconForItem:item size:30.0];
    celda.backgroundColor = tema.cardBackground;
    celda.contentView.backgroundColor = tema.cardBackground;
    UIView *fondo = [[UIView alloc] init];
    fondo.backgroundColor = tema.selectionFill;
    celda.selectedBackgroundView = fondo;
    celda.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return celda;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 ? 68.0 : 60.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        IOAnalyzerGroup *grupo = self.grupos[indexPath.row];
        [self abrirGrupo:grupo];
        return;
    }
    IOFileItem *item = self.grandes[indexPath.row];
    IOFilesViewController *vc = [[IOFilesViewController alloc]
                                 initWithPath:[item.path stringByDeletingLastPathComponent]];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)abrirGrupo:(IOAnalyzerGroup *)grupo {
    IOAnalyzerCategoryViewController *vc =
        [[IOAnalyzerCategoryViewController alloc] initWithTitle:grupo.title
                                                           files:grupo.files];
    __weak IOAnalyzerViewController *debil = self;
    vc.onDelete = ^{ [debil iniciarAnalisis]; };
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)elegirCarpeta {
    NSArray *opciones = @[
        @[ @"Medios (/var/mobile/Media)", @"/var/mobile/Media" ],
        @[ @"Documentos", @"/var/mobile/Documents" ],
        @[ @"Datos de usuario", @"/var/mobile" ],
        @[ @"Caches", @"/var/mobile/Library/Caches" ],
        @[ @"Temporales (/tmp)", @"/tmp" ],
        @[ @"Toda la raiz (/)", @"/" ]
    ];
    NSMutableArray *acciones = [NSMutableArray array];
    __weak IOAnalyzerViewController *debil = self;
    for (NSArray *opcion in opciones) {
        NSString *titulo = opcion[0];
        NSString *ruta = opcion[1];
        IODialogAction *accion = [IODialogAction actionWithTitle:titulo
            style:([self.path isEqualToString:ruta] ? IODialogActionStyleSelected
                                                    : IODialogActionStyleDefault)
            handler:^{ [debil confirmarCarpeta:ruta]; }];
        [acciones addObject:accion];
    }
    [IODialog showSheetIn:self title:@"Analizar carpeta" actions:acciones];
}

- (void)confirmarCarpeta:(NSString *)ruta {
    if ([[IOFileSystem shared] isProtectedPath:ruta] || [ruta isEqualToString:@"/"]) {
        __weak IOAnalyzerViewController *debil = self;
        [IODialog showConfirmIn:self
                          title:@"Zona amplia"
                        message:@"Se analizara todo el sistema, pero se omitiran las carpetas criticas. Aun asi, revisa siempre lo que seleccionas antes de borrar."
                    destructive:NO
                   confirmTitle:@"Analizar"
                        handler:^{ [debil cambiarA:ruta]; }];
        return;
    }
    [self cambiarA:ruta];
}

- (void)cambiarA:(NSString *)ruta {
    self.path = ruta;
    [self iniciarAnalisis];
}

@end

#pragma mark - Lista de una categoria

@interface IOAnalyzerCategoryViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *tituloGrupo;
@property (nonatomic, strong) NSArray<IOFileItem *> *archivos;
@property (nonatomic, strong) UITableView *tabla;
@property (nonatomic, strong) UIToolbar *barra;
@property (nonatomic, strong) NSMutableArray<IOFileItem *> *seleccionados;
@property (nonatomic, strong) UIBarButtonItem *botonBorrar;
@end

@implementation IOAnalyzerCategoryViewController

- (instancetype)initWithTitle:(NSString *)title files:(NSArray<IOFileItem *> *)files {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _tituloGrupo = [title copy];
        _archivos = [files copy];
        _seleccionados = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.tituloGrupo;
    self.view.backgroundColor = [IOTheme shared].background;

    self.tabla = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tabla.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabla.dataSource = self;
    self.tabla.delegate = self;
    self.tabla.rowHeight = 62.0;
    self.tabla.allowsMultipleSelectionDuringEditing = YES;
    self.tabla.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.tabla setEditing:YES animated:NO];
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
            attribute:NSLayoutAttributeBottom multiplier:1 constant:-44]
    ]];

    self.barra = [[UIToolbar alloc] init];
    self.barra.translatesAutoresizingMaskIntoConstraints = NO;
    self.barra.translucent = NO;
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
            attribute:NSLayoutAttributeBottom multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.barra attribute:NSLayoutAttributeHeight
            relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute
            multiplier:1 constant:44]
    ]];

    UIBarButtonItem *todo = [[UIBarButtonItem alloc] initWithTitle:@"Todo"
        style:UIBarButtonItemStylePlain target:self action:@selector(seleccionarTodo)];
    UIBarButtonItem *nada = [[UIBarButtonItem alloc] initWithTitle:@"Nada"
        style:UIBarButtonItemStylePlain target:self action:@selector(seleccionarNada)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:
        UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    self.botonBorrar = [[UIBarButtonItem alloc] initWithTitle:@"Borrar"
        style:UIBarButtonItemStylePlain target:self action:@selector(confirmarBorrado)];
    self.botonBorrar.tintColor = [IOTheme shared].danger;
    self.botonBorrar.enabled = NO;
    self.barra.items = @[ todo, flex, nada, flex, self.botonBorrar ];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];

    [self aplicarTema];
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
    self.barra.barTintColor = tema.cardBackground;
    self.barra.barStyle = tema.dark ? UIBarStyleBlack : UIBarStyleDefault;
    self.barra.tintColor = tema.accent;
    self.botonBorrar.tintColor = tema.danger;
    [self.tabla reloadData];
}

#pragma mark - Tabla

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.archivos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IOTheme *tema = [IOTheme shared];
    UITableViewCell *celda = [tableView dequeueReusableCellWithIdentifier:@"archivo"];
    if (!celda) {
        celda = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                       reuseIdentifier:@"archivo"];
    }
    IOFileItem *item = self.archivos[indexPath.row];
    celda.textLabel.text = item.name;
    celda.textLabel.font = [tema fontHeadline];
    celda.textLabel.textColor = tema.textPrimary;
    celda.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@",
        [item.path stringByDeletingLastPathComponent], [IOHelpers humanSize:item.size]];
    celda.detailTextLabel.font = [tema fontSubhead];
    celda.detailTextLabel.textColor = tema.textSecondary;
    celda.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    celda.imageView.image = [[IOFileIcons shared] fileIconForItem:item size:30.0];
    celda.backgroundColor = tema.cardBackground;
    celda.contentView.backgroundColor = tema.cardBackground;
    UIView *fondo = [[UIView alloc] init];
    fondo.backgroundColor = tema.selectionFill;
    celda.selectedBackgroundView = fondo;
    celda.tintColor = tema.accent;
    return celda;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    IOFileItem *item = self.archivos[indexPath.row];
    if (![self.seleccionados containsObject:item]) {
        [self.seleccionados addObject:item];
    }
    [self actualizarBarra];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    IOFileItem *item = self.archivos[indexPath.row];
    [self.seleccionados removeObject:item];
    [self actualizarBarra];
}

- (void)seleccionarTodo {
    [self.seleccionados removeAllObjects];
    for (NSUInteger i = 0; i < self.archivos.count; i++) {
        NSIndexPath *indice = [NSIndexPath indexPathForRow:(NSInteger)i inSection:0];
        [self.tabla selectRowAtIndexPath:indice animated:NO
                          scrollPosition:UITableViewScrollPositionNone];
        [self.seleccionados addObject:self.archivos[i]];
    }
    [self actualizarBarra];
}

- (void)seleccionarNada {
    [self.seleccionados removeAllObjects];
    for (NSUInteger i = 0; i < self.archivos.count; i++) {
        NSIndexPath *indice = [NSIndexPath indexPathForRow:(NSInteger)i inSection:0];
        [self.tabla deselectRowAtIndexPath:indice animated:NO];
    }
    [self actualizarBarra];
}

- (void)actualizarBarra {
    unsigned long long total = 0;
    for (IOFileItem *item in self.seleccionados) { total += item.size; }
    self.botonBorrar.title = self.seleccionados.count
        ? [NSString stringWithFormat:@"Borrar (%@)", [IOHelpers humanSize:total]]
        : @"Borrar";
    self.botonBorrar.enabled = (self.seleccionados.count > 0);
}

- (void)confirmarBorrado {
    if (self.seleccionados.count == 0) { return; }
    unsigned long long total = 0;
    for (IOFileItem *item in self.seleccionados) { total += item.size; }

    NSMutableString *lista = [NSMutableString string];
    NSUInteger limite = MIN(self.seleccionados.count, (NSUInteger)8);
    for (NSUInteger i = 0; i < limite; i++) {
        [lista appendFormat:@"\n· %@", self.seleccionados[i].name];
    }
    if (self.seleccionados.count > limite) {
        [lista appendFormat:@"\n... y %lu mas",
            (unsigned long)(self.seleccionados.count - limite)];
    }

    NSString *mensaje = [NSString stringWithFormat:
        @"Se borraran %lu archivos (%@) para siempre.\n\n%@",
        (unsigned long)self.seleccionados.count,
        [IOHelpers humanSize:total], lista];

    __weak IOAnalyzerCategoryViewController *debil = self;
    [IODialog showConfirmIn:self
                      title:@"Borrar archivos"
                    message:mensaje
                destructive:YES
               confirmTitle:@"Borrar definitivamente"
                    handler:^{ [debil borrarSeleccionados]; }];
}

- (void)borrarSeleccionados {
    NSArray *items = [self.seleccionados copy];
    IOProgressHUD *hud = [IOProgressHUD shared];
    [hud showInView:self.view message:@"Borrando archivos..."];
    [hud updateProgress:-1.0];
    __weak IOAnalyzerCategoryViewController *debil = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        IOFileSystem *fs = [IOFileSystem shared];
        NSError *ultimo = nil;
        NSUInteger borrados = 0;
        for (IOFileItem *item in items) {
            if (![fs removeItemAtPath:item.path error:&ultimo]) {
                // Si falla uno, se continua con el resto.
                continue;
            }
            borrados++;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [[IOProgressHUD shared] hide];
            IOAnalyzerCategoryViewController *fuerte = debil;
            if (!fuerte) { return; }
            UINavigationController *nav = fuerte.navigationController;
            [nav popViewControllerAnimated:NO];
            if (fuerte.onDelete) { fuerte.onDelete(); }
            if (borrados < items.count) {
                UIViewController *destino = nav.topViewController ?: fuerte;
                [IODialog showAlertIn:destino
                    title:@"Borrado incompleto"
                    message:[NSString stringWithFormat:
                        @"Se borraron %lu de %lu archivos. %@",
                        (unsigned long)borrados, (unsigned long)items.count,
                        ultimo.localizedDescription ?: @""]];
            }
        });
    });
}

@end
