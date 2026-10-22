#import <Foundation/Foundation.h>
#import <sys/stat.h>

// Un archivo o carpeta, con sus metadatos ya leidos (lstat/stat).
@interface IOFileItem : NSObject

@property (nonatomic, copy)   NSString *name;
@property (nonatomic, copy)   NSString *path;
@property (nonatomic, assign) BOOL isDirectory;
@property (nonatomic, assign) BOOL isSymlink;
@property (nonatomic, assign) BOOL isHidden;
@property (nonatomic, assign) BOOL isReadable;
@property (nonatomic, assign) BOOL isWritable;
@property (nonatomic, assign) BOOL isExecutable;
@property (nonatomic, assign) unsigned long long size;
@property (nonatomic, assign) unsigned long long allocatedSize;
@property (nonatomic, strong) NSDate *modificationDate;
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, assign) mode_t mode;
@property (nonatomic, assign) uid_t uid;
@property (nonatomic, assign) gid_t gid;
@property (nonatomic, assign) NSUInteger childCount;
@property (nonatomic, assign) BOOL childCountComputed;

// Lee la entrada. Si compute=YES y es carpeta, cuenta sus hijos (hasta 9999).
+ (instancetype)itemAtPath:(NSString *)path computeChildCount:(BOOL)compute;
+ (instancetype)itemAtPath:(NSString *)path;

- (NSString *)extension;
- (NSString *)kindDescription;
- (NSString *)permissionsString;
- (NSString *)displayNameWithExtension:(BOOL)mostrar;

@end
