class_name YankPoses
extends RefCounted
## 카드 목록함 가족 자세(Climb 콘텐츠 팩 catalogue, run 151 — data/climb/catalogue.json, scripts/games/climb_catalogue.gd; 운영자 보드의 '서랍·문 당기기' 가족 — 제 옆의 것을 두 손으로 홱 당기는 몸): `yank` 절벽에 박힌 서랍을 가슴으로 당겨 빼는 몸 —
## 뻗기(0..0.12): 두 팔이 절벽 쪽 어깨 높이로 뻗어 서랍 손잡이에 간다(먼 팔은 가슴을 가로질러), 몸통이 그쪽으로 조금 기울고 고개가 손잡이를 본다(예비)
## → 당김(0.12..0.42): 팔꿈치가 깊이 접혀 두 손이 가슴으로 오고 어깨가 돌아오며, 무게가 뒤발(절벽 반대쪽 다리)로 떨어진다 — 그 무릎이 더 깊이 접히고 골반이 내려앉고 몸통이 뒤로 젖혀지며 가슴이 열린다
## → 놓기(0.42..0.57): 손이 열려 떨어지고 뒤발이 절벽 반대로 반걸음 벌려 선다(허벅지 벌림 — 서랍은 몸의 옆에 있으니 물러서는 걸음도 옆이다)
## → 회수(0.57..0.9): 바로 선다 — 풀린 무릎, 내린 팔, 앞을 보는 고개. 정지화가 아니다: 뻗고, 당기고, 놓고, 선다.
## 어느 쪽이 절벽인가는 meta "yank_side"(+1 몸의 local +x 쪽, −1 그 반대 — 팩이 face 로 적는다: 오른쪽(+x)을 보는 몸은 rotation.y = π/2 라 local +x 가 world −z, 절벽 쪽).
## 시계는 pose_t; meta "yank_t" 가 있으면 그 값(점검·주민 시연용 — 한 순간에 멈춰 세운다). done(f) 가 참이면(0.9초) 로더가 자세를 비운다.
## heave(머리 위 줄을 당긴다)·unroll(가슴에서 밖으로 쓸어 펼친다)·shunt(앞의 서가를 민다)와 다르다: 이건 옆의 것을 가슴으로 홱 당기고 뒤발로 받는 몸 — 일의 길이는 서랍의 것이 아니라 한 번의 홱. stick3d_puff.gd 처럼 주제별 파일

const REACH_T := 0.12
const PULL_T := 0.3
const DROP_T := 0.15
const YANK_T := 0.9
const ENTER_T := 0.1

## 자세에 든 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, ENTER_T, f.pose_t)

## 자세의 시계 — 팩·점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("yank_t", f.pose_t))

## 절벽이 있는 쪽(몸의 local x 부호) — 팩이 적어 준 값, 없으면 +1
static func side(f: Stick3D) -> float:
	return 1.0 if float(f.get_meta("yank_side", 1.0)) >= 0.0 else -1.0

## 홱이 끝났나 — 로더가 자세를 비운다
static func done(f: Stick3D) -> bool:
	return at(f) >= YANK_T

## [reach, grip, drop, weight] 0..1 — 뻗은 몫(당김에 내려간다), 가슴에 쥔 몫(놓기에 내려간다), 놓은 몫(회수에 내려간다), 뒤발에 실린 무게(당김부터 회수까지)
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var r := smoothstep(0.0, REACH_T, u)
	var p := smoothstep(REACH_T, REACH_T + PULL_T, u)
	var d := smoothstep(REACH_T + PULL_T, REACH_T + PULL_T + DROP_T, u)
	var c := smoothstep(REACH_T + PULL_T + DROP_T, YANK_T, u)
	return [r * (1.0 - p), p * (1.0 - d), d * (1.0 - c), p * (1.0 - c)]

## 골반은 뻗을 때 조금, 무게가 뒤발에 실리면 더 내려앉는다; 몸통은 뻗을 때 앞으로 기울고 당기면 뒤로 젖혀진다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var ph := phases(f); var reach := float(ph[0]); var w := float(ph[3])
	f.pelvis.position.y = StickRig.HIP_Y - (0.03 * reach + 0.06 * w) * kk
	return (0.2 * reach - 0.22 * w) * kk

## 팔다리 — 두 팔: 절벽 쪽 어깨 높이로 뻗고(먼 팔은 가슴을 가로질러) 당기면 팔꿈치가 접혀 손이 가슴에, 놓으면 떨어진다; 다리: 뒤발(절벽 반대쪽)에 무게 — 그 무릎이 깊고 놓기에 옆으로 반걸음 벌린다; 고개는 손잡이를 보다 당기며 들린다, 가슴은 당김에 열린다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "yank": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var D := side(f); var near := s == D
	var ph := phases(f); var reach := float(ph[0]); var grip := float(ph[1]); var drop := float(ph[2]); var w := float(ph[3])
	var sh_z := (1.25 * reach + 0.75 * grip + 0.25 * drop) if near else (1.1 * reach + 0.95 * grip + 0.3 * drop)   # 양 팔이 다 절벽 쪽으로(+θ 는 local +x 로 — 피벗은 z 를 먼저 돈다)
	sh.rotation.z = D * sh_z * kk
	sh.rotation.x = -((0.15 + 0.35 * reach + 0.2 * grip - 0.1 * drop) * kk)
	el.rotation.x = -((0.3 + 0.15 * reach + 1.5 * grip + 0.1 * drop) * kk)
	if near:
		hip.rotation.x = -((0.1 * reach + 0.1 * w) * kk); knee.rotation.x = (0.15 * reach + 0.3 * w) * kk
		hip.rotation.z = D * 0.06 * w * kk
	else:
		hip.rotation.x = -((0.1 * reach + 0.25 * w) * kk); knee.rotation.x = (0.15 * reach + 0.55 * w) * kk   # 뒤발 — 무게가 여기 떨어진다
		hip.rotation.z = -D * (0.1 * w + 0.22 * drop) * kk                                                   # 놓기에 절벽 반대로 반걸음
	if s > 0.0:
		f.neck.rotation.x += (0.2 * reach - 0.15 * w) * kk
		f.neck.rotation.y += D * 0.35 * (reach + grip) * kk   # 고개는 손잡이를 본다
		f.chest.rotation.x += -0.1 * w * kk
	return true
