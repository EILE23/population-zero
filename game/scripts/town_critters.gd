class_name TownCritters
extends TownTrades
## 여우의 노획(CI run 69)과 굴뚝 연기(CI run 77) — town_systems 가 500줄을 넘어 뗐다(2026-09-30). 사슬: boat → critters → systems

var _smoke_at := 0.0

## 여우 — 육식동물(운영자 2026-09-28): 새(비둘기·오리)를 살금살금 다가가 덮친다 — 새는 날아 도망. 사람이 때리면 6초간 쫓아와 문다.
## 노획(2026-09-28, 마을 소원 열두 개가 한 시스템 "쓰러진 사람 곁의 동물"이었다 — 그 첫 조각): 8m 안에서 넘어진 사람이 떨어뜨린 것(dropped_at, 6초 안)을
## 달려가 물고 굴로 가져가 놓는다 — 굴 앞에 놓이니 찾아가 다시 집을 수 있다. 물고 가는 동안 6m 안에 사과가 있으면 그리로 가서 물건을 놓고 사과를 먹는다(먹이로 유인).
## 한 번에 하나만 물고, 누가 먼저 집으면 그만둔다 — 넘어진 사람 곁에 서 있는 쪽이 늘 먼저다(핵심 동작은 그대로 되어야 한다는 규칙)
func _fox(a: Dictionary, delta: float) -> void:
	var n: Node3D = a["node"]; var q = a["quad"]   # Quad3D 또는 Animal3D
	var p := body.global_position; var d := p.distance_to(n.global_position)
	q.look = d < 5.0; q.look_at_pos = p + Vector3(0, 0.9, 0)
	var angry: bool = a.get("angry_until", 0.0) > a["t"]
	var want: Vector3 = a.get("wander", a["home"]); var spd := 0.0
	var stalking := false
	var lv: Variant = a.get("loot", null)   # 풀린(먹힌) 노드를 타입 변수에 바로 넣으면 런타임 오류 — 먼저 확인
	var loot: Node3D = lv if is_instance_valid(lv) else null
	a["loot"] = loot
	q.carry = loot != null
	if angry:
		want = p; spd = 4.2
		if d < 0.9 and a.get("bite_at", 0.0) < a["t"]:
			a["bite_at"] = a["t"] + 1.1; q.act("bite"); resident_hits_player(n, (p - n.global_position).normalized())
	elif loot != null:
		var bait := _near_item(n.global_position, "apple", 6.0)
		want = bait.global_position if bait else (a["home"] as Vector3) + Vector3(0.5, 0, 0.3); spd = 3.2
		if want.distance_to(n.global_position) < 0.5:
			_fox_drop(a, loot, n); q.act("bite")
			if bait: items.erase(bait); bait.queue_free(); a["wander_until"] = a["t"] + 3.0; a["wander"] = n.global_position
	else:
		var mv: Variant = a.get("mark", null)
		var mark: Node3D = mv if is_instance_valid(mv) and items.has(mv) else null   # 누가 먼저 집었다(또는 먹었다) — 그만둔다
		if mark == null: mark = _fresh_drop(n.global_position, 8.0)
		a["mark"] = mark
		if mark != null:
			want = mark.global_position; spd = 4.0
			if want.distance_to(n.global_position) < 0.6: _fox_grab(a, mark, q)
		else:
			var prey: Dictionary = {}; var pd := 4.5
			for b in animals:
				if b["kind"] in ["pigeon", "duck"] and b.get("fly", 0.0) <= 0.0:
					var dd: float = (b["node"] as Node3D).global_position.distance_to(n.global_position)
					if dd < pd: pd = dd; prey = b
			if not prey.is_empty():
				want = (prey["node"] as Node3D).global_position
				stalking = pd > 1.8
				spd = 1.0 if stalking else 4.0   # 멀면 살금살금, 가까우면 덮친다
				if pd < 0.9:
					prey["fly"] = 1.6; prey["land"] = prey.get("home", want) + Vector3(randf_range(-3, 3), 0, randf_range(-2, 2)); q.act("bite")
					a["wander_until"] = a["t"] + 3.0; a["wander"] = n.global_position
			else:
				if a.get("wander_until", 0.0) < a["t"]:
					a["wander_until"] = a["t"] + randf_range(3.0, 7.0); a["wander"] = a["home"] + Vector3(randf_range(-6, 6), 0, randf_range(-4, 4))
				want = a.get("wander", a["home"]); spd = 1.3
	if a.get("freeze_until", 0.0) > a["t"]: spd = 0.0   # 맞고 움찔하는 동안은 제자리
	var to := want - n.global_position; to.y = 0.0
	if to.length() > 0.4 and spd > 0.0:
		n.global_position += to.normalized() * spd * delta
		n.look_at(n.global_position + to, Vector3.UP, true)
		q.speed = spd
		if q.state != "bite": q.state = "run" if spd > 2.5 else ("stalk" if stalking else "walk")
	else:
		q.speed = 0.0
		if q.state in ["walk", "run", "stalk"]: q.state = "idle"

## 물기 — 물건을 바닥 목록에서 빼 여우 머리(입 앞)에 붙인다. 곁에 쓰러져 있던 사람이 한마디
func _fox_grab(a: Dictionary, mark: Node3D, q) -> void:
	items.erase(mark); a["mark"] = null; a["loot"] = mark; q.act("bite")
	mark.get_parent().remove_child(mark); q.head.add_child(mark)
	mark.position = Vector3(0, -q.head_r * 0.4, q.head_r * 1.6); mark.rotation = Vector3.ZERO
	for r in residents:
		if r.state in ["down", "getup"] and r.global_position.distance_to(mark.global_position) < 3.0:
			r.say(["The fox.", "That was mine.", "Noted. The fox."][r.uid % 3], 2.5); break

## 내려놓기 — 입에서 떼어 코앞 바닥에(_fly 가 내려놓는 높이와 같은 0.06). dropped_at 을 지워 제가 놓은 걸 다시 물지 않는다
func _fox_drop(a: Dictionary, loot: Node3D, n: Node3D) -> void:
	loot.get_parent().remove_child(loot); add_child(loot)
	loot.global_position = n.global_position + n.global_transform.basis.z * 0.35 + Vector3(0, 0.06, 0); loot.rotation = Vector3.ZERO
	if loot.has_meta("dropped_at"): loot.remove_meta("dropped_at")
	items.append(loot); a["loot"] = null

## 가장 가까운 그 종류의 바닥 물건(r 안), 없으면 null
func _near_item(from: Vector3, kind: String, r: float) -> Node3D:
	var best: Node3D = null
	for it in items:
		if String(it.get_meta("kind", "")) != kind: continue
		var dd := it.global_position.distance_to(from)
		if dd < r: r = dd; best = it
	return best

## 방금(6초 안) 넘어져 떨어진 물건(r 안) — Resident.hit 과 resident_hits_player 가 dropped_at 을 찍는다. 던진 것·내려놓은 것은 아니다
func _fresh_drop(from: Vector3, r: float) -> Node3D:
	var now := Time.get_ticks_msec() / 1000.0
	var best: Node3D = null
	for it in items:
		if float(it.get_meta("dropped_at", -99.0)) < now - 6.0: continue
		var dd := it.global_position.distance_to(from)
		if dd < r: r = dd; best = it
	return best

## 굴뚝 연기(run 77, 비전 10단계 "밤이 읽힌다"): 그 집의 침대·의자·선반 칸을 주민이 차지했거나 내가 그 안에서 앉거나 누워 있으면 굴뚝이 뿜는다 —
## 밖에서 "누가 집에 있다"를 읽는 첫 방법. 자세는 없다(사람이 하는 일이 아니다): 주민은 집에 가는 것만으로 연기를 낸다. 반초에 한 번 훑는다(집 넷, 자리 열몇 — 프레임마다 볼 일은 아니다)
func _smoke(now: float) -> void:
	if now - _smoke_at < 0.5: return
	_smoke_at = now
	for h in houses:
		if h.get("chim") == null: continue   # 평지붕(옥상 집)엔 굴뚝이 없다
		if not h.has("smoke"): h["smoke"] = _make_smoke(h["chim"])
		var pt: CPUParticles3D = h["smoke"]
		pt.emitting = _someone_home(h)
		pt.direction = Vector3(0.3 + gust * 6.0, 1.0, 0.0)   # 잎 뭉치와 같은 바람에 +x 로 흘러간다 — 비바람이면 더 눕는다

## 이 집에 누가 있나 — 주민이 잡은 칸(_house 가 spots[k]["door"] 로 집을 이어 둔다) 또는 그 벽 안에서 앉거나 누운 나
func _someone_home(h: Dictionary) -> bool:
	var p := body.global_position; var mn: Vector3 = h["min"]; var mx: Vector3 = h["max"]
	if (resting or not seat.is_empty()) and p.x > mn.x and p.x < mx.x and p.z > mn.z and p.z < mx.z and p.y < mx.y: return true
	for sp in spots:
		if not sp.has("taken") or sp.get("door") != h["door"]: continue
		for t in sp["taken"]:
			if t != null: return true
	return false

## 굴뚝 갓 위의 연기 입자 — 옅은 회색 구가 2초 동안 떠오르며 커지고 사라진다(color_ramp 로 끝에서 투명). 갓의 자식이라 컷어웨이로 지붕이 사라지면 같이 사라진다
func _make_smoke(cap: Node3D) -> CPUParticles3D:
	var pt := CPUParticles3D.new()
	pt.amount = 12; pt.lifetime = 2.0; pt.emitting = false; pt.local_coords = false
	pt.direction = Vector3(0.3, 1.0, 0.0); pt.spread = 10.0
	pt.initial_velocity_min = 0.3; pt.initial_velocity_max = 0.5; pt.gravity = Vector3(0, 0.2, 0)   # 연기는 뜬다 — 위로 갈수록 조금 빨라진다
	pt.scale_amount_min = 0.5; pt.scale_amount_max = 1.0
	var sc := Curve.new(); sc.add_point(Vector2(0.0, 0.5)); sc.add_point(Vector2(1.0, 1.8)); pt.scale_amount_curve = sc   # 퍼지면서 커진다
	var g := Gradient.new(); g.set_color(0, Color(0.76, 0.74, 0.73, 0.6)); g.set_color(1, Color(0.76, 0.74, 0.73, 0.0)); pt.color_ramp = g
	var sm := SphereMesh.new(); sm.radius = 0.09; sm.height = 0.18; sm.radial_segments = 8; sm.rings = 4; pt.mesh = sm
	var m := StandardMaterial3D.new(); m.albedo_color = Color.WHITE; m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pt.material_override = m
	pt.position = Vector3(0, 0.05, 0); cap.add_child(pt)
	return pt

## 주민이 나를 친다 — 같은 규칙: 움찔, 3초 안에 세 대면 넘어진다
func resident_hits_player(_r: Node3D, dir: Vector3) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if down_until > now or getup_until > now: return
	if now - my_last_hit > 3.0: my_hits = 0
	my_hits += 1; my_last_hit = now
	jet = false; throw_charge = -1.0; player.seated = false
	if not seat.is_empty(): seat = {}; body.collision_layer = 4; body.collision_mask = 7   # 앉은 채 맞으면 충돌을 되살린다 — 앉기 가지가 매 프레임 0/0 으로 꺼 두는데 자리만 지우면 마스크 0 인 몸이 바닥을 못 딛고 세계 밑으로 떨어졌다(polish 79)
	if my_hits >= 3:
		my_hits = 0
		if not riding.is_empty(): dismount()
		if seesaw_ride: seesaw_ride.leave("player"); seesaw_ride = null; body.global_position += Vector3(0, 0, 0.7)   # 시소 위에서 넘어지면 판 앞에 내린다(판 속에 겹친 채 마스크가 켜지면 바닥 밑으로 밀렸다) — 시소 가지가 먼저 return 해 일어나기가 영영 안 돌았다(polish 79)
		down_until = now + 1.6; player.lying = true; player.action = ""; action_until = now
		body.velocity = dir * 3.5 + Vector3(0, 2.0, 0)
		if Wear.tear(player.worn.get("back")): call("say_toast", "Torn. The tailor on the east plaza mends these.")   # 주민과 같은 규칙(run 82) — 토스트는 위층
		while player.carrying:   # 들고 있던 걸 전부 떨어뜨린다(주민과 같은 규칙)
			var it: Node3D = player.release(self, body.global_position + dir * randf_range(0.4, 0.8) + Vector3(randf_range(-0.3, 0.3), 0.1, 0)); it.set_meta("dropped_at", Time.get_ticks_msec() / 1000.0); items.append(it)   # 여우가 노린다(_fox)
	else:
		player.action = "flinch"; action_until = now + 0.3
		body.velocity = dir * 1.6
	cam_kick = 0.05

## 그네에서 내리기 — 어느 길로 내리든 여기로. 타는 동안 그네 각도를 따라 기울인 몸을 바로 세운다(전엔 뛰어내린 각도로 영영 기운 채 걸었다)
func dismount() -> void:
	riding = {}; player.pose_request = ""; player.rotation.x = 0.0

## 건네기(운영자 2026-09-30, 주민의 자아) — 든 걸(입는 것·우산 빼고) 1m 앞, 바라보는 쪽의 빈손 주민에게 C 로 준다. 받은 사람은 고마워하고 기억한다(호감↑), 먹을 거면 먹는다
func give_to_resident(now: float) -> bool:
	var it: Node3D = player.carrying
	if it == null or it.get_meta("wearable", false) or String(it.get_meta("kind", "")) == "umbrella": return false
	var p := body.global_position
	var fwd := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
	for r in residents:
		if r.state in ["down", "getup", "drive", "chase"] or r.in_boat or r.fig.carrying != null or r.fig.seated: continue
		var to: Vector3 = r.global_position - p; to.y = 0.0
		if to.length() > 1.0 or to.normalized().dot(fwd) < 0.5: continue
		r._release(); r.take_gift(player.release(self, Vector3.ZERO))
		player.action = "grab"; action_until = now + 0.4
		return true
	return false
