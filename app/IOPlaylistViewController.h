#import <UIKit/UIKit.h>

@class IOPlaylistViewController;

// El reproductor actua como fuente de datos de su propia lista.
@protocol IOPlaylistDataSource <NSObject>
- (NSInteger)playlistNumberOfItems;
- (NSString *)playlistPathAtIndex:(NSInteger)index;
- (NSInteger)playlistCurrentIndex;
- (void)playlistSelectIndex:(NSInteger)index;
- (void)playlistRemoveIndex:(NSInteger)index;
@end

// Pantalla completa con la lista de reproduccion. No es una hoja modal: se
// presenta encima del reproductor para que el audio siga sonando.
@interface IOPlaylistViewController : UIViewController

@property (nonatomic, weak) id<IOPlaylistDataSource> dataSource;

@end
