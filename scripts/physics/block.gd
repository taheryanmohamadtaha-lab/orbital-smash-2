class_name Block
extends RigidBody3D
## A destructible building block. Material values come from data/items/materials.json.

signal broke(block: Block)
signal hit(block: Block, impact: float, from_ball: bool)

var material_id := "wood"
var mat: Dictionary = {}
var is_target := false
var is_protected := false
var size := Vector3.ONE
var hp := 1.0
var breakable := true
var break_threshold := 20.0
var score_value := 10
var dead := false
var fallen := false
var last_velocity := Vector3.ZERO
var color := Color.WHITE
var _mesh_mat: StandardMaterial3D
var _cracked := false

func setup(def: Dictionary, material: Dictionary) -> void:
	mat = material
	material_id = str(def["material"])
	is_target = bool(def.get("target", false)) or material_id == "crystal"
	is_protected = bool(def.get("protected", false))
	var sz: Array = def["size"]
	var p: Array = def["pos"]
	size = Vector3(float(sz[0]), float(sz[1]), float(sz[2]))
	position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	mass = maxf(0.05, float(mat["density"]) * size.x * size.y * size.z)
	breakable = bool(mat.get("breakable", true))
	break_threshold = float(mat.get("threshold", 20.0))
	score_value = int(mat.get("score", 10))
	color = Color(str(mat["color"]))
	if is_protected:
		color = color.lerp(Color("#ff3030"), 0.55)

	var pm := PhysicsMaterial.new()
	pm.friction = float(mat["friction"])
	pm.bounce = float(mat["bounce"])
	physics_material_override = pm
	collision_layer = 1
	collision_mask = 3
	angular_damp = 0.6
	can_sleep = true
	sleeping = true  # the structure stays perfectly still until hit
	contact_monitor = true
	max_contacts_reported = 3

	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size * 0.98
	cs.shape = sh
	add_child(cs)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size * 0.985
	mi.mesh = bm
	_mesh_mat = StandardMaterial3D.new()
	var alpha := float(mat.get("alpha", 1.0))
	_mesh_mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0:
		_mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_mat.roughness = 0.6 if material_id != "glass" else 0.1
	_mesh_mat.metallic = float(mat.get("metallic", 0.0))
	if material_id == "crystal":
		_mesh_mat.emission_enabled = true
		_mesh_mat.emission = color
		_mesh_mat.emission_energy_multiplier = float(mat.get("emission", 1.0))
	elif is_protected:
		_mesh_mat.emission_enabled = true
		_mesh_mat.emission = Color("#ff2020")
		_mesh_mat.emission_energy_multiplier = 0.5
	elif is_target:
		_mesh_mat.emission_enabled = true
		_mesh_mat.emission = Color("#ffd23f")
		_mesh_mat.emission_energy_multiplier = 0.6
	mi.material_override = _mesh_mat
	add_child(mi)

	add_to_group("blocks")
	body_entered.connect(_on_body_entered)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	last_velocity = state.linear_velocity

func _on_body_entered(body: Node) -> void:
	if dead:
		return
	var other_v := Vector3.ZERO
	var other_mass := 2.0
	var from_ball := false
	var dynamic := false
	if body is Block:
		other_v = (body as Block).last_velocity
		other_mass = (body as Block).mass
		dynamic = true
	elif body is Ball:
		other_v = (body as Ball).last_velocity
		other_mass = (body as Ball).mass
		from_ball = true
		dynamic = true
	var v_rel := (last_velocity - other_v).length()
	if v_rel < 2.5:
		return
	var impact := v_rel * sqrt(other_mass) if dynamic else v_rel * 1.2
	if impact < 4.0:
		return
	hit.emit(self, impact, from_ball)
	apply_impact(impact)

## Accumulates damage. Used by collisions and by blast explosions.
func apply_impact(impact: float) -> void:
	if dead or not breakable:
		return
	if impact > break_threshold * 0.4:
		hp -= pow(impact / break_threshold, 2.0) * 0.6
		if hp <= 0.0:
			force_break()
		elif hp < 0.5 and not _cracked:
			_cracked = true
			_mesh_mat.albedo_color = _mesh_mat.albedo_color.darkened(0.25)

func force_break() -> void:
	if dead or not breakable:
		return
	dead = true
	broke.emit(self)
