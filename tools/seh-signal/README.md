# seh-signal (prototype, not shipped)

Proof that Samsung's RIL reports signal bars only through `ISehRadioIndication.signalLevelInfoChanged`,
and that pushing them into TelephonyRegistry shows bars. Kept as reference for the ROM framework
patch. See notes/procedure.md ("Signal bars 0"). Don't run it as a boot service: rild accepts only one
ISehRadio client and hangs or restarts if that client misbehaves.

- `Dump.java`: run on the phone (`app_process`) to dump the Samsung HIDL Java signatures into `dump.txt`
- `gen.py`: generates compile-only stubs (`stubs/`) and no-op callback bases (`gen/`) from `dump.txt`
- `src/.../SehSignal.java`: registers for the callbacks and pushes levels; `Inject.java`: one-off push of a level
- Build: `scripts/make-signal-bars-module.sh` (module in `magisk-src/fold3-signal-bars`, not installed)
