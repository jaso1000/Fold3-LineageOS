# Fold3 ROM build additions

Everything that turns MisterZtr's LineageOS 23.2 TrebleDroid GSI into the Fold3 ROM. Applied on
top of his patches with `rom/apply.sh`; see [notes/rom-packaging-todo.md](../notes/rom-packaging-todo.md)
for the plan and status.

```bash
cd ~/android/lineage
bash LineageOS_gsi/patches/apply-patches.sh .     # MisterZtr's patches (once per sync)
bash ~/Projects/Fold3-LineageOS/rom/apply.sh .    # ours (re-runnable)
. build/envsetup.sh && breakfast lineage_arm64_bvN4-bp4a-userdebug && make systemimage -j12
```

## What replaces which Magisk module

| Magisk module / manual step | In the ROM |
|---|---|
| `fold3-outer-touch` (binary patch of `libpowermanager.so`) | `patches/platform_frameworks_native`: `setInteractiveAsync(enabled, -1)` |
| patched vendor image (dual-screen `<lid-switch>`) | `fold3-early.sh`: bind-mounts the fixed config at boot (stock vendor works) |
| `fold3-media-c2-seccomp` | already upstream in TrebleDroid `rw-system.sh` (2026-07-26) |
| `fold3-usb-audio` | `fold3-early.sh` (same bind mount) |
| `fold3-fold-config` overlays, display config, camera-id prop, helper | RROs `Fold3FrameworkOverlay` / `Fold3ApertureOverlay`, product displayconfig, system prop, service `fold3_fold_config` |
| `fold3-floss-ims` + `persist.sys.phh.ims.floss` | priv-app `FlossIms` + privapp permissions + system prop; hidden-API exemption in `fold3-boot.sh` |
| `fold3-net-fixes` | `fold3-boot.sh` |
| `fold3-desktop` | service `fold3_desktop` + system prop; USB device list moves to `/data/misc/fold3/usb-history` |
| `fold3-fingerprint-fix` | service `fold3_fingerprint` (started at post-fs-data), dex in `/system/etc/fold3` |
| `pm disable …SafetySourceReceiver` | `fold3-boot.sh` |
| `fold3-android-auto`, GSF permissions | MindTheGapps |

Milestone 3 (framework) fixes, also applied by `apply.sh`:

| Problem | Fix |
|---|---|
| Signal bars always 0 | `patches/platform_frameworks_opt_telephony`: `ISehRadio…signalLevelInfoChanged` → SignalStrength (+ `CA_ENABLED=1`) |
| Fingerprint enrollment lost at boot / after a HAL restart | `patches/platform_frameworks_base`: HIDL adapter sets the active group on every new HAL connection (the boot service still covers rild restarts) |
| Samsung logo stays on the screen not in use | `patches/platform_frameworks_native` 0002: SurfaceFlinger sends HWC ON→OFF once for an internal panel it only thinks is off (the bootloader left it lit; an OFF request on an "already OFF" display used to return early) |

| VoLTE off after a flash (`carrier_volte_available` override lost; `cmd phone cc` is refused while PlayIntegrityFork reports a user build) | `patches/packages_apps_CarrierConfig`: VoLTE available for Telstra (1345) and Boost (2503, new) |

Still manual: the IMS APN (kept in data across flashes). Not done: phone app slow start (root
cause), built-in Play Integrity spoof (use PlayIntegrityFork).

**Adaptive refresh rate** (48–120 Hz): the framework's default refresh-rate vote capped rendering at
60 Hz (`defaultRefreshRate` 60, `defaultPeakRefreshRate` 0, and the max is min(default, peak)).
`Fold3FrameworkOverlay` sets default 0 / peak 120, like Pixels. Forcing Settings → Display →
Minimum refresh rate → 120 Hz still works if you want it fixed at 120 (costs battery).

**Always-on display in low-power mode**: SystemUI's `doze_display_state_supported` defaults to
false, so AOD ran as a normal screen at low brightness (SurfaceFlinger power On, 48–60 Hz). The
system property `doze.display.supported=true` makes it request STATE_DOZE; Samsung's driver then
enters panel LPM (measured on the outer screen: 30 Hz).

**AOD double tap, pocket, brightness** (2026-09-26):
- `patches/platform_frameworks_base` 0002: TrebleDroid always called Samsung sysinput
  `setTspEnable` for device 1; the cover screen's panel (device 2) never got doze/off, so in AOD
  its touch stayed in normal mode and double tap didn't wake. Now device 1/2 per built-in display.
- `Fold3LineageOverlay`: LineageOS "Prevent accidental wake-up" (proximity check before any
  wake-up) available and on by default; AOSP doze already pauses AOD while the proximity sensor
  is covered.
- `Fold3FrameworkOverlay`: `config_allowAutoBrightnessWhileDozing`; the cover-screen helper follows
  the framework's doze brightness (floor 10%; `persist.fold3.outer_aod` forces a level).

Scripts run as root in TrebleDroid's `phhsu_daemon` domain (like `rw-system.sh`) and exit at once
unless `ro.product.vendor.model` is `SM-F926*`. The module scripts in `magisk-src/` stay the single
source; `apply.sh` copies them in.
