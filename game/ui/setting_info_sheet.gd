extends Overlay
## What a setting does: a little looping demo, a description, and the switch.

const INFO: Dictionary = {
	"lift": ["Lift pieces above finger", "A piece you carry floats a little above your fingertip, so you can see exactly where it will land. Turn it off to hold pieces right under your finger."],
	"haptics": ["Vibration", "Your phone gives a short buzz when you pick up a piece, when it lands, and on button taps. Turn it off to play silently in your hand."],
}

var key: String = "lift"


func build() -> void:
	name = "SettingInfo"
	var info: Array = INFO.get(key, INFO["lift"])
	add_title(str(info[0]))
	var body: VBoxContainer = card_body()
	body.add_theme_constant_override("separation", 16)
	var demo: _Demo = _Demo.new()
	demo.name = "Demo"
	demo.key = key
	demo.pal = pal
	demo.custom_minimum_size = Vector2(0, 300)
	body.add_child(demo)
	var text: Label = UIKit.label(str(info[1]), 23, pal["ink"], 400)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(text)
	var row: HBoxContainer = UIKit.toggle_row(str(info[0]), bool(SaveSystem.get_setting(key, true)), pal, func(on: bool) -> void:
		SaveSystem.set_setting(key, on)
		demo.queue_redraw()
	)
	row.name = "Toggle"
	body.add_child(row)
	var back: Button = UIKit.pill("Back to settings", pal, "soft", Vector2(0, 76), 24)
	back.name = "BackToSettings"
	back.pressed.connect(close)
	body.add_child(back)
	_first_focus = back


## Side-by-side "off" and "on" panels playing the same moment.
class _Demo:
	extends Control
	var key: String
	var pal: Dictionary
	var _t: float = 0.0
	var _buzzed: int = -1

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w: float = (size.x - 20.0) * 0.5
		for i: int in 2:
			var r: Rect2 = Rect2(Vector2(float(i) * (w + 20.0), 0), Vector2(w, size.y))
			var on: bool = i == 1
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = Color(pal["ink"], 0.05)
			sb.set_corner_radius_all(24)
			sb.border_color = Color(pal["accent"], 0.8) if on else Color(pal["ink"], 0.1)
			sb.set_border_width_all(3 if on else 2)
			draw_style_box(sb, r)
			var f: Font = UIKit.font(700)
			var cap: String = "ON" if on else "OFF"
			draw_string(f, r.position + Vector2(18, 34), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(pal["accent"] if on else pal["muted"]))
			if key == "haptics":
				_buzz_panel(r, on)
			else:
				_lift_panel(r, on)

	## A fingertip carrying a piece toward its spot: hidden under the finger, or floating above it.
	func _lift_panel(r: Rect2, on: bool) -> void:
		var cs: float = minf(r.size.x / 6.0, 34.0)
		var slot: Vector2 = r.position + Vector2(r.size.x * 0.5 - cs, 64)
		var well: Dictionary = {Vector2i(0, 0): true, Vector2i(1, 0): true, Vector2i(0, 1): true}
		BlockStyles._blob(self, well, slot, cs, cs * 0.1, cs * 0.2, Color(pal["ink"], 0.1))
		var u: float = fmod(_t, 2.4) / 2.4
		var k: float = 0.5 - 0.5 * cos(clampf(u / 0.7, 0.0, 1.0) * PI)
		var finger: Vector2 = Vector2(r.position.x + r.size.x * 0.5, r.end.y - 40).lerp(slot + Vector2(cs, cs) + Vector2(0, cs * 1.6 if on else 0.0), k)
		var piece_c: Vector2 = finger - Vector2(0, cs * 1.6 if on else 0.0)
		var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
		BlockStyles.draw_piece(self, "soft", cells, piece_c - Vector2(cs, cs), cs, Palette.block_color(pal, 0, false), pal, 0.6)
		var s2: float = 64.0
		var hand: Rect2 = Rect2(finger - Vector2(s2 * 0.3, s2 * 0.05), Vector2(s2, s2))
		draw_texture_rect(UIKit.icon("pointer-filled"), hand, false, Color(1, 1, 1, 0.95))
		draw_texture_rect(UIKit.icon("pointer"), hand, false, pal["ink"])

	## A phone that buzzes as a piece lands, with ripples, when vibration is on.
	func _buzz_panel(r: Rect2, on: bool) -> void:
		var u: float = fmod(_t, 1.4) / 1.4
		var buzz: bool = on and u > 0.5 and u < 0.75
		var c: Vector2 = r.get_center() + Vector2(0, 18)
		var wob: Vector2 = Vector2(sin(_t * 90.0) * 3.0, 0) if buzz else Vector2.ZERO
		var phone: Rect2 = Rect2(c - Vector2(42, 74) + wob, Vector2(84, 148))
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(pal["ink"], 0.08)
		sb.border_color = pal["ink"]
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(16)
		draw_style_box(sb, phone)
		var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]
		BlockStyles.draw_piece(self, "soft", cells, phone.get_center() + Vector2(-16, -36), 16.0, Palette.block_color(pal, 1, false), pal)
		if buzz:
			for k: int in 3:
				var off2: float = 58.0 + 12.0 * float(k)
				var col: Color = Color(pal["accent"], 0.7 - 0.2 * float(k))
				draw_arc(c + Vector2(-off2 + 10.0, 0), 20.0, PI * 0.7, PI * 1.3, 10, col, 3.0, true)
				draw_arc(c + Vector2(off2 - 10.0, 0), 20.0, -PI * 0.3, PI * 0.3, 10, col, 3.0, true)
			var beat: int = int(_t / 1.4)
			if beat != _buzzed:
				_buzzed = beat
				if is_visible_in_tree():
					Haptics.tap(18)
