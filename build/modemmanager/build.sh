#!/bin/sh
# ModemManager 1.25.95 (Ubuntu 26.04) с патчами m52xq (две SIM, DSDS) из pmOS (0100–0103) -> .deb в этой папке/out.
# Chroot классик/mesa-build-root2 (qemu aarch64). Лог: build.log. Использование: ./build.sh
set -e
B=$(cd "$(dirname "$0")" && pwd); R=$B/../../mesa-build-root2
sudo cp $B/0100-*.patch $B/0101-*.patch $B/0102-*.patch $B/0103-*.patch $B/0104-*.patch $R/build-mm/
sudo chroot $R sh -c 'DEBIAN_FRONTEND=noninteractive apt-get build-dep -y modemmanager 2>&1 | tail -2'
sudo chroot $R sh -c 'cd /build-mm && rm -rf modemmanager-1.25.95 && dpkg-source -x modemmanager_1.25.95-1ubuntu1.dsc >/dev/null && cd modemmanager-1.25.95 && for f in ../0100-*.patch ../0101-*.patch ../0102-*.patch ../0103-*.patch ../0104-*.patch; do echo "== $f"; patch -p1 < "$f" || exit 1; done && printf "modemmanager (1.25.95-1ubuntu1+m52xq1) resolute; urgency=medium\n\n  * m52xq: dual SIM (DSDS) patches 0100-0103 from postmarketOS.\n\n -- m52xq <m52xq@localhost>  Wed, 28 Oct 2026 21:00:00 +0000\n\n" | cat - debian/changelog > /tmp/cl && cp /tmp/cl debian/changelog && DEB_BUILD_OPTIONS="nocheck noautodbgsym" dpkg-buildpackage -b -us -uc -j8 2>&1 | tail -15'
mkdir -p $B/out; sudo cp $R/build-mm/*.deb $B/out/ 2>/dev/null; sudo chown -R $(id -u):$(id -g) $B/out; ls -l $B/out
