#!/bin/sh
# spacebar 6.6.4 (Ubuntu 26.04) + патчи pmOS: spacebar-0001 постоянное уведомление, m52xq-spacebar (-p0) SMS на обеих SIM
# (подписка на все модемы, отправка с выбранной SIM, метки «SIM N», статусы неотправленных). -> .deb в out/ (1:6.6.4-0ubuntu1+m52xq2).
# Chroot классик/mesa-build-root2. Использование: ./build.sh (после завершения сборки plasma-dialer — делят CPU).
set -e
B=$(cd "$(dirname "$0")" && pwd); R=$B/../../mesa-build-root2
sudo cp $B/spacebar-0001-persistent-notification.patch $B/m52xq-spacebar.patch $B/spacebar-0002-state-marking.patch $R/build-pd/
sudo chroot $R sh -c 'cd /build-pd && rm -rf spacebar-6.6.4 && dpkg-source -x spacebar_6.6.4-0ubuntu1.dsc >/dev/null && cd spacebar-6.6.4 && patch -p1 < ../spacebar-0001-persistent-notification.patch && patch -p0 < ../m52xq-spacebar.patch && patch -p1 < ../spacebar-0002-state-marking.patch && printf "spacebar (1:6.6.4-0ubuntu1+m52xq2) resolute; urgency=medium\n\n  * m52xq: dual SIM messaging, SIM labels, persistent notification.\n\n -- m52xq <m52xq@localhost>  Thu, 29 Oct 2026 02:00:00 +0000\n\n" | cat - debian/changelog > /tmp/cl && cp /tmp/cl debian/changelog && DEB_BUILD_OPTIONS="nocheck noautodbgsym" dpkg-buildpackage -b -us -uc -j8 2>&1 | tail -12'
rm -rf $B/out; mkdir -p $B/out; sudo cp $R/build-pd/spacebar_*m52xq2*.deb $B/out/; sudo chown -R $(id -u):$(id -g) $B/out; ls -l $B/out
