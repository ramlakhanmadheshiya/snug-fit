# Snug Fit: audio

All music and sound effects in `assets/audio/music/` and `assets/audio/sfx/` are
**original and fully synthesized** by `tools/synth_audio.py`. There are no
samples, recordings or third-party material. They are released with the
project under CC0-style terms (public domain dedication).

Format: 16-bit PCM WAV, mono, 44100 Hz. In the browser the music isn't in the
game's pack: `ship.sh` sends each track as Ogg Vorbis and `AudioManager` streams it.

## Regenerating

```sh
python3 -m venv .venv && .venv/bin/pip install numpy scipy
.venv/bin/python -I tools/synth_audio.py                 # everything (about 30 s)
.venv/bin/python -I tools/synth_audio.py --only place ch3  # a subset, by file stem
.venv/bin/python -I tools/synth_audio.py --check         # analyse existing files only
```

The script is deterministic (fixed seeds), so every rerun produces
bit-identical files. Each run prints an analysis table (duration, peak, RMS, DC
offset, clips), loop-seam metrics for the music, and an FFT pitch check for
`place.wav`.

## Music (`assets/audio/music/`)

Every track loops sample-exactly over the whole file: notes that ring past the
loop point are folded back onto the start, and reverb and delay are circular
convolutions, so the file is the steady state of an endless loop. Each file
carries a RIFF `smpl` loop over the whole file; `audio_manager.gd` also sets
forward looping at runtime.

Harmony: only chords from C major / A minor, so the pentatonic placement notes
always fit. Each chapter uses the arrangement whose mood suits it, with its own
melody seeds (`SEED_SHIFT`), so nothing is shared note for note with other games.

| File | Chapter | BPM | Mood |
|---|---|---|---|
| `menu.wav` | Home, chapters, shop | 72 | Kalimba over a slow Cmaj7 · Am7 · Fmaj7 · G6 pad |
| `ch1.wav` | Fit | 84 | Soft piano plucks and a light pad |
| `ch2.wav` | Turn | 90 | Glassy bell arpeggios with a dotted-eighth delay |
| `ch3.wav` | Paint | 76 | Airy pad, gentle marimba, clear melody |
| `ch4.wav` | Pegs | 78 | Warm, woody marimba ostinato, kalimba melody |
| `ch5.wav` | Spare | 88 | Electric-piano cycles, wide pad |
| `ch6.wav` | Flip | 96 | Pluck arpeggiator, soft kick and shaker |
| `ch7.wav` | Mosaic | 100 | Layered plucks and bells, the fullest track |

## Sound effects (`assets/audio/sfx/`)

| File | When | Notes |
|---|---|---|
| `place.wav` | A piece lands on the shape | Wooden bar at **C5 = 523.25 Hz** with a woody click and a body thump. Harmonic partials only, so it stays in tune when `AudioManager.play_note` climbs the C-major pentatonic ladder as the shape fills. |
| `pick.wav` | A piece is lifted | Small rising blip |
| `reject.wav` | A drop that doesn't fit | Two soft low bumps |
| `turn.wav` | A quarter turn | Crisp double click |
| `flip.wav` | A piece turns over | Quick airy swish with a tick |
| `back.wav` | A piece glides back to the tray | Soft falling tone |
| `win.wav` | The shape is filled | Rising bell arpeggio over a warm pad |
| `star.wav` | Each star on the result card | C6, re-pitched per star |
| `hint.wav` | A hint outline appears | Shimmering high cluster |
| `undo.wav` | The stars on offer drop | Reversed swell |
| `unlock.wav` | A purchase, key or chapter opens | Rising chime |
| `ui_tap.wav`, `ui_back.wav`, `ui_toggle.wav` | Buttons, back, switches | Short, quiet |
