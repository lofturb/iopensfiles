#import "IOStore.h"

static NSString * const kFavoritesKey = @"IO.favorites";
static NSString * const kRecentsKey = @"IO.recents";
static const NSUInteger kMaxRecents = 30;

@implementation IOStore

+ (instancetype)shared {
    static IOStore *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IOStore alloc] init];
    });
    return instancia;
}

- (NSArray<NSString *> *)favorites {
    return [[NSUserDefaults standardUserDefaults] arrayForKey:kFavoritesKey] ?: @[];
}

- (NSArray<NSString *> *)recents {
    return [[NSUserDefaults standardUserDefaults] arrayForKey:kRecentsKey] ?: @[];
}

- (BOOL)isFavorite:(NSString *)path {
    return [self.favorites containsObject:path];
}

- (void)toggleFavorite:(NSString *)path {
    if ([self isFavorite:path]) {
        [self removeFavorite:path];
    } else {
        [self addFavorite:path];
    }
}

- (void)addFavorite:(NSString *)path {
    if (path.length == 0) { return; }
    NSMutableArray *favoritos = [self.favorites mutableCopy];
    if ([favoritos containsObject:path]) { return; }
    [favoritos addObject:path];
    [[NSUserDefaults standardUserDefaults] setObject:favoritos forKey:kFavoritesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)removeFavorite:(NSString *)path {
    NSMutableArray *favoritos = [self.favorites mutableCopy];
    if ([favoritos containsObject:path]) {
        [favoritos removeObject:path];
        [[NSUserDefaults standardUserDefaults] setObject:favoritos forKey:kFavoritesKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)addRecent:(NSString *)path {
    if (path.length == 0) { return; }
    NSMutableArray *recientes = [self.recents mutableCopy];
    [recientes removeObject:path];
    [recientes insertObject:path atIndex:0];
    if (recientes.count > kMaxRecents) {
        [recientes removeObjectsInRange:NSMakeRange(kMaxRecents,
                                                    recientes.count - kMaxRecents)];
    }
    [[NSUserDefaults standardUserDefaults] setObject:recientes forKey:kRecentsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)clearRecents {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRecentsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark - Portapapeles

@implementation IOClipboard

+ (instancetype)shared {
    static IOClipboard *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IOClipboard alloc] init];
    });
    return instancia;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _paths = @[];
        _isCut = NO;
    }
    return self;
}

- (BOOL)hasItems {
    return self.paths.count > 0;
}

- (NSUInteger)count {
    return self.paths.count;
}

- (void)setPaths:(NSArray<NSString *> *)paths cut:(BOOL)cut {
    self.paths = paths ?: @[];
    self.isCut = cut;
}

- (void)clear {
    self.paths = @[];
    self.isCut = NO;
}

@end
