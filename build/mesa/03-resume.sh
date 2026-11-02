#!/bin/sh
# Продолжить сборку libEGL_mesa (ninja резюмируется по .ninja_log) — если 02-build.sh был прерван. Конфигурацию НЕ пересоздаёт.
R=$(cd "$(dirname "$0")/../.." && pwd)/mesa-build-root2
sudo mount -t proc proc $R/proc 2>/dev/null || true
sudo mount --bind /dev $R/dev 2>/dev/null || true
sudo chroot $R sh -c 'cd /build/mesa-src && ninja -C bld -j12 src/egl/libEGL_mesa.so.0.0.0 2>&1 | tail -15; ls -la bld/src/egl/libEGL_mesa.so.0.0.0'
