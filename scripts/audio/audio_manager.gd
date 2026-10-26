class_name AudioManager
extends Node
## All sounds are synthesised in code at startup (no external audio assets, no licences needed).

const RATE := 22050
const MUSIC_RATE := 11025
const MUSIC := {
	1: {"root": 261.63, "scale": [0, 2, 4, 7, 9], "bpm": 104, "wave": 0},
	2: {"root": 220.0, "scale": [0, 3, 5, 7, 10], "bpm": 124, "wave": 1},
	3: {"root": 196.0, "scale": [0, 1, 4, 5, 7, 8], "bpm": 88, "wave": 3},
	4: {"root": 329.63, "scale": [0, 2, 4, 7, 11], "bpm": 80, "wave": 2},
	5: {"root": 174.61, "scale": [0, 3, 7, 10, 14], "bpm": 96, "wave": 4},
}

var sfx_volume := 0.8
var music_volume := 0.5

var _cache: Dictionary = {}
var _music_cache: Dictionary = {}
var _players: Array = []
var _music: AudioStreamPlayer
var _last_play: Dictionary = {}
var _music_world := -1

func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_build_sfx()

func _wav(samples: PackedFloat32Array, rate: int = RATE, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s

func _tone(dur: float, f0: float, f1: float, decay: float, noise: float = 0.0, harm: float = 0.0, vol: float = 0.8) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := float(i) / float(n)
		var f := lerpf(f0, f1, k)
		phase += TAU * f / RATE
		var env := exp(-t * decay) * minf(1.0, t * 400.0)
		var s := sin(phase) + harm * sin(phase * 2.5)
		if noise > 0.0:
			lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.35)
			s = lerpf(s, lp * 2.0, noise)
		out[i] = s * env * vol
	return out

func _seq(notes: Array, note_len: float, decay: float, harm: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in notes:
		var ff: float = f
		out.append_array(_tone(note_len, ff, ff, decay, 0.0, harm, 0.6))
	return out

func _build_sfx() -> void:
	_cache["launch"] = _wav(_tone(0.25, 300.0, 700.0, 8.0, 0.15, 0.2))
	_cache["hit_wood"] = _wav(_tone(0.18, 180.0, 90.0, 22.0, 0.5, 0.1))
	_cache["hit_stone"] = _wav(_tone(0.22, 120.0, 60.0, 18.0, 0.7))
	_cache["hit_metal"] = _wav(_tone(0.5, 900.0, 880.0, 6.0, 0.0, 0.8))
	_cache["hit_glass"] = _wav(_tone(0.3, 2400.0, 2200.0, 14.0, 0.1, 0.6, 0.5))
	_cache["hit_rubber"] = _wav(_tone(0.25, 400.0, 120.0, 10.0, 0.0, 0.1))
	_cache["hit_crystal"] = _wav(_tone(0.45, 1500.0, 1500.0, 7.0, 0.0, 0.9, 0.5))
	_cache["shatter"] = _wav(_tone(0.5, 3000.0, 1000.0, 9.0, 0.9, 0.3, 0.7))
	_cache["fall"] = _wav(_tone(0.3, 100.0, 50.0, 15.0, 0.8))
	_cache["explosion"] = _wav(_tone(0.9, 90.0, 30.0, 4.0, 0.9, 0.0, 1.0))
	_cache["coin"] = _wav(_seq([988.0, 1319.0], 0.1, 9.0, 0.3))
	_cache["star"] = _wav(_seq([660.0, 880.0, 1320.0], 0.09, 8.0, 0.4))
	_cache["win"] = _wav(_seq([523.0, 659.0, 784.0, 1047.0], 0.14, 6.0, 0.3))
	_cache["lose"] = _wav(_seq([392.0, 330.0, 262.0, 196.0], 0.16, 5.0, 0.2))
	_cache["click"] = _wav(_tone(0.06, 800.0, 600.0, 40.0))

func play(sfx: String, vol: float = 1.0, pitch: float = 1.0) -> void:
	if not _cache.has(sfx) or sfx_volume <= 0.001:
		return
	var now := Time.get_ticks_msec()
	if _last_play.has(sfx) and now - int(_last_play[sfx]) < 60:
		return
	_last_play[sfx] = now
	for p in _players:
		var pl: AudioStreamPlayer = p
		if not pl.playing:
			pl.stream = _cache[sfx]
			pl.volume_db = linear_to_db(clampf(vol * sfx_volume, 0.001, 1.0))
			pl.pitch_scale = pitch
			pl.play()
			return

func refresh_volume() -> void:
	if _music != null:
		_music.volume_db = linear_to_db(clampf(music_volume, 0.001, 1.0)) - 6.0
		if music_volume <= 0.001:
			_music.stream_paused = true
		else:
			_music.stream_paused = false

func play_music(world: int) -> void:
	if world == _music_world and _music.playing:
		refresh_volume()
		return
	_music_world = world
	if not _music_cache.has(world):
		_music_cache[world] = _gen_music(world)
	_music.stream = _music_cache[world]
	refresh_volume()
	_music.play()

func _gen_music(world: int) -> AudioStreamWAV:
	var cfg: Dictionary = MUSIC.get(world, MUSIC[1])
	var scale: Array = cfg["scale"]
	var step_len := 60.0 / float(cfg["bpm"]) / 2.0
	var steps := 16
	var total := int(step_len * steps * MUSIC_RATE)
	var buf := PackedFloat32Array()
	buf.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = world * 7919
	var wave: int = int(cfg["wave"])
	var root: float = float(cfg["root"])
	for s in steps:
		var deg: int = int(scale[rng.randi() % scale.size()])
		var bass := (s % 4 == 0)
		var f := root * pow(2.0, float(deg) / 12.0) * (0.5 if bass else (2.0 if s % 2 == 1 else 1.0))
		var amp := 0.2 if bass else 0.11
		var start := int(s * step_len * MUSIC_RATE)
		var note_samples := int(step_len * 1.8 * MUSIC_RATE)
		for i in note_samples:
			var t := float(i) / MUSIC_RATE
			var env := exp(-t * 3.5) * minf(1.0, t * 80.0)
			var ph := TAU * f * t
			var v := 0.0
			match wave:
				0:
					v = sin(ph)
				1:
					v = sin(ph) + 0.35 * sin(ph * 3.0)
				2:
					v = asin(sin(ph)) * 0.64
				3:
					v = sin(ph) + 0.5 * sin(ph * 2.76)
				_:
					v = sin(ph) + 0.5 * sin(ph * 2.0) + 0.33 * sin(ph * 3.0)
			buf[(start + i) % total] += v * env * amp
	return _wav(buf, MUSIC_RATE, true)
