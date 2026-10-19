class_name PedalPoses
extends RefCounted
## 자전거 가족 자세(Climb 콘텐츠 팩 railcar, run 180 — data/climb/railcar.json, scripts/games/climb_railcar.gd; 운영자 보드의 '자전거' 가족의 첫 자세): `pedal` 톱니 궤도차의 안장에 앉아 크랭크를 밟는 몸 — 몸은 궤도가 오르는 쪽(옆)을 보고 차는 x 로 간다.
## 시계는 넷이고 팩이 적는다: meta "pedal_m"(오른 몫 0..1 — 0.45 s 에 다리를 안장 너머로 넘기고 앉는다, 내려설 땐 1 → 0), meta "pedal_k"(밟는 박자 0..1 — 두 발이 크랭크 위를 돈다), meta "pedal_a"(크랭크 각, rad — 팩이 적분한다), meta "pedal_b"(자유바퀴에 버티는 몫 0..1 — 굴러 내릴 때). 메타가 없으면 pose_t 로 혼자 한 바퀴 돈다(점검·주민 시연용: 오름 0.45 s, 밟기 3 s, 내려섬 0.45 s).
## 오름(m 0 → 1): 골반이 안장으로 내려앉고(0.42 → 0.32 m) 두 다리가 크랭크의 자리로 접히며, 넘기는 다리(s > 0)가 한가운데(m 0.5)에 가장 높이 들린다(엉덩이 −0.9·무릎 +1.2 의 산), 두 손이 손잡이로(어깨 −0.95·팔꿈치 −0.35), 상체가 앞으로 0.45
## → 밟기(k 만큼): 두 발이 크랭크 축(골반에서 앞 0.26·아래 0.30 m, 반지름 0.09)을 도는 원 위에 서로 반대로(s < 0 은 반 바퀴 뒤) — 두 관절 다리의 역운동(허벅지 0.26·정강이 0.24)이라 무릎이 꼭대기에서 1.68, 바닥에서 0.71 로 접힌다; 상체가 밟음마다 0.05 흔들리고(2a), 어깨가 돌고(0.06·sin a), 팔꿈치가 조금 당긴다
## → 자유바퀴(b 만큼): 다리는 멎고(각이 그대로) 상체가 뒤로 0.35 버티며 팔꿈치가 0.5 더 당기고 고개가 조금 내려온다 → 내려섬(m 1 → 0): 오름의 거꾸로. 고개는 늘 궤도 위를 본다(−0.3); 0.8 Hz 숨에 골반·무릎·어깨가 조금 흔들린다 — 정지화가 아니다.
## stomp(한 발로 풀무를 구른다)·crank(손으로 윈치를 감는다)·ride(풍차 컵에 선 채 실려 간다)와 다르다: 이건 앉아서 두 발로 바퀴를 돌려 제 몸을 올리는 첫 자세 — 다리가 멎으면 되돌아 내려온다. stick3d_stomp.gd 처럼 주제별 파일

const MOUNT_T := 0.45     # 오름(s) = climb_railcar mount_s
const RIDE_T := 3.0       # 메타 없이 돌 때 밟는 시간(s)
const OFF_T := 0.45       # 내려섬(s) = off_s
const LAP := MOUNT_T + RIDE_T + OFF_T   # 한 바퀴(s) — 메타 없이 돌 때 done
const CAD_HZ := 1.4       # 메타 없이 돌 때 크랭크의 바퀴/s = cad_hz
const SEAT_DROP := 0.10   # 안장에 내려앉는 골반(m) — HIP_Y 0.42 → 0.32
const AXLE_F := 0.26      # 크랭크 축: 골반에서 앞으로(m) = climb_railcar AXLE_F
const AXLE_D := 0.30      # 크랭크 축: 골반에서 아래로(m)
const CRANK_R := 0.09     # 크랭크 반지름(m) = CRANK_R
const SWING_HIP := 0.9    # 넘기는 다리의 산(rad)
const SWING_KNEE := 1.2
const BREATHE_HZ := 0.8

## 오른 몫 0..1 — 팩의 메타, 없으면 pose_t 로 오르고 LAP 끝에 내려선다
static func mount(f: Stick3D) -> float:
	if f.has_meta("pedal_m"): return clampf(float(f.get_meta("pedal_m")), 0.0, 1.0)
	return smoothstep(0.0, MOUNT_T, f.pose_t) * (1.0 - smoothstep(LAP - OFF_T, LAP, f.pose_t))

## 밟는 박자 0..1 — 팩의 메타, 없으면 오른 뒤 0.5 s 에 가득, 내려서기 0.5 s 전에 멎는다
static func cadence(f: Stick3D) -> float:
	if f.has_meta("pedal_k"): return clampf(float(f.get_meta("pedal_k")), 0.0, 1.0)
	return smoothstep(MOUNT_T, MOUNT_T + 0.5, f.pose_t) * (1.0 - smoothstep(LAP - OFF_T - 0.5, LAP - OFF_T, f.pose_t))

## 자유바퀴에 버티는 몫 0..1 — 팩의 메타, 없으면 0
static func brace(f: Stick3D) -> float:
	if f.has_meta("pedal_b"): return clampf(float(f.get_meta("pedal_b")), 0.0, 1.0)
	return 0.0

## 크랭크 각(rad) — 팩의 메타, 없으면 오른 뒤 CAD_HZ 로 돈다
static func angle(f: Stick3D) -> float:
	if f.has_meta("pedal_a"): return float(f.get_meta("pedal_a"))
	return TAU * CAD_HZ * maxf(0.0, f.pose_t - MOUNT_T - 0.25)

## 시간으로 돌 때 끝났나 — 팩이 모는 동안은 팩이 busy 로 비운다
static func done(f: Stick3D) -> bool:
	return not f.has_meta("pedal_m") and not f.has_meta("pedal_k") and not f.has_meta("pedal_a") and not f.has_meta("pedal_b") and f.pose_t >= LAP

## 크랭크 각 a 의 발(축에서 앞 sin a·위 cos a 의 원 위)에 닿는 다리 — [엉덩이, 무릎](rad): 두 관절의 역운동, 무릎은 앞으로 나온다
static func leg(a: float) -> Array:
	var fx := AXLE_F + CRANK_R * sin(a); var fy := -AXLE_D + CRANK_R * cos(a)
	var th := StickRig.THIGH; var sh := StickRig.SHIN
	var d := clampf(sqrt(fx * fx + fy * fy), absf(th - sh) + 0.01, th + sh - 0.01)
	var knee := PI - acos(clampf((th * th + sh * sh - d * d) / (2.0 * th * sh), -1.0, 1.0))
	var beta := atan2(fx, -fy)   # 엉덩이에서 발까지의 선이 수직에서 앞으로 돈 각
	var alpha := acos(clampf((th * th + d * d - sh * sh) / (2.0 * th * d), -1.0, 1.0))   # 그 선에서 허벅지가 더 앞으로 돈 각
	return [-(beta + alpha), knee]

## 골반은 오른 만큼 안장으로 내려앉고 숨에 조금 흔들린다; 상체는 앞으로 숙였다가 밟음마다 흔들리고 자유바퀴엔 뒤로 버틴다
static func lean(f: Stick3D) -> float:
	var m := mount(f); var k := cadence(f); var b := brace(f); var a := angle(f)
	var breathe := sin(f._t * TAU * BREATHE_HZ)
	f.pelvis.position.y = StickRig.HIP_Y - SEAT_DROP * m + 0.01 * breathe * m
	return (0.45 + 0.05 * sin(2.0 * a) * k - 0.35 * b) * m

## 팔다리 — 두 다리: 크랭크 위의 발(s < 0 은 반 바퀴 뒤), 오를 때 넘기는 다리(s > 0)가 한가운데서 들린다, 쉬는 무릎은 숨쉰다; 두 팔: 손잡이로(어깨 −0.95·z 로 조금 벌려·팔꿈치 −0.35), 밟음에 조금 당기고 자유바퀴에 더; 어깨가 밟음에 돌고 고개는 궤도 위를 본다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "pedal": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var m := mount(f); var k := cadence(f); var b := brace(f); var a := angle(f)
	var swing := sin(PI * m) * (1.0 if s > 0.0 else 0.0)                       # 넘기는 다리 — 오를 때와 내려설 때 한가운데서 가장 높이
	var breathe := sin(f._t * TAU * BREATHE_HZ)
	var lg := leg(a + (0.0 if s > 0.0 else PI))
	hip.rotation.x = float(lg[0]) * m - SWING_HIP * swing
	knee.rotation.x = float(lg[1]) * m + SWING_KNEE * swing + 0.03 * breathe * (1.0 - k) * m
	sh.rotation.x = (-0.95 - 0.1 * b) * m + 0.02 * breathe * m
	sh.rotation.z = -s * 0.12 * m
	el.rotation.x = (-0.35 - 0.5 * b + 0.05 * sin(2.0 * a) * k) * m
	if s > 0.0:
		f.torso.rotation.y = 0.06 * sin(a) * k * m                               # 어깨가 밟음에 돈다
		f.neck.rotation.x += (-0.3 + 0.15 * b + 0.03 * sin(2.0 * a) * k) * m   # 궤도 위를 본다, 밟음에 끄덕인다, 버틸 땐 조금 내려온다
	return true
