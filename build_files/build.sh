#!/bin/bash
set -oue pipefail

log() {
    echo -e "\n\033[1;34m==> $1\033[0m\n"
}

COPR_PLASMA="copr:copr.fedorainfracloud.org/solopasha/plasma-unstable"
COPR_GEAR="copr:copr.fedorainfracloud.org/solopasha/kde-gear-unstable"

echo "==> Updating repo metadata..."
sudo dnf5 clean all
sudo dnf5 makecache

echo "==> Setting COPR priorities..."
sudo dnf5 copr enable "$COPR_PLASMA" -y
sudo dnf5 copr enable "$COPR_GEAR" -y

# Plasma COPR has highest priority
sudo dnf5 config-manager setopt "$COPR_PLASMA".priority=1
sudo dnf5 config-manager setopt "$COPR_GEAR".priority=2

echo "==> Listing packages from COPRs..."
PLASMA_PKGS=$(dnf5 repoquery --repo="$COPR_PLASMA" --qf "%{name}" || true)
GEAR_PKGS=$(dnf5 repoquery --repo="$COPR_GEAR" --qf "%{name}" || true)

echo "==> Finding installed packages that are in COPRs..."
INSTALLED_PLASMA_PKGS=()
for pkg in $PLASMA_PKGS; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
        INSTALLED_PLASMA_PKGS+=("$pkg")
    fi
done

INSTALLED_GEAR_PKGS=()
for pkg in $GEAR_PKGS; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
        INSTALLED_GEAR_PKGS+=("$pkg")
    fi
done

echo "Plasma COPR packages installed: ${INSTALLED_PLASMA_PKGS[*]:-none}"
echo "Gear COPR packages installed: ${INSTALLED_GEAR_PKGS[*]:-none}"

echo "==> Reinstalling from highest priority COPRs..."
if [ ${#INSTALLED_PLASMA_PKGS[@]} -gt 0 ]; then
    sudo dnf5 reinstall -y "${INSTALLED_PLASMA_PKGS[@]}"
fi
if [ ${#INSTALLED_GEAR_PKGS[@]} -gt 0 ]; then
    sudo dnf5 reinstall -y "${INSTALLED_GEAR_PKGS[@]}"
fi

echo "==> Done."

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
