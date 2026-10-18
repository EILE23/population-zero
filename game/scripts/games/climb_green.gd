class_name ClimbGreen
extends Node3D
## Climb 콘텐츠 팩 '구름 그린'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 구름바다(Cloud sea) 층의 오르는 순서에서 잇단 still 발판 한 쌍 — 티 발판의 건너편 쪽 가장자리 tee_in 안쪽에 티(잔디 한 조각·못·공, 절벽 쪽 green_d 안이라 앞길은 비어 있다), 깃발 발판의 먼 끝 hole_in 안쪽에 홀과 깃발(바람에 펄럭이는 깃). 공이 티에서 홀까지 loft_deg 로 날아가는 데 드는 속도가 v_max 의 need_lo..need_hi 사이인 쌍만 그린이 된다(톡 치면 틈에 빠지고 다 모으면 넘어간다).
## 티 곁(HW + reach)에서 C: 공 앞에 선다(address) — 누르고 있는 동안 백스윙이 charge_s 까지 감기고(점프의 CHARGE 와 같은 시계), 놓으면 strike_s 뒤 공이 못을 떠나(tock) 스윙은 swing_s 에 끝난다; 그동안 몸은 busy(걷기·점프 없음). 공은 v_min + (v_max − v_min) × 모은 만큼, 층의 바람에 몸처럼 밀린다.
## 공은 단단하지 않고 값도 없다: G 로 떨어지고, bounce_v 보다 빠르게 턱 위에 오면 한 번 튀고(bounce_k·hit_k), 구르며 friction 만큼 느려지고, cup_v 보다 느리게 홀 위를 지나면 들어간다(cup — 탑의 하루 day_s 에 한 번 센다, 쉼터 판이 note(n) 으로 읽는다), 턱 끝을 구르면 다시 떨어지고, 티보다 lose_dy 아래거나 탑 폭 밖이면 구름에 잃는다(plop·먼지). 잃은·멈춘·들어간 공은 rest_s 뒤 못 위로 돌아온다. 깃발 발판에 처음 닿은 것은 그날 '그린에 올렸다'로 센다(굴러 떨어져도).
## 못 앞에서 C 를 누르지 않는 몸에겐 아무것도 바뀌지 않는다: 티 발판을 달려 지나는 길, 틈을 건너는 맨 점프, 다른 데서의 C(쉼터 문·판)는 그대로(평이한 결과 100%).
## 멀리뛰기 모래(제 몸의 기록)·높이뛰기 바(제 몸이 넘는다)와 다르다: 이건 몸이 아니라 공을 보내는 첫 조각 — 모은 힘이 거리가 되고 눈이 공을 따라간다. 자세는 stroke(stick3d_stroke.gd — 운영자 보드의 '골프' 가족): 어드레스(무릎 풀고 공을 본다) → 모은 만큼 감기는 백스윙 → 다운스윙·임팩트 → 가슴이 목표를 향하고 고개가 공을 쫓는 피니시(10 Hz 잔떨림) — 정지화가 아니다. 골퍼는 카메라를 본다(공은 x 로 난다).
## 로더가 할 일(climb.gd, 운영자 세션): `var cg := ClimbGreen.new(); add_child(cg); signs.notes.append(cg.note)`; 층을 지을 때 `var tk := cr.plan(n, plats) + mu.plan(n, plats); var pp := cp.plan(n, plats, tk); var bp := ba.plan(n, plats, tk + pp); var lp := ln.plan(n, plats, tk + pp + bp); cg.build(root, cg.plan(n, plats, wind_of(n), tk + pp + bp + lp + lj.plan(n, plats, tk + pp + bp + lp)))`
## (뗏목·버섯·널·열기구·렌즈·모래밭의 계획을 taken 으로 — 티 잔디·홀 자리를 둘이 안 나눈다; 틈에 뜬 것 위로는 공이 난다; plan 은 plats 를 공의 착지용으로 품는다); 매 틱 `cg.sync(_t)`;
## 발판에 선 가지에서(매달림·붙잡음이 비고 `on` 이 찼을 때, jump_held 를 읽기 전에) `var g := cg.tee(x, z, on, Input.is_action_pressed("act"), fig); if g["busy"]: dir = 0.0; jump_held = false; charge = 0.0; fig.pose_request = "stroke" elif fig.pose_request == "stroke": fig.pose_request = ""`
## (팩이 meta stroke_c·stroke_t·stroke_lead 를 적고 스윙이 끝나면 지운다); `_figure()` 의 face 가지 앞에 `if cg.swinging(fig): fig.face(0.0)` (골퍼는 카메라를 본다); 공중에선 부르지 않는다. 쉼터 판 C 는 signs.tick 이 먼저 — 그린은 std/ice 발판에만 선다.
## 주민 반쪽(run 173): 그린마다 골퍼 하나(climb_golfer.gd — 그린 노드 아래 Stick3D)가 못 뒤 40 px 에 카메라를 보고 서서 탑의 1분마다, 그리고 플레이어가 친 뒤 1.5 s 뒤에 못으로 가 공이 돌아오길 기다려 같은 tee(count 거짓)·같은 stroke 로 치고(충전은 홀 50 px 앞의 need 를 가운데로 ±0.1 — 셋에 하나 들어간다) 공을 눈으로 쫓는다(track).
## tee 의 count: 비우면 플레이어(판에 세고 me_t 를 적는다 — 주민 반쪽이 기다렸다 따라 친다), 다른 몸(주민 반쪽)은 거짓을 준다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_green.gd

const PACK := "res://data/climb/green.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_LO := 20.0      # taken 조각이 이 쌍의 것인가: y 가 티 발판 윗면 − BAND_LO 부터 깃발 발판 윗면 + BAND_HI 앞까지(run 152 의 띠 규칙)
const BAND_HI := 60.0
const BODY_UP := 50.0      # 선 몸의 키(px) — 상자 위쪽 여유
const SIDE := 10.0         # 상자 x 여유(px) — 손 하나

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.green
var greens: Array = []          # 지은 그린 {id, kind "green", n, tee_id, flag_id, hop_w, y, fy, tee_x, hole_x, dir, dx, need, x, w, y_top, z, d, wind, plats, node, ball_node, pen, ball, bx, by, vx, vy, on_id, sw, sw_t0, sw_fig, c, struck, count, shots, rest_t0, day, hit_day, me_t, tock, plop, cup, golfer}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("green", {})

func sync(now: float) -> void:
	t = now

func tee_in() -> float:
	return maxf(C.HW, float(kind.get("tee_in", 24.0)))

func min_w() -> float:
	return maxf(2.0 * tee_in(), float(kind.get("min_w", 60.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 14.0)))

func green_d() -> float:
	return maxf(8.0, float(kind.get("green_d", 24.0)))

func tee_h() -> float:
	return maxf(0.0, float(kind.get("tee_h", 2.0)))

func ball_r() -> float:
	return maxf(1.0, float(kind.get("ball_r", 3.0)))

func loft() -> float:
	return deg_to_rad(clampf(float(kind.get("loft_deg", 60.0)), 20.0, 80.0))

func v_min() -> float:
	return maxf(1.0, float(kind.get("v_min", 400.0)))

func v_max() -> float:
	return maxf(v_min() + 1.0, float(kind.get("v_max", 1100.0)))

func need_lo() -> float:
	return clampf(float(kind.get("need_lo", 0.5)), 0.0, 1.0)

func need_hi() -> float:
	return clampf(float(kind.get("need_hi", 0.92)), need_lo(), 1.0)

func charge_s() -> float:
	return maxf(0.05, float(kind.get("charge_s", 0.7)))

func strike_s() -> float:
	return maxf(0.0, float(kind.get("strike_s", 0.12)))

func swing_s() -> float:
	return maxf(strike_s() + 0.05, float(kind.get("swing_s", 0.6)))

func bounce_v() -> float:
	return maxf(0.0, float(kind.get("bounce_v", 220.0)))

func bounce_k() -> float:
	return clampf(float(kind.get("bounce_k", 0.25)), 0.0, 0.9)

func hit_k() -> float:
	return clampf(float(kind.get("hit_k", 0.7)), 0.0, 1.0)

func roll_k() -> float:
	return clampf(float(kind.get("roll_k", 0.6)), 0.0, 1.0)

func friction() -> float:
	return maxf(1.0, float(kind.get("friction", 160.0)))

func cup_v() -> float:
	return maxf(0.0, float(kind.get("cup_v", 260.0)))

func hole_in() -> float:
	return maxf(C.HW, float(kind.get("hole_in", 30.0)))

func hole_r() -> float:
	return maxf(3.0, float(kind.get("hole_r", 10.0)))

func lose_dy() -> float:
	return maxf(10.0, float(kind.get("lose_dy", 160.0)))

func rest_s() -> float:
	return maxf(0.1, float(kind.get("rest_s", 2.5)))

func day_s() -> float:
	return maxf(1.0, float(kind.get("day_s", 600.0)))

func flag_h() -> float:
	return maxf(4.0, float(kind.get("flag_h", 40.0)))

func flutter_hz() -> float:
	return maxf(0.1, float(kind.get("flutter_hz", 2.3)))

## 탑의 오늘 — 로더의 시계를 day_s 로 나눈 몫
func day() -> int:
	return floori(t / day_s())

## 티에서 dx 앞, dy 위의 홀까지 loft 로 나르는 데 드는 속도(px/s) — 닿지 못하는 기하(홀이 사정각 위)면 INF
func need_v(dx: float, dy: float) -> float:
	var den := 2.0 * pow(cos(loft()), 2.0) * (dx * tan(loft()) - dy)
	if dx <= 0.0 or den <= 1.0: return INF
	return sqrt(C.G * dx * dx / den)

## 층 n(테마 층)의 잇단 still 발판 쌍(티 발판은 조각의 on, 깃발 발판은 flag_on) 중 티 발판이 min_w 보다 넓고, 티 → 홀의 속도가 v_max 의 need_lo..need_hi 이고, 둘 사이 상자(티..홀 ± 손 하나, 티 윗면..깃발 발판 위 선 몸)를 다른 발판이 가르지 않고, taken 조각이 티 잔디·홀 자리의 띠 안에 없는 것들 중 티 발판이 가장 넓은 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, wind: float = 0.0, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))   # 오르는 순서(band() 는 그렇게 쌓는다) — 다음 발판이 깃발 발판
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var kinds: Array = piece.get("on", ["std", "ice"]); var flags: Array = piece.get("flag_on", ["std", "ice"])
		var found: Array = []
		for i in range(0, hops.size() - 1):
			var p: Dictionary = hops[i]; var q: Dictionary = hops[i + 1]
			if not (String(p["kind"]) in kinds) or not (String(q["kind"]) in flags): continue
			var w := float(p["w"]); var y := float(p["y"]); var fw := float(q["w"]); var fy := float(q["y"])
			if w < min_w() or fw < 2.0 * hole_in() or fy <= y: continue
			var dir := 1.0 if float(q["x"]) + fw / 2.0 >= float(p["x"]) + w / 2.0 else -1.0   # 티 발판에서 깃발 발판 쪽으로
			var tee_x := float(p["x"]) + w - tee_in() if dir > 0.0 else float(p["x"]) + tee_in()
			var hole_x := float(q["x"]) + fw - hole_in() if dir > 0.0 else float(q["x"]) + hole_in()
			var dx := (hole_x - tee_x) * dir
			var need := need_v(dx, fy - y)
			if need < need_lo() * v_max() or need > need_hi() * v_max(): continue
			var lo := minf(tee_x, hole_x); var hi := maxf(tee_x, hole_x)
			if not _clear(plats, [p["id"], q["id"]], lo - SIDE, hi + SIDE, y + 1.0, fy + BODY_UP): continue
			if not _free(taken, tee_x - 5.0, tee_x + 5.0, y - BAND_LO, y + BAND_HI): continue   # 티 자리(_free 가 손 하나 10 을 더한다) — 모래밭·널이 쓰는 턱이면 비킨다; 틈에 뜬 뗏목·열기구·렌즈는 턱 바로 밑에서 시작해도 공의 길 아래다(단단한 게 없다)
			if not _free(taken, hole_x - hole_r(), hole_x + hole_r(), fy - BAND_LO, fy + BAND_HI): continue   # 홀 자리
			found.append({ "hop_w": w, "tee_id": String(p["id"]), "flag_id": String(q["id"]), "hop_kind": String(p["kind"]), "y": y, "fy": fy, "tee_x": tee_x, "hole_x": hole_x, "dir": dir, "dx": dx, "need": need, "x": lo, "w": hi - lo, "hz": float(p.get("z", C.WALL_Z + C.DEPTH_HALF)), "hd": float(p.get("d", C.DEPTH_HALF * 2.0)) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["hop_w"]) > float(q["hop_w"]) if float(p["hop_w"]) != float(q["hop_w"]) else float(p["y"]) < float(q["y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.G%d" % [n, i]; s["kind"] = "green"; s["n"] = n; s["wind"] = wind
			s["y_top"] = float(g["fy"]) + flag_h()   # 깃대 꼭대기 — 다른 팩의 _free 가 읽는 키
			s["z"] = C.WALL_Z + green_d() / 2.0; s["d"] = green_d()   # 티·공의 깊이 — 절벽에서 green_d 까지
			s["plats"] = plats   # 공의 착지용 — 복사하지 않는다(로더의 발판 사전 그대로)
			out.append(s)
	return out

## 쌍의 상자에 그 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x, 있으면 w·rail_y·beam_y·y_top)이 자리의 x 와 겹치고 높이 띠 [ylo, yhi) 에 들면 그 자리는 그 팩의 것 — 모래밭은 발판 위, 널은 턱에(둘 다 티 자리와 겹친다), 뗏목·열기구·렌즈는 틈에(공의 길 아래 — 겹치지 않는다)
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qtop := qy
		for key: String in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qtop = maxf(qtop, float(q[key]))
		if x1 > qx0 and x0 < qx1 and qtop >= ylo and qy < yhi: return false
	return true

## 발판에 선 매 틱 — {busy, k, id}: 티 발판의 못 곁(HW + reach, 걷는 선)에 선 몸이 C 를 누르면(못 위에 공이 있을 때) 어드레스에 들어 모으기 시작하고(sw "charge", meta stroke_c 0..1 · stroke_lead 목표 쪽), 놓으면 스윙(sw "swing", meta stroke_t 놓은 뒤 시간 — 공은 _process 가 strike_s 에 띄운다); 스윙이 끝날 때까지 busy.
## 남의 스윙 중인 티는 기다린다(busy 거짓). 못에서 떠난 몸(다른 발판·먼 x)이 모으던 중이었으면 그 모으기는 풀리고 공은 못에 남는다
func tee(x: float, z: float, on: Dictionary, pressed: bool, fig: Stick3D = null, count := true) -> Dictionary:
	var none := { "busy": false, "k": 0.0, "id": "" }
	var oid := String(on.get("id", ""))
	for sv in greens:
		var s: Dictionary = sv
		if oid != String(s["tee_id"]) or absf(z - C.PLAYER_Z) >= C.HZ + 4.0 or absf(x - float(s["tee_x"])) > C.HW + reach(): continue
		var r := none.duplicate(); r["id"] = String(s["id"])
		if String(s["sw"]) == "":
			if not pressed or String(s["ball"]) != "tee": return r
			s["sw"] = "charge"; s["sw_t0"] = t; s["sw_fig"] = fig; s["count"] = count; s["c"] = 0.0
			if fig: fig.set_meta("stroke_c", 0.0); fig.set_meta("stroke_lead", float(s["dir"])); _club(fig, true)
			r["busy"] = true; return r
		if (s["sw_fig"] as Stick3D) != fig: return r   # 남의 스윙 — 기다린다
		if String(s["sw"]) == "charge":
			s["c"] = clampf((t - float(s["sw_t0"])) / charge_s(), 0.0, 1.0)
			if pressed:
				if fig: fig.set_meta("stroke_c", float(s["c"]))
			else:
				s["sw"] = "swing"; s["sw_t0"] = t; s["struck"] = false
				if fig: fig.set_meta("stroke_t", 0.0)
		elif fig: fig.set_meta("stroke_t", t - float(s["sw_t0"]))
		r["busy"] = true; r["k"] = float(s["c"]); return r
	_drop(fig)
	return none

## 어느 티에도 없는 몸 — 모으던 중이었으면 푼다(스윙에 든 것은 공을 띄우고 제 때에 끝난다)
func _drop(fig: Stick3D) -> void:
	if fig == null: return
	for sv in greens:
		var s: Dictionary = sv
		if (s["sw_fig"] as Stick3D) == fig and String(s["sw"]) == "charge": _finish(s)

## 이 몸이 어느 티에서든 어드레스·스윙 중인가 — 로더가 카메라 쪽을 보게 한다
func swinging(fig: Stick3D) -> bool:
	for sv in greens:
		if String((sv as Dictionary)["sw"]) != "" and ((sv as Dictionary)["sw_fig"] as Stick3D) == fig: return true
	return false

## 스윙에서 떠난 몸 — 자세의 메타와 손의 채를 거둔다
func leave(fig: Stick3D) -> void:
	if fig == null: return
	for key: String in ["stroke_c", "stroke_t", "stroke_lead"]:
		if fig.has_meta(key): fig.remove_meta(key)
	_club(fig, false)

func _finish(s: Dictionary) -> void:
	leave(s["sw_fig"] as Stick3D)
	s["sw"] = ""; s["sw_fig"] = null

## 오른손의 채 — 어드레스에 쥐고 스윙 끝에 놓는다(그림 — 손목에서 아래로 뻗는 샤프트와 헤드)
func _club(fig: Stick3D, on: bool) -> void:
	var had := fig.hand_r.get_node_or_null("club")
	if not on:
		if had: had.queue_free()
		return
	if had: return
	var club := Node3D.new(); club.name = "club"; fig.hand_r.add_child(club)
	_box(club, Vector3(0.025, 0.72, 0.025), _mat(Color("8a8a92"))).position = Vector3(0.0, -0.36, 0.0)
	_box(club, Vector3(0.11, 0.05, 0.07), _mat(Color("4a4a52"))).position = Vector3(0.035, -0.72, 0.0)

## n0..n1 층의 지은 그린에서 오늘 올린 수·들어간 수·전체·들어간 것 중 가장 먼 티 → 홀(px) — {hit, holed, total, longest}
func holed_today(n0: int, n1: int) -> Dictionary:
	var hit := 0; var holed := 0; var total := 0; var longest := 0.0
	for sv in greens:
		var s: Dictionary = sv
		if int(s["n"]) < n0 or int(s["n"]) > n1: continue
		total += 1
		if int(s["hit_day"]) == day(): hit += 1
		if int(s["day"]) == day(): holed += 1; longest = maxf(longest, float(s["dx"]))
	return { "hit": hit, "holed": holed, "total": total, "longest": longest }

## 쉼터 판(n 층)에 붙는 줄 — 위 다섯 층(n..n+4)의 그린, 없으면 아래 다섯 층(n−5..n−1), 그것도 없으면 빈 줄. climb_signs.notes 에 넣는다. 거리는 탑의 m(36 px)
func note(n: int) -> String:
	for span: Array in [[n, n + 4], [n - 5, n - 1]]:
		var v := holed_today(int(span[0]), int(span[1]))
		if int(v["total"]) > 0:
			var line := "Cloud green, floors %d–%d: %d of %d %s hit today" % [int(span[0]), int(span[1]), int(v["hit"]), int(v["total"]), "green" if int(v["total"]) == 1 else "greens"]
			if int(v["holed"]) > 0: line += ", %d holed, the longest %.1f m" % [int(v["holed"]), float(v["longest"]) * C.K]
			return line + "."
	return ""

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 스윙·공·그림을 지금으로 — 공은 로더의 dt 상한(1/30)으로 적분한다
func _process(delta: float) -> void:
	t += delta
	greens = greens.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_bar 와 같은 식)
	for sv in greens:
		var s: Dictionary = sv
		_swing(s); _ball(s, minf(delta, 1.0 / 30.0)); _place(s)
		if s.has("golfer"): (s["golfer"] as ClimbGolfer).step(delta)   # 골퍼의 틱

## 스윙의 시계 — 놓은 뒤 strike_s 에 공이 못을 떠나고(tock) swing_s 에 몸이 풀린다
func _swing(s: Dictionary) -> void:
	if String(s["sw"]) != "swing": return
	var u := t - float(s["sw_t0"])
	if not bool(s["struck"]) and u >= strike_s():
		var v := v_min() + (v_max() - v_min()) * float(s["c"])
		s["struck"] = true; s["ball"] = "fly"; s["on_id"] = ""; s["shots"] = int(s["shots"]) + 1
		s["vx"] = float(s["dir"]) * v * cos(loft()); s["vy"] = v * sin(loft())
		if bool(s["count"]): s["me_t"] = t   # 플레이어가 쳤다 — 주민 반쪽이 기다렸다 따라 친다
		_play(s["tock"] as AudioStreamPlayer3D)
	if u >= swing_s(): _finish(s)

func _ball(s: Dictionary, dt: float) -> void:
	var b := String(s["ball"])
	if b == "fly": _fly(s, dt)
	elif b == "roll": _roll(s, dt)
	elif b != "tee" and t - float(s["rest_t0"]) >= rest_s():   # 멈춘·들어간·잃은 공 — 못 위로 돌아온다
		s["ball"] = "tee"; s["bx"] = float(s["tee_x"]); s["by"] = float(s["y"]) + tee_h(); s["vx"] = 0.0; s["vy"] = 0.0; s["on_id"] = ""

## 나는 공 — G 로 떨어지고 바람에 밀린다; 내려오며 턱 윗면을 지나면 닿는다: 빠르면 한 번 튀고 느리면 구른다; 티보다 lose_dy 아래·탑 밖이면 구름에 잃는다
func _fly(s: Dictionary, dt: float) -> void:
	s["vy"] = float(s["vy"]) - C.G * dt
	var bx := float(s["bx"]); var by := float(s["by"]); var vx := float(s["vx"]); var vy := float(s["vy"])
	var nx := bx + (vx + float(s["wind"])) * dt; var ny := by + vy * dt
	if vy <= 0.0:
		for pv in (s["plats"] as Array):
			var p: Dictionary = pv
			var py := float(p["y"])
			if nx <= float(p["x"]) or nx >= float(p["x"]) + float(p["w"]) or by < py or ny > py: continue   # 움직이는 발판은 선 자리로 읽는다 — 공이 거기 내리는 일은 드물고 오차는 진폭만큼
			s["bx"] = nx; s["by"] = py; s["on_id"] = String(p["id"])
			if -vy > bounce_v(): s["vy"] = -vy * bounce_k(); s["vx"] = vx * hit_k()
			else: s["vy"] = 0.0; s["vx"] = vx * roll_k(); s["ball"] = "roll"
			if String(p["id"]) == String(s["flag_id"]) and bool(s["count"]): s["hit_day"] = day()   # 그린에 올렸다 — 굴러 떨어져도 오늘 것
			return
	s["bx"] = nx; s["by"] = ny
	if ny < float(s["y"]) - lose_dy() or nx < 0.0 or nx > C.WORLD_W: _lose(s)

## 구르는 공 — friction 으로 느려진다; 깃발 발판에서 cup_v 보다 느리게 홀 위를 지나면 들어가고(cup, 오늘 센다), 턱 끝을 지나면 다시 떨어지고, 서면 rest_s 눕는다
func _roll(s: Dictionary, dt: float) -> void:
	var vx := float(s["vx"]); var bx := float(s["bx"]) + vx * dt
	var p := _plat(s, String(s["on_id"]))
	s["bx"] = bx
	if p.is_empty() or bx < float(p["x"]) or bx > float(p["x"]) + float(p["w"]):
		s["ball"] = "fly"; s["vy"] = 0.0; return
	if String(s["on_id"]) == String(s["flag_id"]) and absf(bx - float(s["hole_x"])) < hole_r() and absf(vx) < cup_v():
		s["ball"] = "holed"; s["bx"] = float(s["hole_x"]); s["vx"] = 0.0; s["rest_t0"] = t
		if bool(s["count"]): s["day"] = day()
		_play(s["cup"] as AudioStreamPlayer3D)
		return
	vx -= signf(vx) * minf(absf(vx), friction() * dt); s["vx"] = vx
	if absf(vx) < 2.0: s["ball"] = "rest"; s["rest_t0"] = t

func _lose(s: Dictionary) -> void:
	s["ball"] = "lost"; s["rest_t0"] = t; s["vx"] = 0.0; s["vy"] = 0.0
	_play(s["plop"] as AudioStreamPlayer3D)
	if is_inside_tree(): Jump3D.dust(self, C.to3(float(s["bx"]), float(s["by"]), float(s["z"]) * C.K), 0.5)   # 구름이 받는 자리의 뭉게 — 로더의 착지 먼지 그대로

func _plat(s: Dictionary, id: String) -> Dictionary:
	for pv in (s["plats"] as Array):
		if String((pv as Dictionary)["id"]) == id: return pv
	return {}

## 공과 깃을 지금 자리로 — 잃은 공은 안 보이고, 들어간 공은 홀에 가라앉고, 깃은 바람에 펄럭인다(바람 없는 층도 그 4/10)
func _place(s: Dictionary) -> void:
	var ball: Node3D = s["ball_node"]; var b := String(s["ball"])
	ball.visible = b != "lost"
	var dy := (float(s["by"]) - float(s["y"])) * C.K + ball_r() * C.K * (-0.6 if b == "holed" else 1.0)
	ball.position = Vector3((float(s["bx"]) - float(s["tee_x"])) * C.K, dy, 0.0)
	var k := 0.4 + 0.6 * clampf(absf(float(s["wind"])) / 120.0, 0.0, 1.0)
	(s["pen"] as Node3D).rotation.y = 0.35 * k * sin(t * TAU * flutter_hz() + float(s["hole_x"]) * 0.01)

## 그린을 짓는다 — root 는 그 층의 노드. 노드 원점은 (티의 x, 티 발판 윗면, 절벽); 잔디 조각과 못, 공(제 노드 — _place 가 옮긴다), 깃발 발판의 홀(검은 원)·깃대·깃(강조색), 소리 셋
func build(root: Node3D, planned: Array) -> void:
	var gd := green_d() * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(false)   # plats 는 로더의 것 그대로(깊은 복사 없음)
		var node := Node3D.new(); node.position = C.to3(float(s["tee_x"]), float(s["y"]), C.WALL_Z * C.K); root.add_child(node)
		var turf := _mat(Color("8fb86a")); var white := _mat(Color("f7f4ef"), true); var iron := _mat(Color("4a4a52")); var acc := _mat(Color("ad7096")); var dark := _mat(Color("1b0c15"), true)
		_box(node, Vector3(30.0 * C.K, 0.04, gd), turf).position = Vector3(0.0, 0.02, gd / 2.0)   # 잔디 한 조각
		_box(node, Vector3(0.02, tee_h() * C.K + 0.02, 0.02), white).position = Vector3(0.0, (tee_h() * C.K + 0.02) / 2.0, gd / 2.0)   # 못
		var ball := Node3D.new(); ball.position.z = gd / 2.0; node.add_child(ball)
		var sph := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = ball_r() * C.K; sm.height = sm.radius * 2.0; sm.radial_segments = 8; sm.rings = 4; sph.mesh = sm; sph.material_override = white
		sph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; ball.add_child(sph)
		var hx := (float(s["hole_x"]) - float(s["tee_x"])) * C.K; var hy := (float(s["fy"]) - float(s["y"])) * C.K
		var hole := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = hole_r() * C.K; cm.bottom_radius = cm.top_radius; cm.height = 0.012; cm.radial_segments = 12; hole.mesh = cm; hole.material_override = dark
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; hole.position = Vector3(hx, hy + 0.006, gd / 2.0); node.add_child(hole)
		var fh := flag_h() * C.K
		_box(node, Vector3(0.03, fh, 0.03), iron).position = Vector3(hx - float(s["dir"]) * 0.02, hy + fh / 2.0, gd / 2.0)   # 깃대 — 홀 뒤에
		var pen := Node3D.new(); pen.position = Vector3(hx - float(s["dir"]) * 0.02, hy + fh - 0.12, gd / 2.0); node.add_child(pen)
		_box(pen, Vector3(0.3, 0.2, 0.01), acc).position = Vector3(float(s["dir"]) * 0.16, 0.0, 0.0)   # 깃 — 강조색은 이 한 조각
		s["node"] = node; s["ball_node"] = ball; s["pen"] = pen
		s["ball"] = "tee"; s["bx"] = float(s["tee_x"]); s["by"] = float(s["y"]) + tee_h(); s["vx"] = 0.0; s["vy"] = 0.0; s["on_id"] = ""
		s["sw"] = ""; s["sw_t0"] = -99.0; s["sw_fig"] = null; s["c"] = 0.0; s["struck"] = false; s["count"] = true; s["shots"] = 0; s["rest_t0"] = -99.0; s["day"] = -1; s["hit_day"] = -1; s["me_t"] = -99.0
		s["tock"] = _snd(node, float(kind.get("tock_hz", 900)), 0.05, -14.0, false); s["plop"] = _snd(node, float(kind.get("plop_hz", 160)), 0.2, -14.0, false); s["cup"] = _snd(node, float(kind.get("cup_hz", 1400)), 0.14, -12.0, true)
		s["golfer"] = ClimbGolfer.new(self, s, node)   # 주민 반쪽 — 못 뒤에 카메라를 보고 선 골퍼
		greens.append(s)
		_place(s)

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

## 소리 — 짧은 기음이 잦아든다: tock(0.05초, 메마르게 — 채가 공을 친다)·plop(0.2초, 낮게 — 공이 구름에 묻힌다)·cup(0.14초, 두 번 — 공이 컵 안에서 튄다). 한 번 재생, 반복 없음
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
