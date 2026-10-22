#import "IOFileIcons.h"
#import "IOTheme.h"
#import "IOHelpers.h"

#import <ImageIO/ImageIO.h>

#pragma mark - Construccion de caminos (coordenadas 0..1)

static void IOLinea(UIBezierPath *p, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2) {
    [p moveToPoint:CGPointMake(x1, y1)];
    [p addLineToPoint:CGPointMake(x2, y2)];
}

static void IOPunto(UIBezierPath *p, CGFloat x, CGFloat y) {
    [p moveToPoint:CGPointMake(x, y)];
    [p addLineToPoint:CGPointMake(x, y)];
}

static void IOCirculo(UIBezierPath *p, CGFloat cx, CGFloat cy, CGFloat r) {
    [p moveToPoint:CGPointMake(cx + r, cy)];
    [p addArcWithCenter:CGPointMake(cx, cy) radius:r
            startAngle:0 endAngle:(CGFloat)(2 * M_PI) clockwise:YES];
    [p closePath];
}

static void IORectRedondeado(UIBezierPath *p, CGFloat x, CGFloat y,
                             CGFloat w, CGFloat h, CGFloat r) {
    [p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(x, y, w, h)
                                             cornerRadius:r]];
}

static UIBezierPath *IOCaminoCarpeta(void) {
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(0.10, 0.82)];
    [p addLineToPoint:CGPointMake(0.10, 0.24)];
    [p addLineToPoint:CGPointMake(0.40, 0.24)];
    [p addLineToPoint:CGPointMake(0.50, 0.36)];
    [p addLineToPoint:CGPointMake(0.90, 0.36)];
    [p addLineToPoint:CGPointMake(0.90, 0.82)];
    [p closePath];
    return p;
}

static UIBezierPath *IOUnitPathForGlyph(IOGlyph glyph) {
    UIBezierPath *p = [UIBezierPath bezierPath];

    switch (glyph) {
        case IOGlyphFolder:
            p = IOCaminoCarpeta();
            break;

        case IOGlyphImage:
            IORectRedondeado(p, 0.10, 0.18, 0.80, 0.64, 0.11);
            IOCirculo(p, 0.34, 0.37, 0.075);
            [p moveToPoint:CGPointMake(0.16, 0.74)];
            [p addLineToPoint:CGPointMake(0.38, 0.50)];
            [p addLineToPoint:CGPointMake(0.52, 0.64)];
            [p addLineToPoint:CGPointMake(0.66, 0.46)];
            [p addLineToPoint:CGPointMake(0.86, 0.74)];
            break;

        case IOGlyphVideo:
            IORectRedondeado(p, 0.08, 0.22, 0.84, 0.56, 0.13);
            [p moveToPoint:CGPointMake(0.42, 0.36)];
            [p addLineToPoint:CGPointMake(0.42, 0.64)];
            [p addLineToPoint:CGPointMake(0.64, 0.50)];
            [p closePath];
            break;

        case IOGlyphAudio:
            IOCirculo(p, 0.31, 0.70, 0.115);
            IOCirculo(p, 0.69, 0.62, 0.115);
            IOLinea(p, 0.42, 0.70, 0.42, 0.24);
            IOLinea(p, 0.80, 0.62, 0.80, 0.16);
            IOLinea(p, 0.42, 0.24, 0.80, 0.16);
            break;

        case IOGlyphText:
            IORectRedondeado(p, 0.20, 0.10, 0.60, 0.80, 0.09);
            IOLinea(p, 0.32, 0.34, 0.68, 0.34);
            IOLinea(p, 0.32, 0.48, 0.68, 0.48);
            IOLinea(p, 0.32, 0.62, 0.68, 0.62);
            IOLinea(p, 0.32, 0.76, 0.54, 0.76);
            break;

        case IOGlyphCode:
            [p moveToPoint:CGPointMake(0.36, 0.30)];
            [p addLineToPoint:CGPointMake(0.14, 0.50)];
            [p addLineToPoint:CGPointMake(0.36, 0.70)];
            [p moveToPoint:CGPointMake(0.64, 0.30)];
            [p addLineToPoint:CGPointMake(0.86, 0.50)];
            [p addLineToPoint:CGPointMake(0.64, 0.70)];
            IOLinea(p, 0.56, 0.24, 0.44, 0.76);
            break;

        case IOGlyphArchive:
            IORectRedondeado(p, 0.14, 0.34, 0.72, 0.50, 0.09);
            IOLinea(p, 0.10, 0.34, 0.90, 0.34);
            IOLinea(p, 0.50, 0.20, 0.50, 0.34);
            IORectRedondeado(p, 0.43, 0.34, 0.14, 0.14, 0.04);
            break;

        case IOGlyphPlist:
            IOPunto(p, 0.20, 0.30); IOLinea(p, 0.38, 0.30, 0.82, 0.30);
            IOPunto(p, 0.20, 0.50); IOLinea(p, 0.38, 0.50, 0.82, 0.50);
            IOPunto(p, 0.20, 0.70); IOLinea(p, 0.38, 0.70, 0.82, 0.70);
            break;

        case IOGlyphApp:
        case IOGlyphGrid:
            IORectRedondeado(p, 0.16, 0.16, 0.30, 0.30, 0.09);
            IORectRedondeado(p, 0.54, 0.16, 0.30, 0.30, 0.09);
            IORectRedondeado(p, 0.16, 0.54, 0.30, 0.30, 0.09);
            IORectRedondeado(p, 0.54, 0.54, 0.30, 0.30, 0.09);
            break;

        case IOGlyphExec:
            IORectRedondeado(p, 0.08, 0.18, 0.84, 0.64, 0.13);
            [p moveToPoint:CGPointMake(0.26, 0.40)];
            [p addLineToPoint:CGPointMake(0.40, 0.50)];
            [p addLineToPoint:CGPointMake(0.26, 0.60)];
            IOLinea(p, 0.52, 0.62, 0.74, 0.62);
            break;

        case IOGlyphFile:
            [p moveToPoint:CGPointMake(0.28, 0.10)];
            [p addLineToPoint:CGPointMake(0.60, 0.10)];
            [p addLineToPoint:CGPointMake(0.78, 0.28)];
            [p addLineToPoint:CGPointMake(0.78, 0.90)];
            [p addLineToPoint:CGPointMake(0.28, 0.90)];
            [p closePath];
            [p moveToPoint:CGPointMake(0.60, 0.10)];
            [p addLineToPoint:CGPointMake(0.60, 0.28)];
            [p addLineToPoint:CGPointMake(0.78, 0.28)];
            break;

        case IOGlyphRoot:
            IORectRedondeado(p, 0.12, 0.24, 0.76, 0.52, 0.11);
            IOLinea(p, 0.12, 0.50, 0.88, 0.50);
            IOPunto(p, 0.74, 0.64);
            IOPunto(p, 0.63, 0.64);
            break;

        case IOGlyphDisk:
            [p moveToPoint:CGPointMake(0.18, 0.29)];
            [p addLineToPoint:CGPointMake(0.18, 0.71)];
            [p addArcWithCenter:CGPointMake(0.50, 0.71) radius:0.32
                    startAngle:M_PI endAngle:0 clockwise:YES];
            [p addLineToPoint:CGPointMake(0.82, 0.29)];
            [p appendPath:[UIBezierPath bezierPathWithOvalInRect:
                     CGRectMake(0.18, 0.18, 0.64, 0.22)]];
            break;

        case IOGlyphGear:
            IOCirculo(p, 0.50, 0.50, 0.20);
            for (int i = 0; i < 8; i++) {
                CGFloat ang = (CGFloat)i * (CGFloat)(M_PI / 4.0);
                CGFloat x1 = 0.50 + cosf(ang) * 0.28;
                CGFloat y1 = 0.50 + sinf(ang) * 0.28;
                CGFloat x2 = 0.50 + cosf(ang) * 0.42;
                CGFloat y2 = 0.50 + sinf(ang) * 0.42;
                IOLinea(p, x1, y1, x2, y2);
            }
            break;

        case IOGlyphStar: {
            CGFloat cx = 0.50, cy = 0.52;
            CGFloat rExt = 0.42, rInt = 0.18;
            for (int i = 0; i < 10; i++) {
                CGFloat r = (i % 2 == 0) ? rExt : rInt;
                CGFloat ang = (CGFloat)(-M_PI / 2.0) + (CGFloat)i * (CGFloat)(M_PI / 5.0);
                CGPoint punto = CGPointMake(cx + cosf(ang) * r, cy + sinf(ang) * r);
                if (i == 0) { [p moveToPoint:punto]; } else { [p addLineToPoint:punto]; }
            }
            [p closePath];
            break;
        }

        case IOGlyphClock:
            IOCirculo(p, 0.50, 0.50, 0.38);
            IOLinea(p, 0.50, 0.50, 0.50, 0.26);
            IOLinea(p, 0.50, 0.50, 0.68, 0.60);
            break;

        case IOGlyphTrash:
            IOLinea(p, 0.20, 0.28, 0.80, 0.28);
            [p moveToPoint:CGPointMake(0.40, 0.28)];
            [p addLineToPoint:CGPointMake(0.40, 0.18)];
            [p addLineToPoint:CGPointMake(0.60, 0.18)];
            [p addLineToPoint:CGPointMake(0.60, 0.28)];
            [p moveToPoint:CGPointMake(0.28, 0.28)];
            [p addLineToPoint:CGPointMake(0.34, 0.86)];
            [p addLineToPoint:CGPointMake(0.66, 0.86)];
            [p addLineToPoint:CGPointMake(0.72, 0.28)];
            IOLinea(p, 0.44, 0.42, 0.44, 0.74);
            IOLinea(p, 0.56, 0.42, 0.56, 0.74);
            break;

        case IOGlyphShare:
            IOLinea(p, 0.50, 0.12, 0.50, 0.64);
            [p moveToPoint:CGPointMake(0.34, 0.28)];
            [p addLineToPoint:CGPointMake(0.50, 0.12)];
            [p addLineToPoint:CGPointMake(0.66, 0.28)];
            [p moveToPoint:CGPointMake(0.30, 0.44)];
            [p addLineToPoint:CGPointMake(0.30, 0.88)];
            [p addLineToPoint:CGPointMake(0.70, 0.88)];
            [p addLineToPoint:CGPointMake(0.70, 0.44)];
            break;

        case IOGlyphPlus:
            IOLinea(p, 0.50, 0.20, 0.50, 0.80);
            IOLinea(p, 0.20, 0.50, 0.80, 0.50);
            break;

        case IOGlyphSearch:
            IOCirculo(p, 0.44, 0.44, 0.28);
            IOLinea(p, 0.64, 0.64, 0.84, 0.84);
            break;

        case IOGlyphList:
            IOPunto(p, 0.20, 0.30); IOLinea(p, 0.36, 0.30, 0.82, 0.30);
            IOPunto(p, 0.20, 0.50); IOLinea(p, 0.36, 0.50, 0.82, 0.50);
            IOPunto(p, 0.20, 0.70); IOLinea(p, 0.36, 0.70, 0.82, 0.70);
            break;

        case IOGlyphEye:
            [p moveToPoint:CGPointMake(0.10, 0.50)];
            [p addQuadCurveToPoint:CGPointMake(0.90, 0.50)
                     controlPoint:CGPointMake(0.50, 0.14)];
            [p addQuadCurveToPoint:CGPointMake(0.10, 0.50)
                     controlPoint:CGPointMake(0.50, 0.86)];
            IOCirculo(p, 0.50, 0.50, 0.13);
            break;

        case IOGlyphLock:
            IORectRedondeado(p, 0.26, 0.46, 0.48, 0.40, 0.09);
            [p moveToPoint:CGPointMake(0.36, 0.46)];
            [p addLineToPoint:CGPointMake(0.36, 0.34)];
            [p addQuadCurveToPoint:CGPointMake(0.64, 0.34)
                     controlPoint:CGPointMake(0.50, 0.12)];
            [p addLineToPoint:CGPointMake(0.64, 0.46)];
            break;

        case IOGlyphInfo:
            IOCirculo(p, 0.50, 0.50, 0.38);
            IOPunto(p, 0.50, 0.34);
            IOLinea(p, 0.50, 0.46, 0.50, 0.68);
            break;

        case IOGlyphLink:
            IORectRedondeado(p, 0.14, 0.28, 0.58, 0.58, 0.12);
            [p moveToPoint:CGPointMake(0.52, 0.48)];
            [p addLineToPoint:CGPointMake(0.86, 0.14)];
            [p moveToPoint:CGPointMake(0.60, 0.14)];
            [p addLineToPoint:CGPointMake(0.86, 0.14)];
            [p addLineToPoint:CGPointMake(0.86, 0.40)];
            break;

        case IOGlyphChevronRight:
            [p moveToPoint:CGPointMake(0.40, 0.26)];
            [p addLineToPoint:CGPointMake(0.64, 0.50)];
            [p addLineToPoint:CGPointMake(0.40, 0.74)];
            break;

        case IOGlyphChevronLeft:
            [p moveToPoint:CGPointMake(0.60, 0.26)];
            [p addLineToPoint:CGPointMake(0.36, 0.50)];
            [p addLineToPoint:CGPointMake(0.60, 0.74)];
            break;

        case IOGlyphChevronUp:
            [p moveToPoint:CGPointMake(0.26, 0.62)];
            [p addLineToPoint:CGPointMake(0.50, 0.36)];
            [p addLineToPoint:CGPointMake(0.74, 0.62)];
            break;

        case IOGlyphChevronDown:
            [p moveToPoint:CGPointMake(0.26, 0.38)];
            [p addLineToPoint:CGPointMake(0.50, 0.64)];
            [p addLineToPoint:CGPointMake(0.74, 0.38)];
            break;

        case IOGlyphMore:
            IOPunto(p, 0.24, 0.50);
            IOPunto(p, 0.50, 0.50);
            IOPunto(p, 0.76, 0.50);
            break;

        case IOGlyphCheck:
            [p moveToPoint:CGPointMake(0.24, 0.52)];
            [p addLineToPoint:CGPointMake(0.44, 0.72)];
            [p addLineToPoint:CGPointMake(0.78, 0.30)];
            break;

        case IOGlyphMenu:
            IOLinea(p, 0.18, 0.32, 0.82, 0.32);
            IOLinea(p, 0.18, 0.50, 0.82, 0.50);
            IOLinea(p, 0.18, 0.68, 0.82, 0.68);
            break;

        case IOGlyphCopy:
            [p moveToPoint:CGPointMake(0.16, 0.60)];
            [p addLineToPoint:CGPointMake(0.16, 0.14)];
            [p addLineToPoint:CGPointMake(0.62, 0.14)];
            IORectRedondeado(p, 0.32, 0.28, 0.52, 0.58, 0.09);
            break;

        case IOGlyphPaste:
            IORectRedondeado(p, 0.20, 0.16, 0.60, 0.72, 0.10);
            IORectRedondeado(p, 0.36, 0.10, 0.28, 0.14, 0.05);
            IOLinea(p, 0.32, 0.46, 0.68, 0.46);
            IOLinea(p, 0.32, 0.60, 0.68, 0.60);
            break;

        case IOGlyphRename:
            [p moveToPoint:CGPointMake(0.22, 0.78)];
            [p addLineToPoint:CGPointMake(0.24, 0.62)];
            [p addLineToPoint:CGPointMake(0.70, 0.16)];
            [p addLineToPoint:CGPointMake(0.84, 0.30)];
            [p addLineToPoint:CGPointMake(0.38, 0.76)];
            [p closePath];
            IOLinea(p, 0.62, 0.24, 0.76, 0.38);
            break;

        case IOGlyphArrowUp:
            IOLinea(p, 0.50, 0.82, 0.50, 0.22);
            [p moveToPoint:CGPointMake(0.26, 0.46)];
            [p addLineToPoint:CGPointMake(0.50, 0.22)];
            [p addLineToPoint:CGPointMake(0.74, 0.46)];
            break;

        case IOGlyphArrowLeft:
            IOLinea(p, 0.82, 0.50, 0.22, 0.50);
            [p moveToPoint:CGPointMake(0.46, 0.26)];
            [p addLineToPoint:CGPointMake(0.22, 0.50)];
            [p addLineToPoint:CGPointMake(0.46, 0.74)];
            break;

        case IOGlyphDownload:
            IOLinea(p, 0.50, 0.16, 0.50, 0.62);
            [p moveToPoint:CGPointMake(0.26, 0.40)];
            [p addLineToPoint:CGPointMake(0.50, 0.64)];
            [p addLineToPoint:CGPointMake(0.74, 0.40)];
            [p moveToPoint:CGPointMake(0.20, 0.76)];
            [p addLineToPoint:CGPointMake(0.20, 0.86)];
            [p addLineToPoint:CGPointMake(0.80, 0.86)];
            [p addLineToPoint:CGPointMake(0.80, 0.76)];
            break;

        case IOGlyphRefresh:
            [p moveToPoint:CGPointMake(0.78, 0.50)];
            [p addArcWithCenter:CGPointMake(0.50, 0.50) radius:0.30
                    startAngle:0 endAngle:(CGFloat)(-M_PI * 1.5) clockwise:YES];
            [p moveToPoint:CGPointMake(0.66, 0.16)];
            [p addLineToPoint:CGPointMake(0.80, 0.26)];
            [p addLineToPoint:CGPointMake(0.90, 0.12)];
            break;

        case IOGlyphClose:
            IOLinea(p, 0.28, 0.28, 0.72, 0.72);
            IOLinea(p, 0.72, 0.28, 0.28, 0.72);
            break;

        case IOGlyphHome:
            [p moveToPoint:CGPointMake(0.16, 0.52)];
            [p addLineToPoint:CGPointMake(0.50, 0.18)];
            [p addLineToPoint:CGPointMake(0.84, 0.52)];
            [p moveToPoint:CGPointMake(0.26, 0.46)];
            [p addLineToPoint:CGPointMake(0.26, 0.84)];
            [p addLineToPoint:CGPointMake(0.74, 0.84)];
            [p addLineToPoint:CGPointMake(0.74, 0.46)];
            break;

        case IOGlyphNewFolder:
            IORectRedondeado(p, 0.08, 0.32, 0.84, 0.54, 0.10);
            IOLinea(p, 0.50, 0.44, 0.50, 0.74);
            IOLinea(p, 0.35, 0.59, 0.65, 0.59);
            break;

        case IOGlyphNewFile:
            [p moveToPoint:CGPointMake(0.28, 0.10)];
            [p addLineToPoint:CGPointMake(0.60, 0.10)];
            [p addLineToPoint:CGPointMake(0.78, 0.28)];
            [p addLineToPoint:CGPointMake(0.78, 0.90)];
            [p addLineToPoint:CGPointMake(0.28, 0.90)];
            [p closePath];
            IOLinea(p, 0.53, 0.46, 0.53, 0.72);
            IOLinea(p, 0.40, 0.59, 0.66, 0.59);
            break;

        case IOGlyphSelect:
            IOCirculo(p, 0.50, 0.50, 0.40);
            [p moveToPoint:CGPointMake(0.32, 0.52)];
            [p addLineToPoint:CGPointMake(0.45, 0.66)];
            [p addLineToPoint:CGPointMake(0.70, 0.36)];
            break;

        case IOGlyphFilter:
            IOLinea(p, 0.18, 0.30, 0.82, 0.30);
            IOLinea(p, 0.28, 0.50, 0.72, 0.50);
            IOLinea(p, 0.40, 0.70, 0.60, 0.70);
            break;

        default:
            p = IOCaminoCarpeta();
            break;
    }
    return p;
}

#pragma mark -

@interface IOFileIcons ()
@property (nonatomic, strong) NSMutableDictionary *cacheIconos;
@property (nonatomic, strong) NSCache *cacheMiniaturas;
@property (nonatomic, strong) dispatch_queue_t colaMiniaturas;
@end

@implementation IOFileIcons

+ (instancetype)shared {
    static IOFileIcons *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IOFileIcons alloc] init];
    });
    return instancia;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cacheIconos = [NSMutableDictionary dictionary];
        _cacheMiniaturas = [[NSCache alloc] init];
        _cacheMiniaturas.countLimit = 120;
        _colaMiniaturas = dispatch_queue_create("com.lofturb.iopensfiles.thumbnails",
                                                DISPATCH_QUEUE_SERIAL);
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(limpiarTodo)
                name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(limpiarTodo)
                name:@"IOMemoryWarningNotification" object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)limpiarTodo {
    [self.cacheMiniaturas removeAllObjects];
    [self.cacheIconos removeAllObjects];
}

- (void)clearCache {
    [self limpiarTodo];
}

#pragma mark - Glifos

- (UIImage *)glyph:(IOGlyph)glyph size:(CGFloat)size
             color:(UIColor *)color lineWidth:(CGFloat)lineWidth {
    if (size <= 0) { size = 24.0; }
    CGFloat escala = [UIScreen mainScreen].scale;
    NSString *clave = [NSString stringWithFormat:@"g-%ld-%.1f-%@-%.2f",
                       (long)glyph, size, [color description], lineWidth];
    UIImage *enCache = self.cacheIconos[clave];
    if (enCache) { return enCache; }

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, escala);
    UIBezierPath *camino = IOUnitPathForGlyph(glyph);
    [camino applyTransform:CGAffineTransformMakeScale(size, size)];
    camino.lineWidth = lineWidth;
    camino.lineCapStyle = kCGLineCapRound;
    camino.lineJoinStyle = kCGLineJoinRound;
    [color setStroke];
    [camino stroke];
    UIImage *imagen = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (imagen) { self.cacheIconos[clave] = imagen; }
    return imagen;
}

- (UIImage *)glyph:(IOGlyph)glyph size:(CGFloat)size color:(UIColor *)color {
    return [self glyph:glyph size:size color:color lineWidth:MAX(1.4, size * 0.085)];
}

#pragma mark - Iconos de tipo

- (UIImage *)fileIconForPath:(NSString *)path isDirectory:(BOOL)isDirectory
                        size:(CGFloat)size {
    IOGlyph glyph = [IOFileIcons glyphForPath:path isDirectory:isDirectory];
    UIColor *color = [IOFileIcons colorForGlyph:glyph];
    return [self fileIconForGlyph:glyph color:color size:size];
}

- (UIImage *)fileIconForItem:(IOFileItem *)item size:(CGFloat)size {
    return [self fileIconForPath:item.path isDirectory:item.isDirectory size:size];
}

- (UIImage *)fileIconForGlyph:(IOGlyph)glyph color:(UIColor *)color size:(CGFloat)size {
    if (size <= 0) { size = 44.0; }
    CGFloat escala = [UIScreen mainScreen].scale;
    BOOL oscuro = [IOTheme shared].dark;
    NSString *clave = [NSString stringWithFormat:@"f-%ld-%.1f-%d", (long)glyph, size, oscuro];
    UIImage *enCache = self.cacheIconos[clave];
    if (enCache) { return enCache; }

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, escala);

    CGRect rect = CGRectMake(0, 0, size, size);
    CGFloat radio = size * 0.30;
    UIBezierPath *fondo = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radio];
    CGFloat alphaFondo = oscuro ? 0.28 : 0.14;
    [[color colorWithAlphaComponent:alphaFondo] setFill];
    [fondo fill];

    CGFloat margen = size * 0.27;
    CGFloat lado = size - margen * 2.0;
    UIBezierPath *camino = IOUnitPathForGlyph(glyph);
    [camino applyTransform:CGAffineTransformMakeScale(lado, lado)];
    [camino applyTransform:CGAffineTransformMakeTranslation(margen, margen)];
    camino.lineWidth = MAX(1.4, size * 0.075);
    camino.lineCapStyle = kCGLineCapRound;
    camino.lineJoinStyle = kCGLineJoinRound;
    [color setStroke];
    [camino stroke];

    UIImage *imagen = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (imagen) { self.cacheIconos[clave] = imagen; }
    return imagen;
}

+ (IOGlyph)glyphForPath:(NSString *)path isDirectory:(BOOL)isDirectory {
    if (isDirectory) {
        if ([path hasSuffix:@".app"]) { return IOGlyphApp; }
        return IOGlyphFolder;
    }
    if ([IOHelpers isImageFile:path]) { return IOGlyphImage; }
    if ([IOHelpers isVideoFile:path]) { return IOGlyphVideo; }
    if ([IOHelpers isAudioFile:path]) { return IOGlyphAudio; }
    if ([IOHelpers isArchiveFile:path]) { return IOGlyphArchive; }
    if ([IOHelpers isPlistFile:path]) { return IOGlyphPlist; }
    NSString *ext = [path pathExtension].lowercaseString;
    static NSSet *codigo = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        codigo = [NSSet setWithArray:@[@"c", @"h", @"m", @"mm", @"cpp", @"cc",
                                       @"hpp", @"swift", @"js", @"ts", @"py",
                                       @"rb", @"sh", @"css", @"html", @"htm",
                                       @"json", @"xml", @"yml", @"yaml", @"sql"]];
    });
    if ([codigo containsObject:ext]) { return IOGlyphCode; }
    if ([IOHelpers isTextFile:path]) { return IOGlyphText; }
    if (ext.length == 0) { return IOGlyphExec; }
    return IOGlyphFile;
}

+ (UIColor *)colorForGlyph:(IOGlyph)glyph {
    switch (glyph) {
        case IOGlyphFolder:  return [IOTheme colorWithHex:0x0A84FF alpha:1.0];
        case IOGlyphImage:   return [IOTheme colorWithHex:0x30B0C7 alpha:1.0];
        case IOGlyphVideo:   return [IOTheme colorWithHex:0xAF52DE alpha:1.0];
        case IOGlyphAudio:   return [IOTheme colorWithHex:0xFF2D55 alpha:1.0];
        case IOGlyphArchive: return [IOTheme colorWithHex:0xFF9F0A alpha:1.0];
        case IOGlyphPlist:   return [IOTheme colorWithHex:0x34C759 alpha:1.0];
        case IOGlyphCode:    return [IOTheme colorWithHex:0x5856D6 alpha:1.0];
        case IOGlyphText:    return [IOTheme colorWithHex:0x64748B alpha:1.0];
        case IOGlyphApp:     return [IOTheme colorWithHex:0x0A84FF alpha:1.0];
        case IOGlyphExec:    return [IOTheme colorWithHex:0x636366 alpha:1.0];
        case IOGlyphRoot:    return [IOTheme colorWithHex:0x0A84FF alpha:1.0];
        case IOGlyphDisk:    return [IOTheme colorWithHex:0x34C759 alpha:1.0];
        case IOGlyphStar:    return [IOTheme colorWithHex:0xFFB300 alpha:1.0];
        case IOGlyphClock:   return [IOTheme colorWithHex:0x8E8E93 alpha:1.0];
        default:             return [IOTheme colorWithHex:0x8E8E93 alpha:1.0];
    }
}

#pragma mark - Miniaturas

- (UIImage *)cachedThumbnailForPath:(NSString *)path size:(CGFloat)size {
    return [self.cacheMiniaturas objectForKey:[self claveMiniatura:path size:size]];
}

- (NSString *)claveMiniatura:(NSString *)path size:(CGFloat)size {
    return [NSString stringWithFormat:@"%@#%.0f", path, size];
}

- (void)requestThumbnailForPath:(NSString *)path size:(CGFloat)size
                     completion:(void (^)(UIImage *imagen))completion {
    UIImage *enCache = [self cachedThumbnailForPath:path size:size];
    if (enCache) {
        if (completion) { completion(enCache); }
        return;
    }
    __weak IOFileIcons *debil = self;
    dispatch_async(self.colaMiniaturas, ^{
        UIImage *imagen = [IOFileIcons generarMiniatura:path size:size];
        if (imagen) {
            [debil.cacheMiniaturas setObject:imagen forKey:[debil claveMiniatura:path size:size]];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) { completion(imagen); }
        });
    });
}

+ (UIImage *)generarMiniatura:(NSString *)path size:(CGFloat)size {
    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageSourceRef fuente = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!fuente) { return nil; }
    CGFloat escala = [UIScreen mainScreen].scale;
    NSDictionary *opciones = @{
        (id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
        (id)kCGImageSourceShouldCacheImmediately: @YES,
        (id)kCGImageSourceThumbnailMaxPixelSize: @(size * escala)
    };
    CGImageRef cg = CGImageSourceCreateThumbnailAtIndex(fuente, 0,
                                                        (__bridge CFDictionaryRef)opciones);
    CFRelease(fuente);
    if (!cg) { return nil; }
    UIImage *imagen = [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    return imagen;
}

@end
