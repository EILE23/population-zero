class_name TreadPoses
extends RefCounted
## 톱니 컨베이어 가족 자세(Climb 콘텐츠 팩 gears, run 124 — data/climb/gears.json, scripts/games/climb_gears.gd; 운영자 보드의 '러닝머신·무빙워크' 가족 — 흐르는 바닥 위에 선 몸): `tread` 띠 위의 몸 —
## 0.15 무릎이 내려앉고 두 발이 앞뒤로 벌어지며 두 팔이 조금 벌어진다(예비) → 유지: 띠의 방향(meta "tread_k" −1..1, + 면 보는 쪽으로 실려 간다 — 팩의 carry 가 적는다, 없으면 11.2초 주기의 제 박자)을 거슬러 몸통이 기울고(실려 가는 쪽의 반대로, 무빙워크 위 사람처럼),
## 서 있으면 0.8초마다 끌려가는 발을 한 짝씩 떼어 제자리에 고쳐 딛는 잔걸음; 띠를 거슬러 걸으면("tread_w" −1) 0.3초의 짧고 빠른 걸음에 앞으로 숙인 몸과 펌프질하는 팔, 띠와 같은 쪽으로 걸으면(+1) 느긋한 긴 보폭;
## 톱니가 멈췄다 다시 돌기 시작하면("tread_j" 초, 팩의 started) 0.25초 몸통이 새 방향의 반대로 휘청하고 무릎이 더 접힌다(jolt) → 턱 밖으로 나가 로더가 자세를 비우면 stick3d 의 블렌딩이 팔을 내리고 무릎을 편다(회수).
## ride(원을 그리며 실려 가는 몸)·sway(골반째 기우는 몸)와 다르다: 이건 평평한 바닥이 발밑에서 흐르는 몸. stick3d_ride.gd 처럼 주제별 파일

const BRACE_T := 0.15
const STEP_T := 0.3      # 거슬러 걷는 한 걸음
const STRIDE_T := 0.5    # 같은 쪽으로 걷는 한 걸음
const SHUFFLE_T := 0.8   # 서서 발을 고쳐 딛는 주기
const JOLT_T := 0.25
const PERIOD := 11.2     # 메타가 없을 때의 제 박자(팩의 한 주기)

## 벌어진 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, BRACE_T, f.pose_t)

## 보는 쪽으로 실려 가는 정도 −1..1 — 팩이 적어 준 값, 없으면 제 박자(주민·시연용)
static func carry(f: Stick3D) -> float:
	return clampf(float(f.get_meta("tread_k", signf(sin(f._t * TAU / PERIOD)))), -1.0, 1.0)

## 걷기: −1 거슬러 · 0 서서 · +1 같은 쪽으로
static func walk(f: Stick3D) -> float:
	return clampf(float(f.get_meta("tread_w", 0.0)), -1.0, 1.0)

## 돌기 시작한 직후의 휘청 1..0
static func jolt(f: Stick3D) -> float:
	return 1.0 - smoothstep(0.0, JOLT_T, float(f.get_meta("tread_j", 9.0)))

## 골반이 내려앉고(휘청이면 더), 몸통은 서면 실려 가는 쪽의 반대로, 거슬러 걸으면 앞으로 숙인다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var c := carry(f); var w := walk(f); var j := jolt(f)
	f.pelvis.position.y = StickRig.HIP_Y - (0.05 + 0.05 * j) * kk
	var body := -0.14 * c if w == 0.0 else (0.22 if w < 0.0 else 0.06)
	return (body - 0.25 * c * j + 0.02 * sin(f._t * 2.5)) * kk

## 팔다리 — 거슬러: 짧고 빠른 걸음에 펌프질하는 팔; 같은 쪽: 긴 보폭; 서서: 앞뒤로 벌린 발을 한 짝씩 고쳐 딛고 팔은 옆으로 벌려 균형을 잡는다. 고개는 띠를 본다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "tread": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var c := carry(f); var w := walk(f); var j := jolt(f)
	if w < 0.0:
		var a := sin(f._t * TAU / (STEP_T * 2.0)) * s * 0.45
		hip.rotation.x = -(a + 0.25 * kk); knee.rotation.x = -(-(0.65 if a < 0.0 else 0.25) - 0.1 * kk)
		sh.rotation.x = -(-a * 0.9); sh.rotation.z = -s * 0.12; el.rotation.x = -(0.9)
	elif w > 0.0:
		var a := sin(f._t * TAU / (STRIDE_T * 2.0)) * s * 0.55
		hip.rotation.x = -(a); knee.rotation.x = -(-(0.45 if a < 0.0 else 0.2))
		sh.rotation.x = -(-a * 0.5); sh.rotation.z = -s * 0.1; el.rotation.x = -(0.35)
	else:
		var lift := maxf(0.0, sin(f._t * TAU / SHUFFLE_T + (0.0 if s > 0.0 else PI))) * kk   # 한 짝씩 번갈아 뗀다
		hip.rotation.x = -((0.22 if s > 0.0 else -0.18) * kk + 0.15 * lift - 0.1 * c * j)
		knee.rotation.x = -(-(0.3 + 0.35 * lift + 0.2 * j) * kk)
		sh.rotation.x = -((-0.25 * c + 0.3 * c * j) * kk); sh.rotation.z = -s * (0.1 + 0.4 * kk); el.rotation.x = -(0.4 - 0.1 * kk)
	if s > 0.0: f.neck.rotation.x += (0.25 if w == 0.0 else 0.12) * kk
	return true
