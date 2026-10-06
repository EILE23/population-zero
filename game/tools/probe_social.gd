extends SceneTree
## 사람끼리 점검(헤드리스): 감정 표현(자세·방으로 가는 pose·움직이면 끊김), 채팅 입력 중 멈춤, 조작법 창, 말풍선, 밀림
func _key(k: Key) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.pressed = true; root.push_input(e)
	var u := InputEventKey.new(); u.keycode = k; u.pressed = false; root.push_input(u)

func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await physics_frame
	town._net_town()   # 점검 도구라 방엔 안 붙고 pos_source 만 선다
	for k in [KEY_2, KEY_4, KEY_3, KEY_1, KEY_5]:
		town._emote({ KEY_1: "wave", KEY_2: "cheer", KEY_3: "bow", KEY_4: "dance", KEY_5: "sky" }[k])
		for i in 20: await physics_frame
		var d: Dictionary = town.net.pos_source.call()
		print("EMOTE ", town.emote, " action=", town.player.action, " move=", town.player.move, " pose_req=", town.player.pose_request, " t=%.2f" % town.player.action_t, " sent pose=", d["pose"])
		town.emote_until = 0.0
		for i in 3: await physics_frame
		print("  ended: emote='", town.emote, "' action='", town.player.action, "' pose_req='", town.player.pose_request, "'")
	_key(KEY_ENTER); for i in 3: await physics_frame
	print("CHAT open typing=", town.typing)
	var p0: Vector3 = town.body.global_position
	Input.action_press("move_right"); for i in 20: await physics_frame
	Input.action_release("move_right")
	print("  moved while typing=%.2f" % (town.body.global_position - p0).length())
	_key(KEY_ESCAPE); for i in 20: await physics_frame
	print("CHAT closed typing=", town.typing)
	_key(KEY_H); for i in 2: await process_frame
	var kh: Node = town.get_node("UI").get_children().filter(func(n): return n is KeyHelp)[0]
	print("HELP visible=", kh.visible)
	ChatBox.bubble(town.body, "Good morning.", 1.75); town.chat.line("probe", "Good morning.")
	print("BUBBLE ", (town.body.get_node("bubble") as Label3D).text, " visible=", (town.body.get_node("bubble") as Label3D).visible)
	town.net.me = 7
	var v0: Vector3 = town.body.velocity
	town._on_room({ "t": "ev", "by": 3, "ev": { "k": "hitp", "who": 7, "dx": 1.0, "dy": 0.0 } })
	print("SHOVED dv=", town.body.velocity - v0, " action=", town.player.action)
	quit()
