class_name BrushPoses
extends RefCounted
## 풍경 가족 자세(Climb 콘텐츠 팩 chime, run 160 — data/climb/chime.json, scripts/games/climb_chime.gd; 운영자 보드의 '놀람·피하기' 가족 — 얼굴 앞의 것을 팔로 쓸어 내는 공중의 몸): `brush` 통 사이를 지나는 몸 —
## 움찔(0..0.12): 오른팔이 얼굴 앞으로 튀어 오르고(팔꿈치가 깊이 접혀 손이 눈앞에), 왼팔은 가슴을 가리며, 어깨가 움츠러들어 턱이 당겨지고 무릎이 조금 올라온다(예비)
## → 쓸기(0.12..0.5): 오른팔이 펴지며 옆으로 통을 쓸어 내고(어깨가 바깥으로 0.75 까지, 팔꿈치가 펴진다 — 공중에 머무는 동안 제 박자로 조금씩 더 민다), 고개는 반대쪽으로 돌아가고, 무릎의 올림은 반쯤 풀린다(유지 — 정지화가 아니다)
## → 착지(f.airborne 이 false 가 된 순간)부터 0.3: 무릎이 받쳤다 서고 팔이 내려오며 고개를 한 번 턴다 — 귀에 남은 소리를 털듯이(회수). lurch(발밑이 사라진 몸)·duck(머리를 감싼 선 몸)과 다르다: 이건 뜀의 길을 그대로 가며 눈앞의 것만 치우는 몸.
## 착지 시각은 자세가 바뀌지 않아 시계가 이어지므로 meta "brush_land" 에 적는다(공중을 한 번은 본 뒤에만 — lurch 와 같은 이유); 로더는 done(f) 가 true 가 되면 pose_request 를 비운다.
## 시계는 pose_t; meta "brush_t" 가 있으면 그 값(점검용 — 한 순간에 멈춰 세운다). stick3d_lurch.gd 처럼 주제별 파일

const FLINCH_T := 0.12
const SWEEP_T := 0.38     # 움찔 뒤 쓸기가 다 펴지기까지
const LAND_T := 0.3

## 자세의 시계 — 점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("brush_t", f.pose_t))

## 착지 시각(자세의 시계 기준) — 아직 공중이면 -1. 자세의 첫 프레임엔 지운다; 공중을 본 적이 있어야 착지로 센다
static func _land(f: Stick3D) -> float:
	if f.pose_t == 0.0 and not f.has_meta("brush_t"): f.set_meta("brush_land", -1.0); f.set_meta("brush_air", false)
	var land := float(f.get_meta("brush_land", -1.0)); var air := bool(f.get_meta("brush_air", false))
	if f.airborne and not air: air = true; f.set_meta("brush_air", true)
	if land < 0.0 and air and not f.airborne: land = at(f); f.set_meta("brush_land", land)
	return land

## [flinch, sweep, brace, air] 0..1 — 움찔은 FLINCH_T 에 다 서고 SWEEP_T 에 걸쳐 쓸기가 그 위에 얹힌다; 착지 뒤 0.1 에 공중 몫이 꺼지고 LAND_T 동안 무릎이 한 번 받쳤다 편다
static func phases(f: Stick3D) -> Array:
	var u := at(f); var land := _land(f)
	var fl := smoothstep(0.0, FLINCH_T, u)
	var sw := smoothstep(FLINCH_T, FLINCH_T + SWEEP_T, u)
	var g := 0.0 if land < 0.0 else smoothstep(0.0, 0.1, u - land)
	var b := 0.0 if land < 0.0 else sin(clampf((u - land) / LAND_T, 0.0, 1.0) * PI)
	return [fl, sw, b, 1.0 - g]

## 회수가 끝났나 — 로더가 pose_request 를 비울 때
static func done(f: Stick3D) -> bool:
	var land := float(f.get_meta("brush_land", -1.0))
	return land >= 0.0 and at(f) - land >= LAND_T

## 골반은 착지에 조금 내려앉는다; 몸통은 움찔에 살짝 숙이고 쓸기에 조금 젖혀지며 착지에 숙인다
static func lean(f: Stick3D) -> float:
	var p := phases(f); var fl := float(p[0]); var sw := float(p[1]); var b := float(p[2]); var air := float(p[3])
	f.pelvis.position.y = StickRig.HIP_Y - 0.08 * b
	return (0.1 * fl * (1.0 - sw) - 0.04 * sw) * air + 0.18 * b

## 팔다리 — 오른팔: 얼굴 앞으로 튀어 올랐다가 옆으로 쓸어 낸다(공중에선 제 박자로 조금씩 더 민다), 착지에 내려온다; 왼팔: 가슴을 가린다; 다리: 무릎이 올라왔다 반쯤 풀리고 착지에 받친다; 고개: 턱을 당겼다 반대쪽으로 돌리고 착지에 한 번 턴다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "brush": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var p := phases(f); var fl := float(p[0]); var sw := float(p[1]); var b := float(p[2]); var air := float(p[3])
	var u := at(f)
	hip.rotation.x = -(0.45 * fl * (1.0 - 0.4 * sw)) * air - 0.5 * b
	knee.rotation.x = (0.7 * fl * (1.0 - 0.4 * sw)) * air + 1.0 * b
	if s > 0.0:
		sh.rotation.x = -(2.4 * fl - 0.9 * sw + 0.15 * sin(u * 7.0) * sw) * air - 0.6 * b    # 얼굴 앞으로 → 펴지며 옆으로(쓸기의 박자)
		sh.rotation.z = -s * (0.15 * fl + 0.75 * sw) * air - s * 0.1 * b                    # 바깥으로 — 통을 밀어 낸다
		el.rotation.x = -(1.7 * fl - 1.2 * sw + 0.2 * sin(u * 7.0 + 1.0) * sw) * air - 0.4 * b
		f.chest.rotation.x += 0.12 * fl * air                                                # 움츠러든 어깨
		f.neck.rotation.x += (0.3 * fl * (1.0 - sw) - 0.1 * sw) * air + 0.15 * b             # 턱을 당겼다 든다, 착지에 숙인다
		var land := float(f.get_meta("brush_land", -1.0))
		var shake := 0.0 if land < 0.0 else sin(clampf((u - land) / LAND_T, 0.0, 1.0) * TAU)
		f.neck.rotation.y += 0.6 * sw * air + 0.3 * shake * b                               # 반대쪽으로 돌린 고개 — 착지에 한 번 턴다
	else:
		sh.rotation.x = -(1.1 * fl) * air - 0.5 * b                                          # 가슴을 가리는 손
		sh.rotation.z = s * 0.15 * fl * air
		el.rotation.x = -(1.9 * fl) * air - 0.3 * b
	return true
