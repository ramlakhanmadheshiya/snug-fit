extends Screen
## Chapters as a two-column grid of tiles, each painted in its chapter's colours
## with its idea playing out, its progress and stars. A locked tile offers a
## chapter key.

var _first: Control


func _ready() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	col.add_child(make_header("Chapters", func() -> void: app.open_home(), _chapter_key_chip()))
	var total: HBoxContainer = HBoxContainer.new()
	total.name = "TotalStars"
	total.alignment = BoxContainer.ALIGNMENT_CENTER
	total.add_theme_constant_override("separation", 8)
	total.add_child(UIKit.icon_rect("star-filled", 26.0, Color("#F2B233")))
	total.add_child(UIKit.label("%d of %d stars" % [SaveSystem.total_stars(), Levels.total_levels() * 3], 22, pal["muted"], 800))
	col.add_child(total)
	var scroll: TouchScroll = TouchScroll.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	scroll.set_content(list)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	list.add_child(grid)
	for i: int in Levels.chapters.size():
		var tile: Button = _tile(Levels.chapters[i], i)
		grid.add_child(tile)
		if _first == null:
			_first = tile
		tile.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.tween_interval(0.05 * float(i))
		tw.tween_property(tile, "modulate:a", 1.0, 0.3)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	list.add_child(spacer)


func _chapter_key_chip() -> Control:
	var chip: CounterChip = CounterChip.make("chapter_keys", pal, app)
	chip.custom_minimum_size = Vector2(0, 62)
	return chip


func _tile(c: Dictionary, index: int) -> Button:
	var id: String = str(c["id"])
	var cp: Dictionary = Palette.get_palette(id)
	var open: bool = Levels.chapter_open(id)
	var b: Button = Button.new()
	b.name = "Chapter_" + id
	b.custom_minimum_size = Vector2(0, 330)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	var fill: Color = (cp["top"] as Color).lerp(cp["bottom"], 0.5)
	var lip: Color = UIKit.lip(cp, fill)
	b.add_theme_stylebox_override("normal", UIKit.lip_box(fill, lip, 32, 8))
	b.add_theme_stylebox_override("hover", UIKit.lip_box(fill.lightened(0.03), lip, 32, 8))
	b.add_theme_stylebox_override("pressed", UIKit.lip_box(fill.darkened(0.03), lip, 32, 8, Vector2(26, 10), true))
	b.add_theme_stylebox_override("hover_pressed", UIKit.lip_box(fill.darkened(0.03), lip, 32, 8, Vector2(26, 10), true))
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.set_corner_radius_all(36)
	focus.border_color = pal["accent"]
	focus.set_border_width_all(4)
	focus.expand_margin_left = 6
	focus.expand_margin_right = 6
	focus.expand_margin_top = 6
	focus.expand_margin_bottom = 6
	b.add_theme_stylebox_override("focus", focus)
	UIKit.add_press_feel(b)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 24)
	b.add_child(margin)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)
	var art: ChapterArt = ChapterArt.new()
	art.name = "Art"
	art.chapter_id = id
	art.pal = cp
	art.bg = fill
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(art)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var name_l: Label = UIKit.label(str(cp["name"]), 36, cp["ink"], 900, HORIZONTAL_ALIGNMENT_LEFT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	head.add_child(UIKit.label("%d" % (index + 1), 22, cp["muted"], 900))
	var tag: Label = UIKit.label(str(cp["tagline"]), 19, cp["muted"], 700, HORIZONTAL_ALIGNMENT_LEFT)
	tag.clip_text = true
	v.add_child(tag)
	var total: int = Levels.level_count(id)
	if open:
		var bar: _Bar = _Bar.new()
		bar.pal = cp
		bar.k = float(Levels.cleared_in(id)) / float(maxi(1, total))
		bar.custom_minimum_size = Vector2(0, 12)
		v.add_child(bar)
		var stars: HBoxContainer = HBoxContainer.new()
		stars.add_theme_constant_override("separation", 6)
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars.add_child(UIKit.icon_rect("star-filled", 20.0, Color("#F2B233")))
		stars.add_child(UIKit.label("%d/%d" % [Levels.stars_in(id), total * 3], 19, cp["ink"], 800, HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(stars)
		b.pressed.connect(func() -> void: app.open_levels(id))
	else:
		art.modulate.a = 0.4
		art.playing = false
		var lock: HBoxContainer = HBoxContainer.new()
		lock.add_theme_constant_override("separation", 8)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.add_child(UIKit.icon_rect("lock", 22.0, cp["ink"]))
		var prev: String = str(Levels.chapters[index - 1]["id"])
		var left: int = Levels.CHAPTER_GATE - Levels.cleared_in(prev)
		lock.add_child(UIKit.label("%d more in %s" % [left, str(Palette.get_palette(prev)["name"])], 18, cp["muted"], 800, HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(lock)
		b.pressed.connect(func() -> void: app.open_chapter_keys(id))
	return b


func focus_default() -> void:
	if _first != null:
		_first.grab_focus()


func handle_back() -> bool:
	app.open_home()
	return true


## How much of the chapter is cleared.
class _Bar:
	extends Control
	var pal: Dictionary
	var k: float = 0.0

	func _draw() -> void:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_corner_radius_all(int(size.y * 0.5))
		sb.bg_color = Color(pal["ink"], 0.1)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if k > 0.0:
			sb.bg_color = pal["accent"]
			draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * k), size.y)))
