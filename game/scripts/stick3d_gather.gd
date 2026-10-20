class_name GatherPoses
extends RefCounted
## 책을 모으는 자세(Climb 팩 barrow 의 주민 반쪽 — 책 담당, run 185; 운영자 보드의 '상자·가구 나르기' 가족의 셋째 자세): `gather` 더미 곁에 한 무릎을 꿇고(0.3 s), 오른손이 한 권씩 바닥에서 가슴으로 퍼 올려(한 권 0.4 s) 왼 팔뚝 위에 쌓고(더미가 팔뚝에 오른다 — 책 노드는 책 담당이 torso 에 붙인다), 들고 일어서는(0.3 s) 몸 — 그 뒤 들고 걷는 다리(gat_w)와 통에 쏟는 팔(gat_d).
## 시계는 책 담당(climb_page.gd)이 적는다: meta "gat_t"(자세에 든 뒤 시간), meta "gat_n"(모을 권수 — 퍼 올리기가 이만큼 되풀이된다), meta "gat_w"(들고 걷는 속도 0..1 — 다리가 짧게 걷는다, 상체는 선 채), meta "gat_d"(쏟는 몫 0..1 — 왼 팔뚝이 앞으로 기울고 오른손이 받친다). 메타가 없으면 pose_t 로 혼자 한 번 돈다(점검·시연용, 넷).
## 꿇기(0..0.3): 오른 허벅지가 뒤로(+0.3) 오른 무릎이 접혀(1.6) 바닥에, 왼 허벅지는 앞으로(−1.2) 왼 무릎 접혀(1.3) 발이 앞에; 골반이 0.18 내려앉고 상체가 0.4 숙이고 고개가 더미를 본다(+0.5); 왼팔은 가슴 앞에 팔뚝을 눕혀(어깨 −1.1·z 0.2·팔꿈치 −1.5)
## → 퍼 올리기(권마다 0.4 s): 오른손이 가슴(어깨 −1.0·팔꿈치 −1.4)에서 바닥으로 내려갔다(sin: 어깨 −0.4·팔꿈치 −0.1) 올라오고 상체가 0.15 더 숙였다 돌아오고 고개가 손을 따른다; 왼 팔뚝이 받는 무게에 0.1 내려앉는다
## → 서기(마지막 0.3): 다리·골반·상체가 돌아오고 왼팔은 그대로 가슴 앞 → 걷기(gat_w): 다리가 1.4 Hz 로 짧게(0.3) 걷는다 → 쏟기(gat_d): 왼 어깨가 −1.4 로 오르며 팔꿈치가 −0.6 으로 풀려 팔뚝이 앞으로 기울고 오른손이 밑을 받친다(어깨 −0.9·팔꿈치 −0.9), 상체 0.2 숙임. 0.8 Hz 숨에 골반이 조금 흔들린다 — 정지화가 아니다.
## lug(쪼그려 안아 든다)·heft(손잡이를 당겨 재 본다)·stoop(하나를 집는다)과 다르다: 이건 바닥의 여럿을 한 권씩 팔뚝에 쌓는 몸. stick3d_heft.gd 처럼 주제별 파일

const KNEEL_T := 0.3                        # 꿇는 시간(s)
const SCOOP_T := 0.4                        # 한 권(s)
const STAND_T := 0.3                        # 일어서는 시간(s)
const DROP_T := 0.3                         # 통에 쏟는 시간(s) — gat_d 는 책 담당이 이 시간으로 올린다
const DEFAULT_N := 4                        # 메타 없을 때의 권수
const STRIDE_HZ := 1.4
const BREATHE_HZ := 0.8
const DROP := 0.18                          # 꿇으면 골반이 내려앉는 높이(m)
const LEAN := 0.4; const DIP := 0.15        # 꿇은 상체, 퍼 올릴 때 더 숙이는 몫
const R_HIP := 0.3; const R_KNEE := 1.6     # 오른다리(무릎이 바닥에)
const L_HIP := -1.2; const L_KNEE := 1.3    # 왼다리(발이 앞에)
const HOLD_SH := 1.1; const HOLD_Z := 0.2; const HOLD_EL := 1.5   # 왼팔 — 팔뚝을 가슴 앞에 눕힌다
const CHEST_SH := 1.0; const CHEST_EL := 1.4                     # 오른손이 가슴에
const FLOOR_SH := 0.4; const FLOOR_EL := 0.1                     # 오른손이 바닥에
const SAG := 0.1                                                  # 받는 무게에 왼 팔뚝이 내려앉는 몫
const LOOK := 0.5
const TIP_SH := 1.4; const TIP_EL := 0.6; const UNDER_SH := 0.9; const UNDER_EL := 0.9; const TIP_LEAN := 0.2   # 쏟기

## 자세에 든 뒤 시간(s) — 책 담당의 메타, 없으면 pose_t
static func since(f: Stick3D) -> float:
	if f.has_meta("gat_t"): return maxf(0.0, float(f.get_meta("gat_t")))
	return f.pose_t

## 모을 권수 — 책 담당의 메타, 없으면 DEFAULT_N
static func count(f: Stick3D) -> int:
	if f.has_meta("gat_n"): return maxi(1, int(f.get_meta("gat_n")))
	return DEFAULT_N

## 꿇기·퍼 올리기·서기 전체(s)
static func total(n: int) -> float:
	return KNEEL_T + SCOOP_T * float(n) + STAND_T

## 다 했나(모으기만 — 걷기·쏟기는 책 담당의 메타가 끝낸다)
static func done(f: Stick3D) -> bool:
	return since(f) >= total(count(f))

## [kneel, dip, hand] — 꿇은 몫(0.3 에 꿇어 마지막 0.3 에 일어선다), 퍼 올리는 손의 내려감 0..1(권마다 sin), 지금 손이 쥔 것의 몫(권수 진행 0..1 — 왼 팔뚝의 무게)
static func phases(f: Stick3D) -> Array:
	var u := since(f); var n := count(f); var tot := total(n)
	var kneel := smoothstep(0.0, KNEEL_T, u) * (1.0 - smoothstep(tot - STAND_T, tot, u))
	var q := (u - KNEEL_T) / SCOOP_T
	var dip := sin(PI * fposmod(q, 1.0)) if q >= 0.0 and q < float(n) else 0.0
	var hand := clampf(q, 0.0, float(n)) / float(n)
	return [kneel, dip, hand]

static func walk(f: Stick3D) -> float:
	return clampf(float(f.get_meta("gat_w")), 0.0, 1.0) if f.has_meta("gat_w") else 0.0

static func drop(f: Stick3D) -> float:
	return clampf(float(f.get_meta("gat_d")), 0.0, 1.0) if f.has_meta("gat_d") else 0.0

## 골반은 꿇으면 내려앉고 숨에 흔들린다; 상체는 꿇어 숙이고 퍼 올릴 때 더 숙이고 쏟을 때 조금 숙인다
static func lean(f: Stick3D) -> float:
	var ph := phases(f); var kneel := float(ph[0]); var dip := float(ph[1])
	f.pelvis.position.y = StickRig.HIP_Y - DROP * kneel + 0.01 * sin(f._t * TAU * BREATHE_HZ)
	return LEAN * kneel + DIP * dip * kneel + TIP_LEAN * drop(f)

## 팔다리 — 오른다리(s > 0): 무릎이 바닥에; 왼다리: 발이 앞에; 걷기(gat_w)엔 둘 다 짧게 걷는다; 왼팔(s < 0): 팔뚝을 가슴 앞에 눕혀 무게에 내려앉다 쏟을 때 앞으로 기운다; 오른팔: 가슴과 바닥을 오간다, 쏟을 때 밑을 받친다; 고개는 손을 따른다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "gather": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(f); var kneel := float(ph[0]); var dip := float(ph[1]); var hand := float(ph[2])
	var w := walk(f); var d := drop(f)
	var stride := s * sin(f._t * TAU * STRIDE_HZ) * 0.3 * w
	var breathe := sin(f._t * TAU * BREATHE_HZ) * 0.03
	hip.rotation.x = (R_HIP if s > 0.0 else L_HIP) * kneel - stride
	knee.rotation.x = (R_KNEE if s > 0.0 else L_KNEE) * kneel + (0.1 + 0.3 * maxf(0.0, s * sin(f._t * TAU * STRIDE_HZ + 0.9))) * w + breathe * (1.0 - kneel)
	if s < 0.0:
		sh.rotation.x = -HOLD_SH - SAG * hand * dip * kneel - (TIP_SH - HOLD_SH) * d
		sh.rotation.z = -s * HOLD_Z
		el.rotation.x = -HOLD_EL + (HOLD_EL - TIP_EL) * d
	else:
		sh.rotation.x = -(CHEST_SH - (CHEST_SH - FLOOR_SH) * dip) * kneel - UNDER_SH * d - 0.1 * (1.0 - kneel) * (1.0 - d)
		sh.rotation.z = 0.0
		el.rotation.x = -(CHEST_EL - (CHEST_EL - FLOOR_EL) * dip) * kneel - UNDER_EL * d
		f.neck.rotation.x += LOOK * kneel * (0.6 + 0.4 * dip) + 0.3 * d   # 더미를, 손을, 통을 본다
	return true
