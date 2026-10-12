class_name CrankPoses
extends RefCounted
## 도개교 가족 자세(Climb 콘텐츠 팩 drawbridge, run 144 — data/climb/drawbridge.json, scripts/games/climb_drawbridge.gd; 운영자 보드의 '손잡이 돌리기·윈치' 가족 — 두 손으로 가슴 높이의 손잡이를 돌리는 몸): `crank` 윈치를 감아 널을 내리는 몸 —
## 0.25 두 팔이 앞으로 나와 가슴 높이의 손잡이를 모아 쥐고 오른발이 앞으로 나가 버티며 골반이 조금 내려앉고 몸통이 북 쪽으로 기운다(예비 — 한 걸음 다가서기) → 유지, 팩이 적는 메타로:
## 손잡이의 각("crank_ph" 0..1, 한 바퀴마다; 없으면 2Hz 의 제 박자): 두 손이 가슴 앞의 원을 따라 돈다 — 어깨가 뻗었다 당기고 팔꿈치가 접혔다 펴진다, 몸통이 한 바퀴마다 밀 때 기울고 당길 때 서며 골반이 밀 때 조금 더 내려앉고 버틴 다리가 같이 흔들린다; 고개는 북을 보다 반 박자마다 널 쪽을 살핀다;
## 미끄러짐("crank_slide" 0..1, 세워지는 널 위의 몸; "crank_tilt" 널의 각 rad, 없으면 0.5): 두 팔을 옆으로 벌려 균형을 잡고 두 다리를 앞으로 뻗은 채 널의 각만큼 뒤로 젖혀 앉듯 내려앉으며 고개는 발밑을 본다 — 경첩에 닿으면 로더가 자세를 비우고 stick3d 의 블렌딩이 몸을 편다(회수).
## 메타가 없으면 2Hz 의 제 박자로 돈다(주민·시연용). shunt(앞의 서가를 두 손으로 민다)·heave(머리 위 줄을 당긴다)·tug(버너 줄을 홱 당긴다)와 다르다: 이건 제자리에서 도는 두 손, 일의 길이가 손의 것이다. stick3d_shunt.gd 처럼 주제별 파일

const SET_T := 0.25
const TURN_HZ := 2.0      # 제 박자 — 팩의 turns / lower_s 와 같다
const ARM := 1.1          # 어깨: 손잡이까지의 앞뻗음 가운데
const SWING := 0.35       # 어깨·팔꿈치: 한 바퀴의 흔들림(rad)
const DIP := 0.05         # 골반: 손을 댄 몸의 내려앉음
const SIT := 0.12         # 골반: 미끄러지는 몸의 내려앉음

## 손을 댄 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, SET_T, f.pose_t)

## 손잡이의 각(rad) — 팩이 적어 준 값, 없으면 제 박자
static func ph(f: Stick3D) -> float:
	if f.has_meta("crank_ph"): return fposmod(float(f.get_meta("crank_ph")), 1.0) * TAU
	return fposmod(f._t * TURN_HZ, 1.0) * TAU

## 미끄러지는 정도 0..1 — 0 이면 감는 몸
static func slide(f: Stick3D) -> float:
	if f.has_meta("crank_slide"): return clampf(float(f.get_meta("crank_slide")), 0.0, 1.0)
	return 0.0

## 널의 각(rad) — 미끄러질 때만
static func tilt(f: Stick3D) -> float:
	if f.has_meta("crank_tilt"): return clampf(float(f.get_meta("crank_tilt")), 0.0, PI / 2.0)
	return 0.5

## 골반이 내려앉고(밀 때 조금 더, 미끄러지면 앉듯) 몸통이 북 쪽으로 기울며 한 바퀴마다 밀 때 더 기운다; 미끄러지면 널의 각만큼 뒤로 젖힌다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var w := slide(f); var p := ph(f)
	f.pelvis.position.y = StickRig.HIP_Y - lerpf(DIP + 0.02 * maxf(0.0, -cos(p)), SIT, w) * kk
	var crank_l := 0.22 + 0.08 * sin(p)
	var slide_l := -(0.2 + 0.4 * tilt(f) / (PI / 2.0))
	return lerpf(crank_l, slide_l, w) * kk

## 팔다리 — 두 팔은 가슴 앞의 손잡이를 모아 쥐고 원을 따라 돈다(어깨 뻗음·팔꿈치 접힘이 한 바퀴 엇갈려), 오른발은 앞·왼발은 뒤로 버티며 바퀴마다 흔들린다; 고개는 북을 보다 널 쪽을 살핀다; 미끄러지면 두 팔을 옆으로 벌리고 다리를 뻗은 채 발밑을 본다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "crank": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var w := slide(f); var p := ph(f)
	# 감는 몸
	var rock := 0.04 * sin(p)
	var hip_c := (-0.4 if s > 0.0 else 0.25) + rock; var knee_c := (0.5 if s > 0.0 else 0.15) + 0.03 * maxf(0.0, -cos(p))
	var sh_c := ARM + SWING * cos(p); var shz_c := 0.12; var el_c := 0.9 - SWING * sin(p)
	# 미끄러지는 몸 — 팔을 벌리고 다리를 뻗는다
	var hip_s := -0.75; var knee_s := 0.15
	var sh_s := 0.6; var shz_s := 1.25; var el_s := 0.4
	hip.rotation.x = -(lerpf(hip_c, hip_s, w) * kk)
	knee.rotation.x = lerpf(knee_c, knee_s, w) * kk
	sh.rotation.x = -(0.15 + (lerpf(sh_c, sh_s, w) - 0.15) * kk); sh.rotation.z = -s * lerpf(shz_c, shz_s, w) * kk; el.rotation.x = -(0.5 + (lerpf(el_c, el_s, w) - 0.5) * kk)
	if s > 0.0:
		f.neck.rotation.x += lerpf(0.35, 0.5, w) * kk   # 북을 본다; 미끄러지면 발밑을
		f.neck.rotation.y += 0.35 * maxf(0.0, sin(f._t * PI)) * (1.0 - w) * kk   # 반 박자마다 널 쪽을 살핀다
	return true
