class_name TownTrades
extends TownBoat
## 거리의 장인들("Trades on the street", 마을이 설계한 열세 번째 시스템 — run 80 이 첫 조각): 작은 작업대에서 짧게 손일을 해 주는 사람과, 제 물건이 닳으면 알아서 찾아오는 주민.
## 첫 장인은 구두장이 — 동쪽 광장 서쪽 끝의 낮은 작업대(구두골·구두 셋·걸린 간판)와 그 옆 걸상. 동쪽 집(24호) 문에 "cobbler" 가 적혀 그 집 주민이 낮(09–17)에 여기서 망치질한다.
## 닳음은 진짜 걸음이다: 주민도 사람도 걸은 만큼 `walked` 가 쌓이고, 350m 를 넘은 주민은 구두장이가 일하는 중이면 걸상에 앉아 한 바퀴 두 번 고쳐 받는다("Better.").
## 사람: 구두장이가 일하는 중에 C = 걸상에 앉아 같은 수선(끝나면 "Resoled.", 내 걸음이 0), 아무도 없을 때 작업대에서 C = 망치질 한 바퀴(구두장이가 근처면 "Careful with the last.").
## 상속 사슬: base → build → places → boat → **trades** → critters → systems → combat → ride → player → town3d.

const SOLE_M := 350.0   # 이만큼 걸으면 밑창이 닳았다 — 주민 걸음(1.6m/s)으로 몇 분이면 차니 하루에 몇 명은 들른다
var cobbler: Dictionary = {}   # {work: 구두장이 자리, stool: 손님 걸상 자리}
var walked := 0.0              # 사람이 걸은 거리(m) — 걸상에서 고치면 0
var resole_at := -1.0          # 사람이 걸상에 앉아 고쳐 받는 중이면 끝나는 시각
var _sole_told := false        # "밑창이 얇다"는 한 번만

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
			w.say(["Sit.", "Left foot first.", "These have seen some road."][w.uid % 3], 1.6)
		return
	player.face(sp["yaw"])
	player.pose_request = "hammer"; use_until = now + StickPoses.HAMMER_T; action_until = now + StickPoses.HAMMER_T
	for r in residents:
		if r.job == "cobbler" and r.state != "drive" and r.global_position.distance_to(body.global_position) < 12.0:
			r.say("Careful with the last.", 1.8); break

## 매 프레임(town_systems _tick): 사람의 걸음을 세고, 걸상에서 고쳐 받는 중이면 두 바퀴 뒤에 밑창이 새것이 된다(구두장이가 떠났거나 사람이 일어났으면 없던 일)
func _trades(delta: float, now: float) -> void:
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
