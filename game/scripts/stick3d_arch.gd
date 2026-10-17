class_name ArchPoses
extends RefCounted
## 높이뛰기 가족 자세(Climb 콘텐츠 팩 bar, run 170 — data/climb/bar.json, scripts/games/climb_bar.gd; 운영자 보드의 '스포츠 — 허들·높이뛰기' 가족의 둘째 자세, hurdle 의 다음): `arch` 가로대를 등으로 넘는 몸(배면뛰기) —
## 시계는 시간이 아니라 자리다: 팩이 공중의 매 틱 meta "arch_k"(0..1, 가로대 위가 0.5)를 몸의 x 로 적는다 — 몸이 멈추면 자세도 멈추지 않고 로더가 비운다(정지화를 막는다). 메타가 없으면 pose_t / FLIGHT_T(점검·주민 시연용).
## 도약(0..0.3): 앞무릎이 치솟고 두 팔이 머리 위로 휘둘러 오르며 골반이 조금 눌린다(예비) → 활(0.2..0.85): 등이 뒤로 휘고 가슴이 열리고 고개가 젖혀지며 두 팔이 머리 너머로, 두 다리는 허벅지가 뒤로 늘어진 채 무릎이 접혀 매달리고 골반이 가로대 위로 뜬다(유지)
## → 넘김(0.6..1.0): 두 다리를 차올려 가로대 너머로 넘기며(허벅지가 앞으로, 무릎이 펴진다) 팔이 내려와 균형을 잡고 고개가 매트를 본다(회수) — 로더가 매트에 내려서면 자세를 비운다.
## 가로대를 떨어뜨리면(meta "arch_hit" 1) 넘김이 사림이 된다: 무릎을 끌어안고 팔이 내려와 몸을 가리고 고개를 사린다. 팔은 14 Hz 잔떨림으로 어느 순간도 정지화가 아니다.
## hurdle(한 걸음에 낮은 가로대를 넘는다 — 앞다리 쭉·뒷다리 옆으로)·bound(던져진다)·glide(뜬다)와 다르다: 이건 뒤로 누워 넘는 첫 자세. stick3d_hurdle.gd 처럼 주제별 파일

const FLIGHT_T := 0.6     # 메타 없이 시간으로 돌 때의 한 번(s) — 2.4 m 가로대를 넘는 비행의 반쯤
const ENTER_T := 0.08
const RISE := 0.28        # 활의 꼭대기에서 골반이 뜨는 높이(m) — 매달린 다리가 가로대를 넘게

## 자세에 든 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, ENTER_T, f.pose_t)

## 가로대를 건너는 자리 0..1 — 팩이 적는 메타, 없으면 시간
static func at(f: Stick3D) -> float:
	return clampf(float(f.get_meta("arch_k", f.pose_t / FLIGHT_T)), 0.0, 1.0)

## 가로대를 떨어뜨렸나 0..1 — 팩이 적는 메타
static func hit(f: Stick3D) -> float:
	return clampf(float(f.get_meta("arch_hit", 0.0)), 0.0, 1.0)

## 시간으로 돌 때 끝났나 — 팩이 모는 동안은 팩이 in_flight 로 비운다
static func done(f: Stick3D) -> bool:
	return not f.has_meta("arch_k") and f.pose_t >= FLIGHT_T

## [drive, arch, kick] — 도약(0.3 까지 한 번), 활(0.2 에 들어 0.45 부터 다 휘고 0.65..0.85 에 풀린다), 넘김(0.6..0.8 에 올라 끝까지)
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var drive := sin(clampf(u / 0.3, 0.0, 1.0) * PI)
	var arch := smoothstep(0.2, 0.45, u) * (1.0 - smoothstep(0.65, 0.85, u))
	var kick := smoothstep(0.6, 0.8, u)
	return [drive, arch, kick]

## 골반은 활에 RISE 만큼 뜨고 도약에 조금 눌리며 사림에 조금 더 내려앉는다; 몸통은 도약에 조금 앞으로, 활에 뒤로 젖고, 넘김에 앞으로(매트를 보며) — 사림은 더 앞으로
static func lean(f: Stick3D) -> float:
	var kk := k(f); var ph := phases(f); var drive := float(ph[0]); var arch := float(ph[1]); var kick := float(ph[2]); var h := hit(f)
	f.pelvis.position.y = StickRig.HIP_Y + (RISE * arch - 0.05 * drive - 0.04 * kick * h) * kk
	return (0.25 * drive - 0.6 * arch + (0.3 + 0.35 * h) * kick) * kk

## 팔다리 — 앞다리(s > 0): 도약에 무릎이 치솟고, 활에 허벅지가 뒤로 늘어진 채 무릎이 접혀 매달리고, 넘김에 앞으로 차올라 펴진다; 뒷다리(s < 0): 도약에 땅을 밀고 나머지는 앞다리와 같다;
## 팔은 둘 다 도약에 머리 위로 휘둘러 올라 활에 머리 너머로 젖고 넘김에 내려와 균형을 잡는다; 고개는 활에 젖혀지고 넘김에 매트를 본다; 사림(hit)은 무릎을 끌어안고 팔을 내리고 고개를 사린다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "arch": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var ph := phases(f); var h := hit(f)
	var drive := float(ph[0]) * kk; var arch := float(ph[1]) * kk; var kick := float(ph[2]) * kk
	var wob := sin(f._t * 14.0 + s) * 0.05   # 팔의 잔떨림 — 정지화가 아니다
	if s > 0.0:
		hip.rotation.x = -(1.2 * drive) + 0.55 * arch - (1.3 - 0.3 * h) * kick     # 앞다리 — 도약에 치솟고, 활에 뒤로 늘어지고, 넘김에 차올린다(사림은 덜)
		knee.rotation.x = 1.1 * drive + 0.9 * arch + (0.15 + 1.4 * h) * kick       # 접힌 채 매달리다 펴진다; 사림은 끌어안는다
	else:
		hip.rotation.x = 0.35 * drive + 0.55 * arch - (1.3 - 0.3 * h) * kick       # 뒷다리 — 도약에 땅을 밀고 나머지는 같다
		knee.rotation.x = 0.25 * drive + 0.9 * arch + (0.15 + 1.4 * h) * kick
	hip.rotation.z = 0.0
	sh.rotation.x = -(1.6 * drive) - 2.6 * arch - (0.8 - 0.5 * h) * kick + wob    # 머리 위로 휘둘러 올라 머리 너머로, 넘김에 내려온다(−x 가 앞·위)
	sh.rotation.z = -s * (0.12 + 0.35 * arch + 0.15 * drive)
	el.rotation.x = -(0.4 * drive + 0.25 * arch + (0.5 + 0.6 * h) * kick)
	if s > 0.0:
		f.neck.rotation.x += -0.1 * drive - 0.45 * arch + (0.25 + 0.4 * h) * kick   # 활에 젖혀지고(−), 넘김에 매트를 본다(+); 사림은 더 사린다
		f.chest.rotation.x += -0.3 * arch + 0.1 * kick                                # 가슴이 열리며 등이 휜다
	return true
