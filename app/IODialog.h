#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, IODialogActionStyle) {
    IODialogActionStyleDefault = 0,
    IODialogActionStyleSelected,
    IODialogActionStyleDestructive,
    IODialogActionStyleCancel
};

typedef NS_ENUM(NSInteger, IODialogStyle) {
    IODialogStyleAlert = 0,
    IODialogStyleSheet
};

// Accion de un dialogo.
@interface IODialogAction : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) IODialogActionStyle style;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, copy) void (^handler)(void);
+ (instancetype)actionWithTitle:(NSString *)title
                          style:(IODialogActionStyle)style
                        handler:(void (^)(void))handler;
@end

// Dialogo propio de la app: alerta centrada o hoja inferior, con acciones y
// campos de texto. Sustituye a UIAlertController en toda la aplicacion.
@interface IODialog : UIViewController

+ (instancetype)alertWithTitle:(NSString *)title message:(NSString *)message;
+ (instancetype)sheetWithTitle:(NSString *)title message:(NSString *)message;

@property (nonatomic, assign) IODialogStyle style;
@property (nonatomic, readonly) NSArray<UITextField *> *textFields;
@property (nonatomic, readonly) NSArray<IODialogAction *> *actions;

- (IODialogAction *)addAction:(NSString *)title
                        style:(IODialogActionStyle)style
                      handler:(void (^)(void))handler;
- (UITextField *)addTextFieldWithPlaceholder:(NSString *)placeholder text:(NSString *)text;
- (void)presentIn:(UIViewController *)viewController;

// Atajos.
+ (void)showAlertIn:(UIViewController *)vc title:(NSString *)title message:(NSString *)message;
+ (void)showErrorIn:(UIViewController *)vc error:(NSError *)error;
+ (void)showConfirmIn:(UIViewController *)vc
                title:(NSString *)title
              message:(NSString *)message
          destructive:(BOOL)destructive
         confirmTitle:(NSString *)confirmTitle
              handler:(void (^)(void))handler;
+ (void)showSheetIn:(UIViewController *)vc
              title:(NSString *)title
            actions:(NSArray<IODialogAction *> *)actions;

@end
