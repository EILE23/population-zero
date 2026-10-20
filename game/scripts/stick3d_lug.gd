class_name LugPoses
extends RefCounted
## 상자·가구 나르기 가족 자세(Climb 콘텐츠 팩 crate, run 182 — data/climb/crate.json, scripts/games/climb_crate.gd; 운영자 보드의 '상자·가구 나르기' 가족의 첫 자세): `lug` 발치의 이삿짐 상자를 쪼그려 잡아 배에 안고 일어서서, 안은 채 짧게 걷다 앞에 내려놓는 몸 — 몸은 걷는 쪽(옆)을 보고 상자는 몸(torso)의 자식으로 함께 가고 기운다.
## 시계는 셋이고 팩이 적는다: meta "lug_t"(든 몫 0..1 — 0.5 s 에 쪼그려(0.5 에 가장 깊이) 잡아 안고 일어선다, 내려놓을 땐 1 → 0 로 0.4 s), meta "lug_v"(걷는 속도 0..1 — 안은 채 짧은 걸음), meta "lug_x"(미끄러짐 0..1 — 상자가 손에서 빠져 팔이 앞으로 들렸다 내려온다; 그동안 lug_t 는 1). 메타가 없으면 pose_t 로 혼자 한 바퀴(점검·주민 시연용: 들기 0.5 s, 안고 걷기 2 s, 내려놓기 0.4 s).
## 들기(t 0 → 1): 쪼그림 sin(πt) 에 골반이 DIP 내려앉고 상체가 0.7 숙여 두 팔이 발치의 상자로 곧게 내려가고(어깨 −0.5) 고개가 상자를 본다 → 안기(hold = smoothstep(0.5, 1, t)): 골반 0.02 내려, 상체가 무게에 0.12 뒤로 버티고, 두 팔이 상자 옆을 안는다(어깨 −0.94·z 로 0.75 벌려·팔꿈치 −0.1 — 손이 0.72 m 상자의 밧줄 손잡이에), 팔이 6 Hz 로 떨고 무릎이 조금 굽는다
## → 걷기(v 만큼): 다리가 1.6 Hz 로 짧게(0.3) 걷고 상체가 걸음에 0.03 흔들린다 → 내려놓기(t 1 → 0): 들기의 거꾸로 → 미끄러짐(x 0 → 1): 안은 팔이 풀리며 앞으로 0.5 들렸다 내려오고 상체가 0.2 앞으로 쏠리고 고개가 떨어지는 상자를 본다. 0.8 Hz 숨에 골반·무릎이 조금 흔들린다 — 정지화가 아니다.
## shunt(앞의 것을 민다)·heave(줄을 당긴다)·press(머리 위에 버틴다)·carry(마을의 작은 것을 허리 높이에)와 다르다: 이건 무거운 것을 배에 안고 걷는 첫 자세 — 들 때 쪼그리고, 안으면 뒤로 버틴다. stick3d_pedal.gd 처럼 주제별 파일

const LIFT_T := 0.5       # 들기(s) = climb_crate lift_s
const CARRY_T := 2.0      # 메타 없이 돌 때 안고 걷는 시간(s)
const SET_T := 0.4        # 내려놓기(s) = set_s
const LAP := LIFT_T + CARRY_T + SET_T   # 한 바퀴(s) — 메타 없이 돌 때 done
const STRIDE_HZ := 1.6
const TREMBLE_HZ := 6.0
const BREATHE_HZ := 0.8
const DIP := 0.25         # 쪼그림에 골반이 내려앉는 높이(m)
const ARM_X := 0.94       # 안은 팔: 어깨 앞으로(rad) — 손이 골반 위 0.2 m 의 손잡이에(climb_crate HOLD_Y)
const ARM_Z := 0.75       # 안은 팔: 옆으로 벌림(rad) — 손이 0.72 m 상자의 옆면에

## 든 몫 0..1 — 팩의 메타, 없으면 pose_t 로 들고 LAP 끝에 내려놓는다
static func lift(f: Stick3D) -> float:
	if f.has_meta("lug_t"): return clampf(float(f.get_meta("lug_t")), 0.0, 1.0)
	return smoothstep(0.0, LIFT_T, f.pose_t) * (1.0 - smoothstep(LAP - SET_T, LAP, f.pose_t))

## 걷는 속도 0..1 — 팩의 메타, 없으면 든 뒤 0.3 s 에 가득, 내려놓기 0.3 s 전에 멎는다
static func speed(f: Stick3D) -> float:
	if f.has_meta("lug_v"): return clampf(float(f.get_meta("lug_v")), 0.0, 1.0)
	return smoothstep(LIFT_T, LIFT_T + 0.3, f.pose_t) * (1.0 - smoothstep(LAP - SET_T - 0.3, LAP - SET_T, f.pose_t))

## 미끄러짐 0..1 — 팩의 메타, 없으면 0
static func slip(f: Stick3D) -> float:
	if f.has_meta("lug_x"): return clampf(float(f.get_meta("lug_x")), 0.0, 1.0)
	return 0.0

## 시간으로 돌 때 끝났나 — 팩이 모는 동안은 팩이 busy 로 비운다
static func done(f: Stick3D) -> bool:
	return not f.has_meta("lug_t") and not f.has_meta("lug_v") and not f.has_meta("lug_x") and f.pose_t >= LAP

## [sq, hold] — 쪼그림(t 0.5 에 1, 0 과 1 에 0), 안음(t 0.5..1 에 0 → 1)
static func parts(f: Stick3D) -> Array:
	var tt := lift(f)
	return [sin(PI * tt), smoothstep(0.5, 1.0, tt)]

## 골반은 쪼그림에 깊이 내려앉고 안으면 조금 내려 숨에 흔들린다; 상체는 쪼그림에 숙이고 안으면 뒤로 버티며 걸음에 흔들리고 미끄러지면 앞으로 쏠린다
static func lean(f: Stick3D) -> float:
	var p := parts(f); var sq := float(p[0]); var hold := float(p[1]); var v := speed(f); var x := slip(f)
	var breathe := sin(f._t * TAU * BREATHE_HZ)
	f.pelvis.position.y = StickRig.HIP_Y - DIP * sq - 0.02 * hold + 0.01 * breathe * hold
	return 0.7 * sq - 0.12 * hold * (1.0 - x) + 0.03 * sin(f._t * TAU * STRIDE_HZ * 2.0) * v * hold + 0.2 * sin(PI * x)

## 팔다리 — 두 다리: 쪼그림(엉덩이 −1.1·무릎 1.5), 안은 채 속도만큼 짧게 걷고(1.6 Hz, 0.3) 무릎이 무게에 조금 굽고 숨쉰다; 두 팔: 쪼그림에 발치로 곧게(−0.5), 안으면 상자 옆을 안고(−0.94·z 0.75·팔꿈치 −0.1) 6 Hz 로 떨며, 미끄러지면 풀려 앞으로 들렸다 내려온다; 고개는 상자를 보다(쪼그림 +) 안으면 상자 너머를(−) 미끄러지면 떨어지는 상자를(+)
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "lug": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var p := parts(f); var sq := float(p[0]); var hold := float(p[1]); var v := speed(f); var x := slip(f)
	var grip := hold * (1.0 - x)
	var ph := f._t * TAU * STRIDE_HZ
	var breathe := sin(f._t * TAU * BREATHE_HZ)
	var tremble := sin(f._t * TAU * TREMBLE_HZ + s) * 0.02 * grip                       # 무게의 잔떨림 — 정지화가 아니다
	var stride := s * sin(ph) * 0.3 * v * hold                                         # 앞 = 양수: 두 다리가 번갈아, 짧게
	hip.rotation.x = -(1.1 * sq + stride)
	knee.rotation.x = 1.5 * sq + 0.08 * hold + (0.15 + 0.35 * maxf(0.0, s * sin(ph + 0.9))) * v * hold + 0.03 * breathe * hold
	sh.rotation.x = -(0.5 * sq + ARM_X * grip) + tremble - 0.5 * sin(PI * x)
	sh.rotation.z = -s * (0.1 * sq + ARM_Z * grip)
	el.rotation.x = -(0.15 * sq + 0.1 * grip) + tremble
	if s > 0.0: f.neck.rotation.x += 0.5 * sq - 0.15 * grip + 0.3 * sin(PI * x)   # 상자를 보다, 안으면 상자 너머를, 미끄러지면 떨어지는 상자를
	return true
