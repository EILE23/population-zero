class_name FlourishPoses
extends RefCounted
## 절 자세(Climb 팩 tightrope 의 주민 반쪽 — 외줄꾼, run 165; 운영자 보드의 '결혼식·졸업식' 가족의 첫 자세): `flourish` 밧줄을 다 건넌 몸이 고리 옆에서 하는 외줄꾼의 절 —
## 펴기(0..0.15): 오른팔이 허리에 접히고(어깨가 앞·안쪽으로, 팔꿈치가 깊이) 왼팔이 옆으로 수평히 펴지며, 오른발이 뒤로 한 발 물러나 무릎이 살짝 굽는다(예비)
## → 절(0.15..0.75, 0.6 s 한 박자): 상체가 사인 곡선으로 숙였다 들리고(0.6 rad), 고개는 상체보다 먼저 내려가 먼저 든다, 편 왼팔은 숙일수록 위로 들려 펄럭인다(유지 — 어느 순간도 정지화가 아니다)
## → 거두기(0.75..1.0): 두 팔이 내려오고 발이 돌아와 고르게 선다(회수). bow(FightPoses — 두 팔을 늘어뜨린 맨 절)·tiptoe(밧줄 위의 몸)와 다르다: 이건 한 팔을 허리에, 한 팔을 펴 든 무대의 절.
## 이름이 `bow` 가 아닌 까닭: `bow` 는 이미 싸움·감정표현의 기술 이름(FightPoses.move, town_social LOOPS) — 같은 이름에 다른 몸짓을 두지 않는다.
## 시계는 pose_t; meta "flourish_t" 가 있으면 그 값(점검용). done(f) 가 참이면(FLOURISH_T) 팩이 자세를 비운다. stick3d_limber.gd 처럼 주제별 파일

const SET_T := 0.15
const DIP_T := 0.6        # 숙였다 드는 한 박자
const FLOURISH_T := 1.0
const DIP := 0.6          # 상체가 숙는 각(rad)
const SOFT := 0.02        # 숙이며 무릎이 풀려 골반이 내려앉는 높이(m)

## 자세의 시계 — 점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("flourish_t", f.pose_t))

## 절이 끝났나 — 팩이 자세를 비운다
static func done(f: Stick3D) -> bool:
	return at(f) >= FLOURISH_T

## [arm, dip, head] — 팔·발이 자리 잡은 몫 0..1(펴기에 오르고 거두기에 내려온다), 상체의 숙임 0..1(사인 한 박자), 고개의 숙임 0..1(상체보다 한 치 앞선 박자)
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var arm := smoothstep(0.0, SET_T, u) * (1.0 - smoothstep(SET_T + DIP_T, FLOURISH_T, u))
	var dip := sin(clampf((u - SET_T) / DIP_T, 0.0, 1.0) * PI)
	var head := sin(clampf((u - SET_T + 0.08) / DIP_T, 0.0, 1.0) * PI)
	return [arm, dip, head]

## 상체는 숙였다 들리고 골반은 조금 내려앉는다
static func lean(f: Stick3D) -> float:
	var dip := float(phases(f)[1])
	f.pelvis.position.y = StickRig.HIP_Y - SOFT * dip
	return DIP * dip

## 팔다리 — 오른팔: 허리에 접힌다; 왼팔: 옆으로 펴고 숙일수록 위로; 오른발: 뒤로 물러나 무릎이 살짝; 왼발: 곧게. 고개: 상체보다 먼저 내려가 먼저 든다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "flourish": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(f); var arm := float(ph[0]); var dip := float(ph[1]); var head := float(ph[2])
	if s > 0.0:
		hip.rotation.x = 0.3 * arm; knee.rotation.x = 0.25 * arm                                      # 오른발이 뒤로 — 무릎이 살짝
		sh.rotation.x = -(0.7 * arm); sh.rotation.z = s * 0.35 * arm; el.rotation.x = -(0.35 + 1.75 * arm)   # 허리에 접힌 팔
	else:
		hip.rotation.x = 0.0; knee.rotation.x = 0.05 * arm                                           # 곧게 선 다리
		sh.rotation.x = -(0.1 * arm); sh.rotation.z = -s * (0.1 + (1.3 + 0.5 * dip) * arm); el.rotation.x = -(0.35 - 0.2 * arm)   # 펴 든 팔 — 숙일수록 위로
	if s > 0.0: f.neck.rotation.x += 0.4 * head - 0.15 * dip
	return true
