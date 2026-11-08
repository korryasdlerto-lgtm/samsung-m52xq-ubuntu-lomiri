# "Classic": Ubuntu 26.04 + Lomiri (Ubuntu Touch) on a mainline kernel for the Samsung Galaxy M52 5G (m52xq) — full manual

Document version: 2026-11-09. Latest release: **unofficial v1** (2026-11-09); changes: [CHANGES-v1.md](CHANGES-v1.md).

## 1. What this is

- Device: Samsung Galaxy M52 5G, SM-M526B / SM-M526BR, Snapdragon 778G (SM7325, "yupik"), codename `m52xq`.
- Kernel: **mainline Linux 7.1.13** with device patches (section 6) — no Halium, libhybris or Android HAL:
  Mir runs on `gbm-kms` and Mesa, audio is ALSA/PipeWire, the modem is QMI through ModemManager.
- System: a real **Ubuntu 26.04 LTS "resolute" arm64** root (built from scratch with `debootstrap`) + **Lomiri 0.6.2** and apps
  from the **UBports `26.04-1.x`** repository (`http://repo.ubports.com`).
- Hardware support (kernel, firmware, `m52xq-*` services) is the same layer as in the postmarketOS ports
  ([samsung-m52xq-mainline](https://github.com/korryasdlerto-lgtm/samsung-m52xq-mainline),
  [samsung-m52xq-postmarketos-lomiri](https://github.com/korryasdlerto-lgtm/samsung-m52xq-postmarketos-lomiri)), moved to Ubuntu.
- Personal hobby port, tested on one SM-M526B.

Video: https://www.youtube.com/watch?v=xJV4l0g4Kwc (installation); back to Android: https://www.youtube.com/watch?v=0lgLbtdl4rA&t=89s

## 2. What works (release unofficial v1, 2026-11-09)

| Feature | Status | Notes |
|---|---|---|
| Lomiri shell, first-run wizard | works | Plymouth splash, lock screen with a number pad; the language chosen in the wizard is applied to the shell, the quick settings and all apps |
| Display, GPU for the shell and apps | works | own `libEGL_mesa` (Mesa 26.0.8, `bind-wayland-display`) — GPU compositing in apps (YouTube in Morph: 445 % → 30 % CPU) |
| Touch, maliit keyboard | works | |
| Auto-rotation | works | SSC through libssc (patched), iio-sensor-proxy |
| Two SIMs, mobile data | works | ModemManager 1.25.95 + DSDS patches 0100–0103 (`build/modemmanager`), SIM indicator `m52xq-indicator-sim` |
| Calls and SMS | works | plasma-dialer and Spacebar built from KDE sources with patches (2 SIMs, key tones, USSD, speaker/mute reset, "Add contact"); daemons are user services `m52xq-*-daemon`; speaker/earpiece switching in place (kernel); call bar with time and name; contacts shared with the Lomiri address book |
| GPS in apps | works | ModemManager GNSS → gpsd → lomiri-location-service; rebuilt Qt Positioning "lomiri" plugin (`build/build-lls-plugin.sh`); per-app GeoClue permissions (`m52xq-gps-perms`) |
| Wi-Fi, Bluetooth, BT audio | works | Bluetooth address from EFS (`m52xq-bt-addr.py`), PipeWire BlueZ module |
| Audio, audio while locked | works | PipeWire; `lifecycle-exempt-appids` list (music keeps playing when locked) |
| Video | works | Venus in the Lomiri media player (own Qt6 GStreamer plugin `build/qt6-multimedia`); Qt5 browsers decode on the CPU |
| Camera | works, partial | `lomiri-camera-app` with patches + `m52xqcamsrc`: rear and front, 64 MP photos, digital zoom up to 4x, Venus video; not every lens and mode |
| OpenStore (click) | works | click + `pkcon`, `aa-exec-click` stubs, AppArmor shim; `/home` and click apps on userdata |
| Apps | works | YouTube, uNav, Pure Maps (Qt5 `qmlscene` built, PyOtherSide), TELEports (`libssl1.1` + push notifications QML module) |
| Alarm clock | works | `lomiri-indicator-datetime`, wakes the phone from sleep through the RTC |
| zram | works | 3 GB compressed swap (`m52xq-zram`) |
| Flashlight, silent mode, settings links from the shade | works | |
| Suspend | works | short power key press locks; wakes for calls, SMS and alarms; the panel stays dark on network wake-ups; Wi-Fi firmware sleeps when Wi-Fi is off |

Not working: fingerprint reader, VoLTE (calls use 2G/3G).

Known issues: after a rotation from portrait to landscape the right half of the keyboard sometimes does not react (hide the
keyboard and tap the text field again; in the wizard type the Wi-Fi password in portrait); TELEports has no Telegram calls;
the quick settings may show some formats in English until the first reboot after the wizard; video in the browser is decoded
on the CPU; auto-brightness; uNav CARTO tiles need a key.

## 3. Requirements

Phone — as for the postmarketOS ports: SM-M526B with an unlocked bootloader, TWRP
(https://github.com/saadelasfur/Action-Recovery-Builder/releases/tag/20261004173308), microSD, backups of EFS, persist, modem,
boot, vendor_boot, vbmeta. Build computer — section 7.

## 4. Installation

### 4.1. Flashable zip (TWRP)
Archive [ubuntu_touch_classic_26.04-m52xq-mainline-v1-UNOFFICIAL.zip](https://drive.google.com/file/d/1Z9dCERDZID4DJXgfY4CrCK9k98HZdGAa/view?usp=sharing):
1 085 618 664 bytes, md5 `a3343884846751530f4a590e23e9275e`; the root image inside is split into two chunks. It contains no
personal data, no SSH keys and no proprietary firmware.

The phone gets warm during the install; if the display already shows vertical coloured lines, do not install. Flash
UN1CA_3.1.0 first for the maximum system partition size (after LineageOS 23 it is 1 GB smaller, the install still works).

TWRP steps (as in the video):
```
Wipe - Format Data - yes - enter - Back - Back - Advanced Wipe - Data - Repair or Change File System - Change File System - EXT4 -
Swipe to Change - Back - Back - Back - Back - Back - Install - Select Storage - Micro SD card - ubuntu_touch_classic_26.04-m52xq-mainline-v1-UNOFFICIAL.zip -
Swipe to confirm Flash - Reboot System
```
The installer is the postmarketOS port's one: it grows `system` to 8 000 000 000 bytes, joins the two chunks
`samsung-m52xq.img.part-0…1` into `/dev/block/mapper/system`, writes boot, vendor_boot and dtbo (`dtbo-frag`), adds the IPA
firmware of the phone to the boot ramdisk and copies from the phone, read-only: ADSP, GPU zap shader, IPA and Venus
(`apnhlos`), Bluetooth firmware and sensor configs (`vendor`), the modem (`modem`), the sensor registry (`persist`) and the
Bluetooth address (`EFS`). `vendor` must come from a Samsung-based ROM. Wait for `Updater process ended with RC=0`; the line
`Failed to mount '/system_root'` at the end is normal. The first boot takes longer, then the wizard starts.

### 4.2. Testing without flashing: the image as `/data/rootfs.img`
The boot loader (initramfs hook of the boot image) prefers `/data/rootfs.img` when it exists:
```sh
# phone in TWRP
adb push samsung-m52xq-classic.img /data/.rootfs.img.part
adb shell md5sum /data/.rootfs.img.part                 # compare with the .md5
adb shell 'mv /data/.rootfs.img.part /data/rootfs.img && sync'
# roll back (in TWRP): mv /data/rootfs.img /data/rootfs.img.off — the system in the system partition boots again
```

### 4.3. Password and access
Default password of `user` and `root` (4-digit screen unlock): **1111**; change it in System Settings - Security & Privacy
(from a shell: `openssl passwd -6` + `chpasswd -e`; plain `chpasswd` fails — `pam_extrausers` does not know YESCRYPT).
Shadow backup: `/etc/.m52xq-shadow-backup` (service `m52xq-password-restore`).
SSH over USB, about 30 s after boot: `ssh root@172.16.42.1`. SSH host keys are created on the first boot.
Screenshot: Volume Up + Volume Down at the same time (saved to `~/Screenshots`).

## 5. Going back to Android
Video: https://www.youtube.com/watch?v=0lgLbtdl4rA&t=89s. Enter TWRP with the power and volume buttons, copy the firmware zip
to the microSD card first; the LineageOS and UN1CA zips rewrite boot, vendor_boot and dtbo themselves.
```
Wipe - Format Data - yes - enter - Back - Back - Back - Advanced Wipe - Data - Repair or Change File System - Change File System -
EXT4 - Swipe to Change - Back - Back - Back - Back - Back - Install - lineage-23.2-2026-nightly-m52xq-signed.zip - Back - Back -
Wipe - Format Data - enter - Reboot System
```
Latest LineageOS: https://download.lineageos.org/devices/m52xq/builds. Stock firmware — with Odin or Heimdall (BL, AP, CP, CSC).

## 6. Kernel

Release [kernel-7.1.13](../../releases/tag/kernel-7.1.13) of this repository: `boot.img` (the one in the v1 zip, without
the IPA firmware, which the installer adds from the phone), `vendor_boot.img` (DTB of `device-tree/`), `dtbo-frag.img`,
`Image`, `config-7.1.13`, `modules-7.1.13.tar.gz` (Ubuntu layout `usr/lib/modules/7.1.13/…`, exactly the modules of the v1
image), `SHA256SUMS`. `MODVERSIONS` is off: install the modules only together with this Image.
Kernel source: [sc7280-mainline-linux-m52xq](https://github.com/korryasdlerto-lgtm/sc7280-mainline-linux-m52xq) (7.1.13) plus
the three patches in `kernel/patches/`: in-place voice device switch (q6voice), panel kept asleep while the brightness is 0,
ath11k power save with the radio off. Config: `kernel/config-7.1.13`. The earlier build: release
[kernel-7.1.2-430](../../releases/tag/kernel-7.1.2-430), `kernel/config-7.1.2-430`.

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
6. **Overlay and packages** — `apply-fixes.sh`:
   ```sh
   L=$(sudo losetup -f --show -b 4096 -P samsung-m52xq-classic.img); sudo mount ${L}p2 mnt-new
   sudo ./apply-fixes.sh $PWD/mnt-new     # rootfs-overlay (owned by root), .debs via chroot dpkg -i, password, groups, locale-gen, flags
   sync; sudo umount mnt-new; sudo losetup -d $L; md5sum samsung-m52xq-classic.img
   ```
   The `.deb` packages for dpkg (`debs*`) are built from `build/` (section 9) or downloaded from Ubuntu/UBports — the `.deb` files are not in the repository.
   The v1 release image was made differently: a snapshot of a phone with all fixes installed, with personal data, SSH keys,
   the machine ID and proprietary firmware removed and checked by a pattern scan; then split into two chunks.

## 8. Repository layout

| Folder | Contents |
|---|---|
| `installer/META-INF` | TWRP installer (two chunks), banner "classic v1" |
| `rootfs-overlay/` | every file of the port over the root (scripts, services, QML, configs, Plymouth); binaries, proprietary firmware, fonts, wallpapers and sounds are listed in `EXCLUDED-FILES.txt` with size and md5 |
| `kernel/` | kernel configs and `patches/` on top of the kernel repository |
| `device-tree/` | DTS of the vendor_boot DTB (upstream-style file + local additions) |
| `apply-fixes.sh` | applies the overlay and packages to a mounted image |
| `image/` | root and image build scripts (`build-01…04`, chroot, UBports, upload to the phone) |
| `build/` | sources, patches and scripts of every rebuilt program (section 9) |
| `docs/` | this manual (RU/EN), `CHANGES-v1.md` / `CHANGES-v1-RU.md`, `ИНСТРУКЦИЯ.md` (all commands step by step), `ПРАВКИ.md` (change log) |

## 9. Rebuilt programs (`build/`)

| Folder | What and why |
|---|---|
| `mesa` | `libEGL_mesa` 26.0.8 with `-Dlegacy-wayland=bind-wayland-display` — GPU in Lomiri apps (VERSION = full package version) |
| `modemmanager` | ModemManager 1.25.95 + patches 0100–0103: primary slot and 2G SIM paths, a second modem object for SIM 2, data SIM choice, non-fatal SIM 2 attach; 0104: netlink use-after-free (crash on data connects) |
| `plasma-dialer`, `spacebar` | dialer and SMS from KDE sources for Ubuntu: 2 SIMs, key tones (canberra, Lomiri setting), sheet width, persistent notification, read state; USSD and landscape buttons (0010), speaker/mute reset at call end (0012), "Add contact" (0013); 0011 is kept but not built |
| `kpeople` | KPeople 6.24 + `0001-m52xq-serialize-persondb-access.patch`: one lock for the contacts database (dialer crash) |
| `libcamera`, `lomiri-camera-app`, `m52xqcamsrc` | camera: soft-ISP patches, tap to focus, 4K video, 16 MP binned, options overlay, fewer buffers for 64 MP (0012); GStreamer source with Venus and digital zoom |
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
| `90-m52xq-lang` (user environment generator), `m52xq-session-lang` | `LANG`/`LANGUAGE` of the user session from the account language |
| `m52xq-voicecall`, `m52xq-voice-mixers.sh`, `m52xq-tfa-guard`, `m52xq-audio-rescue` | call audio routes and in-place device switch, amplifier retry, sound card rescue after boot |
| `m52xq-contacts-sync` (user) | Lomiri address book → vCards for the dialer |
| `m52xq-bt-firmware` | Bluetooth firmware load after the rfkill unblock |
| `m52xq-wpss-guard`, `m52xq-wpss-restart`, `m52xq-wl-reset` | Wi-Fi firmware crash guard and clean restart |
| `m52xq-zram` | 3 GB zram swap |
| `m52xq-ssh-hostkeys`, `m52xq-password-hint` | SSH host keys on the first boot; number pad for the 4-digit password |

## 11. Pitfalls (short)

- Most binaries from postmarketOS are musl and do not load on Ubuntu: everything hardware-related is rebuilt for glibc.
- Ubuntu 26.04 does not ship Qt5 `qmlscene`, `pkcon`, PackageKit-click, the Qt6 GStreamer plugin or the lomiri position plugin — built here.
- Do not install UBports dev packages on the phone: they downgrade systemd/libc.
- `losetup` always with `--sector-size 4096`; the zip from inside the archive folder.
- `pkill -f` inside an ssh command kills its own session.
- Editing launcher entries in `/custom/xdg/data/applications` makes Lomiri flicker — do not rewrite unchanged files.

## 12. Credits
Ubuntu, UBports and Lomiri; postmarketOS; KDE (plasma-dialer, Spacebar, KPeople); the mainline Linux developers for Qualcomm SC7280/QCM6490.
