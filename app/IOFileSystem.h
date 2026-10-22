#import <Foundation/Foundation.h>
#import "IOFileItem.h"

extern NSString * const IOFileSystemErrorDomain;

typedef NS_ENUM(NSInteger, IOFileSystemErrorCode) {
    IOFileSystemErrorNotFound = 1,
    IOFileSystemErrorPermission,
    IOFileSystemErrorExists,
    IOFileSystemErrorInvalid,
    IOFileSystemErrorCancelled,
    IOFileSystemErrorUnknown
};

// fraction: 0..1 (o -1 si no se sabe). currentPath: el archivo que se esta
// procesando. Se llama muchas veces: el receptor debe agrupar/refrescar.
typedef void (^IOProgressBlock)(double fraction, NSString *currentPath);
typedef BOOL (^IOCancelBlock)(void);

// Operaciones sobre el sistema de ficheros. Dirige syscalls directamente para
// poder preservar permisos y dar progreso, en vez de NSFileManager.
@interface IOFileSystem : NSObject

+ (instancetype)shared;

@property (nonatomic, assign, readonly) uid_t currentUID;
@property (nonatomic, assign, readonly) BOOL isRoot;
@property (nonatomic, copy) NSString *rootPath;   // raiz ampliada del navegador

// --- Listado ---
- (NSArray<IOFileItem *> *)contentsOfDirectory:(NSString *)path error:(NSError **)error;
- (IOFileItem *)itemAtPath:(NSString *)path;
- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDir;

// --- Rutas ---
- (NSString *)normalizePath:(NSString *)path;
- (NSString *)parentOfPath:(NSString *)path;
- (NSString *)uniquePathForItemNamed:(NSString *)name inDirectory:(NSString *)dir;

// --- Operaciones ---
- (BOOL)createDirectoryAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)createFileAtPath:(NSString *)path contents:(NSData *)data error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)path progress:(IOProgressBlock)progress
                  cancel:(IOCancelBlock)cancel error:(NSError **)error;
- (BOOL)copyItemAtPath:(NSString *)src toPath:(NSString *)dst error:(NSError **)error;
- (BOOL)copyItemAtPath:(NSString *)src toPath:(NSString *)dst
              progress:(IOProgressBlock)progress cancel:(IOCancelBlock)cancel
                 error:(NSError **)error;
- (BOOL)moveItemAtPath:(NSString *)src toPath:(NSString *)dst
              progress:(IOProgressBlock)progress cancel:(IOCancelBlock)cancel
                 error:(NSError **)error;
- (BOOL)renameItemAtPath:(NSString *)path toName:(NSString *)name error:(NSError **)error;
- (BOOL)setMode:(mode_t)mode atPath:(NSString *)path recursive:(BOOL)recursive error:(NSError **)error;
- (BOOL)setOwner:(uid_t)uid group:(gid_t)gid atPath:(NSString *)path recursive:(BOOL)recursive error:(NSError **)error;

// --- Datos ---
- (NSData *)dataAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)writeData:(NSData *)data toPath:(NSString *)path error:(NSError **)error;

// --- Espacio y tamano ---
- (unsigned long long)recursiveSizeOfPath:(NSString *)path;
- (unsigned long long)freeSpaceAtPath:(NSString *)path;
- (unsigned long long)totalSpaceAtPath:(NSString *)path;

// --- Recursivo ---
- (NSArray<NSString *> *)allPathsUnderPath:(NSString *)path;

// --- Volumenes y zonas sensibles ---
// Cada diccionario: name, path, device, fsType, total (NSNumber), free (NSNumber).
- (NSArray<NSDictionary *> *)mountedVolumes;

// Zonas del sistema que el limpiador nunca debe ofrecer para borrar.
- (BOOL)isProtectedPath:(NSString *)path;

@end
