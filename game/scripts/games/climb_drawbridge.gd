class_name ClimbDrawbridge
extends Node3D
## Climb 콘텐츠 팩 '도개교'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 옛 회관(Old hall) 층(바람구멍 층은 뺀다)의 잇단 두 still 발판 사이 틈 — 아래 발판의 틈 쪽 가장자리에 경첩을 단 널(plank)이 하늘로 곧추서 있고, 그 끝에서 사슬이 가장자리 안 inset 의 윈치 기둥(북·손잡이·뒤에 매단 돌 추)으로 온다.
## 아래 발판에서 윈치 옆에 서서 C 를 쥐면(몸이 기둥에서 reach 안) 북을 감는다: lower_s 에 걸쳐 널이 틈 위로 내려오고(반 바퀴마다 래칫 click, 모두 turns 바퀴), 쿵(thud) 눕는다 — 윗면은 발판과 같은 높이, 끝은 위 발판 가장자리 밑 clear 앞. hold_s 동안 걸어 건너는 다리: 끝에서 위 발판까지는 틈 없이 높이만 남는다. 그 뒤 추가 raise_s 에 걸쳐 도로 세운다.
## 세워지는 널 위에 아직 선 몸은 기운 널을 따라 발판으로 미끄러져 내려온다(맨 결과: slide × sin(기운 각) px/s — 다치지도 떨어지지도 않는다; 끝이나 경첩 밖으로 걸어 나가면 여느 발판 끝처럼 밑으로 떨어진다). 다 눕기 전에 C 를 놓으면 추가 그 자리에서 도로 끌어올린다(creak).
## 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 틈을 건너는 맨 점프는 그대로, 윈치 기둥은 걷는 선 뒤에 서서 아무것도 막지 않고, 널은 누워 있는 동안만 발판이다. 쓰기 전에 발판에서 손으로 일을 하는 첫 팩.
## 감는 자세는 crank(stick3d_crank.gd — 운영자 보드의 '손잡이 돌리기' 가족: 두 손이 가슴 높이의 손잡이를 쥐고 돌며 몸이 한 바퀴마다 기울고 한 발을 버틴다; 미끄러질 땐 두 팔을 벌리고 다리를 뻗은 채 뒤로 젖힌다).
## shunt(서가를 민다)·heave(머리 위 줄을 당긴다)·tug(버너 줄을 홱 당긴다)와 다르다: 이건 제자리에서 돌리는 두 손, 일의 길이가 손의 것이다.
## 로더가 할 일(climb.gd, 운영자 세션): `var dw := ClimbDrawbridge.new(); add_child(dw)`; 층을 지을 때 `var bl := cb.plan(n, plats); var dr := cr.plan(n, plats, bl); dw.build(root, dw.plan(n, plats, bl + dr + cl.plan(n, plats, bl + dr)))` (종 줄·회전문·빨랫줄의 계획을 taken 으로 — 그 틈은 비켜 간다); 매 틱 `dw.sync(_t)`;
## 발판에 선 틱의 걷기 자리(`_physics_process` 의 `else:` — target 을 정하기 전): `var r := dw.crank(on, x, z, dir, Input.is_action_pressed("act"), dt, fig); if r["cranking"]: x = r["x"]; vx = 0.0; fig.pose_request = "crank"; elif fig.pose_request == "crank" and not bool(fig.get_meta("crank_slide", 0.0)): fig.pose_request = ""`;
## 로더 자신의 착지 판정이 비면 `landed = dw.land(x, y, ny, z)` (kind "drawbridge" — 누운 널의 윗면, 발판과 같은 높이);
## `on["kind"] == "drawbridge"` 인 매 틱, 'move' 발판 자리에서: `var r := dw.stand(on, x, dt, fig); x = r["x"]; y = r["y"]; if r["slide"]: fig.pose_request = "crank"; if r["off"]: on = {}; apex = y; fig.pose_request = ""` — stand 가 on["x"]·on["w"] 를 기운 널의 자리로 고쳐 쓰니 로더 자신의 떠남 판정은 그대로 둔다.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_drawbridge.gd

const PACK := "res://data/climb/drawbridge.json"
const C = preload("res://scripts/games/climb.gd")
const TAKEN_UP := 140.0    # taken 조각(종 줄·회전문·빨랫줄 말뚝) 위로 비워 두는 높이(px)
const LET_GO_T := 0.35     # 감는 틱이 이만큼 끊기면(뛰었다, 떠났다) 손을 뗀 것
const BODY_UP := 50.0      # 널 위에 선 몸의 키(px) — 상자 위쪽 여유
const POST_Z := 10.0       # 윈치 기둥이 절벽 면에서 나온 깊이(px) — 걷는 선(PLAYER_Z) 뒤
const PLANK_D := 0.6       # 널의 앞뒤 폭(m)

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.span
var spans: Array = []           # 지은 도개교 {id, kind "drawbridge", x, y, w, z, d, dir, gap, hinge_x, tip_x, post_x, len, a_id, b_id, a_y, b_y, node, pivot, chain, drum, weight, click, thud, creak, state, k, t_flat, k_rel, t_rel, cranking, last, clicks}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("span", {})

func sync(now: float) -> void:
	t = now
	for sv in spans:   # 감는 틱이 끊겼으면(뛰었다, 떠났다) 손을 뗀 것
		var s: Dictionary = sv
		if bool(s["cranking"]) and t - float(s["last"]) > LET_GO_T: _release(s)

func inset() -> float:
	return maxf(0.0, float(kind.get("inset", 24.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 18.0)))

func clear_px() -> float:
	return maxf(0.0, float(kind.get("clear", 8.0)))

func plank_th() -> float:
	return maxf(1.0, float(kind.get("plank_th", 6.0)))

func deck_d() -> float:
	return maxf(2.0, float(kind.get("deck_d", 24.0)))

func lower_s() -> float:
	return maxf(0.05, float(kind.get("lower_s", 1.5)))

func hold_s() -> float:
	return maxf(0.0, float(kind.get("hold_s", 6.0)))

func raise_s() -> float:
	return maxf(0.05, float(kind.get("raise_s", 2.0)))

func turns() -> float:
	return maxf(1.0, float(kind.get("turns", 3)))

func slide() -> float:
	return maxf(0.0, float(kind.get("slide", 300.0)))

## 널이 누운 정도 0..1(0 곧추섬, 1 누움) — at 때. 감는 동안은 s.k, 누운 뒤엔 hold_s 쉬고 raise_s 에 걸쳐 0 으로, 일찍 놓았으면 그 자리에서 raise_s × k 에 걸쳐 0 으로
func k_at(s: Dictionary, at: float) -> float:
	match String(s["state"]):
		"lowering": return float(s["k"])
		"down":
			var dk := (at - float(s["t_flat"]) - hold_s()) / raise_s()
			return 1.0 if dk <= 0.0 else maxf(0.0, 1.0 - dk)
		"back": return maxf(0.0, float(s["k_rel"]) - (at - float(s["t_rel"])) / raise_s())
	return 0.0

## 지금 널의 형편 — "up"(곧추섬)·"lowering"(감는 중)·"down"(누워 있다)·"raising"(추가 세우는 중)
func phase(s: Dictionary, at: float) -> String:
	var st := String(s["state"])
	if st == "lowering": return st
	var k := k_at(s, at)
	if k <= 0.0: return "up"
	if st == "down" and k >= 1.0: return "down"
	return "raising"

## 널이 기운 각(rad; 0 누움, π/2 곧추섬)
func tilt(s: Dictionary, at: float) -> float:
	return (1.0 - k_at(s, at)) * PI / 2.0

## 도로 선 널은 쉰다; 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	spans = spans.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_laundry 와 같은 식)
	for sv in spans:
		var s: Dictionary = sv
		if bool(s["cranking"]) and t - float(s["last"]) > LET_GO_T: _release(s)
		if String(s["state"]) != "lowering" and k_at(s, t) <= 0.0: s["state"] = "up"
		_place(s)

## 층 n(테마 층만, 바람구멍 층은 뺀다)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 min_dy..max_dy 높으며 널 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나 — 거기에 도개교. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := float(kind.get("min_gap", 70.0)); var max_gap := float(kind.get("max_gap", 220.0))
	var min_dy := float(kind.get("min_dy", 60.0)); var max_dy := float(kind.get("max_dy", 150.0))
	var ins := inset(); var cl := clear_px()
	var room := ins + 2.0 * C.HW + reach() + 4.0   # 기둥과 그 뒤에 서서 감는 몸이 들어갈 발판 폭
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std", "ice"])
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var found: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < min_dy or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0   # 아래 발판에서 위 발판 쪽 — 위가 오른쪽이면 널은 +x 로 눕는다
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			if float(a["w"]) < room: continue
			var hinge := ax1 if dir > 0.0 else ax0
			var ln := gap - cl
			var tip := hinge + dir * ln; var post := hinge - dir * ins
			var x0 := (post - C.HW - reach() - 4.0) if dir > 0.0 else (tip - 4.0)   # 기둥 뒤에 선 몸부터 널 끝까지
			var x1 := (tip + 4.0) if dir > 0.0 else (post + C.HW + reach() + 4.0)
			if not _clear(plats, a, b, x0, x1, float(a["y"]) + 1.0, float(a["y"]) + ln + BODY_UP): continue
			if not _free(taken, x0, x1, float(a["y"]) + 1.0, float(a["y"]) + ln + BODY_UP): continue
			found.append({ "gap": gap, "dir": dir, "hinge_x": hinge, "tip_x": tip, "post_x": post, "len": ln,
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.D%d" % [n, i]; s["kind"] = "drawbridge"; s["x"] = minf(float(g["hinge_x"]), float(g["tip_x"])); s["w"] = float(g["len"]); s["y"] = float(g["a_y"]); s["z"] = C.PLAYER_Z; s["d"] = deck_d()
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 널 상자(윈치 뒤의 몸..위 발판 가장자리, 아래 발판 윗면..곧추선 널 끝 + 몸)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x·w·y)이 널 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - 10.0; var qy1 := qy + TAKEN_UP
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 발판에 선 틱 — on 이 널의 아래 발판이고 C 를 쥔 채 몸이 기둥에서 HW + reach 안이면 감는다: {cranking, x} 의 x 는 기둥 뒤(틈 반대쪽)에 붙어 선 몸의 자리. 누운 널은 더 감기지 않는다. 아니면 {cranking false}
## fig 가 있으면 자세의 메타를 적는다: crank_ph 손잡이의 각 0..1(한 바퀴마다), crank_slide 0
func crank(on: Dictionary, x: float, z: float, _dir: float, held: bool, dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _reached(on, x, z) if held and not on.is_empty() else {}
	for sv in spans:   # 이 틱에 감지 않는 윈치는 손을 뗀 것 — 바로 놓인다
		if bool((sv as Dictionary)["cranking"]) and sv != s: _release(sv)
	if s.is_empty() or phase(s, t) == "down": return { "cranking": false, "x": x }
	if not bool(s["cranking"]):
		s["k"] = k_at(s, t); s["state"] = "lowering"; s["cranking"] = true; s["clicks"] = floori(float(s["k"]) * turns() * 2.0)   # 세워지던 널은 그 자리에서 다시 감긴다(k 는 state 를 바꾸기 전에 읽는다)
	s["last"] = t
	var k := minf(1.0, float(s["k"]) + dt / lower_s())
	if k >= 1.0 - 0.0001: k = 1.0   # 틱의 합이 1 에 모자라도 눕는다(0.0625/1.5 × 24 는 1 에서 ε 빠진다)
	s["k"] = k
	var n := floori(k * turns() * 2.0 + 0.0001)   # 반 바퀴마다 래칫 — 반 바퀴 틱의 ε 도 센다
	while int(s["clicks"]) < n: s["clicks"] = int(s["clicks"]) + 1; _play(s["click"])
	if k >= 1.0:
		s["state"] = "down"; s["t_flat"] = t; s["cranking"] = false; _play(s["thud"])
	if fig: fig.set_meta("crank_ph", fposmod(k * turns(), 1.0)); fig.set_meta("crank_slide", 0.0)
	return { "cranking": true, "x": float(s["post_x"]) - float(s["dir"]) * (C.HW + 6.0) }

## on 이 아래 발판이고 몸이 기둥에서 HW + reach 안인 도개교 — 없으면 빈 사전
func _reached(on: Dictionary, x: float, z: float) -> Dictionary:
	for sv in spans:
		var s: Dictionary = sv
		if String(on.get("id", "")) != String(s["a_id"]): continue
		if absf(z - float(s["z"])) >= deck_d() / 2.0 + C.HZ: continue
		if absf(x - float(s["post_x"])) <= C.HW + reach(): return s
	return {}

## 로더 자신의 착지 판정이 빈 뒤 — 누운 널의 윗면을 떨어지는 몸이 지나면 올라선다: {kind "drawbridge", id, x, y, w, z, d}. 세워진·감기는·세워지는 널은 발판이 아니다
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	for sv in spans:
		var s: Dictionary = sv
		if phase(s, t) != "down": continue
		var top := float(s["a_y"])
		if y < top - 0.5 or ny > top: continue
		if absf(z - float(s["z"])) >= deck_d() / 2.0 + C.HZ: continue
		var x0 := float(s["x"]); var x1 := x0 + float(s["len"])
		if x + C.HW <= x0 or x - C.HW >= x1: continue
		return { "kind": "drawbridge", "id": String(s["id"]), "x": x0, "y": top, "w": float(s["len"]), "z": float(s["z"]), "d": deck_d() }
	return {}

## 널 위에 선 매 틱 — {x, y, off, slide}: 누워 있으면 그대로; 세워지는 동안은 기운 널을 따라 경첩 쪽으로 미끄러진다(slide × sin(각) px/s, 자세의 slide 모드) — 경첩에 닿으면 발판 위에 서고 off. on["x"]·on["w"] 를 기운 널의 자리로 고쳐 쓴다(로더의 떠남 판정이 그대로 버틴다)
## fig 가 있으면 자세의 메타를 적는다: crank_slide 1(미끄러지는 동안), crank_tilt 널의 각(rad); 끝나면 지운다
func stand(on: Dictionary, x: float, dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "x": x, "y": float(on.get("y", 0.0)), "off": true, "slide": false }
	var ph := phase(s, t); var top := float(s["a_y"])
	if ph == "down":
		on.erase("dist")   # 누운 널 위에선 걷는다 — 미끄러진 거리는 없다
		return { "x": x, "y": top, "off": false, "slide": false }
	var dir := float(s["dir"]); var hinge := float(s["hinge_x"]); var ln := float(s["len"])
	var th := tilt(s, t)
	var dist := float(on["dist"]) if on.has("dist") else clampf(dir * (x - hinge), 0.0, ln)   # 널을 따라 잰 거리 — x 는 그 cos 배라 x 에서 되읽으면 틱마다 줄어든다
	dist = maxf(0.0, dist - slide() * sin(th) * dt)
	if ph != "raising" or dist <= 0.001:
		if fig: _clear_metas(fig)
		on.erase("dist")
		return { "x": hinge - dir * (C.HW + 1.0), "y": top, "off": true, "slide": false }
	on["dist"] = dist
	var nx := hinge + dir * dist * cos(th)
	on["x"] = minf(hinge, hinge + dir * ln * cos(th)) - 1.0; on["w"] = ln * cos(th) + 2.0
	if fig: fig.set_meta("crank_slide", 1.0); fig.set_meta("crank_tilt", th)
	return { "x": nx, "y": top + dist * sin(th), "off": false, "slide": true }

## 손을 뗀다 — 감던 널은 그 자리에서 추가 도로 세운다(creak)
func _release(s: Dictionary) -> void:
	s["cranking"] = false
	if String(s["state"]) == "lowering":
		s["state"] = "back"; s["k_rel"] = float(s["k"]); s["t_rel"] = t
		_play(s["creak"])

static func _clear_metas(fig: Stick3D) -> void:
	for m in ["crank_ph", "crank_slide", "crank_tilt"]:
		if fig.has_meta(m): fig.remove_meta(m)

func _find(id: String) -> Dictionary:
	for sv in spans:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 도개교를 짓는다 — root 는 그 층의 노드. 노드 원점은 경첩(hinge_x, a_y, PLAYER_Z); 경첩 축(pivot: 널·가로장 둘·끝의 띠), 경첩 받침, 윈치 기둥·북·손잡이·돌 추(절벽 쪽 POST_Z), 사슬(북 꼭대기→널 끝 — _place 가 길이·각을 맞춘다), click·thud·creak
func build(root: Node3D, planned: Array) -> void:
	var th := plank_th() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var dir := float(s["dir"]); var ln := float(s["len"]) * C.K
		var node := Node3D.new(); node.position = C.to3(float(s["hinge_x"]), float(s["a_y"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("8a6a4a")); var dark := _mat(Color("5e4432")); var iron := _mat(Color("4a4650")); var stone := _mat(Color("8a7f86")); var plate := _mat(Color("ad7096"))
		var pivot := Node3D.new(); node.add_child(pivot)                                                       # 경첩 축 — rotation.z 가 널의 각
		_box(pivot, Vector3(ln, th, PLANK_D), wood).position = Vector3(dir * ln / 2.0, -th / 2.0, 0)             # 널 — 윗면이 발판과 같은 높이
		for q in [0.3, 0.7]:
			_box(pivot, Vector3(0.05, th + 0.02, PLANK_D + 0.04), dark).position = Vector3(dir * ln * (q as float), -th / 2.0, 0)   # 가로장
		_box(pivot, Vector3(0.06, th + 0.01, PLANK_D + 0.02), plate).position = Vector3(dir * (ln - 0.05), -th / 2.0, 0)     # 끝의 띠 — 강조색만
		_box(node, Vector3(0.1, 0.05, PLANK_D + 0.08), iron).position = Vector3(-dir * 0.03, 0.025, 0)       # 경첩 받침
		var pz := (C.WALL_Z + POST_Z - C.PLAYER_Z) * C.K                                                       # 기둥은 절벽 쪽, 걷는 선 뒤
		var px := -dir * inset() * C.K; var ph := float(kind.get("post_h", 40.0)) * C.K; var dr := float(kind.get("drum_r", 7.0)) * C.K
		_box(node, Vector3(0.1, ph, 0.1), dark).position = Vector3(px, ph / 2.0, pz)                           # 윈치 기둥
		var drum := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = dr; cm.bottom_radius = dr; cm.height = 0.16; cm.radial_segments = 10; drum.mesh = cm
		drum.material_override = wood; drum.rotation.x = PI / 2.0; drum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drum.position = Vector3(px, ph, pz); node.add_child(drum)                                              # 북 — 축이 앞뒤(z)
		_box(drum, Vector3(0.04, dr + 0.06, 0.03), iron).position = Vector3(0, (dr + 0.06) / 2.0, 0.1)         # 손잡이 — 북과 같이 돈다
		var weight := _box(node, Vector3(float(kind.get("weight", 14.0)) * C.K, float(kind.get("weight", 14.0)) * C.K, 0.2), stone)   # 돌 추 — 널이 눕는 만큼 내려간다
		weight.position = Vector3(px - dir * 0.3, ph - 0.2, pz)
		var chain := _box(node, Vector3(0.02, 1.0, 0.02), iron)                                                # 사슬 — 길이·각은 _place
		var click := AudioStreamPlayer3D.new(); click.stream = _tick_wav(float(kind.get("click_hz", 320)), 0.04); click.volume_db = -14.0; click.unit_size = 6.0; click.max_distance = 30.0; node.add_child(click)
		var thud := AudioStreamPlayer3D.new(); thud.stream = _tick_wav(float(kind.get("thud_hz", 110)), 0.12); thud.volume_db = -8.0; thud.unit_size = 6.0; thud.max_distance = 30.0; node.add_child(thud)
		var creak := AudioStreamPlayer3D.new(); creak.stream = _tick_wav(float(kind.get("creak_hz", 140)), 0.15); creak.volume_db = -12.0; creak.unit_size = 6.0; creak.max_distance = 30.0; node.add_child(creak)
		s["node"] = node; s["pivot"] = pivot; s["chain"] = chain; s["drum"] = drum; s["weight"] = weight; s["click"] = click; s["thud"] = thud; s["creak"] = creak
		s["state"] = "up"; s["k"] = 0.0; s["t_flat"] = -9.0; s["k_rel"] = 0.0; s["t_rel"] = -9.0; s["cranking"] = false; s["last"] = -9.0; s["clicks"] = 0
		spans.append(s)
		_place(s)

## 널을 지금 각으로, 사슬을 북 꼭대기에서 널 끝까지, 북과 손잡이는 감긴 만큼 돌고, 추는 눕는 만큼 내려간다
func _place(s: Dictionary) -> void:
	var k := k_at(s, t); var th := (1.0 - k) * PI / 2.0
	var dir := float(s["dir"]); var ln := float(s["len"]) * C.K
	var pivot: Node3D = s["pivot"]; pivot.rotation.z = dir * th
	var pz := (C.WALL_Z + POST_Z - C.PLAYER_Z) * C.K
	var px := -dir * inset() * C.K; var ph := float(kind.get("post_h", 40.0)) * C.K; var dr := float(kind.get("drum_r", 7.0)) * C.K
	var tip := Vector3(dir * ln * cos(th), ln * sin(th), 0)
	_line(s["chain"], Vector3(px, ph + dr, pz), tip)
	(s["drum"] as Node3D).rotation = Vector3(PI / 2.0, 0.0, -dir * k * turns() * TAU)   # 북 — 오일러 YXZ 의 안쪽 z 가 제 축 둘레의 돌림(x 로 눕힌 뒤)
	(s["weight"] as Node3D).position.y = ph - 0.2 - k * (ph - 0.4)

## 한 토막 상자를 두 점 사이로 — 돌린 뒤 제 축으로 늘인다(look_at 은 트리 밖에서 못 쓴다)
static func _line(mi: Node3D, from: Vector3, to: Vector3) -> void:
	var l := maxf(0.02, (to - from).length())
	mi.transform = Transform3D(Basis(Quaternion(Vector3.UP, (to - from) / l)) * Basis.from_scale(Vector3(1, l, 1)), (from + to) / 2.0)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 래칫·널·사슬 소리 — 짧은 기음이 빠르게 잦아든다: click(0.04초, 래칫 이가 넘어간다)·thud(0.12초, 널이 땅을 친다)·creak(0.15초, 사슬이 무게를 받는다). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.3) * 0.2) * exp(-k * 10.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
