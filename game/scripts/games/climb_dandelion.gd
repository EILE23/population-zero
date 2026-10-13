class_name ClimbDandelion
extends Node3D
## Climb 콘텐츠 팩 '민들레 홀씨'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 바람 절벽(Wind cliffs) 층의 잇단 두 발판 사이 틈(min_gap..max_gap, 위 발판이 0..max_dy 높이; 아래 발판은 still, 위 발판은 부서지거나 튀어도 된다 — 서는 건 아래뿐) — 아래 발판의 틈 쪽 가장자리에서 stalk_off 들어간 절벽에 거대한 민들레 줄기가 뿌리내리고,
## 그 머리(아래 발판 윗면 head_up 위, 선 몸의 가슴 높이)에 홀씨 `seeds` 개가 head_r 길이로 둘러 있다. 바람 있는 층(40층부터 wind_of)은 위 발판이 바람 아래쪽인 짝만, 없는 층은 절벽의 돌풍이 위 발판 쪽으로 분다.
## 아래 발판 가장자리 reach 안에 서서 C: 분다(puff — 가슴이 오르며 어깨가 들리고 고개가 다가가는 들숨, 고개를 밀며 팔이 떨어지는 날숨, 바로 서는 회수) → blow_at 뒤 홀씨가 stagger 마다 하나씩 떠난다: 바람(또는 돌풍)의 속도로 흘러가며 rise_v 로 오르다 life_s 에 톡 터진다(pop).
## 호의 꼭대기나 떨어지는 몸(vy ≤ catch_vy)의 손(발 + hang)이 살아 있는 홀씨 catch_r 안에 오면 잡혀 매달린다(snap, 자세 kite — 머리 위 한 것을 두 손으로 쥐고 다리가 바람에 흐른다): 홀씨가 제 속도로 carry_s 동안 몸을 싣고(rise_v × carry_s = 제 호보다 30 px 높이) 터지며 제 속도로 놓는다; ↓ 는 그 속도로 먼저 놓는다.
## 빈 머리는 마지막 홀씨가 떠난 뒤 regrow_s 에 걸쳐 다시 자라고 그때까진 불어도 아무 일이 없다(bare). 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 틈을 건너는 맨 점프는 그대로(줄기는 가늘고 단단한 게 없으며 홀씨는 꼭대기나 떨어지는 몸만 잡아 보태기만 한다).
## 연(run 131 — 토글을 잡으면 줄이 끌고 간다)·풍향계(run 136 — 리본을 잡으면 화살이 돌아 싣는다)와 다르다: 이건 제 숨으로 띄운 것을 뒤따라 뛰어 잡는 몸 — 바람에 띄울 것을 제가 만드는 첫 기계. 자세는 puff(stick3d_puff.gd — 운영자 보드의 '숨·입김' 가족).
## 로더가 할 일(climb.gd, 운영자 세션): `var cd := ClimbDandelion.new(); add_child(cd)`; 층을 지을 때 `var kp := ck.plan(n, plats, wind_of(n)); cd.build(root, cd.plan(n, plats, wind_of(n), kp + cv.plan(n, plats, wind_of(n), kp)))` (연·풍향계의 계획을 taken 으로 — 한 틈을 둘이 안 나눈다); 매 틱 `cd.sync(_t)`;
## 발판에 선 가지에서 act 가 막 눌렸고(`Input.is_action_just_pressed("act")`) `cd.poised(on, x)` 면 `var b := cd.blow(on, x, fig); if b["took"]: fig.pose_request = "puff"; _scene_until = now + PuffPoses.BLOW_T` (부는 동안 몸은 선 자리에), `PuffPoses.done(fig)` 면 자세를 비운다 (줄기 밖에선 C 는 로더의 것 — 판 읽기·쉼터 문);
## 공중(on 이 비고 vy ≤ 60)이고 홀드·다른 팩의 잡기가 비었으면 `var g := cd.catch(x, y, z, vy); if not g.is_empty(): seeding = g; vx = 0.0; vy = 0.0; charge = 0.0; face = float(g["dir"])` (seeding 은 로더의 새 사전 — kiting 처럼);
## 매달린 매 틱(`_hold` 와 같은 자리, 맨 앞): `var r := cd.ride(seeding, fig); x = r["x"]; y = r["y"]; apex = y; fig.pose_request = "kite"; if r["done"]: var v := cd.let_go(seeding); vx = v["vx"]; vy = v["vy"]; seeding = {}; fig.pose_request = ""`;
## SPACE 를 놓으면 `var v := cd.let_go(seeding); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9 + v["vy"]; vx = dir * RUN * 0.9 + v["vx"]; seeding = {}; 자세 ""`; ↓ 면 `vx = v["vx"]; vy = v["vy"]; seeding = {}`.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_dandelion.gd

const PACK := "res://data/climb/dandelion.json"
const C = preload("res://scripts/games/climb.gd")
const TAKEN_UP := 220.0    # taken 조각(연·풍향계: 발 자리부터 꼭대기까지) 위로 비워 두는 높이(px) — 제 꼭대기(len·y_top)가 더 높으면 그것
const BODY_UP := 50.0      # 홀씨에 매달린 몸의 키(px) — 상자 위쪽 여유
const NEVER := 1.0e9       # 안 터지는 홀씨의 터질 시각
const LEAVES := 3

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.dandelion
var heads: Array = []           # 지은 민들레 {id, kind "dandelion", x, y, w, z, d, y_top, dir, gap, dy, a_edge, b_edge, a_y, b_y, a_id, b_id, stalk_x, head_y, v, wind, node, head, tufts, flights, puff, pop, snap, last, count, cat, popped}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("dandelion", {})

func sync(now: float) -> void:
	t = now
	for sv in heads:
		_pops(sv)

func stalk_off() -> float:
	return maxf(0.0, float(kind.get("stalk_off", 20.0)))

func head_up() -> float:
	return maxf(0.0, float(kind.get("head_up", 24.0)))

func head_r() -> float:
	return maxf(4.0, float(kind.get("head_r", 22.0)))

func seeds() -> int:
	return maxi(1, int(kind.get("seeds", 8)))

func root_d() -> float:
	return maxf(0.0, float(kind.get("root_d", 30.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 44.0)))

func blow_at() -> float:
	return maxf(0.0, float(kind.get("blow_at", 0.5)))

func stagger() -> float:
	return maxf(0.0, float(kind.get("stagger", 0.2)))

func rise_v() -> float:
	return float(kind.get("rise_v", 20.0))

func life_s() -> float:
	return maxf(0.1, float(kind.get("life_s", 3.0)))

func hang() -> float:
	return float(kind.get("hang", 58.0))

func catch_r() -> float:
	return maxf(0.0, float(kind.get("catch_r", 26.0)))

func catch_vy() -> float:
	return float(kind.get("catch_vy", 60.0))

func carry_s() -> float:
	return maxf(0.0, float(kind.get("carry_s", 1.5)))

func regrow_s() -> float:
	return maxf(0.1, float(kind.get("regrow_s", 12.0)))

func deck_d() -> float:
	return maxf(2.0, float(kind.get("deck_d", 28.0)))

## 이 층의 바람에서 홀씨가 흘러가는 속도 px/s — 바람이 없으면 절벽의 돌풍 gust_v, 있으면 |바람| × wind_k 를 max_v 로 막는다
func speed_for(wind: float) -> float:
	if wind == 0.0: return float(kind.get("gust_v", 120.0))
	return minf(float(kind.get("max_v", 240.0)), absf(wind) * float(kind.get("wind_k", 1.0)))

## 홀씨 i 가 떠나는 시각 — 분 적이 없으면 NEVER
func launch_at(s: Dictionary, i: int) -> float:
	var last := float(s["last"])
	return NEVER if last < 0.0 else last + blow_at() + stagger() * float(i)

## 홀씨 i 가 터지는 시각 — 제 수명이 다하거나, 잡혔으면 잡힌 뒤 carry_s
func pop_at(s: Dictionary, i: int) -> float:
	var la := launch_at(s, i)
	if la >= NEVER: return NEVER
	var cat := float((s["cat"] as Array)[i])
	return minf(la + life_s(), cat + carry_s()) if cat >= 0.0 else la + life_s()

## 홀씨 i 의 at 시각 자리(px) — 떠난 뒤 k 초: 머리에서 바람 쪽으로 v·k, 위로 rise_v·k (떠나기 전이나 터진 뒤는 묻지 말 것 — seed_at 이 가린다)
func seed_pos(s: Dictionary, i: int, at: float) -> Vector2:
	var k := maxf(0.0, at - launch_at(s, i))
	return Vector2(float(s["stalk_x"]) + float(s["dir"]) * float(s["v"]) * k, float(s["head_y"]) + rise_v() * k)

## 홀씨 i 가 at 시각에 공중에 있으면 {x, y, k}, 아직 머리에 있거나 터졌으면 빈 사전
func seed_at(s: Dictionary, i: int, at: float) -> Dictionary:
	var la := launch_at(s, i)
	if at < la or at >= pop_at(s, i): return {}
	var p := seed_pos(s, i, at)
	return { "x": p.x, "y": p.y, "k": at - la }

## 마지막 홀씨가 떠난 시각 — 그때부터 머리가 다시 자란다
func gone_at(s: Dictionary) -> float:
	return launch_at(s, seeds() - 1)

## 머리가 다시 자란 몫 0..1 — 분 적이 없으면 1, 홀씨가 아직 떠나는 중이면 0
func grow_k(s: Dictionary) -> float:
	if float(s["last"]) < 0.0: return 1.0
	return clampf((t - gone_at(s)) / regrow_s(), 0.0, 1.0)

## 홀씨 i 가 머리에 붙은 크기 0..1 — 아직 안 떠났으면 1, 떠났으면 다시 자란 만큼
func tuft_k(s: Dictionary, i: int) -> float:
	return 1.0 if t < launch_at(s, i) else grow_k(s)

## 불 수 있는 머리인가 — 분 적이 없거나 다 자랐다
func full(s: Dictionary) -> bool:
	return grow_k(s) >= 1.0

## 터진 홀씨의 소리 — 한 번씩
func _pops(s: Dictionary) -> void:
	var popped: Array = s["popped"]
	for i in seeds():
		if bool(popped[i]) or t < pop_at(s, i): continue
		popped[i] = true
		_play(s["pop"] as AudioStreamPlayer3D)

## 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	heads = heads.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_bellows 와 같은 식)
	for sv in heads:
		var s: Dictionary = sv
		_pops(s)
		_place(s)

## 층 n(테마 층)의 잇단 두 발판(조각의 on·to; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 0..max_dy 높으며 바람 아래쪽에 있고(wind 0 이면 어느 쪽이든) 줄기·홀씨의 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나. 같은 층·같은 바람·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, wind: float = 0.0, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := float(kind.get("min_gap", 70.0)); var max_gap := float(kind.get("max_gap", 240.0)); var max_dy := float(kind.get("max_dy", 160.0))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
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
			if wind != 0.0 and signf(wind) != dir: continue   # 바람을 거슬러선 홀씨가 못 간다
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var a_edge := ax1 if dir > 0.0 else ax0; var b_edge := bx0 if dir > 0.0 else bx1
			var x0 := minf(a_edge, b_edge) - C.HW; var x1 := maxf(a_edge, b_edge) + C.HW
			var ylo := float(a["y"]) - root_d() + 1.0; var yhi := maxf(float(a["y"]), float(b["y"])) + rise_v() * life_s() + BODY_UP
			if not _clear(plats, a, b, x0, x1, ylo, yhi): continue
			if not _free(taken, x0, x1, ylo, yhi): continue
			found.append({ "gap": gap, "dy": dy, "dir": dir, "a_edge": a_edge, "b_edge": b_edge, "stalk_x": a_edge + dir * stalk_off(), "head_y": float(a["y"]) + head_up(),
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.D%d" % [n, i]; s["kind"] = "dandelion"; s["x"] = float(g["stalk_x"]) - head_r(); s["w"] = head_r() * 2.0; s["y"] = float(g["a_y"]); s["y_top"] = float(g["head_y"]) + head_r()
			s["z"] = C.PLAYER_Z; s["d"] = deck_d(); s["v"] = speed_for(wind); s["wind"] = wind
			out.append(s)
	return out

## 줄기·홀씨의 상자(두 발판의 틈 쪽 가장자리 사이, 뿌리..높은 발판 위 홀씨의 길과 몸)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x·w·y, 있으면 len·y_top)이 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지, 제 꼭대기가 더 높으면 거기까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - 10.0; var qy1 := qy + TAKEN_UP
		if q.has("len"): qy1 = maxf(qy1, qy + float(q["len"]) + 10.0)
		if q.has("y_top"): qy1 = maxf(qy1, float(q["y_top"]) + 60.0)
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 줄기 앞에 선 몸인가 — 아래 발판 위, 틈 쪽 가장자리에서 reach 안; 거기선 C 가 민들레의 것
func poised(on: Dictionary, x: float) -> bool:
	for sv in heads:
		var s: Dictionary = sv
		if String(on.get("id", "")) != String(s["a_id"]): continue
		var u := float(s["dir"]) * (float(s["a_edge"]) - x)   # 가장자리에서 발판 안쪽으로 잰 거리
		return u >= 0.0 and u <= reach()
	return false

## C 한 번 — {took, seeds, bare}: 줄기 앞이 아니면 took 거짓(C 는 로더의 것). 머리가 비어 자라는 중이면 took 거짓·bare 참(아무 일도 없다). 아니면 분다(puff): 홀씨가 blow_at 뒤 stagger 마다 떠난다
func blow(on: Dictionary, x: float, fig: Stick3D = null) -> Dictionary:
	if not poised(on, x): return { "took": false, "seeds": 0, "bare": false }
	var s := _find_a(String(on.get("id", "")))
	if not full(s): return { "took": false, "seeds": 0, "bare": true }
	s["last"] = t; s["count"] = int(s["count"]) + 1
	var cat: Array = s["cat"]; var popped: Array = s["popped"]
	for i in seeds():
		cat[i] = -1.0; popped[i] = false
	_play(s["puff"] as AudioStreamPlayer3D)
	if fig and fig.has_meta("puff_t"): fig.remove_meta("puff_t")   # 자세의 시계는 pose_t — 시연용 메타가 남아 있으면 지운다
	return { "took": true, "seeds": seeds(), "bare": false }

## 공중의 몸 — 꼭대기나 떨어지는 몸(vy ≤ catch_vy)의 손(발 + hang)이 살아 있고 아직 안 잡힌 홀씨 catch_r 안이면 잡는다(snap): 돌려주는 사전의 x·y 가 몸의 자리(홀씨 밑 hang), seed 가 홀씨 번호, dir 이 흘러가는 쪽. 아니면 빈 사전
func catch(x: float, y: float, z: float, vy: float) -> Dictionary:
	if vy > catch_vy(): return {}
	var r := catch_r(); var hy := y + hang()
	for sv in heads:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= deck_d() / 2.0 + C.HZ: continue
		var cat: Array = s["cat"]
		for i in seeds():
			if float(cat[i]) >= 0.0: continue
			var p := seed_at(s, i, t)
			if p.is_empty(): continue
			if absf(x - float(p["x"])) < r and absf(hy - float(p["y"])) < r:
				cat[i] = t
				_play(s["snap"] as AudioStreamPlayer3D)
				return { "id": String(s["id"]), "kind": "dandelion", "seed": i, "x": float(p["x"]), "y": float(p["y"]) - hang(), "t0": t, "dir": float(s["dir"]) }
	return {}

## 매달린 매 틱 — {x, y, done}: 홀씨와 같이 바람 쪽으로 흘러 오르다 홀씨가 터지는 순간(carry_s 나 수명) 그 자리에서 done — 로더가 let_go 로 속도를 받는다. 모르는 민들레면 그 자리에서 done
## fig 가 있으면 kite 자세의 메타를 적는다: kite_v 흘러가는 쪽 ±1, kite_set 0(내려놓기는 없다 — 터지며 놓는다)
func ride(riding: Dictionary, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty(): return { "x": float(riding.get("x", 0.0)), "y": float(riding.get("y", 0.0)), "done": true }
	var i := int(riding.get("seed", 0)); var pop := pop_at(s, i)
	var p := seed_pos(s, i, minf(t, pop))
	if fig: fig.set_meta("kite_v", float(s["dir"])); fig.set_meta("kite_set", 0.0)
	return { "x": p.x, "y": p.y - hang(), "done": t >= pop }

## 놓는 순간 홀씨의 속도 {vx, vy} px/s — 흘러가던 만큼, 오르던 만큼 안고 간다; 홀씨는 잡힌 채로 남아 다시 잡히지 않고 제때 터진다
func let_go(riding: Dictionary) -> Dictionary:
	var s := _find(String(riding.get("id", "")))
	if s.is_empty(): return { "vx": 0.0, "vy": 0.0 }
	return { "vx": float(s["dir"]) * float(s["v"]), "vy": rise_v() }

func _find(id: String) -> Dictionary:
	for sv in heads:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _find_a(a_id: String) -> Dictionary:
	for sv in heads:
		if String((sv as Dictionary)["a_id"]) == a_id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 민들레를 짓는다 — root 는 그 층의 노드. 노드 원점은 줄기 자리(stalk_x, 아래 발판 윗면, PLAYER_Z); 뿌리 잎 셋·줄기·꽃받침·머리(홀씨 `seeds` — 줄기와 솜뭉치)·날아가는 홀씨 `seeds`(솜뭉치와 매달린 씨, 숨긴 채)·소리 셋
func build(root: Node3D, planned: Array) -> void:
	var hr := head_r() * C.K; var hu := head_up() * C.K; var rd := root_d() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var node := Node3D.new(); node.position = C.to3(float(s["stalk_x"]), float(s["a_y"]), float(s["z"]) * C.K); root.add_child(node)
		var leaf := _mat(Color("5f8a3e")); var stem := _mat(Color("8fae5a"))
		for i in LEAVES:
			var lf := _box(node, Vector3(0.26, 0.025, 0.09), leaf)   # 뿌리 잎 — 절벽에서 비스듬히
			lf.rotation.z = -0.9 + 0.9 * float(i); lf.position = Vector3(0.11 * sin(lf.rotation.z + 0.4), -rd + 0.06 + 0.03 * float(i), 0.02 * float(i))
		_cyl(node, 0.025, rd + hu, stem).position = Vector3(0.0, (hu - rd) / 2.0, 0.0)   # 줄기 — 뿌리에서 머리까지
		_ball(node, 0.07, _mat(Color("c9a24a"))).position = Vector3(0.0, hu, 0.0)        # 꽃받침
		var head := Node3D.new(); head.position = Vector3(0.0, hu, 0.0); node.add_child(head)
		var tufts: Array = []
		for i in seeds():
			var tf := Node3D.new(); tf.rotation.z = TAU * float(i) / float(seeds()) + 0.2; head.add_child(tf)
			_box(tf, Vector3(0.012, hr, 0.012), stem).position = Vector3(0.0, hr / 2.0, 0.0)
			_ball(tf, float(kind.get("tuft", 10.0)) * C.K / 2.0, _mat(Color("efe9e2"))).position = Vector3(0.0, hr, 0.0)
			tufts.append(tf)
		var flights := Node3D.new(); node.add_child(flights)
		var fl: Array = []
		for i in seeds():
			var sd := Node3D.new(); sd.visible = false; flights.add_child(sd)
			_ball(sd, float(kind.get("tuft", 10.0)) * C.K / 2.0, _mat(Color("efe9e2")))                  # 솜뭉치
			_box(sd, Vector3(0.012, 0.2, 0.012), stem).position = Vector3(0.0, -0.1, 0.0)                 # 매달린 줄기
			_box(sd, Vector3(0.04, 0.06, 0.03), _mat(Color("6b4a35"))).position = Vector3(0.0, -0.23, 0.0)   # 씨
			fl.append(sd)
		var puff := _snd(node, float(kind.get("puff_hz", 120)), 0.35, 5.0, -16.0); var pop := _snd(node, float(kind.get("pop_hz", 700)), 0.05, 14.0, -14.0); var snap := _snd(node, float(kind.get("snap_hz", 180)), 0.08, 12.0, -10.0)
		s["node"] = node; s["head"] = head; s["tufts"] = tufts; s["flights"] = fl; s["puff"] = puff; s["pop"] = pop; s["snap"] = snap
		s["last"] = -99.0; s["count"] = 0
		var cat: Array = []; var popped: Array = []
		for i in seeds():
			cat.append(-1.0); popped.append(false)
		s["cat"] = cat; s["popped"] = popped
		heads.append(s)
		_place(s)

## 머리의 홀씨를 붙은 크기로, 줄기를 바람에 흔들고, 날아가는 홀씨를 지금 자리로(살아 있는 것만 보인다, 조금 흔들리며)
func _place(s: Dictionary) -> void:
	var head: Node3D = s["head"]; var tufts: Array = s["tufts"]; var fl: Array = s["flights"]
	var sway := 0.06 * (1.0 + absf(float(s["wind"])) / 120.0)
	head.rotation.z = sin(t * 1.5) * sway + sin(t * 3.7) * sway * 0.3
	for i in seeds():
		var k := tuft_k(s, i)
		var tf: Node3D = tufts[i]
		tf.visible = k > 0.001; tf.scale = Vector3.ONE * maxf(0.001, k)
		var sd: Node3D = fl[i]
		var p := seed_at(s, i, t)
		sd.visible = not p.is_empty()
		if sd.visible:
			sd.position = Vector3((float(p["x"]) - float(s["stalk_x"])) * C.K + sin(t * 3.0 + float(i)) * 0.04, (float(p["y"]) - float(s["a_y"])) * C.K + sin(t * 5.0 + float(i) * 0.7) * 0.03, 0.0)
			sd.rotation.z = -float(s["dir"]) * 0.25 + sin(t * 4.0 + float(i)) * 0.1   # 바람 쪽으로 기운 채 까딱인다

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
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = maxf(0.02, h); cm.radial_segments = 8; mi.mesh = cm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi); return mi

func _ball(parent: Node3D, r: float, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 8; sm.rings = 4; mi.mesh = sm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi); return mi

## 소리 — 짧은 기음이 잦아든다: puff(0.35초, 낮고 부드럽게 — 입김)·pop(0.05초, 높고 메마르게 — 홀씨가 터진다)·snap(0.08초 — 손이 홀씨를 잡는다). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float, decay: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.3) * 0.2 + sin(ph * 5.7) * 0.08) * exp(-k * decay)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
