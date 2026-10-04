extends VBoxContainer

const Board = preload("res://scripts/board.gd")
const BoardView = preload("res://scripts/board_view.gd")
var record_data: Dictionary = {}
var columns: Array[Vector2i] = []
var view: Node3D
var board: RefCounted
var step := 0
var caption: Label
var box: SubViewportContainer
var dragging := false
var touch_count := 0

static func move_columns(record: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if record.get("columns") is Array:
		for value in record.columns:
			if value is Array and value.size() == 2:
				result.append(Vector2i(int(value[0]), int(value[1])))
		return result
	var pattern := RegEx.new()
	pattern.compile("：([A-E])([1-5])")
	for text in record.get("history", []):
		var match_data := pattern.search(str(text))
		if match_data == null: return []
		result.append(Vector2i(int(match_data.get_string(2)) - 1, match_data.get_string(1).unicode_at(0) - 65))
	return result

func _ready() -> void:
	columns = move_columns(record_data)
	box = SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(240, 270)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 360)
	viewport.own_world_3d = true
	box.add_child(viewport)
	view = BoardView.new()
	viewport.add_child(view)
	view.set_guides(false, Board.new())
	box.gui_input.connect(_input_board)
	caption = Label.new()
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(caption)
	var actions := HBoxContainer.new()
	add_child(actions)
	for item in [["初始", 0], ["上一步", -1], ["下一步", 1], ["最终", 999]]:
		var amount := int(item[1])
		var button := Button.new()
		button.text = str(item[0])
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: seek(0 if amount == 0 else (columns.size() if amount == 999 else step + amount)))
		actions.add_child(button)
	seek(columns.size())

func seek(value: int) -> void:
	step = clampi(value, 0, columns.size())
	board = Board.new()
	board.turn = int(record_data.get("first_side",1))
	for i in step:
		if not board.drop_piece(columns[i].x, columns[i].y):
			caption.text = "旧记录落子数据不完整，无法继续回放。"
			return
	if step == columns.size() and record_data.get("final_snapshot") is Dictionary:
		board.load_snapshot(record_data.final_snapshot)
	view.sync(board, false)
	caption.text = "第 %d / %d 手 · 拖动旋转，滚轮缩放 · 回看不影响当前对局" % [step, columns.size()]
	if columns.is_empty() and not record_data.has("final_snapshot"): caption.text = "此旧记录没有可还原的落子数据。"

func _input_board(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]: dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: view.zoom(-0.6)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: view.zoom(0.6)
	elif event is InputEventMouseMotion and dragging: view.orbit(event.relative)
	elif event is InputEventScreenTouch: touch_count = maxi(0, touch_count + (1 if event.pressed else -1))
	elif event is InputEventScreenDrag and touch_count > 0: view.orbit(event.relative)
