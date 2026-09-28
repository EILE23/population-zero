class_name StickPoses
extends RefCounted
## 졸라맨의 `pose_request` 자세들 — stick3d.gd 에서 떼어 냈다(코드 정리, run 70: 그 파일이 497줄이라 자세를 하나도 더 못 넣었다).
## `lean()` 은 상체 기울기(와 골반 위치)를, `limbs()` 는 한쪽 팔다리의 관절 각을 정한다. 둘 다 stick3d.gd 의 _process 가 프레임마다 부른다.
## 각도 부호 약속은 stick3d.gd 머리말과 같다: 매달린 뼈는 -( ) 로 뒤집어 '앞 = 양수'로 읽는다.
## 타이밍: `f.pose_t` 는 지금 자세가 시작된 뒤 흐른 시간 — 새 자세는 이걸로 예비(windup)·유지(hold)·회수(recovery)를 갖는다. 정지화 한 장은 자세가 아니다.

const WATER_T := 2.4   # 물주기 한 번: 0.35 들어올림 → 붓기 → 마지막 0.35 바로 서기. 그 뒤엔 pose_request 가 풀릴 때까지 물뿌리개를 든 채 선다

## 상체 기울기 — base 는 걷기·웅크림·공중에서 계산된 값. 자세가 정하면 덮어쓴다(원래 stick3d.gd 에 있던 순서 그대로)
static func lean(f: Stick3D, moving: bool, delta: float, base: float) -> float:
	var lean := base
	var p := f.pose_request
	if p == "lean" and not moving:
		lean = -0.2
	if p == "shake" and not moving:
		lean = sin(f._t * 9.0) * 0.12
	if p == "read" and not moving:
		lean = 0.12
	if p == "drink" and not moving:
		lean = -0.12
	if p == "eat" and not moving:
		lean = 0.08
	if p == "swing":
		lean = -0.15 - f.swing_k * 0.25
	if p == "push":
		f.push_t += delta * 1.6
		lean = 0.25 if f.push_t < 0.3 else 0.08
	if p == "water" and not moving:
		# 물주기(2D water): 앞으로 숙여 붓는다 — 붓는 동안 살짝 흔들린다(물뿌리개 무게)
		var k := water_k(f.pose_t)
		lean = 0.3 * k + sin(f._t * 3.0) * 0.03 * k
	if p == "rest":
		f.pelvis.rotation.x = -1.5; lean = 0.25 + sin(f._t * 1.6) * 0.02
		f.pelvis.position.y = 0.16
	return lean

## 물주기 진행 0..1 — 0.35초에 걸쳐 숙였다가(예비), 붓고(유지), 끝 0.35초에 바로 선다(회수). WATER_T 뒤엔 0(든 채 서기)
static func water_k(t: float) -> float:
	if t >= WATER_T: return 0.0
	if t < 0.35: return smoothstep(0.0, 1.0, t / 0.35)
	if t > WATER_T - 0.35: return 1.0 - smoothstep(0.0, 1.0, (t - (WATER_T - 0.35)) / 0.35)
	return 1.0

## 물뿌리개 물방울 — 든 것에 "drops" 입자가 달려 있으면(town_base make_item "can") 붓는 동안만 켠다
static func drops(f: Stick3D, on: bool) -> void:
	if f.carrying == null or not f.carrying.has_meta("drops"): return
	(f.carrying.get_meta("drops") as CPUParticles3D).emitting = on

## 이 자세가 오른팔을 직접 쓰는가 — 그러면 stick3d.gd 의 '들고 있으면 오른팔 앞으로' 덮어쓰기를 건너뛴다(먹기·마시기 손이 입까지 못 올라가던 것)
static func owns_right_arm(p: String) -> bool:
	return p in ["eat", "drink", "water"]

## 한쪽(s = -1 왼, +1 오른) 팔다리 — pose_request 에 맞는 자세가 있으면 대입하고 true, 없으면 false(호출자가 기지개·앉기·걷기로 이어간다)
static func limbs(f: Stick3D, s: float, moving: bool, sw: float, run_k: float) -> bool:
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t: float = f._t
	match f.pose_request:
		"lean":
			# 가로등에 기대서기(2D lean): 어깨가 뒤로 빠지고 한쪽 발은 발끝만 걸쳐 꼬고 팔짱
			hip.rotation.x = -(0.15 if s > 0.0 else -0.35); knee.rotation.x = -(-0.1 if s > 0.0 else -0.6)
			sh.rotation.x = -(0.45); sh.rotation.z = -s * 0.05; el.rotation.x = -(1.9)
		"shake":
			# 나무 흔들기(2D shake): 두 팔을 위로 뻗어 가지를 잡고 몸통째 좌우로
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.1)
			sh.rotation.x = -(2.9 + sin(t * 9.0) * 0.15); sh.rotation.z = -s * 0.25; el.rotation.x = -(0.2)
		"eat":
			# 서서 먹기(2D chew): 오른손이 입으로 오르내리고 고개가 살짝 숙여진다
			var m := (sin(t * 4.0) + 1.0) / 2.0
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			if s > 0.0: sh.rotation.x = -(0.55 + m * 0.5); sh.rotation.z = -0.25; el.rotation.x = -(1.9 + m * 0.5)
			else: sh.rotation.x = -(0.05); sh.rotation.z = 0.1; el.rotation.x = -(0.35)
		"drink":
			# 마시기: 컵을 든 손이 입까지 올라가 머물고 고개가 뒤로 젖혀진다
			var m := clampf(sin(t * 1.6) * 0.5 + 0.5, 0.0, 1.0)
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			if s > 0.0: sh.rotation.x = -(0.7 + m * 0.4); sh.rotation.z = -0.3; el.rotation.x = -(2.2 + m * 0.3)
			else: sh.rotation.x = -(0.05); sh.rotation.z = 0.1; el.rotation.x = -(0.35)
		"read":
			# 서서 읽기(2D read): 두 손이 가슴 앞, 고개 숙임
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			sh.rotation.x = -(0.5); sh.rotation.z = -s * 0.15; el.rotation.x = -(1.7)
		"push":
			# 그네 밀기: 두 팔을 앞으로 내밀어 좌석을 밀고(0→0.3) 거둔다(0.3→1). 쉴 땐 팔을 앞에 반쯤 든 채 기다린다
			var pt: float = f.push_t
			var k := (smoothstep(0.0, 1.0, pt / 0.3) if pt < 0.3 else 1.0 - smoothstep(0.0, 1.0, (pt - 0.3) / 0.7)) if pt < 1.0 else 0.0
			hip.rotation.x = -(0.15 * k * (1.0 if s > 0.0 else -1.0)); knee.rotation.x = -(-0.1)
			sh.rotation.x = -(0.9 + 0.8 * k); sh.rotation.z = -s * 0.1; el.rotation.x = -(1.1 - 0.9 * k)
		"swing":
			# 그네(2D swing): 두 손은 위로 줄을 잡고, 앞으로 갈 때 다리를 뻗고 돌아올 때 접는다. 엉덩이는 좌석에
			hip.rotation.x = -(1.4 - f.swing_k * 0.5); knee.rotation.x = -(-1.2 + f.swing_k * 1.0)
			sh.rotation.x = -(2.6); sh.rotation.z = -s * 0.32; el.rotation.x = -(0.3)
		"rest":
			# 침대에 눕기(2D sit): 등을 대고 다리는 뻗고, 한 팔은 머리 뒤, 한 팔은 배 위
			hip.rotation.x = -(0.1 + 0.05 * s); knee.rotation.x = -(-0.15 if s > 0.0 else -0.5)
			if s > 0.0: sh.rotation.x = -(2.6); sh.rotation.z = -0.5; el.rotation.x = -(1.6)
			else: sh.rotation.x = -(0.9); sh.rotation.z = 0.1; el.rotation.x = -(1.5)
		"carry":
			# 가구 들기: 두 팔을 앞으로 내밀어 허리 높이에서 받쳐 든다, 걸음은 다리만
			if moving:
				var a := s * sw * 0.55 * run_k
				hip.rotation.x = -(a); knee.rotation.x = -(-(1.0 if a < 0.0 else 0.15) * run_k)
			else:
				hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			sh.rotation.x = -(0.95); sh.rotation.z = -s * 0.12; el.rotation.x = -(1.35)
		"wave":
			# 손 흔들기(2D wave): 오른팔을 머리 위로 들어 좌우로
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			if s > 0.0: sh.rotation.x = -(2.7); sh.rotation.z = -0.35 + sin(t * 9.0) * 0.25; el.rotation.x = -(0.5)
			else: sh.rotation.x = -(0.05); sh.rotation.z = 0.1; el.rotation.x = -(0.35)
		"water":
			# 물주기(2D water, 텃밭 가족의 첫 자세 — run 70): 오른손의 물뿌리개를 앞·아래로 내밀어 기울이고(손목 hand_r 이 주둥이를 숙인다),
			# 왼팔은 반쯤 앞에서 균형, 오른발이 반 걸음 앞. k 가 예비·유지·회수를 만든다 — 붓는 동안만 물방울
			var k := water_k(f.pose_t)
			hip.rotation.x = -(0.12 * k) if s > 0.0 else -(-0.05 * k); knee.rotation.x = -(-0.08)
			if s > 0.0:
				sh.rotation.x = -(0.35 + 0.55 * k); sh.rotation.z = -0.15; el.rotation.x = -(0.25 + 0.1 * k)
				f.hand_r.rotation.x = 0.85 * k
				drops(f, k > 0.95)
			else:
				sh.rotation.x = -(0.15 + 0.25 * k); sh.rotation.z = 0.12; el.rotation.x = -(0.6)
		_:
			return false
	return true
