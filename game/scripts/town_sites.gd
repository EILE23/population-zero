class_name TownSites
extends TownWoods
## 열린 세계의 장소(운영자 2026-10-01: "열린 세계에 실제 장소 — 숲 오두막, 호숫가 마을, Climb 탑 언덕 — 거기서 미니게임 입구로 이어지는 틀").
## 자리·땅 깎기는 WorldGen.SITES, 여기선 짓는다(_site_<name>). 마을과 같은 빌더·같은 자리(spots)라 주민이 일과로 걸어온다(멀면 게으른 사람은 덜 온다 — mind.score 거리항).
## 미니게임 입구(gate): 자리 kind "gate" + game id. 사람이 C 로 들어가면 res://scripts/games/<id>.gd 를 띄우고 마을은 멈춘 채 숨는다(상태는 그대로) — 끝나면(신호 finished)
## 나온 문 앞으로 돌아오고 기록이 표지판에 남는다(user://records.json). 레벨·XP 없이 마을에 보이는 흔적으로만(운영자 원칙)

const RECORDS := "user://records.json"
const TIMED := ["race"]   # 기록이 시간인 게임 — 낮을수록 좋고 초로 적는다(Climb 은 높이, 클수록 좋다)
var records := {}
var game_node: Node = null
var _signs: Array = []   # [{label, game}]
const BITE_WIN := 1.2          # 찌가 두 번 잠기는 동안 — 이 안에 C 면 감아올려 물고기, 놓치면 "It got away." 하고 다음 입질을 기다린다
var fishers: Array = []        # 낚는 사람마다 {fig, who: 주민|null, rod, tip, line, bob, spot, to: 찌 자리, state: cast/wait/dip/reel, bite, caught, end}

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
	doors[doors.size() - 1]["job"] = "woodcutter"   # 오두막 주민이 나무꾼 — 낮엔 그루터기에서 패고 장작을 더미로 나른다(_woodcut)
	_woodyard(c)
	_lamp(c + Vector3(-3.0, 0, -3.0))
	for i in 6:
		var a := i * TAU / 6.0 + 0.3
		_tree(c + Vector3(cos(a) * 11.5, 0, sin(a) * 11.5), 1.1 + 0.1 * (i % 3))

# ── 부두 낚시(운영자 2026-10-01 "열린 세계의 장소에 할 일" — 호숫가 2조각, run 91): 빈손으로 부두 끝 C = 던지고(cast) 걸터앉아 찌를 본다. 4–12초 뒤 찌가 두 번 잠기고
## 그 1.2초 안에 C 면 감아올려(reel) 물고기 한 마리(FOOD, 세 입), 놓치면 "It got away." — 계속 앉아 있으면 다음 입질이 온다. 움직이면 거둔다.
## 시간 여유 있는 주민이 부두 끝 자리에 오면 셋에 하나는 같은 자세로 앉아 낚고(resident_life _fish_arrive), 낚으면 그 자리에서 먹는다. 낚싯대는 사람 것이 아니라 부두의 것 — 손엔 남지 않는다

## 던지기 — 낚싯대(두 마디, 끝 마디가 휜다)·줄·찌를 만들어 fig 의 오른손에 붙인다. 찌는 CAST_FLICK 에 손을 떠나 앞으로 4m 날아간다
func cast_line(fig: Stick3D, who: Node3D, sp: Dictionary, now: float) -> void:
	var rod := Node3D.new(); _add(rod)   # 원점 = 손잡이, −z 로 뻗는다(looking_at)
	var cork := _mat(Color("6b4a35")); var cane := _mat(Color("c9a77a"))
	_box(Vector3(0.03, 0.03, 0.9), Vector3(0, -0.015, -0.45), cane, false, rod)
	_box(Vector3(0.04, 0.04, 0.16), Vector3(0, -0.02, 0.0), cork, false, rod)
	var tip := Node3D.new(); tip.position = Vector3(0, 0, -0.9); rod.add_child(tip)
	_box(Vector3(0.016, 0.016, 0.7), Vector3(0, -0.008, -0.35), cane, false, tip)
	var line := MeshInstance3D.new(); var lm := BoxMesh.new(); lm.size = Vector3(0.006, 0.006, 1.0); line.mesh = lm; line.material_override = _mat(Color("efe9e2")); _add(line)
	var bob := MeshInstance3D.new(); var bm := SphereMesh.new(); bm.radius = 0.045; bm.height = 0.09; bob.mesh = bm; bob.material_override = _mat(Color("ff2d55")); _add(bob)
	_box(Vector3(0.012, 0.08, 0.012), Vector3(0, 0.02, 0), _mat(Color("efe9e2")), false, bob)   # 찌 꼭지 — 흰 막대
	var yaw: float = sp["yaw"]
	var to: Vector3 = sp["pos"] + Vector3(sin(yaw), 0, cos(yaw)) * 4.3; to.y = Water3D.SURFACE_Y + 0.02
	fig.pose_request = "cast"
	fishers.append({ "fig": fig, "who": who, "rod": rod, "tip": tip, "line": line, "bob": bob, "spot": sp, "to": to, "state": "cast", "bite": now + FishPoses.CAST_T + randf_range(4.0, 12.0), "caught": false, "end": 0.0 })

func _fisher(fig: Stick3D) -> Dictionary:
	for e in fishers:
		if e["fig"] == fig: return e
	return {}

## 사람이 부두 끝에서 빈손 C — 주민이 낚고 있거나 오는 중이면 자리는 그의 것. 아니면 끝으로 가 걸터앉아 던진다
func fish_use(sp: Dictionary, now: float) -> void:
	for r in sp.get("taken", []):
		if r != null: say_toast("Taken."); return
	var yaw: float = sp["yaw"]
	var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(body, "position", sp["pos"] + Vector3(sin(yaw), 0.02, cos(yaw)) * 0.3, 0.3)
	player.face(yaw); cast_line(player, null, sp, now)
	action_until = now + FishPoses.CAST_T

## 낚는 중의 C — 입질(dip) 중이면 감아 낚고, 아니면 빈 줄을 감아 거둔다. 낚는 중이 아니면 false(다른 C 로)
func fish_c(now: float) -> bool:
	var e := _fisher(player)
	if e.is_empty() or e["state"] == "reel": return not e.is_empty()
	if e["state"] == "cast": return true
	_reel(e, now, e["state"] == "dip")
	if not e["caught"]: say_toast("Nothing yet.")
	return true

func _reel(e: Dictionary, now: float, caught: bool) -> void:
	e["state"] = "reel"; e["caught"] = caught; e["end"] = now + FishPoses.REEL_T
	(e["fig"] as Stick3D).pose_request = "reel"
	if e["fig"] == player: action_until = now + FishPoses.REEL_T

## 매 프레임(town_systems _tick): 대는 오른손에서 rod_pitch 로 뻗고, 줄은 대 끝에서 찌까지. 찌는 날아가 물에 닿고(물결), 입질이면 두 번 잠긴다.
## 자세가 풀렸으면(움직였다, 맞았다, 주민이 떠났다) 대·줄·찌를 거둔다
func _fish(now: float) -> void:
	for e in fishers.duplicate():
		var fv: Variant = e["fig"]   # 타입을 박으면 지워진 노드를 넣을 때 멈춘다
		if not is_instance_valid(fv) or not ((fv as Stick3D).pose_request in ["cast", "reel"]):
			for k in ["rod", "line", "bob"]: (e[k] as Node3D).queue_free()
			fishers.erase(e); continue
		var fig: Stick3D = fv
		var fwd := Vector3(sin(fig.rotation.y), 0, cos(fig.rotation.y))
		var a := FishPoses.rod_pitch(fig)
		var dir := fwd * cos(a) + Vector3.UP * sin(a)
		var rod: Node3D = e["rod"]; var bob: Node3D = e["bob"]
		rod.global_transform = Transform3D(Basis.looking_at(dir, fwd.cross(Vector3.UP).cross(dir)), fig.hand_r.global_position)
		var tip_pos: Vector3 = (e["tip"] as Node3D).to_global(Vector3(0, 0, -0.7))
		var to: Vector3 = e["to"]
		match String(e["state"]):
			"cast":
				var fl := (fig.pose_t - FishPoses.CAST_FLICK) / 0.5   # 찌가 날아가는 0..1
				if fl < 0.0: bob.global_position = tip_pos
				elif fl < 1.0: bob.global_position = tip_pos.lerp(to, fl) + Vector3(0, sin(fl * PI) * 1.2, 0)
				else:
					e["state"] = "wait"; bob.global_position = to
					water._ring(to, 0.05, 0.5, 0.8, 0.6); water.splash(to, false)
			"wait":
				bob.global_position = to + Vector3(0, sin(now * 2.0) * 0.008, 0)
				if now >= e["bite"]: e["state"] = "dip"; water._ring(to, 0.04, 0.35, 0.6, 0.7)
			"dip":
				var d: float = now - float(e["bite"])
				bob.global_position = to - Vector3(0, 0.07 * maxf(0.0, sin(d / BITE_WIN * TAU * 2.0)), 0)   # 두 번 쑥 잠긴다
				var r: Node3D = e["who"]
				if r != null and d > 0.45: _reel(e, now, true)   # 주민은 두 번째 잠김 전에 챈다 — 사람과 같은 창 안
				elif d > BITE_WIN:
					e["state"] = "wait"; e["bite"] = now + randf_range(4.0, 12.0)
					if fig == player: say_toast("It got away.")
			"reel":
				var rk := clampf(1.0 - (float(e["end"]) - now) / FishPoses.REEL_T, 0.0, 1.0)
				bob.global_position = to.lerp(tip_pos, rk) + Vector3(0, sin(rk * PI) * 0.3, 0)
				(e["tip"] as Node3D).rotation.x = -0.5 * (1.0 - rk) if e["caught"] else 0.0   # 걸렸으면 끝 마디가 물 쪽으로 휜다
				if now >= float(e["end"]): _landed(e, now)
		var ln: MeshInstance3D = e["line"]
		var span := bob.global_position - tip_pos
		if span.length() > 0.01:
			var lb := Basis.looking_at(span, Vector3.UP if absf(span.normalized().y) < 0.99 else fwd); lb.z *= span.length()   # 길이 1 상자를 대 끝–찌 거리로 늘인다
			ln.global_transform = Transform3D(lb, tip_pos + span / 2.0)

## 다 감았다 — 걸렸으면 물고기를 손에. 사람은 그대로 서고, 주민은 그 자리에서 세 입에 먹는다(resident_base 의 한입 규칙)
func _landed(e: Dictionary, now: float) -> void:
	var fig: Stick3D = e["fig"]
	fig.pose_request = ""
	if not e["caught"]: return
	var fish := make_item("fish", Vector3.ZERO)
	if not fig.hold(fish): fish.queue_free(); return
	var r: Node3D = e["who"]
	if r == null:
		say_toast("A fish.")
		for x in residents:
			if x.state != "drive" and x.global_position.distance_to(body.global_position) < 8.0: x.say(x.mind.line("fish_watch"), 1.6); break
	else:
		r.call("_fish_caught", now)

# ── 호숫가 마을(동쪽 135m): 연못보다 큰 호수(물 애셋 — 헤엄·물보라 그대로), 나무 부두와 낚시 자리, 호수를 보는 집 셋, 물가 길과 벤치·가로등 ──
func _site_lakeside(c: Vector3) -> void:
	var lake := c + Vector3(-9, 0, 4)
	water.disc(lake, 8.0)
	var plank := _mat(Color("a07a52"))
	_box(Vector3(5.2, 0.12, 1.2), lake + Vector3(5.6, 0.05, 0), plank)   # 동쪽 물가에서 서쪽으로 뻗은 부두(윗면 0.17 — 턱 오르기 안)
	for i in 4: _box(Vector3(0.12, 0.5, 0.12), lake + Vector3(3.6 + i * 1.3, -0.3, 0.62 if i % 2 == 0 else -0.62), _mat(Color("6b4a35")), false)   # 말뚝
	spots.append({ "pos": lake + Vector3(3.5, 0.17, 0), "kind": "bank", "yaw": -PI / 2.0, "fish": true })   # 부두 끝 — 서서 호수를 보거나, 빈손이면 걸터앉아 낚시(_fish)
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
	_box(Vector3(3.0, 2.0, 0.1), at + Vector3(0, 0, 2.0), _mat(Color("3a2f36")), false)   # 셔터 안의 어둠
	for k in 8:   # 체크무늬 간판: 8×2 칸
		for r in 2: _box(Vector3(0.45, 0.3, 0.06), at + Vector3(-1.575 + k * 0.45, 2.85 + r * 0.3, 2.05), _mat(Color("1b0c15") if (k + r) % 2 == 0 else Color("efe9e2")), false)
	var tyre := _mat(Color("2f2a2e"))
	for i in 3:   # 타이어 셋 — 눕혀 쌓았다
		var ty := MeshInstance3D.new(); var tm := CylinderMesh.new(); tm.top_radius = 0.38; tm.bottom_radius = 0.38; tm.height = 0.24; ty.mesh = tm; ty.material_override = tyre
		ty.position = at + Vector3(-3.0, 0.12 + i * 0.25, 2.2); _add(ty)
	_gate(at + Vector3(0, 0, 3.2), PI, "race", "RACE", _gate_door(at + Vector3(0, 0, 2.1)))
	_path(at + Vector3(-11, 0, 3.6), at + Vector3(0, 0, 3.6), 1.6)   # 호숫가로 오는 자갈길에서 차고 문 앞까지

# ── Climb 탑 언덕(북쪽 골목 너머): 돌탑(꼭대기 깃발, 둘레를 감아 오르는 발판 장식), 문 앞의 입구 자리와 기록 표지판, 둘레 벤치·가로등·나무 ──
func _site_tower(c: Vector3) -> void:
	var stone := _mat(Color("bfb6b0")); var dark := _mat(Color("8a7f86"))
	var t := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 2.8; cm.bottom_radius = 3.2; cm.height = 14.0; cm.radial_segments = 24; t.mesh = cm; t.material_override = stone
	t.position = c + Vector3(0, 7.0, -2.0); _add(t)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 3.2; cy.height = 14.0; cs.shape = cy; sb.add_child(cs); t.add_child(sb)
	for i in 6:   # 창 — 탑 안에 세상이 있다(운영자 2026-10-06: 바깥을 오르는 게 아니라 안의 세상) — 바깥 발판 장식은 뺐다, 창마다 따뜻한 빛
		var a := i * 1.05 + 0.3; var wy := 3.0 + i * 1.8
		var wn := _box(Vector3(0.5, 0.9, 0.08), c + Vector3(cos(a) * 3.05, wy, -2.0 + sin(a) * 3.05), _mat(Color("f2c84b")), false); wn.rotation.y = -a + PI / 2.0
	var flag_pole := _box(Vector3(0.08, 2.0, 0.08), c + Vector3(0, 14.0, -2.0), dark, false)
	var flag := _box(Vector3(0.9, 0.5, 0.03), c + Vector3(0.5, 15.4, -2.0), _mat(Color("ad7096")), false)
	flag_pole.set_meta("flag", flag)
	_box(Vector3(1.3, 2.1, 0.2), c + Vector3(0, 0, 1.1), _mat(Color("3a2f36")), false)   # 문틀 안의 어둠
	_gate(c + Vector3(0, 0, 2.2), PI, "climb", "CLIMB", _gate_door(c + Vector3(0, 0, 1.25)))
	_path(c + Vector3(0, 0, 2.0), c + Vector3(0, 0, 8.0), 2.0)
	_bench(c + Vector3(-4.5, 0, 4.5)); _bench(c + Vector3(4.5, 0, 4.5))
	_lamp(c + Vector3(-2.2, 0, 3.0)); _lamp(c + Vector3(2.2, 0, 3.0))
	spots.append({ "pos": c + Vector3(-3.0, 0, 6.5), "kind": "lookout", "yaw": PI })   # 탑을 올려다본다
	for i in 5:
		var a := PI * 0.15 + i * PI * 0.25
		_tree(c + Vector3(cos(a) * 12.0, 0, -sin(a) * 12.0 - 2.0), 1.2)

## 입구 — 자리(kind gate)와 표지판(이름 + 내 기록). 사람이 C 로 들어간다(town_player). 주민은 문 앞에 서서 구경한다(같은 자리 — door 처럼 잠깐 선다)
func _gate(at: Vector3, yaw: float, game: String, title: String, door: Node3D = null) -> void:
	spots.append({ "pos": at, "kind": "gate", "yaw": yaw, "game": game, "door": door })
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
		var extra := ""
		if String(s["game"]) == "climb" and float(records.get("climb_time", 0.0)) > 0.0:   # 꼭대기까지 간 적이 있으면 최고 시간과 별
			extra = "\ntop in %d:%04.1f · stars %d" % [int(records["climb_time"]) / 60, fmod(float(records["climb_time"]), 60.0), int(records.get("climb_stars", 0))]
		(s["label"] as Label3D).text = String(s["title"]) + ("\nbest " + _fmt(String(s["game"]), best) if best > 0.0 else "\nC to enter") + extra

func _fmt(id: String, v: float) -> String:
	return "%.1f s" % v if id in TIMED else "%d m" % int(v)

## 들어가기 — 미니게임을 띄우고 마을은 그대로 멈춘다(숨김 + 처리 끔). 돌아오면 나온 자리에서 이어진다
func enter_game(id: String) -> void:
	if game_node != null or gating or not ResourceLoader.exists("res://scripts/games/%s.gd" % id): return
	var sp: Dictionary = {}
	for s in spots:
		if s["kind"] == "gate" and s["game"] == id: sp = s
	gating = true
	# 문 장면(운영자 2026-10-06: "들어갔다 나갈 때 문 열고 나가는 애니메이션"): 문 쪽을 보고, 문이 열리고, 걸어 들어가며 화면이 어두워진다
	var yaw: float = sp.get("yaw", PI); var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var door: Node3D = sp.get("door")
	var into: Vector3 = (door.global_position if door else body.global_position + fwd * 1.2) + fwd * 0.4; into.y = body.global_position.y
	player.face(yaw); player.move_dir = fwd; player.speed = 1.4
	if door: get_tree().create_tween().tween_property(door.get_node("leaf"), "rotation:y", -1.6, 0.3)
	var tw := get_tree().create_tween()
	tw.tween_property(body, "global_position", into, 0.9)
	tw.parallel().tween_property(_fader(), "color:a", 1.0, 0.45).set_delay(0.45)
	tw.tween_callback(func() -> void: _start_game(id))

## 화면 어둡게 하기 — 마을이 숨어도 남도록 뿌리(root)에 둔다
var _fade_rect: ColorRect
func _fader() -> ColorRect:
	if _fade_rect == null or not is_instance_valid(_fade_rect):
		var cl := CanvasLayer.new(); cl.layer = 50; get_tree().root.add_child(cl)
		_fade_rect = ColorRect.new(); _fade_rect.color = Color(0, 0, 0, 0); _fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT); _fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(_fade_rect)
	return _fade_rect

func _start_game(id: String) -> void:
	player.move_dir = Vector3.ZERO; player.speed = 0.0
	_fader().color.a = 0.0
	game_node = (load("res://scripts/games/%s.gd" % id) as GDScript).new()
	if "start_camp" in game_node: game_node.set("start_camp", int(records.get("climb_camp", 0)))
	if "gear" in game_node: game_node.set("gear", String(records.get("climb_gear", ""))); game_node.set("taken", records.get("climb_axes", []))   # 내 손도끼, 이미 가져간 자리들   # Climb: 지난번 나간 쉼터에서
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
	if result.has("camp"): records["climb_camp"] = int(result["camp"])   # 쉼터 문으로 나갔으면 다음엔 거기서
	if String(result.get("gear", "")) != "" and String(records.get("climb_gear", "")) == "":   # 손도끼를 얻었다 — 내 것, 그 자리는 다음에도 비어 있다
		records["climb_gear"] = result["gear"]; var ax: Array = records.get("climb_axes", []); ax.append(result["gear"]); records["climb_axes"] = ax
		var fg := FileAccess.open(RECORDS, FileAccess.WRITE)
		if fg: fg.store_string(JSON.stringify(records))
	_walk_out(id)
	var score := float(result.get("score", 0.0)); var old := float(records.get(id, 0.0))
	if score > 0.0 and ((old <= 0.0 or score < old) if id in TIMED else score > old):
		records[id] = score
		var f := FileAccess.open(RECORDS, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(records))
		say_toast("New best: " + _fmt(id, score))
	elif int(result.get("place", 0)) > 0: say_toast("Finished %s." % ["1st", "2nd", "3rd"][int(result["place"]) - 1])
	if id == "climb" and bool(result.get("top", false)):   # Climb: 꼭대기까지의 최고 시간(짧을수록)과 별 수(많을수록)도 따로 남긴다
		var t := float(result.get("time", 0.0)); var bt := float(records.get("climb_time", 0.0))
		if bt <= 0.0 or t < bt: records["climb_time"] = t; say_toast("Fastest climb: %d:%04.1f" % [int(t) / 60, fmod(t, 60.0)])
		records["climb_stars"] = maxi(int(records.get("climb_stars", 0)), int(result.get("stars", 0)))
		var f2 := FileAccess.open(RECORDS, FileAccess.WRITE)
		if f2: f2.store_string(JSON.stringify(records))
	_refresh_signs()

## 나오는 문 장면 — 어두운 데서 밝아지며 문이 열리고 문 앞으로 걸어 나온 뒤 문이 닫힌다. 그동안 조작은 잠긴다(gating)
func _walk_out(id: String) -> void:
	var sp: Dictionary = {}
	for s in spots:
		if s["kind"] == "gate" and s["game"] == id: sp = s
	if sp.is_empty(): gating = false; return
	var yaw: float = sp.get("yaw", PI); var back := -Vector3(sin(yaw), 0, cos(yaw))
	var door: Node3D = sp.get("door")
	var from: Vector3 = (door.global_position if door else sp["pos"]) - back * 0.4; from.y = body.global_position.y
	var to: Vector3 = sp["pos"] + back * 0.6; to.y = body.global_position.y
	body.global_position = from; body.velocity = Vector3.ZERO
	player.face(atan2(back.x, back.z)); player.move_dir = back; player.speed = 1.4
	_fader().color.a = 1.0
	var tw := get_tree().create_tween()
	tw.tween_property(_fader(), "color:a", 0.0, 0.4)
	if door: tw.parallel().tween_property(door.get_node("leaf"), "rotation:y", -1.6, 0.3)
	tw.tween_property(body, "global_position", to, 0.9)
	if door: tw.tween_property(door.get_node("leaf"), "rotation:y", 0.0, 0.35)
	tw.tween_callback(func() -> void: player.move_dir = Vector3.ZERO; player.speed = 0.0; gating = false)

## 경첩 문 — 문틀 앞의 나무 문짝(leaf). 열면 바깥쪽으로 돈다
func _gate_door(at: Vector3) -> Node3D:
	var d := Node3D.new(); d.position = at; _add(d)
	var hinge := Node3D.new(); hinge.name = "leaf"; hinge.position = Vector3(-0.55, 0, 0); d.add_child(hinge)
	var leaf := _box(Vector3(1.1, 2.0, 0.08), Vector3(0.55, 0, 0), _mat(Color("8a6a4a")), false, hinge)
	_box(Vector3(0.08, 0.08, 0.06), Vector3(0.95, 1.0, 0.06), _mat(Color("e3c46a")), false, hinge)   # 손잡이
	leaf.name = "plank"
	return d
