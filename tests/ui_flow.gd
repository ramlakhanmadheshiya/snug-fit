extends Node
## End-to-end flow through the real app, headless:
## home -> first level (tutorial) -> a real drag -> refusals -> fill -> result
## with coins -> next -> turning and flipping -> hints (free, coins, out of
## coins) -> restart -> locked level and chapter (keys) -> shop, coins and packs
## -> settings, appearance and pickers -> back.
## Run: godot --headless --path . res://tests/ui_flow.tscn

var app: Control
var failures: int = 0
var _backup: Dictionary


func _ready() -> void:
	AudioManager.mute_for_tests = true
	_backup = SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem._defaults()
	SaveSystem.data["settings"]["appearance"] = "light"
	SaveSystem._apply_cosmetics()
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	add_child(app)
	_run.call_deferred()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok  ", label)
	else:
		failures += 1
		push_error("FAILED: " + label)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _find(name: String) -> Node:
	return app.find_child(name, true, false)


func _screen_is(file: String) -> bool:
	return app.current != null and app.current.get_script().resource_path.ends_with(file)


func _board() -> Board:
	return app.current.get("board") as Board


func _press(name: String) -> void:
	(_find(name) as BaseButton).pressed.emit()


## A real drag on the board: press on the piece in the tray, move, let go.
func _drag(b: Board, i: int, to: Vector2) -> void:
	var from: Vector2 = b.tray_center(i)
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	b._gui_input(down)
	for k: int in 6:
		var mv: InputEventMouseMotion = InputEventMouseMotion.new()
		mv.position = from.lerp(to, float(k + 1) / 6.0)
		b._gui_input(mv)
		await _wait(0.03)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	b._gui_input(up)
	await _wait(0.1)


## Puts a level's solution in, piece by piece, through the board.
func _solve(b: Board) -> void:
	for pl: Array in b.level["solution"]:
		if not b.on_board[int(pl[0])]:
			b.place_now(int(pl[0]), int(pl[1]), Vector2i(int(pl[2]), int(pl[3])))


func _run() -> void:
	await _wait(0.6)
	_check(_screen_is("home_screen.gd"), "starts on the home screen")
	_check((_find("Title") as Label).text == "Snug Fit", "home shows the name")
	_check(_find("Play") != null and _find("Chapters") != null and _find("Coins") != null and _find("Keys") != null and _find("Shop") != null, "home has Play, Chapters, coins, keys and the shop")
	var coins0: int = SaveSystem.coins()
	_check(coins0 == Economy.START_COINS, "a new player starts with %d coins" % Economy.START_COINS)
	_press("Play")
	await _wait(0.8)
	var b: Board = _board()
	_check(b != null and str(b.level.get("id", "")) == "ch1_01", "Play opens the first level")
	_check(_find("Tutorial") != null, "first play shows the hands-on tutorial")
	_check(_find("ShapeName") != null and (_find("ShapeName") as Label).text == str(b.level["name"]), "the header names the shape")

	# A real drag, onto the piece's spot in the solution.
	var pl: Array = b.level["solution"][0]
	var i: int = int(pl[0])
	SaveSystem.data["settings"]["lift"] = false
	await _drag(b, i, b.board_center(i, int(pl[1]), Vector2i(int(pl[2]), int(pl[3]))) + Vector2(0, b.cs * 0.25))
	_check(b.on_board[i] and b.moves == 1, "dragging a piece onto its spot places it and counts a move")
	# Dragging it off again sends it home without a move.
	await _drag_from_board(b, i, b.tray_rect.get_center())
	_check(not b.on_board[i] and b.moves == 1, "dragging a piece off the shape takes it back, free")
	await _wait(0.4)
	# A drop half off the shape is refused, and the piece goes home.
	var refused: Array = []
	b.rejected.connect(func(r: String) -> void: refused.append(r))
	await _drag(b, i, b.board_center(i, int(pl[1]), Vector2i(int(pl[2]), int(pl[3]) + 1)) + Vector2(0, b.cs * 0.25))
	_check(not b.on_board[i] and refused.has("outside"), "a piece dropped half outside the shape is refused")
	_check(not b.place_now(i, 0, Vector2i(-1, 0)), "an illegal spot can't be taken")
	b.reset()
	_check(b.moves == 0, "a reset empties the shape")
	# Taps don't turn pieces in Fit.
	b._tap(0)
	_check(refused.has("still") and b.orient[0] == 0, "Fit pieces don't turn on a tap")

	# Fill it: result card, stars, coins.
	_solve(b)
	_check(b.is_solved and b.locked, "filling every cell solves the level")
	await _wait(1.6)
	_check(_find("ResultTitle") != null and _find("Next") != null and _find("Share") != null, "the result card shows with Next and Share")
	_check(_find("Earned") != null and SaveSystem.coins() == coins0 + Economy.level_reward(true, 3), "a first ★★★ clear pays coins (shown on the card)")
	_check(SaveSystem.stars_for("ch1_01") == 3 and SaveSystem.flag("tutorial_done"), "three stars recorded, tutorial done")
	_press("Next")
	await _wait(0.8)
	_check(str(_board().level.get("id", "")) == "ch1_02", "Next opens level 2")

	# Hints: the day's free one, then coins, then (out of coins, no video) free.
	b = _board()
	var c1: int = SaveSystem.coins()
	_check(SaveSystem.free_hints_left() == Economy.FREE_HINTS, "one free hint a day")
	_press("Hint")
	await _wait(0.2)
	_check(b.has_hint() and SaveSystem.coins() == c1 and SaveSystem.free_hints_left() == 0, "the free hint outlines a piece and costs nothing")
	_check(app.current.call("stars_now") == 2, "a hint caps the stars at two")
	var hinted: Array = b._hint.duplicate()
	b.place_now(int(hinted[0]), int(hinted[1]), Vector2i(int(hinted[2]), int(hinted[3])))
	_check(not b.has_hint(), "placing the hinted piece clears the outline")
	_press("Hint")
	await _wait(0.2)
	_check(b.has_hint() and SaveSystem.coins() == c1 - Economy.HINT_COST, "the next hint costs %d coins" % Economy.HINT_COST)
	b.clear_hint()
	SaveSystem.data["coins"] = 0
	_press("Hint")
	await _wait(0.2)
	_check(b.has_hint() and SaveSystem.coins() == 0, "out of coins with no video available, the hint is free")
	# A wrong piece is moved off by the next hint.
	_press("Restart")
	await _wait(0.2)
	_check(b.moves == 0 and not b.has_hint(), "Restart is a fresh start")

	# Turning and flipping.
	app.open_game("ch2", 3)
	await _wait(0.8)
	b = _board()
	var o0: int = b.orient[0]
	b._tap(0)
	_check(b.orient[0] == FitSim.turned(o0) and b.moves == 0, "in Turn, a tap turns a tray piece, free")
	app.open_game("ch6", 3)
	await _wait(0.8)
	b = _board()
	_check(_find("Flip") != null, "Flip levels show a Flip button")
	b.selected = 1
	var o1: int = b.orient[1]
	_press("Flip")
	_check(b.orient[1] == FitSim.flipped(o1), "Flip turns the selected piece over")
	_solve(b)
	_check(b.is_solved, "a Flip level can be solved with its stored answer")
	await _wait(1.6)

	# Locked level and chapter: keys.
	app.open_levels("ch1")
	await _wait(0.6)
	_check(_find("Level_30") != null, "the level gallery shows all 30 shapes")
	app.open_locked("ch1", 20)
	await _wait(0.3)
	_check(_find("UseKey") != null and (_find("UseKey") as Button).disabled, "a locked level offers a key (none yet)")
	SaveSystem.add_keys(1)
	_press("UseKey")
	await _wait(0.8)
	_check(_screen_is("game_screen.gd") and str(_board().level["id"]) == "ch1_21", "a level key opens the level")
	app.open_chapters()
	await _wait(0.6)
	_check(_find("Chapter_ch3") != null, "chapters show as tiles")
	_check(not Levels.chapter_open("ch3"), "Paint is locked at the start")
	app.open_chapter_keys("ch3")
	await _wait(0.3)
	SaveSystem.add_chapter_keys(1)
	_press("UseChapterKey")
	await _wait(0.8)
	_check(Levels.chapter_open("ch3") and _screen_is("levels_screen.gd"), "a chapter key opens the whole chapter")

	# Shop: packs, coins (simulated purchase in debug), trials.
	app.open_shop()
	await _wait(0.6)
	for id: String in Store.PRODUCTS:
		_check(_find("Product_" + id) != null, "the shop lists " + str(Store.PRODUCTS[id]["name"]))
	_check(_find("Product_coins") != null and _find("Product_chapter_keys") != null and _find("Product_keys") != null and _find("TipJar") != null, "the shop has coins, chapter keys, level keys and the tip jar")
	app.open_coins()
	await _wait(0.3)
	var c2: int = SaveSystem.coins()
	_press("Buy_coins_1000")
	await _wait(0.2)
	_check(SaveSystem.coins() == c2 + 1000, "buying a coin bag adds its coins")
	app.open_product("complete_pack")
	await _wait(0.3)
	var k0: int = SaveSystem.keys()
	Store.buy("complete_pack")
	await _wait(0.2)
	_check(SaveSystem.is_supporter() and SaveSystem.owns("block_pack") and SaveSystem.owns("theme_pack"), "the Complete pack unlocks every pack")
	_check(SaveSystem.keys() == k0 + Store.COMPLETE_KEYS and SaveSystem.free_hints_left() >= Economy.SUPPORTER_FREE_HINTS - 1, "the Complete pack adds keys, and Supporters get 3 free hints")
	app.close_settings()

	# Settings, appearance and pickers.
	app.open_settings(false)
	await _wait(0.3)
	_check(_find("Appearance") != null and _find("Row_lift") != null and _find("Reset") != null, "settings has appearance, lift and reset")
	(_find("Option_Dark") as Button).pressed.emit()
	await _wait(0.5)
	_check(bool(Palette.get_palette("ch1")["dark"]), "Dark appearance makes light chapters dark")
	(_find("Option_Light") as Button).pressed.emit()
	await _wait(0.5)
	_check(not bool(Palette.get_palette("ch7")["dark"]), "Light appearance makes dark chapters light")
	app.open_picker("blocks")
	await _wait(0.3)
	SaveSystem.set_setting("block_style", "candy")
	_check(SaveSystem.block_style() == "candy", "an owned block style can be chosen")
	app.open_about()
	await _wait(0.3)
	_check(_find("About") != null and _find("Privacy") != null and _find("Help") != null, "about links to privacy and help")
	app.close_settings()
	app.go_back()
	await _wait(0.6)

	SaveSystem.data = _backup
	SaveSystem.save()
	SaveSystem._apply_cosmetics()
	print("UI FLOW: ", "FAIL (%d)" % failures if failures > 0 else "PASS")
	get_tree().quit(1 if failures > 0 else 0)


## Drags a placed piece from the shape to a point.
func _drag_from_board(b: Board, i: int, to: Vector2) -> void:
	var from: Vector2 = b.cell_center(b.at[i] + b.cells_of(i)[0])
	var down: InputEventMouseButton = InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	b._gui_input(down)
	for k: int in 6:
		var mv: InputEventMouseMotion = InputEventMouseMotion.new()
		mv.position = from.lerp(to, float(k + 1) / 6.0)
		b._gui_input(mv)
		await _wait(0.03)
	var up: InputEventMouseButton = InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	b._gui_input(up)
	await _wait(0.1)
