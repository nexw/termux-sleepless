# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-11-17

First public release.

### Added

- `termux-keepalive` command with `start`, `stop`, `restart`, `status`,
  `logs`, `generate`, `install-boot`, `uninstall-boot`, `version` and `help`.
- Silent 65-second PCM WAV (`insomnia-65s.wav`) generated on device with
  `printf` and `dd`, replayed every 60 seconds so consecutive tracks overlap.
- `flock`-based single instance, PID validation against `/proc/<pid>/cmdline`,
  per-call API timeouts, bounded log rotation and a managed boot entry that
  refuses to overwrite unowned files.
- `install.sh` for installing and removing the command, with `--dir`,
  `--prefix` and `--uninstall`.
- ShellCheck/shfmt-clean sources and a device-independent test suite using fake
  Termux:API commands.
- GitHub Actions: CI on every push and pull request, and a release workflow
  that verifies the tag against `VERSION`, builds the tarball, publishes its
  SHA-256 checksum and attaches both to the GitHub release.
- English and Chinese READMEs, installation, design and troubleshooting docs,
  contribution guide, security policy and code of conduct.

### Changed

- The worker now logs only state changes instead of every playback cycle.
- The audio file name carries its duration, so a file from another version is
  never reused.
- `stop` only stops the shared Termux:API player when its current track is the
  generated WAV.

### Removed

- The `app_process` screen-state probing experiment and its build stubs.
- Archived notes about one specific device installation. Current documentation
  describes a clean install instead of a historical snapshot.
