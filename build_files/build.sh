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

### 🧩 Enable COPRs for Plasma + Gear
log "Enabling KDE COPRs..."
dnf5 copr enable -y solopasha/plasma-unstable
dnf5 copr enable -y solopasha/kde-gear-unstable

dnf5 install -y yq

### 🔁 Reinstall packages from kinoite-packages.yaml (repo-packages only)
log "Reinstalling Plasma & Gear packages from COPRs..."
curl -sSL https://raw.githubusercontent.com/solopasha/kde6-copr/unstable/atomic/kinoite-packages.yaml |
  yq eval '."repo-packages"[] | .repo + " " + (.packages | join(" "))' |
  while read -r repo pkgs; do
    echo "🔁 Reinstalling from $repo with priority 1:"
    echo "    $pkgs"
    dnf5 reinstall -y \
      --disablerepo='*' \
      --enablerepo="$repo" \
      --setopt="$repo.priority=1" \
      $pkgs
  done

### 🔧 KDE Build Dependencies
log "Installing KDE build dependencies (using solopasha COPRs where possible)..."
dnf5 install -y git python3-dbus python3-pyyaml python3-setproctitle

curl -s 'https://invent.kde.org/sysadmin/repo-metadata/-/raw/master/distro-dependencies/fedora.ini' |
  sed '1d' | grep -vE '^\s*#|^\s*$' |
  xargs dnf5 install -y --skip-broken \
    --setopt=copr:copr.fedorainfracloud.org:solopasha:plasma-unstable.priority=1 \
    --setopt=copr:copr.fedorainfracloud.org:solopasha:kde-gear-unstable.priority=1

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
