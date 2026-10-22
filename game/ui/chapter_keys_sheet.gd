extends Overlay
## Chapter keys: a key opens a whole locked chapter at once. Opened on a locked
## chapter, it offers to use one right there; otherwise it sells them (1-5) and
## gives one free from a video each day.

## The locked chapter this was opened for ("" from the shop).
var chapter_id: String = ""
var _count: int = 1
var _num: Label
var _buy: Button
var _use: Button
var _video: Button
var _status: Label


func build() -> void:
	name = "ChapterKeys"
	var locked: bool = not chapter_id.is_empty() and not Levels.chapter_open(chapter_id)
	add_title(str(Palette.get_palette(chapter_id)["name"]) + " is locked" if locked else "Chapter keys")
	var body: VBoxContainer = card_body()
	body.add_theme_constant_override("separation", 14)
	var text: String = "A chapter key opens a whole locked chapter for good. Its levels then open one by one as you play."
	if locked:
		var ci: int = Levels.chapter_index(chapter_id)
		var prev: String = str(Levels.chapters[ci - 1]["id"])
		var left: int = Levels.CHAPTER_GATE - Levels.cleared_in(prev)
		text = "Clear %d more %s in %s to open it, or open it now with a chapter key." % [left, "level" if left == 1 else "levels", str(Palette.get_palette(prev)["name"])]
	var sub: Label = UIKit.label(text, 22, pal["muted"], 500)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sub)
	var have: HBoxContainer = HBoxContainer.new()
	have.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(have)
	have.add_child(CounterChip.make("chapter_keys", pal, app))
	if locked:
		_use = UIKit.pill("", pal, "primary", Vector2(0, 90), 28)
		_use.name = "UseChapterKey"
		_use.pressed.connect(_use_key)
		body.add_child(_use)
		_first_focus = _use
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	body.add_child(row)
	var minus: Button = UIKit.icon_button("minus", pal, 72.0)
	minus.name = "Minus"
	minus.pressed.connect(func() -> void: _set_count(_count - 1))
	row.add_child(minus)
	_num = UIKit.label("1", 60, pal["ink"], 800)
	_num.custom_minimum_size = Vector2(90, 0)
	row.add_child(_num)
	var plus: Button = UIKit.icon_button("plus", pal, 72.0)
	plus.name = "Plus"
	plus.pressed.connect(func() -> void: _set_count(_count + 1))
	row.add_child(plus)
	_buy = UIKit.pill("", pal, "soft" if locked else "primary", Vector2(0, 86), 26)
	_buy.name = "BuyChapterKeys"
	_buy.pressed.connect(func() -> void:
		_status.text = "Opening Google Play…"
		Store.buy("chapter_keys_%d" % _count)
	)
	body.add_child(_buy)
	body.add_child(UIKit.refund_note(pal))
	if _first_focus == null:
		_first_focus = _buy
	_video = UIKit.pill("", pal, "soft", Vector2(0, 76), 22)
	_video.name = "VideoChapterKey"
	_video.pressed.connect(_watch)
	body.add_child(_video)
	_status = UIKit.label("", 20, pal["accent"], 700)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)
	Store.purchase_finished.connect(func(ok: bool, msg: String, id: String) -> void:
		if is_inside_tree() and (Store.is_chapter_keys(id) or id.is_empty()):
			_status.text = msg
			if ok:
				AudioManager.play("unlock", 1.0)
	)
	Events.chapter_keys_changed.connect(func(_c: int) -> void: _refresh())
	Store.price_updated.connect(func(_id: String, _p: String) -> void: _refresh())
	_refresh()


func _set_count(n: int) -> void:
	_count = clampi(n, 1, Store.CHAPTER_KEY_MAX)
	AudioManager.play_ui("ui_toggle")
	_refresh()


func _refresh() -> void:
	if _num == null or not is_inside_tree():
		return
	_num.text = str(_count)
	_buy.text = "Get %d %s for %s" % [_count, "key" if _count == 1 else "keys", Store.price("chapter_keys_%d" % _count)]
	if _use != null:
		var k: int = SaveSystem.chapter_keys()
		_use.text = "Open %s now  ·  you have %d" % [str(Palette.get_palette(chapter_id)["name"]), k] if k > 0 else "No chapter keys yet"
		_use.disabled = k <= 0
	var left: int = SaveSystem.video_chapter_keys_left()
	_video.text = "Watch a video for a chapter key" if left > 0 else "Next free chapter key tomorrow"
	_video.disabled = left <= 0


func _watch() -> void:
	if not AdManager.rewarded_ready():
		_status.text = "No video available right now. Try again in a little while." if AdManager.provider != null else "Videos are available in the Android app."
		return
	AdManager.show_rewarded(func(ok: bool) -> void:
		if ok and is_inside_tree():
			SaveSystem.add_video_chapter_key()
			AudioManager.play("unlock", 1.0)
			_status.text = "Here's a chapter key!"
		_refresh()
	)


func _use_key() -> void:
	if SaveSystem.use_chapter_key(chapter_id):
		AudioManager.play("unlock", 1.0)
		Haptics.tap(20)
		app.close_settings()
		app.open_levels(chapter_id)
