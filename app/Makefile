# ---------------------------------------------------------------------------
#  IOpenFiles -- gestor de archivos con acceso al sistema para iOS 9 (armv7).
#
#  Compila con Theos + toolchain LLVM que genera armv7 contra el SDK 9.3.
#  Interfaz 100% en codigo: sin storyboards, sin XIB, sin Swift.
#
#  Compilar:  make clean && make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa
# ---------------------------------------------------------------------------

TARGET = iphone:clang:9.3:9.0
ARCHS = armv7
PACKAGE_FORMAT = ipa

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IOpenFiles

# Todos los .m del proyecto. Si anades un archivo, anadelo aqui o no enlaza.
IOpenFiles_FILES = \
	main.m \
	AppDelegate.m \
	IOTheme.m \
	IOSettings.m \
	IOHelpers.m \
	IOFileItem.m \
	IOFileSystem.m \
	IOArchive.m \
	IOStore.m \
	IOFileIcons.m \
	IOProgressHUD.m \
	IOFileCell.m \
	IODialog.m \
	IOTrash.m \
	IOTrashViewController.m \
	IOIPAInstaller.m \
	IOInstallViewController.m \
	IOAnalyzerViewController.m \
	IOHomeViewController.m \
	IOSidebarViewController.m \
	IOFilesViewController.m \
	IOPropertiesViewController.m \
	IOTextEditorViewController.m \
	IOImageViewController.m \
	IOMediaPlayerViewController.m \
	IOPlaylistViewController.m \
	IOSettingsViewController.m \
	IORootContainerViewController.m

# Frameworks disponibles en iOS 9. ImageIO sirve para las miniaturas.
IOpenFiles_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore \
	AVFoundation CoreMedia CoreVideo ImageIO MobileCoreServices \
	MediaPlayer

# -Werror convierte cualquier aviso en error: silenciamos solo lo justo.
IOpenFiles_CFLAGS = -fobjc-arc \
	-Wno-deprecated-declarations \
	-Wno-unused-parameter \
	-Wno-unused-variable \
	-Wno-unused-function \
	-Wno-objc-method-access

IOpenFiles_RESOURCE_DIRS = Resources

# libz: se usa para leer y escribir ZIP (deflate).
IOpenFiles_LDFLAGS = -Wl,-dead_strip -lz

# Permisos de jailbreak: llavero + acceso amplio al sistema de ficheros.
IOpenFiles_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
