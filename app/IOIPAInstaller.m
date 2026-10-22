#import "IOIPAInstaller.h"

#import "IOArchive.h"
#import "IOFileSystem.h"

#import <dlfcn.h>
#import <objc/runtime.h>
#import <sys/stat.h>
#import <CoreFoundation/CoreFoundation.h>

NSString * const IOIPAInstallerErrorDomain = @"IOIPAInstallerErrorDomain";

typedef int (*IOInstallFunction)(CFStringRef ruta, CFDictionaryRef opciones,
                                 void *callback, CFErrorRef *error);

@interface IOIPAInstaller ()
@property (nonatomic, copy, readwrite) NSString *lastBundleIdentifier;
@end

@implementation IOIPAInstaller

+ (instancetype)shared {
    static IOIPAInstaller *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IOIPAInstaller alloc] init];
    });
    return instancia;
}

#pragma mark - Instalacion

- (BOOL)installIPAAtPath:(NSString *)path
                 message:(void (^)(NSString *))message
                   error:(NSError **)error {
    if (path.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        if (error) {
            *error = [self errorWithCode:1 description:@"No se encuentra el archivo .ipa"];
        }
        return NO;
    }

    if (message) { message(@"Preparando paquete..."); }

    NSString *temporal = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[NSString stringWithFormat:
            @"iopensfiles-install-%@", [[NSUUID UUID] UUIDString]]];
    [[NSFileManager defaultManager] createDirectoryAtPath:temporal
                              withIntermediateDirectories:YES attributes:nil error:NULL];

    BOOL extraido = [IOArchive extractArchive:path toDirectory:temporal
                                     progress:nil cancel:nil error:NULL];
    NSString *appPath = extraido ? [self appBundleInDirectory:temporal] : nil;
    NSString *bundleID = appPath ? [self bundleIdentifierAtPath:appPath] : nil;

    BOOL exito = NO;
    NSError *errorInterno = nil;

    if (appPath) {
        if (message) { message(@"Instalando aplicacion..."); }
        exito = [self installBundleAtPath:appPath error:&errorInterno];
    }

    if (!exito) {
        // Algunos IPA no se dejan extraer con nuestro lector de ZIP; se prueba
        // a entregar el .ipa directamente a MobileInstallation.
        if (message) { message(@"Probando instalacion directa..."); }
        NSError *errorDirecto = nil;
        if ([self installBundleAtPath:path error:&errorDirecto]) {
            exito = YES;
            errorInterno = nil;
        } else if (!errorInterno) {
            errorInterno = errorDirecto;
        }
    }

    [[NSFileManager defaultManager] removeItemAtPath:temporal error:NULL];

    if (exito) {
        self.lastBundleIdentifier = bundleID;
        return YES;
    }

    if (error) {
        *error = errorInterno ?: [self errorWithCode:2
            description:@"El sistema no permitio instalar el paquete"];
    }
    return NO;
}

- (NSString *)appBundleInDirectory:(NSString *)directory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *payload = [directory stringByAppendingPathComponent:@"Payload"];
    NSArray *candidatos = @[ payload, directory ];
    for (NSString *carpeta in candidatos) {
        NSArray *hijos = [fm contentsOfDirectoryAtPath:carpeta error:NULL];
        for (NSString *nombre in hijos) {
            if (![[nombre pathExtension].lowercaseString isEqualToString:@"app"]) { continue; }
            NSString *ruta = [carpeta stringByAppendingPathComponent:nombre];
            BOOL esDir = NO;
            if ([fm fileExistsAtPath:ruta isDirectory:&esDir] && esDir) {
                NSString *info = [ruta stringByAppendingPathComponent:@"Info.plist"];
                if ([fm fileExistsAtPath:info]) { return ruta; }
            }
        }
    }
    return nil;
}

- (NSString *)bundleIdentifierAtPath:(NSString *)appPath {
    NSString *info = [appPath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:info];
    NSString *bundleID = plist[@"CFBundleIdentifier"];
    return bundleID.length ? bundleID : nil;
}

- (BOOL)installBundleAtPath:(NSString *)bundlePath error:(NSError **)error {
    NSDictionary *opciones = @{
        @"ApplicationType": @"User",
        @"PackageType": @"Developer",
        @"ReturnContainerPath": @YES,
        @"IsUserInitiated": @YES,
        @"AllowInstallLocalProvisioned": @YES,
        @"IgnoreAppBlacklist": @YES
    };

    void *manejador = dlopen(
        "/System/Library/PrivateFrameworks/MobileInstallation.framework/MobileInstallation",
        RTLD_LAZY);
    NSError *ultimoError = nil;

    if (manejador) {
        IOInstallFunction instalar = (IOInstallFunction)dlsym(manejador,
                                                               "MobileInstallationInstall");
        if (instalar) {
            CFErrorRef errorCF = NULL;
            int resultado = instalar((__bridge CFStringRef)bundlePath,
                                     (__bridge CFDictionaryRef)opciones,
                                     NULL, &errorCF);
            if (resultado == 0) {
                dlclose(manejador);
                return YES;
            }
            NSString *detalle = nil;
            if (errorCF) {
                CFStringRef texto = CFErrorCopyDescription(errorCF);
                if (texto) {
                    detalle = (__bridge_transfer NSString *)texto;
                }
                CFRelease(errorCF);
            }
            ultimoError = [self errorWithCode:resultado
                description:(detalle.length ? detalle :
                    [NSString stringWithFormat:@"MobileInstallation devolvio %d", resultado])];
        }
        dlclose(manejador);
    } else {
        ultimoError = [self errorWithCode:3
            description:@"MobileInstallation no esta disponible en este sistema"];
    }

    // Alternativa: LaunchServices.
    NSError *errorLS = nil;
    if ([self installWithLaunchServices:bundlePath error:&errorLS]) { return YES; }
    if (!ultimoError) { ultimoError = errorLS; }

    if (error) { *error = ultimoError; }
    return NO;
}

- (BOOL)installWithLaunchServices:(NSString *)bundlePath error:(NSError **)error {
    Class clase = NSClassFromString(@"LSApplicationWorkspace");
    if (!clase) {
        if (error) {
            *error = [self errorWithCode:4 description:@"LaunchServices no esta disponible"];
        }
        return NO;
    }

    SEL selDefault = NSSelectorFromString(@"defaultWorkspace");
    Method metodoClase = class_getClassMethod(clase, selDefault);
    if (!metodoClase) {
        if (error) {
            *error = [self errorWithCode:5 description:@"Sin espacio de trabajo de aplicaciones"];
        }
        return NO;
    }
    id (*obtenerEspacio)(id, SEL) = (id (*)(id, SEL))method_getImplementation(metodoClase);
    id espacio = obtenerEspacio(clase, selDefault);
    if (!espacio) {
        if (error) {
            *error = [self errorWithCode:6 description:@"Sin espacio de trabajo de aplicaciones"];
        }
        return NO;
    }

    SEL selInstalar = NSSelectorFromString(@"installApplication:withOptions:");
    Method metodo = class_getInstanceMethod(clase, selInstalar);
    if (!metodo) {
        if (error) {
            *error = [self errorWithCode:7
                description:@"Esta version de iOS no permite instalar desde la app"];
        }
        return NO;
    }

    NSURL *url = [NSURL fileURLWithPath:bundlePath];
    NSDictionary *opciones = @{ @"ApplicationType": @"User" };
    BOOL (*instalar)(id, SEL, NSURL *, NSDictionary *) =
        (BOOL (*)(id, SEL, NSURL *, NSDictionary *))method_getImplementation(metodo);
    BOOL exito = instalar(espacio, selInstalar, url, opciones);
    if (!exito && error) {
        *error = [self errorWithCode:8
            description:@"El sistema rechazo la instalacion del paquete"];
    }
    return exito;
}

- (BOOL)launchBundleIdentifier:(NSString *)bundleID {
    if (bundleID.length == 0) { return NO; }
    Class clase = NSClassFromString(@"LSApplicationWorkspace");
    if (!clase) { return NO; }
    SEL selDefault = NSSelectorFromString(@"defaultWorkspace");
    Method metodoClase = class_getClassMethod(clase, selDefault);
    if (!metodoClase) { return NO; }
    id (*obtenerEspacio)(id, SEL) = (id (*)(id, SEL))method_getImplementation(metodoClase);
    id espacio = obtenerEspacio(clase, selDefault);
    if (!espacio) { return NO; }

    SEL selAbrir = NSSelectorFromString(@"openApplicationWithBundleID:");
    Method metodo = class_getInstanceMethod(clase, selAbrir);
    if (!metodo) { return NO; }
    BOOL (*abrir)(id, SEL, NSString *) =
        (BOOL (*)(id, SEL, NSString *))method_getImplementation(metodo);
    return abrir(espacio, selAbrir, bundleID);
}

#pragma mark - Busqueda

- (NSArray<NSDictionary *> *)findIPAsInPaths:(NSArray<NSString *> *)paths
                                       limit:(NSUInteger)limit {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *resultados = [NSMutableArray array];
    NSMutableSet *vistos = [NSMutableSet set];

    for (NSString *raiz in paths) {
        BOOL esDir = NO;
        if (![fm fileExistsAtPath:raiz isDirectory:&esDir] || !esDir) { continue; }
        NSDirectoryEnumerator *enumerador = [fm
            enumeratorAtURL:[NSURL fileURLWithPath:raiz]
 includingPropertiesForKeys:@[ NSURLIsDirectoryKey, NSURLFileSizeKey,
                               NSURLContentModificationDateKey ]
                    options:NSDirectoryEnumerationSkipsHiddenFiles
               errorHandler:nil];
        for (NSURL *url in enumerador) {
            if (resultados.count >= limit) { break; }
            NSNumber *esDirectorio = nil;
            [url getResourceValue:&esDirectorio forKey:NSURLIsDirectoryKey error:NULL];
            if (esDirectorio.boolValue) {
                NSString *relativa = [url.path substringFromIndex:MIN(raiz.length,
                                                                      url.path.length)];
                NSInteger profundidad = [[relativa componentsSeparatedByString:@"/"] count];
                if (profundidad > 4) { [enumerador skipDescendants]; }
                continue;
            }
            if (![[url.pathExtension lowercaseString] isEqualToString:@"ipa"]) { continue; }
            if ([vistos containsObject:url.path]) { continue; }
            [vistos addObject:url.path];

            NSNumber *tamano = nil;
            NSDate *fecha = nil;
            [url getResourceValue:&tamano forKey:NSURLFileSizeKey error:NULL];
            [url getResourceValue:&fecha forKey:NSURLContentModificationDateKey error:NULL];
            [resultados addObject:@{
                @"path": url.path,
                @"name": url.lastPathComponent,
                @"size": tamano ?: @0,
                @"date": fecha ?: [NSDate date]
            }];
        }
    }

    [resultados sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [b[@"date"] compare:a[@"date"]];
    }];
    return resultados;
}

#pragma mark - Utilidades

- (NSError *)errorWithCode:(NSInteger)codigo description:(NSString *)descripcion {
    return [NSError errorWithDomain:IOIPAInstallerErrorDomain
                               code:codigo
                           userInfo:@{ NSLocalizedDescriptionKey:
                                       (descripcion.length ? descripcion : @"Error") }];
}

@end
