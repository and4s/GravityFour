extends SceneTree
var game: Control
var role := ""
var phase := 0
var done_at := 0
var initial_round := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, description: String) -> void:
	if not value:
		failures += 1
		printerr("ROOM FAIL: ", role, " ", description)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0]
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound.enabled = false
	game.username_input.text = "主机甲" if role == "host" else "客机乙"
	game.profiles.register_user(game.username_input.text)
	game.change_avatar(game.username_input.text,3 if role == "host" else 6)
	var entries: Array[Dictionary] = [{"name": game.username_input.text, "moves": 4, "result": 1}]
	game.profiles.record({"uid":"seed","mode":"online","seconds":1.0}, entries)
	var stats: Dictionary = game.profiles.data.profiles[game.username_input.text].online
	stats.games = 10 if role == "host" else 20
	stats.wins = 6 if role == "host" else 5
	game.change_frame(game.username_input.text,1)
	if role == "host": game.host_game(int(args[1]))
	else: game.join_game("127.0.0.1", int(args[1]))
	create_timer(25).timeout.connect(func() -> void: printerr("ROOM TIMEOUT: ", role, " phase ", phase); quit(1))
	var timer := Timer.new()
	timer.wait_time = 0.08
	timer.timeout.connect(tick)
	root.add_child(timer)
	timer.start()
func tick() -> void:
	if phase == 0:
		if (role == "host" and game.guest_id == 0) or (role != "host" and not game.authenticated): return
		check(game.room_stats[0].games == 10 and game.room_stats[1].games == 20, "both device statistics exchanged at join")
		check(game.room_avatars[0] == 3 and game.room_avatars[1] == 6,"both avatars exchanged at join")
		check(game.room_frames[0] == 1 and game.room_frames[1] == 1,"equipped frames exchanged at join")
		initial_round = game.round_id
		phase = 1
	elif phase == 1:
		if game.board.winner == 0:
			if role == "host" and game.board.turn == 1: game.play_column(Vector2i(0,0))
			elif role != "host" and game.board.turn == 2 and not game.pending: game.play_column(Vector2i(0,1))
		else:
			done_at = Time.get_ticks_msec()
			phase = 2
	elif phase == 2 and Time.get_ticks_msec() - done_at > 900:
		check(game.ui.modal_title.text == ("你赢了" if role == "host" else "你输了"), "personalized automatic settlement")
		check(game.room_stats[0].games == 11 and game.room_stats[1].games == 21 and game.room_stats[0].wins == 7, "statistics updated after completed game")
		if role == "host":
			game.change_avatar(game.username_input.text,5)
			game.change_frame(game.username_input.text,0)
			game.ui.step_choice.select(1)
			game.ui.game_choice.select(game.GAME_TIMES.find(900))
			game.choose_next_times()
			game.choose_next_rules(1)
			game.choose_next_starter(1)
			check(not game.rematch_ready[0] and not game.rematch_ready[1], "rule changes clear both ready states")
		phase = 20
	elif phase == 20 and Time.get_ticks_msec() - done_at > 1400 and game.next_ruleset == 1:
		check(game.room_avatars[0] == 5 and game.room_avatars[1] == 6,"avatar changes synchronize while in room")
		check(game.room_frames[0] == 0 and game.room_frames[1] == 1,"frame changes synchronize while in room")
		if role == "host":
			game.request_rematch()
			phase = 3
		else:
			game.request_rematch_rpc.rpc_id(1, game.round_id, game.rules_revision - 1)
			done_at = Time.get_ticks_msec()
			phase = 21
	elif phase == 21 and Time.get_ticks_msec() - done_at > 250:
		check(game.round_id == initial_round and game.board.winner != 0, "stale readiness from old rules cannot start rematch")
		game.request_rematch()
		phase = 3
	elif phase == 3 and game.round_id > initial_round:
		check(game.board.moves == 0 and game.board.winner == 0 and not game.rematch_ready[0] and not game.rematch_ready[1], "mutual rematch creates synchronized clean board")
		check(game.ruleset == 1 and game.match_mode == "online_series3", "both peers apply staged series rules")
		check(game.board.turn == 1 and game.first_side == 1,"series overrides starter choice with fixed red-first rotation")
		check(game.step_limit == 60 and game.game_limit == 900 and game.next_step_limit == 60,"both peers apply staged step and game time limits")
		done_at = Time.get_ticks_msec()
		phase = 4
	elif phase == 4:
		if role == "host" and Time.get_ticks_msec() - done_at > 700:
			game.turn_left = 0.01
			game._process(0.02)
			phase = 6
			done_at = Time.get_ticks_msec()
		elif role != "host" and game.board.winner == 2:
			phase = 6
			done_at = Time.get_ticks_msec()
	elif phase == 6 and Time.get_ticks_msec() - done_at > (1700 if role == "host" else 900):
		check(game.board.winner == 2 and game.end_reason == "步时超时判负", "authoritative timeout result synchronized")
		check(game.ui.modal_title.text == "第 1 局结束", "series uses compact round settlement")

		check(game.series_scores == [0,1] and game.series_winner == 0,"first series result synchronized without early championship")
		initial_round = game.round_id
		game.request_rematch()
		phase = 8
	elif phase == 8 and game.round_id > initial_round:
		check(game.first_side == 2 and game.series_scores == [0,1],"next online round rotates and preserves score")
		if role == "host":
			game.turn_left = 0.01
			game._process(0.02)
		done_at = Time.get_ticks_msec()
		phase = 9
	elif phase == 9 and game.board.winner == 1 and Time.get_ticks_msec()-done_at > 900:
		check(game.series_scores == [1,1] and game.series_winner == 0,"tied series stays active")
		initial_round = game.round_id
		game.request_rematch()
		phase = 10
	elif phase == 10 and game.round_id > initial_round:
		check(game.first_side == 1,"deciding round rotates starter back to red")
		if role == "host":
			game.turn_left = 0.01
			game._process(0.02)
		done_at = Time.get_ticks_msec()
		phase = 11
	elif phase == 11 and game.series_winner == 2 and Time.get_ticks_msec()-done_at > (1700 if role == "host" else 900):
		check(game.series_scores == [1,2] and game.series_results == [2,1,2],"full online best of three clinches identical champion and history")
		if role == "host":
			game.leave_room()
			phase = 5
			done_at = Time.get_ticks_msec()
		else: phase = 7
	elif phase == 7:
		if game.mode == "local":
			check("解散" in game.message and not game.ui.room_button.visible, "host dissolution notifies client and removes room controls")
			finish()
	elif phase == 5 and Time.get_ticks_msec() - done_at > 500:
		check(game.mode == "local" and not game.ui.room_button.visible, "host dissolution closes room")
		finish()
func finish() -> void:
	print("ROOM LIFECYCLE ", role, ": ", failures, " failures")
	game.queue_free()
	quit(0 if failures == 0 else 1)
