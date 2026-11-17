# termux-sleepless

[![CI](https://github.com/nexw/termux-sleepless/actions/workflows/ci.yml/badge.svg)](https://github.com/nexw/termux-sleepless/actions/workflows/ci.yml)
[![Release](https://github.com/nexw/termux-sleepless/actions/workflows/release.yml/badge.svg)](https://github.com/nexw/termux-sleepless/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Termux is great until the screen goes off. Android then suspends the CPU,
freezes background work and cuts network access, so SSH sessions, bots and
sync jobs die quietly.

**termux-sleepless** is one Bash script that holds a wake lock and keeps a
silent media session alive, which makes Termux far less likely to be put back
to sleep. The silent track is called `insomnia.wav`: 65 seconds of digital
silence.

> **Honest scope:** this is not a Doze exemption. It does not stop the system
> from killing Termux, and it cannot override vendor battery managers. It works
> by keeping the app visibly busy. Please read
> [docs/how-it-works.md](docs/how-it-works.md) before relying on it.

## Features

- One self-contained Bash script, no daemon framework and no runtime wrapper.
- `start` / `stop` / `restart` / `status` / `logs` / `generate`, plus
  `install-boot` / `uninstall-boot` for autostart.
- Single instance via `flock`; the liveness check matches the worker command
  line, so a recycled PID is never signalled.
- Silent WAV written with `printf` + `dd`, no encoder.
- Optional boot entry that refuses to overwrite files it does not own.
- ShellCheck- and shfmt-clean, tested on every push and release.

## Requirements

- Termux installed from [F-Droid](https://f-droid.org/packages/com.termux/) or
  the [GitHub releases](https://github.com/termux/termux-app/releases) — the
  Play Store build is deprecated and cannot use the add-ons.
- `termux-api`, `coreutils` and `util-linux` packages
  (`pkg install termux-api coreutils util-linux`).
- The [Termux:API](https://f-droid.org/packages/com.termux.api/) app installed.
- `curl` for the one-line installer (`pkg install curl`).
- Optional: [Termux:Boot](https://f-droid.org/packages/com.termux.boot/) for
  autostart, opened once after installation.

## Install

### One-line install

```sh
# latest release
curl -fsSL https://raw.githubusercontent.com/nexw/termux-sleepless/refs/heads/main/install.sh | bash

# pin a release
curl -fsSL https://raw.githubusercontent.com/nexw/termux-sleepless/refs/heads/main/install.sh |
    bash -s -- --release v1.0.0
```

## Usage

```sh
termux-sleepless start      # start the background worker
termux-sleepless status     # exit 0 when running, 1 when not
termux-sleepless logs -f    # follow the log
termux-sleepless stop       # stop the worker
```

| Command | Description |
| --- | --- |
| `start` | Start the worker (default command). Idempotent. |
| `stop` | Stop the worker and the silent track it started. |
| `restart` | `stop` then `start`. |
| `status` | Print the state; exit code 0 only while running. |
| `logs [-f]` | Print the last 100 lines, or follow with `-f`. |
| `generate` | Write the silent WAV and print its path. |
| `install-boot` | Install `~/.termux/boot/10-sleepless.sh`. |
| `uninstall-boot` | Remove that boot entry. |
| `version` | Print the version. |
| `help` | Print usage. |

State, log and the generated audio live in
`~/.local/state/termux-sleepless/` (override with `TERMUX_SLEEPLESS_STATE_DIR`).
The log is rotated to `sleepless.log.1` on the next `start` once it exceeds
1 MiB.

### Autostart at boot

```sh
termux-sleepless install-boot
```

Termux:Boot must be installed and opened once, and Termux must be allowed to
start at boot by the system. The boot entry only starts the background worker.

### Uninstall

```sh
termux-sleepless stop
termux-sleepless uninstall-boot
curl -fsSL https://raw.githubusercontent.com/nexw/termux-sleepless/refs/heads/main/install.sh |
    bash -s -- --uninstall
rm -rf ~/.local/state/termux-sleepless
```

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `TERMUX_SLEEPLESS_STATE_DIR` | `$XDG_STATE_HOME/termux-sleepless` or `~/.local/state/termux-sleepless` | PID, lock, log and audio files. |
| `TERMUX_SLEEPLESS_BOOT_FILE` | `~/.termux/boot/10-sleepless.sh` | Path written by `install-boot`. |

## License

[MIT](LICENSE)
