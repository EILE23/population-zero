class_name CoinPoses
extends RefCounted
## 동전 가족 자세("Money in hands" — 마을이 설계한 스무째 시스템, 1조각 run 107): `stoop` 바닥의 동전을 집어 주머니에 넣는다 —
## 0.3 무릎을 굽히며 허리를 깊이 숙이고 오른팔이 바닥으로(예비) → 0.12 손끝이 동전 위에 머물며 쥔다(유지, 고개가 손을 본다) → 0.48 일어서며 오른손이 허리 주머니로 돌아가 톡 친다(회수).
## grab(물건 집기)과 다르다: grab 은 선 채 팔만 뻗어 손에 든다; stoop 은 숙여 쥐고 손에 남기지 않는다 — 동전은 손이 아니라 주머니로 간다(town_coins).
## STOOP_IN 에 동전이 바닥에서 손으로, STOOP_AWAY 에 손에서 주머니로 사라진다. 사람도 주민도 같은 자세·같은 시각. stick3d_shelf.gd 처럼 주제별 파일

const STOOP_T := 0.9
const STOOP_IN := 0.42    # 손이 동전을 쥔 순간 — 동전이 바닥에서 손으로(town_coins)
const STOOP_AWAY := 0.74  # 손이 주머니에 닿은 순간 — 동전이 손에서 사라지고 주머니 수가 는다

## 숙인 정도 0..1 — 0.3 에 다 숙이고 0.5 부터 0.78 까지 일어선다
static func bend(t: float) -> float:
	return smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.5, 0.78, t))

## 주머니로 가는 손 0..1 — 일어서며 허리 뒤로 돌아가 STOOP_AWAY 에 닿고 끝에 늘어진다
static func hip(t: float) -> float:
	return smoothstep(0.5, STOOP_AWAY, t) * (1.0 - smoothstep(STOOP_AWAY + 0.08, STOOP_T, t))

## 톡 0..1 — 주머니에 닿은 뒤 0.08초 한 번
static func tap(t: float) -> float:
	return absf(sin((t - STOOP_AWAY) / 0.08 * PI)) if t >= STOOP_AWAY and t < STOOP_AWAY + 0.08 else 0.0

static func lean(f: Stick3D) -> float:
	var b := bend(minf(f.pose_t, STOOP_T))
	f.pelvis.position.y = StickRig.HIP_Y - 0.16 * b   # 무릎이 굽으며 골반이 내려간다
	return 0.95 * b   # 상체가 깊이 숙는다 — 팔만으로는 바닥이 안 닿는다

## 팔다리 — 다리는 무릎이 굽고(오른발이 더), 오른팔은 숙인 몸에서 바닥까지 곧게 뻗다가 일어서며 뒤로 돌아 허리 주머니에(팔꿈치 접힘), 왼팔은 균형으로 뒤로 조금
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "stoop": return false
	var hip_n: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t := minf(f.pose_t, STOOP_T); var b := bend(t); var h := hip(t); var tp := tap(t)
	hip_n.rotation.x = -((0.55 if s > 0.0 else 0.42) * b); knee.rotation.x = -(-(0.95 if s > 0.0 else 0.8) * b)   # 좌우가 같지 않게
	if s > 0.0:
		sh.rotation.x = -(0.9 * b - 0.5 * h); sh.rotation.z = -s * 0.08 * b + s * 0.2 * h
		el.rotation.x = -(0.05 + 0.1 * smoothstep(0.3, STOOP_IN, t) * b + 1.1 * h + 0.15 * tp)   # 쥘 때 손목이 살짝 감기고, 주머니에선 팔꿈치가 접힌다
		f.neck.rotation.x += 0.35 * b - 0.1 * h   # 손끝(동전)을 본다, 주머니에 넣을 땐 고개를 든다
	else:
		sh.rotation.x = -(0.05 - 0.4 * b); sh.rotation.z = s * 0.12 * b; el.rotation.x = -(0.3 + 0.15 * b)
	return true
