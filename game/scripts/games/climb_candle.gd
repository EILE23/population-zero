class_name ClimbCandle
extends Node3D
## Climb 콘텐츠 팩 '촛대 계단'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 별밤(Starlit) 층의 잇단 두 still 발판 사이 틈(min_gap..max_gap, 위 발판이 max_dy 안) — 아래 발판의 틈 쪽 가장자리에서 절벽의 놋쇠 받침이 나오고, 그 위에 굵은 밀랍 초 셋이 나란히 선다(각 tread 폭). 초의 꼭대기는 하나씩 min_h..max_h 만큼 높아져(셋의 오름을 더하면 위 발판 높이 − top_short; base−4, base+4, base 로 고르지 않게) 초마다 톡 뛰는 한 단, 마지막 초에서 위 발판도 톡 뛰는 한 단.
## 선 몸이 밀랍을 무르게 한다: 발밑의 초가 sag_v px/s 로 가라앉고(max_sag 까지; 불꽃은 발에 눌려 꺼진다), 몸이 떠난 뒤 hold_s 동안 자국을 지키다 set_s 에 걸쳐 밀랍이 다시 서고 심지에 불이 붙는다 — 같은 계단을 1분 안에 세 번째 오르면 낮아져 있고 위 발판으로 가는 마지막 점프가 그만큼 높다.
## 더 높은 옆 초로 걸어 들어가면 밀랍 벽에 막혀 서고, 초의 가장자리를 넘으면 아래 초나 발판으로 떨어진다. 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 틈을 건너는 맨 점프는 그대로(초는 그 호 밑의 바닥일 뿐), 초는 발판을 덮지 않는다. 몸무게로 닳는 첫 계단.
## 서 있는 자세는 sink(stick3d_sink.gd — 운영자 보드의 '무른 바닥·눈밭' 가족, balance 의 다음: 무릎이 자국 깊이만큼 풀리고 밀랍이 꺼지는 동안 팔이 올라가며 몸통이 박자로 몸을 다잡고 자유 발이 작은 회복 뜀을 친다).
## balance(비탈이 되는 발밑 — 앞뒤로 기운다)·sway(옆으로 흔들리는 발밑)·teeter(디딤돌)와 다르다: 이건 발밑이 제 무게로 내려앉는 몸 — 수직으로 가라앉고 무릎으로 받는다.
## 로더가 할 일(climb.gd, 운영자 세션): `var cc := ClimbCandle.new(); add_child(cc)`; 층을 지을 때 `cc.build(root, cc.plan(n, plats, cn.plan(n, plats, ci.plan(n, plats)) + ci.plan(n, plats)))` (등롱·고드름의 계획을 taken 으로 — 그 틈은 비켜 간다); 매 틱 `cc.sync(_t)`;
## 로더 자신의 착지 판정이 비었고 vy <= 0 이면 `landed = cc.land(x, y, ny, z)` (kind "candle" — 돌려준 사전의 "y" 가 그 초의 꼭대기, "i" 가 초 번호; "step" 이 참이면 내려선 걸음, "ramp" 가 참이면 가라앉은 초로 걸어 올라선 걸음이라 vx 를 0 으로 안 해도 된다);
## `on["kind"] == "candle"` 인 매 틱, 'move' 발판 자리에서: `var r := cc.stand(on, x, dt, fig); x = r["x"]; y = r["y"]; if r["off"]: on = {}; apex = y; else: fig.pose_request = "sink"`, 초를 떠나면 자세를 비운다.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_candle.gd

const PACK := "res://data/climb/candle.json"
const C = preload("res://scripts/games/climb.gd")
const TAKEN_UP := 220.0    # taken 조각(등롱·고드름) 위로 비워 두는 높이(px) — 제 꼭대기(rail_y·beam_y·y_top)나 len 이 더 높으면 그것
const BODY_UP := 50.0      # 꼭대기 초에 선 몸의 키(px) — 상자 위쪽 여유
const STOOD_T := 0.1       # 이만큼 stand 가 안 오면 몸이 떠난 것 — 자국의 시계가 돈다
const JITTER := 4.0        # 세 오름의 고르지 않음(px): base−4, base+4, base

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.candle
var stairs: Array = []          # 지은 계단 {id, kind "candle", x, y, w, z, d, y_top, dir, gap, a_edge, b_edge, a_y, b_y, a_id, b_id, hs, node, cands, waxes, rims, flames, glows, squish, hiss, pop, dents, rests, stood, lit, cur}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("candle", {})

func sync(now: float) -> void:
	t = now
	for sv in stairs:
		_settle(sv)

func steps() -> int:
	return maxi(1, int(kind.get("steps", 3)))

func tread() -> float:
	return maxf(8.0, float(kind.get("tread", 28.0)))

func min_h() -> float:
	return maxf(max_sag() + 1.0, float(kind.get("min_h", 24.0)))   # 자국이 가장 깊어도 초의 차례는 지킨다

func max_h() -> float:
	return maxf(min_h(), float(kind.get("max_h", 40.0)))

func top_short() -> float:
	return maxf(0.0, float(kind.get("top_short", 20.0)))

func sag_v() -> float:
	return maxf(0.0, float(kind.get("sag_v", 6.0)))

func max_sag() -> float:
	return maxf(0.0, float(kind.get("max_sag", 16.0)))

func hold_s() -> float:
	return maxf(0.0, float(kind.get("hold_s", 20.0)))

func set_s() -> float:
	return maxf(0.05, float(kind.get("set_s", 3.0)))

func catch_px() -> float:
	return maxf(0.0, float(kind.get("catch", 16.0)))

func deck_d() -> float:
	return maxf(2.0, float(kind.get("deck_d", 28.0)))

## 초 i 의 지금 꼭대기(px) — 받침 위 오름의 합에서 자국만큼 내려
func top_of(s: Dictionary, i: int) -> float:
	return float(s["a_y"]) + float((s["hs"] as Array)[i]) - float((s["dents"] as Array)[i])

## x 밑의 초 번호(아래 발판 쪽이 0) — 계단 밖이면 −1
func index_at(s: Dictionary, x: float) -> int:
	var u := float(s["dir"]) * (x - float(s["a_edge"]))
	if u < 0.0 or u >= tread() * float(steps()): return -1
	return mini(steps() - 1, int(floor(u / tread())))

## 세 오름(px, 정수) — 더하면 dy − top_short(min_h×3..max_h×3 안), base−4·base+4·base 로 고르지 않게
func rises(dy: float) -> Array:
	var n := steps()
	var total := clampf(dy - top_short(), min_h() * float(n), max_h() * float(n))
	var base := total / float(n)
	var out: Array = []
	for i in n:
		var j: float = -JITTER if i % 3 == 0 else (JITTER if i % 3 == 1 else 0.0)
		out.append(roundf(clampf(base + j, min_h(), max_h())))
	return out

## 자국의 시계 — 몸이 떠난 초는 hold_s 를 지키다 set_s 에 걸쳐 돌아오고, 다 돌아오면 심지에 불(pop)
func _settle(s: Dictionary) -> void:
	var dents: Array = s["dents"]; var rests: Array = s["rests"]; var stood: Array = s["stood"]; var lit: Array = s["lit"]
	var rate := max_sag() / set_s()
	for i in steps():
		if t - float(stood[i]) <= STOOD_T: continue   # 몸이 서 있다 — stand 가 가라앉힌다
		var since := t - float(stood[i]) - hold_s()
		dents[i] = maxf(0.0, float(rests[i]) - maxf(0.0, since) * rate)
		if float(dents[i]) <= 0.0 and not bool(lit[i]):
			lit[i] = true
			_play((s["pop"] as Array)[i] as AudioStreamPlayer3D)

## 노드를 지금 자리로 — 밀랍은 자국만큼 낮고 불꽃은 천천히 흔들린다
func _process(delta: float) -> void:
	t += delta
	stairs = stairs.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_planter 와 같은 식)
	for sv in stairs:
		var s: Dictionary = sv
		_settle(s)
		_place(s)

## 층 n(테마 층, 조각의 only 규칙)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 max_dy 안으로 높으며 계단 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := float(kind.get("min_gap", 100.0)); var max_gap := float(kind.get("max_gap", 200.0)); var max_dy := float(kind.get("max_dy", 150.0))
	var width := tread() * float(steps()); var over := float(kind.get("wick", 6.0)) + float(kind.get("flame", 10.0)) + BODY_UP
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
			var a_edge := ax1 if dir > 0.0 else ax0; var b_edge := bx0 if dir > 0.0 else bx1
			var hs: Array = []; var acc := 0.0
			for r in rises(dy):
				acc += float(r); hs.append(acc)
			var y_top := float(a["y"]) + acc
			var x0 := minf(a_edge, a_edge + dir * width) - 4.0; var x1 := maxf(a_edge, a_edge + dir * width) + 4.0
			var ylo := float(a["y"]) + 1.0; var yhi := y_top + over
			if not _clear(plats, a, b, x0, x1, ylo, yhi): continue
			if not _free(taken, x0, x1, ylo, yhi): continue
			found.append({ "gap": gap, "dir": dir, "a_edge": a_edge, "b_edge": b_edge, "hs": hs, "y_top": y_top,
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.C%d" % [n, i]; s["kind"] = "candle"; s["x"] = minf(float(g["a_edge"]), float(g["a_edge"]) + float(g["dir"]) * width); s["w"] = width; s["y"] = float(g["a_y"]); s["z"] = C.PLAYER_Z; s["d"] = deck_d()
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 계단 상자(아래 발판 가장자리..초 셋, 아래 윗면..꼭대기 초의 불꽃과 몸)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x·w·y, 있으면 rail_y·beam_y·y_top·floor, 장대면 len)이 계단 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지, 제 꼭대기가 더 높으면 거기 + 60 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := minf(qy, float(q.get("floor", qy))) - 10.0; var qy1 := qy + TAKEN_UP
		for key in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qy1 = maxf(qy1, float(q[key]) + 60.0)
		if q.has("len"): qy1 = maxf(qy1, qy + float(q["len"]) + 10.0)   # 등롱 장대 — 핀에서 꼭대기까지
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 로더의 착지 판정이 빈 뒤(vy <= 0) — 이 틱에 초의 꼭대기를 지나 떨어지는 몸, 꼭대기 위 catch 안에서 내려서는 몸, 또는 꼭대기가 발 위 catch 안에 있는 몸(가라앉은 초로 걸어 올라서는 걸음)을 받는다(squish): {kind "candle", id, x, y(그 초의 꼭대기), w, z, d, i, step, ramp}
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	var catch := catch_px()
	for sv in stairs:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= deck_d() / 2.0 + C.HZ: continue
		var i := index_at(s, x)
		if i < 0: continue
		if ny > y: continue   # 오르는 몸은 받지 않는다
		var sy := top_of(s, i)
		var cross := y >= sy and ny <= sy
		var step := not cross and y > sy and y - sy <= catch
		var ramp := not cross and y < sy and sy - y <= catch
		if not (cross or step or ramp): continue
		s["cur"] = i
		_play(s["squish"] as AudioStreamPlayer3D)
		return { "kind": "candle", "id": String(s["id"]), "x": float(s["x"]), "y": sy, "w": float(s["w"]), "z": float(s["z"]), "d": deck_d(), "i": i, "step": step, "ramp": ramp }
	return {}

## 초 위에 선 매 틱 — {x, y, off, i, dent}: 발밑의 초가 sag_v·dt 가라앉고(max_sag 까지) 불꽃이 꺼진다(hiss); 더 높은 옆 초로 걸으면 밀랍 벽에서 x 가 선다; 낮은 옆 초나 계단 밖으로 걸으면 off(떨어져 아래 것이 받는다). 모르는 계단이면 off
## fig 가 있으면 자세의 메타를 적는다: sink_k 자국 깊이 0..1, sink_v 가라앉는 중이면 1
func stand(on: Dictionary, x: float, dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "x": x, "y": float(on.get("y", 0.0)), "off": true, "i": -1, "dent": 0.0 }
	var cur := int(s["cur"]); var dir := float(s["dir"]); var j := index_at(s, x)
	var y := top_of(s, cur)
	if j < 0 or (j != cur and top_of(s, j) <= y): return { "x": x, "y": y, "off": true, "i": cur, "dent": float((s["dents"] as Array)[cur]) }
	if j != cur: x = float(s["a_edge"]) + dir * (tread() * float(cur + 1) - 0.5)   # 더 높은 옆 초 — 밀랍 벽
	var dents: Array = s["dents"]; var lit: Array = s["lit"]
	dents[cur] = minf(max_sag(), float(dents[cur]) + sag_v() * maxf(0.0, dt))
	(s["rests"] as Array)[cur] = dents[cur]; (s["stood"] as Array)[cur] = t
	if bool(lit[cur]):
		lit[cur] = false
		_play((s["hiss"] as Array)[cur] as AudioStreamPlayer3D)
	var dent := float(dents[cur])
	if fig:
		fig.set_meta("sink_k", clampf(dent / maxf(0.001, max_sag()), 0.0, 1.0))
		fig.set_meta("sink_v", 1.0 if dent < max_sag() else 0.0)
	return { "x": x, "y": top_of(s, cur), "off": false, "i": cur, "dent": dent }

func _find(id: String) -> Dictionary:
	for sv in stairs:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 받침과 초를 짓는다 — root 는 그 층의 노드. 노드 원점은 계단의 왼끝(x, 아래 발판 윗면, PLAYER_Z); 놋쇠 받침(절벽에서)과 받침 팔 둘, 초마다 노드(밀랍 기둥·녹은 테·심지·불꽃·흘러내린 밀랍 둘), squish 하나와 초마다 hiss·pop
func build(root: Node3D, planned: Array) -> void:
	var tr := tread() * C.K; var dd := deck_d() * C.K; var wk := float(kind.get("wick", 6.0)) * C.K; var fl := float(kind.get("flame", 10.0)) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var dir := float(s["dir"]); var n := steps(); var width := tr * float(n)
		var node := Node3D.new(); node.position = C.to3(float(s["x"]), float(s["a_y"]), float(s["z"]) * C.K); root.add_child(node)
		var brass := _mat(Color("c9a24a")); var wax := _mat(Color("f1e8d6")); var mauve := _mat(Color("ad7096")); var ink := _mat(Color("2f2a4e"))
		var arm_len := (C.PLAYER_Z - C.WALL_Z) * C.K + dd / 2.0
		_box(node, Vector3(width + 0.06, 0.04, dd + 0.04), brass).position = Vector3(width / 2.0, -0.02, 0.0)                      # 받침 — 초 셋이 선 선반
		for q: float in [0.2, 0.8]:
			_box(node, Vector3(0.05, 0.05, arm_len), brass).position = Vector3(width * q, -0.065, -arm_len / 2.0 + dd / 2.0)   # 받침 팔 — 절벽에서
		var cands: Array = []; var waxes: Array = []; var rims: Array = []; var flames: Array = []; var glows: Array = []; var hiss: Array = []; var pop: Array = []
		for i in n:
			var k := i if dir > 0.0 else n - 1 - i   # 아래 발판 쪽이 0 — 왼끝에서 잰 자리는 방향에 따라
			var h := float((s["hs"] as Array)[i]) * C.K
			var cand := Node3D.new(); cand.position = Vector3((float(k) + 0.5) * tr, 0.0, 0.0); node.add_child(cand)
			var body := _cyl(cand, tr * 0.46, h, mauve if i == 1 else wax); body.position = Vector3(0.0, h / 2.0, 0.0)   # 밀랍 기둥 — 가운데 것은 자주색
			var top := Node3D.new(); top.position = Vector3(0.0, h, 0.0); cand.add_child(top)
			_cyl(top, tr * 0.5, 0.02, wax).position = Vector3(0.0, -0.01, 0.0)                                         # 녹은 테 — 꼭대기의 밀랍 웅덩이
			_cyl(top, 0.012, wk, ink).position = Vector3(0.0, wk / 2.0, 0.0)                                           # 심지
			var glow := _mat(Color("f7dc8a")); glow.emission_enabled = true; glow.emission = Color("f2c84b"); glow.emission_energy_multiplier = 1.2   # 불꽃 — 별밤의 노란빛
			var flame := _box(top, Vector3(0.07, fl, 0.05), glow); flame.position = Vector3(0.0, wk + fl / 2.0, 0.0); flame.rotation.z = PI / 4.0 * 0.15
			for d: Array in [[0.46, 0.55, 1.0], [-0.44, 0.2, -1.0]]:
				_box(cand, Vector3(0.03, h * float(d[1]), 0.025), wax).position = Vector3(float(d[0]) * tr, h * (1.0 - float(d[1]) / 2.0) - 0.01, float(d[2]) * dd * 0.3)   # 흘러내린 밀랍 — 양쪽이 다르다
			var hs_p := AudioStreamPlayer3D.new(); hs_p.stream = _tick_wav(float(kind.get("hiss_hz", 2400)), 0.12, 6.0); hs_p.volume_db = -16.0; hs_p.unit_size = 6.0; hs_p.max_distance = 30.0; cand.add_child(hs_p)
			var pp := AudioStreamPlayer3D.new(); pp.stream = _tick_wav(float(kind.get("pop_hz", 600)), 0.05, 14.0); pp.volume_db = -12.0; pp.unit_size = 6.0; pp.max_distance = 30.0; cand.add_child(pp)
			cands.append(cand); waxes.append(body); rims.append(top); flames.append(flame); glows.append(glow); hiss.append(hs_p); pop.append(pp)
		var squish := AudioStreamPlayer3D.new(); squish.stream = _tick_wav(float(kind.get("squish_hz", 70)), 0.14, 8.0); squish.volume_db = -10.0; squish.unit_size = 6.0; squish.max_distance = 30.0; node.add_child(squish)
		s["node"] = node; s["cands"] = cands; s["waxes"] = waxes; s["rims"] = rims; s["flames"] = flames; s["glows"] = glows; s["squish"] = squish; s["hiss"] = hiss; s["pop"] = pop
		var dents: Array = []; var rests: Array = []; var stood: Array = []; var lit: Array = []
		for i in n:
			dents.append(0.0); rests.append(0.0); stood.append(-99.0); lit.append(true)
		s["dents"] = dents; s["rests"] = rests; s["stood"] = stood; s["lit"] = lit; s["cur"] = 0; s["phase"] = fposmod(float(s["x"]) * 0.37, TAU)
		stairs.append(s)
		_place(s)

## 밀랍 기둥을 자국만큼 줄이고 테·심지·불꽃을 그 꼭대기로, 불꽃은 켜진 초에서만 흔들린다
func _place(s: Dictionary) -> void:
	var dents: Array = s["dents"]; var lit: Array = s["lit"]; var glow_hz := float(kind.get("glow_hz", 0.9))
	for i in steps():
		var h := float((s["hs"] as Array)[i]); var now := h - float(dents[i])
		var body: Node3D = (s["waxes"] as Array)[i]; var top: Node3D = (s["rims"] as Array)[i]; var flame: Node3D = (s["flames"] as Array)[i]
		body.scale.y = maxf(0.05, now / maxf(1.0, h)); body.position.y = now * C.K / 2.0
		top.position.y = now * C.K
		flame.visible = bool(lit[i])
		var tilt := sin(t * 5.1 + float(i) * 1.7) * 0.12
		flame.rotation.z = tilt
		((s["glows"] as Array)[i] as StandardMaterial3D).emission_energy_multiplier = 1.2 + 0.3 * sin(t * TAU * glow_hz + float(s["phase"]) + float(i)) + 0.08 * sin(t * 9.3 + float(i))

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

## 소리 — 짧은 기음이 잦아든다: squish(0.14초, 느리게 — 발이 밀랍에 앉는다)·hiss(0.12초, 높고 길게 — 심지가 발에 눌려 꺼진다)·pop(0.05초, 아주 빠르게 — 심지에 불이 붙는다). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float, decay: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.3) * 0.2) * exp(-k * decay)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
