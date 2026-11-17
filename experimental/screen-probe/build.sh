#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
D8_JAR="${D8_JAR:-$PREFIX/share/java/d8.jar}"
[[ -f "$D8_JAR" ]] || { echo "Missing d8: $D8_JAR" >&2; exit 1; }
# Use a fresh output directory: Android 14+ requires read-only runtime DEX.
out=$(mktemp -d "$PWD/build-stage.XXXXXX")
trap 'rm -rf -- "$out"' EXIT
mkdir -p "$out/classes" "$out/dex"
mapfile -t stubs < <(find stubs -name '*.java' -print)
javac --release 8 -Xlint:-options -d "$out/classes" "${stubs[@]}" ScreenProbe.java
java -cp "$D8_JAR" com.android.tools.r8.D8 --min-api 26 \
    --output "$out/dex" "$out"/classes/ScreenProbe*.class
chmod 400 "$out/dex/classes.dex"
mkdir -p build
mv -f "$out/dex/classes.dex" build/classes.dex
echo "Built: $PWD/build/classes.dex"
