#!/bin/bash
set -oue pipefail

log() {
    echo -e "\n\033[1;34m==> $1\033[0m\n"
}

error() {
    echo -e "\n\033[1;31mERROR: $1\033[0m\n" >&2
}

log "Fedora Version:"
log "$(rpm -E %fedora)"
log "Running main setup..."

### --------------------
### Firefox
### --------------------

log "Installing Firefox..."
if ! dnf5 install -y --allowerasing firefox 2>/tmp/firefox-dnf-error ; then
    error "Failed to install Firefox: $(grep -v '^Last metadata' /tmp/firefox-dnf-error | head -n5)"
fi

### --------------------
### Core Go tools and primary utilities
### --------------------

go_tools=(
    golang
    gopls
    golang-github-cpuguy83-md2man
    shadow-utils-subid-devel
    podman-compose
    curl
    dialog
    freerdp
    git
    iproute
    libnotify
    nmap-ncat
    gnome-boxes
)
for tool in "${go_tools[@]}"; do
    if ! dnf5 install -y --skip-broken --skip-unavailable --allowerasing "$tool" 2>/tmp/dnf-error; then
        error "Failed to install $tool: $(grep -v '^Last metadata' /tmp/dnf-error | head -n5)"
    fi
done

### --------------------
### Firefox PWA repo
### --------------------
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

### --------------------
### Extra software (mapped from NixOS config)
### --------------------

extra_pkgs=(
    btop bottles clang-tools-extra curl discord flatpak gimp git git-clang-format
    github-desktop htop kcalc konsole partitionmanager xdg-desktop-portal-kde
    libreoffice qbittorrent spotify supertux supertuxkart thunderbird
    toolbox vim vlc wget xdg-desktop-portal-gtk cmake-gui gcc make go gopls
    golang-github-cpuguy83-md2man libgcc meson shadow-utils podman xdg-utils
    wayland-utils kde-dev-utils kde-dev-scripts cowsay fortune-mod sl ponysay
    cmatrix toilet figlet rig nyancat
)
for pkg in "${extra_pkgs[@]}"; do
    if ! dnf5 install -y --skip-broken --skip-unavailable --allowerasing "$pkg" 2>/tmp/dnf-error; then
        error "Failed to install $pkg: $(grep -v '^Last metadata' /tmp/dnf-error | head -n5)"
    fi
done

### --------------------
### Virtualization stack: Tools & Services
### --------------------

log "Installing Fedora Virtualization group and dependencies..."
if ! dnf5 group install -y --with-optional virtualization 2>/tmp/dnf-virt-error; then
    error "Failed to install virtualization group: $(grep -v '^Last metadata' /tmp/dnf-virt-error | head -n5)"
fi

virt_pkgs=(qemu-kvm virt-manager virt-install virt-viewer libvirt-daemon-config-network libvirt-daemon-kvm)
for pkg in "${virt_pkgs[@]}"; do
    if ! dnf5 install -y --allowerasing "$pkg" 2>/tmp/dnf-virt-error; then
        error "Failed to install virtualization tool/pkg $pkg: $(grep -v '^Last metadata' /tmp/dnf-virt-error | head -n5)"
    fi
done

# Only enable default virsh network for autostart (do not start or enable any services in CI/rootfs)
log "Enabling default libvirt network for autostart..."
if virsh net-info default &>/dev/null; then
    virsh net-autostart default || error "Failed to set default network to autostart"
else
    error "No default libvirt network found; please run 'virsh net-define ...' manually."
fi

### --------------------
### KDE dependencies
### --------------------

log "Fetching KDE dependency list..."
kde_deps=$(curl -s "https://invent.kde.org/sysadmin/repo-metadata/-/raw/master/distro-dependencies/fedora.ini" | sed '1d' | grep -vE '^\s*#|^\s*$')
if [[ -z "$kde_deps" ]]; then
    error "Failed to fetch KDE dependencies list"
else
    log "Installing KDE dependencies..."
    echo "$kde_deps" | xargs dnf5 install -y --skip-broken --skip-unavailable --allowerasing 2>/tmp/dnf-error || \
        error "Some KDE dependencies failed to install: $(grep -v '^Last metadata' /tmp/dnf-error | head -n5)"
fi

### --------------------
### Additional Dev Tools
### --------------------
log "Installing additional dev tools..."
dev_tools=(neovim zsh flatpak-builder kdevelop kdevelop-devel kdevelop-libs)
for tool in "${dev_tools[@]}"; do
    if ! dnf5 install -y --skip-broken --skip-unavailable --allowerasing "$tool" 2>/tmp/dnf-error; then
        error "Failed to install $tool: $(grep -v '^Last metadata' /tmp/dnf-error | head -n5)"
    fi
done

### --------------------
### kde-builder
### --------------------
log "Installing kde-builder..."
tmpdir=$(mktemp -d)
pushd "$tmpdir" >/dev/null
git clone https://invent.kde.org/sdk/kde-builder.git
cd kde-builder
mkdir -p /usr/share/kde-builder
cp -r ./* /usr/share/kde-builder
mkdir -p /usr/bin
ln -sf /usr/share/kde-builder/kde-builder /usr/bin/kde-builder
mkdir -p /usr/share/zsh/site-functions
ln -sf /usr/share/kde-builder/data/completions/zsh/_kde-builder /usr/share/zsh/site-functions/_kde-builder
ln -sf /usr/share/kde-builder/data/completions/zsh/_kde-builder_projects_and_groups /usr/share/zsh/site-functions/_kde-builder_projects_and_groups
popd >/dev/null
rm -rf "$tmpdir"

### --------------------
### winboat (latest AppImage)
### --------------------
log "Installing latest winboat..."
REPO="TibixDev/winboat"
tag=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name')
version="${tag#v}"
url="https://github.com/$REPO/releases/download/$tag/winboat-${version}-x86_64.AppImage"

log "Downloading $url"
curl -L -o "winboat-${version}.AppImage" "$url"

log "Installing winboat ${version}"
mv "./winboat-${version}.AppImage" /usr/bin/winboat || error "Failed to install winboat"
chmod +x /usr/bin/winboat

log "Installing winboat icon..."
install -Dm644 /dev/null "/usr/share/icons/hicolor/scalable/apps/winboat.svg"
curl -L "https://raw.githubusercontent.com/TibixDev/winboat/refs/heads/main/gh-assets/winboat_logo.svg" -o "/usr/share/icons/hicolor/scalable/apps/winboat.svg" || error "Failed to download icon"

log "Creating desktop entry..."
desktop_file="/usr/share/applications/winboat.desktop"
echo "[Desktop Entry]"                >  "$desktop_file"
echo "Name=winboat"                  >> "$desktop_file"
echo "Exec=/usr/bin/winboat %U"      >> "$desktop_file"
echo "Terminal=false"                >> "$desktop_file"
echo "Type=Application"              >> "$desktop_file"
echo "Icon=winboat"                  >> "$desktop_file"
echo "StartupWMClass=winboat"        >> "$desktop_file"
echo "Comment=Windows for Penguins"  >> "$desktop_file"
echo "Categories=Utility;"           >> "$desktop_file"

### --------------------
### Enable podman, waydroid, docker (no --now)
### --------------------
log "Enabling podman socket..."
systemctl enable podman.socket || error "Failed to enable podman.socket"
log "Enabling waydroid service..."
systemctl enable waydroid-container.service || error "Failed to enable waydroid-container.service"
log "Enabling docker service..."
systemctl enable docker.service || error "Failed to enable docker.service"
