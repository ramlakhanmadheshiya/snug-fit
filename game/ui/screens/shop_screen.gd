extends Screen
## The shop: your coins and keys up top, every pack with a live preview, its
## price and whether it's yours (tap for its card), then coins, keys and the tip
## jar as rows that open their own cards, and Restore purchases.

var _rows: Dictionary = {}
var _status: Label
var _first: Control


func _ready() -> void:
	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.add_child(make_header("Shop", func() -> void: app.open_home()))
	var chips: HBoxContainer = HBoxContainer.new()
	chips.name = "Counters"
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 12)
	for kind: String in ["chapter_keys", "keys", "coins"]:
		chips.add_child(CounterChip.make(kind, pal, app))
	col.add_child(chips)
	var scroll: TouchScroll = TouchScroll.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	scroll.set_content(list)
	var sub: Label = UIKit.label("Every level in Snug Fit opens by playing.\nThese are extras, and they help me make more.", 21, pal["muted"], 600)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(sub)
	for id: String in Store.PRODUCTS:
		var row: Button = _row(id)
		list.add_child(row)
		_rows[id] = row
		if _first == null:
			_first = row
	list.add_child(UIKit.caption("Coins, keys and thanks", {"muted": pal["accent"]}, 17))
	list.add_child(_link("coins", "Coins", "Bags of 300 to 6,000  ·  free coins from a video", "Product_coins", func() -> void: app.open_coins()))
	list.add_child(_link("chapter_keys", "Chapter keys", "Open a locked chapter now  ·  one free from a video daily", "Product_chapter_keys", func() -> void: app.open_chapter_keys()))
	list.add_child(_link("keys", "Level keys", "Open any locked level  ·  10% off for 5+", "Product_keys", func() -> void: app.open_keys()))
	var n: int = SaveSystem.tips_given()
	list.add_child(_link("tips", "Tip jar", "Say thanks, as often as you like" if n == 0 else "You've tipped %d %s. Thank you ♥" % [n, "time" if n == 1 else "times"], "TipJar", func() -> void: app.open_tips()))
	_status = UIKit.label("", 20, pal["muted"], 600)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(_status)
	var restore: Button = UIKit.pill("Restore purchases", pal, "soft", Vector2(340, 72), 24)
	restore.name = "Restore"
	restore.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restore.pressed.connect(func() -> void:
		_status.text = "Checking your purchases…"
		Store.restore()
	)
	list.add_child(restore)
	var foot: Label = UIKit.label("One-time purchases through Google Play. No subscriptions.", 18, pal["muted"], 500)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(foot)
	list.add_child(UIKit.refund_note(pal))
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	list.add_child(spacer)
	Store.restore_finished.connect(func(_ok: bool, msg: String) -> void:
		_status.text = msg
		_refresh_all()
	)
	Store.purchase_finished.connect(func(ok: bool, msg: String, _id: String) -> void:
		if not is_inside_tree():
			return
		_status.text = msg
		if ok:
			AudioManager.play("unlock", 1.0, -3.0)
		_refresh_all()
	)
	Store.price_updated.connect(func(_id: String, _p: String) -> void: _refresh_all())
	Events.purchases_changed.connect(_refresh_all)


func _refresh_all() -> void:
	if not is_inside_tree():
		return
	for id: String in _rows:
		((_rows[id] as Node).find_child("Right", true, false) as _PriceTag).refresh()


## A raised row: lip block, featured ones outlined in the accent.
func _block(node_name: String, height: float, featured: bool) -> Button:
	var b: Button = Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_ALL
	var fill: Color = UIKit.surface(pal)
	if featured:
		fill = fill.lerp(pal["accent"], 0.1)
	var l: Color = UIKit.lip(pal, fill)
	var outline: Color = pal["accent"] if featured else Color.TRANSPARENT
	b.add_theme_stylebox_override("normal", UIKit.lip_box(fill, l, 30, 7, Vector2(8, 8), false, outline))
	b.add_theme_stylebox_override("hover", UIKit.lip_box(fill.lightened(0.04), l, 30, 7, Vector2(8, 8), false, outline))
	b.add_theme_stylebox_override("pressed", UIKit.lip_box(fill.darkened(0.04), l, 30, 7, Vector2(8, 8), true, outline))
	b.add_theme_stylebox_override("hover_pressed", UIKit.lip_box(fill.darkened(0.04), l, 30, 7, Vector2(8, 8), true, outline))
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.set_corner_radius_all(34)
	focus.border_color = pal["accent"]
	focus.set_border_width_all(4)
	focus.expand_margin_left = 5
	focus.expand_margin_right = 5
	focus.expand_margin_top = 5
	focus.expand_margin_bottom = 5
	b.add_theme_stylebox_override("focus", focus)
	UIKit.add_press_feel(b)
	return b


func _row_box(b: Button) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	row.offset_bottom = -7
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	return row


func _preview(id: String, side: float) -> ProductPreview:
	var tile: ProductPreview = ProductPreview.new()
	tile.product = id
	tile.pal = pal
	tile.compact = true
	tile.custom_minimum_size = Vector2(side, side)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tile


## One pack: preview, name and blurb, and price / owned / trial time.
func _row(id: String) -> Button:
	var info: Dictionary = Store.PRODUCTS[id]
	var featured: bool = id == "complete_pack"
	var b: Button = _block("Product_" + id, 150.0 if featured else 132.0, featured)
	b.pressed.connect(func() -> void: app.open_product(id))
	var row: HBoxContainer = _row_box(b)
	row.add_child(_preview(id, 96.0))
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	if featured:
		text.add_child(UIKit.caption("Best value  ·  save %d%%" % Store.complete_saving(), {"muted": pal["accent"]}, 16))
	text.add_child(UIKit.label(str(info["name"]), 30, pal["ink"], 900, HORIZONTAL_ALIGNMENT_LEFT))
	var blurb: Label = UIKit.label(str(info["blurb"]), 19, pal["muted"], 600, HORIZONTAL_ALIGNMENT_LEFT)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(blurb)
	var right: _PriceTag = _PriceTag.new()
	right.name = "Right"
	right.product = id
	right.pal = pal
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	right.refresh()
	return b


## A row that opens its own card (coins, keys, the tip jar).
func _link(preview: String, title: String, sub: String, node_name: String, cb: Callable) -> Button:
	var b: Button = _block(node_name, 120.0, false)
	b.pressed.connect(cb)
	var row: HBoxContainer = _row_box(b)
	row.add_child(_preview(preview, 84.0))
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(UIKit.label(title, 28, pal["ink"], 900, HORIZONTAL_ALIGNMENT_LEFT))
	var s: Label = UIKit.label(sub, 19, pal["muted"], 600, HORIZONTAL_ALIGNMENT_LEFT)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(s)
	row.add_child(UIKit.icon_rect("chevron-right", 28.0, pal["muted"]))
	return b


func focus_default() -> void:
	if _first != null:
		_first.grab_focus()


func handle_back() -> bool:
	app.open_home()
	return true


## Price, "Owned" check, or the time left on a video trial (live).
class _PriceTag:
	extends HBoxContainer
	var product: String
	var pal: Dictionary
	var _clock: Label
	var _wait: float = 0.0

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait <= 0.0:
			_wait = 0.25
			_tick()

	func _tick() -> void:
		if _clock == null or not is_instance_valid(_clock):
			return
		var c: String = SaveSystem.trial_clock(product)
		_clock.text = "trial · %s left" % c if not c.is_empty() else ""

	func refresh() -> void:
		for c: Node in get_children():
			c.queue_free()
		add_theme_constant_override("separation", 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if SaveSystem.bought(product):
			add_child(UIKit.icon_rect("check", 28.0, Color("#2E9E62")))
			add_child(UIKit.label("Owned", 24, Color("#2E9E62"), 900))
			return
		var box: VBoxContainer = VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		box.add_child(UIKit.label(Store.price(product), 26, Color("#D88F1F"), 900, HORIZONTAL_ALIGNMENT_RIGHT))
		if SaveSystem.trial_left(product) > 0:
			var clock: Label = UIKit.label("", 16, pal["accent"], 800, HORIZONTAL_ALIGNMENT_RIGHT)
			clock.name = "TrialClock"
			box.add_child(clock)
			_clock = clock
			_tick()
		add_child(UIKit.icon_rect("chevron-right", 28.0, pal["muted"]))
