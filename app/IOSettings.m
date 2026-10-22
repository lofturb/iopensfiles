#import "IOSettings.h"

static NSString * const kShowHidden = @"IO.showHidden";
static NSString * const kFoldersFirst = @"IO.foldersFirst";
static NSString * const kSortAscending = @"IO.sortAscending";
static NSString * const kSortKey = @"IO.sortKey";
static NSString * const kDarkMode = @"IO.darkMode";
static NSString * const kConfirmDelete = @"IO.confirmDelete";
static NSString * const kShowDetails = @"IO.showDetails";
static NSString * const kThumbnails = @"IO.thumbnails";
static NSString * const kShowExtensions = @"IO.showExtensions";
static NSString * const kAskBeforeOverwrite = @"IO.askBeforeOverwrite";
static NSString * const kStartPath = @"IO.startPath";
static NSString * const kOpenAtLastPath = @"IO.openAtLastPath";
static NSString * const kLastPath = @"IO.lastPath";

@interface IOSettings ()
@property (nonatomic, strong) NSUserDefaults *defaults;
@property (nonatomic, assign) BOOL cargado;
@end

@implementation IOSettings

+ (instancetype)shared {
    static IOSettings *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IOSettings alloc] init];
    });
    return instancia;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _defaults = [NSUserDefaults standardUserDefaults];
        [self registrarValoresPorDefecto];
        _cargado = YES;
    }
    return self;
}

- (void)registrarValoresPorDefecto {
    NSDictionary *porDefecto = @{
        kShowHidden: @NO,
        kFoldersFirst: @YES,
        kSortAscending: @YES,
        kSortKey: @(IOSortByName),
        kDarkMode: @NO,
        kConfirmDelete: @YES,
        kShowDetails: @YES,
        kThumbnails: @YES,
        kShowExtensions: @YES,
        kAskBeforeOverwrite: @YES,
        kStartPath: @"/",
        kOpenAtLastPath: @YES,
        kLastPath: @"/"
    };
    [self.defaults registerDefaults:porDefecto];
}

#pragma mark - Accesores

- (BOOL)showHidden { return [self.defaults boolForKey:kShowHidden]; }
- (void)setShowHidden:(BOOL)v { [self.defaults setBool:v forKey:kShowHidden]; [self save]; }

- (BOOL)foldersFirst { return [self.defaults boolForKey:kFoldersFirst]; }
- (void)setFoldersFirst:(BOOL)v { [self.defaults setBool:v forKey:kFoldersFirst]; [self save]; }

- (BOOL)sortAscending { return [self.defaults boolForKey:kSortAscending]; }
- (void)setSortAscending:(BOOL)v { [self.defaults setBool:v forKey:kSortAscending]; [self save]; }

- (IOSortKey)sortKey { return (IOSortKey)[self.defaults integerForKey:kSortKey]; }
- (void)setSortKey:(IOSortKey)v { [self.defaults setInteger:v forKey:kSortKey]; [self save]; }

- (BOOL)darkMode { return [self.defaults boolForKey:kDarkMode]; }
- (void)setDarkMode:(BOOL)v { [self.defaults setBool:v forKey:kDarkMode]; [self save]; }

- (BOOL)confirmDelete { return [self.defaults boolForKey:kConfirmDelete]; }
- (void)setConfirmDelete:(BOOL)v { [self.defaults setBool:v forKey:kConfirmDelete]; [self save]; }

- (BOOL)showDetails { return [self.defaults boolForKey:kShowDetails]; }
- (void)setShowDetails:(BOOL)v { [self.defaults setBool:v forKey:kShowDetails]; [self save]; }

- (BOOL)thumbnails { return [self.defaults boolForKey:kThumbnails]; }
- (void)setThumbnails:(BOOL)v { [self.defaults setBool:v forKey:kThumbnails]; [self save]; }

- (BOOL)showExtensions { return [self.defaults boolForKey:kShowExtensions]; }
- (void)setShowExtensions:(BOOL)v { [self.defaults setBool:v forKey:kShowExtensions]; [self save]; }

- (BOOL)askBeforeOverwrite { return [self.defaults boolForKey:kAskBeforeOverwrite]; }
- (void)setAskBeforeOverwrite:(BOOL)v { [self.defaults setBool:v forKey:kAskBeforeOverwrite]; [self save]; }

- (NSString *)startPath {
    NSString *valor = [self.defaults stringForKey:kStartPath];
    return valor.length ? valor : @"/";
}
- (void)setStartPath:(NSString *)v { [self.defaults setObject:v forKey:kStartPath]; [self save]; }

- (BOOL)openAtLastPath { return [self.defaults boolForKey:kOpenAtLastPath]; }
- (void)setOpenAtLastPath:(BOOL)v { [self.defaults setBool:v forKey:kOpenAtLastPath]; [self save]; }

- (NSString *)lastPath {
    NSString *valor = [self.defaults stringForKey:kLastPath];
    return valor.length ? valor : @"/";
}
- (void)setLastPath:(NSString *)v { [self.defaults setObject:v forKey:kLastPath]; [self save]; }

- (void)save {
    [self.defaults synchronize];
}

@end
