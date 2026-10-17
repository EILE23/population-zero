class_name ClimbEscape
extends Node3D
## Climb 콘텐츠 팩 '핀 바퀴'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 태엽(Clockwork) 층(바람구멍 층은 뺀다)의 잇단 두 발판 사이 틈(min_gap..max_gap, 위 발판이 min_dy..max_dy 높이; 아래 발판은 still, 위 발판은 부서지거나 튀어도 된다) 한가운데 — 절벽에서 나온 축에 놋쇠 탈진 바퀴(escape wheel)가 걸려 있고, 바닥 핀이 아래 발판 윗면 높이다.
## 반지름은 기하로 정한다: r = min((dy − short_min) / 2, gap / 2 − clear − pin_r) — 꼭대기 핀이 위 발판 밑 short_min..short_max 에 서게(r_min 미만·short_max 초과면 안 건다). 테 둘레에 pins 개의 핀이 등반자 쪽으로 나와 있고 핀이 발판이다.
## 바퀴는 돌지 않고 간다: 탑의 시계 tick_s 마다 핀 하나만큼 step_s 동안 덜컥 전진한다(탈진기의 박자 — 테 위의 앵커가 같이 흔들리며 tick… tock…), 아래 발판 쪽이 오르는 방향으로. 핀에 뛰어 오르면(공중에서 핀 위를 지나거나 catch 안에서 내려서서) 핀과 함께 덜컥덜컥 올라 꼭대기에서 위 발판 밑 short 에 멎는다 — 톡 뛰어 건넌다;
## 그대로 있으면 먼 쪽으로 내려가 밑을 돌아 다시 오른다(떨어뜨리지 않는다). 핀 밖으로 걸어 나가면 off — 맨 떨어짐. 틈을 건너는 맨 점프는 그대로(평이한 결과 100%). 꼭대기를 넘은 타기를 탑의 하루(day_s)마다 세어 쉼터 판이 note(n) 으로 읽는다. 상은 없다.
## 풍차(흐르듯 돈다, 컵이 수평을 지킨다)·파터노스터(멎지 않는다)·뻐꾸기 널(박자에만 발판이다)과 다르다: 이건 멎었다 덜컥, 멎었다 덜컥 하는 첫 발판 — 자세는 jolt(stick3d_jolt.gd — 운영자 보드의 '균형' 가족, log 의 다음).
## 로더가 할 일(climb.gd, 운영자 세션): `var ew := ClimbEscape.new(); add_child(ew); signs.notes.append(ew.note)`; 층을 지을 때 `ew.build(root, ew.plan(n, plats, cg.plan(n, plats) + cpn.plan(n, plats) + pk.plan(n, plats, …) + cl.plan(n, plats, …)))` (톱니 띠·추·뻐꾸기 집·풀무의 계획을 taken 으로 — 그 틈은 비켜 간다); 매 틱 `ew.sync(_t)`;
## 'move' 발판을 옮기는 자리(ny 를 재기 전)에서 `on["kind"] == "escape"` 이면 `var r := ew.ride(on, x, dt, fig); x = r["x"]; y = r["y"]; fig.pose_request = "jolt"; if r["off"]: on = {}; apex = y; fig.pose_request = ""` (핀 밖으로 걸어 나간 몸 — 떨어진다; 뛰어 내려서도 자세를 비운다);
## 착지 판정에서 landed 가 비었고 vy <= 0 이면 `landed = ew.land(x, y, ny, z)` (돌려준 사전의 "y" 가 핀 윗면, "pin" 이 어느 핀인지, "step" 이 참이면 턱에서 내려선 걸음이라 vx 를 0 으로 안 해도 된다).
## 핀 위에선 로더의 '발판 밖으로 나갔나' 검사(x..x+w)를 그대로 둬도 된다 — x/w 가 바퀴의 좌우 폭이라 타는 동안 늘 안이다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_escape.gd

const PACK := "res://data/climb/escape.json"
const C = preload("res://scripts/games/climb.gd")
const TAKEN_UP := 220.0    # taken 조각(띠·추·집·풀무) 위로 비워 두는 높이(px) — 제 꼭대기(len·y_top·b_y)가 더 높으면 그것
const BODY_UP := 50.0      # 꼭대기 핀에 선 몸의 키(px) — 상자 위쪽 여유
const ANCHOR_AMP := 0.22   # 앵커가 박자마다 기우는 각(rad)
const DISC_Z := 0.16       # 바퀴 면이 절벽에서 나온 거리(m) — 핀은 여기서 pin_len 만큼 등반자 쪽으로

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.wheel
var wheels: Array = []          # 지은 바퀴 {id, kind "escape", n, x, y, w, y_top, z, d, hx, cy, r, dir, gap, dy, short, a_id, b_id, a_y, b_y, phase, node, wheel, anchor, tick, tock, step_n, day, over, rode_t}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("wheel", {})

func sync(now: float) -> void:
	t = now

func pins() -> int:
	return maxi(4, int(kind.get("pins", 8)))

func pin_r() -> float:
	return maxf(1.0, float(kind.get("pin_r", 4.0)))

func pin_w() -> float:
	return maxf(4.0, float(kind.get("pin_w", 20.0)))

func pin_len() -> float:
	return maxf(8.0, float(kind.get("pin_len", 24.0)))

func clear() -> float:
	return maxf(0.0, float(kind.get("clear", 4.0)))

func r_min() -> float:
	return maxf(8.0, float(kind.get("r_min", 32.0)))

func short_min() -> float:
	return maxf(0.0, float(kind.get("short_min", 8.0)))

func short_max() -> float:
	return maxf(short_min(), float(kind.get("short_max", 30.0)))

func tick_s() -> float:
	return maxf(0.1, float(kind.get("tick_s", 0.7)))

func step_s() -> float:
	return clampf(float(kind.get("step_s", 0.18)), 0.02, tick_s())

func catch() -> float:
	return maxf(0.0, float(kind.get("catch", 14.0)))

func day_s() -> float:
	return maxf(1.0, float(kind.get("day_s", 600.0)))

## 핀 하나의 각(rad)
func arc() -> float:
	return TAU / pins()

## 탑의 오늘 — 로더의 시계를 day_s 로 나눈 몫
func day() -> int:
	return floori(t / day_s())

## 지금까지 간 걸음 — 몫은 끝난 걸음, 소수는 step_s 동안 smoothstep 으로 가는 이번 걸음(같은 시각엔 누구에게나 같은 값)
func steps(at: float) -> float:
	var n := floorf(at / tick_s())
	var u := clampf((at - n * tick_s()) / step_s(), 0.0, 1.0)
	return n + smoothstep(0.0, 1.0, u)

## 마지막 덜컥 뒤 흐른 시간(s) — 자세가 읽는다
func since(at: float) -> float:
	return at - floorf(at / tick_s()) * tick_s()

## 핀 k 의 각 — 바닥에서 아래 발판 쪽으로 올라가는 쪽이 양수(rad)
func ang(s: Dictionary, k: int, at: float) -> float:
	return float(s.get("phase", 0.0)) + (steps(at) + k) * arc()

## 핀 k 의 가운데 자리(px) — 바닥(hx, cy − r)에서 a 쪽으로 각만큼 돈 자리(dir 는 a 에서 b 쪽: b 가 오른쪽이면 +1 이니 a 쪽은 −dir)
func pin(s: Dictionary, k: int, at: float) -> Vector2:
	var a := ang(s, k, at); var rr := float(s["r"])
	return Vector2(float(s["hx"]) - float(s["dir"]) * rr * sin(a), float(s["cy"]) - rr * cos(a))

## 핀 k 가 가는 방향(단위, x 는 +x 로 가면 양수, y 는 오르면 양수) — d/dφ 의 방향
func heading(s: Dictionary, k: int, at: float) -> Vector2:
	var a := ang(s, k, at)
	return Vector2(-float(s["dir"]) * cos(a), sin(a))

## 층 n(테마 층, 조각의 not 규칙)의 잇단 두 발판(조각의 on·to; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 min_dy..max_dy 높으며 바퀴의 원을 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := float(kind.get("min_gap", 90.0)); var max_gap := float(kind.get("max_gap", 220.0))
	var min_dy := float(kind.get("min_dy", 60.0)); var max_dy := float(kind.get("max_dy", 150.0))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var skip: Dictionary = piece.get("not", {})
		if not skip.is_empty() and _on(n, skip): continue
		var kinds: Array = piece.get("on", ["std", "ice"]); var to: Array = piece.get("to", kinds)   # on: 뛰어 오르는 아래 발판(still 만), to: 뛰어 건너는 위 발판(부서지거나 튀어도 된다)
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var found: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in to): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < min_dy or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0   # a 에서 b 쪽 — b 가 오른쪽이면 +x
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var rr := minf((dy - short_min()) / 2.0, gap / 2.0 - clear() - pin_r())   # 꼭대기 핀이 위 발판 밑 short_min 에, 테가 두 턱에서 clear 떨어지게
			if rr < r_min(): continue
			var short := dy - rr * 2.0
			if short > short_max(): continue   # 틈이 좁아 바퀴가 작다 — 꼭대기에서 위 발판이 너무 멀다
			var hx := (ax1 + bx0) / 2.0 if dir > 0.0 else (bx1 + ax0) / 2.0
			var cy := float(a["y"]) + rr
			var reach := rr + pin_r() + 10.0
			if not _clear(plats, a, b, hx - reach, hx + reach, cy - reach, cy + reach + BODY_UP): continue
			if not _free(taken, hx - reach, hx + reach, cy - reach, cy + reach + BODY_UP): continue
			found.append({ "gap": gap, "dy": dy, "dir": dir, "hx": hx, "cy": cy, "r": rr, "short": short, "a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			var half := float(g["r"]) + pin_r()
			s["id"] = "%d.E%d" % [n, i]; s["kind"] = "escape"; s["n"] = n
			s["x"] = float(g["hx"]) - half; s["w"] = half * 2.0; s["y"] = float(g["a_y"]); s["y_top"] = float(g["cy"]) + half   # x·w·y·y_top: 다른 팩의 _free 가 읽는 바퀴의 상자
			s["z"] = C.PLAYER_Z; s["d"] = pin_len(); s["phase"] = float(piece.get("phase", 0.0))
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 바퀴의 상자(테 + 핀 + 손 하나, 꼭대기의 몸까지)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var amp := float(p.get("amp", 0.0))
		var px0 := float(p["x"]) - amp - 10.0; var px1 := float(p["x"]) + float(p["w"]) + amp + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: x·w·y, 있으면 px·hx·a_edge·b_edge 로 넓어지고 len·y_top·b_y 로 높아진다)이 바퀴의 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)); var qx1 := qx0 + float(q.get("w", 0.0))
		for key: String in ["px", "hx", "a_edge", "b_edge"]:
			if q.has(key): qx0 = minf(qx0, float(q[key])); qx1 = maxf(qx1, float(q[key]))
		var qy := float(q.get("y", 0.0)); var qy1 := qy + TAKEN_UP
		if q.has("len"): qy1 = maxf(qy1, qy + float(q["len"]) + 10.0)
		for key: String in ["y_top", "b_y"]:
			if q.has(key): qy1 = maxf(qy1, float(q[key]) + 60.0)
		if x1 > qx0 - 10.0 and x0 < qx1 + 10.0 and yhi > qy - 10.0 and ylo < qy1: return false
	return true

## 로더의 착지 판정 뒤에 — 이 틱에 핀 윗면을 지나 떨어지는 몸, 또는 그 위 catch px 안에서 내려서는 몸(턱에서 핀으로 걸어 내려가는 걸음)을 받는다. 핀 가운데에서 pin_w / 2 안의 x 만
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	for sv in wheels:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		for k in pins():
			var p := pin(s, k, t)
			if absf(x - p.x) > pin_w() / 2.0: continue
			var sy := p.y + pin_r()
			var cross := y >= sy and ny <= sy
			var step := not cross and ny < y and y > sy and y - sy <= catch()
			if not (cross or step): continue
			var hit := s.duplicate(); hit["y"] = sy; hit["pin"] = k; hit["step"] = step
			return hit
	return {}

## 서 있는 매 틱 — 핀과 함께 덜컥 간 자리 {x, y, off}: 핀 위의 제자리(가운데에서의 치우침)를 지키며 x·y 가 바뀐다(걸으면 치우침이 바뀐다); 핀 밖으로 나가면 off. 꼭대기(각 π)를 넘으면 오늘의 수에 하나(count). fig 가 있으면 자세가 읽을 박자와 방향을 적어 준다
func ride(on: Dictionary, x: float, dt: float, fig: Stick3D = null, count := true) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "x": x, "y": float(on.get("y", 0.0)), "off": true }
	var k := int(on.get("pin", 0))
	var was := pin(s, k, t - dt); var now := pin(s, k, t)
	var side := x - was.x
	var off := absf(side) > pin_w() / 2.0 + 4.0
	if count and fposmod(ang(s, k, t - dt), TAU) < PI and fposmod(ang(s, k, t), TAU) >= PI:   # 꼭대기를 넘었다 — 오늘의 수에 하나
		_day(s); s["over"] = int(s["over"]) + 1
	s["rode_t"] = t
	if fig:
		var h := heading(s, k, t)
		fig.set_meta("jolt_t", since(t)); fig.set_meta("jolt_dx", h.x); fig.set_meta("jolt_dy", h.y)
	return { "x": now.x + side, "y": now.y + pin_r(), "off": off }

func _find(id: String) -> Dictionary:
	for sv in wheels:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _day(s: Dictionary) -> void:
	if int(s["day"]) != day(): s["day"] = day(); s["over"] = 0

## n0..n1 층의 바퀴가 오늘 센 것 — {over, wheels}
func today(n0: int, n1: int) -> Dictionary:
	var over := 0; var count := 0
	for sv in wheels:
		var s: Dictionary = sv
		if int(s["n"]) < n0 or int(s["n"]) > n1: continue
		count += 1
		if int(s["day"]) == day(): over += int(s["over"])
	return { "over": over, "wheels": count }

## 쉼터 판(n 층)에 붙는 줄 — 위 다섯 층(n..n+4)의 바퀴, 없으면 아래 다섯 층(n−5..n−1), 그것도 없으면 빈 줄. climb_signs.notes 에 넣는다
func note(n: int) -> String:
	for span: Array in [[n, n + 4], [n - 5, n - 1]]:
		var v := today(int(span[0]), int(span[1]))
		if int(v["wheels"]) > 0:
			var k := int(v["over"])
			return "Pin wheel, floors %d–%d: %d %s over the top today." % [int(span[0]), int(span[1]), k, "ride" if k == 1 else "rides"]
	return ""

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 바퀴를 지금 각으로, 앵커를 박자에 — 걸음이 바뀌는 프레임에 tick 과 tock 을 번갈아. 빈 바퀴도 간다(시계니까)
func _process(delta: float) -> void:
	t += delta
	wheels = wheels.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_windmill 과 같은 식)
	for sv in wheels:
		var s: Dictionary = sv
		var n_now := floori(t / tick_s())
		if n_now != int(s["step_n"]):
			s["step_n"] = n_now
			_play((s["tick"] if n_now % 2 == 0 else s["tock"]) as AudioStreamPlayer3D)
		_place(s)

## 바퀴 노드의 돌림 — 핀 k 를 제 각(k·arc)에 두었으니 노드를 −dir·(phase + steps·arc) 돌리면 세상의 pin() 자리와 맞는다; 앵커는 걸음마다 반대로 기운다(같은 smoothstep)
func _place(s: Dictionary) -> void:
	(s["wheel"] as Node3D).rotation.z = -float(s["dir"]) * (float(s["phase"]) + steps(t) * arc())
	(s["anchor"] as Node3D).rotation.z = ANCHOR_AMP * cos(PI * steps(t))

## 바퀴를 짓는다 — root 는 그 층의 노드. 노드 원점은 축(hx, cy, 절벽); 절벽에서 나오는 축대, 테, 놋쇠 판, 축머리, 도는 바퀴(살 넷 + 핀마다 놋쇠 핀과 포도빛 머리), 테 위의 앵커(받침 + 두 팔레트), 소리 둘
func build(root: Node3D, planned: Array) -> void:
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var rr := float(s["r"]) * C.K
		var pr := pin_r() * C.K; var pl := pin_len() * C.K
		var node := Node3D.new(); node.position = C.to3(float(s["hx"]), float(s["cy"]), C.WALL_Z * C.K); root.add_child(node)
		var brass := _mat(Color("c9a35a")); var dark := _mat(Color("8a6a4a")); var iron := _mat(Color("4a4a52")); var ink := _mat(Color("2f2a4e")); var cap := _mat(Color("ad7096"))
		_box(node, Vector3(0.1, 0.1, DISC_Z + 0.1), iron).position = Vector3(0.0, 0.0, DISC_Z / 2.0)   # 축대 — 절벽에서 바퀴 면까지
		_cyl(node, rr + pr * 0.6, 0.06, dark).position = Vector3(0.0, 0.0, DISC_Z - 0.02)   # 테 — 판 뒤에서 조금 넓게
		_cyl(node, rr, 0.1, brass).position = Vector3(0.0, 0.0, DISC_Z)                     # 놋쇠 판
		_cyl(node, 0.12, 0.14, iron).position = Vector3(0.0, 0.0, DISC_Z + 0.04)            # 축머리
		var wheel := Node3D.new(); wheel.position = Vector3(0.0, 0.0, DISC_Z); node.add_child(wheel)   # 도는 것 — 살과 핀
		for i in 4:
			var spoke := _box(wheel, Vector3(rr * 1.8, 0.04, 0.02), ink)   # 잉크 살 넷 — 도는 게 보이게(판 면 위)
			spoke.rotation.z = i * PI / 4.0; spoke.position.z = 0.06
		for k in pins():
			var a := k * arc()
			var pin_n := _cyl(wheel, pr, pl, brass)   # 핀 — 등반자 쪽으로 나온 놋쇠 가로대, 몸은 그 위에 선다
			pin_n.position = Vector3(-float(s["dir"]) * rr * sin(a), -rr * cos(a), 0.05 + pl / 2.0)
			_cyl(pin_n, pr * 1.3, 0.02, cap, false).position = Vector3(0.0, pl / 2.0, 0.0)   # 포도빛 머리 — 선 자리의 점(핀의 축 y 를 따라 끝에, 핀과 같은 방향이라 안 돌린다)
		var anchor := Node3D.new(); anchor.position = Vector3(0.0, rr + pr + 14.0 * C.K, DISC_Z + 0.1); node.add_child(anchor)   # 앵커 — 테 위에서 박자마다 기운다
		_box(anchor, Vector3(0.06, 0.2, 0.05), iron).position = Vector3(0.0, 0.1, 0.0)   # 받침 — 위로 짧게
		for sx: float in [-1.0, 1.0]:
			var pal := _box(anchor, Vector3(0.05, rr * 0.45, 0.05), dark)   # 팔레트 둘 — 테를 향해 내려오는 팔
			pal.position = Vector3(sx * rr * 0.3, -rr * 0.18, 0.0); pal.rotation.z = -sx * 0.55
		s["node"] = node; s["wheel"] = wheel; s["anchor"] = anchor; s["step_n"] = -1
		s["day"] = -1; s["over"] = 0; s["rode_t"] = -99.0
		s["tick"] = _snd(node, float(kind.get("tick_hz", 1500)), 0.03, -14.0); s["tock"] = _snd(node, float(kind.get("tock_hz", 1150)), 0.03, -14.0)
		wheels.append(s)
		_place(s)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 원기둥(반지름 r, 길이 h) — turn 이면 x 로 돌려 z 축을 따라 선다(판·테·핀), 아니면 제 축(y)대로(핀 머리 — 핀의 아이라 이미 돌아 있다)
func _cyl(parent: Node3D, r: float, h: float, m: StandardMaterial3D, turn := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new()
	cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = 16; cm.rings = 1
	mi.mesh = cm; mi.material_override = m
	if turn: mi.rotation.x = PI / 2.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi); return mi

func _snd(parent: Node3D, hz: float, secs: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — 아주 짧은 기음이 잦아든다: tick(1500 Hz)·tock(1150 Hz), 0.03초 — 탈진기의 두 클릭. 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var n := int(rate * secs)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var k := float(i) / n
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.6 + sin(ph * 3.1) * 0.15) * exp(-k * 9.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
