class_name HearthPoses
extends RefCounted
## 불 가족 자세(운영자 보드의 '불 피우기' — run 92, 숲 오두막 무쇠 난로): `stoke` 쪼그려 앉아 왼손으로 난로 문을 열고, 오른손의 장작을 밀어 넣고, 닫고 일어선다.
## stick3d_poses.gd 가 450줄 근처라 주제별로 뗐다(stick3d_fish.gd 처럼). StickPoses.lean/limbs 가 이리로 넘긴다. 난로 문은 town_woods `_stove` 가 같은 door_k 로 돌린다

const STOKE_T := 1.2    # 0.3 쪼그려 앉으며 왼손이 문으로(예비) → 0.6 문을 열어 둔 채 장작을 밀어 넣는다(유지) → 0.3 문을 닫고 일어선다(회수)
const STOKE_IN := 0.75  # 장작이 손을 떠나 화실에 들어가는 순간(town_woods _stoked) — 이 전에 움직이면 장작은 손에 남는다
const DOWN_Y := 0.32    # 쪼그린 골반 높이

## 쪼그린 정도 0..1 — 들어갈 때 0.3초, 문을 닫은 뒤 0.2초에 걸쳐 선다
static func crouch(t: float) -> float:
	return smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(1.0, 1.2, t))

## 난로 문이 열린 정도 0..1 — 손이 닿은 뒤 열고, 장작이 들어간 뒤 닫는다
static func door_k(t: float) -> float:
	return smoothstep(0.15, 0.35, t) * (1.0 - smoothstep(0.85, 1.05, t))

## 오른손이 앞으로 밀어 넣은 정도 0..1
static func push(t: float) -> float:
	return smoothstep(0.35, STOKE_IN, t) * (1.0 - smoothstep(0.8, 1.0, t))

static func lean(f: Stick3D) -> float:
	var c := crouch(f.pose_t)
	f.pelvis.position.y = lerpf(StickRig.HIP_Y, DOWN_Y, c)
	return 0.3 * c + 0.12 * push(f.pose_t)   # 쪼그리며 숙이고, 밀어 넣을 때 어깨가 조금 더 따라 들어간다

## 팔다리 — 두 무릎이 접히고(오른 무릎이 조금 낮다), 왼팔은 문고리로 뻗었다가 옆으로 끌어 연다, 오른팔은 가슴 앞의 장작을 화실로 쭉 민다. 고개는 불을 본다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "stoke": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t := f.pose_t; var c := crouch(t); var o := door_k(t); var p := push(t)
	hip.rotation.x = -((0.95 if s > 0.0 else 0.75) * c); knee.rotation.x = -(-(1.7 if s > 0.0 else 1.35) * c)
	if s > 0.0:
		sh.rotation.x = -(0.5 + 0.6 * p); sh.rotation.z = -0.1; el.rotation.x = -(1.2 - 1.05 * p)   # 장작을 가슴에 안았다가 팔을 펴며 민다
		f.neck.rotation.x += 0.2 * c
	else:
		sh.rotation.x = -(0.15 + 0.6 * smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(1.0, 1.2, t))); sh.rotation.z = -s * (0.1 + 0.55 * o); el.rotation.x = -(0.3 + 0.2 * o)   # 문고리를 잡고 바깥으로 끌어 연다
	return true
