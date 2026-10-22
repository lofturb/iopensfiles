#import <UIKit/UIKit.h>

// Reproductor de audio y video con lista de reproduccion, aleatorio,
// repeticion y control de velocidad.
@interface IOMediaPlayerViewController : UIViewController

- (instancetype)initWithPath:(NSString *)path;
- (instancetype)initWithPaths:(NSArray<NSString *> *)paths startIndex:(NSInteger)index;

@end
