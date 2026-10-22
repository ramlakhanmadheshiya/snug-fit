class_name BlockStyles
extends RefCounted
## How pieces look, in every style the Block pack offers. "soft" is free; the
## rest come with the Block pack (or a one-hour trial from a video).
## A piece is drawn as one joined shape, with faint seams between its blocks.

const STYLES: Array = [
	{"id": "soft", "name": "Soft", "free": true},
	{"id": "candy", "name": "Candy"},
	{"id": "paper", "name": "Paper"},
	{"id": "glass", "name": "Glass"},
	{"id": "neon", "name": "Neon"},
	{"id": "stone", "name": "Stone"},
	{"id": "pixel", "name": "Pixel"},
]

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]


static func ids() -> Array:
	return STYLES.map(func(s: Dictionary) -> String: return str(s["id"]))


static func display_name(id: String) -> String:
	for s: Dictionary in STYLES:
		if str(s["id"]) == id:
			return str(s["name"])
	return "Soft"


static func is_free(id: String) -> bool:
	return id == "soft"


## Draws a piece whose cells sit at origin + cell * cs. `lift` (0..1) adds the
## shadow of a piece being carried.
static func draw_piece(c: CanvasItem, id: String, cells: Array[Vector2i], origin: Vector2, cs: float, col: Color, pal: Dictionary, lift: float = 0.0, alpha: float = 1.0) -> void:
	var cellset: Dictionary = {}
	for q: Vector2i in cells:
		cellset[q] = true
	var gap: float = maxf(1.5, cs * 0.05)
	var r: float = cs * (0.0 if id == "pixel" else 0.2)
	var dark: bool = bool(pal.get("dark", false))
	if lift > 0.0:
		_blob(c, cellset, origin + Vector2(0, cs * 0.18) * lift, cs, gap - cs * 0.02, r, Color(0, 0, 0, (0.22 if not dark else 0.4) * lift * alpha))
	match id:
		"candy":
			_blob(c, cellset, origin + Vector2(0, cs * 0.07), cs, gap, r, Color(col.darkened(0.25), alpha))
			_blob(c, cellset, origin, cs, gap, r, Color(col.lightened(0.05), alpha))
			_seams(c, cellset, origin, cs, gap, Color(col.darkened(0.2), 0.35 * alpha))
			for q: Vector2i in cells:
				var p: Vector2 = origin + Vector2(q) * cs
				c.draw_circle(p + Vector2(cs * 0.32, cs * 0.3), cs * 0.13, Color(1, 1, 1, 0.55 * alpha), true, -1.0, true)
				c.draw_circle(p + Vector2(cs * 0.5, cs * 0.24), cs * 0.05, Color(1, 1, 1, 0.45 * alpha), true, -1.0, true)
		"paper":
			var line: Color = Color(pal["ink"], 0.85 * alpha)
			_blob(c, cellset, origin, cs, gap - maxf(2.0, cs * 0.04), r, line)
			_blob(c, cellset, origin, cs, gap + maxf(1.0, cs * 0.02), r * 0.85, Color(col.lerp(Color.WHITE, 0.15), alpha))
			_seams(c, cellset, origin, cs, gap, Color(pal["ink"], 0.25 * alpha))
		"glass":
			_blob(c, cellset, origin, cs, gap, r, Color(col.lightened(0.35), 0.5 * alpha))
			_blob(c, cellset, origin, cs, gap + cs * 0.08, r * 0.7, Color(col, 0.55 * alpha))
			_seams(c, cellset, origin, cs, gap, Color(1, 1, 1, 0.35 * alpha))
			for q: Vector2i in cells:
				if not cellset.has(q + Vector2i(0, -1)):
					var p: Vector2 = origin + Vector2(q) * cs
					c.draw_line(p + Vector2(cs * 0.22, cs * 0.2), p + Vector2(cs * 0.78, cs * 0.2), Color(1, 1, 1, 0.6 * alpha), maxf(1.5, cs * 0.05), true)
		"neon":
			for i: int in 3:
				_blob(c, cellset, origin, cs, gap - cs * 0.05 * float(3 - i), r * 1.1, Color(col, 0.12 * alpha))
			_blob(c, cellset, origin, cs, gap, r, Color(col, alpha))
			_blob(c, cellset, origin, cs, gap + maxf(2.5, cs * 0.07), r * 0.8, Color(pal["top"].lerp(Color.BLACK, 0.35), 0.92 * alpha))
			_seams(c, cellset, origin, cs, gap, Color(col, 0.5 * alpha))
		"stone":
			var base: Color = col.lerp(Color("#9A958E"), 0.35)
			_blob(c, cellset, origin + Vector2(0, cs * 0.06), cs, gap, r * 0.6, Color(base.darkened(0.3), alpha))
			_blob(c, cellset, origin, cs, gap, r * 0.6, Color(base, alpha))
			_seams(c, cellset, origin, cs, gap, Color(base.darkened(0.3), 0.5 * alpha))
			for q: Vector2i in cells:
				var p: Vector2 = origin + Vector2(q) * cs
				for k: int in 5:
					var h: int = hash(Vector3i(q.x, q.y, k))
					var sp: Vector2 = p + Vector2(float(h % 97) / 97.0, float((h / 97) % 89) / 89.0) * cs * 0.7 + Vector2(cs * 0.15, cs * 0.15)
					c.draw_circle(sp, cs * 0.025 + float(h % 3) * 0.6, Color(base.darkened(0.25 if k % 2 == 0 else -0.25), 0.6 * alpha), true, -1.0, true)
		"pixel":
			for q: Vector2i in cells:
				var p: Vector2 = origin + Vector2(q) * cs
				var rc: Rect2 = Rect2(p + Vector2(gap, gap) * 0.5, Vector2(cs - gap, cs - gap))
				c.draw_rect(rc, Color(col, alpha))
				var b: float = maxf(2.0, cs * 0.1)
				c.draw_rect(Rect2(rc.position, Vector2(rc.size.x, b)), Color(col.lightened(0.3), alpha))
				c.draw_rect(Rect2(rc.position, Vector2(b, rc.size.y)), Color(col.lightened(0.18), alpha))
				c.draw_rect(Rect2(rc.position + Vector2(0, rc.size.y - b), Vector2(rc.size.x, b)), Color(col.darkened(0.3), alpha))
				c.draw_rect(Rect2(rc.position + Vector2(rc.size.x - b, 0), Vector2(b, rc.size.y)), Color(col.darkened(0.2), alpha))
		_:
			# Soft: a gentle lip under the piece, a calm face, a faint top light.
			_blob(c, cellset, origin + Vector2(0, cs * 0.07), cs, gap, r, Color(col.darkened(0.2), alpha))
			_blob(c, cellset, origin, cs, gap, r, Color(col, alpha))
			_seams(c, cellset, origin, cs, gap, Color(col.darkened(0.16), 0.55 * alpha))
			for q: Vector2i in cells:
				if not cellset.has(q + Vector2i(0, -1)):
					var p: Vector2 = origin + Vector2(q) * cs
					var hl: StyleBoxFlat = StyleBoxFlat.new()
					hl.bg_color = Color(1, 1, 1, 0.22 * alpha)
					hl.set_corner_radius_all(int(cs * 0.08))
					c.draw_style_box(hl, Rect2(p + Vector2(cs * 0.2, gap + cs * 0.08), Vector2(cs * 0.6, cs * 0.09)))


## A see-through colour laid over `bg`, made solid, so overlapping parts of one
## shape never show darker seams.
static func solid(bg: Color, c: Color) -> Color:
	return Color(bg.lerp(Color(c, 1.0), c.a), 1.0)


## Every cell as a rounded square, bridged to its neighbours so the piece reads as one shape.
static func _blob(c: CanvasItem, cellset: Dictionary, origin: Vector2, cs: float, inset: float, r: float, col: Color) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(maxf(0.0, r)))
	sb.corner_detail = 6
	sb.anti_aliasing = true
	var h: float = inset * 0.5
	for q: Vector2i in cellset:
		var p: Vector2 = origin + Vector2(q) * cs
		var cell: Rect2 = Rect2(p + Vector2(h, h), Vector2(cs - inset, cs - inset))
		c.draw_style_box(sb, cell)
		if cellset.has(q + Vector2i(1, 0)):
			c.draw_rect(Rect2(Vector2(cell.end.x - r - 1.0, cell.position.y), Vector2(inset + 2.0 * r + 2.0, cell.size.y)), col)
		if cellset.has(q + Vector2i(0, 1)):
			c.draw_rect(Rect2(Vector2(cell.position.x, cell.end.y - r - 1.0), Vector2(cell.size.x, inset + 2.0 * r + 2.0)), col)
		if cellset.has(q + Vector2i(1, 0)) and cellset.has(q + Vector2i(0, 1)) and cellset.has(q + Vector2i(1, 1)):
			c.draw_rect(Rect2(cell.end - Vector2(r + 1.0, r + 1.0), Vector2(inset + 2.0 * r + 2.0, inset + 2.0 * r + 2.0)), col)


## Thin lines between the blocks of one piece, so its size is easy to count.
static func _seams(c: CanvasItem, cellset: Dictionary, origin: Vector2, cs: float, inset: float, col: Color) -> void:
	var w: float = maxf(1.0, cs * 0.035)
	var m: float = inset * 0.5 + cs * 0.14
	for q: Vector2i in cellset:
		var p: Vector2 = origin + Vector2(q) * cs
		if cellset.has(q + Vector2i(1, 0)):
			c.draw_line(p + Vector2(cs, m), p + Vector2(cs, cs - m), col, w, true)
		if cellset.has(q + Vector2i(0, 1)):
			c.draw_line(p + Vector2(m, cs), p + Vector2(cs - m, cs), col, w, true)
