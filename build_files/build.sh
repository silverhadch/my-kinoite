#!/bin/bash
set -oue pipefail

log() {
    echo -e "\n\033[1;34m==> $1\033[0m\n"
}

error() {
    echo -e "\n\033[1;31mERROR: $1\033[0m\n" >&2
}

log "Fedora $(rpm -E %fedora) - running setup..."

### --------------------
### Nix bind mount (/var/nix-mount → /nix)
### --------------------
log "Setting up Nix bind mount..."

# Ensure the real backing directory exists
tee /etc/tmpfiles.d/nix-mount.conf >/dev/null <<'EOF'
# Ensure target directory exists
d /var/nix-mount 0755 root root -
EOF

# Ensure the mountpoint exists (systemd mount units require the directory)
mkdir -p /nix

# systemd mount unit for /nix -> /var/nix-mount
cat >/etc/systemd/system/nix.mount <<'EOF'
[Unit]
Description=Bind mount for Nix store (will fail first run)
Before=local-fs.target
After=var.mount

[Mount]
What=/var/nix-mount
Where=/nix
Type=none
Options=bind

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nix.mount || error "Failed to enable nix.mount"

### --------------------
### KDE Builder Conf and Sysext
### --------------------
log "Setting up KDE Builder Config..."
mkdir -p /etc/xdg
cp /ctx/kde-builder.yaml /etc/xdg/

log "Installing systemd-sysext for KDE Builder Setup Script..."
cp /ctx/setup-kde-sysext /usr/bin/

### --------------------
### Firefox
### --------------------
log "Installing Firefox..."
if ! dnf5 install -y --allowerasing firefox 2>/tmp/firefox-dnf-error ; then
    error "Failed to install Firefox: $(grep -v '^Last metadata' /tmp/firefox-dnf-error | head -n5)"
fi

### --------------------
### Core system tools
### --------------------
core_system_pkgs=(
    curl dialog freerdp git iproute libnotify nmap-ncat shadow-utils-subid-devel
    gnome-boxes
)

### --------------------
### Development toolchain
### --------------------
dev_pkgs=(
    gcc make go gopls golang golang-github-cpuguy83-md2man
    meson cmake-gui libgcc nasm
    btrfs-progs-devel python3-btrfsutil
)

### --------------------
### KDE / Qt / PipeWire development
### --------------------
kde_devel_pkgs=(
    # KDE frameworks & general Plasma dev headers
    kpipewire-devel
    pipewire-devel
    plasma-wayland-protocols-devel
    kf6-*-devel
    kdecoration-devel
    kde-*-devel

    # KF6 CMake deps
    "cmake(KF6Config)"
    "cmake(KF6CoreAddons)"
    "cmake(KF6Crash)"
    "cmake(KF6DBusAddons)"
    "cmake(KF6GuiAddons)"
    "cmake(KF6I18n)"
    "cmake(KF6KCMUtils)"
    "cmake(KF6StatusNotifierItem)"

    # Qt6 CMake deps
    "cmake(Qt6Core)"
    "cmake(Qt6DBus)"
    "cmake(Qt6Gui)"
    "cmake(Qt6Network)"
    "cmake(Qt6Qml)"
    "cmake(Qt6Quick)"
    "cmake(Qt6WaylandClient)"

    qt6-qtbase-private-devel

    # FreeRDP stack
    "cmake(FreeRDP-Server)>=3"
    "cmake(FreeRDP)>=3"
    "cmake(WinPR)>=3"

    # Extra KDE/Wayland components
    "cmake(KPipeWire)"
    "cmake(PlasmaWaylandProtocols)"
    "cmake(Qca)"
    "cmake(Qt6Keychain)"

    # pkgconfig deps
    "pkgconfig(epoxy)"
    "pkgconfig(gbm)"
    "pkgconfig(libdrm)"
    "pkgconfig(libpipewire-0.3)"
    "pkgconfig(libavcodec)"
    "pkgconfig(libavfilter)"
    "pkgconfig(libavformat)"
    "pkgconfig(libavutil)"
    "pkgconfig(libswscale)"
    "pkgconfig(libva-drm)"
    "pkgconfig(libva)"
    "pkgconfig(xkbcommon)"

    # System deps
    pam-devel
    wayland-devel
)

### --------------------
### Desktop software (apps, games, tools)
### --------------------
desktop_pkgs=(
    btop bottles clang-tools-extra
    discord flatpak gimp git-clang-format github-desktop
    htop kcalc konsole partitionmanager libreoffice
    qbittorrent spotify steam supertux supertuxkart thunderbird
    vim vlc wget steam xdg-desktop-portal-kde xdg-desktop-portal-gtk
    cmatrix cowsay fortune-mod sl ponysay toilet figlet rig nyancat waydroid
)

### --------------------
### Network/Container tools
### --------------------
network_pkgs=(
    podman podman-compose toolbox xdg-utils wayland-utils
)

### --------------------
### Generic installer helper
### --------------------
install_group() {
    local title="$1"; shift
    local pkgs=("$@")

    log "Installing $title..."
    for pkg in "${pkgs[@]}"; do
        if ! dnf5 install -y --skip-broken --skip-unavailable --allowerasing "$pkg" 2>/tmp/dnf-error; then
            error "Failed to install $pkg: $(grep -v '^Last metadata' /tmp/dnf-error | head -n5)"
        fi
    done
}

install_group "core system tools"      "${core_system_pkgs[@]}"
install_group "development tools"       "${dev_pkgs[@]}"
install_group "desktop software"        "${desktop_pkgs[@]}"
install_group "network/container tools" "${network_pkgs[@]}"
install_group "KDE/Qt/PipeWire deps"    "${kde_devel_pkgs[@]}"

### --------------------
### Firefox PWA repo
### --------------------
log "Configuring FirefoxPWA repo..."
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

dnf5 -q makecache -y --disablerepo="*" --enablerepo="firefoxpwa" || true
dnf5 install -y firefoxpwa || error "Failed to install FirefoxPWA"

### --------------------
### Virtualization stack
### --------------------
log "Installing virtualization group..."
if ! dnf5 group install -y --with-optional virtualization 2>/tmp/dnf-virt-error; then
    error "Virtualization group failed: $(grep -v '^Last metadata' /tmp/dnf-virt-error | head -n5)"
fi

virt_pkgs=(qemu-kvm virt-manager virt-install virt-viewer libvirt-daemon-config-network libvirt-daemon-kvm)
install_group "virtualization extras" "${virt_pkgs[@]}"

log "Setting libvirt autostart..."
if virsh net-info default &>/dev/null; then
    virsh net-autostart default || error "Failed to autostart default network"
fi

### --------------------
### KDE dependency list
### --------------------
log "Fetching KDE metadata deps..."
kde_deps=$(curl -s "https://invent.kde.org/sysadmin/repo-metadata/-/raw/master/distro-dependencies/fedora.ini" | sed '1d' | grep -vE '^\s*#|^\s*$')

if [[ -n "$kde_deps" ]]; then
    log "Installing KDE metadata deps..."
    echo "$kde_deps" | xargs dnf5 install -y --skip-broken --skip-unavailable --allowerasing 2>/tmp/dnf-error || \
        error "Some KDE deps failed: $(grep -v '^Last metadata' /tmp/dnf-error | head -n5)"
else
    error "Failed to fetch KDE dependency metadata"
fi

### --------------------
### Additional dev tools
### --------------------
install_group "extra dev tools" neovim zsh flatpak-builder kdevelop kdevelop-devel kdevelop-libs rust cargo

### --------------------
### kde-builder install
### --------------------
log "Installing kde-builder..."
tmpdir=$(mktemp -d)
pushd "$tmpdir" >/dev/null
git clone https://invent.kde.org/sdk/kde-builder.git
cd kde-builder
install -d /usr/share/kde-builder
cp -r ./* /usr/share/kde-builder
ln -sf /usr/share/kde-builder/kde-builder /usr/bin/kde-builder

install -d /usr/share/zsh/site-functions
ln -sf /usr/share/kde-builder/data/completions/zsh/_kde-builder /usr/share/zsh/site-functions/
ln -sf /usr/share/kde-builder/data/completions/zsh/_kde-builder_projects_and_groups /usr/share/zsh/site-functions/
popd >/dev/null
rm -rf "$tmpdir"

### --------------------
### winboat installer
### --------------------
log "Installing winboat..."
REPO="TibixDev/winboat"
tag=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name')
version="${tag#v}"
url="https://github.com/$REPO/releases/download/$tag/winboat-${version}-x86_64.AppImage"

curl -L -o "winboat-${version}.AppImage" "$url"
mv "winboat-${version}.AppImage" /usr/bin/winboat
chmod +x /usr/bin/winboat

install -Dm644 <(curl -sL https://raw.githubusercontent.com/TibixDev/winboat/refs/heads/main/gh-assets/winboat_logo.svg) "/usr/share/icons/hicolor/scalable/apps/winboat.svg"

cat >/usr/share/applications/winboat.desktop <<EOF
[Desktop Entry]
Name=winboat
Exec=/usr/bin/winboat %U
Terminal=false
Type=Application
Icon=winboat
StartupWMClass=winboat
Comment=Windows for Penguins
Categories=Utility;
EOF

### --------------------
### Enable services (no --now)
### --------------------
systemctl enable podman.socket || error "Failed to enable podman.socket"
systemctl enable waydroid-container.service || error "Failed to enable waydroid-container.service"
systemctl enable docker.service || error "Failed to enable docker.service"
