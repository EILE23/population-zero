class_name NapPoses
extends RefCounted
## 낮잠방 자세("Elders and children" 6조각, run 108): `rock` 흔들의자 — 0.4 앉은 몸이 흔들림에 실리고(예비) → 2.2초에 한 번 의자와 함께 골반째 ±0.12 rad 앞뒤로 기운다(유지):
## 고개는 반 박자 늦게 따라오고, 뒤로 기울 때 다리가 조금 뻗어 발끝이 바닥을 밀고, 앞으로 올 때 오른손이 팔걸이를 톡 친다; 자세가 풀리면 stick3d 블렌딩이 세운다(회수).
## 박자는 벽시계 — 의자(town_nap _nap_tick)와 몸이 한 박자다. 사람도 주인도 같은 자세.
## `rub` 깨어남 — 0.4 누운 골반이 세워지며 윗몸을 일으키고(예비) → 0.9 오른 주먹이 눈을 비빈다(유지: 손목이 14Hz 로 잘게, 고개가 손으로 기운다) → 0.3 손이 무릎으로(회수).
## 왼손은 뒤로 침대를 짚는다. 문소리에 깬 아이도, 간이침대에 누웠다 깬 사람도 같은 자세. stick3d_sunroom.gd 처럼 주제별 파일

const ROCK_T := 2.2
const ROCK_A := 0.12
const ROCK_IN := 0.4
const RUB_T := 1.6

## 흔들림 −1..1 — 모두 같은 시계(의자와 몸). 양수 = 뒤로. late 만큼 늦은 위상(고개)
static func rock_phase(late := 0.0) -> float:
	return sin(Time.get_ticks_msec() / 1000.0 * TAU / ROCK_T - late)

static func rock_k(f: Stick3D) -> float:
	return smoothstep(0.0, ROCK_IN, f.pose_t)

static func sit_up(t: float) -> float:
	return smoothstep(0.0, 0.4, t)

static func rub_k(t: float) -> float:
	return smoothstep(0.4, 0.6, t) * (1.0 - smoothstep(1.3, RUB_T, t))

static func lean(f: Stick3D) -> float:
	if f.pose_request == "rock":
		var k := rock_k(f)
		f.pelvis.rotation.x = -ROCK_A * rock_phase() * k   # 골반째 — 의자가 기우는 만큼(음수 = 뒤, 누운 자세와 같은 부호)
		return -0.05 - 0.04 * rock_phase() * k
	var t := minf(f.pose_t, RUB_T); var su := sit_up(t)
	f.pelvis.rotation.x = -1.5 * (1.0 - su)
	f.pelvis.position.y = lerpf(0.16, 0.13, su)   # 매트 위에 앉은 골반
	return 0.2 * su + 0.08 * rub_k(t)

static func limbs(f: Stick3D, s: float) -> bool:
	if not (f.pose_request in ["rock", "rub"]): return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	if f.pose_request == "rock":
		var k := rock_k(f); var ph := rock_phase() * k; var back := maxf(ph, 0.0); var fwd := maxf(-ph, 0.0)
		hip.rotation.x = -(1.5 - 0.2 * back); knee.rotation.x = -(-1.45 + 0.4 * back)
		sh.rotation.x = -(0.5 + 0.05 * ph); sh.rotation.z = -s * 0.14; el.rotation.x = -(1.0 - 0.1 * ph + (0.2 * fwd if s > 0.0 else 0.0))
		if s > 0.0: f.neck.rotation.x += 0.1 * rock_phase(0.7) * k
		return true
	var t := minf(f.pose_t, RUB_T); var su := sit_up(t); var rk := rub_k(t)
	hip.rotation.x = -(0.15 + 0.3 * su + (0.1 if s < 0.0 else 0.0)); knee.rotation.x = -(-0.2 - 0.25 * su)   # 다리는 침대 위에 뻗은 채 조금 당긴다(왼쪽이 조금 더)
	if s > 0.0:
		sh.rotation.x = -(0.5 * su + 0.9 * rk); sh.rotation.z = -s * (0.12 + 0.1 * rk) + sin(f._t * 14.0) * 0.08 * rk; el.rotation.x = -(0.35 + 0.4 * su + 1.4 * rk)
		f.neck.rotation.x += 0.3 * rk
	else:
		sh.rotation.x = -(0.5 - 1.0 * su); sh.rotation.z = s * 0.2 * su; el.rotation.x = -(0.3)
	return true
