class_name LedgerPoses
extends RefCounted
## 장부 가족 자세("Money in hands" 4조각, run 112): `sigh` — 장부의 제 줄을 읽고 난 한숨. 두 손을 탁자 모서리에 평평히 짚은 채
## 0.4 어깨와 가슴이 숨을 들이쉬며 오른다(예비) → 0.6 어깨가 떨어지고 고개가 앞으로 꺾이며 몸이 가라앉는다(회수). 정지화가 아니다.
## 가라앉는 동안 고개가 한 번 천천히 옆으로 기운다 — 리그엔 눈이 없어 '느린 눈 깜빡임'은 이것으로 읽는다. 사람도 주민도 같은 자세·같은 시각(town_ledger).
## scan(stick3d_post.gd, 읽기) 뒤, stoop(stick3d_coin.gd, 접시에 한 닢) 앞에 온다 — 셋이 한 차례다

const SIGH_T := 1.0
const SIGH_UP := 0.4   # 들이쉼의 끝 — 여기서 가장 높다

## 들이쉰 정도 0..1 — 0.4 까지 오르고 0.6 동안 떨어진다(떨어짐이 더 빠르게 시작해 끝에서 늘어진다)
static func breath(t: float) -> float:
	if t < SIGH_UP: return smoothstep(0.0, SIGH_UP, t)
	return 1.0 - smoothstep(SIGH_UP, SIGH_UP + 0.35, t)

## 가라앉음 0..1 — 떨어진 뒤 끝까지 남는다(고개가 앞으로, 몸이 모서리에 실린다)
static func sink(t: float) -> float:
	return smoothstep(SIGH_UP, SIGH_T, t)

## 느린 기울임 −1..1 — 가라앉는 동안 한 번
static func tilt(t: float) -> float:
	return sin(clampf((t - SIGH_UP) / 0.6, 0.0, 1.0) * PI)

static func lean(f: Stick3D) -> float:
	var t := minf(f.pose_t, SIGH_T)
	return 0.18 - 0.07 * breath(t) + 0.12 * sink(t)   # 탁자에 손을 짚느라 조금 숙인 채, 들이쉬며 펴지고 내쉬며 더 숙는다

## 팔다리 — 두 팔이 앞으로 내려가 손이 탁자 모서리(0.72m)에 평평히, 들이쉴 때 어깨가 바깥·위로 들리고 내쉴 때 팔꿈치가 조금 꺾이며 몸이 실린다. 무릎은 내쉴 때 살짝 풀린다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "sigh": return false
	var t := minf(f.pose_t, SIGH_T); var b := breath(t); var k := sink(t)
	f.hips[s].rotation.x = -(0.02 + 0.03 * k); f.knees[s].rotation.x = 0.04 + 0.06 * k
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	sh.rotation.x = -(1.15 - 0.08 * b + 0.05 * k); sh.rotation.z = -s * (0.1 + 0.16 * b - 0.04 * k)   # 어깨가 들리면 팔이 바깥으로 벌어진다
	el.rotation.x = -(0.1 + 0.05 * b + 0.22 * k)   # 몸이 실리면 팔꿈치가 꺾인다
	if s > 0.0:
		f.neck.rotation.x += -0.14 * b + 0.42 * k   # 들이쉬며 고개가 들리고, 내쉬며 앞으로 꺾인다
		f.neck.rotation.z += 0.12 * tilt(t)
		f.chest.rotation.x -= 0.05 * b
	return true
