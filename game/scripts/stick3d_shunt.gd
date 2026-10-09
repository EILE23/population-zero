class_name ShuntPoses
extends RefCounted
## 가구 밀기 가족 자세(Climb 콘텐츠 팩 bookcase, run 132 — data/climb/bookcase.json, scripts/games/climb_bookcase.gd; 운영자 보드의 '상자·가구 밀기' 가족 — 두 손을 대고 몸을 기울여 다리로 미는 몸): `shunt` 서가의 뒷면에 두 손을 대고 궤도를 따라 밀어 가는 몸 —
## 0.25 두 팔이 앞으로 뻗어 가슴 높이에 손을 대고 골반이 내려앉으며 몸통이 깊이 기운다(예비 — 발판에서 서가로 한 걸음) → 유지: 굴러가는 속도(meta "shunt_v" 0..1, 팩의 push 가 적는다, 없으면 1)만큼
## 다리가 1.4Hz 로 밀어 걷는다(앞다리 접고 뒷다리 뻗어 — 보폭은 속도에 비례), 몸통이 걸음에 작게 흔들리고, 고개는 발밑을 본다; 끝막이에 닿아 서가가 안 가면(shunt_v 0) 한 발 앞·한 발 뒤로 벌려 버티며 2Hz 로 용을 쓴다(어깨가 밀고 골반이 내려앉는다)
## → 손을 떼 로더가 자세를 비우면 stick3d 의 블렌딩이 팔을 내리고 몸을 세운다(회수). 몸이 보는 쪽이 미는 쪽(로더가 face = dir).
## heave(머리 위 줄을 당긴다)·haul(줄에 매달린다)·tread(흐르는 띠 위에 선다)와 다르다: 이건 바닥을 딛고 앞의 무거운 것을 미는 두 팔과 두 다리. stick3d_heave.gd 처럼 주제별 파일

const SET_T := 0.25
const STRIDE_HZ := 1.4
const STRAIN_HZ := 2.0

## 손을 댄 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, SET_T, f.pose_t)

## 굴러가는 속도 0..1 — 팩이 적어 준 값, 없으면 1
static func v(f: Stick3D) -> float:
	return clampf(float(f.get_meta("shunt_v", 1.0)), 0.0, 1.0)

## 끝막이에 버티며 용쓰는 정도 0..1 — 서가가 안 갈수록, 2Hz 로 오간다
static func strain(f: Stick3D) -> float:
	return (1.0 - v(f)) * (0.5 + 0.5 * sin(f._t * TAU * STRAIN_HZ))

## 골반이 내려앉고(용쓰면 더) 몸통이 깊이 앞으로 기운다 — 걸음에 작게 흔들린다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var vv := v(f); var st := strain(f)
	f.pelvis.position.y = StickRig.HIP_Y - (0.07 + 0.02 * st) * kk
	return (0.55 + 0.06 * st + 0.03 * sin(f._t * TAU * STRIDE_HZ * 2.0) * vv) * kk

## 팔다리 — 두 팔은 앞으로 뻗어 가슴 높이의 서가에(팔꿈치는 거의 펴고, 용쓰면 어깨가 더 민다), 다리는 속도만큼 밀어 걷고 멈추면 한 발 앞·한 발 뒤로 벌려 버틴다. 고개는 발밑
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "shunt": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var vv := v(f); var st := strain(f)
	var ph := f._t * TAU * STRIDE_HZ
	var stride := s * sin(ph) * 0.38 * vv   # 앞 = 양수: 두 다리가 번갈아
	var split := (0.22 if s > 0.0 else -0.42) * (1.0 - vv)   # 멈춘 채 버틸 땐 오른다리 앞·왼다리 뒤
	var bend := (0.25 + 0.3 * maxf(0.0, s * sin(ph + 0.9))) * vv + ((0.55 if s > 0.0 else 0.1) + 0.05 * st) * (1.0 - vv)
	hip.rotation.x = -((stride + split) * kk)
	knee.rotation.x = bend * kk
	sh.rotation.x = -(0.15 + (0.85 + 0.12 * st) * kk); sh.rotation.z = -s * (0.1 - 0.04 * kk); el.rotation.x = -(0.5 - 0.38 * kk)   # 두 팔이 앞으로 나란히
	if s > 0.0: f.neck.rotation.x += 0.6 * kk   # 기운 몸이 머리를 0.7·lean 만큼 되돌리니 그보다 더 — 발밑을 본다
	return true
