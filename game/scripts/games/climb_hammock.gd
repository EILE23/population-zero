class_name ClimbHammock
extends Node3D
## Climb 콘텐츠 팩 '해먹 그물'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 공중 정원(Hanging garden) 층의 잇단 두 still 발판 사이 틈(min_gap..max_gap, 높이차 max_dy 안) 아래 — 발판마다 틈 쪽 끝에 나무 말뚝, 거기서 턱을 넘어 면을 타고 내려온 줄이 낮은 발판 윗면 hang 아래의 고리에, 두 고리 사이에 빈 채로 dip 처진 밧줄 그물(세로 줄·가로 살·한쪽 끝의 베개).
## 틈으로 떨어지는 몸(catch_vy 보다 빠르게)이 그물의 쉼선(y_low − hang − dip)을 지나면 받는다(catch): sag_s 에 걸쳐 떨어진 속도만큼(|vy|·sag_k, sag_min..sag_max) 처지며 몸은 그물 가운데로 굴러가고, 그다음 rest_s 에 걸쳐 rest_sag 로 되돌아온다 — 누워 있으면 얕은 쉼 처짐만 남는다.
## 누운 자세는 loll(stick3d_loll.gd — 운영자 보드의 '소파에 눕기' 가족: 등을 대고 한 팔은 머리 뒤, 한 팔은 가장자리 너머, 발 하나가 까딱이며 그물의 흔들림에 몸째 흔들린다).
## SPACE 는 처진 깊이만큼 던져 올린다(let_go(on, true): 높이 = 지금 처짐 × throw, vy = sqrt(2·G·h)) — 깊이 떨어진 직후의 SPACE 는 점프보다 높이, 늦은 SPACE 는 깡충; ↓ 는 굴러 나가 떨어진다(vy 0). 방금 놓은 그물은 grace_s 동안 안 받는다.
## 빈 그물은 그 층의 바람(climb.gd wind_of)에 흔들린다 — 바람 없는 층도 그 1/3 로(살아 있는 건 움직인다). 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 두 발판의 맨 착지와 맨 점프는 그대로; 그물은 층을 지나쳐 떨어질 몸에게만 있다.
## 로더가 할 일(climb.gd, 운영자 세션): `var ch := ClimbHammock.new(); add_child(ch)`; 층을 지을 때 `ch.build(root, ch.plan(n, plats, wind_of(n), cb.plan(n, plats) + cg.plan(n, plats) + cm.plan(n, plats)))` (다리·유령 판·버섯의 계획을 taken 으로 — 한 틈을 둘이 안 나눈다); 매 틱 `ch.sync(_t)`;
## 공중에서 로더의 착지 판정이 비었고 vy < 0 이면: `var c := ch.catch(x, y, ny, z, vy); if not c.is_empty(): clinging = c; on = {}; vx = 0.0; vy = 0.0; charge = 0.0; apex = y` (clinging 은 로더의 새 사전 — holding 처럼);
## 누운 매 틱(`_hold` 와 같은 자리, 맨 앞): `var r := ch.cling(clinging, fig); x = r["x"]; y = r["y"]; apex = y; fig.pose_request = "loll"; if r["lost"]: clinging = {}; fig.pose_request = ""`;
## SPACE 를 놓으면 `var v := ch.let_go(clinging, true); vy = v["vy"]; vx = dir * RUN * 0.9; clinging = {}; 자세 ""` (던지는 건 그물 — 점프 세기는 안 섞는다); ↓ 면 `var v := ch.let_go(clinging, false); vy = v["vy"]; vx = v["vx"]; clinging = {}; 자세 ""`.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_hammock.gd

const PACK := "res://data/climb/hammock.json"
const C = preload("res://scripts/games/climb.gd")
const PEG := 8.0          # 말뚝이 발판 끝에서 안쪽으로 선 거리(px)
const TAKEN_HALF := 50.0  # 폭이 없는 taken 조각(버섯: 갓의 반지름쯤)의 반폭(px)
const TAKEN_UP := 100.0   # taken 조각 위로 비워 두는 높이(px) — 버섯 갓과 그 위의 몸, 유령 판 위의 몸
const BODY := 50.0        # 고리 위로 비워 두는 높이(px) — 그물에 누운 몸과 고리

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.net
var nets: Array = []            # 지은 그물 {id, kind "hammock", x, y, w, z, d, x0, x1, y_l, y_r, y_low, mid, half, line, anchor, wind, node, net, creak, snap, go, cx, sag, rider, held, rel}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("net", {})

func sync(now: float) -> void:
	t = now

func hang() -> float:
	return float(kind.get("hang", 24.0))

func dip() -> float:
	return float(kind.get("dip", 14.0))

func depth() -> float:
	return float(kind.get("d", 30.0))

func sag_s() -> float:
	return maxf(0.05, float(kind.get("sag_s", 0.4)))

func rest_s() -> float:
	return maxf(0.05, float(kind.get("rest_s", 3.0)))

func sag_max() -> float:
	return float(kind.get("sag_max", 80.0))

## 떨어진 속도(px/s, 음수)가 만드는 처짐(px)
func sag_of(vy: float) -> float:
	return clampf(absf(vy) * float(kind.get("sag_k", 0.1)), float(kind.get("sag_min", 20.0)), sag_max())

## 처짐(px)이 던져 올리는 속도(px/s) — 높이 처짐 × throw 를 G 로
func throw_v(sag: float) -> float:
	return sqrt(2.0 * C.G * maxf(0.0, sag * float(kind.get("throw", 3.0))))

## 받힌 지 k 초의 처짐(px): sag_s 에 걸쳐 sag 까지, 그다음 rest_s 에 걸쳐 rest_sag 로
func sag_at(s: Dictionary, k: float) -> float:
	var sag := float(s["sag"]); var ss := sag_s()
	if k < ss: return sag * smoothstep(0.0, 1.0, k / ss)
	return lerpf(sag, float(kind.get("rest_sag", 30.0)), clampf((k - ss) / rest_s(), 0.0, 1.0))

## 지금 처짐(px) — 누운 몸이 없으면 0
func sag_now(s: Dictionary) -> float:
	return sag_at(s, t - float(s["go"])) if bool(s["rider"]) else 0.0

## 빈 그물의 흔들림(rad) — 바람 120 에 sway_a, 바람 없는 층은 그 1/3; 그물마다 위상이 다르다
func sway(s: Dictionary) -> float:
	var k := 0.33 + 0.67 * clampf(absf(float(s["wind"])) / 120.0, 0.0, 1.0)
	return float(kind.get("sway_a", 0.12)) * k * sin(t * TAU / maxf(0.5, float(kind.get("sway_s", 2.6))) + float(s["mid"]) * 0.01)

func _process(delta: float) -> void:
	t += delta
	nets = nets.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_door 와 같은 식)
	for sv in nets: _place(sv)

## 층 n(테마 층, 조각의 only 층만)의 잇단 두 still 발판(조각의 on) 사이 틈(min_gap..max_gap, 높이차 max_dy 안) 중 그물 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 것들 중 가장 넓은 하나(같으면 낮은 쪽). 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, wind: float = 0.0, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var min_gap := float(kind.get("min_gap", 70.0)); var max_gap := float(kind.get("max_gap", 200.0)); var max_dy := float(kind.get("max_dy", 130.0))
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			if absf(float(a["y"]) - float(b["y"])) > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			var right := bx0 >= ax1   # b 가 오른쪽에
			var gap := bx0 - ax1 if right else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var x0 := ax1 if right else bx1; var x1 := bx0 if right else ax0
			var y_l := float(a["y"]) if right else float(b["y"]); var y_r := float(b["y"]) if right else float(a["y"])
			var y_low := minf(y_l, y_r); var line := y_low - hang() - dip()
			var ylo := line - sag_max() - 4.0; var yhi := y_low - hang() + BODY   # 그물 상자 — 가장 깊은 처짐부터 고리 위의 누운 몸까지(틈의 위쪽은 비워 두지 않는다: 지그재그 발판에선 한 기둥에 틈이 층층이 쌓이고, 한 단 아래 발판은 92px 밑이라 깊은 처짐 82 가 그 위를 지난다)
			if not _clear(plats, a, b, x0, x1, ylo, yhi): continue
			if not _free(taken, x0, x1, ylo, yhi): continue
			spans.append({ "gap": gap, "x0": x0, "x1": x1, "y_l": y_l, "y_r": y_r, "y_low": y_low, "line": line, "a_id": String(a["id"]), "b_id": String(b["id"]) })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["y_low"]) < float(q["y_low"]))
		for i in range(0, mini(int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.H%d" % [n, i]; s["kind"] = "hammock"; s["x"] = float(g["x0"]); s["w"] = float(g["x1"]) - float(g["x0"]); s["y"] = float(g["line"]); s["z"] = C.PLAYER_Z; s["d"] = depth()
			s["mid"] = (float(g["x0"]) + float(g["x1"])) / 2.0; s["half"] = float(s["w"]) / 2.0; s["anchor"] = float(g["y_low"]) - hang(); s["wind"] = wind
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 그물 상자(틈의 x, 가장 깊은 처짐..고리 위의 몸)에 그 두 발판 말고 다른 발판이 걸리지 않나 — 지름길 판이 틈에 있으면 그물이 걸린다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var px0 := float(p["x"]) - 10.0; var px1 := float(p["x"]) + float(p["w"]) + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken)이 그물 상자에 닿지 않나 — 다리(x, w, y0, y1)·유령 판(x, w, y)·버섯(x, y 만: 반폭 TAKEN_HALF); 조각 위 TAKEN_UP 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qh := float(q["w"]) / 2.0 + 10.0 if q.has("w") else TAKEN_HALF
		var qc := float(q["x"]) + (float(q["w"]) / 2.0 if q.has("w") else 0.0)
		var qx0 := qc - qh; var qx1 := qc + qh
		var qy := float(q.get("y", 0.0))
		var qy0 := minf(qy, minf(float(q.get("y0", qy)), float(q.get("y1", qy)))) - 10.0
		var qy1 := maxf(qy, maxf(float(q.get("y0", qy)), float(q.get("y1", qy)))) + TAKEN_UP
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 공중에서 떨어지는 몸(vy < catch_vy) — 로더의 착지 판정이 빈 다음: 틈 안(몸 반폭을 뺀 자리)에서 쉼선을 지나면 받는다 — 돌려주는 사전의 x·y 가 몸의 자리(받힌 x, 쉼선). 방금 놓은 그물(grace_s)·빈 그물이 아닌 것은 빈 사전
func catch(x: float, y: float, ny: float, z: float, vy: float) -> Dictionary:
	if vy >= float(kind.get("catch_vy", -120.0)): return {}
	for sv in nets:
		var s: Dictionary = sv
		if bool(s["rider"]): continue
		var line := float(s["line"])
		if y < line or ny > line: continue
		if absf(z - float(s["z"])) >= depth() / 2.0 + C.HZ: continue
		if x < float(s["x0"]) + C.HW or x > float(s["x1"]) - C.HW: continue
		if t - float(s["held"]) < float(kind.get("grace_s", 0.4)): continue
		s["go"] = t; s["cx"] = x; s["sag"] = sag_of(vy); s["rider"] = true; s["rel"] = -9.0
		_play(s["creak"])
		var hit := s.duplicate(); hit["x"] = x; hit["y"] = line
		return hit
	return {}

## 누운 매 틱 — 그물 속 몸의 자리 {x, y, done false, lost}: sag_s 에 걸쳐 처지며 가운데로 굴러가고, 그다음 쉼 처짐으로. fig 가 있으면 자세가 읽을 안김(loll_c 0..1)·흔들림(loll_sw −1..1)·깊이(loll_d 0..1)를 적는다
func cling(on: Dictionary, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty() or not bool(s["rider"]): return { "x": float(on.get("x", 0.0)), "y": float(on.get("y", 0.0)), "done": false, "lost": true }
	var k := t - float(s["go"])
	var settle := smoothstep(0.0, 1.0, k / sag_s())
	var sag := sag_at(s, k)
	if fig:
		fig.set_meta("loll_c", settle)
		fig.set_meta("loll_sw", sway(s) / maxf(0.001, float(kind.get("sway_a", 0.12))))
		fig.set_meta("loll_d", sag / sag_max())
	return { "x": lerpf(float(s["cx"]), float(s["mid"]), settle), "y": float(s["line"]) - sag, "done": false, "lost": false }

## 놓는 순간 {vy, vx} px/s — jump 면 지금 처짐만큼 던져 올린다(snap), 아니면 굴러 나가 떨어진다(0); 그물은 grace_s 동안 다시 안 받고 튕겨 오른다
func let_go(on: Dictionary, jump: bool) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty() or not bool(s["rider"]): return { "vy": 0.0, "vx": 0.0 }
	var vy := throw_v(sag_now(s)) if jump else 0.0
	s["rider"] = false; s["held"] = t; s["rel"] = t
	if jump: _play(s["snap"])
	return { "vy": vy, "vx": 0.0 }

func _find(id: String) -> Dictionary:
	for sv in nets:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 그물을 짓는다 — root 는 그 층의 노드. 노드 원점은 두 고리의 가운데(mid, anchor, z); 말뚝 둘(발판 위), 끌줄 둘(턱을 넘어 면을 타고 고리까지), 그물 묶음(세로 줄·가로 살·베개 — 흔들리고 처진다), creak, snap
func build(root: Node3D, planned: Array) -> void:
	var dk := dip() * C.K; var dm := depth() * C.K
	var n_rope := maxi(2, int(kind.get("ropes", 5))); var n_rung := maxi(2, int(kind.get("rungs", 7)))
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var node := Node3D.new(); node.position = C.to3(float(s["mid"]), float(s["anchor"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("8a6a4a")); var hemp := _mat(Color("d8c39a")); var moss := _mat(Color("9cc86a")); var linen := _mat(Color("efe9e2"))
		var half := float(s["half"]) * C.K
		for side in [-1.0, 1.0]:   # 말뚝과 끌줄 — 발판 윗면은 쪽마다 다르다(y_l, y_r)
			var top := (float(s["y_l"] if side < 0.0 else s["y_r"]) - float(s["anchor"])) * C.K
			_box(node, Vector3(0.14, 0.2, 0.14), wood).position = Vector3(side * (half + PEG * C.K), top + 0.1, 0)
			_box(node, Vector3(PEG * C.K + 0.02, 0.02, 0.02), hemp).position = Vector3(side * (half + PEG * C.K / 2.0), top + 0.01, 0)   # 윗면을 지나 턱까지
			_box(node, Vector3(0.02, top, 0.02), hemp).position = Vector3(side * half, top / 2.0, 0)   # 면을 타고 고리까지
		var net := Node3D.new(); net.position = Vector3(0, -dk, 0); node.add_child(net)
		for i in n_rope:   # 세로 줄 — 바깥 줄일수록 조금 높아 그릇꼴
			var zz := (float(i) - float(n_rope - 1) / 2.0) / (float(n_rope - 1) / 2.0)
			_box(net, Vector3(half * 2.0, 0.02, 0.02), hemp if i % 2 == 0 else moss).position = Vector3(0, 0.08 * zz * zz, zz * dm / 2.0)
		for j in n_rung:   # 가로 살 — 끝으로 갈수록 고리 쪽으로 오른다
			var xx := (float(j) - float(n_rung - 1) / 2.0) / (float(n_rung + 1) / 2.0)
			_box(net, Vector3(0.02, 0.02, dm), hemp).position = Vector3(xx * half, 0.06 * xx * xx + 0.01, 0)
		var pillow := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.16; sm.height = 0.14; pillow.mesh = sm; pillow.material_override = linen
		pillow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; pillow.position = Vector3(-half * 0.6, 0.09, 0); net.add_child(pillow)
		var creak := AudioStreamPlayer3D.new(); creak.stream = _tick_wav(float(kind.get("creak_hz", 140)), 0.22); creak.volume_db = -8.0; creak.unit_size = 6.0; creak.max_distance = 30.0; node.add_child(creak)
		var snap := AudioStreamPlayer3D.new(); snap.stream = _tick_wav(float(kind.get("snap_hz", 230)), 0.12); snap.volume_db = -6.0; snap.unit_size = 6.0; snap.max_distance = 30.0; node.add_child(snap)
		s["node"] = node; s["net"] = net; s["creak"] = creak; s["snap"] = snap
		s["go"] = -9.0; s["cx"] = float(s["mid"]); s["sag"] = 0.0; s["rider"] = false; s["held"] = -9.0; s["rel"] = -9.0
		nets.append(s)
		_place(s)

## 그물을 지금 자리로 — 처진 만큼 내려가고(받히는 동안 잘게 떨린다), 놓으면 튕겨 올라 잦아들고, 빈 채로는 바람에 흔들린다(몸이 누우면 흔들림은 반으로)
func _place(s: Dictionary) -> void:
	var sag := sag_now(s)
	var k := t - float(s["go"])
	var tremble := sin(t * 14.0) * 1.5 * (1.0 - clampf(k / sag_s(), 0.0, 1.0)) if bool(s["rider"]) else 0.0
	var rel := float(s["rel"]); var bounce := 0.0
	if rel > -1.0 and t - rel < 1.5: bounce = -6.0 * exp(-(t - rel) * 3.0) * cos((t - rel) * 10.0)
	var net: Node3D = s["net"]
	net.position.y = -(dip() + sag + tremble + bounce) * C.K
	net.rotation.x = sway(s) * (0.5 if bool(s["rider"]) else 1.0)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 고리·그물 소리 — 짧은 기음이 빠르게 잦아든다(회전문의 clack 과 같은 식). 한 번 재생, 반복 없음
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
