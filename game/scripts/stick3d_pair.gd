class_name PairPoses
extends RefCounted
## 짝 가족 자세("Walking in pairs" — run 95, 1조각): `bicker` 나란히 걷던 둘 중 하나가 맞아 짝이 깨지면, 둘이 마주 서서 손바닥을 위로 두 팔을 내밀고(왜 그래?),
## 오른손으로 두 번 찌르듯 따지며 고개를 젓고, 팔을 떨군다. 다툼은 몇 초의 몸짓일 뿐 — C 나 뺏기를 막지 않는다. stick3d_dock.gd 처럼 주제별 파일
## `makeup`(run 96, 2조각): 토라졌던 둘이 벤치 옆 칸(또는 마주 서서) — 어깨가 올라갔다 떨어지는 한숨, 고개를 한 번 깊이 끄덕, 짝 쪽 손바닥을 반쯤 펴 보이고 내린다.
## 앉아 있으면 다리는 앉은 채, 고개 돌림은 resident_pair 가 look_yaw 로(앉은 몸은 벤치를 본다)

const BICKER_T := 1.7    # 0.2 두 팔이 손바닥을 위로 앞으로 올라온다(예비) → 1.2 두 번 따진다(유지: 오른손이 0.6초마다 앞으로 찌르고 고개를 젓는다) → 0.3 팔을 떨군다(회수)

## 팔이 올라온 정도 0..1
static func raise(t: float) -> float:
	return smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(1.4, BICKER_T, t))

## 찌르기 0..1 — 유지 구간(0.2..1.4)에 두 번, 빠르게 나갔다 천천히 돌아온다
static func jab(t: float) -> float:
	if t < 0.2 or t > 1.4: return 0.0
	var c := fmod(t - 0.2, 0.6) / 0.6
	return smoothstep(0.0, 0.25, c) * (1.0 - smoothstep(0.35, 1.0, c))

const MAKEUP_T := 1.3    # 0.4 한숨(예비: 어깨가 올라갔다 떨어진다) → 0.4 끄덕(유지) → 0.5 손바닥을 반쯤 펴 보이고 내린다(회수)

static func sigh(t: float) -> float:
	return sin(t / 0.4 * PI) if t < 0.4 else 0.0

static func nod(t: float) -> float:
	return sin((t - 0.4) / 0.4 * PI) if t >= 0.4 and t < 0.8 else 0.0

static func palm(t: float) -> float:
	return sin((t - 0.8) / 0.5 * PI) if t >= 0.8 and t < MAKEUP_T else 0.0

static func lean(f: Stick3D) -> float:
	if f.pose_request == "makeup":
		return (-0.05 if f.seated else 0.0) - 0.04 * sigh(f.pose_t) + 0.1 * nod(f.pose_t)   # 숨을 내쉬며 조금 젖혔다가, 끄덕일 때 상체가 따라 숙인다
	return 0.06 * raise(f.pose_t) + 0.1 * jab(f.pose_t)   # 따질 때마다 상체가 조금 들이민다

## 팔다리 — 다리는 어깨너비로 버티고(왼발이 반 발 앞), 왼팔은 손바닥을 위로 내민 채, 오른팔이 찌른다. 고개는 찌를 때마다 좌우로
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request == "makeup": return _makeup(f, s)
	if f.pose_request != "bicker": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t := f.pose_t; var r := raise(t); var j := jab(t)
	hip.rotation.x = -(0.12 if s < 0.0 else -0.06); knee.rotation.x = -(-0.12 if s < 0.0 else -0.05)
	if s > 0.0:
		sh.rotation.x = -(0.75 * r + 0.55 * j); sh.rotation.z = -(0.35 * r - 0.25 * j); el.rotation.x = -(1.25 * r - 0.85 * j)   # 손바닥 위로 → 팔꿈치를 펴며 앞으로 찌른다
		var hold := smoothstep(0.2, 0.3, t) * (1.0 - smoothstep(1.3, 1.4, t))
		f.neck.rotation.y += sin((t - 0.2) * TAU / 0.6) * 0.3 * hold   # 따지는 박자에 고개를 젓는다
		f.torso.rotation.y += 0.12 * j   # 찌르는 쪽 어깨가 따라 나간다
	else:
		sh.rotation.x = -(0.7 * r); sh.rotation.z = 0.4 * r; el.rotation.x = -(1.2 * r)   # 왼손은 손바닥을 위로 내민 채(어쩌라고)
	return true

## 화해 — 다리는 앉은 채(서 있으면 곧게), 팔은 무릎 위(서 있으면 늘어뜨림)에서 한숨에 어깨가 들썩, 끄덕, 그다음 오른손 손바닥이 짝 쪽으로 반쯤 올라왔다 내려간다
static func _makeup(f: Stick3D, s: float) -> bool:
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t := f.pose_t; var sg := sigh(t); var p := palm(t) if s > 0.0 else 0.0
	if f.seated: hip.rotation.x = -(1.5); knee.rotation.x = -(-1.45)
	else: hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
	var bx := 0.55 if f.seated else 0.05; var be := 0.9 if f.seated else 0.35
	sh.rotation.x = -(bx + 0.35 * p); sh.rotation.z = -s * (0.1 + 0.2 * sg + 0.15 * p); el.rotation.x = -(be + 0.7 * p)
	if s > 0.0: f.neck.rotation.x += 0.4 * nod(t) - 0.12 * sg   # 한숨에 고개가 살짝 들렸다가, 한 번 깊이 끄덕
	return true
