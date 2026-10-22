#import "IOTrash.h"
#import "IOFileSystem.h"

static NSString * const kIOTrashIndexKey = @"IO.trashIndex";

@interface IOTrash ()
@property (nonatomic, copy) NSString *directory;
@property (nonatomic, strong) NSMutableDictionary *indice;
@end

@implementation IOTrash

+ (instancetype)shared {
    static IOTrash *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IOTrash alloc] init];
    });
    return instancia;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _directory = @"/var/mobile/.IOpenFiles/Trash";
        [self asegurarCarpeta];
        [self cargarIndice];
    }
    return self;
}

- (void)asegurarCarpeta {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:self.directory]) {
        [fm createDirectoryAtPath:self.directory
      withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

- (void)cargarIndice {
    NSDictionary *guardado = [[NSUserDefaults standardUserDefaults]
                              dictionaryForKey:kIOTrashIndexKey];
    self.indice = guardado ? [guardado mutableCopy] : [NSMutableDictionary dictionary];
}

- (void)guardarIndice {
    [[NSUserDefaults standardUserDefaults] setObject:self.indice
                                              forKey:kIOTrashIndexKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Consulta

- (NSArray<NSString *> *)itemNames {
    NSArray *contenido = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtPath:self.directory error:NULL];
    NSMutableArray *nombres = [NSMutableArray array];
    for (NSString *nombre in contenido) {
        [nombres addObject:nombre];
    }
    [nombres sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return nombres;
}

- (BOOL)hasItems {
    return self.itemNames.count > 0;
}

- (NSUInteger)count {
    return self.itemNames.count;
}

- (NSString *)originalPathForItemNamed:(NSString *)name {
    NSString *ruta = self.indice[name];
    return ruta.length ? ruta : nil;
}

- (unsigned long long)totalSize {
    unsigned long long total = 0;
    IOFileSystem *fs = [IOFileSystem shared];
    for (NSString *nombre in [self itemNames]) {
        total += [fs recursiveSizeOfPath:[self.directory stringByAppendingPathComponent:nombre]];
    }
    return total;
}

#pragma mark - Operaciones

- (BOOL)moveItemAtPath:(NSString *)path error:(NSError **)error {
    if (path.length == 0) { return NO; }
    [self asegurarCarpeta];
    IOFileSystem *fs = [IOFileSystem shared];
    NSString *nombre = [path lastPathComponent];
    NSString *destino = [fs uniquePathForItemNamed:nombre inDirectory:self.directory];
    if (![fs moveItemAtPath:path toPath:destino progress:nil cancel:nil error:error]) {
        return NO;
    }
    self.indice[[destino lastPathComponent]] = path;
    [self guardarIndice];
    return YES;
}

- (BOOL)restoreItemNamed:(NSString *)name error:(NSError **)error {
    NSString *origen = [self.directory stringByAppendingPathComponent:name];
    if (![[NSFileManager defaultManager] fileExistsAtPath:origen]) {
        [self.indice removeObjectForKey:name];
        [self guardarIndice];
        if (error) {
            *error = [NSError errorWithDomain:IOFileSystemErrorDomain
                                         code:IOFileSystemErrorNotFound
                                     userInfo:@{ NSLocalizedDescriptionKey:
                                                 @"El elemento ya no esta en la papelera" }];
        }
        return NO;
    }

    NSString *original = self.originalPathForItemNamed(name);
    NSString *carpeta = original.length ? [original stringByDeletingLastPathComponent]
                                        : @"/var/mobile/Media";
    BOOL esDir = NO;
    if (![[IOFileSystem shared] fileExistsAtPath:carpeta isDirectory:&esDir] || !esDir) {
        carpeta = @"/var/mobile/Media";
    }
    [self asegurarCarpetaDeDestino:carpeta];

    NSString *nombreOriginal = original.length ? [original lastPathComponent] : name;
    NSString *destino = [[IOFileSystem shared]
                         uniquePathForItemNamed:nombreOriginal inDirectory:carpeta];
    if (![[IOFileSystem shared] moveItemAtPath:origen toPath:destino
                                      progress:nil cancel:nil error:error]) {
        return NO;
    }
    [self.indice removeObjectForKey:name];
    [self guardarIndice];
    return YES;
}

- (void)asegurarCarpetaDeDestino:(NSString *)carpeta {
    if (![[NSFileManager defaultManager] fileExistsAtPath:carpeta]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:carpeta
                                  withIntermediateDirectories:YES
                                                   attributes:nil error:NULL];
    }
}

- (BOOL)deleteItemNamed:(NSString *)name error:(NSError **)error {
    NSString *ruta = [self.directory stringByAppendingPathComponent:name];
    if (![[IOFileSystem shared] removeItemAtPath:ruta error:error]) {
        return NO;
    }
    [self.indice removeObjectForKey:name];
    [self guardarIndice];
    return YES;
}

- (BOOL)emptyWithError:(NSError **)error {
    BOOL todoBien = YES;
    for (NSString *nombre in [self itemNames]) {
        if (![[IOFileSystem shared]
              removeItemAtPath:[self.directory stringByAppendingPathComponent:nombre]
                         error:error]) {
            todoBien = NO;
        } else {
            [self.indice removeObjectForKey:nombre];
        }
    }
    [self guardarIndice];
    return todoBien;
}

@end
