"""Draws the web and Android launcher icons (bus on a solid tile, no gradients) as PNGs without extra libraries.

    python3 infra/flutter-web/make_icons.py
"""
import struct
import sys
import zlib
from pathlib import Path

APPS = {'student_app': (0x25, 0x63, 0xEB), 'driver_app': (0x1E, 0x1B, 0x4B)}
WHITE = (255, 255, 255)


def png(path: Path, size: int, pixel):
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        for x in range(size):
            raw.extend(pixel(x / size, y / size))
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    path.write_bytes(data)


def rounded(x, y, x0, y0, x1, y1, r):
    if not (x0 <= x <= x1 and y0 <= y <= y1):
        return False
    cx = min(max(x, x0 + r), x1 - r)
    cy = min(max(y, y0 + r), y1 - r)
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def icon(bg, maskable=False, tile=True):
    s = 0.78 if maskable else 1.0  # maskable icons keep the glyph inside the safe zone
    def at(x, y):
        # Glyph space: centre and scale.
        gx, gy = 0.5 + (x - 0.5) / s, 0.5 + (y - 0.5) / s
        inside_tile = maskable or rounded(x, y, 0.0, 0.0, 1.0, 1.0, 0.22)
        if not inside_tile:
            return (0, 0, 0, 0)
        colour = bg
        body = rounded(gx, gy, 0.26, 0.2, 0.74, 0.72, 0.08)
        window = rounded(gx, gy, 0.32, 0.27, 0.68, 0.47, 0.03)
        light_l = (gx - 0.35) ** 2 + (gy - 0.6) ** 2 <= 0.03 ** 2
        light_r = (gx - 0.65) ** 2 + (gy - 0.6) ** 2 <= 0.03 ** 2
        wheel_l = rounded(gx, gy, 0.3, 0.7, 0.4, 0.8, 0.03)
        wheel_r = rounded(gx, gy, 0.6, 0.7, 0.7, 0.8, 0.03)
        if (body and not window and not light_l and not light_r) or wheel_l or wheel_r:
            colour = WHITE
        return (*colour, 255)
    return at


def main(root: Path):
    for app, bg in APPS.items():
        web = root / 'apps' / app / 'web'
        png(web / 'favicon.png', 64, icon(bg))
        png(web / 'icons' / 'Icon-192.png', 192, icon(bg))
        png(web / 'icons' / 'Icon-512.png', 512, icon(bg))
        png(web / 'icons' / 'Icon-maskable-192.png', 192, icon(bg, maskable=True))
        png(web / 'icons' / 'Icon-maskable-512.png', 512, icon(bg, maskable=True))
        res = root / 'apps' / app / 'android' / 'app' / 'src' / 'main' / 'res'
        for density, size in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
            png(res / f'mipmap-{density}' / 'ic_launcher.png', size, icon(bg))


if __name__ == '__main__':
    main(Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2])
