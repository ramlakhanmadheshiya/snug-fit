class_name ChapterArt
extends Control
## A looping mini-scene that shows what a chapter is about: the last piece turns,
## flips or finds its colour, then slides into the shape. Used on the chapter
## cards, the chapter hero and each chapter's intro card.
## Scenes are drawn on a virtual 10 x 5 grid, scaled into `area` (or the whole
## control if `area` is empty).

const GRID: Vector2 = Vector2(10, 5)
const PERIOD: float = 3.6

## Per chapter: the shape's cells, the pieces already in it, and the piece that
## arrives ("move", its final cells; "from", where it starts; "act": turn/flip).
const SCENES: Dictionary = {
	"ch1": {"pieces": [[[5, 1], [6, 1], [7, 1], [8, 1]], [[5, 2], [5, 3], [6, 3]]],
		"move": [[6, 2], [7, 2], [8, 2], [7, 3], [8, 3]], "from": [-5, 0], "act": ""},
	"ch2": {"pieces": [[[5, 1], [6, 1], [5, 2]], [[5, 3], [6, 3], [7, 3], [8, 3]]],
		"move": [[7, 1], [8, 1], [6, 2], [7, 2], [8, 2]], "from": [-5, 0], "act": "turn"},
	"ch3": {"pieces": [[[5, 1], [6, 1], [7, 1], [5, 2]], [[8, 1], [8, 2], [8, 3], [7, 3]]],
		"move": [[6, 2], [7, 2], [5, 3], [6, 3]], "from": [-5, 0], "act": "paint", "mark": [6, 3]},
	"ch4": {"pieces": [[[5, 1], [6, 1], [5, 2], [5, 3]], [[7, 1], [8, 1], [8, 2], [8, 3]]],
		"move": [[6, 2], [7, 2], [6, 3], [7, 3]], "from": [-5, 0], "act": "pegs", "pegs": [[5, 2], [8, 1], [7, 3]]},
	"ch5": {"pieces": [[[5, 1], [6, 1], [7, 1], [8, 1]], [[5, 2], [6, 2], [5, 3]]],
		"move": [[7, 2], [8, 2], [6, 3], [7, 3], [8, 3]], "from": [-5, 0], "act": "spare", "spare": [[1, 0], [1, 1], [2, 1], [2, 2]]},
	"ch6": {"pieces": [[[5, 1], [6, 1], [5, 2], [5, 3]], [[7, 3], [8, 3], [8, 2]]],
		"move": [[7, 1], [8, 1], [6, 2], [7, 2], [6, 3]], "from": [-5, 0], "act": "flip"},
	"ch7": {"pieces": [],
		"move": [], "act": "mosaic",
		"drops": [[[4, 1], [5, 1], [4, 2]], [[6, 1], [7, 1], [8, 1], [8, 2]], [[5, 2], [6, 2], [7, 2]], [[4, 3], [5, 3], [6, 3]], [[7, 3], [8, 3]]]},
}

var chapter_id: String = "ch1"
var pal: Dictionary = Palette.get_palette("ch1")
## Where to draw, in local pixels. Empty = the full control.
var area: Rect2 = Rect2()
var playing: bool = true
## What the scene sits on (see-through shapes are mixed onto it).
var bg: Color = Color(0, 0, 0, 0)
var _t: float = 0.0
var _cs: float = 20.0
var _origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * PERIOD


func _process(delta: float) -> void:
	if playing and is_visible_in_tree():
		_t += delta
		queue_redraw()


static func _cells(raw: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Array in raw:
		out.append(Vector2i(int(c[0]), int(c[1])))
	return out


func _draw() -> void:
	var box: Rect2 = area if area.size.x > 0.0 else Rect2(Vector2.ZERO, size)
	_cs = minf(box.size.x / GRID.x, box.size.y / GRID.y)
	_origin = box.position + (box.size - GRID * _cs) * 0.5
	var sc: Dictionary = SCENES.get(chapter_id, SCENES["ch1"])
	var u: float = fmod(_t, PERIOD) / PERIOD
	var alpha: float = clampf(u / 0.06, 0.0, 1.0) * clampf((1.0 - u) / 0.08, 0.0, 1.0)
	if not playing:
		u = 1.0
		alpha = 1.0
	var act: String = sc["act"]
	var blocks: Array = pal["blocks"]
	var paint: Array = pal["paint"]
	# The shape: every cell any piece ends up in.
	var shape: Dictionary = {}
	var all: Array = (sc["pieces"] as Array) + [sc["move"]] + (sc.get("drops", []) as Array)
	for p: Array in all:
		for c: Vector2i in _cells(p):
			shape[c] = true
	var base: Color = bg if bg.a > 0.0 else (pal["top"] as Color).lerp(pal["bottom"], 0.3)
	var plate_c: Color = BlockStyles.solid(base, Color(pal["ink"], 0.06))
	BlockStyles._blob(self, shape, _origin, _cs, -_cs * 0.1, _cs * 0.3, Color(plate_c, alpha))
	var well: StyleBoxFlat = StyleBoxFlat.new()
	well.bg_color = Color(BlockStyles.solid(plate_c, Color(pal["ink"], 0.07)), alpha)
	well.set_corner_radius_all(int(_cs * 0.2))
	for c: Vector2i in shape:
		draw_style_box(well, Rect2(_origin + Vector2(c) * _cs, Vector2(_cs, _cs)).grow(-_cs * 0.06))
	if sc.has("mark"):
		var m: Vector2i = Vector2i(int(sc["mark"][0]), int(sc["mark"][1]))
		var ms: StyleBoxFlat = well.duplicate()
		ms.bg_color = Color(paint[2], 0.3 * alpha)
		ms.border_color = Color(paint[2], 0.9 * alpha)
		ms.set_border_width_all(maxi(2, int(_cs * 0.06)))
		draw_style_box(ms, Rect2(_origin + Vector2(m) * _cs, Vector2(_cs, _cs)).grow(-_cs * 0.12))
	for i: int in (sc["pieces"] as Array).size():
		var col: Color = paint[i] if act == "paint" else blocks[(i * 2 + 1) % blocks.size()]
		BlockStyles.draw_piece(self, "soft", _cells(sc["pieces"][i]), _origin, _cs, col, pal, 0.0, alpha)
	if act == "mosaic":
		var drops: Array = sc["drops"]
		for i: int in drops.size():
			var k: float = clampf((u - 0.08 - 0.11 * float(i)) / 0.16, 0.0, 1.0)
			if k <= 0.0:
				continue
			var fall: float = (1.0 - ease(k, 0.4)) * -_cs * 3.0
			BlockStyles.draw_piece(self, "soft", _cells(drops[i]), _origin + Vector2(0, fall), _cs, blocks[i % blocks.size()], pal, 1.0 - k, alpha * k)
		_pegs(sc, alpha)
		return
	# The arriving piece: act first, then slide in on a small arc.
	var move: Array[Vector2i] = _cells(sc["move"])
	var mn: Vector2i = move[0]
	for c: Vector2i in move:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
	var local: Array[Vector2i] = []
	for c: Vector2i in move:
		local.append(c - mn)
	var sz: Vector2 = Vector2(FitSim.size_of(local))
	var act_k: float = clampf((u - 0.12) / 0.18, 0.0, 1.0)
	var slide: float = clampf((u - 0.34) / 0.3, 0.0, 1.0)
	slide = slide * slide * (3.0 - 2.0 * slide)
	var home: Vector2 = _origin + (Vector2(mn) + sz * 0.5) * _cs
	var start: Vector2 = home + Vector2(float(sc["from"][0]), float(sc["from"][1])) * _cs
	var c2: Vector2 = start.lerp(home, slide) - Vector2(0, sin(slide * PI) * _cs * 0.8)
	var spin: float = 0.0
	var flipx: float = 1.0
	if act == "turn":
		spin = lerpf(-PI * 0.5, 0.0, ease(act_k, -2.0))
	elif act == "flip":
		flipx = lerpf(-1.0, 1.0, ease(act_k, -2.0))
	var pop: float = clampf((u - 0.64) / 0.08, 0.0, 1.0)
	var s: float = _cs * (1.0 + 0.1 * sin(pop * PI))
	var col2: Color = paint[2] if act == "paint" else blocks[0]
	draw_set_transform(c2, spin, Vector2(flipx, 1.0))
	BlockStyles.draw_piece(self, "soft", local, -sz * s * 0.5, s, col2, pal, sin(slide * PI), alpha)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if act == "spare":
		var wob: float = sin(_t * 9.0) * _cs * 0.06 * clampf((u - 0.66) / 0.1, 0.0, 1.0)
		BlockStyles.draw_piece(self, "soft", _cells(sc["spare"]), _origin + Vector2(wob, _cs * 1.0), _cs * 0.9, blocks[3], pal, 0.0, alpha * lerpf(1.0, 0.45, clampf((u - 0.66) / 0.1, 0.0, 1.0)))
	_pegs(sc, alpha)


func _pegs(sc: Dictionary, alpha: float) -> void:
	for p: Array in sc.get("pegs", []):
		var c: Vector2 = _origin + (Vector2(float(p[0]), float(p[1])) + Vector2(0.5, 0.5)) * _cs
		var r: float = _cs * 0.14
		draw_circle(c, r, Color(1, 1, 1, 0.92 * alpha), true, -1.0, true)
		draw_circle(c, r * 0.45, Color(pal["ink"], 0.4 * alpha), true, -1.0, true)
