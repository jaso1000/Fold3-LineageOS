#!/usr/bin/env bash
# Build the patched vendor image for the GSI from a STOCK Samsung vendor.img (e.g. extracted
# from the F926BXXSJJZH3 AP tar: super.img.lz4 -> lz4 -d -> simg2img -> lpunpack -p vendor).
# See notes/procedure.md ("Dual-screen switching").
#
# The only change: /vendor/etc/devicestate/device_state_configuration.xml is replaced by
# Samsung's own sec/ 6-state sensor config with the <lid-switch> conditions removed (the GSI's
# lid switch stays "open" forever, so CLOSE was unreachable and the outer screen never took over).
# Nothing of Samsung's is stored in this repo; the file is derived from the input image.
#
# Usage: make-vendor-image.sh <stock-vendor.img> <out.img>
# Flash from TWRP: adb push out.img /tmp/vendor.img, then in adb shell:
#   dd if=/tmp/vendor.img of=/dev/block/mapper/vendor bs=4M conv=fsync
set -euo pipefail

IN="${1:?stock vendor.img}"
OUT="${2:?output image}"
F=/etc/devicestate/device_state_configuration.xml
SEC=/etc/devicestate/sec/device_state_configuration.xml
LABEL='u:object_r:vendor_configs_file:s0'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

debugfs -R "cat $SEC" "$IN" 2>/dev/null > "$tmp/sec.xml"
grep -q '<lid-switch>' "$tmp/sec.xml" \
    || { echo "no <lid-switch> in $SEC; not a stock q2q vendor? refusing" >&2; exit 1; }
sed '/<lid-switch>/,/<\/lid-switch>/d' "$tmp/sec.xml" > "$tmp/device_state_configuration.xml"
printf '%s\0' "$LABEL" > "$tmp/label"

cp "$IN" "$OUT"
debugfs -w "$OUT" -f - >/dev/null 2>&1 <<EOF
rm $F
write $tmp/device_state_configuration.xml $F
set_inode_field $F mode 0100644
set_inode_field $F uid 0
set_inode_field $F gid 0
ea_set -f $tmp/label $F security.selinux
EOF

e2fsck -fn "$OUT" >/dev/null
debugfs -R "cat $F" "$OUT" 2>/dev/null | cmp -s - "$tmp/device_state_configuration.xml" \
    || { echo "verification failed" >&2; exit 1; }
echo "Built $OUT ($(debugfs -R "cat /build.prop" "$OUT" 2>/dev/null | grep -m1 ro.vendor.build.fingerprint | cut -d= -f2))"
