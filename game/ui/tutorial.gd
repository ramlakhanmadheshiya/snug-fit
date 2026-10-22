class_name Tutorial
extends Control
## Hands-on first-play tutorial for Fit level 1. It never blocks input: the player
## really drags the pieces while an animated hand shows where each one goes.

signal finished

enum Step { DRAG, NEXT, DONE }

var board: Board
var pal: Dictionary
var step: Step = Step.DRAG
var _t: float = 0.0
var _caption: Label
var _bubble: PanelContainer
var _shown_text: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = pal["ink"]
	sb.set_corner_radius_all(30)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption = UIKit.label("", 26, pal["top"], 600)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size = Vector2(420, 0)
	_bubble.add_child(_caption)
	add_child(_bubble)
	board.placed.connect(func(_i: int) -> void:
		if step == Step.DRAG:
			_go(Step.NEXT)
	)
	board.solved.connect(func() -> void:
		_go(Step.DONE)
		SaveSystem.set_flag("tutorial_done")
		var tw: Tween = create_tween()
		tw.tween_interval(0.6)
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func() -> void:
			finished.emit()
			queue_free()
		)
	)
	_go(Step.DRAG)


func _go(next: Step) -> void:
	step = next
	_t = 0.0
	match step:
		Step.DRAG:
			_say("Drag a piece into the shape")
		Step.NEXT:
			_say("Now fill the rest")
		Step.DONE:
			_say("A snug fit!")


func _say(text: String) -> void:
	if text == _shown_text:
		return
	_shown_text = text
	_caption.text = text
	_bubble.pivot_offset = _bubble.size * 0.5
	_bubble.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(_bubble, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The next piece to show: the first of the solution still in the tray.
func _next() -> Array:
	for pl: Array in board.level.get("solution", []):
		if not board.on_board[int(pl[0])]:
			return pl
	return []


func _process(delta: float) -> void:
	_t += delta
	var top: Vector2 = board.global_position - global_position + Vector2(board.size.x * 0.5, board.origin.y)
	_bubble.position = Vector2(top.x - _bubble.size.x * 0.5, maxf(0.0, top.y - _bubble.size.y - 18.0))
	queue_redraw()


func _draw() -> void:
	if board == null or board.level.is_empty() or step == Step.DONE:
		return
	var pl: Array = _next()
	if pl.is_empty() or board._dragging:
		return
	var origin: Vector2 = board.global_position - global_position
	var i: int = int(pl[0])
	var from: Vector2 = origin + board.tray_center(i)
	var to: Vector2 = origin + board.board_center(i, int(pl[1]), Vector2i(int(pl[2]), int(pl[3])))
	# Where it goes.
	var pulse: float = 0.5 + 0.5 * sin(_t * 5.0)
	var cells: Array[Vector2i] = FitSim.transform(board.pz.pieces[i], int(pl[1]))
	var hset: Dictionary = {}
	for c: Vector2i in cells:
		hset[c] = true
	var bg: Color = (pal["top"] as Color).lerp(pal["bottom"], 0.4)
	BlockStyles._blob(self, hset, origin + board.origin + Vector2(int(pl[2]), int(pl[3])) * board.cs, board.cs, board.cs * 0.04, board.cs * 0.2, BlockStyles.solid(bg, Color(pal["accent"], 0.25 + 0.2 * pulse)))
	# A looping hand: press on the piece, carry it up, let go over its spot.
	var cycle: float = fmod(_t, 2.4) / 2.4
	var press: float = clampf(cycle / 0.15, 0.0, 1.0)
	var move: float = clampf((cycle - 0.18) / 0.5, 0.0, 1.0)
	move = 1.0 - pow(1.0 - move, 3.0)
	var release: float = clampf((cycle - 0.74) / 0.12, 0.0, 1.0)
	var hand: Vector2 = from.lerp(to, move)
	var alpha: float = minf(press, 1.0 - clampf((cycle - 0.88) / 0.1, 0.0, 1.0))
	draw_arc(from, 18.0 + 22.0 * press, 0.0, TAU, 32, Color(pal["accent"], 0.6 * (1.0 - press)), 3.0, true)
	if release > 0.0:
		draw_arc(hand, 16.0 + 30.0 * release, 0.0, TAU, 32, Color(pal["accent"], 0.7 * (1.0 - release)), 3.0, true)
	var s: float = 76.0 * (1.0 - 0.12 * press + 0.12 * release)
	var r: Rect2 = Rect2(hand - Vector2(s * 0.3, s * 0.05), Vector2(s, s))
	draw_texture_rect(UIKit.icon("pointer-filled"), r, false, Color(1, 1, 1, alpha))
	draw_texture_rect(UIKit.icon("pointer"), r, false, Color(pal["ink"], alpha))
