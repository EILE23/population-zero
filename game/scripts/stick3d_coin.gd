class_name CoinPoses
extends RefCounted
## 동전 가족 자세("Money in hands" — 마을이 설계한 스무째 시스템, 1조각 run 107): `stoop` 바닥의 동전을 집어 주머니에 넣는다 —
## 0.3 무릎을 굽히며 허리를 깊이 숙이고 오른팔이 바닥으로(예비) → 0.12 손끝이 동전 위에 머물며 쥔다(유지, 고개가 손을 본다) → 0.48 일어서며 오른손이 허리 주머니로 돌아가 톡 친다(회수).
## grab(물건 집기)과 다르다: grab 은 선 채 팔만 뻗어 손에 든다; stoop 은 숙여 쥐고 손에 남기지 않는다 — 동전은 손이 아니라 주머니로 간다(town_coins).
## STOOP_IN 에 동전이 바닥에서 손으로, STOOP_AWAY 에 손에서 주머니로 사라진다. 사람도 주민도 같은 자세·같은 시각. stick3d_shelf.gd 처럼 주제별 파일
## `palm`(2조각 run 110): 창구 상판의 동전을 손바닥으로 쓸어 쥐고 주머니에 — 0.3 오른손이 허리 높이로 뻗어 상판을 따라 옆으로 미끄러진다(예비) → 0.1 손가락이 오므려지며 고개가 어깨 너머를 돌아본다(유지 —
## 남의 것인지 제 것인지는 보는 이가 안다) → 0.4 손이 허리 주머니로 돌아가 톡(회수). stoop 과 다르다: 바닥이 아니라 상판, 무릎은 안 굽고 몸만 조금 기운다. 도둑도 주인도 같은 자세 — 빵집 주인이 17시에 수입을 거둘 때도 이것
## `put`(7조각 run 116, 전당포 — town_pawn.gd): 주머니의 동전을 꺼내 상판의 접시에 놓는다 — palm 의 반대 방향이지만 제 시계가 있다: 0.22 오른손이 허리 뒤 주머니로 가 더듬고(예비) → 0.08 쥔 채 멈춤(유지, PUT_IN 에 동전이 손에)
## → 0.3 팔이 허리 높이로 앞으로 뻗어 상판에 놓고(PUT_AWAY 에 동전이 접시로, 고개가 접시를 본다) → 0.2 거둔다(회수). 동전마다 한 번(town_pawn pay_out 이 시계를 되감는다 — palm_till 의 사슬과 같다). 사람도 주민도 같은 자세

const STOOP_T := 0.9
const STOOP_IN := 0.42    # 손이 동전을 쥔 순간 — 동전이 바닥에서 손으로(town_coins)
const STOOP_AWAY := 0.74  # 손이 주머니에 닿은 순간 — 동전이 손에서 사라지고 주머니 수가 는다
const PALM_T := 0.8
const PALM_IN := 0.34     # 손가락이 상판의 동전을 쥔 순간 — 접시에서 손으로(town_coins)
const PALM_AWAY := 0.62   # 주머니에 닿은 순간
const PUT_T := 0.8
const PUT_IN := 0.26      # 주머니에서 손으로(town_pawn)
const PUT_AWAY := 0.6     # 손에서 접시로

## 숙인 정도 0..1 — 0.3 에 다 숙이고 0.5 부터 0.78 까지 일어선다
static func bend(t: float) -> float:
	return smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.5, 0.78, t))

## 주머니로 가는 손 0..1 — 일어서며 허리 뒤로 돌아가 STOOP_AWAY 에 닿고 끝에 늘어진다
static func hip(t: float) -> float:
	return smoothstep(0.5, STOOP_AWAY, t) * (1.0 - smoothstep(STOOP_AWAY + 0.08, STOOP_T, t))

## 톡 0..1 — 주머니에 닿은 뒤 0.08초 한 번
static func tap(t: float) -> float:
	return absf(sin((t - STOOP_AWAY) / 0.08 * PI)) if t >= STOOP_AWAY and t < STOOP_AWAY + 0.08 else 0.0

## 뻗은 정도 0..1 — 0.3 에 상판에 닿고 0.4 부터 거둔다
static func reach(t: float) -> float:
	return smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.4, 0.6, t))

## 어깨 너머 돌아보는 고개 0..1 — 쥐는 동안만
static func glance(t: float) -> float:
	return smoothstep(0.26, 0.36, t) * (1.0 - smoothstep(0.5, PALM_AWAY, t))

## put — 주머니로 가는 손 0..1(0.22 에 닿아 0.3 까지 더듬는다)
static func pocket(t: float) -> float:
	return smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.3, 0.45, t))

## put — 상판으로 뻗는 손 0..1(PUT_AWAY 에 닿고 끝에 거둔다)
static func put_reach(t: float) -> float:
	return smoothstep(0.36, PUT_AWAY, t) * (1.0 - smoothstep(PUT_AWAY + 0.06, PUT_T, t))

static func lean(f: Stick3D) -> float:
	if f.pose_request == "palm": return 0.22 * reach(minf(f.pose_t, PALM_T))   # 상판 쪽으로 조금만 — 무릎은 그대로
	if f.pose_request == "put": return 0.2 * put_reach(minf(f.pose_t, PUT_T))   # 놓을 때만 상판 쪽으로
	var b := bend(minf(f.pose_t, STOOP_T))
	f.pelvis.position.y = StickRig.HIP_Y - 0.16 * b   # 무릎이 굽으며 골반이 내려간다
	return 0.95 * b   # 상체가 깊이 숙는다 — 팔만으로는 바닥이 안 닿는다

## 팔다리 — 다리는 무릎이 굽고(오른발이 더), 오른팔은 숙인 몸에서 바닥까지 곧게 뻗다가 일어서며 뒤로 돌아 허리 주머니에(팔꿈치 접힘), 왼팔은 균형으로 뒤로 조금
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request == "palm": return palm_limbs(f, s)
	if f.pose_request == "put": return put_limbs(f, s)
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

## palm 의 팔다리 — 무게가 오른발로 조금, 오른팔은 허리 높이로 뻗어 상판을 따라 안쪽으로 미끄러지고(어깨 z) 쥔 뒤 주머니로(팔꿈치 접힘), 고개는 쥐는 동안 어깨 너머를 본다. 왼팔은 늘어진 채 균형
static func palm_limbs(f: Stick3D, s: float) -> bool:
	var hip_n: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t := minf(f.pose_t, PALM_T); var rc := reach(t); var g := glance(t)
	var h := smoothstep(0.42, PALM_AWAY, t) * (1.0 - smoothstep(PALM_AWAY + 0.08, PALM_T, t))
	var tp := absf(sin((t - PALM_AWAY) / 0.08 * PI)) if t >= PALM_AWAY and t < PALM_AWAY + 0.08 else 0.0
	hip_n.rotation.x = -((0.06 if s > 0.0 else -0.03) * rc); knee.rotation.x = -((-0.08 if s > 0.0 else 0.0) * rc)
	if s > 0.0:
		sh.rotation.x = -(1.3 * rc - 0.55 * h); sh.rotation.z = -s * 0.3 * smoothstep(0.12, 0.3, t) * rc + s * 0.2 * h   # 뻗은 팔이 상판을 따라 안쪽으로
		el.rotation.x = -(0.25 * rc + 0.2 * smoothstep(0.28, PALM_IN, t) * rc + 1.1 * h + 0.15 * tp)   # 쥘 때 손목이 감기고, 주머니에선 팔꿈치가 접힌다
		f.neck.rotation.y += 0.6 * g; f.neck.rotation.x += 0.15 * rc - 0.1 * g   # 동전을 보다가 어깨 너머로
	else:
		sh.rotation.x = -(0.05 - 0.15 * rc); sh.rotation.z = s * 0.08 * rc; el.rotation.x = -(0.3 + 0.1 * rc)
	return true

## put 의 팔다리 — 오른팔이 뒤로 돌아 허리 주머니를 더듬고(팔꿈치 접힘), 앞으로 뻗어 상판에 놓는다(팔꿈치 펴짐); 고개는 주머니를 더듬을 땐 살짝 숙이고 놓을 땐 접시를 본다. 무게는 놓을 때 오른발로 조금, 왼팔은 늘어진 채 균형
static func put_limbs(f: Stick3D, s: float) -> bool:
	var hip_n: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t := minf(f.pose_t, PUT_T); var pk := pocket(t); var rc := put_reach(t)
	hip_n.rotation.x = -((0.05 if s > 0.0 else -0.03) * rc); knee.rotation.x = -((-0.06 if s > 0.0 else 0.0) * rc)
	if s > 0.0:
		sh.rotation.x = -(-0.55 * pk + 1.25 * rc); sh.rotation.z = s * 0.2 * pk - s * 0.25 * rc   # 뒤로 돌아 주머니, 앞으로 뻗어 상판
		el.rotation.x = -(1.1 * pk + 0.3 * rc + 0.2 * smoothstep(0.5, PUT_AWAY, t) * rc)   # 주머니에선 접히고, 놓을 땐 손목이 조금 감긴다
		f.neck.rotation.x += 0.14 * rc - 0.08 * pk
	else:
		sh.rotation.x = -(0.05 - 0.12 * rc); sh.rotation.z = s * 0.08 * rc; el.rotation.x = -(0.3 + 0.1 * rc)
	return true
