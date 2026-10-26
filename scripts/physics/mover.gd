class_name Mover
extends AnimatableBody3D
## A neon bar sliding back and forth. Pushes blocks and balls physically.

var origin := Vector3.ZERO
var axis := Vector3.RIGHT
var amplitude := 3.0
var speed := 1.0
var _t := 0.0

func setup(def: Dictionary, color: Color) -> void:
	var p: Array = def["pos"]
	var s: Array = def["size"]
	var a: Array = def["axis"]
	origin = Vector3(float(p[0]), float(p[1]), float(p[2]))
	axis = Vector3(float(a[0]), float(a[1]), float(a[2])).normalized()
	amplitude = float(def.get("amplitude", 3.0))
	speed = float(def.get("speed", 1.0))
	position = origin
	sync_to_physics = true
	collision_layer = 2
	collision_mask = 0
	var size := Vector3(float(s[0]), float(s[1]), float(s[2]))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.2
	mi.material_override = m
	add_child(mi)

func _physics_process(delta: float) -> void:
	_t += delta
	position = origin + axis * sin(_t * speed) * amplitude
