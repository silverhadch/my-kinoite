#!/bin/bash
set -oue pipefail

log() {
    echo -e "\n\033[1;34m==> $1\033[0m\n"
}

error() {
    echo -e "\n\033[1;31mERROR: $1\033[0m\n" >&2
}

log "Fedora Version:"
log $(rpm -E %fedora)
log "Installing..."

log "Installing rdp2 tools..."
dnf5 install -y --skip-broken --skip-unavailable --allowerasing freerdp2-libs freerdp2-devel

log "Installing Virtualisations tools..."
dnf5 group install -y --skip-broken --skip-unavailable --allowerasing --with-optional virtualization

# Core Go tools
go_tools=(
    golang
    gopls
    golang-github-cpuguy83-md2man
    shadow-utils-subid-devel
    firefox
    podman-compose
)
for tool in "${go_tools[@]}"; do
    if ! dnf5 install -y --skip-broken --skip-unavailable --allowerasing "$tool" 2>/tmp/dnf-error; then
        error "Failed to install $tool: $(grep -v '^Last metadata' /tmp/dnf-error | head -n5)"
    fi
done

# Firefox PWA repo
rpm --import https://packagecloud.io/filips/FirefoxPWA/gpgkey
cat >/etc/yum.repos.d/firefoxpwa.repo <<'EOF'
[firefoxpwa]
name=FirefoxPWA
metadata_expire=7d
baseurl=https://packagecloud.io/filips/FirefoxPWA/rpm_any/rpm_any/$basearch
gpgkey=https://packagecloud.io/filips/FirefoxPWA/gpgkey
repo_gpgcheck=1
gpgcheck=0
enabled=1
EOF

dnf5 -q makecache -y --disablerepo="*" --enablerepo="firefoxpwa"
dnf5 install -y firefoxpwa

# Extra software (mapped from NixOS config)
extra_pkgs=(
    btop
    bottles
    clang-tools-extra
    curl
    discord
    flatpak
    gimp
    git
    git-clang-format
    github-desktop
    htop
    kcalc
    konsole
    partitionmanager
    xdg-desktop-portal-kde
    libreoffice
    qbittorrent
    spotify
    supertux
    supertuxkart
    thunderbird
    toolbox
    vim
    vlc
    wget
    xdg-desktop-portal-gtk
    cmake-gui
    gcc
    make
    go
    gopls
    golang-github-cpuguy83-md2man
    libgcc
    meson
    shadow-utils
    podman
    xdg-utils
    wayland-utils
    kde-dev-utils
    kde-dev-scripts
    cowsay
    fortune-mod
    sl
    ponysay
    cmatrix
    toilet
    figlet
    rig
    nyancat
)

# Install all extra pkgs
for pkg in "${extra_pkgs[@]}"; do
    if ! dnf5 install -y --skip-broken --skip-unavailable --allowerasing "$pkg" 2>/tmp/dnf-error; then
        error "Failed to install $pkg: $(grep -v '^Last metadata' /tmp/dnf-error | head -n5)"
    fi
done

log "Enabling libvirtd..."
systemctl enable libvirtd
