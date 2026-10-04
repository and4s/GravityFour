class_name GravityBoard
extends RefCounted

const SIZE := 5
const CONNECT := 4
const CELLS := SIZE * SIZE * SIZE
var cells: Array[int] = []
var turn := 1
var winner := 0
var winning_cells: Array[Vector3i] = []
var moves := 0

func _init() -> void:
	reset()

func reset() -> void:
	cells.clear()
	cells.resize(CELLS)
	cells.fill(0)
	turn = 1
	winner = 0
	moves = 0
	winning_cells.clear()

func index(x: int, y: int, z: int) -> int:
	return x + SIZE * (z + SIZE * y)

func get_cell(p: Vector3i) -> int:
	if p.x < 0 or p.y < 0 or p.z < 0 or p.x >= SIZE or p.y >= SIZE or p.z >= SIZE:
		return -1
	return cells[index(p.x, p.y, p.z)]

func landing_y(x: int, z: int) -> int:
	if x < 0 or z < 0 or x >= SIZE or z >= SIZE:
		return -1
	for y in SIZE:
		if cells[index(x, y, z)] == 0:
			return y
	return -1

func drop_piece(x: int, z: int) -> bool:
	if winner != 0:
		return false
	var y := landing_y(x, z)
	if y < 0:
		return false
	var player := turn
	cells[index(x, y, z)] = player
	moves += 1
	_find_win(Vector3i(x, y, z), player)
	if winner == 0:
		if moves == CELLS:
			winner = 3
		else:
			turn = 3 - turn
	return true

func _find_win(origin: Vector3i, player: int) -> void:
	# One representative for each of the 13 undirected axes in a 3D grid.
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				if dx < 0 or (dx == 0 and dy < 0) or (dx == 0 and dy == 0 and dz <= 0):
					continue
				var direction := Vector3i(dx, dy, dz)
				var line: Array[Vector3i] = [origin]
				for sign_value in [-1, 1]:
					var p: Vector3i = origin + direction * int(sign_value)
					while get_cell(p) == player:
						line.append(p)
						p += direction * sign_value
				if line.size() >= 4:
					winner = player
					winning_cells = line
					return

func snapshot(round_id: int) -> Dictionary:
	var line: Array = []
	for p in winning_cells:
		line.append([p.x, p.y, p.z])
	return {"cells": cells.duplicate(), "turn": turn, "winner": winner,
		"moves": moves, "line": line, "round": round_id}

func load_snapshot(data: Dictionary) -> bool:
	var incoming: Variant = data.get("cells")
	if not incoming is Array or incoming.size() != CELLS:
		return false
	for value in incoming:
		if not value is int or value < 0 or value > 2:
			return false
	if int(data.get("turn", 0)) not in [1, 2] or int(data.get("winner", -1)) not in [0, 1, 2, 3]:
		return false
	cells.assign(incoming)
	turn = int(data.turn)
	winner = int(data.winner)
	moves = int(data.moves)
	winning_cells.clear()
	for p in data.get("line", []):
		if p is Array and p.size() == 3:
			winning_cells.append(Vector3i(int(p[0]), int(p[1]), int(p[2])))
	return true
