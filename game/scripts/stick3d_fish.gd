class_name FishPoses
extends RefCounted
## 낚시 자세(운영자 보드의 낚시 가족 — run 91, 호숫가 부두 끝): `cast` 던지고 앉아 기다리기, `reel` 감아올리기. stick3d_poses.gd 가 450줄을 넘어 주제별로 뗐다(GROW.md 코드 정리).
## StickPoses.lean/limbs 가 이 두 자세를 여기로 넘긴다. 낚싯대·찌·줄은 town_sites `_fish` 가 오른손을 따라 그린다 — 같은 rod_pitch 로.

const CAST_T := 1.1      # 던지기: 0.4 낚싯대를 어깨 너머 뒤로(예비) → 0.2 앞으로 휙(던짐) → 0.5 부두 끝에 걸터앉는다. 그 뒤엔 앉아 찌를 본다(유지, 낚싯대 끝이 까딱인다)
const CAST_FLICK := 0.6  # 찌가 손을 떠나는 순간 — 날아가 0.5초 뒤 물에 닿는다(town_sites)
const REEL_T := 0.8      # 감기: 앉은 채 오른손이 대를 세우고 왼손이 릴을 3바퀴 돌린다(0.15 대를 든다 → 감기 → 끝). 끝나면 자세가 풀려 일어선다(stick3d 블렌딩이 회수)
const SEAT_Y := 0.1      # 걸터앉은 골반 높이 — 발은 판자 끝 너머로 늘어진다

## 걸터앉은 정도 0..1 — 던진 뒤 0.5초에 걸쳐 앉는다. 감는 동안은 앉은 채
static func sit_k(f: Stick3D) -> float:
	if f.pose_request == "reel": return 1.0
	return smoothstep(0.0, 1.0, clampf((f.pose_t - CAST_FLICK) / 0.5, 0.0, 1.0))

## 낚싯대가 수평에서 들린 각(라디안) — 뒤로 넘기면 PI/2 를 넘어 등 뒤를 가리킨다. 휙 던지면 0.35 로 내려오고 앉아 기다리는 동안 끝이 까딱인다. 감을 땐 세운다
static func rod_pitch(f: Stick3D) -> float:
	var t := f.pose_t
	if f.pose_request == "reel": return lerpf(0.35, 0.95, smoothstep(0.0, 1.0, minf(t / 0.15, 1.0))) + 0.04 * sin(f._t * 19.0)
	if t < 0.4: return lerpf(0.5, 2.1, smoothstep(0.0, 1.0, t / 0.4))
	if t < CAST_FLICK: return lerpf(2.1, 0.3, (t - 0.4) / (CAST_FLICK - 0.4))
	return 0.35 + 0.035 * sin(f._t * 1.7)

## 상체 기울기 — 뒤로 넘길 때 젖히고, 던질 때 앞으로, 앉으면 찌 쪽으로 조금. 감을 땐 당기느라 뒤로(바퀴마다 한 번씩)
static func lean(f: Stick3D) -> float:
	var t := f.pose_t; var k := sit_k(f)
	f.pelvis.position.y = lerpf(StickRig.HIP_Y, SEAT_Y, k)
	if f.pose_request == "reel": return -0.12 - 0.04 * absf(sin(t * 3.0 * PI))
	if t < 0.4: return -0.15 * smoothstep(0.0, 1.0, t / 0.4)
	if t < CAST_FLICK: return lerpf(-0.15, 0.22, (t - 0.4) / (CAST_FLICK - 0.4))
	return lerpf(0.22, 0.08, k)

## 팔다리 — 서서 던지고(다리 어깨 너비), 앉으면 허벅지는 판자 위 수평·정강이는 끝 너머로 늘어져 번갈아 흔들린다. 오른손이 대, 왼손은 대 아래(기다림)나 릴(감기)
static func limbs(f: Stick3D, s: float) -> bool:
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t := f.pose_t; var k := sit_k(f)
	match f.pose_request:
		"cast":
			hip.rotation.x = -lerpf(0.1 * s, 1.5, k); knee.rotation.x = -lerpf(-0.1, -1.45 + 0.12 * sin(f._t * 1.5 + s), k)   # 걸터앉은 발이 번갈아 까딱인다
			var a := rod_pitch(f)
			if s > 0.0:
				# 대를 쥔 팔: 대가 뒤로 넘어가면 손은 어깨 위(2.6), 던지면 앞(1.1)으로 — 대 각을 따라간다
				sh.rotation.x = -(clampf(1.1 + (a - 0.35) * 0.9, 0.6, 2.7)); sh.rotation.z = -0.12; el.rotation.x = -(0.45 if t < CAST_FLICK else 0.4)
			else:
				# 왼손: 던지는 동안은 균형(옆으로), 앉으면 대 아래를 받친다(안쪽으로 모인다)
				sh.rotation.x = -lerpf(0.3, 0.85, k); sh.rotation.z = s * lerpf(-0.35, 0.2, k); el.rotation.x = -lerpf(0.4, 1.0, k)
			if s > 0.0: f.neck.rotation.x += 0.18 * k   # 찌를 본다
		"reel":
			hip.rotation.x = -(1.5); knee.rotation.x = -(-1.45)
			var up := smoothstep(0.0, 1.0, minf(t / 0.15, 1.0))
			if s > 0.0:
				sh.rotation.x = -(1.1 + 0.45 * up); sh.rotation.z = -0.12; el.rotation.x = -(0.4 + 0.15 * up)
			else:
				var w := t * 3.0 * TAU   # 릴 한 바퀴 = 팔꿈치가 작은 원을 그린다
				sh.rotation.x = -(0.95 + 0.15 * sin(w) * up); sh.rotation.z = s * 0.25; el.rotation.x = -(1.2 + 0.25 * cos(w) * up)
			if s > 0.0: f.neck.rotation.x += 0.1
		_:
			return false
	return true
