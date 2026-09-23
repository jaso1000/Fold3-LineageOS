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

Realistic path: a **TrebleDroid/LineageOS GSI**, tested first via **DSU (Dynamic System
Updates)** after bootloader unlock, since DSU boots a GSI alongside stock One UI without
touching the existing install — reboot returns to stock. Full flash via fastbootd is the
fallback once DSU proves it boots.

## Plan

1. [ ] Confirm device details: exact model (SM-F926B), current One UI / Android version,
   whether "OEM unlocking" is visible/enabled in Developer Options.
   → `scripts/check-device.sh` once the phone is connected via adb.
2. [ ] Survey current-gen Android 16 GSIs (arm64, TrebleDroid/LineageOS-based) on XDA and
   pick a candidate. Track options in [notes/gsi-candidates.md](notes/gsi-candidates.md).
3. [ ] Write the step-by-step: unlock bootloader → DSU test → (optional) full flash via
   fastbootd. Record in [notes/procedure.md](notes/procedure.md) as it's worked out.
4. [ ] Optional: draft an XDA post to josip-k (q2q interest) and to bgcngm (Tab S7 extended
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
