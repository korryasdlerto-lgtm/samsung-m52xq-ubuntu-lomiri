#!/bin/sh
# Страница «Мобильная сеть» (settings:///system/cellular) для Lomiri System Settings 1.5.0 на ModemManager/NetworkManager: плагин из pmOS
# (в3/build-cellular: cellular-plugin.{h,cpp}, cellular.settings, PageComponent.qml, backend/ — QML-модуль Lomiri.SystemSettings.M52xqCellular
# на QProcess: m52xq-sim-mode, nmcli, mmcli). Под Ubuntu: заголовки LomiriSystemSettings из исходников lomiri-system-settings 1.5.0
# (lib/LomiriSystemSettings/ -> /build-cell/inc-LomiriSystemSettings), библиотека libLomiriSystemSettings.so.1 — с телефона. Использование:
#   sudo chroot mesa-build-root2 sh /build-cell/build.sh
set -e
cd /build-cell
mkdir -p inc/LomiriSystemSettings && cp inc-LomiriSystemSettings/* inc/LomiriSystemSettings/
QT=/usr/include/aarch64-linux-gnu/qt5
MOC=/usr/lib/qt5/bin/moc
MI="-DQT_NO_KEYWORDS -DQT_PLUGIN -DQT_SHARED -I/build-cell/inc -I$QT -I$QT/QtCore -I$QT/QtQml -I$QT/QtQuick -I$QT/QtGui -I$QT/QtNetwork"
CFL="-std=c++17 -O2 -fPIC $MI"
cd cellular
$MOC $MI cellular-plugin.h -o moc_cellular-plugin.cpp
$MOC $MI cellular-plugin.cpp -o cellular-plugin.moc
g++ $CFL -DPLUGIN_QML_DIR='"/usr/share/lomiri-system-settings/qml-plugins"' -I. -shared cellular-plugin.cpp moc_cellular-plugin.cpp -o /build-cell/libcellular-plugin.so \
  -L/build-cell/lib -lLomiriSystemSettings -lQt5Qml -lQt5Core -lQt5Gui
cd backend
$MOC $MI mobile.h -o moc_mobile.cpp
$MOC $MI plugin.h -o moc_plugin.cpp
g++ $CFL -shared plugin.cpp mobile.cpp moc_mobile.cpp moc_plugin.cpp -o /build-cell/libM52xqCellularBackend.so -lQt5Quick -lQt5Qml -lQt5Core
ls -l /build-cell/*.so
