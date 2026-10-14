class_name PeerPoses
extends RefCounted
## 망원경 가족 자세(Climb 콘텐츠 팩 telescope, run 154 — data/climb/telescope.json, scripts/games/climb_telescope.gd; 운영자 보드의 '지도 읽기·둘러보기' 가족 — 가슴 높이의 접안렌즈에 눈을 대고 멀리 보는 몸): `peer` 망원경을 보는 몸 —
## 자리 잡기(0..0.5): 골반에서 꺾여 앞으로 숙이고(접안렌즈가 가슴 높이에 있다) 오른손이 앞의 통으로 가 쥐며 왼손이 올라와 감은 눈을 오목하게 덮는다, 오른발이 앞으로 나가 버티고 골반이 조금 내려앉는다, 고개는 통을 따라 틈 너머 위를 본다
## → 훑기(0.5..3.4): 고개와 몸통이 보는 자리를 따라 천천히 돈다(meta "peer_pan" −1..1 — 팩이 화살표로 적는다, 없으면 제 박자로 좌우), 통을 쥔 손이 그쪽으로 조금 밀고, 숨을 따라 가슴이 들락인다 — 정지화가 아니다
## → 바로 서기(3.4..4.0): 손이 내려오고 몸이 펴지며 고개가 별을 본 하늘로 올라간다(살짝 뒤로). 발판에 선 채 로더가 자세를 비우면 stick3d 의 블렌딩이 마저 편다(회수).
## 시계는 pose_t; meta "peer_t" 가 있으면 그 값(점검·주민 시연용 — 한 순간에 멈춰 세운다). done(f) 가 참이면(4.0초) 로더가 자세를 비운다.
## shade(선 채 손차양으로 멀리 본다)·scan(판을 읽는다)·read(손의 종이)와 다르다: 이건 숙여 한 눈을 기계에 대고 다른 눈을 손으로 덮은 몸. stick3d_spin.gd 처럼 주제별 파일

const SETTLE_T := 0.5
const PAN_T := 2.9        # 훑는 길이 — 팩의 show_s 4.0 = 자리 잡기 + 훑기 + 바로 서기
const RISE_T := 0.6
const PEER_T := 4.0
const ENTER_T := 0.1

## 자세에 든 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, ENTER_T, f.pose_t)

## 자세의 시계 — 팩·점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("peer_t", f.pose_t))

## 보기가 끝났나 — 로더가 자세를 비운다
static func done(f: Stick3D) -> bool:
	return at(f) >= PEER_T

## [bend, sweep, rise] — 접안렌즈에 숙인 몫 0..1(자리 잡기에 오르고 바로 서기에 내려간다), 보는 자리 −1..1(메타가 있으면 그 값, 없으면 제 박자 — 훑는 동안만), 바로 선 몫 0..1
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var st := smoothstep(0.0, SETTLE_T, u)
	var rise := smoothstep(SETTLE_T + PAN_T, PEER_T, u)
	var sweep_k := clampf((u - SETTLE_T) / 0.4, 0.0, 1.0) * (1.0 - rise)
	var sweep := float(f.get_meta("peer_pan", sin((u - SETTLE_T) * 1.1))) * sweep_k
	return [st * (1.0 - rise), sweep, rise]

## 골반은 숙인 만큼 조금 내려앉는다(훑으며 숨을 따라 흔들린다); 몸통은 접안렌즈 쪽으로 깊이 숙이고 바로 서며 하늘을 보느라 살짝 뒤로
static func lean(f: Stick3D) -> float:
	var kk := k(f); var ph := phases(f); var bend := float(ph[0]); var rise := float(ph[2])
	f.pelvis.position.y = StickRig.HIP_Y - (0.05 * bend + 0.01 * sin(at(f) * 2.4) * bend) * kk
	return (0.55 * bend - 0.06 * rise) * kk

## 팔다리 — 오른팔: 앞의 통을 쥔다(훑는 쪽으로 조금 민다); 왼팔: 올라와 감은 눈을 덮는다(팔꿈치가 깊이 접혀 손이 얼굴에); 다리: 오른발 앞·왼발 뒤로 버틴다; 고개는 통을 따라 위를 보고 훑는 쪽으로 돈다, 바로 서며 하늘로
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "peer": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var ph := phases(f); var bend := float(ph[0]); var sweep := float(ph[1]); var rise := float(ph[2])
	var b := bend * kk
	if s > 0.0:
		sh.rotation.x = -((1.25 + 0.12 * sweep) * b)                  # 통을 쥔 손 — 앞 가슴 높이, 훑는 쪽으로 조금
		sh.rotation.z = s * 0.1 * b
		el.rotation.x = -(1.1 * b)
		hip.rotation.x = 0.3 * b; knee.rotation.x = 0.35 * b           # 앞발 — 버틴다
		f.chest.rotation.x += (0.15 + 0.02 * sin(at(f) * 2.4)) * b     # 숙인 가슴, 숨
		f.neck.rotation.x += (-0.2 * b - 0.35 * rise) * kk              # 통을 따라 위를 — 바로 서며 하늘로
		f.neck.rotation.y += 0.3 * sweep * b
		f.torso.rotation.y = 0.15 * sweep * b
	else:
		sh.rotation.x = -(1.9 * b); sh.rotation.z = -s * 0.3 * b        # 눈을 덮는 손 — 안쪽으로(s < 0 이라 local +x 쪽이 얼굴)
		el.rotation.x = -(2.2 * b)
		hip.rotation.x = -(0.15 * b); knee.rotation.x = 0.1 * b         # 뒷발
	return true
