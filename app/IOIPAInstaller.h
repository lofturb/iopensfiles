#import <Foundation/Foundation.h>

extern NSString * const IOIPAInstallerErrorDomain;

// Instalador de paquetes .ipa mediante la API privada MobileInstallation
// (la misma que usa Filza en dispositivos con jailbreak).
@interface IOIPAInstaller : NSObject

+ (instancetype)shared;

@property (nonatomic, copy, readonly) NSString *lastBundleIdentifier;

// Extrae el IPA en /tmp, valida el .app y lo instala. Devuelve el bundle id
// instalado en lastBundleIdentifier cuando se puede leer.
- (BOOL)installIPAAtPath:(NSString *)path
                 message:(void (^)(NSString *mensaje))message
                   error:(NSError **)error;

// Abre una app ya instalada (si el sistema lo permite).
- (BOOL)launchBundleIdentifier:(NSString *)bundleID;

// Busca .ipa en las carpetas indicadas (hasta 4 niveles). Cada diccionario:
// path, name, size, date.
- (NSArray<NSDictionary *> *)findIPAsInPaths:(NSArray<NSString *> *)paths
                                       limit:(NSUInteger)limit;

@end
