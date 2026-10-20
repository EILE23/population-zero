class_name AfloatPoses
extends RefCounted
## 구름 웅덩이 가족 자세(Climb 콘텐츠 팩 pool, run 186 — data/climb/pool.json, scripts/games/climb_pool.gd; 운영자 보드의 '물' 가족 가운데 '등을 대고 뜨기'): `afloat` 구름 웅덩이에 빠져 등을 대고 뜬 몸 —
## 빠짐(meta "afl_c" 0..1, 팩의 swim 이 적는다 — 없으면 0.4초에 제 박자로): 떨어진 몸이 발부터 들어가 무릎이 가슴으로 오르고 두 팔이 위로 벌어지며 골반이 반쯤 눕는다(예비 — 물보라)
## → 떠오르며 등을 댄다: 골반이 깊이 눕고(−1.45) 낮아지며, 두 팔이 옆으로 활짝 펴지고(z ±1.25) 팔뚝이 0.7Hz 로 번갈아 물을 젓고, 다리는 뻗어 발끝이 위를 보며 오른발이 0.6Hz 로 까딱이고, 고개는 하늘을 본다(유지);
## 젓기(meta "afl_v" 0..1 — 좌우를 누르면 1): 팔뚝의 젓기가 1.4Hz 로 빨라지고 어깨까지 젓는다. 몸통은 숨(1.0Hz)에 오르내린다 — 팩이 몸째 흔드는 bob 과 겹친다.
## → 기어오름(meta "afl_o" 0..1, 팩이 적는다 — 없으면 마지막 0.6초): 앞으로 굴러 두 손을 턱에 짚고 왼 무릎을 올려(0..0.6) 일어선다(0.6..1); 가라앉음(meta "afl_s" 0..1): ↓ 로 몸이 접히며 두 팔을 위로 뻗은 채 밑으로.
## → 로더가 자세를 비우면 stick3d 의 블렌딩이 선 자세로 편다(회수). 몸이 보는 쪽(로더의 face)의 반대가 머리 쪽.
## loll(그물에 받혀 늘어진 눕기)·wade(솜에 발이 잠긴 선 몸)·swim(마을 강의 헤엄 — 엎드려 젓는다)과 다르다: 이건 등을 대고 떠서 팔뚝으로 젓고 흐름에 실려 가는 첫 자세 — 턱에 닿으면 손으로 기어오른다. stick3d_loll.gd 처럼 주제별 파일

const DUNK_T := 0.4       # 빠짐(s) = climb_pool dunk_s
const FLOAT_T := 2.0      # 메타 없이 돌 때 뜬 시간(s)
const OUT_T := 0.6        # 기어오름(s) = out_s
const LAP := DUNK_T + FLOAT_T + OUT_T   # 한 바퀴(s) — 메타 없이 돌 때 done
const SCULL_HZ := 0.7
const WAG_HZ := 0.6
const BREATH_HZ := 1.0
const ARM_OUT := 1.25     # 뜬 팔: 옆으로 벌림(rad)
const LIE := -1.45        # 뜬 골반(rad) — 등을 댄다
const LIE_Y := 0.10       # 뜬 골반 높이(m)
const KNEEL_Y := 0.25

## 빠진 몫 0..1 — 팩의 메타, 없으면 pose_t 로
static func c(f: Stick3D) -> float:
	if f.has_meta("afl_c"): return clampf(float(f.get_meta("afl_c")), 0.0, 1.0)
	return smoothstep(0.0, DUNK_T, f.pose_t)

## 젓는 몫 0..1 — 팩의 메타, 없으면 0
static func v(f: Stick3D) -> float:
	return clampf(float(f.get_meta("afl_v", 0.0)), 0.0, 1.0)

## 기어오른 몫 0..1 — 팩의 메타, 없으면 마지막 OUT_T
static func o(f: Stick3D) -> float:
	if f.has_meta("afl_o"): return clampf(float(f.get_meta("afl_o")), 0.0, 1.0)
	return smoothstep(LAP - OUT_T, LAP, f.pose_t)

## 가라앉은 몫 0..1 — 팩의 메타, 없으면 0
static func sk(f: Stick3D) -> float:
	return clampf(float(f.get_meta("afl_s", 0.0)), 0.0, 1.0)

## 시간으로 돌 때 끝났나 — 팩이 모는 동안은 팩이 자세를 쥔다
static func done(f: Stick3D) -> bool:
	return not f.has_meta("afl_c") and not f.has_meta("afl_o") and f.pose_t >= LAP

## [roll, stand] — 기어오름의 두 토막: 앞으로 구르기(0..0.6), 일어서기(0.6..1)
static func parts(f: Stick3D) -> Array:
	var oo := o(f)
	return [smoothstep(0.0, 0.6, oo), smoothstep(0.6, 1.0, oo)]

## 골반은 빠질 땐 반쯤 눕고 뜨면 깊이 누워 낮다; 기어오르면 앞으로 굴러 무릎을 꿇었다 선다; 가라앉으면 접힌다. 몸통은 빠질 땐 말리고 뜨면 가슴을 열고 숨 쉬고, 기어오르면 턱 위로 숙였다 편다
static func lean(f: Stick3D) -> float:
	var cc := c(f); var p := parts(f); var roll := float(p[0]); var stand := float(p[1]); var s := sk(f)
	var breathe := sin(f._t * TAU * BREATH_HZ)
	var rot := lerpf(-0.5, LIE, cc) + 0.6 * s
	rot = lerpf(rot, 0.5, roll); rot = lerpf(rot, 0.0, stand)
	var py := lerpf(StickRig.HIP_Y - 0.1, LIE_Y + 0.01 * breathe, cc) - 0.03 * s
	py = lerpf(py, KNEEL_Y, roll); py = lerpf(py, StickRig.HIP_Y, stand)
	f.pelvis.rotation.x = rot; f.pelvis.position.y = py
	var ln := lerpf(0.3, -0.15 + 0.02 * breathe, cc) + 0.3 * s
	return lerpf(ln, 0.5, roll) * (1.0 - stand)

## 팔다리 — 두 다리: 빠질 땐 무릎이 가슴으로(−1.2·1.4), 뜨면 뻗고(−0.25/−0.15·0.1) 오른발이 까딱이고, 기어오르면 왼 무릎을 턱에 올리고(−1.3·1.3) 선다, 가라앉으면 접힌다; 두 팔: 빠질 땐 위로(−1.5·z 0.8), 뜨면 옆으로 활짝(−0.4·z 1.25) 팔뚝이 번갈아 젓고(0.7Hz, 저으면 1.4Hz 로 어깨까지), 기어오르면 앞으로 턱을 짚고(−1.1·z 0.25) 선다; 고개는 뜨면 하늘을(−), 기어오르면 턱을(+), 가라앉으면 위를
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "afloat": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var cc := c(f); var vv := v(f); var p := parts(f); var roll := float(p[0]); var stand := float(p[1]); var sink := sk(f)
	var ph := f._t * TAU * (SCULL_HZ + SCULL_HZ * vv) + (0.0 if s > 0.0 else PI)
	var wag := 0.08 * sin(f._t * TAU * WAG_HZ) if s > 0.0 else 0.0
	# 빠짐(cc 0) → 뜸(cc 1)
	var hip_f := -(0.25 if s > 0.0 else 0.15) - 0.8 * sink
	var knee_f := 0.1 + wag + 1.0 * sink
	var hx := lerpf(-1.2, hip_f, cc); var kx := lerpf(1.4, knee_f, cc)
	var shx := lerpf(-1.5, -0.4 - 0.2 * vv * sin(ph), cc) - 1.3 * sink * cc
	var shz := -s * lerpf(0.8, ARM_OUT, cc)
	var elx := lerpf(-0.3, -0.35 - 0.3 * sin(ph), cc)
	var neck := lerpf(0.1, -0.35 + 0.03 * sin(f._t * TAU * BREATH_HZ), cc) + 0.3 * sink
	# 기어오름: 앞으로 굴러 무릎을 꿇고(왼 무릎이 턱 위) 손을 짚고 → 선다
	hx = lerpf(hx, -1.3 if s < 0.0 else -1.1, roll); kx = lerpf(kx, 1.3, roll)
	shx = lerpf(shx, -1.1, roll); shz = lerpf(shz, -s * 0.25, roll); elx = lerpf(elx, -0.4, roll); neck = lerpf(neck, 0.2, roll)
	hip.rotation.x = hx * (1.0 - stand); knee.rotation.x = kx * (1.0 - stand)
	sh.rotation.x = shx * (1.0 - stand); sh.rotation.z = shz * (1.0 - stand); el.rotation.x = elx * (1.0 - stand)
	if s > 0.0: f.neck.rotation.x += neck * (1.0 - stand)
	return true
