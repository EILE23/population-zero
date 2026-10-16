class_name TiptoePoses
extends RefCounted
## 외줄 가족 자세(Climb 콘텐츠 팩 tightrope, run 164 — data/climb/tightrope.json, scripts/games/climb_tightrope.gd; 운영자 보드의 '외줄·평균대' 가족, teeter·sway 의 다음): `tiptoe` 외줄 위의 몸 —
## 0.2 두 팔이 어깨 높이로 수평히 벌어지고 뒤꿈치가 들려 골반이 조금 오르며 한 발이 다른 발 앞에 한 줄로 선다(예비) → 유지: 골반이 몸의 벗어남(meta "tiptoe_k" −1..1 = 벗어남 / 떨어지는 값, 팩의 stand 가 적는다; 없으면 1.6초 주기의 제 박자)을 따라 절벽 쪽·바깥 쪽으로 기울고
## 낮아지는 쪽 팔이 올라가 무게를 잡으며, 팔은 6 Hz 로 잘게 떨린다(어느 순간도 정지화가 아니다), 고개는 밧줄을 본다; 걸으면 발을 한 줄로 바꿔 디디는 좁은 걸음(0.5초 한 걸음, 다리는 곧게) → 자세가 풀리면 stick3d 의 블렌딩이 팔을 내린다(회수).
## sway(흔들리는 바닥 — 무릎이 느슨하고 발이 벌어진다)·teeter(디딤돌 — 서서 팔만)와 다르다: 이건 다리를 곧게 편 채 발끝으로 한 줄에 서서 제 몸의 기울기와 싸우는 몸. stick3d_sway.gd 처럼 주제별 파일

const RISE_T := 0.2
const STEP_T := 0.5
const PERIOD := 1.6
const TREMOR_HZ := 6.0
const LIFT := 0.03        # 뒤꿈치가 들려 골반이 오르는 높이(m)
const ROLL := 0.22        # 벗어남 1 에서 골반이 기우는 각(rad) — sway 의 0.1 보다 크다: 밧줄은 몸이 기운다

## 벌어진 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, RISE_T, f.pose_t)

## 몸의 벗어남 −1..1 — 팩이 적어 준 값, 없으면 제 박자(주민·시연용)
static func off(f: Stick3D) -> float:
	return clampf(float(f.get_meta("tiptoe_k", sin(f._t * TAU / PERIOD) * 0.4)), -1.0, 1.0)

static func moving(f: Stick3D) -> bool:
	return f.speed > 0.05 and f.move_dir.length_squared() > 0.0001 and not f.airborne and not f.seated

## 골반째 기울고(+z 돌림 = 오른쪽이 뜬다) 뒤꿈치가 들려 조금 오른다(잘게 떨리며); 몸통은 발밑을 보느라 살짝 숙인다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var sw := off(f)
	f.pelvis.rotation.z = ROLL * sw * kk
	f.pelvis.position.y = StickRig.HIP_Y + (LIFT + 0.006 * sin(f._t * TAU * TREMOR_HZ * 0.5)) * kk
	return 0.1 * kk + 0.015 * sin(f._t * 3.0) * kk

## 팔다리 — 다리는 곧게, 발은 한 줄(서면 오른발 앞·왼발 뒤, 걸으면 번갈아 앞으로), 팔은 수평으로 벌려 낮아지는 쪽이 올라가고 잘게 떨린다. 고개는 밧줄
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "tiptoe": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var sw := off(f)
	var low := -sw * s   # 이쪽이 낮아지는 정도 −1..1 (골반 +z 돌림이면 왼쪽(s −1)이 내려간다)
	var tremor := sin(f._t * TAU * TREMOR_HZ + s) * 0.03
	if moving(f):
		var a := sin(f._t * TAU / (STEP_T * 2.0)) * s * 0.35   # 한 줄 걸음 — 발이 번갈아 앞으로, 무릎은 거의 곧게
		hip.rotation.x = -(a + 0.05 * kk); knee.rotation.x = (0.22 if a < 0.0 else 0.08) * kk
	else:
		hip.rotation.x = -((0.3 if s > 0.0 else -0.1) * kk); knee.rotation.x = 0.08 * kk   # 오른발 앞, 왼발 뒤 — 한 줄에 선다
	sh.rotation.x = -(0.05 * kk); sh.rotation.z = -s * (0.1 + (1.45 + 0.4 * low) * kk) + tremor; el.rotation.x = -(0.35 - 0.2 * kk)
	if s > 0.0: f.neck.rotation.x += 0.35 * kk
	return true
