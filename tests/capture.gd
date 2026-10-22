extends Node
## Drives the real app through every screen and saves screenshots.
## Run (needs a window; the flags keep it drawing when it's behind other windows):
##   godot --fixed-fps 60 --disable-vsync --always-on-top --path . res://tests/capture.tscn -- <out_dir>
##   ... -- store/screenshots --store    # the Play Store set, 1080 x 1920
## Add --dark for the dark appearance (light otherwise).
## The player's own save is set aside while it runs and put back afterwards.

## Holds the player's real save while a capture runs; a run that dies leaves it
## here, and the next run puts it back before doing anything else.
const SAVE_GUARD: String = "user://capture_save_guard.json"

var out_dir: String = "user://captures"
var _store_vp: SubViewport
var app: Control


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty() and not args[0].begins_with("--"):
		out_dir = args[0]
	if out_dir.is_relative_path():
		out_dir = ProjectSettings.globalize_path("res://").path_join(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	AudioManager.mute_for_tests = true
	_guard_save()
	app = (load("res://game/scenes/main.tscn") as PackedScene).instantiate()
	if args.has("--store"):
		# A full 1080 x 1920 phone screen, whatever the monitor.
		_store_vp = SubViewport.new()
		_store_vp.size = Vector2i(1080, 1920)
		_store_vp.size_2d_override = Vector2i(720, 1280)
		_store_vp.size_2d_override_stretch = true
		_store_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_store_vp)
		_store_vp.add_child(app)
	else:
		add_child(app)
	_run.call_deferred()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = (_store_vp if _store_vp != null else get_viewport()).get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("captured ", name)


func _board() -> Board:
	return app.current.get("board") as Board


## Puts the first n pieces of the level's solution on the shape.
func _place(b: Board, n: int) -> void:
	var sol: Array = b.level["solution"]
	for k: int in mini(n, sol.size()):
		var pl: Array = sol[k]
		b.place_now(int(pl[0]), int(pl[1]), Vector2i(int(pl[2]), int(pl[3])))


## Shows piece `i` being carried towards its solution spot (fraction k of the way).
func _carry(b: Board, i: int, k: float) -> void:
	var pl: Array = []
	for s: Array in b.level["solution"]:
		if int(s[0]) == i:
			pl = s
	b.orient[i] = int(pl[1])
	var to: Vector2 = b.board_center(i, int(pl[1]), Vector2i(int(pl[2]), int(pl[3])))
	b._press = i
	b._dragging = true
	b._drag_k = 1.0
	b._lift = 0.0
	b._grab = Vector2.ZERO
	b._drag_pos = b.tray_center(i).lerp(to, k)
	b.queue_redraw()


func _run() -> void:
	if OS.get_cmdline_user_args().has("--store"):
		await _store()
	else:
		await _screens()
	_restore_save()
	get_tree().quit()


func _screens() -> void:
	await _wait(0.9)
	await _shot("00_splash")
	await _wait(2.4)
	await _shot("01_home")
	app.open_chapters()
	await _wait(1.6)
	await _shot("02_chapters")
	(app.find_child("Scroll", true, false) as TouchScroll).scroll_to(1200.0)
	await _wait(0.8)
	await _shot("02b_chapters_more")
	app.open_levels("ch1")
	await _wait(0.9)
	await _shot("03_levels")
	app.open_game("ch1", 0)
	await _wait(1.6)
	await _shot("04_tutorial")
	app.open_game("ch2", 0)
	await _wait(1.2)
	await _shot("05_chapter_intro")
	app.current.find_child("GotIt", true, false).emit_signal("pressed")
	await _wait(0.8)
	await _shot("05b_intro_hint")
	for spec: Array in [["ch1", 14, 2], ["ch2", 20, 3], ["ch3", 12, 2], ["ch4", 16, 3], ["ch5", 10, 2], ["ch6", 18, 2], ["ch7", 25, 4]]:
		app.open_game(spec[0], spec[1])
		await _wait(1.1)
		var b: Board = _board()
		_place(b, int(spec[2]))
		await _wait(0.6)
		var next: int = int((b.level["solution"] as Array)[int(spec[2])][0])
		_carry(b, next, 0.7)
		await _shot("06_%s_%02d" % [spec[0], int(spec[1]) + 1])
		b._dragging = false
		b._press = -1
	var b2: Board = _board()
	_place(b2, 99)
	await _wait(0.5)
	await _shot("07_finish")
	await _wait(1.6)
	await _shot("08_result")
	app.current.find_child("Share", true, false).emit_signal("pressed")
	await _wait(1.5)
	await _shot("08b_share")
	app.close_settings()
	app.open_game("ch3", 4)
	await _wait(1.0)
	app.current.call("_hint")
	await _wait(0.6)
	await _shot("09_hint")
	app.open_settings(true)
	await _wait(0.6)
	await _shot("10_settings")
	app.open_setting_info("lift")
	await _wait(1.2)
	await _shot("10b_info_lift")
	app.open_picker("blocks")
	await _wait(0.6)
	await _shot("10c_blocks")
	app.open_how_to_play()
	await _wait(0.6)
	await _shot("10d_how_to_play")
	app.open_about()
	await _wait(0.6)
	await _shot("10e_about")
	app.close_settings()
	app.open_shop()
	await _wait(1.2)
	await _shot("11_shop")
	app.open_product("block_pack")
	await _wait(0.8)
	await _shot("11b_block_pack")
	app.close_settings()
	SaveSystem.data["owned"]["theme_pack"] = true
	SaveSystem.data["owned"]["block_pack"] = true
	SaveSystem.set_setting("theme", "midnight")
	SaveSystem.set_setting("block_style", "candy")
	app.apply_theme()
	await _wait(0.6)
	app.open_game("ch1", 22)
	await _wait(1.2)
	_place(_board(), 4)
	await _wait(0.6)
	await _shot("12_midnight_candy")


## Play Store screenshots: the moments that sell the game.
func _store() -> void:
	await _wait(3.2)
	await _shot("01_home")
	var specs: Array = [["ch1", 24, 4, "02_fit"], ["ch3", 20, 4, "03_paint"], ["ch2", 26, 3, "04_turn"], ["ch4", 22, 3, "05_pegs"], ["ch7", 27, 5, "06_mosaic"]]
	for spec: Array in specs:
		app.open_game(spec[0], spec[1])
		await _wait(1.2)
		var b: Board = _board()
		_place(b, int(spec[2]))
		await _wait(0.6)
		_carry(b, int((b.level["solution"] as Array)[int(spec[2])][0]), 0.65)
		await _shot(spec[3])
		b._dragging = false
		b._press = -1
	_place(_board(), 99)
	await _wait(2.8)
	await _shot("07_result")
	app.open_chapters()
	await _wait(1.6)
	await _shot("08_chapters")


func _guard_save() -> void:
	if FileAccess.file_exists(SAVE_GUARD):
		_restore_save()
		SaveSystem.load_save()
	var existed: bool = FileAccess.file_exists(SaveSystem.SAVE_PATH)
	var text: String = FileAccess.get_file_as_string(SaveSystem.SAVE_PATH) if existed else ""
	var f: FileAccess = FileAccess.open(SAVE_GUARD, FileAccess.WRITE)
	f.store_string(JSON.stringify({"existed": existed, "text": text}))
	f.close()
	# Shots start from a fresh install's save, with the tutorial and intros seen,
	# a few chapters open, and some stars.
	SaveSystem.data = SaveSystem._defaults()
	SaveSystem.data["settings"]["appearance"] = "dark" if OS.get_cmdline_user_args().has("--dark") else "light"
	SaveSystem._apply_cosmetics()
	for c: Dictionary in Levels.chapters:
		var list: Array = c["levels"]
		for i: int in list.size():
			if i < 18 and str(c["id"]) in ["ch1", "ch2", "ch3", "ch4"]:
				SaveSystem.data["levels"][str(list[i]["id"])] = {"stars": 3 if i % 4 else 2, "best": 5}
	SaveSystem.data["flags"]["tutorial_done"] = false
	SaveSystem.data["last"] = {"chapter": "ch3", "index": 18}


func _restore_save() -> void:
	var guard: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_GUARD))
	if guard is Dictionary:
		if bool(guard["existed"]):
			var f: FileAccess = FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
			f.store_string(str(guard["text"]))
			f.close()
		elif FileAccess.file_exists(SaveSystem.SAVE_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSystem.SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_GUARD))
