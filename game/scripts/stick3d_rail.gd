class_name RailPoses
extends RefCounted
## 서가 사다리 가족 자세(Climb 콘텐츠 팩 ladder, run 127 — data/climb/ladder.json, scripts/games/climb_ladder.gd; 운영자 보드의 '사다리 오르기' 가족 — 가로대를 밟고 오르는 몸과 사다리에 매달려 실려 가는 몸): `rail` 굴러가는 서가 사다리의 몸 —
## 0.2 두 손이 머리 위 가로대를 잡고 무릎이 조금 접힌다(예비 — 턱에서 사다리로 한 걸음) → 유지, 팩이 적는 메타로 둘 중 하나:
## 오르기·내려가기("rail_c" +1·−1): 0.6초 한 단의 사다리 걸음 — 이쪽 다리가 위 가로대로 높이 들려 무릎이 접혔다 디디며 펴지고, 그때 반대 손이 위 가로대로 뻗는다(손발이 엇갈려 — 사다리를 오르는 사람), 고개는 오르면 위를, 내려가면 발밑을 본다;
## 구르기("rail_v" −1..1, 가는 속도): 한쪽 다리는 가로대에 곧게, 다른 다리는 뒤로 처져 흔들리고(바퀴의 덜컹임에 맞춰), 뒷손은 머리 위 난간을 쥐고 앞손은 앞으로 뻗어 가는 쪽을 가리키며(책을 집으려는 사서처럼) 몸통이 가는 쪽으로 기운다, 빠를수록 더; 서 있는 사다리에선 두 손이 가로대를 쥔 채 곧게
## → 내리거나 뛰어 로더가 자세를 비우면 stick3d 의 블렌딩이 팔을 내리고 무릎을 편다(회수). 몸이 보는 쪽(f._yaw)으로 '앞'을 읽는다.
## climb(홀드에 붙은 몸, stick3d.gd 의 move "climb")·dangle(가로대에 매달려 호를 그리는 몸)과 다르다: 이건 발로 디딘 사다리 — 오를 땐 손발이 엇갈리고 구를 땐 한 손으로 매달려 선다. stick3d_wade.gd 처럼 주제별 파일

const GRAB_T := 0.2
const STEP_T := 0.6      # 사다리 한 단
const PERIOD := 6.0      # 메타가 없을 때의 제 박자(주민·시연용: 오르기 → 구르기 → 내려가기)

## 잡은 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, GRAB_T, f.pose_t)

## 오르면 +1, 내려가면 −1, 아니면 0 — 팩이 적어 준 값, 없으면 제 박자
static func climb(f: Stick3D) -> float:
	if f.has_meta("rail_c"): return clampf(float(f.get_meta("rail_c")), -1.0, 1.0)
	var ph := fmod(f._t, PERIOD) / PERIOD
	return 1.0 if ph < 0.3 else (-1.0 if ph > 0.7 else 0.0)

## 몸 앞쪽으로 가는 정도 −1..1 — 세상 x 의 속도(meta)를 보는 방향(yaw, +x 를 보면 sin 이 +)으로 뒤집는다, 없으면 제 박자
static func fwd(f: Stick3D) -> float:
	var raw := clampf(float(f.get_meta("rail_v", sin(TAU * (fmod(f._t, PERIOD) / PERIOD - 0.3) / 0.4) if climb(f) == 0.0 else 0.0)), -1.0, 1.0)
	return raw * (1.0 if sin(f._yaw) >= 0.0 else -1.0)

## 골반은 오를 땐 걸음에 조금 오르내리고 구를 땐 바퀴의 덜컹임에 떤다; 몸통은 구를 때 가는 쪽으로, 오를 땐 조금 앞으로
static func lean(f: Stick3D) -> float:
	var kk := k(f); var c := climb(f); var fw := fwd(f)
	var bob := 0.015 * absf(sin(f._t * TAU / STEP_T)) if c != 0.0 else 0.006 * sin(f._t * 26.0) * absf(fw)
	f.pelvis.position.y = StickRig.HIP_Y + bob * kk
	return ((0.08 if c != 0.0 else 0.28 * fw) + 0.02 * sin(f._t * 2.0)) * kk

## 팔다리 — 오를 땐 손발이 엇갈려 가로대로, 구를 땐 뒷손이 난간·앞손이 앞으로·뒷발이 처진다, 서 있으면 두 손이 가로대를 쥔 채 곧게. 고개는 오르면 위, 내려가면 발밑, 구르면 건너편
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "rail": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var c := climb(f); var fw := fwd(f)
	if c != 0.0:
		var a := sin(f._t * TAU / STEP_T) * s   # +면 이쪽 다리가 위 가로대로
		var up := maxf(0.0, a); var reach := maxf(0.0, -a)   # 반대 손이 그때 위로
		hip.rotation.x = -((0.25 + 0.85 * up) * kk)
		knee.rotation.x = -(-(0.3 + 1.0 * sin(PI * up)) * kk)   # 들다 접혔다 디디며 편다
		sh.rotation.x = -(0.2 + (2.0 + 0.7 * reach) * kk); sh.rotation.z = -s * 0.12; el.rotation.x = -((0.9 - 0.5 * reach) * kk + 0.1)
		if s > 0.0: f.neck.rotation.x -= 0.3 * c * kk
	else:
		var rumble := sin(f._t * 13.0) * 0.08 * absf(fw)
		if s > 0.0:   # 앞다리는 가로대에 곧게, 앞손은 앞으로
			hip.rotation.x = -(0.08 * kk); knee.rotation.x = -(-0.12 * kk)
			sh.rotation.x = -(0.2 + (1.3 if absf(fw) > 0.05 else 2.5) * kk); el.rotation.x = -((0.6 - 0.4 * kk) if absf(fw) > 0.05 else (0.5 - 0.3 * kk))
			f.neck.rotation.x -= 0.12 * absf(fw) * kk
		else:   # 뒷다리는 뒤로 처져 흔들리고, 뒷손은 머리 위 난간
			hip.rotation.x = -((-0.45 * absf(fw) + rumble) * kk); knee.rotation.x = -(-(0.12 + 0.6 * absf(fw) + rumble) * kk)
			sh.rotation.x = -(0.2 + 2.6 * kk); el.rotation.x = -(0.5 - 0.3 * kk)
		sh.rotation.z = -s * (0.1 + 0.15 * kk)
	return true
