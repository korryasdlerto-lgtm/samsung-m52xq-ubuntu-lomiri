#!/bin/sh
# Чистый chroot Ubuntu 26.04 arm64 (БЕЗ репозитория UBports — иначе apt понижает библиотеки) для сборки Mesa с EGL_WL_bind_wayland_display.
# Использование: ./01-chroot.sh   -> классик/mesa-build-root2
set -e
cd "$(dirname "$0")/.."/..
R=$PWD/mesa-build-root2
[ -e "$R" ] && { echo "$R уже есть"; exit 1; }
D=$PWD/tools/debootstrap-new/x
export DEBOOTSTRAP_DIR=$D/usr/share/debootstrap
sudo -E $D/usr/sbin/debootstrap --arch=arm64 --foreign --variant=minbase --components=main,universe --no-check-gpg \
  --include=ca-certificates,dpkg-dev,g++,gcc,meson,ninja-build,pkgconf,python3-mako,python3-yaml,python3-packaging,python3-ply,python3-setuptools,bison,flex,libdrm-dev,libwayland-dev,wayland-protocols,libwayland-egl-backend-dev,libexpat1-dev,zlib1g-dev,libzstd-dev,libglvnd-dev,libelf-dev,libudev-dev,libx11-dev,libx11-xcb-dev,libxcb1-dev,libxcb-dri3-dev,libxcb-present-dev,libxcb-sync-dev,libxshmfence-dev,libxcb-randr0-dev,libxcb-xfixes0-dev,libxcb-glx0-dev,libxext-dev,libxfixes-dev,libxxf86vm-dev,glslang-tools,libpciaccess-dev \
  resolute "$R" http://ports.ubuntu.com/ubuntu-ports/
sudo cp /usr/bin/qemu-aarch64-static "$R/usr/bin/"
sudo chroot "$R" /debootstrap/debootstrap --second-stage
printf 'Types: deb deb-src\nURIs: http://ports.ubuntu.com/ubuntu-ports\nSuites: resolute resolute-updates resolute-security\nComponents: main universe\n' | sudo tee "$R/etc/apt/sources.list.d/ubuntu.sources" >/dev/null
echo "готово: $(sudo du -sh $R | cut -f1)"
