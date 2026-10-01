class_name TownSites
extends TownMeals
## 열린 세계의 장소(운영자 2026-10-01: "열린 세계에 실제 장소 — 숲 오두막, 호숫가 마을, Climb 탑 언덕 — 거기서 미니게임 입구로 이어지는 틀").
## 자리·땅 깎기는 WorldGen.SITES, 여기선 짓는다(_site_<name>). 마을과 같은 빌더·같은 자리(spots)라 주민이 일과로 걸어온다(멀면 게으른 사람은 덜 온다 — mind.score 거리항).
## 미니게임 입구(gate): 자리 kind "gate" + game id. 사람이 C 로 들어가면 res://scripts/games/<id>.gd 를 띄우고 마을은 멈춘 채 숨는다(상태는 그대로) — 끝나면(신호 finished)
## 나온 문 앞으로 돌아오고 기록이 표지판에 남는다(user://records.json). 레벨·XP 없이 마을에 보이는 흔적으로만(운영자 원칙)

const RECORDS := "user://records.json"
const TIMED := ["race"]   # 기록이 시간인 게임 — 낮을수록 좋고 초로 적는다(Climb 은 높이, 클수록 좋다)
var records := {}
var game_node: Node = null
var _signs: Array = []   # [{label, game}]

func _sites() -> void:
	var f := FileAccess.open(RECORDS, FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary: records = d
	for s in WorldGen.SITES:
		var c: Vector3 = s["c"]; var from: Vector3 = s["from"]
		var dir := Vector3(c.x - from.x, 0, c.z - from.z)
		_path(from, c - dir.normalized() * 6.0, 1.8)   # 큰길(또는 골목)에서 장소 앞까지 자갈길
		_district(s["name"], c, Callable(self, "_site_" + String(s["name"])))
		var rng := RandomNumberGenerator.new(); rng.seed = int(c.x * 7.0 + c.z * 3.0)
		for i in 40:   # 깎은 평지가 맨땅으로 보이지 않게 — 둘레에 풀·꽃·덤불(가운데 8m 는 비운다)
			var a := rng.randf() * TAU; var d := rng.randf_range(8.0, float(s["r"]) + 6.0)
			var id: String = ["Grass_Common_Short", "Grass_Wispy_Tall", "Flower_3_Group", "Flower_4_Group", "Clover_1", "Bush_Common", "Bush_Common_Flowers", "Fern_1"][i % 8]
			_scatter(id, c + Vector3(cos(a) * d, 0, sin(a) * d), rng.randf_range(0.35, 0.6) if id.begins_with("Bush") else rng.randf_range(0.6, 1.0))

# ── 숲 오두막(서쪽 150m): 통나무집, 모닥불(돌 둘레·장작·불꽃·따뜻한 빛), 통나무 벤치 둘, 장작더미, 도끼 꽂힌 그루터기, 등불, 둘레 나무 ──
func _site_cabin(c: Vector3) -> void:
	_house(c + Vector3(0, 0, -6), Vector3(4.4, 2.7, 3.6), Color("8a6a4a"), "wood", false, 31)
	var fire := c + Vector3(0, 0, 2.6)
	var stone := _mat(Color("9a8f86"))
	for i in 9:
		var a := i * TAU / 9.0
		var st := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.16; sm.height = 0.2; st.mesh = sm; st.material_override = stone
		st.position = fire + Vector3(cos(a) * 0.62, 0.06, sin(a) * 0.62); _add(st)
	var wood := _mat(Color("6b4a35"))
	for a in [0.4, -0.5, 1.6]:
		var lg := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.08; cm.height = 0.8; lg.mesh = cm; lg.material_override = wood
		lg.position = fire + Vector3(0, 0.12, 0); lg.rotation = Vector3(PI / 2.0, a, 0.25); _add(lg)
	var flame := CPUParticles3D.new(); flame.amount = 40; flame.lifetime = 0.7; flame.direction = Vector3.UP; flame.spread = 18.0
	flame.initial_velocity_min = 0.8; flame.initial_velocity_max = 1.6; flame.gravity = Vector3(0, 0.8, 0); flame.scale_amount_min = 0.6; flame.scale_amount_max = 1.4
	var fm := SphereMesh.new(); fm.radius = 0.09; fm.height = 0.18; fm.radial_segments = 6; fm.rings = 3; flame.mesh = fm
	var fmat := StandardMaterial3D.new(); fmat.albedo_color = Color(1.0, 0.55, 0.15); fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; flame.material_override = fmat
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; flame.emission_sphere_radius = 0.18
	flame.position = fire + Vector3(0, 0.2, 0); _add(flame)
	var glow := OmniLight3D.new(); glow.light_color = Color(1.0, 0.7, 0.4); glow.light_energy = 1.4; glow.omni_range = 7.0; glow.position = fire + Vector3(0, 0.8, 0); _add(glow)
	spots.append({ "pos": fire + Vector3(0, 0, 1.3), "kind": "bank", "yaw": PI })   # 불 앞에 서서 손을 쬔다
	_bench(c + Vector3(-1.6, 0, 0.7)); _bench(c + Vector3(1.6, 0, 0.7))   # 불을 보는 통나무 벤치
	for row in 3:   # 장작더미: 통나무 세 층, 위로 갈수록 적게
		for i in 4 - row:
			var lg := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.11; cm.bottom_radius = 0.11; cm.height = 1.1; lg.mesh = cm; lg.material_override = wood if (i + row) % 2 == 0 else _mat(Color("7a5640"))
			lg.position = c + Vector3(3.6, 0.11 + row * 0.2, -5.2 + i * 0.23 + row * 0.11); lg.rotation = Vector3(0, 0, PI / 2.0); _add(lg)
	var stump := MeshInstance3D.new(); var sc := CylinderMesh.new(); sc.top_radius = 0.28; sc.bottom_radius = 0.33; sc.height = 0.45; stump.mesh = sc; stump.material_override = _mat(Color("7a5640"))
	stump.position = c + Vector3(3.8, 0.22, -2.2); _add(stump)
	var axe := _box(Vector3(0.05, 0.6, 0.05), c + Vector3(3.8, 0.4, -2.2), _mat(Color("9a7650")), false); axe.rotation.z = 0.5
	_box(Vector3(0.22, 0.12, 0.04), c + Vector3(3.68, 0.44, -2.2), _mat(Color("5b5b63")), false).rotation.z = 0.5
	_lamp(c + Vector3(-3.0, 0, -3.0))
	for i in 6:
		var a := i * TAU / 6.0 + 0.3
		_tree(c + Vector3(cos(a) * 11.5, 0, sin(a) * 11.5), 1.1 + 0.1 * (i % 3))

# ── 호숫가 마을(동쪽 135m): 연못보다 큰 호수(물 애셋 — 헤엄·물보라 그대로), 나무 부두와 낚시 자리, 호수를 보는 집 셋, 물가 길과 벤치·가로등 ──
func _site_lakeside(c: Vector3) -> void:
	var lake := c + Vector3(-9, 0, 4)
	water.disc(lake, 8.0)
	var plank := _mat(Color("a07a52"))
	_box(Vector3(5.2, 0.12, 1.2), lake + Vector3(5.6, 0.05, 0), plank)   # 동쪽 물가에서 서쪽으로 뻗은 부두(윗면 0.17 — 턱 오르기 안)
	for i in 4: _box(Vector3(0.12, 0.5, 0.12), lake + Vector3(3.6 + i * 1.3, -0.3, 0.62 if i % 2 == 0 else -0.62), _mat(Color("6b4a35")), false)   # 말뚝
	spots.append({ "pos": lake + Vector3(3.5, 0.17, 0), "kind": "bank", "yaw": -PI / 2.0 })   # 부두 끝 — 서서 호수를 본다
	spots.append({ "pos": lake + Vector3(0, 0, 8.9), "kind": "bank", "yaw": PI })
	spots.append({ "pos": lake + Vector3(-8.9, 0, 0), "kind": "bank", "yaw": PI / 2.0 })
	_house(c + Vector3(-10, 0, -12), Vector3(4.2, 2.8, 3.4), Color("dfe6ea"), "wood", false, 32)
	_house(c + Vector3(-1, 0, -13), Vector3(4.6, 3.0, 3.6), Color("e6d3a5"), "shingle", false, 33)
	_house(c + Vector3(8, 0, -12), Vector3(3.8, 2.6, 3.2), Color("b5c9a8"), "brick", false, 34)
	_path(c + Vector3(-15, 0, -8), c + Vector3(13, 0, -8), 1.6)   # 집 앞 물가 길
	_bench(c + Vector3(-4, 0, -6.2)); _bench(c + Vector3(4.5, 0, -6.2))
	_lamp(c + Vector3(-6.5, 0, -6.8)); _lamp(c + Vector3(3.5, 0, -6.8)); _lamp(c + Vector3(12, 0, -6.8))
	for t in [Vector3(-17, 0, -3), Vector3(13, 0, 2), Vector3(15, 0, -14), Vector3(-15, 0, 10)]: _tree(c + t, 1.15)
	_garage(c + Vector3(11, 0, 11))

## 차고(레이싱 입구) — 호숫가 길 동쪽, 남쪽(오는 길)을 보는 문. 지붕 위 체크무늬 간판, 문 옆에 타이어 더미. 들어가면 race.gd(트랙은 미니게임 안)
func _garage(at: Vector3) -> void:
	_box(Vector3(4.6, 2.6, 4.0), at, _mat(Color("c9c2bb")))
	_box(Vector3(5.0, 0.2, 4.4), at + Vector3(0, 2.6, 0), _mat(Color("5b5560")), false)
	_box(Vector3(3.0, 2.0, 0.1), at + Vector3(0, 0, 2.0), _mat(Color("3a2f36")), false)   # 열린 셔터 안의 어둠
	for k in 8:   # 체크무늬 간판: 8×2 칸
		for r in 2: _box(Vector3(0.45, 0.3, 0.06), at + Vector3(-1.575 + k * 0.45, 2.85 + r * 0.3, 2.05), _mat(Color("1b0c15") if (k + r) % 2 == 0 else Color("efe9e2")), false)
	var tyre := _mat(Color("2f2a2e"))
	for i in 3:   # 타이어 셋 — 눕혀 쌓았다
		var ty := MeshInstance3D.new(); var tm := CylinderMesh.new(); tm.top_radius = 0.38; tm.bottom_radius = 0.38; tm.height = 0.24; ty.mesh = tm; ty.material_override = tyre
		ty.position = at + Vector3(-3.0, 0.12 + i * 0.25, 2.2); _add(ty)
	_gate(at + Vector3(0, 0, 3.2), PI, "race", "RACE")
	_path(at + Vector3(-11, 0, 3.6), at + Vector3(0, 0, 3.6), 1.6)   # 호숫가로 오는 자갈길에서 차고 문 앞까지

# ── Climb 탑 언덕(북쪽 골목 너머): 돌탑(꼭대기 깃발, 둘레를 감아 오르는 발판 장식), 문 앞의 입구 자리와 기록 표지판, 둘레 벤치·가로등·나무 ──
func _site_tower(c: Vector3) -> void:
	var stone := _mat(Color("bfb6b0")); var dark := _mat(Color("8a7f86"))
	var t := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 2.8; cm.bottom_radius = 3.2; cm.height = 14.0; cm.radial_segments = 24; t.mesh = cm; t.material_override = stone
	t.position = c + Vector3(0, 7.0, -2.0); _add(t)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 3.2; cy.height = 14.0; cs.shape = cy; sb.add_child(cs); t.add_child(sb)
	for i in 14:   # 감아 오르는 발판(장식) — 안에 들어가면 진짜로 오른다
		var a := -i * 0.85   # 미니게임 탑과 같은 방향(각이 줄어드는 쪽) — 밖에서 보면 오른쪽으로 오른다
		var p := _box(Vector3(1.0, 0.18, 0.7), c + Vector3(cos(a) * 3.5, 0.6 + i * 0.95, -2.0 + sin(a) * 3.5), dark, false); p.rotation.y = -a
	var flag_pole := _box(Vector3(0.08, 2.0, 0.08), c + Vector3(0, 14.0, -2.0), dark, false)
	var flag := _box(Vector3(0.9, 0.5, 0.03), c + Vector3(0.5, 15.4, -2.0), _mat(Color("ad7096")), false)
	flag_pole.set_meta("flag", flag)
	_box(Vector3(1.3, 2.1, 0.2), c + Vector3(0, 0, 1.15), _mat(Color("3a2f36")), false)   # 문(어두운 아치)
	_gate(c + Vector3(0, 0, 2.2), PI, "climb", "CLIMB")
	_path(c + Vector3(0, 0, 2.0), c + Vector3(0, 0, 8.0), 2.0)
	_bench(c + Vector3(-4.5, 0, 4.5)); _bench(c + Vector3(4.5, 0, 4.5))
	_lamp(c + Vector3(-2.2, 0, 3.0)); _lamp(c + Vector3(2.2, 0, 3.0))
	spots.append({ "pos": c + Vector3(-3.0, 0, 6.5), "kind": "lookout", "yaw": PI })   # 탑을 올려다본다
	for i in 5:
		var a := PI * 0.15 + i * PI * 0.25
		_tree(c + Vector3(cos(a) * 12.0, 0, -sin(a) * 12.0 - 2.0), 1.2)

## 입구 — 자리(kind gate)와 표지판(이름 + 내 기록). 사람이 C 로 들어간다(town_player). 주민은 문 앞에 서서 구경한다(같은 자리 — door 처럼 잠깐 선다)
func _gate(at: Vector3, yaw: float, game: String, title: String) -> void:
	spots.append({ "pos": at, "kind": "gate", "yaw": yaw, "game": game })
	var post := _box(Vector3(0.1, 1.5, 0.1), at + Vector3(1.4, 0, 0.3), _mat(Color("6b4a35")), false)
	var board := _box(Vector3(1.1, 0.6, 0.06), at + Vector3(1.4, 1.3, 0.3), _mat(Color("efe9e2")), false)
	var lb := Label3D.new(); lb.font_size = 64; lb.pixel_size = 0.004; lb.modulate = Color("1b0c15"); lb.outline_size = 0
	lb.position = at + Vector3(1.4, 1.62, 0.35); lb.billboard = BaseMaterial3D.BILLBOARD_DISABLED; _add(lb)
	_signs.append({ "label": lb, "game": game, "title": title })
	post.set_meta("board", board)
	_refresh_signs()

func _refresh_signs() -> void:
	for s in _signs:
		var best := float(records.get(String(s["game"]), 0.0))
		(s["label"] as Label3D).text = String(s["title"]) + ("\nbest " + _fmt(String(s["game"]), best) if best > 0.0 else "\nC to enter")

func _fmt(id: String, v: float) -> String:
	return "%.1f s" % v if id in TIMED else "%d m" % int(v)

## 들어가기 — 미니게임을 띄우고 마을은 그대로 멈춘다(숨김 + 처리 끔). 돌아오면 나온 자리에서 이어진다
func enter_game(id: String) -> void:
	if game_node != null or not ResourceLoader.exists("res://scripts/games/%s.gd" % id): return
	game_node = (load("res://scripts/games/%s.gd" % id) as GDScript).new()
	game_node.set("best", float(records.get(id, 0.0)))
	if "rivals" in game_node:   # 상대가 필요한 게임(Race) — 성미 급한 주민 둘이 나선다
		var hot := residents.duplicate(); hot.sort_custom(func(a: Resident, b: Resident) -> bool: return a.mind.temper > b.mind.temper)
		game_node.set("rivals", hot.slice(0, 2).map(func(r: Resident) -> Dictionary: return { "handle": r.handle, "color": r.fig.color }))
	game_node.connect("finished", _game_done.bind(id))
	get_tree().root.add_child(game_node)
	visible = false; process_mode = Node.PROCESS_MODE_DISABLED
	(get_node("UI") as CanvasLayer).visible = false

func _game_done(result: Dictionary, id: String) -> void:
	if game_node: game_node.queue_free()
	game_node = null
	visible = true; process_mode = Node.PROCESS_MODE_INHERIT
	(get_node("UI") as CanvasLayer).visible = true; cam.current = true
	var score := float(result.get("score", 0.0)); var old := float(records.get(id, 0.0))
	if score > 0.0 and ((old <= 0.0 or score < old) if id in TIMED else score > old):
		records[id] = score
		var f := FileAccess.open(RECORDS, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(records))
		say_toast("New best: " + _fmt(id, score))
	elif int(result.get("place", 0)) > 0: say_toast("Finished %s." % ["1st", "2nd", "3rd"][int(result["place"]) - 1])
	_refresh_signs()
