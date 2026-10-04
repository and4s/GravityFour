extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("RELEASE FEATURE FAIL: ", description)
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound.enabled = false
	await process_frame
	check(not game.ui.guide_check.button_pressed and not game.view.guides_enabled, "connection guides default off")
	game.ui.confirm("悔棋", "请同意撤回一步", func() -> void: pass)
	check(game.ui.modal.custom_minimum_size.x <= 500 and game.ui.modal.custom_minimum_size.y <= 300, "compact confirmation dimensions")
	game.ui.close()
	for column in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(2,0),Vector2i(2,1),Vector2i(3,0)]: game.play_column(column)
	var summary: Dictionary = game._summary()
	check(summary.columns.size() == 7 and summary.final_snapshot.winner == 1, "records persist structured moves and final board")
	game.ui.show_match_detail(summary)
	var replay = game.ui.pages.detail.get_child(1)
	check(replay.board.cells == game.board.cells and replay.board.winner == 1, "replay restores final board and winning line")
	replay.seek(3)
	check(replay.board.moves == 3 and game.board.moves == 7, "stepping replay never mutates live board")
	var legacy: Dictionary = summary.duplicate(true)
	legacy.erase("columns")
	legacy.erase("final_snapshot")
	check(game.ReplayView.move_columns(legacy).size() == 7, "legacy text history can be restored")
	game.ui.close()
	check(not game.ui.overlay.visible and game.board.winner == 1, "closing replay restores live interface")
	game.mode = "host"
	game.ui.show_result()
	check(game.ui.modal_title.text == "你赢了", "host winner sees own victory")
	game.mode = "client"
	game.ui.show_result()
	check(game.ui.modal_title.text == "你输了", "client loser sees own defeat")
	check(game.ui.modal.custom_minimum_size.x <= 500 and game.ui.modal.custom_minimum_size.y <= 420, "compact result includes centered next-round controls")
	game.board.winner = 3
	game.ui.show_result()
	check(game.ui.modal_title.text == "平局", "personal draw result")
	game.mode = "local"
	check(game.UpdateChecker.repository("https://github.com/example/game/") == "example/game", "normalize GitHub repository URL")
	check(game.UpdateChecker.repository("example/game?token=secret").is_empty(), "reject invalid repository URLs")
	check(game.UpdateChecker.newer("v3.10.0", "3.9.0") and not game.UpdateChecker.newer("v3.9.0", "3.9.0") and not game.UpdateChecker.newer("3.9.1-beta", "3.9.0"), "numeric version comparison excludes prereleases")
	check(game.UpdateChecker.RELEASE_API_URL == "https://api.github.com/repos/and4s/GravityFour/releases/latest", "update endpoint is fixed to project repository")
	game.updater._completed(HTTPRequest.RESULT_SUCCESS, 200, [], JSON.stringify({"tag_name":"v3.9.1","html_url":"https://github.com/and4s/GravityFour/releases/tag/v3.9.1"}).to_utf8_buffer())
	check(not game.updater.release_url.is_empty(), "new release exposes manual download page")
	game.updater._completed(HTTPRequest.RESULT_SUCCESS, 404, [], "{}".to_utf8_buffer())
	check("Release" in game.updater.status, "missing release reports actionable status")
	game.ui.show_about()
	check(game.ui.current_page == "about" and not game.updater.info.author.is_empty(), "about page and metadata load")
	check(game.updater.info.author == "and4s", "author matches GitHub login")
	check(game.ui.pages.about.find_children("*","LineEdit",true,false).is_empty(), "repository address is read-only")
	game.updater._completed(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"tag_name":"v3.9.1","html_url":"https://github.com/example/game/releases/tag/v3.9.1"}).to_utf8_buffer())
	check(game.updater.release_url.is_empty(), "foreign repository release URL is rejected")
	game.profiles.data.settings.github_repo = "example/game"
	game._save_settings()
	check(game.Profiles.new(game.profiles.path).data.settings.github_repo == "and4s/GravityFour", "legacy custom update repository is replaced")
	game.mode = "client"
	game.leave_room()
	await create_timer(0.3).timeout
	check(game.mode == "local" and game.board.moves == 0 and not game.authenticated, "room exit returns to clean local board")
	game.queue_free()
	await process_frame
	print("RELEASE FEATURE TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
