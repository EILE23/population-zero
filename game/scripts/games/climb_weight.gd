class_name ClimbWeight
extends Node3D
## Climb 콘텐츠 팩 '시계추'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 태엽(Clockwork) 층의 still std 발판 중 min_w 보다 넓고 다른 팩이 안 쓴 가장 넓은 것 — 그 한가운데 절벽 쪽(weight_d 안, 앞길은 비어 있다)에 놋쇠 추가 바닥에 내려앉아 있고, 추의 사슬이 drum_h 위의 북(drum)으로 오르며 북 오른쪽엔 바늘 하나짜리 다이얼. 다 풀린 시계: 추는 바닥에, 바늘은 멈춰 있다.
## 추 곁(HW + reach)에서 C(추가 바닥에 있을 때): 쪼그려 잡고(grip_s) 가슴까지 끌어올려(clean_s, 추 밑이 chest_h) 머리 위로 밀어 올린 뒤(press_s, head_h) hold_s 동안 C 를 쥐고 버틴다(무게 kg 마다 길다 — hold_base + hold_per_kg × kg)
## → 다 버티면 사슬이 추를 받아(hook_s) 고리 높이 hook_h 에 걸리고 시계가 돈다: 추가 run_s 동안 바닥까지 가라앉으며 북이 돌고 바늘이 한 바퀴, tick_s 마다 째깍 — 바닥에 닿으면 clank, 다시 다 풀린 시계. 버티다 놓으면 추가 떨어진다(drop_s, thud·먼지) — 세지 않는다, 몸은 recover_s 에 풀린다.
## 그동안 몸은 busy(걷기·점프 없음), 자세는 press(stick3d_press.gd — 운영자 보드의 '역도' 가족: 쪼그려 잡기 → 클린(가슴, 받는 딥) → 프레스(머리 위, 다리가 앞뒤로 갈린다) → 버티기(10 Hz 떨림, 1.5 Hz 흔들림) → 걸고 팔을 내리며 어깨를 턴다 / 놓치고 움츠린다 — 정지화가 아니다). 드는 이는 카메라를 본다.
## 추는 단단하지 않고 값도 없다. 감은 시계는 탑의 하루(day_s)에 한 번 센다 — 쉼터 판이 note(n) 으로 읽는다('Clock weights, floors 15–19: 2 of 3 clocks wound today, the heaviest 14 kg.').
## 추 곁에서 C 를 누르지 않는 몸에겐 아무것도 바뀌지 않는다: 발판을 달려 지나는 길, 맨 점프, 다른 데서의 C(쉼터 문·판)는 그대로(평이한 결과 100%). 돌고 있는 시계의 추 곁 C 도 아무것도 아니다(추가 공중에 있다).
## 풀무(발로 다른 자리를 올린다)·윈치(손으로 감는다)·그린(공을 보낸다)과 다르다: 이건 제 팔로 무게를 머리 위에 버티는 몸 — 버틴 시간이 시계의 1분이 된다. 탑에서 사람의 힘이 기계를 감는 첫 조각.
## 로더가 할 일(climb.gd, 운영자 세션): `var cw := ClimbWeight.new(); add_child(cw); signs.notes.append(cw.note)`; 층을 지을 때 `var ck := cg.plan(n, plats) + cpn.plan(n, plats) + pk.plan(n, plats); var bl := cl.plan(n, plats, ck); cw.build(root, cw.plan(n, plats, ck + bl + ew.plan(n, plats, ck + bl)))`
## (톱니 띠·추·뻐꾸기 집·풀무·핀 바퀴의 계획을 taken 으로 — 그 발판은 비켜 간다); 매 틱 `cw.sync(_t)`;
## 발판에 선 가지에서(매달림·붙잡음이 비고 `on` 이 찼을 때, jump_held 를 읽기 전에) `var lw := cw.lift(x, z, on, Input.is_action_pressed("act"), fig); if lw["busy"]: dir = 0.0; jump_held = false; charge = 0.0; fig.pose_request = "press" elif fig.pose_request == "press": fig.pose_request = ""`
## (팩이 meta press_t·press_end·press_u 를 적고 끝나면 지운다); `_figure()` 의 face 가지 앞에 `if cw.lifting(fig): fig.face(0.0)` (드는 이는 카메라를 본다); 공중에선 부르지 않는다. 쉼터 판 C 는 signs.tick 이 먼저 — 추는 std 발판에만 선다.
## lift 의 count: 비우면 플레이어(판에 세고 me_t 를 적는다 — 주민 반쪽이 다음 run 에 기다렸다 따라 든다), 다른 몸은 거짓을 준다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_weight.gd

const PACK := "res://data/climb/weight.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_LO := 20.0      # taken 조각이 이 발판의 것인가: y 가 발판 윗면 − BAND_LO 부터 + BAND_HI 앞까지(run 152 의 띠 규칙)
const BAND_HI := 60.0
const SIDE := 10.0         # 추 자리의 x 여유(px) — 손 하나
const LIFTING := ["grip", "clean", "press", "hold"]   # C 를 쥐고 있어야 하는 단계들

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.weight
var weights: Array = []         # 지은 추 {id, kind "weight", n, hop_id, hop_w, wx, x, w, y, y_top, z, d, kg, hold_s, st, ph, t0, end_t0, h, h0, fig, count, wound_t0, tick_i, day, lifts, drops, me_t, node, w_node, chain, drum, hand, thud, clank, tick}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("weight", {})

func sync(now: float) -> void:
	t = now

func min_w() -> float:
	return maxf(4.0 * C.HW, float(kind.get("min_w", 110.0)))

func reach() -> float:
	return maxf(0.0, float(kind.get("reach", 14.0)))

func weight_d() -> float:
	return maxf(8.0, float(kind.get("weight_d", 24.0)))

func weight_r() -> float:
	return maxf(2.0, float(kind.get("weight_r", 9.0)))

func weight_h() -> float:
	return maxf(2.0, float(kind.get("weight_h", 14.0)))

func col_w() -> float:
	return maxf(weight_r(), float(kind.get("col_w", 40.0)))

## 층 n 의 추 무게(kg) — 다섯 층에 걸쳐 kg_base 부터 kg_step 씩
func kg_of(n: int) -> int:
	return int(kind.get("kg_base", 8)) + (n % C.REST_EVERY) * int(kind.get("kg_step", 2))

func grip_s() -> float:
	return maxf(0.05, float(kind.get("grip_s", 0.3)))

func clean_s() -> float:
	return maxf(0.05, float(kind.get("clean_s", 0.3)))

func press_s() -> float:
	return maxf(0.05, float(kind.get("press_s", 0.35)))

## 잡기부터 머리 위까지(s) — 그 뒤가 버티기
func rise_s() -> float:
	return grip_s() + clean_s() + press_s()

func chest_h() -> float:
	return maxf(0.0, float(kind.get("chest_h", 30.0)))

func head_h() -> float:
	return maxf(chest_h(), float(kind.get("head_h", 50.0)))

## kg 의 추를 버텨야 하는 시간(s)
func hold_of(kg: int) -> float:
	return maxf(0.1, float(kind.get("hold_base", 0.6)) + float(kind.get("hold_per_kg", 0.05)) * kg)

func hook_s() -> float:
	return maxf(0.05, float(kind.get("hook_s", 0.3)))

func drop_s() -> float:
	return maxf(0.05, float(kind.get("drop_s", 0.25)))

func recover_s() -> float:
	return maxf(drop_s(), float(kind.get("recover_s", 0.4)))

func hook_h() -> float:
	return maxf(head_h(), float(kind.get("hook_h", 60.0)))

func drum_h() -> float:
	return maxf(hook_h() + weight_h(), float(kind.get("drum_h", 76.0)))

func drum_r() -> float:
	return maxf(2.0, float(kind.get("drum_r", 8.0)))

func dial_r() -> float:
	return maxf(4.0, float(kind.get("dial_r", 12.0)))

func run_s() -> float:
	return maxf(1.0, float(kind.get("run_s", 60.0)))

func tick_s() -> float:
	return maxf(0.1, float(kind.get("tick_s", 1.0)))

func day_s() -> float:
	return maxf(1.0, float(kind.get("day_s", 600.0)))

## 탑의 오늘 — 로더의 시계를 day_s 로 나눈 몫
func day() -> int:
	return floori(t / day_s())

## 층 n(테마 층)의 still 발판(조각의 on) 중 min_w 보다 넓고, 한가운데 위 기둥(± col_w, 다이얼 꼭대기까지)을 다른 발판이 가르지 않고, taken 조각이 추 자리의 띠 안에 없는 것들 중 가장 넓은 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
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
			if not _clear(plats, [p["id"]], wx - col_w(), wx + col_w(), y + 1.0, y + drum_h() + dial_r() + 10.0): continue   # 사슬·북·다이얼 기둥 — 다른 발판이 들면 비킨다
			if not _free(taken, wx - weight_r() - SIDE, wx + weight_r() + SIDE, y - BAND_LO, y + BAND_HI): continue   # 추 자리(_free 가 손 하나 10 을 더한다) — 띠·뻐꾸기 집·풀무·핀 바퀴가 쓰는 발판이면 비킨다
			found.append({ "hop_id": String(p["id"]), "hop_w": w, "wx": wx, "x": wx - weight_r(), "w": weight_r() * 2.0, "y": y, "hz": float(p.get("z", C.WALL_Z + C.DEPTH_HALF)), "hd": float(p.get("d", C.DEPTH_HALF * 2.0)) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["hop_w"]) > float(q["hop_w"]) if float(p["hop_w"]) != float(q["hop_w"]) else float(p["y"]) < float(q["y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.W%d" % [n, i]; s["kind"] = "weight"; s["n"] = n
			s["kg"] = kg_of(n); s["hold_s"] = hold_of(kg_of(n))
			s["y_top"] = float(g["y"]) + drum_h() + dial_r()   # 다이얼 꼭대기 — 다른 팩의 _free 가 읽는 키
			s["z"] = C.WALL_Z + weight_d() / 2.0; s["d"] = weight_d()   # 추·북의 깊이 — 절벽에서 weight_d 까지
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

## 다른 팩의 조각(taken: x, 있으면 w·rail_y·beam_y·y_top)이 자리의 x 와 겹치고 높이 띠 [ylo, yhi) 에 들면 그 자리는 그 팩의 것
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qtop := qy
		for key: String in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qtop = maxf(qtop, float(q[key]))
		if x1 > qx0 and x0 < qx1 and qtop >= ylo and qy < yhi: return false
	return true

## 발판에 선 매 틱 — {busy, k, id}: 추 발판의 추 곁(HW + reach, 걷는 선)에 선 몸이 C 를 누르면(추가 바닥에 있을 때) 들기 시작하고(ph grip, meta press_t 든 뒤 시간), 쥐고 있는 동안 단계가 시간으로 넘어가며(clean → press → hold), 버티기를 다 채우면 걸고(hook) 놓치면 떨어뜨린다(drop) — 끝까지 busy. k 는 버티기 0..1.
## 남이 드는 추는 기다린다(busy 거짓). 돌고 있는 시계(st wound)의 C 는 아무것도 아니다. 추에서 떠난 몸(다른 발판·먼 x)이 들던 중이었으면 추는 떨어지고 그 몸은 바로 풀린다
func lift(x: float, z: float, on: Dictionary, pressed: bool, fig: Stick3D = null, count := true) -> Dictionary:
	var none := { "busy": false, "k": 0.0, "id": "" }
	var oid := String(on.get("id", ""))
	for sv in weights:
		var s: Dictionary = sv
		if oid != String(s["hop_id"]) or absf(z - C.PLAYER_Z) >= C.HZ + 4.0 or absf(x - float(s["wx"])) > C.HW + reach(): continue
		var r := none.duplicate(); r["id"] = String(s["id"])
		if String(s["ph"]) == "":
			if not pressed or String(s["st"]) != "down": return r
			s["st"] = "lift"; s["ph"] = "grip"; s["t0"] = t; s["fig"] = fig; s["count"] = count; s["lifts"] = int(s["lifts"]) + 1
			if fig: fig.set_meta("press_t", 0.0)
			r["busy"] = true; return r
		if (s["fig"] as Stick3D) != fig: return r   # 남의 들기 — 기다린다
		if String(s["ph"]) in LIFTING:
			if pressed: _lift(s)
			else: _drop(s)
		r["busy"] = true; r["k"] = hold_k(s); return r
	_away(fig)
	return none

## 버티기 0..1 — 머리 위에 올린 뒤 hold_s 중 지난 몫
func hold_k(s: Dictionary) -> float:
	if String(s["ph"]) == "hook": return 1.0
	if not (String(s["ph"]) in LIFTING): return 0.0
	return clampf((t - float(s["t0"]) - rise_s()) / float(s["hold_s"]), 0.0, 1.0)

## 어느 추 곁에도 없는 몸 — 들던 중이었으면 추는 떨어지고 몸은 바로 풀린다(걸기·놓침은 제 때에 끝난다)
func _away(fig: Stick3D) -> void:
	if fig == null: return
	for sv in weights:
		var s: Dictionary = sv
		if (s["fig"] as Stick3D) == fig and String(s["ph"]) in LIFTING: _drop(s); _release(s)

## 이 몸이 어느 추든 들고 있나(걸기·놓침의 회수까지) — 로더가 카메라 쪽을 보게 한다
func lifting(fig: Stick3D) -> bool:
	for sv in weights:
		if String((sv as Dictionary)["ph"]) != "" and ((sv as Dictionary)["fig"] as Stick3D) == fig: return true
	return false

## 들기에서 떠난 몸 — 자세의 메타를 거둔다
func leave(fig: Stick3D) -> void:
	if fig == null: return
	for key: String in ["press_t", "press_end", "press_u"]:
		if fig.has_meta(key): fig.remove_meta(key)

func _release(s: Dictionary) -> void:
	leave(s["fig"] as Stick3D)
	s["fig"] = null

## 들기의 시계 — 든 뒤 시간으로 단계가 넘어간다; 추 밑의 높이 h 도 여기서(클린에 chest_h, 프레스에 head_h, 버티기에 1.5 Hz 흔들림); 버티기를 다 채우면 건다
func _lift(s: Dictionary) -> void:
	if not (String(s["ph"]) in LIFTING): return
	var u := t - float(s["t0"])
	var fig: Stick3D = s["fig"]
	if fig: fig.set_meta("press_t", u)
	if u < grip_s(): s["ph"] = "grip"; s["h"] = 0.0
	elif u < grip_s() + clean_s(): s["ph"] = "clean"; s["h"] = chest_h() * smoothstep(grip_s(), grip_s() + clean_s(), u)
	elif u < rise_s(): s["ph"] = "press"; s["h"] = chest_h() + (head_h() - chest_h()) * smoothstep(grip_s() + clean_s(), rise_s(), u)
	elif u < rise_s() + float(s["hold_s"]): s["ph"] = "hold"; s["h"] = head_h() + 1.5 * sin((u - rise_s()) * TAU * 1.5)
	else:
		s["ph"] = "hook"; s["end_t0"] = t; s["h0"] = float(s["h"])
		if fig: fig.set_meta("press_end", "hook"); fig.set_meta("press_u", 0.0)

## 놓쳤다 — 추가 지금 높이에서 떨어진다(thud 는 바닥에서), 세지 않는다
func _drop(s: Dictionary) -> void:
	if not (String(s["ph"]) in LIFTING): return
	s["ph"] = "drop"; s["end_t0"] = t; s["h0"] = float(s["h"]); s["drops"] = int(s["drops"]) + 1; s["thudded"] = false
	var fig: Stick3D = s["fig"]
	if fig: fig.set_meta("press_end", "drop"); fig.set_meta("press_u", 0.0)

## 걸기·놓침의 끝 — 걸면 시계가 돈다(wound, 오늘 센다), 놓치면 다시 바닥(down); 몸은 풀린다
func _end(s: Dictionary) -> void:
	var ph := String(s["ph"]); var eu := t - float(s["end_t0"])
	var fig: Stick3D = s["fig"]
	if fig: fig.set_meta("press_u", eu)
	if ph == "hook":
		s["h"] = float(s["h0"]) + (hook_h() - float(s["h0"])) * smoothstep(0.0, hook_s(), eu)
		if eu >= hook_s():
			s["st"] = "wound"; s["ph"] = ""; s["wound_t0"] = t; s["tick_i"] = -1; s["h"] = hook_h()
			if bool(s["count"]): s["day"] = day(); s["me_t"] = t   # 플레이어가 감았다 — 주민 반쪽이 기다렸다 따라 든다
			_release(s)
	elif ph == "drop":
		var k := clampf(eu / drop_s(), 0.0, 1.0)
		s["h"] = float(s["h0"]) * (1.0 - k * k)   # 떨어지는 추 — 빨라진다
		if k >= 1.0 and not bool(s["thudded"]):
			s["thudded"] = true; _play(s["thud"] as AudioStreamPlayer3D)
			if is_inside_tree(): Jump3D.dust(self, C.to3(float(s["wx"]), float(s["y"]), float(s["z"]) * C.K), 0.4)   # 추가 받는 바닥의 먼지 — 로더의 착지 먼지 그대로
		if eu >= recover_s(): s["st"] = "down"; s["ph"] = ""; s["h"] = 0.0; _release(s)

## 도는 시계 — 추가 run_s 동안 바닥까지 가라앉고 북이 돌고 바늘이 한 바퀴, tick_s 마다 째깍; 바닥에 닿으면 clank 와 함께 다시 다 풀린 시계
func _run(s: Dictionary) -> void:
	if String(s["st"]) != "wound": return
	var k := (t - float(s["wound_t0"])) / run_s()
	if k >= 1.0:
		s["st"] = "down"; s["h"] = 0.0; (s["hand"] as Node3D).rotation.z = 0.0; (s["drum"] as Node3D).rotation.z = 0.0
		_play(s["clank"] as AudioStreamPlayer3D); return
	s["h"] = hook_h() * (1.0 - k)
	(s["hand"] as Node3D).rotation.z = -TAU * k
	(s["drum"] as Node3D).rotation.z = -(hook_h() * k) / drum_r()   # 사슬이 풀린 만큼 북이 돈다
	var i := floori((t - float(s["wound_t0"])) / tick_s())
	if i > int(s["tick_i"]): s["tick_i"] = i; _play(s["tick"] as AudioStreamPlayer3D)

## n0..n1 층의 지은 추에서 오늘 감은 수·전체·오늘 감은 것 중 가장 무거운 kg·지금 도는 수 — {wound, total, heaviest, running}
func wound_today(n0: int, n1: int) -> Dictionary:
	var wound := 0; var total := 0; var heaviest := 0; var running := 0
	for sv in weights:
		var s: Dictionary = sv
		if int(s["n"]) < n0 or int(s["n"]) > n1: continue
		total += 1
		if int(s["day"]) == day(): wound += 1; heaviest = maxi(heaviest, int(s["kg"]))
		if String(s["st"]) == "wound": running += 1
	return { "wound": wound, "total": total, "heaviest": heaviest, "running": running }

## 쉼터 판(n 층)에 붙는 줄 — 위 다섯 층(n..n+4)의 추, 없으면 아래 다섯 층(n−5..n−1), 그것도 없으면 빈 줄. climb_signs.notes 에 넣는다
func note(n: int) -> String:
	for span: Array in [[n, n + 4], [n - 5, n - 1]]:
		var v := wound_today(int(span[0]), int(span[1]))
		if int(v["total"]) > 0:
			var line := "Clock weights, floors %d–%d: %d of %d %s wound today" % [int(span[0]), int(span[1]), int(v["wound"]), int(v["total"]), "clock" if int(v["total"]) == 1 else "clocks"]
			if int(v["wound"]) > 0: line += ", the heaviest %d kg" % int(v["heaviest"])
			if int(v["running"]) > 0: line += ", %d running" % int(v["running"])
			return line + "."
	return ""

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 들기·시계·그림을 지금으로
func _process(delta: float) -> void:
	t += delta
	weights = weights.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_green 과 같은 식)
	for sv in weights:
		var s: Dictionary = sv
		if String(s["ph"]) in LIFTING: _lift(s)
		if String(s["ph"]) in ["hook", "drop"]: _end(s)
		_run(s); _place(s)

## 추와 사슬을 지금 높이로 — 사슬은 추 꼭대기에서 북 밑까지
func _place(s: Dictionary) -> void:
	var h := float(s["h"]) * C.K; var wh := weight_h() * C.K; var zc := weight_d() * C.K / 2.0
	(s["w_node"] as Node3D).position = Vector3(0.0, h + wh / 2.0, zc)
	var top := h + wh; var ln := maxf(0.01, (drum_h() - drum_r()) * C.K - top)
	var chain: Node3D = s["chain"]; chain.scale.y = ln; chain.position = Vector3(0.0, top + ln / 2.0, zc)

## 추를 짓는다 — root 는 그 층의 노드. 노드 원점은 (추의 x, 발판 윗면, 절벽); 놋쇠 추(제 노드 — _place 가 옮긴다)·사슬·북(돈다)·받침·다이얼·바늘(강조색)·소리 셋
func build(root: Node3D, planned: Array) -> void:
	var zc := weight_d() * C.K / 2.0
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(false)
		var node := Node3D.new(); node.position = C.to3(float(s["wx"]), float(s["y"]), C.WALL_Z * C.K); root.add_child(node)
		var brass := _mat(Color("c9a24a")); var iron := _mat(Color("4a4a52")); var face := _mat(Color("f7f4ef"), true); var acc := _mat(Color("ad7096"), true)
		var w_node := Node3D.new(); node.add_child(w_node)
		var body := _cyl(w_node, weight_r() * C.K, weight_h() * C.K, brass); body.position = Vector3.ZERO   # 놋쇠 추 — 세로 원통
		_box(w_node, Vector3(weight_r() * C.K * 1.4, 0.02, weight_r() * C.K * 1.4), iron).position = Vector3(0.0, weight_h() * C.K / 2.0, 0.0)   # 꼭대기 쇠 테
		_box(w_node, Vector3(0.03, 0.05, 0.015), iron).position = Vector3(0.0, weight_h() * C.K / 2.0 + 0.025, 0.0)   # 고리
		var chain := _box(node, Vector3(0.02, 1.0, 0.02), iron)   # 사슬 — 높이 1 의 막대, _place 가 늘인다
		var dh := drum_h() * C.K; var dr := drum_r() * C.K
		_box(node, Vector3(0.06, 0.06, zc), iron).position = Vector3(0.0, dh, zc / 2.0)   # 받침 — 절벽에서 북까지
		var drum := Node3D.new(); drum.position = Vector3(0.0, dh, zc); node.add_child(drum)
		var dm := _cyl(drum, dr, zc * 0.6, brass); dm.rotation.x = PI / 2.0   # 북 — 축이 카메라 쪽
		_box(drum, Vector3(0.02, dr * 1.8, 0.012), iron).position = Vector3(0.0, 0.0, zc * 0.3 + 0.006)   # 살 하나 — 도는 게 보인다
		var dial := Node3D.new(); dial.position = Vector3((drum_r() + dial_r() + 4.0) * C.K, dh, zc); node.add_child(dial)
		var disc := _cyl(dial, dial_r() * C.K, 0.012, face); disc.rotation.x = PI / 2.0   # 다이얼 — 북 오른쪽
		var hand := Node3D.new(); hand.position.z = 0.012; dial.add_child(hand)
		_box(hand, Vector3(0.015, dial_r() * C.K * 0.8, 0.008), acc).position = Vector3(0.0, dial_r() * C.K * 0.4, 0.0)   # 바늘 — 강조색은 이 한 조각
		s["node"] = node; s["w_node"] = w_node; s["chain"] = chain; s["drum"] = drum; s["hand"] = hand
		s["st"] = "down"; s["ph"] = ""; s["t0"] = -99.0; s["end_t0"] = -99.0; s["h"] = 0.0; s["h0"] = 0.0; s["fig"] = null; s["count"] = true
		s["wound_t0"] = -99.0; s["tick_i"] = -1; s["day"] = -1; s["lifts"] = 0; s["drops"] = 0; s["me_t"] = -99.0; s["thudded"] = false
		s["thud"] = _snd(node, float(kind.get("thud_hz", 90)), 0.18, -12.0, false); s["clank"] = _snd(node, float(kind.get("clank_hz", 1800)), 0.1, -14.0, true); s["tick"] = _snd(node, float(kind.get("tick_hz", 2600)), 0.03, -20.0, false)
		weights.append(s)
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

func _cyl(parent: Node3D, r: float, h: float, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = 12; cm.rings = 1
	mi.mesh = cm; mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi); return mi

func _snd(parent: Node3D, hz: float, secs: float, db: float, twice: bool) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs, twice); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — 짧은 기음이 잦아든다: thud(0.18초, 낮게 — 추가 바닥에 떨어진다)·clank(0.1초, 두 번 — 다 풀린 추가 바닥에 닿는다)·tick(0.03초, 가늘게 — 시계의 째깍). 한 번 재생, 반복 없음
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
