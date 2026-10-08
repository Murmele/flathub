#!/usr/bin/env python3
"""Unpack an Electron app.asar archive (files marked as unpacked are skipped).

Usage: asar_extract.py <app.asar> <destination-dir>
"""
import json
import os
import struct
import sys


def extract(src: str, dst: str) -> None:
    with open(src, "rb") as f:
        _, header_size, _, json_len = struct.unpack("<IIII", f.read(16))
        header = json.loads(f.read(json_len).decode())
        base = 8 + header_size

        def walk(node: dict, rel: str) -> None:
            for name, entry in node.get("files", {}).items():
                path = os.path.normpath(os.path.join(rel, name))
                if path.startswith("..") or os.path.isabs(path):
                    raise ValueError(f"unsafe path in archive: {path}")
                out = os.path.join(dst, path)
                if "files" in entry:
                    os.makedirs(out, exist_ok=True)
                    walk(entry, path)
                elif entry.get("unpacked") or "link" in entry:
                    continue
                else:
                    f.seek(base + int(entry["offset"]))
                    os.makedirs(os.path.dirname(out), exist_ok=True)
                    with open(out, "wb") as o:
                        o.write(f.read(entry["size"]))
                    if entry.get("executable"):
                        os.chmod(out, 0o755)

        walk(header, "")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    extract(sys.argv[1], sys.argv[2])
