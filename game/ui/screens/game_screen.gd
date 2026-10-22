extends Screen
## One level: fill the shape with the pieces in the tray. Every drop on the shape
## is a move; finishing within par + a little earns ★★★ (a hint caps it at ★★).
## Restart is a fresh start with all three stars on offer again.

const TIPS: Dictionary = {
	"ch1_02": "Every drop is a move  ·  few moves earn ★★★",
	"ch1_03": "Drag a piece off the shape to take it back",
}
## Shown the first time a chapter's levels use something new.
const NEW_THINGS: Dictionary = {
	"turn": "From here on, tap a piece to turn it",
	"flip": "Flip turns a piece over",
	"paint": "Coloured cells take the piece of their colour",
	"pegs": "Every piece covers exactly one peg",
	"spare": "One piece is left over",
}
const TITLES: Array = ["", "Filled", "Nicely done", "Snug fit"]
const WIN_DB: float = -8.0
const STAR_DB: float = -7.0

var chapter_id: String = "ch1"
var index: int = 0
var level: Dictionary = {}

var board: Board
var _hud: _Hud
var _hint_btn: Button
var _hint_badge: Label
var _flip_btn: Button
var _toast: Label
var _toast_tween: Tween
var _sheet: Control
var _done: bool = false
var _sheet_focus: Control
var _hinted: bool = false
var _stars: int = 0
var _intro: Control
var _told_still: bool = false
var _earned: int = 0
var _bonus: int = 0


func music_track() -> String:
	return chapter_id


func in_game() -> bool:
	return true


func _ready() -> void:
	level = Levels.level(chapter_id, index)
	SaveSystem.set_last_played(chapter_id, index)
	var lid: String = str(level.get("id", ""))
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	var header: Control = make_header("", func() -> void: app.open_levels(chapter_id))
	var names: VBoxContainer = VBoxContainer.new()
	names.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -6)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(UIKit.caption("%s  ·  %d" % [pal["name"], index + 1], {"muted": pal["accent"]}, 17, HORIZONTAL_ALIGNMENT_CENTER))
	var shape_name: Label = UIKit.label(str(level.get("name", "")), 34, pal["ink"], 900)
	shape_name.name = "ShapeName"
	names.add_child(shape_name)
	header.add_child(names)
	header.move_child(names, 0)
	col.add_child(header)

	# MOVES / STARS strip. Messages show in this same strip, above the shape,
	# so they never cover the playing area.
	var strip: Control = Control.new()
	strip.name = "Strip"
	strip.custom_minimum_size = Vector2(0, 76)
	col.add_child(strip)
	_hud = _Hud.new()
	_hud.name = "Hud"
	_hud.pal = pal
	_hud.par = int(level.get("par", 0))
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip.add_child(_hud)

	var stage: Control = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(stage)
	board = Board.new()
	board.name = "Board"
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(board)
	board.setup(level, pal)
	board.placed.connect(func(_i: int) -> void: _refresh())
	board.rejected.connect(_on_rejected)
	board.solved.connect(_on_solved)
	board.touched.connect(func() -> void: _hide_toast())

	_toast = UIKit.label("", 24, pal["ink"], 500)
	_toast.name = "Toast"
	_toast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.modulate.a = 0.0
	strip.add_child(_toast)

	var bar: HBoxContainer = HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 22)
	bar.custom_minimum_size = Vector2(0, 124)
	col.add_child(bar)
	bar.add_child(_tool("layout-grid", "LEVELS", "LevelsButton", func() -> void: app.open_levels(chapter_id)))
	bar.add_child(_tool("rotate-ccw", "RESTART", "Restart", _restart))
	if board.can_flip():
		var flip: Control = _tool("flip-horizontal-2", "FLIP", "Flip", func() -> void:
			if board.selected < 0:
				_show_toast("Touch a piece, then flip it", 2.0)
			board.flip_selected()
			_refresh()
		)
		_flip_btn = flip.get_node("Flip")
		_flip_btn.tooltip_text = "Flip the selected piece"
		bar.add_child(flip)
	var hint_box: Control = _tool("lightbulb", "HINT", "Hint", _hint, true)
	_hint_btn = hint_box.get_node("Hint")
	_hint_badge = UIKit.badge("", pal)
	_hint_badge.name = "HintPrice"
	_hint_badge.position = Vector2(58, -10)
	_hint_btn.add_child(_hint_badge)
	bar.add_child(hint_box)

	_refresh()
	if lid == "ch1_01" and not SaveSystem.flag("tutorial_done"):
		var tut: Tutorial = Tutorial.new()
		tut.name = "Tutorial"
		tut.board = board
		tut.pal = pal
		stage.add_child(tut)
		return
	if bool(level.get("intro", false)) and not SaveSystem.flag("intro_" + chapter_id):
		_show_intro(stage)
		return
	var tip: String = str(TIPS.get(lid, ""))
	if tip.is_empty():
		tip = _new_thing_tip()
	if not tip.is_empty():
		_show_toast(tip, 4.0)


## Chapter opener: a card that explains the new idea with a live demo, then the
## level itself with the first piece's spot outlined once.
func _show_intro(stage: Control) -> void:
	var intro: ChapterIntro = ChapterIntro.new()
	intro.name = "ChapterIntro"
	intro.chapter_id = chapter_id
	intro.pal = pal
	intro.board = board
	intro.done.connect(func() -> void:
		SaveSystem.set_flag("intro_" + chapter_id)
		var sol: Array = level.get("solution", [])
		if not sol.is_empty():
			board.show_hint(sol[0])
	)
	add_child(intro)
	_intro = intro


## A tip the first time this chapter shows something it hasn't used yet
## (Paint pieces that start turning, for example).
func _new_thing_tip() -> String:
	var seen: Dictionary = {}
	for i: int in index:
		for f: String in features(Levels.level(chapter_id, i)):
			seen[f] = true
	for f: String in features(level):
		if index > 0 and not seen.has(f) and NEW_THINGS.has(f) and not SaveSystem.flag("tip_%s_%s" % [chapter_id, f]):
			SaveSystem.set_flag("tip_%s_%s" % [chapter_id, f])
			return str(NEW_THINGS[f])
	return ""


static func features(lv: Dictionary) -> Array:
	var out: Array = []
	if bool(lv.get("flip", false)):
		out.append("flip")
	elif bool(lv.get("turn", false)):
		out.append("turn")
	if not (lv.get("marks", []) as Array).is_empty():
		out.append("paint")
	if not (lv.get("pegs", []) as Array).is_empty():
		out.append("pegs")
	if lv.has("spare"):
		out.append("spare")
	return out


func focus_default() -> void:
	if _sheet != null and is_instance_valid(_sheet) and _sheet_focus != null:
		_sheet_focus.grab_focus()
	else:
		_hint_btn.grab_focus()


## Stars still on offer if the level were finished with the next move.
func stars_now() -> int:
	return FitSim.stars_for(level, maxi(board.moves, int(level.get("par", 0))), _hinted)


func _refresh() -> void:
	_hud.set_state(board.moves, stars_now())
	var free: int = SaveSystem.free_hints_left()
	_hint_badge.text = "FREE" if free > 0 else "%d" % Economy.HINT_COST
	(_hint_badge.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = Color("#3DBE7A") if free > 0 else Color("#E9A23B")


## A square tool button with its name under it.
func _tool(icon_name: String, caption: String, node_name: String, cb: Callable, accent: bool = false) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var b: Button = UIKit.icon_button(icon_name, pal, 86.0 if accent else 80.0)
	b.name = node_name
	if accent:
		var fill: Color = pal["accent"]
		var l: Color = UIKit.lip(pal, fill)
		b.add_theme_stylebox_override("normal", UIKit.lip_box(fill, l, 28, 6, Vector2(23, 21)))
		b.add_theme_stylebox_override("hover", UIKit.lip_box(fill.lightened(0.04), l, 28, 6, Vector2(23, 21)))
		b.add_theme_stylebox_override("pressed", UIKit.lip_box(fill.darkened(0.04), l, 28, 6, Vector2(23, 21), true))
		b.add_theme_stylebox_override("hover_pressed", UIKit.lip_box(fill.darkened(0.04), l, 28, 6, Vector2(23, 21), true))
		for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
			b.add_theme_color_override(key, UIKit.on_accent(pal))
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.label(caption, 15, pal["muted"], 900))
	return box


func _on_rejected(reason: String) -> void:
	if reason == "still":
		if not _told_still:
			_told_still = true
			_show_toast("These pieces don't turn  ·  drag them in as they are", 2.6)
		return
	_show_toast(str(FitSim.REASONS.get(reason, "")), 1.8)


func _on_solved() -> void:
	var lid: String = str(level["id"])
	_done = true
	board.locked = true
	_stars = FitSim.stars_for(level, board.moves, _hinted)
	_earned = SaveSystem.record_level(lid, _stars, board.moves)
	_bonus = SaveSystem.reward_chapter(chapter_id)
	Events.level_completed.emit(lid, _stars)
	_refresh()
	AudioManager.play("win", 1.0, WIN_DB)
	await get_tree().create_timer(1.15).timeout
	if is_inside_tree():
		_show_result()


func _pulse(c: Control) -> void:
	var tw: Tween = c.create_tween().set_loops(3)
	tw.tween_property(c, "scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)


## A fresh start: every piece back in the tray, all three stars on offer.
func _restart() -> void:
	_close_sheet()
	var fresh: bool = board.moves > 0 or _hinted
	_done = false
	_hinted = false
	board.locked = false
	board.reset()
	_refresh()
	if fresh:
		_show_toast("Fresh start  ·  all three stars on offer", 1.8)


func _hint() -> void:
	if _done:
		return
	if board.has_hint():
		_show_toast("The outline shows where that piece goes", 2.0)
		return
	if SaveSystem.free_hints_left() > 0 or SaveSystem.coins() >= Economy.HINT_COST:
		if _show_hint_now():
			var free: bool = SaveSystem.free_hints_left() > 0
			SaveSystem.spend_hint()
			if not free:
				_show_toast("−%d coins" % Economy.HINT_COST, 1.4)
			_refresh()
		return
	# Out of coins: offer a video for the hint. If no video can be shown, it's free.
	if AdManager.rewarded_ready():
		_ask_for_ad()
	else:
		if _show_hint_now():
			_show_toast("Here's a free hint", 2.5)


## Outlines where the next piece goes. If the pieces already down can't lead to
## a solution, the wrong ones go back to the tray first.
func _show_hint_now() -> bool:
	var step: Array = next_step(level, board.placements())
	if step.is_empty():
		return false
	var wrong: Array = step[1]
	if not wrong.is_empty():
		board.send_back(wrong)
		_show_toast("%d %s moved back to the tray" % [wrong.size(), "piece" if wrong.size() == 1 else "pieces"], 2.4)
	board.show_hint(step[0])
	_hinted = true
	_refresh()
	return true


## The next placement towards a solution from these pieces on the shape, and the
## pieces that have to come off first: [[i, o, x, y], [wrong pieces]].
static func next_step(lv: Dictionary, fixed: Dictionary) -> Array:
	var pz: FitSim.Puzzle = FitSim.puzzle(lv)
	var res: Dictionary = FitSim.solve(pz, fixed, 1, 150000)
	var wrong: Array = []
	var sol: Array = []
	if int(res["count"]) > 0:
		sol = (res["solutions"] as Array)[0]
	else:
		# Keep what matches the stored solution, take the rest off.
		sol = lv.get("solution", [])
		var kept: Dictionary = {}
		for i: Variant in fixed:
			var pl: Array = [int(i)] + (fixed[i] as Array)
			var ok: bool = false
			for s: Array in sol:
				if FitSim.same_cells(pz, pl, s):
					ok = true
			if ok:
				kept[i] = fixed[i]
			else:
				wrong.append(int(i))
		var again: Dictionary = FitSim.solve(pz, kept, 1, 150000)
		if int(again["count"]) > 0:
			sol = (again["solutions"] as Array)[0]
	# The first piece of the solution still in the tray, top-left first.
	var best: Array = []
	for pl: Array in sol:
		if fixed.has(int(pl[0])) and not int(pl[0]) in wrong:
			continue
		if best.is_empty() or int(pl[3]) * 100 + int(pl[2]) < int(best[3]) * 100 + int(best[2]):
			best = pl
	if best.is_empty():
		return []
	return [best, wrong]


func _ask_for_ad() -> void:
	var sheet: VBoxContainer = _open_sheet()
	sheet.add_child(UIKit.label("Not enough coins", 44, pal["ink"], 800))
	var note: Label = UIKit.label("A hint is %d coins. Watch a short video for this one instead?\nYour free hint comes back at midnight." % Economy.HINT_COST, 24, pal["muted"], 500)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(note)
	var watch: Button = UIKit.pill("Watch a video", pal, "primary", Vector2(0, 88), 30)
	watch.name = "WatchAd"
	watch.pressed.connect(func() -> void:
		_close_sheet()
		AdManager.show_rewarded(func(ok: bool) -> void:
			if ok:
				AudioManager.play("unlock", 1.0)
				_show_hint_now()
			_refresh()
		)
	)
	sheet.add_child(watch)
	var shop: Button = UIKit.pill("Get coins", pal, "soft", Vector2(0, 76), 24)
	shop.name = "HintShop"
	shop.pressed.connect(func() -> void:
		_close_sheet()
		app.open_coins()
	)
	sheet.add_child(shop)
	var close: Button = UIKit.pill("Not now", pal, "ghost", Vector2(0, 76), 24)
	close.name = "NotNow"
	close.pressed.connect(_close_sheet)
	sheet.add_child(close)
	_sheet_focus = watch


## How it went, in a few words.
func _verdict() -> String:
	var par: int = int(level.get("par", 0))
	if board.moves <= par and not _hinted:
		return "Not a single wasted move."
	if _hinted:
		return "Filled in %d moves, with a hint." % board.moves
	return "Filled in %d moves." % board.moves


func _stats_line() -> String:
	var n: int = int(level.get("par", 0))
	return "%s  ·  %d pieces  ·  par %d" % [str(level.get("name", "")), n, n]


func _show_result() -> void:
	var sheet: VBoxContainer = _open_sheet()
	sheet.add_theme_constant_override("separation", 14)
	sheet.add_child(UIKit.label("%s  ·  LEVEL %d" % [str(pal["name"]).to_upper(), index + 1], 20, pal["accent"], 700))
	var title: Label = UIKit.label(TITLES[_stars], 54, pal["ink"], 900)
	title.name = "ResultTitle"
	sheet.add_child(title)
	var picture: Board = Board.new()
	picture.name = "Picture"
	picture.show_tray = false
	picture.bg_color = UIKit.surface(pal)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.custom_minimum_size = Vector2(0, 220)
	sheet.add_child(picture)
	picture.setup(level, pal)
	picture.show_filled(board.placements())
	var row: _Stars = _Stars.new()
	row.pal = pal
	row.custom_minimum_size = Vector2(0, 88)
	sheet.add_child(row)
	row.play(_stars)
	sheet.add_child(UIKit.label(_verdict(), 26, pal["ink"], 700))
	sheet.add_child(UIKit.label(_stats_line(), 21, pal["muted"], 700))
	if _earned + _bonus > 0:
		var coins: HBoxContainer = HBoxContainer.new()
		coins.name = "Earned"
		coins.alignment = BoxContainer.ALIGNMENT_CENTER
		coins.add_theme_constant_override("separation", 10)
		var coin: _Coin = _Coin.new()
		coin.custom_minimum_size = Vector2(34, 34)
		coins.add_child(coin)
		var text: String = "+%d coins" % (_earned + _bonus)
		if _bonus > 0:
			text += "  ·  chapter complete!"
		coins.add_child(UIKit.label(text, 24, Color("#C98A1E"), 900))
		sheet.add_child(coins)
	var nxt: Dictionary = Levels.next_after(chapter_id, index)
	var next_btn: Button = UIKit.pill("Next level" if not nxt.is_empty() else "Chapters", pal, "primary", Vector2(0, 92), 32)
	next_btn.name = "Next"
	next_btn.pressed.connect(func() -> void:
		AdManager.between_levels(func() -> void:
			if nxt.is_empty():
				app.open_chapters()
			else:
				app.open_game(str(nxt["chapter"]), int(nxt["index"]))
		)
	)
	sheet.add_child(next_btn)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 22)
	sheet.add_child(actions)
	actions.add_child(_action("share-2", "SHARE", "Share", func() -> void: app.open_share(_share_info())))
	actions.add_child(_action("rotate-ccw", "AGAIN", "Replay", _restart))
	actions.add_child(_action("layout-grid", "LEVELS", "Levels", func() -> void: app.open_levels(chapter_id)))
	_sheet_focus = next_btn


## Everything the share card needs.
func _share_info() -> Dictionary:
	return {
		"level": level, "pal": pal, "chapter": str(pal["name"]), "number": index + 1,
		"stars": _stars, "title": TITLES[_stars], "verdict": _verdict(),
		"stats": _stats_line(), "placements": board.placements(),
	}


## A round icon button with a small caption under it.
func _action(icon_name: String, caption: String, node_name: String, cb: Callable) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var b: Button = UIKit.icon_button(icon_name, pal, 80.0)
	b.name = node_name
	b.pressed.connect(cb)
	box.add_child(b)
	box.add_child(UIKit.label(caption, 16, pal["muted"], 600))
	return box


## Opens a centred card and returns its content column.
func _open_sheet() -> VBoxContainer:
	_close_sheet()
	var root: Control = Control.new()
	root.name = "Sheet"
	root.add_to_group("modal")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(pal["bottom"], 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.card_style(pal))
	panel.custom_minimum_size = Vector2(600, 0)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	center.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	panel.add_child(col)
	_sheet = root
	shade.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(shade, "modulate:a", 1.0, 0.25)
	panel.modulate.a = 0.0
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	# Pop in from slightly smaller once the card has measured itself.
	(func() -> void:
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(0.85, 0.85)
		var pop: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(panel, "scale", Vector2.ONE, 0.42)
	).call_deferred()
	return col


func _close_sheet() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = null


## Shows a message in the strip over the shape, in place of MOVES / STARS.
func _show_toast(text: String, seconds: float) -> void:
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween().set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_property(_hud, "modulate:a", 0.0, 0.2)
	if seconds > 0.0:
		_toast_tween.chain().tween_interval(seconds)
		_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.35)
		_toast_tween.tween_property(_hud, "modulate:a", 1.0, 0.35)


func _hide_toast() -> void:
	if _toast.modulate.a > 0.0:
		if _toast_tween != null:
			_toast_tween.kill()
		_toast_tween = create_tween().set_parallel(true)
		_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.25)
		_toast_tween.tween_property(_hud, "modulate:a", 1.0, 0.25)


func handle_back() -> bool:
	if _intro != null and is_instance_valid(_intro):
		_intro.call("dismiss")
		return true
	if _sheet != null and is_instance_valid(_sheet) and not _done:
		_close_sheet()
		return true
	app.open_levels(chapter_id)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match (event as InputEventKey).keycode:
		KEY_R:
			_restart()
		KEY_H:
			_hint()
		KEY_T:
			board.turn_selected()
		KEY_F:
			board.flip_selected()
		_:
			return
	get_viewport().set_input_as_handled()


## A coin, for the reward line.
class _Coin:
	extends Control

	func _draw() -> void:
		UIKit.draw_coin(self, size * 0.5, minf(size.x, size.y) * 0.45)


## Three stars that pop in one after another with rising notes.
class _Stars:
	extends Control
	var pal: Dictionary
	var _shown: Array[float] = [0.0, 0.0, 0.0]
	var _earned: int = 0

	func play(stars: int) -> void:
		_earned = stars
		for i: int in 3:
			var tw: Tween = create_tween()
			tw.tween_interval(0.25 + 0.22 * float(i))
			tw.tween_callback(func() -> void:
				if i < _earned:
					AudioManager.play("star", [1.0, 1.25, 1.5][i], STAR_DB)
					Haptics.tap(12)
			)
			tw.tween_method(func(v: float) -> void:
				_shown[i] = v
				queue_redraw(), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		var tex: Texture2D = UIKit.icon("star-filled")
		var outline: Texture2D = UIKit.icon("star")
		for i: int in 3:
			var s: float = (78.0 if i == 1 else 64.0) * _shown[i]
			if s <= 1.0:
				continue
			var c: Vector2 = Vector2(size.x * 0.5 + (float(i) - 1.0) * 104.0, size.y * 0.5 - (8.0 if i == 1 else 0.0))
			var r: Rect2 = Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
			if i < _earned:
				draw_texture_rect(tex, r, false, Color("#FFC53D"))
			else:
				draw_texture_rect(outline, r, false, Color(pal["ink"], 0.25))


## MOVES (against par) and STARS, side by side over the shape. The stars on offer
## drop as moves go past par (and with a hint), with a little pulse.
class _Hud:
	extends Control
	var pal: Dictionary
	var par: int = 0
	var moves: int = 0
	var stars: int = 3
	var _bump: float = 0.0

	func set_state(m: int, s: int) -> void:
		if s < stars and is_inside_tree():
			_bump = 1.0
			AudioManager.play("undo", 0.8, -6.0)
		moves = m
		stars = s
		queue_redraw()

	func _process(delta: float) -> void:
		if _bump > 0.0:
			_bump = maxf(0.0, _bump - delta * 2.5)
			queue_redraw()

	func _draw() -> void:
		var fill: Color = UIKit.surface(pal)
		var l: Color = UIKit.lip(pal, fill)
		var h: float = 60.0
		var w: float = 230.0
		var gap: float = 16.0
		var y: float = (size.y - h) * 0.5
		var left: Rect2 = Rect2(Vector2(size.x * 0.5 - w - gap * 0.5, y), Vector2(w, h))
		var right: Rect2 = Rect2(Vector2(size.x * 0.5 + gap * 0.5, y), Vector2(w, h))
		draw_style_box(UIKit.lip_box(fill, l, 22, 5), left)
		draw_style_box(UIKit.lip_box(fill, l, 22, 5), right)
		var cf: Font = UIKit.font(900)
		var mid_y: float = y + h * 0.5 - 2.0
		_text(cf, "MOVES", Vector2(left.position.x + 22, mid_y), 16, pal["muted"])
		var nf: Font = UIKit.font(900)
		var num: String = "%d" % moves
		var tail: String = " / %d" % par
		var nw: float = nf.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var tw: float = nf.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var x: float = left.end.x - 22.0 - nw - tw
		_text(nf, num, Vector2(x, mid_y), 34, pal["ink"])
		_text(nf, tail, Vector2(x + nw, mid_y + 3.0), 22, pal["muted"])
		_text(cf, "STARS", Vector2(right.position.x + 22, mid_y), 16, pal["muted"])
		for k: int in 3:
			var s: float = 30.0 * (1.0 + (0.35 * _bump if k == stars else 0.0))
			var c: Vector2 = Vector2(right.end.x - 30.0 - float(2 - k) * 36.0, mid_y)
			var r: Rect2 = Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
			if k < stars:
				draw_texture_rect(UIKit.icon("star-filled"), r, false, Color("#F2B233"))
			else:
				draw_texture_rect(UIKit.icon("star-filled"), r, false, Color(pal["ink"], 0.13 + 0.4 * (_bump if k == stars else 0.0)))

	func _text(f: Font, t: String, left_mid: Vector2, fs: int, col: Color) -> void:
		var asc: float = f.get_ascent(fs)
		var desc: float = f.get_descent(fs)
		draw_string(f, Vector2(left_mid.x, left_mid.y + (asc - desc) * 0.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
