class_name SpinPoses
extends RefCounted
## 등대 렌즈 가족 자세(Climb 콘텐츠 팩 lens, run 152 — data/climb/lens.json, scripts/games/climb_lens.gd; 운영자 보드의 '손잡이 돌리기·윈치' 가족 — 한 손으로 허리 높이의 바퀴를 돌리는 몸): `spin` 렌즈의 손바퀴를 돌리는 몸 —
## 예비(0..0.25): 오른손이 앞 허리 높이의 바퀴로 내려가 쥐고 바퀴를 반의 반 바퀴 되감는다(팔이 조금 뒤로), 오른발이 앞으로 나가 버티고 골반이 조금 내려앉으며 왼팔이 균형으로 옆에 벌어진다, 고개는 바퀴를 본다
## → 돌림(0.25..1.45): 손이 몸 앞의 세로 원을 네 바퀴 돈다 — 어깨가 앞뒤로 흔들리고 팔꿈치가 반 박자 앞서 접혔다 펴지며(팔꿈치가 이끈다), 바퀴마다 손이 내려가는 쪽에서 어깨(가슴)가 앞으로 꺼지고 골반이 조금 더 내려앉는다; 처음은 느리게 붙고 가운데가 빠르다; 고개는 바퀴에서 렌즈로 올라간다
## → 놓음(1.45..1.8): 바퀴가 느려지며 손이 열려 팔이 내려오고 왼팔이 접히며 바로 선다. 정지화가 아니다: 쥐고, 돌리고, 놓고, 선다.
## 시계는 pose_t; meta "spin_t" 가 있으면 그 값(점검·주민 시연용 — 한 순간에 멈춰 세운다). done(f) 가 참이면(1.8초) 로더가 자세를 비운다.
## crank(두 손이 가슴 앞의 윈치를 모아 쥐고 돈다 — 일의 길이가 손의 것)·turn(한 손이 가슴 높이 회전문 손잡이를)·yank(옆의 것을 가슴으로 홱)와 다르다: 이건 한 손이 허리 높이에서 제 박자로 네 바퀴 돌리고 놓는 몸. stick3d_yank.gd 처럼 주제별 파일

const WIND_T := 0.25
const TURNS := 4.0
const TURN_T := 0.3       # 한 바퀴(초) — 팩의 바퀴는 더 빨리 돈다(렌즈의 네 배), 손은 제 박자
const REL_T := 0.35
const SPIN_T := 1.8
const ENTER_T := 0.1
const BACK := 0.25        # 예비에 되감는 바퀴(회전)

## 자세에 든 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, ENTER_T, f.pose_t)

## 자세의 시계 — 팩·점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("spin_t", f.pose_t))

## 돌림이 끝났나 — 로더가 자세를 비운다
static func done(f: Stick3D) -> bool:
	return at(f) >= SPIN_T

## [hold, psi, set] — 바퀴를 쥔 몫 0..1(놓음에 내려간다), 바퀴의 각 rad(되감기 −BACK 바퀴에서 네 바퀴, 놓음에 조금 더 흘러 선다), 자리를 잡은 몫 0..1(예비에 오른다)
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var st := smoothstep(0.0, WIND_T, u)
	var turns := -BACK * st
	var p := clampf((u - WIND_T) / (TURNS * TURN_T), 0.0, 1.0)
	turns += TURNS * smoothstep(0.0, 1.0, p)   # 느리게 붙고 가운데가 빠르다
	var rel := smoothstep(0.0, REL_T, u - WIND_T - TURNS * TURN_T)
	turns += 0.15 * rel                        # 놓은 바퀴가 조금 더 흘러 선다
	return [1.0 - rel, turns * TAU, st]

## 골반은 자리를 잡으며 조금, 손이 내려가는 쪽에서 조금 더 내려앉는다; 몸통은 바퀴 쪽으로 기울고 바퀴마다 흔들린다
static func lean(f: Stick3D) -> float:
	var kk := k(f); var ph := phases(f); var hold := float(ph[0]); var psi := float(ph[1]); var st := float(ph[2])
	f.pelvis.position.y = StickRig.HIP_Y - (0.04 * st * hold + 0.02 * maxf(0.0, -sin(psi)) * hold) * kk
	return (0.14 * st + 0.05 * cos(psi) * st) * hold * kk

## 팔다리 — 오른팔: 앞 허리 높이의 바퀴를 쥐고 세로 원을 돈다(어깨 앞뒤, 팔꿈치가 반 박자 앞서); 왼팔: 옆으로 벌려 균형(놓음에 접힌다); 다리: 오른발 앞·왼발 뒤로 버티며 바퀴마다 흔들린다; 가슴은 손이 내려가는 쪽으로 꺼진다; 고개는 바퀴를 보다 렌즈로 올라간다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "spin": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var ph := phases(f); var hold := float(ph[0]); var psi := float(ph[1]); var st := float(ph[2])
	var g := st * hold   # 쥔 손 — 자리를 잡고, 아직 놓지 않은
	var rock := 0.04 * sin(psi) * g
	if s > 0.0:
		sh.rotation.x = -((0.6 + 0.3 * sin(psi)) * g)                 # 앞 허리 높이, 바퀴를 따라 앞뒤로
		sh.rotation.z = s * 0.15 * g                                   # 조금 밖으로(+z 는 local +x 쪽 — run 151 의 점검)
		el.rotation.x = -((0.9 + 0.35 * cos(psi + 0.5)) * g)          # 팔꿈치가 반 박자 앞선다
		hip.rotation.x = (0.4 + rock) * kk; knee.rotation.x = (0.5 + 0.05 * maxf(0.0, -sin(psi)) * g) * kk   # 앞발 — 버틴다(crank 의 선 자세)
		f.chest.rotation.x += 0.08 * maxf(0.0, -sin(psi)) * g * kk     # 손이 내려가는 쪽에서 어깨가 꺼진다(x 만 — stick3d 는 chest 의 z 를 매 틱 되돌리지 않는다)
		f.neck.rotation.x += (0.3 * st * hold - 0.15 * (1.0 - hold) * st) * kk   # 바퀴를 보다 놓으며 렌즈로
		f.neck.rotation.y += -0.2 * maxf(0.0, sin(psi)) * g * kk
	else:
		sh.rotation.x = -(0.25 * g); sh.rotation.z = s * 0.9 * g        # 균형 팔 — 옆으로 벌린다(s < 0 이라 local −x 쪽)
		el.rotation.x = -(0.3 * g)
		hip.rotation.x = -((0.25 - rock) * kk); knee.rotation.x = 0.15 * kk   # 뒷발
	return true
