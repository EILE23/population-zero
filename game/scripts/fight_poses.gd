class_name FightPoses
extends RefCounted
## 싸움 자세(운영자 2026-09-30: "발차기·주먹질 연계·제트킥 다 빼도 되니까, 때리고 넘어지고 일어나는 게 어색하지 않게").
## 기술은 둘뿐 — 주먹(번갈아 좌우)과 앞차기. 대신 각 동작을 네 박자로 만든다: 예비(뒤로 당김) → 타격(순간 뻗음) → 멈춤 → 회수.
## 맞기(flinch)는 맞은 방향으로 고개·상체가 젖혀졌다 돌아오고, 넘어짐(down)은 뒤로 쓰러져 한 번 튕기며 미끄러지고, 일어나기(getup)는
## 옆으로 돌아누움 → 한 손 짚고 무릎 세움 → 일어섬 세 단계. Stick3D 가 action 을 보고 부른다. 모든 각은 stick3d.gd 부호 약속을 따른다.

const PUNCH_T := 0.34
const KICK_T := 0.5
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

## 앞차기: 무릎을 가슴까지 끌어올리고(예비), 발바닥으로 곧게 밀어 차고, 멈췄다가, 무릎을 다시 접어 내린다. 팔은 벌려 균형, 상체는 뒤로
static func kick(f: Stick3D, a: float) -> void:
	var chamber := smoothstep(0.0, 1.0, a / 0.3) if a < 0.3 else (1.0 if a < 0.72 else 1.0 - smoothstep(0.0, 1.0, (a - 0.72) / 0.28))
	var extend := strike_k(a, 0.3, 0.42, 0.62) if a >= 0.3 else 0.0
	extend = maxf(extend, 0.0)
	f.hips[1.0].rotation.x = -(1.5 * chamber + 0.2 * extend); f.knees[1.0].rotation.x = -(-2.0 * chamber * (1.0 - extend))
	f.hips[-1.0].rotation.x = -(-0.1 * chamber); f.knees[-1.0].rotation.x = -(-0.25 * chamber)
	f.torso.rotation.x = -0.25 * chamber - 0.15 * extend; f.neck.rotation.x = 0.2 * chamber
	f.shoulders[1.0].rotation.x = -(0.3); f.shoulders[1.0].rotation.z = -0.9 * chamber; f.elbows[1.0].rotation.x = -(0.8)
	f.shoulders[-1.0].rotation.x = -(0.7 * chamber); f.shoulders[-1.0].rotation.z = 0.7 * chamber; f.elbows[-1.0].rotation.x = -(1.2)
	f.pelvis.position.y = Stick3D.HIP_Y - 0.04 * chamber

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
