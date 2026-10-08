#!/usr/bin/env bash
# Checks that the host tools needed to prepare and build the Flatpak are installed.
set -euo pipefail

missing=()
for tool in 7z python3 flatpak; do
    command -v "$tool" >/dev/null || missing+=("$tool")
done
if ((${#missing[@]})); then
    echo "Missing tools: ${missing[*]}" >&2
    echo "Install them, e.g. on Debian/Ubuntu: sudo apt install p7zip-full python3 flatpak" >&2
    echo "                    on Fedora:       sudo dnf install p7zip p7zip-plugins python3 flatpak" >&2
    exit 1
fi
echo "Host tools OK"
