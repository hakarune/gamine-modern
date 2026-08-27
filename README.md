# Gamine (modern)

A single-file HTML5 Canvas re-implementation of **[Gamine][sf]**, the drawing
game for very young children — the one where a two-year-old who can't use a
mouse or keyboard yet just *moves* the pointer and colour appears.

Move the pointer (or drag a finger) to draw bright lines. Click or tap to
stamp a colourful star. Press any letter key to stamp that letter. Every
action makes a friendly sound. That's the whole game.

The original is a GTK 3 / Cairo / GStreamer program by Emmanuel Garette. This
port keeps its behaviour but needs nothing but a browser — no install, no
toolchain, one `index.html`.

[sf]: https://sourceforge.net/projects/gamine-game

## Play

- **Online:** open the GitHub Pages deployment (enable Pages → "GitHub Actions"
  in the repo settings; the `pages` workflow publishes `index.html`).
- **Locally:** just open `index.html` in any modern browser. Or serve it:

  ```sh
  npm start          # -> http://localhost:8080  (uses `npx serve`)
  ```

- **As a desktop app (Debian/Ubuntu):** see [Packaging](#packaging-a-deb).

Press **Tap to play** first — browsers require one gesture before audio and
fullscreen are allowed.

## Controls

| Input | Action | Original `gamine.c` |
| --- | --- | --- |
| Move pointer / drag | Draw a coloured line | `draw_line` on `motion_notify_event` |
| Click / tap | Stamp a random star (2–7 spikes) | `draw_star` on `button_press_event` |
| Any letter/number key | Stamp that character | `draw_string` / `key_press` |
| `space` | Clear the screen | `GDK_KEY_space` |
| `s` or `PrintScreen` | Save the drawing as a PNG | `save_picture` |
| `f` | Toggle fullscreen | (window was fullscreen, no WM) |
| `m` | Toggle the ambient music | `background_music` playbin loop |
| `esc` | Leave fullscreen | `gtk_main_quit` |

On a **touchscreen** (no physical keyboard) a small control cluster sits in
the top-right corner — 🎵 music, ⌨️ keyboard, 💾 save, 🖥️ fullscreen. The ⌨️
button focuses a hidden text field so the on-screen keyboard pops up; letters
typed there are stamped (and advance across the screen like a typewriter).
The cluster dims after a few seconds and returns on the next tap.

## What was ported from the C source

The three pieces of logic the task called for, lifted straight out of
`gamine.c` (see the comments in `index.html` that name each original function):

### Shape stamping — `build_star()` / `draw_star()`

On every click a filled polygon is drawn with `random() % 6 + 2` spikes
(2–7), alternating between an **inner radius** (`object_weight`, 15) and a
hard-coded **outer radius** of 20, with vertices at `i·π / spike_count`. The
port reproduces the loop vertex-for-vertex, scaled up for large / hi-DPI
screens.

### Colour cycling — `get_cairo_context()`

Two distinct palettes, exactly as in the original:

- **Lines** get a *pastel* colour — each channel
  `((rand()%128 + 127) / 255 + 1) / 2`, i.e. `0.75–1.0`. It is regenerated
  **only** once more than `timer_color_change` has elapsed, so a stroke keeps
  one colour for a while instead of shimmering.
- **Stamps and letters** get a *dark* colour — each channel
  `random()%10 · 0.1`, i.e. `0.0–0.9` — freshly rolled on every stamp.

### Pointer & keyboard logic — `draw_line()` / `key_press()`

Round-capped segments are drawn from the previous point to the current one;
a `-1` sentinel seeds the first point so no line jumps in from nowhere
(`event->x + 1` quirk included). Key repeats are suppressed the way the
original tracked `lastkeyval`.

### Sound — Web Audio instead of samples

The original picks a random `.wav`/`.ogg` from a fixed table on every stamp
and loops a Brandenburg Concerto in the background. This port has **no audio
files**: a small `Synth` class synthesises four playful voices (blip, chime,
swoop, filtered-noise hit) on a C-major-pentatonic scale, a soft tick on each
line-colour change, and an optional ambient pad for the background music.

## Configuration

`index.html` has a `CONFIG` object near the top that mirrors the original
`/etc/gamine.conf`:

| `CONFIG` key | `gamine.conf` key | Meaning |
| --- | --- | --- |
| `lineWidth` | `line_width` | line stroke width |
| `objectWeight` | `object_weight` | star inner radius / text anchor |
| `outerRadius` | *(hard-coded 20)* | star outer radius |
| `fontWeight` | `font_weight` | stamped character size (px) |
| `colorChangeMs` | `timer_color_change` | min time between line colours |
| `music` | `background_music` | start the ambient pad on launch |

## Packaging a `.deb`

`build-deb.sh` produces a Debian package that installs the app plus a
launcher which opens it fullscreen in the best available browser
(Chromium/Chrome kiosk, then Firefox kiosk, then `xdg-open`).

```sh
./build-deb.sh            # -> dist/gamine-modern_2.0.0_all.deb
sudo apt install ./dist/gamine-modern_2.0.0_all.deb
gamine-modern             # or launch "Gamine" from the app menu
```

The script uses `dpkg-deb` when available and falls back to `ar` + `tar`
so it also runs on non-Debian CI. `gamine-modern.desktop.in` is the desktop
launcher template (`@BINDIR@` is substituted at build time).

Installed layout:

```
/usr/share/gamine-modern/index.html
/usr/bin/gamine-modern                       # launcher script
/usr/share/applications/gamine-modern.desktop
/usr/share/icons/hicolor/scalable/apps/gamine-modern.svg
/usr/share/doc/gamine-modern/{copyright,changelog.Debian.gz}
```

## Project layout

```
index.html                  the entire game (canvas + Web Audio synth)
gamine-modern.svg           app icon
gamine-modern.desktop.in    desktop launcher template
build-deb.sh                .deb builder
package.json                dev scripts (serve / validate / build:deb)
.github/workflows/          CI, Pages deploy, tagged release
```

## Development

No build step. Edit `index.html`, reload. Optional checks:

```sh
npm run validate     # html-validate via npx
shellcheck build-deb.sh
```

## Credits & license

- Original game © 2007–2019 Emmanuel Garette and the Gamine authors — see
  [`AUTHORS.md`](AUTHORS.md).
- This port is likewise **GPL-3.0-or-later** — see [`LICENSE`](LICENSE).
- The original's bundled sounds and `pencil.png` are **not** redistributed
  here; all audio is synthesised and the cursor/icon are original SVGs.
