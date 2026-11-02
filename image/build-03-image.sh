#!/bin/bash
# классик, шаг 4: пустой образ GPT (сектор 4096, как у v3: те же PARTUUID и UUID файловых систем) + копия корня Ubuntu 26.04.
# Использование: ./build-03-image.sh rootfs-26.04-c   -> samsung-m52xq-classic.img, смонтированный на mnt-new (остаётся смонтированным для шага 5)
set -e
cd "$(dirname "$0")"
SRC=$PWD/${1:?папка корня}
IMG=$PWD/samsung-m52xq-classic.img
[ -e "$IMG" ] && { echo "$IMG уже есть"; exit 1; }
SECT=4096
P1_START=2048; P1_END=124927            # 480 МиБ, как в v3
P2_START=124928; P2_SECTORS=$((5*1024*1024*1024/SECT)); P2_END=$((P2_START+P2_SECTORS-1))   # 5 ГиБ корня
TOTAL=$(( (P2_END + 1 + 40) * SECT ))
truncate -s $TOTAL "$IMG"
L=$(sudo losetup -fP -b $SECT --show "$IMG")
sudo sgdisk -o "$L" >/dev/null
sudo sgdisk -n 1:$P1_START:$P1_END -t 1:EF00 -c 1:primary -u 1:C57D543F-2B8D-4F32-A27B-CDD7E68E1D76 \
            -n 2:$P2_START:$P2_END -t 2:8305 -c 2:primary -u 2:E7BC48A5-73CD-420C-916B-FC997CDB7486 "$L" >/dev/null
sudo losetup -d "$L"
L=$(sudo losetup -fP -b $SECT --show "$IMG"); echo "$L" > tools/new.loop
sudo mkfs.ext2 -q -L pmOS_boot -U b58f3919-56c2-45b3-b952-281dcbace35a ${L}p1
sudo mkfs.ext4 -q -L pmOS_root -U 27c97050-ff55-4e42-b894-0f866eb5ad1f ${L}p2
mkdir -p mnt-new; sudo mount ${L}p2 mnt-new
# p1 (/boot) как в v3
mkdir -p mnt-v3-boot; sudo mount -o ro /dev/loop18p1 mnt-v3-boot 2>/dev/null || true
sudo mkdir -p mnt-new/boot; sudo mount ${L}p1 mnt-new/boot
[ -d mnt-v3-boot/lost+found ] && sudo rsync -aHAX --exclude lost+found mnt-v3-boot/ mnt-new/boot/
sudo rsync -aHAX --numeric-ids --info=progress2 --exclude=/proc/* --exclude=/sys/* --exclude=/dev/* --exclude=/boot/* "$SRC"/ mnt-new/
sudo rm -f mnt-new/usr/bin/qemu-aarch64-static
echo "шаг 4 готов: $(sudo du -sh mnt-new | cut -f1) в корне, loop $L"; df -h mnt-new | tail -1
