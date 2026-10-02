class_name TownWoods
extends TownMeals
## 숲 오두막의 장작과 난로(run 90 패기·쌓기, run 92 난로에 넣기) — town_sites.gd 가 450줄을 넘어 주제별로 뗐다(GROW.md 코드 정리). 자리는 _site_cabin(town_sites)이 _woodyard 로 짓는다.
## 사슬: … → town_meals → town_woods → town_sites → town_player

const STACK_MAX := 12          # 쪼갠 장작더미 칸 — 넷씩 세 단
const LOOSE_MAX := 8           # 그루터기 둘레에 흩어진 장작이 이만큼이면 더 쪼개지 않는다(통나무가 안 올라온다) — 나르는 게 먼저
const FIRE_MAX := 3            # 난로 화실 — 장작 셋이면 꽉 찬다(문 너머로 마구리 셋이 보인다)
var woodcut: Dictionary = {}   # {work, pile, stove: 자리, stump, block, axe, rest: 도끼가 꽂힌 자세, stack: [장작 노드], base, glow, light, sdoor, ends, fire: 화실 장작 수, house, stoker, who, cut, night}

# ── 장작 패기(운영자 2026-10-01 "열린 세계의 장소에 할 일" — 오두막 1조각): 그루터기 위에 통나무를 세우고 도끼로 찍으면 둘로 쪼개져 옆으로 튄다(줍는 물건 "log").
## 주운 장작은 오두막 옆 쪼갠 장작더미(넷씩 세 단)에 C 로 쌓인다. 나무꾼(오두막 문의 주민)이 낮에 같은 자리에서 같은 자세로 패고, 흩어진 장작을 하나씩 더미로 나른다.
## 오두막 안 무쇠 난로는 누가 장작을 넣어야 붙는다(run 92, 3조각 — 전엔 밤마다 더미에서 저절로 탔다): 장작을 들고 난로 앞 C = stoke(화실에 하나, 셋까지).
## 넣어 둔 난로는 해 질 녘에 붙고(앞창이 붉고 굴뚝이 연기) 밤새 다 타서 아침엔 빈다. 나무꾼은 16:30 에 더미에서 하나를 들고 들어가 같은 자세로 넣는다.
## 사람: 빈손으로 그루터기 앞 C = 두 번 패기, 장작을 들고 더미 앞 C = 쌓기
func _woodyard(c: Vector3) -> void:
	var bark := _mat(Color("7a5640")); var iron := _mat(Color("3a3438"))
	var st := c + Vector3(3.8, 0, -2.2)
	var stump := MeshInstance3D.new(); var sc := CylinderMesh.new(); sc.top_radius = 0.28; sc.bottom_radius = 0.33; sc.height = 0.45; stump.mesh = sc; stump.material_override = bark
	stump.position = st + Vector3(0, 0.22, 0); _add(stump)
	_box(Vector3(0.5, 0.012, 0.5), st + Vector3(0, 0.445, 0), _mat(Color("c9a77a")), false).rotation.y = 0.4   # 잘린 윗면 — 밝은 나이테 판
	var block := MeshInstance3D.new(); var bm := CylinderMesh.new(); bm.top_radius = 0.13; bm.bottom_radius = 0.14; bm.height = 0.3; block.mesh = bm; block.material_override = bark
	block.position = st + Vector3(0, 0.6, 0); block.visible = false; _add(block)   # 패는 동안만 그루터기 위에 선다
	var axe := Node3D.new(); _add(axe)   # 원점 = 손잡이 끝(쥐는 곳), 자루가 −y 로, 날은 −z(내리찍는 쪽)
	_box(Vector3(0.04, 0.62, 0.04), Vector3(0, -0.62, 0), _mat(Color("9a7650")), false, axe)
	_box(Vector3(0.035, 0.1, 0.18), Vector3(0, -0.64, -0.05), _mat(Color("5b5b63")), false, axe)
	var rest := Transform3D(Basis(Vector3.BACK, 0.35), st + Vector3(-0.22, 1.02, 0))   # 쉴 땐 날이 그루터기에 박혀 비스듬히 선다
	axe.global_transform = rest
	var base := c + Vector3(3.6, 0, -3.9)
	_box(Vector3(0.42, 0.05, 0.66), base, _mat(Color("6b4a35")), false)   # 쪼갠 장작을 올리는 받침
	var work := { "pos": st + Vector3(-0.8, 0, 0), "kind": "chop", "yaw": PI / 2.0 }
	var pile := { "pos": base + Vector3(-0.75, 0, 0), "kind": "pile", "yaw": PI / 2.0 }
	spots.append(work); spots.append(pile)
	# 오두막 안 무쇠 난로 — 뒷벽, 침대와 선반 사이. 연통이 천장으로. 화실에 장작이 있는 밤엔 앞창이 붉고 방이 따뜻해진다
	var sv := c + Vector3(-0.75, 0, -7.35)
	_box(Vector3(0.5, 0.55, 0.4), sv, iron)
	_box(Vector3(0.1, 2.0, 0.1), sv + Vector3(0.1, 0.55, -0.08), iron, false)
	var glow := _box(Vector3(0.24, 0.14, 0.02), sv + Vector3(0, 0.2, 0.2), _mat(Color("2a2226")), false)
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color("ff8a2a"); gm.emission_enabled = true; gm.emission = Color("ff6a1a"); gm.emission_energy_multiplier = 1.6
	glow.set_meta("lit", gm); glow.set_meta("cold", glow.material_override)
	var sl := OmniLight3D.new(); sl.light_color = Color(1.0, 0.6, 0.3); sl.light_energy = 0.9; sl.omni_range = 3.5; sl.position = sv + Vector3(0, 0.5, 0.4); sl.visible = false; _add(sl)
	var ends: Array = []   # 앞창 너머로 보이는 장작 마구리 셋 — 화실에 든 만큼만 보인다
	for i in FIRE_MAX:
		var e := MeshInstance3D.new(); var em := CylinderMesh.new(); em.top_radius = 0.028; em.bottom_radius = 0.028; em.height = 0.012; e.mesh = em; e.material_override = _mat(Color("c9a77a"))
		e.position = sv + Vector3(-0.07 + i * 0.07, 0.25 + 0.03 * (i % 2), 0.212); e.rotation.x = PI / 2.0; e.visible = false; _add(e); ends.append(e)
	var sdoor := Node3D.new(); sdoor.position = sv + Vector3(-0.13, 0.27, 0.224); _add(sdoor)   # 앞창의 무쇠 문틀 — 왼쪽 경첩(원점)에서 바깥(+z)으로 열린다. 틀뿐이라 닫혀도 불이 보인다
	for b: Array in [[Vector3(0.26, 0.02, 0.012), Vector3(0.13, 0.07, 0)], [Vector3(0.26, 0.02, 0.012), Vector3(0.13, -0.09, 0)], [Vector3(0.02, 0.18, 0.012), Vector3(0.01, -0.09, 0)], [Vector3(0.02, 0.18, 0.012), Vector3(0.25, -0.09, 0)], [Vector3(0.025, 0.025, 0.03), Vector3(0.235, -0.0125, 0.015)]]:
		_box(b[0], b[1], iron, false, sdoor)
	var stove := { "pos": sv + Vector3(0, 0, 0.62), "kind": "stove", "yaw": PI, "door": doors[doors.size() - 1] }   # 문을 달아 둬야 주민이 벽을 뚫지 않고 문으로 들어온다(침대·선반처럼)
	spots.append(stove)
	woodcut = { "work": work, "pile": pile, "stove": stove, "stump": st, "block": block, "axe": axe, "rest": rest, "stack": [], "base": base, "glow": glow, "light": sl, "sdoor": sdoor, "ends": ends, "fire": 0,
		"house": houses[houses.size() - 1], "stoker": null, "who": null, "cut": -1, "night": false }
	for i in 4: pile_put()   # 쌓아 둔 게 조금 있다 — 첫날 밤에도 난로가 붙는다

## 지금 그루터기에서 패는 나무꾼(주민) — 없으면 null
func woodcutter_at_work() -> ResidentBase:
	if woodcut.is_empty(): return null
	for r in (woodcut["work"] as Dictionary).get("taken", []):
		if r is ResidentBase and (r as ResidentBase).state == "busy" and (r as ResidentBase).fig.pose_request == "chop": return r
	return null

## 그루터기 둘레(4m)에 흩어진 쪼갠 장작 — 나무꾼이 하나씩 나른다
func loose_logs() -> Array:
	if woodcut.is_empty(): return []
	var st: Vector3 = woodcut["stump"]
	return items.filter(func(it: Node3D) -> bool: return String(it.get_meta("kind", "")) == "log" and it.global_position.distance_to(st) < 4.0)

## 더미에 장작 하나 — 넷씩 한 단, 단마다 살짝 엇갈린다. 꽉 찼으면 false
func pile_put() -> bool:
	var stack: Array = woodcut["stack"]
	if stack.size() >= STACK_MAX: return false
	var i := stack.size()
	var lg := make_item("log", Vector3.ZERO)
	var row := floori(i / 4.0)
	lg.get_parent().remove_child(lg); (woodcut["axe"] as Node3D).get_parent().add_child(lg)   # 구역 노드 밑 — 멀어지면 같이 꺼진다
	lg.global_position = (woodcut["base"] as Vector3) + Vector3(0.03 * (row % 2), 0.085 + row * 0.075, -0.21 + (i % 4) * 0.14)
	lg.rotation.y = 0.04 * (i % 3 - 1)
	stack.append(lg)
	return true

## 더미 맨 위 장작 하나를 내린다(나무꾼이 난로로 가져간다) — 비었으면 null
func pile_take() -> Node3D:
	var stack: Array = woodcut["stack"]
	return null if stack.is_empty() else stack.pop_back()

## 난로에 넣기 — 문 앞에 쪼그려 stoke. 장작은 STOKE_IN 에 손을 떠난다(그 전에 움직이면 손에 남는다). 화실이 꽉 찼으면 false
func stoke(fig: Stick3D, who: Node3D) -> bool:
	if int(woodcut["fire"]) >= FIRE_MAX: return false
	fig.face(PI); fig.pose_request = "stoke"; woodcut["stoker"] = fig
	get_tree().create_timer(HearthPoses.STOKE_IN).timeout.connect(_stoked.bind(fig, who))
	return true

func _stoked(fv: Variant, who: Variant) -> void:   # 타입을 박으면 그새 지워진 노드를 넣을 때 멈춘다
	if not is_instance_valid(fv) or (fv as Stick3D).pose_request != "stoke": return
	var fig: Stick3D = fv
	if fig.carrying == null or String(fig.carrying.get_meta("kind", "")) != "log" or int(woodcut["fire"]) >= FIRE_MAX: return
	fig.release(self, Vector3.ZERO).queue_free()
	woodcut["fire"] = int(woodcut["fire"]) + 1
	for i in FIRE_MAX: (woodcut["ends"][i] as Node3D).visible = i < int(woodcut["fire"])
	if is_instance_valid(who): who.set("carrying_kind", "")
	if fig == player: say_toast(["One log in.", "Two in.", "Full. It will burn tonight."][int(woodcut["fire"]) - 1])

## 장작을 들고 난로 앞에서 C — 넣는다(나무꾼이 집에 있으면 한마디). 난로 앞이 아니면 false(더미·내려놓기로)
func stoke_log(now: float) -> bool:
	if woodcut.is_empty(): return false
	var sp: Dictionary = woodcut["stove"]
	if body.global_position.distance_to(sp["pos"]) > 1.2: return false
	if int(woodcut["fire"]) >= FIRE_MAX: say_toast("The firebox is full."); return true
	var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(body, "position", sp["pos"] + Vector3(0, 0.02, 0), 0.25)
	stoke(player, null)
	use_until = now + HearthPoses.STOKE_T; action_until = use_until
	for r in residents:
		if r.job == "woodcutter" and r.state != "drive" and r.global_position.distance_to(body.global_position) < 6.0:
			r.say(r.mind.line("stoke_watch"), 1.8); break
	return true

## 사람이 그루터기 앞에서 C — 나무꾼이 패거나 오는 중이면 자리는 그의 것. 아니면 그 자리에 서서 두 번 팬다(나무꾼이 근처면 한마디)
func chop_use(sp: Dictionary, now: float) -> void:
	for r in sp.get("taken", []):
		if r != null: return
	var tw := create_tween(); tw.set_ease(Tween.EASE_IN_OUT); tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(body, "position", sp["pos"] + Vector3(0, 0.02, 0), 0.3)
	player.face(sp["yaw"]); player.pose_request = "chop"
	use_until = now + StickPoses.CHOP_T * 2.0; action_until = use_until
	for r in residents:
		if r.job == "woodcutter" and r.state != "drive" and r.global_position.distance_to(body.global_position) < 12.0:
			r.say(r.mind.line("chop_watch"), 1.8); break

## 장작을 들고 더미 앞에서 C — 쌓는다(꽉 찼으면 아래 '내려놓기'로)
func stack_log(now: float) -> bool:
	if woodcut.is_empty() or body.global_position.distance_to((woodcut["pile"] as Dictionary)["pos"]) > 1.4 or not pile_put(): return false
	player.release(self, Vector3.ZERO).queue_free()
	player.action = "grab"; action_until = now + 0.4
	return true

## 매 프레임(town_systems _tick): 누가 패고 있으면 도끼가 그 오른손을 따라가고, 찍기 전엔 그루터기 위에 통나무가 서 있다가 찍는 순간 둘로 갈라져 좌우로 튄다.
## 아무도 없으면 도끼는 그루터기에 꽂힌다. 난로는 _stove
func _woodcut(now: float) -> void:
	if woodcut.is_empty(): return
	_stove()
	var w := woodcutter_at_work()
	var f: Stick3D = w.fig if w != null else null
	if f == null and player.pose_request == "chop" and body.global_position.distance_to((woodcut["work"] as Dictionary)["pos"]) < 1.5: f = player
	var axe: Node3D = woodcut["axe"]; var block: Node3D = woodcut["block"]
	if f == null:
		axe.global_transform = woodcut["rest"]; block.visible = false; woodcut["who"] = null
		return
	if woodcut["who"] != f: woodcut["who"] = f; woodcut["cut"] = -1
	axe.global_transform = f.hand_r.global_transform
	var cyc := int(f.pose_t / StickPoses.CHOP_T); var c := fmod(f.pose_t, StickPoses.CHOP_T)
	var room := loose_logs().size() < LOOSE_MAX
	block.visible = room and c < StickPoses.CHOP_HIT and cyc != int(woodcut["cut"])
	if c < StickPoses.CHOP_HIT or cyc == int(woodcut["cut"]): return
	woodcut["cut"] = cyc
	if not room: return   # 통나무가 없었다 — 빈 그루터기를 찍었을 뿐
	var st: Vector3 = woodcut["stump"]
	for side: float in [-1.0, 1.0]:   # 찍는 사람은 +x 를 본다 — 반쪽은 좌우(±z)로 튄다
		var lg := make_item("log", st + Vector3(0, 0.5, side * 0.06))
		lg.rotation.y = PI / 2.0
		flying.append({ "node": lg, "vel": Vector3(randf_range(-0.2, 0.3), 1.6, side * randf_range(1.0, 1.5)), "spin": side * 5.0 })
	shake(st, 0.05)

## 난로: 밤이고 화실에 장작이 있으면 붙는다(앞창·빛·오두막 굴뚝 연기 — town_critters _smoke 가 집의 "fed" 를 본다). 해 뜨면 밤새 다 타 화실이 빈다.
## 누가 stoke 중이면 앞창 문이 그 사람의 door_k 로 열렸다 닫힌다
func _stove() -> void:
	var night := is_night()
	if night != woodcut["night"]:
		woodcut["night"] = night
		if not night:
			woodcut["fire"] = 0   # 밤새 탄 것 — 오늘 밤 불은 오늘 넣는다
			for e in woodcut["ends"]: (e as Node3D).visible = false
	var lit := night and int(woodcut["fire"]) > 0
	var h: Dictionary = woodcut["house"]
	if lit != bool(h.get("fed", false)):
		h["fed"] = lit
		(woodcut["light"] as OmniLight3D).visible = lit
		var glow: MeshInstance3D = woodcut["glow"]; glow.material_override = glow.get_meta("lit") if lit else glow.get_meta("cold")
	var sk: Variant = woodcut["stoker"]
	var o := 0.0
	if is_instance_valid(sk) and (sk as Stick3D).pose_request == "stoke": o = HearthPoses.door_k((sk as Stick3D).pose_t)
	(woodcut["sdoor"] as Node3D).rotation.y = -1.7 * o
