class_name TownTraffic
extends TownCabin
## 차로 다니는 주민(운영자 2026-10-08: "차 운전하는 주민도 많아져야지, 지금 차량 보면 왔다 갔다밖에 안 하잖아") —
## 집이 북쪽 블록에 있는 주민 몇에게 자기 차(집 앞 길에 세워 둔다). 낮이면 가끔 볼일을 정한다: 가게·시청·학교·남의 집·탑·호숫가·오두막.
## 차까지 걸어가 타고(주민의 "car" 자리 — 이미 있는 길) → 골목 격자를 차선 주행(car_rail — 오른쪽 차선·둥근 모퉁이·앞차 간격·교차로 양보) →
## 목적지 길섶에 대고 내려 그 문으로 들어간다. 한참 뒤엔 다시 차로 집에 와 세운다. 사람이 그 차를 빼앗으면(차는 사람 것) 그 볼일은 끝
## 하루(운영자 2026-10-19: "차도 타고 다니고, 타고 내렸다가 집도 가고, 일하다가 자러 가기도"): 차 있는 주민은 일터가 있다(가게·공방·관공서).
##   아침(6~7.5시 사이 저마다) 차로 출근 → 일터 앞에 대고 걸어가 일한다(안으로 들어가거나 가게 앞·공방 마당에서) → 오후(14~15시) 차로 퇴근, 셋에 하나는 가게에 들렀다
##   → 집 앞에 대고 집으로 → 저녁은 마음대로 → 밤엔 제 침대(resident _pick_spot). 하루에 한 번 출근(밤이 지나면 다시)

const COMMUTERS := 30
const KINDS := ["sedan", "hatchback", "suv", "truck", "sedan", "hatchback"]
const EAST_Z := 2.9
const WEST_Z := 1.1
const VERGE := 2.6                # 갓길 주차 — 길 가운데에서(아스팔트 끝 3.35 안, 차선 차와 0.6m 틈)

var commuters: Array = []   # [{r, car, home: Vector3, phase, dest, until}]
var workplaces: Array = []  # [{door, park, name, spot: {kind "work", pos, yaw, inside, pose}}]
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
	_find_workplaces()
	for i in picks.size():
		var r: Resident = picks[i]
		var dp: Vector3 = r.home_door["pos"]
		var park := _free_park(park_at(dp), null)
		var c := _car(KINDS[i % KINDS.size()], park, _road_yaw(park))
		r.own_car = c
		commuters.append({ "r": r, "car": c, "home": park, "phase": "home", "dest": {}, "until": Time.get_ticks_msec() / 1000.0 + randf_range(20.0, 120.0),
			"work": _work_for(dp, i, c), "go_h": 5.8 + fmod(float(r.uid) * 0.37, 1.2), "back_h": 13.4 + fmod(float(r.uid) * 0.53, 1.0), "went": false })
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
	for e in cruisers:   # 늘 도는 차 — 다 왔으면 둘에 하나는 세우고 내려 그 문에 들렀다(배달·손님 내려 주기) 다시 타고, 아니면 다음 목적지
		var c: Car3D = e["car"]; var r: Resident = e["r"]
		if not is_instance_valid(c) or not is_instance_valid(r) or driving == c or passenger == c: continue
		if String(e.get("st", "")) == "out":   # 내려서 문에 들르는 중 — 제 차로 돌아와 타면(resident _back_to_car) 다시 간다. 너무 오래면 차로 부른다
			if r.state == "drive" and r.car_seat == c:
				e["st"] = ""; c.ai = true; c.cruise = 8.0; c.reach = 5.0
			elif now > float(e.get("until", 0.0)) and r.state in ["busy", "routine"]:
				r._release(); r.spot = { "kind": "car" }; r.route = via_bridge(r.global_position, [{ "pos": c.exit_pos(), "act": "" }]); r.target = r.route[0]["pos"]; r.state = "walk"; e["until"] = now + 40.0
			elif now > float(e.get("until", 0.0)) + 40.0 and r.global_position.distance_to(c.global_position) < 12.0: r.drive(c)
			continue
		if r.car_seat != c: continue
		if c.rail != null and not c.rail.done: continue
		var dr: Dictionary = e.get("dest", {}).get("door", {})
		if c.rail != null and not c.rail.lost and not dr.is_empty() and not is_night() and randf() < 0.5:   # 세우고 내린다
			_pull_over(c, Vector3.INF)
			c.ai = false; c.rail = null; c.route = []; c.input = { "throttle": 0.0, "steer": 0.0, "brake": true }
			r.leave_car()
			var dsp := { "kind": "door", "pos": (dr["pos"] as Vector3) + Vector3(0, 0, 0.9), "yaw": PI }
			r.spot = dsp; r.route = via_bridge(r.global_position, [{ "pos": dsp["pos"], "act": "" }]); r.target = r.route[0]["pos"]; r.state = "walk"
			r.say(["Delivery.", "One parcel.", "Back in a minute.", "Sign here, please."][randi() % 4], 1.6)
			e["st"] = "out"; e["until"] = now + 45.0
			continue
		var d := _pick_dest(r)   # 다 왔거나(밀려나 길을 잃었거나) — 다음 목적지
		e["dest"] = d
		_go(c, d.get("park", _free_park(park_at(Vector3(randf_range(-300.0, 300.0), 0, -40.0)), c)), d)
	for e in commuters:
		var r: Resident = e["r"]; var c: Car3D = e["car"]
		if not is_instance_valid(r) or not is_instance_valid(c): continue
		if driving == c or passenger == c:   # 사람이 탔다 — 볼일은 접고 기다린다
			e["phase"] = "home"; e["until"] = now + 60.0; continue
		var h := fmod(clock * 24.0 + 6.0, 24.0)
		if h < 5.0: e["went"] = false   # 밤이 지나면 다시 출근할 날
		match String(e["phase"]):
			"home", "there":
				if r.state in ["chase", "down", "getup", "drive"] or r.has_meta("in_room"): continue
				var dest := {}
				var name := String(e["dest"].get("name", ""))
				if e["phase"] == "home":
					if not e["went"] and not e["work"].is_empty() and h >= float(e["go_h"]) and h < 12.0:   # 출근
						dest = e["work"]; e["went"] = true
					elif now < float(e["until"]) or is_night() or e["went"] == false and h < 12.0: continue
					else: dest = _pick_dest(r)   # 퇴근 뒤 저녁 볼일(가끔)
				elif name == "work":
					if h < float(e["back_h"]) and not is_night(): continue
					r.remove_meta("work"); r.remove_meta("work_until")
					dest = { "park": e["home"], "door": r.home_door, "name": "home" }
					if r.uid % 3 == 0 and not is_night():   # 셋에 하나는 가게에 들렀다 간다
						var sh := workplaces.filter(func(w: Dictionary) -> bool: return String(w["name"]) == "the shops")
						if not sh.is_empty(): dest = sh[r.uid % sh.size()].duplicate(); dest.erase("spot")
				else:
					if now < float(e["until"]) and not is_night(): continue
					dest = { "park": e["home"], "door": r.home_door, "name": "home" }
				if dest.is_empty(): e["until"] = now + 60.0; continue
				e["dest"] = dest; e["phase"] = "to_car"; e["until"] = now + 30.0 + r.global_position.distance_to(c.global_position) / 1.2   # 걸어서 닿을 만큼
				if not r.visible: r.visible = true; r.collision_layer = 4; r.collision_mask = 7   # 일터 안에서 나온다
				r._release(); r.spot = { "kind": "car", "pos": c.exit_pos() }; r.slot = 0
				r.route = via_bridge(r.global_position, [{ "pos": c.exit_pos(), "act": "" }]); r.target = r.route[0]["pos"]; r.state = "walk"
			"to_car":
				if r.state != "drive" and c.driver == null and r.global_position.distance_to(c.global_position) < 7.5 and r.state in ["walk", "routine"]: r.drive(c)   # 차 곁까지 왔다 — 문 쪽이 담·생울타리에 막혀 내리는 자리에 못 닿아 퇴근을 못 했다
				if r.state == "drive" and r.car_seat == c:
					if not e["dest"].has("via"): e["dest"]["park"] = _free_park(dest_park(e), c)   # 빈 자리 — 같은 가게에 차가 겹쳐 서던 것
					c.ai = true; c.cruise = 9.0; c.reach = 5.0; e["lost_n"] = 0; _go(c, dest_park(e), e["dest"])
					e["phase"] = "driving"; e["until"] = now + 120.0
					r.say(["Errands.", "Back in a bit.", "Off to " + String(e["dest"].get("name", "town")) + "."][randi() % 3], 1.6)
				elif now > float(e["until"]):   # 차까지 못 갔다 — 다음에
					e["phase"] = "there" if e["dest"].get("name", "") == "home" else "home"; e["until"] = now + 40.0
			"driving":
				var goal := dest_park(e)
				if c.rail == null or c.rail.lost:   # 밀려나 길을 잃었다 — 그 자리에서 다시. 세 번째마다 가까운 길 가운데로 옮겨 놓고(길섶에서 같은 데 걸려 되풀이했다)
					e["lost_n"] = int(e.get("lost_n", 0)) + 1
					if int(e["lost_n"]) % 3 == 0: _unstick(c)
					_go(c, goal, e["dest"])
				var stop := now > float(e["until"]) or c.rail == null   # 길이 없다·너무 오래 — 여기 세운다
				if stop or c.rail.done:
					_pull_over(c, goal if c.global_position.distance_to(goal) < 8.0 else Vector3.INF)
					c.ai = false; c.route = []; c.rail = null; c.input = { "throttle": 0.0, "steer": 0.0, "brake": true }
					r.leave_car(); r.job = ""
					var dr: Dictionary = e["dest"].get("door", {})
					var ws: Dictionary = e["dest"].get("spot", {})
					if not ws.is_empty():   # 일터 — 걸어가 일한다(resident _pick_spot 이 퇴근까지 그 자리로 돌려보낸다)
						r.set_meta("work", ws); r.set_meta("work_until", now + 60.0 + maxf(30.0, (float(e["back_h"]) - fmod(clock * 24.0 + 6.0, 24.0)) * DAY_LEN / 24.0))   # 퇴근 부름(back_h)보다 1분 늦게 끝난다 — 먼저 끝나면 딴 데로 걸어가 차에서 150m 떨어졌다
						r.spot = ws; r.route = via_bridge(r.global_position, [{ "pos": ws["pos"], "act": "" }]); r.target = r.route[0]["pos"]; r.state = "walk"
						r.say(["Work.", "Right. Work.", "Clocking in."][r.uid % 3], 1.4)
					elif not dr.is_empty():
						var dsp := { "kind": "door", "pos": (dr["pos"] as Vector3) + Vector3(0, 0, 0.9), "yaw": PI }
						r.spot = dsp; r.route = via_bridge(r.global_position, [{ "pos": dsp["pos"], "act": "" }]); r.target = r.route[0]["pos"]; r.state = "walk"
					var back: bool = e["dest"].get("name", "") == "home"
					e["phase"] = "home" if back else "there"
					e["until"] = now + (randf_range(120.0, 300.0) if back else randf_range(30.0, 60.0))

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
		var q := PhysicsShapeQueryParameters3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(2.0, 1.0, 4.6); q.shape = bx; q.collision_mask = 1   # 차 크기 그대로, 길 따라 — 1.8m 네모라 가로등 기둥 옆에 바짝 댔다
		q.transform = Transform3D(Basis(Vector3.UP, atan2(-d.x, -d.y)), p + Vector3(0, 0.8, 0))
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

## 일터 — 가게(문 앞에서 거들거나 안으로)·공방(마당에서 고친다)·관공서(안으로). 차는 그 문 앞 길섶에
func _find_workplaces() -> void:
	workplaces.clear()
	for dr in doors:
		var p: Vector3 = dr["pos"]
		if p.x > 1000.0 or float(Valley.near(Vector2(p.x, p.z), 2)[0]) > 25.0: continue
		var kind := "the shops" if dr.has("shop_id") else ("the town hall" if dr.has("civic") else ("the garage" if dr.has("garage") else ""))
		if kind == "": continue
		var sp := { "kind": "work", "pos": p + Vector3(0, 0, 0.9), "yaw": PI, "inside": true, "pose": "" }
		if kind == "the garage": sp = { "kind": "work", "pos": p + Vector3(2.4, 0, 1.4), "yaw": PI / 2.0, "inside": false, "pose": "fix" }
		workplaces.append({ "park": park_at(p), "door": dr, "name": kind, "spot": sp })

## 이 집의 일터 — 곧은 거리로 가까운 여섯 중 차 길이 가장 짧은 데(곧은 거리로만 고르니 강·막다른 골목을 돌아 길이 여섯 배였다, 2026-10-26).
## 한 일터에 넷 넘게 몰리면 다음으로
var _work_load := {}
func _work_for(home: Vector3, _i: int, c: Car3D = null) -> Dictionary:
	if workplaces.is_empty(): return {}
	var near := workplaces.duplicate()
	near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["door"]["pos"] as Vector3).distance_to(home) < (b["door"]["pos"] as Vector3).distance_to(home))
	var best: Dictionary = {}; var bl := 1e9
	for w0 in near.slice(0, 6):
		var w: Dictionary = w0
		var load := int(_work_load.get(w["door"]["pos"], 0))
		var L: float = (w["door"]["pos"] as Vector3).distance_to(home) * 3.0
		if c != null:
			var nr: Array = Valley.near(Vector2((w["park"] as Vector3).x, (w["park"] as Vector3).z), 2)
			var rl := CarRail.plan(self, c, Vector3((nr[1] as Vector2).x, 0, (nr[1] as Vector2).y))
			if rl == null: continue
			L = rl.lane.size() * 1.5
		L += maxf(0.0, load - 3) * 150.0
		if L < bl: bl = L; best = w
	if best.is_empty(): best = near[0]
	_work_load[best["door"]["pos"]] = int(_work_load.get(best["door"]["pos"], 0)) + 1
	var w: Dictionary = best.duplicate()
	w["place"] = w["name"]; w["name"] = "work"
	return w

## 낀 차를 길로 — 가까운 길 가운데 오른쪽 차선 위, 길 방향으로(보는 사람이 가까우면 안 한다)
func _unstick(c: Car3D) -> void:
	if c.global_position.distance_to(body.global_position) < 40.0: return
	var nr: Array = Valley.near(Vector2(c.global_position.x, c.global_position.z), 2)
	if int(nr[4]) < 0: return
	var q: Vector2 = nr[1]; var d: Vector2 = nr[2]
	var yaw := atan2(-d.x, -d.y)
	if cos(yaw - c.rotation.y) < 0.0: d = -d; yaw += PI
	var at := q + Vector2(-d.y, d.x) * 1.2   # 오른쪽 차선(car_rail _right 와 같은 쪽)
	c.global_position = Vector3(at.x, float(nr[3]) + 0.3, at.y); c.rotation.y = yaw; c.v = 0.0; c.velocity = Vector3.ZERO
