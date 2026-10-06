class_name TownGrowth
extends TownLedger
## 마을이 자란다(운영자 2026-10-06: "가짜 도시는 없어 다 진짜여야 해, 모든 집들은 다 동작해야 하고", "빌딩을 실제로 짓는 건축가들").
## 도시계획(town_plan.gd)의 필지를 순서대로 — 건축가 주민(job "builder", 노란 모자) 둘이 공사장에 출근해 망치질한다(hammer 자세, 한 번에 25초 = 일 한 단위).
## 단계: 0 말뚝·끈·판자 더미 → 1 바닥 → 2 기둥·보 → 3 벽 → 4 지붕 틀 → 완성: 마을의 다른 집과 같은 진짜 집(_house: 문, 실내, 계단·컷어웨이)이 서고
## 명부의 다음 주민이 입주한다(그 문이 집, 밤엔 거기서 잔다). 필지 앞 골목은 공사가 시작될 때 깔리고, 땅이 산이면 블록째 평평하게 깎인다(WorldGen).
## 진행은 user://growth.json — 꺼 둔 동안 흐른 시간만큼도 자라 있다(한 번에 최대 OFFLINE_MAX 채). 공사장 곁엔 구경 자리가 있어 지나가던 주민이 멈춰 본다

const GROWTH := "user://growth.json"
const SITES_AT_ONCE := 2       # 동시에 짓는 공사장 수
const STAGE_WORK := 4          # 한 단계에 필요한 일 단위(건축가 한 명 25초)
const WORK_T := 25.0
const OFFLINE_HOUSE_S := 240.0 # 꺼 둔 동안 이만큼마다 한 채
const OFFLINE_MAX := 12
const RES_MAX := 90            # 몸이 있는 주민 상한 — 넘으면 입주는 하되 집에 불만 켜진다(성능)

var built := 0                 # 지은 필지 수(순번 0..built-1)
var site_work := {}            # 순번 -> 쌓인 일(0 .. 5·STAGE_WORK)
var _site_nodes := {}          # 순번 -> 공사장 노드
var _built_root: Node3D
var _paved := {}               # 깔린 골목 토막
var _roster: Array = []

func _growth_init() -> void:
	_economy_init()
	var f := FileAccess.open("res://data/residents.json", FileAccess.READ)
	if f: _roster = (JSON.parse_string(f.get_as_text()) as Dictionary).get("residents", [])
	_built_root = Node3D.new(); _built_root.name = "Built"; add_child(_built_root)
	var g := FileAccess.open(GROWTH, FileAccess.READ)
	var saved_t := 0.0
	if g:
		var d: Variant = JSON.parse_string(g.get_as_text())
		if d is Dictionary:
			built = int(d.get("built", 0)); saved_t = float(d.get("t", 0.0))
			for k in (d.get("work", {}) as Dictionary): site_work[int(k)] = float(d["work"][k])
	built = maxi(built, CityMap.founded())   # 기본 마을 — 처음부터 이만큼은 지어져 있다(운영자 2026-10-06: 탑 가는 길에 아무것도 없다, data/map/town.json)
	if saved_t > 0.0 and not _tool_run():   # 꺼 둔 동안
		var gained := mini(OFFLINE_MAX, int((Time.get_unix_time_from_system() - saved_t) / OFFLINE_HOUSE_S))
		built += gained
		if gained > 0: get_tree().create_timer(2.0).timeout.connect(func() -> void: say_toast("While you were away the builders finished %d house%s." % [gained, "" if gained == 1 else "s"]))
	gen.flat_limit = built + SITES_AT_ONCE
	if built > 0: gen.rebuild_all(body.global_position)   # 지은 집 블록이 평지가 되게 칸을 다시(처음 칸은 성장 상태를 읽기 전에 지어졌다)
	var lots := TownPlan.lots()
	for k in mini(built, lots.size()): _finish_lot(lots[k], false)
	_hire_builders()
	_open_sites()

func _tool_run() -> bool:
	return DisplayServer.get_name() == "headless" or "-s" in OS.get_cmdline_args() or "--script" in OS.get_cmdline_args() or "--sheet" in OS.get_cmdline_user_args()

func _save_growth() -> void:
	if _tool_run(): return
	var w := {}
	for k in site_work: w[str(k)] = site_work[k]
	var f := FileAccess.open(GROWTH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({ "built": built, "work": w, "t": Time.get_unix_time_from_system() }))

## 건축가 둘 — 일자리 없는 어른 중 배짱 있는 사람(노란 모자). 이미 있으면 그대로
func _hire_builders() -> void:
	var have := residents.filter(func(r: Resident) -> bool: return r.job == "builder").size()
	for r in residents:
		if have >= 2: break
		if r.job != "" or r is ResidentKid or r.state == "drive": continue
		r.job = "builder"; r.fig.wear(Wear.make("cap", Color("f2c84b"))); have += 1

## 다음 공사장들 — 순번 built .. built+SITES_AT_ONCE-1
func _open_sites() -> void:
	var lots := TownPlan.lots()
	for k in range(built, mini(built + SITES_AT_ONCE, lots.size())):
		if _site_nodes.has(k): continue
		if gen.flat_limit < k + 1:
			gen.flat_limit = k + SITES_AT_ONCE; gen.reflat(lots[k]["c"])   # 산 위의 필지면 블록째 깎는다
		_pave(lots[k])
		_site_nodes[k] = Node3D.new(); _built_root.add_child(_site_nodes[k])
		_draw_site(k)

## 공사장 모습 — 단계마다 하나씩 더해진다
func _draw_site(k: int) -> void:
	var n: Node3D = _site_nodes[k]
	for c in n.get_children(): c.queue_free()
	var l: Dictionary = TownPlan.lots()[k]
	var c := Vector3(l["c"].x, 0, l["c"].y)
	var sp := TownPlan.house_spec(l); var s: Vector3 = sp["size"]
	var stage := int(float(site_work.get(k, 0.0)) / STAGE_WORK)
	var wood := _mat(Color("b48a5a")); var dark := _mat(Color("6b4a35"))
	for cx in [-1.0, 1.0]:   # 말뚝 넷과 끈
		for cz in [-1.0, 1.0]: _box(Vector3(0.08, 0.6, 0.08), c + Vector3(cx * (s.x / 2.0 + 0.5), 0, cz * (s.z / 2.0 + 0.5)), dark, false, n)
	for i in 4: _box(Vector3(2.2, 0.08, 0.3), c + Vector3(s.x / 2.0 + 1.8, 0.08 * i, s.z / 2.0 - 0.3 - (i % 2) * 0.35), wood, false, n)   # 판자 더미
	if stage >= 1: _box(Vector3(s.x, 0.18, s.z), c, _mat(Color("bfb6b0")), true, n)   # 바닥
	if stage >= 2:
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]: _box(Vector3(0.16, s.y, 0.16), c + Vector3(cx * (s.x / 2.0 - 0.1), 0.18, cz * (s.z / 2.0 - 0.1)), wood, false, n)
		for cz in [-1.0, 1.0]: _box(Vector3(s.x, 0.14, 0.14), c + Vector3(0, s.y + 0.1, cz * (s.z / 2.0 - 0.1)), wood, false, n)
	if stage >= 3:
		_box(Vector3(s.x - 0.3, s.y * 0.7, 0.12), c + Vector3(0, 0.18, -s.z / 2.0 + 0.1), _mat(sp["wall"]), false, n)
		for sx in [-1.0, 1.0]: _box(Vector3(0.12, s.y * 0.55, s.z - 0.3), c + Vector3(sx * (s.x / 2.0 - 0.1), 0.18, 0), _mat(sp["wall"]), false, n)
		for i in 3: _box(Vector3(0.06, s.y + 0.6, 0.06), c + Vector3(-s.x / 2.0 - 0.6 + i * 0.05, 0, s.z / 2.0 + 0.6), _mat(Color("8a8a92")), false, n)   # 비계
	if stage >= 4:
		for i in 5:
			var rafter := _box(Vector3(0.1, 0.1, s.z + 0.4), c + Vector3(-s.x / 2.0 + i * s.x / 4.0, s.y + 0.45 + (0.5 - absf(i - 2) * 0.25), 0), wood, false, n)
	var lb := Label3D.new(); lb.text = "Building — %d%%" % int(100.0 * float(site_work.get(k, 0.0)) / (STAGE_WORK * 5.0)); lb.font_size = 48; lb.pixel_size = 0.004
	lb.modulate = Color("1b0c15"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef"); lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = c + Vector3(0, s.y + 1.6, 0); n.add_child(lb)

## 건축가가 일할 자리 — 짓는 중인 공사장 앞(문 쪽), 칸 둘. 없으면 {}
func build_spot(r: ResidentBase) -> Dictionary:
	var best: Dictionary = {}; var bd := 1e9
	for k in _site_nodes:
		var l: Dictionary = TownPlan.lots()[k]
		var sp: Dictionary = _site_nodes[k].get_meta("spot", {})
		if sp.is_empty():
			var s: Vector3 = TownPlan.house_spec(l)["size"]
			sp = { "pos": Vector3(l["c"].x, 0, l["c"].y + s.z / 2.0 + 0.9), "kind": "build", "yaw": PI, "lot": k }
			_site_nodes[k].set_meta("spot", sp)
		var d: float = r.global_position.distance_to(sp["pos"])
		if r._free_slot(sp) >= 0 and d < bd: bd = d; best = sp
	return best

## 일 한 단위(건축가 25초) — 단계가 오르면 모습이 바뀌고, 다 쌓이면 집이 선다
func build_work(sp: Dictionary) -> void:
	var k: int = sp["lot"]
	if not _site_nodes.has(k): return
	var before := int(float(site_work.get(k, 0.0)) / STAGE_WORK)
	site_work[k] = float(site_work.get(k, 0.0)) + 1.0
	var after := int(float(site_work[k]) / STAGE_WORK)
	if after >= 5:
		(_site_nodes[k] as Node3D).queue_free(); _site_nodes.erase(k); site_work.erase(k)
		_finish_lot(TownPlan.lots()[k], true)
		while built < TownPlan.lots().size() and (built in _done_set()): built += 1
		_open_sites()
	else:
		_draw_site(k)
	_save_growth()

var _done := {}
func _done_set() -> Dictionary:
	return _done

## 집이 선다 — 마을의 다른 집과 같은 _house(문·실내·계단·컷어웨이·자리 등록). live 면 새 주민이 입주하고 한마디
func _finish_lot(l: Dictionary, live: bool) -> void:
	var k := int(l["order"])
	if _done.has(k): return
	_done[k] = true
	if not live: built = maxi(built, k + 1)
	_pave(l)
	var sp := TownPlan.house_spec(l)
	var c := Vector3(l["c"].x, 0, l["c"].y)
	var nd := doors.size()
	var keep := _build_parent; _build_parent = _built_root
	_house(c, sp["size"], sp["wall"], sp["roof"], false, sp["seed"])
	_flower_bed(c + Vector3(-(sp["size"] as Vector3).x / 2.0 - 0.9, 0, (sp["size"] as Vector3).z / 2.0 + 0.4))
	_build_parent = keep
	if doors.size() > nd: _move_in(doors[doors.size() - 1], live)
	if live:
		_dust(c + Vector3(0, 0.5, 0)); say_toast("A new house is finished.")

func _flower_bed(at: Vector3) -> void:
	for i in 4: _scatter(["Flower_3_Group", "Flower_4_Group", "Bush_Common_Flowers", "Clover_1"][i], at + Vector3(i * 0.35, 0, 0), 0.5)

## 입주 — 명부에서 아직 마을에 없는 다음 사람. 몸이 있는 주민이 RES_MAX 를 넘으면 문에 이름만(불 켜진 집)
func _move_in(door: Dictionary, live: bool) -> void:
	if _roster.is_empty(): return
	var i := residents.size()
	var row: Dictionary = _roster[(i * 7) % _roster.size()]
	if residents.size() >= RES_MAX: door["owner"] = String(row["handle"]); return
	var r := Resident.new(); add_child(r)
	r.setup(self, int(row["id"]), String(row["handle"]))
	r.home_door = door
	var dp: Vector3 = door["pos"]
	r.position = dp + Vector3(0, 0.02, 1.2)
	residents.append(r)
	if live: get_tree().create_timer(1.5).timeout.connect(func() -> void: if is_instance_valid(r): r.say(["Moved in.", "Home.", "It's lovely."][r.uid % 3], 2.4))

## 골목 — 필지 앞(문 쪽) 동서 골목 한 토막(블록 폭), 처음 공사가 시작될 때 깔린다
func _pave(l: Dictionary) -> void:
	var b: Vector2i = l["b"]
	var key := "%d,%d,%d" % [b.x, b.y, int(l["row"])]
	if _paved.has(key): return
	_paved[key] = true
	var z: float = l["street_z"]
	var x0 := TownPlan.OX + b.x * TownPlan.PITCH; var x1 := x0 + TownPlan.PITCH
	var keep := _build_parent; _build_parent = _built_root
	_path(Vector3(x0, 0, z), Vector3(x1, 0, z), TownPlan.PATH_W)
	for xv in [x0, x1]:   # 남북 골목도 그 블록만큼
		var vk := "v%d,%d" % [int(xv), b.y]
		if not _paved.has(vk):
			_paved[vk] = true
			_path(Vector3(xv, 0, TownPlan.OZ + b.y * TownPlan.PITCH), Vector3(xv, 0, TownPlan.OZ + (b.y + 1) * TownPlan.PITCH), TownPlan.PATH_W)
	_build_parent = keep

# ── 화폐(운영자 2026-10-06: "진짜 화폐로 키우자") — 값(data/prices.json), 사기·팔기·상금, 지갑 저장. 버는 길이 늘 곁에 있어야 막는 값이 있다 ──
var prices := {}

func _economy_init() -> void:
	var f := FileAccess.open("res://data/prices.json", FileAccess.READ)
	if f: prices = JSON.parse_string(f.get_as_text())
	coins = int(records.get("coins", 0))
	set_meta("wallet_loaded", true)
	if coins > 0: _set_coins(coins)

func _save_records() -> void:
	if _tool_run(): return
	records["coins"] = coins
	var f := FileAccess.open(RECORDS, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(records))

func price_of(sp: Dictionary) -> int:
	return int((prices.get("buy", {}) as Dictionary).get(String(sp.get("item", "")), 1))

## 살 수 있나 — 주인 없는 창구(카페)는 아직 공짜. 모자라면 주인이 값을 말하고 버는 길을 알려 준다
func can_pay(sp: Dictionary) -> bool:
	if not sp.has("stock"): return true
	var p := price_of(sp)
	if coins >= p: return true
	say_toast("That's %d coins. Sell something at a counter, or win in a game." % p)
	for r in residents:
		if r.job == "baker" and r.global_position.distance_to(body.global_position) < 14.0: r.say(["Two coins, love.", "Coins first.", "Come back with coins."][randi() % 3], 1.8); break
	return false

## 팔기 — 든 것이 값이 있는 물건이고 1.4m 안에 창구가 있으면 내주고 값을 받는다
func sell_here(now: float) -> bool:
	var it: Node3D = player.carrying
	if it == null: return false
	var kind := String(it.get_meta("kind", ""))
	var sell: Dictionary = prices.get("sell", {})
	if not sell.has(kind): return false
	var near := false
	for sp in spots:
		if (sp["kind"] == "counter" or (sp["kind"] == "shop" and call("shop_open", sp))) and (sp["pos"] as Vector3).distance_to(body.global_position) < 1.4: near = true; player.face(sp["yaw"]); break   # 지도의 가게도 주인이 있으면 산다(town_city)
	if not near: return false
	var p := int(sell[kind])
	player.release(self, Vector3.ZERO).queue_free()
	player.action = "grab"; action_until = now + 0.4
	_set_coins(coins + p)
	say_toast("Sold %s · +%d" % [kind, p])
	return true

## 상금 — Climb 는 오른 높이(m)에 비례(한 번에 상한), 레이싱은 순위
func _game_prize(id: String, result: Dictionary) -> void:
	var pr: Dictionary = prices.get("prize", {})
	var won := 0
	if id == "climb": won = mini(int(pr.get("climb_cap", 80)), int(float(result.get("score", 0.0)) * float(pr.get("climb_per_m", 0.05))))
	elif id == "race":
		var place := int(result.get("place", 0)); var table: Array = pr.get("race", [12, 6, 3])
		if place >= 1 and place <= table.size(): won = int(table[place - 1])
	if won > 0:
		_set_coins(coins + won)
		get_tree().create_timer(1.6).timeout.connect(func() -> void: say_toast("Prize: %d coins." % won))

# ── 계정·멀티(poz_net.gd) — 마을 방의 좌표: x+10000, 깊이 z+10000(방의 y), 높이×10(방의 z), 방향은 s 에 ──
var net: PozNet

func _net_town() -> void:
	net = get_tree().root.get_node_or_null("PozNet") as PozNet
	if net == null:
		net = PozNet.new(); get_tree().root.add_child(net)
	net.town = self
	net.ghost_parent = self
	net.ghost_place = func(o: Dictionary) -> Transform3D:
		var yaw := float(String(o.get("s", "y:0")).trim_prefix("y:"))
		return Transform3D(Basis(Vector3.UP, yaw), Vector3(float(o.get("x", 10000.0)) - 10000.0, float(o.get("z", 0.0)) / 10.0, float(o.get("y", 10000.0)) - 10000.0))
	net.pos_source = func() -> Dictionary:
		var p := focus_pos()
		var pose := "drive" if driving else ("jump" if not body.is_on_floor() else ("walk" if player.speed > 0.2 else "stand"))
		return { "x": p.x + 10000.0, "y": p.z + 10000.0, "z": clampf(p.y * 10.0, 0.0, 400.0), "pose": pose, "face": 1, "s": "y:%.2f" % player.rotation.y, "m": "town" }
	if _tool_run(): return   # 점검 도구는 네트워크에 붙지 않는다
	net.join("town")
