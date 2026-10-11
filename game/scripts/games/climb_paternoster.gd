class_name ClimbPaternoster
extends Node3D
## Climb 콘텐츠 팩 '파터노스터'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 서재(Library) 층의 벽 쪽(짝수 층은 왼벽, 홀수 층은 오른벽 — 이웃한 두 서재 층의 발판은 층 경계에서 높이가 섞이므로 같은 자리에 사슬 둘이 안 겹치게) — 문 없는 칸들이 사슬에 달려 끝없이 도는 승강기: 안쪽 레인에서 오르고 꼭대기를 돌아 벽 쪽 레인으로 내려와 바닥을 돌아 다시 오른다.
## 그 벽에 가장 가까운 발판 턱에서 step 만큼 바깥이 레인의 안쪽 가장자리(벽에서 wall_in + 칸 둘보다 안으론 못 간다); 턱이 거기서 reach 안에 있는 발판들이 사슬을 '쓴다'(둘 이상이어야 사슬이 선다). 고리는 가장 낮은 쓰는 발판 아래 below 부터 가장 높은 것 위 head 까지 — 칸 수(min_cabins 이상)가 pitch 간격으로 고리 전체에 딱 맞게 올림한다; 칸은 period 마다 한 pitch 씩 간다.
## 칸의 바닥은 널(plank)처럼 팩이 가진 바닥이다: 쓰는 발판에서 레인으로 걸어 나가는 건 로더의 걸음 그대로 — land 가 바닥을 지나 떨어지는 몸을, 그리고 같은 틱에 발밑으로 솟아오른 바닥도 발판처럼 받고, stand 가 매 틱 칸과 같이 몸을 실어(꼭대기·바닥을 돌 땐 옆으로) 발밑 높이를 주며, 바닥 가장자리에서 over 를 지나 걸으면 off(위의 쓰는 발판으로 내려서거나, 아래 칸이 받는 낙하).
## 아무것도 멈추지 않는다: 안 내리면 꼭대기를 돌아 내려와 바닥을 돌아 다시 오른다 — 놓친 값은 한 바퀴뿐. 칸 안의 SPACE 는 로더의 모아 뛰기 그대로. 자세는 board(stick3d_board.gd — 들어설 땐 한 손이 뒷벽 난간으로, 가까운 무릎이 문턱을 넘고, 몸이 가라앉는다; 타는 동안 난간 손, 오르내림을 받는 무릎, 돌 땐 반대 팔이 밖으로, 고개는 가는 쪽; 나설 땐 손을 놓고 앞발이 뻗는다).
## 덤웨이터(heave — 제 손으로 끌어올리는 상자)·흔들 사다리(rail)와 다르다: 이건 스스로 도는 바닥에 걸어 들어가고 걸어 나오는 것 — 손은 잡기만 한다.
## 로더가 할 일(climb.gd, 운영자 세션): `var pn := ClimbPaternoster.new(); add_child(pn)`; 층을 지을 때 `pn.build(root, pn.plan(n, plats, cl.plan(n, plats) + cd.plan(n, plats) + cb.plan(n, plats)))` (사다리·덤웨이터·서가의 계획을 taken 으로 — 레인이 닿는 자리는 비켜 간다); 매 틱 `pn.sync(_t)`;
## 착지 판정에서 landed 가 비었고 vy <= 0 이면 `landed = pn.land(x, y, ny, z)` (돌려준 사전이 칸: x·w 는 바닥, y 는 지금 바닥 높이, chain·k 는 어느 사슬의 몇째 칸);
## 서 있을 때 `on["kind"] == "paternoster"` 면 'move' 발판이 실어 가는 자리에서 `var r := pn.stand(on, x, dt, fig); x = r["x"]; y = r["y"]; fig.pose_request = "board"; if r["off"]: on = {}; apex = y; fig.pose_request = ""` (stand 는 on 의 x·y 도 지금 칸 자리로 고쳐 써서 로더 자신의 가장자리 판정이 그대로 맞는다; r["vy"] 는 칸의 세로 속도 — 뛸 때 얹고 싶으면 maxf(0, r["vy"])).
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_paternoster.gd

const PACK := "res://data/climb/paternoster.json"
const C = preload("res://scripts/games/climb.gd")
const TAKEN_UP := 220.0    # taken 조각(사다리·덤웨이터·서가) 위로 비워 두는 높이(px)
const BODY_UP := 70.0      # 발판 위에 선 몸의 머리까지(px) — 발판의 상자 높이
const LEDGE_DOWN := 500.0  # 턱(ledge) 밑의 바위벽 — 발판 목록엔 턱만 있다(climb.gd 의 _walls 는 따로)
const CHAIN_UP := 6.0      # 지붕 위 사슬까지(px)

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.paternoster
var chains: Array = []          # 지은 사슬 {id, kind "paternoster", x, y, w, z, d, side, inner, up_cx, down_cx, y_bot, y_top, H, L, cabins, serves, a_y, b_y, node, cabs, lanes, wheels, creak, clank}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)
var _dt := 1.0 / 60.0           # 마지막 두 sync 사이 — land 가 '지난 틱의 바닥'을 알려고

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("paternoster", {})

func sync(now: float) -> void:
	if now > t: _dt = clampf(now - t, 1.0 / 240.0, 0.25)
	t = now

func cab_w() -> float:
	return maxf(24.0, float(kind.get("cab_w", 48.0)))

func cab_h() -> float:
	return maxf(40.0, float(kind.get("cab_h", 76.0)))

func cab_d() -> float:
	return maxf(20.0, float(kind.get("cab_d", 40.0)))

func pitch() -> float:
	return maxf(cab_h() + 20.0, float(kind.get("pitch", 160.0)))

func period() -> float:
	return maxf(0.2, float(kind.get("period", 2.0)))

## 사슬의 속도 px/s
func speed() -> float:
	return pitch() / period()

## 두 레인의 가운데 사이(px) — 칸 하나와 틈
func lane_w() -> float:
	return cab_w() + maxf(0.0, float(kind.get("lane_gap", 8.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 40.0)))

func over() -> float:
	return maxf(0.0, float(kind.get("over", 6.0)))

func step_s() -> float:
	return maxf(0.05, float(kind.get("step_s", 0.25)))

## 고리 위의 자리 q(0..L)에서 칸의 바닥 가운데 — {x, y, v, h, lane}: v 세로 방향 ±1·0, h 가로 방향 ±1·0, lane 0 오름·1 꼭대기·2 내림·3 바닥
func at(s: Dictionary, q: float) -> Dictionary:
	var H := float(s["H"]); var w := lane_w(); var yb := float(s["y_bot"])
	var upx := float(s["up_cx"]); var dnx := float(s["down_cx"])
	if q < H: return { "x": upx, "y": yb + q, "v": 1.0, "h": 0.0, "lane": 0 }
	if q < H + w: return { "x": lerpf(upx, dnx, (q - H) / w), "y": yb + H, "v": 0.0, "h": signf(dnx - upx), "lane": 1 }
	if q < 2.0 * H + w: return { "x": dnx, "y": yb + H - (q - H - w), "v": -1.0, "h": 0.0, "lane": 2 }
	return { "x": lerpf(dnx, upx, (q - 2.0 * H - w) / w), "y": yb, "v": 0.0, "h": signf(upx - dnx), "lane": 3 }

## k 째 칸의 때 at 의 자리 — 칸은 pitch 간격으로 고리를 speed 로 돈다
func pos(s: Dictionary, k: int, at_t: float) -> Dictionary:
	return at(s, fposmod(speed() * at_t + float(k) * pitch(), float(s["L"])))

## 칸이 꼭대기 톱니를 지나면 clank; 칸·톱니를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	if delta > 0.0: _dt = delta
	chains = chains.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_plank 와 같은 식)
	for sv in chains:
		var s: Dictionary = sv
		var lanes: Array = s["lanes"]
		for k in int(s["cabins"]):
			var lane := int(pos(s, k, t)["lane"])
			if int(lanes[k]) == 0 and lane == 1: _play(s["clank"])
			lanes[k] = lane
		_place(s)

## 벽 쪽으로 작아지는 자리 u — 왼벽(side +)은 x 그대로, 오른벽(side −)은 −x
static func _u(side: float, x: float) -> float:
	return x if side > 0.0 else -x

## 층 n(테마 층만)의 벽 쪽(짝수 왼·홀수 오른) 레인: 조각의 on 종류 중 그 벽에 가장 가까운 턱에서 step 바깥이 안쪽 가장자리, 거기서 reach 안의 발판들이 쓴다(둘 이상). 고리는 아래 below·위 head, 칸 수는 pitch 에 맞게 올림. 레인 상자를 다른 발판이 가르거나 taken 조각이 닿으면 없다. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var side := 1.0 if n % 2 == 0 else -1.0
	var cw := cab_w(); var w := lane_w(); var lg := w - cw
	var wall_in := float(kind.get("wall_in", 10.0)); var step := float(kind.get("step", 8.0))
	var below := float(kind.get("below", 170.0)); var head := float(kind.get("head", 10.0)); var min_cabs := maxi(1, int(kind.get("min_cabins", 4)))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std", "ice"])
		var cands: Array = plats.filter(func(p: Dictionary) -> bool: return String(p["kind"]) in kinds)
		if cands.size() < 2: continue
		var u_min := INF
		for cv in cands: u_min = minf(u_min, _edge(side, cv))
		var limit := (wall_in if side > 0.0 else wall_in - C.WORLD_W) + 2.0 * cw + lg   # 벽에서 칸 둘과 틈보다 안으론 못 간다
		var inner := maxf(u_min - step, limit)
		var serves: Array = cands.filter(func(p: Dictionary) -> bool: return _edge(side, p) - inner >= 0.0 and _edge(side, p) - inner <= reach())
		if serves.size() < 2: continue
		serves.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["y"]) < float(q["y"]))
		var y_lo := float(serves[0]["y"]); var y_hi := float(serves[serves.size() - 1]["y"])
		var y_bot := y_lo - below
		var need := 2.0 * (y_hi + head - y_bot) + 2.0 * w
		var cabins := maxi(min_cabs, ceili(need / pitch()))
		var L := float(cabins) * pitch(); var H := (L - 2.0 * w) / 2.0
		var y_top := y_bot + H
		var u0 := inner - 2.0 * cw - lg - 4.0; var u1 := inner + 4.0
		var x0 := minf(side * u0, side * u1); var x1 := maxf(side * u0, side * u1)
		var ylo := y_bot - 10.0; var yhi := y_top + cab_h() + 20.0
		var ids: Array = serves.map(func(p: Dictionary) -> String: return String(p["id"]))
		if not _clear(plats, ids, x0, x1, ylo, yhi): continue
		if not _free(taken, x0, x1, ylo, yhi): continue
		var up_cx := side * (inner - cw / 2.0); var down_cx := up_cx - side * w
		var s := { "id": "%d.N0" % n, "kind": "paternoster", "x": x0 + 4.0, "y": y_bot, "w": 2.0 * cw + lg, "z": C.WALL_Z + cab_d() / 2.0, "d": cab_d(),
			"side": side, "inner": inner, "up_cx": up_cx, "down_cx": down_cx, "y_bot": y_bot, "y_top": y_top, "H": H, "L": L, "cabins": cabins, "serves": ids, "a_y": y_lo, "b_y": y_hi }
		out.append(s)
		if out.size() >= int(piece.get("max", 1)): break
	return out

## 발판의 벽을 향한 턱(u 로)
static func _edge(side: float, p: Dictionary) -> float:
	return _u(side, float(p["x"])) if side > 0.0 else _u(side, float(p["x"]) + float(p["w"]))

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 레인 상자에 쓰는 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째, 턱은 그 밑의 바위벽째, 선 몸의 높이까지
static func _clear(plats: Array, serve_ids: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if String(p["id"]) in serve_ids: continue
		var py := float(p["y"])
		var plo := py - (LEDGE_DOWN if String(p["kind"]) == "ledge" else 20.0); var phi := py + BODY_UP
		if phi < ylo or plo > yhi: continue
		var amp := float(p.get("amp", 0.0))
		var px0 := float(p["x"]) - amp - 10.0; var px1 := float(p["x"]) + float(p["w"]) + amp + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: x·w·y)이 레인 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - 10.0; var qy1 := qy + TAKEN_UP
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 로더의 착지 판정과 같은 규칙(HW·HZ) — 이 틱에 칸 바닥을 지나 떨어지는 몸, 또는 지난 틱의 바닥 위에 있다가 솟아오른 바닥에 발이 닿은 몸을 받고 칸(발판 모양 사전)을 돌려준다(creak). 바닥 가장자리 over 안까지
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	var half := cab_w() / 2.0 + over()
	for sv in chains:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		for k in int(s["cabins"]):
			var p := pos(s, k, t)
			if absf(x - float(p["x"])) > half: continue
			var fy := float(p["y"]); var fp := float(pos(s, k, t - _dt)["y"])
			if y >= minf(fy, fp) - 0.5 and ny <= fy:
				_play(s["creak"])
				return _cab(s, k, p)
	return {}

## 칸을 발판 모양 사전으로 — x·w 는 바닥, y 는 지금 바닥 높이, chain·k 는 어느 사슬의 몇째 칸
func _cab(s: Dictionary, k: int, p: Dictionary) -> Dictionary:
	return { "id": "%s.c%d" % [String(s["id"]), k], "kind": "paternoster", "chain": String(s["id"]), "k": k, "x": float(p["x"]) - cab_w() / 2.0, "y": float(p["y"]), "w": cab_w(), "z": float(s["z"]), "d": float(s["d"]) }

## 서 있는 매 틱 — {x, y, off, lost, vy}: x 는 칸이 이 틱에 실어 간 만큼 옮긴 몸의 x(오를 땐 그대로, 꼭대기·바닥을 돌 땐 옆으로), y 는 지금 바닥, off 는 가장자리에서 over 를 지났나(creak), lost 는 사슬이 사라졌나(지운 층), vy 는 칸의 세로 속도. on 의 x·y 도 지금 자리로 고쳐 쓴다.
## fig 가 있으면 자세의 메타를 적는다: board_v 오르내림 ±1·0, board_x 옆으로 실려 가는 방향 ±1·0, board_out 문턱(sill)에서 over 까지 나선 정도 0..1
func stand(on: Dictionary, x: float, dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("chain", "")))
	if s.is_empty(): return { "x": x, "y": float(on.get("y", 0.0)), "off": true, "lost": true, "vy": 0.0 }
	var k := int(on.get("k", 0))
	var p := pos(s, k, t); var q := pos(s, k, t - dt)
	var nx := x + float(p["x"]) - float(q["x"])
	var u := absf(nx - float(p["x"]))
	var off := u > cab_w() / 2.0 + over()
	on["x"] = float(p["x"]) - cab_w() / 2.0; on["y"] = float(p["y"])
	if off: _play(s["creak"])
	if fig:
		fig.set_meta("board_v", float(p["v"]))
		fig.set_meta("board_x", float(p["h"]))
		var sill := float(kind.get("sill", 14.0))
		fig.set_meta("board_out", clampf((u - (cab_w() / 2.0 - sill)) / maxf(1.0, sill + over()), 0.0, 1.0))
	return { "x": nx, "y": float(p["y"]), "off": off, "lost": false, "vy": float(p["v"]) * speed() }

func _find(id: String) -> Dictionary:
	for sv in chains:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 사슬을 짓는다 — root 는 그 층의 노드. 노드 원점은 오름 레인의 가운데·고리 바닥·칸 깊이 가운데; 레인마다 뒷벽의 쇠 레일 둘과 사슬 줄, 위아래 톱니바퀴, 칸들(바닥·지붕·뒷벽·난간·걸이·번호판), creak, clank
func build(root: Node3D, planned: Array) -> void:
	var cw := cab_w() * C.K; var ch := cab_h() * C.K; var cd := cab_d() * C.K
	var iron := _mat(Color("3a3640")); var oak := _mat(Color("6b4a35")); var brass := _mat(Color("c9a07a")); var paper := _mat(Color("efe9e2")); var ink := _mat(Color("1b0c15")); var plate := _mat(Color("ad7096"))
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var node := Node3D.new(); node.position = C.to3(float(s["up_cx"]), float(s["y_bot"]), float(s["z"]) * C.K); root.add_child(node)
		var body_z := (C.PLAYER_Z - float(s["z"])) * C.K   # 몸이 서는 깊이
		var back_z := body_z - cd / 2.0                      # 칸의 뒷벽(절벽 쪽)
		var H := float(s["H"]) * C.K; var run := H + ch + (CHAIN_UP + 10.0) * C.K
		var dnx := (float(s["down_cx"]) - float(s["up_cx"])) * C.K
		for lx in [0.0, dnx]:
			for k in [-1.0, 1.0]: _box(node, Vector3(0.05, run + 0.3, 0.05), iron).position = Vector3((lx as float) + (k as float) * (cw / 2.0 + 0.06), run / 2.0 - 0.15, back_z - 0.03)   # 안내 레일 둘
			_box(node, Vector3(0.03, H, 0.03), ink).position = Vector3((lx as float), H / 2.0 + ch + CHAIN_UP * C.K, back_z + 0.02)   # 사슬 줄
		var wheels: Array = []
		for wy in [0.0, H]:
			var axle := Node3D.new(); axle.position = Vector3(dnx / 2.0, (wy as float) + ch + CHAIN_UP * C.K, back_z + 0.02); node.add_child(axle)   # 굴대 — 앞뒤 축으로 돈다(_place)
			var wh := MeshInstance3D.new(); var wm := CylinderMesh.new(); wm.top_radius = lane_w() * C.K / 2.0; wm.bottom_radius = wm.top_radius; wm.height = 0.06; wm.radial_segments = 12; wh.mesh = wm
			wh.material_override = brass; wh.rotation.x = PI / 2.0; wh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; axle.add_child(wh)   # 톱니바퀴
			wheels.append(axle)
		var cabs: Array = []; var lanes: Array = []
		for k in int(s["cabins"]):
			var cab := Node3D.new(); node.add_child(cab)
			_box(cab, Vector3(cw, 0.11, cd), oak).position = Vector3(0, -0.055, body_z)                      # 바닥 — 윗면이 원점 높이
			_box(cab, Vector3(cw, 0.08, cd), oak).position = Vector3(0, ch + 0.04, body_z)                    # 지붕
			_box(cab, Vector3(cw, ch, 0.06), paper).position = Vector3(0, ch / 2.0, back_z + 0.03)           # 뒷벽
			_box(cab, Vector3(cw - 0.1, 0.07, 0.07), brass).position = Vector3(0, float(kind.get("rail_h", 34.0)) * C.K, back_z + 0.12)   # 난간 — 손이 쥐는 자리
			_box(cab, Vector3(0.05, CHAIN_UP * C.K + 0.1, 0.05), iron).position = Vector3(0, ch + 0.08 + CHAIN_UP * C.K / 2.0, back_z + 0.02)   # 걸이 — 지붕에서 사슬로
			_box(cab, Vector3(0.22, 0.16, 0.02), plate).position = Vector3(0, ch - 0.3, back_z + 0.07)      # 번호판 — 강조색만
			cabs.append(cab); lanes.append(int(pos(s, k, t)["lane"]))
		var creak := AudioStreamPlayer3D.new(); creak.stream = _tick_wav(float(kind.get("creak_hz", 140)), 0.2); creak.volume_db = -10.0; creak.unit_size = 6.0; creak.max_distance = 30.0; node.add_child(creak)
		var clank := AudioStreamPlayer3D.new(); clank.stream = _tick_wav(float(kind.get("clank_hz", 260)), 0.12); clank.volume_db = -14.0; clank.unit_size = 6.0; clank.max_distance = 30.0; node.add_child(clank)
		s["node"] = node; s["cabs"] = cabs; s["lanes"] = lanes; s["wheels"] = wheels; s["creak"] = creak; s["clank"] = clank
		chains.append(s)
		_place(s)

## 칸을 지금 자리로, 톱니는 간 만큼 돈다(살아 있는 것은 움직인다)
func _place(s: Dictionary) -> void:
	var cabs: Array = s["cabs"]
	for k in cabs.size():
		var p := pos(s, k, t)
		(cabs[k] as Node3D).position = Vector3((float(p["x"]) - float(s["up_cx"])) * C.K, (float(p["y"]) - float(s["y_bot"])) * C.K, 0)
	var ang := -float(s["side"]) * speed() * t / (lane_w() / 2.0)   # 간 거리 / 반지름
	for wv in (s["wheels"] as Array): (wv as Node3D).rotation.z = ang

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 디딤·톱니 소리 — 짧은 기음이 빠르게 잦아든다(널의 creak 과 같은 식). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.3) * 0.2) * exp(-k * 9.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
