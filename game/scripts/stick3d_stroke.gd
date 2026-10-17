class_name StrokePoses
extends RefCounted
## 골프 가족 자세(Climb 콘텐츠 팩 green, run 172 — data/climb/green.json, scripts/games/climb_green.gd; 운영자 보드의 '스포츠 — 골프' 가족의 첫 자세): `stroke` 티의 공을 채로 날리는 몸 — 몸은 카메라를 보고 공은 x 로 난다(정면 골프).
## 시계는 둘이고 팩이 적는다: meta "stroke_c"(0..1, 모은 만큼 — 백스윙이 감긴다)와 meta "stroke_t"(놓은 뒤 시간 — 다운스윙·임팩트·피니시); 목표 쪽은 meta "stroke_lead"(±1 — 그쪽 팔이 리드). 메타가 없으면 pose_t 로 혼자 한 번 돈다(점검·주민 시연용: 어드레스 0.3 s, 모으기 0.7 s, 스윙 0.6 s).
## 어드레스(0..0.2): 무릎이 풀리고 골반에서 조금 숙여 두 팔이 앞에 모여 채 끝이 공에 닿고 고개는 공을 본다, 손은 1.6 Hz 로 꼼지락(예비) → 백스윙(모은 만큼): 두 팔이 뒤쪽(트레일) 어깨 너머로 감기고 몸통이 목표 반대로 틀리고 트레일 팔꿈치가 접힌다, 고개는 그대로 공에(유지)
## → 다운스윙(놓은 뒤 0..0.12): 몸통이 풀리며 팔이 공을 지나 리드 쪽으로 쓸고 → 피니시(0.12..0.37): 팔이 리드 어깨 위로 오르고 가슴이 목표를 향하고 트레일 무릎이 안으로 꺾이고 고개가 들려 공을 쫓는다, 팔은 10 Hz 로 떤다 → 풀림(0.45..0.6): 서서 팔이 내려온다(회수) — 팩이 swing_s 에 메타를 지우고 로더가 자세를 비운다.
## arch(가로대를 넘는 몸)·plant(모래에 내리는 몸)·hurdle 과 다르다: 이건 몸이 아니라 공을 보내는 첫 자세 — 눈이 공을 쫓는다. stick3d_arch.gd 처럼 주제별 파일

const ADDRESS_T := 0.2    # 어드레스에 드는 시간(s)
const DEMO_CHARGE := 0.7  # 메타 없이 돌 때 모으는 시간(s) = climb_green charge_s
const DEMO_WAIT := 0.3    # 메타 없이 돌 때 어드레스 뒤 모으기 전 숨(s)
const STRIKE_T := 0.12    # 놓은 뒤 임팩트까지(s) = climb_green strike_s
const FINISH_T := 0.37    # 피니시가 다 올라오는 때(s)
const RELAX_T := 0.45     # 풀리기 시작(s)
const SWING_T := 0.6      # 한 번(s) = climb_green swing_s
const TREMBLE_HZ := 10.0
const WAGGLE_HZ := 1.6
const DIP := 0.05         # 어드레스에 무릎이 풀려 골반이 내려앉는 높이(m)

## 모은 만큼 0..1 — 팩의 메타, 없으면 시간
static func charge(f: Stick3D) -> float:
	if f.has_meta("stroke_c"): return clampf(float(f.get_meta("stroke_c")), 0.0, 1.0)
	if f.has_meta("stroke_t"): return 1.0
	return smoothstep(ADDRESS_T + DEMO_WAIT, ADDRESS_T + DEMO_WAIT + DEMO_CHARGE, f.pose_t)

## 놓은 뒤 시간(s) — 아직 놓지 않았으면 −1
static func since(f: Stick3D) -> float:
	if f.has_meta("stroke_t"): return maxf(0.0, float(f.get_meta("stroke_t")))
	if f.has_meta("stroke_c"): return -1.0
	var u := f.pose_t - (ADDRESS_T + DEMO_WAIT + DEMO_CHARGE)
	return u if u >= 0.0 else -1.0

## 목표 쪽 ±1 — 그쪽 팔이 리드
static func lead(f: Stick3D) -> float:
	return 1.0 if float(f.get_meta("stroke_lead", 1.0)) >= 0.0 else -1.0

## 시간으로 돌 때 끝났나 — 팩이 모는 동안은 팩이 busy 로 비운다
static func done(f: Stick3D) -> bool:
	return not f.has_meta("stroke_c") and not f.has_meta("stroke_t") and since(f) >= SWING_T

## [addr, back, thru, up] — 어드레스(0.2 까지 든다), 백스윙(모은 만큼, 다운스윙 0.12 에 풀린다), 스윙(놓은 뒤 0 → 0.37 에 피니시), 풀림(0.45..0.6 에 0 → 1)
static func phases(f: Stick3D) -> Array:
	var u := since(f)
	var addr := smoothstep(0.0, ADDRESS_T, f.pose_t)
	var c := charge(f)
	var back := c if u < 0.0 else c * (1.0 - smoothstep(0.0, STRIKE_T, u))
	var thru := 0.0 if u < 0.0 else smoothstep(0.0, FINISH_T, u)
	var up := 0.0 if u < 0.0 else smoothstep(RELAX_T, SWING_T, u)
	return [addr, back, thru, up]

## 골반은 어드레스에 내려앉고 피니시에 돌아온다; 몸통은 어드레스에 숙이고 백스윙엔 그대로, 피니시에 가슴을 든다(뒤로 조금)
static func lean(f: Stick3D) -> float:
	var ph := phases(f); var addr := float(ph[0]); var thru := float(ph[2]); var up := float(ph[3])
	var stay := 1.0 - up
	f.pelvis.position.y = StickRig.HIP_Y - DIP * addr * (1.0 - 0.7 * thru) * stay
	return (0.32 * addr * (1.0 - thru) - 0.15 * thru) * stay

## 팔다리 — 두 팔: 앞에 모여(채) 백스윙에 트레일 쪽으로 감기고 스윙에 리드 쪽 어깨 위로 쓸려 오른다(옆으로 가는 각은 두 어깨 다 −쪽·a — 그쪽 팔은 벌리고 다른 팔은 가슴을 가로지른다); 트레일 팔꿈치는 백스윙에 접힌다;
## 두 다리: 어드레스에 무릎이 풀리고 피니시에 트레일 무릎이 안으로 꺾인다; 몸통은 백스윙에 목표 반대로, 피니시에 목표로 틀린다; 고개는 공을 보다 피니시에 들어 공을 쫓는다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "stroke": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(f); var addr := float(ph[0]); var back := float(ph[1]); var thru := float(ph[2]); var up := float(ph[3])
	var ld := lead(f); var trail := s != ld
	var stay := 1.0 - up
	var waggle := sin(f._t * TAU * WAGGLE_HZ) * 0.05 * addr * (1.0 - back) * (1.0 if since(f) < 0.0 else 0.0)   # 어드레스의 꼼지락
	var tremble := sin(f._t * TAU * TREMBLE_HZ + s) * 0.04 * thru * stay                                          # 피니시의 잔떨림 — 정지화가 아니다
	var side := ld * (2.2 * back - 2.4 * thru) * stay   # 옆으로 가는 각 — 백스윙은 트레일 쪽(−ld), 스윙은 리드 쪽(+ld)
	sh.rotation.z = -side - s * 0.08 * addr * stay + waggle
	sh.rotation.x = -(0.55 * addr * (1.0 - 0.5 * back) * (1.0 - 0.6 * thru)) * stay + tremble
	el.rotation.x = -(0.15 * addr + (0.9 if trail else 0.25) * back + 0.35 * thru * (1.0 if trail else 0.4)) * stay
	hip.rotation.x = -(0.3 * addr * (1.0 - thru)) * stay
	hip.rotation.z = (0.18 * thru * stay) * s if trail else 0.0   # 트레일 무릎이 안으로
	knee.rotation.x = (0.35 * addr * (1.0 - 0.5 * thru) + (0.55 * thru if trail else 0.0)) * stay
	if s > 0.0:
		f.torso.rotation.y = ld * (-0.9 * back + 0.8 * thru) * stay   # 목표 반대로 감고 목표로 풀린다
		f.neck.rotation.x += (0.45 * addr * (1.0 - thru) - 0.35 * thru) * stay   # 공을 보다(+) 피니시에 들어 쫓는다(−)
		f.neck.rotation.y += ld * 0.5 * thru * stay   # 공이 간 쪽으로
		f.chest.rotation.x += -0.12 * thru * stay      # 가슴이 든다
	return true
