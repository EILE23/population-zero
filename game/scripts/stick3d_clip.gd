class_name ClipPoses
extends RefCounted
## 바짓단을 집는 자세(Climb 팩 railcar 의 주민 반쪽 — 선로지기, run 181; 운영자 보드의 '자전거' 시트에서 페달 앞의 몸, 자전거 가족의 둘째): `clip` 차에 오르기 전에 허리를 숙여 한 손으로 발목의 바짓단을 집어 모으고(0.4 s), 그 다리를 들어 정강이를 털고(0.3 s), 일어서는(0.3 s) 몸 — 몸은 카메라를 보고 선다.
## 시계는 하나고 선로지기(climb_linesman.gd)가 적는다: meta "clip_t"(자세에 든 뒤 시간). 메타가 없으면 pose_t 로 혼자 한 번 돈다(점검·시연용).
## 숙임(0..0.4): 0.15 s 에 상체가 앞으로(0.95) 두 무릎이 접히고(0.45) 골반이 조금 내려오며(−0.06) 오른팔이 발목으로(어깨 −0.55, 안으로 z −0.1, 팔꿈치 −0.25) 손가락이 천을 6 Hz 로 집는다(팔꿈치 ±0.05); 왼팔은 뒤로 흔들려 버틴다(+0.35); 고개는 발목을 본다(+0.55)
## → 털기(0.4..0.7): 상체가 반쯤 일어나고(0.45) 오른 다리가 들려(엉덩이 −0.5, 무릎 +0.6) 정강이가 5 Hz 로 흔들린다(무릎 ±0.25); 손은 놓고 내려온다; 왼 무릎이 조금 버틴다(0.1)
## → 일어섬(0.7..1.0): 다 돌아온다 — 정지화가 아니다(왼 무릎은 늘 0.8 Hz 로 숨쉰다).
## sleeve(소매를 걷는다)·chalk(손에 초크를 친다)·limber(다리를 턴다)와 다르다: 이건 톱니에 물릴 천을 모으는 몸 — 끝나면 바로 pedal 이 온다. stick3d_lick.gd 처럼 주제별 파일

const STOOP_T := 0.4                        # 숙여 집는 시간(s)
const SHAKE_T := 0.3                        # 정강이를 터는 시간(s)
const STAND_T := 0.3                        # 일어서는 시간(s)
const TOTAL := STOOP_T + SHAKE_T + STAND_T  # 자세 전체(s) — 선로지기가 이만큼 뒤 차에 오른다
const RISE := 0.15                          # 숙여 들어가는 시간(s)
const BLEND := 0.05                         # 숙임에서 털기로 넘어가는 반폭(s)
const PINCH_HZ := 6.0                       # 천을 집는 손가락
const SHAKE_HZ := 5.0                       # 정강이의 흔들림
const BREATHE_HZ := 0.8
const LEAN := 0.95; const HALF := 0.45      # 숙인 상체·반쯤 일어난 상체(rad)
const DIP := 0.06                           # 숙일 때 골반이 내려오는 높이(m)
const STOOP_HIP := 0.35; const STOOP_KNEE := 0.45
const REACH_SH := 0.55; const REACH_Z := 0.1; const REACH_EL := 0.25; const PINCH := 0.05
const BACK_SH := 0.35; const BACK_EL := 0.2
const LIFT_HIP := 0.5; const LIFT_KNEE := 0.6; const SHAKE := 0.25
const LOOK := 0.55; const LOOK_HALF := 0.2

## 자세에 든 뒤 시간(s) — 선로지기의 메타, 없으면 pose_t
static func since(f: Stick3D) -> float:
	if f.has_meta("clip_t"): return maxf(0.0, float(f.get_meta("clip_t")))
	return f.pose_t

## 다 했나
static func done(f: Stick3D) -> bool:
	return since(f) >= TOTAL

## [a, b] — 숙임의 몫(0.15 에 숙여 0.4 에 넘어간다), 털기의 몫(0.4 에 들어 0.7..1.0 에 내려온다)
static func phases(u: float) -> Array:
	var ta := smoothstep(STOOP_T - BLEND, STOOP_T + BLEND, u)
	var te := smoothstep(TOTAL - STAND_T, TOTAL, u)
	var a := smoothstep(0.0, RISE, u) * (1.0 - ta)
	var b := ta * (1.0 - te)
	return [a, b]

## 상체 — 숙여 발목으로, 털 땐 반쯤; 골반은 숙인 만큼 내려온다
static func lean(f: Stick3D) -> float:
	var ph := phases(since(f)); var a := float(ph[0]); var b := float(ph[1])
	f.pelvis.position.y = StickRig.HIP_Y - DIP * a - 0.02 * b
	return LEAN * a + HALF * b

## 팔다리 — 오른팔(s > 0): 발목으로(−0.55, z −0.1, −0.25) 손가락이 6 Hz 로 집는다 → 놓고 내려온다; 왼팔(s < 0): 뒤로 버틴다(+0.35, −0.2); 오른 다리: 숙임의 접힘 → 들려(−0.5, +0.6) 정강이가 5 Hz 로 흔들린다; 왼 다리: 숙임의 접힘 → 조금 버틴다, 늘 숨쉰다; 고개는 발목을 본다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "clip": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(since(f)); var a := float(ph[0]); var b := float(ph[1])
	var breathe := sin(f._t * TAU * BREATHE_HZ) * 0.03   # 왼 무릎의 숨 — 정지화가 아니다
	var pinch := sin(f._t * TAU * PINCH_HZ) * PINCH * a   # 천을 집는 손가락
	var shake := sin(f._t * TAU * SHAKE_HZ) * SHAKE * b   # 털리는 정강이
	if s > 0.0:
		sh.rotation.x = -REACH_SH * a - 0.15 * b
		sh.rotation.z = -REACH_Z * a
		el.rotation.x = -REACH_EL * a + pinch
		hip.rotation.x = -STOOP_HIP * a - LIFT_HIP * b
		knee.rotation.x = STOOP_KNEE * a + LIFT_KNEE * b + shake
		f.neck.rotation.x += LOOK * a + LOOK_HALF * b   # 발목을 본다
	else:
		sh.rotation.x = BACK_SH * a + 0.1 * b
		sh.rotation.z = 0.0
		el.rotation.x = -BACK_EL * a
		hip.rotation.x = -STOOP_HIP * a
		knee.rotation.x = STOOP_KNEE * a + 0.1 * b + breathe
	return true
