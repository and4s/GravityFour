class_name GravityAI
extends RefCounted
const Board = preload("res://scripts/board.gd")
const N := Board.SIZE
const WEIGHTS := [0, 2, 24, 260, 100000]
const MATE := 8000000
var cells: Array[int] = []
var heights: Array[int] = []
var lines: Array = []
var cell_lines: Array = []
var counts: Array = []
var keys: Array = []
var hash_key := 0
var side_key := 0
var symmetry_maps: Array = []
var symmetry_inverse: Array = []
var symmetry_hashes: Array[int] = []
var root_symmetries: Array[int] = []
var table: Dictionary = {}
var killers: Dictionary = {}
var score := 0
var nodes := 0
var deadline := 0
var aborted := false
var cancelled := false
var report: Dictionary = {}
var advanced_tactics := true
var side_stones: Array[int] = [0,0]
var rng := RandomNumberGenerator.new()
func _init() -> void:
	rng.randomize()
	for orientation in 8:
		var mapping: Array[int] = []
		var inverse: Array[int] = []
		inverse.resize(N*N)
		for col in N*N:
			var x := col % N
			var z := col / N
			var transforms := [Vector2i(x,z),Vector2i(N-1-z,x),Vector2i(N-1-x,N-1-z),Vector2i(z,N-1-x),Vector2i(N-1-x,z),Vector2i(x,N-1-z),Vector2i(z,x),Vector2i(N-1-z,N-1-x)]
			var p: Vector2i = transforms[orientation]
			mapping.append(p.x + N*p.y)
			inverse[mapping[-1]] = col
		symmetry_maps.append(mapping)
		symmetry_inverse.append(inverse)
	for i in Board.CELLS:
		cell_lines.append([])
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				if dx < 0 or (dx == 0 and dy < 0) or (dx == 0 and dy == 0 and dz <= 0):
					continue
				for x in N:
					for y in N:
						for z in N:
							var finish := Vector3i(x, y, z) + Vector3i(dx, dy, dz) * 3
							if finish.x < 0 or finish.y < 0 or finish.z < 0 or finish.x >= N or finish.y >= N or finish.z >= N:
								continue
							var line: Array[int] = []
							for step in 4:
								var index := x + dx * step + N * (z + dz * step + N * (y + dy * step))
								line.append(index)
								cell_lines[index].append(lines.size())
							lines.append(line)

static func search_limits(difficulty: int, stones: int, budget_ms: int = -1) -> Dictionary:
	var tier := clampi(difficulty,0,3)
	var budget: int = [180,1400,4500,8000][tier] if budget_ms < 0 else budget_ms
	var depth: int = [1,6,11,13][tier]
	if stones > 14 and tier in [1,2]:
		budget = maxi(1,int(budget * 0.75))
		depth = 5 if tier == 1 else 8
	return {"budget_ms":budget,"max_depth":depth}

func choose_move(snapshot: Dictionary, difficulty: int = 1, budget_ms: int = -1) -> Vector2i:
	if int(snapshot.get("winner", 0)) != 0: return Vector2i(-1, -1)
	var started := Time.get_ticks_msec()
	advanced_tactics = difficulty >= 2
	report = {}
	cells.assign(snapshot.cells)
	side_stones.assign([0,0])
	for piece in cells:
		if piece > 0: side_stones[piece-1] += 1
	heights.resize(N * N)
	heights.fill(0)
	for col in N * N:
		while heights[col] < N and cells[col + N * N * heights[col]] != 0: heights[col] += 1
	counts = []
	for line in lines:
		var one := 0
		var two := 0
		for index in line:
			one += 1 if cells[index] == 1 else 0
			two += 1 if cells[index] == 2 else 0
		counts.append([one, two])
	var key_rng := RandomNumberGenerator.new()
	key_rng.seed = 741239
	keys.clear()
	hash_key = 0
	for i in Board.CELLS:
		keys.append([(int(key_rng.randi()) << 30) ^ int(key_rng.randi()), (int(key_rng.randi()) << 30) ^ int(key_rng.randi())])
		if cells[i] != 0: hash_key ^= int(keys[i][cells[i] - 1])
	side_key = (int(key_rng.randi()) << 30) ^ int(key_rng.randi())
	symmetry_hashes.resize(8)
	symmetry_hashes.fill(0)
	for orientation in 8:
		for i in Board.CELLS:
			if cells[i] != 0: symmetry_hashes[orientation] ^= int(keys[int(symmetry_maps[orientation][i % (N*N)]) + (i / (N*N)) * N*N][cells[i]-1])
	root_symmetries.clear()
	for orientation in 8:
		if symmetry_hashes[orientation] == symmetry_hashes[0]: root_symmetries.append(orientation)
	score = 0
	for c in counts: score += _value(c)
	for i in Board.CELLS:
		if cells[i] != 0: score += _center(i % (N * N)) * (1 if cells[i] == 2 else -1)
	var side := int(snapshot.turn)
	var options := _legal()
	if options.is_empty(): return Vector2i(-1, -1)
	var wins := _winning_cols(side)
	if not wins.is_empty():
		report = {"reason":"win", "depth":1}
		return _column(wins[0])
	var threats := _winning_cols(3 - side)
	if threats.size() == 1:
		report = {"reason":"block", "depth":1}
		return _column(threats[0])
	if difficulty >= 2:
		var fork := _safe_fork(side)
		if fork >= 0:
			report = {"reason": "fork", "tactic": "fork", "nodes": 0, "depth": 3, "ms": Time.get_ticks_msec()-started}
			return _column(fork)
	# Opening policy keeps central control; tactical wins/blocks always take precedence.
	var stones := 0
	for height in heights: stones += height
	if difficulty > 0 and stones == 0:
		report = {"reason":"center", "book": true, "nodes": 0, "depth": 0, "ms": Time.get_ticks_msec()-started}
		return Vector2i(2,2)

	nodes = 0
	aborted = false
	table.clear()
	killers.clear()
	var limits := search_limits(difficulty,stones,budget_ms)
	deadline = started + int(limits.budget_ms)
	var ranked := _rank(side, -1, 0)
	var best: int = ranked[0].col
	if difficulty == 0:
		var candidates: Array[Dictionary] = []
		for item in ranked:
			if item.value < -1000000: continue
			_push(item.col, side)
			var value := _evaluate(side)
			_pop(item.col)
			candidates.append({"col":item.col,"value":value})
		candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.value > b.value)
		if not candidates.is_empty():
			best = candidates[0].col
			if candidates.size() > 1 and candidates[0].value - candidates[1].value <= 20 and rng.randf() < 0.2: best = candidates[1].col
		report = {"reason":"position", "depth":1,"ms":Time.get_ticks_msec()-started}
		return _column(best)
	var completed_depth := 0
	var best_score := -MATE
	for depth in range(1, int(limits.max_depth)+1):
		var current_best := best
		var current_score := -MATE * 2
		var alpha := -MATE * 2
		ranked = _rank(side, best, 0)
		for item in ranked:
			if _out_of_time(): break
			var col: int = item.col
			var won := _push(col, side)
			var value := MATE - 1 if won else -_search(3 - side, depth - 1, -MATE * 2, -alpha, 1, 0)
			_pop(col)
			if aborted: break
			if value > current_score:
				current_score = value
				current_best = col
			alpha = maxi(alpha, value)
		if aborted: break
		best = current_best
		best_score = current_score
		completed_depth = depth
		if absi(best_score) >= MATE - 200: break
	report = {"budget_ms": int(limits.budget_ms), "max_depth":int(limits.max_depth), "opening":stones <= 14, "reason":"forced_win" if best_score >= MATE-200 else "position", "nodes": nodes, "depth": completed_depth, "score": best_score, "ms": Time.get_ticks_msec() - started}
	return _column(best)

func _column(col: int) -> Vector2i:
	return Vector2i(col % N, col / N)

func _center(col: int) -> int:
	return (4 - absi(col % N - 2) - absi(col / N - 2)) * 5

func _legal() -> Array[int]:
	var result: Array[int] = []
	for col in N * N:
		if heights[col] < N: result.append(col)
	return result

func _value(c: Array) -> int:
	if c[0] > 0 and c[1] > 0: return 0
	return int(WEIGHTS[c[1]]) - int(WEIGHTS[c[0]])

func _winning_at(index: int, side: int) -> bool:
	if side_stones[side-1] < 3: return false
	for line_id in cell_lines[index]:
		var c: Array = counts[line_id]
		if c[side - 1] == 3 and c[2 - side] == 0: return true
	return false

func _winning_cols(side: int) -> Array[int]:
	var result: Array[int] = []
	if side_stones[side-1] < 3: return result
	for col in N * N:
		if heights[col] < N and _winning_at(col + N * N * heights[col], side): result.append(col)
	return result

func _push(col: int, side: int) -> bool:
	var index := col + N * N * heights[col]
	var won := _winning_at(index, side)
	for line_id in cell_lines[index]:
		score -= _value(counts[line_id])
		counts[line_id][side - 1] += 1
		score += _value(counts[line_id])
	cells[index] = side
	side_stones[side-1] += 1
	heights[col] += 1
	hash_key ^= int(keys[index][side - 1])
	for orientation in 8: symmetry_hashes[orientation] ^= int(keys[int(symmetry_maps[orientation][col]) + (index / (N*N)) * N*N][side-1])
	score += _center(col) * (1 if side == 2 else -1)
	return won

func _pop(col: int) -> void:
	heights[col] -= 1
	var index := col + N * N * heights[col]
	var side := cells[index]
	for line_id in cell_lines[index]:
		score -= _value(counts[line_id])
		counts[line_id][side - 1] -= 1
		score += _value(counts[line_id])
	hash_key ^= int(keys[index][side - 1])
	for orientation in 8: symmetry_hashes[orientation] ^= int(keys[int(symmetry_maps[orientation][col]) + (index / (N*N)) * N*N][side-1])
	score -= _center(col) * (1 if side == 2 else -1)
	cells[index] = 0
	side_stones[side-1] -= 1

func _rank(side: int, preferred: int, ply: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for col in _legal():
		if ply == 0:
			var representative: int = col
			for orientation in root_symmetries: representative = mini(representative, int(symmetry_maps[orientation][col]))
			if representative != col: continue
		var won := _push(col, side)
		var value := score if side == 2 else -score
		# Penalise support moves that open an immediately winning cell above this piece.
		if heights[col] < N and _winning_at(col + N * N * heights[col], 3 - side): value -= 2000000
		_pop(col)
		if col == int(killers.get(ply, -1)): value += 1000
		if col == preferred: value += 4000000
		if won: value += MATE
		result.append({"col": col, "value": value})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.value > b.value)
	return result

func _out_of_time() -> bool:
	if cancelled or Time.get_ticks_msec() >= deadline:
		aborted = true
	return aborted

func _search(side: int, depth: int, alpha: int, beta: int, ply: int, extension: int) -> int:
	nodes += 1
	if nodes % 16 == 0 and _out_of_time(): return 0
	var wins := _winning_cols(side)
	if not wins.is_empty(): return MATE - ply
	var threats := _winning_cols(3 - side)
	if threats.size() >= 2: return -MATE + ply + 1
	var legal := _legal()
	if legal.is_empty(): return 0
	if depth <= 0 and threats.is_empty():
		if advanced_tactics and _safe_fork(side) >= 0: return MATE - ply - 2
		return _evaluate(side)
	if depth <= 0 and extension >= (6 if advanced_tactics else 2): return _evaluate(side)
	var original_alpha := alpha
	var canonical := _canonical(side)
	var key: int = canonical[0]
	var orientation: int = canonical[1]
	var preferred := -1
	if table.has(key):
		var entry: Dictionary = table[key]
		preferred = int(symmetry_inverse[orientation][int(entry.col)])
		if int(entry.depth) >= depth and depth > 0:
			if entry.bound == 0: return int(entry.value)
			if entry.bound == 1: alpha = maxi(alpha, int(entry.value))
			if entry.bound == 2: beta = mini(beta, int(entry.value))
			if alpha >= beta: return int(entry.value)
	var ranked: Array[Dictionary] = []
	if threats.size() == 1:
		ranked.append({"col": threats[0]})
	else:
		ranked = _rank(side, preferred, ply)
	var best := -MATE * 2
	var best_col: int = ranked[0].col
	for item in ranked:
		var col: int = item.col
		var won := _push(col, side)
		var value := MATE - ply if won else -_search(3 - side, maxi(0, depth - 1), -beta, -alpha, ply + 1, extension + 1 if depth <= 0 else 0)
		_pop(col)
		if aborted: return 0
		if value > best:
			best = value
			best_col = col
		alpha = maxi(alpha, best)
		if alpha >= beta:
			killers[ply] = col
			break
	if depth > 0 and table.size() < 150000:
		table[key] = {"depth": depth, "value": best, "col": int(symmetry_maps[orientation][best_col]), "bound": 2 if best <= original_alpha else (1 if best >= beta else 0)}
	return best

func _canonical(side: int) -> Array[int]:
	var best := 9223372036854775807
	var orientation := 0
	for i in 8:
		var key: int = symmetry_hashes[i] ^ (side_key if side == 2 else 0)
		if key < best:
			best = key
			orientation = i
	return [best, orientation]

func _evaluate(side: int) -> int:
	var value := score
	for line_id in lines.size():
		var c: Array = counts[line_id]
		if c[0] > 0 and c[1] > 0: continue
		var owner := 1 if c[0] > 0 else 2
		var count: int = c[owner-1]
		if count == 1 and side_stones[0]+side_stones[1] <= 14:
			# Favor several reachable attack axes, not merely an occupied central pillar.
			var reach := 0
			for index in lines[line_id]:
				if cells[index] == 0 and index/(N*N) == heights[index%(N*N)]: reach += 1
			value += reach*4*(1 if owner == 2 else -1)
		if count < 2: continue
		var playable := 0
		var support := 0
		for index in lines[line_id]:
			if cells[index] != 0: continue
			var deficit: int = index / (N*N) - heights[index % (N*N)]
			if deficit == 0: playable += 1
			support += maxi(0, deficit)
		var bonus := 0
		if count == 3: bonus = 2600 if playable > 0 else -210 + 160 / maxi(1, support)
		elif count == 2: bonus = 100 if playable >= 2 else (35 if playable == 1 and support <= 1 else -18)
		value += bonus * (1 if owner == 2 else -1)
	return value if side == 2 else -value

func _safe_fork(side: int) -> int:
	if side_stones[side-1] < 2: return -1
	var forced := _winning_cols(3-side)
	if forced.size() >= 2: return -1
	for col in _legal():
		if forced.size() == 1 and col != forced[0]: continue
		var index: int = col + N*N*heights[col]
		_push(col,side)
		var targets: Dictionary = {}
		for line_id in cell_lines[index]:
			var c: Array = counts[line_id]
			if c[side-1] != 3 or c[2-side] != 0: continue
			for empty in lines[line_id]:
				if cells[empty] == 0 and empty / (N*N) == heights[empty % (N*N)]: targets[empty % (N*N)] = true
		var above: int = col + N*N*heights[col]
		var safe := true
		if heights[col] < N:
			if _winning_at(above,side): targets[col] = true
			if _winning_at(above,3-side): safe = false
		_pop(col)
		if targets.size() >= 2 and safe: return col
	return -1
