class_name PartPoses
extends RefCounted
## 덩굴 커튼 가족 자세(Climb 콘텐츠 팩 vine, run 129 — data/climb/vine.json, scripts/games/climb_vine.gd; 운영자 보드의 '밀고 헤치기' 가족 — 늘어진 것을 두 손으로 젖히며 지나는 몸과 그것에 안긴 몸): `part` 덩굴 커튼 속의 몸 —
## 0.2 들어감: 두 팔이 가슴 높이로 올라 앞으로 뻗고 고개가 숙는다(예비) → 유지, 팩이 적는 메타로:
## 깊이("part_k" 0..1, 가운데가 1 — 없으면 2초 주기의 제 박자): 깊을수록 팔이 더 높이, 두 손이 0.5초 박자로 번갈아 덩굴을 바깥으로 젖히고(팔꿈치가 펴졌다 접힌다) 몸통이 앞으로 숙고 고개가 가슴으로; 걸으면 무릎 높이 걸음(덩굴을 넘는 다리), 서면 무릎을 조금 굽힌다;
## 안김("part_c" 0..1, 떨어져 받힌 몸): 두 팔이 옆 위로 벌어져 가닥을 쥐고 다리가 늘어져 천천히 흔들리며 몸통이 조금 뒤로, 고개는 발밑 발판을 본다; 미끄러짐("part_v" −1..0): 무릎이 들리고 팔이 위로 펴지며 몸이 늘어난다 — 가닥을 타고 내려오는 몸
## → 커튼을 떠나면 로더가 done(f) 를 묻기 시작한 때부터 0.25 풀림: 팔이 내려오고 고개가 든다(회수) — 그 끝에 done 이 true 가 되면 로더가 pose_request 를 비운다. 풀리는 도중 다시 들어오면 로더가 hold(f) 를 불러 풀림을 지운다.
## wade(발이 잠긴 바닥 — 발을 높이 뺀다)·haul(한 줄을 당겨 오른다)·dangle(가로대에 두 손)과 다르다: 이건 몸 앞의 늘어진 것을 젖히는 손과, 그것에 받혀 멈춘 몸. stick3d_duck.gd 처럼 주제별 파일

const IN_T := 0.2
const OUT_T := 0.25
const SWEEP_T := 0.5     # 한 손이 덩굴을 젖히는 박자(두 손이 반 박자 엇갈린다)
const STEP_T := 0.55     # 덩굴을 넘는 한 걸음
const SWING_T := 2.1     # 안긴 다리가 흔들리는 주기
const PERIOD := 2.0      # 메타가 없을 때 깊이의 제 박자

## 풀림 시각(pose_t 기준) — 아직 안이면 -1. 자세의 첫 프레임엔 지운다
static func _off(f: Stick3D) -> float:
	if f.pose_t == 0.0: f.set_meta("part_off", -1.0)
	return float(f.get_meta("part_off", -1.0))

## 로더가 in 이 참인 틱마다 — 풀리던 몸도 다시 젖힌다
static func hold(f: Stick3D) -> void:
	f.set_meta("part_off", -1.0)

## 로더가 in 이 거짓이고 자세가 part 인 틱마다 — 첫 물음에 풀림이 시작되고 OUT_T 뒤에 true
static func done(f: Stick3D) -> bool:
	var off := _off(f)
	if off < 0.0:
		f.set_meta("part_off", f.pose_t)
		return false
	return f.pose_t - off >= OUT_T

## 들어간 정도 0..1 — IN_T 에 다 들어가고, 풀림이 시작되면 OUT_T 에 걸쳐 0 으로
static func k(f: Stick3D) -> float:
	var kin := smoothstep(0.0, IN_T, f.pose_t)
	var off := _off(f)
	if off < 0.0: return kin
	return kin * (1.0 - smoothstep(off, off + OUT_T, f.pose_t))

## 깊이 0..1 — 팩이 적어 준 값, 없으면 제 박자(주민·시연용)
static func deep(f: Stick3D) -> float:
	return clampf(float(f.get_meta("part_k", 0.5 - 0.5 * cos(f._t * TAU / PERIOD))), 0.0, 1.0)

## 안김 0..1 — 팩이 적어 준 값, 없으면 0(걸어 지나는 몸)
static func cling(f: Stick3D) -> float:
	return clampf(float(f.get_meta("part_c", 0.0)), 0.0, 1.0)

## 미끄러짐 0..1 — 팩의 part_v(−1..0)를 뒤집어서
static func slide(f: Stick3D) -> float:
	return clampf(-float(f.get_meta("part_v", 0.0)), 0.0, 1.0)

## 걷기 0/1 — 몸의 속도로
static func walk(f: Stick3D) -> float:
	return 1.0 if f.speed > 0.05 and f.move_dir.length_squared() > 0.0001 and not f.airborne and not f.seated else 0.0

## 골반은 젖히며 지날 땐 깊을수록 조금 내려앉고 안기면 조금 오른다(늘어진 몸); 몸통은 젖힐 땐 앞으로(깊을수록 더), 안기면 조금 뒤로
static func lean(f: Stick3D) -> float:
	var kk := k(f); var d := deep(f); var c := cling(f)
	f.pelvis.position.y = StickRig.HIP_Y + (0.03 * c - 0.03 * d * (1.0 - c)) * kk
	return ((0.18 + 0.1 * d) * (1.0 - c) - 0.08 * c + 0.02 * sin(f._t * 2.4)) * kk

## 팔다리 — 젖히며 지날 땐 두 손이 가슴 앞에서 번갈아 바깥으로, 걸으면 무릎을 들어 넘고 고개는 가슴으로; 안기면 팔이 옆 위로 가닥을 쥐고 다리가 늘어져 흔들리며 고개는 발밑을, 미끄러지면 무릎이 들리고 팔이 펴진다. 둘 사이는 안김으로 섞는다(받히는 순간 튀지 않게)
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "part": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var d := deep(f); var c := cling(f); var dn := slide(f); var w := walk(f)
	# 젖히며 지나는 몸
	var sweep := sin(f._t * TAU / SWEEP_T + (PI / 2.0 if s > 0.0 else 0.0))   # +면 이 손이 바깥으로
	var push := maxf(0.0, sweep)
	var hip_w: float; var knee_w: float
	if w != 0.0:
		var a := sin(f._t * TAU / (STEP_T * 2.0)) * s   # +면 이쪽 다리가 앞
		var lift := maxf(0.0, a)
		hip_w = 0.15 + 0.6 * lift + 0.3 * minf(0.0, a) + 0.1 * d
		knee_w = 0.2 + 0.8 * sin(PI * lift)
	else:
		hip_w = 0.15 + 0.1 * d
		knee_w = 0.3 + 0.15 * d
	var shx_w := 1.2 + 0.4 * d + 0.15 * sweep
	var shz_w := 0.12 + 0.2 * kk + (0.35 + 0.45 * push) * d * kk
	var el_w := 1.0 - 0.4 * push * d
	var neck_w := 0.25 * d - 0.05 * sweep
	# 안긴 몸
	var sw := sin(f._t * TAU / SWING_T) * 0.08 * s
	var hip_c := 0.12 + sw + 0.3 * dn
	var knee_c := 0.25 + 0.45 * dn
	var shx_c := 2.1 + 0.5 * dn
	var shz_c := 0.1 + 0.55 - 0.3 * dn
	var el_c := 0.6 - 0.4 * dn
	var neck_c := 0.3 - 0.1 * dn
	hip.rotation.x = -(lerpf(hip_w, hip_c, c) * kk)
	knee.rotation.x = -(-(lerpf(knee_w, knee_c, c) * kk))
	sh.rotation.x = -(0.2 * c + lerpf(shx_w, shx_c, c) * kk); sh.rotation.z = -s * lerpf(shz_w, 0.1 + (shz_c - 0.1) * kk, c)
	el.rotation.x = -(lerpf(el_w, el_c, c) * kk + 0.1)
	if s > 0.0: f.neck.rotation.x += lerpf(neck_w, neck_c, c) * kk
	return true
