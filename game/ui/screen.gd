class_name Screen
extends Control
## Base for full-screen pages. The app sets `app` and `pal` before adding it.

var app: Node
var pal: Dictionary = Palette.get_palette("ch1")


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


## Which music track and palette this screen wants.
func music_track() -> String:
	return "menu"


## Return true if the screen consumed the back action.
func handle_back() -> bool:
	return false


## True while a level is being played (settings then hide progress reset).
func in_game() -> bool:
	return false


## Called after the screen is visible; give keyboard/gamepad focus here.
func focus_default() -> void:
	pass


## Standard header: back button, centred title and a settings button (or any
## control) on the right.
func make_header(title: String, on_back: Callable, right: Control = null) -> Control:
	if right == null:
		right = UIKit.icon_button("settings", pal, 68.0)
		right.name = "SettingsButton"
		(right as Button).pressed.connect(func() -> void: app.open_settings(in_game()))
	var bar: Control = Control.new()
	bar.custom_minimum_size = Vector2(0, 88)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t: Label = UIKit.label(title, 34, pal["ink"], 900)
	t.name = "Title"
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(t)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(row)
	var back: Button = UIKit.icon_button("chevron-left", pal, 68.0)
	back.name = "Back"
	back.pressed.connect(on_back)
	row.add_child(back)
	var fill: Control = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fill)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	return bar
