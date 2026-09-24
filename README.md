# LineageOS on Galaxy Z Fold3 (SM-F926B, "q2q")

Getting LineageOS (Android 16 GSI) running as a daily driver on a Samsung Galaxy Z Fold3, working
toward a packaged ROM later.

Device: Samsung Galaxy Z Fold3, SM-F926B (Australian variant), codename **q2q**, Snapdragon 888 (SM8350).

## Status: Android 16 daily driver (updated 2026-09-24)

LineageOS 23.2 (Android 16) TrebleDroid GSI + BiTGApps Core, rooted with Magisk, on the stock
Samsung A15 vendor (`F926BXXSJJZH3`). Nearly everything works, including **VoLTE calls on
Telstra/Boost** and both screens. Fixes are delivered as small Magisk modules, built by
`scripts/` or kept in `magisk-src/`; the root-cause writeups are in
[notes/procedure.md](notes/procedure.md), and what still has to happen for a real ROM build is in
[notes/rom-packaging-todo.md](notes/rom-packaging-todo.md).

### Fixes in place

| Problem | Root cause (short) | Fix | Where |
|---|---|---|---|
| Outer screen stuck on the boot logo / no display switching | `<lid-switch>` condition in Samsung's device-state config never true | Edited `device_state_configuration.xml` in vendor | hand-patched vendor image |
| Outer touchscreen dead | GSI calls Samsung miscpower HAL with hard-coded "main display" mode | Patch 2 instructions in `libpowermanager.so` (mode -1) | module `fold3-outer-touch` (`scripts/make-outer-touch-module.sh`) |
| No `/sdcard`, no media/"speakers", Google sign-in fails, fingerprint gone | Samsung Codec2 HAL killed by its seccomp policy (`mremap`), hanging MediaCodecList and StorageManagerService | Widen that one seccomp rule | module `fold3-media-c2-seccomp` (`scripts/make-media-c2-seccomp-module.sh`) |
| Google sign-in "Checking info" | GSF missing runtime permissions (BiTGApps Core) | `pm grant` GSF permissions | manual (TODO: default-permissions XML) |
| No calls (Telstra has no 3G) | No IMS stack usable with Samsung's vendor | phh's Floss IMS, **patched**: direct-200 answer handling, BYE, real P-ANI, no preconditions, jitter buffer, all AMR modes, DTMF, re-register alarm, priv-app permissions | module `fold3-floss-ims` (`patches/floss-ims/`, `scripts/make-floss-module.sh`) + IMS APN + `carrier_volte_available` override |
| Phone app / no network after boot (ANR loop) | Phone blocks on slow rild init at startup | Disabled `com.android.phone/.security.SafetySourceReceiver`; recovers on its own now | manual `pm disable` (root cause still open) |
| Hotspot "connected, no internet" | Tethering never starts a DNS proxy; clients' DNS goes nowhere | DNAT hotspot DNS to 8.8.8.8 | module `fold3-net-fixes` |
| Cover-screen selfie camera shows the inner camera | GSI has no folded/open device-state config, so camera HAL never told "folded" | Framework RRO with fold states, postures and hinge feature | module `fold3-fold-config` (`overlays/Fold3FrameworkOverlay`) |
| Outer screen brightness never changes | Only one backlight light (inner); Samsung HWC ignores per-display brightness | Helper mirrors live brightness to `panel1-backlight` | module `fold3-fold-config` (`service.sh`) |

Disabled: `fold3-boot-splash` (cleared the outer-screen boot logo but killed the fingerprint HAL).
Recovery if a module ever breaks boot: hold **Volume Down** during boot = Magisk safe mode.

### Test checklist

✅ works · ⚠️ known issue · ☐ not tested yet

**Calls & messaging**
- ✅ Outgoing calls (voicemail + real numbers), audio both ways, clean hang-up
- ✅ Keypad tones (DTMF) in calls
- ✅ Call audio smooth (jitter buffer)
- ☐ Incoming call (answer, audio both ways, hang up)
- ☐ Incoming call with screen off / locked; decline; missed-call log
- ☐ Calls still work after 1–2+ h idle (re-registration fix)
- ☐ Speakerphone + Bluetooth audio during a call
- ☐ SMS send/receive, MMS
- ⚠️ Signal bars always show 0 (Samsung RIL returns empty signal strength) — deferred to ROM build

**Data & connectivity**
- ✅ Mobile data, Wi-Fi, Bluetooth (headphones, controller), airplane mode
- ✅ Hotspot
- ✅ GPS / location
- ☐ NFC tag read

**Display & fold**
- ✅ Inner/outer switching on fold, outer touch, rotation on both screens
- ✅ Brightness on both screens (outer follows the slider live)
- ✅ Screen on/off and lock screen on both screens
- ✅ Half-fold doesn't glitch
- ⚠️ Adaptive refresh doesn't ramp up to 120 Hz on its own — workaround: Settings → Display → **Minimum refresh rate = 120 Hz** (smooth, costs some battery)
- ☐ Flex mode in apps (e.g. YouTube half-folded)
- ⚠️ Samsung logo stays on the outer screen after an unfolded boot until the first fold

**Audio, camera & media**
- ✅ Speakers / media playback, microphone, screen recording, volume keys
- ✅ Rear main camera, inner (under-display) selfie, cover-screen selfie, flashlight
- ☐ Other rear lenses (ultra-wide / tele), video recording with sound
- ☐ Wired / USB-C headphones

**Sensors & hardware**
- ✅ Fingerprint (survives reboot), haptics, proximity sensor, wireless charging
- ☐ S Pen, reverse wireless charging, fast charging speed

**System**
- ✅ Storage, Play Store / Google services, root
- ☐ Google sign-in completed end to end
- ☐ Several reboots in a row: network up within ~1 min each time
- ☐ Overnight battery drain
- ☐ Banking apps (may refuse: Knox tripped + Magisk)

## How the phone is set up

1. Bootloader unlocked (Knox tripped — Samsung Pay/Wallet, Secure Folder, Health are gone).
2. Recovery: Azkali's q2q TWRP (CI mirror build) patched with
   [DynaPatch](https://xdaforums.com/t/guide-direct-flashing-gsi-image-to-logical-partitions-on-samsung-galaxy-with-dynamic-partitions.4340947/)
   for "Install Image" on dynamic partitions (no fastboot needed). TWRP can't decrypt `/data`.
3. System: LineageOS 23.2 TrebleDroid GSI, grown with `truncate` + `resize2fs` so the GApps zip
   fits, flashed via Install Image → System.
4. GApps: BiTGApps Core zip via TWRP Install (MindTheGapps' SetupWizard hangs — very likely the
   Codec2 bug below, unconfirmed).
5. Vendor: stock `F926BXXSJJZH3` plus the hand-edited `device_state_configuration.xml`.
6. Format Data, boot, then Magisk (boot image patched from the **exact-match** firmware boot.img —
   a mismatched boot.img fails Samsung's "Secure check").
7. Install the Magisk modules in the table above (`scripts/` builds them), plus the manual steps:
   GSF `pm grant`s, IMS APN + carrier config override, `pm disable` SafetySourceReceiver.

Firmware: `samloader check-update -m SM-F926B -r VAU` / `samloader download ...` pulls the exact
matching firmware straight from Samsung — use it before flashing any partition (esp. `boot`).
Step-by-step details and every root-cause investigation: [notes/procedure.md](notes/procedure.md).

## Tooling

- adb/fastboot: `~/Android/sdk/platform-tools/` (not on PATH by default); root shell via `adb shell su -c`.
- Module builders: `scripts/make-*-module.sh`; Floss IMS source + patches in `build/src/floss-ims`
  and `patches/floss-ims/`; framework overlay source in `overlays/`.
- Floss build SDK: `build/src/floss-sdk` (android-33 platform with MmTelFeature stripped, build-tools 34).
- Laptop: Surface, Arch Linux (Omarchy).

## References

- Floss IMS (phh): https://github.com/phhusson/ims
- TrebleDroid GSIs: https://github.com/TrebleDroid/treble_experimentations
- q2q kernel source used for driver analysis: https://github.com/cawilliamson/android_kernel_samsung_q2q
- Samsung LineageOS trees used as reference: Exynoobs sm8550-common / q5q (Fold5), samsung-sm8350
- Fold3 forum: https://xdaforums.com/f/samsung-galaxy-z-fold3.12349/
