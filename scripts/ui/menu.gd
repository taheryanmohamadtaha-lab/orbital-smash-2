extends Control
## Main menu, level select, shop and settings. All UI is built in code.

var _content: Control
var _coin_label: Label
var _screen := "main"
var _shop_tab := "colors"
var _reset_armed := false

func _ready() -> void:
	GameState.audio.play_music(1)
	var bg := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color("#1b1450"))
	g.set_color(1, Color("#3d9bff"))
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for i in 7:
		var c := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.07)
		sb.set_corner_radius_all(200)
		c.add_theme_stylebox_override("panel", sb)
		var s := randf_range(120.0, 320.0)
		c.size = Vector2(s, s)
		c.position = Vector2(randf_range(0, 900), randf_range(0, 1700))
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		var tw := create_tween().set_loops()
		tw.tween_property(c, "position:y", c.position.y - 160.0, randf_range(4.0, 8.0)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(c, "position:y", c.position.y, randf_range(4.0, 8.0)).set_trans(Tween.TRANS_SINE)
	var ins := UIKit.safe_insets(self)
	var m := UIKit.margin(36, int(ins.x) + 36, 36, int(ins.y) + 36)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(_content)
	GameState.coins_changed.connect(func(_t: int): _update_coins())
	var start := GameState.start_screen
	GameState.start_screen = "main"
	_show(start)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _screen == "main":
			get_tree().quit()
		else:
			_show("main")

func _update_coins() -> void:
	if is_instance_valid(_coin_label):
		_coin_label.text = "%s: %d" % [Loc.t("coins"), GameState.coins()]

func _clear() -> VBoxContainer:
	for c in _content.get_children():
		c.queue_free()
	var v := UIKit.vbox(20)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_child(v)
	return v

func _header(v: VBoxContainer, title: String, with_back: bool) -> void:
	var row := UIKit.hbox(16)
	v.add_child(row)
	if with_back:
		var b := UIKit.button(Loc.t("back"), Color("#5b6dff"), Vector2(220, 96), 38)
		b.pressed.connect(func(): _show("main"))
		row.add_child(b)
	var t := UIKit.label(title, 56, Color("#ffd23f"))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	_coin_label = UIKit.label("", 38, Color("#ffd23f"))
	row.add_child(_coin_label)
	_update_coins()

func _show(screen: String) -> void:
	_screen = screen
	_reset_armed = false
	match screen:
		"levels":
			_levels()
		"shop":
			_shop()
		"settings":
			_settings()
		_:
			_main()

func _start_level(id: int) -> void:
	GameState.current_level_id = id
	get_tree().change_scene_to_file("res://scenes/gameplay/game.tscn")

# ---------------------------------------------------------------- main
func _main() -> void:
	var v := _clear()
	var top := UIKit.hbox()
	top.alignment = BoxContainer.ALIGNMENT_END
	_coin_label = UIKit.label("", 40, Color("#ffd23f"))
	top.add_child(_coin_label)
	v.add_child(top)
	_update_coins()
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 200)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var logo := UIKit.label("ORBITAL\nSMASH", 150, Color("#ffd23f"))
	logo.pivot_offset = Vector2(500, 150)
	v.add_child(logo)
	var tw := create_tween().set_loops()
	tw.tween_property(logo, "scale", Vector2(1.05, 1.05), 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE)
	v.add_child(UIKit.label(Loc.t("subtitle"), 48, Color("#d9e7ff")))
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 120)
	sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp2)
	var unlocked := int(GameState.data["unlocked_level"])
	var play_text := Loc.t("play") if unlocked <= 1 and GameState.total_stars() == 0 else "%s (%d)" % [Loc.t("continue_game"), unlocked]
	var bp := UIKit.button(play_text, Color("#2ec27e"), Vector2(0, 140), 56)
	bp.pressed.connect(func(): _start_level(unlocked))
	v.add_child(bp)
	var bl := UIKit.button(Loc.t("levels"), Color("#ff9f1c"), Vector2(0, 120), 46)
	bl.pressed.connect(func(): _show("levels"))
	v.add_child(bl)
	var bs := UIKit.button(Loc.t("shop"), Color("#a23bff"), Vector2(0, 120), 46)
	bs.pressed.connect(func(): _show("shop"))
	v.add_child(bs)
	var bt := UIKit.button(Loc.t("settings"), Color("#5b6dff"), Vector2(0, 120), 46)
	bt.pressed.connect(func(): _show("settings"))
	v.add_child(bt)
	v.add_child(UIKit.label("★ %d / %d" % [GameState.total_stars(), GameState.level_count() * 3], 36))
	v.add_child(UIKit.label(Loc.t("credit"), 34, Color("#ffd23f")))

# ---------------------------------------------------------------- levels
func _levels() -> void:
	var v := _clear()
	_header(v, Loc.t("levels"), true)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := UIKit.vbox(18)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(list)
	for w in range(1, 6):
		var first := (w - 1) * GameState.LEVELS_PER_WORLD + 1
		list.add_child(UIKit.label("%s %d — %s" % [Loc.t("world"), w, GameState.world_name(w)], 42, Color("#ffd23f")))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 16)
		grid.mouse_filter = Control.MOUSE_FILTER_PASS
		list.add_child(grid)
		for id in range(first, first + GameState.LEVELS_PER_WORLD):
			if id > GameState.level_count():
				break
			var rec := GameState.level_record(id)
			var ok := GameState.is_level_unlocked(id)
			var txt := "%d\n%s" % [id, UIKit.star_text(int(rec["stars"]))] if ok else "%d\n%s" % [id, Loc.t("locked")]
			var b := UIKit.button(txt, Color(str((GameState.worlds[w - 1] as Dictionary)["color"])), Vector2(300, 170), 40)
			b.disabled = not ok
			var lid := id
			b.pressed.connect(func(): _start_level(lid))
			grid.add_child(b)

# ---------------------------------------------------------------- shop
func _shop() -> void:
	var v := _clear()
	_header(v, Loc.t("shop"), true)
	var tabs := UIKit.hbox(16)
	v.add_child(tabs)
	for t in ["colors", "trails"]:
		var tn: String = t
		var b := UIKit.button(Loc.t("tab_" + tn), Color("#a23bff") if _shop_tab == tn else Color("#3b3f7a"), Vector2(0, 100), 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			_shop_tab = tn
			_shop())
		tabs.add_child(b)
	var items: Array = GameState.shop_colors if _shop_tab == "colors" else GameState.shop_trails
	var key := "ball_color" if _shop_tab == "colors" else "ball_trail"
	for it in items:
		var item: Dictionary = it
		var id := str(item["id"])
		var row := UIKit.panel(Color(0, 0, 0, 0.35), 28)
		v.add_child(row)
		var h := UIKit.hbox(16)
		row.add_child(h)
		var sw := ColorRect.new()
		sw.color = Color(str(item["color"]))
		sw.custom_minimum_size = Vector2(80, 80)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(sw)
		var nm := UIKit.label(str(item["name_fa"]) if Loc.lang == "fa" else str(item["name_en"]), 40)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		var price := int(item["price"])
		var owned := GameState.owned(_shop_tab, id)
		var btn: Button
		if owned and str(GameState.data[key]) == id:
			btn = UIKit.button(Loc.t("equipped"), Color("#2ec27e"), Vector2(260, 90), 34)
			btn.disabled = true
		elif owned:
			btn = UIKit.button(Loc.t("equip"), Color("#5b6dff"), Vector2(260, 90), 34)
			btn.pressed.connect(func():
				GameState.equip(_shop_tab, id)
				_shop())
		else:
			btn = UIKit.button("%s %d" % [Loc.t("buy"), price], Color("#ff9f1c"), Vector2(260, 90), 34)
			btn.disabled = GameState.coins() < price
			btn.pressed.connect(func():
				if GameState.buy(_shop_tab, id, price):
					GameState.audio.play("coin")
					GameState.equip(_shop_tab, id)
				_shop())
		h.add_child(btn)

# ---------------------------------------------------------------- settings
func _settings() -> void:
	var v := _clear()
	_header(v, Loc.t("settings"), true)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := UIKit.vbox(16)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(list)
	_cycle(list, "tod", "tod", ["day", "sunset", "night"])
	_cycle_str(list, "scenery", "scenery", ["auto", "island", "forest", "autumn", "desert", "beach", "snow", "mountain", "temple", "city", "space"])
	_slider(list, "music", "music")
	_slider(list, "sfx", "sfx")
	_cycle(list, "quality", "quality", ["low", "medium", "high"])
	_cycle(list, "effects", "effects", ["off", "low", "high"])
	_toggle(list, "shake", "shake")
	_toggle(list, "vibration", "vibration")
	var lr := _row(list, Loc.t("language"))
	var lb := UIKit.button(Loc.t("lang_name"), Color("#5b6dff"), Vector2(300, 90), 36)
	lb.pressed.connect(func():
		GameState.set_setting("language", "en" if Loc.lang == "fa" else "fa")
		_show("settings"))
	lr.add_child(lb)
	var rb := UIKit.button(Loc.t("reset_confirm") if _reset_armed else Loc.t("reset_progress"), Color("#c0392b"), Vector2(0, 100), 38)
	rb.pressed.connect(func():
		if _reset_armed:
			GameState.reset_progress()
			_show("main")
		else:
			_reset_armed = true
			_settings())
	list.add_child(rb)
	list.add_child(UIKit.label(Loc.t("credit"), 34, Color("#ffd23f")))

func _cycle_str(v: VBoxContainer, title_key: String, setting: String, values: Array) -> void:
	var h := _row(v, Loc.t(title_key))
	var cur := maxi(0, values.find(str(GameState.setting(setting))))
	var b := UIKit.button(Loc.t("sc_" + str(values[cur])), Color("#5b6dff"), Vector2(300, 90), 34)
	b.pressed.connect(func():
		GameState.set_setting(setting, str(values[(cur + 1) % values.size()]))
		_show("settings"))
	h.add_child(b)

func _row(v: VBoxContainer, title: String) -> HBoxContainer:
	var p := UIKit.panel(Color(0, 0, 0, 0.35), 24)
	v.add_child(p)
	var h := UIKit.hbox(16)
	p.add_child(h)
	var l := UIKit.label(title, 38, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h

func _slider(v: VBoxContainer, title_key: String, setting: String) -> void:
	var h := _row(v, Loc.t(title_key))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(GameState.setting(setting))
	s.custom_minimum_size = Vector2(380, 70)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(val: float): GameState.set_setting(setting, val))
	h.add_child(s)

func _toggle(v: VBoxContainer, title_key: String, setting: String) -> void:
	var h := _row(v, Loc.t(title_key))
	var on := bool(GameState.setting(setting))
	var b := UIKit.button(Loc.t("on") if on else Loc.t("off"), Color("#2ec27e") if on else Color("#7a7a8a"), Vector2(220, 90), 36)
	b.pressed.connect(func():
		GameState.set_setting(setting, not on)
		_show("settings"))
	h.add_child(b)

func _cycle(v: VBoxContainer, title_key: String, setting: String, names: Array) -> void:
	var h := _row(v, Loc.t(title_key))
	var cur := clampi(int(GameState.setting(setting)), 0, names.size() - 1)
	var b := UIKit.button(Loc.t(str(names[cur])), Color("#5b6dff"), Vector2(260, 90), 36)
	b.pressed.connect(func():
		GameState.set_setting(setting, (cur + 1) % names.size())
		_show("settings"))
	h.add_child(b)
