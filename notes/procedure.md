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
  sensor config with the `<lid-switch>` conditions removed (hand-patched vendor image).
- **Verify**: `dumpsys device_state` → CLOSE when folded; `dumpsys display` → outer ON/active.

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
- **Our build** (`phhusson/ims` main @ c180bdf + `patches/floss-ims/`, `scripts/make-floss-module.sh`):
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

### Fingerprint keeps losing its user — module `fold3-fingerprint-fix`
- **Cause**: Samsung's HAL drops its active group after boot and after every **rild restart**
  (modem restart resets its secure-world session: `BAuth_SessionClose Fail`), then rejects
  enroll/auth with `gid != m_active_group -1`; boot cleanup may then delete the enrolment.
- **Fix**: `service.sh` runs a tiny dex (`tools/fp-active-group/FpActiveGroup.java`, via
  `app_process` + services.jar's HIDL class) calling `setActiveGroup(0, /data/vendor_de/0/fpdata)`
  ~30 s after boot and 20 s after any rild PID change. Also: stop manually restarting rild.

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
  `config_device_state_postures` 0:1 1:2 2:2 3:3, hinge `fold-[884,0,884,2208]`.
  Camera ids: 0 back main, 1 front (cover when folded), 2 back, 3 front UDC, 4 secure (face).

### Outer screen brightness — module `fold3-fold-config` (service.sh)
- **Cause**: Lights HAL has one backlight light, attached to the first (inner) display only;
  Samsung HWC ignores per-display brightness (the `canSetBrightnessViaHwc` quirk in
  `/product/etc/displayconfig/display_id_...155.xml` doesn't help).
- **Fix**: helper writes `/sys/class/backlight/panel1-backlight` (= brightness × 510) while the
  outer panel is lit; reads `mTemporaryScreenBrightness` from `dumpsys display` so it follows
  the slider live (0.3 s poll, only while folded).

### Disabled: `fold3-boot-splash`
Flipping device state CLOSE→reset at boot cleared the outer-screen boot logo but kills Samsung's
fingerprint HAL; the restarted HAL never gets `setActiveGroup` → no sensor, and boot cleanup
then deletes the enrolled fingerprint. Kept in `magisk-src/`, disabled on the phone.

## Known issues

- **Signal bars 0**: Samsung rild returns an all-invalid SignalStrength and never sends signal
  indications (though `UNSOL_CELL_INFO_LIST` has real values); `FW_READY` is already sent by the
  GSI. Needs a telephony framework change (telephony-common is in the boot image) → ROM build.
- **Outer-screen boot logo** stays until the first fold (needs a fix that doesn't change device state).
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
