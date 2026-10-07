class_name FurnishPoses
extends RefCounted
## 가구 가족 자세(money 4, run 117 — 내 집 꾸미기, town_furnish.gd): `plonk` 두 손에 든 납작 상자(flatpack)를 바닥에 내려놓는다 —
## 0.3 무릎이 굽고 허리가 숙으며 두 팔이 앞·아래로 뻗어 상자를 바닥으로(예비) → 0.08 손이 상자 위에 머문다(유지 — PLONK_DOWN 에 손의 것이 바닥의 진짜 가구가 된다)
## → 0.52 일어서며 가슴 앞에서 두 손을 두 번 털고 팔이 내려온다(회수). stoop(한 손, 동전은 주머니로)과 다르다: 두 손이 같이 내려가고 손엔 아무것도 남지 않는다;
## 내려놓기(release)의 grab 과도 다르다: grab 은 선 채 팔만 뻗는다. 사람도 주민도 같은 자세·같은 시각(town_furnish, resident_furnish). stick3d_wear.gd 처럼 주제별 파일

const PLONK_T := 0.9
const PLONK_DOWN := 0.38   # 손의 상자가 바닥의 가구가 되는 순간(town_furnish.furnish_place, resident_furnish)

## 숙인 정도 0..1 — 0.3 에 다 숙이고 0.42 부터 0.72 까지 일어선다
static func bend(t: float) -> float:
	return smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.42, 0.72, t))

## 일어서며 가슴 앞에 모이는 손 0..1
static func gather(t: float) -> float:
	return smoothstep(0.42, 0.72, t) * (1.0 - smoothstep(0.8, PLONK_T, t))

## 손 털기 0..1 — 0.6~0.8 사이 두 번
static func dust(t: float) -> float:
	return absf(sin((t - 0.6) / 0.2 * TAU)) if t >= 0.6 and t < 0.8 else 0.0

static func lean(f: Stick3D) -> float:
	var b := bend(minf(f.pose_t, PLONK_T))
	f.pelvis.position.y = StickRig.HIP_Y - 0.2 * b   # 무릎이 굽으며 골반이 내려간다
	return 0.7 * b

## 팔다리 — 두 다리의 무릎이 굽고(왼발이 조금 더), 두 어깨가 앞·아래로 뻗어 상자를 바닥에, 일어서며 팔꿈치가 접혀 가슴 앞에서 손을 턴다; 고개는 상자를 보다가 든다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "plonk": return false
	var hip_n: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t := minf(f.pose_t, PLONK_T); var b := bend(t); var g := gather(t); var d := dust(t)
	hip_n.rotation.x = -((0.5 if s > 0.0 else 0.6) * b); knee.rotation.x = -(-(0.9 if s > 0.0 else 1.0) * b)
	sh.rotation.x = -(0.1 + 0.95 * b + 0.6 * g + 0.1 * d); sh.rotation.z = -s * (0.12 * b + 0.08 * g)
	el.rotation.x = -(0.05 + 0.15 * b + 1.2 * g + 0.3 * d)
	if s > 0.0: f.neck.rotation.x += 0.3 * b - 0.05 * g
	return true
