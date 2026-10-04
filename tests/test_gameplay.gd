extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("GAMEPLAY FAIL: ", description)
func run() -> void:
	create_timer(20).timeout.connect(func() -> void: printerr("GAMEPLAY TIMEOUT"); quit(1))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound.enabled = false
	var board = game.Board.new()
	var central := true
	for i in 12:
		var move: Vector2i = game.AI.new().choose_move(board.snapshot(0),0)
		central = central and move.x in range(1,4) and move.y in range(1,4)
	check(central,"easy AI opens in central area instead of random outer columns")
	board.drop_piece(2,2)
	board.drop_piece(0,0)
	var ai = game.AI.new()
	ai.choose_move(board.snapshot(0),1)
	check(int(ai.report.get("depth",0)) <= 6 and ai.report.get("budget_ms",0) == 1400,"normal AI uses moderate six-ply and 1400ms search")
	game.ui.rule_choice.select(0)
	game.ui.starter_choice.select(2)
	game.start_local()
	check(game.first_side == 1 and game.board.turn == 1,"alternate mode starts with red")
	game.new_round()
	check(game.first_side == 2 and game.board.turn == 2,"alternate mode swaps starting color")
	check(game.RULES.size() == 2 and game.match_mode == "local","alternating start shares classic mode and leaderboard")
	game.play_column(Vector2i(0,0))
	game.play_column(Vector2i(1,0))
	var record_data: Dictionary = game._summary()
	game.ui.show_match_detail(record_data)
	var replay = game.ui.pages.detail.get_child(1)
	check(replay.board.cells == game.board.cells and replay.board.cells[0] == 2,"replay preserves blue-first move order")
	game.ui.close()
	game.ui.rule_choice.select(1)
	game.ui.starter_choice.select(0)
	game.start_local()
	check(game.match_mode == "local_series3" and game.turn_left > 29,"series has independent leaderboard mode and countdown")
	game.turn_left = 0.01
	game._process(0.02)
	check(game.board.winner == 2 and game.end_reason == "步时超时判负" and game.match_recorded,"timeout awards opponent win exactly once")
	var user_key: String = game.names[1].to_lower()
	check(game.series_scores == [0,1],"series timeout updates score")
	game.ui.show_match_detail(game._summary())
	replay = game.ui.pages.detail.get_child(1)
	check(replay.board.winner == 2 and replay.board.moves == 0,"zero-move timeout replay preserves final verdict")
	game.ui.close()
	game.ui.rule_choice.select(0)
	game.start_local()
	game.ai_budget.value = 1.0
	game.play_column(Vector2i(2,2))
	game.play_column(Vector2i(0,0))
	game.request_hint()
	var began := Time.get_ticks_msec()
	while game.ai_thread != null and Time.get_ticks_msec()-began < 5000: await process_frame
	check(game.ai_thread == null and game.message.begins_with("建议") and int(game.ai_worker.report.get("budget_ms",0)) == 4000,"hint uses minimum 4s hard analysis and reason text")
	check(game.assisted,"hint match stays excluded from achievements and scores")
	var path := "user://tests/achievements_%d_%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	var profiles = game.Profiles.new(path)
	var entries: Array[Dictionary] = [{"name":"成就甲","result":1,"moves":4}]
	var snapshot := {"line":[[0,0,0],[1,1,1],[2,2,2],[3,3,3]]}
	for i in 10:
		profiles.record({"uid":"award-%d" % i,"mode":"ai_hard","seconds":10.0,"plies":7,"final_snapshot":snapshot},entries)
	var earned: Dictionary = profiles.data.achievements["成就甲"]
	check(earned.has("hard_win") and earned.has("space_win") and earned.has("streak3") and earned.has("wins10") and earned.has("games10"),"career and tactical achievements unlock at their thresholds")
	var before: int = earned.size()
	var practice_entries: Array[Dictionary] = []
	profiles.record({"uid":"practice","mode":"ai_hard","seconds":1.0,"plies":1},practice_entries)
	check(profiles.data.achievements["成就甲"].size() == before,"practice records award no achievements")
	check(game.Profiles.new(path).data.achievements["成就甲"].size() == before,"achievement unlocks persist")
	profiles.clear_scores("ai_hard")
	check(profiles.data.achievements["成就甲"].size() == before,"clearing leaderboard does not revoke achievements")
	profiles.delete_user("成就甲")
	check(not profiles.data.achievements.has("成就甲"),"deleting user removes their achievements")
	profiles.register_user("头像甲")
	check(profiles.set_avatar("头像甲",7) and game.Profiles.new(path).avatar_for("头像甲") == 7,"per-account avatar persists")
	profiles.set_avatar("头像甲",1000)
	check(profiles.avatar_for("头像甲") == 7,"avatar id clamped")
	var old_entries: Array[Dictionary] = [{"name":"头像甲","result":1,"moves":4}]
	profiles.record({"uid":"old-alternate","mode":"ai_easy_alternate","seconds":2.0,"plies":7},old_entries)
	var migrated = game.Profiles.new(path)
	check(migrated.data.profiles["头像甲"].ai_easy.games == 1 and not migrated.data.profiles["头像甲"].has("ai_easy_alternate"),"retired alternate leaderboard merges into classic")
	check(migrated.data.history.size() == profiles.data.history.size() and migrated.avatar_for("头像甲") == 7,"migration preserves history and avatar")
	game.ui.show_avatars()
	check(game.ui.current_page == "avatars","avatar picker available")
	game.ui.rule_choice.select(1)
	game.ui.starter_choice.select(1)
	game.start_local()
	check(game.board.turn == 1 and game.match_mode == "local_series3","series always starts red and keeps configured timers")
	game.ui.show_achievements()
	check(game.ui.current_page == "achievements","achievement page available")
	game.queue_free()
	await process_frame
	print("GAMEPLAY TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
