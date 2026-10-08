class_name WadePoses
extends RefCounted
## 구름 뗏목 가족 자세(Climb 콘텐츠 팩 raft, run 126 — data/climb/raft.json, scripts/games/climb_raft.gd; 운영자 보드의 '물 건너기(wading)' 가족 — 발이 잠긴 바닥 위의 몸): `wade` 솜구름에 발이 잠긴 몸 —
## 0.15 무릎이 내려앉고 두 팔이 옆으로 들리며 손이 가슴 높이로(예비) → 유지: 가라앉은 만큼(meta "wade_k" 0..1, 팩의 stand 가 적는다; 없으면 6초 주기의 제 박자) 골반이 내려가고 무릎이 더 접히며 팔꿈치가 더 올라간다(물이 차오르면 팔을 드는 사람처럼),
## 서 있으면 0.9초로 무게를 한 발씩 옮기고 고개는 발밑과 건너편 턱을 번갈아 본다(2초); 걸으면("wade_w" ≠ 0, 없으면 몸의 속도로) 0.6초 한 걸음의 무릎 높이 걸음 — 앞다리는 허벅지가 높이 들리며 무릎이 접혔다 끝에서 펴지고(솜에서 발을 빼는 다리), 뒷다리는 뒤로 처지고, 몸통이 앞으로 숙고 팔은 반대로 크게 흔든다
## → 뛰어 로더가 자세를 비우면 stick3d 의 블렌딩이 팔을 내리고 무릎을 편다(회수).
## sway(흔들리는 바닥 — 골반째 기운다)·tread(흐르는 바닥 — 거슬러 선다)와 다르다: 이건 발밑이 꺼지는 바닥 — 몸이 가라앉고 발을 높이 뺀다. stick3d_tread.gd 처럼 주제별 파일

const BRACE_T := 0.15
const STEP_T := 0.6      # 무릎 높이 한 걸음
const SHIFT_T := 0.9     # 서서 무게를 옮기는 주기
const LOOK_T := 2.0      # 발밑 ↔ 건너편
const PERIOD := 6.0      # 메타가 없을 때의 제 박자(팩의 흐름 한 주기)

## 내려앉은 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, BRACE_T, f.pose_t)

## 가라앉은 정도 0..1 — 팩이 적어 준 값, 없으면 제 박자(주민·시연용)
static func sunk(f: Stick3D) -> float:
	return clampf(float(f.get_meta("wade_k", 0.5 - 0.5 * cos(f._t * TAU / PERIOD))), 0.0, 1.0)

## 걷기 −1..1 — 팩이 적어 준 값, 없으면 몸의 속도로
static func walk(f: Stick3D) -> float:
	if f.has_meta("wade_w"): return clampf(float(f.get_meta("wade_w")), -1.0, 1.0)
	return 1.0 if f.speed > 0.05 and f.move_dir.length_squared() > 0.0001 and not f.airborne and not f.seated else 0.0

## 골반이 가라앉은 만큼 내려간다(발이 솜에 잠긴다); 몸통은 서면 조금, 걸으면 더 앞으로
static func lean(f: Stick3D) -> float:
	var kk := k(f); var d := sunk(f); var w := walk(f)
	f.pelvis.position.y = StickRig.HIP_Y - (0.04 + 0.08 * d) * kk
	var body := 0.08 if w == 0.0 else 0.25
	return (body + 0.02 * sin(f._t * 2.2)) * kk

## 팔다리 — 걸으면 앞다리를 높이 들어 빼고 뒷다리는 처지며 팔을 반대로 흔든다; 서면 무릎을 접은 채 무게를 한 발씩 옮기고 팔은 옆으로 들어 가슴 높이에. 가라앉을수록 모두 더. 고개는 발밑과 건너편을 번갈아
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "wade": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var d := sunk(f); var w := walk(f)
	if w != 0.0:
		var a := sin(f._t * TAU / (STEP_T * 2.0)) * s   # +면 이쪽 다리가 앞
		var lift := maxf(0.0, a)   # 앞으로 가는 다리만 높이 든다 — 솜에서 빼는 다리
		hip.rotation.x = -((0.15 + 0.85 * lift + 0.4 * minf(0.0, a) + 0.15 * d) * kk)
		knee.rotation.x = -(-(0.2 + 1.0 * sin(PI * lift) + 0.2 * d) * kk)   # 들다 말고 접혔다 끝에서 편다
		sh.rotation.x = -((0.3 - 0.6 * a) * kk); sh.rotation.z = -s * (0.1 + 0.4 * kk); el.rotation.x = -(0.9 + 0.2 * d)
	else:
		var shift := sin(f._t * TAU / SHIFT_T) * s   # +면 이쪽에 무게
		hip.rotation.x = -((0.2 + 0.25 * d - 0.05 * shift) * kk)
		knee.rotation.x = -(-(0.35 + 0.3 * d + 0.08 * shift) * kk)
		sh.rotation.x = -((0.25 + 0.3 * d) * kk); sh.rotation.z = -s * (0.1 + (0.6 + 0.3 * d) * kk); el.rotation.x = -(1.2 + 0.3 * d)
	if s > 0.0:
		var look := 0.5 - 0.5 * cos(f._t * TAU / LOOK_T)   # 0 발밑, 1 건너편
		f.neck.rotation.x += ((0.35 - 0.45 * look) if w == 0.0 else 0.15) * kk
	return true
