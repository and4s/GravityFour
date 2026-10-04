extends RefCounted

const JADE := Color("4ed8cb")
const MUTED := Color("91a8bd")
var g: Control
var overlay: Control
var modal: PanelContainer
var modal_title: Label
var modal_kicker: Label
var page_host: VBoxContainer
var pages: Dictionary = {}
var current_page := ""
var modal_reject := Callable()
var main_box: BoxContainer
var info_card: PanelContainer
var footer: HBoxContainer
var account_button: Button
var account_choice: OptionButton
var opponent_choice: OptionButton
var register_input: LineEdit
var register_message: Label
var account_names: Array[String] = []
var mode_boxes: Array[VBoxContainer] = []
var new_mode := 1
var form_hint: Label
var drop_button: Button
var undo_button: Button
var hint_button: Button
var live_time: Label
var mobile := false
var header_box: BoxContainer
var scroll_view: ScrollContainer
var guide_check: CheckButton
const Avatar = preload("res://scripts/avatar.gd")
var avatar_preview: Control
var room_avatar_icons: Array[Control] = []
var series_choice: OptionButton
var series_box: VBoxContainer
var step_choice: OptionButton
var game_choice: OptionButton
var player_icons: Array[Control] = []
var player_names: Array[Label] = []
var player_clocks: Array[Label] = []
var starter_choice: OptionButton
var rule_choice: OptionButton
var result_headline: Label
var room_button: Button
var room_summary: Label
var room_bar: VBoxContainer
var rematch_button: Button
var rematch_status: Label
var github_repo := ""
var update_status: Label
var update_button: Button
var release_button: Button
var fps_choice: OptionButton
var vsync_check: CheckButton
var background_check: CheckButton
var quality_choice: OptionButton
var performance_status: Label
var mobile_choices: Array[Dictionary] = []
var compact_status: Label
var preview_wrap: VBoxContainer
var brand_kicker: Label
var shell_margin: MarginContainer

func build(game: Control) -> void:
	g = game
	mobile = OS.has_feature("android") or "--mobile-preview" in OS.get_cmdline_user_args()
	var theme := Theme.new()
	theme.default_font = load("res://fonts/NotoSansSC-Medium.ttf")
	theme.default_font_size = 20 if mobile else 17
	for kind in ["OptionButton", "Button"]:
		theme.set_stylebox("normal", kind, g.style(Color("192d43"), Color("29435b"), 10))
		theme.set_stylebox("hover", kind, g.style(Color("28465d"), JADE, 10))
		theme.set_stylebox("pressed", kind, g.style(Color("245e54"), JADE, 10))
	for kind in ["LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", kind, g.style(Color("0b1626"), Color("29435b"), 8))
		theme.set_stylebox("focus", kind, g.style(Color("102536"), JADE, 8))
	g.theme = theme
	var bg := ColorRect.new()
	bg.color = Color("080f1b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.add_child(bg)
	var margin := MarginContainer.new()
	shell_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 18)
	g.add_child(margin)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 12)
	margin.add_child(shell)
	var header := BoxContainer.new()
	header_box = header
	header.add_theme_constant_override("separation", 8)
	var brand := VBoxContainer.new()
	brand_kicker = g.label("GRAVITY FOUR  /  v" + g.UpdateChecker.VERSION, 12, JADE)
	brand.add_child(brand_kicker)
	brand.add_child(g.label("重力四子棋", 24))
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	var menus: HBoxContainer = g.row()
	header.add_child(menus)
	menus.add_child(g.button("新对局", show_new_game, true))
	menus.add_child(g.button("记录", show_history))
	menus.add_child(g.button("榜单", show_ranking))
	menus.add_child(g.button("设置", show_settings))
	room_button = g.button("解散房间", confirm_leave)
	menus.add_child(room_button)
	room_button.hide()
	account_button = g.button("账户", show_accounts)
	menus.add_child(account_button)
	shell.add_child(header)
	compact_status = g.label("", 18, JADE)
	compact_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	shell.add_child(compact_status)
	var players: HBoxContainer = g.row()
	shell.add_child(players)
	for side in 2:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel",g.style(Color("14263a"),Color("543645") if side == 0 else Color("294a66"),10))
		players.add_child(panel)
		var content: HBoxContainer = g.row()
		panel.add_child(content)
		var icon := Avatar.new()
		icon.custom_minimum_size = Vector2(42,42)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(icon)
		player_icons.append(icon)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(details)
		var name: Label = text(details,"",16)
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		player_names.append(name)
		player_clocks.append(text(details,"",13,MUTED))
	main_box = BoxContainer.new()
	main_box.add_theme_constant_override("separation", 14)
	main_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(main_box)
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", g.style(Color("0c1726"), Color("223b51"), 18))
	main_box.add_child(frame)
	g.viewport_box = SubViewportContainer.new()
	g.viewport_box.stretch = true
	g.viewport_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.viewport_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	g.viewport_box.custom_minimum_size = Vector2(220, 230)
	frame.add_child(g.viewport_box)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 700)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	g.viewport_box.add_child(viewport)
	g.view = g.BoardView.new()
	viewport.add_child(g.view)
	g.viewport_box.gui_input.connect(g._board_input)
	info_card = PanelContainer.new()
	info_card.custom_minimum_size.x = 250
	info_card.add_theme_stylebox_override("panel", g.style(Color("102034"), Color("223b51"), 18))
	main_box.add_child(info_card)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 16)
	info_card.add_child(info)
	info.add_child(g.label("本 局 对 战", 13, MUTED))
	g.turn_label = g.label("", 24, JADE)
	info.add_child(g.turn_label)
	g.subtitle = g.label("", 15, MUTED)
	g.subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(g.subtitle)
	g.player_label = g.label("", 17)
	g.player_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(g.player_label)
	g.player_label.hide()
	live_time = g.label("00:00", 32, JADE)
	info.add_child(live_time)
	g.move_label = g.label("", 14, MUTED)
	g.move_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(g.move_label)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(gap)
	g.results_button = g.button("查看赛后统计", show_result)
	info.add_child(g.results_button)
	info.add_child(g.button("俯视 / 立体", toggle_view))
	info.add_child(g.button("复位视角", reset_camera))
	g.status_label = g.label("", 15, JADE)
	g.status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shell.add_child(g.status_label)
	room_bar = VBoxContainer.new()
	var avatar_row: HBoxContainer = g.row()
	avatar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	room_bar.add_child(avatar_row)
	avatar_row.hide()
	for i in 2:
		var icon := Avatar.new()
		avatar_row.add_child(icon)
		room_avatar_icons.append(icon)
	shell.add_child(room_bar)
	room_summary = text(room_bar, "", 14, MUTED)
	room_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_button.reparent(room_bar)
	room_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	room_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_bar.hide()
	room_summary.hide()
	footer = g.row()
	g.preview_label = g.label("点棋盘选柱，再确认落子", 15, MUTED)
	g.preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_wrap = VBoxContainer.new()
	preview_wrap.add_child(g.preview_label)
	shell.add_child(preview_wrap)
	hint_button = g.button("提示", g.request_hint)
	footer.add_child(hint_button)
	undo_button = g.button("悔棋", g.request_undo)
	footer.add_child(undo_button)
	drop_button = g.button("确认落子", func() -> void: g.play_column(g.selected), true)
	drop_button.custom_minimum_size.x = 145
	footer.add_child(drop_button)
	shell.add_child(footer)
	_build_overlay()
	_build_forms()
	g.resized.connect(adapt)
	adapt.call_deferred()

func card(parent: Node, color: Color = Color("14263a")) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", g.style(color, Color("294258"), 12))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box

func text(parent: Node, value: String, font_size: int = 16, color: Color = Color("e7eff8")) -> Label:
	var result: Label = g.label(value, font_size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(result)
	return result

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 10
	g.add_child(overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.03, 0.055, 0.9)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	modal = PanelContainer.new()
	modal.add_theme_stylebox_override("panel", g.style(Color("0f2032"), Color("35566f"), 18))
	center.add_child(modal)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 15)
	modal.add_child(body)
	var header: HBoxContainer = g.row()
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_kicker = g.label("", 12, JADE)
	modal_title = g.label("", 26)
	titles.add_child(modal_kicker)
	titles.add_child(modal_title)
	header.add_child(titles)
	header.add_child(g.button("关闭", close))
	body.add_child(header)
	var scroll := ScrollContainer.new()
	scroll_view = scroll
	scroll.scroll_deadzone = 12
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	page_host = VBoxContainer.new()
	page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page_host)
	g.result_dialog = overlay
	g.ranking_dialog = overlay
	g.history_dialog = overlay
	overlay.hide()

func page(key: String, rebuild: bool = false) -> VBoxContainer:
	if not pages.has(key):
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 14)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_host.add_child(box)
		pages[key] = box
		box.hide()
	var result: VBoxContainer = pages[key]
	if rebuild:
		for child in result.get_children():
			result.remove_child(child)
			child.queue_free()
	return result

func show_page(key: String, title: String, kicker: String) -> void:
	g._reset_tap()
	modal_reject = Callable()
	current_page = key
	modal_title.text = title
	modal_title.visible = key != "result"
	modal_kicker.text = kicker
	for name in pages: pages[name].visible = name == key
	_prepare_mobile_choices()
	_prepare_scroll()
	scroll_view.scroll_vertical = 0
	adapt()
	overlay.show()

func close() -> void:
	var reject := modal_reject
	modal_reject = Callable()
	overlay.hide()
	if reject.is_valid(): reject.call()

func _field(parent: Node, caption: String, value: String, secret: bool = false) -> LineEdit:
	text(parent, caption, 14, MUTED)
	var input := LineEdit.new()
	input.text = value
	input.secret = secret
	input.virtual_keyboard_enabled = true
	input.virtual_keyboard_show_on_focus = true
	input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD if secret else LineEdit.KEYBOARD_TYPE_DEFAULT
	input.custom_minimum_size.y = 48 if mobile else 42
	parent.add_child(input)
	return input

func _build_forms() -> void:
	var settings: Dictionary = g.profiles.data.settings
	github_repo = str(settings.get("github_repo", g.updater.info.get("github_repo", "")))
	g.updater.changed.connect(_refresh_update)
	# Persistent hidden inputs keep the backend and settings independent from page layout.
	var hidden := Control.new()
	hidden.hide()
	g.add_child(hidden)
	g.username_input = LineEdit.new()
	g.username_input.text = str(settings.get("username", "玩家"))
	g.opponent_input = LineEdit.new()
	g.opponent_input.text = str(settings.get("opponent", "玩家二"))
	hidden.add_child(g.username_input)
	hidden.add_child(g.opponent_input)
	var setup := page("new")
	var modes: HBoxContainer = g.row()
	for i in 3:
		var index: int = i
		var btn: Button = g.button(["本地双人", "AI 训练", "局域网联机"][i], func() -> void: _select_mode(index))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		modes.add_child(btn)
	setup.add_child(modes)
	for i in 3:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 12)
		setup.add_child(box)
		mode_boxes.append(box)
	var rule_box := VBoxContainer.new()
	setup.add_child(rule_box)
	setup.move_child(rule_box,0)
	text(rule_box,"玩法",14,MUTED)
	rule_choice = OptionButton.new()
	for title in g.RULES: rule_choice.add_item(title)
	rule_choice.select(1 if int(settings.get("rules_version",0)) >= 38 and int(settings.get("ruleset",0)) == 1 else 0)
	rule_box.add_child(rule_choice)
	rule_choice.item_selected.connect(func(index: int) -> void: g.choose_next_rules(index); g._mark_settings())
	text(rule_box,"经典单局可自选计时，默认局时不限；系列赛选三局两胜 / 五局三胜，固定轮换先手，平局补赛。系列内规则、玩家和 AI 难度锁定。",14,MUTED)
	series_box = VBoxContainer.new()
	rule_box.add_child(series_box)
	text(series_box,"赛制 · 固定每局交换先手",14,MUTED)
	series_choice = OptionButton.new()
	for title in ["三局两胜","五局三胜"]: series_choice.add_item(title)
	series_choice.select(1 if int(settings.get("series_target",2)) == 3 else 0)
	series_box.add_child(series_choice)
	series_choice.item_selected.connect(func(index: int) -> void: g.choose_series_target(index+2); g._mark_settings())
	text(rule_box,"先手 · 系列赛固定轮换，首局红方先行",14,MUTED)
	starter_choice = OptionButton.new()
	for title in g.STARTERS: starter_choice.add_item(title)
	starter_choice.select(clampi(int(settings.get("starter_policy",2 if int(settings.get("ruleset",0)) == 2 else 0)),0,2))
	rule_box.add_child(starter_choice)
	starter_choice.item_selected.connect(func(index: int) -> void: g.choose_next_starter(index); g._mark_settings())

	text(rule_box,"步时 · 每手最多用时",14,MUTED)
	step_choice = OptionButton.new()
	for title in ["30 秒","60 秒","5 分钟","10 分钟","不限时"]: step_choice.add_item(title)
	step_choice.select(maxi(0,g.STEP_TIMES.find(int(settings.get("step_seconds",600)))))
	rule_box.add_child(step_choice)
	text(rule_box,"局时 · 每方累计思考用时",14,MUTED)
	game_choice = OptionButton.new()
	for title in ["30 秒","60 秒","5 分钟","10 分钟","15 分钟","30 分钟","不限时"]: game_choice.add_item(title)
	game_choice.select(maxi(0,g.GAME_TIMES.find(int(settings.get("game_seconds",0)))))
	rule_box.add_child(game_choice)
	for choice in [step_choice,game_choice]:
		choice.item_selected.connect(func(_index: int) -> void:
			g.choose_next_times()
			g._mark_settings()
			if current_page == "round_options": show_round_options())
	var local_box := mode_boxes[0]
	text(local_box, "同一设备轮流操作，选择另一位注册用户。", 16, MUTED)
	opponent_choice = OptionButton.new()
	local_box.add_child(opponent_choice)
	local_box.add_child(g.button("开始本地双人", func() -> void: _launch(0), true))
	var ai_box := mode_boxes[1]
	text(ai_box, "训练难度", 14, MUTED)
	g.difficulty_choice = OptionButton.new()
	for value in ["简单 · 布局入门", "普通 · 六步攻防", "困难 · 深度博弈", "大师 · 巅峰挑战"]: g.difficulty_choice.add_item(value)
	g.difficulty_choice.select(clampi(int(settings.get("difficulty", 1)), 0, 3))
	ai_box.add_child(g.difficulty_choice)
	text(ai_box, "你的棋色", 14, MUTED)
	g.side_choice = OptionButton.new()
	g.side_choice.add_item("我执红棋")
	g.side_choice.add_item("我执蓝棋")
	g.side_choice.select(clampi(int(settings.get("side", 0)), 0, 1))
	ai_box.add_child(g.side_choice)
	g.ai_button = g.button("开始 AI 训练", func() -> void: _launch(1), true)
	ai_box.add_child(g.ai_button)
	var network := mode_boxes[2]
	g.address_input = _field(network, "加入房间 · 主机 IP / 域名", str(settings.get("address", "127.0.0.1")))
	text(network, "UDP 端口", 14, MUTED)
	g.port_input = SpinBox.new()
	g.port_input.min_value = 1024
	g.port_input.max_value = 65535
	g.port_input.value = int(settings.get("port", 24567))
	network.add_child(g.port_input)
	g.password_input = _field(network, "房间口令（可选）", "", true)
	g.password_input.max_length = 32
	var net_row: HBoxContainer = g.row()
	net_row.alignment = BoxContainer.ALIGNMENT_CENTER
	g.host_button = g.button("创建房间", func() -> void:
		if g.host_game(int(g.port_input.value), g.password_input.text): close(), true)
	g.join_button = g.button("加入房间", func() -> void:
		if g.join_game(g.address_input.text.strip_edges(), int(g.port_input.value), g.password_input.text): close())
	net_row.add_child(g.host_button)
	net_row.add_child(g.join_button)
	network.add_child(net_row)
	g.room_label = text(network, "校园网即使同一 Wi-Fi / 认证账户，也可能隔离设备或分属不同子网；局域网无法互通时可用个人热点、UDP SakuraFrp 或共同虚拟网络。也请检查主机防火墙。", 14, MUTED)
	form_hint = text(setup, "", 15, Color("ffbb70"))
	for field in [g.port_input.get_line_edit()]:
		field.virtual_keyboard_enabled = true
		field.virtual_keyboard_show_on_focus = true
		field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	var prefs := page("settings")
	var performance := card(prefs)
	text(performance, "性能与画面", 20)
	text(performance, "帧率上限", 14, MUTED)
	fps_choice = OptionButton.new()
	for value in g.FPS_OPTIONS: fps_choice.add_item("不限帧" if value == 0 else "%d FPS" % value)
	g.fps_limit = int(settings.get("fps_limit", 60))
	if g.fps_limit not in g.FPS_OPTIONS: g.fps_limit = 60
	fps_choice.select(g.FPS_OPTIONS.find(g.fps_limit))
	performance.add_child(fps_choice)
	fps_choice.item_selected.connect(func(index: int) -> void:
		g.fps_limit = g.FPS_OPTIONS[index]
		g._apply_performance()
		g._mark_settings()
		refresh())
	vsync_check = CheckButton.new()
	vsync_check.text = "垂直同步（减少画面撕裂）"
	vsync_check.button_pressed = bool(settings.get("vsync", true))
	performance.add_child(vsync_check)
	background_check = CheckButton.new()
	background_check.text = "切到后台时限制为 30 FPS"
	background_check.button_pressed = bool(settings.get("background_limit", true))
	performance.add_child(background_check)
	text(performance, "棋盘画质", 14, MUTED)
	quality_choice = OptionButton.new()
	quality_choice.add_item("标准 · 清晰棋盘")
	quality_choice.add_item("省电 · 降低棋盘分辨率与模型细分")
	quality_choice.select(1 if bool(settings.get("low_power_render", false)) else 0)
	performance.add_child(quality_choice)
	for control in [vsync_check, background_check]:
		control.toggled.connect(func(_value: bool) -> void: g._apply_performance(); g._mark_settings())
	quality_choice.item_selected.connect(func(_index: int) -> void: g._apply_performance(); g._mark_settings())
	text(performance, "帧率设置立即生效并自动保存。垂直同步开启时，帧率同时受屏幕刷新率限制；省电画质只影响棋盘，文字保持清晰。后台限帧不会主动暂停联机或 AI，手机系统仍可能挂起后台应用。", 14, MUTED)
	performance_status = text(performance, "", 14, JADE)
	g._apply_performance()
	var audio := card(prefs)
	text(audio, "声音", 20)
	g.sound_check = CheckButton.new()
	g.sound_check.text = "启用音效"
	g.sound_check.button_pressed = bool(settings.get("sound", true))
	g.sound.enabled = g.sound_check.button_pressed
	audio.add_child(g.sound_check)
	g.volume_slider = HSlider.new()
	g.volume_slider.max_value = 1
	g.volume_slider.step = 0.05
	g.volume_slider.value = float(settings.get("volume", 0.65))
	g.sound.volume = g.volume_slider.value
	g.volume_slider.custom_minimum_size.y = 35
	audio.add_child(g.volume_slider)
	g.sound_check.toggled.connect(func(value: bool) -> void:
		g.sound.enabled = value
		g._mark_settings())
	g.volume_slider.value_changed.connect(func(value: float) -> void:
		g.sound.volume = value
		g._mark_settings())
	var interaction := card(prefs)
	text(interaction, "操作与思考", 20)
	g.confirm_check = CheckButton.new()
	g.confirm_check.text = "选柱后确认落子（触屏推荐）"
	g.confirm_check.button_pressed = bool(settings.get("confirm_move", true))
	interaction.add_child(g.confirm_check)
	g.confirm_check.toggled.connect(func(_value: bool) -> void: g._mark_settings())
	g.double_tap_check = CheckButton.new()
	g.double_tap_check.text = "双击同一柱位直接落子"
	g.double_tap_check.button_pressed = bool(settings.get("double_tap_move", false))
	interaction.add_child(g.double_tap_check)
	g.double_tap_check.toggled.connect(func(_value: bool) -> void: g._reset_tap(); g._mark_settings())
	text(interaction, "开启后，第一次点击选柱，0.5 秒内再次点同一位置落子；也可使用落子按钮。拖动与缩放不会触发。", 14, MUTED)
	text(interaction, "AI 深度分析预算（秒）", 14, MUTED)
	g.ai_budget = SpinBox.new()
	g.ai_budget.min_value = 1
	g.ai_budget.max_value = 8
	g.ai_budget.step = 0.5
	g.ai_budget.value = float(settings.get("ai_seconds", 3.0 if mobile else 4.0))
	interaction.add_child(g.ai_budget)
	g.ai_budget.value_changed.connect(func(_value: float) -> void: g._mark_settings())
	text(interaction,"困难使用设定预算；大师至少 8 秒，提示至少 4 秒。达到搜索目标时会提前落子。",14,MUTED)
	text(interaction, "拖动棋盘旋转；双指缩放。桌面右键旋转、滚轮缩放。悔棋 / 提示局标记为练习，不计排行榜。", 15, MUTED)
	prefs.add_child(g.button("俯视 / 立体", toggle_view))
	prefs.add_child(g.button("复位视角", reset_camera))
	prefs.add_child(g.button("规则与联机帮助", show_help))

	prefs.add_child(g.button("关于 / 作者 / 检查更新", show_about))
	prefs.add_child(g.button("开源许可", show_licenses))
	guide_check = CheckButton.new()
	guide_check.text = "同色相邻棋子连线辅助"
	guide_check.button_pressed = bool(settings.get("connection_guides", false))
	prefs.add_child(guide_check)
	g.view.set_guides(guide_check.button_pressed, g.board)
	guide_check.toggled.connect(func(value: bool) -> void: g.view.set_guides(value, g.board); g._mark_settings())
	var accounts := page("accounts")
	avatar_preview = Avatar.new()
	avatar_preview.custom_minimum_size = Vector2(84,84)
	avatar_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	accounts.add_child(avatar_preview)
	var avatar_button: Button = g.button("更改头像", show_avatars)
	avatar_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	accounts.add_child(avatar_button)
	var frame_button: Button = g.button("成就头像框",show_frames)
	frame_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	accounts.add_child(frame_button)
	var achievement_button: Button = g.button("成就与挑战奖励",show_achievements)
	achievement_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	accounts.add_child(achievement_button)
	text(accounts, "切换已有用户 · 下一局生效", 15, MUTED)
	account_choice = OptionButton.new()
	accounts.add_child(account_choice)
	account_choice.item_selected.connect(func(index: int) -> void:
		g.username_input.text = account_names[index]
		g._mark_settings()
		refresh())
	opponent_choice.item_selected.connect(func(index: int) -> void:
		g.opponent_input.text = account_names[index]
		g._mark_settings())
	var registration := card(accounts)
	text(registration, "注册唯一用户名", 20)
	register_input = _field(registration, "2～16 字，不区分大小写 · 最多 3 个账户", "")
	register_input.max_length = 16
	registration.add_child(g.button("注册并切换", func() -> void:
		var result: Dictionary = g.profiles.register_user(register_input.text)
		register_message.text = "已注册并切换到 " + str(result.name) if result.ok else str(result.error)
		if result.ok:
			g.username_input.text = str(result.name)
			g._mark_settings()
			refresh_accounts()
			refresh(), true))
	register_message = text(registration, "", 15, JADE)
	text(accounts, "用户名在本机注册列表、联机房间内唯一。无需账号服务器；不同设备仍可能注册相同名字。", 15, MUTED)
	accounts.add_child(g.button("删除当前选中用户", _delete_selected_user))
	refresh_accounts()
	_select_mode(1)

func refresh_accounts() -> void:
	account_names = g.profiles.users()
	for choice in [account_choice, opponent_choice]: choice.clear()
	for i in account_names.size():
		account_choice.add_item(account_names[i])
		opponent_choice.add_item(account_names[i])
		if account_names[i] == g.username_input.text: account_choice.select(i)
		if account_names[i] == g.opponent_input.text: opponent_choice.select(i)

func _select_mode(index: int) -> void:
	new_mode = index
	for i in mode_boxes.size(): mode_boxes[i].visible = i == index
	adapt()

func _launch(index: int) -> void:
	if (g.board.moves > 0 and g.board.winner == 0) or g.series_active():
		confirm("开始新棋局？", "当前未完成的棋局 / 系列挑战将中止，已经完成的单局记录保留。", func() -> void: _start(index))
	else: _start(index)

func _start(index: int) -> void:
	if index == 0 and g.username_input.text.to_lower() == g.opponent_input.text.to_lower():
		show_new_game()
		form_hint.text = "双方需使用不同的注册用户名。"
		return
	close()
	if index == 0: g.start_local()
	else: g.start_ai()

func show_new_game() -> void:
	refresh_accounts()
	form_hint.text = "当前用户：" + g.username_input.text + (" · 房间操作在顶部按钮" if g.mode in ["host", "client"] else "")
	show_page("new", "开始一场对弈", "PLAY / 5 × 5 × 5")
	refresh()

func show_settings() -> void:
	show_page("settings", "设置", "PREFERENCES")

func show_accounts() -> void:
	refresh_accounts()
	show_page("accounts", "用户管理", "PLAYER ID")

func show_help() -> void:
	var help := page("help", true)
	text(help, "四子连线，胜负在三维空间中决定。", 22, JADE)
	text(help, "5×5×5 棋盘，棋子落到所选柱位最低空位。横、竖、平面和空间对角线，连续四枚同色棋子获胜。旋转视角不改变向下重力。", 17)
	text(help, "局域网与外网联机", 20, JADE)
	text(help, "主机创建房间，客机输入 IP / 域名及 UDP 端口，默认 24567。同 Wi-Fi 使用 WLAN / Wi-Fi 网卡地址；VPN 双方加入同一虚拟网络后使用虚拟 IP。SakuraFrp 使用 UDP 隧道映射 127.0.0.1:24567，客机填写远程端口。主机需放行防火墙 UDP 入站，双方都用 " + g.UpdateChecker.VERSION + "。", 16)
	text(help, "悔棋与战绩", 20, JADE)
	text(help, "本地撤回一步；AI 撤回你最近一手及 AI 回复。联机撤回申请者最近一手及对方回复，必须经对方明确同意；等待时锁棋，30 秒超时拒绝。结束后不能悔棋。悔棋或提示局标为练习，保存记录但不计积分。", 16)
	show_page("help", "玩法指南", "HOW TO PLAY")

func show_result() -> void:
	if g.board.winner == 0: return
	if g.ruleset == 1:
		show_series_result()
		return
	var box := page("result", true)
	box.add_theme_constant_override("separation",8)
	var summary: Dictionary = g._summary()
	var own: int = g._own_side()
	var headline := "平局" if g.board.winner == 3 else ("你赢了" if own == g.board.winner else "你输了")
	if own == 0 and g.board.winner != 3: headline = g.names[g.board.winner - 1] + " 获胜"
	var verdict_color := Color("a4cddd") if g.board.winner == 3 else (Color("f3c76c") if own == 0 or own == g.board.winner else Color("ef8191"))
	result_headline = text(box, headline, 42 if headline.length() < 9 else 30, verdict_color)
	result_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_headline.custom_minimum_size.y = 54
	if g.ruleset == 1:
		var series_label: Label = text(box,g.series_title(),16,JADE)
		series_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var summary_label := text(box, "%s · %d 步 · %.1f 秒" % [g.end_reason if not g.end_reason.is_empty() else g.RULES[g.ruleset],g.board.moves, g.elapsed], 16, MUTED)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if own > 0:
		var own_label := text(box, "%s · 落子 %d 次 · 思考 %.1f 秒" % [g.names[own - 1], summary.counts[own - 1], g.thinking[own - 1]], 15)
		own_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var saved := text(box,"练习局，不计排行榜" if g.assisted else ("新成就：" + g.unlocked[0] if not g.unlocked.is_empty() else "战绩已保存"),14,JADE)
	saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var actions: HBoxContainer = g.row()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	rematch_button = g.button("下一局" if g.series_active() else ("再开系列" if g.ruleset == 1 else "再来一局"), g.request_rematch, true)
	actions.add_child(rematch_button)
	if g.mode in ["host", "client"]:
		actions.add_child(g.button("解散房间" if g.mode == "host" else "退出房间", func() -> void: close(); g.leave_room()))
	else: actions.add_child(g.button("返回棋盘", close))
	box.add_child(actions)
	rematch_status = text(box, "双方点击再来一局后开始" if g.mode in ["host", "client"] else "", 14, MUTED)
	rematch_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var links: HBoxContainer = g.row()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_child(g.button("回看棋盘", func() -> void: show_match_detail(summary)))
	if g.mode != "client":
		var options_button: Button = g.button("系列赛规则固定" if g.series_active() else "下一局设置", show_round_options)
		options_button.disabled = g.series_active()
		links.add_child(options_button)
	else: links.add_child(g.button("账户", show_accounts))
	box.add_child(links)
	show_page("result", headline, "MATCH COMPLETE")
	refresh()

func show_series_result() -> void:
	var box := page("result",true)
	box.add_theme_constant_override("separation",6)
	var finished: bool = g.series_winner != 0
	var title := "系列赛结束" if finished else "第 %d 局结束" % g.series_round
	var victor: int = g.series_winner if finished else g.board.winner
	var verdict: String = "平局 · 加赛并轮换先手" if victor == 3 else g.names[victor-1] + (" 夺冠" if finished else " 赢下本局")
	var label := text(box,verdict,22,JADE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scores: HBoxContainer = g.row()
	scores.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 2:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := text(column,g.names[i],16,Color("ef8191") if i == 0 else Color("82baff"))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var score_label := text(column,str(g.series_scores[i]),36,Color("ef8191") if i == 0 else Color("82baff"))
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scores.add_child(column)
		if i == 0: scores.add_child(g.label(":",32,MUTED))
	box.add_child(scores)
	var note := text(box,("先赢 %d 局夺冠 · 下一局%s先手" % [g.series_target,g.names[2-g.first_side]]) if not finished else ("新成就：" + g.unlocked[0] if not g.unlocked.is_empty() else "系列赛战绩已保存"),14,MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var actions: HBoxContainer = g.row()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	rematch_button = g.button("再开系列" if finished else "下一局",g.request_rematch,true)
	actions.add_child(rematch_button)
	actions.add_child(g.button("解散房间" if g.mode == "host" else ("退出房间" if g.mode == "client" else "返回棋盘"),func() -> void: close(); if g.mode in ["host","client"]: g.leave_room()))
	box.add_child(actions)
	rematch_status = text(box,"双方准备后开始" if g.mode in ["host","client"] else "",14,MUTED)
	rematch_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rematch_status.visible = g.mode in ["host","client"]
	show_page("result",title,title + " · " + ("三局两胜" if g.series_target == 2 else "五局三胜"))
	refresh()

func confirm_leave() -> void:
	confirm("解散房间？" if g.mode == "host" else "退出房间？", "未结束的对局不计战绩。" + ("对方将断开连接。" if g.mode == "host" else "主机将保留房间。"), g.leave_room)

func show_ranking() -> void:
	var box := page("ranking", true)
	var key := "*"
	var rows: Array[Dictionary] = g.profiles.ranking(key)
	text(box, "统一总榜 · 所有模式累计 · 胜 3 分 / 平 1 分", 14, MUTED)
	for i in rows.size():
		var entry: Dictionary = rows[i]
		var item := card(box, Color("173a39") if i == 0 else Color("14263a"))
		var header: HBoxContainer = g.row()
		var title: Label = g.label("%02d  %s" % [i + 1, entry.name], 21, JADE if i == 0 else Color("e7eff8"))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.add_child(title)
		header.add_child(g.label(str(entry.points) + " 分", 21, JADE))
		item.add_child(header)
		text(item, "%d 胜 / %d 负 / %d 平 · 胜率 %.0f%% · 最长连胜 %d" % [entry.wins, entry.losses, entry.draws, 100.0 * float(entry.wins) / maxi(1, int(entry.games)), entry.best_streak], 15, MUTED)
		var username := str(entry.name)
		item.add_child(g.button("删除该用户总榜成绩", func() -> void:
			confirm("删除成绩？", username + " 的全部累计成绩将清空。对局记录和注册用户保留。", func() -> void: g.profiles.clear_scores(key, username); show_ranking())))
	if rows.is_empty(): text(box, "暂无成绩，完成一局未使用辅助的对弈后会自动记录。", 17, MUTED)
	box.add_child(g.button("清空总榜", func() -> void:
		confirm("清空总榜？", "所有用户的累计成绩将清空，对局记录和成就保留。", func() -> void: g.profiles.clear_scores(key); show_ranking())))
	show_page("ranking", "排行榜", "LOCAL LEADERBOARD")

func show_history() -> void:
	var box := page("history", true)
	text(box, "最近 20 局 · 删除记录不改变累计积分", 14, MUTED)
	for i in range(g.profiles.data.history.size() - 1, -1, -1):
		var entry: Dictionary = g.profiles.data.history[i]
		var item := card(box)
		var result := "平局" if int(entry.winner) == 3 else str(entry.names[int(entry.winner) - 1]) + " 获胜"
		text(item, result, 21, JADE)
		text(item, "%s vs %s" % [entry.names[0], entry.names[1]], 17)
		text(item, "%s · %d 步 · %.1f 秒%s" % [g.mode_title(str(entry.mode)), entry.plies, entry.seconds, " · 练习" if bool(entry.get("assisted", false)) else ""], 15, MUTED)
		text(item, str(entry.date).replace("T", " "), 13, MUTED)
		var record_data := entry.duplicate(true)
		item.add_child(g.button("查看对局详情", func() -> void: show_match_detail(record_data)))
		var uid := str(entry.uid)
		item.add_child(g.button("删除此记录", func() -> void:
			confirm("删除这局记录？", "仅移除该对局记录，累计积分不变。", func() -> void: g.profiles.delete_history(uid); show_history())))
	if g.profiles.data.history.is_empty(): text(box, "还没有对局记录，开始你的第一场对弈吧。", 18, MUTED)
	box.add_child(g.button("全部清空记录", func() -> void:
		confirm("清空全部记录？", "本机所有对局记录将删除，累计积分与用户保留。", func() -> void: g.profiles.clear_history(); show_history())))
	show_page("history", "对局记录", "MATCH ARCHIVE")

func confirm(title: String, description: String, accept: Callable, reject: Callable = Callable()) -> void:
	var box := page("confirm", true)
	text(box, description, 16)
	var actions: HBoxContainer = g.row()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_child(g.button("同意 / 确认", func() -> void:
		modal_reject = Callable()
		close()
		accept.call(), true))
	actions.add_child(g.button("拒绝 / 取消", close))
	box.add_child(actions)
	show_page("confirm", title, "CONFIRMATION")
	modal_reject = reject

func toggle_view() -> void:
	g._reset_tap()
	g.view.pitch = 0.48 if g.view.pitch > 1.0 else 1.35
	g.view.yaw = 0.65 if g.view.pitch < 1.0 else 0.0
	g.view.update_camera()

func reset_camera() -> void:
	g._reset_tap()
	g.view.pitch = 0.48
	g.view.yaw = 0.65
	g.view.distance = 11.8
	g.view.update_camera()

func adapt() -> void:
	if not is_instance_valid(main_box): return
	var portrait := g.size.y > g.size.x
	main_box.vertical = portrait
	header_box.vertical = portrait
	info_card.visible = not portrait and not mobile
	compact_status.visible = portrait or mobile or g.ruleset == 1
	var compact := current_page in ["confirm", "result"]
	modal.custom_minimum_size = Vector2(minf(g.size.x - 32, (460 if g.ruleset == 1 and current_page == "result" else 500) if compact else 710), minf(g.size.y - 32, (230 if current_page == "confirm" else (310 if g.ruleset == 1 else 410)) if compact else 640))
	if g.preview_label.get_parent() != (preview_wrap if portrait else footer):
		g.preview_label.reparent(preview_wrap if portrait else footer)
		if not portrait: footer.move_child(g.preview_label, 0)
	preview_wrap.visible = portrait
	brand_kicker.visible = not mobile or portrait
	if mobile:
		g.view.camera.fov = 42 if portrait else 36
		for btn in [drop_button, undo_button, hint_button]:
			btn.custom_minimum_size.y = 60
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_FILL
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		var scale := g.size / Vector2(get_window_size())
		for edge in ["left", "right", "top", "bottom"]: shell_margin.add_theme_constant_override("margin_" + edge, 18)
		shell_margin.add_theme_constant_override("margin_left", 18 + int(maxi(0, safe.position.x) * scale.x))
		shell_margin.add_theme_constant_override("margin_top", 18 + int(maxi(0, safe.position.y) * scale.y))
		shell_margin.add_theme_constant_override("margin_right", 18 + int(maxi(0, screen.x - safe.end.x) * scale.x))
		shell_margin.add_theme_constant_override("margin_bottom", 18 + int(maxi(0, screen.y - safe.end.y) * scale.y))

func refresh() -> void:
	if is_instance_valid(rule_choice):
		rule_choice.disabled = g.mode == "client" or (g.mode == "host" and g.guest_id != 0 and g.board.winner == 0)
		starter_choice.disabled = rule_choice.disabled or rule_choice.selected == 1
		series_choice.disabled = rule_choice.disabled
		series_box.visible = rule_choice.selected == 1
		step_choice.disabled = rule_choice.disabled
		game_choice.disabled = rule_choice.disabled
	if is_instance_valid(avatar_preview):
		avatar_preview.avatar_id = g.profiles.avatar_for(g.username_input.text)
		avatar_preview.frame_id = g.profiles.frame_for(g.username_input.text)
	for i in player_icons.size():
		var look: Dictionary = g.player_appearance(i+1)
		player_icons[i].avatar_id = look.avatar
		player_icons[i].frame_id = look.frame
		player_icons[i].is_ai = look.ai
		player_names[i].text = g.names[i]
		player_names[i].tooltip_text = g.names[i]
		var clock: String = "局 " + (g.clock_text(maxf(0,g.game_limit-g.thinking[i])) if g.game_limit > 0 else "不限")
		if g.board.turn == i+1 and g.board.winner == 0: clock += " · 步 " + (g.clock_text(g.turn_left) if g.step_limit > 0 else "不限")
		player_clocks[i].text = clock
		player_names[i].add_theme_color_override("font_color",Color("ef8191") if i == 0 else Color("82baff"))
	for i in room_avatar_icons.size(): room_avatar_icons[i].avatar_id = g.room_avatars[i]
	room_button.visible = g.mode in ["host", "client"]
	room_button.text = "解散房间" if g.mode == "host" else "退出房间"
	room_summary.visible = room_button.visible
	room_bar.visible = room_button.visible
	if room_button.visible:
		if g.mode == "host": g.room_stats[0] = g.online_stats()
		var entries: Array[String] = []
		for side in [0, 1]:
			var stats: Dictionary = g.room_stats[side]
			entries.append("%s · %s · %d 局 · 胜率 %.0f%%" % ["红" if side == 0 else "蓝", g.names[side], stats.games, 100.0 * stats.wins / maxi(1, int(stats.games))])
		room_summary.text = "\n".join(entries)
	if is_instance_valid(rematch_button) and current_page == "result":
		var own: int = g._own_side()
		var ready: bool = own > 0 and g.mode in ["host", "client"] and g.rematch_ready[own - 1]
		rematch_button.text = "已准备" if ready else ("下一局" if g.series_active() else ("再开系列" if g.ruleset == 1 else "再来一局"))
		rematch_button.disabled = ready or (g.mode == "host" and g.guest_id == 0) or (g.mode == "client" and not g.authenticated)
		if is_instance_valid(rematch_status) and g.mode in ["host", "client"]:
			rematch_status.text = "下一局：%s · 双方准备后开始" % (g.RULES[g.next_ruleset] + " · " + ("固定轮换先手" if g.next_ruleset == 1 else g.STARTERS[g.next_starter_policy]) + " · " + g.time_rules_title())
		if is_instance_valid(rematch_status) and ready: rematch_status.text = "等待对方准备 · " + (g.RULES[g.next_ruleset] + " · " + ("固定轮换先手" if g.next_ruleset == 1 else g.STARTERS[g.next_starter_policy]) + " · " + g.time_rules_title())
	if current_page == "result" and g.ruleset == 1 and is_instance_valid(rematch_status):
		rematch_status.text = ("等待对方准备" if g.rematch_ready[maxi(0,g._own_side()-1)] else "双方准备后开始") if g.mode in ["host","client"] else ""
	if performance_status != null and overlay.visible and current_page == "settings":
		performance_status.text = "当前 %.0f FPS · %s" % [Engine.get_frames_per_second(), "后台上限 30 FPS" if not g.app_focused and background_check.button_pressed else ("不限帧" if g.fps_limit == 0 else "上限 %d FPS" % g.fps_limit)]
	account_button.text = "账户"
	drop_button.disabled = not g.can_play() or g.selected.x < 0 or g.board.landing_y(g.selected.x, g.selected.y) < 0
	drop_button.text = "落子 " + g.column_name(g.selected) if g.selected.x >= 0 else "确认落子"
	undo_button.disabled = not g.can_request_undo()
	hint_button.visible = g.mode in ["local", "ai"]
	hint_button.disabled = not g.can_request_hint()
	for entry in mobile_choices:
		if is_instance_valid(entry.choice) and is_instance_valid(entry.button):
			entry.button.text = entry.choice.get_item_text(entry.choice.selected) + "  ▾" if entry.choice.selected >= 0 else "请选择  ▾"
			entry.button.disabled = entry.choice.disabled
	live_time.text = "%02d:%02d" % [int(g.elapsed) / 60, int(g.elapsed) % 60]
	compact_status.text = "%s · %s" % [g.turn_label.text, live_time.text]
	if g.ruleset == 1: compact_status.text += " · %s %d : %d %s" % [g.names[0],g.series_scores[0],g.series_scores[1],g.names[1]]

func get_window_size() -> Vector2i:
	return g.get_window().size

func show_licenses() -> void:
	var box := page("licenses", true)
	text(box, "Godot Engine · Noto Sans SC · Gravity Four", 18, JADE)
	var document := TextEdit.new()
	document.editable = false
	document.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	document.custom_minimum_size.y = 340
	document.add_theme_font_size_override("font_size", 13)
	for file in ["PROJECT-LICENSE", "GODOT-LICENSE", "NOTO-LICENSE", "GODOT-COPYRIGHT"]:
		document.text += FileAccess.get_file_as_string("res://assets/" + file + ".txt") + "\n\n"
	box.add_child(document)
	show_page("licenses", "开源许可", "OPEN SOURCE")

func show_match_detail(record_data: Dictionary) -> void:
	var box := page("detail", true)
	text(box, "%s vs %s · %d 步" % [record_data.names[0], record_data.names[1], int(record_data.plies)], 18, JADE)
	var replay = g.ReplayView.new()
	replay.record_data = record_data.duplicate(true)
	box.add_child(replay)
	box.add_child(g.button("退出回看 · 返回记录", show_history, true))
	show_page("detail", "棋盘回看", "REPLAY / READ ONLY")

func show_about() -> void:
	var box := page("about", true)
	text(box, "三维重力四子棋 v" + g.UpdateChecker.VERSION, 22, JADE)
	text(box, "作者：" + str(g.updater.info.get("author", "待填写")), 17)
	text(box, str(g.updater.info.get("support_text", "打赏信息待填写")), 16, MUTED)
	var support_url := str(g.updater.info.get("support_url", ""))
	if support_url.begins_with("https://"):
		box.add_child(g.button("支持作者 / 打赏", func() -> void: OS.shell_open(support_url)))
	var repo_input := _field(box, "公开 GitHub 仓库 · 用户名/仓库名", github_repo)
	box.add_child(g.button("保存仓库地址", func() -> void:
		var repo: String = g.UpdateChecker.repository(repo_input.text)
		if repo.is_empty(): update_status.text = "请输入有效 GitHub 仓库。"; return
		github_repo = repo
		g._save_settings()
		update_status.text = "已保存仓库。"))
	update_status = text(box, g.updater.status, 15, MUTED)
	update_button = g.button("检查更新", func() -> void:
		var repo: String = g.UpdateChecker.repository(repo_input.text)
		if not repo.is_empty(): github_repo = repo; g._save_settings()
		g.updater.check(repo))
	box.add_child(update_button)
	release_button = g.button("打开新版发布页面", func() -> void: OS.shell_open(g.updater.release_url), true)
	box.add_child(release_button)
	text(box, "更新检查读取 GitHub 正式 Release；下载与安装由你操作，保留原有用户数据需使用相同 APK 签名。作者和默认仓库由 assets/app_info.json 配置。", 14, MUTED)
	show_page("about", "关于与更新", "VERSION / AUTHOR")
	_refresh_update()

func _refresh_update() -> void:
	if is_instance_valid(update_status): update_status.text = g.updater.status
	if is_instance_valid(update_button): update_button.disabled = g.updater.busy
	if is_instance_valid(release_button): release_button.visible = not g.updater.release_url.is_empty()

func _prepare_mobile_choices() -> void:
	if not mobile: return
	for choice in page_host.find_children("*", "OptionButton", true, false):
		if choice.has_meta("mobile_proxy"): continue
		choice.set_meta("mobile_proxy", true)
		choice.hide()
		var select_button: Button = g.button("请选择  ▾", func() -> void: _show_mobile_choice(choice))
		select_button.custom_minimum_size.y = 52
		select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var parent: Node = choice.get_parent()
		parent.add_child(select_button)
		parent.move_child(select_button, choice.get_index())
		mobile_choices.append({"choice": choice, "button": select_button})
	refresh()

func _show_mobile_choice(choice: OptionButton) -> void:
	var previous := current_page
	var title := modal_title.text
	var kicker := modal_kicker.text
	var box := page("choice", true)
	for i in choice.item_count:
		var index: int = i
		var option: Button = g.button(("✓  " if i == choice.selected else "") + choice.get_item_text(i), func() -> void:
			choice.select(index)
			show_page(previous, title, kicker)
			choice.item_selected.emit(index)
			refresh(), i == choice.selected)
		option.custom_minimum_size.y = 56
		option.disabled = choice.is_item_disabled(i)
		box.add_child(option)
	box.add_child(g.button("返回", func() -> void: show_page(previous, title, kicker)))
	show_page("choice", "选择一项", "SELECT")


func _prepare_scroll() -> void:
	# Cards and buttons must bubble the touch-emulated pointer to ScrollContainer.
	for node in page_host.find_children("*", "Control", true, false):
		if node is PanelContainer or node is BoxContainer or node is BaseButton:
			node.mouse_filter = Control.MOUSE_FILTER_PASS
	page_host.mouse_filter = Control.MOUSE_FILTER_PASS

func _delete_selected_user() -> void:
	var username: String = g.username_input.text
	if username in g.names and ((g.board.moves > 0 and g.board.winner == 0) or g.mode in ["host", "client"]):
		register_message.text = "该用户正在对局中，请先结束对局或退出联机。"
		return
	if g.profiles.users().size() <= 1:
		register_message.text = "至少保留一名用户，请先注册其他用户。"
		return
	confirm("删除用户？", "删除 %s 及其全部排行榜成绩，历史对局保留。" % username, func() -> void:
		if g.profiles.delete_user(username):
			var fallback: String = g.profiles.users()[0]
			if g.username_input.text == username: g.username_input.text = fallback
			if g.opponent_input.text == username: g.opponent_input.text = fallback
			g._save_settings()
			if g.board.moves == 0 and g.mode in ["local", "ai"]: g.new_round()
			refresh_accounts()
			register_message.text = "已删除用户 " + username
		show_accounts())

func show_achievements() -> void:
	var box := page("achievements",true)
	var username: String = g.username_input.text
	var earned: Dictionary = g.profiles.data.achievements.get(username.to_lower(),{})
	var visible_unlocked := 0
	for item in g.Profiles.Achievements.ITEMS:
		if earned.has(item[0]): visible_unlocked += 1
	text(box,"%s · 已解锁 %d / %d" % [username,visible_unlocked,g.Profiles.Achievements.ITEMS.size()],22,JADE)
	text(box,"成就按账户保存，正式对局解锁；悔棋 / 提示练习局不解锁。清空排行榜不撤回已有成就。",14,MUTED)
	var challenges: Array = g.Profiles.Achievements.ITEMS.duplicate()
	challenges.sort_custom(func(a: Array,b: Array) -> bool: return str(a[0]).begins_with("master_") and not str(b[0]).begins_with("master_"))
	for item in challenges:
		var id: String = item[0]
		var unlocked: bool = earned.has(id)
		var panel := card(box,Color("173a39") if unlocked else Color("14263a"))
		text(panel,("✓ " if unlocked else "○ ") + item[1],20,JADE if unlocked else MUTED)
		text(panel,item[2],15,MUTED)
		var frame_index: int = g.Profiles.FRAME_REQUIREMENTS.find(id)
		if frame_index > 0: text(panel,"头像框奖励 · " + g.Profiles.FRAME_TITLES[frame_index],14,JADE)
		var avatar_index: int = g.Profiles.AVATAR_REQUIREMENTS.find(id)
		if avatar_index >= 8: text(panel,"限定头像 · " + Avatar.TITLES[avatar_index],14,JADE)
		if unlocked: text(panel,"解锁于 " + str(earned[id]).replace("T"," "),13,MUTED)
	show_page("achievements","我的成就","ACHIEVEMENTS")

func show_round_options() -> void:
	var box := page("round_options",true)
	text(box,"选择下一局玩法和先手；更改后双方需重新准备。",15,MUTED)
	for i in g.RULES.size():
		var index: int = i
		var btn: Button = g.button(("✓ " if g.next_ruleset == i else "") + g.RULES[i],func() -> void: g.choose_next_rules(index); g._mark_settings(); show_round_options(),g.next_ruleset == i)
		box.add_child(btn)
	box.add_child(g.button("步时：" + step_choice.get_item_text(step_choice.selected),func() -> void: _show_mobile_choice(step_choice)))
	if g.next_ruleset == 1: box.add_child(g.button("赛制：" + series_choice.get_item_text(series_choice.selected),func() -> void: _show_mobile_choice(series_choice)))
	box.add_child(g.button("局时：" + game_choice.get_item_text(game_choice.selected),func() -> void: _show_mobile_choice(game_choice)))
	text(box,"红方 = 主机 · 蓝方 = 客机",14,MUTED)
	for i in 3:
		var index: int = i
		var btn: Button = g.button(("✓ " if g.next_starter_policy == i else "") + g.STARTERS[i],func() -> void: g.choose_next_starter(index); g._mark_settings(); show_round_options(),g.next_starter_policy == i)
		btn.disabled = g.next_ruleset == 1
		box.add_child(btn)
	box.add_child(g.button("返回结算",show_result))
	show_page("round_options","下一局设置","NEXT ROUND")

func show_avatars() -> void:
	var username: String = g.username_input.text
	var box := page("avatars",true)
	text(box,username + " · 选择头像，立即保存并同步当前房间",16,JADE)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	box.add_child(grid)
	for i in Avatar.TITLES.size():
		var index: int = i
		var available: bool = g.profiles.avatar_unlocked(username,i)
		var btn: Button = g.button("",func() -> void: g.change_avatar(username,index); show_accounts(),i == g.profiles.avatar_for(username))
		btn.disabled = not available
		btn.custom_minimum_size = Vector2(140,116)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := Avatar.new()
		icon.avatar_id = i
		btn.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		icon.offset_left = -26
		icon.offset_right = 26
		icon.offset_top = 8
		icon.offset_bottom = 60
		var caption: Label = g.label(Avatar.TITLES[i] + (" · 锁定" if not available else ""),16)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_child(caption)
		caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		caption.offset_top = 72
		caption.offset_bottom = 96
		grid.add_child(btn)
	show_page("avatars","更改头像","AVATAR")

func show_frames() -> void:
	var username: String = g.username_input.text
	var box := page("frames",true)
	text(box,"完成成就永久解锁，点击已解锁的头像框装备。",15,MUTED)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	box.add_child(grid)
	for i in g.Profiles.HUMAN_FRAMES:
		var index: int = i
		var available: bool = g.profiles.frame_unlocked(username,i)
		var requirement := ""
		for achievement in g.Profiles.Achievements.ITEMS:
			if achievement[0] == g.Profiles.FRAME_REQUIREMENTS[i]: requirement = achievement[1]
		var item := card(grid,Color("173a39") if g.profiles.frame_for(username) == i else Color("14263a"))
		item.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var icon := Avatar.new()
		icon.avatar_id = g.profiles.avatar_for(username)
		icon.frame_id = i
		icon.custom_minimum_size = Vector2(84,84)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		item.add_child(icon)
		var title: Label = text(item,g.Profiles.FRAME_TITLES[i],17,JADE if available else MUTED)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var description: Label = text(item,"已解锁" if available else "完成“%s”解锁" % requirement,13,MUTED)
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var btn: Button = g.button("已装备" if g.profiles.frame_for(username) == i else ("装备" if available else "未解锁"),func() -> void: g.change_frame(username,index); show_accounts(),g.profiles.frame_for(username) == i)
		btn.disabled = not available
		item.add_child(btn)
	box.add_child(g.button("返回账户",show_accounts))
	show_page("frames","成就头像框","FRAMES")
