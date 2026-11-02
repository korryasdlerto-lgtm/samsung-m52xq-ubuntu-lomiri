#!/bin/bash
# классик: залить samsung-m52xq-classic.img в корень /data телефона (на работающей системе это /mnt/userdata) под временным именем,
# после проверки md5 переименовать в rootfs.img (загрузчик берёт /data/rootfs.img первым после SD/USB; откат: переименовать/удалить файл).
set -e
cd "$(dirname "$0")"
IMG=samsung-m52xq-classic.img
{ cat /tmp/claude-1000/-home-sasha-Templates---------/21f124fa-4095-4276-a809-ddade279b463/scratchpad/.pwu; echo; gzip -1 -c $IMG; } | sshpass -f /tmp/claude-1000/-home-sasha-Templates---------/21f124fa-4095-4276-a809-ddade279b463/scratchpad/.pwu ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR user@172.16.42.1 "sudo -S -p '' sh -c 'gunzip > /mnt/userdata/.rootfs.img.part'"
echo "залито: $(date +%T)"
