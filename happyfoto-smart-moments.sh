#!/bin/sh
# Start the repacked HappyFoto smart moments Electron app inside the Flatpak sandbox.
export TMPDIR="${XDG_RUNTIME_DIR}/app/${FLATPAK_ID}"
exec zypak-wrapper /app/main/happyfoto-smart-moments --ozone-platform-hint=auto "$@"
