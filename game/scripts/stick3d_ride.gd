class_name RidePoses
extends RefCounted
## 풍차 날 가족 자세(Climb 콘텐츠 팩 windmill, run 122 — data/climb/windmill.json, scripts/games/climb_windmill.gd; 운영자 보드의 '스케이트·서핑' 가족 — 움직이는 바닥 위에 선 몸): `ride` 돌아가는 바퀴의 컵에 선 몸 —
## 0.2 두 발이 앞뒤로 벌어지고 무릎이 내려앉고 두 팔이 옆으로 나간다(예비) → 유지: 컵의 속도(meta "ride_k" 가로 −1..1, +면 +x 로 간다; "ride_v" 세로, +면 오른다 — 팩의 ride 가 적는다, 없으면 5초 주기의 제 박자)를 거슬러
## 몸통이 가는 방향의 반대로 기울고(버스에 선 사람처럼) 팔은 앞으로 나와 균형을 잡는다, 오를 땐 눌려 무릎이 더 접히고 팔이 내려가며 내릴 땐 가벼워져 무릎이 펴지고 팔이 뜬다 — 바퀴가 도는 동안 몸은 한 모양으로 서 있지 않는다; 걸으면 좁은 조심 걸음(0.45초), 고개는 발밑
## → 컵에서 뛰거나 걸어 내려서면 로더가 자세를 비우고 stick3d 의 블렌딩이 팔을 내리고 무릎을 편다(회수). 몸이 보는 쪽(f._yaw)으로 '앞'을 읽는다.
## sway(흔들리는 바닥 — 골반째 좌우로 기운다)·glide(바람에 뜬 몸)와 다르다: 이건 원을 그리며 실려 가는 몸. stick3d_sway.gd 처럼 주제별 파일

const BRACE_T := 0.2
const STEP_T := 0.45
const PERIOD := 5.0

## 벌어진 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, BRACE_T, f.pose_t)

## 몸 앞쪽으로 가는 정도 −1..1 — 세상 x 의 속도(meta)를 보는 방향(yaw, +x 를 보면 sin 이 +)으로 뒤집는다
static func fwd(f: Stick3D) -> float:
	var raw := clampf(float(f.get_meta("ride_k", sin(f._t * TAU / PERIOD))), -1.0, 1.0)
	return raw * (1.0 if sin(f._yaw) >= 0.0 else -1.0)

## 오르는 정도 −1..1
static func rise(f: Stick3D) -> float:
	return clampf(float(f.get_meta("ride_v", cos(f._t * TAU / PERIOD))), -1.0, 1.0)

static func moving(f: Stick3D) -> bool:
	return f.speed > 0.05 and f.move_dir.length_squared() > 0.0001 and not f.airborne and not f.seated

## 무릎이 내려앉고(오를 땐 더), 몸통은 가는 방향의 반대로 기운다
static func lean(f: Stick3D) -> float:
	var kk := k(f)
	f.pelvis.position.y = StickRig.HIP_Y - (0.06 + 0.04 * rise(f)) * kk
	return (-0.3 * fwd(f) + 0.02 * sin(f._t * 3.0)) * kk

## 팔다리 — 오른다리(s +) 앞·왼다리 뒤의 벌린 자세, 무릎은 오를수록 접힌다; 두 팔은 옆으로 벌리고(내릴수록 뜬다) 가는 쪽으로 나와 균형을 잡는다; 걸으면 좁은 조심 걸음. 고개는 발밑
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "ride": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var fw := fwd(f); var rs := rise(f)
	if moving(f):
		var a := sin(f._t * TAU / (STEP_T * 2.0)) * s * 0.3   # 좁은 보폭 — 컵 하나 안의 조심 걸음
		hip.rotation.x = -(a + 0.1 * kk); knee.rotation.x = -(-(0.5 if a < 0.0 else 0.3) - 0.15 * kk)
	else:
		hip.rotation.x = -((0.3 if s > 0.0 else -0.25) * kk); knee.rotation.x = -(-(0.35 + 0.25 * rs) * kk)
	sh.rotation.x = -((0.15 + 0.3 * fw) * kk); sh.rotation.z = -s * (0.1 + (0.7 - 0.3 * rs) * kk); el.rotation.x = -(0.35 - 0.1 * kk)
	if s > 0.0: f.neck.rotation.x += 0.2 * kk
	return true
