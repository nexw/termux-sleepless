#!/data/data/com.termux/files/usr/bin/bash
# SPDX-License-Identifier: MIT
#
# Install or remove termux-sleepless.
#
# Two modes:
#   * source checkout: install ./bin/termux-sleepless next to this script;
#   * standalone: download the latest release tarball, verify its SHA-256 and
#     install the script from it. This is what the documented one-liner uses:
#
#     curl -fsSL https://raw.githubusercontent.com/nexw/termux-sleepless/refs/heads/main/install.sh | bash
#
# No git and no source checkout are needed in the second mode.

set -eu

PROGRAM=${0##*/}
NAME=termux-sleepless
REPO=${TERMUX_SLEEPLESS_REPO:-nexw/termux-sleepless}
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
DEST_DIR="$PREFIX/bin"
ACTION=install
RELEASE=${TERMUX_SLEEPLESS_RELEASE:-latest}
RELEASE_TMP=''

usage() {
    cat <<EOF
$PROGRAM - install or remove $NAME

Usage:
  $PROGRAM [options]
  curl -fsSL https://raw.githubusercontent.com/$REPO/refs/heads/main/install.sh | bash

Options:
  --prefix DIR   Install into DIR/bin (default: \$PREFIX/bin)
  --dir DIR      Install into DIR (takes precedence over --prefix)
  --release TAG  Install this release tag instead of the latest one
  --uninstall    Remove the installed command
  -h, --help     Print this help

In a source checkout the local script is installed. Otherwise the release
tarball is downloaded from GitHub, its SHA-256 is verified, and the script is
installed from it.

State and logs under ~/.local/state/termux-sleepless are never removed here.
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
        --release)
            (($# >= 2)) || die '--release needs a tag'
            RELEASE=$2
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

# When the script is piped into bash there is no source file and no checkout,
# so the install falls back to downloading a release.
SCRIPT_DIR=''
script_path=${BASH_SOURCE[0]:-}
if [[ -n $script_path && -f $script_path ]]; then
    SCRIPT_DIR=$(cd -- "$(dirname -- "$script_path")" && pwd)
fi
LOCAL_SOURCE="${SCRIPT_DIR:+$SCRIPT_DIR/bin/$NAME}"
TARGET="$DEST_DIR/$NAME"

next_steps() {
    printf '\nNext steps:\n'
    printf '  %s start\n' "$TARGET"
    printf '  %s status\n' "$TARGET"
    printf '  %s install-boot   # optional autostart\n' "$TARGET"
}

source_version() {
    sed -n "s/^VERSION='\([^']*\)'$/\1/p" "$1"
}

install_file() {
    local source=$1 mode=$2 release_version=${3:-} version
    mkdir -p "$DEST_DIR"
    install -m 700 "$source" "$TARGET"
    case $mode in
        local)
            version=$(source_version "$source")
            printf 'Installed: %s (version %s)\n' "$TARGET" "${version:-unknown}"
            ;;
        release)
            printf 'Installed: %s (release %s)\n' "$TARGET" "$release_version"
            ;;
    esac
    case ":$PATH:" in
        *":$DEST_DIR:"*) ;;
        *) printf 'Warning: %s is not in PATH; use the full path.\n' "$DEST_DIR" ;;
    esac
    next_steps
}

verify_checksum() {
    local dir=$1 file=$2
    if command -v sha256sum >/dev/null 2>&1; then
        (cd "$dir" && sha256sum -c "$file.sha256")
    elif command -v shasum >/dev/null 2>&1; then
        (cd "$dir" && shasum -a 256 -c "$file.sha256")
    else
        die 'sha256sum or shasum is required to verify the download'
    fi
}

install_release() {
    local tmp_root tmp tag version base tarball source
    command -v curl >/dev/null 2>&1 || die 'curl is required to download a release'
    command -v tar >/dev/null 2>&1 || die 'tar is required to unpack a release'

    tmp_root=${TMPDIR:-}
    if [[ -z $tmp_root || ! -d $tmp_root ]]; then
        if [[ -d $PREFIX/tmp ]]; then
            tmp_root=$PREFIX/tmp
        elif [[ -d /tmp ]]; then
            tmp_root=/tmp
        else
            tmp_root=$PWD
        fi
    fi
    tmp=$(mktemp -d "$tmp_root/termux-sleepless.XXXXXX")
    RELEASE_TMP=$tmp
    trap 'rm -rf "${RELEASE_TMP:-}"' EXIT

    tag=$RELEASE
    if [[ $tag == latest ]]; then
        local api
        api=${TERMUX_SLEEPLESS_API:-https://api.github.com/repos/$REPO/releases/latest}
        tag=$(curl -fsSL "$api" |
            sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' |
            head -n 1)
        [[ -n $tag ]] || die "could not read the latest release tag from $api"
    fi
    version=${tag#v}

    base=${TERMUX_SLEEPLESS_BASE_URL:-https://github.com/$REPO/releases/download/$tag}
    tarball="$tmp/$NAME-$version.tar.gz"
    printf 'Downloading %s %s\n' "$NAME" "$version"
    curl -fsSL --retry 3 -o "$tarball" "$base/$NAME-$version.tar.gz" ||
        die "download failed: $base/$NAME-$version.tar.gz"
    curl -fsSL --retry 3 -o "$tarball.sha256" "$base/$NAME-$version.tar.gz.sha256" ||
        die "download failed: $base/$NAME-$version.tar.gz.sha256"

    verify_checksum "$tmp" "$(basename -- "$tarball")"
    tar -xzf "$tarball" -C "$tmp"
    source="$tmp/$NAME-$version/bin/$NAME"
    [[ -f $source ]] || die "unexpected tarball layout: missing bin/$NAME"

    install_file "$source" release "$version"
}

case $ACTION in
    install)
        if [[ -n $LOCAL_SOURCE && -f $LOCAL_SOURCE ]]; then
            install_file "$LOCAL_SOURCE" local
        else
            install_release
        fi
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
