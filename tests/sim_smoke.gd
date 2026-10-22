extends SceneTree
## The rules (FitSim): orientations, turning and flipping, every refusal reason,
## the solver (counting, identical pieces, spare pieces, fixed pieces), stars,
## and the economy's rewards.
## Run: godot --headless --path . -s res://tests/sim_smoke.gd

var failures: int = 0


func _init() -> void:
	_orientations()
	_checks()
	_solver()
	_spare_and_fixed()
	_stars()
	_rewards()
	print("SIM SMOKE: ", "FAIL (%d)" % failures if failures > 0 else "PASS")
	quit(1 if failures > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok  ", label)
	else:
		failures += 1
		push_error("FAILED: " + label)


func _cells(raw: Array) -> Array[Vector2i]:
	return FitSim.to_cells(raw)


func _orientations() -> void:
	var l: Array[Vector2i] = _cells([[0, 0], [0, 1], [0, 2], [1, 2]])
	_check(FitSim.key(FitSim.transform(l, 0)) == FitSim.key(l), "orientation 0 leaves a piece as it is")
	_check(FitSim.key(FitSim.transform(l, 1)) == FitSim.key(_cells([[0, 0], [1, 0], [2, 0], [0, 1]])), "a quarter turn is clockwise on screen")
	_check(FitSim.key(FitSim.transform(l, 4)) == FitSim.key(_cells([[1, 0], [1, 1], [1, 2], [0, 2]])), "orientation 4 mirrors left-right")
	var ok: bool = true
	for o: int in 8:
		var turned: String = FitSim.key(FitSim.transform(l, FitSim.turned(o)))
		var by_hand: String = FitSim.key(FitSim.transform(FitSim.transform(l, o), 1))
		var flipped: String = FitSim.key(FitSim.transform(l, FitSim.flipped(o)))
		var mirrored: String = FitSim.key(FitSim.transform(FitSim.transform(l, o), 4))
		ok = ok and turned == by_hand and flipped == mirrored
	_check(ok, "turned() and flipped() match turning and mirroring what's on screen, from every orientation")
	_check(FitSim.allowed({}).size() == 1 and FitSim.allowed({"turn": true}).size() == 4 and FitSim.allowed({"flip": true}).size() == 8, "fixed, turning and flipping levels allow 1, 4 and 8 orientations")
	var square: Array[Vector2i] = _cells([[0, 0], [1, 0], [0, 1], [1, 1]])
	_check(FitSim.class_key(square, [0, 1, 2, 3]) == FitSim.key(square), "a square looks the same every way round")


## A 2 x 3 box filled by an L and an upright domino.
func _box() -> Dictionary:
	return {"shape": ["##", "##", "##"], "pieces": [
		{"cells": [[0, 0], [0, 1], [0, 2], [1, 2]], "color": 0},
		{"cells": [[0, 0], [0, 1]], "color": 1},
	], "solution": [[0, 0, 0, 0], [1, 0, 1, 0]]}


func _checks() -> void:
	var lv: Dictionary = {"shape": ["###", "#.."], "pieces": [
		{"cells": [[0, 0], [1, 0]], "color": 0}, {"cells": [[0, 0], [0, 1]], "color": 1}, {"cells": [[0, 0]], "color": 2}]}
	var pz: FitSim.Puzzle = FitSim.puzzle(lv)
	var occ: PackedInt32Array = FitSim.empty_occ(pz)
	_check(FitSim.check(pz, occ, 0, 0, Vector2i(0, 0)).is_empty(), "a piece fits inside the shape")
	_check(FitSim.check(pz, occ, 0, 0, Vector2i(2, 0)) == "outside", "sticking out of the grid is refused")
	_check(FitSim.check(pz, occ, 0, 0, Vector2i(1, 1)) == "outside", "a cell outside the shape is refused")
	occ = FitSim.occ_for(pz, [[0, 0, 0, 0]])
	_check(FitSim.check(pz, occ, 1, 0, Vector2i(0, 0)) == "overlap", "pieces can't overlap")
	_check(FitSim.check(pz, occ, 0, 0, Vector2i(0, 0)).is_empty(), "a piece can be put back where it already is")
	var painted: Dictionary = lv.duplicate(true)
	painted["marks"] = [[2, 0, 2]]
	var pp: FitSim.Puzzle = FitSim.puzzle(painted)
	_check(FitSim.check(pp, FitSim.empty_occ(pp), 0, 0, Vector2i(1, 0)) == "colour", "a coloured cell refuses another colour")
	_check(FitSim.check(pp, FitSim.empty_occ(pp), 2, 0, Vector2i(2, 0)).is_empty(), "a coloured cell takes its own colour")
	var pegged: Dictionary = lv.duplicate(true)
	pegged["pegs"] = [[0, 0], [1, 0]]
	var pg: FitSim.Puzzle = FitSim.puzzle(pegged)
	_check(FitSim.check(pg, FitSim.empty_occ(pg), 0, 0, Vector2i(0, 0)) == "peg", "covering two pegs is refused")
	_check(FitSim.check(pg, FitSim.empty_occ(pg), 2, 0, Vector2i(2, 0)) == "peg", "covering no peg is refused")
	_check(FitSim.check(pg, FitSim.empty_occ(pg), 2, 0, Vector2i(1, 0)).is_empty(), "covering exactly one peg is fine")
	var full: FitSim.Puzzle = FitSim.puzzle(_box())
	_check(not FitSim.is_full(full, FitSim.occ_for(full, [[0, 0, 0, 0]])), "half a shape isn't full")
	_check(FitSim.is_full(full, FitSim.occ_for(full, _box()["solution"])), "the solution fills the shape")


func _solver() -> void:
	var res: Dictionary = FitSim.solve(FitSim.puzzle(_box()), {}, 10, 10000, 10)
	_check(int(res["count"]) == 1 and bool(res["complete"]), "a fixed-orientation box has exactly one solution")
	# With turning, the L can also go in rotated: the mirror image of the box.
	var turning: Dictionary = _box()
	turning["turn"] = true
	var t: Dictionary = FitSim.solve(FitSim.puzzle(turning), {}, 10, 10000, 10)
	_check(int(t["count"]) == 2, "turning finds the rotated answer too")
	# Two identical dominoes in a 2 x 2: interchangeable, so one solution, not two.
	var twins: Dictionary = {"shape": ["##", "##"], "pieces": [{"cells": [[0, 0], [1, 0]]}, {"cells": [[0, 0], [1, 0]]}]}
	_check(int(FitSim.solve(FitSim.puzzle(twins), {}, 10)["count"]) == 1, "identical pieces count once")
	# Something impossible.
	var stuck: Dictionary = {"shape": ["###"], "pieces": [{"cells": [[0, 0], [0, 1]]}, {"cells": [[0, 0]]}]}
	_check(int(FitSim.solve(FitSim.puzzle(stuck), {}, 10)["count"]) == 0, "a vertical piece can't fill a flat row")
	# The solution the solver returns is legal, piece by piece.
	var sol: Array = (res["solutions"] as Array)[0]
	var pz: FitSim.Puzzle = FitSim.puzzle(_box())
	var occ: PackedInt32Array = FitSim.empty_occ(pz)
	var legal: bool = true
	for pl: Array in sol:
		legal = legal and FitSim.check(pz, occ, int(pl[0]), int(pl[1]), Vector2i(int(pl[2]), int(pl[3]))).is_empty()
		occ = FitSim.occ_for(pz, sol.slice(0, sol.find(pl) + 1))
	_check(legal and FitSim.is_full(pz, occ), "the solver's answer replays legally")
	# The node limit stops a search and says so.
	var big: Dictionary = {"shape": ["#####", "#####", "#####", "#####"], "turn": true, "pieces": []}
	for i: int in 5:
		big["pieces"].append({"cells": [[0, 0], [1, 0], [2, 0], [3, 0]]})
	var capped: Dictionary = FitSim.solve(FitSim.puzzle(big), {}, 1000, 5)
	_check(not bool(capped["complete"]), "a capped search reports it didn't finish")


func _spare_and_fixed() -> void:
	var spare: Dictionary = _box()
	spare["pieces"].append({"cells": [[0, 0], [1, 0], [1, 1]]})
	var res: Dictionary = FitSim.solve(FitSim.puzzle(spare), {}, 10, 10000, 10)
	var unused: bool = true
	for s: Array in res["solutions"]:
		for pl: Array in s:
			unused = unused and int(pl[0]) != 2
	_check(int(res["count"]) == 1 and unused, "with a spare piece, the shape is filled and the spare stays out")
	var fixed: Dictionary = FitSim.solve(FitSim.puzzle(_box()), {0: [0, 0, 0]}, 10)
	_check(int(fixed["count"]) == 1, "a piece already placed right still leads to the answer")
	var wrong: Dictionary = FitSim.solve(FitSim.puzzle(_box()), {1: [0, 1, 1]}, 10)
	_check(int(wrong["count"]) == 0, "a piece placed wrong leads nowhere")


func _stars() -> void:
	var lv: Dictionary = {"par": 6, "stars": [8, 14]}
	_check(FitSim.stars_for(lv, 6, false) == 3 and FitSim.stars_for(lv, 8, false) == 3, "par plus a little slack earns ★★★")
	_check(FitSim.stars_for(lv, 9, false) == 2 and FitSim.stars_for(lv, 14, false) == 2, "a few more moves earn ★★")
	_check(FitSim.stars_for(lv, 15, false) == 1, "any finish earns ★")
	_check(FitSim.stars_for(lv, 6, true) == 2, "a hint caps the stars at ★★")


func _rewards() -> void:
	_check(Economy.level_reward(true, 3) == Economy.LEVEL_REWARD + 3 * Economy.STAR_REWARD, "a first ★★★ clear pays the clear and three stars")
	_check(Economy.level_reward(false, 1) == Economy.STAR_REWARD, "improving a level pays only the new star")
	_check(Economy.level_reward(false, 0) == 0, "replaying for the same stars pays nothing")
