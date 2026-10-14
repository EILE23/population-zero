class_name TownTraffic
extends TownCabin
## 차로 다니는 주민(운영자 2026-10-08: "차 운전하는 주민도 많아져야지, 지금 차량 보면 왔다 갔다밖에 안 하잖아") —
## 집이 북쪽 블록에 있는 주민 몇에게 자기 차(집 앞 길에 세워 둔다). 낮이면 가끔 볼일을 정한다: 가게·시청·학교·남의 집·탑·호숫가·오두막.
## 차까지 걸어가 타고(주민의 "car" 자리 — 이미 있는 길) → 골목 격자를 차선 주행(car_rail — 오른쪽 차선·둥근 모퉁이·앞차 간격·교차로 양보) →
## 목적지 길섶에 대고 내려 그 문으로 들어간다. 한참 뒤엔 다시 차로 집에 와 세운다. 사람이 그 차를 빼앗으면(차는 사람 것) 그 볼일은 끝

const COMMUTERS := 12
const KINDS := ["sedan", "hatchback", "suv", "truck", "sedan", "hatchback"]
const EAST_Z := 2.9
const WEST_Z := 1.1
const VERGE := 2.6                # 갓길 주차 — 길 가운데에서(아스팔트 끝 3.35 안, 차선 차와 0.6m 틈)

var commuters: Array = []   # [{r, car, home: Vector3, phase, dest, until}]
var cruisers: Array = []    # [{r, car, slow}] — 늘 도는 차(GTA 처럼 길에 차가 끊이지 않게): 닿으면 곧장 다음 목적지
const CRUISERS := 8
var _traffic_at := 0.0

## 마을이 다 선 뒤(town3d) — 북쪽 집 주민에게 차 한 대씩
func _traffic_init() -> void:
	var picks: Array = []
	for r in residents:
		if picks.size() >= COMMUTERS: break
		if r is ResidentKid or r.job != "" or r.home_door.is_empty() or r.own_car != null: continue
		var dp: Vector3 = r.home_door["pos"]
		if (absf(dp.x) < 80.0 and absf(dp.z) < 32.0) or dp.x > 1000.0 or float(Valley.near(Vector2(dp.x, dp.z), 2)[0]) > 25.0: continue   # 옛 마을 밖, 길에서 25m 안 집
		picks.append(r)
	for i in picks.size():
		var r: Resident = picks[i]
		var dp: Vector3 = r.home_door["pos"]
		var park := _free_park(park_at(dp), null)
		var c := _car(KINDS[i % KINDS.size()], park, _road_yaw(park))
		r.own_car = c
		commuters.append({ "r": r, "car": c, "home": park, "phase": "home", "dest": {}, "until": Time.get_ticks_msec() / 1000.0 + randf_range(20.0, 120.0) })
	var drivers: Array = residents.filter(func(x: Resident) -> bool: return not (x is ResidentKid) and x.job == "" and x.own_car == null and not picks.has(x))
	for i in mini(CRUISERS, drivers.size()):   # 큰길 위에 늘어놓고 바로 출발
		var r: Resident = drivers[i]
		var ax := -330.0 + i * 85.0 + (20.0 if absf(-330.0 + i * 85.0) < 90.0 else 0.0)
		var at := Vector3(ax, 0, Valley.main_z(ax) + (1.6 if i % 2 == 0 else -1.6))
		var c := _car(["taxi", "sedan", "delivery", "hatchback", "suv", "sedan", "truck", "hatchback"][i % 8], at, -PI / 2.0 if i % 2 == 0 else PI / 2.0)
		r.drive(c); c.ai = true; c.cruise = 8.0; c.reach = 5.0
		cruisers.append({ "r": r, "car": c, "slow": 0.0 })

## 매 틱(town_social) — 2초마다 볼일 진행
func _traffic_tick(now: float) -> void:
	if now < _traffic_at: return
	_traffic_at = now + 1.0
	if has_method("_signal_tick"): call("_signal_tick")
	if has_method("_streets_tick"): call("_streets_tick")
	for e in cruisers:   # 늘 도는 차 — 다 왔으면 다음 목적지, 오래 막혔으면 다음 경유지로
		var c: Car3D = e["car"]; var r: Resident = e["r"]
		if not is_instance_valid(c) or driving == c or passenger == c or not (is_instance_valid(r) and r.car_seat == c): continue
		if c.rail != null and not c.rail.done: continue
		var d := _pick_dest(r)   # 다 왔거나(밀려나 길을 잃었거나) — 다음 목적지
		_go(c, d.get("park", _free_park(park_at(Vector3(randf_range(-300.0, 300.0), 0, -40.0)), c)), d)
	for e in commuters:
		var r: Resident = e["r"]; var c: Car3D = e["car"]
		if not is_instance_valid(r) or not is_instance_valid(c): continue
		if driving == c or passenger == c:   # 사람이 탔다 — 볼일은 접고 기다린다
			e["phase"] = "home"; e["until"] = now + 60.0; continue
		match String(e["phase"]):
			"home", "there":
				if now < float(e["until"]) or is_night() or r.state in ["chase", "down", "getup", "drive"] or r.has_meta("in_room"): continue
				var dest := _pick_dest(r) if e["phase"] == "home" else { "park": e["home"], "door": r.home_door, "name": "home" }
				if dest.is_empty(): e["until"] = now + 60.0; continue
				e["dest"] = dest; e["phase"] = "to_car"; e["until"] = now + 60.0
				r._release(); r.spot = { "kind": "car", "pos": c.exit_pos() }; r.slot = 0
				r.route = via_bridge(r.global_position, [{ "pos": c.exit_pos(), "act": "" }]); r.target = r.route[0]["pos"]; r.state = "walk"
			"to_car":
				if r.state == "drive" and r.car_seat == c:
					if not e["dest"].has("via"): e["dest"]["park"] = _free_park(dest_park(e), c)   # 빈 자리 — 같은 가게에 차가 겹쳐 서던 것
					c.ai = true; c.cruise = 7.0; c.reach = 5.0; _go(c, dest_park(e), e["dest"])
					e["phase"] = "driving"; e["until"] = now + 120.0
					r.say(["Errands.", "Back in a bit.", "Off to " + String(e["dest"].get("name", "town")) + "."][randi() % 3], 1.6)
				elif now > float(e["until"]):   # 차까지 못 갔다 — 다음에
					e["phase"] = "there" if e["dest"].get("name", "") == "home" else "home"; e["until"] = now + 40.0
			"driving":
				var goal := dest_park(e)
				if c.rail == null or c.rail.lost: _go(c, goal, e["dest"])   # 밀려나 길을 잃었다 — 그 자리에서 다시
				var stop := now > float(e["until"]) or c.rail == null   # 길이 없다·너무 오래 — 여기 세운다
				if stop or c.rail.done:
					_pull_over(c, goal if c.global_position.distance_to(goal) < 8.0 else Vector3.INF)
					c.ai = false; c.route = []; c.rail = null; c.input = { "throttle": 0.0, "steer": 0.0, "brake": true }
					r.leave_car(); r.job = ""
					var dr: Dictionary = e["dest"].get("door", {})
					if not dr.is_empty():
						var dsp := { "kind": "door", "pos": (dr["pos"] as Vector3) + Vector3(0, 0, 0.9), "yaw": PI }
						r.spot = dsp; r.route = via_bridge(r.global_position, [{ "pos": dsp["pos"], "act": "" }]); r.target = r.route[0]["pos"]; r.state = "walk"
					var back: bool = e["dest"].get("name", "") == "home"
					e["phase"] = "home" if back else "there"
					e["until"] = now + (randf_range(120.0, 300.0) if back else randf_range(60.0, 150.0))

## 차선 주행으로 보낸다(car_rail) — 장소면 큰길의 그 장소 길 입구까지 가서 그 길로 꺾는다
func _go(c: Car3D, park: Vector3, dest: Dictionary = {}) -> void:
	var via: Variant = dest.get("via", null)
	var rl: CarRail = null
	if via is Vector3: rl = CarRail.plan(self, c, via as Vector3, [park])
	else:
		var nr: Array = Valley.near(Vector2(park.x, park.z), 2)
		rl = CarRail.plan(self, c, Vector3((nr[1] as Vector2).x, 0, (nr[1] as Vector2).y), [], park)
	c.rail = rl; c.route = []   # 길이 없으면(그 목적지로 이어진 깎인 길이 아직 없다) 서서 다음 틱에 다른 데로
	if rl: rl.cruise = c.cruise

## 길섶에 댄다 — 세울 자리(가까우면)나 지금 길의 길섶으로 1초에 걸쳐 미끄러져 길과 나란히. 차선 위에 세운 차는 뒤차를 영영 세웠다
func _pull_over(c: Car3D, at: Vector3) -> void:
	var p := c.global_position
	if at == Vector3.INF: at = park_at(p)
	at = _free_park(at, c); at.y = p.y
	var yaw := _road_yaw(at)
	if cos(yaw - c.rotation.y) < 0.0: yaw += PI   # 달리던 쪽으로
	var tw := c.create_tween(); tw.set_parallel(true)
	tw.tween_property(c, "global_position", at, 1.0); tw.tween_property(c, "rotation:y", c.rotation.y + wrapf(yaw - c.rotation.y, -PI, PI), 1.0)

## 길 방향(차 rotation.y — 앞이 −z) — 가까운 길 토막을 따라
static func _road_yaw(p: Vector3) -> float:
	var d: Vector2 = Valley.near(Vector2(p.x, p.z), 2)[2]
	return atan2(-d.x, -d.y)

## 이 자리 가까운 길의 길섶 — 길 가운데에서 그 자리 쪽으로 길 폭 반 + 1.6m
static func park_at(door_pos: Vector3) -> Vector3:
	var p := Vector2(door_pos.x, door_pos.z)
	var nr: Array = Valley.near(p, 3)
	if int(nr[4]) < 0: return door_pos
	var q: Vector2 = nr[1]; var d: Vector2 = nr[2]
	var n := Vector2(-d.y, d.x)
	if (p - q).dot(n) < 0.0: n = -n
	var w: float = Valley.roads()[int(nr[4])]["w"]
	var v := q + n * (w / 2.0 + 0.5)   # 길 가장자리에 반쯤 걸쳐(길섶 마당·소품에 박지 않게)
	return Vector3(v.x, 0, v.y)

## 길섶 빈 자리 — 그 자리부터 길 따라 6m 씩 양쪽으로, 다른 차(서 있거나 그리로 가는) 5.5m 안이 아닌 곳
func _free_park(at: Vector3, me: Car3D, _ns := false) -> Vector3:
	var d: Vector2 = Valley.near(Vector2(at.x, at.z), 2)[2]
	for k in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5]:
		var p: Vector3 = at + Vector3(d.x, 0, d.y) * (float(k) * 6.0)
		if float(Valley.near(Vector2(p.x, p.z), 2)[0]) < -0.6: continue   # 다른 길 한가운데(갈림목)
		var q := PhysicsShapeQueryParameters3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(1.8, 1.0, 1.8); q.shape = bx; q.collision_mask = 1
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.8, 0))
		if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty(): continue   # 그 자리에 무엇이 있다(벤치·나무·담)
		var free := true
		for c in cars:
			if c == me: continue
			if (c as Node3D).global_position.distance_to(p) < 5.5: free = false; break
		if free:
			for e in commuters:
				if e["car"] != me and String(e["phase"]) == "driving" and (e["dest"].get("park", Vector3.INF) as Vector3).distance_to(p) < 5.5: free = false; break
		if free: return p
	return at

func dest_park(e: Dictionary) -> Vector3:
	return e["dest"].get("park", e["home"])

## 볼일 고르기 — 가게(열렸든 말든)·관공서·남의 집·장소. 차를 세울 자리는 그 문 앞 길가
func _pick_dest(r: Resident) -> Dictionary:
	var opts: Array = []
	for i in doors.size():
		var dr: Dictionary = doors[i]
		var p: Vector3 = dr["pos"]
		if (absf(p.x) < 80.0 and absf(p.z) < 32.0) or p.x > 1000.0 or dr == r.home_door: continue
		if float(Valley.near(Vector2(p.x, p.z), 2)[0]) > 25.0: continue   # 길에서 먼 집
		var name := "the shops" if dr.has("shop_id") else ("the town hall" if dr.has("civic") else "a friend's")
		opts.append({ "park": park_at(p), "door": dr, "name": name })
	for s in WorldGen.SITES:   # 장소 — 들머리 가까운 길섶에 세우고 걸어간다
		opts.append({ "park": park_at(s["from"]), "door": {}, "name": String(s["name"]) })
	return opts[randi() % opts.size()] if not opts.is_empty() else {}
