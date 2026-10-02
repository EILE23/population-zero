class_name DockPoses
extends RefCounted
## 나루 가족 자세(운영자 보드의 '배 매기' — run 94, 남쪽 나루): `moor` 배에서 내려 부두 말뚝 앞에 반쯤 쪼그려 앉아, 오른손이 밧줄을 말뚝에 두 번 감고, 두 손으로 당겨 조인 뒤 선다.
## 왼손은 감는 동안 밧줄 끝을 가슴 앞에 쥐고 있다. stick3d_hearth.gd 처럼 주제별 파일. 밧줄(town_boat _rope)은 MOOR_TIGHT 에 매인다

const MOOR_T := 1.5      # 0.3 쪼그려 앉으며 두 손이 말뚝으로(예비) → 0.9 오른손이 두 바퀴 감는다(유지) → 0.3 두 손으로 당겨 조이고 일어선다(회수)
const MOOR_TIGHT := 1.3  # 당겨 조인 순간 — 밧줄이 보인다(그 전에 누가 배에 타면 안 매인다)
const DOWN_Y := 0.3      # 반쯤 쪼그린 골반 높이(HIP_Y 0.42 → 0.3)

## 쪼그린 정도 0..1 — 들어갈 때 0.3초, 당긴 뒤 0.15초에 걸쳐 선다
static func crouch(t: float) -> float:
	return smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(1.35, MOOR_T, t))

## 감기 각도(rad) — 0.3..1.2 동안 두 바퀴. 그 밖엔 멈춰 있다
static func wind(t: float) -> float:
	return clampf((t - 0.3) / 0.9, 0.0, 1.0) * TAU * 2.0

## 당겨 조이는 정도 0..1 — 감기가 끝난 뒤 0.1초에 당기고, 서면서 놓는다
static func pull(t: float) -> float:
	return smoothstep(1.2, 1.3, t) * (1.0 - smoothstep(1.4, MOOR_T, t))

static func lean(f: Stick3D) -> float:
	var c := crouch(f.pose_t)
	f.pelvis.position.y = lerpf(StickRig.HIP_Y, DOWN_Y, c)
	return 0.38 * c - 0.2 * pull(f.pose_t)   # 말뚝 쪽으로 숙였다가, 당길 때 뒤꿈치로 몸을 젖힌다

## 팔다리 — 두 무릎이 접히고(왼 무릎이 조금 낮다), 오른손은 말뚝 둘레로 원을 그리고(어깨 앞뒤·옆, 팔꿈치가 같이 오므렸다 편다), 왼손은 밧줄 끝을 가슴 앞에. 당길 땐 두 팔이 함께 몸 쪽으로
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "moor": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t := f.pose_t; var c := crouch(t); var a := wind(t); var p := pull(t)
	var reach := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(1.35, MOOR_T, t))
	hip.rotation.x = -((0.65 if s > 0.0 else 0.85) * c); knee.rotation.x = (1.15 if s > 0.0 else 1.45) * c
	if s > 0.0:
		var w := 1.0 if t > 0.3 and t < 1.2 else 0.0
		sh.rotation.x = -(reach * (0.95 - 0.55 * p) + w * 0.3 * sin(a)); sh.rotation.z = -(0.12 + w * 0.22 * cos(a))
		el.rotation.x = -(0.35 + w * 0.35 * (0.5 + 0.5 * cos(a)) + 1.0 * p)   # 당길 땐 팔꿈치를 접어 몸으로 끌어온다
		f.neck.rotation.x += 0.25 * c   # 손끝(말뚝)을 본다
	else:
		sh.rotation.x = -(reach * (0.7 - 0.4 * p)); sh.rotation.z = 0.08; el.rotation.x = -(0.9 + 0.6 * p)   # 밧줄 끝을 쥐고 — 당길 때 같이 끌어온다
	return true
