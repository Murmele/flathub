#!/usr/bin/env python3
"""Extract the largest PNG image of at most 512x512 pixels from a macOS .icns file.

Usage: icns_to_png.py <icon.icns> <out.png>
"""
import struct
import sys

MAX_SIZE = 512  # largest icon size exported by Flatpak


def png_size(chunk: bytes) -> int:
    # PNG signature (8 bytes) + IHDR length/type (8 bytes) + width (4 bytes)
    return struct.unpack(">I", chunk[16:20])[0]


def main(src: str, dst: str) -> None:
    data = open(src, "rb").read()
    if data[:4] != b"icns":
        sys.exit("not an icns file")
    best, best_size = b"", 0
    pos = 8
    while pos + 8 <= len(data):
        _kind, size = struct.unpack(">4sI", data[pos:pos + 8])
        if size < 8:
            break
        chunk = data[pos + 8:pos + size]
        if chunk.startswith(b"\x89PNG"):
            px = png_size(chunk)
            if best_size < px <= MAX_SIZE:
                best, best_size = chunk, px
        pos += size
    if not best:
        sys.exit("no suitable PNG image found in icns")
    open(dst, "wb").write(best)
    print(best_size)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
