# LineageOS on Galaxy Z Fold3 (SM-F926B, "q2q")

Unofficial LineageOS 23.2 (Android 16) for the Samsung Galaxy Z Fold3, built from source with the
Fold3 fixes built in. **Download: [Releases](https://github.com/jaso1000/Fold3-LineageOS/releases)**
(install steps below).

Device: Samsung Galaxy Z Fold3, SM-F926B (Australian variant), codename **q2q**, Snapdragon 888 (SM8350).

## Status (updated 2026-09-28)

**Latest build: [fold3-2026.09.28.2](https://github.com/jaso1000/Fold3-LineageOS/releases/tag/fold3-2026.09.28.2)**,
Android security patch 2026-09-01, on Samsung's **final** firmware F926BXXSJJZH3 (Samsung ended
Fold3 updates in September 2026). A TrebleDroid-based system image (MisterZtr's LineageOS GSI
patches) plus this repo's Fold3 changes (`rom/`): no Magisk modules needed, root optional. Daily
driver for the dev, including **VoLTE with HD voice on Telstra/Boost**, both screens, signal bars, AOD,
Dolby Atmos and Android Auto.

> ⚠️ **Emergency calls (000/112): untested.** SIP-level emergency tests pass on Telstra (emergency
> data connection and registration), but the dedicated emergency call isn't implemented yet, so
> 000 is sent as a normal VoLTE call, and no real emergency call has been made. **Don't rely on
> this phone for emergencies; keep another phone available.**

Details of every fix: [rom/README.md](rom/README.md) (how it's built into the ROM) ·
[notes/procedure.md](notes/procedure.md) (root causes) · [notes/rom-packaging-todo.md](notes/rom-packaging-todo.md) (plan and to-do).

### Fixes in the ROM

| Problem on the plain GSI | Root cause (short) | Fix in the ROM |
|---|---|---|
| No display switching on fold; outer screen stuck | `<lid-switch>` condition in Samsung's device-state config is never true on the GSI | Boot script mounts Samsung's `sec/` device-state config without `<lid-switch>` (stock vendor works) |
| Outer touchscreen dead | GSI tells Samsung's miscpower HAL "main display only" | Framework patch: `setInteractiveAsync(…, -1)` (all panels) |
| No storage/media/fingerprint at boot | Samsung Codec2 HAL killed by its seccomp policy (`mremap`) | Already fixed upstream in TrebleDroid |
| No calls (Telstra has no 3G) | No IMS stack usable with Samsung's vendor | phh's Floss IMS, **patched** (Telstra call/SMS fixes) and built from source, as a privileged app; VoLTE carrier config for Telstra/Boost; Telstra IMS APN |
| Callers can hardly hear you | Outgoing calls start in the modem's call audio mode; Samsung's audio chip then keeps the mic on the modem path and the IMS app gets ~40 dB less signal | Calls start in VoIP audio mode while VoLTE is up (telephony patch + overlay); noise suppression on the call mic |
| Calls only in narrowband (non-HD) | Floss IMS only spoke AMR 8 kHz | **HD voice** (AMR-WB 16 kHz) with automatic AMR fallback |
| Signal bars always 0 | With TrebleDroid's `ISehRadio` registration, Samsung's RIL stops filling the standard signal report | Registration skipped (`ro.telephony.samsung_sehradio=false`); real signal strength |
| Fingerprint enrollment lost at boot | Samsung's HAL loses its active user; the framework's cleanup then deletes the enrollment | Framework sets the active group on every HAL connection; boot service re-sends it after rild restarts |
| Cover selfie shows the inner camera; no Flex mode; no ultra-wide/tele | No fold states in the GSI; Samsung hides aux lenses | Framework overlay with fold states/postures/hinge; Samsung camera ids + Aperture overlay |
| Outer screen brightness never changes | Only one backlight is wired to Android | Helper mirrors brightness to the cover panel |
| No auto-brightness, double tap, AOD | GSI config off; touch panels not told | Overlay enables them; AOD in Samsung's low-power panel mode (HLPM), double tap works from AOD, brightness steps 2/10/30/60 nit like One UI |
| AOD stays on in a pocket; accidental wake-ups | No standard proximity sensor, only Samsung types | SystemUI and LineageOS "Prevent accidental wake-up" use Samsung's proximity sensor |
| No 120 Hz unless forced; flicker when dim | Framework's 60 Hz default cap; Samsung panels shift colour at low brightness below 120 Hz | Adaptive 48–120 Hz; holds 120 Hz only when dim in a dim room (One UI's thresholds per screen); AOD at 48 Hz |
| Folding doesn't lock | Samsung's device-state config lacks Android 16's sleep/wake properties | Added at boot; Settings → Display → "Continue using apps on fold" (default "Never") |
| Muffled speaker; USB-C headphones silent | GSI loads the vendor's generic audio effects/policy | Samsung's `audio_effects_sec.xml` (SoundBooster, SoundAlive, Dolby) and `audio_policy_configuration_sec.xml` |
| No Dolby Atmos switch | One UI's Sound quality and effects app isn't in a GSI | "Dolby Atmos" Quick Settings tile drives Samsung's Dolby effect (off by default, like stock) |
| No Dolby audio in streaming apps | Samsung's Dolby decoders aren't in the codec list the GSI reads | Codec list includes Samsung's Dolby decoders (AC-3, E-AC-3/Atmos, AC-4) |
| Hotspot "connected, no internet" | Tethering never starts a DNS proxy | Hotspot DNS redirected to 8.8.8.8 |
| USB-C dock only charges, then only mirrors | Samsung's USB lock state stays "restricted"; desktop flags off | One UI-style USB lock handling; Android 16 desktop mode on external monitors |
| Phone app ANR loop at boot | Phone blocks on rild's slow start | `SafetySourceReceiver` disabled at boot (mitigation) |
| Android Auto "error 22" | Must be a privileged system app | MindTheGapps ships it privileged |

The same fixes as standalone Magisk modules (for the plain GSI, before the ROM) are in `magisk-src/` and `prebuilt/`.

### Test checklist

✅ works · ⚠️ known issue · ☐ not tested yet

**Calls & messaging**
- ✅ Outgoing calls (voicemail, local and +61 numbers incl. call-log callbacks), audio both ways, clean hang-up
- ✅ Keypad tones (DTMF) in calls, in HD voice and narrowband calls
- ✅ **HD voice** (AMR-WB) outgoing and incoming on Telstra; narrowband fallback when the other side doesn't offer it
- ✅ Caller hears you clearly (call mic starts in VoIP audio mode; tested in build 13)
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
- ✅ RCS chats in Google Messages (needs Play Integrity BASIC + number entered manually, see install step 4)
- ✅ Signal bars (real signal strength)

**Data & connectivity**
- ✅ Mobile data, Wi-Fi, Bluetooth (headphones, controller), airplane mode
- ✅ Hotspot
- ✅ GPS / location
- ✅ NFC (tap-to-pay not supported, see Play Integrity)
- ☐ eSIM (download/activate a profile)

**Display & fold**
- ✅ Inner/outer switching on fold, outer touch, rotation on both screens
- ✅ Brightness on both screens (outer follows the slider live)
- ✅ Screen on/off and lock screen on both screens
- ✅ Double-tap to wake on both screens, also from AOD
- ✅ Auto-brightness (Adaptive brightness) on both screens
- ✅ Always-on display on both screens in Samsung's low-power panel mode (inner 1–30 Hz, cover 30 Hz); brightness follows the light sensor through Samsung's AOD levels
- ✅ Pocket: AOD turns off while the proximity sensor is covered
- ☐ "Prevent accidental wake-up" (on by default): no wake-up while the sensor is covered
- ✅ Half-fold doesn't glitch
- ✅ Adaptive refresh 48–120 Hz; holds 120 Hz only when dim in a dim room (One UI's thresholds per screen) to avoid low-brightness flicker; AOD at 48 Hz
- ✅ Lock on fold / wake on unfold (Settings → Display → "Continue using apps on fold", default "Never")
- ✅ Flex mode in apps (YouTube half-folded)
- ⚠️ Samsung logo stays on the cover screen after an **unfolded** boot until the first fold (the bootloader leaves the unused panel lit). **Boot folded** and it clears; otherwise fold once after booting to avoid OLED retention.

**Audio, camera & media**
- ✅ Speakers / media playback (Samsung's SoundBooster / SoundAlive / Dolby effects loaded, loud playback clear), microphone, screen recording, volume keys
- ✅ Dolby Atmos Quick Settings tile switches Samsung's Dolby effect (build 12+)
- ✅ Dolby decoders listed for apps (live test); ☐ Dolby audio in a streaming app
- ✅ Rear main camera, inner (under-display) selfie, cover-screen selfie, flashlight
- ✅ Ultra-wide and telephoto: photos from every lens, video recording with sound
- ✅ USB-C (digital) headphones: playback, mic, inline volume buttons; known ones work when plugged in while locked
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
- ✅ Several reboots in a row: network and fingerprint come back each time
- ✅ Android Auto over a USB cable (and wireless)
- ✅ Overnight battery drain: about the same as stock
- ☐ A full day of normal use without crashes or lost network
- ☐ Alarms fire while locked / in Doze
- ⚠️ Banking apps / Wallet tap-to-pay: not used on this phone. Many banks' terms forbid modified or rooted OSes, and an unlocked bootloader only gets BASIC integrity. Keep banking on a stock, updated phone.

## Releases and building

- **2026-09-28.2** [fold3-2026.09.28.2](https://github.com/jaso1000/Fold3-LineageOS/releases/tag/fold3-2026.09.28.2):
  callers hear you clearly (call mic level fixed), HD voice (AMR-WB), call-mic noise suppression,
  Dolby Atmos tile, Dolby decoders for streaming apps ([notes](notes/releases/2026-09-28.2.md)).
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

**Get the ROM: [latest release](https://github.com/jaso1000/Fold3-LineageOS/releases/latest)**
(`lineage-23.2-…-UNOFFICIAL-q2q-VANILLA-EXT4.img.xz`, the recovery
`twrp-q2q-azkali-dynapatch-AP.tar.md5`, and their `.sha256` files). You also need
[MindTheGapps](https://github.com/MindTheGapps/16.0.0-arm64/releases) (Android 16, arm64) for Google apps.
Already unlocked with TWRP + DynaPatch? Go straight to step 3.

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

**2. Custom recovery (TWRP)**

The release includes the exact recovery this ROM was tested with:
**`twrp-q2q-azkali-dynapatch-AP.tar.md5`**. It contains Azkali's TWRP for q2q with
[DynaPatch](https://xdaforums.com/t/guide-direct-flashing-gsi-image-to-logical-partitions-on-samsung-galaxy-with-dynamic-partitions.4340947/)
already applied (Install Image can write the dynamic `system`/`vendor` partitions, so no fastboot
and no separate DynaPatch flash are needed), plus a verification-disabled `vbmeta` (generic,
made with avbtool; no Samsung content).
1. Check the `.sha256`, then boot to Download Mode (power off, hold **Vol Up + Vol Down**, plug in USB).
2. **Odin (Windows):** put the file in **AP**, go to Options and **untick Auto Reboot**, then press Start.
   **Heimdall (Linux/macOS):** `tar -xf twrp-q2q-azkali-dynapatch-AP.tar.md5`, `lz4 -d` both files, then
   `heimdall flash --RECOVERY recovery.img --VBMETA vbmeta.img --no-reboot`.
3. Leave Download Mode by holding **Vol Down + Power**. As soon as the screen goes black, switch to
   **Vol Up + Power** (USB still plugged in) and hold until TWRP appears.

Notes:
- The recovery **can't decrypt `/data`** on this firmware, so no recovery backups. Keep the stock
  firmware (from samloader) as your way back.
- Source: Azkali's Fold3 recovery ([XDA thread](https://xdaforums.com/t/orangefox-and-twrp-recovery-recovery-for-sm-f926b.4660021/),
  device tree on [GitLab](https://gitlab.com/azkali-samsung/q2q)), built with
  [bm0x/twrp-actions-compiler](https://github.com/bm0x/twrp-actions-compiler) because Azkali's
  download page is down; [TWRP](https://github.com/TeamWin) (GPLv3); Samsung's GPL kernel source is at
  [opensource.samsung.com](https://opensource.samsung.com). Redistributed unmodified apart from
  DynaPatch's fstab entries.

**3. Flash the ROM + Google apps**
1. Download the image from the [latest release](https://github.com/jaso1000/Fold3-LineageOS/releases/latest)
   and check its `.sha256`.
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
  prebuilt zips in `prebuilt/`; Floss IMS source in `floss-ims/` (GPLv2, phh; the ROM builds it with
  Soong as `PhhIms`), our changes vs upstream `phhusson/ims@c180bdf` as patches in
  `patches/floss-ims/`; overlay source in `overlays/`.
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
