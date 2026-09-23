# LineageOS on Galaxy Z Fold3 (SM-F926B, "q2q")

Research + build project for getting LineageOS (or a close GSI equivalent) running on a
Samsung Galaxy Z Fold3, following on from the [Tab S7 LineageOS project](notes/handoff.md#1-galaxy-tab-s7-wifi-sm-t870-gts7lwifi--done),
which is done and working.

Device: Samsung Galaxy Z Fold3, SM-F926B (Australian variant), codename **q2q**, Snapdragon 888 (SM8350).

## Status: Android 16 booting with working Play Store (paused 2026-09-24)

**Where things actually stand right now**, for picking this back up later:
- Bootloader **unlocked**, Knox tripped, device fully healthy and usable.
- Working custom recovery on the device: not Azkali's own build (their distribution wiki is
  down) but a same-source mirror built via CI (see [notes/procedure.md](notes/procedure.md)),
  patched with
  [Yillié's DynaPatch](https://xdaforums.com/t/guide-direct-flashing-gsi-image-to-logical-partitions-on-samsung-galaxy-with-dynamic-partitions.4340947/)
  to add "Install Image" support for the dynamic/logical partitions, which is what actually
  let us flash GSIs without ever getting fastboot exposed (a separate, still-unresolved
  side-quest — see below).
- **Working daily-driver-ish build achieved**: LineageOS 23.2 (Android 16 QPR2) GSI +
  [BiTGApps](https://bitgapps.io) (Core variant) booting cleanly. Confirmed working: WiFi,
  Bluetooth, both cameras, haptics, mobile data, **Play Store/Google Play Services**. Broken:
  fingerprint (expected — matches the established Android-14-only pattern from research),
  audio/speakers (new, not yet investigated), and — the current focus — **only the inner
  screen works; the outer/cover screen stays frozen on the boot logo**, since a generic GSI
  has zero foldable-aware display-switching logic. Full writeup, including the multi-hour
  GApps SetupWizard-crash saga and its fix, in
  [notes/procedure.md](notes/procedure.md#success-android-16-lineageos-232-booting-with-working-gapps-2026-09-24).
- Evolution X 9.9.3 (Android 14) was the first GSI that booted at all, earlier in the same
  session — still on disk, useful as a fallback: has working audio and (per the Android-14
  pattern) fingerprint, but no GApps and no calls.
- **Calls don't work** on any build tried — Samsung's IMS stack is proprietary and the
  standard community VoLTE fix explicitly doesn't support Samsung devices. Unsolved,
  deprioritized for now.
- **Next goal (not yet started): get both screens working.** This needs real foldable-aware
  device-tree/kernel work (display-switching HAL, dual brightness, fold-state sensor
  integration) — a GSI fundamentally can't do this, no matter which one we pick. The only
  known reference for someone getting this specific device's dual-screen switching working is
  the abandoned [Pixel Experience WIP thread](https://xdaforums.com/t/pixel-experience-running-on-my-fold-3-wip-development.4483239/)
  (2022-23) — got inner+outer switching, brightness, RIL, camera, and charging all working
  via a proper device tree, but the build was never released and the developer vanished. That
  thread (and Azkali's own `android_device_samsung_q2q` / kernel repos on
  [GitLab](https://gitlab.com/azkali-samsung/q2q)) are the starting points to study — this is
  a meaningfully bigger undertaking than anything done so far (building/adapting a real
  device tree, not just flashing a pre-built image).
- All work pushed to a private GitHub repo: https://github.com/jaso1000/Fold3-LineageOS

Original research below is still accurate background context.

There is no official or active unofficial LineageOS build for q2q. The Fold5 LOS 23.2 build
(q5q, SM8550, by josip-k / Exynoobs) is **not portable** — different chipset and kernel — only
useful as reference for foldable-specific logic (inner/outer display switching, dual
brightness, fold sensor).

Realistic path: a **TrebleDroid/LineageOS GSI**, flashed directly via fastboot after
bootloader unlock. **Correction from the original handoff: DSU (Dynamic System Updates) is
not usable here** — Samsung strips the DSU Loader out of One UI entirely, on every Galaxy
device, so there's no non-destructive test-boot path.

There's a Fold3-specific recovery (Azkali's TWRP/OrangeFox for q2q), but it's built on
Android 14 firmware and **our phone is on Android 15** (confirmed — see
[notes/device-info.md](notes/device-info.md)) — a large enough gap that Samsung's
anti-rollback protection would likely refuse to flash it. Instead of relying on that stale
build, the current plan **patches our own currently-installed stock recovery** to add
fastboot access — same firmware version in and out, so no anti-rollback conflict, and no
dependency on a dormant device-specific project. See [notes/procedure.md](notes/procedure.md)
for the full method and sources.

**Bad news, confirmed**: the Fold3 custom-ROM scene is dead — the one 2025 "any custom OS?"
XDA thread got zero replies, and phhusson's treble_experimentations (classic GSI compat
tracker) has been archived since Jan 2025.

## Plan

1. [x] Research how similar SM8350 (Snapdragon 888) Samsung devices achieve this.
2. [x] Confirm device details — SM-F926B, Android 15 (`F926BXXSJJZH3`).
3. [x] Unlock the bootloader — stable, Knox tripped.
4. [x] Get a working custom recovery on the device (Azkali's build via a CI mirror + DynaPatch
   for dynamic-partition image flashing — see [notes/procedure.md](notes/procedure.md)).
5. [x] Get a GSI booting at all — Evolution X 9.9.3 (Android 14) first, then LineageOS 23.2
   (Android 16).
6. [x] Get GApps working on Android 16 — BiTGApps (Core), after MindTheGapps proved
   incompatible with this GSI across three different install methods.
7. [ ] **Current goal: get both screens working.** Needs real device-tree/kernel work for
   foldable display switching — see Status above for starting points (Pixel Experience WIP
   thread, Azkali's device tree/kernel repos). Not started.
8. [ ] Unsolved, lower priority: calls (Samsung's proprietary IMS), audio on the Android 16
   build, fastboot access on the recovery (we ended up not needing it — DynaPatch's Install
   Image feature was sufficient — but still an open question if useful later).

## Known constraints going in

- Unlocking the bootloader trips **Knox permanently**: Samsung Pay/Wallet, Secure Folder,
  Health are lost, and some banking apps may refuse to run afterward. Confirm the user is
  OK with this before actually unlocking (this is a one-way door).
- Expected GSI limitations on a foldable: outer screen switching/brightness, side
  fingerprint, some cameras, VoLTE/VoWiFi (carrier-dependent), manual updates only.

## Tooling

- adb/fastboot: `~/Android/sdk/platform-tools/` (not on PATH by default).
- Laptop: Surface, Arch Linux (Omarchy).

## Sources

- Fold3 forum: https://xdaforums.com/f/samsung-galaxy-z-fold3.12349/
- Fold5 unofficial LOS 23.2 (reference only, not portable): https://xdaforums.com/t/rom-unofficial-volte-vowifi-lineageos-23-2-for-galaxy-z-fold5.4774598/
- Fold3 Pixel Experience WIP (abandoned 2022-23): https://xdaforums.com/t/pixel-experience-running-on-my-fold-3-wip-development.4483239/
- Tab S7 LOS23 thread (prior project, for technique reference): https://xdaforums.com/t/rom-official-lineageos-23-weeklies-for-galaxy-tab-s7-wifi-and-s7-lte.4763404/
- Tab S7 install guide: https://wiki.lineageos.org/devices/gts7lwifi/install/
