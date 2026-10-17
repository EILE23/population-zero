class_name ClimbJump
extends RefCounted
## 탑 주민의 뜀 맞추기(코드 정리, run 171 — 백로그 "Grows from Pin wheel" 의 hygiene 줄: 리퍼의 land_x·외줄꾼의 _leap·타는 이의 _fit 이 저마다 로더의 뜀을 베꼈다 — 넷째 주민이 또 베끼기 전에 한 곳으로).
## 로더(climb.gd)의 수 그대로: 초속은 JUMP_MIN 430..JUMP_V 860 을 웅크린 만큼(CHARGE 0.7 s 에 비례), 가로는 RUN 300 안, 중력 G 2400.
## 반암시적 오일러(로더와 같은 순서 — 틱마다 중력을 뺀 뒤 자리를 옮긴다)는 첫 틱부터 G·dt 만큼 느리니 실제 초속은 vy − G·dt/2: 여기서 한 번만 다룬다(60 Hz 에서 7 px, 30 Hz 에서 14 px 의 차 — 안 더하면 발끝만 턱에 걸린다).
## fit(): (ox, oy) 에서 (tx, ty) 에 내리는 뜀 — 타는 이(run 169)가 쓰던 식 그대로(점검 probe_escape 의 값은 그대로). over(): 꼭대기가 apex 만큼 높고 dy 위에 내리는 뜀 — 높이뛰기 선수(run 171)가 가로대 위로 발이 지나게 쓴다.
## 외줄꾼·리퍼는 아직 제 식을 쓴다(점검 값이 한 틱 움직일 수 있어 다음 정리 조각에서 — 백로그의 같은 줄).

const C = preload("res://scripts/games/climb.gd")
const VX_K := 0.9         # fit 이 가로를 가는 RUN 의 몫 — 공중에서 안 민다(AIR 가 없다)

## 초속 vy0 를 내는 데 웅크릴 시간(s) — JUMP_MIN 아래는 0(톡 뜀)
static func charge_of(vy0: float) -> float:
	return clampf((vy0 - C.JUMP_MIN) / (C.JUMP_V - C.JUMP_MIN), 0.0, 1.0) * C.CHARGE

## (ox, oy) → (tx, ty): 가로를 RUN × vx_k 로 가는 시간에 그 높이를 오르내릴 vy(JUMP_MIN 아래면 톡 뜀 그대로, JUMP_V 가 끝)와 그 비행 시간으로 낸 vx(RUN 안) — {vx, vy, fly_t, charge_s}
static func fit(ox: float, oy: float, tx: float, ty: float, dt: float, vx_k := VX_K) -> Dictionary:
	var dist := absf(tx - ox); var dy := ty - oy
	var tf := maxf(dist / (C.RUN * vx_k), 0.01)
	var half_g := C.G * dt / 2.0
	var need := (C.G * tf * tf + 2.0 * dy) / (2.0 * tf) + half_g
	var vy0 := clampf(need, C.JUMP_MIN, C.JUMP_V)
	var ve := vy0 - half_g
	var fly_t := (ve + sqrt(maxf(0.0, ve * ve - 2.0 * C.G * dy))) / C.G
	return { "vx": signf(tx - ox) * minf(dist / fly_t, C.RUN), "vy": vy0, "fly_t": fly_t, "charge_s": charge_of(vy0) }

## 꼭대기가 뛴 자리보다 apex(px) 높고 dy(px, + 위)에 내리는 뜀 — {vy, t_up, t_down, fly_t, apex, charge_s}: 가로는 부르는 쪽이 t_up·t_down 으로 맞춘다(꼭대기를 어디에 둘지는 제 일)
static func over(apex: float, dy: float, dt: float) -> Dictionary:
	var half_g := C.G * dt / 2.0
	var ve := sqrt(2.0 * C.G * maxf(0.0, apex))
	var vy0 := clampf(ve + half_g, C.JUMP_MIN, C.JUMP_V)
	ve = vy0 - half_g
	var t_up := ve / C.G
	var t_down := sqrt(maxf(0.0, ve * ve - 2.0 * C.G * dy)) / C.G
	return { "vy": vy0, "t_up": t_up, "t_down": t_down, "fly_t": t_up + t_down, "apex": ve * ve / (2.0 * C.G), "charge_s": charge_of(vy0) }
