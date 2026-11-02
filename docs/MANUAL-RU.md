# «Классик»: Ubuntu 26.04 + Lomiri (Ubuntu Touch) на mainline-ядре для Samsung Galaxy M52 5G (m52xq) — полная инструкция

Версия документа: 2026-11-02. Последняя сборка: **классик в2** (2026-10-29).

## 1. Что это

- Устройство: Samsung Galaxy M52 5G, SM-M526B / SM-M526BR, Snapdragon 778G (SM7325, «yupik»), кодовое имя `m52xq`.
- Ядро: **mainline Linux 7.1.2**, сборка **#430** (boot v241 + vendor_boot v238) — без Halium, libhybris и Android HAL:
  Mir работает через `gbm-kms` и Mesa, звук ALSA/PipeWire, модем QMI через ModemManager.
- Система: настоящий корень **Ubuntu 26.04 LTS «resolute» arm64** (собран с нуля `debootstrap`) + **Lomiri 0.6.2** и приложения
  из репозитория **UBports `26.04-1.x`** (`http://repo.ubports.com`).
- Железо (ядро, прошивки, службы `m52xq-*`) — тот же слой, что у postmarketOS-портов
  ([samsung-m52xq-mainline](https://github.com/korryasdlerto-lgtm/samsung-m52xq-mainline),
  [samsung-m52xq-postmarketos-lomiri](https://github.com/korryasdlerto-lgtm/samsung-m52xq-postmarketos-lomiri)), перенесённый на Ubuntu.
- Личный любительский порт, проверен на одном SM-M526B.

Видео: https://www.youtube.com/watch?v=xJV4l0g4Kwc (Ubuntu Touch 26.04 на M52); возврат на Android: https://www.youtube.com/watch?v=0lgLbtdl4rA

## 2. Что работает (на 2026-10-29)

| Функция | Состояние | Примечание |
|---|---|---|
| Оболочка Lomiri, мастер первого запуска | работает | заставка Plymouth, экран блокировки с цифровой панелью |
| Экран, GPU у оболочки и приложений | работает | своя `libEGL_mesa` (Mesa 26.0.8, `bind-wayland-display`) — GPU-композитинг в приложениях (YouTube в Morph: 445 % → 30 % CPU) |
| Касания, клавиатура maliit | работает | |
| Автоповорот | работает | SSC через libssc (патч), iio-sensor-proxy |
| Две SIM, мобильный интернет | работает | ModemManager 1.25.95 + патчи DSDS 0100–0103 (`build/modemmanager`), индикатор SIM `m52xq-indicator-sim` |
| Звонки и SMS | работает (как в pmOS) | plasma-dialer и Spacebar из исходников KDE с патчами (2 SIM, звуки клавиш, ширина листа, постоянное уведомление); демоны — пользовательские службы `m52xq-*-daemon` |
| GPS в приложениях | работает | ModemManager GNSS → gpsd → lomiri-location-service; пересобран плагин Qt Positioning «lomiri» (`build/build-lls-plugin.sh`); разрешения GeoClue по приложениям (`m52xq-gps-perms`) |
| Wi-Fi, Bluetooth, BT-аудио | работает | адрес Bluetooth из EFS (`m52xq-bt-addr.py`), модуль PipeWire для BlueZ |
| Звук, звук при блокировке | работает | PipeWire; список `lifecycle-exempt-appids` (музыка не замолкает при блокировке) |
| Видео | работает | Venus в плеере Lomiri (свой GStreamer-плагин Qt6 `build/qt6-multimedia`); в браузерах Qt5 — на CPU |
| Камера | частично | `lomiri-camera-app` с патчами + `m52xqcamsrc`; см. ниже |
| OpenStore (click) | работает | click + заглушки `pkcon`, `aa-exec-click`, AppArmor-shim; `/home` и click-приложения на userdata |
| Приложения | работает | YouTube, uNav, Pure Maps (Qt5 `qmlscene` собран, PyOtherSide) |
| Фонарик, беззвучный режим, переходы в настройки из шторки | работает | |
| Сон | работает | короткое нажатие питания — блокировка; пробуждение по звонку/SMS |

Не сделано / известные проблемы: значки SIM в шторке через `lomiri-indicator-network` (у нас свой индикатор), камера стартует не всегда,
автояркость, изредка залипание тача Synaptics при гашении экрана, тихая запись звука, zram, Firefox (не установлен),
4K с фронтальной не играет в родном плеере (Qt5), плитки CARTO в uNav требуют ключ. `apply-fixes.sh` ещё не прогонялся на чистом образе.

## 3. Что нужно

Телефон — как для postmarketOS-портов: SM-M526B с разблокированным загрузчиком, TWRP
(https://github.com/saadelasfur/Action-Recovery-Builder/releases/tag/20261004173308), microSD, резервные копии EFS, persist, modem,
boot, vendor_boot, vbmeta. Компьютер для сборки — раздел 7.

## 4. Установка

### 4.1. Установочный zip (TWRP)
Архив `ubuntu-classic-26.04-m52xq-v2.zip`: 1 140 275 059 байт, md5 `dc2860e4481f0b247bb9863f82773a48`, образ внутри —
5 880 578 048 байт (md5 `0b3f52cb8c582086909512693b0bd225`), три чанка.
**Архив не публикуется:** его корень — снимок живой системы конкретного телефона (адрес Bluetooth, реестр датчиков, ssh-ключи, хеш пароля).
Для своего телефона соберите архив по разделам 7–9.

Шаги в TWRP — как в видео и как у postmarketOS-порта (Format Data → EXT4 → при желании UN1CA_3.1.0 → снова Format Data/EXT4 → Install):
```
Wipe - Format Data - yes - enter - Back - Back - Advanced Wipe - Data - Repair or Change File System - Change File System - EXT4 -
Swipe to Change - Back - Back - Back - Back - Back - Install - Select Storage - Micro SD card - ubuntu-classic-26.04-m52xq-v2.zip -
Swipe to confirm Flash - Reboot System
```
Установщик тот же, что у postmarketOS-порта (раздел 4 его инструкции): увеличивает `system` до 8 000 000 000 байт, склеивает
**три** чанка `samsung-m52xq.img.part-0…2` в `/dev/block/mapper/system`, пишет boot v241 и vendor_boot v238, берёт с телефона
адрес Bluetooth (EFS), прошивку модема и реестр датчиков (persist).

### 4.2. Проверка без прошивки: образ как `/data/rootfs.img`
Загрузчик (хук initramfs boot v233+) предпочитает `/data/rootfs.img`, если он есть:
```sh
# телефон в TWRP
adb push samsung-m52xq-classic.img /data/.rootfs.img.part
adb shell md5sum /data/.rootfs.img.part                 # сверить с .md5
adb shell 'mv /data/.rootfs.img.part /data/rootfs.img && sync'
# откат (в TWRP): mv /data/rootfs.img /data/rootfs.img.off — загрузится система из раздела system
```

### 4.3. Пароль и доступ
Пароль `user` и `root`, который ставит `apply-fixes.sh`: **1111** (`openssl passwd -6` + `chpasswd -e`; обычный `chpasswd`
не работает — `pam_extrausers` не знает YESCRYPT). Мастер Lomiri может поставить пустой пароль — тогда задайте свой так же.
Резерв shadow: `/etc/.m52xq-shadow-backup` (служба `m52xq-password-restore`).
Доступ по USB: `ssh user@172.16.42.1`.

## 5. Возврат на Android
Видео: https://www.youtube.com/watch?v=0lgLbtdl4rA — шаги как у postmarketOS-порта (Format Data → EXT4 → LineageOS 23.2 → Format Data → Reboot).
Сток — через Odin (BL, AP, CP, CSC).

## 6. Ядро

Релиз [kernel-7.1.2-430](../../releases/tag/kernel-7.1.2-430) этого репозитория: `boot_v241_nfc.img` (md5 `f89bec95…`),
`vendor_boot_v238_nfc_se9.img` (md5 `e1fb7dd3…`), `Image`, `config-7.1.2-430`, `modules-7.1.2-430.tar.gz`
(раскладка Ubuntu `usr/lib/modules/7.1.2/…`: `ath11k_ahb.ko`, `extra/v4l2loopback.ko`, `extra/venus/*` — грузит `m52xq-venus-load`), `SHA256SUMS`.
Модули — ровно те, что в образе классик в2. `MODVERSIONS` выключен: ставить только вместе с этим boot.
Исходники ядра: [sc7280-mainline-linux-m52xq](https://github.com/korryasdlerto-lgtm/sc7280-mainline-linux-m52xq).

## 7. Сборка с нуля: корень Ubuntu 26.04 + Lomiri

Полные команды с выводом — `docs/ИНСТРУКЦИЯ.md` (разделы 1–9, 12.10, 15), все правки по пунктам — `docs/ПРАВКИ.md` (≈ 150 пунктов).
Скрипты — в `image/`.

Хост: Ubuntu 20.04 x86_64, sudo, ≥ 20 ГБ, интернет:
```sh
sudo apt install debootstrap qemu-user-static binfmt-support gdisk rsync e2fsprogs curl openssl zip unzip util-linux
ls /proc/sys/fs/binfmt_misc/ | grep qemu-aarch64          # должен быть
```

1. **Базовый корень** — `image/build-01-resolute.sh`: debootstrap хоста 20.04 не знает resolute и ломается на `/bin → usr/bin`,
   поэтому берётся **свежий debootstrap 1.0.144** из архива Ubuntu и распаковывается рядом (система хоста не меняется); первая и вторая
   стадия под qemu. `/etc/apt/sources.list`: main restricted universe multiverse + updates + security.
2. **chroot** — `image/chroot-config.sh`, `image/chroot-run.sh` (монтирование proc/sys/dev, resolv.conf, policy-rc.d).
3. **Lomiri из UBports**: `/etc/apt/sources.list.d/ubports.sources` (`http://repo.ubports.com`, набор `26.04-1.x`) и
   `/etc/apt/preferences.d/ubports.pref` (приоритет UBports для своих пакетов); `apt install lomiri …` (`image/rootfs-ubports.sh`).
4. **Пустой образ GPT с теми же UUID** — `image/build-03-image.sh`: сектор 4096, p1 `pmOS_boot`, p2 `pmOS_root`
   (UUID p2 `27c97050-ff55-4e42-b894-0f866eb5ad1f`), копия корня.
5. **Слой железа m52xq** — `image/build-04-hardware.sh`: из образа postmarketOS-Lomiri v3 (только чтение,
   `losetup --sector-size 4096`) копируются `lib/modules` → `usr/lib/modules`, `lib/firmware` → `usr/lib/firmware`, `/usr/local`,
   udev-правила, юниты systemd, хуки сна, конфиги NM, UCM звука, `/usr/share/qcom` (реестр датчиков — личные данные, в репозиторий не входит).
6. **Правки этапа в2** — `apply-fixes.sh`:
   ```sh
   L=$(sudo losetup -f --show -b 4096 -P samsung-m52xq-classic.img); sudo mount ${L}p2 mnt-new
   sudo ./apply-fixes.sh $PWD/mnt-new     # rootfs-overlay (владелец root), .deb через chroot dpkg -i, пароль, группы, locale-gen, флаги
   sync; sudo umount mnt-new; sudo losetup -d $L; md5sum samsung-m52xq-classic.img
   ```
   Пакеты `.deb` для dpkg (`debs*`) собираются из `build/` (раздел 9) или скачиваются из Ubuntu/UBports — сами `.deb` в репозиторий не входят.

## 8. Состав репозитория

| Папка | Что внутри |
|---|---|
| `installer/META-INF` | установщик TWRP (три чанка), баннер «classic v2» |
| `rootfs-overlay/` | все файлы этапа в2 поверх корня (скрипты, службы, QML, конфиги, Plymouth); двоичные — в `EXCLUDED-FILES.txt` с md5 |
| `apply-fixes.sh` | накладывает оверлей и пакеты на смонтированный образ |
| `image/` | сценарии сборки корня и образа (`build-01…04`, chroot, UBports, заливка на телефон) |
| `build/` | исходники, патчи и сценарии каждой пересобранной программы (раздел 9) |
| `docs/` | эта инструкция (RU/EN), `ИНСТРУКЦИЯ.md` (все команды по шагам), `ПРАВКИ.md` (журнал правок) |

## 9. Пересобранные программы (`build/`)

| Папка | Что и зачем |
|---|---|
| `mesa` | `libEGL_mesa` 26.0.8 с `-Dlegacy-wayland=bind-wayland-display` — GPU в приложениях Lomiri (VERSION = полная версия пакета) |
| `modemmanager` | ModemManager 1.25.95 + патчи 0100–0103: основной слот и 2G-пути SIM, второй модем-объект для SIM 2, выбор SIM для данных, нефатальный attach SIM 2 |
| `plasma-dialer`, `spacebar` | звонилка и SMS из исходников KDE для Ubuntu: 2 SIM, звуки клавиш (canberra, настройка Lomiri), ширина листа, постоянное уведомление, отметка прочитанного |
| `libcamera`, `lomiri-camera-app`, `m52xqcamsrc` | камера: soft-ISP патчи, фокус по касанию, видео 4K, 16 Мп с биннингом, оверлей настроек; GStreamer-источник с Venus |
| `qt6-multimedia` | GStreamer-бэкенд Qt6 Multimedia (в Ubuntu 26.04 его нет) — Venus-видео в плеере Lomiri |
| `qmlscene5` | `qmlscene` Qt5 (в 26.04 не поставляется) — для YouTube/uNav/Pure Maps из OpenStore |
| `build-lls-plugin.sh` | плагин Qt Positioning «lomiri» (lomiri-location-service) — GPS в приложениях |
| `build-cellular-plugin.sh`, `cellular` | модуль «Сотовая связь» настроек под ModemManager |
| `indicator-bluetooth` | `0001-phone-paired-devices.patch` — сопряжённые устройства в индикаторе |
| `sensors` | `libssc-m52xq-0003-proximity-report-dump.patch` (+ исходники libssc 0.4.4, iio-sensor-proxy 3.9) |
| `aa-shim`, `settings-stub`, `src/noprops.c` | заглушки AppArmor для click, настроек, Android-свойств |

## 10. Службы и скрипты

| Служба / скрипт | Назначение |
|---|---|
| `m52xq-userdata-dirs` | каталоги `/home` и `/opt/click.ubuntu.com` на разделе userdata |
| `m52xq-click-desktops` | ярлыки click-приложений в каталог, который читает Lomiri |
| `m52xq-modem-setup` | сессия SIM и включение GNSS-движка модема |
| `m52xq-gnss-gpsd`, `m52xq-gps*`, `m52xq-gps-perms` | GNSS → gpsd, разрешения на геопозицию по приложениям (GeoClue) |
| `m52xq-indicator-sim` (пользовательская) | индикатор SIM-карт для панели и шторки |
| `m52xq-modem-daemon`, `m52xq-kde-telephony-daemon`, `m52xq-spacebar-daemon` (пользовательские) | демоны звонилки и SMS в сеансе Lomiri (XDG-автозапуск в Lomiri не срабатывает) |
| `m52xq-incall-proximity` | гашение экрана и блок касаний у уха |
| `m52xq-sim-slots`, `m52xq-sim-mode`, `m52xq-sim-mode-menu` | слоты SIM по ICCID, режим SIM |
| `m52xq-powerkey`, `m52xq-reboot-recovery`, `m52xq-flight-mode` | кнопка питания, меню перезагрузки в recovery, режим полёта |
| `m52xq-plymouth-fallback` | закрыть Plymouth, если greeter этого не сделал |
| `pkcon`, `aa-exec-click` | заглушки для установки click-пакетов OpenStore |
| `m52xq-unav-tiles` | источник плиток для uNav |

## 11. Ловушки (коротко)

- Большая часть бинарников из postmarketOS — musl и на Ubuntu не грузится: всё железное пересобирается под glibc.
- Ubuntu 26.04 не поставляет Qt5 `qmlscene`, `pkcon`, PackageKit-click, GStreamer-плагин Qt6, плагин позиции lomiri — собраны сами.
- Не ставить на телефон dev-пакеты UBports: понижают systemd/libc.
- `losetup` — всегда `--sector-size 4096`; zip — изнутри папки архива.
- `pkill -f` в ssh-команде убивает свою сессию.
- Правка ярлыков в `/custom/xdg/data/applications` вызывает мерцание Lomiri — не переписывать неизменённые файлы.

## 12. Благодарности
Ubuntu, UBports и Lomiri; postmarketOS; KDE (plasma-dialer, Spacebar); разработчикам mainline Linux для Qualcomm SC7280/QCM6490.
