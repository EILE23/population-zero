class_name PoisePoses
extends RefCounted
## 모으기 자세(Climb 팩 escape 의 주민 반쪽 — 타는 이, run 169; 운영자 보드의 '균형' 가족, jolt 의 다음): `poise` 덜컥 가는 바퀴의 핀 위에서, 위 발판으로 톡 뛰기 전에 몸을 모으는 몸 —
## 모으기(0..0.2): 무릎이 깊이 접히며 골반이 내려앉고, 두 팔이 뒤로 당겨지고, 상체가 앞으로 숙고 고개가 위 발판의 턱을 올려다본다(예비)
## → 버티기(0.2..): 모은 채 9 Hz 로 떤다 — 무릎·팔·골반의 잔떨림이 버틸수록 커진다(POISE_T 0.5 s 가 가장 짧은 버팀; 핀이 꼭대기에 멎는 다음 박자까지 팩이 쥐고 있다 — 어느 순간도 정지화가 아니다)
## → 뜀: 팩이 자세를 비우고 공중(airborne)으로 — stick3d 의 블렌딩이 팔을 내린다(회수). jolt(덜컥을 받는 몸)·steady(발을 얹어 보는 몸)·limber(다리를 터는 몸)와 다르다: 이건 멎은 핀 위에서 뛰기 직전에 쥐는 한 번.
## 시계는 pose_t; meta "poise_t" 가 있으면 그 값(점검용). done(f) 가 참이면(POISE_T) 팩이 뛰어도 된다. stick3d_jolt.gd 처럼 주제별 파일

const GATHER_T := 0.2
const POISE_T := 0.5      # 가장 짧은 버팀 — 팩은 핀이 꼭대기에 멎는 박자까지(그리고 모아야 할 웅크림만큼) 더 쥔다
const TREMBLE_HZ := 9.0
const DIP := 0.14         # 무릎이 깊이 접혀 골반이 내려앉는 높이(m)
const HIP := 0.95         # 허벅지가 앞으로 접히는 각(rad)
const KNEE := 1.4         # 무릎이 접히는 각(rad)
const ARM := 0.85         # 팔이 뒤로 당겨지는 각(rad)

## 자세의 시계 — 점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("poise_t", f.pose_t))

## 다 모았나 — 팩이 뛰어도 된다
static func done(f: Stick3D) -> bool:
	return at(f) >= POISE_T

## 모인 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, GATHER_T, at(f))

## 잔떨림 −1..1 — 버틸수록 커진다(모으기 끝엔 반, 0.8 s 에 온전히)
static func tremble(f: Stick3D, s: float) -> float:
	var grow := 0.5 + 0.5 * clampf((at(f) - GATHER_T) / 0.6, 0.0, 1.0)
	return sin(f._t * TAU * TREMBLE_HZ + s) * grow * k(f)

## 골반은 무릎이 접히며 깊이 내려앉고 떨린다; 상체는 앞으로 숙는다(뛸 쪽으로)
static func lean(f: Stick3D) -> float:
	var kk := k(f)
	f.pelvis.position.y = StickRig.HIP_Y - (DIP + 0.01 * tremble(f, 0.0)) * kk
	return (0.35 + 0.02 * tremble(f, 0.7)) * kk

## 팔다리 — 두 다리 다 깊이 접힌 채 떨리고, 팔은 뒤로 당겨져 떨리며, 고개는 위 발판의 턱을 본다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "poise": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var q := tremble(f, s)
	hip.rotation.x = -(HIP + 0.04 * q) * kk; hip.rotation.z = 0.0
	knee.rotation.x = (KNEE + 0.06 * q) * kk
	sh.rotation.z = -s * (0.12 + 0.2 * kk)
	sh.rotation.x = (ARM + 0.05 * q) * kk   # 뒤로 당긴 팔(+x 가 뒤)
	el.rotation.x = -(0.3 + 0.1 * kk)
	if s > 0.0: f.neck.rotation.x -= 0.4 * kk; f.chest.rotation.x += 0.1 * kk   # 고개를 들어 턱을 본다
	return true
