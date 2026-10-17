class_name JoltPoses
extends RefCounted
## 핀 바퀴 가족 자세(Climb 콘텐츠 팩 escape, run 168 — data/climb/escape.json, scripts/games/climb_escape.gd; 운영자 보드의 '균형' 가족, log 의 다음): `jolt` 한 박자에 한 칸씩 덜컥 가는 바퀴의 핀 위에 선 몸 —
## 0.2 무릎이 조금 내려앉고 두 팔이 옆으로 조금 나간다(예비) → 유지: 덜컥(meta "jolt_t" = 마지막 걸음 뒤 흐른 시간, 팩의 ride 가 적는다; 없으면 0.7 s 의 제 박자)마다 SHOCK_T 의 충격 — 0.09 s 에 치솟아 잦아든다: 무릎이 꺾이고 골반이 내려앉고 두 팔이 위로 튀어 오르며
## 몸통이 핀이 가는 방향의 반대로 쏠리고(meta "jolt_dx" 세상 x −1..1 — 버스에 선 사람처럼) 고개가 번쩍 든다 — 그리고 다음 덜컥까지 숨 쉬듯 무릎이 흔들리고 팔이 내려와 자리를 잡는다(어느 순간도 정지화가 아니다) →
## 핀에서 뛰어 내리면 로더가 자세를 비우고 stick3d 의 블렌딩이 팔을 내린다(회수). ride(컵이 구르듯 실려 간다 — 늘 기운다)·tread(띠에 실려 걷는다)·perch(널에 웅크린다)와 다르다: 이건 멎었다 덜컥, 멎었다 덜컥 하는 바닥을 받는 몸. stick3d_log.gd 처럼 주제별 파일

const BRACE_T := 0.2
const SHOCK_T := 0.35
const PEAK := 0.25        # 충격이 가장 큰 때 — SHOCK_T 의 이 비율(0.0875 s)
const PERIOD := 0.7
const DIP := 0.05         # 무릎이 내려앉아 골반이 낮아지는 높이(m)
const ARM := 0.5          # 팔이 옆으로 나가는 각(rad) — 충격엔 1.1 더

## 벌어진 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, BRACE_T, f.pose_t)

## 마지막 덜컥 뒤 흐른 시간 — 팩이 적어 준 값, 없으면 제 박자(주민·시연용)
static func since(f: Stick3D) -> float:
	return maxf(0.0, float(f.get_meta("jolt_t", fmod(f._t, PERIOD))))

## 충격 0..1 — PEAK 까지 치솟아 SHOCK_T 에 잦아든다
static func shock(f: Stick3D) -> float:
	var u := clampf(since(f) / SHOCK_T, 0.0, 1.0)
	return smoothstep(0.0, PEAK, u) * (1.0 - smoothstep(PEAK, 1.0, u))

## 핀이 가는 쪽을 몸의 앞으로 −1..1 — 세상 x 의 방향(meta)을 보는 방향(yaw, +x 를 보면 sin 이 +)으로 뒤집는다(ride 와 같은 식)
static func fwd(f: Stick3D) -> float:
	var raw := clampf(float(f.get_meta("jolt_dx", 0.4 * sin(f._t * 0.9))), -1.0, 1.0)
	return raw * (1.0 if sin(f._yaw) >= 0.0 else -1.0)

## 골반은 조금 내려앉아 충격에 더 내려앉고 숨 쉬듯 흔들린다; 몸통은 충격에 가는 방향의 반대로 쏠린다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var a := shock(f)
	f.pelvis.position.y = StickRig.HIP_Y - (DIP + 0.08 * a + 0.01 * sin(f._t * 4.0)) * kk
	return (-0.3 * fwd(f) * a + 0.03 * sin(f._t * 2.1)) * kk

## 팔다리 — 무릎은 조금 굽힌 채 충격에 꺾이고, 팔은 옆으로 조금 나간 채 충격에 위로 튄다; 고개는 발밑을 보다 충격에 번쩍 든다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "jolt": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var a := shock(f); var breath := sin(f._t * 4.0 + s * 0.5)
	hip.rotation.x = -(0.2 + 0.45 * a + 0.02 * breath) * kk; hip.rotation.z = 0.0
	knee.rotation.x = (0.35 + 0.9 * a + 0.03 * breath) * kk
	sh.rotation.z = -s * (0.12 + (ARM + 1.1 * a) * kk)
	sh.rotation.x = -(0.1 + 0.5 * a) * kk + 0.02 * sin(f._t * 2.1 + s) * kk
	el.rotation.x = -(0.35 + 0.3 * a) * kk
	if s > 0.0:
		f.neck.rotation.x += (0.15 - 0.35 * a) * kk; f.chest.rotation.x += 0.05 * a * kk
	return true
