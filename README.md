# samsung-m52xq-ubuntu-lomiri

**"Classic": Ubuntu 26.04 LTS + Lomiri (Ubuntu Touch, UBports 26.04-1.x)** on a **mainline Linux kernel** for the
**Samsung Galaxy M52 5G** (codename `m52xq`, SM-M526B / SM-M526BR, Qualcomm Snapdragon 778G / SM7325).

A real Ubuntu arm64 root built with debootstrap, Lomiri 0.6.2 from UBports, mainline Linux 7.1.2 (build #430) — no Halium,
no libhybris, no Android HAL. The hardware layer comes from
[samsung-m52xq-mainline](https://github.com/korryasdlerto-lgtm/samsung-m52xq-mainline) and
[samsung-m52xq-postmarketos-lomiri](https://github.com/korryasdlerto-lgtm/samsung-m52xq-postmarketos-lomiri), rebuilt for glibc.
Personal, unofficial project, tested on one SM-M526B.

**Status (build "classic v2", 2026-10-29):** Lomiri with GPU in apps, two SIMs, calls and SMS, mobile data, GPS in apps, Wi-Fi,
Bluetooth and BT audio, auto-rotation, OpenStore (click apps), Venus video in the player, suspend. Camera partial.

## Videos

| | |
|---|---|
| Ubuntu Touch 26.04 on the M52 | https://www.youtube.com/watch?v=xJV4l0g4Kwc |
| Going back to Android | https://www.youtube.com/watch?v=0lgLbtdl4rA |

## Manuals

| Language | Markdown | Word |
|---|---|---|
| English | [docs/MANUAL-EN.md](docs/MANUAL-EN.md) | [docs/M52-ubuntu-26.04-lomiri-manual-EN.docx](docs/M52-ubuntu-26.04-lomiri-manual-EN.docx) |
| Русский | [docs/MANUAL-RU.md](docs/MANUAL-RU.md) | [docs/M52-ubuntu-26.04-lomiri-manual-RU.docx](docs/M52-ubuntu-26.04-lomiri-manual-RU.docx) |

Step-by-step build commands with output (Russian): [docs/ИНСТРУКЦИЯ.md](docs/ИНСТРУКЦИЯ.md); change log: [docs/ПРАВКИ.md](docs/ПРАВКИ.md).

## Kernel

Release **[kernel-7.1.2-430](../../releases/tag/kernel-7.1.2-430)**: `boot_v241_nfc.img`, `vendor_boot_v238_nfc_se9.img`, `Image`,
`config-7.1.2-430`, `modules-7.1.2-430.tar.gz` (Ubuntu layout `usr/lib/modules`), `SHA256SUMS`.
Source: [sc7280-mainline-linux-m52xq](https://github.com/korryasdlerto-lgtm/sc7280-mainline-linux-m52xq).

## Layout

| Folder | Contents |
|---|---|
| `installer/` | TWRP installer (`META-INF`, three image chunks) |
| `rootfs-overlay/` | v2 files over the root; binaries listed in `EXCLUDED-FILES.txt` |
| `apply-fixes.sh` | applies the overlay and packages to a mounted image |
| `image/` | debootstrap / UBports / image / hardware-layer scripts |
| `build/` | sources, patches and build scripts (Mesa EGL, ModemManager DSDS, plasma-dialer, Spacebar, camera, Qt6 GStreamer, Qt5 qmlscene, location plugin, …) |
| `docs/` | manuals (EN/RU), step-by-step instructions, change log |

The flashable zip and the image are not in the repository: the v2 root is a snapshot of the test phone and contains its personal data.
Build your own with the manual, sections 7–9.
