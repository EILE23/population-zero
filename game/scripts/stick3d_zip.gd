class_name ZipPoses
extends RefCounted
## 집라인 가족 자세(Climb 콘텐츠 팩 zip, run 140 — data/climb/zip.json, scripts/games/climb_zip.gd; 운영자 보드의 '매달리기·철봉' 가족 — 두 손으로 가로대를 쥐고 비탈을 미끄러져 내려가는 몸): `zip` 트롤리 가로대에 매달린 몸 —
## 0.2 두 팔이 머리 위로 벌려 올라가 가로대를 쥐고(두 손이 어깨보다 넓게 — 한 줄로 모으는 kite·조금 벌리는 dangle 보다 넓다) 무릎이 가슴으로 올라오며(접힌 다리) 골반이 조금 오른다(예비) → 유지, 팩이 적는 메타로:
## 속도("zip_v" −1..1, +면 +x 로 간다; 없으면 제 박자): 몸통이 속도만큼 트롤리 뒤로 처져 기울고 접힌 다리가 7.5rad/s 로 흔들린다, 고개는 케이블 아래 건너편 발판을 본다;
## 제동("zip_brk" 0..1): 몸이 트롤리 앞으로 쏠린다(기울기가 뒤집히고 다리가 조금 앞으로, 고개가 든다);
## 내려놓기("zip_set" 0..1, 팩의 land_s 에 걸쳐): 다리가 내려와 발판을 디디려 하고 몸통이 서고 팔꿈치가 조금 접힌다 — 손은 아직 가로대에
## → 발판에 서서 로더가 자세를 비우면 stick3d 의 블렌딩이 팔을 내리고 무릎을 편다(회수). 몸이 보는 쪽(f._yaw)으로 '앞'을 읽는다. 메타가 없으면 3초 한 바퀴의 제 박자(2.2 미끄러짐 → 0.4 제동 → 0.4 내려놓기; 주민·시연용).
## dangle(가로대에 매달려 다리를 앞뒤로 펌프질)·kite(한 줄을 모아 쥐고 다리가 뒤로 펄럭인다)·haul(종 줄을 위아래로 당긴다)과 다르다: 이건 두 손을 벌려 쥐고 다리를 접은 채 뒤로 처졌다 앞으로 쏠리는 몸. stick3d_kite.gd 처럼 주제별 파일

const GRAB_T := 0.2
const LAP := 3.0          # 제 박자 한 바퀴
const SLIDE_T := 2.2      # 제 박자의 미끄러짐
const BRAKE_T := 0.4      # 제 박자의 제동
const TUCK_HIP := 1.0     # 엉덩이: 가슴으로 올린 무릎
const TUCK_KNEE := 1.6    # 무릎: 접힌 다리
const SPREAD := 0.45      # 어깨(옆으로): 벌려 쥔 손

## 잡은 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, GRAB_T, f.pose_t)

## 세상 x 의 속도 −1..1 — 팩이 적어 준 값, 없으면 제 박자(미끄러짐·제동 동안 1, 내려놓기 0)
static func raw(f: Stick3D) -> float:
	if f.has_meta("zip_v"): return clampf(float(f.get_meta("zip_v")), -1.0, 1.0)
	return 1.0 if fmod(f._t, LAP) < SLIDE_T + BRAKE_T else 0.0

## 몸 앞쪽으로 가는 방향 ±1 — 속도의 부호를 보는 방향(yaw, +x 를 보면 sin 이 +)으로 뒤집는다(속도 0 이면 앞)
static func dirn(f: Stick3D) -> float:
	var r := raw(f)
	return (1.0 if r >= 0.0 else -1.0) * (1.0 if sin(f._yaw) >= 0.0 else -1.0)

## 빠르기 0..1
static func spd(f: Stick3D) -> float:
	return absf(raw(f))

## 제동 0..1 — 팩이 적어 준 값, 없으면 제 박자
static func brk(f: Stick3D) -> float:
	if f.has_meta("zip_brk"): return clampf(float(f.get_meta("zip_brk")), 0.0, 1.0)
	var q := fmod(f._t, LAP)
	return 0.0 if q < SLIDE_T else clampf((q - SLIDE_T) / BRAKE_T, 0.0, 1.0)

## 내려놓기 0..1 — 팩이 적어 준 값, 없으면 제 박자
static func setk(f: Stick3D) -> float:
	if f.has_meta("zip_set"): return clampf(float(f.get_meta("zip_set")), 0.0, 1.0)
	var q := fmod(f._t, LAP)
	return 0.0 if q < SLIDE_T + BRAKE_T else clampf((q - SLIDE_T - BRAKE_T) / (LAP - SLIDE_T - BRAKE_T), 0.0, 1.0)

## 골반이 조금 오르고(접힌 몸), 몸통은 속도만큼 뒤로 처지다 제동에 앞으로 쏠린다 — 내려놓으면 선다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var st := setk(f); var br := brk(f)
	f.pelvis.position.y = StickRig.HIP_Y + 0.05 * kk * (1.0 - st)
	return (dirn(f) * (-0.3 * spd(f) * (1.0 - br) + 0.35 * br) + 0.04 * sin(f._t * 7.5)) * (1.0 - st) * kk

## 팔다리 — 두 팔은 머리 위로 벌려 가로대를(팔꿈치는 잡은 뒤 펴지고 내려놓으며 조금 접힌다), 두 다리는 가슴으로 접힌 채 흔들리고(제동에 조금 앞으로) 내려놓으면 내려온다, 고개는 건너편 발판을 보다 제동에 든다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "zip": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var st := setk(f); var br := brk(f)
	var wob := sin(f._t * 7.5 + s * 0.4) * 0.1 * (1.0 - st)
	var hip_v := lerpf(TUCK_HIP + 0.15 * br + wob, 0.15, st)
	var knee_v := lerpf(TUCK_KNEE + 0.1 * br, 0.3, st)
	hip.rotation.x = -(hip_v * kk)
	knee.rotation.x = knee_v * kk
	sh.rotation.x = -(0.1 + 2.75 * kk); sh.rotation.z = -s * (0.1 + SPREAD * kk); el.rotation.x = -(0.5 - 0.3 * kk + 0.25 * st * kk)   # 어깨가 밖으로 — 두 손이 벌려 가로대에
	if s > 0.0: f.neck.rotation.x += (0.25 - 0.35 * br) * (1.0 - st) * kk
	return true
