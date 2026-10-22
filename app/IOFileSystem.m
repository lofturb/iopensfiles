#import "IOFileSystem.h"

#import <fcntl.h>
#import <unistd.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <errno.h>
#import <sys/stat.h>
#import <sys/time.h>
#import <sys/mount.h>

NSString * const IOFileSystemErrorDomain = @"IOFileSystemErrorDomain";

#pragma mark - Seguimiento de progreso

@interface IOProgressTracker : NSObject
@property (nonatomic, assign) unsigned long long total;
@property (nonatomic, assign) unsigned long long done;
@property (nonatomic, copy) IOProgressBlock block;
@property (nonatomic, copy) IOCancelBlock cancel;
@property (nonatomic, assign) BOOL cancelled;
@end

@implementation IOProgressTracker

- (void)advance:(unsigned long long)bytes current:(NSString *)ruta {
    self.done += bytes;
    if (self.block) {
        double fraccion = (self.total > 0)
            ? ((double)self.done / (double)self.total) : -1.0;
        self.block(fraccion, ruta);
    }
    if (self.cancel && self.cancel()) {
        self.cancelled = YES;
    }
}

@end

#pragma mark - Errores

static NSError *IOError(NSInteger codigo, NSString *mensaje) {
    return [NSError errorWithDomain:IOFileSystemErrorDomain
                               code:codigo
                           userInfo:@{ NSLocalizedDescriptionKey:
                                       (mensaje.length ? mensaje : @"Error") }];
}

static NSError *IOErrorFromErrno(NSString *contexto) {
    int e = errno;
    NSInteger codigo = IOFileSystemErrorUnknown;
    if (e == ENOENT) { codigo = IOFileSystemErrorNotFound; }
    else if (e == EACCES || e == EPERM) { codigo = IOFileSystemErrorPermission; }
    else if (e == EEXIST || e == ENOTEMPTY) { codigo = IOFileSystemErrorExists; }
    NSString *mensaje = [NSString stringWithFormat:@"%@: %s",
                         contexto, strerror(e)];
    return IOError(codigo, mensaje);
}

@interface IOFileSystem ()
@property (nonatomic, assign) uid_t currentUID;
@property (nonatomic, assign) BOOL isRoot;
@end

@implementation IOFileSystem

+ (instancetype)shared {
    static IOFileSystem *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IOFileSystem alloc] init];
    });
    return instancia;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentUID = geteuid();
        _isRoot = (geteuid() == 0);
        _rootPath = @"/";
    }
    return self;
}

#pragma mark - Rutas

- (NSString *)normalizePath:(NSString *)path {
    if (path.length == 0) { return @"/"; }
    BOOL absoluto = [path hasPrefix:@"/"];
    NSArray *partes = [path componentsSeparatedByString:@"/"];
    NSMutableArray *pila = [NSMutableArray array];
    for (NSString *parte in partes) {
        if (parte.length == 0 || [parte isEqualToString:@"."]) { continue; }
        if ([parte isEqualToString:@".."]) {
            if (pila.count && ![[pila lastObject] isEqualToString:@".."]) {
                [pila removeLastObject];
            } else if (!absoluto) {
                [pila addObject:@".."];
            }
            continue;
        }
        [pila addObject:parte];
    }
    NSString *resultado = [pila componentsJoinedByString:@"/"];
    if (absoluto) { return [@"/" stringByAppendingString:resultado]; }
    return resultado.length ? resultado : @".";
}

- (NSString *)parentOfPath:(NSString *)path {
    NSString *limpio = [self normalizePath:path];
    if ([limpio isEqualToString:@"/"]) { return @"/"; }
    NSString *padre = [limpio stringByDeletingLastPathComponent];
    return padre.length ? padre : @"/";
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDir {
    struct stat info;
    if (stat([path fileSystemRepresentation], &info) != 0) {
        return NO;
    }
    if (isDir) { *isDir = S_ISDIR(info.st_mode); }
    return YES;
}

- (NSString *)uniquePathForItemNamed:(NSString *)name inDirectory:(NSString *)dir {
    NSString *base = [name stringByDeletingPathExtension];
    NSString *ext = [name pathExtension];
    NSString *candidato = [dir stringByAppendingPathComponent:name];
    int n = 2;
    while ([self fileExistsAtPath:candidato isDirectory:NULL]) {
        NSString *nuevo = ext.length
            ? [NSString stringWithFormat:@"%@ %d.%@", base, n, ext]
            : [NSString stringWithFormat:@"%@ %d", name, n];
        candidato = [dir stringByAppendingPathComponent:nuevo];
        n++;
        if (n > 9999) { break; }
    }
    return candidato;
}

#pragma mark - Listado

- (NSArray<IOFileItem *> *)contentsOfDirectory:(NSString *)path error:(NSError **)error {
    NSError *err = nil;
    NSArray *nombres = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path
                                                                          error:&err];
    if (!nombres) {
        if (error) {
            *error = err ?: IOError(IOFileSystemErrorNotFound,
                                    @"No se pudo abrir la carpeta");
        }
        return nil;
    }
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:nombres.count];
    for (NSString *nombre in nombres) {
        NSString *ruta = [path stringByAppendingPathComponent:nombre];
        IOFileItem *item = [IOFileItem itemAtPath:ruta];
        if (item) { [items addObject:item]; }
    }
    return items;
}

- (IOFileItem *)itemAtPath:(NSString *)path {
    return [IOFileItem itemAtPath:path computeChildCount:YES];
}

#pragma mark - Crear

- (BOOL)createDirectoryAtPath:(NSString *)path error:(NSError **)error {
    if (mkdir([path fileSystemRepresentation], 0755) != 0) {
        if (error) { *error = IOErrorFromErrno(@"No se pudo crear la carpeta"); }
        return NO;
    }
    return YES;
}

- (BOOL)createFileAtPath:(NSString *)path contents:(NSData *)data error:(NSError **)error {
    int fd = open([path fileSystemRepresentation],
                  O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        if (error) { *error = IOErrorFromErrno(@"No se pudo crear el archivo"); }
        return NO;
    }
    BOOL ok = YES;
    if (data.length > 0) {
        const void *bytes = data.bytes;
        size_t restante = (size_t)data.length;
        const uint8_t *p = bytes;
        while (restante > 0) {
            ssize_t escritos = write(fd, p, restante);
            if (escritos < 0) {
                ok = NO;
                break;
            }
            p += escritos;
            restante -= (size_t)escritos;
        }
    }
    close(fd);
    if (!ok && error) { *error = IOErrorFromErrno(@"No se pudo escribir el archivo"); }
    return ok;
}

#pragma mark - Datos

- (NSData *)dataAtPath:(NSString *)path error:(NSError **)error {
    NSData *datos = [NSData dataWithContentsOfFile:path options:0 error:error];
    return datos;
}

- (BOOL)writeData:(NSData *)data toPath:(NSString *)path error:(NSError **)error {
    return [data writeToFile:path options:NSDataWritingAtomic error:error];
}

#pragma mark - Borrar

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error {
    return [self removeItemAtPath:path progress:nil cancel:nil error:error];
}

- (BOOL)removeItemAtPath:(NSString *)path progress:(IOProgressBlock)progress
                  cancel:(IOCancelBlock)cancel error:(NSError **)error {
    IOProgressTracker *tracker = [[IOProgressTracker alloc] init];
    tracker.block = progress;
    tracker.cancel = cancel;
    tracker.total = [self recursiveSizeOfPath:path];
    return [self removePath:path tracker:tracker error:error];
}

- (BOOL)removePath:(NSString *)path tracker:(IOProgressTracker *)tracker
             error:(NSError **)error {
    struct stat info;
    if (lstat([path fileSystemRepresentation], &info) != 0) {
        if (error) { *error = IOErrorFromErrno(@"No se pudo leer el elemento"); }
        return NO;
    }
    if (S_ISDIR(info.st_mode)) {
        NSArray *hijos = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtPath:path error:NULL];
        for (NSString *hijo in hijos) {
            NSString *rutaHijo = [path stringByAppendingPathComponent:hijo];
            if (![self removePath:rutaHijo tracker:tracker error:error]) {
                return NO;
            }
        }
        if (rmdir([path fileSystemRepresentation]) != 0) {
            if (error) { *error = IOErrorFromErrno(@"No se pudo borrar la carpeta"); }
            return NO;
        }
        return YES;
    }
    if (unlink([path fileSystemRepresentation]) != 0) {
        if (error) { *error = IOErrorFromErrno(@"No se pudo borrar el archivo"); }
        return NO;
    }
    [tracker advance:0 current:path];
    return YES;
}

#pragma mark - Copiar

- (BOOL)copyItemAtPath:(NSString *)src toPath:(NSString *)dst error:(NSError **)error {
    return [self copyItemAtPath:src toPath:dst progress:nil cancel:nil error:error];
}

- (BOOL)copyItemAtPath:(NSString *)src toPath:(NSString *)dst
              progress:(IOProgressBlock)progress cancel:(IOCancelBlock)cancel
                 error:(NSError **)error {
    IOProgressTracker *tracker = [[IOProgressTracker alloc] init];
    tracker.block = progress;
    tracker.cancel = cancel;
    tracker.total = [self recursiveSizeOfPath:src];
    return [self copyPath:src to:dst tracker:tracker error:error];
}

- (BOOL)copyPath:(NSString *)src to:(NSString *)dst
         tracker:(IOProgressTracker *)tracker error:(NSError **)error {
    if (tracker.cancelled) {
        if (error) { *error = IOError(IOFileSystemErrorCancelled, @"Cancelado"); }
        return NO;
    }

    struct stat info;
    if (lstat([src fileSystemRepresentation], &info) != 0) {
        if (error) { *error = IOErrorFromErrno(@"No se pudo leer el origen"); }
        return NO;
    }

    mode_t modo = info.st_mode & 07777;
    const char *cSrc = [src fileSystemRepresentation];
    const char *cDst = [dst fileSystemRepresentation];

    if (S_ISLNK(info.st_mode)) {
        char destino[4096];
        ssize_t n = readlink(cSrc, destino, sizeof(destino) - 1);
        if (n < 0) {
            if (error) { *error = IOErrorFromErrno(@"No se pudo leer el enlace"); }
            return NO;
        }
        destino[n] = '\0';
        unlink(cDst);
        if (symlink(destino, cDst) != 0) {
            if (error) { *error = IOErrorFromErrno(@"No se pudo crear el enlace"); }
            return NO;
        }
        return YES;
    }

    if (S_ISDIR(info.st_mode)) {
        mkdir(cDst, modo);
        NSArray *hijos = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtPath:src error:NULL];
        for (NSString *hijo in hijos) {
            NSString *origenHijo = [src stringByAppendingPathComponent:hijo];
            NSString *destinoHijo = [dst stringByAppendingPathComponent:hijo];
            if (![self copyPath:origenHijo to:destinoHijo tracker:tracker error:error]) {
                return NO;
            }
        }
        chmod(cDst, modo);
        return YES;
    }

    if (S_ISREG(info.st_mode)) {
        int in = open(cSrc, O_RDONLY);
        if (in < 0) {
            if (error) { *error = IOErrorFromErrno(@"No se pudo abrir el origen"); }
            return NO;
        }
        int out = open(cDst, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (out < 0) {
            close(in);
            if (error) { *error = IOErrorFromErrno(@"No se pudo crear el destino"); }
            return NO;
        }

        const size_t tam = 256 * 1024;
        uint8_t *buf = malloc(tam);
        BOOL ok = YES;
        while (1) {
            ssize_t leidos = read(in, buf, tam);
            if (leidos < 0) {
                ok = NO;
                if (error) { *error = IOErrorFromErrno(@"Error de lectura"); }
                break;
            }
            if (leidos == 0) { break; }
            ssize_t escritos = 0;
            while (escritos < leidos) {
                ssize_t w = write(out, buf + escritos, (size_t)(leidos - escritos));
                if (w < 0) {
                    ok = NO;
                    if (error) { *error = IOErrorFromErrno(@"Error de escritura"); }
                    break;
                }
                escritos += w;
            }
            if (!ok) { break; }
            [tracker advance:(unsigned long long)leidos current:src];
            if (tracker.cancelled) {
                ok = NO;
                if (error) { *error = IOError(IOFileSystemErrorCancelled, @"Cancelado"); }
                break;
            }
        }
        free(buf);
        close(in);
        close(out);
        if (!ok) {
            unlink(cDst);
            return NO;
        }
        chmod(cDst, modo);
        struct timeval tiempos[2];
        tiempos[0].tv_sec = info.st_atimespec.tv_sec;
        tiempos[0].tv_usec = 0;
        tiempos[1].tv_sec = info.st_mtimespec.tv_sec;
        tiempos[1].tv_usec = 0;
        utimes(cDst, tiempos);
        return YES;
    }

    // Tipos especiales: intenta recrearlos.
    if (S_ISFIFO(info.st_mode)) {
        if (mkfifo(cDst, modo) != 0) {
            if (error) { *error = IOErrorFromErrno(@"No se pudo crear la FIFO"); }
            return NO;
        }
        return YES;
    }
    if (S_ISCHR(info.st_mode) || S_ISBLK(info.st_mode)) {
        if (mknod(cDst, info.st_mode, info.st_rdev) != 0) {
            if (error) { *error = IOErrorFromErrno(@"No se pudo crear el dispositivo"); }
            return NO;
        }
        return YES;
    }

    if (error) { *error = IOError(IOFileSystemErrorInvalid, @"Tipo no soportado"); }
    return NO;
}

#pragma mark - Mover y renombrar

- (BOOL)moveItemAtPath:(NSString *)src toPath:(NSString *)dst
              progress:(IOProgressBlock)progress cancel:(IOCancelBlock)cancel
                 error:(NSError **)error {
    IOProgressTracker *tracker = [[IOProgressTracker alloc] init];
    tracker.block = progress;
    tracker.cancel = cancel;

    errno = 0;
    if (rename([src fileSystemRepresentation], [dst fileSystemRepresentation]) == 0) {
        tracker.total = 1;
        [tracker advance:1 current:dst];
        return YES;
    }
    if (errno != EXDEV) {
        if (error) { *error = IOErrorFromErrno(@"No se pudo mover"); }
        return NO;
    }
    // Distinto volumen: copiar y luego borrar.
    if (![self copyItemAtPath:src toPath:dst progress:progress cancel:cancel error:error]) {
        return NO;
    }
    return [self removeItemAtPath:src error:error];
}

- (BOOL)renameItemAtPath:(NSString *)path toName:(NSString *)name error:(NSError **)error {
    if (name.length == 0) {
        if (error) { *error = IOError(IOFileSystemErrorInvalid, @"Nombre vacio"); }
        return NO;
    }
    NSString *padre = [self parentOfPath:path];
    NSString *destino = [padre stringByAppendingPathComponent:name];
    if ([self fileExistsAtPath:destino isDirectory:NULL]) {
        if (error) { *error = IOError(IOFileSystemErrorExists, @"Ya existe un elemento con ese nombre"); }
        return NO;
    }
    if (rename([path fileSystemRepresentation], [destino fileSystemRepresentation]) != 0) {
        if (error) { *error = IOErrorFromErrno(@"No se pudo renombrar"); }
        return NO;
    }
    return YES;
}

#pragma mark - Permisos y dueno

- (BOOL)setMode:(mode_t)mode atPath:(NSString *)path recursive:(BOOL)recursive
          error:(NSError **)error {
    if (chmod([path fileSystemRepresentation], mode) != 0) {
        if (error) { *error = IOErrorFromErrno(@"No se pudieron cambiar los permisos"); }
        return NO;
    }
    if (recursive) {
        BOOL esDir = NO;
        if ([self fileExistsAtPath:path isDirectory:&esDir] && esDir) {
            NSArray *hijos = [[NSFileManager defaultManager]
                              contentsOfDirectoryAtPath:path error:NULL];
            for (NSString *hijo in hijos) {
                NSString *rutaHijo = [path stringByAppendingPathComponent:hijo];
                if (![self setMode:mode atPath:rutaHijo recursive:YES error:error]) {
                    return NO;
                }
            }
        }
    }
    return YES;
}

- (BOOL)setOwner:(uid_t)uid group:(gid_t)gid atPath:(NSString *)path
       recursive:(BOOL)recursive error:(NSError **)error {
    if (chown([path fileSystemRepresentation], uid, gid) != 0) {
        if (error) { *error = IOErrorFromErrno(@"No se pudo cambiar el propietario"); }
        return NO;
    }
    if (recursive) {
        BOOL esDir = NO;
        if ([self fileExistsAtPath:path isDirectory:&esDir] && esDir) {
            NSArray *hijos = [[NSFileManager defaultManager]
                              contentsOfDirectoryAtPath:path error:NULL];
            for (NSString *hijo in hijos) {
                NSString *rutaHijo = [path stringByAppendingPathComponent:hijo];
                if (![self setOwner:uid group:gid atPath:rutaHijo recursive:YES error:error]) {
                    return NO;
                }
            }
        }
    }
    return YES;
}

#pragma mark - Tamano y espacio

- (unsigned long long)recursiveSizeOfPath:(NSString *)path {
    struct stat info;
    if (lstat([path fileSystemRepresentation], &info) != 0) { return 0; }
    if (S_ISREG(info.st_mode)) {
        return (unsigned long long)info.st_size;
    }
    if (!S_ISDIR(info.st_mode)) { return 0; }
    unsigned long long total = 0;
    NSArray *hijos = [[NSFileManager defaultManager]
                      contentsOfDirectoryAtPath:path error:NULL];
    for (NSString *hijo in hijos) {
        NSString *rutaHijo = [path stringByAppendingPathComponent:hijo];
        total += [self recursiveSizeOfPath:rutaHijo];
    }
    return total;
}

- (unsigned long long)freeSpaceAtPath:(NSString *)path {
    struct statfs info;
    if (statfs([path fileSystemRepresentation], &info) != 0) { return 0; }
    return (unsigned long long)info.f_bavail * (unsigned long long)info.f_bsize;
}

- (unsigned long long)totalSpaceAtPath:(NSString *)path {
    struct statfs info;
    if (statfs([path fileSystemRepresentation], &info) != 0) { return 0; }
    return (unsigned long long)info.f_blocks * (unsigned long long)info.f_bsize;
}

#pragma mark - Recursivo

- (NSArray<NSString *> *)allPathsUnderPath:(NSString *)path {
    NSMutableArray *resultado = [NSMutableArray array];
    [self collectPathsUnder:path into:resultado];
    return resultado;
}

- (void)collectPathsUnder:(NSString *)path into:(NSMutableArray *)acumulador {
    NSArray *hijos = [[NSFileManager defaultManager]
                      contentsOfDirectoryAtPath:path error:NULL];
    for (NSString *hijo in hijos) {
        NSString *rutaHijo = [path stringByAppendingPathComponent:hijo];
        [acumulador addObject:rutaHijo];
        BOOL esDir = NO;
        struct stat info;
        if (lstat([rutaHijo fileSystemRepresentation], &info) == 0 &&
            S_ISDIR(info.st_mode)) {
            esDir = YES;
        }
        if (esDir) {
            [self collectPathsUnder:rutaHijo into:acumulador];
        }
    }
}

#pragma mark - Volumenes y zonas sensibles

- (NSArray<NSDictionary *> *)mountedVolumes {
    struct statfs *montajes = NULL;
    int cantidad = getmntinfo(&montajes, MNT_NOWAIT);
    if (cantidad <= 0 || !montajes) { return @[]; }

    NSMutableArray *resultado = [NSMutableArray array];
    NSMutableSet *dispositivos = [NSMutableSet set];
    NSMutableSet *puntos = [NSMutableSet set];

    for (int i = 0; i < cantidad; i++) {
        struct statfs *m = &montajes[i];
        NSString *tipo = m->f_fstypename[0]
            ? [NSString stringWithUTF8String:m->f_fstypename] : @"";
        if ([tipo isEqualToString:@"devfs"] || [tipo isEqualToString:@"autofs"] ||
            [tipo isEqualToString:@"map"]) {
            continue;
        }
        unsigned long long total = (unsigned long long)m->f_blocks *
                                   (unsigned long long)m->f_bsize;
        if (total == 0) { continue; }

        NSString *punto = m->f_mntonname[0]
            ? [NSString stringWithUTF8String:m->f_mntonname] : @"";
        NSString *dispositivo = m->f_mntfromname[0]
            ? [NSString stringWithUTF8String:m->f_mntfromname] : @"";
        if (punto.length == 0) { continue; }
        if ([puntos containsObject:punto]) { continue; }
        if (dispositivo.length && [dispositivos containsObject:dispositivo]) { continue; }
        [puntos addObject:punto];
        if (dispositivo.length) { [dispositivos addObject:dispositivo]; }

        unsigned long long libre = (unsigned long long)m->f_bavail *
                                   (unsigned long long)m->f_bsize;
        NSString *nombre = nil;
        if ([punto isEqualToString:@"/"]) {
            nombre = @"Sistema";
        } else if ([punto isEqualToString:@"/private/var"] ||
                   [punto isEqualToString:@"/var"]) {
            nombre = @"Datos";
        } else if ([punto isEqualToString:@"/private/var/mobile/Media"]) {
            nombre = @"Medios";
        } else {
            nombre = [punto lastPathComponent];
            if (nombre.length == 0) { nombre = @"Almacenamiento"; }
        }

        [resultado addObject:@{
            @"name": nombre,
            @"path": punto,
            @"device": dispositivo,
            @"fsType": tipo,
            @"total": @(total),
            @"free": @(libre)
        }];
    }

    [resultado sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSString *pa = a[@"path"];
        NSString *pb = b[@"path"];
        if ([pa isEqualToString:@"/"]) { return NSOrderedAscending; }
        if ([pb isEqualToString:@"/"]) { return NSOrderedDescending; }
        unsigned long long ta = [a[@"total"] unsignedLongLongValue];
        unsigned long long tb = [b[@"total"] unsignedLongLongValue];
        if (ta < tb) { return NSOrderedDescending; }
        if (ta > tb) { return NSOrderedAscending; }
        return [pa compare:pb];
    }];

    return resultado;
}

- (BOOL)isProtectedPath:(NSString *)path {
    NSString *limpio = [self normalizePath:path];
    if (limpio.length == 0) { return YES; }

    static NSArray<NSString *> *prefijos = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        prefijos = @[
            @"/System", @"/usr", @"/bin", @"/sbin", @"/dev", @"/etc",
            @"/private/etc", @"/private/preboot", @"/private/var/db",
            @"/private/var/lib", @"/private/var/stash", @"/private/var/Keychains",
            @"/private/var/root", @"/private/var/preferences", @"/Library",
            @"/Applications", @"/cores",
            @"/private/var/mobile/Containers/Bundle",
            @"/private/var/mobile/Containers/Data",
            @"/private/var/mobile/Containers/Shared/AppGroup",
            @"/var/mobile/Containers/Bundle",
            @"/var/mobile/Containers/Data",
            @"/var/mobile/Containers/Shared/AppGroup",
            @"/private/var/mobile/Media/PhotoData",
            @"/var/mobile/Media/PhotoData"
        ];
    });

    for (NSString *prefijo in prefijos) {
        if ([limpio isEqualToString:prefijo]) { return YES; }
        if ([limpio hasPrefix:[prefijo stringByAppendingString:@"/"]]) { return YES; }
    }

    // La biblioteca del usuario se protege salvo caches y registros, que son
    // justo lo que interesa limpiar.
    NSArray *bibliotecas = @[ @"/private/var/mobile/Library",
                              @"/var/mobile/Library" ];
    for (NSString *biblioteca in bibliotecas) {
        if ([limpio isEqualToString:biblioteca]) { return YES; }
        if ([limpio hasPrefix:[biblioteca stringByAppendingString:@"/"]]) {
            NSString *caches = [biblioteca stringByAppendingString:@"/Caches"];
            NSString *logs = [biblioteca stringByAppendingString:@"/Logs"];
            if ([limpio isEqualToString:caches] ||
                [limpio hasPrefix:[caches stringByAppendingString:@"/"]]) {
                return NO;
            }
            if ([limpio isEqualToString:logs] ||
                [limpio hasPrefix:[logs stringByAppendingString:@"/"]]) {
                return NO;
            }
            return YES;
        }
    }
    return NO;
}

@end
