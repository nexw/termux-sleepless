# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-11-17

First public release.

### Added

- `termux-sleepless` command with `start`, `stop`, `restart`, `status`,
  `logs`, `generate`, `install-boot`, `uninstall-boot`, `version` and `help`.
- Silent 65-second PCM WAV (`insomnia.wav`) generated on device with
  `printf` and `dd`, replayed every 60 seconds so consecutive tracks overlap.
  The track is rebuilt when its size does not match the configured duration.
- `flock`-based single instance, PID validation against `/proc/<pid>/cmdline`,
  per-call API timeouts, bounded log rotation and a managed boot entry that
  refuses to overwrite unowned files.
- `install.sh` for installing and removing the command, with `--dir`,
  `--prefix`, `--release` and `--uninstall`. It installs the local checkout
  when one is present, and otherwise downloads the latest (or a pinned) release
  tarball and verifies its SHA-256, which enables the one-line install:

  ```sh
  curl -fsSL https://raw.githubusercontent.com/nexw/termux-sleepless/refs/heads/main/install.sh | bash
  ```
- ShellCheck/shfmt-clean sources and a device-independent test suite using fake
  Termux:API commands.
- GitHub Actions: CI on every push and pull request, and a release workflow
  that verifies the tag against `VERSION`, builds the tarball, publishes its
  SHA-256 checksum and attaches both to the GitHub release.
- English and Chinese READMEs, installation, design and troubleshooting docs,
  contribution guide, security policy and code of conduct.

### Changed

- The worker now logs only state changes instead of every playback cycle.
- `insomnia.wav` is validated by size, so a truncated file or one written for
  a different duration is replaced instead of reused.
- `stop` only stops the shared Termux:API player when its current track is the
  generated WAV.

### Removed

- The `app_process` screen-state probing experiment and its build stubs.
- Archived notes about one specific device installation. Current documentation
  describes a clean install instead of a historical snapshot.
