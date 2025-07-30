#!/bin/bash
set -oue pipefail

log() {
    echo -e "\n\033[1;34m==> $1\033[0m\n"
}

### 🧰 Initial Setup
log "Setting up RPM Fusion repositories..."
dnf5 install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

### 🔧 KDE Build Dependencies
log "Installing KDE build dependencies (this might take a while)..."
cp -r /root /root-back
rm -rf /root
mkdir -p /root
cd ~
export PATH="$HOME/.local/bin:$PATH"
curl 'https://invent.kde.org/sdk/kde-builder/-/raw/master/scripts/initial_setup.sh' > initial_setup.sh
bash initial_setup.sh
kde-builder --generate-config
kde-builder --install-distro-packages --prompt-answer Y
cd /
rm -rf /root 
cp -r /root-back /root 

### 🎮 Steam & Development Tools
log "Installing Steam and additional dev tools..."
dnf5 install -y steam steam-devices neovim zsh distrobox waydroid

### 🦫 Go & Toolbx Development
log "Installing Go toolchain and Toolbx-related tools..."
dnf5 install -y golang gopls golang-github-cpuguy83-md2man

### 🧹 Cleanup
log "Removing unnecessary packages..."
dnf5 remove -y firefox

### 🔌 Enable systemd units
log "Enabling podman socket..."
systemctl enable podman.socket

log "Enabling waydroid service..."
systemctl enable waydroid-container.service
# ─────────────────────────────────────────────────────────
# 🧪 You can enable COPRs temporarily like this:
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install some-package
# dnf5 -y copr disable ublue-os/staging
