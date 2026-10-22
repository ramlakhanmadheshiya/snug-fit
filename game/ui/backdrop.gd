class_name Backdrop
extends Control
## Soft vertical gradient that eases between chapter palettes, with a few little
## blocks slowly drifting up and turning.

var _top: Color = Color("#FFF4E8")
var _bottom: Color = Color("#FFD3C2")
var _mote: Color = Color(1, 1, 1, 0.5)
var _motes: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7
	for i: int in 18:
		_motes.append({"p": Vector2(_rng.randf(), _rng.randf()), "r": _rng.randf_range(5.0, 12.0), "s": _rng.randf_range(0.005, 0.016), "ph": _rng.randf() * TAU})


func set_palette(pal: Dictionary, animate: bool = true) -> void:
	var top: Color = pal["top"]
	var bottom: Color = pal["bottom"]
	var mote: Color = Color(1, 1, 1, 0.55) if not bool(pal.get("dark", false)) else Color(1, 1, 1, 0.18)
	if _tween != null:
		_tween.kill()
	if not animate:
		_top = top
		_bottom = bottom
		_mote = mote
		queue_redraw()
		return
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "_top", top, 0.7)
	_tween.tween_property(self, "_bottom", bottom, 0.7)
	_tween.tween_property(self, "_mote", mote, 0.7)


func _process(delta: float) -> void:
	for m: Dictionary in _motes:
		var p: Vector2 = m["p"]
		p.y -= float(m["s"]) * delta
		p.x += sin(Time.get_ticks_msec() / 1000.0 * 0.4 + float(m["ph"])) * 0.0006
		if p.y < -0.02:
			p.y = 1.02
		m["p"] = p
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var pts: PackedVector2Array = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(pts, PackedColorArray([_top, _top, _bottom, _bottom]))
	for m: Dictionary in _motes:
		var p: Vector2 = (m["p"] as Vector2) * size
		var t: float = Time.get_ticks_msec() / 1000.0
		var tw: float = 0.5 + 0.5 * sin(t * 0.8 + float(m["ph"]))
		var half: float = float(m["r"])
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(_mote, _mote.a * (0.25 + 0.45 * tw))
		sb.set_corner_radius_all(int(half * 0.35))
		draw_set_transform(p, t * 0.15 + float(m["ph"]), Vector2.ONE)
		draw_style_box(sb, Rect2(-Vector2(half, half), Vector2(half, half) * 2.0))
		draw_set_transform_matrix(Transform2D.IDENTITY)
