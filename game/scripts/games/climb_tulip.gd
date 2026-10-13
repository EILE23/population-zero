class_name ClimbTulip
extends Node3D
## Climb 콘텐츠 팩 '튤립 승강기'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 공중정원(Hanging garden) 층(바람구멍 층은 뺀다)의 잇단 두 발판 사이 틈(min_gap..max_gap, 위 발판이 max_dy 안; 아래 발판은 still, 위 발판은 부서지거나 튀어도 된다 — 서는 건 아래뿐) — 아래 발판의 틈 쪽 가장자리에 붙어 절벽 받침의 화분에서 굵은 줄기가 올라오고, 그 위에 발판 높이의 바닥을 가진 커다란 닫힌 튤립 봉오리(bud_w 폭, bud_h 높이)가 꽃잎을 조금 벌리고 선다.
## 아래 발판에서 틈 가장자리 reach 안에서 C: 몸이 봉오리로 한 걸음 들어서고 꽃잎이 fold_s 에 몸을 감싸 닫힌다(몸은 무릎을 가슴으로 — curl) → 줄기가 rise_s 에 걸쳐 lift(위 발판 높이 − top_short, min_lift..max_lift) 만큼 늘어난다(creak) → 꼭대기에서 꽃잎이 bloom_s 에 벌어지고(pop) 몸이 펴진다 → 벌어진 봉오리의 바닥과 줄기에서 위 발판 쪽으로 난 잎 턱(leaf_w)에 선다: 잎 끝에서 위 발판은 톡 뛰는 한 단.
## 몸이 떠난 뒤 hold_s, 또는 핀 뒤 stay_s 가 지나면 누가 서 있든 꽃이 wilt_s 에 걸쳐 시들어 내려온다(발밑이 같이 내려올 뿐, 밀지 않는다) — 시드는 동안엔 쓸 수 없고, 줄기가 돌아오면 close_s 에 꽃잎이 닫혀 다시 선다(누가 아직 서 있으면 벌어진 채 기다린다, spent).
## 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 틈을 건너는 맨 점프는 그대로(봉오리는 그 호 옆의 줄기일 뿐). 몸을 싣고 제 힘으로 자라는 첫 꽃.
## 안에 있는 동안 자세는 curl(stick3d_curl.gd — 운영자 보드의 '웅크리기·공처럼 말기' 가족, cling 의 다음: 무릎을 가슴으로 끌어안고 고개를 묻은 몸, 줄기가 늘어나는 동안 박자로 조금 더 죄고 꽃잎이 벌어지는 만큼 펴진다).
## heave(덤웨이터 — 줄을 당겨 오른다)·ride(풍차 날개 — 선 채 실려 간다)·dangle(가로대에 매달린다)과 다르다: 이건 실려 오르는 동안 공처럼 말린 몸, 오르는 힘이 꽃의 것이다.
## 로더가 할 일(climb.gd, 운영자 세션): `var ct := ClimbTulip.new(); add_child(ct)`; 층을 지을 때 `var vp := cv.plan(n, plats); var bp := cb.plan(n, plats); var hp := ch.plan(n, plats, wind_of(n), bp); var zp := cz.plan(n, plats, hp + bp); var pp := cp.plan(n, plats, vp + bp + hp + zp); ct.build(root, ct.plan(n, plats, vp + bp + hp + zp + pp))` (덩굴·다리·그물·집라인·시소 화분의 계획을 taken 으로 — 그 틈은 비켜 간다); 매 틱 `ct.sync(_t)`;
## 발판에 선 틱의 걷기 자리(`_physics_process` 의 `else:`): `var g := ct.enter(on, x, z, Input.is_action_just_pressed("act")); if not g.is_empty(): on = g; x = float(g["bx"]); vx = 0.0` (봉오리로 들어선 틱 — 사전의 x·w 는 바닥의 왼끝과 폭, bx 가 봉오리 가운데; 빈 사전이면 닿지 않거나 꽃이 쉬고 있지 않은 것);
## 로더 자신의 착지 판정이 비었고 vy <= 0 이면 `landed = ct.land(x, y, ny, z)` (kind "tulip" — 돌려준 사전의 "y" 가 벌어진 봉오리 바닥의 지금 높이; "step" 이 참이면 내려선 걸음, "ramp" 가 참이면 바닥으로 걸어 올라선 걸음이라 vx 를 0 으로 안 해도 된다);
## `on["kind"] == "tulip"` 인 매 틱, 'move' 발판 자리에서: `var r := ct.stand(on, x, dt, fig); x = r["x"]; y = r["y"]; if r["off"]: on = {}; apex = y; else: fig.pose_request = "curl" if r["curl"] else ""`, 꽃을 떠나면 자세를 비운다 — 말린 동안은 ← → 가 안 먹고(x 가 봉오리 가운데) SPACE 는 로더의 홀드 점프 규칙대로.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_tulip.gd

const PACK := "res://data/climb/tulip.json"
const C = preload("res://scripts/games/climb.gd")
const TAKEN_UP := 220.0    # taken 조각(덩굴·다리·그물·집라인·화분) 위로 비워 두는 높이(px) — 제 꼭대기(rail_y·beam_y·y_top)나 len 이 더 높으면 그것
const BODY_UP := 50.0      # 핀 봉오리에 선 몸의 키(px) — 상자 위쪽 여유
const STOOD_T := 0.1       # 이만큼 stand 가 안 오면 몸이 떠난 것 — 시들기의 시계가 돈다
const REST_OPEN := 0.35    # 쉬는 봉오리의 벌어진 정도 0..1 — 몸이 들어설 틈
const OPEN_ANG := 1.3      # 활짝 핀 꽃잎의 기울기(rad, 바깥으로); 닫힌 꽃잎은 끝이 안으로 0.25
const DROOP := 0.4         # 시든 꽃잎이 더 처지는 기울기(rad)
const PETALS := 6

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.tulip
var lifts: Array = []           # 지은 튤립 {id, kind "tulip", x, y, w, z, d, dir, gap, a_edge, b_edge, a_y, b_y, a_id, b_id, bx, lift, x_in, x_out, y_top, node, stem, head, petals, rustle, creak, pop, sigh, phase, t0, top_t, stood, k_stem, open_k, curl_k, droop, sway}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("tulip", {})

func sync(now: float) -> void:
	t = now
	for sv in lifts:
		_settle(sv)

func bud_w() -> float:
	return maxf(8.0, float(kind.get("bud_w", 40.0)))

func bud_h() -> float:
	return maxf(8.0, float(kind.get("bud_h", 44.0)))

func leaf_w() -> float:
	return maxf(0.0, float(kind.get("leaf_w", 36.0)))

func min_lift() -> float:
	return maxf(1.0, float(kind.get("min_lift", 60.0)))

func max_lift() -> float:
	return maxf(min_lift(), float(kind.get("max_lift", 90.0)))

func top_short() -> float:
	return maxf(0.0, float(kind.get("top_short", 40.0)))

func root_d() -> float:
	return maxf(0.0, float(kind.get("root_d", 40.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 24.0)))

func fold_s() -> float:
	return maxf(0.05, float(kind.get("fold_s", 0.4)))

func rise_s() -> float:
	return maxf(0.05, float(kind.get("rise_s", 1.2)))

func bloom_s() -> float:
	return maxf(0.05, float(kind.get("bloom_s", 0.3)))

func stay_s() -> float:
	return maxf(0.0, float(kind.get("stay_s", 5.0)))

func hold_s() -> float:
	return maxf(0.0, float(kind.get("hold_s", 1.5)))

func wilt_s() -> float:
	return maxf(0.05, float(kind.get("wilt_s", 6.0)))

func close_s() -> float:
	return maxf(0.05, float(kind.get("close_s", 0.4)))

func catch_px() -> float:
	return maxf(0.0, float(kind.get("catch", 16.0)))

func deck_d() -> float:
	return maxf(2.0, float(kind.get("deck_d", 28.0)))

## 줄기가 늘어나는 길이(px) — 위 발판 높이 − top_short, min_lift..max_lift 안
func lift_of(dy: float) -> float:
	return clampf(dy - top_short(), min_lift(), max_lift())

## 봉오리 바닥의 지금 높이(px)
func floor_of(s: Dictionary) -> float:
	return float(s["a_y"]) + float(s["lift"]) * float(s["k_stem"])

## x 가 바닥(봉오리 + 잎 턱) 위인가 — 아래 발판 쪽 가장자리에서 잰다
func on_floor(s: Dictionary, x: float) -> bool:
	var u := float(s["dir"]) * (x - float(s["x_in"]))
	return u >= 0.0 and u <= bud_w() + leaf_w()

## 단계를 바꾼다 — at 은 그 단계가 시작한 시각(앞 단계의 끝에 이어 붙여 시계가 틱에 안 끌린다)
func _go(s: Dictionary, phase: String, snd: AudioStreamPlayer3D = null, at: float = -INF) -> void:
	s["phase"] = phase; s["t0"] = t if at == -INF else at
	if snd: _play(snd)

## 꽃의 시계 — 쉼(ajar) → 감싸기 → 늘어나기 → 피기 → 핌 → 시들기 → (spent) → 닫기 → 쉼. k_stem 줄기의 늘어난 몫, open_k 꽃잎의 벌어짐, curl_k 안의 몸이 접힌 몫, droop 시든 처짐
func _settle(s: Dictionary) -> void:
	var ph := String(s["phase"]); var t0 := float(s["t0"]); var k := t - t0
	var gone := t - float(s["stood"]) > STOOD_T
	var f := 0.0
	match ph:
		"rest":
			s["k_stem"] = 0.0; s["open_k"] = REST_OPEN; s["curl_k"] = 0.0; s["droop"] = 0.0
		"fold":
			f = clampf(k / fold_s(), 0.0, 1.0)
			s["k_stem"] = 0.0; s["open_k"] = REST_OPEN * (1.0 - f); s["curl_k"] = f
			if f >= 1.0: _go(s, "rise", s["creak"] as AudioStreamPlayer3D, t0 + fold_s())
		"rise":
			f = clampf(k / rise_s(), 0.0, 1.0)
			s["k_stem"] = smoothstep(0.0, 1.0, f); s["open_k"] = 0.0; s["curl_k"] = 1.0
			if f >= 1.0: _go(s, "bloom", s["pop"] as AudioStreamPlayer3D, t0 + rise_s())
		"bloom":
			f = clampf(k / bloom_s(), 0.0, 1.0)
			s["k_stem"] = 1.0; s["open_k"] = f; s["curl_k"] = 1.0 - f
			if f >= 1.0:
				_go(s, "open", null, t0 + bloom_s()); s["top_t"] = t0 + bloom_s()
		"open":
			s["k_stem"] = 1.0; s["open_k"] = 1.0; s["curl_k"] = 0.0
			var at := minf(float(s["top_t"]) + stay_s(), float(s["stood"]) + hold_s() if gone else INF)   # 핀 뒤 stay_s, 또는 몸이 떠난 뒤 hold_s — 이른 쪽
			if t >= at: _go(s, "wilt", s["sigh"] as AudioStreamPlayer3D, at)
		"wilt":
			f = clampf(k / wilt_s(), 0.0, 1.0)
			s["k_stem"] = 1.0 - smoothstep(0.0, 1.0, f); s["open_k"] = 1.0; s["droop"] = f
			if f >= 1.0: _go(s, "close" if gone else "spent", null, t0 + wilt_s())
		"spent":
			s["k_stem"] = 0.0; s["open_k"] = 1.0; s["droop"] = 1.0
			if gone: _go(s, "close")
		"close":
			f = clampf(k / close_s(), 0.0, 1.0)
			s["k_stem"] = 0.0; s["open_k"] = lerpf(1.0, REST_OPEN, f); s["droop"] = 1.0 - f
			if f >= 1.0: _go(s, "rest", null, t0 + close_s())

## 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	lifts = lifts.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_planter 와 같은 식)
	for sv in lifts:
		var s: Dictionary = sv
		_settle(s)
		_place(s)

## 층 n(테마 층, 조각의 only 규칙)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 max_dy 안으로 높으며 꽃의 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := float(kind.get("min_gap", 84.0)); var max_gap := float(kind.get("max_gap", 200.0)); var max_dy := float(kind.get("max_dy", 150.0))
	var width := bud_w() + leaf_w()
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std", "ice"]); var to: Array = piece.get("to", kinds)   # on: 서는 아래 발판(still 만), to: 뛰어 건너는 위 발판(부서지거나 튀어도 된다)
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var found: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in to): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < 0.0 or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0   # a 에서 b 쪽 — b 가 오른쪽이면 +x
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var a_edge := ax1 if dir > 0.0 else ax0; var b_edge := bx0 if dir > 0.0 else bx1
			var lift := lift_of(dy); var y_top := float(a["y"]) + lift + bud_h()
			var x0 := minf(a_edge, a_edge + dir * width) - 4.0; var x1 := maxf(a_edge, a_edge + dir * width) + 4.0
			var ylo := float(a["y"]) - root_d() + 1.0; var yhi := y_top + BODY_UP
			if not _clear(plats, a, b, x0, x1, ylo, yhi): continue
			if not _free(taken, x0, x1, ylo, yhi): continue
			found.append({ "gap": gap, "dir": dir, "a_edge": a_edge, "b_edge": b_edge, "lift": lift, "y_top": y_top, "bx": a_edge + dir * bud_w() / 2.0, "x_in": a_edge, "x_out": a_edge + dir * width,
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.T%d" % [n, i]; s["kind"] = "tulip"; s["x"] = minf(float(g["x_in"]), float(g["x_out"])); s["w"] = width; s["y"] = float(g["a_y"]); s["z"] = C.PLAYER_Z; s["d"] = deck_d()
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 꽃의 상자(아래 발판 가장자리..봉오리와 잎, 화분..핀 봉오리 꼭대기와 몸)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x·w·y, 있으면 rail_y·beam_y·y_top·floor, 장대면 len)이 꽃의 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지, 제 꼭대기가 더 높으면 거기 + 60 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := minf(qy, float(q.get("floor", qy))) - 10.0; var qy1 := qy + TAKEN_UP
		for key in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qy1 = maxf(qy1, float(q[key]) + 60.0)
		if q.has("len"): qy1 = maxf(qy1, qy + float(q["len"]) + 10.0)
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 발판에 선 틱의 C — 아래 발판(on 이 a) 위, 틈 가장자리 reach 안(가장자리를 4 넘게 지나지 않은 몸), 꽃이 쉬고 있을 때만: 몸이 봉오리로 들어서고(rustle) 감싸기가 시작된다 → {kind "tulip", id, x(봉오리 가운데), y, w, z, d}; 아니면 {}
func enter(on: Dictionary, x: float, z: float, pressed: bool) -> Dictionary:
	if not pressed: return {}
	var id := String(on.get("id", ""))
	for sv in lifts:
		var s: Dictionary = sv
		if id != String(s["a_id"]) or String(s["phase"]) != "rest": continue
		if absf(z - float(s["z"])) >= deck_d() / 2.0 + C.HZ: continue
		var u := float(s["dir"]) * (float(s["a_edge"]) - x)   # 가장자리까지 — 발판 위에서 +
		if u < -4.0 or u > reach(): continue
		_go(s, "fold", s["rustle"] as AudioStreamPlayer3D); s["stood"] = t
		return _on_dict(s, false, false)
	return {}

## 로더가 밟는 사전 — x·w 는 바닥(봉오리 + 잎 턱)의 왼끝과 폭(다른 발판과 같은 꼴), bx 는 봉오리 가운데(들어선 몸의 자리)
func _on_dict(s: Dictionary, step: bool, ramp: bool) -> Dictionary:
	return { "kind": "tulip", "id": String(s["id"]), "x": float(s["x"]), "y": floor_of(s), "w": float(s["w"]), "z": float(s["z"]), "d": deck_d(), "bx": float(s["bx"]), "step": step, "ramp": ramp }

## 로더의 착지 판정이 빈 뒤(vy <= 0) — 벌어진 꽃(피는 중·핌·시듦·spent)의 바닥을 이 틱에 지나 떨어지는 몸, 바닥 위 catch 안에서 내려서는 몸, 또는 바닥이 발 위 catch 안에 있는 몸(걸어 올라서는 걸음)을 받는다(rustle). 닫힌 봉오리는 발판이 아니다
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	var catch := catch_px()
	for sv in lifts:
		var s: Dictionary = sv
		if not (String(s["phase"]) in ["bloom", "open", "wilt", "spent"]): continue
		if absf(z - float(s["z"])) >= deck_d() / 2.0 + C.HZ: continue
		if not on_floor(s, x): continue
		if ny > y: continue   # 오르는 몸은 받지 않는다
		var sy := floor_of(s)
		var cross := y >= sy and ny <= sy
		var step := not cross and y > sy and y - sy <= catch
		var ramp := not cross and y < sy and sy - y <= catch
		if not (cross or step or ramp): continue
		s["stood"] = t
		_play(s["rustle"] as AudioStreamPlayer3D)
		return _on_dict(s, step, ramp)
	return {}

## 꽃 위의 매 틱 — {x, y, off, curl, phase}: 감싸기·늘어나기·피기 동안 x 는 봉오리 가운데에 묶이고 curl; 핀 뒤엔 바닥과 잎 턱 위를 걷고 어느 끝이든 넘으면 off(떨어져 발판이나 바닥이 받는다); 쉬는·닫히는 꽃이나 모르는 꽃이면 off
## fig 가 있으면 자세의 메타를 적는다: curl_k 접힌 몫 0..1, curl_v 줄기가 늘어나는 중이면 1
func stand(on: Dictionary, x: float, _dt: float, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "x": x, "y": float(on.get("y", 0.0)), "off": true, "curl": false, "phase": "" }
	var ph := String(s["phase"]); var y := floor_of(s)
	if ph in ["rest", "close"]: return { "x": x, "y": y, "off": true, "curl": false, "phase": ph }
	var curled := ph in ["fold", "rise", "bloom"]
	if curled: x = float(s["bx"])   # 꽃잎 속 — 봉오리 가운데에 묶인다
	elif not on_floor(s, x): return { "x": x, "y": y, "off": true, "curl": false, "phase": ph }
	s["stood"] = t
	if fig:
		fig.set_meta("curl_k", float(s["curl_k"]))
		fig.set_meta("curl_v", 1.0 if ph == "rise" else 0.0)
	return { "x": x, "y": y, "off": false, "curl": curled, "phase": ph }

func _find(id: String) -> Dictionary:
	for sv in lifts:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 화분과 줄기와 봉오리를 짓는다 — root 는 그 층의 노드. 노드 원점은 봉오리 가운데(bx, 아래 발판 윗면, PLAYER_Z); 절벽 받침 팔·화분·줄기(길이 1 의 기둥을 scale.y 로 늘린다)·밑동의 잎 둘·머리(바닥 원반·꽃잎 여섯·잎 턱·잎맥)·소리 넷
func build(root: Node3D, planned: Array) -> void:
	var r := bud_w() / 2.0 * C.K; var h := bud_h() * C.K; var dd := deck_d() * C.K; var rd := root_d() * C.K; var lw := leaf_w() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var dir := float(s["dir"])
		var node := Node3D.new(); node.position = C.to3(float(s["bx"]), float(s["a_y"]), float(s["z"]) * C.K); root.add_child(node)
		var clay := _mat(Color("c8775a")); var green := _mat(Color("6f9a48")); var leaf := _mat(Color("8fbd5a")); var petal := _mat(Color("d98aa8")); var mauve := _mat(Color("ad7096")); var brass := _mat(Color("c9a24a"))
		var arm_len := (C.PLAYER_Z - C.WALL_Z) * C.K + dd / 2.0
		_box(node, Vector3(0.06, 0.05, arm_len), brass).position = Vector3(0.0, -rd - 0.3, -arm_len / 2.0 + dd / 2.0)   # 받침 팔 — 절벽에서
		_cyl(node, r * 0.9, 0.3, clay).position = Vector3(0.0, -rd - 0.15, 0.0)                                             # 화분 — 줄기가 흙에서
		var stem := Node3D.new(); stem.position = Vector3(0.0, -rd, 0.0); node.add_child(stem)
		_cyl(stem, 0.05, 1.0, green).position = Vector3(0.0, 0.5, 0.0)                                                       # 줄기 — scale.y 가 길이
		for d: Array in [[1.0, 0.35], [-1.0, 0.22]]:
			var lf := _box(node, Vector3(0.5, 0.02, 0.16), leaf); lf.position = Vector3(float(d[0]) * 0.22, -rd + float(d[1]), 0.0); lf.rotation.z = -float(d[0]) * 0.45   # 밑동의 잎 둘 — 높이가 다르다
		var head := Node3D.new(); node.add_child(head)
		_cyl(head, r, 0.03, green).position = Vector3(0.0, -0.015, 0.0)                                                        # 바닥 — 벌어진 꽃의 꽃받침
		var petals: Array = []
		for i in PETALS:
			var th := TAU * float(i) / float(PETALS) + 0.26
			var pv := Node3D.new(); pv.position = Vector3(cos(th) * r, 0.0, sin(th) * r); pv.rotation.y = -th; head.add_child(pv)   # 지역 +x 가 바깥
			_box(pv, Vector3(0.03, h, TAU * r / float(PETALS) * 1.08), mauve if i % 3 == 0 else petal).position = Vector3(0.0, h / 2.0, 0.0)
			petals.append(pv)
		_box(head, Vector3(lw, 0.03, dd * 0.8), leaf).position = Vector3(dir * (r + lw / 2.0), -0.015, 0.0)                   # 잎 턱 — 위 발판 쪽으로
		_box(head, Vector3(lw * 0.9, 0.012, 0.02), green).position = Vector3(dir * (r + lw / 2.0), 0.004, 0.0)                 # 잎맥
		var rustle := _snd(node, float(kind.get("rustle_hz", 900)), 0.1, 9.0, -16.0); var creak := _snd(node, float(kind.get("creak_hz", 120)), 0.5, 3.0, -14.0)
		var pop := _snd(node, float(kind.get("pop_hz", 700)), 0.06, 12.0, -12.0); var sigh := _snd(node, float(kind.get("sigh_hz", 300)), 0.6, 2.5, -18.0)
		s["node"] = node; s["stem"] = stem; s["head"] = head; s["petals"] = petals; s["rustle"] = rustle; s["creak"] = creak; s["pop"] = pop; s["sigh"] = sigh
		s["phase"] = "rest"; s["t0"] = t; s["top_t"] = t; s["stood"] = -99.0; s["k_stem"] = 0.0; s["open_k"] = REST_OPEN; s["curl_k"] = 0.0; s["droop"] = 0.0; s["sway"] = fposmod(float(s["bx"]) * 0.37, TAU)
		lifts.append(s)
		_place(s)

## 줄기를 늘어난 만큼, 머리를 그 위로, 꽃잎을 벌어진 만큼 바깥으로(시들면 더 처진다); 머리는 느리게 흔들린다
func _place(s: Dictionary) -> void:
	var k_stem := float(s["k_stem"]); var open_k := float(s["open_k"]); var droop := float(s["droop"])
	var stem: Node3D = s["stem"]; var head: Node3D = s["head"]
	var stem_len := (root_d() + float(s["lift"]) * k_stem) * C.K
	stem.scale.y = maxf(0.05, stem_len)
	head.position.y = float(s["lift"]) * k_stem * C.K
	head.rotation.z = sin(t * 1.3 + float(s["sway"])) * 0.03
	for pv in (s["petals"] as Array):
		(pv as Node3D).rotation.z = 0.25 * (1.0 - open_k) - (OPEN_ANG + DROOP * droop) * open_k

func _snd(parent: Node3D, hz: float, secs: float, decay: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs, decay); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

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

## 소리 — 짧은 기음이 잦아든다: rustle(0.1초, 빠르게 — 꽃잎이 스친다)·creak(0.5초, 낮고 길게 — 줄기가 늘어난다)·pop(0.06초 — 꽃잎이 벌어진다)·sigh(0.6초, 아주 느리게 — 꽃이 시든다). 한 번 재생, 반복 없음
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
