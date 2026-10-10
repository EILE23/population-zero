class_name LollPoses
extends RefCounted
## 해먹 눕기 가족 자세(Climb 콘텐츠 팩 hammock, run 135 — data/climb/hammock.json, scripts/games/climb_hammock.gd; 운영자 보드의 '소파에 눕기' 가족 중 그물에 받혀 누운 몸): `loll` 해먹 그물에 등을 대고 누운 몸 —
## 받히는 0.4(meta "loll_c" 0..1, 팩의 cling 이 적는다 — 없으면 0.4초에 제 박자로): 떨어진 몸이 등부터 닿아 팔다리가 위로 벌어지고(두 팔이 옆 위로, 두 무릎이 가슴으로) 골반이 반쯤 누운 채 높이 있다(예비 — 충격)
## → 가라앉으며 자리를 잡는다: 골반이 깊이 눕고(−1.35) 낮아지며, 오른팔은 머리 뒤로 접히고 왼팔은 가장자리 너머로 늘어지고, 다리는 뻗되 오른발이 왼발 위에 얹혀 0.6Hz 로 까딱이고, 고개는 하늘을 본다(유지);
## 그물의 흔들림(meta "loll_sw" −1..1)에 골반째 옆으로 구르고, 깊이(meta "loll_d" 0..1)만큼 몸이 더 접힌다(깊은 그물은 몸을 감싼다); 몸통은 숨(1.0Hz)에 오르내린다.
## → 던져 올리거나 굴러 나가 로더가 자세를 비우면 stick3d 의 블렌딩이 공중 자세로 편다(회수). 몸이 보는 쪽(로더의 face)의 반대가 머리 쪽.
## sky·rest(바닥에 눕기 — 쪼그려 앉았다 등을 굴린다)·rock(흔들의자에 앉아 흔들린다)·part 의 안김(덩굴을 쥔 채 선 몸)과 다르다: 이건 떨어져 받힌 충격에서 늘어진 눕기로 가라앉는 몸. stick3d_nap.gd 처럼 주제별 파일

const SETTLE_T := 0.4
const BOB_HZ := 0.6
const BREATH_HZ := 1.0

## 자리를 잡은 정도 0..1 — 팩이 적어 준 값, 없으면 pose_t 로
static func c(f: Stick3D) -> float:
	return clampf(float(f.get_meta("loll_c", smoothstep(0.0, SETTLE_T, f.pose_t))), 0.0, 1.0)

## 그물의 흔들림 −1..1
static func sw(f: Stick3D) -> float:
	return clampf(float(f.get_meta("loll_sw", sin(f._t * TAU / 2.6))), -1.0, 1.0)

## 깊이 0..1
static func d(f: Stick3D) -> float:
	return clampf(float(f.get_meta("loll_d", 0.4)), 0.0, 1.0)

## 골반은 충격엔 반쯤 누워 높고 자리를 잡으면 깊이 누워 낮다; 흔들림에 옆으로 구른다. 몸통은 숨에, 깊을수록 조금 더 접힌다
static func lean(f: Stick3D) -> float:
	var cc := c(f); var dd := d(f)
	f.pelvis.rotation.x = lerpf(-1.0, -1.35, cc)
	f.pelvis.rotation.z = 0.08 * sw(f) * cc
	f.pelvis.position.y = lerpf(0.16, 0.11, cc)
	return -0.1 - 0.12 * dd * cc + 0.02 * sin(f._t * TAU * BREATH_HZ) * cc

## 팔다리 — 충격: 두 팔이 옆 위로 벌어지고 무릎이 가슴으로; 자리: 오른팔은 머리 뒤로 접히고 왼팔은 가장자리 너머로, 다리는 뻗고 오른발이 왼발 위에서 까딱인다, 고개는 하늘을
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "loll": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var cc := c(f); var dd := d(f)
	var bob := 0.05 * sin(f._t * TAU * BOB_HZ)
	# 충격(cc 0) → 자리(cc 1)
	var hip_a := 1.0 + 0.1 * s; var knee_a := 1.3
	var hip_b := (0.35 + bob if s > 0.0 else 0.25) + 0.25 * dd; var knee_b := (0.3 if s > 0.0 else 0.15) + 0.2 * dd
	hip.rotation.x = -lerpf(hip_a, hip_b, cc)
	knee.rotation.x = lerpf(knee_a, knee_b, cc)
	if s > 0.0:   # 오른팔 — 충격엔 옆 위로, 자리엔 머리 뒤로 접힌다
		sh.rotation.x = -lerpf(1.6, 2.7, cc); sh.rotation.z = -s * lerpf(0.9, 0.5, cc); el.rotation.x = -lerpf(0.4, 2.3, cc)
		f.neck.rotation.x += lerpf(0.2, -0.3, cc)   # 충격엔 턱을 당기고, 자리엔 하늘을
		f.neck.rotation.z += 0.05 * sw(f) * cc
	else:   # 왼팔 — 충격엔 옆 위로, 자리엔 가장자리 너머로 늘어진다
		sh.rotation.x = -lerpf(1.6, 0.1, cc); sh.rotation.z = -s * lerpf(0.9, 1.1, cc); el.rotation.x = -lerpf(0.4, 0.3, cc)
	return true
