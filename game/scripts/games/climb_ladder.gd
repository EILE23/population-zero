class_name ClimbLadder
extends Node3D
## Climb 콘텐츠 팩 '서가 사다리'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 서재(Library) 층의 잇단 두 선 발판 사이 틈 — 절벽에 책이 꽂힌 서가 벽이 서고, 위 발판보다 rail_above 위에 놋쇠 난간, 그 난간에 바퀴 달린 나무 사다리가 걸려 아래 발판 높이의 바닥 레일 위를 구른다(도서관의 굴러가는 사다리).
## 발판 끝에서 C: 사다리가 이쪽 끝에 서 있으면 올라탄다(mount_s 에 걸쳐 한 걸음) — 아래 발판에서면 가로대를 밟아 위 발판 높이까지 오르고(climb_v) 그다음 사다리가 난간을 따라 건너편으로 구르고(roll_v, 천천히 떠나 천천히 선다) 위 발판에 내린다; 위 발판에서면 먼저 구르고 그다음 내려간다.
## 사다리가 건너편 끝에 서 있으면 C 는 부르기 — 빈 채로 이쪽으로 굴러온다. 타는 중에 ↓ 면 그 자리에서 떨어지고(사다리는 빈 채 마저 간다), SPACE 로 모았다 놓으면 홀드처럼 0.9 로 뛰되 사다리의 속도를 얹는다. 밀지도, 떨어뜨리지도 않는다 — 느리고 확실한 길.
## 타는 동안 자세는 rail(오를 땐 손발을 번갈아 가로대로, 구를 땐 뒷손이 난간을 쥐고 앞손은 앞으로, 뒷발은 처진다; stick3d_rail.gd). 바퀴가 멈추는 순간 나무 clunk.
## 사다리는 그 층의 다른 틈 팩이 가져가는 가장 긴 틈 하나(다리 bridge·유령 판 ghost)나 둘(버섯 mushroom)을 건너뛴 다음 틈에만 — 같은 틈을 두 팩이 쓰지 않는다(뗏목·추 팩과 같은 식). 통풍구 층엔 없다.
## 로더가 할 일(climb.gd, 운영자 세션): `var cl := ClimbLadder.new(); add_child(cl)`; 층을 지을 때 `cl.build(root, cl.plan(n, plats))`; 매 틱 `cl.sync(_t)`;
## `_after_step` 의 C 자리(판 읽기·쉼터 문 다음): `elif not locked and Input.is_action_just_pressed("act") and not on.is_empty(): var g := cl.grab(on, x, z); if not g.is_empty(): riding = g; on = {}; vx = 0.0; vy = 0.0; charge = 0.0` (riding 은 로더의 새 사전 — holding 처럼; 빈 사전이면 부르기였거나 닿지 않는 것);
## 타는 매 틱(`_hold` 와 같은 자리, 맨 앞): `var r := cl.ride_on(riding, fig); x = r["x"]; y = r["y"]; apex = y; face = r["face"]; fig.pose_request = "rail"; if r["done"] or r["lost"]: riding = {}; fig.pose_request = ""`
## SPACE 를 놓으면 `var v := cl.let_go(riding); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9; vx = dir * RUN * 0.9 + v["vx"]; riding = {}; 자세 ""`; ↓ 면 `vx = v["vx"]; vy = 0.0; riding = {}`.
## done 인 틱의 x·y 는 건너편 발판 위 자리라 다음 틱 로더 자신의 착지 판정이 그 발판을 밟는다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_ladder.gd

const PACK := "res://data/climb/ladder.json"
const C = preload("res://scripts/games/climb.gd")

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.ladder
var ladders: Array = []         # 지은 사다리 {id, kind "ladder", x, y, w, z, d, cx0, cx1, a_y, b_y, rail_y, a_id, b_id, xa, xb, dirx, node, car, clunk, end, from, to, go, rider}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("ladder", {})

func sync(now: float) -> void:
	t = now

func roll_v() -> float:
	return maxf(10.0, float(kind.get("roll_v", 150.0)))

func climb_v() -> float:
	return maxf(10.0, float(kind.get("climb_v", 110.0)))

func mount_s() -> float:
	return maxf(0.0, float(kind.get("mount_s", 0.25)))

## 한 번 구르는 데 걸리는 시간 — 가운데에서 roll_v, 양 끝에선 0 (smoothstep 의 가운데 기울기 1.5)
func roll_s(s: Dictionary) -> float:
	return absf(float(s["cx1"]) - float(s["cx0"])) * 1.5 / roll_v()

## 아래 발판 높이에서 위 발판 높이까지 가로대를 오르는 시간
func climb_s(s: Dictionary) -> float:
	return (float(s["b_y"]) - float(s["a_y"])) / climb_v()

## 사다리 가운데의 x(px) — 서 있으면 그 끝, 구르는 중이면 천천히 떠나 천천히 서는 호(smoothstep)
func lx(s: Dictionary, at: float) -> float:
	var go := float(s.get("go", -9.0))
	var from := float(s["cx0"]) if int(s.get("from", 0)) == 0 else float(s["cx1"])
	if go < -1.0 or at < go: return float(s["cx0"]) if int(s.get("end", 0)) == 0 else float(s["cx1"])
	var to := float(s["cx0"]) if int(s.get("to", 1)) == 0 else float(s["cx1"])
	return lerpf(from, to, smoothstep(0.0, 1.0, clampf((at - go) / roll_s(s), 0.0, 1.0)))

## 구르는 속도 px/s (+x 로 가면 양수) — 서 있으면 0
func lvx(s: Dictionary, at: float) -> float:
	var go := float(s.get("go", -9.0))
	if go < -1.0 or at < go or at > go + roll_s(s): return 0.0
	var k := (at - go) / roll_s(s)
	var from := float(s["cx0"]) if int(s.get("from", 0)) == 0 else float(s["cx1"])
	var to := float(s["cx0"]) if int(s.get("to", 1)) == 0 else float(s["cx1"])
	return (to - from) * 6.0 * k * (1.0 - k) / roll_s(s)

## 구름이 끝나면 그 끝에 선다(clunk); 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	ladders = ladders.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_raft 와 같은 식)
	for sv in ladders:
		var s: Dictionary = sv
		var go := float(s.get("go", -9.0))
		if go > -1.0 and t >= go + roll_s(s):
			s["end"] = int(s["to"]); s["go"] = -9.0; s["stop"] = t
			var ck: AudioStreamPlayer3D = s["clunk"]
			if ck.playing: ck.stop()
			ck.play()
		_place(s)

## 층 n(테마 층만, 조각의 'only' 층만)의 잇단 두 선 발판 사이 틈 중 min_gap..max_gap 에 들고 높이차가 max_dy 안인 것들을 긴 순서로 세워 조각의 skip 개(그 층의 다른 팩 몫)를 버리고 그다음 것 하나 — 서가 벽과 사다리. 같은 층은 늘 같은 답
func plan(n: int, plats: Array) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var min_gap := float(kind.get("min_gap", 90.0)); var max_gap := float(kind.get("max_gap", 240.0)); var max_dy := float(kind.get("max_dy", 150.0))
		var margin := float(kind.get("margin", 8.0)); var lw := float(kind.get("ladder_w", 24.0)); var above := float(kind.get("rail_above", 56.0))
		var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < 0.0 or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			var right := bx0 >= ax1   # 위 발판이 오른쪽에
			var gap := bx0 - ax1 if right else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var dirx := 1.0 if right else -1.0
			var ea := ax1 if right else ax0; var eb := bx0 if right else bx1   # 틈을 보는 두 턱 끝
			var cx0 := ea + dirx * (margin + lw / 2.0); var cx1 := eb - dirx * (margin + lw / 2.0)
			var rail_y := float(b["y"]) + above
			var x0 := minf(ea, eb) - C.HW; var x1 := maxf(ea, eb) + C.HW
			if not _clear(plats, a, b, x0, x1, float(a["y"]) - 10.0, rail_y + float(kind.get("shelf_h", 40.0))): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "ea": ea, "eb": eb, "cx0": cx0, "cx1": cx1, "dirx": dirx, "rail_y": rail_y, "d": d, "a_y": float(a["y"]), "b_y": float(b["y"]), "a_id": String(a["id"]), "b_id": String(b["id"]) })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]))
		var skip := int(piece.get("skip", kind.get("skip_longest", 2)))
		for i in range(skip, mini(skip + int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			var dirx := float(g["dirx"])
			out.append({ "id": "%d.L%d" % [n, i - skip], "kind": "ladder", "x": minf(float(g["ea"]), float(g["eb"])), "y": float(g["a_y"]), "w": float(g["gap"]), "z": C.WALL_Z + float(g["d"]) / 2.0, "d": float(g["d"]),
				"cx0": float(g["cx0"]), "cx1": float(g["cx1"]), "dirx": dirx, "rail_y": float(g["rail_y"]), "a_y": float(g["a_y"]), "b_y": float(g["b_y"]), "a_id": String(g["a_id"]), "b_id": String(g["b_id"]),
				"xa": float(g["ea"]) - dirx * (C.HW + 6.0), "xb": float(g["eb"]) + dirx * (C.HW + 6.0) })
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 서가 상자(틈 폭 + 몸, 바닥 레일..서가 꼭대기)에 두 턱 말고 다른 발판이 걸리지 않나 — 지름길 판이 서가를 가르면 둘 다 못 읽는다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var px0 := float(p["x"]) - 10.0; var px1 := float(p["x"]) + float(p["w"]) + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 발판 on 에 선 몸이 C — 그 발판이 사다리의 두 턱 중 하나고 몸이 서 있는 끝의 사다리 자리에서 reach_x 안이면: 사다리가 이 끝에 서 있으면 올라탄다(돌려주는 사전이 로더의 riding — dir +1 오르는 길, −1 내려가는 길, t0 탄 시각, x0 선 자리),
## 건너편에 서 있으면 부른다(빈 채 굴러온다, 빈 사전), 구르는 중이면 아무것도(빈 사전)
func grab(on: Dictionary, x: float, z: float) -> Dictionary:
	var rx := float(kind.get("reach_x", 40.0))
	var id := String(on.get("id", ""))
	for sv in ladders:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		var here := -1
		if id == String(s["a_id"]): here = 0
		elif id == String(s["b_id"]): here = 1
		if here < 0: continue
		var cx := float(s["cx0"]) if here == 0 else float(s["cx1"])
		if absf(x - cx) >= rx: continue
		if float(s.get("go", -9.0)) > -1.0 or bool(s.get("rider", false)): return {}   # 구르는 중·누가 타는 중
		if int(s.get("end", 0)) != here:   # 건너편에 서 있다 — 부른다
			s["from"] = int(s["end"]); s["to"] = here; s["go"] = t
			return {}
		s["rider"] = true
		return { "id": String(s["id"]), "kind": "ladder", "dir": 1.0 if here == 0 else -1.0, "t0": t, "x0": x, "y0": float(on.get("y", 0.0)) }
	return {}

## 타는 매 틱 — {x, y, face, done, lost}: 오르는 길(dir +1)은 올라타기(mount_s) → 가로대 오르기(climb_s) → 구르기(roll_s) → 위 발판 자리; 내려가는 길은 올라타기 → 구르기 → 내려가기 → 아래 발판 자리.
## fig 가 있으면 자세의 메타를 적는다: rail_c 오르면 +1, 내려가면 −1, 아니면 0; rail_v 구르는 속도 −1..1 (+x 가 +). 사다리가 사라졌으면 lost
func ride_on(riding: Dictionary, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty(): return { "x": float(riding.get("x0", 0.0)), "y": float(riding.get("y0", 0.0)), "face": 1.0, "done": false, "lost": true }
	var up := float(riding.get("dir", 1.0)) > 0.0
	var dirx := float(s["dirx"]) * (1.0 if up else -1.0)   # 몸이 가는 쪽(세상 x)
	var k := t - float(riding.get("t0", t))
	var ms := mount_s(); var cs := climb_s(s)
	var ay := float(s["a_y"]); var by := float(s["b_y"])
	var home := float(s["cx0"]) if up else float(s["cx1"])
	var c := 0.0; var v := 0.0; var px := home; var py := ay if up else by; var done := false
	if k < ms:   # 올라타기 — 턱에서 사다리 가운데로 한 걸음
		px = lerpf(float(riding.get("x0", home)), home, smoothstep(0.0, 1.0, k / maxf(0.01, ms)))
	elif up and k < ms + cs:   # 오르기
		c = 1.0; py = lerpf(ay, by, (k - ms) / maxf(0.01, cs))
	elif up:
		if float(s.get("go", -9.0)) < -1.0 and int(s.get("end", 0)) == 0: s["from"] = 0; s["to"] = 1; s["go"] = t   # 다 올랐다 — 구르기 시작
		py = by; px = lx(s, t); v = clampf(lvx(s, t) / roll_v(), -1.0, 1.0)
		if int(s.get("end", 0)) == 1 and float(s.get("go", -9.0)) < -1.0: done = true
	else:
		if float(s.get("go", -9.0)) < -1.0 and int(s.get("end", 0)) == 1: s["from"] = 1; s["to"] = 0; s["go"] = t   # 올라타자마자 구르기
		px = lx(s, t); py = by; v = clampf(lvx(s, t) / roll_v(), -1.0, 1.0)
		if int(s.get("end", 0)) == 0 and float(s.get("go", -9.0)) < -1.0:   # 다 굴렀다(_process 가 stop 을 적었다) — 내려가기
			var kd := t - float(s.get("stop", t))
			c = -1.0; py = lerpf(by, ay, clampf(kd / maxf(0.01, cs), 0.0, 1.0))
			if kd >= cs: done = true
	if done:
		s["rider"] = false
		px = float(s["xb"]) if up else float(s["xa"]); py = by if up else ay; c = 0.0; v = 0.0
	if fig:
		fig.set_meta("rail_c", c)
		fig.set_meta("rail_v", v)
	return { "x": px, "y": py, "face": dirx, "done": done, "lost": false }

## 놓는 순간 사다리의 속도 {vx} px/s — 뛰면 얹고, 떨어지면 안고 간다; 사다리는 빈 채 마저 간다
func let_go(riding: Dictionary) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty(): return { "vx": 0.0 }
	s["rider"] = false
	return { "vx": lvx(s, t) }

func _find(id: String) -> Dictionary:
	for sv in ladders:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

## 사다리를 짓는다 — root 는 그 층의 노드. 노드 원점은 틈의 왼쪽 턱 끝·아래 발판 높이·발판 깊이 가운데; 절벽에 서가 벽(선반마다 책등 — 높이·빛깔이 고르지 않다), 놋쇠 난간과 받침, 바닥 레일, 그리고 구르는 차(car) 노드 안에 두 세로대·가로대·갈고리·바퀴, 멈출 때 clunk
func build(root: Node3D, planned: Array) -> void:
	var lw := float(kind.get("ladder_w", 24.0)) * C.K; var every := float(kind.get("rung_every", 22.0))
	var wr := float(kind.get("wheel_r", 5.0)) * C.K; var shelf_h := float(kind.get("shelf_h", 40.0)) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var x0 := float(s["x"]); var w := float(s["w"]) * C.K
		var node := Node3D.new(); node.position = C.to3(x0, float(s["y"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("6b4a35")); var brass := _mat(Color("c9a24a")); var paper := _mat(Color("efe9e2")); var oak := _mat(Color("c9a07a"))
		var wall_z := (C.WALL_Z - float(s["z"])) * C.K + 0.06   # 절벽 면(노드 기준)
		var rail_h := (float(s["rail_y"]) - float(s["y"])) * C.K
		var wall_w := w + lw * 2.0
		_box(node, Vector3(wall_w, rail_h + shelf_h + 0.3, 0.08), oak).position = Vector3(w / 2.0, (rail_h + shelf_h + 0.3) / 2.0 - 0.3, wall_z)   # 서가 뒤판
		var rows := maxi(2, int((rail_h + shelf_h) / (every * 2.0 * C.K)))
		var seed := int(hash(String(s["id"]))) & 0x7fff
		var spines: Array = [_mat(Color("8a7f86")), _mat(Color("2f2a4e")), _mat(Color("6b4a35")), paper, _mat(Color("9cc86a")), _mat(Color("e3c46a")), _mat(Color("ad7096"))]   # 자주빛은 맨 끝 하나 — 강조색은 넓게 안 쓴다
		for r in rows:
			var sy := 0.12 + float(r) * (rail_h + shelf_h - 0.2) / rows
			_box(node, Vector3(wall_w - 0.1, 0.03, 0.18), wood).position = Vector3(w / 2.0, sy, wall_z + 0.1)   # 선반
			var bx := 0.0 - lw + 0.06
			var i := 0
			while bx < wall_w - lw - 0.3:   # 책은 서너 권씩 한 덩이(노드 수를 아낀다) — 높이·폭·빛깔이 고르지 않고 가끔 빼 간 자리가 빈다
				var h := 0.16 + 0.04 * float((seed + i * 7 + r * 3) % 4); var bw := 0.18 + 0.05 * float((seed + i * 5 + r) % 4)
				var m: StandardMaterial3D = spines[(seed + i * 11 + r * 5) % (spines.size() - (0 if (i + r) % 5 == 0 else 1))]
				_box(node, Vector3(bw, h, 0.14), m).position = Vector3(bx + bw / 2.0, sy + h / 2.0 + 0.015, wall_z + 0.1)
				bx += bw + 0.015 + (0.08 if (seed + i) % 6 == 0 else 0.0)
				i += 1
		var car_z := (C.PLAYER_Z - 6.0 - float(s["z"])) * C.K   # 사다리는 몸 바로 뒤
		_box(node, Vector3(wall_w, 0.04, 0.04), brass).position = Vector3(w / 2.0, rail_h, car_z)   # 난간
		for i in 2:
			var bz := wall_z + (car_z - wall_z) / 2.0
			_box(node, Vector3(0.05, 0.05, car_z - wall_z), brass).position = Vector3(lw * (0.5 if i == 0 else -0.5) + (0.0 if i == 0 else w), rail_h, bz)   # 난간 받침
		_box(node, Vector3(wall_w, 0.03, 0.1), wood).position = Vector3(w / 2.0, -0.015, car_z)   # 바닥 레일
		var car := Node3D.new(); node.add_child(car)   # 구르는 사다리 — 원점은 바닥 레일 위 가운데
		var ln := rail_h + 0.08
		for i in 2:
			var sx := lw * (0.5 if i == 0 else -0.5)
			_box(car, Vector3(0.04, ln, 0.04), wood).position = Vector3(sx, ln / 2.0, car_z)
			_box(car, Vector3(0.05, 0.08, 0.1), brass).position = Vector3(sx, rail_h + 0.05, car_z)   # 난간에 건 갈고리
			var wheel := MeshInstance3D.new(); var wm := CylinderMesh.new(); wm.top_radius = wr; wm.bottom_radius = wr; wm.height = 0.03; wm.radial_segments = 10; wheel.mesh = wm
			wheel.material_override = brass; wheel.rotation.x = PI / 2.0; wheel.position = Vector3(sx, wr, car_z + 0.03); wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; car.add_child(wheel)
		var ry := fmod(float(s["b_y"]) - float(s["a_y"]), every)   # 위 발판 높이에 가로대 하나가 꼭 맞도록
		while ry < rail_h / C.K - 10.0:
			if ry > 6.0: _box(car, Vector3(lw, 0.03, 0.03), wood).position = Vector3(0, ry * C.K, car_z)
			ry += every
		var clunk := AudioStreamPlayer3D.new(); clunk.stream = _clunk_wav(float(kind.get("clunk_hz", 180))); clunk.volume_db = -10.0; clunk.unit_size = 6.0; clunk.max_distance = 30.0; car.add_child(clunk)
		s["node"] = node; s["car"] = car; s["clunk"] = clunk; s["end"] = 0; s["from"] = 0; s["to"] = 1; s["go"] = -9.0; s["rider"] = false
		ladders.append(s)
		_place(s)

## 차 노드를 지금 자리로 — 노드 원점이 왼쪽 턱 끝이라 그만큼 뺀다
func _place(s: Dictionary) -> void:
	(s["car"] as Node3D).position.x = (lx(s, t) - float(s["x"])) * C.K

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 바퀴가 멈추는 clunk — 0.12초, 둔한 나무 기음이 아주 빠르게 잦아든다(추의 tock 보다 짧고 메마르다; 한 번 재생, 반복 없음)
static func _clunk_wav(hz: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * 0.12)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.7) * 0.2) * exp(-k * 14.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
