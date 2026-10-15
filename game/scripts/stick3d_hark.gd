class_name HarkPoses
extends RefCounted
## 귀 기울이기 자세(Climb 팩 chime 의 주민 반쪽 — 풍경 점퍼, run 161; 운영자 보드의 '전화·손을 귀에' 가족의 첫 자세): `hark` 통 사이로 뛰어내려 선 몸이 잦아드는 화음을 듣는다 —
## 들기(0..0.25): 오른손이 귀로 올라가고(어깨가 옆으로 벌어지며 팔꿈치가 깊이 접힌다) 왼손은 허리에, 무게가 오른다리로 옮겨 오른 무릎이 조금 굽고 골반이 살짝 내려앉는다, 고개는 손 쪽으로 기울며 앞(화면)으로 돈다(look_yaw — 귀를 소리 쪽으로)
## → 듣기(0.25..1.2): 손이 0.3 s 박자로 귀를 감쌌다 풀고(팔꿈치가 한 치 더 접혔다 펴진다) 고개가 0.6 Hz 로 느리게 갸웃거린다 — 정지화가 아니다. 화음(ring_s 1.2)이 잦아드는 길이만큼
## → 내리기(1.2..1.5): 손이 내려오고 고개가 돌아오며 무게가 고르게 선다(회수). peer(망원경에 숙인 몸)·squint(돌판을 읽는 몸)와 다르다: 이건 눈이 아니라 귀로 보는 몸.
## 고개의 방향은 meta "hark_side"(몸이 보는 쪽 부호 — +1 이면 +x; 없으면 +1): 고개는 늘 화면 쪽으로 돈다. 시계는 pose_t; meta "hark_t" 가 있으면 그 값(점검용). done(f) 가 참이면(1.5초) 팩이 자세를 비운다. stick3d_wipe.gd 처럼 주제별 파일

const RISE_T := 0.25
const HOLD_T := 0.95      # 듣는 길이 — 1.5 = 들기 + 듣기 + 내리기
const HARK_T := 1.5
const BEAT_HZ := 3.3      # 손이 귀를 감쌌다 푸는 박자(0.3 s)
const TILT_HZ := 0.6      # 고개의 갸웃
const DIP := 0.02         # 무게를 옮기며 골반이 내려앉는 높이(m)

## 자세의 시계 — 점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("hark_t", f.pose_t))

## 듣기가 끝났나 — 팩이 자세를 비운다
static func done(f: Stick3D) -> bool:
	return at(f) >= HARK_T

## [up, cup, tilt] — 손이 귀에 든 몫 0..1(들기에 오르고 내리기에 내려온다), 감쌈 0..1(듣는 동안 박자로), 갸웃 −1..1(듣는 동안 느리게)
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var up := smoothstep(0.0, RISE_T, u) * (1.0 - smoothstep(RISE_T + HOLD_T, HARK_T, u))
	var hold := smoothstep(RISE_T, RISE_T + 0.1, u) * (1.0 - smoothstep(RISE_T + HOLD_T - 0.1, RISE_T + HOLD_T, u))
	var cup := (0.5 - 0.5 * cos((u - RISE_T) * TAU * BEAT_HZ)) * hold
	var tilt := sin((u - RISE_T) * TAU * TILT_HZ) * hold
	return [up, cup, tilt]

## 골반은 무게를 옮기며 조금 내려앉는다; 고개는 화면 쪽으로 돈다(look_yaw); 몸통은 살짝 앞으로
static func lean(f: Stick3D) -> float:
	var ph := phases(f); var up := float(ph[0])
	var side := float(f.get_meta("hark_side", 1.0))
	f.pelvis.position.y = StickRig.HIP_Y - DIP * up
	f.look_yaw = -0.7 * side * up   # +x 를 보는 몸은 음의 yaw 가 화면 쪽(stick3d 의 앞은 몸의 +z)
	return 0.05 * up

## 팔다리 — 오른팔: 옆으로 벌려 올리며 팔꿈치를 깊이 접어 손을 귀에, 박자로 한 치 더 감싼다; 왼팔: 허리에; 다리: 오른 무릎이 조금 굽어 무게를 받는다; 고개: 손 쪽으로 기울고 갸웃거린다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "hark": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(f); var up := float(ph[0]); var cup := float(ph[1]); var tilt := float(ph[2])
	if s > 0.0:
		hip.rotation.x = -0.05 * up; knee.rotation.x = 0.12 * up                 # 무게를 받는 다리
		sh.rotation.x = -(1.1 * up); sh.rotation.z = -s * (1.0 * up)             # 옆으로 벌려 올린 팔
		el.rotation.x = -(2.5 * up + 0.12 * cup)                                 # 깊이 접힌 팔꿈치 — 손이 귀에, 박자로 감싼다
		f.neck.rotation.z = (0.22 + 0.08 * tilt) * up                            # 손 쪽으로 기운 고개 — 갸웃
		f.neck.rotation.x += 0.08 * up
	else:
		hip.rotation.x = 0.03 * up; knee.rotation.x = 0.05 * up
		sh.rotation.x = -(0.35 * up); sh.rotation.z = -s * (0.3 * up); el.rotation.x = -(1.5 * up)   # 허리에 얹은 손
	return true
