class_name TrailPoses
extends RefCounted
## 풍향계 가족 자세(Climb 콘텐츠 팩 vane, run 136 — data/climb/vane.json, scripts/games/climb_vane.gd; 운영자 보드의 '매달리기' 가족 — 한 손으로 매달려 끌려 도는 몸): `trail` 풍향계 꼬리의 리본에 매달린 몸 —
## 0.2 오른팔이 머리 위로 뻗어 리본을 쥐고(한 손 — 두 손을 모아 쥐는 kite, 가로대를 벌려 잡는 dangle 과 다르다) 왼팔은 균형 잡느라 옆으로 활짝, 다리가 늘어지며 골반이 조금 오른다(예비)
## → 유지: 끌려 도는 속도(meta "trail_v" −1..1, +면 +x 로 간다; 팩의 hang_on 이 적는다, 없으면 1)를 보는 쪽으로 뒤집어 몸통이 가는 쪽으로 기울고, 두 다리는 허공을 페달 밟듯 번갈아 젓는다(빠를수록 빨리, 뒤로 가는 다리가 접힌다 — 끌려가는 몸이 허공을 딛으려는 것), 왼팔이 그 박자에 흔들리고 고개는 풍향계를 올려본다;
## 내려놓기(meta "trail_set" 0 → 1, 팩의 land_s 에 걸쳐): 페달이 멎고 다리가 앞으로 내려와 발판을 디디려 하고 몸통이 서고 고개가 발판으로 내려온다 — 오른팔은 아직 리본에
## → 발판에 서서 로더가 자세를 비우면 stick3d 의 블렌딩이 팔을 내리고 무릎을 편다(회수). 몸이 보는 쪽(f._yaw)으로 '앞'을 읽는다.
## kite(두 손 한 줄, 다리가 뒤로 펄럭)·dangle(두 손 가로대, 펌프질)·cling(장대를 안는다)과 다르다: 이건 한 손에 매달려 허공을 젓는 몸. stick3d_kite.gd 처럼 주제별 파일

const GRAB_T := 0.2

## 잡은 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, GRAB_T, f.pose_t)

## 몸 앞쪽으로 끌려가는 정도 −1..1 — 세상 x 의 속도(meta)를 보는 방향(yaw, +x 를 보면 sin 이 +)으로 뒤집는다
static func fwd(f: Stick3D) -> float:
	var raw := clampf(float(f.get_meta("trail_v", 1.0)), -1.0, 1.0)
	return raw * (1.0 if sin(f._yaw) >= 0.0 else -1.0)

## 내려놓기 0..1 — 팩이 적어 준 값, 없으면 0
static func setk(f: Stick3D) -> float:
	return clampf(float(f.get_meta("trail_set", 0.0)), 0.0, 1.0)

## 페달의 위상 — 빠를수록 빨리 젓는다(0.8..1.8Hz)
static func pedal(f: Stick3D) -> float:
	return f._t * TAU * (0.8 + 1.0 * absf(fwd(f)))

## 골반이 조금 오르고(늘어진 몸), 몸통은 가는 쪽으로 기운다 — 발이 뒤처진다; 내려놓으면 선다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var st := setk(f)
	f.pelvis.position.y = StickRig.HIP_Y + 0.03 * kk * (1.0 - st)
	return (0.3 * fwd(f) * (1.0 - st) + 0.03 * sin(f._t * 1.9)) * kk

## 팔다리 — 오른팔은 머리 위 리본을(팔꿈치는 잡은 뒤 펴진다), 왼팔은 옆으로 활짝 벌려 페달 박자에 흔들리고, 두 다리는 번갈아 허공을 젓다 내려놓으면 앞으로 내려온다, 고개는 풍향계를 올려보다 발판으로
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "trail": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var sp := absf(fwd(f)); var st := setk(f)
	var ped := pedal(f); var ph := ped + (PI if s > 0.0 else 0.0)   # 두 다리가 반 박자 어긋난다
	var swing := (-0.15 - 0.2 * sp + 0.35 * sin(ph)) * (1.0 - st) + 0.15 * st   # 앞 = 양수: 끌리는 만큼 뒤로 흐르며 젓다 내려놓으면 앞으로
	var bend := (0.3 + 0.45 * (0.5 - 0.5 * sin(ph))) * (1.0 - st) + 0.25 * st   # 뒤로 가는 다리가 접힌다
	hip.rotation.x = -(swing * kk)
	knee.rotation.x = bend * kk
	if s > 0.0:   # 오른팔 — 머리 위 리본에
		sh.rotation.x = -(0.1 + 2.9 * kk); sh.rotation.z = -s * (0.1 - 0.05 * kk); el.rotation.x = -(0.5 - 0.4 * kk)
		f.neck.rotation.x -= (0.3 * (1.0 - st) - 0.25 * st) * kk   # 풍향계를 올려보다 발판으로
	else:   # 왼팔 — 옆으로 활짝, 페달 박자에 흔들린다
		sh.rotation.x = -(0.1 + 0.3 * kk + 0.15 * sin(ped) * kk * (1.0 - st)); sh.rotation.z = -s * (0.1 + 1.2 * kk); el.rotation.x = -(0.5 - 0.2 * kk)
	return true
