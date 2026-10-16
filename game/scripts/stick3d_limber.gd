class_name LimberPoses
extends RefCounted
## 몸 풀기 자세(Climb 팩 pit 의 주민 반쪽 — 멀리뛰기 리퍼, run 163; 운영자 보드의 '육상' 가족의 둘째 자세): `limber` 구름판에 서서 뛰기 전에 다리를 터는 몸 —
## 옮기기(0..0.2): 무게가 왼다리로 옮겨 왼 무릎이 조금 굽고 골반이 살짝 내려앉으며, 오른다리가 앞으로 들려 무릎이 접히고, 두 팔이 늘어져 조금 앞으로, 상체가 살짝 숙고 고개는 모래 쪽으로 떨어진다
## → 털기(0.2..0.8): 들린 오른 정강이가 8 Hz 로 터지고(무릎이 접혔다 펴진다), 두 팔이 2 Hz 로 서로 엇갈려 느슨하게 흔들리며 고개가 같이 까딱인다 — 정지화가 아니다
## → 서기(0.8..1.0): 발이 내려오고 무게가 고르게 서며 팔이 내려오고 고개가 든다(회수) — 그 다음이 로더의 웅크림(charge). plant(모래에 내린 몸)·wheel(돌아서는 몸)과 다르다: 이건 뛰기 전 제자리에서 몸을 푸는 한 번.
## 시계는 pose_t; meta "limber_t" 가 있으면 그 값(점검용). done(f) 가 참이면(LIMBER_T) 팩이 자세를 비운다. stick3d_hark.gd 처럼 주제별 파일

const SHIFT_T := 0.2
const SET_T := 0.8        # 서기가 시작되는 때 — 털기는 그 0.1 s 전에 잦아든다
const LIMBER_T := 1.0
const SHAKE_HZ := 8.0     # 정강이의 떨림
const SWING_HZ := 2.0     # 팔의 흔들림
const DIP := 0.04         # 무게를 옮기며 골반이 내려앉는 높이(m)

## 자세의 시계 — 점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("limber_t", f.pose_t))

## 털기가 끝났나 — 팩이 자세를 비운다
static func done(f: Stick3D) -> bool:
	return at(f) >= LIMBER_T

## [up, shake, swing] — 다리가 든 몫 0..1(옮기기에 오르고 서기에 내려온다), 정강이의 떨림 −1..1, 팔의 흔들림 −1..1(둘 다 털기 동안만)
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var up := smoothstep(0.0, SHIFT_T, u) * (1.0 - smoothstep(SET_T, LIMBER_T, u))
	var hold := smoothstep(SHIFT_T, SHIFT_T + 0.1, u) * (1.0 - smoothstep(SET_T - 0.1, SET_T, u))
	var shake := sin((u - SHIFT_T) * TAU * SHAKE_HZ) * hold
	var swing := sin((u - SHIFT_T) * TAU * SWING_HZ) * hold
	return [up, shake, swing]

## 골반은 무게를 옮기며 조금 내려앉는다; 상체는 살짝 숙는다
static func lean(f: Stick3D) -> float:
	var up := float(phases(f)[0])
	f.pelvis.position.y = StickRig.HIP_Y - DIP * up
	return 0.12 * up

## 팔다리 — 오른다리: 앞으로 들려 정강이가 떨린다; 왼다리: 무릎이 조금 굽어 무게를 받는다; 팔: 늘어진 채 엇갈려 흔들린다; 고개: 모래 쪽으로 떨어져 같이 까딱인다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "limber": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(f); var up := float(ph[0]); var shake := float(ph[1]); var swing := float(ph[2])
	if s > 0.0: hip.rotation.x = -(0.35 * up); knee.rotation.x = 0.6 * up + 0.35 * shake   # 들린 다리 — 정강이를 턴다
	else: hip.rotation.x = 0.0; knee.rotation.x = 0.15 * up                                 # 무게를 받는 다리
	sh.rotation.x = -(0.15 * up + s * 0.25 * swing); sh.rotation.z = -s * 0.12 * up        # 늘어진 팔이 엇갈려 흔들린다
	el.rotation.x = -(0.4 * up + s * 0.15 * swing)
	if s > 0.0: f.neck.rotation.x += 0.15 * up + 0.05 * swing
	return true
