class_name DuckPoses
extends RefCounted
## 고드름 가족 자세(Climb 콘텐츠 팩 icicle, run 123 — data/climb/icicle.json, scripts/games/climb_icicle.gd; 운영자 보드의 '머리 감싸기·몸 사리기' 가족 — 위에서 뭔가 떨어질 때의 반사): `duck` 떠는 고드름 밑에 선 몸 —
## 0.15 들어감: 고개가 가슴으로 꺾이고 두 팔이 머리 위로 올라가 팔꿈치가 접혀 정수리를 덮고 무릎이 내려앉으며 몸통이 앞으로 숙는다(예비) → 유지: 14Hz 로 어깨가 가늘게 떨고 몸통이 함께 흔들린다 — 한 모양으로 굳어 있지 않다
## → 로더가 done(f) 를 묻기 시작한 때부터 0.3 풀림: 팔이 내려오고 무릎이 펴지며 고개가 한 번 치켜 올라가 위를 살핀다(회수, peek) — 그 끝에 done 이 true 가 되면 로더가 pose_request 를 비운다.
## 풀리는 도중 다시 near 가 오면 로더가 hold(f) 를 불러 풀림을 지우고 다시 감싼다. lurch(발밑이 사라진 몸)·teeter(녹는 판 위의 몸)와 다르다: 이건 위를 보고 몸을 사리는 몸. stick3d_lurch.gd 처럼 주제별 파일

const IN_T := 0.15
const OUT_T := 0.3
const SHIVER_HZ := 14.0

## 풀림 시각(pose_t 기준) — 아직 감싸고 있으면 -1. 자세의 첫 프레임엔 지운다
static func _off(f: Stick3D) -> float:
	if f.pose_t == 0.0: f.set_meta("duck_off", -1.0)
	return float(f.get_meta("duck_off", -1.0))

## 로더가 near 가 참인 틱마다 — 풀리던 몸도 다시 감싼다
static func hold(f: Stick3D) -> void:
	f.set_meta("duck_off", -1.0)

## 로더가 near 가 거짓이고 자세가 duck 인 틱마다 — 첫 물음에 풀림이 시작되고 OUT_T 뒤에 true
static func done(f: Stick3D) -> bool:
	var off := _off(f)
	if off < 0.0:
		f.set_meta("duck_off", f.pose_t)
		return false
	return f.pose_t - off >= OUT_T

## 감싼 정도 0..1 — IN_T 에 다 들어가고, 풀림이 시작되면 OUT_T 에 걸쳐 0 으로
static func k(f: Stick3D) -> float:
	var kin := smoothstep(0.0, IN_T, f.pose_t)
	var off := _off(f)
	if off < 0.0: return kin
	return kin * (1.0 - smoothstep(off, off + OUT_T, f.pose_t))

## 풀리며 위를 살피는 고개 0..1..0
static func peek(f: Stick3D) -> float:
	var off := _off(f)
	if off < 0.0: return 0.0
	return sin(clampf((f.pose_t - off) / OUT_T, 0.0, 1.0) * PI)

## 무릎이 내려앉고 몸통이 앞으로 숙으며 가늘게 떤다
static func lean(f: Stick3D) -> float:
	var kk := k(f)
	f.pelvis.position.y = StickRig.HIP_Y - 0.14 * kk
	return (0.35 + 0.02 * sin(f._t * SHIVER_HZ * TAU)) * kk

## 팔다리 — 허벅지 앞으로·무릎 접힘(내려앉음), 두 팔은 머리 위로 올라 팔꿈치가 접혀 정수리를 덮고 어깨가 14Hz 로 떤다; 고개는 가슴으로, 풀릴 땐 한 번 치켜 위를 살핀다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "duck": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f)
	var shiver := sin(f._t * SHIVER_HZ * TAU + s * 1.3) * 0.03 * kk
	hip.rotation.x = -(0.55 * kk); knee.rotation.x = -(-0.95 * kk)
	sh.rotation.x = -(2.5 * kk + shiver); sh.rotation.z = -s * (0.1 + 0.1 * kk) + shiver
	el.rotation.x = -(0.3 + 1.6 * kk)
	if s > 0.0: f.neck.rotation.x += 0.7 * kk - 0.25 * peek(f)
	return true
