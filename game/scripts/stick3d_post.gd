class_name PostPoses
extends RefCounted
## 우편 가족 자세("Letters and notes" — run 99, 1조각 편지방): `sort` 오른손이 편지를 눈높이로 들어 받는 이를 읽고(예비, 고개가 손으로 숙는다),
## 팔을 펴 칸 하나에 밀어 넣고(유지), 손을 거두며 손끝으로 한 번 튕겨 줄을 맞춘다(회수). 바퀴마다 다른 단(아래·가운데·위)으로 손이 간다 —
## 서기가 세 바퀴 돌면 세 단을 다 짚는다. 꺼낼 때도 같은 자세(빈손이 칸으로 들어갔다 편지를 쥐고 나온다, SORT_IN 에 바뀐다). 왼손은 허리께에 편지 다발을 받친다

const SORT_T := 1.2    # 0.35 눈높이로 들어 읽기(예비) → 0.4 칸으로 뻗기(유지) → 0.45 거두며 튕기기(회수)
const SORT_IN := 0.75  # 손이 칸 안에 닿은 순간 — town_letters·resident_letters 가 이 시각에 재고를 바꾼다

## 눈높이로 든 정도 0..1(읽는 동안 높고, 뻗을 때 칸 높이로 넘어간다)
static func read_k(t: float) -> float:
	return smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(0.35, 0.6, t))

## 칸으로 뻗은 정도 0..1
static func reach(t: float) -> float:
	return smoothstep(0.35, SORT_IN, t) * (1.0 - smoothstep(0.85, SORT_T, t))

## 튕기기 0..1 — 0.75..0.95 에 한 번
static func flick(t: float) -> float:
	return sin(clampf((t - SORT_IN) / 0.2, 0.0, 1.0) * PI)

## 이번 바퀴의 단 0..2 — 바퀴마다 아래·가운데·위를 돈다(사람마다 시작 단이 같아도 되풀이하면 셋을 다 짚는다)
static func row(f: Stick3D) -> int:
	return int(f.pose_t / SORT_T) % 3

static func lean(f: Stick3D) -> float:
	var t := fmod(f.pose_t, SORT_T)
	return 0.04 * read_k(t) + (0.1 - 0.06 * row(f)) * reach(t)   # 아래 단엔 몸이 더 숙고, 위 단엔 곧게 선다

## 팔다리 — 다리는 곧게(위 단엔 뒤꿈치가 들려 무릎이 펴진 채 엉덩이가 조금 앞으로), 오른팔은 단 높이만큼 올라가며 팔꿈치를 편다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "sort": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t := fmod(f.pose_t, SORT_T); var rd := read_k(t); var rc := reach(t); var fl := flick(t); var r := row(f)
	var up := 0.9 + 0.72 * r   # 칸 높이에 닿는 어깨 각 — 아래 0.55m·가운데 0.8m·위 1.05m(어깨 0.84, 팔 0.37)
	hip.rotation.x = -(0.06 * rc if s > 0.0 else -0.03 * rc); knee.rotation.x = 0.04 + (0.1 * rc if r == 0 else 0.0)
	if s > 0.0:
		sh.rotation.x = -(0.1 + 1.0 * rd + (up - 0.1 - 1.0 * rd) * rc); sh.rotation.z = -0.08
		el.rotation.x = -(0.3 + 1.5 * rd * (1.0 - rc) + 0.25 * fl)   # 눈앞에선 팔꿈치를 접어 읽고, 칸에선 편다 — 튕길 때 손목 대신 팔꿈치가 살짝
		f.neck.rotation.x += 0.22 * rd - 0.15 * rc * (r - 1)   # 편지를 읽다가, 손끝이 가는 단을 본다
	else:
		sh.rotation.x = -(0.35 + 0.1 * rd); sh.rotation.z = 0.12; el.rotation.x = -1.35   # 왼손은 허리께에 다발을 받친다
	return true
