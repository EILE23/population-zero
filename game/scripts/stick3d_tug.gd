class_name TugPoses
extends RefCounted
## 열기구 가족 자세(Climb 콘텐츠 팩 balloon, run 138 — data/climb/balloon.json, scripts/games/climb_balloon.gd; 운영자 보드의 '당기기' 가족 — 머리 위 줄을 홱 당기는 몸): `tug` 바구니 안에서 버너 줄의 토글을 당겨 불을 키우는 몸 —
## 0.2 한 손이 테를 쥐고 다른 손이 얼굴 높이의 토글로 올라가며 무릎이 조금 접힌다(예비 — 발판에서 바구니로 한 걸음) → 유지, 팩이 적는 메타로:
## 당김("tug_k" 1 → 0, yank_s 에 걸쳐; "tug_h" ±1 당기는 손): 처음 0.3 에 토글 손이 얼굴에서 어깨까지 홱 내려오며 팔꿈치가 접히고 무릎이 눌리고 테 손이 꽉 쥐며 고개가 뒤로 젖혀져 불꽃을 본다, 남은 0.65 에 손이 토글을 따라 되올라가고 고개가 내려온다 — 하나의 짧은 당김
## 오름("tug_v" > 0): 몸통이 살짝 뒤로 기울고 골반이 조금 내려앉는다(바람과 오름에 받친 몸); 당기지 않을 땐 고개가 테 너머 아래를 본다(기구에서 내려다보는 사람)
## → 내리거나 뛰어 로더가 자세를 비우면 stick3d 의 블렌딩이 팔을 내리고 무릎을 편다(회수). 메타가 없으면 1.6초마다 손을 바꿔 당기는 제 박자(주민·시연용).
## heave(덤웨이터 — 줄을 손 바꿔 제 몸을 끌어올린다, 두 손이 늘 줄에)·haul(종 줄에 매달려 발이 공중)과 다르다: 이건 발로 바닥을 딛고 한 손은 테에 둔 채 다른 손이 한 번 홱 당기는 것. stick3d_heave.gd 처럼 주제별 파일

const GRAB_T := 0.2
const PERIOD := 1.6      # 메타가 없을 때 한 번 당기는 박자
const YANK_T := 0.45     # 제 박자의 당김 길이(팩의 yank_s 와 같다)
const UP := 2.2          # 어깨: 손이 얼굴 높이의 토글에
const DOWN := 1.5        # 어깨: 토글을 어깨까지 당겨 내린 손
const RIM := 0.45        # 어깨: 손이 허벅지 높이의 테에

## 잡은 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, GRAB_T, f.pose_t)

## 당김 1 → 0 — 팩이 적어 준 값, 없으면 제 박자
static func pull(f: Stick3D) -> float:
	if f.has_meta("tug_k"): return clampf(float(f.get_meta("tug_k")), 0.0, 1.0)
	return clampf(1.0 - fmod(f._t, PERIOD) / YANK_T, 0.0, 1.0)

## 당기는 손 ±1 — 팩이 적어 준 값, 없으면 박자마다 바꾼다
static func hand(f: Stick3D) -> float:
	if f.has_meta("tug_h"): return 1.0 if float(f.get_meta("tug_h")) >= 0.0 else -1.0
	return 1.0 if int(f._t / PERIOD) % 2 == 0 else -1.0

## 오름 0..1 — 팩의 tug_v 가 양수인 만큼, 없으면 0
static func rise(f: Stick3D) -> float:
	return clampf(float(f.get_meta("tug_v", 0.0)), 0.0, 1.0)

## 당겨 내린 정도 0..1 — 당김의 처음 0.3 에 홱 내려가(1) 0.35 부터 1.0 까지 되올라온다(0); 당기지 않으면 0
static func down(f: Stick3D) -> float:
	var y := 1.0 - pull(f)
	if y <= 0.0 or y >= 1.0: return 0.0
	return smoothstep(0.0, 0.3, y) * (1.0 - smoothstep(0.35, 1.0, y))

## 골반은 당김에 눌리고 오를 때 조금 내려앉는다; 몸통은 당김에 조금 앞으로, 오르면 뒤로, 바구니의 숨만큼 흔들린다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var dn := down(f); var up := rise(f)
	f.pelvis.position.y = StickRig.HIP_Y - (0.05 * dn + 0.02 * up) * kk
	return (0.08 * dn - 0.08 * up + 0.015 * sin(f._t * 1.7)) * kk

## 팔다리 — 토글 손은 얼굴 높이에서 어깨까지 홱 내려오고 되올라간다, 테 손은 허벅지 높이의 테를 쥐고 당김에 꽉 쥔다; 무릎은 당김에 눌린다. 고개는 당기면 불꽃을(뒤로), 아니면 테 너머 아래를
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "tug": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var dn := down(f); var up := rise(f)
	var pulling := hand(f) == s
	var sh_v := lerpf(UP, DOWN, dn) if pulling else RIM + 0.1 * dn
	var el_v := lerpf(0.4, 1.3, dn) if pulling else 0.15 + 0.25 * dn
	var hip_v := 0.1 + 0.12 * dn - 0.05 * up
	var knee_v := 0.15 + 0.2 * dn
	hip.rotation.x = -(hip_v * kk)
	knee.rotation.x = knee_v * kk
	sh.rotation.x = -(0.2 + (sh_v - 0.2) * kk); sh.rotation.z = -s * ((0.05 if pulling else 0.2) * kk + 0.08)   # 토글 손은 얼굴 앞 한 줄에, 테 손은 옆으로
	el.rotation.x = -(el_v * kk + 0.1)
	if s > 0.0: f.neck.rotation.x += (0.25 * (1.0 - dn) * (1.0 - up) - 0.35 * dn - 0.15 * up) * kk
	return true
