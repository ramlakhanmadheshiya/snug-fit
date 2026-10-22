class_name Palette
extends RefCounted
## One calm colour story per chapter. Every screen reads its colours from here.
## "blocks" colour the pieces; "paint" are the three colours Paint levels use
## (clearly different hues, so a coloured cell is never ambiguous).

const CHAPTERS: Dictionary = {
	"ch1": {
		"name": "Fit", "tagline": "Fill the shape",
		"top": Color("#FFF4E8"), "bottom": Color("#FFD3C2"),
		"ink": Color("#2D2A4A"), "muted": Color("#2D2A4A", 0.45), "faint": Color("#2D2A4A", 0.08),
		"accent": Color("#FF8A5B"), "target": Color("#FF5D5D"),
		"blocks": [Color("#FF7F6E"), Color("#F5B544"), Color("#4FBFA4"), Color("#5BA6E6"), Color("#9C8CF0"), Color("#F28DB2")],
		"paint": [Color("#F25F5C"), Color("#F2B33D"), Color("#3D8BD9")],
		"card": Color("#FFFFFF", 0.55), "dark": false,
	},
	"ch2": {
		"name": "Turn", "tagline": "Tap a piece to turn it",
		"top": Color("#EAF8F4"), "bottom": Color("#B7E4DA"),
		"ink": Color("#173A45"), "muted": Color("#173A45", 0.45), "faint": Color("#173A45", 0.08),
		"accent": Color("#2BA7A0"), "target": Color("#F2545B"),
		"blocks": [Color("#2BA7A0"), Color("#F2765B"), Color("#F2B544"), Color("#4D8FE0"), Color("#9A6FD8"), Color("#7CC36A")],
		"paint": [Color("#F2545B"), Color("#F2B544"), Color("#2B7BD6")],
		"card": Color("#FFFFFF", 0.5), "dark": false,
	},
	"ch3": {
		"name": "Paint", "tagline": "Colours must match",
		"top": Color("#EEF5FB"), "bottom": Color("#CFE3F5"),
		"ink": Color("#1E3A55"), "muted": Color("#1E3A55", 0.5), "faint": Color("#1E3A55", 0.08),
		"accent": Color("#3D8BD9"), "target": Color("#F25F5C"),
		"blocks": [Color("#3D8BD9"), Color("#F25F5C"), Color("#F2B33D"), Color("#4FBF9A"), Color("#8E7CE0"), Color("#F28C5B")],
		"paint": [Color("#F25F5C"), Color("#F2B33D"), Color("#3D8BD9")],
		"card": Color("#FFFFFF", 0.55), "dark": false,
	},
	"ch4": {
		"name": "Pegs", "tagline": "One peg per piece",
		"top": Color("#F1F4E6"), "bottom": Color("#C9D7B0"),
		"ink": Color("#27352A"), "muted": Color("#27352A", 0.5), "faint": Color("#27352A", 0.08),
		"accent": Color("#5E8C3A"), "target": Color("#E4572E"),
		"blocks": [Color("#7FB35A"), Color("#E9844F"), Color("#E7BB45"), Color("#4FA7A0"), Color("#C57AA8"), Color("#7C8FD6")],
		"paint": [Color("#E4572E"), Color("#E7BB45"), Color("#3F8FC9")],
		"card": Color("#FFFFFF", 0.5), "dark": false,
	},
	"ch5": {
		"name": "Spare", "tagline": "One piece too many",
		"top": Color("#FBEDE8"), "bottom": Color("#E8B4A6"),
		"ink": Color("#3E2430"), "muted": Color("#3E2430", 0.5), "faint": Color("#3E2430", 0.08),
		"accent": Color("#C8553D"), "target": Color("#D7263D"),
		"blocks": [Color("#E2725B"), Color("#8E6CC2"), Color("#E8A83E"), Color("#4CA79A"), Color("#D9668F"), Color("#5E8FD6")],
		"paint": [Color("#D7263D"), Color("#E8A83E"), Color("#4C7BD6")],
		"card": Color("#FFFFFF", 0.5), "dark": false,
	},
	"ch6": {
		"name": "Flip", "tagline": "Pieces flip over",
		"top": Color("#3A2E6E"), "bottom": Color("#7C4F8F"),
		"ink": Color("#FFF1F7"), "muted": Color("#FFF1F7", 0.55), "faint": Color("#FFF1F7", 0.08),
		"accent": Color("#FF8FC7"), "target": Color("#FFD166"),
		"blocks": [Color("#FF8FC7"), Color("#6EE7F9"), Color("#FFD166"), Color("#A88BFF"), Color("#7EE0A8"), Color("#FF9F7A")],
		"paint": [Color("#FF6B8A"), Color("#FFD166"), Color("#6EE7F9")],
		"card": Color("#FFFFFF", 0.09), "dark": true,
	},
	"ch7": {
		"name": "Mosaic", "tagline": "Everything at once",
		"top": Color("#0F1328"), "bottom": Color("#1E2046"),
		"ink": Color("#E9EDFF"), "muted": Color("#E9EDFF", 0.5), "faint": Color("#E9EDFF", 0.07),
		"accent": Color("#8BE9FD"), "target": Color("#FF5E8A"),
		"blocks": [Color("#8BE9FD"), Color("#FF79C6"), Color("#F1FA8C"), Color("#BD93F9"), Color("#50FA7B"), Color("#FFB86C")],
		"paint": [Color("#FF5E8A"), Color("#F1FA8C"), Color("#8BE9FD")],
		"card": Color("#FFFFFF", 0.07), "dark": true,
	},
}

const HOME_ID: String = "ch1"

## Colour themes from the Theme pack. "chapters" (free) keeps each chapter's own
## colours; any other theme repaints every chapter in one calm scheme.
const THEMES: Dictionary = {
	"midnight": {"name": "Midnight", "top": "#15161E", "bottom": "#23253A", "ink": "#ECEAF6", "target": "#FF6B81", "accent": "#7AA2F7", "dark": true},
	"paper": {"name": "Paper", "top": "#FAFAF7", "bottom": "#E9E7E1", "ink": "#222222", "target": "#E5484D", "accent": "#222222", "dark": false},
	"sepia": {"name": "Sepia", "top": "#F6EEDF", "bottom": "#E2D2B4", "ink": "#4A3B2A", "target": "#C0532E", "accent": "#A66A2C", "dark": false},
	"nord": {"name": "Nord", "top": "#2E3440", "bottom": "#3B4252", "ink": "#ECEFF4", "target": "#BF616A", "accent": "#88C0D0", "dark": true},
	"dracula": {"name": "Dracula", "top": "#282A36", "bottom": "#343746", "ink": "#F8F8F2", "target": "#FF5555", "accent": "#BD93F9", "dark": true},
	"forest": {"name": "Forest", "top": "#EEF3EA", "bottom": "#C9DBC0", "ink": "#22372B", "target": "#D2553F", "accent": "#3F7D4F", "dark": false},
	"ocean": {"name": "Ocean", "top": "#0E2233", "bottom": "#14405A", "ink": "#E6F4FB", "target": "#FF8A65", "accent": "#4FC3F7", "dark": true},
	"rose": {"name": "Rose", "top": "#FFF1F3", "bottom": "#F7C9D2", "ink": "#4A2030", "target": "#E0405F", "accent": "#C2185B", "dark": false},
	"mint": {"name": "Mint", "top": "#EFFAF5", "bottom": "#BFE8D6", "ink": "#16413A", "target": "#F2545B", "accent": "#18A57E", "dark": false},
	"sunset": {"name": "Sunset", "top": "#2B1B3D", "bottom": "#7A3B57", "ink": "#FFF0E6", "target": "#FFD166", "accent": "#FF8C61", "dark": true},
	"mono": {"name": "Mono", "top": "#101010", "bottom": "#1C1C1C", "ink": "#F2F2F2", "target": "#F2F2F2", "accent": "#BDBDBD", "dark": true},
}

## The active theme and appearance, set by SaveSystem from the player's settings.
static var theme_id: String = "chapters"
## "auto" (each chapter's own look, all dark when the phone is in dark mode),
## "dark" or "light". Theme-pack themes keep their own.
static var appearance: String = "auto"


static func get_palette(chapter_id: String) -> Dictionary:
	var base: Dictionary = CHAPTERS.get(chapter_id, CHAPTERS[HOME_ID])
	if THEMES.has(theme_id):
		return themed(base, theme_id)
	var want_dark: bool = bool(base["dark"])
	if appearance == "dark" or (appearance == "auto" and DisplayServer.is_dark_mode()):
		want_dark = true
	elif appearance == "light":
		want_dark = false
	return base if want_dark == bool(base["dark"]) else turned(base, want_dark)


## A chapter in the other appearance: its accent sets a deep night or a soft day.
static func turned(base: Dictionary, dark: bool) -> Dictionary:
	var out: Dictionary = base.duplicate()
	var accent: Color = base["accent"]
	var ink: Color
	if dark:
		out["top"] = accent.darkened(0.84).lerp(Color("#17142E"), 0.5)
		out["bottom"] = accent.darkened(0.72).lerp(Color("#211C40"), 0.45)
		ink = Color("#F3F1FA")
		out["card"] = Color("#FFFFFF", 0.08)
	else:
		out["top"] = accent.lerp(Color.WHITE, 0.88)
		out["bottom"] = accent.lerp(Color.WHITE, 0.68)
		ink = Color("#29244E")
		out["card"] = Color("#FFFFFF", 0.55)
		# Night accents are pale; deepen them so text in the accent reads on white.
		out["accent"] = accent.darkened(0.38) if accent.get_luminance() > 0.55 else accent
	out["ink"] = ink
	out["muted"] = Color(ink, 0.55 if dark else 0.5)
	out["faint"] = Color(ink, 0.08)
	out["dark"] = dark
	return out


## A chapter palette repainted in a theme (keeps the chapter's name, tagline and blocks).
static func themed(base: Dictionary, id: String) -> Dictionary:
	var th: Dictionary = THEMES[id]
	var ink: Color = Color(th["ink"])
	var dark: bool = bool(th["dark"])
	var out: Dictionary = base.duplicate()
	out["top"] = Color(th["top"])
	out["bottom"] = Color(th["bottom"])
	out["ink"] = ink
	out["muted"] = Color(ink, 0.5)
	out["faint"] = Color(ink, 0.07 if dark else 0.08)
	out["target"] = Color(th["target"])
	out["accent"] = Color(th["accent"])
	out["card"] = Color("#FFFFFF", 0.08 if dark else 0.5)
	out["dark"] = dark
	if id == "mono":
		out["blocks"] = [Color("#F2F2F2"), Color("#BDBDBD"), Color("#8A8A8A"), Color("#DADADA"), Color("#A5A5A5"), Color("#717171")]
	return out


## Theme ids in shop order, "chapters" first.
static func theme_ids() -> Array:
	return ["chapters"] + THEMES.keys()


static func theme_name(id: String) -> String:
	return "Chapter colours" if id == "chapters" else str(THEMES.get(id, {}).get("name", id))


## A piece's colour: its paint colour on levels with coloured cells, otherwise
## one of the chapter's block colours.
static func block_color(pal: Dictionary, index: int, paint: bool) -> Color:
	var list: Array = pal["paint"] if paint else pal["blocks"]
	return list[posmod(index, list.size())]


## Play order, gentlest idea first.
const ORDER: Array = ["ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7"]


static func ids() -> Array:
	return ORDER
