#import "IOSidebarViewController.h"

#import "IOTheme.h"
#import "IOStore.h"
#import "IOFileSystem.h"
#import "IOFileIcons.h"
#import "IOHelpers.h"

#pragma mark - Celda del panel lateral

@interface IOSidebarCell : UITableViewCell
@property (nonatomic, strong) UIImageView *iconoVista;
@property (nonatomic, strong) UILabel *titulo;
@property (nonatomic, strong) UILabel *contador;
@property (nonatomic, assign) IOGlyph glifo;
@property (nonatomic, assign) BOOL esFavorito;
- (void)aplicarTema;
@end

@implementation IOSidebarCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
               reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        self.iconoVista = [[UIImageView alloc] init];
        self.iconoVista.translatesAutoresizingMaskIntoConstraints = NO;
        self.iconoVista.contentMode = UIViewContentModeCenter;
        [self.contentView addSubview:self.iconoVista];

        self.titulo = [[UILabel alloc] init];
        self.titulo.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.titulo];

        self.contador = [[UILabel alloc] init];
        self.contador.translatesAutoresizingMaskIntoConstraints = NO;
        self.contador.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:self.contador];

        [self.contentView addConstraints:@[
            [NSLayoutConstraint constraintWithItem:self.iconoVista attribute:NSLayoutAttributeLeading
                relatedBy:NSLayoutRelationEqual toItem:self.contentView
                attribute:NSLayoutAttributeLeading multiplier:1 constant:16],
            [NSLayoutConstraint constraintWithItem:self.iconoVista attribute:NSLayoutAttributeCenterY
                relatedBy:NSLayoutRelationEqual toItem:self.contentView
                attribute:NSLayoutAttributeCenterY multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:self.iconoVista attribute:NSLayoutAttributeWidth
                relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute
                multiplier:1 constant:24],
            [NSLayoutConstraint constraintWithItem:self.iconoVista attribute:NSLayoutAttributeHeight
                relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute
                multiplier:1 constant:24],

            [NSLayoutConstraint constraintWithItem:self.titulo attribute:NSLayoutAttributeLeading
                relatedBy:NSLayoutRelationEqual toItem:self.iconoVista
                attribute:NSLayoutAttributeTrailing multiplier:1 constant:12],
            [NSLayoutConstraint constraintWithItem:self.titulo attribute:NSLayoutAttributeCenterY
                relatedBy:NSLayoutRelationEqual toItem:self.contentView
                attribute:NSLayoutAttributeCenterY multiplier:1 constant:0],
            [NSLayoutConstraint constraintWithItem:self.titulo attribute:NSLayoutAttributeTrailing
                relatedBy:NSLayoutRelationLessThanOrEqual toItem:self.contador
                attribute:NSLayoutAttributeLeading multiplier:1 constant:-8],

            [NSLayoutConstraint constraintWithItem:self.contador attribute:NSLayoutAttributeTrailing
                relatedBy:NSLayoutRelationEqual toItem:self.contentView
                attribute:NSLayoutAttributeTrailing multiplier:1 constant:-16],
            [NSLayoutConstraint constraintWithItem:self.contador attribute:NSLayoutAttributeCenterY
                relatedBy:NSLayoutRelationEqual toItem:self.contentView
                attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]
        ]];
    }
    return self;
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.titulo.font = [tema fontBody];
    self.titulo.textColor = tema.textPrimary;
    self.contador.font = [tema fontSubhead];
    self.contador.textColor = tema.textTertiary;
    [self actualizarIcono];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    [self actualizarFondo];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    [self actualizarFondo];
}

- (void)actualizarFondo {
    IOTheme *tema = [IOTheme shared];
    BOOL activa = (self.selected || self.highlighted);
    self.contentView.backgroundColor = activa ? tema.accentSoft : [UIColor clearColor];
    self.titulo.textColor = activa ? tema.accent : tema.textPrimary;
    [self actualizarIcono];
}

- (void)actualizarIcono {
    IOTheme *tema = [IOTheme shared];
    BOOL activa = (self.selected || self.highlighted);
    UIColor *color = activa ? tema.accent : [IOFileIcons colorForGlyph:self.glifo];
    if (self.esFavorito) {
        color = activa ? tema.accent : [IOTheme colorWithHex:0xFFB300 alpha:1.0];
    }
    self.iconoVista.image = [[IOFileIcons shared] glyph:self.glifo size:22.0 color:color];
}

@end

#pragma mark - Panel lateral

static NSString * const IOSidebarHomePath = @"io.iopensfiles.inicio";

typedef NS_ENUM(NSInteger, IOSidebarSection) {
    IOSidebarSectionLugares = 0,
    IOSidebarSectionFavoritos,
    IOSidebarSectionRecientes
};

@interface IOSidebarViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tabla;
@property (nonatomic, strong) UIView *cabecera;
@property (nonatomic, strong) UILabel *cabeceraTitulo;
@property (nonatomic, strong) UILabel *cabeceraDetalle;
@property (nonatomic, strong) NSArray *lugares;
@end

@implementation IOSidebarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [IOTheme shared].sidebarBackground;

    [self construirLugares];

    self.tabla = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tabla.translatesAutoresizingMaskIntoConstraints = NO;
    self.tabla.dataSource = self;
    self.tabla.delegate = self;
    self.tabla.backgroundColor = [UIColor clearColor];
    self.tabla.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tabla.rowHeight = 46.0;
    self.tabla.contentInset = UIEdgeInsetsMake(6, 0, 24, 0);
    [self.tabla registerClass:[IOSidebarCell class] forCellReuseIdentifier:@"side"];
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
    [self reloadData];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)construirLugares {
    self.lugares = @[
        @{ @"t": @"Inicio",         @"p": IOSidebarHomePath,                 @"g": @(IOGlyphHome) },
        @{ @"t": @"Raiz",           @"p": @"/",                              @"g": @(IOGlyphRoot) },
        @{ @"t": @"Medios",         @"p": @"/var/mobile/Media",              @"g": @(IOGlyphFolder) },
        @{ @"t": @"Documentos",     @"p": @"/var/mobile/Documents",          @"g": @(IOGlyphText) },
        @{ @"t": @"Aplicaciones",   @"p": @"/Applications",                  @"g": @(IOGlyphApp) },
        @{ @"t": @"Biblioteca",     @"p": @"/var/mobile/Library",            @"g": @(IOGlyphFolder) },
        @{ @"t": @"Preferencias",   @"p": @"/var/mobile/Library/Preferences",@"g": @(IOGlyphPlist) },
        @{ @"t": @"Contenedores",   @"p": @"/var/mobile/Containers",         @"g": @(IOGlyphDisk) },
        @{ @"t": @"Sistema",        @"p": @"/System",                        @"g": @(IOGlyphGear) },
        @{ @"t": @"Raiz privada",   @"p": @"/private/var",                   @"g": @(IOGlyphDisk) }
    ];
}

- (void)construirCabecera {
    CGFloat ancho = [IOTheme shared].sidebarWidth;
    self.cabecera = [[UIView alloc] initWithFrame:CGRectMake(0, 0, ancho, 92)];

    self.cabeceraTitulo = [[UILabel alloc] initWithFrame:CGRectMake(18, 22, ancho - 36, 30)];
    self.cabeceraTitulo.text = @"IOpenFiles";
    [self.cabecera addSubview:self.cabeceraTitulo];

    self.cabeceraDetalle = [[UILabel alloc] initWithFrame:CGRectMake(18, 52, ancho - 36, 20)];
    [self.cabecera addSubview:self.cabeceraDetalle];

    self.tabla.tableHeaderView = self.cabecera;
    [self aplicarTema];
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.view.backgroundColor = tema.sidebarBackground;
    self.tabla.backgroundColor = [UIColor clearColor];
    self.cabecera.backgroundColor = [UIColor clearColor];
    self.cabeceraTitulo.font = [UIFont systemFontOfSize:26.0 weight:UIFontWeightBold];
    self.cabeceraTitulo.textColor = tema.textPrimary;
    self.cabeceraDetalle.font = [tema fontSubhead];
    self.cabeceraDetalle.textColor = tema.textSecondary;
    [self actualizarDetalleCabecera];
    [self.tabla reloadData];
}

- (void)actualizarDetalleCabecera {
    unsigned long long libre = [[IOFileSystem shared] freeSpaceAtPath:@"/"];
    unsigned long long total = [[IOFileSystem shared] totalSpaceAtPath:@"/"];
    if (total > 0) {
        self.cabeceraDetalle.text = [NSString stringWithFormat:@"%@ libres de %@",
                                     [IOHelpers humanSize:libre], [IOHelpers humanSize:total]];
    } else {
        self.cabeceraDetalle.text = @"Gestor de archivos";
    }
}

- (void)reloadData {
    [self actualizarDetalleCabecera];
    [self.tabla reloadData];
}

- (void)setSelectedPath:(NSString *)selectedPath {
    _selectedPath = [selectedPath copy];
    [self.tabla reloadData];
}

#pragma mark - Tabla

- (NSArray *)filasDeSeccion:(NSInteger)seccion {
    if (seccion == IOSidebarSectionLugares) { return self.lugares; }
    if (seccion == IOSidebarSectionFavoritos) { return [IOStore shared].favorites; }
    return [IOStore shared].recents;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self filasDeSeccion:section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == IOSidebarSectionLugares) { return @"LUGARES"; }
    if (section == IOSidebarSectionFavoritos) { return @"FAVORITOS"; }
    return @"RECIENTES";
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view
       forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *cabecera = (UITableViewHeaderFooterView *)view;
        cabecera.textLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
        cabecera.textLabel.textColor = [IOTheme shared].textTertiary;
        cabecera.contentView.backgroundColor = [UIColor clearColor];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if ([self tableView:tableView numberOfRowsInSection:section] == 0) { return 8.0; }
    return 30.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IOSidebarCell *celda = [tableView dequeueReusableCellWithIdentifier:@"side"
                                                          forIndexPath:indexPath];
    NSArray *filas = [self filasDeSeccion:indexPath.section];

    if (indexPath.section == IOSidebarSectionLugares) {
        NSDictionary *fila = filas[indexPath.row];
        celda.titulo.text = fila[@"t"];
        celda.glifo = (IOGlyph)[fila[@"g"] integerValue];
        celda.esFavorito = NO;
        celda.contador.text = @"";
        BOOL esInicio = [fila[@"p"] isEqualToString:IOSidebarHomePath];
        celda.selected = esInicio ? (self.selectedPath.length == 0)
                                  : [self.selectedPath isEqualToString:fila[@"p"]];
    } else {
        NSString *ruta = filas[indexPath.row];
        celda.titulo.text = [ruta lastPathComponent];
        celda.glifo = (indexPath.section == IOSidebarSectionFavoritos)
            ? IOGlyphStar : IOGlyphClock;
        celda.esFavorito = (indexPath.section == IOSidebarSectionFavoritos);
        celda.contador.text = @"";
        celda.selected = [self.selectedPath isEqualToString:ruta];
    }

    [celda aplicarTema];
    [celda actualizarFondo];
    return celda;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *filas = [self filasDeSeccion:indexPath.section];
    NSString *ruta = nil;
    if (indexPath.section == IOSidebarSectionLugares) {
        ruta = filas[indexPath.row][@"p"];
    } else {
        ruta = filas[indexPath.row];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if ([ruta isEqualToString:IOSidebarHomePath]) {
        self.selectedPath = nil;
        [tableView reloadData];
        if ([self.delegate respondsToSelector:@selector(sidebarDidSelectHome:)]) {
            [self.delegate sidebarDidSelectHome:self];
        }
        return;
    }

    self.selectedPath = ruta;
    [tableView reloadData];
    if (self.delegate) {
        [self.delegate sidebar:self didSelectPath:ruta];
    }
}

- (BOOL)tableView:(UITableView *)tableView
       canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section != IOSidebarSectionLugares;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView
     commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
      forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *filas = [self filasDeSeccion:indexPath.section];
    if (indexPath.row >= (NSInteger)filas.count) { return; }
    NSString *ruta = filas[indexPath.row];
    if (indexPath.section == IOSidebarSectionFavoritos) {
        [[IOStore shared] removeFavorite:ruta];
    } else {
        // Quitar de recientes reescribiendo la lista sin ese elemento.
        NSMutableArray *recientes = [[IOStore shared].recents mutableCopy];
        [recientes removeObject:ruta];
        [[NSUserDefaults standardUserDefaults] setObject:recientes forKey:@"IO.recents"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    [tableView reloadData];
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView
                  editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == IOSidebarSectionLugares) { return nil; }
    __weak IOSidebarViewController *debil = self;
    UITableViewRowAction *quitar = [UITableViewRowAction
        rowActionWithStyle:UITableViewRowActionStyleDestructive
                     title:@"Quitar"
                   handler:^(UITableViewRowAction *accion, NSIndexPath *indice) {
        [debil tableView:tableView commitEditingStyle:UITableViewCellEditingStyleDelete
        forRowAtIndexPath:indice];
    }];
    return @[ quitar ];
}

@end
