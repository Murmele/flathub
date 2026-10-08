#!/usr/bin/env bash
# Prepare the HappyFoto "smart moments" Electron app from the official macOS DMG for the
# Linux Flatpak build. The result in ./work/ is proprietary HappyFoto software: it is for
# personal use only and must never be committed or redistributed.
#
# Usage: ./prepare.sh "/path/to/HappyFoto smart moments.dmg"
set -euo pipefail

dmg="${1:?usage: $0 <path to HappyFoto smart moments.dmg>}"
here="$(cd "$(dirname "$0")" && pwd)"
work="$here/work"
res_in_dmg="HappyFoto smart moments.app/Contents/Resources"

command -v 7z >/dev/null || { echo "7z (p7zip) is required" >&2; exit 1; }

rm -rf "$work"
mkdir -p "$work/raw" "$work/app/resources/app"

echo "Extracting resources from DMG ..."
(cd "$work/raw" && 7z x -y "$dmg" \
    "$res_in_dmg/app.asar" \
    "$res_in_dmg/app.asar.unpacked/*" \
    "$res_in_dmg/config.json" \
    "$res_in_dmg/tenants.json" \
    "$res_in_dmg/icon.icns" >/dev/null)
raw="$work/raw/$res_in_dmg"

echo "Unpacking app.asar ..."
python3 -I "$here/asar_extract.py" "$raw/app.asar" "$work/app/resources/app"
# Merge the files that were kept outside of the archive (native modules, exiftool, ...)
cp -a "$raw/app.asar.unpacked/." "$work/app/resources/app/"

# Drop macOS-only native payloads; the Flatpak build adds Linux builds or stubs instead.
rm -rf "$work/app/resources/app/node_modules/@img/"*darwin* \
       "$work/app/resources/app/node_modules/@hf-designer/ai-desktop/bin" \
       "$work/app/resources/app/node_modules/@myunisoft/heif-converter/node_modules"

# Disable the built-in auto updater (it only knows the macOS/Windows packages).
python3 -I - "$raw/config.json" "$work/app/resources/config.json" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
cfg.pop("appUpdateUrl", None)
json.dump(cfg, open(sys.argv[2], "w"), indent=4)
PY
cp "$raw/tenants.json" "$work/app/resources/tenants.json"

icon_size="$(python3 -I "$here/icns_to_png.py" "$raw/icon.icns" "$work/icon.png")"
[ "$icon_size" = 512 ] || echo "Warning: app icon is ${icon_size}px instead of 512px" >&2
rm -rf "$work/raw"
echo "Done: $work"
