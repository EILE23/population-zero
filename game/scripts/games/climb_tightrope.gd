class_name ClimbTightrope
extends Node3D
## Climb 콘텐츠 팩 '외줄'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 별밤(Starlit) 층의 잇단 두 still 발판(std·ice·spring — 움직이거나 무너지는 턱은 밧줄을 못 쥔다) 사이 가장 넓은 틈(min_gap..max_gap, 높이차 max_dy — 이 탑의 잇단 발판은 늘 92..138 px 씩 오르니 수평한 짝은 없다: 밧줄은 다리처럼 아래 턱 끝에서 위 턱 끝으로 비탈을 오른다) 하나 — 두 턱의 마주 보는 끝 안쪽(ring_in)에 박힌 쇠고리 둘을 잇는 밧줄이 팽팽히 걸리고(sag 는 4 px — 다리의 28 과 다르다), 밑에 양철 별 셋이 실에 달린다.
## 뛰지 않고 걸어 건너는 길이지만 몸이 흔들린다: 서 있는 매 틱 몸의 밧줄 밖 벗어남(off)이 period 주기로 좌우(절벽 쪽·바깥 쪽)로 오가고, 그 진폭은 가만히 서면 base_amp, 층의 바람에 wind_amp(120 px/s 에서 다), 걸음에 speed_amp(WALK 의 반부터 다)만큼 커지며 amp_t 에 걸쳐 따라간다 — 멈추면 같은 빠르기로 다시 줄어든다.
## 벗어남이 fall_px 를 넘으면 떨어진다(fall — 로더가 on 을 비우고 기존 lurch 를 준다): 밧줄이 twang 하고 shake_s 동안 떨며 아무도 받지 않는다. 방향을 쥐고 걸으면 95 px 쯤에서 떨어지고(0.37 s), 짧게 걷다 멈추기를 되풀이하면 어떤 밧줄도 건넌다 — 박자가 솜씨다. 자세는 tiptoe(stick3d_tiptoe.gd — 팔을 수평으로 벌리고 발을 한 줄로 디디며 벗어남을 따라 기운다).
## 밧줄 다리(sway — 바닥이 흔들린다, 걸어도 떨어지지 않는다)·디딤돌(teeter — 서서 팔만)과 다르다: 이건 제 걸음의 박자가 떨어지느냐를 가르는 첫 조각. 단단한 것이 없고 값도 없다: 틈을 뛰어넘는 맨 점프는 100% 그대로고, 짧은 점프는 떨어지는 대신 밧줄에 받힌다(평이한 결과 ≥ 40% 규칙).
## 로더가 할 일(climb.gd, 운영자 세션): `var tr := ClimbTightrope.new(); add_child(tr)`; 층을 지을 때 `var ic := ci.plan(n, plats); var lp := cn.plan(n, plats, ic); var tp := ct.plan(n, plats, ic + lp); tr.build(root, tr.plan(n, plats, ic + lp + tp + ts.plan(n, plats, ic + lp + tp)), wind_of(n))` (고드름·등롱 장대·그네·망원경의 계획을 taken 으로 — 한 틈을 둘이 안 나눈다); 매 틱 `tr.sync(_t)`;
## 착지 판정에서 landed 가 비었고 vy <= 0 이면 `landed = tr.land(x, y, ny, z)` (돌려준 사전의 "y" 가 그 x 의 밧줄 높이; "step" 이 참이면 턱에서 밧줄로 내디딘 걸음);
## 서 있을 때 `on["kind"] == "tightrope"` 면 `var r := tr.stand(on, x, dt, fig); y = r["y"]; if r["fall"]: on = {}; apex = y; fig.pose_request = "lurch" else: fig.pose_request = "tiptoe"`, 밧줄을 떠나면 `if fig.pose_request == "tiptoe": fig.pose_request = ""`; lurch 는 유령 발판처럼 `LurchPoses.done(fig)` 가 참이 되면 비운다.
## 몸마다의 상태 st: 비우면 플레이어(팩의 _me — 올라선 때를 stepped_t 에, 선 매 틱을 me_t 에 남긴다), 다른 몸(외줄꾼)은 제 사전 {px, rid} 을 준다 — 앞 틱의 x 로 걸음의 빠르기를 잰다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위).
## 주민 반쪽(run 165): 밧줄마다 외줄꾼 하나(climb_ropewalker.gd — 밧줄 노드 아래 Stick3D)가 아래 고리 옆에 서서 탑의 1분마다, 그리고 플레이어가 올라선 뒤 1.5 s 에(밧줄이 비면) 같은 stand() 를 제 st 로 부르며 걸음·멈춤의 박자로 건너고(tiptoe), 건너편 고리에서 절한다(flourish); 떨어지면 같은 lurch 로 plan 이 적어 준 이 층의 발판(hops) 위에 내려 꼭대기를 타고 돌아온다. 점검은 tools/probe_tightrope.gd

const PACK := "res://data/climb/tightrope.json"
const C = preload("res://scripts/games/climb.gd")
const BODY_UP := 50.0      # 선 몸의 키(px) — 상자 위쪽 여유
const UNDER := 40.0        # 밧줄 아래로 보는 띠(px) — 다리의 _clear 와 같은 수
const WIND_REF := 120.0    # wind_amp 가 다 붙는 바람(px/s)
const SHAKE_HZ := 28.0     # 떨어진 뒤 밧줄의 떨림

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.tightrope
var ropes: Array = []           # 지은 밧줄 {id, kind "tightrope", n, x, w, y, x0, y0, x1, y1, dir, a_id, b_id, hops, z, d, wind, node, base_y, segs [MeshInstance3D…], stars [Node3D…], hum, twang, stood, fell, ph, amp, stepped_t, me_t, walker}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)
var _me := { "px": 0.0, "rid": "" }   # 플레이어의 걸음 상태 — px: 앞 틱의 몸 x, rid: 그때 선 밧줄

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("tightrope", {})

func sync(now: float) -> void:
	t = now

func sag() -> float:
	return maxf(0.0, float(kind.get("sag", 4.0)))

func catch() -> float:
	return maxf(1.0, float(kind.get("catch", 24.0)))

func ring_in() -> float:
	return maxf(2.0, float(kind.get("ring_in", 6.0)))

func period() -> float:
	return maxf(0.2, float(kind.get("period", 1.6)))

func base_amp() -> float:
	return maxf(0.0, float(kind.get("base_amp", 1.2)))

func wind_amp() -> float:
	return maxf(0.0, float(kind.get("wind_amp", 1.2)))

func speed_amp() -> float:
	return maxf(0.0, float(kind.get("speed_amp", 3.0)))

func amp_t() -> float:
	return maxf(0.05, float(kind.get("amp_t", 0.35)))

func fall_px() -> float:
	return maxf(0.5, float(kind.get("fall_px", 3.0)))

func shake_s() -> float:
	return maxf(0.1, float(kind.get("shake_s", 1.2)))

## 층 n(테마 층만)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 사이 틈 중 min_gap..max_gap 이고 높이차가 max_dy(150) 안이며 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 것들 중 가장 넓은 틈 하나 — 왼 턱 끝에서 오른 턱 끝으로. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := float(kind.get("min_gap", 100.0)); var max_gap := float(kind.get("max_gap", 200.0)); var max_dy := float(kind.get("max_dy", 150.0))
	var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var kinds: Array = piece.get("on", ["std", "ice", "spring"])
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			if absf(float(b["y"]) - float(a["y"])) > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0   # 위 발판이 오른쪽이면 +x 로 건너간다
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var x0 := ax1 if dir > 0.0 else bx1; var x1 := bx0 if dir > 0.0 else ax0   # 왼 턱 끝 → 오른 턱 끝
			var y0 := float(a["y"]) if dir > 0.0 else float(b["y"]); var y1 := float(b["y"]) if dir > 0.0 else float(a["y"])
			var ylo := minf(y0, y1); var yhi := maxf(y0, y1)
			if not _clear(plats, a, b, x0, x1, y0, y1): continue
			if not _free(taken, x0, x1, ylo - UNDER / 2.0, yhi + BODY_UP): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "dir": dir, "x0": x0, "y0": y0, "x1": x1, "y1": y1, "d": d, "a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "hops": _rects(hops, i) })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.R%d" % [n, i]; s["kind"] = "tightrope"; s["n"] = n
			s["x"] = float(g["x0"]); s["w"] = float(g["x1"]) - float(g["x0"])
			s["z"] = C.WALL_Z + float(g["d"]) / 2.0
			s["y"] = surf(s, (float(g["x0"]) + float(g["x1"])) / 2.0)   # 한가운데 밧줄 높이 — 로더의 일반 코드가 읽을 대표 높이(착지·서기는 surf 로)
			s["y_top"] = maxf(float(g["y0"]), float(g["y1"])) + BODY_UP   # 걷는 몸의 키 — 다른 팩의 _free 가 읽는 키
			out.append(s)
	return out

## 이 층의 발판 0..i(아래서 위 턱까지)의 자리 — 외줄꾼이 떨어져 내릴 곳과 되오를 길(움직이는 발판은 폭을 amp 로)
static func _rects(hops: Array, i: int) -> Array:
	var out: Array = []
	for j in range(0, i + 1):
		var p: Dictionary = hops[j]
		out.append({ "id": String(p["id"]), "x": float(p["x"]), "w": float(p["w"]), "y": float(p["y"]), "amp": float(p.get("amp", 0.0)) })
	return out

## 이 폭(x0..x1) 안에 두 턱 말고 다른 발판이 밧줄 선(y0 → y1 의 현)의 높이 띠 — 그 발판이 걸치는 x 에서 밧줄 아래 UNDER, 위 BODY_UP — 에 걸리지 않나; 움직이는 발판은 진폭째(지름길 판이 밧줄 위로 솟으면 걸을 수 없다). 비탈진 밧줄이라 상자 하나가 아니라 선을 본다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, y0: float, y1: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var amp := float(p.get("amp", 0.0))
		var px0 := float(p["x"]) - amp - 10.0; var px1 := float(p["x"]) + float(p["w"]) + amp + 10.0
		if x1 <= px0 or x0 >= px1: continue
		var ra := lerpf(y0, y1, clampf((px0 - x0) / maxf(1.0, x1 - x0), 0.0, 1.0)); var rb := lerpf(y0, y1, clampf((px1 - x0) / maxf(1.0, x1 - x0), 0.0, 1.0))
		var py := float(p["y"])
		if py >= minf(ra, rb) - UNDER and py <= maxf(ra, rb) + BODY_UP: return false
	return true

## 다른 팩의 조각(taken: x, w, y, 있으면 len·b_y·floor·y_top·hp·beam_y·rail_y 까지 — 등롱 장대는 y..y+len, 고드름은 floor..y, 그네는 y..hp)이 밧줄의 상자와 겹치지 않나
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0))
		var ys: Array = [qy, qy + float(q.get("len", 0.0))]
		for key in ["b_y", "floor", "y_top", "hp", "beam_y", "rail_y"]:
			if q.has(key): ys.append(float(q[key]))
		var qy0 := float(ys.min()) - 10.0; var qy1 := float(ys.max()) + 10.0
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 밧줄 높이(px) — 두 고리를 잇는 현에서 sag 만큼 처진다. 폭 밖은 가까운 끝의 높이
func surf(s: Dictionary, x: float) -> float:
	var u := clampf((x - float(s["x0"])) / maxf(1.0, float(s["x1"]) - float(s["x0"])), 0.0, 1.0)
	return lerpf(float(s["y0"]), float(s["y1"]), u) - sag() * 4.0 * u * (1.0 - u)

## 로더의 착지 판정 뒤에 — 이 틱에 밧줄을 지나 떨어지는 몸, 또는 밧줄 높이 catch 안에서 내려오는 몸(턱에서 밧줄로 내디딘 걸음 — 턱 끝을 떠난 첫 틱은 비탈을 따라 밧줄 아래로든 위로든 21 px 까지 벗어나 있다)을 받는다. 떨어진 뒤 shake_s 동안은 아무도 받지 않는다. 돌려준 사전의 "y" 가 그 x 의 밧줄
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	for sv in ropes:
		var s: Dictionary = sv
		if x < float(s["x0"]) or x > float(s["x1"]) or absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		if t - float(s["fell"]) < shake_s(): continue
		var sy := surf(s, x)
		var cross := y >= sy and ny <= sy
		var step := not cross and ny < y and absf(y - sy) <= catch()
		if not (cross or step): continue
		var hit := s.duplicate(); hit["y"] = sy; hit["step"] = step
		return hit
	return {}

## 서 있는 매 틱 — {y, fall, off}: 새로 올라선 몸이면(0.1 s 비어 있었다) 흔들림을 처음부터(hum), 앞 틱의 x 로 걸음의 빠르기를 재고, 진폭을 원하는 값(서기 + 바람 + 걸음)으로 amp_t 의 빠르기로 옮기며 period 로 흔든다;
## fig 가 있으면 자세가 읽을 벗어남(tiptoe_k = off / fall_px)을 적는다. 벗어남이 fall_px 를 넘으면 fall — 밧줄이 twang 하고 떨며(shake_s) 몸은 로더가 떨어뜨린다
func stand(on: Dictionary, x: float, dt: float, fig: Stick3D = null, st: Dictionary = {}) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "y": float(on.get("y", 0.0)), "fall": false, "off": 0.0 }
	var who := _me if st.is_empty() else st
	var id := String(s["id"])
	if t - float(s["stood"]) > 0.1:   # 빈 밧줄에 올라섰다 — 흔들림은 0 에서, 걸음의 기준 x 는 여기서
		s["ph"] = 0.0; s["amp"] = 0.0; who["px"] = x; who["rid"] = id
		_play(s["hum"] as AudioStreamPlayer3D)
		if st.is_empty(): s["stepped_t"] = t   # 플레이어가 올라섰다 — 외줄꾼이 REACT 뒤에 따라 건넌다
	s["stood"] = t
	if st.is_empty(): s["me_t"] = t   # 플레이어가 서 있는 동안 외줄꾼은 박자를 멈춘다
	var spd := absf(x - float(who["px"])) / maxf(dt, 0.0001) if String(who.get("rid", "")) == id else 0.0
	who["px"] = x; who["rid"] = id
	s["ph"] = fposmod(float(s["ph"]) + dt * TAU / period(), TAU)
	var want := base_amp() + wind_amp() * minf(1.0, absf(float(s["wind"])) / WIND_REF) + speed_amp() * clampf((spd - C.WALK * 0.5) / (C.WALK * 0.5), 0.0, 1.0)
	s["amp"] = move_toward(float(s["amp"]), want, dt * speed_amp() / amp_t())
	var off := float(s["amp"]) * sin(float(s["ph"]))
	var sy := surf(s, x)
	if absf(off) > fall_px():
		s["fell"] = t; s["stood"] = -9.0; s["fall_amp"] = float(s["amp"]); s["amp"] = 0.0; who["rid"] = ""   # fall_amp 는 점검이 읽는다
		_play(s["twang"] as AudioStreamPlayer3D)
		if fig: fig.remove_meta("tiptoe_k")
		return { "y": sy, "fall": true, "off": off }
	if fig: fig.set_meta("tiptoe_k", clampf(off / fall_px(), -1.0, 1.0))
	return { "y": sy, "fall": false, "off": off }

func _find(id: String) -> Dictionary:
	for sv in ropes:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 떨어진 뒤의 떨림을 그림에 — 밧줄 노드가 위아래로 잘게 떨고 별이 흔들린다(shake_s 에 걸쳐 잦아든다); 빈 밧줄은 지은 모양 그대로
func _process(delta: float) -> void:
	t += delta
	ropes = ropes.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_bridge 와 같은 식)
	for sv in ropes:
		var s: Dictionary = sv
		if s.has("walker"): (s["walker"] as ClimbRopewalker).step(delta)   # 외줄꾼의 틱
		var k := (t - float(s["fell"])) / shake_s()
		var node: Node3D = s["node"]
		if k >= 1.0:
			if node.position.y != float(s["base_y"]): node.position.y = float(s["base_y"]); _swing(s, 0.0)
			continue
		var shiver := sin((t - float(s["fell"])) * SHAKE_HZ) * (1.0 - k)
		node.position.y = float(s["base_y"]) + 2.0 * C.K * shiver
		_swing(s, 0.5 * shiver)

func _swing(s: Dictionary, a: float) -> void:
	for nv in (s["stars"] as Array):
		(nv as Node3D).rotation.x = a

## 밧줄을 짓는다 — root 는 그 층의 노드. 노드 원점은 왼 끝(x0, y0, z); 밧줄 토막은 처짐을 따라, 고리 둘은 턱 끝 안쪽에 납작하게, 별 셋은 실에 달려 밑에
func build(root: Node3D, planned: Array, wind: float = 0.0) -> void:
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var node := Node3D.new(); node.position = C.to3(float(s["x0"]), float(s["y0"]), float(s["z"]) * C.K); root.add_child(node)
		var rope := _mat(Color("c9b48a")); var iron := _mat(Color("3a3640")); var tin := _mat(Color("f2c84b"), true); var band := _mat(Color("ad7096"))
		var w := float(s["w"]); var segs := maxi(4, int(w / 25.0)); var seg_px := w / float(segs)
		var pieces: Array = []
		for i in segs:   # 밧줄 토막 — 처짐을 따라 놓고 기울인다
			var xm := (float(i) + 0.5) * seg_px
			var y := surf_m(s, xm); var slope := atan2(surf_m(s, xm + 1.0) - surf_m(s, xm - 1.0), 2.0 * C.K)
			var seg := _box(node, Vector3(seg_px * C.K + 0.01, 0.02, 0.02), rope); seg.position = Vector3(xm * C.K, y + 0.01, 0.0); seg.rotation.z = slope
			pieces.append(seg)
		for ev in [[-ring_in(), 0.0], [w + ring_in(), (float(s["y1"]) - float(s["y0"]))]]:   # 고리 둘 — 턱 끝 안쪽, 밧줄 꼬리가 턱 끝까지
			var e: Array = ev
			var ring := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = float(kind.get("ring_r", 3.0)) * C.K; cm.bottom_radius = cm.top_radius; cm.height = 0.02; cm.radial_segments = 8; ring.mesh = cm
			ring.material_override = iron; ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; ring.position = Vector3(float(e[0]) * C.K, float(e[1]) * C.K + 0.01, 0.0); node.add_child(ring)
			_box(node, Vector3(ring_in() * C.K, 0.02, 0.02), rope).position = Vector3((float(e[0]) + (ring_in() if float(e[0]) < 0.0 else -ring_in()) / 2.0) * C.K, float(e[1]) * C.K + 0.01, 0.0)
		var stars: Array = []
		var count := maxi(0, int(kind.get("stars", 3))); var drop := float(kind.get("star_drop", 10.0)) * C.K
		for i in count:   # 양철 별 — 밧줄 밑 실에, 마름모로 세운 작은 판(별밤의 강조색, 빛을 안 받는다)
			var u := (float(i) + 1.0) / (float(count) + 1.0); var xm := u * w
			var pin := Node3D.new(); pin.position = Vector3(xm * C.K, surf_m(s, xm), 0.0); node.add_child(pin)
			_box(pin, Vector3(0.008, drop, 0.008), rope).position = Vector3(0, -drop / 2.0, 0)
			var star := _box(pin, Vector3(0.07, 0.07, 0.01), tin); star.position = Vector3(0, -drop - 0.04, 0); star.rotation.z = PI / 4.0
			stars.append(pin)
		_box(node, Vector3(0.03, 0.03, 0.03), band).position = Vector3(5.0 * C.K, surf_m(s, 5.0) + 0.01, 0.0)   # 왼 끝의 매듭 띠 — 강조색은 이 하나
		s["hum"] = _snd(node, float(kind.get("hum_hz", 95)), 0.25, -14.0); s["twang"] = _snd(node, float(kind.get("twang_hz", 520)), 0.12, -10.0)
		s["node"] = node; s["base_y"] = node.position.y; s["segs"] = pieces; s["stars"] = stars; s["wind"] = wind
		s["stood"] = -9.0; s["fell"] = -99.0; s["ph"] = 0.0; s["amp"] = 0.0; s["stepped_t"] = -99.0; s["me_t"] = -99.0
		ropes.append(s)
		s["walker"] = ClimbRopewalker.new(self, s, node)   # 주민 반쪽 — 아래 고리 옆에 선 외줄꾼

## 노드 기준 높이(m) — xm 은 노드 원점에서 px
func surf_m(s: Dictionary, xm: float) -> float:
	return (surf(s, float(s["x0"]) + xm) - float(s["y0"])) * C.K

func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

func _snd(parent: Node3D, hz: float, secs: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — 짧은 기음이 잦아든다: hum(0.25초, 낮게 — 밧줄이 발밑에서 팽팽해진다)·twang(0.12초, 높게 — 밧줄이 몸을 놓친다). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var n := int(rate * secs)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var k := float(i) / n
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.3) * 0.2) * exp(-k * 8.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
