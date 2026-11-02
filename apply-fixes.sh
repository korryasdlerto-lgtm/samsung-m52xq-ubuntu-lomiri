#!/bin/bash
# Применить правки в2 к смонтированному rw корню образа классик: ./apply-fixes.sh /путь/к/корню
set -e
R="$1"; [ -d "$R/etc" ] || { echo "укажите корень образа"; exit 1; }
cp -a --no-preserve=ownership "$(dirname "$0")/rootfs-files/." "$R/"
# владельцы: всё скопированное — root (иначе sudo/systemd ругаются: «/etc/sudoers.d is owned by uid …»)
chown -R root:root "$R/etc" "$R/usr/local" "$R/usr/share/fonts/truetype/droid-nonlatin" 2>/dev/null || true
chmod 440 "$R/etc/sudoers.d/"* 2>/dev/null || true
chmod 755 "$R/usr/local/sbin/m52xq-powerkey" "$R/usr/local/lib/libm52xq-noprops.so" 2>/dev/null || true
H=$(openssl passwd -6 -salt KTNqVOH.JQAIbJ.r 1111)
for u in root user; do
  awk -F: -v OFS=: -v u="$u" -v h="$H" '$1==u{$2=h}1' "$R/etc/shadow" > "$R/etc/shadow.new"
  cat "$R/etc/shadow.new" > "$R/etc/shadow"; rm "$R/etc/shadow.new"
done
chown root:root "$R/var/lib/extrausers"; chmod 755 "$R/var/lib/extrausers"
echo "в2 применено к $R"
# при загрузке shadow возвращается из shadow.m52xq.bak — обновить и копию
if [ -f "$R/etc/shadow.m52xq.bak" ]; then cat "$R/etc/shadow" > "$R/etc/shadow.m52xq.bak"; echo "обновлён shadow.m52xq.bak"; fi
# корень образа принадлежал uid 1000 (ломало systemd-tmpfiles: "unsafe path transition")
chown root:root "$R"; chmod 755 "$R"
# драйверы графики Mir 1 (без них Lomiri не стартует: нет /usr/lib/aarch64-linux-gnu/mir1/server-platform)
# пакеты (Mir 1, приложения Lomiri, мастер настройки, click) ставим настоящим dpkg внутри образа (через qemu-binfmt)
D="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$R/var/tmp/m52xq-debs"
cp "$D"/debs/*.deb "$D"/debs-apps/*.deb "$D"/debs-fonts/*.deb "$D"/debs-plymouth/*.deb "$D"/debs-keyboard/*.deb "$D"/debs-indicators/*.deb "$D"/debs-qml/*.deb "$D"/debs-time/*.deb "$D"/debs-qt6/*.deb "$D"/debs-sensors/*.deb "$R/var/tmp/m52xq-debs/"
mount -t proc proc "$R/proc"; mount --bind /dev "$R/dev"
chroot "$R" sh -c 'cd /var/tmp/m52xq-debs && dpkg -i --auto-deconfigure --skip-same-version *.deb' || echo "dpkg: были ошибки"
umount "$R/dev" "$R/proc"
rm -rf "$R/var/tmp/m52xq-debs"
# группа nopasswdlogin ДОЛЖНА остаться без членов: Lomiri CanLock() запрещает блокировку её членам (короткое нажатие питания не блокировало экран)
grep -q '^nopasswdlogin:' "$R/etc/group" || echo 'nopasswdlogin:x:107:' >> "$R/etc/group"
true  # (группа остаётся пустой: члены не могут блокировать экран)
grep -q '^nopasswdlogin:' "$R/etc/gshadow" || echo 'nopasswdlogin:!::' >> "$R/etc/gshadow"
# пакет libhybris (тянется веб-движком) ставит GLVND-вендор 10_libhybris.json — он перебивает Mesa и ломает Mir («Failed to find platform»). Отключаем.
[ -f "$R/usr/share/glvnd/egl_vendor.d/10_libhybris.json" ] && mv "$R/usr/share/glvnd/egl_vendor.d/10_libhybris.json" "$R/usr/share/glvnd/egl_vendor.d/10_libhybris.json.off"
# флаг «мастер уже пройден» лежал в образе (дата сборки) → мастер первой настройки не показывался
rm -f "$R/home/user/.config/lomiri/wizard-has-run"
# локали из /etc/locale.gen (список языков мастера берётся из `locale -a`)
chroot "$R" locale-gen
# старые Ubuntu-индикаторы (indicator-datetime и др.) конфликтуют с ayatana-*: у них та же схема gsettings (enum time-enum) → новая схема отклоняется, Lomiri падает (ABRT)
for f in "$R"/usr/share/glib-2.0/schemas/com.canonical.indicator.datetime.gschema.xml; do [ -f "$f" ] && mv "$f" "$f.off"; done
chroot "$R" glib-compile-schemas /usr/share/glib-2.0/schemas
ln -sfn ../m52xq-click-desktops.service "$R/etc/systemd/system/multi-user.target.wants/m52xq-click-desktops.service"
# приложения запускаются через m52xq-app-env (GRID_UNIT_PX, LANG, wayland-egl, EGL_PLATFORM=wayland, без DISPLAY — иначе Mesa берёт x11 и в приложениях нет клавиатуры):
# перекрытие .desktop в первом каталоге XDG_DATA_DIRS (/custom/xdg/data)
install -d -m755 "$R/custom/xdg/data/applications"
for f in "$R"/usr/share/applications/lomiri-*-app.desktop "$R"/usr/share/applications/morph-browser.desktop "$R"/usr/share/applications/m52xq-reboot-recovery.desktop "$R"/usr/share/applications/m52xq-sim-mode.desktop; do
  [ -f "$f" ] || continue
  sed -E "s#^Exec=(/usr/local/bin/m52xq-app-env )?#Exec=/usr/local/bin/m52xq-app-env #" "$f" > "$R/custom/xdg/data/applications/$(basename "$f")"
done
# у Галереи, Камеры, Barcode Reader, Менеджера файлов значок задан именем (Icon=lomiri-gallery-app), тема его не находит (пустые значки в списке
# приложений) → полный путь к картинке
for n in lomiri-gallery-app lomiri-camera-app lomiri-barcode-reader-app lomiri-filemanager-app; do
  f="$R/custom/xdg/data/applications/$n.desktop"; [ -f "$f" ] || continue
  i=/usr/share/icons/hicolor/128x128/apps/$n.png; [ -f "$R$i" ] || i=/usr/share/icons/hicolor/scalable/apps/$n.svg
  sed -i -E "s#^Icon=$n\$#Icon=$i#" "$f"
done
# лишние пункты в списке приложений (настройки X-ввода и отладки, не нужные в Lomiri): NoDisplay=true в перекрытии
for n in kasumi activity-log-manager unity-activity-log-manager-panel org.freedesktop.IBus.Setup; do
  f="$R/usr/share/applications/$n.desktop"; [ -f "$f" ] || continue
  sed -E '/^NoDisplay=/d; /^\[Desktop Entry\]/a NoDisplay=true' "$f" > "$R/custom/xdg/data/applications/$n.desktop"
done
# Lomiri-«Телефон» и «Сообщения» без oFono не работают; вместо них plasma-dialer и spacebar (ярлыки в custom/xdg/data/applications): скрыть родные
for n in lomiri-dialer-app lomiri-messaging-app; do
  f="$R/custom/xdg/data/applications/$n.desktop"; [ -f "$f" ] && sed -i -e '/^NoDisplay=/d' -e '/^\[Desktop Entry\]/a NoDisplay=true' "$f"
done
ln -sfn ../m52xq-sim-slots.service "$R/etc/systemd/system/multi-user.target.wants/m52xq-sim-slots.service"
# polkit: только 50-m52xq-sim-mode.rules (разрешено пользователем 2026-10-27; hotspot/nfc не применялись)
install -d -m755 "$R/etc/polkit-1/rules.d"; install -m644 "$D/rootfs-files/etc/polkit-1/rules.d/50-m52xq-sim-mode.rules" "$R/etc/polkit-1/rules.d/"
# время: systemd-timesyncd 259.5 (из Ubuntu, версия = systemd; в UBports версия 255.4 — НЕ брать) ; без NTP часы шли с 1970/апреля → «сертификат ещё не действителен» в Morph
ln -sfn /usr/lib/systemd/system/systemd-timesyncd.service "$R/etc/systemd/system/sysinit.target.wants/systemd-timesyncd.service" 2>/dev/null || true
# gsettings-override (обои с котом, значок лаунчера, фон приветствия) нужно скомпилировать
chroot "$R" glib-compile-schemas /usr/share/glib-2.0/schemas
ln -sfn ../m52xq-click-desktops.service "$R/etc/systemd/system/multi-user.target.wants/m52xq-click-desktops.service"
# пароль: ramdisk при КАЖДОЙ загрузке перезаписывает /etc/shadow старой копией («m52xq»), а свою копию кладёт в shadow.m52xq.bak.
# Обход из pmOS: backup.path копирует изменённый shadow в /etc/.m52xq-shadow-backup, restore.service (sysinit) возвращает его после ramdisk.
cp -a "$R/etc/shadow" "$R/etc/.m52xq-shadow-backup"
ln -sfn ../m52xq-password-restore.service "$R/etc/systemd/system/sysinit.target.wants/m52xq-password-restore.service"
ln -sfn ../m52xq-password-backup.path "$R/etc/systemd/system/multi-user.target.wants/m52xq-password-backup.path"
# датчики (автоповорот): права и udev
chmod 755 "$R/usr/bin/ssccli" "$R/usr/local/libexec/iio-sensor-proxy"
chroot "$R" ldconfig 2>/dev/null || true
# реестр датчиков (калибровка именно этого телефона, из его раздела persist): hexagonrpcd работает от пользователя fastrpc и пишет туда
chroot "$R" chown -R fastrpc:fastrpc /usr/share/qcom/sm7325/Samsung/m52xq/sensors/registry
chmod 755 "$R/usr/share/qcom/sm7325/Samsung/m52xq/sensors/registry"; chmod 600 "$R"/usr/share/qcom/sm7325/Samsung/m52xq/sensors/registry/*
# персональные данные ЭТОГО телефона (адрес Bluetooth из EFS, per-phone/ — не публиковать): hci_uart_qca держит заглушку 00:00:00:00:5A:AD → контроллер «unconfigured», включение даёт «Invalid Index»
install -d -m755 "$R/etc/m52xq"; install -m644 "$D/per-phone/etc/m52xq/bt_addr" "$R/etc/m52xq/bt_addr"
ln -sfn ../m52xq-bt-firmware.service "$R/etc/systemd/system/multi-user.target.wants/m52xq-bt-firmware.service"

# ===== 2026-10-28 (п. 98–125 ПРАВКИ.md): всё, что делалось на живом телефоне и не прогонялось на чистом образе =====
# Пакеты из репозитория (нужны сеть и qemu в chroot; на телефоне apt -s показывал только новые пакеты/обновление python3.14):
#   Qt5 Multimedia (звуки уведомлений, Галерея), Qt6-модуль Lomiri.Action (lomiri-mediaplayer-app), PyOtherSide (Pure Maps),
#   инструменты GStreamer/V4L2, qmicli для SIM/GNSS, gpsd, индикатор расположения (пункт «Расположение» в Настройках)
chroot "$R" sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y libqt5multimedia5-plugins qml6-module-lomiri-action qml-module-io-thp-pyotherside gstreamer1.0-tools v4l-utils libqmi-utils gpsd gpsd-tools lomiri-indicator-location' || echo "apt: были ошибки"
chroot "$R" systemctl disable gpsd.socket gpsd.service 2>/dev/null || true   # свой gpsd запускает мост m52xq-gnss-gpsd
# ModemManager 1.25.95 + патчи pmOS 0100–0103 (две SIM), собран в build-modemmanager/ (при обновлении Ubuntu-версии пересобрать)
cp "$D"/debs-modemmanager/*.deb "$R/var/tmp/m52xq-debs/" && chroot "$R" sh -c 'cd /var/tmp/m52xq-debs && dpkg -i libmm-glib0_*+m52xq1_*.deb gir1.2-modemmanager-1.0_*+m52xq1_*.deb modemmanager_*+m52xq1_*.deb' || echo "dpkg modemmanager: были ошибки"
# click: lomiri-app-launch вызывает /usr/bin/aa-exec и aa-clickhook (AppArmor в ядре нет) -> заглушки через dpkg-divert (п. 112, 118)
for t in aa-exec aa-clickhook; do
  chroot "$R" dpkg-divert --local --rename --divert /usr/bin/$t.real --add /usr/bin/$t
  install -m755 "$D/rootfs-files/usr/local/lib/m52xq-click/$t" "$R/usr/bin/$t"
done
chmod 755 "$R/usr/local/bin/pkcon" "$R/usr/local/bin/aa-exec-click" "$R/usr/local/sbin/m52xq-click-desktops" "$R/usr/local/sbin/m52xq-userdata-dirs" "$R/usr/local/sbin/m52xq-unav-tiles" "$R/usr/local/lib/m52xq-click/aa-exec" "$R/usr/lib/qt5/bin/qmlscene" 2>/dev/null || true
chown -R root:root "$R/usr/lib/qt5" "$R/usr/lib/aarch64-linux-gnu/qt5/plugins/position" "$R/usr/lib/aarch64-linux-gnu/qt6/plugins/multimedia" 2>/dev/null || true
# службы при загрузке: /home и /opt/click на userdata (п. 111), ярлыки click-приложений (п. 112/116), GPS и модем (п. 109/122), датчики (п. 110)
for u in m52xq-userdata-dirs.service home.mount opt-click.ubuntu.com.mount; do ln -sfn ../$u "$R/etc/systemd/system/local-fs.target.wants/$u"; done
for u in m52xq-click-desktops.path m52xq-gnss-gpsd.service m52xq-gps-perms.service m52xq-modem-setup.service; do ln -sfn ../$u "$R/etc/systemd/system/multi-user.target.wants/$u"; done
ln -sfn /usr/lib/systemd/system/iio-sensor-proxy.service "$R/etc/systemd/system/multi-user.target.wants/iio-sensor-proxy.service"
# режим SIM как в pmOS: обе SIM активны, мобильные данные через SIM2
install -d -m755 "$R/etc/m52xq"; echo dsds > "$R/etc/m52xq/sim-mode"; echo 2 > "$R/etc/m52xq/data-sim"
# ПРИ ПЕРВОЙ ЗАГРУЗКЕ ВРУЧНУЮ/СКРИПТОМ С САМОГО ТЕЛЕФОНА (личные данные, в образ не вшиваются): прошивка модема —
#   mount -o ro,nosuid,nodev,noexec /dev/sda18 /mnt && cp -a /mnt/image/modem* /lib/firmware/ && umount /mnt   (п. 109)
# Приложения из OpenStore (в образ не вшиваются): после установки uNav — /usr/local/sbin/m52xq-unav-tiles (плитки OSM вместо CARTO, п. 125);
#   lifecycle-exempt-appids для звуковых приложений — в 99-m52xq-lomiri.gschema.override (п. 98, 117)
chroot "$R" glib-compile-schemas /usr/share/glib-2.0/schemas
ln -sfn ../m52xq-click-desktops.service "$R/etc/systemd/system/multi-user.target.wants/m52xq-click-desktops.service"

# звонилка и SMS «как в pmOS»: plasma-dialer (с патчем выбора SIM, debs-plasma-dialer/, 1:6.6.4-0ubuntu1+m52xq1) + spacebar + драйвер SQLite; демоны — XDG-автозапуск (user-systemd generator)
chroot "$R" sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends spacebar plasma-dialer libqt6sql6-sqlite' || echo "apt звонилка: были ошибки"
cp "$D"/debs-plasma-dialer/*+m52xq4_*.deb "$D"/debs-spacebar/*+m52xq2_*.deb "$R/var/tmp/m52xq-debs/" && chroot "$R" sh -c 'dpkg -i /var/tmp/m52xq-debs/plasma-dialer_*+m52xq4_*.deb /var/tmp/m52xq-debs/spacebar_*+m52xq2_*.deb' || echo "dpkg plasma-dialer/spacebar: были ошибки"
# камера: libcamera 0.7 + пересобранная lomiri-camera-app (п. 142); m52xq-virtualcam НЕ включать (п. 141)
chroot "$R" sh -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gstreamer1.0-libcamera libcamera-tools' || echo "apt libcamera: были ошибки"
# libcamera 0.7.2 с патчами pmOS (remosaic 16/64 Мп, п. 143) поверх пакетов Ubuntu 0.7.0
cp "$D"/debs-libcamera/*.deb "$R/var/tmp/m52xq-debs/" && chroot "$R" sh -c 'dpkg -i /var/tmp/m52xq-debs/libcamera0.7_*m52xq1_*.deb /var/tmp/m52xq-debs/libcamera-ipa_*m52xq1_*.deb /var/tmp/m52xq-debs/gstreamer1.0-libcamera_*m52xq1_*.deb && apt-mark hold libcamera0.7 libcamera-ipa gstreamer1.0-libcamera' || echo "dpkg libcamera: были ошибки"
mkdir -p "$R/etc/tmpfiles.d"; printf 'w /sys/module/udmabuf/parameters/size_limit_mb - - - - 512\n' > "$R/etc/tmpfiles.d/m52xq-udmabuf.conf"
cp "$D"/debs-lomiri-camera-app/*+m52xq3_*.deb "$R/var/tmp/m52xq-debs/" && chroot "$R" sh -c 'dpkg -i /var/tmp/m52xq-debs/lomiri-camera-app_*+m52xq3_*.deb && apt-mark hold lomiri-camera-app' || echo "dpkg lomiri-camera-app: были ошибки"
# Venus (аппаратный видеокодек): параметр защищённого PERSIST-буфера при автозагрузке модулей (п. 148)
mkdir -p "$R/etc/modprobe.d"; cp "$D/rootfs-files/etc/modprobe.d/m52xq-venus.conf" "$R/etc/modprobe.d/"
# индикатор SIM для шторки (читает ModemManager): юнит включается в lomiri-indicators.target
chmod 755 "$R/usr/local/sbin/m52xq-indicator-sim"
# экран гаснет у уха во время звонка + звонилка поверх блокировки (п. 134, 137)
ln -sfn ../m52xq-incall-proximity.service "$R/etc/systemd/system/multi-user.target.wants/m52xq-incall-proximity.service"
chmod 755 "$R/usr/local/bin/m52xq-incall-proximity"
chroot "$R" glib-compile-schemas /usr/share/glib-2.0/schemas || true
ln -sfn ../m52xq-click-desktops.service "$R/etc/systemd/system/multi-user.target.wants/m52xq-click-desktops.service"

# NetworkManager: профиль мобильного интернета SIM2 из pmOS (type=gsm, interface-name=qrtr0-sim2, apn=internet); файл только для root (0600)
chmod 600 "$R/etc/NetworkManager/system-connections/m52xq-mobile-internet.nmconnection" 2>/dev/null || true
