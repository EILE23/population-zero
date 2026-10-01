class_name Car3D
extends CharacterBody3D
## 차(운영자 2026-09-29: "운전 자체가 재미있게 — 레이싱 게임 만들 때 쓰도록"). Kenney Car Kit(CC0) 모델 + 아케이드 조작:
## 가속·브레이크·후진, 속도에 따라 줄어드는 조향, SPACE 핸드브레이크로 뒷바퀴가 미끄러지는 드리프트(스키드 자국·먼지), 코너에서 몸이 기울고
## 가속·제동에 앞뒤로 끄덕임, 바퀴는 굴러가고 앞바퀴는 꺾인다. 조작은 `input`(throttle·steer·brake)로 받으니 사람이든 봇이든 시트 도구든 같은 길로 몬다.
## 물리는 직접 적분(VehicleBody3D 는 서스펜션 튜닝이 재미와 무관하게 시간을 먹는다): 앞 속도 v, 옆 미끄러짐 side, 요 각속도.

const SPECS := {
	"sedan":     { "path": "res://assets/models/vehicles/sedan.glb", "top": 9.5, "accel": 5.5, "grip": 9.0, "mass": 1.0 },
	"hatchback": { "path": "res://assets/models/vehicles/hatchback-sports.glb", "top": 11.0, "accel": 7.0, "grip": 8.0, "mass": 0.9 },
	"van":       { "path": "res://assets/models/vehicles/van.glb", "top": 8.0, "accel": 4.0, "grip": 10.0, "mass": 1.4 },
	"truck":     { "path": "res://assets/models/vehicles/truck.glb", "top": 7.5, "accel": 3.5, "grip": 10.0, "mass": 1.8 },
	"taxi":      { "path": "res://assets/models/vehicles/taxi.glb", "top": 9.5, "accel": 5.5, "grip": 9.0, "mass": 1.0 },
	"delivery":  { "path": "res://assets/models/vehicles/delivery.glb", "top": 8.0, "accel": 4.0, "grip": 10.0, "mass": 1.5 },
	"suv":       { "path": "res://assets/models/vehicles/suv.glb", "top": 9.0, "accel": 5.0, "grip": 9.5, "mass": 1.3 },
	"race":      { "path": "res://assets/models/vehicles/race.glb", "top": 14.0, "accel": 9.0, "grip": 7.0, "mass": 0.8 },
	"tractor":   { "path": "res://assets/models/vehicles/tractor.glb", "top": 5.0, "accel": 3.0, "grip": 12.0, "mass": 1.6 },
}

var kind := "sedan"
var town: Node3D
var driver: Node3D = null            # 타고 있는 사람(플레이어 body 또는 주민) — null 이면 세워 둔 차
var input := { "throttle": 0.0, "steer": 0.0, "brake": false }   # 매 프레임 바깥이 채운다(-1..1, -1..1, bool)

var v := 0.0                 # 앞 방향 속도(m/s, 후진은 음수)
var side := 0.0              # 옆 미끄러짐 속도(m/s, +는 오른쪽)
var yaw_rate := 0.0
var steer := 0.0             # 실제 조향(-1..1, 입력을 부드럽게 따라간다)
var drifting := false
var _spec: Dictionary = {}
var _model: Node3D
var _wheels: Array[Node3D] = []
var _front: Array[Node3D] = []
var _spin := 0.0
var _skid_t := 0.0
var _skids: Array[Node3D] = []
var _dust: CPUParticles3D
var _roll := 0.0
var _pitch := 0.0
var _crash_at := -9.0
var _blocked_since := -1.0
var _slope_pitch := 0.0
var _slope_roll := 0.0
var _vy := 0.0
var _grip_k := 1.0   # 뒤 접지력 배율 — 핸드브레이크로 내려가고 떼면 서서히 돌아온다
## 주민 운전(교통) — route 를 따라 돈다. 앞에 사람·차가 있으면 선다
var ai := false
var _shaken_until := -9.0         # 사고 뒤 멈춰 있는 시각(주민 운전)
var _detour := Vector3.INF         # 세워 둔 차를 비켜 가는 임시 경유지
var _block: Node3D = null          # 지금 나를 막는 것 — 서로 막았는지 보려고
var _reverse_until := -9.0         # 양보: 이 시각까지 후진
var _argued := false
var _rev_steer := 0.0
var _bias := 0.0                   # 막힌 뒤 한동안 이쪽(+오른쪽)으로 피한다
var _bias_until := -9.0
var _stuck_since := -1.0          # 가려는데 못 움직인 지 — 원인이 뭐든 2초면 꺾으며 뒤로 뺀다
var stop_until := -9.0             # 손님이 내리겠다고 하면 이 시각까지 선다
var route: Array[Vector3] = []
var _ri := 0

func setup(k: String, t: Node3D) -> void:
	kind = k; town = t; _spec = SPECS[k]
	_model = (load(_spec["path"]) as PackedScene).instantiate()
	_model.rotation.y = PI   # Kenney 모델은 앞이 +z, 컨트롤러는 -z 가 앞 — 안 돌리면 ↑ 에 뒤로 갔다(운영자 2026-09-29)
	add_child(_model)
	for c in _model.find_children("wheel*", "MeshInstance3D", true, false):
		if not ("left" in c.name or "right" in c.name): continue   # SUV 뒤 스페어타이어(wheel-back)는 차체 장식 — 굴리면 안 된다(운영자 2026-09-29)
		_wheels.append(c)
		if "front" in c.name: _front.append(c)
	var col := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.4, 0.9, 2.5); col.shape = bs; col.position.y = 0.55; add_child(col)
	collision_layer = 2; collision_mask = 3
	floor_max_angle = deg_to_rad(42.0); floor_snap_length = 0.25   # 언덕을 오르고, 꼭대기에서 빠르면 뜬다   # 차는 층 2 — 누운 몸(마스크 1만)은 차를 안 느껴 밀려나지 않고 깔린다
	_dust = CPUParticles3D.new()
	_dust.amount = 40; _dust.lifetime = 0.9; _dust.emitting = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; _dust.emission_box_extents = Vector3(0.5, 0.05, 0.2)
	_dust.direction = Vector3(0, 1, -1); _dust.spread = 40.0; _dust.initial_velocity_min = 0.8; _dust.initial_velocity_max = 1.8; _dust.gravity = Vector3(0, 0.6, 0)
	_dust.scale_amount_min = 0.6; _dust.scale_amount_max = 1.6
	var dm := SphereMesh.new(); dm.radius = 0.09; dm.height = 0.18; dm.radial_segments = 6; dm.rings = 3; _dust.mesh = dm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.82, 0.78, 0.7, 0.55); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust.material_override = mat; _dust.position = Vector3(0, 0.1, -1.0); add_child(_dust)

## 운전석(주민이 앉는 자리) — 차 앞쪽 왼편, 좌석 높이
func seat_pos() -> Vector3:
	return global_position - global_transform.basis.y * 0.08 - global_transform.basis.x * 0.28 - global_transform.basis.z * 0.05

## 조수석 — 운전석 반대편
func passenger_pos() -> Vector3:
	return global_position - global_transform.basis.y * 0.08 + global_transform.basis.x * 0.28 - global_transform.basis.z * 0.05

## 운전석 위치(사람이 내릴 자리는 왼쪽 옆)
func exit_pos() -> Vector3:
	return global_position + global_transform.basis.x * 1.3

## 주민 운전 — 더듬이(운영자 2026-09-30: "앞에 뭐가 있으면 피해가야지, 다 박으면서 지나다니네"). 앞범퍼에서 다섯 줄(정면·좌우 20°·좌우 45°)을
## 속도에 맞춘 길이로 쏜다(차·사람·벤치·가로등·울타리·집 — 층 1·2·3 전부). 정면이 막히면 더 트인 쪽으로 꺾고, 남은 거리만큼 속도를 줄인다(제동거리).
## 옆 더듬이가 가까우면 그 반대로 살짝 비킨다. 완전히 막혀 2초 서 있으면: 사람이면 천천히 밀고 가고(사람은 비켜선다), 그 밖이면 반대로 꺾으며 1.4초 후진한 뒤
## 트인 쪽으로 2초 기울여 다시 간다. 마주 선 주민 차끼리는 운전사가 한마디씩 하고 덜 급한 쪽이 양보한다(_standoff). 사고가 나면 2.5초 서서 한마디(_shaken)
const WHISK := [[0.0, 1.0], [0.35, 0.85], [-0.35, 0.85], [0.8, 0.55], [-0.8, 0.55]]   # [각도(rad, +는 오른쪽), 길이 배율]

func _whiskers(fwd: Vector3, right: Vector3, L: float) -> Array:
	var space := get_world_3d().direct_space_state
	var from := global_position + global_transform.basis.y * 0.55 + fwd * 1.2
	var out: Array = []   # [거리, 맞은 것]
	for w in WHISK:
		var dir: Vector3 = (fwd * cos(w[0]) + right * sin(w[0])).normalized()
		var len: float = L * float(w[1])
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * len, 7, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty(): out.append([len, null])
		else:
			var col: Object = hit["collider"]
			if col == driver or (hit["normal"] as Vector3).y > 0.55: out.append([len, null])   # 위를 보는 면은 땅(오르막·언덕·산길) — 막힘이 아니다
			else: out.append([from.distance_to(hit["position"]), col])
	return out

func _drive_ai() -> void:
	if route.is_empty(): return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _shaken_until:
		input = { "throttle": -0.4 if v > 0.3 else 0.0, "steer": 0.0, "brake": false }; return
	if now < stop_until:
		input = { "throttle": -0.5 if v > 0.3 else 0.0, "steer": 0.0, "brake": false }; return
	if now < _reverse_until:
		input = { "throttle": -0.6, "steer": _rev_steer, "brake": false }; return   # 뒤로 빼며 반대로 꺾는다
	var tgt: Vector3 = _detour if _detour != Vector3.INF else route[_ri]
	var to := tgt - global_position; to.y = 0.0
	if to.length() < 3.0:
		if _detour != Vector3.INF: _detour = Vector3.INF
		else: _ri = (_ri + 1) % route.size()
		return
	var diff := wrapf(atan2(-to.x, -to.z) - rotation.y, -PI, PI)
	var st := clampf(-diff * 2.0, -1.0, 1.0)
	var fwd := -global_transform.basis.z; var right := global_transform.basis.x
	var L := 3.0 + maxf(v, 0.0) * 0.9
	var wk := _whiskers(fwd, right, L)
	var c0: float = wk[0][0]
	var lclear: float = wk[2][0] + wk[4][0]; var rclear: float = wk[1][0] + wk[3][0]
	# 피하기: 정면이 막힐수록 트인 쪽으로 세게, 옆이 가까우면 반대로 살짝. 사람은 피해 꺾지 않고 선다(길 건너는 주민마다 꺾다 큰길을 벗어나 집 사이를 헤맸다)
	var solid := func(o: Variant) -> bool: return o != null and not (o is ResidentBase) and o != town.body
	if solid.call(wk[0][1]) or solid.call(wk[1][1]) or solid.call(wk[2][1]):
		var side := 1.0 if rclear > lclear else -1.0
		if now < _bias_until: side = _bias
		var urgency := 1.0 - c0 / L
		st = clampf(st + side * (0.4 + 1.6 * urgency), -1.0, 1.0)
	for k in [3, 4]:
		if solid.call(wk[k][1]) and float(wk[k][0]) < L * 0.35: st = clampf(st - (1.0 if k == 3 else -1.0) * 0.5, -1.0, 1.0)
	# 차선 지키기: 경유지 차선(z)에서 1.4m 넘게 벗어나면 되돌아오게 — 비켜 가도 큰길 안에서
	if _detour == Vector3.INF and absf(tgt.z - global_position.z) < 3.0 and absf(fwd.x) > 0.7:
		var off := global_position.z - tgt.z
		if absf(off) > 1.4: st = clampf(st + signf(off) * signf(fwd.x) * -0.6 * minf(absf(off) - 1.4, 1.0), -1.0, 1.0)
	var tspd := 8.0 * clampf(1.0 - absf(diff) / 1.2, 0.3, 1.0)   # 꺾을수록 천천히
	var block: Object = wk[0][1]
	if block != null: tspd = minf(tspd, maxf(0.0, (c0 - 1.2) * 1.3))   # 제동거리 — 남은 거리만큼만
	var thr := 0.6 if v < tspd else (-0.5 if v > tspd + 0.8 else 0.0)
	_block = block as Node3D if block is Node3D else null
	var stopped := block != null and c0 < 2.2 and absf(v) < 0.6
	if not stopped: _blocked_since = -1.0; _argued = false
	elif _blocked_since < 0.0: _blocked_since = now
	var waited := now - _blocked_since if stopped else 0.0
	if stopped:
		if block is Car3D and (block as Car3D)._block == self and driver is Resident and (block as Car3D).driver is Resident:
			thr = 0.0; _standoff(block as Car3D, now)
		elif block is ResidentBase or block == town.body:
			if waited > 1.5: thr = 0.35 if waited > 4.0 else 0.2   # 사람: 섰다가 천천히 밀고 간다
			if waited > 1.5 and fmod(now, 3.0) < 0.05 and driver is Resident: (driver as Resident).say(["Excuse me.", "Coming through.", "Mind the car."][int(now) % 3], 1.4)
		elif waited > 2.0:
			var side := 1.0 if rclear > lclear else -1.0
			_reverse_until = now + 1.4; _rev_steer = -side; _bias = side; _bias_until = now + 3.4; _blocked_since = -1.0   # 후진할 때 반대로 꺾으면 앞코가 트인 쪽으로 돈다
			if driver is Resident and randf() < 0.5: (driver as Resident).say(["Hm. Tight.", "Reversing.", "Who put that there."][randi() % 3], 1.6)
	# 끼임: 가려는데(가속 중) 1초에 0.3m/s 도 못 내고 2초 — 앞 더듬이가 못 본 모서리(울타리 기둥·집 모서리)에 옆구리가 걸려 제자리에서 튕기던 것
	if thr > 0.1 and absf(v) < 0.3 and not stopped:
		if _stuck_since < 0.0: _stuck_since = now
		elif now - _stuck_since > 2.0:
			var sd := 1.0 if rclear > lclear else -1.0
			_reverse_until = now + 1.4; _rev_steer = -sd; _bias = sd; _bias_until = now + 3.4; _stuck_since = -1.0
	else: _stuck_since = -1.0
	input = { "throttle": thr, "steer": st, "brake": false }

func _physics_process(delta: float) -> void:
	if ai and driver is Resident:
		if (driver as Resident).state == "drive": _drive_ai()
		else: driver = null; input = { "throttle": 0.0, "steer": 0.0, "brake": false }   # 운전사가 내렸으면(어떤 이유로든) 차는 선다 — 빈 차가 혼자 달리던 것
	var driven := driver != null
	var thr: float = clampf(float(input["throttle"]), -1.0, 1.0) if driven else 0.0
	var st_in: float = clampf(float(input["steer"]), -1.0, 1.0) if driven else 0.0
	var hb: bool = bool(input["brake"]) if driven else false
	var top: float = _spec["top"]; var accel: float = _spec["accel"]; var grip: float = _spec["grip"]
	# 가속·제동: 앞으로 갈 때 뒤를 누르면 브레이크(빠르게), 멈춘 뒤엔 후진(느리게)
	if thr > 0.0: v = move_toward(v, top, accel * delta * (1.0 if v >= 0.0 else 2.2))
	elif thr < 0.0: v = move_toward(v, -top, accel * (2.2 if v > 0.0 else 1.0) * delta)   # 후진도 앞과 같은 가속·최고속(운영자 2026-09-29)
	else: v = move_toward(v, 0.0, (2.0 + absf(v) * 0.25) * delta)   # 놓으면 엔진 브레이크
	if hb: v = move_toward(v, 0.0, (1.2 if thr > 0.0 else 4.0) * delta)   # 핸드브레이크: 가속 중이면 속도는 조금만 깎이고 뒤가 미끄러진다(드리프트), 놓고 당기면 제동
	# 조향: 입력을 부드럽게, 빠를수록 덜 꺾인다(고속 안정), 느리면 크게(주차)
	steer = move_toward(steer, st_in, 5.0 * delta)
	var speed_k := clampf(absf(v) / 5.0, 0.0, 1.0)
	var max_yaw := lerpf(2.4, 1.15, speed_k)
	var want_yaw := steer * max_yaw * clampf(absf(v) / 1.5, 0.0, 1.0) * (1.0 if v >= 0.0 else -1.0)
	# 드리프트 물리(운영자 2026-09-29: 이상하게 동작) — 운동량은 세계 좌표에 남고 차체만 돈다: 돌기 전 속도 벡터를 새 앞·옆으로 다시 나눠 미끄러짐이 저절로 생긴다
	# (전엔 속도가 차 앞방향에 붙어 같이 돌고 옆 속도만 따로 더해 제자리에서 도는 느낌이었다). 옆 접지력이 옆 속도를 죽이는데, 핸드브레이크면 뒤 접지력이 확 줄어
	# 차가 옆으로 흘러가고, 떼면 0.4초에 걸쳐 접지력이 돌아와 자세를 잡는다. 드리프트 중 조향은 더 세게 먹어 카운터로 각을 잡을 수 있다
	var fwd0 := -global_transform.basis.z; var right0 := global_transform.basis.x
	var vel_h := fwd0 * v + right0 * side
	_grip_k = move_toward(_grip_k, 0.22 if (hb and absf(v) > 3.0) else 1.0, delta / 0.4)
	if _grip_k < 0.9: want_yaw *= 1.5
	yaw_rate = lerpf(yaw_rate, want_yaw, minf(1.0, delta * (6.0 if _grip_k > 0.9 else 3.0)))
	rotation.y -= yaw_rate * delta
	var nf := -global_transform.basis.z; var nr := global_transform.basis.x
	v = vel_h.dot(nf); side = vel_h.dot(nr)
	side = move_toward(side, 0.0, grip * _grip_k * delta)   # 옆 접지력
	side = clampf(side, -9.0, 9.0)
	drifting = absf(side) > 1.2 and absf(v) > 2.0      # 옆으로 흐르는 동안 스키드·먼지
	var fwd := -global_transform.basis.z
	var right := global_transform.basis.x
	# 언덕: 바닥 기울기를 따라 달리고, 내리막은 빨라지고 오르막은 느려진다. 차체도 바닥에 맞춰 기운다
	var fwd_s := fwd; var right_s := right
	var on_car := false
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is Car3D and get_slide_collision(i).get_normal().y > 0.3: on_car = true
	if is_on_floor() and not on_car:
		var fn := get_floor_normal()
		fwd_s = (fwd - fn * fwd.dot(fn)).normalized(); right_s = (right - fn * right.dot(fn)).normalized()
		v += -9.8 * fwd_s.y * delta * 0.85
	_slope_pitch = lerpf(_slope_pitch, asin(clampf(fwd_s.y, -0.9, 0.9)), minf(1.0, delta * 10.0))
	_slope_roll = lerpf(_slope_roll, asin(clampf(right_s.y, -0.9, 0.9)), minf(1.0, delta * 10.0))
	if absf(v) > 1.5: _smash_props(fwd)   # 물리 전에 — 늦으면 벤치 충돌체에 먼저 막혀 튕겼다
	_run_over(fwd)
	var before := global_position
	_vy = 0.0 if is_on_floor() and not on_car else _vy - 20.0 * delta
	_unstack()   # 언덕 꼭대기에서 속도가 붙어 있으면 뜬다(점프)
	velocity = fwd_s * v + right_s * side + Vector3(0, _vy, 0)
	move_and_slide()
	# 충돌: 다른 차면 교통사고(서로 밀리고 부품이 튄다), 집이면 벽이 부서지고(금·먼지) 튕겨 나온다
	var now := Time.get_ticks_msec() / 1000.0
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if absf(n.y) > 0.5 and not (col.get_collider() is Car3D): continue
		var hit_speed := absf(v) * absf(n.dot(fwd)) + absf(side) * absf(n.dot(right))
		if col.get_collider() is Car3D:
			var o: Car3D = col.get_collider()
			if hit_speed > 1.5 and now - _crash_at > 0.4:
				_crash_at = now; o._crash_at = now
				var push := fwd * v + right * side
				var k: float = float(_spec["mass"]) / (float(_spec["mass"]) + float(o._spec["mass"]))
				var ofw := -o.global_transform.basis.z; var ort := o.global_transform.basis.x
				o.v += push.dot(ofw) * k * 1.2; o.side += push.dot(ort) * k * 1.4; o.yaw_rate += randf_range(-2.0, 2.0) * k
				v *= (1.0 - k) * 0.5; side *= 0.3
				_debris(col.get_position(), push, hit_speed)
				for cc in [self, o]: cc._shaken()
		elif hit_speed > 1.0:
			if hit_speed > 4.0 and now - _crash_at > 0.3:
				_crash_at = now
				for j in int(clampf(hit_speed / 3.0, 1.0, 4.0)): town._crack_wall(fwd * signf(v), global_position + fwd * signf(v) * 0.7 + Vector3(randf_range(-0.5, 0.5), -0.3, 0))
				_debris(col.get_position(), fwd * v, hit_speed * 0.5)
			v *= -0.2; side *= 0.4   # 튕겨 나온다
	global_position.x = clampf(global_position.x, -town.OPEN + 1.5, town.OPEN - 1.5)   # 열린 세계 끝까지 달린다
	global_position.z = clampf(global_position.z, -town.OPEN + 1.5, town.OPEN - 1.5)
	# 바퀴: 굴러가고(이동 거리로), 앞바퀴는 조향각
	var moved := global_position.distance_to(before) * signf(v if absf(v) > 0.05 else 1.0)
	_spin += moved / 0.3
	for w in _wheels:
		w.rotation.x = _spin
	for w in _front:
		w.rotation.y = -steer * 0.55
	# 몸 기울기: 코너 바깥으로 롤, 가속하면 뒤로·제동하면 앞으로 끄덕
	_roll = lerpf(_roll, clampf(yaw_rate * v * 0.02, -0.12, 0.12), minf(1.0, delta * 6.0))
	_pitch = lerpf(_pitch, clampf(-thr * 0.03 * (1.0 if absf(v) < top * 0.9 else 0.2), -0.05, 0.05), minf(1.0, delta * 5.0))
	_model.rotation.z = _roll - _slope_roll; _model.rotation.x = _pitch - _slope_pitch
	# 드리프트: 스키드 자국·먼지
	_dust.emitting = drifting
	if drifting:
		_skid_t += delta
		if _skid_t > 0.06:
			_skid_t = 0.0
			for sx in [-0.6, 0.6]:
				_skid(global_position + right * sx + fwd * -0.8)
	if driven and absf(v) > 2.5: _hit_people(fwd)
	elif driven and absf(v) > 0.2: _nudge_people(fwd, delta)

## 스키드 자국: 바닥 위 얇은 어두운 판, 200개 넘으면 오래된 것부터 지운다
func _skid(at: Vector3) -> void:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.14, 0.006, 0.55); mi.mesh = bm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.22, 0.2, 0.2, 0.55); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m; mi.position = Vector3(at.x, 0.012, at.z); mi.rotation.y = rotation.y
	town.add_child(mi); _skids.append(mi)
	if _skids.size() > 200: (_skids.pop_front() as Node3D).queue_free()

## 천천히 갈 땐 앞사람을 밀며 간다(길막 대신) — 밀린 사람은 옆으로 비켜서며 한마디
func _nudge_people(fwd: Vector3, delta: float) -> void:
	var push := fwd * absf(v) * 1.15 * delta * signf(v)
	for r in town.residents:
		if r.state == "down" or r == driver: continue
		var to: Vector3 = r.global_position - global_position; to.y = 0.0
		if to.length() < 1.8 and (fwd * signf(v)).dot(to.normalized()) > 0.4:
			var sidestep: Vector3 = global_transform.basis.x * signf(global_transform.basis.x.dot(to)) * 0.6 * delta
			r.global_position += push + sidestep
			if randf() < 0.01: r.say(["Careful.", "I am walking here.", "Do you mind."][r.uid % 3], 1.4)
	if town.driving != self and town.body.visible:
		var tp: Vector3 = town.body.global_position - global_position; tp.y = 0.0
		if tp.length() < 1.8 and (fwd * signf(v)).dot(tp.normalized()) > 0.4: town.body.global_position += push

## 기절해 누운 것 위로 지나가면 깔고 넘어간다(운영자 2026-09-29) — 차가 덜컹 들리고, 깔린 몸은 납작해졌다 돌아오며 기절이 길어진다
func _run_over(_fwd: Vector3) -> void:
	if absf(v) < 0.5: return
	var now := Time.get_ticks_msec() / 1000.0
	for r in town.residents:
		if r.state != "down" or r == driver: continue
		var to: Vector3 = r.global_position - global_position; to.y = 0.0
		if to.length() < 1.1 and now - float(r.get_meta("flat_at", -9.0)) > 1.2:
			r.set_meta("flat_at", now); r.down_until = maxf(r.down_until, now + 1.0); r.say("Ow.", 1.0)
			_flatten(r.fig); _pitch -= 0.08
	for a in town.animals:
		if a.get("stun_until", 0.0) < a["t"] or a.has("lv"): continue
		var an: Node3D = a["node"]
		var to: Vector3 = an.global_position - global_position; to.y = 0.0
		if to.length() < 1.0 and now - float(a.get("flat_at", -9.0)) > 1.2:
			a["flat_at"] = now; a["stun_until"] = a["t"] + 1.5; _flatten(an); _pitch -= 0.06
	if town.driving != self and town.down_until > now:
		var tp: Vector3 = town.body.global_position - global_position; tp.y = 0.0
		if tp.length() < 1.1 and now - float(get_meta("flat_me", -9.0)) > 1.2:
			set_meta("flat_me", now); town.down_until += 1.0; _flatten(town.player); _pitch -= 0.08

static func _flatten(n: Node3D) -> void:
	var prop := "base_scale" if n is Stick3D else "scale"   # 졸라맨은 scale 을 프레임마다 제가 쓴다(찌그러짐) — 기준 배율을 눌러야 0.5초 납작함이 보인다(polish 79)
	var tw := n.create_tween(); tw.set_trans(Tween.TRANS_BACK); tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(n, prop, Vector3(1.25, 0.35, 1.25), 0.06)
	tw.tween_interval(0.5)
	tw.tween_property(n, prop, Vector3.ONE, 0.45)

## 벤치·울타리 토막을 들이받으면 부서져 조각이 날아간다 — 수리공이 나중에 다시 세운다
func _smash_props(fwd: Vector3) -> void:
	for w in town.wreckables.duplicate():
		var to: Vector3 = (w["at"] as Vector3) - global_position; to.y = 0.0
		var ahead := to.dot(fwd * signf(v)); var lat := absf(to.dot(global_transform.basis.x))
		if ahead > 0.0 and ahead < 1.25 + float(w["r"]) + absf(v) * 0.05 and lat < 0.72 + float(w["r"]):   # 차체 앞 상자에 닿은 것만 — 전엔 1.7m 부채꼴이라 길가 가로등·벤치 옆을 지나기만 해도 부쉈다
			town.smash(w, fwd * signf(v) * absf(v))
			v *= 0.8

## 부딪힌 자리에서 부품(범퍼 조각·볼트·판)이 튀어 날아가 떨어진다 — 떨어진 건 주울 수 있다
func _debris(at: Vector3, push: Vector3, strength: float) -> void:
	var parts := ["debris-bolt", "debris-plate-small-a", "debris-bumper", "debris-plate-a", "debris-tire"]
	for i in int(clampf(strength / 2.0, 1.0, 5.0)):
		var id: String = parts[randi() % parts.size()]
		var ps: PackedScene = load("res://assets/models/vehicles/%s.glb" % id)
		if ps == null: continue
		var d: Node3D = ps.instantiate(); d.scale = Vector3.ONE * 0.8; town.add_child(d); d.global_position = at + Vector3(0, 0.5, 0)
		d.set_meta("debris", true); d.set_meta("fade", true)   # 이펙트일 뿐 — 줍지 못하고 몇 초 뒤 사라진다(운영자 2026-09-29)
		town.flying.append({ "node": d, "vel": push.normalized() * randf_range(1.0, 3.0) + Vector3(randf_range(-2, 2), randf_range(2.5, 5.0), randf_range(-2, 2)), "spin": randf_range(6.0, 14.0) })

## 앞에 선 주민·동물·사람을 친다 — 속도만큼 날아가 기절했다 일어난다(운영자 2026-09-29)
func _hit_people(fwd: Vector3) -> void:
	var launch := fwd * absf(v) * 0.9 + Vector3(0, 2.0 + absf(v) * 0.35, 0)
	var stun := 1.2 + absf(v) * 0.15
	for r in town.residents:
		if r.state in ["down", "drive"] or r == driver: continue   # 다른 차의 운전사도 차 안이다
		var to: Vector3 = r.global_position - global_position; to.y = 0.0
		if to.length() < 1.7 and fwd.dot(to.normalized()) > 0.5:
			r.hit(fwd, self, true); r.launch(launch, stun); v *= 0.7
	if town.driving != self:
		var tp: Vector3 = town.body.global_position - global_position; tp.y = 0.0
		if tp.length() < 1.7 and fwd.dot(tp.normalized()) > 0.5 and town.body.visible:
			town.car_hits_player(launch, stun); v *= 0.7
	for a in town.animals:
		if not a.has("quad"): continue
		var an: Node3D = a["node"]
		var to: Vector3 = an.global_position - global_position; to.y = 0.0
		if to.length() < 1.5 and fwd.dot(to.normalized()) > 0.5 and not a.has("lv") and a.get("stun_until", 0.0) < a["t"]:
			town.animal_hit(a, fwd)
			a["lv"] = launch * 0.9; a["stun_for"] = stun + 0.8; a["car_fear_until"] = a["t"] + 30.0

## 차끼리 겹치거나 올라탔으면 옆으로 떼어 낸다 — 상자 충돌체 모서리를 비탈로 읽어 남의 차 위에 올라앉아 끼던 것(운영자 2026-09-30)
func _unstack() -> void:
	for c in town.cars:
		if c == self: continue
		var d: Vector3 = global_position - c.global_position
		var hd := Vector2(d.x, d.z)
		if hd.length() > 2.3 or absf(d.y) > 1.6: continue
		if d.y > 0.25:   # 위에 올라탔다: 바깥으로 밀고 떨어뜨린다
			var out := Vector3(hd.x, 0, hd.y).normalized() if hd.length() > 0.05 else global_transform.basis.x
			global_position += out * 0.12; _vy = minf(_vy, -1.5)
		elif hd.length() < 1.3:   # 속이 겹쳤다: 둘 다 반씩 비킨다
			var push := Vector3(hd.x, 0, hd.y).normalized() * (1.3 - hd.length()) * 0.5
			global_position += push; c.global_position -= push

## 사고 — 주민이 몰던 차면 2.5초 서서 운전사가 한마디(그냥 가지 않는다)
func _shaken() -> void:
	if not ai or not (driver is Resident): return
	_shaken_until = Time.get_ticks_msec() / 1000.0 + 2.5
	var r: Resident = driver
	r.say(r.mind.line("hurt") if randf() < 0.5 else ["Oh dear.", "Sorry! Sorry.", "Was that me?"][randi() % 3], 2.0)

## 맞선 두 차(운영자 2026-09-30: "어디 한 쪽이 좀 빼던가, 아니면 둘이 싸우던가") — 운전사끼리 제 성미대로 한마디씩 주고받고,
## 덜 급한 쪽(성미가 낮은 쪽, 같으면 uid 가 작은 쪽)이 1.8초 뒤로 뺀 뒤 옆으로 비켜 지나간다. 급한 쪽은 기다렸다 간다. 둘 다 불같으면 한 번 더 싸운다
func _standoff(o: Car3D, now: float) -> void:
	var me: Resident = driver; var him: Resident = o.driver
	if not _argued:
		_argued = true; o._argued = true
		var hot := me.mind.temper > 0.6
		me.say(["Back up!", "I was here first.", "Really? Now?"][randi() % 3] if hot else ["After you.", "Oh. Sorry.", "Shall I?"][randi() % 3], 2.0)
		get_tree().create_timer(1.4).timeout.connect(func() -> void: if is_instance_valid(him): him.say(["You back up!", "Absolutely not.", "Unbelievable."][randi() % 3] if him.mind.temper > 0.6 else ["Fine, fine.", "No, after you.", "All right."][randi() % 3], 2.0))
		return
	var i_yield := me.mind.temper < him.mind.temper or (is_equal_approx(me.mind.temper, him.mind.temper) and me.uid < him.uid)
	if not i_yield or now - _blocked_since < 3.2: return
	_reverse_until = now + 1.8; _rev_steer = -1.0; _bias = 1.0; _bias_until = now + 4.5; _blocked_since = -1.0; _argued = false; o._argued = false   # 뒤로 빼며 앞코를 오른쪽으로 — 그다음 오른쪽으로 비켜 상대 옆을 지난다
	me.mind.befriend(him, -0.05); him.mind.befriend(me, -0.05)
