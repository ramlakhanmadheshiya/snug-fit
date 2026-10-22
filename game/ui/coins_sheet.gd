extends Overlay
## Coins: four bags to buy, and free coins from a short video (a few a day).

var _status: Label
var _video: Button


func _init() -> void:
	scrollable = true


func build() -> void:
	name = "CoinsShop"
	add_title("Coins")
	var body: VBoxContainer = card_body()
	body.add_theme_constant_override("separation", 12)
	var sub: Label = UIKit.label("Coins pay for hints (%d each). You also earn them by clearing levels, for every new star, and for finishing a chapter." % Economy.HINT_COST, 22, pal["muted"], 500)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sub)
	var have: HBoxContainer = HBoxContainer.new()
	have.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(have)
	have.add_child(CounterChip.make("coins", pal, app))
	for id: String in Store.COIN_PACKS:
		body.add_child(_row(id))
	_video = UIKit.pill("", pal, "soft", Vector2(0, 80), 23)
	_video.name = "FreeCoins"
	_video.pressed.connect(_watch)
	body.add_child(_video)
	_status = UIKit.label("", 20, pal["muted"], 600)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_status)
	body.add_child(UIKit.refund_note(pal))
	Store.purchase_finished.connect(func(ok: bool, msg: String, id: String) -> void:
		if is_inside_tree() and (Store.is_coins(id) or id.is_empty()):
			_status.text = msg
			if ok:
				AudioManager.play("unlock", 1.0)
	)
	Store.price_updated.connect(func(_id: String, _p: String) -> void: _refresh_prices())
	_refresh()


func _refresh() -> void:
	var left: int = SaveSystem.video_coins_left()
	_video.text = "Watch a video: +%d coins  ·  %d left today" % [Economy.VIDEO_COINS, left] if left > 0 else "Free coins are back tomorrow"
	_video.disabled = left <= 0


func _refresh_prices() -> void:
	if not is_inside_tree():
		return
	for id: String in Store.COIN_PACKS:
		var tag: Label = find_child("Price_" + id, true, false) as Label
		if tag != null:
			tag.text = Store.price(id)


## A coin bag: a stack of coins, the amount and its bonus, and the price. Tap to buy.
func _row(id: String) -> Button:
	var pack: Array = Store.COIN_PACKS[id]
	var b: Button = UIKit.pill("", pal, "soft", Vector2(0, 104), 22)
	b.name = "Buy_" + id
	b.pressed.connect(func() -> void:
		_status.text = "Opening Google Play…"
		Store.buy(id)
	)
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var stack: _Stack = _Stack.new()
	stack.count = 1 + Store.COIN_PACKS.keys().find(id)
	stack.custom_minimum_size = Vector2(70, 70)
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stack)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(UIKit.label("%s coins" % _thousands(int(pack[0])), 27, pal["ink"], 800, HORIZONTAL_ALIGNMENT_LEFT))
	var bonus: int = _bonus(id)
	text.add_child(UIKit.label(str(pack[1]) + ("  ·  +%d%% more coins" % bonus if bonus > 0 else ""), 19, Color("#2E9E62") if bonus > 0 else pal["muted"], 700, HORIZONTAL_ALIGNMENT_LEFT))
	var price: Label = UIKit.badge(Store.price(id), pal, Color("#E9A23B"))
	price.name = "Price_" + id
	price.add_theme_font_size_override("font_size", 22)
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price)
	return b


## Extra coins per rupee compared with the smallest bag, as a percentage (to the nearest 5).
static func _bonus(id: String) -> int:
	var base: Array = Store.COIN_PACKS[Store.COIN_PACKS.keys()[0]]
	var pack: Array = Store.COIN_PACKS[id]
	var per: float = float(pack[0]) / float(pack[2])
	var base_per: float = float(base[0]) / float(base[2])
	return int(round((per / base_per - 1.0) * 100.0 / 5.0)) * 5


static func _thousands(n: int) -> String:
	return str(n) if n < 1000 else "%d,%03d" % [n / 1000, n % 1000]


func _watch() -> void:
	if SaveSystem.video_coins_left() <= 0:
		return
	if not AdManager.rewarded_ready():
		_status.text = "No video available right now. Try again in a little while." if AdManager.provider != null else "Videos are available in the Android app."
		return
	AdManager.show_rewarded(func(ok: bool) -> void:
		if not is_inside_tree():
			return
		if ok and SaveSystem.claim_video_coins():
			AudioManager.play("unlock", 1.0)
			_status.text = "+%d coins. Thank you for watching!" % Economy.VIDEO_COINS
		elif not ok:
			_status.text = "The video was closed early, so no coins this time."
		_refresh()
	)


## A small pile of coins: more coins for bigger bags.
class _Stack:
	extends Control
	var count: int = 1

	func _draw() -> void:
		var r: float = size.x * 0.24
		var n: int = 1 + count
		for k: int in n:
			var x: float = size.x * 0.5 + (float(k % 2) - 0.5) * r * 0.9 * float(mini(1, k))
			var y: float = size.y - r - 4.0 - float(k) * r * 0.42
			UIKit.draw_coin(self, Vector2(x, y), r)
