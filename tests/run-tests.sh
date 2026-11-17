#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# End-to-end tests for bin/termux-sleepless. The tests run anywhere bash,
# coreutils and mktemp exist (Linux CI and Termux). Termux:API is replaced by
# a fake player, so no Android device is required.

set -uo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
NAME=termux-sleepless
COMMAND="$ROOT/bin/termux-sleepless"
INSTALL="$ROOT/install.sh"
VERSION=$(sed -n "s/^VERSION='\(.*\)'$/\1/p" "$COMMAND")

tmpbase=${TMPDIR:-}
if [[ -z $tmpbase || ! -d $tmpbase ]]; then
    if [[ -d /tmp ]]; then tmpbase=/tmp; else tmpbase=$PWD; fi
fi
TMP=$(mktemp -d "$tmpbase/termux-sleepless-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

FAKE_BIN="$TMP/bin"
TEST_HOME="$TMP/home"
STATE="$TMP/state"
CALLS="$TMP/calls"
CURRENT="$TMP/current-track"

pass=0
fail=0

fail() {
    fail=$((fail + 1))
    printf 'FAIL: %s\n' "$1" >&2
}

check_eq() {
    local name=$1 expected=$2 actual=$3
    if [[ $expected == "$actual" ]]; then
        pass=$((pass + 1))
    else
        fail "$name: expected [$expected], got [$actual]"
    fi
}

check_contains() {
    local name=$1 needle=$2 haystack=$3
    if [[ $haystack == *"$needle"* ]]; then
        pass=$((pass + 1))
    else
        fail "$name: expected to contain [$needle], got [$haystack]"
    fi
}

check_status() {
    local name=$1 expected=$2 actual=$3
    if [[ $expected == "$actual" ]]; then
        pass=$((pass + 1))
    else
        fail "$name: expected exit $expected, got $actual"
    fi
}

# The script prepends $PREFIX/bin to PATH; point PREFIX at an empty
# directory so the fake Termux:API commands win over real ones.
FAKE_PREFIX="$TMP/prefix"
mkdir -p "$FAKE_BIN" "$TEST_HOME" "$STATE" "$FAKE_PREFIX/bin"

cat >"$FAKE_BIN/termux-media-player" <<'FAKE'
#!/usr/bin/env bash
set -u
printf 'media-player %s\n' "$*" >>"${FAKE_CALLS:?}"
case ${1:-} in
    play)
        printf '%s\n' "${2:-}" >"${FAKE_CURRENT:?}"
        printf 'Playing\n'
        ;;
    info)
        if [[ -s ${FAKE_CURRENT:?} ]]; then
            printf 'Status: Playing\nTrack: %s\n' "$(basename "$(cat "$FAKE_CURRENT")")"
        else
            printf 'Status: Stopped\n'
        fi
        ;;
    stop)
        rm -f "${FAKE_CURRENT:?}"
        printf 'Stopped\n'
        ;;
    *)
        printf 'fake player: unsupported command: %s\n' "${1:-}" >&2
        exit 1
        ;;
esac
FAKE

cat >"$FAKE_BIN/termux-wake-lock" <<'FAKE'
#!/usr/bin/env bash
printf 'wake-lock\n' >>"${FAKE_CALLS:?}"
FAKE

chmod +x "$FAKE_BIN/termux-media-player" "$FAKE_BIN/termux-wake-lock"

# Keep the real PATH minus any Termux player, and put the fakes first.
run() {
    HOME="$TEST_HOME" \
        PREFIX="$FAKE_PREFIX" \
        TERMUX_SLEEPLESS_STATE_DIR="$STATE" \
        TERMUX_SLEEPLESS_BOOT_FILE="$TEST_HOME/.termux/boot/10-sleepless.sh" \
        FAKE_CALLS="$CALLS" \
        FAKE_CURRENT="$CURRENT" \
        PATH="$FAKE_BIN:$PATH" \
        bash "$COMMAND" "$@"
}

# Wait until a file contains a string, so tests never race the worker.
wait_for() {
    local file=$1 needle=$2 i
    for ((i = 0; i < 100; i++)); do
        [[ -f $file ]] && grep -Fq "$needle" "$file" && return 0
        sleep 0.1
    done
    return 1
}

# --- version, help and argument handling ------------------------------------

out=$(run version)
check_eq 'version output' "termux-sleepless $VERSION" "$out"

out=$(run --version)
check_eq '--version output' "termux-sleepless $VERSION" "$out"

run --help >/dev/null
check_status '--help exits 0' 0 $?
out=$(run --help)
check_contains 'help lists start' 'start' "$out"

out=$(run help)
check_contains 'help mentions state dir' 'TERMUX_SLEEPLESS_STATE_DIR' "$out"

out=$(run nonsense 2>&1)
check_status 'unknown command exits 2' 2 $?
check_contains 'unknown command message' 'unknown command' "$out"

# --- generate ---------------------------------------------------------------

wav=$(run generate)
check_status 'generate exits 0' 0 $?
check_eq 'generate prints the wav path' "$STATE/insomnia.wav" "$wav"
check_eq 'wav exists' 'yes' "$([[ -s $wav ]] && echo yes || echo no)"

size=$(wc -c <"$wav")
check_eq 'wav size is 44 bytes header plus 65s of 16-bit 8kHz mono' 1040044 "$size"

magic=$(dd if="$wav" bs=1 count=4 2>/dev/null)
check_eq 'wav magic' 'RIFF' "$magic"
format=$(dd if="$wav" bs=1 skip=8 count=4 2>/dev/null)
check_eq 'wav format' 'WAVE' "$format"
chunk=$(dd if="$wav" bs=1 skip=36 count=4 2>/dev/null)
check_eq 'wav data chunk' 'data' "$chunk"
data_size=$(od -An -tu4 -j40 -N4 "$wav" | tr -d ' ')
check_eq 'wav data chunk size' 1040000 "$data_size"
channels=$(od -An -tu2 -j22 -N2 "$wav" | tr -d ' ')
check_eq 'wav channels' 1 "$channels"
rate=$(od -An -tu4 -j24 -N4 "$wav" | tr -d ' ')
check_eq 'wav sample rate' 8000 "$rate"
bits=$(od -An -tu2 -j34 -N2 "$wav" | tr -d ' ')
check_eq 'wav bit depth' 16 "$bits"
nonzero=$(od -An -v -tx1 -j44 -N64 "$wav" | tr -d ' \n')
check_eq 'wav samples are digital silence' "$(printf '%0128d' 0)" "$nonzero"

first=$(sha256sum "$wav" | cut -d' ' -f1)
run generate >/dev/null
second=$(sha256sum "$wav" | cut -d' ' -f1)
check_eq 'generate reuses an existing wav' "$first" "$second"

printf 'x' >>"$wav"
run generate >/dev/null
check_eq 'generate repairs a wrong-sized wav' "$size" "$(wc -c <"$wav")"

# --- status and start/stop --------------------------------------------------

out=$(run status)
check_status 'status exits 1 when stopped' 1 $?
check_contains 'status reports not running' 'Not running' "$out"

out=$(run start)
check_status 'start exits 0' 0 $?
check_contains 'start reports the pid' 'Started (pid' "$out"

# The worker takes a moment to request the wake lock and start playback.
wait_for "$CALLS" 'wake-lock'
check_contains 'worker requests the wake lock' 'wake-lock' "$(cat "$CALLS" 2>/dev/null)"

wait_for "$CALLS" 'play'
check_contains 'worker plays the wav' "media-player play $STATE/insomnia.wav" "$(cat "$CALLS" 2>/dev/null)"

out=$(run status)
check_status 'status exits 0 when running' 0 $?
check_contains 'status reports running' 'Running (pid' "$out"

out=$(run start)
check_contains 'second start is idempotent' 'Already running' "$out"

out=$(run logs)
check_contains 'log records the worker' 'worker started' "$out"

out=$(run stop)
check_status 'stop exits 0' 0 $?
check_contains 'stop stops the shared player' 'media-player stop' "$(cat "$CALLS" 2>/dev/null)"

out=$(run status)
check_status 'status exits 1 after stop' 1 $?

out=$(run stop)
check_contains 'stop is idempotent' 'Not running' "$out"

printf '999999\n' >"$STATE/pid"
out=$(run status)
check_status 'status ignores a stale pid file' 1 $?
rm -f "$STATE/pid"

# --- missing termux-api -----------------------------------------------------

out=$(
    export HOME="$TEST_HOME" PREFIX="$FAKE_PREFIX"
    export TERMUX_SLEEPLESS_STATE_DIR="$STATE"
    export PATH=/usr/bin:/bin
    "${BASH:-bash}" "$COMMAND" start 2>&1
)
check_status 'start fails without termux-api' 1 $?
check_contains 'start explains the missing dependency' 'termux-media-player' "$out"

# --- boot entry -------------------------------------------------------------

boot="$TEST_HOME/.termux/boot/10-sleepless.sh"
out=$(run install-boot)
check_status 'install-boot exits 0' 0 $?
check_contains 'install-boot reports the path' "$boot" "$out"
check_contains 'boot entry is managed' '# Managed by termux-sleepless' "$(cat "$boot")"
check_contains 'boot entry starts the worker' '" start' "$(cat "$boot")"
perms=$(stat -c '%a' "$boot" 2>/dev/null || stat -f '%Lp' "$boot")
check_eq 'boot entry is executable' '700' "$perms"

out=$(run uninstall-boot)
check_status 'uninstall-boot exits 0' 0 $?
check_eq 'boot entry is removed' 'no' "$([[ -e $boot ]] && echo yes || echo no)"

out=$(run uninstall-boot)
check_contains 'uninstall-boot is idempotent' 'No managed boot entry' "$out"

mkdir -p "${boot%/*}"
printf '#!/bin/sh\necho user file\n' >"$boot"
out=$(run install-boot 2>&1)
check_status 'install-boot refuses unmanaged files' 1 $?
check_contains 'install-boot refuses unmanaged files with a message' 'Refusing to overwrite' "$out"
rm -f "$boot"

# --- install.sh -------------------------------------------------------------

installed_dir="$TMP/install-local"
out=$(bash "$INSTALL" --dir "$installed_dir" 2>&1)
check_status 'install.sh installs from a checkout' 0 $?
check_contains 'install.sh reports a version' "(version $VERSION)" "$out"
check_eq 'installed command exists' 'yes' "$([[ -x $installed_dir/$NAME ]] && echo yes || echo no)"
check_eq 'installed command runs' "termux-sleepless $VERSION" "$(bash "$installed_dir/$NAME" version)"

out=$(bash "$INSTALL" --dir "$installed_dir" --uninstall 2>&1)
check_status 'install.sh uninstalls' 0 $?
check_eq 'installed command is gone' 'no' "$([[ -e $installed_dir/$NAME ]] && echo yes || echo no)"

# A standalone copy has no checkout next to it, so it must download a release.
# Fake release: API response, tarball and checksum behind file:// URLs, so the
# download path is tested without network access.
mkdir -p "$TMP/standalone"
cp "$INSTALL" "$TMP/standalone/install.sh"
STANDALONE="$TMP/standalone/install.sh"
release_dir="$TMP/release"
stage="$TMP/stage/$NAME-$VERSION"
mkdir -p "$release_dir" "$stage/bin"
cp "$COMMAND" "$stage/bin/$NAME"
(cd "$TMP/stage" && tar -czf "$release_dir/$NAME-$VERSION.tar.gz" "$NAME-$VERSION")
(cd "$release_dir" && sha256sum "$NAME-$VERSION.tar.gz" >"$NAME-$VERSION.tar.gz.sha256")
printf '{\n  "tag_name": "v%s"\n}\n' "$VERSION" >"$TMP/api.json"
api_url="file://$TMP/api.json"
base_url="file://$release_dir"

remote_dir="$TMP/install-remote"
out=$(TERMUX_SLEEPLESS_API="$api_url" TERMUX_SLEEPLESS_BASE_URL="$base_url" \
    bash "$STANDALONE" --dir "$remote_dir" 2>&1)
check_status 'install.sh downloads a release' 0 $?
check_contains 'install.sh verifies the checksum' 'OK' "$out"
check_contains 'install.sh reports the release' "(release $VERSION)" "$out"
check_eq 'downloaded command runs' "termux-sleepless $VERSION" "$(bash "$remote_dir/$NAME" version)"

pipe_dir="$TMP/install-piped"
out=$(cat "$STANDALONE" | TERMUX_SLEEPLESS_API="$api_url" TERMUX_SLEEPLESS_BASE_URL="$base_url" \
    bash -s -- --dir "$pipe_dir" 2>&1)
check_status 'install.sh works when piped' 0 $?
check_eq 'piped install runs' "termux-sleepless $VERSION" "$(bash "$pipe_dir/$NAME" version)"

# bash < install.sh leaves BASH_SOURCE unset, unlike bash -s.
redir_prefix="$TMP/prefix-redirected"
out=$(TERMUX_SLEEPLESS_API="$api_url" TERMUX_SLEEPLESS_BASE_URL="$base_url" \
    PREFIX="$redir_prefix" bash <"$STANDALONE" 2>&1)
check_status 'install.sh works with a redirected stdin' 0 $?
check_eq 'redirected install runs' "termux-sleepless $VERSION" "$(bash "$redir_prefix/bin/$NAME" version)"

bad_dir="$TMP/release-bad"
cp -r "$release_dir" "$bad_dir"
printf 'tampered\n' >>"$bad_dir/$NAME-$VERSION.tar.gz"
out=$(TERMUX_SLEEPLESS_API="$api_url" TERMUX_SLEEPLESS_BASE_URL="file://$bad_dir" \
    bash "$STANDALONE" --dir "$TMP/install-bad" 2>&1)
check_status 'install.sh rejects a bad checksum' 1 $?
check_eq 'nothing installed after a bad checksum' 'no' "$([[ -e $TMP/install-bad/$NAME ]] && echo yes || echo no)"

tag_dir="$TMP/install-tag"
out=$(TERMUX_SLEEPLESS_BASE_URL="$base_url" bash "$STANDALONE" --dir "$tag_dir" --release "v$VERSION" 2>&1)
check_status 'install.sh accepts --release' 0 $?
check_eq 'pinned install runs' "termux-sleepless $VERSION" "$(bash "$tag_dir/$NAME" version)"

# --- summary ----------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$pass" "$fail"
((fail == 0))
