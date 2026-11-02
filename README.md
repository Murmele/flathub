# HappyFoto smart moments – Linux Flatpak (repack of the official app)

HappyFoto only ships its "smart moments" designer for Windows and macOS. The app is an
Electron application, so its code also runs on Linux. These scripts repack the official
macOS build into a Flatpak.

## Quick start

1. In this repository run

   ```sh
   ./build-flatpak.sh
   ```

2. Start "HappyFoto smart moments (Linux repack)" from the application menu, or run
   `flatpak run at.happyfoto.SmartMoments`.

The manifest downloads the official DMG and verifies its SHA-256 before extracting it.
Matching downloads are reused from Flatpak Builder's cache. To build a new upstream
release, update the DMG's `sha256` in `at.happyfoto.SmartMoments.yml`; the changed
checksum makes Flatpak Builder download a fresh copy from the same URL. Cached builds
do not automatically check the server for newer releases.

Options: `--bundle` also writes `HappyFoto-smart-moments.flatpak` (installable with
`flatpak install --user HappyFoto-smart-moments.flatpak`), `--run` starts the app after the
build, and `--skip-setup` skips tooling installation. See `--help`.

Host requirement: `flatpak`. Everything else (Freedesktop SDK
25.08, Node.js SDK extension, Electron base app, flatpak-builder) is installed per user by
the script. The manifest downloads 7-Zip for extraction and uses Python from the SDK.
All downloads, including npm packages and Electron headers, are declared as manifest
sources and fetched before the build. The build itself runs without network access;
`build-flatpak.sh` passes `--sandbox` to enforce this locally.

## What the scripts do

| Script | Purpose |
|---|---|
| `build-flatpak.sh` | Sets up tooling, then builds/installs with flatpak-builder |
| `check-deps.sh` | Checks the host tools |
| `setup-flatpak.sh` | Adds Flathub (user) and installs SDK, runtimes and builder |
| `update-generated-sources.sh` | Refreshes the npm lockfile and generates the source list for offline builds |
| `icns_to_png.py` | Icon extraction helper run inside the Flatpak build |
| `at.happyfoto.SmartMoments.yml` | Downloads and verifies the DMG, extracts and prepares the app, then builds the Flatpak |
| `build-dependencies/package.json`, `build-dependencies/package-lock.json` | Pin the ASAR tool, node-gyp and Linux native-module dependencies |
| `generated-sources.json` | Generated source list that supplies the npm cache for offline installation |
| `API.md` | Notes on the HappyFoto backend API |

Inside the Flatpak build:

* 7-Zip extracts the app resources from the downloaded DMG. The built-in auto-updater is
  disabled and the application icon is extracted inside the sandbox.
* Electron 36.1.0 (the version the official app uses) is downloaded; the binary is renamed
  so the app behaves like an installed (packaged) app.
* The official [`@electron/asar`](https://github.com/electron/asar) CLI (pinned to 4.3.1)
  extracts `app.asar` using the SDK's Node.js. The external files in `app.asar.unpacked`
  are included, and macOS-only native payloads are removed before Linux replacements are added.
* `npm ci --offline --ignore-scripts` installs the locked dependencies from the supplied
  npm cache. `sharp` uses its Linux prebuilt binaries; `better-sqlite3` is compiled for
  the Electron ABI using the declared Electron headers and the local `node-gyp` tool.
* `@hf-designer/ai-desktop` (proprietary, macOS/Windows only) is replaced by a stub. It is
  only used for a macOS-specific JPEG loader; the AI image analysis runs in the web part
  and keeps working.
* `@myunisoft/heif-converter` keeps the app's existing wrapper and uses the Linux x64
  binary from `@myunisoft/heif-converter.linux-x64@0.1.6`, enabling HEIC/HEIF photo import.

## Updating build dependencies

Install Node.js 22 with npm, and install
[`flatpak-node-generator`](https://github.com/flatpak/flatpak-builder-tools/tree/74697c75b630d7330e77250fc13cb5ea688d9479/node)
using Python 3.10 or newer, Git and [pipx](https://pipx.pypa.io/):

```sh
pipx install 'git+https://github.com/flatpak/flatpak-builder-tools.git@74697c75b630d7330e77250fc13cb5ea688d9479#subdirectory=node'
```

Ensure `npm` and `flatpak-node-generator` are on `PATH`. After editing the pinned versions
in `build-dependencies/package.json`, run:

```sh
./update-generated-sources.sh
```

The script follows the [Flatpak Electron guide](https://docs.flatpak.org/en/latest/electron.html#bundling-npm-packages):
it runs `npm install --package-lock-only --ignore-scripts` and then `flatpak-node-generator npm`.
It stages the inputs in a temporary directory, leaving any local `node_modules` alone, and
replaces the lockfile and source list only after both commands succeed. Review and commit
`build-dependencies/package.json`, `build-dependencies/package-lock.json` and
`generated-sources.json` together when updating dependencies.

This maintenance command needs network access; normal builds use the committed lockfile
and source list. When changing the Node.js SDK or runtime branch, also update
`--node-sdk-extension` in the script. When upgrading Electron, update its runtime archive,
header archive and native rebuild target together in the manifest.

## Known limitations

* No automatic updates: update the DMG checksum and run `build-flatpak.sh` again.
  New app releases may also require updating the pinned Electron and native-module versions.
* Initial source downloads and Flatpak tooling installation need network access.
* `--disable-rofiles-fuse` is always used because rofiles-fuse is not available in every
  environment (e.g. when flatpak-builder itself runs as a Flatpak).
