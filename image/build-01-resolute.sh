#!/bin/sh
# классик, шаг 1: базовый корень Ubuntu 26.04 (resolute) arm64 через СВЕЖИЙ debootstrap 1.0.144 (старый debootstrap хоста 20.04 ломается:
# tar: ./bin: Cannot create symlink to 'usr/bin': File exists). Свежий берётся из архива Ubuntu и распаковывается в tools/debootstrap-new/x (систему не меняем).
# Первая стадия (--foreign), потом вторая в chroot под qemu-aarch64-static. Аргумент: имя папки корня (должна быть НОВОЙ).
set -e
cd "$(dirname "$0")"
R=$PWD/${1:-rootfs-26.04-c}
[ -e "$R" ] && { echo "$R уже есть, дайте новое имя"; exit 1; }
D=$PWD/tools/debootstrap-new/x
export DEBOOTSTRAP_DIR=$D/usr/share/debootstrap
sudo -E $D/usr/sbin/debootstrap --arch=arm64 --foreign --variant=minbase --no-check-gpg \
  --include=ca-certificates,gnupg,dbus,locales,python3,python3-gi,sudo,kmod,udev,iproute2,iputils-ping,openssh-server,network-manager,modemmanager,wpasupplicant,pipewire,pipewire-pulse,wireplumber,polkitd,alsa-utils,less,nano,systemd-sysv,libpam-systemd,tzdata \
  resolute "$R" http://ports.ubuntu.com/ubuntu-ports/
sudo cp /usr/bin/qemu-aarch64-static "$R/usr/bin/"
sudo chroot "$R" /debootstrap/debootstrap --second-stage
echo "шаг 1 готов: $(sudo du -sh $R | cut -f1)"
