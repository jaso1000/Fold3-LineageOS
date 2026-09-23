# LineageOS on Galaxy Z Fold3 (SM-F926B, "q2q")

Research + build project for getting LineageOS (or a close GSI equivalent) running on a
Samsung Galaxy Z Fold3, following on from the [Tab S7 LineageOS project](notes/handoff.md#1-galaxy-tab-s7-wifi-sm-t870-gts7lwifi--done),
which is done and working.

Device: Samsung Galaxy Z Fold3, SM-F926B (Australian variant), codename **q2q**, Snapdragon 888 (SM8350).

## Status: research phase — not yet started on-device

There is no official or active unofficial LineageOS build for q2q. The Fold5 LOS 23.2 build
(q5q, SM8550, by josip-k / Exynoobs) is **not portable** — different chipset and kernel — only
useful as reference for foldable-specific logic (inner/outer display switching, dual
brightness, fold sensor).

Realistic path: a **TrebleDroid/LineageOS GSI**, flashed directly via a custom recovery
after bootloader unlock. **Correction from the original handoff: DSU (Dynamic System
Updates) is not usable here** — Samsung strips the DSU Loader out of One UI entirely, on
every Galaxy device, so there's no non-destructive test-boot path. The actual working
method (confirmed via the same-SoC S21 5G Snapdragon GSI community, and a
Fold3-specific recovery project) is: unlock bootloader → flash a q2q-specific custom
recovery (TWRP/OrangeFox, already exists — see below) with matching vbmeta via
Odin → `fastboot flash system` the GSI → wipe data. See
[notes/procedure.md](notes/procedure.md) for the full draft writeup and sources.

**Good news found during research**: a maintained TWRP/OrangeFox recovery already exists
for exactly this device (SM-F926B/q2q, by Azkali) — the hard device-specific part (AVB/
vbmeta bypass, boot chain) is already solved by someone else. Bad news: the Fold3 custom-ROM
scene is confirmed dead — the one 2025 "any custom OS?" XDA thread got zero replies.

## Plan

1. [x] Research how similar SM8350 (Snapdragon 888) Samsung devices achieve this — done,
   see [notes/procedure.md](notes/procedure.md).
2. [ ] Confirm device details: exact model (SM-F926B), current One UI / Android version,
   whether "OEM unlocking" is visible/enabled in Developer Options.
   → `scripts/check-device.sh` once the phone is connected via adb.
3. [ ] Get Azkali's q2q recovery + matching vbmeta tar from
   https://xdaforums.com/t/orangefox-and-twrp-recovery-recovery-for-sm-f926b.4660021/
   (companion wiki was down when checked — retry https://fold-wiki.azka.li/en/Recovery).
4. [ ] Pick a GSI to try first — see [notes/gsi-candidates.md](notes/gsi-candidates.md)
   (leaning Evolution X for first bring-up, LineageOS 23.2 GSI as the real target).
5. [ ] Back up the device, confirm the user is OK with the permanent Knox trip, then unlock
   the bootloader and run through [notes/procedure.md](notes/procedure.md) step by step.
6. [ ] Optional: draft an XDA post to josip-k (q2q interest) and to bgcngm (Tab S7 extended
   external display).

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
