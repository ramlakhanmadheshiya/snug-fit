#!/usr/bin/env python3
"""Writes Snug Fit's icon artwork as SVG: three pieces settled snugly into a square.

  python3 tools/make_icons.py                       # assets/icon.svg + assets/android/src/*.svg
  godot --headless --path . -s res://tools/render_icons.gd   # the PNGs Android and the boot splash use

The same three pieces (and colours) open the game in game/ui/splash.gd.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BG = ("#3A2F7A", "#241E52", "#15122F")
# Cells on a 3 x 3 grid, colour, and the darker lip under it.
PIECES = [
    ([(0, 0), (1, 0), (0, 1)], "#FF7F6E", "#D9604F"),
    ([(2, 0), (2, 1), (2, 2)], "#F5B544", "#CF9227"),
    ([(1, 1), (0, 2), (1, 2)], "#4FBFA4", "#349C83"),
]
CELL = 200
GAP = 16
R = 46
LIP = 18


def piece(cells, fill, ox, oy, mono=False):
    """One piece as rounded cells bridged to their neighbours (opaque, so no seams)."""
    out = []
    inner = CELL - GAP
    s = set(cells)
    for (x, y) in cells:
        px, py = ox + x * CELL + GAP / 2, oy + y * CELL + GAP / 2
        out.append(f'<rect x="{px}" y="{py}" width="{inner}" height="{inner}" rx="{R}" fill="{fill}"/>')
        if (x + 1, y) in s:
            out.append(f'<rect x="{px + inner - R}" y="{py}" width="{GAP + 2 * R}" height="{inner}" fill="{fill}"/>')
        if (x, y + 1) in s:
            out.append(f'<rect x="{px}" y="{py + inner - R}" width="{inner}" height="{GAP + 2 * R}" fill="{fill}"/>')
    return "\n    ".join(out)


def highlights(cells, ox, oy):
    """A soft light along the top of each piece's top cells."""
    s = set(cells)
    out = []
    for (x, y) in cells:
        if (x, y - 1) not in s:
            px, py = ox + x * CELL + GAP / 2, oy + y * CELL + GAP / 2
            out.append(f'<rect x="{px + 40}" y="{py + 22}" width="{CELL - GAP - 80}" height="20" rx="10" fill="#FFFFFF" opacity="0.28"/>')
    return "\n    ".join(out)


def seams(cells, ox, oy, colour):
    """Faint lines between the blocks of one piece."""
    s = set(cells)
    out = []
    for (x, y) in cells:
        px, py = ox + x * CELL, oy + y * CELL
        if (x + 1, y) in s:
            out.append(f'<line x1="{px + CELL}" y1="{py + 40}" x2="{px + CELL}" y2="{py + CELL - 40}" stroke="{colour}" stroke-width="7" stroke-linecap="round" opacity="0.55"/>')
        if (x, y + 1) in s:
            out.append(f'<line x1="{px + 40}" y1="{py + CELL}" x2="{px + CELL - 40}" y2="{py + CELL}" stroke="{colour}" stroke-width="7" stroke-linecap="round" opacity="0.55"/>')
    return "\n    ".join(out)


def art(mono=False):
    ox = oy = 512 - 1.5 * CELL
    parts = []
    if not mono:
        # The square the pieces fill, a shade lighter than the background.
        parts.append(f'<rect x="{ox - 22}" y="{oy - 22}" width="{3 * CELL + 44}" height="{3 * CELL + 44}" rx="{R + 24}" fill="#FFFFFF" opacity="0.07"/>')
    for cells, fill, lip in PIECES:
        if mono:
            parts.append(piece(cells, "#FFFFFF", ox, oy))
            continue
        parts.append(piece(cells, lip, ox, oy + LIP))
        parts.append(piece(cells, fill, ox, oy))
        parts.append(seams(cells, ox, oy, lip))
        parts.append(highlights(cells, ox, oy))
    return "\n    ".join(parts)


def defs():
    return f'''<defs>
    <linearGradient id="bg" x1="0.1" y1="0" x2="0.9" y2="1">
      <stop offset="0" stop-color="{BG[0]}"/>
      <stop offset="0.55" stop-color="{BG[1]}"/>
      <stop offset="1" stop-color="{BG[2]}"/>
    </linearGradient>
  </defs>'''


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n  {body}\n</svg>\n'


def main():
    icon = svg(f'{defs()}\n  <rect width="1024" height="1024" rx="232" fill="url(#bg)"/>\n  <g transform="translate(512 524) scale(1.0) translate(-512 -512)">\n    {art()}\n  </g>')
    (ROOT / "assets/icon.svg").write_text(icon)
    src = ROOT / "assets/android/src"
    (src / "background.svg").write_text(svg(f'{defs()}\n  <rect width="1024" height="1024" fill="url(#bg)"/>'))
    # Adaptive icons keep the middle 66% safe from the launcher's mask.
    (src / "foreground.svg").write_text(svg(f'<g transform="translate(512 520) scale(0.6) translate(-512 -512)">\n    {art()}\n  </g>'))
    (src / "monochrome.svg").write_text(svg(f'<g transform="translate(512 520) scale(0.6) translate(-512 -512)">\n    {art(mono=True)}\n  </g>'))
    print("wrote assets/icon.svg and assets/android/src/*.svg")


if __name__ == "__main__":
    main()
