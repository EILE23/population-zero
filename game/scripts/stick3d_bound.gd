class_name BoundPoses
extends RefCounted
## 다이빙 판 가족 자세(Climb 콘텐츠 팩 plank, run 137 — data/climb/plank.json, scripts/games/climb_plank.gd; 운영자 보드의 '다이빙·높이뛰기' 가족 — 널 끝에서 튀어 오르는 몸): `bound` 널 끝에 선 몸이 던져져 날아 내린다 —
## 준비(널 끝 tip_zone 에 선 동안, 0.2 로 잡힌다): 두 팔을 앞으로 어깨 높이로, 무릎을 풀고, 널의 출렁임(meta "bound_dip" −1..1, 위가 +; 팩의 stand 가 적는다)에 맞춰 눌릴 땐 무릎이 더 접히고 팔이 아래로 쓸리며 튀어 오를 땐 팔이 머리 쪽으로 — 다이버의 팔 젓기, 쌓인 탭(meta "bound_k" 0..1)만큼 더 깊고 더 크게; 고개는 건너편을
## → 뻗기(f.airborne 이 된 뒤 0.15): 두 팔이 머리 위로 곧게, 다리를 모아 곧게, 등이 살짝 젖혀진다(높이뛰기의 몸) → 접기(꼭대기를 지나 f.vertical ≤ 0, 0.2): 허리가 깊이 접히고 팔이 정강이 쪽으로 내려오며 고개가 무릎을 본다(다이빙의 파이크)
## → 착지(f.airborne 이 거짓이 된 순간)부터 0.3 접힌 몸이 풀리며 무릎이 깊이 받쳤다 선다(회수); 로더는 done(f) 가 true 가 되면 pose_request 를 비운다.
## 자세가 바뀌지 않아 pose_t 가 이어지므로 날기·낙하·착지 시각은 meta "bound_fly"/"bound_fall"/"bound_land" 에 적는다(첫 프레임에 지운다).
## bounce(버섯 — 공처럼 말렸다 펼친다)·glide(통풍구 — 팔을 벌려 뜬다)와 다르다: 이건 제 발로 널을 구르고 곧게 뻗었다 접는 몸. stick3d_bounce.gd 처럼 주제별 파일

const POISE_T := 0.2
const STRETCH_T := 0.15
const PIKE_T := 0.2
const LAND_T := 0.3

## [fly, fall, land] — 날기 시작·낙하 시작·착지 시각(pose_t 기준, 아직이면 -1). 자세의 첫 프레임엔 지운다
static func _marks(f: Stick3D) -> Array:
	if f.pose_t == 0.0: f.set_meta("bound_fly", -1.0); f.set_meta("bound_fall", -1.0); f.set_meta("bound_land", -1.0)
	var fly := float(f.get_meta("bound_fly", -1.0)); var fall := float(f.get_meta("bound_fall", -1.0)); var land := float(f.get_meta("bound_land", -1.0))
	if fly < 0.0 and f.airborne: fly = f.pose_t
	elif fly >= 0.0 and fall < 0.0 and f.airborne and f.vertical <= 0.0 and f.pose_t - fly > 0.05: fall = f.pose_t
	elif fly >= 0.0 and land < 0.0 and not f.airborne and f.pose_t - fly > 0.05: land = f.pose_t
	f.set_meta("bound_fly", fly); f.set_meta("bound_fall", fall); f.set_meta("bound_land", land)
	return [fly, fall, land]

## [ground, up, pk, brace] 0..1 — 널 위의 준비, 뻗기, 접기(착지 뒤 LAND_T 의 반에 풀린다), 착지의 무릎 받침(한 번 깊이 굽었다 편다)
static func phases(f: Stick3D) -> Array:
	var m := _marks(f)
	var fly := float(m[0]); var fall := float(m[1]); var land := float(m[2])
	var poise := smoothstep(0.0, POISE_T, f.pose_t)
	var stretch := 0.0 if fly < 0.0 else smoothstep(0.0, STRETCH_T, f.pose_t - fly)
	var pike := 0.0 if fall < 0.0 else smoothstep(0.0, PIKE_T, f.pose_t - fall)
	var lk := 0.0 if land < 0.0 else smoothstep(0.0, LAND_T * 0.5, f.pose_t - land)
	var brace := 0.0 if land < 0.0 else sin(clampf((f.pose_t - land) / LAND_T, 0.0, 1.0) * PI)
	if land >= 0.0: stretch = 1.0; pike = 1.0   # 땅에 닿은 뒤엔 준비도 뻗기도 없다 — 풀리는 접기와 받치는 무릎만
	return [poise * (1.0 - stretch), stretch * (1.0 - pike), pike * (1.0 - lk), brace]

## 회수가 끝났나 — 로더가 pose_request 를 비울 때
static func done(f: Stick3D) -> bool:
	var land := float(f.get_meta("bound_land", -1.0))
	return land >= 0.0 and f.pose_t - land >= LAND_T

## 널 끝의 처짐 −1..1(위가 +) — 팩이 적어 준 값, 없으면 0
static func dip(f: Stick3D) -> float:
	return clampf(float(f.get_meta("bound_dip", 0.0)), -1.0, 1.0)

## 쌓인 탭 0..1 — 팩이 적어 준 값, 없으면 0
static func loadk(f: Stick3D) -> float:
	return clampf(float(f.get_meta("bound_k", 0.0)), 0.0, 1.0)

## 널 위에선 조금 앞으로 숙인 채 눌릴 때 더 숙이고 골반이 내려앉는다(쌓일수록 깊이), 뻗기엔 살짝 젖혀지고, 접기엔 깊이 앞으로, 착지엔 받치며 숙인다
static func lean(f: Stick3D) -> float:
	var p := phases(f); var g := float(p[0]); var up := float(p[1]); var pk := float(p[2]); var b := float(p[3])
	var dp := dip(f); var kk := loadk(f); var dn := maxf(0.0, -dp)
	f.pelvis.position.y = StickRig.HIP_Y - (0.06 + 0.08 * kk + 0.06 * dn) * g - 0.3 * b
	return (0.12 + 0.08 * kk + 0.1 * dn) * g - 0.15 * up + 0.9 * pk + 0.3 * b

## 팔다리 — 준비: 팔은 앞으로 어깨 높이에서 출렁임에 젓고(눌리면 아래로, 튀면 위로) 무릎은 풀린 채 눌리면 더 접힌다; 뻗기: 팔은 머리 위로 곧게, 다리는 곧게; 접기: 허리가 접히고 팔이 정강이로; 착지: 무릎이 깊이 받치고 팔이 앞으로 균형을 잡는다. 고개는 건너편 → 위 → 무릎 → 앞
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "bound": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var p := phases(f); var g := float(p[0]); var up := float(p[1]); var pk := float(p[2]); var b := float(p[3])
	var dp := dip(f); var kk := loadk(f); var dn := maxf(0.0, -dp)
	hip.rotation.x = -((0.25 + 0.15 * kk + 0.3 * dn) * g - 0.1 * up + 1.3 * pk + 0.9 * b)
	knee.rotation.x = (0.4 + 0.25 * kk + 0.5 * dn) * g + 0.05 * up + 0.15 * pk + 1.6 * b
	sh.rotation.x = -((1.2 + (1.0 + 0.6 * kk) * dp) * g + 2.95 * up + 1.4 * pk + 1.0 * b)
	sh.rotation.z = -s * (0.15 * g + 0.1 * up + 0.05 * pk + 0.25 * b)
	el.rotation.x = -(0.3 * g + 0.2 * pk + 0.5 * b)
	if s > 0.0: f.neck.rotation.x += -0.15 * g - 0.3 * up + 0.45 * pk + 0.2 * b
	return true
