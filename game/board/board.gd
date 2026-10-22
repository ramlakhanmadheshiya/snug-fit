class_name Board
extends Control
## The playing field: the shape to fill, the tray of pieces under it, dragging,
## turning and flipping, the rules (through FitSim) and all the juice.
## In demo mode it quietly solves levels by itself (the home screen).

## A move landed: a piece placed, moved, turned or flipped on the shape.
signal placed(piece: int)
## A drop or tap that the rules refused ("outside", "overlap", "colour", "peg", "still").
signal rejected(reason: String)
signal solved
## Any touch at all (the game screen hides its tips).
signal touched

const DRAG_START: float = 10.0
## How far above the finger a carried piece floats on touch screens, in cells.
const LIFT_CELLS: float = 1.2
const MAX_CELL: float = 92.0
const PLACE_DB: float = -4.0

var demo: bool = false
var quiet: bool = false
## False draws only the shape (share card).
var show_tray: bool = true
## What the board sits on (see-through shapes are mixed onto it, so they stay seamless).
var bg_color: Color = Color(0, 0, 0, 0)
## No input while a card, intro or tutorial step is in charge.
var locked: bool = false
var level: Dictionary = {}
var pal: Dictionary = Palette.get_palette("ch1")
var pz: FitSim.Puzzle
var style: String = "soft"

## Per piece: on the shape or in the tray, its orientation, and where it sits.
var on_board: Array[bool] = []
var orient: Array[int] = []
var at: Array[Vector2i] = []
var occ: PackedInt32Array = PackedInt32Array()
var moves: int = 0
var selected: int = -1
var is_solved: bool = false

var cs: float = 64.0
var origin: Vector2 = Vector2.ZERO
var ts: float = 32.0
var slots: Array[Rect2] = []
var tray_rect: Rect2 = Rect2()

var _press: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_pos: Vector2 = Vector2.ZERO
## Pointer offset from the carried piece's centre, in cells.
var _grab: Vector2 = Vector2.ZERO
var _drag_from: Array = []
var _drag_k: float = 0.0
var _lift: float = 0.0
var _pop: Array[float] = []
var _spin: Array[float] = []
var _flipx: Array[float] = []
var _wiggle: Array[float] = []
var _flights: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _hint: Array = []
var _clock: float = 0.0
var _win_t: float = -1.0
var _win_from: Vector2 = Vector2.ZERO
var _fade: float = 1.0
var _demo_levels: Array = []
var _demo_index: int = 0
var _demo_step: int = 0
var _demo_wait: float = 0.0
var _demo_order: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP if not demo else Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_rng.seed = 11


func setup(lv: Dictionary, palette: Dictionary) -> void:
	level = lv
	pal = palette
	pz = FitSim.puzzle(lv)
	style = SaveSystem.block_style() if not demo else "soft"
	var n: int = pz.pieces.size()
	on_board.resize(n)
	orient.resize(n)
	at.resize(n)
	_pop.resize(n)
	_spin.resize(n)
	_flipx.resize(n)
	_wiggle.resize(n)
	reset()


## Plays these levels one after another, by itself (home screen, chapter cards).
func play_demo(levels: Array, palette: Dictionary) -> void:
	demo = true
	quiet = true
	locked = true
	_demo_levels = levels
	_demo_index = 0
	if not levels.is_empty():
		setup(levels[0], palette)
		_start_demo()


## Everything back in the tray, as the level first shows it.
func reset() -> void:
	occ = FitSim.empty_occ(pz)
	for i: int in pz.pieces.size():
		on_board[i] = false
		orient[i] = 0
		at[i] = Vector2i.ZERO
		_pop[i] = 0.0
		_spin[i] = 0.0
		_flipx[i] = 1.0
		_wiggle[i] = 0.0
	moves = 0
	selected = -1
	is_solved = false
	_hint = []
	_flights.clear()
	_win_t = -1.0
	_dragging = false
	_press = -1
	_layout()
	queue_redraw()


func can_turn() -> bool:
	return bool(level.get("turn", false)) or bool(level.get("flip", false))


func can_flip() -> bool:
	return bool(level.get("flip", false))


## Pieces on the shape as {piece: [o, x, y]} (what the solver calls fixed).
func placements() -> Dictionary:
	var out: Dictionary = {}
	for i: int in on_board.size():
		if on_board[i]:
			out[i] = [orient[i], at[i].x, at[i].y]
	return out


func piece_color(i: int) -> Color:
	return Palette.block_color(pal, pz.colors[i], pz.has_marks)


func cells_of(i: int) -> Array[Vector2i]:
	return FitSim.transform(pz.pieces[i], orient[i])


# --- Layout ----------------------------------------------------------------------

func _layout() -> void:
	if pz == null or size.x <= 0.0:
		return
	var tray_h: float = clampf(size.y * 0.36, 170.0, 460.0)
	if demo:
		tray_h = clampf(size.y * 0.3, 60.0, 240.0)
	if not show_tray:
		tray_h = 0.0
	var board_h: float = size.y - tray_h - 18.0
	cs = minf(minf(size.x * 0.94 / float(pz.w), board_h * 0.96 / float(pz.h)), MAX_CELL)
	cs = floorf(cs)
	origin = Vector2((size.x - cs * pz.w) * 0.5, (board_h - cs * pz.h) * 0.5)
	origin = origin.floor()
	tray_rect = Rect2(Vector2(0, size.y - tray_h), Vector2(size.x, tray_h))
	_layout_tray()
	queue_redraw()


## Square slots (so turning never reflows), in centred rows, as big as fit.
func _layout_tray() -> void:
	var n: int = pz.pieces.size()
	slots.clear()
	slots.resize(n)
	var dims: Array[int] = []
	for i: int in n:
		var sz: Vector2i = FitSim.size_of(pz.pieces[i])
		dims.append(maxi(sz.x, sz.y) if can_turn() else 0)
	var scale: float = minf(cs * 0.66, 50.0)
	while scale > 10.0:
		if _pack(scale, dims, false):
			break
		scale -= 2.0
	ts = scale
	_pack(scale, dims, true)


func _pack(scale: float, dims: Array[int], commit: bool) -> bool:
	var pad: float = maxf(12.0, scale * 0.38)
	var rows: Array = [[]]
	var widths: Array[float] = [0.0]
	var heights: Array[float] = [0.0]
	for i: int in pz.pieces.size():
		var sz: Vector2i = FitSim.size_of(pz.pieces[i])
		var w: float = (float(dims[i]) if dims[i] > 0 else float(sz.x)) * scale + pad
		var h: float = (float(dims[i]) if dims[i] > 0 else float(sz.y)) * scale + pad
		if widths[-1] + w > tray_rect.size.x and not (rows[-1] as Array).is_empty():
			rows.append([])
			widths.append(0.0)
			heights.append(0.0)
		(rows[-1] as Array).append([i, w, h])
		widths[-1] += w
		heights[-1] = maxf(heights[-1], h)
	var total_h: float = 0.0
	for h: float in heights:
		total_h += h
	if total_h > tray_rect.size.y:
		return false
	if commit:
		var y: float = tray_rect.position.y + (tray_rect.size.y - total_h) * 0.5
		for r: int in rows.size():
			var x: float = (tray_rect.size.x - widths[r]) * 0.5
			for item: Array in rows[r]:
				slots[int(item[0])] = Rect2(Vector2(x, y + (heights[r] - float(item[2])) * 0.5), Vector2(float(item[1]), float(item[2])))
				x += float(item[1])
			y += heights[r]
	return true


func cell_center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cs


## Where piece i sits in the tray (its centre).
func tray_center(i: int) -> Vector2:
	return slots[i].get_center() if i < slots.size() else Vector2.ZERO


## The centre of piece i at a placement on the shape.
func board_center(i: int, o: int, top_left: Vector2i) -> Vector2:
	var sz: Vector2i = FitSim.size_of(FitSim.transform(pz.pieces[i], o))
	return origin + (Vector2(top_left) + Vector2(sz) * 0.5) * cs


# --- Input -----------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if locked or is_solved or demo:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			_on_press(mb.position)
		else:
			_on_release(mb.position)
		accept_event()
	elif event is InputEventMouseMotion and _press >= 0:
		var mm: InputEventMouseMotion = event
		_drag_pos = mm.position
		if not _dragging and _drag_pos.distance_to(_press_pos) > DRAG_START:
			_begin_drag()
		accept_event()


func _piece_at(p: Vector2) -> int:
	var c: Vector2i = Vector2i(floori((p.x - origin.x) / cs), floori((p.y - origin.y) / cs))
	if c.x >= 0 and c.y >= 0 and c.x < pz.w and c.y < pz.h:
		var k: int = occ[c.y * pz.w + c.x]
		if k >= 0:
			return k
	var best: int = -1
	var best_d: float = INF
	for i: int in slots.size():
		if on_board[i] or _flying(i):
			continue
		var r: Rect2 = slots[i].grow(6.0)
		if r.has_point(p):
			var d: float = r.get_center().distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = i
	return best


func _on_press(p: Vector2) -> void:
	touched.emit()
	_press = _piece_at(p)
	_press_pos = p
	_drag_pos = p
	_dragging = false
	if _press >= 0:
		selected = _press
		queue_redraw()


func _begin_drag() -> void:
	var i: int = _press
	_dragging = true
	_drag_k = 0.0
	_lift = LIFT_CELLS if _touch_lift() else 0.25
	if on_board[i]:
		_drag_from = [orient[i], at[i]]
		var c: Vector2 = board_center(i, orient[i], at[i])
		_grab = (_press_pos - c) / cs
		_lift_off(i)
	else:
		_drag_from = []
		_grab = Vector2.ZERO
	_play("pick", 1.0 + 0.04 * float(i % 4))
	Haptics.tap(8)
	var tw: Tween = create_tween()
	tw.tween_property(self, "_drag_k", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _touch_lift() -> bool:
	return bool(SaveSystem.get_setting("lift", true)) and (DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"))


## Where a carried piece is drawn: centre and cell size.
func _drag_view() -> Array:
	var i: int = _press
	var size_now: float = lerpf(ts, cs, _drag_k)
	var c: Vector2 = _drag_pos - _grab * size_now - Vector2(0, _lift * cs * _drag_k)
	var sz: Vector2i = FitSim.size_of(cells_of(i))
	return [c, size_now, c - Vector2(sz) * size_now * 0.5]


## The cell a carried piece would snap to, or (-99, -99) when it's over the tray.
func _snap() -> Vector2i:
	var view: Array = _drag_view()
	var tl: Vector2 = (view[2] as Vector2 - origin) / cs
	var cell: Vector2i = Vector2i(roundi(tl.x), roundi(tl.y))
	var sz: Vector2i = FitSim.size_of(cells_of(_press))
	var center: Vector2 = view[0]
	if center.y > tray_rect.position.y + cs * 0.3:
		return Vector2i(-99, -99)
	if cell.x + sz.x <= 0 or cell.y + sz.y <= 0 or cell.x >= pz.w or cell.y >= pz.h:
		return Vector2i(-99, -99)
	return cell


func _on_release(p: Vector2) -> void:
	var i: int = _press
	_press = -1
	if i < 0:
		return
	if not _dragging:
		_tap(i)
		return
	_dragging = false
	_drag_pos = p
	_press = i
	var view: Array = _drag_view()
	var cell: Vector2i = _snap()
	_press = -1
	if cell.x == -99:
		_send_home(i, view, false)
		return
	var why: String = FitSim.check(pz, occ, i, orient[i], cell)
	if not why.is_empty():
		_send_home(i, view, true)
		rejected.emit(why)
		return
	var same: bool = not _drag_from.is_empty() and int(_drag_from[0]) == orient[i] and (_drag_from[1] as Vector2i) == cell
	_put(i, cell, not same)


## Taps turn a piece (where the rules allow); on the shape it turns in place.
func _tap(i: int) -> void:
	if not can_turn():
		_wiggle[i] = 1.0
		_play("reject", 1.2, -8.0)
		rejected.emit("still")
		return
	turn_piece(i, false)


## Turns (or flips) piece i. On the shape it stays put if it still fits,
## otherwise it goes back to the tray.
func turn_piece(i: int, flip: bool) -> void:
	if i < 0 or i >= on_board.size() or is_solved:
		return
	selected = i
	var was_on: bool = on_board[i]
	var center: Vector2 = board_center(i, orient[i], at[i]) if was_on else Vector2.ZERO
	if was_on:
		_lift_off(i)
	orient[i] = FitSim.flipped(orient[i]) if flip else FitSim.turned(orient[i])
	if flip:
		_flipx[i] = -1.0
		create_tween().tween_method(func(v: float) -> void: _flipx[i] = v, -1.0, 1.0, 0.22).set_trans(Tween.TRANS_SINE)
		_play("flip", 1.0)
	else:
		_spin[i] = -PI * 0.5
		create_tween().tween_method(func(v: float) -> void: _spin[i] = v, -PI * 0.5, 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_play("turn", 1.0 + 0.03 * float(orient[i] % 4))
	Haptics.tap(6)
	if was_on:
		var sz: Vector2i = FitSim.size_of(cells_of(i))
		var tl: Vector2 = (center - origin) / cs - Vector2(sz) * 0.5
		var cell: Vector2i = Vector2i(roundi(tl.x), roundi(tl.y))
		if FitSim.check(pz, occ, i, orient[i], cell).is_empty():
			_put(i, cell, true)
			return
		_flights.append({"i": i, "from": center, "from_size": cs, "t": 0.0, "dur": 0.28})
		_play("back", 0.9)
	queue_redraw()


func turn_selected() -> void:
	if selected >= 0 and can_turn():
		turn_piece(selected, false)


func flip_selected() -> void:
	if selected >= 0 and can_flip():
		turn_piece(selected, true)


func _lift_off(i: int) -> void:
	on_board[i] = false
	for k: int in occ.size():
		if occ[k] == i:
			occ[k] = -1


## Lands piece i on the shape; counts a move if it changed anything.
func _put(i: int, cell: Vector2i, counts: bool) -> void:
	on_board[i] = true
	at[i] = cell
	for c: Vector2i in cells_of(i):
		occ[pz.idx(cell + c)] = i
	_pop[i] = 1.0
	if counts:
		moves += 1
	if not _hint.is_empty() and FitSim.same_cells(pz, [i, orient[i], cell.x, cell.y], _hint):
		_hint = []
	var filled: int = 0
	for k: int in occ.size():
		if occ[k] >= 0:
			filled += 1
	var step: int = int(float(filled) / float(maxi(1, pz.area)) * 8.0)
	if not quiet:
		AudioManager.play_note("place", step, PLACE_DB)
	Haptics.tap(14)
	_burst(i, 7)
	if counts:
		placed.emit(i)
	queue_redraw()
	if FitSim.is_full(pz, occ):
		_win(i)


## Back to the tray, gliding. `refused` adds a soft thud and a shake.
func _send_home(i: int, view: Array, refused: bool) -> void:
	_flights.append({"i": i, "from": view[0], "from_size": view[1], "t": 0.0, "dur": 0.26})
	if refused:
		_wiggle[i] = 1.0
		_play("reject", 1.0, -3.0)
		Haptics.tap(20)
	else:
		_play("back", 1.0, -6.0)
	queue_redraw()


func _flying(i: int) -> bool:
	for f: Dictionary in _flights:
		if int(f["i"]) == i:
			return true
	return false


# --- Hints -----------------------------------------------------------------------

## Outlines where a piece goes ([piece, o, x, y]) and turns the tray piece to match.
func show_hint(pl: Array) -> void:
	_hint = pl.duplicate()
	var i: int = int(pl[0])
	if not on_board[i] and orient[i] != int(pl[1]):
		orient[i] = int(pl[1])
		_spin[i] = -PI * 0.5
		create_tween().tween_method(func(v: float) -> void: _spin[i] = v, -PI * 0.5, 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	selected = i
	_hint_pop()
	queue_redraw()


func _hint_pop() -> void:
	_play("hint", 1.0)


func clear_hint() -> void:
	_hint = []
	queue_redraw()


func has_hint() -> bool:
	return not _hint.is_empty()


## Sends these pieces back to the tray (a hint undoing wrong guesses).
func send_back(pieces: Array) -> void:
	for i: int in pieces:
		if on_board[i]:
			var c: Vector2 = board_center(i, orient[i], at[i])
			_lift_off(i)
			_flights.append({"i": i, "from": c, "from_size": cs, "t": 0.0, "dur": 0.3})
	if not pieces.is_empty():
		_play("back", 0.9)
	queue_redraw()


## Places a piece directly (tutorial, demo and tests).
func place_now(i: int, o: int, cell: Vector2i, counts: bool = true) -> bool:
	if on_board[i]:
		_lift_off(i)
	orient[i] = o
	if not FitSim.check(pz, occ, i, o, cell).is_empty():
		return false
	_put(i, cell, counts)
	return true


## Shows the shape already filled ({piece: [o, x, y]}), at rest (share card).
func show_filled(fixed: Dictionary) -> void:
	for i: Variant in fixed:
		var pl: Array = fixed[i]
		on_board[int(i)] = true
		orient[int(i)] = int(pl[0])
		at[int(i)] = Vector2i(int(pl[1]), int(pl[2]))
		for c: Vector2i in cells_of(int(i)):
			occ[pz.idx(at[int(i)] + c)] = int(i)
	is_solved = true
	set_process(false)
	queue_redraw()


# --- Winning -------------------------------------------------------------------

func _win(last: int) -> void:
	is_solved = true
	_hint = []
	selected = -1
	_win_t = 0.0
	_win_from = board_center(last, orient[last], at[last])
	if not quiet:
		Haptics.tap(30)
	for k: int in 3:
		_burst(last, 6)
	solved.emit()


# --- Demo --------------------------------------------------------------------------

func _start_demo() -> void:
	# Build bottom-up, the way a person might.
	var sol: Array = (level.get("solution", []) as Array).duplicate()
	sol.sort_custom(func(a: Array, b: Array) -> bool: return int(a[3]) * 100 + int(a[2]) > int(b[3]) * 100 + int(b[2]))
	_demo_order = sol
	_demo_step = 0
	_demo_wait = 0.9
	_fade = 0.0
	create_tween().tween_property(self, "_fade", 1.0, 0.4)


func _demo_tick(delta: float) -> void:
	if _demo_levels.is_empty():
		return
	_demo_wait -= delta
	if _demo_wait > 0.0:
		return
	if is_solved:
		_demo_index = (_demo_index + 1) % _demo_levels.size()
		var tw: Tween = create_tween()
		tw.tween_property(self, "_fade", 0.0, 0.35)
		tw.tween_callback(func() -> void:
			setup(_demo_levels[_demo_index], pal)
			_start_demo())
		_demo_wait = 10.0
		return
	if _demo_step >= _demo_order.size():
		return
	var pl: Array = _demo_order[_demo_step]
	_demo_step += 1
	var i: int = int(pl[0])
	var from: Vector2 = tray_center(i)
	var from_size: float = ts
	orient[i] = int(pl[1])
	var target: Vector2i = Vector2i(int(pl[2]), int(pl[3]))
	_flights.append({"i": i, "from": from, "from_size": from_size, "to": board_center(i, orient[i], target), "to_size": cs, "t": 0.0, "dur": 0.55, "land": target})
	_demo_wait = 0.75 if _demo_step < _demo_order.size() else 2.6


# --- Frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if demo:
		_demo_tick(delta)
	for i: int in _pop.size():
		_pop[i] = maxf(0.0, _pop[i] - delta * 4.0)
		_wiggle[i] = maxf(0.0, _wiggle[i] - delta * 3.0)
	var done: Array[Dictionary] = []
	for f: Dictionary in _flights:
		f["t"] = float(f["t"]) + delta / float(f["dur"])
		if float(f["t"]) >= 1.0:
			done.append(f)
	for f: Dictionary in done:
		_flights.erase(f)
		if f.has("land"):
			place_now(int(f["i"]), orient[int(f["i"])], f["land"], false)
	var alive: Array[Dictionary] = []
	for p: Dictionary in _particles:
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) > 0.0:
			p["v"] = (p["v"] as Vector2) * (1.0 - delta * 2.5) + Vector2(0, 420.0) * delta
			p["p"] = (p["p"] as Vector2) + (p["v"] as Vector2) * delta
			alive.append(p)
	_particles = alive
	if _win_t >= 0.0:
		_win_t += delta
	queue_redraw()


func _burst(i: int, per_cell: int) -> void:
	if demo and _particles.size() > 60:
		return
	var col: Color = piece_color(i)
	var cells: Array[Vector2i] = cells_of(i)
	for c: Vector2i in cells:
		var center: Vector2 = cell_center(at[i] + c)
		for k: int in maxi(1, per_cell / cells.size() + 1):
			var a: float = _rng.randf() * TAU
			_particles.append({"p": center + Vector2(cos(a), sin(a)) * cs * 0.4, "v": Vector2(cos(a), sin(a) - 0.6) * _rng.randf_range(80.0, 260.0), "life": _rng.randf_range(0.35, 0.7), "max": 0.7, "c": col, "s": _rng.randf_range(0.06, 0.12) * cs})


func _play(id: String, pitch: float, db: float = 0.0) -> void:
	if not quiet:
		AudioManager.play(id, pitch, db)


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	if pz == null:
		return
	var ink: Color = pal["ink"]
	var dark: bool = bool(pal.get("dark", false))
	var a: float = _fade
	var bg: Color = bg_color if bg_color.a > 0.0 else (pal["top"] as Color).lerp(pal["bottom"], 0.4)
	# The shape: one soft plate, then a quiet well for every cell.
	var plate: Dictionary = {}
	for y: int in pz.h:
		for x: int in pz.w:
			if pz.inside[y * pz.w + x] == 1:
				plate[Vector2i(x, y)] = true
	var plate_cells: Array[Vector2i] = []
	plate_cells.assign(plate.keys())
	var plate_c: Color = BlockStyles.solid(bg, Color(ink, 0.05 if not dark else 0.07))
	BlockStyles._blob(self, plate, origin, cs, -cs * 0.12, cs * 0.3, Color(plate_c, a))
	var well: StyleBoxFlat = StyleBoxFlat.new()
	well.bg_color = Color(BlockStyles.solid(plate_c, Color(ink, 0.06 if not dark else 0.08)), a)
	well.set_corner_radius_all(int(cs * 0.2))
	well.corner_detail = 6
	for c: Vector2i in plate_cells:
		var r: Rect2 = Rect2(origin + Vector2(c) * cs, Vector2(cs, cs)).grow(-cs * 0.06)
		draw_style_box(well, r)
		var k: int = c.y * pz.w + c.x
		if pz.marks[k] >= 0 and occ[k] < 0:
			var mc: Color = Palette.block_color(pal, pz.marks[k], true)
			var m: StyleBoxFlat = well.duplicate()
			m.bg_color = Color(mc, 0.28 * a)
			m.border_color = Color(mc, 0.9 * a)
			m.set_border_width_all(maxi(2, int(cs * 0.05)))
			draw_style_box(m, r.grow(-cs * 0.06))
		if pz.pegs[k] == 1 and occ[k] < 0:
			_draw_peg(cell_center(c), false, a)
	# Where the hint says a piece goes.
	if not _hint.is_empty():
		var hi: int = int(_hint[0])
		var pulse: float = 0.5 + 0.5 * sin(_clock * 4.0)
		var cells: Array[Vector2i] = FitSim.transform(pz.pieces[hi], int(_hint[1]))
		var hset: Dictionary = {}
		for c: Vector2i in cells:
			hset[c] = true
		var tl: Vector2 = origin + Vector2(int(_hint[2]), int(_hint[3])) * cs
		BlockStyles._blob(self, hset, tl, cs, cs * 0.02, cs * 0.22, BlockStyles.solid(plate_c, Color(piece_color(hi), 0.55 + 0.3 * pulse)))
		BlockStyles._blob(self, hset, tl, cs, cs * 0.16, cs * 0.16, BlockStyles.solid(plate_c, Color(piece_color(hi), 0.14)))
	# Pieces on the shape.
	for i: int in on_board.size():
		if on_board[i] and not (_dragging and _press == i):
			var c: Vector2 = board_center(i, orient[i], at[i])
			var s: float = 1.0 + 0.1 * sin(_pop[i] * PI) * _pop[i]
			_draw_piece(i, c, cs * s, 0.0, a)
			for cc: Vector2i in cells_of(i):
				var k: int = pz.idx(at[i] + cc)
				if pz.pegs[k] == 1:
					_draw_peg(cell_center(at[i] + cc), true, a)
	# The finish: a wave of light across the filled shape.
	if _win_t >= 0.0:
		for c: Vector2i in plate_cells:
			var center: Vector2 = cell_center(c)
			var d: float = center.distance_to(_win_from) / (cs * 9.0)
			var t: float = clampf((_win_t - d * 0.6) / 0.45, 0.0, 1.0)
			if t > 0.0 and t < 1.0:
				var glow: StyleBoxFlat = well.duplicate()
				glow.bg_color = Color(1, 1, 1, 0.55 * sin(t * PI))
				draw_style_box(glow, Rect2(origin + Vector2(c) * cs, Vector2(cs, cs)).grow(-cs * 0.04 + cs * 0.06 * sin(t * PI)))
		var ring_t: float = clampf(_win_t / 0.9, 0.0, 1.0)
		if ring_t < 1.0:
			draw_arc(_win_from, cs * (0.6 + ring_t * 6.0), 0.0, TAU, 64, Color(pal["accent"], 0.5 * (1.0 - ring_t)), 4.0 * (1.0 - ring_t) + 1.0, true)
	# The tray.
	for i: int in slots.size():
		if on_board[i] or _flying(i) or (_dragging and _press == i):
			continue
		var wig: float = sin(_wiggle[i] * PI * 5.0) * _wiggle[i] * 8.0
		var center: Vector2 = tray_center(i) + Vector2(wig, 0)
		var s: float = ts
		if selected == i and (can_flip() or not _hint.is_empty()):
			draw_circle(center, ts * 1.9 + 4.0 * sin(_clock * 3.0), Color(pal["accent"], 0.12 * a), true, -1.0, true)
		if not _hint.is_empty() and int(_hint[0]) == i:
			s *= 1.0 + 0.06 * sin(_clock * 5.0)
		_draw_piece(i, center, s, 0.0, a)
	for f: Dictionary in _flights:
		var i2: int = int(f["i"])
		var t2: float = ease(clampf(float(f["t"]), 0.0, 1.0), -2.0)
		var to: Vector2 = f.get("to", tray_center(i2))
		var to_size: float = float(f.get("to_size", ts))
		var p: Vector2 = (f["from"] as Vector2).lerp(to, t2)
		p.y -= sin(t2 * PI) * cs * 0.6
		_draw_piece(i2, p, lerpf(float(f["from_size"]), to_size, t2), sin(t2 * PI) * 0.6, a)
	# The carried piece, its landing spot first.
	if _dragging and _press >= 0:
		var view: Array = _drag_view()
		var cell: Vector2i = _snap()
		if cell.x != -99:
			var ok: bool = FitSim.check(pz, occ, _press, orient[_press], cell).is_empty()
			var gset: Dictionary = {}
			for c: Vector2i in cells_of(_press):
				gset[c] = true
			var gc: Color = BlockStyles.solid(plate_c, Color(piece_color(_press), 0.4) if ok else Color(pal["target"], 0.3))
			BlockStyles._blob(self, gset, origin + Vector2(cell) * cs, cs, cs * 0.06, cs * 0.2, gc)
		_draw_piece(_press, view[0], view[1], _drag_k, 1.0)
	for p2: Dictionary in _particles:
		var k2: float = float(p2["life"]) / float(p2["max"])
		var sz2: float = float(p2["s"]) * k2
		draw_rect(Rect2(p2["p"] as Vector2 - Vector2(sz2, sz2) * 0.5, Vector2(sz2, sz2)), Color(p2["c"] as Color, k2))


## Piece i, centred at c with cell size s; spin and flip animations applied.
func _draw_piece(i: int, c: Vector2, s: float, lift: float, alpha: float) -> void:
	var cells: Array[Vector2i] = cells_of(i)
	var sz: Vector2 = Vector2(FitSim.size_of(cells))
	draw_set_transform(c, _spin[i], Vector2(_flipx[i], 1.0))
	BlockStyles.draw_piece(self, style, cells, -sz * s * 0.5, s, piece_color(i), pal, lift, alpha)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_peg(c: Vector2, covered: bool, alpha: float) -> void:
	var r: float = cs * 0.13
	if covered:
		draw_circle(c, r * 1.15, Color(0, 0, 0, 0.18 * alpha), true, -1.0, true)
		draw_circle(c, r, Color(1, 1, 1, 0.92 * alpha), true, -1.0, true)
		draw_circle(c, r * 0.45, Color(pal["ink"], 0.35 * alpha), true, -1.0, true)
	else:
		draw_circle(c + Vector2(0, r * 0.25), r, Color(0, 0, 0, 0.12 * alpha), true, -1.0, true)
		draw_circle(c, r, Color(pal["ink"], 0.6 * alpha), true, -1.0, true)
		draw_circle(c - Vector2(r, r) * 0.3, r * 0.3, Color(1, 1, 1, 0.5 * alpha), true, -1.0, true)
