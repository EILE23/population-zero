class_name ClimbJumper
extends RefCounted
## 풍경 점퍼 — 풍경 팩(climb_chime.gd, run 160)의 주민 반쪽(run 161; 운영자 규칙 "플레이어가 하는 상호작용은 주민도 제 일과에서 한다"): 풍경이 걸린 틈의 아래 발판 먼 끝에 선 주민 하나.
## 탑의 1분(MINUTE)마다 한 번(층마다 어긋나게) 턱으로 달려가(run, RUN 300) 틈을 뛰어 통 사이를 지나고(air — 같은 brush() 호출, 같은 rehit, 같은 화음·엉킴; 제 몫은 hit_j 로 따로 세어 플레이어의 hits 를 건드리지 않는다),
## 위 발판에 내려(로더와 같은 착지 squash −0.6) wheel 로 돌아서 턱까지 걸어가 다시 통 사이로 뛰어내리고(drop — 둘째 울림), 아래 발판에 내려 잦아드는 화음을 듣고(hark, 1.5 s — 손을 귀에) 집으로 걸어 돌아와(back) wheel 로 돌아서 틈을 보고 선다(idle).
## 뜀은 로더의 수(G 2400, JUMP_MIN 430..JUMP_V 860, vx ≤ RUN 300)를 쓰되 플레이어처럼 힘을 고른다(jump_for): 턱에 닿을 때 이미 내려오는 중이고 x 가 턱 2 px 안이 되게 — 아래 턱에서 JUMP_V 로 온 힘을 다해 뛰면 좁은 틈·낮은 턱에선 통 위로 70 px 넘게 지나가 영영 울리지 않는다.
## 뛰어내릴 땐 걸어서 떨어지는 것으로 닿으면(WALK · 자유낙하 시간 ≥ 틈 + 6) 그냥 턱을 걸어 내려서고, 아니면 가장 약한 뜀부터 고른다(drop_for). 로더의 reach(RUN · 체공 − 40)로 세운 틈은 늘 닿는다(점검 TOWER 의 fits); 그래도 못 닿으면(미스) 집으로 돌려 세우고 misses 에 센다.
## 단단한 것이 없다: 플레이어와 겹쳐도 밀지 않고 다른 일과·거래·식사에 끌려가지 않는다(탑의 몸이라 마을의 mind 는 아직 없다 — 백로그의 "who rang it" 이 그 자리). 노드는 풍경의 노드(원점: 기둥·위 발판 윗면·걷는 깊이) 아래라 층이 지워지면 함께 지워진다. 점검은 tools/probe_chime.gd 의 JUMPER 줄

const C = preload("res://scripts/games/climb.gd")
const MINUTE := 60.0      # 탑의 1분 — 이만큼마다 한 번 뛴다(두 번 울린다)
const LAND_T := 0.3       # 착지 뒤 서는 시간(s) — brush 의 회수(BrushPoses.LAND_T)와 같다
const RUNUP := 100.0      # 집에서 턱까지의 달림(px)의 최대 — 긴 발판에서도 집은 턱에서 이만큼
const INSIDE := 6.0       # 뛰어내려 내려서는 자리: 아래 턱에서 이만큼 안쪽(px)
const DESC_K := 1.3       # 위 턱에 닿을 때 꼭대기가 지난 뒤이게 하는 체공의 여유(√(dy/1200) 의 배) — 1.05 면 발끝이 턱을 긁고, 1.3 이면 dy 90 에 턱 위 6 px; dy 150 엔 온 힘(JUMP_V)이 되어 달림을 늦춘다
const ICE_K := 1.6        # 얼음 가속 — climb.gd 의 같은 수(vx += (target − vx) · min(1, dt · ICE_K))
const WHO := "jumper"     # brush() 에 주는 이름 — 제 rehit 와 제 울림 수
const EULER := 20.0       # = G 2400 × 0.5 / 60(상수식에선 다른 스크립트의 상수를 안 읽는다): 반암시적 오일러(vy −= G·dt 뒤 y += vy·dt)가 60 Hz 에서 잃는 높이의 몫(px/s) — 로더와 같은 순서라 같은 만큼 낮게 난다

var cw: ClimbChime
var chime: Dictionary     # 풍경(climb_chime.chimes 의 것 — 사전은 참조라 hit_j·rings 를 같이 본다)
var fig: Stick3D
var phase := "idle"       # idle | run | air | land | wheel | walk | drop | hark | back | wheel2
var since := 0.0          # 지금 phase 에 든 뒤 흐른 시간(s)
var next_at := 0.0        # 다음 뛰는 때(cw.t)
var up := true            # 지금 공중/착지가 올라가는 뜀인가(true) 뛰어내림인가(false)
var x := 0.0; var y := 0.0; var vx := 0.0; var vy := 0.0
var dir := 1.0            # 아래 발판에서 위 발판 쪽(풍경의 dir)
var home_x := 0.0; var a_lip := 0.0; var hinge := 0.0
var a_y := 0.0; var b_y := 0.0
var misses := 0           # 못 닿아 집으로 돌려 세운 수 — 진짜 탑에선 0
var hop_kind := "std"     # 아래 발판의 종류 — 얼음이면 달림에 가속이 붙는다

func _init(pack: ClimbChime, c: Dictionary, parent: Node3D) -> void:
	cw = pack; chime = c; dir = float(c["dir"]); hop_kind = String(c.get("a_kind", "std"))
	a_y = float(c["a_y"]); b_y = float(c["b_y"]); hinge = float(c["hinge_x"])
	var ax := float(c.get("a_x", hinge - dir * (float(c["gap"]) + 60.0))); var aw := float(c.get("a_w", 60.0))
	a_lip = ax + aw if dir > 0.0 else ax
	home_x = a_lip - dir * minf(aw - C.HW - 4.0, RUNUP)   # 먼 끝 — 긴 발판에선 턱에서 RUNUP 만큼(해시계의 키퍼와 끝을 다투지 않게)
	x = home_x; y = a_y
	next_at = cw.t + 20.0 + float(int(c["n"]) % 5) * 8.0   # 층마다 어긋나게 — 공중 정원의 다섯 층이 한꺼번에 울리지 않는다
	fig = Stick3D.new(); fig.color = Color("4e6b5a"); fig.head_color = Color("4e6b5a")
	parent.add_child(fig)
	var lb := Label3D.new(); lb.text = "jumper"; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("4e6b5a"); lb.outline_size = 8; lb.outline_modulate = Color("f7f4ef")
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.position = Vector3(0, 1.6, 0); fig.add_child(lb)   # AI 주민은 늘 이름표 — 정체를 숨기지 않는다
	fig.face(PI / 2.0 if dir > 0.0 else -PI / 2.0)
	_drive()

## 수평 d(px)를 건너 dy(px, + 위)만큼 다른 높이에 내리는 뜀 — {vx, vy, t, ok}: 체공 t 는 RUN 으로 건너는 시간, 올라가는 뜀이면 꼭대기가 턱 앞에 오게(DESC_K), 가장 약한 뜀(JUMP_MIN)의 체공보다 짧지 않게;
## vy 에 EULER 를 더한다(로더의 반암시적 오일러는 60 Hz 에서 그만큼 낮게 난다 — 안 더하면 발끝만 턱에 걸린다); 그래도 JUMP_V 를 넘으면 온 힘의 체공(로더의 reach 와 같은 식)으로 달림을 늦추고, 그래도 안 닿으면 ok false
static func jump_for(d: float, dy: float) -> Dictionary:
	var g2 := C.G / 2.0
	var tl := d / C.RUN
	if dy > 0.0: tl = maxf(tl, sqrt(dy / g2) * DESC_K)
	var disc := C.JUMP_MIN * C.JUMP_MIN - 2.0 * C.G * dy
	if disc >= 0.0: tl = maxf(tl, (C.JUMP_MIN + sqrt(disc)) / C.G)
	var v := dy / tl + g2 * tl + EULER
	var ok := true
	if v > C.JUMP_V:
		var dv := maxf(0.0, C.JUMP_V * C.JUMP_V - 2.0 * C.G * dy)
		tl = (C.JUMP_V + sqrt(dv)) / C.G; v = C.JUMP_V
		ok = dv > 0.0 and tl * C.RUN >= d
	return { "vx": minf(C.RUN, d / tl), "vy": v, "t": tl, "ok": ok }

## 턱에서 d(px) 건너 dy(px, 음수) 아래로 내려서기 — 걸어서 떨어지는 것으로 닿으면(4 px 여유) vy 0, 아니면 jump_for; 달림은 아래 발판 가운데까지 내려서게 빠르게(RUN 까지) — 통 사이를 0.25 s(rehit) 안에 지나 한 번만 울린다
static func drop_for(d: float, dy: float, aw: float) -> Dictionary:
	var tf := sqrt(maxf(0.0, -dy) / (C.G / 2.0))
	var j: Dictionary = { "vx": C.WALK, "vy": 0.0, "t": tf, "ok": true } if C.WALK * tf >= d + 4.0 else jump_for(d, dy)
	j["vx"] = minf(C.RUN, maxf(float(j["vx"]), (d + maxf(0.0, aw / 2.0 - INSIDE)) / float(j["t"])))
	return j

## 매 틱(climb_chime._process)
func step(dt: float) -> void:
	if not is_instance_valid(fig) or dt <= 0.0: return
	since += dt
	match phase:
		"idle":
			if cw.t >= next_at: _go("run", dir)
		"run", "walk", "back":
			_walk(dt)
		"air", "drop":
			_fly(dt)
		"land":
			if since >= LAND_T:   # brush 의 회수(BrushPoses.LAND_T)와 같은 길이 — 자세의 시계를 묻지 않는다(헤드리스 점검은 프레임을 안 돌린다)
				fig.pose_request = ""
				if up: fig.pose_request = "wheel"; _go("wheel", -dir)
				else: fig.set_meta("hark_side", -dir); fig.pose_request = "hark"; phase = "hark"; since = 0.0   # 뛰어내린 몸은 −dir 을 본다 — 고개는 앞(화면)으로
		"wheel", "wheel2":
			if since >= WheelPoses.WHEEL_T:
				fig.look_yaw = 0.0; fig.pose_request = ""
				if phase == "wheel": _go("walk", -dir)
				else: _rest()
		"hark":
			if since >= HarkPoses.HARK_T: fig.look_yaw = 0.0; fig.pose_request = ""; _go("back", -dir)
	_drive()

## 걷는 틱 — run 은 턱(a_lip)에서 뛰고, walk 는 위 턱(hinge)에서 뛰어내리고, back 은 집에 닿아 돌아선다
func _walk(dt: float) -> void:
	var d := dir if phase == "run" else -dir
	var target := d * (C.RUN if phase == "run" else C.WALK)
	vx = vx + (target - vx) * minf(1.0, dt * ICE_K) if hop_kind == "ice" and phase != "walk" else target
	x += vx * dt
	var end := a_lip if phase == "run" else (hinge if phase == "walk" else home_x)
	if (x - end) * d < 0.0: return
	x = end
	if phase == "run":
		var j := jump_for(float(chime["gap"]) + 2.0, b_y - a_y)
		_leap(dir * float(j["vx"]), float(j["vy"]), true, "air")
	elif phase == "walk":
		var k := drop_for(float(chime["gap"]) + INSIDE, a_y - b_y, float(chime.get("a_w", 60.0)))
		_leap(-dir * float(k["vx"]), float(k["vy"]), false, "drop")
	else:
		vx = 0.0; fig.pose_request = "wheel"; _go("wheel2", dir)

func _leap(nvx: float, nvy: float, rising: bool, p: String) -> void:
	vx = nvx; vy = nvy; up = rising; phase = p; since = 0.0
	fig.pose_request = ""

## 공중의 틱 — 로더와 같은 순서(중력 → 자리 → 착지 판정); 통 사이를 지나면 brush(제 이름으로 — 제 rehit, 플레이어의 hits 는 그대로)
func _fly(dt: float) -> void:
	vy -= C.G * dt
	var ny := y + vy * dt
	x += vx * dt
	var ty := b_y if up else a_y
	var tx0 := float(chime.get("b_x", hinge)) if up else float(chime.get("a_x", a_lip))
	var tw := float(chime.get("b_w", 0.0)) if up else float(chime.get("a_w", 0.0))
	if vy <= 0.0 and y >= ty and ny <= ty and x + C.HW > tx0 and x - C.HW < tx0 + tw:
		y = ty; vx = 0.0; vy = 0.0; fig.squash = -0.6   # 로더의 plain 착지 — 같은 squash
		phase = "land"; since = 0.0
		return
	y = ny
	var r := cw.brush(x, y, ClimbChime.TUBE_Z, true, WHO)
	if bool(r["brushed"]): fig.pose_request = "brush"
	if y < minf(a_y, b_y) - 80.0: misses += 1; _home()   # 못 닿았다 — 진짜 탑에선 없다(TOWER 의 fits)

func _go(p: String, d: float) -> void:
	phase = p; since = 0.0
	fig.face(PI / 2.0 if d > 0.0 else -PI / 2.0)

## 집으로 돌려 세운다(미스) — 다음 분에 다시
func _home() -> void:
	x = home_x; y = a_y; vx = 0.0; vy = 0.0; fig.pose_request = ""; fig.look_yaw = 0.0; _rest()

## 집에서 틈을 보고 선다 — 다음은 1분 뒤
func _rest() -> void:
	phase = "idle"; since = 0.0; vx = 0.0; vy = 0.0; fig.pose_request = ""
	fig.face(PI / 2.0 if dir > 0.0 else -PI / 2.0); next_at = cw.t + MINUTE; _drive()

## Stick3D 에 걸음·공중을 — climb.gd 가 플레이어에게 하는 것과 같은 식(풍경 노드의 원점 기준)
func _drive() -> void:
	var air := phase == "air" or phase == "drop"
	fig.airborne = air; fig.vertical = vy * C.K if air else 0.0
	fig.move_dir = Vector3(signf(vx), 0, 0) if absf(vx) > 20.0 and not air else Vector3.ZERO
	fig.speed = absf(vx) * C.K
	fig.position = Vector3((x - float(chime["post_x"])) * C.K, (y - b_y) * C.K, 0.0)
