class_name ClimbKeeper
extends RefCounted
## 다이얼 키퍼 — 해시계 팩(climb_sundial.gd, run 157)의 주민 반쪽(run 158; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 돌판이 박힌 발판의 집 쪽 끝(오른끝)에 서서 돌판을 보는 주민 하나.
## 탑의 한 시간(day_s / 24 = 25 s)마다 정각에, 그리고 플레이어가 이 돌판을 읽은 뒤 REACT 초 뒤(2 s 안)에 돌판 곁(read_x — 돌판 가장자리에서 SIDE 안쪽, 플레이어의 reach 안)으로 같은 WALK(260 px/s)로 걸어가
## 같은 squint(같은 3.2 s, squint_dir 도 같은 그림자에서)로 읽고 머리 위에 시각을 말한다("Tower time 14:20." — SAY_T 동안) → 정각 12:00 이면 WIPE_T 만큼 더 머물며 소매로 그노몬을 닦는다(wipe) → 같은 WALK 로 집으로 돌아와 돌판을 보고 선다.
## 키퍼의 읽기는 돌판의 read_t0 를 건드리지 않는다: 그 값은 플레이어의 읽기라 로더가 squinting() 으로 플레이어의 걷기를 잠그는 조건이다 — 키퍼가 읽을 때마다 플레이어가 멈추면 안 된다. 시각은 돌판 글자 대신 키퍼의 머리 위 줄이 보인다.
## 얼음 발판에선 climb.gd 와 같은 가속(ICE_K)으로 속도가 붙는다 — 거리가 짧아 부딪힐 것은 없다. 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 다른 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 마을의 mind 는 아직 없다 — 백로그의 "the hurdler remembers" 가 그 자리).
## 노드는 돌판의 노드(원점: 돌판 가운데·발판 윗면·돌판의 깊이) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_sundial.gd 의 KEEPER·NOON 줄

const C = preload("res://scripts/games/climb.gd")
const REACT := 0.8        # 플레이어의 읽기 뒤 이만큼 있다 간다(2 s 안) — 보고 따라 읽는 사이
const SAY_T := 2.0        # 머리 위 시각이 머무는 시간(s)
const SIDE := 8.0         # 읽는 자리: 돌판 가장자리에서 이만큼 바깥(px) — 반지름 + reach(36) 안쪽
const NOON_H := 12        # 정오의 시(탑의 24시간)
const ICE_K := 1.6        # 얼음 가속 — climb.gd 의 같은 수(vx += (target − vx) · min(1, dt · ICE_K))

var sd: ClimbSundial
var dial: Dictionary      # 돌판(climb_sundial.dials 의 것 — 사전은 참조라 read_t0 를 같이 본다)
var fig: Stick3D
var line: Label3D         # 머리 위의 시각
var phase := "idle"       # idle | walk | squint | wipe | back
var since := 0.0          # 지금 phase 에 든 뒤 흐른 시간(s)
var hour := -1            # 마지막으로 제 발로 읽은 탑의 시(hour_of) — 정각마다 한 번
var seen_t0 := -99.0      # 따라 읽은 플레이어의 read_t0 — 한 읽기에 한 번
var noon := false         # 이번 읽기가 정오의 것인가 — 닦는다
var say_until := -99.0
var x := 0.0; var z := 0.0; var vx := 0.0
var dir := -1.0           # 지금 가는 방향 — 집(오른끝) → 돌판은 −x
var home_x := 0.0; var read_x := 0.0
var hop_kind := "std"

func _init(pack: ClimbSundial, d: Dictionary, parent: Node3D) -> void:
	sd = pack; dial = d; hop_kind = String(d.get("hop_kind", "std"))
	var cx := float(d["cx"]); var hw := float(d.get("hop_w", sd.min_w()))
	home_x = cx + hw / 2.0 - C.HW - 4.0
	read_x = minf(home_x, cx + sd.size() / 2.0 + SIDE)   # 좁은 발판(min_w)에선 집이 곧 읽는 자리
	x = home_x; z = C.PLAYER_Z
	hour = sd.hour_of(sd.t)   # 세워진 시의 정각은 지났다 — 다음 정각부터
	fig = Stick3D.new(); fig.color = Color("6b5a3e"); fig.head_color = Color("6b5a3e")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "dial-keeper"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("6b5a3e"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	line = Label3D.new(); line.text = ""; line.font_size = 40; line.pixel_size = 0.004; line.modulate = Color("1b0c15"); line.outline_size = 8; line.outline_modulate = Color("f7f4ef")
	line.billboard = BaseMaterial3D.BILLBOARD_ENABLED; line.no_depth_test = true; line.position = Vector3(0, 1.95, 0); line.visible = false; fig.add_child(line)
	fig.face(-PI / 2.0)
	_drive()

## 매 틱(climb_sundial._process)
func step(dt: float) -> void:
	if not is_instance_valid(fig) or dt <= 0.0: return
	since += dt
	match phase:
		"idle":
			var h := sd.hour_of(sd.t); var pr := float(dial["read_t0"])
			if h != hour: hour = h; noon = h % 24 == NOON_H; _go("walk", -1.0)   # 정각 — 12시면 닦는다
			elif pr != seen_t0 and sd.t - pr >= REACT and sd.t - pr < 2.0: seen_t0 = pr; noon = false; _go("walk", -1.0)   # 플레이어가 읽었다 — 따라 읽는다
		"walk", "back":
			_walk(dt)
		"squint":
			if since >= SquintPoses.SQUINT_T:
				_say("Tower time %s." % sd.time_text(sd.t))
				if noon: fig.pose_request = "wipe"; phase = "wipe"; since = 0.0
				else: fig.pose_request = ""; _go("back", 1.0)
		"wipe":
			if since >= WipePoses.WIPE_T: fig.pose_request = ""; _go("back", 1.0)
	line.visible = sd.t < say_until
	_drive()

## 걷는 틱 — 플레이어와 같은 속도; 돌판 곁에 닿으면 읽고(squint), 집에 닿으면 돌판을 보고 선다
func _walk(dt: float) -> void:
	var target := dir * C.WALK
	vx = vx + (target - vx) * minf(1.0, dt * ICE_K) if hop_kind == "ice" else target
	x += vx * dt
	var end := read_x if dir < 0.0 else home_x
	if (x - end) * dir < 0.0: return
	x = end; vx = 0.0
	if phase == "walk":
		fig.set_meta("squint_dir", cos(sd.day_frac(sd.t) * TAU))   # 플레이어의 read 와 같은 식 — 고개가 그림자 끝 쪽을 본다
		fig.pose_request = "squint"; phase = "squint"; since = 0.0
	else: _rest()

func _go(p: String, d: float) -> void:
	phase = p; since = 0.0; dir = d
	fig.face(PI / 2.0 if d > 0.0 else -PI / 2.0)

func _say(text: String) -> void:
	line.text = text; say_until = sd.t + SAY_T

## 집에서 돌판을 보고 선다 — 다음은 정각(또는 플레이어의 읽기 뒤)
func _rest() -> void:
	phase = "idle"; since = 0.0; vx = 0.0; dir = -1.0; fig.pose_request = ""
	fig.face(-PI / 2.0); _drive()

## Stick3D 에 걸음을 — climb.gd 가 플레이어에게 하는 것과 같은 식(돌판 노드의 원점 기준)
func _drive() -> void:
	fig.move_dir = Vector3(signf(vx), 0, 0) if absf(vx) > 20.0 else Vector3.ZERO
	fig.speed = absf(vx) * C.K
	fig.position = Vector3((x - float(dial["cx"])) * C.K, 0.0, (z - float(dial["z"])) * C.K)
