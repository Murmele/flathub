# HappyFoto smart moments – Linux Flatpak (repack of the official app)

HappyFoto only ships its "smart moments" designer for Windows and macOS. The app is an
Electron application, so its code also runs on Linux. These scripts repack the official
macOS build into a Flatpak.

> **Personal use only.** The app is proprietary HappyFoto software. The scripts work on
> *your own* downloaded installer; the extracted files (`work/`), the build directories and
> the generated bundle must not be committed or redistributed.

## Quick start

1. Download the macOS installer `HappyFoto smart moments.dmg` from HappyFoto.
2. In this repository run

   ```sh
   ./build-flatpak.sh ~/Downloads/"HappyFoto smart moments.dmg"
   ```

3. Start "HappyFoto smart moments (Linux repack)" from the application menu, or run
   `flatpak run at.happyfoto.SmartMomentsLinux`.

The DMG path is the mandatory first argument. Options: `--bundle` also writes `HappyFoto-smart-moments.flatpak` (installable with
`flatpak install --user HappyFoto-smart-moments.flatpak`), `--run` starts the app after the
build, `--skip-setup` / `--skip-prepare` skip the steps that already ran. See `--help`.

Host requirements: `flatpak`, `7z` (p7zip), `python3`. Everything else (Freedesktop SDK
25.08, Node.js SDK extension, Electron base app, flatpak-builder) is installed per user by
the script.

## What the scripts do

| Script | Purpose |
|---|---|
| `build-flatpak.sh` | Runs all steps below, then builds/installs with flatpak-builder |
| `check-deps.sh` | Checks the host tools |
| `setup-flatpak.sh` | Adds Flathub (user) and installs SDK, runtimes and builder |
| `prepare.sh` | Extracts `app.asar` and the unpacked native modules from the DMG into `work/`, disables the auto-updater, extracts the icon |
| `asar_extract.py`, `icns_to_png.py` | Helpers for `prepare.sh` |
| `at.happyfoto.SmartMomentsLinux.yml` | Flatpak manifest |
| `API.md` | Notes on the HappyFoto backend API |

Inside the Flatpak build:

* Electron 36.1.0 (the version the official app uses) is downloaded; the binary is renamed
  so the app behaves like an installed (packaged) app.
* `sharp` uses its Linux prebuilt binaries; `better-sqlite3` is compiled for the Electron ABI.
* `@hf-designer/ai-desktop` (proprietary, macOS/Windows only) is replaced by a stub. It is
  only used for a macOS-specific JPEG loader; the AI image analysis runs in the web part
  and keeps working.
* `@myunisoft/heif-converter` keeps the app's existing wrapper and uses the Linux x64
  binary from `@myunisoft/heif-converter.linux-x64@0.1.6`, enabling HEIC/HEIF photo import.

## Known limitations

* No automatic updates: download the new DMG and run `build-flatpak.sh` again.
* Building needs network access (Electron download, npm, node-gyp headers).
* `--disable-rofiles-fuse` is always used because rofiles-fuse is not available in every
  environment (e.g. when flatpak-builder itself runs as a Flatpak).
