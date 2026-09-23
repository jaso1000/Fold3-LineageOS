# Device info

Confirmed 2026-09-23 via `scripts/check-device.sh`.

- Model: SM-F926B (q2q) — confirmed
- Build: `AP3A.240905.015.A2.F926BXXSJJZH3` — **Android 15**
- PDA/bootloader: `F926BXXSJJZH3`
- CSC sales code: `VAU` (Australia)
- Developer options enabled: yes (`development_settings_enabled=1`)
- USB debugging enabled: yes (`adb_enabled=1`)
- Bootloader lock status: **locked** (`ro.boot.flash.locked=1`)
- Knox warranty bit: **0 — not yet tripped** (OEM unlock/root has never been used on this
  device)
- OEM unlocking toggle visibility in Developer Options: not yet confirmed directly on-screen
  — check manually before proceeding (adb can't read this setting remotely).

## Why this matters: firmware gap vs. the recovery we're relying on

Azkali's q2q recovery (our planned path) is built against **F926BXXS8HXG6** — an
Android 14 build. This phone is on **F926BXXSJJZH3** — Android 15. Comparing Samsung's
build-suffix versioning (`8H...` vs `JJ...`, a large alphabetic jump), this is a
substantial firmware gap — plausibly 12-18+ months of updates apart, likely several
security-patch revisions.

Per [procedure.md](procedure.md), Samsung's anti-rollback protection means flashing an
older AP/recovery against a newer bootloader typically gets refused by Odin
(`SW REV CHECK FAIL`) rather than working — bootloop or brick is possible but less likely
than a clean refusal, per community reports on downgrade attempts generally. **Nobody has
confirmed Azkali's specific recovery works against Android 15 firmware** — the XDA thread
has zero replies since Sep 2024.

**Recommendation: do not flash this recovery yet.** Next step should be confirming with
Azkali (still active on the Fold3 as of Mar 2026 per the Ubuntu Touch thread) whether a
newer build exists or whether this one is known to work/not-work on Android 15 firmware,
before touching the bootloader.

## Raw output

```
== adb devices ==
List of devices attached
[adb-serial]            device usb:3-2 product:q2qxxx model:SM_F926B device:q2q transport_id:11

== build props ==
SM-F926B
q2qxxx
AP3A.240905.015.A2.F926BXXSJJZH3
15
F926BXXSJJZH3
VAU
F926BXXSJJZH3

== OEM unlock / dev options relevant settings ==
1
1

== Knox/warranty (informational only) ==
0
1
```

## Firmware downloaded for recovery-patching

`F926BXXSIJZE5_F926BOXMIJZE5_F926BXXSIJZE5_XSA.zip` (9.2GB) downloaded to
`~/Downloads/`, MD5 verified against SamMobile's published checksum
(`da063969173029513184c25858d24e77`) — confirmed intact 2026-09-23.

This is the XSA (Australia, unbranded) build of F926BXXSIJZE5, Android 15, security patch
2026-05-05 — **not an exact match** to the phone's current build (F926BXXSJJZH3, Sept 2026)
but same major Android 15 release, from a trusted source. See procedure.md for the
recovery/vbmeta patching plan using this file.

## Bootloader unlock (2026-09-23)

Confirmed unlocked via re-run of check-device.sh:
- `ro.boot.flash.locked`: `1` → `0` (unlocked)
- `ro.boot.warranty_bit`: still `0` — Knox trip apparently triggers on first non-Samsung-signed
  flash, not from the OEM unlock toggle alone on this device/firmware. Expect this to flip to
  `1` (permanently) once the patched recovery is flashed.

Build still reports `F926BXXSJJZH3` post-wipe, as expected (unlocking doesn't change firmware
version, just the lock state).

### Note on entering Download Mode on this device/firmware

The classic Vol Up + Vol Down + USB combo (and `adb reboot download`) landed on a stripped-down
"D2 error" blue screen instead of the real warning/unlock UI — Samsung's newer firmware blocks
the classic Download Mode entry while any lock-screen security (PIN/pattern/biometrics) is
active. Fix that worked: Settings → Security and Privacy → Lock Screen → set to None (does not
wipe data), power off completely, then Vol Up + Vol Down + USB — this reached the real screen.
Re-enable lock screen security after flashing is done.
