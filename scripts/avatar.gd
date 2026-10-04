extends Control
const TITLES := ["星猫", "蓝狐", "竹熊", "赤兔", "月鹿", "金狮", "云鲸", "紫鸮", "曜影龙", "天穹执政官", "星焰凰", "不败棋圣", "逆冕骑士"]
const COLORS := ["56bfc2","609bea","7fbb86","ed8490","ab9de6","e3b35e","76b8d3","b78ec4", "8a78ef", "68c9ee", "f59960", "e7d183", "ea83c3"]
var frame_id := 0:
	set(value):
		if frame_id == value: return
		frame_id = clampi(value,0,17)
		queue_redraw()
var is_ai := false:
	set(value):
		if is_ai == value: return
		is_ai = value
		queue_redraw()
var avatar_id := 0:
	set(value):
		if avatar_id == value: return
		avatar_id = clampi(value,0,12)
		queue_redraw()
func _init() -> void:
	custom_minimum_size = Vector2(52,52)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var s := minf(size.x,size.y)
	var c := size / 2

	var color := Color(COLORS[avatar_id])
	if is_ai:
		color = Color(["a98f70","b9cfdb","bc9bec","f0d17e"][clampi(frame_id-8,0,3)])
		draw_circle(c,s*0.43,Color("17263d"))
		draw_style_box(robot_style(color),Rect2(c-Vector2(s*0.29,s*0.22),Vector2(s*0.58,s*0.48)))
		draw_line(c-Vector2(0,s*0.22),c-Vector2(0,s*0.36),color,s*0.045,true)
		draw_circle(c-Vector2(0,s*0.36),s*0.05,color)
		for sign in [-1,1]: draw_circle(c+Vector2(sign*s*0.12,-s*0.03),s*0.045,Color("122437"))
		draw_line(c+Vector2(-s*0.12,s*0.13),c+Vector2(s*0.12,s*0.13),Color("122437"),s*0.04,true)
		_draw_frame(c,s)
		return
	draw_circle(c,s*0.47,Color("192b43"))

	if avatar_id >= 8:
		draw_circle(c,s*0.40,Color("142239"))
		var helmet := PackedVector2Array([c+Vector2(-s*0.32,-s*0.17),c+Vector2(-s*0.19,-s*0.36),c+Vector2(0,-s*0.22),c+Vector2(s*0.19,-s*0.36),c+Vector2(s*0.32,-s*0.17),c+Vector2(s*0.25,s*0.22),c+Vector2(0,s*0.35),c+Vector2(-s*0.25,s*0.22)])
		draw_colored_polygon(helmet,color)
		for sign in [-1,1]:
			draw_colored_polygon(PackedVector2Array([c+Vector2(sign*s*0.20,-s*0.15),c+Vector2(sign*s*0.40,-s*0.41),c+Vector2(sign*s*0.12,-s*0.27)]),color)
			draw_line(c+Vector2(sign*s*0.07,-s*0.02),c+Vector2(sign*s*0.21,-s*0.07),Color("e7ffff"),s*0.045,true)
			draw_line(c+Vector2(sign*s*0.04,s*0.22),c+Vector2(sign*s*0.25,s*0.06),Color("223050"),s*0.035,true)
		if avatar_id in [9,11]: draw_arc(c,s*0.30,PI,TAU,24,Color("e8ebcf"),s*0.04,true)
		if avatar_id == 10:
			for sign in [-1,1]: draw_colored_polygon(PackedVector2Array([c+Vector2(sign*s*0.23,0),c+Vector2(sign*s*0.48,-s*0.21),c+Vector2(sign*s*0.36,s*0.19)]),Color("f2c785"))
		if avatar_id == 12: draw_colored_polygon(PackedVector2Array([c+Vector2(-s*0.16,-s*0.24),c+Vector2(0,-s*0.48),c+Vector2(s*0.16,-s*0.24)]),Color("f5bddb"))
		_draw_frame(c,s)
		return
	if avatar_id == 3:
		for sign in [-1,1]:
			draw_line(c+Vector2(sign*s*0.14,-s*0.08),c+Vector2(sign*s*0.18,-s*0.40),color,s*0.14,true)
			draw_line(c+Vector2(sign*s*0.14,-s*0.16),c+Vector2(sign*s*0.18,-s*0.36),Color("ffe0df"),s*0.055,true)
	elif avatar_id == 4:
		for sign in [-1,1]:
			draw_line(c+Vector2(sign*s*0.19,-s*0.13),c+Vector2(sign*s*0.25,-s*0.40),color,s*0.05,true)
			draw_line(c+Vector2(sign*s*0.23,-s*0.30),c+Vector2(sign*s*0.39,-s*0.36),color,s*0.04,true)
	elif avatar_id == 6:
		for sign in [-1,1]: draw_colored_polygon(PackedVector2Array([c+Vector2(sign*s*0.20,0),c+Vector2(sign*s*0.45,s*0.16),c+Vector2(sign*s*0.18,s*0.25)]),color)
		draw_line(c+Vector2(0,-s*0.25),c+Vector2(0,-s*0.42),color,s*0.04,true)
	elif avatar_id % 2 == 0:
		for sign in [-1,1]: draw_circle(c+Vector2(sign*s*0.24,-s*0.23),s*0.15,color)
	else:
		for sign in [-1,1]: draw_colored_polygon(PackedVector2Array([c+Vector2(sign*s*0.31,-s*0.04),c+Vector2(sign*s*0.29,-s*0.40),c+Vector2(sign*s*0.07,-s*0.18)]),color)
	draw_circle(c+Vector2(0,s*0.03),s*0.32,color)
	if avatar_id == 5: draw_arc(c,s*0.38,0,TAU,24,color,s*0.13,true)
	if avatar_id in [1,2,7]: draw_circle(c+Vector2(0,s*0.12),s*0.20,Color("e4e9e6"))
	if avatar_id in [2,7]:
		for sign in [-1,1]: draw_circle(c+Vector2(sign*s*0.13,-s*0.01),s*0.11,Color("142237") if avatar_id == 2 else Color("f7eacc"))
	for sign in [-1,1]:
		draw_circle(c+Vector2(sign*s*0.12,0),s*0.05,Color("142237"))
		draw_circle(c+Vector2(sign*s*0.12-s*0.012,-s*0.014),s*0.015,Color.WHITE)
	draw_circle(c+Vector2(0,s*0.11),s*0.035,Color("142237"))
	draw_arc(c+Vector2(0,s*0.09),s*0.10,0.3,PI-0.3,16,Color("142237"),maxf(1,s*0.025),true)

	_draw_frame(c,s)
func robot_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style
func _gem(c: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([c+Vector2(0,-radius),c+Vector2(radius*0.7,0),c+Vector2(0,radius),c+Vector2(-radius*0.7,0)])
	draw_colored_polygon(points,color)
	draw_line(points[0],points[1],Color("f1ffff"),maxf(1,radius*0.15),true)
	draw_line(points[0],points[3],Color("f1ffff"),maxf(1,radius*0.15),true)

func _draw_frame(c: Vector2,s: float) -> void:
	if frame_id == 0: return
	var colors := ["233c52","bd9166","60cbb8","b9cfdb","bd93ec","f4d178","84bdf1","f5c66c","bd9166","b9cfdb","bd93ec","f4d178","a398ff","75e0ed","ffc482","f7e49b","efa1d2","7bdcec"]
	var color := Color(colors[frame_id])
	var elite := frame_id >= 12 or frame_id in [5,11]
	var radius := s*(0.37 if elite else 0.43)
	# Dark edge, metallic core and bright inner bevel keep detail legible at HUD size.
	draw_arc(c,radius,0,TAU,64,Color("07101e"),maxf(2,s*0.085),true)
	draw_arc(c,radius,0,TAU,64,color,maxf(1.5,s*0.045),true)
	draw_arc(c,radius-s*0.026,PI,TAU,32,Color("eef8ff"),maxf(1,s*0.013),true)
	if not elite:
		if frame_id in [4,6,7,10]:
			for sign in [-1,1]: _gem(c+Vector2(sign*radius,0),s*0.052,color)
		if frame_id == 7: _gem(c+Vector2(0,-radius),s*0.065,Color("fff1bd"))
		return
	# Blade (17), dragon (12), orbit (13), phoenix (14), sovereign (15) and apex (16).
	if frame_id == 13:
		var orbit := PackedVector2Array()
		for i in 65:
			var angle := TAU*i/64.0
			orbit.append(c+Vector2(cos(angle)*s*0.48,sin(angle)*s*0.22).rotated(-0.5))
		draw_polyline(orbit,Color("d3faff"),maxf(1,s*0.022),true)
		for angle in [0.0,PI]: _gem(c+Vector2(cos(angle)*s*0.43,sin(angle)*s*0.22).rotated(-0.5),s*0.045,color)
	else:
		var feathers := 4 if frame_id in [14,15,16] else 2
		for sign in [-1,1]:
			for i in feathers:
				var y := s*(-0.20+i*0.11)
				var wing := PackedVector2Array([c+Vector2(sign*s*0.30,y+s*0.09),c+Vector2(sign*s*0.49,y-s*0.09),c+Vector2(sign*s*0.45,y+s*0.10),c+Vector2(sign*s*0.33,y+s*0.16)])
				draw_colored_polygon(wing,Color(color.darkened(0.16*i)))
				draw_line(wing[0],wing[1],Color("fff4d6") if frame_id in [15,16] else Color("eefaff"),maxf(1,s*0.014),true)
	if frame_id in [5,11,15,16]:
		var crown := PackedVector2Array([c+Vector2(-s*0.24,-s*0.31),c+Vector2(-s*0.28,-s*0.46),c+Vector2(-s*0.12,-s*0.38),c+Vector2(0,-s*0.49),c+Vector2(s*0.12,-s*0.38),c+Vector2(s*0.28,-s*0.46),c+Vector2(s*0.24,-s*0.31)])
		draw_colored_polygon(crown,Color("f6d584"))
		_gem(c+Vector2(0,-s*0.38),s*0.06,color if frame_id == 16 else Color("79ddeb"))
	else:
		_gem(c+Vector2(0,-s*0.41),s*0.075,color)
	if frame_id == 16:
		for i in 8:
			var angle := TAU*i/8.0
			_gem(c+Vector2(cos(angle),sin(angle))*s*0.35,s*0.027,Color("fff3b7"))
		_gem(c+Vector2(0,s*0.43),s*0.065,Color("fbd1ed"))
	elif frame_id in [12,14,15,17]:
		_gem(c+Vector2(0,s*0.42),s*(0.065 if frame_id != 17 else 0.085),color)
