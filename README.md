# IOpenFiles

Gestor de archivos con **acceso al sistema completo** para iPad/iPhone de
**32 bits con iOS 9**. Nace del kit `Guia-IPA-iOS9` (Theos + GitHub Actions, sin
Mac) y toma como referencia el conjunto de funciones de **Filza**, con una
interfaz propia más limpia: pantalla de inicio con tarjetas de almacenamiento,
barra lateral, diálogos propios, iconos de línea dibujados a mano y modo
claro/oscuro completo.

- **Dispositivo objetivo:** iPad mini 1 (iPad2,6), iOS 9.3.6, armv7f, 512 MB,
  1024×768 (no retina).
- **Bundle:** `com.lofturb.iopensfiles` — versión `1.1.0`.
- **Sin Mac, sin Xcode, sin Swift, sin storyboards.** Todo Objective-C, en
  código, compilado con Theos e firmado con `ldid`.

---

## Qué hace

**Inicio y navegación**
- **Pantalla de inicio** con una tarjeta por volumen montado (Sistema, Datos,
  Medios): uso, espacio libre, porcentaje y acceso directo a esa raíz.
- Accesos rápidos a limpieza, instalador de IPA, papelera, favoritos,
  recientes y cachés; información del sistema y ajustes.
- Recorre todo el sistema de ficheros: `/`, `/var`, `/Applications`, `/System`,
  contenedores de apps...
- Barra lateral con Lugares, Favoritos y Recientes; se ve dividida en
  horizontal y se superpone en vertical.
- Ruta visible bajo el título, apertura de carpetas apilando navegadores.
- Búsqueda **recursiva** desde la carpeta actual (hasta 500 resultados).
- «Ir a una ruta...» y «Ir a la raíz» desde el menú y desde Inicio.

**Operaciones**
- Crear carpeta y archivo, renombrar, duplicar, copiar, cortar y pegar.
- **Papelera interna** (opcional): los borrados del navegador se pueden
  restaurar; desde la papelera también se puede borrar para siempre o vaciarla.
- **Selección múltiple**: todo, nada, invertir o seleccionar por tipo
  (imágenes, vídeos, audio, documentos, carpetas), además de pulsar filas.
- Progreso y cancelación en las operaciones largas.
- Si al pegar hay colisión de nombres: reemplazar, conservar ambos o cancelar.

**Limpieza y espacio**
- **Examinar y limpiar**: analiza una carpeta (o todo el sistema) y agrupa los
  archivos por tipo con el peso total y por categoría.
- Lista de los archivos más grandes, con selección múltiple y borrado
  **permanente** solo de lo que el usuario marque.
- Omite por defecto zonas críticas (`/System`, `/usr`, `/bin`, `/Applications`,
  `/Library`, contenedores de apps, `PhotoData`, etc.). **Nada se borra solo.**
- Acceso directo a cachés y temporales para liberar espacio.

**Instalador de IPA**
- Detecta los `.ipa` de Medios, Documentos y Descargas, o permite elegirlos con
  un explorador en modo selector.
- Extrae el paquete en una carpeta temporal, lee el bundle ID e instala con
  `MobileInstallation`, con alternativa vía LaunchServices y al `.ipa` directo.
- Al terminar ofrece abrir la app instalada.

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
- **Audio y vídeo**: `AVPlayer` con lista de la carpeta, aleatorio, repetir
  (todo/una), anterior/siguiente, control de velocidad, carátula ID3 y audio en
  segundo plano.
- **ZIP**: comprimir y extraer, con listado del contenido.

**Integración**
- Compartir / «Abrir con»: primero una hoja propia y, al elegir «Compartir con
  apps…», el selector del sistema (la única pieza que no se puede rediseñar).
- Favoritos y recientes persistentes.
- Tema claro/oscuro completo y ajustes de orden (nombre, tipo, fecha, tamaño),
  ocultos, carpetas primero, detalles, miniaturas y extensiones.

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
git commit -m "IOpenFiles 1.1.0"
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

También se puede instalar directamente por USB con `libimobiledevice`:

```powershell
ideviceinstaller -u UDID-DEL-IPAD -i IOpenFiles.ipa
```

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
un demonio auxiliar. Esta versión hace las operaciones directamente; si el
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
│   ├── IODialog.h/.m            alertas y hojas propias (sustituyen a UIAlertController)
│   ├── IOTrash.h/.m             papelera interna y su indice
│   ├── IOTrashViewController    lista de la papelera (restaurar/vaciar)
│   ├── IOIPAInstaller.h/.m      instalacion de .ipa (MobileInstallation)
│   ├── IOInstallViewController  pantalla del instalador
│   ├── IOAnalyzerViewController analizador por tipo con borrado selectivo
│   ├── IOHomeViewController     inicio: volumenes, accesos rapidos y recientes
│   ├── IOFileCell.h/.m          fila de la lista
│   ├── IOSidebarViewController  panel lateral
│   ├── IOFilesViewController    navegador y todas las acciones
│   ├── IOPropertiesViewController  propiedades, chmod/chown
│   ├── IOTextEditorViewController  visor/editor de texto
│   ├── IOImageViewController    visor de imagenes
│   ├── IOMediaPlayerViewController reproductor con lista, aleatorio y velocidad
│   ├── IOSettingsViewController    ajustes, papelera y mantenimiento
│   ├── IORootContainerViewController  lateral + navegador (Inicio como raiz)
│   └── Resources/               Info.plist, iconos y arranque (generados)
├── tools/                       scripts (recursos, verificacion, AFC, simbolizar)
├── entrega-web/                 pagina HTTP + servir.py
└── .github/workflows/           build + Release del .ipa
```

---

## Como se construye la interfaz

- **Todo por codigo**: `UIViewController`, `UITableView`, `UIToolbar`,
  Auto Layout a mano. Nada de storyboards ni XIB.
- **Diálogos propios**: `IODialog` dibuja alertas centradas y hojas inferiores
  con el mismo tema; en toda la app no se usa `UIAlertController`.
- **Sistema de diseno** en `IOTheme`: una sola bandera (`dark`) cambia toda la
  paleta; los colores salen de ahí. En oscuro se tiñen también ventanas,
  barras, tablas, buscadores, teclados y hojas.
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
