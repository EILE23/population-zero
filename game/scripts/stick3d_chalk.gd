class_name ChalkPoses
extends RefCounted
## 손에 초크를 치는 자세(Climb 팩 weight 의 주민 반쪽 — 시계 감는 이, run 175; 운영자 보드의 '역도' 가족, press 의 앞): `chalk` 추를 들기 전에 두 손바닥을 맞부딪쳐 가루를 날리고 손가락을 비벼 손을 털어 내는 몸 — 몸은 카메라를 보고 선다.
## 시계는 하나고 감는 이(climb_winder.gd)가 적는다: meta "chalk_t"(자세에 든 뒤 시간 — 가루 먼지 퍼프는 감는 이가 clap_between 으로 때를 묻는다). 메타가 없으면 pose_t 로 혼자 한 번 돈다(점검·시연용).
## 박수(0..0.667): 두 팔을 가슴 앞에 들고(어깨 −1.0, 팔꿈치 −1.4) 3 Hz 로 두 번 손이 모였다 벌어진다(모임이 CLAP 1, 1/6·1/2 s 에 가루가 난다), 무릎이 박수에 조금 튄다, 고개는 손을 본다 → 비빔(0.667..1.067): 손이 모인 채 8 Hz 로 팔꿈치가 어긋나게 잔떨린다 → 털기(1.067..1.367): 팔이 옆으로 내려오며 한 번 바깥으로 흔들려 돌아오고 고개가 든다 — 정지화가 아니다.
## press(무게를 머리 위에 버티는 몸)·rub(잠에서 깨 눈을 비비는 몸)·wipe(소매로 닦는 몸)와 다르다: 이건 다음 일을 위해 제 손을 채비하는 몸 — 끝나면 바로 press 가 온다. stick3d_press.gd 처럼 주제별 파일

const CLAP_HZ := 3.0                     # 박수의 박자
const CLAP_T := 2.0 / CLAP_HZ            # 박수 두 번(s)
const RUB_T := 0.4                       # 손가락 비빔(s)
const SHAKE_T := 0.3                     # 손 털기(s)
const TOTAL := CLAP_T + RUB_T + SHAKE_T  # 자세 전체(s) — 감는 이가 이만큼 뒤 press 로
const RUB_HZ := 8.0
const APART := 0.4                       # 벌린 손의 어깨 z(rad)
const MEET := 0.05                       # 모인 손의 어깨 z(rad)
const SETTLE := 0.05                     # 비빔에 드는·나는 시간(s)

## 자세에 든 뒤 시간(s) — 감는 이의 메타, 없으면 pose_t
static func since(f: Stick3D) -> float:
	if f.has_meta("chalk_t"): return maxf(0.0, float(f.get_meta("chalk_t")))
	return f.pose_t

## 다 했나
static func done(f: Stick3D) -> bool:
	return since(f) >= TOTAL

## 손이 모인 정도 0..1 — 박수 동안 3 Hz 의 반원, 1/6·1/2 s 에 1
static func clap(u: float) -> float:
	if u >= CLAP_T: return 0.0
	return 0.5 - 0.5 * cos(u * TAU * CLAP_HZ)

## (u0, u1] 사이에 손이 맞부딪친 때가 있나 — 가루 퍼프의 때(감는 이가 묻는다)
static func clap_between(u0: float, u1: float) -> bool:
	for i in 2:
		var hit := (float(i) + 0.5) / CLAP_HZ
		if hit > u0 and hit <= u1: return true
	return false

## 비빔의 세기 0..1 — 박수 끝에 들고 털기 앞에 난다
static func rub(u: float) -> float:
	return smoothstep(CLAP_T, CLAP_T + SETTLE, u) * (1.0 - smoothstep(CLAP_T + RUB_T - SETTLE, CLAP_T + RUB_T, u))

## 팔이 내려온 정도 0..1 — 털기
static func shake(u: float) -> float:
	return smoothstep(CLAP_T + RUB_T, TOTAL, u)

## 상체 — 손을 보는 동안 조금 숙인다
static func lean(f: Stick3D) -> float:
	return 0.12 * (1.0 - shake(since(f)))

## 팔다리 — 두 팔은 가슴 앞에 들려 박수에 모였다 벌어지고 비빔에 팔꿈치가 어긋나게 떨리다 털기에 옆으로 내려오며 한 번 바깥으로 흔들린다; 다리는 선 채 박수에 무릎이 튄다; 고개는 손을 보다 털기에 든다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "chalk": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var u := since(f); var c := clap(u); var r := rub(u); var k := shake(u); var up := 1.0 - k
	var together := maxf(c, r)
	var wig := sin(u * TAU * RUB_HZ) * 0.06 * r   # 비빔 — 두 팔꿈치가 어긋나게(아래 s 가 붙는다), 정지화가 아니다
	sh.rotation.x = -(0.1 + 0.9 * up)
	sh.rotation.z = -s * ((APART - (APART - MEET) * together) * up + 0.2 * sin(PI * k))   # 벌림·모임, 털기엔 한 번 바깥으로
	el.rotation.x = -(0.35 + 1.05 * up) + s * wig
	hip.rotation.x = -0.05; knee.rotation.x = 0.1 + 0.05 * c
	if s > 0.0: f.neck.rotation.x += 0.25 * up   # 손을 본다(+), 털기에 든다
	return true
