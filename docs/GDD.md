# Snug Fit: game design

## High concept
Snug Fit is a calm, portrait block puzzle. Each level is a shape (a cat, a
rocket, a teacup) and a tray of pieces. Drag the pieces in until every cell is
filled, snugly. No timers, no score chasing: just the click of a piece finding
its place.

## Market references
- **Tangram and "fill the shape" block puzzles** (Blocks: Tangram, Doodle Fit):
  the proven core of fitting given pieces into a silhouette.
- **Two Dots, Monument Valley, Single Shot:** calm palettes, one obvious action
  per screen, audio that is part of the reward, chapters that each teach one idea.

## Player promise
You look at a shape, see how it splits, and fill it in a handful of confident
moves while each piece lands with a rising note.

## Core loop
1. Read the shape and the pieces in the tray.
2. Drag a piece onto the shape. A ghost shows where it would land (red if it can't).
3. Pieces that fit snap in with a note that climbs as the shape fills; ones that
   don't glide back to the tray with a soft bump and a one-line reason.
4. Fill every cell. Stars by moves against par (one move per piece).
5. The result card shows the filled shape, the stars and the coins earned.

## Rules
| Rule | Detail |
|---|---|
| Moves | Every drop on the shape is a move (placing, moving, or turning a piece that's on it). Taking a piece back off is free, and so is turning it in the tray. |
| Stars | ★★★ within par + 1 (+1 per 6 pieces), ★★ within 2 × par + 2, ★ otherwise. A hint caps the level at ★★. Restart is a fresh start. |
| Turn | Tap a piece to turn it a quarter clockwise. On the shape it turns in place if it still fits, otherwise it goes back to the tray. |
| Flip | Touch a piece, then Flip mirrors it left-right. |
| Paint | A coloured cell only takes the piece of its colour. |
| Pegs | Every piece must cover exactly one peg. |
| Spare | The tray holds one piece too many; the shape fills without it. Its size matches the most common piece size, so counting cells won't give it away. |

## Progression
- **7 chapters × 30 levels = 210**, gentlest idea first: Fit, Turn, Paint, Pegs,
  Spare, Flip, Mosaic. Level 1 of each chapter (from Turn on) opens with a card
  that shows the new idea live, then outlines where the first piece goes.
- **Mixing in:** from level 16, Paint, Pegs and Spare pieces can be turned too
  (a tip says so the first time). Mosaic mixes a different pair of ideas each level.
- **Pieces climb** with the level: Fit goes from 2 to 8 pieces, Mosaic from 4 to 9.
  Shapes grow with them (6 to about 46 cells), and no shape repeats in a chapter.
- **Unlocks:** levels open one at a time; a chapter opens after 12 clears in the
  one before. A level key opens any locked level, a chapter key any locked chapter.

## How the levels are made
`tools/level_lab.gd` builds each slot from a hand-drawn silhouette library
(`tools/shapes.gd`, 80 named shapes, mirrored at random):
1. Pick a shape whose size fits the slot's piece count, unused in the chapter.
2. Cut it into pieces of 2 to 6 cells, always growing a piece from the most
   hemmed-in cell left, so no lonely pockets are stranded. No more than two
   copies of any piece.
3. Add the chapter's rule: random start orientations (Turn, Flip); paint colours
   and coloured cells, chosen greedily so each one rules out the most other
   answers (Paint); one peg per piece, the set that leaves the fewest answers
   (Pegs); or a spare piece (Spare).
4. The solver (`FitSim.solve`, exact cover that always fills the first empty
   cell, with identical pieces interchangeable and pocket pruning) counts every
   answer. A level is kept only if it has at most 3 answers (2 from level 9,
   1 from level 19, times the shape's own symmetry), and for Paint and Pegs only
   if the rule is what cuts the answers down.
5. Of ten good candidates per slot, later slots keep the ones that took the
   solver more work. Each chapter is then ordered by pieces and effort.

`tests/levels_test.gd` replays every stored answer under the rules and re-runs
the solver on all 210 levels.

## Feel
- **Pick up:** the piece grows from tray size to board size and floats above the
  finger (Settings: Lift pieces above finger) with a soft shadow; a ghost shows
  where it would land.
- **Place:** a pop of scale, a few block particles in the piece's colour, a
  wooden note that climbs a pentatonic ladder as the shape fills, and a haptic tick.
- **Refuse:** the piece glides home with a wiggle and two soft bumps; the strip
  over the shape says why.
- **Fill:** a wave of light runs across the shape from the last piece, a ring
  opens, a bell chime; the result card springs up with stars popping in.

## Presentation
- **Type:** Nunito (round and friendly), heavy weights for titles.
- **Shapes:** chunky "block" buttons, chips and cards with a soft lip under them,
  like the pieces themselves.
- **Colour:** each chapter is one palette; Settings → Appearance switches between
  Auto (follows the phone's dark mode), Dark and Light.
- **Levels screen:** a gallery of the chapter's shapes; cleared ones are shown
  filled in their colours.

## Monetisation (game_2's model)
All rules in `game/core/economy.gd`, `game/autoload/store.gd` and `game/ads/ad_manager.gd`.
- **Coins:** start with 150. +5 for a first clear, +5 per new star, +100 per chapter.
  A hint costs 30 coins; the first hint each day is free (3 for Supporters).
  Out of coins, a video pays for the hint (free if no video can be shown).
- **Shop:** Complete pack (everything, 1,000 coins and 5 level keys), Supporter
  pack (no ads, 3 free hints a day), Theme pack (11 themes), Block styles (6
  looks), coin bags (300 to 6,000), chapter keys (1 to 5), level keys (1 to 10),
  tip jar. Theme pack and Block styles have a one-hour video trial.
- **Ads (Android):** a banner with space reserved; rewarded videos only when the
  player asks (coins, a hint, a key, a trial); one video after every 5 finished
  levels, on tapping Next, never for Supporters.
