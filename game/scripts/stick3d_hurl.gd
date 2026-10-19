class_name HurlPoses
extends RefCounted
## 투창 가족 자세(Climb 콘텐츠 팩 javelin, run 178 — data/climb/javelin.json, scripts/games/climb_javelin.gd; 운영자 보드의 '투창' 가족의 첫 자세): `hurl` 받침대의 창을 뽑아 어깨 뒤로 당겼다 머리 위로 휘둘러 고리에 던지는 몸 — 몸은 던지는 쪽(옆)을 보고 창은 x 로 난다. 던지는 팔은 오른팔(s > 0, hand_r 에 창), 앞다리는 왼다리.
## 시계는 셋이고 팩이 적는다: meta "hurl_d"(당김에 든 뒤 시간 — 0.45 에 당김이 끝나고 모으기로), meta "hurl_c"(0..1, 모은 만큼), meta "hurl_t"(놓은 뒤 시간 — 던짐·따라감·섬). 메타가 없으면 pose_t 로 혼자 한 번 돈다(점검·주민 시연용: 당김 0.45 s, 숨 0.15 s, 모으기 0.6 s, 던짐 0.75 s).
## 당김(0..0.45): 던지는 팔이 어깨 뒤로 곧게 올라가고(어깨 +1.9·팔꿈치 −0.35) 다른 팔이 앞으로 뻗어 고리를 가리키며(−1.5), 앞다리가 나가고(엉덩이 −0.5·무릎 0.35) 뒷다리가 굽어 받치고(+0.35·0.5), 몸통이 던지는 쪽 반대로 감기고 뒤로 조금, 고개는 고리를 본다(−0.25)
## → 모으기(모은 만큼): 골반이 더 내려앉고(0.05 → 0.12 m) 상체가 더 뒤로, 던지는 팔이 더 뒤로 뻗으며 9 Hz 로 떤다(긴장), 가슴이 열리고, 가리키는 팔이 1.2 Hz 로 흔들린다(유지)
## → 던짐(놓은 뒤 0..0.2): 엉덩이가 앞으로 가고 상체가 뒤에서 앞으로 넘어가며 던지는 팔이 머리 위로 휘둘러 앞으로(−1.7), 다른 팔은 허리로 내려와 막고(+0.2·팔꿈치 −1.3), 앞다리가 버티고(−0.35·0.15), 고개가 창을 따라 든다(−0.5)
## → 따라감(0.2..0.4): 뒷다리가 앞으로 나오고(엉덩이 −0.7·무릎 0.9) 골반이 내려앉고 던진 팔이 가슴 앞으로 떨어지며(−0.6) 눈이 창을 쫓는다 → 섬(0.55..0.75): 팔다리가 내려온다(회수) — 팩이 swing_s 에 메타를 지우고 로더가 자세를 비운다. 무릎은 늘 0.8 Hz 로 숨쉰다 — 정지화가 아니다.
## stroke(공을 채로 날린다)·arch(가로대를 등으로 넘는다)·shovel(삽으로 퍼낸다)과 다르다: 이건 손에 든 것을 제 팔로 멀리 보내는 첫 자세 — 당긴 만큼이 거리가 된다. stick3d_stroke.gd 처럼 주제별 파일

const DRAW_T := 0.45      # 당김(s) = climb_javelin draw_s
const DEMO_WAIT := 0.15   # 메타 없이 돌 때 당김 뒤 모으기 전 숨(s)
const DEMO_CHARGE := 0.6  # 메타 없이 돌 때 모으는 시간(s)
const RELEASE_T := 0.2    # 놓은 뒤 창이 손을 떠나는 때(s) = release_s
const FOLLOW_T := 0.4     # 따라감이 다 오는 때(s)
const RELAX_T := 0.55     # 풀리기 시작(s)
const SWING_T := 0.75     # 한 번(s) = swing_s
const TREMBLE_HZ := 9.0
const SWAY_HZ := 1.2
const BREATHE_HZ := 0.8
const DIP_A := 0.05       # 당김의 골반 내려앉음(m)
const DIP_B := 0.07       # 모으기에 더 내려앉는 높이(m)
const DIP_C := 0.06       # 따라감의 골반 내려앉음(m)

## 당김에 든 뒤 시간(s) — 팩의 메타, 없으면 pose_t
static func drawn(f: Stick3D) -> float:
	if f.has_meta("hurl_d"): return maxf(0.0, float(f.get_meta("hurl_d")))
	if f.has_meta("hurl_t"): return DRAW_T + DEMO_WAIT + DEMO_CHARGE
	return f.pose_t

## 모은 만큼 0..1 — 팩의 메타, 없으면 시간
static func charge(f: Stick3D) -> float:
	if f.has_meta("hurl_c"): return clampf(float(f.get_meta("hurl_c")), 0.0, 1.0)
	if f.has_meta("hurl_t"): return 1.0
	if f.has_meta("hurl_d"): return 0.0
	return smoothstep(DRAW_T + DEMO_WAIT, DRAW_T + DEMO_WAIT + DEMO_CHARGE, f.pose_t)

## 놓은 뒤 시간(s) — 아직 놓지 않았으면 −1
static func since(f: Stick3D) -> float:
	if f.has_meta("hurl_t"): return maxf(0.0, float(f.get_meta("hurl_t")))
	if f.has_meta("hurl_d") or f.has_meta("hurl_c"): return -1.0
	var u := f.pose_t - (DRAW_T + DEMO_WAIT + DEMO_CHARGE)
	return u if u >= 0.0 else -1.0

## 시간으로 돌 때 끝났나 — 팩이 모는 동안은 팩이 busy 로 비운다
static func done(f: Stick3D) -> bool:
	return not f.has_meta("hurl_d") and not f.has_meta("hurl_c") and not f.has_meta("hurl_t") and since(f) >= SWING_T

## [draw, c, thru, fol, up] — 당김(0.45 까지 든다), 모은 만큼, 던짐(놓은 뒤 0 → 0.2), 따라감(0.2 → 0.4), 섬(0.55..0.75 에 0 → 1)
static func phases(f: Stick3D) -> Array:
	var u := since(f)
	var draw := smoothstep(0.0, DRAW_T, drawn(f))
	var c := charge(f)
	var thru := 0.0 if u < 0.0 else smoothstep(0.0, RELEASE_T, u)
	var fol := 0.0 if u < 0.0 else smoothstep(RELEASE_T, FOLLOW_T, u)
	var up := 0.0 if u < 0.0 else smoothstep(RELAX_T, SWING_T, u)
	return [draw, c, thru, fol, up]

## 골반은 당김에 조금, 모으기에 더 내려앉고 던짐에 올라왔다 따라감에 다시 내려앉는다; 상체는 당김·모으기에 뒤로, 던짐에 앞으로 넘어가고 따라감에 조금 돌아온다
static func lean(f: Stick3D) -> float:
	var ph := phases(f); var draw := float(ph[0]); var c := float(ph[1]); var thru := float(ph[2]); var fol := float(ph[3]); var up := float(ph[4])
	var stay := 1.0 - up; var back := (1.0 - thru) * stay
	f.pelvis.position.y = StickRig.HIP_Y - (DIP_A * draw + DIP_B * c) * back - DIP_C * fol * stay
	return (-0.2 * draw - 0.25 * c) * back + (0.45 * thru - 0.15 * fol) * stay

## 팔다리 — 던지는 팔(s > 0): 당김에 어깨 뒤로 곧게(+1.9·−0.35), 모으기에 더 뒤로(+15%)·떨림, 던짐에 머리 위로 앞으로(−1.7·−0.4), 따라감에 가슴 앞으로(−0.6); 가리키는 팔(s < 0): 당김에 앞으로(−1.5·−0.1)·흔들림, 던짐에 허리로(+0.2·−1.3);
## 앞다리(s < 0): 당김에 나가고(−0.5·0.35) 던짐에 버틴다(−0.35·0.15); 뒷다리(s > 0): 당김에 굽어 받치고(+0.35·0.5) 따라감에 앞으로 나온다(−0.7·0.9); 무릎은 늘 숨쉰다; 몸통은 당김에 던지는 쪽 반대로 감기고 던짐에 풀린다; 가슴은 모으기에 열린다; 고개는 고리를 보다(−0.25) 던짐에 창을 따라 든다(−0.5)
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "hurl": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(f); var draw := float(ph[0]); var c := float(ph[1]); var thru := float(ph[2]); var fol := float(ph[3]); var up := float(ph[4])
	var stay := 1.0 - up; var back := (1.0 - thru) * stay
	var arm := s > 0.0                                                        # 던지는 팔·뒷다리 쪽
	var breathe := sin(f._t * TAU * BREATHE_HZ) * 0.03                       # 무릎의 숨 — 정지화가 아니다
	var tremble := sin(f._t * TAU * TREMBLE_HZ) * 0.04 * c * back            # 당긴 팔의 긴장
	var sway := sin(f._t * TAU * SWAY_HZ) * 0.04 * c * back                  # 가리키는 팔의 흔들림
	if arm:
		sh.rotation.x = 1.9 * draw * (1.0 + 0.15 * c) * back + (-1.7 * thru + 1.1 * fol) * stay + tremble
		sh.rotation.z = -0.25 * draw * back
		el.rotation.x = (-0.35 * draw + 0.15 * c) * back - 0.4 * thru * (1.0 - fol) * stay
		hip.rotation.x = (0.35 * draw + 0.1 * c) * back - 0.7 * fol * stay
		knee.rotation.x = (0.5 * draw + 0.1 * c) * back + 0.9 * fol * stay + breathe
	else:
		sh.rotation.x = -1.5 * draw * back + 0.2 * thru * stay + sway
		sh.rotation.z = 0.0
		el.rotation.x = -0.1 * draw * back - 1.3 * thru * (1.0 - 0.6 * fol) * stay
		hip.rotation.x = (-0.5 * draw - 0.15 * c) * back - 0.35 * thru * (1.0 - fol) * stay
		knee.rotation.x = (0.35 * draw + 0.1 * c) * back + 0.15 * thru * stay + breathe
	if s > 0.0:
		f.torso.rotation.y = (-0.6 * draw - 0.3 * c) * back + 0.5 * thru * (1.0 - fol) * stay   # 던지는 쪽 반대로 감고 던짐에 풀린다
		f.neck.rotation.x += -0.25 * draw * back - 0.5 * thru * stay + 0.3 * fol * stay   # 고리를 보다(−) 창을 따라 더 든다(−) 따라감에 조금 내린다
		f.chest.rotation.x += -0.2 * c * back + 0.15 * thru * stay   # 가슴이 모으기에 열리고 던짐에 닫힌다
	return true
