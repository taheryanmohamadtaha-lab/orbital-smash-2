extends Node
## Autoload "GameState": progress, settings, shop, data tables, audio.

signal coins_changed(total: int)

const BALL_ORDER := ["standard", "heavy", "bouncy", "blast", "precision"]
const LEVELS_PER_WORLD := 6

var data: Dictionary = {}
var ball_types: Dictionary = {}
var materials: Dictionary = {}
var shop_colors: Array = []
var shop_trails: Array = []
var worlds: Array = []
var levels: Array = []
var current_level_id := 1
var start_screen := "main"
var audio: AudioManager

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = SaveManager.load_data()
	ball_types = LevelLoader.read_json("res://data/items/balls.json").get("balls", {})
	materials = LevelLoader.read_json("res://data/items/materials.json").get("materials", {})
	var shop := LevelLoader.read_json("res://data/items/shop.json")
	shop_colors = shop.get("colors", [])
	shop_trails = shop.get("trails", [])
	worlds = LevelLoader.read_json("res://data/worlds/worlds.json").get("worlds", [])
	levels = LevelLoader.load_all()
	audio = AudioManager.new()
	add_child(audio)
	apply_settings()
	_setup_theme()
	current_level_id = clampi(int(data["unlocked_level"]), 1, maxi(1, levels.size()))

func _setup_theme() -> void:
	var th := Theme.new()
	th.default_font_size = 36
	var fp := "res://assets/fonts/Vazirmatn.ttf"
	if ResourceLoader.exists(fp):
		th.default_font = load(fp)
	get_tree().root.theme = th

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()

# ---------------------------------------------------------------- save
func save() -> void:
	SaveManager.save_data(data)

func reset_progress() -> void:
	var settings: Dictionary = data["settings"]
	data = SaveManager.default_data()
	data["settings"] = settings
	current_level_id = 1
	save()
	coins_changed.emit(0)

# ---------------------------------------------------------------- settings
func setting(key: String) -> Variant:
	var s: Dictionary = data["settings"]
	return s.get(key)

func set_setting(key: String, value: Variant) -> void:
	var s: Dictionary = data["settings"]
	s[key] = value
	apply_settings()
	save()

func apply_settings() -> void:
	Loc.lang = str(setting("language"))
	if audio != null:
		audio.sfx_volume = float(setting("sfx"))
		audio.music_volume = float(setting("music"))
		audio.refresh_volume()

func vibrate(ms: int) -> void:
	if bool(setting("vibration")):
		Input.vibrate_handheld(ms)

# ---------------------------------------------------------------- levels
func level_count() -> int:
	return levels.size()

func get_level(id: int) -> Dictionary:
	if id >= 1 and id <= levels.size():
		return levels[id - 1]
	return {}

func world_name(world_id: int) -> String:
	for w in worlds:
		var wd: Dictionary = w
		if int(wd["id"]) == world_id:
			return str(wd["name_fa"]) if Loc.lang == "fa" else str(wd["name_en"])
	return ""

func level_name(level: Dictionary) -> String:
	return str(level["name_fa"]) if Loc.lang == "fa" else str(level["name_en"])

func is_level_unlocked(id: int) -> bool:
	return id <= int(data["unlocked_level"])

func level_record(id: int) -> Dictionary:
	var lv: Dictionary = data["levels"]
	if lv.has(str(id)):
		return lv[str(id)]
	return {"stars": 0, "best_score": 0}

func total_stars() -> int:
	var n := 0
	var lv: Dictionary = data["levels"]
	for k in lv.keys():
		var rec: Dictionary = lv[k]
		n += int(rec.get("stars", 0))
	return n

## Records a win. Returns {"coins": gained, "new_best": bool, "best": int}.
func complete_level(id: int, stars: int, score: int, coin_reward: int) -> Dictionary:
	var lv: Dictionary = data["levels"]
	var rec: Dictionary = level_record(id).duplicate()
	var first := int(rec["stars"]) == 0
	var new_best := score > int(rec["best_score"])
	rec["stars"] = maxi(int(rec["stars"]), stars)
	rec["best_score"] = maxi(int(rec["best_score"]), score)
	lv[str(id)] = rec
	var gained := coin_reward if first else int(round(float(coin_reward) * 0.25))
	data["coins"] = int(data["coins"]) + gained
	if id >= int(data["unlocked_level"]) and id < levels.size():
		data["unlocked_level"] = id + 1
	var wl: Array = []
	for w in range(1, 6):
		if int(data["unlocked_level"]) >= (w - 1) * LEVELS_PER_WORLD + 1:
			wl.append(w)
	data["worlds_unlocked"] = wl
	save()
	coins_changed.emit(int(data["coins"]))
	return {"coins": gained, "new_best": new_best, "best": int(rec["best_score"])}

# ---------------------------------------------------------------- balls & shop
func owns_ball(type_id: String) -> bool:
	if not ball_types.has(type_id):
		return false
	var def: Dictionary = ball_types[type_id]
	return int(def["unlock_level"]) <= int(data["unlocked_level"]) or (data["balls_owned"] as Array).has(type_id)

func coins() -> int:
	return int(data["coins"])

func owned(kind: String, id: String) -> bool:
	return (data[kind + "_owned"] as Array).has(id)

func buy(kind: String, id: String, price: int) -> bool:
	if owned(kind, id):
		return true
	if coins() < price:
		return false
	data["coins"] = coins() - price
	(data[kind + "_owned"] as Array).append(id)
	save()
	coins_changed.emit(coins())
	return true

func equip(kind: String, id: String) -> void:
	if owned(kind, id):
		data["ball_" + ("color" if kind == "colors" else "trail")] = id
		save()

func equipped_color_def() -> Dictionary:
	for c in shop_colors:
		var cd: Dictionary = c
		if str(cd["id"]) == str(data["ball_color"]):
			return cd
	return {"id": "default", "color": "#ffffff"}

func equipped_trail_def() -> Dictionary:
	for t in shop_trails:
		var td: Dictionary = t
		if str(td["id"]) == str(data["ball_trail"]):
			return td
	return {"id": "none", "color": "#ffffff"}
