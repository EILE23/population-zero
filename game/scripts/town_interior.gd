class_name TownInterior
extends TownCity
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
	var n := Node3D.new(); n.name = "Room_%d" % i; add_child(n)
	var rm := { "node": n, "o": o, "w": dim.x, "d": dim.y, "kind": kind, "door": i, "spots": [], "entry": o + Vector3(0, 0.05, dim.y / 2.0 - 1.1), "slot": slot }
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
	var wm := _mat((walls[rng.randi() % walls.size()] as Color).darkened(0.12))   # 벽 윗면이 해를 받아 하얗게 날아갔다
	var fm := _mat(Color.WHITE, _tex("faces/wall-plank"), Vector3(w / 1.6, d / 1.6, 1))
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

## 집 — 왼쪽 침실(칸막이), 오른쪽 뒤 부엌(조리대·화덕·냉장고), 앞쪽 거실(소파·탁자·러그), 식탁과 의자 둘, 책장, 화분, 액자. 문패
func _house_room(rm: Dictionary, rng: RandomNumberGenerator) -> void:
	var o: Vector3 = rm["o"]; var w: float = rm["w"]; var d: float = rm["d"]
	var wood := _mat(Color("8a6a4a")); var cloth := _mat([Color("ad7096"), Color("5a6f9a"), Color("6f9a5a"), Color("d8a24a")][rng.randi() % 4])
	var wall := w / 2.0 - 3.6
	_box(Vector3(0.12, 2.4, d * 0.55), o + Vector3(-wall, 0, -d * 0.22), _mat(Color("e6d9c8")))   # 침실 칸막이
	var bed := o + Vector3(-w / 2.0 + 1.3, 0, -d / 2.0 + 1.5)
	_box(Vector3(1.6, 0.35, 2.1), bed, wood, false); _box(Vector3(1.5, 0.14, 1.95), bed + Vector3(0, 0.35, 0.05), _mat(Color("f7f4ef")), false)
	_box(Vector3(1.5, 0.06, 0.7), bed + Vector3(0, 0.45, 0.68), cloth, false)   # 이불은 발치에만 — 누우면 사람이 이불 속에 묻혔다; _box(Vector3(0.7, 0.12, 0.35), bed + Vector3(0, 0.49, -0.75), _mat(Color("efe9e2")), false)
	_spot(rm, "bed", bed + Vector3(0, 0, 0.1), 0.0)   # 마을 침대와 같다 — 몸은 바닥, rest 자세가 침대 높이로 눕는다
	_box(Vector3(0.5, 0.5, 0.45), bed + Vector3(1.2, 0, -0.75), wood)   # 협탁
	var k := o + Vector3(w / 2.0 - 2.2, 0, -d / 2.0 + 0.45)
	_box(Vector3(3.2, 0.9, 0.6), k, _mat(Color("cfc7c2"))); _box(Vector3(0.7, 0.03, 0.5), k + Vector3(-0.6, 0.9, 0), _mat(Color("2a2a30")), false)
	_spot(rm, "stove", k + Vector3(-0.6, 0, 0.8), PI)
	var fr := o + Vector3(w / 2.0 - 0.5, 0, -d / 2.0 + 0.45)
	_box(Vector3(0.75, 1.9, 0.65), fr, _mat(Color("f7f4ef")))
	_spot(rm, "fridge", fr + Vector3(0, 0, 0.9), PI)
	var tb := o + Vector3(w / 2.0 - 2.4, 0, -0.4)
	_box(Vector3(1.4, 0.75, 0.9), tb, wood)
	for s in [-1.0, 1.0]:
		_box(Vector3(0.45, 0.45, 0.45), tb + Vector3(s * 1.05, 0, 0), wood)
		_spot(rm, "sit", tb + Vector3(s * 1.05, 0.45, 0), -s * PI / 2.0)
	var sofa := o + Vector3(1.0, 0, d / 2.0 - 2.4)
	_box(Vector3(2.2, 0.42, 0.85), sofa, cloth); _box(Vector3(2.2, 0.5, 0.2), sofa + Vector3(0, 0.42, -0.33), cloth, false)
	for s in [-0.55, 0.55]: _spot(rm, "sit", sofa + Vector3(s, 0.42, 0.05), 0.0)
	_box(Vector3(2.8, 0.01, 1.8), sofa + Vector3(0, 0, 1.2), _mat(Color("c9b18a")), false)   # 러그
	var bk := o + Vector3(-wall + 1.2, 0, -d / 2.0 + 0.3)
	_box(Vector3(1.6, 2.0, 0.4), bk, wood)
	for r in 4:
		for c in 6: _box(Vector3(0.18, 0.32, 0.25), bk + Vector3(-0.6 + c * 0.24, 0.12 + r * 0.48, 0.1), _mat([Color("b56a5a"), Color("5a6f9a"), Color("d8a24a"), Color("6f9a5a")][(r + c) % 4]), false)
	_spot(rm, "read", bk + Vector3(0, 0, 0.8), PI)
	for p in [o + Vector3(-w / 2.0 + 0.5, 0, d / 2.0 - 1.0), o + Vector3(w / 2.0 - 0.5, 0, d / 2.0 - 1.4)]: _scatter("Plant_1", p, 0.7)
	for i in 3: _box(Vector3(0.5, 0.4, 0.03), o + Vector3(-1.0 + i * 0.9, 1.5, -d / 2.0 + 0.08), _mat([Color("ad7096"), Color("5a6f9a"), Color("d8a24a")][i]), false)   # 액자
	var owner := ""
	for r in residents:
		if r.home_door == doors[rm["door"]]: owner = r.handle; break
	if owner == "": owner = String(doors[rm["door"]].get("owner", ""))
	if owner != "":
		var lb := Label3D.new(); lb.text = "Home of %s" % owner; lb.font_size = 40; lb.pixel_size = 0.004; lb.modulate = Color("7b526c"); lb.outline_size = 0
		lb.position = o + Vector3(1.5, 2.2, -d / 2.0 + 0.09); _add(lb)

## 가게 — 뒤 가운데 계산대(주인 자리 뒤), 양옆·가운데 진열대(그 가게 물건), 간판
func _shop_room(rm: Dictionary, rng: RandomNumberGenerator) -> void:
	var o: Vector3 = rm["o"]; var w: float = rm["w"]; var d: float = rm["d"]
	var dr: Dictionary = doors[rm["door"]]
	var sh: Dictionary = shops[int(dr["shop_id"])]
	var wood := _mat(Color("8a6a4a"))
	var ct := o + Vector3(0, 0, -d / 2.0 + 1.8)
	_box(Vector3(2.6, 0.95, 0.6), ct, wood); _box(Vector3(0.4, 0.25, 0.3), ct + Vector3(0.8, 0.95, 0), _mat(Color("4a4a52")), false)   # 금전등록기
	_spot(rm, "counter", ct + Vector3(0, 0, 0.85), PI)
	sh["keeper"]["inner"] = ct + Vector3(0, 0.05, -0.75)
	sh["room"] = rm["door"]
	var item := String(sh["item"])
	for col in [-1, 0, 1]:
		var sx := float(col) * (w / 2.0 - 1.2) if col != 0 else 0.0
		var at := o + Vector3(sx, 0, 0.6 if col == 0 else -0.2)
		var len := 3.0 if col == 0 else d - 4.0
		var shelf := _box(Vector3(0.6 if col != 0 else 2.4, 1.3, len if col != 0 else 0.6), at, wood)
		for k in 4:
			var p := at + (Vector3(0, 1.3, -len / 2.0 + 0.4 + k * (len - 0.8) / 3.0) if col != 0 else Vector3(-0.9 + k * 0.6, 1.3, 0))
			var it := make_item(item, p); _add_display(it)
		var face := Vector3(-signf(sx) * 0.75, 0, 0) if col != 0 else Vector3(0, 0, 0.75)
		_spot(rm, "shelf", at + face, atan2(-face.x, -face.z), { "item": item })
	var lb := Label3D.new(); lb.text = String(sh["type"]); lb.font_size = 72; lb.pixel_size = 0.005; lb.modulate = Color("1b0c15"); lb.outline_size = 0
	lb.position = o + Vector3(0, 2.3, -d / 2.0 + 0.09); _add(lb)
	var pr := Label3D.new(); pr.text = "%s  %d coins" % [item.capitalize(), int((prices.get("buy", {}) as Dictionary).get(item, 1))]; pr.font_size = 40; pr.pixel_size = 0.004; pr.modulate = Color("7b526c"); pr.outline_size = 0
	pr.position = o + Vector3(0, 1.8, -d / 2.0 + 0.09); _add(pr)

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
			var it := make_item(String(best["item"]), p + Vector3(0, 0.9, 0)); it.set_meta("unpaid", true)
			player.hold(it); player.action = "grab"; action_until = now + 0.4
			say_toast("%s — pay at the counter." % String(best["item"]).capitalize())
		"counter":
			player.face(float(best["yaw"]))
			_till_use(now)
		"board":
			player.face(float(best["yaw"])); say_toast(String(best.get("text", "")))
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
