class_name Stick3D
extends StickRig
## 입체 졸라맨의 움직임 — 걸음·달리기·점프·앉기·눕기·일과 자세(pose_request)·잠깐의 동작(action)·대기 기지개. 몸은 stick_rig.gd 에.
## 2D figure.gd 와 같은 관절 논리를 3D 각도로 옮겼다: 걸음 위상은 이동 거리에 걸려 발이 미끄러지지 않고, 팔은 다리와 반대 위상,
## 무릎은 뒤로 갈 때 접히고, 상체는 달릴 때 앞으로 기울고, 엉덩이는 보폭마다 살짝 뜬다. 몸은 이동 방향으로 부드럽게 돈다.
## 회전 부호 약속(2026-09-28 수정 — 처음엔 팔꿈치가 뒤로, 무릎이 앞으로 꺾여 "팔이 따로 놀았다"):
##   매달린 뼈(팔다리)는 rotation.x 가 −면 끝이 앞(+z, 얼굴 방향)으로 간다(Godot 오른손 좌표계). 코드는 '앞 = 양수' 로 읽히게 쓰고 대입에서 -( ) 로 뒤집는다.
##   2026-09-28 두 번째 수정: 처음엔 + 가 앞인 줄 알고 넣어서 다리가 진행 방향과 반대로 저었다(운영자: "지금 무슨 문워크 하냐"). 위로 뻗는 몸통(torso)은 + 가 앞이 맞다.

## 바깥에서 매 프레임 채워 준다
var move_dir := Vector3.ZERO   # 수평 이동 방향(단위) — ZERO 면 서 있음
var speed := 0.0               # m/s
var airborne := false
var vertical := 0.0            # 공중 속도(+ 위)
var crouch := 0.0              # 0..1 웅크림
var seated := false            # 벤치에 앉음
var jet := false               # 제트킥 비행 중(온몸이 앞으로 쏠린 자세)
var action := ""               # "punch" | "kick" | "grab" | "" — 잠깐의 동작
var action_t := 0.0            # 동작 진행 0..1
var punch_side := 1.0          # 연속기: 1.0 오른손, -1.0 왼손
var move := ""                 # action "fight" 일 때 기술 이름(FightMoves) — 자세는 FightPoses.move
var kick_step := 0            # 발차기 연속 단계 0 오른 앞차기 · 1 왼 앞차기 · 2 돌려차기
var punch_kind := "jab"        # "jab" | "cross" | "hook"
var lying := false             # 맞아서 누움(등을 바닥에)
var _was_lying := false
var _lie_since := 0.0
var pose_request := ""         # 주민 일과용: "lean"(가로등) | "shake"(나무) | "water"(텃밭) | ... | "" — 자세 자체는 stick3d_poses.gd
var swing_k := 0.0             # 그네: 각속도 정규화(-1..1) — 앞으로 갈 때 다리를 뻗는다
var squash := 0.0             # jump stretch(+)/land squash(-), decays to 0
var base_scale := Vector3.ONE  # 기준 배율(차 안 0.8, 차에 깔리면 납작) — scale 은 매 프레임 여기에 찌그러짐을 곱해 다시 쓴다(polish 79: 바깥에서 scale 을 만지면 다음 프레임에 지워졌다)
var push_t := 9.0              # 밀기: 0 에서 시작해 1 까지(팔을 뻗었다 거둔다), 9 = 쉼
var look_yaw := 0.0            # 고개만 돌려 보기(rad, 몸 기준) — 나란히 걷는 짝을 돌아본다(run 95, resident_pair). 0 이면 정면
var pose_t := 0.0              # 지금 pose_request 가 시작된 뒤 흐른 시간 — 자세마다 예비·유지·회수 타이밍(StickPoses). 자세가 바뀌면 0
var _pose_prev := ""

## 대기 기지개(운영자 2026-09-28, "Stick3D feel"): 가만히 서 있을 때만 저절로 — 2D figure.gd 의 yawn·shrug·look 을 그대로
var _fidget := ""              # "" | "yawn" | "shrug" | "look" — 서 있을 때만, 걷거나 동작 중이면 즉시 취소
var _fidget_t := 0.0
var _fidget_next := randf_range(3.0, 8.0)   # 다음 기지개까지 남은 시간(초) — 인스턴스마다 무작위라 여럿이 동시에 하품하지 않는다

var _phase := 0.0
var _pose_since := 0.0
const CI_POSES := ["water", "knead", "shade", "storm", "lwave", "hammer", "grind", "wait", "sew", "teeter", "share", "pass", "chop", "cast", "reel", "stoke", "moor", "bicker", "makeup", "shelve", "sort", "pin", "scan", "skip", "crossleg", "story", "stoop", "palm", "put", "rock", "rub", "strum", "sigh", "don", "doff", "plonk", "glide", "bounce", "lurch", "sway", "ride", "duck", "tread", "dangle", "wade", "rail", "haul", "part", "heave", "kite", "shunt", "cling", "turn", "loll", "trail"]
var _t := 0.0
var _yaw := 0.0
var _yaw_target := 0.0

func _process(delta: float) -> void:
	_t += delta
	if pose_request != _pose_prev:
		if _pose_prev == "water": StickPoses.drops(self, false)   # 붓다 말고 자세가 풀리면 물방울도 끈다
		_pose_prev = pose_request; pose_t = 0.0; _pose_since = _t
	else:
		pose_t += delta
	if pose_request == "umbr" and (carrying == null or not carrying.has_meta("umb")): pose_request = ""   # 손에 우산이 없으면 우산 자세도 없다
	if pose_request != "lwave": umbr_k = move_toward(umbr_k, 1.0 if pose_request == "umbr" else 0.0, delta / StickPoses.UMBR_T)   # 왼손 인사(run 77) 동안 우산은 있던 대로 — 펴졌으면 편 채, 접혔으면 접은 채
	var moving := move_dir.length_squared() > 0.0001 and speed > 0.05 and not seated
	# 몸 방향 — 이동 방향으로 부드럽게(초당 약 10rad 로 수렴). 서 있으면 마지막 방향 유지
	if moving:
		_yaw_target = atan2(move_dir.x, move_dir.z)
	_yaw = lerp_angle(_yaw, _yaw_target, minf(1.0, delta * 10.0))
	squash = move_toward(squash, 0.0, delta * 5.0)
	var sq := squash * 0.16
	scale = base_scale * Vector3(1.0 - sq * 0.5, 1.0 + sq, 1.0 - sq * 0.5)   # volume-ish preserving stretch/squash
	rotation.y = _yaw
	# 대기 기지개 — 가만히 서 있을 때만(다른 자세·동작·이동이 끼어들면 바로 취소, 어색하게 이어붙지 않는다)
	var idle_now := not moving and not airborne and not seated and not lying and crouch <= 0.0 and action == "" and pose_request == ""
	if not idle_now:
		_fidget = ""; _fidget_next = randf_range(3.0, 8.0)
	elif _fidget != "":
		_fidget_t += delta
		if _fidget_t > (1.3 if _fidget == "yawn" else (1.0 if _fidget == "shrug" else 1.6)):
			_fidget = ""; _fidget_t = 0.0; _fidget_next = randf_range(4.0, 9.0)
	else:
		_fidget_next -= delta
		if _fidget_next <= 0.0:
			_fidget = ["yawn", "shrug", "look"][randi() % 3]; _fidget_t = 0.0
	# 자세 블렌딩 — 이 프레임의 목표 각도를 아래에서 곧장 대입한 뒤, 끝에서 이전 각도와 섞는다(앉기·일어서기가 딱딱하지 않게)
	var prev := {}
	for pv in _pivots:
		prev[pv] = pv.rotation
	var prev_pelvis_y := pelvis.position.y
	var prev_pelvis_rot := pelvis.rotation
	pelvis.rotation = Vector3.ZERO
	# 걸음 위상은 거리로 — 빠르면 빨리, 멈추면 멈춘다
	if moving and not airborne:
		_phase += speed * delta / STRIDE * TAU
	else:
		_phase = lerp_angle(_phase, 0.0, minf(1.0, delta * 8.0))
	var sw := sin(_phase)
	var cw := cos(_phase)
	var run_k := clampf(speed / 3.0, 0.0, 1.4)  # 걷기 1.0 근처, 대시 1.4
	var breathe := sin(_t * 2.0) * 0.006
	var bob := absf(cw) * 0.06 * run_k if moving and not airborne else 0.0   # 2D 와 같은 6%
	pelvis.position.y = HIP_Y + bob + breathe - crouch * 0.16
	# 상체: 달리면 앞으로 기울고 골반과 반대로 살짝 비틀림; 웅크리면 더 숙임; 공중이면 뒤로 살짝; 앉으면 곧게
	var lean := 0.32 * run_k if moving and not airborne else 0.0   # 2D 와 같은 0.32
	lean += crouch * 0.35
	if airborne:
		lean = 0.18 if vertical > 0.0 else 0.08  # 도약은 살짝 앞으로
	if seated:
		lean = -0.05
	if pose_request == "lean" and not moving:
		lean = -0.2
	if pose_request == "shake" and not moving:
		lean = sin(_t * 9.0) * 0.12
	if pose_request == "read" and not moving:
		lean = 0.12
	if pose_request == "drink" and not moving:
		lean = -0.12
	if pose_request == "eat" and not moving:
		lean = 0.08
	if pose_request == "pet" and not moving:
		lean = 0.55; pelvis.position.y = HIP_Y - 0.3   # 쪼그림: 엉덩이가 내려간다
	if pose_request == "swing":
		lean = -0.15 - swing_k * 0.25
	if pose_request == "push":
		push_t += delta * 1.6
		lean = 0.25 if push_t < 0.3 else 0.08
	if pose_request == "swim":
		# 헤엄(크롤, 운영자 모션 보드의 물 가족 첫 자세): 엎드려 몸이 수면에 눕고(골반 +1.4 = 얼굴이 아래), 팔은 번갈아 풍차, 다리는 발장구.
		# town 이 몸을 -0.22 내려 하반신은 물속에 감춰진다
		pelvis.rotation.x = 1.4; lean = 0.0
		pelvis.position.y = 0.3 + sin(_t * 2.2) * 0.01
	var pt := clampf((_t - _pose_since) / 0.8, 0.0, 1.0)   # 자세 진입 진행 0..1 (눕기 전환에 쓴다)
	if pose_request == "sky" or pose_request == "rest":
		# 눕기(2D sky·rest): 먼저 0.35초 쪼그려 앉듯 엉덩이를 내리고, 그다음 등을 굴려 눕는다 — 전엔 선 채로 툭 넘어갔다
		var down := smoothstep(0.0, 1.0, (pt - 0.3) / 0.7)
		var crouch_k := sin(clampf(pt / 0.45, 0.0, 1.0) * PI) * (1.0 - down)
		pelvis.rotation.x = -1.5 * down
		pelvis.position.y = lerpf(HIP_Y - 0.22 * crouch_k, 0.12 if pose_request == "sky" else 0.16, down)
		lean = (0.6 * crouch_k) * (1.0 - down) + ((0.05 if pose_request == "sky" else 0.25) + sin(_t * 1.6) * 0.02) * down
	if pose_request in CI_POSES: lean = StickPoses.lean(self, moving, delta, lean)   # 물주기·반죽·손차양·처마 비 구경(CI run 70~74) — stick3d_poses.gd
	if lying:
		pelvis.rotation.x = -1.45; lean = 0.1
		pelvis.position.y = 0.12
	torso.rotation.x = lean * 0.45
	chest.rotation.x = lean * 0.55 + (0.18 * run_k if moving and not airborne else 0.0)  # 달리면 등이 둥글게 말린다
	torso.rotation.y = -sw * 0.10 * run_k if moving else 0.0
	chest.rotation.y = 0.0
	neck.rotation.x = -(torso.rotation.x + chest.rotation.x) * 0.7  # 고개는 앞을 본다
	neck.rotation.y = 0.0  # 매 프레임 다시 정면으로 — look 기지개가 끝나도 고개가 돌아간 채 남지 않게
	if pose_request == "swim":
		neck.rotation.x = -0.9; neck.rotation.y = sin(_t * 2.0) * 0.5   # 고개를 들어 앞을 보고 숨 쉴 때 옆으로
	if _fidget == "yawn":
		neck.rotation.x -= 0.35  # 고개를 젖힌다(2D yawn 과 같은 방향)
	elif _fidget == "look":
		neck.rotation.y = sin(_fidget_t * 2.2) * 0.35  # 좌우로 둘러본다(2D look)
	neck.rotation.y += look_yaw   # 블렌딩이 돌림을 부드럽게 한다
	hand_r.rotation = Vector3.ZERO   # 손목은 블렌딩 대상이 아니다 — 물주기가 기울인 걸 프레임마다 되돌린다
	hips[-1.0].rotation.z = 0.0; hips[1.0].rotation.z = 0.0   # 허벅지 벌림은 책상다리(run 103)만 쓴다 — 다른 자세는 매 프레임 모은다(블렌딩이 부드럽게 푼다)
	for side in [-1.0, 1.0]:
		var s: float = side
		var hip: Node3D = hips[s]; var knee: Node3D = knees[s]
		var sh: Node3D = shoulders[s]; var el: Node3D = elbows[s]
		if pose_request == "swim":
			# 팔: 한 바퀴 돌며 뒤→위→앞→아래(물속에서 당김) — 엎드린 몸 기준으로 +x 회전이 그 순서다. 다리: 작은 발장구
			var arm := _t * (4.0 + minf(speed, 2.0) * 2.0) + (PI if s < 0.0 else 0.0)
			hip.rotation.x = -(s * sin(_t * 9.0) * 0.28); knee.rotation.x = -(-0.25)
			sh.rotation.x = arm; sh.rotation.z = -s * 0.25; el.rotation.x = -(0.5)
		elif (pose_request == "sky" or pose_request == "rest") and pt < 0.35:
			# 눕기 전환 앞 절반: 쪼그려 앉는다(무릎 깊이, 손은 앞에 짚을 듯)
			hip.rotation.x = -(1.2); knee.rotation.x = -(-1.9)
			sh.rotation.x = -(0.8); sh.rotation.z = -s * 0.15; el.rotation.x = -(0.6)
		elif pose_request == "sky":
			# 누워 하늘 보기: 오른 무릎 세움, 왼다리 쭉, 두 팔은 머리 뒤로 접음
			hip.rotation.x = -(0.95 if s > 0.0 else 0.05); knee.rotation.x = -(-1.7 if s > 0.0 else -0.1)
			sh.rotation.x = -(2.8); sh.rotation.z = -s * 0.7; el.rotation.x = -(2.1)
		elif lying:
			# 맞아서 등을 바닥에 — 골반을 뒤로 눕히고(pelvis −1.45) 팔다리는 살짝 벌린 채 힘없이
			hip.rotation.x = -(0.25 + 0.1 * s); knee.rotation.x = -(-0.4)
			sh.rotation.x = -(0.5 * s); sh.rotation.z = -s * 0.9; el.rotation.x = -(0.3)
		elif pose_request == "lean":
			# 가로등에 기대서기(2D lean): 어깨가 뒤로 빠지고 한쪽 발은 발끝만 걸쳐 꼬고 팔짱
			hip.rotation.x = -(0.15 if s > 0.0 else -0.35); knee.rotation.x = -(-0.1 if s > 0.0 else -0.6)
			sh.rotation.x = -(0.45); sh.rotation.z = -s * 0.05; el.rotation.x = -(1.9)
		elif pose_request == "shake":
			# 나무 흔들기(2D shake): 두 팔을 위로 뻗어 가지를 잡고 몸통째 좌우로
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.1)
			sh.rotation.x = -(2.9 + sin(_t * 9.0) * 0.15); sh.rotation.z = -s * 0.25; el.rotation.x = -(0.2)
		elif pose_request == "eat":
			# 서서 먹기(2D chew): 오른손이 입으로 오르내리고 고개가 살짝 숙여진다
			var m := (sin(_t * 4.0) + 1.0) / 2.0
			hip.rotation.x = -(1.5) if seated else 0.0; knee.rotation.x = -(-1.45) if seated else -(-0.05)   # 벤치에서 먹으면 다리는 앉은 채(run 85, 나눠 먹기 — 전엔 앉아서 먹으면 다리가 서 버렸다)
			if s > 0.0: sh.rotation.x = -(0.55 + m * 0.5); sh.rotation.z = -0.25; el.rotation.x = -(1.9 + m * 0.5)
			else: sh.rotation.x = -(0.05); sh.rotation.z = 0.1; el.rotation.x = -(0.35)
		elif pose_request == "drink":
			# 마시기: 컵을 든 손이 입까지 올라가 머물고 고개가 뒤로 젖혀진다
			var m := clampf(sin(_t * 1.6) * 0.5 + 0.5, 0.0, 1.0)
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			if s > 0.0: sh.rotation.x = -(0.7 + m * 0.4); sh.rotation.z = -0.3; el.rotation.x = -(2.2 + m * 0.3)
			else: sh.rotation.x = -(0.05); sh.rotation.z = 0.1; el.rotation.x = -(0.35)
		elif pose_request == "read":
			# 서서 읽기(2D read): 두 손이 가슴 앞, 고개 숙임
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			sh.rotation.x = -(0.5); sh.rotation.z = -s * 0.15; el.rotation.x = -(1.7)
		elif pose_request == "push":
			# 그네 밀기: 두 팔을 앞으로 내밀어 좌석을 밀고(0→0.3) 거둔다(0.3→1). 쉴 땐 팔을 앞에 반쯤 든 채 기다린다
			var k := (smoothstep(0.0, 1.0, push_t / 0.3) if push_t < 0.3 else 1.0 - smoothstep(0.0, 1.0, (push_t - 0.3) / 0.7)) if push_t < 1.0 else 0.0
			hip.rotation.x = -(0.15 * k * (1.0 if s > 0.0 else -1.0)); knee.rotation.x = -(-0.1)
			sh.rotation.x = -(0.9 + 0.8 * k); sh.rotation.z = -s * 0.1; el.rotation.x = -(1.1 - 0.9 * k)
		elif pose_request == "swing":
			# 그네(2D swing): 두 손은 위로 줄을 잡고, 앞으로 갈 때 다리를 뻗고 돌아올 때 접는다. 엉덩이는 좌석에
			hip.rotation.x = -(1.4 - swing_k * 0.5); knee.rotation.x = -(-1.2 + swing_k * 1.0)
			sh.rotation.x = -(2.6); sh.rotation.z = -s * 0.32; el.rotation.x = -(0.3)
		elif pose_request == "rest":
			# 침대에 눕기(2D sit): 등을 대고 다리는 뻗고, 한 팔은 머리 뒤, 한 팔은 배 위
			hip.rotation.x = -(0.1 + 0.05 * s); knee.rotation.x = -(-0.15 if s > 0.0 else -0.5)
			if s > 0.0: sh.rotation.x = -(2.6); sh.rotation.z = -0.5; el.rotation.x = -(1.6)
			else: sh.rotation.x = -(0.9); sh.rotation.z = 0.1; el.rotation.x = -(1.5)
		elif pose_request == "carry":
			# 가구 들기: 두 팔을 앞으로 내밀어 허리 높이에서 받쳐 든다, 걸음은 다리만
			if moving:
				var a := s * sw * 0.55 * run_k
				hip.rotation.x = -(a); knee.rotation.x = -(-(1.0 if a < 0.0 else 0.15) * run_k)
			else:
				hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			sh.rotation.x = -(0.95); sh.rotation.z = -s * 0.12; el.rotation.x = -(1.35)
		elif pose_request == "fix":
			# 수리: 벽 앞에서 한쪽 무릎 굽히고 오른손 망치질(빠르게 내려치고 천천히 올림), 왼손은 벽을 짚는다
			var hm := fmod(_t * 3.0, 1.0); var hk := 1.0 - smoothstep(0.0, 0.25, hm) if hm < 0.25 else smoothstep(0.25, 1.0, hm)
			hip.rotation.x = -(0.35 if s > 0.0 else -0.1); knee.rotation.x = -(-0.6 if s > 0.0 else -0.1)
			if s > 0.0: sh.rotation.x = -(1.2 + hk * 1.3); sh.rotation.z = -0.15; el.rotation.x = -(0.4 + hk * 0.8)
			else: sh.rotation.x = -(1.35); sh.rotation.z = 0.1; el.rotation.x = -(0.25)
		elif pose_request == "drive":
			# 운전: 앉아서 두 손으로 핸들(가슴 앞), 가끔 한 손이 기어로 — 다리는 앉은 자세
			hip.rotation.x = -(1.5); knee.rotation.x = -(-1.45)
			var gear := 1.0 if (s > 0.0 and fmod(_t, 7.0) < 0.6) else 0.0
			sh.rotation.x = -(1.25 - 0.6 * gear); sh.rotation.z = -s * 0.25; el.rotation.x = -(1.0 + 0.4 * gear)
		elif pose_request == "talk":
			# 수다: 한 손은 말하며 휘젓고(느린 원), 다른 손은 허리에. 가끔 어깨 으쓱
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			if s > 0.0: sh.rotation.x = -(0.6 + sin(_t * 3.1) * 0.35); sh.rotation.z = -0.3 - cos(_t * 3.1) * 0.15; el.rotation.x = -(1.3 + sin(_t * 2.3) * 0.3)
			else: sh.rotation.x = -(0.3); sh.rotation.z = 0.55; el.rotation.x = -(1.7)
		elif pose_request == "pet":
			# 쓰다듬기: 쪼그려 앉아(두 무릎 깊이 굽힘, 상체 앞으로) 오른손이 등을 앞뒤로 쓸고, 왼손은 무릎에
			var stroke := sin(_t * 5.5) * 0.25
			hip.rotation.x = -(1.35); knee.rotation.x = -(-2.1)
			if s > 0.0: sh.rotation.x = -(1.15 + stroke); sh.rotation.z = -0.2; el.rotation.x = -(0.25)
			else: sh.rotation.x = -(0.8); sh.rotation.z = 0.1; el.rotation.x = -(1.2)
		elif pose_request == "wave":
			# 손 흔들기(2D wave): 오른팔을 머리 위로 들어 좌우로
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			if s > 0.0: sh.rotation.x = -(2.7); sh.rotation.z = -0.35 + sin(_t * 9.0) * 0.25; el.rotation.x = -(0.5)
			else: sh.rotation.x = -(0.05); sh.rotation.z = 0.1; el.rotation.x = -(0.35)
		elif pose_request in CI_POSES and StickPoses.limbs(self, s, moving, sw, run_k):
			pass
		elif _fidget == "yawn":
			# 하품(2D yawn): 한 팔이 입 쪽으로, 다른 팔은 늘어뜨린 채
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			if s > 0.0: sh.rotation.x = -(1.1); sh.rotation.z = -0.3; el.rotation.x = -(1.6)
			else: sh.rotation.x = -(0.05); sh.rotation.z = 0.1; el.rotation.x = -(0.35)
		elif _fidget == "shrug":
			# 어깨 으쓱(2D shrug): 두 어깨가 함께 들렸다 내려간다
			var m := (sin(_fidget_t * 6.0) + 1.0) / 2.0
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			sh.rotation.x = -(0.55 + m * 0.35); sh.rotation.z = -s * (0.15 + m * 0.1); el.rotation.x = -(0.9 + m * 0.3)
		elif _fidget == "look":
			# 둘러보기(2D look): 팔은 그대로 늘어뜨리고 고개만(위에서 neck.rotation.y 로 처리)
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			sh.rotation.x = -(0.05); sh.rotation.z = 0.1; el.rotation.x = -(0.35)
		elif seated:
			# 벤치: 허벅지 앞으로 수평, 정강이 아래로, 손은 무릎 위
			hip.rotation.x = -(1.5); knee.rotation.x = -(-1.45)
			sh.rotation.x = -(0.55); sh.rotation.z = -s * 0.1; el.rotation.x = -(0.9)
		elif airborne:
			# 점프: 오를 땐 무릎을 당기고 팔을 위로, 내릴 땐 다리를 내리고 팔을 벌린다
			# 보폭 도약(운영자 스케치 2026-09-28): 오른다리(s=1)가 앞, 왼다리가 뒤. 팔은 반대 — 왼팔 앞·위, 오른팔 뒤. 내려올수록 앞다리를 내려 착지 준비
			# 공중 세 단계(운영자 2026-09-29: 공중 자세가 한 모양으로 굳어 있었다): 오름 = 무릎을 가슴으로 당기고 두 팔을 위로 휘두름,
			# 꼭대기 = 다리를 앞뒤로 벌리고 팔을 옆으로 펼침(체공), 내림 = 두 다리를 아래로 뻗어 착지 준비, 팔은 위로 들어 균형
			var up := clampf(vertical / 5.0, 0.0, 1.0); var down := clampf(-vertical / 6.0, 0.0, 1.0)
			var apex := 1.0 - maxf(up, down)
			var hipf := (1.3 * up + 0.9 * apex + 0.35 * down) if s > 0.0 else (1.0 * up - 0.55 * apex + 0.2 * down)
			var kneef := -(1.7 * up + 0.9 * apex + 0.25 * down) if s > 0.0 else -(1.4 * up + 0.8 * apex + 0.35 * down)
			hip.rotation.x = -(hipf); knee.rotation.x = -(kneef)
			sh.rotation.x = -(2.5 * up + 0.4 * apex + 1.2 * down); sh.rotation.z = -s * (0.2 * up + 1.2 * apex + 0.7 * down); el.rotation.x = -(0.4 * up + 0.2 * apex + 0.5 * down)
		elif crouch > 0.0:
			hip.rotation.x = -(1.0 * crouch)
			knee.rotation.x = -(-1.7 * crouch)
			sh.rotation.x = -(-0.5 * crouch)
			sh.rotation.z = -s * 0.15
			el.rotation.x = -(1.0 * crouch)
		elif moving:
			# 다리: 허벅지 ±43°·뒤로 갈 때 무릎 접힘(2D 와 같은 규칙)
			var a := s * sw * 0.9 * run_k
			hip.rotation.x = -(a)
			knee.rotation.x = -(-(1.4 if a < 0.0 else 0.2) * run_k)
			# 팔: 다리와 반대 위상(2D: 1.05), 팔꿈치는 2D 의 1.7 에 가깝게 접혀 손이 가슴 앞을 오간다
			sh.rotation.x = -(-s * sw * 0.8 * run_k)
			sh.rotation.z = -s * 0.04
			el.rotation.x = -(0.35 + 0.75 * run_k)  # 걷기 0.9 근처, 달리면 더 접힘
		else:
			# 서 있음: 팔은 늘어뜨리고 숨 쉬듯 미세하게
			hip.rotation.x = -(0.0)
			knee.rotation.x = -(-0.05)
			sh.rotation.x = -(sin(_t * 2.0 + s) * 0.03 - 0.08)  # 살짝 앞에 늘어뜨림
			sh.rotation.z = -s * 0.04                              # 몸에 붙임(평탄)
			el.rotation.x = -(0.35)                                # 팔꿈치 살짝 굽힘
	# 들고 있으면 오른팔은 앞으로 반쯤 들어 물건을 보인다(걸음 스윙 대신)
	if carrying and not airborne and not StickPoses.owns_right_arm(pose_request) and not carrying.has_meta("umb"):   # 먹기·마시기·물주기는 오른손을 제 자리에 둔다(전엔 이 덮어쓰기가 입까지 가던 손을 도로 내렸다); 접은 우산은 지팡이처럼 늘어뜨린 채
		shoulders[1.0].rotation.x = -(0.55)
		elbows[1.0].rotation.x = -(1.15)
	if umbr_k > 0.0: StickPoses.umbr(self)   # 우산(run 76): 오른팔만 덮어쓴다 — 걷든 서든 앉든 다리·왼팔은 위에서 정한 그대로
	# 잠깐의 동작 — 2D 자세를 그대로: 빨리 나갔다(35%) 천천히 돌아온다(65%). 공중에서도 된다(점프킥·점프 주먹)
	if lying:
		if not _was_lying: _was_lying = true; _lie_since = _t
		FightPoses.down(self, _t - _lie_since)   # 넘어져 누움: 떨어진 직후 팔다리가 들렸다 떨어진다
	else:
		_was_lying = false
	if action in ["punch", "kick", "flinch", "getup", "fight"]:
		var fa := clampf(action_t, 0.0, 1.0)
		match action:
			"fight": FightPoses.move(self, move, fa)
			"punch": FightPoses.punch(self, fa)
			"kick": FightPoses.kick(self, fa)
			"flinch": FightPoses.flinch(self, fa)
			"getup": FightPoses.getup(self, fa)
	elif action != "":
		var a := clampf(action_t, 0.0, 1.0)
		# 타격 곡선(운영자: 힘이 실려야): 예비동작 0~15%(k 가 살짝 음수 = 뒤로 당김) → 15~30% 순간적으로 뻗음 → 30~55% 뻗은 채 멈춤 → 55~100% 천천히 회수
		var k: float
		if a < 0.15: k = -0.35 * sin(a / 0.15 * PI)
		elif a < 0.30: k = smoothstep(0.0, 1.0, (a - 0.15) / 0.15)
		elif a < 0.55: k = 1.0
		else: k = 1.0 - smoothstep(0.0, 1.0, (a - 0.55) / 0.45)
		if action == "grab" or action == "flinch":
			k = sin(a * PI)
		if action == "punch":
			# 운영자 그림(2026-09-28): 힘줘서 온몸이 앞으로 쏠리는 주먹 — 골반·상체 앞으로, 앞다리(왼) 무릎 굽혀 내딛고 뒷다리(오른) 뒤로 끌림,
			# 주먹 팔은 살짝 위로 쭉, 반대팔은 뒤로. 공중이면 더 쏠린다
			if airborne:
				# 점프 주먹: 온몸이 앞으로 쏠려 내리꽂는다
				pelvis.rotation.x = 0.24 * k
				torso.rotation.x = 0.55 * k; torso.rotation.y = -0.5 * k; neck.rotation.x = -0.3 * k
				shoulders[1.0].rotation.x = -(1.75 * k); elbows[1.0].rotation.x = -(0.05 * k + 0.12 * (1.0 - k)); shoulders[1.0].rotation.z = -0.34 * k
				shoulders[-1.0].rotation.x = -(-1.0 * k); elbows[-1.0].rotation.x = -(0.7 * k)
				hips[-1.0].rotation.x = -(0.75 * k); knees[-1.0].rotation.x = -(-0.95 * k)
				hips[1.0].rotation.x = -(-0.65 * k); knees[1.0].rotation.x = -(-0.25 * k)
			else:
				# 서서 치기(운영자: 권투처럼) — 자세 좁게, 힘은 허리 회전·어깨에서. 연속기: 왼 잽 → 오른 스트레이트 → 왼 훅
				var ps := punch_side; var os := -punch_side
				pelvis.rotation.x = 0.06 * k
				neck.rotation.x = -0.1 * k
				if punch_kind == "hook":
					# 훅: 팔꿈치 굽힌 채 옆에서 돌아 들어온다 — 어깨는 옆으로 들리고 허리가 크게 돈다
					torso.rotation.x = 0.12 * k; torso.rotation.y = -ps * 1.0 * k
					shoulders[ps].rotation.x = -(1.4 * k); shoulders[ps].rotation.z = -ps * (1.3 - 0.9 * k); elbows[ps].rotation.x = -(1.5)
				else:
					var reach := 1.45 if punch_kind == "jab" else 1.75
					torso.rotation.x = (0.12 if punch_kind == "jab" else 0.25) * k; torso.rotation.y = -ps * (0.35 if punch_kind == "jab" else 0.75) * k
					shoulders[ps].rotation.x = -(reach * k); elbows[ps].rotation.x = -(0.05 * k + 0.35 * (1.0 - k)); shoulders[ps].rotation.z = -ps * 0.34 * k  # 안쪽으로 모아 정중앙 타점(운영자 지적)
				shoulders[os].rotation.x = -(0.9); elbows[os].rotation.x = -(1.9); shoulders[os].rotation.z = -os * 0.15  # 가드
				hips[os].rotation.x = -(0.28 * k); knees[os].rotation.x = -(-0.35)
				hips[ps].rotation.x = -(-0.18 * k); knees[ps].rotation.x = -(-0.3)
		elif action == "kick":
			# 발차기도 앞으로 쏠린다(운영자: 발에 힘이 들어가면 몸이 앞으로 간다) — 골반·상체 앞으로, 찬 발 앞으로 높이 쭉, 팔은 앞·뒤로 균형
			hips[1.0].rotation.x = -(1.5 * k); knees[1.0].rotation.x = -(-0.1 * k)
			pelvis.rotation.x = 0.12 * k
			torso.rotation.x = 0.3 * k; torso.rotation.y = 0.2 * k; neck.rotation.x = -0.15 * k
			shoulders[1.0].rotation.x = -(-0.9 * k); shoulders[-1.0].rotation.x = -(-0.5 * k); elbows[-1.0].rotation.x = -(0.3 * k); elbows[1.0].rotation.x = -(0.2 * k)
			if not airborne:
				knees[-1.0].rotation.x = -(-0.3 * k)
			elif jet:
				# 제트킥(운영자 스케치): 몸 전체가 앞으로 쏠려 거의 수평 — 골반을 앞으로 70° 눕히고, 찬 다리는 몸 선을 따라 앞으로 쭉,
				# 반대 다리는 접어 뒤로, 팔은 몸 선을 따라 옆·뒤로, 고개는 들어 앞을 본다
				# (두 번째 수정: 처음엔 70° 눕혀 바닥에 누운 꼴이 됐다) 몸통은 20° 만 앞으로, 찬 다리는 정확히 수평 앞, 반대 다리 접어 뒤, 팔은 옆으로 수평, 고개 앞
				# (네 번째, 운영자 그림 2026-09-28 승인용): 척추가 굽어 앞으로(골반 0.3·허리 0.3·가슴 0.3), 찬 다리 수평 앞, 뒷다리 짧게 뒤로 접힘,
				# 앞팔은 앞·아래 40°, 뒷팔은 곧게 뒤로 수평, 고개는 살짝 들어 앞. 옆으로 벌리지 않는다(앞에서 보면 팔이 앞쪽)
				pelvis.rotation.x = 0.3 * k
				torso.rotation.x = 0.3 * k; chest.rotation.x = 0.3 * k; torso.rotation.y = 0.15 * k; neck.rotation.x = -0.3 * k
				hips[1.0].rotation.x = -(1.87 * k); knees[1.0].rotation.x = -(0.0)
				hips[-1.0].rotation.x = -(-0.3 * k); knees[-1.0].rotation.x = -(-0.55 * k)  # 발은 아래로(정강이 뒤·아래) — 위로 접으면 안 된다(운영자 지적)
				shoulders[1.0].rotation.x = -(2.47 * k); shoulders[1.0].rotation.z = -0.08 * k; elbows[1.0].rotation.x = -(0.1 * k)  # 앞팔 수평(그림)
				shoulders[-1.0].rotation.x = -(-0.67 * k); shoulders[-1.0].rotation.z = 0.08 * k; elbows[-1.0].rotation.x = -(0.05 * k)
			else:
				# 비행 킥: 찬 다리 앞으로 쭉, 반대 다리는 접어 뒤로, 상체는 뒤로 젖혀 비틀고, 양팔은 벌려 균형
				hips[1.0].rotation.x = -(1.75 * k); knees[1.0].rotation.x = -(0.0)
				hips[-1.0].rotation.x = -(-0.7 * k); knees[-1.0].rotation.x = -(-1.6 * k)
				torso.rotation.x = -0.5 * k; torso.rotation.y = 0.35 * k; neck.rotation.x = 0.3 * k
				shoulders[1.0].rotation.x = -(-1.1 * k); shoulders[1.0].rotation.z = -0.7 * k
				shoulders[-1.0].rotation.x = -(0.4 * k); shoulders[-1.0].rotation.z = 0.8 * k; elbows[-1.0].rotation.x = -(0.3 * k)
		elif action == "throw":
			# 2D throw: 앞 절반은 팔을 뒤로 높이 감고(뒷다리에 체중), 뒤 절반은 앞으로 쭉 뻗어 놓는다
			var back := a < 0.45
			var w := smoothstep(0.0, 1.0, a / 0.45) if back else smoothstep(0.0, 1.0, (a - 0.45) / 0.3)
			shoulders[1.0].rotation.x = -(-2.4 * w) if back else -(lerpf(-2.4, 1.3, w))
			elbows[1.0].rotation.x = -(1.0 * w) if back else -(lerpf(1.0, 0.1, w))
			torso.rotation.y = (0.5 * w) if back else lerpf(0.5, -0.4, w)
			torso.rotation.x = (-0.15 * w) if back else lerpf(-0.15, 0.3, w)
			if not airborne:
				hips[1.0].rotation.x = -(-0.3); hips[-1.0].rotation.x = -(0.3)
		elif action == "flinch":
			# 맞음: 머리가 뒤로 젖혀지고 상체가 뒤로 밀리며 무릎이 살짝 꺾이고 팔이 반사적으로 올라온다(0.25초)
			var f := sin(a * PI)
			pelvis.rotation.x = -0.12 * f
			torso.rotation.x = -0.4 * f; torso.rotation.y = 0.25 * f; neck.rotation.x = -0.5 * f
			hips[1.0].rotation.x = -(0.2 * f); hips[-1.0].rotation.x = -(-0.25 * f); knees[1.0].rotation.x = -(-0.5 * f); knees[-1.0].rotation.x = -(-0.4 * f)
			shoulders[1.0].rotation.x = -(0.7 * f); shoulders[-1.0].rotation.x = -(0.5 * f); elbows[1.0].rotation.x = -(1.6 * f); elbows[-1.0].rotation.x = -(1.4 * f)
		elif action == "getup":
			# 일어나기: 누운 골반이 세워지며 한 손으로 바닥을 짚고 무릎을 세운다
			var g := clampf(a, 0.0, 1.0)
			pelvis.rotation.x = -1.45 * (1.0 - g)
			pelvis.position.y = lerpf(0.12, HIP_Y, g)
			torso.rotation.x = 0.7 * sin(g * PI)
			hips[1.0].rotation.x = -(1.2 * (1.0 - g)); knees[1.0].rotation.x = -(-1.6 * (1.0 - g))
			hips[-1.0].rotation.x = -(0.4 * (1.0 - g)); knees[-1.0].rotation.x = -(-0.6 * (1.0 - g))
			shoulders[1.0].rotation.x = -(-1.2 * sin(g * PI)); elbows[1.0].rotation.x = -(0.2)
		elif action == "grab":
			torso.rotation.x = 0.9 * k
			hips[1.0].rotation.x = -(0.35 * k); hips[-1.0].rotation.x = -(0.35 * k)
			knees[1.0].rotation.x = -(-0.7 * k); knees[-1.0].rotation.x = -(-0.7 * k)
			shoulders[1.0].rotation.x = -(1.3 * k)
			elbows[1.0].rotation.x = -(0.2 * k)
	# 블렌딩 속도: 동작 중엔 아주 빠르게(주먹이 0.28초라 뭉개지면 안 된다), 앉기·웅크림은 느리게, 걷기는 중간
	var rate := (60.0 if action in ["punch", "kick", "flinch", "fight"] else 34.0) if action != "" else (9.0 if seated or crouch > 0.0 else 30.0)  # 걷기는 거의 즉답
	var k := minf(1.0, delta * rate)
	for pv in _pivots:
		var want: Vector3 = pv.rotation
		var was: Vector3 = prev[pv]
		pv.rotation = Vector3(lerp_angle(was.x, want.x, k), lerp_angle(was.y, want.y, k), lerp_angle(was.z, want.z, k))
	pelvis.position.y = lerpf(prev_pelvis_y, pelvis.position.y, k)
	pelvis.rotation.x = lerp_angle(prev_pelvis_rot.x, pelvis.rotation.x, k)
	_keep_upright()

## 컵·캔·빵·사과 같은 건 손이 어떻게 돌든 바로 선 채로(운영자 2026-10-06: 컵을 옆으로 눕혀 들고 다녔다) — 손 자리는 따라가고 방향만 세계 기준으로 세운다
const UPRIGHT := ["cup", "can", "bread", "apple", "tomato", "cabbage", "pumpkin", "fish", "coin"]
func _keep_upright() -> void:
	for it in [carrying] + pocket:
		if it != null and is_instance_valid(it) and it.is_inside_tree() and String(it.get_meta("kind", "")) in UPRIGHT:
			it.global_basis = Basis(Vector3.UP, global_rotation.y)

## 바깥에서 방향을 정한다(벤치에 앉을 때 등) — 부드럽게 돌아간다
func face(yaw: float) -> void:
	_yaw_target = yaw
