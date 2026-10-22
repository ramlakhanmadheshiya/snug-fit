extends SceneTree
## Builds every chapter's 30 levels and writes content/levels/<chapter>.json.
##
##   godot --headless --path . -s res://tools/level_lab.gd            # all chapters
##   godot --headless --path . -s res://tools/level_lab.gd -- ch3     # one chapter
##
## For each level slot: pick a silhouette of about the right size (never twice in
## a chapter), cut it into pieces, add the chapter's rule, and let the solver
## (FitSim.solve) count the solutions. A level is kept only if it has very few
## solutions (one, late in a chapter) and, for paint and pegs, only if the rule
## is what makes it that way. The candidates that fit each slot's place on the
## difficulty curve are kept, then the chapter is ordered by pieces and effort.

const COUNT: int = 30
const OUT_DIR: String = "res://content/levels/"
## Pieces per level (first -> last), smallest and biggest piece, and the rule.
const CHAPTERS: Dictionary = {
	"ch1": {"k": [2, 8], "rule": "fit"},
	"ch2": {"k": [3, 7], "rule": "turn"},
	"ch3": {"k": [4, 8], "rule": "paint"},
	"ch4": {"k": [4, 8], "rule": "pegs"},
	"ch5": {"k": [3, 7], "rule": "spare"},
	"ch6": {"k": [3, 7], "rule": "flip"},
	"ch7": {"k": [4, 9], "rule": "mix"},
}
## From this level on, Paint, Pegs and Spare pieces can be turned too.
const TURN_FROM: int = 15
## Ch7 mixes everything, a different pair of ideas each level.
const MIX: Array = [["turn", "paint"], ["turn", "pegs"], ["turn", "spare"], ["flip", "paint"], ["flip", "pegs"], ["flip"], ["turn", "paint", "pegs"]]
const PAINT_COLOURS: int = 3
const BLOCK_COLOURS: int = 6
const CANDIDATES: int = 10
const ATTEMPTS: int = 260
const NODE_LIMIT: int = 250000
const SOLUTION_CAP: int = 400


func _init() -> void:
	var only: Array = []
	for a: String in OS.get_cmdline_user_args():
		only.append(a)
	for id: String in CHAPTERS:
		if not only.is_empty() and not id in only:
			continue
		var t0: int = Time.get_ticks_msec()
		var levels: Array = build_chapter(id)
		var f: FileAccess = FileAccess.open(OUT_DIR + id + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"id": id, "levels": levels}, "\t"))
		f.close()
		print("%s: %d levels in %.1fs" % [id, levels.size(), (Time.get_ticks_msec() - t0) / 1000.0])
		for lv: Dictionary in levels:
			print("  %s %-10s k=%d sol=%d nodes=%d %s" % [lv["id"], lv["name"], lv["par"], lv["solutions"], lv["nodes"], _rules_text(lv)])
	quit()


func _rules_text(lv: Dictionary) -> String:
	var r: Array = []
	for k: String in ["turn", "flip"]:
		if bool(lv.get(k, false)):
			r.append(k)
	if not (lv.get("marks", []) as Array).is_empty():
		r.append("paint×%d" % (lv["marks"] as Array).size())
	if not (lv.get("pegs", []) as Array).is_empty():
		r.append("pegs")
	if lv.has("spare"):
		r.append("spare")
	return ",".join(r)


## The ideas a slot uses.
static func rules_for(chapter: String, n: int) -> Array:
	var rule: String = CHAPTERS[chapter]["rule"]
	match rule:
		"fit":
			return []
		"turn":
			return ["turn"]
		"flip":
			return ["flip"]
		"mix":
			return MIX[n % MIX.size()]
		_:
			return [rule, "turn"] if n >= TURN_FROM else [rule]


func build_chapter(chapter: String) -> Array:
	var used: Dictionary = {}
	var picked: Array = []
	for n: int in COUNT:
		var lv: Dictionary = build_slot(chapter, n, used)
		if lv.is_empty():
			push_error("%s slot %d: no level found" % [chapter, n])
			continue
		used[lv["name"]] = true
		picked.append(lv)
	# The first level teaches the idea, so it stays first; the rest climb.
	var first: Dictionary = picked.pop_front()
	picked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["par"]) != int(b["par"]):
			return int(a["par"]) < int(b["par"])
		return int(a["nodes"]) < int(b["nodes"]))
	picked.push_front(first)
	for i: int in picked.size():
		var lv: Dictionary = picked[i]
		lv["id"] = "%s_%02d" % [chapter, i + 1]
		if i == 0 and chapter != "ch1":
			lv["intro"] = true
	return picked


func build_slot(chapter: String, n: int, used: Dictionary) -> Dictionary:
	var spec: Dictionary = CHAPTERS[chapter]
	var t: float = float(n) / float(COUNT - 1)
	var k: int = roundi(lerpf(float(spec["k"][0]), float(spec["k"][1]), pow(t, 0.9)))
	var rules: Array = rules_for(chapter, n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var found: Array = []
	for attempt: int in ATTEMPTS * 4:
		if attempt >= ATTEMPTS and not found.is_empty():
			break
		rng.seed = hash("%s/%d/%d" % [chapter, n, attempt])
		var lv: Dictionary = candidate(chapter, n, k, rules, used, rng)
		if lv.is_empty():
			continue
		found.append(lv)
		if found.size() >= CANDIDATES:
			break
	if found.is_empty():
		return {}
	# Later slots take the harder candidates; the first one in a chapter the easiest.
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["nodes"]) < int(b["nodes"]))
	var q: float = 0.0 if n == 0 else clampf(0.25 + 0.7 * t, 0.0, 1.0)
	return found[roundi(q * float(found.size() - 1))]


## Silhouettes near the area k pieces would cover, not used yet in this chapter.
func pick_shape(k: int, t: float, used: Dictionary, rng: RandomNumberGenerator, smin: int, smax: int) -> String:
	var avg: float = lerpf(3.2, 4.3, t)
	var want: float = float(k) * avg
	var pool: Array = []
	for name: String in ShapeLibrary.names():
		if used.has(name):
			continue
		var a: int = ShapeLibrary.area(name)
		if a < k * smin or a > k * smax:
			continue
		if absf(float(a) - want) <= maxf(3.0, want * 0.22):
			pool.append(name)
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]


func candidate(chapter: String, n: int, k: int, rules: Array, used: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var t: float = float(n) / float(COUNT - 1)
	var smin: int = 2 if (chapter == "ch1" and n < 8) else 3
	var smax: int = 5 if n < 20 else 6
	var name: String = pick_shape(k, t, used, rng, smin, smax)
	if name.is_empty():
		return {}
	var rows: Array = ShapeLibrary.rows(name, rng.randf() < 0.5)
	var cells: Array[Vector2i] = ShapeLibrary.cells(rows)
	var parts: Array = partition(cells, k, smin, smax, rng)
	if parts.is_empty():
		return {}
	var turn: bool = "turn" in rules
	var flip: bool = "flip" in rules
	var orients: Array[int] = FitSim.allowed({"turn": turn, "flip": flip})
	if not distinct_enough(parts, orients):
		return {}
	var lv: Dictionary = {"name": name, "shape": rows, "turn": turn or flip, "flip": flip}
	var paint: bool = "paint" in rules
	var colours: Array = paint_colours(parts, orients, rng) if paint else block_colours(parts, rng)
	# Pieces are stored as the tray first shows them; the solution says how they go in.
	var pieces: Array = []
	var solution: Array = []
	for i: int in parts.size():
		var sol_cells: Array[Vector2i] = FitSim.normalize(parts[i])
		var start: int = 0
		if turn or flip:
			start = start_orientation(sol_cells, orients, rng)
		var shown: Array[Vector2i] = FitSim.transform(sol_cells, start)
		var o: int = FitSim.orient_matching(shown, sol_cells, orients)
		var at: Vector2i = parts_origin(parts[i])
		pieces.append({"cells": _cells_json(shown), "color": colours[i]})
		solution.append([i, o, at.x, at.y])
	lv["pieces"] = pieces
	if "spare" in rules:
		var spare: Array[Vector2i] = spare_piece(parts, orients, rng)
		if spare.is_empty():
			return {}
		var s0: int = 0
		if turn or flip:
			s0 = start_orientation(spare, orients, rng)
		pieces.insert(rng.randi() % (pieces.size() + 1), {"cells": _cells_json(FitSim.transform(spare, s0)), "color": rng.randi() % BLOCK_COLOURS, "spare": true})
		# Re-index the solution around the inserted piece.
		var spare_at: int = -1
		for i: int in pieces.size():
			if bool((pieces[i] as Dictionary).get("spare", false)):
				spare_at = i
		for pl: Array in solution:
			if int(pl[0]) >= spare_at:
				pl[0] = int(pl[0]) + 1
		(pieces[spare_at] as Dictionary).erase("spare")
		lv["spare"] = spare_at
	var g: int = symmetry(cells, orients)
	var max_sol: int = (3 if n < 8 else (2 if n < 18 else 1)) * g
	var pz: FitSim.Puzzle = FitSim.puzzle(lv)
	if paint:
		pz.has_marks = true
	var raw: Dictionary = FitSim.solve(pz, {}, SOLUTION_CAP, NODE_LIMIT, SOLUTION_CAP)
	if not bool(raw["complete"]):
		return {}
	var sols: Array = raw["solutions"]
	if paint:
		var marks: Array = choose_marks(pz, solution, sols, max_sol)
		if marks.is_empty():
			return {}
		lv["marks"] = marks
	if "pegs" in rules:
		var pegs: Array = choose_pegs(pz, solution, sols, max_sol, rng)
		if pegs.is_empty():
			return {}
		lv["pegs"] = pegs
	if not paint and not "pegs" in rules and sols.size() > max_sol:
		return {}
	# The final count and effort, with every rule in place.
	pz = FitSim.puzzle(lv)
	var fin: Dictionary = FitSim.solve(pz, {}, 50, NODE_LIMIT * 2, 1)
	if not bool(fin["complete"]) or int(fin["count"]) < 1 or int(fin["count"]) > max_sol:
		return {}
	# The stored solution must be legal under the rules.
	var occ: PackedInt32Array = FitSim.empty_occ(pz)
	for pl: Array in solution:
		if not FitSim.check(pz, occ, int(pl[0]), int(pl[1]), Vector2i(int(pl[2]), int(pl[3]))).is_empty():
			return {}
		occ = FitSim.occ_for(pz, solution.slice(0, solution.find(pl) + 1))
	if not FitSim.is_full(pz, occ):
		return {}
	lv["solution"] = solution
	lv["solutions"] = int(fin["count"])
	lv["nodes"] = int(raw["nodes"])
	lv["par"] = k
	lv["stars"] = [k + 1 + k / 6, 2 * k + 2]
	return lv


func _cells_json(cells: Array[Vector2i]) -> Array:
	var out: Array = []
	for c: Vector2i in cells:
		out.append([c.x, c.y])
	return out


func parts_origin(part: Array) -> Vector2i:
	var mn: Vector2i = part[0]
	for c: Vector2i in part:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
	return mn


## Cuts the shape into k connected pieces of smin..smax cells. Each piece starts
## at the most hemmed-in cell left, so no lonely pockets are stranded. [] on failure.
func partition(cells: Array[Vector2i], k: int, smin: int, smax: int, rng: RandomNumberGenerator) -> Array:
	var area: int = cells.size()
	if area < k * smin or area > k * smax:
		return []
	for attempt: int in 40:
		var sizes: Array[int] = split_sizes(area, k, smin, smax, rng)
		var left: Dictionary = {}
		for c: Vector2i in cells:
			left[c] = true
		var parts: Array = []
		var ok: bool = true
		while not sizes.is_empty():
			var start: Vector2i = most_hemmed(left, rng)
			var comp: Array[Vector2i] = component(left, start)
			var s: int = -1
			if comp.size() in sizes:
				if comp.size() <= smax:
					s = comp.size()
			if s < 0:
				var options: Array[int] = []
				for z: int in sizes:
					if z < comp.size() and comp.size() - z >= smin:
						options.append(z)
				if options.is_empty():
					ok = false
					break
				s = options[rng.randi() % options.size()]
			var piece: Array[Vector2i] = grow(left, start, s, rng)
			if piece.size() != s:
				ok = false
				break
			for c: Vector2i in piece:
				left.erase(c)
			sizes.erase(s)
			parts.append(piece)
			if not pockets_ok(left, smin):
				ok = false
				break
		if ok and left.is_empty():
			return parts
	return []


func split_sizes(area: int, k: int, smin: int, smax: int, rng: RandomNumberGenerator) -> Array[int]:
	var sizes: Array[int] = []
	for i: int in k:
		sizes.append(area / k)
	for i: int in area % k:
		sizes[i] += 1
	for i: int in k * 3:
		var a: int = rng.randi() % k
		var b: int = rng.randi() % k
		if a != b and sizes[a] > smin and sizes[b] < smax:
			sizes[a] -= 1
			sizes[b] += 1
	return sizes


func most_hemmed(left: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var best: Array[Vector2i] = []
	var best_n: int = 99
	for c: Vector2i in left:
		var nb: int = 0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if left.has(c + d):
				nb += 1
		if nb < best_n:
			best_n = nb
			best = [c]
		elif nb == best_n:
			best.append(c)
	return best[rng.randi() % best.size()]


func component(left: Dictionary, start: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	var i: int = 0
	while i < out.size():
		var c: Vector2i = out[i]
		i += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if left.has(c + d) and not seen.has(c + d):
				seen[c + d] = true
				out.append(c + d)
	return out


## Grows a piece from start, preferring hemmed-in neighbours so the rest stays whole.
func grow(left: Dictionary, start: Vector2i, s: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var piece: Array[Vector2i] = [start]
	var inp: Dictionary = {start: true}
	while piece.size() < s:
		var frontier: Array[Vector2i] = []
		var weights: Array[float] = []
		for c: Vector2i in piece:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = c + d
				if left.has(q) and not inp.has(q) and not q in frontier:
					var nb: int = 0
					for e: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if left.has(q + e) and not inp.has(q + e):
							nb += 1
					frontier.append(q)
					weights.append(1.0 / float(1 + nb * nb) + 0.15)
		if frontier.is_empty():
			break
		var total: float = 0.0
		for w: float in weights:
			total += w
		var r: float = rng.randf() * total
		var pick: int = 0
		for j: int in weights.size():
			r -= weights[j]
			if r <= 0.0:
				pick = j
				break
		piece.append(frontier[pick])
		inp[frontier[pick]] = true
	return piece


func pockets_ok(left: Dictionary, smin: int) -> bool:
	var seen: Dictionary = {}
	for c: Vector2i in left:
		if seen.has(c):
			continue
		var comp: Array[Vector2i] = component(left, c)
		for q: Vector2i in comp:
			seen[q] = true
		if comp.size() < smin:
			return false
	return true


## No more than two copies of any piece, and not all pieces straight bars.
func distinct_enough(parts: Array, orients: Array[int]) -> bool:
	var counts: Dictionary = {}
	for p: Array in parts:
		var cells: Array[Vector2i] = []
		cells.assign(p)
		var ck: String = FitSim.class_key(cells, orients)
		counts[ck] = int(counts.get(ck, 0)) + 1
		if int(counts[ck]) > 2:
			return false
	return counts.size() >= mini(parts.size(), 2)


## A start orientation that looks different from how the piece goes in, when it can.
func start_orientation(cells: Array[Vector2i], orients: Array[int], rng: RandomNumberGenerator) -> int:
	var home: String = FitSim.key(cells)
	var options: Array[int] = []
	for o: int in orients:
		if FitSim.key(FitSim.transform(cells, o)) != home:
			options.append(o)
	if options.is_empty():
		return 0
	return options[rng.randi() % options.size()]


## How many allowed transformations map the shape onto itself.
func symmetry(cells: Array[Vector2i], orients: Array[int]) -> int:
	var home: String = FitSim.key(cells)
	var n: int = 0
	for o: int in orients:
		if FitSim.key(FitSim.transform(cells, o)) == home:
			n += 1
	return maxi(1, n)


## Neighbouring pieces get different colours from the chapter's blocks.
func block_colours(parts: Array, rng: RandomNumberGenerator) -> Array:
	var owner: Dictionary = {}
	for i: int in parts.size():
		for c: Vector2i in parts[i]:
			owner[c] = i
	var colours: Array = []
	colours.resize(parts.size())
	colours.fill(-1)
	var used: Array = []
	used.resize(BLOCK_COLOURS)
	used.fill(0)
	var offset: int = rng.randi() % BLOCK_COLOURS
	for i: int in parts.size():
		var banned: Dictionary = {}
		for c: Vector2i in parts[i]:
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if owner.has(c + d) and int(owner[c + d]) != i and int(colours[owner[c + d]]) >= 0:
					banned[colours[owner[c + d]]] = true
		var best: int = -1
		for j: int in BLOCK_COLOURS:
			var col: int = (j + offset) % BLOCK_COLOURS
			if banned.has(col):
				continue
			if best < 0 or int(used[col]) < int(used[best]):
				best = col
		if best < 0:
			best = rng.randi() % BLOCK_COLOURS
		colours[i] = best
		used[best] = int(used[best]) + 1
	return colours


## Three paint colours, spread out, and identical pieces painted differently.
func paint_colours(parts: Array, orients: Array[int], rng: RandomNumberGenerator) -> Array:
	var colours: Array = []
	var by_class: Dictionary = {}
	var order: Array = range(PAINT_COLOURS)
	order.shuffle()
	for i: int in parts.size():
		var cells: Array[Vector2i] = []
		cells.assign(parts[i])
		var ck: String = FitSim.class_key(cells, orients)
		var col: int = int(order[i % PAINT_COLOURS])
		if by_class.has(ck):
			col = (int(by_class[ck]) + 1 + rng.randi() % (PAINT_COLOURS - 1)) % PAINT_COLOURS
		by_class[ck] = col
		colours.append(col)
	return colours


## Paint marks, greedily: each new mark rules out the most other solutions.
## At least two marks, and only worth it if the marks are what make it unique.
func choose_marks(pz: FitSim.Puzzle, solution: Array, sols: Array, max_sol: int) -> Array:
	if sols.size() < 2:
		return []
	var owner: Dictionary = {}
	for pl: Array in solution:
		for c: Vector2i in FitSim.transform(pz.pieces[int(pl[0])], int(pl[1])):
			owner[Vector2i(int(pl[2]), int(pl[3])) + c] = int(pl[0])
	var covers: Array = []
	for s: Array in sols:
		var m: Dictionary = {}
		for pl: Array in s:
			for c: Vector2i in FitSim.transform(pz.pieces[int(pl[0])], int(pl[1])):
				m[Vector2i(int(pl[2]), int(pl[3])) + c] = pz.colors[int(pl[0])]
		covers.append(m)
	var alive: Array = range(sols.size())
	var marks: Array = []
	var marked_piece: Dictionary = {}
	while alive.size() > max_sol or marks.size() < 2:
		var best: Vector2i = Vector2i(-1, -1)
		var best_left: int = 1 << 20
		for c: Vector2i in owner:
			var piece: int = owner[c]
			if marked_piece.has(piece):
				continue
			var col: int = pz.colors[piece]
			var left: int = 0
			for a: int in alive:
				if int((covers[a] as Dictionary).get(c, -1)) == col:
					left += 1
			if left < best_left or (left == best_left and (c.x + c.y * 7) % 5 == 0):
				best_left = left
				best = c
		if best.x < 0 or (best_left == alive.size() and marks.size() >= 2):
			break
		var piece_b: int = owner[best]
		marked_piece[piece_b] = true
		marks.append([best.x, best.y, pz.colors[piece_b]])
		var keep: Array = []
		for a: int in alive:
			if int((covers[a] as Dictionary).get(best, -1)) == pz.colors[piece_b]:
				keep.append(a)
		alive = keep
		if marks.size() > solution.size():
			break
	if alive.size() > max_sol:
		return []
	return marks


## One peg per piece of the intended solution, tried at random; keeps the set that
## leaves the fewest solutions. Only worth it if the pegs are what make it unique.
func choose_pegs(pz: FitSim.Puzzle, solution: Array, sols: Array, max_sol: int, rng: RandomNumberGenerator) -> Array:
	if sols.size() < 2:
		return []
	var placed: Array = []
	for pl: Array in solution:
		var cells: Array = []
		for c: Vector2i in FitSim.transform(pz.pieces[int(pl[0])], int(pl[1])):
			cells.append(Vector2i(int(pl[2]), int(pl[3])) + c)
		placed.append(cells)
	var sol_cells: Array = []
	for s: Array in sols:
		var list: Array = []
		for pl: Array in s:
			var cells: Dictionary = {}
			for c: Vector2i in FitSim.transform(pz.pieces[int(pl[0])], int(pl[1])):
				cells[Vector2i(int(pl[2]), int(pl[3])) + c] = true
			list.append(cells)
		sol_cells.append(list)
	var best: Array = []
	var best_n: int = 1 << 20
	for tries: int in 80:
		var pegs: Dictionary = {}
		for cells: Array in placed:
			pegs[cells[rng.randi() % cells.size()]] = true
		var n: int = 0
		for list: Array in sol_cells:
			var good: bool = true
			for cells: Dictionary in list:
				var hits: int = 0
				for p: Vector2i in pegs:
					if cells.has(p):
						hits += 1
				if hits != 1:
					good = false
					break
			if good:
				n += 1
		if n < best_n:
			best_n = n
			best = pegs.keys()
		if best_n == 1:
			break
	if best_n > max_sol:
		return []
	var out: Array = []
	for p: Vector2i in best:
		out.append([p.x, p.y])
	out.sort()
	return out


## A spare piece the size most pieces already have (so counting cells won't
## tell you which one is left over), unlike any of them.
func spare_piece(parts: Array, orients: Array[int], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var counts: Dictionary = {}
	var keys: Dictionary = {}
	for p: Array in parts:
		counts[p.size()] = int(counts.get(p.size(), 0)) + 1
		var cells: Array[Vector2i] = []
		cells.assign(p)
		keys[FitSim.class_key(cells, orients)] = true
	var size: int = 4
	var most: int = 0
	for s: int in counts:
		if int(counts[s]) > most:
			most = int(counts[s])
			size = s
	for attempt: int in 30:
		var field: Dictionary = {}
		for y: int in 5:
			for x: int in 5:
				field[Vector2i(x, y)] = true
		var cells: Array[Vector2i] = grow(field, Vector2i(2, 2), size, rng)
		if cells.size() != size:
			continue
		cells = FitSim.normalize(cells)
		if not keys.has(FitSim.class_key(cells, orients)):
			return cells
	return []
