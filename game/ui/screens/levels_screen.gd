extends Screen
## One chapter as a gallery of its shapes. Cleared levels show the shape filled
## in, with their stars; open ones show the empty shape waiting; locked ones are
## faint, with a lock (a level key opens any of them).

var chapter_id: String = "ch1"
var _focus: Control
var _scroll: TouchScroll
var _tiles: Array = []


func music_track() -> String:
	return chapter_id


func _ready() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.add_child(make_header(str(pal["name"]), func() -> void: app.open_chapters(), CounterChip.make("keys", pal, app)))
	col.add_child(_summary())
	var scroll: TouchScroll = TouchScroll.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_scroll = scroll
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	scroll.set_content(list)
	var next: Dictionary = Levels.continue_target()
	var grid: GridContainer = GridContainer.new()
	grid.name = "Grid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	list.add_child(grid)
	for i: int in Levels.level_count(chapter_id):
		var lv: Dictionary = Levels.level(chapter_id, i)
		var tile: _Tile = _Tile.new()
		tile.name = "Level_%d" % (i + 1)
		tile.pal = pal
		tile.level = lv
		tile.number = i + 1
		tile.current = str(next["chapter"]) == chapter_id and int(next["index"]) == i
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.pressed.connect(_on_tile.bind(i))
		grid.add_child(tile)
		_tiles.append(tile)
		if tile.current or (_focus == null and Levels.level_open(chapter_id, i)):
			_focus = tile
		tile.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.tween_interval(0.012 * float(i))
		tw.tween_property(tile, "modulate:a", 1.0, 0.22)
	_refresh()
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	list.add_child(spacer)
	Events.keys_changed.connect(func(_c: int) -> void: _refresh())
	# Bring the current level into view.
	(func() -> void:
		if _focus != null and _focus.is_inside_tree():
			var bottom: float = _focus.global_position.y - _scroll.content.global_position.y + _focus.size.y + 24.0
			if bottom > _scroll.size.y:
				_scroll.scroll_to(bottom - _scroll.size.y * 0.8)
	).call_deferred()


## The chapter's idea, how far along it is, and its stars.
func _summary() -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.name = "Summary"
	var fill: Color = UIKit.surface(pal)
	card.add_theme_stylebox_override("panel", UIKit.lip_box(fill, UIKit.lip(pal, fill), 28, 6, Vector2(24, 14)))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var art: ChapterArt = ChapterArt.new()
	art.chapter_id = chapter_id
	art.pal = pal
	art.bg = fill
	art.custom_minimum_size = Vector2(170, 86)
	row.add_child(art)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	text.add_child(UIKit.label(str(pal["tagline"]), 26, pal["ink"], 800, HORIZONTAL_ALIGNMENT_LEFT))
	var total: int = Levels.level_count(chapter_id)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.add_child(UIKit.icon_rect("star-filled", 22.0, Color("#F2B233")))
	line.add_child(UIKit.label("%d/%d  ·  %d of %d filled" % [Levels.stars_in(chapter_id), total * 3, Levels.cleared_in(chapter_id), total], 20, pal["muted"], 700, HORIZONTAL_ALIGNMENT_LEFT))
	text.add_child(line)
	return card


func _on_tile(i: int) -> void:
	if Levels.level_open(chapter_id, i):
		app.open_game(chapter_id, i)
	else:
		AudioManager.play_ui("ui_back")
		app.open_locked(chapter_id, i)


func _refresh() -> void:
	for i: int in _tiles.size():
		var t: _Tile = _tiles[i]
		var id: String = str(t.level["id"])
		t.open = Levels.level_open(chapter_id, i)
		t.stars = SaveSystem.stars_for(id)
		t.keyed = SaveSystem.key_unlocked(id) and not SaveSystem.is_cleared(id)
		t.queue_redraw()


func focus_default() -> void:
	if _focus != null:
		_focus.grab_focus()


func handle_back() -> bool:
	app.open_chapters()
	return true


## One level: its shape (filled in once cleared), number, stars or lock.
class _Tile:
	extends Button
	var pal: Dictionary
	var level: Dictionary
	var number: int = 1
	var stars: int = 0
	var open: bool = false
	var current: bool = false
	var keyed: bool = false
	var _t: float = 0.0
	var _plate: Dictionary = {}
	var _size: Vector2i = Vector2i.ONE

	func _init() -> void:
		custom_minimum_size = Vector2(0, 238)
		focus_mode = Control.FOCUS_ALL
		flat = true
		var empty: StyleBoxEmpty = StyleBoxEmpty.new()
		for key: String in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(key, empty)

	func _ready() -> void:
		UIKit.add_press_feel(self)
		var rows: Array = level.get("shape", [])
		_size = Vector2i(str(rows[0]).length(), rows.size())
		for y: int in rows.size():
			for x: int in str(rows[y]).length():
				if str(rows[y])[x] == "#":
					_plate[Vector2i(x, y)] = true

	func _process(delta: float) -> void:
		_t += delta
		if current or has_focus():
			queue_redraw()

	func _draw() -> void:
		var ink: Color = pal["ink"]
		var fill: Color = UIKit.surface(pal) if open else UIKit.surface(pal).lerp(pal["top"], 0.55)
		var box: Rect2 = Rect2(Vector2.ZERO, size)
		draw_style_box(UIKit.lip_box(fill, UIKit.lip(pal, fill), 26, 6), box)
		if current or has_focus():
			var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
			var ring: StyleBoxFlat = StyleBoxFlat.new()
			ring.bg_color = Color.TRANSPARENT
			ring.set_corner_radius_all(30)
			ring.border_color = Color(pal["accent"], 0.9 - 0.5 * pulse if current else 0.9)
			ring.set_border_width_all(4)
			draw_style_box(ring, box.grow(3.0 + 3.0 * pulse))
		# The shape, fitted into the top of the tile.
		var area: Rect2 = Rect2(Vector2(18, 16), Vector2(size.x - 36, size.y - 84))
		var cs: float = floorf(minf(area.size.x / float(_size.x), area.size.y / float(_size.y)))
		var origin: Vector2 = area.position + (area.size - Vector2(_size) * cs) * 0.5
		var cleared: bool = stars > 0
		var plate_a: float = 1.0 if open else 0.5
		BlockStyles._blob(self, _plate, origin, cs, -cs * 0.1, cs * 0.3, Color(BlockStyles.solid(fill, Color(ink, 0.08)), plate_a))
		if cleared:
			var paint: bool = not (level.get("marks", []) as Array).is_empty()
			var pieces: Array = level["pieces"]
			for pl: Array in level.get("solution", []):
				var pc: Dictionary = pieces[int(pl[0])]
				var cells: Array[Vector2i] = FitSim.transform(FitSim.to_cells(pc["cells"]), int(pl[1]))
				BlockStyles.draw_piece(self, "soft", cells, origin + Vector2(int(pl[2]), int(pl[3])) * cs, cs, Palette.block_color(pal, int(pc.get("color", 0)), paint), pal)
		# Number and stars (or the lock) along the bottom.
		var f: Font = UIKit.font(900)
		var num: String = str(number)
		var base_y: float = size.y - 30.0
		if not open:
			draw_string(f, Vector2(20, base_y + 8), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(ink, 0.35))
			draw_texture_rect(UIKit.icon("lock"), Rect2(Vector2(size.x - 50, base_y - 16), Vector2(28, 28)), false, Color(ink, 0.4))
			return
		draw_string(f, Vector2(20, base_y + 8), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ink)
		if keyed:
			draw_texture_rect(UIKit.icon("key-round"), Rect2(Vector2(size.x - 50, base_y - 16), Vector2(28, 28)), false, pal["accent"])
			return
		for k: int in 3:
			var s: float = 24.0
			var c: Vector2 = Vector2(size.x - 34.0 - float(2 - k) * 27.0, base_y - 4.0)
			var col: Color = Color("#F2B233") if k < stars else Color(ink, 0.16)
			draw_texture_rect(UIKit.icon("star-filled"), Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, col)
