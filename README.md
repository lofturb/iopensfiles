# IOpenFiles

Gestor de archivos con **acceso al sistema completo** para iPad/iPhone de
**32 bits con iOS 9**. Nace del kit `Guia-IPA-iOS9` (Theos + GitHub Actions, sin
Mac) y toma como referencia el conjunto de funciones de **Filza**, con una
interfaz propia más limpia: barra lateral, tarjetas, iconos de línea dibujados a
mano y modo claro/oscuro.

- **Dispositivo objetivo:** iPad mini 1 (iPad2,6), iOS 9.3.6, armv7f, 512 MB,
  1024×768 (no retina).
- **Bundle:** `com.lofturb.iopensfiles` — versión `1.0.0`.
- **Sin Mac, sin Xcode, sin Swift, sin storyboards.** Todo Objective-C, en
  código, compilado con Theos e firmado con `ldid`.

---

## Qué hace

**Navegación**
- Recorre todo el sistema de ficheros: `/`, `/var`, `/Applications`, `/System`,
  contenedores de apps...
- Barra lateral con Lugares, Favoritos y Recientes; se ve dividida en
  horizontal y se superpone en vertical.
- Ruta visible bajo el título, apertura de carpetas apilando navegadores.
- Búsqueda **recursiva** desde la carpeta actual (hasta 500 resultados).

**Operaciones**
- Crear carpeta y archivo, renombrar, duplicar, copiar, cortar y pegar.
- Borrado recursivo con confirmación opcional.
- **Selección múltiple** con barra de acciones (compartir, copiar, mover,
  comprimir, borrar).
- Progreso y cancelación en las operaciones largas.
- Si al pegar hay colisión de nombres: reemplazar, conservar ambos o cancelar.

**Permisos y propiedades**
- Modo Unix (`rwxr-xr-x`), **chmod octal** y **chown** de dueño y grupo, con
  opción de aplicar a subcarpetas.
- Tamaño (recursivo en carpetas), tamaño en disco, fechas, tipo y formato real
  (cabecera mágica), enlace simbólico, ruta y si está oculto.

**Visores**
- **Texto**: visor/editor con búsqueda y guardado (UTF-8 con reserva Latin-1),
  tamaño de fuente ajustable.
- **Imágenes**: pantalla completa, zoom (pellizco y doble toque) y paso entre
  las imágenes de la carpeta.
- **Audio y vídeo**: `AVPlayer` con barra de progreso; audio en segundo plano.
- **ZIP**: comprimir y extraer, con listado del contenido.

**Integración**
- Compartir / «Abrir con» (hoja de iOS y apps compatibles).
- Favoritos y recientes persistentes.
- Tema claro/oscuro y ajustes de orden (nombre, tipo, fecha, tamaño), ocultos,
  carpetas primero, detalles, miniaturas y extensiones.

---

## Requisitos en el dispositivo

- **Jailbreak**.
- **AppSync Unified** (`https://cydia.akemi.ai/`): sin esto iOS rechaza la
  firma `ldid`.
- **Filza** para abrir el `.ipa` (o instalar por AFC/HTTP).
- Si vas a leer HTTPS moderno desde otras apps, el perfil
  `CertificadosModernos.mobileconfig`; la app en sí no necesita red.

---

## Compilar e instalar

La vía recomendada es **GitHub Actions** (no hace falta Mac):

```powershell
git init
git add .
git commit -m "IOpenFiles 1.0.0"
git remote add origin https://github.com/TU-USUARIO/iopensfiles.git
git push -u origin main
```

El workflow `.github/workflows/build-ipa.yml` compila con Theos + toolchain
armv7 + SDK `iPhoneOS9.3` y publica el `.ipa` en **Releases**.

Pasarlo al iPad:

```powershell
# Copiar al iPad por USB (raiz de AFC = /var/mobile/Media)
python tools\afc_put.py IOpenFiles.ipa /IOpenFiles.ipa
```

En el iPad: **Filza → /var/mobile/Media → IOpenFiles.ipa → Instalar**.

Alternativa sin cable: `entrega-web/` con `servir.py` en el puerto 80 y abrir
`http://IP-DEL-PC/` en Safari (PASO 1 certificados → PASO 2 la app).

Verificación del paquete:

```powershell
python tools\verificar_ipa.py IOpenFiles.ipa
# Correcto: armv7, iOS 9 y pseudo-firmado
```

---

## Acceso a disco y root (importante)

La app lleva los entitlements de jailbreak:

- `platform-application`, `com.apple.private.security.no-sandbox`,
  `com.apple.private.security.no-container`;
- excepciones de rutas absolutas (`read-write` y `read-only`) para `/`.

Con eso **lee y navega todo el sistema** y escribe en las zonas permitidas al
usuario `mobile` (`/var/mobile`, `/private/var`, `/var/mobile/Media`, ...).

**Las escrituras en zonas propiedad de `root`** (por ejemplo `/System`, parte de
`/Applications`, algunas preferencias del sistema) dependen de los permisos Unix
y, como en Filza, requieren un **helper con root**: bien instalar la app/paquete
desde un `.deb` de Cydia con el binario propiedad de `root` y bit `setuid`, bien
un demonio auxiliar. Esta versión 1.0 hace las operaciones directamente; si el
sistema devuelve «permission denied», es ese límite, no un fallo de la app.

---

## Estructura

```
IOpenFiles/
├── app/
│   ├── Makefile                 reglas de Theos (armv7, SDK 9.3, -lz)
│   ├── control                  metadatos del paquete
│   ├── main.m                   punto de entrada
│   ├── AppDelegate.h/.m         arranque, tema, sesion de audio
│   ├── entitlements.plist       llavero + acceso amplio al sistema
│   ├── IOTheme.h/.m             colores, tipografia y medidas (claro/oscuro)
│   ├── IOSettings.h/.m          ajustes persistidos (NSUserDefaults)
│   ├── IOHelpers.h/.m           formatos y deteccion de tipo de archivo
│   ├── IOFileItem.h/.m          modelo de archivo/carpeta (lstat/stat)
│   ├── IOFileSystem.h/.m        motor: listar, copiar, mover, permisos...
│   ├── IOArchive.h/.m           ZIP con zlib (listar, extraer, comprimir)
│   ├── IOStore.h/.m             favoritos, recientes y portapapeles
│   ├── IOFileIcons.h/.m         glifos de linea + iconos + miniaturas
│   ├── IOProgressHUD.h/.m       tarjeta de progreso con cancelacion
│   ├── IOFileCell.h/.m          fila de la lista
│   ├── IOSidebarViewController  panel lateral
│   ├── IOFilesViewController    navegador y todas las acciones
│   ├── IOPropertiesViewController  propiedades, chmod/chown
│   ├── IOTextEditorViewController  visor/editor de texto
│   ├── IOImageViewController    visor de imagenes
│   ├── IOMediaPlayerViewController reproductor AVPlayer
│   ├── IOSettingsViewController    ajustes
│   ├── IORootContainerViewController  lateral + navegador
│   └── Resources/               Info.plist, iconos y arranque (generados)
├── tools/                       scripts (recursos, verificacion, AFC, simbolizar)
├── entrega-web/                 pagina HTTP + servir.py
└── .github/workflows/           build + Release del .ipa
```

---

## Como se construye la interfaz

- **Todo por codigo**: `UIViewController`, `UITableView`, `UIToolbar`,
  `UIAlertController`, Auto Layout a mano. Nada de storyboards ni XIB.
- **Sistema de diseno** en `IOTheme`: una sola bandera (`dark`) cambia toda la
  paleta; los colores salen de ahí.
- **Iconos**: `IOFileIcons` dibuja cada glifo con `UIBezierPath` en coordenadas
  0..1, con trazo redondeado (estilo línea minimalista). Los archivos se pintan
  como un cuadrado redondeado con fondo tintado suave + glifo; las imágenes
  muestran miniatura real generada con ImageIO en segundo plano.
- **Rendimiento en A5/512 MB**: listados y miniaturas en colas de fondo,
  caches (`NSCache`) que se vacían al aviso de memoria, reutilizacion de celdas.

---

## Anadir funciones

1. Crea `app/MiClase.h/.m`.
2. Anadelo a `IOpenFiles_FILES` en `app/Makefile` (si no, no se compila).
3. Si usas un framework nuevo, anadelo a `IOpenFiles_FRAMEWORKS`.
4. `python tools\comprobar_fuentes.py` y `python tools\generar_recursos.py`
   antes de subir.

Errores tipicos y su arreglo: siguen valiendo los del kit original
(`ERRORES.md`): `liblaunch.tbd`, `-Werror`, barras negras, `-34018`, etc.

---

## Aviso legal

Proyecto personal y educativo. No está afiliado a Apple, a TIGI Software (Filza)
ni a ninguna otra marca. Filza es software cerrado: aquí se reimplementa su
conjunto de funciones, no se reutiliza su código.
