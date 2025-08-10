#!/bin/bash
set -oue pipefail

log() {
    echo -e "\n\033[1;34m==> $1\033[0m\n"
}

### 🔧 KDE Build Dependencies
log "Installing KDE build dependencies (using solopasha COPRs where possible)..."
dnf5 install -y --skip-broken --allowerasing git python3-dbus python3-pyyaml python3-setproctitle clang-devel

curl -s 'https://invent.kde.org/sysadmin/repo-metadata/-/raw/master/distro-dependencies/fedora.ini' |
  sed '1d' | grep -vE '^\s*#|^\s*$' |
  xargs dnf5 install -y --skip-broken --allowerasing

### 🎮 Steam & Development Tools
log "Installing additional dev tools..."
dnf5 install -y --allowerasing neovim zsh distrobox flatpak-builder

### 🦫 Go & Toolbx Development
log "Installing Go toolchain and Toolbx-related tools..."
dnf5 install -y --allowerasing golang gopls golang-github-cpuguy83-md2man

### 🔌 Enable systemd units
log "Enabling podman socket..."
systemctl enable podman.socket

log "Enabling waydroid service..."
systemctl enable waydroid-container.service
