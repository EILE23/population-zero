class_name ResetPoses
extends RefCounted
## 가로대 세우기 자세(Climb 팩 bar 의 주민 반쪽 — 높이뛰기 선수, run 171; 백로그 "Raising the bar" 가 플레이어에게 쓸 같은 자세): `reset` 매트에 누운 가로대를 두 손으로 들어 눈금에 다시 놓는 몸 —
## 손 대기(0..0.2): 무릎을 조금 굽히고 허리를 숙여 두 손이 허리 높이의 가로대로 간다(예비 — 매트 14 px 위의 가로대는 허리께다)
## → 들기(0.2..0.8, 팩의 lift_s 0.6 과 같다 — 가로대가 눈금으로 돌아가는 동안 손이 따라 오른다): 무릎이 펴지고 두 팔이 허리에서 머리 위로 곧게 오르며 몸통이 조금 뒤로 젖고 발뒤꿈치가 든다(유지 — 팔은 12 Hz 로 떨린다, 든 무게)
## → 손 떼기(0.8..1.0): 팔이 내려와 옆에 붙고 고개는 눈금 위의 가로대를 올려다보며 한 번 까딱인다(회수) — RESET_T 에 끝나면 팩이 자세를 비운다.
## 가로대는 팩이 옮긴다(climb_bar._place 의 lift — 선수가 REACH_T 에 fell_t 를 돌려놓는다); 자세는 그 위에 손을 입힌다. 눈금은 손보다 높이 있다(2.0·2.4 m) — 졸라맨의 팔은 거기까지 안 닿고 가로대만 더 오른다.
## heave(덤웨이터 줄을 당기는 몸)·shelve(선반에 얹는 몸)·plonk(상자를 바닥에 놓는 몸)와 다르다: 이건 가벼운 가로대를 눈금까지 들어 올리는 한 번. stick3d_sprawl.gd 처럼 주제별 파일

const REACH_T := 0.2      # 손이 가로대에 닿는 때(s) — 팩은 여기서 가로대를 올리기 시작한다
const LIFT_T := 0.6       # 드는 시간(s) = climb_bar lift_s
const RESET_T := 1.0      # 한 번(s) — 팩이 여기서 자세를 비운다
const TREMBLE_HZ := 12.0
const DIP := 0.06         # 손 댈 때 무릎이 굽어 골반이 내려앉는 높이(m)
const RISE := 0.03        # 다 들었을 때 발뒤꿈치가 들려 골반이 오르는 높이(m)

## 자세의 시계 — 점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("reset_t", f.pose_t))

static func done(f: Stick3D) -> bool:
	return at(f) >= RESET_T

## [reach, lift, off] — 손 대기(0.2 까지 들어온다), 들기(0.2..0.8 에 0 → 1), 손 떼기(0.8..1.0 에 0 → 1)
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var reach := smoothstep(0.0, REACH_T, u)
	var lift := smoothstep(REACH_T, REACH_T + LIFT_T, u)
	var off := smoothstep(REACH_T + LIFT_T, RESET_T, u)
	return [reach, lift, off]

## 든 팔의 잔떨림 −1..1 — 들수록 커진다
static func tremble(f: Stick3D, s: float) -> float:
	var ph := phases(f)
	return sin(f._t * TAU * TREMBLE_HZ + s) * float(ph[1]) * (1.0 - float(ph[2]))

## 골반은 손 댈 때 내려앉고 들며 발뒤꿈치가 들려 조금 오르고 손을 떼면 돌아온다; 몸통은 숙였다가 들며 뒤로 조금 젖고 손을 떼며 선다
static func lean(f: Stick3D) -> float:
	var ph := phases(f); var reach := float(ph[0]); var lift := float(ph[1]); var off := float(ph[2])
	f.pelvis.position.y = StickRig.HIP_Y - DIP * reach * (1.0 - lift) + RISE * lift * (1.0 - off)
	return 0.3 * reach * (1.0 - lift) - 0.12 * lift * (1.0 - off)

## 팔다리 — 두 다리: 손 댈 때 굽고 들며 펴진다; 두 팔: 허리 높이의 앞으로 뻗었다가 머리 위로 곧게 오르고(떨린다) 손을 떼며 옆으로 내려온다; 고개는 들며 가로대를 따라 오르고 손을 떼며 한 번 까딱인다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "reset": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(f); var reach := float(ph[0]); var lift := float(ph[1]); var off := float(ph[2])
	var q := tremble(f, s) * 0.05
	var bend := reach * (1.0 - lift)
	hip.rotation.x = -(0.45 * bend) - 0.05 * s * lift; hip.rotation.z = 0.0
	knee.rotation.x = 0.8 * bend
	var arm := lerpf(lerpf(0.0, 0.95, reach), 2.9, lift) * (1.0 - off) + 0.05 * off   # 허리 높이(0.95) → 머리 위(2.9) → 옆(0.05)
	sh.rotation.x = -(arm) + q
	sh.rotation.z = -s * (0.12 + 0.1 * bend + 0.08 * lift * (1.0 - off))
	el.rotation.x = -(0.35 * bend + 0.15 * lift * (1.0 - off) + 0.3 * off)
	if s > 0.0:
		var nod := sin(clampf(off, 0.0, 1.0) * PI) * 0.15   # 손을 떼며 한 번 까딱
		f.neck.rotation.x += 0.15 * bend - 0.4 * lift + nod
		f.chest.rotation.x += 0.08 * bend - 0.06 * lift * (1.0 - off)
	return true
