#import <Foundation/Foundation.h>
#import "IOFileSystem.h"

extern NSString * const IOArchiveErrorDomain;

// Lectura y escritura de ZIP con zlib (deflate/store). Sin dependencias.
@interface IOArchive : NSObject

// Devuelve un array de diccionarios con claves:
//   name (NSString), size (NSNumber), compressedSize (NSNumber),
//   crc (NSNumber), method (NSNumber), isDirectory (NSNumber).
+ (NSArray<NSDictionary *> *)listEntriesAtPath:(NSString *)zipPath
                                         error:(NSError **)error;

// Extrae el ZIP dentro de destDir (creando subcarpetas segun la entrada).
+ (BOOL)extractArchive:(NSString *)zipPath toDirectory:(NSString *)destDir
              progress:(IOProgressBlock)progress cancel:(IOCancelBlock)cancel
                 error:(NSError **)error;

// Crea un ZIP con las rutas indicadas (archivos o carpetas), guardando en cada
// entrada el nombre del elemento (no la ruta completa).
+ (BOOL)createArchive:(NSString *)zipPath fromPaths:(NSArray<NSString *> *)paths
             progress:(IOProgressBlock)progress cancel:(IOCancelBlock)cancel
                error:(NSError **)error;

@end
