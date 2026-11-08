#!/bin/bash
# классик: залить samsung-m52xq-classic.img в корень /data телефона (на работающей системе это /mnt/userdata) под временным именем,
# после проверки md5 переименовать в rootfs.img (загрузчик берёт /data/rootfs.img первым после SD/USB; откат: переименовать/удалить файл).
set -e
cd "$(dirname "$0")"
IMG=samsung-m52xq-classic.img
PWF=${PWF:?file with the phone user password}   # пароль user телефона, одна строка
{ cat $PWF; echo; gzip -1 -c $IMG; } | sshpass -f $PWF ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR user@172.16.42.1 "sudo -S -p '' sh -c 'gunzip > /mnt/userdata/.rootfs.img.part'"
echo "залито: $(date +%T)"
