class_name ClimbPlanter
extends Node3D
## Climb 콘텐츠 팩 '시소 화분'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 공중정원(Hanging garden) 층(바람구멍 층은 뺀다)의 잇단 두 still 발판 사이 틈(min_gap..max_gap, 위 발판이 max_dy 안) — 틈 한가운데 절벽에서 나온 받침(pivot) 위에 긴 흙 화분(trough)이 가로놓인다. 받침은 아래 발판 윗면 위 slope × 반틈에 서서, 어느 끝이든 내려가면 slope(1 = 45°)의 비탈이고 들린 끝은 아래 발판 위 slope × 틈 — 탑의 발판은 틈 ~100 에 ~110 오르니 위 발판 높이쯤이다.
## 가까운 끝은 아래 발판 가장자리에 내려앉아 있다(정원사가 둔 대로 — 흙이 그쪽에 무겁다): 발판에서 걸어 올라선다. 먼 끝 위엔 절벽의 덩굴 고리에 화분 하나가 매달려 있다: 화분 위 어디서든 C 를 누르면 덩굴이 끊기고(snap) 화분이 fall_s 에 먼 끝으로 떨어져(thud) 몸보다 무거워 tip_s 에 걸쳐 반대로 기운다 — 먼 끝은 틈 속으로 가라앉고, 몸이 선 가까운 끝은 slope × 틈 높이로 들린다(clunk, 받침의 멈춤쇠). 거기서 위 발판은 같은 높이의 점프다.
## 화분은 hold_s 뒤 내려간 끝에서 미끄러져 떨어지고(slide_s), 덩굴은 regrow_s 뒤 새 화분을 맺는다. 화분이 없으면 시소는 선 몸 쪽으로 기운다(받침 mid_w 안에 가만히 선 몸은 수평으로; 한끝에서 반대끝까지 tip_s) — 아무도 없으면 가까운 끝으로 돌아간다. 뒤쪽엔 꽃 다섯 — 기울 때마다 끄덕인다(기우는 속도를 거슬러 줄기가 젖는다).
## 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 틈을 건너는 맨 점프는 그대로(화분은 그 밑의 바닥일 뿐), 화분은 발판을 덮지 않는다. 제 무게로 타고 남의 무게로 오르는 첫 다리.
## 서 있는 자세는 balance(stick3d_balance.gd — 운영자 보드의 '외줄·평균대' 가족, sway·teeter 의 다음: 두 팔을 벌리고 무릎이 느슨하며 몸통이 앞 비탈의 오르막 쪽으로 기울고, 화분이 기우는 동안 잔걸음으로 고쳐 선다).
## sway(흔들리는 발밑 — 골반째 옆으로 기운다)·teeter(디딤돌 — 팔만 오르내린다)·bound(다이빙 판 — 제 발로 눌러 던져진다)와 다르다: 이건 발밑이 무게로 앞뒤 비탈이 되는 몸, 오르는 힘이 남의 무게다.
## 로더가 할 일(climb.gd, 운영자 세션): `var cp := ClimbPlanter.new(); add_child(cp)`; 층을 지을 때 `cp.build(root, cp.plan(n, plats, cv.plan(n, plats) + cb.plan(n, plats) + ch.plan(n, plats, wind_of(n), …) + cz.plan(n, plats, …)))` (덩굴·다리·그물·집라인의 계획을 taken 으로 — 그 틈은 비켜 간다); 매 틱 `cp.sync(_t)`;
## 발판에 선 틱의 걷기 자리(`_physics_process` 의 `else:`): `cp.drop(on, Input.is_action_just_pressed("act"))` (true 면 덩굴이 끊긴 틱);
## 로더 자신의 착지 판정이 비었고 vy <= 0 이면 `landed = cp.land(x, y, ny, z)` (kind "planter" — 돌려준 사전의 "y" 가 그 x 의 바닥 높이; "step" 이 참이면 발판에서 내려선 걸음, "ramp" 가 참이면 발판에서 비탈로 걸어 올라선 걸음이라 vx 를 0 으로 안 해도 된다);
## `on["kind"] == "planter"` 인 매 틱, 'move' 발판 자리에서: `var r := cp.stand(on, x, dt, fig); y = r["y"]; if r["off"]: on = {}; apex = y; else: fig.pose_request = "balance"`, 화분을 떠나면 자세를 비운다.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_planter.gd

const PACK := "res://data/climb/planter.json"
const C = preload("res://scripts/games/climb.gd")
const TAKEN_UP := 220.0    # taken 조각(덩굴·그물·집라인·다리) 위로 비워 두는 높이(px) — 제 꼭대기(rail_y·beam_y·y_top)가 더 높으면 그것
const BODY_UP := 50.0      # 들린 끝에 선 몸의 키(px) — 상자 위쪽 여유
const SLOPE_REF := 1.0     # 자세 메타 balance_k 가 1 이 되는 비탈(dy/dx) — 45°
const STOOD_T := 0.1       # 이만큼 stand 가 안 오면 몸이 떠난 것 — 시소가 제 무게로 돌아간다
const NOD_T := 0.15        # 꽃이 젖고 서는 데 걸리는 시간(s)
const ARM_Y := 0.06        # 받침 팔이 화분 바닥 밑으로 내려간 깊이(m)
const SLIDE_DROP := 2.0    # 미끄러진 화분이 slide_s 동안 떨어지는 깊이(m)

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.trough
var troughs: Array = []         # 지은 화분 {id, kind "planter", x, y, w, z, d, y_top, dir, gap, half, xm, a_edge, b_edge, a_y, b_y, y_piv, a_id, b_id, node, deck, stems, pot, snap, thud, clunk, creak, target, k_from, t_tip, at_stop, pot_st, t_pot, u, stood, face, nod_v}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("trough", {})

func sync(now: float) -> void:
	t = now
	for sv in troughs:
		_settle(sv)

func overlap() -> float:
	return maxf(0.0, float(kind.get("overlap", 16.0)))

func clear_px() -> float:
	return maxf(0.0, float(kind.get("clear", 4.0)))

func slope() -> float:
	return clampf(float(kind.get("slope", 1.0)), 0.2, 1.6)   # 1.6 위면 걸어 올라설 때 catch 를 넘는다

func tip_s() -> float:
	return maxf(0.05, float(kind.get("tip_s", 0.6)))

func mid_w() -> float:
	return maxf(0.0, float(kind.get("mid_w", 24.0)))

func hang() -> float:
	return maxf(0.0, float(kind.get("hang", 30.0)))

func fall_s() -> float:
	return maxf(0.01, float(kind.get("fall_s", 0.25)))

func hold_s() -> float:
	return maxf(0.0, float(kind.get("hold_s", 2.0)))

func slide_s() -> float:
	return maxf(0.05, float(kind.get("slide_s", 0.6)))

func regrow_s() -> float:
	return maxf(0.0, float(kind.get("regrow_s", 8.0)))

func catch_px() -> float:
	return maxf(0.0, float(kind.get("catch", 16.0)))

func deck_d() -> float:
	return maxf(2.0, float(kind.get("deck_d", 28.0)))

func th() -> float:
	return maxf(1.0, float(kind.get("th", 10.0)))

## 지금 기울기 −1(가까운 a 끝이 내려감)..+1(먼 b 끝이 내려감) — target 으로 t_tip 부터 tip_s 에 한 바퀴(2)의 빠르기로 간다
func k_at(s: Dictionary, at: float) -> float:
	return move_toward(float(s["k_from"]), float(s["target"]), maxf(0.0, at - float(s["t_tip"])) * 2.0 / tip_s())

## 기울기 k 에서 u(받침에서 b 쪽으로 잰 px, 화분 끝 밖은 끝에서 멈춘다)의 바닥 높이 — 어느 끝이든 내려가면 slope 의 비탈, 받침은 늘 y_piv
func deck_y(s: Dictionary, u: float, k: float) -> float:
	var uu := clampf(u, -float(s["half"]), float(s["half"]))
	return float(s["y_piv"]) - k * slope() * uu

## 기울기 k 의 바닥 비탈(dy/dx, +x 쪽으로) — 그림의 회전각과 자세의 오르막이 여기서
func slope_x(s: Dictionary, k: float) -> float:
	return -float(s["dir"]) * k * slope()

## 화분의 형편 — "hung"(덩굴에)·"falling"·"on"(먼 끝 위)·"sliding"(미끄러져 떨어진다)·"regrow"(덩굴이 새 화분을 맺는 중)
func pot_phase(s: Dictionary, at: float) -> String:
	var st := String(s["pot_st"]); var since := at - float(s["t_pot"])
	match st:
		"falling": return "on" if since >= fall_s() else st
		"on": return "sliding" if since >= hold_s() else st
		"sliding": return "regrow" if since >= slide_s() else st
		"regrow": return "hung" if since >= regrow_s() else st
	return st

## 시계가 넘긴 고비를 적는다 — 화분이 내려앉으면 thud 와 기울기 목표, 미끄러지면 몸 쪽(없으면 쉼)으로, 끝이 멈춤쇠에 닿으면 clunk
func _settle(s: Dictionary) -> void:
	var ph := pot_phase(s, t)
	while ph != String(s["pot_st"]):   # 한 틱에 두 고비를 넘길 수도 있다(fall_s 가 짧다)
		var st := String(s["pot_st"])
		s["t_pot"] = float(s["t_pot"]) + (fall_s() if st == "falling" else hold_s() if st == "on" else slide_s() if st == "sliding" else regrow_s())
		s["pot_st"] = ph
		if ph == "on": _play(s["thud"])
		ph = pot_phase(s, t)
	_aim(s, _target(s))
	var k := k_at(s, t)
	if absf(k) >= 1.0 and not bool(s["at_stop"]): s["at_stop"] = true; _play(s["clunk"])
	elif absf(k) < 1.0: s["at_stop"] = false

## 기울기 목표 — 화분이 먼 끝에 있으면 +1, 몸이 서 있으면 그쪽(가운데는 0), 아니면 쉼(−1)
func _target(s: Dictionary) -> float:
	if String(s["pot_st"]) == "on": return 1.0
	if t - float(s["stood"]) <= STOOD_T:
		var u := float(s["u"])
		return 0.0 if absf(u) <= mid_w() / 2.0 else (1.0 if u > 0.0 else -1.0)
	return -1.0

## 목표가 바뀌면 지금 기울기에서 새로 간다 — 멈춰 있던 시소가 움직이기 시작하면 creak
func _aim(s: Dictionary, target: float) -> void:
	if target == float(s["target"]): return
	var k := k_at(s, t)
	if k == float(s["k_from"]) or absf(k - float(s["target"])) < 0.0001: _play(s["creak"])   # 서 있다가(아직 안 갔거나 다 갔거나) 간다
	s["k_from"] = k; s["t_tip"] = t; s["target"] = target

## 노드를 지금 자리로 — 꽃은 기우는 속도를 따라 젖고 NOD_T 에 선다
func _process(delta: float) -> void:
	t += delta
	troughs = troughs.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_bridge 와 같은 식)
	for sv in troughs:
		var s: Dictionary = sv
		_settle(s)
		var k := k_at(s, t); var moving := absf(k - float(s["target"])) > 0.0001
		var want := (signf(float(s["target"]) - float(s["k_from"])) if moving else 0.0)
		s["nod_v"] = float(s["nod_v"]) + (want - float(s["nod_v"])) * minf(1.0, delta / NOD_T)
		_place(s)

## 층 n(테마 층, 조각의 only 규칙)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 max_dy 안으로 높으며 화분 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := float(kind.get("min_gap", 80.0)); var max_gap := float(kind.get("max_gap", 200.0)); var max_dy := float(kind.get("max_dy", 150.0))
	var ov := overlap(); var cl := clear_px(); var room := ov + 2.0 * C.HW
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
			if dy < 0.0 or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0   # a 에서 b 쪽 — b 가 오른쪽이면 +x
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			if float(a["w"]) < room: continue
			var a_edge := ax1 if dir > 0.0 else ax0; var b_edge := bx0 if dir > 0.0 else bx1
			var y_piv := float(a["y"]) + slope() * gap / 2.0
			var y_top := float(a["y"]) + slope() * gap   # 들린 끝의 높이
			var x0 := minf(a_edge - dir * ov, b_edge - dir * cl) - 4.0; var x1 := maxf(a_edge - dir * ov, b_edge - dir * cl) + 4.0
			var ylo := float(a["y"]) + 1.0; var yhi := y_top + hang() + BODY_UP
			if not _clear(plats, a, b, x0, x1, ylo, yhi): continue
			if not _free(taken, x0, x1, ylo, yhi): continue
			found.append({ "gap": gap, "dir": dir, "a_edge": a_edge, "b_edge": b_edge, "xm": (a_edge + b_edge) / 2.0, "half": gap / 2.0, "y_piv": y_piv, "y_top": y_top,
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate()
			var near := float(g["a_edge"]) - float(g["dir"]) * ov; var far := float(g["b_edge"]) - float(g["dir"]) * cl
			s["id"] = "%d.P%d" % [n, i]; s["kind"] = "planter"; s["x"] = minf(near, far); s["w"] = absf(far - near); s["y"] = float(g["y_piv"]); s["z"] = C.PLAYER_Z; s["d"] = deck_d()
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 화분 상자(가까운 끝 너머 overlap..먼 끝, 아래 윗면..들린 끝 위의 화분과 몸)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x·w·y, 있으면 rail_y·beam_y·y_top)이 화분 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지, 제 꼭대기가 더 높으면 거기 + 60 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - 10.0; var qy1 := qy + TAKEN_UP
		for key in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qy1 = maxf(qy1, float(q[key]) + 60.0)
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 발판에 선 틱 — on 이 화분이고 덩굴에 화분이 매달려 있을 때 C 를 누르면 끊는다(snap): true 는 그 틱. 떨어지는·앉은·미끄러지는·맺히는 화분은 더 못 끊는다
func drop(on: Dictionary, pressed: bool) -> bool:
	var s := _find(String(on.get("id", "")))
	if s.is_empty() or not pressed or String(s["pot_st"]) != "hung": return false
	s["pot_st"] = "falling"; s["t_pot"] = t
	_play(s["snap"])
	return true

## 로더의 착지 판정이 빈 뒤(vy <= 0) — 이 틱에 바닥을 지나 떨어지는 몸, 바닥 위 catch 안에서 내려서는 몸(발판에서 화분으로), 또는 바닥이 발 위 catch 안에 있는 몸(발판에서 비탈로 걸어 올라서는 걸음)을 받는다: {kind "planter", id, x, y(그 x 의 바닥), w, z, d, step, ramp}
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	var catch := catch_px()
	for sv in troughs:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= deck_d() / 2.0 + C.HZ: continue
		if x < float(s["x"]) or x > float(s["x"]) + float(s["w"]): continue
		if ny > y: continue   # 오르는 몸은 받지 않는다
		var sy := deck_y(s, float(s["dir"]) * (x - float(s["xm"])), k_at(s, t))
		var cross := y >= sy and ny <= sy
		var step := not cross and y > sy and y - sy <= catch
		var ramp := not cross and y < sy and sy - y <= catch
		if not (cross or step or ramp): continue
		return { "kind": "planter", "id": String(s["id"]), "x": float(s["x"]), "y": sy, "w": float(s["w"]), "z": float(s["z"]), "d": deck_d(), "step": step, "ramp": ramp }
	return {}

## 화분 위에 선 매 틱 — {x, y, off, k}: 몸이 선 자리를 적고(화분이 없으면 시소가 그쪽으로 기운다; 받침 mid_w 안이면 수평으로), y 는 그 x 의 바닥. 화분 끝을 지났거나 모르는 화분이면 off
## fig 가 있으면 자세의 메타를 적는다: balance_k 앞 비탈(+ 오르막, SLOPE_REF 로 1), balance_v 기우는 중이면 1
func stand(on: Dictionary, x: float, _dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "x": x, "y": float(on.get("y", 0.0)), "off": true, "k": 0.0 }
	var k := k_at(s, t)
	if x < float(s["x"]) or x > float(s["x"]) + float(s["w"]): return { "x": x, "y": deck_y(s, float(s["dir"]) * (x - float(s["xm"])), k), "off": true, "k": k }
	var u := float(s["dir"]) * (x - float(s["xm"]))
	s["stood"] = t; s["u"] = u
	_aim(s, _target(s))
	if fig:
		if absf(fig.move_dir.x) > 0.01: s["face"] = 1.0 if fig.move_dir.x > 0.0 else -1.0
		fig.set_meta("balance_k", clampf(slope_x(s, k) * float(s["face"]) / SLOPE_REF, -1.0, 1.0))
		fig.set_meta("balance_v", 1.0 if absf(k - float(s["target"])) > 0.0001 else 0.0)
	return { "x": x, "y": deck_y(s, u, k), "off": false, "k": k }

func _find(id: String) -> Dictionary:
	for sv in troughs:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 받침과 화분을 짓는다 — root 는 그 층의 노드. 노드 원점은 받침 꼭대기(xm, y_piv, PLAYER_Z) = 수평일 때의 바닥 선; 받침 팔(절벽에서)·핀, 화분(deck: 바닥·흙·앞뒤 턱·양끝·꽃 다섯 — 받침을 축으로 돈다), 덩굴 고리(절벽에서 먼 끝 위로)와 화분(pot), snap·thud·clunk·creak
func build(root: Node3D, planned: Array) -> void:
	var thm := th() * C.K; var dd := deck_d() * C.K; var lip := float(kind.get("lip", 5.0)) * C.K; var pr := float(kind.get("pot_r", 9.0)) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var dir := float(s["dir"]); var half := float(s["half"]) * C.K
		var near := (float(s["a_edge"]) - dir * overlap() - float(s["xm"])) * C.K; var far := (float(s["b_edge"]) - dir * clear_px() - float(s["xm"])) * C.K   # 받침에서 잰 양끝(m, +x)
		var L := absf(far - near); var cx := (near + far) / 2.0
		var node := Node3D.new(); node.position = C.to3(float(s["xm"]), float(s["y_piv"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("6b4a35")); var soil := _mat(Color("3a2a24")); var iron := _mat(Color("4a4a52")); var green := _mat(Color("5f8a3e")); var bloom := _mat(Color("ad7096")); var clay := _mat(Color("c47a52"))
		var arm_len := (C.PLAYER_Z - C.WALL_Z) * C.K + 0.2
		_box(node, Vector3(0.14, 0.08, arm_len), iron).position = Vector3(0.0, -thm - ARM_Y, -arm_len / 2.0 + 0.1)   # 받침 팔 — 절벽에서 걷는 선까지
		var pin := _cyl(node, 0.04, dd + 0.1, iron); pin.rotation.x = PI / 2.0; pin.position = Vector3(0.0, -thm - 0.02, 0.0)   # 핀 — 축이 앞뒤(z)
		var deck := Node3D.new(); node.add_child(deck)
		_box(deck, Vector3(L, thm, dd), wood).position = Vector3(cx, -thm / 2.0, 0.0)                                # 바닥
		_box(deck, Vector3(L - 0.04, 0.01, dd - 0.04), soil).position = Vector3(cx, 0.0, 0.0)                       # 흙 — 윗면이 바닥 선
		_box(deck, Vector3(L, lip, 0.03), wood).position = Vector3(cx, lip / 2.0, dd / 2.0)                          # 앞 턱
		_box(deck, Vector3(L, lip, 0.03), wood).position = Vector3(cx, lip / 2.0, -dd / 2.0)                         # 뒤 턱
		for q in [near, far]:
			_box(deck, Vector3(0.03, lip + thm, dd), wood).position = Vector3(q as float, (lip - thm) / 2.0, 0.0)   # 양끝
		var stems: Array = []
		for i in 5:
			var stem := Node3D.new(); stem.position = Vector3(cx + (float(i) - 2.0) * L * 0.18, 0.0, -dd * 0.3); deck.add_child(stem)   # 꽃 — 뒤쪽 반, 줄기 밑이 흙
			_cyl(stem, 0.012, 0.22, green).position = Vector3(0.0, 0.11, 0.0)
			var head := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.045; sm.height = 0.09; sm.radial_segments = 8; sm.rings = 4; head.mesh = sm; head.material_override = bloom if i % 2 == 0 else _mat(Color("f2b632"))
			head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; head.position = Vector3(0.0, 0.24, 0.0); stem.add_child(head)
			stems.append(stem)
		var hook_y := slope() * half + hang() * C.K + pr * 2.0   # 덩굴 고리 — 들린 먼 끝(받침 위 slope × 반틈) 위 hang 에 화분 바닥, 그 위에 화분 하나
		var vine := _cyl(node, 0.015, 0.4, green); vine.position = Vector3(far, hook_y + 0.2, -dd * 0.3)                              # 덩굴 — 고리에서 위로
		var pot := _cyl(node, pr, pr * 2.0, clay); pot.position = Vector3(far, hook_y - pr, -dd * 0.3)                                # 화분 — 매달린 자리
		var snap := AudioStreamPlayer3D.new(); snap.stream = _tick_wav(float(kind.get("snap_hz", 1200)), 0.06); snap.volume_db = -12.0; snap.unit_size = 6.0; snap.max_distance = 30.0; node.add_child(snap)
		var thud := AudioStreamPlayer3D.new(); thud.stream = _tick_wav(float(kind.get("thud_hz", 90)), 0.12); thud.volume_db = -8.0; thud.unit_size = 6.0; thud.max_distance = 30.0; node.add_child(thud)
		var clunk := AudioStreamPlayer3D.new(); clunk.stream = _tick_wav(float(kind.get("clunk_hz", 160)), 0.1); clunk.volume_db = -10.0; clunk.unit_size = 6.0; clunk.max_distance = 30.0; node.add_child(clunk)
		var creak := AudioStreamPlayer3D.new(); creak.stream = _tick_wav(float(kind.get("creak_hz", 140)), 0.3); creak.volume_db = -14.0; creak.unit_size = 6.0; creak.max_distance = 30.0; node.add_child(creak)
		s["node"] = node; s["deck"] = deck; s["stems"] = stems; s["pot"] = pot; s["snap"] = snap; s["thud"] = thud; s["clunk"] = clunk; s["creak"] = creak
		s["target"] = -1.0; s["k_from"] = -1.0; s["t_tip"] = -9.0; s["at_stop"] = true; s["pot_st"] = "hung"; s["t_pot"] = -9.0; s["u"] = 0.0; s["stood"] = -9.0; s["face"] = dir; s["nod_v"] = 0.0   # 정원사가 둔 대로: 가까운 끝이 내려가 있다, 화분은 덩굴에
		troughs.append(s)
		_place(s)

## 화분을 지금 기울기로(받침을 축으로), 꽃은 기우는 쪽을 거슬러 젖고, 항아리는 덩굴에서 먼 끝으로 떨어져 앉았다가 미끄러져 사라진다
func _place(s: Dictionary) -> void:
	var k := k_at(s, t); var dir := float(s["dir"]); var half := float(s["half"]) * C.K; var dd := deck_d() * C.K
	var pr := float(kind.get("pot_r", 9.0)) * C.K
	(s["deck"] as Node3D).rotation.z = atan(slope_x(s, k))
	var nod := -dir * float(s["nod_v"]) * float(kind.get("nod", 0.35))
	for sv in (s["stems"] as Array):
		(sv as Node3D).rotation.z = nod
	var pot: Node3D = s["pot"]; var ph := String(s["pot_st"]); var since := t - float(s["t_pot"])
	var far := (float(s["b_edge"]) - dir * clear_px() - float(s["xm"])) * C.K
	var fu := float(s["dir"]) * (float(s["b_edge"]) - clear_px() * dir - float(s["xm"]))   # 먼 끝의 u(px)
	var hook_y := slope() * half + hang() * C.K + pr * 2.0
	var on_y := (deck_y(s, fu, k) - float(s["y_piv"])) * C.K + pr   # 지금 기울기에서 먼 끝 바닥 위에 앉은 항아리의 가운데
	pot.visible = ph != "regrow"
	match ph:
		"hung": pot.position = Vector3(far, hook_y - pr, -dd * 0.3)
		"falling":
			var q := clampf(since / fall_s(), 0.0, 1.0)
			pot.position = Vector3(far, lerpf(hook_y - pr, on_y, q * q), -dd * 0.3)
		"on": pot.position = Vector3(far, on_y, -dd * 0.3)
		"sliding":
			var q := clampf(since / slide_s(), 0.0, 1.0)
			pot.position = Vector3(far + dir * 0.4 * q, on_y - SLIDE_DROP * q * q, -dd * 0.3)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

func _cyl(parent: Node3D, r: float, h: float, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = 8; mi.mesh = cm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi); return mi

## 소리 — 짧은 기음이 빠르게 잦아든다: snap(0.06초, 덩굴이 끊긴다)·thud(0.12초, 항아리가 흙에 내려앉는다)·clunk(0.1초, 끝이 멈춤쇠에)·creak(0.3초, 받침이 끙 한다). 한 번 재생, 반복 없음
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
