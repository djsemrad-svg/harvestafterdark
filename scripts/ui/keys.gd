class_name Keys
extends RefCounted
## Rebindable keys and a game controller (Nov 21). Game.settings.keys holds the player's choices
## (action -> physical keycode); anything not set uses DEFAULT. The arrow keys always move and Enter always
## interacts, whatever is bound. A controller works alongside: left stick or d-pad to move, A interact,
## X use (hold to charge), Y eat, B shove, LB / RB change the toolbar slot, Start pause, Back journal,
## left trigger crouch, right trigger sprint.

const ACTIONS := [
	["up", "Move up", KEY_W], ["down", "Move down", KEY_S], ["left", "Move left", KEY_A], ["right", "Move right", KEY_D],
	["use", "Use tool or item", KEY_SPACE], ["interact", "Interact, talk, harvest", KEY_E], ["eat", "Eat selected item", KEY_F],
	["reload", "Reload", KEY_R], ["shove", "Shove", KEY_V], ["sprint", "Sprint (double-tap to dash)", KEY_SHIFT], ["crouch", "Crouch", KEY_CTRL],
	["next_slot", "Next toolbar slot", KEY_Q], ["journal", "Journal", KEY_TAB], ["map", "Map", KEY_M], ["tasks", "Tasks", KEY_J], ["goals", "Today's goals (show all)", KEY_H],
	["crafting", "Crafting", KEY_C], ["pause", "Pause", KEY_ESCAPE],
]
const JOY := {JOY_BUTTON_A: "interact", JOY_BUTTON_X: "use", JOY_BUTTON_Y: "eat", JOY_BUTTON_B: "shove", JOY_BUTTON_START: "pause",
	JOY_BUTTON_BACK: "journal", JOY_BUTTON_LEFT_SHOULDER: "prev_slot", JOY_BUTTON_RIGHT_SHOULDER: "next_slot"}
const DEAD := 0.3

static var waiting := ""      # the action waiting for a new key (Settings), or ""

static func code(action: String) -> int:
	var k: Dictionary = Game.settings.get("keys", {})
	if k.has(action): return int(k[action])
	for a in ACTIONS:
		if a[0] == action: return int(a[2])
	return 0

static func label(action: String) -> String:
	return OS.get_keycode_string(code(action))

## Held down right now (keyboard or controller).
static func held(action: String) -> bool:
	if Input.is_physical_key_pressed(code(action)):
		return true
	match action:
		"up": return Input.is_physical_key_pressed(KEY_UP)
		"down": return Input.is_physical_key_pressed(KEY_DOWN)
		"left": return Input.is_physical_key_pressed(KEY_LEFT)
		"right": return Input.is_physical_key_pressed(KEY_RIGHT)
		"use": return Input.is_joy_button_pressed(0, JOY_BUTTON_X)
		"sprint": return Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5
		"crouch": return Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.5
	return false

## The movement direction from keys, d-pad and the left stick.
static func move_dir() -> Vector2:
	var d := Vector2.ZERO
	if held("left") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT): d.x -= 1
	if held("right") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT): d.x += 1
	if held("up") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP): d.y -= 1
	if held("down") or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN): d.y += 1
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() > DEAD:
		d += Vector2(signf(stick.x) if absf(stick.x) > DEAD else 0.0, signf(stick.y) if absf(stick.y) > DEAD else 0.0)
	return d.clamp(Vector2(-1, -1), Vector2(1, 1))

## Which action a key or controller button event is, or "".
static func action_of(e: InputEvent) -> String:
	if e is InputEventKey:
		var pk: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		for a in ACTIONS:
			if code(a[0]) == pk: return a[0]
		if pk in [KEY_ENTER, KEY_KP_ENTER]: return "interact"
		if pk == KEY_I: return "journal"
		if pk == KEY_P: return "pause"
	elif e is InputEventJoypadButton:
		return JOY.get(e.button_index, "")
	return ""

static func bind(action: String, keycode: int) -> void:
	var k: Dictionary = Game.settings.get("keys", {}).duplicate()
	# a key does one thing: whatever had it before goes back to its default (or loses it if that clashes too)
	for a in ACTIONS:
		if a[0] != action and code(a[0]) == keycode:
			k[a[0]] = int(a[2]) if int(a[2]) != keycode else 0
	k[action] = keycode
	Game.settings.keys = k
	Game.save_settings()

static func reset() -> void:
	Game.settings.keys = {}
	Game.save_settings()
