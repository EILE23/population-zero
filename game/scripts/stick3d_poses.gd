class_name StickPoses
extends RefCounted
## 졸라맨의 `pose_request` 자세들 — stick3d.gd 에서 떼어 냈다(코드 정리, run 70: 그 파일이 497줄이라 자세를 하나도 더 못 넣었다).
## `lean()` 은 상체 기울기(와 골반 위치)를, `limbs()` 는 한쪽 팔다리의 관절 각을 정한다. 둘 다 stick3d.gd 의 _process 가 프레임마다 부른다.
## 각도 부호 약속은 stick3d.gd 머리말과 같다: 매달린 뼈는 -( ) 로 뒤집어 '앞 = 양수'로 읽는다.
## 타이밍: `f.pose_t` 는 지금 자세가 시작된 뒤 흐른 시간 — 새 자세는 이걸로 예비(windup)·유지(hold)·회수(recovery)를 갖는다. 정지화 한 장은 자세가 아니다.

const WATER_T := 2.4   # 물주기 한 번: 0.35 들어올림 → 붓기 → 마지막 0.35 바로 서기. 그 뒤엔 pose_request 가 풀릴 때까지 물뿌리개를 든 채 선다
const SHADE_T := 6.0   # 손차양 한 바퀴(run 73, 전망 자리): 0.35 손이 이마로(예비) → 둘러보기(유지: 고개·몸통이 천천히 좌우) → 마지막 0.4 손을 내림(회수). 자세가 풀릴 때까지 되풀이
const STORM_T := 3.0   # 처마 밑 비 구경 한 바퀴(run 74): 0.3 고개가 하늘로(예비) → 잠깐 본다(유지, 꼭대기에서 어깨 으쓱) → 0.4 내린다(회수) → 남은 1.3초는 앞의 비를 본다. 비가 그칠 때까지 되풀이
const UMBR_T := 0.3    # 우산 펴기(run 76, 우산꽂이): 0.3초에 걸쳐 팔이 머리 위로 오르고 캐노피가 0 → 1 로 펴진다(예비) → 든 채 걷고 서고 앉는다(유지, 걸을수록 진행 방향으로 기운다) → 두 번째 C 에 같은 0.3초로 접힌다(회수)
const LWAVE_T := 1.4   # 왼손 인사(run 77, 우산 가족의 두 번째 자세): 0.2 왼팔이 머리 위로(예비) → 흔든다(유지, wave 와 같은 9Hz·0.25rad) → 마지막 0.3 내린다(회수). 오른팔은 손대지 않는다 — 우산을 든 채(umbr 이 뒤에서 덮어쓴다)
const ROW_T := 1.2     # 노 한 번(run 78, 거룻배): 0.5 젓기(다리를 펴며 팔을 가슴으로 당기고 몸이 뒤로) → 0.7 회수(팔을 내밀고 몸이 앞으로, 노는 물 밖). 박자(push_t)는 배가 가는 만큼만 간다 — 서면 노를 든 채 쉰다
const HAMMER_T := 1.5  # 망치질 한 바퀴(run 80, 구두장이 작업대): 0.3 망치를 든다(예비) → 0.3 씩 세 번 두드린다(유지, 팔꿈치에서 내리치고 손목이 꺾인다) → 0.3 내린다(회수). 두 바퀴 = 밑창 하나
const GRIND_T := 2.4   # 칼갈이 한 바퀴(run 81, 숫돌): 0.4 숙여 들어가 날을 돌에 댄다(예비) → 1.6 간다(유지, 오른발이 발판을 1.6Hz 로 밟고 불꽃이 튄다) → 0.4 바로 선다(회수). 두 바퀴 = 가위 하나
const WAIT_T := 1.5    # 기다리기 한 눈길(run 81, 숫돌 손님 자리): 팔짱은 0.3초에 감기고(예비), 그 뒤 1.5초마다 고개가 옆으로 0.25 돌아가 0.5 보고 0.25 돌아온다(유지 속의 회수). 자세가 풀릴 때까지 되풀이
const SEW_T := 3.0     # 바느질 한 바퀴(run 82, 재봉사 작업대): 0.3 바늘로 손을 뻗는다(예비) → 2.4 실을 뽑았다 되돌린다(유지, 오른손이 1.2Hz 로 옆으로 당긴다) → 0.3 실을 이로 끊는다(회수: 손이 입으로, 고개가 까딱). 한 바퀴 = 찢어진 것 하나
const TEETER_T := 0.25 # 디딤돌 균형(run 84): 0.25초에 두 팔이 옆으로 벌어진다(예비) → 건너는 동안 두 팔이 시소처럼 번갈아 오르내린다(유지, 2.4rad/s) → 돌을 벗어나면 팔이 걷기 흔들림으로 내려온다(회수, stick3d 블렌딩)
const SHARE_T := 2.0   # 나눠 먹기(run 85, 벤치): 0.3 두 손이 가슴 앞에서 먹을 걸 쥔다(예비) → 0.6 비틀어 쪼갠다 → 0.6 옆 사람 쪽 팔을 뻗어 반을 건넨다(유지) → 0.5 무릎으로 돌아온다(회수)
const SHARE_HAND := 1.2 # 반쪽이 옆 사람 손으로 넘어가는 순간 — 팔이 끝까지 뻗은 때(town_meals split_food)
const PASS_T := 1.0    # 옆으로 건네기(run 86, 벤치 줄): 0.2 오른손이 든 것을 가슴 높이로 옆 사람 쪽에 내민다(예비) → 0.6 내민 채 넘겨준다(유지) → 0.2 무릎으로(회수)
const PASS_HAND := 0.5 # 넘겨주는 순간 — 내민 손이 머문 한가운데(town_meals pass_on_bench, resident_life _pass_along)
const CHOP_T := 1.6    # 장작 패기 한 번(오두막 그루터기): 0.45 도끼를 머리 뒤로(예비) → 0.15 내리찍기 → 0.4 박힌 채 숙여 있다(유지) → 0.6 도끼를 빼며 선다(회수). 한 번에 통나무 하나가 둘로
const CHOP_HIT := 0.6  # 날이 통나무에 닿는 순간 — 여기서 쪼개진다(town_woods _woodcut)
const KNEAD_T := 2.6   # 반죽 한 덩이(run 72): 0.3 손을 판에 올림(예비) → 누르기(유지) → 마지막 0.3 옆으로 밀어 놓기(회수). 한 바퀴에 빵 하나 — 여러 덩이면 자세가 되풀이된다

## 상체 기울기 — base 는 걷기·웅크림·공중에서 계산된 값. 자세가 정하면 덮어쓴다(원래 stick3d.gd 에 있던 순서 그대로)
static func lean(f: Stick3D, moving: bool, delta: float, base: float) -> float:
	var lean := base
	var p := f.pose_request
	if p == "lean" and not moving:
		lean = -0.2
	if p == "shake" and not moving:
		lean = sin(f._t * 9.0) * 0.12
	if p == "read" and not moving:
		lean = 0.12
	if p == "drink" and not moving:
		lean = -0.12
	if p == "eat" and not moving:
		lean = 0.08
	if p == "swing":
		lean = -0.15 - f.swing_k * 0.25
	if p == "push":
		f.push_t += delta * 1.6
		lean = 0.25 if f.push_t < 0.3 else 0.08
	if p == "water" and not moving:
		# 물주기(2D water): 앞으로 숙여 붓는다 — 붓는 동안 살짝 흔들린다(물뿌리개 무게)
		var k := water_k(f.pose_t)
		lean = 0.3 * k + sin(f._t * 3.0) * 0.03 * k
	if p == "knead" and not moving:
		# 반죽: 낮은 판 위로 숙이고, 누를 때마다 어깨가 조금 더 내려간다
		var k := knead_k(f.pose_t)
		lean = 0.22 * k + absf(sin(f._t * 7.0)) * 0.05 * k
	if p == "hammer" and not moving:
		lean = 0.2 * hammer_k(f.pose_t) + 0.04 * hammer_tap(f.pose_t)   # 구두골 위로 숙이고, 내리칠 때마다 어깨가 조금 따라간다
	if p == "chop" and not moving:
		var c := fmod(f.pose_t, CHOP_T)
		lean = -0.1 * smoothstep(0.0, 1.0, minf(c / 0.45, 1.0)) * (1.0 - chop_bend(f.pose_t)) + 0.38 * chop_bend(f.pose_t)   # 들 때 젖히고, 찍으며 허리가 접힌다
	if p == "grind" and not moving:
		lean = (0.28 + 0.03 * grind_pump(f)) * grind_k(f.pose_t)   # 돌 위로 숙이고, 발판을 밟을 때마다 어깨가 조금 따라 내려간다
	if p == "wait" and not moving:
		lean = -0.04 * smoothstep(0.0, 1.0, minf(f.pose_t / 0.3, 1.0)) + sin(f._t * 1.1) * 0.015   # 뒤꿈치에 무게, 숨 쉬듯 조금 흔들린다
	if p == "sew":
		lean = 0.14 * sew_k(f.pose_t) + 0.05 * sew_bite(f.pose_t)   # 앉은 채 손 위로 숙이고, 실을 끊을 때 한 번 더 숙인다
	if p == "share":
		lean = 0.06 * share_k(f.pose_t) + 0.05 * share_break(f.pose_t)   # 쪼갤 때 손 위로 조금 숙인다
	if p == "pass":
		lean = 0.05 * pass_k(f.pose_t)   # 옆으로 내밀 때 몸이 조금 따라간다
	if p == "teeter":
		lean = base * 0.5 + 0.12 * smoothstep(0.0, 1.0, minf(f.pose_t / TEETER_T, 1.0))   # 달리기 기울기는 반, 대신 발밑을 보느라 조금 웅크린다
	if p == "shade" and not moving:
		lean = -0.08 * shade_k(f.pose_t)   # 손차양: 멀리 보느라 살짝 뒤로 젖힌다 — 고개·몸통 돌림은 limbs 에서(몸통 y 는 그 뒤에 정해진다)
	if p == "storm" and not moving:
		lean = -0.1 - 0.05 * storm_k(f.pose_t)   # 뒤꿈치에 무게 — 하늘을 볼 때 조금 더 젖혀진다
	if p == "row":
		# 노 젓기(run 78): 박자는 배 속도(swing_k)만큼만 간다 — 캐치에서 앞으로 숙였다가 피니시에서 뒤로 눕는다. 엉덩이는 낮은 판자(0.17) 위 0.3
		f.push_t += delta * absf(f.swing_k)
		lean = 0.35 - 0.65 * row_k(f)
		f.pelvis.position.y = 0.3
	if p == "cast" or p == "reel":
		lean = FishPoses.lean(f)   # 낚시(run 91) — 걸터앉는 골반 높이도 거기서(stick3d_fish.gd)
	if p == "bicker" or p == "makeup": lean = PairPoses.lean(f)   # 짝 다툼(run 95)·화해(run 96), stick3d_pair.gd
	if p == "shelve": lean = ShelfPoses.lean(f)   # 책 상자에 꽂기·꺼내기(run 98, stick3d_shelf.gd)
	if p in ["sort", "pin", "scan"]: lean = PostPoses.lean(f)   # 우편함에 꽂기·꺼내기(run 99), 게시판 꽂기·읽기(run 100) — stick3d_post.gd
	if p == "crossleg" or p == "story": lean = SunroomPoses.lean(f)   # 방석 책상다리·안락의자 읽기(run 103) — 내려앉는 골반 높이도 거기서(stick3d_sunroom.gd)
	if p == "rock" or p == "rub": lean = NapPoses.lean(f)   # 흔들의자·깨어남(run 108) — 골반의 기울기와 높이도 거기서(stick3d_nap.gd)
	if p == "strum": lean = BuskPoses.lean(f)   # 상자 기타 치기(run 111) — 기타를 등과 가슴 사이로 옮기는 것도 거기서(stick3d_busk.gd)
	if p == "sigh": lean = LedgerPoses.lean(f)   # 장부 앞의 한숨(run 112, stick3d_ledger.gd)
	if p == "glide": lean = GlidePoses.lean(f)   # 상승기류에 뜬 몸(run 118, Climb 팩 updraft — stick3d_glide.gd)
	if p == "plonk": lean = FurnishPoses.lean(f)   # 납작 상자를 바닥에(run 117, 내 집 꾸미기 — stick3d_furnish.gd)
	if p == "don" or p == "doff": lean = WearPoses.lean(f)   # 모자 쓰기·벗기(run 114, 잡화점 — stick3d_wear.gd)
	if p == "stoop" or p == "palm" or p == "put": lean = CoinPoses.lean(f)   # put: 주머니에서 접시로(run 116, 전당포)   # 동전 집어 주머니에(run 107)·상판에서 쓸어 쥐기(run 110) — 굽는 무릎의 골반 높이도 거기서(stick3d_coin.gd)
	if p == "skip": lean = KidPoses.lean(f, lean)   # 아이 걸음(run 102) — 걸음마다 뜨는 골반 높이도 거기서(stick3d_kid.gd)
	if p == "moor": lean = DockPoses.lean(f)   # 배 매기(run 94) — 쪼그린 골반 높이도 거기서(stick3d_dock.gd)
	if p == "stoke": lean = HearthPoses.lean(f)   # 난로에 장작 넣기(run 92) — 쪼그린 골반 높이도 거기서(stick3d_hearth.gd)
	if p == "rest":
		f.pelvis.rotation.x = -1.5; lean = 0.25 + sin(f._t * 1.6) * 0.02
		f.pelvis.position.y = 0.16
	return lean

## 노 젓기 진행 0..1 — 0 = 캐치(팔 뻗음·무릎 접힘·몸 앞), 1 = 피니시(손 가슴·다리 펴짐·몸 뒤). 한 번(ROW_T)에 0.5 젓고 0.7 돌아온다.
## 박자(push_t)는 배 속도만큼만 가니 서면 멈춘다 — 그때는 0.35(노를 든 채 쉼)로 섞인다. 노(town_boat _boats)도 같은 값으로 물을 젓는다
static func row_k(f: Stick3D) -> float:
	var c := fmod(f.push_t, ROW_T)
	var cyc := smoothstep(0.0, 1.0, c / 0.5) if c < 0.5 else 1.0 - smoothstep(0.0, 1.0, (c - 0.5) / 0.7)
	return lerpf(0.35, cyc, clampf(absf(f.swing_k) * 4.0, 0.0, 1.0))

## 물주기 진행 0..1 — 0.35초에 걸쳐 숙였다가(예비), 붓고(유지), 끝 0.35초에 바로 선다(회수). WATER_T 뒤엔 0(든 채 서기)
static func water_k(t: float) -> float:
	if t >= WATER_T: return 0.0
	if t < 0.35: return smoothstep(0.0, 1.0, t / 0.35)
	if t > WATER_T - 0.35: return 1.0 - smoothstep(0.0, 1.0, (t - (WATER_T - 0.35)) / 0.35)
	return 1.0

## 반죽 진행 0..1 — 한 덩이(KNEAD_T)마다 되풀이: 0.3초 손을 판 위로(예비), 누르기(유지), 끝 0.3초 옆으로 밀어 놓기(회수). 그 다음 덩이는 처음부터
static func knead_k(t: float) -> float:
	var c := fmod(t, KNEAD_T)
	if c < 0.3: return smoothstep(0.0, 1.0, c / 0.3)
	if c > KNEAD_T - 0.3: return 1.0 - smoothstep(0.0, 1.0, (c - (KNEAD_T - 0.3)) / 0.3)
	return 1.0

## 장작 패기 팔 각(어깨, 아래로 늘어뜨린 데서 앞·위로 든 라디안) — 허리 높이 0.9 → 머리 위 뒤 2.9(예비) → 통나무를 가리키는 1.0(찍기, 선형이라 빠르다) → 박힌 채 → 0.9(회수)
static func chop_arm(t: float) -> float:
	var c := fmod(t, CHOP_T)
	if c < 0.45: return lerpf(0.9, 2.9, smoothstep(0.0, 1.0, c / 0.45))
	if c < CHOP_HIT: return lerpf(2.9, 1.0, (c - 0.45) / (CHOP_HIT - 0.45))
	if c < 1.0: return 1.0
	return lerpf(1.0, 0.9, smoothstep(0.0, 1.0, (c - 1.0) / 0.6))

## 장작 패기 허리 숙임 0..1 — 들 땐 0(뒤로 조금 젖힌다), 찍는 순간 1 로 접혀 박힌 동안 머물고, 회수에 걸쳐 편다
static func chop_bend(t: float) -> float:
	var c := fmod(t, CHOP_T)
	if c < 0.45: return 0.0
	if c < CHOP_HIT: return smoothstep(0.0, 1.0, (c - 0.45) / (CHOP_HIT - 0.45))
	if c < 1.0: return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (c - 1.0) / 0.6)

## 망치질 진행 0..1 — 한 바퀴 HAMMER_T 마다: 0.3초 든다(예비), 두드림(유지), 끝 0.3초 내린다(회수)
static func hammer_k(t: float) -> float:
	var c := fmod(t, HAMMER_T)
	if c < 0.3: return smoothstep(0.0, 1.0, c / 0.3)
	if c > HAMMER_T - 0.3: return 1.0 - smoothstep(0.0, 1.0, (c - (HAMMER_T - 0.3)) / 0.3)
	return 1.0

## 칼갈이 진행 0..1 — 한 바퀴 GRIND_T 마다: 0.4초 숙여 들어간다(예비), 간다(유지), 끝 0.4초 바로 선다(회수)
static func grind_k(t: float) -> float:
	var c := fmod(t, GRIND_T)
	if c < 0.4: return smoothstep(0.0, 1.0, c / 0.4)
	if c > GRIND_T - 0.4: return 1.0 - smoothstep(0.0, 1.0, (c - (GRIND_T - 0.4)) / 0.4)
	return 1.0

## 발판 밟기 0..1 — 1.6Hz, 0 = 발판이 올라와 있다, 1 = 끝까지 밟았다. 숫돌과 발판(town_trades _wheel)도 같은 값으로 돈다
static func grind_pump(f: Stick3D) -> float:
	return (sin(f._t * 1.6 * TAU) + 1.0) / 2.0

## 바느질 진행 0..1 — 한 바퀴 SEW_T 마다: 0.3초 바늘로 손을 뻗고(예비), 꿰맨다(유지), 끝 0.3초는 sew_bite(회수)가 맡는다 — 손은 들린 채(1)
static func sew_k(t: float) -> float:
	var c := fmod(t, SEW_T)
	return smoothstep(0.0, 1.0, c / 0.3) if c < 0.3 else 1.0

## 실 뽑기 0..1 — 유지 구간에서 1.2Hz: 0 = 바늘이 천에 꽂힘, 1 = 오른손이 옆·위로 실을 끝까지 뽑음. 예비·회수 동안은 0
static func sew_pull(t: float) -> float:
	var c := fmod(t, SEW_T)
	if c < 0.3 or c > SEW_T - 0.3: return 0.0
	return (1.0 - cos((c - 0.3) * 1.2 * TAU)) / 2.0

## 실 끊기 0..1 — 끝 0.3초에 오른손이 입으로 올라갔다(이로 끊고) 내려온다
static func sew_bite(t: float) -> float:
	var c := fmod(t, SEW_T)
	return sin((c - (SEW_T - 0.3)) / 0.3 * PI) if c > SEW_T - 0.3 else 0.0

## 나눠 먹기 진행 0..1 — 0.3초 두 손이 가슴 앞으로(예비), 쪼개고 건네는 동안 1, 끝 0.5초 무릎으로(회수). SHARE_T 뒤엔 0
static func share_k(t: float) -> float:
	if t >= SHARE_T: return 0.0
	if t < 0.3: return smoothstep(0.0, 1.0, t / 0.3)
	if t > SHARE_T - 0.5: return 1.0 - smoothstep(0.0, 1.0, (t - (SHARE_T - 0.5)) / 0.5)
	return 1.0

## 건네기 진행 0..1 — 0.2초 내밀고(예비), 0.6초 머물고(유지), 0.2초 거둔다(회수). PASS_T 뒤엔 0
static func pass_k(t: float) -> float:
	if t >= PASS_T: return 0.0
	if t < 0.2: return smoothstep(0.0, 1.0, t / 0.2)
	if t > PASS_T - 0.2: return 1.0 - smoothstep(0.0, 1.0, (t - (PASS_T - 0.2)) / 0.2)
	return 1.0

## 쪼개기 0..1 — 0.3..0.9 동안 두 번 비튼다(두 손이 벌어졌다 모인다), 마지막에 벌어진 채 끝난다
static func share_break(t: float) -> float:
	if t < 0.3 or t > 0.9: return 0.0
	return absf(sin((t - 0.3) / 0.6 * PI * 1.5))

## 건네기 0..1 — 0.9..1.5 동안 옆 사람 쪽 팔이 뻗고(SHARE_HAND 1.2 에 끝까지) 머문다, 회수는 share_k 가 맡는다
static func share_offer(t: float) -> float:
	if t < 0.9: return 0.0
	return smoothstep(0.0, 1.0, minf((t - 0.9) / 0.3, 1.0))

## 기다리기 눈길 0..1 — WAIT_T 마다: 0.25초 고개가 옆으로(예비), 0.5초 본다(유지), 0.25초 돌아온다(회수), 나머지 0.5초는 앞을 본다
static func wait_glance(t: float) -> float:
	var c := fmod(t, WAIT_T)
	if c < 0.25: return smoothstep(0.0, 1.0, c / 0.25)
	if c < 0.75: return 1.0
	if c < 1.0: return 1.0 - smoothstep(0.0, 1.0, (c - 0.75) / 0.25)
	return 0.0

## 두드림 높이 0..1 — 유지 구간(0.3..1.2)의 0.3초마다 한 번: 0 = 구두에 닿음, 1 = 팔꿈치 꼭대기. 예비·회수 동안은 0.6(든 채)
static func hammer_tap(t: float) -> float:
	var c := fmod(t, HAMMER_T)
	if c < 0.3 or c > HAMMER_T - 0.3: return 0.6
	return sin(fmod(c - 0.3, 0.3) / 0.3 * PI)

## 왼손 인사 진행 0..1 — 0.2초 오르고(예비), 흔들고(유지), 끝 0.3초 내린다(회수). LWAVE_T 뒤엔 0(팔을 내린 채) — 자세가 풀릴 때 팔이 뚝 떨어지지 않는다
static func lwave_k(t: float) -> float:
	if t >= LWAVE_T: return 0.0
	if t < 0.2: return smoothstep(0.0, 1.0, t / 0.2)
	if t > LWAVE_T - 0.3: return 1.0 - smoothstep(0.0, 1.0, (t - (LWAVE_T - 0.3)) / 0.3)
	return 1.0

## 손차양 진행 0..1 — 한 바퀴 SHADE_T 마다: 0.35초 손을 이마로(예비), 둘러보기(유지), 끝 0.4초 손을 내린다(회수). 그 다음 바퀴는 처음부터
static func shade_k(t: float) -> float:
	var c := fmod(t, SHADE_T)
	if c < 0.35: return smoothstep(0.0, 1.0, c / 0.35)
	if c > SHADE_T - 0.4: return 1.0 - smoothstep(0.0, 1.0, (c - (SHADE_T - 0.4)) / 0.4)
	return 1.0

## 비 구경 고개 들기 0..1 — 한 바퀴 STORM_T 마다: 0.3초 고개가 하늘로(예비), 1초 본다(유지), 0.4초 내린다(회수), 나머지는 0(앞을 본다)
static func storm_k(t: float) -> float:
	var c := fmod(t, STORM_T)
	if c < 0.3: return smoothstep(0.0, 1.0, c / 0.3)
	if c < 1.3: return 1.0
	if c < 1.7: return 1.0 - smoothstep(0.0, 1.0, (c - 1.3) / 0.4)
	return 0.0

## 비 구경 옷깃 으쓱 0..1 — 고개가 꼭대기에 있는 동안(0.3..1.3) 한 번 부풀었다 가라앉는다
static func storm_shrug(t: float) -> float:
	var c := fmod(t, STORM_T)
	return smoothstep(0.0, 1.0, clampf(1.0 - absf(c - 0.8) / 0.5, 0.0, 1.0))

## 물뿌리개 물방울 — 든 것에 "drops" 입자가 달려 있으면(town_base make_item "can") 붓는 동안만 켠다
static func drops(f: Stick3D, on: bool) -> void:
	if f.carrying == null or not f.carrying.has_meta("drops"): return
	(f.carrying.get_meta("drops") as CPUParticles3D).emitting = on

## 이 자세가 오른팔을 직접 쓰는가 — 그러면 stick3d.gd 의 '들고 있으면 오른팔 앞으로' 덮어쓰기를 건너뛴다(먹기·마시기 손이 입까지 못 올라가던 것)
static func owns_right_arm(p: String) -> bool:
	return p in ["eat", "drink", "water", "shade", "storm", "umbr", "grind", "wait", "sew", "share", "pass", "chop", "cast", "reel", "stoke", "moor", "bicker", "sort", "pin", "stoop", "palm", "put", "strum", "sigh", "don", "doff", "plonk", "glide"]   # glide: 두 팔이 옆으로 벌어진다(run 118)   # plonk: 두 손이 상자를 바닥에(run 117)   # put: 오른손이 주머니에서 접시로(run 116)   # don·doff: 두 손/오른손이 모자를 머리로·머리에서(run 114)   # sigh: 두 손이 탁자 모서리를 짚는다(run 112)   # palm: 오른손이 상판에서 주머니로(run 110)   # stoop: 오른손이 바닥에서 주머니로(run 107). pin: 오른손이 쪽지를 판에 누른다(run 100)   # sort: 오른손이 편지를 칸에 넣는다(run 99)   # bicker: 오른손이 따진다(run 95)   # moor: 오른손이 밧줄을 감는다(run 94)   # stoke: 오른손이 장작을 밀어 넣는다(run 92)   # cast·reel: 오른손이 낚싯대를(run 91)   # chop: 두 손이 도끼 자루를   # grind: 두 손이 날을 잡는다, wait: 팔짱   # storm: 든 것은 팔짱 안에 품는다(빵을 든 채 비를 피한 주민)

## 우산(run 76, "Weather people feel" 2조각): 오른팔만 쓴다 — 다리와 왼팔은 걷기·서기·앉기 그대로라 limbs() 의 match 에 없고, stick3d.gd 가 팔다리를 다 정한 뒤 이걸 부른다(세 변형이 팔 하나를 나눠 쓴다).
## k = f.umbr_k(0..1, UMBR_T 에 걸쳐 오간다): 팔이 늘어진 곳에서 머리 위로 오르고 캐노피(우산 meta "umb")가 펴진다; 접힐 땐 같은 길을 거꾸로. 걸을수록 진행 방향으로 조금 더 기운다 — 정지화가 아니다
static func umbr(f: Stick3D) -> void:
	if f.carrying == null or not f.carrying.has_meta("umb"): return
	var k := smoothstep(0.0, 1.0, f.umbr_k)
	var sh: Node3D = f.shoulders[1.0]; var el: Node3D = f.elbows[1.0]
	var mv := clampf(f.speed / 2.6, 0.0, 1.4) if f.move_dir.length_squared() > 0.0001 else 0.0
	sh.rotation.x = lerp_angle(sh.rotation.x, -(2.7 + 0.2 * mv), k); sh.rotation.z = lerpf(sh.rotation.z, -0.2, k)
	el.rotation.x = lerp_angle(el.rotation.x, -(0.2), k)
	var s := lerpf(0.15, 1.0, k)
	(f.carrying.get_meta("umb") as Node3D).scale = Vector3(s, 1.0, s)

## 한쪽(s = -1 왼, +1 오른) 팔다리 — pose_request 에 맞는 자세가 있으면 대입하고 true, 없으면 false(호출자가 기지개·앉기·걷기로 이어간다)
static func limbs(f: Stick3D, s: float, moving: bool, sw: float, run_k: float) -> bool:
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var t: float = f._t
	match f.pose_request:
		"lean":
			# 가로등에 기대서기(2D lean): 어깨가 뒤로 빠지고 한쪽 발은 발끝만 걸쳐 꼬고 팔짱
			hip.rotation.x = -(0.15 if s > 0.0 else -0.35); knee.rotation.x = -(-0.1 if s > 0.0 else -0.6)
			sh.rotation.x = -(0.45); sh.rotation.z = -s * 0.05; el.rotation.x = -(1.9)
		"shake":
			# 나무 흔들기(2D shake): 두 팔을 위로 뻗어 가지를 잡고 몸통째 좌우로
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.1)
			sh.rotation.x = -(2.9 + sin(t * 9.0) * 0.15); sh.rotation.z = -s * 0.25; el.rotation.x = -(0.2)
		"eat":
			# 서서 먹기(2D chew): 오른손이 입으로 오르내리고 고개가 살짝 숙여진다
			var m := (sin(t * 4.0) + 1.0) / 2.0
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			if s > 0.0: sh.rotation.x = -(0.55 + m * 0.5); sh.rotation.z = -0.25; el.rotation.x = -(1.9 + m * 0.5)
			else: sh.rotation.x = -(0.05); sh.rotation.z = 0.1; el.rotation.x = -(0.35)
		"drink":
			# 마시기: 컵을 든 손이 입까지 올라가 머물고 고개가 뒤로 젖혀진다
			var m := clampf(sin(t * 1.6) * 0.5 + 0.5, 0.0, 1.0)
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			if s > 0.0: sh.rotation.x = -(0.7 + m * 0.4); sh.rotation.z = -0.3; el.rotation.x = -(2.2 + m * 0.3)
			else: sh.rotation.x = -(0.05); sh.rotation.z = 0.1; el.rotation.x = -(0.35)
		"read":
			# 서서 읽기(2D read): 두 손이 가슴 앞, 고개 숙임
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			sh.rotation.x = -(0.5); sh.rotation.z = -s * 0.15; el.rotation.x = -(1.7)
		"push":
			# 그네 밀기: 두 팔을 앞으로 내밀어 좌석을 밀고(0→0.3) 거둔다(0.3→1). 쉴 땐 팔을 앞에 반쯤 든 채 기다린다
			var pt: float = f.push_t
			var k := (smoothstep(0.0, 1.0, pt / 0.3) if pt < 0.3 else 1.0 - smoothstep(0.0, 1.0, (pt - 0.3) / 0.7)) if pt < 1.0 else 0.0
			hip.rotation.x = -(0.15 * k * (1.0 if s > 0.0 else -1.0)); knee.rotation.x = -(-0.1)
			sh.rotation.x = -(0.9 + 0.8 * k); sh.rotation.z = -s * 0.1; el.rotation.x = -(1.1 - 0.9 * k)
		"swing":
			# 그네(2D swing): 두 손은 위로 줄을 잡고, 앞으로 갈 때 다리를 뻗고 돌아올 때 접는다. 엉덩이는 좌석에
			hip.rotation.x = -(1.4 - f.swing_k * 0.5); knee.rotation.x = -(-1.2 + f.swing_k * 1.0)
			sh.rotation.x = -(2.6); sh.rotation.z = -s * 0.32; el.rotation.x = -(0.3)
		"rest":
			# 침대에 눕기(2D sit): 등을 대고 다리는 뻗고, 한 팔은 머리 뒤, 한 팔은 배 위
			hip.rotation.x = -(0.1 + 0.05 * s); knee.rotation.x = -(-0.15 if s > 0.0 else -0.5)
			if s > 0.0: sh.rotation.x = -(2.6); sh.rotation.z = -0.5; el.rotation.x = -(1.6)
			else: sh.rotation.x = -(0.9); sh.rotation.z = 0.1; el.rotation.x = -(1.5)
		"carry":
			# 가구 들기: 두 팔을 앞으로 내밀어 허리 높이에서 받쳐 든다, 걸음은 다리만
			if moving:
				var a := s * sw * 0.55 * run_k
				hip.rotation.x = -(a); knee.rotation.x = -(-(1.0 if a < 0.0 else 0.15) * run_k)
			else:
				hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			sh.rotation.x = -(0.95); sh.rotation.z = -s * 0.12; el.rotation.x = -(1.35)
		"wave":
			# 손 흔들기(2D wave): 오른팔을 머리 위로 들어 좌우로
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			if s > 0.0: sh.rotation.x = -(2.7); sh.rotation.z = -0.35 + sin(t * 9.0) * 0.25; el.rotation.x = -(0.5)
			else: sh.rotation.x = -(0.05); sh.rotation.z = 0.1; el.rotation.x = -(0.35)
		"lwave":
			# 왼손 인사(운영자 보드의 우산 가족, 두 번째 자세 — run 77): 오른손이 우산을 든 채라 왼팔을 머리 위로 들어 좌우로 흔든다(wave 와 같은 9Hz·0.25rad).
			# k 가 예비·유지·회수를 만든다(0.2초 오르고, 흔들고, 0.3초 내린다); 오른팔은 늘어뜨린 값만 두고 건드리지 않는다 — 그 위에 StickPoses.umbr 이 캐노피를 든다(편 우산이면)
			var k := lwave_k(f.pose_t)
			hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			if s < 0.0: sh.rotation.x = -(0.05 + 2.65 * k); sh.rotation.z = 0.1 + (0.25 - sin(t * 9.0) * 0.25) * k; el.rotation.x = -(0.35 + 0.15 * k)
			else: sh.rotation.x = -(0.05); sh.rotation.z = -0.1; el.rotation.x = -(0.35)
		"water":
			# 물주기(2D water, 텃밭 가족의 첫 자세 — run 70): 오른손의 물뿌리개를 앞·아래로 내밀어 기울이고(손목 hand_r 이 주둥이를 숙인다),
			# 왼팔은 반쯤 앞에서 균형, 오른발이 반 걸음 앞. k 가 예비·유지·회수를 만든다 — 붓는 동안만 물방울
			var k := water_k(f.pose_t)
			hip.rotation.x = -(0.12 * k) if s > 0.0 else -(-0.05 * k); knee.rotation.x = -(-0.08)
			if s > 0.0:
				sh.rotation.x = -(0.35 + 0.55 * k); sh.rotation.z = -0.15; el.rotation.x = -(0.25 + 0.1 * k)
				f.hand_r.rotation.x = 0.85 * k
				drops(f, k > 0.95)
			else:
				sh.rotation.x = -(0.15 + 0.25 * k); sh.rotation.z = 0.12; el.rotation.x = -(0.6)
		"knead":
			# 반죽(운영자 보드의 부엌·빵집 가족 — run 72, 빵집 화덕): 낮은 판 앞에 숙여 두 손이 번갈아 반죽을 누른다 — 누르는 손은 앞·아래로 뻗고 반대 손은 접혀 들린다.
			# k 가 예비·유지·회수를 만든다(판에 손을 올리고, 누르고, 옆으로 밀어 놓는다); 발은 어깨 너비, 무릎은 살짝. 한 바퀴 KNEAD_T 에 빵 하나(town_places _bakery)
			var k := knead_k(f.pose_t)
			var pr := sin(t * 7.0) * s
			hip.rotation.x = -(0.04 * s * k); knee.rotation.x = -(-0.05 - 0.08 * k)
			sh.rotation.x = -(0.05 + (0.45 + 0.15 * pr) * k); sh.rotation.z = -s * (0.04 + 0.06 * k); el.rotation.x = -(0.35 + (0.05 - 0.18 * pr) * k)
		"hammer":
			# 망치질(운영자 보드의 연장 가족 첫 자세 — run 80, 구두장이 작업대): 왼손은 구두골 위의 구두를 누르고, 오른손은 팔꿈치에서 내리친다 — 꼭대기에서 손목이 뒤로 젖혀졌다가
			# 닿는 순간 앞으로 꺾인다(hand_r). k 가 예비·유지·회수를 만든다(망치를 들고, 세 번 두드리고, 내린다); 무게는 앞발, 무릎은 살짝. 사람도 주민도 같은 자세
			var k := hammer_k(f.pose_t)
			var tap := hammer_tap(f.pose_t)
			hip.rotation.x = -(0.06 * s * k); knee.rotation.x = -(-0.05 - 0.1 * k)
			if s > 0.0:
				sh.rotation.x = -(0.05 + (0.75 + 0.45 * tap) * k); sh.rotation.z = -0.18 * k; el.rotation.x = -(0.35 + (0.5 + 1.2 * tap) * k)
				f.hand_r.rotation.x = (0.5 - 1.1 * tap) * k
			else:
				sh.rotation.x = -(0.05 + 0.6 * k); sh.rotation.z = 0.12 * k; el.rotation.x = -(0.35 + 0.7 * k)
		"chop":
			# 장작 패기(운영자 보드의 연장 가족 셋째 자세 — 숲 오두막 그루터기): 발은 어깨보다 넓게, 두 손이 한 자루를 쥐어 두 팔이 같이 움직인다 — 머리 뒤로 들었다가(팔꿈치 접힘)
			# 팔을 펴며 내리찍고, 날이 박힌 동안 허리가 접혀 머물고, 빼면서 선다. 무릎은 찍을 때 더 굽는다. 사람도 나무꾼 주민도 같은 자세, 도끼는 오른손을 따라간다(town_woods _woodcut)
			var a := chop_arm(f.pose_t); var b := chop_bend(f.pose_t)
			var c := fmod(f.pose_t, CHOP_T)
			var up := smoothstep(0.0, 1.0, minf(c / 0.45, 1.0)) * (1.0 - b)   # 머리 뒤로 든 정도 — 팔꿈치가 접힌다
			hip.rotation.x = -(0.08 * s); knee.rotation.x = -(-0.1 - 0.25 * b)
			sh.rotation.x = -(a); sh.rotation.z = s * (0.14 - 0.04 * up); el.rotation.x = -(0.25 + 0.75 * up)   # 두 손이 한 자루로 모인다(+s = 안쪽)
			if s > 0.0: f.neck.rotation.x += 0.2 * b   # 박힌 날을 본다
		"grind":
			# 칼갈이(운영자 보드의 연장 가족 두 번째 자세 — run 81, 시장 동쪽 끝의 숫돌): 오른발이 앞의 발판을 1.6Hz 로 밟고(무릎이 접혔다 펴진다, 무게는 왼다리) 두 손은 허리 높이 앞에서
			# 날을 돌에 댄 채 — 밟을 때마다 어깨가 조금 따라 내려간다. k 가 예비·유지·회수를 만든다(숙여 들어가고, 갈고, 바로 선다); 사람도 주민도 같은 자세, 돌·발판·불꽃은 같은 pump·k 로 돈다(town_trades _wheel)
			var k := grind_k(f.pose_t)
			var pump := grind_pump(f) * k
			if s > 0.0: hip.rotation.x = -(0.15 * k + 0.35 * pump); knee.rotation.x = -(-(0.2 * k + 0.5 * pump))
			else: hip.rotation.x = -(-0.05 * k); knee.rotation.x = -(-0.05 - 0.06 * k)
			sh.rotation.x = -(0.05 + (0.7 + 0.06 * pump) * k); sh.rotation.z = -s * (0.1 + 0.08 * k); el.rotation.x = -(0.35 + 0.55 * k)
		"wait":
			# 기다리기(운영자 보드의 '서서 기다리기' 일상 가족 — run 81, 숫돌 손님 자리; 만석 벤치 앞에도 쓸 자세): 왼다리에 무게, 오른 무릎은 살짝 접혀 발끝만, 팔짱.
			# k 가 예비를 만든다(0.3초에 팔짱이 감긴다); 유지 동안 1.5초마다 고개(와 몸통 조금)가 옆 — 숫돌·자리 쪽 — 으로 갔다 돌아온다(wait_glance). 정지화가 아니다
			var k := smoothstep(0.0, 1.0, minf(f.pose_t / 0.3, 1.0))
			var gl := wait_glance(f.pose_t)
			hip.rotation.x = -(0.05 * k if s > 0.0 else -0.04 * k); knee.rotation.x = -(-(0.35 * k) if s > 0.0 else -0.02)
			sh.rotation.x = -(0.05 + 0.45 * k); sh.rotation.z = -s * (0.1 + 0.02 * sin(t * 1.1) * k); el.rotation.x = -(0.35 + 1.7 * k)
			if s > 0.0: f.neck.rotation.y = 0.55 * gl; f.torso.rotation.y = 0.1 * gl
		"sew":
			# 바느질(운영자 보드의 손일 가족 — run 82, 재봉사 작업대): 앉아서(허벅지 수평, 정강이 아래) 왼손은 가슴 앞에서 천을 잡고, 오른손은 바늘을 꽂았다가 옆·위로 실을 뽑는다(1.2Hz).
			# k 가 예비(바늘로 손을 뻗는다), pull 이 유지, bite 가 회수(손이 입으로 — 실을 이로 끊고 고개가 까딱)를 만든다. 재봉사도 걸상의 사람도 같은 자세
			var k := sew_k(f.pose_t); var pull := sew_pull(f.pose_t); var bite := sew_bite(f.pose_t)
			hip.rotation.x = -(1.5); knee.rotation.x = -(-1.45 + 0.05 * s)
			if s > 0.0:
				sh.rotation.x = -(0.05 + (0.7 + 0.3 * pull) * k + 0.5 * bite); sh.rotation.z = -(0.1 + 0.4 * pull) * k; el.rotation.x = -(0.35 + (1.4 - 0.8 * pull) * k + 0.5 * bite)
				f.neck.rotation.x += 0.25 * bite
			else:
				sh.rotation.x = -(0.05 + 0.75 * k); sh.rotation.z = 0.12 * k; el.rotation.x = -(0.35 + 1.35 * k)
		"share":
			# 나눠 먹기(운영자 보드의 '건네기·함께' 가족 첫 자세 — run 85, "Sharing food" 1조각): 벤치에 앉은 채(서 있으면 다리는 서기) 두 손이 가슴 앞에서 먹을 걸 쥐고(예비),
			# 두 번 비틀어 쪼갠다(손이 옆으로 벌어졌다 모인다), 그다음 옆 사람 쪽 팔(meta share_side, ±1 = 그쪽 어깨)이 옆·앞으로 뻗어 반을 건네고 고개도 그쪽을 본다(유지), 무릎으로 돌아온다(회수).
			# 주는 주민도 C 로 주는 사람도 같은 자세 — 받는 쪽은 이어서 앉은 채 먹는다(eat)
			var k := share_k(f.pose_t); var brk := share_break(f.pose_t); var off := share_offer(f.pose_t)
			var side: float = f.get_meta("share_side", 1.0)
			if f.seated: hip.rotation.x = -(1.5); knee.rotation.x = -(-1.45)
			else: hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			var reach := off if s == side else 0.0
			sh.rotation.x = -(0.55 + 0.25 * k - 0.2 * reach); sh.rotation.z = -s * (0.1 + 0.18 * brk * k + 0.75 * reach * k)
			el.rotation.x = -(0.9 + 0.8 * k * (1.0 - reach) - 0.5 * reach * k)
			if s > 0.0: f.neck.rotation.y = 0.45 * side * off * k
		"pass":
			# 옆으로 건네기(운영자 보드의 '건네기·함께' 가족 둘째 자세 — run 86, "Sharing food" 2조각): 앉은 채 오른손에 든 컵·빵을 가슴 높이로 옆 사람 쪽(meta share_side)에 내민다 —
			# 오른쪽이면 팔이 바깥으로, 왼쪽이면 가슴 앞을 가로질러. 받는 이의 왼손 쪽에 닿도록 팔꿈치를 편다. 고개가 그쪽을 보고, 왼손은 무릎에. 주민도 길게 C 누른 사람도 같은 자세
			var k := pass_k(f.pose_t)
			var side: float = f.get_meta("share_side", 1.0)
			if f.seated: hip.rotation.x = -(1.5); knee.rotation.x = -(-1.45)
			else: hip.rotation.x = 0.0; knee.rotation.x = -(-0.05)
			if s > 0.0:
				sh.rotation.x = -(0.35 + 0.95 * k); sh.rotation.z = -(0.1 + 0.6 * k) if side > 0.0 else -(0.1 - 0.75 * k)
				el.rotation.x = -(0.9 - 0.6 * k)
				f.neck.rotation.y = 0.4 * side * k
			else:
				sh.rotation.x = -(0.55); sh.rotation.z = 0.1; el.rotation.x = -(0.9)
		"teeter":
			# 디딤돌 균형(운영자 보드의 '외줄·평균대' 가족 첫 자세 — run 84, 강의 디딤돌): 두 팔을 옆으로 벌리고 걸음은 좁고 무릎은 조금 더 접힌다, 고개는 발밑.
			# k 가 예비(팔이 벌어진다), rock 이 유지(한 팔이 오르면 다른 팔이 내려가는 시소 — 정지화가 아니다). 사람도 주민도 같은 돌 위에서 같은 자세
			var k := smoothstep(0.0, 1.0, minf(f.pose_t / TEETER_T, 1.0))
			var rock := sin(t * 2.4)
			if moving:
				var a := s * sw * 0.35 * run_k   # 보폭을 줄인다 — 돌 한 개에 한 걸음
				hip.rotation.x = -(a); knee.rotation.x = -(-(0.9 if a < 0.0 else 0.25) * run_k)
			else:
				hip.rotation.x = -(0.05); knee.rotation.x = -(-0.2)
			sh.rotation.x = -(0.05 + 0.2 * k); sh.rotation.z = -s * (0.1 + (1.15 + 0.3 * rock * s) * k); el.rotation.x = -(0.35 - 0.2 * k)
			if s > 0.0: f.neck.rotation.x += 0.25 * k
		"shade":
			# 손차양(운영자 보드의 '지도 읽기·둘러보기' 일상 가족 — run 73, 전망 언덕의 전망 자리): 오른손을 이마 위에 얹고 왼손은 허리에, 무게는 왼다리에(오른 무릎 살짝).
			# k 가 예비·유지·회수를 만든다(손이 올라가고, 둘러보고, 내려온다); 둘러보는 동안 고개와 몸통이 천천히 좌우로 돈다 — 정지화가 아니다. 주민도 사람도 같은 자세
			var k := shade_k(f.pose_t)
			var scan := sin(t * 0.9) * k
			hip.rotation.x = -(0.06 * s * k); knee.rotation.x = -(-0.05 - (0.12 * k if s > 0.0 else 0.0))
			if s > 0.0:
				sh.rotation.x = -(0.05 + 1.95 * k); sh.rotation.z = -0.35 * k; el.rotation.x = -(0.35 + 1.4 * k)
				f.torso.rotation.y = scan * 0.2; f.neck.rotation.y = scan * 0.3
			else:
				sh.rotation.x = -(0.05 + 0.25 * k); sh.rotation.z = -s * 0.42 * k; el.rotation.x = -(0.35 + 1.15 * k)
		"row":
			# 노 젓기(운영자 보드의 '당기기' 가족 첫 자세 — run 78, 거룻배; 줄다리기가 다음): 낮은 판자에 앉아 캐치(k 0: 무릎 접고 두 팔을 앞으로 쭉, 몸 앞)에서
			# 피니시(k 1: 다리를 펴고 손을 가슴으로, 몸 뒤)로. 박자는 배가 가는 만큼만(push_t, lean()), 서면 노를 든 채 쉰다(k 0.35). 사람도 주민도 같은 자세, 노는 같은 k 로 물을 젓는다
			var k := row_k(f)
			hip.rotation.x = -(1.2 - 0.2 * k); knee.rotation.x = -(-(0.66 - 0.5 * k))
			sh.rotation.x = -(1.4 - 1.05 * k); sh.rotation.z = -s * 0.12; el.rotation.x = -(0.15 + 1.75 * k)
		"storm":
			# 처마 밑 비 구경(날씨를 몸으로 받는 첫 자세 — run 74, 비 오는 문 앞: 사람도 주민도): 팔짱을 끼고 다리는 곧게, 무게는 뒤꿈치에.
			# k 가 예비·유지·회수를 만든다(고개가 하늘로 올라가고, 잠깐 보고, 내려온다); 꼭대기에서 어깨가 옷깃처럼 한 번 으쓱(shrug). 나머지 시간은 앞의 비를 본다 — 정지화가 아니다
			var k := storm_k(f.pose_t)
			var shrug := storm_shrug(f.pose_t)
			hip.rotation.x = -(-0.06); knee.rotation.x = 0.0
			sh.rotation.x = -(0.5 + 0.1 * shrug); sh.rotation.z = -s * (0.08 + 0.22 * shrug); el.rotation.x = -(2.05)
			if s > 0.0:
				f.neck.rotation.x -= 0.55 * k; f.chest.rotation.x -= 0.06 * k   # 고개만 든다 — 몸통은 조금
		_:
			return FishPoses.limbs(f, s) or HearthPoses.limbs(f, s) or DockPoses.limbs(f, s) or PairPoses.limbs(f, s) or ShelfPoses.limbs(f, s) or PostPoses.limbs(f, s) or KidPoses.limbs(f, s) or SunroomPoses.limbs(f, s) or CoinPoses.limbs(f, s) or NapPoses.limbs(f, s) or BuskPoses.limbs(f, s) or LedgerPoses.limbs(f, s) or WearPoses.limbs(f, s) or FurnishPoses.limbs(f, s) or GlidePoses.limbs(f, s)   # 이야기방(run 103)· 아이 걸음(run 102)· 우편 가족(run 99)· 낚시 가족(run 91)·불 가족(run 92)·나루 가족(run 94)·짝 가족(run 95) — 이 파일이 450줄을 넘어 주제별 파일로
	return true
