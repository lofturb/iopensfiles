# IOpenFiles 1.0.0 — gestor de archivos para iOS 9 (32 bits)

Gestor de archivos con acceso al sistema completo para iPad/iPhone de 32 bits
con iOS 9. Inspirado en el conjunto de funciones de Filza, con una interfaz
propia mas limpia (barra lateral, tarjetas y modo claro/oscuro).

## Que necesitas

- Un dispositivo con **jailbreak** y **AppSync Unified**.
- Descargar el `.ipa` de este Release y abrirlo con **Filza** (o instalarlo por
  AFC/HTTP como cualquier app de este kit).

## Que trae esta version

- Navegacion de todo el sistema de ficheros (raiz, `/var`, `/Applications`...).
- Operaciones: copiar, cortar, pegar, mover, renombrar, duplicar, borrar y
  crear carpetas y archivos.
- Permisos y propiedades: `chmod` octal, dueño/grupo, fechas, tamaño y tipo.
- Visor/editor de texto con busqueda y guardado.
- Visor de imagenes con zoom y paso entre imagenes de la carpeta.
- Reproductor de audio y video (H.264 para el A5).
- ZIP: comprimir y extraer.
- Buscador recursivo, favoritos, recientes y seleccion multiple.
- Tema claro/oscuro y ajustes de orden (nombre, fecha, tamaño, tipo).

## Como se instala

1. Copia el `.ipa` al dispositivo (USB/AFC o pagina HTTP local).
2. Abrelo con Filza y toca **Instalar**.
3. Si el icono no aparece, haz un respring.

## Verificacion

El `.ipa` se comprueba con `tools/verificar_ipa.py`: armv7, iOS 9.0 minimo y
binario pseudo-firmado con `ldid`.

## Acceso root

La app navega y lee todo el sistema gracias a los entitlements
(`no-sandbox`, `platform-application` y excepciones de rutas). Las escrituras en
zonas propiedad de `root` (por ejemplo `/System`) dependen de los permisos Unix;
para escribir ahi hace falta un helper con root, igual que en Filza. Ver el
`README.md` del repositorio.

## Aviso legal

Proyecto personal y educativo, sin relacion con Apple, TIGI Software (Filza) ni
ninguna otra marca. No lo distribuyas como oficial.
