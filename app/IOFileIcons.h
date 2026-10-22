#import <UIKit/UIKit.h>
#import "IOFileItem.h"

// Glifos de linea (estilo minimalista). Se dibujan con Core Graphics.
typedef NS_ENUM(NSInteger, IOGlyph) {
    IOGlyphFolder = 0,
    IOGlyphImage,
    IOGlyphVideo,
    IOGlyphAudio,
    IOGlyphText,
    IOGlyphCode,
    IOGlyphArchive,
    IOGlyphPlist,
    IOGlyphApp,
    IOGlyphExec,
    IOGlyphFile,
    IOGlyphRoot,
    IOGlyphDisk,
    IOGlyphGear,
    IOGlyphStar,
    IOGlyphClock,
    IOGlyphTrash,
    IOGlyphShare,
    IOGlyphPlus,
    IOGlyphSearch,
    IOGlyphList,
    IOGlyphGrid,
    IOGlyphEye,
    IOGlyphLock,
    IOGlyphInfo,
    IOGlyphLink,
    IOGlyphChevronRight,
    IOGlyphChevronLeft,
    IOGlyphChevronUp,
    IOGlyphChevronDown,
    IOGlyphMore,
    IOGlyphCheck,
    IOGlyphMenu,
    IOGlyphCopy,
    IOGlyphPaste,
    IOGlyphRename,
    IOGlyphArrowUp,
    IOGlyphArrowLeft,
    IOGlyphDownload,
    IOGlyphRefresh,
    IOGlyphClose,
    IOGlyphHome,
    IOGlyphNewFolder,
    IOGlyphNewFile,
    IOGlyphSelect,
    IOGlyphFilter
};

// Fabrica de iconos: glifos, iconos de tipo de archivo y miniaturas de imagen.
@interface IOFileIcons : NSObject

+ (instancetype)shared;

// Glifo de linea suelto (fondo transparente). lineWidth en puntos.
- (UIImage *)glyph:(IOGlyph)glyph size:(CGFloat)size
             color:(UIColor *)color lineWidth:(CGFloat)lineWidth;

// Glifo con grosor por defecto.
- (UIImage *)glyph:(IOGlyph)glyph size:(CGFloat)size color:(UIColor *)color;

// Icono de tipo: cuadrado redondeado con fondo tintado suave + glifo.
- (UIImage *)fileIconForPath:(NSString *)path isDirectory:(BOOL)isDirectory
                        size:(CGFloat)size;
- (UIImage *)fileIconForItem:(IOFileItem *)item size:(CGFloat)size;

// Glifo y color que corresponden a una ruta (para reutilizarlos en la UI).
+ (IOGlyph)glyphForPath:(NSString *)path isDirectory:(BOOL)isDirectory;
+ (UIColor *)colorForGlyph:(IOGlyph)glyph;

// --- Miniaturas (imagenes reales) ---
- (UIImage *)cachedThumbnailForPath:(NSString *)path size:(CGFloat)size;
- (void)requestThumbnailForPath:(NSString *)path size:(CGFloat)size
                     completion:(void (^)(UIImage *imagen))completion;
- (void)clearCache;

@end
