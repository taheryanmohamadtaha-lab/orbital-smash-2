extends Node3D
## Gameplay controller: builds the level from JSON, handles aiming, launching,
## settle detection, win/lose, scoring and effects.

enum State { INTRO, READY, AIMING, SHOOTING, ENDED }

const LAUNCH_POS := Vector3(0.0, 1.5, 3.0)
const MIN_SPEED := 12.0
const MAX_SPEED := 30.0
const DOT_COUNT := 28

var level: Dictionary = {}
var world_id := 1
var state: State = State.INTRO
var ammo: Dictionary = {}
var selected_type := "standard"
var balls_used := 0
var score := 0
var targets_total := 0
var targets_destroyed := 0
var targets_fallen := 0
var fallen_count := 0
var protect_violated := false
var has_protected := false
var win_def: Dictionary = {}
var quality := 1
var effects_level := 2
var shake_enabled := true
var shard_budget := 0

var camera: Camera3D
var hud: HUD
var blocks_root: Node3D
var ghost: MeshInstance3D
var dots: Array = []
var balls: Array = []
var base_cam_pos := Vector3(0, 6, 8)
var base_look := Vector3(0, 4, -14)
var cam_focus := Vector3(0, 4, -14)
var cam_offset := Vector3(10, 9, 14)
var shake := 0.0
var aim_start := Vector2.ZERO
var aim_cur := Vector2.ZERO
var shot_time := 0.0
var settle_time := 0.0

func _ready() -> void:
	get_tree().paused = false
	level = GameState.get_level(GameState.current_level_id)
	if level.is_empty():
		GameState.current_level_id = 1
		level = GameState.get_level(1)
	world_id = int(level["world"])
	win_def = level["win"]
	quality = int(GameState.setting("quality"))
	effects_level = int(GameState.setting("effects"))
	shake_enabled = bool(GameState.setting("shake"))
	shard_budget = [12, 32, 60][clampi(quality, 0, 2)] if effects_level > 0 else 0
	if quality >= 2:
		get_viewport().msaa_3d = Viewport.MSAA_2X
	_build_world()
	_build_blocks()
	_build_camera()
	_build_launcher()
	_build_hud()
	_init_ammo()
	_refresh_ghost()
	hud.set_balls(ammo, selected_type)
	_update_progress()
	GameState.audio.play_music(world_id)
	_start_intro()

# ------------------------------------------------------------------ building
func _build_world() -> void:
	add_child(WorldBuilder.build(world_id, quality, int(GameState.setting("tod")), str(GameState.setting("scenery")), int(level["id"])))
	var plat: Dictionary = level["platform"]
	var ps: Array = plat["size"]
	var pz := float(plat["center_z"])
	add_child(WorldBuilder.make_platform(world_id, Vector3(float(ps[0]), 1.0, float(ps[1])), Vector3(0, -0.5, pz), quality))

func _build_blocks() -> void:
	blocks_root = Node3D.new()
	blocks_root.name = "Blocks"
	add_child(blocks_root)
	for d in level["blocks"]:
		var def: Dictionary = d
		var b := Block.new()
		b.setup(def, GameState.materials[str(def["material"])])
		b.broke.connect(_on_block_broke)
		b.hit.connect(_on_block_hit)
		blocks_root.add_child(b)
		if b.is_target:
			targets_total += 1
		if b.is_protected:
			has_protected = true
	for m in level.get("movers", []):
		var mv := Mover.new()
		mv.setup(m, WorldBuilder.mover_color(world_id))
		add_child(mv)

func _build_camera() -> void:
	var cd: Dictionary = level["camera"]
	var cp: Array = cd["position"]
	var cl: Array = cd["look_at"]
	base_cam_pos = Vector3(float(cp[0]), float(cp[1]), float(cp[2]))
	base_look = Vector3(float(cl[0]), float(cl[1]), float(cl[2]))
	cam_focus = base_look
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = float(cd["fov"])
	camera.near = 0.2
	camera.far = 320.0
	add_child(camera)
	camera.current = true
	_apply_camera()

func _build_launcher() -> void:
	var pad := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.2
	cm.height = 0.3
	pad.mesh = cm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = WorldBuilder.mover_color(world_id)
	pm.emission_enabled = true
	pm.emission = pm.albedo_color
	pm.emission_energy_multiplier = 0.9
	pad.material_override = pm
	pad.position = LAUNCH_POS + Vector3(0, -0.85, 0)
	add_child(pad)
	ghost = MeshInstance3D.new()
	var sm := SphereMesh.new()
	ghost.mesh = sm
	ghost.position = LAUNCH_POS
	ghost.material_override = StandardMaterial3D.new()
	add_child(ghost)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(1, 1, 1, 0.9)
	for i in DOT_COUNT:
		var d := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.1
		s.height = 0.2
		s.radial_segments = 8
		s.rings = 4
		d.mesh = s
		d.material_override = dm
		d.visible = false
		add_child(d)
		dots.append(d)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	layer.add_child(hud)
	hud.setup(level, "%s: %s" % [Loc.t("world"), GameState.world_name(world_id)] + "  –  " + GameState.level_name(level))
	hud.aim_event.connect(_on_aim_input)
	hud.type_selected.connect(_on_type_selected)
	hud.pause_toggled.connect(func(p: bool): get_tree().paused = p)
	hud.restart_pressed.connect(_restart)
	hud.menu_pressed.connect(func(): _leave("main"))
	hud.levels_pressed.connect(func(): _leave("levels"))
	hud.next_pressed.connect(_next_level)
	hud.set_score(0)

func _init_ammo() -> void:
	var inv: Dictionary = level["balls"]
	ammo = {}
	for k in inv.keys():
		var t := str(k)
		var use_t := t if GameState.owns_ball(t) else "standard"
		ammo[use_t] = int(ammo.get(use_t, 0)) + int(inv[k])
	selected_type = "standard"
	for t in GameState.BALL_ORDER:
		if int(ammo.get(t, 0)) > 0:
			selected_type = t
			break

func _total_ammo() -> int:
	var n := 0
	for k in ammo.keys():
		n += int(ammo[k])
	return n

# ------------------------------------------------------------------ camera
func _start_intro() -> void:
	state = State.INTRO
	var tw := create_tween()
	tw.tween_property(self, "cam_offset", Vector3.ZERO, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_on_intro_done)

func _on_intro_done() -> void:
	if state != State.INTRO:
		return
	state = State.READY
	hud.show_banner(_goal_text(), 3.2)
	if int(level["id"]) <= 3:
		hud.show_hint(Loc.t("hint_aim"))

func _goal_text() -> String:
	var txt := ""
	match str(win_def["type"]):
		"knock_off":
			txt = Loc.t("goal_knock") % int(win_def["count"])
		"topple":
			txt = Loc.t("goal_topple")
		_:
			txt = Loc.t("goal_destroy")
	if has_protected:
		txt += "\n" + Loc.t("goal_protected")
	return txt

func _apply_camera() -> void:
	camera.look_at_from_position(base_cam_pos + cam_offset, cam_focus, Vector3.UP)
	if shake_enabled and shake > 0.0:
		camera.h_offset = randf_range(-1.0, 1.0) * shake * 0.35
		camera.v_offset = randf_range(-1.0, 1.0) * shake * 0.35
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.5)
	var desired := base_look
	if state == State.SHOOTING:
		for b in balls:
			if is_instance_valid(b):
				var bp: Vector3 = (b as Ball).global_position
				desired = base_look.lerp(Vector3(bp.x, maxf(bp.y, 1.0), maxf(bp.z, base_look.z)), 0.3)
				break
	cam_focus = cam_focus.lerp(desired, minf(1.0, delta * 3.0))
	_apply_camera()

# ------------------------------------------------------------------ aiming
func _max_drag() -> float:
	return get_viewport().get_visible_rect().size.y * 0.15

func _on_type_selected(t: String) -> void:
	if state != State.READY or int(ammo.get(t, 0)) <= 0:
		return
	selected_type = t
	hud.set_balls(ammo, selected_type)
	_refresh_ghost()

func _ball_color(t: String) -> Color:
	var cdef: Dictionary = GameState.equipped_color_def()
	if str(cdef["id"]) != "default":
		return Color(str(cdef["color"]))
	return Color(str((GameState.ball_types[t] as Dictionary)["color"]))

func _refresh_ghost() -> void:
	var def: Dictionary = GameState.ball_types[selected_type]
	var r := float(def["radius"])
	var sm := ghost.mesh as SphereMesh
	sm.radius = r
	sm.height = r * 2.0
	var mat := ghost.material_override as StandardMaterial3D
	mat.albedo_color = _ball_color(selected_type)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 0.35
	ghost.visible = _total_ammo() > 0 and state != State.ENDED

func _on_aim_input(event: InputEvent) -> void:
	if state != State.READY and state != State.AIMING:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if state == State.READY and _total_ammo() > 0:
				aim_start = mb.position
				aim_cur = mb.position
				state = State.AIMING
				hud.hide_hint()
		elif state == State.AIMING:
			_release()
	elif event is InputEventMouseMotion and state == State.AIMING:
		aim_cur = (event as InputEventMouseMotion).position
		_update_aim()

func _aim_velocity() -> Vector3:
	var pull := aim_start - aim_cur
	var md := _max_drag()
	var power := clampf(pull.length() / md, 0.0, 1.0)
	var yaw := clampf(pull.x / md, -1.0, 1.0) * deg_to_rad(28.0)
	var pitch := deg_to_rad(8.0 + clampf(pull.y / md, 0.0, 1.0) * 40.0)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()
	var def: Dictionary = GameState.ball_types[selected_type]
	return dir * lerpf(MIN_SPEED, MAX_SPEED, power) * float(def["speed"])

func _update_aim() -> void:
	var pull := aim_start - aim_cur
	var power := clampf(pull.length() / _max_drag(), 0.0, 1.0)
	hud.set_power(power)
	if power < 0.12:
		_hide_dots()
		return
	_update_preview(_aim_velocity())

func _hide_dots() -> void:
	for d in dots:
		(d as MeshInstance3D).visible = false

func _update_preview(vel: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var p := LAUNCH_POS
	var v := vel
	var dt := 1.0 / 60.0
	var idx := 0
	var last_check := p
	var ended := false
	for i in range(1, 181):
		v.y -= g * dt
		p += v * dt
		if i % 4 == 0:
			var query := PhysicsRayQueryParameters3D.create(last_check, p, 3)
			var res := space.intersect_ray(query)
			if not res.is_empty():
				p = res["position"]
				ended = true
			last_check = p
			if idx < dots.size():
				var d := dots[idx] as MeshInstance3D
				d.position = p
				d.scale = Vector3.ONE * lerpf(1.2, 0.5, float(idx) / DOT_COUNT)
				d.visible = true
				idx += 1
		if ended or p.y < -2.0:
			break
	for j in range(idx, dots.size()):
		(dots[j] as MeshInstance3D).visible = false

func _release() -> void:
	hud.set_power(0.0)
	_hide_dots()
	if (aim_start - aim_cur).length() / _max_drag() < 0.12:
		state = State.READY
		return
	_launch(_aim_velocity())

func _launch(vel: Vector3) -> void:
	var t := selected_type
	ammo[t] = int(ammo[t]) - 1
	balls_used += 1
	var b := Ball.new()
	b.setup(t, GameState.ball_types[t], _ball_color(t), GameState.equipped_trail_def(), quality >= 1 and effects_level > 0)
	b.position = LAUNCH_POS
	add_child(b)
	b.linear_velocity = vel
	b.hit.connect(_on_ball_hit)
	balls.append(b)
	GameState.audio.play("launch", 0.9)
	GameState.vibrate(20)
	hud.set_balls(ammo, selected_type)
	ghost.visible = false
	shot_time = 0.0
	settle_time = 0.0
	state = State.SHOOTING

# ------------------------------------------------------------------ simulation loop
func _physics_process(delta: float) -> void:
	if state != State.SHOOTING:
		return
	shot_time += delta
	_check_blocks()
	_cleanup_balls()
	if _is_settled():
		settle_time += delta
	else:
		settle_time = 0.0
	if (settle_time > 0.8 and shot_time > 0.8) or shot_time > 14.0:
		_evaluate()

func _check_blocks() -> void:
	for n in blocks_root.get_children():
		var b := n as Block
		if b == null or b.dead:
			continue
		var y := b.global_position.y
		if not b.fallen and y < -1.2:
			b.fallen = true
			fallen_count += 1
			score += int(b.score_value * 0.5)
			if b.is_target:
				targets_fallen += 1
				score += 100
			if b.is_protected:
				protect_violated = true
			GameState.audio.play("fall", 0.7)
			hud.set_score(score)
			_update_progress()
		if y < -14.0:
			b.dead = true
			b.queue_free()

func _cleanup_balls() -> void:
	for b in balls.duplicate():
		if not is_instance_valid(b):
			balls.erase(b)
			continue
		var bl := b as Ball
		var bp := bl.global_position
		if bl.age > 12.0 or bp.y < -8.0 or bp.z < -45.0:
			bl.queue_free()
			balls.erase(b)

func _is_settled() -> bool:
	for n in blocks_root.get_children():
		var b := n as Block
		if b == null or b.dead or b.fallen or b.sleeping:
			continue
		if b.linear_velocity.length() > 0.25 or b.angular_velocity.length() > 0.6:
			return false
	for bb in balls:
		if not is_instance_valid(bb):
			continue
		var bl := bb as Ball
		if bl.sleeping:
			continue
		if bl.linear_velocity.length() > 0.25:
			return false
	return true

func _clear_balls() -> void:
	for b in balls:
		if is_instance_valid(b):
			(b as Ball).queue_free()
	balls.clear()

func _targets_done() -> int:
	var n := targets_destroyed + targets_fallen
	if str(win_def["type"]) == "topple":
		var h := float(win_def.get("height", 1.4))
		for c in blocks_root.get_children():
			var b := c as Block
			if b != null and b.is_target and not b.dead and not b.fallen and b.global_position.y < h:
				n += 1
	return n

func _update_progress() -> void:
	if str(win_def["type"]) == "knock_off":
		hud.set_progress(fallen_count, int(win_def["count"]))
	else:
		hud.set_progress(_targets_done(), targets_total)

func _is_won() -> bool:
	match str(win_def["type"]):
		"knock_off":
			return fallen_count >= int(win_def["count"])
		"topple":
			return _targets_done() >= targets_total
		_:
			return targets_destroyed + targets_fallen >= targets_total
	return false

func _evaluate() -> void:
	_update_progress()
	if protect_violated:
		_finish(false, "lose_protect")
	elif _is_won():
		_finish(true, "")
	elif _total_ammo() <= 0:
		_finish(false, "lose_balls")
	else:
		_clear_balls()
		if int(ammo.get(selected_type, 0)) <= 0:
			for t in GameState.BALL_ORDER:
				if int(ammo.get(t, 0)) > 0:
					selected_type = t
					break
		hud.set_balls(ammo, selected_type)
		_refresh_ghost()
		state = State.READY

func _finish(won: bool, cause: String) -> void:
	state = State.ENDED
	_clear_balls()
	ghost.visible = false
	_hide_dots()
	if won:
		var left := _total_ammo()
		score += 1000 + left * 400
		hud.set_score(score)
		var st: Dictionary = level["stars"]
		var stars := 1
		if balls_used <= int(st["three"]):
			stars = 3
		elif balls_used <= int(st["two"]):
			stars = 2
		var reward: Dictionary = level["reward"]
		var base_coins := int(round(float(reward["coins"]) * (0.6 + 0.2 * stars))) + left * 3
		var res: Dictionary = GameState.complete_level(int(level["id"]), stars, score, base_coins)
		GameState.audio.play("win")
		GameState.vibrate(60)
		var tw := create_tween()
		tw.tween_property(self, "cam_offset", Vector3(0, 2.5, 6), 1.4).set_trans(Tween.TRANS_SINE)
		get_tree().create_timer(1.0).timeout.connect(func():
			hud.show_result(true, {
				"stars": stars, "score": score, "best": int(res["best"]), "new_best": bool(res["new_best"]),
				"coins": int(res["coins"]), "balls_used": balls_used,
				"has_next": not GameState.get_level(int(level["id"]) + 1).is_empty(),
			}))
	else:
		GameState.audio.play("lose")
		get_tree().create_timer(0.8).timeout.connect(func(): hud.show_result(false, {"cause": Loc.t(cause)}))

# ------------------------------------------------------------------ events from physics objects
func _on_block_hit(b: Block, impact: float, from_ball: bool) -> void:
	if not is_instance_valid(b):
		return
	GameState.audio.play(str(b.mat.get("sound", "hit_wood")), clampf(impact / 30.0, 0.15, 1.0), randf_range(0.92, 1.08))
	if from_ball:
		shake = maxf(shake, clampf(impact / 45.0, 0.0, 0.8))
		if impact > 22.0:
			GameState.vibrate(25)
		if effects_level >= 1 and impact > 14.0:
			_burst(b.global_position, b.color.lightened(0.3), 6, 3.5, 0.12)

func _on_block_broke(b: Block) -> void:
	# Spawning physics bodies is not allowed while physics callbacks are flushing.
	_process_break.call_deferred(b)

func _process_break(b: Block) -> void:
	if not is_instance_valid(b):
		return
	score += b.score_value
	if b.is_target:
		targets_destroyed += 1
		score += 150
	if b.is_protected:
		protect_violated = true
	_shatter(b)
	GameState.audio.play("shatter", 0.8, randf_range(0.9, 1.1))
	b.queue_free()
	hud.set_score(score)
	_update_progress()

func _on_ball_hit(ball: Ball, body: Node, rel: float) -> void:
	if not is_instance_valid(ball) or ball.exploded:
		return
	if rel < 2.0:
		return
	if not (body is Block) and rel > 5.0:
		GameState.audio.play("fall", clampf(rel / 30.0, 0.2, 0.9))
	var ability := str(ball.def.get("ability", ""))
	if ability == "blast" and (body is Block or rel > 6.0):
		ball.exploded = true
		_explode.call_deferred(ball)
	elif ability == "pierce" and body is Block:
		var bk := body as Block
		if (bk.material_id == "glass" or bk.material_id == "wood") and rel > 8.0:
			bk.force_break()
			ball.set_deferred("linear_velocity", ball.last_velocity * 0.88)

func _explode(ball: Ball) -> void:
	if not is_instance_valid(ball):
		return
	var pos := ball.global_position
	var radius := 3.6
	for n in blocks_root.get_children():
		var b := n as Block
		if b == null or b.dead:
			continue
		var d := b.global_position - pos
		var dist := d.length()
		if dist > radius:
			continue
		var f := 1.0 - dist / radius
		var dir := (d.normalized() + Vector3.UP * 0.35).normalized()
		b.apply_central_impulse(dir * 16.0 * f * b.mass)
		b.apply_impact(70.0 * f)
	_flash(pos, radius)
	_burst(pos, Color("#ff9a3c"), 40, 9.0, 0.35)
	GameState.audio.play("explosion", 1.0)
	GameState.vibrate(80)
	shake = 1.0
	balls.erase(ball)
	ball.queue_free()

func _flash(pos: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.7, 0.2, 0.8)
	mi.material_override = m
	mi.position = pos
	mi.scale = Vector3.ONE * 0.3
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)

# ------------------------------------------------------------------ effects
func _burst(pos: Vector3, color: Color, amount: int, speed: float, psize: float) -> void:
	if effects_level == 0:
		return
	var p := CPUParticles3D.new()
	p.amount = amount if effects_level >= 2 else maxi(4, amount / 2)
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -8, 0)
	p.scale_amount_min = psize
	p.scale_amount_max = psize * 1.6
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	p.mesh = m
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)

func _shatter(b: Block) -> void:
	_burst(b.global_position, b.color, 14, 5.0, 0.18)
	if shard_budget <= 0:
		return
	var n := mini(int(b.mat.get("shards", 4)), shard_budget)
	var alpha := float(b.mat.get("alpha", 1.0))
	for i in n:
		var s := RigidBody3D.new()
		s.collision_layer = 4
		s.collision_mask = 2
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		var ssz := b.size * 0.3
		sh.size = ssz
		cs.shape = sh
		s.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = ssz
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(b.color.r, b.color.g, b.color.b, alpha)
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		s.add_child(mi)
		s.position = b.global_position + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * b.size * 0.3
		add_child(s)
		s.linear_velocity = b.linear_velocity * 0.5 + Vector3(randf_range(-2, 2), randf_range(1, 4), randf_range(-2, 2))
		s.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		shard_budget -= 1
		get_tree().create_timer(2.2).timeout.connect(_free_shard.bind(s))

func _free_shard(s: RigidBody3D) -> void:
	if is_instance_valid(s):
		s.queue_free()
	shard_budget += 1

# ------------------------------------------------------------------ navigation
func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _next_level() -> void:
	GameState.current_level_id = int(level["id"]) + 1
	_restart()

func _leave(screen: String) -> void:
	get_tree().paused = false
	GameState.start_screen = screen
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and hud != null and state != State.ENDED:
		hud.toggle_pause()
