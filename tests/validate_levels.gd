extends SceneTree
## godot --headless --path . --script tests/validate_levels.gd

func _init() -> void:
	var failures := 0
	var count := 0
	for i in range(1, 500):
		var path := "res://data/levels/level_%02d.json" % i
		if not FileAccess.file_exists(path):
			break
		count += 1
		var errs := LevelValidator.validate(LevelLoader.read_json(path))
		if not errs.is_empty():
			failures += 1
			print("FAIL level %d: %s" % [i, ", ".join(errs)])
	if count < 30:
		failures += 1
		print("FAIL: expected >= 30 levels, found %d" % count)
	print("levels checked: %d, failures: %d" % [count, failures])
	quit(1 if failures > 0 else 0)
