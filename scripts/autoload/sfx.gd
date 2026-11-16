extends Node
## Tiny synthesizer: builds every sound effect and the gentle background music
## from code, so the project has no audio files yet. Replace any entry in
## EFFECTS with load("res://assets/sounds/....ogg") later if you like.

const RATE := 22050
const MUSIC_RATE := 16000

# Each effect: list of parts [kind, freq, seconds, wave, volume, slide, delay]
const EFFECTS := {
	"hoe": [["noise", 0, 0.08, "", 0.3, 1.0, 0.0], ["tone", 140, 0.08, "tri", 0.3, 0.6, 0.0]],
	"chop": [["tone", 220, 0.07, "sq", 0.25, 0.5, 0.0], ["noise", 0, 0.05, "", 0.25, 1.0, 0.0]],
	"pick": [["tone", 900, 0.05, "sq", 0.15, 0.7, 0.0], ["noise", 0, 0.04, "", 0.2, 1.0, 0.0]],
	"break": [["noise", 0, 0.18, "", 0.4, 1.0, 0.0], ["tone", 120, 0.15, "tri", 0.3, 0.5, 0.0]],
	"water": [["noise", 0, 0.15, "", 0.15, 1.0, 0.0], ["tone", 600, 0.12, "sine", 0.15, 0.5, 0.0]],
	"pickup": [["tone", 660, 0.06, "sq", 0.15, 1.0, 0.0], ["tone", 990, 0.07, "sq", 0.15, 1.0, 0.05]],
	"coin": [["tone", 1200, 0.06, "sq", 0.15, 1.0, 0.0], ["tone", 1600, 0.1, "sq", 0.15, 1.0, 0.06]],
	"menu": [["tone", 520, 0.04, "sq", 0.1, 1.0, 0.0]],
	"eat": [["tone", 300, 0.06, "tri", 0.3, 1.0, 0.0], ["tone", 260, 0.06, "tri", 0.3, 1.0, 0.09]],
	"hurt": [["tone", 200, 0.2, "saw", 0.3, 0.4, 0.0]],
	"swing": [["noise", 0, 0.06, "", 0.15, 1.0, 0.0]],
	"hit": [["tone", 160, 0.08, "sq", 0.3, 0.5, 0.0], ["noise", 0, 0.05, "", 0.3, 1.0, 0.0]],
	"splash": [["noise", 0, 0.25, "", 0.3, 1.0, 0.0], ["tone", 400, 0.2, "sine", 0.15, 0.4, 0.0]],
	"bite": [["tone", 880, 0.08, "sq", 0.2, 1.0, 0.0], ["tone", 880, 0.08, "sq", 0.2, 1.0, 0.11]],
	"catch": [["tone", 523, 0.12, "sq", 0.15, 1.0, 0.0], ["tone", 659, 0.12, "sq", 0.15, 1.0, 0.09], ["tone", 784, 0.12, "sq", 0.15, 1.0, 0.18], ["tone", 1047, 0.14, "sq", 0.15, 1.0, 0.27]],
	"levelup": [["tone", 392, 0.15, "tri", 0.25, 1.0, 0.0], ["tone", 523, 0.15, "tri", 0.25, 1.0, 0.11], ["tone", 659, 0.15, "tri", 0.25, 1.0, 0.22], ["tone", 784, 0.2, "tri", 0.25, 1.0, 0.33]],
	"door": [["tone", 180, 0.1, "tri", 0.25, 0.7, 0.0]],
	"sleep": [["tone", 523, 0.3, "sine", 0.2, 1.0, 0.0], ["tone", 440, 0.3, "sine", 0.2, 1.0, 0.22], ["tone", 349, 0.3, "sine", 0.2, 1.0, 0.44], ["tone", 262, 0.4, "sine", 0.2, 1.0, 0.66]],
	"death": [["tone", 330, 0.35, "tri", 0.3, 1.0, 0.0], ["tone", 262, 0.35, "tri", 0.3, 1.0, 0.26], ["tone", 196, 0.35, "tri", 0.3, 1.0, 0.52], ["tone", 131, 0.5, "tri", 0.3, 1.0, 0.78]],
	"error": [["tone", 150, 0.12, "sq", 0.2, 1.0, 0.0]],
	"ladder": [["tone", 300, 0.1, "tri", 0.25, 0.5, 0.0]],
	"shot": [["noise", 0, 0.12, "", 0.5, 1.0, 0.0], ["tone", 110, 0.1, "sq", 0.3, 0.4, 0.0]],
	"shot_small": [["noise", 0, 0.07, "", 0.3, 1.0, 0.0], ["tone", 220, 0.05, "sq", 0.15, 0.5, 0.0]],
	"shot_big": [["noise", 0, 0.22, "", 0.6, 1.0, 0.0], ["tone", 70, 0.2, "sq", 0.4, 0.4, 0.0]],
	"twang": [["tone", 330, 0.12, "tri", 0.2, 0.7, 0.0], ["noise", 0, 0.03, "", 0.1, 1.0, 0.0]],
	"throw": [["noise", 0, 0.08, "", 0.12, 1.0, 0.0], ["tone", 500, 0.06, "sine", 0.08, 0.6, 0.0]],
	"reload": [["tone", 900, 0.03, "sq", 0.12, 1.0, 0.0], ["tone", 700, 0.04, "sq", 0.12, 1.0, 0.08]],
	"click": [["tone", 1200, 0.02, "sq", 0.1, 1.0, 0.0]],
	"saw": [["tone", 90, 0.12, "saw", 0.25, 1.2, 0.0], ["noise", 0, 0.1, "", 0.15, 1.0, 0.0]],
	"boom": [["noise", 0, 0.45, "", 0.7, 1.0, 0.0], ["tone", 55, 0.4, "sine", 0.5, 0.5, 0.0]],
	"fire": [["noise", 0, 0.3, "", 0.25, 1.0, 0.0]],
	"zap": [["tone", 1400, 0.06, "saw", 0.15, 0.5, 0.0], ["noise", 0, 0.05, "", 0.15, 1.0, 0.02]],
	"scream": [["tone", 900, 0.5, "saw", 0.25, 1.6, 0.0], ["tone", 600, 0.5, "sq", 0.12, 1.4, 0.05]],
	"spit": [["noise", 0, 0.1, "", 0.2, 1.0, 0.0], ["tone", 260, 0.08, "sine", 0.15, 0.5, 0.0]],
	"crit": [["tone", 1300, 0.05, "sq", 0.15, 1.0, 0.0], ["tone", 160, 0.08, "sq", 0.3, 0.5, 0.0], ["noise", 0, 0.05, "", 0.3, 1.0, 0.0]],
	"stomp": [["tone", 90, 0.1, "sq", 0.35, 0.5, 0.0], ["noise", 0, 0.08, "", 0.35, 1.0, 0.0]],
}

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_cache := {}
var _track := ""

func _ready() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)

func set_volumes(sfx_pct: float, music_pct: float) -> void:
	_set_bus("SFX", sfx_pct / 100.0 * 0.6)
	_set_bus("Music", music_pct / 100.0 * 0.35)

func _set_bus(bus_name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, linear <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(max(linear, 0.001)))

func play(effect: String) -> void:
	if not EFFECTS.has(effect):
		return
	if not _cache.has(effect):
		_cache[effect] = _build(EFFECTS[effect], RATE)
	for p in _players:
		if not p.playing:
			p.stream = _cache[effect]
			p.play()
			return

func _wave(kind: String, phase: float) -> float:
	match kind:
		"sq": return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"tri": return 4.0 * abs(fmod(phase, 1.0) - 0.5) - 1.0
		"saw": return 2.0 * fmod(phase, 1.0) - 1.0
		_: return sin(phase * TAU)

func _build(parts: Array, rate: int) -> AudioStreamWAV:
	var total := 0.0
	for pt in parts:
		total = max(total, pt[6] + pt[2])
	var buf := PackedFloat32Array()
	buf.resize(int(total * rate) + 1)
	for pt in parts:
		_add_part(buf, pt[0], pt[1], pt[2], pt[3], pt[4], pt[5], int(pt[6] * rate), rate)
	return _to_wav(buf, rate)

func _add_part(buf: PackedFloat32Array, kind: String, freq: float, dur: float, wave: String, vol: float, slide: float, offset: int, rate: int) -> void:
	var n := int(dur * rate)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var env := pow(1.0 - t, 2.0)
		var s: float
		if kind == "noise":
			s = randf_range(-1.0, 1.0)
		else:
			var f = freq * lerp(1.0, slide, t)
			phase += f / rate
			s = _wave(wave, phase)
		var j := offset + i
		if j < buf.size():
			buf[j] += s * vol * env

func _to_wav(buf: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clamp(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = buf.size()
	return w

## Gentle generative loop per season (built once, then cached).
func play_music(season: String) -> void:
	if _track == season and _music.playing:
		return
	_track = season
	if not _music_cache.has(season):
		_music_cache[season] = _build_music(season)
	_music.stream = _music_cache[season]
	_music.play()

func stop_music() -> void:
	_music.stop()
	_track = ""

func _build_music(season: String) -> AudioStreamWAV:
	var scales := {"spring": [0, 2, 4, 7, 9], "summer": [0, 2, 4, 5, 7, 9], "autumn": [0, 2, 3, 7, 8], "winter": [0, 3, 5, 7, 10]}
	var sc: Array = scales.get(season, scales.spring)
	var root := 262.0 if season != "winter" else 220.0
	var step := 0.34
	var steps := 32
	var rate := MUSIC_RATE
	var buf := PackedFloat32Array()
	buf.resize(int(steps * step * rate) + rate * 2)
	var chord_roots := [0, 5, 3, 4]
	var pattern := [0, 2, 4, 2, 1, 3, 4, 3]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(season)
	for i in steps:
		var bar := i / 8
		var st := i % 8
		var cr: int = sc[chord_roots[bar] % sc.size()]
		var off := int(i * step * rate)
		if st == 0:
			_add_part(buf, "tone", root * pow(2.0, (cr - 12) / 12.0), 2.4, "tri", 0.35, 1.0, off, rate)
		_add_part(buf, "tone", root * pow(2.0, (cr + sc[pattern[st] % sc.size()]) / 12.0), 0.5, "sine", 0.22, 1.0, off, rate)
		if rng.randf() > 0.78:
			_add_part(buf, "tone", root * pow(2.0, (cr + 12 + sc[(st + 2) % sc.size()]) / 12.0), 0.4, "tri", 0.1, 1.0, off, rate)
	# fold the tail back into the start so the loop is seamless
	var loop_len := int(steps * step * rate)
	for i in range(loop_len, buf.size()):
		buf[i - loop_len] += buf[i]
	buf.resize(loop_len)
	return _to_wav(buf, rate, true)
