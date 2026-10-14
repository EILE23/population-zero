class_name ClimbHurdler
extends RefCounted
## 허들러 — 허들 줄 팩(climb_hurdle.gd, run 155)의 주민 반쪽(run 156; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 줄이 선 발판의 집 쪽 끝(오른끝)에 선 주민 하나.
## 탑의 1분(MINUTE)마다 한 번, 그리고 플레이어가 이 줄의 가로대를 넘은 뒤 REACT 초 뒤(2 s 안)에 혼자 줄을 뛴다 — 같은 WALK(260 px/s)로, 같은 stride() 호출(제 상태 st 로, 메타 hurdle_k 는 제 x 로)·같은 hurdle 자세로;
## 먼 끝(왼끝)에서 wheel 로 돌아서며 앞길(lane_z — 가로대 띠 바깥, 발판 앞끝 안쪽)로 옮겨 서고 걸어 돌아와(back) 다시 wheel 로 돌아서 줄을 보며 선다. 얕은 발판(앞길이 안 나오는)에선 되돌아올 때도 가로대를 넘는다.
## 얼음 발판에선 선 채로 출발해 climb.gd 와 같은 가속(ICE_K)으로 속도가 붙으니 첫 0.7 s 안에 첫 가로대에 부딪힌다 — 플레이어와 똑같이 teeter 로 bump_s 동안 흔들리고 물러선 뒤 집으로 걸어 돌아간다(오늘은 이만). 가로대는 흔들린다.
## 제 vault 는 판에 세지 않는다(st.count false — 판은 플레이어의 기록). 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않는다. 노드는 줄의 노드(원점: 발판 가운데·윗면·절벽) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_hurdle.gd

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0      # 탑의 1분 — 혼자서도 이만큼마다 한 번 뛴다
const REACT := 0.8        # 플레이어의 vault 뒤 이만큼 있다 뛴다(2 s 안) — 보고 따라 뛰는 사이
const LANE_GAP := 4.0     # 앞길과 가로대 띠 사이 여유(px)
const ICE_K := 1.6        # 얼음 가속 — climb.gd 의 같은 수(vx += (target − vx) · min(1, dt · ICE_K))

var ch: ClimbHurdle
var row: Dictionary       # 줄(climb_hurdle.rows 의 것 — 사전은 참조라 poke·hits 를 같이 본다)
var fig: Stick3D
var st := { "px": 0.0, "on_id": "", "count": false }   # stride 의 제 상태 — 판에는 세지 않는다
var on: Dictionary = {}   # stride 에 주는 발판 {id, kind}
var phase := "idle"       # idle | run | wheel | back | wheel2 | teeter | home
var since := 0.0          # 지금 phase 에 든 뒤 흐른 시간(s)
var next_at := 0.0        # 다음 혼자 뛰는 때(ch.t)
var x := 0.0; var z := 0.0; var vx := 0.0
var dir := -1.0           # 지금 가는 방향 — 뛰는 길은 집(오른끝) → 먼 끝(왼끝)
var home_x := 0.0; var far_x := 0.0; var rail_z := 0.0; var lane_z := 0.0
var hop_kind := "std"

func _init(pack: ClimbHurdle, r: Dictionary, parent: Node3D, kind: String) -> void:
	ch = pack; row = r; hop_kind = kind
	on = { "id": String(r["hop_id"]), "kind": kind }
	var cx := float(r["cx"]); var hw := float(r["hop_w"])
	home_x = cx + hw / 2.0 - C.HW - 4.0; far_x = cx - hw / 2.0 + C.HW + 4.0
	rail_z = float(r["z"])
	var front := C.WALL_Z + float(r["hd"]) - C.HZ - 2.0   # 발판 앞끝 안쪽
	lane_z = front if front >= rail_z + ch.rail_d() / 2.0 + C.HZ + LANE_GAP else rail_z   # 얕은 발판엔 앞길이 없다 — 가로대 위로 되돌아 넘는다
	x = home_x; z = rail_z
	next_at = ch.t + 20.0 + float(int(r["n"]) % 5) * 8.0   # 층마다 어긋나게 — 여럿이 동시에 뛰지 않는다
	fig = Stick3D.new(); fig.color = Color("5b4f56"); fig.head_color = Color("5b4f56")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "hurdler"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("5b4f56"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	fig.face(-PI / 2.0)
	_drive()

## 매 틱(climb_hurdle._process)
func step(dt: float) -> void:
	if not is_instance_valid(fig) or dt <= 0.0: return
	since += dt
	match phase:
		"idle":
			var poke := float(row.get("poke", -99.0))
			if ch.t >= next_at or (ch.t - poke >= REACT and ch.t - poke < 2.0): _go("run", -1.0)
		"run", "back", "home":
			_walk(dt)
		"wheel", "wheel2":
			z = lerpf(z, lane_z if phase == "wheel" else rail_z, minf(1.0, dt * 8.0))   # 돌아서며 길로(다시 가로대 앞으로) 옮겨 선다
			if since >= WheelPoses.WHEEL_T:
				fig.look_yaw = 0.0; fig.pose_request = ""
				if phase == "wheel": _go("back", 1.0)
				else: _rest()
		"teeter":
			if since >= ch.bump_s(): fig.pose_request = ""; _go("home", 1.0)   # 부딪힌 몸은 집으로 — 오늘은 이만
	_drive()

## 걷는 틱 — 플레이어와 같은 속도·같은 stride: 넘거나(hurdle) 부딪히거나(teeter) 끝에 닿아 돌아선다(wheel)
func _walk(dt: float) -> void:
	var target := dir * C.WALK
	vx = vx + (target - vx) * minf(1.0, dt * ICE_K) if hop_kind == "ice" else target
	x += vx * dt
	var r := ch.stride(on, x, z, vx, fig, st); x = float(r["x"])
	if bool(r["bump"]):
		vx = 0.0; fig.pose_request = "teeter"; phase = "teeter"; since = 0.0
		return
	if bool(r["in_row"]): fig.pose_request = "hurdle"
	elif fig.pose_request == "hurdle": fig.pose_request = ""
	var end := far_x if dir < 0.0 else home_x
	if (x - end) * dir >= 0.0:
		x = end; vx = 0.0; ch._leave(fig)
		fig.pose_request = "wheel"
		_go("wheel" if phase == "run" else "wheel2", -dir)

func _go(p: String, d: float) -> void:
	phase = p; since = 0.0; dir = d
	fig.face(PI / 2.0 if d > 0.0 else -PI / 2.0)

## 집에서 줄을 보고 선다 — 다음은 1분 뒤(또는 플레이어의 vault 뒤)
func _rest() -> void:
	phase = "idle"; since = 0.0; vx = 0.0; z = rail_z; fig.pose_request = ""; dir = -1.0
	fig.face(-PI / 2.0); next_at = ch.t + MINUTE; _drive()

## Stick3D 에 걸음을 — climb.gd 가 플레이어에게 하는 것과 같은 식
func _drive() -> void:
	fig.move_dir = Vector3(signf(vx), 0, 0) if absf(vx) > 20.0 else Vector3.ZERO
	fig.speed = absf(vx) * C.K
	fig.position = Vector3((x - float(row["cx"])) * C.K, 0.0, (z - C.WALL_Z) * C.K)
