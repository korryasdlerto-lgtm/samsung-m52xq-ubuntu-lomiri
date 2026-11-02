#!/bin/sh
# классик, шаг 1: базовый корень Ubuntu 20.04 (focal) arm64 через debootstrap (первая стадия), потом вторая стадия в chroot с qemu-aarch64-static
set -e
cd "$(dirname "$0")"
R=$PWD/rootfs-focal
[ -d "$R" ] && { echo "$R уже есть, не трогаю"; exit 1; }
sudo debootstrap --arch=arm64 --foreign --variant=minbase \
  --include=ca-certificates,gnupg,dbus,locales,python3,python3-gi,sudo,kmod,udev,iproute2,iputils-ping,openssh-server,network-manager,modemmanager,wpasupplicant,pulseaudio,alsa-utils,less,nano,systemd-sysv,libpam-systemd,policykit-1,tzdata \
  focal "$R" http://ports.ubuntu.com/ubuntu-ports/
sudo cp /usr/bin/qemu-aarch64-static "$R/usr/bin/"
sudo chroot "$R" /debootstrap/debootstrap --second-stage
echo "шаг 1 готов: $(sudo du -sh $R | cut -f1)"
