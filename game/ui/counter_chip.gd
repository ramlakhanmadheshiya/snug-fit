class_name CounterChip
extends Button
## A balance chip: coins, level keys or chapter keys. Counts smoothly to new
## values with a little pop, and opens its own shop card when tapped.

var kind: String = "coins"
var pal: Dictionary
var app: Node
var _shown: float = 0.0
var _value_label: Label
var _row: HBoxContainer


## kind: "coins", "keys" or "chapter_keys".
static func make(chip_kind: String, palette: Dictionary, host: Node) -> CounterChip:
	var c: CounterChip = CounterChip.new()
	c.kind = chip_kind
	c.pal = palette
	c.app = host
	c.name = {"coins": "Coins", "keys": "Keys", "chapter_keys": "ChapterKeys"}[chip_kind]
	return c


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0, 62)
	var fill: Color = UIKit.surface(pal)
	var l: Color = UIKit.lip(pal, fill)
	add_theme_stylebox_override("normal", UIKit.lip_box(fill, l, 22, 5, Vector2(12, 4)))
	add_theme_stylebox_override("hover", UIKit.lip_box(fill.lightened(0.04), l, 22, 5, Vector2(12, 4)))
	add_theme_stylebox_override("pressed", UIKit.lip_box(fill.darkened(0.04), l, 22, 5, Vector2(12, 4), true))
	add_theme_stylebox_override("hover_pressed", UIKit.lip_box(fill.darkened(0.04), l, 22, 5, Vector2(12, 4), true))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row: HBoxContainer = HBoxContainer.new()
	_row = row
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -10
	row.offset_bottom = -4
	add_child(row)
	var ic: _Icon = _Icon.new()
	ic.kind = kind
	ic.pal = pal
	ic.custom_minimum_size = Vector2(36, 36)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	_value_label = UIKit.label("0", 26, pal["ink"], 900)
	_value_label.name = "Value"
	row.add_child(_value_label)
	var plus: Label = UIKit.badge("+", pal, Color("#3DBE7A"))
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(plus)
	_shown = float(_value())
	_set_text(_shown)
	UIKit.add_press_feel(self)
	pressed.connect(_open)
	match kind:
		"coins":
			Events.coins_changed.connect(_on_changed)
		"chapter_keys":
			Events.chapter_keys_changed.connect(_on_changed)
		_:
			Events.keys_changed.connect(_on_changed)


func _value() -> int:
	match kind:
		"coins":
			return SaveSystem.coins()
		"chapter_keys":
			return SaveSystem.chapter_keys()
	return SaveSystem.keys()


func _set_text(v: float) -> void:
	_value_label.text = str(int(round(v)))
	# A Button doesn't grow with its children, so size the chip to its row.
	custom_minimum_size.x = _row.get_combined_minimum_size().x + 24.0


func _open() -> void:
	match kind:
		"coins":
			app.open_coins()
		"chapter_keys":
			app.open_chapter_keys()
		_:
			app.open_keys()


func _on_changed(total: int) -> void:
	if not is_inside_tree():
		return
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_method(func(v: float) -> void:
		_shown = v
		_set_text(v), _shown, float(total), 0.6)
	pivot_offset = size * 0.5
	scale = Vector2(1.12, 1.12)
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The chip's little picture: a gold coin, a gold key, or a chapter key.
class _Icon:
	extends Control
	var kind: String
	var pal: Dictionary

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.46
		if kind == "coins":
			UIKit.draw_coin(self, c, r)
			return
		var col: Color = Color("#F5B544") if kind == "keys" else Color(pal["accent"])
		draw_circle(c, r, Color(col, 0.22), true, -1.0, true)
		draw_texture_rect(UIKit.icon("key-round" if kind == "keys" else "book-key"), Rect2(c - Vector2(r, r) * 0.72, Vector2(r, r) * 1.44), false, col.darkened(0.15))
