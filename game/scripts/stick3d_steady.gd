class_name SteadyPoses
extends RefCounted
## 발 얹기 자세(Climb 팩 log 의 주민 반쪽 — 통나무꾼, run 167; 운영자 보드의 '균형' 가족의 셋째 자세, tiptoe·log 의 다음): `steady` 통나무 옆에 서서 올라타기 전에 오른발을 얹어 통나무를 눌러 보는 몸 —
## 얹기(0..0.2): 무게가 왼다리로 옮겨 왼 무릎이 굽고 골반이 내려앉으며, 오른다리가 앞으로 들려 정강이가 통나무 위로 뻗고, 두 팔이 옆으로 벌어지며 상체가 앞으로 숙는다(예비)
## → 누르기(0.2..0.6): 얹은 발이 한 번 통나무를 눌렀다 놓고(코사인 한 바퀴 — 무릎이 펴지며 허벅지가 내려가고 골반이 같이 가라앉는다), 벌린 팔은 10 Hz 잔떨림으로 균형을 잡고 고개는 발밑의 통나무를 본다(유지 — 어느 순간도 정지화가 아니다)
## → 거두기(0.6..0.8): 발이 내려와 고르게 서고 팔이 내려온다(회수) — 그 다음이 올라타기(log). limber(들린 발을 턴다)·log(통나무 위의 걸음)·tiptoe(한 줄 위)와 다르다: 이건 구르는 것을 타기 전에 발로 눌러 보는 한 번.
## 시계는 pose_t; meta "steady_t" 가 있으면 그 값(점검용). done(f) 가 참이면(STEADY_T) 팩이 자세를 비운다. stick3d_flourish.gd 처럼 주제별 파일

const SET_T := 0.2
const PRESS_T := 0.4      # 누르기 구간 — 한 번 눌렀다 놓는다
const STEADY_T := 0.8
const WOB_HZ := 10.0      # 벌린 팔의 잔떨림
const DIP := 0.05         # 무게가 왼다리로 옮겨 골반이 내려앉는 높이(m)
const PRESS := 0.03       # 누를 때 더 가라앉는 높이(m)
const REACH := 0.9        # 얹은 다리가 앞으로 드는 각(rad)
const ARM := 0.9          # 팔이 옆으로 벌어지는 각(rad)

## 자세의 시계 — 점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("steady_t", f.pose_t))

## 끝났나 — 팩이 자세를 비운다
static func done(f: Stick3D) -> bool:
	return at(f) >= STEADY_T

## [set, press] — 발이 얹힌 몫 0..1(얹기에 오르고 거두기에 내려온다), 누름 0..1(누르기 구간에 코사인 한 바퀴: 0 → 1 → 0)
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var lift := smoothstep(0.0, SET_T, u) * (1.0 - smoothstep(SET_T + PRESS_T, STEADY_T, u))
	var press := 0.5 - 0.5 * cos(clampf((u - SET_T) / PRESS_T, 0.0, 1.0) * TAU)
	return [lift, press]

## 골반은 왼다리에 무게가 실려 내려앉고 누를 때 더 가라앉는다; 상체는 통나무 위로 숙는다
static func lean(f: Stick3D) -> float:
	var ph := phases(f); var lift := float(ph[0]); var press := float(ph[1])
	f.pelvis.position.y = StickRig.HIP_Y - (DIP + PRESS * press) * lift
	return 0.25 * lift + 0.1 * press * lift

## 팔다리 — 오른다리: 앞으로 들려 통나무에 얹히고 누를수록 허벅지가 내려가며 무릎이 펴진다; 왼다리: 무게를 받아 무릎이 굽고 누를 때 더 굽는다; 팔: 옆으로 벌려 잔떨림; 고개: 발밑
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "steady": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(f); var lift := float(ph[0]); var press := float(ph[1])
	var wob := sin(f._t * TAU * WOB_HZ + s) * 0.05 * lift   # 팔의 잔떨림 — 정지화가 아니다
	if s > 0.0:
		hip.rotation.x = -(REACH - 0.15 * press) * lift; hip.rotation.z = 0.0   # 얹은 다리 — 누를수록 허벅지가 내려간다
		knee.rotation.x = (0.6 - 0.3 * press) * lift                             # 누르며 무릎이 펴진다
	else:
		hip.rotation.x = (0.15 + 0.1 * press) * lift; hip.rotation.z = 0.0        # 선 다리 — 무게를 받아 굽는다
		knee.rotation.x = (0.35 + 0.2 * press) * lift
	sh.rotation.z = -s * (0.15 + ARM * lift); sh.rotation.x = wob
	el.rotation.x = -(0.35 + 0.1 * lift)
	if s > 0.0: f.neck.rotation.x += 0.5 * lift   # 숙인 상체(0.16)를 고개가 되돌리는 몫을 넘어 발밑을 본다
	return true
