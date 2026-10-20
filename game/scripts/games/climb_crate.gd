class_name ClimbCrate
extends Node3D
## Climb 콘텐츠 팩 '이삿짐 상자'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 옛 홀(Old hall) 층의 넓은 still 발판(min_w 이상, std 만 — 얼음은 더미가 미끄러지고, 움직이는 발판은 두고 가고, 부서지는 발판은 떨어뜨리고, 튀는 발판은 더미에서 몸을 던진다) 가운데 다음 발판 b 가 가장 높이 오르는 발판 a — 틈 반대쪽 끝 pile_in 안의 분필 자리에 상자 count 개가 쌓여 있다.
## a(또는 그 위의 더미) 위에서 C 한 번(더미 가운데 곁 HW + w/2 + reach, 제가 선 더미는 빼고): 맨 위 상자를 든다(lift_s — 쪼그려 잡아 배에 안고 일어선다, busy) → 안은 채 걷는다(걸음 slow 배, 점프 없음) → C 한 번: 앞(x + face·(HW + 2 + w/2))에 내려놓는다(set_s, busy) — a 안이면 바닥에 새 더미로, 닿은 더미가 있으면 그 위에(x 를 맞춘다, max_stack 까지).
## 더미 꼭대기는 떨어지는 몸의 디딤(land, h 마다 한 단) — 탑에서 제 손으로 짓는 첫 디딤. 안은 채 a 를 떠나면(공중에 뜨거나 다른 데 내려서면) 상자가 손에서 미끄러져(SLIP_T) 포물선으로 분필 자리에 굴러 돌아간다(tumble_s, thud) — 상자는 이 발판의 것.
## 꽉 찬 더미 위·a 밖에 내려놓기는 아무것도 아니다(안은 채 그대로). 더미가 max_stack 에 닿으면 탑의 하루(day_s)에 한 번 센다(플레이어의 것만 판의 날; 쉼터 판이 note(n) 으로 읽는다: 'Removal crates, floors 1–4: 1 of 1 pile stacked 3 high today, 3 of 3 crates off the pile.').
## 더미 곁에서 C 를 누르지 않는 몸에겐 아무것도 바뀌지 않는다: a 를 달려 지나는 길, 틈을 건너는 맨 점프, 더미를 지나 걷기(더미는 위에서 오는 몸만 받는다 — 막지 않는다)는 그대로(평이한 결과 100%). 값도 없다.
## 자세는 lug(stick3d_lug.gd — 운영자 보드의 '상자·가구 나르기' 가족의 첫 자세: 쪼그려 잡고 배에 안아 일어서는 몸, 안은 채 짧게 걷는 다리, 무게에 뒤로 버티는 상체, 떨리는 팔, 놓치는 손 — 정지화가 아니다). 안은 상자는 몸(torso)의 자식 — 몸과 함께 가고 기운다.
## shunt(서가를 민다)·heave(줄을 당긴다)·press(추를 머리 위에 버틴다)·carry(마을의 작은 것을 한 손에)와 다르다: 이건 두 팔로 안아 옮겨 쌓는 첫 것 — 쌓은 자리가 디딤이 된다.
## 로더가 할 일(climb.gd, 운영자 세션): `var cc := ClimbCrate.new(); add_child(cc); signs.notes.append(cc.note)`; 층을 지을 때 `var bl := cb.plan(n, plats); var dr := cr.plan(n, plats, bl); var ll := cl.plan(n, plats, bl + dr); var db := dw.plan(n, plats, bl + dr + ll); cc.build(root, cc.plan(n, plats, bl + dr + ll + db + tp.plan(n, plats, bl + dr + ll + db, wind_of(n)) + lg.plan(n, plats, bl + dr)))`
## (종 줄·회전문·빨랫줄·도개교·태피스트리·통나무의 계획을 taken 으로 — 그 발판은 비켜 간다); 매 틱 `cc.sync(_t)`;
## `_physics_process` 에서 jump_held 를 읽은 뒤, 발판 위든 공중이든: `var ck := cc.step(on, x, z, face, not locked and Input.is_action_just_pressed("act"), dt, fig); if ck["busy"]: dir = 0.0; jump_held = false; charge = 0.0 elif ck["lug"]: dir *= cc.slow(); jump_held = false; charge = 0.0`
## `if ck["busy"] or ck["lug"]: fig.pose_request = "lug" elif fig.pose_request == "lug": fig.pose_request = ""` (step 이 매 틱 와야 한다 — HELD_T 동안 안 오면 안은 몸이 사라진 것이라 상자가 굴러 집으로);
## 로더 자신의 착지 판정이 비면 `landed = cc.land(x, y, ny, z)` (kind "crate" — 더미 꼭대기; 로더의 떠남 판정은 x·w·z·d 로 그대로 된다 — 더미는 안 움직인다). 쉼터 판 C 는 signs.tick 이 먼저 — 더미는 발판에만 선다.
## step 의 tally: 비우면 플레이어(판에 세고 me_t 를 적는다 — 주민 반쪽이 따라 나른다; C 가 없어도 더미 곁 NEAR 안에 선 틱을 near_t 에 적는다 — 짐꾼이 비켜 선다), 다른 몸은 거짓을 준다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_crate.gd
## 주민 반쪽(run 183): 더미마다 짐꾼 하나(climb_porter.gd — 더미 노드 아래 Stick3D)가 틈 쪽 끝에 카메라를 보고 서서 탑의 1분마다, 그리고 플레이어의 더미가 다 쌓인(me_t) 2 s 뒤에 분필 자리에서 가장 먼 더미로 걸어가 맨 위 상자를 재 보고(heft) 같은 step(tally 거짓)·같은 lug 로 들어 분필 자리에 되돌려 놓는다 — 더미가 다 돌아올 때까지 하나씩; 플레이어가 더미 곁이거나 안고 있으면 집에서 기다린다. 판의 줄에 'the porter put N back' 이 붙는다. 로더가 할 일은 없다 — 팩이 짓고 틱을 준다.

const PACK := "res://data/climb/crate.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_LO := 20.0      # taken 조각이 이 발판의 것인가: y 가 발판 − BAND_LO 부터 + BAND_HI 앞까지(run 152 의 띠 규칙)
const BAND_HI := 60.0
const BODY_UP := 50.0      # 더미 위에 선 몸의 키(px) — 더미 상자 위쪽 여유
const SIDE := 10.0         # 더미 상자의 x 여유(px) — 손 하나
const HELD_T := 0.25       # 이만큼 step 이 안 오면 안은 몸이 사라진 것 — 상자가 굴러 집으로
const SLIP_T := 0.3        # 손에서 미끄러지는 시간(s) — 자세의 lug_x
const HOLD_Y := 0.20       # 안은 상자의 가운데: 골반에서 위로(m) — stick3d_lug.gd 의 손 높이와 같은 수
const HOLD_Z := 0.34       # 안은 상자의 가운데: 몸 앞으로(m)
const TUMBLE_UP := 0.3     # 굴러 돌아가는 상자의 포물선 높이(m)
const NEAR := 60.0         # 플레이어가 분필 자리나 더미에서 이 안에 선 틱을 near_t 에 적는다(px) — 짐꾼이 집에서 기다린다

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.pile
var piles: Array = []           # 지은 더미 {id, kind "pile", n, a_id, a_x, a_w, a_y, b_id, dy, dir, px, x, w, y, y_top, z, d, node, stacks [{id, x, n, crates}], next, holder, held, sw, sw_t0, step_t, last_x, count, set_x, set_i, day, me_t, lifts, slips, fulls, full_day, day_fulls, tumbles, creak, thud, roll, near_t, ported, port_day, porter}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("pile", {})

func sync(now: float) -> void:
	t = now

func w() -> float:
	return maxf(2.0 * C.HW, float(kind.get("w", 26.0)))

func h() -> float:
	return maxf(4.0, float(kind.get("h", 20.0)))

func deck_d() -> float:
	return maxf(2.0, float(kind.get("deck_d", 16.0)))

func count() -> int:
	return maxi(1, int(kind.get("count", 3)))

func min_w() -> float:
	return maxf(w() + 4.0 * C.HW, float(kind.get("min_w", 150.0)))

func pile_in() -> float:
	return maxf(w() / 2.0, float(kind.get("pile_in", 30.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 14.0)))

func lift_s() -> float:
	return maxf(0.05, float(kind.get("lift_s", 0.5)))

func set_s() -> float:
	return maxf(0.05, float(kind.get("set_s", 0.4)))

func slow() -> float:
	return clampf(float(kind.get("slow", 0.6)), 0.1, 1.0)

func max_stack() -> int:
	return maxi(1, int(kind.get("max_stack", 3)))

func tumble_s() -> float:
	return maxf(0.05, float(kind.get("tumble_s", 0.6)))

func day_s() -> float:
	return maxf(1.0, float(kind.get("day_s", 600.0)))

## 탑의 오늘 — 로더의 시계를 day_s 로 나눈 몫
func day() -> int:
	return floori(t / day_s())

## 층 n(테마 층, 조각의 not 규칙)의 still 발판 a(조각의 on, min_w 이상) 가운데 다음 발판 b 가 가장 높이 오르고 더미의 상자를 다른 발판이 가르지 않고 taken 조각이 발판에 닿지 않는 것 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var skip: Dictionary = piece.get("not", {})
		if not skip.is_empty() and _on(n, skip): continue
		var kinds: Array = piece.get("on", ["std"])
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var found: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds): continue
			var ax := float(a["x"]); var aw := float(a["w"]); var ay := float(a["y"])
			if aw < min_w(): continue
			var dy := float(b["y"]) - ay
			if dy <= 0.0: continue
			var dir := 1.0 if float(b["x"]) + float(b["w"]) / 2.0 >= ax + aw / 2.0 else -1.0   # a 에서 b 쪽
			var px := ax + pile_in() + w() / 2.0 if dir > 0.0 else ax + aw - pile_in() - w() / 2.0   # 더미는 틈 반대쪽 끝 — 뜀길을 안 막는다
			var lo := px - w() / 2.0 - SIDE; var hi := px + w() / 2.0 + SIDE
			var ylo := ay - 10.0; var yhi := ay + float(count()) * h() + BODY_UP
			if not _clear(plats, a, lo, hi, ylo, yhi): continue
			if not _free(taken, ax - SIDE, ax + aw + SIDE, ay - BAND_LO, ay + BAND_HI): continue   # 발판 전체 — 상자는 a 어디에나 놓인다
			found.append({ "a_id": String(a["id"]), "a_x": ax, "a_w": aw, "a_y": ay, "b_id": String(b["id"]), "dy": dy, "dir": dir, "px": px, "x": lo, "w": hi - lo })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["dy"]) > float(q["dy"]) if float(p["dy"]) != float(q["dy"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.K%d" % [n, i]; s["kind"] = "pile"; s["n"] = n
			s["y"] = float(g["a_y"]); s["y_top"] = float(g["a_y"]) + float(count()) * h()   # 다른 팩의 _free 가 읽는 키 — 상자는 발판에서 더미 꼭대기까지
			s["z"] = C.PLAYER_Z; s["d"] = deck_d()
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 더미의 상자(x 폭, a 윗면 조금 밑..더미 위 선 몸)에 a 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
static func _clear(plats: Array, a: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var amp := float(p.get("amp", 0.0))
		var px0 := float(p["x"]) - amp - 10.0; var px1 := float(p["x"]) + float(p["w"]) + amp + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: x·w·y, 있으면 len·y_top)이 발판의 상자에 닿지 않나 — 조각의 몸은 y − BAND_LO 부터 y + BAND_HI(제 꼭대기 len·y_top 가 더 높으면 거기 + 10)까지
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - BAND_LO; var qy1 := qy + BAND_HI
		if q.has("len"): qy1 = maxf(qy1, qy + float(q["len"]) + 10.0)
		if q.has("y_top"): qy1 = maxf(qy1, float(q["y_top"]) + 10.0)
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 로더 자신의 착지 판정이 빈 뒤 — 떨어지는 몸이 더미 꼭대기를 지나면 올라선다: {kind "crate", id, x, y, w, z, d}. 아니면 빈 사전
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	if absf(z - C.PLAYER_Z) >= deck_d() / 2.0 + C.HZ: return {}
	for sv in piles:
		var s: Dictionary = sv
		for kv in (s["stacks"] as Array):
			var k: Dictionary = kv
			if int(k["n"]) <= 0: continue
			var top := float(s["a_y"]) + float(k["n"]) * h()
			if y < top or ny > top: continue
			var sx := float(k["x"])
			if x + C.HW <= sx - w() / 2.0 or x - C.HW >= sx + w() / 2.0: continue
			return { "kind": "crate", "id": String(k["id"]), "x": sx - w() / 2.0, "y": top, "w": w(), "z": C.PLAYER_Z, "d": deck_d() }
	return {}

## 매 틱 — {busy, lug}: 안은 상자가 있으면 그 틱(_carry), 없으면 C 가 막 눌리고 a(또는 그 더미) 위에 서서 더미 곁이면 든다(busy). 아무것도 아니면 둘 다 거짓
func step(on: Dictionary, x: float, z: float, face: float, pressed: bool, dt: float, fig: Stick3D = null, tally := true) -> Dictionary:
	if fig == null: return { "busy": false, "lug": false }
	var mine := _held_by(fig)
	if not mine.is_empty(): return _carry(mine, on, x, face, pressed, dt)
	if on.is_empty() or absf(z - C.PLAYER_Z) >= C.HZ + 4.0: return { "busy": false, "lug": false }
	var here := _here(on)
	if here.is_empty(): return { "busy": false, "lug": false }
	if tally and _near(here, x): here["near_t"] = t   # 플레이어가 더미 곁에 선 틱(C 없이도) — 짐꾼은 집에서 기다린다
	if not pressed: return { "busy": false, "lug": false }
	var k := _nearest(here, x, String(on.get("id", "")))
	if k.is_empty() or fig.torso == null: return { "busy": false, "lug": false }
	_lift(here, k, x, fig, tally)
	return { "busy": true, "lug": false }

## 안은 몸의 틱 — 들기(lift)·안고 걷기(lug: a 를 떠나면 미끄러지고, C 면 내려놓기로)·내려놓기(set)·미끄러짐(slip)
func _carry(s: Dictionary, on: Dictionary, x: float, face: float, pressed: bool, dt: float) -> Dictionary:
	s["step_t"] = t
	var v := clampf(absf(x - float(s["last_x"])) / dt / (C.WALK * slow()), 0.0, 1.0) if dt > 0.0 else 0.0
	s["last_x"] = x
	var u := t - float(s["sw_t0"])
	match String(s["sw"]):
		"lift":
			_metas(s, clampf(u / lift_s(), 0.0, 1.0), 0.0, 0.0)
			if u >= lift_s(): s["sw"] = "lug"; s["sw_t0"] = t; return { "busy": false, "lug": true }   # 안은 틱 — 그 틱부터 걷는다
			return { "busy": true, "lug": false }
		"lug":
			if on.is_empty() or String(_here(on).get("id", "")) != String(s["id"]):   # a 를 떠났다(공중·다른 발판) — 상자가 손에서 미끄러진다
				_slip(s); return { "busy": false, "lug": true }
			if pressed and _set_down(s, on, x, face): _metas(s, 1.0, 0.0, 0.0); return { "busy": true, "lug": false }
			_metas(s, 1.0, v, 0.0)
			return { "busy": false, "lug": true }
		"set":
			_metas(s, 1.0 - clampf(u / set_s(), 0.0, 1.0), 0.0, 0.0)
			if u >= set_s(): _put(s); return { "busy": false, "lug": false }
			return { "busy": true, "lug": false }
		"slip":
			_metas(s, 1.0, 0.0, clampf(u / SLIP_T, 0.0, 1.0))
			if u >= SLIP_T: _release(s); return { "busy": false, "lug": false }
			return { "busy": false, "lug": true }
	return { "busy": false, "lug": false }

## 선 발판(on)이 어느 더미의 a 또는 그 더미인가 — 아니면 빈 사전
func _here(on: Dictionary) -> Dictionary:
	var oid := String(on.get("id", ""))
	for sv in piles:
		var s: Dictionary = sv
		if oid == String(s["a_id"]): return s
		for kv in (s["stacks"] as Array):
			if oid == String((kv as Dictionary)["id"]): return s
	return {}

## 이 몸이 안은 더미(들기·안기·내려놓기·미끄러짐 중) — 아니면 빈 사전
func _held_by(fig: Stick3D) -> Dictionary:
	for sv in piles:
		var s: Dictionary = sv
		if String(s["sw"]) != "" and is_instance_valid(s["holder"]) and (s["holder"] as Stick3D) == fig: return s   # 사라진 몸은 as 전에 거른다
	return {}

## 이 몸이 상자를 안고 있나(들기·안기·내려놓기·미끄러짐)
func lugging(fig: Stick3D) -> bool:
	return not _held_by(fig).is_empty()

## x 곁(HW + w/2 + reach)의 가장 가까운 상자 있는 더미 — 제가 선 더미(on_id)는 뺀다
func _nearest(s: Dictionary, x: float, on_id: String) -> Dictionary:
	var best: Dictionary = {}; var best_d := 1e9
	for kv in (s["stacks"] as Array):
		var k: Dictionary = kv
		if int(k["n"]) <= 0 or String(k["id"]) == on_id: continue
		var d := absf(x - float(k["x"]))
		if d <= C.HW + w() / 2.0 + reach() and d < best_d: best = k; best_d = d
	return best

## x 가 분필 자리나 상자 있는 더미의 NEAR 안인가 — 짐꾼의 배려
func _near(s: Dictionary, x: float) -> bool:
	if absf(x - float(s["px"])) <= NEAR: return true
	for kv in (s["stacks"] as Array):
		var k: Dictionary = kv
		if int(k["n"]) > 0 and absf(x - float(k["x"])) <= NEAR: return true
	return false

## 더미 k 의 맨 위 상자를 든다 — 상자는 몸(torso)의 자식으로, 빈 더미(분필 자리 말고)는 지운다
func _lift(s: Dictionary, k: Dictionary, x: float, fig: Stick3D, tally: bool) -> void:
	var nd := (k["crates"] as Array).pop_back() as Node3D
	k["n"] = int(k["n"]) - 1
	if int(k["n"]) <= 0 and String(k["id"]) != String((((s["stacks"] as Array)[0]) as Dictionary)["id"]): (s["stacks"] as Array).erase(k)
	_reparent(nd, fig.torso, Vector3(0.0, HOLD_Y, HOLD_Z))
	s["holder"] = fig; s["held"] = nd; s["sw"] = "lift"; s["sw_t0"] = t; s["step_t"] = t; s["last_x"] = x; s["count"] = tally
	s["lifts"] = int(s["lifts"]) + 1
	_metas(s, 0.0, 0.0, 0.0)
	_play(s["creak"] as AudioStreamPlayer3D)

## 앞에 내려놓을 수 있나 — 발자국(x + face·(HW + 2 + w/2) ± w/2)이 a 안이고, 닿은 더미가 없거나 덜 찼으면 내려놓기로(set_x·set_i)
func _set_down(s: Dictionary, on: Dictionary, x: float, face: float) -> bool:
	var cx := x + (1.0 if face >= 0.0 else -1.0) * (C.HW + 2.0 + w() / 2.0)
	if cx - w() / 2.0 < float(s["a_x"]) or cx + w() / 2.0 > float(s["a_x"]) + float(s["a_w"]): return false
	var stacks: Array = s["stacks"]; var idx := -1
	for i in stacks.size():
		var k: Dictionary = stacks[i]
		if absf(float(k["x"]) - cx) < w(): idx = i; break
	if idx >= 0:
		var k: Dictionary = stacks[idx]
		if int(k["n"]) >= max_stack() or String(k["id"]) == String(on.get("id", "")): return false   # 꽉 찼거나 제가 선 더미 — 아무것도 아니다
	s["set_x"] = cx; s["set_i"] = idx; s["sw"] = "set"; s["sw_t0"] = t
	return true

## 내려놓는다 — 닿은 더미 위에(x 를 맞춘다) 또는 새 더미로; max_stack 에 닿으면 센다(오늘·전체; 플레이어의 것만 판의 날)
func _put(s: Dictionary) -> void:
	var stacks: Array = s["stacks"]
	var k: Dictionary = {}
	if int(s["set_i"]) >= 0: k = stacks[int(s["set_i"])]
	else:
		k = { "id": "%s.%d" % [String(s["id"]), int(s["next"])], "x": float(s["set_x"]), "n": 0, "crates": [] }
		s["next"] = int(s["next"]) + 1; stacks.append(k)
	var nd := s["held"] as Node3D
	_reparent(nd, s["node"] as Node3D, Vector3.ZERO)
	(k["crates"] as Array).append(nd); k["n"] = int(k["n"]) + 1
	_place(s, k)
	_play(s["thud"] as AudioStreamPlayer3D)
	if int(k["n"]) >= max_stack():
		s["fulls"] = int(s["fulls"]) + 1
		if int(s["full_day"]) != day(): s["full_day"] = day(); s["day_fulls"] = 0
		s["day_fulls"] = int(s["day_fulls"]) + 1
		if bool(s["count"]): s["day"] = day(); s["me_t"] = t   # 플레이어가 다 쌓았다 — 주민 반쪽이 따라 나른다
	_release(s)

## 짐꾼이 분필 더미에 되돌려 놓았다(climb_porter 의 set 끝) — 오늘의 셈, 판의 'the porter put N back'
func put_back(s: Dictionary) -> void:
	if int(s["port_day"]) != day(): s["port_day"] = day(); s["ported"] = 0
	s["ported"] = int(s["ported"]) + 1

## 상자가 손에서 미끄러진다 — 지금 자리에서 분필 자리로 굴러간다(tumble), 몸은 SLIP_T 동안 놓치는 자세
func _slip(s: Dictionary) -> void:
	var hv: Variant = s["held"]; var node := s["node"] as Node3D
	var nd: Node3D = null
	if is_instance_valid(hv): nd = hv as Node3D   # 몸과 함께 지워진 상자는 as 하지 않는다
	var from := Vector3(0.0, (float(count()) * h() + h() / 2.0) * C.K, 0.0)
	if nd != null and nd.is_inside_tree(): from = node.to_local(nd.global_position)
	if nd != null: _reparent(nd, node, from)
	else: nd = _crate(node); nd.position = from   # 안은 몸이 통째로 사라졌다 — 상자를 새로
	(s["tumbles"] as Array).append({ "node": nd, "t0": t, "from": from })
	s["held"] = null; s["sw"] = "slip"; s["sw_t0"] = t; s["slips"] = int(s["slips"]) + 1
	_play(s["roll"] as AudioStreamPlayer3D)

## 자세의 메타 — lug_t 든 몫 0..1, lug_v 걷는 속도 0..1, lug_x 미끄러짐 0..1
func _metas(s: Dictionary, lt: float, v: float, x: float) -> void:
	if not is_instance_valid(s["holder"]): return
	var fig := s["holder"] as Stick3D
	fig.set_meta("lug_t", lt); fig.set_meta("lug_v", v); fig.set_meta("lug_x", x)

## 상자에서 떠난 몸 — 자세의 메타를 거둔다
func leave(fig: Stick3D) -> void:
	if fig == null or not is_instance_valid(fig): return
	for key: String in ["lug_t", "lug_v", "lug_x"]:
		if fig.has_meta(key): fig.remove_meta(key)

func _release(s: Dictionary) -> void:
	if is_instance_valid(s["holder"]): leave(s["holder"] as Stick3D)
	s["holder"] = null; s["held"] = null; s["sw"] = ""

## 더미 k 의 상자들을 제자리에 — 노드 원점은 분필 자리(px, a 윗면); i 번째 상자의 가운데는 i·h + h/2 위
func _place(s: Dictionary, k: Dictionary) -> void:
	var crates: Array = k["crates"]
	for i in crates.size():
		var nd := crates[i] as Node3D
		nd.position = Vector3((float(k["x"]) - float(s["px"])) * C.K, (float(i) * h() + h() / 2.0) * C.K, 0.0); nd.rotation = Vector3.ZERO

static func _reparent(nd: Node3D, to: Node3D, at: Vector3) -> void:
	var p := nd.get_parent()
	if p != null: p.remove_child(nd)
	to.add_child(nd); nd.position = at; nd.rotation = Vector3.ZERO

## n0..n1 층의 더미에서 오늘 다 쌓은 수·전체·분필 자리를 떠난 상자·상자 전체·짐꾼이 오늘 되돌린 상자 — {full, total, off, crates, back}
func top_today(n0: int, n1: int) -> Dictionary:
	var full := 0; var total := 0; var off := 0; var crates := 0; var back := 0
	for sv in piles:
		var s: Dictionary = sv
		if int(s["n"]) < n0 or int(s["n"]) > n1: continue
		total += 1; crates += count()
		if int(s["day"]) == day(): full += 1
		off += count() - int((((s["stacks"] as Array)[0]) as Dictionary)["n"])
		if int(s["port_day"]) == day(): back += int(s["ported"])
	return { "full": full, "total": total, "off": off, "crates": crates, "back": back }

## 쉼터 판(n 층)에 붙는 줄 — 위 다섯 층(n..n+4)의 더미, 없으면 아래 다섯 층(n−5..n−1), 그것도 없으면 빈 줄. climb_signs.notes 에 넣는다
func note(n: int) -> String:
	for span: Array in [[n, n + 4], [n - 5, n - 1]]:
		var v := top_today(int(span[0]), int(span[1]))
		if int(v["total"]) > 0:
			return "Removal crates, floors %d–%d: %d of %d %s stacked %d high today, %d of %d crates off the pile, the porter put %d back." % [int(span[0]), int(span[1]), int(v["full"]), int(v["total"]), "pile" if int(v["total"]) == 1 else "piles", max_stack(), int(v["off"]), int(v["crates"]), int(v["back"])]
	return ""

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 굴러가는 상자와 사라진 몸 — 안은 몸이 HELD_T 동안 step 을 안 주면(탑을 나갔다) 상자가 굴러 집으로; 구르는 상자는 포물선 끝에 분필 자리의 더미에 얹힌다(thud)
func _process(delta: float) -> void:
	t += delta
	piles = piles.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_bellows 와 같은 식)
	for sv in piles:
		var s: Dictionary = sv
		if s.has("porter"): (s["porter"] as ClimbPorter).step(delta)   # 짐꾼의 틱 — HELD_T 판정보다 먼저라 안은 상자의 step_t 가 새롭다
		if String(s["sw"]) != "" and String(s["sw"]) != "slip" and (not is_instance_valid(s["holder"]) or t - float(s["step_t"]) > HELD_T): _slip(s); _release(s)
		var keep: Array = []
		var pile: Dictionary = (s["stacks"] as Array)[0]
		for tv in (s["tumbles"] as Array):
			var tb: Dictionary = tv
			var k := clampf((t - float(tb["t0"])) / tumble_s(), 0.0, 1.0)
			var from: Vector3 = tb["from"]; var nd := tb["node"] as Node3D
			var to := Vector3(0.0, (float(pile["n"]) * h() + h() / 2.0) * C.K, 0.0)
			nd.position = from.lerp(to, k) + Vector3(0.0, TUMBLE_UP * sin(PI * k), 0.0)
			nd.rotation.z = TAU * k * (1.0 if from.x > 0.0 else -1.0)
			if k >= 1.0: (pile["crates"] as Array).append(nd); pile["n"] = int(pile["n"]) + 1; _place(s, pile); _play(s["thud"] as AudioStreamPlayer3D)
			else: keep.append(tb)
		s["tumbles"] = keep

## 더미를 짓는다 — root 는 그 층의 노드. 노드 원점은 (분필 자리 px, a 윗면, PLAYER_Z); 분필 선 넷, 상자 count 개(나무 몸통·앞면 널 둘·밧줄 손잡이 둘·스텐실), 소리 셋
func build(root: Node3D, planned: Array) -> void:
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var node := Node3D.new(); node.position = C.to3(float(s["px"]), float(s["a_y"]), C.PLAYER_Z * C.K); root.add_child(node)
		var chalk := _mat(Color("f7f4ef"))
		var cw := (w() + 8.0) * C.K; var cd := (deck_d() + 8.0) * C.K
		for sd: float in [-1.0, 1.0]:
			_box(node, Vector3(cw, 0.01, 0.03), chalk).position = Vector3(0.0, 0.006, sd * cd / 2.0)   # 분필 자리 — 앞뒤 선
			_box(node, Vector3(0.03, 0.01, cd), chalk).position = Vector3(sd * cw / 2.0, 0.006, 0.0)   # 좌우 선
		var pile := { "id": "%s.0" % String(s["id"]), "x": float(s["px"]), "n": count(), "crates": [] }
		for i in count(): (pile["crates"] as Array).append(_crate(node))
		s["node"] = node; s["stacks"] = [pile]; s["next"] = 1; s["tumbles"] = []
		s["holder"] = null; s["held"] = null; s["sw"] = ""; s["sw_t0"] = -99.0; s["step_t"] = -99.0; s["last_x"] = 0.0; s["count"] = true; s["set_x"] = 0.0; s["set_i"] = -1
		s["day"] = -1; s["me_t"] = -99.0; s["lifts"] = 0; s["slips"] = 0; s["fulls"] = 0; s["full_day"] = -1; s["day_fulls"] = 0
		s["near_t"] = -99.0; s["ported"] = 0; s["port_day"] = -1
		s["creak"] = _snd(node, float(kind.get("creak_hz", 320)), 0.25, 8.0, -16.0); s["thud"] = _snd(node, float(kind.get("thud_hz", 140)), 0.2, 10.0, -12.0); s["roll"] = _snd(node, float(kind.get("roll_hz", 220)), 0.35, 6.0, -14.0)
		_place(s, pile)
		s["porter"] = ClimbPorter.new(self, s, node)   # 주민 반쪽 — 틈 쪽 끝에 카메라를 보고 선 짐꾼
		piles.append(s)

## 상자 하나 — 나무 몸통(w × h × deck_d), 앞면 널 둘, 밧줄 손잡이 둘, 스텐실(강조색은 이 한 조각). 원점은 가운데
func _crate(parent: Node3D) -> Node3D:
	var nd := Node3D.new(); parent.add_child(nd)
	var wood := _mat(Color("c9a07a")); var dark := _mat(Color("6b4a35")); var rope := _mat(Color("1b0c15")); var mauve := _mat(Color("ad7096"))
	var sz := Vector3(w() * C.K, h() * C.K, deck_d() * C.K)
	_box(nd, sz, wood)
	for sd: float in [-1.0, 1.0]:
		_box(nd, Vector3(sz.x + 0.01, 0.035, 0.012), dark).position = Vector3(0.0, sd * sz.y * 0.3, sz.z / 2.0)      # 앞면 널 둘
		_box(nd, Vector3(0.02, 0.05, 0.1), rope).position = Vector3(sd * (sz.x / 2.0 + 0.01), sz.y * 0.15, 0.0)     # 밧줄 손잡이 둘 — 안는 손이 잡는 자리
	_box(nd, Vector3(0.1, 0.07, 0.012), mauve).position = Vector3(sz.x * 0.2, -sz.y * 0.05, sz.z / 2.0 + 0.002)   # 스텐실
	return nd

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

func _snd(parent: Node3D, hz: float, secs: float, decay: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs, decay); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — 짧은 기음이 잦아든다: creak(0.25초 — 밧줄 손잡이가 당겨진다)·thud(0.2초, 낮게 — 상자가 바닥에 놓인다)·roll(0.35초 — 상자가 손에서 빠져 구른다). 한 번 재생, 반복 없음
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
