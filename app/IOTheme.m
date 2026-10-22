#import "IOTheme.h"

NSString * const IOThemeDidChangeNotification = @"IOThemeDidChangeNotification";

@implementation IOTheme

+ (instancetype)shared {
    static IOTheme *instancia = nil;
    static dispatch_once_t unaVez;
    dispatch_once(&unaVez, ^{
        instancia = [[IOTheme alloc] init];
    });
    return instancia;
}

+ (void)applyDark:(BOOL)dark {
    [IOTheme shared].dark = dark;
    UIWindow *ventana = [[UIApplication sharedApplication] keyWindow];
    ventana.tintColor = [IOTheme shared].accent;
    ventana.backgroundColor = [IOTheme shared].background;
    for (UIWindow *w in [[UIApplication sharedApplication] windows]) {
        w.tintColor = [IOTheme shared].accent;
        w.backgroundColor = [IOTheme shared].background;
    }
    [UIApplication sharedApplication].statusBarStyle = dark
        ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:IOThemeDidChangeNotification
                      object:nil];
}

+ (UIColor *)colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha {
    CGFloat r = ((hex >> 16) & 0xFF) / 255.0;
    CGFloat g = ((hex >> 8) & 0xFF) / 255.0;
    CGFloat b = (hex & 0xFF) / 255.0;
    return [UIColor colorWithRed:r green:g blue:b alpha:alpha];
}

#pragma mark - Colores

- (UIColor *)background {
    return self.dark ? [IOTheme colorWithHex:0x000000 alpha:1.0]
                     : [IOTheme colorWithHex:0xF2F2F7 alpha:1.0];
}

- (UIColor *)cardBackground {
    return self.dark ? [IOTheme colorWithHex:0x1C1C1E alpha:1.0]
                     : [IOTheme colorWithHex:0xFFFFFF alpha:1.0];
}

- (UIColor *)elevatedBackground {
    return self.dark ? [IOTheme colorWithHex:0x2C2C2E alpha:1.0]
                     : [IOTheme colorWithHex:0xFFFFFF alpha:1.0];
}

- (UIColor *)sidebarBackground {
    return self.dark ? [IOTheme colorWithHex:0x0E0E10 alpha:1.0]
                     : [IOTheme colorWithHex:0xF7F7FA alpha:1.0];
}

- (UIColor *)textPrimary {
    return self.dark ? [IOTheme colorWithHex:0xFFFFFF alpha:1.0]
                     : [IOTheme colorWithHex:0x1C1C1E alpha:1.0];
}

- (UIColor *)textSecondary {
    return self.dark ? [IOTheme colorWithHex:0x98989F alpha:1.0]
                     : [IOTheme colorWithHex:0x6E6E73 alpha:1.0];
}

- (UIColor *)textTertiary {
    return self.dark ? [IOTheme colorWithHex:0x6E6E73 alpha:1.0]
                     : [IOTheme colorWithHex:0xAEAEB2 alpha:1.0];
}

- (UIColor *)separator {
    return self.dark ? [IOTheme colorWithHex:0x38383A alpha:1.0]
                     : [IOTheme colorWithHex:0xE3E3E8 alpha:1.0];
}

- (UIColor *)accent {
    return [IOTheme colorWithHex:0x0A84FF alpha:1.0];
}

- (UIColor *)accentSoft {
    return self.dark ? [IOTheme colorWithHex:0x0A84FF alpha:0.24]
                     : [IOTheme colorWithHex:0x0A84FF alpha:0.12];
}

- (UIColor *)danger {
    return self.dark ? [IOTheme colorWithHex:0xFF453A alpha:1.0]
                     : [IOTheme colorWithHex:0xFF3B30 alpha:1.0];
}

- (UIColor *)success {
    return self.dark ? [IOTheme colorWithHex:0x30D158 alpha:1.0]
                     : [IOTheme colorWithHex:0x34C759 alpha:1.0];
}

- (UIColor *)warning {
    return self.dark ? [IOTheme colorWithHex:0xFFD60A alpha:1.0]
                     : [IOTheme colorWithHex:0xFF9F0A alpha:1.0];
}

- (UIColor *)controlFill {
    return self.dark ? [IOTheme colorWithHex:0x2C2C2E alpha:1.0]
                     : [IOTheme colorWithHex:0xEFEFF4 alpha:1.0];
}

- (UIColor *)selectionFill {
    return self.dark ? [IOTheme colorWithHex:0x0A84FF alpha:0.28]
                     : [IOTheme colorWithHex:0x0A84FF alpha:0.14];
}

- (UIColor *)fieldBackground {
    return self.dark ? [IOTheme colorWithHex:0x2C2C2E alpha:1.0]
                     : [IOTheme colorWithHex:0xF2F2F7 alpha:1.0];
}

- (UIColor *)overlay {
    return [UIColor colorWithWhite:0.0 alpha:(self.dark ? 0.66 : 0.42)];
}

- (UIColor *)separatorStrong {
    return self.dark ? [IOTheme colorWithHex:0x545458 alpha:1.0]
                     : [IOTheme colorWithHex:0xC7C7CC alpha:1.0];
}

#pragma mark - Medidas

- (CGFloat)cornerRadius { return 12.0; }
- (CGFloat)largeCornerRadius { return 18.0; }
- (CGFloat)rowHeight { return 64.0; }
- (CGFloat)gutter { return 16.0; }
- (CGFloat)sidebarWidth { return 300.0; }

#pragma mark - Tipografia

- (UIFont *)fontNavTitle {
    return [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
}

- (UIFont *)fontTitle {
    return [UIFont systemFontOfSize:22.0 weight:UIFontWeightBold];
}

- (UIFont *)fontHeadline {
    return [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
}

- (UIFont *)fontBody {
    return [UIFont systemFontOfSize:16.0 weight:UIFontWeightRegular];
}

- (UIFont *)fontSubhead {
    return [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
}

- (UIFont *)fontCaption {
    return [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
}

- (UIFont *)fontMono:(CGFloat)size {
    return [UIFont fontWithName:@"Menlo" size:size] ?: [UIFont systemFontOfSize:size];
}

@end
