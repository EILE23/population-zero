class_name WearPoses
extends RefCounted
## 입기 가족 자세(money 2, run 114 — 잡화점에서 산 것을 그 자리에서 쓴다; 운영자의 졸라맨 판 "모자 쓰기·졸업·결혼" 줄에서):
## `don` 두 손으로 머리에 얹는다 — 0.3 오른손의 것이 두 손에 들려 머리 위로 오르고 팔꿈치가 바깥으로 벌어진다(예비) → 0.15 고개가 살짝 숙으며 얹힌다(유지 — DON_ON 에 손의 것이 소켓으로 옮겨 간다)
## → 0.4 손끝이 챙을 두 번 톡톡 고르고 팔이 내려온다(회수). 손에 든 채 C 로 쓰던 grab 과 다르다: grab 은 선 채 손만 뻗는다; don 은 머리까지 올려 고르고 내려온다.
## `doff` 오른손만 올려 벗는다 — 0.32 오른팔이 머리로(예비) → DOFF_OFF 에 소켓의 것이 손으로 → 0.48 팔이 내려와 가슴 앞에 든다(회수), 고개는 모자가 떠나는 쪽으로 살짝 든다. 왼팔은 늘어뜨린 채.
## 사람도 주민도 같은 자세·같은 시각(town_store). stick3d_coin.gd 처럼 주제별 파일

const DON_T := 0.85
const DON_ON := 0.3      # 손의 것이 머리 소켓으로 옮겨 가는 순간(town_store.don)
const DOFF_T := 0.8
const DOFF_OFF := 0.32   # 소켓의 것이 손으로 오는 순간(town_store.doff)

## 올린 정도 0..1 — 0.3 에 머리에 닿고 0.45 부터 0.85 까지 내려온다
static func rise(t: float) -> float:
	return smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.45, 0.85, t))

## 얹는 동안 고개 숙임 0..1
static func settle(t: float) -> float:
	return smoothstep(0.26, 0.34, t) * (1.0 - smoothstep(0.45, 0.6, t))

## 챙 고르기 — 0.45~0.65 사이 두 번 톡톡
static func pat(t: float) -> float:
	return absf(sin((t - 0.45) / 0.2 * TAU)) if t >= 0.45 and t < 0.65 else 0.0

## 벗기의 오른팔 0..1 — 0.32 에 머리, 0.8 까지 가슴 앞으로
static func lift(t: float) -> float:
	return smoothstep(0.0, 0.32, t) * (1.0 - smoothstep(0.4, DOFF_T, t))

static func lean(f: Stick3D) -> float:
	if f.pose_request == "doff": return -0.04 * lift(minf(f.pose_t, DOFF_T))
	return -0.06 * rise(minf(f.pose_t, DON_T))   # 손이 머리로 가면 몸이 조금 젖혀진다

## 팔다리 — don: 두 어깨가 앞·위로 2.3 까지, 팔꿈치가 1.3 접혀 손이 머리 꼭대기에, 어깨가 바깥으로 벌어진다; doff: 오른팔만 같은 길, 왼팔은 늘어뜨린다. 무릎은 조금 풀린 서기
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "don" and f.pose_request != "doff": return false
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	f.hips[s].rotation.x = -0.02; f.knees[s].rotation.x = 0.05
	if f.pose_request == "don":
		var t := minf(f.pose_t, DON_T); var k := rise(t); var st := settle(t); var pt := pat(t)
		sh.rotation.x = -(0.1 + 2.2 * k - 0.12 * st + 0.08 * pt); sh.rotation.z = -s * (0.08 + 0.3 * k)
		el.rotation.x = -(0.15 + 1.15 * k + 0.1 * st)
		if s > 0.0: f.neck.rotation.x += 0.18 * st - 0.04 * pt
		return true
	var t2 := minf(f.pose_t, DOFF_T); var l := lift(t2); var held := smoothstep(0.4, DOFF_T, t2)   # 끝엔 가슴 앞에 든다(carry 와 같은 팔)
	if s > 0.0:
		sh.rotation.x = -(0.1 + 2.2 * l + 0.45 * held); sh.rotation.z = -(0.06 + 0.25 * l)
		el.rotation.x = -(0.15 + 1.15 * l + 1.0 * held)
		f.neck.rotation.x -= 0.12 * l
	else:
		sh.rotation.x = -0.05; sh.rotation.z = 0.04; el.rotation.x = -0.1
	return true
