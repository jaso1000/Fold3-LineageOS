#!/usr/bin/env bash
# Build the "fold3-signal-bars" Magisk module from tools/seh-signal. See notes/procedure.md
# ("Signal bars"). dump.txt comes from running tools/seh-signal/Dump.java on the phone.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/tools/seh-signal"
SDK="$ROOT/build/src/floss-sdk"
BT="$SDK/build-tools/34.0.0"
JAR="$SDK/platforms/android-33/android.jar"
MOD="$ROOT/magisk-src/fold3-signal-bars"

cd "$SRC"
python3 gen.py >/dev/null
rm -rf out && mkdir -p out/stubs out/cls
javac -nowarn -d out/stubs -cp "$JAR" $(find stubs -name "*.java")
javac -nowarn -d out/cls -cp "$JAR:out/stubs" $(find gen src -name "*.java")
"$BT/d8" --min-api 30 --lib "$JAR" --classpath out/stubs --output out $(find out/cls -name "*.class")
cp out/classes.dex "$MOD/seh-signal.dex"
mkdir -p "$ROOT/magisk"
(cd "$MOD" && rm -f "$ROOT/magisk/fold3-signal-bars.zip" && zip -qr "$ROOT/magisk/fold3-signal-bars.zip" .)
echo "Built $ROOT/magisk/fold3-signal-bars.zip"
