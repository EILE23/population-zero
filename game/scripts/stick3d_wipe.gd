class_name WipePoses
extends RefCounted
## 닦기 자세(Climb 팩 sundial 의 주민 반쪽 — 다이얼 키퍼, run 158; 운영자 보드의 '쓸기·닦기' 가족의 첫 자세): `wipe` 발밑 돌판의 그노몬을 소매로 닦는 몸 —
## stoop(바닥의 동전을 쥐어 주머니로)·rub(침대에서 깨며 눈을 비빈다 — 누운 골반)과 다르다: 이건 서서 무릎을 굽혀 숙인 채 오른 소매가 낮은 것을 앞뒤로 문지르는 몸, 손에 남는 것이 없다.
## 뻗기(0..0.4): 무릎이 굽으며 골반이 내려앉고 허리가 깊이 숙는다, 오른팔이 앞 아래 그노몬으로 뻗고 왼손은 왼 무릎을 짚어 버틴다, 고개는 손을 본다
## → 닦기(0.4..1.6): 오른 소매가 2.5 Hz 로 좌우로 문지른다(어깨 z 가 흔들리고 팔꿈치가 같이 접혔다 펴진다), 어깨가 문지름에 조금씩 따라 내려갔다 오르고 고개가 손을 따라 돈다 — 정지화가 아니다
## → 털기(1.6..2.0): 몸이 펴지며 오른손이 올라와 소매를 한 번 턴다(8 Hz 의 잦아드는 흔들림), 왼손이 무릎에서 떨어진다. 로더가 자세를 비우면 stick3d 의 블렌딩이 마저 편다(회수).
## 시계는 pose_t; meta "wipe_t" 가 있으면 그 값(점검·주민 시연용). done(f) 가 참이면(2.0초) 팩이 자세를 비운다. stick3d_squint.gd 처럼 주제별 파일

const REACH_T := 0.4
const RUB_T := 1.2         # 닦는 길이 — 2.0 = 뻗기 + 닦기 + 털기
const SHAKE_T := 0.4
const WIPE_T := 2.0
const ENTER_T := 0.1
const RUB_HZ := 2.5        # 소매가 오가는 박자
const DIP := 0.14          # 무릎이 굽으며 골반이 내려앉는 높이(m)

## 자세에 든 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, ENTER_T, f.pose_t)

## 자세의 시계 — 팩·점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("wipe_t", f.pose_t))

## 닦기가 끝났나 — 팩이 자세를 비운다
static func done(f: Stick3D) -> bool:
	return at(f) >= WIPE_T

## [bend, rub, shake] — 숙인 몫 0..1(뻗기에 숙고 털기에 선다), 소매 −1..1(닦는 동안만 좌우), 소매 털기 0..1(털기의 잦아드는 흔들림)
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var up := smoothstep(REACH_T + RUB_T, WIPE_T, u)
	var bend := smoothstep(0.0, REACH_T, u) * (1.0 - up)
	var in_rub := clampf((u - REACH_T) / 0.2, 0.0, 1.0) * (1.0 - up)
	var rub := sin((u - REACH_T) * TAU * RUB_HZ) * in_rub
	var shake := sin((u - REACH_T - RUB_T) * TAU * 8.0) * exp(-(u - REACH_T - RUB_T) * 6.0) * up if u > REACH_T + RUB_T else 0.0
	return [bend, rub, shake]

## 골반은 무릎이 굽은 만큼 내려앉는다; 몸통은 깊이 숙고 문지름마다 조금씩 더 내려갔다 온다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var ph := phases(f); var bend := float(ph[0]); var rub := float(ph[1])
	f.pelvis.position.y = StickRig.HIP_Y - DIP * bend * kk
	return (0.75 * bend + 0.04 * absf(rub)) * kk

## 팔다리 — 다리: 두 무릎이 굽는다(오른쪽이 조금 더); 오른팔: 앞 아래로 뻗어 소매가 좌우로 문지르고 털기에 올라와 턴다; 왼팔: 왼 무릎을 짚는다; 고개는 손을 보고 문지름을 따라 돈다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "wipe": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var ph := phases(f); var bend := float(ph[0]); var rub := float(ph[1]); var shake := float(ph[2])
	var b := bend * kk
	hip.rotation.x = -(0.55 + (0.1 if s > 0.0 else 0.0)) * b; knee.rotation.x = (0.9 + (0.15 if s > 0.0 else 0.0)) * b
	if s > 0.0:
		sh.rotation.x = -(1.25 * b + 0.9 * shake * kk); sh.rotation.z = -(0.2 + 0.35 * rub) * b - 0.3 * shake * kk   # 뻗은 팔이 좌우로 문지르고, 털 땐 들려 흔들린다
		el.rotation.x = -(0.25 + 0.15 * absf(rub)) * b - 0.6 * absf(shake) * kk
		f.neck.rotation.x += 0.5 * b; f.neck.rotation.y += 0.2 * rub * b   # 손을 보고 문지름을 따라 돈다
	else:
		sh.rotation.x = -(0.5 * b); sh.rotation.z = 0.15 * b; el.rotation.x = -(0.95 * b)   # 왼손은 무릎에
	return true
