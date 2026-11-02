#!/bin/sh
# Сборка ayatana-indicator-bluetooth 26.6.1 с патчем «сопряжённые устройства в шторке» в чистом chroot классик/mesa-build-root2.
# Результат: ayatana-indicator-bluetooth-service.built (копия — в rootfs-files/usr/libexec/ayatana-indicator-bluetooth/).
set -e
B=$(cd "$(dirname "$0")" && pwd); R=$B/../../mesa-build-root2
sudo chroot $R sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends cmake cmake-extras intltool libayatana-common-dev libglib2.0-dev libnotify-dev systemd-dev valac make'
sudo rm -rf $R/build-bt; sudo mkdir -p $R/build-bt; sudo tar -xzf $B/ayatana-indicator-bluetooth-26.6.1.src.tar.gz -C $R/build-bt
(cd $R/build-bt/ayatana-indicator-bluetooth-26.6.1 && sudo patch -p1 < $B/0001-phone-paired-devices.patch)
sudo chroot $R sh -c 'cd /build-bt/ayatana-indicator-bluetooth-26.6.1 && mkdir b && cd b && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DENABLE_TESTS=OFF && make -j12'
sudo cp $R/build-bt/ayatana-indicator-bluetooth-26.6.1/b/src/ayatana-indicator-bluetooth-service $B/ayatana-indicator-bluetooth-service.built
