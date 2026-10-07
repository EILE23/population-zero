class_name LurchPoses
extends RefCounted
## 유령 발판 가족 자세(Climb 콘텐츠 팩 ghost, run 120 — data/climb/ghost.json, scripts/games/climb_ghost.gd): `lurch` 발밑이 사라진 몸 —
## 0.12 놀람: 두 팔이 위로 튀어 오르고 무릎이 가슴 쪽으로 꺾이며 고개가 뒤로(예비) → 0.25 에 걸쳐 허우적거림으로 풀린다: 두 팔이 반 바퀴 어긋나 풍차처럼 돌고(18rad/s) 다리가 번갈아 차며(9rad/s) 몸은 뒤로 젖혀진다(유지)
## → 착지(f.airborne 이 false 가 된 순간)부터 0.3 무릎이 깊이 받쳤다 서고 팔은 앞으로 균형을 잡는다(회수). 공중 기본 자세(뛴 몸)나 bounce(던져진 몸)와 다르다: 이건 발판이 먼저 떠난 몸.
## 착지 시각은 자세가 바뀌지 않아 pose_t 가 이어지므로 meta "lurch_land" 에 적는다(공중을 한 번은 본 뒤에만 — 로더가 자세와 airborne 을 같은 틱에 주지 않아도 첫 프레임에 착지로 읽지 않게); 로더는 done(f) 가 true 가 되면 pose_request 를 비운다. stick3d_bounce.gd 처럼 주제별 파일

const STARTLE_T := 0.12
const FLAIL_T := 0.25
const LAND_T := 0.3

## 착지 시각(pose_t 기준) — 아직 공중이면 -1. 자세의 첫 프레임엔 지운다; 공중을 본 적이 있어야 착지로 센다
static func _land(f: Stick3D) -> float:
	if f.pose_t == 0.0: f.set_meta("lurch_land", -1.0); f.set_meta("lurch_air", false)
	var land := float(f.get_meta("lurch_land", -1.0)); var air := bool(f.get_meta("lurch_air", false))
	if f.airborne and not air: air = true; f.set_meta("lurch_air", true)
	if land < 0.0 and air and not f.airborne: land = f.pose_t; f.set_meta("lurch_land", land)
	return land

## [startle, flail, brace, air] 0..1 — 놀람은 STARTLE_T 에 다 서고 FLAIL_T 에 걸쳐 허우적거림이 그 자리를 받는다; 착지 뒤 0.1 에 공중 몫이 꺼지고 LAND_T 동안 무릎이 한 번 깊이 굽었다 편다
static func phases(f: Stick3D) -> Array:
	var land := _land(f)
	var st := smoothstep(0.0, STARTLE_T, f.pose_t)
	var fl := smoothstep(STARTLE_T, STARTLE_T + FLAIL_T, f.pose_t)
	var g := 0.0 if land < 0.0 else smoothstep(0.0, 0.1, f.pose_t - land)
	var b := 0.0 if land < 0.0 else sin(clampf((f.pose_t - land) / LAND_T, 0.0, 1.0) * PI)
	return [st, fl, b, 1.0 - g]

## 회수가 끝났나 — 로더가 pose_request 를 비울 때
static func done(f: Stick3D) -> bool:
	var land := float(f.get_meta("lurch_land", -1.0))
	return land >= 0.0 and f.pose_t - land >= LAND_T

static func lean(f: Stick3D) -> float:
	var p := phases(f); var st := float(p[0]); var fl := float(p[1]); var b := float(p[2]); var air := float(p[3])
	f.pelvis.position.y = StickRig.HIP_Y - 0.3 * b
	return (-0.15 * st * (1.0 - fl) - 0.25 * fl) * air + 0.3 * b   # 놀라 조금 젖혀지고, 허우적거리며 더 젖혀지고, 착지에 숙인다

## 팔다리 — 놀람: 두 팔이 위로, 무릎이 가슴 쪽으로; 허우적거림: 팔이 풍차처럼 어긋나 돌고 다리가 번갈아 찬다; 착지: 무릎이 깊이 받치고 팔이 앞으로 균형을 잡는다. 고개는 놀라 젖히고 착지에 숙인다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "lurch": return false
	var hip_n: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var p := phases(f); var st := float(p[0]); var fl := float(p[1]); var b := float(p[2]); var air := float(p[3])
	var wm := sin(f._t * 18.0 + s * PI)   # 풍차 — 양팔이 반 바퀴 어긋난다
	var kick := sin(f._t * 9.0 + s * PI)   # 다리는 번갈아
	var snap := st * (1.0 - fl)
	hip_n.rotation.x = -((1.2 * snap + (0.6 + 0.5 * kick) * fl) * air + 0.9 * b)
	knee.rotation.x = -((-1.4 * snap + (-0.8 - 0.4 * kick) * fl) * air - 1.6 * b)
	sh.rotation.x = -((2.6 * snap + (2.6 - 0.6 * wm) * fl) * air + 1.0 * b)
	sh.rotation.z = -s * ((0.5 * snap + (0.35 + 0.25 * wm) * fl) * air + 0.25 * b)
	el.rotation.x = -((0.2 * snap + (0.4 + 0.3 * wm) * fl) * air + 0.5 * b)
	if s > 0.0: f.neck.rotation.x += (-0.35 * snap - 0.3 * fl) * air + 0.2 * b
	return true
