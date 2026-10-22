class_name Splash
extends Control
## The opening moment: the logo builds itself (three pieces settle snugly into a
## square), the title appears, then it fades into the game. Matches the boot
## splash colour so the hand-off is seamless.
## Tap to skip.

signal finished

const BG_TOP: Color = Color("#3A2F7A")
const BG_BOTTOM: Color = Color("#15122F")
const LENGTH: float = 2.6
## The logo's pieces on a 3 x 3 grid, their colours, where each flies in from,
## and when each lands (seconds).
const PIECES: Array = [[[0, 0], [1, 0], [0, 1]], [[2, 0], [2, 1], [2, 2]], [[1, 1], [0, 2], [1, 2]]]
const COLORS: Array = [Color("#FF7F6E"), Color("#F5B544"), Color("#4FBFA4")]
const FROM: Array = [Vector2(-3.5, -1.0), Vector2(3.5, -0.5), Vector2(0.0, 4.0)]
const LANDS: Array = [0.75, 1.05, 1.4]

var _t: float = 0.0
## Driven frame by frame (e.g. for recording) instead of by the clock: no sound, no
## tap to skip, no fade-out.
var manual: bool = false
var _done: bool = false
var _landed: int = 0


## Shows the moment `t` seconds in (manual mode).
func show_at(t: float) -> void:
	_t = t
	_landed = LANDS.filter(func(l: float) -> bool: return t > l).size()
	queue_redraw()


func _ready() -> void:
	if manual:
		set_process(false)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_finish()
	)


func _process(delta: float) -> void:
	_t += delta
	if _landed < LANDS.size() and _t > LANDS[_landed]:
		AudioManager.play_note("place", 2 + _landed * 2, -4.0)
		Haptics.tap(10 + 4 * _landed)
		_landed += 1
	if _t >= LENGTH:
		_finish()
	queue_redraw()


func _finish() -> void:
	if _done:
		return
	_done = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)


## Logo space (1024 x 1024) to screen, centred a little above the middle.
func _p(v: Vector2) -> Vector2:
	var s: float = minf(size.x, size.y) / 1024.0 * 0.62
	return size * Vector2(0.5, 0.42) + (v - Vector2(512, 512)) * s


func _r(v: float) -> float:
	return v * minf(size.x, size.y) / 1024.0 * 0.62


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([BG_TOP, BG_TOP, BG_BOTTOM, BG_BOTTOM]))
	var appear: float = clampf(_t / 0.35, 0.0, 1.0)
	var cs: float = _r(230)
	var grid: Vector2 = _p(Vector2(512, 512)) - Vector2(cs, cs) * 1.5
	# The empty square, waiting.
	var plate: Dictionary = {}
	for y: int in 3:
		for x: int in 3:
			plate[Vector2i(x, y)] = true
	BlockStyles._blob(self, plate, grid, cs, -cs * 0.12, cs * 0.3, BlockStyles.solid(BG_TOP.lerp(BG_BOTTOM, 0.42), Color(1, 1, 1, 0.08 * appear)))
	var pal: Dictionary = {"ink": Color("#F4F1FF"), "top": BG_TOP, "dark": true}
	for i: int in PIECES.size():
		var land: float = LANDS[i]
		var k: float = clampf((_t - (land - 0.45)) / 0.45, 0.0, 1.0)
		if k <= 0.0:
			continue
		var e: float = 1.0 - pow(1.0 - k, 3.0)
		var off: Vector2 = (FROM[i] as Vector2) * cs * (1.0 - e) - Vector2(0, sin(k * PI) * cs * 0.4)
		var pop: float = clampf((_t - land) / 0.25, 0.0, 1.0)
		var cells: Array[Vector2i] = FitSim.to_cells(PIECES[i])
		var center: Vector2 = grid + Vector2(cs, cs) * 1.5 + off
		var s: float = 1.0 + 0.08 * sin(pop * PI)
		draw_set_transform(center, 0.0, Vector2(s, s))
		BlockStyles.draw_piece(self, "soft", cells, -Vector2(cs, cs) * 1.5, cs, COLORS[i], pal, 1.0 - e, minf(1.0, k * 3.0))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	# A soft ring when the square is complete.
	var done_t: float = clampf((_t - LANDS[-1]) / 0.6, 0.0, 1.0)
	if done_t > 0.0 and done_t < 1.0:
		draw_arc(grid + Vector2(cs, cs) * 1.5, cs * (1.6 + 1.4 * done_t), 0.0, TAU, 64, Color(1, 1, 1, 0.5 * (1.0 - done_t)), _r(10), true)
	# Title.
	var ta: float = clampf((_t - 1.55) / 0.45, 0.0, 1.0)
	if ta > 0.0:
		var f2: Font = UIKit.font(250)
		var fs: int = int(clampf(size.x * 0.11, 48.0, 96.0))
		var title: String = "snug fit"
		var w: float = f2.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var y: float = size.y * 0.42 + _r(560) + 20.0 * (1.0 - ta)
		draw_string(f2, Vector2(size.x * 0.5 - w * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#F4F1FF", ta))
		var f3: Font = UIKit.font(500)
		var tag: String = "a calm shape puzzle"
		var tw2: float = f3.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(f3, Vector2(size.x * 0.5 - tw2 * 0.5, y + 46.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5 * ta))
