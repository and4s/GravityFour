extends SceneTree

const Board = preload("res://scripts/board.gd")
var checks := 0
var failures := 0

func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", title)

func _initialize() -> void:
	var board := Board.new()
	check(board.cells.size() == 125 and board.turn == 1, "initial state")
	check(not board.drop_piece(-1, 0) and not board.drop_piece(5, 0), "bounds")
	for y in 5:
		check(board.landing_y(0, 0) == y, "gravity layer " + str(y))
		check(board.drop_piece(0, 0), "legal alternating move")
	check(not board.drop_piece(0, 0), "full column")
	check(board.moves == 5 and board.winner == 0, "rejected moves do not change state")
	board.reset()
	for i in 3:
		board.drop_piece(0, 0)
		board.drop_piece(1, 0)
	board.drop_piece(0, 0)
	check(board.winner == 1 and board.winning_cells.size() == 4, "legal vertical victory")
	check(not board.drop_piece(2, 0) and board.moves == 7, "moves after game over")
	var restored := Board.new()
	check(restored.load_snapshot(board.snapshot(17)), "snapshot accepted")
	check(restored.cells == board.cells and restored.winner == 1 and restored.moves == 7, "snapshot round trip")
	check(not restored.load_snapshot({"cells": [0]}), "invalid snapshot rejected")
	# Exhaustively enumerate all winning segments of the 5x5x5 cube.
	var lines := 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				if dx < 0 or (dx == 0 and dy < 0) or (dx == 0 and dy == 0 and dz <= 0):
					continue
				var direction := Vector3i(dx, dy, dz)
				for x in 5:
					for y in 5:
						for z in 5:
							var start := Vector3i(x, y, z)
							var finish := start + direction * 3
							if finish.x < 0 or finish.y < 0 or finish.z < 0 or finish.x >= 5 or finish.y >= 5 or finish.z >= 5:
								continue
							lines += 1
							for player in [1, 2]:
								board.reset()
								for step in 4:
									var pos := start + direction * step
									board.cells[board.index(pos.x, pos.y, pos.z)] = player
								board._find_win(start + direction * 2, player)
								check(board.winner == player and board.winning_cells.size() == 4, "line %d / player %d" % [lines, player])
	check(lines == 302, "302 winning lines")
	# Replay a deterministic legal alternating 125-ply draw fixture.
	board.reset()
	var fixture: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/draw_fixture.json"))
	check(fixture.size() == 125, "draw fixture size")
	for col in fixture:
		check(board.drop_piece(int(col[0]), int(col[1])), "legal draw move")
	check(board.winner == 3 and board.moves == 125, "legal full-board draw")
	print("BOARD TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
