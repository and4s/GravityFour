extends SceneTree

const Board = preload("res://scripts/board.gd")
const AI = preload("res://scripts/ai.gd")
const Profiles = preload("res://scripts/profiles.gd")
var checks := 0
var failures := 0

func check(value: bool, title: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", title)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var board := Board.new()
	for col in [Vector2i(0, 0), Vector2i(0, 4), Vector2i(1, 0), Vector2i(1, 4), Vector2i(2, 0), Vector2i(3, 4)]:
		board.drop_piece(col.x, col.y)
	var engine := AI.new()
	check(engine.lines.size() == 302, "AI enumerates 302 winning segments")
	for difficulty in 4:
		var before := board.cells.duplicate()
		check(engine.choose_move(board.snapshot(1), difficulty) == Vector2i(3, 0), "AI takes immediate win " + str(difficulty))
		check(board.cells == before, "AI does not mutate live board")
	for i in board.cells.size():
		if board.cells[i] != 0: board.cells[i] = 3 - board.cells[i]
	board.turn = 2
	check(engine.choose_move(board.snapshot(1), 2) == Vector2i(3, 0), "AI tactical victory as second player")
	board.reset()
	for col in [Vector2i(0, 0), Vector2i(0, 2), Vector2i(1, 0), Vector2i(2, 3), Vector2i(2, 0)]:
		board.drop_piece(col.x, col.y)
	for difficulty in [1, 2, 3]:
		check(engine.choose_move(board.snapshot(1), difficulty) == Vector2i(3, 0), "AI blocks opponent threat " + str(difficulty))
	board.reset()
	for difficulty in 3:
		var started := Time.get_ticks_msec()
		var column: Vector2i = AI.new().choose_move(board.snapshot(0), difficulty)
		check(column.x >= 0 and column.x < 5 and column.y >= 0 and column.y < 5, "AI legal opening")
		check(Time.get_ticks_msec() - started < 4400, "AI bounded thinking time")
	check(AI.new().choose_move(board.snapshot(0), 2, 250) == Vector2i(2,2), "hard opening controls center")
	board.drop_piece(0,0)
	var opening_ai := AI.new()
	check(opening_ai.choose_move(board.snapshot(0), 1, 300) == Vector2i(2,2), "normal reply to corner controls center")
	board.reset()
	board.drop_piece(2,2)
	var reply: Vector2i = opening_ai.choose_move(board.snapshot(1), 2, 600)
	check(reply.x >= 0 and reply.x < 5 and reply.y >= 0 and reply.y < 5, "center reply search remains legal")
	check(opening_ai.symmetry_hashes[0] == opening_ai.hash_key and opening_ai.root_symmetries.size() == 8, "symmetry hash restores after opening search")
	board.winner = 1
	check(engine.choose_move(board.snapshot(0), 2) == Vector2i(-1, -1), "AI stops after game over")
	var storage := "user://tests/features_%d_%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var profiles := Profiles.new(storage)
	var match_data := {"uid": "one", "mode": "ai_hard", "winner": 1, "seconds": 12.5}
	var entries: Array[Dictionary] = [{"name": "测试甲", "moves": 4, "result": 1}]
	check(profiles.record(match_data, entries), "record finished match")
	check(not profiles.record(match_data, entries), "no duplicate scoring")
	check(profiles.ranking("ai_normal").is_empty(), "difficulty-separated ranking")
	profiles.record({"uid": "two", "mode": "ai_hard", "seconds": 10.0}, entries)
	check(profiles.ranking("ai_hard")[0].best_streak == 2, "win streak")
	entries[0].result = -1
	profiles.record({"uid": "three", "mode": "ai_hard", "seconds": 20.0}, entries)
	check(profiles.ranking("ai_hard")[0].streak == 0, "loss resets streak")
	entries[0].result = 0
	profiles.record({"uid": "four", "mode": "ai_hard", "seconds": 30.0}, entries)
	var reloaded := Profiles.new(storage)
	var stats: Dictionary = reloaded.ranking("ai_hard")[0]
	check(stats.games == 4 and stats.wins == 2 and stats.losses == 1 and stats.draws == 1 and stats.points == 7, "persistent win loss draw points")
	check(is_equal_approx(float(stats.fastest_win), 10.0), "fastest win")
	check(Profiles.clean_name(" \n测试\t甲 ") == "测试甲", "sanitised nickname")
	check(Profiles.clean_name("") == "玩家", "empty nickname fallback")
	profiles.delete_user("玩家二")
	check(profiles.register_user("UniquePilot").ok, "register unique account")
	check(not profiles.register_user("FourthUser").ok, "account registration capped at three")
	check(not profiles.register_user("uniquepilot").ok, "case insensitive account uniqueness")
	check(not profiles.register_user("AI-test").ok, "reserved AI username")
	check(profiles.delete_history("one"), "delete individual history")
	check(not profiles.record(match_data, entries), "deleted match cannot score twice")
	check(profiles.ranking("ai_hard")[0].games == 4, "history deletion preserves score")
	profiles.clear_history()
	check(profiles.data.history.is_empty(), "clear all history")
	profiles.clear_scores("ai_hard", "测试甲")
	check(profiles.ranking("ai_hard").is_empty(), "delete user mode score")
	check("UniquePilot" in Profiles.new(storage).users(), "user registry persists after deletion")
	var legacy_path := storage + ".legacy"
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({"version":2,"profiles":{"Pilot":{"ai_hard":stats.duplicate()},"pilot":{"ai_hard":stats.duplicate()}},"settings":{},"history":[]}))
	legacy_file.close()
	var migrated := Profiles.new(legacy_path)
	check(migrated.ranking("ai_hard").size() == 1 and migrated.ranking("ai_hard")[0].games == 8, "legacy case variants merge without losing scores")
	check(not migrated.register_user("PILOT").ok, "migration reserves canonical unique username")
	board.reset()
	for col in [Vector2i(1,2),Vector2i(0,0),Vector2i(3,2),Vector2i(4,0),Vector2i(2,1),Vector2i(0,4),Vector2i(2,3),Vector2i(4,4)]: board.drop_piece(col.x,col.y)
	check(AI.new().choose_move(board.snapshot(1), 2, 1200) == Vector2i(2,2), "AI finds multi-line winning fork")
	profiles.delete_user("UniquePilot")
	check(profiles.register_user("DeleteUser").ok, "register deletable account")
	var delete_entries: Array[Dictionary] = [{"name":"DeleteUser","moves":4,"result":1}]
	profiles.record({"uid":"delete-fixture","mode":"ai_hard","seconds":10.0},delete_entries)
	check(profiles.delete_user("DeleteUser"), "delete registered account")
	var after_delete := Profiles.new(storage)
	check("DeleteUser" not in after_delete.users() and after_delete.ranking("ai_hard").is_empty(), "deleted account and all scores stay deleted after reload")
	check(after_delete.data.history.size() == 1, "account deletion preserves history")
	for username in after_delete.users():
		if after_delete.users().size() > 1: after_delete.delete_user(username)
	var survivor: String = after_delete.users()[0]
	check(not after_delete.delete_user(survivor), "last user cannot be deleted")
	check(Profiles.new(storage).users() == [survivor], "deleted default users are not recreated on reload")
	# Exercise real app integration: local summary, both profiles and AI thread cancellation.
	var game: Control = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.username_input.text = "甲"
	game.opponent_input.text = "乙"
	game.start_local()
	var history_count: int = game.profiles.data.history.size()
	for col in [Vector2i(0, 0), Vector2i(0, 4), Vector2i(1, 0), Vector2i(1, 4), Vector2i(2, 0), Vector2i(2, 4), Vector2i(3, 0)]:
		game.play_column(col)
	check(game.board.winner == 1 and game.profiles.data.history.size() == history_count + 1, "app records complete round")
	check(game.profiles.ranking("local")[0].name == "甲", "local winner ranked")
	game._finish_match()
	check(game.profiles.data.history.size() == history_count + 1, "app finish is idempotent")
	game.new_round()
	game.play_column(Vector2i(2, 2))
	game.new_round()
	check(game.profiles.data.history.size() == history_count + 1, "unfinished rounds excluded")
	game.play_column(Vector2i(2, 2))
	game.play_column(Vector2i(1, 1))
	var undo_epoch: int = game.round_id
	game.request_undo()
	check(game.board.moves == 1 and game.board.turn == 2 and game.assisted, "local undo restores turn and marks practice")
	check(game.round_id > undo_epoch and game.move_history.size() == 1, "undo invalidates stale moves and restores history")
	game.new_round()
	game.difficulty_choice.select(2)
	game.side_choice.select(1)
	game.ai_budget.value = 1.0
	game.start_ai()
	for i in 200:
		await create_timer(0.02).timeout
		if game.board.moves > 0: break
	check(game.board.moves == 1 and game.board.turn == 2, "AI first-player turn through worker thread")
	game.play_column(Vector2i(0, 0))
	await create_timer(0.45).timeout
	game.request_undo()
	check(game.board.moves == 1 and game.board.turn == 2, "AI undo cancels pending reply and restores human turn")
	game.start_local()
	await create_timer(2.0).timeout
	check(game.mode == "local" and game.board.moves == 0, "discard AI result after mode change")
	game._show_ranking()
	game._show_history()
	check(game.sound.streams.size() == 7, "all sound assets loaded")
	game.queue_free()
	await process_frame
	print("FEATURE TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
