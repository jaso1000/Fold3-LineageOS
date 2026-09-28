# LineageOS on Galaxy Z Fold3 (SM-F926B, "q2q")

Unofficial LineageOS 23.2 (Android 16) for the Samsung Galaxy Z Fold3, built from source with the
Fold3 fixes built in. **Download: [Releases](https://github.com/jaso1000/Fold3-LineageOS/releases)**
(install steps below).

Device: Samsung Galaxy Z Fold3, SM-F926B (Australian variant), codename **q2q**, Snapdragon 888 (SM8350).

## Status (updated 2026-09-28)

**Latest build: [fold3-2026.09.28](https://github.com/jaso1000/Fold3-LineageOS/releases/tag/fold3-2026.09.28)**,
Android security patch 2026-09-01, on Samsung's **final** firmware F926BXXSJJZH3 (Samsung ended
Fold3 updates in September 2026). A TrebleDroid-based system image (MisterZtr's LineageOS GSI
patches) plus this repo's Fold3 changes (`rom/`): no Magisk modules needed, root optional. Daily
driver for the dev, including **VoLTE on Telstra/Boost**, both screens, signal bars, AOD and Android
Auto.

> ⚠️ **Emergency calls (000/112): untested.** SIP-level emergency tests pass on Telstra (emergency
> data connection and registration), but the dedicated emergency call isn't implemented yet, so
> 000 is sent as a normal VoLTE call, and no real emergency call has been made. **Don't rely on
> this phone for emergencies; keep another phone available.**

How each fix is built into the ROM: [rom/README.md](rom/README.md). Root-cause writeups:
[notes/procedure.md](notes/procedure.md). Plan and to-do: [notes/rom-packaging-todo.md](notes/rom-packaging-todo.md).
The table below is the original Magisk-module version of each fix (`magisk-src/`, `prebuilt/`),
kept for reference; the ROM contains all of them.

### Fixes in place

| Problem | Root cause (short) | Fix | Where |
|---|---|---|---|
| Outer screen stuck on the boot logo / no display switching | `<lid-switch>` condition in Samsung's device-state config never true | Edited `device_state_configuration.xml` in vendor | vendor image built by `scripts/make-vendor-image.sh` |
| Outer touchscreen dead | GSI calls Samsung miscpower HAL with hard-coded "main display" mode | Patch 2 instructions in `libpowermanager.so` (mode -1) | module `fold3-outer-touch` (`scripts/make-outer-touch-module.sh`) |
| No `/sdcard`, no media/"speakers", Google sign-in fails, fingerprint gone | Samsung Codec2 HAL killed by its seccomp policy (`mremap`), hanging MediaCodecList and StorageManagerService | Widen that one seccomp rule | module `fold3-media-c2-seccomp` (`scripts/make-media-c2-seccomp-module.sh`) |
| Google sign-in "Checking info" | GSF missing runtime permissions (BiTGApps Core) | Not needed with MindTheGapps (ships default permissions); with BiTGApps, `pm grant` GSF permissions | — |
| No calls (Telstra has no 3G) | No IMS stack usable with Samsung's vendor | phh's Floss IMS, **patched**: direct-200/early-media handling, conditional preconditions, RFC 3966 `+CC` numbers, SMS SMSC decoding, BYE both directions, caller ID, real P-ANI, VoIP audio mode, RNNoise bypass + AGC, jitter buffer, all AMR modes, DTMF, re-register alarm, priv-app permissions | module `fold3-floss-ims` (source `floss-ims/`, changes in `patches/floss-ims/`, `scripts/make-floss-module.sh`) + IMS APN + `carrier_volte_available` override |
| Phone app / no network after boot (ANR loop) | Phone blocks on slow rild init at startup | Disabled `com.android.phone/.security.SafetySourceReceiver`; recovers on its own now | manual `pm disable` (root cause still open) |
| Hotspot "connected, no internet" | Tethering never starts a DNS proxy; clients' DNS goes nowhere | DNAT hotspot DNS to 8.8.8.8 | module `fold3-net-fixes` |
| Cover-screen selfie camera shows the inner camera; no Flex mode in apps | GSI has no folded/open device-state config, so camera HAL never told "folded" | Framework RRO with fold states, postures and hinge feature (`config_display_features` is a plain string, not an array) | module `fold3-fold-config` (`overlays/Fold3FrameworkOverlay`) |
| Only main camera usable; no ultra-wide / telephoto | Samsung's camera provider hides aux lenses from `getCameraIdList`; Aperture has aux cameras disabled | `persist.sys.phh.samsung.camera_ids=true` (GSI asks via `sehGetCameraIdList`) + Aperture RRO enabling aux cameras, ignoring logical/duplicate ids | module `fold3-fold-config` (`overlays/Fold3ApertureOverlay`, `scripts/make-overlays.sh`) |
| Outer screen brightness never changes | Only one backlight light (inner); Samsung HWC ignores per-display brightness | Helper mirrors live brightness to `panel1-backlight` | module `fold3-fold-config` (`service.sh`) |
| No auto-brightness, double tap to wake or always-on display | The GSI ships Samsung SM8350's brightness curve but leaves `config_automatic_brightness_available` off; double-tap isn't wired to the touch drivers | RRO turns on auto-brightness, the double-tap setting and AOD (doze), with AOD brightness raised from 1/255 to 15% (inner) and 10% on the outer screen (`persist.fold3.outer_aod` to tune); helper sends `aot_enable,<0/1>` to both touch panels (`/sys/class/sec/tsp1`, `tsp2`) following the setting | module `fold3-fold-config` (overlay + `service.sh`) |
| USB-C dock: only charges (no keyboard/mouse, no monitor), then only mirrors | Samsung's `usb_notify` boots in lock state `SKY_DEFAULT`, which it treats as "restricted", so it refuses USB host (and with it DisplayPort). One UI's UsbHostRestrictor normally writes `SUNNY_WORK_MODE`. Android 16's desktop mode also needs the desktop-experience developer flags | Drive `usb_sl` like One UI's UsbHostRestrictor: unlocked `SUNNY_WORK_MODE`; locked with a secure lock screen `RAINY_RESTRICT_MODE` (new USB devices blocked, already-connected keep working; `block_usb_lock=0` gives `CLOUDY_WORK_MODE`). Re-plug USB host on unlock if something was blocked. Turn on freeform, force desktop mode on external displays, and desktop experience features; enable new external displays | module `fold3-desktop` |
| USB-C headphones silent (audio stays on the speaker, or goes nowhere) | The GSI loads the vendor's generic `audio_policy_configuration.xml`, which has no USB routing. With Qualcomm USB offload on, only the primary HAL's DSP path can play to a USB headset. One UI uses Samsung's `audio_policy_configuration_sec.xml` | Bind-mount Samsung's `_sec` policy over the default at boot | module `fold3-usb-audio` |
| Android Auto: "Communication error 22 - not preinstalled" | Since Android 10 Android Auto must be a privileged system app; BiTGApps Core doesn't ship it | MindTheGapps ships a privileged Android Auto stub; update it from the Play Store. With BiTGApps: put the Play Store install into `/system/priv-app` | MindTheGapps (with BiTGApps: module `fold3-android-auto` via `scripts/make-android-auto-module.sh`) |
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
- ⚠️ **Emergency calls (000/112): untested** (see the warning at the top). Emergency data connection + emergency registration verified on Telstra; the emergency call itself (INVITE `urn:service:sos`) isn't written, so 000 goes out as a normal VoLTE call. Never test by dialling 000.
- ☐ Call waiting, hold/swap, merge into conference
- ☐ Voicemail notification (new-voicemail indicator)
- ☐ Wi-Fi calling (likely unsupported by Floss)
- ☐ USSD codes (e.g. balance checks)
- ✅ Speakerphone and Bluetooth audio in calls
- ✅ SMS send/receive (over IMS), MMS send/receive
- ☐ Long SMS (over 160 chars, multipart) and group MMS
- ✅ RCS chats in Google Messages (needs Play Integrity BASIC + number entered manually, see install step 5)
- ✅ Signal bars (ROM build 7): TrebleDroid's `ISehRadio` registration made Samsung's RIL stop filling the standard signal report; the ROM skips it (`ro.telephony.samsung_sehradio=false`), bars show real signal

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
- ✅ Double-tap to wake on both screens, also from AOD (ROM build 7: the dozing panel's touch input is closed so the controller enters its gesture mode)
- ✅ Auto-brightness (Adaptive brightness) on both screens
- ✅ Always-on display on both screens in Samsung's low-power panel mode (ROM: real doze + HLPM `alpm` mode; brightness follows auto-brightness via Samsung's AOD table)
- ✅ Pocket: AOD turns off while the proximity sensor is covered (ROM build 7, Samsung proximity sensor; there's no standard one). "Prevent accidental wake-up" is on by default (not yet tested separately)
- ✅ Half-fold doesn't glitch
- ✅ Adaptive refresh 48–120 Hz; holds 120 Hz only when dim in a dim room (One UI's thresholds per screen) to avoid low-brightness flicker; AOD at 48 Hz
- ✅ Lock on fold / wake on unfold (Settings → Display → "Continue using apps on fold", default "Never")
- ✅ Flex mode in apps (YouTube half-folded)
- ⚠️ Samsung logo stays on the cover screen after an **unfolded** boot until the first fold (the bootloader leaves the unused panel lit). **Boot folded** and it clears. A SurfaceFlinger power-cycle attempt (ROM build 7) didn't fix the unfolded case; low priority. Fold once after booting unfolded to avoid OLED retention.

**Audio, camera & media**
- ✅ Speakers / media playback (Samsung's SoundBooster / SoundAlive / Dolby effects loaded, loud playback clear), microphone, screen recording, volume keys
- ✅ Rear main camera, inner (under-display) selfie, cover-screen selfie, flashlight
- ✅ Ultra-wide and telephoto: photos from every lens, video recording with sound
- ✅ USB-C (digital) headphones: playback, mic, inline volume buttons; known ones work when plugged in while locked
- ✅ Speaker and Bluetooth audio re-checked with Samsung's audio policy
- ☐ Call audio with Samsung's audio policy: earpiece, speakerphone, USB headset mic
- ✅ USB-C dock: keyboard, mouse, USB hub, external monitor as a separate desktop (Android 16 desktop mode), charging passthrough
- ✅ Dock security like stock: unknown devices plugged in while locked stay blocked until unlock, then come up without replugging; devices used before (remembered) work while locked; locking while docked keeps connected devices working

**Sensors & hardware**
- ✅ Fingerprint (survives reboot; rarely the enrollment can still drop at boot if the HAL crashes, see procedure.md), haptics, proximity sensor, wireless charging
- ☐ S Pen (Fold edition, inner screen)
- ☐ Fast charging speed, reverse wireless charging

**System**
- ✅ Storage, Play Store / Google services, root
- ✅ Google sign-in, Play Store installs (Messages, YouTube)
- ✅ Play Integrity: BASIC (with PlayIntegrityFork); DEVICE/STRONG not expected with an unlocked bootloader
- ✅ Several reboots in a row: network, fingerprint and modules come back each time
- ✅ Android Auto over a USB cable (and wireless)
- ✅ Overnight battery drain: about the same as stock
- ☐ A full day of normal use without crashes or lost network
- ☐ Alarms fire while locked / in Doze
- ⚠️ Banking apps / Wallet tap-to-pay: not used on this phone. Many banks' terms forbid modified or rooted OSes, and an unlocked bootloader only gets BASIC integrity. Keep banking on a stock, updated phone.

## Releases and building

- **2026-09-28** [fold3-2026.09.28](https://github.com/jaso1000/Fold3-LineageOS/releases/tag/fold3-2026.09.28):
  low-brightness flicker fix, AOD 48 Hz and One UI-style AOD brightness, lock on fold, Samsung
  audio effects, Telstra IMS APN ([notes](notes/releases/2026-09-28.md)).
- **2026-09-26** [fold3-2026.09.26](https://github.com/jaso1000/Fold3-LineageOS/releases/tag/fold3-2026.09.26):
  first build ([notes](notes/releases/2026-09-26.md)).

Built on a Windows desktop under WSL2: LineageOS 23.2 + MisterZtr's `treble_manifest` and patches,
then `rom/apply.sh` (our patches and `vendor/fold3`), `breakfast lineage_arm64_bvN4-bp4a-userdebug &&
make systemimage`. Details in [rom/README.md](rom/README.md); open items (emergency calls, clean-install
test, a TWRP-flashable zip) in [notes/rom-packaging-todo.md](notes/rom-packaging-todo.md).

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

**3. Flash the ROM + Google apps**
1. Download the latest `lineage-23.2-…-UNOFFICIAL-q2q-VANILLA-EXT4.img.xz` from
   [Releases](https://github.com/jaso1000/Fold3-LineageOS/releases) and check its `.sha256`.
   Unpack it on your computer (`xz -d …img.xz`, or 7-Zip on Windows). It's already enlarged for GApps.
2. Download [MindTheGapps](https://github.com/MindTheGapps/16.0.0-arm64/releases) for Android 16 (arm64).
3. In TWRP: `adb push lineage-….img /tmp/` and `adb push MindTheGapps-….zip /tmp/`.
4. Install → **Install Image** → the `.img` → **System**; then Install → **Install Zip** → MindTheGapps.
5. **Fresh install:** Wipe → **Format Data**. **Updating from an earlier build:** skip this, data is kept.
6. Reboot. The stock JJZH3 vendor is fine (the dual-screen fix is built in; the patched vendor
   image from older guides isn't needed).

**4. Optional: root, RCS**
1. Root: extract `boot.img` from the **exact** firmware your phone runs (samloader), patch it with
   [Magisk](https://github.com/topjohnwu/Magisk), flash via Install Image → Boot. (A boot.img from any
   other firmware version fails Samsung's "Secure check".)
2. RCS: enable Zygisk in Magisk, install [PlayIntegrityFork](https://github.com/osm0sis/PlayIntegrityFork)
   and run its action (`autopif4.sh`; the Pixel profile expires every ~6 weeks, re-run then). Install
   Google Messages + Carrier Services, enter your number in Messages → Settings → Advanced → Phone
   number (the SIM doesn't carry it), then toggle RCS chats off/on.

**Calls on other carriers:** VoLTE uses the built-in Floss IMS. Telstra/Boost work out of the box;
other carriers need an IMS APN (Settings → Network & internet → SIMs → Access Point Names → **+**,
APN `ims`, type `ims`, protocol IPv4/IPv6) and VoLTE enabled in their carrier config, and are
untested. Mobile data and MMS use LineageOS's APN list.

<details><summary>Older method: MisterZtr's GSI + this repo's Magisk modules (before the ROM build)</summary>

Flash MisterZtr's LineageOS 23.2 VANILLA EXT4 GSI, the patched vendor from
`scripts/make-vendor-image.sh`, a Magisk-patched boot.img, then the zips in [`prebuilt/`](prebuilt/)
plus `fold3-media-c2-seccomp` (`scripts/make-media-c2-seccomp-module.sh`) and the manual carrier
steps in [notes/procedure.md](notes/procedure.md). Superseded by the ROM releases.
</details>

## Tooling

- adb/fastboot: `~/Android/sdk/platform-tools/` (not on PATH by default); root shell via `adb shell su -c`.
- Module builders: `scripts/make-*-module.sh`, `scripts/make-overlays.sh`, `scripts/make-vendor-image.sh`;
  prebuilt zips in `prebuilt/`; Floss IMS source in `floss-ims/` (GPLv2, phh), our changes vs
  upstream `phhusson/ims@c180bdf` as patches in `patches/floss-ims/`; overlay source in `overlays/`.
- Floss build SDK: `build/src/floss-sdk` (android-33 platform with MmTelFeature stripped, build-tools 34).
- Prototypes kept for the ROM build: `tools/seh-signal/` (signal bars via Samsung ISehRadio),
  `tools/fp-active-group/` (fingerprint setActiveGroup).
- ROM: `rom/` (apply.sh, vendor_fold3, patches). Stock-firmware analysis: `scripts/lpunpack.py`, `tools/sensor-probe/`.
- Laptop: Surface, Arch Linux (Omarchy). ROM build machine: Windows desktop with WSL2.

## References

- LineageOS 23.2 GSI: https://github.com/MisterZtr/LineageOS_gsi
- Fold3 recovery (Azkali): https://xdaforums.com/t/orangefox-and-twrp-recovery-recovery-for-sm-f926b.4660021/ · https://gitlab.com/azkali-samsung/q2q
- DynaPatch (flash GSIs to dynamic partitions): https://xdaforums.com/t/guide-direct-flashing-gsi-image-to-logical-partitions-on-samsung-galaxy-with-dynamic-partitions.4340947/
- samloader-rs: https://github.com/topjohnwu/samloader-rs · Heimdall: https://github.com/Benjamin-Dobell/Heimdall · Magisk: https://github.com/topjohnwu/Magisk
- MindTheGapps: https://github.com/MindTheGapps/16.0.0-arm64 · BiTGApps: https://bitgapps.io
- Floss IMS (phh): https://github.com/phhusson/ims · TrebleDroid: https://github.com/TrebleDroid/treble_experimentations
- q2q kernel source (driver analysis): https://github.com/cawilliamson/android_kernel_samsung_q2q
- Reference device trees: Exynoobs sm8550-common / q5q (Fold5), samsung-sm8350
- Fold3 XDA forum: https://xdaforums.com/f/samsung-galaxy-z-fold3.12349/
