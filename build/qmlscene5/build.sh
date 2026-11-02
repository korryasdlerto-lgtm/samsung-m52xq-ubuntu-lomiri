#!/bin/sh
# Qt 5 qmlscene для классик: в Ubuntu 26.04 Qt5-qmlscene не поставляется (есть только /usr/lib/qt6/bin/qmlscene), а click-приложения
# Ubuntu Touch (uNav: "qmlscene --scaling qml/Main.qml") его вызывают -> «qmlscene: could not find a Qt installation of ''».
# Сборка: tools/qmlscene из qtdeclarative-opensource-src 5.15 в chroot классик/mesa-build-root2 (qemu aarch64). Лог: build.log
set -e
B=$(cd "$(dirname "$0")" && pwd); R=$B/../../mesa-build-root2
sudo chroot $R sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends qtbase5-dev qtbase5-private-dev qtbase5-dev-tools qtdeclarative5-dev qtdeclarative5-private-dev qtdeclarative5-dev-tools libqt5quick5 libqt5qml5 qtchooser make g++ 2>&1 | tail -2'
sudo chroot $R sh -c 'rm -rf /build-qs && mkdir /build-qs && cd /build-qs && apt-get source qtdeclarative-opensource-src 2>&1 | tail -2; ls'
sudo chroot $R sh -c 'cd /build-qs/qtdeclarative-opensource-src-5.15* && ls tools/qmlscene && cd tools/qmlscene && QT_SELECT=qt5 /usr/lib/qt5/bin/qmake qmlscene.pro 2>&1 | tail -5 && make -j8 2>&1 | tail -5; ls -l /build-qs/qtdeclarative-opensource-src-5.15*/tools/qmlscene/qmlscene ../../bin/qmlscene 2>&1 | head'
