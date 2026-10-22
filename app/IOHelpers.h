#import <Foundation/Foundation.h>
#import <sys/stat.h>

// Funciones de formato y deteccion de tipo de archivo. Nada de estado.
@interface IOHelpers : NSObject

// --- Formatos ---
+ (NSString *)humanSize:(unsigned long long)bytes;
+ (NSString *)permissionsString:(mode_t)mode;
+ (NSString *)octalString:(mode_t)mode;
+ (mode_t)modeFromOctalString:(NSString *)texto;
+ (NSString *)dateString:(NSDate *)fecha;
+ (NSString *)shortDateString:(NSDate *)fecha;
+ (NSString *)relativeDateString:(NSDate *)fecha;
+ (NSString *)displayNameForItemName:(NSString *)nombre showExtension:(BOOL)mostrar;

// --- Deteccion por extension ---
+ (BOOL)isImageFile:(NSString *)ruta;
+ (BOOL)isAudioFile:(NSString *)ruta;
+ (BOOL)isVideoFile:(NSString *)ruta;
+ (BOOL)isTextFile:(NSString *)ruta;
+ (BOOL)isArchiveFile:(NSString *)ruta;
+ (BOOL)isPlistFile:(NSString *)ruta;
+ (BOOL)isPreviewable:(NSString *)ruta;

// --- Descripciones ---
+ (NSString *)kindDescriptionForPath:(NSString *)ruta isDirectory:(BOOL)esCarpeta;
+ (NSString *)magicDescriptionForPath:(NSString *)ruta;

// --- Dueno/grupo ---
+ (NSString *)ownerNameForUID:(uid_t)uid;
+ (NSString *)groupNameForGID:(gid_t)gid;

@end
