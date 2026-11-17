#!/data/data/com.termux/files/usr/bin/bash
# Log only; never starts/stops audio. No automatic background installation.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
[[ -r build/classes.dex ]] || { echo 'Run build.sh first.' >&2; exit 1; }
export CLASSPATH="$PWD/build/classes.dex"
exec /data/data/com.termux/files/usr/bin/timeout --signal=TERM 900 \
    /system/bin/app_process /system/bin ScreenProbe
