class_name SprawlPoses
extends RefCounted
## 매트에 누운 자세(Climb 팩 bar 의 주민 반쪽 — 높이뛰기 선수, run 171; 운영자 보드의 '스포츠 — 높이뛰기' 가족의 셋째 자세, arch 의 다음): `sprawl` 가로대를 넘어 매트에 등으로 내린 몸 —
## 털썩(0..0.3): 내린 몸이 뒤로 넘어가 등이 매트에 닿는다 — 골반이 눕고(−1.45) 낮아지며 두 팔이 옆 위로 벌어지고 두 무릎이 가슴으로 튄다(예비 — 충격)
## → 숨 고르기(0.3..1.5): 등을 대고 누워 오른 무릎은 세우고(발은 매트에) 왼다리는 뻗고, 오른팔은 눈 위에 얹고 왼팔은 매트에 늘어지고, 가슴이 0.9 Hz 로 오르내리고 세운 무릎이 조금 흔들린다(유지 — 어느 순간도 정지화가 아니다)
## → 일어나 앉기(1.5..1.9): 왼팔로 매트를 짚고 몸을 굴려 앉는다 — 골반이 서고(−0.25) 두 다리가 앞으로 뻗어 무릎이 접히고, 고개가 넘은 가로대를 올려다본다(회수) — SPRAWL_T 에 끝나면 팩이 자세를 비우고 stick3d 의 블렌딩이 서게 한다.
## 몸이 보는 쪽(face)의 반대가 머리 쪽 — 팩이 내리며 가로대 쪽을 보게 돌리니 머리는 가로대 반대쪽(배면뛰기의 착지). loll(그물에 받혀 가라앉는 몸)·lying(맞아 누운 몸)·rest(바닥에 눕기)와 다르다: 이건 제 발로 뛰어 넘고 등으로 내린 뒤 한숨 돌리고 앉는 한 번. stick3d_arch.gd 처럼 주제별 파일

const FLOP_T := 0.3
const REST_T := 1.5       # 숨 고르기가 끝나는 때(s) — 그 뒤 일어나 앉는다
const SPRAWL_T := 1.9     # 한 번(s) — 팩이 여기서 자세를 비운다
const BREATH_HZ := 0.9
const LIE_Y := 0.10       # 누운 골반의 높이(m) — 매트 윗면에 등이 닿는다
const SIT_Y := 0.12       # 앉은 골반의 높이(m)

## 자세의 시계 — 점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("sprawl_t", f.pose_t))

static func done(f: Stick3D) -> bool:
	return at(f) >= SPRAWL_T

## [flop, rest, sit] — 털썩(0.3 까지 들어온다), 숨 고르기(0.15 에 들어 1.5 까지, 일어나며 사라진다), 앉기(1.5..1.9 에 올라 끝까지)
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var flop := smoothstep(0.0, FLOP_T, u)
	var sit := smoothstep(REST_T, SPRAWL_T, u)
	var rest := smoothstep(FLOP_T * 0.5, FLOP_T, u) * (1.0 - sit)
	return [flop, rest, sit]

## 가슴의 숨 −1..1
static func breath(f: Stick3D) -> float:
	return sin(f._t * TAU * BREATH_HZ)

## 골반은 털썩에 눕고(−1.45) 낮아지며 숨에 조금 오르내리고, 앉기에 서서(−0.25) 조금 오른다; 몸통은 누워선 뒤로 조금, 앉으며 앞으로(짚은 팔로 밀어 올리는 몸)
static func lean(f: Stick3D) -> float:
	var ph := phases(f); var flop := float(ph[0]); var rest := float(ph[1]); var sit := float(ph[2])
	f.pelvis.rotation.x = lerpf(-1.45, -0.25, sit) * flop
	f.pelvis.position.y = lerpf(StickRig.HIP_Y, LIE_Y, flop) + (SIT_Y - LIE_Y) * sit + 0.006 * breath(f) * rest
	return (-0.12 - 0.03 * breath(f)) * rest * flop + 0.3 * sit

## 팔다리 — 오른다리(s > 0): 털썩에 무릎이 가슴으로 튀고, 누워선 무릎을 세우고(발은 매트에, 조금 흔들린다), 앉으며 앞으로 뻗어 무릎을 접는다; 왼다리(s < 0): 털썩에 같이 튀고 누워선 뻗고 앉으며 접는다;
## 오른팔: 털썩에 옆 위로, 누워선 눈 위에 얹고, 앉으며 무릎으로; 왼팔: 털썩에 옆 위로, 누워선 매트에 늘어지고, 앉으며 뒤를 짚는다; 고개는 누워선 하늘, 앉으며 가로대를 올려다본다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "sprawl": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(f); var flop := float(ph[0]); var rest := float(ph[1]); var sit := float(ph[2])
	var br := breath(f)
	var bump := sin(clampf(at(f) / FLOP_T, 0.0, 1.0) * PI)   # 충격에 한 번 튄다
	var sway := sin(f._t * 2.3) * 0.06 * rest                   # 세운 무릎의 흔들림 — 정지화가 아니다
	if s > 0.0:
		hip.rotation.x = -(1.0 * bump) - (0.9 + sway) * rest - 1.2 * sit
		knee.rotation.x = 1.3 * bump + (1.6 + sway) * rest + 1.0 * sit
		sh.rotation.x = -(1.6 * bump) - (2.6 + 0.03 * br) * rest - 0.9 * sit            # 눈 위에 얹은 팔 — 숨에 조금 움직인다
		sh.rotation.z = -s * (0.9 * bump + 0.25 * rest + 0.15 * sit)
		el.rotation.x = -(0.4 * bump + 2.2 * rest + 0.6 * sit)
		f.neck.rotation.x += 0.2 * bump - 0.25 * rest - 0.35 * sit                       # 누워선 하늘, 앉으며 가로대를 올려다본다
		f.chest.rotation.x += 0.03 * br * rest
	else:
		hip.rotation.x = -(1.0 * bump) - 0.05 * rest - 1.2 * sit
		knee.rotation.x = 1.3 * bump + 0.1 * rest + 1.0 * sit
		sh.rotation.x = -(1.6 * bump) - 0.1 * rest + 0.7 * sit                           # 매트에 늘어졌다 앉으며 뒤를 짚는다(+x 가 뒤)
		sh.rotation.z = -s * (0.9 * bump + 1.0 * rest + 0.3 * sit)
		el.rotation.x = -(0.4 * bump + 0.3 * rest + 0.2 * sit)
	hip.rotation.z = 0.0
	return true
