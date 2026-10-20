class_name PivotPoses
extends RefCounted
## 외바퀴 손수레를 돌리는 자세(Climb 팩 barrow 의 책 담당, run 185 — 운영자 보드의 '외바퀴 손수레' 가족의 둘째 자세): `pivot` 손잡이 뒤에서 숙여 손잡이를 들고(0.3 s), 수레의 가운데를 돌아 네 번 옆걸음치며 수레를 반 바퀴 돌리고(0.8 s — 바퀴와 손잡이가 자리를 바꾼다, 몸은 반대쪽에 선다), 내려놓는(0.2 s) 몸. 수레의 몸체(yaw)와 돌리는 이의 자리(호)는 팩(climb_barrow.turn)과 책 담당(climb_page)이 옮긴다 — 여기는 몸만.
## 시계는 하나고 팩이 적는다: meta "piv_t"(자세에 든 뒤 시간). 메타가 없으면 pose_t 로 혼자 한 번 돈다(점검·시연용).
## 들기(0..0.3): 골반이 0.06 내려앉고 상체가 0.3 숙여 두 팔이 뒤 아래 손잡이로(어깨 −0.35·z 로 0.12 벌려·팔꿈치 −0.05 — barrow 의 잡은 팔과 같다) 두 무릎이 조금 접히고(0.15) 고개가 바퀴를 본다(+0.3)
## → 옆걸음(0.3..1.1): 5 Hz 의 네 걸음 — 바깥 다리가 벌어지며(엉덩이 z 0.22) 무릎이 들리고(0.35) 안 다리가 따라 붙는다; 상체가 걸음에 0.05 흔들리고 팔이 4 Hz 로 떤다 → 놓기(1.1..1.3): 상체·팔·무릎이 돌아온다. 0.8 Hz 숨 — 정지화가 아니다.
## barrow(잡고 앞으로 민다)·shunt(앞의 것을 민다)·turn(제자리에서 몸이 돈다)과 다르다: 이건 잡은 것을 중심으로 몸이 반 바퀴 옆걸음치는 첫 자세. stick3d_barrow.gd 처럼 주제별 파일

const LIFT_T := 0.3                         # 손잡이를 드는 시간(s)
const SWING_T := 0.8                        # 반 바퀴 옆걸음(s)
const SET_T := 0.2                          # 내려놓는 시간(s)
const TOTAL := LIFT_T + SWING_T + SET_T     # 자세 전체(s) — 팩이 이만큼 뒤 dir 를 뒤집는다
const STEPS := 4.0                          # 옆걸음 수
const TREMBLE_HZ := 4.0
const BREATHE_HZ := 0.8
const DIP := 0.06
const LEAN := 0.3
const ARM_X := 0.35; const ARM_Z := 0.12; const ARM_EL := 0.05   # barrow 의 잡은 팔과 같은 수
const KNEE := 0.15
const STEP_Z := 0.22; const STEP_KNEE := 0.35
const LOOK := 0.3

## 자세에 든 뒤 시간(s) — 팩의 메타, 없으면 pose_t
static func since(f: Stick3D) -> float:
	if f.has_meta("piv_t"): return maxf(0.0, float(f.get_meta("piv_t")))
	return f.pose_t

## 옆걸음의 진행 0..1 — 팩은 이 몫으로 수레를 돌리고 책 담당은 호를 걷는다
static func swing(f: Stick3D) -> float:
	return clampf((since(f) - LIFT_T) / SWING_T, 0.0, 1.0)

static func done(f: Stick3D) -> bool:
	return since(f) >= TOTAL

## [lift, step] — 든 몫(0.3 에 들어 마지막 0.2 에 놓는다), 걸음(−1..1: 양수면 오른다리가 밖으로)
static func phases(f: Stick3D) -> Array:
	var u := since(f)
	var lift := smoothstep(0.0, LIFT_T, u) * (1.0 - smoothstep(TOTAL - SET_T, TOTAL, u))
	var q := swing(f)
	var step := sin(TAU * STEPS * q) * (1.0 if q > 0.0 and q < 1.0 else 0.0)
	return [lift, step]

## 골반은 들면 내려앉고 걸음과 숨에 흔들린다; 상체는 들면 숙이고 걸음에 흔들린다
static func lean(f: Stick3D) -> float:
	var ph := phases(f); var lift := float(ph[0]); var step := float(ph[1])
	f.pelvis.position.y = StickRig.HIP_Y - DIP * lift - 0.02 * absf(step) + 0.01 * sin(f._t * TAU * BREATHE_HZ)
	return LEAN * lift + 0.05 * step

## 팔다리 — 두 팔: 뒤 아래 손잡이를 잡고 떤다; 두 다리: 조금 접혀, 걸음에 바깥 다리가 벌어지며 무릎이 들린다; 고개는 바퀴를 본다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "pivot": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(f); var lift := float(ph[0]); var step := float(ph[1])
	var out := maxf(0.0, s * step)                                   # 이 다리가 밖으로 나가는 몫
	var tremble := sin(f._t * TAU * TREMBLE_HZ + s) * 0.015 * lift
	var breathe := sin(f._t * TAU * BREATHE_HZ) * 0.03
	hip.rotation.x = -0.1 * lift
	hip.rotation.z = -s * STEP_Z * out
	knee.rotation.x = KNEE * lift + STEP_KNEE * out + breathe * (0.5 if s < 0.0 else 0.0)
	sh.rotation.x = -ARM_X * lift + tremble
	sh.rotation.z = -s * ARM_Z * lift
	el.rotation.x = -ARM_EL * lift
	if s > 0.0: f.neck.rotation.x += LOOK * lift
	return true
