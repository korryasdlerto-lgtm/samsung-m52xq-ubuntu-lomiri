#!/bin/sh
# Плагин Qt Positioning «lomiri» (libqtposition_lomiri.so) для Qt 5 на Ubuntu 26.04: приложения (Pure Maps, uNav) берут позицию у
# lomiri-location-service (gpsd, наш GPS). В pmOS плагин лежал в Alpine-пакете lomiri-location-service (musl — не грузится).
# Исходники: lomiri-location-service 3.4.1, qt/position/ (4 файла). Заголовки/библиотеки UBports — только в sysroot (/build-lls/sys),
# в систему chroot и на телефон НЕ ставятся (на телефоне dev-пакет потянул бы понижение systemd/udev/libc).
# Использование (на компьютере): sudo chroot mesa-build-root2 sh /build-lls/build.sh
set -e
cd /build-lls/qt/position
S=/build-lls/sys/usr
Q=/usr/lib/qt5/bin
QT=/usr/include/aarch64-linux-gnu/qt5
MI="-I. -I$QT -I$QT/QtCore -I$QT/QtGui -I$QT/QtPositioning -DQT_NO_KEYWORDS -DQT_PLUGIN"
$Q/moc $MI core_geo_position_info_source.h -o moc_source.cpp
$Q/moc $MI core_geo_position_info_source_factory.h -o moc_factory.cpp
$Q/rcc position.qrc -name position -o qrc_position.cpp
g++ -std=c++17 -O2 -fPIC -shared -DQT_NO_KEYWORDS -DQT_PLUGIN -DQT_SHARED -pthread \
  -I. -I$QT -I$QT/QtCore -I$QT/QtGui -I$QT/QtPositioning -I$QT/QtPositioning/5.15.18 -I$QT/QtPositioning/5.15.18/QtPositioning \
  -I$QT/QtCore/5.15.18 -I$QT/QtCore/5.15.18/QtCore -I$QT/QtGui/5.15.18 \
  -I$S/include -I$S/include/lomiri-location-service-3 \
  core_geo_position_info_source.cpp core_geo_position_info_source_factory.cpp moc_source.cpp moc_factory.cpp qrc_position.cpp \
  -L$S/lib/aarch64-linux-gnu -Wl,-rpath-link,$S/lib/aarch64-linux-gnu \
  -llomiri-location-service -ldbus-cpp -lQt5Positioning -lQt5Gui -lQt5Core -lboost_filesystem \
  $(pkg-config --cflags --libs dbus-1) \
  -o libqtposition_lomiri.so
ls -l libqtposition_lomiri.so
