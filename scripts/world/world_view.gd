extends Node2D
## Draws the current map: tiles, tilled soil, objects, crops, buildings and
## characters (sorted by depth), plus Godot 2D lights for night, the mine
## and lamps, weather effects, and the fishing and charge meters.

var world
var cam: Camera2D
var darkness: CanvasModulate
var lights_root: Node2D
var light_pool: Array[PointLight2D] = []
var overlay: Node2D
var weather_node: Node2D
var anim_t := 0.0
var cam_pos := Vector2.ZERO
var title_map: GameMap
var title_t := 0.0
var drops_fx := []
var flash := 0.0
var font: Font
var grade: ColorRect
var grade_now := Vector4(1.0, 1.0, 1.0, 1.0)   # saturation, r, g, b tint

const MOODS := {
	"warm": Vector4(1.1, 1.03, 1.0, 0.95),
	"cold": Vector4(0.7, 0.93, 0.98, 1.06),
	"deep": Vector4(0.55, 0.9, 0.96, 1.08),
}

class Painter extends Node2D:
	var callback: Callable
	func _draw() -> void:
		callback.call(self)

func _ready() -> void:
	font = ThemeDB.fallback_font
	cam = Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(cam)
	cam.make_current()
	darkness = CanvasModulate.new()
	add_child(darkness)
	lights_root = Node2D.new()
	add_child(lights_root)
	for i in 40:
		var l := PointLight2D.new()
		l.texture = Art.light_texture
		l.visible = false
		l.blend_mode = Light2D.BLEND_MODE_ADD
		lights_root.add_child(l)
		light_pool.append(l)
	# colour grading: warm and saturated where it's safe, grey and cold where it isn't
	var gl := CanvasLayer.new()
	gl.layer = 1
	add_child(gl)
	grade = ColorRect.new()
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://scripts/world/grade.gdshader")
	grade.material = mat
	gl.add_child(grade)
	var ol := CanvasLayer.new()
	ol.layer = 2
	ol.follow_viewport_enabled = true
	add_child(ol)
	overlay = Painter.new()
	overlay.callback = draw_overlay
	ol.add_child(overlay)
	var wl := CanvasLayer.new()
	wl.layer = 3
	add_child(wl)
	weather_node = Painter.new()
	weather_node.callback = draw_weather
	wl.add_child(weather_node)

func view_size() -> Vector2:
	return get_viewport_rect().size

# ---------------------------------------------------------------- camera
func clamp_cam(m: GameMap, c: Vector2) -> Vector2:
	var vs := view_size()
	var mw := m.w * 16.0
	var mh := m.h * 16.0
	var x = -(vs.x - mw) / 2.0 if mw <= vs.x else clamp(c.x, 0.0, mw - vs.x)
	var y = -(vs.y - mh) / 2.0 if mh <= vs.y else clamp(c.y, 0.0, mh - vs.y)
	return Vector2(round(x), round(y))

func snap_camera() -> void:
	if Game.map == null:
		return
	cam_pos = clamp_cam(Game.map, Game.player.pos - Vector2(0, 16) - view_size() / 2.0)
	cam.position = cam_pos

func env() -> Dictionary:
	if Game.screen != "game" or Game.state.is_empty():
		return {"season": ["spring", "summer", "autumn", "winter"][int(anim_t / 20.0) % 4], "time": 1150, "weather": "sun"}
	return {"season": Game.season(), "time": int(Game.state.time), "weather": Game.state.weather}

func current_map() -> GameMap:
	if Game.screen == "game" and Game.map != null:
		return Game.map
	if title_map == null:
		title_map = MapBuilder.homestead(9177)
		title_map.soil = {}
		for x in range(16, 26):
			for y in range(12, 16):
				title_map.objects.erase(GameMap.k(x, y))
				title_map.soil[GameMap.k(x, y)] = {"w": 1 if (x + y) % 3 else 0, "crop": {"id": ["potato", "radish", "snapbean"][x % 3], "g": (x * 7 + y) % 9}}
	return title_map

func _process(dt: float) -> void:
	anim_t += dt
	var m := current_map()
	if Game.screen == "game" and Game.map != null:
		var target := clamp_cam(m, Game.player.pos - Vector2(0, 16) - view_size() / 2.0)
		cam_pos = cam_pos.lerp(target, min(1.0, dt * 12.0))
		if cam_pos.distance_to(target) < 0.5:
			cam_pos = target
		var c := cam_pos
		if Game.shake > 0:
			Game.shake -= dt
			c += Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
		cam.position = c.round()
	else:
		title_t += dt
		var max_x := m.w * 16.0 - view_size().x
		cam.position = Vector2(round((sin(title_t * 0.05) * 0.5 + 0.5) * max(max_x, 0.0)), min(6 * 16.0, m.h * 16.0 - view_size().y))
	update_lighting(m)
	update_grade(m, dt)
	update_weather(dt)
	queue_redraw()
	overlay.queue_redraw()
	weather_node.queue_redraw()

func is_night(e: Dictionary) -> bool:
	return e.time >= (1080 if e.season == "winter" else 1170) or e.time < 390

# ---------------------------------------------------------------- world drawing
func _draw() -> void:
	var m := current_map()
	var e := env()
	var season: String = e.season
	var c := cam.position
	var vs := view_size()
	var x0: int = max(0, int(floor(c.x / 16)))
	var y0: int = max(0, int(floor(c.y / 16)))
	var x1: int = min(m.w - 1, int(floor((c.x + vs.x) / 16)))
	var y1: int = min(m.h - 1, int(floor((c.y + vs.y) / 16)))
	draw_rect(Rect2(c - Vector2(8, 8), vs + Vector2(16, 16)), Color("#0c0a0a") if m.mine else Color("#1a1a1a"))
	var wf := int(anim_t / 0.42) % 4
	var bd: Texture2D = Art.override(m.backdrop) if m.backdrop != "" else null
	if bd != null:
		draw_texture(bd, Vector2.ZERO)
	for y in range(y0, y1 + 1) if bd == null else []:
		for x in range(x0, x1 + 1):
			var t := m.tile_at(x, y)
			var v := int(Art.hash2(x, y, 5) * 4)
			var pos := Vector2(x * 16, y * 16)
			draw_texture(Art.get_tile(t, season, v, (wf + v) % 4 if t == "water" else 0), pos)
			if t == "water":
				var above := m.tile_at(x, y - 1)
				if above != "water" and above != "bridge":
					draw_rect(Rect2(pos, Vector2(16, 1)), Color(1, 1, 1, 0.35))
					draw_rect(Rect2(pos + Vector2(0, 1), Vector2(16, 2)), Color(0, 0, 0, 0.18))
			var s = m.soil.get(GameMap.k(x, y))
			if s != null:
				draw_texture(Art.get_soil(int(s.w) == 1, season), pos)
	if bd != null:
		for kk in m.soil:
			var tt := GameMap.unk(kk)
			draw_texture(Art.get_soil(int(m.soil[kk].w) == 1, season), Vector2(tt.x * 16, tt.y * 16))
	var sorted := []
	for y in range(y0 - 1, min(m.h - 1, y1 + 3) + 1):
		for x in range(x0 - 2, x1 + 2):
			var o = m.objects.get(GameMap.k(x, y))
			if o == null or o.type == "part" or Data.obj_defs.get(o.type, {}).get("invisible", false):
				continue
			if Data.obj_defs.get(o.type, {}).get("floor", false):
				_draw_obj(o, m, e)
				continue
			var low: bool = o.type in ["forage", "weeds", "twig", "dig_spot"]
			sorted.append([(int(o.y) + int(o.get("h", 1))) * 16 - (6 if low else 0), 0, o])
	for y in range(y0, min(m.h - 1, y1 + 2) + 1):
		for x in range(x0, x1 + 1):
			var s = m.soil.get(GameMap.k(x, y))
			if s != null and s.get("crop") != null:
				sorted.append([y * 16 + 12, 1, [s.crop, x, y]])
	var night := is_night(e)
	for st in m.structures:
		if st.x * 16 > c.x + vs.x or (st.x + st.w) * 16 < c.x or st.y * 16 > c.y + vs.y or (st.y + st.h) * 16 < c.y - 10:
			continue
		sorted.append([(st.y + st.h) * 16 - 1, 2, st])
	if Game.screen == "game" and Game.map == m:
		for id in Game.npcs:
			var n: Dictionary = Game.npcs[id]
			if n.map == m.id:
				sorted.append([n.pos.y, 3, n])
		for en in Game.enemies:
			sorted.append([en.pos.y, 4, en])
		for a in Game.state.get("animals", []):
			var r = Game.animals_rt.get(int(a.uid))
			if r != null and r.map == m.id:
				sorted.append([r.pos.y, 7, [a, r]])
		for d in m.drops:
			sorted.append([d.pos.y, 5, d])
		sorted.append([Game.player.pos.y, 6, Game.player])
	sorted.sort_custom(func(a, b): return a[0] < b[0])
	for it in sorted:
		match it[1]:
			0: _draw_obj(it[2], m, e)
			1: _draw_crop(it[2][0], it[2][1], it[2][2])
			2:
				var bt: Texture2D = Art.get_building(it[2], season, night)
				var bst: Dictionary = it[2]
				draw_texture(bt, Vector2(bst.x * 16 + (bst.w * 16 - bt.get_width()) / 2, (bst.y + bst.h) * 16 - bt.get_height()))
			3: _draw_char(Data.npcs[it[2].id].look, it[2].pos, it[2].dir, it[2].frame, 1.0)
			4: _draw_enemy(it[2])
			5: _draw_drop(it[2])
			6: _draw_player()
			7:
				var a: Dictionary = it[2][0]
				var r: Dictionary = it[2][1]
				var tex: Texture2D = Art.get_animal(a.type, int(a.color), r.dir, int(r.frame), Game.animal_mature(a))
				draw_texture(tex, (r.pos - Vector2(8, 15)).round())
	for q in Game.particles if Game.screen == "game" else []:
		draw_rect(Rect2(q.pos.round(), Vector2.ONE), q.color)
	if Game.screen == "game":
		for f in Game.fires:
			var fa: float = clampf(f.t / maxf(f.dur, 0.01), 0.0, 1.0)
			var fc := Color("#f07a20") if f.kind == "fire" else (Color("#9ad030") if f.kind == "acid" else Color("#b8d890"))
			draw_circle(f.pos, f.r * (0.85 + 0.1 * sin(anim_t * 9.0)), Color(fc, 0.22 * fa + 0.08))
		for pr in Game.projectiles:
			_draw_projectile(pr)
		for a in Game.arcs:
			var pts := PackedVector2Array()
			for i in 6:
				var t := i / 5.0
				pts.append(a.a.lerp(a.b, t) + (Vector2(randf_range(-3, 3), randf_range(-3, 3)) if i > 0 and i < 5 else Vector2.ZERO))
			draw_polyline(pts, Color("#c8f4ff"), 1.0)
	if Game.screen == "game" and Game.settings.show_target and not Game.overlay_open() and Game.player.swing == null and Game.fishing == null:
		var s = Game.selected_stack()
		if s != null:
			var it: Dictionary = Data.items[s.id]
			if it.has("building") and m.id == "homestead":
				var rr: Rect2i = Game.building_rect(it.building, world.facing_tile(), Game.player.dir)
				var ok: bool = Game.building_fits(m, rr)
				var col := Color(0.4, 1.0, 0.4, 0.28) if ok else Color(1.0, 0.3, 0.3, 0.28)
				draw_rect(Rect2(rr.position * 16, rr.size * 16), col)
				draw_rect(Rect2(rr.position * 16, rr.size * 16), Color(col, 0.9), false, 1.0)
				draw_rect(Rect2(Vector2(rr.position.x + 3, rr.end.y - 1) * 16 + Vector2(4, 4), Vector2(8, 12)), Color(1, 1, 1, 0.5))
			elif it.has("tool") or it.cat == "seed" or it.has("place") or it.has("fert"):
				var t: Vector2i = world.target_preview()
				var tiles: Array = world.area_tiles(t, world.charge_level()) if Game.charge != null else [t]
				for tt in tiles:
					draw_rect(Rect2(tt.x * 16 + 0.5, tt.y * 16 + 0.5, 15, 15), Color(1, 1, 1, 0.55), false, 1.0)

func _draw_obj(o: Dictionary, m: GameMap, e: Dictionary) -> void:
	var nb := 0
	if Data.obj_defs.get(o.type, {}).get("barrier", false):
		var i := 0
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var n = m.objects.get(GameMap.k(int(o.x) + d.x, int(o.y) + d.y))
			if n != null and Data.obj_defs.get(n.type, {}).get("barrier", false):
				nb |= 1 << i
			i += 1
	var fr := (1 if is_night(e) else 0) if o.type == "window" else int(anim_t / 0.15) % 4
	var sp = Art.get_obj(o, e.season, fr, nb)
	var sx := 0.0
	if o.get("shake", 0.0) > 0:
		sx = round(sin(anim_t * 50.0) * 1.5)
		o.shake -= get_process_delta_time()
		if o.shake <= 0:
			o.erase("shake")
	draw_texture(sp.tex, Vector2(int(o.x) * 16 + sp.ox + sx, int(o.y) * 16 + sp.oy))
	if o.get("job") != null and Game.screen == "game" and Game.machine_ready(o):
		# a finished machine shows what's waiting inside
		var bob := sin(anim_t * 4.0) * 1.5
		var bx := int(o.x) * 16 + 2
		var by = int(o.y) * 16 + sp.oy - 14 + bob
		draw_rect(Rect2(bx - 1, by - 1, 14, 14), Color(0.97, 0.9, 0.72, 0.9))
		draw_texture_rect(Art.get_icon(o.job.out), Rect2(bx, by, 12, 12), false)
	if o.get("flash", 0.0) > 0:
		var mz := Vector2(int(o.x) * 16 + 8, int(o.y) * 16 + 2) + Vector2.from_angle(o.get("aim", 0.0)) * 8
		draw_rect(Rect2(mz.round() - Vector2(1, 1), Vector2(3, 3)), Color("#fff0a0"))

func _draw_crop(c: Dictionary, x: int, y: int) -> void:
	if c.get("dead", false):
		draw_texture(Art.get_obj({"type": "dead_crop", "v": 0}, "spring").tex, Vector2(x * 16, y * 16))
		return
	var stage: int = world.crop_stage(c)
	var sp = Art.get_crop(c.id, stage)
	draw_texture(sp.tex, Vector2(x * 16, y * 16 + sp.oy))
	if stage == 4 and int(anim_t / 0.5) % 2 == 0:
		draw_rect(Rect2(x * 16 + 13, y * 16 + sp.oy + 2, 1, 1), Color(1, 1, 0.8, 0.9))

func _shadow(at: Vector2, w: float) -> void:
	draw_rect(Rect2(round(at.x - w / 2), round(at.y - 1), w, 2), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(round(at.x - w / 2 + 1), round(at.y - 2), w - 2, 4), Color(0, 0, 0, 0.12))

func _draw_char(look: Dictionary, pos: Vector2, dir: String, frame: int, alpha: float) -> void:
	_shadow(pos, 10)
	var ct: Texture2D = Art.get_char(look, dir, frame)
	draw_texture(ct, (pos - Vector2(ct.get_width() / 2, ct.get_height() - 1)).round(), Color(1, 1, 1, alpha))

var _lying_looks := {}

func _draw_enemy(en: Dictionary) -> void:
	var d: Dictionary = Data.enemies[en.type]
	var jx = round(sin(anim_t * 40.0)) if en.state in ["telegraph", "scream"] else 0.0
	var look: Dictionary = en.get("look", d.look)
	if en.state == "down" and look.get("sprite", "") == "zv" and not look.get("lying", false):
		var key := Art.look_key(look)
		if not _lying_looks.has(key):
			var l2: Dictionary = look.duplicate()
			l2.lying = true
			_lying_looks[key] = l2
		look = _lying_looks[key]
	var alpha := 0.5 if en.flash > 0 else 1.0
	if d.get("ai", "") == "stalker" and en.state in ["wander", "asleep"] and en.pos.distance_to(Game.player.pos) > 40.0:
		alpha = 0.22
	var mod := Color(1, 1, 1, alpha)
	if en.get("turned", 0.0) > 0: mod = Color(0.6, 1.2, 0.6, alpha)
	elif en.has("fx") and en.fx.has("burn") and int(anim_t * 8) % 2 == 0: mod = Color(1.3, 0.9, 0.6, alpha)
	elif en.has("fx") and en.fx.has("corrode"): mod = Color(0.85, 1.15, 0.6, alpha)
	elif en.state == "stun" and en.get("stunned_fx", 0.0) > 0.5: mod = Color(1.1, 1.1, 1.4, alpha)
	_shadow(en.pos, 10 * float(look.get("scale", 1.0)))
	var ct: Texture2D = Art.get_char(look, en.dir, en.frame)
	draw_texture(ct, (en.pos + Vector2(jx, 0) - Vector2(ct.get_width() / 2, ct.get_height() - 1)).round(), mod)
	# health bar once it's been hurt
	if float(en.hp) < float(en.get("max_hp", d.hp)) and alpha > 0.3:
		var bw := 14.0
		var top: Vector2 = en.pos - Vector2(bw / 2, ct.get_height() + 3)
		draw_rect(Rect2(top.round(), Vector2(bw, 2)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top.round(), Vector2(bw * clampf(float(en.hp) / float(en.get("max_hp", d.hp)), 0, 1), 2)), Color("#e04a3a") if not en.get("boss", false) else Color("#e8a020"))
	if en.state == "asleep" and int(anim_t * 2) % 2 == 0:
		draw_string(ThemeDB.fallback_font, en.pos + Vector2(4, -20), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 1, 1, 0.7))

func _draw_projectile(pr: Dictionary) -> void:
	var k: String = pr.get("kind", "round")
	var dirv: Vector2 = pr.vel.normalized() if pr.vel != Vector2.ZERO else Vector2.RIGHT
	match k:
		"bolt", "arrow", "harpoon", "javelin":
			var ln := 7.0 if k != "javelin" else 10.0
			draw_line((pr.pos - dirv * ln).round(), pr.pos.round(), Color("#a07a48") if k != "harpoon" else Color("#9aa0a8"), 1.0)
			draw_rect(Rect2(pr.pos.round() - Vector2(0.5, 0.5), Vector2(1, 1)), Color("#d8d8e0"))
		"stone":
			draw_rect(Rect2(pr.pos.round() - Vector2(1, 1), Vector2(2, 2)), Color("#b0b0b8"))
		"knife", "axe", "boomerang":
			var tex: Texture2D = Art.get_icon(pr.src)
			draw_set_transform(pr.pos.round(), anim_t * 22.0, Vector2(0.6, 0.6))
			draw_texture(tex, Vector2(-8, -8))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"lob":
			var t: float = 1.0 - pr.life / maxf(pr.get("max_life", 1.0), 0.01)
			var up: float = sin(t * PI) * 18.0
			draw_rect(Rect2(pr.pos.round() - Vector2(1, 1), Vector2(2, 2)), Color(0, 0, 0, 0.3))
			var tex2: Texture2D = Art.get_icon(pr.src)
			draw_set_transform((pr.pos - Vector2(0, up)).round(), anim_t * 10.0, Vector2(0.6, 0.6))
			draw_texture(tex2, Vector2(-8, -8))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"acid":
			draw_circle(pr.pos, 2.0, Color("#a8e040"))
		"flare":
			draw_circle(pr.pos, 2.0, Color("#ff5030"))
			draw_circle(pr.pos, 4.0, Color(1, 0.4, 0.2, 0.25))
		"pellet":
			draw_rect(Rect2(pr.pos.round(), Vector2(1, 1)), Color("#fff0b0"))
		_:
			var tail: Vector2 = pr.pos - dirv * 4.0
			draw_line(tail.round(), pr.pos.round(), Color("#fff0b0"), 1.0)

func _draw_drop(d: Dictionary) -> void:
	var bob: float = d.z if d.z > 0 else sin(anim_t * 4.0 + d.pos.x) * 1.2
	draw_rect(Rect2(round(d.pos.x - 4), round(d.pos.y), 8, 2), Color(0, 0, 0, 0.2))
	draw_texture_rect(Art.get_icon(d.id), Rect2(round(d.pos.x - 5), round(d.pos.y - 11 - bob), 10, 10), false)

func _draw_player() -> void:
	var p: Dictionary = Game.player
	var blink: bool = p.iframes > 0 and int(anim_t / 0.08) % 2 == 0
	if p.get("crouching", false):
		_shadow(p.pos, 10)
		var ct: Texture2D = Art.get_char(Game.state.character.look, p.dir, p.frame)
		draw_set_transform(p.pos.round(), 0, Vector2(1, 0.8))
		draw_texture(ct, Vector2(-ct.get_width() / 2, -ct.get_height() + 1), Color(1, 1, 1, 0.35 if blink else 1.0))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		_draw_char(Game.state.character.look, p.pos, p.dir, p.frame, 0.35 if blink else 1.0)
	if p.get("sprinting", false) and int(anim_t * 10) % 3 == 0:
		Game.particles.append({"pos": p.pos + Vector2(randf_range(-3, 3), 0), "vel": Vector2(0, -8), "t": 0.3, "color": Color(0.8, 0.75, 0.6, 0.6), "g": 0.0})
	# a held gun, bow or chainsaw points where you aim
	var hs = Game.selected_stack()
	if p.swing == null and hs != null and Data.weapons.has(hs.id) and Data.weapons[hs.id].mode in ["shoot", "saw"]:
		var dv: Vector2 = {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}[p.dir]
		var hand: Vector2 = p.pos + Vector2(0, -11) + dv * 4.0 + Vector2(0, 1 if p.get("saw_t", 0.0) > 0 and int(anim_t * 30) % 2 == 0 else 0)
		var kick: float = -2.0 if p.get("shoot_t", 0.0) > 0.08 else 0.0
		var flipx: bool = p.dir == "left"
		var ang2: float = 0.0 if p.dir in ["left", "right"] else (PI / 2 if p.dir == "down" else -PI / 2)
		draw_set_transform((hand + dv * kick).round(), ang2 if not flipx else 0.0, Vector2(-0.7, 0.7) if flipx else Vector2(0.7, 0.7))
		draw_texture(Art.get_icon(hs.id), Vector2(-4, -8))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		if p.get("flash", 0.0) > 0:
			draw_circle(hand + dv * 9.0, 2.5, Color(1, 0.9, 0.5, 0.9))
	if p.get("reload") != null:
		var r: Dictionary = p.reload
		var bw := 14.0
		var top: Vector2 = p.pos - Vector2(bw / 2, 36)
		draw_rect(Rect2(top.round(), Vector2(bw, 2)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top.round(), Vector2(bw * clampf(r.t / r.dur, 0, 1), 2)), Color("#e8d070"))
	if p.swing != null and p.swing.get("shove", false):
		pass
	elif p.swing != null:
		var sw: Dictionary = p.swing
		var pr: float = clamp(sw.t / sw.dur, 0.0, 1.0)
		var icon = Art.get_icon(sw.get("weapon", sw.tool), sw.tier)
		var piv: Vector2 = {"down": Vector2(3, -9), "up": Vector2(-3, -15), "left": Vector2(-3, -11), "right": Vector2(3, -11)}[p.dir]
		var ang: float = {"down": lerp(-1.4, 1.2, pr), "up": lerp(-1.2, 0.6, pr), "left": lerp(0.6, -1.8, pr), "right": lerp(-0.6, 1.8, pr)}[p.dir]
		draw_set_transform((p.pos + piv).round(), ang, Vector2(-1, 1) if p.dir == "left" else Vector2.ONE)
		draw_texture(icon, Vector2(-3, -14))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var f = Game.fishing
	if f != null and f.phase in ["cast", "wait", "bite", "mini"]:
		var hand: Vector2 = p.pos + Vector2(-6 if p.dir == "left" else (6 if p.dir == "right" else 3), -10)
		var b: Vector2 = f.bob
		if f.phase == "cast":
			var t: float = f.t / 0.3
			b = hand.lerp(b, t) - Vector2(0, sin(t * PI) * 20)
		else:
			b += Vector2(0, sin(anim_t * 3.3) + (2 if f.phase == "bite" else 0))
		var mid := Vector2((hand.x + b.x) / 2, max(hand.y, b.y) + 6)
		var pts := PackedVector2Array()
		for i in 9:
			var t := i / 8.0
			pts.append(hand.lerp(mid, t).lerp(mid.lerp(b, t), t))
		draw_polyline(pts, Color(0.94, 0.94, 0.94, 0.7), 1.0)
		draw_rect(Rect2(b.round() + Vector2(-1, -2), Vector2(3, 2)), Color("#e83a3a"))
		draw_rect(Rect2(b.round() + Vector2(-1, 0), Vector2(3, 1)), Color("#f4f4f4"))
		draw_texture(Art.get_icon("fishing_rod"), (hand - Vector2(8, 8)).round())

# ---------------------------------------------------------------- overlay (not darkened by night)
func _text(ci: CanvasItem, txt: String, pos: Vector2, c: Color, size := 8) -> void:
	ci.draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(0, 0, 0, 0.85))
	ci.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

func draw_overlay(ci: CanvasItem) -> void:
	if Game.screen != "game" or Game.map == null:
		return
	var p: Dictionary = Game.player
	for id in Game.npcs:
		var n: Dictionary = Game.npcs[id]
		if n.map == Game.map.id and not Game.state.npcs[id].met:
			_text(ci, "!", n.pos + Vector2(-1, -35 + (int(anim_t / 0.3) % 2)), Color("#f8e070"), 9)
	for en in Game.enemies:
		if en.state == "telegraph":
			_text(ci, "!", en.pos + Vector2(-1, -35), Color("#ff4040"), 10)
	for fl in Game.floaters:
		_text(ci, fl.text, fl.pos - Vector2(6, 0), fl.color, 8)
	if Game.charge != null:
		_bar(ci, p.pos + Vector2(0, -42), float(world.charge_level() + (fmod(Game.charge.t, 0.45) / 0.45 if world.charge_level() < Game.tool_tier(Game.charge.tool) else 0.0)) / max(1, Game.tool_tier(Game.charge.tool)), world.charge_level() >= Game.tool_tier(Game.charge.tool))
	var f = Game.fishing
	if f == null:
		return
	if f.phase == "charge":
		_bar(ci, p.pos + Vector2(0, -42), f.power, f.power > 0.95)
	elif f.phase == "bite":
		_text(ci, "!", p.pos + Vector2(-2, -38), Color("#ffe040"), 12)
	elif f.phase == "mini":
		var H := 104.0
		var W := 18.0
		var vs := view_size()
		var x: float = clamp(p.pos.x + 22, cam.position.x + 4, cam.position.x + vs.x - W - 30)
		var y: float = clamp(p.pos.y - 70, cam.position.y + 6, cam.position.y + vs.y - H - 14)
		ci.draw_rect(Rect2(x - 3, y - 3, W + 14, H + 6), Color("#2a1d16"))
		ci.draw_rect(Rect2(x - 2, y - 2, W + 12, H + 4), Color("#8a6040"))
		ci.draw_rect(Rect2(x, y, W, H), Color("#20406a"))
		var by: float = y + H - (f.bar + f.bar_size) * H
		ci.draw_rect(Rect2(x + 1, round(by), W - 2, round(f.bar_size * H)), Color(0.43, 0.9, 0.43, 0.85 if f.inside else 0.55))
		ci.draw_texture(Art.get_icon(f.fish), Vector2(x + 1, round(y + H - f.pos * H) - 8))
		ci.draw_rect(Rect2(x + W + 3, y, 5, H), Color("#1a1414"))
		var pc := Color("#60d060") if f.prog > 0.66 else (Color("#e0c040") if f.prog > 0.33 else Color("#e05040"))
		ci.draw_rect(Rect2(x + W + 4, round(y + H - f.prog * H), 3, round(f.prog * H)), pc)
		_text(ci, "Hold Space", Vector2(x - 8, y + H + 11), Color.WHITE, 7)
	elif f.phase == "result":
		var name: String = Data.items[f.caught].name
		var w := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 26
		var at = (p.pos + Vector2(-w / 2, -52)).round()
		ci.draw_rect(Rect2(at - Vector2.ONE, Vector2(w + 2, 20)), Color("#2a1d16"))
		ci.draw_rect(Rect2(at, Vector2(w, 18)), Color("#f0e2c0"))
		ci.draw_texture(Art.get_icon(f.caught), at + Vector2(2, 1))
		ci.draw_string(font, at + Vector2(21, 12), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#3a2a1a"))

func _bar(ci: CanvasItem, at: Vector2, frac: float, full: bool) -> void:
	var w := 22.0
	ci.draw_rect(Rect2(round(at.x - w / 2) - 1, round(at.y) - 1, w + 2, 5), Color("#1a1414"))
	ci.draw_rect(Rect2(round(at.x - w / 2), round(at.y), w, 3), Color("#3a3030"))
	ci.draw_rect(Rect2(round(at.x - w / 2), round(at.y), round(w * clamp(frac, 0.0, 1.0)), 3), Color("#f0d040") if full else Color("#60c060"))

# ---------------------------------------------------------------- lighting
func darkness_level(m: GameMap, e: Dictionary) -> float:
	if m.mine:
		return 0.72 if m.band.get("palette", "") == "lower" else 0.62
	var t: int = e.time
	var start := 1050 if e.season == "winter" else 1140
	var a := 0.0
	if t >= start:
		a = clamp((t - start) / 150.0, 0.0, 1.0) * 0.74
	if t < 420:
		a = max(a, (420 - t) / 60.0 * 0.45)
	if e.weather == "rain" or e.weather == "storm":
		a = max(a, 0.18) + (0.05 if a > 0 else 0.0)
	if e.weather == "fog":
		a = max(a, 0.08)
	if not m.outdoor:
		a = min(a, 0.45) * 0.8 + (0.1 if t >= 1200 else 0.0)
	return a

func update_grade(m: GameMap, dt: float) -> void:
	var mood: String = m.mood
	if m.mine:
		mood = "cold" if m.floor_n <= 4 else "deep"
	var target: Vector4 = MOODS.get(mood, MOODS.warm)
	grade_now = grade_now.lerp(target, clampf(dt * 2.5, 0.0, 1.0))
	var mat := grade.material as ShaderMaterial
	mat.set_shader_parameter("saturation", grade_now.x)
	mat.set_shader_parameter("tint", Vector3(grade_now.y, grade_now.z, grade_now.w))

func update_lighting(m: GameMap) -> void:
	var e := env()
	var a := darkness_level(m, e)
	var dark_col := Color(0.06, 0.04, 0.1) if m.mine else Color(0.1, 0.13, 0.32)
	darkness.color = Color.WHITE.lerp(dark_col, a)
	var used := 0
	if a > 0.02:
		var srcs := []
		var c := cam.position
		var vs := view_size()
		var x0 := int(c.x / 16) - 6
		var y0 := int(c.y / 16) - 6
		for y in range(max(0, y0), min(m.h, y0 + int(vs.y / 16) + 13)):
			for x in range(max(0, x0), min(m.w, x0 + int(vs.x / 16) + 13)):
				var o = m.objects.get(GameMap.k(x, y))
				if o == null or o.type == "part":
					continue
				var od: Dictionary = Data.obj_defs.get(o.type, {})
				var r: int = od.get("light", 0)
				if od.has("power") and not o.get("powered", false):
					r = 0
				if r > 0:
					var oy := -12 if o.type == "lamp_post" else (-4 if o.type == "lamp" else 4)
					srcs.append([Vector2(x * 16 + 8, y * 16 + oy), r, true])
		for st in m.structures:
			var B: Dictionary = Data.buildings[st.kind]
			if B.has("special") or B.get("boarded", false) or (Art.building_condition(st) < 3 and st.kind != "farmhouse"):
				continue
			srcs.append([Vector2((st.door_x + 0.5) * 16, (st.y + st.h * 0.7) * 16), 44, true])
		for l in m.lights:
			srcs.append([Vector2(l.x * 16 + 8, l.y * 16 + 8), l.r, true])
		if Game.screen == "game" and m == Game.map:
			srcs.append([Game.player.pos + Vector2(0, -16), 100 if m.mine else (30 if m.outdoor else 20), false])
		for s in srcs:
			if used >= light_pool.size():
				break
			var l := light_pool[used]
			used += 1
			l.visible = true
			l.position = s[0]
			var flick := 1.0 + sin(anim_t * 8.0 + s[0].x) * 0.03 if s[2] else 1.0
			l.texture_scale = s[1] * 2.0 / 128.0 * flick
			l.color = Color(1.0, 0.78, 0.5) if s[2] else Color(0.85, 0.85, 0.95)
			l.energy = (0.3 + a * 0.75) * (0.8 if s[1] >= 100 else 1.0) if s[2] else 0.55 + a * 1.1
	for i in range(used, light_pool.size()):
		light_pool[i].visible = false

# ---------------------------------------------------------------- weather (screen space)
func update_weather(dt: float) -> void:
	var w: String = env().weather
	var m := current_map()
	if not m.outdoor:
		w = "sun"
	var want = {"storm": 160, "rain": 90, "snow": 70, "wind": 14}.get(w, 0)
	var vs := view_size()
	while drops_fx.size() < want:
		drops_fx.append({"p": Vector2(randf() * vs.x, randf() * vs.y), "s": 0.6 + randf() * 0.6})
	if drops_fx.size() > want:
		drops_fx.resize(want)
	for d in drops_fx:
		match w:
			"snow": d.p += Vector2(sin(anim_t * 1.4 + d.s * 13.0) * 8.0, 22.0 * d.s) * dt
			"wind": d.p += Vector2(90.0 * d.s, sin(anim_t * 3.3 + d.s * 13.0) * 20.0) * dt
			_: d.p += Vector2(-50.0, 260.0 * d.s) * dt
		if d.p.y > vs.y: d.p = Vector2(randf() * vs.x, -4)
		if d.p.x < -4: d.p.x = vs.x
		if d.p.x > vs.x + 4: d.p.x = -4
	if w == "storm":
		flash = max(0.0, flash - dt)
		if randf() < dt / 9.0:
			flash = 0.16
	else:
		flash = 0.0

func draw_weather(ci: CanvasItem) -> void:
	var w: String = env().weather
	if not current_map().outdoor:
		return
	var vs := view_size()
	var season: String = env().season
	for d in drops_fx:
		match w:
			"rain", "storm": ci.draw_rect(Rect2(d.p.round(), Vector2(1, 4)), Color(0.67, 0.78, 1.0, 0.55))
			"snow": ci.draw_rect(Rect2(d.p.round(), Vector2(2, 2) if d.s > 0.9 else Vector2.ONE), Color(1, 1, 1, 0.9))
			"wind": ci.draw_rect(Rect2(d.p.round(), Vector2(2, 1)), Color("#d8843a") if season == "autumn" else (Color("#f4b8d0") if season == "spring" else Color("#7cc060")))
	if w == "fog":
		ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.86, 0.88, 0.9, 0.18))
	if flash > 0:
		ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, flash * 2.5))
