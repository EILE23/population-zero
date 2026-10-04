class_name KidPoses
extends RefCounted
## 아이 걸음 `skip`("Elders and children" 1조각, run 102): 걸음마다 한 번 뛴다 — 0.12 무릎을 접어 웅크리고(예비), 0.18 떠서 앞다리 허벅지를 높이 올리고
## 팔은 다리와 반대로 크게 젓고(유지), 0.1 내려앉으며 무릎이 깊게 접힌다(회수). 한 걸음 0.4초, 왼발·오른발 번갈아 — 정지화가 아니라 박자다.
## 아이(ResidentKid)는 걸을 때 늘 이 걸음, 사람은 SPACE 를 두 번 톡톡 친 뒤 3초 동안 빈손으로 걸으면 같은 걸음(player). 걸음 박자는 시간으로 — 몸집이 작아도 같은 리듬

const STEP_T := 0.4
const CROUCH := 0.12   # 예비
const FLOAT := 0.18    # 유지(공중)
const LAND := 0.1      # 회수(착지)
const HOLD := 3.0      # 사람: 두 번 톡톡 뒤 이만큼
const TAP_GAP := 0.4   # 이 안에 두 번이면 '톡톡'

## 걸음 안의 시각 0..STEP_T, 이번 걸음의 앞다리(+1 오른 · −1 왼)
static func _t(f: Stick3D) -> float:
	return fmod(f._t, STEP_T)
static func lead(f: Stick3D) -> float:
	return 1.0 if fmod(f._t, STEP_T * 2.0) < STEP_T else -1.0

## 웅크림 0..1(예비에서 차오르고 뜨며 풀린다), 뜸 0..1..0, 착지 0..1..0
static func crouch_k(t: float) -> float:
	return smoothstep(0.0, CROUCH, t) * (1.0 - smoothstep(CROUCH, CROUCH + 0.08, t))
static func float_k(t: float) -> float:
	return sin(clampf((t - CROUCH) / FLOAT, 0.0, 1.0) * PI)
static func land_k(t: float) -> float:
	return sin(clampf((t - CROUCH - FLOAT) / LAND, 0.0, 1.0) * PI)

static func moving(f: Stick3D) -> bool:
	return f.pose_request == "skip" and f.speed > 0.05 and f.move_dir.length_squared() > 0.0001 and not f.airborne and not f.seated

## 몸통 기울기 + 골반 높이 — 웅크릴 때 숙고 내려가며, 뜰 때 곧게 솟고, 내려앉을 때 다시 숙는다
static func lean(f: Stick3D, base: float) -> float:
	if not moving(f): return base
	var t := _t(f)
	var c := crouch_k(t); var u := float_k(t); var l := land_k(t)
	f.pelvis.position.y = StickRig.HIP_Y - 0.06 * c + 0.09 * u - 0.07 * l
	return 0.06 + 0.14 * c - 0.04 * u + 0.12 * l

static func limbs(f: Stick3D, s: float) -> bool:
	if not moving(f): return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t := _t(f); var front := s == lead(f)
	var c := crouch_k(t); var u := float_k(t); var l := land_k(t)
	# 앞다리: 허벅지가 높이 올라 무릎이 접힌 채 떴다가 내딛는다. 뒷다리: 밀어내며 뒤로 뻗었다 따라온다
	var thigh := 0.3 * c + (1.15 * u + 0.5 * l if front else -0.35 * u + 0.1 * l)
	var bend := 0.65 * c + (1.3 * u + 0.9 * l if front else 0.4 * u + 0.75 * l)
	hip.rotation.x = -(thigh); knee.rotation.x = -(-bend)
	# 팔: 다리와 반대 — 앞다리 쪽 팔은 뒤로, 반대 팔은 앞으로 높이(뜰 때 가장 크게), 팔꿈치는 뜰수록 접힌다
	var arm := maxf(u, 0.45 * (c + l)) * (-0.6 if front else 1.3)
	sh.rotation.x = -(arm); sh.rotation.z = -s * (0.1 + 0.2 * u); el.rotation.x = -(0.55 + 0.6 * u)
	return true

## 사람의 반쪽 — SPACE 두 번 톡톡(TAP_GAP 안)이면 HOLD 초 동안, 빈손으로 땅에서 걸으면 skip. 멈추거나 들거나 다른 자세가 오면 바로 놓는다
static func player(f: Stick3D, now: float, tapped: bool, walking: bool) -> void:
	if tapped:
		if now - float(f.get_meta("skip_tap", -9.0)) < TAP_GAP: f.set_meta("skip_until", now + HOLD)
		f.set_meta("skip_tap", now)
	var on: bool = now < float(f.get_meta("skip_until", -9.0)) and walking and f.carrying == null
	if on and f.pose_request == "": f.pose_request = "skip"
	elif not on and f.pose_request == "skip": f.pose_request = ""
