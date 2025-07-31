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

### 🧪 KDE Unstable COPR
log "Enabling KDE Plasma 6 Unstable COPR..."
dnf5 -y copr enable @kdesig/plasma-6-unstable

log "Refreshing metadata and force-upgrading KDE packages..."
dnf5 upgrade --refresh -y

### 🔧 KDE Build Dependencies
log "Installing KDE build dependencies (this might take a while)..."
dnf5 install -y git python3-dbus python3-pyyaml python3-setproctitle
dnf5 install -y --skip-broken $(curl -s 'https://invent.kde.org/sysadmin/repo-metadata/-/raw/master/distro-dependencies/fedora.ini' | sed '1d' | grep -vE '^\s*#|^\s*$')

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
