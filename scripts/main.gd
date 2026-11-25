extends Node3D
## Game controller: economy, purchases, interaction, saving.

const Data = preload("res://scripts/data.gd")
const S = preload("res://scripts/shapes.gd")
const StationScript = preload("res://scripts/station.gd")
const WorldScript = preload("res://scripts/world.gd")
const PlayerScript = preload("res://scripts/player.gd")
const UIScript = preload("res://scripts/ui.gd")
const SfxScript = preload("res://scripts/sfx.gd")
var save_path := "user://save.json"
const SPAWN := Vector3(-14, 0, -5.6)

var money := 0.0
var total_earned := 0.0
var owned := {}
var play_time := 0.0
var won := false
var seen_intro := false

var stations := {}
var world
var player
var ui
var sfx
var env: Environment
var rate := 0.0

var _earn_bucket := 0.0
var _rate_t := 0.0
var _save_t := 0.0
var _hold_t := 0.0
var _label_t := 0.0
var _no_save := false
var _debug_dir := ""


func _ready() -> void:
	_setup_input()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Courier New", "Courier", "Liberation Mono", "monospace"])
	f.font_weight = 700
	S.font = f
	_setup_env()
	world = WorldScript.new()
	add_child(world)
	world.build(self)
	for p in Data.PRODUCTS:
		var st = StationScript.new()
		add_child(st)
		st.setup(self, p)
		stations[p["id"]] = st
	stations["pistol"].unlocked = true
	sfx = SfxScript.new()
	add_child(sfx)
	player = PlayerScript.new()
	add_child(player)
	player.look_from(SPAWN, Vector3(-14, 1.0, -9))
	ui = UIScript.new()
	ui.game = self
	add_child(ui)

	for a in OS.get_cmdline_user_args():
		if a == "--bench":
			_no_save = true
			_debug_dir = "bench"
			get_tree().create_timer(6.0).timeout.connect(func():
				print("BENCH fps=%s" % Engine.get_frames_per_second())
				get_tree().quit())
		if a == "--savetest":
			_debug_dir = "bench"
			save_path = "user://savetest.json"
			_savetest.call_deferred()
		if a.begins_with("--shots="):
			_debug_dir = a.substr(8)
			_no_save = true
	var offline := 0.0
	if _debug_dir == "":
		offline = load_game()
	refresh_all()
	if _debug_dir == "bench":
		return
	if _debug_dir != "":
		_debug_shots()
		return
	if not seen_intro:
		_show_intro()
	elif offline > 0.0:
		ui.show_dialog("While you were away", "The night shift kept the automated lines running at half pace.\n\nThey earned %s cr." % fmt(offline), [["Back to work", Callable()]])
	update_mouse()


func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("jump", [KEY_SPACE])
	_bind("sprint", [KEY_SHIFT])
	_bind("interact", [KEY_E], MOUSE_BUTTON_LEFT)
	_bind("ledger", [KEY_TAB, KEY_L])
	_bind("menu", [KEY_ESCAPE, KEY_P])


func _bind(action: String, keys: Array, mouse: int = -1) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	if mouse >= 0:
		var m := InputEventMouseButton.new()
		m.button_index = mouse
		InputMap.action_add_event(action, m)


func _setup_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.42, 0.5, 0.6)
	sm.sky_horizon_color = Color(0.68, 0.7, 0.72)
	sm.ground_horizon_color = Color(0.5, 0.5, 0.48)
	sm.ground_bottom_color = Color(0.25, 0.25, 0.22)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.68)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.56, 0.6)
	env.fog_density = 0.006
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


# ------------------------------------------------------------------ economy

func mult() -> float:
	var m := 1.0
	for r in Data.REPAIRS:
		if owned.has(r["id"]):
			m += float(r["bonus"])
	return m


func power_cap() -> int:
	var p := Data.START_POWER
	for g in Data.POWER:
		if owned.has(g["id"]):
			p += int(g["power"])
	return p


func power_used() -> int:
	var u := 0
	for st in stations.values():
		u += st.auto * int(st.d["power"])
	return u


func earn(amount: float) -> void:
	money += amount
	total_earned += amount
	_earn_bucket += amount


## Income per second from fully automated lines only (used for offline earnings).
func auto_income() -> float:
	var t := 0.0
	for st in stations.values():
		t += st.auto_rate() * float(st.d["value"])
	return t * mult()


func auto_cost(st) -> float:
	return float(st.d["auto_base"]) * pow(Data.AUTO_GROWTH, st.auto)


func speed_cost(st) -> float:
	return float(st.d["auto_base"]) * Data.SPEED_BASE * pow(Data.SPEED_GROWTH, st.speed)


func line_cost(st) -> float:
	return float(st.d["auto_base"]) * Data.LINE_BASE * pow(Data.LINE_GROWTH, st.lines - 1)


func missing_reqs(st) -> Array:
	var miss := []
	for r in st.d["requires"]:
		if not owned.has(r):
			miss.append(Data.repair_name(r))
	return miss


func _find(list: Array, id: String) -> Dictionary:
	for x in list:
		if x["id"] == id:
			return x
	return {}


## Works out whether `key` ("kind:id") can be bought right now.
func offer(key: String) -> Dictionary:
	var parts := key.split(":")
	var kind := parts[0]
	var id := parts[1]
	var r := {"cost": 0.0, "reason": "", "done": false}
	match kind:
		"unlock":
			var st = stations[id]
			r["done"] = st.unlocked
			r["cost"] = float(st.d["unlock"])
			var miss := missing_reqs(st)
			if miss.size() > 0:
				r["reason"] = "Needs " + ", ".join(miss)
		"auto":
			var st = stations[id]
			r["done"] = st.auto >= 4
			if not r["done"]:
				r["cost"] = auto_cost(st)
				if power_used() + int(st.d["power"]) > power_cap():
					r["reason"] = "Not enough power"
		"speed":
			var st = stations[id]
			r["cost"] = speed_cost(st)
			if st.auto < 1:
				r["reason"] = "Automate a step first"
		"line":
			var st = stations[id]
			r["cost"] = line_cost(st)
			if st.auto < 4:
				r["reason"] = "Automate all 4 steps first"
		"repair":
			r["done"] = owned.has(id)
			r["cost"] = float(_find(Data.REPAIRS, id)["cost"])
		"power":
			r["done"] = owned.has(id)
			r["cost"] = float(_find(Data.POWER, id)["cost"])
	r["ok"] = not r["done"] and r["reason"] == "" and money >= r["cost"]
	return r


func buy(key: String) -> void:
	var o := offer(key)
	if not o["ok"]:
		sfx.play("error")
		if o["reason"] != "":
			ui.toast(o["reason"], UIScript.RED)
		elif not o["done"]:
			ui.toast("Not enough funds - need %s cr." % fmt(o["cost"]), UIScript.RED)
		return
	money -= o["cost"]
	var parts := key.split(":")
	var id := parts[1]
	match parts[0]:
		"unlock":
			stations[id].unlocked = true
			ui.toast("Contract signed: %s. The bench is yours." % stations[id].d["name"], UIScript.AMBER)
		"auto":
			var st = stations[id]
			ui.toast("Installed: %s on the %s bench." % [st.d["machines"][st.auto], st.d["name"]], UIScript.AMBER)
			st.auto += 1
			if st.auto >= 4:
				st.step = 0
				st.cycle_phase = 0.0
				ui.toast("%s line is fully automated!" % st.d["name"], UIScript.AMBER)
		"speed":
			stations[id].speed += 1
		"line":
			stations[id].lines += 1
			ui.toast("New %s line running (%d total)." % [stations[id].d["name"], stations[id].lines], UIScript.AMBER)
		"repair":
			owned[id] = true
			ui.toast("Repair done: %s." % _find(Data.REPAIRS, id)["name"], UIScript.AMBER)
		"power":
			owned[id] = true
			ui.toast("Power online: %s." % _find(Data.POWER, id)["name"], UIScript.AMBER)
	sfx.play("buy")
	refresh_all()
	if ui.ledger.visible:
		ui.refresh_ledger()
	_save_t = 15.0  # save soon


func refresh_all() -> void:
	world.apply(owned)
	for st in stations.values():
		st.refresh()


func _btn_text(o: Dictionary, done_text: String) -> String:
	if o["done"]:
		return done_text
	if o["reason"] != "":
		return "Locked"
	return "%s cr" % fmt(o["cost"])


func _row(key: String, title: String, desc: String, done_text: String = "Done") -> Dictionary:
	var o := offer(key)
	var d := desc
	if o["reason"] != "" and not o["done"]:
		d += ("\n" if d != "" else "") + o["reason"] + "."
	return {"key": key, "title": title, "desc": d, "btn": _btn_text(o, done_text), "enabled": o["ok"]}


func ledger_rows(tab: String) -> Array:
	var rows := []
	match tab:
		"production":
			for p in Data.PRODUCTS:
				var st = stations[p["id"]]
				var id: String = p["id"]
				var status := "Not under contract"
				if st.unlocked:
					status = "%s %s made" % [fmt(st.made), p["unit"]]
					if st.auto >= 4:
						status += "  |  %s/s  |  %d line%s" % [fmt(st.auto_rate()), st.lines, "" if st.lines == 1 else "s"]
					else:
						status += "  |  %d/4 steps automated" % st.auto
					status += "  |  %s cr each" % fmt(float(p["value"]) * mult())
				rows.append({"key": "hdr:" + id, "header": true, "title": String(p["name"]).to_upper(), "desc": status})
				if not st.unlocked:
					rows.append(_row("unlock:" + id, "Sign the contract", "%s Pays %s cr per unit." % [p["desc"], fmt(float(p["value"]))]))
					continue
				if st.auto < 4:
					rows.append(_row("auto:" + id, "Automate: %s" % p["machines"][st.auto],
						"Takes over '%s'. Draws %d power." % [p["steps"][st.auto], int(p["power"])]))
				else:
					rows.append({"key": "auto:" + id, "title": "All four steps automated", "desc": "The line runs on its own.", "btn": "Done", "enabled": false})
				rows.append(_row("speed:" + id, "Faster machinery  (level %d)" % st.speed,
					"Machines run 25%% faster. Currently x%.2f." % st.speed_mult()))
				rows.append(_row("line:" + id, "Extra production line  (%d running)" % st.lines,
					"Another full set of machines: +1 %s every cycle." % String(p["unit"]).trim_suffix("s")))
		"warehouse":
			rows.append({"key": "hdr:wh", "header": true, "title": "REPAIRS & IMPROVEMENTS",
				"desc": "Each repair raises the whole works' output. Current bonus: +%d%%" % roundi((mult() - 1.0) * 100.0)})
			for r in Data.REPAIRS:
				rows.append(_row("repair:" + r["id"], r["name"], "%s  (+%d%% output)" % [r["desc"], roundi(float(r["bonus"]) * 100.0)], "Done"))
		"power":
			rows.append({"key": "hdr:pw", "header": true, "title": "POWER",
				"desc": "Each automated step draws power. In use: %d / %d. The old hand-crank dynamo gives %d." % [power_used(), power_cap(), Data.START_POWER]})
			for g in Data.POWER:
				rows.append(_row("power:" + g["id"], g["name"], "%s  (+%d power)" % [g["desc"], int(g["power"])], "Running"))
		"contract":
			var heavy = stations["heavy"]
			rows.append({"key": "hdr:wc", "header": true, "title": "THE WAR CONTRACT",
				"desc": "The high command needs %d heavy artillery shells for the final offensive." % Data.FINAL_GOAL})
			var prog := "%s / %d heavy shells delivered" % [fmt(minf(heavy.made, Data.FINAL_GOAL)), Data.FINAL_GOAL]
			if won:
				prog += "  -  CONTRACT COMPLETE"
			rows.append({"key": "info:prog", "title": prog, "desc": "Heavy artillery shells need the gantry crane and the railway siding."})
			rows.append({"key": "hdr:stats", "header": true, "title": "WORKS RECORD", "desc": ""})
			rows.append({"key": "info:time", "title": "Time on the job: %s" % _fmt_time(play_time), "desc": ""})
			rows.append({"key": "info:earned", "title": "Total earned: %s cr" % fmt(total_earned), "desc": ""})
			for p in Data.PRODUCTS:
				var st = stations[p["id"]]
				if st.unlocked:
					rows.append({"key": "info:m_" + p["id"], "title": "%s: %s %s" % [p["name"], fmt(st.made), p["unit"]], "desc": ""})
	return rows


func lock_text(st) -> String:
	var t := "%s\nUNDER TARPAULIN\nContract: %s cr" % [String(st.d["name"]).to_upper(), fmt(float(st.d["unlock"]))]
	var miss := missing_reqs(st)
	if miss.size() > 0:
		t += "\nNeeds: " + ", ".join(miss)
	return t


# ------------------------------------------------------------------ loop & input

func _process(delta: float) -> void:
	play_time += delta
	for st in stations.values():
		st.tick(delta)
	_rate_t += delta
	if _rate_t >= 1.0:
		var sample := _earn_bucket / _rate_t
		rate = sample if rate == 0.0 else lerpf(rate, sample, 0.35)
		_earn_bucket = 0.0
		_rate_t = 0.0
	_label_t -= delta
	if _label_t <= 0.0:
		_label_t = 0.25
		for st in stations.values():
			st.update_label()
	_handle_interaction(delta)
	_check_final()
	_save_t += delta
	if _save_t >= 20.0:
		_save_t = 0.0
		save_game()


func _handle_interaction(delta: float) -> void:
	player.enabled = not ui.any_open()
	if ui.any_open() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		ui.set_prompt("")
		return
	var target = player.get_target()
	var kind := ""
	if target != null and target.has_meta("kind"):
		kind = target.get_meta("kind")
	var prompt := ""
	match kind:
		"step":
			prompt = target.get_meta("station").prompt_for(target.get_meta("step"))
		"unlock":
			var st = target.get_meta("station")
			var o := offer("unlock:" + st.pid)
			if o["reason"] != "":
				prompt = "%s - %s" % [st.d["name"], o["reason"]]
			else:
				prompt = "[E] Sign the %s contract  (%s cr)" % [st.d["name"], fmt(o["cost"])]
		"ledger":
			prompt = "[E] Open the ledger"
	ui.set_prompt(prompt)
	if Input.is_action_just_pressed("interact"):
		_hold_t = 0.35
		_interact(target, kind)
	elif Input.is_action_pressed("interact") and kind == "step":
		_hold_t -= delta
		if _hold_t <= 0.0:
			_hold_t = 0.16
			_interact(target, kind, true)


func _interact(target, kind: String, repeat: bool = false) -> void:
	match kind:
		"step":
			var msg: String = target.get_meta("station").manual_click(target.get_meta("step"))
			if msg != "" and not repeat:
				ui.flash_prompt(msg)
		"unlock":
			buy("unlock:" + target.get_meta("station").pid)
		"ledger":
			ui.open_ledger()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ledger") and not event.is_echo():
		if ui.dialogs.size() == 0:
			ui.toggle_ledger()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu") and not event.is_echo():
		if not ui.close_top():
			ui.open_menu()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not ui.any_open():
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func update_mouse() -> void:
	if _debug_dir != "":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ui.any_open() else Input.MOUSE_MODE_CAPTURED


func _check_final() -> void:
	if won or stations["heavy"].made < Data.FINAL_GOAL:
		return
	won = true
	save_game()
	ui.show_dialog("THE WAR CONTRACT IS COMPLETE",
		"The last heavy shell rolls onto the railway wagon. A ruined, rain-soaked shed has become one of the finest ammunition works in the country.\n\nTime on the job: %s\nTotal earned: %s cr\n\nThe lines will keep running if you want to carry on." % [_fmt_time(play_time), fmt(total_earned)],
		[["Carry on", Callable()]], 720.0)


func _show_intro() -> void:
	seen_intro = true
	ui.show_dialog("AMMUNITION WORKS No. 7",
		"The ministry has requisitioned a bomb-damaged warehouse and handed you the keys. The roof leaks, the lamps are dead and there is one working bench.\n\nThe front needs ammunition. Pack pistol cartridges by hand, earn contract money, then buy machines, repairs and power until this ruin is turning out tank and artillery shells.\n\nWASD - move    Mouse - look    Shift - run\nE / Left click - work the highlighted step (hold to repeat)\nTab - open the ledger    Esc - menu",
		[["Get to work", Callable()]], 760.0)


# ------------------------------------------------------------------ formatting

func fmt(v: float) -> String:
	var a := absf(v)
	if a < 1000.0:
		if a < 10.0 and absf(v - roundf(v)) > 0.05:
			return "%.1f" % v
		return str(int(roundf(v)))
	var suffixes := ["K", "M", "B", "T", "Qa", "Qi", "Sx"]
	var i := -1
	while a >= 1000.0 and i < suffixes.size() - 1:
		a /= 1000.0
		i += 1
	var num := ""
	if a < 10.0:
		num = "%.2f" % a
	elif a < 100.0:
		num = "%.1f" % a
	else:
		num = "%.0f" % a
	return ("-" if v < 0 else "") + num + suffixes[i]


func fmt_floor(v: float) -> String:
	if v < 1000.0:
		return str(int(floorf(v)))
	return fmt(v)


func _fmt_time(t: float) -> String:
	var s := int(t)
	return "%dh %02dm %02ds" % [s / 3600, (s / 60) % 60, s % 60]


# ------------------------------------------------------------------ saving

func save_game() -> void:
	if _no_save:
		return
	var data := {
		"v": 1, "money": money, "total": total_earned, "owned": owned.keys(), "time": play_time,
		"won": won, "intro": seen_intro, "ts": Time.get_unix_time_from_system(), "stations": {},
	}
	for id in stations:
		var st = stations[id]
		data["stations"][id] = {"u": st.unlocked, "a": st.auto, "s": st.speed, "l": st.lines, "m": st.made}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


## Loads the save. Returns money earned offline.
func load_game() -> float:
	if not FileAccess.file_exists(save_path):
		return 0.0
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(data) != TYPE_DICTIONARY:
		return 0.0
	money = float(data.get("money", 0.0))
	total_earned = float(data.get("total", 0.0))
	play_time = float(data.get("time", 0.0))
	won = bool(data.get("won", false))
	seen_intro = bool(data.get("intro", false))
	owned.clear()
	for id in data.get("owned", []):
		owned[String(id)] = true
	var sd: Dictionary = data.get("stations", {})
	for id in sd:
		if not stations.has(id):
			continue
		var st = stations[id]
		var s: Dictionary = sd[id]
		st.unlocked = bool(s.get("u", false)) or id == "pistol"
		st.auto = clampi(int(s.get("a", 0)), 0, 4)
		st.speed = int(s.get("s", 0))
		st.lines = maxi(1, int(s.get("l", 1)))
		st.made = float(s.get("m", 0.0))
	# Offline production
	var away := clampf(Time.get_unix_time_from_system() - float(data.get("ts", 0.0)), 0.0, Data.OFFLINE_CAP)
	var gained := 0.0
	if away > 60.0:
		gained = auto_income() * away * Data.OFFLINE_RATE
		for st in stations.values():
			st.made += st.auto_rate() * away * Data.OFFLINE_RATE
		earn(gained)
		_earn_bucket = 0.0
	return gained


func reset_game() -> void:
	_no_save = true
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	get_tree().reload_current_scene()


func quit_game() -> void:
	save_game()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# ------------------------------------------------------------------ debug screenshots
# Run with:  Godot --path . -- --shots=C:/some/folder

func _savetest() -> void:
	money = 1234.5
	owned["roof"] = true
	stations["rifle"].unlocked = true
	stations["rifle"].auto = 4
	stations["rifle"].lines = 2
	stations["rifle"].made = 77.0
	save_game()
	money = 0.0
	owned.clear()
	stations["rifle"].unlocked = false
	stations["rifle"].auto = 0
	var off := load_game()
	print("SAVETEST money=%s owned=%s rifle u=%s a=%d l=%d m=%s offline=%s" % [money, owned.keys(), stations["rifle"].unlocked, stations["rifle"].auto, stations["rifle"].lines, stations["rifle"].made, off])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	get_tree().quit()


func _debug_shots() -> void:
	ui.toast("Debug screenshot run")
	await get_tree().create_timer(1.5).timeout
	await _shot("01_start")
	player.look_from(Vector3(10, 0, 11), Vector3(-6, 1.5, -6))
	await _shot("02_decrepit_overview")
	# Self-test: work one full cartridge through the ray-cast, like a player would.
	var pistol = stations["pistol"]
	for rep in 2:
		for i in 4:
			player.look_from(SPAWN + Vector3(0, 0, -1.0), pistol.global_position + Vector3(StationScript.SLOT_X[i], 1.1, 0))
			await get_tree().physics_frame
			await get_tree().physics_frame
			var t = player.get_target()
			var k: String = t.get_meta("kind") if t != null and t.has_meta("kind") else "none"
			print("TEST slot %d -> %s step=%s" % [i, k, str(t.get_meta("step")) if k == "step" else "-"])
			if k == "step":
				_interact(t, k)
	print("TEST after 2 manual cycles: made=%s money=%s" % [pistol.made, money])
	money = 200.0
	buy("repair:rubble")
	buy("auto:pistol")
	buy("power:diesel")
	print("TEST owned=%s auto=%d money=%s power=%d/%d" % [owned.keys(), pistol.auto, money, power_used(), power_cap()])
	print("TEST fps=%s" % Engine.get_frames_per_second())
	owned.erase("rubble")
	owned.erase("diesel")
	refresh_all()
	stations["pistol"].refresh()
	player.look_from(SPAWN + Vector3(1.2, 0, 0.6), Vector3(-14, 1.0, -9))
	await _shot("03_pistol_bench")
	money = 1.0e9
	for st in stations.values():
		st.unlocked = true
		st.auto = 4
		st.lines = 3
		st.speed = 2
		st.made = 140.0
	for r in Data.REPAIRS:
		owned[r["id"]] = true
	for g in Data.POWER:
		owned[g["id"]] = true
	refresh_all()
	await get_tree().create_timer(1.0).timeout
	player.look_from(Vector3(10, 0, 11), Vector3(-6, 1.5, -6))
	await _shot("04_repaired_overview")
	player.look_from(Vector3(6.5, 0, 3.8), Vector3(10, 1.2, 0))
	await _shot("05_heavy_bench")
	player.look_from(Vector3(-16, 0, 6), Vector3(10, 2, -6))
	await _shot("06_repaired_other_side")
	print("TEST fps (repaired)=%s" % Engine.get_frames_per_second())
	player.look_from(Vector3(24, 0, -9), Vector3(32, 1.5, 3))
	await _shot("07_yard")
	ui.open_ledger("production")
	await get_tree().create_timer(0.5).timeout
	await _shot("08_ledger")
	ui.close_ledger()
	get_tree().quit()


func _shot(shot_name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_debug_dir.path_join(shot_name + ".png"))
