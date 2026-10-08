class_name DanglePoses
extends RefCounted
## 추 가족 자세(Climb 콘텐츠 팩 pendulum, run 125 — data/climb/pendulum.json, scripts/games/climb_pendulum.gd; 운영자 보드의 '매달리기·철봉' 가족 — 손으로 매달려 실려 가는 몸): `dangle` 흔들리는 가로대에 매달린 몸 —
## 0.2 두 팔이 머리 위로 뻗어 가로대를 잡고 다리가 아래로 늘어지며 골반이 조금 오른다(예비) → 유지: 가로대의 속도(meta "dangle_v" −1..1, +면 +x 로 간다; 팩의 hang_on 이 적는다, 없으면 2.4초 주기의 제 박자)를 보는 쪽으로 뒤집어
## 몸통이 가는 쪽으로 기울고(발이 뒤처진다 — 줄에 매달린 몸처럼), 앞으로 갈 땐 두 다리를 앞으로 차고 돌아올 땐 무릎을 접는다(그네의 펌프질), 양 끝(속도 0)에선 곧게 매달려 멈춘 한순간; 팔꿈치는 잡은 뒤 거의 펴진다, 고개는 건너편 턱을 본다
## → 뛰거나 놓아 로더가 자세를 비우면 stick3d 의 블렌딩이 팔을 내리고 무릎을 편다(회수). 몸이 보는 쪽(f._yaw)으로 '앞'을 읽는다.
## ride(컵에 선 몸)·glide(바람에 뜬 몸)·climb(홀드에 붙은 몸, stick3d.gd 의 move "climb")과 다르다: 이건 손 둘로 매달려 호를 그리는 몸. stick3d_ride.gd 처럼 주제별 파일

const GRAB_T := 0.2
const PERIOD := 2.4

## 잡은 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, GRAB_T, f.pose_t)

## 몸 앞쪽으로 가는 정도 −1..1 — 세상 x 의 속도(meta)를 보는 방향(yaw, +x 를 보면 sin 이 +)으로 뒤집는다
static func fwd(f: Stick3D) -> float:
	var raw := clampf(float(f.get_meta("dangle_v", cos(f._t * TAU / PERIOD))), -1.0, 1.0)
	return raw * (1.0 if sin(f._yaw) >= 0.0 else -1.0)

## 골반이 조금 오르고(늘어진 몸), 몸통은 가는 쪽으로 기운다 — 발이 뒤처진다
static func lean(f: Stick3D) -> float:
	var kk := k(f)
	f.pelvis.position.y = StickRig.HIP_Y + 0.03 * kk
	return (0.35 * fwd(f) + 0.03 * sin(f._t * 2.0)) * kk

## 팔다리 — 두 팔은 머리 위로 뻗어 가로대를(팔꿈치는 잡은 뒤 펴진다), 두 다리는 앞으로 갈수록 앞으로 차고 돌아올수록 접는다(펌프질, 한 짝이 아주 조금 앞), 고개는 건너편을
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "dangle": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var fw := fwd(f)
	hip.rotation.x = -((0.1 + 0.3 * fw + 0.04 * s) * kk)
	knee.rotation.x = -(-(0.35 - 0.25 * fw) * kk)
	sh.rotation.x = -(0.1 + 2.8 * kk); sh.rotation.z = -s * (0.1 + 0.1 * kk); el.rotation.x = -(0.5 - 0.35 * kk)
	if s > 0.0: f.neck.rotation.x -= (0.25 - 0.15 * absf(fw)) * kk
	return true
