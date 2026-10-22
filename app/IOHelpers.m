#import "IOHelpers.h"

#import <pwd.h>
#import <grp.h>
#import <unistd.h>
#import <stdlib.h>

static NSSet *IOConjunto(NSArray *elementos) {
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        cache = [NSMutableDictionary dictionary];
    });
    NSString *clave = [elementos componentsJoinedByString:@","];
    NSSet *conjunto = cache[clave];
    if (!conjunto) {
        conjunto = [NSSet setWithArray:elementos];
        cache[clave] = conjunto;
    }
    return conjunto;
}

@implementation IOHelpers

#pragma mark - Formatos

+ (NSString *)humanSize:(unsigned long long)bytes {
    if (bytes < 1000ULL) {
        return [NSString stringWithFormat:@"%llu B", bytes];
    }
    double valor = (double)bytes;
    NSArray *unidades = @[@"KB", @"MB", @"GB", @"TB"];
    NSUInteger i = 0;
    valor /= 1024.0;
    while (valor >= 1024.0 && i + 1 < unidades.count) {
        valor /= 1024.0;
        i++;
    }
    NSString *formato = (valor >= 100.0) ? @"%.0f %@" :
                        ((valor >= 10.0) ? @"%.1f %@" : @"%.2f %@");
    return [NSString stringWithFormat:formato, valor, unidades[i]];
}

+ (NSString *)permissionsString:(mode_t)mode {
    char letras[11];
    letras[0] = S_ISDIR(mode) ? 'd' :
                (S_ISLNK(mode) ? 'l' :
                 (S_ISBLK(mode) ? 'b' :
                  (S_ISCHR(mode) ? 'c' :
                   (S_ISFIFO(mode) ? 'p' :
                    (S_ISSOCK(mode) ? 's' : '-')))));
    letras[1] = (mode & S_IRUSR) ? 'r' : '-';
    letras[2] = (mode & S_IWUSR) ? 'w' : '-';
    letras[3] = (mode & S_IXUSR) ? ((mode & S_ISUID) ? 's' : 'x')
                                 : ((mode & S_ISUID) ? 'S' : '-');
    letras[4] = (mode & S_IRGRP) ? 'r' : '-';
    letras[5] = (mode & S_IWGRP) ? 'w' : '-';
    letras[6] = (mode & S_IXGRP) ? ((mode & S_ISGID) ? 's' : 'x')
                                 : ((mode & S_ISGID) ? 'S' : '-');
    letras[7] = (mode & S_IROTH) ? 'r' : '-';
    letras[8] = (mode & S_IWOTH) ? 'w' : '-';
    letras[9] = (mode & S_IXOTH) ? ((mode & S_ISVTX) ? 't' : 'x')
                                 : ((mode & S_ISVTX) ? 'T' : '-');
    letras[10] = '\0';
    return [NSString stringWithUTF8String:letras];
}

+ (NSString *)octalString:(mode_t)mode {
    return [NSString stringWithFormat:@"%03o", (unsigned)(mode & 0777)];
}

+ (mode_t)modeFromOctalString:(NSString *)texto {
    NSString *limpio = [texto stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (limpio.length == 0) {
        return 0;
    }
    // Parseo octal (base 8) sobre la cadena en C, ignorando un posible "0" delante.
    const char *c = [limpio UTF8String];
    unsigned valor = (unsigned)strtoul(c, NULL, 8);
    return (mode_t)(valor & 07777);
}

+ (NSString *)dateString:(NSDate *)fecha {
    if (!fecha) { return @"—"; }
    static NSDateFormatter *formato = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        formato = [[NSDateFormatter alloc] init];
        formato.dateStyle = NSDateFormatterMediumStyle;
        formato.timeStyle = NSDateFormatterShortStyle;
    });
    return [formato stringFromDate:fecha];
}

+ (NSString *)shortDateString:(NSDate *)fecha {
    if (!fecha) { return @"—"; }
    static NSDateFormatter *formato = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        formato = [[NSDateFormatter alloc] init];
        formato.dateFormat = @"d MMM yyyy";
    });
    return [formato stringFromDate:fecha];
}

+ (NSString *)relativeDateString:(NSDate *)fecha {
    if (!fecha) { return @"—"; }
    NSTimeInterval segundos = -[fecha timeIntervalSinceNow];
    if (segundos < 60) { return @"ahora"; }
    if (segundos < 3600) {
        return [NSString stringWithFormat:@"hace %d min", (int)(segundos / 60)];
    }
    if (segundos < 86400) {
        return [NSString stringWithFormat:@"hace %d h", (int)(segundos / 3600)];
    }
    static NSDateFormatter *formato = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        formato = [[NSDateFormatter alloc] init];
        formato.dateFormat = @"d MMM yyyy, HH:mm";
    });
    return [formato stringFromDate:fecha];
}

+ (NSString *)displayNameForItemName:(NSString *)nombre showExtension:(BOOL)mostrar {
    if (mostrar) { return nombre; }
    if ([nombre hasPrefix:@"."]) { return nombre; }
    NSString *ext = [nombre pathExtension];
    if (ext.length == 0) { return nombre; }
    return [nombre stringByDeletingPathExtension];
}

#pragma mark - Deteccion por extension

+ (BOOL)isImageFile:(NSString *)ruta {
    NSString *ext = [ruta pathExtension].lowercaseString;
    return [IOConjunto(@[@"png", @"jpg", @"jpeg", @"gif", @"bmp", @"tif",
                          @"tiff", @"ico", @"icns"]) containsObject:ext];
}

+ (BOOL)isAudioFile:(NSString *)ruta {
    NSString *ext = [ruta pathExtension].lowercaseString;
    return [IOConjunto(@[@"mp3", @"m4a", @"aac", @"wav", @"aif", @"aiff",
                          @"caf", @"m4b", @"aax", @"opus", @"ogg"]) containsObject:ext];
}

+ (BOOL)isVideoFile:(NSString *)ruta {
    NSString *ext = [ruta pathExtension].lowercaseString;
    return [IOConjunto(@[@"mp4", @"mov", @"m4v", @"3gp", @"ts", @"mpg",
                          @"mpeg", @"m2ts"]) containsObject:ext];
}

+ (BOOL)isTextFile:(NSString *)ruta {
    NSString *ext = [ruta pathExtension].lowercaseString;
    return [IOConjunto(@[@"txt", @"md", @"markdown", @"json", @"xml", @"plist",
                          @"strings", @"conf", @"cfg", @"ini", @"log", @"h", @"m",
                          @"mm", @"c", @"cc", @"cpp", @"hpp", @"swift", @"js",
                          @"css", @"html", @"htm", @"csv", @"tsv", @"sh", @"py",
                          @"rb", @"yml", @"yaml", @"sql", @"properties", @"pem",
                          @"crt", @"key", @"tbd", @"xib", @"entitlements", @"pbxproj",
                          @"gitignore", @"env", @"rc", @"service", @"mobileconfig",
                          @"srt", @"vtt", @"passwd", @"hosts", @"fstab"]) containsObject:ext];
}

+ (BOOL)isArchiveFile:(NSString *)ruta {
    NSString *ext = [ruta pathExtension].lowercaseString;
    return [IOConjunto(@[@"zip", @"ipa", @"deb", @"epub", @"jar"]) containsObject:ext];
}

+ (BOOL)isPlistFile:(NSString *)ruta {
    NSString *ext = [ruta pathExtension].lowercaseString;
    return [ext isEqualToString:@"plist"];
}

+ (BOOL)isPreviewable:(NSString *)ruta {
    return [self isImageFile:ruta] || [self isAudioFile:ruta] ||
           [self isVideoFile:ruta] || [self isTextFile:ruta] ||
           [self isArchiveFile:ruta];
}

#pragma mark - Descripciones

+ (NSString *)kindDescriptionForPath:(NSString *)ruta isDirectory:(BOOL)esCarpeta {
    if (esCarpeta) { return @"Carpeta"; }
    if ([self isImageFile:ruta]) { return @"Imagen"; }
    if ([self isAudioFile:ruta]) { return @"Audio"; }
    if ([self isVideoFile:ruta]) { return @"Video"; }
    if ([self isArchiveFile:ruta]) {
        NSString *ext = [ruta pathExtension].lowercaseString;
        if ([ext isEqualToString:@"ipa"]) { return @"Paquete IPA"; }
        if ([ext isEqualToString:@"deb"]) { return @"Paquete DEB"; }
        return @"Archivo comprimido";
    }
    if ([self isPlistFile:ruta]) { return @"Lista de propiedades"; }
    if ([self isTextFile:ruta]) { return @"Texto"; }
    NSString *ext = [ruta pathExtension].uppercaseString;
    if (ext.length) { return [NSString stringWithFormat:@"Documento %@", ext]; }
    return @"Documento";
}

+ (NSString *)magicDescriptionForPath:(NSString *)ruta {
    NSFileHandle *manejador = [NSFileHandle fileHandleForReadingAtPath:ruta];
    if (!manejador) { return nil; }
    NSData *datos = [manejador readDataOfLength:8];
    [manejador closeFile];
    if (datos.length < 4) { return nil; }
    const unsigned char *b = datos.bytes;
    if (b[0] == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G') { return @"PNG"; }
    if (b[0] == 0xFF && b[1] == 0xD8) { return @"JPEG"; }
    if (b[0] == 'G' && b[1] == 'I' && b[2] == 'F') { return @"GIF"; }
    if (b[0] == '%' && b[1] == 'P' && b[2] == 'D' && b[3] == 'F') { return @"PDF"; }
    if (b[0] == 'P' && b[1] == 'K') { return @"ZIP"; }
    if (b[0] == 'B' && b[1] == 'M') { return @"BMP"; }
    if (b[0] == 0xFE && b[1] == 0xED && b[2] == 0xFA && (b[3] == 0xCE || b[3] == 0xCF)) {
        return @"Mach-O (32 bits, big-endian)";
    }
    if ((b[0] == 0xCE || b[0] == 0xCF) && b[1] == 0xFA && b[2] == 0xED && b[3] == 0xFE) {
        return @"Mach-O (32 bits)";
    }
    if ((b[0] == 0xCF || b[0] == 0xCA) && b[1] == 0xFA && b[2] == 0xED && b[3] == 0xFE) {
        return @"Mach-O (64 bits)";
    }
    if (b[0] == 'I' && b[1] == 'D' && b[2] == '3') { return @"MP3"; }
    if (b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) { return @"MP3/AAC"; }
    if (b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F') { return @"RIFF (WAV/AVI)"; }
    if (b[0] == 0x00 && b[1] == 0x00 && b[2] == 0x00 && (b[3] == 0x18 || b[3] == 0x1C ||
                                                          b[3] == 0x20 || b[3] == 0x2C)) {
        return @"MP4/MOV";
    }
    return nil;
}

#pragma mark - Dueno/grupo

+ (NSString *)ownerNameForUID:(uid_t)uid {
    struct passwd *pw = getpwuid(uid);
    if (pw && pw->pw_name) {
        return [NSString stringWithUTF8String:pw->pw_name];
    }
    return [NSString stringWithFormat:@"%u", (unsigned)uid];
}

+ (NSString *)groupNameForGID:(gid_t)gid {
    struct group *gr = getgrgid(gid);
    if (gr && gr->gr_name) {
        return [NSString stringWithUTF8String:gr->gr_name];
    }
    return [NSString stringWithFormat:@"%u", (unsigned)gid];
}

@end
