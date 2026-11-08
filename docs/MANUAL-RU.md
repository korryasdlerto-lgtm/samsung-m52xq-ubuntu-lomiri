# «Классик»: Ubuntu 26.04 + Lomiri (Ubuntu Touch) на mainline-ядре для Samsung Galaxy M52 5G (m52xq) — полная инструкция

Версия документа: 2026-11-09. Последний релиз: **unofficial v1** (2026-11-09); изменения: [CHANGES-v1-RU.md](CHANGES-v1-RU.md).

## 1. Что это

- Устройство: Samsung Galaxy M52 5G, SM-M526B / SM-M526BR, Snapdragon 778G (SM7325, «yupik»), кодовое имя `m52xq`.
- Ядро: **mainline Linux 7.1.13** с патчами устройства (раздел 6) — без Halium, libhybris и Android HAL:
  Mir работает через `gbm-kms` и Mesa, звук ALSA/PipeWire, модем QMI через ModemManager.
- Система: настоящий корень **Ubuntu 26.04 LTS «resolute» arm64** (собран с нуля `debootstrap`) + **Lomiri 0.6.2** и приложения
  из репозитория **UBports `26.04-1.x`** (`http://repo.ubports.com`).
- Железо (ядро, прошивки, службы `m52xq-*`) — тот же слой, что у postmarketOS-портов
  ([samsung-m52xq-mainline](https://github.com/korryasdlerto-lgtm/samsung-m52xq-mainline),
  [samsung-m52xq-postmarketos-lomiri](https://github.com/korryasdlerto-lgtm/samsung-m52xq-postmarketos-lomiri)), перенесённый на Ubuntu.
- Личный любительский порт, проверен на одном SM-M526B.

Видео: https://www.youtube.com/watch?v=xJV4l0g4Kwc (установка); возврат на Android: https://www.youtube.com/watch?v=0lgLbtdl4rA&t=89s

## 2. Что работает (релиз unofficial v1, 2026-11-09)

| Функция | Состояние | Примечание |
|---|---|---|
| Оболочка Lomiri, мастер первого запуска | работает | заставка Plymouth, экран блокировки с цифровой панелью; язык из мастера применяется к оболочке, шторке и всем приложениям |
| Экран, GPU у оболочки и приложений | работает | своя `libEGL_mesa` (Mesa 26.0.8, `bind-wayland-display`) — GPU-композитинг в приложениях (YouTube в Morph: 445 % → 30 % CPU) |
| Касания, клавиатура maliit | работает | |
| Автоповорот | работает | SSC через libssc (патч), iio-sensor-proxy |
| Две SIM, мобильный интернет | работает | ModemManager 1.25.95 + патчи DSDS 0100–0103 (`build/modemmanager`), индикатор SIM `m52xq-indicator-sim` |
| Звонки и SMS | работает | plasma-dialer и Spacebar из исходников KDE с патчами (2 SIM, звуки клавиш, USSD, сброс громкой/микрофона, «Добавить контакт»); демоны — пользовательские службы `m52xq-*-daemon`; переключение громкая/разговорный на месте (ядро); полоска звонка со временем и именем; контакты общие с адресной книгой Lomiri |
| GPS в приложениях | работает | ModemManager GNSS → gpsd → lomiri-location-service; пересобран плагин Qt Positioning «lomiri» (`build/build-lls-plugin.sh`); разрешения GeoClue по приложениям (`m52xq-gps-perms`) |
| Wi-Fi, Bluetooth, BT-аудио | работает | адрес Bluetooth из EFS (`m52xq-bt-addr.py`), модуль PipeWire для BlueZ |
| Звук, звук при блокировке | работает | PipeWire; список `lifecycle-exempt-appids` (музыка не замолкает при блокировке) |
| Видео | работает | Venus в плеере Lomiri (свой GStreamer-плагин Qt6 `build/qt6-multimedia`); в браузерах Qt5 — на CPU |
| Камера | работает, частично | `lomiri-camera-app` с патчами + `m52xqcamsrc`: основная и фронтальная, фото 64 Мп, цифровой зум до 4x, видео через Venus; не все объективы и режимы |
| OpenStore (click) | работает | click + заглушки `pkcon`, `aa-exec-click`, AppArmor-shim; `/home` и click-приложения на userdata |
| Приложения | работает | YouTube, uNav, Pure Maps (Qt5 `qmlscene` собран, PyOtherSide), TELEports (`libssl1.1` + QML-модуль push-уведомлений) |
| Будильник | работает | `lomiri-indicator-datetime`, будит телефон из сна через RTC |
| zram | работает | сжатая подкачка 3 ГБ (`m52xq-zram`) |
| Фонарик, беззвучный режим, переходы в настройки из шторки | работает | |
| Сон | работает | короткое нажатие питания — блокировка; пробуждение по звонку, SMS и будильнику; при пробуждениях по сети экран остаётся тёмным; прошивка Wi-Fi спит при выключенном Wi-Fi |

Не работает: сканер отпечатков, VoLTE (звонки через 2G/3G).

Известные проблемы: после поворота из портретной в альбомную правая половина клавиатуры иногда не реагирует (скрыть клавиатуру
и снова нажать на поле ввода; в мастере пароль Wi-Fi удобнее вводить в портретной); в TELEports нет звонков Telegram; шторка
до первой перезагрузки после мастера может показывать часть форматов на английском; видео в браузере декодируется на CPU;
автояркость; плитки CARTO в uNav требуют ключ.

## 3. Что нужно

Телефон — как для postmarketOS-портов: SM-M526B с разблокированным загрузчиком, TWRP
(https://github.com/saadelasfur/Action-Recovery-Builder/releases/tag/20261004173308), microSD, резервные копии EFS, persist, modem,
boot, vendor_boot, vbmeta. Компьютер для сборки — раздел 7.

## 4. Установка

### 4.1. Установочный zip (TWRP)
Архив [ubuntu_touch_classic_26.04-m52xq-mainline-v1-UNOFFICIAL.zip](https://drive.google.com/file/d/1Z9dCERDZID4DJXgfY4CrCK9k98HZdGAa/view?usp=sharing):
1 085 618 664 байт, md5 `a3343884846751530f4a590e23e9275e`; образ корня внутри разбит на два чанка. В нём нет личных данных,
ключей SSH и закрытых прошивок.

Телефон при установке греется; если на экране уже есть вертикальные цветные полосы, не устанавливайте. Для максимального
размера раздела system сначала прошейте UN1CA_3.1.0 (после LineageOS 23 он на 1 ГБ меньше, установка всё равно проходит).

Шаги в TWRP (как в видео):
```
Wipe - Format Data - yes - enter - Back - Back - Advanced Wipe - Data - Repair or Change File System - Change File System - EXT4 -
Swipe to Change - Back - Back - Back - Back - Back - Install - Select Storage - Micro SD card - ubuntu_touch_classic_26.04-m52xq-mainline-v1-UNOFFICIAL.zip -
Swipe to confirm Flash - Reboot System
```
Установщик тот же, что у postmarketOS-порта: увеличивает `system` до 8 000 000 000 байт, склеивает два чанка
`samsung-m52xq.img.part-0…1` в `/dev/block/mapper/system`, пишет boot, vendor_boot и dtbo (`dtbo-frag`), добавляет прошивку IPA
телефона в ramdisk boot и копирует с телефона (только чтение): ADSP, zap-шейдер GPU, IPA и Venus (`apnhlos`), прошивку
Bluetooth и конфиги датчиков (`vendor`), модем (`modem`), реестр датчиков (`persist`) и адрес Bluetooth (`EFS`). `vendor` должен
быть от прошивки на базе Samsung. Дождитесь `Updater process ended with RC=0`; строка `Failed to mount '/system_root'` в конце —
норма. Первая загрузка дольше, затем запускается мастер.

### 4.2. Проверка без прошивки: образ как `/data/rootfs.img`
Загрузчик (хук initramfs образа boot) предпочитает `/data/rootfs.img`, если он есть:
```sh
# телефон в TWRP
adb push samsung-m52xq-classic.img /data/.rootfs.img.part
adb shell md5sum /data/.rootfs.img.part                 # сверить с .md5
adb shell 'mv /data/.rootfs.img.part /data/rootfs.img && sync'
# откат (в TWRP): mv /data/rootfs.img /data/rootfs.img.off — загрузится система из раздела system
```

### 4.3. Пароль и доступ
Пароль по умолчанию для `user` и `root` (разблокировка экрана, 4 цифры): **1111**; сменить — Настройки → Безопасность и
конфиденциальность (из консоли: `openssl passwd -6` + `chpasswd -e`; обычный `chpasswd` не работает — `pam_extrausers` не знает YESCRYPT).
Резерв shadow: `/etc/.m52xq-shadow-backup` (служба `m52xq-password-restore`).
SSH по USB, примерно через 30 с после загрузки: `ssh root@172.16.42.1`. Ключи SSH создаются при первой загрузке.
Снимок экрана: громкость вверх + громкость вниз одновременно (сохраняется в `~/Screenshots`).

## 5. Возврат на Android
Видео: https://www.youtube.com/watch?v=0lgLbtdl4rA&t=89s. Войдите в TWRP кнопками питания и громкости, заранее положите zip
прошивки на microSD; zip LineageOS и UN1CA сами перезаписывают boot, vendor_boot и dtbo.
```
Wipe - Format Data - yes - enter - Back - Back - Back - Advanced Wipe - Data - Repair or Change File System - Change File System -
EXT4 - Swipe to Change - Back - Back - Back - Back - Back - Install - lineage-23.2-2026-nightly-m52xq-signed.zip - Back - Back -
Wipe - Format Data - enter - Reboot System
```
Свежая LineageOS: https://download.lineageos.org/devices/m52xq/builds. Сток — через Odin или Heimdall (BL, AP, CP, CSC).

## 6. Ядро

Релиз [kernel-7.1.13](../../releases/tag/kernel-7.1.13) этого репозитория: `boot.img` (тот, что в zip v1, без прошивки IPA —
её добавляет установщик с телефона), `vendor_boot.img` (DTB из `device-tree/`), `dtbo-frag.img`, `Image`, `config-7.1.13`,
`modules-7.1.13.tar.gz` (раскладка Ubuntu `usr/lib/modules/7.1.13/…`, ровно модули образа v1), `SHA256SUMS`. `MODVERSIONS`
выключен: ставить модули только вместе с этим Image.
Исходники ядра: [sc7280-mainline-linux-m52xq](https://github.com/korryasdlerto-lgtm/sc7280-mainline-linux-m52xq) (7.1.13) плюс
три патча в `kernel/patches/`: переключение голосового устройства на месте (q6voice), сон панели при яркости 0, энергосбережение
ath11k при выключенном радио. Конфиг: `kernel/config-7.1.13`. Прежняя сборка: релиз
[kernel-7.1.2-430](../../releases/tag/kernel-7.1.2-430), `kernel/config-7.1.2-430`.

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
6. **Оверлей и пакеты** — `apply-fixes.sh`:
   ```sh
   L=$(sudo losetup -f --show -b 4096 -P samsung-m52xq-classic.img); sudo mount ${L}p2 mnt-new
   sudo ./apply-fixes.sh $PWD/mnt-new     # rootfs-overlay (владелец root), .deb через chroot dpkg -i, пароль, группы, locale-gen, флаги
   sync; sudo umount mnt-new; sudo losetup -d $L; md5sum samsung-m52xq-classic.img
   ```
   Пакеты `.deb` для dpkg (`debs*`) собираются из `build/` (раздел 9) или скачиваются из Ubuntu/UBports — сами `.deb` в репозиторий не входят.
   Образ релиза v1 сделан иначе: снимок телефона со всеми правками, из которого убраны личные данные, ключи SSH, machine-id и
   закрытые прошивки (с проверкой поиском по образцам); затем разбит на два чанка.

## 8. Состав репозитория

| Папка | Что внутри |
|---|---|
| `installer/META-INF` | установщик TWRP (два чанка), баннер «classic v1» |
| `rootfs-overlay/` | все файлы порта поверх корня (скрипты, службы, QML, конфиги, Plymouth); двоичные, закрытые прошивки, шрифты, обои и звуки — в `EXCLUDED-FILES.txt` с размером и md5 |
| `kernel/` | конфиги ядра и `patches/` поверх репозитория ядра |
| `device-tree/` | DTS для DTB в vendor_boot (файл в стиле апстрима + локальные добавки) |
| `apply-fixes.sh` | накладывает оверлей и пакеты на смонтированный образ |
| `image/` | сценарии сборки корня и образа (`build-01…04`, chroot, UBports, заливка на телефон) |
| `build/` | исходники, патчи и сценарии каждой пересобранной программы (раздел 9) |
| `docs/` | эта инструкция (RU/EN), `CHANGES-v1.md` / `CHANGES-v1-RU.md`, `ИНСТРУКЦИЯ.md` (все команды по шагам), `ПРАВКИ.md` (журнал правок) |

## 9. Пересобранные программы (`build/`)

| Папка | Что и зачем |
|---|---|
| `mesa` | `libEGL_mesa` 26.0.8 с `-Dlegacy-wayland=bind-wayland-display` — GPU в приложениях Lomiri (VERSION = полная версия пакета) |
| `modemmanager` | ModemManager 1.25.95 + патчи 0100–0103: основной слот и 2G-пути SIM, второй модем-объект для SIM 2, выбор SIM для данных, нефатальный attach SIM 2; 0104: use-after-free в netlink (падение при подключении данных) |
| `plasma-dialer`, `spacebar` | звонилка и SMS из исходников KDE для Ubuntu: 2 SIM, звуки клавиш (canberra, настройка Lomiri), ширина листа, постоянное уведомление, отметка прочитанного; USSD и кнопки в альбомной (0010), сброс громкой/микрофона в конце звонка (0012), «Добавить контакт» (0013); 0011 лежит, но не собирается |
| `kpeople` | KPeople 6.24 + `0001-m52xq-serialize-persondb-access.patch`: одна блокировка на базу контактов (падение звонилки) |
| `libcamera`, `lomiri-camera-app`, `m52xqcamsrc` | камера: soft-ISP патчи, фокус по касанию, видео 4K, 16 Мп с биннингом, оверлей настроек, меньше буферов для 64 Мп (0012); GStreamer-источник с Venus и цифровым зумом |
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
| `90-m52xq-lang` (генератор окружения пользователя), `m52xq-session-lang` | `LANG`/`LANGUAGE` сеанса по языку учётной записи |
| `m52xq-voicecall`, `m52xq-voice-mixers.sh`, `m52xq-tfa-guard`, `m52xq-audio-rescue` | звуковые маршруты звонка и переключение на месте, повтор усилителя, восстановление звуковой карты после загрузки |
| `m52xq-contacts-sync` (пользовательская) | адресная книга Lomiri → vCard для звонилки |
| `m52xq-bt-firmware` | загрузка прошивки Bluetooth после разблокировки rfkill |
| `m52xq-wpss-guard`, `m52xq-wpss-restart`, `m52xq-wl-reset` | защита от цикла падений прошивки Wi-Fi и чистый перезапуск |
| `m52xq-zram` | подкачка zram 3 ГБ |
| `m52xq-ssh-hostkeys`, `m52xq-password-hint` | ключи SSH при первой загрузке; цифровая панель для пароля из 4 цифр |

## 11. Ловушки (коротко)

- Большая часть бинарников из postmarketOS — musl и на Ubuntu не грузится: всё железное пересобирается под glibc.
- Ubuntu 26.04 не поставляет Qt5 `qmlscene`, `pkcon`, PackageKit-click, GStreamer-плагин Qt6, плагин позиции lomiri — собраны сами.
- Не ставить на телефон dev-пакеты UBports: понижают systemd/libc.
- `losetup` — всегда `--sector-size 4096`; zip — изнутри папки архива.
- `pkill -f` в ssh-команде убивает свою сессию.
- Правка ярлыков в `/custom/xdg/data/applications` вызывает мерцание Lomiri — не переписывать неизменённые файлы.

## 12. Благодарности
Ubuntu, UBports и Lomiri; postmarketOS; KDE (plasma-dialer, Spacebar, KPeople); разработчикам mainline Linux для Qualcomm SC7280/QCM6490.
