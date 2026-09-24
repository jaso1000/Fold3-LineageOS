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
| No calls (Telstra has no 3G) | No IMS stack usable with Samsung's vendor | phh's Floss IMS, **patched**: direct-200/early-media handling, conditional preconditions, BYE both directions, caller ID, real P-ANI, VoIP audio mode, RNNoise bypass + AGC, jitter buffer, all AMR modes, DTMF, re-register alarm, priv-app permissions | module `fold3-floss-ims` (`patches/floss-ims/`, `scripts/make-floss-module.sh`) + IMS APN + `carrier_volte_available` override |
| Phone app / no network after boot (ANR loop) | Phone blocks on slow rild init at startup | Disabled `com.android.phone/.security.SafetySourceReceiver`; recovers on its own now | manual `pm disable` (root cause still open) |
| Hotspot "connected, no internet" | Tethering never starts a DNS proxy; clients' DNS goes nowhere | DNAT hotspot DNS to 8.8.8.8 | module `fold3-net-fixes` |
| Cover-screen selfie camera shows the inner camera | GSI has no folded/open device-state config, so camera HAL never told "folded" | Framework RRO with fold states, postures and hinge feature | module `fold3-fold-config` (`overlays/Fold3FrameworkOverlay`) |
| Outer screen brightness never changes | Only one backlight light (inner); Samsung HWC ignores per-display brightness | Helper mirrors live brightness to `panel1-backlight` | module `fold3-fold-config` (`service.sh`) |
| Fingerprint sensor stops detecting / enrollment lost | Samsung HAL loses its active user after boot and after every rild restart; Android only sends `setActiveGroup` once | Re-send `setActiveGroup` ~30 s after boot and after rild restarts | module `fold3-fingerprint-fix` (`tools/fp-active-group/`) |

Disabled: `fold3-boot-splash` (cleared the outer-screen boot logo but killed the fingerprint HAL).
Recovery if a module ever breaks boot: hold **Volume Down** during boot = Magisk safe mode.
Don't `ctl.restart ril-daemon` to fix a slow phone start — it breaks the fingerprint HAL (the fingerprint module repairs it, but the phone app recovers on its own within ~1–2 min anyway).

### Test checklist

✅ works · ⚠️ known issue · ☐ not tested yet

**Calls & messaging**
- ✅ Outgoing calls (voicemail + real numbers), audio both ways (other side hears you clearly), clean hang-up
- ✅ Keypad tones (DTMF) in calls
- ✅ Call audio smooth (jitter buffer)
- ✅ Incoming calls: ring, caller ID, answer, audio both ways, hang up from either side
- ☐ Incoming call with screen off / locked; decline; missed-call log
- ☐ Calls still work after 1–2+ h idle (re-registration fix)
- ☐ Speakerphone during a call (route switches in the HAL; not confirmed audible yet) + Bluetooth audio in calls
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
Replace `/vendor/etc/devicestate/device_state_configuration.xml` with Samsung's own
`/vendor/etc/devicestate/sec/device_state_configuration.xml` **with every `<lid-switch>`
condition removed**, on a copy of your stock `vendor.img` (grow it by 64 KiB first), and flash it
via Install Image → Vendor. Details: [notes/procedure.md](notes/procedure.md#dual-screen-switching-vendor-edit).

**5. Root + fixes**
1. Extract `boot.img` from the **exact** firmware your phone runs (samloader), patch it with
   [Magisk](https://github.com/topjohnwu/Magisk), flash via Install Image → Boot, open the Magisk
   app once. (A boot.img from any other firmware version fails Samsung's "Secure check".)
2. Build and install this repo's Magisk modules (see the table above; `scripts/make-*-module.sh`
   and `magisk-src/`), then do the manual steps listed in the table (GSF permissions, IMS APN +
   `carrier_volte_available`, disabling `SafetySourceReceiver`).
3. Calls: the Floss IMS module + carrier setup in
   [notes/procedure.md](notes/procedure.md#volte-calls--module-fold3-floss-ims--manual-carrier-setup).
   Carriers other than Telstra/Boost are untested.

## Tooling

- adb/fastboot: `~/Android/sdk/platform-tools/` (not on PATH by default); root shell via `adb shell su -c`.
- Module builders: `scripts/make-*-module.sh`; Floss IMS source + patches in `build/src/floss-ims`
  and `patches/floss-ims/`; framework overlay source in `overlays/`.
- Floss build SDK: `build/src/floss-sdk` (android-33 platform with MmTelFeature stripped, build-tools 34).
- Laptop: Surface, Arch Linux (Omarchy).

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
