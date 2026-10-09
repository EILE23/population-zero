class_name HeavePoses
extends RefCounted
## 덤웨이터 가족 자세(Climb 콘텐츠 팩 dumbwaiter, run 130 — data/climb/dumbwaiter.json, scripts/games/climb_dumbwaiter.gd; 운영자 보드의 '줄다리기·당기기' 가족 — 줄을 손 바꿔 당기는 몸): `heave` 상자 안에서 머리 위 줄을 당겨 제 몸을 올리는 몸 —
## 0.2 두 손이 머리 위 줄을 쥐고 무릎이 조금 접힌다(예비 — 발판에서 상자로 한 걸음) → 유지, 팩이 적는 메타로:
## 당김("heave_k" 1 → 0, heave_s 에 걸쳐; "heave_h" ±1 당기는 손): 당기는 손이 머리 위에서 가슴까지 내려오며 팔꿈치가 접히고 그 사이 다른 손이 가슴에서 머리 위로 올라 줄을 다시 쥔다(손 바꿔 — 하나는 늘 줄을 쥔다), 당김 가운데서 무릎이 내려앉고 몸통이 조금 뒤로 젖혀지며 고개는 줄을 본다; 당김 사이엔 그대로 멈춰(당긴 손은 가슴, 다른 손은 위) 숨만 쉰다;
## 제동 하강("heave_v" < 0): 두 손이 머리 위 줄을 쥐고 무릎을 깊이 굽혀 버티며 몸통이 조금 앞으로, 고개는 발밑을 보고, 손이 줄에 쓸리며 잘게 떤다
## → 내리거나 뛰어 로더가 자세를 비우면 stick3d 의 블렌딩이 팔을 내리고 무릎을 편다(회수). 메타가 없으면 0.7초마다 손을 바꾸는 제 박자(주민·시연용).
## haul(종 줄에 매달려 끌려 오르는 몸 — 발이 공중)·rail(사다리를 발로 디딤)·dangle(가로대에 두 손)과 다르다: 이건 바닥을 밟고 선 채 줄을 손 바꿔 당기는 두 팔. stick3d_rail.gd 처럼 주제별 파일

const GRAB_T := 0.2
const PERIOD := 0.7      # 메타가 없을 때 한 번 당기는 박자
const PULL_T := 0.3      # 제 박자의 당김 길이(팩의 heave_s 와 같다)
const HIGH := 2.7        # 어깨: 손이 머리 위 줄에
const LOW := 1.3         # 어깨: 손이 가슴 앞 줄에

## 잡은 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, GRAB_T, f.pose_t)

## 당김 1 → 0 — 팩이 적어 준 값, 없으면 제 박자
static func pull(f: Stick3D) -> float:
	if f.has_meta("heave_k"): return clampf(float(f.get_meta("heave_k")), 0.0, 1.0)
	return clampf(1.0 - fmod(f._t, PERIOD) / PULL_T, 0.0, 1.0)

## 당기는 손 ±1 — 팩이 적어 준 값, 없으면 박자마다 바꾼다
static func hand(f: Stick3D) -> float:
	if f.has_meta("heave_h"): return 1.0 if float(f.get_meta("heave_h")) >= 0.0 else -1.0
	return 1.0 if int(f._t / PERIOD) % 2 == 0 else -1.0

## 제동 하강 0..1 — 팩의 heave_v 가 음수인 만큼, 없으면 0
static func brake(f: Stick3D) -> float:
	return clampf(-float(f.get_meta("heave_v", 0.0)), 0.0, 1.0)

## 골반은 당김 가운데서 내려앉고 제동하면 더 낮다; 몸통은 당기면 조금 뒤로, 제동하면 조금 앞으로
static func lean(f: Stick3D) -> float:
	var kk := k(f); var p := 1.0 - pull(f); var b := brake(f)
	var dip := sin(PI * p) * (1.0 - b)
	f.pelvis.position.y = StickRig.HIP_Y - (0.05 * dip + 0.08 * b) * kk
	return (-0.12 * dip + 0.1 * b + 0.015 * sin(f._t * 2.2)) * kk

## 팔다리 — 당기는 손은 위에서 가슴으로, 다른 손은 가슴에서 위로(손 바꿔), 무릎은 당김 가운데서 내려앉는다; 제동하면 두 손이 위 줄을 쥐고 무릎을 깊이 굽혀 떤다. 고개는 당기면 줄을, 제동하면 발밑을
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "heave": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var p := 1.0 - pull(f); var b := brake(f)
	var pulling := hand(f) == s
	var e := smoothstep(0.0, 1.0, p)
	var sh_pull := lerpf(HIGH, LOW, e) if pulling else lerpf(LOW, HIGH, e)   # 하나가 내려오면 다른 하나가 올라간다
	var el_pull := (0.3 + 0.9 * e) if pulling else (1.2 - 0.9 * e)
	var dip := sin(PI * p)
	var tremble := sin(f._t * 23.0) * 0.03 * b
	var hip_v := lerpf(0.12 + 0.2 * dip, 0.35 + tremble, b)
	var knee_v := lerpf(0.2 + 0.35 * dip, 0.55 + tremble, b)
	var sh_v := lerpf(sh_pull, HIGH - 0.1 + tremble, b)
	var el_v := lerpf(el_pull, 0.45, b)
	hip.rotation.x = -(hip_v * kk)
	knee.rotation.x = -(-(knee_v * kk))
	sh.rotation.x = -(0.2 + (sh_v - 0.2) * kk); sh.rotation.z = -s * (0.08 + 0.1 * kk)   # 팔은 몸 앞 한 줄에 모인다
	el.rotation.x = -(el_v * kk + 0.1)
	if s > 0.0: f.neck.rotation.x += lerpf(-0.2 * (1.0 - e) - 0.05, 0.35, b) * kk
	return true
