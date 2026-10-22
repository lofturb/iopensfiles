#import "AppDelegate.h"

#import "IOTheme.h"
#import "IOSettings.h"
#import "IORootContainerViewController.h"

#import <AVFoundation/AVFoundation.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
        didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Carga los ajustes guardados y aplica el tema (claro u oscuro).
    IOSettings *ajustes = [IOSettings shared];
    [IOTheme shared].dark = ajustes.darkMode;

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [IOTheme shared].background;

    // El contenedor monta la barra lateral + el navegador (estilo iPad moderno).
    IORootContainerViewController *raiz = [[IORootContainerViewController alloc] init];
    self.window.rootViewController = raiz;
    [self.window makeKeyAndVisible];

    // Que el audio siga sonando si el usuario bloquea la pantalla mientras suena
    // un archivo de musica o un video.
    NSError *errorSesion = nil;
    AVAudioSession *sesion = [AVAudioSession sharedInstance];
    [sesion setCategory:AVAudioSessionCategoryPlayback error:&errorSesion];
    [sesion setActive:YES error:&errorSesion];

    // Avisa a las vistas de que el tema ya esta listo.
    [[NSNotificationCenter defaultCenter]
        postNotificationName:IOThemeDidChangeNotification
                      object:nil];

    return YES;
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    // Un A5 tiene 512 MB: al primer aviso, vaciamos las caches de imagenes.
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"IOMemoryWarningNotification"
                      object:nil];
}

@end
