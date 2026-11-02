#!/bin/sh
# GStreamer-бэкенд Qt 6 Multimedia (libgstreamermediaplugin.so) для классик: в пакетах Qt 6 на телефоне только FFmpeg-бэкенд,
# lomiri-mediaplayer-app (Qt 6) декодировал 4K программно (≈429 % CPU) и не использовал Venus (v4l2h264dec в GStreamer).
# Сборка в chroot классик/mesa-build-root2 (Ubuntu 26.04 arm64, qemu), qtmultimedia 6.10.2 (как на телефоне).
# Результат: libgstreamermediaplugin.so в этой папке. Использование: ./build.sh  (лог: build.log)
set -e
B=$(cd "$(dirname "$0")" && pwd); R=$B/../../mesa-build-root2
sudo chroot $R sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-declarative-private-dev qt6-shadertools-dev qt6-base-dev-tools qt6-declarative-dev-tools cmake ninja-build libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgstreamer-plugins-bad1.0-dev libgl-dev libegl-dev libdrm-dev libwayland-dev libpulse-dev libasound2-dev libglib2.0-dev perl'
sudo chroot $R sh -c 'rm -rf /build-qtmm && mkdir /build-qtmm && cd /build-qtmm && apt-get source --download-only qt6-multimedia 2>&1 | tail -2; ls'
sudo chroot $R sh -c 'cd /build-qtmm && ls *.orig.tar.* && tar -xf qt6-multimedia*.orig.tar.* && ls'
