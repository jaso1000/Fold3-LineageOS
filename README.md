# LineageOS on Galaxy Z Fold3 (SM-F926B, "q2q")

Research + build project for getting LineageOS (or a close GSI equivalent) running on a
Samsung Galaxy Z Fold3, following on from the [Tab S7 LineageOS project](notes/handoff.md#1-galaxy-tab-s7-wifi-sm-t870-gts7lwifi--done),
which is done and working.

Device: Samsung Galaxy Z Fold3, SM-F926B (Australian variant), codename **q2q**, Snapdragon 888 (SM8350).

## Status: bootloader unlocked, blocked on fastboot access (paused 2026-09-23)

**Where things actually stand right now**, for picking this back up later:
- Bootloader is **unlocked** and stable. Knox has tripped. Device boots normally, fully
  functional as a phone.
- We built a patched recovery+vbmeta (from May 2026 `F926BXXSIJZE5` firmware, since the
  phone's exact Sept 2026 build wasn't available from a trusted source) and flashed it
  successfully via heimdall. It's currently on the device.
- Hit one real scare: after flashing, normal system boot failed once ("couldn't load
  system") — **fixed by a factory reset**, no data of consequence lost (already backed up),
  device fully healthy afterward. Full incident writeup in
  [notes/procedure.md](notes/procedure.md#incident-system-boot-failure-after-recoveryvbmeta-flash-2026-09-23).
  Download Mode and heimdall access were never lost — this was never brick territory.
- **Blocked**: the patched recovery doesn't actually expose fastboot access. Tried three
  ways (visible "Enter Fastboot" menu option, automatic USB fastbootd exposure, `adb reboot
  fastboot` boot-reason flag) — none worked. The community hexpatch technique we used
  (patterns from ~Dec 2023) appears to be stale against this device's 2026 firmware; research
  suggests Samsung has been actively hardening/stripping recovery features through 2026.
- **Next steps to try** (not yet attempted): a different patch fork with updated hex
  patterns, or — probably higher-value — just asking Azkali directly (still active on the
  Fold3 scene as of Mar 2026) whether they've hit and solved this same 2026 hardening.

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

1. [x] Research how similar SM8350 (Snapdragon 888) Samsung devices achieve this — done,
   see [notes/procedure.md](notes/procedure.md).
2. [x] Confirm device details — done, see [notes/device-info.md](notes/device-info.md):
   SM-F926B, Android 15 (`F926BXXSJJZH3`).
3. [x] Download official `F926BXXSIJZE5` firmware (closest trusted match; exact build wasn't
   mirrored yet), extract `recovery.img.lz4` + `vbmeta.img.lz4`, patch and flash via heimdall.
   Done — see [notes/procedure.md](notes/procedure.md).
4. [x] Unlock the bootloader — done, stable, Knox tripped.
5. [ ] **Blocked**: patched recovery doesn't expose fastboot access (see Status above).
   Next: try an updated patch fork, or ask Azkali directly.
6. [ ] Pick a GSI to try once fastboot access works — see
   [notes/gsi-candidates.md](notes/gsi-candidates.md) (leaning Evolution X for first
   bring-up, LineageOS 23.2 GSI as the real target).
7. [ ] Optional: draft an XDA post to josip-k (q2q interest), Azkali (2026 recovery
   hardening / fastboot access status), and bgcngm (Tab S7 extended external display).

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
