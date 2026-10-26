class_name HUD
extends Control
## In-game HUD: score, ball selector, aim area, pause and result screens.

signal aim_event(event: InputEvent)
signal type_selected(type_id: String)
signal pause_toggled(is_paused: bool)
signal restart_pressed
signal menu_pressed
signal levels_pressed
signal next_pressed

var aim_area: Control
var score_label: Label
var balls_label: Label
var progress: ProgressBar
var progress_label: Label
var power_bar: ProgressBar
var banner: PanelContainer
var banner_label: Label
var hint_panel: PanelContainer
var hint_label: Label
var type_row: HBoxContainer
var pause_overlay: Control
var result_overlay: Control
var _score_shown := 0.0
var _score_target := 0
var _paused := false
var _ball_buttons: Dictionary = {}

func setup(level: Dictionary, world_name: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ins := UIKit.safe_insets(self)

	aim_area = Control.new()
	aim_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aim_area.mouse_filter = Control.MOUSE_FILTER_STOP
	aim_area.gui_input.connect(func(e: InputEvent): aim_event.emit(e))
	add_child(aim_area)

	# ---- top bar
	var top := UIKit.margin(24, int(ins.x) + 20, 24, 0)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(top)
	var col := UIKit.vbox(12)
	top.add_child(col)
	var row := UIKit.hbox(16)
	col.add_child(row)
	var pause_btn := UIKit.button("II", Color("#ff9f1c"), Vector2(104, 104), 48)
	pause_btn.pressed.connect(toggle_pause)
	row.add_child(pause_btn)
	var info := UIKit.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UIKit.label("%s %d" % [Loc.t("level"), int(level["id"])], 44))
	info.add_child(UIKit.label(world_name, 30, Color("#d9e7ff")))
	score_label = UIKit.label("0", 56, Color("#ffd23f"))
	score_label.custom_minimum_size = Vector2(260, 0)
	row.add_child(score_label)
	var prow := UIKit.hbox(12)
	col.add_child(prow)
	progress = UIKit.bar(Color("#4dff88"), 26)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(progress)
	progress_label = UIKit.label("0/0", 30)
	progress_label.custom_minimum_size = Vector2(150, 0)
	prow.add_child(progress_label)

	# ---- banner (goal text)
	var bwrap := UIKit.margin(60, int(ins.x) + 300, 60, 0)
	bwrap.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(bwrap)
	banner = UIKit.panel(Color(0, 0, 0, 0.6))
	banner.modulate.a = 0.0
	bwrap.add_child(banner)
	banner_label = UIKit.label("", 40)
	banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_label.custom_minimum_size = Vector2(800, 0)
	banner.add_child(banner_label)

	# ---- bottom area
	var bot := UIKit.margin(24, 0, 24, int(ins.y) + 24)
	bot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bot)
	var bcol := UIKit.vbox(14)
	bot.add_child(bcol)
	hint_panel = UIKit.panel(Color(0, 0, 0, 0.55), 28)
	hint_panel.visible = false
	hint_label = UIKit.label("", 34)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(880, 0)
	hint_panel.add_child(hint_label)
	bcol.add_child(hint_panel)
	power_bar = UIKit.bar(Color("#ff5c3a"), 24)
	power_bar.modulate.a = 0.0
	bcol.add_child(power_bar)
	balls_label = UIKit.label("", 34)
	bcol.add_child(balls_label)
	type_row = UIKit.hbox(14)
	type_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bcol.add_child(type_row)

	_build_pause()
	_build_result()

func _process(delta: float) -> void:
	if int(_score_shown) != _score_target:
		_score_shown = move_toward(_score_shown, float(_score_target), maxf(40.0, absf(_score_target - _score_shown) * 6.0) * delta)
		score_label.text = str(int(_score_shown))

# ------------------------------------------------------------ public API
func set_score(s: int) -> void:
	_score_target = s

func set_progress(done: int, need: int) -> void:
	progress.value = clampf(float(done) / float(maxi(1, need)), 0.0, 1.0)
	progress_label.text = "%d/%d" % [mini(done, need), need]

func set_power(p: float) -> void:
	power_bar.value = p
	power_bar.modulate.a = 1.0 if p > 0.0 else 0.0

func set_balls(ammo: Dictionary, selected: String) -> void:
	for c in type_row.get_children():
		c.queue_free()
	_ball_buttons.clear()
	var total := 0
	for t in GameState.BALL_ORDER:
		var cnt := int(ammo.get(t, 0))
		total += cnt
		if cnt <= 0:
			continue
		var def: Dictionary = GameState.ball_types[t]
		var base := Color(str(def["color"]))
		var btn := UIKit.button("%s\n×%d" % [Loc.t("ball_" + str(t)), cnt], base.darkened(0.15) if t != selected else base.lightened(0.1), Vector2(176, 132), 28)
		if t == selected:
			btn.add_theme_stylebox_override("normal", _selected_style(base))
		var tid: String = t
		btn.pressed.connect(func(): type_selected.emit(tid))
		type_row.add_child(btn)
		_ball_buttons[t] = btn
	balls_label.text = "%s: %d" % [Loc.t("balls_left"), total]

func _selected_style(base: Color) -> StyleBoxFlat:
	var sb := UIKit.style(base.lightened(0.1))
	sb.border_color = Color.WHITE
	sb.set_border_width_all(6)
	return sb

func show_banner(text: String, seconds: float) -> void:
	banner_label.text = text
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.4)
	tw.tween_interval(seconds)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)

func show_hint(text: String) -> void:
	hint_label.text = text
	hint_panel.visible = true

func hide_hint() -> void:
	hint_panel.visible = false

func toggle_pause() -> void:
	if result_overlay.visible:
		return
	_paused = not _paused
	pause_overlay.visible = _paused
	pause_toggled.emit(_paused)

# ------------------------------------------------------------ overlays
func _overlay_base() -> Control:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0.02, 0.08, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(dim)
	add_child(o)
	return o

func _build_pause() -> void:
	pause_overlay = _overlay_base()
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(cc)
	var p := UIKit.panel(Color("#1b2a5a"), 40)
	cc.add_child(p)
	var v := UIKit.vbox(22)
	p.add_child(v)
	v.add_child(UIKit.label(Loc.t("pause"), 64, Color("#ffd23f")))
	var b1 := UIKit.button(Loc.t("resume"), Color("#2ec27e"), Vector2(560, 120))
	b1.pressed.connect(toggle_pause)
	v.add_child(b1)
	var b2 := UIKit.button(Loc.t("restart"), Color("#ff9f1c"), Vector2(560, 120))
	b2.pressed.connect(func(): restart_pressed.emit())
	v.add_child(b2)
	var be := UIKit.button(Loc.t("change_env"), Color("#1f8fbf"), Vector2(560, 120))
	be.pressed.connect(func():
		GameState.set_setting("tod", (int(GameState.setting("tod")) + 1) % 3)
		restart_pressed.emit())
	v.add_child(be)
	var b3 := UIKit.button(Loc.t("to_menu"), Color("#5b6dff"), Vector2(560, 120))
	b3.pressed.connect(func(): menu_pressed.emit())
	v.add_child(b3)

func _build_result() -> void:
	result_overlay = _overlay_base()

func show_result(won: bool, info: Dictionary) -> void:
	for c in result_overlay.get_children():
		if c is CenterContainer:
			c.queue_free()
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_overlay.add_child(cc)
	var p := UIKit.panel(Color("#1b2a5a") if won else Color("#3a1b2a"), 44)
	cc.add_child(p)
	var v := UIKit.vbox(18)
	p.add_child(v)
	v.add_child(UIKit.label(Loc.t("win_title") if won else Loc.t("lose_title"), 78, Color("#4dff88") if won else Color("#ff6b6b")))
	if won:
		var stars := int(info["stars"])
		var srow := UIKit.hbox(12)
		srow.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(srow)
		for i in 3:
			var sl := UIKit.label("★", 130, Color("#ffd23f") if i < stars else Color(1, 1, 1, 0.18))
			sl.pivot_offset = Vector2(60, 70)
			sl.scale = Vector2.ZERO
			srow.add_child(sl)
			var tw := create_tween()
			tw.tween_interval(0.4 + i * 0.35)
			tw.tween_property(sl, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if i < stars:
				tw.tween_callback(func(): GameState.audio.play("star"))
		v.add_child(UIKit.label("%s: %d" % [Loc.t("score"), int(info["score"])], 46, Color("#ffd23f")))
		if bool(info["new_best"]):
			v.add_child(UIKit.label(Loc.t("new_best"), 38, Color("#4dff88")))
		else:
			v.add_child(UIKit.label("%s: %d" % [Loc.t("best"), int(info["best"])], 34))
		v.add_child(UIKit.label("%s: %d" % [Loc.t("balls_used"), int(info["balls_used"])], 34))
		v.add_child(UIKit.label("%s: +%d" % [Loc.t("coins_earned"), int(info["coins"])], 38, Color("#ffd23f")))
		if bool(info["has_next"]):
			var bn := UIKit.button(Loc.t("next_level"), Color("#2ec27e"), Vector2(620, 124))
			bn.pressed.connect(func(): next_pressed.emit())
			v.add_child(bn)
	else:
		v.add_child(UIKit.label(str(info["cause"]), 42))
	var br := UIKit.button(Loc.t("retry"), Color("#ff9f1c"), Vector2(620, 112))
	br.pressed.connect(func(): restart_pressed.emit())
	v.add_child(br)
	var bl := UIKit.button(Loc.t("to_levels"), Color("#5b6dff"), Vector2(620, 112))
	bl.pressed.connect(func(): levels_pressed.emit())
	v.add_child(bl)
	result_overlay.visible = true
	p.scale = Vector2(0.6, 0.6)
	p.pivot_offset = Vector2(310, 400)
	var tw2 := create_tween()
	tw2.tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
