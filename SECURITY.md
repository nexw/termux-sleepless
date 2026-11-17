# Security policy

## Supported versions

The latest minor release receives fixes. Older releases are not patched; upgrade
by unpacking the new release and running `./install.sh` again, then
`termux-sleepless restart`.

## Reporting a vulnerability

Please do not open a public issue for security problems. Use GitHub's private
vulnerability reporting on this repository (Security → Report a vulnerability),
or contact the maintainer [@nexw](https://github.com/nexw) privately.

Include:

- the version (`termux-sleepless version`),
- Termux and Android versions,
- what the script can do that it should not, and how to reproduce it.

You can expect an acknowledgement within a few days. Because this is a small
volunteer project, no bug bounty is available.

## Scope

This script runs with the normal Termux user ID and installs into `$PREFIX/bin`
and `~/.termux/boot`. Reports about the following are in scope:

- command injection or path handling issues in `bin/termux-sleepless` or
  `install.sh`,
- unsafe file overwrites, symlink attacks or permission mistakes,
- ways a local process could make the script run arbitrary code,
- checksum or release artifact integrity problems.

Out of scope:

- the Android system killing the Termux app, or OEM battery managers,
- the fact that a wake lock does not grant network access (documented),
- vulnerabilities in Termux, Termux:API, Termux:Boot or Android itself — report
  those to their respective projects.
