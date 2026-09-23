# GSI candidates

Tracking table for Android 16 arm64 GSIs to try via DSU on the Fold3 (q2q, SM8350).

| GSI | Base Android | Maintainer/source | A/B or A-only | Foldable support notes | Link | Tried? |
|---|---|---|---|---|---|---|
| | | | | | | |

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
