#import <Foundation/Foundation.h>

// Favoritos y recientes (persisten en NSUserDefaults).
@interface IOStore : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) NSArray<NSString *> *favorites;
@property (nonatomic, readonly) NSArray<NSString *> *recents;

- (BOOL)isFavorite:(NSString *)path;
- (void)toggleFavorite:(NSString *)path;
- (void)addFavorite:(NSString *)path;
- (void)removeFavorite:(NSString *)path;

- (void)addRecent:(NSString *)path;
- (void)clearRecents;

@end

// Portapapeles interno para copiar/cortar/pegar rutas dentro de la app.
@interface IOClipboard : NSObject

+ (instancetype)shared;

@property (nonatomic, copy) NSArray<NSString *> *paths;
@property (nonatomic, assign) BOOL isCut;
@property (nonatomic, readonly) BOOL hasItems;
@property (nonatomic, readonly) NSUInteger count;

- (void)setPaths:(NSArray<NSString *> *)paths cut:(BOOL)cut;
- (void)clear;

@end
