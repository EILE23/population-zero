class_name ClimbGolfer
extends RefCounted
## 골퍼 — 구름 그린 팩(climb_green.gd, run 172)의 주민 반쪽(run 173; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 그린마다 하나, 티 발판에서 못 뒤 BACK(몸 둘 폭)에 카메라를 보고 선 주민.
## 탑의 1분(MINUTE)마다 한 번(층마다 어긋나게), 그리고 플레이어가 친 뒤(팩이 count 참일 때 me_t 에 적는다) REACT 초 뒤에 못으로 걸어가 — 공이 못에 돌아올 때까지(rest_s) 거기 서서 기다리고, 남이 스윙 중이면 더 기다린다(플레이어의 티가 먼저; WAIT_S 넘으면 집으로) —
## 같은 tee()(count 거짓 — 제 샷은 판에 안 세고 me_t 도 안 적는다)로 어드레스하고 같은 stroke 로 친다.
## 모으는 양은 그린의 제 need 에서 고른다: 홀 SHORT px 앞에 떨어뜨리는 속도(need_v(dx − SHORT, dy))의 충전을 가운데로 — 홀 바로 위에 떨어뜨리는 need 그대로면 bounce_v 보다 빨라 튀어 넘어간다 —
## 층·샷 차례(n + swings) % 3 에 따라 OFFS 만큼: 셋에 하나는 들어가고 하나는 짧아 틈에 빠지고 하나는 그린을 넘는다(점검 그린의 홀인 창은 충전 0.67..0.80, 가운데 0.74 — 백로그의 ±0.06 은 셋 다 들어갔을 것이라 ±0.10).
## 스윙이 풀리면(swing_s) 공을 눈으로 따라간다 — track(stick3d_track.gd): 리드 손이 이마로 0.3 s, 고개가 공의 x·y 를 공의 속도로 쫓고(메타 track_x·track_y 를 매 틱 적는다), 컵이면 고개를 두 번 끄덕이고(cup) 잃으면 천천히 젓고(lost) 서면 어깨를 한 번 들고(rest), 손이 내려온다(DOWN_T) — 그 뒤 집으로 걸어가 카메라를 본다.
## 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 마을의 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 mind 는 아직 없다). 티 발판을 벗어나지 않는다(걷는 길이 못과 집 사이뿐이라 VOID 가 없다). 노드는 그린의 노드(원점: 티의 x, 발판 윗면, 절벽) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_green.gd 의 GOLFER 줄

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0      # 탑의 1분 — 혼자서도 이만큼마다 한 번 친다
const REACT := 1.5        # 플레이어가 친 뒤 이만큼 있다 못으로 간다 — 공이 나는 걸 보는 사이
const BACK := 40.0        # 못 뒤 이만큼에 선다(px) — 몸 둘 폭(2 × 2 HW)
const SHORT := 50.0       # 홀 이만큼 앞에 떨어뜨리는 속도를 가운데로(px) — 튄 뒤 구르는 만큼
const OFFS := [0.0, -0.1, 0.1]   # 샷 차례의 충전 어긋남 — 가운데(들어간다)·짧게(틈)·멀리(넘는다)
const WAIT_S := 12.0      # 못에서 공을 이보다 오래 기다리면 집으로
const ICE_K := 1.6        # 얼음 가속 — climb.gd 의 같은 수
const EPS := 0.000001     # 시계 비교의 여유

var cg: ClimbGreen
var s: Dictionary         # 그린(climb_green.greens 의 것 — 참조라 me_t·sw·ball 을 같이 본다)
var hop: Dictionary       # 티 발판(로더의 사전) — tee() 의 on
var fig: Stick3D
var phase := "idle"       # idle | walk | wait | address | swing | track | back | gone
var since := 0.0          # 지금 phase 에 든 뒤 흐른 시간(s)
var next_at := 0.0        # 다음 혼자 치는 때(cg.t)
var seen_me := -99.0      # 따라간 플레이어의 me_t — 한 샷에 한 번
var x := 0.0; var y := 0.0; var z := 0.0; var vx := 0.0
var dir := 1.0            # 그린의 dir — 티에서 홀 쪽
var home_x := 0.0; var tee_x := 0.0
var c_target := 0.0       # 이번 샷에 모을 충전
var end_kind := ""        # 이번 샷의 공의 끝 — "" | cup | lost | rest
var end_t0 := 0.0
var swings := 0
var charges: Array = []   # 점검용 — 놓은 때의 충전
var ends: Array = []      # 점검용 — 공의 끝
var trail: Array = []     # phase@t — 점검용

func _init(pack: ClimbGreen, green: Dictionary, parent: Node3D) -> void:
	cg = pack; s = green; dir = float(s["dir"]); tee_x = float(s["tee_x"]); y = float(s["y"]); z = C.PLAYER_Z
	hop = cg._plat(s, String(s["tee_id"]))
	var x0 := float(hop.get("x", tee_x - 100.0)) + C.HW; var x1 := x0 + float(hop.get("w", 200.0)) - 2.0 * C.HW
	home_x = clampf(tee_x - dir * BACK, x0, x1)   # 좁은 발판(60)이면 먼 끝 안쪽까지만
	x = home_x
	next_at = cg.t + 25.0 + float(int(s["n"]) % 5) * 7.0   # 층마다 어긋나게 — 구름바다의 다섯 층이 한꺼번에 치지 않는다
	fig = Stick3D.new(); fig.color = Color("4e5f6b"); fig.head_color = Color("4e5f6b")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "golfer"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("4e5f6b"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	fig.face(0.0)
	_drive()

## 못이 비었나 — 공이 못 위에 있고 아무도 스윙 중이 아니다
func free_tee() -> bool:
	return String(s["sw"]) == "" and String(s["ball"]) == "tee"

## 매 틱(climb_green._process)
func step(dt: float) -> void:
	if not is_instance_valid(fig) or dt <= 0.0: return
	since += dt
	match phase:
		"idle":
			var me := float(s.get("me_t", -99.0))
			if me > seen_me and cg.t - me >= REACT - EPS: seen_me = me; next_at = minf(next_at, cg.t)   # 플레이어가 쳤다 — 따라 친다
			if String(s["sw"]) != "": pass   # 남이 어드레스 중 — 플레이어의 티가 먼저
			elif cg.t >= next_at: seen_me = me; _go("walk")
		"walk":
			if _walk(tee_x, dt): _go("wait")
		"wait":
			if free_tee(): _address()
			elif since >= WAIT_S: _go("back")
		"address":
			_charge()
		"swing":
			if not cg.swinging(fig): _start_track()
			else: cg.tee(x, z, hop, false, fig, false)   # 스윙의 시계(meta stroke_t)는 tee 가 적는다 — 플레이어처럼 매 틱 부르지 않으면 다운스윙 첫 그림에 0.6 s 멈춘다
		"track":
			_track()
		"back":
			if _walk(home_x, dt): _rest()
		"gone":
			if cg.t >= next_at: _home()
	_drive()

## target 까지 플레이어의 걸음(WALK, 얼음은 ICE_K 로 붙는다)으로 — 닿으면 true 를 주고 카메라를 본다
func _walk(target: float, dt: float) -> bool:
	var d := signf(target - x)
	if d == 0.0 or (target - x) * d <= C.WALK * dt:
		x = target; vx = 0.0; fig.face(0.0); return true
	var want := d * C.WALK
	vx = vx + (want - vx) * minf(1.0, dt * ICE_K) if String(s.get("hop_kind", "std")) == "ice" else want
	x += vx * dt; fig.face(PI / 2.0 if d > 0.0 else -PI / 2.0)
	return false

## 어드레스 — 이번 샷의 충전을 고르고(가운데 ± 차례) 팩의 tee 에 든다(count 거짓); 못이 비지 않았으면 다음 틱에 다시
func _address() -> void:
	var aim := cg.need_v(float(s["dx"]) - SHORT, float(s["fy"]) - y)
	var c0 := clampf((aim - cg.v_min()) / (cg.v_max() - cg.v_min()), 0.0, 1.0)
	c_target = clampf(c0 + float(OFFS[(int(s["n"]) + swings) % 3]), 0.0, 1.0)
	var r := cg.tee(x, z, hop, true, fig, false)
	if not bool(r["busy"]): return
	fig.pose_request = "stroke"; _go("address")

## 모으기 — 팩의 시계가 c_target 에 닿을 때까지 누르고, 닿으면 놓는다(팩이 스윙으로)
func _charge() -> void:
	var held := (cg.t - float(s["sw_t0"])) / cg.charge_s() < c_target - EPS
	var r := cg.tee(x, z, hop, held, fig, false)
	if not bool(r["busy"]): fig.pose_request = ""; _go("back"); return   # 풀렸다 — 집으로(남이 끼어들 수는 없지만 팩이 그렇게 말하면 따른다)
	if not held: swings += 1; charges.append(float(s["c"])); _go("swing")

## 스윙이 풀렸다 — 공을 쫓는다(리드 손은 stroke 의 리드와 같다: 홀 쪽)
func _start_track() -> void:
	end_kind = ""; fig.set_meta("track_lead", dir); fig.pose_request = "track"; _go("track")
	_track()

## 공을 눈으로 — 메타 track_x·track_y 는 몸(발)에서 공까지(px); 공이 서면(holed·lost·rest) 끝의 종류와 시간을 적고, 끄덕임·젓기·어깨 뒤 손이 내려오면 집으로
func _track() -> void:
	var b := String(s["ball"])
	fig.set_meta("track_x", float(s["bx"]) - x); fig.set_meta("track_y", float(s["by"]) - y)
	if end_kind == "" and b != "fly" and b != "roll":
		end_kind = "cup" if b == "holed" else ("lost" if b == "lost" else "rest"); end_t0 = cg.t; ends.append(end_kind)
		fig.set_meta("track_end", end_kind)
	if end_kind == "": return
	var u := cg.t - end_t0
	fig.set_meta("track_end_t", u)
	if u >= TrackPoses.end_s(end_kind) + TrackPoses.DOWN_T - EPS: _clear(); _go("back")

## track 의 메타와 자세를 거둔다
func _clear() -> void:
	for key: String in ["track_x", "track_y", "track_end", "track_end_t", "track_lead"]:
		if fig.has_meta(key): fig.remove_meta(key)
	if fig.pose_request == "track": fig.pose_request = ""

## 집에서 카메라를 보고 선다 — 다음은 1분 뒤(또는 플레이어의 샷 뒤)
func _rest() -> void:
	vx = 0.0; fig.face(0.0); next_at = cg.t + MINUTE; _go("idle")

## 집에 바로 세운다(점검·돌아옴) — 모으던 것은 팩에서 풀고, 다음 차례는 지금
func _home() -> void:
	x = home_x; vx = 0.0; fig.visible = true; cg._drop(fig); cg.leave(fig); _clear(); fig.pose_request = ""
	next_at = cg.t; fig.face(0.0); _go("idle")

func _go(p: String) -> void:
	phase = p; since = 0.0; trail.append("%s@%.2f" % [p, cg.t])
	if trail.size() > 40: trail.pop_front()

## Stick3D 에 걸음·자리를 — climb.gd 가 플레이어에게 하는 것과 같은 식(그린 노드의 원점 기준: 티의 x, 발판 윗면, 절벽)
func _drive() -> void:
	fig.move_dir = Vector3(signf(vx), 0.0, 0.0) if absf(vx) > 20.0 else Vector3.ZERO
	fig.speed = absf(vx) * C.K
	fig.position = Vector3((x - tee_x) * C.K, 0.0, (z - C.WALL_Z) * C.K)
