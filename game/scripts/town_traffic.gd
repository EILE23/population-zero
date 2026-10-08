class_name TownTraffic
extends TownCabin
## 차로 다니는 주민(운영자 2026-10-08: "차 운전하는 주민도 많아져야지, 지금 차량 보면 왔다 갔다밖에 안 하잖아") —
## 집이 북쪽 블록에 있는 주민 몇에게 자기 차(집 앞 길에 세워 둔다). 낮이면 가끔 볼일을 정한다: 가게·시청·학교·남의 집·탑·호숫가·오두막.
## 차까지 걸어가 타고(주민의 "car" 자리 — 이미 있는 길) → 골목을 따라 가까운 큰길 들목(x 16·96·−104 …, 옛 마을은 지나지 않는다)으로 → 큰길 차선 → 목적지 쪽 들목 → 목적지 길 →
## 세우고 내려 그 문으로 들어간다. 한참 뒤엔 다시 차로 집에 와 세운다. 사람이 그 차를 빼앗으면(차는 사람 것) 그 볼일은 끝
## 큰길만 오가는 택시·배달차(town3d)는 그대로 둔다

const COMMUTERS := 12
const KINDS := ["sedan", "hatchback", "suv", "truck", "sedan", "hatchback"]
const LINKS := [16.0, 96.0, -104.0, 136.0, -144.0, 176.0, -184.0]   # 큰길에서 북쪽 마을로 드는 남북 길(옛 마을 |x|<72 밖이거나 Tower Road)
const EAST_Z := 2.9
const WEST_Z := 1.1

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
		var park := park_at(dp)
		var c := _car(KINDS[i % KINDS.size()], park, PI / 2.0)
		r.own_car = c
		commuters.append({ "r": r, "car": c, "home": park, "phase": "home", "dest": {}, "until": Time.get_ticks_msec() / 1000.0 + randf_range(20.0, 120.0) })
	var drivers: Array = residents.filter(func(x: Resident) -> bool: return not (x is ResidentKid) and x.job == "" and x.own_car == null and not picks.has(x))
	for i in mini(CRUISERS, drivers.size()):   # 큰길 위에 늘어놓고 바로 출발
		var r: Resident = drivers[i]
		var at := Vector3(-150.0 + i * 40.0, 0, EAST_Z if i % 2 == 0 else WEST_Z)
		var c := _car(["taxi", "sedan", "delivery", "hatchback", "suv", "sedan", "truck", "hatchback"][i % 8], at, -PI / 2.0 if i % 2 == 0 else PI / 2.0)
		r.drive(c); c.ai = true; c.cruise = 8.0; c.reach = 5.0
		c.route = _road_route(at, _any_street(r)); c._ri = 0
		cruisers.append({ "r": r, "car": c, "slow": 0.0 })

## 매 틱(town_social) — 2초마다 볼일 진행
func _traffic_tick(now: float) -> void:
	if now < _traffic_at: return
	_traffic_at = now + 2.0
	for e in cruisers:   # 늘 도는 차 — 다 왔으면 다음 목적지, 오래 막혔으면 다음 경유지로
		var c: Car3D = e["car"]; var r: Resident = e["r"]
		if not is_instance_valid(c) or driving == c or passenger == c or not (is_instance_valid(r) and r.car_seat == c): continue
		_unstick(e, c)
		if c._ri >= c.route.size() - 1 and c.global_position.distance_to(c.route[c.route.size() - 1]) < 6.0:
			c.route = _road_route(c.global_position, _any_street(r)); c._ri = 0
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
					c.route = _road_route(c.global_position, dest_park(e)); c._ri = 0; c.ai = true; c.cruise = 7.0; c.reach = 5.0
					e["phase"] = "driving"; e["until"] = now + 120.0
					r.say(["Errands.", "Back in a bit.", "Off to " + String(e["dest"].get("name", "town")) + "."][randi() % 3], 1.6)
				elif now > float(e["until"]):   # 차까지 못 갔다 — 다음에
					e["phase"] = "there" if e["dest"].get("name", "") == "home" else "home"; e["until"] = now + 40.0
			"driving":
				_unstick(e, c)
				var goal := dest_park(e)
				if c.global_position.distance_to(goal) < 4.5 or now > float(e["until"]):
					c.ai = false; c.route = []; c.input = { "throttle": 0.0, "steer": 0.0, "brake": true }
					r.leave_car(); r.job = ""
					var dr: Dictionary = e["dest"].get("door", {})
					if not dr.is_empty():
						var dsp := { "kind": "door", "pos": (dr["pos"] as Vector3) + Vector3(0, 0, 0.9), "yaw": PI }
						r.spot = dsp; r.route = via_bridge(r.global_position, [{ "pos": dsp["pos"], "act": "" }]); r.target = r.route[0]["pos"]; r.state = "walk"
					var back: bool = e["dest"].get("name", "") == "home"
					e["phase"] = "home" if back else "there"
					e["until"] = now + (randf_range(120.0, 300.0) if back else randf_range(60.0, 150.0))

## 문 앞 길에 세울 자리 — 동서 길은 모두 z = OZ + 20k(블록 경계 골목과 블록 가운데 뒷골목), 문 남쪽의 그 줄 한가운데에서 0.9m 비켜(차선)
## 전엔 앞마당 끝(문 앞 3m)에 세워 울타리·나무·가로등 줄을 따라가다 막혔다
static func park_at(door_pos: Vector3) -> Vector3:
	var sz := TownPlan.OZ + ceilf((door_pos.z - TownPlan.OZ + 0.5) / 20.0) * 20.0
	return Vector3(door_pos.x + 2.2, 0, sz + 0.9)

## 4초 넘게 거의 서 있으면(차는 그사이 저절로 뒤로 빼 본다) 다음 경유지로 — 같은 모퉁이에 영영 걸려 있지 않게
func _unstick(e: Dictionary, c: Car3D) -> void:
	var t := float(e.get("slow", 0.0))
	if absf(c.v) < 0.6: t += 2.0
	else: t = 0.0
	if t >= 4.0 and c._ri < c.route.size() - 1: c._ri += 1; t = 0.0
	e["slow"] = t

## 아무 데나 — 지은 집 문 앞 길(옛 마을 밖) 또는 장소 앞
func _any_street(r: Resident) -> Vector3:
	var d := _pick_dest(r)
	return d.get("park", Vector3(randf_range(-140.0, 140.0), 0, EAST_Z)) if not d.is_empty() else Vector3(randf_range(-140.0, 140.0), 0, EAST_Z)

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
		opts.append({ "park": c + (Vector3(s["from"].x - c.x, 0, s["from"].z - c.z).normalized() * (float(s["r"]) + 3.0)), "door": {}, "name": String(s["name"]), "via": s["from"] })
	return opts[randi() % opts.size()] if not opts.is_empty() else {}

## 길 — 지금 자리 → 가까운 들목 길로 → 큰길 차선 → 목적지 쪽 들목 → 목적지. 북쪽 마을의 골목(동서)은 지금 자리의 z 를 그대로 탄다
func _road_route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var la := _link_near(from.x, from.z); var lb := _link_near(to.x, to.z)
	var via: Variant = _via_of(to)
	if via is Vector3: lb = (via as Vector3).x   # 장소(탑·호숫가·오두막·산 들머리)는 그 장소로 난 길로 — 그 길은 깎여 있다
	var east := lb > la
	var lane := EAST_Z if east else WEST_Z
	var pts: Array[Vector3] = []
	if absf(from.z - 2.0) > 20.0: pts.append(Vector3(la, 0, from.z))
	pts.append(Vector3(la, 0, lane))
	if absf(lb - la) > 1.0: pts.append(Vector3(lb, 0, lane))
	if via is Vector3: pass
	elif absf(to.z - 2.0) > 20.0: pts.append(Vector3(lb, 0, to.z))
	pts.append(to)
	return pts

## 가까운 들목 — 큰길에서 그 z 까지 땅이 깎여 있는(차가 달릴 수 있는) 남북 길만. 남쪽은 Tower Road(x 16)가 없다(옛 마을 남쪽은 강·공원)
## 전엔 깎이지 않은 언덕 위 들목(x −104)으로 들어가 칸이 없는 데서 서 버렸다(2026-10-08)
func _link_near(x: float, z: float) -> float:
	var best := 1e9
	for l in LINKS:
		if z > 0.0 and absf(float(l)) < 72.0: continue
		if not _link_ok(float(l), z): continue
		if absf(float(l) - x) < absf(best - x): best = l
	return best if best < 1e8 else 16.0

func _link_ok(x: float, z: float) -> bool:
	for k in 7:
		var zz := lerpf(2.0, z, k / 6.0)
		if gen.wild_k(x, zz) > 0.05: return false
	return true

## 장소로 가는 길(WorldGen.SITES from) — 목적지가 장소면 그 길 입구
func _via_of(to: Vector3) -> Variant:
	for s in WorldGen.SITES:
		var c: Vector3 = s["c"]
		if Vector2(to.x - c.x, to.z - c.z).length() < float(s["r"]) + 6.0: return s["from"]
	return null
