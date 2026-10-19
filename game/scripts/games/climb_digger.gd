class_name ClimbDigger
extends RefCounted
## 파는 이 — 별가루 더미 팩(climb_drift.gd, run 176)의 주민 반쪽(run 177; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 더미마다 하나, 무더기에서 BACK(몸 둘 폭) 오른쪽에 카메라를 보고 선 주민 — 더미의 지킴이.
## 쌓인 더미를 삽 곁에 아무도 없이 탑의 1분(MINUTE) 두면(층마다 어긋나게 시작한다) 삽으로 걸어가 소매를 걷고(sleeve, stick3d_sleeve.gd — 한 소매 0.4 s 씩 둘, 깃 한 번, 1.0 s) 같은 dig(count 거짓 — 제 별은 판에 안 세고 me_t 도 안 적는다)로 같은 shovel 로 판다;
## 바퀴마다 C 를 쥔 채 — 마지막 삽까지(놓는 법이 없다 — 지킴이니까) → 별이 뜨면 팩의 바라봄(gaze)을 그대로 하고 집으로 걸어가 카메라를 본다; 다음은 그 더미가 되메워진(hang_s + sink_s + refill_s) 뒤 1분.
## 플레이어가 파면(팩이 count 참일 때 me_t 에 적는다) 되메워지길 기다려 FOLLOW 뒤에 판다(따라 판다). 플레이어가 파는 동안은 집에서 기다린다(걸어가던 중이면 돌아온다 — 플레이어의 삽이 먼저);
## 플레이어가 바퀴 중에 떠나면(팩의 _away 가 left_t 를 적는다) 바로 와서 남은 삽을 판다 — 판 데서부터(판 것은 더미가 기억한다). 멈춤(stop)으로 놓은 더미는 떠난 게 아니다 — 1분 뒤의 차례를 기다린다.
## 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 마을의 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 mind 는 아직 없다). 더미 발판을 벗어나지 않는다(걷는 길이 삽과 집 사이뿐이라 VOID 가 없다). 노드는 더미의 노드(원점: 더미의 x, 발판 윗면, 절벽) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_drift.gd 의 DIGGER·SLEEVE 줄

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0      # 탑의 1분 — 쌓인 더미를 이만큼 두었다 판다
const FOLLOW := 1.0       # 플레이어가 판 더미가 되메워진 뒤 이만큼 있다 판다
const BACK := 40.0        # 무더기에서 이만큼 오른쪽에 선다(px) — 몸 둘 폭(2 × 2 HW)
const EPS := 0.000001

var cd: ClimbDrift
var s: Dictionary         # 더미(climb_drift.drifts 의 것 — 참조라 st·ph·fig·dug·me_t·left_t 를 같이 본다)
var hop: Dictionary       # dig() 의 on — 팩은 id 만 읽는다
var fig: Stick3D
var phase := "idle"       # idle | walk | sleeve | dig | back | gone
var since := 0.0          # 지금 phase 에 든 뒤 흐른 시간(s)
var next_at := 0.0        # 다음 파는 때(cd.t) — 더미가 쌓여 있어야 간다
var seen_me := -99.0      # 본 플레이어의 me_t — 한 별에 한 번
var seen_left := -99.0    # 본 플레이어의 left_t — 한 떠남에 한 번
var sleeve_t := 0.0       # sleeve 에 든 뒤 시간 — 메타 sleeve_t 로 자세에
var x := 0.0; var z := 0.0; var vx := 0.0
var wx := 0.0; var home_x := 0.0
var stars := 0            # 점검용 — 제가 드러낸 별
var takeovers := 0        # 점검용 — 플레이어가 두고 간 더미를 마친 수
var dug_mine := false     # 이번 귀가가 제 별 뒤인가 — _rest 가 다음 차례를 그 더미에 맞춘다
var trail: Array = []     # phase@t — 점검용

func _init(pack: ClimbDrift, drift: Dictionary, parent: Node3D) -> void:
	cd = pack; s = drift; wx = float(s["wx"]); z = C.PLAYER_Z
	hop = { "id": String(s["hop_id"]) }
	var half := float(s["hop_w"]) / 2.0 - C.HW
	home_x = clampf(wx + cd.heap_dx() + BACK, wx - half, wx + half)   # 좁은 발판(100)이면 끝 안쪽까지만
	x = home_x
	next_at = cd.t + 25.0 + float(int(s["n"]) % 5) * 7.0   # 층마다 어긋나게 — 별밤의 다섯 층이 한꺼번에 파지 않는다
	fig = Stick3D.new(); fig.color = Color("5b5a66"); fig.head_color = Color("5b5a66")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "digger"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("5b5a66"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	fig.face(0.0)
	_drive()

## 남(플레이어)이 이 더미를 파고 있나(바라봄·멈춤까지)
func other_digging() -> bool:
	return String(s["ph"]) != "" and (s["fig"] as Stick3D) != fig

## 쌓여 있고 삽 곁에 아무도 없나
func free_heap() -> bool:
	return String(s["st"]) == "heaped" and String(s["ph"]) == ""

## 매 틱(climb_drift._process)
func step(dt: float) -> void:
	if not is_instance_valid(fig) or dt <= 0.0: return
	since += dt
	match phase:
		"idle":
			var me := float(s.get("me_t", -99.0))
			if me > seen_me: seen_me = me; next_at = me + cd.hang_s() + cd.sink_s() + cd.refill_s() + FOLLOW   # 플레이어가 팠다 — 되메워지길 기다려 따라 판다(집에서만 본다 — 걷다 돌아온 뒤에도 늦지 않다)
			var left := float(s.get("left_t", -99.0))
			if left > seen_left: seen_left = left; next_at = minf(next_at, left)   # 플레이어가 바퀴 중에 떠났다 — 바로 가서 마친다
			if free_heap() and cd.t >= next_at: _go("walk")
		"walk":
			if other_digging(): _go("back")   # 플레이어가 먼저 잡았다 — 집에서 기다린다
			elif _walk(wx, dt): sleeve_t = 0.0; fig.set_meta("sleeve_t", 0.0); fig.pose_request = "sleeve"; _go("sleeve")
		"sleeve":
			if other_digging(): _end_sleeve(); _go("back")
			else: _sleeve(dt)
		"dig":
			var r := cd.dig(x, z, hop, true, fig, false)   # C 를 쥔 채 — 마지막 삽까지
			fig.face(PI / 2.0)   # 파는 이는 무더기 쪽을 본다 — 로더가 플레이어에게 하는 것과 같이
			if not bool(r["busy"]):
				if String(s["st"]) == "dug": stars += 1; dug_mine = true
				fig.pose_request = ""; _go("back")
		"back":
			if _walk(home_x, dt): _rest()
		"gone":
			if cd.t >= next_at: _home()
	_drive()

## target 까지 플레이어의 걸음(WALK)으로 — 닿으면 true 를 주고 카메라를 본다(더미는 std 발판에만 서니 얼음은 없다)
func _walk(target: float, dt: float) -> bool:
	var d := signf(target - x)
	if d == 0.0 or (target - x) * d <= C.WALK * dt:
		x = target; vx = 0.0; fig.face(0.0); return true
	vx = d * C.WALK
	x += vx * dt; fig.face(PI / 2.0 if d > 0.0 else -PI / 2.0)
	return false

## 소매의 시계 — 메타 sleeve_t 를 적고, 다 하면 판다
func _sleeve(dt: float) -> void:
	sleeve_t += dt; fig.set_meta("sleeve_t", sleeve_t)
	if sleeve_t >= SleevePoses.TOTAL - EPS: _end_sleeve(); _dig()

## sleeve 의 메타와 자세를 거둔다
func _end_sleeve() -> void:
	if fig.has_meta("sleeve_t"): fig.remove_meta("sleeve_t")
	if fig.pose_request == "sleeve": fig.pose_request = ""

## 판다 — 팩의 dig 에 든다(count 거짓); 더미가 쌓여 있지 않으면(그새 파였다) 집으로. 플레이어가 두고 간 더미면 takeover 로 센다
func _dig() -> void:
	var was_dug := int(s["dug"])
	var r := cd.dig(x, z, hop, true, fig, false)
	if not bool(r["busy"]): _go("back"); return
	if was_dug > 0: takeovers += 1
	fig.pose_request = "shovel"; _go("dig")

## 집에서 카메라를 보고 선다 — 제가 팠으면 다음은 그 더미가 되메워진 뒤 1분, 아니면 차례는 그대로(지났으면 더미가 쌓이는 대로 간다)
func _rest() -> void:
	vx = 0.0; fig.face(0.0)
	if dug_mine: dug_mine = false; next_at = float(s["star_t0"]) + cd.hang_s() + cd.sink_s() + cd.refill_s() + MINUTE
	_go("idle")

## 집에 바로 세운다(점검·돌아옴) — 파던 것은 팩에서 풀고, 다음 차례는 지금
func _home() -> void:
	x = home_x; vx = 0.0; fig.visible = true; cd._away(fig); cd.leave(fig); _end_sleeve(); fig.pose_request = ""
	dug_mine = false; next_at = cd.t; seen_left = float(s.get("left_t", -99.0)); fig.face(0.0); _go("idle")

func _go(p: String) -> void:
	phase = p; since = 0.0; trail.append("%s@%.2f" % [p, cd.t])
	if trail.size() > 40: trail.pop_front()

## Stick3D 에 걸음·자리를 — climb.gd 가 플레이어에게 하는 것과 같은 식(더미 노드의 원점 기준: 더미의 x, 발판 윗면, 절벽)
func _drive() -> void:
	fig.move_dir = Vector3(signf(vx), 0.0, 0.0) if absf(vx) > 20.0 else Vector3.ZERO
	fig.speed = absf(vx) * C.K
	fig.position = Vector3((x - wx) * C.K, 0.0, (z - C.WALL_Z) * C.K)
