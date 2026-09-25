# LineageOS on Galaxy Z Fold3 (SM-F926B, "q2q")

Getting LineageOS (Android 16 GSI) running as a daily driver on a Samsung Galaxy Z Fold3, working
toward a packaged ROM later.

Device: Samsung Galaxy Z Fold3, SM-F926B (Australian variant), codename **q2q**, Snapdragon 888 (SM8350).

## Status: Android 16 daily driver (updated 2026-09-24)

Running on Samsung's **final** Fold3 firmware, F926BXXSJJZH3 (August 2026 patch). Samsung ended
all updates for the Fold3 in September 2026.

LineageOS 23.2 (Android 16) TrebleDroid GSI + BiTGApps Core, rooted with Magisk, on the stock
Samsung Android 15 vendor (`F926BXXSJJZH3`). Nearly everything works, including **VoLTE calls on
Telstra/Boost** and both screens. Fixes are delivered as small Magisk modules (ready-made zips in
[`prebuilt/`](prebuilt/), sources in `magisk-src/` and `scripts/`, the patched VoLTE app in
[`floss-ims/`](floss-ims/)); the root-cause writeups are in
[notes/procedure.md](notes/procedure.md), and what still has to happen for a real ROM build is in
[notes/rom-packaging-todo.md](notes/rom-packaging-todo.md).

### Fixes in place

| Problem | Root cause (short) | Fix | Where |
|---|---|---|---|
| Outer screen stuck on the boot logo / no display switching | `<lid-switch>` condition in Samsung's device-state config never true | Edited `device_state_configuration.xml` in vendor | vendor image built by `scripts/make-vendor-image.sh` |
| Outer touchscreen dead | GSI calls Samsung miscpower HAL with hard-coded "main display" mode | Patch 2 instructions in `libpowermanager.so` (mode -1) | module `fold3-outer-touch` (`scripts/make-outer-touch-module.sh`) |
| No `/sdcard`, no media/"speakers", Google sign-in fails, fingerprint gone | Samsung Codec2 HAL killed by its seccomp policy (`mremap`), hanging MediaCodecList and StorageManagerService | Widen that one seccomp rule | module `fold3-media-c2-seccomp` (`scripts/make-media-c2-seccomp-module.sh`) |
| Google sign-in "Checking info" | GSF missing runtime permissions (BiTGApps Core) | `pm grant` GSF permissions | manual (TODO: default-permissions XML) |
| No calls (Telstra has no 3G) | No IMS stack usable with Samsung's vendor | phh's Floss IMS, **patched**: direct-200/early-media handling, conditional preconditions, RFC 3966 `+CC` numbers, SMS SMSC decoding, BYE both directions, caller ID, real P-ANI, VoIP audio mode, RNNoise bypass + AGC, jitter buffer, all AMR modes, DTMF, re-register alarm, priv-app permissions | module `fold3-floss-ims` (source `floss-ims/`, changes in `patches/floss-ims/`, `scripts/make-floss-module.sh`) + IMS APN + `carrier_volte_available` override |
| Phone app / no network after boot (ANR loop) | Phone blocks on slow rild init at startup | Disabled `com.android.phone/.security.SafetySourceReceiver`; recovers on its own now | manual `pm disable` (root cause still open) |
| Hotspot "connected, no internet" | Tethering never starts a DNS proxy; clients' DNS goes nowhere | DNAT hotspot DNS to 8.8.8.8 | module `fold3-net-fixes` |
| Cover-screen selfie camera shows the inner camera; no Flex mode in apps | GSI has no folded/open device-state config, so camera HAL never told "folded" | Framework RRO with fold states, postures and hinge feature (`config_display_features` is a plain string, not an array) | module `fold3-fold-config` (`overlays/Fold3FrameworkOverlay`) |
| Only main camera usable; no ultra-wide / telephoto | Samsung's camera provider hides aux lenses from `getCameraIdList`; Aperture has aux cameras disabled | `persist.sys.phh.samsung.camera_ids=true` (GSI asks via `sehGetCameraIdList`) + Aperture RRO enabling aux cameras, ignoring logical/duplicate ids | module `fold3-fold-config` (`overlays/Fold3ApertureOverlay`, `scripts/make-overlays.sh`) |
| Outer screen brightness never changes | Only one backlight light (inner); Samsung HWC ignores per-display brightness | Helper mirrors live brightness to `panel1-backlight` | module `fold3-fold-config` (`service.sh`) |
| No auto-brightness, double tap to wake or always-on display | The GSI ships Samsung SM8350's brightness curve but leaves `config_automatic_brightness_available` off; double-tap isn't wired to the touch drivers | RRO turns on auto-brightness, the double-tap setting and AOD (doze), with AOD brightness raised from 1/255 to 15%; helper sends `aot_enable,<0/1>` to both touch panels (`/sys/class/sec/tsp1`, `tsp2`) following the setting | module `fold3-fold-config` (overlay + `service.sh`) |
| Fingerprint sensor stops detecting / enrollment lost | Samsung HAL loses its active user after boot and after every rild restart; Android only sends `setActiveGroup` once | Re-send `setActiveGroup` the moment the HAL starts (before system_server touches it), on every HAL restart, and after rild restarts | module `fold3-fingerprint-fix` (`tools/fp-active-group/`) |

Disabled: `fold3-boot-splash` (cleared the outer-screen boot logo but killed the fingerprint HAL).
Recovery if a module ever breaks boot: hold **Volume Down** during boot = Magisk safe mode.
Don't `ctl.restart ril-daemon` to fix a slow phone start — it breaks the fingerprint HAL (the fingerprint module repairs it, but the phone app recovers on its own within ~1–2 min anyway).

### Test checklist

✅ works · ⚠️ known issue · ☐ not tested yet

**Calls & messaging**
- ✅ Outgoing calls (voicemail, local and +61 numbers incl. call-log callbacks), audio both ways, clean hang-up
- ✅ Keypad tones (DTMF) in calls
- ✅ Call audio smooth (jitter buffer)
- ✅ Incoming calls: ring, caller ID, answer, audio both ways, hang up from either side
- ✅ Incoming call with screen off / locked; decline; missed-call log
- ☐ Calls still work after 1–2+ h idle (re-registration fix)
- ⚠️ **Emergency calls (000/112): treat as NOT working.** Android routes 000 to VoLTE (Floss), but Floss has no emergency support (no emergency PDN, emergency registration or `urn:service:sos`). It goes out as a normal call, and whether Telstra connects it can't be tested safely. There's no 3G fallback in Australia. **Keep a stock phone for emergencies.** Groundwork done and verified (emergency PDN + emergency registration); the emergency call itself (INVITE `urn:service:sos`) isn't written yet (paused; see notes/procedure.md).
- ☐ Call waiting, hold/swap, merge into conference
- ☐ Voicemail notification (new-voicemail indicator)
- ☐ Wi-Fi calling (likely unsupported by Floss)
- ☐ USSD codes (e.g. balance checks)
- ✅ Speakerphone and Bluetooth audio in calls
- ✅ SMS send/receive (over IMS), MMS send/receive
- ☐ Long SMS (over 160 chars, multipart) and group MMS
- ✅ RCS chats in Google Messages (needs Play Integrity BASIC + number entered manually, see install step 5)
- ⚠️ Signal bars always show 0. Samsung's RIL only reports bars through its own `ISehRadio` callback. The fix is proven but left for the ROM build (a side service can hang the RIL).

**Data & connectivity**
- ✅ Mobile data, Wi-Fi, Bluetooth (headphones, controller), airplane mode
- ✅ Hotspot
- ✅ GPS / location
- ☐ NFC tag read
- ☐ eSIM (download/activate a profile)

**Display & fold**
- ✅ Inner/outer switching on fold, outer touch, rotation on both screens
- ✅ Brightness on both screens (outer follows the slider live)
- ✅ Screen on/off and lock screen on both screens
- ✅ Double-tap to wake on both screens (Settings toggle)
- ✅ Auto-brightness (Adaptive brightness) on both screens
- ✅ Always-on display on both screens (Settings → Always show time and info), with AOD brightness at about 15%
- ✅ Half-fold doesn't glitch
- ⚠️ Adaptive refresh doesn't ramp up to 120 Hz on its own — workaround: Settings → Display → **Minimum refresh rate = 120 Hz** (smooth, costs some battery)
- ✅ Flex mode in apps (YouTube half-folded)
- ⚠️ Samsung logo stays on the outer screen after boot (folded or unfolded) until the first fold/unfold. The cause is known (the bootloader leaves the idle panel lit); the fix is in the ROM build. Fold once after booting, because the static logo causes OLED image retention.

**Audio, camera & media**
- ✅ Speakers / media playback, microphone, screen recording, volume keys
- ✅ Rear main camera, inner (under-display) selfie, cover-screen selfie, flashlight
- ✅ Ultra-wide and telephoto: photos from every lens, video recording with sound
- ☐ Wired / USB-C headphones

**Sensors & hardware**
- ✅ Fingerprint (survives reboot; rarely the enrollment can still drop at boot if the HAL crashes, see procedure.md), haptics, proximity sensor, wireless charging
- ☐ S Pen (Fold edition, inner screen)
- ☐ Fast charging speed, reverse wireless charging

**System**
- ✅ Storage, Play Store / Google services, root
- ✅ Google sign-in, Play Store installs (Messages, YouTube)
- ✅ Play Integrity: BASIC (with PlayIntegrityFork); DEVICE/STRONG not expected with an unlocked bootloader
- ☐ Several reboots in a row: network up within ~1 min, fingerprint still enrolled
- ☐ Android Auto (installed, not yet tried in the car)
- ☐ Overnight battery drain
- ☐ A full day of normal use without crashes or lost network
- ☐ Alarms fire while locked / in Doze
- ⚠️ Banking apps / Wallet tap-to-pay: not used on this phone. Many banks' terms forbid modified or rooted OSes, and an unlocked bootloader only gets BASIC integrity. Keep banking on a stock, updated phone.

## Next: a real ROM build

The Magisk-module setup is feature-complete for daily use. What's left needs Android's own code
changed, so the next step is building the ROM from source: **LineageOS 23.2 TrebleDroid GSI source
+ this repo's fixes baked in**, on a Windows desktop under WSL2. It will fix signal bars, the
outer-screen boot logo, the fingerprint boot race, the phone app's slow start and adaptive 120 Hz,
add a built-in Play Integrity spoof (RCS without root), and need no root. The plan, milestones and
full to-do list are in [notes/rom-packaging-todo.md](notes/rom-packaging-todo.md). Releases will go to
this repo's GitHub Releases.

## Installing it yourself

> ⚠️ **Read first.** Unlocking the bootloader **wipes the phone** and **trips Knox permanently**
> (Samsung Pay/Wallet, Secure Folder, Samsung Health and some banking apps stop working, and
> it can't be undone). This is a working personal build, not a polished ROM — you can end up
> without a working phone. Only tested on the **SM-F926B** (global/Australian model)
> on firmware `F926BXXSJJZH3`, with Telstra/Boost for calls.

**Tools**
- Samsung firmware: [samloader-rs](https://github.com/topjohnwu/samloader-rs) — downloads the
  exact firmware straight from Samsung (`check-update -m SM-F926B -r <CSC>`, then `download`).
- Flashing from Download Mode: [Heimdall](https://github.com/Benjamin-Dobell/Heimdall) (Linux/macOS)
  or Odin (Windows).
- adb from Android platform-tools.

**1. Unlock the bootloader**
1. Enable Developer options → **OEM unlocking**.
2. Samsung blocks the real Download Mode screen while a lock-screen PIN/pattern/biometric is set
   (you get a "D2 error" screen). Set Lock screen to **None**, power off, then hold
   **Vol Up + Vol Down** and plug in USB.
3. Long-press Vol Up to unlock and confirm. The phone wipes and reboots; redo the setup and
   check OEM unlocking is still on.

**2. Custom recovery**
- Azkali's Fold3 (q2q) recovery: [XDA thread](https://xdaforums.com/t/orangefox-and-twrp-recovery-recovery-for-sm-f926b.4660021/),
  device tree on [GitLab](https://gitlab.com/azkali-samsung/q2q) (Azkali's own download page is
  down — we used a build made with [bm0x/twrp-actions-compiler](https://github.com/bm0x/twrp-actions-compiler)).
  Flash it (with a verification-disabled vbmeta) from Download Mode.
- Flash [**DynaPatch**](https://xdaforums.com/t/guide-direct-flashing-gsi-image-to-logical-partitions-on-samsung-galaxy-with-dynamic-partitions.4340947/)
  in the recovery. It adds **Install Image** support for the dynamic `system`/`vendor`
  partitions, so no fastboot is needed.
- The recovery **can't decrypt `/data`** on this firmware, so no recovery backups — keep the
  stock firmware (from samloader) as your way back.

**3. System (GSI) + Google apps**
1. Download the LineageOS 23.2 **VANILLA EXT4** GSI from
   [MisterZtr/LineageOS_gsi](https://github.com/MisterZtr/LineageOS_gsi/releases) and grow the
   image (`truncate -s +1700M system.img && e2fsck -f system.img && resize2fs system.img`) so the
   GApps installer has room.
2. `adb push` it to `/tmp` in recovery → Install → Install Image → **System**.
3. Install [BiTGApps](https://bitgapps.io) **Core** for Android 16 (arm64) as a normal zip.
   (MindTheGapps' setup wizard hangs on this phone.)
4. **Format Data**, reboot.

**4. Dual-screen vendor fix**
Extract the stock `vendor.img` from the JJZH3 AP (`super.img.lz4` → `lz4 -d` → `simg2img` →
`lpunpack -p vendor`), then run `scripts/make-vendor-image.sh vendor.img vendor-patched.img`. That
replaces `/vendor/etc/devicestate/device_state_configuration.xml` with Samsung's own `sec/` version
**with every `<lid-switch>` condition removed**. Flash it from TWRP (Install Image → Vendor, or
`dd` to `/dev/block/mapper/vendor`). Details: [notes/procedure.md](notes/procedure.md#dual-screen-switching-vendor-edit).

**5. Root + fixes**
1. Extract `boot.img` from the **exact** firmware your phone runs (samloader), patch it with
   [Magisk](https://github.com/topjohnwu/Magisk), flash via Install Image → Boot, open the Magisk
   app once. (A boot.img from any other firmware version fails Samsung's "Secure check".)
2. Install this repo's Magisk modules: the zips in [`prebuilt/`](prebuilt/) (or rebuild them with
   `scripts/make-*-module.sh`), plus `fold3-media-c2-seccomp`, which you build from your own phone
   with `scripts/make-media-c2-seccomp-module.sh`. Then do the manual steps listed in the table (GSF permissions, IMS APN +
   `carrier_volte_available`, disabling `SafetySourceReceiver`).
3. Calls: the Floss IMS module + carrier setup in
   [notes/procedure.md](notes/procedure.md#volte-calls--module-fold3-floss-ims--manual-carrier-setup).
   Carriers other than Telstra/Boost are untested.
4. RCS (optional): enable Zygisk in Magisk, install
   [PlayIntegrityFork](https://github.com/osm0sis/PlayIntegrityFork) and run its action
   (`autopif4.sh`) to fetch a current Pixel beta profile (expires every ~6 weeks; re-run then).
   Install Google Messages + Carrier Services, enter your number in Messages → Settings →
   Advanced → Phone number (the SIM doesn't carry it), then toggle RCS chats off/on.

## Tooling

- adb/fastboot: `~/Android/sdk/platform-tools/` (not on PATH by default); root shell via `adb shell su -c`.
- Module builders: `scripts/make-*-module.sh`, `scripts/make-overlays.sh`, `scripts/make-vendor-image.sh`;
  prebuilt zips in `prebuilt/`; Floss IMS source in `floss-ims/` (GPLv2, phh), our changes vs
  upstream `phhusson/ims@c180bdf` as patches in `patches/floss-ims/`; overlay source in `overlays/`.
- Floss build SDK: `build/src/floss-sdk` (android-33 platform with MmTelFeature stripped, build-tools 34).
- Prototypes kept for the ROM build: `tools/seh-signal/` (signal bars via Samsung ISehRadio),
  `tools/fp-active-group/` (fingerprint setActiveGroup).
- Laptop: Surface, Arch Linux (Omarchy). ROM build machine: Windows desktop with WSL2 (planned).

## References

- LineageOS 23.2 GSI: https://github.com/MisterZtr/LineageOS_gsi
- Fold3 recovery (Azkali): https://xdaforums.com/t/orangefox-and-twrp-recovery-recovery-for-sm-f926b.4660021/ · https://gitlab.com/azkali-samsung/q2q
- DynaPatch (flash GSIs to dynamic partitions): https://xdaforums.com/t/guide-direct-flashing-gsi-image-to-logical-partitions-on-samsung-galaxy-with-dynamic-partitions.4340947/
- samloader-rs: https://github.com/topjohnwu/samloader-rs · Heimdall: https://github.com/Benjamin-Dobell/Heimdall · Magisk: https://github.com/topjohnwu/Magisk
- BiTGApps: https://bitgapps.io
- Floss IMS (phh): https://github.com/phhusson/ims · TrebleDroid: https://github.com/TrebleDroid/treble_experimentations
- q2q kernel source (driver analysis): https://github.com/cawilliamson/android_kernel_samsung_q2q
- Reference device trees: Exynoobs sm8550-common / q5q (Fold5), samsung-sm8350
- Fold3 XDA forum: https://xdaforums.com/f/samsung-galaxy-z-fold3.12349/
