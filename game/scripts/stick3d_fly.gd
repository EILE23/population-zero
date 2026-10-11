class_name FlyPoses
extends RefCounted
## 공중그네 가족 자세(Climb 콘텐츠 팩 trapeze, run 141 — data/climb/trapeze.json, scripts/games/climb_trapeze.gd; 운영자 보드의 '매달리기·철봉' 가족 — 두 손으로 가로대를 쥐고 제 박자로 흔드는 몸): `fly` 공중그네 가로대에 매달린 몸 —
## 0.2 두 팔이 머리 위로 뻗어 어깨 폭으로 가로대를 쥐고 다리가 곧게 늘어지며 골반이 조금 오른다(예비) → 유지, 팩이 적는 메타로:
## 속도("fly_v" −1..1, +면 +x 로 간다; 없으면 3초 주기의 제 박자): 다리가 가는 쪽으로 모여 따라가고(두 다리 같이, 한 짝이 아주 조금 앞) 몸통은 밧줄을 따라 기운다 — 각("fly_a" rad, +면 +x 로 기울었다)만큼 발이 손보다 바깥으로;
## 펌프질("fly_pump" 0..1): 앞으로 갈 땐 두 다리를 모아 높이 차고 돌아올 땐 무릎을 접는다 — 그네의 펌프질, 다리가 함께 뛴다;
## 끝("fly_e" 0..1, 진폭의 끝에 가까운 정도): 등이 휘고(가슴이 젖혀진다) 고개가 든다 — 멈춘 한순간;
## 접기(FlyPoses.release 가 적는 "fly_rel", 놓은 뒤 0.15 에 걸쳐): 무릎이 가슴으로, 팔이 가로대에서 내려와 정강이를 안고, 고개가 숙는다 — 0.45 가 지나면 done, 로더가 자세를 비우면 stick3d 의 블렌딩이 몸을 편다(회수).
## 몸이 보는 쪽(f._yaw)으로 '앞'을 읽는다. 메타가 없으면 3초 한 바퀴의 제 박자(주민·시연용).
## dangle(시계추에 실려 가는 몸 — 몸통이 가는 쪽으로 기운다)·zip(두 손을 벌려 쥐고 다리를 접은 채 처진다)·kite(한 줄을 모아 쥔다)와 다르다: 이건 밧줄을 따라 곧게 늘어진 몸이 다리를 모아 저어 제 진폭을 만들고 끝에서 등을 휘는 것. stick3d_dangle.gd 처럼 주제별 파일

const GRAB_T := 0.2
const PERIOD := 3.0
const TUCK_IN := 0.15     # 놓은 뒤 몸을 접는 데 걸리는 시간
const TUCK_T := 0.45      # 접은 채 머무는 시간 — 그 뒤 done
const TUCK_HIP := 1.35    # 엉덩이: 가슴으로 올린 무릎
const TUCK_KNEE := 1.7    # 무릎: 접힌 다리

## 잡은 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, GRAB_T, f.pose_t)

## 보는 방향 ±1 — +x 를 보면 sin 이 +
static func facing(f: Stick3D) -> float:
	return 1.0 if sin(f._yaw) >= 0.0 else -1.0

## 몸 앞쪽으로 가는 정도 −1..1 — 세상 x 의 속도(meta)를 보는 방향으로 뒤집는다
static func fwd(f: Stick3D) -> float:
	var raw := clampf(float(f.get_meta("fly_v", cos(f._t * TAU / PERIOD))), -1.0, 1.0)
	return raw * facing(f)

## 앞쪽으로 기운 각(rad) — 세상의 각(meta)을 보는 방향으로 뒤집는다
static func tilt(f: Stick3D) -> float:
	var raw := clampf(float(f.get_meta("fly_a", 0.35 * sin(f._t * TAU / PERIOD))), -1.2, 1.2)
	return raw * facing(f)

## 끝에 가까운 정도 0..1
static func endk(f: Stick3D) -> float:
	if f.has_meta("fly_e"): return clampf(float(f.get_meta("fly_e")), 0.0, 1.0)
	return absf(sin(f._t * TAU / PERIOD))

## 펌프질 0..1
static func pumpk(f: Stick3D) -> float:
	return clampf(float(f.get_meta("fly_pump", 0.0)), 0.0, 1.0)

## 놓은 순간을 적는다 — 그때부터 몸을 접는다(팩의 let_go 가 부른다)
static func release(f: Stick3D) -> void:
	f.set_meta("fly_rel", f.pose_t)
	for m in ["fly_v", "fly_a", "fly_e", "fly_pump"]:
		if f.has_meta(String(m)): f.remove_meta(String(m))

## 접은 정도 0..1 — 놓기 전엔 0. 자세가 새로 시작되면(pose_t 0) 지난 놓기를 잊는다
static func tuck(f: Stick3D) -> float:
	if f.pose_t == 0.0 and f.has_meta("fly_rel"): f.remove_meta("fly_rel")
	var rel := float(f.get_meta("fly_rel", -1.0))
	if rel < 0.0: return 0.0
	return smoothstep(0.0, TUCK_IN, f.pose_t - rel)

## 접기가 끝났나 — 놓은 뒤 TUCK_T 가 지나면
static func done(f: Stick3D) -> bool:
	var rel := float(f.get_meta("fly_rel", -1.0))
	return rel >= 0.0 and f.pose_t - rel >= TUCK_T

## 골반이 조금 오르고(늘어진 몸), 몸통은 밧줄을 따라 기운다 — 발이 손보다 바깥으로(각의 반대쪽으로 젖혀진 몸통); 접으면 앞으로 말린다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var tk := tuck(f)
	f.pelvis.position.y = StickRig.HIP_Y + 0.03 * kk * (1.0 - tk) - 0.05 * tk
	return (-0.8 * tilt(f) + 0.03 * sin(f._t * 2.0)) * kk * (1.0 - tk) + 0.5 * tk

## 팔다리 — 두 팔은 머리 위로 어깨 폭으로 가로대를(팔꿈치는 잡은 뒤 펴진다), 두 다리는 모여 가는 쪽으로 따라가고 펌프질이면 앞으로 높이 차다 돌아올 땐 접는다, 끝에선 가슴이 젖혀지고 고개가 든다; 접으면 무릎이 가슴으로 오고 팔이 정강이를 안는다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "fly": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var fw := fwd(f); var pk := pumpk(f); var e := endk(f); var tk := tuck(f)
	var hip_h := (0.1 + 0.3 * fw + 0.5 * fw * pk + 0.03 * s) * kk   # 매달린 다리 — 가는 쪽으로, 펌프질이면 더
	var knee_h := maxf(0.0, 0.25 - 0.2 * fw + 0.3 * pk * maxf(0.0, -fw)) * kk   # 돌아올 땐 접힌다
	hip.rotation.x = -lerpf(hip_h, TUCK_HIP, tk)
	knee.rotation.x = lerpf(knee_h, TUCK_KNEE, tk)
	sh.rotation.x = -lerpf(0.1 + 2.7 * kk, 0.9, tk); sh.rotation.z = -s * (0.1 + 0.15 * kk); el.rotation.x = -lerpf(0.5 - 0.4 * kk, 1.9, tk)   # 팔이 가로대에서 정강이로
	if s > 0.0:
		f.chest.rotation.x -= 0.3 * e * kk * (1.0 - tk)   # 끝에서 등이 휜다
		f.neck.rotation.x -= (0.2 + 0.2 * e) * kk * (1.0 - tk) - 0.5 * tk
	return true
