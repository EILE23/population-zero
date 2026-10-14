class_name ClimbTapestry
extends Node3D
## Climb 콘텐츠 팩 '태피스트리'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 옛 회관(Old hall) 층(바람구멍 층은 뺀다)의 잇단 두 still 발판 사이 틈(90..220 px) — 절벽에서 나온 받침 둘이 놋쇠 고리 레일을 위 발판 윗면보다 hang + lift 위에 받치고(아래 발판 가장자리 조금 너머에서 위 발판 가장자리 몸 하나 앞까지), 레일의 고리 ring_n 개에 긴 천(tap_w 폭)이 걸려 그 단이 아래 발판 윗면 hem 위에 늘어진다. 천은 레일의 아래 발판 쪽 끝에서 쉰다.
## 아래 발판 위, 틈 쪽 가장자리 HW + reach 안에서 C: 천을 쥔다(scale — 손을 번갈아 뻗어 천을 당기고 무릎을 끌어올려 발로 천을 밀며 오르는 몸; 뻗고, 당기고, 다시 쥔다, 정지화가 아니다): 몸은 climb_v 로 오르고(손이 레일에 닿으면 — 발이 위 발판 윗면 lift 위 — 거기서 매달린다) 그동안 고리가 drift_v 로 위 발판 쪽으로 미끄러진다; 둘 다 끝나면 settle_s 에 걸쳐 건너가 선다(발이 위 발판 윗면, 가장자리 inset 안 — 그 틱의 y 가 발판 윗면이라 다음 틱 로더의 착지 판정이 밟는다).
## ↓ 는 고리의 속도를 안고 놓고(let_go 의 vx), SPACE 는 그 속도를 얹어 뛴다. 빈 천은 back_v 로 제자리로 돌아가고 거기 닿기 전엔(그리고 놓은 지 grace_s 안엔) 못 쥔다. 천단은 층의 바람에 sway px 흔들리고(바람 없는 회관 안에서도 그 1/3) 매달린 몸도 같이 흔들린다.
## 밀지도, 떨어뜨리지도, 거절하지도, 값을 받지도 않는다 — 틈을 건너는 맨 점프는 그대로다(천은 그냥 지나가고 레일은 발판이 아니다).
## 종 줄(run 128 — 줄이 몸을 끌어올린다)·빨랫줄(run 143 — 손이 옆으로 간다)·등롱 장대(run 133 — 장대가 넘어간다)와 다르다: 이건 제 손으로 오르는 동안 걸린 것이 옆으로 실어다 주는 첫 조각 — 오르기와 건너기가 한 몸짓. 자세는 scale(stick3d_scale.gd — 운영자 보드의 '밧줄·천 오르기' 가족).
## 로더가 할 일(climb.gd, 운영자 세션): `var tp := ClimbTapestry.new(); add_child(tp)`; 층을 지을 때 `var bl := cb.plan(n, plats); var dr := cr.plan(n, plats, bl); var ll := cl.plan(n, plats, bl + dr); tp.build(root, tp.plan(n, plats, bl + dr + ll + dw.plan(n, plats, bl + dr + ll), wind_of(n)))` (종 줄·회전문·빨랫줄·도개교의 계획을 taken 으로 — 한 틈을 둘이 안 나눈다); 매 틱 `tp.sync(_t)`;
## 발판에 선 가지에서 act 가 막 눌렸으면(`Input.is_action_just_pressed("act")`) `var g := tp.grip(on, x, z, true); if not g.is_empty(): scaling = g; on = {}; vx = 0.0; vy = 0.0; charge = 0.0; face = float(g["dir"])` (scaling 은 로더의 새 사전 — holding 처럼; 천 밖에선 C 는 로더의 것);
## 매달린 매 틱(`_hold` 와 같은 자리, 맨 앞): `var r := tp.climb(scaling, dt, fig); x = r["x"]; y = r["y"]; apex = y; fig.pose_request = "scale"; stamina -= dt * 0.09; if r["done"] or r["lost"]: scaling = {}; fig.pose_request = ""`;
## SPACE 를 놓으면 `var v := tp.let_go(scaling); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9; vx = dir * RUN * 0.9 + v["vx"]; scaling = {}; 자세 ""`; ↓ 나 힘이 다하면 `vx = v["vx"]; vy = 0.0; scaling = {}`.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_tapestry.gd

const PACK := "res://data/climb/tapestry.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_IN := 20.0      # taken 조각이 이 틈의 것인가: y 가 아래 발판 윗면 − BAND_IN 부터 위 발판 윗면 − BAND_IN 앞까지(run 152 의 띠 규칙 — 탑은 지그재그라 모든 틈이 한 x 열에 쌓인다)
const GRAB_T := 0.2        # 쥔 자리에서 천 밑으로 옮겨 가는 시간(초) — 자세의 예비와 같다
const CLOTH_D := 2.0       # 천의 두께(px)
const RAIL_R := 2.0        # 레일의 반지름(px)
const RING_R := 4.0        # 고리의 반지름(px)
const BACK_Z := 6.0        # 천은 몸 바로 뒤(px) — 종 줄과 같다

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.tapestry
var cloths: Array = []          # 지은 천 {id, kind "tapestry", n, x, w, y, rail_y, hem_y, top, x_start, x_end, x_in, hinge_x, dir, gap, wind, a_id, b_id, a_y, b_y, z, d, cx, gx, rider, t0, feet, settle, held, node, rings, cloth, rustle, click}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("tapestry", {})

func sync(now: float) -> void:
	t = now

func tap_w() -> float:
	return maxf(2.0 * C.HW, float(kind.get("tap_w", 36.0)))

func hem() -> float:
	return maxf(0.0, float(kind.get("hem", 20.0)))

func hang() -> float:
	return maxf(10.0, float(kind.get("hang", 58.0)))

func lift() -> float:
	return maxf(2.0, float(kind.get("lift", 12.0)))

func inset() -> float:
	return maxf(C.HW, float(kind.get("inset", 14.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 18.0)))

func climb_v() -> float:
	return maxf(5.0, float(kind.get("climb_v", 40.0)))

func drift_v() -> float:
	return maxf(5.0, float(kind.get("drift_v", 30.0)))

func back_v() -> float:
	return maxf(5.0, float(kind.get("back_v", 30.0)))

func settle_s() -> float:
	return maxf(0.05, float(kind.get("settle_s", 0.35)))

func grace_s() -> float:
	return maxf(0.0, float(kind.get("grace_s", 0.4)))

func sway() -> float:
	return maxf(0.0, float(kind.get("sway", 6.0)))

## 천단의 흔들림(px) — 바람이 셀수록 크게(60 px/s 바람이면 다), 없어도 1/3 은 흔들린다(회관 안 공기); 바람 쪽으로 치우친다
func sway_at(s: Dictionary, at: float) -> float:
	var w := float(s.get("wind", 0.0))
	var amp := sway() * (1.0 / 3.0 + 2.0 / 3.0 * minf(1.0, absf(w) / 60.0))
	return amp * sin(at * TAU * float(kind.get("sway_hz", 0.35))) + sway() * clampf(w / 120.0, -0.5, 0.5)

## 천의 높이 y(px)에서의 흔들림 — 레일에선 0, 단에서 sway_at
func sway_y(s: Dictionary, at: float, y: float) -> float:
	var h := float(s["rail_y"]) - float(s["hem_y"])
	return sway_at(s, at) * clampf((float(s["rail_y"]) - y) / maxf(1.0, h), 0.0, 1.0)

## 고리가 제자리(아래 발판 쪽 끝)에 있나
func home(s: Dictionary) -> bool:
	return absf(float(s["cx"]) - float(s["x_start"])) < 0.5

## 층 n(테마 층·조각의 only 층만)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 min_dy..max_dy 높으며 레일의 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나. wind 는 그 층의 바람(climb.gd wind_of — 흔들림만). 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = [], wind := 0.0) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := maxf(tap_w() + 2.0 * C.HW + inset() + 8.0, float(kind.get("min_gap", 90.0))); var max_gap := float(kind.get("max_gap", 220.0))
	var min_dy := float(kind.get("min_dy", 40.0)); var max_dy := float(kind.get("max_dy", 150.0))
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
			var dir := 1.0 if bx0 >= ax1 else -1.0   # 아래 발판에서 위 발판 쪽
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			if float(a["w"]) < 2.0 * C.HW + reach() + 4.0 or float(b["w"]) < inset() + C.HW + 4.0: continue
			var hinge := ax1 if dir > 0.0 else ax0
			var rail_y := float(b["y"]) + hang() + lift()
			var x_start := hinge + dir * (tap_w() / 2.0 + 4.0); var x_end := hinge + dir * (gap - C.HW - 4.0); var x_in := hinge + dir * (gap + inset())
			var x0 := minf(hinge - dir * (C.HW + reach()), x_in) - 4.0; var x1 := maxf(hinge - dir * (C.HW + reach()), x_in) + 4.0
			if not _clear(plats, a, b, x0, x1, float(a["y"]) + 1.0, rail_y + 10.0): continue
			if not _free(taken, x0, x1, float(a["y"]) - BAND_IN, float(b["y"]) - BAND_IN): continue
			found.append({ "gap": gap, "dir": dir, "hinge_x": hinge, "x_start": x_start, "x_end": x_end, "x_in": x_in, "rail_y": rail_y, "hem_y": float(a["y"]) + hem(), "top": rail_y - hang(),
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]), "z": float(a.get("z", 0.0)), "d": float(a.get("d", C.DEPTH_HALF * 2.0)) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.T%d" % [n, i]; s["kind"] = "tapestry"; s["n"] = n; s["wind"] = wind
			s["x"] = minf(float(g["x_start"]), float(g["x_end"])) - tap_w() / 2.0; s["w"] = absf(float(g["x_end"]) - float(g["x_start"])) + tap_w(); s["y"] = float(g["a_y"])
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 레일의 상자(가장자리에 선 몸부터 위 발판 안 inset 까지, 아래 발판 윗면..레일 위 손 하나)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x·w·y, 있으면 rail_y·beam_y·y_top 까지의 키)이 이 틈에 들지 않나 — 틈의 x 와 겹치고 조각의 높이 띠가 [ylo, yhi) 와 겹치면 그 틈은 그 팩의 것(run 152 의 규칙)
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qtop := qy
		for key in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qtop = maxf(qtop, float(q[key]))
		if x1 > qx0 and x0 < qx1 and qtop >= ylo and qy < yhi: return false
	return true

## C 를 누른 틱 — 아래 발판 위에서 틈 쪽 가장자리 HW + reach 안이고 천이 제자리에 비어 있으면(놓은 지 grace_s 지난) 쥔다: 돌려주는 사전의 x·y 가 몸의 자리(천 밑, 발은 아래 발판 윗면), dir 이 건너는 쪽. 걷는 깊이여야 한다
func grip(on: Dictionary, x: float, z: float, pressed: bool) -> Dictionary:
	if not pressed: return {}
	var oid := String(on.get("id", ""))
	for sv in cloths:
		var s: Dictionary = sv
		if oid != String(s["a_id"]): continue
		if absf(z - C.PLAYER_Z) >= C.HZ + 4.0: continue
		if absf(x - float(s["hinge_x"])) > C.HW + reach(): continue
		if bool(s["rider"]) or not home(s) or t - float(s["held"]) < grace_s(): continue
		s["rider"] = true; s["t0"] = t; s["feet"] = 0.0; s["settle"] = -1.0; s["gx"] = x
		_play(s["rustle"])
		var hit := s.duplicate(); hit["x"] = float(s["cx"]); hit["y"] = float(s["a_y"])
		return hit
	return {}

## 매달린 매 틱 — 몸의 자리 {x, y, face, done, lost}: 발은 climb_v 로 top(손이 레일)까지 오르고 고리는 drift_v 로 x_end 까지 간다; 둘 다 끝나면 settle_s 에 걸쳐 x_in·위 발판 윗면으로 건너가 done. fig 가 있으면 자세가 읽을 메타(scale_v 오르는 중 1, scale_sw 흔들림 −1..1, scale_k 건너가는 몫 0..1)를 적어 준다. 천이 사라졌으면 lost
func climb(on: Dictionary, dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "x": float(on.get("x", 0.0)), "y": float(on.get("y", 0.0)), "face": 1.0, "done": false, "lost": true }
	var top := float(s["top"]); var dir := float(s["dir"])
	var x := 0.0; var y := 0.0; var v := 0.0; var kk := 0.0
	if float(s["settle"]) < 0.0:
		var feet := minf(top - float(s["a_y"]), float(s["feet"]) + climb_v() * dt); s["feet"] = feet
		s["cx"] = move_toward(float(s["cx"]), float(s["x_end"]), drift_v() * dt)
		y = float(s["a_y"]) + feet
		x = lerpf(float(s["gx"]), float(s["cx"]), smoothstep(0.0, GRAB_T, t - float(s["t0"])))   # 쥔 자리에서 천 밑으로
		v = 1.0 if feet < top - float(s["a_y"]) - 0.01 else 0.0
		if v == 0.0 and absf(float(s["cx"]) - float(s["x_end"])) < 0.01:
			s["settle"] = t; _play(s["click"])
	else:
		kk = smoothstep(0.0, 1.0, (t - float(s["settle"])) / settle_s())
		x = lerpf(float(s["x_end"]), float(s["x_in"]), kk); y = lerpf(top, float(s["b_y"]), kk)
	var sw := sway_y(s, t, y + hang()) if kk < 1.0 else 0.0
	if fig:
		fig.set_meta("scale_v", v); fig.set_meta("scale_sw", clampf(sw / maxf(1.0, sway()), -1.0, 1.0)); fig.set_meta("scale_k", kk)
	if kk >= 1.0:
		s["rider"] = false; s["held"] = t; s["feet"] = 0.0; s["settle"] = -1.0
		return { "x": float(s["x_in"]), "y": float(s["b_y"]), "face": dir, "done": true, "lost": false }
	return { "x": x + sw * (1.0 - kk), "y": y, "face": dir, "done": false, "lost": false }

## 놓는 순간 고리의 속도 {vx} px/s — 미끄러지는 중이면 그만큼 안고 간다; 천은 비어 제자리로 돌아간다
func let_go(on: Dictionary) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "vx": 0.0 }
	var moving := float(s["settle"]) < 0.0 and absf(float(s["cx"]) - float(s["x_end"])) >= 0.01
	s["rider"] = false; s["held"] = t; s["feet"] = 0.0; s["settle"] = -1.0
	return { "vx": float(s["dir"]) * drift_v() if moving else 0.0 }

func _find(id: String) -> Dictionary:
	for sv in cloths:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 빈 천은 제자리로 미끄러진다; 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	cloths = cloths.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_lens 와 같은 식)
	for sv in cloths:
		var s: Dictionary = sv
		if not bool(s["rider"]): s["cx"] = move_toward(float(s["cx"]), float(s["x_start"]), back_v() * delta)
		_place(s)

## 천을 짓는다 — root 는 그 층의 노드. 노드 원점은 (천의 쉬는 자리 x_start, 아래 발판 윗면, 절벽 면); 절벽에서 나온 받침 둘·놋쇠 레일·미끄러지는 고리 노드(고리 ring_n·천 노드: 종이빛 천, 잉크 무늬, 자주 단 띠, 술 다섯)·소리 둘
func build(root: Node3D, planned: Array) -> void:
	var rr := RAIL_R * C.K; var gr := RING_R * C.K; var tw := tap_w() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var node := Node3D.new(); node.position = C.to3(float(s["x_start"]), float(s["a_y"]), C.WALL_Z * C.K); root.add_child(node)
		var brass := _mat(Color("b08d57")); var wood := _mat(Color("8a6a4a")); var paper := _mat(Color("efe9e2")); var ink := _mat(Color("2f2a4e")); var band := _mat(Color("ad7096"))
		var ry := (float(s["rail_y"]) - float(s["a_y"])) * C.K; var rz := (C.PLAYER_Z - BACK_Z - C.WALL_Z) * C.K
		var run := (float(s["x_end"]) - float(s["x_start"])) * C.K; var rl := absf(run) + tw
		var rail := MeshInstance3D.new(); var rm := CylinderMesh.new(); rm.top_radius = rr; rm.bottom_radius = rr; rm.height = rl; rm.radial_segments = 8
		rail.mesh = rm; rail.material_override = brass; rail.rotation.z = PI / 2.0; rail.position = Vector3(run / 2.0, ry, rz); rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(rail)   # 레일 — 축이 x
		for ei in 2:
			var bx := run / 2.0 + (float(ei) * 2.0 - 1.0) * (rl / 2.0 - 2.0 * C.K)
			_box(node, Vector3(4.0 * C.K, 4.0 * C.K, rz + 2.0 * C.K), wood).position = Vector3(bx, ry, rz / 2.0)   # 받침 — 절벽에서 레일까지
		var rings := Node3D.new(); rings.position = Vector3(0.0, ry, rz); node.add_child(rings)   # 미끄러지는 고리 — x 를 매 틱 옮긴다
		var rn := maxi(2, int(kind.get("ring_n", 5)))
		for i in rn:
			var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = gr - 1.0 * C.K; tm.outer_radius = gr; tm.rings = 8; tm.ring_segments = 6
			ring.mesh = tm; ring.material_override = brass; ring.rotation.z = PI / 2.0; ring.position = Vector3((float(i) / float(rn - 1) - 0.5) * (tw - 4.0 * C.K), 0.0, 0.0)
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; rings.add_child(ring)   # 고리 — 레일을 꿴다
		var cloth := Node3D.new(); cloth.position = Vector3(0.0, -gr, 0.0); rings.add_child(cloth)   # 천 — 고리 밑에서 늘어져 레일을 축으로 흔들린다
		var ch := (float(s["rail_y"]) - float(s["hem_y"])) * C.K - gr
		_box(cloth, Vector3(tw, ch, CLOTH_D * C.K), paper).position = Vector3(0.0, -ch / 2.0, 0.0)
		_box(cloth, Vector3(tw * 0.5, ch * 0.4, CLOTH_D * C.K + 0.004), ink).position = Vector3(0.0, -ch * 0.45, 0.0)   # 무늬 — 잉크 한 장
		_box(cloth, Vector3(tw, 6.0 * C.K, CLOTH_D * C.K + 0.006), band).position = Vector3(0.0, -ch + 3.0 * C.K, 0.0)   # 단 띠 — 강조색만
		for i in 5:
			_box(cloth, Vector3(2.0 * C.K, 6.0 * C.K, CLOTH_D * C.K), paper).position = Vector3((float(i) / 4.0 - 0.5) * (tw - 6.0 * C.K), -ch - 3.0 * C.K, 0.0)   # 술
		var rustle := _snd(node, float(kind.get("rustle_hz", 180)), 0.35, -14.0); var click := _snd(node, float(kind.get("click_hz", 1320)), 0.12, -12.0)
		s["cx"] = float(s["x_start"]); s["gx"] = float(s["x_start"]); s["rider"] = false; s["t0"] = -9.0; s["feet"] = 0.0; s["settle"] = -1.0; s["held"] = -9.0
		s["node"] = node; s["rings"] = rings; s["cloth"] = cloth; s["rustle"] = rustle; s["click"] = click
		cloths.append(s)
		_place(s)

## 고리를 지금 자리로, 천을 흔들림만큼 레일 축으로 기울인다(단이 sway_at 만큼 옮겨 가게)
func _place(s: Dictionary) -> void:
	(s["rings"] as Node3D).position.x = (float(s["cx"]) - float(s["x_start"])) * C.K
	var h := maxf(1.0, float(s["rail_y"]) - float(s["hem_y"]))
	(s["cloth"] as Node3D).rotation.z = asin(clampf(sway_at(s, t) / h, -0.5, 0.5))

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

func _snd(parent: Node3D, hz: float, secs: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — rustle(0.35초, 낮은 기음에 거친 떨림: 천이 쓸린다)·click(0.12초, 고리가 레일 끝에 닿는다). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.4 + sin(ph * 2.7) * 0.2 + sin(ph * 7.3) * 0.1) * exp(-k * 5.0) * (0.5 + 0.5 * absf(sin(k * secs * 70.0)))
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
