extends Node
## Music and ambience (Nov 22): Daniel's music packs, picked by where you are, the time and what's happening,
## and looping background sounds (weather, birds, insects, night, water and fires by distance, caves).
## Files: res://audio/music, res://audio/ambience (made by tools/import_audio.py). Sound effects stay in Sfx.
##
## Music works like Stardew: a track from the place's playlist, then a quiet gap with just the ambience, then
## another. Moving somewhere with a different playlist fades across. Fights fade in combat music (boss music for
## bosses) with no gaps, and back out a few seconds after the last attacker is gone.
## Every list is plain track names, easy to change after listening.

const PLAYLISTS := {
	"title": ["last_journey", "world_wanderer"],
	"farm": ["happy_walking", "joyful", "world_wanderer", "magic_cliffs", "up_and_right", "going_up", "exploration"],
	"farm_winter": ["lost_in_thought", "distalgia", "world_wanderer", "hurt_and_heart"],
	"evening": ["summer_nights", "lost_in_thought", "hurt_and_heart", "last_journey"],
	"town": ["dark_happy_world", "joyful", "happy_walking", "going_up", "up_and_right", "world_wanderer"],
	"night": ["lost_in_thought", "last_journey", "distalgia", "hurt_and_heart", "mystery"],
	"wild": ["into_the_woods", "mystic_forest", "exploration", "magic_cliffs", "lost_and_notfound"],
	"district": ["lost_and_notfound", "industrial", "dark_ambient_1", "expansion", "mystery"],
	"danger_night": ["dark_ambient_2", "dark_ambient_3", "anxiety", "magic_fx_6", "dark_ambient_1"],
	"lab": ["anxiety", "dark_ambient_3", "expansion", "magic_fx_6"],
	"mine": ["dark_dungeon", "warped_caves", "dark_ambient_2", "expansion", "magic_fx_6"],
	"festival": ["joyful", "jump_run_duck", "arcade", "happy_walking"],
	"combat": ["battle_encounter", "long_preparation", "hurry_up_and_run", "maniac", "never_ending_race", "nesquence", "outrunner", "moonlight"],
	"boss": ["boss_battle", "fantasy_dragon", "magic_fx_7"],
}
## Quiet between tracks, in seconds (min, max); fights and festivals have none
const GAP := {"combat": [0, 0], "boss": [0, 0], "festival": [2, 6], "title": [3, 6]}
const DEFAULT_GAP := [25, 70]
const FADE := 2.5               # seconds to fade between playlists
const COMBAT_TILES := 9.0       # an attacker this close and after you starts the fight music
const COMBAT_HOLD := 5.0        # seconds the fight music stays after the last attacker

## Ambience loops and the most each plays at (0-1 of the Ambience bus)
const AMB := ["rain_calm", "rain_strong", "wind_calm", "wind_forest", "forest_birds", "cicadas", "night",
	"river_moderate", "stream_calm", "waterfall_calm", "waterfall_strong", "firecamp_small", "firecamp_medium",
	"fire_big", "cave_drips", "cave_dark", "cave_deep", "sea"]
const RIVER_MAPS := ["town", "riverlands"]       # their water is a river; elsewhere ponds and lakes (a calm stream)

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _cur: AudioStreamPlayer
var _list := ""
var _track := ""
var _gap := 0.0
var _fade_t := 0.0
var _combat_t := 0.0
var _amb := {}          # name -> AudioStreamPlayer
var _amb_target := {}
var _scan_t := 0.0
var _streams := {}
var enabled := true     # the test runner turns real playback off
var last_list := ""     # for tests: the playlist chosen last
var last_amb := {}      # for tests: ambience targets chosen last

func _ready() -> void:
	for bus_name in ["Music", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	_a = _player("Music"); _b = _player("Music")
	_cur = _a
	for n in AMB:
		var p := _player("Ambience")
		p.volume_db = -60.0
		_amb[n] = p
	process_mode = Node.PROCESS_MODE_ALWAYS

func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func _stream(path: String, loop: bool) -> AudioStream:
	if _streams.has(path): return _streams[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
		if s is AudioStreamOggVorbis: (s as AudioStreamOggVorbis).loop = loop
	_streams[path] = s
	return s

func set_volume(amb_pct: float) -> void:
	var i := AudioServer.get_bus_index("Ambience")
	if i < 0: return
	var lin := amb_pct / 100.0 * 0.8
	AudioServer.set_bus_mute(i, lin <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lin, 0.001)))

# ================================================================ choosing
## Which playlist fits right now.
func pick_list() -> String:
	if Game.screen == "title" or Game.state.is_empty():
		return "title"
	var m: GameMap = Game.map
	if m == null: return "title"
	if _combat_t > 0.0:
		return "boss" if _boss_near() else "combat"
	var t := int(Game.state.get("time", 720))
	var night: bool = t >= 20 * 60 or t < 6 * 60
	var region := region_of(m)
	match region:
		"mine": return "mine"
		"lab": return "lab"
		"district", "wild":
			return "danger_night" if night else region
	if region == "town" and Festivals.on_now():
		return "festival"
	if night: return "night"
	if t >= 18 * 60 and Game.season() in ["summer", "spring"]: return "evening"
	if region == "farm":
		return "farm_winter" if Game.season() == "winter" else "farm"
	return "town"

## The kind of place a map is: farm, town, district, wild, lab or mine.
func region_of(m: GameMap) -> String:
	if m.mine: return "mine"
	var d := str(m.district)
	if d in ["residential", "industrial", "dry_creek"]: return "district"
	if d == "halvorsen": return "lab" if not m.outdoor else "district"
	if d == "riverlands" or m.id in ["riverlands", "mountain"]: return "wild"
	if m.id == "sandbox": return "district"
	if m.id in ["homestead", "house", "cellar"] or m.farmable or str(m.id).begins_with("coop") or str(m.id).begins_with("barn") or str(m.id).begins_with("hutch"):
		return "farm"
	return "town"

func _boss_near() -> bool:
	for e in Game.enemies:
		if e.get("boss", false) and e.get("hp", 1) > 0 and e.pos.distance_to(Game.player.pos) < 16 * 16: return true
	return false

## Something is coming for you: an awake attacker close by, or a raid on the farm tonight after 10 pm.
func in_fight() -> bool:
	if Game.state.is_empty() or Game.map == null: return false
	var pp: Vector2 = Game.player.pos
	for e in Game.enemies:
		if e.get("turned", 0.0) > 0 or float(e.get("hp", 1)) <= 0: continue
		if str(e.get("state", "")) in ["chase", "lunge", "telegraph", "recover", "scream"] and e.pos.distance_to(pp) < COMBAT_TILES * 16:
			return true
	return false

# ================================================================ playing
func _process(dt: float) -> void:
	if not enabled: return
	if Game.screen == "game" and not Game.state.is_empty():
		_combat_t = COMBAT_HOLD if in_fight() else maxf(0.0, _combat_t - dt)
	else:
		_combat_t = 0.0
	var want := pick_list()
	last_list = want
	if want != _list:
		_switch(want)
	elif not _cur.playing and _fade_t <= 0.0:
		_gap -= dt
		if _gap <= 0.0: _next(false)
	if _fade_t > 0.0:
		_fade_t = maxf(0.0, _fade_t - dt)
		var k := 1.0 - _fade_t / FADE
		_cur.volume_db = linear_to_db(maxf(k, 0.001))
		var old := _b if _cur == _a else _a
		old.volume_db = linear_to_db(maxf(1.0 - k, 0.001))
		if _fade_t <= 0.0: old.stop()
	_scan_t -= dt
	if _scan_t <= 0.0:
		_scan_t = 0.4
		_amb_target = ambience_targets()
		last_amb = _amb_target
	for n in _amb:
		var p: AudioStreamPlayer = _amb[n]
		var tv: float = float(_amb_target.get(n, 0.0))
		var cur := db_to_linear(p.volume_db) if p.playing else 0.0
		var nv := move_toward(cur, tv, dt * 0.5)
		if nv > 0.005:
			if not p.playing:
				var s := _stream("res://audio/ambience/%s.ogg" % n, true)
				if s == null: continue
				p.stream = s
				p.play(randf() * 5.0)
			p.volume_db = linear_to_db(nv)
		elif p.playing:
			p.stop()

func _switch(want: String) -> void:
	var prev := _list
	_list = want
	# going into or out of a fight, or between places: fade straight to a new track
	_next(prev != "")

func _next(crossfade: bool) -> void:
	var names: Array = PLAYLISTS.get(_list, [])
	var choices := names.filter(func(n): return n != _track and ResourceLoader.exists("res://audio/music/%s.ogg" % n))
	if choices.is_empty(): choices = names.filter(func(n): return ResourceLoader.exists("res://audio/music/%s.ogg" % n))
	if choices.is_empty():
		_cur.stop()
		return
	_track = str(choices[randi() % choices.size()])
	var g: Array = GAP.get(_list, DEFAULT_GAP)
	_gap = randf_range(float(g[0]), float(g[1]))
	var s := _stream("res://audio/music/%s.ogg" % _track, int(g[1]) == 0)
	if crossfade and _cur.playing:
		_cur = _b if _cur == _a else _a
		_cur.stream = s
		_cur.volume_db = -60.0
		_cur.play()
		_fade_t = FADE
	else:
		_cur.stream = s
		_cur.volume_db = 0.0
		_cur.play()

func stop_all() -> void:
	_a.stop(); _b.stop(); _list = ""; _track = ""

# ================================================================ ambience
## How loud each loop should be here and now (0-1).
func ambience_targets() -> Dictionary:
	var out := {}
	if Game.screen != "game" or Game.state.is_empty() or Game.map == null:
		return out
	var m: GameMap = Game.map
	var t := int(Game.state.get("time", 720))
	var night: bool = t >= 20 * 60 or t < 5 * 60
	var season: String = Game.season()
	var w := str(Game.state.get("weather", "sun"))
	var rain: bool = w in ["rain", "storm"] and season != "winter"      # winter rain falls as snow
	if m.mine:
		var fl := int(m.floor_n)
		out[("cave_drips" if fl <= 20 else ("cave_dark" if fl <= 60 else "cave_deep"))] = 0.8
		return out
	if not m.outdoor:
		if rain: out["rain_calm"] = 0.25 if w == "rain" else 0.0
		if rain and w == "storm": out["rain_strong"] = 0.25
		_fires(m, out, 0.6)
		return out
	if rain:
		out["rain_strong" if w == "storm" else "rain_calm"] = 0.85
	elif season == "winter":
		out["wind_calm"] = 0.6
	if not rain:
		if night:
			if season != "winter": out["night"] = 0.7
		else:
			if season != "winter" and t < 19 * 60: out["forest_birds"] = 0.55 if region_of(m) in ["farm", "wild", "town"] else 0.25
			if season == "summer" and t >= 11 * 60 and t < 19 * 60: out["cicadas"] = 0.45
	if m.id in ["mountain", "riverlands"] and not rain:
		out["wind_forest"] = maxf(float(out.get("wind_forest", 0.0)), 0.35)
	# water and waterfalls, louder the closer you are
	var pt := Vector2i(int(Game.player.pos.x) / 16, int(Game.player.pos.y - 4) / 16)
	var wd := _nearest_water(m, pt, 10)
	if wd < 99:
		out["river_moderate" if m.id in RIVER_MAPS else "stream_calm"] = clampf(1.0 - wd / 10.0, 0.0, 1.0) * 0.8
	for r in m.rises:
		var fx := int(r.get("fall", -1))
		if fx < 0: continue
		var fc := Vector2(fx + 1, int(r.y) + int(r.h))
		var d := fc.distance_to(Vector2(pt))
		if d < 16:
			out["waterfall_strong" if d < 6 else "waterfall_calm"] = clampf(1.0 - d / 16.0, 0.0, 1.0) * 0.9
	_fires(m, out, 1.0)
	return out

func _nearest_water(m: GameMap, pt: Vector2i, r: int) -> float:
	var best := 99.0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := pt.x + dx; var y := pt.y + dy
			if m.in_bounds(x, y) and m.tile_at(x, y) == "water":
				best = minf(best, Vector2(dx, dy).length())
	return best

## Campfires, watch fires and anything burning nearby.
func _fires(m: GameMap, out: Dictionary, k: float) -> void:
	var pp: Vector2 = Game.player.pos
	var small := 99.0
	for key in m.objects:
		var o: Dictionary = m.objects[key]
		var ty := str(o.type)
		if not ("campfire" in ty or ty in ["watch_fire", "fire_pit", "fire_barrel", "bonfire", "cookstove"]): continue
		small = minf(small, Vector2(int(o.x) * 16 + 8, int(o.y) * 16 + 8).distance_to(pp) / 16.0)
	if small < 8:
		out["firecamp_medium" if Festivals.on_now() and m.id == "town" else "firecamp_small"] = clampf(1.0 - small / 8.0, 0.0, 1.0) * 0.8 * k
	var big := 99.0
	for f in Game.fires:
		if str(f.get("kind", "")) == "fire": big = minf(big, f.pos.distance_to(pp) / 16.0)
	if big < 10:
		out["fire_big"] = clampf(1.0 - big / 10.0, 0.0, 1.0) * 0.9 * k
