class_name BouncePoses
extends RefCounted
## 통통 버섯 가족 자세(Climb 콘텐츠 팩 mushroom, run 119 — data/climb/mushroom.json, scripts/games/climb_mushroom.gd): `bounce` 갓에 튕겨 오른 몸 —
## 0.15 무릎을 가슴까지 끌어올리고 두 팔로 정강이를 감싸며 고개를 숙인다(예비·웅크림) → 오르는 동안 웅크린 채 아주 조금 흔들린다(유지)
## → 꼭대기를 지나 떨어지기 시작하면(f.vertical ≤ 0) 0.2 다리를 아래로 펴고 두 팔을 머리 위로 올린다(펼침) → 착지(f.airborne 이 false 가 된 순간)부터 0.3 무릎이 깊이 받쳤다 튀듯 선다(철퍼덕·회수).
## 자세가 바뀌지 않아 pose_t 가 이어지므로 꼭대기·착지 시각은 meta "bounce_fall"/"bounce_land" 에 적고, 다시 튕기면(착지·낙하 뒤 다시 오르면) "bounce_since" 로 처음부터 센다; 로더는 done(f) 가 true 가 되면 pose_request 를 비운다. stick3d_glide.gd 처럼 주제별 파일

const TUCK_T := 0.15
const OPEN_T := 0.2
const LAND_T := 0.3

## [since, fall, land] — 이 튕김의 시작·낙하 시작·착지 시각(pose_t 기준, 아직이면 -1). 자세의 첫 프레임엔 지운다; 착지했거나 떨어지던 몸이 다시 오르면 새 튕김
static func _marks(f: Stick3D) -> Array:
	if f.pose_t == 0.0: f.set_meta("bounce_since", 0.0); f.set_meta("bounce_fall", -1.0); f.set_meta("bounce_land", -1.0)
	var since := float(f.get_meta("bounce_since", 0.0)); var fall := float(f.get_meta("bounce_fall", -1.0)); var land := float(f.get_meta("bounce_land", -1.0))
	if (fall >= 0.0 or land >= 0.0) and f.airborne and f.vertical > 0.5:
		since = f.pose_t; fall = -1.0; land = -1.0
	elif fall < 0.0 and f.airborne and f.vertical <= 0.0 and f.pose_t - since > TUCK_T: fall = f.pose_t
	elif land < 0.0 and not f.airborne and f.pose_t - since > 0.05: land = f.pose_t
	f.set_meta("bounce_since", since); f.set_meta("bounce_fall", fall); f.set_meta("bounce_land", land)
	return [since, fall, land]

## [tuck, open, brace] 0..1 — 웅크림은 TUCK_T 에 다 감기고 펼침이 그만큼 풀며, 착지 뒤 LAND_T 동안 무릎이 한 번 깊이 굽었다 편다
static func phases(f: Stick3D) -> Array:
	var m := _marks(f)
	var tuck := smoothstep(0.0, TUCK_T, f.pose_t - float(m[0]))
	var open := 0.0 if float(m[1]) < 0.0 else smoothstep(0.0, OPEN_T, f.pose_t - float(m[1]))
	var brace := 0.0 if float(m[2]) < 0.0 else sin(clampf((f.pose_t - float(m[2])) / LAND_T, 0.0, 1.0) * PI)
	if float(m[2]) >= 0.0: open = 1.0   # 땅에 닿은 뒤엔 웅크림이 없다 — 받치는 무릎만
	return [tuck * (1.0 - open), open, brace]

## 회수가 끝났나 — 로더가 pose_request 를 비울 때
static func done(f: Stick3D) -> bool:
	var land := float(f.get_meta("bounce_land", -1.0))
	return land >= 0.0 and f.pose_t - land >= LAND_T

static func lean(f: Stick3D) -> float:
	var p := phases(f); var tuck := float(p[0]); var open := float(p[1]); var b := float(p[2])
	f.pelvis.position.y = StickRig.HIP_Y - 0.08 * tuck - 0.3 * b
	return 0.4 * tuck + sin(f._t * 5.0) * 0.03 * tuck - 0.1 * open * (1.0 - b) + 0.3 * b   # 공처럼 말리고, 펼치며 조금 젖혀지고, 착지에 숙인다

## 팔다리 — 웅크림: 허벅지가 가슴으로, 무릎이 접히고, 두 팔이 정강이를 감싼다; 펼침: 다리는 아래로 곧게, 두 팔은 머리 위로; 착지: 무릎이 깊이 받치고 팔이 앞으로 균형을 잡는다. 고개는 웅크릴 때 숙이고 펼칠 때 든다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "bounce": return false
	var hip_n: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var p := phases(f); var tuck := float(p[0]); var open := float(p[1]); var b := float(p[2])
	var wob := sin(f._t * 5.0 + s * 0.4) * 0.04 * tuck   # 말린 몸이 조금 흔들린다
	hip_n.rotation.x = -(2.0 * tuck + wob - 0.05 * open + 0.9 * b)
	knee.rotation.x = -(-2.3 * tuck - 0.1 * open - 1.6 * b)
	sh.rotation.x = -(lerpf(-0.08, 1.35, tuck) + 2.9 * open * (1.0 - b) + 1.0 * b)
	sh.rotation.z = -s * (0.08 + 0.2 * open * (1.0 - b) + 0.25 * b)
	el.rotation.x = -(1.3 * tuck + 0.2 * open + 0.5 * b + wob * 2.0)
	if s > 0.0: f.neck.rotation.x += 0.5 * tuck - 0.25 * open * (1.0 - b) + 0.2 * b
	return true
