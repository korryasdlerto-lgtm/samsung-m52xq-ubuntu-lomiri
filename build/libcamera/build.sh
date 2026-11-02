#!/bin/sh
# libcamera 0.7.2 (upstream v0.7.2) + 10 патчей pmOS (в3/build-libcamera: simple soft-ISP, quad-Bayer, remosaic Tetracell s5kgw3 для 16/64 Мп,
# AGC без записи в датчик и др.; все ложатся на 0.7.2 без правок) -> три .deb с теми же именами, что у Ubuntu: libcamera0.7, libcamera-ipa,
# gstreamer1.0-libcamera (версия 0.7.2+m52xq1; control берётся из пакетов Ubuntu, файлы заменяются своими). Результат — out/.
# Chroot классик/mesa-build-root2 (qemu aarch64). Лог: build.log. Использование: ./build.sh
set -e
B=$(cd "$(dirname "$0")" && pwd); R=$B/../../mesa-build-root2
D=${LIBCAMERA_TARBALL:-}   # при необходимости: путь к libcamera-v0.7.2.tar.gz на хосте (https://gitlab.freedesktop.org/camera/libcamera/-/archive/v0.7.2/)
[ -n "$D" ] && sudo cp "$D" $R/build-pd/libcamera-v0.7.2.tar.gz
sudo cp $B/patches/*.patch $R/build-pd/
sudo chroot $R sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends meson ninja-build pkg-config python3-yaml python3-ply python3-jinja2 libyaml-dev libgnutls28-dev libevent-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libpisp-dev libyuv-dev libudev-dev libdw-dev libunwind-dev libssl-dev openssl g++ 2>&1 | tail -2'
sudo chroot $R sh -c '
set -e
cd /build-pd && rm -rf libcamera-v0.7.2 lc-dest lc-pkg && tar xf libcamera-v0.7.2.tar.gz && cd libcamera-v0.7.2
for f in ../000*.patch ../0010-*.patch; do patch -p1 -s < $f; done
meson setup output --prefix=/usr --libdir=lib/aarch64-linux-gnu --libexecdir=libexec/aarch64-linux-gnu --buildtype=release -Dpipelines=simple -Dipas=simple -Dgstreamer=enabled -Dv4l2=false -Dcam=disabled -Dqcam=disabled -Dlc-compliance=disabled -Dpycamera=disabled -Ddocumentation=disabled -Dtest=false -Dwerror=false 2>&1 | tail -15
ninja -C output -j8 2>&1 | tail -5
DESTDIR=/build-pd/lc-dest meson install --no-rebuild -C output 2>&1 | tail -2
cd /build-pd && mkdir lc-pkg && cd lc-pkg && apt-get download libcamera0.7 libcamera-ipa gstreamer1.0-libcamera 2>&1 | tail -1
L=/build-pd/lc-dest
for p in libcamera0.7 libcamera-ipa gstreamer1.0-libcamera; do
  deb=$(ls ${p}_*.deb); dpkg-deb -R $deb x-$p
  # содержимое пакета (кроме DEBIAN и doc) заменяется нашей сборкой: что в какой пакет — по путям
  find x-$p/usr -mindepth 1 -not -path "x-$p/usr/share/doc*" -not -type d -delete
  find x-$p/usr -mindepth 1 -type d -empty -not -path "x-$p/usr/share/doc*" -delete 2>/dev/null || true
  case $p in
  libcamera0.7)
    mkdir -p x-$p/usr/lib/aarch64-linux-gnu; cp -a $L/usr/lib/aarch64-linux-gnu/libcamera.so* $L/usr/lib/aarch64-linux-gnu/libcamera-base.so* x-$p/usr/lib/aarch64-linux-gnu/ ;;
  libcamera-ipa)
    mkdir -p x-$p/usr/lib/aarch64-linux-gnu x-$p/usr/libexec/aarch64-linux-gnu x-$p/usr/share
    cp -a $L/usr/lib/aarch64-linux-gnu/libcamera x-$p/usr/lib/aarch64-linux-gnu/
    cp -a $L/usr/libexec/aarch64-linux-gnu/libcamera x-$p/usr/libexec/aarch64-linux-gnu/
    [ -d $L/usr/share/libcamera ] && cp -a $L/usr/share/libcamera x-$p/usr/share/ ;;
  gstreamer1.0-libcamera)
    mkdir -p x-$p/usr/lib/aarch64-linux-gnu; cp -a $L/usr/lib/aarch64-linux-gnu/gstreamer-1.0 x-$p/usr/lib/aarch64-linux-gnu/ ;;
  esac
  sed -i "s/^Version: .*/Version: 0.7.2+m52xq1/" x-$p/DEBIAN/control
  rm -f x-$p/DEBIAN/md5sums
  dpkg-deb -b x-$p ${p}_0.7.2+m52xq1_arm64.deb >/dev/null
  echo "== $p"; dpkg-deb -c ${p}_0.7.2+m52xq1_arm64.deb | awk "{print \$6}" | grep -v "/$" | grep -v share/doc | head -20
done
ls -l *m52xq1*.deb
'
rm -rf $B/out; mkdir -p $B/out; sudo cp $R/build-pd/lc-pkg/*m52xq1*.deb $B/out/; sudo chown -R $(id -u):$(id -g) $B/out; ls -l $B/out
