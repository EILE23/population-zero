class_name PostPoses
extends RefCounted
## 우편 가족 자세("Letters and notes" — run 99, 1조각 편지방): `sort` 오른손이 편지를 눈높이로 들어 받는 이를 읽고(예비, 고개가 손으로 숙는다),
## 팔을 펴 칸 하나에 밀어 넣고(유지), 손을 거두며 손끝으로 한 번 튕겨 줄을 맞춘다(회수). 바퀴마다 다른 단(아래·가운데·위)으로 손이 간다 —
## 서기가 세 바퀴 돌면 세 단을 다 짚는다. 꺼낼 때도 같은 자세(빈손이 칸으로 들어갔다 편지를 쥐고 나온다, SORT_IN 에 바뀐다). 왼손은 허리께에 편지 다발을 받친다
## 게시판(run 100, 2조각): `pin` 쪽지를 판 높이로 들어 대고(예비), 엄지로 두 번 꾹 눌러 핀을 박고(유지), 반 발짝 물러서며 팔을 내린다(회수) — 뗄 때도 같은 자세.
## `scan` 게시판 읽기: 뒷짐을 지고 고개를 들어(0.3 예비) 쪽지를 왼쪽에서 오른쪽으로 훑고 다시 돌아오며(유지, 2.4초마다) 무게를 이 발 저 발로 옮긴다

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

const PIN_T := 0.9   # 0.3 판에 대기(예비) → 0.4 엄지로 두 번 누르기(유지) → 0.2 물러서기(회수)
const PIN_IN := 0.45 # 첫 누름이 들어간 순간 — town_letters·resident_letters 가 이 시각에 쪽지를 꽂거나 뗀다
const SCAN_T := 2.4  # 훑는 한 바퀴(왼쪽 → 오른쪽 → 가운데)

## 판에 댄 정도 0..1, 누름 0..1(두 번), 물러섬 0..1
static func pin_k(t: float) -> float:
	return smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.7, PIN_T, t))
static func press(t: float) -> float:
	return absf(sin(clampf((t - 0.3) / 0.4, 0.0, 1.0) * TAU))
static func back(t: float) -> float:
	return sin(clampf((t - 0.7) / 0.2, 0.0, 1.0) * PI)

static func lean(f: Stick3D) -> float:
	var pt := fmod(f.pose_t, PIN_T)   # 서기는 여러 장을 연달아 뗀다 — 바퀴마다 처음부터
	if f.pose_request == "pin": return 0.05 * pin_k(pt) + 0.04 * press(pt) - 0.08 * back(pt)   # 누를 때 몸이 실리고, 물러설 때 젖혀진다
	if f.pose_request == "scan": return -0.04 * smoothstep(0.0, 0.3, f.pose_t)   # 판을 올려다보느라 살짝 뒤로
	var t := fmod(f.pose_t, SORT_T)
	return 0.04 * read_k(t) + (0.1 - 0.06 * row(f)) * reach(t)   # 아래 단엔 몸이 더 숙고, 위 단엔 곧게 선다

## 팔다리 — 다리는 곧게(위 단엔 뒤꿈치가 들려 무릎이 펴진 채 엉덩이가 조금 앞으로), 오른팔은 단 높이만큼 올라가며 팔꿈치를 편다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request == "pin": return _pin(f, s)
	if f.pose_request == "scan": return _scan(f, s)
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

## 꽂기 — 오른팔이 판 높이(0.9–1.2m, 어깨보다 위)로 올라가 엄지로 두 번 누르고, 왼손은 판 가장자리를 짚는다. 물러설 땐 왼발이 반 발짝 뒤로
static func _pin(f: Stick3D, s: float) -> bool:
	var t := fmod(f.pose_t, PIN_T); var k := pin_k(t); var pr := press(t); var bk := back(t)
	f.hips[s].rotation.x = 0.25 * bk if s < 0.0 else -0.05 * bk; f.knees[s].rotation.x = 0.04 + (0.2 * bk if s < 0.0 else 0.0)
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	if s > 0.0:
		sh.rotation.x = -(0.15 + 1.95 * k + 0.08 * pr); sh.rotation.z = -0.06
		el.rotation.x = -(0.25 + 0.5 * (1.0 - k) - 0.15 * pr)   # 눌러 박을 때 팔꿈치가 펴진다
		f.neck.rotation.x -= 0.18 * k   # 쪽지 끝을 올려다본다
	else:
		sh.rotation.x = -(0.15 + 1.3 * k * (1.0 - bk)); sh.rotation.z = 0.18 * k; el.rotation.x = -(0.3 + 0.3 * k)
	return true

## 읽기 — 뒷짐(두 팔이 뒤로, 팔꿈치 조금 접혀 손이 엉덩이 뒤에서 만난다), 고개는 위로 −0.2 들고 좌우로 훑는다. 무게가 2.4초에 한 번 이 발 저 발
static func _scan(f: Stick3D, s: float) -> bool:
	var up := smoothstep(0.0, 0.3, f.pose_t); var ph := f.pose_t / SCAN_T * TAU
	var w := sin(ph) * 0.5 + 0.5   # 1 이면 오른발에 무게
	f.hips[s].rotation.x = -0.03; f.knees[s].rotation.x = 0.04 + 0.12 * (1.0 - w if s > 0.0 else w)   # 무게가 빠진 쪽 무릎이 접힌다
	f.shoulders[s].rotation.x = 0.35 * up; f.shoulders[s].rotation.z = -s * 0.12 * up; f.elbows[s].rotation.x = -0.35 * up
	if s > 0.0:
		f.neck.rotation.x -= 0.2 * up; f.neck.rotation.y += 0.32 * sin(ph - 0.6) * up   # 읽는 줄을 따라 고개가 간다
	return true
