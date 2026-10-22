#import "IOTextEditorViewController.h"

#import "IOTheme.h"
#import "IOHelpers.h"
#import "IOFileSystem.h"
#import "IOFileIcons.h"

@interface IOTextEditorViewController () <UITextViewDelegate, UISearchBarDelegate>

@property (nonatomic, copy) NSString *ruta;
@property (nonatomic, strong) UITextView *texto;
@property (nonatomic, strong) UIToolbar *barra;
@property (nonatomic, strong) UISearchBar *buscador;
@property (nonatomic, assign) BOOL esEscribible;
@property (nonatomic, assign) BOOL sucio;
@property (nonatomic, assign) CGFloat tamanoFuente;
@property (nonatomic, assign) NSRange ultimaBusqueda;

@end

@implementation IOTextEditorViewController

- (instancetype)initWithPath:(NSString *)path {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _ruta = [path copy];
        _tamanoFuente = 14.0;
        _ultimaBusqueda = NSMakeRange(0, 0);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    IOTheme *tema = [IOTheme shared];
    self.view.backgroundColor = tema.cardBackground;

    self.texto = [[UITextView alloc] init];
    self.texto.translatesAutoresizingMaskIntoConstraints = NO;
    self.texto.delegate = self;
    self.texto.alwaysBounceVertical = YES;
    self.texto.autocorrectionType = UITextAutocorrectionTypeNo;
    self.texto.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.texto.spellCheckingType = UITextSpellCheckingTypeNo;
    self.texto.textContainerInset = UIEdgeInsetsMake(12, 12, 24, 12);
    [self.view addSubview:self.texto];

    [self.view addConstraints:@[
        [NSLayoutConstraint constraintWithItem:self.texto attribute:NSLayoutAttributeTop
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeTop multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.texto attribute:NSLayoutAttributeLeading
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeLeading multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.texto attribute:NSLayoutAttributeTrailing
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeTrailing multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.texto attribute:NSLayoutAttributeBottom
            relatedBy:NSLayoutRelationEqual toItem:self.view
            attribute:NSLayoutAttributeBottom multiplier:1 constant:0]
    ]];

    [self construirBarra];
    [self cargarArchivo];
    [self aplicarTema];
    [self actualizarTitulo];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(aplicarTema)
            name:IOThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(tecladoCambia:)
            name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)construirBarra {
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
            attribute:NSLayoutAttributeBottom multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.barra attribute:NSLayoutAttributeHeight
            relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute
            multiplier:1 constant:44]
    ]];

    UIBarButtonItem *buscar = [self itemGlifo:IOGlyphSearch accion:@selector(toggleBuscar)];
    UIBarButtonItem *menos = [[UIBarButtonItem alloc] initWithTitle:@"A-"
        style:UIBarButtonItemStylePlain target:self action:@selector(menosFuente)];
    UIBarButtonItem *mas = [[UIBarButtonItem alloc] initWithTitle:@"A+"
        style:UIBarButtonItemStylePlain target:self action:@selector(masFuente)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *flex2 = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    self.barra.items = @[ buscar, flex, menos, flex2, mas ];
}

- (UIBarButtonItem *)itemGlifo:(IOGlyph)glifo accion:(SEL)accion {
    UIImage *imagen = [[IOFileIcons shared] glyph:glifo size:22.0
                                            color:[UIColor blackColor]];
    imagen = [imagen imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return [[UIBarButtonItem alloc] initWithImage:imagen style:UIBarButtonItemStylePlain
                                           target:self action:accion];
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.view.backgroundColor = tema.cardBackground;
    self.texto.backgroundColor = tema.cardBackground;
    self.texto.textColor = tema.textPrimary;
    self.texto.font = [tema fontMono:self.tamanoFuente];
    self.barra.barTintColor = tema.cardBackground;
    self.barra.tintColor = tema.accent;
    self.barra.barStyle = tema.dark ? UIBarStyleBlack : UIBarStyleDefault;
}

- (void)actualizarTitulo {
    UILabel *titulo = [[UILabel alloc] init];
    titulo.text = [self.ruta lastPathComponent];
    titulo.font = [IOTheme shared].fontNavTitle;
    titulo.textColor = [IOTheme shared].textPrimary;
    titulo.textAlignment = NSTextAlignmentCenter;

    UILabel *subtitulo = [[UILabel alloc] init];
    subtitulo.text = self.ruta;
    subtitulo.font = [UIFont systemFontOfSize:11.0];
    subtitulo.textColor = [IOTheme shared].textSecondary;
    subtitulo.textAlignment = NSTextAlignmentCenter;
    subtitulo.lineBreakMode = NSLineBreakByTruncatingMiddle;

    UIView *contenedor = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 240, 40)];
    titulo.frame = CGRectMake(0, 0, 240, 22);
    subtitulo.frame = CGRectMake(0, 20, 240, 14);
    [contenedor addSubview:titulo];
    [contenedor addSubview:subtitulo];
    self.navigationItem.titleView = contenedor;
}

#pragma mark - Carga y guardado

- (void)cargarArchivo {
    BOOL esDir = NO;
    [[IOFileSystem shared] fileExistsAtPath:self.ruta isDirectory:&esDir];

    NSData *datos = [NSData dataWithContentsOfFile:self.ruta];
    if (!datos) {
        self.texto.text = @"No se pudo leer el archivo.";
        self.texto.editable = NO;
        return;
    }

    NSString *contenido = [[NSString alloc] initWithData:datos encoding:NSUTF8StringEncoding];
    if (!contenido) {
        contenido = [[NSString alloc] initWithData:datos encoding:NSISOLatin1StringEncoding];
    }
    if (!contenido) {
        self.texto.text = @"Este archivo no es texto legible.";
        self.texto.editable = NO;
        return;
    }

    self.texto.text = contenido;

    IOFileItem *item = [[IOFileSystem shared] itemAtPath:self.ruta];
    self.esEscribible = item.isWritable && !esDir;
    self.texto.editable = self.esEscribible;

    if (self.esEscribible) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
            initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                 target:self action:@selector(guardar)];
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
}

- (void)guardar {
    if (!self.esEscribible) { return; }
    NSError *error = nil;
    NSData *datos = [self.texto.text dataUsingEncoding:NSUTF8StringEncoding];
    if ([[IOFileSystem shared] writeData:datos toPath:self.ruta error:&error]) {
        self.sucio = NO;
        self.navigationItem.rightBarButtonItem.enabled = NO;
    } else {
        UIAlertController *alerta = [UIAlertController
            alertControllerWithTitle:@"No se pudo guardar"
                             message:error.localizedDescription
                      preferredStyle:UIAlertControllerStyleAlert];
        [alerta addAction:[UIAlertAction actionWithTitle:@"Vale"
            style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alerta animated:YES completion:nil];
    }
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    if (!self.esEscribible) { return; }
    self.sucio = YES;
    self.navigationItem.rightBarButtonItem.enabled = YES;
}

#pragma mark - Buscar

- (void)toggleBuscar {
    if (self.buscador) {
        [self cerrarBuscar];
        return;
    }
    self.buscador = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 260, 44)];
    self.buscador.delegate = self;
    self.buscador.placeholder = @"Buscar en el texto";
    self.buscador.showsCancelButton = YES;
    self.buscador.searchBarStyle = UISearchBarStyleMinimal;
    self.navigationItem.titleView = self.buscador;
    [self.buscador becomeFirstResponder];
}

- (void)cerrarBuscar {
    self.buscador = nil;
    [self actualizarTitulo];
    self.ultimaBusqueda = NSMakeRange(0, 0);
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self cerrarBuscar];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self buscarTexto:searchBar.text desde:self.ultimaBusqueda.location];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self buscarTexto:searchText desde:0];
}

- (void)buscarTexto:(NSString *)aguja desde:(NSUInteger)inicio {
    NSString *texto = self.texto.text ?: @"";
    if (aguja.length == 0) {
        self.texto.selectedRange = NSMakeRange(0, 0);
        return;
    }
    NSRange rango = NSMakeRange(0, texto.length);
    if (inicio >= texto.length) { inicio = 0; }
    NSRange encontrado = [texto rangeOfString:aguja
                                       options:NSCaseInsensitiveSearch
                                         range:NSMakeRange(inicio, texto.length - inicio)];
    if (encontrado.location == NSNotFound) {
        encontrado = [texto rangeOfString:aguja options:NSCaseInsensitiveSearch range:rango];
    }
    if (encontrado.location == NSNotFound) { return; }
    self.ultimaBusqueda = encontrado;
    [self.texto scrollRangeToVisible:encontrado];
    self.texto.selectedRange = encontrado;
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar { return YES; }

#pragma mark - Fuente

- (void)menosFuente {
    self.tamanoFuente = MAX(10.0, self.tamanoFuente - 2.0);
    [self aplicarTema];
}

- (void)masFuente {
    self.tamanoFuente = MIN(28.0, self.tamanoFuente + 2.0);
    [self aplicarTema];
}

#pragma mark - Teclado

- (void)tecladoCambia:(NSNotification *)notificacion {
    NSDictionary *info = notificacion.userInfo;
    CGRect marcoFinal = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect marcoEnVista = [self.view convertRect:marcoFinal fromView:nil];
    CGFloat interseccion = CGRectGetHeight(self.view.bounds) - CGRectGetMinY(marcoEnVista);
    CGFloat fondo = MAX(0.0, interseccion);
    self.texto.contentInset = UIEdgeInsetsMake(0, 0, fondo, 0);
    self.texto.scrollIndicatorInsets = self.texto.contentInset;
}

@end
