class_name SinkPoses
extends RefCounted
## 촛대 계단 가족 자세(Climb 콘텐츠 팩 candle, run 147 — data/climb/candle.json, scripts/games/climb_candle.gd; 운영자 보드의 '무른 바닥·눈밭' 가족, balance 의 다음): `sink` 제 무게로 꺼지는 밀랍 위의 몸 —
## 0.2 무릎이 조금 풀리고 골반이 내려가며 팔이 옆으로 조금 벌어진다(예비) → 유지: 무릎이 자국 깊이만큼 더 접히고 골반이 더 내려앉으며(meta "sink_k" 0..1, 팩의 stand 가 적는다; 없으면 2.4초 주기의 제 박자) 고개가 발밑을 본다;
## 밀랍이 꺼지는 동안(meta "sink_v" 0/1; 없으면 제 박자) 팔이 균형 잡으러 올라가고 몸통이 0.5초 박자로 앞으로 숙였다 다잡으며 서 있으면 자유 발(뒷발)이 0.6초마다 작은 회복 뜀을 친다; 걸으면 보폭이 좁은 조심 걸음(0.5초 한 걸음, 무릎이 접힌 채)
## → 자세가 풀리면 stick3d 의 블렌딩이 팔을 내리고 무릎을 편다(회수).
## balance(발밑이 앞뒤 비탈이 된다 — 몸통이 오르막 쪽으로 기운다)·sway(옆으로 흔들린다)·teeter(디딤돌 — 팔만)와 다르다: 이건 발밑이 수직으로 내려앉는 몸 — 무릎으로 받고 한 발이 뜬다. stick3d_sway.gd 처럼 주제별 파일

const RISE_T := 0.2
const STEP_T := 0.5
const CATCH_T := 0.5
const HOP_T := 0.6
const PERIOD := 2.4

## 풀린 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, RISE_T, f.pose_t)

## 자국 깊이 0..1 — 팩이 적어 준 값, 없으면 제 박자(주민·시연용)
static func depth(f: Stick3D) -> float:
	return clampf(float(f.get_meta("sink_k", 0.5 - 0.5 * cos(f._t * TAU / PERIOD))), 0.0, 1.0)

## 꺼지는 중 0..1 — 팩이 적어 준 값, 없으면 제 박자(깊어지는 반 주기)
static func v(f: Stick3D) -> float:
	return clampf(float(f.get_meta("sink_v", 1.0 if sin(f._t * TAU / PERIOD) > 0.0 else 0.0)), 0.0, 1.0)

static func moving(f: Stick3D) -> bool:
	return f.speed > 0.05 and f.move_dir.length_squared() > 0.0001 and not f.airborne and not f.seated

## 골반이 자국만큼 내려앉고(꺼질 땐 조금 더) 몸통이 꺼지는 동안 박자로 숙였다 다잡는다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var dp := depth(f); var vv := v(f)
	f.pelvis.position.y = StickRig.HIP_Y - (0.04 + 0.06 * dp + 0.03 * vv) * kk
	var catch := 0.5 + 0.5 * sin(f._t * TAU / CATCH_T)
	return (0.08 + 0.12 * vv * catch) * kk

## 팔다리 — 무릎은 자국만큼, 팔은 꺼지는 동안 올라가고, 서 있으면 뒷발이 회복 뜀, 걸을 땐 좁은 조심 걸음. 고개는 발밑을
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "sink": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var dp := depth(f); var vv := v(f)
	if moving(f):
		var a := sin(f._t * TAU / (STEP_T * 2.0)) * s * 0.3   # 좁은 보폭 — 무른 밀랍 위의 조심 걸음
		hip.rotation.x = -(a + 0.1 * kk); knee.rotation.x = -(-(0.55 if a < 0.0 else 0.3) - 0.3 * dp * kk)
	else:
		var hop := maxf(0.0, sin(f._t * TAU / HOP_T)) * vv * kk if s < 0.0 else 0.0   # 뒷발의 회복 뜀 — 꺼지는 동안만
		hip.rotation.x = -(0.15 + 0.25 * dp) * kk - 0.5 * hop; knee.rotation.x = (0.3 + 0.5 * dp) * kk + 0.6 * hop
	sh.rotation.x = -(0.1 * kk); sh.rotation.z = -s * (0.1 + (0.6 + 0.9 * vv) * kk); el.rotation.x = -(0.4 - 0.1 * kk)
	if s > 0.0: f.neck.rotation.x += (0.15 + 0.3 * dp) * kk
	return true
