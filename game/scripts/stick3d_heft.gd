class_name HeftPoses
extends RefCounted
## 상자를 재 보는 자세(Climb 팩 crate 의 주민 반쪽 — 짐꾼, run 183; 운영자 보드의 '상자·가구 나르기' 가족의 둘째 자세): `heft` 더미 곁에 옆으로 서서 맨 위 상자에 허리를 숙이고(0.25 s), 한 손으로 밧줄 손잡이를 당겨 무게를 재고(0.3 s — 두 번 당긴다), 고개를 끄덕이며 일어서는(0.25 s) 몸 — 들기(lug) 전에 들 만한지 보는 손.
## 시계는 하나고 짐꾼(climb_porter.gd)이 적는다: meta "heft_t"(자세에 든 뒤 시간), meta "heft_h"(손잡이의 높이 0..1 — 발치면 0, 가슴이면 1: 낮은 상자엔 깊이 숙이고 높은 상자엔 조금만, 팔은 그만큼 앞으로). 메타가 없으면 pose_t 로 혼자 한 번 돈다(점검·시연용, 높이 0.3).
## 숙임(0..0.25): 0.12 s 에 상체가 앞으로(0.9 × 깊이) 두 무릎이 접히고(0.5 × 깊이) 골반이 조금 내려오며(−0.1 × 깊이) 오른팔이 손잡이로(어깨 −0.5 − 0.8 × 높이, 팔꿈치 −0.2); 왼손은 허리에(어깨 z 0.45 벌려 팔꿈치 −1.3); 고개는 상자를 본다(+0.45, 높은 상자는 덜)
## → 당김(0.25..0.55): 오른 팔꿈치가 6 Hz 로 손잡이를 당기고(−0.35) 상체가 당김에 뒤로 버틴다(−0.1) — 숙임은 그대로
## → 끄덕임(0.55..0.8): 상체·무릎·팔이 돌아오며 고개가 한 번 끄덕인다(+0.35 sin). 정지화가 아니다(왼 무릎은 늘 0.8 Hz 로 숨쉰다).
## lug(쪼그려 안아 든다)·steady(통나무에 발을 얹어 눌러 본다)·clip(바짓단을 집는다)과 다르다: 이건 손으로 무게를 재는 몸 — 끝나면 바로 lug 가 온다. stick3d_clip.gd 처럼 주제별 파일

const BEND_T := 0.25                        # 숙여 잡는 시간(s)
const PULL_T := 0.3                         # 손잡이를 당기는 시간(s)
const NOD_T := 0.25                         # 끄덕이며 일어서는 시간(s)
const TOTAL := BEND_T + PULL_T + NOD_T      # 자세 전체(s) — 짐꾼이 이만큼 뒤 든다
const RISE := 0.12                          # 숙여 들어가는 시간(s)
const BLEND := 0.03                         # 당김의 들고 나는 반폭(s)
const PULL_HZ := 6.0                        # 손잡이를 당기는 팔꿈치
const BREATHE_HZ := 0.8
const DEFAULT_H := 0.3                      # 메타 없을 때의 손잡이 높이
const LEAN := 0.9; const KNEE := 0.5; const HIP := 0.35; const DIP := 0.1   # 숙임의 깊이 1 일 때
const SHALLOW := 0.75                       # 가슴 높이 상자엔 숙임이 이만큼 얕다(깊이 = 1 − SHALLOW × 높이)
const REACH_SH := 0.5; const REACH_H := 0.8; const REACH_EL := 0.2
const PULL_EL := 0.35; const PULL_LEAN := 0.1
const AKIMBO_Z := 0.45; const AKIMBO_SH := 0.2; const AKIMBO_EL := 1.3
const LOOK := 0.45; const LOOK_H := 0.5; const NOD := 0.35

## 자세에 든 뒤 시간(s) — 짐꾼의 메타, 없으면 pose_t
static func since(f: Stick3D) -> float:
	if f.has_meta("heft_t"): return maxf(0.0, float(f.get_meta("heft_t")))
	return f.pose_t

## 손잡이의 높이 0..1 — 짐꾼의 메타, 없으면 DEFAULT_H
static func height(f: Stick3D) -> float:
	if f.has_meta("heft_h"): return clampf(float(f.get_meta("heft_h")), 0.0, 1.0)
	return DEFAULT_H

## 다 했나
static func done(f: Stick3D) -> bool:
	return since(f) >= TOTAL

## [bend, pull, nod] — 숙임의 몫(0.12 에 숙여 끄덕임에 돌아온다), 당김의 몫(0.25..0.55), 끄덕임의 진행 0..1
static func phases(u: float) -> Array:
	var bend := smoothstep(0.0, RISE, u) * (1.0 - smoothstep(TOTAL - NOD_T, TOTAL, u))
	var pull := smoothstep(BEND_T - BLEND, BEND_T + BLEND, u) * (1.0 - smoothstep(BEND_T + PULL_T - BLEND, BEND_T + PULL_T + BLEND, u))
	var nod := clampf((u - BEND_T - PULL_T) / NOD_T, 0.0, 1.0)
	return [bend, pull, nod]

## 당기는 손 0..1 — 6 Hz 의 당김, 당김의 몫만큼
static func tug(f: Stick3D, pull: float) -> float:
	return maxf(0.0, sin(f._t * TAU * PULL_HZ)) * pull

## 상체 — 숙여 상자로(낮은 상자엔 깊이), 당김에 뒤로 버틴다; 골반은 숙인 만큼 내려온다
static func lean(f: Stick3D) -> float:
	var ph := phases(since(f)); var bend := float(ph[0]); var pull := float(ph[1])
	var depth := 1.0 - SHALLOW * height(f)
	f.pelvis.position.y = StickRig.HIP_Y - DIP * depth * bend
	return LEAN * depth * bend - PULL_LEAN * tug(f, pull)

## 팔다리 — 오른팔(s > 0): 손잡이로(−0.5 − 0.8 × 높이, 팔꿈치 −0.2) 당김에 팔꿈치가 6 Hz 로 당긴다; 왼팔(s < 0): 허리에(z 0.45, 팔꿈치 −1.3); 두 다리: 숙임의 접힘(깊이만큼), 왼 무릎은 늘 숨쉰다; 고개는 상자를 보다 끄덕인다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "heft": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(since(f)); var bend := float(ph[0]); var pull := float(ph[1]); var nod := float(ph[2])
	var h := height(f); var depth := 1.0 - SHALLOW * h
	var breathe := sin(f._t * TAU * BREATHE_HZ) * 0.03   # 왼 무릎의 숨 — 정지화가 아니다
	hip.rotation.x = -HIP * depth * bend
	knee.rotation.x = KNEE * depth * bend
	if s > 0.0:
		sh.rotation.x = -(REACH_SH + REACH_H * h) * bend
		sh.rotation.z = 0.0
		el.rotation.x = -REACH_EL * bend - PULL_EL * tug(f, pull)
		f.neck.rotation.x += LOOK * (1.0 - LOOK_H * h) * bend + NOD * sin(PI * nod)   # 상자를 보다, 끄덕인다
	else:
		sh.rotation.x = AKIMBO_SH * bend
		sh.rotation.z = -s * AKIMBO_Z * bend
		el.rotation.x = -AKIMBO_EL * bend
		knee.rotation.x += breathe
	return true
