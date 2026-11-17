# Installation

## 1. Termux and the add-ons

Install Termux from [F-Droid](https://f-droid.org/packages/com.termux/) or the
[GitHub releases](https://github.com/termux/termux-app/releases). The Play Store
build is deprecated and cannot talk to the add-on apps.

Then install the two apps this project uses:

| App | Why |
| --- | --- |
| [Termux:API](https://f-droid.org/packages/com.termux.api/) | provides `termux-media-player` and `termux-wake-lock` |
| [Termux:Boot](https://f-droid.org/packages/com.termux.boot/) | optional, runs `~/.termux/boot/*` after boot |

Open Termux:Boot once after installing it, otherwise it will not run anything.

Packages inside Termux:

```sh
pkg update
pkg install termux-api coreutils util-linux
```

`install.sh` itself uses `install` from coreutils; `flock` comes from
util-linux; `timeout` and `dd` come from coreutils.

## 2. Install the command

### Release tarball (recommended)

```sh
ver=1.0.0
base="https://github.com/nexw/termux-keepalive/releases/download/v$ver"
curl -fLO "$base/termux-keepalive-$ver.tar.gz"
curl -fLO "$base/termux-keepalive-$ver.tar.gz.sha256"
sha256sum -c "termux-keepalive-$ver.tar.gz.sha256"
tar -xzf "termux-keepalive-$ver.tar.gz"
cd "termux-keepalive-$ver"
./install.sh
```

The tarball is built by the release workflow from the tagged commit, and the
`.sha256` file is generated in the same run.

### Source checkout

```sh
pkg install git
git clone https://github.com/nexw/termux-keepalive.git
cd termux-keepalive
./install.sh
```

### Options

```sh
./install.sh --dir "$HOME/.local/bin"   # custom destination
./install.sh --prefix "$HOME/.local"    # value/bin as destination
./install.sh --uninstall                # remove the installed command
```

The default destination is `$PREFIX/bin`, which is already on `PATH` in Termux.

### Without installing

```sh
git clone https://github.com/nexw/termux-keepalive.git
cd termux-keepalive
./bin/termux-keepalive start
```

State and logs still go to `~/.local/state/termux-keepalive`.

## 3. Start it

```sh
termux-keepalive start
termux-keepalive status
termux-keepalive logs -f
```

`start` returns once the worker is alive. If it fails, the message points at
the log; see [troubleshooting](troubleshooting.md).

## 4. Autostart (optional)

```sh
termux-keepalive install-boot
```

This writes `~/.termux/boot/10-keepalive.sh`, which runs
`termux-keepalive start`. It refuses to overwrite an existing file it does not
manage. Remove it with:

```sh
termux-keepalive uninstall-boot
```

Boot scripts run without a terminal. If Termux reports that its boot receiver
did not run, check that Termux:Boot is installed from the same source as
Termux, has been opened once, and is allowed to start at boot.

## 5. System settings that matter more than this script

These are user decisions, and no script can make them for you:

- Exempt Termux from battery optimisation (Android settings → Apps → Termux →
  Battery → Unrestricted).
- In OEM settings, allow Termux to auto-start and to keep running in the
  background when the screen is off.
- Do not use "force stop" on Termux; it kills the worker and the boot receiver
  may not fire until the app is opened again.

## Upgrading

Replace the installed command: unpack the new release and run `./install.sh`
again, or `git pull` and run `./install.sh`. The worker keeps running the old
code until you restart it:

```sh
termux-keepalive restart
```

The state directory survives upgrades. A generated audio file whose name does
not match the current version is simply ignored and a new one is created on the
next start.

## Uninstalling

```sh
termux-keepalive stop
termux-keepalive uninstall-boot
./install.sh --uninstall
rm -rf ~/.local/state/termux-keepalive
```

`stop` leaves the app wake lock alone, because other Termux services may use
it. If you want it released, close the other services first and then run
`termux-wake-unlock`.
