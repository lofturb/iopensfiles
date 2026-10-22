# -*- coding: utf-8 -*-
"""
Genera los iconos e imagenes de arranque de IOpenFiles, sin dependencias externas.

Escribe PNGs a mano con zlib + struct (biblioteca estandar), asi que funciona
en Windows 7 con Python 3.8 sin Pillow ni nada parecido.

Produce:
  app/Resources/              -> iconos del sistema e imagenes de arranque
  app/recursos-generados.txt  -> resumen de lo creado

Uso (desde la raiz del proyecto):
    python tools/generar_recursos.py

Uso desde cualquier sitio:
    python tools/generar_recursos.py --raiz C:\\ruta\\al\\proyecto

Personalizacion rapida:
  * cambia FONDO y ACENTO por los colores de tu app;
  * dentro_del_simbolo() dibuja la carpeta: cambiala por otra forma si quieres;
  * si tu app no necesita todos los tamanos, deja solo los que uses.
"""

import io
import os
import struct
import sys
import zlib


def raiz_proyecto():
    """Acepta --raiz; si no, usa el directorio actual (si tiene app/) o el
    abuelo de este script (cuando vive en tools/)."""
    if "--raiz" in sys.argv:
        i = sys.argv.index("--raiz")
        if i + 1 < len(sys.argv):
            return os.path.abspath(sys.argv[i + 1])
    actual = os.getcwd()
    if os.path.isdir(os.path.join(actual, "app")):
        return actual
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


RAIZ = raiz_proyecto()
DESTINO = os.path.join(RAIZ, "app", "Resources")

# Paleta de IOpenFiles: azul de acento sobre fondo blanco roto.
FONDO = (0x0A, 0x84, 0xFF, 255)      # azul de acento
FONDO_OSCURO = (0x0B, 0x12, 0x20, 255)  # azul noche para las imagenes de arranque
ACENTO = (0x0A, 0x84, 0xFF, 255)     # azul
BLANCO = (0xFF, 0xFF, 0xFF, 255)
ACENTO_CLARO = (0x5A, 0xAC, 0xFF, 255)


def escribir_png(ruta, ancho, alto, pixeles):
    """pixeles: bytearray RGBA de ancho*alto*4."""
    filas = []
    for y in range(alto):
        inicio = y * ancho * 4
        filas.append(b"\x00" + bytes(pixeles[inicio:inicio + ancho * 4]))
    crudo = b"".join(filas)

    def bloque(tipo, datos):
        return (struct.pack(">I", len(datos)) + tipo + datos
                + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF))

    cabecera = struct.pack(">IIBBBBB", ancho, alto, 8, 6, 0, 0, 0)
    contenido = (b"\x89PNG\r\n\x1a\n"
                 + bloque(b"IHDR", cabecera)
                 + bloque(b"IDAT", zlib.compress(crudo, 9))
                 + bloque(b"IEND", b""))
    with io.open(ruta, "wb") as f:
        f.write(contenido)


def en_rectangulo_redondeado(x, y, x0, y0, x1, y1, radio):
    """Punto dentro de un rectangulo con esquinas redondeadas."""
    if x < x0 or x > x1 or y < y0 or y > y1:
        return False
    cx = min(max(x, x0 + radio), x1 - radio)
    cy = min(max(y, y0 + radio), y1 - radio)
    dx, dy = x - cx, y - cy
    return dx * dx + dy * dy <= radio * radio


def dentro_del_simbolo(x, y, ancho, alto):
    """Carpeta: cuerpo redondeado + pestana arriba a la izquierda."""
    # Cuerpo de la carpeta.
    bx0, by0, bx1, by1 = 0.16 * ancho, 0.36 * alto, 0.84 * ancho, 0.74 * alto
    if en_rectangulo_redondeado(x, y, bx0, by0, bx1, by1, 0.07 * ancho):
        return True
    # Pestana posterior.
    tx0, ty0, tx1, ty1 = 0.16 * ancho, 0.25 * alto, 0.46 * ancho, 0.40 * alto
    if en_rectangulo_redondeado(x, y, tx0, ty0, tx1, ty1, 0.06 * ancho):
        return True
    return False


def icono(ancho, alto, con_fondo=True):
    """Icono: fondo de acento, esquinas redondeadas y carpeta blanca.
    Se dibuja con supermuestreo 3x para que los bordes queden suaves."""
    sup = 3
    radio = 0.2237 * ancho
    pixeles = bytearray(ancho * alto * 4)

    for y in range(alto):
        for x in range(ancho):
            acumulado = [0.0, 0.0, 0.0, 0.0]
            for sy in range(sup):
                for sx in range(sup):
                    px = x + (sx + 0.5) / sup
                    py = y + (sy + 0.5) / sup
                    if con_fondo and not en_rectangulo_redondeado(
                            px, py, 0, 0, ancho, alto, radio):
                        color = (0, 0, 0, 0)
                    elif dentro_del_simbolo(px, py, ancho, alto):
                        color = BLANCO
                    else:
                        color = ACENTO
                    for i in range(4):
                        acumulado[i] += color[i]
            n = sup * sup
            base = (y * ancho + x) * 4
            for i in range(4):
                pixeles[base + i] = int(round(acumulado[i] / n))
    return pixeles


def arranque(ancho, alto):
    """Imagen de arranque: fondo azul noche con la carpeta centrada."""
    pixeles = bytearray(ancho * alto * 4)
    lado = int(min(ancho, alto) * 0.30)
    ox = (ancho - lado) // 2
    oy = (alto - lado) // 2
    for y in range(alto):
        for x in range(ancho):
            base = (y * ancho + x) * 4
            if ox <= x < ox + lado and oy <= y < oy + lado:
                lx, ly = x - ox, y - oy
                if dentro_del_simbolo(lx, ly, lado, lado):
                    color = BLANCO
                else:
                    color = FONDO_OSCURO
            else:
                color = FONDO_OSCURO
            pixeles[base:base + 4] = bytes(color)
    return pixeles


ICONOS = [
    ("Icon-Small.png", 29),
    ("Icon-Small@2x.png", 58),
    ("Icon-Small-40.png", 40),
    ("Icon-Small-40@2x.png", 80),
    ("Icon-Small-40@3x.png", 120),
    ("Icon-60.png", 60),
    ("Icon-60@2x.png", 120),
    ("Icon-60@3x.png", 180),
    ("Icon-72.png", 72),
    ("Icon-72@2x.png", 144),
    ("Icon-76.png", 76),
    ("Icon-76@2x.png", 152),
    ("iTunesArtwork", 512),
]

ARRANQUES = [
    ("LaunchImage.png", 320, 480),
    ("LaunchImage@2x.png", 640, 960),
    ("LaunchImage-568h@2x.png", 640, 1136),
    ("LaunchImage-700.png", 320, 480),
    ("LaunchImage-700@2x.png", 640, 960),
    ("LaunchImage-700-568h@2x.png", 640, 1136),
    ("LaunchImage-700-Portrait.png", 768, 1024),
    ("LaunchImage-700-Portrait@2x.png", 1536, 2048),
    ("LaunchImage-700-Landscape.png", 1024, 768),
    ("LaunchImage-700-Landscape@2x.png", 2048, 1536),
]


def main():
    if not os.path.isdir(DESTINO):
        os.makedirs(DESTINO)
    hechos = []

    print("  Raiz:    %s" % RAIZ)
    print("  Destino: %s" % DESTINO)
    print("")

    for nombre, lado in ICONOS:
        escribir_png(os.path.join(DESTINO, nombre), lado, lado,
                     icono(lado, lado, con_fondo=(nombre != "iTunesArtwork")))
        hechos.append("%s  %dx%d" % (nombre, lado, lado))

    for nombre, ancho, alto in ARRANQUES:
        escribir_png(os.path.join(DESTINO, nombre), ancho, alto, arranque(ancho, alto))
        hechos.append("%s  %dx%d" % (nombre, ancho, alto))

    resumen = os.path.join(RAIZ, "app", "recursos-generados.txt")
    with io.open(resumen, "w", encoding="utf-8") as f:
        f.write("Recursos generados por tools/generar_recursos.py\n\n")
        f.write("\n".join(hechos) + "\n")

    print("Generados %d archivos en app/Resources" % len(hechos))
    for h in hechos:
        print("   ", h)


if __name__ == "__main__":
    main()
