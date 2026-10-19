class_name ClimbJavelin
extends Node3D
## Climb 콘텐츠 팩 '절벽 투창'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 바람 절벽(Wind cliffs) 층의 still std 발판 중 min_w 보다 넓고 다른 팩이 안 쓴 가장 넓은 것 — 던지는 쪽은 탑 가운데(dir: 가운데 왼쪽 발판은 +1, 오른쪽은 −1), 뒷끝에서 rack_in 안쪽 절벽 쪽(range_d 안, 앞길은 비어 있다)에 창 count 자루가 기대 선 받침대, 그 앞 range_dx·위 range_dy 의 절벽에 짚 고리(ring_r).
## 받침대 곁(HW + reach)에서 C: 창을 뽑아 든다 — 당김(draw_s: 던지는 팔이 어깨 뒤로 곧게, 다른 팔은 고리를 가리킨다), C 를 쥐는 동안 모은다(charge_s 에 가득 — 점프의 CHARGE 와 같은 시계), 놓으면 던진다: release_s 뒤 창이 손(hand_dx 앞, hand_dy 위)을 떠나 loft_deg 로 v_min + (v_max − v_min) × 모은 만큼 날고(층의 바람에 몸처럼 밀린다), 몸은 swing_s 에 풀린다. 그동안 busy(걷기·점프 없음).
## 길이 빈 고리의 ring_r 안을 지나는 창은 꽂힌다: 촉은 고리에, 자루는 던진 쪽으로 수평 — 그 자루가 고리 높이의 len 폭 발판이다(로더의 land/holds). 거기서 다음다음 발판은 맨 점프. stay_s 가 지나면 고리가 놓아 창이 떨어진다.
## 발판에 내린 창은 눕고(clatter), 발판 아래 lose_dy 나 탑 밖으로 간 창은 잃는다(먼지) — 둘 다 back_s 뒤 받침대로 돌아온다. 고리를 맞힌 것은 탑의 하루(day_s)에 한 번 센다 — 쉼터 판이 note(n) 으로 읽는다('Javelin range, floors 20–24: 1 of 2 rings hit today, 7 throws today.').
## 자세는 hurl(stick3d_hurl.gd — 운영자 보드의 '투창' 가족: 던지는 팔을 어깨 뒤로 곧게 뻗고 다른 팔로 고리를 가리키는 당김 → 굽힌 뒷다리에 앉으며 가슴이 열리고 팔이 떠는 모으기 → 머리 위로 휘두르고 다른 팔은 허리에 막는 던짐 → 뒷다리가 앞으로 나오고 눈이 창을 쫓는 따라감 → 섬 — 정지화가 아니다). 던지는 이는 dir 쪽을 본다(로더의 평이한 face 가지 — throwing(fig) 이 dir 을 준다).
## 받침대 곁에서 C 를 누르지 않는 몸에겐 아무것도 바뀌지 않는다: 발판을 달려 지나는 길, 맨 점프, 다른 데서의 C(쉼터 문·판)는 그대로(평이한 결과 100%). 빈 받침대 곁 C 도 아무것도 아니다. 받침대·고리·창은 꽂힌 자루 말고는 단단하지 않고 값도 없다.
## 구름 그린(공을 보내 홀에 넣는다)·높이뛰기 바(제 몸이 넘는다)·연(바람에 매달린다)과 다르다: 이건 몸이 보낸 것이 몸의 발판이 되는 첫 조각 — 바람 절벽의 여섯 조각은 다 바람을 타거나 몸이 넘는 것이었다, 던져 꽂는 건 처음.
## 로더가 할 일(climb.gd, 운영자 세션): `var cj := ClimbJavelin.new(); add_child(cj); signs.notes.append(cj.note)`; 층을 지을 때 `var kp := ck.plan(n, plats, wind_of(n)); var hop_top := cu.plan(n, plats) + ci.plan(n, plats) + kp; var hp := ch.plan(n, plats, hop_top); var dp := cd.plan(n, plats, wind_of(n), kp + cv.plan(n, plats, wind_of(n), kp)); var bp := cb.plan(n, plats, wind_of(n), hop_top + hp + dp); cj.build(root, cj.plan(n, plats, wind_of(n), hop_top + hp + dp + bp))`
## (통풍구·고드름·연·허들·높이뛰기 바·민들레의 계획을 taken 으로 — 받침대 자리·고리 띠를 둘이 안 나눈다; plan 은 plats 를 창의 착지용으로 품는다); 매 틱 `cj.sync(_t)`;
## 발판에 선 가지에서(매달림·붙잡음이 비고 `on` 이 찼을 때, jump_held 를 읽기 전에) `var jv := cj.throw(x, z, on, Input.is_action_pressed("act"), fig); if jv["busy"]: dir = 0.0; jump_held = false; charge = 0.0; fig.pose_request = "hurl" elif fig.pose_request == "hurl": fig.pose_request = ""`
## (팩이 meta hurl_d·hurl_c·hurl_t 를 적고 swing_s 에 지운다); `_figure()` 의 face 가지 앞에 `var jd := cj.throwing(fig); if jd != 0.0: fig.face(PI / 2.0 if jd > 0.0 else -PI / 2.0)`; 공중에선 부르지 않는다. 쉼터 판 C 는 signs.tick 이 먼저 — 받침대는 std 발판에만 선다.
## 착지: 로더의 착지 판정이 비면 `var jl := cj.land(x, y, ny, z); if not jl.is_empty(): landed = jl`; 선 매 틱 `if String(on.get("kind", "")) == "javelin" and not cj.holds(on): on = {}; apex = y` (고리가 놓았다 — 몸은 그냥 떨어진다, 빌린 자세 없음).
## throw 의 count: 비우면 플레이어(판에 세고 me_t 를 적는다 — 다음 조각의 주민 반쪽이 따라 던진다), 다른 몸은 거짓을 준다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_javelin.gd

const PACK := "res://data/climb/javelin.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_LO := 20.0       # taken 조각이 이 발판의 것인가: y 가 윗면 − BAND_LO 부터 + BAND_HI 앞까지(run 152 의 띠 규칙)
const BAND_HI := 60.0
const BODY_UP := 50.0       # 선 몸의 키(px) — 고리 위 여유
const SIDE := 10.0          # 자리의 x 여유(px) — 손 하나
const CORRIDOR_IN := 30.0   # 받침대 가운데에서 비행 복도가 시작하는 거리(px) — 손을 떠난 뒤부터
const CORRIDOR_UP := 60.0   # 발판 윗면에서 복도가 시작하는 높이(px) — 손(hand_dy)보다 위
const SWINGING := ["draw", "charge", "throw"]
const RACK_LEAN := 1.25     # 받침대에 기댄 창의 각(rad, 수평에서)

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.range
var ranges: Array = []          # 지은 투창장 {id, kind "range", n, hop_id, hop_w, hop_x, y, dir, wx, rx, ry, x, w, y_top, z, d, wind, need, plats, node, rack, ring_node, javs, jav, sw, sw_t0, sw_fig, c, thrown, count, throws, day, hits, me_t, throw_day, day_throws, whish, thunk, clatter}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("range", {})

func sync(now: float) -> void:
	t = now

func min_w() -> float:
	return maxf(4.0 * C.HW, float(kind.get("min_w", 110.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 14.0)))

func rack_in() -> float:
	return maxf(C.HW, float(kind.get("rack_in", 26.0)))

func range_d() -> float:
	return maxf(8.0, float(kind.get("range_d", 24.0)))

func rack_n() -> int:
	return maxi(1, int(kind.get("count", 3)))

func jav_len() -> float:
	return maxf(2.0 * C.HW, float(kind.get("len", 60.0)))

func rack_h() -> float:
	return maxf(10.0, float(kind.get("rack_h", 40.0)))

func range_dx() -> float:
	return maxf(jav_len(), float(kind.get("range_dx", 120.0)))

func range_dy() -> float:
	return maxf(BODY_UP, float(kind.get("range_dy", 150.0)))

func ring_r() -> float:
	return maxf(2.0, float(kind.get("ring_r", 12.0)))

func loft() -> float:
	return deg_to_rad(clampf(float(kind.get("loft_deg", 60.0)), 20.0, 80.0))

func v_min() -> float:
	return maxf(1.0, float(kind.get("v_min", 500.0)))

func v_max() -> float:
	return maxf(v_min(), float(kind.get("v_max", 1300.0)))

func hand_dx() -> float:
	return float(kind.get("hand_dx", 12.0))

func hand_dy() -> float:
	return maxf(0.0, float(kind.get("hand_dy", 48.0)))

func draw_s() -> float:
	return maxf(0.05, float(kind.get("draw_s", 0.45)))

func charge_s() -> float:
	return maxf(0.05, float(kind.get("charge_s", 0.8)))

func release_s() -> float:
	return maxf(0.0, float(kind.get("release_s", 0.2)))

func swing_s() -> float:
	return maxf(release_s(), float(kind.get("swing_s", 0.75)))

func stay_s() -> float:
	return maxf(1.0, float(kind.get("stay_s", 12.0)))

func back_s() -> float:
	return maxf(0.05, float(kind.get("back_s", 3.0)))

func lose_dy() -> float:
	return maxf(10.0, float(kind.get("lose_dy", 300.0)))

func day_s() -> float:
	return maxf(1.0, float(kind.get("day_s", 600.0)))

## 탑의 오늘 — 로더의 시계를 day_s 로 나눈 몫
func day() -> int:
	return floori(t / day_s())

## 손에서 dx 앞, dy 위의 고리까지 loft 로 나르는 데 드는 속도(px/s, 바람 없이) — 닿지 못하는 기하(고리가 사정각 위)면 INF
func need_v(dx: float, dy: float) -> float:
	var den := 2.0 * pow(cos(loft()), 2.0) * (dx * tan(loft()) - dy)
	if dx <= 0.0 or den <= 1.0: return INF
	return sqrt(C.G * dx * dx / den)

## 고리 한가운데를 맞히는 모음 0..1(바람 없이) — 주민 반쪽이 겨눌 값
func need_k() -> float:
	return clampf((need_v(range_dx() - hand_dx(), range_dy() - hand_dy()) - v_min()) / maxf(1.0, v_max() - v_min()), 0.0, 1.0)

## 층 n(테마 층)의 still 발판(조각의 on) 중 min_w 보다 넓고, 고리가 탑 안에 들고, 비행 복도(받침대 + CORRIDOR_IN 부터 고리 바깥까지, 발판 위 CORRIDOR_UP 부터 고리 위 선 몸까지)를 다른 발판이 가르지 않고, taken 조각이 받침대 자리·고리 띠에 없는 것들 중 가장 넓은 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, wind: float = 0.0, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var kinds: Array = piece.get("on", ["std"])
		var found: Array = []
		for hv in plats:
			var p: Dictionary = hv
			if not (String(p["kind"]) in kinds): continue
			var w := float(p["w"]); var y := float(p["y"]); var hx := float(p["x"])
			if w < min_w(): continue
			var dir := 1.0 if hx + w / 2.0 < C.WORLD_W / 2.0 else -1.0   # 탑 가운데 쪽으로 던진다
			var wx := hx + rack_in() if dir > 0.0 else hx + w - rack_in()
			var rx := wx + dir * range_dx(); var ry := y + range_dy()
			if rx - ring_r() < SIDE or rx + ring_r() > C.WORLD_W - SIDE: continue
			var lo := minf(wx + dir * CORRIDOR_IN, rx) - ring_r() - SIDE; var hi := maxf(wx + dir * CORRIDOR_IN, rx) + ring_r() + SIDE
			if not _clear(plats, [p["id"]], lo, hi, y + CORRIDOR_UP, ry + BODY_UP): continue   # 비행 복도 — 다른 발판이 들면 비킨다
			if not _free(taken, wx - 12.0, wx + 12.0, y - BAND_LO, y + BAND_HI): continue    # 받침대 자리 — 허들·바·고드름 턱이 쓰는 발판이면 비킨다
			if not _free(taken, lo, hi, ry - BAND_LO, ry + BAND_HI): continue                 # 고리 띠 — 연·민들레가 든 틈이면 비킨다
			found.append({ "hop_id": String(p["id"]), "hop_w": w, "hop_x": hx, "y": y, "dir": dir, "wx": wx, "rx": rx, "ry": ry, "x": lo, "w": hi - lo })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["hop_w"]) > float(q["hop_w"]) if float(p["hop_w"]) != float(q["hop_w"]) else float(p["y"]) < float(q["y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.J%d" % [n, i]; s["kind"] = "range"; s["n"] = n; s["wind"] = wind; s["need"] = need_k()
			s["y_top"] = float(g["ry"]) + ring_r() + 4.0   # 고리 꼭대기 — 다른 팩의 _free 가 읽는 키
			s["z"] = C.WALL_Z + range_d() / 2.0; s["d"] = range_d()   # 받침대·고리·꽂힌 자루의 깊이 — 절벽에서 range_d 까지
			s["plats"] = plats   # 창의 착지용 — 복사하지 않는다(로더의 발판 사전 그대로)
			out.append(s)
	return out

## 복도 상자에 그 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
static func _clear(plats: Array, ids: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] in ids: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var amp := float(p.get("amp", 0.0))
		var px0 := float(p["x"]) - amp - 10.0; var px1 := float(p["x"]) + float(p["w"]) + amp + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: x, w, y, 있으면 len·b_y·floor·y_top·hp·beam_y·rail_y 까지)이 자리의 x 와 겹치고 높이 띠 [ylo, yhi) 에 들면 그 자리는 그 팩의 것
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0))
		var ys: Array = [qy, qy + float(q.get("len", 0.0))]
		for key: String in ["b_y", "floor", "y_top", "hp", "beam_y", "rail_y"]:
			if q.has(key): ys.append(float(q[key]))
		var qy0 := float(ys.min()); var qy1 := float(ys.max())
		if x1 > qx0 and x0 < qx1 and qy1 >= ylo and qy0 < yhi: return false
	return true

## 발판에 선 매 틱 — {busy, k, id}: 투창장 발판의 받침대 곁(HW + reach, 걷는 선)에 선 몸이 C 를 누르면(받침대에 창이 있을 때) 창을 뽑아 당기고(sw draw, meta hurl_d), draw_s 뒤 모으기(sw charge, meta hurl_c 0..1), 놓으면 던진다(sw throw, meta hurl_t 놓은 뒤 시간 — 창은 _process 가 release_s 에 띄운다); swing_s 까지 busy. k 는 모은 몫.
## 남의 던지기 중인 받침대는 기다린다(busy 거짓). 받침대에서 떠난 몸(다른 발판·먼 x)이 당기거나 모으던 중이었으면 그 창은 받침대로 돌아가고 몸은 바로 풀린다
func throw(x: float, z: float, on: Dictionary, pressed: bool, fig: Stick3D = null, count := true) -> Dictionary:
	var none := { "busy": false, "k": 0.0, "id": "" }
	var oid := String(on.get("id", ""))
	for sv in ranges:
		var s: Dictionary = sv
		if oid != String(s["hop_id"]) or absf(z - C.PLAYER_Z) >= C.HZ + 4.0 or absf(x - float(s["wx"])) > C.HW + reach(): continue
		var r := none.duplicate(); r["id"] = String(s["id"])
		if String(s["sw"]) == "":
			var j := _in_rack(s)
			if not pressed or j.is_empty(): return r
			j["st"] = "held"; s["jav"] = int(j["i"])
			s["sw"] = "draw"; s["sw_t0"] = t; s["sw_fig"] = fig; s["count"] = count; s["c"] = 0.0; s["thrown"] = false
			if fig: fig.set_meta("hurl_d", 0.0); _hand(fig, true)
			r["busy"] = true; return r
		if (s["sw_fig"] as Stick3D) != fig: return r   # 남의 던지기 — 기다린다
		var sw := String(s["sw"]); var u := t - float(s["sw_t0"])
		if sw == "draw":
			if fig: fig.set_meta("hurl_d", u)
			if u >= draw_s(): s["sw"] = "charge"; s["sw_t0"] = t; sw = "charge"; u = 0.0
		if sw == "charge":
			s["c"] = clampf(u / charge_s(), 0.0, 1.0)
			if fig: fig.set_meta("hurl_d", draw_s() + u); fig.set_meta("hurl_c", float(s["c"]))
			if not pressed:
				s["sw"] = "throw"; s["sw_t0"] = t
				if fig: fig.set_meta("hurl_t", 0.0)
		elif sw == "throw" and fig: fig.set_meta("hurl_t", u)
		r["busy"] = true; r["k"] = float(s["c"]); return r
	_drop(fig)
	return none

## 받침대의 첫 창 — 없으면 빈 사전
func _in_rack(s: Dictionary) -> Dictionary:
	for jv in (s["javs"] as Array):
		if String((jv as Dictionary)["st"]) == "rack": return jv
	return {}

## 어느 받침대에도 없는 몸 — 당기거나 모으던 중이었으면 창을 받침대에 되돌리고 푼다(던진 것은 제 때에 끝난다)
func _drop(fig: Stick3D) -> void:
	if fig == null: return
	for sv in ranges:
		var s: Dictionary = sv
		if (s["sw_fig"] as Stick3D) == fig and String(s["sw"]) in ["draw", "charge"]:
			((s["javs"] as Array)[int(s["jav"])] as Dictionary)["st"] = "rack"
			_finish(s)

## 이 몸이 어느 받침대에서든 당기고·모으고·던지는 중이면 그 투창장의 dir(±1), 아니면 0 — 로더가 그쪽을 보게 한다
func throwing(fig: Stick3D) -> float:
	for sv in ranges:
		var s: Dictionary = sv
		if String(s["sw"]) != "" and (s["sw_fig"] as Stick3D) == fig: return float(s["dir"])
	return 0.0

## 던지기에서 떠난 몸 — 자세의 메타와 손의 창을 거둔다
func leave(fig: Stick3D) -> void:
	if fig == null: return
	for key: String in ["hurl_d", "hurl_c", "hurl_t"]:
		if fig.has_meta(key): fig.remove_meta(key)
	_hand(fig, false)

func _finish(s: Dictionary) -> void:
	leave(s["sw_fig"] as Stick3D)
	s["sw"] = ""; s["sw_fig"] = null

## 오른손의 창 — 뽑을 때 쥐고 손을 떠날 때 놓는다(그림 — 손에서 팔뚝을 따라 뻗는 자루, 촉은 손 너머 0.6·len, 손잡이 끈은 손에)
func _hand(fig: Stick3D, on: bool) -> void:
	var had := fig.hand_r.get_node_or_null("jav")
	if not on:
		if had: had.name = "jav_gone"; had.queue_free()   # 이름을 먼저 바꾼다 — 같은 틱에 다시 뽑으면 죽어 가는 노드를 손의 창으로 보지 않게
		return
	if had: return
	var L := jav_len() * C.K
	var jav := Node3D.new(); jav.name = "jav"; fig.hand_r.add_child(jav)
	_box(jav, Vector3(0.016, L, 0.016), _mat(Color("d8c9a8"))).position = Vector3(0.0, 0.1 * L, 0.0)
	_box(jav, Vector3(0.024, 0.08, 0.024), _mat(Color("4a4a52"))).position = Vector3(0.0, 0.6 * L - 0.04, 0.0)
	_box(jav, Vector3(0.022, 0.05, 0.022), _mat(Color("ad7096"), true)).position = Vector3.ZERO

## n0..n1 층의 지은 투창장에서 오늘 맞힌 수·전체·오늘 던진 수 — {hit, total, throws}
func hit_today(n0: int, n1: int) -> Dictionary:
	var hit := 0; var total := 0; var throws := 0
	for sv in ranges:
		var s: Dictionary = sv
		if int(s["n"]) < n0 or int(s["n"]) > n1: continue
		total += 1
		if int(s["day"]) == day(): hit += 1
		if int(s["throw_day"]) == day(): throws += int(s["day_throws"])
	return { "hit": hit, "total": total, "throws": throws }

## 쉼터 판(n 층)에 붙는 줄 — 위 다섯 층(n..n+4)의 투창장, 없으면 아래 다섯 층(n−5..n−1), 그것도 없으면 빈 줄. climb_signs.notes 에 넣는다
func note(n: int) -> String:
	for span: Array in [[n, n + 4], [n - 5, n - 1]]:
		var v := hit_today(int(span[0]), int(span[1]))
		if int(v["total"]) > 0:
			var line := "Javelin range, floors %d–%d: %d of %d %s hit today" % [int(span[0]), int(span[1]), int(v["hit"]), int(v["total"]), "ring" if int(v["total"]) == 1 else "rings"]
			if int(v["throws"]) > 0: line += ", %d %s today" % [int(v["throws"]), "throw" if int(v["throws"]) == 1 else "throws"]
			return line + "."
	return ""

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 던지기·창·그림을 지금으로 — 창은 로더의 dt 상한(1/30)으로 적분한다
func _process(delta: float) -> void:
	t += delta
	ranges = ranges.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_green 과 같은 식)
	var dt := minf(delta, 1.0 / 30.0)
	for sv in ranges:
		var s: Dictionary = sv
		_swing(s)
		for jv in (s["javs"] as Array): _jav(s, jv, dt)
		_place(s)

## 던지기의 시계 — 놓은 뒤 release_s 에 창이 손을 떠나고(whish) swing_s 에 몸이 풀린다
func _swing(s: Dictionary) -> void:
	if String(s["sw"]) != "throw": return
	var u := t - float(s["sw_t0"])
	if not bool(s["thrown"]) and u >= release_s():
		var j: Dictionary = (s["javs"] as Array)[int(s["jav"])]
		var v := v_min() + (v_max() - v_min()) * float(s["c"]); var dir := float(s["dir"])
		s["thrown"] = true; s["throws"] = int(s["throws"]) + 1
		j["st"] = "fly"; j["x"] = float(s["wx"]) + dir * hand_dx(); j["y"] = float(s["y"]) + hand_dy()
		j["vx"] = dir * v * cos(loft()); j["vy"] = v * sin(loft()); j["tilt"] = atan2(float(j["vy"]), float(j["vx"]) + float(s["wind"])); j["t0"] = t; j["loose"] = false; j["count"] = bool(s["count"])
		if int(s["throw_day"]) != day(): s["throw_day"] = day(); s["day_throws"] = 0
		s["day_throws"] = int(s["day_throws"]) + 1
		if bool(s["count"]): s["me_t"] = t   # 플레이어가 던졌다 — 주민 반쪽이 따라 던진다
		_play(s["whish"] as AudioStreamPlayer3D)
		_hand(s["sw_fig"] as Stick3D, false)
	if u >= swing_s(): _finish(s)

## 한 창의 시계 — 나는 창은 _fly; 꽂힌 창은 stay_s 뒤 고리가 놓아 곧장 떨어진다; 누운·잃은 창은 back_s 뒤 받침대로
func _jav(s: Dictionary, j: Dictionary, dt: float) -> void:
	match String(j["st"]):
		"fly": _fly(s, j, dt)
		"stuck":
			if t - float(j["t0"]) >= stay_s(): j["st"] = "fly"; j["vx"] = 0.0; j["vy"] = 0.0; j["loose"] = true; j["t0"] = t
		"down", "lost":
			if t - float(j["t0"]) >= back_s(): j["st"] = "rack"; j["loose"] = false

## 나는 창 — G 로 떨어지고 바람에 밀린다; 이 틱의 길이 빈 고리의 ring_r 안을 지나면 꽂힌다(놓인 창은 다시 안 꽂힌다); 내려오며 턱 윗면을 지나면 눕는다(clatter); 발판 아래 lose_dy·탑 밖이면 잃는다
func _fly(s: Dictionary, j: Dictionary, dt: float) -> void:
	j["vy"] = float(j["vy"]) - C.G * dt
	var bx := float(j["x"]); var by := float(j["y"]); var vx := float(j["vx"]) + float(s["wind"]); var vy := float(j["vy"])
	var nx := bx + vx * dt; var ny := by + vy * dt
	if not bool(j["loose"]) and _ring_empty(s) and _seg_dist(float(s["rx"]), float(s["ry"]), bx, by, nx, ny) < ring_r(): _stick(s, j); return
	if vy <= 0.0:
		for pv in (s["plats"] as Array):
			var p: Dictionary = pv
			var py := float(p["y"])
			if nx <= float(p["x"]) or nx >= float(p["x"]) + float(p["w"]) or by < py or ny > py: continue   # 움직이는 발판은 선 자리로 읽는다 — 창이 거기 내리는 일은 드물다
			j["st"] = "down"; j["x"] = nx; j["y"] = py; j["vx"] = 0.0; j["vy"] = 0.0; j["tilt"] = 0.0; j["t0"] = t
			_play(s["clatter"] as AudioStreamPlayer3D)
			return
	j["x"] = nx; j["y"] = ny
	if absf(vx) > 0.1 or absf(vy) > 0.1: j["tilt"] = atan2(vy, vx)
	if ny < float(s["y"]) - lose_dy() or nx < 0.0 or nx > C.WORLD_W: _lose(s, j)

## 꽂힌다 — 촉은 고리에, 자루는 던진 쪽으로 수평; 자루가 발판(ledge)이 된다; 오늘 센다(플레이어의 창만)
func _stick(s: Dictionary, j: Dictionary) -> void:
	var dir := float(s["dir"]); var rx := float(s["rx"]); var ry := float(s["ry"])
	j["st"] = "stuck"; j["x"] = rx - dir * jav_len() / 2.0; j["y"] = ry; j["vx"] = 0.0; j["vy"] = 0.0; j["tilt"] = 0.0 if dir > 0.0 else PI; j["t0"] = t
	var l: Dictionary = j["ledge"]; l["x"] = rx - jav_len() if dir > 0.0 else rx; l["y"] = ry
	s["hits"] = int(s["hits"]) + 1
	if bool(j["count"]): s["day"] = day()
	_play(s["thunk"] as AudioStreamPlayer3D)

func _lose(s: Dictionary, j: Dictionary) -> void:
	j["st"] = "lost"; j["t0"] = t; j["vx"] = 0.0; j["vy"] = 0.0
	if is_inside_tree(): Jump3D.dust(self, C.to3(clampf(float(j["x"]), 0.0, C.WORLD_W), float(j["y"]), float(s["z"]) * C.K), 0.4)   # 창이 사라지는 자리의 먼지 — 로더의 착지 먼지 그대로

func _ring_empty(s: Dictionary) -> bool:
	for jv in (s["javs"] as Array):
		if String((jv as Dictionary)["st"]) == "stuck": return false
	return true

## 점 (px, py) 에서 선분 (ax, ay)→(bx, by) 까지의 거리 — 창은 한 틱에 ring_r 보다 멀리 가니 점이 아니라 길로 본다
static func _seg_dist(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
	var dx := bx - ax; var dy := by - ay
	var l2 := dx * dx + dy * dy
	var k := 0.0 if l2 < 0.0001 else clampf(((px - ax) * dx + (py - ay) * dy) / l2, 0.0, 1.0)
	return Vector2(px - (ax + dx * k), py - (ay + dy * k)).length()

## 로더의 착지 판정과 같은 규칙(HW·HZ) — 이 틱에 꽂힌 자루의 윗면을 지나 떨어지는 몸만 받고 그 자루(발판 모양 사전)를 돌려준다
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	for sv in ranges:
		for jv in ((sv as Dictionary)["javs"] as Array):
			var j: Dictionary = jv
			if String(j["st"]) != "stuck": continue
			var l: Dictionary = j["ledge"]
			var lx := float(l["x"]); var ly := float(l["y"])
			if x + C.HW > lx and x - C.HW < lx + float(l["w"]) and y >= ly and ny <= ly and absf(z - float(l["z"])) < float(l["d"]) / 2.0 + C.HZ: return l
	return {}

## 서 있는 자루가 아직 꽂혀 있나 — 아니면 로더가 on 을 비운다(남의 발판이면 참)
func holds(on: Dictionary) -> bool:
	var oid := String(on.get("id", ""))
	for sv in ranges:
		for jv in ((sv as Dictionary)["javs"] as Array):
			var j: Dictionary = jv
			if String((j["ledge"] as Dictionary)["id"]) == oid: return String(j["st"]) == "stuck"
	return true

## 창·고리를 지금 자리로 — 받침대의 창은 기대 서고, 손의 창은 손이 그리고(안 보인다), 나는·꽂힌·누운 창은 제 자리에 제 각으로, 잃은 창은 안 보인다; 고리는 바람에 조금 흔들린다(바람 없는 층도 그 1/3)
func _place(s: Dictionary) -> void:
	var dir := float(s["dir"]); var L := jav_len() * C.K; var zc := range_d() * C.K / 2.0
	for jv in (s["javs"] as Array):
		var j: Dictionary = jv; var st := String(j["st"]); var node: Node3D = j["node"]
		node.visible = st != "held" and st != "lost"
		if st == "rack" or st == "held":
			node.rotation.z = dir * RACK_LEAN
			node.position = Vector3((float(j["i"]) - 1.0) * 0.07 + dir * 0.5 * L * cos(RACK_LEAN), 0.5 * L * sin(RACK_LEAN) + 0.01, zc)
		else:
			node.rotation.z = float(j["tilt"])
			node.position = Vector3((float(j["x"]) - float(s["wx"])) * C.K, (float(j["y"]) - float(s["y"])) * C.K + (0.012 if st == "down" else 0.0), zc)
	var k := 0.33 + 0.67 * clampf(absf(float(s["wind"])) / 120.0, 0.0, 1.0)
	(s["ring_node"] as Node3D).rotation.z = 0.05 * k * sin(t * TAU * 0.5 + float(s["rx"]) * 0.01)

## 투창장을 짓는다 — root 는 그 층의 노드. 노드 원점은 (받침대의 x, 발판 윗면, 절벽); 받침대(기둥 둘·가로대), 고리(짚 원판·검은 가운데·절벽 받침), 창 count 자루(자루·촉·손잡이 끈 한 조각), 소리 셋
func build(root: Node3D, planned: Array) -> void:
	var zc := range_d() * C.K / 2.0
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(false)   # plats 는 로더의 것 그대로(깊은 복사 없음)
		var node := Node3D.new(); node.position = C.to3(float(s["wx"]), float(s["y"]), C.WALL_Z * C.K); root.add_child(node)
		var wood := _mat(Color("8a6a4a")); var iron := _mat(Color("4a4a52")); var straw := _mat(Color("e3c46a")); var dark := _mat(Color("1b0c15"), true)
		var rack := Node3D.new(); rack.position = Vector3(0.0, 0.0, zc); node.add_child(rack)
		var rh := rack_h() * C.K
		for sx: float in [-0.14, 0.14]: _box(rack, Vector3(0.03, rh, 0.03), wood).position = Vector3(sx, rh / 2.0, 0.0)   # 기둥 둘
		_box(rack, Vector3(0.34, 0.03, 0.03), wood).position = Vector3(0.0, rh, 0.0)   # 가로대 — 창이 기댄다
		var ring := Node3D.new(); ring.position = Vector3((float(s["rx"]) - float(s["wx"])) * C.K, (float(s["ry"]) - float(s["y"])) * C.K, zc); node.add_child(ring)
		var disc := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = ring_r() * C.K; cm.bottom_radius = cm.top_radius; cm.height = 0.06; cm.radial_segments = 14; disc.mesh = cm; disc.material_override = straw
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; disc.rotation.x = PI / 2.0; ring.add_child(disc)   # 짚 원판 — 카메라를 본다
		var dot := MeshInstance3D.new(); var dm := CylinderMesh.new(); dm.top_radius = 0.04; dm.bottom_radius = 0.04; dm.height = 0.07; dm.radial_segments = 10; dot.mesh = dm; dot.material_override = dark
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; dot.rotation.x = PI / 2.0; ring.add_child(dot)   # 가운데
		_box(ring, Vector3(0.05, 0.05, zc), iron).position = Vector3(0.0, 0.0, -zc / 2.0)   # 절벽 받침
		var javs: Array = []
		for i in rack_n():
			var jn := _jav_node(node)
			javs.append({ "i": i, "st": "rack", "x": float(s["wx"]), "y": float(s["y"]), "vx": 0.0, "vy": 0.0, "tilt": 0.0, "t0": -99.0, "loose": false, "count": true, "node": jn,
				"ledge": { "id": "%s.j%d" % [String(s["id"]), i], "x": float(s["rx"]), "w": jav_len(), "y": float(s["ry"]), "kind": "javelin", "z": float(s["z"]), "d": float(s["d"]) } })
		s["node"] = node; s["rack"] = rack; s["ring_node"] = ring; s["javs"] = javs; s["jav"] = -1
		s["sw"] = ""; s["sw_t0"] = -99.0; s["sw_fig"] = null; s["c"] = 0.0; s["thrown"] = false; s["count"] = true
		s["throws"] = 0; s["day"] = -1; s["hits"] = 0; s["me_t"] = -99.0; s["throw_day"] = -1; s["day_throws"] = 0
		s["whish"] = _snd(node, float(kind.get("whish_hz", 600)), 0.08, -16.0, false); s["thunk"] = _snd(node, float(kind.get("thunk_hz", 240)), 0.12, -12.0, false); s["clatter"] = _snd(node, float(kind.get("clatter_hz", 1100)), 0.2, -14.0, true)
		ranges.append(s)
		_place(s)

## 창 한 자루 — 원점은 자루 가운데, 촉은 +x(rotation.z 가 각을 준다): 물푸레 자루, 쇠촉, 손잡이 끈(강조색은 이 한 조각)
func _jav_node(parent: Node3D) -> Node3D:
	var L := jav_len() * C.K
	var jn := Node3D.new(); parent.add_child(jn)
	_box(jn, Vector3(L, 0.016, 0.016), _mat(Color("d8c9a8")))
	_box(jn, Vector3(0.08, 0.024, 0.024), _mat(Color("4a4a52"))).position = Vector3(0.5 * L - 0.04, 0.0, 0.0)
	_box(jn, Vector3(0.05, 0.022, 0.022), _mat(Color("ad7096"), true)).position = Vector3(-0.1 * L, 0.0, 0.0)
	return jn

func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

func _snd(parent: Node3D, hz: float, secs: float, db: float, twice: bool) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs, twice); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — 짧은 기음이 잦아든다: whish(0.08초 — 창이 손을 떠난다)·thunk(0.12초, 낮게 — 촉이 고리에 박힌다)·clatter(0.2초, 두 번, 높게 — 자루가 발판에 눕는다). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float, twice: bool) -> AudioStreamWAV:
	var rate := 22050; var n := int(rate * secs)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var k := float(i) / n
		var ph := float(i) * hz * TAU / rate
		var env := exp(-k * 9.0) + (exp(-(k - 0.5) * 9.0) if twice and k > 0.5 else 0.0)
		var v := (sin(ph) * 0.5 + sin(ph * 2.7) * 0.2) * env
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
