#!/usr/bin/env python3
"""
prepare-app-icon.py — install a 1024x1024 PNG as the app icon.

The App Store rejects an icon that carries an alpha channel, even a fully
opaque one, and Xcode does not strip it for you. Exporters add one by default,
so this flattens the image onto a solid background and rewrites it without the
channel, then points the asset catalog at the result.

Pure standard library on purpose: it has to run on a stock macOS Python with
nothing installed.

    python3 scripts/prepare-app-icon.py ~/Desktop/icon.png
"""

import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONSET = os.path.join(ROOT, "Resources", "Assets.xcassets", "AppIcon.appiconset")
OUTPUT_NAME = "AppIcon1024.png"
CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


def fail(message):
    sys.stderr.write("error: %s\n" % message)
    sys.exit(1)


def read_chunks(data):
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        fail("that file is not a PNG")
    offset, chunks = 8, []
    while offset < len(data):
        (length,) = struct.unpack(">I", data[offset:offset + 4])
        kind = data[offset + 4:offset + 8]
        chunks.append((kind, data[offset + 8:offset + 8 + length]))
        offset += length + 12
    return chunks


def unfilter(raw, width, height, bpp):
    """Undo the per-scanline PNG filters. Returns one flat bytearray."""
    stride = width * bpp
    out = bytearray()
    previous = bytearray(stride)
    pos = 0
    for _ in range(height):
        filter_type = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        if filter_type == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif filter_type == 2:
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif filter_type == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif filter_type == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = previous[i]
                c = previous[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        elif filter_type != 0:
            fail("unsupported PNG filter %d" % filter_type)
        out += line
        previous = line
    return out


def resize_hint(path, width, height):
    """macOS ships sips, so a wrong-sized export is one command from fixed."""
    quoted = path if " " not in path else '"%s"' % path
    if width == height:
        return "resize it with:  sips -z 1024 1024 %s --out ~/Desktop/icon1024.png" % quoted
    return ("crop it square first — %dx%d would be squashed by a straight resize"
            % (width, height))


def to_rgb(path, background):
    data = open(path, "rb").read()
    chunks = read_chunks(data)
    header = dict(chunks).get(b"IHDR")
    if header is None:
        fail("PNG has no header chunk")
    width, height, depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", header[:13])

    if (width, height) != (1024, 1024):
        fail("icon must be 1024x1024, this one is %dx%d\n       %s"
             % (width, height, resize_hint(path, width, height)))
    if interlace:
        fail("interlaced PNGs are not supported — re-export without interlacing")
    if depth != 8:
        fail("icon must be 8 bits per channel, this one is %d" % depth)
    if color_type not in CHANNELS:
        fail("unsupported PNG colour type %d" % color_type)

    palette = dict(chunks).get(b"PLTE")
    if color_type == 3 and palette is None:
        fail("palette PNG has no palette")

    raw = zlib.decompress(b"".join(body for kind, body in chunks if kind == b"IDAT"))
    bpp = CHANNELS[color_type]
    pixels = unfilter(raw, width, height, bpp)

    br, bg, bb = background
    rgb = bytearray()
    had_alpha = color_type in (4, 6)
    for i in range(0, len(pixels), bpp):
        if color_type == 6:
            r, g, b, a = pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]
        elif color_type == 2:
            r, g, b, a = pixels[i], pixels[i + 1], pixels[i + 2], 255
        elif color_type == 0:
            r = g = b = pixels[i]
            a = 255
        elif color_type == 4:
            r = g = b = pixels[i]
            a = pixels[i + 1]
        else:
            base = pixels[i] * 3
            r, g, b = palette[base], palette[base + 1], palette[base + 2]
            a = 255
        if a == 255:
            rgb += bytes((r, g, b))
        else:
            rgb += bytes((
                (r * a + br * (255 - a)) // 255,
                (g * a + bg * (255 - a)) // 255,
                (b * a + bb * (255 - a)) // 255,
            ))
    return width, height, bytes(rgb), had_alpha


def write_png(path, width, height, rgb):
    stride = width * 3
    raw = b"".join(b"\x00" + rgb[y * stride:(y + 1) * stride] for y in range(height))

    def chunk(kind, body):
        return (struct.pack(">I", len(body)) + kind + body
                + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))

    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")
        handle.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        handle.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        handle.write(chunk(b"IEND", b""))


CONTENTS = """{
  "images" : [
    {
      "filename" : "%s",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
""" % OUTPUT_NAME


def main():
    if len(sys.argv) < 2:
        fail("usage: python3 scripts/prepare-app-icon.py <1024x1024 png> [#rrggbb]")
    source = os.path.expanduser(sys.argv[1])
    if not os.path.isfile(source):
        fail("no such file: %s" % source)

    colour = sys.argv[2].lstrip("#") if len(sys.argv) > 2 else "0C0A18"  # DS neutral 900
    if len(colour) != 6:
        fail("background must be a six-digit hex colour, e.g. 0C0A18")
    background = tuple(int(colour[i:i + 2], 16) for i in (0, 2, 4))

    width, height, rgb, had_alpha = to_rgb(source, background)
    destination = os.path.join(ICONSET, OUTPUT_NAME)
    write_png(destination, width, height, rgb)

    with open(os.path.join(ICONSET, "Contents.json"), "w") as handle:
        handle.write(CONTENTS)

    stale = os.path.join(ICONSET, "Background_1024.png")
    if os.path.exists(stale) and os.path.basename(destination) != "Background_1024.png":
        os.remove(stale)
        print("removed the old placeholder icon")

    print("wrote %s (%dx%d, no alpha channel%s)"
          % (destination, width, height,
             ", flattened onto #%s" % colour if had_alpha else ""))
    print("now run: xcodegen generate")


if __name__ == "__main__":
    main()
