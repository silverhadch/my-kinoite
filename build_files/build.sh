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
wget https://mega.nz/linux/repo/Fedora_$(rpm -E %fedora)/x86_64/megasync-Fedora_$(rpm -E %fedora).x86_64.rpm && dnf5 install -y "$PWD/megasync-Fedora_$(rpm -E %fedora).x86_64.rpm"

go_tools=(golang gopls golang-github-cpuguy83-md2man shadow-utils-subid-devel firefox)
for tool in "${go_tools[@]}"; do
    if ! dnf5 install -y --skip-broken --skip-unavailable --allowerasing "$tool" 2>/tmp/dnf-error; then
        error "Failed to install $tool: $(grep -v '^Last metadata' /tmp/dnf-error | head -n5)"
    fi
done

rpm --import https://packagecloud.io/filips/FirefoxPWA/gpgkey
echo -e "[firefoxpwa]\nname=FirefoxPWA\nmetadata_expire=7d\nbaseurl=https://packagecloud.io/filips/FirefoxPWA/rpm_any/rpm_any/\$basearch\ngpgkey=https://packagecloud.io/filips/FirefoxPWA/gpgkey\nrepo_gpgcheck=1\ngpgcheck=0\nenabled=1" | tee /etc/yum.repos.d/firefoxpwa.repo
dnf5 -q makecache -y --disablerepo="*" --enablerepo="firefoxpwa"
dnf5 install -y firefoxpwa
