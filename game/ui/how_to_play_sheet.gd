extends Overlay
## The rules in five short lines, plus a way to replay the hands-on tutorial.

const STEPS: Array = [
	["1", "Drag the pieces from the tray into the shape."],
	["2", "Cover every cell. Pieces can't overlap or stick out."],
	["3", "Drag a piece off the shape to take it back."],
	["4", "Where pieces turn, tap one to turn it. Turning in the tray is free."],
	["5", "Every drop on the shape is a move. Par is one move per piece."],
	["6", "Near par ★★★  ·  a little over ★★  ·  any finish ★. Restart is a fresh start."],
]


func build() -> void:
	name = "HowToPlay"
	add_title("How to play")
	var body: VBoxContainer = card_body()
	body.add_theme_constant_override("separation", 14)
	for step: Array in STEPS:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var num: Label = UIKit.label(step[0], 24, pal["top"], 700)
		num.custom_minimum_size = Vector2(44, 44)
		var dot: StyleBoxFlat = StyleBoxFlat.new()
		dot.bg_color = pal["accent"]
		dot.set_corner_radius_all(22)
		num.add_theme_stylebox_override("normal", dot)
		num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(num)
		var text: Label = UIKit.label(step[1], 25, pal["ink"], 500, HORIZONTAL_ALIGNMENT_LEFT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		body.add_child(row)
	var tip: Label = UIKit.label("Stuck? The bulb outlines where the next piece goes.", 21, pal["muted"], 400)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(tip)
	add_gap(6)
	var replay: Button = UIKit.pill("Replay tutorial", pal, "primary", Vector2(0, 80), 26)
	replay.name = "ReplayTutorial"
	replay.pressed.connect(func() -> void: app.replay_tutorial())
	body.add_child(replay)
	_first_focus = replay
