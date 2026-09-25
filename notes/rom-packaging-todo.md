# ROM build plan and TODO

Things deliberately deferred because they need source/framework changes, plus everything
currently delivered via Magisk that must be baked in. See notes/procedure.md for root causes.

## Plan (decided 2026-09-24)
- **Route**: build the LineageOS 23.2 TrebleDroid GSI **from source** (MisterZtr/LineageOS_gsi
  manifest + TrebleDroid patches) with our changes as extra patches. A device-tree build (like the
  Fold5 Exynoobs ROM) and official LineageOS status come later, if ever.
- **Target firmware**: F926BXXSJJZH3 is Samsung's **final** Fold3 firmware (Aug 2026 patch;
  support ended Sep 2026). Vendor, kernel and bootloader stay frozen there; users flash it first.
- **Machine**: Windows desktop, WSL2 Ubuntu 24.04. Run Claude Code inside Ubuntu with this repo
  cloned there. Attach the phone to WSL with usbipd-win (Odin stays on Windows).
  - **Storage (updated 2026-09-25)**: the desktop's internal SSD is short on space, so the WSL
    distro goes on an **external USB HDD** (NTFS, USB 3 port):
    `wsl --install -d Ubuntu-24.04 --location E:\WSL` (or `wsl --manage Ubuntu-24.04 --move`).
    Exclude that folder from Defender. Run `wsl --shutdown` before unplugging.
  - **Hybrid layout if the SSD has ~100–150 GB free**: source (mostly read) on the HDD; `out/` and
    ccache (heavy writes) on a second VHDX on the internal SSD, attached with `wsl --mount --vhd`.
  - HDD tuning: shallow sync (`repo init --depth=1`, `repo sync -c --no-tags -j4`), large
    `.wslconfig` memory so the page cache hides seek latency, keep WSL running between builds.
    Expect sync 3–6 h, first build 6–10+ h, incrementals 15–40 min.
  - Desktop (checked 2026-09-25): Ryzen 7 5800X (8C/16T), 32 GB RAM, C: = Samsung 980 PRO 1 TB
    NVMe with ~358 GB free, E: = Seagate 1 TB USB HDD (empty). WSL not installed yet.
    → `.wslconfig`: memory ~26 GB, 16 processors, swap 32 GB (swap file on C:).
    → Use the hybrid layout: source on E:, `out/` + ccache in a ~150 GB VHDX on C:.
  - Fallbacks: apply to **Crave.io** (free ROM build servers, invite-only) in parallel; buy a 1 TB
    SSD (~AUD 100–150) if HDD iteration is too slow. Hetzner Cloud doubled its prices in June 2026
    (CCX33 ~€165/mo), so it's no longer a cheap option; cloud spot VMs are the paid fallback.
- **Identity**: unofficial build name, own release keys (kept out of the repo, backed up), vanilla
  (GApps flashed separately), releases on this repo's GitHub Releases (kept for the ROM).
- **Scope (confirmed 2026-09-25)**: the full plan — every fix built in, not just a GSI rebuild with
  Magisk modules on top. Main reason: MisterZtr's last GSI release is 2026-05-24, so building our own
  is the only way to keep getting LineageOS monthly security patches for the Android layer
  (vendor/kernel stay frozen at Samsung's Aug 2026 patch either way).
- **Root (decided 2026-09-25)**: the ROM ships **without root** and nothing in it depends on
  Magisk. Development builds are userdebug, so Developer options → Rooted debugging gives `adb root`
  for logs and testing. Full root stays optional: the ROM only replaces `system`, so a
  Magisk-patched stock `boot.img` works on top exactly as it does now. RCS gets BASIC integrity
  from the built-in Play Integrity spoof, not PlayIntegrityFork.
- **Milestones**
  1. Reproduce the current GSI from source, unchanged; it must boot identically.
     **Done 2026-09-26**: built in 4 h 39 min (`lineage_arm64_bvN4-bp4a-userdebug`, MisterZtr tag
     v2026.05.24, security patch 2026-09-01), flashed over the May GSI without wiping data, with
     MindTheGapps instead of BiTGApps. Calls/data, storage, fingerprint, Google apps all fine.
     `libpowermanager.so` is byte-identical to the May build, so `fold3-outer-touch` still applies.
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
- [x] Samsung Codec2 seccomp `mremap` rule (storage/media/fingerprint) — **already upstream**:
      TrebleDroid device_phh_treble merged the same fix on 2026-07-26 (rw-system.sh bind-mounts a
      copy of the policy with `mremap: arg3 == 3` → `mremap: 1`; the JJZH3 vendor has exactly that
      line). Only confirm on the first boot of our build that the module isn't needed.
- [ ] device_state_configuration.xml lid-switch fix (dual-screen) — bind-mount at boot
- [ ] Floss IMS (`floss-ims/`) as priv-app + privapp-permissions + hidden-API exemptions
- [x] GSF runtime permissions — MindTheGapps ships them (switched from BiTGApps 2026-09-26)
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
- [ ] Emergency calls over IMS: EIMS PDN + emergency REGISTER done and verified (Floss patch 0007).
      Remaining: INVITE `urn:service:sos[.type]` with P-Access-Network-Info on the emergency
      registration, wired to SERVICE_TYPE_EMERGENCY; fallback to the normal registration; 380
      handling. Never test by dialling 000. Paused 2026-09-25.
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
- [ ] Always-on display: bake in the doze RRO values + AOD brightness 0.15 (inner) / 0.10 (outer, `persist.fold3.outer_aod`); give the outer panel proper doze brightness in the framework instead of the helper
- [ ] Outer display brightness: lights HAL/framework path for the second panel (currently a polling helper writing panel1-backlight)
- [ ] Adaptive refresh rate (decided 2026-09-26: ship as an opt-in quirk, Minimum refresh rate = 120 Hz). Not SurfaceFlinger props: content detection + 200 ms touch timer are already the defaults. If revisited, look at DisplayModeDirector votes / Samsung panel modes (48/96/120 Hz VRR/LFD)
- [ ] Cameras: set `persist.sys.phh.samsung.camera_ids=true` (or LineageOS samsung camera provider with `EXTRA_IDS`) and ship the Aperture aux-camera overlay
- [ ] USB-C dock/desktop: port the fold3-desktop logic into the framework (UsbHostRestrictor-like keyguard listener instead of polling; host re-plug on unlock), default the desktop-experience flags on, and handle the external display "mirror or extend" prompt properly
- [ ] USB-C audio: make audioserver load Samsung's `audio_policy_configuration_sec.xml` (or merge its primary USB ports) instead of the bind mount
- [ ] Fix TrebleDroid app crash in Desktop.kt onInputDeviceAdded (null InputDevice) if we keep that app
- [ ] Android Auto: GApps flavour for the ROM should include it as a priv-app (or document fold3-android-auto)
- [ ] Play Integrity: built-in certified-props spoof (PIHooks/PixelPropsUtils-style, GMS DroidGuard only) so RCS gets BASIC without root; optional user-supplied keybox
