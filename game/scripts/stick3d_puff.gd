class_name PuffPoses
extends RefCounted
## 민들레 홀씨 가족 자세(Climb 콘텐츠 팩 dandelion, run 150 — data/climb/dandelion.json, scripts/games/climb_dandelion.gd; 운영자 보드의 '숨·입김' 가족 — 제 숨으로 무언가를 띄우는 몸): `puff` 줄기 앞에 서서 홀씨를 부는 몸 —
## 들숨(0..0.5): 가슴이 오르며(chest 가 뒤로 젖혀진다) 어깨가 들려 두 팔이 옆으로 벌어져 오르고 골반이 조금 뜨며 고개가 머리 쪽으로 다가간다(예비)
## → 날숨(0.5..0.9): 고개를 앞으로 밀며 몸통이 숙여지고 가슴이 둥글게 말리며 팔이 떨어지고 골반이 내려앉고 무릎이 접힌다(불기 — 팩의 blow_at 0.5 에 첫 홀씨가 떠난다)
## → 회수(0.9..1.4): 바로 선다 — 풀린 무릎, 내린 팔, 앞을 보는 고개. 그 뒤 로더가 자세를 비울 때까지 2초 숨에 무릎·골반이 조금 흔들린다 — 정지화가 아니다.
## 시계는 pose_t; meta "puff_t" 가 있으면 그 값(점검·주민 시연용 — 한 순간에 멈춰 세운다). done(f) 가 참이면(1.4초) 로더가 자세를 비운다.
## storm(팔짱 끼고 하늘을 본다)·shade(손차양)·sigh(탁자를 짚는다)와 다르다: 이건 숨 자체가 동작인 몸 — 들이쉬고, 불고, 선다. stick3d_stomp.gd 처럼 주제별 파일

const IN_T := 0.5
const OUT_T := 0.4
const REC_T := 0.5
const BLOW_T := 1.4
const ENTER_T := 0.2
const BREATH := 2.0

## 자세에 든 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, ENTER_T, f.pose_t)

## 자세의 시계 — 팩·점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("puff_t", f.pose_t))

## 불기가 끝났나 — 로더가 자세를 비운다
static func done(f: Stick3D) -> bool:
	return at(f) >= BLOW_T

## [breath, blow] 0..1 — 들이쉰 몫(날숨에 내려간다), 부는 몫(회수에 내려간다)
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var inn := smoothstep(0.0, IN_T, u)
	var out := smoothstep(IN_T, IN_T + OUT_T, u)
	var rec := smoothstep(IN_T + OUT_T, BLOW_T, u)
	return [inn * (1.0 - out), out * (1.0 - rec)]

## 골반이 들숨에 조금 뜨고 날숨에 내려앉으며 쉴 땐 숨에 흔들린다; 몸통은 들숨에 조금, 날숨에 깊이 앞으로
static func lean(f: Stick3D) -> float:
	var kk := k(f); var ph := phases(f); var b := float(ph[0]); var w := float(ph[1])
	var rest := 0.5 + 0.5 * sin(f._t * TAU / BREATH)
	f.pelvis.position.y = StickRig.HIP_Y + (0.015 * b - 0.03 * w - 0.005 * rest) * kk
	return (0.05 + 0.15 * b + 0.35 * w + 0.01 * sin(f._t * TAU / BREATH)) * kk

## 팔다리 — 두 팔: 들숨에 어깨가 들려 옆으로 벌어져 오르고 날숨에 떨어진다; 다리: 날숨에 무릎이 접힌다, 쉴 땐 숨에 흔들린다. 고개는 들숨에 머리 쪽으로, 날숨에 앞으로 민다; 가슴은 들숨에 젖혀지고 날숨에 말린다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "puff": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var ph := phases(f); var b := float(ph[0]); var w := float(ph[1])
	var breath := 0.02 * sin(f._t * TAU / BREATH) * kk
	hip.rotation.x = -((0.08 + 0.12 * w) * kk)
	knee.rotation.x = (0.1 + 0.2 * w) * kk + breath
	sh.rotation.x = -((0.2 + 0.35 * b - 0.15 * w) * kk); sh.rotation.z = -s * (0.12 + 0.3 * b) * kk; el.rotation.x = -((0.35 + 0.2 * b - 0.2 * w) * kk)
	if s > 0.0:
		f.neck.rotation.x += (0.25 * b + 0.45 * w) * kk
		f.chest.rotation.x += (-0.25 * b + 0.15 * w) * kk
	return true
