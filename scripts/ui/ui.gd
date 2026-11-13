extends CanvasLayer
## The whole interface: title screens, character creation, HUD and every
## in-game window (journal, shops, forge, crate, chests, dialogue, reports).
## Windows are rebuilt from scratch each time they change: simple and reliable.

const K := preload("res://scripts/ui/ui_kit.gd")

var root: Control
var screen_root: Control
var hud: Control
var overlay_root: Control
var overlay := {}          # the open window, empty when none
var flow := {}             # title screen state
var toasts := []
var toast_box: VBoxContainer
var clock_lbl: RichTextLabel
var bars_box: VBoxContainer
var status_box: HBoxContainer
var hint_lbl: Label
var banner_lbl: Label
var toolbar: HBoxContainer
var tb_name: Label
var _last := {}
var banner_t := 0.0

const TABS := {"inventory": "Inventory", "skills": "Skills", "map": "Map", "quests": "Journal", "social": "Social", "crafting": "Crafting", "collections": "Collections", "calendar": "Calendar", "settings": "Settings"}

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	apply_settings()
	screen_root = _full()
	hud = _full()
	overlay_root = _full()
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_root.visible = false
	hud.visible = false

func _full() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c

func apply_settings() -> void:
	if root:
		root.theme = K.make_theme(Game.settings.large_text, Game.settings.high_contrast)

func _clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()

func _center(p: Control, parent: Control) -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(p)
	parent.add_child(cc)

# ================================================================ title flow
func show_title() -> void:
	flow = {"view": "main"}
	hud.visible = false
	overlay = {}
	overlay_root.visible = false
	_clear(overlay_root)
	screen_root.visible = true
	render_title()

func render_title() -> void:
	_clear(screen_root)
	match flow.view:
		"main": _title_main()
		"mode": _title_mode()
		"slot", "load": _title_slots()
		"create": _title_create()
		"property": _title_property()
		"settings": _title_simple("Settings", _settings_box(false))
		"help": _title_simple("How to play", _help_box())
		"import": _title_import()

func _go(view: String, extra := {}) -> void:
	flow.view = view
	flow.merge(extra, true)
	flow.erase("err")
	render_title()

func _title_main() -> void:
	var v := K.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	# wooden sign logo
	var sign := PanelContainer.new()
	var ss := K.sb(Color("#b8682a"), Color("#6a3412"), 3, 4, K.OUTLINE, 3, 8)
	sign.add_theme_stylebox_override("panel", ss)
	var lv := K.vbox(0)
	var t1 := K.label("HARVEST", 26, Color("#ffe6b0"))
	var t2 := K.label("AFTERDARK", 26, Color("#ffe6b0"))
	for t in [t1, t2]:
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_constant_override("outline_size", 6)
		t.add_theme_color_override("font_outline_color", Color("#4a1e06"))
		lv.add_child(t)
	var sub := K.label("a homestead at the end of the world", 8, Color("#ffd9a0"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(sub)
	sign.add_child(lv)
	v.add_child(sign)
	var row := K.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(K.button("New Game", func(): _go("mode"), "big", 70))
	row.add_child(K.button("Load", func(): _go("load"), "big", 60))
	v.add_child(row)
	var row2 := K.hbox(4)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_child(K.button("Restore Backup", func(): _go("import")))
	row2.add_child(K.button("Settings", func(): _go("settings")))
	row2.add_child(K.button("How to Play", func(): _go("help")))
	row2.add_child(K.button("Quit", func(): get_tree().quit()))
	v.add_child(row2)
	var foot := K.label("Phase 1 build  ·  saves are kept on this computer", 6, Color("#ffe6c0"))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	if flow.has("msg"):
		v.add_child(K.label(flow.msg, 7, Color("#ffe6c0")))
	_center(v, screen_root)

func _title_simple(title: String, body: Control) -> void:
	var p := K.panel(320)
	var v := K.vbox()
	v.add_child(K.title(title))
	v.add_child(K.scroll(body, 190))
	v.add_child(K.button("Back", func(): _go("main")))
	p.add_child(v)
	_center(p, screen_root)

func _title_mode() -> void:
	var p := K.panel(420)
	var v := K.vbox(6)
	v.add_child(K.title("Choose your game mode"))
	var row := K.hbox(8)
	for m in Balance.MODES:
		var c: Dictionary = Balance.modes[m]
		var card := K.row_box(Color("#f2cfa8") if m == "survivor" else Color("#dfe6bf"))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := K.vbox(3)
		cv.add_child(K.label(c.label, 11, K.WOOD_DARK))
		cv.add_child(K.label("Difficulty: " + c.difficulty, 7, K.INK_SOFT))
		var lines: Array = ["Health, hunger and thirst to manage", "An infected bite is fatal: you wake at your last night's sleep and everything since is lost", "Smaller pack (%d slots), costlier work, scarcer forage" % Balance.inventory.survivor_slots, "Bigger rewards for tough tasks"] if m == "survivor" else ["Health only. Food and water are optional boosts", "The infected deal ordinary damage", "Collapsing costs a little money and time, nothing else", "Full %d-slot pack" % Balance.inventory.adventure_slots]
		for l in lines:
			var ll := K.label("• " + l, 7, null, true)
			ll.custom_minimum_size.x = 180
			cv.add_child(ll)
		var mode: String = m
		cv.add_child(K.button("Play " + c.label, func(): _go("slot", {"mode": mode}), "big"))
		card.add_child(cv)
		row.add_child(card)
	v.add_child(row)
	v.add_child(K.label("Both modes share the same world, story, people and progression. Each mode has its own save slots.", 7, K.INK_SOFT, true))
	v.add_child(K.button("Back", func(): _go("main")))
	p.add_child(v)
	_center(p, screen_root)

func _title_slots() -> void:
	var p := K.panel(400)
	var v := K.vbox(4)
	var is_new: bool = flow.view == "slot"
	v.add_child(K.title("Choose a save slot" if is_new else "Load Game"))
	var list := K.vbox(3)
	for m in ([flow.mode] if is_new else Balance.MODES):
		list.add_child(K.label(Balance.modes[m].label, 8, K.WOOD_DARK))
		for s in range(1, Balance.SLOTS_PER_MODE + 1):
			var d = Game.read_slot(m, s)
			var row := K.row_box()
			var h := K.hbox(4)
			var mode: String = m
			var slot_n: int = s
			if d == null:
				h.add_child(K.label("Empty slot %d" % s, 7, K.INK_SOFT))
				h.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
				if is_new:
					h.add_child(K.button("Start here", func(): _start_create(slot_n), "small"))
			elif d.get("corrupt", false):
				var l := K.label("Slot %d: damaged save (%s)" % [s, d.error], 7, K.DANGER, true)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(l)
				h.add_child(K.button("Delete", func(): _delete_slot(mode, slot_n), "small"))
				if is_new: h.add_child(K.button("Overwrite", func(): _start_create(slot_n), "small"))
			else:
				h.add_child(K.icon(Art.get_portrait(d.character.look), 18))
				var info := K.label("%s of %s\n%s · %d gold" % [d.character.name, d.property_name, Game.date_label(d.day), d.money], 7, null)
				info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(info)
				if is_new:
					h.add_child(K.button("Overwrite", func(): _start_create(slot_n), "small"))
				else:
					h.add_child(K.button("Load", func(): _load(mode, slot_n), "small"))
					h.add_child(K.button("Back up", func(): _backup(mode, slot_n), "small"))
					h.add_child(K.button("Delete", func(): _delete_slot(mode, slot_n), "small"))
			row.add_child(h)
			list.add_child(row)
	v.add_child(K.scroll(list, 170))
	if flow.has("err"):
		v.add_child(K.label(flow.err, 7, K.DANGER, true))
	v.add_child(K.button("Back", func(): _go("mode" if is_new else "main")))
	p.add_child(v)
	_center(p, screen_root)

func _start_create(slot_n: int) -> void:
	flow.slot = slot_n
	if not flow.has("look"):
		flow.look = Data.default_look.duplicate(true)
	if not flow.has("name"):
		flow.name = ""
	_go("create")

func _load(mode: String, slot_n: int) -> void:
	var err := Game.load_game(mode, slot_n)
	if err != "":
		flow.err = err
		render_title()
	else:
		toast("Welcome back. " + Game.date_label() + ".")

func _backup(mode: String, slot_n: int) -> void:
	var path := Game.export_slot(mode, slot_n)
	flow.err = ("Backed up to " + ProjectSettings.globalize_path(path)) if path != "" else "Nothing to back up."
	render_title()

func _delete_slot(mode: String, slot_n: int) -> void:
	var tag := "%s%d" % [mode, slot_n]
	if flow.get("confirm_del", "") != tag:
		flow.confirm_del = tag
		flow.err = "Click Delete again to permanently remove that save."
		render_title()
		return
	Game.delete_slot(mode, slot_n)
	flow.confirm_del = ""
	flow.erase("err")
	render_title()

func _title_create() -> void:
	var p := K.panel(440)
	var v := K.vbox(4)
	v.add_child(K.title("Create your survivor"))
	v.add_child(_creator(flow.look, true))
	var row := K.hbox()
	row.add_child(K.button("Back", func(): _go("slot")))
	row.add_child(K.button("Next", func():
		if str(flow.name).strip_edges() == "":
			flow.err = "Please enter a name."
			render_title()
		else:
			_go("property"), "big"))
	v.add_child(row)
	if flow.has("err"):
		v.add_child(K.label(flow.err, 7, K.DANGER))
	p.add_child(v)
	_center(p, screen_root)

func _creator(look: Dictionary, with_name: bool) -> Control:
	var h := K.hbox(8)
	var pv := K.row_box(Color("#a8c890"))
	var pvv := K.vbox(2)
	var big := K.icon(Art.get_char(look, "down", 0), 64)
	big.custom_minimum_size = Vector2(48, 96)
	pvv.add_child(big)
	var dirs := K.hbox(1)
	for d in ["down", "left", "up", "right"]:
		var ic := K.icon(Art.get_char(look, d, 0), 16)
		ic.custom_minimum_size = Vector2(16, 32)
		dirs.add_child(ic)
	pvv.add_child(dirs)
	pvv.add_child(K.button("Randomize", func():
		for kk in Data.look_options:
			look[kk] = Data.look_options[kk][randi() % Data.look_options[kk].size()]
		_refresh_creator(), "small"))
	pv.add_child(pvv)
	h.add_child(pv)
	var opts := GridContainer.new()
	opts.columns = 2
	if with_name:
		opts.add_child(K.label("Name", 7))
		var le := LineEdit.new()
		le.text = flow.get("name", "")
		le.max_length = 16
		le.placeholder_text = "Your name"
		le.custom_minimum_size.x = 150
		le.text_changed.connect(func(t): flow.name = t)
		opts.add_child(le)
	for kk in Data.look_options:
		var key: String = kk
		var options: Array = Data.look_options[kk]
		opts.add_child(K.label(Data.look_labels[kk], 7))
		if str(options[0]).begins_with("#"):
			var sw := K.hbox(1)
			for c in options:
				var col: String = c
				var b := Button.new()
				b.focus_mode = Control.FOCUS_NONE
				b.custom_minimum_size = Vector2(10, 10)
				var s := K.sb(Color(col), K.GOLD if look[key] == col else K.OUTLINE, 1, 1, Color(0, 0, 0, 0), 0, 0)
				b.add_theme_stylebox_override("normal", s)
				b.add_theme_stylebox_override("hover", K.sb(Color(col), Color.WHITE, 1, 1, Color(0, 0, 0, 0), 0, 0))
				b.add_theme_stylebox_override("pressed", s)
				b.pressed.connect(func():
					look[key] = col
					_refresh_creator())
				sw.add_child(b)
			opts.add_child(sw)
		else:
			var st := K.hbox(2)
			st.add_child(K.button("◀", func():
				look[key] = options[(options.find(look[key]) - 1 + options.size()) % options.size()]
				_refresh_creator(), "small"))
			var val := K.label(str(look[key]), 7)
			val.custom_minimum_size.x = 50
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			st.add_child(val)
			st.add_child(K.button("▶", func():
				look[key] = options[(options.find(look[key]) + 1) % options.size()]
				_refresh_creator(), "small"))
			opts.add_child(st)
	h.add_child(opts)
	return h

func _refresh_creator() -> void:
	if Game.screen == "title":
		render_title()
	else:
		render_overlay()

func _title_property() -> void:
	var p := K.panel(320)
	var v := K.vbox(4)
	v.add_child(K.title("Name your homestead"))
	v.add_child(K.label("An old farm sits at the edge of Brightwater: a run-down house, an overgrown field, a pond. It's yours now. What will you call it?", 7, null, true))
	var le := LineEdit.new()
	le.text = flow.get("prop", "")
	le.max_length = 24
	le.placeholder_text = "e.g. Second Spring Farm"
	le.text_changed.connect(func(t): flow.prop = t)
	v.add_child(le)
	var ideas := HFlowContainer.new()
	for n in ["Second Spring", "Hollow Oak Farm", "Last Light Acres", "Kettle Creek", "Thistledown"]:
		var nm: String = n
		ideas.add_child(K.button(n, func():
			flow.prop = nm
			render_title(), "small"))
	v.add_child(ideas)
	v.add_child(K.label("Mode: %s · Slot %d" % [Balance.modes[flow.mode].label, flow.slot], 7, K.INK_SOFT))
	var row := K.hbox()
	row.add_child(K.button("Back", func(): _go("create")))
	row.add_child(K.button("Begin", func():
		var pn: String = str(flow.get("prop", "")).strip_edges()
		if pn == "":
			flow.err = "Please name your homestead."
			render_title()
			return
		Game.new_game({"mode": flow.mode, "slot": flow.slot, "name": str(flow.name).strip_edges(), "look": flow.look, "property_name": pn}), "big"))
	v.add_child(row)
	if flow.has("err"):
		v.add_child(K.label(flow.err, 7, K.DANGER))
	p.add_child(v)
	_center(p, screen_root)
	(func(): if is_instance_valid(le) and le.is_inside_tree(): le.grab_focus()).call_deferred()

func _title_import() -> void:
	var p := K.panel(380)
	var v := K.vbox(4)
	v.add_child(K.title("Restore a backup"))
	v.add_child(K.label("Backups are made from Load Game > Back up. Pick one to restore into an empty or chosen slot.", 7, null, true))
	var list := K.vbox(2)
	var files := Game.list_backups()
	if files.is_empty():
		list.add_child(K.label("No backups found in " + ProjectSettings.globalize_path(Game.BACKUP_DIR), 7, K.INK_SOFT, true))
	for f in files:
		var path: String = f
		var row := K.row_box()
		var h := K.hbox()
		var l := K.label(path.get_file(), 6)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		for s in range(1, Balance.SLOTS_PER_MODE + 1):
			var sn: int = s
			h.add_child(K.button("To slot %d" % s, func():
				var err := Game.import_save_file(path, sn)
				flow.err = err if err != "" else "Restored into slot %d. Find it under Load." % sn
				render_title(), "small"))
		row.add_child(h)
		list.add_child(row)
	v.add_child(K.scroll(list, 150))
	if flow.has("err"):
		v.add_child(K.label(flow.err, 7, K.INK, true))
	var row2 := K.hbox()
	row2.add_child(K.button("Open backups folder", func():
		DirAccess.make_dir_recursive_absolute(Game.BACKUP_DIR)
		OS.shell_open(ProjectSettings.globalize_path(Game.BACKUP_DIR))))
	row2.add_child(K.button("Back", func(): _go("main")))
	v.add_child(row2)
	p.add_child(v)
	_center(p, screen_root)

# ================================================================ HUD
func enter_game() -> void:
	screen_root.visible = false
	_clear(screen_root)
	hud.visible = true
	overlay = {}
	overlay_root.visible = false
	_clear(overlay_root)
	build_hud()

func build_hud() -> void:
	_clear(hud)
	_last = {}
	# clock (top right)
	var cp := K.panel(84)
	cp.tape = false
	cp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cp.position = Vector2(-88, 3)
	cp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	clock_lbl = K.rich("", 7)
	clock_lbl.custom_minimum_size.x = 76
	cp.add_child(clock_lbl)
	hud.add_child(cp)
	# bars (top left)
	var bp := K.panel(90)
	bp.tape = false
	bp.position = Vector2(3, 3)
	bars_box = K.vbox(1)
	bp.add_child(bars_box)
	hud.add_child(bp)
	status_box = K.hbox(2)
	status_box.position = Vector2(98, 5)
	hud.add_child(status_box)
	# toasts (bottom left)
	toast_box = K.vbox(2)
	toast_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_box.position = Vector2(4, -36)
	hud.add_child(toast_box)
	# hint + toolbar (bottom center)
	var bottom := K.vbox(1)
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.position.y = -4
	hint_lbl = K.label("", 7, Color("#fff4dc"))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_constant_override("outline_size", 3)
	hint_lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02, 0.9))
	bottom.add_child(hint_lbl)
	tb_name = K.label("", 7, Color("#fff4dc"))
	tb_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tb_name.add_theme_constant_override("outline_size", 3)
	tb_name.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02, 0.9))
	bottom.add_child(tb_name)
	var tbp := PanelContainer.new()
	tbp.add_theme_stylebox_override("panel", K.sb(Color("#b8682a"), K.WOOD_DARK, 2, 3, K.OUTLINE, 1, 2))
	toolbar = K.hbox(1)
	tbp.add_child(toolbar)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(tbp)
	bottom.add_child(cc)
	hud.add_child(bottom)
	# buttons (bottom right)
	var br := K.vbox(2)
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	br.grow_vertical = Control.GROW_DIRECTION_BEGIN
	br.position = Vector2(-4, -4)
	br.add_child(K.button("Journal", func(): if not overlay_open(): open("journal", {"tab": "inventory"}), "small"))
	br.add_child(K.button("Pause", func(): if not overlay_open(): open_pause(), "small"))
	hud.add_child(br)
	# banner
	banner_lbl = K.label("", 14, Color("#fff4d0"))
	banner_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_lbl.position.y = 76
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_lbl.add_theme_constant_override("outline_size", 5)
	banner_lbl.add_theme_color_override("font_outline_color", Color("#2a1a0a"))
	banner_lbl.modulate.a = 0
	hud.add_child(banner_lbl)

func banner(text: String) -> void:
	if banner_lbl:
		banner_lbl.text = text
		banner_t = 2.6

func update_hud(dt: float) -> void:
	if Game.screen != "game" or Game.state.is_empty() or clock_lbl == null:
		return
	var st: Dictionary = Game.state
	var late: bool = st.time >= Balance.time.midnight
	var clock := "[right][b]%s. %s %d[/b] [color=#7a5434]Y%d[/color]\n[font_size=11][color=%s]%s[/color][/font_size]\n[color=#7a5434]%s · %s[/color]\n[b][color=#6a4a10]%s gold[/color][/b]%s[/right]" % [
		Game.weekday(), Game.season().capitalize(), Game.day_of_season(), Game.year(), "#b3392e" if late else "#5a2c0e", Game.fmt_time(int(st.time)),
		Data.weather_info[st.weather].name, Game.location_name(), _num(int(st.money)), "\n[color=#b3392e][b]PAUSED[/b][/color]" if Game.paused else ""]
	if _last.get("clock") != clock:
		clock_lbl.text = clock
		_last.clock = clock
	var bars := [["Health", st.health, Balance.player.max_health, Color("#d8453a")], ["Energy", st.energy, Balance.player.max_energy, Color("#e8c03a")]]
	if Game.is_survivor():
		bars.append(["Hunger", st.hunger, Balance.survival.hunger_max, Color("#d8823a")])
		bars.append(["Thirst", st.thirst, Balance.survival.thirst_max, Color("#3a90d8")])
	var bkey := str(bars.map(func(b): return int(ceil(b[1]))))
	if _last.get("bars") != bkey:
		_last.bars = bkey
		_clear(bars_box)
		for b in bars:
			var h := K.hbox(2)
			var lab := K.label(b[0], 6, K.EMBER if b[1] / b[2] <= 0.25 else K.INK)
			lab.custom_minimum_size.x = 26
			h.add_child(lab)
			var track := ProgressBar.new()
			track.show_percentage = false
			track.custom_minimum_size = Vector2(46, 5)
			track.max_value = b[2]
			track.value = b[1]
			track.add_theme_stylebox_override("background", K.sb(Color("#3a2a1c"), K.OUTLINE, 1, 1, Color(0, 0, 0, 0), 0, 0))
			track.add_theme_stylebox_override("fill", K.sb(b[3], b[3].darkened(0.3), 1, 1, Color(0, 0, 0, 0), 0, 0))
			track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(track)
			h.add_child(K.label(str(int(ceil(b[1]))), 6))
			bars_box.add_child(h)
		var tag := K.label(Balance.modes[st.mode].label.to_upper(), 5, Color.WHITE)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var tagp := PanelContainer.new()
		tagp.add_theme_stylebox_override("panel", K.sb(Color("#8a3a2a") if st.mode == "survivor" else Color("#3f7a2c"), Color(0, 0, 0, 0), 0, 1, Color(0, 0, 0, 0), 0, 1))
		tagp.add_child(tag)
		bars_box.add_child(tagp)
	var effs := Game.status_effects()
	var ekey := str(effs.map(func(e): return e.id))
	if _last.get("eff") != ekey:
		_last.eff = ekey
		_clear(status_box)
		for e in effs:
			var pc := PanelContainer.new()
			pc.add_theme_stylebox_override("panel", K.sb(K.DANGER if e.get("bad", false) else K.EMBER, K.OUTLINE, 1, 2, Color(0, 0, 0, 0), 0, 2))
			pc.add_child(K.label(e.label, 6, Color.WHITE))
			pc.tooltip_text = e.desc
			pc.mouse_filter = Control.MOUSE_FILTER_PASS
			status_box.add_child(pc)
	# toolbar
	var tkey := str(st.selected) + str(st.inventory.slice(0, Balance.inventory.toolbar_size)) + str(st.tools) + str(st.can_water)
	if _last.get("tb") != tkey:
		_last.tb = tkey
		_clear(toolbar)
		var keys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
		for i in Balance.inventory.toolbar_size:
			var s = st.inventory[i]
			var idx: int = i
			var tier := Game.tool_tier(Data.items[s.id].tool) if (s != null and Data.items[s.id].has("tool")) else 0
			var sl := K.slot(s, func(_b): if not overlay_open(): Game.state.selected = idx, tier, i == int(st.selected), false, 20)
			var kl := K.label(keys[i], 5, K.INK_SOFT)
			kl.position = Vector2(1, -1)
			sl.add_child(kl)
			if s != null and s.id == "watering_can":
				var wb := ColorRect.new()
				wb.color = Color("#3a90d8")
				var frac: float = float(st.can_water) / Game.can_capacity()
				wb.size = Vector2(2, 16 * frac)
				wb.position = Vector2(1, 18 - 16 * frac)
				wb.mouse_filter = Control.MOUSE_FILTER_IGNORE
				sl.add_child(wb)
			toolbar.add_child(sl)
		var sel = st.inventory[int(st.selected)]
		tb_name.text = (Game.item_display_name(sel.id) + (" (%d/%d)" % [st.can_water, Game.can_capacity()] if sel.id == "watering_can" else "")) if sel != null else ""
	# toasts
	for i in range(toasts.size() - 1, -1, -1):
		toasts[i].t -= dt
		if toasts[i].t <= 0:
			toasts[i].node.queue_free()
			toasts.remove_at(i)
	# hint and banner
	var h := hint_text()
	if hint_lbl.text != h:
		hint_lbl.text = h
	if banner_t > 0:
		banner_t -= dt
		banner_lbl.modulate.a = clamp(min(banner_t, 2.6 - banner_t) * 3.0, 0.0, 1.0)
	else:
		banner_lbl.modulate.a = 0

static func _num(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

func toast(text: String, icon := "", style := "") -> void:
	if toast_box == null or Game.screen != "game":
		return
	var colors := {"": [Color(0.97, 0.89, 0.72, 0.95), K.WOOD], "gold": [Color("#fff0b8"), Color("#a87a10")], "warn": [Color("#f8dcb8"), K.EMBER], "bad": [Color("#f4c4bc"), K.DANGER]}
	var c: Array = colors.get(style, colors[""])
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.sb(c[0], c[1], 1, 2, Color(0, 0, 0, 0.3), 1, 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := K.hbox(3)
	if icon != "" and Data.items.has(icon):
		h.add_child(K.icon(Art.get_icon(icon), 10))
	var l := K.label(text, 6, null, true)
	l.custom_minimum_size.x = min(200, 5 * text.length())
	h.add_child(l)
	p.add_child(h)
	toast_box.add_child(p)
	toasts.append({"node": p, "t": 4.2, "text": text})
	while toasts.size() > 6:
		toasts[0].node.queue_free()
		toasts.remove_at(0)

func hint_text() -> String:
	if overlay_open() or Game.paused or Game.map == null or Game.world == null:
		return ""
	var f = Game.fishing
	if f != null:
		match f.phase:
			"charge": return "Release to cast"
			"bite": return "A bite! Press Space now!"
			"mini": return "Hold Space to raise the green bar. Keep the fish inside it."
			"wait": return "Waiting for a bite... (move to reel in)"
		return ""
	var w = Game.world
	var npc = w.npc_in_front()
	if npc != null:
		var s = Game.selected_stack()
		var rel: Dictionary = Game.state.npcs[npc]
		var gift: bool = s != null and Game.item_flags(s.id).giftable and rel.met and Game.can_gift(npc)
		return "E: " + ("Talk / give %s to " % Data.items[s.id].name if gift else "Talk to ") + Data.npcs[npc].name.split(" ")[0]
	var an = w.animal_in_front()
	if an != null:
		return ("E: Pet %s" % an.name) if int(an.petted_day) != int(Game.state.day) else "%s looks %s" % [an.name, Game.animal_mood(an)]
	var t: Vector2i = w.target_preview()
	var m: GameMap = Game.map
	var coop = Game.get_building_rec("coop")
	if coop != null and m.id == "homestead" and w.facing_tile() == Game.animal_door_tile(coop):
		return "E: " + ("Close" if coop.door_open else "Open") + " animal door"
	var sel_b = Game.selected_stack()
	if sel_b != null and Data.items[sel_b.id].has("building"):
		return "Face an open 6 by 4 space and press Space to build (green means it fits)" if m.id == "homestead" else "Take the kit to your farm to build"
	var sl = m.soil.get(GameMap.k(t.x, t.y))
	if sl != null and w.crop_ready(sl.get("crop")):
		return "E: Harvest " + Data.crops[sl.crop.id].name
	var o = m.get_obj(t.x, t.y)
	if o != null:
		var od: Dictionary = Data.obj_defs.get(o.type, {})
		if od.get("barrier", false):
			if Game.barrier_damaged(o): return "E: Repair %s (%s)" % [od.name, ", ".join(od.repair.map(func(c): return "%d %s" % [c[1], Data.items[c[0]].name]))]
			if od.get("gate", false): return "E: " + ("Close gate" if o.get("open", false) else "Open gate")
		if od.get("turret", false): return "E: Check %s" % od.name + (" (%d rounds)" % int(o.get("ammo_n", 0)) if od.has("ammo") else (" (powered)" if o.get("powered", false) else " (no power)"))
		if od.get("machine", false):
			if Game.machine_ready(o): return "E: Collect %s" % Data.items[o.job.out].name
			if o.get("job") != null: return "%s: working (%s left)" % [od.name, Game.machine_time_left(o)]
			if o.type == "rain_collector": return "E: Collect water (%d)" % int(o.get("water", 0))
			return "E: Load %s (%s)" % [od.name, Data.machines[o.type].hint]
		if o.type == "generator": return "E: Generator (%d coal)" % int(o.get("fuel", 0))
		if o.type == "hay_hopper": return "E: Hay hopper (%d hay)" % int(Game.get_building_rec("coop").hay) if Game.get_building_rec("coop") != null else ""
		if o.type == "animal_product": return "E: Pick up " + Data.items[o.item].name
		if o.type == "ammo_bench": return "E: Use Ammo Bench"
		if o.type == "armory_bench": return "E: Use Armory Bench"
		if o.type in ["car_wreck", "suitcase", "supply_crate"]:
			return ("E: Search" if int(Game.state.day) - int(o.get("searched", -99)) >= Balance.loot.respawn_days else "Already searched")
		var names := {"bed": "Sleep (save and end the day)", "shipping_box": "Open trade crate", "chest": "Open chest", "fridge": "Open refrigerator", "stove": "Cook", "mirror": "Change appearance", "pump": "Drink and refill watering can", "notice_board": "Read notices", "sign": "Read sign", "ladder_up": "Climb up", "mine_lift": "Use lift", "counter": "Shop"}
		if o.type == "forage": return "E: Pick up " + Data.items[o.item].name
		if names.has(o.type): return "E: " + names[o.type]
		if o.type == "boulder" or o.type == "big_stump": return Data.obj_defs[o.type].hint
	var stc = m.structure_at(t.x, t.y)
	if stc != null and stc.has("text"):
		return "E: Look"
	return ""

# ================================================================ overlay plumbing
func overlay_open() -> bool:
	return not overlay.is_empty()

func overlay_type() -> String:
	return overlay.get("type", "")

func open(type: String, data := {}) -> void:
	overlay = {"type": type}
	overlay.merge(data, true)
	Game.charge = null
	render_overlay()

func close() -> void:
	var was := overlay_type()
	overlay = {}
	if was == "pause":
		Game.paused = false
	overlay_root.visible = false
	_clear(overlay_root)

func close_all() -> void:
	close()
	Game.paused = false

func open_pause() -> void:
	Game.paused = true
	open("pause")

func say(npc: String, text: String, after = null) -> void:
	dialogue(npc, [text], after)

func dialogue(npc: String, lines: Array, after = null) -> void:
	open("dialogue", {"npc": npc, "lines": lines, "idx": 0, "after": after})

func confirm(text: String, yes: Callable, no = null) -> void:
	open("confirm", {"text": text, "yes": yes, "no": no})

func choice(title: String, text: String, choices: Array) -> void:
	open("choice", {"title": title, "text": text, "choices": choices})

func on_key(e: InputEventKey) -> void:
	if not e.pressed or e.echo:
		return
	var k := e.keycode
	var t := overlay_type()
	var accept: bool = k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]
	match t:
		"dialogue":
			if accept or k == KEY_ESCAPE: dialogue_next()
		"confirm":
			if k in [KEY_ENTER, KEY_KP_ENTER, KEY_Y]: _confirm(true)
			elif k in [KEY_ESCAPE, KEY_N]: _confirm(false)
		"report", "intro", "death", "message":
			if accept or k == KEY_ESCAPE: _finish_simple()
		"collapse":
			if accept or k == KEY_ESCAPE:
				close()
				Game.recover_from_collapse()
		"pause":
			if k in [KEY_ESCAPE, KEY_P]: close()
		"journal":
			if k in [KEY_ESCAPE, KEY_TAB, KEY_I]:
				close()
				return
			var keys := TABS.keys()
			var i := keys.find(overlay.tab)
			if k == KEY_RIGHT or k == KEY_BRACKETRIGHT:
				overlay.tab = keys[(i + 1) % keys.size()]; render_overlay()
			elif k == KEY_LEFT or k == KEY_BRACKETLEFT:
				overlay.tab = keys[(i - 1 + keys.size()) % keys.size()]; render_overlay()
		"appearance":
			if k == KEY_ESCAPE: close()
		_:
			if k == KEY_ESCAPE or k == KEY_E: close()

func dialogue_next() -> void:
	if overlay.idx < overlay.lines.size() - 1:
		overlay.idx += 1
		render_overlay()
		return
	var after = overlay.get("after")
	close()
	if after != null:
		after.call()

func _confirm(yes: bool) -> void:
	var fn = overlay.yes if yes else overlay.get("no")
	close()
	if fn != null:
		fn.call()

func _finish_simple() -> void:
	var then = overlay.get("then")
	close()
	if then != null:
		then.call()

func render_overlay() -> void:
	_clear(overlay_root)
	if overlay.is_empty():
		overlay_root.visible = false
		return
	overlay_root.visible = true
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.12 if overlay.type == "dialogue" else 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if overlay.type == "dialogue":
		dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: dialogue_next())
	overlay_root.add_child(dim)
	var body: Control = call("_ov_" + overlay.type)
	if overlay.type == "dialogue":
		# pinned to the bottom of the screen, growing upward
		body.anchor_left = 0.5; body.anchor_right = 0.5; body.anchor_top = 1.0; body.anchor_bottom = 1.0
		body.offset_left = 0; body.offset_right = 0; body.offset_top = -8; body.offset_bottom = -8
		body.grow_horizontal = Control.GROW_DIRECTION_BOTH
		body.grow_vertical = Control.GROW_DIRECTION_BEGIN
		overlay_root.add_child(body)
	else:
		_center(body, overlay_root)

## Weapons and gear that need work, with what each repair costs.
func _repair_box() -> VBoxContainer:
	var v := K.vbox(2)
	v.add_child(K.label("Repairs restore full durability. The closer something is to breaking, the more it costs." + (" In Survivor Mode a broken item is lost, so don't wait too long." if Game.is_survivor() else " Broken items can still be fixed."), 6, K.INK_SOFT, true))
	var items := Game.repairable_items()
	if items.is_empty():
		v.add_child(K.label("Nothing you're carrying or wearing needs repair.", 7))
	for s in items:
		var c := Game.repair_cost(s)
		var row := K.row_box()
		var rh := K.hbox(4)
		rh.add_child(K.icon(Art.get_icon(s.id), 16))
		var md := Game.max_dur(s.id)
		var nm := K.rich("[b]%s[/b]%s\n%s · %d gold + %s" % [Data.items[s.id].name, " [color=#c83a2a](broken)[/color]" if Game.is_broken(s) else "",
			"Durability %d/%d" % [Game.stack_dur(s), md], int(c.gold), ", ".join(c.mats.map(func(m): return "%d %s" % [int(m[1]), Data.items[m[0]].name]))], 6)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.custom_minimum_size.x = 220
		rh.add_child(nm)
		var ss: Dictionary = s
		rh.add_child(K.button("Repair", func():
			var err := Game.repair_item(ss)
			overlay.err = err
			if err == "": toast("Repaired your %s." % Data.items[ss.id].name, ss.id)
			render_overlay(), "small"))
		row.add_child(rh)
		v.add_child(row)
	return v

func _ov_repair() -> Control:
	var pw := _window("", 360)
	var v: VBoxContainer = pw[1]
	var owner: String = overlay.get("owner", "jo")
	v.add_child(_shop_head(owner, Data.npcs[owner].name, "Repairs"))
	v.add_child(K.scroll(_repair_box(), 170))
	if overlay.get("err", "") != "": v.add_child(K.label(overlay.err, 7, K.DANGER))
	v.add_child(_close_btn("Done"))
	return pw[0]

func _window(title: String, w := 300.0) -> Array:
	var p := K.panel(w)
	var v := K.vbox(4)
	if title != "":
		v.add_child(K.title(title))
	p.add_child(v)
	return [p, v]

func _close_btn(text := "Close") -> Button:
	return K.button(text, close)

# ================================================================ overlays
func _ov_intro() -> Control:
	var pw := _window(Game.state.property_name, 360)
	var v: VBoxContainer = pw[1]
	v.add_child(K.label("Years ago, the outbreak the old broadcasts called the Quiet Fall emptied the cities and cut the settlements off from one another. The infected still wander the dark places. But out here, life goes on.", 7, null, true))
	v.add_child(K.label("You arrived last night at an abandoned homestead just west of Brightwater, a small town of survivors. The house leaks, the field is overgrown and the pond is full of weeds. It's a start.", 7, null, true))
	v.add_child(K.label(("Survivor Mode: watch your hunger and thirst, drink at the hand pump outside, and keep clear of the infected. A single bite sends you back to your last night of sleep.") if Game.is_survivor() else ("Adventure Mode: enjoy the world at your own pace. Food and water are optional boosts, and the infected only cause ordinary damage."), 7, K.INK_SOFT, true))
	v.add_child(_controls_box())
	v.add_child(K.button("Begin the first day", close, "big"))
	for c in v.get_children():
		if c is Label: c.custom_minimum_size.x = 340
	return pw[0]

func _ov_pause() -> Control:
	var pw := _window("Paused", 160)
	var v: VBoxContainer = pw[1]
	v.add_child(K.label("The clock is stopped.", 7, K.INK_SOFT))
	v.add_child(K.button("Resume", close, "big"))
	v.add_child(K.button("Journal", func(): Game.paused = false; open("journal", {"tab": "inventory"})))
	v.add_child(K.button("Settings", func(): Game.paused = false; open("journal", {"tab": "settings"})))
	v.add_child(K.button("Controls", func(): Game.paused = false; open("help")))
	v.add_child(K.button("Quit to Title", _quit_confirm, "danger"))
	return pw[0]

func _quit_confirm() -> void:
	confirm("Quit to the title screen? Anything since you last slept will be lost.", func(): Game.quit_to_title())

func _ov_help() -> Control:
	var pw := _window("How to play", 360)
	pw[1].add_child(K.scroll(_help_box(), 190))
	pw[1].add_child(_close_btn())
	return pw[0]

func _ov_message() -> Control:
	var pw := _window(overlay.get("title", ""), 240)
	var l := K.label(overlay.text, 7, null, true)
	l.custom_minimum_size.x = 220
	pw[1].add_child(l)
	pw[1].add_child(K.button("OK", _finish_simple, "big"))
	return pw[0]

func _ov_dialogue() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", K.sb(K.PARCH, K.WOOD, 3, 3, K.OUTLINE, 2, 6))
	p.custom_minimum_size = Vector2(380, 64)
	var h := K.hbox(8)
	var npc: String = overlay.get("npc", "")
	var tv := K.vbox(2)
	var line := K.label(overlay.lines[overlay.idx], 8, null, true)
	line.custom_minimum_size = Vector2(290 if npc != "" else 360, 40)
	tv.add_child(line)
	tv.add_child(K.label("Click or press Enter ▼" if overlay.idx < overlay.lines.size() - 1 else "Click or press Enter to close", 6, K.INK_SOFT))
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	if npc != "":
		var pv := K.vbox(1)
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", K.sb(Color("#8fbf70"), K.WOOD_DARK, 2, 2, K.OUTLINE, 1, 1))
		var pi := K.icon(Art.get_portrait(Data.npcs[npc].look), 40)
		pi.custom_minimum_size = Vector2(44, 38)
		frame.add_child(pi)
		pv.add_child(frame)
		var nl := K.label(Data.npcs[npc].name.split(" ")[0], 8, K.WOOD_DARK)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pv.add_child(nl)
		pv.add_child(K.rich("[center]" + K.hearts(Game.hearts(npc)) + "[/center]", 5))
		h.add_child(pv)
	p.add_child(h)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: dialogue_next())
	return p

func _ov_confirm() -> Control:
	var pw := _window("", 220)
	var l := K.label(overlay.text, 8, null, true)
	l.custom_minimum_size.x = 200
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pw[1].add_child(l)
	var row := K.hbox()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(K.button("Yes", func(): _confirm(true), "big", 50))
	row.add_child(K.button("No", func(): _confirm(false), "", 50))
	pw[1].add_child(row)
	return pw[0]

func _ov_choice() -> Control:
	var pw := _window(overlay.title, 200)
	pw[1].add_child(K.label(overlay.text, 8, null, true))
	for c in overlay.choices:
		var fn: Callable = c.fn
		pw[1].add_child(K.button(c.label, func():
			close()
			fn.call()))
	return pw[0]

func _ov_death() -> Control:
	var p := K.panel(280)
	p.add_theme_stylebox_override("panel", K.sb(K.PARCH, Color("#6a1a14"), 3, 3, Color("#2a0a08"), 3, 8))
	var v := K.vbox(5)
	v.add_child(K.label("You were bitten", 13, Color("#8a2a1e")))
	for t in ["An infected caught you. In Survivor Mode, a bite is the end of the road.",
		"You open your eyes in your own bed on the morning of %s. Everything since you last slept is gone: items, crops, progress and money are exactly as they were." % overlay.get("checkpoint", "your last save")]:
		var l := K.label(t, 7, null, true)
		l.custom_minimum_size.x = 260
		v.add_child(l)
	v.add_child(K.button("Get up", _finish_simple, "big"))
	p.add_child(v)
	return p

func _ov_collapse() -> Control:
	var pw := _window("Rescued", 260)
	var cause: String = {"starvation": "You collapsed from hunger.", "dehydration": "You collapsed from thirst.", "infected": "The infected overwhelmed you and you blacked out."}.get(overlay.cause, "You collapsed.")
	for t in [cause, "Someone from Brightwater found you and carried you home.%s You lost %d hours recovering." % [(" You lost %d gold along the way." % overlay.lost) if overlay.lost else "", Game.mode_cfg().collapse_hours_lost]]:
		var l := K.label(t, 7, null, true)
		l.custom_minimum_size.x = 240
		pw[1].add_child(l)
	pw[1].add_child(K.label("Your items, crops and progress are safe.", 7, K.INK_SOFT))
	pw[1].add_child(K.button("Continue", func():
		close()
		Game.recover_from_collapse(), "big"))
	return pw[0]

func _ov_report() -> Control:
	var r: Dictionary = overlay.report
	var pw := _window("You passed out..." if r.reason == "passout" else "Good morning", 340)
	var v: VBoxContainer = pw[1]
	v.add_child(K.label("%s. %s · %s" % [Game.weekday(), Game.date_label(), Data.weather_info[Game.state.weather].name], 7, K.INK_SOFT))
	if r.reason == "passout":
		v.add_child(K.label("You collapsed from exhaustion at 2:00 am and woke up at home%s." % ((", %d gold lighter" % r.lost) if r.lost else ""), 7, K.EMBER, true))
	v.add_child(K.label("Trade crate sales", 8, K.WOOD_DARK))
	if r.sales.is_empty():
		v.add_child(K.label("Nothing was shipped yesterday.", 7, K.INK_SOFT))
	else:
		var g := GridContainer.new()
		g.columns = 4
		for hdr in ["Item", "Qty", "Each", "Total"]:
			g.add_child(K.label(hdr, 7, K.WOOD_DARK))
		for l in r.sales:
			var hb := K.hbox(2)
			hb.add_child(K.icon(Art.get_icon(l.id), 10))
			hb.add_child(K.label(l.name, 7))
			hb.custom_minimum_size.x = 150
			g.add_child(hb)
			g.add_child(K.label(str(l.qty), 7))
			g.add_child(K.label(str(l.price), 7))
			g.add_child(K.label(str(l.total), 7))
		g.add_child(K.label("Total earnings", 8, K.WOOD_DARK)); g.add_child(Control.new()); g.add_child(Control.new())
		g.add_child(K.label(str(r.total), 8, K.WOOD_DARK))
		v.add_child(g)
	if not r.lines.is_empty():
		v.add_child(K.label("Overnight", 8, K.WOOD_DARK))
		for l in r.lines:
			var ll := K.label("• " + l, 7, null, true)
			ll.custom_minimum_size.x = 320
			v.add_child(ll)
	v.add_child(K.label("Game saved." if r.get("saved", false) else "The game could not be saved.", 7, K.MOSS if r.get("saved", false) else K.DANGER))
	v.add_child(K.button("Start the day", _finish_simple, "big"))
	return pw[0]

func _ov_notices() -> Control:
	var pw := _window("Brightwater Notice Board", 320)
	var v: VBoxContainer = pw[1]
	var st: Dictionary = Game.state
	var pins := ["Today: %s. %s. Weather: %s. Forecast tomorrow: %s." % [Game.weekday(), Game.date_label(), Data.weather_info[st.weather].name, Data.weather_info[st.weather_tomorrow].name]]
	for id in Data.shops:
		var s: Dictionary = Data.shops[id]
		pins.append("%s: %s to %s, closed %s. %s" % [s.name, Game.fmt_time(s.open), Game.fmt_time(s.close), ", ".join(s.closed_days), "Open now." if Game.is_shop_open(id) else "Closed now."])
	var up := upcoming(3)
	pins.append("Coming up: " + ("; ".join(up.map(func(e): return "%s (%s)" % [e.label, e.when])) if not up.is_empty() else "nothing scheduled") + ".")
	pins.append("From Ruth: \"Infected have been spotted on the ridge after dark. Stay in town at night, or carry something to defend yourself.\"")
	pins.append("From Ines: \"Bring geodes and ore to the forge. Five ore and one coal makes a bar.\"")
	for t in pins:
		var b := K.row_box(Color("#fff6e4"))
		var l := K.label(t, 7, null, true)
		l.custom_minimum_size.x = 290
		b.add_child(l)
		v.add_child(b)
	v.add_child(_close_btn())
	return pw[0]

func upcoming(n: int) -> Array:
	var out := []
	var day := int(Game.state.day)
	for d in range(day, day + 60):
		if out.size() >= n: break
		var s := Game.season(d)
		var dd := Game.day_of_season(d)
		var when := "today" if d == day else ("tomorrow" if d == day + 1 else "%s %d" % [s.capitalize(), dd])
		for f in Data.festivals:
			if f.season == s and f.day == dd: out.append({"label": f.name, "when": when})
		for id in Data.npcs:
			var b: Dictionary = Data.npcs[id].birthday
			if b.season == s and b.day == dd: out.append({"label": Data.npcs[id].name.split(" ")[0] + "'s birthday", "when": when})
	return out.slice(0, n)

func _ov_lift() -> Control:
	var pw := _window("Mine lift", 180)
	var v: VBoxContainer = pw[1]
	var here: int = Game.map.floor_n if Game.map.mine else 0
	v.add_child(K.label("Checkpoints unlock every %d floors. Deepest reached: %d." % [Balance.mining.lift_every, Game.state.mine.deepest], 7, K.INK_SOFT, true))
	if here:
		v.add_child(K.button("Surface (Ridge Path)", func():
			close()
			Game.change_map("mountain", 19, 5, "down")))
	var floors: Array = Game.state.mine.lifts.duplicate()
	floors.sort()
	for f in floors:
		if f == here: continue
		var fl: int = f
		v.add_child(K.button("Floor %d" % f, func():
			close()
			Game.change_map("mine", 0, 0, "down", {"floor": fl})))
	v.add_child(_close_btn("Cancel"))
	return pw[0]

func _ov_name_animal() -> Control:
	var kind: String = overlay.kind
	var pw := _window("Name your new %s" % Data.animals[kind].name.to_lower(), 260)
	var v: VBoxContainer = pw[1]
	var h := K.hbox(8)
	var ic := K.icon(Art.get_animal(kind, 0, "down", 0, false), 32)
	ic.custom_minimum_size = Vector2(32, 32)
	h.add_child(ic)
	var le := LineEdit.new()
	le.text = overlay.name
	le.max_length = 14
	le.custom_minimum_size.x = 150
	le.text_changed.connect(func(t): overlay.name = t)
	le.text_submitted.connect(func(_t): _adopt())
	h.add_child(le)
	v.add_child(h)
	v.add_child(K.label("It will be waiting in your coop. Babies grow up in a few days.", 7, K.INK_SOFT, true))
	var row := K.hbox()
	row.add_child(K.button("Random name", func():
		overlay.name = Game.random_animal_name()
		render_overlay(), "small"))
	row.add_child(K.button("Done", _adopt, "big"))
	v.add_child(row)
	(func(): if is_instance_valid(le) and le.is_inside_tree(): le.grab_focus()).call_deferred()
	return pw[0]

func _adopt() -> void:
	var a := Game.adopt_animal(overlay.kind, str(overlay.name))
	close()
	toast("Welcome home, %s! Find them in your coop." % a.name)

func _ov_appearance() -> Control:
	if not overlay.has("look"):
		overlay.look = Game.state.character.look.duplicate(true)
	var pw := _window("Mirror", 440)
	pw[1].add_child(_creator(overlay.look, false))
	var row := K.hbox()
	row.add_child(_close_btn("Cancel"))
	row.add_child(K.button("Save look", save_look, "big"))
	pw[1].add_child(row)
	return pw[0]

func save_look() -> void:
	Game.state.character.look = overlay.look.duplicate(true)
	close()
	toast("Looking good.")

# ---------------------------------------------------------------- crate and chests
func _grid(list: Array, cols: int, on_click: Callable, lock_fn = null) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	for i in list.size():
		var s = list[i]
		var idx: int = i
		var locked: bool = s != null and lock_fn != null and lock_fn.call(s.id)
		var tier := Game.tool_tier(Data.items[s.id].tool) if (s != null and Data.items[s.id].has("tool")) else 0
		g.add_child(K.slot(s, (func(btn): on_click.call(idx, btn)) if s != null and not locked else null, tier, false, locked, 20))
	return g

func _ov_ship() -> Control:
	var st: Dictionary = Game.state
	var pw := _window("Trade crate", 420)
	var v: VBoxContainer = pw[1]
	var l := K.label("Items left here sell overnight; you get an itemized report in the morning. Click an item to add the stack, right-click to add one. Click an item in the crate to take it back.", 7, K.INK_SOFT, true)
	l.custom_minimum_size.x = 400
	v.add_child(l)
	var h := K.hbox(10)
	var a := K.vbox()
	a.add_child(K.label("Your pack", 8, K.WOOD_DARK))
	a.add_child(_grid(st.inventory, 8, _ship_add, func(id): return not Game.item_flags(id).sellable))
	h.add_child(a)
	var b := K.vbox()
	var total := 0
	for s in st.shipping:
		total += Data.items[s.id].price * int(s.qty)
	b.add_child(K.label("In the crate (worth about %d gold)" % total, 8, K.WOOD_DARK))
	b.add_child(_grid(st.shipping, 6, func(i, _btn):
		var s: Dictionary = st.shipping[i]
		var left := Game.add_item(s.id, int(s.qty), {"silent": true})
		if left > 0: s.qty = left
		else: st.shipping.remove_at(i)
		render_overlay()) if not st.shipping.is_empty() else K.label("Empty", 7, K.INK_SOFT))
	h.add_child(b)
	v.add_child(h)
	if overlay.has("err"): v.add_child(K.label(overlay.err, 7, K.DANGER))
	v.add_child(_close_btn("Done"))
	return pw[0]

func _ship_add(i: int, btn: int) -> void:
	var st: Dictionary = Game.state
	var s = st.inventory[i]
	if s == null or not Game.item_flags(s.id).sellable:
		return
	var id: String = s.id
	var n: int = 1 if btn == 2 else int(s.qty)
	var do_ship := func():
		var cur = st.inventory[i]
		if cur == null or cur.id != id:
			return
		var q: int = min(n, int(cur.qty))
		var ex = null
		for x in st.shipping:
			if x.id == id: ex = x
		if ex != null: ex.qty = int(ex.qty) + q
		else: st.shipping.append({"id": id, "qty": q})
		Game.remove_from_slot(i, q)
		Sfx.play("pickup")
	var fl := Game.item_flags(id)
	var only: bool = Game.count_item(id) <= n
	if (fl.donatable and only) or Data.items[id].price >= 200:
		var saved := overlay.duplicate()
		confirm(("This is your only %s. The Archive may want one when it reopens. " % Data.items[id].name if fl.donatable and only else "This is a valuable item. ") + "Ship %d %s for %d gold?" % [n, Data.items[id].name, Data.items[id].price * n],
			func():
				do_ship.call()
				overlay = saved
				render_overlay(),
			func():
				overlay = saved
				render_overlay())
		return
	do_ship.call()
	render_overlay()

func _ov_chest() -> Control:
	var o: Dictionary = overlay.obj
	if not (o.get("items") is Array): o.items = []
	var size: int = Balance.inventory.fridge_slots if o.type == "fridge" else Balance.inventory.chest_slots
	while o.items.size() < size: o.items.append(null)
	var pw := _window(overlay.title, 420)
	var v: VBoxContainer = pw[1]
	v.add_child(K.label("Click a stack to move it between your pack and the %s." % ("fridge" if o.type == "fridge" else "chest"), 7, K.INK_SOFT))
	var h := K.hbox(10)
	var a := K.vbox()
	a.add_child(K.label("Your pack", 8, K.WOOD_DARK))
	a.add_child(_grid(Game.state.inventory, 8, func(i, _b): _move_stack(Game.state.inventory, o.items, i, false)))
	h.add_child(a)
	var b := K.vbox()
	b.add_child(K.label(overlay.title, 8, K.WOOD_DARK))
	b.add_child(_grid(o.items, 6, func(i, _b): _move_stack(o.items, Game.state.inventory, i, true)))
	h.add_child(b)
	v.add_child(h)
	v.add_child(_close_btn("Done"))
	return pw[0]

func _move_stack(from: Array, to: Array, i: int, discover: bool) -> void:
	var s = from[i]
	if s == null: return
	var left := Game.add_item(s.id, int(s.qty), {"list": to, "silent": true})
	if left > 0: s.qty = left
	else: from[i] = null
	if discover: Game.mark_discovered(s.id)
	render_overlay()

# ---------------------------------------------------------------- shops and forge
func _shop_box(shop_id: String) -> Control:
	var st: Dictionary = Game.state
	var sh: Dictionary = Data.shops[shop_id]
	var qty: int = overlay.get("qty", 1)
	var h := K.hbox(8)
	var buy := K.vbox(2)
	var bh := K.hbox()
	var bl := K.label("Buy", 8, K.WOOD_DARK)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(bl)
	for n in [1, 5, 10]:
		var nn: int = n
		var qb := K.button("x%d" % n, func():
			overlay.qty = nn
			render_overlay(), "small")
		if qty == n: qb.modulate = Color(1.2, 1.2, 0.8)
		bh.add_child(qb)
	buy.add_child(bh)
	var bl2 := K.vbox(2)
	var stock := Game.shop_stock(shop_id)
	for i in stock.size():
		var e: Dictionary = stock[i]
		var row := K.row_box()
		var rh := K.hbox(3)
		var owned: bool = e.get("service", "") == "backpack" and st.flags.get("backpack", false)
		if e.has("id"): rh.add_child(K.icon(Art.get_icon(e.id), 14))
		elif e.get("service", "") == "animal": rh.add_child(K.icon(Art.get_animal(e.animal, 0, "down", 0, true), 14))
		elif e.get("service", "") == "coop": rh.add_child(K.icon(Art.get_icon("coop_kit"), 14))
		else: rh.add_child(K.label("★", 10, K.GOLD))
		var nm := K.rich("[b]%s[/b]%s\n[font_size=5][color=#7a5434]%s[/color][/font_size]" % [Data.items[e.id].name if e.has("id") else e.name, " [color=#b3392e]SALE[/color]" if e.sale else "", Data.items[e.id].desc if e.has("id") else e.desc], 6)
		nm.custom_minimum_size.x = 110
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(nm)
		rh.add_child(K.rich(("[s]%d[/s] " % e.price if e.sale else "") + "[b]%d[/b]" % e.final_price, 6))
		if owned:
			rh.add_child(K.label("Owned", 6, K.INK_SOFT))
		else:
			var q: int = 1 if e.has("service") else qty
			var entry := e
			var b := K.button("Buy" + (" %d" % q if q > 1 else ""), func():
				overlay.err = Game.shop_buy(shop_id, entry, q)
				render_overlay(), "small")
			b.disabled = int(st.money) < e.final_price * q
			rh.add_child(b)
		row.add_child(rh)
		bl2.add_child(row)
	buy.add_child(K.scroll(bl2, 150))
	buy.custom_minimum_size.x = 210
	h.add_child(buy)
	var sell := K.vbox(2)
	sell.add_child(K.label("Sell", 8, K.WOOD_DARK))
	var sl := K.vbox(2)
	var any := false
	for i in st.inventory.size():
		var s = st.inventory[i]
		if s == null or not Game.shop_buys_item(shop_id, s.id): continue
		any = true
		var idx: int = i
		var row := K.row_box()
		var rh := K.hbox(3)
		rh.add_child(K.icon(Art.get_icon(s.id), 14))
		var nm := K.label("%s x%d" % [Data.items[s.id].name, s.qty], 6)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(nm)
		rh.add_child(K.label(str(Game.sell_price(s)), 6, Color("#6a4a10")))
		rh.add_child(K.button("1", func(): Game.shop_sell(shop_id, idx, 1); render_overlay(), "small"))
		rh.add_child(K.button("All", func(): Game.shop_sell(shop_id, idx, 999); render_overlay(), "small"))
		row.add_child(rh)
		sl.add_child(row)
	if not any:
		sl.add_child(K.label("%s buys: %s. You have nothing they want right now." % [sh.name, ", ".join(sh.buys.map(func(c): return Data.categories[c].label))], 6, K.INK_SOFT, true))
	sell.add_child(K.scroll(sl, 150))
	sell.custom_minimum_size.x = 170
	h.add_child(sell)
	return h

func _shop_head(owner: String, title: String, sub: String) -> HBoxContainer:
	var h := K.hbox(6)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", K.sb(Color("#8fbf70"), K.WOOD_DARK, 2, 2, K.OUTLINE, 1, 1))
	var pi := K.icon(Art.get_portrait(Data.npcs[owner].look), 26)
	pi.custom_minimum_size = Vector2(28, 25)
	frame.add_child(pi)
	h.add_child(frame)
	var tv := K.vbox(0)
	tv.add_child(K.title(title))
	tv.add_child(K.label(sub, 6, K.INK_SOFT))
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	var purse := K.row_box(Color("#fff0c8"))
	purse.add_child(K.label("%s gold" % _num(int(Game.state.money)), 8, Color("#6a4a10")))
	h.add_child(purse)
	return h

func _ov_shop() -> Control:
	var sh: Dictionary = Data.shops[overlay.shop]
	var pw := _window("", 410)
	var v: VBoxContainer = pw[1]
	v.add_child(_shop_head(sh.owner, sh.name, "%s · Open %s to %s · Closed %s" % [Data.npcs[sh.owner].name, Game.fmt_time(sh.open), Game.fmt_time(sh.close), ", ".join(sh.closed_days)]))
	v.add_child(_shop_box(overlay.shop))
	if overlay.get("err", "") != "": v.add_child(K.label(overlay.err, 7, K.DANGER))
	v.add_child(_close_btn("Leave"))
	return pw[0]

func _ov_forge() -> Control:
	var st: Dictionary = Game.state
	var tab: String = overlay.get("tab", "geodes")
	var pw := _window("", 410)
	var v: VBoxContainer = pw[1]
	v.add_child(_shop_head("ines", "Varga Forge", "Ines Varga · Blacksmith"))
	var tabs := K.hbox(2)
	for t in [["geodes", "Crack Geodes"], ["refine", "Refine Ore"], ["upgrade", "Upgrade Tools"], ["repair", "Repair"], ["shop", "Buy & Sell"]]:
		var tid: String = t[0]
		var b := K.button(t[1], func():
			overlay.tab = tid
			overlay.err = ""
			overlay.erase("result")
			render_overlay(), "small")
		if tid == tab: b.modulate = Color(1.25, 1.2, 0.9)
		tabs.add_child(b)
	v.add_child(tabs)
	var body := K.vbox(2)
	match tab:
		"geodes":
			body.add_child(K.label("Fee: %d gold per geode. Each geode type has its own pool of possible finds." % Balance.services.geode_fee, 7, K.INK_SOFT))
			var any := false
			for g in Data.geode_tables:
				if Game.count_item(g) <= 0: continue
				any = true
				var gid: String = g
				var row := K.row_box()
				var rh := K.hbox(4)
				rh.add_child(K.icon(Art.get_icon(g), 16))
				var nm := K.label("%s x%d" % [Data.items[g].name, Game.count_item(g)], 7)
				nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rh.add_child(nm)
				var b := K.button("Crack one", func():
					var r := Game.forge_open_geode(gid)
					if r.has("error"): overlay.err = r.error
					else:
						overlay.result = r
						overlay.err = ""
					render_overlay(), "small")
				b.disabled = int(st.money) < Balance.services.geode_fee
				rh.add_child(b)
				row.add_child(rh)
				body.add_child(row)
			if not any: body.add_child(K.label("You have no geodes. Look for speckled rocks in the mine.", 7))
			if overlay.has("result"):
				var r: Dictionary = overlay.result
				var rb := K.row_box(Color("#fff4c8"))
				var rh := K.hbox(6)
				rh.add_child(K.icon(Art.get_icon(r.id), 32))
				rh.add_child(K.label("Inside: %d %s\n%s" % [r.qty, Data.items[r.id].name, Data.items[r.id].desc], 7, null, true))
				rh.get_child(1).custom_minimum_size.x = 300
				rb.add_child(rh)
				body.add_child(rb)
		"refine":
			body.add_child(K.label("Ines refines 5 ore and 1 coal into a bar overnight. Bars are ready the next morning.", 7, K.INK_SOFT, true))
			for bar in Data.refining:
				var r: Dictionary = Data.refining[bar]
				var fee: int = Balance.services.refine_fee_per_bar[bar]
				var can: int = min(Game.count_item(r.ore) / r.ore_qty, min(Game.count_item("coal") / r.coal, int(st.money) / fee))
				var bid: String = bar
				var row := K.row_box()
				var rh := K.hbox(3)
				rh.add_child(K.icon(Art.get_icon(bar), 14))
				var nm := K.label("%s: %d %s (have %d) + %d Coal (have %d) + %d gold" % [Data.items[bar].name, r.ore_qty, Data.items[r.ore].name, Game.count_item(r.ore), r.coal, Game.count_item("coal"), fee], 6, null, true)
				nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rh.add_child(nm)
				var b1 := K.button("Refine 1", func(): overlay.err = Game.forge_refine(bid, 1); render_overlay(), "small")
				b1.disabled = can < 1
				rh.add_child(b1)
				var nmax: int = max(can, 1)
				var b2 := K.button("Refine %d" % nmax, func(): overlay.err = Game.forge_refine(bid, nmax); render_overlay(), "small")
				b2.disabled = can < 2
				rh.add_child(b2)
				row.add_child(rh)
				body.add_child(row)
			var ready: Array = st.forge.orders.filter(func(o): return int(o.ready_day) <= int(st.day))
			var pending: Array = st.forge.orders.filter(func(o): return int(o.ready_day) > int(st.day))
			if not ready.is_empty():
				var rh := K.hbox()
				rh.add_child(K.label("Ready to collect: " + ", ".join(ready.map(func(o): return "%d %s" % [o.qty, Data.items[o.bar].name])), 7, K.MOSS))
				rh.add_child(K.button("Collect", func(): Game.forge_collect(); render_overlay(), "small"))
				body.add_child(rh)
			if not pending.is_empty():
				body.add_child(K.label("In the furnace: " + ", ".join(pending.map(func(o): return "%d %s (ready %s)" % [o.qty, Data.items[o.bar].name, Game.date_label(int(o.ready_day))])), 7, K.INK_SOFT, true))
		"upgrade":
			body.add_child(K.label("Upgrades need refined bars, gold and your current tool. The tool stays with Ines until it is done.", 7, K.INK_SOFT, true))
			for t in Data.tool_defs:
				if not Data.tool_defs[t].upgradable: continue
				var tid: String = t
				var cur := Game.tool_tier(t)
				var up := Game.next_upgrade(t)
				var busy = Game.tool_busy(t)
				var row := K.row_box()
				var rh := K.hbox(3)
				rh.add_child(K.icon(Art.get_icon(t, cur), 16))
				var text := ""
				if busy != null:
					text = "[b]%s %s[/b]\nBeing upgraded to %s. Back on %s." % [Data.tool_tiers[cur].name, Data.tool_defs[t].name, Data.tool_tiers[int(busy.tier)].name, Game.date_label(int(busy.ready_day))]
				elif up.is_empty():
					text = "[b]%s %s[/b]\nFully upgraded." % [Data.tool_tiers[cur].name, Data.tool_defs[t].name]
				else:
					rh.add_child(K.label("➜", 8))
					rh.add_child(K.icon(Art.get_icon(t, up.tier), 16))
					var ok_b: bool = Game.count_item(up.bar) >= up.bars
					var ok_m: bool = int(st.money) >= up.cost
					text = "[b]%s → %s %s[/b]\n[font_size=5]Now: %s Upgraded: %s[/font_size]\n[color=%s]%d %ss (have %d)[/color] · [color=%s]%d gold[/color] · %d days" % [
						Data.tool_tiers[cur].name, Data.tool_tiers[up.tier].name, Data.tool_defs[t].name, Game.tool_effect_text(t, cur), Game.tool_effect_text(t, up.tier),
						"#3f7a2c" if ok_b else "#b3392e", up.bars, Data.items[up.bar].name, Game.count_item(up.bar), "#3f7a2c" if ok_m else "#b3392e", up.cost, up.days]
				var rl := K.rich(text, 6)
				rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rh.add_child(rl)
				if busy == null and not up.is_empty():
					var b := K.button("Upgrade", func():
						overlay.err = Game.forge_upgrade(tid)
						if overlay.err == "": toast("Ines took your %s. It will be ready in %d days." % [Data.tool_defs[tid].name, Data.tool_upgrades[Game.tool_tier(tid) + 1].days], tid)
						render_overlay(), "small")
					b.disabled = not (Game.count_item(up.bar) >= up.bars and int(st.money) >= up.cost)
					rh.add_child(b)
				row.add_child(rh)
				body.add_child(row)
		"repair":
			body.add_child(_repair_box())
		"shop":
			body.add_child(_shop_box("forge"))
	v.add_child(K.scroll(body, 170))
	if overlay.get("err", "") != "": v.add_child(K.label(overlay.err, 7, K.DANGER))
	v.add_child(_close_btn("Leave"))
	return pw[0]

# ---------------------------------------------------------------- crafting
func recipe_unlocked(r: Dictionary) -> bool:
	if r.unlock.type == "start": return true
	if r.unlock.type == "skill": return Game.skill_level(r.unlock.skill) >= r.unlock.level
	if r.unlock.type == "friend": return Game.hearts(r.unlock.npc) >= r.unlock.hearts
	if r.unlock.type == "has_item": return Game.count_item(r.unlock.item) > 0
	if r.unlock.type == "reward": return Game.state.flags.get("recipe_" + r.out, false)
	return false

func unlock_text(r: Dictionary) -> String:
	if r.unlock.type == "skill": return "Locked: reach %s level %d." % [Data.skills[r.unlock.skill].name, r.unlock.level]
	if r.unlock.type == "friend": return "Locked: become friends with %s (%d hearts)." % [Data.npcs[r.unlock.npc].name.split(" ")[0], r.unlock.hearts]
	if r.unlock.type == "has_item": return "Locked: needs a %s in your pack." % Data.items[r.unlock.item].name
	if r.unlock.type == "reward": return "Locked: %s." % str(r.unlock.get("text", "a recipe reward"))
	return "Locked."

const STATION_NAMES := {"stove": "Stove, Campfire or Cookstove", "hand": "By hand, anywhere", "ammo_bench": "Ammo Bench", "armory_bench": "Armory Bench",
	"workbench": "Workbench", "anvil": "Anvil", "electronics_bench": "Electronics Bench", "chem_station": "Chemistry Station", "sewing_table": "Sewing Table",
	"brick_furnace": "Brick Furnace", "loom": "Loom", "ferment_barrel": "Fermentation Barrel", "grain_mill": "Grain Mill"}

func _recipes(station: String, show_all: bool) -> VBoxContainer:
	var v := K.vbox(2)
	var last_group := ""
	for r in Data.recipes:
		if not show_all and r.station != station: continue
		if show_all and r.station == "stove": continue
		if r.get("group", "") != last_group:
			last_group = r.get("group", "")
			v.add_child(K.label(last_group, 8, K.WOOD_DARK))
		var un := recipe_unlocked(r)
		var here: bool = r.station == station
		var row := K.row_box()
		var rh := K.hbox(3)
		var ic := K.icon(Art.get_icon(r.out), 16)
		if not un: ic.modulate = Color(1, 1, 1, 0.4)
		rh.add_child(ic)
		var ins := []
		for pair in r.inputs:
			var have := Game.count_match(pair[0])
			var nm: String = Game.spec_name(pair[0])
			ins.append("[color=%s]%d %s (%d)[/color]" % ["#3f7a2c" if have >= pair[1] else "#b3392e", pair[1], nm, have])
		var text := "[b]%s%s[/b]\n%s\n[font_size=5]%s · %s%s[/font_size]" % [Data.items[r.out].name, " x%d" % r.qty if r.qty > 1 else "",
			", ".join(ins) if un else unlock_text(r),
			STATION_NAMES.get(r.station, r.station), Data.items[r.out].desc, (" " + r.note) if r.has("note") else ""]
		var rl := K.rich(text, 6)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(rl)
		if here:
			var can: bool = un and r.inputs.all(func(p): return Game.count_match(p[0]) >= p[1]) and Game.can_fit(r.out, r.qty)
			var rec: Dictionary = r
			var b := K.button("Cook" if station == "stove" else "Make", func(): _craft(rec), "small")
			b.disabled = not can
			rh.add_child(b)
		else:
			rh.add_child(K.label("At the " + ("stove" if r.station == "stove" else "ammo bench"), 6, K.INK_SOFT))
		row.add_child(rh)
		v.add_child(row)
	return v

func _craft(r: Dictionary) -> void:
	if not r.inputs.all(func(p): return Game.count_match(p[0]) >= p[1]) or not Game.can_fit(r.out, r.qty):
		overlay.err = "Missing ingredients or no room."
		render_overlay()
		return
	for p in r.inputs:
		Game.consume_match(p[0], p[1])
	Game.add_item(r.out, r.qty)
	if r.station == "stove":
		Game.add_xp("cooking", 12)
	Sfx.play("eat" if r.station == "stove" else "pick")
	overlay.err = ""
	render_overlay()

## Your own anvil: upgrade tools with 5 bars of the next metal, on the spot.
func _ov_anvil() -> Control:
	var pw := _window("Anvil", 380)
	var v: VBoxContainer = pw[1]
	v.add_child(K.label("Upgrade a tool with 5 bars of the next metal (Aurium also needs a Glimmerite). No fee, no wait.", 7, K.INK_SOFT, true))
	for t in Data.tool_defs:
		if not Data.tool_defs[t].upgradable: continue
		var up := Game.next_upgrade(t)
		var row := K.row_box()
		var rh := K.hbox(4)
		rh.add_child(K.icon(Art.get_icon(t, Game.tool_tier(t)), 16))
		var txt := "%s %s" % [Data.tool_tiers[Game.tool_tier(t)].name, Data.tool_defs[t].name]
		if not up.is_empty(): txt += "  >  %s (5 %s, you have %d)" % [Data.tool_tiers[int(up.tier)].name, Data.items[up.bar].name, Game.count_item(up.bar)]
		var nl := K.label(txt, 6)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(nl)
		if not up.is_empty():
			var tid: String = t
			rh.add_child(K.button("Upgrade", func():
				overlay.err = Game.anvil_upgrade(tid)
				if overlay.err == "": toast("Upgraded your %s." % Data.tool_defs[tid].name, tid, "gold")
				render_overlay(), "small"))
		row.add_child(rh)
		v.add_child(row)
	v.add_child(K.label("Also made here:", 7, K.WOOD_DARK))
	v.add_child(K.scroll(_recipes("anvil", false), 90))
	if overlay.get("err", "") != "": v.add_child(K.label(overlay.err, 7, K.DANGER))
	v.add_child(_close_btn())
	return pw[0]

func _ov_craft() -> Control:
	var pw := _window({"stove": "Cooking"}.get(overlay.station, STATION_NAMES.get(overlay.station, "Crafting")), 380)
	pw[1].add_child(K.scroll(_recipes(overlay.station, false), 170))
	if overlay.get("err", "") != "": pw[1].add_child(K.label(overlay.err, 7, K.DANGER))
	pw[1].add_child(_close_btn())
	return pw[0]

# ---------------------------------------------------------------- journal
func _ov_journal() -> Control:
	var tab: String = overlay.get("tab", "inventory")
	var p := K.panel(440, 226)
	var v := K.vbox(3)
	var tabs := K.hbox(1)
	for t in TABS:
		var tid: String = t
		var b := K.button(TABS[t], func():
			overlay.tab = tid
			overlay.erase("pick")
			render_overlay(), "small")
		if tid == tab:
			b.add_theme_stylebox_override("normal", K.sb(K.PARCH, K.WOOD, 1, 2, Color(0, 0, 0, 0), 0, 3))
			b.add_theme_color_override("font_color", K.WOOD_DARK)
			b.add_theme_constant_override("outline_size", 0)
		tabs.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	tabs.add_child(K.button("✕", close, "danger"))
	v.add_child(tabs)
	v.add_child(call("_tab_" + tab))
	p.add_child(v)
	return p

func _tab_inventory() -> Control:
	var st: Dictionary = Game.state
	var h := K.hbox(8)
	var left := K.vbox(3)
	var g := GridContainer.new()
	g.columns = 12
	for i in st.inventory.size():
		var s = st.inventory[i]
		var idx: int = i
		var tier := Game.tool_tier(Data.items[s.id].tool) if (s != null and Data.items[s.id].has("tool")) else 0
		var sl := K.slot(s, func(_b): _inv_click(idx), tier, overlay.get("pick", -1) == i or overlay.get("sel", -1) == i, false, 20)
		if i < Balance.inventory.toolbar_size:
			sl.self_modulate = Color(1.05, 1.0, 0.85)
		g.add_child(sl)
	left.add_child(g)
	var row := K.hbox()
	row.add_child(K.button("Sort pack", func():
		Game.sort_inventory()
		overlay.erase("sel"); overlay.erase("pick")
		render_overlay(), "small"))
	row.add_child(K.label("%d / %d slots used%s" % [st.inventory.filter(func(x): return x != null).size(), st.inventory.size(), "" if st.flags.get("backpack", false) else " · A larger backpack is sold at Brennan's General"], 6, K.INK_SOFT))
	left.add_child(row)
	var eq := K.row_box()
	var eh := K.hbox(6)
	var face := K.icon(Art.get_char(st.character.look, "down", 0), 16)
	face.custom_minimum_size = Vector2(24, 48)
	eh.add_child(face)
	# what you're wearing: click a slot to see it or take it off
	var gv := K.vbox(1)
	var gslots := K.hbox(2)
	for slot in Arsenal.SLOTS:
		var sv := K.vbox(0)
		var sname: String = slot
		var es = st.equip.get(slot)
		var gsl := K.slot(es, func(_b):
			overlay.erase("pick"); overlay.erase("sel")
			overlay.eq = sname
			render_overlay(), 0, overlay.get("eq", "") == slot, false, 20)
		sv.add_child(gsl)
		sv.add_child(K.label(Arsenal.SLOT_NAMES[slot], 5, K.INK_SOFT))
		gslots.add_child(sv)
	gv.add_child(gslots)
	var gt := Game.gear_total()
	var red: float = gt.armor / (gt.armor + Balance.armor.armor_k) * 100.0
	gv.add_child(K.label("Armor %d (-%d%% damage) · Max health %d · Bite resist %d%%\nSpeed %+d%% · Noise %+d%% · Extra pockets %d" % [int(gt.armor), int(red), int(Game.max_health()), int(gt.bite * 100), int(gt.move * 100), int(gt.noise * 100), int(gt.carry)], 6, null, true))
	gv.add_child(K.label("Shift: sprint · Ctrl: crouch · V: shove or stomp · R: reload", 5, K.INK_SOFT))
	eh.add_child(gv)
	eq.add_child(eh)
	left.add_child(eq)
	h.add_child(left)
	var det := K.row_box()
	det.custom_minimum_size.x = 150
	var dv := K.vbox(3)
	var sel = st.inventory[overlay.sel] if overlay.has("sel") and overlay.sel < st.inventory.size() else null
	var eq_slot: String = overlay.get("eq", "")
	if eq_slot != "" and sel == null:
		sel = st.equip.get(eq_slot)
	if sel == null and eq_slot != "":
		dv.add_child(K.label("Nothing worn on your %s. Click clothing or armour in your pack, then Wear." % Arsenal.SLOT_NAMES[eq_slot].to_lower(), 6, K.INK_SOFT, true))
	elif sel == null:
		dv.add_child(K.label("Click an item to see details. Click two slots in a row to move or swap them. The top row is your toolbar.", 6, K.INK_SOFT, true))
	else:
		var it: Dictionary = Data.items[sel.id]
		var fl := Game.item_flags(sel.id)
		var hh := K.hbox(4)
		hh.add_child(K.icon(Art.get_icon(sel.id, Game.tool_tier(it.tool) if it.has("tool") else 0), 24))
		hh.add_child(K.rich("[b]%s[/b]\n[color=%s]%s[/color] · x%d" % [Game.item_display_name(sel.id), Data.categories[it.cat].color, Data.categories[it.cat].label, sel.qty], 7))
		hh.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dv.add_child(hh)
		if it.has("weapon") or it.has("gear"):
			dv.add_child(K.rich(gear_info(sel), 6))
		else:
			dv.add_child(K.label(it.desc, 6, null, true))
			if it.has("buffs"):
				dv.add_child(K.label("Also: " + ", ".join(it.buffs.map(func(b): return Game.buff_text(str(b.stat), float(b.v), int(b.min)))), 6, K.MOSS, true))
			var od: Dictionary = Data.obj_defs.get(it.get("place", ""), {})
			var todo: String = str(it.get("todo", od.get("todo", "")))
			if todo != "":
				dv.add_child(K.label("Not in the game yet: " + todo, 6, Color("#9a8a7a"), true))
			if it.has("sheet") and it.sheet.where != "" and not it.has("weapon"):
				dv.add_child(K.label(("Made at: " if it.sheet.source in ["Craft", "Cook", "Machine", "Upgrade"] else "Found: ") + str(it.sheet.where), 5, K.INK_SOFT, true))
		if it.has("tool") and Data.tool_defs[it.tool].upgradable:
			dv.add_child(K.label(Game.tool_effect_text(it.tool, Game.tool_tier(it.tool)), 6, K.INK_SOFT, true))
		if it.has("edible"):
			var e: Dictionary = it.edible
			var parts := []
			if e.get("energy", 0): parts.append("%d energy" % e.energy)
			if e.get("hp", 0): parts.append("%d health" % e.hp)
			if Game.is_survivor() and e.get("hunger", 0): parts.append("%d hunger" % e.hunger)
			if Game.is_survivor() and e.get("thirst", 0): parts.append("%d thirst" % e.thirst)
			dv.add_child(K.label("Restores: " + ", ".join(parts), 6, K.INK_SOFT, true))
		var tags := []
		if fl.sellable: tags.append("[bgcolor=#a87a10][color=white] Sellable (%d) [/color][/bgcolor]" % it.price)
		if fl.edible: tags.append("[bgcolor=#c8642a][color=white] Edible [/color][/bgcolor]")
		if fl.donatable: tags.append("[bgcolor=#7a4aa0][color=white] Collectible [/color][/bgcolor]")
		if fl.placeable: tags.append("[bgcolor=#4a7a6a][color=white] Placeable [/color][/bgcolor]")
		if fl.plantable: tags.append("[bgcolor=#3f7a2c][color=white] Plantable [/color][/bgcolor]")
		if fl.tool or fl.weapon: tags.append("[bgcolor=#3f6fb5][color=white] Equipment (protected) [/color][/bgcolor]")
		if Data.recipes.any(func(r): return r.inputs.any(func(p): return Game.matches(p[0], sel.id))): tags.append("[bgcolor=#6a5a4a][color=white] Crafting ingredient [/color][/bgcolor]")
		dv.add_child(K.rich(" ".join(tags), 5))
		var br := K.hbox()
		var sidx: int = overlay.get("sel", -1)
		if it.has("gear") and eq_slot != "" and sidx < 0:
			br.add_child(K.button("Take off", func():
				Game.unequip(eq_slot)
				overlay.erase("eq")
				render_overlay(), "small"))
		elif it.has("gear"):
			br.add_child(K.button("Wear", func():
				Game.equip_from(sidx)
				overlay.erase("pick"); overlay.erase("sel")
				overlay.eq = Data.gear[it.id].slot
				render_overlay(), "small"))
		if fl.edible:
			br.add_child(K.button(it.get("use_word", "Drink" if it.get("drink", false) else "Eat"), func():
				var s2 = Game.state.inventory[sidx]
				if s2 != null: Game.eat_item(s2.id)
				overlay.erase("pick")
				render_overlay(), "small"))
		if not fl.protected:
			br.add_child(K.button("Discard 1", func():
				var s2 = Game.state.inventory[sidx]
				if s2 != null and not Game.item_flags(s2.id).protected:
					toast("Discarded 1 %s." % Data.items[s2.id].name)
					Game.remove_from_slot(sidx, 1)
				overlay.erase("pick")
				render_overlay(), "danger"))
		dv.add_child(br)
	det.add_child(dv)
	h.add_child(det)
	return h

## Stats, effects and story for a weapon or piece of gear.
func gear_info(s: Dictionary) -> String:
	var it: Dictionary = Data.items[s.id]
	var t := ""
	var rar: String = it.get("rarity", "Normal")
	if it.has("weapon"):
		var w: Dictionary = it.weapon
		t += "[color=%s]%s %s %s[/color]\n" % [Arsenal.rarity_color(rar), rar, w.category, w.type]
		var dmg := "%d" % int(w.damage) + (" x%d" % int(w.projectiles) if int(w.projectiles) > 1 else "")
		t += "Damage [b]%s[/b] · %s per second · Range %s tiles · Crit %d%%\n" % [dmg, str(snappedf(float(w.aps), 0.01)), str(snappedf(float(w.range), 0.1)), int(w.crit)]
		var extra := []
		if float(w.stamina) > 0: extra.append("Energy %s per attack" % str(snappedf(float(w.stamina) * Balance.weapons.stamina_to_energy, 0.1)))
		extra.append("Noise %d/5" % int(w.noise))
		if w.ammo != "":
			var an: Array = Arsenal.ammo_ids(w).map(func(a): return Data.items[a].name)
			extra.append("Ammo: " + " or ".join(an))
		if int(w.mag) > 1: extra.append("Loaded %d/%d" % [int(Game.mag_of(s)), int(w.mag)])
		if float(w.reload) > 0: extra.append("Reload %ss" % str(w.reload))
		t += " · ".join(extra) + "\n"
	else:
		var g: Dictionary = it.gear
		t += "[color=%s]%s %s (%s)[/color]\n" % [Arsenal.rarity_color(rar), rar, Arsenal.SLOT_NAMES[g.slot], g.weight]
		if not g.cosmetic:
			var parts := ["Armor %d" % int(g.armor)]
			if g.hp: parts.append("Health %+d" % int(g.hp))
			if g.move: parts.append("Speed %+d%%" % int(g.move * 100))
			if g.regen: parts.append("Stamina %+d%%" % int(g.regen * 100))
			if g.bite: parts.append("Bite resist %+d%%" % int(g.bite * 100))
			if g.noise: parts.append("Noise %+d%%" % int(g.noise * 100))
			if g.carry: parts.append("Pockets +%d" % int(g.carry))
			t += " · ".join(parts) + "\n"
	var md := Game.max_dur(s.id)
	if md > 0:
		t += ("[color=#c83a2a][b]Broken.[/b] Repair it at Varga Forge or Mercer Workshop.[/color]\n" if Game.is_broken(s) else "Durability %d/%d\n" % [Game.stack_dur(s), md])
	var d: Dictionary = it.get("weapon", it.get("gear", {}))
	var inactive: Array = d.get("inactive", [])
	for k in [["trait", "Trait"], ["passive", "Passive"], ["ability", "Ability"], ["bonus", "Legendary"]]:
		var txt: String = d.get(k[0], "")
		if txt == "" or txt == "Cosmetic only": continue
		var shown := []
		for part in txt.split(";"):
			var pt := part.strip_edges()
			if pt == "": continue
			shown.append(("[color=#9a8a7a]%s (not in the game yet)[/color]" % pt) if inactive.has(pt) and not _flavor(pt) else pt)
		t += "[color=#7a5434]%s:[/color] %s\n" % [k[1], "; ".join(shown)]
	if d.get("look", "") != "": t += "[i]%s[/i]\n" % d.look
	if d.get("flavor", "") != "": t += "[color=#6a5a4a][i]%s[/i][/color]\n" % d.flavor
	elif it.has("gear") and d.get("cosmetic", false): t += "Cosmetic. Changes nothing but how you feel.\n"
	t += "[color=#8a7a6a]Found: %s[/color]" % d.get("how", "")
	return t

## Descriptive text that isn't meant to do anything by itself.
func _flavor(t: String) -> bool:
	for w in ["pockets", "reach", "plating", "soles", "quiet", "light", "pattern", "rubber", "vest", "suit", "sprinting", "never jams", "sidearm", "firearm", "semi-auto", "handling", "belt-fed", "magazine", "stab", "one-handed", "breaks easily", "plentiful", "camouflage", "denim", "leather", "slippery", "footsteps", "knee armor", "accurate", "mailbag", "stopping", "draw stamina", "thrown as a pair"]:
		if t.to_lower().contains(w): return true
	return false

func _inv_click(i: int) -> void:
	overlay.erase("eq")
	var inv: Array = Game.state.inventory
	if overlay.has("pick") and overlay.pick != i:
		var tmp = inv[i]
		inv[i] = inv[overlay.pick]
		inv[overlay.pick] = tmp
		overlay.erase("pick")
		overlay.sel = i
	elif overlay.get("pick", -1) == i:
		overlay.erase("pick")
	else:
		overlay.sel = i
		if inv[i] != null: overlay.pick = i
		else: overlay.erase("pick")
	render_overlay()

func _tab_skills() -> Control:
	var g := GridContainer.new()
	g.columns = 2
	var t: Array = Balance.skills.xp_table
	for id in Data.skills:
		var s: Dictionary = Data.skills[id]
		var box := K.row_box()
		box.custom_minimum_size.x = 210
		var v := K.vbox(1)
		if s.phase > 1:
			box.modulate = Color(1, 1, 1, 0.6)
			v.add_child(K.rich("[b]%s[/b]  [color=#7a5434]Not yet available[/color]" % s.name, 7))
			v.add_child(K.label("%s. %s" % [s.gain, s.perk], 6, K.INK_SOFT, true))
		else:
			var lvl := Game.skill_level(id)
			var xp: int = int(Game.state.skills[id].xp)
			var nxt: int = t[min(lvl + 1, t.size() - 1)]
			v.add_child(K.rich("[b]%s[/b]  [color=#3f7a2c]Level %d[/color]" % [s.name, lvl], 7))
			var pips := ""
			for i in Balance.skills.max_level:
				pips += "[color=#c8402a]■[/color]" if i < lvl else "[color=#c8a888]■[/color]"
			v.add_child(K.rich(pips, 7))
			v.add_child(K.label("%d XP%s · Gain by: %s" % [xp, (" · %d to next level" % (nxt - xp)) if lvl < Balance.skills.max_level else " · max level", s.gain], 6, K.INK_SOFT, true))
			v.add_child(K.label(s.perk, 6, null, true))
		box.add_child(v)
		g.add_child(box)
	return K.scroll(g, 186)

func _tab_map() -> Control:
	var st: Dictionary = Game.state
	var h := K.hbox(8)
	var here := "mine" if Game.map.mine else ""
	for r in Data.regions:
		if r.has("maps") and r.maps.has(Game.map.id): here = r.id
	var cell := 26.0
	var wm := Panel.new()
	wm.custom_minimum_size = Vector2(9 * cell + 4, 6 * cell + 4)
	wm.add_theme_stylebox_override("panel", K.sb(Color("#6a9a50"), K.WOOD, 2, 3, K.OUTLINE, 1, 0))
	for r in Data.regions:
		var unlocked: bool = not r.has("lock") and st.unlocked.get(r.id, false)
		var name: String = st.property_name if r.id == "homestead" else r.name
		var rp := PanelContainer.new()
		var col := Color("#f8e2b0") if unlocked else Color(0.18, 0.14, 0.1, 0.65)
		rp.add_theme_stylebox_override("panel", K.sb(col, Color("#e8402a") if r.id == here else (K.WOOD if unlocked else Color("#8a7a6a")), 2 if r.id == here else 1, 3, Color(0, 0, 0, 0), 0, 1))
		rp.position = Vector2(2 + r.gx * cell + 1, 2 + r.gy * cell + 1)
		rp.size = Vector2(r.gw * cell - 2, r.gh * cell - 2)
		rp.custom_minimum_size = rp.size
		var l := K.label(name + ("\nYou are here" if r.id == here else ""), 5, K.WOOD_DARK if unlocked else Color("#e8dcc8"), true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rp.add_child(l)
		rp.tooltip_text = name if unlocked else name + ": " + r.get("lock", "Locked")
		rp.mouse_filter = Control.MOUSE_FILTER_PASS
		wm.add_child(rp)
	h.add_child(wm)
	var v := K.vbox(2)
	v.add_child(K.label("Current location", 8, K.WOOD_DARK))
	v.add_child(K.label(Game.location_name(), 7))
	v.add_child(K.label("Town services", 8, K.WOOD_DARK))
	for id in Data.shops:
		var s: Dictionary = Data.shops[id]
		v.add_child(K.rich("[b]%s[/b]: %s to %s, closed %s. %s" % [s.name, Game.fmt_time(s.open), Game.fmt_time(s.close), ", ".join(s.closed_days), "[color=#3f7a2c]Open now[/color]" if Game.is_shop_open(id) else "[color=#b3392e]Closed now[/color]"], 6))
	v.add_child(K.label("Lantern Post tavern: boarded up for now.\nCommunity Archive: closed for restoration.", 6, null, true))
	v.add_child(K.label("Old Mine", 8, K.WOOD_DARK))
	v.add_child(K.label("North of town, up the Ridge Path. Deepest floor: %s. Hover a locked area to see why it's closed." % (str(st.mine.deepest) if int(st.mine.deepest) > 0 else "none yet"), 6, K.INK_SOFT, true))
	v.custom_minimum_size.x = 170
	h.add_child(v)
	return h

func _tab_quests() -> Control:
	var q: Dictionary = Game.state.quests
	var v := K.vbox(2)
	v.add_child(K.label("Active tasks", 8, K.WOOD_DARK))
	if q.active.is_empty(): v.add_child(K.label("No active tasks.", 6, K.INK_SOFT))
	for id in q.active:
		var d := Game.quest_def(id)
		var r: Dictionary = d.get("reward", {})
		var rew := []
		if r.has("money"): rew.append("%d gold" % r.money)
		for pair in r.get("items", []): rew.append("%d %s" % [pair[1], Data.items[pair[0]].name])
		var b := K.row_box()
		b.add_child(K.rich("[b]%s[/b]  [color=#5a2c0e]%s[/color]\n%s\n[font_size=5][color=#7a5434]From: %s · Reward: %s[/color][/font_size]" % [d.title, Game.quest_progress_text(d), d.desc, Data.npcs[d.giver].name, ", ".join(rew)], 6))
		v.add_child(b)
	v.add_child(K.label("Main story", 8, K.WOOD_DARK))
	for s in Data.story:
		var b := K.row_box()
		if s.get("locked", false): b.modulate = Color(1, 1, 1, 0.6)
		b.add_child(K.rich("[b]%s[/b]\n%s" % [s.title, s.text], 6))
		v.add_child(b)
	v.add_child(K.label("Completed", 8, K.WOOD_DARK))
	if q.done.is_empty(): v.add_child(K.label("Nothing yet.", 6, K.INK_SOFT))
	for id in q.done:
		v.add_child(K.label("✔ " + Game.quest_def(id).title, 6, K.MOSS))
	return K.scroll(v, 186)

func _tab_social() -> Control:
	var g := GridContainer.new()
	g.columns = 2
	var st: Dictionary = Game.state
	for id in Data.npcs:
		var d: Dictionary = Data.npcs[id]
		var rel: Dictionary = st.npcs[id]
		var b := K.row_box()
		b.custom_minimum_size.x = 210
		var h := K.hbox(4)
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", K.sb(Color("#8fbf70"), K.WOOD_DARK, 1, 2, Color(0, 0, 0, 0), 0, 1))
		var pi := K.icon(Art.get_portrait(d.look), 22)
		pi.custom_minimum_size = Vector2(24, 21)
		frame.add_child(pi)
		h.add_child(frame)
		var known := []
		for kk in rel.known:
			known.append("%s (%s)" % [Data.items[kk].name, rel.known[kk]])
		var where := "At home"
		var nm: String = Game.npcs[id].map
		if nm != "": where = st.property_name if nm == "homestead" else Data.location_names.get(nm, nm)
		var t := K.rich("[b]%s[/b] [font_size=5][color=#7a5434]%s[/color][/font_size]\n%s\n[font_size=5]Talked today: %s · Gift today: %s · Birthday: %s %d%s\nGift tastes: %s\nRecruitment: available in a later update.[/font_size]" % [
			d.name if rel.met else "???", d.role if rel.met else "Not met yet", K.hearts(Game.hearts(id)), "✔" if int(rel.talked_day) == int(st.day) else "–", "✔" if int(rel.gifted_day) == int(st.day) else "–",
			d.birthday.season.capitalize(), d.birthday.day, (" · Now: " + where) if rel.met else "", ", ".join(known) if not known.is_empty() else "give gifts to learn what they like"], 6)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		b.add_child(h)
		g.add_child(b)
	var wrap := K.vbox(4)
	wrap.add_child(g)
	wrap.add_child(_animals_box())
	return K.scroll(wrap, 186)

func _animals_box() -> Control:
	var v := K.vbox(2)
	var list: Array = Game.state.get("animals", [])
	v.add_child(K.label("Your animals (%d)" % list.size(), 8, K.WOOD_DARK))
	if list.is_empty():
		v.add_child(K.label("No animals yet. Build a coop and visit Marisol at Reyes Ranch, north of the town square.", 6, K.INK_SOFT, true))
		return v
	var g := GridContainer.new()
	g.columns = 2
	for a in list:
		var b := K.row_box()
		b.custom_minimum_size.x = 210
		var h := K.hbox(4)
		var ic := K.icon(Art.get_animal(a.type, int(a.color), "down", 0, Game.animal_mature(a)), 16)
		h.add_child(ic)
		var hearts := int(a.friendship) / 200
		var t := K.rich("[b]%s[/b] [font_size=5][color=#7a5434]%s%s[/color][/font_size]\n%s\n[font_size=5]Mood: %s · Petted today: %s[/font_size]" % [a.name, Data.animals[a.type].name, "" if Game.animal_mature(a) else " (baby)", K.hearts(hearts), Game.animal_mood(a), "✔" if int(a.petted_day) == int(Game.state.day) else "–"], 6)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		b.add_child(h)
		g.add_child(b)
	v.add_child(g)
	return v

func _tab_crafting() -> Control:
	var v := K.vbox(2)
	v.add_child(K.label("Hand recipes can be made anywhere. Ammunition is made at an Ammo Bench; cooking at the stove in your house. New recipes unlock as your skills grow.", 6, K.INK_SOFT, true))
	v.add_child(_recipes("hand", true))
	if overlay.get("err", "") != "": v.add_child(K.label(overlay.err, 7, K.DANGER))
	return K.scroll(v, 186)

func _tab_collections() -> Control:
	var v := K.vbox(3)
	var found: Dictionary = Game.state.collections.found
	for col in Data.collections:
		var ids := Game.collection_items(col)
		var n := ids.filter(func(i): return found.has(i)).size()
		v.add_child(K.rich("[b]%s[/b]  [color=#7a5434]%d/%d (%d%%)[/color]" % [Data.collections[col], n, ids.size(), int(100.0 * n / max(1, ids.size()))], 7))
		var flow_c := HFlowContainer.new()
		for id in ids:
			var cell := PanelContainer.new()
			cell.add_theme_stylebox_override("panel", K.sb(Color("#f0c88a") if found.has(id) else Color("#8a7a6a"), Color("#c0803e"), 1, 1, Color(0, 0, 0, 0), 0, 1))
			cell.custom_minimum_size = Vector2(18, 18)
			cell.mouse_filter = Control.MOUSE_FILTER_PASS
			if found.has(id):
				cell.add_child(K.icon(Art.get_icon(id), 16))
				cell.tooltip_text = Data.items[id].name + ": " + Data.items[id].desc + (" Shipped: %d" % Game.state.collections.shipped[id] if Game.state.collections.shipped.has(id) else "")
			else:
				var q := K.label("?", 8, Color("#e8dcc8"))
				q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cell.add_child(q)
				cell.tooltip_text = "Not discovered yet"
			flow_c.add_child(cell)
		v.add_child(flow_c)
	# shipping log: every crop, forage, fish and artisan good you've sent out in the trade crate
	var ship_ids := []
	for id in Data.items:
		if Data.items[id].cat in ["crop", "forage", "fish", "artisan"]: ship_ids.append(id)
	var shipped: Dictionary = Game.state.collections.shipped
	var sn := ship_ids.filter(func(i): return shipped.has(i)).size()
	v.add_child(K.rich("[b]Shipping Log[/b]  [color=#7a5434]%d/%d shipped (%d%%)[/color]" % [sn, ship_ids.size(), int(100.0 * sn / max(1, ship_ids.size()))], 7))
	var sf := HFlowContainer.new()
	for id in ship_ids:
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", K.sb(Color("#f0c88a") if shipped.has(id) else Color("#8a7a6a"), Color("#c0803e"), 1, 1, Color(0, 0, 0, 0), 0, 1))
		cell.custom_minimum_size = Vector2(18, 18)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		var ic := K.icon(Art.get_icon(id), 16)
		if not shipped.has(id): ic.modulate = Color(0, 0, 0, 0.45)
		cell.add_child(ic)
		cell.tooltip_text = (Data.items[id].name + ": shipped %d" % int(shipped[id])) if shipped.has(id) else "Not shipped yet"
		sf.add_child(cell)
	v.add_child(sf)
	v.add_child(K.label("Museum donations: the Brightwater Community Archive is closed for restoration. Keep your finest finds.", 6, K.INK_SOFT, true))
	return K.scroll(v, 186)

func _tab_calendar() -> Control:
	var st: Dictionary = Game.state
	var si: int = overlay.get("cal_season", Game.season_index())
	var season: String = Balance.calendar.seasons[si]
	var y := Game.year()
	var v := K.vbox(2)
	var hh := K.hbox()
	hh.alignment = BoxContainer.ALIGNMENT_CENTER
	hh.add_child(K.button("◀", func(): overlay.cal_season = (si + 3) % 4; render_overlay(), "small"))
	var tl := K.label("%s, Year %d" % [season.capitalize(), y], 9, K.WOOD_DARK)
	tl.custom_minimum_size.x = 100
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hh.add_child(tl)
	hh.add_child(K.button("▶", func(): overlay.cal_season = (si + 1) % 4; render_overlay(), "small"))
	v.add_child(hh)
	var g := GridContainer.new()
	g.columns = 7
	for d in range(1, 31):
		var ad := Game.abs_day(si, d, y)
		var c := PanelContainer.new()
		var today := ad == int(st.day)
		c.add_theme_stylebox_override("panel", K.sb(Color("#fff4c8") if today else K.PARCH_2, Color("#e8402a") if today else K.PARCH_3, 1, 1, Color(0, 0, 0, 0), 0, 1))
		c.custom_minimum_size = Vector2(60, 24)
		if ad < int(st.day): c.modulate = Color(1, 1, 1, 0.55)
		var txt := "[b]%d[/b] [font_size=4]%s[/font_size]" % [d, Balance.calendar.weekdays[(ad - 1) % 7]]
		for f in Data.festivals:
			if f.season == season and f.day == d: txt += "\n[bgcolor=#f0c860][font_size=4]%s[/font_size][/bgcolor]" % f.name
		for id in Data.npcs:
			var b: Dictionary = Data.npcs[id].birthday
			if b.season == season and b.day == d: txt += "\n[bgcolor=#f8c8d4][font_size=4]%s's birthday[/font_size][/bgcolor]" % Data.npcs[id].name.split(" ")[0]
		c.add_child(K.rich(txt, 6))
		g.add_child(c)
	v.add_child(g)
	var up := upcoming(4)
	v.add_child(K.label("Today is %s. %s. Upcoming: %s." % [Game.weekday(), Game.date_label(), "; ".join(up.map(func(e): return "%s (%s)" % [e.label, e.when])) if not up.is_empty() else "nothing soon"], 6, K.INK_SOFT, true))
	return K.scroll(v, 186)

func _tab_settings() -> Control:
	return K.scroll(_settings_box(true), 186)

func _settings_box(in_game: bool) -> Control:
	var v := K.vbox(3)
	var s: Dictionary = Game.settings
	v.add_child(K.label("Audio", 8, K.WOOD_DARK))
	for pair in [["music", "Music volume"], ["sfx", "Sound effects volume"]]:
		var key: String = pair[0]
		var h := K.hbox()
		var l := K.label(pair[1], 7)
		l.custom_minimum_size.x = 110
		h.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0
		sl.max_value = 100
		sl.value = s[key]
		sl.custom_minimum_size.x = 120
		sl.focus_mode = Control.FOCUS_NONE
		var val := K.label(str(s[key]), 7)
		sl.value_changed.connect(func(x):
			Game.settings[key] = int(x)
			val.text = str(int(x))
			Game.save_settings())
		h.add_child(sl)
		h.add_child(val)
		v.add_child(h)
	v.add_child(K.label("Display and controls", 8, K.WOOD_DARK))
	for pair in [["large_text", "Larger interface text"], ["high_contrast", "High-contrast interface"], ["show_target", "Show tool target outline"], ["pause_on_blur", "Pause when the window loses focus"]]:
		var key: String = pair[0]
		var cb := CheckBox.new()
		cb.text = pair[1]
		cb.button_pressed = s[key]
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on):
			Game.settings[key] = on
			Game.save_settings()
			if key in ["large_text", "high_contrast"]:
				if Game.screen == "title": render_title()
				else:
					build_hud()
					render_overlay())
		v.add_child(cb)
	var fs := CheckBox.new()
	fs.text = "Fullscreen"
	fs.focus_mode = Control.FOCUS_NONE
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	v.add_child(fs)
	v.add_child(_controls_box())
	if in_game:
		var st: Dictionary = Game.state
		var c: Dictionary = Balance.modes[st.mode]
		v.add_child(K.label("Difficulty", 8, K.WOOD_DARK))
		v.add_child(K.label("%s (%s). %s %s" % [c.label, c.difficulty, "Infected bites reload your last bed save." if c.bites_kill else "Infected cause normal damage.", "Hunger and thirst are active." if c.survival_meters else "No hunger or thirst requirements."], 6, null, true))
		v.add_child(K.label("Save", 8, K.WOOD_DARK))
		v.add_child(K.label("Slot %d. Saving happens when you sleep in your bed. Save files: %s" % [st.slot, ProjectSettings.globalize_path(Game.SAVE_DIR)], 6, null, true))
		var row := K.hbox()
		row.add_child(K.button("Back up save", func():
			var p := Game.export_slot(st.mode, int(st.slot))
			toast(("Backed up to " + p.get_file()) if p != "" else "Nothing saved yet. Sleep in your bed first.")))
		row.add_child(K.button("Open saves folder", func():
			DirAccess.make_dir_recursive_absolute(Game.SAVE_DIR)
			OS.shell_open(ProjectSettings.globalize_path(Game.SAVE_DIR))))
		row.add_child(K.button("Quit to title", _quit_confirm, "danger"))
		v.add_child(row)
	return v

func _controls_box() -> Control:
	var g := GridContainer.new()
	g.columns = 2
	for pair in [["Move", "WASD / Arrow keys"], ["Use tool or item", "Space / Left click (hold to charge or cast)"], ["Interact, talk, harvest", "E / Enter / Right click"],
		["Toolbar slot", "1-9, 0, -, =  ·  mouse wheel  ·  Q"], ["Eat selected item", "F"],
		["Aim a gun, bow or throw", "Point with the mouse and click (Space fires where you face)"], ["Sprint / Crouch", "Hold Shift / hold Ctrl"],
		["Shove (stomp if they're down)", "V"], ["Reload", "R"], ["Journal / Map / Tasks / Crafting", "Tab or I / M / J / C"], ["Pause", "Esc or P"]]:
		g.add_child(K.label(pair[0], 6, K.WOOD_DARK))
		g.add_child(K.label(pair[1], 6))
	return g

func _help_box() -> Control:
	var v := K.vbox(3)
	for t in ["The daily loop: wake at 6:00 am, work your land, visit Brightwater, explore the mine, and get to bed before 2:00 am. Sleeping in your bed is how the game saves.",
		"Farming: clear weeds with the scythe, rocks with the pickaxe and branches with the axe. Till soil with the hoe, plant, and water every day (rain does it for you). Crops die when their season ends.",
		"Selling: drop goods in the trade crate beside your house to sell them overnight, or sell directly at shops during opening hours.",
		"The forge: the mine has stone, copper, iron, gems and geodes. Ines cracks geodes, refines 5 ore and 1 coal into a bar, and upgrades tools with bars and gold.",
		"Fishing: talk to Wren at the river to get a rod. Hold to cast, press when the \"!\" appears, then hold Space to keep the fish inside the green bar.",
		"The infected: they wind up before they lunge (watch for the red \"!\"). Hit them to knock them back. In Survivor Mode a bite reloads your last sleep, unless your gear stops it (see Bite resist).",
		"Weapons and gear wear out. Repair them at Varga Forge or Mercer Workshop: the closer something is to breaking, the more it costs. In Survivor Mode a broken item is gone for good.",
		"Noise draws the infected. Guns are loud. Crouch to sneak up on infected that haven't noticed you: a hit from behind does extra damage, and knives kill outright."]:
		var l := K.label(t, 7, null, true)
		l.custom_minimum_size.x = 320
		v.add_child(l)
	v.add_child(_controls_box())
	return v
