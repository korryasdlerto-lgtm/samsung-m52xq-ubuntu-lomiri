#!/bin/sh
# Конфигурация и сборка qtmultimedia 6.10.2 только с GStreamer-бэкендом (без FFmpeg). Лог: compile.log
set -e
B=$(cd "$(dirname "$0")" && pwd); R=$B/../../mesa-build-root2
sudo chroot $R sh -c 'cd /build-qtmm && rm -rf b && mkdir b && cd b && cmake -G Ninja ../qtmultimedia-everywhere-src-6.10.2 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DFEATURE_ffmpeg=OFF -DFEATURE_gstreamer=ON -DFEATURE_gstreamer_gl=ON -DFEATURE_pulseaudio=OFF -DFEATURE_alsa=OFF -DFEATURE_wmf=OFF -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF -DQT_BUILD_EXAMPLES=OFF && cmake --build . --parallel 8'
