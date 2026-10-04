extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("CLOCK/FRAME FAIL: ",description)
func run() -> void:
	create_timer(15).timeout.connect(func() -> void: printerr("CLOCK/FRAME TIMEOUT"); quit(1))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound.enabled = false
	check(game.step_limit == 600 and game.game_limit == 0,"default ten-minute step and unlimited game time")
	game.ui.rule_choice.select(0)
	game.ui.step_choice.select(1)
	game.ui.game_choice.select(game.GAME_TIMES.find(600))
	game.start_local()
	game._process(8.0)
	game.play_column(Vector2i(0,0))
	check(game.turn_left == 60 and game.thinking[0] >= 8,"move resets step clock but preserves cumulative thinking")
	game._process(15.0)
	var spent: float = game.thinking[1]
	game.request_undo()
	check(game.turn_left == 60 and game.thinking[1] == spent,"undo does not refund game time")
	game.start_local()
	game.turn_left = 0.01
	game._process(0.02)
	check(game.board.winner == 2 and game.end_reason == "步时超时判负","classic configured step expiry loses")
	game.start_local()
	game.thinking[0] = 599.99
	game._process(0.02)
	check(game.board.winner == 2 and game.end_reason == "局时超时判负","cumulative game expiry loses even with step time left")
	game.ui.step_choice.select(4)
	game.ui.game_choice.select(game.GAME_TIMES.find(0))
	game.start_local()
	game._process(10000)
	check(game.board.winner == 0 and game.step_limit == 0 and game.game_limit == 0,"unlimited step and game time cannot expire")
	game.ui.rule_choice.select(1)
	game.start_local()
	check(game.step_limit == 0 and game.game_limit == 0,"series supports unlimited step and game time")
	var username: String = game.username_input.text
	check(not game.profiles.set_frame(username,5),"locked master frame cannot be equipped")
	game.profiles.data.achievements[username.to_lower()] = {"first_game":"test","master_win":"test"}
	check(game.profiles.set_frame(username,5) and game.Profiles.new(game.profiles.path).frame_for(username) == 5,"earned master frame equips and persists")
	game.ui.rule_choice.select(0)
	game.difficulty_choice.select(3)
	game.start_ai()
	var look: Dictionary = game.player_appearance(game.ai_side)
	check(game.match_mode == "ai_master" and look.ai and look.frame == 11,"master AI has separate score bucket and exclusive gold frame")
	game.ui.refresh()
	check(game.ui.player_icons[game.ai_side-1].is_ai and game.ui.player_icons[game.ai_side-1].frame_id == 11,"game HUD displays master robot with exclusive frame")
	check(game.ui.player_icons[2-game.ai_side].frame_id == 5,"human equipped frame appears beside game username")
	var board = game.Board.new()
	board.drop_piece(2,2)
	for difficulty in range(1,4):
		var engine = game.AI.new()
		var move: Vector2i = engine.choose_move(board.snapshot(0),difficulty,250)
		check(move.x in range(5) and move.y in range(5) and not engine.report.get("book",false) and engine.report.get("depth",0) > 0,"AI searches occupied-center opening instead of fixed random reply tier %d" % difficulty)
	var awards: Array[String] = game.Profiles.Achievements.eligible({"mode":"ai_master","plies":12},1,{})
	check("master_win" in awards,"beating master unlocks gold frame achievement")
	game.ui.show_frames()
	check(game.ui.current_page == "frames","frame picker available")
	game.queue_free()
	await process_frame
	print("CLOCK AND FRAME TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
