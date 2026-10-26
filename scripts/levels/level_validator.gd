class_name LevelValidator
extends RefCounted
## Detects incomplete levels or invalid coordinates. Returns a list of error strings.

const WIN_TYPES := ["destroy_targets", "knock_off", "topple"]
const MATERIALS := ["wood", "glass", "stone", "metal", "rubber", "crystal"]
const BALLS := ["standard", "heavy", "bouncy", "blast", "precision"]
const REQUIRED := ["id", "world", "name_fa", "name_en", "difficulty", "balls", "win", "reward", "stars", "platform", "camera", "blocks"]

static func _vec3_ok(v) -> bool:
	if not (v is Array) or v.size() != 3:
		return false
	for x in v:
		if not (x is float or x is int) or not is_finite(float(x)):
			return false
	return true

static func validate(level: Dictionary) -> Array:
	var errs: Array = []
	for key in REQUIRED:
		if not level.has(key):
			errs.append("missing key '%s'" % key)
	if not errs.is_empty():
		return errs
	var world := int(level["world"])
	if world < 1 or world > 5:
		errs.append("world out of range")
	var balls: Dictionary = level["balls"]
	if balls.is_empty():
		errs.append("no balls")
	for k in balls.keys():
		if not BALLS.has(str(k)) or int(balls[k]) <= 0:
			errs.append("bad ball entry %s" % str(k))
	var win: Dictionary = level["win"]
	var wtype := str(win.get("type", ""))
	if not WIN_TYPES.has(wtype):
		errs.append("bad win type")
	if wtype == "knock_off" and int(win.get("count", 0)) <= 0:
		errs.append("knock_off needs count")
	var plat: Dictionary = level["platform"]
	var psize: Array = plat.get("size", [])
	if psize.size() != 2:
		errs.append("platform.size must be [w, d]")
		return errs
	var pw := float(psize[0])
	var pd := float(psize[1])
	var pz := float(plat.get("center_z", 0.0))
	var cam: Dictionary = level["camera"]
	if not (_vec3_ok(cam.get("position")) and _vec3_ok(cam.get("look_at"))):
		errs.append("bad camera")
	var targets := 0
	var blocks: Array = level["blocks"]
	if blocks.is_empty():
		errs.append("no blocks")
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		if not MATERIALS.has(str(b.get("material", ""))):
			errs.append("block %d: bad material" % i)
			continue
		if not (_vec3_ok(b.get("pos")) and _vec3_ok(b.get("size"))):
			errs.append("block %d: bad vectors" % i)
			continue
		var p: Array = b["pos"]
		var s: Array = b["size"]
		if minf(float(s[0]), minf(float(s[1]), float(s[2]))) < 0.05:
			errs.append("block %d: too small" % i)
		if absf(float(p[0])) + float(s[0]) * 0.5 > pw * 0.5 + 0.01:
			errs.append("block %d: outside platform (x)" % i)
		if float(p[2]) - float(s[2]) * 0.5 < pz - pd * 0.5 - 0.01 or float(p[2]) + float(s[2]) * 0.5 > pz + pd * 0.5 + 0.01:
			errs.append("block %d: outside platform (z)" % i)
		if float(p[1]) - float(s[1]) * 0.5 < -0.01:
			errs.append("block %d: below platform" % i)
		if str(b["material"]) == "crystal" or bool(b.get("target", false)):
			targets += 1
	if (wtype == "destroy_targets" or wtype == "topple") and targets == 0:
		errs.append("this win type needs at least one target")
	for m in level.get("movers", []):
		if not (m is Dictionary and _vec3_ok(m.get("pos")) and _vec3_ok(m.get("size")) and _vec3_ok(m.get("axis"))):
			errs.append("bad mover")
	return errs
