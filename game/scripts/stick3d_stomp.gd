class_name StompPoses
extends RefCounted
## 풀무 승강기 가족 자세(Climb 콘텐츠 팩 bellows, run 149 — data/climb/bellows.json, scripts/games/climb_bellows.gd; 운영자 보드의 '밟기·구르기' 가족, bound 의 다음): `stomp` 페달 위에 서서 발을 구르는 몸 —
## 준비(0.2 에 잡힌다): 무릎을 풀고 두 팔을 앞으로 조금 들어 어깨 폭보다 벌린 채 판 너머의 피스톤을 본다(피스톤이 오를수록 고개가 따라 올라간다 — meta "stomp_k" 0..1); 판이 눌린 만큼(meta "stomp_dip" 0..1) 골반이 내려앉고 무릎이 더 접힌다; 쉬는 동안도 1.8초 숨에 무릎이 조금 흔들린다 — 정지화가 아니다
## 구름(meta "stomp_s" 마지막 구름 뒤 초, meta "stomp_f" 구르는 발 ±1; 팩의 stand 가 적는다, 없으면 1.2초 주기의 제 박자로 발을 바꿔 가며 구른다): 0.12 한 무릎이 가슴 높이로 올라오고 팔이 위로 휘두르며 몸이 뒤로 젖혀진다(예비)
## → 0.1 발이 내리꽂히고 몸이 앞으로 쏠리며 골반이 내려앉는다(구름) → 0.3 팔이 늦게 내려오고 무릎이 풀린 준비로 돌아온다(회수).
## bound(널 끝에서 두 발로 젓다 던져진다)·tread(띠 위를 걷는다)·crank(손으로 감는다)와 다르다: 이건 한 발로 다른 것을 올리는 몸 — 제 몸은 그 자리에 선다. stick3d_curl.gd 처럼 주제별 파일

const READY_T := 0.2
const LIFT_T := 0.12
const DRIVE_T := 0.1
const REC_T := 0.3
const PERIOD := 1.2
const BREATH := 1.8
const PRESS_T := 0.12
const BACK_T := 0.25

## 자세에 든 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, READY_T, f.pose_t)

## 마지막 구름 뒤 초 — 팩이 적어 준 값, 없으면 제 박자(주민·시연용)
static func since(f: Stick3D) -> float:
	return maxf(0.0, float(f.get_meta("stomp_s", fposmod(f._t, PERIOD))))

## 구르는 발 ±1 — 팩이 적어 준 값, 없으면 박자마다 바꾼다
static func foot(f: Stick3D) -> float:
	return 1.0 if float(f.get_meta("stomp_f", 1.0 if int(floor(f._t / PERIOD)) % 2 == 0 else -1.0)) >= 0.0 else -1.0

## 피스톤의 높이 0..1 — 팩이 적어 준 값, 없으면 느린 제 박자
static func height(f: Stick3D) -> float:
	return clampf(float(f.get_meta("stomp_k", 0.5 - 0.5 * cos(f._t * TAU / (PERIOD * 6.0)))), 0.0, 1.0)

## 판이 눌린 몫 0..1 — 팩이 적어 준 값, 없으면 구름에 맞춘 제 박자(0.12 눌렸다 0.25 에 돌아온다)
static func dip(f: Stick3D) -> float:
	if f.has_meta("stomp_dip"): return clampf(float(f.get_meta("stomp_dip")), 0.0, 1.0)
	var u := since(f)
	if u >= PRESS_T + BACK_T: return 0.0
	return u / PRESS_T if u < PRESS_T else 1.0 - (u - PRESS_T) / BACK_T

## [up, drive, arm] 0..1 — 무릎이 올라온 몫, 내리꽂히는 몫, 팔이 휘둘린 몫(발보다 늦게 내려온다)
static func beat(f: Stick3D) -> Array:
	var u := since(f)
	var up := smoothstep(0.0, LIFT_T, u) * (1.0 - smoothstep(LIFT_T, LIFT_T + DRIVE_T, u))
	var dn := smoothstep(LIFT_T, LIFT_T + DRIVE_T, u) * (1.0 - smoothstep(LIFT_T + DRIVE_T, LIFT_T + DRIVE_T + REC_T, u))
	var arm := smoothstep(0.0, LIFT_T, u) * (1.0 - smoothstep(LIFT_T + 0.05, LIFT_T + DRIVE_T + REC_T, u))
	return [up, dn, arm]

## 골반이 판의 눌림과 구름에 내려앉고(무릎이 올라올 땐 선 다리가 펴져 조금 뜬다) 몸통은 무릎이 올라올 때 뒤로, 내리꽂힐 때 앞으로; 숨에 조금 흔들린다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var b := beat(f); var up := float(b[0]); var dn := float(b[1])
	var dp := dip(f); var breath := 0.5 + 0.5 * sin(f._t * TAU / BREATH)
	f.pelvis.position.y = StickRig.HIP_Y - (0.06 + 0.04 * dp + 0.05 * dn + 0.02 * breath - 0.04 * up) * kk
	return (0.1 - 0.25 * up + 0.25 * dn + 0.02 * breath) * kk

## 팔다리 — 구르는 발: 무릎이 가슴 높이로 올라왔다 내리꽂힌다; 선 다리: 풀린 무릎이 올라올 때 살짝 펴지고 구름에 더 접힌다; 팔: 앞으로 들렸다 구름에 위로 휘두르고 늦게 내려온다. 고개는 피스톤을 — 오를수록 위로, 내리꽂힐 때 턱을 당긴다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "stomp": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var b := beat(f); var up := float(b[0]); var dn := float(b[1]); var arm := float(b[2])
	var dp := dip(f); var mine := 1.0 if s == foot(f) else 0.0
	var bend := (0.2 + 0.12 * dp + 0.15 * dn) * kk   # 풀린 무릎 — 판이 눌리고 구름에 더
	var breath := 0.03 * sin(f._t * TAU / BREATH) * kk
	hip.rotation.x = -(bend + (1.5 * up) * mine - 0.1 * up * (1.0 - mine) * kk)
	knee.rotation.x = bend * 1.6 + (2.0 * up) * mine + breath
	sh.rotation.x = -((0.5 + 1.3 * arm) * kk); sh.rotation.z = -s * (0.25 + 0.15 * arm) * kk; el.rotation.x = -((0.5 - 0.2 * arm) * kk)
	if s > 0.0: f.neck.rotation.x += (0.15 - 0.3 * height(f) - 0.2 * up + 0.15 * dn) * kk
	return true
