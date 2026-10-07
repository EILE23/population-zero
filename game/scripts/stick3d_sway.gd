class_name SwayPoses
extends RefCounted
## 밧줄 다리 가족 자세(Climb 콘텐츠 팩 bridge, run 121 — data/climb/bridge.json, scripts/games/climb_bridge.gd; 운영자 보드의 '외줄·평균대' 가족, teeter 의 다음): `sway` 흔들리는 바닥 위의 몸 —
## 0.2 두 팔이 옆으로 벌어지고 무릎이 느슨해지며 골반이 조금 내려간다(예비) → 유지: 골반이 다리의 흔들림(meta "sway_k", 팩의 stand 가 적는다; 없으면 1.2초 주기의 제 박자)을 따라 좌우로 기울고
## 몸통은 그걸 거슬러 세우며 낮아지는 쪽 팔이 올라가 무게를 잡는다, 고개는 발밑; 걸으면 보폭이 좁은 조심 걸음(0.5초 한 걸음, 무릎이 접힌 채) → 자세가 풀리면 stick3d 의 블렌딩이 팔을 내린다(회수).
## teeter(디딤돌, 서서 시소처럼 팔만 오르내린다)와 다르다: 이건 발밑이 움직이는 몸 — 골반째 기운다. stick3d_lurch.gd 처럼 주제별 파일

const RISE_T := 0.2
const STEP_T := 0.5
const PERIOD := 1.2

## 벌어진 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, RISE_T, f.pose_t)

## 바닥의 흔들림 −1..1 — 팩이 적어 준 값, 없으면 제 박자(주민·시연용)
static func swing(f: Stick3D) -> float:
	return clampf(float(f.get_meta("sway_k", sin(f._t * TAU / PERIOD) * 0.5)), -1.0, 1.0)

static func moving(f: Stick3D) -> bool:
	return f.speed > 0.05 and f.move_dir.length_squared() > 0.0001 and not f.airborne and not f.seated

## 골반째 기울고(+z 돌림 = 오른쪽이 뜬다) 조금 내려앉는다; 몸통은 발밑을 보느라 살짝 숙인다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var sw := swing(f)
	f.pelvis.rotation.z = 0.1 * sw * kk
	f.pelvis.position.y = StickRig.HIP_Y - 0.05 * kk
	return 0.12 * kk + 0.02 * sin(f._t * 2.0) * kk

## 팔다리 — 무릎 느슨(낮아지는 쪽이 더 접힌다), 팔은 옆으로 벌려 낮아지는 쪽이 올라간다, 걸을 땐 좁은 조심 걸음. 고개는 발밑
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "sway": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var sw := swing(f)
	var low := -sw * s   # 이쪽이 낮아지는 정도 −1..1 (골반 +z 돌림이면 왼쪽(s −1)이 내려간다)
	if moving(f):
		var a := sin(f._t * TAU / (STEP_T * 2.0)) * s * 0.3   # 좁은 보폭 — 판자 하나에 한 걸음
		hip.rotation.x = -(a + 0.1 * kk); knee.rotation.x = -(-(0.55 if a < 0.0 else 0.3) - 0.2 * kk)
	else:
		hip.rotation.x = -(0.2 * kk); knee.rotation.x = -(-(0.45 + 0.15 * low) * kk)
	sh.rotation.x = -(0.1 * kk); sh.rotation.z = -s * (0.1 + (1.3 + 0.35 * low) * kk); el.rotation.x = -(0.35 - 0.1 * kk)
	if s > 0.0: f.neck.rotation.x += 0.3 * kk
	return true
