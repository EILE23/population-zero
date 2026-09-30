extends Node
## 동작 시트 — `godot --path game res://scenes/town3d.tscn -- --sheet` 로 켜면(town3d.gd _ready 가 붙인다) 동작마다 0.1초 간격 12프레임을
## 한 장(4×3)에 이어 붙여 user://shots/sheet-<name>.png 로 저장하고 끝나면 종료한다. 운영자 2026-09-28: "png 로 보지 말고 이어서 보면서" —
## 영상 대신 연속 프레임으로 타이밍·연결을 본다. 게임 코드는 건드리지 않고 town 의 공개 상태만 조작한다(카메라는 대상에 붙인다).

const N := 12
const DT := 0.1
const W := 400
const H := 300

var town: Node3D
var clips: Array = []
var ci := -1
var frames: Array[Image] = []
var next_frame := -1.0
var subject: Node3D
var lead_until := 0.0

func _ready() -> void:
	town = get_parent()
	town.view_25d = false
	await get_tree().create_timer(1.0).timeout
	_define()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			var names: PackedStringArray = arg.substr(7).split(",")
			clips = clips.filter(func(c: Dictionary) -> bool: return c["name"] in names)
	_next()

func _animal(kind: String) -> Dictionary:
	for a in town.animals:
		if a["kind"] == kind: return a
	return {}

func _pos(a: Dictionary) -> Vector3:
	return (a["node"] as Node3D).global_position

## 플레이어를 대상에서 3.6m 떨어뜨려 둔다(개가 따라오지 않게) — 카메라는 대상에
func _near(a: Dictionary) -> void:
	town.body.position = _pos(a) + Vector3(0, 0.02, 3.6)

## 동물을 제자리에 오래 세운다(마을 습성이 상태를 덮어쓰지 않게)
func _hold(a: Dictionary, secs := 9.0) -> void:
	a["wander"] = _pos(a); a["wander_until"] = a["t"] + secs; a["idle_act"] = ""; a["follow_until"] = 0.0; a["flee_until"] = 0.0

func _define() -> void:
	var dog := _animal("dog"); var cat := _animal("cat"); var duck := _animal("duck"); var pigeon := _animal("pigeon")
	clips = [
		{ "name": "dog-walk", "subject": dog["node"], "setup": func() -> void: _near(dog); _hold(dog); dog["wander"] = _pos(dog) + Vector3(2.5, 0, 0) },
		{ "name": "dog-run", "subject": dog["node"], "setup": func() -> void: _near(dog); _hold(dog); dog["flee_until"] = dog["t"] + 4.0; dog["wander"] = _pos(dog) + Vector3(5, 0, 0) },
		{ "name": "dog-sit", "subject": dog["node"], "lead": 0.05, "setup": func() -> void: _near(dog); _hold(dog); (dog["quad"] as Node).call("act", "sit") },
		{ "name": "dog-lie", "subject": dog["node"], "lead": 0.05, "setup": func() -> void: _near(dog); _hold(dog); (dog["quad"] as Node).call("act", "lie") },
		{ "name": "dog-stretch", "subject": dog["node"], "lead": 0.05, "setup": func() -> void: _near(dog); _hold(dog); (dog["quad"] as Node).call("act", "stretch") },
		{ "name": "dog-bow", "subject": dog["node"], "lead": 0.05, "setup": func() -> void: _near(dog); _hold(dog); (dog["quad"] as Node).call("act", "bow") },
		{ "name": "dog-roll", "subject": dog["node"], "lead": 0.05, "dt": 0.28, "setup": func() -> void: _near(dog); _hold(dog); (dog["quad"] as Node).call("act", "roll") },
		{ "name": "dog-hurt", "subject": dog["node"], "lead": 0.0, "setup": func() -> void: _near(dog); _hold(dog); town.animal_hit(dog, Vector3(0, 0, -1)) },
		{ "name": "dog-affection", "subject": dog["node"], "lead": 0.3, "setup": func() -> void: _hold(dog); dog["sulk_until"] = 0.0; dog["follow_until"] = dog["t"] + 9.0; dog["aff_until"] = 0.0; town.body.position = _pos(dog) + Vector3(0, 0.02, 1.2) },
		{ "name": "dog-beg", "subject": dog["node"], "lead": 0.05, "setup": func() -> void: _near(dog); _hold(dog); (dog["quad"] as Node).call("act", "beg") },
		{ "name": "dog-pet", "subject": dog["node"], "lead": 0.1, "side": true, "setup": func() -> void: _hold(dog); dog["sulk_until"] = 0.0; town.body.position = _pos(dog) + Vector3(0, 0.02, 0.8); town._pet_dog(dog, Time.get_ticks_msec() / 1000.0) },
		{ "name": "dog-sniff", "subject": dog["node"], "lead": 0.05, "setup": func() -> void: _near(dog); _hold(dog); (dog["quad"] as Node).call("act", "sniff") },
		{ "name": "dog-scratch", "subject": dog["node"], "lead": 0.05, "setup": func() -> void: _near(dog); _hold(dog); (dog["quad"] as Node).call("act", "scratch") },
		{ "name": "dog-shake", "subject": dog["node"], "lead": 0.0, "setup": func() -> void: _near(dog); _hold(dog); (dog["quad"] as Node).call("act", "shake") },
		{ "name": "fox-walk", "subject": _animal("fox")["node"], "setup": func() -> void: var f := _animal("fox"); _near(f); _hold(f); f["wander"] = _pos(f) + Vector3(3.0, 0, 0); f["wander_until"] = f["t"] + 9.0 },
		{ "name": "marten-walk", "subject": _animal("marten")["node"], "setup": func() -> void: var f := _animal("marten"); _near(f); _hold(f); f["wander"] = _pos(f) + Vector3(2.0, 0, 0); f["wander_until"] = f["t"] + 9.0 },
		{ "name": "cat-idle", "subject": cat["node"], "setup": func() -> void: _near(cat); _hold(cat) },
		{ "name": "cat-walk", "subject": cat["node"], "setup": func() -> void: _near(cat); _hold(cat); cat["wander"] = _pos(cat) + Vector3(2.5, 0, 0) },
		{ "name": "cat-groom", "subject": cat["node"], "lead": 0.05, "setup": func() -> void: _near(cat); _hold(cat); (cat["quad"] as Node).call("act", "groom") },
		{ "name": "cat-arch", "subject": cat["node"], "lead": 0.05, "setup": func() -> void: _near(cat); _hold(cat); (cat["quad"] as Node).call("act", "arch") },
		{ "name": "duck-paddle", "subject": duck["node"], "setup": func() -> void: town.body.position = duck["center"] + Vector3(0, 0.02, 4.5) },
		{ "name": "pigeon-idle", "subject": pigeon["node"], "setup": func() -> void: town.body.position = _pos(pigeon) + Vector3(0, 0.02, 3.0) },
		{ "name": "car-drift", "subject": town.cars[0], "lead": 1.2, "dt": 0.25, "setup": func() -> void: var c: Car3D = town.cars[0]; town.body.position = c.global_position + Vector3(1.3, 0.02, 0); town._enter_car(c, Time.get_ticks_msec() / 1000.0); c.input = { "throttle": 1.0, "steer": 0.0, "brake": false }; c.v = 7.0; c.rotation.y = PI / 2.0; (func() -> void: await town.get_tree().create_timer(1.0).timeout; c.input = { "throttle": 1.0, "steer": 1.0, "brake": true }).call() },
		{ "name": "player-jump", "subject": town.body, "lead": 0.15, "dt": 0.08, "setup": func() -> void: town.body.position = Vector3(-3.5, 0.02, 15.0); town.resting = false; town.player.pose_request = ""; (func() -> void: await town.get_tree().create_timer(0.1).timeout; Input.action_press("jump"); await town.get_tree().create_timer(0.3).timeout; Input.action_release("jump")).call() },
		{ "name": "car-forward", "subject": town.cars[0], "lead": 0.3, "dt": 0.2, "setup": func() -> void: var c: Car3D = town.cars[0]; c.global_position = Vector3(19.5, 0.02, 7.5); c.rotation.y = PI / 2.0; town.body.position = c.global_position + Vector3(0, 0.02, 1.5); town._enter_car(c, Time.get_ticks_msec() / 1000.0); c.v = 0.0; c.input = { "throttle": 1.0, "steer": 0.0, "brake": false } },
		{ "name": "car-hitdog", "subject": dog["node"], "lead": 0.05, "dt": 0.12, "side": true, "setup": func() -> void: _hold(dog); var c: Car3D = town.cars[1]; var dp := _pos(dog); c.global_position = dp + Vector3(3.0, 0.02, 0); c.rotation.y = PI / 2.0; town.body.position = c.global_position + Vector3(0, 0.02, 1.5); town._enter_car(c, Time.get_ticks_msec() / 1000.0); c.v = 8.0; c.input = { "throttle": 1.0, "steer": 0.0, "brake": false } },
		{ "name": "car-crash", "subject": town.cars[2], "lead": 0.05, "dt": 0.12, "setup": func() -> void: var c: Car3D = town.cars[0]; var o: Car3D = town.cars[2]; o.global_position = Vector3(5, 0.02, 8.0); o.rotation.y = 0.0; c.global_position = o.global_position + Vector3(4.0, 0, 0); c.rotation.y = PI / 2.0; if town.driving: town.driving.driver = null; town.driving = null; town.body.position = c.global_position + Vector3(0, 0.02, 1.5); town._enter_car(c, Time.get_ticks_msec() / 1000.0); c.v = 9.0; c.input = { "throttle": 1.0, "steer": 0.0, "brake": false } },
		{ "name": "swing-top", "subject": town.body, "lead": 0.05, "dt": 0.15, "setup": func() -> void: if town.driving: town.driving.driver = null; town.driving = null; town.body.visible = true; town.body.collision_layer = 4; town.body.collision_mask = 7; var sw: Dictionary = town.swings[0]; sw["rider"] = null; town.riding = sw; sw["angle"] = 1.1; sw["vel"] = 0.0; (func() -> void: await town.get_tree().create_timer(0.05).timeout; Input.action_press("jump"); await town.get_tree().create_timer(0.1).timeout; Input.action_release("jump")).call() },
		{ "name": "car-push", "subject": town.cars[0], "lead": 0.2, "dt": 0.25, "setup": func() -> void: _free_car(); var c: Car3D = town.cars[0]; c.global_position = Vector3(-8, 0.02, 9.0); c.rotation.y = PI / 2.0; var r = town.residents[3]; r.state = "busy"; r.busy_until = Time.get_ticks_msec() / 1000.0 + 30.0; r.global_position = c.global_position + Vector3(-2.2, 0, 0); _enter(c); c.v = 1.2; c.input = { "throttle": 0.25, "steer": 0.0, "brake": false } },
		{ "name": "car-bench", "subject": town.cars[0], "lead": 0.05, "dt": 0.12, "setup": func() -> void: _free_car(); var c: Car3D = town.cars[0]; c.global_position = Vector3(0.5, 0.02, 4.2); c.rotation.y = PI / 2.0; _enter(c); c.v = 7.0; c.input = { "throttle": 1.0, "steer": 0.0, "brake": false } },
		{ "name": "car-runover", "subject": town.cars[0], "lead": 0.05, "dt": 0.1, "setup": func() -> void: _free_car(); var c: Car3D = town.cars[0]; c.global_position = Vector3(-8, 0.02, 9.0); c.rotation.y = PI / 2.0; var r = town.residents[3]; r.global_position = c.global_position + Vector3(-3.0, 0, 0); r.hit(Vector3(-1, 0, 0), c, true); r.velocity = Vector3.ZERO; r.down_until = Time.get_ticks_msec() / 1000.0 + 6.0; _enter(c); c.v = 3.0; c.input = { "throttle": 0.4, "steer": 0.0, "brake": false } },
		{ "name": "seesaw-launch", "subject": town.seesaws[0], "lead": 0.05, "dt": 0.12, "setup": func() -> void: _free_car(); var ss: Seesaw3D = town.seesaws[0]; var r = town.residents[5]; r.global_position = ss.seat_pos(1); r.spot = { "kind": "seesaw", "ss": ss }; r.state = "busy"; r.busy_until = Time.get_ticks_msec() / 1000.0 + 30.0; ss.riders = [null, null]; ss.sit(r, 1); r.riding_seesaw = ss; r.fig.seated = true; r.collision_layer = 0; r.collision_mask = 0; ss.angle = -Seesaw3D.LIMIT; ss.omega = 0.0; town.body.global_position = ss.global_position + Vector3(-Seesaw3D.L * 0.9, 3.2, 0); town.body.velocity = Vector3.ZERO; r.set_meta("ss_push_at", 1e12) },
		{ "name": "car-fence", "subject": town.cars[0], "lead": 0.05, "dt": 0.1, "setup": func() -> void: _free_car(); var c: Car3D = town.cars[0]; c.global_position = Vector3(-10, 0.02, 4.5); c.rotation.y = PI; _enter(c); c.v = 8.0; c.input = { "throttle": 1.0, "steer": 0.0, "brake": false } },
		{ "name": "car-lamp", "subject": town.cars[0], "lead": 0.05, "dt": 0.1, "setup": func() -> void: _free_car(); var c: Car3D = town.cars[0]; c.global_position = Vector3(-8, 0.02, 4.8); c.rotation.y = 0.0; _enter(c); c.v = 8.0; c.input = { "throttle": 1.0, "steer": 0.0, "brake": false } },
		{ "name": "car-hill", "subject": town.cars[0], "lead": 0.05, "dt": 0.18, "setup": func() -> void: _free_car(); var c: Car3D = town.cars[0]; c.global_position = Vector3(23.5, 0.02, 18.5); c.rotation.y = -PI / 2.0; _enter(c); c.v = 10.0; c.input = { "throttle": 1.0, "steer": 0.0, "brake": false } },
		{ "name": "car-reverse", "subject": town.cars[0], "lead": 0.05, "dt": 0.18, "setup": func() -> void: _free_car(); var c: Car3D = town.cars[0]; c.global_position = Vector3(10, 0.02, 1.4); c.rotation.y = -PI / 2.0; _enter(c); c.v = 0.0; c.input = { "throttle": -1.0, "steer": 0.0, "brake": false } },
		{ "name": "fight-punch", "subject": town.body, "lead": 0.05, "dt": 0.04, "side": true, "setup": func() -> void: _free_car(); town.body.position = Vector3(-3.5, 0.02, 15.0); town.player.face(PI / 2.0); town.player.rotation.y = PI / 2.0; town.player.action = "punch"; town.player.punch_side = 1.0; town.action_until = Time.get_ticks_msec() / 1000.0 + FightPoses.PUNCH_T },
		{ "name": "fight-round", "subject": town.body, "lead": 0.05, "dt": 0.055, "side": true, "setup": func() -> void: _free_car(); town.body.position = Vector3(-3.5, 0.02, 15.0); town.player.rotation.y = PI / 2.0; town.player.face(PI / 2.0); town.player.kick_step = 2; town.player.action = "kick"; town.action_until = Time.get_ticks_msec() / 1000.0 + FightPoses.ROUND_T },
		{ "name": "fight-kick", "subject": town.body, "lead": 0.05, "dt": 0.05, "side": true, "setup": func() -> void: _free_car(); town.body.position = Vector3(-3.5, 0.02, 15.0); town.player.face(PI / 2.0); town.player.rotation.y = PI / 2.0; town.player.action = "kick"; town.action_until = Time.get_ticks_msec() / 1000.0 + FightPoses.KICK_T },
		{ "name": "fight-knockdown", "subject": town.residents[3], "lead": 0.02, "dt": 0.25, "side": true, "setup": func() -> void: _free_car(); var r = town.residents[3]; r.global_position = Vector3(-3.5, 0.02, 15.0); r.state = "routine"; r.hit(Vector3(1, 0, 0), town.body, true) },
		{ "name": "player-sky", "subject": town.body, "lead": 0.0, "setup": func() -> void: town.body.position = Vector3(-3.5, 0.02, 16.5); town.resting = true; town.player.pose_request = "sky" },
		{ "name": "player-carry3", "subject": town.body, "lead": 0.3, "setup": func() -> void: town.body.position = Vector3(-3.5, 0.02, 15.0); town.resting = false; town.player.pose_request = ""; for k in ["apple", "cup", "bread"]: town.player.hold(town.make_item(k, Vector3.ZERO)) },
		{ "name": "player-swim", "subject": town.body, "lead": 0.3, "setup": func() -> void: _free_car(); town.body.position = Vector3(-5, 0.02, 11.5); town.body.velocity = Vector3.ZERO },
	]

func _next() -> void:
	ci += 1
	if ci >= clips.size():
		print("SHEET done"); get_tree().quit(); return
	var c: Dictionary = clips[ci]
	subject = c["subject"]
	frames = []
	(c["setup"] as Callable).call()
	var now := Time.get_ticks_msec() / 1000.0
	lead_until = now + maxf(0.12, float(c.get("lead", 0.6)))   # 최소 두 프레임 — 첫 장에 이전 장면이 남지 않게
	next_frame = lead_until

func _process(_delta: float) -> void:
	if ci < 0 or ci >= clips.size() or subject == null: return
	var cam: Camera3D = town.cam
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	var s := subject.global_position
	var c: Dictionary = clips[ci]
	if subject is Car3D or subject is Seesaw3D: cam.position = s + Vector3(4.5, 3.0, 5.5)
	elif subject == town.body: cam.position = s + Vector3(2.0, 1.6, 3.0)        # 사람은 크니 조금 멀리
	elif c.get("side", false): cam.position = s + Vector3(0.3, 1.0, 3.2)     # 옆에서(쓰다듬기 — 사람이 앞을 가린다)
	else: cam.position = s + Vector3(0.9, 1.1, 2.0)
	cam.look_at(s + Vector3(0, 0.3 if subject != town.body else 0.45, 0), Vector3.UP)
	var now := Time.get_ticks_msec() / 1000.0
	if now < next_frame: return
	next_frame += float(clips[ci].get("dt", DT))
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	frames.append(img)
	if frames.size() >= N:
		_save(clips[ci]["name"])
		_next()

func _save(name: String) -> void:
	var sheet := Image.create(W * 4, H * 3, false, Image.FORMAT_RGB8)
	for i in frames.size():
		var src: Image = frames[i]
		sheet.blit_rect(src, Rect2i((src.get_width() - W) / 2, (src.get_height() - H) / 2 - 20, W, H), Vector2i((i % 4) * W, (i / 4) * H))
	DirAccess.make_dir_recursive_absolute("user://shots")
	sheet.save_png("user://shots/sheet-%s.png" % name)
	print("SHEET ", name)

func _free_car() -> void:
	if town.driving: town.driving.driver = null; town.driving = null
	town.body.visible = true; town.body.collision_layer = 4; town.body.collision_mask = 7

func _enter(c: Car3D) -> void:
	town.body.position = c.global_position + Vector3(0, 0.02, 1.5); town._enter_car(c, Time.get_ticks_msec() / 1000.0)
