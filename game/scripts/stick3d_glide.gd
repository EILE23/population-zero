class_name GlidePoses
extends RefCounted
## 상승기류 가족 자세(Climb 콘텐츠 팩 updraft, run 118 — data/climb/updraft.json, scripts/games/climb_updraft.gd): `glide` 바람 기둥에 뜬 몸 —
## 0.2 두 팔이 옆으로 올라 수평보다 조금 위까지(예비) → 유지: 손목이 외투 자락처럼 7Hz 로 펄럭이고 어깨가 숨 쉬듯 오르내리며 다리는 뒤로 흘러 무릎이 살짝 접힌다, 고개는 위
## → 착지(f.airborne 이 false 가 된 순간)부터 0.3 팔이 내려오며 무릎이 한 번 받쳤다 선다(회수). 공중 기본 자세(stick3d 의 오름·꼭대기·내림)와 다르다: 그건 뛴 몸, 이건 바람이 드는 몸.
## 착지 시각은 자세가 바뀌지 않아 pose_t 가 이어지므로 meta "glide_land" 에 적는다; 로더는 done(f) 가 true 가 되면 pose_request 를 비운다. stick3d_furnish.gd 처럼 주제별 파일

const RISE_T := 0.2
const DROP_T := 0.3

## 착지 시각(pose_t 기준) — 아직 공중이면 -1. 자세의 첫 프레임엔 지운다(새 상승마다 처음부터); 다시 떠오르면 다시 -1
static func _land(f: Stick3D) -> float:
	if f.pose_t == 0.0: f.set_meta("glide_land", -1.0)
	var land := float(f.get_meta("glide_land", -1.0))
	if f.airborne and land >= 0.0: land = -1.0; f.set_meta("glide_land", land)
	elif not f.airborne and land < 0.0: land = f.pose_t; f.set_meta("glide_land", land)
	return land

## 팔이 벌어진 정도 0..1 — RISE_T 에 다 벌어지고, 착지 뒤 DROP_T 에 걸쳐 내려온다
static func spread(f: Stick3D) -> float:
	var land := _land(f)
	var up := smoothstep(0.0, RISE_T, f.pose_t)
	return up if land < 0.0 else up * (1.0 - smoothstep(0.0, DROP_T, f.pose_t - land))

## 착지 뒤 무릎이 받치는 정도 0..1 — DROP_T 동안 한 번 굽었다 편다
static func brace(f: Stick3D) -> float:
	var land := _land(f)
	return 0.0 if land < 0.0 else sin(clampf((f.pose_t - land) / DROP_T, 0.0, 1.0) * PI)

## 회수가 끝났나 — 로더가 pose_request 를 비울 때
static func done(f: Stick3D) -> bool:
	var land := float(f.get_meta("glide_land", -1.0))
	return land >= 0.0 and f.pose_t - land >= DROP_T

static func lean(f: Stick3D) -> float:
	var k := spread(f); var b := brace(f)
	f.pelvis.position.y = StickRig.HIP_Y - 0.12 * b
	return -0.12 * k + sin(f._t * 1.3) * 0.02 * k + 0.25 * b   # 바람에 젖혀지고, 착지에 숙인다

## 팔다리 — 팔은 늘어뜨린 데서 옆으로 벌어지고(어깨 z) 손목이 펄럭인다(팔꿈치), 다리는 뒤로 흘러 무릎이 접힌 채 조금씩 흔들린다; 착지엔 무릎이 받친다. 고개는 위
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "glide": return false
	var hip_n: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var k := spread(f); var b := brace(f); var t: float = f._t
	var flut := sin(t * 44.0 + s * 1.7) * 0.12 + sin(t * 29.0) * 0.05   # 44rad/s ≈ 7Hz 펄럭임, 느린 결 하나
	var breathe := sin(t * 2.4) * 0.08
	hip_n.rotation.x = -((-0.25 + sin(t * 2.0 + s) * 0.04) * k + 0.6 * b)
	knee.rotation.x = -(-(0.35 + 0.1 * (0.5 + 0.5 * sin(t * 3.1 + s))) * k - 1.0 * b)
	sh.rotation.x = -(lerpf(-0.08, 0.3 + breathe, k)); sh.rotation.z = -s * lerpf(0.04, 1.45 + breathe, k)
	el.rotation.x = -(lerpf(0.35, 0.15, k) + flut * k)
	if s > 0.0: f.neck.rotation.x -= 0.25 * k
	return true
