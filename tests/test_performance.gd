extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("PERFORMANCE FAIL: ", description)

func run() -> void:
	create_timer(15).timeout.connect(func() -> void: printerr("PERFORMANCE TEST TIMEOUT"); quit(1))
	var game: Control = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound.enabled = false
	await process_frame
	check(game.fps_limit == 60 and Engine.max_fps == 60, "default 60 FPS")
	for i in game.FPS_OPTIONS.size():
		game.ui.fps_choice.select(i)
		game.ui.fps_choice.item_selected.emit(i)
		check(Engine.max_fps == game.FPS_OPTIONS[i], "apply frame limit %d" % game.FPS_OPTIONS[i])
	game.app_focused = false
	game._apply_performance()
	check(Engine.max_fps == 30, "unlimited mode capped in background")
	game.ui.background_check.button_pressed = false
	check(Engine.max_fps == 0, "background cap can be disabled")
	game.ui.background_check.button_pressed = true
	game.app_focused = true
	game._apply_performance()
	check(Engine.max_fps == 0, "foreground restores selected unlimited mode")
	game.ui.fps_choice.select(0)
	game.ui.fps_choice.item_selected.emit(0)
	game.app_focused = false
	game._apply_performance()
	check(Engine.max_fps == 30, "background never raises a low foreground cap")
	game.app_focused = true
	game.ui.quality_choice.select(1)
	game.ui.quality_choice.item_selected.emit(1)
	check(game.viewport_box.stretch_shrink == 2 and game.view.sphere_mesh.rings == 16, "low power renders smaller viewport and mesh")
	await process_frame
	var picks_match := true
	for z in 5:
		for x in 5:
			var world_position := Vector3((x - 2) * game.view.GRID, 0, (2 - z) * game.view.GRID)
			var screen: Vector2 = game.view.camera.unproject_position(world_position) * game.viewport_box.size / Vector2(game.view.get_viewport().size)
			game._tap_column(screen)
			picks_match = picks_match and game.selected == Vector2i(x, z)
	check(picks_match, "all 25 columns pick correctly at reduced resolution")
	game._save_settings()
	var reloaded = game.Profiles.new(game.profiles.path)
	check(reloaded.data.settings.fps_limit == 30 and reloaded.data.settings.low_power_render and reloaded.data.settings.background_limit, "performance preferences survive reload")
	game.ui.quality_choice.select(0)
	game.ui.quality_choice.item_selected.emit(0)
	check(game.viewport_box.stretch_shrink == 1 and game.view.sphere_mesh.rings == 32, "standard quality restored")
	check(game.view.static_batches.size() == 1 and game.view.static_batches[0].multimesh.instance_count == 25, "25 plain steel pillars batched into one node")
	game.view.preview(Vector2i(1, 1), game.board, true)
	var material_id: int = game.view.targets[6].material_override.get_instance_id()
	game.view.preview(Vector2i(1, 1), game.board, true)
	check(game.view.targets[6].material_override.get_instance_id() == material_id, "preview reuses cached materials")
	var full_board = game.Board.new()
	var route: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/draw_fixture.json"))
	for move in route: full_board.drop_piece(int(move[0]), int(move[1]))
	game.view.set_guides(true, full_board)
	game.view.sync(full_board, false)
	var expected := 0
	for y in 5:
		for z in 5:
			for x in 5:
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						for dz in range(-1, 2):
							if dx < 0 or (dx == 0 and dy < 0) or (dx == 0 and dy == 0 and dz <= 0): continue
							var b := Vector3i(x + dx, y + dy, z + dz)
							if b.x not in range(5) or b.y not in range(5) or b.z not in range(5): continue
							if full_board.cells[full_board.index(x, y, z)] == full_board.cells[full_board.index(b.x, b.y, b.z)]: expected += 1
	var actual := 0
	for node in game.view.connection_root.get_children(): actual += node.multimesh.instance_count
	check(game.view.connection_root.get_child_count() <= 2 and actual == expected, "all full-board adjacency lines retained in at most two batches")
	game.view.set_guides(false, full_board)
	check(game.view.connection_root.get_child_count() == 0, "guides disabled immediately")
	game.view.set_guides(true, full_board)
	check(game.view.connection_root.get_child_count() == 2, "guides restored")
	game.view.sync(game.board, false)
	game.view.active_tweens.clear()
	game.view._process(0.0)
	check(game.view.get_viewport().render_target_update_mode in [SubViewport.UPDATE_ONCE, SubViewport.UPDATE_DISABLED], "static board stops continuous rendering")
	game.view.orbit(Vector2(10, 0))
	check(game.view.get_viewport().render_target_update_mode == SubViewport.UPDATE_ONCE, "camera motion invalidates cached board")
	game.board.drop_piece(2, 2)
	game.view.sync(game.board, true)
	check(game.view.get_viewport().render_target_update_mode == SubViewport.UPDATE_ALWAYS, "falling piece continues rendering")
	while not game.view.active_tweens.is_empty(): await process_frame
	check(game.view.get_viewport().render_target_update_mode != SubViewport.UPDATE_ALWAYS, "rendering sleeps after animation")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(Engine.max_fps == 30, "focus loss applies background policy")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	game.queue_free()
	await process_frame
	Engine.max_fps = 0
	print("PERFORMANCE TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
