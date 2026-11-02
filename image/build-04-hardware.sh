#!/bin/bash
# классик, шаг 5: слой железа m52xq поверх корня Ubuntu (образ уже смонтирован на mnt-new, образ v3 — на mnt-v3 только чтение).
# Копируется: модули ядра 7.1.2, прошивки, /usr/local (скрипты m52xq-*), часть /etc и udev/systemd/ucm. Alpine-бинарники (musl) НЕ копируются.
set -e
cd "$(dirname "$0")"
V=$PWD/mnt-v3; N=$PWD/mnt-new
cp_dir() { sudo mkdir -p "$N/$2"; sudo rsync -aH --chown=root:root "$V/$1/" "$N/$2/"; }   # каталог -> каталог
cp_file() { sudo mkdir -p "$N/$(dirname "${2:-$1}")"; sudo rsync -aH --chown=root:root "$V/$1" "$N/${2:-$1}"; }
# 1. ядро и прошивки (в Ubuntu /lib -> usr/lib)
cp_dir lib/modules usr/lib/modules
cp_dir lib/firmware usr/lib/firmware
# 2. наш слой скриптов и данных
cp_dir usr/local usr/local
cp_dir etc/m52xq etc/m52xq
for f in $(cd $V && ls etc/udev/rules.d/*m52xq* 2>/dev/null); do cp_file $f; done
for f in 10-fastrpc 20-imagis-input 20-tm2-touchkey-input 20-tm2-touchkey-leds 20-zinitix-input 50-udmabuf; do cp_file usr/lib/udev/rules.d/$f.rules; done
for f in $(cd $V && ls etc/systemd/system/m52xq-*.service etc/systemd/system/m52xq-*.path 2>/dev/null); do cp_file $f; done
for f in $(cd $V && ls usr/lib/systemd/system-sleep/m52xq-*.sh); do cp_file $f; done
for f in etc/systemd/journald.conf.d/00-m52xq-debug.conf etc/systemd/resolved.conf.d/m52xq.conf etc/systemd/sleep.conf.d/m52xq.conf \
         etc/tmpfiles.d/m52xq-udmabuf.conf etc/NetworkManager/conf.d/90-m52xq-hotspot.conf etc/NetworkManager/dispatcher.d/90-m52xq-wowlan \
         etc/ssh/sshd_config.d/99-m52xq.conf etc/geoclue/conf.d/90-m52xq.conf etc/m52xq-hotspot.conf; do [ -e "$V/$f" ] && cp_file $f; done
for d in usr/share/alsa/ucm2/Qualcomm usr/share/qcom usr/share/deviceinfo usr/share/sounds/m52xq usr/share/plymouth/themes/m52xq-ubuntu-touch usr/lib/m52xq usr/libexec/m52xq-camera-switch; do [ -e "$V/$d" ] && { [ -d "$V/$d" ] && cp_dir $d $d || cp_file $d; }; done
sudo mkdir -p "$N/usr/share/alsa/ucm2/conf.d"; sudo rsync -aH --chown=root:root "$V/usr/share/alsa/ucm2/conf.d/" "$N/usr/share/alsa/ucm2/conf.d/" 2>/dev/null || true
# 3. вторая часть: m52xq-ные systemd-cкрипты в /etc/systemd/system.conf.d (PATH) и сервисы-подсказки
for f in etc/systemd/system.conf.d/10-m52xq-path.conf etc/systemd/user.conf.d/10-m52xq-path.conf; do [ -e "$V/$f" ] && cp_file $f; done
sudo chown -R root:root "$N/usr/local" "$N/etc/m52xq" 2>/dev/null || true
echo "шаг 5: слой железа скопирован: $(sudo du -sh $N/usr/lib/modules $N/usr/lib/firmware $N/usr/local | tr '\t' ' ' | tr '\n' ';')"
