# Changes in unofficial v1 (first public release)

Audience: users of the port and developers who want to know what changed since the previous build described in this
repository ("classic v2", 2026-10-29) and why.

| | classic v2 (2026-10-29, not published) | unofficial v1 (2026-11-09) |
|---|---|---|
| Kernel | 7.1.2 | 7.1.13 + ath11k, q6voice and panel patches (`kernel/patches/`) |
| Device tree | downstream-style DTB | DTB from the upstream-style `sm7325-samsung-m52xq.dts` + local nodes, RTC enabled (`device-tree/`) |
| dtbo | left as it was | replaced by `dtbo-frag` (one harmless fragment; the bootloader needs it for this DTB) |
| Image | snapshot of one phone with its personal data, 3 chunks | clean image: no personal data, keys or proprietary firmware, 2 chunks |
| Zip | not published | `ubuntu_touch_classic_26.04-m52xq-mainline-v1-UNOFFICIAL.zip`, md5 `a3343884846751530f4a590e23e9275e` |

A clean install is required: Format Data as described in the README.

## Installer and image

- **No proprietary firmware in the zip.** ADSP, modem, IPA, Venus, GPU zap shader, Bluetooth firmware and sensor configs are
  copied from the phone's own partitions during the install, as in the postmarketOS port.
- SSH host keys are created on the first boot (`m52xq-ssh-hostkeys.service`, ordered before `sockets.target`; an earlier
  ordering loop sometimes dropped `ssh`). The machine ID and Bluetooth address are per phone.
- The installer writes dtbo (`dtbo-frag`) itself. Booting after another port no longer ends in a boot loop.
- `/home` and `/opt/click.ubuntu.com` live on the userdata partition (`run-m52xq\x2drootsrc-userdata.mount`); click hooks
  give the folder back to the user (`click-system-hooks.service.d`).
- `~/.config` is created for the user before any session service (`tmpfiles.d/m52xq-user-config.conf`); before, it was
  owned by root and settings were not saved.
- Bluetooth was blocked on the first boot: the image had saved rfkill states from another phone. Now all are unblocked, and
  `m52xq-bt-firmware` waits for the unblock without a pipe that ended only on the next rfkill event.
- 3 GB zram swap (`m52xq-zram.service`).

## Kernel

- **Calls: speaker/earpiece switching without new voice sessions** (`m52xq-q6voice-in-place-device-switch.diff`). The audio
  DSP sometimes crashed and the phone rebooted when a new voice session was created during a call. The device is now switched
  in place, like the downstream driver does: pause the voice path, `VSS_IVOCPROC_CMD_SET_DEVICE_V3`, media format,
  calibration, start. Parameter `q6voice.device_switch` (on by default).
- **Display: no flash on network wake-ups** (`m52xq-panel-sleep-while-brightness-0.diff`). Resume woke the panel with full
  brightness before user space could keep it dark. The panel now stays asleep while the brightness is 0 and wakes when the
  brightness is set.
- **Wi-Fi off really sleeps** (`m52xq-ath11k-radio-off-power-save.diff`). With the radio switched off, nobody told the WCN6750
  firmware to enter power save, and it stayed awake all night. The AHB driver now sends `POWER_SAVE_ENTER` on suspend when the
  radio is off (86 s asleep out of 90 s in the test, before: 0).
- RTC (`pmk8350_rtc`) enabled in the device tree: alarms wake the phone from sleep.
- Updated from 7.1.2 to the 7.1.13 stable release, with the fixes of the postmarketOS port v2 (fuel gauge ADC name, Type-C
  interrupts in suspend, ath11k removal).

## Calls, contacts and audio

- **ModemManager crash on mobile data connects fixed** (`build/modemmanager/0104-…`): `transaction_complete()` called the
  completion callback after the transaction was freed. It crashed up to 8 times per boot, lost incoming calls and switched the
  SIM mode. Candidate for upstream ModemManager.
- **Dialer crash when it opened during a call fixed** (`build/kpeople`): two threads used one KPeople database connection
  (contact name and avatar) without a lock. Candidate for upstream KPeople.
- Incoming call: the dialer buttons work. When the dialer is in front, the call notification is hidden but the ringtone keeps
  playing; when it is not, the notification with buttons is shown.
- The call bar opens the running dialer (focus instead of a second start, which crashed it) and shows the call time and the
  number or contact name.
- Speaker and mute are reset at the end of a call (`plasma-dialer-0012`); the next call starts on the earpiece.
- Silent loudspeaker after several switches: the amplifier route is retried when the TFA9878 does not start
  (`m52xq-voicecall`, `m52xq-tfa-guard`); `m52xq-audio-rescue` re-binds the sound card if it is missing after boot.
- Contacts from the Lomiri address book are exported for the dialer (`m52xq-contacts-sync`); "Add contact" in the dialer opens
  the address book (`plasma-dialer-0013`).
- USSD dialog width and call buttons in landscape (`plasma-dialer-0010`).

## Shell and system

- **Language from the wizard is applied everywhere.** The stock wizard did not save the language when the list had no entry
  for the current locale. Now it always saves it (`Wizard/Pages/10-welcome.qml`). A systemd user environment generator and
  drop-ins for the indicators set `LANG`/`LANGUAGE` from the account, so the quick settings, Settings and apps follow the
  choice.
- Default language English, default keyboard English, 4-digit unlock code `1111`; the wizard always shows the Wi-Fi step and
  preselects the number code.
- Screen lock: the backlight goes off first, then the lock screen is drawn (no flash of the lock screen before blanking).
- The phone no longer locks by itself when a Wi-Fi password dialog or a notification closes.
- Sound over Bluetooth keeps the phone awake like local sound.
- Morph Browser keeps media playing in the background; the clock app has a landscape layout; the reboot and SIM menus are
  translated.
- Alarm clock: `lomiri-indicator-datetime` instead of the Ayatana one (it reads the clock app's alarms), wake-up through the
  RTC alarm.
- TELEports works: `libssl1.1` and `qml-module-lomiri-pushnotifications` are in the image.

## Camera

- Digital zoom up to 4x (pinch or slider) for the viewfinder, photos and video, done in the GStreamer source
  (`build/m52xqcamsrc`).
- 64 MP photos without running out of memory: fewer buffers for frames of 24 MP and more (`build/libcamera/patches/0012-…`,
  about 670 MB less) plus zram.
- Crash when switching front/rear fixed (libcamerasrc handler on a freed state); photos after a switch are no longer rotated.
- The zoom slider fits in landscape.

## Known issues

See the README: the keyboard after a rotation, TELEports calls, formats in the first session.
