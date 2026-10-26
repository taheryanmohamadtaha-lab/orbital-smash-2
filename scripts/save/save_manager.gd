class_name SaveManager
extends RefCounted
## Persistent progress storage with backup + versioning.

const PATH := "user://save.json"
const BACKUP := "user://save.bak.json"
const VERSION := 1

static func default_data() -> Dictionary:
	return {
		"version": VERSION,
		"coins": 0,
		"unlocked_level": 1,
		"levels": {},
		"worlds_unlocked": [1],
		"balls_owned": ["standard"],
		"selected_ball": "standard",
		"colors_owned": ["default"],
		"ball_color": "default",
		"trails_owned": ["none"],
		"ball_trail": "none",
		"settings": {
			"sfx": 0.8,
			"music": 0.5,
			"effects": 2,
			"shake": true,
			"vibration": true,
			"quality": 1,
			"language": "fa",
			"tod": 0,
			"scenery": "auto",
		},
	}

static func load_data() -> Dictionary:
	var d := _read(PATH)
	if d.is_empty():
		d = _read(BACKUP)
	if d.is_empty():
		return default_data()
	return _merge(default_data(), d)

static func save_data(data: Dictionary) -> bool:
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(PATH, BACKUP)
		DirAccess.remove_absolute(PATH)
	return DirAccess.rename_absolute(tmp, PATH) == OK

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed = json.data
	if parsed is Dictionary:
		return parsed
	return {}

## Fills missing keys from defaults (also handles older save versions).
static func _merge(defaults: Dictionary, loaded: Dictionary) -> Dictionary:
	var out: Dictionary = defaults.duplicate(true)
	for k in loaded.keys():
		if out.has(k) and out[k] is Dictionary and loaded[k] is Dictionary and k != "levels":
			out[k] = _merge(out[k], loaded[k])
		else:
			out[k] = loaded[k]
	out["version"] = VERSION
	return out
