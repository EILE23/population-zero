class_name FightPoses
extends RefCounted
## 싸움 자세(운영자 2026-09-30: "발차기·주먹질 연계·제트킥 다 빼도 되니까, 때리고 넘어지고 일어나는 게 어색하지 않게").
## 기술은 둘뿐 — 주먹(번갈아 좌우)과 앞차기. 대신 각 동작을 네 박자로 만든다: 예비(뒤로 당김) → 타격(순간 뻗음) → 멈춤 → 회수.
## 맞기(flinch)는 맞은 방향으로 고개·상체가 젖혀졌다 돌아오고, 넘어짐(down)은 뒤로 쓰러져 한 번 튕기며 미끄러지고, 일어나기(getup)는
## 옆으로 돌아누움 → 한 손 짚고 무릎 세움 → 일어섬 세 단계. Stick3D 가 action 을 보고 부른다. 모든 각은 stick3d.gd 부호 약속을 따른다.

const PUNCH_T := 0.34
const KICK_T := 0.5
const ROUND_T := 0.62
const CHAIN_WINDOW := 0.35   # 이 안에 다시 누르면 다음 발차기
const FLINCH_T := 0.35
const GETUP_T := 1.0

## 0..1 진행을 네 박자 세기로 — 예비는 살짝 음수(뒤로 당김), 타격은 빠르게 1, 멈춤, 회수는 천천히 0
static func strike_k(a: float, wind: float, hit: float, hold: float) -> float:
	if a < wind: return -0.45 * sin(a / wind * PI * 0.5)
	if a < hit: return lerpf(-0.45, 1.0, smoothstep(0.0, 1.0, (a - wind) / (hit - wind)))
	if a < hold: return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (a - hold) / (1.0 - hold))

## 주먹: 뒷발에 체중을 싣고 주먹을 턱 옆으로 당겼다가, 허리·어깨를 돌리며 곧게 뻗고, 반대손은 턱 앞 가드. 앞발이 반 발짝 나간다
static func punch(f: Stick3D, a: float) -> void:
	var k := strike_k(a, 0.22, 0.38, 0.6)
	var ps := f.punch_side; var os := -ps
	var kp := maxf(k, 0.0)
	f.pelvis.rotation.y = -ps * 0.25 * k
	f.torso.rotation.x = 0.1 + 0.18 * kp; f.torso.rotation.y = -ps * 0.55 * k
	f.chest.rotation.y = -ps * 0.25 * k
	f.neck.rotation.x = -0.15 - 0.1 * kp
	f.shoulders[ps].rotation.x = -(0.6 + 1.1 * kp - 0.3 * minf(k, 0.0)); f.shoulders[ps].rotation.z = -ps * (0.25 + 0.1 * kp)
	f.elbows[ps].rotation.x = -(1.9 - 1.8 * kp)
	f.shoulders[os].rotation.x = -(1.0); f.shoulders[os].rotation.z = -os * 0.2; f.elbows[os].rotation.x = -(2.0)
	f.hips[ps].rotation.x = -(-0.25 - 0.1 * kp); f.knees[ps].rotation.x = -(-0.2)
	f.hips[os].rotation.x = -(0.3 + 0.15 * kp); f.knees[os].rotation.x = -(-0.35 - 0.1 * kp)
	f.pelvis.position.y = Stick3D.HIP_Y - 0.03 - 0.03 * kp

## 발차기 연속(운영자 2026-09-30: "발차기도 연속동작"): 누를 때마다 오른발 앞차기 → 왼발 앞차기 → 돌려차기. f.kick_step 0·1·2
static func kick(f: Stick3D, a: float) -> void:
	if f.kick_step == 2: roundhouse(f, a); return
	var ks := 1.0 if f.kick_step == 0 else -1.0; var ss := -ks   # 차는 발, 디딤발
	var chamber := smoothstep(0.0, 1.0, a / 0.3) if a < 0.3 else (1.0 if a < 0.72 else 1.0 - smoothstep(0.0, 1.0, (a - 0.72) / 0.28))
	var extend := maxf(strike_k(a, 0.3, 0.42, 0.62), 0.0) if a >= 0.3 else 0.0
	f.hips[ks].rotation.x = -(1.5 * chamber + 0.2 * extend); f.knees[ks].rotation.x = -(-2.0 * chamber * (1.0 - extend))
	f.hips[ss].rotation.x = -(-0.1 * chamber); f.knees[ss].rotation.x = -(-0.25 * chamber)
	f.torso.rotation.x = -0.25 * chamber - 0.15 * extend; f.neck.rotation.x = 0.2 * chamber
	f.pelvis.rotation.y = -ks * 0.15 * extend
	f.shoulders[ks].rotation.x = -(0.3); f.shoulders[ks].rotation.z = -ks * 0.9 * chamber; f.elbows[ks].rotation.x = -(0.8)
	f.shoulders[ss].rotation.x = -(0.7 * chamber); f.shoulders[ss].rotation.z = -ss * 0.7 * chamber; f.elbows[ss].rotation.x = -(1.2)
	f.pelvis.position.y = Stick3D.HIP_Y - 0.04 * chamber

## 돌려차기(마무리): 디딤발(왼)을 축으로 골반을 90° 돌리며 오른 무릎을 옆으로 들어 올리고, 정강이를 채찍처럼 휘둘러 옆에서 친 뒤 몸이 반 바퀴 더 돌아 되돌아온다
static func roundhouse(f: Stick3D, a: float) -> void:
	var lift := smoothstep(0.0, 1.0, a / 0.3) if a < 0.3 else (1.0 if a < 0.7 else 1.0 - smoothstep(0.0, 1.0, (a - 0.7) / 0.3))
	var snap := maxf(strike_k(a, 0.3, 0.44, 0.6), 0.0) if a >= 0.3 else 0.0
	var turn := smoothstep(0.0, 1.0, a / 0.45) * (1.0 - smoothstep(0.0, 1.0, (a - 0.7) / 0.3))
	f.pelvis.rotation.y = -1.4 * turn
	f.pelvis.rotation.z = 0.25 * lift   # 살짝 옆으로 누우며 다리를 높인다
	f.hips[1.0].rotation.x = -(1.75 * lift); f.hips[1.0].rotation.z = -0.35 * lift   # 허리 높이로 — 옆(z)으로 크게 돌리면 낮은 쓸기처럼 보였다
	f.knees[1.0].rotation.x = -(-1.9 * lift * (1.0 - snap))
	f.hips[-1.0].rotation.x = -(0.1); f.knees[-1.0].rotation.x = -(-0.3 * lift)
	f.torso.rotation.z = -0.35 * lift; f.torso.rotation.y = 0.6 * turn; f.neck.rotation.y = 0.9 * turn
	f.shoulders[1.0].rotation.x = -(-0.4 * lift); f.shoulders[1.0].rotation.z = -1.0 * lift; f.elbows[1.0].rotation.x = -(0.6)
	f.shoulders[-1.0].rotation.x = -(1.0 * lift); f.shoulders[-1.0].rotation.z = 0.4; f.elbows[-1.0].rotation.x = -(1.8)
	f.pelvis.position.y = Stick3D.HIP_Y - 0.03 * lift

## 맞기: 맞은 쪽으로 머리가 먼저 젖혀지고(0.08초) 상체·골반이 따라 밀렸다가 돌아온다. 팔은 반사적으로 얼굴 앞, 무릎이 꺾인다
static func flinch(f: Stick3D, a: float) -> void:
	var snap := sin(minf(a / 0.3, 1.0) * PI * 0.5) if a < 0.3 else 1.0 - smoothstep(0.0, 1.0, (a - 0.3) / 0.7)
	var head := sin(minf(a / 0.18, 1.0) * PI * 0.5) if a < 0.18 else 1.0 - smoothstep(0.0, 1.0, (a - 0.18) / 0.6)
	f.neck.rotation.x = 0.55 * head
	f.torso.rotation.x = -0.35 * snap; f.chest.rotation.x = -0.2 * snap; f.torso.rotation.y = 0.2 * snap
	f.pelvis.position.y = Stick3D.HIP_Y - 0.08 * snap
	for s in [-1.0, 1.0]:
		f.shoulders[s].rotation.x = -(1.3 * snap); f.shoulders[s].rotation.z = -s * 0.15; f.elbows[s].rotation.x = -(2.0 * snap)
		f.hips[s].rotation.x = -(0.25 * snap); f.knees[s].rotation.x = -(-0.5 * snap)

## 넘어져 누움: 등을 대고, 떨어진 직후(a<0.25)엔 팔다리가 들렸다 떨어지고, 그 뒤엔 힘없이 벌린 채 숨만
static func down(f: Stick3D, t_since: float) -> void:
	var bounce := maxf(0.0, 1.0 - t_since / 0.35)
	f.pelvis.rotation.x = -1.45; f.pelvis.position.y = 0.12 + 0.06 * sin(bounce * PI)
	f.torso.rotation.x = 0.1 - 0.25 * bounce; f.neck.rotation.x = -0.2 * bounce
	for s in [-1.0, 1.0]:
		f.hips[s].rotation.x = -(0.2 + 0.1 * s + 0.6 * bounce); f.knees[s].rotation.x = -(-0.4 - 0.5 * bounce)
		f.shoulders[s].rotation.x = -(0.6 + 0.8 * bounce); f.shoulders[s].rotation.z = -s * (1.0 - 0.3 * bounce); f.elbows[s].rotation.x = -(0.4)

## 일어나기 세 단계: 0~0.35 옆으로 돌아누우며 한 손 짚기 → 0.35~0.7 무릎 꿇고 한 발 세우기 → 0.7~1 밀고 일어서기
static func getup(f: Stick3D, a: float) -> void:
	var g1 := smoothstep(0.0, 1.0, a / 0.35); var g2 := smoothstep(0.0, 1.0, (a - 0.35) / 0.35); var g3 := smoothstep(0.0, 1.0, (a - 0.7) / 0.3)
	f.pelvis.rotation.x = lerpf(-1.45, -0.2, g1) * (1.0 - g2) + 0.25 * g2 * (1.0 - g3)
	f.pelvis.rotation.z = 0.6 * g1 * (1.0 - g2)
	f.pelvis.position.y = lerpf(0.12, 0.2, g1) * (1.0 - g2) + lerpf(0.2, Stick3D.HIP_Y - 0.12, g2) * g2 * (1.0 - g3) + lerpf(Stick3D.HIP_Y - 0.12, Stick3D.HIP_Y, g3) * g3
	f.torso.rotation.x = 0.5 * g1 * (1.0 - g3) + 0.35 * g2 * (1.0 - g3)
	f.shoulders[1.0].rotation.x = -(0.9 * g1 * (1.0 - g2) + 0.4 * g2 * (1.0 - g3)); f.elbows[1.0].rotation.x = -(0.2)
	f.shoulders[-1.0].rotation.x = -(0.3); f.elbows[-1.0].rotation.x = -(0.8 * (1.0 - g3))
	f.hips[1.0].rotation.x = -(1.4 * g2 * (1.0 - g3)); f.knees[1.0].rotation.x = -(-1.5 * g2 * (1.0 - g3))
	f.hips[-1.0].rotation.x = -(0.4 * g1 * (1.0 - g2) - 0.3 * g2 * (1.0 - g3)); f.knees[-1.0].rotation.x = -(-1.9 * g2 * (1.0 - g3) - 0.6 * g1 * (1.0 - g2))

## 타격 불꽃 — 맞은 자리에서 흰 별 조각이 짧게 퍼진다(0.18초)
static func spark(parent: Node3D, at: Vector3, heavy: bool) -> void:
	var p := CPUParticles3D.new(); p.amount = 14 if heavy else 8; p.lifetime = 0.18; p.one_shot = true; p.explosiveness = 1.0
	p.direction = Vector3.UP; p.spread = 180.0; p.initial_velocity_min = 2.5; p.initial_velocity_max = 5.0 if heavy else 3.5; p.gravity = Vector3.ZERO
	var bm := BoxMesh.new(); bm.size = Vector3(0.14, 0.025, 0.025); p.mesh = bm
	p.particle_flag_align_y = true
	var m := StandardMaterial3D.new(); m.albedo_color = Color("fff4d6"); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; p.material_override = m
	p.position = at; parent.add_child(p); p.emitting = true
	parent.get_tree().create_timer(0.5).timeout.connect(p.queue_free)

## 히트스톱 — 맞는 순간 세계를 잠깐 멈춘다(가벼운 0.05초, 무거운 0.09초). 실제 시간으로 재서 풀린다
static func hitstop(tree: SceneTree, heavy: bool) -> void:
	Engine.time_scale = 0.05
	tree.create_timer(0.09 if heavy else 0.05, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)

# ── 기술표 자세(FightMoves, 2026-10-01) ──
# 부호 약속(stick3d): hips.x = -θ 다리 앞으로 · knees.x = +b 정강이 뒤로 접힘 · hips.z = s·ψ 바깥으로 벌림 · shoulders.x = -θ 팔 앞(위)으로 · shoulders.z = s·ψ 바깥 ·
# elbows.x = -b 팔꿈치 굽힘 · torso.x + 앞으로 숙임 · torso.y - 오른어깨가 앞 · torso.z + 왼쪽으로 기욺 · pelvis.z + 오른골반이 올라감 · pelvis.y 몸 전체가 돈다

## 구간 진행 0..1 (a 가 a0 에서 a1 로 갈 때) — 부드럽게
static func seg(a: float, a0: float, a1: float) -> float:
	return smoothstep(0.0, 1.0, clampf((a - a0) / (a1 - a0), 0.0, 1.0))

## 올렸다(up 구간) 내리는(down 구간) 봉우리 0..1..0
static func bump(a: float, up0: float, up1: float, dn0: float, dn1: float) -> float:
	return seg(a, up0, up1) * (1.0 - seg(a, dn0, dn1))

static func move(f: Stick3D, m: String, a: float) -> void:
	match m:
		"jab": _straight(f, a, -1.0, 0.55)
		"cross": _straight(f, a, 1.0, 1.0)
		"hook": _hook(f, a, -1.0)
		"upper": _upper(f, a, 1.0)
		"front": _front(f, a)
		"push": _push(f, a)
		"round": _round(f, a)
		"knee": _knee(f, a)
		"backfist": _backfist(f, a)
		"fly": _fly(f, a)
		"hammer": _hammer(f, a)
		"block": _block(f, a)
		"dodge": _dodge(f, a)
		_: _straight(f, a, -1.0, 0.55)

## 가드 — 주먹을 턱 앞에(차는 동안·기다릴 때 공통)
static func _guard(f: Stick3D, s: float, k := 1.0) -> void:
	f.shoulders[s].rotation.x = -(1.25 * k); f.shoulders[s].rotation.z = -s * 0.25 * k; f.elbows[s].rotation.x = -(2.1 * k)

## 곧은 주먹(잽·스트레이트) — 잽(power 0.55)은 앞손으로 짧게 툭, 머리가 반대로 살짝 빠진다. 스트레이트(1.0)는 뒷발 뒤꿈치를 들며 골반·어깨를 한꺼번에 돌려 끝까지 뻗는다
static func _straight(f: Stick3D, a: float, s: float, power: float) -> void:
	var k := strike_k(a, 0.16 if power < 0.8 else 0.22, 0.34, 0.5)
	var kp := maxf(k, 0.0); var o := -s
	f.pelvis.rotation.y = s * -0.35 * k * power
	f.torso.rotation.y = s * -0.5 * k * power; f.chest.rotation.y = s * -0.25 * k * power
	f.torso.rotation.x = 0.08 + 0.2 * kp * power
	f.neck.rotation.x = -0.1 - 0.12 * kp; f.neck.rotation.z = -s * 0.15 * kp   # 머리는 뻗는 팔 반대로 비켜 둔다
	f.shoulders[s].rotation.x = -(1.0 + 0.62 * kp - 0.3 * minf(k, 0.0)); f.shoulders[s].rotation.z = -s * (0.15 + 0.12 * kp)
	f.elbows[s].rotation.x = -(2.0 - 1.95 * kp)
	_guard(f, o)
	f.hips[s].rotation.x = -(0.25 * power * kp - 0.1); f.knees[s].rotation.x = 0.15 + 0.2 * kp * power   # 때리는 쪽 뒷발 뒤꿈치가 들린다
	f.hips[o].rotation.x = -(0.3 + 0.2 * kp * power); f.knees[o].rotation.x = 0.35 + 0.15 * kp           # 앞발 무릎을 굽혀 체중을 싣는다
	f.pelvis.position.y = Stick3D.HIP_Y - 0.03 - 0.05 * kp * power

## 훅 — 골반을 반대로 감았다가(예비) 팔꿈치를 어깨 높이로 들어 90° 접은 채 몸통째 옆으로 휘두른다
static func _hook(f: Stick3D, a: float, s: float) -> void:
	var load := bump(a, 0.0, 0.2, 0.2, 0.32); var sw := seg(a, 0.22, 0.42); var back := seg(a, 0.6, 1.0)
	var turn := (-0.45 * load + 1.1 * sw) * (1.0 - back)   # +는 때리는 쪽 어깨가 앞으로
	f.pelvis.rotation.y = -s * 0.55 * turn
	f.torso.rotation.y = -s * 0.7 * turn; f.chest.rotation.y = -s * 0.3 * turn
	f.torso.rotation.x = 0.15 + 0.1 * sw * (1.0 - back); f.torso.rotation.z = s * 0.12 * sw * (1.0 - back)
	var arm := clampf(load + sw, 0.0, 1.0) * (1.0 - back)
	f.shoulders[s].rotation.x = -(1.25 + 0.2 * arm); f.shoulders[s].rotation.z = s * (1.2 * arm)   # 팔을 옆으로 들어 수평
	f.elbows[s].rotation.x = -(2.1 - 0.55 * arm)
	_guard(f, -s)
	f.hips[s].rotation.x = -(0.3); f.knees[s].rotation.x = 0.4
	f.hips[-s].rotation.x = -(-0.15); f.knees[-s].rotation.x = 0.3
	f.neck.rotation.y = s * 0.5 * turn
	f.pelvis.position.y = Stick3D.HIP_Y - 0.06 * arm

## 어퍼컷 — 무릎을 굽혀 깊이 가라앉았다가(예비) 다리로 튕겨 오르며 직각으로 굽힌 팔이 아래에서 위로. 끝엔 발끝으로 서서 상체가 뒤로 젖혀진다
static func _upper(f: Stick3D, a: float, s: float) -> void:
	var dip := bump(a, 0.0, 0.28, 0.3, 0.42); var up := seg(a, 0.28, 0.42) * (1.0 - seg(a, 0.62, 1.0))
	f.pelvis.position.y = Stick3D.HIP_Y - 0.13 * dip + 0.05 * up
	f.torso.rotation.x = 0.35 * dip - 0.25 * up; f.torso.rotation.y = -s * (0.3 * dip + 0.45 * up); f.torso.rotation.z = s * 0.2 * dip
	f.shoulders[s].rotation.x = -(0.1 + 2.1 * up); f.shoulders[s].rotation.z = -s * 0.2
	f.elbows[s].rotation.x = -(1.7 - 0.25 * up)
	_guard(f, -s)
	for t in [-1.0, 1.0]:
		f.hips[t].rotation.x = -(0.55 * dip - 0.05 * up); f.knees[t].rotation.x = 0.95 * dip
	f.neck.rotation.x = 0.2 * dip - 0.3 * up

## 앞차기(오른) — 무릎을 가슴까지 끌어올려 접고(예비), 발바닥을 앞으로 쭉 내지르며 골반이 밀려 나간다. 몸은 뒤로 젖혀 균형, 오른팔은 뒤로 휘둘러 힘을 싣는다
static func _front(f: Stick3D, a: float) -> void:
	var ch := bump(a, 0.0, 0.26, 0.62, 0.92); var ex := bump(a, 0.26, 0.4, 0.5, 0.64)
	f.hips[1.0].rotation.x = -(1.75 * ch - 0.25 * ex); f.knees[1.0].rotation.x = 2.3 * ch * (1.0 - ex) + 0.05
	f.hips[-1.0].rotation.x = -(-0.12 * ch); f.knees[-1.0].rotation.x = 0.3 * ch
	f.pelvis.rotation.x = -0.25 * ex; f.torso.rotation.x = -0.1 * ch + 0.1 * ex; f.neck.rotation.x = 0.25 * ch
	f.pelvis.rotation.y = -0.2 * ex
	f.shoulders[1.0].rotation.x = -(-0.5 * ex + 0.5 * ch * (1.0 - ex)); f.shoulders[1.0].rotation.z = 0.5 * ch; f.elbows[1.0].rotation.x = -(0.6)
	_guard(f, -1.0, ch)
	f.pelvis.position.y = Stick3D.HIP_Y + 0.04 * ex - 0.03 * ch * (1.0 - ex)

## 밀어차기(왼, 두 번째·더 셈) — 뒷발로 깡충 뛰어 나가며(lunge) 무릎을 턱 밑까지 끌어올리고, 몸 전체를 뒤로 크게 젖히며 발바닥으로 밀어 찬다.
## 두 팔은 뒤로 내리쳐 반동, 디딤발은 발끝으로. 맞으면 넘어지며 멀리 밀려난다
static func _push(f: Stick3D, a: float) -> void:
	var ch := bump(a, 0.0, 0.3, 0.62, 0.9); var ex := bump(a, 0.32, 0.44, 0.56, 0.72); var hop := bump(a, 0.12, 0.3, 0.42, 0.6)
	f.hips[-1.0].rotation.x = -(2.05 * ch - 0.5 * ex); f.knees[-1.0].rotation.x = 2.5 * ch * (1.0 - ex)
	f.hips[1.0].rotation.x = -(-0.2 * ch - 0.1 * ex); f.knees[1.0].rotation.x = 0.45 * ch * (1.0 - ex)
	f.pelvis.rotation.x = -0.45 * ex - 0.1 * ch; f.pelvis.rotation.y = 0.45 * ex
	f.torso.rotation.x = -0.15 * ex + 0.15 * ch * (1.0 - ex); f.torso.rotation.y = -0.3 * ex
	f.neck.rotation.x = 0.35 * ex
	for s in [-1.0, 1.0]:
		f.shoulders[s].rotation.x = -(1.2 * ch * (1.0 - ex) - 0.7 * ex); f.shoulders[s].rotation.z = s * 0.45 * ex; f.elbows[s].rotation.x = -(1.6 * (1.0 - ex) + 0.3)
	f.pelvis.position.y = Stick3D.HIP_Y + 0.14 * hop - 0.04 * ch * (1.0 - hop)

## 360° 돌려차기(오른, 마무리) — 왼쪽으로 반 박자 감았다가(예비) 디딤발로 돌며 오른 무릎을 옆으로 접어 수평까지 들고, 오른옆이 상대를 보는 순간
## 정강이를 채찍처럼 펴 옆에서 친다. 상체는 반대(왼)로 크게 젖혀 균형, 머리는 끝까지 상대를 보다가 몸을 따라 휙 돈다. 다리를 거두며 한 바퀴 다 돌아 착지
static func _round(f: Stick3D, a: float) -> void:
	var wind := bump(a, 0.0, 0.16, 0.16, 0.3)
	var yaw := 0.45 * wind - (PI / 2.0) * seg(a, 0.14, 0.42) - (1.5 * PI) * seg(a, 0.52, 1.0)   # 감기 +0.45 → 오른옆이 상대(-π/2) → 마저 한 바퀴(-2π)
	var ch := bump(a, 0.12, 0.32, 0.6, 0.86); var ex := bump(a, 0.32, 0.42, 0.5, 0.62)
	f.pelvis.rotation.y = yaw
	f.pelvis.rotation.z = 0.4 * ch                                           # 오른골반을 들어 다리를 높인다
	f.hips[1.0].rotation.z = 1.35 * ch; f.hips[1.0].rotation.x = -(0.3 * ch)  # 옆으로 수평까지
	f.knees[1.0].rotation.x = 2.2 * ch * (1.0 - ex)                           # 접었다 채찍처럼 편다
	f.hips[-1.0].rotation.z = -0.4 * ch; f.knees[-1.0].rotation.x = 0.35 * ch   # 디딤다리는 땅에 곧게, 무릎 살짝
	f.torso.rotation.z = 0.38 * ch; f.torso.rotation.x = -0.1 * ch; f.chest.rotation.z = 0.12 * ch   # 반대로 젖힌다(골반 기울기와 합쳐 약 50°)
	f.neck.rotation.z = -0.55 * ch
	f.neck.rotation.y = clampf(-wrapf(yaw, -PI, PI), -1.4, 1.4)   # 머리는 상대를 본다(스포팅) — 등 뒤로 넘어가면 휙 돈다
	_guard(f, -1.0)
	f.shoulders[1.0].rotation.x = -(-0.8 * ch); f.shoulders[1.0].rotation.z = 1.0 * ch; f.elbows[1.0].rotation.x = -(0.3)   # 오른팔은 뒤·아래로 휘둘러 반동
	f.pelvis.position.y = Stick3D.HIP_Y + 0.05 * bump(a, 0.25, 0.4, 0.55, 0.8) - 0.05 * wind

## 무릎차기(오른) — 두 손으로 상대 목덜미를 잡아 당겨 내리듯 팔을 앞·아래로, 무릎을 가슴까지 찍어 올린다. 골반은 앞으로, 디딤발은 발끝
static func _knee(f: Stick3D, a: float) -> void:
	var grab := bump(a, 0.0, 0.2, 0.6, 0.95); var up := bump(a, 0.2, 0.42, 0.52, 0.8)
	for s in [-1.0, 1.0]:
		f.shoulders[s].rotation.x = -(1.55 * grab - 0.5 * up); f.shoulders[s].rotation.z = -s * 0.2 * grab; f.elbows[s].rotation.x = -(0.6 + 0.7 * up)
	f.hips[1.0].rotation.x = -(2.15 * up); f.knees[1.0].rotation.x = 2.4 * up
	f.hips[-1.0].rotation.x = -(-0.15 * up); f.knees[-1.0].rotation.x = 0.1
	f.pelvis.rotation.x = -0.3 * up; f.torso.rotation.x = 0.25 * grab + 0.2 * up
	f.pelvis.position.y = Stick3D.HIP_Y + 0.05 * up

## 돌아 등주먹(오른) — 등을 보이며 반대쪽(왼)으로 3/4 바퀴 휙 돌고, 오른옆이 상대를 보는 순간 접었던 팔을 옆으로 펴 손등으로 친다. 남은 1/4 바퀴로 가드
static func _backfist(f: Stick3D, a: float) -> void:
	var yaw := 1.5 * PI * seg(a, 0.08, 0.5) + 0.5 * PI * seg(a, 0.6, 0.95)
	var ext := bump(a, 0.36, 0.5, 0.58, 0.75)
	f.pelvis.rotation.y = yaw
	f.shoulders[1.0].rotation.x = -(1.3); f.shoulders[1.0].rotation.z = 1.45 * ext + 0.4 * (1.0 - ext); f.elbows[1.0].rotation.x = -(2.0 * (1.0 - ext))
	_guard(f, -1.0)
	f.torso.rotation.z = 0.25 * ext; f.torso.rotation.x = 0.1
	f.neck.rotation.y = clampf(-wrapf(yaw, -PI, PI), -1.4, 1.4)
	f.hips[1.0].rotation.x = -(0.2); f.hips[-1.0].rotation.x = -(-0.15); f.knees[1.0].rotation.x = 0.35; f.knees[-1.0].rotation.x = 0.3
	f.pelvis.position.y = Stick3D.HIP_Y - 0.05

## 날아차기(공중 Z) — 뛰어오른 채 왼무릎은 가슴에 접어 넣고 오른다리를 앞·아래로 쭉 내지른다. 상체는 뒤로, 두 팔은 뒤·옆으로 벌려 균형
static func _fly(f: Stick3D, a: float) -> void:
	var tuck := bump(a, 0.0, 0.2, 0.75, 1.0); var ex := bump(a, 0.2, 0.32, 0.7, 0.9)
	f.hips[-1.0].rotation.x = -(2.0 * tuck); f.knees[-1.0].rotation.x = 2.4 * tuck
	f.hips[1.0].rotation.x = -(1.6 * tuck - 0.35 * ex); f.knees[1.0].rotation.x = 2.2 * tuck * (1.0 - ex)
	f.pelvis.rotation.x = -0.35 * ex; f.torso.rotation.x = -0.2 * ex + 0.2 * tuck * (1.0 - ex)
	for s in [-1.0, 1.0]:
		f.shoulders[s].rotation.x = -(-0.6 * ex + 0.8 * (1.0 - ex) * tuck); f.shoulders[s].rotation.z = s * 0.9 * ex; f.elbows[s].rotation.x = -(0.4)
	f.neck.rotation.x = 0.3 * ex

## 내려찍기(공중 X) — 두 손을 깍지 껴 머리 위로 높이 들며 몸을 활처럼 젖혔다가, 내려오며 온몸을 접어 아래로 내리친다. 무릎은 접어 착지 준비
static func _hammer(f: Stick3D, a: float) -> void:
	var lift := bump(a, 0.0, 0.36, 0.42, 0.56); var slam := bump(a, 0.42, 0.56, 0.7, 1.0)
	for s in [-1.0, 1.0]:
		f.shoulders[s].rotation.x = -(2.9 * lift + 1.0 * slam); f.shoulders[s].rotation.z = -s * 0.25; f.elbows[s].rotation.x = -(0.5 * lift + 0.2 * slam)
		f.hips[s].rotation.x = -(0.4 * lift + 1.2 * slam); f.knees[s].rotation.x = 0.6 * lift + 1.5 * slam
	f.torso.rotation.x = -0.35 * lift + 0.7 * slam; f.chest.rotation.x = -0.15 * lift + 0.25 * slam
	f.neck.rotation.x = -0.3 * lift + 0.3 * slam

## 막기(주민) — 두 팔뚝을 얼굴 앞에 세워 겹치고 몸을 웅크린다
static func _block(f: Stick3D, a: float) -> void:
	var k := bump(a, 0.0, 0.15, 0.8, 1.0)
	for s in [-1.0, 1.0]:
		f.shoulders[s].rotation.x = -(1.45 * k); f.shoulders[s].rotation.z = -s * 0.4 * k; f.elbows[s].rotation.x = -(2.35 * k)
		f.hips[s].rotation.x = -(0.3 * k); f.knees[s].rotation.x = 0.5 * k
	f.torso.rotation.x = 0.25 * k; f.neck.rotation.x = 0.3 * k
	f.pelvis.position.y = Stick3D.HIP_Y - 0.07 * k

## 피하기(주민) — 상체를 뒤로 젖히며 뒤로 반 발짝(속도는 주민이 준다), 팔은 가드
static func _dodge(f: Stick3D, a: float) -> void:
	var k := bump(a, 0.0, 0.25, 0.6, 1.0)
	f.torso.rotation.x = -0.4 * k; f.neck.rotation.x = 0.2 * k
	_guard(f, 1.0, k); _guard(f, -1.0, k)
	f.hips[1.0].rotation.x = -(-0.35 * k); f.knees[1.0].rotation.x = 0.3 * k; f.hips[-1.0].rotation.x = -(0.3 * k); f.knees[-1.0].rotation.x = 0.4 * k
	f.pelvis.position.y = Stick3D.HIP_Y - 0.04 * k
