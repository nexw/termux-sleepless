#!/data/data/com.termux/files/usr/bin/bash
# SPDX-License-Identifier: MIT
#
# Install or remove the termux-keepalive command.

set -eu

PROGRAM=${0##*/}
NAME=termux-keepalive
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
DEST_DIR="$PREFIX/bin"
ACTION=install

usage() {
    cat <<EOF
$PROGRAM - install or remove $NAME

Usage: $PROGRAM [options]

Options:
  --prefix DIR   Install into DIR/bin (default: \$PREFIX/bin)
  --dir DIR      Install into DIR (takes precedence over --prefix)
  --uninstall    Remove the installed command
  -h, --help     Print this help

State and logs under ~/.local/state/termux-keepalive are never removed here.
EOF
}

die() {
    printf '%s: %s\n' "$PROGRAM" "$*" >&2
    exit 1
}

while (($# > 0)); do
    case $1 in
        --prefix)
            (($# >= 2)) || die '--prefix needs a directory'
            DEST_DIR="$2/bin"
            shift 2
            ;;
        --dir)
            (($# >= 2)) || die '--dir needs a directory'
            DEST_DIR=$2
            shift 2
            ;;
        --uninstall)
            ACTION=uninstall
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SOURCE="$SCRIPT_DIR/bin/$NAME"
TARGET="$DEST_DIR/$NAME"

case $ACTION in
    install)
        [[ -f $SOURCE ]] || die "cannot find $SOURCE (run this from a source checkout)"
        mkdir -p "$DEST_DIR"
        install -m 700 "$SOURCE" "$TARGET"
        printf 'Installed: %s\n' "$TARGET"
        case ":$PATH:" in
            *":$DEST_DIR:"*) ;;
            *) printf 'Warning: %s is not in PATH; use the full path.\n' "$DEST_DIR" ;;
        esac
        printf '\nNext steps:\n'
        printf '  %s start\n' "$TARGET"
        printf '  %s status\n' "$TARGET"
        printf '  %s install-boot   # optional autostart\n' "$TARGET"
        ;;
    uninstall)
        if [[ -f $TARGET ]]; then
            rm -f "$TARGET"
            printf 'Removed: %s\n' "$TARGET"
        else
            printf 'Not installed at %s.\n' "$TARGET"
        fi
        printf 'A running worker keeps running; stop it first if needed.\n'
        ;;
esac
