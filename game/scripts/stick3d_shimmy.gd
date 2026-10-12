class_name ShimmyPoses
extends RefCounted
## 빨랫줄 가족 자세(Climb 콘텐츠 팩 laundry, run 143 — data/climb/laundry.json, scripts/games/climb_laundry.gd; 운영자 보드의 '매달리기·철봉' 가족 — 두 손으로 줄을 번갈아 쥐고 가는 몸): `shimmy` 빨랫줄에 매달려 손을 옮겨 가는 몸 —
## 0.2 두 팔이 머리 위로 올라가 줄을 쥐고(조금 벌려 — 가로대를 넓게 쥐는 zip 보다 좁고 fly 보다 조금 넓다) 다리가 발목을 꼬아 늘어지며 골반이 조금 오른다(예비) → 유지, 팩이 적는 메타로:
## 속도("shimmy_v" −1..1, +면 +x 로 간다; 없으면 4초 주기의 제 박자)와 손 번갈음("shimmy_ph" 0..1, stride 마다 한 바퀴): 앞 손이 줄을 따라 뻗고 뒤 손이 팔꿈치를 접어 당긴다 — 손이 바뀔 때마다 꼰 다리가 같이 흔들린다; 멈추면 두 손이 나란하고 다리는 느리게 흔들린다;
## 이불("shimmy_sheet" 0..1): 천이 얼굴로 펄럭여 들어 고개가 가는 쪽 반대로 돌고 조금 숙는다;
## 덮임("shimmy_hood" 0..1): 집게가 튀어 이불이 머리를 덮었다 — 고개가 천 속으로 숙고 돌지 않는다, 손은 그대로 간다;
## 눈먼 걸음("shimmy_walk" 0..1, 내려선 뒤 hood_s 에 걸쳐): 두 손이 얼굴의 천을 번갈아 당겨 벗고 발이 잰 걸음으로 더듬으며 몸통이 숙는다 — 끝나면 로더가 자세를 비우고 stick3d 의 블렌딩이 몸을 편다(회수).
## 몸이 보는 쪽(f._yaw)으로 '앞'을 읽는다. 메타가 없으면 4초 한 바퀴의 제 박자(3.2 손 옮기기, 1.2..1.8 에 이불이 얼굴로; 주민·시연용).
## zip(두 손을 벌려 가로대를 쥐고 비탈을 미끄러진다)·fly(그네를 펌프질한다)·dangle(흔들리는 가로대)과 다르다: 이건 손이 제 걸음을 내는 몸, 빠르기가 손의 것이다. stick3d_zip.gd 처럼 주제별 파일

const GRAB_T := 0.2
const LAP := 4.0          # 제 박자 한 바퀴
const MOVE_T := 3.2       # 제 박자의 손 옮기기
const STRIDE_HZ := 110.0 / 24.0   # 제 박자의 손 번갈음(pace / stride)
const HANG_HIP := 0.3     # 엉덩이: 늘어진 다리의 작은 앞기울기
const HANG_KNEE := 0.45   # 무릎: 살짝 접힌 다리
const CROSS := 0.14       # 엉덩이(옆으로): 발목을 꼰 다리
const REACH := 0.3        # 앞 손이 줄을 따라 더 뻗는 만큼(rad)

## 잡은 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, GRAB_T, f.pose_t)

## 세상 x 의 속도 −1..1 — 팩이 적어 준 값, 없으면 제 박자(손 옮기는 동안 1)
static func raw(f: Stick3D) -> float:
	if f.has_meta("shimmy_v"): return clampf(float(f.get_meta("shimmy_v")), -1.0, 1.0)
	return 1.0 if fmod(f._t, LAP) < MOVE_T else 0.0

## 몸 앞쪽으로 가는 방향 ±1 — 속도의 부호를 보는 방향(yaw, +x 를 보면 sin 이 +)으로 뒤집는다(속도 0 이면 앞)
static func dirn(f: Stick3D) -> float:
	var r := raw(f)
	return (1.0 if r >= 0.0 else -1.0) * (1.0 if sin(f._yaw) >= 0.0 else -1.0)

## 빠르기 0..1
static func spd(f: Stick3D) -> float:
	return absf(raw(f))

## 손 번갈음 0..1 — 팩이 적어 준 값, 없으면 제 박자
static func ph(f: Stick3D) -> float:
	if f.has_meta("shimmy_ph"): return fposmod(float(f.get_meta("shimmy_ph")), 1.0)
	return fposmod(f._t * STRIDE_HZ, 1.0) if fmod(f._t, LAP) < MOVE_T else 0.0

## 얼굴에 든 이불 0..1 — 팩이 적어 준 값, 없으면 제 박자(1.2..1.8)
static func sheet(f: Stick3D) -> float:
	if f.has_meta("shimmy_sheet"): return clampf(float(f.get_meta("shimmy_sheet")), 0.0, 1.0)
	var q := fmod(f._t, LAP)
	return 1.0 if (q >= 1.2 and q < 1.8) else 0.0

## 머리를 덮은 이불 0..1
static func hood(f: Stick3D) -> float:
	if f.has_meta("shimmy_hood"): return clampf(float(f.get_meta("shimmy_hood")), 0.0, 1.0)
	return 0.0

## 눈먼 걸음 0..1 — 0 이면 매달린 몸
static func walk(f: Stick3D) -> float:
	if f.has_meta("shimmy_walk"): return clampf(float(f.get_meta("shimmy_walk")), 0.0, 1.0)
	return 0.0

## 골반이 조금 오르고(매달린 몸) 몸통은 가는 쪽으로 조금 기울며 손이 바뀔 때마다 흔들린다; 눈먼 걸음엔 천 속에서 앞으로 숙는다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var w := walk(f)
	f.pelvis.position.y = StickRig.HIP_Y + 0.04 * kk * (1.0 - w)
	var hang_l := dirn(f) * 0.12 * spd(f) + 0.03 * sin(TAU * ph(f))
	return (hang_l * (1.0 - w) + 0.3 * w) * kk

## 팔다리 — 두 팔은 머리 위 줄에, 앞 손이 뻗고 뒤 손이 당긴다(번갈음); 다리는 발목을 꼰 채 손이 바뀔 때마다 흔들린다; 고개는 손을 올려다보다 이불이 들면 돌리고 덮이면 천 속으로 숙는다; 눈먼 걸음엔 두 손이 얼굴의 천을 당기고 발이 더듬는다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "shimmy": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var w := walk(f); var sp := spd(f); var dn := dirn(f)
	var p := ph(f); var shk := sheet(f); var hd := hood(f)
	var ra := sin(TAU * p) * (1.0 if s > 0.0 else -1.0)   # +면 이 손이 앞으로 뻗는 차례
	var swing := 0.2 * sin(TAU * p) * sp + 0.12 * sin(f._t * 3.0)
	# 매달린 몸
	var hip_h := HANG_HIP + swing; var knee_h := HANG_KNEE
	var sh_h := 0.1 + 2.7 * kk + REACH * ra * sp * dn * kk; var shz_h := 0.1 + 0.25 * kk; var el_h := 0.3 - 0.1 * kk + 0.25 * maxf(0.0, -ra) * sp * kk
	# 눈먼 걸음 — 잰 걸음으로 더듬고 두 손이 얼굴의 천을 번갈아 당긴다
	var step := sin(f._t * 7.0 + (0.0 if s > 0.0 else PI))
	var hip_w := 0.22 * step; var knee_w := 0.35 + 0.2 * maxf(0.0, step)
	var sh_w := 1.9 + 0.25 * sin(f._t * 9.0 + (0.0 if s > 0.0 else PI)); var shz_w := 0.3; var el_w := 1.9
	hip.rotation.x = -(lerpf(hip_h, hip_w, w) * kk)
	hip.rotation.z = s * CROSS * kk * (1.0 - w)
	knee.rotation.x = lerpf(knee_h, knee_w, w) * kk
	sh.rotation.x = -lerpf(sh_h, sh_w, w); sh.rotation.z = -s * lerpf(shz_h, shz_w, w); el.rotation.x = -lerpf(el_h, el_w, w)
	if s > 0.0:
		var look := (0.1 - 0.25 * shk) * (1.0 - hd) + 0.45 * hd   # 손을 올려다보다 이불엔 숙고 덮이면 천 속으로
		f.neck.rotation.x += (look * (1.0 - w) + 0.4 * (1.0 - 0.5 * w) * w) * kk
		f.neck.rotation.y += -dn * 0.5 * shk * (1.0 - hd) * (1.0 - w) * kk
	return true
