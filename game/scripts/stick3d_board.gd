class_name BoardPoses
extends RefCounted
## 파터노스터 가족 자세(Climb 콘텐츠 팩 paternoster, run 139 — data/climb/paternoster.json, scripts/games/climb_paternoster.gd; 운영자 보드의 '올라타기·내리기' 가족 — 움직이는 바닥에 걸어 들어가고 나오는 몸): `board` 도는 칸에 타고 있는 몸 —
## 들어서기(STEP_T 에 잡힌다): 오른손이 뒷벽 난간으로 옆으로 뻗어 오르고 오른 무릎이 문턱 위로 높이 들렸다 내려 디디며 몸이 조금 가라앉고 고개는 문턱을 본다(예비) → 유지, 팩이 적는 메타로:
## 오르내림("board_v" ±1·0): 오를 땐 무릎이 더 받치고 고개가 위를, 내릴 땐 무릎이 풀리며 고개가 아래를 본다; 옆으로 돌 때("board_x" ±1·0): 왼팔이 밖으로 펼쳐지고 몸이 실려 가는 쪽으로 기운다;
## 나서기("board_out" 0..1 — 문턱에서 가장자리까지): 난간 손이 내려오고 왼다리가 앞으로 뻗으며 몸이 앞으로 기운다(회수의 첫 반 — 가장자리를 지나 로더가 자세를 비우면 stick3d 의 블렌딩이 나머지를 편다).
## 메타가 없으면 5.4초 한 바퀴의 제 박자(오름 2 → 꼭대기 0.7 → 내림 2 → 바닥 0.7; 주민·시연용).
## heave(덤웨이터 — 제 손으로 줄을 당긴다)·rail(사다리 — 가로대를 번갈아 쥔다)·tug(열기구 — 토글을 홱 당긴다)와 다르다: 이건 손이 잡기만 하고 다리가 걸어 들어가고 나오는 것. stick3d_tug.gd 처럼 주제별 파일

const STEP_T := 0.25     # 들어서기 — 무릎이 문턱을 넘고 손이 난간에
const RAIL := 1.3        # 어깨(옆으로): 손이 어깨 높이 난간에
const LIFT := 0.9        # 엉덩이: 문턱을 넘는 무릎의 높이
const REACH := 0.7       # 엉덩이: 나서는 앞다리
const LAP := 5.4         # 제 박자 한 바퀴

## 들어선 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, STEP_T, f.pose_t)

## 오르내림 ±1·0 — 팩이 적어 준 값, 없으면 제 박자
static func v(f: Stick3D) -> float:
	if f.has_meta("board_v"): return clampf(float(f.get_meta("board_v")), -1.0, 1.0)
	var q := fmod(f._t, LAP)
	return 1.0 if q < 2.0 else (0.0 if q < 2.7 else (-1.0 if q < 4.7 else 0.0))

## 옆으로 실려 가는 방향 ±1·0 — 팩이 적어 준 값, 없으면 제 박자
static func h(f: Stick3D) -> float:
	if f.has_meta("board_x"): return clampf(float(f.get_meta("board_x")), -1.0, 1.0)
	var q := fmod(f._t, LAP)
	return 0.0 if q < 2.0 else (-1.0 if q < 2.7 else (0.0 if q < 4.7 else 1.0))

## 나서는 정도 0..1 — 팩의 board_out, 없으면 0
static func out(f: Stick3D) -> float:
	return clampf(float(f.get_meta("board_out", 0.0)), 0.0, 1.0)

## 골반은 들어설 때 가라앉고 오를 때 조금, 나설 때 조금 내려앉는다; 몸통은 들어설 때 앞으로, 실려 가는 쪽으로, 나설 때 앞으로, 사슬의 흔들림만큼
static func lean(f: Stick3D) -> float:
	var kk := k(f); var up := maxf(0.0, v(f)); var hx := h(f); var o := out(f)
	f.pelvis.position.y = StickRig.HIP_Y - 0.06 * (1.0 - kk) - 0.03 * up * kk - 0.04 * o
	return 0.1 * (1.0 - kk) + (-0.1 * hx + 0.15 * o + 0.03 * sin(f._t * 2.0)) * kk

## 팔다리 — 오른손은 난간에(들어서며 올라가 쥐고 나서며 놓는다), 왼팔은 돌 때 밖으로; 오른 무릎이 문턱을 넘고, 타는 동안 무릎이 오르내림을 받으며, 나설 땐 왼다리가 앞으로. 고개는 문턱 → 가는 쪽
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "board": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var vv := v(f); var hx := h(f); var o := out(f)
	var up := maxf(0.0, vv); var dn := maxf(0.0, -vv); var ax := absf(hx)
	var hip_v := 0.08 + 0.06 * up - 0.03 * dn
	var knee_v := 0.12 + 0.18 * up + 0.1 * dn
	if s > 0.0:   # 오른쪽 — 난간 손, 문턱을 넘는 무릎
		hip_v = lerpf(LIFT, hip_v, kk)
		knee_v = lerpf(1.2, knee_v, kk)
		sh.rotation.x = -(0.1 * kk); sh.rotation.z = -s * (RAIL * kk * (1.0 - o) + 0.08)
		el.rotation.x = -(0.5 * kk * (1.0 - o) + 0.1)
	else:         # 왼쪽 — 균형 팔, 나서는 앞다리
		hip_v = lerpf(hip_v, REACH, o)
		knee_v = lerpf(knee_v, 0.3, o)
		sh.rotation.x = -(0.15 + 0.35 * ax * kk); sh.rotation.z = -s * (0.1 + 0.5 * ax * kk)
		el.rotation.x = -(0.2 + 0.2 * ax * kk)
	hip.rotation.x = -hip_v
	knee.rotation.x = knee_v
	if s > 0.0: f.neck.rotation.x += 0.15 * (1.0 - kk) + (-0.2 * up + 0.3 * dn) * kk
	return true
