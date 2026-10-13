#!/usr/bin/env bash
# Checks that Flatpak is installed; extraction tools run inside the build sandbox.
set -euo pipefail

if ! command -v flatpak >/dev/null; then
    echo "Missing tool: flatpak" >&2
    echo "Install it, e.g. on Debian/Ubuntu: sudo apt install flatpak" >&2
    echo "                  on Fedora:       sudo dnf install flatpak" >&2
    exit 1
fi
echo "Host tools OK"
