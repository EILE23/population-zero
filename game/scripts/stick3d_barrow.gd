class_name BarrowPoses
extends RefCounted
## 외바퀴 손수레 가족 자세(Climb 콘텐츠 팩 barrow, run 184 — data/climb/barrow.json, scripts/games/climb_barrow.gd; 운영자 보드의 '외바퀴 손수레' 가족의 첫 자세): `barrow` 발치의 손잡이에 숙여 잡고 다리를 들어, 상체를 밀어 넣고 다리로 밀다, 팔을 어깨 높이로 올리며 엎고, 손을 놓는 몸 — 몸은 미는 쪽(옆)을 보고 수레는 팩이 손 앞에 둔다.
## 시계는 넷이고 팩이 적는다: meta "bar_t"(잡은 몫 0..1 — 0.4 s 에 숙여(0.5 에 가장 깊이) 손잡이를 잡고 들어 올린다, 내려놓을 땐 1 → 0 로 0.3 s), meta "bar_v"(미는 속도 0..1 — 상체가 밀려 들어가고 다리가 민다), meta "bar_k"(엎은 몫 0..1 — 팔이 어깨 높이로 오르고 뒷다리가 버틴다; 세울 땐 1 → 0), meta "bar_x"(놓는 몫 0..1 — 손이 손잡이에서 떨어지며 팔이 튀어 올랐다 내려온다). 메타가 없으면 pose_t 로 혼자 한 바퀴(점검·주민 시연용: 잡기 0.4 s, 밀기 2 s, 엎기 0.6 s, 놓기 0.3 s).
## 잡기(t 0 → 1): 숙임 sin(πt) 에 골반이 DIP 내려앉고 상체가 0.5 숙여 두 팔이 발치의 손잡이로(어깨 −0.45) 무릎이 접히고 고개가 손잡이를 본다 → 들기(hold = smoothstep(0.5, 1, t)): 골반 0.02 내려, 상체가 LEAN_IN 밀려 들어가고, 두 팔이 곧게 뒤 아래 손잡이를 잡는다(어깨 −0.35·z 로 0.12 벌려·팔꿈치 −0.05 — 손이 0.45 m 의 손잡이 끝에), 팔이 4 Hz 로 떤다
## → 밀기(v 만큼): 다리가 1.4 Hz 로 길게(0.45) 밀고 상체가 0.12 더 들어가고 고개가 앞을 본다 → 엎기(k 0 → 1): 팔이 어깨 위로(−1.5) 오르고 상체가 0.35 더 숙이고 왼다리가 뒤로 0.3 버티고 오른 무릎이 0.4 접히고 고개가 통을 본다 → 놓기(x 0 → 1): 잡은 것이 풀리며 팔이 0.3 튀어 올랐다 내려오고 상체가 돌아오며 조금 젖힌다. 0.8 Hz 숨에 골반·무릎이 조금 흔들린다 — 정지화가 아니다.
## lug(배에 안고 걷는다)·shunt(앞의 것을 민다)·heave(줄을 당긴다)와 다르다: 이건 두 손을 뒤 아래로 내려 손잡이를 잡고 바퀴 달린 것을 미는 첫 자세 — 밀 땐 상체가 들어가고, 엎을 땐 팔이 오른다. stick3d_lug.gd 처럼 주제별 파일

const GRIP_T := 0.4       # 잡기(s) = climb_barrow grip_s
const PUSH_T := 2.0       # 메타 없이 돌 때 미는 시간(s)
const TIP_T := 0.6        # 엎기(s) = swing_s
const DROP_T := 0.3       # 놓기(s) = drop_s
const LAP := GRIP_T + PUSH_T + TIP_T + DROP_T   # 한 바퀴(s) — 메타 없이 돌 때 done
const STRIDE_HZ := 1.4
const TREMBLE_HZ := 4.0
const BREATHE_HZ := 0.8
const DIP := 0.1          # 숙임에 골반이 내려앉는 높이(m)
const ARM_X := 0.35       # 잡은 팔: 어깨 앞으로(rad) — 손이 발치 뒤 0.45 m 의 손잡이 끝에
const ARM_Z := 0.12       # 잡은 팔: 옆으로 벌림(rad) — 손잡이 둘의 폭
const LEAN_IN := 0.2      # 미는 상체
const TIP_ARM := 1.5      # 엎을 때 팔이 오르는 높이(rad) — 어깨 위
const TIP_LEAN := 0.35
const BRACE := 0.3        # 엎을 때 뒷다리가 뒤로 버티는 각
const SPRING := 0.3       # 놓을 때 팔이 튀어 오르는 각

## 잡은 몫 0..1 — 팩의 메타, 없으면 pose_t 로 잡는다(놓기는 drop 이 한다)
static func grip(f: Stick3D) -> float:
	if f.has_meta("bar_t"): return clampf(float(f.get_meta("bar_t")), 0.0, 1.0)
	return smoothstep(0.0, GRIP_T, f.pose_t)

## 미는 속도 0..1 — 팩의 메타, 없으면 잡은 뒤 0.3 s 에 가득, 엎기 0.3 s 전에 멎는다
static func speed(f: Stick3D) -> float:
	if f.has_meta("bar_v"): return clampf(float(f.get_meta("bar_v")), 0.0, 1.0)
	return smoothstep(GRIP_T, GRIP_T + 0.3, f.pose_t) * (1.0 - smoothstep(GRIP_T + PUSH_T - 0.3, GRIP_T + PUSH_T, f.pose_t))

## 엎은 몫 0..1 — 팩의 메타, 없으면 밀기 뒤 TIP_T 에 걸쳐
static func tip(f: Stick3D) -> float:
	if f.has_meta("bar_k"): return clampf(float(f.get_meta("bar_k")), 0.0, 1.0)
	return smoothstep(GRIP_T + PUSH_T, GRIP_T + PUSH_T + TIP_T, f.pose_t)

## 놓는 몫 0..1 — 팩의 메타, 없으면 마지막 DROP_T
static func drop(f: Stick3D) -> float:
	if f.has_meta("bar_x"): return clampf(float(f.get_meta("bar_x")), 0.0, 1.0)
	return smoothstep(LAP - DROP_T, LAP, f.pose_t)

## 시간으로 돌 때 끝났나 — 팩이 모는 동안은 팩이 busy 로 비운다
static func done(f: Stick3D) -> bool:
	return not f.has_meta("bar_t") and not f.has_meta("bar_v") and not f.has_meta("bar_k") and not f.has_meta("bar_x") and f.pose_t >= LAP

## [bend, hold] — 숙임(t 0.5 에 1, 0 과 1 에 0), 잡음(t 0.5..1 에 0 → 1)
static func parts(f: Stick3D) -> Array:
	var tt := grip(f)
	return [sin(PI * tt), smoothstep(0.5, 1.0, tt)]

## 골반은 숙임에 내려앉고 잡으면 조금 내려 엎으면 더 내려 숨에 흔들린다; 상체는 숙임에 숙이고 잡으면 밀려 들어가고 엎으면 더 숙이고 놓으면 돌아오며 조금 젖힌다
static func lean(f: Stick3D) -> float:
	var p := parts(f); var bend := float(p[0]); var hold := float(p[1]); var v := speed(f); var k := tip(f); var x := drop(f)
	var breathe := sin(f._t * TAU * BREATHE_HZ)
	f.pelvis.position.y = StickRig.HIP_Y - DIP * bend - 0.02 * hold * (1.0 - x) - 0.05 * k * (1.0 - x) + 0.01 * breathe * hold
	return 0.5 * bend + (LEAN_IN + 0.12 * v) * hold * (1.0 - x) + TIP_LEAN * k * (1.0 - x) - 0.1 * sin(PI * x)

## 팔다리 — 두 다리: 숙임(엉덩이 −0.6·무릎 0.9), 잡고 속도만큼 길게 밀고(1.4 Hz, 0.45) 엎으면 왼다리가 뒤로 버티고 오른 무릎이 접히고 숨쉰다; 두 팔: 숙임에 발치로(−0.45), 잡으면 곧게 뒤 아래 손잡이를(−0.35·z 0.12·팔꿈치 −0.05) 4 Hz 로 떨며, 엎으면 어깨 위로(−1.5), 놓으면 풀려 튀어 올랐다 내려온다; 고개는 손잡이를 보다(숙임 +) 밀면 앞을(−) 엎으면 통을(+) 놓으면 수레를(+)
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "barrow": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var p := parts(f); var bend := float(p[0]); var hold := float(p[1]); var v := speed(f); var k := tip(f); var x := drop(f)
	var grip_k := hold * (1.0 - x)
	var ph := f._t * TAU * STRIDE_HZ
	var breathe := sin(f._t * TAU * BREATHE_HZ)
	var tremble := sin(f._t * TAU * TREMBLE_HZ + s) * 0.015 * grip_k * (1.0 - k)   # 무게의 잔떨림 — 정지화가 아니다
	var stride := s * sin(ph) * 0.45 * v * hold                                   # 앞 = 양수: 두 다리가 번갈아, 길게
	var brace := BRACE * k * (1.0 - x) if s < 0.0 else 0.0                       # 왼다리가 뒤로 버틴다
	hip.rotation.x = -(0.6 * bend + stride) + brace
	knee.rotation.x = 0.9 * bend + 0.1 * hold + (0.15 + 0.4 * maxf(0.0, s * sin(ph + 0.9))) * v * hold + (0.4 if s > 0.0 else 0.1) * k * (1.0 - x) + 0.03 * breathe * hold
	var arm := 0.45 * bend + ARM_X * grip_k + (TIP_ARM - ARM_X) * k * (1.0 - x)
	sh.rotation.x = -arm + tremble - SPRING * sin(PI * x)
	sh.rotation.z = -s * (0.08 * bend + ARM_Z * grip_k)
	el.rotation.x = -(0.1 * bend + 0.05 * grip_k + 0.1 * k * (1.0 - x))
	if s > 0.0: f.neck.rotation.x += 0.45 * bend - 0.1 * v * hold + 0.4 * k * (1.0 - x) + 0.2 * sin(PI * x)   # 손잡이를 보다, 밀면 앞을, 엎으면 통을, 놓으면 수레를
	return true
