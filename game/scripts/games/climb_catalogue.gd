class_name ClimbCatalogue
extends Node3D
## Climb 콘텐츠 팩 '카드 목록함'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 서재(Library) 층의 잇단 두 still 발판 사이 틈 — 아래 발판의 틈 쪽 가장자리에서 near 지나 절벽에 박힌 키 큰 카드 목록함(cab_w 폭), 아래 발판 윗면에서 step 마다 서랍 앞판이 위 발판 top_clear 밑까지 쌓여 있다(많아야 drawers 개; 탑의 발판 높이차로는 셋이나 넷).
## 아래 발판에서 목록함 앞면 reach 안에 서서, 또는 빼낸 서랍 위에 서서 C 를 누르면 바로 위 서랍을 홱 당긴다(yank): pull_s 에 걸쳐 draw_out 만큼 절벽에서 나오고 그 윗면이 발판이 된다 — 서랍이 사다리의 한 칸.
## 다 나온 뒤 hold_s 가 지나면 slide_s 에 걸쳐 저절로 들어가며 탁(clack) 닫힌다: 그 위에 선 몸은 절벽 쪽으로 실려 가다(등이 절벽에 닿으면 거기서) 서랍이 다 들어가면 더는 아무것도 딛지 않은 몸이 된다 — 밑 서랍이 아직 나와 있으면 거기로, 아니면 아래 발판이나 틈으로(로더의 맨 낙하; 밀지도 다치게 하지도 않는다).
## 한 목록함의 서랍 둘을 card_s 안에 당기면 카드 한 장이 흔들려 빠진다: 당긴 서랍의 앞 가장자리에서 card_v 로 아래 발판 위로 나부껴 떨어져 card_lie_s 눕고, 그 옆에서 C 면 집어 읽는다(text — 층과 서랍으로 cards 에서 고른 목록 카드 한 줄, 로더가 보여 준다).
## 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 서랍이 닫혀 있는 동안 틈을 건너는 맨 점프는 그대로다(앞판은 절벽에 묻혀 있고 단단한 게 없다); 빼낸 서랍은 짧은 점프를 받아 줄 뿐이다.
## 사다리(run 127 — 구르는 사다리에 올라 오른다)·덤웨이터(run 130 — 줄을 당겨 칸을 올린다)·서가(run 132 — 밀어 발판을 낮춘다)와 다르다: 이건 제가 한 칸씩 빼 쌓는 계단, 그리고 제 시계로 한 칸씩 사라지는 계단. 자세는 yank(stick3d_yank.gd — 운영자 보드의 '서랍·문 당기기' 가족).
## 로더가 할 일(climb.gd, 운영자 세션): `var cc := ClimbCatalogue.new(); add_child(cc)`; 층을 지을 때 `var lp := cl.plan(n, plats); var dp := cd.plan(n, plats); var bp := cs.plan(n, plats, lp + dp); var np := pn.plan(n, plats, lp + dp + bp); var sp := sc.plan(n, plats, lp + dp + bp + np); cc.build(root, cc.plan(n, plats, lp + dp + bp + np + sp))` (사다리·덤웨이터·서가·파터노스터·두루마리 선반의 계획을 taken 으로 — 그 자리는 비켜 간다); 매 틱 `cc.sync(_t)`;
## 발판에 선 가지에서 act 가 막 눌렸으면(`Input.is_action_just_pressed("act")`) `var r := cc.yank(on, x, z, face, true, fig); if r["yanked"]: fig.pose_request = "yank"; _scene_until = now + YankPoses.YANK_T` (당기는 동안 몸은 선 자리에), `YankPoses.done(fig)` 면 자세를 비운다; 아니면 `var c := cc.take(on, x, z, true); if c["took"]: fig.pose_request = "stoop"; _scene_until = now + 0.4; _say(c["text"])` (목록함·카드 밖에선 C 는 로더의 것 — 판 읽기·쉼터 문);
## 로더 자신의 착지 판정이 비면 `landed = cc.land(x, y, ny, z)` (kind "drawer" — 빼낸 서랍의 윗면);
## `on["kind"] == "drawer"` 인 매 틱, 'move' 발판 자리에서: `var r := cc.stand(on, x, z, dt); y = r["y"]; z = r["z"]; if r["off"]: on = {}; apex = y` — 들어가는 서랍이 몸을 절벽 쪽으로 싣고, 다 들어가면 off 라 맨 낙하가 된다(로더 자신의 x 떠남 판정은 그대로 둬도 좋다 — on["x"]·on["w"] 는 목록함 자리).
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_catalogue.gd

const PACK := "res://data/climb/catalogue.json"
const C = preload("res://scripts/games/climb.gd")
const TAKEN_UP := 220.0    # taken 조각 위로 비워 두는 높이(px) — 제 꼭대기(rail_y·beam_y·y_top)가 더 높으면 그것
const BODY_UP := 50.0      # 서랍 위에 선 몸의 키(px) — 상자 위쪽 여유
const FRAME_D := 6.0       # 목록함 틀의 두께(px) — 절벽 면에 묻힌다
const CARD_W := 10.0       # 카드(px)
const CARD_D := 14.0

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.cabinet
var cards_txt: Array = []       # 카드 글(층·서랍으로 고른다)
var cabs: Array = []            # 지은 목록함 {id, kind "catalogue", n, x, w, y, y_top, z, d, dir, gap, hinge_x, near_x, far_x, a_id, b_id, a_y, b_y, nd, drawers [{id, i, top, t_pull, clacked, z_front, slot}], last_pull, card {state, t0, t_lie, x, y0, text}, node, card_node, yank_snd, clack_snd, flutter_snd}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("cabinet", {})
	cards_txt = pack.get("cards", ["Card."])

func sync(now: float) -> void:
	t = now
	for cv in cabs:
		_settle(cv)

func near() -> float:
	return maxf(0.0, float(kind.get("near", 12.0)))

func cab_w() -> float:
	return maxf(2.0 * C.HW, float(kind.get("cab_w", 48.0)))

func step() -> float:
	return maxf(8.0, float(kind.get("step", 24.0)))

func draw_h() -> float:
	return clampf(float(kind.get("draw_h", 18.0)), 4.0, step() - 2.0)

func draw_out() -> float:
	return maxf(2.0 * C.HZ, float(kind.get("draw_out", 40.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 18.0)))

func pull_s() -> float:
	return maxf(0.05, float(kind.get("pull_s", 0.3)))

func hold_s() -> float:
	return maxf(0.0, float(kind.get("hold_s", 3.0)))

func slide_s() -> float:
	return maxf(0.05, float(kind.get("slide_s", 0.5)))

func card_s() -> float:
	return maxf(0.0, float(kind.get("card_s", 1.0)))

func card_v() -> float:
	return maxf(1.0, float(kind.get("card_v", 60.0)))

func card_lie_s() -> float:
	return maxf(0.0, float(kind.get("card_lie_s", 12.0)))

## 서랍이 나온 정도 0..1 — at 때. 당긴 뒤 pull_s 에 1 로, hold_s 머물고, slide_s 에 걸쳐 0 으로
func k_at(d: Dictionary, at: float) -> float:
	var tp := float(d["t_pull"])
	if tp < 0.0: return 0.0
	var u := at - tp
	if u < 0.0: return 0.0
	if u < pull_s(): return u / pull_s()
	if u < pull_s() + hold_s(): return 1.0
	return maxf(0.0, 1.0 - (u - pull_s() - hold_s()) / slide_s())

## 지금 서랍의 형편 — "shut"(절벽에 묻혀 있다)·"pulling"(나오는 중)·"open"(다 나와 있다)·"sliding"(들어가는 중)
func phase(d: Dictionary, at: float) -> String:
	var tp := float(d["t_pull"])
	if tp < 0.0: return "shut"
	var u := at - tp
	if u < 0.0: return "shut"
	if u < pull_s(): return "pulling"
	if u < pull_s() + hold_s(): return "open"
	return "sliding" if u < pull_s() + hold_s() + slide_s() else "shut"

## 서랍 앞면의 z(px) — 절벽 면 WALL_Z 에서 나온 만큼
func z_front(d: Dictionary, at: float) -> float:
	return C.WALL_Z + draw_out() * k_at(d, at)

## 시계가 넘긴 고비를 적는다 — 다 들어간 서랍의 탁 소리와 닫힘, 카드의 착지와 치움
func _settle(c: Dictionary) -> void:
	for dv in (c["drawers"] as Array):
		var d: Dictionary = dv
		if float(d["t_pull"]) >= 0.0 and phase(d, t) == "shut":
			d["t_pull"] = -9.0
			if not bool(d["clacked"]): d["clacked"] = true; _play(c["clack_snd"])
	var card: Dictionary = c["card"]
	if String(card["state"]) == "falling" and _card_y(c, t) <= float(c["a_y"]) + 0.001:
		card["state"] = "lying"; card["t_lie"] = float(card["t0"]) + (float(card["y0"]) - float(c["a_y"])) / card_v()
	if String(card["state"]) == "lying" and t >= float(card["t_lie"]) + card_lie_s(): card["state"] = "none"

## 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	cabs = cabs.filter(func(c: Dictionary) -> bool: return is_instance_valid(c["node"]))   # 지운 층의 것은 뺀다(climb_scroll 과 같은 식)
	for cv in cabs:
		_settle(cv)
		_place(cv)

## 층 n(테마 층만)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 min_dy..max_dy 높으며 목록함 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var min_gap := maxf(near() + cab_w(), float(kind.get("min_gap", 70.0))); var max_gap := float(kind.get("max_gap", 220.0))
	var min_dy := float(kind.get("min_dy", 40.0)); var max_dy := float(kind.get("max_dy", 150.0))
	var top_clear := float(kind.get("top_clear", 20.0)); var most := maxi(1, int(kind.get("drawers", 6)))
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
			var nd := mini(most, floori((dy - top_clear) / step()))
			if nd < 1: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0   # 아래 발판에서 위 발판 쪽
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			if float(a["w"]) < 2.0 * C.HW + 4.0: continue
			var hinge := ax1 if dir > 0.0 else ax0
			var nx := hinge + dir * near(); var fx := nx + dir * cab_w()
			var x0 := minf(nx, fx) - 4.0; var x1 := maxf(nx, fx) + 4.0
			var yhi := float(a["y"]) + step() * nd + BODY_UP
			if not _clear(plats, a, b, x0, x1, float(a["y"]) + 1.0, yhi): continue
			if not _free(taken, x0, x1, float(a["y"]) + 1.0, yhi): continue
			found.append({ "gap": gap, "dir": dir, "hinge_x": hinge, "near_x": nx, "far_x": fx, "nd": nd,
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.C%d" % [n, i]; s["kind"] = "catalogue"; s["n"] = n; s["x"] = minf(float(g["near_x"]), float(g["far_x"])); s["w"] = cab_w(); s["y"] = float(g["a_y"])
			s["y_top"] = float(g["a_y"]) + step() * int(g["nd"]) + draw_h(); s["z"] = C.WALL_Z + draw_out() / 2.0; s["d"] = draw_out()
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 목록함 상자(폭 ± 손 하나, 아래 발판 윗면..맨 위 서랍에 선 몸)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x·w·y, 있으면 rail_y·beam_y·y_top)이 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지, 제 꼭대기가 더 높으면 거기 + 60 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - 10.0; var qy1 := qy + TAKEN_UP
		for key in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qy1 = maxf(qy1, float(q[key]) + 60.0)
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## C 를 누른 틱 — 아래 발판에서 앞면 reach 안이면 첫 서랍, 빼낸 서랍 위면 바로 위 서랍을 당긴다(닫혀 있을 때만; 나오는·나온·들어가는 서랍은 그대로): {yanked, side, card, drawer}. side 는 절벽이 있는 팔 쪽(+1: 오른쪽을 보는 몸의 local +x) — fig 에 메타 yank_side 로 적는다. card 는 이 홱이 카드를 떨어뜨렸나
func yank(on: Dictionary, x: float, z: float, face: float, pressed: bool, fig: Stick3D = null) -> Dictionary:
	var none := { "yanked": false, "side": 1.0, "card": false, "drawer": "" }
	if not pressed: return none
	var got := _at(on, x, z)
	if got.is_empty(): return none
	var c: Dictionary = got["cab"]; var d: Dictionary = (c["drawers"] as Array)[int(got["i"]) - 1]
	if phase(d, t) != "shut": return none
	d["t_pull"] = t; d["clacked"] = false; d["z_front"] = C.WALL_Z
	_play(c["yank_snd"])
	var card := false
	var cd: Dictionary = c["card"]
	if t - float(c["last_pull"]) <= card_s() and String(cd["state"]) == "none":
		card = true
		cd["state"] = "falling"; cd["t0"] = t; cd["y0"] = float(d["top"]); cd["x"] = float(c["near_x"]) - float(c["dir"]) * (C.HW + 6.0)
		cd["text"] = "Drawer %d · %s" % [int(d["i"]), String(cards_txt[(int(c["n"]) + int(d["i"])) % cards_txt.size()])]
		_play(c["flutter_snd"])
	c["last_pull"] = t
	var side := 1.0 if face >= 0.0 else -1.0
	if fig: fig.set_meta("yank_side", side)
	return { "yanked": true, "side": side, "card": card, "drawer": String(d["id"]) }

## 몸이 당길 수 있는 서랍 — {cab, i}(1부터) 또는 빈 사전: 아래 발판 위에서 앞면 HW + reach 안이면 1, 서랍 i 위면 i + 1(있으면). 걷는 깊이여야 한다
func _at(on: Dictionary, x: float, z: float) -> Dictionary:
	var oid := String(on.get("id", ""))
	for cv in cabs:
		var c: Dictionary = cv
		if absf(z - float(c["z"])) >= draw_out() / 2.0 + C.HZ: continue
		if oid == String(c["a_id"]) and absf(x - float(c["near_x"])) <= C.HW + reach(): return { "cab": c, "i": 1 }
		if String(on.get("kind", "")) == "drawer":
			for dv in (c["drawers"] as Array):
				var d: Dictionary = dv
				if String(d["id"]) == oid and int(d["i"]) < int(c["nd"]): return { "cab": c, "i": int(d["i"]) + 1 }
	return {}

## 로더 자신의 착지 판정이 빈 뒤 — 나와 있는(open·sliding) 서랍의 윗면을 떨어지는 몸이 지나면 올라선다: {kind "drawer", id, cab, x, y, w, z, d}. 닫힌·나오는 서랍은 발판이 아니다
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	for cv in cabs:
		var c: Dictionary = cv
		if x + C.HW <= float(c["x"]) or x - C.HW >= float(c["x"]) + float(c["w"]): continue
		for dv in (c["drawers"] as Array):
			var d: Dictionary = dv
			var ph := phase(d, t)
			if ph != "open" and ph != "sliding": continue
			var top := float(d["top"])
			if y < top - 0.5 or ny > top: continue
			var out := draw_out() * k_at(d, t); var zc := C.WALL_Z + out / 2.0
			if absf(z - zc) >= out / 2.0 + C.HZ: continue
			d["z_front"] = C.WALL_Z + out
			return { "kind": "drawer", "id": String(d["id"]), "cab": String(c["id"]), "x": float(c["x"]), "y": top, "w": float(c["w"]), "z": zc, "d": out }
	return {}

## 서랍 위에 선 매 틱 — {x, y, z, off}: 나와 있으면 그대로; 들어가는 동안 몸이 절벽 쪽으로 실려 간다(등이 절벽에 닿으면 거기서); 다 들어가면 off(로더가 on 을 비워 맨 낙하)
func stand(on: Dictionary, x: float, z: float, _dt: float) -> Dictionary:
	var d := _drawer(String(on.get("id", "")))
	if d.is_empty(): return { "x": x, "y": float(on.get("y", 0.0)), "z": z, "off": true }
	var ph := phase(d, t)
	if ph != "open" and ph != "sliding": return { "x": x, "y": float(d["top"]), "z": z, "off": true }
	var zf := z_front(d, t)
	var nz := z
	if ph == "sliding": nz = maxf(z + zf - float(d["z_front"]), C.WALL_Z + C.HZ)
	d["z_front"] = zf
	return { "x": x, "y": float(d["top"]), "z": nz, "off": zf <= nz - C.HZ }

## C 를 누른 틱 — 아래 발판 위에서 누운 카드 HW + reach 안이면 집어 읽는다: {took, text}. 날고 있는 카드·없는 카드는 아니다
func take(on: Dictionary, x: float, z: float, pressed: bool) -> Dictionary:
	if not pressed: return { "took": false, "text": "" }
	for cv in cabs:
		var c: Dictionary = cv; var cd: Dictionary = c["card"]
		if String(cd["state"]) != "lying" or String(on.get("id", "")) != String(c["a_id"]): continue
		if absf(z - float(c["z"])) >= draw_out() / 2.0 + C.HZ: continue
		if absf(x - float(cd["x"])) > C.HW + reach(): continue
		cd["state"] = "none"; c["cards_taken"] = int(c.get("cards_taken", 0)) + 1
		return { "took": true, "text": String(cd["text"]) }
	return { "took": false, "text": "" }

## 카드의 높이(px) — at 때: 당긴 서랍의 윗면에서 card_v 로 내려와 아래 발판 윗면에 눕는다
func _card_y(c: Dictionary, at: float) -> float:
	var cd: Dictionary = c["card"]
	return maxf(float(c["a_y"]), float(cd["y0"]) - card_v() * (at - float(cd["t0"])))

func _drawer(id: String) -> Dictionary:
	for cv in cabs:
		for dv in ((cv as Dictionary)["drawers"] as Array):
			if String((dv as Dictionary)["id"]) == id: return dv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 목록함을 짓는다 — root 는 그 층의 노드. 노드 원점은 (목록함의 낮은 x 끝, 아래 발판 윗면, 절벽 면); 틀(절벽에 묻힘), 서랍마다 slot(앞판·손잡이·라벨 — _place 가 z 로 밀어 낸다), 카드(장·먹선), yank·clack·flutter 소리
func build(root: Node3D, planned: Array) -> void:
	var cw := cab_w() * C.K; var dh := draw_h() * C.K; var dout := draw_out() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var nd := int(s["nd"])
		var node := Node3D.new(); node.position = C.to3(float(s["x"]), float(s["a_y"]), C.WALL_Z * C.K); root.add_child(node)
		var frame := _mat(Color("6b4a35")); var front := _mat(Color("c9a07a")); var brass := _mat(Color("b08d57")); var paper := _mat(Color("efe9e2")); var ink := _mat(Color("3a2a24")); var tab := _mat(Color("ad7096"))
		var fh := (step() * nd + draw_h() + 8.0) * C.K
		_box(node, Vector3(cw + 8.0 * C.K, fh, FRAME_D * C.K), frame).position = Vector3(cw / 2.0, fh / 2.0, -FRAME_D * C.K / 2.0)   # 틀 — 절벽 면에 묻힌다
		var drawers: Array = []
		for i in range(1, nd + 1):
			var top := float(s["a_y"]) + step() * i
			var slot := Node3D.new(); slot.position = Vector3(cw / 2.0, (top - float(s["a_y"])) * C.K - dh / 2.0, 0.0); node.add_child(slot)
			_box(slot, Vector3(cw - 8.0 * C.K, dh - 4.0 * C.K, dout), front).position = Vector3(0.0, 0.0, -dout / 2.0)   # 앞판과 몸통 — 닫히면 절벽 속
			_box(slot, Vector3(6.0 * C.K, 2.0 * C.K, 2.0 * C.K), brass).position = Vector3(0.0, -dh * 0.2, 1.0 * C.K)        # 손잡이
			var label := _box(slot, Vector3(10.0 * C.K, 6.0 * C.K, 1.0 * C.K), paper); label.position = Vector3(0.0, dh * 0.2, 0.5 * C.K)   # 라벨
			_box(label, Vector3(10.0 * C.K, 1.0 * C.K, 1.2 * C.K), tab).position = Vector3(0.0, 2.5 * C.K, 0.0)                                # 라벨의 띠 — 강조색만
			drawers.append({ "id": "%s.d%d" % [String(s["id"]), i], "i": i, "top": top, "t_pull": -9.0, "clacked": true, "z_front": C.WALL_Z, "slot": slot })
		var card_node := Node3D.new(); card_node.visible = false; node.add_child(card_node)
		_box(card_node, Vector3(CARD_W * C.K, 0.5 * C.K, CARD_D * C.K), paper)
		_box(card_node, Vector3(6.0 * C.K, 0.6 * C.K, 1.0 * C.K), ink).position = Vector3(0.0, 0.0, -CARD_D * C.K * 0.2)   # 먹선 한 줄
		var yank_snd := _snd(node, float(kind.get("yank_hz", 420)), 0.12, -14.0); var clack_snd := _snd(node, float(kind.get("clack_hz", 150)), 0.08, -8.0); var flutter_snd := _snd(node, float(kind.get("flutter_hz", 1400)), 0.15, -18.0)
		s["drawers"] = drawers; s["last_pull"] = -9.0; s["cards_taken"] = 0
		s["card"] = { "state": "none", "t0": -9.0, "t_lie": -9.0, "x": 0.0, "y0": 0.0, "text": "" }
		s["node"] = node; s["card_node"] = card_node; s["yank_snd"] = yank_snd; s["clack_snd"] = clack_snd; s["flutter_snd"] = flutter_snd
		cabs.append(s)
		_place(s)

## 서랍을 나온 만큼 밀어 내고, 카드는 나부껴 내려오다 눕는다
func _place(c: Dictionary) -> void:
	for dv in (c["drawers"] as Array):
		var d: Dictionary = dv
		(d["slot"] as Node3D).position.z = draw_out() * k_at(d, t) * C.K
	var cd: Dictionary = c["card"]; var cn: Node3D = c["card_node"]
	var st := String(cd["state"])
	cn.visible = st == "falling" or st == "lying"
	if not cn.visible: return
	var u := t - float(cd["t0"])
	var wob := 6.0 * sin(u * 8.0) if st == "falling" else 0.0
	cn.position = Vector3((float(cd["x"]) + wob - float(c["x"])) * C.K, (_card_y(c, t) - float(c["a_y"])) * C.K + 0.3 * C.K, (C.PLAYER_Z - C.WALL_Z) * C.K)
	cn.rotation = Vector3(0.0, 0.0, 0.4 * sin(u * 8.0 + 1.0)) if st == "falling" else Vector3.ZERO

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

## 나무 소리 — 짧은 기음이 빠르게 잦아든다: yank(0.12초, 서랍이 미끄럼대를 탄다)·clack(0.08초, 서랍이 멈춤쇠에 닿는다)·flutter(0.15초, 카드가 빠진다). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.3) * 0.2) * exp(-k * 10.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
