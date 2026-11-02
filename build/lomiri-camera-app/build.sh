#!/bin/sh
# lomiri-camera-app 4.1.1+dfsg-1 (Ubuntu 26.04) + правки pmOS (в3/build-lomiri-camera-app: libcamerasrc в camerabin, libcamera-qml, постобработка
# снимков, необязательный qzxing; патч = diff orig-v4.1.1 -> lomiri-camera-app-v4.1.1, -p1). -> .deb в out/ (4.1.1+dfsg-1+m52xq3).
# Бинарник из pmOS (musl) на Ubuntu не запускается, поэтому пересборка. Chroot классик/mesa-build-root2. Лог: build.log.
set -e
B=$(cd "$(dirname "$0")" && pwd); R=$B/../../mesa-build-root2
sudo cp $B/m52xq-camera-app.patch $B/m52xq-options-overlay.patch $B/m52xq-tap-focus.patch $B/m52xq-16mp-binned.patch $B/m52xq-video-4k.patch $R/build-pd/
sudo chroot $R sh -c 'cd /build-pd && DEBIAN_FRONTEND=noninteractive apt-get build-dep -y lomiri-camera-app 2>&1 | tail -2; rm -rf lomiri-camera-app-4.1.1+dfsg && dpkg-source -x lomiri-camera-app_4.1.1+dfsg-1.dsc >/dev/null 2>&1; cd lomiri-camera-app-4.1.1+dfsg && patch -p1 < ../m52xq-camera-app.patch >/dev/null && patch -p1 < ../m52xq-options-overlay.patch >/dev/null && patch -p1 < ../m52xq-tap-focus.patch >/dev/null && patch -p1 < ../m52xq-16mp-binned.patch >/dev/null && patch -p1 < ../m52xq-video-4k.patch >/dev/null && printf "lomiri-camera-app (4.1.1+dfsg-1+m52xq3) resolute; urgency=medium\n\n  * m52xq: libcamerasrc camerabin source, libcamera-qml, post-processing, optional qzxing.\n\n -- m52xq <m52xq@localhost>  Thu, 29 Oct 2026 03:30:00 +0000\n\n" | cat - debian/changelog > /tmp/cl && cp /tmp/cl debian/changelog && DEB_BUILD_OPTIONS="nocheck noautodbgsym" dpkg-buildpackage -b -us -uc -j8 2>&1 | tail -12'
rm -rf $B/out; mkdir -p $B/out; sudo cp $R/build-pd/lomiri-camera-app*m52xq3*.deb $B/out/; sudo chown -R $(id -u):$(id -g) $B/out; ls -l $B/out
