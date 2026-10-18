class_name TrackPoses
extends RefCounted
## 공을 눈으로 쫓는 자세(Climb 팩 green 의 주민 반쪽 — 골퍼, run 173; 운영자 보드의 '골프' 가족, stroke 의 다음): `track` 친 공이 나는 동안 리드 손을 이마에 얹고 고개가 공을 따라가는 몸.
## 시계는 둘이고 골퍼(climb_golfer.gd)가 적는다: meta "track_x"·"track_y"(몸의 발에서 공까지 px — 고개의 요·피치가 그걸 본다, 공의 속도가 고개의 속도), meta "track_end"(공의 끝: cup | lost | rest)와 "track_end_t"(끝난 뒤 시간), meta "track_lead"(±1 — 그쪽 손이 이마로). 메타가 없으면 pose_t 로 혼자 한 번 돈다(점검·시연용: 손 0.3 s, 공이 왼쪽 아래에서 오른쪽 위로 1.2 s, 컵의 끄덕임, 손 내림).
## 손 올림(0..RAISE_T): 리드 손이 이마로(손차양 shade 와 같은 팔 — 어깨 −2.0, 팔꿈치 −1.75), 무게가 그 다리로 → 쫓기: 고개가 공 쪽으로 돌고(atan2(x, VIEW_D), YAW_MAX 까지) 공이 높을수록 들린다(PITCH_MAX 까지), 몸통이 고개의 3/10 만큼 따라 돌고, 이마의 팔은 6 Hz 로 잔떨린다 — 정지화가 아니다
## → 끝: 컵이면 고개를 두 번 끄덕이고(NOD_T, 1.25 Hz 의 |sin|), 잃으면 천천히 한 번 젓고(SHAKE_T, 한 바퀴), 서면 어깨를 한 번 들고(REST_T) → 손 내림(DOWN_T): 팔·고개·몸통이 돌아온다(회수) — 골퍼가 자세를 비운다.
## stroke(공을 보내는 몸)·shade(둘러보는 손차양 — 고개가 제 박자로 좌우를 쓴다)·peer(망원경에 숙인 몸)와 다르다: 이건 밖의 한 점을 그 점의 속도로 쫓는 눈. stick3d_stroke.gd 처럼 주제별 파일

const RAISE_T := 0.3      # 손이 이마에 닿는 시간(s)
const DOWN_T := 0.3       # 끝난 뒤 손이 내려오는 시간(s)
const NOD_T := 0.8        # 컵의 끄덕임(s) — 두 번
const SHAKE_T := 1.2      # 잃은 공의 젓기(s) — 한 바퀴
const REST_T := 0.4       # 선 공의 어깨(s)
const DEMO_FOLLOW := 1.2  # 메타 없이 돌 때 공이 가는 시간(s)
const VIEW_D := 160.0     # 눈에서 공의 길까지의 깊이(px) — 요·피치의 atan 분모
const YAW_MAX := 1.0      # 고개가 도는 한계(rad)
const PITCH_MAX := 0.6    # 고개가 들리는 한계(rad)
const NOD_HZ := 1.25
const SHAKE_HZ := 1.0 / SHAKE_T
const TREMBLE_HZ := 6.0

## 메타 없이 도는가(점검·시연)
static func demo(f: Stick3D) -> bool:
	return not f.has_meta("track_x")

## 그쪽 손이 이마로 ±1
static func lead(f: Stick3D) -> float:
	return 1.0 if float(f.get_meta("track_lead", 1.0)) >= 0.0 else -1.0

## 공의 자리 — 몸의 발에서(px): 메타, 없으면 왼쪽 아래에서 오른쪽 위로 호를 그리는 시연
static func target(f: Stick3D) -> Vector2:
	if not demo(f): return Vector2(float(f.get_meta("track_x", 0.0)), float(f.get_meta("track_y", 0.0)))
	var k := smoothstep(RAISE_T, RAISE_T + DEMO_FOLLOW, f.pose_t)
	return Vector2(lerpf(-120.0, 260.0, k), 150.0 * sin(k * PI))

## 공의 끝 — "" | cup | lost | rest
static func end_kind(f: Stick3D) -> String:
	if not demo(f): return String(f.get_meta("track_end", ""))
	return "cup" if f.pose_t >= RAISE_T + DEMO_FOLLOW else ""

## 끝난 뒤 시간(s) — 끝나지 않았으면 0
static func end_t(f: Stick3D) -> float:
	if not demo(f): return maxf(0.0, float(f.get_meta("track_end_t", 0.0)))
	return maxf(0.0, f.pose_t - (RAISE_T + DEMO_FOLLOW))

## 끝의 길이(s) — 골퍼가 손 내림의 때를 센다
static func end_s(kind: String) -> float:
	match kind:
		"cup": return NOD_T
		"lost": return SHAKE_T
		"rest": return REST_T
	return 0.0

## 시간으로 돌 때 끝났나 — 골퍼가 모는 동안은 골퍼가 비운다
static func done(f: Stick3D) -> bool:
	return demo(f) and end_t(f) >= NOD_T + DOWN_T

## 손이 오른 정도 0..1
static func up(f: Stick3D) -> float:
	return smoothstep(0.0, RAISE_T, f.pose_t)

## 손이 내려온 정도 0..1 — 끝의 길이 뒤 DOWN_T 에 걸쳐
static func down(f: Stick3D) -> float:
	var k := end_kind(f)
	if k == "": return 0.0
	return smoothstep(end_s(k), end_s(k) + DOWN_T, end_t(f))

## 쫓는 몸의 세기 0..1 — 올라간 손이 아직 내려오지 않은 만큼
static func hold(f: Stick3D) -> float:
	return up(f) * (1.0 - down(f))

## 고개의 피치(들림, rad, +) — 공이 높을수록
static func pitch(f: Stick3D) -> float:
	return clampf(atan2(maxf(target(f).y, 0.0), VIEW_D), 0.0, PITCH_MAX) * hold(f)

## 상체 — 공을 올려볼수록 조금 뒤로 젖힌다(손차양의 −0.08 에 피치만큼 더)
static func lean(f: Stick3D) -> float:
	return -(0.08 * hold(f) + 0.12 * pitch(f) / PITCH_MAX)

## 팔다리 — 리드 손은 이마에(잔떨림), 다른 팔은 늘어져 조금 벌어지고, 무게는 리드 다리에; 고개는 공 쪽으로 돌고 들리며 끝에 끄덕이거나(cup) 젓고(lost), 서면 두 어깨가 한 번 든다(rest); 몸통은 고개의 3/10
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "track": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var h := hold(f); var brow := s == lead(f)
	var k := end_kind(f); var u := end_t(f); var e := 1.0 - down(f)
	var q := sin(f._t * TAU * TREMBLE_HZ + s) * 0.03 * h   # 이마의 팔의 잔떨림 — 정지화가 아니다
	var shrug := 0.15 * sin(clampf(u / REST_T, 0.0, 1.0) * PI) * e if k == "rest" else 0.0
	hip.rotation.x = -(0.06 * s * h); hip.rotation.z = 0.0
	knee.rotation.x = 0.05 + (0.12 * h if brow else 0.0)
	if brow: sh.rotation.x = -(0.05 + 1.95 * h) + q; sh.rotation.z = -s * (0.35 * h + shrug); el.rotation.x = -(0.35 + 1.4 * h) + q
	else: sh.rotation.x = -(0.05 + 0.1 * h); sh.rotation.z = -s * (0.1 * h + shrug); el.rotation.x = -(0.35 + 0.1 * h)
	if s > 0.0:
		var yaw := clampf(atan2(target(f).x, VIEW_D), -YAW_MAX, YAW_MAX) * h
		var nod := 0.22 * absf(sin(u * TAU * NOD_HZ)) * e if k == "cup" and u < NOD_T else 0.0
		var shake := 0.3 * sin(u * TAU * SHAKE_HZ) * e if k == "lost" and u < SHAKE_T else 0.0
		f.neck.rotation.y += yaw + shake   # 공 쪽으로(+x 가 +) — 잃으면 젓는다
		f.neck.rotation.x += -pitch(f) + nod   # 공이 높으면 든다(−) — 컵이면 끄덕인다(+)
		f.torso.rotation.y = 0.3 * yaw
		f.chest.rotation.x += -0.1 * pitch(f)
	return true
