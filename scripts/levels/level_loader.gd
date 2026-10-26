class_name LevelLoader
extends RefCounted
## Loads data-driven level files res://data/levels/level_NN.json

static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
	var parsed = json.data
	if parsed is Dictionary:
		return parsed
	return {}

static func load_all() -> Array:
	var out: Array = []
	for i in range(1, 500):
		var path := "res://data/levels/level_%02d.json" % i
		if not FileAccess.file_exists(path):
			break
		var lv := read_json(path)
		var errs := LevelValidator.validate(lv)
		if errs.is_empty():
			out.append(lv)
		else:
			push_error("Level %d invalid: %s" % [i, ", ".join(errs)])
			break
	return out
