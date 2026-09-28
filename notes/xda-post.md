# XDA post (paste the BBCode below into XDA's editor, source/BB mode)

Suggested title: **[ROM][UNOFFICIAL][16] LineageOS 23.2 for Galaxy Z Fold3 (SM-F926B / q2q)**

```
[CENTER][SIZE=6][B]LineageOS 23.2 (Android 16) for Galaxy Z Fold3[/B][/SIZE]
[B]SM-F926B · q2q · unofficial[/B][/CENTER]

[COLOR=rgb(226, 80, 65)][B]⚠️ Emergency calls (000/112/911): untested.[/B][/COLOR] SIP-level emergency tests pass on Telstra (emergency data connection and registration), but the dedicated emergency call isn't implemented yet, so 000 is sent as a normal VoLTE call, and no real emergency call has been made. [B]Don't rely on this phone for emergencies; keep another phone available.[/B]

[B]⚠️ Personal build.[/B] Made for and tested on one SM-F926B on Telstra/Boost (Australia). Things may be broken on your device or carrier. Unlocking the bootloader wipes the phone and trips Knox permanently. Flash at your own risk.

[SIZE=5][B]What it is[/B][/SIZE]
LineageOS 23.2 built from source: MisterZtr's TrebleDroid LineageOS GSI with the Fold3 fixes built in (no Magisk modules needed, root optional). Android security patch 2026-09-01, on Samsung's final firmware F926BXXSJJZH3. Vanilla: flash MindTheGapps yourself.

[SIZE=5][B]Working[/B][/SIZE]
[LIST]
[*]Both screens, switching on fold, cover-screen touch, Flex mode
[*]Lock on fold / wake on unfold (Settings → Display → "Continue using apps on fold")
[*]Adaptive refresh 48–120 Hz with One UI's low-brightness anti-flicker behaviour
[*]Always-on display in Samsung's low-power mode: 1–30 Hz inner / 30 Hz cover, brightness steps like One UI, double tap to wake, turns off in a pocket
[*]Auto-brightness on both screens, double tap to wake
[*]All cameras incl. cover selfie, ultra-wide and telephoto
[*]Fingerprint, signal bars, mobile data, Wi-Fi, Bluetooth, hotspot, GPS
[*][B]VoLTE calls, SMS, MMS on Telstra/Boost[/B] (patched Floss IMS built in); RCS with Magisk + PlayIntegrityFork
[*]Speakers with Samsung's SoundBooster / SoundAlive / Dolby effects, USB-C headphones
[*]USB-C dock with Android 16 desktop mode on an external monitor
[*]Android Auto wired and wireless (with MindTheGapps)
[/LIST]

[SIZE=5][B]Known issues[/B][/SIZE]
[LIST]
[*]Emergency calls: untested (see above)
[*]Clean install not tested yet (tested updating over an existing install) — please report
[*]Booting unfolded leaves the Samsung logo on the cover screen until the first fold (boot folded, or fold once)
[*]VoLTE only tested on Telstra/Boost; other carriers need an IMS APN and may not work
[*]Banking / Google Wallet tap-to-pay not supported (unlocked bootloader)
[*]Samsung "Adapt Sound" not available
[/LIST]

[SIZE=5][B]Install[/B][/SIZE]
Requirements: SM-F926B, unlocked bootloader, firmware F926BXXSJJZH3, Azkali's TWRP for q2q + DynaPatch. Full unlock/recovery steps: [URL='https://github.com/jaso1000/Fold3-LineageOS#installing-it-yourself']GitHub README[/URL].
[LIST=1]
[*]Download the latest image from [URL='https://github.com/jaso1000/Fold3-LineageOS/releases']Releases[/URL], check the .sha256, unpack the .xz
[*]Download [URL='https://github.com/MindTheGapps/16.0.0-arm64/releases']MindTheGapps 16 arm64[/URL]
[*]In TWRP: adb push both to /tmp
[*]Install → Install Image → the .img → System; then Install Zip → MindTheGapps
[*]Fresh install: Format Data. Updating: skip, data is kept
[*]Reboot. Optional: Magisk-patched JJZH3 boot.img for root
[/LIST]
Other carriers: add an APN with APN "ims", type "ims", protocol IPv4/IPv6 for VoLTE.

[SIZE=5][B]Downloads & source[/B][/SIZE]
Releases: [URL]https://github.com/jaso1000/Fold3-LineageOS/releases[/URL]
Source, fixes and write-ups: [URL]https://github.com/jaso1000/Fold3-LineageOS[/URL]

[SIZE=5][B]Credits[/B][/SIZE]
LineageOS · TrebleDroid / phhusson (GSI, Floss IMS) · MisterZtr (LineageOS GSI) · Azkali (q2q TWRP) · DynaPatch
```
