class_name LogPoses
extends RefCounted
## 통나무 가족 자세(Climb 콘텐츠 팩 log, run 166 — data/climb/log.json, scripts/games/climb_log.gd; 운영자 보드의 '균형' 가족, tiptoe 의 다음): `log` 구르는 통나무 위의 몸 —
## 0.15 두 팔이 어깨 높이로 수평히 벌어지고 무릎이 조금 내려앉는다(예비) → 유지: 무릎을 높이 드는 짧고 빠른 걸음(STEP_T 0.25 s 에 한 걸음 — 발밑이 뒤로 굴러가니 제자리 뛰듯), 팔은 다리와 반대로 조금 흔들리고 몸통은 구르는 속도만큼 뒤로 기운다;
## 멈추면(meta "log_v" 0..1 = 구르는 속도 / 걷는 속도의 slow 배, 팩의 roll 이 적는다; 없으면 느린 맥박의 시연값) 걸음은 9 Hz 의 잔발 구르기가 되고 팔이 휘돌며 몸통이 앞으로 — 엎어지기 직전의 허둥댐(어느 순간도 정지화가 아니다); 고개는 발밑을 본다 →
## 자세가 풀리면 stick3d 의 블렌딩이 팔을 내린다(회수). tiptoe(곧은 다리로 한 줄에 선다)·tread(톱니 띠 — 몸이 실려 간다)와 다르다: 이건 제 발밑이 제 걸음에 굴러가는 몸. stick3d_tiptoe.gd 처럼 주제별 파일

const RISE_T := 0.15
const STEP_T := 0.25
const SCRAMBLE_HZ := 9.0
const DIP := 0.06         # 무릎이 내려앉아 골반이 낮아지는 높이(m)
const ARM := 1.25         # 팔이 수평으로 벌어지는 각(rad)

## 벌어진 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, RISE_T, f.pose_t)

## 구르는 속도 0..1 — 팩이 적어 준 값, 없으면 느린 맥박(주민·시연용)
static func v(f: Stick3D) -> float:
	return clampf(float(f.get_meta("log_v", 0.6 + 0.4 * sin(f._t * 1.3))), 0.0, 1.0)

## 걸음의 박자 −1..1 — +면 오른발이 뜬다
static func beat(f: Stick3D) -> float:
	return sin(f._t * TAU / (STEP_T * 2.0))

## 골반은 조금 내려앉아 걸음마다 까딱이고 무게가 발에서 발로 옮겨 가며(z 돌림), 멈추면 잘게 떤다; 몸통은 구르면 뒤로, 허둥대면 앞으로
static func lean(f: Stick3D) -> float:
	var kk := k(f); var vv := v(f); var b := beat(f)
	f.pelvis.position.y = StickRig.HIP_Y - (DIP - 0.02 * absf(b) * vv + 0.01 * sin(f._t * TAU * SCRAMBLE_HZ) * (1.0 - vv)) * kk
	f.pelvis.rotation.z = 0.06 * b * kk
	return (-0.08 * vv + 0.15 * (1.0 - vv)) * kk + 0.01 * sin(f._t * 3.0) * kk

## 팔다리 — 다리는 번갈아 무릎을 높이 들고(멈추면 잔발), 팔은 수평으로 벌려 다리와 반대로 흔들리다 멈추면 휘돈다; 고개는 발밑
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "log": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var vv := v(f); var b := beat(f) * s
	var lift := maxf(b, 0.0)                                                # 이쪽 발이 뜨는 정도
	var jitter := sin(f._t * TAU * SCRAMBLE_HZ + s) * 0.2 * (1.0 - vv) * kk  # 잔발 — 멈출수록 크다
	hip.rotation.x = -(0.15 + 1.0 * lift) * kk - jitter; hip.rotation.z = 0.0
	knee.rotation.x = (0.25 + 1.2 * lift) * kk + jitter
	sh.rotation.z = -s * (0.15 + ARM * kk)
	sh.rotation.x = -0.3 * b * vv * kk + sin(f._t * TAU * SCRAMBLE_HZ * 0.5 + s * 1.7) * 0.7 * (1.0 - vv) * kk
	el.rotation.x = -(0.3 + 0.1 * kk)
	if s > 0.0:
		f.neck.rotation.x += 0.3 * kk; f.chest.rotation.x += 0.05 * kk
	return true
