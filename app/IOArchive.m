#import "IOArchive.h"

#import <zlib.h>
#import <stdio.h>
#import <string.h>
#import <errno.h>
#import <time.h>
#import <sys/stat.h>
#import <unistd.h>

NSString * const IOArchiveErrorDomain = @"IOArchiveErrorDomain";

#define IOZIP_EOCD 0x06054b50
#define IOZIP_CENTRAL 0x02014b50
#define IOZIP_LOCAL 0x04034b50
#define IOZIP_DATADESC 0x08074b50

static NSError *IOZipError(NSString *mensaje) {
    return [NSError errorWithDomain:IOArchiveErrorDomain
                               code:1
                           userInfo:@{ NSLocalizedDescriptionKey: mensaje }];
}

static uint16_t ioLe16(const uint8_t *p) {
    return (uint16_t)(p[0] | (p[1] << 8));
}

static uint32_t ioLe32(const uint8_t *p) {
    return (uint32_t)(p[0] | (p[1] << 8) | (p[2] << 16) | ((uint32_t)p[3] << 24));
}

static void ioAppend16(NSMutableData *datos, uint16_t valor) {
    uint8_t b[2] = { (uint8_t)(valor & 0xFF), (uint8_t)((valor >> 8) & 0xFF) };
    [datos appendBytes:b length:2];
}

static void ioAppend32(NSMutableData *datos, uint32_t valor) {
    uint8_t b[4] = { (uint8_t)(valor & 0xFF), (uint8_t)((valor >> 8) & 0xFF),
                     (uint8_t)((valor >> 16) & 0xFF), (uint8_t)((valor >> 24) & 0xFF) };
    [datos appendBytes:b length:4];
}

static void ioDosDateTime(time_t t, uint16_t *fecha, uint16_t *hora) {
    struct tm tmv;
    memset(&tmv, 0, sizeof(tmv));
    localtime_r(&t, &tmv);
    int anio = tmv.tm_year + 1900;
    if (anio < 1980) { anio = 1980; }
    *fecha = (uint16_t)(((anio - 1980) << 9) | ((tmv.tm_mon + 1) << 5) | tmv.tm_mday);
    *hora = (uint16_t)((tmv.tm_hour << 11) | (tmv.tm_min << 5) | (tmv.tm_sec / 2));
}

@implementation IOArchive

#pragma mark - Listar

+ (NSArray<NSDictionary *> *)listEntriesAtPath:(NSString *)zipPath
                                         error:(NSError **)error {
    NSFileHandle *manejador = [NSFileHandle fileHandleForReadingAtPath:zipPath];
    if (!manejador) {
        if (error) { *error = IOZipError(@"No se pudo abrir el ZIP"); }
        return nil;
    }
    unsigned long long tam = [manejador seekToEndOfFile];
    unsigned long long ventana = MIN(tam, (unsigned long long)(65557));
    [manejador seekToFileOffset:tam - ventana];
    NSData *cola = [manejador readDataOfLength:(NSUInteger)ventana];

    const uint8_t *bytes = cola.bytes;
    NSInteger pos = (NSInteger)cola.length - 22;
    NSInteger eocd = -1;
    while (pos >= 0) {
        if (ioLe32(bytes + pos) == IOZIP_EOCD) { eocd = pos; break; }
        pos--;
    }
    if (eocd < 0) {
        [manejador closeFile];
        if (error) { *error = IOZipError(@"No es un ZIP valido (sin EOCD)"); }
        return nil;
    }

    uint16_t total = ioLe16(bytes + eocd + 10);
    uint32_t cdOffset = ioLe32(bytes + eocd + 16);

    [manejador seekToFileOffset:cdOffset];
    NSMutableArray *entradas = [NSMutableArray arrayWithCapacity:total];
    for (uint16_t i = 0; i < total; i++) {
        NSData *cabecera = [manejador readDataOfLength:46];
        if (cabecera.length < 46) { break; }
        const uint8_t *c = cabecera.bytes;
        if (ioLe32(c) != IOZIP_CENTRAL) { break; }
        uint16_t method = ioLe16(c + 10);
        uint32_t crc = ioLe32(c + 16);
        uint32_t compSize = ioLe32(c + 20);
        uint32_t uncompSize = ioLe32(c + 24);
        uint16_t nameLen = ioLe16(c + 28);
        uint16_t extraLen = ioLe16(c + 30);
        uint16_t commentLen = ioLe16(c + 32);
        uint32_t extAttrs = ioLe32(c + 38);

        NSData *nombreDatos = [manejador readDataOfLength:nameLen];
        NSString *nombre = [[NSString alloc] initWithData:nombreDatos
                                                 encoding:NSUTF8StringEncoding];
        if (!nombre) {
            nombre = [[NSString alloc] initWithData:nombreDatos
                                           encoding:NSISOLatin1StringEncoding];
        }
        if (extraLen > 0) { [manejador seekToFileOffset:[manejador offsetInFile] + extraLen]; }
        if (commentLen > 0) { [manejador seekToFileOffset:[manejador offsetInFile] + commentLen]; }

        BOOL esDir = [nombre hasSuffix:@"/"] || ((extAttrs & 0x10) != 0);
        [entradas addObject:@{
            @"name": nombre ?: @"",
            @"size": @(uncompSize),
            @"compressedSize": @(compSize),
            @"crc": @(crc),
            @"method": @(method),
            @"isDirectory": @(esDir)
        }];
    }
    [manejador closeFile];
    return entradas;
}

#pragma mark - Extraer

+ (BOOL)extractArchive:(NSString *)zipPath toDirectory:(NSString *)destDir
              progress:(IOProgressBlock)progress cancel:(IOCancelBlock)cancel
                 error:(NSError **)error {
    NSFileHandle *manejador = [NSFileHandle fileHandleForReadingAtPath:zipPath];
    if (!manejador) {
        if (error) { *error = IOZipError(@"No se pudo abrir el ZIP"); }
        return NO;
    }
    unsigned long long tam = [manejador seekToEndOfFile];
    unsigned long long ventana = MIN(tam, (unsigned long long)(65557));
    [manejador seekToFileOffset:tam - ventana];
    NSData *cola = [manejador readDataOfLength:(NSUInteger)ventana];
    const uint8_t *cb = cola.bytes;
    NSInteger pos = (NSInteger)cola.length - 22;
    NSInteger eocd = -1;
    while (pos >= 0) {
        if (ioLe32(cb + pos) == IOZIP_EOCD) { eocd = pos; break; }
        pos--;
    }
    if (eocd < 0) {
        [manejador closeFile];
        if (error) { *error = IOZipError(@"No es un ZIP valido"); }
        return NO;
    }
    uint16_t total = ioLe16(cb + eocd + 10);
    uint32_t cdOffset = ioLe32(cb + eocd + 16);

    if (![[NSFileManager defaultManager] fileExistsAtPath:destDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:destDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil error:NULL];
    }

    [manejador seekToFileOffset:cdOffset];
    for (uint16_t i = 0; i < total; i++) {
        if (cancel && cancel()) {
            [manejador closeFile];
            if (error) { *error = IOZipError(@"Cancelado"); }
            return NO;
        }
        NSData *cabecera = [manejador readDataOfLength:46];
        if (cabecera.length < 46) { break; }
        const uint8_t *c = cabecera.bytes;
        if (ioLe32(c) != IOZIP_CENTRAL) { break; }
        uint16_t method = ioLe16(c + 10);
        uint32_t compSize = ioLe32(c + 20);
        uint32_t uncompSize = ioLe32(c + 24);
        uint16_t nameLen = ioLe16(c + 28);
        uint16_t extraLen = ioLe16(c + 30);
        uint16_t commentLen = ioLe16(c + 32);
        uint32_t localOffset = ioLe32(c + 42);

        NSData *nombreDatos = [manejador readDataOfLength:nameLen];
        NSString *nombre = [[NSString alloc] initWithData:nombreDatos
                                                 encoding:NSUTF8StringEncoding];
        if (!nombre) {
            nombre = [[NSString alloc] initWithData:nombreDatos
                                           encoding:NSISOLatin1StringEncoding];
        }
        if (extraLen > 0) { [manejador seekToFileOffset:[manejador offsetInFile] + extraLen]; }
        if (commentLen > 0) { [manejador seekToFileOffset:[manejador offsetInFile] + commentLen]; }

        if (!nombre || [nombre hasPrefix:@"/"] || [nombre rangeOfString:@".."].location != NSNotFound) {
            continue;
        }

        NSString *rutaDestino = [destDir stringByAppendingPathComponent:nombre];
        BOOL esDir = [nombre hasSuffix:@"/"];

        if (esDir) {
            [[NSFileManager defaultManager] createDirectoryAtPath:rutaDestino
                                      withIntermediateDirectories:YES
                                                       attributes:nil error:NULL];
            if (progress) { progress((double)(i + 1) / (double)total, nombre); }
            continue;
        }

        // Crea la carpeta contenedora.
        NSString *carpeta = [rutaDestino stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:carpeta
                                  withIntermediateDirectories:YES
                                                   attributes:nil error:NULL];

        // Lee el encabezado local para saber donde empiezan los datos.
        [manejador seekToFileOffset:localOffset];
        NSData *local = [manejador readDataOfLength:30];
        if (local.length < 30) { continue; }
        const uint8_t *l = local.bytes;
        uint16_t lNameLen = ioLe16(l + 26);
        uint16_t lExtraLen = ioLe16(l + 28);
        unsigned long long dataOffset = localOffset + 30ULL + lNameLen + lExtraLen;

        [manejador seekToFileOffset:dataOffset];
        NSData *datosComprimidos = [manejador readDataOfLength:compSize];

        FILE *salida = fopen([rutaDestino fileSystemRepresentation], "wb");
        if (!salida) {
            if (error) { *error = IOZipError(@"No se pudo crear el archivo extraido"); }
            [manejador closeFile];
            return NO;
        }

        BOOL ok = YES;
        if (method == 0) {
            if (datosComprimidos.length) {
                fwrite(datosComprimidos.bytes, 1, datosComprimidos.length, salida);
            }
        } else if (method == 8) {
            z_stream zs;
            memset(&zs, 0, sizeof(zs));
            if (inflateInit2(&zs, -15) != Z_OK) {
                ok = NO;
            } else {
                zs.next_in = (Bytef *)datosComprimidos.bytes;
                zs.avail_in = (uInt)datosComprimidos.length;
                uint8_t salidaBuf[65536];
                int ret = Z_OK;
                while (ret != Z_STREAM_END) {
                    zs.next_out = salidaBuf;
                    zs.avail_out = (uInt)sizeof(salidaBuf);
                    ret = inflate(&zs, Z_NO_FLUSH);
                    if (ret != Z_OK && ret != Z_STREAM_END && ret != Z_BUF_ERROR) {
                        ok = NO;
                        break;
                    }
                    size_t hay = sizeof(salidaBuf) - zs.avail_out;
                    if (hay) { fwrite(salidaBuf, 1, hay, salida); }
                    if (ret == Z_BUF_ERROR && zs.avail_in == 0) { break; }
                }
                inflateEnd(&zs);
            }
        } else {
            ok = NO;
        }
        fclose(salida);
        if (!ok) {
            if (error) { *error = IOZipError(@"Metodo de compresion no soportado"); }
            [manejador closeFile];
            return NO;
        }
        (void)uncompSize;
        if (progress) { progress((double)(i + 1) / (double)total, nombre); }
    }
    [manejador closeFile];
    return YES;
}

#pragma mark - Crear

+ (BOOL)createArchive:(NSString *)zipPath fromPaths:(NSArray<NSString *> *)paths
             progress:(IOProgressBlock)progress cancel:(IOCancelBlock)cancel
                error:(NSError **)error {
    FILE *salida = fopen([zipPath fileSystemRepresentation], "wb");
    if (!salida) {
        if (error) { *error = IOZipError(@"No se pudo crear el ZIP"); }
        return NO;
    }

    // Cuenta total de elementos para el progreso.
    NSUInteger totalElementos = 0;
    for (NSString *ruta in paths) {
        totalElementos += [[IOFileSystem shared] allPathsUnderPath:ruta].count + 1;
    }
    __block NSUInteger hechos = 0;

    NSMutableArray *central = [NSMutableArray array];
    BOOL ok = YES;

    for (NSString *ruta in paths) {
        if (![self addItemAtPath:ruta entryName:[ruta lastPathComponent]
                        toFile:salida central:central hechos:&hechos
                          total:totalElementos progress:progress cancel:cancel
                          error:error]) {
            ok = NO;
            break;
        }
    }

    if (ok) {
        unsigned long long cdInicio = ftello(salida);
        for (NSData *cabecera in central) {
            fwrite(cabecera.bytes, 1, cabecera.length, salida);
        }
        unsigned long long cdFin = ftello(salida);

        NSMutableData *eocd = [NSMutableData data];
        ioAppend32(eocd, IOZIP_EOCD);
        ioAppend16(eocd, 0);
        ioAppend16(eocd, 0);
        ioAppend16(eocd, (uint16_t)central.count);
        ioAppend16(eocd, (uint16_t)central.count);
        ioAppend32(eocd, (uint32_t)(cdFin - cdInicio));
        ioAppend32(eocd, (uint32_t)cdInicio);
        ioAppend16(eocd, 0);
        fwrite(eocd.bytes, 1, eocd.length, salida);
    }

    fclose(salida);
    if (!ok) {
        unlink([zipPath fileSystemRepresentation]);
        return NO;
    }
    return YES;
}

+ (BOOL)addItemAtPath:(NSString *)ruta entryName:(NSString *)nombre
               toFile:(FILE *)salida central:(NSMutableArray *)central
               hechos:(NSUInteger *)hechos total:(NSUInteger)total
             progress:(IOProgressBlock)progress cancel:(IOCancelBlock)cancel
                error:(NSError **)error {
    if (cancel && cancel()) {
        if (error) { *error = IOZipError(@"Cancelado"); }
        return NO;
    }

    struct stat info;
    if (lstat([ruta fileSystemRepresentation], &info) != 0) {
        if (error) { *error = IOZipError(@"No se pudo leer un elemento a comprimir"); }
        return NO;
    }
    if (S_ISLNK(info.st_mode)) {
        // Los enlaces se guardan como el archivo destino (se sigue el enlace).
        if (stat([ruta fileSystemRepresentation], &info) != 0) { return YES; }
    }

    uint16_t fecha = 0, hora = 0;
    ioDosDateTime(info.st_mtimespec.tv_sec, &fecha, &hora);

    if (S_ISDIR(info.st_mode)) {
        NSString *nombreDir = [nombre hasSuffix:@"/"] ? nombre
                                                      : [nombre stringByAppendingString:@"/"];
        NSData *nombreDatos = [nombreDir dataUsingEncoding:NSUTF8StringEncoding];
        unsigned long long offset = ftello(salida);

        NSMutableData *local = [NSMutableData data];
        ioAppend32(local, IOZIP_LOCAL);
        ioAppend16(local, 20);
        ioAppend16(local, 0);
        ioAppend16(local, 0);   // store
        ioAppend16(local, hora);
        ioAppend16(local, fecha);
        ioAppend32(local, 0);
        ioAppend32(local, 0);
        ioAppend32(local, 0);
        ioAppend16(local, (uint16_t)nombreDatos.length);
        ioAppend16(local, 0);
        [local appendData:nombreDatos];
        fwrite(local.bytes, 1, local.length, salida);

        [central addObject:[self centralHeaderWithName:nombreDatos method:0 flags:0
                                                   crc:0 comp:0 uncomp:0 offset:offset
                                                 fecha:fecha hora:hora external:0x10]];

        NSArray *hijos = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtPath:ruta error:NULL];
        for (NSString *hijo in hijos) {
            NSString *rutaHijo = [ruta stringByAppendingPathComponent:hijo];
            NSString *nombreHijo = [nombreDir stringByAppendingString:hijo];
            if (![self addItemAtPath:rutaHijo entryName:nombreHijo toFile:salida
                             central:central hechos:hechos total:total
                            progress:progress cancel:cancel error:error]) {
                return NO;
            }
        }
        (*hechos)++;
        if (progress) { progress((double)*hechos / (double)((total > 0) ? total : 1), ruta); }
        return YES;
    }

    if (!S_ISREG(info.st_mode)) {
        // Se saltan dispositivos, sockets, etc.
        (*hechos)++;
        return YES;
    }

    NSData *nombreDatos = [nombre dataUsingEncoding:NSUTF8StringEncoding];
    unsigned long long offset = ftello(salida);

    NSMutableData *local = [NSMutableData data];
    ioAppend32(local, IOZIP_LOCAL);
    ioAppend16(local, 20);
    ioAppend16(local, 0);   // sin data descriptor (tamanos conocidos)
    ioAppend16(local, 8);   // deflate
    ioAppend16(local, hora);
    ioAppend16(local, fecha);
    ioAppend32(local, 0);
    ioAppend32(local, 0);
    ioAppend32(local, 0);
    ioAppend16(local, (uint16_t)nombreDatos.length);
    ioAppend16(local, 0);
    [local appendData:nombreDatos];

    // Reserva el encabezado local y lo reescribe al final con los tamanos.
    long headerPos = ftello(salida);
    fwrite(local.bytes, 1, local.length, salida);
    unsigned long long dataStart = ftello(salida);

    FILE *entrada = fopen([ruta fileSystemRepresentation], "rb");
    if (!entrada) {
        if (error) { *error = IOZipError(@"No se pudo leer un archivo a comprimir"); }
        return NO;
    }

    uLong crc = crc32(0L, Z_NULL, 0);
    uint32_t uncompSize = 0;
    z_stream zs;
    memset(&zs, 0, sizeof(zs));
    if (deflateInit2(&zs, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -15, 8,
                     Z_DEFAULT_STRATEGY) != Z_OK) {
        fclose(entrada);
        if (error) { *error = IOZipError(@"No se pudo inicializar deflate"); }
        return NO;
    }

    uint8_t inBuf[131072];
    uint8_t outBuf[65536];
    size_t leidos = 0;
    while ((leidos = fread(inBuf, 1, sizeof(inBuf), entrada)) > 0) {
        crc = crc32(crc, inBuf, (uInt)leidos);
        uncompSize += (uint32_t)leidos;
        zs.next_in = inBuf;
        zs.avail_in = (uInt)leidos;
        while (zs.avail_in > 0) {
            zs.next_out = outBuf;
            zs.avail_out = (uInt)sizeof(outBuf);
            deflate(&zs, Z_NO_FLUSH);
            size_t hay = sizeof(outBuf) - zs.avail_out;
            if (hay) { fwrite(outBuf, 1, hay, salida); }
        }
        if (cancel && cancel()) {
            deflateEnd(&zs);
            fclose(entrada);
            if (error) { *error = IOZipError(@"Cancelado"); }
            return NO;
        }
    }
    int ret = Z_OK;
    do {
        zs.next_out = outBuf;
        zs.avail_out = (uInt)sizeof(outBuf);
        ret = deflate(&zs, Z_FINISH);
        size_t hay = sizeof(outBuf) - zs.avail_out;
        if (hay) { fwrite(outBuf, 1, hay, salida); }
    } while (ret == Z_OK);
    deflateEnd(&zs);
    fclose(entrada);

    unsigned long long dataEnd = ftello(salida);
    uint32_t compSize = (uint32_t)(dataEnd - dataStart);

    // Reescribe el encabezado local con crc y tamanos reales.
    NSMutableData *localFinal = [NSMutableData data];
    ioAppend32(localFinal, IOZIP_LOCAL);
    ioAppend16(localFinal, 20);
    ioAppend16(localFinal, 0);
    ioAppend16(localFinal, 8);
    ioAppend16(localFinal, hora);
    ioAppend16(localFinal, fecha);
    ioAppend32(localFinal, (uint32_t)crc);
    ioAppend32(localFinal, compSize);
    ioAppend32(localFinal, uncompSize);
    ioAppend16(localFinal, (uint16_t)nombreDatos.length);
    ioAppend16(localFinal, 0);
    [localFinal appendData:nombreDatos];

    long finPos = ftello(salida);
    fseeko(salida, headerPos, SEEK_SET);
    fwrite(localFinal.bytes, 1, localFinal.length, salida);
    fseeko(salida, finPos, SEEK_SET);

    [central addObject:[self centralHeaderWithName:nombreDatos method:8 flags:0
                                               crc:(uint32_t)crc comp:compSize
                                            uncomp:uncompSize offset:(uint32_t)offset
                                             fecha:fecha hora:hora external:0]];

    (*hechos)++;
    if (progress) { progress((double)*hechos / (double)((total > 0) ? total : 1), ruta); }
    return YES;
}

+ (NSData *)centralHeaderWithName:(NSData *)nombre method:(uint16_t)method
                            flags:(uint16_t)flags crc:(uint32_t)crc
                             comp:(uint32_t)comp uncomp:(uint32_t)uncomp
                           offset:(uint32_t)offset fecha:(uint16_t)fecha
                             hora:(uint16_t)hora external:(uint32_t)external {
    NSMutableData *cabecera = [NSMutableData data];
    ioAppend32(cabecera, IOZIP_CENTRAL);
    ioAppend16(cabecera, 20);      // version made by
    ioAppend16(cabecera, 20);      // version needed
    ioAppend16(cabecera, flags);
    ioAppend16(cabecera, method);
    ioAppend16(cabecera, hora);
    ioAppend16(cabecera, fecha);
    ioAppend32(cabecera, crc);
    ioAppend32(cabecera, comp);
    ioAppend32(cabecera, uncomp);
    ioAppend16(cabecera, (uint16_t)nombre.length);
    ioAppend16(cabecera, 0);       // extra
    ioAppend16(cabecera, 0);       // comment
    ioAppend16(cabecera, 0);       // disk
    ioAppend16(cabecera, 0);       // internal attrs
    ioAppend32(cabecera, external);
    ioAppend32(cabecera, offset);
    [cabecera appendData:nombre];
    return cabecera;
}

@end
