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
		{ "name": "dog-roll", "subject": dog["node"], "lead": 0.05, "setup": func() -> void: _near(dog); _hold(dog); (dog["quad"] as Node).call("act", "roll") },
		{ "name": "dog-hurt", "subject": dog["node"], "lead": 0.0, "setup": func() -> void: _near(dog); _hold(dog); town.animal_hit(dog, Vector3(0, 0, -1)) },
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
		{ "name": "player-sky", "subject": town.body, "lead": 0.0, "setup": func() -> void: town.body.position = Vector3(-3.5, 0.02, 16.5); town.resting = true; town.player.pose_request = "sky" },
		{ "name": "player-carry3", "subject": town.body, "lead": 0.3, "setup": func() -> void: town.body.position = Vector3(-3.5, 0.02, 15.0); town.resting = false; town.player.pose_request = ""; for k in ["apple", "cup", "bread"]: town.player.hold(town.make_item(k, Vector3.ZERO)) },
		{ "name": "player-swim", "subject": town.body, "lead": 0.0, "setup": func() -> void: town.body.position = Vector3(-5, 0.02, 11.5) },
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
	if subject == town.body: cam.position = s + Vector3(2.0, 1.6, 3.0)        # 사람은 크니 조금 멀리
	elif c.get("side", false): cam.position = s + Vector3(2.4, 0.9, 0.3)     # 옆에서(쓰다듬기 — 사람이 앞을 가린다)
	else: cam.position = s + Vector3(0.9, 1.1, 2.0)
	cam.look_at(s + Vector3(0, 0.3 if subject != town.body else 0.45, 0), Vector3.UP)
	var now := Time.get_ticks_msec() / 1000.0
	if now < next_frame: return
	next_frame += DT
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
