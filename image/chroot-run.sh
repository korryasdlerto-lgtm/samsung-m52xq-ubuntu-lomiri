#!/bin/sh
# классик: выполнить команду внутри корня Ubuntu (chroot под qemu) с /proc, /sys, /dev, DNS и обычным PATH.
# Использование: ./chroot-run.sh <папка корня> <команда...>   (например ./chroot-run.sh rootfs-26.04-c apt-get update)
R=$(cd "$(dirname "$0")" && pwd)/$1; shift
sudo mount --bind /proc "$R/proc"; sudo mount --bind /sys "$R/sys"; sudo mount --bind /dev "$R/dev"; sudo mount --bind /dev/pts "$R/dev/pts"
sudo cp /etc/resolv.conf "$R/etc/resolv.conf" 2>/dev/null
sudo chroot "$R" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/sbin:/usr/bin:/sbin:/bin DEBIAN_FRONTEND=noninteractive "$@"
rc=$?
sudo umount "$R/dev/pts" "$R/dev" "$R/sys" "$R/proc" 2>/dev/null
exit $rc
