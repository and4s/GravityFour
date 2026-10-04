extends SceneTree

var game: Control
var role := ""
var phase := 0
var reconnect_at := 0
var ticks := 0
var seen_match := false
var saw_disconnect := false
var resume_tick := 0
var verified_restore := false
var timeout: Timer
var timer: Timer

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if args.size() > 0 else "host"
	var port := int(args[1]) if args.size() > 1 else 25491
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.username_input.text = "联机主机" if role in ["host", "duplicate-name"] else "联机客机"
	timeout = Timer.new()
	timeout.one_shot = true
	timeout.wait_time = 30
	timeout.timeout.connect(func() -> void:
		printerr("NETWORK FAIL: ", role, " phase=", phase, " message=", game.message)
		quit(1))
	root.add_child(timeout)
	timeout.start()
	if role == "host":
		if not game.host_game(port, "test-room"):
			quit(1)
	else:
		if not game.join_game("127.0.0.1", port, "wrong" if role == "bad-password" else "test-room"):
			quit(1)
	timer = Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(tick)
	root.add_child(timer)
	timer.start()

func tick() -> void:
	ticks += 1
	if role in ["bad-password", "duplicate-name"]:
		if game.mode == "local" and (("口令" in game.message) if role == "bad-password" else ("用户名" in game.message)):
			print("NETWORK PASS: ", role, " rejected")
			quit(0)
		return
	if role == "host":
		if game.guest_id != 0:
			seen_match = true
		if seen_match and game.guest_id == 0:
			saw_disconnect = true
		if phase == 0:
			if game.board.winner == 1:
				phase = 1
			elif game.can_play():
				game.play_column(Vector2i(0, 0))
		elif phase == 1 and saw_disconnect and game.guest_id != 0:
			if game.board.moves != 7 or game.board.winner != 1:
				printerr("Reconnect lost board")
				quit(1)
			resume_tick = ticks + 10
			phase = 2
		elif phase == 2 and ticks >= resume_tick:
			game.new_round()
			resume_tick = ticks + 15
			phase = 3
		elif phase == 3 and ticks >= resume_tick:
			if game.board.moves != 0:
				printerr("Invalid request changed host board")
				quit(1)
			game.play_column(Vector2i(2, 3))
			phase = 4
		elif phase == 4 and game.board.moves == 1:
			print("NETWORK PASS: authoritative moves, victory, disconnect, reconnect, rematch")
			phase = 5
			get_tree_safe_quit()
		return
	if phase == 0:
		if game.authenticated and game.board.winner == 1:
			if game.board.moves != 7:
				quit(1)
			game._close_network()
			game.mode = "local"
			reconnect_at = ticks + 10
			phase = 1
		elif game.can_play():
			game.play_column(Vector2i(1, 0))
	elif phase == 1 and ticks >= reconnect_at:
		game.join_game("127.0.0.1", int(OS.get_cmdline_user_args()[1]), "test-room")
		phase = 2
	elif phase == 2 and game.authenticated and game.board.moves == 7 and game.board.winner == 1:
		verified_restore = true
		if game.names != ["联机主机", "联机客机"] or game.profiles.ranking("online").size() != 1 or game.profiles.data.history.size() != 1:
			printerr("Name sync or deduplication failed")
			quit(1)
	elif phase == 2 and game.authenticated and game.board.moves == 0 and game.board.winner == 0:
		if game.names != ["联机主机", "联机客机"]:
			printerr("Rematch lost player names")
			quit(1)
		if not verified_restore:
			printerr("Client did not restore original board")
			quit(1)
		phase = 3
		# Deliberately send out-of-turn, stale-round, and out-of-bounds moves.
		game.request_move.rpc_id(1, 3, 3, 0, game.round_id)
		game.request_move.rpc_id(1, 3, 3, 0, game.round_id - 1)
		game.request_move.rpc_id(1, 999, -1, 0, game.round_id)
	elif phase == 3 and ticks % 10 == 0:
		if game.board.moves != 0:
			printerr("Invalid move accepted")
			quit(1)
		phase = 4
	elif phase == 4 and game.board.moves == 1:
		print("NETWORK PASS: client restored state and rejected invalid moves")
		quit(0)

func get_tree_safe_quit() -> void:
	create_timer(1.0).timeout.connect(func() -> void: quit(0))
