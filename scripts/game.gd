extends Control

const Board = preload("res://scripts/board.gd")
const BoardView = preload("res://scripts/board_view.gd")
const AI = preload("res://scripts/ai.gd")
const Profiles = preload("res://scripts/profiles.gd")
const Sfx = preload("res://scripts/sfx.gd")
const PROTOCOL := 9
const RULES := ["经典四子棋", "系列赛"]
var series_target := 2
var next_series_target := 2
var series_scores: Array[int] = [0,0]
var series_results: Array[int] = []
var series_winner := 0
var series_assisted := false
var series_credited := ""
const STARTERS := ["红方先手", "蓝方先手", "轮换先手"]
var starter_policy := 0
var next_starter_policy := 0
var room_avatars: Array[int] = [0,0]
var ruleset := 0
var next_ruleset := 0
var rules_revision := 0
var series_round := 0
var first_side := 1
const STEP_TIMES := [30,60,300,600,0]
const GAME_TIMES := [30,60,300,600,900,1800,0]
var step_limit := 600
var game_limit := 0
var next_step_limit := 600
var next_game_limit := 0
var room_frames: Array[int] = [0,0]
var turn_left := 600.0
var end_reason := ""
var unlocked: Array[String] = []
const UpdateChecker = preload("res://scripts/update_checker.gd")
const ReplayView = preload("res://scripts/replay_view.gd")
var updater: Node
var room_stats: Array[Dictionary] = [{"games": 0, "wins": 0}, {"games": 0, "wins": 0}]
var rematch_ready: Array[bool] = [false, false]
const UIShell = preload("res://scripts/ui_shell.gd")
const AMBER := Color("ef5b5d")
const JADE := Color("56a7ff")
const MUTED := Color("8ba2b8")
var ui: RefCounted
var double_tap_check: CheckButton
var last_tap_column := Vector2i(-1, -1)
var last_tap_position := Vector2.ZERO
var last_tap_at := -1000
var last_tap_round := -1
var last_tap_moves := -1
var confirm_check: CheckButton
var ai_budget: SpinBox
var ai_worker: RefCounted
var ai_task := "move"
var undo_states: Array[Dictionary] = []
var undo_counts: Array[int] = [0, 0]
var undo_timeout_seconds := 30.0
var undo_offer: Dictionary = {}
var assisted := false
var touches: Dictionary = {}
var touch_dragged := false
var mouse_dragged := false
var mouse_down := Vector2.ZERO
var board := Board.new()
var view: Node3D
var mode := "local"
var guest_id := 0
var authenticated := false
var round_id := 1
var room_password := ""
var pending := false
var disconnecting := false
var message := "选择本地双人，或创建 / 加入联机房间。"
var connection_timer: Timer
var move_timer: Timer
var status_label: Label
var turn_label: Label
var subtitle: Label
var room_label: Label
var preview_label: Label
var move_label: Label
var address_input: LineEdit
var port_input: SpinBox
var password_input: LineEdit
var host_button: Button
var join_button: Button
var reset_button: Button
var local_button: Button
var column_buttons: Array[Button] = []
var viewport_box: SubViewportContainer
var selected := Vector2i(-1, -1)
var help_dialog: AcceptDialog
var last_move := "—"
var profiles: RefCounted
var sound: Node
var username_input: LineEdit
var opponent_input: LineEdit
var difficulty_choice: OptionButton
var side_choice: OptionButton
var ai_button: Button
var sound_check: CheckButton
var volume_slider: HSlider
var player_label: Label
var results_button: Button
var result_dialog: Control
var result_text: RichTextLabel
var ranking_dialog: Control
var ranking_filter: OptionButton
var ranking_tree: Tree
var history_dialog: Control
var history_text: RichTextLabel
var names: Array[String] = ["玩家", "玩家二"]
var match_uid := ""
var match_mode := "local"
var match_recorded := false
var elapsed := 0.0
var thinking: Array[float] = [0.0, 0.0]
var move_history: Array[String] = []
var ai_side := 2
var ai_difficulty := 1
var ai_thread: Thread
var ai_round := 0
var ai_moves := 0
var ai_next_at := 0
var settings_dirty := false
var settings_save_at := 0
const FPS_OPTIONS := [30, 60, 90, 120, 0]
var fps_limit := 60
var app_focused := true
var ui_refresh_left := 0.0

func _apply_performance() -> void:
	if ui == null or ui.vsync_check == null: return
	var limit := fps_limit
	if not app_focused and ui.background_check.button_pressed:
		limit = 30 if limit == 0 else mini(limit, 30)
	Engine.max_fps = limit
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if ui.vsync_check.button_pressed else DisplayServer.VSYNC_DISABLED)
	viewport_box.stretch_shrink = 2 if ui.quality_choice.selected == 1 else 1
	view.set_low_power(ui.quality_choice.selected == 1)

func _ready() -> void:
	if OS.has_feature("android") or "--mobile-preview" in OS.get_cmdline_user_args():
		_mobile_scale()
		get_window().size_changed.connect(_mobile_scale)
	var storage_path := "user://profiles_v2.json"
	if "--isolated-test" in OS.get_cmdline_user_args():
		storage_path = "user://tests/profiles_%d_%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	profiles = Profiles.new(storage_path)
	updater = UpdateChecker.new()
	add_child(updater)
	sound = Sfx.new()
	add_child(sound)
	_build_ui()
	connection_timer = Timer.new()
	connection_timer.one_shot = true
	connection_timer.wait_time = 12
	connection_timer.timeout.connect(_connection_timeout)
	add_child(connection_timer)
	move_timer = Timer.new()
	move_timer.one_shot = true
	move_timer.wait_time = 8
	move_timer.timeout.connect(func() -> void:
		pending = false
		message = "落子确认超时，请断开后重新加入房间。"
		_refresh())
	add_child(move_timer)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	_start_rules()
	new_round(true)

func style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func label(text_value: String, size_value: int = 16, color: Color = Color("e6eef7")) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size", size_value)
	result.add_theme_color_override("font_color", color)
	return result

func button(text_value: String, callback: Callable, accent: bool = false) -> Button:
	var result := Button.new()
	result.text = text_value
	result.custom_minimum_size.y = 42
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.add_theme_stylebox_override("normal", style(Color("184740") if accent else Color("192a40"), Color("28665e") if accent else Color("2a4159"), 8))
	result.add_theme_stylebox_override("hover", style(Color("245f57") if accent else Color("28435e"), JADE, 8))
	result.add_theme_stylebox_override("pressed", style(Color("357c70"), JADE, 8))
	result.add_theme_stylebox_override("disabled", style(Color("111e30"), Color("233248"), 8))
	result.add_theme_color_override("font_disabled_color", Color("536b82"))
	result.pressed.connect(func() -> void:
		sound.play("click")
		callback.call())
	return result

func row() -> HBoxContainer:
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", 8)
	return result

func _build_ui() -> void:
	ui = UIShell.new()
	ui.build(self)

func column_name(column: Vector2i) -> String:
	return String.chr(65 + column.y) + str(column.x + 1)

func _board_input(event: InputEvent) -> void:
	if ui.overlay.visible: return
	# UI controls need touch-to-mouse emulation; the board handles real touch itself.
	if event.device == InputEvent.DEVICE_ID_EMULATION and (event is InputEventMouseButton or event is InputEventMouseMotion): return
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_reset_tap()
			view.orbit(event.relative)
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT and event.position.distance_to(mouse_down) > 6:
			mouse_dragged = true
			_reset_tap()
			view.orbit(event.relative)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_reset_tap()
			view.zoom(-0.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_reset_tap()
			view.zoom(0.6)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				mouse_down = event.position
				mouse_dragged = false
			elif not mouse_dragged:
				_tap_column(event.position)
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 1: touch_dragged = false
			else:
				touch_dragged = true
				_reset_tap()
		else:
			if touches.size() == 1 and not touch_dragged:
				_tap_column(event.position)
			touches.erase(event.index)
	if event is InputEventScreenDrag:
		var old_positions: Array = touches.values()
		var old_distance: float = old_positions[0].distance_to(old_positions[1]) if old_positions.size() > 1 else 0.0
		touches[event.index] = event.position
		touch_dragged = true
		_reset_tap()
		if touches.size() > 1:
			var positions: Array = touches.values()
			view.zoom((old_distance - positions[0].distance_to(positions[1])) * 0.015)
		else: view.orbit(event.relative)

func _select(column: Vector2i) -> void:
	selected = column
	view.preview(column, board, can_play())
	ui.refresh()
	if column.x < 0:
		preview_label.text = "移到棋盘底座，预览落点"
	else:
		var y := board.landing_y(column.x, column.y)
		preview_label.text = "%s  /  第 %d 层" % [column_name(column), y + 1] if y >= 0 else "%s  /  此柱已满" % column_name(column)

func can_play() -> bool:
	if board.winner != 0 or pending or not undo_offer.is_empty():
		return false
	if mode == "local":
		return true
	if mode == "ai":
		return board.turn != ai_side
	if mode == "host":
		return guest_id != 0 and board.turn == 1
	return authenticated and board.turn == 2

func play_column(column: Vector2i) -> void:
	if column.x < 0 or column.y < 0 or not can_play():
		return
	if board.landing_y(column.x, column.y) < 0:
		message = "此柱已满，请选择其他柱位。"
		_refresh()
		return
	_reset_tap()
	if mode == "client":
		pending = true
		move_timer.start()
		request_move.rpc_id(1, column.x, column.y, board.moves, round_id)
		_refresh()
	else:
		_commit_move(column.x, column.y)

func _commit_move(x: int, z: int) -> void:
	if board.winner != 0 or board.landing_y(x, z) < 0 or not undo_offer.is_empty(): return
	undo_states.append({"board": board.snapshot(round_id), "history": move_history.duplicate(), "last_move": last_move})
	var y := board.landing_y(x, z)
	if not board.drop_piece(x, z):
		return
	turn_left = float(step_limit)
	last_move = "%s · 第 %d 层" % [column_name(Vector2i(x, z)), y + 1]
	move_history.append("%d. %s：%s" % [board.moves, names[board.cells[board.index(x, y, z)] - 1], last_move])
	message = "已落子 %s。" % last_move
	view.sync(board)
	var sound_uid := match_uid
	get_tree().create_timer(0.38).timeout.connect(func() -> void:
		if match_uid == sound_uid: sound.play("drop"))
	if mode == "host" and guest_id != 0:
		_send_snapshot(guest_id)
	if board.winner != 0:
		_finish_match()
	ai_next_at = Time.get_ticks_msec() + 350
	_refresh()

func _refresh() -> void:
	var player := "红方" if board.turn == 1 else "蓝方"
	turn_label.text = "%s的回合" % player
	turn_label.add_theme_color_override("font_color", AMBER if board.turn == 1 else JADE)
	if board.winner == 3:
		turn_label.text = "棋盘已满 · 平局"
	elif board.winner != 0:
		turn_label.text = "%s · 四子连线获胜" % ("红方" if board.winner == 1 else "蓝方")
		turn_label.add_theme_color_override("font_color", AMBER if board.winner == 1 else JADE)
	subtitle.text = "本地双人 · %s" % names[board.turn - 1] if mode == "local" else ("你是红方 · 主机" if mode == "host" else "你是蓝方 · 客机")
	if mode == "ai":
		subtitle.text = "%s · %s" % [mode_title(match_mode), "AI 正在思考…" if board.turn == ai_side and board.winner == 0 else "等待你落子"]
	if mode == "host" and guest_id == 0:
		subtitle.text += " · 等待客机"
	elif mode == "client" and not authenticated:
		subtitle.text += " · 尚未入房"
	if board.winner != 0:
		subtitle.text = mode_title(match_mode) + " · 对局已结束"
	status_label.text = message
	move_label.text = "%03d / 125 步 · %s" % [board.moves, last_move]
	player_label.text = "红方  %s\n\n蓝方  %s" % [names[0], names[1]]
	for i in column_buttons.size():
		column_buttons[i].disabled = not can_play() or board.landing_y(i % Board.SIZE, i / Board.SIZE) < 0
	host_button.disabled = mode not in ["local", "ai"]
	join_button.disabled = mode not in ["local", "ai"]
	address_input.editable = mode in ["local", "ai"]
	port_input.editable = mode in ["local", "ai"]
	password_input.editable = mode in ["local", "ai"]
	results_button.disabled = board.winner == 0
	_select(selected)
	ui.refresh()

func _close_network() -> void:
	_cancel_ai()
	_clear_undo_offer()
	disconnecting = true
	connection_timer.stop()
	move_timer.stop()
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	guest_id = 0
	authenticated = false
	pending = false
	disconnecting = false

func start_local() -> void:
	_close_network()
	mode = "local"
	_start_rules()
	room_label.text = "无需网络，同一台电脑轮流落子。"
	message = "本地双人已就绪。红方先手。"
	new_round()

func new_round(silent: bool = false) -> void:
	if mode == "client":
		return
	_cancel_ai()
	rematch_ready.assign([false, false])
	_clear_undo_offer()
	pending = false

	var continuing := series_active()
	if not continuing:
		series_scores.assign([0,0])
		series_results.clear()
		series_winner = 0
		series_assisted = false
		series_target = next_series_target
		if ruleset == 1 or next_ruleset == 1: series_round = 0
	board.reset()
	ruleset = next_ruleset
	starter_policy = 2 if ruleset == 1 else next_starter_policy
	first_side = (1 if series_round == 0 else 3-first_side) if starter_policy == 2 else starter_policy+1
	series_round += 1
	board.turn = first_side
	step_limit = next_step_limit
	game_limit = next_game_limit
	turn_left = float(step_limit)
	end_reason = ""
	unlocked.clear()
	round_id += 1
	last_move = "—"
	_begin_match()
	result_dialog.hide()
	if not silent: sound.play("start")
	message = "%s · %s先手。" % [RULES[ruleset], "红方" if first_side == 1 else "蓝方"]
	view.sync(board, false)
	if mode == "host" and guest_id != 0:
		_send_snapshot(guest_id)
	_refresh()

func host_from_ui() -> void:
	host_game(int(port_input.value), password_input.text)

static func clean_stats(value: Variant) -> Dictionary:
	if not value is Dictionary: return {"games": 0, "wins": 0}
	var games := clampi(int(value.get("games", 0)), 0, 1000000)
	return {"games": games, "wins": clampi(int(value.get("wins", 0)), 0, games)}

func online_stats() -> Dictionary:
	var stats := {"games":0,"wins":0}
	var modes: Dictionary = profiles.data.profiles.get(Profiles.clean_name(username_input.text), {})
	for key in ["online","online_series3","online_series5"]:
		stats.games += int(modes.get(key,{}).get("games",0))
		stats.wins += int(modes.get(key,{}).get("wins",0))
	return clean_stats(stats)

func _start_rules() -> void:
	next_ruleset = ui.rule_choice.selected
	next_series_target = 2+ui.series_choice.selected
	series_winner = 0
	series_scores.assign([0,0])
	series_results.clear()
	series_assisted = false
	next_starter_policy = ui.starter_choice.selected
	ruleset = next_ruleset
	next_step_limit = STEP_TIMES[ui.step_choice.selected]
	next_game_limit = GAME_TIMES[ui.game_choice.selected]
	series_round = 0

func choose_next_rules(value: int) -> void:
	if series_active(): return
	if mode == "client": return
	if mode == "host" and board.winner == 0 and guest_id != 0: return
	next_ruleset = clampi(value,0,1)
	ui.rule_choice.select(next_ruleset)
	rules_revision += 1
	rematch_ready.assign([false,false])
	if mode == "host":
		if guest_id == 0:
			series_round = 0
			new_round()
		else: _send_snapshot(guest_id)
	ui.refresh()

func choose_next_starter(value: int) -> void:
	if series_active(): return
	if mode == "client" or (mode == "host" and guest_id != 0 and board.winner == 0): return
	next_starter_policy = clampi(value,0,2)
	ui.starter_choice.select(next_starter_policy)
	rules_revision += 1
	rematch_ready.assign([false,false])
	if mode == "host":
		if guest_id == 0:
			series_round = 0
			new_round()
		else: _send_snapshot(guest_id)
	ui.refresh()

func choose_next_times() -> void:
	if series_active(): return
	if mode == "client" or (mode == "host" and guest_id != 0 and board.winner == 0): return
	next_step_limit = STEP_TIMES[ui.step_choice.selected]
	next_game_limit = GAME_TIMES[ui.game_choice.selected]
	rules_revision += 1
	rematch_ready.assign([false,false])
	if mode == "host":
		if guest_id == 0:
			series_round = 0
			new_round()
		else: _send_snapshot(guest_id)
	ui.refresh()

static func clock_text(seconds: float) -> String:
	var value := maxi(0,ceili(seconds))
	return "%02d:%02d" % [value/60,value%60]
func time_rules_title() -> String:
	var step := next_step_limit
	return "步时 %s / 每方局时 %s" % ["不限" if step == 0 else clock_text(step),"不限" if next_game_limit == 0 else clock_text(next_game_limit)]
func series_active() -> bool:
	return ruleset == 1 and series_round > 0 and series_winner == 0 and (board.moves > 0 or not series_results.is_empty() or guest_id != 0 or mode == "ai")
func choose_series_target(value: int) -> void:
	if series_active() or mode == "client" or (mode == "host" and guest_id != 0 and board.winner == 0): return
	next_series_target = clampi(value,2,3)
	ui.series_choice.select(next_series_target-2)
	rules_revision += 1
	rematch_ready.assign([false,false])
	if mode == "host":
		if guest_id == 0:
			series_round = 0
			new_round()
		else: _send_snapshot(guest_id)
	ui.refresh()
func series_title() -> String:
	return "%s · 第 %d 局 · 红 %d : %d 蓝%s" % ["三局两胜" if series_target == 2 else "五局三胜",series_round,series_scores[0],series_scores[1]," · 系列结束" if series_winner > 0 else ""]
func _credit_series() -> void:
	if ruleset != 1 or series_credited == match_uid: return
	series_credited = match_uid
	series_assisted = series_assisted or assisted
	series_results.append(board.winner)
	if board.winner in [1,2]:
		series_scores[board.winner-1] += 1
		if series_scores[board.winner-1] >= series_target: series_winner = board.winner
func winning_axis_count() -> int:
	if board.winner not in [1,2] or board.winning_cells.is_empty(): return 0
	var axes: Dictionary = {}
	for dx in range(-1,2):
		for dy in range(-1,2):
			for dz in range(-1,2):
				if dx < 0 or (dx == 0 and dy < 0) or (dx == 0 and dy == 0 and dz <= 0): continue
				var direction := Vector3i(dx,dy,dz)
				for index in board.cells.size():
					if board.cells[index] != board.winner: continue
					var origin := Vector3i(index%5,index/25,(index/5)%5)
					var end := origin+direction*3
					if end.x < 0 or end.y < 0 or end.z < 0 or end.x >= 5 or end.y >= 5 or end.z >= 5: continue
					var complete := true
					for k in 4:
						var pos := origin+direction*k
						if board.cells[board.index(pos.x,pos.y,pos.z)] != board.winner: complete = false; break
					if complete: axes[direction] = true; break
	return axes.size()

func player_appearance(side: int) -> Dictionary:
	if mode == "ai" and side == ai_side: return {"avatar":0,"frame":8+ai_difficulty,"ai":true}
	if mode in ["host","client"]: return {"avatar":room_avatars[side-1],"frame":room_frames[side-1],"ai":false}
	return {"avatar":profiles.avatar_for(names[side-1]),"frame":profiles.frame_for(names[side-1]),"ai":false}
func change_frame(username: String, value: int) -> void:
	if not profiles.set_frame(username,value): return
	change_avatar(username,profiles.avatar_for(username))

func own_avatar() -> int:
	return profiles.avatar_for(username_input.text)

func change_avatar(username: String, value: int) -> void:
	if not profiles.set_avatar(username,value): return
	if mode == "host" and names[0].to_lower() == username.to_lower():
		room_avatars[0] = profiles.avatar_for(username)
		room_frames[0] = profiles.frame_for(username)
		if guest_id != 0: _send_snapshot(guest_id)
	elif mode == "client" and authenticated and names[1].to_lower() == username.to_lower(): avatar_changed.rpc_id(1,profiles.avatar_for(username),profiles.frame_for(username))
	ui.refresh()

@rpc("any_peer", "call_remote", "reliable")
func avatar_changed(value: int, frame: int) -> void:
	if mode != "host" or guest_id == 0 or multiplayer.get_remote_sender_id() != guest_id: return
	room_avatars[1] = clampi(value,0,12)
	room_frames[1] = frame if frame in Profiles.HUMAN_FRAMES else 0
	_send_snapshot(guest_id)

@rpc("any_peer", "call_remote", "reliable")
func report_online_stats(stats: Dictionary) -> void:
	if mode != "host" or guest_id == 0 or multiplayer.get_remote_sender_id() != guest_id: return
	room_stats[1] = clean_stats(stats)
	_send_snapshot(guest_id)
	ui.refresh()

func request_rematch() -> void:
	if board.winner == 0: return
	if mode in ["local", "ai"]:
		if series_active():
			new_round()
			return
		next_series_target = 2+ui.series_choice.selected
		next_ruleset = ui.rule_choice.selected
		next_starter_policy = ui.starter_choice.selected
		next_step_limit = STEP_TIMES[ui.step_choice.selected]
		next_game_limit = GAME_TIMES[ui.game_choice.selected]
		new_round()
	elif mode == "host" and guest_id != 0:
		_mark_rematch(1)
	elif mode == "client" and authenticated:
		rematch_ready[1] = true
		request_rematch_rpc.rpc_id(1, round_id, rules_revision)
	ui.refresh()

@rpc("any_peer", "call_remote", "reliable")
func request_rematch_rpc(expected_round: int, expected_rules: int) -> void:
	if mode != "host" or guest_id == 0 or multiplayer.get_remote_sender_id() != guest_id or expected_round != round_id or expected_rules != rules_revision or board.winner == 0: return
	_mark_rematch(2)

func _mark_rematch(side: int) -> void:
	rematch_ready[side - 1] = true
	if rematch_ready[0] and rematch_ready[1]: new_round()
	else:
		_send_snapshot(guest_id)
		ui.refresh()

func leave_room() -> void:
	if mode not in ["host", "client"]: return
	var old_peer := multiplayer.multiplayer_peer
	var was_host := mode == "host"
	if was_host and guest_id != 0: room_dissolved.rpc_id(guest_id)
	_cancel_ai()
	_clear_undo_offer()
	connection_timer.stop()
	move_timer.stop()
	mode = "local"
	guest_id = 0
	authenticated = false
	room_stats.assign([{"games": 0, "wins": 0}, {"games": 0, "wins": 0}])
	new_round()
	room_label.text = "无需网络，同一台设备轮流落子。"
	message = "房间已解散。" if was_host else "已退出房间。"
	_refresh()
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		if multiplayer.multiplayer_peer == old_peer: _close_network()
		elif old_peer != null: old_peer.close())

@rpc("authority", "call_remote", "reliable")
func room_dissolved() -> void:
	if mode != "client": return
	start_local()
	message = "主机已解散房间，已返回本地模式。"
	_refresh()

func host_game(port: int, password: String = "") -> bool:
	if mode not in ["local", "ai"]:
		return false
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("0.0.0.0")
	var error := peer.create_server(port, 1)
	if error != OK:
		message = "创建失败（%s），请检查端口是否被占用。" % error_string(error)
		_refresh()
		return false
	multiplayer.multiplayer_peer = peer
	mode = "host"
	_start_rules()
	room_password = password
	room_avatars.assign([own_avatar(),0])
	room_frames.assign([profiles.frame_for(username_input.text),0])
	new_round()
	var addresses: Array[String] = []
	for item in IP.get_local_interfaces():
		var title := str(item.get("friendly", ""))
		if title.is_empty(): title = str(item.get("name","网卡"))
		for ip in item.get("addresses", []):
			if "." in ip and not ip.begins_with("127.") and not ip.begins_with("169.254."):
				addresses.append("%s：%s" % [title, ip])
	room_label.text = "UDP %d\n%s\n同一 Wi-Fi：选 Wi-Fi 网卡的 IPv4；VPN：选对应虚拟网卡的 IP。每个地址属于不同网卡，不保证都能互通。" % [port, "\n".join(addresses)]
	message = "房间已创建，等待一位客机加入。"
	_refresh()
	return true

func join_from_ui() -> void:
	join_game(address_input.text.strip_edges(), int(port_input.value), password_input.text)

func join_game(address: String, port: int, password: String = "") -> bool:
	if mode not in ["local", "ai"]:
		return false
	if address.is_empty() or "/" in address or ":" in address:
		message = "请填写 IPv4 地址或域名；端口单独填写，不包含 udp://。"
		_refresh()
		return false
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		message = "连接启动失败：%s" % error_string(error)
		_refresh()
		return false
	_cancel_ai()
	_reset_tap()
	multiplayer.multiplayer_peer = peer
	mode = "client"
	pending = false
	authenticated = false
	room_password = password
	_save_settings()
	board.reset()
	view.sync(board, false)
	room_label.text = "目标 %s:%d（UDP）" % [address, port]
	message = "正在连接主机…"
	connection_timer.start()
	_refresh()
	return true

func _peer_connected(id: int) -> void:
	if mode == "host":
		# A connected transport is not a player until its version/password is checked.
		get_tree().create_timer(8.0).timeout.connect(func() -> void:
			if mode == "host" and guest_id != id and id in multiplayer.get_peers():
				multiplayer.multiplayer_peer.disconnect_peer(id))

func _connected() -> void:
	if mode != "client":
		return
	message = "网络已连接，正在验证房间…"
	register_player.rpc_id(1, PROTOCOL, room_password, Profiles.clean_name(username_input.text), online_stats(), own_avatar(),profiles.frame_for(username_input.text))
	_refresh()

@rpc("any_peer", "call_remote", "reliable")
func register_player(version: int, password: String, username: String = "玩家二", stats: Dictionary = {}, avatar_id: int = 0, frame: int = 0) -> void:
	if mode != "host" or not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1:
		return
	if version != PROTOCOL or password != room_password or (guest_id != 0 and guest_id != sender):
		var reason := "房间口令不正确。" if password != room_password else "版本不兼容或房间已满。"
		join_rejected.rpc_id(sender, reason)
		get_tree().create_timer(0.3).timeout.connect(func() -> void:
			if mode == "host" and sender in multiplayer.get_peers() and guest_id != sender:
				multiplayer.multiplayer_peer.disconnect_peer(sender))
		return
	if Profiles.clean_name(username).to_lower() == names[0].to_lower():
		join_rejected.rpc_id(sender, "该用户名与主机重复，请注册不同用户名。")
		return
	if ruleset == 1 and not series_results.is_empty() and series_winner == 0 and Profiles.clean_name(username) != names[1]:
		join_rejected.rpc_id(sender,"系列赛进行中，请原玩家使用相同用户名重连。")
		return
	guest_id = sender
	names[1] = Profiles.clean_name(username, "玩家二")
	set_meta("guest_name", names[1])
	room_stats[1] = clean_stats(stats)
	room_avatars[1] = clampi(avatar_id,0,12)
	room_frames[1] = frame if frame in Profiles.HUMAN_FRAMES else 0
	sound.play("connect")
	message = "客机已加入。双方可以开始对弈。"
	_send_snapshot(sender)
	_refresh()

@rpc("authority", "call_remote", "reliable")
func join_rejected(reason: String) -> void:
	if mode != "client":
		return
	_close_network()
	mode = "local"
	message = "加入失败：" + reason
	_refresh()

func _send_snapshot(id: int) -> void:
	if board.winner != 0: _credit_series()
	var data := board.snapshot(round_id)
	data["last_move"] = last_move
	data["names"] = names.duplicate()
	data["uid"] = match_uid
	data["elapsed"] = elapsed
	data["thinking"] = thinking.duplicate()
	data["history"] = move_history.duplicate()
	data["assisted"] = assisted
	data["undo_counts"] = undo_counts.duplicate()
	data["undo_offer"] = undo_offer.duplicate()
	data["undo_available"] = _undo_count_for(2) > 0
	room_stats[0] = online_stats()
	data["room_stats"] = room_stats.duplicate(true)
	data["rematch_ready"] = rematch_ready.duplicate()
	data["series_target"] = series_target
	data["next_series_target"] = next_series_target
	data["series_scores"] = series_scores
	data["series_results"] = series_results
	data["series_winner"] = series_winner
	data["series_assisted"] = series_assisted
	data["series_round"] = series_round
	data["step_limit"] = step_limit
	data["game_limit"] = game_limit
	data["next_step_limit"] = next_step_limit
	data["next_game_limit"] = next_game_limit
	data["room_frames"] = room_frames
	data["room_avatars"] = room_avatars
	data["starter_policy"] = starter_policy
	data["next_starter_policy"] = next_starter_policy
	data["ruleset"] = ruleset
	data["next_ruleset"] = next_ruleset
	data["rules_revision"] = rules_revision
	data["first_side"] = first_side
	data["turn_left"] = turn_left
	data["end_reason"] = end_reason
	data["match_mode"] = match_mode
	receive_snapshot.rpc_id(id, data)

@rpc("authority", "call_remote", "reliable")
func receive_snapshot(data: Dictionary) -> void:
	if mode != "client":
		return
	var previous_moves := board.moves
	var previous_round := round_id
	var new_uid := str(data.get("uid", ""))
	if match_uid != new_uid:
		match_recorded = false
	match_uid = new_uid
	match_mode = str(data.get("match_mode", "online"))
	ruleset = clampi(int(data.get("ruleset",0)),0,1)
	next_ruleset = clampi(int(data.get("next_ruleset",0)),0,1)
	rules_revision = int(data.get("rules_revision",0))
	first_side = int(data.get("first_side",1))
	series_target = clampi(int(data.get("series_target",2)),2,3)
	next_series_target = clampi(int(data.get("next_series_target",2)),2,3)
	series_scores.assign(data.get("series_scores",[0,0]))
	series_results.assign(data.get("series_results",[]))
	series_winner = int(data.get("series_winner",0))
	series_assisted = bool(data.get("series_assisted",false))
	series_round = int(data.get("series_round",1))
	ui.series_choice.select(next_series_target-2)
	step_limit = int(data.get("step_limit",600))
	game_limit = int(data.get("game_limit",0))
	next_step_limit = int(data.get("next_step_limit",600))
	next_game_limit = int(data.get("next_game_limit",0))
	ui.step_choice.select(maxi(0,STEP_TIMES.find(next_step_limit)))
	ui.game_choice.select(maxi(0,GAME_TIMES.find(next_game_limit)))
	turn_left = clampf(float(data.get("turn_left",600.0)),0.0,maxf(600.0,step_limit))
	var frames: Variant = data.get("room_frames",[0,0])
	if frames is Array and frames.size() == 2: room_frames.assign([int(frames[0]) if int(frames[0]) in Profiles.HUMAN_FRAMES else 0,int(frames[1]) if int(frames[1]) in Profiles.HUMAN_FRAMES else 0])
	end_reason = str(data.get("end_reason",""))
	starter_policy = clampi(int(data.get("starter_policy",0)),0,2)
	next_starter_policy = clampi(int(data.get("next_starter_policy",0)),0,2)
	ui.starter_choice.select(next_starter_policy)
	var avatar_values: Variant = data.get("room_avatars",[0,0])
	if avatar_values is Array and avatar_values.size() == 2: room_avatars.assign([clampi(int(avatar_values[0]),0,12),clampi(int(avatar_values[1]),0,12)])
	ui.rule_choice.select(next_ruleset)
	var incoming_names: Array = data.get("names", ["主机", "客机"])
	if incoming_names.size() == 2:
		names.assign([Profiles.clean_name(str(incoming_names[0])), Profiles.clean_name(str(incoming_names[1]))])
	elapsed = float(data.get("elapsed", 0.0))
	var incoming_thinking: Array = data.get("thinking", [0.0, 0.0])
	if incoming_thinking.size() == 2:
		thinking.assign(incoming_thinking)
	move_history.assign(data.get("history", []))
	assisted = bool(data.get("assisted", false))
	undo_counts.assign(data.get("undo_counts", [0, 0]))
	var stats: Variant = data.get("room_stats", [])
	if stats is Array and stats.size() == 2:
		room_stats.assign([clean_stats(stats[0]), clean_stats(stats[1])])
	var ready_flags: Variant = data.get("rematch_ready", [false, false])
	if ready_flags is Array and ready_flags.size() == 2: rematch_ready.assign(ready_flags)
	var had_offer := not undo_offer.is_empty()
	undo_offer = data.get("undo_offer", {}).duplicate()
	if had_offer and undo_offer.is_empty() and ui.current_page == "confirm":
		ui.modal_reject = Callable()
		ui.close()
	set_meta("remote_undo_available", bool(data.get("undo_available", false)))
	if not board.load_snapshot(data):
		message = "收到无效棋局数据，请重新连接。"
		_refresh()
		return
	round_id = int(data.round)
	last_move = str(data.get("last_move", "—")).left(40)
	var first_sync := not authenticated
	authenticated = true
	pending = false
	connection_timer.stop()
	move_timer.stop()
	view.sync(board, not first_sync and round_id == previous_round and board.moves == previous_moves + 1)
	if first_sync:
		sound.play("connect")
	elif board.moves == previous_moves + 1:
		var sound_uid := match_uid
		get_tree().create_timer(0.38).timeout.connect(func() -> void:
			if match_uid == sound_uid: sound.play("drop"))
	elif round_id != previous_round:
		result_dialog.hide()
		sound.play("start")
	message = "已加入房间，棋局已同步。" if first_sync else "棋局已同步。"
	if board.winner != 0:
		_finish_match()
	_refresh()

@rpc("any_peer", "call_remote", "reliable")
func request_move(x: int, z: int, expected_moves: int, expected_round: int) -> void:
	if mode != "host" or not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != guest_id or guest_id == 0:
		return
	if expected_moves != board.moves or expected_round != round_id or board.turn != 2 or board.winner != 0 or not undo_offer.is_empty():
		_send_snapshot(sender)
		return
	if x < 0 or z < 0 or x >= Board.SIZE or z >= Board.SIZE or board.landing_y(x, z) < 0:
		_send_snapshot(sender)
		return
	_commit_move(x, z)

func _peer_disconnected(id: int) -> void:
	if disconnecting:
		return
	if mode == "host" and id == guest_id:
		guest_id = 0
		rematch_ready.assign([false, false])
		room_stats[1] = {"games": 0, "wins": 0}
		_clear_undo_offer()
		message = "客机已离线，棋局保留。等待客机重新加入。"
		_refresh()

func _server_disconnected() -> void:
	if disconnecting or mode != "client":
		return
	_close_network()
	# Preserve the last visible board, but lock input until reconnect/local restart.
	mode = "local"
	message = "主机连接已断开。可重新加入恢复棋局，或点击本地双人重开。"
	pending = true
	_refresh()

func _connection_failed() -> void:
	if disconnecting or mode != "client":
		return
	_close_network()
	mode = "local"
	message = "连接失败。检查地址、UDP 端口、防火墙及隧道 / VPN。"
	_refresh()

func _connection_timeout() -> void:
	if mode != "client" or authenticated:
		return
	_close_network()
	mode = "local"
	message = "连接超时。检查主机已开房、UDP 端口与防火墙。同 Wi-Fi / 同认证账户不保证互通：校园网可能隔离设备；可改用个人热点或 UDP SakuraFrp。"
	_refresh()

func _exit_tree() -> void:
	_cancel_ai()
	if ai_thread != null and ai_thread.is_started():
		ai_thread.wait_to_finish()
	if profiles != null and username_input != null:
		_save_settings()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()

func _process(delta: float) -> void:
	var active := mode in ["local", "ai"] or (mode == "host" and guest_id != 0) or (mode == "client" and authenticated)

	if board.winner == 0 and active and not (mode == "local" and pending) and undo_offer.is_empty():
		elapsed += delta
		thinking[board.turn-1] += delta
		if step_limit > 0: turn_left = maxf(0.0,turn_left-delta)
		var step_expired := step_limit > 0 and turn_left <= 0
		var game_expired: bool = game_limit > 0 and thinking[board.turn-1] >= game_limit
		if (step_expired or game_expired) and mode != "client":
			end_reason = "步时超时判负" if step_expired else "局时超时判负"
			board.winner = 3-board.turn
			_cancel_ai()
			if mode == "host" and guest_id != 0: _send_snapshot(guest_id)
			_finish_match()
			_refresh()
	if settings_dirty and Time.get_ticks_msec() >= settings_save_at:
		_save_settings()
	ui_refresh_left -= delta
	if ui_refresh_left <= 0.0:
		ui_refresh_left = 0.25
		ui.refresh()
	if ai_thread != null and ai_thread.is_started():
		if ai_thread.is_alive():
			return
		var column: Vector2i = ai_thread.wait_to_finish()
		ai_thread = null
		if ai_task == "hint" and mode in ["local", "ai"] and not ai_worker.cancelled and ai_round == round_id and ai_moves == board.moves and board.winner == 0:
			_select(column)
			var reasons := {"win":"立即连成四子", "block":"阻止对方下一手获胜", "fork":"形成双重获胜威胁", "center":"争夺中心空间", "opening":"沿中心轴建立攻防支点", "forced_win":"搜索发现连续攻势", "position":"兼顾布局与攻防"}
			message = "建议 %s · %s · 分析深度 %d · 练习局" % [column_name(column), reasons.get(str(ai_worker.report.get("reason","position")),"兼顾布局与攻防"),int(ai_worker.report.get("depth",0))]
			_refresh()
		elif mode == "ai" and ai_round == round_id and ai_moves == board.moves and board.turn == ai_side and board.winner == 0:
			if column.x >= 0:
				_commit_move(column.x, column.y)
	if mode == "ai" and board.turn == ai_side and board.winner == 0 and ai_thread == null and Time.get_ticks_msec() >= ai_next_at:
		ai_round = round_id
		ai_moves = board.moves
		var engine := AI.new()
		ai_worker = engine
		ai_task = "move"
		var state := board.snapshot(round_id)
		var difficulty := ai_difficulty
		var search_budget := int(maxf(8.0,ai_budget.value)*1000) if difficulty == 3 else (int(ai_budget.value*1000) if difficulty == 2 else -1)
		ai_thread = Thread.new()
		var error := ai_thread.start(func() -> Vector2i: return engine.choose_move(state, difficulty, search_budget))
		if error != OK:
			ai_thread = null
			message = "AI 线程启动失败，请重新开局。"
		_refresh()

func start_ai() -> void:
	_close_network()
	mode = "ai"
	_start_rules()
	ai_difficulty = difficulty_choice.selected
	ai_side = 2 if side_choice.selected == 0 else 1
	new_round()
	message = "AI 对战已开始，%s。" % ("你先手" if board.turn != ai_side else "AI 先手")
	_refresh()

func _begin_match() -> void:
	_reset_tap()
	match_uid = "%d-%d-%d" % [int(Time.get_unix_time_from_system() * 1000), OS.get_process_id(), randi()]
	match_recorded = false
	elapsed = 0.0
	thinking.assign([0.0, 0.0])
	move_history.clear()
	undo_states.clear()
	undo_counts.assign([0, 0])
	assisted = false
	if ruleset != 1 or series_round == 1:
		var username: String = profiles._ensure_user(username_input.text)
		var opponent: String = profiles._ensure_user(Profiles.clean_name(opponent_input.text, "玩家二"))
		if opponent.to_lower() == username.to_lower():
			var other_users: Array[String] = profiles.users()
			other_users.erase(username)
			opponent = other_users[0] if not other_users.is_empty() else "访客 · 双人"
		names.assign([username, opponent])
		match_mode = "local"
		if mode == "ai":
			ai_difficulty = difficulty_choice.selected
			ai_side = 2 if side_choice.selected == 0 else 1
			match_mode = Profiles.MODES[ai_difficulty]
			names[ai_side - 1] = "AI · " + ["简单", "普通", "困难", "大师"][ai_difficulty]
			names[2 - ai_side] = username
		elif mode == "host":
			match_mode = "online"
			names[1] = "等待客机"
			if guest_id != 0:
				# During a rematch keep the already authenticated guest name.
				names[1] = Profiles.clean_name(str(get_meta("guest_name", "客机")))
		if ruleset == 1: match_mode += "_series3" if series_target == 2 else "_series5"
	ai_next_at = Time.get_ticks_msec() + 400
	_save_settings()

func _mark_settings() -> void:
	settings_dirty = true
	settings_save_at = Time.get_ticks_msec() + 700

func _save_settings() -> void:
	profiles.data.settings = {"username": Profiles.clean_name(username_input.text),
		"opponent": Profiles.clean_name(opponent_input.text, "玩家二"), "difficulty": difficulty_choice.selected,
		"side": side_choice.selected, "sound": sound.enabled, "volume": sound.volume,
		"address": address_input.text, "port": int(port_input.value), "confirm_move": confirm_check.button_pressed, "double_tap_move": double_tap_check.button_pressed, "connection_guides": ui.guide_check.button_pressed, "ai_seconds": ai_budget.value,
		"fps_limit": fps_limit, "vsync": ui.vsync_check.button_pressed,
		"background_limit": ui.background_check.button_pressed, "low_power_render": ui.quality_choice.selected == 1}
	profiles.data.settings["github_repo"] = ui.github_repo
	profiles.data.settings["ruleset"] = ui.rule_choice.selected
	profiles.data.settings["series_target"] = 2+ui.series_choice.selected
	profiles.data.settings["rules_version"] = 38
	profiles.data.settings["starter_policy"] = ui.starter_choice.selected
	profiles.data.settings["step_seconds"] = STEP_TIMES[ui.step_choice.selected]
	profiles.data.settings["game_seconds"] = GAME_TIMES[ui.game_choice.selected]
	profiles.save()
	settings_dirty = false

func mode_title(key: String) -> String:
	var base := key.trim_suffix("_blitz").trim_suffix("_alternate").trim_suffix("_series3").trim_suffix("_series5")
	var index: int = Profiles.MODES.find(base)
	var title: String = ["AI · 简单", "AI · 普通", "AI · 困难", "AI · 大师", "本地双人", "联机对战"][index] if index >= 0 else key
	if key.ends_with("_series3"): return title + " · 三局两胜"
	if key.ends_with("_series5"): return title + " · 五局三胜"
	return title + (" · 旧快棋" if key.ends_with("_blitz") else (" · 轮换先手" if key.ends_with("_alternate") else ""))

func _own_side() -> int:
	if mode == "host": return 1
	if mode == "client": return 2
	if mode == "ai": return 3 - ai_side
	return 0

func _summary() -> Dictionary:
	var counts: Array[int] = [0, 0]
	for cell in board.cells:
		if cell != 0: counts[cell - 1] += 1
	var columns: Array = []
	for column in ReplayView.move_columns({"history": move_history}): columns.append([column.x, column.y])
	return {"uid": match_uid, "mode": match_mode, "names": names.duplicate(), "winner": board.winner, "columns": columns, "final_snapshot": board.snapshot(round_id), "first_side": first_side, "end_reason": end_reason, "step_limit":step_limit,"game_limit":game_limit,"own_side":_own_side(),"winning_axes":winning_axis_count(),"series_target":series_target,"series_scores":series_scores.duplicate(),"series_results":series_results.duplicate(),"series_winner":series_winner,"series_assisted":series_assisted,
		"plies": board.moves, "counts": counts, "seconds": snappedf(elapsed, 0.01),
		"thinking": thinking.duplicate(), "date": Time.get_datetime_string_from_system(),
		"history": move_history.duplicate(), "assisted": assisted, "undo_counts": undo_counts.duplicate()}

func _finish_match() -> void:
	if match_recorded or board.winner == 0:
		return
	match_recorded = true
	if mode != "client": _credit_series()
	var summary := _summary()
	var entries: Array[Dictionary] = []
	var sides: Array[int] = []
	if mode == "local":
		sides.assign([1, 2])
	else:
		sides.append(_own_side())
	for side in sides:
		if side == 0 or names[side - 1].begins_with("访客 ·"): continue
		entries.append({"name": names[side - 1], "moves": summary.counts[side - 1],
			"result": 0 if board.winner == 3 else (1 if board.winner == side else -1)})
	if assisted: entries.clear()
	var recorded: bool = profiles.record(summary, entries)
	unlocked.assign(profiles.last_unlocks)
	if mode in ["host", "client"]:
		room_stats[_own_side() - 1] = online_stats()
		if mode == "host" and guest_id != 0: _send_snapshot(guest_id)
		elif mode == "client": report_online_stats.rpc_id(1, online_stats())
	var result_sound := "draw" if board.winner == 3 else ("victory" if _own_side() == 0 or board.winner == _own_side() else "defeat")
	var finished_uid := match_uid
	get_tree().create_timer(0.65).timeout.connect(func() -> void:
		if match_uid == finished_uid and board.winner != 0:
			sound.play(result_sound)
			if recorded: _show_result())

func _build_stats_dialogs() -> void:
	pass

func _show_result() -> void:
	ui.show_result()

func _show_ranking() -> void:
	ui.show_ranking()

func _refresh_ranking() -> void:
	ui.show_ranking()

func _show_history() -> void:
	ui.show_history()

func _cancel_ai() -> void:
	if ai_worker != null: ai_worker.cancelled = true

func _undo_count_for(side: int) -> int:
	if board.winner != 0 or board.moves == 0: return 0
	if mode == "local": return 1 if not undo_states.is_empty() else 0
	for i in range(undo_states.size() - 1, -1, -1):
		if int(undo_states[i].board.turn) == side:
			return undo_states.size() - i
	return 0

func can_request_undo() -> bool:
	if board.winner != 0 or pending or not undo_offer.is_empty(): return false
	if mode == "client": return authenticated and bool(get_meta("remote_undo_available", false))
	if mode == "host" and guest_id == 0: return false
	return _undo_count_for(_own_side() if mode != "local" else board.turn) > 0

func request_undo() -> void:
	if not can_request_undo(): return
	if mode in ["local", "ai"]:
		_apply_undo(_undo_count_for(_own_side() if mode == "ai" else board.turn), _own_side() if mode == "ai" else 3 - board.turn)
	elif mode == "host": _start_undo_offer(1)
	else:
		pending = true
		request_undo_rpc.rpc_id(1, round_id, board.moves)
		message = "已发送悔棋申请，等待对方同意。"
		_refresh()

@rpc("any_peer", "call_remote", "reliable")
func request_undo_rpc(expected_round: int, expected_moves: int) -> void:
	if mode != "host" or multiplayer.get_remote_sender_id() != guest_id or guest_id == 0: return
	if expected_round != round_id or expected_moves != board.moves or not undo_offer.is_empty() or _undo_count_for(2) == 0:
		_send_snapshot(guest_id)
		return
	_start_undo_offer(2)

func _start_undo_offer(side: int) -> void:
	var count := _undo_count_for(side)
	if count == 0 or guest_id == 0 or not undo_offer.is_empty(): return
	var token := "%d-%d" % [Time.get_ticks_msec(), randi()]
	undo_offer = {"id": token, "side": side, "round": round_id, "moves": board.moves, "count": count}
	message = "悔棋申请中，棋局已锁定，等待对方答复。"
	_send_snapshot(guest_id)
	if side == 1: receive_undo_offer.rpc_id(guest_id, undo_offer)
	else: _show_undo_consent(undo_offer)
	_refresh()
	get_tree().create_timer(undo_timeout_seconds).timeout.connect(func() -> void:
		if mode == "host" and str(undo_offer.get("id", "")) == token:
			_clear_undo_offer()
			message = "悔棋申请超时，未获得同意。"
			if guest_id != 0: _send_snapshot(guest_id)
			_refresh())

@rpc("authority", "call_remote", "reliable")
func receive_undo_offer(offer: Dictionary) -> void:
	if mode != "client" or not authenticated: return
	undo_offer = offer.duplicate()
	pending = false
	_show_undo_consent(offer)
	_refresh()

func _show_undo_consent(offer: Dictionary) -> void:
	var token := str(offer.id)
	var expected_round := int(offer.round)
	var expected_moves := int(offer.moves)
	var request_name := names[int(offer.side) - 1]
	ui.confirm("对方请求悔棋", "%s 请求撤回最近 %d 步（含你的回复）。同意后本局标记为练习，不计排行榜。30 秒内未同意则拒绝。" % [request_name, offer.count],
		func() -> void: _respond_undo(token, true, expected_round, expected_moves),
		func() -> void: _respond_undo(token, false, expected_round, expected_moves))

func _respond_undo(token: String, accepted: bool, expected_round: int, expected_moves: int) -> void:
	if mode == "host": _handle_undo_reply(token, accepted, 1, expected_round, expected_moves)
	elif mode == "client": respond_undo_rpc.rpc_id(1, token, accepted, expected_round, expected_moves)

@rpc("any_peer", "call_remote", "reliable")
func respond_undo_rpc(token: String, accepted: bool, expected_round: int, expected_moves: int) -> void:
	if mode != "host" or multiplayer.get_remote_sender_id() != guest_id or guest_id == 0: return
	_handle_undo_reply(token, accepted, 2, expected_round, expected_moves)

func _handle_undo_reply(token: String, accepted: bool, side: int, expected_round: int, expected_moves: int) -> void:
	if undo_offer.is_empty() or str(undo_offer.id) != token or side == int(undo_offer.side): return
	if expected_round != round_id or expected_moves != board.moves or int(undo_offer.round) != round_id: return
	var requester := int(undo_offer.side)
	var count := int(undo_offer.count)
	_clear_undo_offer()
	if accepted: _apply_undo(count, requester)
	else:
		message = "对方拒绝了悔棋申请，继续对弈。"
		if guest_id != 0: _send_snapshot(guest_id)
		_refresh()

func _clear_undo_offer() -> void:
	var was_pending := not undo_offer.is_empty()
	undo_offer.clear()
	pending = false
	if was_pending and ui != null and ui.current_page == "confirm":
		ui.modal_reject = Callable()
		ui.close()

func _apply_undo(count: int, side: int) -> void:
	if count <= 0 or count > undo_states.size() or board.winner != 0: return
	_cancel_ai()
	var state: Dictionary = undo_states[undo_states.size() - count]
	undo_states.resize(undo_states.size() - count)
	board.load_snapshot(state.board)
	turn_left = float(step_limit)
	move_history.assign(state.history)
	last_move = str(state.last_move)
	round_id += 1
	undo_counts[side - 1] += 1
	assisted = true
	pending = false
	view.sync(board, false)
	message = "已撤回 %d 步 · 本局标记为练习。" % count
	ai_next_at = Time.get_ticks_msec() + 350
	sound.play("click")
	if mode == "host" and guest_id != 0: _send_snapshot(guest_id)
	_refresh()

func can_request_hint() -> bool:
	return mode in ["local", "ai"] and can_play() and ai_thread == null

func request_hint() -> void:
	if not can_request_hint(): return
	assisted = true
	ai_round = round_id
	ai_moves = board.moves
	ai_task = "hint"
	ai_worker = AI.new()
	var worker := ai_worker
	var state := board.snapshot(round_id)
	ai_thread = Thread.new()
	var budget := int(maxf(4.0, ai_budget.value) * 1000)
	var error := ai_thread.start(func() -> Vector2i: return worker.choose_move(state, 3, budget))
	if error != OK:
		ai_thread = null
		message = "提示线程启动失败，请重试。"
		_refresh()
		return
	message = "正在分析落点…"
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		if ui.overlay.visible: ui.close()
		else: ui.show_settings()
	elif not ui.overlay.visible:
		if event.keycode in [KEY_ENTER, KEY_SPACE]: play_column(selected)
		elif event.keycode == KEY_Z and event.ctrl_pressed: request_undo()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_IN]:
		app_focused = what == NOTIFICATION_APPLICATION_FOCUS_IN
		_apply_performance()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and ui != null:
		if ui.overlay.visible: ui.close()
		else: ui.show_settings()

func _mobile_scale() -> void:
	var window := get_window()
	var target := Vector2i(540, 960) if window.size.y > window.size.x else Vector2i(960, 540)
	if window.content_scale_size != target: window.content_scale_size = target

func _reset_tap() -> void:
	last_tap_column = Vector2i(-1, -1)
	last_tap_at = -1000
	last_tap_round = -1
	last_tap_moves = -1

func _tap_column(point: Vector2) -> void:
	var render_size := Vector2(view.get_viewport().size)
	var column: Vector2i = view.pick_column(point * render_size / viewport_box.size)
	_select(column)
	if column.x < 0 or not can_play() or board.landing_y(column.x, column.y) < 0:
		_reset_tap()
		return
	if double_tap_check.button_pressed:
		var now := Time.get_ticks_msec()
		if column == last_tap_column and point.distance_to(last_tap_position) <= 28 and now - last_tap_at <= 500 and last_tap_round == round_id and last_tap_moves == board.moves:
			_reset_tap()
			play_column(column)
		else:
			last_tap_column = column
			last_tap_position = point
			last_tap_at = now
			last_tap_round = round_id
			last_tap_moves = board.moves
			preview_label.text += " · 再点一次落子"
	elif not confirm_check.button_pressed:
		play_column(column)
