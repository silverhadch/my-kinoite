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
    repo_name="copr:copr.fedorainfracloud.org:${copr////:}"
    
    # Get package list - using the new dnf5 repoquery format
    pkg_list=$(dnf5 --quiet repoquery --available --repo="$repo_name" --qf '%{name}' | sort -u)
    
    if [[ -z "$pkg_list" ]]; then
        echo "  ⚠ No packages found in $copr (skipping)"
        continue
    fi

    # Count packages for progress tracking
    total_pkgs=$(echo "$pkg_list" | wc -l)
    current=0
    
    while IFS= read -r pkg; do
        ((current++))
        # Skip empty lines
        [[ -z "$pkg" ]] && continue
        
        if rpm -q "$pkg" &>/dev/null; then
            echo "  🔄 [$current/$total_pkgs] Reinstalling $pkg from $copr..."
            if ! dnf5 reinstall -y --skip-unavailable "$pkg" --disablerepo='*' --enablerepo="$repo_name"; then
                echo "  ❌ Failed to reinstall $pkg"
            fi
        else
            echo "  ⏩ [$current/$total_pkgs] Skipping $pkg (not installed)"
        fi
    done <<< "$pkg_list"
done

### 🔧 KDE Build Dependencies
log "Installing KDE build dependencies..."
dnf5 install -y --skip-broken --allowerasing --skip-unavailable git python3-dbus python3-pyyaml python3-setproctitle clang-devel

log "Installing KDE Builder dependencies from repo-metadata..."
fedora_ini_url='https://invent.kde.org/sysadmin/repo-metadata/-/raw/master/distro-dependencies/fedora.ini'
if curl -s --fail "$fedora_ini_url" > /tmp/fedora.ini; then
    # Read packages line by line and install
    while IFS= read -r pkg; do
        [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
        echo "  📦 Installing $pkg..."
        dnf5 install -y --skip-broken --allowerasing --skip-unavailable "$pkg"
    done < <(sed '1d' /tmp/fedora.ini)
    rm -f /tmp/fedora.ini
else
    echo "  ⚠ Failed to download KDE Builder dependencies list from $fedora_ini_url"
fi

### 🎮 Development Tools
log "Installing additional dev tools..."
dnf5 install -y --allowerasing --skip-unavailable neovim zsh flatpak-builder

### 🦫 Go & Toolbx Development
log "Installing Go toolchain..."
dnf5 install -y --allowerasing --skip-unavailable golang gopls golang-github-cpuguy83-md2man

### 🔌 Enable systemd units
log "Enabling podman socket..."
systemctl enable --now podman.socket

log "Enabling waydroid service..."
systemctl enable --now waydroid-container.service
