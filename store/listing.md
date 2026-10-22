# Google Play store listing: Snug Fit

Paste these into Play Console > Grow users > Store presence > Main store listing.
Lengths are checked by `python3 store/check_listing.py`.

## App name (30 max)

Snug Fit: Block Shape Puzzle

## Short description (80 max)

Fit every block into the shape. A calm puzzle with 210 hand-checked levels.

## Full description (4000 max)

Snug Fit is a calm block puzzle. Each level is a shape: a cat, a rocket, a teacup, a castle. Drag the pieces from the tray into it until every cell is filled, snugly. No timers, no rush.

Every drop on the shape is a move. Find the fit in your head first, then fill it near par for three stars. Changed your mind? Drag a piece back off. Restart is always a fresh start.

SEVEN IDEAS, ONE AT A TIME
Each chapter adds one new idea and opens with a short card that shows it:
• Fit: fill the shape
• Turn: tap a piece to turn it
• Paint: coloured cells take only the piece of their colour
• Pegs: every piece covers exactly one peg
• Spare: there's one piece too many; which one stays out?
• Flip: pieces turn over too
• Mosaic: everything at once

210 LEVELS, A GENTLE CLIMB
Every chapter has 30 shapes, from a few big pieces to big shapes and many small ones. Each level was built with its answer and checked by a solver, so every one can be filled, and late in a chapter there is exactly one way.

CALM BY DESIGN
• A free hint every day; a hint shows exactly where the next piece goes
• Coins for every new level, star and finished chapter
• Optional videos only when you choose them, and one short video every 5 levels at most
• Light and dark appearance, 11 colour themes and 7 block styles
• Progress stays on your device, with no account to make

SHARE YOUR FIT
After a level, save or share a picture of your filled shape and ask your friends: can you fill it in par?

Made with Godot by Ramlakhan Madheshiya (Brainnova Studio). Questions or ideas: support@theramlakhan.com

## Category and tags

- Category: Games > Puzzle
- Tags (up to 5, from the Console's list): Puzzle, Logic, Casual, Block, Offline. Avoid "Brain games" or "brain training": the guide warns these read as health claims.

## Contact details

- Email: support@theramlakhan.com
- Website: https://theramlakhan.com/BrainnovaStudio/games/snug-fit/
- Privacy policy: https://theramlakhan.com/BrainnovaStudio/games/snug-fit/privacy/

## Graphics

Made from the real game: `godot --fixed-fps 60 --disable-vsync --always-on-top --path . res://tests/capture.tscn -- store/screenshots --store` (phone screenshots), `godot --path . --resolution 1024x500 res://tools/render_feature_graphic.tscn` (feature graphic and icon).

| Asset | File |
|---|---|
| App icon, 512 x 512 PNG (32-bit, full bleed) | `store/icon_512.png` |
| Feature graphic, 1024 x 500 PNG | `store/feature_graphic.png` |
| Phone screenshots, 1080 x 1920 PNG | `store/screenshots/*.png` (8, in order) |

## Screenshot alt text (one plain sentence each)

1. `01_home.png`: The home screen, with the Snug Fit title, a shape filling itself, and a big Play button.
2. `02_fit.png`: A piece being carried into a half-filled shape in the Fit chapter.
3. `03_paint.png`: Coloured cells in a Paint level, with a matching piece on its way in.
4. `04_turn.png`: A Turn level, with pieces turned to fit a larger shape.
5. `05_pegs.png`: A Pegs level, where every piece covers exactly one peg.
6. `06_mosaic.png`: A dark Mosaic level mixing colours, pegs and turning pieces.
7. `07_result.png`: The level complete card with stars, the filled shape and the coins earned.
8. `08_chapters.png`: The seven chapters as colourful tiles, each showing its idea.
