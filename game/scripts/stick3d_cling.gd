class_name ClingPoses
extends RefCounted
## 장대 타기 가족 자세(Climb 콘텐츠 팩 lantern, run 133 — data/climb/lantern.json, scripts/games/climb_lantern.gd; 운영자 보드의 '장대 오르기' 가족 — 두 팔과 두 무릎으로 장대를 안고 오르는 몸): `cling` 등롱 장대를 안고 오르다 장대째 넘어가는 몸 —
## 0.2 두 팔이 머리 위 앞으로 모여 장대를 쥐고(팔꿈치는 접은 채 — 안는다) 두 무릎이 장대를 죄며 골반이 붙는다(예비) → 유지 1 오르기(meta "cling_v" 1, 팩의 hang_on 이 적는다, 없으면 1): 1.4Hz 의 '당기고 밀기' —
## 무릎을 끌어올려 죄고(엉덩이 1.1·무릎 1.6) 두 손이 반 박자 엇갈려 위로 뻗으며 다리를 펴 몸을 밀어 올린다(엉덩이 0.6·무릎 1.0); 골반이 박자마다 조금 뜨고 몸통이 장대에 붙었다 떨어지며, 고개는 장대 위를 본다
## → 유지 2 넘어가기(cling_v 0, meta "cling_a" 장대의 기울기 rad, +면 +x 로): 손발이 멎고 몸이 장대를 꼭 안은 채 골반째 장대와 같이 기운다(보는 쪽으로 기울면 앞으로 — 로더가 face = dir), 고개는 건너편 발판을, 숨이 1.1Hz 로 몸통에
## → 발판에 내려 로더가 자세를 비우면 stick3d 의 블렌딩이 팔을 내리고 무릎을 편다(회수). 몸이 보는 쪽(f._yaw)으로 '앞'을 읽는다.
## dangle(가로대에 두 손만, 다리는 늘어진다)·haul(줄을 위아래로 쥐고 당긴다)·rail(사다리 가로대를 딛고 오른다)·climb(홀드에 붙은 몸, stick3d.gd 의 move "climb")과 다르다: 이건 장대를 안고 무릎으로 죄어 오르는 몸. stick3d_dangle.gd 처럼 주제별 파일

const GRAB_T := 0.2
const SHIN_HZ := 1.4
const BREATH_HZ := 1.1

## 안은 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, GRAB_T, f.pose_t)

## 오르는 중 0..1 — 팩이 적어 준 값, 없으면 1
static func v(f: Stick3D) -> float:
	return clampf(float(f.get_meta("cling_v", 1.0)), 0.0, 1.0)

## 당기기(1)..밀기(0) 박자 — 모든 관절이 한 박자
static func hitch(f: Stick3D) -> float:
	return 0.5 + 0.5 * sin(f._t * TAU * SHIN_HZ)

## 장대의 기울기를 몸 앞쪽(+)으로 — 세상 x 의 각(meta)을 보는 방향(yaw, +x 를 보면 sin 이 +)으로 뒤집는다
static func tilt(f: Stick3D) -> float:
	var raw := clampf(float(f.get_meta("cling_a", 0.0)), -1.2, 1.2)
	return raw * (1.0 if sin(f._yaw) >= 0.0 else -1.0)

## 골반째 장대와 같이 기울고(앞 = 양수, stick3d 의 쪼그림과 같은 부호), 당길 때 골반이 조금 뜬다; 몸통은 장대를 안아 앞으로, 넘어갈 땐 숨에 흔들린다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var vv := v(f); var h := hitch(f)
	f.pelvis.rotation.x = (0.9 * tilt(f) + 0.04 * h * vv) * kk
	f.pelvis.position.y = StickRig.HIP_Y + 0.03 * h * vv * kk
	return (0.25 + 0.05 * h * vv + 0.02 * sin(f._t * TAU * BREATH_HZ) * (1.0 - vv)) * kk

## 팔다리 — 두 팔은 머리 위 앞에 모여 장대를(팔꿈치 접은 채; 오를 땐 두 손이 반 박자 엇갈려 위로), 두 무릎은 장대를 죄고(당길 때 더 올리고 밀 때 편다; 넘어갈 땐 꼭 안고 멎는다), 고개는 오를 땐 위를·넘어갈 땐 건너편을
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "cling": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var vv := v(f); var h := hitch(f)
	var fwd := 0.6 + 0.5 * h * vv + 0.35 * (1.0 - vv)   # 앞 = 양수: 무릎이 장대를 죈다
	var bend := 1.0 + 0.6 * h * vv + 0.4 * (1.0 - vv)
	hip.rotation.x = -(fwd * kk)
	knee.rotation.x = bend * kk
	var reach := s * sin(f._t * TAU * SHIN_HZ) * 0.3 * vv   # 두 손이 번갈아 위로 — 한 박자 엇갈려
	sh.rotation.x = -(0.1 + (2.45 + reach) * kk); sh.rotation.z = -s * (0.1 - 0.02 * kk); el.rotation.x = -(0.5 + 0.45 * kk)   # 어깨가 안으로, 팔꿈치는 접은 채 — 장대를 안는다
	if s > 0.0: f.neck.rotation.x -= (0.4 * vv - 0.1 * (1.0 - vv)) * kk
	return true
