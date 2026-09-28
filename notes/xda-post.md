[B]LineageOS 23.2 (Android 16) on the Galaxy Z Fold3 SM-F926B[/B]

Hey everyone, first time poster but long time lurker / tinkerer !

I was almost going to pull the trigger on upgrading my aging z fold 3 for a pixel fold but before I do, I decided to have a go at trying to build out my own pixel like ROM.
I had pretty good success so far and given the lack of development for this device I figured I'd share all the fixes I've worked through.

[B]Update (2026-09-28):[/B] it's now a proper ROM built from source with all the fixes baked in, and there's a downloadable release. No Magisk modules needed anymore, root is optional.

Full disclosure: AI was used heavily to get to this point and all text below this point is AI generated too!

[MEDIA=youtube]00z9D7Q8IqA[/MEDIA]

Cheers,
Jason

[URL='https://github.com/jaso1000/Fold3-LineageOS']github.com/jaso1000/Fold3-LineageOS[/URL]

[B]Download:[/B] [URL='https://github.com/jaso1000/Fold3-LineageOS/releases']latest release[/URL] (currently [URL='https://github.com/jaso1000/Fold3-LineageOS/releases/tag/fold3-2026.09.28']fold3-2026.09.28[/URL])

[SIZE=5][B]What this is (right now)[/B][/SIZE]
An unofficial LineageOS 23.2 (Android 16) system image built from source:
[LIST]
[*]MisterZtr's [URL='https://github.com/MisterZtr/LineageOS_gsi']LineageOS 23.2 TrebleDroid GSI[/URL] patches, plus all the Fold3 fixes built in ([URL='https://github.com/jaso1000/Fold3-LineageOS/tree/master/rom']rom/[/URL])
[*]Android security patch 2026-09-01, on Samsung's final firmware (F926BXXSJJZH3), stock vendor
[*]Vanilla: flash [URL='https://github.com/MindTheGapps/16.0.0-arm64/releases']MindTheGapps[/URL] for Google apps. Magisk optional
[*]Installed with TWRP's Install Image (a system image, not a one-zip flashable ROM yet)
[/LIST]

[SIZE=5][B]What works[/B][/SIZE]
[LIST]
[*]Inner and outer screen switching on fold, outer touchscreen, brightness on both screens
[*]Lock on fold / wake on unfold, with the "Continue using apps on fold" setting
[*]Adaptive refresh 48–120 Hz, with One UI's low-brightness anti-flicker behaviour
[*]Always-on display in Samsung's low-power mode (inner 1–30 Hz, cover 30 Hz), brightness steps like One UI, double tap to wake from AOD, turns off in a pocket
[*]Signal bars
[*]VoLTE calls in and out (patched phh Floss IMS): caller ID, two-way audio, keypad tones, speaker, Bluetooth, calls from the call log
[*]SMS and MMS over IMS, RCS in Google Messages (with Magisk + Play Integrity Fix)
[*]Mobile data, 5G, Wi-Fi, Bluetooth, hotspot, GPS
[*]All cameras: main, ultra-wide, 2x telephoto, inner under-display selfie, cover selfie
[*]Flex mode in apps (e.g. YouTube half-folded)
[*]Fingerprint, storage, speakers with Samsung's SoundBooster / SoundAlive / Dolby effects, USB-C headphones, haptics, wireless charging
[*]USB-C dock with Android 16 desktop mode on an external monitor
[*]Android Auto, wired and wireless
[*]Google sign-in, Play Store, YouTube and so on
[/LIST]
Full checklist, including what's untested: [URL='https://github.com/jaso1000/Fold3-LineageOS#test-checklist']Test checklist[/URL]

[SIZE=5][B]Known issues[/B][/SIZE]
[LIST]
[*][B]Emergency calls (000/112): untested.[/B] SIP-level emergency tests pass on Telstra (emergency data connection and registration), but the dedicated emergency call isn't implemented yet, so 000 is sent as a normal VoLTE call, and no real emergency call has been made. Don't rely on this phone for emergencies; keep another phone available.
[*]A clean install hasn't been tested yet (I've been updating over my existing install). Please report if a fresh install needs extra steps.
[*]Booting unfolded leaves the Samsung logo on the cover screen until the first fold. Boot folded, or fold once after booting.
[*]VoLTE is only tested on Telstra/Boost. Other carriers need an IMS APN and may need more work.
[*]Samsung's "Adapt Sound" isn't available.
[/LIST]

[SIZE=5][B]Read before trying this[/B][/SIZE]
[LIST]
[*]Unlocking the bootloader wipes the phone and trips Knox permanently (Samsung Pay/Wallet, Secure Folder, Samsung Health stop working).
[*]Only tested on the SM-F926B on F926BXXSJJZH3.
[*]Don't rely on it for emergency calls.
[*]Many banks' app terms don't allow modified or rooted phones. Keep banking on a stock phone.
[*]This is a personal build shared as-is. You can end up without a working phone.
[/LIST]

[SIZE=5][B]How to install[/B][/SIZE]
Step-by-step guide (unlock, recovery, flashing the image + MindTheGapps, optional root and RCS):
[URL='https://github.com/jaso1000/Fold3-LineageOS#installing-it-yourself']Installing it yourself[/URL]

Recovery: the release includes the TWRP I use (Azkali's q2q build with DynaPatch already applied, plus a verification-disabled vbmeta), [B]twrp-q2q-azkali-dynapatch-AP.tar.md5[/B]. Flash it in Odin's AP slot with Auto Reboot unticked, then hold Vol Down + Power and, when the screen goes black, Vol Up + Power to boot into TWRP.

Short version, in TWRP:
[LIST=1]
[*]Unpack the release .img.xz on your computer
[*]Push the .img and MindTheGapps to /tmp
[*]Install → Install Image → the .img → System
[*]Install Zip → MindTheGapps
[*]Fresh install: Format Data. Updating: skip, data is kept
[*]Reboot
[/LIST]
Other carriers: add an APN with APN "ims", type "ims", protocol IPv4/IPv6 for VoLTE.

How each fix works: [URL='https://github.com/jaso1000/Fold3-LineageOS/blob/master/rom/README.md']rom/README.md[/URL] · root causes: [URL='https://github.com/jaso1000/Fold3-LineageOS/blob/master/notes/procedure.md']notes/procedure.md[/URL]

[SIZE=5][B]What's next[/B][/SIZE]
[LIST]
[*]Emergency calls over VoLTE (the dedicated emergency call)
[*]Testing a clean install
[*]A one-zip TWRP-flashable package
[/LIST]

[SIZE=5][B]Credits[/B][/SIZE]
[LIST]
[*][URL='https://github.com/MisterZtr/LineageOS_gsi']MisterZtr[/URL] for the LineageOS GSI, and [URL='https://github.com/TrebleDroid/treble_experimentations']TrebleDroid / phhusson[/URL] for the GSI work and [URL='https://github.com/phhusson/ims']Floss IMS[/URL]
[*]Azkali for the [URL='https://xdaforums.com/t/orangefox-and-twrp-recovery-recovery-for-sm-f926b.4660021/']Fold3 recovery[/URL]
[*]The [URL='https://xdaforums.com/t/guide-direct-flashing-gsi-image-to-logical-partitions-on-samsung-galaxy-with-dynamic-partitions.4340947/']DynaPatch[/URL] author
[*]topjohnwu for [URL='https://github.com/topjohnwu/Magisk']Magisk[/URL] and [URL='https://github.com/topjohnwu/samloader-rs']samloader-rs[/URL]
[*][URL='https://github.com/MindTheGapps']MindTheGapps[/URL], osm0sis for [URL='https://github.com/osm0sis/PlayIntegrityFork']PlayIntegrityFork[/URL]
[*]The LineageOS project, and the Exynoobs Fold5 build for reference
[/LIST]
