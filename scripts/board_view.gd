extends Node3D

const N := 5
const HALF := 2.0
const GRID := 0.9
const Board = preload("res://scripts/board.gd")
const AMBER := Color("ef5b5d")
const JADE := Color("56a7ff")
var camera: Camera3D
var pieces: Dictionary = {}
var targets: Array[MeshInstance3D] = []
var ghost: MeshInstance3D
var yaw := 0.65
var pitch := 0.48
var distance := 11.8
var selected := Vector2i(-1, -1)
var win_root: Node3D
var sphere_mesh: TorusMesh
var connection_root: Node3D
var guides_enabled := false
var mats: Array[StandardMaterial3D] = []
var target_materials: Array[StandardMaterial3D] = []
var ghost_materials: Array[StandardMaterial3D] = []
var guide_materials: Array[StandardMaterial3D] = []
var low_power := false
var static_batches: Array[MultiMeshInstance3D] = []
var guide_mesh: CylinderMesh
var active_tweens: Array[Tween] = []

func request_redraw() -> void:
	var viewport := get_viewport()
	if viewport is SubViewport:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if not active_tweens.is_empty() else SubViewport.UPDATE_ONCE

func _process(_delta: float) -> void:
	for tween in active_tweens.duplicate():
		if not tween.is_valid() or not tween.is_running(): active_tweens.erase(tween)
	if active_tweens.is_empty():
		set_process(false)
		request_redraw()

func set_low_power(enabled: bool) -> void:
	if low_power == enabled: return
	low_power = enabled
	sphere_mesh.rings = 16 if enabled else 32
	sphere_mesh.ring_segments = 12 if enabled else 20
	request_redraw()

func batch(mesh: Mesh, mat: Material, transforms: Array[Transform3D], parent: Node3D) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size(): multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _ready() -> void:
	set_process(false)
	get_viewport().size_changed.connect(request_redraw)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c1625")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9d4e8")
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.3
	add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3, 5, 4)
	fill.light_color = JADE
	fill.light_energy = 1.3
	fill.omni_range = 12
	add_child(fill)
	camera = Camera3D.new()
	camera.fov = 42
	add_child(camera)
	update_camera()
	mats = [material(AMBER), material(JADE)]
	sphere_mesh = TorusMesh.new()
	sphere_mesh.inner_radius = 0.05
	sphere_mesh.outer_radius = 0.43
	sphere_mesh.rings = 32
	sphere_mesh.ring_segments = 20
	var base := BoxMesh.new()
	base.size = Vector3(5.0, 0.18, 5.0)
	mesh_instance(base, material(Color("1d344b")), Vector3(0, -0.18, 0))
	var edge_mat := material(Color("4e7185"))
	target_materials.assign([edge_mat, mats[1]])
	for color in [AMBER, JADE]:
		var transparent_color: Color = color
		transparent_color.a = 0.35
		ghost_materials.append(material(transparent_color, true))
		var line_material := material(color)
		line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		guide_materials.append(line_material)
	guide_mesh = CylinderMesh.new()
	guide_mesh.top_radius = 0.025
	guide_mesh.bottom_radius = 0.025
	guide_mesh.height = 1.0
	guide_mesh.radial_segments = 8
	var rod_mat := material(Color(0.45, 0.72, 0.78, 0.22), true)
	var rod := CylinderMesh.new()
	rod.top_radius = 0.022
	rod.bottom_radius = 0.022
	rod.height = 4.6
	rod.radial_segments = 8
	var ring := TorusMesh.new()
	ring.inner_radius = 0.32
	ring.outer_radius = 0.39
	ring.rings = 24
	ring.ring_segments = 12
	var rods: Array[Transform3D] = []
	for z in N:
		for x in N:
			rods.append(Transform3D(Basis.IDENTITY, Vector3((x - HALF) * GRID, 2.2, (HALF - z) * GRID)))
			var target := mesh_instance(ring, edge_mat, Vector3((x - HALF) * GRID, -0.05, (HALF - z) * GRID))
			targets.append(target)
	static_batches.append(batch(rod, rod_mat, rods, self))
	for x in N:
		label_3d(str(x + 1), Vector3((x - HALF) * GRID, 0.02, 2.4))
	for z in N:
		label_3d(String.chr(65 + z), Vector3(-2.4, 0.02, (HALF - z) * GRID))
	ghost = mesh_instance(sphere_mesh, material(Color(1, 0.72, 0.35, 0.35), true), Vector3.ZERO)
	ghost.scale.y = 2.1
	ghost.visible = false
	connection_root = Node3D.new()
	add_child(connection_root)
	win_root = Node3D.new()
	add_child(win_root)
	request_redraw()

func label_3d(value: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = value
	label.position = pos
	label.font_size = 56
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("91b1c5")
	add_child(label)

func material(color: Color, transparent: bool = false, metallic: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = 0.62
	if transparent:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result

func mesh_instance(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	add_child(instance)
	return instance

func cell_position(p: Vector3i) -> Vector3:
	return Vector3((p.x - HALF) * GRID, (p.y + 0.5) * GRID, (HALF - p.z) * GRID)

func update_camera() -> void:
	var center := Vector3(0, 1.9, 0)
	camera.position = center + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(center)
	request_redraw()

func orbit(delta: Vector2) -> void:
	yaw -= delta.x * 0.008
	pitch = clampf(pitch + delta.y * 0.008, 0.16, 1.4)
	update_camera()

func zoom(amount: float) -> void:
	distance = clampf(distance + amount, 9.0, 19.0)
	update_camera()

func pick_column(mouse: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var point: Variant = Plane(Vector3.UP, 0).intersects_ray(origin, direction)
	if point == null:
		return Vector2i(-1, -1)
	var x := int(floor(point.x / GRID + 2.5))
	var z := int(floor(2.5 - point.z / GRID))
	if x not in range(N) or z not in range(N):
		return Vector2i(-1, -1)
	return Vector2i(x, z)

func preview(column: Vector2i, board: RefCounted, active: bool) -> void:
	selected = column
	for i in targets.size():
		var is_selected := column.x == i % N and column.y == i / N
		targets[i].material_override = target_materials[1 if is_selected else 0]
	ghost.visible = false
	request_redraw()
	if column.x < 0 or not active:
		return
	var y: int = board.landing_y(column.x, column.y)
	if y >= 0:
		ghost.position = cell_position(Vector3i(column.x, y, column.y))
		ghost.material_override = ghost_materials[board.turn - 1]
		ghost.visible = true

func sync(board: RefCounted, animate: bool = true) -> void:
	if not animate:
		for tween in active_tweens: tween.kill()
		active_tweens.clear()
		set_process(false)
	for key in pieces.keys():
		if board.cells[key] == 0:
			pieces[key].queue_free()
			pieces.erase(key)
	for y in N:
		for z in N:
			for x in N:
				var key: int = board.index(x, y, z)
				var player: int = board.cells[key]
				if player == 0: continue
				var pos := cell_position(Vector3i(x, y, z))
				if pieces.has(key):
					if not animate: pieces[key].position = pos
					continue
				var instance := mesh_instance(sphere_mesh, mats[player - 1], pos)
				instance.scale.y = 2.1
				pieces[key] = instance
				if animate:
					set_process(true)
					instance.position.y = 6.1
					var tween := create_tween()
					active_tweens.append(tween)
					tween.tween_property(instance, "position:y", pos.y, 0.42).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_build_connections(board)
	for child in win_root.get_children():
		child.queue_free()
	if board.winning_cells.size() >= 4:
		var endpoints: Array = board.winning_cells.duplicate()
		endpoints.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return board.index(a.x, a.y, a.z) < board.index(b.x, b.y, b.z))
		var start := cell_position(endpoints.front())
		var finish := cell_position(endpoints.back())
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.065
		cylinder.bottom_radius = 0.065
		cylinder.height = start.distance_to(finish)
		var beam := MeshInstance3D.new()
		beam.mesh = cylinder
		var mat := material(Color("ffffff"))
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam.material_override = mat
		win_root.add_child(beam)
		beam.position = (start + finish) / 2.0
		beam.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
	request_redraw()

func set_guides(enabled: bool, board: RefCounted) -> void:
	guides_enabled = enabled
	if is_instance_valid(connection_root): _build_connections(board)
	request_redraw()

func _build_connections(board: RefCounted) -> void:
	for child in connection_root.get_children():
		connection_root.remove_child(child)
		child.queue_free()
	if not guides_enabled: return
	var red: Array[Transform3D] = []
	var blue: Array[Transform3D] = []
	for y in N:
		for z in N:
			for x in N:
				var a := Vector3i(x,y,z)
				var side: int = board.cells[board.index(x,y,z)]
				if side == 0: continue
				for dx in range(-1,2):
					for dy in range(-1,2):
						for dz in range(-1,2):
							if dx < 0 or (dx == 0 and dy < 0) or (dx == 0 and dy == 0 and dz <= 0): continue
							var b := a + Vector3i(dx,dy,dz)
							if b.x < 0 or b.y < 0 or b.z < 0 or b.x >= N or b.y >= N or b.z >= N: continue
							if board.cells[board.index(b.x,b.y,b.z)] != side: continue
							var start := cell_position(a)
							var end := cell_position(b)
							var orientation := Basis(Quaternion(Vector3.UP, (end-start).normalized()))
							orientation = orientation.scaled_local(Vector3(1, start.distance_to(end), 1))
							var transform := Transform3D(orientation, (start+end)/2)
							if side == 1: red.append(transform)
							else: blue.append(transform)
	if not red.is_empty(): batch(guide_mesh, guide_materials[0], red, connection_root)
	if not blue.is_empty(): batch(guide_mesh, guide_materials[1], blue, connection_root)
