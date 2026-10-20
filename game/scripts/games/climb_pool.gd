class_name ClimbPool
extends Node3D
## Climb 콘텐츠 팩 '구름 웅덩이'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 구름바다(Cloud sea) 층의 잇단 두 발판 a(아래, 가만한 것)·b(위) 사이 틈(min_gap..max_gap, 높이차 max_dy 안)을 채운 구름 웅덩이 — 수면은 a 윗면 lip 아래, 두께 depth, 수면 위를 솜 puffs 개가 a 쪽으로 flow 로 흘러 돌고, a 끝에 구명 고리(강조색).
## 틈으로 떨어지는 몸이 수면을 지나면 받는다(catch): dunk_s 동안 dunk 까지 들어갔다 ride 로 떠올라(물보라) 등을 대고 뜬다(afloat, stick3d_afloat.gd) — bob_s 마다 bob_a 로 까딱이며 흐름에 a 쪽으로 실려 간다; ← → 는 paddle × WALK 로 젓고(흐름을 거슬러 머물 수도), SPACE 는 아무것도 아니다(밀 것이 없다).
## a 의 끝에 닿으면 out_s 동안 턱을 짚고 기어올라 a 에 선다(stand 로 a 를 돌려준다) — 놓친 점프가 뛴 발판으로 돌아온다, 높이 대신 시간을 치르고. ↓ 는 sink_s 동안 가라앉아 바닥(depth) 밑으로 떨어져 나간다. 막 떠난 웅덩이는 grace_s 동안 안 받는다.
## 받은 것을 탑의 하루(day_s)에 한 번 센다; 쉼터 판이 note(n) 으로 읽는다: 'Cloud pools, floors 25–29: 2 of 3 floated in today, 7 dips today.'
## 밀지도, 거절하지도, 값도 없다 — 두 발판의 맨 착지와 수면 위를 지나는 맨 점프는 그대로(100%); 웅덩이는 층을 지나쳐 떨어질 몸과 a 의 틈 쪽 끝에서 걸어 내려선 몸(이제 떨어지는 대신 뜬다)에게만 있다.
## 해먹(받아서 던져 올린다)·뗏목(발밑이 가라앉는다)·덩굴(느려지고 받힌다)과 다르다: 이건 탑에서 몸이 등을 대고 뜨는 첫 것 — 받은 몸을 제 발판으로 도로 데려다 준다.
## 로더가 할 일(climb.gd, 운영자 세션): `var po := ClimbPool.new(); add_child(po); signs.notes.append(po.note)`; 층을 지을 때 `var tk := cr.plan(n, plats) + mu.plan(n, plats); var pp := cp.plan(n, plats, tk); var bp := ba.plan(n, plats, tk + pp); var lp := ln.plan(n, plats, tk + pp + bp); var jp := lj.plan(n, plats, tk + pp + bp + lp); var gp := cg.plan(n, plats, wind_of(n), tk + pp + bp + lp + jp); po.build(root, po.plan(n, plats, tk + pp + bp + lp + jp + gp + cb.plan(n, plats) + gh.plan(n, plats)))` (뗏목·버섯·널·열기구·렌즈·모래밭·그린·다리·유령 판의 계획을 taken 으로 — 한 틈을 둘이 안 나눈다); 매 틱 `po.sync(_t)`;
## 공중에서 로더의 착지 판정이 비었고 vy < 0 이면: `var c := po.catch(x, y, ny, z, vy); if not c.is_empty(): clinging = c; on = {}; vx = 0.0; vy = 0.0; charge = 0.0; apex = y` (해먹의 clinging 과 같은 사전 — kind "pool");
## 뜬 매 틱(`_hold` 와 같은 자리, 맨 앞): `var r := po.swim(clinging, dir, dirz > 0.0, dt, fig); x = r["x"]; y = r["y"]; apex = y; fig.pose_request = "afloat"; if r["lost"]: clinging = {}; fig.pose_request = ""; if not r["stand"].is_empty(): on = r["stand"]; y = on["y"]; vy = 0.0` (stand 가 비면 떨어진다 — vy 0 에서).
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_pool.gd

const PACK := "res://data/climb/pool.json"
const C = preload("res://scripts/games/climb.gd")
const BODY := 50.0        # 수면 위로 비워 두는 높이(px) — 뜬 몸
const TAKEN_HALF := 50.0  # 폭이 없는 taken 조각(버섯)의 반폭(px)
const TAKEN_UP := 30.0    # taken 조각 위로 비워 두는 높이(px) — 버섯 갓·널의 두께쯤. 해먹의 100 으로는 구름바다의 여섯 팩이 모든 틈을 막았다(run 186 의 첫 점검): 웅덩이는 수면 아래를 채우니 조각 제 몸만 비켜 가면 된다
const HELD_T := 0.25      # 이만큼 swim 이 안 오면 뜬 몸이 사라진 것 — 웅덩이를 비운다
const OUT_IN := 2.0       # 기어올라 선 자리: a 의 끝에서 HW + 이만큼 안쪽(px)
const B_NOT := ["move"]   # 위 발판 b 가 이 종류면 틈이 없다 — 틈의 끝이 움직인다(아래 발판 a 는 조각의 on: 기어올라 서는 곳이라 가만히 있어야 한다)
const SLACK := 0.001      # 토막의 끝 판정 여유(s) — 로더의 시계가 0.4 에 딱 서지 않는다(부동소수점), 1 ms 는 한 틱보다 짧다

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.pool
var pools: Array = []           # 지은 웅덩이 {id, kind "pool", n, x, w, y(수면), z, d, x0, x1, mid, surf, dir(a 에서 b 쪽 ±1), a_id, b_id, a(발판 사전), a_edge, node, tufts, splash, slosh, rider, sw, go, go2, cx, x_at, y_at, step_t, held, dips, day, day_dips, dip_day}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("pool", {})

func sync(now: float) -> void:
	t = now

func lip() -> float: return maxf(0.0, float(kind.get("lip", 8.0)))
func depth() -> float: return maxf(8.0, float(kind.get("depth", 48.0)))
func d() -> float: return maxf(4.0, float(kind.get("d", 40.0)))
func dunk() -> float: return clampf(float(kind.get("dunk", 18.0)), ride(), depth())
func dunk_s() -> float: return maxf(0.05, float(kind.get("dunk_s", 0.4)))
func ride() -> float: return maxf(0.0, float(kind.get("ride", 4.0)))
func bob_a() -> float: return maxf(0.0, float(kind.get("bob_a", 3.0)))
func bob_s() -> float: return maxf(0.2, float(kind.get("bob_s", 2.4)))
func flow() -> float: return maxf(0.0, float(kind.get("flow", 30.0)))
func paddle() -> float: return clampf(float(kind.get("paddle", 0.35)), 0.0, 1.0)
func out_s() -> float: return maxf(0.05, float(kind.get("out_s", 0.6)))
func sink_s() -> float: return maxf(0.05, float(kind.get("sink_s", 0.3)))
func grace_s() -> float: return maxf(0.0, float(kind.get("grace_s", 0.4)))
func day_s() -> float: return maxf(1.0, float(kind.get("day_s", 600.0)))

## 탑의 오늘 — 로더의 시계를 day_s 로 나눈 몫
func day() -> int: return floori(t / day_s())

## 층 n(테마 층, 조각의 only 층만)의 잇단 두 발판(아래 a 는 조각의 on, 위 b 는 움직이지만 않으면) 사이 틈(min_gap..max_gap, 높이차 max_dy 안) 중 웅덩이 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 것들 중 가장 넓은 하나(같으면 낮은 쪽). 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var min_gap := float(kind.get("min_gap", 60.0)); var max_gap := float(kind.get("max_gap", 200.0)); var max_dy := float(kind.get("max_dy", 140.0))
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds) or String(b["kind"]) in B_NOT: continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < 0.0 or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			var right := bx0 >= ax1   # b 가 오른쪽에
			var gap := bx0 - ax1 if right else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var x0 := ax1 if right else bx1; var x1 := bx0 if right else ax0
			var surf := float(a["y"]) - lip()
			if not _clear(plats, a, b, x0, x1, surf - depth() - 4.0, surf + BODY): continue
			if not _free(taken, x0, x1, surf - depth() - 4.0, surf + BODY): continue
			spans.append({ "gap": gap, "x0": x0, "x1": x1, "surf": surf, "dir": 1.0 if right else -1.0, "a_id": String(a["id"]), "b_id": String(b["id"]), "a": _plain(a) })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["surf"]) < float(q["surf"]))
		for i in range(0, mini(int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.P%d" % [n, i]; s["kind"] = "pool"; s["n"] = n
			s["x"] = float(g["x0"]); s["w"] = float(g["x1"]) - float(g["x0"]); s["y"] = float(g["surf"]); s["z"] = C.PLAYER_Z; s["d"] = d()
			s["mid"] = (float(g["x0"]) + float(g["x1"])) / 2.0; s["a_edge"] = float(g["x0"]) if float(g["dir"]) > 0.0 else float(g["x1"])
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 발판 사전에서 노드 없이 — stand 로 로더에 돌려주는 것(로더의 떠남 판정은 x·w·y·z·d 만 읽는다)
static func _plain(p: Dictionary) -> Dictionary:
	var q := {}
	for k: String in ["id", "x", "y", "w", "kind", "z", "d", "amp", "freq", "phase"]:
		if p.has(k): q[k] = p[k]
	return q

## 웅덩이 상자(틈의 x, 바닥 밑..수면 위의 몸)에 그 두 발판 말고 다른 발판이 걸리지 않나 — 지름길 판이 틈에 있으면 웅덩이가 걸린다
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

## 다른 팩의 조각(taken)이 웅덩이 상자에 닿지 않나 — 폭 있는 것(x·w·y, 있으면 y0·y1·y_top·len)과 폭 없는 것(버섯: x·y 만, 반폭 TAKEN_HALF); 조각 위 TAKEN_UP 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qh := float(q["w"]) / 2.0 + 10.0 if q.has("w") else TAKEN_HALF
		var qc := float(q.get("x", 0.0)) + (float(q["w"]) / 2.0 if q.has("w") else 0.0)
		var qy := float(q.get("y", 0.0))
		var qy0 := minf(qy, minf(float(q.get("y0", qy)), float(q.get("y1", qy)))) - 10.0
		var qy1 := maxf(qy, maxf(float(q.get("y0", qy)), float(q.get("y1", qy)))) + TAKEN_UP
		if q.has("len"): qy1 = maxf(qy1, qy + float(q["len"]) + 10.0)
		if q.has("y_top"): qy1 = maxf(qy1, float(q["y_top"]) + 10.0)
		if x1 > qc - qh and x0 < qc + qh and yhi > qy0 and ylo < qy1: return false
	return true

## 공중에서 떨어지는 몸(vy < 0) — 로더의 착지 판정이 빈 다음: 틈 안(몸 반폭을 뺀 자리)에서 수면을 지나면 받는다 — 돌려주는 사전의 x·y 가 몸의 자리(받힌 x, 수면). 막 떠난 웅덩이(grace_s)·누가 떠 있는 것·앞뒤 밖은 빈 사전. 받으면 오늘을 센다(플레이어만 여기 온다)
func catch(x: float, y: float, ny: float, z: float, vy: float) -> Dictionary:
	if vy >= 0.0: return {}
	for sv in pools:
		var s: Dictionary = sv
		if bool(s["rider"]): continue
		var surf := float(s["surf"])
		if y < surf or ny > surf: continue
		if absf(z - float(s["z"])) >= d() / 2.0 + C.HZ: continue
		if x < float(s["x0"]) + C.HW or x > float(s["x1"]) - C.HW: continue
		if t - float(s["held"]) < grace_s(): continue
		s["rider"] = true; s["sw"] = "in"; s["go"] = t; s["go2"] = t; s["cx"] = x; s["x_at"] = x; s["y_at"] = surf; s["step_t"] = t
		s["dips"] = int(s["dips"]) + 1
		if int(s["dip_day"]) != day(): s["dip_day"] = day(); s["day_dips"] = 0
		s["day_dips"] = int(s["day_dips"]) + 1; s["day"] = day()
		_play(s["splash"] as AudioStreamPlayer3D)
		var hit := { "kind": "pool", "id": String(s["id"]), "x": x, "y": surf, "w": float(s["w"]), "z": float(s["z"]), "d": d() }
		return hit
	return {}

## 뜬 매 틱 — 몸의 자리 {x, y, stand, lost}: 빠짐(in: dunk 까지 들어갔다 ride 로), 뜸(float: 흐름 + 젓기, bob; a 의 끝에 닿으면 out, ↓ 면 sink), 기어오름(out: a 위로 — 끝나면 stand = a, lost), 가라앉음(sink: 바닥 밑으로 — 끝나면 stand {}, lost). fig 가 있으면 자세의 시계(afl_c·afl_v·afl_o·afl_s)를 적는다
func swim(on: Dictionary, dir: float, down: bool, dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty() or not bool(s["rider"]): return { "x": float(on.get("x", 0.0)), "y": float(on.get("y", 0.0)), "stand": {}, "lost": true }
	s["step_t"] = t
	var surf := float(s["surf"]); var k := t - float(s["go"]); var u := t - float(s["go2"])
	var x := float(s["x_at"]); var y := float(s["y_at"])
	match String(s["sw"]):
		"in":
			var kk := clampf(k / dunk_s(), 0.0, 1.0)
			y = surf - ride() - (dunk() - ride()) * sin(PI * kk)
			_metas(fig, kk, 0.0, 0.0, 0.0)
			if k >= dunk_s() - SLACK: s["sw"] = "float"; s["go2"] = t
		"float":
			x = clampf(x + (-float(s["dir"]) * flow() + dir * paddle() * C.WALK) * dt, float(s["x0"]) + C.HW, float(s["x1"]) - C.HW)
			y = surf - ride() + bob_a() * sin(TAU * u / bob_s())
			_metas(fig, 1.0, absf(dir), 0.0, 0.0)
			if down: s["sw"] = "sink"; s["go2"] = t; s["cx"] = x
			elif (x - float(s["a_edge"])) * float(s["dir"]) <= C.HW + 1.0: s["sw"] = "out"; s["go2"] = t; s["cx"] = x
		"out":
			var kk := clampf(u / out_s(), 0.0, 1.0)
			var a: Dictionary = s["a"]
			x = lerpf(float(s["cx"]), float(s["a_edge"]) - float(s["dir"]) * (C.HW + OUT_IN), kk)
			y = lerpf(surf - ride(), float(a["y"]), smoothstep(0.0, 1.0, kk))
			_metas(fig, 1.0, 0.0, kk, 0.0)
			if u >= out_s() - SLACK: _leave(s); leave(fig); _play(s["slosh"] as AudioStreamPlayer3D); return { "x": x, "y": float(a["y"]), "stand": a.duplicate(), "lost": true }
		"sink":
			var kk := clampf(u / sink_s(), 0.0, 1.0)
			y = surf - ride() - (depth() - ride()) * kk
			_metas(fig, 1.0, 0.0, 0.0, kk)
			if u >= sink_s() - SLACK: _leave(s); leave(fig); return { "x": x, "y": surf - depth(), "stand": {}, "lost": true }
	s["x_at"] = x; s["y_at"] = y
	return { "x": x, "y": y, "stand": {}, "lost": false }

## 자세의 시계 — afl_c 빠진 몫, afl_v 젓는 몫, afl_o 기어오른 몫, afl_s 가라앉은 몫
static func _metas(fig: Stick3D, c: float, v: float, o: float, sk: float) -> void:
	if fig == null or not is_instance_valid(fig): return
	fig.set_meta("afl_c", c); fig.set_meta("afl_v", v); fig.set_meta("afl_o", o); fig.set_meta("afl_s", sk)

## 웅덩이에서 떠난 몸 — 자세의 시계를 거둔다
static func leave(fig: Stick3D) -> void:
	if fig == null or not is_instance_valid(fig): return
	for key: String in ["afl_c", "afl_v", "afl_o", "afl_s"]:
		if fig.has_meta(key): fig.remove_meta(key)

func _leave(s: Dictionary) -> void:
	s["rider"] = false; s["sw"] = ""; s["held"] = t

func _find(id: String) -> Dictionary:
	for sv in pools:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

## n0..n1 층의 웅덩이에서 오늘 받은 수·전체·오늘의 빠진 횟수 — {floated, total, dips}
func top_today(n0: int, n1: int) -> Dictionary:
	var floated := 0; var total := 0; var dips := 0
	for sv in pools:
		var s: Dictionary = sv
		if int(s["n"]) < n0 or int(s["n"]) > n1: continue
		total += 1
		if int(s["day"]) == day(): floated += 1
		if int(s["dip_day"]) == day(): dips += int(s["day_dips"])
	return { "floated": floated, "total": total, "dips": dips }

## 쉼터 판(n 층)에 붙는 줄 — 위 다섯 층(n..n+4)의 웅덩이, 없으면 아래 다섯 층(n−5..n−1), 그것도 없으면 빈 줄. climb_signs.notes 에 넣는다
func note(n: int) -> String:
	for span: Array in [[n, n + 4], [n - 5, n - 1]]:
		var v := top_today(int(span[0]), int(span[1]))
		if int(v["total"]) > 0:
			return "Cloud pools, floors %d–%d: %d of %d floated in today, %d %s today." % [int(span[0]), int(span[1]), int(v["floated"]), int(v["total"]), int(v["dips"]), "dip" if int(v["dips"]) == 1 else "dips"]
	return ""

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 솜이 a 쪽으로 흘러 돈다; 뜬 몸이 HELD_T 동안 swim 을 안 주면(탑을 나갔다) 웅덩이를 비운다
func _process(delta: float) -> void:
	t += delta
	pools = pools.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_hammock 과 같은 식)
	for sv in pools:
		var s: Dictionary = sv
		if bool(s["rider"]) and t - float(s["step_t"]) > HELD_T: _leave(s)
		var half := float(s["w"]) / 2.0 * C.K; var step := -float(s["dir"]) * flow() * C.K * delta
		for tv in (s["tufts"] as Array):
			var tuft := tv as Node3D
			tuft.position.x += step
			if tuft.position.x < -half: tuft.position.x += 2.0 * half
			elif tuft.position.x > half: tuft.position.x -= 2.0 * half

## 웅덩이를 짓는다 — root 는 그 층의 노드. 노드 원점은 (틈 가운데, 수면, PLAYER_Z); 구름 판(두께 depth), 수면의 솜 puffs 개(흐른다), 밑의 그늘 솜 둘, a 끝의 구명 고리(기둥 + 고리 — 강조색은 이 한 조각), 소리 둘
func build(root: Node3D, planned: Array) -> void:
	var puffs := maxi(2, int(kind.get("puffs", 6)))
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var w := float(s["w"]) * C.K; var dep := d() * C.K; var th := depth() * C.K
		var node := Node3D.new(); node.position = C.to3(float(s["mid"]), float(s["surf"]), float(s["z"]) * C.K); root.add_child(node)
		var paper := _mat(Color("f7f4ef")); var shade := _mat(Color("c9dde6")); var pale := _mat(Color("e4edf2"))
		_box(node, Vector3(w, th, dep), pale).position = Vector3(0.0, -th / 2.0, 0.0)   # 구름 판 — 틈을 채운다
		var tufts: Array = []
		for i in puffs:
			var rr := (9.0 + 2.0 * float((i * 7) % 3)) * C.K
			var px := (float(i) + 0.5) / float(puffs) * w - w / 2.0
			var tuft := _ball(node, rr, rr * 1.2, paper); tuft.position = Vector3(px, -rr * 0.45 + 0.01 * float((i * 5) % 3), (0.04 * float((i * 3) % 3) - 0.04))
			tufts.append(tuft)
		for i in 2: _ball(node, 0.3, 0.3, shade).position = Vector3((float(i) - 0.5) * w * 0.5, -th + 0.1, dep * 0.3)   # 밑의 그늘 솜
		var dir := float(s["dir"]); var ex := (float(s["a_edge"]) - float(s["mid"])) * C.K - dir * 0.08
		_box(node, Vector3(0.04, (lip() + 22.0) * C.K, 0.04), _mat(Color("6b4a35"))).position = Vector3(ex, (lip() + 22.0) * C.K / 2.0, -0.2)   # 고리 기둥 — a 의 끝
		var buoy := _mat(Color("ad7096"))
		_box(node, Vector3(0.22, 0.05, 0.04), buoy).position = Vector3(ex, (lip() + 18.0) * C.K, -0.17)   # 구명 고리(가로·세로 띠)
		_box(node, Vector3(0.05, 0.22, 0.04), buoy).position = Vector3(ex, (lip() + 18.0) * C.K, -0.17)
		s["node"] = node; s["tufts"] = tufts
		s["splash"] = _snd(node, float(kind.get("splash_hz", 260)), 0.3, 9.0, -14.0); s["slosh"] = _snd(node, float(kind.get("slosh_hz", 160)), 0.25, 8.0, -16.0)
		s["rider"] = false; s["sw"] = ""; s["go"] = -99.0; s["go2"] = -99.0; s["cx"] = 0.0; s["x_at"] = 0.0; s["y_at"] = 0.0; s["step_t"] = -99.0; s["held"] = -99.0
		s["dips"] = 0; s["day"] = -1; s["day_dips"] = 0; s["dip_day"] = -1
		pools.append(s)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 납작한 구 — 솜 한 덩이(가로 지름 2r, 높이 h)
func _ball(parent: Node3D, r: float, h: float, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = h; sm.radial_segments = 10; sm.rings = 6; mi.mesh = sm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi); return mi

func _snd(parent: Node3D, hz: float, secs: float, decay: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs, decay); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — 짧은 기음이 잦아든다: splash(0.3초 — 빠지는 물보라)·slosh(0.25초 — 턱을 넘는 몸). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float, decay: float) -> AudioStreamWAV:
	var rate := 22050; var n := int(rate * secs)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var k := float(i) / n
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.3) * 0.2 + sin(ph * 5.7) * 0.08) * exp(-k * decay)
		data.encode_s16(i * 2, int(v * 22000.0))
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = rate; wav.stereo = false; wav.data = data
	return wav
