extends Node
## Versioned local progress and settings, stored as JSON in user://.

const SAVE_PATH: String = "user://snug_fit_save.json"
const BACKUP_PATH: String = "user://snug_fit_save.bak"
const SAVE_VERSION: int = 1
## A video unlocks a cosmetic pack for this long.
const TRIAL_SECONDS: int = 60 * 60

var data: Dictionary = {}


func _ready() -> void:
	load_save()


func load_save() -> void:
	data = _defaults()
	for path: String in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_merge(data, parsed)
			break
	_apply_cosmetics()


## Writes atomically (a temp file renamed over the save) and keeps the last good
## save as a backup, so a crash mid-write never loses progress.
func save() -> void:
	data["version"] = SAVE_VERSION
	var tmp: String = SAVE_PATH + ".tmp"
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))


func get_setting(key: String, fallback: Variant = null) -> Variant:
	return (data["settings"] as Dictionary).get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save()
	if key in ["theme", "appearance"]:
		_apply_cosmetics()
	Events.setting_changed.emit(key, value)


## Applies the chosen theme (falling back to chapter colours once a trial ends)
## and the Auto / Dark / Light appearance.
func _apply_cosmetics() -> void:
	var theme: String = str(get_setting("theme", "chapters"))
	Palette.theme_id = theme if theme == "chapters" or owns("theme_pack") else "chapters"
	Palette.appearance = str(get_setting("appearance", "auto"))


func block_style() -> String:
	var id: String = str(get_setting("block_style", "soft"))
	return id if BlockStyles.is_free(id) or owns("block_pack") else "soft"


func level_record(level_id: String) -> Dictionary:
	return (data["levels"] as Dictionary).get(level_id, {})


func stars_for(level_id: String) -> int:
	return int(level_record(level_id).get("stars", 0))


func is_cleared(level_id: String) -> bool:
	return stars_for(level_id) > 0


## Stores a finished level and pays its rewards (each paid once: a first clear,
## each new star). Returns the coins earned.
func record_level(level_id: String, stars: int, moves: int) -> int:
	var prev: Dictionary = level_record(level_id)
	var before: int = int(prev.get("stars", 0))
	data["levels"][level_id] = {
		"stars": maxi(stars, before),
		"best": mini(moves, int(prev.get("best", 999))),
	}
	save()
	var earned: int = Economy.level_reward(before == 0, maxi(0, stars - before))
	if earned > 0:
		add_coins(earned)
	return earned


## Pays the chapter bonus the first time every level of a chapter is cleared.
## Returns the coins paid (0 if not yet, or already paid).
func reward_chapter(chapter_id: String) -> int:
	if flag("chapter_done_" + chapter_id) or Levels.cleared_in(chapter_id) < Levels.level_count(chapter_id):
		return 0
	set_flag("chapter_done_" + chapter_id)
	add_coins(Economy.CHAPTER_BONUS)
	return Economy.CHAPTER_BONUS


func total_stars() -> int:
	var total: int = 0
	for rec: Variant in (data["levels"] as Dictionary).values():
		if rec is Dictionary:
			total += int(rec.get("stars", 0))
	return total


func set_last_played(chapter_id: String, index: int) -> void:
	data["last"] = {"chapter": chapter_id, "index": index}
	save()


func last_played() -> Dictionary:
	return data.get("last", {"chapter": "ch1", "index": 0})


func flag(key: String) -> bool:
	return bool((data["flags"] as Dictionary).get(key, false))


func set_flag(key: String, value: bool = true) -> void:
	data["flags"][key] = value
	save()


# --- Coins and hints ----------------------------------------------------------

func coins() -> int:
	_grant_complete_bonus()
	return int(data.get("coins", Economy.START_COINS))


## Coins earned by playing (rewards, videos).
func add_coins(n: int) -> void:
	data["coins"] = coins() + maxi(0, n)
	save()
	Events.coins_changed.emit(coins())


## Coins bought in the shop: also remembered so a progress reset keeps them.
func add_bought_coins(n: int) -> void:
	data["bought_coins"] = int(data.get("bought_coins", 0)) + maxi(0, n)
	add_coins(n)


## Spends coins; false (and nothing spent) if there aren't enough.
func spend_coins(n: int) -> bool:
	if coins() < n:
		return false
	data["coins"] = coins() - n
	save()
	Events.coins_changed.emit(coins())
	return true


## Free hints left today: 1, or 3 for Supporters. Refills at local midnight.
func free_hints_left() -> int:
	var today: String = Time.get_date_string_from_system()
	var allowance: int = Economy.SUPPORTER_FREE_HINTS if is_supporter() else Economy.FREE_HINTS
	if str(data.get("hint_day", "")) != today:
		return allowance
	return maxi(0, allowance - int(data.get("hints_used", 0)))


## Pays for one hint: a free one if any are left today, else HINT_COST coins.
## False if neither is possible.
func spend_hint() -> bool:
	if free_hints_left() > 0:
		var today: String = Time.get_date_string_from_system()
		if str(data.get("hint_day", "")) != today:
			data["hint_day"] = today
			data["hints_used"] = 0
		data["hints_used"] = int(data.get("hints_used", 0)) + 1
		save()
		Events.hints_changed.emit(free_hints_left())
		return true
	return spend_coins(Economy.HINT_COST)


func video_coins_left() -> int:
	return _daily_left("video_coins", Economy.VIDEO_COINS_PER_DAY)


## Pays the coins for watching a video, within today's allowance.
func claim_video_coins() -> bool:
	if video_coins_left() <= 0:
		return false
	_daily_use("video_coins")
	add_coins(Economy.VIDEO_COINS)
	return true


## How many of a daily allowance are left today.
func _daily_left(key: String, per_day: int) -> int:
	var today: String = Time.get_date_string_from_system()
	if str(data.get(key + "_day", "")) != today:
		return per_day
	return maxi(0, per_day - int(data.get(key, 0)))


func _daily_use(key: String) -> void:
	var today: String = Time.get_date_string_from_system()
	if str(data.get(key + "_day", "")) != today:
		data[key + "_day"] = today
		data[key] = 0
	data[key] = int(data.get(key, 0)) + 1
	save()


## Levels finished since the last between-levels video (saved, so quitting doesn't skip one).
func wins_since_ad() -> int:
	return int(data.get("wins_since_ad", 0))


func set_wins_since_ad(n: int) -> void:
	data["wins_since_ad"] = maxi(0, n)
	save()


func is_supporter() -> bool:
	return owns("supporter_pack")


func set_supporter(on: bool) -> void:
	set_owned("supporter_pack", on)


# --- Purchases and trials ----------------------------------------------------

## True if the pack is bought (directly or through the Complete pack) or, for
## cosmetic packs, on a video trial that hasn't run out.
func owns(product: String) -> bool:
	var owned: Dictionary = data["owned"]
	if bool(owned.get(product, false)) or bool(owned.get("complete_pack", false)):
		return true
	if product == "supporter_pack" and flag("supporter"):
		return true
	return trial_left(product) > 0


func bought(product: String) -> bool:
	return bool((data["owned"] as Dictionary).get(product, false)) or bool((data["owned"] as Dictionary).get("complete_pack", false))


func set_owned(product: String, on: bool) -> void:
	data["owned"][product] = on
	if product in ["supporter_pack", "complete_pack"]:
		data["flags"]["supporter"] = bool(data["owned"].get("supporter_pack", false)) or bool(data["owned"].get("complete_pack", false))
	save()
	_apply_cosmetics()
	Events.purchases_changed.emit()
	if product in ["supporter_pack", "complete_pack"]:
		Events.supporter_changed.emit(is_supporter())


## Seconds left on a video trial (0 if none).
func trial_left(product: String) -> int:
	var until: int = int((data["trials"] as Dictionary).get(product, 0))
	return maxi(0, until - int(Time.get_unix_time_from_system()))


func start_trial(product: String) -> void:
	data["trials"][product] = int(Time.get_unix_time_from_system()) + TRIAL_SECONDS
	save()
	_apply_cosmetics()
	Events.purchases_changed.emit()


## "42:13" left on a trial (or "" when none).
func trial_clock(product: String) -> String:
	var left: int = trial_left(product)
	if left <= 0:
		return ""
	return "%d:%02d" % [left / 60, left % 60]


# --- Level keys -------------------------------------------------------------

func keys() -> int:
	_grant_complete_bonus()
	return int(data.get("keys", 0))


func add_keys(n: int) -> void:
	data["keys"] = keys() + maxi(0, n)
	save()
	Events.keys_changed.emit(keys())


## Spends a key to open one level for good. False if there are no keys.
func use_key(level_id: String) -> bool:
	if keys() <= 0:
		return false
	data["keys"] = keys() - 1
	data["unlocked"][level_id] = true
	save()
	Events.keys_changed.emit(keys())
	return true


func key_unlocked(level_id: String) -> bool:
	return bool((data["unlocked"] as Dictionary).get(level_id, false))


func video_keys_left() -> int:
	return _daily_left("video_keys", Economy.VIDEO_KEYS_PER_DAY)


func add_video_key() -> void:
	_daily_use("video_keys")
	add_keys(1)


# --- Chapter keys -----------------------------------------------------------

func chapter_keys() -> int:
	return int(data.get("chapter_keys", 0))


func add_chapter_keys(n: int) -> void:
	data["chapter_keys"] = chapter_keys() + maxi(0, n)
	save()
	Events.chapter_keys_changed.emit(chapter_keys())


## Spends a chapter key to open a whole locked chapter for good.
func use_chapter_key(chapter_id: String) -> bool:
	if chapter_keys() <= 0:
		return false
	data["chapter_keys"] = chapter_keys() - 1
	data["chapters_open"][chapter_id] = true
	save()
	Events.chapter_keys_changed.emit(chapter_keys())
	return true


func chapter_unlocked(chapter_id: String) -> bool:
	return bool((data["chapters_open"] as Dictionary).get(chapter_id, false))


func video_chapter_keys_left() -> int:
	return _daily_left("video_chapter_keys", Economy.VIDEO_CHAPTER_KEYS_PER_DAY)


func add_video_chapter_key() -> void:
	_daily_use("video_chapter_keys")
	add_chapter_keys(1)


## The Complete pack's 1,000 coins and 5 level keys, granted once, ever.
func _grant_complete_bonus() -> void:
	if bool((data["owned"] as Dictionary).get("complete_pack", false)) and not flag("complete_bonus"):
		data["flags"]["complete_bonus"] = true
		data["keys"] = int(data.get("keys", 0)) + Store.COMPLETE_KEYS
		data["coins"] = int(data.get("coins", Economy.START_COINS)) + Store.COMPLETE_COINS
		data["bought_coins"] = int(data.get("bought_coins", 0)) + Store.COMPLETE_COINS
		save()
		Events.coins_changed.emit(int(data["coins"]))
		Events.keys_changed.emit(int(data["keys"]))


func tips_given() -> int:
	return int(data.get("tips", 0))


func add_tip(_rupees: int = 0) -> void:
	data["tips"] = tips_given() + 1
	save()


## Clears stars and earned coins. Keeps settings, packs, keys and bought coins.
func reset_progress() -> void:
	data["levels"] = {}
	data["last"] = {"chapter": "ch1", "index": 0}
	data["flags"] = {"supporter": is_supporter(), "complete_bonus": flag("complete_bonus")}
	data["coins"] = Economy.START_COINS + int(data.get("bought_coins", 0))
	data["chapters_open"] = {}
	save()
	Events.coins_changed.emit(coins())


func _defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"levels": {},
		"last": {"chapter": "ch1", "index": 0},
		"flags": {},
		"owned": {},
		"keys": 0,
		"unlocked": {},
		"trials": {},
		"tips": 0,
		"coins": Economy.START_COINS,
		"bought_coins": 0,
		"chapter_keys": 0,
		"chapters_open": {},
		"hint_day": "",
		"hints_used": 0,
		"wins_since_ad": 0,
		"settings": {
			"music_volume": 0.5,
			"sound_volume": 0.75,
			"haptics": true,
			"lift": true,
			"appearance": "auto",
			"theme": "chapters",
			"block_style": "soft",
		},
	}


## Copies saved values over defaults so new keys appear after updates.
func _merge(into: Dictionary, from: Dictionary) -> void:
	for key: Variant in from:
		if into.has(key) and into[key] is Dictionary and from[key] is Dictionary and not key in ["levels", "unlocked", "chapters_open"]:
			_merge(into[key], from[key])
		else:
			into[key] = from[key]
