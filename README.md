# Omarchy Notch

A Mac-style notch for the Omarchy desktop. It attaches beneath the centered
clock, expands on hover, and uses real frosted glass that follows your wallpaper.

## Features

- **Now playing:** artwork, track information, progress, and playback controls through MPRIS.
- **Live audio spectrum:** 32 Cava bands driven by your output audio, with smooth transitions.
- **Activities:** screen recording with elapsed time and stop/save, dictation, reminders, stay-awake, and Do Not Disturb.
- **Persistent status:** active recording and other ongoing activity remain visible when collapsed.
- **Notifications:** compact cards that resize around their text and support the notification's default action.
- **Calendar:** month navigation, today, week number, and year progress.
- **Live video preview:** mirrors a dedicated browser picture-in-picture window into the music pane.
- **Desktop integration:** the clock still opens the notch; nearby bar buttons remain clickable.

## Requirements

This is an **Omarchy shell plugin**, not a standalone Quickshell configuration.
It uses Omarchy's `qs.Commons` module, shell APIs, and desktop commands.

- A recent Omarchy installation using the Quickshell shell and Lua Hyprland configuration.
- A horizontal top bar with the clock centered.
- Python 3, Bash, `jq`, and ImageMagick (`magick`).
- Cava for the audio spectrum, using the PulseAudio compatibility server normally provided by PipeWire.
- An MPRIS-compatible player for media controls.
- Optional: Voxtype for dictation, a browser PiP window and Hyprland toplevel capture for live video.

Developed against the installed Omarchy APIs in October 2026. Other shell versions
may need adjustments. Dimensions and timing are near the top of `Notch.qml`.

## Repository layout

This repository contains one plugin. `manifest.json`, its QML entry point, and
runtime helpers live at the repository root, as required by the Omarchy plugin
marketplace. `install.py` is an optional manual installer; `hypr/` contains the
optional glass rules and `tests/` contains development checks.

## Install

```sh
git clone https://github.com/markerspoint/omarchy-notch.git
cd omarchy-notch
python install.py --glass
hyprctl reload
hyprctl configerrors
omarchy restart shell
```

The installer copies the plugin to `~/.config/omarchy/plugins/mark.notch`,
adds it to the existing `shell.json`, and preserves other plugins and settings.
Backups go under `~/.config/omarchy/backups/notch-<timestamp>/`.

`--glass` also installs `~/.config/hypr/notch.lua` and loads it from
`~/.config/hypr/looknfeel.lua`. It enables blur and puts the bar and notch on the
same wallpaper blur path to avoid a visible seam. If you manage Hyprland rules
yourself, omit `--glass` and use [hypr/notch.lua](hypr/notch.lua) as a reference.
The installer does not restart the desktop or install packages automatically.

For the transparent look, enable `bar.transparent` in Omarchy's `shell.json`.
Without transparency, the notch follows the bar's configured surface color.

## Use

Hover below the clock to peek. Click the clock or notch to pin it, and click
outside or on the clock again to close. Right-clicking the clock still cycles
its format; middle-clicking opens the timezone menu.

Open **Activities** for desktop controls. Recording or dictation starting will
peek at that view, and ongoing activities stay visible in the collapsed notch.
Starting or resuming playback, changing tracks, or switching the active player
automatically selects **Now playing**, even if Activities or Calendar was last
open. Manually choosing another tab stays in effect until the next playback
event. Audio analysis and video capture stop when their view is hidden.

For live YouTube video, first enable the browser's **Picture in picture** mode.
The notch mirrors that dedicated window, retaining the browser's audio and
playback controls. It does not extract video from background tabs. When no
matching PiP window exists—or more than one matches—it uses artwork instead.
The browser's PiP window remains available separately.

```sh
omarchy-shell mark.notch music
omarchy-shell mark.notch calendar
omarchy-shell mark.notch activities
omarchy-shell mark.notch show
omarchy-shell mark.notch hide
omarchy-shell mark.notch toggle
omarchy-shell mark.notch debug
```

## Notes

- Audio visualization monitors the default **output**, not the microphone. It can reflect other system audio too.
- Notification takeover dismisses the native toast after displaying it in the notch. Change `takeOverNativeToasts` to retain native toasts.
- Notification cards support up to two title lines and six body lines, with a maximum width of 520 pixels.
- PiP recognition currently expects an English “Picture-in-Picture” window title.
- Recorder detection follows Omarchy's `gpu-screen-recorder` process.
- This project contains no desktop screenshots, private wallpaper files, or personal system configuration.

## Remove

Remove `mark.notch` from the `plugins` array in `~/.config/omarchy/shell.json`,
then remove `~/.config/omarchy/plugins/mark.notch/` and restart the shell.
If installed with `--glass`, remove the marked `require("hypr.notch")` block
from `looknfeel.lua` and remove `~/.config/hypr/notch.lua`. Reload Hyprland and
check `hyprctl configerrors`. Backups can be used to restore previous settings.

## Development

```sh
python -m unittest discover -s tests -v
bash -n watch-navbar.sh
bash -n watch-notifications.sh
```

The recording-state tests use a temporary `/proc` fixture and never start or stop
recording. Installer tests use temporary configuration directories.

Built for [Omarchy](https://omarchy.org/), using [Quickshell](https://quickshell.org/)
and [Cava](https://github.com/karlstav/cava).

## License

[MIT](LICENSE) — Copyright (c) 2026 markerspoint.
