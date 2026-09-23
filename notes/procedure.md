# Working procedure (research-derived, not yet tested on-device)

Synthesized from the S21 5G Snapdragon GSI guide (same SM8350/Snapdragon 888 SoC as the
Fold3) and Azkali's SM-F926B (q2q) recovery project, which is device-specific to the Fold3.
See [Sources](#sources) below. **Nothing here has been run against the actual phone yet** —
treat it as a draft to validate step by step once the device is connected.

## Correction to the original handoff plan: DSU is not usable on Samsung

The original plan assumed testing a GSI via Android's built-in **DSU (Dynamic System
Updates)** loader, since it's non-destructive (boots a guest OS, reboot returns to stock).
Research shows **Samsung deliberately strips the DSU Loader out of One UI's Developer
options on all Galaxy devices** — it's not hidden or togglable, the code path simply isn't
shipped. This is corroborated by multiple Samsung Members forum threads and is consistent
across devices/years. So DSU is off the table; there's no non-destructive way to test-boot
a GSI on this phone.

The actual community method for Samsung devices instead **replaces the recovery and system
partition directly**, using a custom recovery (TWRP/OrangeFox) built for the exact model to
handle AVB/vbmeta, then `fastboot flash system` the GSI. This is what the Tab S7 project
also effectively did (samloader + sideload), just with an official LineageOS device tree
instead of a generic image. It's reversible (can reflash stock firmware via Odin) but not
as casually reversible as DSU would have been — treat the bootloader unlock as the
commit point.

## Key finding: a Fold3-specific recovery already exists

Unlike LineageOS itself, a maintained TWRP/OrangeFox recovery for **exactly this device**
(SM-F926B / q2q) exists: Azkali's project, kernel based on F926BXXS8HXG6 (Android 14),
device tree forked from a Z Flip3 DT. XDA thread:
https://xdaforums.com/t/orangefox-and-twrp-recovery-recovery-for-sm-f926b.4660021/
Detailed install steps live on a companion wiki: https://fold-wiki.azka.li/en/Recovery
(returned a 502 when checked during this research session — retry before relying on it,
and fall back to the XDA thread's own posts/attachments if it stays down).

This matters because it means the hard, device-specific part (a working AVB/vbmeta bypass
and boot chain for q2q) is already solved by someone else, rather than something we'd need
to reverse-engineer from scratch.

## Draft procedure (S21-guide pattern, adapted with q2q-specific recovery)

1. **Confirm identity + unlock eligibility** — run `scripts/check-device.sh`. Non-US
   Snapdragon Samsung variants (ours is Australian SM-F926B) are generally unlockable;
   US carrier variants of Snapdragon Samsung phones typically are not. Australian retail
   should be fine, but verify "OEM unlocking" actually appears in Developer Options before
   going further.
2. **Back up everything.** Unlocking wipes the device and permanently trips Knox
   (Samsung Pay/Wallet, Secure Folder, Health lost; some banking apps may refuse to run
   afterward). This is a one-way door — confirm before proceeding.
3. **Unlock the bootloader**: Settings > Developer options > OEM unlocking (toggle on) →
   reboot to Download Mode (Power+Vol Down at power-off, or `adb reboot download`) →
   Vol Up to confirm unlock → device factory-resets itself.
4. **Flash Azkali's recovery via Odin/SamFW Tool**: AP slot = recovery image tar
   (`OrangeFox-Unofficial-q2q.img.tar` or TWRP equivalent), DATA slot = the matching
   `vbmeta.tar` from the *same* release (mixing vbmeta from a different build/device is
   the classic cause of bootloops per the treble_experimentations issue tracker).
5. **Boot into the custom recovery**, then reboot to fastboot(d) mode from its menu.
6. **Pick and flash a GSI** — see [gsi-candidates.md](gsi-candidates.md). `fastboot flash
   system <path-to-gsi.img>`, matching arm64/A-B partition layout.
7. **Wipe data** from recovery (mandatory after a system-partition swap), then reboot.
8. If bootloop: the usual culprits are (a) vbmeta mismatched to the recovery build, or
   (b) picking the wrong GSI variant (vndklite vs standard) — install the "Treble Info" app
   from Play/F-Droid on a *working* boot first if possible, or check community reports for
   q2q/S21-class Snapdragon 888 devices, to confirm which variant this device wants before
   re-flashing.

## Realistic expectations

Per the S21 Snapdragon GSI thread (same SoC family) and general GSI-on-foldable caveats
from the original handoff:
- Working, generally: boot, calls/SMS/data (RIL), fingerprint (on Android 14-based GSIs
  specifically — older/newer GSI Android versions reportedly break fingerprint/SMS on the
  S21 thread), audio, basic sensors.
- Flaky: Bluetooth on some builds.
- Foldable-specific and *not* covered by a generic (non-foldable-aware) GSI: inner/outer
  display switching, cover-screen brightness curve, possibly the side fingerprint reader's
  exact placement handling, some cameras, VoLTE/VoWiFi (carrier-dependent, may need APN/IMS
  config work regardless of ROM).
- No OTA updates — GSIs on an unsupported device are manually reflashed per update.

## Sources

- S21 5G Snapdragon GSI guide (technique template, same SoC): https://xdaforums.com/t/rom-14-gsi-custom-roms-for-galaxy-s21-5g-snapdragon-g9910-g991u-g991u1-scg09-sc-51b.4759120/
- Azkali's SM-F926B (q2q) recovery thread: https://xdaforums.com/t/orangefox-and-twrp-recovery-recovery-for-sm-f926b.4660021/
- Companion install-steps wiki (502 at last check, retry): https://fold-wiki.azka.li/en/Recovery
- MisterZtr/LineageOS_gsi (candidate GSI, TrebleDroid-based LOS 23.2): https://github.com/MisterZtr/LineageOS_gsi
- phhusson/treble_experimentations — **archived/dead as of Jan 2025**; useful historically
  for the bootloop-troubleshooting pattern (vbmeta mismatch) but no longer maintained:
  https://github.com/phhusson/treble_experimentations
- Samsung DSU-not-supported confirmation (Samsung Members forum threads, multiple devices/years)
- XDA "Any custom os?" thread for the Fold3 — one post, May 2025, no replies. Confirms the
  scene really is this quiet: https://xdaforums.com/t/any-custom-os.4735111/
