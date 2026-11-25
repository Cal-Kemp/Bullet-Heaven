extends Node3D
## One workbench / production line. Steps run left to right along the bench.
## Automation takes over steps from the left; once all four are automated the
## line runs on its own and extra lines multiply its output.

const S = preload("res://scripts/shapes.gd")
const Data = preload("res://scripts/data.gd")
const SLOT_X := [-1.5, -0.5, 0.5, 1.5]
const BENCH_Y := 0.94
const WP_Z := 0.3

var game
var d: Dictionary
var pid := ""

# --- saved state ---
var unlocked := false
var auto := 0       # number of automated steps (from the left)
var speed := 0      # speed upgrade level
var lines := 1      # parallel lines (only matters when fully automated)
var made := 0.0

# --- transient state ---
var step := 0
var click_prog := 0
var auto_prog := 0.0
var cycle_phase := 0.0
var unit_acc := 0.0
var _t := 0.0

# --- visuals ---
var tool_nodes := []
var tool_pulse := [0.0, 0.0, 0.0, 0.0]
var machine_nodes := []
var flywheels := []
var press_head: Node3D
var workpiece: Node3D
var wp_proj: Node3D
var marker: Node3D
var info_label: Label3D
var lock_label: Label3D
var locked_root: Node3D
var unlocked_root: Node3D
var crate_root: Node3D
var crate_mat: StandardMaterial3D
var crates_shown := -1
var hit_bodies := []
var lock_body: StaticBody3D


func setup(p_game, data: Dictionary) -> void:
	game = p_game
	d = data
	pid = d["id"]
	name = "Station_" + pid
	position = d["pos"]
	_build()


# ------------------------------------------------------------------ building

func _build() -> void:
	var wood := S.mat(Color(0.45, 0.32, 0.19))
	var dark_wood := S.mat(Color(0.28, 0.19, 0.11))
	# Bench
	S.box(self, Vector3(4.3, 0.08, 1.1), Vector3(0, 0.9, 0), wood)
	for x in [-2.05, 2.05]:
		for z in [-0.48, 0.48]:
			S.box(self, Vector3(0.08, 0.9, 0.08), Vector3(x, 0.45, z), dark_wood)
	S.box(self, Vector3(4.2, 0.05, 1.0), Vector3(0, 0.25, 0), dark_wood)
	S.collider(self, Vector3(4.3, 0.95, 1.1), Vector3(0, 0.475, 0))
	# Pallet for finished crates
	S.box(self, Vector3(1.2, 0.12, 1.0), Vector3(2.95, 0.06, 0), dark_wood)
	crate_root = Node3D.new()
	crate_root.position = Vector3(2.95, 0.12, 0)
	add_child(crate_root)
	crate_mat = S.mat(Color(0.47, 0.4, 0.24))

	unlocked_root = Node3D.new()
	add_child(unlocked_root)
	locked_root = Node3D.new()
	add_child(locked_root)

	for i in 4:
		var t := Node3D.new()
		t.position = Vector3(SLOT_X[i], BENCH_Y, -0.22)
		unlocked_root.add_child(t)
		_build_tool(t, i)
		tool_nodes.append(t)
		var hb := S.collider(unlocked_root, Vector3(0.95, 1.0, 1.3), Vector3(SLOT_X[i], 1.35, 0.0), 2)
		hb.set_meta("kind", "step")
		hb.set_meta("station", self)
		hb.set_meta("step", i)
		hit_bodies.append(hb)
		var m := Node3D.new()
		m.position = Vector3(SLOT_X[i], 0, -1.0)
		unlocked_root.add_child(m)
		_build_machine(m, i)
		machine_nodes.append(m)

	_build_workpiece()

	marker = Node3D.new()
	unlocked_root.add_child(marker)
	S.cyl(marker, 0.09, 0.0, 0.18, Vector3.ZERO, S.emissive(Color(1.0, 0.65, 0.15), 2.5), Vector3.ZERO, 8)

	info_label = S.label(self, "", Vector3(0, 2.45, 0), 34)
	S.fade(info_label, 15.0)

	# Locked: tarp over the bench and a sign
	S.box(locked_root, Vector3(4.5, 0.25, 1.3), Vector3(0, 1.0, 0), S.mat(Color(0.33, 0.31, 0.24)))
	S.box(locked_root, Vector3(4.5, 0.9, 0.05), Vector3(0, 0.55, 0.65), S.mat(Color(0.3, 0.28, 0.22)))
	var tape := S.mat(Color(0.75, 0.62, 0.15))
	S.box(locked_root, Vector3(0.06, 1.1, 0.06), Vector3(-2.4, 0.55, 1.0), dark_wood)
	S.box(locked_root, Vector3(0.06, 1.1, 0.06), Vector3(2.4, 0.55, 1.0), dark_wood)
	S.box(locked_root, Vector3(4.8, 0.04, 0.02), Vector3(0, 1.0, 1.0), tape)
	lock_label = S.label(locked_root, "", Vector3(0, 2.0, 0), 34, Color(0.95, 0.8, 0.5))
	S.fade(lock_label, 13.0)
	lock_body = S.collider(locked_root, Vector3(4.6, 1.8, 1.6), Vector3(0, 0.9, 0.1), 2)
	lock_body.set_meta("kind", "unlock")
	lock_body.set_meta("station", self)


func _build_tool(t: Node3D, i: int) -> void:
	var steel := S.mat(Color(0.42, 0.43, 0.45), 0.45, 0.7)
	var dark := S.mat(Color(0.18, 0.19, 0.2), 0.6, 0.5)
	var green := S.mat(Color(0.28, 0.34, 0.24), 0.7, 0.2)
	match i:
		0: # Hopper on a stand with a scale pan
			S.box(t, Vector3(0.42, 0.03, 0.32), Vector3(0, 0.015, 0), steel)
			S.box(t, Vector3(0.04, 0.6, 0.04), Vector3(0.18, 0.3, -0.1), dark)
			S.cyl(t, 0.16, 0.16, 0.24, Vector3(0, 0.58, -0.05), green)
			S.cyl(t, 0.16, 0.03, 0.16, Vector3(0, 0.38, -0.05), green)
		1: # Tray of projectiles
			S.box(t, Vector3(0.6, 0.06, 0.42), Vector3(0, 0.03, 0), S.mat(Color(0.3, 0.2, 0.12)))
			var pm := S.mat(d["proj_col"], 0.4, 0.5)
			var r: float = minf(0.03, d["proj"][0])
			for a in 4:
				for b in 3:
					S.cyl(t, 0.0, r, 0.07, Vector3(-0.21 + a * 0.14, 0.095, -0.12 + b * 0.12), pm, Vector3.ZERO, 8)
		2: # Bench press with a moving head
			S.box(t, Vector3(0.36, 0.08, 0.36), Vector3(0, 0.04, 0), dark)
			S.cyl(t, 0.035, 0.035, 0.85, Vector3(-0.13, 0.45, -0.12), steel)
			S.cyl(t, 0.035, 0.035, 0.85, Vector3(0.13, 0.45, -0.12), steel)
			S.box(t, Vector3(0.4, 0.08, 0.12), Vector3(0, 0.86, -0.12), dark)
			press_head = Node3D.new()
			press_head.position = Vector3(0, 0.62, 0)
			t.add_child(press_head)
			S.box(press_head, Vector3(0.3, 0.12, 0.3), Vector3.ZERO, S.mat(Color(0.55, 0.15, 0.1), 0.6, 0.3))
			S.cyl(press_head, 0.03, 0.03, 0.2, Vector3(0, 0.15, 0), steel)
		3: # Open crate
			var wood := S.mat(Color(0.5, 0.4, 0.22))
			S.box(t, Vector3(0.6, 0.03, 0.45), Vector3(0, 0.015, 0), wood)
			S.box(t, Vector3(0.6, 0.28, 0.03), Vector3(0, 0.14, 0.21), wood)
			S.box(t, Vector3(0.6, 0.28, 0.03), Vector3(0, 0.14, -0.21), wood)
			S.box(t, Vector3(0.03, 0.28, 0.45), Vector3(0.29, 0.14, 0), wood)
			S.box(t, Vector3(0.03, 0.28, 0.45), Vector3(-0.29, 0.14, 0), wood)
			var lab := S.label(t, "AMMO", Vector3(0, 0.15, 0.23), 18, Color(0.15, 0.12, 0.08), false)
			lab.outline_size = 0


func _build_machine(m: Node3D, i: int) -> void:
	var body := S.mat(Color(0.25, 0.31, 0.23), 0.6, 0.3)
	var steel := S.mat(Color(0.42, 0.43, 0.45), 0.45, 0.7)
	var dark := S.mat(Color(0.15, 0.15, 0.16), 0.6, 0.5)
	S.box(m, Vector3(0.82, 1.5, 0.6), Vector3(0, 0.75, 0), body)
	S.box(m, Vector3(0.86, 0.08, 0.64), Vector3(0, 1.54, 0), steel)
	var fw := S.cyl(m, 0.24, 0.24, 0.07, Vector3(0, 1.05, 0.34), steel, Vector3(90, 0, 0), 20)
	S.box(fw, Vector3(0.44, 0.08, 0.05), Vector3(0, 0.0, 0), dark)
	flywheels.append(fw)
	S.sphere(m, 0.05, Vector3(0.3, 1.64, 0.2), S.emissive(Color(0.25, 1.0, 0.35), 2.0))
	S.box(m, Vector3(0.08, 0.08, 0.75), Vector3(0, 1.38, 0.62), steel)
	S.box(m, Vector3(0.06, 0.3, 0.06), Vector3(0, 1.24, 0.98), steel)
	var lab := S.label(m, d["machines"][i], Vector3(0, 0.55, 0.31), 16, Color(0.95, 0.9, 0.7), false)
	lab.outline_size = 4
	S.fade(lab, 9.0)
	m.visible = false


func _build_workpiece() -> void:
	workpiece = Node3D.new()
	unlocked_root.add_child(workpiece)
	var case_mat := S.mat(d["case_col"], 0.35, 0.75)
	var proj_mat := S.mat(d["proj_col"], 0.4, 0.5)
	var c = d["case"]
	var p = d["proj"]
	var cnt := int(d["count"])
	wp_proj = Node3D.new()
	workpiece.add_child(wp_proj)
	for k in cnt:
		var off := (k - (cnt - 1) / 2.0) * 0.07
		S.cyl(workpiece, c[0], c[0], c[1], Vector3(off, c[1] / 2.0, 0), case_mat)
		var body_h: float = p[1] * 0.55
		var tip_h: float = p[1] * 0.45
		S.cyl(wp_proj, p[0], p[0], body_h, Vector3(off, c[1] + body_h / 2.0, 0), proj_mat)
		S.cyl(wp_proj, 0.002, p[0], tip_h, Vector3(off, c[1] + body_h + tip_h / 2.0, 0), proj_mat)
	workpiece.scale = Vector3.ONE * float(d.get("show_scale", 1.0))
	if pid == "heavy" or pid == "tank":
		# Yellow identification band
		S.cyl(wp_proj, p[0] * 1.02, p[0] * 1.02, 0.03, Vector3(0, c[1] + p[1] * 0.3, 0), S.mat(Color(0.85, 0.7, 0.1)))


# ------------------------------------------------------------------ logic

func speed_mult() -> float:
	return pow(Data.SPEED_MULT, speed)


func cycle_time() -> float:
	return 4.0 * float(d["step_time"]) / speed_mult()


## Units per second when fully automated (0 otherwise).
func auto_rate() -> float:
	if not unlocked or auto < 4:
		return 0.0
	return lines / cycle_time()


func fully_automated() -> bool:
	return auto >= 4


func tick(delta: float) -> void:
	if not unlocked:
		return
	if auto >= 4:
		var cyc := cycle_time()
		cycle_phase = fmod(cycle_phase + delta / cyc, 1.0)
		unit_acc += lines * delta / cyc
		if unit_acc >= 1.0:
			var n := floorf(unit_acc)
			unit_acc -= n
			_produce(n, false)
		var s := int(cycle_phase * 4.0)
		if s != step:
			if s < step:
				_snap_workpiece()
			step = s
			tool_pulse[step] = 1.0
	elif step < auto:
		auto_prog += delta * speed_mult() / float(d["step_time"])
		if auto_prog >= 1.0:
			auto_prog = 0.0
			_advance()


## Player clicked step i on this bench. Returns a message if nothing happened.
func manual_click(i: int) -> String:
	if not unlocked:
		return ""
	if auto >= 4:
		return "This line runs itself now."
	if i < auto and i == step:
		return "The %s is handling this." % d["machines"][i].to_lower()
	if i != step:
		if step < auto:
			return "Wait for the %s." % d["machines"][step].to_lower()
		return "Next step: %s" % d["steps"][step]
	click_prog += 1
	tool_pulse[i] = 1.0
	game.sfx.play("click")
	if click_prog >= int(d["clicks"]):
		_advance()
	return ""


func prompt_for(i: int) -> String:
	var steps = d["steps"]
	if auto >= 4:
		return "%s  (automated)" % steps[i]
	if i < auto:
		return "%s  (%s)" % [steps[i], d["machines"][i]]
	if i == step:
		var s := "[E] %s" % steps[i]
		if int(d["clicks"]) > 1:
			s += "  %d/%d" % [click_prog, int(d["clicks"])]
		return s
	return "%s  - next is: %s" % [steps[i], steps[step]]


func _advance() -> void:
	click_prog = 0
	tool_pulse[step] = 1.0
	step += 1
	if step >= 4:
		step = 0
		_produce(1.0, true)
		_snap_workpiece()
	elif step > auto:
		game.sfx.play("step")


func _produce(n: float, manual: bool) -> void:
	made += n
	game.earn(n * float(d["value"]) * game.mult())
	if manual:
		game.sfx.play("done")
	_update_crates()


# ------------------------------------------------------------------ visuals

func refresh() -> void:
	locked_root.visible = not unlocked
	unlocked_root.visible = unlocked
	info_label.visible = unlocked
	# Hidden nodes still collide, so switch the hitboxes over explicitly.
	lock_body.collision_layer = 0 if unlocked else 2
	for hb in hit_bodies:
		hb.collision_layer = 2 if unlocked else 0
	for i in 4:
		machine_nodes[i].visible = i < auto
	if auto >= 4:
		auto_prog = 0.0
		click_prog = 0
	if not unlocked:
		lock_label.text = game.lock_text(self)
	_update_crates()
	_snap_workpiece()
	update_label()


func update_label() -> void:
	if not unlocked:
		lock_label.text = game.lock_text(self)
		return
	var status := ""
	if auto >= 4:
		status = "Fully automated  -  %d line%s" % [lines, "" if lines == 1 else "s"]
		status += "\n%s %s/s" % [game.fmt(auto_rate()), d["unit"]]
	elif step < auto:
		status = "%s working..." % d["machines"][step]
	else:
		status = "Next: %s" % d["steps"][step]
	info_label.text = "%s\n%s\n%s made" % [String(d["name"]).to_upper(), status, game.fmt(made)]


func _update_crates() -> void:
	var n := int(floorf(made / float(d["crate"]))) % 25
	if n == crates_shown:
		return
	crates_shown = n
	for c in crate_root.get_children():
		c.queue_free()
	for k in n:
		var col := k % 3
		var row := (k / 3) % 2
		var lvl := k / 6
		S.box(crate_root, Vector3(0.34, 0.32, 0.36), Vector3(-0.38 + col * 0.38, 0.16 + lvl * 0.33, -0.2 + row * 0.4), crate_mat)


func _wp_target() -> Vector3:
	return Vector3(SLOT_X[step], BENCH_Y, WP_Z)


func _snap_workpiece() -> void:
	if workpiece:
		workpiece.position = _wp_target()


func _process(delta: float) -> void:
	if not unlocked:
		return
	_t += delta
	workpiece.position = workpiece.position.lerp(_wp_target(), minf(1.0, delta * 14.0))
	wp_proj.visible = step >= 2
	var spin := speed_mult() * 6.0
	for i in 4:
		if i < auto:
			var active := auto >= 4 or step == i
			flywheels[i].rotate_object_local(Vector3.UP, delta * (spin if active else 0.6))
		tool_pulse[i] = maxf(0.0, tool_pulse[i] - delta * 5.0)
		tool_nodes[i].scale = Vector3.ONE * (1.0 + 0.08 * tool_pulse[i])
	if press_head:
		press_head.position.y = 0.62 - 0.16 * tool_pulse[2]
	var manual_here := auto < 4 and step >= auto
	marker.visible = manual_here
	if manual_here:
		marker.position = Vector3(SLOT_X[step], 2.0 + sin(_t * 4.0) * 0.06, -0.1)
