class_name LickPoses
extends RefCounted
## 바람을 읽는 자세(Climb 팩 javelin 의 주민 반쪽 — 던지는 이, run 179; 운영자 보드의 '바람 읽기' 시트, hurl 의 앞): `lick` 던지기 전에 한 손가락을 입술에 대 적시고(0.3 s), 그 팔을 곧게 들어 손가락을 세운 채(0.8 s) 고개를 바람 아래쪽(lee)으로 돌려 바람을 느끼고, 팔을 내리는(0.2 s) 몸 — 몸은 카메라를 보고 선다.
## 시계는 하나고 던지는 이(climb_thrower.gd)가 적는다: meta "lick_t"(자세에 든 뒤 시간), meta "lick_lee"(고개가 도는 쪽 ±1 — 세상 x 의 부호: 바람이 미는 쪽, 바람이 없으면 고리 쪽). 메타가 없으면 pose_t 로 혼자 한 번 돈다(점검·시연용, lee +1).
## 입술(0..0.3): 오른팔이 입으로(어깨 −1.2, 안으로 z −0.3, 팔꿈치 −1.75) — 손가락이 입술에 닿는 끝에 고개가 조금 숙는다(+0.15); 왼팔은 늘어뜨린 채
## → 든 팔(0.3..1.1): 오른팔이 머리 위로 곧게(어깨 −2.85, 팔꿈치 −0.1) 손가락을 세우고 1.5 Hz 로 z 가 조금 흔들린다(바람을 느낀다, ±0.04), 왼손은 허리로(어깨 −0.3, 바깥 z 0.55, 팔꿈치 −1.7), 고개가 0.25 s 에 걸쳐 lee 로 돈다(0.6)·0.5 Hz 로 조금 끄덕인다, 상체가 조금 뒤로(−0.08)
## → 내림(1.1..1.3): 팔다리가 내려오고 고개가 돌아온다 — 정지화가 아니다(무릎은 늘 0.8 Hz 로 숨쉰다).
## shade(손차양)·hark(화음을 듣는다)·squint(해시계를 읽는다)와 다르다: 이건 보이지 않는 것을 손가락으로 읽는 몸 — 끝나면 바로 hurl 이 온다. stick3d_sleeve.gd 처럼 주제별 파일

const LIPS_T := 0.3                       # 손가락을 입술에(s)
const UP_T := 0.8                         # 든 팔(s)
const DOWN_T := 0.2                       # 내림(s)
const TOTAL := LIPS_T + UP_T + DOWN_T     # 자세 전체(s) — 던지는 이가 이만큼 뒤 hurl 로
const RISE := 0.12                        # 입술로 올라가는 시간(s)
const BLEND := 0.05                       # 입술에서 든 팔로 넘어가는 반폭(s)
const TURN_T := 0.25                      # 고개가 lee 로 도는 시간(s)
const FEEL_HZ := 1.5                      # 든 손가락의 흔들림
const NOD_HZ := 0.5                       # 돌린 고개의 끄덕임
const BREATHE_HZ := 0.8
const LIPS_SH := 1.2; const LIPS_Z := 0.3; const LIPS_EL := 1.75
const UP_SH := 2.85; const UP_EL := 0.1; const FEEL := 0.04
const HIP_SH := 0.3; const HIP_Z := 0.55; const HIP_EL := 1.7
const TURN := 0.6                         # 고개가 lee 로 도는 각(rad)
const NOD := 0.05
const DIP := 0.15                         # 입술에 고개가 숙는 각(rad)
const LEAN := 0.08                        # 든 팔 동안 상체가 뒤로

## 자세에 든 뒤 시간(s) — 던지는 이의 메타, 없으면 pose_t
static func since(f: Stick3D) -> float:
	if f.has_meta("lick_t"): return maxf(0.0, float(f.get_meta("lick_t")))
	return f.pose_t

## 고개가 도는 쪽 ±1 — 메타, 없으면 +1
static func lee(f: Stick3D) -> float:
	return 1.0 if not f.has_meta("lick_lee") or float(f.get_meta("lick_lee")) >= 0.0 else -1.0

## 다 했나
static func done(f: Stick3D) -> bool:
	return since(f) >= TOTAL

## [a, b, k] — 입술의 몫(0.12 에 올라 0.3 에 넘어간다), 든 팔의 몫(0.3 에 들어 1.1..1.3 에 내려온다), 고개가 돈 몫(0.3 뒤 0.25 s 에 걸쳐 돌고 든 팔과 함께 돌아온다)
static func phases(u: float) -> Array:
	var ta := smoothstep(LIPS_T - BLEND, LIPS_T + BLEND, u)
	var te := smoothstep(TOTAL - DOWN_T, TOTAL, u)
	var a := smoothstep(0.0, RISE, u) * (1.0 - ta)
	var b := ta * (1.0 - te)
	var k := smoothstep(LIPS_T, LIPS_T + TURN_T, u) * (1.0 - te)
	return [a, b, k]

## 상체 — 든 팔 동안 조금 뒤로
static func lean(f: Stick3D) -> float:
	var ph := phases(since(f))
	return -LEAN * float(ph[1])

## 팔다리 — 오른팔(s > 0): 입술로(−1.2, z −0.3, −1.75) → 머리 위로 곧게(−2.85, −0.1) 손가락이 1.5 Hz 로 흔들린다 → 내려온다; 왼팔(s < 0): 늘어뜨리다 든 팔 동안 허리로(−0.3, z 0.55, −1.7); 다리는 선 채 무릎이 숨쉰다; 고개는 입술에 숙고(+0.15) 든 팔 동안 lee 로 돈다(0.6)·끄덕인다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "lick": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var u := since(f); var ph := phases(u); var a := float(ph[0]); var b := float(ph[1]); var k := float(ph[2])
	var breathe := sin(f._t * TAU * BREATHE_HZ) * 0.03   # 무릎의 숨 — 정지화가 아니다
	var feel := sin(f._t * TAU * FEEL_HZ) * FEEL * b     # 든 손가락이 바람을 느낀다
	if s > 0.0:
		sh.rotation.x = -LIPS_SH * a - UP_SH * b
		sh.rotation.z = -LIPS_Z * a + feel
		el.rotation.x = -LIPS_EL * a - UP_EL * b
	else:
		sh.rotation.x = -HIP_SH * b
		sh.rotation.z = HIP_Z * b
		el.rotation.x = -HIP_EL * b
	hip.rotation.x = -0.03 * b; knee.rotation.x = 0.05 * (a + b) + breathe
	if s > 0.0:
		f.neck.rotation.x += DIP * a - NOD * sin(f._t * TAU * NOD_HZ) * k   # 입술에 숙고(+), 돌린 채 조금 끄덕인다
		f.neck.rotation.y += TURN * lee(f) * k                                # 바람 아래쪽을 본다
	return true
