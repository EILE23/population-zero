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
## 주민 운전(교통) — route 를 따라 돈다. 앞에 사람·차가 있으면 선다
var ai := false
var route: Array[Vector3] = []
var _ri := 0

func setup(k: String, t: Node3D) -> void:
	kind = k; town = t; _spec = SPECS[k]
	_model = (load(_spec["path"]) as PackedScene).instantiate()
	_model.rotation.y = PI   # Kenney 모델은 앞이 +z, 컨트롤러는 -z 가 앞 — 안 돌리면 ↑ 에 뒤로 갔다(운영자 2026-09-29)
	add_child(_model)
	for c in _model.find_children("wheel*", "MeshInstance3D", true, false):
		_wheels.append(c)
		if "front" in c.name: _front.append(c)
	var col := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(1.4, 0.9, 2.5); col.shape = bs; col.position.y = 0.55; add_child(col)
	collision_layer = 1; collision_mask = 1
	_dust = CPUParticles3D.new()
	_dust.amount = 40; _dust.lifetime = 0.9; _dust.emitting = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; _dust.emission_box_extents = Vector3(0.5, 0.05, 0.2)
	_dust.direction = Vector3(0, 1, -1); _dust.spread = 40.0; _dust.initial_velocity_min = 0.8; _dust.initial_velocity_max = 1.8; _dust.gravity = Vector3(0, 0.6, 0)
	_dust.scale_amount_min = 0.6; _dust.scale_amount_max = 1.6
	var dm := SphereMesh.new(); dm.radius = 0.09; dm.height = 0.18; dm.radial_segments = 6; dm.rings = 3; _dust.mesh = dm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.82, 0.78, 0.7, 0.55); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust.material_override = mat; _dust.position = Vector3(0, 0.1, -1.0); add_child(_dust)

## 운전석 위치(사람이 내릴 자리는 왼쪽 옆)
func exit_pos() -> Vector3:
	return global_position + global_transform.basis.x * 1.3

## 주민 운전: 다음 경유지로 핸들을 꺾고, 앞 5m 안에 사람·차가 있으면 브레이크
func _drive_ai() -> void:
	if route.is_empty(): return
	var tgt: Vector3 = route[_ri]
	var to := tgt - global_position; to.y = 0.0
	if to.length() < 2.0: _ri = (_ri + 1) % route.size(); return
	var want := atan2(-to.x, -to.z)
	var diff := wrapf(want - rotation.y, -PI, PI)
	var st := clampf(-diff * 2.0, -1.0, 1.0)
	var fwd := -global_transform.basis.z
	var blocked := false
	var others: Array = town.residents.duplicate()
	others.append(town.body)
	for c in town.cars: if c != self: others.append(c)
	for o in others:
		if not (o as Node3D).visible: continue
		var d: Vector3 = (o as Node3D).global_position - global_position; d.y = 0.0
		if d.length() < 5.0 and fwd.dot(d.normalized()) > 0.8: blocked = true; break
	input = { "throttle": (0.0 if blocked else 0.6), "steer": st, "brake": blocked }

func _physics_process(delta: float) -> void:
	if ai and driver == self: _drive_ai()
	var driven := driver != null
	var thr: float = clampf(float(input["throttle"]), -1.0, 1.0) if driven else 0.0
	var st_in: float = clampf(float(input["steer"]), -1.0, 1.0) if driven else 0.0
	var hb: bool = bool(input["brake"]) if driven else false
	var top: float = _spec["top"]; var accel: float = _spec["accel"]; var grip: float = _spec["grip"]
	# 가속·제동: 앞으로 갈 때 뒤를 누르면 브레이크(빠르게), 멈춘 뒤엔 후진(느리게)
	if thr > 0.0: v = move_toward(v, top, accel * delta * (1.0 if v >= 0.0 else 2.2))
	elif thr < 0.0: v = move_toward(v, -top * 0.35, (accel * 2.2 if v > 0.0 else accel * 0.8) * delta)
	else: v = move_toward(v, 0.0, (2.0 + absf(v) * 0.25) * delta)   # 놓으면 엔진 브레이크
	if hb: v = move_toward(v, 0.0, (1.2 if thr > 0.0 else 4.0) * delta)   # 핸드브레이크: 가속 중이면 속도는 조금만 깎이고 뒤가 미끄러진다(드리프트), 놓고 당기면 제동
	# 조향: 입력을 부드럽게, 빠를수록 덜 꺾인다(고속 안정), 느리면 크게(주차)
	steer = move_toward(steer, st_in, 5.0 * delta)
	var speed_k := clampf(absf(v) / 5.0, 0.0, 1.0)
	var max_yaw := lerpf(2.4, 1.15, speed_k)
	var want_yaw := steer * max_yaw * clampf(absf(v) / 1.5, 0.0, 1.0) * (1.0 if v >= 0.0 else -1.0)
	drifting = hb and absf(v) > 3.0
	if drifting: want_yaw *= 1.6   # 핸드브레이크: 뒤가 돌아 나간다
	yaw_rate = lerpf(yaw_rate, want_yaw, minf(1.0, delta * (6.0 if not drifting else 3.5)))
	rotation.y -= yaw_rate * delta
	# 옆 미끄러짐: 코너에서 원심력만큼 생기고 접지력이 잡아먹는다. 드리프트면 접지력이 확 준다
	side += yaw_rate * v * delta * 0.9
	side = move_toward(side, 0.0, (grip if not drifting else grip * 0.22) * delta)
	side = clampf(side, -6.0, 6.0)
	var fwd := -global_transform.basis.z
	var right := global_transform.basis.x
	var before := global_position
	velocity = fwd * v + right * side + Vector3(0, -9.8 if not is_on_floor() else 0.0, 0)
	move_and_slide()
	# 충돌: 다른 차면 교통사고(서로 밀리고 부품이 튄다), 집이면 벽이 부서지고(금·먼지) 튕겨 나온다
	var now := Time.get_ticks_msec() / 1000.0
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if absf(n.y) > 0.5: continue
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
		elif hit_speed > 1.0:
			if hit_speed > 4.0 and now - _crash_at > 0.3:
				_crash_at = now
				for j in int(clampf(hit_speed / 3.0, 1.0, 4.0)): town._crack_wall(fwd * signf(v), global_position + fwd * signf(v) * 0.7 + Vector3(randf_range(-0.5, 0.5), -0.3, 0))
				_debris(col.get_position(), fwd * v, hit_speed * 0.5)
			v *= -0.2; side *= 0.4   # 튕겨 나온다
	global_position.x = clampf(global_position.x, -town.WORLD_X + 1.5, town.WORLD_X - 1.5)
	global_position.z = clampf(global_position.z, -town.WORLD_Z + 1.5, town.WORLD_Z - 1.5)
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
	_model.rotation.z = _roll; _model.rotation.x = _pitch
	# 드리프트: 스키드 자국·먼지
	_dust.emitting = drifting
	if drifting:
		_skid_t += delta
		if _skid_t > 0.06:
			_skid_t = 0.0
			for sx in [-0.6, 0.6]:
				_skid(global_position + right * sx + fwd * -0.8)
	if driven and absf(v) > 2.5: _hit_people(fwd)

## 스키드 자국: 바닥 위 얇은 어두운 판, 200개 넘으면 오래된 것부터 지운다
func _skid(at: Vector3) -> void:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.14, 0.006, 0.55); mi.mesh = bm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.22, 0.2, 0.2, 0.55); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m; mi.position = Vector3(at.x, 0.012, at.z); mi.rotation.y = rotation.y
	town.add_child(mi); _skids.append(mi)
	if _skids.size() > 200: (_skids.pop_front() as Node3D).queue_free()

## 부딪힌 자리에서 부품(범퍼 조각·볼트·판)이 튀어 날아가 떨어진다 — 떨어진 건 주울 수 있다
func _debris(at: Vector3, push: Vector3, strength: float) -> void:
	var parts := ["debris-bolt", "debris-plate-small-a", "debris-bumper", "debris-plate-a", "debris-tire"]
	for i in int(clampf(strength / 2.0, 1.0, 5.0)):
		var id: String = parts[randi() % parts.size()]
		var ps: PackedScene = load("res://assets/models/vehicles/%s.glb" % id)
		if ps == null: continue
		var d: Node3D = ps.instantiate(); d.scale = Vector3.ONE * 0.8; town.add_child(d); d.global_position = at + Vector3(0, 0.5, 0)
		town.flying.append({ "node": d, "vel": push.normalized() * randf_range(1.0, 3.0) + Vector3(randf_range(-2, 2), randf_range(2.5, 5.0), randf_range(-2, 2)), "spin": randf_range(6.0, 14.0) })

## 앞에 선 주민·동물·사람을 친다 — 속도만큼 날아가 기절했다 일어난다(운영자 2026-09-29)
func _hit_people(fwd: Vector3) -> void:
	var launch := fwd * absf(v) * 0.9 + Vector3(0, 2.0 + absf(v) * 0.35, 0)
	var stun := 1.2 + absf(v) * 0.15
	for r in town.residents:
		if r.state == "down": continue
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
			a["lv"] = launch * 0.9; a["stun_for"] = stun + 0.8
