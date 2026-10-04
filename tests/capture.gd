extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.artifacts/screenshots"))
	var game: Control = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.username_input.text = "星河"
	game.opponent_input.text = "晨曦"
	game.start_local()
	root.size = Vector2i(1280, 900)
	for frame in 20:
		await process_frame
	for z in 5:
		for x in 5:
			var pos := Vector3(x - 2.0, 0, 2.0 - z)
			var screen: Vector2 = game.view.camera.unproject_position(pos)
			if game.view.pick_column(screen) != Vector2i(x, z):
				printerr("PICK FAIL: ", x, ",", z)
				quit(1)
				return
	for column in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0), Vector2i(2, 2), Vector2i(2, 0), Vector2i(3, 3)]:
		game.play_column(column)
	game._select(Vector2i(3, 0))
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png("res://.artifacts/screenshots/preview.png")
	print("CAPTURE: ", error_string(error))
	if error != OK:
		quit(1)
		return
	game.play_column(Vector2i(3, 0))
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.artifacts/screenshots/victory.png")
	if game.board.winner != 1:
		printerr("UI VICTORY FAIL")
		quit(1)
		return
	game.result_dialog.hide()
	game._show_ranking()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.artifacts/screenshots/ranking.png")
	game.ranking_dialog.hide()
	root.size = Vector2i(1024, 740)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.artifacts/screenshots/compact.png")
	game.ui.show_history()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.artifacts/screenshots/history.png")
	game.ui.close()
	if "--mobile-preview" in OS.get_cmdline_user_args():
		root.size = Vector2i(540, 960)
		await create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.artifacts/screenshots/android-portrait.png")
		game.ui.show_new_game()
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.artifacts/screenshots/android-setup.png")
		game.ui.close()
		root.size = Vector2i(960, 540)
		await create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.artifacts/screenshots/android-landscape.png")
	print("RENDER TESTS: all 25 column picks, victory and compact layout")
	game.queue_free()
	await process_frame
	await process_frame
	quit(0)
