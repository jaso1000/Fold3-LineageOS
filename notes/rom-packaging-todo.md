# ROM build plan and TODO

Things deliberately deferred because they need source/framework changes, plus everything
currently delivered via Magisk that must be baked in. See notes/procedure.md for root causes.

## Plan (decided 2026-09-24)
- **Route**: build the LineageOS 23.2 TrebleDroid GSI **from source** (MisterZtr/LineageOS_gsi
  manifest + TrebleDroid patches) with our changes as extra patches. A device-tree build (like the
  Fold5 Exynoobs ROM) and official LineageOS status come later, if ever.
- **Target firmware**: F926BXXSJJZH3 is Samsung's **final** Fold3 firmware (Aug 2026 patch;
  support ended Sep 2026). Vendor, kernel and bootloader stay frozen there; users flash it first.
- **Machine**: Windows desktop, WSL2 Ubuntu 24.04. Source inside the Linux filesystem (not
  `/mnt/c`), about 400 GB free on NVMe, `.wslconfig` memory 32–48 GB, most cores, swap 32 GB. Exclude
  the WSL disk from Defender. Attach the phone to WSL with usbipd-win (Odin stays on Windows).
  Run Claude Code inside Ubuntu with this repo cloned there.
- **Identity**: unofficial build name, own release keys (kept out of the repo, backed up), vanilla
  (GApps flashed separately), releases on this repo's GitHub Releases (kept for the ROM).
- **Milestones**
  1. Reproduce the current GSI from source, unchanged; it must boot identically.
  2. Bake in everything under "Must bake in" (no Magisk needed).
  3. Framework fixes below (signal bars first; they're proven).
  4. Clean-install test on the phone, then release notes, XDA thread, licence notes (Floss GPLv2).
- **Before building**: finish the open README checklist items (reboots, idle calls, battery,
  Android Auto, NFC, headphones, call features) so problems are attributed correctly.
- **Release blocker**: confirm emergency calling (000/112) works over VoLTE (IMS emergency via
  Floss). There's no 3G fallback in Australia. If it doesn't work, it must be fixed or carry a
  prominent warning.

## Must bake in (currently Magisk modules / manual steps)
- [ ] libpowermanager miscpower mode -1 (outer touch) — source fix in phh's frameworks/native patch
- [ ] Samsung Codec2 seccomp `mremap` rule (storage/media/fingerprint) — bind-mount at boot
- [ ] device_state_configuration.xml lid-switch fix (dual-screen) — bind-mount at boot
- [ ] Floss IMS (`floss-ims/`) as priv-app + privapp-permissions + hidden-API exemptions
- [ ] GSF runtime permissions (default-permissions XML)
- [ ] `pm disable com.android.phone/.security.SafetySourceReceiver` (boot ANR mitigation) — or fix properly
- [ ] IMS APN + carrier_volte_available: make automatic per SIM, not hand-set for 505-01

## Framework fixes to do in source
- [ ] **Signal bars**: in RadioNetworkProxy's HIDL `ISehRadioIndication.signalLevelInfoChanged`
      (TrebleDroid patch 0009, currently log-only), turn `SehSignalBar.lteLevel/nrLevel` into a
      SignalStrength and deliver it like `currentSignalStrength` (SignalStrengthController). Also
      send `CA_ENABLED=1` with `FW_READY=1`. Proven with `tools/seh-signal`; see procedure.md.
- [ ] Resend SET_UNSOLICITED_RESPONSE_FILTER / device state when the radio becomes available
      (DeviceStateMonitor caches the failed boot-time send)
- [ ] Phone/rild startup: phone process blocks in IRadio.getService during rild's slow init
      → "failed to complete startup" ANR loop. Consider more HwBinder threads / async RIL init.
- [ ] Fingerprint: send setActiveGroup before the boot-time InternalCleanupClient enumerate and
      after every HAL/rild restart (currently module fold3-fingerprint-fix, which can still lose
      the race: if the HAL dies at boot, the framework re-enumerates ~1.4 s later and drops the
      enrollment). Fix it in the HIDL fingerprint provider (HidlToAidlSessionAdapter).

## Floss IMS for other carriers
- [ ] Emergency calls over IMS (emergency PDN/APN, SOS URN, emergency registration). Verify
      without dialling 000 (logs/code), then fix if missing.
- [ ] Call waiting / hold / conference, voicemail MWI, USSD over IMS, Wi-Fi calling (ePDG)
- [ ] Precondition fallback: offer QoS preconditions, retry without on 400/420/421 (Telstra rejects them)
- [ ] Test on other carriers (Optus, Vodafone AU, overseas)
- [ ] AMR-WB/EVS (HD voice), SMS delivery-report handling (RP-ACK currently fed as a dummy status report); proper uplink gain instead of AGC

## Cosmetic / later
- [ ] Outer-screen boot logo: at boot, power off the inactive panel via DisplayManager so HWC sends it a real display-off (the bootloader leaves it lit, `dpms=On`). Don't flip device state. Try `cmd display power-off/power-reset` first. See procedure.md.

## Added 2026-09-24 evening
- [ ] Hotspot DNS: TetheringNext never starts a DNS proxy → currently DNAT to 8.8.8.8 (module fold3-net-fixes)
- [ ] Fold device-state config (foldedDeviceStates/postures/display_features) — RRO overlays/Fold3FrameworkOverlay
- [ ] Auto-brightness + double tap to wake (RRO values) and DT2W: set `aot_enable` from the power HAL's DOUBLE_TAP_TO_WAKE mode (or an init/settings trigger) instead of the polling helper
- [ ] Always-on display: bake in the doze RRO values + AOD brightness 0.15; give the outer panel proper doze brightness in the framework instead of the helper
- [ ] Outer display brightness: lights HAL/framework path for the second panel (currently a polling helper writing panel1-backlight)
- [ ] Adaptive refresh rate: make it ramp to 120 Hz on interaction (DisplayModeDirector / peak refresh config, touch boost) instead of forcing min = 120 Hz
- [ ] Cameras: set `persist.sys.phh.samsung.camera_ids=true` (or LineageOS samsung camera provider with `EXTRA_IDS`) and ship the Aperture aux-camera overlay
- [ ] Play Integrity: built-in certified-props spoof (PIHooks/PixelPropsUtils-style, GMS DroidGuard only) so RCS gets BASIC without root; optional user-supplied keybox
