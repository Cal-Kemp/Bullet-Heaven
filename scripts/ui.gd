extends CanvasLayer
## HUD, ledger (shop), menus and pop-up dialogs. Built entirely in code.

const TEXT := Color(0.93, 0.89, 0.76)
const DIM := Color(0.7, 0.67, 0.56)
const AMBER := Color(0.98, 0.72, 0.25)
const RED := Color(0.9, 0.4, 0.3)
const TABS := [["production", "Production"], ["warehouse", "Warehouse"], ["power", "Power"], ["contract", "War Contract"]]

var game
var root: Control
var money_label: Label
var rate_label: Label
var power_label: Label
var bonus_label: Label
var prompt_label: Label
var crosshair: Label
var toast_box: VBoxContainer
var ledger: PanelContainer
var ledger_money: Label
var tabs: TabContainer
var tab_lists := {}
var tab_keys := {}
var rows := {}
var dialogs := []
var menu_open := false
var _refresh_t := 0.0
var _flash_t := 0.0


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_hud()
	_build_ledger()


# ------------------------------------------------------------------ theme

func _make_theme() -> Theme:
	var th := Theme.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Courier New", "Courier", "Liberation Mono", "monospace"])
	f.font_weight = 700
	th.default_font = f
	th.default_font_size = 17
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.11, 0.12, 0.09, 0.95)
	panel.border_color = Color(0.55, 0.5, 0.33)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(3)
	panel.set_content_margin_all(14)
	th.set_stylebox("panel", "PanelContainer", panel)
	var hud: StyleBoxFlat = panel.duplicate()
	hud.bg_color = Color(0.08, 0.09, 0.07, 0.75)
	hud.set_content_margin_all(10)
	th.set_type_variation("Hud", "PanelContainer")
	th.set_stylebox("panel", "Hud", hud)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := StyleBoxFlat.new()
		b.set_corner_radius_all(3)
		b.set_border_width_all(2)
		b.set_content_margin_all(8)
		match st:
			"normal":
				b.bg_color = Color(0.3, 0.36, 0.22)
				b.border_color = Color(0.55, 0.6, 0.38)
			"hover":
				b.bg_color = Color(0.38, 0.45, 0.27)
				b.border_color = Color(0.75, 0.75, 0.45)
			"pressed":
				b.bg_color = Color(0.22, 0.27, 0.16)
				b.border_color = Color(0.75, 0.75, 0.45)
			"disabled":
				b.bg_color = Color(0.18, 0.18, 0.16)
				b.border_color = Color(0.3, 0.3, 0.26)
			"focus":
				b.draw_center = false
				b.border_color = Color(0, 0, 0, 0)
		th.set_stylebox(st, "Button", b)
	th.set_color("font_color", "Label", TEXT)
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", Color(1, 1, 0.9))
	th.set_color("font_disabled_color", "Button", Color(0.5, 0.48, 0.42))
	th.set_color("font_selected_color", "TabContainer", AMBER)
	th.set_color("font_unselected_color", "TabContainer", DIM)
	th.set_font_size("font_size", "TabContainer", 19)
	return th


func _label(text: String, size: int = 17, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	var hud := PanelContainer.new()
	hud.theme_type_variation = "Hud"
	hud.position = Vector2(14, 14)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var v := VBoxContainer.new()
	hud.add_child(v)
	money_label = _label("0 cr", 30, AMBER)
	rate_label = _label("", 16)
	power_label = _label("", 16)
	bonus_label = _label("", 16, DIM)
	for l in [money_label, rate_label, power_label, bonus_label]:
		v.add_child(l)

	var help := _label("[Tab] Ledger   [E / Click] Work (hold)   [Esc] Menu", 15, DIM)
	help.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	help.position.x -= 14
	help.position.y = 14
	root.add_child(help)

	crosshair = _label("+", 26, Color(1, 1, 1, 0.8))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(crosshair)

	prompt_label = _label("", 20)
	prompt_label.anchor_left = 0.0
	prompt_label.anchor_right = 1.0
	prompt_label.anchor_top = 0.5
	prompt_label.anchor_bottom = 0.5
	prompt_label.offset_top = 34
	prompt_label.offset_bottom = 70
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_constant_override("outline_size", 6)
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	root.add_child(prompt_label)

	toast_box = VBoxContainer.new()
	toast_box.anchor_top = 1.0
	toast_box.anchor_bottom = 1.0
	toast_box.offset_left = 16
	toast_box.offset_top = -260
	toast_box.offset_bottom = -16
	toast_box.offset_right = 700
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)


func set_prompt(text: String) -> void:
	if _flash_t > 0.0:
		return
	prompt_label.text = text
	prompt_label.add_theme_color_override("font_color", TEXT)


func flash_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.add_theme_color_override("font_color", RED)
	_flash_t = 1.0


func toast(text: String, col: Color = TEXT) -> void:
	var l := _label(text, 18, col)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast_box.add_child(l)
	while toast_box.get_child_count() > 6:
		toast_box.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ ledger

func _build_ledger() -> void:
	ledger = PanelContainer.new()
	ledger.anchor_left = 0.1
	ledger.anchor_right = 0.9
	ledger.anchor_top = 0.07
	ledger.anchor_bottom = 0.93
	ledger.visible = false
	root.add_child(ledger)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	ledger.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := _label("WAREHOUSE LEDGER", 26, AMBER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	ledger_money = _label("", 22, TEXT)
	top.add_child(ledger_money)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 20
	top.add_child(spacer)
	var close := Button.new()
	close.text = "Close [Tab]"
	close.pressed.connect(close_ledger)
	top.add_child(close)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	for t in TABS:
		var sc := ScrollContainer.new()
		sc.name = t[1]
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(sc)
		var m := MarginContainer.new()
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.add_theme_constant_override("margin_left", 8)
		m.add_theme_constant_override("margin_right", 16)
		m.add_theme_constant_override("margin_top", 8)
		sc.add_child(m)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 8)
		m.add_child(list)
		tab_lists[t[0]] = list
		tab_keys[t[0]] = []


func open_ledger(tab: String = "") -> void:
	if dialogs.size() > 0 or menu_open:
		return
	ledger.visible = true
	if tab != "":
		for i in TABS.size():
			if TABS[i][0] == tab:
				tabs.current_tab = i
	refresh_ledger(true)
	game.update_mouse()


func close_ledger() -> void:
	ledger.visible = false
	game.update_mouse()


func toggle_ledger() -> void:
	if ledger.visible:
		close_ledger()
	else:
		open_ledger()


func refresh_ledger(force: bool = false) -> void:
	ledger_money.text = "Funds: %s cr" % game.fmt_floor(game.money)
	for t in TABS:
		var id: String = t[0]
		var data: Array = game.ledger_rows(id)
		var keys := []
		for r in data:
			keys.append(r["key"])
		if force or keys != tab_keys[id]:
			_rebuild_tab(id, data)
			tab_keys[id] = keys
		else:
			for r in data:
				_update_row(r)


func _rebuild_tab(id: String, data: Array) -> void:
	var list: VBoxContainer = tab_lists[id]
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	for r in data:
		var key: String = r["key"]
		var w := {}
		if r.get("header", false):
			if list.get_child_count() > 0:
				var sep := HSeparator.new()
				list.add_child(sep)
			var hv := VBoxContainer.new()
			w["title"] = _label("", 21, AMBER)
			w["desc"] = _label("", 15, DIM)
			hv.add_child(w["title"])
			hv.add_child(w["desc"])
			list.add_child(hv)
		else:
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 14)
			var tv := VBoxContainer.new()
			tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			w["title"] = _label("", 18)
			w["desc"] = _label("", 15, DIM)
			w["desc"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tv.add_child(w["title"])
			tv.add_child(w["desc"])
			h.add_child(tv)
			if r.has("btn"):
				var b := Button.new()
				b.custom_minimum_size = Vector2(230, 46)
				b.pressed.connect(Callable(game, "buy").bind(key))
				b.focus_mode = Control.FOCUS_NONE
				h.add_child(b)
				w["button"] = b
			list.add_child(h)
		rows[key] = w
		_update_row(r)


func _update_row(r: Dictionary) -> void:
	var w = rows.get(r["key"])
	if w == null:
		return
	w["title"].text = r.get("title", "")
	w["desc"].text = r.get("desc", "")
	w["desc"].visible = w["desc"].text != ""
	if w.has("button"):
		w["button"].text = r.get("btn", "")
		w["button"].disabled = not r.get("enabled", false)


# ------------------------------------------------------------------ dialogs

## buttons: Array of [text, Callable]
func show_dialog(title: String, body: String, buttons: Array, width: float = 640.0) -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(cc)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(_label(title, 26, AMBER))
	if body != "":
		var b := _label(body, 17)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = width - 40
		v.add_child(b)
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_theme_constant_override("separation", 12)
	v.add_child(bh)
	for bd in buttons:
		var btn := Button.new()
		btn.text = bd[0]
		btn.custom_minimum_size = Vector2(170, 44)
		var cb: Callable = bd[1]
		btn.pressed.connect(func():
			close_dialog(holder)
			if cb.is_valid():
				cb.call()
		)
		bh.add_child(btn)
	dialogs.append(holder)
	game.update_mouse()


func close_dialog(holder: Control) -> void:
	dialogs.erase(holder)
	holder.queue_free()
	game.update_mouse()


func close_top() -> bool:
	if dialogs.size() > 0:
		close_dialog(dialogs.back())
		menu_open = false
		return true
	if ledger.visible:
		close_ledger()
		return true
	return false


func open_menu() -> void:
	if ledger.visible:
		close_ledger()
	menu_open = true
	show_dialog("PAUSED", "The works keep running while this menu is open.", [
		["Resume", _menu_resume],
		["Save game", _menu_save],
		["Reset progress", _confirm_reset],
		["Quit", _menu_quit],
	], 760.0)


func _menu_resume() -> void:
	menu_open = false


func _menu_save() -> void:
	menu_open = false
	game.save_game()
	toast("Game saved.")


func _menu_quit() -> void:
	game.quit_game()


func _confirm_reset() -> void:
	menu_open = false
	show_dialog("Reset progress?", "This wipes your save and starts again in the ruined warehouse. It cannot be undone.", [
		["Cancel", Callable()],
		["Reset", Callable(game, "reset_game")],
	])


func any_open() -> bool:
	return ledger.visible or dialogs.size() > 0


# ------------------------------------------------------------------ update

func _process(delta: float) -> void:
	if game == null:
		return
	_flash_t = maxf(0.0, _flash_t - delta)
	money_label.text = "%s cr" % game.fmt_floor(game.money)
	rate_label.text = "Earning %s cr/s" % game.fmt(game.rate)
	power_label.text = "Power: %d / %d" % [game.power_used(), game.power_cap()]
	power_label.add_theme_color_override("font_color", RED if game.power_used() >= game.power_cap() else TEXT)
	bonus_label.text = "Works output bonus: +%d%%" % roundi((game.mult() - 1.0) * 100.0)
	crosshair.visible = not any_open()
	prompt_label.visible = not any_open()
	if ledger.visible:
		_refresh_t -= delta
		if _refresh_t <= 0.0:
			_refresh_t = 0.2
			refresh_ledger()
