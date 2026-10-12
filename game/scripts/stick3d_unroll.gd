class_name UnrollPoses
extends RefCounted
## 두루마리 선반 가족 자세(Climb 콘텐츠 팩 scroll, run 145 — data/climb/scroll.json, scripts/games/climb_scroll.gd; 운영자 보드의 '지도 읽기·펼치기' 가족 — 가슴의 두루마리를 밖으로 쓸어 펼치는 몸): `unroll` 선반의 맨 위 지도를 당겨 틈 위로 펼치는 몸 —
## 0.15 두 팔이 가슴으로 모여 두루마리를 쥐고(팔꿈치가 깊이 접힌다) 고개가 두루마리로 숙으며 무릎이 조금 내려앉고 몸통이 앞으로 기운다(예비 — 쥐기) → 쓸기, 팩이 적는 메타로:
## 종이가 나간 비율("unroll_k" 0..1; 없으면 0.65초의 제 박자): 두 팔이 가슴에서 앞으로 뻗으며 옆으로 벌어지고 팔꿈치가 펴진다 — 종이가 나간 만큼만; 왼발이 한 걸음 물러서고 오른발은 조금 앞에 남으며 몸통은 앞기울기에서 뒤로 젖힘으로 옮겨 가고 골반이 조금 더 내려앉는다; 고개는 두루마리에서 종이 끝을 따라 먼 발판까지 들린다;
## 다 펼쳐진 뒤 0.4초 두 팔이 조금 내려와 쉰다(회수 — 로더가 자세를 비우면 stick3d 의 블렌딩이 몸을 편다).
## 메타가 없으면 제 박자로 한 번 쓸고 쉰다(주민·시연용). crank(제자리에서 도는 두 손)·shunt(앞의 서가를 두 손으로 민다)·part(가슴 앞의 덩굴을 바깥으로 젖힌다)와 다르다: 이건 가슴에서 밖으로 한 번 쓸어 벌리는 두 팔, 일의 길이가 종이의 것이다. stick3d_crank.gd 처럼 주제별 파일

const GRASP_T := 0.15
const SWEEP_T := 0.65     # 제 박자 — 팩의 unroll_s 0.8 에서 쥐기를 뺀 것
const SETTLE_T := 0.4
const STEP_BACK := 0.5    # 왼 엉덩이: 물러선 발(rad)

## 쥔 정도 0..1
static func g(f: Stick3D) -> float:
	return smoothstep(0.0, GRASP_T, f.pose_t)

## 종이가 나간 비율 0..1 — 팩이 적어 준 값, 없으면 제 박자
static func w(f: Stick3D) -> float:
	if f.has_meta("unroll_k"): return clampf(float(f.get_meta("unroll_k")), 0.0, 1.0)
	return clampf((f.pose_t - GRASP_T) / SWEEP_T, 0.0, 1.0)

## 다 펼친 뒤 쉬는 정도 0..1 — 종이가 다 나갔을 때만
static func settle(f: Stick3D) -> float:
	if w(f) < 1.0: return 0.0
	return smoothstep(0.0, SETTLE_T, f.pose_t - GRASP_T - SWEEP_T)

## 골반이 내려앉고(종이가 나갈수록 조금 더) 몸통이 앞으로 기울었다가 물러서며 뒤로 젖힌다
static func lean(f: Stick3D) -> float:
	var gg := g(f); var ww := w(f)
	f.pelvis.position.y = StickRig.HIP_Y - (0.04 + 0.03 * ww) * gg
	return lerpf(0.28, -0.12, ww) * gg

## 팔다리 — 두 팔은 가슴의 두루마리를 쥐었다가 종이가 나간 만큼 앞으로 뻗으며 옆으로 벌어지고 팔꿈치가 펴진다, 다 펼치면 조금 내려와 쉰다; 왼발이 물러서고 오른발은 조금 앞에; 고개는 두루마리에서 종이 끝을 따라 든다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "unroll": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var gg := g(f); var ww := w(f); var r := settle(f)
	var sh_x := lerpf(1.35, 0.95, ww) - 0.25 * r; var sh_z := lerpf(0.15, 0.95, ww); var el_x := lerpf(1.9, 0.35, ww)
	var hip_c := (-0.12 if s > 0.0 else STEP_BACK) * ww; var knee_c := (0.18 if s > 0.0 else 0.4) * ww
	hip.rotation.x = -(hip_c * gg)
	knee.rotation.x = knee_c * gg
	sh.rotation.x = -(0.15 + (sh_x - 0.15) * gg); sh.rotation.z = -s * sh_z * gg; el.rotation.x = -(0.5 + (el_x - 0.5) * gg)
	if s > 0.0: f.neck.rotation.x += lerpf(0.45, -0.12, ww) * gg   # 두루마리를 보다 종이 끝을 따라 먼 발판을
	return true
