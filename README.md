# termux-keepalive

[![CI](https://github.com/nexw/termux-keepalive/actions/workflows/ci.yml/badge.svg)](https://github.com/nexw/termux-keepalive/actions/workflows/ci.yml)
[![Release](https://github.com/nexw/termux-keepalive/actions/workflows/release.yml/badge.svg)](https://github.com/nexw/termux-keepalive/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Termux is great until the screen goes off. Android then suspends the CPU,
freezes background work and cuts network access, so SSH sessions, bots and
sync jobs die quietly.

**termux-keepalive** is one Bash script that holds a wake lock and keeps a
silent media session alive, which makes Termux far less likely to be put back
to sleep. The silent track is called `insomnia-65s.wav`: 65 seconds of digital
silence, generated on device without ffmpeg, Python or any extra package.

> **Honest scope:** this is not a Doze exemption. It does not stop the system
> from killing Termux, and it cannot override vendor battery managers. It works
> by keeping the app visibly busy. Please read
> [docs/how-it-works.md](docs/how-it-works.md) before relying on it.

中文说明：[README.zh-CN.md](README.zh-CN.md)

## Features

- One self-contained Bash script, no daemon framework and no runtime wrapper.
- `start` / `stop` / `restart` / `status` / `logs` / `generate`, plus
  `install-boot` / `uninstall-boot` for autostart.
- Single instance via `flock`; the liveness check matches the worker command
  line, so a recycled PID is never signalled.
- Own state directory, bounded log rotation and API timeouts on every call.
- Silent WAV written with `printf` + `dd`: no encoder, no ~1 MB dependency
  chain, and no audio files checked into git.
- Optional boot entry that refuses to overwrite files it does not own.
- ShellCheck- and shfmt-clean, tested on every push and release.

## Requirements

- Termux installed from [F-Droid](https://f-droid.org/packages/com.termux/) or
  the [GitHub releases](https://github.com/termux/termux-app/releases) — the
  Play Store build is deprecated and cannot use the add-ons.
- `termux-api`, `coreutils` and `util-linux` packages
  (`pkg install termux-api coreutils util-linux`).
- The [Termux:API](https://f-droid.org/packages/com.termux.api/) app installed.
- Optional: [Termux:Boot](https://f-droid.org/packages/com.termux.boot/) for
  autostart, opened once after installation.

## Install

### From a release tarball

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

### From source

```sh
pkg install git
git clone https://github.com/nexw/termux-keepalive.git
cd termux-keepalive
./install.sh
```

`install.sh` copies the command to `$PREFIX/bin/termux-keepalive` (already in
`PATH`) and prints the next steps. Use `./install.sh --dir ~/.local/bin` for a
different location, or `./install.sh --uninstall` to remove the command.

You can also run the script without installing it:

```sh
./bin/termux-keepalive start
```

## Usage

```sh
termux-keepalive start      # start the background worker
termux-keepalive status     # exit 0 when running, 1 when not
termux-keepalive logs -f    # follow the log
termux-keepalive stop       # stop the worker
```

| Command | Description |
| --- | --- |
| `start` | Start the worker (default command). Idempotent. |
| `stop` | Stop the worker and the silent track it started. |
| `restart` | `stop` then `start`. |
| `status` | Print the state; exit code 0 only while running. |
| `logs [-f]` | Print the last 100 lines, or follow with `-f`. |
| `generate` | Write the silent WAV and print its path. |
| `install-boot` | Install `~/.termux/boot/10-keepalive.sh`. |
| `uninstall-boot` | Remove that boot entry. |
| `version` | Print the version. |
| `help` | Print usage. |

State, log and the generated audio live in
`~/.local/state/termux-keepalive/` (override with `TERMUX_KEEPALIVE_STATE_DIR`).
The log is rotated to `keepalive.log.1` on the next `start` once it exceeds
1 MiB.

### Autostart at boot

```sh
termux-keepalive install-boot
```

Termux:Boot must be installed and opened once, and Termux must be allowed to
start at boot by the system. The boot entry only starts the background worker.

### Uninstall

```sh
termux-keepalive stop
termux-keepalive uninstall-boot
./install.sh --uninstall
rm -rf ~/.local/state/termux-keepalive
```

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `TERMUX_KEEPALIVE_STATE_DIR` | `$XDG_STATE_HOME/termux-keepalive` or `~/.local/state/termux-keepalive` | PID, lock, log and audio files. |
| `TERMUX_KEEPALIVE_BOOT_FILE` | `~/.termux/boot/10-keepalive.sh` | Path written by `install-boot`. |

## How it works, briefly

1. `termux-wake-lock` holds the shared Termux app wake lock.
2. A 65-second PCM WAV of exact silence is generated once, with a fixed
   44-byte header and zero samples.
3. The worker asks Termux:API to play it and repeats every 60 seconds, so the
   track overlaps itself instead of leaving a gap.

What that buys you is an app that never looks idle. What it does not buy you is
a network exemption, immunity from the low-memory killer, or protection from
OEM "battery optimisation". Details and caveats:
[docs/how-it-works.md](docs/how-it-works.md).

## Documentation

- [Installation](docs/installation.md)
- [How it works and what it cannot do](docs/how-it-works.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Changelog](CHANGELOG.md)

## Development

```sh
make check    # shellcheck + shfmt + tests
make test     # bash tests/run-tests.sh
make dist     # build dist/termux-keepalive-<version>.tar.gz + sha256
```

The test suite replaces Termux:API with fakes, so it runs on Linux CI as well
as on a device. See [CONTRIBUTING.md](CONTRIBUTING.md) for the release process.

## License

[MIT](LICENSE)
