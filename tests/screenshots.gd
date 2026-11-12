extends Node
## Saves screenshots of key screens to the folder given by --shots=<dir>
## (default user://shots). Needs a real window: run without --headless.

var main: Node
var out := "user://shots/"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="): out = a.substr(8) + "/"
	DirAccess.make_dir_recursive_absolute(out)
	Game.SAVE_DIR = "user://test_saves/"
	main = preload("res://scripts/main.gd").new()
	add_child(main)
	await frames(10)
	await shot("01_title")
	main.ui.flow = {"view": "mode"}; main.ui.render_title(); await shot("02_mode")
	main.ui.flow = {"view": "create", "mode": "survivor", "slot": 1, "look": Data.default_look.duplicate(true), "name": "Dana"}; main.ui.render_title(); await shot("03_create")
	Game.new_game({"mode": "survivor", "slot": 1, "name": "Dana", "look": Data.default_look.duplicate(true), "property_name": "Second Spring"})
	await shot("04_intro")
	main.ui.close_all()
	Game.state.time = 600
	Game.change_map("homestead", 12, 12, "down", {"silent": true})
	await shot("05_homestead")
	Game.change_map("town", 30, 16, "down", {"silent": true})
	Game.sync_npcs()
	await shot("06_town")
	Game.change_map("town", 7, 19, "down", {"silent": true}); await shot("06b_town_gate")
	Game.change_map("town", 22, 31, "up", {"silent": true}); await shot("06c_town_tavern")
	Game.change_map("town", 46, 10, "up", {"silent": true}); await shot("06d_ruin")
	Game.change_map("town", 30, 16, "down", {"silent": true})
	Game.state.time = 1260
	await shot("07_town_night")
	Game.state.time = 600
	Game.change_map("house", 6, 5, "down", {"silent": true})
	await shot("08_house")
	Game.change_map("mine", 0, 0, "down", {"floor": 2})
	Game.enemies.clear()
	var e1: Dictionary = main.world.spawn_enemy("shambler", 0, 0); e1.pos = Game.player.pos + Vector2(28, 0); e1.dir = "left"
	var e2: Dictionary = main.world.spawn_enemy("lurcher", 0, 0); e2.pos = Game.player.pos + Vector2(-26, 10); e2.dir = "down"
	await shot("09_mine")
	Game.enemies.clear()
	Game.change_map("mountain", 19, 20, "down", {"silent": true})
	await frames(60)
	await shot("10_mountain")
	Game.change_map("homestead", 12, 12, "down", {"silent": true})
	main.ui.open("journal", {"tab": "inventory"}); await shot("11_journal")
	main.ui.close_all()
	Game.talk_to("ruth"); await shot("12_dialogue")
	main.ui.close_all()
	main.ui.open("shop", {"shop": "general"}); await shot("13_shop")
	main.ui.close_all()
	main.ui.open("journal", {"tab": "map"}); await shot("14_map")
	main.ui.close_all()
	get_tree().quit()

func frames(n: int) -> void:
	for i in n:
		main.world.step(1.0 / 60.0)
		main.ui.update_hud(1.0 / 60.0)
		await get_tree().process_frame

func shot(name: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name + ".png")
