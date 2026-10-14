class_name ScalePoses
extends RefCounted
## 태피스트리 가족 자세(Climb 콘텐츠 팩 tapestry, run 153 — data/climb/tapestry.json, scripts/games/climb_tapestry.gd; 운영자 보드의 '밧줄·천 오르기' 가족 — 늘어진 천을 손 바꿔 쥐고 무릎으로 끌어올리며 발로 천을 밀어 오르는 몸): `scale` 태피스트리를 오르는 몸 —
## 예비(0..0.2): 두 손이 머리 위 앞의 천으로 올라가 쥐고 무릎이 가슴 쪽으로 올라오며 골반이 천에 붙는다
## → 오르기(meta "scale_v" 1, 팩의 climb 이 적는다, 없으면 1): 1.2Hz 의 손 바꾸기 — 한 손이 위로 뻗는 동안 다른 손은 가슴께로 당기고(어깨가 반 바퀴 엇갈린다), 한 손 바꿈마다 한 번 당긴다(2.4Hz): 당길 땐 팔꿈치가 접히고 무릎이 가슴으로 올라오며 골반이 조금 뜨고 가슴이 천에 붙고, 밀 땐 다리가 펴져 발이 천을 밀어 몸이 천에서 떨어진다; 다리도 손과 엇갈려 번갈아 올라온다; 고개는 천 위를 본다
## → 꼭대기 매달림(scale_v 0): 두 손이 레일을 쥐고 손발이 멎어 무릎만 조금 접힌 채 고리에 실려 간다, 고개는 건너편 발판을 본다
## → 건너가기(meta "scale_k" 0..1): 팔이 내려오고 한 다리(오른)가 높이 넘어가며 몸통이 앞으로 — 발판에 내려 로더가 자세를 비우면 stick3d 의 블렌딩이 마저 편다(회수).
## 흔들림(meta "scale_sw" −1..1, 천단의 흔들림): 골반째 그만큼 옆으로 기운다 — 메타가 없으면 제 박자로 조금 흔들린다(주민·시연용). 시계는 _t; meta "scale_t" 가 있으면 그 값(점검용 — 한 순간에 멈춰 세운다).
## haul(한 줄을 위아래로 쥐고 당겨져 오른다)·cling(장대를 안고 무릎으로 죈다)·shimmy(줄에 매달려 옆으로 손을 옮긴다)·climb(홀드에 붙은 몸)과 다르다: 이건 넓은 천을 두 손으로 번갈아 쥐고 발로 밀어 제 힘으로 오르는 몸. stick3d_cling.gd 처럼 주제별 파일

const GRAB_T := 0.2
const BEAT_HZ := 1.2      # 손 바꾸기 한 바퀴(두 손이 한 번씩) — 당김은 그 두 배

## 쥔 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, GRAB_T, f.pose_t)

## 시계 — 점검이 적어 준 값, 없으면 _t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("scale_t", f._t))

## 오르는 중 0..1 — 팩이 적어 준 값, 없으면 1
static func v(f: Stick3D) -> float:
	return clampf(float(f.get_meta("scale_v", 1.0)), 0.0, 1.0)

## 건너가는 몫 0..1 — 팩이 적어 준 값, 없으면 0
static func settle(f: Stick3D) -> float:
	return clampf(float(f.get_meta("scale_k", 0.0)), 0.0, 1.0)

## 천단의 흔들림 −1..1 — 팩이 적어 준 값, 없으면 제 박자
static func sway(f: Stick3D) -> float:
	if f.has_meta("scale_sw"): return clampf(float(f.get_meta("scale_sw")), -1.0, 1.0)
	return 0.3 * sin(at(f) * 2.2)

## 당김 0..1 — 손 바꿈마다 한 번(2.4Hz)
static func pull(f: Stick3D) -> float:
	return 0.5 + 0.5 * sin(2.0 * at(f) * TAU * BEAT_HZ)

## 어느 손이 위로 뻗는가 −1..1(+ 오른손)
static func alt(f: Stick3D) -> float:
	return sin(at(f) * TAU * BEAT_HZ)

## 골반은 당길 때 조금 뜨고 천의 흔들림에 옆으로 기운다; 몸통은 천에 붙어 앞으로, 당기면 더, 건너갈 땐 깊이
static func lean(f: Stick3D) -> float:
	var kk := k(f); var vv := v(f); var p := pull(f); var st := settle(f)
	f.pelvis.position.y = StickRig.HIP_Y + 0.025 * p * vv * kk
	f.pelvis.rotation.z = 0.12 * sway(f) * kk * (1.0 - st)
	return (0.22 + 0.1 * p * vv + 0.2 * st) * kk

## 팔다리 — 두 손은 머리 위 앞의 천을(오를 땐 번갈아 위로 뻗고 당길 땐 팔꿈치가 접힌다), 무릎은 당길 때 가슴으로 올라와 밀 때 펴지며 손과 엇갈려 번갈아; 꼭대기에선 멎고; 건너갈 땐 팔이 내려오고 오른 다리가 높이 넘어간다; 고개는 오를 땐 천 위를·꼭대기에선 건너편을
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "scale": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var vv := v(f); var p := pull(f); var a := alt(f); var st := settle(f)
	var reach := s * a * 0.3 * vv   # 한 손이 위로 — 반 바퀴 엇갈려
	var shx := -(0.1 + (2.45 + reach) * kk)
	var elx := -((0.35 + 0.55 * p * vv) * kk + 0.1)
	var hipx := -((0.55 + 0.6 * p * vv + 0.15 * (1.0 - vv) + s * 0.12 * a * vv) * kk)   # 앞 = 음수: 무릎이 가슴으로
	var kneex := (0.9 + 0.7 * p * vv + 0.2 * (1.0 - vv)) * kk
	sh.rotation.x = lerpf(shx, -1.3 * kk, st); sh.rotation.z = -s * (0.12 + 0.03 * kk)
	el.rotation.x = lerpf(elx, -0.6 * kk, st)
	hip.rotation.x = lerpf(hipx, -((1.2 if s > 0.0 else 0.35) * kk), st)   # 건너갈 땐 오른 다리가 넘어간다
	knee.rotation.x = lerpf(kneex, (1.0 if s > 0.0 else 0.3) * kk, st)
	if s > 0.0:
		f.chest.rotation.x += 0.06 * p * vv * kk * (1.0 - st)   # 당길 때 가슴이 천에 붙는다(x 만 — stick3d 는 chest 의 z 를 매 틱 되돌리지 않는다)
		f.neck.rotation.x -= (0.35 * vv + 0.1 * (1.0 - vv)) * kk * (1.0 - st)   # 천 위를 보다 꼭대기에선 건너편을
	return true
