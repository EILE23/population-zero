class_name ShovelPoses
extends RefCounted
## 삽질 가족 자세(Climb 콘텐츠 팩 drift, run 176 — data/climb/drift.json, scripts/games/climb_drift.gd; 운영자 보드의 '삽질' 가족의 첫 자세): `shovel` 별가루 더미에 꽂힌 삽을 잡아 발로 날을 밟아 찌르고 젖혀 한쪽으로 퍼 넘기는 몸 — 몸은 무더기 쪽(옆)을 보고 삽은 앞발 앞에 있다.
## 시계는 셋이고 팩이 적는다: meta "shovel_t"(바퀴에 든 뒤 시간 — 찌르기 0.25·지렛대 0.3·헤이브 0.35, 바퀴마다 0 으로), meta "shovel_end"("star" 별이 떴다 | "stop" 놓았다), meta "shovel_u"(끝난 뒤 시간). 메타가 없으면 pose_t 로 혼자 돈다(점검·주민 시연용: 세 바퀴 뒤 0.3 s 에 삽을 꽂고 선다).
## 찌르기(0..0.25): 상체가 깊이 숙고 두 팔이 앞으로 내려가 손잡이를 잡고, 앞발(리드)이 들렸다가(가운데에 엉덩이 −0.9·무릎 1.3 더) 날을 밟아 내려오고, 고개는 날을 본다 → 지렛대(0.25..0.55): 팔꿈치를 당겨 손이 몸 쪽으로, 무릎이 굽고 골반이 내려앉고, 상체가 조금 선다
## → 헤이브(0.55..0.9): 두 팔이 한쪽으로 휘돌아 올라가고(어깨 z 가 같은 쪽으로) 상체가 뒤로 조금 젖혀 가슴이 열리고 고개가 삽날을 따라 오르고, 다리가 선다 → 다음 바퀴의 찌르기는 헤이브 끝에서 이어진다(끊김 없음)
## → 바라봄(star, 0.3 에 들어 0.6): 리드 손은 손잡이 꼭대기에, 트레일 손은 허리에(어깨 z 0.5·팔꿈치 −1.3), 상체가 삽에 조금 기대고, 고개가 별을 올려다보며 0.5 Hz 로 까딱, 체중이 리드 다리에 / 멈춤(stop, 0.3): 팔이 내려오며 트레일 손이 가운데서 이마를 훔치고(어깨 −2.0·팔꿈치 −2.2 의 산) 선다 — 정지화가 아니다(무릎은 늘 0.8 Hz 로 숨쉰다).
## press(무게를 머리 위에 버틴다)·stomp(발로 판을 누른다)·plant(모래에 내린다)와 다르다: 이건 제 삽으로 땅을 덜어 내는 몸 — 바퀴마다 한 삽이 옮겨 간다. stick3d_press.gd 처럼 주제별 파일

const THRUST_T := 0.25    # 찌르기(s) = climb_drift thrust_s
const LEVER_T := 0.3      # 지렛대(s) = lever_s
const HEAVE_T := 0.35     # 헤이브(s) = heave_s
const CYCLE_T := 0.9      # 한 삽(s) = cycle_s
const GAZE_T := 0.6       # 바라봄(s) = gaze_s
const GAZE_IN := 0.3      # 바라봄에 드는 시간(s)
const STOP_T := 0.3       # 멈춤(s) = stop_s
const DEMO_SCOOPS := 3    # 메타 없이 돌 때의 삽 수
const BREATHE_HZ := 0.8
const NOD_HZ := 0.5
const DIP_A := 0.08       # 찌르기의 골반 내려앉음(m)
const DIP_B := 0.12       # 지렛대의 골반 내려앉음(m)

## 바퀴에 든 뒤 시간(s) — 팩의 메타, 없으면 pose_t 를 바퀴로 접는다(끝난 뒤는 헤이브 끝)
static func since(f: Stick3D) -> float:
	if f.has_meta("shovel_t"): return maxf(0.0, float(f.get_meta("shovel_t")))
	if f.pose_t >= CYCLE_T * DEMO_SCOOPS: return CYCLE_T
	return fmod(f.pose_t, CYCLE_T)

## 어떻게 끝났나 — "star" | "stop" | ""(아직 판다)
static func end(f: Stick3D) -> String:
	if f.has_meta("shovel_end"): return String(f.get_meta("shovel_end"))
	if f.has_meta("shovel_t"): return ""
	return "stop" if f.pose_t >= CYCLE_T * DEMO_SCOOPS else ""

## 끝난 뒤 시간(s)
static func end_u(f: Stick3D) -> float:
	if f.has_meta("shovel_end"): return maxf(0.0, float(f.get_meta("shovel_u", 0.0)))
	if f.has_meta("shovel_t"): return 0.0
	return maxf(0.0, f.pose_t - CYCLE_T * DEMO_SCOOPS)

## 시간으로 돌 때 끝났나 — 팩이 모는 동안은 팩이 busy 로 비운다
static func done(f: Stick3D) -> bool:
	return not f.has_meta("shovel_t") and end(f) == "stop" and end_u(f) >= STOP_T

## [wA, wB, wC, lift, gz, st] — 찌르기의 몫(헤이브 끝에서 든다), 지렛대의 몫, 헤이브의 몫(앞 바퀴의 끝까지 — 바퀴가 이어진다), 리드 발의 들림(찌르기 가운데 1), 바라봄(끝난 뒤 0.3 에 1), 멈춤(0..0.3)
static func phases(f: Stick3D) -> Array:
	var u := since(f)
	var th := smoothstep(0.0, THRUST_T, u)
	var lv := smoothstep(THRUST_T, THRUST_T + LEVER_T, u)
	var hv := smoothstep(THRUST_T + LEVER_T, CYCLE_T, u)
	var wa := th * (1.0 - lv)
	var wb := lv * (1.0 - hv)
	var wc := hv + (1.0 - th)
	var lift := sin(th * PI) * (1.0 - lv)
	var e := end(f); var eu := end_u(f)
	var gz := smoothstep(0.0, GAZE_IN, eu) if e == "star" else 0.0
	var st := smoothstep(0.0, STOP_T, eu) if e == "stop" else 0.0
	return [wa, wb, wc, lift, gz, st]

## 골반은 찌르기에 조금, 지렛대에 더 내려앉고 헤이브에 선다; 상체는 찌르기에 깊이 숙고 지렛대에 조금 서고 헤이브에 뒤로 조금, 바라봄엔 삽에 기댄다
static func lean(f: Stick3D) -> float:
	var ph := phases(f); var wa := float(ph[0]); var wb := float(ph[1]); var wc := float(ph[2]); var gz := float(ph[4]); var st := float(ph[5])
	var stay := (1.0 - gz) * (1.0 - st)
	f.pelvis.position.y = StickRig.HIP_Y - (DIP_A * wa + DIP_B * wb) * stay
	return (0.5 * wa + 0.3 * wb - 0.1 * wc) * stay + 0.1 * gz

## 팔다리 — 두 팔: 찌르기에 앞으로 내려가 손잡이를 잡고(어깨 −0.9·팔꿈치 −0.2), 지렛대에 당기고(−0.5·−1.3), 헤이브에 한쪽으로 휘돌아 오르고(−1.5, z −0.45 둘 다 같은 쪽, 팔꿈치 −0.3), 바라봄에 리드 손은 손잡이(−0.6·−0.5)·트레일 손은 허리(0.2, z 0.5, −1.3), 멈춤에 트레일 손이 이마를 훔친다;
## 두 다리: 찌르기에 리드 발이 들렸다 날을 밟고(엉덩이 −0.25·무릎 0.3, 가운데 −0.9·+1.3 더) 트레일은 선다(무릎 0.15), 지렛대에 둘 다 굽고(엉덩이 −0.1·무릎 0.4), 헤이브에 선다(무릎 0.1), 바라봄에 체중이 리드로(리드 무릎 0.05, 트레일 엉덩이 0.1·무릎 0.3); 무릎은 늘 숨쉰다; 고개는 날을 보고(찌르기, +0.6) 삽날을 따라 오르고(헤이브, −0.25) 별을 올려다본다(바라봄, −0.55 ± 0.05); 가슴은 헤이브에 열린다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "shovel": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var ph := phases(f); var wa := float(ph[0]); var wb := float(ph[1]); var wc := float(ph[2]); var lift := float(ph[3]); var gz := float(ph[4]); var st := float(ph[5])
	var stay := (1.0 - gz) * (1.0 - st)
	var lead := s > 0.0
	var breathe := sin(f._t * TAU * BREATHE_HZ) * 0.03   # 무릎의 숨 — 정지화가 아니다
	var wipe := sin(st * PI)                              # 멈춤 가운데 트레일 손이 이마로
	var nod := sin(f._t * TAU * NOD_HZ) * 0.05            # 바라봄의 고개 까딱
	sh.rotation.x = (-0.9 * wa - 0.5 * wb - 1.5 * wc) * stay + (-0.6 if lead else 0.2) * gz + (0.0 if lead else -2.0 * wipe)
	sh.rotation.z = (-0.45 * wc) * stay + (0.0 if lead else -s * 0.5) * gz
	el.rotation.x = (-0.2 * wa - 1.3 * wb - 0.3 * wc) * stay + (-0.5 if lead else -1.3) * gz + (0.0 if lead else -2.2 * wipe)
	hip.rotation.x = ((-0.25 if lead else 0.0) * wa - 0.1 * wb) * stay + (0.0 if lead else 0.1) * gz - (0.9 * lift * stay if lead else 0.0)
	knee.rotation.x = ((0.3 if lead else 0.15) * wa + 0.4 * wb + 0.1 * wc) * stay + (0.05 if lead else 0.3) * gz + (1.3 * lift * stay if lead else 0.0) + breathe
	if s > 0.0:
		f.neck.rotation.x += (0.6 * wa - 0.25 * wc) * stay - (0.55 + nod) * gz - 0.2 * wipe   # 날을 보다(+) 삽날을 따라 오르고(−) 별을 올려다본다(−), 이마를 훔칠 땐 조금 숙인다
		f.chest.rotation.x += -0.1 * wc * stay   # 헤이브에 가슴이 열린다
	return true
