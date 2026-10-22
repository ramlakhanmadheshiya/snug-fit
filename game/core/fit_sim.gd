class_name FitSim
extends RefCounted
## The rules of Snug Fit, shared by the board, hints, the level generator and the tests.
##
## A level is a shape (a silhouette of grid cells) and a set of pieces. Fill every
## cell of the shape with the pieces: no overlaps, nothing outside. Chapters add
## one rule each:
## - turn:  pieces can be turned a quarter at a time;
## - flip:  pieces can also be mirrored;
## - marks: a coloured cell only takes the piece of its colour;
## - pegs:  every piece must cover exactly one peg;
## - spare: one piece is left over (the shape is filled without it).
##
## Orientation o (0..7): mirrored left-right first when o >= 4, then turned
## o % 4 quarter turns clockwise. Piece cells in a level are stored as shown at
## orientation 0; a placement is [piece, o, x, y] with (x, y) the top-left of
## the oriented piece's bounding box.

const REASONS: Dictionary = {
	"outside": "That doesn't fit inside the shape",
	"overlap": "Pieces can't overlap",
	"colour": "Coloured cells take the matching piece",
	"peg": "Each piece covers exactly one peg",
}


# --- Piece geometry ------------------------------------------------------------

static func to_cells(raw: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Variant in raw:
		if c is Vector2i:
			out.append(c)
		else:
			out.append(Vector2i(int(c[0]), int(c[1])))
	return out


## Moves cells so the bounding box starts at (0, 0), sorted row by row.
static func normalize(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.is_empty():
		return cells
	var mn: Vector2i = cells[0]
	for c: Vector2i in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
	var out: Array[Vector2i] = []
	for c: Vector2i in cells:
		out.append(c - mn)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


static func transform(cells: Array[Vector2i], o: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in cells:
		var p: Vector2i = c
		if o >= 4:
			p = Vector2i(-p.x, p.y)
		for i: int in o % 4:
			p = Vector2i(-p.y, p.x)
		out.append(p)
	return normalize(out)


## The orientation reached by turning o a quarter clockwise.
static func turned(o: int) -> int:
	return (o / 4) * 4 + (o % 4 + 1) % 4


## The orientation reached by mirroring o left-right (as seen on screen).
static func flipped(o: int) -> int:
	# Mirroring after k quarter turns equals mirroring first, then turning -k.
	var k: int = o % 4
	return (0 if o >= 4 else 4) + (4 - k) % 4


static func key(cells: Array[Vector2i]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for c: Vector2i in normalize(cells):
		parts.append("%d,%d" % [c.x, c.y])
	return ";".join(parts)


static func size_of(cells: Array[Vector2i]) -> Vector2i:
	var mx: Vector2i = Vector2i.ZERO
	for c: Vector2i in cells:
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	return mx + Vector2i.ONE


## Orientations the level's rules allow.
static func allowed(lv: Dictionary) -> Array[int]:
	if bool(lv.get("flip", false)):
		return [0, 1, 2, 3, 4, 5, 6, 7]
	if bool(lv.get("turn", false)):
		return [0, 1, 2, 3]
	return [0]


## One key per distinct shape a piece can take under the rules (identical pieces share it).
static func class_key(cells: Array[Vector2i], orients: Array[int]) -> String:
	var keys: Array[String] = []
	for o: int in orients:
		keys.append(key(transform(cells, o)))
	keys.sort()
	return keys[0]


# --- The puzzle ----------------------------------------------------------------

## A level unpacked for fast checks: flat grids indexed y * w + x.
class Puzzle:
	extends RefCounted
	var w: int = 0
	var h: int = 0
	var inside: PackedByteArray = PackedByteArray()
	var marks: PackedInt32Array = PackedInt32Array()
	var pegs: PackedByteArray = PackedByteArray()
	var has_marks: bool = false
	var has_pegs: bool = false
	var pieces: Array = []  # Array[Array[Vector2i]], as stored (orientation 0)
	var colors: PackedInt32Array = PackedInt32Array()
	var orients: Array[int] = [0]
	var area: int = 0
	var spare: bool = false

	func idx(p: Vector2i) -> int:
		return p.y * w + p.x

	func is_inside(p: Vector2i) -> bool:
		return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and inside[p.y * w + p.x] == 1


static func puzzle(lv: Dictionary) -> Puzzle:
	var pz: Puzzle = Puzzle.new()
	var rows: Array = lv.get("shape", [])
	pz.h = rows.size()
	pz.w = str(rows[0]).length() if pz.h > 0 else 0
	pz.inside.resize(pz.w * pz.h)
	pz.marks.resize(pz.w * pz.h)
	pz.pegs.resize(pz.w * pz.h)
	pz.marks.fill(-1)
	for y: int in pz.h:
		for x: int in pz.w:
			if str(rows[y])[x] == "#":
				pz.inside[y * pz.w + x] = 1
				pz.area += 1
	for m: Array in lv.get("marks", []):
		pz.marks[int(m[1]) * pz.w + int(m[0])] = int(m[2])
		pz.has_marks = true
	for p: Array in lv.get("pegs", []):
		pz.pegs[int(p[1]) * pz.w + int(p[0])] = 1
		pz.has_pegs = true
	var total: int = 0
	for pc: Dictionary in lv.get("pieces", []):
		var cells: Array[Vector2i] = to_cells(pc["cells"])
		pz.pieces.append(cells)
		pz.colors.append(int(pc.get("color", 0)))
		total += cells.size()
	pz.orients = allowed(lv)
	pz.spare = total > pz.area
	return pz


## "" if piece i at orientation o fits at (x, y) on this occupancy, else why not.
## occ holds the piece index on each cell, or -1.
static func check(pz: Puzzle, occ: PackedInt32Array, i: int, o: int, at: Vector2i) -> String:
	var pegs: int = 0
	for c: Vector2i in transform(pz.pieces[i], o):
		var p: Vector2i = at + c
		if not pz.is_inside(p):
			return "outside"
		var k: int = pz.idx(p)
		if occ[k] != -1 and occ[k] != i:
			return "overlap"
		if pz.marks[k] != -1 and pz.marks[k] != pz.colors[i]:
			return "colour"
		pegs += pz.pegs[k]
	if pz.has_pegs and pegs != 1:
		return "peg"
	return ""


## True when every cell of the shape is covered.
static func is_full(pz: Puzzle, occ: PackedInt32Array) -> bool:
	for k: int in pz.inside.size():
		if pz.inside[k] == 1 and occ[k] == -1:
			return false
	return true


static func empty_occ(pz: Puzzle) -> PackedInt32Array:
	var occ: PackedInt32Array = PackedInt32Array()
	occ.resize(pz.w * pz.h)
	occ.fill(-1)
	return occ


## Applies placements [[i, o, x, y], ...] to a fresh board.
static func occ_for(pz: Puzzle, placements: Array) -> PackedInt32Array:
	var occ: PackedInt32Array = empty_occ(pz)
	for pl: Array in placements:
		for c: Vector2i in transform(pz.pieces[int(pl[0])], int(pl[1])):
			occ[pz.idx(Vector2i(int(pl[2]), int(pl[3])) + c)] = int(pl[0])
	return occ


# --- Solver --------------------------------------------------------------------

## Exact-cover search: always fill the first empty cell, trying each kind of piece
## once (identical pieces are interchangeable). Returns
## {"count", "solutions": [[[i, o, x, y], ...], ...], "nodes", "complete"}.
## `fixed` maps piece index -> [o, x, y] for pieces already on the board.
## `keep` stores at most that many solutions (count goes on to `max_count`).
static func solve(pz: Puzzle, fixed: Dictionary = {}, max_count: int = 2, node_limit: int = 400000, keep: int = 1) -> Dictionary:
	var s: _Search = _Search.new()
	s.setup(pz, fixed)
	s.max_count = max_count
	s.node_limit = node_limit
	s.keep = keep
	s.run()
	return {"count": s.count, "solutions": s.found, "nodes": s.nodes, "complete": not s.aborted and s.count < max_count}


class _Search:
	extends RefCounted
	var pz: Puzzle
	var occ: PackedByteArray = PackedByteArray()
	## Per class: piece indices still free, and the class's placements by cell.
	var class_pieces: Array = []
	var class_size: PackedInt32Array = PackedInt32Array()
	## cover[cell] = Array of [class, o_rep, x, y, PackedInt32Array cells]
	var cover: Array = []
	var cells_order: PackedInt32Array = PackedInt32Array()
	var stack: Array = []
	var fixed_list: Array = []
	var count: int = 0
	var found: Array = []
	var nodes: int = 0
	var max_count: int = 2
	var node_limit: int = 400000
	var keep: int = 1
	var aborted: bool = false
	var reps: Array = []
	var filled: int = 0
	var target: int = 0
	var _seen: PackedByteArray = PackedByteArray()
	var _queue: PackedInt32Array = PackedInt32Array()

	func setup(source: Puzzle, fixed: Dictionary) -> void:
		pz = source
		occ.resize(pz.w * pz.h)
		_seen.resize(pz.w * pz.h)
		_queue.resize(pz.w * pz.h)
		for k: int in pz.inside.size():
			occ[k] = 0 if pz.inside[k] == 1 else 1
			if pz.inside[k] == 1:
				cells_order.append(k)
		target = pz.area
		# Pieces already placed.
		for i: Variant in fixed:
			var pl: Array = fixed[i]
			fixed_list.append([int(i), int(pl[0]), int(pl[1]), int(pl[2])])
			for c: Vector2i in FitSim.transform(pz.pieces[int(i)], int(pl[0])):
				occ[pz.idx(Vector2i(int(pl[1]), int(pl[2])) + c)] = 1
				filled += 1
		# Group the free pieces into classes of identical ones.
		var by_key: Dictionary = {}
		for i: int in pz.pieces.size():
			if fixed.has(i):
				continue
			var ck: String = FitSim.class_key(pz.pieces[i], pz.orients)
			if pz.has_marks:
				ck += "#%d" % pz.colors[i]
			if not by_key.has(ck):
				by_key[ck] = class_pieces.size()
				class_pieces.append([])
				reps.append(i)
				class_size.append((pz.pieces[i] as Array).size())
			(class_pieces[by_key[ck]] as Array).append(i)
		# Every legal spot for each class, ignoring other pieces.
		cover.resize(pz.w * pz.h)
		for k: int in cover.size():
			cover[k] = []
		for ci: int in reps.size():
			var rep: int = reps[ci]
			var seen_o: Dictionary = {}
			for o: int in pz.orients:
				var cells: Array[Vector2i] = FitSim.transform(pz.pieces[rep], o)
				var ok: String = FitSim.key(cells)
				if seen_o.has(ok):
					continue
				seen_o[ok] = true
				var sz: Vector2i = FitSim.size_of(cells)
				for y: int in pz.h - sz.y + 1:
					for x: int in pz.w - sz.x + 1:
						var flat: PackedInt32Array = PackedInt32Array()
						var good: bool = true
						var pegs: int = 0
						for c: Vector2i in cells:
							var p: Vector2i = Vector2i(x, y) + c
							var k: int = pz.idx(p)
							if pz.inside[k] != 1 or (pz.marks[k] != -1 and pz.marks[k] != pz.colors[rep]):
								good = false
								break
							pegs += pz.pegs[k]
							flat.append(k)
						if not good or (pz.has_pegs and pegs != 1):
							continue
						var entry: Array = [ci, o, x, y, flat]
						for k: int in flat:
							(cover[k] as Array).append(entry)

	func run() -> void:
		_dfs(0)

	func _first_empty(from: int) -> int:
		for j: int in range(from, cells_order.size()):
			if occ[cells_order[j]] == 0:
				return j
		return -1

	func _dfs(from: int) -> void:
		if aborted:
			return
		nodes += 1
		if nodes > node_limit:
			aborted = true
			return
		var j: int = _first_empty(from)
		if j < 0:
			_record()
			return
		var cell: int = cells_order[j]
		for entry: Array in cover[cell]:
			var ci: int = entry[0]
			var free: Array = class_pieces[ci]
			if free.is_empty():
				continue
			var flat: PackedInt32Array = entry[4]
			var clear: bool = true
			for k: int in flat:
				if occ[k] != 0:
					clear = false
					break
			if not clear:
				continue
			for k: int in flat:
				occ[k] = 1
			var piece: int = free.pop_back()
			stack.append([piece, entry])
			filled += flat.size()
			if _regions_ok():
				_dfs(j + 1)
			filled -= flat.size()
			stack.pop_back()
			free.append(piece)
			for k: int in flat:
				occ[k] = 0
			if aborted or count >= max_count:
				return

	## Prunes boards that left a pocket smaller than every piece still free.
	func _regions_ok() -> bool:
		var smallest: int = 1 << 20
		for ci: int in class_pieces.size():
			if not (class_pieces[ci] as Array).is_empty():
				smallest = mini(smallest, class_size[ci])
		if smallest == 1 << 20:
			return filled >= target
		_seen.fill(0)
		for start: int in cells_order:
			if occ[start] != 0 or _seen[start] == 1:
				continue
			var n: int = 0
			var head: int = 0
			var tail: int = 0
			_queue[tail] = start
			tail += 1
			_seen[start] = 1
			while head < tail:
				var k: int = _queue[head]
				head += 1
				n += 1
				var x: int = k % pz.w
				var y: int = k / pz.w
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx < 0 or ny < 0 or nx >= pz.w or ny >= pz.h:
						continue
					var nk: int = ny * pz.w + nx
					if occ[nk] == 0 and _seen[nk] == 0:
						_seen[nk] = 1
						_queue[tail] = nk
						tail += 1
			if n < smallest:
				return false
		return true

	func _record() -> void:
		count += 1
		if found.size() >= keep:
			return
		var sol: Array = fixed_list.duplicate(true)
		for st: Array in stack:
			var piece: int = st[0]
			var entry: Array = st[1]
			var rep: int = reps[int(entry[0])]
			var o: int = int(entry[1])
			if piece != rep:
				o = FitSim.orient_matching(pz.pieces[piece], FitSim.transform(pz.pieces[rep], o), pz.orients)
			sol.append([piece, o, int(entry[2]), int(entry[3])])
		sol.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
		found.append(sol)


## The orientation of `cells` that looks exactly like `target` (-1 if none).
static func orient_matching(cells: Array[Vector2i], target: Array[Vector2i], orients: Array[int]) -> int:
	var want: String = key(target)
	for o: int in orients:
		if key(transform(cells, o)) == want:
			return o
	return -1


## True if a placement covers exactly the same cells as the one in a solution
## (identical pieces are interchangeable).
static func same_cells(pz: Puzzle, a: Array, b: Array) -> bool:
	if pz.colors[int(a[0])] != pz.colors[int(b[0])] and pz.has_marks:
		return false
	var ca: Array[Vector2i] = transform(pz.pieces[int(a[0])], int(a[1]))
	var cb: Array[Vector2i] = transform(pz.pieces[int(b[0])], int(b[1]))
	return Vector2i(int(a[2]), int(a[3])) == Vector2i(int(b[2]), int(b[3])) and key(ca) == key(cb)


## Stars for a finished level: by moves against par, a hint caps at two.
static func stars_for(lv: Dictionary, moves: int, hinted: bool) -> int:
	var limits: Array = lv.get("stars", [99, 99])
	var s: int = 3 if moves <= int(limits[0]) else (2 if moves <= int(limits[1]) else 1)
	return mini(s, 2) if hinted else s
