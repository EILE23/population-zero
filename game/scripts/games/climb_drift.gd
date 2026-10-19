class_name ClimbDrift
extends Node3D
## Climb 콘텐츠 팩 '별가루 더미'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 별밤(Starlit) 층의 still std 발판 중 min_w 보다 넓고 다른 팩이 안 쓴 가장 넓은 것 — 그 한가운데 절벽 쪽(drift_d 안, 앞길은 비어 있다)에 떨어진 별가루 더미(drift_w × drift_h)가 쌓여 있고 삽 한 자루가 꽂혀 있다(손잡이 handle_h). 오른쪽 heap_dx 엔 판 흙자리 — 퍼낸 별가루가 쌓이는 곳.
## 삽 곁(HW + reach)에서 C(더미가 쌓여 있을 때): 삽을 잡고 판다 — 발로 날을 밟아 찌르고(thrust_s) 지렛대로 젖혀(lever_s) 더미 쪽으로 퍼 넘긴다(heave_s): 한 바퀴에 한 삽, 더미는 한 삽 낮아지고 무더기는 한 삽 높아진다(무더기에 가루 퍼프). C 를 쥐고 있으면 바퀴를 잇고, 놓으면 그 바퀴를 마치고 삽을 꽂는다(stop_s 뒤 몸이 풀린다). 바퀴 중에 떠나면 그 삽은 버리되 판 것은 남는다 — 더미가 되메워지기 전까지 얼마나 팠는지 기억한다.
## 마지막 삽이 나오면 묻혀 있던 별이 드러난다: rise_s 에 star_h 까지 떠오르고(chime) 판 이는 삽에 기대어 gaze_s 동안 올려다본다; 별은 hang_s(탑 시간) 동안 돌며 걸려 있다가 sink_s 에 가라앉고 더미가 refill_s 에 걸쳐 되메워진다(별가루가 내린다, hush) — 다시 팔 수 있다.
## 그동안 몸은 busy(걷기·점프 없음), 자세는 shovel(stick3d_shovel.gd — 운영자 보드의 '삽질' 가족: 앞발로 날을 밟는 찌르기 → 팔꿈치를 당기고 무릎을 굽히는 지렛대 → 두 팔로 한쪽으로 퍼 넘기는 헤이브 → 한 손은 손잡이·한 손은 허리로 올려다보는 바라봄 / 이마를 훔치고 서는 멈춤 — 정지화가 아니다). 파는 이는 무더기 쪽(오른쪽)을 본다.
## 더미는 단단하지 않고 값도 없다. 드러난 별은 탑의 하루(day_s)에 한 번 센다 — 쉼터 판이 note(n) 으로 읽는다('Stardust drifts, floors 30–34: 2 of 3 dug out today, the deepest 8 scoops, 1 star up.').
## 삽 곁에서 C 를 누르지 않는 몸에겐 아무것도 바뀌지 않는다: 발판을 달려 지나는 길, 맨 점프, 다른 데서의 C(쉼터 문·판)는 그대로(평이한 결과 100%). 별이 떠 있거나 되메워지는 더미 곁 C 도 아무것도 아니다.
## 시계추(무게를 머리 위에 버틴다)·풀무(발로 다른 자리를 올린다)·서랍(절벽에서 홱 당긴다)과 다르다: 이건 제 삽으로 땅을 덜어 내는 몸 — 판 만큼이 남고, 바닥에 있던 것이 드러난다. 별밤의 여섯 조각은 다 몸이 타고 건너고 들여다보고 오르는 것이었다 — 파는 건 처음.
## 로더가 할 일(climb.gd, 운영자 세션): `var cd := ClimbDrift.new(); add_child(cd); signs.notes.append(cd.note)`; 층을 지을 때 `var ic := ci.plan(n, plats); var lp := cn.plan(n, plats, ic); var tp := ct.plan(n, plats, ic + lp); var cp := cc.plan(n, plats, lp + ic); var tsp := ts.plan(n, plats, ic + lp + tp + cp); cd.build(root, cd.plan(n, plats, ic + lp + tp + cp + tsp + tr.plan(n, plats, ic + lp + tp + tsp)))`
## (고드름·등롱·그네·초 계단·망원경·외줄의 계획을 taken 으로 — 그 발판은 비켜 간다); 매 틱 `cd.sync(_t)`;
## 발판에 선 가지에서(매달림·붙잡음이 비고 `on` 이 찼을 때, jump_held 를 읽기 전에) `var dg := cd.dig(x, z, on, Input.is_action_pressed("act"), fig); if dg["busy"]: dir = 0.0; jump_held = false; charge = 0.0; fig.pose_request = "shovel" elif fig.pose_request == "shovel": fig.pose_request = ""`
## (팩이 meta shovel_t·shovel_end·shovel_u 를 적고 끝나면 지운다); `_figure()` 의 face 가지 앞에 `if cd.digging(fig): fig.face(PI / 2.0)` (파는 이는 무더기 쪽을 본다); 공중에선 부르지 않는다. 쉼터 판 C 는 signs.tick 이 먼저 — 더미는 std 발판에만 놓인다.
## dig 의 count: 비우면 플레이어(판에 세고 me_t 를 적는다 — 다음 조각의 주민 반쪽이 되메워지길 기다려 따라 판다), 다른 몸은 거짓을 준다.
## 주민 반쪽(run 177): 더미마다 파는 이 하나(climb_digger.gd — 더미 노드 아래 Stick3D)가 무더기에서 40 px 오른쪽에 카메라를 보고 서서, 쌓인 더미를 삽 곁에 아무도 없이 탑의 1분 두면 삽으로 가 소매를 걷고(sleeve) 같은 dig(count 거짓)·같은 shovel 로 마지막 삽까지 판다; 플레이어가 파면 되메워진 뒤 1 s 에 따라 파고, 플레이어가 파는 동안은 집에서 기다리고, 플레이어가 바퀴 중에 떠나면(_away 가 left_t 를 적는다) 바로 와서 남은 삽을 판다. 로더가 할 일은 없다 — 팩이 짓고 틱을 준다.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_drift.gd

const PACK := "res://data/climb/drift.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_LO := 20.0      # taken 조각이 이 발판의 것인가: y 가 발판 윗면 − BAND_LO 부터 + BAND_HI 앞까지(run 152 의 띠 규칙)
const BAND_HI := 60.0
const SIDE := 10.0         # 더미 자리의 x 여유(px) — 손 하나
const DIGGING := ["thrust", "lever", "heave"]   # C 를 쥐고 잇는 바퀴의 단계들
const PLANT_S := 0.3       # 바퀴 끝의 삽이 꽂힌 자리로 돌아가는 시간(s) — stop_s 와 같이 간다

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.drift
var drifts: Array = []          # 지은 더미 {id, kind "drift", n, hop_id, hop_w, wx, x, w, y, y_top, z, d, scoops, dug, st, ph, t0, end_t0, held, fig, count, star_t0, refill_t0, day, deep, digs, stars, me_t, left_t, node, mound, heap, shovel, star, fall, crunch, chime, hush, digger}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("drift", {})

func sync(now: float) -> void:
	t = now

func min_w() -> float:
	return maxf(4.0 * C.HW, float(kind.get("min_w", 100.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 14.0)))

func drift_d() -> float:
	return maxf(8.0, float(kind.get("drift_d", 24.0)))

func drift_w() -> float:
	return maxf(8.0, float(kind.get("drift_w", 44.0)))

func drift_h() -> float:
	return maxf(2.0, float(kind.get("drift_h", 18.0)))

func heap_dx() -> float:
	return maxf(drift_w() * 0.5, float(kind.get("heap_dx", 30.0)))

func handle_h() -> float:
	return maxf(drift_h(), float(kind.get("handle_h", 46.0)))

func col_w() -> float:
	return maxf(drift_w() * 0.5, float(kind.get("col_w", 30.0)))

## 층 n 의 더미 깊이(삽 수) — 다섯 층에 걸쳐 scoops_base 부터 scoops_step 씩
func scoops_of(n: int) -> int:
	return maxi(1, int(kind.get("scoops_base", 4)) + (n % C.REST_EVERY) * int(kind.get("scoops_step", 1)))

func thrust_s() -> float:
	return maxf(0.05, float(kind.get("thrust_s", 0.25)))

func lever_s() -> float:
	return maxf(0.05, float(kind.get("lever_s", 0.3)))

func heave_s() -> float:
	return maxf(0.05, float(kind.get("heave_s", 0.35)))

## 한 삽(s) — 찌르기부터 퍼 넘기기까지
func cycle_s() -> float:
	return thrust_s() + lever_s() + heave_s()

func stop_s() -> float:
	return maxf(0.05, float(kind.get("stop_s", 0.3)))

func star_h() -> float:
	return maxf(drift_h(), float(kind.get("star_h", 40.0)))

func rise_s() -> float:
	return maxf(0.05, float(kind.get("rise_s", 0.8)))

func gaze_s() -> float:
	return maxf(0.05, float(kind.get("gaze_s", 0.6)))

func hang_s() -> float:
	return maxf(1.0, float(kind.get("hang_s", 90.0)))

func sink_s() -> float:
	return maxf(0.05, float(kind.get("sink_s", 1.0)))

func refill_s() -> float:
	return maxf(0.05, float(kind.get("refill_s", 2.0)))

func day_s() -> float:
	return maxf(1.0, float(kind.get("day_s", 600.0)))

## 탑의 오늘 — 로더의 시계를 day_s 로 나눈 몫
func day() -> int:
	return floori(t / day_s())

## 층 n(테마 층)의 still 발판(조각의 on) 중 min_w 보다 넓고, 한가운데 위 기둥(± col_w, 손잡이 꼭대기까지)을 다른 발판이 가르지 않고, taken 조각이 더미·무더기 자리의 띠 안에 없는 것들 중 가장 넓은 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var half := drift_w() / 2.0; var foot_w := half + heap_dx() + half * 0.8   # 더미 왼끝부터 무더기 오른끝까지
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var kinds: Array = piece.get("on", ["std"])
		var found: Array = []
		for hv in plats:
			var p: Dictionary = hv
			if not (String(p["kind"]) in kinds): continue
			var w := float(p["w"]); var y := float(p["y"])
			if w < min_w(): continue
			var wx := float(p["x"]) + w / 2.0
			if not _clear(plats, [p["id"]], wx - col_w(), wx + col_w(), y + 1.0, y + handle_h() + 10.0): continue   # 삽 손잡이·별의 기둥 — 다른 발판이 들면 비킨다
			if not _free(taken, wx - half - SIDE, wx - half + foot_w + SIDE, y - BAND_LO, y + BAND_HI): continue   # 더미·무더기 자리 — 고드름·등롱·그네·초 계단·망원경·외줄이 쓰는 발판이면 비킨다
			found.append({ "hop_id": String(p["id"]), "hop_w": w, "wx": wx, "x": wx - half, "w": foot_w, "y": y })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["hop_w"]) > float(q["hop_w"]) if float(p["hop_w"]) != float(q["hop_w"]) else float(p["y"]) < float(q["y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.D%d" % [n, i]; s["kind"] = "drift"; s["n"] = n
			s["scoops"] = scoops_of(n)
			s["y_top"] = float(g["y"]) + handle_h() + 4.0   # 손잡이 꼭대기 — 다른 팩의 _free 가 읽는 키
			s["z"] = C.WALL_Z + drift_d() / 2.0; s["d"] = drift_d()   # 더미·삽의 깊이 — 절벽에서 drift_d 까지
			out.append(s)
	return out

## 기둥 상자에 그 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x, w, y, 있으면 len·b_y·floor·y_top·hp·beam_y·rail_y 까지 — 등롱 장대는 y..y+len, 고드름은 floor..y, 그네는 y..hp)이 자리의 x 와 겹치고 높이 띠 [ylo, yhi) 에 들면 그 자리는 그 팩의 것
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

## 발판에 선 매 틱 — {busy, k, id}: 더미 발판의 삽 곁(HW + reach, 걷는 선)에 선 몸이 C 를 누르면(더미가 쌓여 있을 때) 파기 시작하고(ph thrust, meta shovel_t 바퀴 안의 시간), 바퀴가 시간으로 넘어가며(thrust → lever → heave), 바퀴 끝에 한 삽을 세고 C 가 쥐어져 있으면 다음 바퀴, 놓였으면 삽을 꽂는다(stop); 마지막 삽에 별이 뜨고 올려다본다(gaze) — 끝까지 busy. k 는 판 몫 0..1.
## 남이 파는 더미는 기다린다(busy 거짓). 별이 뜬·되메워지는 더미(st dug·refill)의 C 는 아무것도 아니다. 삽에서 떠난 몸(다른 발판·먼 x)이 바퀴 중이었으면 그 삽은 버리고 그 몸은 바로 풀린다(판 것은 남는다)
func dig(x: float, z: float, on: Dictionary, pressed: bool, fig: Stick3D = null, count := true) -> Dictionary:
	var none := { "busy": false, "k": 0.0, "id": "" }
	var oid := String(on.get("id", ""))
	for sv in drifts:
		var s: Dictionary = sv
		if oid != String(s["hop_id"]) or absf(z - C.PLAYER_Z) >= C.HZ + 4.0 or absf(x - float(s["wx"])) > C.HW + reach(): continue
		var r := none.duplicate(); r["id"] = String(s["id"])
		if String(s["ph"]) == "":
			if not pressed or String(s["st"]) != "heaped": return r
			s["ph"] = "thrust"; s["t0"] = t; s["held"] = true; s["fig"] = fig; s["count"] = count; s["digs"] = int(s["digs"]) + 1
			if fig: fig.set_meta("shovel_t", 0.0)
			_play(s["crunch"] as AudioStreamPlayer3D)
			r["busy"] = true; return r
		if (s["fig"] as Stick3D) != fig: return r   # 남의 파기 — 기다린다
		s["held"] = pressed
		if String(s["ph"]) in DIGGING: _dig(s)
		r["busy"] = true; r["k"] = dug_k(s); return r
	_away(fig)
	return none

## 판 몫 0..1 — 더미의 삽 수 중 퍼낸 수
func dug_k(s: Dictionary) -> float:
	return clampf(float(s["dug"]) / float(s["scoops"]), 0.0, 1.0)

## 어느 삽 곁에도 없는 몸 — 바퀴 중이었으면 그 삽은 버리고 몸은 바로 풀린다(판 것은 남는다; 바라봄·멈춤은 제 때에 끝난다). 플레이어(count)가 떠난 때는 left_t 에 — 파는 이가 와서 마친다
func _away(fig: Stick3D) -> void:
	if fig == null: return
	for sv in drifts:
		var s: Dictionary = sv
		if (s["fig"] as Stick3D) == fig and String(s["ph"]) in DIGGING:
			s["ph"] = ""; s["held"] = false
			if bool(s["count"]): s["left_t"] = t
			_release(s)

## 이 몸이 어느 더미든 파고 있나(바라봄·멈춤까지) — 로더가 무더기 쪽을 보게 한다
func digging(fig: Stick3D) -> bool:
	for sv in drifts:
		if String((sv as Dictionary)["ph"]) != "" and ((sv as Dictionary)["fig"] as Stick3D) == fig: return true
	return false

## 파기에서 떠난 몸 — 자세의 메타를 거둔다
func leave(fig: Stick3D) -> void:
	if fig == null: return
	for key: String in ["shovel_t", "shovel_end", "shovel_u"]:
		if fig.has_meta(key): fig.remove_meta(key)

func _release(s: Dictionary) -> void:
	leave(s["fig"] as Stick3D)
	s["fig"] = null

## 바퀴의 시계 — 바퀴에 든 뒤 시간으로 단계가 넘어간다; 바퀴 끝에 한 삽: 무더기에 퍼프, 마지막이면 별이 뜨고(gaze), 아니면 쥐었으면 다음 바퀴(crunch)·놓았으면 삽을 꽂는다(stop)
func _dig(s: Dictionary) -> void:
	if not (String(s["ph"]) in DIGGING): return
	var u := t - float(s["t0"])
	var fig: Stick3D = s["fig"]
	if fig: fig.set_meta("shovel_t", u)
	if u < thrust_s(): s["ph"] = "thrust"
	elif u < thrust_s() + lever_s(): s["ph"] = "lever"
	elif u < cycle_s(): s["ph"] = "heave"
	else:
		s["dug"] = int(s["dug"]) + 1
		if is_inside_tree(): Jump3D.dust(self, C.to3(float(s["wx"]) + heap_dx(), float(s["y"]), float(s["z"]) * C.K), 0.35)   # 무더기에 떨어지는 별가루 — 로더의 착지 먼지 그대로
		if int(s["dug"]) >= int(s["scoops"]):
			s["st"] = "dug"; s["ph"] = "gaze"; s["end_t0"] = t; s["star_t0"] = t; s["stars"] = int(s["stars"]) + 1
			if bool(s["count"]): s["day"] = day(); s["deep"] = int(s["scoops"]); s["me_t"] = t   # 플레이어가 팠다 — 판에 세고, 주민 반쪽이 기다렸다 따라 판다
			_play(s["chime"] as AudioStreamPlayer3D)
			if fig: fig.set_meta("shovel_end", "star"); fig.set_meta("shovel_u", 0.0)
		elif bool(s["held"]):
			s["ph"] = "thrust"; s["t0"] = t
			if fig: fig.set_meta("shovel_t", 0.0)
			_play(s["crunch"] as AudioStreamPlayer3D)
		else:
			s["ph"] = "stop"; s["end_t0"] = t
			if fig: fig.set_meta("shovel_end", "stop"); fig.set_meta("shovel_u", 0.0)

## 바라봄·멈춤의 끝 — 제 시간이 지나면 몸이 풀린다
func _end(s: Dictionary) -> void:
	var ph := String(s["ph"]); var eu := t - float(s["end_t0"])
	var fig: Stick3D = s["fig"]
	if fig: fig.set_meta("shovel_u", eu)
	if (ph == "gaze" and eu >= gaze_s()) or (ph == "stop" and eu >= stop_s()): s["ph"] = ""; s["held"] = false; _release(s)

## 뜬 별 — hang_s 가 지나면 가라앉고(refill, hush, 별가루가 내린다) sink_s + refill_s 뒤 다시 쌓인 더미(heaped, dug 0)
func _hang(s: Dictionary) -> void:
	if String(s["st"]) == "dug" and t - float(s["star_t0"]) >= hang_s():
		s["st"] = "refill"; s["refill_t0"] = t
		_play(s["hush"] as AudioStreamPlayer3D)
		if is_inside_tree(): (s["fall"] as CPUParticles3D).emitting = true; (s["fall"] as CPUParticles3D).restart()
	elif String(s["st"]) == "refill" and t - float(s["refill_t0"]) >= sink_s() + refill_s():
		s["st"] = "heaped"; s["dug"] = 0

## 더미의 높이 0..1 — 판 만큼 낮고, 되메워지는 동안 sink_s 뒤 refill_s 에 걸쳐 돌아온다
func mound_k(s: Dictionary) -> float:
	var k := 1.0 - dug_k(s)
	if String(s["st"]) == "refill": k = lerpf(k, 1.0, smoothstep(sink_s(), sink_s() + refill_s(), t - float(s["refill_t0"])))
	return k

## 별의 높이(px, 발판 위) — 뜨는 rise_s, 걸린 동안 0.5 Hz 로 3 px 까딱, 가라앉는 sink_s; 쌓인 더미엔 없다(−1)
func star_h_now(s: Dictionary) -> float:
	var st := String(s["st"])
	if st == "dug":
		var u := t - float(s["star_t0"])
		return star_h() * smoothstep(0.0, rise_s(), u) + 3.0 * sin(u * TAU * 0.5) * smoothstep(rise_s(), rise_s() + 1.0, u)
	if st == "refill": return star_h() * (1.0 - smoothstep(0.0, sink_s(), t - float(s["refill_t0"])))
	return -1.0

## n0..n1 층의 지은 더미에서 오늘 다 판 수·전체·오늘 판 것 중 가장 깊은 삽 수·지금 별이 뜬 수 — {dug, total, deepest, up}
func dug_today(n0: int, n1: int) -> Dictionary:
	var dug := 0; var total := 0; var deepest := 0; var up := 0
	for sv in drifts:
		var s: Dictionary = sv
		if int(s["n"]) < n0 or int(s["n"]) > n1: continue
		total += 1
		if int(s["day"]) == day(): dug += 1; deepest = maxi(deepest, int(s["deep"]))
		if String(s["st"]) == "dug": up += 1
	return { "dug": dug, "total": total, "deepest": deepest, "up": up }

## 쉼터 판(n 층)에 붙는 줄 — 위 다섯 층(n..n+4)의 더미, 없으면 아래 다섯 층(n−5..n−1), 그것도 없으면 빈 줄. climb_signs.notes 에 넣는다
func note(n: int) -> String:
	for span: Array in [[n, n + 4], [n - 5, n - 1]]:
		var v := dug_today(int(span[0]), int(span[1]))
		if int(v["total"]) > 0:
			var line := "Stardust drifts, floors %d–%d: %d of %d dug out today" % [int(span[0]), int(span[1]), int(v["dug"]), int(v["total"])]
			if int(v["dug"]) > 0: line += ", the deepest %d scoops" % int(v["deepest"])
			if int(v["up"]) > 0: line += ", %d %s up" % [int(v["up"]), "star" if int(v["up"]) == 1 else "stars"]
			return line + "."
	return ""

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 바퀴·별·그림을 지금으로
func _process(delta: float) -> void:
	t += delta
	drifts = drifts.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_green 과 같은 식)
	for sv in drifts:
		var s: Dictionary = sv
		if String(s["ph"]) in DIGGING: _dig(s)
		if String(s["ph"]) in ["gaze", "stop"]: _end(s)
		_hang(s); _place(s)
		if s.has("digger"): (s["digger"] as ClimbDigger).step(delta)   # 파는 이의 틱 — 더미가 돈 뒤라 되메움·떠남을 같은 틱에 본다

## 더미·무더기·삽·별을 지금으로 — 더미는 판 만큼 납작, 무더기는 판 만큼 높게; 삽은 바퀴 따라 찌르고 젖히고 퍼 넘기다 끝에 꽂힌 자리로 돌아온다; 별은 제 높이에서 0.3 Hz 로 돈다
func _place(s: Dictionary) -> void:
	var mk := maxf(0.04, mound_k(s)); var hk := 1.0 - mound_k(s)
	(s["mound"] as Node3D).scale = Vector3(1.0, mk, 0.8)
	(s["heap"] as Node3D).scale = Vector3(0.8, maxf(0.02, hk * 0.9), 0.7)
	var sh: Node3D = s["shovel"]; var p := _shovel_at(s)
	sh.position = Vector3(float(p["dx"]) * C.K, float(p["dy"]) * C.K, drift_d() * C.K / 2.0); sh.rotation.z = -float(p["tilt"])
	var star: Node3D = s["star"]; var h := star_h_now(s)
	star.visible = h >= 0.0
	if star.visible: star.position.y = (drift_h() * 0.3 + maxf(0.0, h)) * C.K; star.rotation.y = t * TAU * 0.3

## 삽의 자리 {dx, dy, tilt}(px·rad, 더미 가운데 기준): 꽂힌 삽은 더미 왼쪽 어깨에 기울어 서 있고(plant), 찌르기엔 무더기에서 더미로 돌아와 날이 박히고, 지렛대에 젖혀지고, 헤이브에 떠서 무더기 위로 가 쏟는다; 바라봄·멈춤엔 PLANT_S 에 걸쳐 꽂힌 자리로
func _shovel_at(s: Dictionary) -> Dictionary:
	var plant := { "dx": -drift_w() * 0.15, "dy": 0.0, "tilt": 0.25 }
	var heap := { "dx": heap_dx(), "dy": 22.0, "tilt": 1.4 }
	var ph := String(s["ph"])
	if ph == "": return plant
	if ph == "gaze" or ph == "stop": return _mix(heap, plant, smoothstep(0.0, PLANT_S, t - float(s["end_t0"])))
	var u := t - float(s["t0"])
	var into := { "dx": 0.0, "dy": -6.0, "tilt": 0.5 }; var back := { "dx": 0.0, "dy": 0.0, "tilt": 0.9 }
	if u < thrust_s(): return _mix(heap if int(s["dug"]) > 0 else plant, into, smoothstep(0.0, thrust_s(), u))
	if u < thrust_s() + lever_s(): return _mix(into, back, smoothstep(thrust_s(), thrust_s() + lever_s(), u))
	return _mix(back, heap, smoothstep(thrust_s() + lever_s(), cycle_s(), u))

static func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	return { "dx": lerpf(float(a["dx"]), float(b["dx"]), k), "dy": lerpf(float(a["dy"]), float(b["dy"]), k), "tilt": lerpf(float(a["tilt"]), float(b["tilt"]), k) }

## 더미를 짓는다 — root 는 그 층의 노드. 노드 원점은 (더미의 x, 발판 윗면, 절벽); 별가루 더미(납작 공, _place 가 눌러 낮춘다)·무더기(오른쪽, 자란다)·삽(손잡이·T 자루·날·강조색 띠 한 조각)·별(네 꼭지, 금빛, 뜰 때만)·내리는 별가루·소리 셋
func build(root: Node3D, planned: Array) -> void:
	var zc := drift_d() * C.K / 2.0
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(false)
		var node := Node3D.new(); node.position = C.to3(float(s["wx"]), float(s["y"]), C.WALL_Z * C.K); root.add_child(node)
		var dust := _mat(Color("efe2b4")); var iron := _mat(Color("4a4a52")); var wood := _mat(Color("8a6a4a")); var gold := _mat(Color("f2c84b"), true); var acc := _mat(Color("ad7096"), true)
		var mound := Node3D.new(); mound.position = Vector3(0.0, 0.0, zc); node.add_child(mound)
		_ball(mound, drift_w() * C.K / 2.0, drift_h() * C.K, dust)   # 더미 — 납작 공, 발판에 반쯤 묻힌 꼴
		var heap := Node3D.new(); heap.position = Vector3(heap_dx() * C.K, 0.0, zc); node.add_child(heap)
		_ball(heap, drift_w() * C.K / 2.0, drift_h() * C.K, dust)   # 무더기 — 같은 공, 판 만큼 자란다
		var shovel := Node3D.new(); node.add_child(shovel)
		var hh := handle_h() * C.K
		_box(shovel, Vector3(0.02, hh, 0.02), wood).position = Vector3(0.0, hh / 2.0, 0.0)   # 손잡이
		_box(shovel, Vector3(0.09, 0.02, 0.02), wood).position = Vector3(0.0, hh, 0.0)   # T 자루
		_box(shovel, Vector3(0.11, 0.13, 0.01), iron).position = Vector3(0.0, 0.04, 0.0)   # 날 — 끝이 더미에 박힌다
		_box(shovel, Vector3(0.024, 0.05, 0.024), acc).position = Vector3(0.0, hh * 0.8, 0.0)   # 손잡이의 띠 — 강조색은 이 한 조각
		var star := Node3D.new(); star.position = Vector3(0.0, 0.0, zc); node.add_child(star)
		_box(star, Vector3(0.16, 0.03, 0.02), gold)   # 네 꼭지 별 — 가로
		_box(star, Vector3(0.03, 0.16, 0.02), gold)   # 세로
		var core := _box(star, Vector3(0.05, 0.05, 0.03), gold); core.rotation.z = PI / 4.0   # 가운데 — 비스듬한 네모
		star.visible = false
		var fall := _fall(node, zc)
		s["node"] = node; s["mound"] = mound; s["heap"] = heap; s["shovel"] = shovel; s["star"] = star; s["fall"] = fall
		s["st"] = "heaped"; s["ph"] = ""; s["t0"] = -99.0; s["end_t0"] = -99.0; s["held"] = false; s["fig"] = null; s["count"] = true
		s["dug"] = 0; s["star_t0"] = -99.0; s["refill_t0"] = -99.0; s["day"] = -1; s["deep"] = 0; s["digs"] = 0; s["stars"] = 0; s["me_t"] = -99.0; s["left_t"] = -99.0
		s["crunch"] = _snd(node, float(kind.get("crunch_hz", 180)), 0.12, -14.0, false); s["chime"] = _snd(node, float(kind.get("chime_hz", 2200)), 0.3, -12.0, true); s["hush"] = _snd(node, float(kind.get("hush_hz", 120)), 0.5, -16.0, false)
		s["digger"] = ClimbDigger.new(self, s, node)   # 주민 반쪽 — 무더기 곁에 카메라를 보고 선 파는 이
		drifts.append(s)
		_place(s)

## 되메움의 별가루 — 손잡이 높이에서 refill_s 동안 내리는 한 번짜리 낱알(restart 로 다시)
func _fall(parent: Node3D, zc: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 24; p.lifetime = refill_s(); p.one_shot = true; p.explosiveness = 0.2; p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; p.emission_box_extents = Vector3(drift_w() * C.K / 2.0, 0.02, drift_d() * C.K / 3.0)
	p.direction = Vector3(0.0, -1.0, 0.0); p.spread = 10.0; p.gravity = Vector3(0.0, -0.6, 0.0)
	p.initial_velocity_min = 0.1; p.initial_velocity_max = 0.3
	var bm := BoxMesh.new(); bm.size = Vector3(0.02, 0.02, 0.02); bm.material = _mat(Color("f2c84b"), true); p.mesh = bm
	p.position = Vector3(0.0, handle_h() * C.K, zc)
	parent.add_child(p); return p

func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 납작 공 — 반지름 r 의 공을 높이 h 로 눌러(부모의 scale 은 _place 가 쓴다) 원점이 바닥에 오게
func _ball(parent: Node3D, r: float, h: float, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 12; sm.rings = 6
	mi.mesh = sm; mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(1.0, h / r, 1.0); mi.position = Vector3(0.0, 0.0, 0.0)
	parent.add_child(mi); return mi

func _snd(parent: Node3D, hz: float, secs: float, db: float, twice: bool) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs, twice); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — 짧은 기음이 잦아든다: crunch(0.12초, 낮게 — 날이 별가루에 박힌다)·chime(0.3초, 두 번 — 별이 드러난다)·hush(0.5초, 아주 낮게 — 더미가 되메워진다). 한 번 재생, 반복 없음
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
