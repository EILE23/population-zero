class_name TurnPoses
extends RefCounted
## 회전문 밀기 가족 자세(Climb 콘텐츠 팩 door, run 134 — data/climb/door.json, scripts/games/climb_door.gd; 운영자 보드의 '밀기' 가족 중 한 손으로 미는 몸): `turn` 회전문의 잎을 밀며 호를 따라 도는 몸 —
## 0.2 오른손이 가슴 높이의 손잡이에 닿고(팔꿈치 접은 채) 왼팔은 뒤로 늘어지며 골반이 조금 내려앉고 몸통이 살짝 기운다(예비 — 걸음에서 문으로 한 걸음) → 유지: 잎의 속도(meta "turn_v" 0..1, 팩의 push 가 적는다, 없으면 1)만큼
## 2.2Hz 의 잰걸음(짧은 보폭 — 호를 따라 종종걸음)으로 다리가 가고, 왼팔이 걸음에 작게 흔들리고, 몸통이 걸음에 흔들리며, 고개는 도는 쪽을 본다; 문이 서면(turn_v 0) 손을 댄 채 두 발로 서서 몸통만 숨에 흔들린다
## → 손을 떼 로더가 자세를 비우면 stick3d 의 블렌딩이 팔을 내리고 몸을 세운다(회수). 몸이 보는 쪽이 미는 쪽(로더가 face = dir).
## shunt(두 손을 대고 깊이 기울여 다리로 민다 — 무겁다)와 다르다: 이건 한 손으로 가볍게 밀며 걸음이 따라가는 몸. stick3d_shunt.gd 처럼 주제별 파일

const SET_T := 0.2
const STEP_HZ := 2.2
const BREATH_HZ := 1.1

## 손을 댄 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, SET_T, f.pose_t)

## 잎의 속도 0..1 — 팩이 적어 준 값, 없으면 1
static func v(f: Stick3D) -> float:
	return clampf(float(f.get_meta("turn_v", 1.0)), 0.0, 1.0)

## 골반이 조금 내려앉고 잰걸음에 오르내린다; 몸통은 살짝 앞으로, 걸음에 흔들리고 서면 숨에
static func lean(f: Stick3D) -> float:
	var kk := k(f); var vv := v(f)
	var ph := f._t * TAU * STEP_HZ
	f.pelvis.position.y = StickRig.HIP_Y - (0.03 + 0.015 * absf(sin(ph)) * vv) * kk
	return (0.3 + 0.03 * sin(ph * 2.0) * vv + 0.02 * sin(f._t * TAU * BREATH_HZ) * (1.0 - vv)) * kk

## 팔다리 — 오른손은 가슴 높이 손잡이에(팔꿈치 접은 채), 왼팔은 뒤로 늘어져 걸음에 흔들린다; 다리는 속도만큼 잰걸음, 서면 두 발로 선다. 고개는 도는 쪽
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "turn": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var vv := v(f)
	var ph := f._t * TAU * STEP_HZ
	var stride := s * sin(ph) * 0.26 * vv   # 앞 = 양수: 두 다리가 번갈아, 짧게
	var bend := (0.15 + 0.3 * maxf(0.0, s * sin(ph + 0.9))) * vv + 0.1 * (1.0 - vv)
	hip.rotation.x = -(stride * kk)
	knee.rotation.x = bend * kk
	if s > 0.0:   # 오른손이 손잡이에 — 어깨는 앞으로, 팔꿈치는 접어 가슴 높이
		sh.rotation.x = -(0.15 + 0.95 * kk); sh.rotation.z = -s * (0.1 + 0.05 * kk); el.rotation.x = -(0.5 + 0.5 * kk)
		f.neck.rotation.y += 0.45 * kk; f.neck.rotation.x += 0.1 * kk   # 도는 쪽을, 조금 숙여
	else:   # 왼팔은 뒤로 늘어져 걸음에 작게 흔들린다
		sh.rotation.x = -(0.15 - 0.45 * kk + 0.15 * sin(ph) * vv * kk); sh.rotation.z = -s * 0.1; el.rotation.x = -(0.5 - 0.2 * kk)
	return true
