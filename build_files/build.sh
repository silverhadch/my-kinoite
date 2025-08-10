#!/bin/bash
set -oue pipefail

log() {
    echo -e "\n\033[1;34m==> $1\033[0m\n"
}

COPRS=(
    "solopasha/plasma-unstable"
    "solopasha/kde-gear-unstable"
)

### Enable COPRs and set priority
for copr in "${COPRS[@]}"; do
    log "Enabling COPR: $copr"
    dnf5 -y copr enable "$copr"
    log "Setting priority=1 for $copr"
    dnf5 -y config-manager setopt "copr:copr.fedorainfracloud.org:${copr////:}.priority=1"
done

### Replace installed packages with COPR versions
for copr in "${COPRS[@]}"; do
    log "Checking packages from $copr..."
    pkg_list=$(dnf5 repoquery --qf '%{name}' --disablerepo='*' \
        --enablerepo="copr:copr.fedorainfracloud.org:${copr////:}" | sort -u)

    if [[ -z "$pkg_list" ]]; then
        echo "  ⚠ No packages found in $copr (skipping)"
        continue
    fi

    while IFS= read -r pkg; do
        if rpm -q "$pkg" >/dev/null 2>&1; then
            echo "  🔄 Reinstalling $pkg from $copr..."
            dnf5 reinstall -y "$pkg" --disablerepo='*' \
                --enablerepo="copr:copr.fedorainfracloud.org:${copr////:}"
        else
            echo "  ⏩ Skipping $pkg (not installed)"
        fi
    done <<< "$pkg_list"
done

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
