# Fold3 (q2q) on LineageOS 23.2 GSI — reference

How the phone is built, and the root cause + fix for every problem solved so far. Status and the
test checklist live in the [README](../README.md); what must be baked into a real ROM is in
[rom-packaging-todo.md](rom-packaging-todo.md). Full investigation history is in git.

## Device & firmware

- Samsung Galaxy Z Fold3 **SM-F926B** (Australia, XSA/VAU), codename **q2q**, Snapdragon 888
  (SM8350 / "lahaina"). Stock firmware on the phone: **`F926BXXSJJZH3`** (Android 15).
- Displays: inner `local:4630947232161729154` (port 130, 1768×2208), outer
  `local:4630947232161729155` (port 131, 832×2268).
- Device states (Samsung `device_state_configuration.xml`): 0 CLOSE, 1 TENT, 2 HALF_FOLDED,
  3 OPEN, 4 DUAL, 5 REAR_DUAL.
- **Always flash matching firmware**, especially `boot`: `samloader check-update -m SM-F926B -r VAU`,
  then `samloader download -m SM-F926B -r VAU -v <version> -d <dir>` (Samsung's own server,
  decrypts automatically). A May-2026 `F926BXXSIJZE5` boot.img failed Samsung's "Secure check";
  recovery/vendor/system from it were fine. Exact-match images are kept in
  `build/current-firmware-extracted/` (gitignored).

## Unlock & recovery

- **Download Mode**: with any lock-screen security set, Vol Up+Down+USB lands on a "D2 error"
  screen. Set lock screen to None, power off, then Vol Up+Down+USB → real unlock/flash screen.
  Unlocking trips Knox permanently (Pay/Wallet, Secure Folder, Health gone).
- Patching stock recovery to expose fastbootd (raidenii/recv-vbmeta-patcher) **did not work**
  on this firmware — not needed anyway.
- **Recovery**: Azkali's q2q TWRP (CI mirror build via bm0x/twrp-actions-compiler) + **DynaPatch**
  v2.1 → "Install Image" can write the dynamic `system`/`vendor` partitions. TWRP **cannot
  decrypt `/data`** (`unable to override ro.crypto.dm.default_key`) — no TWRP backups; Format
  Data works.
- `adb push` images to `/tmp` in TWRP (RAM tmpfs, ~5 GB).

## Flashing the GSI + GApps

1. System: LineageOS 23.2 vanilla EXT4 GSI, **grown** first (`truncate` + `resize2fs`, ~1.7 GB
   headroom) so the GApps installer has space → Install Image → System.
2. GApps: `BiTGApps-arm64-16.0.0-*-CORE.zip` via TWRP Install. Don't splice GApps on the PC —
   `cp`/`sed -i` drop `security.selinux` xattrs. MindTheGapps / the GAPPS GSI hang in Google's
   SetupWizard, very likely because of the Codec2 bug below (unconfirmed).
3. Vendor: stock plus the device-state edit (next section). Install Image does **not** grow a
   logical partition; the stock vendor ext4 reports 0 bytes free — growing the image by 64 KiB
   (`truncate`+`resize2fs`, within the ~72 KiB slack) makes it writable.
4. Format Data, boot.
5. **Magisk**: patch the *exact-match* `boot.img`, flash it via Install Image → Boot, open the
   Magisk app once. Root shell: `adb shell "su -c '...'"` — quote the whole thing, or
   redirections run as the shell user.

## Fixes

### Dual-screen switching (vendor edit)
- **Symptom**: outer screen frozen on the boot logo; folding never switches displays.
- **Cause**: the GSI replaces only `system`; Samsung's real device-state/display-layout configs
  in vendor are fine, except every state is AND-gated on a `<lid-switch>` condition and the lid
  switch stays "open" forever, so CLOSE is unreachable.
- **Fix**: `/vendor/etc/devicestate/device_state_configuration.xml` = Samsung's `sec/` 6-state
  sensor config with the `<lid-switch>` conditions removed (`scripts/make-vendor-image.sh`).
- **Verify**: `dumpsys device_state` → CLOSE when folded; `dumpsys display` → outer ON/active.
- **Current image (2026-09-24)**: stock **JJZH3** vendor (final firmware, vendor patch 2026-08-05)
  with only this one file replaced (mode 0644, root, `u:object_r:vendor_configs_file:s0`), via
  `debugfs -w` (rm / write / set_inode_field / ea_set), flashed from TWRP with
  `dd of=/dev/block/mapper/vendor`. The JJZH3 vendor is exactly the partition size. Before this the
  vendor was still ZE5 (May) under a JJZH3 kernel. The stock device_state and c2 seccomp files
  are identical between ZE5 and JJZH3.
- After flashing from TWRP the phone may boot back into recovery once; use TWRP's
  Reboot → System.
- Harmless: `qmi_helpers: disagrees about version of symbol module_layout` in dmesg comes from
  netmgrd.rc also running `modprobe -d /vendor/lib/modules/5.4-gki rmnet_shs` (the GKI variant)
  after the qgki one succeeds. Stock does the same.

### Outer touchscreen — module `fold3-outer-touch`
- **Cause**: Samsung's `vendor.samsung.hardware.miscpower@2.0` HAL enables/disables touch panels
  on screen on/off via `setInteractiveAsync(on, mode)`: mode 0 = inner only (tsp2 disabled),
  1 = outer only, -1 = all. The GSI's `libpowermanager.so` passes a hard-coded 0 from
  `AidlHalWrapper::setMode(INTERACTIVE)` (0x28810) and `HidlHalWrapperSeh::setInteractive`
  (0x298e0).
- **Fix**: patch both `mov w2, wzr` → `mov w2, #-1` (`scripts/make-outer-touch-module.sh`
  verifies the lib's sha256 first). InputReader ignores the inactive display's panel.
- Only path into full touch mode is the driver's `input_open` (via the `enabled` sysfs node);
  the kernel's HALL/fold logic alone only reaches LP (gesture) mode.

### Storage, media, "no speakers", fingerprint, Google sign-in — module `fold3-media-c2-seccomp`
- **Cause chain**: Samsung's software Codec2 HAL (`samsung.software.media.c2@1.0-service`,
  `IComponentStore/default0`) is killed by its vendor seccomp policy (`blocked syscall: mremap`
  — policy allows only `arg3 == 3`, the A16 allocator uses `MREMAP_MAYMOVE`) → MediaCodecList
  blocks forever waiting for `default0` → StorageManagerService's handler thread hangs in
  `configureTranscoding → isHevcDecoderSupported` at boot → `/sdcard` never mounts, no media
  playback, GMS can't write storage, fingerprint HAL can't finish.
- **Fix**: widen that rule to `mremap: arg3 == 3 || arg3 == MREMAP_MAYMOVE` (same as AOSP
  `mediacodec.policy`), overlaid on `/vendor/etc/seccomp_policy/samsung.software.media.c2-base-policy`.
- This also explains the old "audio/fingerprint only work on Android 14 GSIs" pattern.

### Google sign-in permissions (manual)
BiTGApps Core doesn't pre-grant GSF: `pm grant com.google.android.gsf android.permission.{GET_ACCOUNTS,READ_CONTACTS,WRITE_CONTACTS,READ_PHONE_STATE}`.

### VoLTE calls — module `fold3-floss-ims` + manual carrier setup
- **Why Floss**: Telstra/Boost have no 3G. Samsung's vendor excludes all Qualcomm IMS HALs
  (`vendor.samsung.hardware.radio.exclude.qcom.xml`) and this A15 vendor has no QTI IMS radio
  libs; Samsung IMS (`com.sec.imsservice`) lived in One UI's system partition. The Fold5
  LineageOS route (`org.codeaurora.ims` + QTI IMS HAL from newer vendor firmware) isn't
  available here. phh's Floss IMS does SIP/IPsec/RTP itself and only needs data + SIM AKA.
- **Carrier setup** (Boost, 505-01): IMS APN `ims` (type ims, IPV4V6);
  `cmd phone cc set-value -s 0 -p carrier_volte_available_bool true` (root, persistent);
  `setprop persist.sys.phh.ims.floss true`;
  `cmd overlay enable me.phh.treble.overlay.flossims_telephony`.
- **Our build** (source in `floss-ims/` = `phhusson/ims` main @ c180bdf + `patches/floss-ims/`, `scripts/make-floss-module.sh`):
  - handle a direct `200 OK`+SDP answer (start RTP, `callSessionInitiated`), send BYE on hangup,
    route remote BYE/rejects to the active call's listener;
  - `P-Access-Network-Info` from the serving LTE cell in REGISTER (Telstra 403s without it);
  - no QoS precondition lines/`Supported: precondition` (Telstra 400s them for normal numbers);
  - ~200 ms playback buffer + silence prefill, all AMR-NB modes, real Q bit, drain decoder;
  - RFC 4733 DTMF (start/stop/sendDtmf → telephone-event packets in the encode thread);
  - explicit periodic re-REGISTER alarm every 30 min (implicit broadcast never arrived → lapsed at 1 h);
  - fix upstream syntax error; prebuilt `librnnoise_jni.so` instead of the submodule.
- **Runs as a priv-app** (we can't sign with the TrebleDroid key the GSI trusts as platform):
  no `sharedUserId=system`; privapp-permissions READ_PRIVILEGED_PHONE_STATE,
  CONNECTIVITY_USE_RESTRICTED_NETWORKS, MODIFY_PHONE_STATE, **CAPTURE_AUDIO_OUTPUT** (else the mic
  is silenced in calls); runtime grants RECORD_AUDIO, READ_PHONE_STATE, ACCESS_FINE_LOCATION;
  `hidden_api_blacklist_exemptions` for exactly the 3 `getFileDescriptor$` methods (service.sh).
  Uninstall phh's release first (`pm uninstall me.phh.ims`).
- ImsMedia is **not** needed (Floss's ImsMedia path is disabled upstream).

### Incoming calls, two-way audio (Floss patch 0004)
- **Incoming dropped instantly**: our 183 demanded `Require: precondition` (and QoS SDP lines)
  though the caller didn't offer it → Telstra CANCELs. Now only if the INVITE offers it; send
  180 Ringing after the early-media 183 is PRACKed.
- **No caller ID**: missing `EXTRA_OIR` → presentation unknown; set OIR/CNAP.
- **Hang-up ignored / 481**: each response got a random To-tag; now one local tag per dialog,
  and the callee BYE uses commonHeaders (Via/Route/Security-Verify) to the INVITE Contact.
- **Other side couldn't hear us** — three stacked causes, found with per-second uplink logging:
  1. Telecom used `MODE_IN_CALL`, so Samsung's HAL started the modem voice path
     (`voicemmode1-call`) and kept it even after a later mode change → call
     `MmTelFeature.setCallAudioHandler(AUDIO_HANDLER_ANDROID)` (the A16 name of
     notifyAudioHandlerChanged) **when each call is created** → `MODE_IN_COMMUNICATION`.
     (In that mode the HAL uses its DSP `compress_voip` path, which works fine.)
  2. RNNoise (48 kHz model) fed 8 kHz audio output pure silence → bypassed.
  3. Capture level ~-50 dBFS → simple AGC (target ~2500 rms, max 32×). Confirmed clear.

- **Callbacks / +61 numbers never connected** (patch 0005): Floss appended `;phone-context=` to
  every tel URI; for a global `+CC` number that's invalid (RFC 3966) and Telstra silently drops
  the INVITE (no 100 Trying; hang-up gets 481). Global numbers now go as plain `tel:+61...`.

- **SMS stuck on "Sending"** (patch 0006): the framework passes the SIM's SMSC as a hex SM-RP
  address (`07 81 ...`), Telstra's ISIM has no SMSC SIP URI, and Floss's fallback crashed on
  `Rlog.d(tag, msg, throwable)` (gone in A16) without resolving the send token. Now the hex SMSC
  is decoded, throwables go through `android.util.Log`, and any failure reports "not sent".
  Receiving already worked (incoming MESSAGE over IMS is injected into the GSM inbound handler).

### RCS (Google Messages) — PlayIntegrityFork (third-party module, not in this repo)
- **Symptom**: RCS stuck on "Connecting". Messages log: `RequestWithMsisdnTokenState: event HTTP 400`
  → `Aborting UPI provisioning`, availability "Carrier RCS is not set up".
- **Causes**: (1) no MSISDN on the SIM (`Message identity not found`) → enter number manually in
  Messages; (2) the final ACS request carries a DroidGuard token and is rejected (400) without
  Play Integrity BASIC.
- **Fix**: Zygisk on + PlayIntegrityFork v18 + `autopif4.sh -m` (Pixel beta fingerprint) → BASIC
  → config request 200, `RcsAvailability: AVAILABLE`. DEVICE isn't needed for RCS here.

### Fingerprint keeps losing its user — module `fold3-fingerprint-fix`
- **Cause**: Samsung's HAL drops its active group after boot and after every **rild restart**
  (modem restart resets its secure-world session: `BAuth_SessionClose Fail`), then rejects
  enroll/auth with `gid != m_active_group -1`. The secure app (`securefp`) isn't even loaded until
  `setActiveGroup`. At boot keyguard starts a detect before that, the HAL dies, restarts empty, and
  the framework's boot cleanup enumerates 0 templates and deletes "Finger 1" from
  `settings_fingerprint.xml` (log: `Removing dangling template from framework`).
- **Fix**: `service.sh` runs a tiny dex (`tools/fp-active-group/FpActiveGroup.java`, via
  `app_process` + services.jar's HIDL class) calling `setActiveGroup(0, /data/vendor_de/0/fpdata)`
  as soon as the HAL process exists (before system_server uses it), again on every HAL PID change,
  and 20 s after any rild PID change. A HAL template the framework lost is re-added by the next
  boot cleanup once the HAL enumerates correctly. Also: stop manually restarting rild.
- **Debugging**: logcat is cleared early in boot (even the HAL's own lines vanish), so the keeper
  logs to `/data/local/tmp/fold3-fp.log` (`.prev` = previous boot). A good boot looks like
  `set_group(initial) ... -> 0` a few seconds before the framework's `Fingerprint HAL ready`.
- **Remaining race**: if the HAL still dies during boot, app_process takes ~1.5 s to re-send the
  group while the framework re-enumerates ~1.4 s after the restart, so the enrollment can still
  be dropped. A proper fix belongs in the framework (ROM build): send setActiveGroup before
  the cleanup enumerate / after every HAL restart.

### Phone app / no network after boot (mitigated, manual)
- **Cause**: at boot the phone process blocks in `IRadio.getService()` during rild's slow init;
  a Safety Center broadcast then ANRs → killed → rild restarts (its rc also restarts
  cpboot-daemon) → "failed to complete startup" ANR loop.
- **Mitigation**: `pm disable com.android.phone/.security.SafetySourceReceiver`; now it recovers
  after a few ANRs (~1 min). Avoid `setprop ctl.restart ril-daemon` — it breaks fingerprint.

### Hotspot "connected, no internet" — module `fold3-net-fixes`
- **Cause**: DHCP gives clients the phone as DNS, but TetheringNext always starts netd with
  `usingLegacyDnsProxy=false` and nothing listens on :53. No flag re-enables it.
- **Fix**: DNAT udp/tcp 53 arriving on `swlan0` to 8.8.8.8 (idempotent, at boot).

### Cover-screen selfie camera, Flex mode — module `fold3-fold-config` (RRO)
- **Cause**: the GSI's `config_foldedDeviceStates` etc. are empty, so CameraService reports
  NORMAL to the camera HAL and Samsung's HAL keeps camera id 1 on the inner UDC sensor.
- **Fix**: framework RRO `overlays/Fold3FrameworkOverlay`: folded [0], halfFolded [1,2], open [3],
  `config_device_state_postures` 0:1 1:2 2:2 3:3, hinge `fold-[884,0,884,2208]`
  (`config_display_features` is a `<string>` in AOSP; as a string-array the RRO silently didn't
  apply and apps like YouTube never got a FoldingFeature).
  Camera ids: 0 back main, 1 front (cover when folded), 2 back, 3 front UDC, 4 secure (face).

### Ultra-wide / telephoto — module `fold3-fold-config` (system.prop + Aperture RRO)
- **Cause**: Samsung's provider only returns ids 0-4 from `getCameraIdList`; the rest are only
  in `ISehCameraProvider::sehGetCameraIdList`. Aperture also ships `config_enableAuxCameras=false`.
  (`persist.sys.phh.include_all_cameras` does nothing here.)
- **Fix**: `persist.sys.phh.samsung.camera_ids=true` makes the GSI's cameraserver use the Samsung
  list: 0 main (5 mm), 2 ultra-wide (1.74 mm), 52 tele (6 mm), 20/21/23 logical multi-cams,
  1 front (fold-routed), 3 inner UDC, 4 secure, 71/73/92 alt front modes. Aperture RRO
  (`overlays/Fold3ApertureOverlay`) enables aux cameras and ignores 3, 20, 21, 23, 71, 73, 92.
  Build overlays with `scripts/make-overlays.sh`.

### Outer screen brightness — module `fold3-fold-config` (service.sh)
- **Cause**: Lights HAL has one backlight light, attached to the first (inner) display only;
  Samsung HWC ignores per-display brightness (the `canSetBrightnessViaHwc` quirk in
  `/product/etc/displayconfig/display_id_...155.xml` doesn't help).
- **Fix**: helper writes `/sys/class/backlight/panel1-backlight` (= brightness × 510) while the
  outer panel is lit; reads `mTemporaryScreenBrightness` from `dumpsys display` so it follows
  the slider live (0.3 s poll, only while folded).

### Auto-brightness, double tap to wake — module `fold3-fold-config` (RRO + service.sh)
- **Auto-brightness**: the light sensor (AMS TMD4907, `android.sensor.light`) works and the GSI already
  carries Samsung SM8350's curve (`config_autoBrightnessLevels`/`DisplayValuesNits`,
  `config_screenBrightnessNits`/`Backlight`, same as LineageOS samsung-sm8350), but
  `config_automatic_brightness_available` was false. The RRO sets it to true. The outer panel follows
  via the brightness helper.
- **Double tap to wake**: both Samsung touch drivers support the sec_input command `aot_enable,1`
  (`/sys/class/sec/tsp1` = inner stm_ts_spi, `tsp2` = outer stm_ts; `doubletap_enable` returns NA).
  In low-power mode a double tap reports `KEY_WAKEUP`, which Android handles natively. The RRO sets
  `config_supportDoubleTapWake=true` (Settings toggle, `secure double_tap_to_wake`), and service.sh
  writes `aot_enable,<setting>` to both panels at boot, on change, and every ~60 s.

### Always-on display — module `fold3-fold-config` (RRO + service.sh)
- The GSI already sets `config_dozeComponent` (SystemUI DozeService) and `config_dozeAlwaysOnEnabled`,
  but `config_dozeAlwaysOnDisplayAvailable` was false. The RRO sets it (plus
  `config_dozeAfterScreenOffByDefault`, as in samsung-sm8350). HWC/panel doze works on both panels.
- AOD brightness: the GSI's `config_screenBrightnessDoze` = 1/255 (float 0.0) put the inner panel
  at 2/510 (barely visible). The RRO sets 38 / 0.15 (inner reads 78/510 in AOD). The outer panel's
  brightness helper uses the same 0.15 while `dumpsys display` shows `mPowerRequest=policy=DOZE`,
  instead of copying the normal brightness.

### USB-C dock / desktop mode — module `fold3-desktop`
- **Symptom**: the dock only charges. No keyboard, mouse or hub, no monitor. Once USB worked, the monitor
  only mirrored the phone.
- **Cause 1 (USB host + DisplayPort)**: PD negotiates fine (the dock sends DR_SWAP, the phone becomes DFP), but
  Samsung's `usb_notify` refuses host mode: `usb_notify: now restricted, skip this command`,
  `/proc/usblog` USB EVENT shows `host_id blocking`. Its lock state `usb_sl` starts as
  `SKY_DEFAULT` (init), which counts as restricted. On One UI, services.jar's
  `com.android.server.usb.UsbHostRestrictor` writes `SUNNY_WORK_MODE` (unlocked),
  `CLOUDY_WORK_MODE` (locked, USB allowed) or `RAINY_RESTRICT_MODE` (locked, USB blocked).
  Numeric writes are rejected from init (`disallow input`). Writing `SUNNY_WORK_MODE` gives xHCI host
  mode, the dock's hubs and HID devices, and DP alt mode (`card0-DP-1` connected). (Earlier red herrings: the
  typec `data_role` file, `disable` = OFF, and the max77705 alternate-mode READY gate.)
- **Cause 2 (mirror instead of desktop)**: the external display must be enabled (Android 16 may add it
  disabled, and then it mirrors) and desktop mode needs `enable_freeform_support=1`,
  `force_desktop_mode_on_external_displays=1`, and developer option **Enable desktop experience features**
  (`override_desktop_experience_features=1` plus `persist.wm.debug.desktop_experience_devopts=1`,
  read at boot).
- **Fix**: the module sets the prop in post-fs-data. service.sh re-applies the settings, runs
  `cmd display enable-display <id>` for disabled HDMI/DP displays, and drives `usb_sl` with stock's
  rules (decompiled from One UI services.jar `UsbHostRestrictor`): `deviceLocked` from `dumpsys trust`
  (only true with a secure lock screen) gives `RAINY_RESTRICT_MODE`, or `CLOUDY_WORK_MODE` if
  Settings.Secure `block_usb_lock=0` (stock default 1); unlocked gives `SUNNY_WORK_MODE`. Stock's post-lock
  timer and MDM/SIM/DeX policy hooks are omitted.
- **Unlock after plugging in while locked**: in RAINY the host starts but new devices get
  `authorized=0` (the dock's hubs). On unlock the driver only re-enumerates when there's no hub and no PD
  contract, and re-authorizing fails (`no configuration chosen`, the allowlist still refuses). So the
  helper does a software re-plug: `echo ON_HOST_REPLUG > usb_control/disable; echo OFF > ...`, and DP stays
  up. Reading `usb_sl` logs a kernel line each time, so the helper caches its last write.

- **Remembered devices (stock behaviour)**: devices plugged in while locked are refused
  (`usb_match_any_interface_for_id: FAIL, it's not in whitelist`, interfaces "not authorized for
  usage") unless they're in the lock-screen allowlist. One UI keeps a history of devices used while
  unlocked (`/efs/usb_con_hist`, `vid:pid` lines) and writes `VPID:vid:pid:vid:pid...` to
  `usb_control/whitelist_for_mdm`. The helper does the same with `/data/adb/fold3-usb-history`
  (last 60), pushed at boot and on change.

### USB-C headphones — module `fold3-usb-audio`
- **Symptom**: digital USB-C earbuds enumerate (ALSA card, inline buttons work) but there's no sound.
- **Cause**: audioserver loads `/vendor/etc/audio_policy_configuration.xml` (generic: primary + a2dpsink +
  r_submix, no USB), giving `could not find HW module for device AUDIO_DEVICE_OUT_USB_HEADSET`. Adding
  the plain `usb` module routes audio there, but with `vendor.audio.feature.usb_offload.enable=true` the
  ADSP owns the playback PCM (`cannot open /dev/snd/pcmC1D0p`). Disabling offload let the AP stream
  run, but it was silent. One UI loads `audio_policy_configuration_sec.xml`, whose **primary** module
  lists the USB headset ports (the DSP offload path).
- **Fix**: post-fs-data bind-mounts `_sec` over the default policy (no Samsung file shipped).
  Speaker, Bluetooth and call routes also come from Samsung's policy now, so re-test them.
- Unrelated: TrebleDroid's `me.phh.treble.app` crashes in `Desktop.kt:39` (NPE in onInputDeviceAdded)
  when a USB HID device appears. It's harmless and only affects that app.

### Android Auto — module `fold3-android-auto`
- "Communication error 22 - Android Auto was not preinstalled": since Android 10 Android Auto
  (`com.google.android.projection.gearhead`) must be a privileged system app. The script copies the
  installed base+split APKs into `/system/priv-app/AndroidAuto` and writes a privapp-permissions
  allowlist of every requested permission (`ro.control_privapp_permissions=log` here, so a gap can't
  bootloop). After a reboot the package shows `SYSTEM UPDATED_SYSTEM_APP` + `PRIVILEGED`, and Play
  updates install on top.

### Disabled: `fold3-boot-splash`
Flipping device state CLOSE→reset at boot cleared the outer-screen boot logo but kills Samsung's
fingerprint HAL; the restarted HAL never gets `setActiveGroup` → no sensor, and boot cleanup
then deletes the enrolled fingerprint. Kept in `magisk-src/`, disabled on the phone.

## Known issues

- **Emergency calls (analysed 2026-09-25, no call placed)**: 000 is in the emergency number list
  (db, au). Carrier config for 505-01: `carrier_use_ims_first_for_emergency_bool=true`,
  emergency over IMS on EUTRAN, domain preference [PS, CS, ...]. The GSI has no OEM domain
  selection service (`useOemDomainSelectionService=true`, none present), so the legacy path
  sends 000 to ImsPhone, i.e. Floss. Floss ignores `SERVICE_TYPE_EMERGENCY` and sends a normal INVITE
  to `tel:000;phone-context=...` on the normal registration: no EIMS PDN, no emergency
  REGISTER (`sos` Contact parameter), no `urn:service:sos`. It then depends on whether Telstra's P-CSCF
  routes a non-UE-detected emergency call or rejects it (380 Alternative Service). The CS retry
  has no 3G in Australia. The network advertises emergency bearer support (`mEmcBearerSupport = 1`).
  Plan: EIMS PDN, then emergency REGISTER, then INVITE `urn:service:sos[.police|.ambulance|.fire]`,
  plus correct failure codes on 380. Test PDN + REGISTER only; **never dial 000 to test**.
- **Progress (Floss patch 0007, v20)**: `SipHandler(emergency = true)` and a DUMP-protected
  `EmergencyTestReceiver` (`am broadcast -a me.phh.ims.EMERGENCY_TEST --es step pdn|register -n
  me.phh.ims/.EmergencyTestReceiver`). Verified on Telstra: the EIMS PDN (APN `sos`) comes up in <1 s with
  two emergency P-CSCFs; emergency REGISTER with `;sos` goes 401 → AKA/IPsec → **200 OK**
  (network-assigned expires=300); then de-REGISTER and release. Normal registration unaffected.
  Still to do (the final INVITE can't be tested): INVITE `urn:service:sos` on the emergency
  registration with P-Access-Network-Info, wired to `SERVICE_TYPE_EMERGENCY`; 380 handling.

- **Signal bars 0**: Samsung rild never fills the standard signal indication (the framework's
  SignalStrengthController receives nothing; `GET_CELL_INFO_LIST` fails with error 63; cell info
  only arrives twice at boot). It reports bars **only** through Samsung's HIDL
  `ISehRadioIndication.signalLevelInfoChanged(SehSignalBar{lteLevel, nrLevel, ...})`, every
  2–15 s. The GSI's telephony (TrebleDroid patch "Initialize Samsung HIDL ISehRadio") registers
  for it and sends `FW_READY=1` but just logs and drops it. Proven on-device (2026-09-24,
  `tools/seh-signal`): registering for it gets `lte=4` reports, and pushing a SignalStrength into
  `ITelephonyRegistry.notifySignalStrengthForPhoneId` (as root) shows bars in the status bar.
  **Not shipped as a module**: rild keeps a single ISehRadio client, restarts itself when that
  client dies, and hangs (killing data) if a two-way call like `needSettingValueIndication` isn't
  answered. The first boot version didn't start the hwbinder thread pool, so rild hung. The fix
  belongs in the ROM: in the GSI's `signalLevelInfoChanged` handler (RadioNetworkProxy), build an
  LTE/NR SignalStrength from the bar level and feed it to SignalStrengthController.
- **Outer-screen boot logo** stays until the first fold (also on a folded boot). Cause (2026-09-24):
  the bootloader lights both panels; Android never powers the inactive one on, so it never sends it a
  display-off. The kernel shows the connector as `enabled=disabled` but `dpms=On`
  (`/sys/class/drm/card0-DSI-2`), and the panel keeps its last frame. Setting
  `panel1-backlight/brightness` to 0 does **not** hide it. `SurfaceControl.getPhysicalDisplayToken`
  moved to services.jar `DisplayControl` (natives only load inside system_server), so an external
  SurfaceFlinger power-cycle isn't practical. Untested lead: `cmd display power-off <id>` /
  `power-reset <id>` on the disabled logical display (unfolded: outer = display 2). ROM fix: power
  the inactive panel off once at boot (DisplayManager/DisplayPowerController), without touching
  device state (the old device-state override killed the fingerprint HAL). Keep test reboots to a
  minimum: the static logo causes OLED image retention.
- **Phone first-start ANR** still happens once per boot (recovers).
- **Refresh rate**: adaptive mode didn't seem to reach 120 Hz when interacting. Workaround in use:
  Settings → Display → Minimum refresh rate → 120 Hz (always 120 Hz; more battery). Not
  investigated yet — likely the GSI's refresh-rate policy (peak/min refresh config, touch boost)
  vs Samsung's panel modes (the kernel logs 48/96/120 Hz VRR/LFD modes).

## Debugging tips

- Input event numbers change between boots — find panels via `/sys/class/input/input*/name`
  (`sec_touchscreen` = inner, `sec_touchscreen2` = outer; `/sys/class/sec/tsp` = virtual).
- After replacing an APK through a Magisk overlay, clear `/data/system/package_cache/*` and
  reboot, or PackageManager keeps the old parse.
- Floss logs: tags `PHH SipHandler`, `PHH MmTelFeature`, `PHH SipChallenge`.
- Stuck system_server/phone thread: `kill -3 <pid>` → `/data/anr/`; native: `debuggerd -b <pid>`.
- Kernel source for driver work: `cawilliamson/android_kernel_samsung_q2q` (`drivers/input/sec_input/stm_fold`).
