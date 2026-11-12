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

func _unhandled_input(e: InputEvent) -> void:
	if Game.screen != "game":
		return
	if ui.overlay_open():
		if e is InputEventKey:
			ui.on_key(e)
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
