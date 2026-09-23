# GSI candidates

Tracking table for arm64 GSIs to try on the Fold3 (q2q, SM8350). DSU is not an option on
Samsung devices (see [procedure.md](procedure.md)) — these get flashed directly via
`fastboot flash system` after installing Azkali's q2q recovery, which is a destructive-ish
step (reflashing stock via Odin is the way back, not a reboot).

| GSI | Base Android | Maintainer/source | A/B or A-only | Foldable support notes | Link | Tried? |
|---|---|---|---|---|---|---|
| LineageOS 23.2 GSI (vanilla or GAPPS, erofs or ext4) | LOS 23.2 (~Android 16) | MisterZtr, TrebleDroid-based, actively released (last checked: 2026-05-24 build) | A/B, arm64 | No foldable-specific logic; generic GSI. Matches the LOS version already running on the Tab S7 project. | https://github.com/MisterZtr/LineageOS_gsi/releases | No |
| Evolution X | Android 14-based GSI | mytja | A/B, arm64 | Recommended as "best tested" in the S21 5G Snapdragon thread (same SoC family) — worth trying first since Android-14-based GSIs reportedly keep fingerprint + SMS working on that device class. | via GSI list linked from S21 thread | No |

## First pick

Start with the **S21-recommended Evolution X (Android 14 base)** for the initial
bring-up test, since it's the only one with a same-SoC success report (fingerprint + RIL
working). Move to the **LineageOS 23.2 GSI** once basic boot/RIL/fingerprint is confirmed
working at all on q2q, since that's the actual end goal and it's still under active
development.

## Requirements to check per candidate

- arm64 + binder64 (all modern Samsung devices need this variant)
- vndklite vs full vndk (Samsung devices often need vndklite GSIs)
- Whether it's confirmed working via DSU on Snapdragon 888 Samsung devices elsewhere
  (Fold3/S21 series share SM8350 — check S21 GSI threads too, more active community)
- Outer-display handling: does it detect/support the cover screen at all, or main-screen-only?

## Notes

- DSU-installed GSIs are read-only overlay style and easy to remove (`adb shell am start
  -n com.android.dynsystem/.VerificationActivity ... ` or via Developer Options > Dynamic
  System Updates), which makes this a safe first test even before deciding to daily-drive
  anything.
- S21 (SM-G991B, also SM8350) GSI/Treble threads are a good proxy for driver compatibility
  since the SoC and most blobs are shared with Fold3.
