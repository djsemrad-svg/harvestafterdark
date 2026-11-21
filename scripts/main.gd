extends Node2D
## The main scene. Creates the world and the interface, hands them to the
## Game autoload, and routes input and the per-frame update.

var world: Node2D
var ui: CanvasLayer

func _ready() -> void:
	world = preload("res://scripts/world/world.gd").new()
	world.name = "World"
	add_child(world)
	ui = preload("res://scripts/ui/ui.gd").new()
	ui.name = "UI"
	add_child(ui)
	Game.world = world
	Game.ui = ui
	Game.apply_settings()
	ui.show_title()
	Sfx.play_music("spring")

## Settings: waiting for the key to bind to an action (Esc cancels).
func _input(e: InputEvent) -> void:
	if Keys.waiting == "" or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	get_viewport().set_input_as_handled()
	var pk: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
	if pk != KEY_ESCAPE:
		Keys.bind(Keys.waiting, pk)
	Keys.waiting = ""
	ui.refresh_settings()

func _unhandled_input(e: InputEvent) -> void:
	if Game.screen != "game":
		return
	if ui.overlay_open():
		if e is InputEventKey:
			ui.on_key(e)
			get_viewport().set_input_as_handled()
		elif e is InputEventJoypadButton and e.pressed and e.button_index in [JOY_BUTTON_B, JOY_BUTTON_START, JOY_BUTTON_BACK]:
			ui.close_all()      # a controller closes menus with B, Start or Back
			get_viewport().set_input_as_handled()
		return
	world.handle_event(e)

func _process(dt: float) -> void:
	dt = minf(dt, 0.1)   # avoid huge jumps after a hitch
	world.step(dt)
	ui.update_hud(dt)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if Game.screen == "game" and Game.settings.pause_on_blur and not ui.overlay_open():
			ui.open_pause()
