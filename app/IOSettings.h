#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, IOSortKey) {
    IOSortByName = 0,
    IOSortByKind,
    IOSortByDate,
    IOSortBySize
};

// Ajustes de la app, respaldados por NSUserDefaults. Un unico objeto compartido.
@interface IOSettings : NSObject

+ (instancetype)shared;

@property (nonatomic, assign) BOOL showHidden;        // mostrar archivos ocultos (.)
@property (nonatomic, assign) BOOL foldersFirst;      // carpetas antes que archivos
@property (nonatomic, assign) BOOL sortAscending;     // orden ascendente
@property (nonatomic, assign) IOSortKey sortKey;      // criterio de orden
@property (nonatomic, assign) BOOL darkMode;          // tema oscuro
@property (nonatomic, assign) BOOL confirmDelete;     // pedir confirmacion al borrar
@property (nonatomic, assign) BOOL showDetails;       // tamano/fecha bajo el nombre
@property (nonatomic, assign) BOOL thumbnails;        // miniaturas de imagenes
@property (nonatomic, assign) BOOL showExtensions;    // mostrar la extension
@property (nonatomic, assign) BOOL askBeforeOverwrite;// avisar antes de sobrescribir
@property (nonatomic, assign) BOOL trashEnabled;      // mover a la papelera al borrar
@property (nonatomic, copy)   NSString *startPath;    // carpeta de arranque
@property (nonatomic, assign) BOOL openAtLastPath;    // recordar la ultima carpeta
@property (nonatomic, copy)   NSString *lastPath;     // ultima carpeta visitada

- (void)save;

@end
