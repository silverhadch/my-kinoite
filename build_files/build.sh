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

### 🔁 Reinstall only installed packages available from COPRs
log "Identifying installed packages available in solopasha COPRs..."
mapfile -t copr_pkgs < <(
    comm -12 \
      <(dnf5 list installed --quiet | awk '{print $1}' | sort) \
      <(dnf5 repoquery --repo=_copr:copr.fedorainfracloud.org:solopasha:plasma-unstable \
                      --repo=_copr:copr.fedorainfracloud.org:solopasha:kde-gear-unstable \
                      --quiet --qf '%{name}' | sort)
)

if [[ ${#copr_pkgs[@]} -gt 0 ]]; then
  log "Reinstalling ${#copr_pkgs[@]} packages from COPRs with high priority..."
  dnf5 reinstall -y \
    --disablerepo='*' \
    --enablerepo='_copr:copr.fedorainfracloud.org:solopasha:plasma-unstable' \
    --enablerepo='_copr:copr.fedorainfracloud.org:solopasha:kde-gear-unstable' \
    --setopt='_copr:copr.fedorainfracloud.org:solopasha:plasma-unstable.priority=1' \
    --setopt='_copr:copr.fedorainfracloud.org:solopasha:kde-gear-unstable.priority=1' \
    "${copr_pkgs[@]}"
else
  log "No matching installed packages found in COPRs."
fi

### 🔧 KDE Build Dependencies
log "Installing KDE build dependencies (using solopasha COPRs where possible)..."
dnf5 install -y git python3-dbus python3-pyyaml python3-setproctitle

curl -s 'https://invent.kde.org/sysadmin/repo-metadata/-/raw/master/distro-dependencies/fedora.ini' |
  sed '1d' | grep -vE '^\s*#|^\s*$' |
  xargs dnf5 install -y --skip-broken \
    --setopt='_copr:copr.fedorainfracloud.org:solopasha:plasma-unstable.priority=1' \
    --setopt='_copr:copr.fedorainfracloud.org:solopasha:kde-gear-unstable.priority=1'

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

