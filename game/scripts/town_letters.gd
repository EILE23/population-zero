class_name TownLetters
extends TownSwap
## 편지와 쪽지("Letters and notes" — 마을이 설계한 열여덟째 시스템): 종이 한 장이 장소를 거쳐 사람에서 사람으로 간다.
## 1조각(run 99, 구조) 편지방: 북쪽 골목 동쪽 끝에 새 집 한 채 — 문·벽장·침상이 있는 실내, 안쪽 벽에 열두 칸 우편함(칸마다 편지가 보인다).
## 골목 길이 집 앞까지 늘고, 집 옆으로 시장(책 상자) 쪽 남북 오솔길이 새로 난다 — 골목과 시장이 처음으로 바로 이어진다.
## 문에 "scribe" — 이 집 주민이 서기. 종이나 편지를 들고 칸 앞에서 C = 꽂기(sort), 빈손 C = 하나 꺼내기(같은 자세). 꺼낸 편지는 C 로 펼쳐 읽는다.
## 2조각(run 100, 밀도) 광장 게시판: 가운데 집 뒤 빈 땅에 기둥 둘·코르크 판. 종이·편지를 들고 C = 핀으로 꽂기(pin, 여섯 장까지), 빈손 C = 가장 새 쪽지 떼기.
## 지나는 주민은 다섯에 하나 멈춰 뒷짐 지고 읽고(scan), 서기는 16시에 와서 하루 넘은 쪽지를 떼어 우편함에 넣는다(재고 +장수).
## 사슬: … → sites → swap → **letters** → sunroom → player → town3d. 다음 조각(옥상 쪽지·아침 배달)도 여기에

const LETTER_MAX := 12
const ROOM_AT := Vector3(19.6, 0, -16.6)   # x 18 이면 서쪽 벽이 Climb 탑 길(x 14.6..16.4)에 0.5m 걸쳤다(리뷰 2026-10-06) — 빵집(x ≥22.5) 전까지   # 골목(z −13) 동쪽 끝 x 14 너머 빈 땅 — 골목 담(x ≤13)·나무(12.5, −16)·빵집(x ≥22.5) 사이, 큰길에서 멀다
const NOTICE_AT := Vector3(-5.5, 0, -9.4)   # 가운데 집(−7, −4) 뒤·넷째 집(x ≤ −10.2) 옆 빈 땅 — 큰길 띠(z −0.1..4.1)에서 9m, 골목길(z −13) 앞
const NOTE_MAX := 6
var notice: Dictionary = {}   # 게시판 자리 {pos, kind "notice", yaw, at, notes: 꽂힌 차례대로 쪽지 노드(meta slot·at·kind), taken}
var letterwall: Dictionary = {}   # 우편함 자리 {pos, kind "letters", yaw, stock, shown: 칸마다 편지, taken(칸 둘 — 서기와 손님), door}

## 편지방 — 집 생성기(_house)에 실내만 바꿔 끼운다(침대·식탁 대신 우편함·서안·침상). 골목 길을 이 문 앞까지 늘이고 시장 쪽 오솔길을 낸다
func _letter_room(at: Vector3) -> void:
	_path(Vector3(13.5, 0, -13), Vector3(21.5, 0, -13), 2.0)   # 골목(_lane: x −14..14)의 연장 — 문 앞(z −14.8)에서 끝난다
	_path(Vector3(20.6, 0, -12.2), Vector3(20.6, 0, -8.6), 1.4)   # 시장 쪽으로 — 빵집(x ≥22.5) 서쪽 벽과 책 상자(21.5, −8) 사이로 내려간다
	_house(at, Vector3(4.2, 2.7, 3.2), Color("dfe6ea"), "shingle", false, 41, "_letter_inside")
	doors[doors.size() - 1]["job"] = "scribe"   # 이 집 주민이 서기 — 낮엔 우편함을 고르고 아침엔 그날 편지를 칸에 넣는다(resident_letters)
	var sign := Label3D.new(); sign.text = "Letters"; sign.font_size = 22; sign.pixel_size = 0.004; sign.modulate = Color("1b0c15")
	sign.position = at + Vector3(0, 2.36, 1.66); _add(sign)
	_box(Vector3(0.62, 0.2, 0.03), at + Vector3(0, 2.26, 1.63), _mat(Color("efe9e2")), false)   # 간판 판자 — 글씨 뒤
	_box(Vector3(0.06, 0.95, 0.06), at + Vector3(1.0, 0, 2.15), _mat(Color("4a4a52")))   # 문 옆 우체통 기둥 + 함(악센트는 작은 면에만)
	_box(Vector3(0.3, 0.36, 0.24), at + Vector3(1.0, 0.95, 2.15), _mat(Color("ad7096")), false)
	_box(Vector3(0.2, 0.025, 0.02), at + Vector3(1.0, 1.2, 2.28), _mat(Color("1b0c15")), false)   # 투입구

## 실내(_house 가 call 로 부른다) — 널빤지 바닥, 안쪽 벽 왼쪽에 우편함(4칸×3단), 오른쪽 벽에 서안과 의자, 앞 왼쪽 구석에 서기의 침상, 램프
func _letter_inside(at: Vector3, size: Vector3) -> void:
	var hw := size.x / 2.0 - WALL; var hd := size.z / 2.0 - WALL
	var floor_m := _mat(Color.WHITE, _tex("faces/wall-plank"), Vector3(size.x / 1.2, size.z / 1.2, 1)); floor_m.uv1_triplanar = true
	_box(Vector3(hw * 2.0, 0.03, hd * 2.0), at, floor_m, false)
	var wood := _mat(Color("8a6a4a")); var c := at + Vector3(-0.4, 0, -hd + 0.16)   # 우편함 가운데(바닥)
	_box(Vector3(1.16, 0.45, 0.3), c, wood)   # 받침장
	_box(Vector3(1.16, 0.72, 0.03), c + Vector3(0, 0.45, -0.135), wood, false)   # 뒤판
	for i in 5: _box(Vector3(0.025, 0.72, 0.3), c + Vector3(-0.565 + i * 0.2825, 0.45, 0), wood, false)
	for j in 4: _box(Vector3(1.16, 0.025, 0.3), c + Vector3(0, 0.45 + j * 0.235, 0), wood, false)
	var shown: Array = []
	for k in LETTER_MAX:   # 칸마다 비스듬히 기대 선 편지 한 통 — 기울기·높이를 칸마다 조금씩(픽셀까지 대칭인 건 없다)
		var col := k % 4; var row := k / 4
		var l := make_item("letter", Vector3.ZERO)
		l.rotation = Vector3(PI / 2.0 - 0.25 - 0.08 * fmod(k * 0.61, 1.0), 0, 0.05 * (col - 1.5))
		l.position = c + Vector3(-0.42 + col * 0.2825, 0.53 + row * 0.235, 0.0)
		shown.append(l)
	letterwall = { "pos": c + Vector3(0, 0, 0.62), "kind": "letters", "yaw": PI, "stock": 7, "shown": shown }
	_show_stock(letterwall); spots.append(letterwall)
	# 서안: 비스듬한 판 + 다리 넷, 위에 잉크병과 종이 한 장. 의자는 벽을 보고(−x 에서 +x 로)
	var dx := hw - 0.35
	for lz: float in [-0.35, 0.35]:
		for lx: float in [-0.2, 0.2]: _box(Vector3(0.05, 0.72, 0.05), at + Vector3(dx + lx, 0, lz), wood, false)
	var top := _box(Vector3(0.55, 0.04, 0.85), at + Vector3(dx, 0.72, 0), _mat(Color("b48a5a"))); top.rotation.z = -0.12
	_box(Vector3(0.22, 0.01, 0.16), at + Vector3(dx - 0.04, 0.77, 0.12), _mat(Color("f7f4ef")), false).rotation.z = -0.12
	var ink := MeshInstance3D.new(); var im := CylinderMesh.new(); im.top_radius = 0.025; im.bottom_radius = 0.03; im.height = 0.05; ink.mesh = im
	ink.material_override = _mat(Color("1b0c15")); ink.position = at + Vector3(dx + 0.12, 0.8, -0.25); _add(ink)
	_furniture("chair", at + Vector3(dx - 0.6, 0, 0), PI / 2.0)
	# 침상: 앞 왼쪽 구석 — 문(가운데)에서 우편함까지 가는 길을 비켜서
	var bx := -hw + 0.45; var bz := hd - 0.95
	_box(Vector3(0.8, 0.3, 1.5), at + Vector3(bx, 0, bz), wood)
	_box(Vector3(0.74, 0.1, 1.4), at + Vector3(bx, 0.3, bz), _mat(Color("dfe6ea")), false)
	_box(Vector3(0.55, 0.09, 0.3), at + Vector3(bx, 0.4, bz - 0.5), _mat(Color("f7f4ef")), false)
	spots.append({ "pos": at + Vector3(bx, 0.4, bz + 0.1), "kind": "bed", "yaw": 0.0 })
	_furniture("lamp", at + Vector3(hw - 0.3, 0, -hd + 0.3))

## 손이 칸에 닿은 순간 — 종이·편지가 아직 손에 있고 칸이 남았으면 손을 떠나 칸에 편지 한 통이 보인다. 사람도 주민도 이걸 부른다
func post_letter(fig: Stick3D, paper: Node3D) -> bool:
	if paper == null or fig.carrying != paper or int(letterwall["stock"]) >= LETTER_MAX: return false
	var n := int(paper.get_meta("count", 1))   # 서기가 게시판에서 떼어 온 다발은 한 번에 여러 통(run 100)
	fig.release(self, Vector3.ZERO).queue_free()
	letterwall["stock"] = mini(LETTER_MAX, int(letterwall["stock"]) + n); _show_stock(letterwall)
	return true

## 꺼내기 — 손이 비었고 남은 편지가 있으면 칸 하나가 비고 손에 편지
func unpost_letter(fig: Stick3D) -> bool:
	if fig.carrying != null or not counter_take(letterwall): return false
	fig.hold(make_item("letter", Vector3.ZERO))
	return true

## 우편함 곁의 서기 — 없으면 null
func scribe_here() -> ResidentBase:
	for r in residents:
		if r.job == "scribe" and r.state == "busy" and is_same(r.spot, letterwall): return r
	return null

## 사람이 우편함 앞(1.1m)에서 C(town_player) — 종이·편지를 들었으면 꽂고, 빈손이면 하나 꺼낸다(SORT_T 한 바퀴). 꽉 찼거나 비었으면 false — 호출자가 다음 규칙(읽기)으로
func letters_use(now: float) -> bool:
	if letterwall.is_empty() or body.global_position.distance_to(letterwall["pos"]) > 1.1: return false
	var it := player.carrying
	var put := it != null and String(it.get_meta("kind", "")) in ["paper", "letter"]
	if (put and int(letterwall["stock"]) >= LETTER_MAX) or (not put and (it != null or int(letterwall["stock"]) <= 0)): return false
	player.face(letterwall["yaw"]); reading = false
	player.pose_request = "sort"; use_until = now + PostPoses.SORT_T; action_until = now + PostPoses.SORT_T
	get_tree().create_timer(PostPoses.SORT_IN).timeout.connect(_sort_hand.bind(put, it))
	var k := scribe_here()
	if k: k.say(k.mind.line("letter_in" if put else "letter_out"), 1.6)   # 꺼내기만 해도 막지 않는다 — 서기는 한마디만
	return true

func _sort_hand(put: bool, it: Node3D) -> void:
	if player.pose_request != "sort": return   # 그새 움직였거나 맞았다 — 없던 일
	if put: post_letter(player, it)
	else: unpost_letter(player)

## 광장 게시판(run 100) — 기둥 둘, 코르크 판, 비 가림 판자. 처음부터 쪽지 둘이 꽂혀 있어 "쓰는 게시판"으로 읽힌다
func _noticeboard(at: Vector3) -> void:
	_board_frame(at, _mat(Color("6b4a35")))
	notice = { "pos": at + Vector3(0, 0, 0.75), "kind": "notice", "yaw": PI, "at": at, "notes": [] }
	spots.append(notice)
	_add_note(1, 0.0, "paper"); _add_note(5, 0.0, "paper")

## 기둥 둘·코르크 판·비 가림 판자 — 게시판과 심부름판(run 115, town_jobs)이 같은 틀을 쓴다; 틀 색만 다르다
func _board_frame(at: Vector3, post: Material) -> void:
	for sx: float in [-0.62, 0.62]: _box(Vector3(0.08, 1.45, 0.08), at + Vector3(sx, 0, 0), post)
	_box(Vector3(1.32, 0.66, 0.05), at + Vector3(0, 0.72, 0), _mat(Color("c49a6c")), false)   # 코르크 — 사람 키(어깨 0.84)보다 조금 위까지
	_box(Vector3(1.46, 0.05, 0.16), at + Vector3(0, 1.45, 0.02), post, false)

## 빈 핀 자리(3칸×2단) — 없으면 −1. 뗀 자리가 다시 찬다(쪽지마다 제 자리를 기억한다)
func note_slot() -> int:
	var used: Array = (notice["notes"] as Array).map(func(n: Node3D) -> int: return int(n.get_meta("slot")))
	for i in NOTE_MAX:
		if not (i in used): return i
	return -1

func _add_note(slot: int, now: float, kind: String) -> void:
	var at: Vector3 = notice["at"]
	var n := _box(Vector3(0.17, 0.2, 0.006), at + Vector3(-0.4 + 0.4 * (slot % 3) + randf_range(-0.05, 0.05), 1.08 - 0.3 * (slot / 3), 0.03), _mat(Color("f7f4ef") if kind == "paper" else Color("efe9e2")), false)
	n.rotation.z = randf_range(-0.14, 0.14)   # 장마다 조금씩 비뚤게 — 사람 손으로 꽂은 판
	_box(Vector3(0.024, 0.024, 0.02), Vector3(0, 0.07, 0.006), _mat(Color("ad7096")), false, n)   # 핀 머리(악센트는 작은 면에만)
	n.set_meta("slot", slot); n.set_meta("at", now); n.set_meta("kind", kind)
	(notice["notes"] as Array).append(n)

## 핀으로 꽂을 수 있는 것 — 종이·편지 한 장. 서기의 다발(meta count)은 우편함으로만 간다: 판에 꽂으면 여러 장이 한 장으로 줄던 구멍(run 101)
func pinnable(it: Node3D) -> bool:
	return it != null and String(it.get_meta("kind", "")) in ["paper", "letter"] and not it.has_meta("count")

## 꽂기 — 손에 든 종이·편지가 판의 쪽지가 된다. 자리가 없으면 false. 사람도 주민도 이걸 부른다
func pin_note(fig: Stick3D, paper: Node3D, now: float) -> bool:
	if not pinnable(paper) or fig.carrying != paper or note_slot() < 0: return false
	var kind := String(paper.get_meta("kind", "paper"))
	fig.release(self, Vector3.ZERO).queue_free()
	_add_note(note_slot(), now, kind)
	return true

## 떼기 — 가장 새 쪽지가 손으로(꽂힌 그대로 종이는 종이, 편지는 편지)
func unpin_note(fig: Stick3D) -> bool:
	var notes: Array = notice["notes"]
	if fig.carrying != null or notes.is_empty(): return false
	var n: Node3D = notes.pop_back()
	fig.hold(make_item(String(n.get_meta("kind")), Vector3.ZERO)); n.queue_free()
	return true

## 하루(DAY_LEN) 넘게 꽂힌 쪽지 — 서기가 떼어 간다
func old_notes(now: float) -> Array:
	return (notice["notes"] as Array).filter(func(n: Node3D) -> bool: return now - float(n.get_meta("at")) > DAY_LEN)

## 사람이 게시판 앞(1.1m)에서 C — 종이·편지를 들었으면 꽂고, 빈손이면 가장 새 것을 뗀다(PIN_T 한 바퀴). 꽉 찼거나 비었으면 false — 호출자가 다음 규칙(읽기)으로
func notice_use(now: float) -> bool:
	if notice.is_empty() or body.global_position.distance_to(notice["pos"]) > 1.1: return false
	var it := player.carrying
	var put := pinnable(it)   # 다발은 아래 조건에서 false — 읽기로 넘어간다
	if (put and note_slot() < 0) or (not put and (it != null or (notice["notes"] as Array).is_empty())): return false
	player.face(notice["yaw"]); reading = false
	player.pose_request = "pin"; use_until = now + PostPoses.PIN_T; action_until = now + PostPoses.PIN_T
	get_tree().create_timer(PostPoses.PIN_IN).timeout.connect(_pin_hand.bind(put, it))
	return true

func _pin_hand(put: bool, it: Node3D) -> void:
	if player.pose_request != "pin": return   # 그새 움직였거나 맞았다 — 없던 일
	if put: pin_note(player, it, Time.get_ticks_msec() / 1000.0)
	else: unpin_note(player)
