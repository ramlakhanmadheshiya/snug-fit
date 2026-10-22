# Snug Fit

*A calm shape puzzle.* Each level is a shape (a cat, a rocket, a teacup). Drag the pieces from the tray into it until every cell is filled, snugly.

Made with Godot 4.7.2 (GDScript, Compatibility renderer, so it also runs on the web). Portrait-first; touch and mouse. Published by Brainnova Studio.

**Play / download:** https://theramlakhan.com/BrainnovaStudio/games/snug-fit/ (Android APK, and play in the browser once the game is in testing).
**Made by:** [Ramlakhan Madheshiya](https://theramlakhan.com), with Claude as AI co-developer.

Snug Fit grew out of the earlier *Corral* (game_3), keeping its blocks and rethinking the rest.

## The game

- **Fill the shape.** Drag a piece onto the shape; a ghost shows where it lands (red if it can't). Fill every cell: no overlaps, nothing outside. Drag a piece off the shape to take it back.
- **210 levels in 7 chapters of 30.** Each chapter has its own colours, music and animated chapter tile, and adds one idea:

  | # | Chapter | New idea |
  |---|---|---|
  | 1 | Fit | Fill the shape. Pieces keep their angle. |
  | 2 | Turn | Tap a piece to turn it (free in the tray, a move on the shape). |
  | 3 | Paint | A coloured cell only takes the piece of its colour. |
  | 4 | Pegs | Every piece covers exactly one peg. |
  | 5 | Spare | One piece too many: it stays in the tray. |
  | 6 | Flip | Touch a piece, then Flip turns it over. |
  | 7 | Mosaic | Everything at once, a different pair of ideas each level. |

  Level 1 of each chapter (from Turn on) opens with a card that shows the idea live, then outlines where the first piece goes. From level 16, Paint, Pegs and Spare pieces can be turned too.
- **Stars by moves.** Every drop on the shape is a move; par is one move per piece. ★★★ within par plus a little, ★★ a few more, ★ any finish; a hint caps the level at ★★. The MOVES and STARS chips show what's still on offer. Restart is a fresh start.
- **Every level is fair.** Each one is built from its answer and checked by a solver: at most three answers allowing for the shape's own symmetry, usually one late in a chapter. See *How the levels are made*.
- **Progress:** levels open one at a time; 12 clears open the next chapter. A level key opens any locked level; a chapter key any locked chapter.
- **Coins and hints** (game_2's model): start with 150 coins; +5 for a first clear, +5 per new star, +100 per finished chapter. A hint outlines where the next piece goes (taking any wrong pieces back first). The first hint each day is free (3 for Supporters), then 30 coins. Out of coins, a video pays for it; if no video can be shown, the hint is free.
- **Shop** (one-time packs plus consumables, all via Google Play):

  | Product | What it gives |
  |---|---|
  | Complete pack | Everything below, plus 1,000 coins and 5 level keys |
  | Supporter pack | No ads, 3 free hints a day |
  | Theme pack | 11 colour themes for the whole game (1-hour trial from a video) |
  | Block styles | 6 looks for every piece: Candy, Paper, Glass, Neon, Stone, Pixel (1-hour trial from a video) |
  | Coin bags | 300 / 1,000 / 2,500 / 6,000 coins; plus 25 free coins from a video (5 a day) |
  | Chapter keys | 1–5; each opens a locked chapter; plus one free from a video a day |
  | Level keys | 1–10, 10% off for 5+; plus a free key from a video (5 a day) |
  | Tip jar | Say thanks; unlocks nothing |

  Product ids: `python3 store/play_products.py list` (also `store/products.csv`); Play Console setup in [`store/PLAY_CONSOLE.md`](store/PLAY_CONSOLE.md). Debug desktop builds simulate purchases.
- **Ads (Android):** a banner with its space reserved; rewarded videos only when the player asks; one video after every 5 finished levels, on tapping Next, never mid-level. Supporters see none. In the browser, the Brainnova Studio play page decides (see the web kit below).
- **Appearance:** Settings → Appearance: Auto (follows the phone's dark mode), Dark or Light. Theme-pack themes keep their own colours.
- **Settings:** Music and Sound, Vibration, Lift pieces above finger, Appearance, colour theme and block style pickers, How to play, Shop, About, Credits, Ad privacy (when required), Reset progress (tap twice; hidden in a level; keeps packs, keys and bought coins).
- **Sharing:** after a level, Share makes a 1080×1350 picture of the filled shape with the stars, the link and a QR code; Save puts it in Pictures › Snug Fit. Android uses a small plugin (`plugins_src/snugfit_share`, built by CI).
- **Saving:** local JSON with atomic writes and a backup.

### Controls

| Input | Action |
|---|---|
| Drag a piece (touch or mouse) | Move it onto the shape, or off it |
| Tap a piece | Turn it (Turn chapters and later) |
| T / F | Turn / flip the selected piece |
| H | Hint |
| R | Restart |
| Esc / Android Back | Back |

## Run

```sh
./play.sh            # launches the game window directly (no editor)
```

## Check

```sh
./tests/run_all.sh   # rules and solver, all 210 levels, end-to-end UI flow, boot smoke
godot --fixed-fps 60 --disable-vsync --always-on-top --path . res://tests/capture.tscn -- /tmp/snug_shots           # screenshots of every screen
godot --fixed-fps 60 --disable-vsync --always-on-top --path . res://tests/capture.tscn -- store/screenshots --store  # Play Store set
```

| Suite | What it checks |
|---|---|
| `tests/sim_smoke.gd` | Orientations, turning and flipping from every angle, every refusal (outside, overlap, colour, peg), the solver (counts, identical pieces, spare pieces, fixed and wrong pieces, the node limit), stars, coin rewards. |
| `tests/levels_test.gd` | All 210 levels: well-formed, connected shapes and pieces, pieces cover the shape exactly, the stored answer replays legally and fills the shape, the solver finishes with at most 3 answers (allowing for symmetry), each chapter uses its idea, pieces never drop as a chapter goes on. |
| `tests/ui_flow.gd` | The real app headless: home, the tutorial, a real drag on and off the shape, refusals, solving, the result card and coins, Next, turning and flipping, hints (free, coins, out of coins), Restart, level and chapter keys, the shop and a simulated coin purchase and Complete pack, appearance, pickers, About. |

## How it works

| Piece | File |
|---|---|
| The rules and the solver, shared by the board, hints, generator and tests | `game/core/fit_sim.gd` |
| Coins, prices and allowances | `game/core/economy.gd` |
| Board: shape, tray, dragging, turning, flipping, hints, demo mode and the juice | `game/board/board.gd` |
| Piece looks (the Block styles pack) | `game/ui/block_styles.gd` |
| App shell, screens, design system and palettes | `game/ui/` |
| Save data, levels and unlocks, audio, store, ads, web platform | `game/autoload/`, `game/ads/` |
| Level generator and shape library | `tools/level_lab.gd`, `tools/shapes.gd` |
| Icons, feature graphic | `tools/make_icons.py`, `tools/render_icons.gd`, `tools/render_feature_graphic.tscn` |
| Audio synthesiser | `tools/synth_audio.py` (see `docs/AUDIO.md`) |

**How the levels are made** (details in [`docs/GDD.md`](docs/GDD.md)): pick a hand-drawn silhouette of the right size (80 named shapes, mirrored at random, never twice in a chapter); cut it into pieces of 2–6 cells, growing each from the most hemmed-in cell left; add the chapter's rule (start orientations, coloured cells chosen greedily to rule out other answers, one peg per piece, or a spare piece of the most common size); let the solver count every answer and keep only levels with very few; then keep the harder candidates for later slots and order the chapter by pieces and effort.

```sh
godot --headless --path . -s res://tools/level_lab.gd            # all chapters (about 4 minutes)
godot --headless --path . -s res://tools/level_lab.gd -- ch3     # one chapter
```

## Build & publish

Every push to `main` runs `.github/workflows/build.yml`: tests, a signed Android APK and AAB, the web build on the shared slim Brainnova engine, then `ship.sh` sends them to Brainnova Studio (`theramlakhan.com/BrainnovaStudio/games/snug-fit/`). Signing uses the repo secrets `ANDROID_KEYSTORE_*` (`./game-keys.sh setup game_3/snug-fit` in the Games folder); the studio deploy key is `STUDIO_DEPLOY_KEY`.

## Credits

| Asset | Source | Licence |
|---|---|---|
| Font: [Nunito](https://github.com/googlefonts/nunito) | Google Fonts | SIL OFL 1.1, `assets/fonts/OFL.txt` |
| Symbol and currency fallbacks: Noto Sans subsets | Google Fonts | SIL OFL 1.1, `assets/fonts/OFL-Noto.txt` |
| Icons: [Lucide](https://lucide.dev) | lucide-static 0.460.0 | ISC, `assets/icons/LICENSE.txt` |
| Music and sound effects | Made for Snug Fit by `tools/synth_audio.py`, no samples | Released with the project |
| QR code on the share card | Generated with [segno](https://github.com/heuer/segno) | Generated output |

The game-dev agent skills used while building this are in `.claude/skills/`. They come from [GodotPrompter](https://github.com/jame581/GodotPrompter) (MIT), [awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) (Apache-2.0) and [godot-skills](https://github.com/vl4dt/godot-skills) (MIT).
