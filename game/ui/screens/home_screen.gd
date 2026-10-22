extends Screen
## Home: the wordmark, a board quietly filling shapes by itself, one big Play
## block that says where it picks up, and Chapters. Coins, keys, the shop and
## settings sit along the top.

var _play: Button
var _board: Board


func _ready() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	var top: HBoxContainer = HBoxContainer.new()
	top.custom_minimum_size = Vector2(0, 84)
	top.add_theme_constant_override("separation", 12)
	var settings: Button = UIKit.icon_button("settings", pal, 68.0)
	settings.name = "SettingsButton"
	settings.pressed.connect(func() -> void: app.open_settings(false))
	top.add_child(settings)
	var fill: Control = Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	var keys: CounterChip = CounterChip.make("keys", pal, app)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(keys)
	var coins: CounterChip = CounterChip.make("coins", pal, app)
	coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(coins)
	var shop: Button = UIKit.icon_button("shopping-bag", pal, 68.0)
	shop.name = "Shop"
	shop.pressed.connect(func() -> void: app.open_shop())
	top.add_child(shop)
	col.add_child(top)

	# The wordmark: bold and round, with the tagline in the accent colour.
	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.add_theme_constant_override("separation", -6)
	var title: Label = UIKit.label("Snug Fit", 96, pal["ink"], 900)
	title.name = "Title"
	title_box.add_child(title)
	title_box.add_child(UIKit.caption("A calm shape puzzle", {"muted": pal["accent"]}, 20, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(title_box)

	# A live demo on a raised card.
	var card: PanelContainer = PanelContainer.new()
	card.name = "DemoCard"
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 320)
	var surface: Color = UIKit.surface(pal)
	card.add_theme_stylebox_override("panel", UIKit.lip_box(surface, UIKit.lip(pal, surface), 40, 8, Vector2(22, 22)))
	col.add_child(card)
	_board = Board.new()
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.bg_color = surface
	card.add_child(_board)
	_board.play_demo(demo_levels(), pal)

	# Play: big, warm, and it names the next level.
	var target: Dictionary = Levels.continue_target()
	var cid: String = str(target["chapter"])
	var lv: Dictionary = Levels.level(cid, int(target["index"]))
	_play = UIKit.pill("", pal, "primary", Vector2(0, 124), 30)
	_play.name = "Play"
	_play.pressed.connect(func() -> void: app.open_game(cid, int(target["index"])))
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 28
	row.offset_right = -28
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.add_child(row)
	var disc: PanelContainer = PanelContainer.new()
	var dsb: StyleBoxFlat = StyleBoxFlat.new()
	dsb.bg_color = Color(1, 1, 1, 0.22)
	dsb.set_corner_radius_all(30)
	disc.add_theme_stylebox_override("panel", dsb)
	disc.custom_minimum_size = Vector2(66, 66)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic: TextureRect = UIKit.icon_rect("play", 30.0, UIKit.on_accent(pal))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.add_child(ic)
	row.add_child(disc)
	var text: VBoxContainer = VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", -4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(UIKit.label("Play", 44, UIKit.on_accent(pal), 900, HORIZONTAL_ALIGNMENT_LEFT))
	var where: String = "%s  ·  Level %d" % [str(Palette.get_palette(cid)["name"]), int(target["index"]) + 1]
	if not lv.is_empty():
		where += "  ·  %s" % str(lv.get("name", ""))
	var sub: Label = UIKit.label(where, 21, Color(UIKit.on_accent(pal), 0.85), 700, HORIZONTAL_ALIGNMENT_LEFT)
	sub.name = "Continue"
	text.add_child(sub)
	col.add_child(_play)

	var chapters: Button = UIKit.pill("", pal, "soft", Vector2(0, 92), 28)
	chapters.name = "Chapters"
	chapters.pressed.connect(func() -> void: app.open_chapters())
	var crow: HBoxContainer = HBoxContainer.new()
	crow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crow.offset_left = 28
	crow.offset_right = -28
	crow.offset_bottom = -6
	crow.add_theme_constant_override("separation", 16)
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chapters.add_child(crow)
	crow.add_child(UIKit.icon_rect("layout-grid", 30.0, pal["ink"]))
	var cl: Label = UIKit.label("Chapters", 30, pal["ink"], 800, HORIZONTAL_ALIGNMENT_LEFT)
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crow.add_child(cl)
	var stars: HBoxContainer = HBoxContainer.new()
	stars.add_theme_constant_override("separation", 6)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.add_child(UIKit.icon_rect("star-filled", 26.0, Color("#F2B233")))
	stars.add_child(UIKit.label("%d / %d" % [SaveSystem.total_stars(), Levels.total_levels() * 3], 24, pal["muted"], 800))
	crow.add_child(stars)
	col.add_child(chapters)

	_play.focus_neighbor_bottom = chapters.get_path()
	chapters.focus_neighbor_top = _play.get_path()
	# A slow breath on Play, until it's touched.
	(func() -> void:
		_play.pivot_offset = _play.size * 0.5
		var tw: Tween = create_tween().set_loops()
		tw.tween_property(_play, "scale", Vector2(1.025, 1.025), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_play, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_play.button_down.connect(func() -> void: tw.kill())
	).call_deferred()


## A few friendly shapes from the first chapters, for the demo card.
static func demo_levels() -> Array:
	var out: Array = []
	for pick: Array in [["ch1", 14], ["ch2", 18], ["ch1", 19], ["ch3", 10], ["ch1", 24]]:
		var lv: Dictionary = Levels.level(pick[0], pick[1])
		if not lv.is_empty():
			out.append(lv)
	return out


func focus_default() -> void:
	if _play != null:
		_play.grab_focus()
