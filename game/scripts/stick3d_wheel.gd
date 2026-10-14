class_name WheelPoses
extends RefCounted
## 돌아서기 자세(Climb 팩 hurdle 의 주민 반쪽 — 허들러, run 156; 운영자 보드의 '달리기·허들' 가족의 둘째 자세): `wheel` 줄 끝에서 멈춰 제자리에서 반 바퀴 돌아서는 몸 —
## 회전문의 turn(손잡이를 밀며 도는 몸)과 다르다: 이건 빈손으로 발을 디뎌 몸을 돌리는 한 번. 몸의 yaw 는 Stick3D 가 face() 로 10 rad/s 로 돌리니 자세는 그 위에 발·팔·고개를 입힌다.
## 디딤(0..0.4): 바깥발(오른쪽)이 옆으로 넓게 디디며 무릎이 내려앉고 두 팔이 옆으로 벌어진다 → 휘돌기(0.25..0.75): 왼다리가 앞으로 가로질러 나가고, 팔은 한쪽 앞·한쪽 뒤로 쓸리며 고개가 먼저 돌아간다(look_yaw) → 모음(0.7..1.0): 발이 모이고 팔이 내려오며 골반이 한 번 튄다.
## 팔은 잔떨림(10 Hz)으로 어느 순간도 정지화가 아니다. 한 번은 WHEEL_T; 끝나면 done — 팩이 pose_request 를 비운다. stick3d_hurdle.gd 처럼 주제별 파일

const WHEEL_T := 0.5      # 한 번 돌아서는 데 드는 시간(s) — 걷다 서서 반 바퀴
const DIP := 0.08         # 디딤에 골반이 내려앉는 높이(m)

## 자세에 든 정도 0..1(시간)
static func at(f: Stick3D) -> float:
	return clampf(f.pose_t / WHEEL_T, 0.0, 1.0)

static func done(f: Stick3D) -> bool:
	return f.pose_t >= WHEEL_T

## [plant, swing, settle] — 디딤(0.4 까지 한 번 내려앉았다 선다), 휘돌기(0.25 에 올라 0.5 까지 다 돌고 0.95 에 내려온다), 모음(0.7..1.0 에 한 번 튄다)
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var plant := sin(clampf(u / 0.4, 0.0, 1.0) * PI)
	var swing := smoothstep(0.25, 0.5, u) * (1.0 - smoothstep(0.7, 0.95, u))
	var settle := sin(clampf((u - 0.7) / 0.3, 0.0, 1.0) * PI)
	return [plant, swing, settle]

## 골반은 디딤에 DIP 만큼 내려앉고 모음에 살짝 튄다; 몸통은 디딤·휘돌기에 조금 앞으로. 고개가 먼저 돈다(look_yaw — 휘돌기 동안 도는 쪽을 본다)
static func lean(f: Stick3D) -> float:
	var ph := phases(f); var plant := float(ph[0]); var swing := float(ph[1]); var settle := float(ph[2])
	f.pelvis.position.y = StickRig.HIP_Y - DIP * plant + 0.03 * settle
	f.look_yaw = -0.9 * swing
	return 0.14 * plant + 0.1 * swing

## 팔다리 — 바깥발(s > 0): 옆으로 넓게 디뎠다(엉덩이 z) 휘돌기에 뒤로 물러서고 모음에 선다; 안쪽 다리(s < 0): 휘돌기에 앞으로 가로질러 나가며 무릎을 들고 모음에 내려선다;
## 팔: 디딤에 둘 다 옆으로 벌어지고 휘돌기에 오른팔 뒤·왼팔 앞으로 쓸리며 모음에 내려온다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "wheel": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(f); var plant := float(ph[0]); var swing := float(ph[1]); var settle := float(ph[2])
	var wob := sin(f._t * 10.0) * 0.04   # 팔의 잔떨림 — 정지화가 아니다
	if s > 0.0:
		hip.rotation.x = 0.15 * plant + 0.35 * swing - 0.05 * settle          # 바깥발 — 디딤에 조금, 휘돌기에 뒤로 물러선다
		hip.rotation.z = -s * (0.45 * plant + 0.15 * swing)                    # 옆으로 넓게
		knee.rotation.x = 0.6 * plant + 0.3 * swing + 0.15 * settle
		sh.rotation.x = 0.7 * swing + 0.1 * plant + wob                        # 오른팔 뒤로
		sh.rotation.z = -s * (0.15 + 0.8 * plant + 0.3 * swing)                # 벌어진다
		el.rotation.x = -(0.3 + 0.3 * plant + 0.2 * swing)
		f.chest.rotation.x += 0.05 * swing
	else:
		hip.rotation.x = -(0.7 * swing) + 0.05 * plant + 0.1 * settle        # 안쪽 다리 — 앞으로 가로질러 나간다
		hip.rotation.z = 0.0
		knee.rotation.x = 0.9 * swing + 0.2 * plant + 0.2 * settle            # 무릎을 들어 넘긴다
		sh.rotation.x = -(0.6 * swing) - 0.1 * plant - wob                     # 왼팔 앞으로
		sh.rotation.z = -s * (0.15 + 0.8 * plant + 0.2 * swing)
		el.rotation.x = -(0.3 + 0.3 * plant + 0.35 * swing)
	return true
