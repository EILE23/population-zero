class_name TownTraffic
extends TownCabin
## 차로 다니는 주민(운영자 2026-10-08: "차 운전하는 주민도 많아져야지, 지금 차량 보면 왔다 갔다밖에 안 하잖아") —
## 집이 북쪽 블록에 있는 주민 몇에게 자기 차(집 앞 길에 세워 둔다). 낮이면 가끔 볼일을 정한다: 가게·시청·학교·남의 집·탑·호숫가·오두막.
## 차까지 걸어가 타고(주민의 "car" 자리 — 이미 있는 길) → 골목 격자를 차선 주행(car_rail — 오른쪽 차선·둥근 모퉁이·앞차 간격·교차로 양보) →
## 목적지 길섶에 대고 내려 그 문으로 들어간다. 한참 뒤엔 다시 차로 집에 와 세운다. 사람이 그 차를 빼앗으면(차는 사람 것) 그 볼일은 끝

const COMMUTERS := 12
const KINDS := ["sedan", "hatchback", "suv", "truck", "sedan", "hatchback"]
const LINKS := [16.0, 96.0, -104.0, 136.0, -144.0, 176.0, -184.0]   # 큰길에서 북쪽 마을로 드는 남북 길(옛 마을 |x|<72 밖이거나 Tower Road)
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
		if absf(dp.z - 2.0) < 30.0 or absf(dp.x) > 200.0 or dp.x > 1000.0: continue   # 옛 마을 밖 블록(남쪽은 다리로 강을 건넌다)
		picks.append(r)
	for x in LINKS:   # 들목마다 강 위 다리(낮은 판 + 난간 — 차는 그대로 건넌다)
		if absf(float(x)) < 72.0: continue
		var keep := _build_parent; var at := Vector3(float(x), 0, RIVER_Z); _build_parent = _root_for(at)
		_box(Vector3(5.0, 0.04, RIVER_HW * 2.0 + 3.0), at, _mat(Color("b8b0aa")), false)
		for sx in [-2.6, 2.6]: _box(Vector3(0.12, 0.8, RIVER_HW * 2.0 + 3.0), at + Vector3(sx, 0, 0), _mat(Color("8a7f86")), false)
		_build_parent = keep
	for i in picks.size():
		var r: Resident = picks[i]
		var dp: Vector3 = r.home_door["pos"]
		var park := _free_park(park_at(dp), null)
		var c := _car(KINDS[i % KINDS.size()], park, PI / 2.0)
		r.own_car = c
		commuters.append({ "r": r, "car": c, "home": park, "phase": "home", "dest": {}, "until": Time.get_ticks_msec() / 1000.0 + randf_range(20.0, 120.0) })
	var drivers: Array = residents.filter(func(x: Resident) -> bool: return not (x is ResidentKid) and x.job == "" and x.own_car == null and not picks.has(x))
	for i in mini(CRUISERS, drivers.size()):   # 큰길 위에 늘어놓고 바로 출발
		var r: Resident = drivers[i]
		var at := Vector3(-150.0 + i * 40.0, 0, EAST_Z if i % 2 == 0 else WEST_Z)
		var c := _car(["taxi", "sedan", "delivery", "hatchback", "suv", "sedan", "truck", "hatchback"][i % 8], at, -PI / 2.0 if i % 2 == 0 else PI / 2.0)
		r.drive(c); c.ai = true; c.cruise = 8.0; c.reach = 5.0
		cruisers.append({ "r": r, "car": c, "slow": 0.0 })

## 매 틱(town_social) — 2초마다 볼일 진행
func _traffic_tick(now: float) -> void:
	if now < _traffic_at: return
	_traffic_at = now + 1.0
	if has_method("_signal_tick"): call("_signal_tick")
	for e in cruisers:   # 늘 도는 차 — 다 왔으면 다음 목적지, 오래 막혔으면 다음 경유지로
		var c: Car3D = e["car"]; var r: Resident = e["r"]
		if not is_instance_valid(c) or driving == c or passenger == c or not (is_instance_valid(r) and r.car_seat == c): continue
		if c.rail != null and not c.rail.done: continue
		var d := _pick_dest(r)   # 다 왔거나(밀려나 길을 잃었거나) — 다음 목적지
		_go(c, d.get("park", Vector3(randf_range(-140.0, 140.0), 0, EAST_Z)), d)
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
	if via is Vector3: rl = CarRail.plan(self, c, Vector3((via as Vector3).x, 0, WorldGen.ROAD_Z), [park])
	else: rl = CarRail.plan(self, c, Vector3(park.x, 0, park.z - VERGE), [], park)
	c.rail = rl; c.route = []   # 길이 없으면(그 목적지로 이어진 깎인 길이 아직 없다) 서서 다음 틱에 다른 데로
	if rl: rl.cruise = c.cruise

## 길섶에 댄다 — 세울 자리(가까우면)나 지금 길의 길섶으로 1초에 걸쳐 미끄러져 길과 나란히. 차선 위에 세운 차는 뒤차를 영영 세웠다
func _pull_over(c: Car3D, at: Vector3) -> void:
	var p := c.global_position
	var ax := absf(sin(c.rotation.y)) > 0.7   # 동서로 서 있다
	var ns := false
	if at == Vector3.INF:
		var s: Array = CarRail._seg_of(p)
		ns = (s[0] as Vector2i).y != (s[1] as Vector2i).y
		var mid: Vector3 = s[2]
		at = Vector3(p.x, p.y, mid.z + (VERGE if p.z >= mid.z else -VERGE)) if (s[0] as Vector2i).y == (s[1] as Vector2i).y else Vector3(mid.x + (VERGE if p.x >= mid.x else -VERGE), p.y, p.z)
	at = _free_park(at, c, ns); at.y = p.y
	var yaw := (PI / 2.0 if sin(c.rotation.y) > 0.0 else -PI / 2.0) if ax else (0.0 if cos(c.rotation.y) > 0.0 else PI)
	var tw := c.create_tween(); tw.set_parallel(true)
	tw.tween_property(c, "global_position", at, 1.0); tw.tween_property(c, "rotation:y", c.rotation.y + wrapf(yaw - c.rotation.y, -PI, PI), 1.0)

## 문 앞 길에 세울 자리 — 동서 길은 모두 z = OZ + 20k(블록 경계 골목과 블록 가운데 뒷골목), 문 남쪽 그 줄의 길섶
static func park_at(door_pos: Vector3) -> Vector3:
	var sz := TownPlan.OZ + ceilf((door_pos.z - TownPlan.OZ + 0.5) / 20.0) * 20.0
	if TownPlan.no_lane(CityMap.block_of(Vector2(door_pos.x, door_pos.z))) and fposmod(sz - TownPlan.OZ, TownPlan.PITCH) > 1.0: sz += 20.0   # 안마당 블록 — 가운데 찻길이 없어 남쪽 찻길에
	var x := door_pos.x + 2.2
	var gx := TownPlan.OX + roundf((x - TownPlan.OX) / TownPlan.PITCH) * TownPlan.PITCH
	if absf(x - gx) < 7.0: x = gx + 7.0 * (1.0 if x >= gx else -1.0)   # 남북 길 들목은 비운다 — 거기 세우면 남북 차선을 막았다
	return Vector3(x, 0, sz + VERGE)   # 길섶(골목 반폭 1.6 밖, 차 반폭 0.7 + 틈) — 차선(±0.8)을 막지 않게(car_rail 차가 세운 차 뒤에서 영영 섰다)

## 길섶 빈 자리 — 그 자리부터 길 따라 6m 씩 양쪽으로, 다른 차(서 있거나 그리로 가는) 5.5m 안이 아니고 남북 길 들목이 아닌 곳.
## 전엔 3.4m 간격으로 붙여 세워 가운데 차가 앞차에 막혀 못 빠져나왔다
func _free_park(at: Vector3, me: Car3D, ns := false) -> Vector3:
	for k in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6]:
		var p := at + (Vector3(0, 0, k * 6.0) if ns else Vector3(k * 6.0, 0, 0))   # 남북 길섶이면 z 로
		if ns:
			var gz := TownPlan.OZ + roundf((p.z - TownPlan.OZ) / 20.0) * 20.0
			if absf(p.z - gz) < 7.0: continue
		else:
			var gx := TownPlan.OX + roundf((p.x - TownPlan.OX) / TownPlan.PITCH) * TownPlan.PITCH
			if absf(p.x - gx) < 7.0: continue
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
		if absf(p.z - 2.0) < 30.0 or p.x > 1000.0 or absf(p.x) > 200.0 or dr == r.home_door: continue
		var name := "the shops" if dr.has("shop_id") else ("the town hall" if dr.has("civic") else "a friend's")
		opts.append({ "park": park_at(p), "door": dr, "name": name })
	for s in WorldGen.SITES:
		var c: Vector3 = s["c"]
		var fr: Vector3 = s["from"]
		if absf(fr.x) < WorldGen.HUB_X + 2.0:   # 옛 마을 안에서 드는 길(탑·산) — 큰길 길섶에 세우고 걸어간다
			opts.append({ "park": Vector3(fr.x + 3.0, 0, WorldGen.ROAD_Z + VERGE), "door": {}, "name": String(s["name"]) })
		else: opts.append({ "park": c + (Vector3(fr.x - c.x, 0, fr.z - c.z).normalized() * (float(s["r"]) + 3.0)), "door": {}, "name": String(s["name"]), "via": fr })
	return opts[randi() % opts.size()] if not opts.is_empty() else {}
