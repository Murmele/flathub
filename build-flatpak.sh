#!/usr/bin/env bash
# One-stop script: extract the HappyFoto smart moments DMG, install the Flatpak tooling and
# build + install the Linux Flatpak of the official Electron app (personal use only).
#
# Usage: ./build-flatpak.sh <path/to/HappyFoto smart moments.dmg> [options]
#
# Options:
#   --bundle       additionally export a single-file bundle (HappyFoto-smart-moments.flatpak)
#   --no-install   only build, do not install the app for the current user
#   --skip-setup   do not install/update the Flatpak SDK and runtimes
#   --skip-prepare reuse the previously extracted app in ./work
#   --run          start the app after a successful installation
#   -h, --help     show this help
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here"
app_id=at.happyfoto.SmartMomentsLinux
manifest="$here/$app_id.yml"
build_dir="$root/build-electron"
state_dir="$root/.flatpak-builder"
repo_dir="$root/repo"

# Prints the comment block at the top of this file.
usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; }

case "${1:-}" in
    -h | --help) usage; exit 0 ;;
    "" | -*) echo "Error: the first argument must be the path to the DMG file" >&2; echo >&2; usage >&2; exit 2 ;;
esac
dmg="$1"
shift
[ -f "$dmg" ] || { echo "DMG not found: $dmg" >&2; exit 1; }

bundle=0 install=1 setup=1 prepare=1 run=0
while (($#)); do
    case "$1" in
        --bundle) bundle=1 ;;
        --no-install) install=0 ;;
        --skip-setup) setup=0 ;;
        --skip-prepare) prepare=0 ;;
        --run) run=1 ;;
        -h | --help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

step() { printf '\n==> %s\n' "$*"; }

step "Checking host tools"
"$here/check-deps.sh"

if ((setup)); then
    step "Installing Flatpak SDK and runtimes"
    "$here/setup-flatpak.sh"
fi

if ((prepare)); then
    step "Extracting the app from $dmg"
    "$here/prepare.sh" "$dmg"
elif [ ! -d "$here/work/app" ]; then
    echo "No prepared app in $here/work - run without --skip-prepare" >&2
    exit 1
fi

if command -v flatpak-builder >/dev/null; then
    builder=(flatpak-builder)
else
    builder=(flatpak run org.flatpak.Builder)
fi
# rofiles-fuse is not available everywhere (e.g. inside the Flathub builder sandbox).
args=(--user --force-clean --disable-rofiles-fuse --state-dir="$state_dir")
if ((install)); then args+=(--install); fi
if ((bundle)); then args+=(--repo="$repo_dir"); fi

# OSTree refuses to write when less than 3 % of the disk is free, which is easily the case on
# large, well-filled disks. Use an absolute limit for the local bundle repository instead.
prepare_repo() {
    if [ ! -f "$repo_dir/config" ]; then
        mkdir -p "$repo_dir"/{objects,tmp,state,extensions,refs/heads,refs/mirrors,refs/remotes}
        printf '[core]\nrepo_version=1\nmode=archive-z2\n' > "$repo_dir/config"
    fi
    grep -q '^min-free-space-size=' "$repo_dir/config" ||
        sed -i 's/^\[core\]$/[core]\nmin-free-space-size=1GB/' "$repo_dir/config"
}
if ((bundle)); then prepare_repo; fi

step "Building the Flatpak (this downloads Electron and compiles native modules)"
(cd "$here" && "${builder[@]}" "${args[@]}" "$build_dir" "$manifest")

if ((bundle)); then
    step "Exporting single-file bundle"
    flatpak build-bundle --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
        "$repo_dir" "$root/HappyFoto-smart-moments.flatpak" "$app_id"
    echo "Bundle: $root/HappyFoto-smart-moments.flatpak"
fi

if ((install)); then
    step "Installed. Start it from the application menu or with: flatpak run $app_id"
    if ((run)); then
        exec flatpak run "$app_id"
    fi
fi
