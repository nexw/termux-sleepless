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

### One-line install (recommended)

```sh
curl -fsSL https://raw.githubusercontent.com/nexw/termux-sleepless/refs/heads/main/install.sh | bash
```

That command downloads and runs `install.sh` from the `main` branch. The script
has no checkout next to it, so it:

1. asks the GitHub API for the latest release tag,
2. downloads `termux-sleepless-<version>.tar.gz` and its `.sha256` asset,
3. verifies the checksum and aborts on a mismatch,
4. installs `bin/termux-sleepless` to `$PREFIX/bin`.

Install a specific release instead of the latest one:

```sh
curl -fsSL https://raw.githubusercontent.com/nexw/termux-sleepless/refs/heads/main/install.sh |
    bash -s -- --release v1.0.0
```

Options go after `bash -s --`. For example, install into `~/.local/bin`:

```sh
curl -fsSL https://raw.githubusercontent.com/nexw/termux-sleepless/refs/heads/main/install.sh |
    bash -s -- --dir "$HOME/.local/bin"
```

The one-liner trusts the `main` branch for the installer itself, while the
command it installs always comes from a tagged release. If you prefer to read
the script first, use one of the manual methods below or fetch it to a file:

```sh
curl -fsSL -o install.sh https://raw.githubusercontent.com/nexw/termux-sleepless/refs/heads/main/install.sh
less install.sh
bash install.sh
```

`TERMUX_SLEEPLESS_REPO=owner/name` points the installer at a fork or mirror.

### Manual release download

```sh
ver=1.0.0
base="https://github.com/nexw/termux-sleepless/releases/download/v$ver"
curl -fLO "$base/termux-sleepless-$ver.tar.gz"
curl -fLO "$base/termux-sleepless-$ver.tar.gz.sha256"
sha256sum -c "termux-sleepless-$ver.tar.gz.sha256"
tar -xzf "termux-sleepless-$ver.tar.gz"
cd "termux-sleepless-$ver"
./install.sh
```

The tarball is built by the release workflow from the tagged commit, and the
`.sha256` file is generated in the same run.

### Source checkout

```sh
pkg install git
git clone https://github.com/nexw/termux-sleepless.git
cd termux-sleepless
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
git clone https://github.com/nexw/termux-sleepless.git
cd termux-sleepless
./bin/termux-sleepless start
```

State and logs still go to `~/.local/state/termux-sleepless`.

## 3. Start it

```sh
termux-sleepless start
termux-sleepless status
termux-sleepless logs -f
```

`start` returns once the worker is alive. If it fails, the message points at
the log; see [troubleshooting](troubleshooting.md).

## 4. Autostart (optional)

```sh
termux-sleepless install-boot
```

This writes `~/.termux/boot/10-sleepless.sh`, which runs
`termux-sleepless start`. It refuses to overwrite an existing file it does not
manage. Remove it with:

```sh
termux-sleepless uninstall-boot
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
termux-sleepless restart
```

The state directory survives upgrades. A generated audio file whose name does
not match the current version is simply ignored and a new one is created on the
next start.

## Uninstalling

```sh
termux-sleepless stop
termux-sleepless uninstall-boot
./install.sh --uninstall
rm -rf ~/.local/state/termux-sleepless
```

`stop` leaves the app wake lock alone, because other Termux services may use
it. If you want it released, close the other services first and then run
`termux-wake-unlock`.
