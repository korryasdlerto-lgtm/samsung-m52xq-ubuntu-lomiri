# "Classic": Ubuntu 26.04 + Lomiri (Ubuntu Touch) on a mainline kernel for the Samsung Galaxy M52 5G (m52xq) — full manual

Document version: 2026-11-02. Latest build: **classic v2** (2026-10-29).

## 1. What this is

- Device: Samsung Galaxy M52 5G, SM-M526B / SM-M526BR, Snapdragon 778G (SM7325, "yupik"), codename `m52xq`.
- Kernel: **mainline Linux 7.1.2**, build **#430** (boot v241 + vendor_boot v238) — no Halium, libhybris or Android HAL:
  Mir runs on `gbm-kms` and Mesa, audio is ALSA/PipeWire, the modem is QMI through ModemManager.
- System: a real **Ubuntu 26.04 LTS "resolute" arm64** root (built from scratch with `debootstrap`) + **Lomiri 0.6.2** and apps
  from the **UBports `26.04-1.x`** repository (`http://repo.ubports.com`).
- Hardware support (kernel, firmware, `m52xq-*` services) is the same layer as in the postmarketOS ports
  ([samsung-m52xq-mainline](https://github.com/korryasdlerto-lgtm/samsung-m52xq-mainline),
  [samsung-m52xq-postmarketos-lomiri](https://github.com/korryasdlerto-lgtm/samsung-m52xq-postmarketos-lomiri)), moved to Ubuntu.
- Personal hobby port, tested on one SM-M526B.

Video: https://www.youtube.com/watch?v=xJV4l0g4Kwc (Ubuntu Touch 26.04 on the M52); back to Android: https://www.youtube.com/watch?v=0lgLbtdl4rA

## 2. What works (as of 2026-10-29)

| Feature | Status | Notes |
|---|---|---|
| Lomiri shell, first-run wizard | works | Plymouth splash, lock screen with a number pad |
| Display, GPU for the shell and apps | works | own `libEGL_mesa` (Mesa 26.0.8, `bind-wayland-display`) — GPU compositing in apps (YouTube in Morph: 445 % → 30 % CPU) |
| Touch, maliit keyboard | works | |
| Auto-rotation | works | SSC through libssc (patched), iio-sensor-proxy |
| Two SIMs, mobile data | works | ModemManager 1.25.95 + DSDS patches 0100–0103 (`build/modemmanager`), SIM indicator `m52xq-indicator-sim` |
| Calls and SMS | works (as in pmOS) | plasma-dialer and Spacebar built from KDE sources with patches (2 SIMs, key tones, sheet width, persistent notification); daemons are user services `m52xq-*-daemon` |
| GPS in apps | works | ModemManager GNSS → gpsd → lomiri-location-service; rebuilt Qt Positioning "lomiri" plugin (`build/build-lls-plugin.sh`); per-app GeoClue permissions (`m52xq-gps-perms`) |
| Wi-Fi, Bluetooth, BT audio | works | Bluetooth address from EFS (`m52xq-bt-addr.py`), PipeWire BlueZ module |
| Audio, audio while locked | works | PipeWire; `lifecycle-exempt-appids` list (music keeps playing when locked) |
| Video | works | Venus in the Lomiri media player (own Qt6 GStreamer plugin `build/qt6-multimedia`); Qt5 browsers decode on the CPU |
| Camera | partial | `lomiri-camera-app` with patches + `m52xqcamsrc`; see below |
| OpenStore (click) | works | click + `pkcon`, `aa-exec-click` stubs, AppArmor shim; `/home` and click apps on userdata |
| Apps | works | YouTube, uNav, Pure Maps (Qt5 `qmlscene` built, PyOtherSide) |
| Flashlight, silent mode, settings links from the shade | works | |
| Suspend | works | short power key press locks; wakes for calls/SMS |

Not done / known issues: SIM icons in the shade through `lomiri-indicator-network` (we use our own indicator), the camera does not
always start, auto-brightness, occasional stuck Synaptics touch after blanking, quiet audio recording, zram, Firefox (not installed),
4K from the front camera does not play in the media player (Qt5), uNav CARTO tiles need a key. `apply-fixes.sh` has not yet been run on a clean image.

## 3. Requirements

Phone — as for the postmarketOS ports: SM-M526B with an unlocked bootloader, TWRP
(https://github.com/saadelasfur/Action-Recovery-Builder/releases/tag/20261004173308), microSD, backups of EFS, persist, modem,
boot, vendor_boot, vbmeta. Build computer — section 7.

## 4. Installation

### 4.1. Flashable zip (TWRP)
Archive `ubuntu-classic-26.04-m52xq-v2.zip`: 1 140 275 059 bytes, md5 `dc2860e4481f0b247bb9863f82773a48`; the image inside is
5 880 578 048 bytes (md5 `0b3f52cb8c582086909512693b0bd225`), three chunks.
**The archive is not published:** its root is a snapshot of one phone's live system (Bluetooth address, sensor registry, ssh keys,
password hash). Build your own archive as in sections 7–9.

TWRP steps — as in the video and as for the postmarketOS port (Format Data → EXT4 → optionally UN1CA_3.1.0 → Format Data/EXT4 again → Install):
```
Wipe - Format Data - yes - enter - Back - Back - Advanced Wipe - Data - Repair or Change File System - Change File System - EXT4 -
Swipe to Change - Back - Back - Back - Back - Back - Install - Select Storage - Micro SD card - ubuntu-classic-26.04-m52xq-v2.zip -
Swipe to confirm Flash - Reboot System
```
The installer is the postmarketOS port's one (section 4 of its manual): it grows `system` to 8 000 000 000 bytes, joins **three**
chunks `samsung-m52xq.img.part-0…2` into `/dev/block/mapper/system`, writes boot v241 and vendor_boot v238, and takes the
Bluetooth address (EFS), the modem firmware and the sensor registry (persist) from the phone.

### 4.2. Testing without flashing: the image as `/data/rootfs.img`
The boot loader (initramfs hook of boot v233+) prefers `/data/rootfs.img` when it exists:
```sh
# phone in TWRP
adb push samsung-m52xq-classic.img /data/.rootfs.img.part
adb shell md5sum /data/.rootfs.img.part                 # compare with the .md5
adb shell 'mv /data/.rootfs.img.part /data/rootfs.img && sync'
# roll back (in TWRP): mv /data/rootfs.img /data/rootfs.img.off — the system in the system partition boots again
```

### 4.3. Password and access
Password of `user` and `root` set by `apply-fixes.sh`: **1111** (`openssl passwd -6` + `chpasswd -e`; plain `chpasswd`
fails — `pam_extrausers` does not know YESCRYPT). The Lomiri wizard may set an empty password — set your own the same way.
Shadow backup: `/etc/.m52xq-shadow-backup` (service `m52xq-password-restore`).
USB access: `ssh user@172.16.42.1`.

## 5. Going back to Android
Video: https://www.youtube.com/watch?v=0lgLbtdl4rA — steps as for the postmarketOS port (Format Data → EXT4 → LineageOS 23.2 → Format Data → Reboot).
Stock firmware — with Odin (BL, AP, CP, CSC).

## 6. Kernel

Release [kernel-7.1.2-430](../../releases/tag/kernel-7.1.2-430) of this repository: `boot_v241_nfc.img` (md5 `f89bec95…`),
`vendor_boot_v238_nfc_se9.img` (md5 `e1fb7dd3…`), `Image`, `config-7.1.2-430`, `modules-7.1.2-430.tar.gz`
(Ubuntu layout `usr/lib/modules/7.1.2/…`: `ath11k_ahb.ko`, `extra/v4l2loopback.ko`, `extra/venus/*` — loaded by `m52xq-venus-load`), `SHA256SUMS`.
The modules are exactly those of the classic v2 image. `MODVERSIONS` is off: install them only together with this boot image.
Kernel source: [sc7280-mainline-linux-m52xq](https://github.com/korryasdlerto-lgtm/sc7280-mainline-linux-m52xq).

## 7. Building from scratch: Ubuntu 26.04 + Lomiri root

Full commands with output — `docs/ИНСТРУКЦИЯ.md` (sections 1–9, 12.10, 15, in Russian); every change by number — `docs/ПРАВКИ.md` (≈ 150 items).
Scripts are in `image/`.

Host: Ubuntu 20.04 x86_64, sudo, ≥ 20 GB, internet:
```sh
sudo apt install debootstrap qemu-user-static binfmt-support gdisk rsync e2fsprogs curl openssl zip unzip util-linux
ls /proc/sys/fs/binfmt_misc/ | grep qemu-aarch64          # must be there
```

1. **Base root** — `image/build-01-resolute.sh`: the host's 20.04 debootstrap does not know resolute and breaks on `/bin → usr/bin`,
   so a **fresh debootstrap 1.0.144** is taken from the Ubuntu archive and unpacked next to the tree (the host is not changed); first
   and second stage under qemu. `/etc/apt/sources.list`: main restricted universe multiverse + updates + security.
2. **chroot** — `image/chroot-config.sh`, `image/chroot-run.sh` (proc/sys/dev mounts, resolv.conf, policy-rc.d).
3. **Lomiri from UBports**: `/etc/apt/sources.list.d/ubports.sources` (`http://repo.ubports.com`, suite `26.04-1.x`) and
   `/etc/apt/preferences.d/ubports.pref` (UBports priority for its packages); `apt install lomiri …` (`image/rootfs-ubports.sh`).
4. **Empty GPT image with the same UUIDs** — `image/build-03-image.sh`: 4096-byte sectors, p1 `pmOS_boot`, p2 `pmOS_root`
   (p2 UUID `27c97050-ff55-4e42-b894-0f866eb5ad1f`), copy of the root.
5. **m52xq hardware layer** — `image/build-04-hardware.sh`: from the postmarketOS-Lomiri v3 image (read-only,
   `losetup --sector-size 4096`) it copies `lib/modules` → `usr/lib/modules`, `lib/firmware` → `usr/lib/firmware`, `/usr/local`,
   udev rules, systemd units, sleep hooks, NM configs, audio UCM, `/usr/share/qcom` (the sensor registry is personal data, not in the repository).
6. **v2 changes** — `apply-fixes.sh`:
   ```sh
   L=$(sudo losetup -f --show -b 4096 -P samsung-m52xq-classic.img); sudo mount ${L}p2 mnt-new
   sudo ./apply-fixes.sh $PWD/mnt-new     # rootfs-overlay (owned by root), .debs via chroot dpkg -i, password, groups, locale-gen, flags
   sync; sudo umount mnt-new; sudo losetup -d $L; md5sum samsung-m52xq-classic.img
   ```
   The `.deb` packages for dpkg (`debs*`) are built from `build/` (section 9) or downloaded from Ubuntu/UBports — the `.deb` files are not in the repository.

## 8. Repository layout

| Folder | Contents |
|---|---|
| `installer/META-INF` | TWRP installer (three chunks), banner "classic v2" |
| `rootfs-overlay/` | every v2 file over the root (scripts, services, QML, configs, Plymouth); binaries are listed in `EXCLUDED-FILES.txt` with md5 |
| `apply-fixes.sh` | applies the overlay and packages to a mounted image |
| `image/` | root and image build scripts (`build-01…04`, chroot, UBports, upload to the phone) |
| `build/` | sources, patches and scripts of every rebuilt program (section 9) |
| `docs/` | this manual (RU/EN), `ИНСТРУКЦИЯ.md` (all commands step by step), `ПРАВКИ.md` (change log) |

## 9. Rebuilt programs (`build/`)

| Folder | What and why |
|---|---|
| `mesa` | `libEGL_mesa` 26.0.8 with `-Dlegacy-wayland=bind-wayland-display` — GPU in Lomiri apps (VERSION = full package version) |
| `modemmanager` | ModemManager 1.25.95 + patches 0100–0103: primary slot and 2G SIM paths, a second modem object for SIM 2, data SIM choice, non-fatal SIM 2 attach |
| `plasma-dialer`, `spacebar` | dialer and SMS from KDE sources for Ubuntu: 2 SIMs, key tones (canberra, Lomiri setting), sheet width, persistent notification, read state |
| `libcamera`, `lomiri-camera-app`, `m52xqcamsrc` | camera: soft-ISP patches, tap to focus, 4K video, 16 MP binned, options overlay; GStreamer source with Venus |
| `qt6-multimedia` | Qt6 Multimedia GStreamer backend (missing in Ubuntu 26.04) — Venus video in the Lomiri player |
| `qmlscene5` | Qt5 `qmlscene` (not shipped in 26.04) — for YouTube/uNav/Pure Maps from OpenStore |
| `build-lls-plugin.sh` | Qt Positioning "lomiri" plugin (lomiri-location-service) — GPS in apps |
| `build-cellular-plugin.sh`, `cellular` | "Cellular" settings module for ModemManager |
| `indicator-bluetooth` | `0001-phone-paired-devices.patch` — paired devices in the indicator |
| `sensors` | `libssc-m52xq-0003-proximity-report-dump.patch` (+ libssc 0.4.4, iio-sensor-proxy 3.9 sources) |
| `aa-shim`, `settings-stub`, `src/noprops.c` | stubs for AppArmor (click), settings, Android properties |

## 10. Services and scripts

| Service / script | Purpose |
|---|---|
| `m52xq-userdata-dirs` | `/home` and `/opt/click.ubuntu.com` on the userdata partition |
| `m52xq-click-desktops` | launcher entries of click apps in the directory Lomiri reads |
| `m52xq-modem-setup` | SIM session and modem GNSS engine setup |
| `m52xq-gnss-gpsd`, `m52xq-gps*`, `m52xq-gps-perms` | GNSS → gpsd, per-app location permissions (GeoClue) |
| `m52xq-indicator-sim` (user) | SIM indicator for the panel and the shade |
| `m52xq-modem-daemon`, `m52xq-kde-telephony-daemon`, `m52xq-spacebar-daemon` (user) | dialer and SMS daemons in the Lomiri session (XDG autostart does not run in Lomiri) |
| `m52xq-incall-proximity` | blank the screen and lock touch at the ear |
| `m52xq-sim-slots`, `m52xq-sim-mode`, `m52xq-sim-mode-menu` | SIM slots by ICCID, SIM mode |
| `m52xq-powerkey`, `m52xq-reboot-recovery`, `m52xq-flight-mode` | power key, reboot-to-recovery menu, flight mode |
| `m52xq-plymouth-fallback` | quit Plymouth if the greeter did not |
| `pkcon`, `aa-exec-click` | stubs for installing OpenStore click packages |
| `m52xq-unav-tiles` | tile source for uNav |

## 11. Pitfalls (short)

- Most binaries from postmarketOS are musl and do not load on Ubuntu: everything hardware-related is rebuilt for glibc.
- Ubuntu 26.04 does not ship Qt5 `qmlscene`, `pkcon`, PackageKit-click, the Qt6 GStreamer plugin or the lomiri position plugin — built here.
- Do not install UBports dev packages on the phone: they downgrade systemd/libc.
- `losetup` always with `--sector-size 4096`; the zip from inside the archive folder.
- `pkill -f` inside an ssh command kills its own session.
- Editing launcher entries in `/custom/xdg/data/applications` makes Lomiri flicker — do not rewrite unchanged files.

## 12. Credits
Ubuntu, UBports and Lomiri; postmarketOS; KDE (plasma-dialer, Spacebar); the mainline Linux developers for Qualcomm SC7280/QCM6490.
