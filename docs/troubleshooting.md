# Troubleshooting

Start with the log. It records worker start, wake-lock failures, playback
failures and exit reasons:

```sh
termux-keepalive logs
termux-keepalive logs -f
```

## `Missing commands: termux-media-player`

The Termux:API package and/or the Termux:API app are missing:

```sh
pkg install termux-api
```

and install the [Termux:API](https://f-droid.org/packages/com.termux.api/) app
from F-Droid or GitHub. Termux and its add-ons must come from compatible
signing sources; mixing the Play Store build with F-Droid add-ons does not
work.

## `Start failed; see ~/.local/state/termux-keepalive/keepalive.log`

The worker exited before it wrote its PID. Common causes:

- `flock` or `timeout` is missing → `pkg install util-linux coreutils`.
- The state directory is not writable.
- A stale worker still holds the lock but its PID file was removed. Check with
  `pgrep -af termux-keepalive`, stop the process, then start again.

## `status` says `Not running` but audio is still playing

The worker was killed without running its cleanup. Stop the orphan track:

```sh
termux-media-player stop
```

Then `termux-keepalive start` again. The worker only stops the player when the
current track is its own `insomnia-*.wav`, to avoid interrupting unrelated
playback.

## Playback fails every minute

- Termux:API app may have been force-stopped or have its permissions revoked.
- Another app may be holding audio focus in a way the player rejects.
- The generated file may have been deleted or truncated. Regenerate it:

```sh
rm -f ~/.local/state/termux-keepalive/insomnia-*.wav
termux-keepalive generate
```

The `generate` command prints the path and should exit 0. The file is about
1 MB; if it is much smaller, the device ran out of space while writing.

## The device still disconnects

This project makes Termux look busy; it does not grant a network exemption.
Check, in order:

1. Battery optimisation is disabled for Termux.
2. The OEM power manager allows Termux to run in the background and to
   autostart.
3. Doze is actually being entered (Android settings → Battery → Battery
   optimisation) and whether your OEM applies it to Termux regardless.
4. The app is not being killed for memory. Look for a new worker PID after the
   disconnect: `termux-keepalive status`, and compare with the log timestamps.

No script can guarantee a connection on every device. Test on your own hardware
before depending on it.

## Boot autostart does not run

- Termux:Boot must be installed, opened at least once, and allowed to start at
  boot.
- The boot entry must exist and be executable:
  `ls -l ~/.termux/boot/10-keepalive.sh`.
- Termux must not be "force stopped"; the boot receiver stays disabled until
  the app is opened manually.
- Some OEM systems delay or skip boot receivers until the device has been
  unlocked once.

## Battery drain

Expected. The wake lock, the audio path and Termux itself all cost power. If
the drain matters more than the connection, stop the worker and rely on the
system wake lock alone, or run the device on a charger.

`stop` does not release the app-wide wake lock; other Termux services may use
it. Release it explicitly with `termux-wake-unlock` only when you are sure
nothing else depends on it.

## The log keeps growing

Rotation happens on the next `start`, once the log is larger than 1 MiB:

```sh
termux-keepalive stop
termux-keepalive start
ls -l ~/.local/state/termux-keepalive/
```

## Resetting everything

```sh
termux-keepalive stop
rm -rf ~/.local/state/termux-keepalive
termux-keepalive start
```

This deletes the PID file, the lock, the log and the generated audio; the next
`start` recreates them.
