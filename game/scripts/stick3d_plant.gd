class_name PlantPoses
extends RefCounted
## 멀리뛰기 가족 자세(Climb 콘텐츠 팩 pit, run 162 — data/climb/pit.json, scripts/games/climb_pit.gd; 운영자 보드의 '육상' 가족 — 모래에 내리는 몸): `plant` 모래밭에 내린 몸 —
## 뒤꿈치(0..0.1): 두 다리가 앞으로 곧게 뻗어 뒤꿈치부터 닿고, 두 팔은 앞으로 던져지며(어깨 높이 위로), 상체는 살짝 뒤로 젖혀진다(예비 — 착지 틱에 자세가 시작되니 첫 프레임이 곧 닿는 순간)
## → 주저앉기(0.1..0.35): 무릎이 깊이 접히고 골반이 모래까지 내려앉으며 팔이 앞으로 낮게 흔들려 내리고 상체가 앞으로 숙는다, 고개는 무릎 쪽(유지 — 정지화가 아니다)
## → 일어나기(0.35..0.9): 몸이 펴지며 오른손(0.35..0.65)·왼손(0.5..0.8)이 번갈아 무릎을 털고(팔꿈치가 접혀 손이 무릎에, 상체는 그동안 숙였다 편다), 고개를 든다(회수). 0.9 에 done — 로더가 pose_request 를 비운다.
## bound(널에서 던져져 무릎이 받친다)·hurdle(가로대를 넘는 걸음)과 다르다: 이건 모래에 주저앉았다 털고 일어나는 몸.
## 시계는 pose_t; meta "plant_t" 가 있으면 그 값(점검용 — 한 순간에 멈춰 세운다). stick3d_bound.gd 처럼 주제별 파일

const HEELS_T := 0.1
const SIT_T := 0.35
const RISE_T := 0.9
const BRUSH_S := 0.3      # 손 하나가 무릎을 터는 시간 — 오른손 0.35 부터, 왼손 0.15 뒤

## 자세의 시계 — 점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("plant_t", f.pose_t))

## [heels, sit, rise] 0..1 — 뒤꿈치는 HEELS_T 에 다 닿고, 주저앉기가 SIT_T 까지 그 위에 얹히며, 일어나기가 RISE_T 에 끝난다
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	return [smoothstep(0.0, HEELS_T, u), smoothstep(HEELS_T, SIT_T, u), smoothstep(SIT_T, RISE_T, u)]

## 손 s 가 무릎을 터는 몫 0..1(한 번 갔다 온다) — 오른손이 먼저
static func brush(f: Stick3D, s: float) -> float:
	var t0 := SIT_T + (0.0 if s > 0.0 else 0.15)
	return sin(PI * clampf((at(f) - t0) / BRUSH_S, 0.0, 1.0))

## 회수가 끝났나 — 로더가 pose_request 를 비울 때
static func done(f: Stick3D) -> bool:
	return at(f) >= RISE_T

## 골반은 주저앉기에 모래까지 내려앉았다 일어난다; 상체는 뒤꿈치에 살짝 젖혀지고 주저앉기에 숙이며 일어나는 중간에 무릎을 털려 한 번 더 숙인다
static func lean(f: Stick3D) -> float:
	var p := phases(f); var hs := float(p[0]); var st := float(p[1]); var rs := float(p[2])
	var a := hs * (1.0 - st); var b := st * (1.0 - rs)
	f.pelvis.position.y = StickRig.HIP_Y - 0.3 * b
	return -0.25 * a + 0.6 * b + 2.0 * rs * (1.0 - rs)

## 팔다리 — 뒤꿈치: 다리를 앞으로 곧게, 팔을 앞으로 던진다; 주저앉기: 무릎이 깊이 접히고 팔이 낮게 앞으로; 일어나기: 펴지며 손이 번갈아 무릎을 턴다. 고개는 앞 → 무릎 → 든다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "plant": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var p := phases(f); var hs := float(p[0]); var st := float(p[1]); var rs := float(p[2])
	var a := hs * (1.0 - st); var b := st * (1.0 - rs); var br := brush(f, s)
	hip.rotation.x = -(0.9 * a + 1.2 * b)
	knee.rotation.x = 0.2 * a + 1.7 * b
	sh.rotation.x = -(2.0 * a + 0.9 * b + 0.7 * br)
	sh.rotation.z = -s * 0.2 * a
	el.rotation.x = -(0.3 * a + 0.5 * b + 1.3 * br)
	if s > 0.0: f.neck.rotation.x += -0.1 * a + 0.35 * b + 0.8 * rs * (1.0 - rs)
	return true
