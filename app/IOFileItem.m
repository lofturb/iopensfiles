#import "IOFileItem.h"
#import "IOHelpers.h"

#import <unistd.h>

@implementation IOFileItem

+ (instancetype)itemAtPath:(NSString *)path {
    return [self itemAtPath:path computeChildCount:NO];
}

+ (instancetype)itemAtPath:(NSString *)path computeChildCount:(BOOL)compute {
    if (path.length == 0) { return nil; }

    struct stat info;
    const char *ruta = [path fileSystemRepresentation];
    if (lstat(ruta, &info) != 0) {
        return nil;
    }

    IOFileItem *item = [[IOFileItem alloc] init];
    item.path = path;
    item.name = [path lastPathComponent];
    if (item.name.length == 0) { item.name = path; }

    item.isSymlink = S_ISLNK(info.st_mode);
    item.mode = info.st_mode;
    item.uid = info.st_uid;
    item.gid = info.st_gid;
    item.size = (unsigned long long)info.st_size;
    item.allocatedSize = (unsigned long long)info.st_blocks * 512ULL;
    item.creationDate = [NSDate dateWithTimeIntervalSince1970:info.st_birthtimespec.tv_sec];
    item.modificationDate = [NSDate dateWithTimeIntervalSince1970:info.st_mtimespec.tv_sec];

    // Si es un enlace, miramos el destino para saber si apunta a una carpeta.
    if (item.isSymlink) {
        struct stat destino;
        if (stat(ruta, &destino) == 0) {
            item.isDirectory = S_ISDIR(destino.st_mode);
            item.size = (unsigned long long)destino.st_size;
        } else {
            item.isDirectory = NO;
        }
    } else {
        item.isDirectory = S_ISDIR(info.st_mode);
    }

    item.isHidden = ([item.name hasPrefix:@"."] || (info.st_flags & 0x8000) != 0);
    item.isReadable = (access(ruta, R_OK) == 0);
    item.isWritable = (access(ruta, W_OK) == 0);
    item.isExecutable = (access(ruta, X_OK) == 0);

    if (compute && item.isDirectory) {
        NSArray *hijos = [[NSFileManager defaultManager]
                          contentsOfDirectoryAtPath:path error:NULL];
        item.childCount = hijos.count;
        item.childCountComputed = YES;
    }

    return item;
}

- (NSString *)extension {
    return [self.name pathExtension].lowercaseString;
}

- (NSString *)kindDescription {
    return [IOHelpers kindDescriptionForPath:self.path isDirectory:self.isDirectory];
}

- (NSString *)permissionsString {
    return [IOHelpers permissionsString:self.mode];
}

- (NSString *)displayNameWithExtension:(BOOL)mostrar {
    return [IOHelpers displayNameForItemName:self.name showExtension:mostrar];
}

@end
