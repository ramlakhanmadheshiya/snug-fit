class_name ChapterIntro
extends Control
## The first time a chapter's opening level is played: a floating card explains the
## chapter's new idea with a live diagram, then the level's new elements are
## spotlit with a short caption until the player touches a piece.

signal done

const LESSONS: Dictionary = {
	"ch1": ["Fill the shape", "Drag the pieces into the shape until every cell is covered. No overlaps, nothing outside."],
	"ch2": ["Turn", "Tap a piece to turn it a quarter. Turn it in the tray for free; turning it on the shape counts as a move."],
	"ch3": ["Paint", "A coloured cell only takes the piece of the same colour. Start with the colours; they tell you where pieces go."],
	"ch4": ["Pegs", "Every piece must cover exactly one peg. Never two, never none."],
	"ch5": ["Spare", "There's one piece too many. Fill the shape and one piece stays in the tray. Which one?"],
	"ch6": ["Flip", "Pieces can be turned over now. Touch a piece, then press Flip. Tap still turns it."],
	"ch7": ["Mosaic", "Everything at once: turning, flipping, colours, pegs and spare pieces, mixed together."],
}
const CAPTIONS: Dictionary = {
	"ch2": "Tap a piece to turn it",
	"ch3": "Match the coloured cells",
	"ch4": "One peg under every piece",
	"ch5": "One piece won't be needed",
	"ch6": "Touch a piece, then Flip",
	"ch7": "Every idea, together",
}

var chapter_id: String = "ch2"
var pal: Dictionary
var board: Board
var _card_root: Control
var _bubble: PanelContainer
var _spotlight: bool = false
var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_card()
	board.touched.connect(func() -> void:
		if _spotlight:
			_finish()
	)


func _build_card() -> void:
	_card_root = Control.new()
	_card_root.add_to_group("modal")
	_card_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card_root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(pal["bottom"], 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_root.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.card_style(pal))
	panel.custom_minimum_size = Vector2(580, 0)
	center.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var lesson: Array = LESSONS.get(chapter_id, LESSONS["ch1"])
	col.add_child(UIKit.caption("New in %s" % pal["name"], {"muted": pal["accent"]}, 18, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.label(str(lesson[0]), 46, pal["ink"], 900))
	var art: ChapterArt = ChapterArt.new()
	art.bg = UIKit.card_style(pal).bg_color
	art.chapter_id = chapter_id
	art.pal = pal
	art.custom_minimum_size = Vector2(0, 230)
	col.add_child(art)
	var text: Label = UIKit.label(str(lesson[1]), 25, pal["ink"], 400)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	var ok: Button = UIKit.pill("Got it", pal, "primary", Vector2(0, 88), 30)
	ok.name = "GotIt"
	ok.pressed.connect(dismiss)
	col.add_child(ok)
	panel.modulate.a = 0.0
	(func() -> void:
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(0.9, 0.9)
		var tw: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "modulate:a", 1.0, 0.25)
		tw.tween_property(panel, "scale", Vector2.ONE, 0.4)
	).call_deferred()
	ok.grab_focus.call_deferred()


## Closes the card and spotlights what's new on the shape.
func dismiss() -> void:
	if _card_root == null:
		_finish()
		return
	var root: Control = _card_root
	_card_root = null
	var tw: Tween = create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(root.queue_free)
	_spotlight = true
	_bubble = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = pal["ink"]
	sb.set_corner_radius_all(30)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(UIKit.label(str(CAPTIONS.get(chapter_id, "Fill the shape")), 24, pal["top"], 600))
	add_child(_bubble)
	done.emit()


func _finish() -> void:
	_spotlight = false
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	if _bubble != null:
		var top: Vector2 = board.global_position - global_position + Vector2(board.size.x * 0.5, board.origin.y)
		_bubble.position = Vector2(top.x - _bubble.size.x * 0.5, maxf(0.0, top.y - _bubble.size.y - 14.0))
	if _spotlight:
		queue_redraw()


## The cells to ring: coloured cells and pegs.
func _spots() -> Array:
	var out: Array = []
	for m: Array in board.level.get("marks", []):
		out.append(Vector2i(int(m[0]), int(m[1])))
	for p: Array in board.level.get("pegs", []):
		out.append(Vector2i(int(p[0]), int(p[1])))
	return out


func _draw() -> void:
	if not _spotlight or board == null:
		return
	var origin: Vector2 = board.global_position - global_position
	var pulse: float = 0.5 + 0.5 * sin(_t * 5.0)
	for c: Vector2i in _spots():
		var p: Vector2 = origin + board.cell_center(c)
		var r: float = board.cs * (0.62 + 0.1 * pulse)
		draw_arc(p, r, 0.0, TAU, 40, Color(pal["accent"], 0.45 + 0.4 * pulse), 4.0, true)
