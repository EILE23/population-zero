class_name TownTrades
extends TownBoat
## 거리의 장인들("Trades on the street", 마을이 설계한 열세 번째 시스템 — run 80 이 첫 조각): 작은 작업대에서 짧게 손일을 해 주는 사람과, 제 물건이 닳으면 알아서 찾아오는 주민.
## 첫 장인은 구두장이 — 동쪽 광장 서쪽 끝의 낮은 작업대(구두골·구두 셋·걸린 간판)와 그 옆 걸상. 동쪽 집(24호) 문에 "cobbler" 가 적혀 그 집 주민이 낮(09–17)에 여기서 망치질한다.
## 닳음은 진짜 걸음이다: 주민도 사람도 걸은 만큼 `walked` 가 쌓이고, 350m 를 넘은 주민은 구두장이가 일하는 중이면 걸상에 앉아 한 바퀴 두 번 고쳐 받는다("Better.").
## 사람: 구두장이가 일하는 중에 C = 걸상에 앉아 같은 수선(끝나면 "Resoled.", 내 걸음이 0), 아무도 없을 때 작업대에서 C = 망치질 한 바퀴(구두장이가 근처면 "Careful with the last.").
## 둘째 장인은 칼갈이(run 81) — 시장 동쪽 끝, 넷째 노점 옆의 발판 숫돌(틀·돌 원판·발판·물통·간판). 카페(12호) 문에 "cutler" 가 적혀 그 집 주민이 낮에 여기서 간다.
## 무딤도 진짜 일이다: 가게지기(keeper)는 창구·노점 교대를 마칠 때마다 `dull` 이 하나 쌓이고, 넷이 되면 칼갈이가 가는 중일 때만 건너편 손님 자리에 팔짱 끼고 서서(wait) 두 바퀴 기다린다("Sharp.").
## 사람: 칼갈이가 가는 중에 C = 손님 자리에 서서 같은 두 바퀴(끝나면 "Sharp."), 아무도 없을 때 숫돌에서 C = 갈기 한 바퀴(불꽃은 유지 구간에만; 칼갈이가 근처면 "Mind your fingers.").
## 셋째 장인은 재봉사(run 82) — 동쪽 광장 동쪽 끝, 구두장이 맞은편의 바느질 탁자(마네킹·모브 천 두루마리·실패·간판). 동쪽 집(23호) 문에 "tailor" 가 적혀 그 집 주민이 낮에 여기서 꿰맨다.
## 찢어짐도 진짜 일이다: 넘어지면(주민도 사람도) 등에 멘 가방·목도리가 찢어지고(Wear.tear, 헝겊 조각이 보인다), 찢어진 주민은 재봉사가 일하는 중이면 다섯 중 셋은 손님 걸상에 앉아 한 바퀴 받는다(Wear.mend, "There.").
## 사람: 찢어진 걸 메고 C = 걸상에 앉아 같은 한 바퀴, 멀쩡하면 재봉사가 없을 때 탁자에 앉아 마네킹 옷에 바느질 한 바퀴(재봉사가 근처면 "Mind the pins.").
## 상속 사슬: base → build → places → boat → **trades** → critters → systems → combat → ride → player → town3d.

const SOLE_M := 350.0   # 이만큼 걸으면 밑창이 닳았다 — 주민 걸음(1.6m/s)으로 몇 분이면 차니 하루에 몇 명은 들른다
var cobbler: Dictionary = {}   # {work: 구두장이 자리, stool: 손님 걸상 자리}
var walked := 0.0              # 사람이 걸은 거리(m) — 걸상에서 고치면 0
var resole_at := -1.0          # 사람이 걸상에 앉아 고쳐 받는 중이면 끝나는 시각
var _sole_told := false        # "밑창이 얇다"는 한 번만
const DULL_N := 4              # 창구·노점 교대 넷이면 가위가 무디다 — 가게지기 하나가 하루에 한두 번 숫돌에 들른다
var wheel: Dictionary = {}     # {work: 칼갈이 자리, whet: 손님 자리, disc: 돌 원판, treadle: 발판, spark: 불꽃, spin: 지금 도는 속도}
var sharp_at := -1.0           # 사람이 손님 자리에서 기다리는 중이면 끝나는 시각
var tailor: Dictionary = {}    # {work: 재봉사 자리, fitting: 손님 걸상}
var mend_at := -1.0            # 사람이 걸상에 앉아 꿰매 받는 중이면 끝나는 시각

## 작업대 — 낮은 탁자, 왼쪽 끝의 쇠 구두골(구두 모양 머리), 탁자 위 구두 셋(잉크·종이·모브, 조금씩 틀어져), 뒤의 기둥에 걸린 간판. 서쪽이 구두장이, 동쪽이 걸상
func _cobbler(at: Vector3) -> void:
	var wood := _mat(Color("8a6a4a")); var iron := _mat(Color("4a4a52"))
	_box(Vector3(1.1, 0.08, 0.55), at + Vector3(0, 0.62, 0), wood)
	for sx: float in [-0.48, 0.48]:
		for sz: float in [-0.22, 0.22]: _box(Vector3(0.06, 0.62, 0.06), at + Vector3(sx, 0, sz), wood, false)
	_box(Vector3(0.05, 0.22, 0.05), at + Vector3(-0.32, 0.7, 0.05), iron, false)   # 구두골: 기둥 위에 뒤집힌 발
	_box(Vector3(0.1, 0.07, 0.24), at + Vector3(-0.32, 0.92, 0.07), iron, false)
	for i in 3:
		var sh := _box(Vector3(0.1, 0.07, 0.22), at + Vector3(0.05 + i * 0.16, 0.7, -0.08 + (i % 2) * 0.05), _mat([Color("1b0c15"), Color("efe9e2"), Color("ad7096")][i]), false)
		sh.rotation.y = 0.2 * (i - 1) + 0.07
	_box(Vector3(0.35, 0.03, 0.22), at + Vector3(-0.05, 0.7, 0.15), iron, false)   # 뉘어 둔 망치 — 자루와 머리
	_box(Vector3(0.06, 1.9, 0.06), at + Vector3(0.5, 0, -0.35), iron, false)
	_box(Vector3(0.5, 0.04, 0.04), at + Vector3(0.3, 1.85, -0.35), iron, false)
	_box(Vector3(0.42, 0.26, 0.03), at + Vector3(0.3, 1.52, -0.35), _mat(Color("efe9e2")), false)
	var sign := Label3D.new(); sign.text = "Cobbler"; sign.font_size = 22; sign.pixel_size = 0.004; sign.modulate = Color("1b0c15")
	sign.position = at + Vector3(0.3, 1.65, -0.33); _add(sign)
	var st := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.17; cm.bottom_radius = 0.17; cm.height = 0.06; st.mesh = cm
	st.material_override = wood; st.position = at + Vector3(0.85, 0.4, 0.05); _add(st)
	_box(Vector3(0.06, 0.38, 0.06), at + Vector3(0.85, 0, 0.05), iron, false)
	var work := { "pos": at + Vector3(-0.75, 0, 0.05), "kind": "cobbler", "yaw": PI / 2.0 }
	var stool := { "pos": at + Vector3(0.85, 0, 0.05), "kind": "stool", "yaw": -PI / 2.0 }
	spots.append(work); spots.append(stool)
	cobbler = { "work": work, "stool": stool }

## 숫돌(run 81, "Trades on the street" 2조각) — 나무 틀(다리 넷, 위 가로대 둘), z 축으로 꿴 쇠 축에 돌 원판(도는 게 보이게 테두리에 모브 쐐기 하나), 원판 밑의 물통(물이 찰랑이는 윗면),
## 칼갈이 발치의 발판(밟을 때마다 기운다), 닿는 점의 불꽃(갈 때만 켠다), 뒤 가로대의 "Cutler" 판. 서쪽이 칼갈이(동쪽을 본다, 원판이 앞), 동쪽 건너편이 손님 자리
func _grindstone(at: Vector3) -> void:
	var wood := _mat(Color("8a6a4a")); var iron := _mat(Color("4a4a52"))
	for sz: float in [-0.3, 0.3]:
		_box(Vector3(0.7, 0.06, 0.06), at + Vector3(0, 0.72, sz), wood, false)
		for sx: float in [-0.32, 0.32]: _box(Vector3(0.06, 0.72, 0.06), at + Vector3(sx, 0, sz), wood, false)
	_box(Vector3(0.36, 0.14, 0.26), at + Vector3(0, 0.02, 0), iron)                                      # 물통 — 원판 아랫자락이 잠긴다
	_box(Vector3(0.32, 0.01, 0.22), at + Vector3(0, 0.15, 0), _mat(Color("8fb8cc")), false)
	_box(Vector3(0.05, 0.05, 0.8), at + Vector3(0, 0.755, 0), iron, false)                                # 축
	var disc := Node3D.new(); disc.position = at + Vector3(0, 0.78, 0); _add(disc)
	var dm := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.34; cm.bottom_radius = 0.34; cm.height = 0.09; cm.radial_segments = 20
	dm.mesh = cm; dm.material_override = _mat(Color("9a948c")); dm.rotation.x = PI / 2.0; disc.add_child(dm)
	_box(Vector3(0.05, 0.05, 0.1), Vector3(0, 0.28, 0), _mat(Color("ad7096")), false, disc)             # 테두리 쐐기 — 돌면 보인다
	var tr := _box(Vector3(0.44, 0.04, 0.22), at + Vector3(-0.55, 0.05, 0), wood, false)                 # 발판 — 칼갈이 오른발 밑
	_box(Vector3(0.04, 0.05, 0.04), at + Vector3(-0.35, 0, 0), iron, false)
	var sp := CPUParticles3D.new(); sp.amount = 18; sp.lifetime = 0.3; sp.emitting = false; sp.local_coords = false
	sp.direction = Vector3(-1, 0.5, 0); sp.spread = 28.0; sp.initial_velocity_min = 1.4; sp.initial_velocity_max = 2.4; sp.gravity = Vector3(0, -6, 0)
	sp.mesh = SphereMesh.new(); (sp.mesh as SphereMesh).radius = 0.014; (sp.mesh as SphereMesh).height = 0.028
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color("ffb347"); sm.emission_enabled = true; sm.emission = Color("ff8a2a"); sm.emission_energy_multiplier = 2.0
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; sp.material_override = sm
	sp.position = at + Vector3(-0.3, 0.95, 0); _add(sp)
	_box(Vector3(0.5, 0.22, 0.03), at + Vector3(0, 0.82, -0.4), _mat(Color("efe9e2")), false)
	var sign := Label3D.new(); sign.text = "Cutler"; sign.font_size = 20; sign.pixel_size = 0.004; sign.modulate = Color("1b0c15")
	sign.position = at + Vector3(0, 0.93, -0.38); _add(sign)
	var work := { "pos": at + Vector3(-0.9, 0, 0), "kind": "wheel", "yaw": PI / 2.0 }
	var whet := { "pos": at + Vector3(0.95, 0, 0), "kind": "whet", "yaw": -PI / 2.0 }
	spots.append(work); spots.append(whet)
	wheel = { "work": work, "whet": whet, "disc": disc, "treadle": tr, "spark": sp, "spin": 0.0 }

## 바느질 탁자(run 82, "Trades on the street" 3조각) — 낮은 탁자 위에 모브 천 두루마리(누운 원기둥)·실패·가위, 탁자 뒤(북쪽)에 마네킹(기둥 + 종이색 몸통 + 모브 헝겊 한 장),
## 양 끝에 걸상 — 동쪽이 재봉사(서쪽을 본다, 광장 쪽), 서쪽이 손님. 구두장이 작업대의 거울상이라 광장 양쪽이 한 쌍으로 읽힌다
func _stitchhouse(at: Vector3) -> void:
	var wood := _mat(Color("8a6a4a")); var iron := _mat(Color("4a4a52")); var paper := _mat(Color("efe9e2"))
	_box(Vector3(1.0, 0.08, 0.55), at + Vector3(0, 0.62, 0), wood)
	for sx: float in [-0.43, 0.43]:
		for sz: float in [-0.22, 0.22]: _box(Vector3(0.06, 0.62, 0.06), at + Vector3(sx, 0, sz), wood, false)
	var bolt := MeshInstance3D.new(); var bm := CylinderMesh.new(); bm.top_radius = 0.07; bm.bottom_radius = 0.07; bm.height = 0.46
	bolt.mesh = bm; bolt.material_override = _mat(Color("ad7096")); bolt.rotation.z = PI / 2.0; bolt.position = at + Vector3(-0.15, 0.77, -0.14); _add(bolt)
	_box(Vector3(0.44, 0.012, 0.2), at + Vector3(-0.1, 0.7, 0.04), _mat(Color("ad7096")), false)   # 두루마리에서 풀려 나온 천
	var spool := MeshInstance3D.new(); var sm := CylinderMesh.new(); sm.top_radius = 0.03; sm.bottom_radius = 0.03; sm.height = 0.06
	spool.mesh = sm; spool.material_override = _mat(Color("1b0c15")); spool.position = at + Vector3(0.22, 0.73, 0.12); _add(spool)
	for i in 2:   # 벌린 가위 — 두 날
		var bl := _box(Vector3(0.14, 0.01, 0.02), at + Vector3(0.28, 0.7, -0.08), iron, false); bl.rotation.y = 0.3 - i * 0.6
	_box(Vector3(0.04, 1.0, 0.04), at + Vector3(0.05, 0, -0.62), iron, false)                                   # 마네킹 기둥과 다리 셋
	for a: float in [0.0, 2.1, 4.2]:
		var leg := _box(Vector3(0.24, 0.03, 0.03), at + Vector3(0.05 + cos(a) * 0.1, 0, -0.62 + sin(a) * 0.1), iron, false); leg.rotation.y = -a
	var torso := MeshInstance3D.new(); var tm := CapsuleMesh.new(); tm.radius = 0.16; tm.height = 0.55
	torso.mesh = tm; torso.material_override = paper; torso.position = at + Vector3(0.05, 1.27, -0.62); torso.scale = Vector3(1.0, 1.0, 0.7); _add(torso)
	_box(Vector3(0.2, 0.22, 0.02), at + Vector3(0.1, 1.24, -0.5), _mat(Color("ad7096")), false)                  # 마네킹에 핀으로 꽂은 헝겊
	_box(Vector3(0.06, 1.9, 0.06), at + Vector3(-0.5, 0, -0.35), iron, false)
	_box(Vector3(0.5, 0.04, 0.04), at + Vector3(-0.3, 1.85, -0.35), iron, false)
	_box(Vector3(0.42, 0.26, 0.03), at + Vector3(-0.3, 1.52, -0.35), paper, false)
	var sign := Label3D.new(); sign.text = "Tailor"; sign.font_size = 22; sign.pixel_size = 0.004; sign.modulate = Color("1b0c15")
	sign.position = at + Vector3(-0.3, 1.65, -0.33); _add(sign)
	for sx: float in [-0.8, 0.8]:
		var st := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.17; cm.bottom_radius = 0.17; cm.height = 0.06; st.mesh = cm
		st.material_override = wood; st.position = at + Vector3(sx, 0.4, 0.05); _add(st)
		_box(Vector3(0.06, 0.38, 0.06), at + Vector3(sx, 0, 0.05), iron, false)
	var work := { "pos": at + Vector3(0.8, 0, 0.05), "kind": "stitch", "yaw": -PI / 2.0 }
	var fit := { "pos": at + Vector3(-0.8, 0, 0.05), "kind": "fitting", "yaw": PI / 2.0 }
	spots.append(work); spots.append(fit)
	tailor = { "work": work, "fitting": fit }

## 지금 탁자에서 꿰매는 재봉사(주민) — 없으면 null. 손님은 이 사람이 있을 때만 온다
func tailor_at_work() -> ResidentBase:
	if tailor.is_empty(): return null
	for r in (tailor["work"] as Dictionary).get("taken", []):
		if r is ResidentBase and (r as ResidentBase).state == "busy" and (r as ResidentBase).fig.pose_request == "sew": return r
	return null

## 사람이 탁자나 걸상 앞에서 C(town_player) — 찢어진 걸 메고 있고 재봉사가 일하면 걸상에 앉아 꿰매 받고, 재봉사가 없으면 탁자에 앉아 바느질 한 바퀴(마네킹 옷에)
func stitch_use(sp: Dictionary, now: float) -> void:
	var w := tailor_at_work()
	var claimed := false   # 재봉사가 오는 중이면 탁자는 그의 것
	for r in (tailor["work"] as Dictionary).get("taken", []):
		if r != null: claimed = true
	var at: Dictionary = tailor["fitting"] if (w != null or claimed or sp["kind"] == "fitting") else tailor["work"]
	for r in at.get("taken", []):
		if r != null: return   # 누가 앉아 있다
	var fitting: bool = at["kind"] == "fitting"
	if fitting and w != null and not Wear.torn(player.worn.get("back")):
		w.say(w.mind.line("tailor_none"), 1.6); return
	seat = { "pos": at["pos"], "yaw": at["yaw"], "chair": true }
	player.seated = true; player.move_dir = Vector3.ZERO; player.speed = 0.0; body.velocity = Vector3.ZERO
	var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(body, "position", at["pos"] + Vector3(0, 0.05, 0), 0.3)
	player.face(at["yaw"])
	if not fitting:
		player.pose_request = "sew"; use_until = now + StickPoses.SEW_T
		for r in residents:
			if r.job == "tailor" and r.state != "drive" and r.global_position.distance_to(body.global_position) < 12.0:
				r.say("Mind the pins.", 1.8); break
	elif w != null:
		mend_at = now + StickPoses.SEW_T
		w.say(w.mind.line("tailor_serve"), 1.6)

## 지금 숫돌에서 가는 칼갈이(주민) — 없으면 null. 손님은 이 사람이 있을 때만 온다
func cutler_at_work() -> ResidentBase:
	if wheel.is_empty(): return null
	for r in (wheel["work"] as Dictionary).get("taken", []):
		if r is ResidentBase and (r as ResidentBase).state == "busy" and (r as ResidentBase).fig.pose_request == "grind": return r
	return null

## 사람이 숫돌이나 손님 자리 앞에서 C(town_player) — 칼갈이가 가는 중이면 손님 자리에 팔짱 끼고 서서 두 바퀴 기다리고, 아니면 숫돌에서 갈기 한 바퀴(손님 자리 앞이면 그냥 기다린다)
func wheel_use(sp: Dictionary, now: float) -> void:
	var w := cutler_at_work()
	var whet: Dictionary = wheel["whet"]
	var claimed := false   # 칼갈이가 오는 중이면 숫돌은 그의 것 — 손님 자리에서 기다린다
	for r in (wheel["work"] as Dictionary).get("taken", []):
		if r != null: claimed = true
	if w != null or claimed or sp["kind"] == "whet":
		for r in whet.get("taken", []):
			if r != null: return   # 손님이 서 있다
		var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
		tw.tween_property(body, "position", whet["pos"] + Vector3(0, 0.02, 0), 0.3)   # 손님 자리로 옮겨 선다 — 전엔 누른 자리(칼갈이 자리일 수도)에서 기다려 몸이 겹쳤다
		player.face(whet["yaw"]); player.pose_request = "wait"
		use_until = now + (StickPoses.GRIND_T * 2.0 if w != null else StickPoses.WAIT_T * 2.0)
		if w != null:
			sharp_at = use_until
			w.say(w.mind.line("cutler_serve"), 1.6)
		return
	player.face(sp["yaw"])
	player.pose_request = "grind"; use_until = now + StickPoses.GRIND_T; action_until = now + StickPoses.GRIND_T
	for r in residents:
		if r.job == "cutler" and r.state != "drive" and r.global_position.distance_to(body.global_position) < 12.0:
			r.say("Mind your fingers.", 1.8); break

## 매 프레임: 누가 갈고 있으면(칼갈이 주민이든 숫돌 앞의 사람이든) 원판이 돌고 발판이 오르내리고, 유지 구간엔 불꽃. 아무도 없으면 원판이 서서히 선다. 사람이 손님 자리에서 두 바퀴를 채우면 "Sharp."
func _wheel(delta: float, now: float) -> void:
	if wheel.is_empty(): return
	var w := cutler_at_work()
	var g: Stick3D = null
	if w != null: g = w.fig
	elif player.pose_request == "grind": g = player
	var k := 0.0; var pump := 0.0
	if g != null: k = StickPoses.grind_k(g.pose_t); pump = StickPoses.grind_pump(g)
	var spin := move_toward(float(wheel["spin"]), 7.0 * k, delta * 6.0)
	wheel["spin"] = spin
	(wheel["disc"] as Node3D).rotate(Vector3.BACK, spin * delta)
	(wheel["treadle"] as Node3D).rotation.z = -0.2 * pump * k
	(wheel["spark"] as CPUParticles3D).emitting = k > 0.95
	if sharp_at < 0.0 or now < sharp_at: return
	sharp_at = -1.0
	if w != null and player.pose_request == "wait": w.say("Sharp.", 1.6)

## 지금 작업대에서 망치질하는 구두장이(주민) — 없으면 null. 손님은 이 사람이 있을 때만 온다
func cobbler_at_work() -> ResidentBase:
	if cobbler.is_empty(): return null
	var w: Dictionary = cobbler["work"]
	for r in w.get("taken", []):
		if r is ResidentBase and (r as ResidentBase).state == "busy" and (r as ResidentBase).fig.pose_request == "hammer": return r
	return null

## 사람이 작업대나 걸상 앞에서 C(town_player) — 구두장이가 일하면 걸상에 앉아 고쳐 받고, 아니면 작업대에서 망치질 한 바퀴(걸상 앞이면 그냥 앉는다)
func cobbler_use(sp: Dictionary, now: float) -> void:
	var w := cobbler_at_work()
	var stool: Dictionary = cobbler["stool"]
	if w != null or sp["kind"] == "stool":
		for r in stool.get("taken", []):
			if r != null: return   # 손님이 앉아 있다
		seat = { "pos": stool["pos"], "yaw": stool["yaw"], "chair": true }
		player.seated = true; player.move_dir = Vector3.ZERO; player.speed = 0.0; body.velocity = Vector3.ZERO
		var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
		tw.tween_property(body, "position", stool["pos"] + Vector3(0, 0.05, 0), 0.3)
		player.face(stool["yaw"])
		if w != null:
			resole_at = now + StickPoses.HAMMER_T * 2.0
			w.say(w.mind.line("cobbler_serve"), 1.6)
		return
	for r in (cobbler["work"] as Dictionary).get("taken", []):
		if r != null: return   # 구두장이가 작업대로 오는 중 — 자리는 그의 것(리뷰 2026-10-01: 주민이 사람 몸속으로 걸어 들어왔다)
	player.face(sp["yaw"])
	player.pose_request = "hammer"; use_until = now + StickPoses.HAMMER_T; action_until = now + StickPoses.HAMMER_T
	for r in residents:
		if r.job == "cobbler" and r.state != "drive" and r.global_position.distance_to(body.global_position) < 12.0:
			r.say("Careful with the last.", 1.8); break

## 매 프레임(town_systems _tick): 사람의 걸음을 세고, 걸상에서 고쳐 받는 중이면 두 바퀴 뒤에 밑창이 새것이 된다(구두장이가 떠났거나 사람이 일어났으면 없던 일)
func _trades(delta: float, now: float) -> void:
	_wheel(delta, now)
	_mend(now)
	if seat.is_empty() and body.is_on_floor() and not swimming:
		walked += Vector2(body.velocity.x, body.velocity.z).length() * delta
	if walked > SOLE_M and not _sole_told:
		_sole_told = true; call("say_toast", "Your soles are wearing thin.")   # 토스트는 systems 층에 있다(위층) — 이름으로 부른다
	if resole_at < 0.0 or now < resole_at: return
	resole_at = -1.0
	var w := cobbler_at_work()
	if w == null or not seat.get("chair", false) or cobbler.is_empty() or (seat["pos"] as Vector3) != cobbler["stool"]["pos"]: return
	walked = 0.0; _sole_told = false
	w.say("Resoled.", 1.6)

## 사람이 걸상에서 꿰매 받는 중이면 한 바퀴 뒤에 찢어진 곳이 없어진다(재봉사가 떠났거나 사람이 일어났으면 없던 일)
func _mend(now: float) -> void:
	if player.pose_request == "sew" and use_until > 0.0 and now >= use_until:
		player.pose_request = ""; use_until = -1.0   # 앉은 사람은 town_player 의 앉기 가지가 먼저 return 해 use_until 이 안 풀린다 — 한 바퀴면 손을 내린다
	if mend_at < 0.0 or now < mend_at: return
	mend_at = -1.0
	var w := tailor_at_work()
	if w == null or tailor.is_empty() or not seat.get("chair", false) or (seat["pos"] as Vector3) != tailor["fitting"]["pos"]: return
	Wear.mend(player.worn.get("back")); w.say("There.", 1.6)
