# Contributing

Thanks for taking the time to help. This project is small on purpose: one Bash
script, one installer, a test suite and documentation. Keep changes in that
spirit.

## Before you start

- Bug reports and feature requests: use the issue templates.
- Security issues: see [SECURITY.md](SECURITY.md). Do not open a public issue.
- For anything larger than a typo, open an issue first so we can agree on the
  scope.

## Development environment

- Termux on Android, or any Linux with `bash`, `coreutils`, `util-linux`,
  `shellcheck` and `shfmt` for tests and linting.
- `make` is convenient but not required; every target is a one-liner.

```sh
git clone https://github.com/nexw/termux-sleepless.git
cd termux-sleepless
make check                 # shellcheck + shfmt + tests
bash tests/run-tests.sh    # tests only
```

The test suite replaces `termux-media-player` and `termux-wake-lock` with fakes
and uses a temporary `HOME`/`PREFIX`, so it does not touch a real device's
audio, wake lock or boot entries. It must pass both on Linux and in Termux.

## Style

- Bash, no additions beyond what Termux ships. New runtime dependencies need a
  good reason and a line in the docs.
- `shellcheck -x` and `shfmt -i 4 -ci` must be clean. Both run in CI.
- Quote expansions, keep functions small, and prefer explicit error messages
  with a next step over silent failure.
- Do not claim more than the code does. Doze exemptions, kill protection and
  OEM battery managers are out of scope; documentation must say so.
- No root, no writes outside `$HOME`, `$PREFIX/bin` and the state directory.

## Commits and pull requests

- One logical change per commit, imperative subject line, body explains *why*.
- Update `CHANGELOG.md` under `## [Unreleased]` for user-visible changes.
- Update docs when behaviour or limitations change.
- PR checklist:
  - [ ] `make check` passes
  - [ ] tests cover the change where practical
  - [ ] docs and `CHANGELOG.md` updated
  - [ ] no secrets, tokens, device identifiers or personal paths

## Release process

1. Bump `VERSION` in `bin/termux-sleepless` (single source of truth).
2. Move the `Unreleased` entries into a new `CHANGELOG.md` section dated today.
3. Commit, then create and push an annotated tag:

   ```sh
   git tag -a v1.2.3 -m 'termux-sleepless 1.2.3'
   git push origin main v1.2.3
   ```

4. The release workflow runs the linters and tests, checks that the tag matches
   `VERSION`, builds `dist/termux-sleepless-1.2.3.tar.gz`, writes its
   `.sha256`, and publishes a GitHub release with generated notes.

The tarball is built from the tagged commit by CI; do not attach locally built
archives to a release.
