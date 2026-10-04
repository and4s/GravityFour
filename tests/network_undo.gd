extends SceneTree
var game: Control
var role := ""
var stage_file := ""
var processed := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("UNDO FAIL: ", label)
func stage(value: int) -> void:
	var file := FileAccess.open(stage_file, FileAccess.WRITE)
	file.store_string(str(value))
func until(condition: Callable, label: String) -> void:
	for i in 160:
		if condition.call(): return
		await create_timer(0.05).timeout
	check(false, "timeout " + label)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0]
	var port := int(args[1])
	stage_file = "user://tests/undo_stage_%d.txt" % port
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound.enabled = false # Transport tests do not need the headless dummy audio driver.
	game.username_input.text = "悔棋主机" if role == "host" else "悔棋客机"
	create_timer(28.0).timeout.connect(func() -> void: printerr("UNDO FAIL process timeout"); quit(1))
	if role == "client":
		game.join_game("127.0.0.1", port, "undo")
		while true:
			await create_timer(0.05).timeout
			if not FileAccess.file_exists(stage_file): continue
			var value := int(FileAccess.get_file_as_string(stage_file))
			if value <= processed: continue
			if value in [1,4,6] and game.can_play():
				game.play_column(Vector2i(1,0)); processed = value
			elif value == 3 and game.can_request_undo():
				game.request_undo(); processed = value
			elif value in [2,5,8] and not game.undo_offer.is_empty():
				var offer: Dictionary = game.undo_offer.duplicate()
				if value == 8:
					game._respond_undo(str(offer.id), true, int(offer.round) - 1, int(offer.moves))
					await create_timer(0.3).timeout
					check(game.board.moves == 2 and not game.undo_offer.is_empty(), "stale approval ignored")
				game._respond_undo(str(offer.id), value == 5, int(offer.round), int(offer.moves))
				processed = value
			elif value == 9:
				game.start_local(); processed = value
			elif value == 10:
				print("UNDO NETWORK CLIENT: ", failures, " failures")
				await finish()
				quit(failures)
				return
	else:
		stage(0)
		game.host_game(port, "undo")
		await until(func() -> bool: return game.guest_id != 0, "authentication")
		game.play_column(Vector2i(0,0)); stage(1)
		await until(func() -> bool: return game.board.moves == 2, "guest move")
		game.request_undo(); stage(2)
		game.play_column(Vector2i(2,2))
		check(game.board.moves == 2 and not game.can_play(), "moves locked while consent pending")
		await until(func() -> bool: return game.undo_offer.is_empty(), "refusal")
		check(game.board.moves == 2, "refusal preserves board")
		stage(3)
		await until(func() -> bool: return not game.undo_offer.is_empty(), "guest request")
		var offer: Dictionary = game.undo_offer.duplicate()
		game._handle_undo_reply(str(offer.id), true, 2, int(offer.round), int(offer.moves))
		check(game.board.moves == 2 and not game.undo_offer.is_empty(), "requester cannot approve own undo")
		game._respond_undo(str(offer.id), true, int(offer.round), int(offer.moves))
		check(game.board.moves == 1 and game.board.turn == 2 and game.assisted, "host approves guest undo")
		stage(4)
		await until(func() -> bool: return game.board.moves == 2, "guest replay")
		game.request_undo(); stage(5)
		await until(func() -> bool: return game.board.moves == 0, "guest approves host undo")
		check(game.undo_counts == [1,1], "both consented undos counted")
		game.play_column(Vector2i(0,0)); stage(6)
		await until(func() -> bool: return game.board.moves == 2, "second guest replay")
		game.undo_timeout_seconds = 0.7
		game.request_undo(); stage(7)
		await until(func() -> bool: return game.undo_offer.is_empty(), "consent timeout")
		check(game.board.moves == 2, "timeout does not imply consent")
		game.undo_timeout_seconds = 30.0
		game.request_undo(); stage(8)
		await until(func() -> bool: return game.undo_offer.is_empty(), "stale then refused reply")
		check(game.board.moves == 2, "stale reply and refusal preserve board")
		game.request_undo(); stage(9)
		await until(func() -> bool: return game.guest_id == 0, "disconnect")
		check(game.undo_offer.is_empty() and game.board.moves == 2, "disconnect cancels consent without undo")
		stage(10)
		await create_timer(0.3).timeout
		print("UNDO NETWORK HOST: consent, refusal, requester spoof, stale epoch, lock, timeout, disconnect; ", failures, " failures")
		await finish()
		quit(failures)

func finish() -> void:
	game.queue_free()
	await process_frame
	await process_frame
