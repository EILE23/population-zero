class_name TownSunroom
extends TownLetters
## 이야기방("Elders and children" — 마을이 설계한 열아홉째 시스템, 2조각 run 103, 구조): 북쪽 골목 서쪽(공원) 끝에 새 집 한 채 — 앞이 유리창인 단층집.
## 안에는 날개 달린 안락의자(방을 본다)·둥근 깔개·방석 셋·주인의 침상. 주인은 마을에서 가장 '늙은 마음'(기운이 가장 낮고 어울림이 가장 높은 어른)이 되고 일은 "storysitter".
## 15–16시 그 사람이 안락의자에서 소리 내어 읽고(story, 책장 4초), 아이들이 걸어와 방석에 책상다리로 앉는다(crossleg). 사람도 빈 방석에서 C — 같은 자세, 읽는 이의 옛이야기 한 줄.
## 사슬: … → letters → **sunroom** → nap(town_nap.gd, 낮잠방 — run 108) → coins → player → town3d. 다음 조각(현관 탁자·기억 우체통·손수레·낮잠방·장난감 선반)도 이 집에
## 책 건네기(run 106, items): 책을 들고 읽는 이 앞에서 C — 집 책은 덮이고 네 책을 읽는다. 끝나면 네 책은 의자 옆 두 칸 선반에(책등이 보인다), 다음 날 10시 주인이 책 상자로 돌려놓는다(resident_sunroom)

const SUN_AT := Vector3(-19.5, 0, -16.6)   # 골목(z −13, x −14..14) 서쪽 끝 너머 빈 땅 — 공원 북쪽 끝(z ≥ −10.5)·골목 울타리(z −19, x ≥ −13)와 떨어져, 큰길에서 멀다
const STORY_FROM := 14.5   # 아이들이 나서는 시각(부모가 "세 시에 이야기"를 말한다) — 하루 12분이라 한 시간이 30초뿐
const STORY_TO := 16.0
var sunroom: Dictionary = {}   # {door, chair: 안락의자 자리, cushions: 방석 자리 셋, shelf: 의자 옆 두 칸 선반 {stock, shown}}
var player_up_at := -999.0   # 사람이 넘어졌다 일어나기 시작한 시각(town_player) — 30초 안에 방석에 앉으면 달래는 줄, 본 이들이 끄덕(run 104)

func _sunroom(at: Vector3) -> void:
	_path(Vector3(-13.5, 0, -13), Vector3(-21.5, 0, -13), 2.0)   # 골목의 서쪽 연장 — 문 앞(z −14.8)에서 끝난다
	_house(at, Vector3(4.6, 2.6, 3.6), Color("efe9e2"), "shingle", false, 43, "_sunroom_inside")   # seed 43 = 단층(첫 randf 0.67 ≥ 0.35)
	var dr: Dictionary = doors[doors.size() - 1]; sunroom["door"] = dr
	for sp: Dictionary in [sunroom["chair"], sunroom["shelf"]] + (sunroom["cushions"] as Array): sp["door"] = dr   # 주인이 밤에 침대를 못 잡으면 여기라도(resident.gd 밤 규칙)
	# 유리 앞면: 문 양쪽 벽 토막마다 창틀 상자 + 옅은 유리 + 가는 문설주 둘(모두 넷) — 집 생성기의 앞창을 덮는다. 컷어웨이 대상에 넣어 안에 들면 같이 감춘다
	var parts: Array = houses[houses.size() - 1]["parts"]
	var frame := _mat(Color("8a6a4a")); var pane := _mat(Color("dfe6ea")); var hd := 1.8
	for cx: float in [-1.375, 1.375]:
		var c := at + Vector3(cx, 0, hd + 0.1)
		parts.append(_box(Vector3(1.66, 0.25, 0.2), c, frame, false))   # 아래 턱
		parts.append(_box(Vector3(1.58, 1.45, 0.02), c + Vector3(0, 0.25, 0.05), pane, false))
		parts.append(_box(Vector3(1.66, 0.08, 0.2), c + Vector3(0, 1.7, 0), frame, false))
		for mx: float in [-0.8, -0.27, 0.27, 0.8]: parts.append(_box(Vector3(0.04 if absf(mx) < 0.5 else 0.06, 1.45, 0.08), c + Vector3(mx, 0.25, 0.06), frame, false))
	var sign := Label3D.new(); sign.text = "Stories at three"; sign.font_size = 18; sign.pixel_size = 0.004; sign.modulate = Color("1b0c15")
	sign.position = at + Vector3(0, 2.25, 1.86); _add(sign); parts.append(sign)
	call("_nap_site", at)   # 낮잠방 공사장(run 108, town_nap) — 동쪽 벽에 기대어, 같은 구역 노드 아래

## 실내(_house 가 call 로 부른다) — 왼쪽 벽 앞에 안락의자(+x 를 본다), 가운데 둥근 깔개, 그 위 방석 셋(의자를 본다), 오른쪽 뒤 구석에 침상
func _sunroom_inside(at: Vector3, size: Vector3) -> void:
	var hw := size.x / 2.0 - WALL; var hd := size.z / 2.0 - WALL
	var floor_m := _mat(Color.WHITE, _tex("faces/wall-plank"), Vector3(size.x / 1.2, size.z / 1.2, 1)); floor_m.uv1_triplanar = true
	_box(Vector3(hw * 2.0, 0.03, hd * 2.0), at, floor_m, false)
	var rug := MeshInstance3D.new(); var rm := CylinderMesh.new(); rm.top_radius = 0.95; rm.bottom_radius = 0.95; rm.height = 0.012; rug.mesh = rm
	rug.material_override = _mat(Color("c49a6c")); rug.position = at + Vector3(-0.25, 0.04, -0.25); _add(rug)
	var ring := MeshInstance3D.new(); var gm := CylinderMesh.new(); gm.top_radius = 0.7; gm.bottom_radius = 0.7; gm.height = 0.014; ring.mesh = gm
	ring.material_override = _mat(Color("e6d3a5")); ring.position = rug.position + Vector3(0, 0.002, 0); _add(ring)
	# 날개 안락의자: 나무 받침, 천 좌석·등받이·팔걸이, 머리 옆 날개 둘. 몸이 앉는 자리라 단단하지 않게(일어설 때 상자 속에 끼지 않는다)
	var cp := at + Vector3(-hw + 0.45, 0, -0.25); var cloth := _mat(Color("b56a5a")); var wood := _mat(Color("6b4a35"))
	_box(Vector3(0.62, 0.08, 0.62), cp, wood, false)
	_box(Vector3(0.6, 0.32, 0.6), cp + Vector3(0, 0.08, 0), cloth, false)
	_box(Vector3(0.14, 0.78, 0.66), cp + Vector3(-0.3, 0.08, 0), cloth, false)   # 등받이(벽 쪽)
	for sz: float in [-0.3, 0.3]:
		_box(Vector3(0.6, 0.2, 0.1), cp + Vector3(0, 0.4, sz), cloth, false)   # 팔걸이
		_box(Vector3(0.2, 0.32, 0.08), cp + Vector3(-0.22, 0.6, sz * 1.05), cloth, false)   # 날개
	var chair := { "pos": cp + Vector3(0.02, 0, 0), "kind": "story", "yaw": PI / 2.0 }   # 바닥 높이 — 앉은 골반(0.42)이 좌석 위(0.4)에 온다, 의자 자리와 같은 약속
	spots.append(chair)
	var cushions: Array = []
	var cc: Array[Color] = [Color("e8c766"), Color("dfe6ea"), Color("ad7096")]   # 악센트는 방석 하나에만
	var cpos: Array[Vector3] = [Vector3(0.0, 0, -0.85), Vector3(0.3, 0, -0.15), Vector3(-0.05, 0, 0.5)]   # 의자를 둘러 반원 — 문(가운데) 안쪽 길은 비운다
	for i in 3:
		var c := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.2; cm.bottom_radius = 0.23; cm.height = 0.08; c.mesh = cm
		c.material_override = _mat(cc[i]); c.position = at + cpos[i] + Vector3(0, 0.085, 0); c.rotation.y = i * 0.7; _add(c)
		var sp := { "pos": at + cpos[i] + Vector3(0, 0.1, 0), "kind": "cushion", "yaw": atan2(cp.x - (at.x + cpos[i].x), cp.z - (at.z + cpos[i].z)) }
		cushions.append(sp); spots.append(sp)
	# 책 선반(run 106): 의자 앞쪽 왼쪽 벽에 작은 널 하나, 책등 둘이 방을 본다(+x). spots 엔 넣지 않는다 — 산책하던 이가 고르지 않게. 주인만 10시에 책을 가지러 온다
	var shp := at + Vector3(-hw + 0.13, 1.0, 0.75)
	_box(Vector3(0.26, 0.03, 0.44), shp, wood, false)
	for sz: float in [-0.17, 0.17]: _box(Vector3(0.03, 0.12, 0.03), shp + Vector3(-0.1, -0.12, sz), wood, false)   # 받침 둘
	var spines: Array = []
	for i in 2:
		var b := make_item("book", Vector3.ZERO); var hk := 0.88 + 0.1 * i
		b.scale = Vector3(1.0, 1.0, hk); b.rotation = Vector3(PI / 2.0, -PI / 2.0, PI / 2.0)   # 세워서 책등이 +x(방 안쪽)으로 — 책 상자의 꽂음새를 90도 돌린 것
		b.position = shp + Vector3(0.0, 0.015 + 0.11 * hk, -0.07 + 0.12 * i); spines.append(b)
	var shelf := { "pos": at + Vector3(-hw + 0.5, 0, 0.75), "kind": "sshelf", "yaw": -PI / 2.0, "stock": 0, "shown": spines }
	_show_stock(shelf)
	sunroom = { "chair": chair, "cushions": cushions, "shelf": shelf }
	# 침상: 오른쪽 뒤 구석 — 이 집 주인이 밤에 잔다
	var bx := hw - 0.45; var bz := -hd + 0.8
	_box(Vector3(0.8, 0.3, 1.5), at + Vector3(bx, 0, bz), _mat(Color("8a6a4a")))
	_box(Vector3(0.74, 0.1, 1.4), at + Vector3(bx, 0.3, bz), _mat(Color("f7f4ef")), false)
	_box(Vector3(0.55, 0.09, 0.3), at + Vector3(bx, 0.4, bz - 0.5), _mat(Color("efe9e2")), false)
	spots.append({ "pos": at + Vector3(bx, 0.4, bz + 0.1), "kind": "bed", "yaw": 0.0 })
	_furniture("lamp", at + Vector3(-hw + 0.3, 0, -hd + 0.3))

## 주인 — 일 없는 어른(운전사·수리공 빼고) 가운데 기운(energy)이 가장 낮고 어울림(social)이 가장 높은 이. 이 집에 살던 사람과 집을 맞바꾼다(_residents 바로 뒤, 운전사 앞)
func _hire_storysitter() -> void:
	if sunroom.is_empty(): return
	var best: Resident = null; var bk := -9.0
	for r: Resident in residents:
		if r.job != "" or r.uid % 6 == 0: continue
		var k: float = r.mind.social - r.mind.energy
		if k > bk: bk = k; best = r
	if best == null: return
	var dr: Dictionary = sunroom["door"]
	for r: Resident in residents:
		if is_same(r.home_door, dr): r.home_door = best.home_door
	best.home_door = dr; best.job = "storysitter"

## 지금 이야기 시간인가(0..24 시계)
func story_time() -> bool:
	var h := fmod(clock * 24.0 + 6.0, 24.0)
	return h >= STORY_FROM and h < STORY_TO

## 안락의자에서 읽는 중인 주인 — 없으면 null
func storysitter_here() -> ResidentBase:
	for r in residents:
		if r.job == "storysitter" and r.state == "busy" and is_same(r.spot, sunroom.get("chair")): return r
	return null

## 사람이 방석(또는 안락의자) 앞에서 C — 빈 방석이면 책상다리로 앉는다(아이들과 같은 crossleg). 의자에선 책을 들었으면 story 로 읽는다. 방향키로 일어난다(회수는 _story_tick)
func cushion_use(sp: Dictionary, now: float) -> void:
	for r in sp.get("taken", []):
		if r != null: return   # 누가 앉았거나 앉으러 오는 중 — 그 자리는 그 사람 것(떠나면 _release 가 비운다)
	var chair: bool = sp["kind"] == "story"
	seat = { "pos": sp["pos"], "yaw": sp["yaw"], "chair": true }
	player.seated = true; player.move_dir = Vector3.ZERO; player.speed = 0.0; body.velocity = Vector3.ZERO
	var it := player.carrying
	player.pose_request = "story" if chair and it != null and String(it.get_meta("kind", "")) in ["book", "paper", "letter"] else ("" if chair else "crossleg")
	player.set_meta("cross_up", INF)
	var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(body, "position", sp["pos"] + Vector3(0, -0.08 if not chair else 0.0, 0), SunroomPoses.DOWN_T)
	player.face(sp["yaw"])
	var k := storysitter_here()
	var shaken: bool = now - player_up_at < 30.0   # 방금 넘어졌던 사람 — 주민이 같은 자리에서 듣는 것과 같은 줄(resident_sunroom)
	if k and not chair: k.say(k.mind.line("story_calm" if shaken else "story"), 2.4)   # 듣는 사람에게 옛이야기 한 줄(Listening Bench 소원)
	elif not chair and story_time(): say_toast("The storysitter is on the way.")
	if shaken and not chair: _room_nods(now)

## 흔들린 사람이 앉았다 — 방석에 앉은 이들 가운데 그 사람이 남을 때리는 걸 본(witnessed, 60초 안) 이는 차갑게 있는 대신 한 번 깊이 끄덕인다(makeup 의 nod). 호감이 조금 돌아온다
func _room_nods(now: float) -> void:
	for r in residents:
		if r.state != "busy" or r.fig.pose_request != "crossleg" or r.spot.get("kind", "") != "cushion" or now - r.mind.witnessed_at > 60.0: continue
		r.fig.set_meta("nod_at", r.fig._t); r.mind.fond = clampf(r.mind.fond + 0.05, -1.0, 1.0)

## 매 프레임(town_systems _tick) — 사람이 방석에서 일어서면 회수(UP_T) 뒤에 자세를 푼다
func _story_tick(_now: float) -> void:
	if not (player.pose_request in ["crossleg", "story"]) or not seat.is_empty(): return
	if player.pose_request == "story": player.pose_request = ""; return
	var up := float(player.get_meta("cross_up", INF))
	if up == INF: player.set_meta("cross_up", player._t)
	elif player._t > up + SunroomPoses.UP_T: player.pose_request = ""

## 읽는 이에게 책 건네기(run 106, items 축): 책을 들고 안락의자의 읽는 이 앞 1.2m 에서 C — 앉은 사람은 give_to_resident 가 건너뛰니(seated·손이 참) town_player 가 이걸 먼저 묻는다.
## 막는 가지 없음: 조건이 맞으면 100% 건넨다. 책을 든 채 이야기방에 온 주민도 방석에 앉기 전에 같은 lend_book(resident_sunroom)
func sunroom_give(now: float) -> bool:
	var it: Node3D = player.carrying
	if it == null or String(it.get_meta("kind", "")) != "book": return false
	var k := storysitter_here()
	if k == null or k.fig.carrying == null: return false
	var to: Vector3 = k.global_position - body.global_position; to.y = 0.0
	if to.length() > 1.2 or to.normalized().dot(Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))) < 0.5: return false
	lend_book(player, k); k.mind.gifted()
	player.action = "grab"; action_until = now + 0.4
	return true

## 책이 손에서 손으로 — 집 책은 덮여 사라지고(집 것이라 선반엔 안 간다), 앞서 받은 책이었으면 선반으로; 받은 책(lent)을 펴 읽는다(이야기가 끝나면 그 책도 선반으로, resident_sunroom _close_book).
## 읽는 이는 새 책을 들어 표지를 본다(newbook_at — SunroomPoses), 방석의 아이들은 다음 세 장을 더 쏠려 듣는다(keen_until). 사람도 주민도 이걸 부른다
func lend_book(from: Stick3D, k: ResidentBase) -> void:
	shelf_put(k.fig.release(self, Vector3.ZERO))
	var nb: Node3D = from.release(self, Vector3.ZERO)
	nb.set_meta("story", true); nb.set_meta("lent", true)
	k.fig.hold(nb); k.carrying_kind = "book"; k.fig.set_meta("newbook_at", k.fig._t)
	k.say(k.mind.line("story_new"), 2.0)
	for r in residents:
		if r.state == "busy" and r.fig.pose_request == "crossleg" and r.spot.get("kind", "") == "cushion": r.fig.set_meta("keen_until", r.fig._t + 3.0 * SunroomPoses.STORY_T)

## 책을 선반에(두 칸) — 받은 책(lent)만 남고 집 책은 사라진다. 칸이 다 찼으면 그 책도 집 것이 된다(사라진다). 주민도 사람도 이걸 부른다
func shelf_put(book: Node3D) -> void:
	if book == null: return
	var sh: Dictionary = sunroom["shelf"]
	if book.has_meta("lent") and int(sh["stock"]) < 2: sh["stock"] = int(sh["stock"]) + 1; _show_stock(sh)
	book.queue_free()

## 선반에서 하나 — 손이 비었고 책이 남았으면 책등 하나가 사라지고 손에 책(lent — 책 상자로 돌아갈 것)
func shelf_take(fig: Stick3D) -> bool:
	var sh: Dictionary = sunroom["shelf"]
	if fig.carrying != null or not counter_take(sh): return false
	var b := make_item("book", Vector3.ZERO); b.set_meta("lent", true); fig.hold(b)
	return true
