class_name Ball
extends RigidBody3D
## A launched ball. Special abilities (blast / pierce) are handled by game.gd.

signal hit(ball: Ball, body: Node, rel_speed: float)

var type_id := "standard"
var def: Dictionary = {}
var last_velocity := Vector3.ZERO
var exploded := false
var age := 0.0

func setup(type_name: String, type_def: Dictionary, color: Color, trail_def: Dictionary, show_trail: bool) -> void:
	type_id = type_name
	def = type_def
	var r := float(def["radius"])
	mass = float(def["mass"])
	var pm := PhysicsMaterial.new()
	pm.bounce = float(def["bounce"])
	pm.friction = float(def["friction"])
	physics_material_override = pm
	collision_layer = 1
	collision_mask = 3
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = 0.0
	angular_damp = 0.2
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = r
	cs.shape = sh
	add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.3
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.35
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	body_entered.connect(_on_body_entered)
	if show_trail and str(trail_def.get("id", "none")) != "none":
		_add_trail(Color(str(trail_def["color"])), r)

func _add_trail(color: Color, r: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.55
	p.local_coords = false
	p.direction = Vector3.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.4
	p.gravity = Vector3.ZERO
	p.scale_amount_min = r * 0.8
	p.scale_amount_max = r * 1.1
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
	add_child(p)
	p.emitting = true

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	last_velocity = state.linear_velocity

func _physics_process(delta: float) -> void:
	age += delta

func _on_body_entered(body: Node) -> void:
	var other_v := Vector3.ZERO
	if body is Block:
		other_v = (body as Block).last_velocity
	hit.emit(self, body, (last_velocity - other_v).length())
