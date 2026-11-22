class_name Talk
extends RefCounted
## Conversations written in Dialogic (Nov 21). Timelines live in res://dialogue/<name>.dtl and characters in
## res://dialogue/characters/<name>.dch; Daniel can open and edit both in Dialogic's editor (the Dialogic tab
## at the top of the Godot editor). The game stands still while one plays.
##
## A timeline talks to the game with signal events ([signal arg="..."]):
##   shop:<shop id>            open a shop (e.g. shop:festival)
##   give:<item id>:<count>    give the player items
##   gold:<amount>             give the player gold
##   friend:<npc id>:<points>  friendship points with a neighbour
##   flag:<name>               set a story flag (Game.state.flags)
##   quest:<quest id>          start a quest
##   toast:<text>              a message at the top of the screen

const DIR := "res://dialogue/"
const STYLE := "res://dialogue/harvest_style.tres"     # a textbox in the game's own colours and pixel font
static var _ready := false
static var _after := []       # things to do when the timeline ends (open a shop, ...)

static func has(name: String) -> bool:
	return ResourceLoader.exists(DIR + name + ".dtl") or FileAccess.file_exists(DIR + name + ".dtl")

static var _started_at := -10.0

## True while a conversation is showing (including the moment its textbox is still loading).
static func running() -> bool:
	var d = _dialogic()
	if d == null: return false
	return d.current_timeline != null or Time.get_ticks_msec() / 1000.0 - _started_at < 0.5

## Play a timeline. Returns false if there's no such timeline (so callers can fall back to plain lines).
static func play(name: String) -> bool:
	var d = _dialogic()
	if d == null or not has(name):
		return false
	_setup(d)
	_after = []
	if not d.Styles.has_active_layout_node():
		d.Styles.load_style(STYLE)
	_started_at = Time.get_ticks_msec() / 1000.0
	d.start(DIR + name + ".dtl")
	return true

static func _dialogic():
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Dialogic") if tree != null else null

static func _setup(d) -> void:
	if _ready:
		return
	_ready = true
	ProjectSettings.set_setting("dialogic/layout/default_style", STYLE)
	# Dialogic finds characters and timelines by name through an index the editor normally keeps
	DialogicResourceUtil.update_directory("dch")
	DialogicResourceUtil.update_directory("dtl")
	# the "next line" input: Enter, Space, E, a left click or a controller's A
	if not InputMap.has_action("dialogic_default_action"):
		InputMap.add_action("dialogic_default_action", 0.5)
		for k in [KEY_ENTER, KEY_SPACE, KEY_E, KEY_KP_ENTER]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event("dialogic_default_action", ev)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("dialogic_default_action", mb)
		var jb := InputEventJoypadButton.new()
		jb.button_index = JOY_BUTTON_A
		InputMap.action_add_event("dialogic_default_action", jb)
	d.signal_event.connect(_on_signal)
	d.timeline_ended.connect(_on_end)

static func _on_signal(arg) -> void:
	var p := str(arg).split(":")
	match p[0]:
		"shop":
			_after.append(func(): Game.ui.open("shop", {"shop": p[1]}))
		"open":
			_after.append(func(): Game.ui.open(p[1]))
		"give":
			if Data.items.has(p[1]): Game.add_item(p[1], int(p[2]) if p.size() > 2 else 1)
		"gold":
			Game.state.money = int(Game.state.money) + int(p[1])
		"friend":
			if Game.state.npcs.has(p[1]): Game.state.npcs[p[1]].points = int(Game.state.npcs[p[1]].points) + int(p[2])
		"flag":
			Game.state.flags[p[1]] = true
		"quest":
			if Game.has_method("start_quest"): Game.start_quest(p[1])
		"toast":
			Game.toast(str(arg).substr(6), "", "gold")

static func _on_end() -> void:
	_started_at = -10.0
	var todo := _after
	_after = []
	for f in todo:
		f.call()
