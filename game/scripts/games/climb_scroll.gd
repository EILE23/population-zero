class_name ClimbScroll
extends Node3D
## Climb 콘텐츠 팩 '두루마리 선반'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 서재(Library) 층의 잇단 두 still 발판 사이 틈 — 아래 발판의 틈 쪽 가장자리 안 inset 에 말린 지도들이 선 키 큰 선반이 절벽에 기대 있고, 맨 위 두루마리가 가로누워 있다.
## 아래 발판에서 선반 옆에 서서 C 를 누르면(몸이 선반에서 reach 안) 맨 위 두루마리를 당긴다: unroll_s 에 걸쳐 지도가 틈 위로 펼쳐지며(몸은 step 만큼 물러선다) 종이 바닥이 되고, 탁(flop) 눕는다 — 윗면은 발판과 같은 높이, 끝은 위 발판 가장자리 밑 clear 앞. 걸어 건너는 다리: 끝에서 위 발판까지는 틈 없이 높이만 남는다.
## 종이는 종이다: 선 몸을 모두 hold_s 초 버틴 뒤(올라선 시간은 오갈 때마다 더해진다) 선반에서 tear_at 자리에서 찢어진다 — 찍(rip), 먼 조각은 떨어져 사라지고 몸은 그저 더는 아무것도 딛지 않은 몸이 된다(로더의 맨 낙하: 밀지도 다치게 하지도 자세를 주지도 않는다; 여느 가장자리 뒤처럼 밑의 것이 받는다); 남은 종이는 roll_s 에 걸쳐 저절로 말려 돌아가고 선반은 다시 당길 수 있다. 아무도 안 선 지도는 눕고 idle_s 뒤에 저절로 말린다(rip 없이).
## 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 틈을 건너는 맨 점프는 그대로, 선반은 걷는 선 뒤에 서서 아무것도 막지 않고, 지도는 누워 있는 동안만 발판이다. 제 손으로 만들고 제 발로 잃는 첫 다리.
## 당기는 자세는 unroll(stick3d_unroll.gd — 운영자 보드의 '지도 읽기·펼치기' 가족: 두 손이 가슴의 두루마리를 쥐었다가 종이가 나간 만큼 밖으로 쓸어 벌리며 한 발 물러서고, 고개가 종이를 따라간다).
## crank(제자리에서 도는 두 손)·shunt(앞의 서가를 민다)·part(덩굴을 젖힌다)와 다르다: 이건 가슴에서 밖으로 한 번 쓸어 벌리는 두 팔, 일의 길이가 종이의 것이다.
## 로더가 할 일(climb.gd, 운영자 세션): `var sc := ClimbScroll.new(); add_child(sc)`; 층을 지을 때 `var lp := cl.plan(n, plats); var dp := cd.plan(n, plats); var bp := cs.plan(n, plats, lp + dp); var np := pn.plan(n, plats, lp + dp + bp); sc.build(root, sc.plan(n, plats, lp + dp + bp + np))` (사다리·덤웨이터·서가·파터노스터의 계획을 taken 으로 — 그 자리는 비켜 간다); 매 틱 `sc.sync(_t)`;
## 발판에 선 틱의 걷기 자리(`_physics_process` 의 `else:` — target 을 정하기 전): `var r := sc.pull(on, x, z, Input.is_action_just_pressed("act"), fig); if r["pulling"]: x = r["x"]; vx = 0.0; fig.pose_request = "unroll"; elif fig.pose_request == "unroll": fig.pose_request = ""`;
## 로더 자신의 착지 판정이 비면 `landed = sc.land(x, y, ny, z)` (kind "scroll" — 누운 지도의 윗면, 발판과 같은 높이);
## `on["kind"] == "scroll"` 인 매 틱, 'move' 발판 자리에서: `var r := sc.stand(on, x, dt, fig); y = r["y"]; if r["off"]: on = {}; apex = y` — 찢기면(r["tear"]) 그 틱에 off 라 맨 낙하가 된다.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_scroll.gd

const PACK := "res://data/climb/scroll.json"
const C = preload("res://scripts/games/climb.gd")
const TAKEN_UP := 220.0    # taken 조각(사다리·덤웨이터·서가·파터노스터) 위로 비워 두는 높이(px) — 제 꼭대기(rail_y·beam_y·y_top)가 더 높으면 그것
const LET_GO_T := 0.35     # 당기는 틱이 이만큼 끊기면(뛰었다, 떠났다) 몸은 풀린다 — 종이는 제 시계로 계속 펼쳐진다
const BODY_UP := 50.0      # 지도 위에 선 몸의 키(px) — 상자 위쪽 여유
const RACK_Z := 10.0       # 선반이 절벽 면에서 나온 깊이(px) — 걷는 선(PLAYER_Z) 뒤
const SCRAP_T := 0.6       # 찢긴 조각이 떨어져 사라지는 시간(s)
const SCRAP_DROP := 2.0    # 그동안 떨어지는 깊이(m)

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.chart
var racks: Array = []           # 지은 선반 {id, kind "scroll", x, y, w, z, d, dir, gap, hinge_x, tip_x, post_x, len, a_id, b_id, a_y, b_y, node, rack, page, roll, scrap, pull, flop, rip, wind, state, t_pull, t_flat, t_back, k_back, torn, flopped, stood, puller, last, t_scrap}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("chart", {})

func sync(now: float) -> void:
	t = now
	for sv in racks:
		_settle(sv)

func inset() -> float:
	return maxf(0.0, float(kind.get("inset", 24.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 18.0)))

func clear_px() -> float:
	return maxf(0.0, float(kind.get("clear", 8.0)))

func sheet_th() -> float:
	return maxf(0.5, float(kind.get("sheet_th", 2.0)))

func deck_d() -> float:
	return maxf(2.0, float(kind.get("deck_d", 24.0)))

func unroll_s() -> float:
	return maxf(0.05, float(kind.get("unroll_s", 0.8)))

func hold_s() -> float:
	return maxf(0.0, float(kind.get("hold_s", 2.0)))

func tear_at() -> float:
	return clampf(float(kind.get("tear_at", 0.6)), 0.05, 0.95)

func idle_s() -> float:
	return maxf(0.0, float(kind.get("idle_s", 8.0)))

func roll_s() -> float:
	return maxf(0.05, float(kind.get("roll_s", 4.0)))

func step() -> float:
	return maxf(0.0, float(kind.get("step", 12.0)))

## 지도가 펼쳐진 길이의 비율 0..1 — at 때. 당긴 뒤 unroll_s 에 걸쳐 1 로, 누운 채 idle_s 쉬고 roll_s 에 걸쳐 0 으로; 찢겼거나 저절로 말리면(back) k_back 에서 roll_s × k_back 에 걸쳐 0 으로
func k_at(s: Dictionary, at: float) -> float:
	match String(s["state"]):
		"open":
			var k := (at - float(s["t_pull"])) / unroll_s()
			if k < 1.0: return maxf(0.0, k)
			var dk := (at - float(s["t_flat"]) - idle_s()) / roll_s()
			return 1.0 if dk <= 0.0 else maxf(0.0, 1.0 - dk)
		"back": return maxf(0.0, float(s["k_back"]) * (1.0 - (at - float(s["t_back"])) / roll_s()))
	return 0.0

## 지금 지도의 형편 — "rolled"(선반에 말려 있다)·"unrolling"(펼쳐지는 중)·"open"(누워 있다)·"back"(말려 돌아가는 중)
func phase(s: Dictionary, at: float) -> String:
	match String(s["state"]):
		"open":
			if at < float(s["t_flat"]): return "unrolling"
			if at < float(s["t_flat"]) + idle_s(): return "open"
			return "back" if k_at(s, at) > 0.0 else "rolled"
		"back": return "back" if k_at(s, at) > 0.0 else "rolled"
	return "rolled"

## 시계가 넘긴 고비를 적는다 — 눕는 탁 소리, 아무도 안 서서 저절로 말리기, 다 말리면 선반에, 당기던 몸의 틱이 끊기면 풀어 준다
func _settle(s: Dictionary) -> void:
	var st := String(s["state"])
	if st == "open" and not bool(s["flopped"]) and t >= float(s["t_flat"]): s["flopped"] = true; _play(s["flop"])
	if st == "open" and t >= float(s["t_flat"]) + idle_s():
		s["state"] = "back"; s["t_back"] = float(s["t_flat"]) + idle_s(); s["k_back"] = 1.0; s["torn"] = false; _play(s["wind"])
	if String(s["state"]) == "back" and k_at(s, t) <= 0.0: s["state"] = "rolled"
	if bool(s["puller"]) and t - float(s["last"]) > LET_GO_T: s["puller"] = false

## 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	racks = racks.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_drawbridge 와 같은 식)
	for sv in racks:
		_settle(sv)
		_place(sv)

## 층 n(테마 층만)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 min_dy..max_dy 높으며 지도 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나 — 그 옆에 선반. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := float(kind.get("min_gap", 70.0)); var max_gap := float(kind.get("max_gap", 220.0))
	var min_dy := float(kind.get("min_dy", 40.0)); var max_dy := float(kind.get("max_dy", 150.0))
	var ins := inset(); var cl := clear_px()
	var room := ins + 2.0 * C.HW + reach() + 4.0   # 선반과 그 뒤에 서서 당기는 몸이 들어갈 발판 폭
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
			var dir := 1.0 if bx0 >= ax1 else -1.0   # 아래 발판에서 위 발판 쪽 — 위가 오른쪽이면 지도는 +x 로 펼쳐진다
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			if float(a["w"]) < room: continue
			var hinge := ax1 if dir > 0.0 else ax0
			var ln := gap - cl
			var tip := hinge + dir * ln; var post := hinge - dir * ins
			var x0 := (post - C.HW - reach() - 4.0) if dir > 0.0 else (tip - 4.0)   # 선반 뒤에 선 몸부터 지도 끝까지
			var x1 := (tip + 4.0) if dir > 0.0 else (post + C.HW + reach() + 4.0)
			if not _clear(plats, a, b, x0, x1, float(a["y"]) + 1.0, float(a["y"]) + BODY_UP): continue
			if not _free(taken, x0, x1, float(a["y"]) + 1.0, float(a["y"]) + BODY_UP): continue
			found.append({ "gap": gap, "dir": dir, "hinge_x": hinge, "tip_x": tip, "post_x": post, "len": ln,
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.S%d" % [n, i]; s["kind"] = "scroll"; s["x"] = minf(float(g["hinge_x"]), float(g["tip_x"])); s["w"] = float(g["len"]); s["y"] = float(g["a_y"]); s["z"] = C.PLAYER_Z; s["d"] = deck_d()
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 지도 상자(선반 뒤의 몸..위 발판 가장자리, 아래 발판 윗면..선 몸)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x·w·y, 있으면 rail_y·beam_y·y_top)이 지도 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지, 제 꼭대기가 더 높으면 거기 + 60 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - 10.0; var qy1 := qy + TAKEN_UP
		for key in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qy1 = maxf(qy1, float(q[key]) + 60.0)
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 발판에 선 틱 — on 이 선반의 아래 발판이고 말린 지도 앞에서(몸이 선반에서 HW + reach 안) C 를 누르면 당긴다: 펼쳐지는 동안 {pulling true, x} 의 x 는 선반 뒤에 섰다가 종이가 나간 만큼 물러선 몸의 자리. 펼쳐진·말리는 지도는 더 당겨지지 않는다. 아니면 {pulling false}
## fig 가 있으면 자세의 메타를 적는다: unroll_k 종이가 나간 비율 0..1; 끝나면 지운다
func pull(on: Dictionary, x: float, z: float, pressed: bool, fig: Stick3D = null) -> Dictionary:
	var s := _mine(on)
	if s.is_empty():
		if fig: _clear_meta(fig)
		return { "pulling": false, "x": x }
	var ph := phase(s, t)
	if ph == "rolled" and pressed and _reached(s, x, z):
		s["state"] = "open"; s["t_pull"] = t; s["t_flat"] = t + unroll_s(); s["flopped"] = false; s["torn"] = false; s["k_back"] = 1.0; s["stood"] = 0.0; s["puller"] = true
		_play(s["pull"])
		ph = "unrolling"
	if ph != "unrolling" or not bool(s["puller"]):
		if fig: _clear_meta(fig)
		return { "pulling": false, "x": x }
	s["last"] = t
	var k := k_at(s, t)
	if fig: fig.set_meta("unroll_k", k)
	return { "pulling": true, "x": float(s["post_x"]) - float(s["dir"]) * (C.HW + 6.0 + step() * k) }

## on 이 아래 발판인 선반 — 없으면 빈 사전
func _mine(on: Dictionary) -> Dictionary:
	for sv in racks:
		if String(on.get("id", "")) == String((sv as Dictionary)["a_id"]): return sv
	return {}

## 몸이 선반에서 HW + reach 안이고 걷는 선에 있나
func _reached(s: Dictionary, x: float, z: float) -> bool:
	if absf(z - float(s["z"])) >= deck_d() / 2.0 + C.HZ: return false
	return absf(x - float(s["post_x"])) <= C.HW + reach()

## 로더 자신의 착지 판정이 빈 뒤 — 누운 지도의 윗면을 떨어지는 몸이 지나면 올라선다: {kind "scroll", id, x, y, w, z, d}. 말린·펼쳐지는·말리는 지도는 발판이 아니다
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	for sv in racks:
		var s: Dictionary = sv
		if phase(s, t) != "open": continue
		var top := float(s["a_y"])
		if y < top - 0.5 or ny > top: continue
		if absf(z - float(s["z"])) >= deck_d() / 2.0 + C.HZ: continue
		var x0 := float(s["x"]); var x1 := x0 + float(s["len"])
		if x + C.HW <= x0 or x - C.HW >= x1: continue
		return { "kind": "scroll", "id": String(s["id"]), "x": x0, "y": top, "w": float(s["len"]), "z": float(s["z"]), "d": deck_d() }
	return {}

## 지도 위에 선 매 틱 — {x, y, off, tear}: 누워 있으면 그대로, 선 시간을 더한다; hold_s 를 다 쓰면 찢긴다(tear, off — 로더가 on 을 비워 맨 낙하); 더는 누워 있지 않으면 off
func stand(on: Dictionary, x: float, dt: float, _fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "x": x, "y": float(on.get("y", 0.0)), "off": true, "tear": false }
	var top := float(s["a_y"])
	if phase(s, t) != "open": return { "x": x, "y": top, "off": true, "tear": false }
	s["stood"] = float(s["stood"]) + dt
	if float(s["stood"]) >= hold_s() - 0.000001:
		_tear(s)
		return { "x": x, "y": top, "off": true, "tear": true }
	return { "x": x, "y": top, "off": false, "tear": false }

## 찢긴다 — 먼 조각이 떨어지고 남은 종이는 말려 돌아간다(rip)
func _tear(s: Dictionary) -> void:
	s["state"] = "back"; s["t_back"] = t; s["k_back"] = tear_at(); s["torn"] = true; s["t_scrap"] = t; s["puller"] = false
	_play(s["rip"])

static func _clear_meta(fig: Stick3D) -> void:
	if fig.has_meta("unroll_k"): fig.remove_meta("unroll_k")

func _find(id: String) -> Dictionary:
	for sv in racks:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 선반과 지도를 짓는다 — root 는 그 층의 노드. 노드 원점은 가장자리(hinge_x, a_y, PLAYER_Z); 선반(받침·기둥 둘·선 지도 셋·띠, 절벽 쪽 RACK_Z), 종이(page: 단위 길이의 장과 먹선 둘 — _place 가 x 로 늘인다), 두루마리(roll), 찢긴 조각(scrap), pull·flop·rip·wind
func build(root: Node3D, planned: Array) -> void:
	var th := sheet_th() * C.K; var dd := deck_d() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var dir := float(s["dir"]); var ln := float(s["len"]) * C.K
		var node := Node3D.new(); node.position = C.to3(float(s["hinge_x"]), float(s["a_y"]), float(s["z"]) * C.K); root.add_child(node)
		var paper := _mat(Color("efe9e2")); var ink := _mat(Color("3a2a24")); var wood := _mat(Color("6b4a35")); var band := _mat(Color("ad7096"))
		var pz := (C.WALL_Z + RACK_Z - C.PLAYER_Z) * C.K                                                       # 선반은 절벽 쪽, 걷는 선 뒤
		var rh := float(kind.get("rack_h", 48.0)) * C.K; var rr := float(kind.get("roll_r", 5.0)) * C.K
		var rack := Node3D.new(); rack.position = Vector3(-dir * inset() * C.K, 0.0, pz); node.add_child(rack)
		_box(rack, Vector3(0.5, 0.06, 0.3), wood).position = Vector3(0, 0.03, 0)                                # 받침
		for q in [-0.2, 0.2]:
			_box(rack, Vector3(0.05, rh, 0.05), wood).position = Vector3(q as float, rh / 2.0, 0)              # 기둥 둘
		for q in [-0.12, 0.0, 0.12]:
			var chart := _cyl(rack, 0.07, rh * 0.9, paper); chart.position = Vector3(q as float, rh * 0.45 + 0.06, 0.02)   # 선 지도 셋
		_box(rack, Vector3(0.42, 0.03, 0.02), band).position = Vector3(0, rh * 0.55, 0.16)                        # 띠 — 강조색만
		var page := Node3D.new(); node.add_child(page)                                                         # 종이 — scale.x 가 펼쳐진 길이
		_box(page, Vector3(1.0, th, dd), paper).position = Vector3(0, -th / 2.0, 0)
		var m1 := _box(page, Vector3(0.3, 0.004, 0.02), ink); m1.position = Vector3(-0.2, 0.003, dd * 0.2); m1.rotation.y = 0.3      # 먹선 — 지도의 길
		var m2 := _box(page, Vector3(0.25, 0.004, 0.02), ink); m2.position = Vector3(0.15, 0.003, -dd * 0.25); m2.rotation.y = -0.5
		var roll := _cyl(node, rr, dd + 0.1, paper); roll.rotation.x = PI / 2.0                                  # 두루마리 — 축이 앞뒤(z)
		var scrap := _box(node, Vector3(ln * (1.0 - tear_at()), th, dd), paper); scrap.visible = false            # 찢긴 조각
		var pull := AudioStreamPlayer3D.new(); pull.stream = _tick_wav(float(kind.get("pull_hz", 900)), 0.08); pull.volume_db = -14.0; pull.unit_size = 6.0; pull.max_distance = 30.0; node.add_child(pull)
		var flop := AudioStreamPlayer3D.new(); flop.stream = _tick_wav(float(kind.get("flop_hz", 160)), 0.1); flop.volume_db = -10.0; flop.unit_size = 6.0; flop.max_distance = 30.0; node.add_child(flop)
		var rip := AudioStreamPlayer3D.new(); rip.stream = _tick_wav(float(kind.get("rip_hz", 240)), 0.2); rip.volume_db = -8.0; rip.unit_size = 6.0; rip.max_distance = 30.0; node.add_child(rip)
		var wind := AudioStreamPlayer3D.new(); wind.stream = _tick_wav(float(kind.get("wind_hz", 520)), 0.12); wind.volume_db = -14.0; wind.unit_size = 6.0; wind.max_distance = 30.0; node.add_child(wind)
		s["node"] = node; s["rack"] = rack; s["page"] = page; s["roll"] = roll; s["scrap"] = scrap; s["pull"] = pull; s["flop"] = flop; s["rip"] = rip; s["wind"] = wind
		s["state"] = "rolled"; s["t_pull"] = -9.0; s["t_flat"] = -9.0; s["t_back"] = -9.0; s["k_back"] = 1.0; s["torn"] = false; s["flopped"] = true; s["stood"] = 0.0; s["puller"] = false; s["last"] = -9.0; s["t_scrap"] = -9.0
		racks.append(s)
		_place(s)

## 종이를 지금 길이로, 두루마리는 선반 꼭대기에서 종이 끝으로(첫 0.12 동안 건너온다), 찢긴 조각은 SCRAP_T 동안 떨어지다 사라진다
func _place(s: Dictionary) -> void:
	var k := k_at(s, t)
	var dir := float(s["dir"]); var ln := float(s["len"]) * C.K; var L := k * ln
	var th := sheet_th() * C.K; var rr := float(kind.get("roll_r", 5.0)) * C.K; var rh := float(kind.get("rack_h", 48.0)) * C.K
	var page: Node3D = s["page"]; page.visible = k > 0.001
	page.scale.x = maxf(0.001, L); page.position.x = dir * L / 2.0
	var rack: Node3D = s["rack"]
	var e := smoothstep(0.0, 0.12, k)
	(s["roll"] as Node3D).position = rack.position.lerp(Vector3(dir * L, rr - th, 0.0), e) + Vector3(0.0, (rh + rr) * (1.0 - e), 0.0)
	var scrap: Node3D = s["scrap"]
	var q := (t - float(s["t_scrap"])) / SCRAP_T
	scrap.visible = bool(s["torn"]) and q >= 0.0 and q < 1.0
	if scrap.visible:
		scrap.position = Vector3(dir * ln * (tear_at() + (1.0 - tear_at()) / 2.0), -th / 2.0 - SCRAP_DROP * q * q, 0.0)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

func _cyl(parent: Node3D, r: float, h: float, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = 10; mi.mesh = cm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi); return mi

## 종이 소리 — 짧은 기음이 빠르게 잦아든다: pull(0.08초, 종이가 선반에서 미끄러진다)·flop(0.1초, 지도가 땅에 눕는다)·rip(0.2초, 찢어진다)·wind(0.12초, 저절로 말린다). 한 번 재생, 반복 없음
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
