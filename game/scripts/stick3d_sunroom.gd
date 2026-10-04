class_name SunroomPoses
extends RefCounted
## 이야기방 자세("Elders and children" 2조각, run 103): `crossleg` 방석에 책상다리 — 0.3 한 손을 바닥에 짚으며 엉덩이를 내리고(예비),
## 허벅지를 벌려 정강이를 앞에서 엇걸고 두 손은 무릎에(유지 — 책장이 넘어갈 때마다 몸이 앞으로 조금 쏠린다), 0.3 같은 손으로 바닥을 밀고 일어선다(회수).
## 회수는 meta "cross_up"(그 몸의 _t 시각)부터 — 주민은 앉을 때 끝날 시각을 적고, 사람은 일어서는 순간 town_sunroom 이 적는다.
## `story` 안락의자에서 소리 내어 읽기: 두 손이 무릎 위에 책을 펴 들고, STORY_T 마다 오른손이 책장 귀퉁이를 집어(0.3 예비) 넘기고(0.5 유지)
## 돌아온다(0.3 회수); 그 사이 고개는 글줄을 따라 끄덕이다가 한 번 들어 아이들을 본다. 박자는 벽시계(ticks)라 듣는 아이들의 쏠림과 맞는다
## 끄덕(run 104): 앉은 몸의 meta "nod_at"(그 몸의 _t) 부터 0.4초 — makeup 의 nod 와 같은 곡선. 상체가 조금 따라 숙는다
## 새 책(run 106): 읽는 이의 meta "newbook_at" 부터 — 0.3 두 손이 책을 얼굴 앞까지 들어 올리고(예비) 0.2 표지를 본다(유지, 고개가 들리고 몸이 뒤로) 0.3 무릎으로 내린다(회수).
## 쏠림(run 106): 방석의 meta "keen_until"(그 몸의 _t) 까지는 책장마다 0.1 rad 더 쏠린다 — 새 책을 더 열심히 듣는 아이들

const DOWN_T := 0.3
const UP_T := 0.3
const STORY_T := 4.0   # 책장 한 장

## 책장 넘기기 위상 0..STORY_T — 모두 같은 시계(읽는 이와 듣는 이가 한 박자)
static func page_t() -> float:
	return fmod(Time.get_ticks_msec() / 1000.0, STORY_T)

## 넘기는 손 0..1..0 (0..1.1초), 듣는 몸의 쏠림 0..1..0(넘기는 순간 뒤 0.6초)
static func turn_k(t: float) -> float:
	return smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.8, 1.1, t))
static func rock_k(t: float) -> float:
	return sin(clampf((t - 0.4) / 0.6, 0.0, 1.0) * PI)

## 앉은 정도 0..1 — 내려앉기(pose_t)와 일어서기(cross_up 부터) 둘 다. 짚는 손 0..1..0 은 두 전환 한가운데서 가장 깊다
static func sit_k(f: Stick3D) -> float:
	var up := clampf((f._t - float(f.get_meta("cross_up", INF))) / UP_T, 0.0, 1.0)
	return smoothstep(0.0, DOWN_T, f.pose_t) * (1.0 - up)
static func prop_k(f: Stick3D) -> float:
	var up := clampf((f._t - float(f.get_meta("cross_up", INF))) / UP_T, 0.0, 1.0)
	return sin(clampf(f.pose_t / DOWN_T, 0.0, 1.0) * PI) + sin(up * PI)

static func nod_k(f: Stick3D) -> float:
	return PairPoses.nod(0.4 + f._t - float(f.get_meta("nod_at", -INF)))   # 없으면(−INF) 0

static func newbook_k(f: Stick3D) -> float:
	var t := f._t - float(f.get_meta("newbook_at", -INF))
	return smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.5, 0.8, t))

static func keen_k(f: Stick3D) -> float:
	return 1.0 if f._t < float(f.get_meta("keen_until", -INF)) else 0.0

static func lean(f: Stick3D) -> float:
	if f.pose_request == "story":
		return 0.06 + 0.04 * turn_k(page_t()) - 0.14 * newbook_k(f)   # 책 위로 조금 숙이고, 넘길 때 조금 더; 새 책은 표지를 보느라 뒤로
	var k := sit_k(f)
	f.pelvis.position.y = lerpf(StickRig.HIP_Y, 0.14, k)
	return 0.25 * prop_k(f) + (0.05 + (0.07 + 0.1 * keen_k(f)) * rock_k(page_t()) + 0.08 * nod_k(f)) * k   # 짚을 때 숙고, 앉아선 책장마다 앞으로 한 번(새 책엔 더), 끄덕일 때도

static func limbs(f: Stick3D, s: float) -> bool:
	if not (f.pose_request in ["crossleg", "story"]): return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	if f.pose_request == "story":
		var t := page_t(); var tk := turn_k(t) * (1.0 - newbook_k(f)); var nk := newbook_k(f)   # 새 책을 들어 보는 동안엔 장을 넘기지 않는다
		hip.rotation.x = -(1.5); knee.rotation.x = -(-1.45)
		if s > 0.0:
			sh.rotation.x = -(0.75 + 0.2 * tk + 0.55 * nk); sh.rotation.z = -(0.15 + 0.45 * sin(clampf((t - 0.3) / 0.5, 0.0, 1.0) * PI) * tk); el.rotation.x = -(1.3 - 0.3 * tk - 0.35 * nk)   # 귀퉁이를 집어 가슴 앞을 가로질러 넘긴다; 새 책은 두 손으로 얼굴 앞까지
			f.neck.rotation.x += 0.18 + sin(f._t * 5.0) * 0.03 - 0.3 * smoothstep(2.0, 2.3, t) * (1.0 - smoothstep(3.0, 3.3, t)) - 0.4 * nk   # 글줄을 따라 끄덕이다가 2–3초에 고개를 들어 본다; 새 책 표지엔 고개가 들린다
		else:
			sh.rotation.x = -(0.75 + 0.55 * nk); sh.rotation.z = -s * 0.15; el.rotation.x = -(1.3 - 0.35 * nk)
		return true
	var k := sit_k(f); var pk := prop_k(f)   # 팔다리 z: +s 가 바깥(run 103 에 리그로 확인 — 어깨 −s 는 안쪽이다)
	# 다리: 허벅지가 앞·바깥으로 벌어지고 무릎이 깊이 접혀 정강이가 앞에서 엇걸린다(왼다리가 조금 앞 — 좌우가 똑같지 않게)
	hip.rotation.x = -(1.25 * k + (0.1 if s < 0.0 else 0.0) * k); hip.rotation.z = s * 0.6 * k
	knee.rotation.x = -(-(0.05 + 2.25 * k))
	if s > 0.0:
		# 짚는 손: 옆 아래로 뻗어 바닥을 짚었다가(전환 한가운데) 무릎으로 온다
		sh.rotation.x = -(0.15 + 0.55 * k * (1.0 - minf(pk, 1.0))); sh.rotation.z = s * (0.1 + 0.55 * minf(pk, 1.0)); el.rotation.x = -(0.2 + 0.5 * k * (1.0 - minf(pk, 1.0)))
		f.neck.rotation.x += 0.4 * nod_k(f) * k   # 한 번 깊이 끄덕(run 104) — 앉아 있을 때만
	else:
		sh.rotation.x = -(0.1 + 0.6 * k); sh.rotation.z = s * 0.15 * k; el.rotation.x = -(0.35 + 0.35 * k)
	return true
