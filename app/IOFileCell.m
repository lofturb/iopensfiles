#import "IOFileCell.h"
#import "IOTheme.h"
#import "IOSettings.h"
#import "IOFileIcons.h"
#import "IOHelpers.h"

@interface IOFileCell ()
@property (nonatomic, copy) NSString *rutaActual;
@end

@implementation IOFileCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
               reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self construir];
    }
    return self;
}

- (void)construir {
    self.selectionStyle = UITableViewCellSelectionStyleDefault;

    CGFloat ladoIcono = 42.0;

    self.iconoVista = [[UIImageView alloc] init];
    self.iconoVista.translatesAutoresizingMaskIntoConstraints = NO;
    self.iconoVista.contentMode = UIViewContentModeScaleAspectFill;
    self.iconoVista.layer.cornerRadius = 10.0;
    self.iconoVista.layer.masksToBounds = YES;
    [self.contentView addSubview:self.iconoVista];

    self.titulo = [[UILabel alloc] init];
    self.titulo.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.titulo];

    self.subtitulo = [[UILabel alloc] init];
    self.subtitulo.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.subtitulo];

    self.detalle = [[UILabel alloc] init];
    self.detalle.translatesAutoresizingMaskIntoConstraints = NO;
    self.detalle.textAlignment = NSTextAlignmentRight;
    [self.contentView addSubview:self.detalle];

    self.chevron = [[UIImageView alloc] init];
    self.chevron.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevron.contentMode = UIViewContentModeCenter;
    [self.contentView addSubview:self.chevron];

    [self.contentView addConstraints:@[
        [NSLayoutConstraint constraintWithItem:self.iconoVista attribute:NSLayoutAttributeLeading
            relatedBy:NSLayoutRelationEqual toItem:self.contentView
            attribute:NSLayoutAttributeLeading multiplier:1 constant:16],
        [NSLayoutConstraint constraintWithItem:self.iconoVista attribute:NSLayoutAttributeCenterY
            relatedBy:NSLayoutRelationEqual toItem:self.contentView
            attribute:NSLayoutAttributeCenterY multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.iconoVista attribute:NSLayoutAttributeWidth
            relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute
            multiplier:1 constant:ladoIcono],
        [NSLayoutConstraint constraintWithItem:self.iconoVista attribute:NSLayoutAttributeHeight
            relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute
            multiplier:1 constant:ladoIcono],

        [NSLayoutConstraint constraintWithItem:self.titulo attribute:NSLayoutAttributeLeading
            relatedBy:NSLayoutRelationEqual toItem:self.iconoVista
            attribute:NSLayoutAttributeTrailing multiplier:1 constant:12],
        [NSLayoutConstraint constraintWithItem:self.titulo attribute:NSLayoutAttributeTrailing
            relatedBy:NSLayoutRelationLessThanOrEqual toItem:self.detalle
            attribute:NSLayoutAttributeLeading multiplier:1 constant:-8],

        [NSLayoutConstraint constraintWithItem:self.subtitulo attribute:NSLayoutAttributeLeading
            relatedBy:NSLayoutRelationEqual toItem:self.titulo
            attribute:NSLayoutAttributeLeading multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.subtitulo attribute:NSLayoutAttributeTrailing
            relatedBy:NSLayoutRelationLessThanOrEqual toItem:self.detalle
            attribute:NSLayoutAttributeLeading multiplier:1 constant:-8],

        [NSLayoutConstraint constraintWithItem:self.detalle attribute:NSLayoutAttributeTrailing
            relatedBy:NSLayoutRelationEqual toItem:self.contentView
            attribute:NSLayoutAttributeTrailing multiplier:1 constant:-14],
        [NSLayoutConstraint constraintWithItem:self.detalle attribute:NSLayoutAttributeCenterY
            relatedBy:NSLayoutRelationEqual toItem:self.contentView
            attribute:NSLayoutAttributeCenterY multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.detalle attribute:NSLayoutAttributeWidth
            relatedBy:NSLayoutRelationLessThanOrEqual toItem:nil
            attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:96],

        [NSLayoutConstraint constraintWithItem:self.chevron attribute:NSLayoutAttributeTrailing
            relatedBy:NSLayoutRelationEqual toItem:self.contentView
            attribute:NSLayoutAttributeTrailing multiplier:1 constant:-10],
        [NSLayoutConstraint constraintWithItem:self.chevron attribute:NSLayoutAttributeCenterY
            relatedBy:NSLayoutRelationEqual toItem:self.contentView
            attribute:NSLayoutAttributeCenterY multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:self.chevron attribute:NSLayoutAttributeWidth
            relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute
            multiplier:1 constant:16],
        [NSLayoutConstraint constraintWithItem:self.chevron attribute:NSLayoutAttributeHeight
            relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute
            multiplier:1 constant:16]
    ]];

    // El titulo y el subtitulo se reparten el alto de la fila.
    [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.titulo
        attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
        toItem:self.contentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:-1]];
    [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.subtitulo
        attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual
        toItem:self.contentView attribute:NSLayoutAttributeCenterY multiplier:1 constant:1]];

    [self aplicarTema];
}

- (void)aplicarTema {
    IOTheme *tema = [IOTheme shared];
    self.backgroundColor = tema.cardBackground;
    self.contentView.backgroundColor = tema.cardBackground;
    self.titulo.textColor = tema.textPrimary;
    self.titulo.font = [tema fontHeadline];
    self.subtitulo.textColor = tema.textSecondary;
    self.subtitulo.font = [tema fontSubhead];
    self.detalle.textColor = tema.textSecondary;
    self.detalle.font = [tema fontSubhead];
    self.chevron.image = [[IOFileIcons shared] glyph:IOGlyphChevronRight
                                                 size:14.0
                                                color:tema.textTertiary];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.rutaActual = nil;
    self.iconoVista.image = nil;
    self.titulo.text = nil;
    self.subtitulo.text = nil;
    self.detalle.text = nil;
    self.chevron.hidden = NO;
    self.alpha = 1.0;
    [self aplicarTema];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    self.chevron.hidden = editing;
}

- (void)configurarConItem:(IOFileItem *)item {
    IOSettings *ajustes = [IOSettings shared];
    self.rutaActual = item.path;

    NSString *nombre = [item displayNameWithExtension:ajustes.showExtensions];
    self.titulo.text = nombre;

    if (item.isDirectory) {
        if (item.childCountComputed) {
            self.subtitulo.text = (item.childCount == 1)
                ? @"1 elemento"
                : [NSString stringWithFormat:@"%lu elementos",
                   (unsigned long)item.childCount];
        } else {
            self.subtitulo.text = @"Carpeta";
        }
        self.detalle.text = @"";
    } else {
        self.subtitulo.text = [item kindDescription];
        self.detalle.text = [IOHelpers humanSize:item.size];
    }

    BOOL detalles = ajustes.showDetails;
    self.subtitulo.hidden = !detalles;
    self.detalle.hidden = !detalles;

    self.chevron.hidden = self.editing || !item.isDirectory;
    self.alpha = item.isHidden ? 0.55 : 1.0;

    // Icono: miniatura si es imagen y esta activada, si no, icono vectorial.
    BOOL esImagen = (!item.isDirectory && [IOHelpers isImageFile:item.path]);
    if (ajustes.thumbnails && esImagen) {
        UIImage *miniatura = [[IOFileIcons shared] cachedThumbnailForPath:item.path
                                                                    size:42.0];
        if (miniatura) {
            self.iconoVista.image = miniatura;
        } else {
            self.iconoVista.image = [[IOFileIcons shared] fileIconForItem:item size:42.0];
            NSString *rutaEsperada = item.path;
            __weak IOFileCell *debil = self;
            [[IOFileIcons shared] requestThumbnailForPath:item.path size:42.0
                completion:^(UIImage *imagen) {
                    if (imagen && [debil.rutaActual isEqualToString:rutaEsperada]) {
                        debil.iconoVista.image = imagen;
                    }
                }];
        }
    } else {
        self.iconoVista.image = [[IOFileIcons shared] fileIconForItem:item size:42.0];
    }
}

@end
