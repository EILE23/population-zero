class_name HaulPoses
extends RefCounted
## 종 줄 가족 자세(Climb 콘텐츠 팩 bell, run 128 — data/climb/bell.json, scripts/games/climb_bell.gd; 운영자 보드의 '줄다리기·줄 당기기' 가족 — 머리 위 줄을 두 손으로 쥐고 당기는 몸과 그 줄에 실려 오르는 몸): `haul` 종 줄에 매달린 몸 —
## 0.2 두 손이 머리 위 줄을 위아래로 쥐고(한 손이 다른 손 위 — 줄이니까) 다리가 늘어진다(예비) → 유지, 팩이 적는 메타로:
## 당김("haul_p" 0..1, 내려앉는 동안): 팔꿈치가 접혀 줄을 가슴께로 끌어내리고 무릎이 몸 쪽으로 접히며 몸통이 뒤로 젖혀지고 고개는 종을 올려다본다(종지기가 줄을 당기는 그 순간);
## 오르내림("haul_v" −1..1): 감겨 오를 땐 팔이 펴지고 다리가 곧게 뒤처져 늘어지며 몸통이 조금 앞으로, 꼭대기에 머물면 고개가 건너편 턱을 내려다보고, 내릴 땐 무릎이 조금 들리며 고개가 발밑을 본다
## → 뛰거나 놓아 로더가 자세를 비우면 stick3d 의 블렌딩이 팔을 내리고 무릎을 편다(회수). 메타가 없으면 제 박자로 당기고 오르고 머물고 내린다(주민·시연용).
## dangle(가로대에 두 손을 나란히 걸고 호를 그리는 몸)·climb(홀드에 붙은 몸)과 다르다: 이건 한 줄을 위아래로 쥐고 당겨서 끌려 오르는 몸. stick3d_rail.gd 처럼 주제별 파일

const GRAB_T := 0.2
const PERIOD := 3.0      # 메타가 없을 때의 제 박자: 당기기 → 오르기 → 머물기 → 내리기

## 잡은 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, GRAB_T, f.pose_t)

## 당김 0..1 — 팩이 적어 준 값, 없으면 제 박자(처음 0.3초 당기고 0.3초에 걸쳐 푼다)
static func pull(f: Stick3D) -> float:
	if f.has_meta("haul_p"): return clampf(float(f.get_meta("haul_p")), 0.0, 1.0)
	var ph := fmod(f._t, PERIOD)
	return smoothstep(0.0, 1.0, ph / 0.3) if ph < 0.3 else 1.0 - smoothstep(0.0, 1.0, (ph - 0.3) / 0.3)

## 오르면 +1, 내리면 −1, 머물거나 쉬면 0 — 팩이 적어 준 값, 없으면 제 박자
static func rise(f: Stick3D) -> float:
	if f.has_meta("haul_v"): return clampf(float(f.get_meta("haul_v")), -1.0, 1.0)
	var ph := fmod(f._t, PERIOD) / PERIOD
	return 1.0 if (ph > 0.2 and ph < 0.5) else (-1.0 if ph > 0.7 else 0.0)

## 골반은 늘어진 몸으로 조금 오르고 당길 땐 내려앉는다; 몸통은 당기면 뒤로 젖혀지고 오르면 조금 앞으로, 내리면 조금 뒤로
static func lean(f: Stick3D) -> float:
	var kk := k(f); var p := pull(f); var v := rise(f)
	f.pelvis.position.y = StickRig.HIP_Y + (0.03 - 0.05 * p) * kk
	return (-0.18 * p + 0.1 * maxf(0.0, v) - 0.05 * maxf(0.0, -v) + 0.02 * sin(f._t * 2.0)) * kk

## 팔다리 — 두 손은 줄을 위아래로(오른손이 위), 당기면 팔꿈치가 접히고 무릎이 접히며 고개가 종을 본다; 오르면 팔이 펴지고 다리가 곧게 늘어진다; 머물면 고개가 턱을, 내리면 무릎이 조금 들리고 고개가 발밑을 본다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "haul": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var p := pull(f); var v := rise(f)
	var up := maxf(0.0, v); var dn := maxf(0.0, -v)
	hip.rotation.x = -((0.12 + 0.55 * p - 0.08 * up + 0.2 * dn + 0.05 * s) * kk)
	knee.rotation.x = -(-(0.3 + 0.8 * p + 0.3 * dn) * kk)
	sh.rotation.x = -(0.2 + ((2.7 if s > 0.0 else 2.35) - 0.15 * p) * kk); sh.rotation.z = -s * (0.05 + 0.08 * kk)
	el.rotation.x = -((0.25 + 0.75 * p) * kk + 0.1)
	if s > 0.0: f.neck.rotation.x -= (0.35 * p + 0.15 * up - 0.2 * dn - (0.12 if (p < 0.05 and absf(v) < 0.05) else 0.0)) * kk
	return true
