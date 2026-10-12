class_name BalancePoses
extends RefCounted
## 시소 화분 가족 자세(Climb 콘텐츠 팩 planter, run 146 — data/climb/planter.json, scripts/games/climb_planter.gd; 운영자 보드의 '외줄·평균대' 가족, sway·teeter 의 다음): `balance` 제 무게로 기우는 비탈 위의 몸 —
## 0.2 두 팔이 옆으로 벌어지고 무릎이 느슨해지며 골반이 조금 내려간다(예비) → 유지: 몸통이 앞 비탈의 오르막 쪽으로 기울고(meta "balance_k" −1..1, + 면 앞이 오르막, 팩의 stand 가 적는다; 없으면 2.4초 주기의 제 박자) 고개는 내리막에선 발밑, 오르막에선 앞을;
## 화분이 기우는 동안(meta "balance_v" 0..1, 기우는 속도; 없으면 제 박자) 무릎이 더 접히고 팔이 더 올라가며 서 있으면 0.25초 박자의 잔걸음으로 고쳐 선다; 걸으면 보폭이 좁은 조심 걸음(0.5초 한 걸음, 무릎이 접힌 채)
## → 자세가 풀리면 stick3d 의 블렌딩이 팔을 내린다(회수).
## sway(발밑이 옆으로 흔들린다 — 골반째 옆으로 기운다)·teeter(디딤돌 — 팔만 오르내린다)와 다르다: 이건 발밑이 앞뒤 비탈이 되는 몸 — 몸통이 앞뒤로 기울고 발이 잔걸음을 친다. stick3d_sway.gd 처럼 주제별 파일

const RISE_T := 0.2
const STEP_T := 0.5
const SHUFFLE_T := 0.25
const PERIOD := 2.4

## 벌어진 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, RISE_T, f.pose_t)

## 앞 비탈 −1..1(+ 오르막) — 팩이 적어 준 값, 없으면 제 박자(주민·시연용)
static func tilt(f: Stick3D) -> float:
	return clampf(float(f.get_meta("balance_k", sin(f._t * TAU / PERIOD) * 0.5)), -1.0, 1.0)

## 기우는 속도 0..1 — 팩이 적어 준 값, 없으면 제 박자(비탈이 바뀌는 만큼)
static func v(f: Stick3D) -> float:
	return clampf(float(f.get_meta("balance_v", absf(cos(f._t * TAU / PERIOD)) * 0.5)), 0.0, 1.0)

static func moving(f: Stick3D) -> bool:
	return f.speed > 0.05 and f.move_dir.length_squared() > 0.0001 and not f.airborne and not f.seated

## 골반이 조금 내려앉고(기울 땐 더) 몸통이 오르막 쪽으로 기운다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var tl := tilt(f); var vv := v(f)
	f.pelvis.position.y = StickRig.HIP_Y - (0.05 + 0.03 * vv) * kk
	return (0.1 + 0.3 * tl) * kk

## 팔다리 — 무릎 느슨(기울 땐 더), 팔은 옆으로 벌려 기울 땐 더 올린다, 서 있으면 기우는 동안 잔걸음, 걸을 땐 좁은 조심 걸음. 고개는 내리막에선 발밑, 오르막에선 앞
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "balance": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var tl := tilt(f); var vv := v(f)
	if moving(f):
		var a := sin(f._t * TAU / (STEP_T * 2.0)) * s * 0.3   # 좁은 보폭 — 흙 위의 조심 걸음
		hip.rotation.x = -(a + 0.1 * kk); knee.rotation.x = -(-(0.55 if a < 0.0 else 0.3) - 0.2 * kk)
	else:
		var sh_step := sin(f._t * TAU / SHUFFLE_T) * s * 0.12 * vv   # 잔걸음 — 기우는 동안만
		hip.rotation.x = -(0.2 * kk + sh_step); knee.rotation.x = (0.4 + 0.25 * vv) * kk
	sh.rotation.x = -(0.1 * kk); sh.rotation.z = -s * (0.1 + (1.25 + 0.3 * vv) * kk); el.rotation.x = -(0.3 - 0.1 * kk)
	if s > 0.0: f.neck.rotation.x += (0.25 - 0.2 * tl) * kk
	return true
