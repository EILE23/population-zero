class_name HurdlePoses
extends RefCounted
## 허들 가족 자세(Climb 콘텐츠 팩 hurdle, run 155 — data/climb/hurdle.json, scripts/games/climb_hurdle.gd; 운영자 보드의 '스포츠 — 허들·높이뛰기' 가족의 첫 자세): `hurdle` 낮은 가로대를 뛰어넘는 몸 —
## 시계는 시간이 아니라 자리다: 팩이 매 틱 meta "hurdle_k"(0..1, 가로대 위가 0.5)를 몸의 x 로 적는다 — 몸이 멈추면 자세도 멈추지 않고 로더가 비운다(정지화를 막는다). 메타가 없으면 pose_t / VAULT_T(점검·주민 시연용).
## 디딤(0..0.3): 무릎이 조금 내려앉고 두 팔이 뒤로 — 예비 → 도약(0.3..0.7): 앞다리(오른쪽)가 곧게 앞으로 뻗고 뒷다리(왼쪽)는 옆으로 펴 접히며(허들 자세의 trail leg), 팔은 다리와 반대(왼팔 앞·오른팔 뒤),
## 골반이 가로대 위로 뜬다, 몸통이 앞으로 숙는다 → 착지 걸음(0.7..1.0): 앞발이 내려서며 무릎이 한 번 받치고 뒷다리가 앞으로 휘둘러 나가며 팔이 앞으로 균형을 잡는다. 다음 가로대의 디딤이 이 착지에서 바로 이어진다.
## 팔은 걷는 박자(_t)로 조금 흔들려 어느 순간도 정지화가 아니다. bound(다이빙 판 — 제 발로 눌러 던져진다)·skip(아이 걸음)과 다르다: 이건 가로대 하나를 넘는 한 걸음. stick3d_peer.gd 처럼 주제별 파일

const VAULT_T := 0.45     # 메타 없이 시간으로 돌 때의 한 번(s) — 260 px/s 걸음으로 가로대 간격 60 px 이 0.23 s 라 둘을 합친 길이
const ENTER_T := 0.08
const RISE := 0.3         # 도약 꼭대기에서 골반이 뜨는 높이(m) — 가로대 20 px = 0.56 m, 골반 0.42 + 0.3 = 0.72 로 접은 뒷다리가 넘는다

## 자세에 든 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, ENTER_T, f.pose_t)

## 가로대를 건너는 자리 0..1 — 팩이 적는 메타, 없으면 시간
static func at(f: Stick3D) -> float:
	return clampf(float(f.get_meta("hurdle_k", f.pose_t / VAULT_T)), 0.0, 1.0)

## 시간으로 돌 때 끝났나 — 팩이 모는 동안은 팩이 in_row 로 비운다
static func done(f: Stick3D) -> bool:
	return not f.has_meta("hurdle_k") and f.pose_t >= VAULT_T

## [crouch, drive, land] — 디딤(0.3 까지 한 번 내려앉았다 선다), 도약(0.3 에 올라 0.6 까지 다 뜨고 0.85 에 내려온다), 착지(0.7..1.0 에 한 번 받친다)
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var crouch := sin(clampf(u / 0.3, 0.0, 1.0) * PI)
	var drive := smoothstep(0.15, 0.4, u) * (1.0 - smoothstep(0.65, 0.88, u))
	var land := sin(clampf((u - 0.7) / 0.3, 0.0, 1.0) * PI)
	return [crouch, drive, land]

## 골반은 도약에 RISE 만큼 뜨고 디딤·착지에 조금 내려앉는다; 몸통은 도약에 앞으로 숙고 착지에 조금
static func lean(f: Stick3D) -> float:
	var kk := k(f); var ph := phases(f); var crouch := float(ph[0]); var drive := float(ph[1]); var land := float(ph[2])
	f.pelvis.position.y = StickRig.HIP_Y + (RISE * drive - 0.06 * crouch - 0.08 * land) * kk
	return (0.38 * drive + 0.12 * crouch + 0.18 * land) * kk

## 팔다리 — 앞다리(s > 0): 디딤에 조금 굽고 도약에 곧게 앞으로 뻗으며 착지에 내려서 받친다; 뒷다리(s < 0): 도약에 옆으로 펴 접히고(엉덩이가 옆으로 벌어지고 무릎이 납작하게) 착지에 앞으로 휘둘러 나간다;
## 팔은 다리와 반대 — 왼팔 앞·오른팔 뒤, 디딤에 둘 다 뒤로, 착지에 둘 다 앞으로; 고개는 다음 가로대를 본다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "hurdle": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var ph := phases(f); var crouch := float(ph[0]) * kk; var drive := float(ph[1]) * kk; var land := float(ph[2]) * kk
	var wob := sin(f._t * 14.0) * 0.06   # 팔의 잔떨림 — 정지화가 아니다
	if s > 0.0:
		hip.rotation.x = -(1.35 * drive) - 0.25 * crouch + 0.3 * land         # 앞다리 — 디딤에 조금 뒤, 도약에 앞으로 쭉, 착지에 내려선다
		hip.rotation.z = 0.0
		knee.rotation.x = 0.12 * drive + 0.55 * crouch + 1.0 * land            # 거의 곧게, 착지에 한 번 받친다
		sh.rotation.x = 0.95 * drive + 0.5 * crouch - 0.45 * land + wob        # 오른팔 뒤로(앞다리와 반대), 착지에 앞으로
		sh.rotation.z = -s * (0.12 + 0.2 * drive)
		el.rotation.x = -(0.5 * drive + 0.3 * crouch + 0.4 * land)
		f.neck.rotation.x += (-0.12 * drive + 0.18 * land) * kk                # 가로대 너머를 보고 착지에 발밑을
		f.chest.rotation.x += 0.08 * drive
	else:
		hip.rotation.x = -(0.55 * drive) - 0.1 * crouch - 0.6 * land          # 뒷다리 — 도약에 옆으로 올라 접히고 착지에 앞으로 휘둘러 나간다
		hip.rotation.z = -s * (1.15 * drive)
		knee.rotation.x = 1.65 * drive + 0.45 * crouch + 0.35 * land           # 납작하게 접힌 무릎
		sh.rotation.x = -(1.4 * drive) + 0.5 * crouch - 0.5 * land - wob       # 왼팔 앞으로(앞다리와 반대), 착지에 앞으로 균형
		sh.rotation.z = -s * (0.12 + 0.25 * drive)
		el.rotation.x = -(0.7 * drive + 0.3 * crouch + 0.4 * land)
	return true
