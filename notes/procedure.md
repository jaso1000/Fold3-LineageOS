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

## Key finding: a Fold3-specific recovery already exists (but is stale)

A maintained TWRP/OrangeFox recovery for **exactly this device** (SM-F926B / q2q) exists:
Azkali's project, kernel based on F926BXXS8HXG6 (Android 14), device tree forked from a Z
Flip3 DT. XDA thread:
https://xdaforums.com/t/orangefox-and-twrp-recovery-recovery-for-sm-f926b.4660021/
Detailed install steps live on a companion wiki: https://fold-wiki.azka.li/en/Recovery
(returned a 502 when checked during this research session — retry before relying on it,
and fall back to the XDA thread's own posts/attachments if it stays down).

**Confirmed problem**: our actual device (checked 2026-09-23, see
[device-info.md](device-info.md)) is on `F926BXXSJJZH3`, Android 15 — a large firmware gap
from Azkali's Android 14 base, with the thread unanswered since Sep 2024. Samsung's
anti-rollback protection (ARB) means flashing an older AP/recovery against a newer
bootloader is expected to be refused outright (`SW REV CHECK FAIL`) rather than actually
work, per general Samsung ARB documentation — nobody has confirmed this specific
combination either way.

## Better plan: patch our own current-firmware recovery instead

Rather than depend on Azkali's dormant build, the standard technique for getting fastboot
access on **any** modern Samsung "dynamic partitions" device — version-matched, so no ARB
conflict at all — is to patch your own currently-installed stock recovery:

1. Download the **official** stock firmware matching what's actually on the phone
   (`F926BXXSJJZH3`) from SamFW or SamMobile.
2. Extract `recovery.img.lz4` and `vbmeta.img.lz4` from its `AP_*.tar.md5`.
3. Run those through a patch script/workflow that adds an "Enter Fastboot" option to the
   recovery and disables vbmeta verification — output is a single Odin-flashable
   `patched-recovery.tar.md5`. Two options, same underlying technique:
   - Local script (Linux/WSL — the Arch laptop works directly, no WSL needed): see the
     [XDA "Patch/Modify STOCK Recovery with fastbootd" guide](https://xdaforums.com/t/patch-modify-stock-recovery-with-fastbootd-only-dynamic-samsung-devices-twrp-alternative.4643956/) —
     a general technique for "Dynamic Samsung devices... Android 10 and above," not tied to
     one model.
   - Automated via GitHub Actions, no local Linux needed: fork
     [raidenii/recv-vbmeta-patcher](https://github.com/raidenii/recv-vbmeta-patcher), upload
     the two `.lz4` files, run the workflow, download the resulting `miniAP.tar.md5`.
4. Flash the patched tar via Odin to the **AP** slot (disable "Auto Reboot" in Odin options
   first, so the device stays put instead of letting stock system overwrite the patched
   recovery on first boot).
5. Manually boot to recovery (Vol- + Power to shut down, then Vol+ + Power) → a new **"Enter
   Fastboot"** option appears in the stock recovery menu → you now have full fastboot
   (`fastboot flash system`, `fastboot -w`, `fastboot getvar all`, etc.) without any
   device-specific TWRP/OrangeFox build at all.
6. **Pick and flash a GSI** — see [gsi-candidates.md](gsi-candidates.md). `fastboot flash
   system <path-to-gsi.img>`, matching arm64/A-B partition layout, then `fastboot -w`.
7. **Reverting to stock is symmetric**: re-extract a *clean* `recovery.img.lz4` +
   `vbmeta.img.lz4` from the same official firmware (no patching), repackage as a tar,
   reflash via Odin.
8. If bootloop after the GSI flash specifically (not the recovery step): the usual culprit
   is picking the wrong GSI variant (vndklite vs standard) — install the "Treble Info" app
   from Play/F-Droid on a *working* boot first if possible, or check community reports for
   q2q/S21-class Snapdragon 888 devices, to confirm which variant this device wants before
   re-flashing.

This sidesteps Azkali's stale build and the ARB mismatch entirely, since input and output
firmware versions match — it's not a downgrade, just a patch of what's already installed.
Azkali's recovery remains a fallback worth asking about directly (still XDA-active as of
Mar 2026 via the Ubuntu Touch thread), but isn't the critical path anymore.

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
- XDA "Patch/Modify STOCK Recovery with fastbootd only Dynamic Samsung Devices (TWRP Alternative)": https://xdaforums.com/t/patch-modify-stock-recovery-with-fastbootd-only-dynamic-samsung-devices-twrp-alternative.4643956/
- raidenii/recv-vbmeta-patcher (GitHub Actions version of the same technique): https://github.com/raidenii/recv-vbmeta-patcher
- Samsung ARB/anti-rollback mechanics (`SW REV CHECK FAIL`), confirming downgrades are the risky part, not patching in place
- phhusson/treble_experimentations — **archived/dead as of Jan 2025**; useful historically
  for the bootloop-troubleshooting pattern (vbmeta mismatch) but no longer maintained:
  https://github.com/phhusson/treble_experimentations
- Samsung DSU-not-supported confirmation (Samsung Members forum threads, multiple devices/years)
- XDA "Any custom os?" thread for the Fold3 — one post, May 2025, no replies. Confirms the
  scene really is this quiet: https://xdaforums.com/t/any-custom-os.4735111/

## Patch run log (2026-09-23)

Ran the raidenii/recv-vbmeta-patcher scripts locally (not GitHub Actions) against the
F926BXXSIJZE5 firmware's `recovery.img.lz4` + `vbmeta.img.lz4`. Source scripts reviewed
before running — they wrap Magisk's `magiskboot` and Google's own `avbtool`, plus a small
`vbmeta-disable-verification` utility; no networking, no obfuscation.

- `patch-vbmeta.sh`: flipped the AVB verification-disable flag. Clean, one-line success.
- `patch-recovery.sh`: unpacked the recovery boot image (confirmed `cpuinfo.chipname=SM8350`
  in the kernel cmdline — right chipset), extracted `system/bin/recovery`, ran ~18 candidate
  hex patches against it (a hexpatch is a no-op if its byte pattern isn't found — expected,
  since the patterns cover many Samsung recovery binary variants). **One pattern matched**:
  `Patch @ 0x0004C3FC [080109aae80000b4] -> [080109aae80000b5]` — this flips the branch
  condition that normally gates fastbootd access behind an ENG-build check. Repacked and
  re-signed with a throwaway key via `avbtool add_hash_footer` (fine — vbmeta verification
  is disabled anyway, this just gives the partition a well-formed AVB footer).
- `pack-odin.sh`: repacked both patched images and produced a valid Odin `.tar.md5`.

**Output**: `build/output/patched-recovery-vbmeta-F926BXXSIJZE5.tar.md5` (~48MB). Contains
`recovery.img.lz4` (patched, fastbootd-unlocked) + `vbmeta.img.lz4` (verification disabled).
Built from the F926BXXSIJZE5 base (not the phone's exact current F926BXXSJJZH3 build) —
same major Android 15 release, so this should be flashable without an anti-rollback
conflict, but hasn't been tested against the real device yet.

**Not yet done / still ahead**: flashing this via Odin (AP slot, Auto Reboot disabled),
manually booting to recovery, confirming the "Enter Fastboot" menu option actually appears
(this is the real test of whether the one matched hexpatch was the right one for this
device/build), then GSI flashing per the steps above. Only one hex pattern matched, so if
"Enter Fastboot" doesn't show up after flashing, that's the next thing to debug — may need
to try patching against the exact current firmware once available, or check if a different
recovery binary offset needs patching for this specific build.

## Incident: system boot failure after recovery+vbmeta flash (2026-09-23)

After flashing the patched recovery+vbmeta (built from May 2026 `F926BXXSIJZE5` firmware)
via heimdall, recovery booted fine, but attempting to boot to normal system hit **"Couldn't
load system, your data may be corrupt"**.

Initial hypothesis was a vbmeta rollback-index mismatch: our patched vbmeta was built from
May 2026 firmware, but the phone's actual system partition is the Sept 2026
(`F926BXXSJJZH3`) build — theorized that Samsung's rollback-index commitment in the older
vbmeta didn't match what's expected for the newer system, and that recovery's more lenient
boot-chain checks let it through while full system boot enforced it strictly.

**Resolution**: a factory reset (wipe data) from that error screen fixed it — phone booted
normally afterward. This actually argues *against* the rollback-index theory (a true
version-mismatch wouldn't be fixed by wiping `/data`, which doesn't touch the flashed
partitions) — more likely just a stale data/cache validation issue after the recovery/vbmeta
swap, not a genuine ARB conflict. Worth remembering if it recurs, but not treating it as a
hard blocker going forward.

**Confirmed not a brick at any point**: Download Mode and heimdall flashing remained fully
functional throughout, and recovery itself always booted — only normal system boot was
affected, and only until the reset.

**Post-recovery state**: bootloader still unlocked, Knox now tripped
(`ro.boot.warranty_bit`: 0 → 1) — this, not the earlier OEM-unlock toggle, is what actually
flipped it, confirming the theory from device-info.md that Knox trips on the first
non-Samsung-signed flash rather than the unlock step itself.

## Still open: does the patch actually expose fastboot?

Neither a visible "Enter Fastboot" recovery menu option nor automatic USB fastboot exposure
(`fastboot devices` from the plain recovery screen) were found after the first flash attempt.
Research suggests **Samsung stripped down recovery menu options in 2026 firmware**, and the
community hexpatch patterns (originally written ~Dec 2023) have documented compatibility
issues against newer One UI builds — our one matched pattern may not have been the actual
correct gate for this build. A promising untried lead: `adb reboot fastboot` sent from a
normally-booted system (not navigating the recovery UI) may reach fastbootd directly via the
boot-reason flag, per a same-symptom report in
https://github.com/Johx22/Patch-Recovery/issues/8 (unresolved in that thread, but worth
testing here). Not yet tested against this device.
