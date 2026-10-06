class_name TownInterior
extends TownPlots
## 문 열고 들어가면 맵(운영자 2026-10-06: "집들은 앵간하면 문 열고 들어가면 맵처럼", "상호작용이 많은 집 특히 상점은 하나의 맵", "로딩 없이") —
## 집·가게·관공서의 속은 바깥 껍데기보다 넓은 방 하나(동물의 숲처럼). 세계 한쪽(ZONE, 열린 세계 끝 가까이 — 칸을 짓지 않는 곳)에 칸을 두고 거기 짓는다.
## 로딩 없음: 문 6m 안에 다가가면 미리 짓고(절차식이라 1~3ms), 열린 문으로 걸어 들어가면 0.12초 어둡게 했다가 그 방 입구로 옮긴다. 나올 땐 거꾸로.
## 가게 방은 처음에 다 지어 둔다(주인이 창구 뒤에 서 있어야 해서 — resident_shop). 그 밖의 방은 최근 KEEP 개만 남긴다.
## 방 안 C(inner_use): 소파·의자 앉기, 침대 눕기, 책장 읽기, 냉장고(사과·캔), 화덕, 가게 진열대에서 집기 → 계산대에서 값 치르기(주인이 있어야)·팔기.
## 값을 안 치른 걸 들고 나가면 주인이 도로 가져간다

const ZONE := Vector2(1700.0, 1700.0)
const SLOT := 40.0
const ROW := 8
const KEEP := 24

var inside: Dictionary = {}     # 지금 들어와 있는 방
var _rooms := {}                # 문 번호 -> 방 {node, o, w, d, kind, door, spots, entry}
var _slot_of := {}              # 칸 번호 -> 문 번호
var _order: Array = []          # 지은 순서(오래된 것부터 지운다)
var _void: MeshInstance3D
var _near_at := 0.0
var _fridge_at := {}            # 방 -> 마지막으로 꺼낸 시각
var _zoom_out := 1.0

func is_inside() -> bool:
	return not inside.is_empty()

func _door_index(dr: Dictionary) -> int:
	return doors.find(dr)

# ── 짓기 ──
func _room(i: int) -> Dictionary:
	if _rooms.has(i): return _rooms[i]
	var dr: Dictionary = doors[i]
	var kind := "shop" if dr.has("shop_id") else ("civic" if dr.has("civic") else "house")
	var slot := 0
	while _slot_of.has(slot): slot += 1
	_slot_of[slot] = i
	var o := Vector3(ZONE.x + (slot % ROW) * SLOT, 0.0, ZONE.y + (slot / ROW) * SLOT)
	var dim: Vector2 = { "house": Vector2(10.0, 8.0), "shop": Vector2(11.0, 9.0), "civic": Vector2(15.0, 11.0) }[kind]
	var kit := {}
	if kind == "house":   # 그 집 사람이 꾸민 틀과 손질(room_kit) — 크기·모양·빛깔이 집마다
		var owner: Node = null
		for r in residents:
			if r.home_door == dr: owner = r; break
		kit = RoomKit.plan(self, i, owner)
		dim = Vector2(kit["w"], kit["d"])
	var n := Node3D.new(); n.name = "Room_%d" % i; add_child(n)
	var rm := { "node": n, "o": o, "w": dim.x, "d": dim.y, "kind": kind, "door": i, "spots": [], "entry": o + Vector3(0, 0.05, dim.y / 2.0 - 1.1), "slot": slot, "kit": kit }
	_rooms[i] = rm; _order.append(i)
	if _void == null:   # 방 둘레 어둠 — 세계의 지평선 판(초록)이 방 밖으로 보이지 않게
		_void = MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(ROW * SLOT + 200.0, ROW * SLOT + 200.0); _void.mesh = pm
		_void.material_override = _mat(Color("2a1e26")); _void.position = Vector3(ZONE.x + ROW * SLOT / 2.0, -0.4, ZONE.y + ROW * SLOT / 2.0); add_child(_void)
	var keep := _build_parent; _build_parent = n
	var rng := RandomNumberGenerator.new(); rng.seed = 7000 + i
	_shell(rm, rng)
	match kind:
		"shop": _shop_room(rm, rng)
		"civic": _civic_room(rm, rng)
		_: _house_room(rm, rng)
	_build_parent = keep
	while _order.size() > KEEP:   # 오래된 방부터 — 가게 방·지금 방은 남긴다
		var old: int = -1
		for k in _order:
			if (_rooms[k]["kind"] != "shop") and _rooms[k] != inside: old = k; break
		if old < 0: break
		_free_room(old)
	return rm

func _free_room(i: int) -> void:
	var rm: Dictionary = _rooms[i]
	(rm["node"] as Node3D).queue_free(); _slot_of.erase(rm["slot"]); _rooms.erase(i); _order.erase(i)

## 바닥·벽(앞벽은 낮다 — 3/4 시점으로 속이 보이게)·문틈·불빛
func _shell(rm: Dictionary, rng: RandomNumberGenerator) -> void:
	var o: Vector3 = rm["o"]; var w: float = rm["w"]; var d: float = rm["d"]
	var walls := [Color("efe2cf"), Color("dfe6ea"), Color("e8d4d8"), Color("dfe8d6"), Color("f2e6c8")]
	var kit: Dictionary = rm.get("kit", {})
	var wm := _mat(((kit["wall"] as Color) if kit.has("wall") else (walls[rng.randi() % walls.size()] as Color)).darkened(0.24))   # 벽 윗면이 해를 받아 하얗게 날아갔다
	var fm := _mat((kit["floor"] as Color) if kit.has("floor") else Color.WHITE, _tex("faces/wall-plank"), Vector3(w / 1.6, d / 1.6, 1))
	_box(Vector3(w, 0.2, d), o + Vector3(0, -0.2, 0), fm)
	_box(Vector3(w + 0.3, 2.8, 0.15), o + Vector3(0, 0, -d / 2.0), wm)
	for s in [-1.0, 1.0]: _box(Vector3(0.15, 2.8, d), o + Vector3(s * (w / 2.0 + 0.075), 0, 0), wm)
	var gap := 1.4
	for s in [-1.0, 1.0]:
		var len := (w - gap) / 2.0
		_box(Vector3(len, 0.7, 0.15), o + Vector3(s * (gap / 2.0 + len / 2.0), 0, d / 2.0), wm)
	_box(Vector3(gap, 0.02, 0.9), o + Vector3(0, 0.0, d / 2.0 - 0.45), _mat(Color("7b526c")), false)   # 문 앞 깔개 — 여기로 나간다
	for s in [-1.0, 1.0]:   # 옆벽 창
		_box(Vector3(0.04, 1.0, 1.4), o + Vector3(s * (w / 2.0 - 0.01), 1.1, -d / 6.0), _mat(Color("bfe3f2")), false)
	var l := OmniLight3D.new(); l.light_color = Color("ffe9c4"); l.light_energy = 1.3; l.omni_range = maxf(w, d) * 1.1; l.position = o + Vector3(0, 2.6, 0); _add(l)

func _spot(rm: Dictionary, kind: String, at: Vector3, yaw: float, extra := {}) -> void:
	var sp := { "kind": kind, "pos": at, "yaw": yaw }
	sp.merge(extra)
	(rm["spots"] as Array).append(sp)

## 집 — 틀(data/interiors.json)과 그 사람의 손(room_kit.gd). 문패
func _house_room(rm: Dictionary, rng: RandomNumberGenerator) -> void:
	var o: Vector3 = rm["o"]; var d: float = rm["d"]
	RoomKit.build(self, rm, rm["kit"])
	var owner := ""
	for r in residents:
		if r.home_door == doors[rm["door"]]: owner = r.handle; break
	if owner == "": owner = String(doors[rm["door"]].get("owner", ""))
	if owner != "":
		var lb := Label3D.new(); lb.text = "Home of %s" % owner; lb.font_size = 40; lb.pixel_size = 0.004; lb.modulate = Color("7b526c"); lb.outline_size = 0
		lb.position = o + Vector3(1.5, 2.2, -d / 2.0 + 0.09); _add(lb)

## 가게 — 뒤 가운데 계산대(주인 자리 뒤), 양옆·가운데 진열대(그 가게 물건), 간판
func _shop_room(rm: Dictionary, rng: RandomNumberGenerator) -> void:
	ShopKit.build(self, rm, shops[int(doors[rm["door"]]["shop_id"])])   # 배치 셋 × 종류마다 꾸밈(shop_kit.gd)

## 관공서 — 시청: 민원 창구·대기 의자 줄·게시판 / 도서관: 서가 줄·열람 탁자 / 학교: 책상 줄·칠판
func _civic_room(rm: Dictionary, rng: RandomNumberGenerator) -> void:
	var o: Vector3 = rm["o"]; var w: float = rm["w"]; var d: float = rm["d"]
	var wood := _mat(Color("8a6a4a"))
	match String(doors[rm["door"]]["civic"]):
		"library":
			for r in 3:
				var at := o + Vector3(-w / 2.0 + 2.5 + r * 3.2, 0, -d / 2.0 + 2.5)
				_box(Vector3(0.5, 2.0, 3.6), at, wood)
				for k in 10: _box(Vector3(0.28, 0.3, 0.18), at + Vector3(0.0, 0.15 + (k % 4) * 0.48, -1.5 + k * 0.33), _mat([Color("b56a5a"), Color("5a6f9a"), Color("d8a24a"), Color("6f9a5a")][k % 4]), false)
				_spot(rm, "read", at + Vector3(0.75, 0, 0), -PI / 2.0, { "borrow": true })
			for t in 2:
				var tb := o + Vector3(w / 2.0 - 3.0, 0, -1.5 + t * 2.8)
				_box(Vector3(2.0, 0.75, 1.0), tb, wood)
				for s in [-1.0, 1.0]: _spot(rm, "sit", tb + Vector3(s * 0.6, 0.45, 0.85), PI)
			_sign_in(rm, "THE LIBRARY\nQuiet, please.")
		"school":
			_box(Vector3(5.0, 1.4, 0.06), o + Vector3(0, 0.8, -d / 2.0 + 0.1), _mat(Color("2f4a3a")), false)
			var bb := Label3D.new(); bb.text = "2 + 2 = 4\nHomework: none."; bb.font_size = 64; bb.pixel_size = 0.005; bb.modulate = Color("f7f4ef"); bb.outline_size = 0; bb.position = o + Vector3(0, 1.6, -d / 2.0 + 0.14); _add(bb)
			for r in 2:
				for c in 4:
					var dk := o + Vector3(-4.5 + c * 3.0, 0, -0.5 + r * 2.4)
					_box(Vector3(1.0, 0.7, 0.6), dk, wood)
					_spot(rm, "sit", dk + Vector3(0, 0.42, 0.65), PI)
		_:
			var ct := o + Vector3(0, 0, -d / 2.0 + 1.6)
			_box(Vector3(5.0, 1.05, 0.6), ct, wood)
			_sign_in(rm, "TOWN HALL\nEnquiries. Take a number.")
			for c in 6: _spot(rm, "sit", o + Vector3(-3.75 + c * 1.5, 0.45, 2.0), PI)
			for c in 6: _box(Vector3(0.5, 0.45, 0.5), o + Vector3(-3.75 + c * 1.5, 0, 2.0), wood)
			_spot(rm, "board", o + Vector3(w / 2.0 - 1.0, 0, -1.0), PI / 2.0, { "text": "NOTICE: The bench by the fountain is being replaced with the same bench." })
			_box(Vector3(0.06, 1.2, 1.6), o + Vector3(w / 2.0 - 0.1, 0.8, -1.0), _mat(Color("c9b18a")), false)

func _sign_in(rm: Dictionary, text: String) -> void:
	var lb := Label3D.new(); lb.text = text; lb.font_size = 64; lb.pixel_size = 0.005; lb.modulate = Color("1b0c15"); lb.outline_size = 0
	lb.position = (rm["o"] as Vector3) + Vector3(0, 2.3, -float(rm["d"]) / 2.0 + 0.09); _add(lb)

# ── 드나들기 ──
## 매 물리 프레임(town_social._social_tick 맨 앞) — 문 가까이면 방을 미리, 열린 문으로 걸어 들면 들어가고, 깔개를 밟고 나가면 나간다
func _inner_tick(now: float, dir: Vector3) -> void:
	if is_inside():
		if now >= _near_at: _near_at = now + 0.5; _mirror(now)
		var o: Vector3 = inside["o"]
		if body.global_position.z > o.z + float(inside["d"]) / 2.0 - 0.35 and dir.z > 0.3: _leave_room()
		elif body.global_position.y < -3.0: body.global_position = inside["entry"]   # 떨어지면 입구로
		return
	if now < _near_at or driving: return
	_near_at = now + 0.25
	var p := body.global_position
	for i in doors.size():
		var dr: Dictionary = doors[i]
		var d := p.distance_to(dr["pos"])
		if d < 6.0: _room(i)   # 다가가면 미리 짓는다 — 들어갈 땐 이미 있다
		if dr["open"] and d < 0.75 and dir.z < -0.3: _enter_room(i); return
	for r in residents:   # 방 구역에 남은 주민(주인 일이 끝났는데 못 나온) — 가게 문 앞으로
		if r.global_position.x > ZONE.x - 50.0 and not (r.state == "busy" and String(r.spot.get("kind", "")) == "keeper"):
			var shs: Array = shops.filter(func(sh: Dictionary) -> bool: return int(sh["id"]) == int(r.get_meta("shop_id", -1)))
			r.global_position = (shs[0]["keeper"]["pos"] as Vector3) if not shs.is_empty() else Vector3(0, 0.05, 4)

## 집에 들어가 있는 주민 — 그 집 벽 안에 있거나 그 집 자리(침대·의자)를 잡은 주민을 방에도 세운다(운영자 2026-10-06: "주민이 집에 들어갔는데 막상 들어가 보면 없어").
## 누웠으면 방 침대에, 앉았으면 의자·소파에, 아니면 부엌·책장 앞에. 다가가면 인사하고, C 로 인사를 나눈다. 나가면 사라진다(진짜 몸은 밖의 집 안에 그대로)
func _mirror(now: float) -> void:
	if inside.get("kind", "") != "house": return
	var dr: Dictionary = doors[inside["door"]]
	var h: Dictionary = {}
	for hh in houses:
		if hh["door"] == dr: h = hh; break
	var here := {}
	for r in residents:
		var p: Vector3 = r.global_position
		var in_walls: bool = not h.is_empty() and p.x > h["min"].x and p.x < h["max"].x and p.z > h["min"].z and p.z < h["max"].z
		var on_spot: bool = r.state == "busy" and r.spot.get("door") is Dictionary and r.spot["door"] == dr
		if in_walls or on_spot: here[r.uid] = r
	var px: Dictionary = inside.get("proxies", {})
	for uid in px.keys():
		if not here.has(uid): (px[uid]["node"] as Node3D).queue_free(); px.erase(uid)
	var spots: Array = inside["spots"]
	var used := {}
	for uid in px: used[px[uid]["spot"]] = true
	for uid in here:
		var r: Resident = here[uid]
		var lying: bool = r.fig.lying or r.fig.pose_request in ["rest", "sky"]
		var want: String = "bed" if lying else ("sit" if r.fig.seated else "")
		if px.has(uid) and px[uid]["want"] == want: continue
		if px.has(uid): (px[uid]["node"] as Node3D).queue_free(); used.erase(px[uid]["spot"])
		var pick := -1
		for k in spots.size():
			var kd := String(spots[k]["kind"])
			if used.has(k): continue
			if (want != "" and kd == want) or (want == "" and kd in ["stove", "read", "fridge", "pose", "tv"]): pick = k; break
		var g := Stick3D.new(); g.color = r.fig.color; g.head_color = r.fig.head_color; (inside["node"] as Node3D).add_child(g)
		var at: Vector3 = (spots[pick]["pos"] as Vector3) if pick >= 0 else (inside["entry"] as Vector3) - Vector3(0, 0, 2.0)
		g.global_position = at if want != "" else Vector3(at.x, 0.02, at.z)
		g.face(float(spots[pick]["yaw"]) + (0.0 if want != "" else PI) if pick >= 0 else PI)
		if want == "bed": g.pose_request = "rest"
		elif want == "sit": g.seated = true
		else: g.pose_request = String(r.fig.pose_request) if r.fig.pose_request != "" else ""
		var lb := Label3D.new(); lb.text = r.handle; lb.font_size = 40; lb.pixel_size = 0.002; lb.modulate = Color("7b526c"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.no_depth_test = true; lb.position = Vector3(0, 1.4, 0); g.add_child(lb)
		px[uid] = { "node": g, "want": want, "spot": pick, "r": r, "said": -999.0 }
		if pick >= 0: used[pick] = true
	inside["proxies"] = px
	for uid in px:   # 다가가면 먼저 한마디(30초에 한 번)
		var e: Dictionary = px[uid]
		if body.global_position.distance_to((e["node"] as Node3D).global_position) < 2.2 and now - float(e["said"]) > 30.0:
			e["said"] = now
			ChatBox.bubble(e["node"], ["Oh. Hello.", "Come in, then.", "Shoes.", "I was just sitting.", "You found the door."][randi() % 5] if e["want"] != "bed" else "Mm. Sleeping.", 1.7)

func _enter_room(i: int) -> void:
	var rm := _room(i)
	_fade_move(func() -> void:
		inside = rm
		body.global_position = rm["entry"]; body.velocity = Vector3.ZERO; player.face(PI)
		_zoom_out = float(get("zoom_want")); set("zoom_want", 1.6); set("zoom", 1.6)   # 방 하나가 다 보이게
		cam.global_position = body.global_position + Vector3(0, 8.5, 7.5) * float(get("zoom"))
		var dr: Dictionary = doors[i]
		var t := String(shops[int(dr["shop_id"])]["type"]).capitalize() if dr.has("shop_id") else (String(dr["civic"]).replace("_", " ").capitalize() if dr.has("civic") else "")
		if t != "": say_toast(t))

func _leave_room() -> void:
	var dr: Dictionary = doors[inside["door"]]
	for uid in inside.get("proxies", {}): (inside["proxies"][uid]["node"] as Node3D).queue_free()   # 방에 세운 주민은 나가면 지운다
	inside["proxies"] = {}
	_unpaid_check()
	_fade_move(func() -> void:
		inside = {}
		body.global_position = (dr["pos"] as Vector3) + Vector3(0, 0.05, 0.95); body.velocity = Vector3.ZERO; player.face(0.0)
		set("zoom_want", _zoom_out)
		cam.global_position = body.global_position + Vector3(0, 8.5, 7.5) * float(get("zoom"))
		gen.fill(body.global_position))

## 잠깐 어둡게 — 그 사이에 옮긴다(방은 이미 지어져 있다)
func _fade_move(move: Callable) -> void:
	var f := _fader()
	var tw := create_tween()
	tw.tween_property(f, "color:a", 1.0, 0.1)
	tw.tween_callback(move)
	tw.tween_property(f, "color:a", 0.0, 0.14)

## 값을 안 치른 걸 들고 나가면 — 주인이 있으면 도로 가져가고, 없으면 제자리에 둔다
func _unpaid_check() -> void:
	var it: Node3D = player.carrying
	if it == null or not it.has_meta("unpaid"): return
	player.release(self, Vector3.ZERO).queue_free()
	var k := _keeper(shops[int(doors[inside["door"]]["shop_id"])]) if doors[inside["door"]].has("shop_id") else null
	if k and shop_open(shops[int(doors[inside["door"]]["shop_id"])]): k.say("That's not paid for.", 1.8); say_toast("The shopkeeper took it back.")
	else: say_toast("You put it back.")

# ── 방 안 C ──
func inner_use(now: float) -> bool:
	if not is_inside(): return false
	var p := body.global_position
	for uid in inside.get("proxies", {}):   # 집에 있는 주민에게 인사
		var e: Dictionary = inside["proxies"][uid]
		var g: Node3D = e["node"]
		if p.distance_to(g.global_position) < 1.3:
			player.pose_request = "wave"; use_until = now + 1.2; action_until = now + 0.3
			player.face(atan2(g.global_position.x - p.x, g.global_position.z - p.z))
			var r: Resident = e["r"]
			ChatBox.bubble(g, r.mind.line("greet_fond") if r.mind.fond > 0.3 else (r.mind.line("greet_cold") if r.mind.fond < -0.3 else r.mind.line("greet_new")), 1.7)
			return true
	var best: Dictionary = {}; var bd := 1.25
	for sp in inside["spots"]:
		var d := Vector2(p.x - sp["pos"].x, p.z - sp["pos"].z).length()
		if d < bd: bd = d; best = sp
	if best.is_empty(): return false
	match String(best["kind"]):
		"sit":   # 벤치와 같은 앉기(seat) — 일어나기·충돌 끄기는 town_player 가 한다
			body.global_position = Vector3(best["pos"].x, 0.05, best["pos"].z); body.velocity = Vector3.ZERO
			set("seat", { "pos": Vector3(best["pos"].x, 0.0, best["pos"].z), "yaw": float(best["yaw"]), "inner": true })
			player.seated = true; player.move_dir = Vector3.ZERO; player.speed = 0.0; player.face(float(best["yaw"]))
		"bed":   # 눕기 — 풀밭에 눕기와 같은 resting·sky(움직이면 일어난다)
			if player.carrying: return false
			resting = true; player.pose_request = "rest"; player.face(float(best["yaw"])); body.velocity = Vector3.ZERO
			var tw := create_tween(); tw.tween_property(body, "position", (best["pos"] as Vector3) + Vector3(0, 0.02, 0), 0.35)
		"read":
			player.face(float(best["yaw"])); player.pose_request = "read"; reading = true
			if best.has("borrow") and player.carrying == null:
				player.hold(make_item("book", p + Vector3(0, 0.9, 0))); say_toast("Borrowed a book. Bring it back whenever.")
		"stove":
			player.face(float(best["yaw"])); player.pose_request = "stoke"; use_until = now + 2.0; action_until = now + 2.0
			say_toast("The kettle, on.")
		"fridge":
			player.face(float(best["yaw"]))
			if player.carrying == null and now - float(_fridge_at.get(inside["door"], -999.0)) > 60.0:
				_fridge_at[inside["door"]] = now
				player.hold(make_item(["apple", "can"][randi() % 2], p + Vector3(0, 0.9, 0))); player.action = "grab"; action_until = now + 0.4
			else: say_toast("Nothing else in there but mustard.")
		"shelf":
			player.face(float(best["yaw"]))
			if player.carrying: return false
			var mix: Array = best.get("mix", [best["item"]]); var kind := String(mix[int(best.get("next", 0)) % mix.size()]); best["next"] = int(best.get("next", 0)) + 1   # 집을 때마다 다음 것(잡화점의 모자 넷)
			var it: Node3D = call("make_goods", kind, p + Vector3(0, 0.9, 0)); it.set_meta("unpaid", true)   # 위층(town_store)
			player.hold(it); player.action = "grab"; action_until = now + 0.4
			say_toast("%s — pay at the counter." % kind.capitalize())
		"counter":
			player.face(float(best["yaw"]))
			_till_use(now)
		"board":
			player.face(float(best["yaw"])); say_toast(String(best.get("text", "")))
		"pose":   # 기구 앞에서 그 일의 자세(망치질·바느질·손차양…) — 움직이면 풀린다(town_player)
			player.face(float(best["yaw"])); player.pose_request = String(best.get("pose", "wait")); use_until = now + 3.0
			if best.has("text"): say_toast(String(best["text"]))
		"emote":   # 매트·아령·철봉 — 산스장과 같은 되풀이 자세(town_social)
			body.global_position = Vector3(best["pos"].x, 0.05, best["pos"].z); player.face(float(best["yaw"]) + PI)
			action_until = now - 0.01; call("_emote", String(best.get("move", "squat")), 8.0)
		"play":   # 피아노·전축 — 음 몇 개(차 라디오와 같은 소리 만들기, town_cabin)
			player.face(float(best["yaw"])); player.pose_request = "strum"; use_until = now + 2.0
			var notes := [262.0, 330.0, 392.0, 523.0, 440.0, 349.0]
			var tone := AudioStreamPlayer.new(); tone.stream = TownCabin._tone_wav([notes[randi() % notes.size()], notes[randi() % notes.size()] * 1.5], 0.6); tone.volume_db = -10.0; add_child(tone); tone.play(); tone.finished.connect(tone.queue_free)
			say_toast("A tune, more or less." if not best.has("tune") else ["The record skips. You let it.", "Something from before you were born.", "It plays the B-side. It is better."][randi() % 3])
		"tv":
			player.face(float(best["yaw"])); say_toast(["The weather, again.", "A cookery programme. Someone burns an onion.", "Snooker. Nobody moves.", "The news. It is about the bench."][randi() % 4])
		"search":   # 상자·통 뒤지기 — 방마다 1분에 한 번 무언가
			player.face(float(best["yaw"])); player.action = "grab"; action_until = now + 0.4
			if player.carrying == null and now - float(_fridge_at.get(-1 - int(inside["door"]), -999.0)) > 60.0:
				_fridge_at[-1 - int(inside["door"])] = now
				player.hold(make_item(["book", "apple", "can", "umbrella", "letter"][randi() % 5], p + Vector3(0, 0.9, 0)))
			else: say_toast("Mostly string.")
	return true

## 계산대 — 안 치른 물건이면 값 치르기, 값이 있는 내 물건이면 팔기. 주인이 서 있어야
func _till_use(now: float) -> void:
	var sh: Dictionary = shops[int(doors[inside["door"]]["shop_id"])]
	if not shop_open(sh): say_toast("Nobody at the counter."); return
	var k := _keeper(sh)
	var it: Node3D = player.carrying
	if it == null: k.say(["Morning.", "Help yourself.", "Shelves are there."][randi() % 3], 1.6); return
	var kind := String(it.get_meta("kind", ""))
	if it.has_meta("unpaid"):
		var price := int((prices.get("buy", {}) as Dictionary).get(kind, 1))
		if coins < price: say_toast("That's %d coins. You have %d." % [price, coins]); return
		_set_coins(coins - price); k.coins += price; it.remove_meta("unpaid")
		k.say(["Thank you.", "There you are.", "Mind how you go."][randi() % 3], 1.6)
		say_toast("%s · -%d" % [kind.capitalize(), price])
		return
	var sell: Dictionary = prices.get("sell", {})
	if sell.has(kind):
		player.release(self, Vector3.ZERO).queue_free(); player.action = "grab"; action_until = now + 0.4
		_set_coins(coins + int(sell[kind])); k.coins = maxi(0, k.coins - int(sell[kind]))
		say_toast("Sold %s · +%d" % [kind, int(sell[kind])])
	else: k.say("Don't need that, thanks.", 1.6)
