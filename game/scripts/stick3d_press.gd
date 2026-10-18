class_name PressPoses
extends RefCounted
## 역도 가족 자세(Climb 콘텐츠 팩 weight, run 174 — data/climb/weight.json, scripts/games/climb_weight.gd; 운영자 보드의 '스포츠 — 역도' 가족의 첫 자세): `press` 바닥의 시계추를 쪼그려 잡아 가슴까지 끌어올리고(클린) 머리 위로 밀어 올려(프레스) 버티다 고리에 거는 몸 — 몸은 카메라를 보고 추는 두 손 사이에서 똑바로 오른다(정면 역도).
## 시계는 셋이고 팩이 적는다: meta "press_t"(든 뒤 시간 — 잡기 0.3·클린 0.3·프레스 0.35·그 뒤는 버티기), meta "press_end"("hook" 걸었다 | "drop" 놓쳤다), meta "press_u"(끝난 뒤 시간). 메타가 없으면 pose_t 로 혼자 한 번 돈다(점검·주민 시연용: 잡기·클린·프레스 뒤 1.0 s 버티고 0.3 s 에 건다).
## 잡기(0..0.3): 골반이 깊이 내려앉고(DIP) 상체가 숙여 두 팔이 발 사이의 추로 곧게 내려가고 고개는 추를 본다 → 클린(0.3..0.6): 몸이 서며 팔꿈치가 접혀 손이 가슴 앞으로, 무릎이 한 번 튄다(받는 딥) → 프레스(0.6..0.95): 팔이 머리 위로 곧게 펴지고 다리가 앞뒤로 갈리고(리드 앞·트레일 뒤) 상체가 조금 젖혀 고개가 추를 올려다본다
## → 버티기(0.95..): 팔은 10 Hz 로 떨고 추처럼 1.5 Hz 로 옆으로 흔들리며 다리는 0.35 s 에 모인다, 숨에 무릎이 흔들린다 → 걸기(hook, 0.3): 팔이 내려오고 어깨를 털며 고개가 뒤로 잠깐 → 선다 / 놓침(drop, 0.4): 팔이 0.15 s 에 떨어지며 무릎을 굽혀 움츠리고 고개를 숙였다가 0.4 s 에 선다 — 정지화가 아니다.
## stomp(발로 판을 누른다)·haul(밧줄을 당긴다)·heave(승강기 밧줄을 끌어올린다)와 다르다: 이건 무게를 머리 위에 버티는 몸 — 시간이 다 가야 손을 놓는다. stick3d_stroke.gd 처럼 주제별 파일

const GRIP_T := 0.3       # 쪼그려 잡기(s) = climb_weight grip_s
const CLEAN_T := 0.3      # 클린(s) = clean_s
const PRESS_T := 0.35     # 프레스(s) = press_s
const RISE_T := 0.95      # 잡기부터 머리 위까지(s) = rise_s
const DEMO_HOLD := 1.0    # 메타 없이 돌 때 버티는 시간(s) — 8 kg 추의 hold
const HOOK_T := 0.3       # 걸기(s) = hook_s
const DROP_T := 0.4       # 놓침의 회수(s) = recover_s
const FLING_T := 0.15     # 놓침에 팔이 떨어지는 시간(s)
const SPLIT_T := 0.35     # 버티기에 갈린 다리가 모이는 시간(s)
const TREMBLE_HZ := 10.0
const SWAY_HZ := 1.5
const BREATHE_HZ := 0.8
const DIP := 0.2          # 쪼그림에 골반이 내려앉는 높이(m)

## 든 뒤 시간(s) — 팩의 메타, 없으면 pose_t
static func since(f: Stick3D) -> float:
	if f.has_meta("press_t"): return maxf(0.0, float(f.get_meta("press_t")))
	return f.pose_t

## 어떻게 끝났나 — "hook" | "drop" | ""(아직 들고 있다)
static func end(f: Stick3D) -> String:
	if f.has_meta("press_end"): return String(f.get_meta("press_end"))
	if f.has_meta("press_t"): return ""
	return "hook" if f.pose_t >= RISE_T + DEMO_HOLD else ""

## 끝난 뒤 시간(s)
static func end_u(f: Stick3D) -> float:
	if f.has_meta("press_end"): return maxf(0.0, float(f.get_meta("press_u", 0.0)))
	if f.has_meta("press_t"): return 0.0
	return maxf(0.0, f.pose_t - RISE_T - DEMO_HOLD)

## 시간으로 돌 때 끝났나 — 팩이 모는 동안은 팩이 busy 로 비운다
static func done(f: Stick3D) -> bool:
	return not f.has_meta("press_t") and end(f) == "hook" and end_u(f) >= HOOK_T

## [g, c, p, hu, hk, dr, fl] — 잡기(0..0.3 에 든다), 클린(0.3..0.6), 프레스(0.6..0.95), 버틴 시간(s), 걸기(끝난 뒤 0..0.3), 놓침의 회수(0..0.4), 놓침의 팔 떨어짐(0..0.15)
static func phases(f: Stick3D) -> Array:
	var u := since(f)
	var g := smoothstep(0.0, GRIP_T, u)
	var c := smoothstep(GRIP_T, GRIP_T + CLEAN_T, u)
	var p := smoothstep(GRIP_T + CLEAN_T, RISE_T, u)
	var hu := maxf(0.0, u - RISE_T)
	var e := end(f); var eu := end_u(f)
	var hk := smoothstep(0.0, HOOK_T, eu) if e == "hook" else 0.0
	var dr := smoothstep(0.0, DROP_T, eu) if e == "drop" else 0.0
	var fl := smoothstep(0.0, FLING_T, eu) if e == "drop" else 0.0
	return [g, c, p, hu, hk, dr, fl]

## 골반은 쪼그림에 깊이 내려앉고 클린 끝에 한 번 받는 딥, 갈린 다리에 조금, 놓침에 움츠려 내려앉는다; 상체는 잡기에 숙이고 프레스에 조금 젖히고 놓침에 앞으로 움츠린다
static func lean(f: Stick3D) -> float:
	var ph := phases(f); var g := float(ph[0]); var c := float(ph[1]); var p := float(ph[2]); var hk := float(ph[4]); var dr := float(ph[5]); var fl := float(ph[6])
	var stay := (1.0 - hk) * (1.0 - dr)
	var dip := DIP * g * (1.0 - c) + 0.12 * sin(c * PI) * (1.0 - p) + 0.05 * p
	f.pelvis.position.y = StickRig.HIP_Y - dip * stay - 0.1 * fl * (1.0 - dr)
	return (0.55 * g * (1.0 - c) - 0.12 * p) * stay + 0.3 * fl * (1.0 - dr)

## 팔다리 — 두 팔: 잡기에 발 사이로 곧게 내려가고(앞으로 조금) 클린에 앞으로 들려 팔꿈치가 접히고(손이 가슴) 프레스에 머리 위로 곧게 펴진다, 버티기엔 10 Hz 떨림과 1.5 Hz 흔들림(두 어깨가 같은 쪽으로 — 추가 흔들린다), 걸기에 내려오며 어깨를 턴다, 놓침에 0.15 s 에 떨어진다;
## 두 다리: 쪼그림(엉덩이 −1.1·무릎 1.6), 받는 딥, 프레스에 리드(오른) 앞·트레일(왼) 뒤로 갈렸다 0.35 s 에 모인다, 버티기엔 숨에 무릎이 흔들린다, 놓침에 움츠린다; 고개는 추를 보다(잡기, +) 올려다보고(프레스, −) 걸기 가운데 뒤로 잠깐, 놓침에 숙인다; 가슴은 프레스에 든다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "press": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(f); var g := float(ph[0]); var c := float(ph[1]); var p := float(ph[2]); var hu := float(ph[3]); var hk := float(ph[4]); var dr := float(ph[5]); var fl := float(ph[6])
	var e := end(f); var eu := end_u(f)
	var stay := (1.0 - hk) * (1.0 - dr)
	var arm_stay := (1.0 - hk) * (1.0 - fl)
	var lead := s > 0.0
	var tremble := sin(f._t * TAU * TREMBLE_HZ + s) * 0.05 * p * arm_stay                       # 버티기의 잔떨림 — 정지화가 아니다
	var sway := sin(f._t * TAU * SWAY_HZ) * 0.08 * p * arm_stay * smoothstep(0.0, 0.5, hu)   # 추처럼 — 버티기에 든다
	var shake := sin(eu * TAU * 3.0) * 0.12 * (1.0 - hk) if e == "hook" else 0.0            # 걸고 어깨를 턴다
	var breathe := sin(f._t * TAU * BREATHE_HZ) * 0.03 * p * stay
	var squat := g * (1.0 - c) * stay
	var dipk := sin(c * PI) * (1.0 - p) * stay   # 받는 딥
	var split := p * (1.0 - smoothstep(0.0, SPLIT_T, hu)) * stay
	var cower := fl * (1.0 - dr)
	sh.rotation.x = -(0.2 * g * (1.0 - c) + 1.3 * c * (1.0 - p) + 2.95 * p) * arm_stay + tremble + 0.25 * cower
	sh.rotation.z = (-s * 0.12 * g + sway) * arm_stay + shake
	el.rotation.x = -(2.3 * c * (1.0 - p)) * arm_stay - 0.5 * tremble
	hip.rotation.x = -(1.1 * squat + 0.35 * dipk) + (-0.45 if lead else 0.35) * split - 0.5 * cower
	knee.rotation.x = 1.6 * squat + 0.6 * dipk + (0.5 if lead else 0.25) * split + 0.08 * p * stay + 0.7 * cower + breathe
	if s > 0.0:
		f.neck.rotation.x += 0.5 * squat - 0.4 * p * stay + 0.45 * cower - 0.3 * sin(PI * hk)   # 추를 보다(+) 올려다보고(−) 걸기 가운데 뒤로, 놓침에 숙인다
		f.chest.rotation.x += -0.12 * p * stay   # 가슴이 든다
	return true
