class_name KitePoses
extends RefCounted
## 연줄 가족 자세(Climb 콘텐츠 팩 kite, run 131 — data/climb/kite.json, scripts/games/climb_kite.gd; 운영자 보드의 '매달리기·바람' 가족 — 줄 하나에 매달려 바람에 끌려가는 몸): `kite` 연의 토글에 매달린 몸 —
## 0.2 두 팔이 머리 위로 뻗어 한 줄의 토글을 모아 쥐고(두 손이 가운데로 — 가로대를 벌려 잡는 dangle 과 다르다) 다리가 늘어지며 골반이 조금 오른다(예비) → 유지: 끌려가는 속도(meta "kite_v" −1..1, +면 +x 로 간다; 팩의 hang_on 이 적는다, 없으면 1)를 보는 쪽으로 뒤집어
## 몸통이 가는 쪽으로 기울고 다리는 뒤로 흘러 깃발처럼 5Hz 로 펄럭인다(무릎이 접힌 채), 고개는 연을 올려본다;
## 내려놓기(meta "kite_set" 0 → 1, 팩의 land_s 에 걸쳐): 다리가 앞으로 내려와 발판을 디디려 하고 몸통이 서고 고개가 발판으로 내려온다 — 팔은 아직 줄에
## → 발판에 서서 로더가 자세를 비우면 stick3d 의 블렌딩이 팔을 내리고 무릎을 편다(회수). 몸이 보는 쪽(f._yaw)으로 '앞'을 읽는다.
## glide(바람에 뜬 몸, 팔을 벌린다)·dangle(가로대에 두 손을 벌려, 다리를 펌프질)·haul(종 줄을 위아래로 쥐고 당긴다)과 다르다: 이건 한 줄을 모아 쥐고 끌려가며 다리가 펄럭이는 몸. stick3d_dangle.gd 처럼 주제별 파일

const GRAB_T := 0.2

## 잡은 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, GRAB_T, f.pose_t)

## 몸 앞쪽으로 끌려가는 정도 −1..1 — 세상 x 의 속도(meta)를 보는 방향(yaw, +x 를 보면 sin 이 +)으로 뒤집는다
static func fwd(f: Stick3D) -> float:
	var raw := clampf(float(f.get_meta("kite_v", 1.0)), -1.0, 1.0)
	return raw * (1.0 if sin(f._yaw) >= 0.0 else -1.0)

## 내려놓기 0..1 — 팩이 적어 준 값, 없으면 0
static func setk(f: Stick3D) -> float:
	return clampf(float(f.get_meta("kite_set", 0.0)), 0.0, 1.0)

## 골반이 조금 오르고(늘어진 몸), 몸통은 가는 쪽으로 기운다 — 발이 뒤처진다; 내려놓으면 선다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var st := setk(f)
	f.pelvis.position.y = StickRig.HIP_Y + 0.03 * kk * (1.0 - st)
	return (0.4 * fwd(f) * (1.0 - st) + 0.02 * sin(f._t * 1.7)) * kk

## 팔다리 — 두 팔은 머리 위 한 줄로 모여 토글을(팔꿈치는 잡은 뒤 펴진다), 두 다리는 뒤로 흘러 펄럭이고(끌리는 만큼 더 뒤로) 내려놓으면 앞으로 내려온다, 고개는 연을 올려보다 발판으로
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "kite": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var fw := absf(fwd(f)); var st := setk(f)
	var flut := sin(f._t * 31.0 + s * 1.3) * 0.12 + sin(f._t * 19.0) * 0.05   # 31rad/s ≈ 5Hz 펄럭임, 느린 결 하나
	var trail := (-0.35 - 0.25 * fw + flut) * (1.0 - st) + 0.2 * st   # 앞 = 양수: 뒤로 흐르다 내려놓으면 앞으로
	var bend := (0.5 + 0.2 * fw + flut) * (1.0 - st) + 0.25 * st
	hip.rotation.x = -(trail * kk)
	knee.rotation.x = -(-(bend * kk))
	sh.rotation.x = -(0.1 + 2.85 * kk); sh.rotation.z = -s * (0.1 - 0.08 * kk); el.rotation.x = -(0.5 - 0.35 * kk)   # 어깨가 안으로 — 두 손이 한 줄에
	if s > 0.0: f.neck.rotation.x -= 0.45 * (1.0 - st) * kk
	return true
