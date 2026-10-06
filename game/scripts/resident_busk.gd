class_name ResidentBusk
extends ResidentTill
## 악사와 모자("Money in hands" 3조각, run 111 — town_busk): 악사(job "busker")는 칸이 열리면 상자로 가 올라서서 세트가 끝날 때까지 strum(stick3d_busk.gd); 끝나면(또는 끊기면) 모자의 동전을
## stoop 으로 제 주머니에(palm_till 의 사슬, 자세만 stoop — 사람이 빈 모자를 거둘 때와 같다). 듣다 내기로 한 주민(meta "tip" = 세트 번호, town_busk _busk_listen)은 모자 앞으로 와
## stoop 으로 한 닢(town.tip — 사람의 C 와 같은 시계). 사슬: … → sunroom → till → **busk** → ledger(resident_ledger.gd, 외상 장부 — run 112) → resident

func _post_pick(now: float) -> bool:
	return _busk_pick(now) or super._post_pick(now)

func _post_arrive(now: float) -> bool:
	return _busk_arrive(now) or super._post_arrive(now)

## 상자로(악사, 칸이 열렸을 때) · 모자로(악사: 세트 뒤 동전이 남았을 때, 손님: tip 표가 이 세트 것이고 아직 치는 중일 때). 못 가면 false(_pick_spot 이 다음 규칙으로)
func _busk_pick(now: float) -> bool:
	var bk: Dictionary = town.busk
	if bk.is_empty() or fig.carrying != null: return false
	var hat: Dictionary = bk["hat"]; var sp: Dictionary = {}
	if job == "busker":
		if town.busk_open() and _free_slot(bk["stage"]) >= 0: sp = bk["stage"]
		elif bk["on"] == null and int(hat["till"]) > 0 and _free_slot(hat) >= 0: sp = hat
	elif int(get_meta("tip", -1)) == int(bk["n"]) and bk["on"] != null and coins > 0 and _free_slot(hat) >= 0:
		sp = hat; set_meta("tip", -1)
	if sp.is_empty(): return false
	slot = 0; spot = sp; _claim(sp, 0)
	var at: Vector3 = sp["pos"]
	route = town.via_bridge(global_position, [{ "pos": Vector3(at.x, 0.0, at.z + (0.9 if sp["kind"] == "stage" else 0.0)), "act": "" }])   # 상자는 앞(남쪽)에서 다가가 올라선다
	target = route[0]["pos"]; state = "walk"; busy_until = now
	return true

## 닿음(resident.gd _arrive 의 기본 가지): 상자면 올라서서 strum(세트 끝 + 내리는 0.4 까지 busy), 모자면 악사는 거두고(하나에 STOOP_T) 손님은 한 닢. 오는 사이 사정이 바뀌었으면 잠깐 보고 간다
func _busk_arrive(now: float) -> bool:
	var k: String = spot.get("kind", "")
	if k != "stage" and k != "hat": return false
	var bk: Dictionary = town.busk; var hat: Dictionary = bk["hat"]
	fig.face(spot.get("yaw", PI))
	if k == "stage":
		if not town.busk_open():
			busy_until = now + 1.0; return true   # 칸이 닫혔거나 사람이 올라섰다
		global_position = (spot["pos"] as Vector3) + Vector3(0, 0.02, 0)
		fig.pose_request = "strum"
		busy_until = float(town.busk_start(self, now)) + BuskPoses.STRUM_OUT + 0.2
		say(mind.line("busk_set"), 1.8)
		return true
	var n := int(hat["till"])
	if job == "busker":
		if n <= 0 or bk["on"] != null:
			busy_until = now + 1.0; return true
		fig.pose_request = "stoop"; busy_until = now + CoinPoses.STOOP_T * n + 0.6
		town.palm_till(fig, hat, self, "stoop"); say(mind.line("till_close"), 1.8)
		return true
	if coins <= 0 or bk["on"] == null:
		busy_until = now + 1.0; return true
	fig.pose_request = "stoop"; busy_until = now + CoinPoses.STOOP_T + 0.3
	town.tip(fig, self)
	return true
