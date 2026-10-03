class_name ShelfPoses
extends RefCounted
## 책장 가족 자세("Leave one, take one" — run 98, 1조각 책 상자): `shelve` 오른손이 책을 가슴 높이로 들어 올리고(예비), 손바닥을 편 채 상자 칸에 밀어 넣고(유지),
## 등을 두 번 톡 쳐 줄을 맞춘 뒤 팔을 내린다(회수). 꺼낼 때도 같은 자세 — 빈손이 칸으로 들어갔다가 책을 쥐고 나온다(손이 칸에 닿는 SHELVE_IN 에 책이 바뀐다).
## 왼손은 상자 윗면을 짚는다. stick3d_dock.gd 처럼 주제별 파일

const SHELVE_T := 1.0    # 0.3 가슴 높이로 들기(예비) → 0.4 밀어 넣기(유지) → 0.3 톡톡 치고 팔 내리기(회수)
const SHELVE_IN := 0.7   # 손이 칸 끝에 닿은 순간 — 책이 손을 떠나거나(넣기) 손에 들어온다(꺼내기). town_swap 이 이 시각에 재고를 바꾼다

## 들어 올린 정도 0..1
static func lift(t: float) -> float:
	return smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.78, SHELVE_T, t))

## 밀어 넣은 정도 0..1 — 0.3..0.7 에 뻗고, 톡톡 치는 동안 조금 거둔다
static func slide(t: float) -> float:
	return smoothstep(0.3, SHELVE_IN, t) * (1.0 - 0.6 * smoothstep(SHELVE_IN, 0.9, t))

## 톡톡 0..1 — 0.7..0.9 에 두 번
static func tap(t: float) -> float:
	return absf(sin((t - SHELVE_IN) / 0.2 * TAU)) if t >= SHELVE_IN and t < 0.9 else 0.0

static func lean(f: Stick3D) -> float:
	var t := fmod(f.pose_t, SHELVE_T)   # 되풀이(관리인이 책등을 세 번 고른다) — 사람은 한 바퀴 뒤 town_player 가 푼다
	return 0.06 * lift(t) + 0.12 * slide(t)   # 칸 쪽으로 몸이 조금 따라 들어간다

## 팔다리 — 다리는 곧게(오른발 반 발 앞), 오른팔은 가슴 앞에서 팔꿈치를 펴며 앞으로, 톡 칠 때 손목 대신 어깨가 살짝 오르내린다. 왼손은 상자 윗면에
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "shelve": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t := fmod(f.pose_t, SHELVE_T); var l := lift(t); var sl := slide(t); var tp := tap(t)
	hip.rotation.x = -(0.1 * l if s > 0.0 else -0.05 * l); knee.rotation.x = 0.05 + (0.08 * l if s < 0.0 else 0.0)
	if s > 0.0:
		sh.rotation.x = -(0.05 + 0.5 * l + 0.45 * sl + 0.08 * tp); sh.rotation.z = -0.1 * l
		el.rotation.x = -(0.35 + 1.25 * l - 1.3 * sl)   # 가슴 앞(팔꿈치 1.6)에서 칸 안(0.3)까지 편다
		f.neck.rotation.x += 0.2 * l   # 손끝(칸)을 본다
	else:
		sh.rotation.x = -(0.05 + 0.55 * l); sh.rotation.z = 0.1; el.rotation.x = -(0.35 + 0.25 * l)   # 상자 윗면을 짚는다
	return true
