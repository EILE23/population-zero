class_name BuskPoses
extends RefCounted
## 악사 가족 자세("Money in hands" 3조각, run 111): `strum` — 등에 멘 상자 기타를 가슴으로 돌려 친다. 0.3 기타가 등에서 가슴으로 오며 두 팔이 오른다(예비) →
## 1.6초 한 바퀴의 유지: 왼손이 목을 따라 오르내리고(한 바퀴에 한 번), 오른 손목이 2.2Hz 로 줄을 긁으며 어깨가 들썩이고, 고개는 엇박(1.1Hz, 반 박자 늦게)에 끄덕이며 오른 무릎이 박자를 밟는다 →
## meta "strum_end"(그 몸의 _t) 부터 0.4 기타를 등으로 내린다(회수). 정지화가 아니다. 사람도 악사도 같은 자세·같은 시각(town_busk).
## 기타는 가슴(chest)의 자식(meta "guitar") — sling() 이 프레임마다 등 자리와 가슴 자리 사이를 k 로 옮긴다(자세가 끊기면 town_busk 가 k 0 으로 되돌린다).
## 끄덕(meta "nod_at", run 104 의 곡선): 빈 주머니로 모자 앞에 선 사람에게 — 치던 손은 그대로, 고개만 한 번 깊이.

const STRUM_IN := 0.3     # 기타가 가슴으로 오는 시간(예비)
const STRUM_OUT := 0.4    # 등으로 내리는 시간(회수) — strum_end 부터
const LOOP_T := 1.6       # 왼손이 목을 한 번 오르내리는 한 바퀴
const HZ := 2.2           # 오른 손목
const BACK := Vector3(0.0, 0.05, -0.1)        # 가슴 좌표: 등 뒤, 비스듬히
const BACK_R := Vector3(0.0, PI, 0.55)        # y 를 돌려 앞면이 바깥, 목은 왼 어깨 위로
const FRONT := Vector3(0.03, 0.0, 0.17)       # 가슴 앞
const FRONT_R := Vector3(-0.15, 0.0, -0.35)   # 목이 왼쪽 위로

## 회수 0..1 — strum_end 가 없으면 0
static func end_k(f: Stick3D) -> float:
	return clampf((f._t - float(f.get_meta("strum_end", INF))) / STRUM_OUT, 0.0, 1.0)

## 쥔 정도 0..1 — 예비에 오르고 회수에 내린다
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, STRUM_IN, f.pose_t) * (1.0 - end_k(f))

## 오른 손목의 박자 −1..1
static func beat(f: Stick3D) -> float:
	return sin(TAU * HZ * f.pose_t)

## 왼손 — 목을 오르내리는 미끄러짐, 한 바퀴 LOOP_T
static func slide(f: Stick3D) -> float:
	return sin(TAU * f.pose_t / LOOP_T)

## 엇박의 고개 0..1 — 손목 박자의 반, 반 박자 늦게
static func offbeat(f: Stick3D) -> float:
	return maxf(0.0, sin(TAU * HZ * 0.5 * f.pose_t + PI))

static func nod_k(f: Stick3D) -> float:
	return PairPoses.nod(0.4 + f._t - float(f.get_meta("nod_at", -INF)))   # 없으면(−INF) 0

## 기타를 등과 가슴 사이에 — kk 0 은 등, 1 은 가슴. 기타가 없는 몸(meta 없음)이면 아무것도
static func sling(f: Stick3D, kk: float) -> void:
	var g: Variant = f.get_meta("guitar", null)
	if not (g is Node3D) or not is_instance_valid(g): return
	(g as Node3D).position = BACK.lerp(FRONT, kk); (g as Node3D).rotation = BACK_R.lerp(FRONT_R, kk)

static func lean(f: Stick3D) -> float:
	var kk := k(f)
	sling(f, kk)
	return 0.08 * kk + 0.02 * absf(beat(f)) * kk   # 기타 위로 조금 숙이고, 긁을 때마다 어깨가 따라간다

## 팔다리 — 오른팔은 몸 안쪽으로 접혀 손목이 줄 위를 긁고(어깨가 들썩), 왼팔은 바깥으로 벌려 목을 쥐고 손이 목을 따라 오르내린다. 오른 무릎이 박자를 밟고 고개는 엇박에 끄덕
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "strum": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var b := beat(f); var sl := slide(f)
	if s > 0.0:
		hip.rotation.x = -(0.05 * kk); knee.rotation.x = -(-(0.1 + 0.08 * maxf(0.0, b)) * kk)
		sh.rotation.x = -(0.55 * kk + 0.05 * absf(b) * kk); sh.rotation.z = -s * 0.3 * kk; el.rotation.x = -(1.35 * kk + 0.22 * b * kk)
		f.neck.rotation.x += (0.12 * offbeat(f) + 0.4 * nod_k(f)) * kk   # 엇박에 끄덕, 빈손 손님에겐 한 번 깊이(run 104 의 곡선)
	else:
		hip.rotation.x = -(-0.03 * kk); knee.rotation.x = -(-0.04 * kk)
		sh.rotation.x = -(0.75 * kk - 0.08 * sl * kk); sh.rotation.z = s * 0.5 * kk; el.rotation.x = -(1.4 * kk + 0.12 * sl * kk)
	return true
