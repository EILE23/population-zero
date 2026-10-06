extends SceneTree
## Esc 메뉴(창 모드) — user://shots/menu-*.png, 키 바꾸기 확인
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await process_frame
	var m: GameMenu = town.menu
	m.open_menu(); for i in 10: await process_frame
	root.get_texture().get_image().save_png("user://shots/menu-main.png")
	print("MENU open=%s typing=%s" % [m.open, town.typing])
	m.open_menu("controls"); for i in 10: await process_frame
	root.get_texture().get_image().save_png("user://shots/menu-controls.png")
	m._wait_key("jump")
	var e := InputEventKey.new(); e.keycode = KEY_K; e.pressed = true; root.push_input(e)
	for i in 3: await process_frame
	print("REBIND jump -> %s" % GameMenu.key_of("jump"))
	m._reset_keys(); print("RESET jump -> %s" % GameMenu.key_of("jump"))
	m.open_menu("settings"); for i in 10: await process_frame
	root.get_texture().get_image().save_png("user://shots/menu-settings.png")
	m.close_menu(); print("CLOSED typing=%s" % town.typing)
	quit()
