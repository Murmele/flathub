flatpak remote-delete OpenVSPRepo
flatpak remote-add OpenVSPRepo OpenVSPRepo --no-gpg-verify --if-not-exists
flatpak install OpenVSPRepo org.openvsp.OpenVSP
