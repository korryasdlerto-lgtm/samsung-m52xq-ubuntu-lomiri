#!/bin/sh
# Сборка libEGL_mesa (Mesa 26.0.8-1ubuntu0.3) с -Dlegacy-wayland=bind-wayland-display в чистом chroot mesa-build-root2.
# Результат: mesa-build-root2/build/mesa-src/bld/src/egl/libEGL_mesa.so.0.0.0 (и libgbm/другие цели, если нужны).
set -e
R=$(cd "$(dirname "$0")/../.." && pwd)/mesa-build-root2
sudo mount -t proc proc $R/proc 2>/dev/null || true
sudo mount --bind /dev $R/dev 2>/dev/null || true
sudo cp /etc/resolv.conf $R/etc/resolv.conf
sudo chroot $R sh -c '
set -e
apt-get update 2>&1 | tail -2
mkdir -p /build && cd /build
[ -d mesa-src ] || { apt-get source --download-only mesa=26.0.8-1ubuntu0.3 2>&1 | tail -2; dpkg-source -x mesa_26.0.8-1ubuntu0.3.dsc mesa-src 2>&1 | tail -2; }
cd mesa-src
# Ubuntu кладёт в VERSION полную версию пакета (debian/rules): от неё имя libgallium-<версия>.so и версия символов — должны совпасть с системной библиотекой на телефоне
echo 26.0.8-1ubuntu0.3 > VERSION
rm -rf bld
meson setup bld -Dprefix=/usr -Dlibdir=lib/aarch64-linux-gnu -Dbuildtype=release -Dplatforms=wayland \
  -Dgallium-drivers=softpipe -Dvulkan-drivers= -Dglx=disabled -Dgbm=enabled -Degl=enabled -Dllvm=disabled \
  -Dlegacy-wayland=bind-wayland-display -Dgles1=disabled -Dgles2=enabled -Dvideo-codecs= -Dtools= \
  -Dlmsensors=disabled -Dvalgrind=disabled -Dglvnd=enabled 2>&1 | tail -30
ninja -C bld -j12 src/egl/libEGL_mesa.so.0.0.0 2>&1 | tail -15
ls -la bld/src/egl/ | head
'
