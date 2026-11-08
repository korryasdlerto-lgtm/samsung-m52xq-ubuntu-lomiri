# samsung-m52xq-ubuntu-lomiri

**Ubuntu 26.04 LTS + Lomiri** (the Ubuntu Touch shell from UBports) on a **mainline Linux kernel** for the
**Samsung Galaxy M52 5G** (codename `m52xq`, SM-M526B / SM-M526BR, Qualcomm Snapdragon 778G / SM7325, platform "yupik").

It is not Halium, not libhybris and not the Android kernel. The phone runs a mainline Linux 7.1.13 kernel with device drivers
and fixes. The system is a real Ubuntu 26.04 "resolute" arm64 root. Lomiri 0.6.2 and the apps come from the UBports
`26.04-1.x` repository, and apps from the OpenStore can be installed too. The hardware layer (kernel, `m52xq-*` services) is
the same as in the postmarketOS port [samsung-m52xq-mainline](https://github.com/korryasdlerto-lgtm/samsung-m52xq-mainline),
rebuilt for glibc. Personal, unofficial project (not a UBports or Canonical release), tested on one SM-M526B.

**Status (release "unofficial v1", 2026-11-09, see [changes](docs/CHANGES-v1.md) / [на русском](docs/CHANGES-v1-RU.md)):
a daily-usable Linux phone.** It has calls, SMS and mobile data on two SIMs, Wi-Fi, Bluetooth, a GPU-accelerated shell and
apps, sound, GPS, sensors, the camera with 64 MP photos and deep sleep that wakes for calls, SMS and alarms.

## Repositories

| | |
|---|---|
| This repository | installer, rootfs overlay (scripts, services, QML, configs), patches and build scripts of the rebuilt programs, device tree, kernel config and patches, documentation |
| Kernel source | [sc7280-mainline-linux-m52xq](https://github.com/korryasdlerto-lgtm/sc7280-mainline-linux-m52xq); the three patches of this release on top of it are in [`kernel/patches/`](kernel/patches) |
| Kernel binaries | release [kernel-7.1.13](../../releases/tag/kernel-7.1.13) of this repository: boot.img, vendor_boot.img, dtbo, Image, modules, config |

## What works

| Feature | Status | Notes |
|---|---|---|
| Boot, UFS storage | works | `system` grown to 8 GB by the installer; `/home` and click apps on the userdata partition |
| Display | works | Samsung S6E3HAB AMOLED, brightness, auto-rotation; the panel stays asleep on network wake-ups |
| GPU (Adreno 642L) | works | Mesa freedreno; own `libEGL_mesa` build gives GPU compositing in Lomiri apps |
| Touchscreen, keyboard | works | Synaptics; maliit keyboard (see known issues) |
| First-run wizard | works | the chosen language is applied to the shell, the quick settings and all apps |
| Wi-Fi, Bluetooth, BT audio | works | WCN6750 / ath11k; Bluetooth address from the phone's EFS |
| Calls, SMS, mobile data | works | **dual SIM** (DSDS, both active), plasma-dialer and Spacebar rebuilt for Ubuntu; switching speaker/earpiece in a call; call window on the lock screen; call bar with call time and contact name |
| Contacts | works | Lomiri contacts are shared with the dialer |
| Audio | works | loudspeaker (TFA9878), earpiece, microphones, in-call noise suppression |
| GPS | works | ModemManager GNSS, gpsd, lomiri-location-service |
| Sensors | works | light, proximity (screen off in calls), accelerometer |
| Battery, charging | works | SM5714 fuel gauge and charger, Samsung AFC 9 V |
| Suspend | works | wakes for calls, SMS and alarms (RTC) |
| Alarm clock | works | wakes the phone from sleep |
| Camera | works, partial | rear and front cameras, **64 MP photos**, digital zoom up to 4x, video with the hardware encoder (Venus); not every lens and mode yet, image processing in software |
| Video playback | works | Venus in the Lomiri media player; video in the browser is decoded in software |
| OpenStore | works | click apps; TELEports (Telegram) works out of the box |
| zram | works | 3 GB compressed swap in RAM, so 64 MP photos and heavy pages do not run out of memory |
| Fingerprint | no | |
| VoLTE | no | calls use 2G/3G |

### Known issues

- **Keyboard after a rotation:** sometimes, after turning the phone from portrait to landscape, the right half of the keyboard
  does not react. Hide the keyboard and tap the text field again. In the first-run wizard it is easiest to type the Wi-Fi
  password in portrait. The cause is a race when the keyboard reports its new area to the shell after the rotation.
- **TELEports:** text, stickers, photos and files work; Telegram voice and video calls are not supported by TELEports itself.
- **Formats in the first session after the wizard:** the quick settings may show some formats (date, numbers) in English
  until the first reboot. Translations are correct right away.

## Install

Requirements: unlocked bootloader, TWRP for m52xq
(<https://github.com/saadelasfur/Action-Recovery-Builder/releases/tag/20261004173308>), a microSD card with the zips,
backups of EFS, persist, modem, boot, vendor_boot and vbmeta. If you are not comfortable restoring a Samsung phone with
Odin, do not install this.

- Flashable zip (1.1 GB): [ubuntu_touch_classic_26.04-m52xq-mainline-v1-UNOFFICIAL.zip](https://drive.google.com/file/d/1Z9dCERDZID4DJXgfY4CrCK9k98HZdGAa/view?usp=sharing), md5 `a3343884846751530f4a590e23e9275e`
- Video guide: <https://www.youtube.com/watch?v=xJV4l0g4Kwc>

The phone gets warm during the install. If your display already shows vertical coloured lines, do not install this: the
heat may make them worse.

Flash **UN1CA_3.1.0** first to get the maximum system partition size (the installer grows `system` to 8 000 000 000 bytes).
After LineageOS 23 the partition is 1 GB smaller, but the install still works.

TWRP steps:

```
Wipe - Format Data - yes - enter - Back - Back - Advanced Wipe - Data - Repair or Change File System - Change File System - EXT4 - Swipe to Change - Back - Back - Back - Back - Back - Install - Select Storage - Micro SD card - ubuntu_touch_classic_26.04-m52xq-mainline-v1-UNOFFICIAL.zip - Swipe to confirm Flash - Reboot System
```

The install takes about two minutes; wait for `Updater process ended with RC=0`. A line `Failed to mount '/system_root'`
at the very end is normal. The first boot takes longer; then the setup wizard starts (language, Wi-Fi, time zone).

The installer writes boot, vendor_boot and dtbo, writes the root image to `system` and enables the device services. The
Samsung/Qualcomm device firmware is **not** in the zip: the installer copies it, read-only, from the phone's own partitions.
ADSP, GPU zap shader, IPA (mobile data) and Venus come from `apnhlos`. Bluetooth firmware and sensor configs come from
`vendor`, the modem from `modem`, the sensor registry from `persist` and the Bluetooth address from `EFS`. The IPA firmware
is added to the boot ramdisk, because the built-in IPA driver needs it before the root is mounted. `vendor` must come from
a Samsung-based ROM (stock, UN1CA or LineageOS). SSH host keys and the machine ID are created on the first boot.

- Default password (4-digit screen unlock, `user` and `root`): `1111`. Change it in System Settings - Security & Privacy.
- SSH over USB (about 30 s after boot): `ssh root@172.16.42.1` (password `1111`).
- Screenshot: press **Volume Up + Volume Down** at the same time; the picture goes to `~/Screenshots`.

### Back to Android

Video guide: <https://www.youtube.com/watch?v=0lgLbtdl4rA&t=89s>

If the port has no option to reboot into recovery, enter TWRP with the power and volume button combination. Copy the
firmware zip to the microSD card first. The LineageOS and UN1CA zips rewrite boot, vendor_boot and dtbo themselves.

```
Wipe - Format Data - yes - enter - Back - Back - Back - Advanced Wipe - Data - Repair or Change File System - Change File System - EXT4 - Swipe to Change - Back - Back - Back - Back - Back - Install - lineage-23.2-2026-nightly-m52xq-signed.zip - Back - Back - Wipe - Format Data - enter - Reboot System
```

Latest LineageOS build: <https://download.lineageos.org/devices/m52xq/builds>. Stock firmware can always be restored with
Odin or Heimdall (BL, AP, CP, CSC).

## Repository layout

| Path | Content |
|---|---|
| `installer/` | `META-INF/.../update-binary` of the flashable zip (TWRP shell installer) |
| `rootfs-overlay/` | files over the Ubuntu root: `m52xq-*` scripts and services, system-sleep hooks, systemd drop-ins, Lomiri / wizard / camera / clock QML, schemas and configs. Binaries, proprietary firmware, sensor configs, fonts, wallpapers and sounds are not here: see `rootfs-overlay/EXCLUDED-FILES.txt` (path, size, md5) |
| `build/` | patches and build scripts of every rebuilt program (table below) |
| `kernel/` | kernel configs (`config-7.1.13` of this release, `config-7.1.2-430` of the earlier build) and `patches/` on top of the kernel repository |
| `device-tree/` | `sm7325-samsung-m52xq.dts` (upstream-style) and `sm7325-samsung-m52xq-local.dts` (local additions, RTC enabled): the DTB in vendor_boot of this release |
| `image/`, `apply-fixes.sh` | scripts that build the Ubuntu 26.04 + Lomiri root from scratch (debootstrap, UBports, image, hardware layer) and apply the overlay |
| `docs/` | manuals (EN/RU, Markdown and Word), change list of v1, step-by-step build commands and the full change log (Russian) |

### Rebuilt programs (`build/`)

| Folder | What and why |
|---|---|
| `mesa` | `libEGL_mesa` 26.0.8 with `bind-wayland-display`: GPU in Lomiri apps |
| `modemmanager` | ModemManager 1.25.95 + patches 0100–0103 (dual SIM) and 0104 (netlink use-after-free that crashed ModemManager on mobile data connects) |
| `plasma-dialer`, `spacebar` | dialer and SMS from KDE sources for Ubuntu: two SIMs, key tones, Lomiri notifications, USSD, speaker/mute reset at call end, "Add contact" |
| `kpeople` | KPeople 6.24 + a patch that serializes the contacts database (the dialer crashed when the contact name and avatar were loaded at once) |
| `libcamera`, `m52xqcamsrc`, `lomiri-camera-app` | camera: soft-ISP patches, quad-Bayer remosaic for 16/64 MP, fewer buffers for 64 MP; GStreamer source with digital zoom |
| `qt6-multimedia` | Qt6 Multimedia GStreamer backend (missing in Ubuntu 26.04): Venus video in the Lomiri player |
| `qmlscene5` | Qt5 `qmlscene` (not shipped in 26.04) for Qt5 apps from the OpenStore |
| `build-lls-plugin.sh` | Qt Positioning "lomiri" plugin: GPS in apps |
| `build-cellular-plugin.sh`, `cellular` | "Cellular" settings module for ModemManager |
| `indicator-bluetooth`, `sensors`, `aa-shim`, `settings-stub`, `src` | paired devices in the indicator, libssc patch, stubs for AppArmor (click), settings, Android properties |

The `.deb` packages themselves are not in the repository.

## Building

- Kernel: `make ARCH=arm64 LLVM=1 Image` with clang/LLD 22 (the pmbootstrap Alpine chroot) using `kernel/config-7.1.13`
  and the patches in `kernel/patches/`; the boot image is the previous boot.img with the new `Image` and the appended DTB
  tail (`tools/repack_boot.py` of samsung-m52xq-mainline). `MODVERSIONS` is off: use the modules only with the same Image.
- Packages: each folder in `build/` has a `build.sh` that builds the `.deb` in an arm64 Ubuntu 26.04 chroot (qemu).
- Root: `image/` + `apply-fixes.sh`, see the manual, sections 7–9. The release image itself was made from a phone
  with all fixes installed, with personal data, keys and proprietary firmware removed.

## Manuals

| Language | Markdown | Word |
|---|---|---|
| English | [docs/MANUAL-EN.md](docs/MANUAL-EN.md) | [docs/M52-ubuntu-26.04-lomiri-manual-EN.docx](docs/M52-ubuntu-26.04-lomiri-manual-EN.docx) |
| Русский | [docs/MANUAL-RU.md](docs/MANUAL-RU.md) | [docs/M52-ubuntu-26.04-lomiri-manual-RU.docx](docs/M52-ubuntu-26.04-lomiri-manual-RU.docx) |

Step-by-step commands with output (Russian): [docs/ИНСТРУКЦИЯ.md](docs/ИНСТРУКЦИЯ.md); full change log: [docs/ПРАВКИ.md](docs/ПРАВКИ.md).

## Bug reports

Please write your model (SM-M526B / SM-M526BR), what you did and what happened. Logs help a lot: `journalctl -b` and
`dmesg` over SSH or in the Terminal app.

## Credits

UBports and the Lomiri developers, Ubuntu, KDE (plasma-dialer, Spacebar, KPeople), postmarketOS and pmbootstrap, the
mainline Linux developers for Qualcomm SC7280 / QCM6490 (Fairphone 5 and others), LineageOS (device and kernel sources used
as reference), the TWRP maintainers for m52xq.

## License

Kernel code: GPL-2.0 (see the kernel repository). Patches follow the license of the patched project. Scripts and
documentation in this repository: GPL-2.0.
