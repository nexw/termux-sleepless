# How it works, and what it cannot do

## The problem

Android does not guarantee background work. When the screen goes off, and even
more aggressively after the device enters Doze, the system may:

- suspend the CPU (ignoring ordinary wake locks once Doze is in effect),
- freeze background apps and their network sockets,
- let an OEM "battery manager" kill apps the stock system would keep.

Termux is an ordinary app from the system's point of view, so an SSH session,
bot or sync job can stop receiving packets while the device sleeps.

## What the worker does

`termux-keepalive start` launches a detached worker that:

1. takes the Termux app wake lock (`termux-wake-lock`),
2. generates a silent WAV once, if it is missing,
3. asks Termux:API to play that WAV (`termux-media-player play`),
4. waits 60 seconds and repeats.

Each cycle is one API call plus one `sleep`. A log line is written only on
worker start, wake-lock failure, playback failure and worker exit, so the log
stays quiet on a healthy device.

### The silent track

The file is `insomnia-65s.wav` in the state directory. It is a mono PCM WAV:
8000 Hz, 16-bit, one channel, 65 seconds, 1,040,044 bytes total.

The 44-byte RIFF header is written with Bash `printf`, the samples with
`dd if=/dev/zero`. In signed 16-bit PCM, zero is exactly digital silence, so the
file needs no encoder. The header fields are computed from the constants in the
script; the file name carries the duration, so a file from another version is
never picked up by accident.

### Why 65 seconds for a 60 second loop

Termux:API returns when playback *starts*, not when it ends. The worker cannot
know exactly when the track stops, and Android scheduling may delay the next
call. A track longer than the loop means the next playback starts while the
previous one is still running, instead of leaving a silent gap with no active
media session. The cost is that the track is restarted about five seconds
before it would have ended.

### Why not just a wake lock?

A wake lock keeps the CPU available, but a media session is what many devices
use as a signal that the app is doing foreground-ish work. Both mechanisms are
cheap to request and neither is authoritative. Some OEM builds react to one,
some to the other, and some to neither.

## What this project does *not* do

- **No Doze network exemption.** Android Doze can suspend network access even
  with a wake lock held. A real exemption has to be granted in system battery
  settings, per app, by the user.
- **No protection from the low-memory killer** or from OEM cleanup services.
  If the system decides to kill Termux, a script cannot prevent it.
- **No automation on screen state.** Reading display events from a plain
  Termux process requires unsupported tricks (loading a DEX with
  `app_process`); that approach was prototyped, did not reliably deliver
  screen broadcasts, and is deliberately not part of this project.
- **No root, no modifications outside `$HOME`** other than the optional boot
  entry and the command installed by `install.sh`.
- **No promise of stable connectivity.** Short tests passing does not mean a
  device will hold a connection overnight.

## Side effects you should know about

- **Battery.** The track is silent, not free: the audio path, the CPU wake lock
  and Termux itself all keep drawing power. Expect a measurable drain.
- **The media player is shared.** `termux-media-player` is a single Termux:API
  player. While the worker runs, it will replace whatever else you played with
  that API. `stop` only asks the player to stop when the current track is the
  generated WAV, and it never stops playback it does not recognise.
- **The wake lock is app-wide.** `termux-wake-lock` is a shared app state, not
  a per-process resource. Other services in Termux, including boot scripts, may
  rely on it, so `stop` deliberately does not release it. Run
  `termux-wake-unlock` only if you are sure nothing else needs it.
- **Log rotation is lazy.** The log is checked on `start`, not while the worker
  runs, so a long-running worker can exceed 1 MiB before rotation.

## Practical advice

- Grant Termux the system battery-optimisation exemption, and allow background
  activity and autostart in the OEM settings if they exist.
- Keep the device on a charger for overnight use, or accept the battery cost.
- Watch `termux-keepalive logs -f` after the screen is off for a while; a
  worker that stops logging playback failures is not proof that the network
  stayed up.
- Test your own device. Results vary by Android version, OEM and power state.

## References

- [Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby)
- [Audio focus](https://developer.android.com/media/optimize/audio-focus)
- [Termux:API `MediaPlayerAPI`](https://github.com/termux/termux-api/blob/master/app/src/main/java/com/termux/api/apis/MediaPlayerAPI.java)
- [Termux:API `WakeLockAPI`](https://github.com/termux/termux-api/blob/master/app/src/main/java/com/termux/api/apis/WakeLockAPI.java)
