extends Node3D
## Builds the warehouse and swaps its decrepit/repaired parts as repairs are bought.

const S = preload("res://scripts/shapes.gd")
const W := 20.0   # half width (x)
const D := 14.0   # half depth (z)
const H := 8.0    # wall height
const SPLIT := 2.4
# Missing roof panels (grid of 8 x 7 panels, 5 m x 4 m each)
const HOLES := [Vector2i(0, 2), Vector2i(2, 0), Vector2i(3, 3), Vector2i(5, 1), Vector2i(6, 4), Vector2i(2, 5), Vector2i(7, 2), Vector2i(4, 6)]

var game
var mats := {}
var groups := {}
var lamps := []
var flicker_light: OmniLight3D
var shutter: Node3D
var shutter_body: StaticBody3D
var crane_bridge: Node3D
var vibrators := []
var _t := 0.0


func build(p_game) -> void:
	game = p_game
	mats["wall_lo"] = S.mat(Color(0.42, 0.26, 0.2), 0.95)
	mats["wall_hi"] = S.mat(Color(0.48, 0.31, 0.24), 0.95)
	mats["floor"] = S.mat(Color(0.34, 0.33, 0.31), 0.92)
	mats["steel"] = S.mat(Color(0.3, 0.31, 0.33), 0.5, 0.7)
	mats["dark"] = S.mat(Color(0.14, 0.14, 0.15), 0.7, 0.4)
	mats["wood"] = S.mat(Color(0.42, 0.3, 0.18))
	mats["dark_wood"] = S.mat(Color(0.26, 0.18, 0.11))
	mats["roof"] = S.mat(Color(0.3, 0.3, 0.29), 0.8, 0.3)
	mats["olive"] = S.mat(Color(0.3, 0.34, 0.22), 0.7, 0.2)
	mats["yellow"] = S.mat(Color(0.85, 0.66, 0.1), 0.6, 0.3)
	mats["khaki"] = S.mat(Color(0.55, 0.5, 0.36), 0.95)
	mats["bulb"] = S.mat(Color(0.25, 0.25, 0.22), 0.4)
	mats["bulb"].emission = Color(1.0, 0.85, 0.6)
	mats["bulb"].emission_energy_multiplier = 4.0
	_ground()
	_walls()
	_roof()
	_lamps()
	_windows()
	_rubble()
	_rain()
	_ledger_board()
	_decor()
	_signs()
	_floor_plates()
	_canteen()
	_crane()
	_dock()
	_lorry()
	_power()
	_shelter()
	_rail()


func g(gname: String) -> Node3D:
	if not groups.has(gname):
		var n := Node3D.new()
		n.name = gname
		add_child(n)
		groups[gname] = n
	return groups[gname]


func _set_group(gname: String, vis: bool) -> void:
	var n := g(gname)
	n.visible = vis
	for b in n.find_children("*", "StaticBody3D", true, false):
		b.collision_layer = 1 if vis else 0


# ------------------------------------------------------------------ structure

func _ground() -> void:
	S.box(self, Vector3(240, 0.2, 240), Vector3(0, -0.12, 0), S.mat(Color(0.3, 0.32, 0.22), 1.0))
	S.collider(self, Vector3(240, 0.2, 240), Vector3(0, -0.12, 0))
	S.box(self, Vector3(2 * W, 0.2, 2 * D), Vector3(0, -0.1, 0), mats["floor"])
	# Yard outside the dock
	S.box(self, Vector3(16, 0.04, 20), Vector3(28, -0.0, 0), S.mat(Color(0.38, 0.37, 0.34), 0.95))
	for p in [Vector3(60, 5, 0), Vector3(-60, 5, 0), Vector3(0, 5, 60), Vector3(0, 5, -60)]:
		var sz := Vector3(1, 10, 120) if absf(p.x) > 1 else Vector3(120, 10, 1)
		S.collider(self, sz, p)


func _wall_box(center: Vector3, sx: float, sz: float, y0: float, y1: float) -> void:
	if y0 < SPLIT:
		var top := minf(y1, SPLIT)
		S.box(self, Vector3(sx, top - y0, sz), Vector3(center.x, (y0 + top) / 2.0, center.z), mats["wall_lo"])
	if y1 > SPLIT:
		var bot := maxf(y0, SPLIT)
		S.box(self, Vector3(sx, y1 - bot, sz), Vector3(center.x, (bot + y1) / 2.0, center.z), mats["wall_hi"])
	S.collider(self, Vector3(sx, y1 - y0, sz), Vector3(center.x, (y0 + y1) / 2.0, center.z))


func _walls() -> void:
	var t := 0.4
	_wall_box(Vector3(0, 0, -D - t / 2), 2 * W + 2 * t, t, 0, H)
	_wall_box(Vector3(0, 0, D + t / 2), 2 * W + 2 * t, t, 0, H)
	_wall_box(Vector3(-W - t / 2, 0, 0), t, 2 * D, 0, H)
	# Right wall with the loading-dock opening (z -3..3, up to 5.5 m)
	_wall_box(Vector3(W + t / 2, 0, -8.5), t, 11, 0, H)
	_wall_box(Vector3(W + t / 2, 0, 8.5), t, 11, 0, H)
	_wall_box(Vector3(W + t / 2, 0, 0), t, 6, 5.5, H)
	# Front door (decorative)
	S.box(self, Vector3(2.0, 3.0, 0.1), Vector3(8, 1.5, D - 0.03), mats["dark_wood"])
	S.box(self, Vector3(2.3, 0.15, 0.14), Vector3(8, 3.05, D - 0.05), mats["dark"])


func _roof() -> void:
	var patch := g("roof_patch")
	var sky_mat := S.glass(Color(0.75, 0.8, 0.85, 0.35))
	for i in 8:
		for j in 7:
			var pos := Vector3(-W + 2.5 + i * 5.0, H + 0.06, -D + 2.0 + j * 4.0)
			if Vector2i(i, j) in HOLES:
				var sheet := S.box(patch, Vector3(4.9, 0.05, 3.9), pos, sky_mat)
				sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				S.box(self, Vector3(5.0, 0.12, 4.0), pos, mats["roof"])
	# Trusses and purlins
	for k in range(1, 8):
		S.box(self, Vector3(0.3, 0.5, 2 * D), Vector3(-W + k * 5.0, H - 0.3, 0), mats["steel"])
	for z in [-7.0, 0.0, 7.0]:
		S.box(self, Vector3(2 * W, 0.2, 0.2), Vector3(0, H - 0.15, z), mats["steel"])


func _lamps() -> void:
	for x in [-15.0, -5.0, 5.0, 15.0]:
		for z in [-9.0, 0.0, 9.0]:
			S.box(self, Vector3(0.03, 1.4, 0.03), Vector3(x, H - 0.75, z), mats["dark"])
			S.cyl(self, 0.06, 0.45, 0.3, Vector3(x, 6.55, z), mats["olive"])
			S.sphere(self, 0.1, Vector3(x, 6.38, z), mats["bulb"])
			var l := OmniLight3D.new()
			l.position = Vector3(x, 6.1, z)
			l.omni_range = 14.0
			l.light_color = Color(1.0, 0.86, 0.66)
			l.light_energy = 0.0
			add_child(l)
			lamps.append(l)
	# One lamp that still (just about) works, over the first bench
	var fm := S.emissive(Color(1.0, 0.8, 0.5), 3.0)
	S.box(self, Vector3(0.03, 2.6, 0.03), Vector3(-14, H - 1.4, -8.6), mats["dark"])
	S.cyl(self, 0.05, 0.35, 0.25, Vector3(-14, 5.2, -8.6), mats["olive"])
	S.sphere(self, 0.08, Vector3(-14, 5.06, -8.6), fm)
	flicker_light = OmniLight3D.new()
	flicker_light.position = Vector3(-14, 4.8, -8.6)
	flicker_light.omni_range = 9.0
	flicker_light.light_color = Color(1.0, 0.8, 0.55)
	flicker_light.light_energy = 1.6
	flicker_light.shadow_enabled = true
	add_child(flicker_light)


func _window(pos: Vector3, yaw: float) -> void:
	var broken := g("win_broken")
	var glazed := g("win_glass")
	var blackout := g("blackout")
	var frames := Node3D.new()
	frames.position = pos
	frames.rotation_degrees.y = yaw
	add_child(frames)
	S.box(frames, Vector3(3.2, 2.2, 0.06), Vector3(0, 0, 0.03), mats["dark_wood"])
	var b := Node3D.new()
	b.transform = frames.transform
	broken.add_child(b)
	S.box(b, Vector3(2.9, 1.9, 0.05), Vector3(0, 0, 0.06), S.mat(Color(0.05, 0.05, 0.05)))
	for k in 3:
		S.box(b, Vector3(3.1, 0.25, 0.04), Vector3(0, -0.6 + k * 0.6, 0.1), mats["wood"], Vector3(0, 0, -8 + k * 9))
	var gl := Node3D.new()
	gl.transform = frames.transform
	glazed.add_child(gl)
	S.box(gl, Vector3(2.9, 1.9, 0.04), Vector3(0, 0, 0.06), S.emissive(Color(0.72, 0.8, 0.88), 0.8))
	S.box(gl, Vector3(0.06, 1.9, 0.06), Vector3(0, 0, 0.09), mats["dark_wood"])
	S.box(gl, Vector3(2.9, 0.06, 0.06), Vector3(0, 0, 0.09), mats["dark_wood"])
	var bo := Node3D.new()
	bo.transform = frames.transform
	blackout.add_child(bo)
	var blind := S.mat(Color(0.1, 0.1, 0.12))
	S.cyl(bo, 0.12, 0.12, 3.3, Vector3(0, 1.22, 0.18), blind, Vector3(0, 0, 90))
	S.box(bo, Vector3(3.3, 0.3, 0.03), Vector3(0, 1.0, 0.26), blind)
	S.box(bo, Vector3(0.03, 0.5, 0.03), Vector3(1.4, 0.75, 0.24), mats["khaki"])


func _windows() -> void:
	for x in [-15.0, -9.0, -3.0, 3.0, 9.0, 15.0]:
		_window(Vector3(x, 4.8, -D), 0)
	for z in [-8.0, 0.0, 8.0]:
		_window(Vector3(-W, 4.8, z), 90)
	for x in [-15.0, 15.0]:
		_window(Vector3(x, 4.8, D), 180)


func _rubble() -> void:
	var r := g("rubble")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var brick := S.mat(Color(0.5, 0.28, 0.2))
	var concrete := S.mat(Color(0.45, 0.44, 0.42))
	var placed := 0
	while placed < 45:
		var x := rng.randf_range(-19, 19)
		var z := rng.randf_range(-13, 13)
		if x > -18.5 and x < -9.5 and z > -11.5 and z < -3.0:
			continue  # keep the first bench and the spawn point clear
		placed += 1
		match rng.randi() % 4:
			0:
				for k in 6:
					S.box(r, Vector3(0.24, 0.1, 0.12), Vector3(x + rng.randf_range(-0.4, 0.4), 0.05 + rng.randf() * 0.15, z + rng.randf_range(-0.4, 0.4)), brick, Vector3(rng.randf_range(-20, 20), rng.randf() * 180, rng.randf_range(-20, 20)))
			1:
				S.box(r, Vector3(1.8, 0.05, 0.2), Vector3(x, 0.08, z), mats["wood"], Vector3(rng.randf_range(-10, 10), rng.randf() * 180, rng.randf_range(-6, 6)))
			2:
				S.box(r, Vector3(0.6, 0.6, 0.6), Vector3(x, 0.25, z), mats["dark_wood"], Vector3(rng.randf_range(-25, 25), rng.randf() * 90, rng.randf_range(-25, 25)))
			3:
				S.box(r, Vector3(0.7, 0.35, 0.5), Vector3(x, 0.15, z), concrete, Vector3(rng.randf_range(-15, 15), rng.randf() * 90, 0))
	# Fallen roof sheets under some holes
	for h in [HOLES[1], HOLES[3], HOLES[6]]:
		var pos := Vector3(-W + 2.5 + h.x * 5.0, 0.4, -D + 2.0 + h.y * 4.0 + 1.0)
		S.box(r, Vector3(3.5, 0.06, 2.0), pos, mats["roof"], Vector3(12, 30, 8))


func _rain() -> void:
	var r := g("rain")
	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.25, 0.012)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.7, 0.78, 0.9, 0.5)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = dm
	var puddle := S.mat(Color(0.12, 0.14, 0.17), 0.05, 0.4)
	for h in HOLES:
		var x: float = -W + 2.5 + h.x * 5.0
		var z: float = -D + 2.0 + h.y * 4.0
		var p := CPUParticles3D.new()
		p.position = Vector3(x, H - 0.2, z)
		p.amount = 70
		p.lifetime = 0.7
		p.mesh = drop
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(2.2, 0.1, 1.7)
		p.direction = Vector3(0, -1, 0)
		p.spread = 2.0
		p.gravity = Vector3(0, -9.8, 0)
		p.initial_velocity_min = 8.0
		p.initial_velocity_max = 9.0
		r.add_child(p)
		S.cyl(r, 1.3, 1.3, 0.01, Vector3(x + 0.3, 0.006, z + 0.2), puddle, Vector3.ZERO, 20)


func _ledger_board() -> void:
	var x := -6.0
	var board := S.mat(Color(0.12, 0.2, 0.14))
	S.box(self, Vector3(3.4, 2.0, 0.08), Vector3(x, 2.4, D - 0.05), mats["dark_wood"])
	S.box(self, Vector3(3.2, 1.8, 0.04), Vector3(x, 2.4, D - 0.1), board)
	var l := S.label(self, "REQUISITIONS\n& LEDGER", Vector3(x, 2.75, D - 0.13), 56, Color(0.92, 0.9, 0.8), false)
	l.rotation_degrees.y = 180
	var l2 := S.label(self, "Press E or Tab", Vector3(x, 1.85, D - 0.13), 28, Color(0.8, 0.8, 0.7), false)
	l2.rotation_degrees.y = 180
	for k in 5:
		S.box(self, Vector3(0.2, 0.28, 0.01), Vector3(x - 1.3 + k * 0.65, 1.55, D - 0.13), S.mat(Color(0.88, 0.85, 0.75)))
	# Desk with a typewriter
	S.box(self, Vector3(2.2, 0.08, 0.9), Vector3(x, 0.78, D - 1.5), mats["wood"])
	for dx in [-1.0, 1.0]:
		for dz in [-0.38, 0.38]:
			S.box(self, Vector3(0.07, 0.78, 0.07), Vector3(x + dx, 0.39, D - 1.5 + dz), mats["dark_wood"])
	S.box(self, Vector3(0.45, 0.15, 0.35), Vector3(x - 0.3, 0.9, D - 1.5), mats["dark"])
	S.box(self, Vector3(0.3, 0.02, 0.4), Vector3(x + 0.5, 0.83, D - 1.5), S.mat(Color(0.9, 0.88, 0.8)), Vector3(0, 12, 0))
	S.collider(self, Vector3(2.2, 0.85, 0.9), Vector3(x, 0.42, D - 1.5))
	var hit := S.collider(self, Vector3(3.6, 2.8, 2.2), Vector3(x, 1.5, D - 1.2), 2)
	hit.set_meta("kind", "ledger")


func _decor() -> void:
	var drum := S.mat(Color(0.25, 0.3, 0.22), 0.6, 0.4)
	var rust := S.mat(Color(0.45, 0.25, 0.15), 0.8, 0.3)
	for p in [Vector3(18.8, 0, -12.5), Vector3(18.0, 0, -12.9), Vector3(18.9, 0, -11.6), Vector3(-19, 0, 5.5)]:
		S.cyl(self, 0.3, 0.3, 0.9, p + Vector3(0, 0.45, 0), drum if p.x > 0 else rust)
	# Empty crates stacked by the door
	for k in 5:
		S.box(self, Vector3(0.9, 0.7, 0.7), Vector3(17.8 + (k % 2) * 1.0, 0.35 + (k / 2) * 0.7, -5.5), mats["wood"])


func _signs() -> void:
	var p := g("paint")
	var cream := Color(0.95, 0.9, 0.75)
	var red := Color(0.8, 0.15, 0.1)
	var l := S.label(p, "AMMUNITION WORKS No. 7", Vector3(0, 6.7, -D + 0.25), 130, cream, false)
	l.outline_size = 0
	var l2 := S.label(p, "NO SMOKING  -  NO NAKED FLAMES", Vector3(-W + 0.25, 3.2, 0), 70, red, false)
	l2.rotation_degrees.y = 90
	l2.outline_size = 0
	var l3 := S.label(p, "EVERY ROUND COUNTS", Vector3(6, 6.4, D - 0.25), 100, cream, false)
	l3.rotation_degrees.y = 180
	l3.outline_size = 0
	var l4 := S.label(p, "LOADING BAY", Vector3(W - 0.25, 6.3, 0), 90, cream, false)
	l4.rotation_degrees.y = -90
	l4.outline_size = 0
	# Yellow safety lines on the floor
	for z in [-5.6, 3.8]:
		S.box(p, Vector3(38, 0.01, 0.12), Vector3(0, 0.006, z), mats["yellow"])
	S.box(p, Vector3(0.12, 0.01, 9.4), Vector3(17.5, 0.006, -0.9), mats["yellow"])


func _floor_plates() -> void:
	var f := g("floor")
	var plate := S.mat(Color(0.4, 0.42, 0.45), 0.45, 0.8)
	for x in [-10.0, 0.0, 10.0]:
		S.box(f, Vector3(7.2, 0.04, 4.2), Vector3(x + 0.5, 0.02, 0.1), plate)
		for dx in [-3.4, 3.4]:
			S.box(f, Vector3(0.08, 0.05, 4.2), Vector3(x + 0.5 + dx, 0.025, 0.1), mats["yellow"])


func _canteen() -> void:
	var c := g("canteen")
	var cloth := S.mat(Color(0.85, 0.82, 0.72))
	for z in [9.3, 12.0]:
		S.box(c, Vector3(2.8, 0.06, 0.9), Vector3(-15.5, 0.76, z), cloth)
		for dx in [-1.25, 1.25]:
			for dz in [-0.35, 0.35]:
				S.box(c, Vector3(0.06, 0.76, 0.06), Vector3(-15.5 + dx, 0.38, z + dz), mats["dark_wood"])
		for dz in [-0.7, 0.7]:
			S.box(c, Vector3(2.8, 0.06, 0.32), Vector3(-15.5, 0.45, z + dz), mats["wood"])
		S.collider(c, Vector3(2.8, 0.8, 1.8), Vector3(-15.5, 0.4, z))
		for k in 4:
			S.cyl(c, 0.04, 0.035, 0.09, Vector3(-16.6 + k * 0.7, 0.835, z + (0.2 if k % 2 == 0 else -0.2)), S.mat(Color(0.9, 0.9, 0.85)))
	S.box(c, Vector3(0.9, 1.0, 3.2), Vector3(-19.4, 0.5, 10.6), mats["wood"])
	S.collider(c, Vector3(0.9, 1.0, 3.2), Vector3(-19.4, 0.5, 10.6))
	S.cyl(c, 0.22, 0.22, 0.5, Vector3(-19.4, 1.25, 10.0), S.mat(Color(0.6, 0.6, 0.6), 0.3, 0.9))
	var l := S.label(c, "CANTEEN", Vector3(-W + 0.25, 2.6, 10.6), 80, Color(0.95, 0.9, 0.75), false)
	l.rotation_degrees.y = 90


func _crane() -> void:
	var c := g("crane")
	for z in [-3.2, 3.2]:
		S.box(c, Vector3(39.6, 0.35, 0.3), Vector3(0, 7.05, z), mats["yellow"])
		for x in [-15.0, -5.0, 5.0, 15.0]:
			S.box(c, Vector3(0.2, 0.7, 0.2), Vector3(x, 7.5, z), mats["steel"])
	crane_bridge = Node3D.new()
	crane_bridge.position = Vector3(0, 6.8, 0)
	c.add_child(crane_bridge)
	S.box(crane_bridge, Vector3(0.6, 0.5, 6.8), Vector3.ZERO, mats["yellow"])
	S.box(crane_bridge, Vector3(1.0, 0.45, 1.0), Vector3(0, -0.4, 0), mats["dark"])
	S.box(crane_bridge, Vector3(0.04, 2.8, 0.04), Vector3(0, -2.0, 0), mats["dark"])
	S.box(crane_bridge, Vector3(0.45, 0.3, 0.3), Vector3(0, -3.5, 0), mats["yellow"])
	S.cyl(crane_bridge, 0.12, 0.12, 0.05, Vector3(0, -3.75, 0), mats["steel"], Vector3(90, 0, 0))


func _dock() -> void:
	shutter = Node3D.new()
	shutter.position = Vector3(W + 0.1, 2.75, 0)
	shutter.rotation_degrees.z = 4
	add_child(shutter)
	var corr := S.mat(Color(0.42, 0.3, 0.2), 0.8, 0.4)
	S.box(shutter, Vector3(0.1, 5.5, 6.0), Vector3.ZERO, corr)
	for k in 9:
		S.box(shutter, Vector3(0.14, 0.05, 6.0), Vector3(0, -2.5 + k * 0.6, 0), mats["dark"])
	shutter_body = S.collider(self, Vector3(0.4, 5.5, 6.0), Vector3(W + 0.2, 2.75, 0))
	# Dock apron and bumpers (shown once repaired)
	var dk := g("dock")
	S.box(dk, Vector3(3.0, 0.9, 7.0), Vector3(W + 1.9, 0.45, 0), S.mat(Color(0.45, 0.44, 0.4)))
	S.collider(dk, Vector3(3.0, 0.9, 7.0), Vector3(W + 1.9, 0.45, 0))
	for z in [-2.5, 2.5]:
		S.box(dk, Vector3(0.3, 0.4, 0.5), Vector3(W + 3.5, 0.6, z), mats["dark"])
	# Ramp down to the yard
	S.box(dk, Vector3(1.6, 0.1, 7.0), Vector3(W + 2.2, 0.45, 5.9), S.mat(Color(0.45, 0.44, 0.4)), Vector3(-30, 0, 0))
	S.collider(dk, Vector3(1.6, 0.1, 2.0), Vector3(W + 2.2, 0.45, 4.4))


func _lorry() -> void:
	var lg := g("lorry")
	var lorry := Node3D.new()
	lorry.position = Vector3(W + 7.2, 0, 0)
	lorry.rotation_degrees.y = 90
	lg.add_child(lorry)
	var tyre := S.mat(Color(0.08, 0.08, 0.08))
	var canvas := S.mat(Color(0.52, 0.5, 0.36), 0.95)
	S.box(lorry, Vector3(2.2, 0.3, 7.0), Vector3(0, 0.75, 0), mats["dark"])
	S.box(lorry, Vector3(2.2, 1.8, 1.8), Vector3(0, 1.8, 2.6), mats["olive"])
	S.box(lorry, Vector3(2.0, 0.6, 0.05), Vector3(0, 2.2, 3.51), S.mat(Color(0.1, 0.12, 0.14), 0.1, 0.4))
	S.box(lorry, Vector3(2.0, 0.9, 1.0), Vector3(0, 1.3, 3.9), mats["olive"])
	S.box(lorry, Vector3(2.4, 2.4, 4.8), Vector3(0, 2.1, -1.0), canvas)
	for z in [2.7, -0.4, -2.4]:
		for x in [-1.1, 1.1]:
			S.cyl(lorry, 0.5, 0.5, 0.35, Vector3(x, 0.5, z), tyre, Vector3(0, 0, 90))
	var star := S.label(lorry, "SUPPLY", Vector3(1.21, 2.2, -1.0), 70, Color(0.95, 0.95, 0.9), false)
	star.rotation_degrees.y = 90
	S.collider(lg, Vector3(7.5, 3.4, 2.5), Vector3(W + 7.2, 1.7, 0))


func _power() -> void:
	# Old hand-crank dynamo (always there)
	var base := Vector3(18.4, 0, 12.6)
	S.box(self, Vector3(1.0, 0.6, 0.7), base + Vector3(0, 0.3, 0), mats["dark"])
	S.cyl(self, 0.32, 0.32, 0.06, base + Vector3(0.55, 0.6, 0), mats["steel"], Vector3(0, 0, 90))
	var lab := S.label(self, "DYNAMO", base + Vector3(0, 0.7, 0.36), 22, Color(0.9, 0.85, 0.7), false)
	lab.outline_size = 2
	# Diesel generator
	var dg := g("p_diesel")
	var dn := Node3D.new()
	dn.position = Vector3(15.6, 0, 12.6)
	dg.add_child(dn)
	S.box(dn, Vector3(2.4, 1.3, 1.1), Vector3(0, 0.65, 0), mats["olive"])
	S.box(dn, Vector3(0.3, 1.1, 1.0), Vector3(-1.35, 0.6, 0), S.mat(Color(0.2, 0.2, 0.2), 0.5, 0.7))
	S.cyl(dn, 0.08, 0.08, 6.7, Vector3(0.8, 4.65, 0.2), mats["dark"])
	var dl := S.label(dn, "DIESEL", Vector3(0, 0.9, 0.56), 26, Color(0.9, 0.85, 0.7), false)
	dl.outline_size = 2
	vibrators.append(dn)
	S.collider(dg, Vector3(2.8, 1.3, 1.1), Vector3(15.5, 0.65, 12.6))
	# Coal boiler & turbine
	var bg := g("p_boiler")
	var red := S.mat(Color(0.35, 0.18, 0.14), 0.6, 0.5)
	S.cyl(bg, 1.1, 1.1, 3.6, Vector3(16.8, 1.4, 8.6), red, Vector3(0, 0, 90))
	S.box(bg, Vector3(1.0, 2.2, 2.0), Vector3(14.6, 1.1, 8.6), mats["dark"])
	S.box(bg, Vector3(0.5, 0.5, 0.05), Vector3(14.6, 0.8, 9.62), S.emissive(Color(1.0, 0.45, 0.1), 3.0))
	S.cyl(bg, 0.28, 0.28, 9.0, Vector3(18.0, 6.5, 8.6), mats["dark"])
	S.cyl(bg, 0.4, 0.4, 0.8, Vector3(19.0, 0.8, 7.2), mats["steel"], Vector3(0, 0, 90))
	var bl := S.label(bg, "BOILER", Vector3(16.8, 1.4, 9.72), 30, Color(0.9, 0.85, 0.7), false)
	bl.outline_size = 2
	S.collider(bg, Vector3(5.0, 2.5, 2.4), Vector3(16.6, 1.25, 8.6))
	# Mains grid transformer
	var gg := g("p_grid")
	S.box(gg, Vector3(1.6, 1.8, 1.2), Vector3(12.6, 0.9, 12.5), S.mat(Color(0.4, 0.42, 0.42), 0.5, 0.6))
	for k in 3:
		S.cyl(gg, 0.08, 0.12, 0.5, Vector3(12.1 + k * 0.5, 2.05, 12.5), S.mat(Color(0.55, 0.3, 0.2), 0.3))
	for k in 5:
		S.box(gg, Vector3(0.12, 1.4, 0.05), Vector3(11.74, 0.9, 12.1 + k * 0.2), mats["dark"])
	S.box(gg, Vector3(0.15, 6.0, 0.15), Vector3(12.6, 5.0, 13.8), mats["dark"])
	var gl := S.label(gg, "MAINS", Vector3(12.6, 1.2, 11.88), 26, Color(0.9, 0.85, 0.7), false)
	gl.rotation_degrees.y = 180
	S.collider(gg, Vector3(1.6, 1.8, 1.2), Vector3(12.6, 0.9, 12.5))
	# Substation in the yard
	var sg := g("p_substation")
	var sx := W + 8.0
	var sz := 11.0
	for k in 2:
		S.box(sg, Vector3(1.8, 2.2, 1.4), Vector3(sx - 1.2 + k * 2.4, 1.1, sz), S.mat(Color(0.4, 0.42, 0.42), 0.5, 0.6))
	S.box(sg, Vector3(0.3, 12.0, 0.3), Vector3(sx, 6.0, sz + 2.5), mats["steel"])
	S.box(sg, Vector3(4.0, 0.2, 0.2), Vector3(sx, 11.0, sz + 2.5), mats["steel"])
	for k in 12:
		var a := k / 12.0 * TAU
		S.box(sg, Vector3(0.08, 2.0, 0.08), Vector3(sx + cos(a) * 4.0, 1.0, sz + sin(a) * 3.2), mats["steel"])
	S.collider(sg, Vector3(5.0, 2.2, 1.6), Vector3(sx, 1.1, sz))


func _shelter() -> void:
	var s := g("shelter")
	var bag: StandardMaterial3D = mats["khaki"]
	# Blast wall around the power corner, with a gap to walk through
	for row in 4:
		for k in 9:
			S.box(s, Vector3(0.62, 0.22, 0.38), Vector3(11.0, 0.11 + row * 0.22, 6.8 + k * 0.64 + (0.32 if row % 2 else 0.0)), bag)
		for k in 9:
			S.box(s, Vector3(0.62, 0.22, 0.38), Vector3(14.2 + k * 0.64 + (0.32 if row % 2 else 0.0), 0.11 + row * 0.22, 6.3), bag, Vector3(0, 90, 0))
	S.collider(s, Vector3(0.4, 0.9, 5.8), Vector3(11.0, 0.45, 9.6))
	S.collider(s, Vector3(5.8, 0.9, 0.4), Vector3(17.0, 0.45, 6.3))
	var l := S.label(s, "AIR RAID SHELTER  >", Vector3(-W + 0.25, 3.0, -8), 60, Color(0.95, 0.9, 0.75), false)
	l.rotation_degrees.y = 90
	l.outline_size = 0
	# Fire buckets
	var red := S.mat(Color(0.75, 0.12, 0.08))
	S.box(s, Vector3(2.2, 0.06, 0.25), Vector3(2.0, 1.6, D - 0.15), mats["dark_wood"])
	for k in 4:
		S.cyl(s, 0.14, 0.11, 0.3, Vector3(1.25 + k * 0.5, 1.4, D - 0.25), red)


func _rail() -> void:
	var r := g("rail")
	var x := W + 15.0
	for dx in [-0.72, 0.72]:
		S.box(r, Vector3(0.08, 0.14, 90), Vector3(x + dx, 0.14, 0), mats["steel"])
	for k in 75:
		S.box(r, Vector3(2.4, 0.1, 0.25), Vector3(x, 0.05, -45 + k * 1.2), mats["dark_wood"])
	# Platform between yard and rails
	S.box(r, Vector3(3.0, 0.9, 16.0), Vector3(x - 3.2, 0.45, 0), S.mat(Color(0.45, 0.44, 0.4)))
	S.collider(r, Vector3(3.0, 0.9, 16.0), Vector3(x - 3.2, 0.45, 0))
	var wagon := S.mat(Color(0.38, 0.2, 0.14), 0.8)
	for z in [-5.0, 3.5]:
		S.box(r, Vector3(2.6, 2.2, 7.0), Vector3(x, 1.9, z), wagon)
		S.box(r, Vector3(2.7, 0.15, 7.2), Vector3(x, 3.05, z), mats["dark"])
		for dz in [-2.5, 2.5]:
			for dx in [-0.72, 0.72]:
				S.cyl(r, 0.42, 0.42, 0.12, Vector3(x + dx, 0.5, z + dz), mats["dark"], Vector3(0, 0, 90))
		S.collider(r, Vector3(2.6, 3.0, 7.0), Vector3(x, 1.5, z))


# ------------------------------------------------------------------ repairs

func apply(owned: Dictionary) -> void:
	_set_group("rubble", not owned.has("rubble"))
	_set_group("roof_patch", owned.has("roof"))
	_set_group("rain", not owned.has("roof"))
	var lit := owned.has("lights")
	for l in lamps:
		l.light_energy = 1.7 if lit else 0.0
	mats["bulb"].emission_enabled = lit
	_set_group("win_broken", not owned.has("windows"))
	_set_group("win_glass", owned.has("windows"))
	var painted := owned.has("paint")
	mats["wall_lo"].albedo_color = Color(0.22, 0.3, 0.22) if painted else Color(0.42, 0.26, 0.2)
	mats["wall_hi"].albedo_color = Color(0.74, 0.7, 0.58) if painted else Color(0.48, 0.31, 0.24)
	mats["floor"].albedo_color = Color(0.42, 0.41, 0.39) if painted else Color(0.34, 0.33, 0.31)
	_set_group("paint", painted)
	var dock := owned.has("dock")
	_set_group("dock", dock)
	_set_group("lorry", dock)
	if dock:
		shutter.position = Vector3(W + 0.1, 6.6, 0)
		shutter.rotation_degrees.z = 0
		shutter.scale = Vector3(1, 0.3, 1)
		shutter_body.collision_layer = 0
	_set_group("floor", owned.has("floor"))
	_set_group("canteen", owned.has("canteen"))
	_set_group("crane", owned.has("crane"))
	_set_group("shelter", owned.has("shelter"))
	_set_group("blackout", owned.has("shelter"))
	_set_group("rail", owned.has("rail"))
	for p in ["diesel", "boiler", "grid", "substation"]:
		_set_group("p_" + p, owned.has(p))


func _process(delta: float) -> void:
	_t += delta
	if flicker_light:
		var f := 1.6
		if fmod(_t, 4.3) < 0.25 or fmod(_t, 7.1) < 0.12:
			f = randf_range(0.1, 1.2)
		flicker_light.light_energy = f
	if crane_bridge and crane_bridge.is_visible_in_tree():
		crane_bridge.position.x = sin(_t * 0.15) * 13.0
	for v in vibrators:
		if v.is_visible_in_tree():
			v.position.y = sin(_t * 70.0) * 0.008
