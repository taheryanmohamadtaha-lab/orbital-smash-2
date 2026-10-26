class_name WorldBuilder
extends RefCounted
## Procedural 3D environments for the five worlds (no external model files needed).

const THEMES := {
	1: {"top": "#3d9bff", "hor": "#c9ecff", "amb": "#e6f2ff", "sun": "#fff1cf", "energy": 1.15, "plat_top": "#6fd35c", "plat_side": "#8d5a2b", "mover": "#ff9f1c"},
	2: {"top": "#120a3a", "hor": "#5a1d8f", "amb": "#7a6af0", "sun": "#b9a6ff", "energy": 0.95, "plat_top": "#1c1b3a", "plat_side": "#0e0d24", "mover": "#ff2fd0"},
	3: {"top": "#e8923c", "hor": "#ffe0a3", "amb": "#ffe6c4", "sun": "#fff0cc", "energy": 1.2, "plat_top": "#c9b27a", "plat_side": "#8a7550", "mover": "#ffd23f"},
	4: {"top": "#8fd0ff", "hor": "#f2fbff", "amb": "#dff3ff", "sun": "#ffffff", "energy": 1.1, "plat_top": "#cfefff", "plat_side": "#7fc3e8", "mover": "#2fd5ff"},
	5: {"top": "#04030f", "hor": "#1b1450", "amb": "#6a64c0", "sun": "#c7c2ff", "energy": 0.95, "plat_top": "#2a2d55", "plat_side": "#171a38", "mover": "#4dffd2"},
}

static func mover_color(world: int) -> Color:
	return Color(str((THEMES[world] as Dictionary)["mover"]))

# ------------------------------------------------------------ helpers
static func _m(color: Color, emission: float = 0.0, alpha: float = 1.0, metallic: float = 0.0, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.metallic = metallic
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

static func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func _box(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b

static func _cyl(top_r: float, bot_r: float, h: float, seg: int = 14) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bot_r
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

static func _sph(r: float, seg: int = 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(3, seg / 2)
	return s

static func _plane(sx: float, sz: float) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(sx, sz)
	return p

static func _torus(inner: float, outer: float, rings: int = 40, segs: int = 6) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = rings
	t.ring_segments = segs
	return t

static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

# ------------------------------------------------------------ build
const SKY := {
	"island": ["#3d9bff", "#c9ecff", "#e6f2ff", "#fff1cf", 1.15],
	"forest": ["#4a95d8", "#cfe6dc", "#e0efe0", "#fff0d0", 1.1],
	"desert": ["#3f98e6", "#ffe0b0", "#fff0d8", "#fff2d0", 1.25],
	"beach": ["#2a92e8", "#bfeaff", "#e6f6ff", "#fff4d8", 1.2],
	"snow": ["#8fd0ff", "#f2fbff", "#dff3ff", "#ffffff", 1.1],
	"mountain": ["#5a9ee0", "#dceeff", "#e4efff", "#fff3dc", 1.1],
	"autumn": ["#6aa8e0", "#ffe2bc", "#ffe9d0", "#ffe8c0", 1.1],
	"temple": ["#e8923c", "#ffe0a3", "#ffe6c4", "#fff0cc", 1.2],
	"city": ["#3a4ab8", "#a98cff", "#8a7ae8", "#d0c0ff", 0.95],
	"space": ["#04030f", "#1b1450", "#6a64c0", "#c7c2ff", 0.95],
}
const SCENERY_BY_WORLD := {
	1: ["island", "forest", "beach"],
	3: ["temple", "desert", "mountain"],
	4: ["snow", "mountain", "autumn"],
}
static var _night := false

static func resolve_scenery(world: int, scenery: String, level_id: int) -> String:
	if scenery != "auto":
		return scenery
	if world == 2:
		return "city"
	if world == 5:
		return "space"
	var lst: Array = SCENERY_BY_WORLD[world]
	return str(lst[level_id % lst.size()])

## tod: 0 = day, 1 = sunset, 2 = night
static func build(world: int, quality: int, tod: int = 0, scenery: String = "auto", level_id: int = 1) -> Node3D:
	var sc := resolve_scenery(world, scenery, level_id)
	var arr: Array = SKY[sc]
	var top := Color(str(arr[0]))
	var hor := Color(str(arr[1]))
	var amb := Color(str(arr[2]))
	var sun_col := Color(str(arr[3]))
	var energy := float(arr[4]) * 0.85
	var amb_energy := 0.55
	var sun_rot := Vector3(-52.0, -28.0, 0.0)
	_night = tod == 2
	if sc == "space":
		energy = 0.9
		amb_energy = 0.6
	elif tod == 1:
		top = Color("#43307a")
		hor = Color("#ff9a5a")
		amb = Color("#ffc9a0")
		sun_col = Color("#ff9a50")
		energy = 0.95
		amb_energy = 0.5
		sun_rot = Vector3(-16.0, -62.0, 0.0)
	elif tod == 2:
		top = Color("#040820")
		hor = Color("#1c2c60")
		amb = Color("#5a6cb0")
		sun_col = Color("#a8bcff")
		energy = 0.5
		amb_energy = 0.5
		sun_rot = Vector3(-40.0, 30.0, 0.0)
		if sc == "city":
			top = Color("#120a3a")
			hor = Color("#5a1d8f")
	var root := Node3D.new()
	root.name = "WorldDecor"
	var we := WorldEnvironment.new()
	var env := Environment.new()
	if sc == "space":
		env.background_mode = Environment.BG_COLOR
		env.background_color = top
	else:
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = top
		sm.sky_horizon_color = hor
		sm.ground_horizon_color = hor
		sm.ground_bottom_color = hor.darkened(0.3)
		sky.sky_material = sm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = amb
	env.ambient_light_energy = amb_energy
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = sun_col
	sun.light_energy = energy
	sun.rotation_degrees = sun_rot
	sun.shadow_enabled = quality >= 1
	sun.directional_shadow_max_distance = 45.0
	root.add_child(sun)
	match sc:
		"island":
			_s_island(root, quality)
		"forest":
			_s_forest(root, quality, false)
		"autumn":
			_s_forest(root, quality, true)
		"desert":
			_s_desert(root, quality)
		"beach":
			_s_beach(root, quality)
		"mountain":
			_s_mountain(root, quality)
		"snow":
			_s_snow(root, quality)
		"temple":
			_s_temple(root, quality)
		"city":
			_s_city(root, quality)
		_:
			_s_space(root, quality)
	# sky bodies
	if sc != "space":
		if tod == 2:
			_stars(root, quality, 77)
			_add(root, _sph(7.0, 20), _unshaded(Color("#f2f6ff")), Vector3(-34, 42, -125))
		elif tod == 1:
			_add(root, _sph(10.0, 20), _unshaded(Color("#ffb060")), Vector3(26, 4, -135))
		elif sc != "city":
			_add(root, _sph(5.0, 16), _unshaded(Color("#fff6c0")), Vector3(34, 46, -140))
	return root

static func _stars(root: Node3D, q: int, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _sph(0.25, 6)
	mm.instance_count = 160 if q >= 1 else 80
	for i in mm.instance_count:
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.05, 1.0), rng.randf_range(-1.0, -0.1)).normalized()
		var s := rng.randf_range(0.5, 1.6)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), dir * rng.randf_range(100.0, 150.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _unshaded(Color.WHITE)
	root.add_child(mmi)

static func _clouds(root: Node3D, rng: RandomNumberGenerator, n: int) -> void:
	if _night:
		return
	for i in n:
		var c := Vector3(rng.randf_range(-45, 45), rng.randf_range(10, 24), rng.randf_range(-90, -40))
		for k in 4:
			var s := rng.randf_range(2.0, 3.5)
			var mi := _add(root, _sph(s, 10), _m(Color.WHITE, 0.15, 0.95), c + Vector3(k * 2.4 - 3.6, rng.randf_range(-0.5, 0.5), 0))
			mi.scale = Vector3(1.0, 0.6, 1.0)

static func _pine(root: Node3D, base: Vector3, h: float, leaf: Color) -> void:
	_add(root, _cyl(0.3, 0.45, h * 0.25, 6), _m(Color("#6b4423")), base + Vector3(0, h * 0.125, 0))
	_add(root, _cyl(0.0, h * 0.26, h * 0.55, 8), _m(leaf), base + Vector3(0, h * 0.45, 0))
	_add(root, _cyl(0.0, h * 0.2, h * 0.45, 8), _m(leaf.lightened(0.08)), base + Vector3(0, h * 0.72, 0))

static func _round_tree(root: Node3D, base: Vector3, h: float, leaf: Color) -> void:
	_add(root, _cyl(0.35, 0.5, h * 0.5, 6), _m(Color("#6b4423")), base + Vector3(0, h * 0.25, 0))
	_add(root, _sph(h * 0.32, 10), _m(leaf), base + Vector3(0, h * 0.65, 0))

static func _palm(root: Node3D, base: Vector3, h: float) -> void:
	_add(root, _cyl(0.3, 0.5, h, 6), _m(Color("#9a7040")), base + Vector3(0, h * 0.5, 0), Vector3(0, 0, 0.12))
	for i in 5:
		var ang := i * TAU / 5.0
		_add(root, _box(Vector3(4.5, 0.15, 1.1)), _m(Color("#2fa84f")),
			base + Vector3(cos(ang) * 2.0 + 0.6, h - 0.2, -sin(ang) * 2.0), Vector3(0, ang, 0.35))

static func _ground(root: Node3D, color: Color, y: float = -10.0) -> void:
	_add(root, _plane(600, 600), _m(color), Vector3(0, y, -80))

static func _far_range(root: Node3D, rng: RandomNumberGenerator, col: Color, snow: bool, n: int, hmin: float, hmax: float) -> void:
	for i in n:
		var h := rng.randf_range(hmin, hmax)
		var r := h * rng.randf_range(0.7, 1.0)
		var x := -120.0 + i * (240.0 / float(maxi(1, n - 1)))
		var z := rng.randf_range(-190.0, -140.0)
		_add(root, _cyl(0.0, r, h, 8), _m(col.darkened(rng.randf_range(0.0, 0.2))), Vector3(x, h * 0.5 - 10.0, z))
		if snow:
			_add(root, _cyl(0.0, r * 0.32, h * 0.3, 8), _m(Color("#f4fbff")), Vector3(x, h * 0.85 - 10.0, z))

static func _s_forest(root: Node3D, q: int, autumn: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 66 if not autumn else 67
	_ground(root, Color("#a8742f") if autumn else Color("#3f8f45"))
	_far_range(root, rng, Color("#5f7fa0") if not autumn else Color("#9a7a8a"), false, 7, 40.0, 70.0)
	for i in 5:
		_add(root, _sph(rng.randf_range(30.0, 50.0), 14), _m(Color("#2f7a3a") if not autumn else Color("#b0602a")),
			Vector3(rng.randf_range(-110, 110), -10.0, rng.randf_range(-150, -100))).scale = Vector3(1, 0.4, 0.8)
	var palette := [Color("#d9731f"), Color("#c23b22"), Color("#e8b020")] if autumn else [Color("#1f7a3a"), Color("#2a8f45"), Color("#18652f")]
	var n := 64 if q >= 1 else 30
	for i in n:
		var x := rng.randf_range(-75.0, 75.0)
		if absf(x) < 8.0:
			x += 14.0 * signf(x + 0.01)
		var z := -rng.randf_range(14.0, 110.0)
		var h := rng.randf_range(12.0, 26.0)
		var col: Color = palette[i % 3]
		if autumn and i % 2 == 0:
			_round_tree(root, Vector3(x, -10.0, z), h, col)
		else:
			_pine(root, Vector3(x, -10.0, z), h, col)
	_clouds(root, rng, 4 if q >= 1 else 2)

static func _s_desert(root: Node3D, q: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	_ground(root, Color("#e6c27a"))
	for i in 10:
		var d := _add(root, _sph(rng.randf_range(25.0, 45.0), 14), _m(Color("#e0b565").darkened(rng.randf_range(0.0, 0.15))),
			Vector3(rng.randf_range(-110, 110), -10.0, rng.randf_range(-170, -40)))
		d.scale = Vector3(1.0, 0.22, 0.7)
	for i in 6:
		var h := rng.randf_range(18.0, 34.0)
		var x := -100.0 + i * 40.0
		var z := rng.randf_range(-160.0, -110.0)
		_add(root, _cyl(12.0, 16.0, h, 10), _m(Color("#c0703a")), Vector3(x, h * 0.5 - 10.0, z))
		_add(root, _cyl(12.5, 12.5, 2.0, 10), _m(Color("#d98a50")), Vector3(x, h - 10.0, z))
	var cn := 14 if q >= 1 else 6
	for i in cn:
		var x := rng.randf_range(-60.0, 60.0)
		if absf(x) < 9.0:
			x += 16.0 * signf(x + 0.01)
		var z := -rng.randf_range(14.0, 90.0)
		var h := rng.randf_range(6.0, 11.0)
		var g := Color("#3f8f4a")
		_add(root, _cyl(0.6, 0.7, h, 8), _m(g), Vector3(x, h * 0.5 - 10.0, z))
		_add(root, _cyl(0.4, 0.4, 2.4, 6), _m(g), Vector3(x + 1.3, h * 0.55 - 10.0, z), Vector3(0, 0, PI * 0.5))
		_add(root, _cyl(0.4, 0.4, 2.6, 6), _m(g), Vector3(x + 2.4, h * 0.7 - 10.0, z))
		_add(root, _cyl(0.4, 0.4, 2.0, 6), _m(g), Vector3(x - 1.2, h * 0.45 - 10.0, z), Vector3(0, 0, PI * 0.5))
		_add(root, _cyl(0.4, 0.4, 2.2, 6), _m(g), Vector3(x - 2.2, h * 0.6 - 10.0, z))
	_clouds(root, rng, 2)

static func _s_beach(root: Node3D, q: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	_add(root, _plane(600, 600), _m(Color("#1fb5d8"), 0.0, 0.9, 0.3, 0.15), Vector3(0, -10, -80))
	for i in 4:
		var pos := Vector3(-60.0 + i * 40.0 + rng.randf_range(-8, 8), -10.0, rng.randf_range(-100, -40))
		var r := rng.randf_range(14.0, 24.0)
		_add(root, _cyl(r, r + 3.0, 1.6, 20), _m(Color("#f2dca0")), pos + Vector3(0, 0.2, 0))
		var np := 3 if q >= 1 else 1
		for k in np:
			_palm(root, pos + Vector3(rng.randf_range(-r * 0.5, r * 0.5), 1.0, rng.randf_range(-r * 0.5, r * 0.5)), rng.randf_range(9.0, 14.0))
	for i in 5:
		_add(root, _sph(rng.randf_range(3.0, 6.0), 8), _m(Color("#6a7080")), Vector3(rng.randf_range(-40, 40), -10.0, rng.randf_range(-70, -24))).scale = Vector3(1, 0.7, 1)
	_far_range(root, rng, Color("#6a9a9a"), false, 5, 25.0, 45.0)
	_clouds(root, rng, 6 if q >= 1 else 3)

static func _s_mountain(root: Node3D, q: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	_ground(root, Color("#4a8a50"))
	_add(root, _plane(140, 140), _m(Color("#2a8fb8"), 0.0, 0.9, 0.3, 0.1), Vector3(0, -9.9, -75))
	_far_range(root, rng, Color("#6a7a96"), true, 6, 70.0, 110.0)
	var n := 40 if q >= 1 else 18
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * rng.randf_range(32.0, 90.0)
		var z := -rng.randf_range(14.0, 110.0)
		_pine(root, Vector3(x, -10.0, z), rng.randf_range(14.0, 28.0), Color("#1f6a38"))
	_clouds(root, rng, 5 if q >= 1 else 2)

static func make_platform(world: int, size: Vector3, center: Vector3, quality: int) -> StaticBody3D:
	var th: Dictionary = THEMES[world]
	var body := StaticBody3D.new()
	body.position = center
	body.collision_layer = 2
	body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.0
	body.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	var top_col := Color(str(th["plat_top"]))
	var side_col := Color(str(th["plat_side"]))
	var side_mat := _m(side_col, 0.0, 1.0, 0.3 if world >= 2 else 0.0, 0.6)
	if world == 4:
		side_mat = _m(side_col, 0.15, 0.85, 0.2, 0.2)
	_add(body, _box(Vector3(size.x, size.y * 0.88, size.z)), side_mat, Vector3(0, -size.y * 0.06, 0))
	var top_mat := _m(top_col, 0.0, 0.9 if world == 4 else 1.0, 0.0, 0.7)
	_add(body, _box(Vector3(size.x, 0.12, size.z)), top_mat, Vector3(0, size.y * 0.44, 0))
	# glowing / decorative edge strips
	var edge_col := Color.WHITE
	var edge_em := 0.0
	match world:
		2:
			edge_col = Color("#2fd5ff")
			edge_em = 2.0
		3:
			edge_col = Color("#ffd23f")
			edge_em = 0.6
		4:
			edge_col = Color("#bff0ff")
			edge_em = 1.0
		5:
			edge_col = Color("#4dffd2")
			edge_em = 2.0
	if edge_em > 0.0:
		var y := size.y * 0.5 + 0.02
		var em := _m(edge_col, edge_em)
		_add(body, _box(Vector3(size.x, 0.06, 0.18)), em, Vector3(0, y, size.z * 0.5 - 0.09))
		_add(body, _box(Vector3(size.x, 0.06, 0.18)), em, Vector3(0, y, -size.z * 0.5 + 0.09))
		_add(body, _box(Vector3(0.18, 0.06, size.z)), em, Vector3(size.x * 0.5 - 0.09, y, 0))
		_add(body, _box(Vector3(0.18, 0.06, size.z)), em, Vector3(-size.x * 0.5 + 0.09, y, 0))
	if world == 1 and quality >= 1:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var cols := [Color("#ff6ec7"), Color("#ffe14a"), Color("#ffffff"), Color("#ff8a3d")]
		for i in 18:
			var c: Color = cols[i % cols.size()]
			var fx := rng.randf_range(-size.x * 0.5 + 0.3, size.x * 0.5 - 0.3)
			var fz := rng.randf_range(-size.z * 0.5 + 0.3, size.z * 0.5 - 0.3)
			_add(body, _sph(0.11, 6), _m(c, 0.3), Vector3(fx, size.y * 0.5 + 0.1, fz))
	return body

# ------------------------------------------------------------ world 1: Rainbow Island
static func _s_island(root: Node3D, q: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	_add(root, _plane(500, 500), _m(Color("#2fb9d8"), 0.0, 0.85, 0.2, 0.2), Vector3(0, -10, -60))
	var isl := [Vector3(-16, -2, -34), Vector3(18, 1, -44), Vector3(-26, 4, -58), Vector3(28, -3, -30), Vector3(6, 6, -70), Vector3(-8, -6, -50)]
	for p in isl:
		var pos: Vector3 = p
		var r := rng.randf_range(4.0, 7.0)
		_add(root, _cyl(r, r, 1.0, 20), _m(Color("#72d85f")), pos)
		_add(root, _cyl(r, 0.1, r * 1.3, 16), _m(Color("#8d5a2b")), pos + Vector3(0, -0.5 - r * 0.65, 0))
		if q >= 1:
			for i in 2:
				var tp := pos + Vector3(rng.randf_range(-r * 0.6, r * 0.6), 0.5, rng.randf_range(-r * 0.6, r * 0.6))
				_add(root, _cyl(0.2, 0.25, 1.4, 6), _m(Color("#7a4a22")), tp + Vector3(0, 0.7, 0))
				_add(root, _cyl(0.0, 1.1, 2.2, 8), _m(Color("#2fa84f")), tp + Vector3(0, 2.2, 0))
	var n_clouds := 0 if _night else (7 if q >= 1 else 3)
	for i in n_clouds:
		var c := Vector3(rng.randf_range(-45, 45), rng.randf_range(8, 22), rng.randf_range(-80, -40))
		for k in 4:
			var s := rng.randf_range(2.0, 3.5)
			var mi := _add(root, _sph(s, 10), _m(Color.WHITE, 0.3, 0.95), c + Vector3(k * 2.4 - 3.6, rng.randf_range(-0.5, 0.5), 0))
			mi.scale = Vector3(1.0, 0.6, 1.0)
	var rc := [Color("#ff3b3b"), Color("#ff9f1c"), Color("#ffe14a"), Color("#4dff88"), Color("#4da6ff"), Color("#6a5cff"), Color("#b46bff")]
	for i in rc.size():
		var col: Color = rc[i]
		_add(root, _torus(34.0 + i * 1.0, 35.0 + i * 1.0, 48, 6), _m(col, 0.8), Vector3(0, -6, -90), Vector3(deg_to_rad(90.0), 0, 0))

# ------------------------------------------------------------ world 2: Neon City
static func _s_city(root: Node3D, q: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 22
	_add(root, _plane(500, 500), _m(Color("#0b0824")), Vector3(0, -14, -60))
	var grid := _m(Color("#ff2fd0"), 1.5)
	for i in range(-10, 11):
		_add(root, _box(Vector3(0.1, 0.05, 200)), grid, Vector3(i * 6, -13.9, -60))
	for i in 20:
		_add(root, _box(Vector3(200, 0.05, 0.1)), grid, Vector3(0, -13.9, -i * 8.0))
	var n := 26 if q >= 1 else 14
	var neon_cols := [Color("#2fd5ff"), Color("#ff2fd0"), Color("#ffe14a")]
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var h := rng.randf_range(14.0, 46.0)
		var w := rng.randf_range(4.0, 8.0)
		var x := side * rng.randf_range(14.0, 42.0)
		var z := -rng.randf_range(16.0, 90.0)
		_add(root, _box(Vector3(w, h, w)), _m(Color("#1a1448"), 0.0, 1.0, 0.4, 0.4), Vector3(x, h * 0.5 - 14.0, z))
		var neon: Color = neon_cols[i % 3]
		for k in 3:
			_add(root, _box(Vector3(w * 0.9, 0.25, 0.1)), _m(neon, 2.0), Vector3(x, rng.randf_range(0.0, h) - 14.0, z + w * 0.5 + 0.06))
	for i in 4:
		var col: Color = neon_cols[i % 2]
		_add(root, _torus(5.0, 5.5, 32, 6), _m(col, 2.2), Vector3((i - 1.5) * 16.0, 10.0 + (i % 2) * 6.0, -45.0 - i * 8.0), Vector3(deg_to_rad(90.0), 0, 0))

# ------------------------------------------------------------ world 3: Ancient Temple
static func _s_temple(root: Node3D, q: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	_add(root, _plane(500, 500), _m(Color("#d9b46a")), Vector3(0, -10, -60))
	var mcols := [Color("#8a6a4a"), Color("#a07850"), Color("#7a6a60")]
	for i in 7:
		var h := rng.randf_range(30.0, 55.0)
		var r := rng.randf_range(18.0, 30.0)
		var mc: Color = mcols[i % 3]
		_add(root, _cyl(0.0, r, h, 8), _m(mc), Vector3(-90.0 + i * 30.0, h * 0.5 - 10.0, rng.randf_range(-130.0, -90.0)))
	var stone := _m(Color("#d8c9a0"))
	var ncol := 12 if q >= 1 else 6
	for i in ncol:
		var side := -1.0 if i % 2 == 0 else 1.0
		var h := rng.randf_range(8.0, 18.0)
		var x := side * rng.randf_range(16.0, 32.0)
		var z := -rng.randf_range(20.0, 70.0)
		_add(root, _cyl(0.8, 0.95, h, 12), stone, Vector3(x, h * 0.5 - 10.0, z))
		_add(root, _box(Vector3(2.4, 0.7, 2.4)), stone, Vector3(x, h - 10.0 + 0.35, z))
		_add(root, _box(Vector3(2.2, 0.6, 2.2)), stone, Vector3(x, -9.7, z))
	for sx in [-24.0, 24.0]:
		var x: float = sx
		var base := Vector3(x, -10.0, -48.0)
		_add(root, _box(Vector3(7, 2, 7)), stone, base + Vector3(0, 1, 0))
		_add(root, _box(Vector3(3.2, 8, 3.2)), _m(Color("#bfae82")), base + Vector3(0, 6, 0))
		_add(root, _sph(1.7, 12), _m(Color("#bfae82")), base + Vector3(0, 11.5, 0))
		_add(root, _box(Vector3(3.6, 0.5, 3.6)), _m(Color("#ffd23f"), 0.6), base + Vector3(0, 2.3, 0))

# ------------------------------------------------------------ world 4: Ice Land
static func _s_snow(root: Node3D, q: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	_add(root, _plane(500, 500), _m(Color("#e9f6ff"), 0.0, 1.0, 0.1, 0.3), Vector3(0, -10, -60))
	for i in 8:
		var h := rng.randf_range(26.0, 50.0)
		var r := rng.randf_range(16.0, 28.0)
		_add(root, _cyl(0.0, r, h, 8), _m(Color("#f4fbff")), Vector3(-100.0 + i * 28.0, h * 0.5 - 10.0, rng.randf_range(-130.0, -85.0)))
		_add(root, _cyl(0.0, r * 0.45, h * 0.35, 8), _m(Color("#9fd8ff")), Vector3(-100.0 + i * 28.0, h * 0.82 - 10.0, rng.randf_range(-84.0, -80.0)))
	var ncr := 14 if q >= 1 else 6
	for i in ncr:
		var side := -1.0 if i % 2 == 0 else 1.0
		var h := rng.randf_range(5.0, 14.0)
		var r := rng.randf_range(1.0, 2.2)
		var x := side * rng.randf_range(10.0, 35.0)
		var z := -rng.randf_range(18.0, 75.0)
		_add(root, _cyl(0.0, r, h, 6), _m(Color("#7fe0ff"), 0.35, 0.7, 0.1, 0.1),
			Vector3(x, h * 0.5 - 10.0, z), Vector3(0, 0, rng.randf_range(-0.3, 0.3)))
	if q >= 1:
		var sn := CPUParticles3D.new()
		sn.amount = 120 if q == 1 else 260
		sn.lifetime = 7.0
		sn.preprocess = 7.0
		sn.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		sn.emission_box_extents = Vector3(30, 0.5, 30)
		sn.direction = Vector3(0.2, -1, 0)
		sn.spread = 15.0
		sn.initial_velocity_min = 1.5
		sn.initial_velocity_max = 3.0
		sn.gravity = Vector3(0, -0.5, 0)
		sn.scale_amount_min = 0.12
		sn.scale_amount_max = 0.25
		var flake := _sph(0.5, 6)
		flake.material = _unshaded(Color.WHITE)
		sn.mesh = flake
		sn.position = Vector3(0, 22, -20)
		root.add_child(sn)
		sn.emitting = true

# ------------------------------------------------------------ world 5: Cosmic Space
static func _s_space(root: Node3D, q: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _sph(0.25, 6)
	mm.instance_count = 160 if q >= 1 else 80
	for i in mm.instance_count:
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 1.0), rng.randf_range(-1.0, -0.1)).normalized()
		var s := rng.randf_range(0.5, 1.6)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), dir * rng.randf_range(100.0, 150.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _unshaded(Color.WHITE)
	root.add_child(mmi)
	var planets := [
		[Vector3(-34, 20, -95), 14.0, Color("#ff7a4d")],
		[Vector3(40, 34, -120), 20.0, Color("#4da6ff")],
		[Vector3(10, 55, -150), 10.0, Color("#b46bff")],
	]
	for p in planets:
		var pos: Vector3 = p[0]
		var r: float = p[1]
		var col: Color = p[2]
		_add(root, _sph(r, 24), _m(col, 0.25, 1.0, 0.0, 0.7), pos)
		if r > 12.0:
			_add(root, _torus(r * 1.4, r * 1.7, 40, 4), _m(col.lightened(0.3), 0.4, 0.7), pos, Vector3(deg_to_rad(80.0), 0, deg_to_rad(15.0)))
	var neb := [Color("#7a2bff"), Color("#2b6aff"), Color("#ff2bd0")]
	for i in 3:
		var nc: Color = neb[i]
		_add(root, _sph(30.0, 12), _m(nc, 0.6, 0.12), Vector3(-50.0 + i * 50.0, 10.0 + i * 8.0, -140.0))
	var n_rocks := 14 if q >= 1 else 6
	for i in n_rocks:
		var side := -1.0 if i % 2 == 0 else 1.0
		var sz := rng.randf_range(1.5, 4.0)
		var pos := Vector3(side * rng.randf_range(12.0, 40.0), rng.randf_range(-6.0, 20.0), -rng.randf_range(20.0, 80.0))
		_add(root, _box(Vector3(sz, sz * 0.7, sz)), _m(Color("#2a2d55"), 0.0, 1.0, 0.4, 0.5), pos,
			Vector3(rng.randf(), rng.randf(), rng.randf()) * 3.0)
		_add(root, _box(Vector3(sz * 1.02, 0.12, sz * 1.02)), _m(Color("#4dffd2"), 1.8), pos + Vector3(0, sz * 0.36, 0),
			Vector3(0, 0, 0))
