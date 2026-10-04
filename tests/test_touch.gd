extends SceneTree
var game: Control
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("TOUCH FAIL: ", label)
func touch(point: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	event.index = index
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func tap(point: Vector2) -> void:
	touch(point, true)
	await process_frame
	touch(point, false)
	await process_frame
func run() -> void:
	create_timer(15).timeout.connect(func() -> void: printerr("TOUCH TEST TIMEOUT"); quit(1))
	root.size = Vector2i(540, 960)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound.enabled = false
	for i in 8: await process_frame
	await tap(game.ui.account_button.get_global_rect().get_center())
	check(game.ui.overlay.visible and game.ui.current_page == "accounts", "touch opens account button with mouse emulation")
	for i in 4: await process_frame
	game.ui.scroll_view.ensure_control_visible(game.ui.register_input)
	for i in 4: await process_frame
	await tap(game.ui.register_input.get_global_rect().get_center())
	check(game.ui.register_input.has_focus() and game.ui.register_input.virtual_keyboard_enabled and game.ui.register_input.virtual_keyboard_show_on_focus, "touch focuses registration input with virtual keyboard enabled")
	for character in "测试":
		var key := InputEventKey.new()
		key.unicode = character.unicode_at(0)
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
	check(game.ui.register_input.text == "测试", "focused input accepts Unicode text")
	var choice_button: Button
	for entry in game.ui.mobile_choices:
		if entry.choice == game.ui.account_choice: choice_button = entry.button
	await tap(choice_button.get_global_rect().get_center())
	for i in 4: await process_frame
	check(game.ui.current_page == "choice" and not game.ui.account_choice.get_popup().visible, "mobile choices use embedded selection page")
	var options: Array = game.ui.pages.choice.get_children()
	await tap(options[1].get_global_rect().get_center())
	check(game.ui.current_page == "accounts" and game.ui.account_choice.selected == 1, "touch selects option and returns")
	game.ui.show_avatars()
	for i in 4: await process_frame
	var avatar_grid: GridContainer = game.ui.pages.avatars.get_child(1)
	await tap(avatar_grid.get_child(3).get_global_rect().get_center())
	check(game.ui.current_page == "accounts" and game.profiles.avatar_for(game.username_input.text) == 3,"touch changes avatar through embedded picker")
	game.ui.show_new_game()
	for i in 4: await process_frame
	var difficulty_button: Button
	for entry in game.ui.mobile_choices:
		if entry.choice == game.difficulty_choice: difficulty_button = entry.button
	game.ui.scroll_view.ensure_control_visible(difficulty_button)
	for i in 4: await process_frame
	await tap(difficulty_button.get_global_rect().get_center())
	for i in 4: await process_frame
	options = game.ui.pages.choice.get_children()
	await tap(options[2].get_global_rect().get_center())
	check(game.difficulty_choice.selected == 2 and game.ui.current_page == "new", "touch difficulty selection without popup window")
	game.ui.close()
	var column: Vector2 = game.view.camera.unproject_position(Vector3(0,0,0)) + game.viewport_box.global_position
	await tap(column)
	check(game.selected == Vector2i(2,2) and game.board.moves == 0, "touch picks center column and waits for confirmation")
	await tap(game.ui.drop_button.get_global_rect().get_center())
	check(game.board.moves == 1, "touch confirms exactly one move")
	await tap(game.ui.undo_button.get_global_rect().get_center())
	check(game.board.moves == 0, "touch undo button")
	var old_yaw: float = game.view.yaw
	touch(column, true)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = column + Vector2(35,0)
	drag.relative = Vector2(35,0)
	Input.parse_input_event(drag)
	await process_frame
	touch(drag.position, false)
	await process_frame
	check(not is_equal_approx(game.view.yaw, old_yaw) and game.board.moves == 0, "touch drag rotates without dropping")
	var distance: float = game.view.distance
	touch(column - Vector2(30,0), true, 0)
	touch(column + Vector2(30,0), true, 1)
	await process_frame
	drag.index = 1
	drag.position = column + Vector2(60,0)
	drag.relative = Vector2(30,0)
	Input.parse_input_event(drag)
	await process_frame
	touch(column - Vector2(30,0), false, 0)
	touch(drag.position, false, 1)
	await process_frame
	check(game.view.distance < distance and game.board.moves == 0, "pinch zoom avoids accidental move")
	game.new_round()
	game.double_tap_check.button_pressed = true
	await tap(column)
	check(game.board.moves == 0, "first tap selects only in double-tap mode")
	await tap(column)
	check(game.board.moves == 1, "second tap confirms exactly one move with mouse emulation")
	await tap(column)
	check(game.board.moves == 1, "third tap cannot place for the next player")
	game.new_round()
	await tap(column)
	await create_timer(0.55).timeout
	await tap(column)
	check(game.board.moves == 0, "expired double tap does not confirm")
	game.new_round()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = column - game.viewport_box.global_position
	mouse.pressed = true
	game._board_input(mouse)
	mouse.pressed = false
	game._board_input(mouse)
	check(game.board.moves == 0, "desktop first click selects only")
	mouse.pressed = true
	game._board_input(mouse)
	mouse.pressed = false
	game._board_input(mouse)
	check(game.board.moves == 1, "desktop double click confirms")
	game.mode = "host"
	game.ui.refresh()
	game.request_hint()
	check(not game.ui.hint_button.visible and game.ai_thread == null, "online hint hidden and backend refused")
	game.mode = "local"
	Input.emulate_touch_from_mouse = true
	game.ui.show_settings()
	for i in 6: await process_frame
	var fps_button: Button
	for entry in game.ui.mobile_choices:
		if entry.choice == game.ui.fps_choice: fps_button = entry.button
	await tap(fps_button.get_global_rect().get_center())
	for i in 4: await process_frame
	check(game.ui.current_page == "choice", "touch opens frame limit selection page")
	options = game.ui.pages.choice.get_children()
	await tap(options[0].get_global_rect().get_center())
	check(game.fps_limit == 30 and Engine.max_fps == 30 and game.ui.current_page == "settings", "touch applies 30 FPS and returns to settings")
	game.ui.fps_choice.select(1)
	game.ui.fps_choice.item_selected.emit(1)
	var quality_button: Button
	for entry in game.ui.mobile_choices:
		if entry.choice == game.ui.quality_choice: quality_button = entry.button
	await tap(quality_button.get_global_rect().get_center())
	for i in 4: await process_frame
	options = game.ui.pages.choice.get_children()
	await tap(options[1].get_global_rect().get_center())
	check(game.viewport_box.stretch_shrink == 2 and game.ui.current_page == "settings", "touch selects power saving quality")
	game.ui.close()
	for i in 4: await process_frame
	var low_power_point: Vector2 = game.view.camera.unproject_position(Vector3.ZERO) * game.viewport_box.size / Vector2(game.view.get_viewport().size) + game.viewport_box.global_position
	await tap(low_power_point)
	check(game.selected == Vector2i(2, 2), "low power viewport preserves touch column coordinates")
	game.ui.show_settings()
	game.ui.quality_choice.select(0)
	game.ui.quality_choice.item_selected.emit(0)
	var scroll: ScrollContainer = game.ui.scroll_view
	var point := scroll.get_global_rect().position + Vector2(25, 300)
	await swipe(point, Vector2(0,-160))
	check(scroll.scroll_vertical > 70, "settings scroll through card surfaces")
	var before_toggle: bool = game.ui.vsync_check.button_pressed
	scroll.scroll_vertical = 0
	for i in 4: await process_frame
	await swipe(game.ui.vsync_check.get_global_rect().get_center(), Vector2(0,-120))
	check(scroll.scroll_vertical > 40 and game.ui.vsync_check.button_pressed == before_toggle, "scroll through button cancels accidental toggle")
	for i in 8:
		var record_data: Dictionary = game._summary()
		record_data.uid = "scroll-fixture-" + str(i)
		record_data.winner = 1
		game.profiles.data.history.append(record_data)
	game.ui.show_history()
	for i in 6: await process_frame
	point = scroll.get_global_rect().position + Vector2(30, 190)
	await swipe(point, Vector2(0,-160))
	check(scroll.scroll_vertical > 70 and game.profiles.data.history.size() == 8, "history cards scroll without deletion")
	Input.emulate_touch_from_mouse = false
	game.ui.show_licenses()
	check(game.ui.current_page == "licenses", "bundled license panel")
	game.queue_free()
	await process_frame
	await process_frame
	print("TOUCH INPUT TESTS: %d checks, %d failures" % [checks, failures])
	quit(failures)

func swipe(start: Vector2, delta: Vector2) -> void:
	touch(start, true)
	await process_frame
	for i in 8:
		var event := InputEventScreenDrag.new()
		event.position = start + delta * float(i+1) / 8
		event.relative = delta / 8
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	touch(start+delta, false)
	await process_frame
