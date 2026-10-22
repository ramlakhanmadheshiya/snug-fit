extends SceneTree
## Proves every shipped level is fair and the chapters are paced as designed:
## - 30 levels per chapter, unique ids, level 1 introduces the chapter's idea;
## - the shape is one connected piece; the pieces cover it exactly (plus one
##   piece more on spare levels); pieces are connected and stored normalised;
## - the stored solution replays legally under every rule and fills the shape;
## - the solver finds very few solutions (at most three, allowing for a
##   symmetric shape), and a complete search;
## - each chapter uses its idea (turning, colours, pegs, a spare, flipping);
## - pieces per level never drop as a chapter goes on, and par is the piece count.
## Run: godot --headless --path . -s res://tests/levels_test.gd

const COUNT: int = 30
var failures: int = 0


func _init() -> void:
	var ids: Dictionary = {}
	var total: int = 0
	for cid: String in Palette.ids():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/levels/%s.json" % cid))
		if not data is Dictionary:
			_fail("%s: missing or invalid" % cid)
			continue
		var list: Array = data["levels"]
		if list.size() != COUNT:
			_fail("%s: has %d levels, expected %d" % [cid, list.size(), COUNT])
		if cid != "ch1" and not bool(list[0].get("intro", false)):
			_fail("%s: level 1 should introduce the chapter" % cid)
		var prev_par: int = 0
		for i: int in list.size():
			var lv: Dictionary = list[i]
			var id: String = str(lv["id"])
			if ids.has(id):
				_fail("duplicate id " + id)
			ids[id] = true
			total += 1
			_level(cid, i, lv)
			if i > 0 and int(lv["par"]) < prev_par:
				_fail("%s: fewer pieces than the level before" % id)
			if i > 0:
				prev_par = int(lv["par"])
	print("  ok  checked %d levels" % total)
	print("LEVELS: ", "FAIL (%d)" % failures if failures > 0 else "PASS")
	quit(1 if failures > 0 else 0)


func _fail(msg: String) -> void:
	failures += 1
	push_error("FAILED: " + msg)


func _level(cid: String, i: int, lv: Dictionary) -> void:
	var id: String = str(lv["id"])
	var shape: Array[Vector2i] = ShapeLibrary.cells(lv["shape"])
	if not ShapeLibrary.connected(shape):
		_fail("%s: the shape is in more than one part" % id)
	var area: int = 0
	var biggest: int = 0
	for pc: Dictionary in lv["pieces"]:
		var cells: Array[Vector2i] = FitSim.to_cells(pc["cells"])
		area += cells.size()
		biggest = maxi(biggest, cells.size())
		if not ShapeLibrary.connected(cells):
			_fail("%s: a piece is in more than one part" % id)
		if FitSim.key(cells) != FitSim.key(FitSim.normalize(cells)) or cells != FitSim.normalize(cells):
			_fail("%s: a piece isn't stored normalised" % id)
	var spare: bool = lv.has("spare")
	if spare and area <= shape.size():
		_fail("%s: a spare level needs one piece more than the shape" % id)
	if not spare and area != shape.size():
		_fail("%s: pieces cover %d cells, the shape has %d" % [id, area, shape.size()])
	if int(lv["par"]) != (lv["pieces"] as Array).size() - (1 if spare else 0):
		_fail("%s: par should be the number of pieces used" % id)
	if biggest > 6:
		_fail("%s: a piece is bigger than 6 cells" % id)
	# The stored solution replays legally and fills the shape.
	var pz: FitSim.Puzzle = FitSim.puzzle(lv)
	var occ: PackedInt32Array = FitSim.empty_occ(pz)
	var sol: Array = lv["solution"]
	var orients: Array[int] = FitSim.allowed(lv)
	for k: int in sol.size():
		var pl: Array = sol[k]
		if not int(pl[1]) in orients:
			_fail("%s: the solution turns a piece the rules don't let you turn" % id)
		var why: String = FitSim.check(pz, occ, int(pl[0]), int(pl[1]), Vector2i(int(pl[2]), int(pl[3])))
		if not why.is_empty():
			_fail("%s: solution step %d refused (%s)" % [id, k + 1, why])
			return
		occ = FitSim.occ_for(pz, sol.slice(0, k + 1))
	if not FitSim.is_full(pz, occ):
		_fail("%s: the solution doesn't fill the shape" % id)
	# Very few answers, and the search finished.
	var res: Dictionary = FitSim.solve(pz, {}, 50, 1000000)
	var sym: int = _symmetry(shape, orients)
	var allowed: int = 3 * sym
	if not bool(res["complete"]) or int(res["count"]) < 1 or int(res["count"]) > allowed:
		_fail("%s: %d solutions (complete %s), at most %d allowed" % [id, int(res["count"]), str(res["complete"]), allowed])
	# The chapter's idea is there.
	var rules: Dictionary = {
		"ch2": bool(lv.get("turn", false)),
		"ch3": not (lv.get("marks", []) as Array).is_empty(),
		"ch4": (lv.get("pegs", []) as Array).size() == int(lv["par"]),
		"ch5": spare,
		"ch6": bool(lv.get("flip", false)),
	}
	if rules.has(cid) and not bool(rules[cid]):
		_fail("%s: doesn't use its chapter's idea" % id)
	if cid == "ch1" and (bool(lv.get("turn", false)) or lv.has("marks") or lv.has("pegs") or spare):
		_fail("%s: Fit levels use no extra rules" % id)


func _symmetry(cells: Array[Vector2i], orients: Array[int]) -> int:
	var home: String = FitSim.key(cells)
	var n: int = 0
	for o: int in orients:
		if FitSim.key(FitSim.transform(cells, o)) == home:
			n += 1
	return maxi(1, n)
