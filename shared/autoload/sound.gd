extends Node
## BGM 再生と、効果音の実行時合成を担当する。

const MIX_RATE: int = 22050
const BGM_MARCH: String = "res://shared/sounds/gunkan_march.ogg"

var _bgm: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _se_pool: Array = []
var _se_index: int = 0
var _streams: Dictionary = {}
var _last_play_ms: Dictionary = {}
var _bgm_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm = AudioStreamPlayer.new()
	_bgm.volume_db = -8.0
	add_child(_bgm)
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -14.0
	add_child(_ambience)
	for i: int in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_se_pool.append(p)
	_build_streams()


# ---------------------------------------------------------------- 公開 API

func play_march() -> void:
	if not ResourceLoader.exists(BGM_MARCH):
		return
	var stream: AudioStream = load(BGM_MARCH)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_fade_in_bgm(stream, -8.0)
	_ambience.stream = _streams["hall"]
	_ambience.volume_db = -16.0
	_ambience.play()


func play_town() -> void:
	_fade_in_bgm(null, -8.0)
	_ambience.stream = _streams["town"]
	_ambience.volume_db = -20.0
	_ambience.play()


func play(se_name: String, volume_db: float = 0.0, pitch: float = 1.0, min_interval_ms: int = 0) -> void:
	if not _streams.has(se_name):
		return
	var now: int = Time.get_ticks_msec()
	if min_interval_ms > 0 and now - int(_last_play_ms.get(se_name, -100000)) < min_interval_ms:
		return
	_last_play_ms[se_name] = now
	var p: AudioStreamPlayer = _se_pool[_se_index]
	_se_index = (_se_index + 1) % _se_pool.size()
	p.stream = _streams[se_name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func _fade_in_bgm(stream: AudioStream, target_db: float) -> void:
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	if stream == null:
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_bgm, "volume_db", -60.0, 0.6)
		_bgm_tween.tween_callback(_bgm.stop)
		return
	_bgm.stream = stream
	_bgm.volume_db = -40.0
	_bgm.play()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm, "volume_db", target_db, 1.0)


# ---------------------------------------------------------------- 合成

func _build_streams() -> void:
	_streams["clack"] = _to_wav(_synth_clack(), false)
	_streams["clack_low"] = _to_wav(_synth_clack_low(), false)
	_streams["launch"] = _to_wav(_synth_launch(), false)
	_streams["spring"] = _to_wav(_synth_spring(), false)
	_streams["chime"] = _to_wav(_synth_chime([1318.5, 1568.0, 2093.0]), false)
	_streams["bigchime"] = _to_wav(_synth_chime([1046.5, 1318.5, 1568.0, 2093.0, 2637.0, 3136.0]), false)
	_streams["pour"] = _to_wav(_synth_pour(), false)
	_streams["hole"] = _to_wav(_synth_hole(), false)
	_streams["door"] = _to_wav(_synth_door_bell(), false)
	_streams["click"] = _to_wav(_synth_click(), false)
	_streams["step"] = _to_wav(_synth_step(), false)
	_streams["hall"] = _to_wav(_synth_hall_ambience(), true)
	_streams["town"] = _to_wav(_synth_town_ambience(), true)


func _to_wav(samples: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * MIX_RATE))
	return b


## 金属球が釘に当たる「カチッ」
func _synth_clack() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.08)
	for i: int in b.size():
		var t: float = float(i) / MIX_RATE
		var env: float = exp(-t * 90.0)
		b[i] = env * (0.5 * sin(TAU * 3900.0 * t) + 0.3 * sin(TAU * 6100.0 * t) + 0.2 * randf_range(-1.0, 1.0))
	return b


## ガラス玉がぶつかる少し低い音
func _synth_clack_low() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.12)
	for i: int in b.size():
		var t: float = float(i) / MIX_RATE
		var env: float = exp(-t * 55.0)
		b[i] = env * (0.55 * sin(TAU * 2200.0 * t) + 0.3 * sin(TAU * 3350.0 * t) + 0.1 * randf_range(-1.0, 1.0))
	return b


func _synth_launch() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.18)
	for i: int in b.size():
		var t: float = float(i) / MIX_RATE
		var env: float = exp(-t * 30.0)
		b[i] = env * (0.6 * sin(TAU * (180.0 - t * 400.0) * t) + 0.4 * randf_range(-1.0, 1.0) * exp(-t * 80.0))
	return b


func _synth_spring() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.35)
	for i: int in b.size():
		var t: float = float(i) / MIX_RATE
		var env: float = exp(-t * 10.0)
		b[i] = env * 0.5 * sin(TAU * (420.0 + 90.0 * sin(TAU * 38.0 * t)) * t)
	return b


func _synth_chime(freqs: Array) -> PackedFloat32Array:
	var step: float = 0.07
	var b: PackedFloat32Array = _buf(step * freqs.size() + 0.6)
	for n: int in freqs.size():
		var f: float = freqs[n]
		var start: int = int(step * n * MIX_RATE)
		for i: int in range(start, b.size()):
			var t: float = float(i - start) / MIX_RATE
			var env: float = exp(-t * 6.0)
			b[i] += env * 0.22 * (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.01 * t))
	return b


## 玉が受け皿にジャラジャラ出てくる音
func _synth_pour() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for k: int in 38:
		var start: int = int(rng.randf_range(0.0, 0.75) * MIX_RATE)
		var f: float = rng.randf_range(2600.0, 5200.0)
		var amp: float = rng.randf_range(0.08, 0.2)
		for i: int in range(start, mini(start + 1400, b.size())):
			var t: float = float(i - start) / MIX_RATE
			b[i] += amp * exp(-t * 110.0) * sin(TAU * f * t)
	return b


## 穴に落ちる「コトン」
func _synth_hole() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.3)
	for i: int in b.size():
		var t: float = float(i) / MIX_RATE
		b[i] = exp(-t * 18.0) * 0.6 * sin(TAU * (520.0 - 260.0 * t) * t) + exp(-t * 60.0) * 0.2 * sin(TAU * 1500.0 * t)
	return b


## 店の扉のカウベル「カランコロン」
func _synth_door_bell() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(1.2)
	var hits: Array = [[0.0, 1760.0], [0.16, 1480.0], [0.3, 1760.0]]
	for h: Array in hits:
		var start: int = int(float(h[0]) * MIX_RATE)
		var f: float = h[1]
		for i: int in range(start, b.size()):
			var t: float = float(i - start) / MIX_RATE
			b[i] += exp(-t * 7.0) * 0.25 * (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.76 * t))
	return b


func _synth_click() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.05)
	for i: int in b.size():
		var t: float = float(i) / MIX_RATE
		b[i] = exp(-t * 150.0) * 0.5 * sin(TAU * 1200.0 * t)
	return b


func _synth_step() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(0.07)
	for i: int in b.size():
		var t: float = float(i) / MIX_RATE
		b[i] = exp(-t * 70.0) * 0.4 * randf_range(-1.0, 1.0) * (0.5 + 0.5 * sin(TAU * 140.0 * t))
	return b


## 店内のジャラジャラ環境音（ループ）
func _synth_hall_ambience() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(4.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp: float = 0.0
	for i: int in b.size():
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		b[i] = lp * 0.25
	for k: int in 900:
		var start: int = rng.randi_range(0, b.size() - 600)
		var f: float = rng.randf_range(2500.0, 6000.0)
		var amp: float = rng.randf_range(0.03, 0.12)
		for i: int in range(start, start + 600):
			var t: float = float(i - start) / MIX_RATE
			b[i] += amp * exp(-t * 130.0) * sin(TAU * f * t)
	return b


## 夕方の町の環境音（そよ風）
func _synth_town_ambience() -> PackedFloat32Array:
	var b: PackedFloat32Array = _buf(6.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lp: float = 0.0
	var lp2: float = 0.0
	var n: int = b.size()
	for i: int in n:
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
		lp2 += (lp - lp2) * 0.05
		var swell: float = 0.6 + 0.4 * sin(TAU * float(i) / float(n) * 2.0)
		b[i] = lp2 * 1.6 * swell
	return b
