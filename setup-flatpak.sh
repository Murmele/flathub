#!/usr/bin/env bash
# Installs (per user) everything flatpak needs to build the HappyFoto repack.
set -euo pipefail

flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

refs=(
    org.freedesktop.Platform//25.08
    org.freedesktop.Sdk//25.08
    org.freedesktop.Sdk.Extension.node22//25.08
    org.electronjs.Electron2.BaseApp//25.08
)
# Prefer a natively installed flatpak-builder; otherwise use the Flathub one.
command -v flatpak-builder >/dev/null || refs+=(org.flatpak.Builder)

flatpak install --user --noninteractive --or-update flathub "${refs[@]}"
echo "Flatpak SDK and runtimes OK"
