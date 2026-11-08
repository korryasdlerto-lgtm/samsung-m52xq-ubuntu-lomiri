# Kernel

## Release unofficial v1: mainline Linux 7.1.13

- Source: [sc7280-mainline-linux-m52xq](https://github.com/korryasdlerto-lgtm/sc7280-mainline-linux-m52xq) (7.1.13) plus the patches in `patches/`:
  - `m52xq-q6voice-in-place-device-switch.diff`: speaker/earpiece switching in a call without new voice sessions
    (pause, `VSS_IVOCPROC_CMD_SET_DEVICE_V3`, media format, calibration, start), parameter `q6voice.device_switch` (default on).
    New voice sessions during a call sometimes crashed the audio DSP and rebooted the phone.
  - `m52xq-panel-sleep-while-brightness-0.diff`: the S6E3HAB panel stays asleep on resume while the brightness is 0 and wakes
    when the brightness is set (no flash on network wake-ups).
  - `m52xq-ath11k-radio-off-power-save.diff`: ath11k AHB sends `POWER_SAVE_ENTER` on suspend when the radio is off, so the
    WCN6750 firmware sleeps with Wi-Fi switched off (module parameter `m52xq_off_ps`, default 1).
- Config: `config-7.1.13`. Build: `make ARCH=arm64 LLVM=1 Image` (clang/LLD 22), then put the Image into the previous
  boot.img with `tools/repack_boot.py` of samsung-m52xq-mainline (the appended DTB tail is kept).
- Device tree of vendor_boot: `../device-tree/sm7325-samsung-m52xq-local.dts` (includes `sm7325-samsung-m52xq.dts`; RTC enabled).
- Binaries: release [kernel-7.1.13](../../../releases/tag/kernel-7.1.13) of this repository (boot.img without IPA firmware,
  vendor_boot.img, dtbo-frag.img, Image, config, modules in the Ubuntu layout `usr/lib/modules/7.1.13`, SHA256SUMS).
  `MODVERSIONS` is off: use the modules only with this Image.

## Earlier build: mainline Linux 7.1.2

Config `config-7.1.2-430`; binaries in release [kernel-7.1.2-430](../../../releases/tag/kernel-7.1.2-430).
