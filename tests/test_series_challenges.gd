extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("SERIES FAIL: ",description)
func finish_round(game: Control, winner: int) -> void:
	game.board.winner = winner
	game._finish_match()
func run() -> void:
	create_timer(20).timeout.connect(func() -> void: printerr("SERIES TIMEOUT"); quit(1))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound.enabled = false
	check(game.game_limit == 0,"classic game time defaults unlimited")
	game.ui.rule_choice.select(1)
	game.ui.series_choice.select(0)
	game.start_local()
	check(game.first_side == 1 and game.step_limit == 600 and game.match_mode == "local_series3","series begins red with configurable clocks")
	finish_round(game,1)
	check(game.series_scores == [1,0] and game.series_winner == 0,"one win does not end best of three")
	game._finish_match()
	check(game.series_scores == [1,0],"duplicate settlement does not double credit series")
	game.request_rematch()
	check(game.board.turn == 2 and game.series_scores == [1,0] and game.series_round == 2,"next round swaps starter and preserves score")
	finish_round(game,3)
	game.request_rematch()
	check(game.board.turn == 1 and game.series_scores == [1,0],"draw requires replay and still swaps starter")
	finish_round(game,1)
	check(game.series_winner == 1 and game.series_scores == [2,0],"two wins clinch series")
	game.request_rematch()
	check(game.series_scores == [0,0] and game.series_round == 1 and game.first_side == 1,"completed series starts fresh score and first round")
	game.ui.series_choice.select(1)
	game.difficulty_choice.select(3)
	game.start_ai()
	check(game.series_target == 3 and game.match_mode == "ai_master_series5","best of five has independent bucket")
	for winner in [2,2,1,1,1]:
		finish_round(game,winner)
		if game.series_winner == 0:
			game.difficulty_choice.select(0)
			game.request_rematch()
	check(game.series_scores == [3,2] and game.series_winner == 1 and game.ai_difficulty == 3,"five game comeback preserves original AI difficulty")
	var username: String = game.names[0]
	check(game.profiles.data.achievements[username.to_lower()].has("master_comeback"),"unassisted zero-two comeback unlocks difficult challenge")
	check(game.profiles.avatar_unlocked(username,12) and game.profiles.frame_unlocked(username,16),"comeback unlocks matching knight avatar and frame")
	check(not game.profiles.set_avatar(username,10) and not game.profiles.set_frame(username,14),"unearned phoenix rewards cannot equip")
	var data := {"mode":"ai_master","own_side":1,"first_side":2,"plies":15,"winning_axes":2,"final_snapshot":{"line":[[0,0,0],[1,1,1],[2,2,2],[3,3,3]]}}
	var awards: Array[String] = game.Profiles.Achievements.eligible(data,1,{})
	check("master_late" in awards and "master_dual" in awards and "master_fast" in awards and "master_space" in awards,"one difficult tactical win can unlock skill challenges")
	data["assisted"] = true
	awards = game.Profiles.Achievements.eligible(data,1,{})
	check("master_late" not in awards and "master_dual" not in awards and "master_space" not in awards,"assisted tactical fixture earns no new challenge")
	game.ui.rule_choice.select(1)
	game.ui.series_choice.select(0)
	game.difficulty_choice.select(3)
	game.start_ai()
	game.assisted = true
	finish_round(game,1)
	game.request_rematch()
	finish_round(game,1)
	data = game._summary()
	awards = game.Profiles.Achievements.eligible(data,1,{})
	check("master_sweep" not in awards,"assistance in an earlier round disqualifies series challenge")
	game.ui.show_accounts()
	var has_achievements := false
	for button in game.ui.pages.accounts.find_children("*","Button",true,false):
		if button.text == "成就与挑战奖励": has_achievements = true
	check(has_achievements,"achievement entry belongs to account page")
	game.board.reset()
	for x in 4: game.board.cells[game.board.index(x,0,2)] = 1
	for z in 4: game.board.cells[game.board.index(2,0,z)] = 1
	game.board.winner = 1
	game.board.winning_cells.assign([Vector3i(0,0,2),Vector3i(1,0,2),Vector3i(2,0,2),Vector3i(3,0,2)])
	check(game.winning_axis_count() == 2,"crossed winning lines count two distinct axes")
	game.board.cells.fill(0)
	for x in 5: game.board.cells[game.board.index(x,0,2)] = 1
	check(game.winning_axis_count() == 1,"five collinear stones do not count as double win")
	var AI = load("res://scripts/ai.gd")
	check(AI.search_limits(1,14) == {"budget_ms":1400,"max_depth":6},"normal opening unchanged through fourteen plies")
	check(AI.search_limits(2,14,4000) == {"budget_ms":4000,"max_depth":11},"hard opening keeps configured budget and depth")
	check(AI.search_limits(1,15) == {"budget_ms":1050,"max_depth":5},"normal later play moderately reduced")
	check(AI.search_limits(2,15,4000) == {"budget_ms":3000,"max_depth":8},"hard later play moderately reduced")
	check(AI.search_limits(3,50) == {"budget_ms":8000,"max_depth":13},"master and hint search unchanged")
	data = {"mode":"ai_hard","own_side":1,"first_side":2,"plies":15,"winning_axes":2,"final_snapshot":{"line":[[0,0,0],[1,1,1],[2,2,2],[3,3,3]]}}
	data.mode = "ai_hard"
	awards = game.Profiles.Achievements.eligible(data,1,{})
	check("master_late" in awards and "master_dual" in awards and "master_fast" in awards and "master_space" in awards,"difficult tactical rewards accept hard AI")
	data.mode = "ai_normal"
	awards = game.Profiles.Achievements.eligible(data,1,{})
	check("master_late" not in awards and "master_space" not in awards,"normal AI cannot unlock hard challenge rewards")
	game.profiles.data.profiles = {username:{"ai_normal":{"games":3,"wins":2,"losses":1,"draws":0,"points":6,"best_streak":2},"online_series3":{"games":4,"wins":2,"losses":1,"draws":1,"points":7,"best_streak":1}}}
	var ranks: Array = game.profiles.ranking("*")
	check(ranks.size() == 1 and ranks[0].games == 7 and ranks[0].points == 13 and ranks[0].best_streak == 2,"unified ranking sums every mode without inventing streaks")
	game.ui.show_ranking()
	check(game.ui.pages.ranking.find_children("*","OptionButton",true,false).is_empty(),"unified ranking has no mode filter")
	game.profiles.clear_scores("*",username)
	check(game.profiles.ranking("*").is_empty(),"unified user delete clears all score categories")
	game.profiles.data.history.clear()
	var no_entries: Array[Dictionary] = []
	for i in 25:
		game.profiles.record({"uid":"retention-%d"%i,"mode":"local","seconds":1.0},no_entries)
	check(game.profiles.data.history.size() == 20 and game.profiles.data.history[0].uid == "retention-5","history only retains twenty newest rounds")
	var reloaded = game.Profiles.new(game.profiles.path)
	check(reloaded.data.history.size() == 20 and not reloaded.record({"uid":"retention-0","mode":"local","seconds":1.0},no_entries),"trimmed history retains duplicate protection after reload")
	game.ruleset = 1
	game.series_winner = 0
	game.ui.show_result()
	game.ui.adapt()
	check(game.ui.modal_title.text.begins_with("第 ") and game.ui.modal.custom_minimum_size.y <= 310,"series round has separate compact score settlement")
	check(game.ui.compact_status.visible and game.ui.compact_status.text.contains(game.names[0]),"series scoreboard stays visible on desktop")
	game.series_winner = 1
	game.ui.show_result()
	check(game.ui.modal_title.text == "系列赛结束","series champion uses final series settlement")
	check(game.view.static_batches.size() == 1,"steel pillars have no tick-ring batch")
	game.queue_free()
	await process_frame
	print("SERIES AND CHALLENGE TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
