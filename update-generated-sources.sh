#!/usr/bin/env bash
# Refresh the dependency lockfile and generated-sources.json for offline Flatpak builds.
#
# Usage: ./update-generated-sources.sh
#
# Requires npm (Node.js 22), flatpak-node-generator and network access.
# Edit build-dependencies/package.json first to change pinned package versions.
# See README.md for tool installation instructions.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$here/update-generated-sources.sh"; }

if (($#)); then
    case "$1" in
        -h | --help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
fi

for tool in npm flatpak-node-generator; do
    if ! command -v "$tool" >/dev/null; then
        echo "Missing required tool: $tool. See 'Updating build dependencies' in README.md." >&2
        exit 1
    fi
done

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/happyfoto-sources.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# The generator requires a clean directory without node_modules. Stage the inputs
# so local npm installs are left alone and a failed update keeps the existing files.
cp "$here/build-dependencies/package.json" "$temp_dir/package.json"
if [[ -f "$here/build-dependencies/package-lock.json" ]]; then
    cp "$here/build-dependencies/package-lock.json" "$temp_dir/package-lock.json"
fi

(
    cd "$temp_dir"
    echo "Refreshing the npm lockfile..."
    npm install --package-lock-only --ignore-scripts --no-audit --no-fund \
        --cache "$temp_dir/npm-cache"

    echo "Generating Flatpak npm sources..."
    # Keep the SDK extension and branch aligned with the Flatpak manifest.
    flatpak-node-generator --no-requests-cache \
        --node-sdk-extension org.freedesktop.Sdk.Extension.node22//25.08 \
        -o generated-sources.json npm package-lock.json
)

if cmp -s "$temp_dir/package-lock.json" "$here/build-dependencies/package-lock.json" &&
    cmp -s "$temp_dir/generated-sources.json" "$here/generated-sources.json"; then
    echo "The lockfile and generated-sources.json are already up to date."
else
    cp "$temp_dir/package-lock.json" "$here/build-dependencies/package-lock.json"
    cp "$temp_dir/generated-sources.json" "$here/generated-sources.json"
    echo "Updated build-dependencies/package-lock.json and generated-sources.json."
fi
