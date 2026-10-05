class_name TownNap
extends TownSunroom
## 낮잠방("Elders and children" 6조각, run 108, 구조 — 눈에 보이는 공사 사슬): 이야기방 동쪽 벽에 기대어 짓는 홑지붕 방 하나.
## 처음엔 말뚝 넷과 줄, 널빤지 더미, "Nap corner. Building." 팻말뿐이다. 아침 8시를 넘길 때마다 한 단계 — 기둥과 들보(1) → 홑지붕과 바닥(2) → 벽·문·안의 간이침대 둘과 흔들의자(3).
## 지나는 주민이 공사를 한마디 한다(mind.line "building"). 단계는 user://town.json 에 남아 다음 판에도 이어진다 — 사흘에 걸쳐 방이 생긴다(한 판 안에서도 아침이 오면 한 단계).
## 다 지어지면 13–14시 아이들이 간이침대에 눕고(rest, 침대와 같은 자세) 주인이 흔들의자에서 흔들며 콧노래(rock, stick3d_nap.gd; 의자도 같은 박자로 기운다).
## 사람도 같은 자리에서 C — 흔들의자에 앉으면 같은 rock 이고 10m 안의 가장 가까운 아이가 와서 눕는다; 간이침대에 누울 수도 있다. 사람이 문을 열면 잠든 아이 하나가 깬다(rub: 윗몸을 일으켜 눈을 비빈다);
## 들어오는 주민은 발소리를 죽인다(그 문을 향해 걷는 이가 있으면 깨우지 않는다) — 대신 간이침대에 누운 사람이 그때 같은 rub 로 깬다. 사슬: … → sunroom → **nap** → coins → player → town3d

const NAP_FROM := 13.0
const NAP_TO := 14.0
const NAP_SAVE := "user://town.json"
const NAP_W := 2.6   # x 폭 — 이야기방 동쪽 벽(x −17.2)에서 바깥으로
const NAP_D := 3.0   # z 깊이 — 뒷벽은 이야기방 뒷벽(z −18.4)과 한 줄, 앞은 이야기방 앞(−14.8)보다 0.6 뒤
var nap: Dictionary = {}   # {node, at(바닥 중심), stage 0..3, pile, parts(컷어웨이), sign, cots, rocker, chair(흔들의자 피벗), door, call(불려 오는 아이)}
var _nap_h := -1.0        # 지난 프레임의 시각(0..24) — 8시를 넘는 순간 한 단계
var _nap_said := 0.0
var _nap_call := -1.0     # 다음에 아이를 부를 수 있는 시각
var _nap_open := false    # 지난 프레임 문이 열려 있었나

## 공사장(_sunroom 이 call 로 부른다 — 이야기방 구역 노드 아래에 짓는다, 같이 켜고 꺼진다): 말뚝·줄·널빤지 더미·팻말. 저장된 단계가 있으면 그만큼 바로 짓는다
func _nap_site(at: Vector3) -> void:
	var c := at + Vector3(2.3 + NAP_W / 2.0, 0, -0.3)
	var nn: Node3D = _build_parent
	nap = { "node": nn, "at": c, "stage": 0, "pile": [], "parts": [], "cots": [], "rocker": {}, "door": {} }
	var wood := _mat(Color("8a6a4a")); var hw := NAP_W / 2.0; var hd := NAP_D / 2.0
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]: _box(Vector3(0.05, 0.5, 0.05), c + Vector3(sx * (hw - 0.05), 0, sz * (hd - 0.05)), wood, false, nn)
	var string := _mat(Color("efe9e2"))
	for sz: float in [-1.0, 1.0]: _box(Vector3(NAP_W, 0.012, 0.012), c + Vector3(0, 0.42, sz * (hd - 0.05)), string, false, nn)
	_box(Vector3(0.012, 0.012, NAP_D), c + Vector3(hw - 0.05, 0.42, 0), string, false, nn)
	for i in 3:   # 널빤지 더미 — 바깥(동쪽) 땅에, 단계마다 한 장씩 쓰여 사라진다
		(nap["pile"] as Array).append(_box(Vector3(1.6, 0.06, 0.25), c + Vector3(hw + 0.7 + 0.03 * i, 0.06 * i, 0.2 - 0.08 * i), wood, false, nn))
	_box(Vector3(0.05, 1.0, 0.05), c + Vector3(0.6, 0, hd + 0.3), wood, false, nn)
	var sign := Label3D.new(); sign.text = "Nap corner. Building."; sign.font_size = 14; sign.pixel_size = 0.004; sign.modulate = Color("1b0c15")
	sign.position = c + Vector3(0.6, 1.1, hd + 0.32); nn.add_child(sign); nap["sign"] = sign
	_nap_h = fmod(clock * 24.0 + 6.0, 24.0)
	var want := 0
	if FileAccess.file_exists(NAP_SAVE):
		var f := FileAccess.open(NAP_SAVE, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary: want = int((d as Dictionary).get("nap_stage", 0))
	for i in want: _nap_stage()

## 다음 단계 — 1 기둥과 들보(집 쪽이 높아 지붕이 바깥으로 흘러내린다) · 2 홑지붕과 널빤지 바닥 · 3 벽·문·안. 쓰인 널빤지는 더미에서 사라지고 팻말이 바뀐다
func _nap_stage() -> void:
	var st := int(nap["stage"]) + 1
	if st > 3: return
	nap["stage"] = st
	var nn: Node3D = nap["node"]; var c: Vector3 = nap["at"]
	var wood := _mat(Color("8a6a4a")); var hw := NAP_W / 2.0; var hd := NAP_D / 2.0
	((nap["pile"] as Array)[3 - st] as Node3D).visible = false
	var sign: Label3D = nap["sign"]
	match st:
		1:
			for sx: float in [-1.0, 1.0]:
				var h := 2.3 if sx < 0.0 else 1.9
				for sz: float in [-1.0, 1.0]: _box(Vector3(0.12, h, 0.12), c + Vector3(sx * (hw - 0.06), 0, sz * (hd - 0.06)), wood, true, nn)
				_box(Vector3(0.1, 0.1, NAP_D), c + Vector3(sx * (hw - 0.06), h, 0), wood, false, nn)
			sign.text = "Nap corner. Posts up."
		2:
			var rm := _mat(Color.WHITE, _tex("faces/roof-shingle"), Vector3(2.4, 1.8, 1)); rm.uv1_triplanar = true
			var roof := _box(Vector3(NAP_W + 0.5, 0.08, NAP_D + 0.4), c + Vector3(0.1, 2.1, 0), rm, true, nn)
			roof.rotation.z = -atan(0.4 / NAP_W)   # 집 쪽(−x)이 0.4 높다
			(nap["parts"] as Array).append(roof)
			var fl := _mat(Color.WHITE, _tex("faces/wall-plank"), Vector3(2.0, 2.4, 1)); fl.uv1_triplanar = true
			_box(Vector3(NAP_W - 0.2, 0.03, NAP_D - 0.2), c, fl, false, nn)
			sign.text = "Nap corner. Roof on."
		3:
			_nap_walls(c, nn); _nap_inside(c, nn, wood)
			sign.text = "Nap corner. Quiet, please."
	var f := FileAccess.open(NAP_SAVE, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({ "nap_stage": st }))

## 벽 셋(바깥·뒤·앞 두 토막)과 문 — 앞벽·문 위 가로대·문틀은 컷어웨이 대상. houses 에 올려 안에 들면 지붕이 열리고(_cutaway) 주민이 문으로 나온다(_exit_house)
func _nap_walls(c: Vector3, nn: Node3D) -> void:
	var hw := NAP_W / 2.0; var hd := NAP_D / 2.0
	var wm := _mat(Color.WHITE, _tex("faces/wall-plank"), Vector3(2.8, 2.8, 1)); wm.uv1_triplanar = true
	_box(Vector3(WALL, 1.9, NAP_D), c + Vector3(hw - WALL / 2.0, 0, 0), wm, true, nn)
	_box(Vector3(NAP_W, 2.2, WALL), c + Vector3(0, 0, -hd + WALL / 2.0), wm, true, nn)
	var seg := (NAP_W - 0.9) / 2.0; var parts: Array = nap["parts"]
	parts.append(_box(Vector3(seg, 2.2, WALL), c + Vector3(-hw + seg / 2.0, 0, hd - WALL / 2.0), wm, true, nn))
	parts.append(_box(Vector3(seg, 1.95, WALL), c + Vector3(hw - seg / 2.0, 0, hd - WALL / 2.0), wm, true, nn))
	parts.append(_box(Vector3(0.92, 0.2, WALL), c + Vector3(0, 1.88, hd - WALL / 2.0), wm, true, nn))
	var trim := _mat(Color("efe9e2"))
	for sx: float in [-1.0, 1.0]: parts.append(_box(Vector3(0.08, 1.88, WALL + 0.04), c + Vector3(sx * 0.49, 0, hd - WALL / 2.0), trim, true, nn))
	var hinge := Node3D.new(); hinge.position = c + Vector3(-0.45, 0, hd - WALL / 2.0); nn.add_child(hinge)
	var leaf := _box(Vector3(0.9, 1.86, 0.07), Vector3(0.45, 0, 0), _mat(Color("7b526c")), true, hinge)
	var knob := MeshInstance3D.new(); var ks := SphereMesh.new(); ks.radius = 0.03; ks.height = 0.06; knob.mesh = ks
	knob.material_override = _mat(Color("e8c766")); knob.position = Vector3(0.34, 0.0, 0.06); leaf.add_child(knob)
	var dr := { "hinge": hinge, "open": false, "pos": hinge.position + Vector3(0.45, 0, 0), "hw": hw, "hd": hd }
	doors.append(dr); nap["door"] = dr
	_box(Vector3(1.1, 0.1, 0.4), c + Vector3(0, 0, hd + 0.2), _mat(Color("cfc7c2")), true, nn)   # 문 앞 돌판 — 턱 오르기로 넘는다
	houses.append({ "min": c + Vector3(-hw, 0, -hd), "max": c + Vector3(hw, 2.3, hd), "parts": parts, "inside": false, "shell": [], "behind": false, "chim": null, "door": dr })

## 안: 바깥 벽을 따라 낮은 간이침대 둘(머리는 뒷벽 쪽), 집 쪽 벽 앞에 흔들의자(간이침대를 본다). 문에서 들어오는 길(x −15.9)은 비운다
func _nap_inside(c: Vector3, nn: Node3D, wood: Material) -> void:
	var hw := NAP_W / 2.0; var hd := NAP_D / 2.0
	var cots: Array = []
	for i in 2:
		var cp := c + Vector3(hw - 0.5, 0, -hd + 0.85 + i * 1.35)
		_box(Vector3(0.6, 0.16, 1.2), cp, wood, true, nn)
		_box(Vector3(0.54, 0.07, 1.12), cp + Vector3(0, 0.16, 0), _mat([Color("dfe6ea"), Color("e6d3a5")][i]), false, nn)
		_box(Vector3(0.4, 0.06, 0.22), cp + Vector3(0, 0.23, -0.4), _mat(Color("f7f4ef")), false, nn)   # 베개
		var sp := { "pos": cp + Vector3(0, 0.23, 0.08), "kind": "cot", "yaw": 0.0, "door": nap["door"] }
		spots.append(sp); cots.append(sp)
	nap["cots"] = cots
	# 흔들의자: 활 모양 발판 둘 위에 다리·좌석(윗면 0.41 — 앉은 골반 0.42 가 그 위)·등받이·팔걸이. 피벗은 발판 바닥, +x 를 보게 돌려 두고 _nap_tick 이 x 로 기울인다
	var rp := c + Vector3(-hw + 0.55, 0, -0.3)
	var piv := Node3D.new(); piv.position = rp; piv.rotation.y = PI / 2.0; nn.add_child(piv)
	var cloth := _mat(Color("b56a5a"))
	for sx: float in [-0.26, 0.26]:
		_box(Vector3(0.05, 0.05, 0.8), Vector3(sx, 0.0, 0), wood, false, piv)
		for sz: float in [-0.2, 0.2]: _box(Vector3(0.05, 0.3, 0.05), Vector3(sx * 0.85, 0.05, sz), wood, false, piv)
	_box(Vector3(0.56, 0.06, 0.56), Vector3(0, 0.35, 0), cloth, false, piv)
	_box(Vector3(0.5, 0.7, 0.06), Vector3(0, 0.41, -0.27), wood, false, piv)
	for sx: float in [-0.28, 0.28]: _box(Vector3(0.05, 0.22, 0.5), Vector3(sx, 0.41, 0), wood, false, piv)
	nap["chair"] = piv
	var rk := { "pos": rp, "kind": "rocker", "yaw": PI / 2.0, "door": nap["door"] }
	spots.append(rk); nap["rocker"] = rk

## 지금 낮잠 시간인가(0..24 시계)
func nap_time() -> bool:
	var h := fmod(clock * 24.0 + 6.0, 24.0)
	return h >= NAP_FROM and h < NAP_TO

## 매 프레임(town_systems _tick): 아침 8시의 한 단계, 공사 구경 한마디, 흔들의자의 기울기, 콧노래, 사람이 흔들면 아이 부르기, 문이 열리면 깨우기
func _nap_tick(now: float) -> void:
	if nap.is_empty(): return
	var h := fmod(clock * 24.0 + 6.0, 24.0)
	if int(nap["stage"]) < 3 and _nap_h < 8.0 and h >= 8.0 and h < 12.0: _nap_stage()   # 자정에 h 가 0 으로 돌아오니 다음 8시에 또 한 단계
	_nap_h = h
	if int(nap["stage"]) < 3:
		if now - _nap_said < 0.5: return
		_nap_said = now
		for r in residents:
			if r.state != "walk" or int(r.get_meta("built_said", -1)) == int(nap["stage"]) or r.global_position.distance_to(nap["at"]) > 6.0: continue
			r.set_meta("built_said", int(nap["stage"]))   # 단계마다 한 사람 한 번 — 다섯에 둘만 말한다, 나머지는 그냥 지나간다
			if randf() < 0.4: r.say(r.mind.line("building"), 1.8)
		return
	var rk: Dictionary = nap["rocker"]; var piv: Node3D = nap["chair"]
	var me_on: bool = not seat.is_empty() and seat["pos"] == rk["pos"]
	var sitter: ResidentBase = null
	for r in residents:
		if r.state == "busy" and is_same(r.spot, rk) and r.fig.pose_request == "rock": sitter = r
	piv.rotation.x = -NapPoses.ROCK_A * NapPoses.rock_phase() if (me_on or sitter != null) else lerpf(piv.rotation.x, 0.0, 0.08)   # 몸과 같은 시계(stick3d_nap) — 비면 멎는다
	if not me_on and player.pose_request == "rock": player.pose_request = ""   # 방향키로 일어섰다
	if sitter and now - float(sitter.fig.get_meta("hum_at", -99.0)) > 7.0: sitter.fig.set_meta("hum_at", now); sitter.say(sitter.mind.line("hum"), 2.0)
	if me_on and now > _nap_call: _nap_call_kid(now)
	var dr: Dictionary = nap["door"]
	if bool(dr["open"]) and not _nap_open:
		var tiptoe := false
		for r in residents:
			if r.state == "walk" and is_same(r.door_ref, dr): tiptoe = true
		if not tiptoe: _nap_wake(now)
		elif resting and player.pose_request == "rest" and _on_cot():
			player.pose_request = "rub"; use_until = now + NapPoses.RUB_T; resting = false   # 주민이 들어오는 문소리에 누운 사람이 깬다 — 아이와 같은 자세
	_nap_open = bool(dr["open"])

func _on_cot() -> bool:
	for c: Dictionary in nap["cots"]:
		if Vector2(body.global_position.x - (c["pos"] as Vector3).x, body.global_position.z - (c["pos"] as Vector3).z).length() < 0.35: return true
	return false

## 사람이 흔들의자에 앉아 있다 — 10m 안에서 가장 가까운, 간이침대에 없는 아이가 하던 걸 접고 빈 간이침대로 온다(resident_sunroom _nap_pick 이 "call" 을 읽는다). 20초에 한 번
func _nap_call_kid(now: float) -> void:
	_nap_call = now + 20.0
	var best: ResidentBase = null; var bd := 10.0
	for r in residents:
		if r.job != "child" or r.state in ["down", "getup", "drive", "chase"] or r.in_boat or r.spot.get("kind", "") == "cot": continue
		var d: float = r.global_position.distance_to(nap["at"])
		if d < bd: bd = d; best = r
	if best == null: return
	var free := false
	for c: Dictionary in nap["cots"]:
		if best._free_slot(c) >= 0: free = true
	if not free: return
	nap["call"] = best
	best.call("_leave")
	if best.state == "routine": best.busy_until = now
	best.say(best.mind.line("nap_call"), 1.6)

## 문이 열렸다(사람이) — 3초 넘게 누운 아이 하나가 윗몸을 일으켜 눈을 비비고(rub) 나간다; 흔들던 이가 "Shh."
func _nap_wake(now: float) -> void:
	for r in residents:
		if r.state != "busy" or r.spot.get("kind", "") != "cot" or r.fig.pose_request != "rest" or now - float(r.fig.get_meta("nap_at", now)) < 3.0: continue
		r.fig.pose_request = "rub"; r.busy_until = now + NapPoses.RUB_T + 0.3; r.say(r.mind.line("woken"), 1.6)
		for s in residents:
			if s.state == "busy" and s.fig.pose_request == "rock": s.say(s.mind.line("shh"), 1.6)
		return

## 사람이 간이침대·흔들의자 앞에서 C(town_player) — 간이침대엔 침대처럼 눕고(rest), 흔들의자엔 앉아 같은 rock. 누가 있으면 그 자리는 그 사람 것. 방향키로 일어난다
func nap_use(sp: Dictionary, now: float) -> void:
	for r in sp.get("taken", []):
		if r != null: return
	body.velocity = Vector3.ZERO; player.move_dir = Vector3.ZERO; player.speed = 0.0; player.face(sp["yaw"])
	var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(body, "position", (sp["pos"] as Vector3) + Vector3(0, 0.02, 0), 0.35)
	if sp["kind"] == "cot":
		resting = true; player.pose_request = "rest"; return
	seat = { "pos": sp["pos"], "yaw": sp["yaw"], "chair": true }
	player.seated = true; player.pose_request = "rock"; _nap_call = now + 1.0
	if not has_meta("rock_told"): set_meta("rock_told", true); say_toast("Rock. The small ones settle.")
