class_name SquintPoses
extends RefCounted
## 해시계 가족 자세(Climb 콘텐츠 팩 sundial, run 157 — data/climb/sundial.json, scripts/games/climb_sundial.gd; 운영자 보드의 '지도 읽기·둘러보기' 가족 — 빛을 가리고 발밑의 판을 읽는 몸): `squint` 해시계를 읽는 몸 —
## 손 올리기(0..0.5): 오른손이 올라와 이마 위에 납작하게 얹혀 빛을 가리고(팔꿈치가 높이 접힌다), 왼팔은 앞으로 내려가 그림자 끝을 가리킨다, 몸은 골반에서 뒤로 젖혀진다(판이 발밑에 있어 멀리 보는 손차양보다 깊이), 고개는 판으로 내려간다
## → 읽기(0.5..2.5): 무게가 1.6초 박자로 발에서 발로 옮겨 간다(딛는 다리는 곧고 쉬는 다리는 무릎이 접힌다, 골반이 옮겨 가는 가운데서 조금 내려앉는다), 고개가 그림자를 따라 판에서 해로 올라가고(meta "squint_dir" −1..1 — 팩이 그림자 끝 쪽을 적는다, 없으면 0.5), 1.9초에 끄덕 한 번 — 정지화가 아니다
## → 바로 서기(2.5..3.2): 두 손이 내려오고 몸이 펴지며 고개가 앞을 본다. 발판에 선 채 로더가 자세를 비우면 stick3d 의 블렌딩이 마저 편다(회수).
## 시계는 pose_t; meta "squint_t" 가 있으면 그 값(점검·주민 시연용 — 한 순간에 멈춰 세운다). done(f) 가 참이면(3.2초) 로더가 자세를 비운다.
## shade(선 채 손차양으로 멀리 둘러본다 — 왼손은 허리에, 몸통이 좌우로 돈다)·peer(숙여 접안렌즈에)·scan(판을 읽는다)과 다르다: 이건 뒤로 젖힌 몸이 한 손으로 빛을 가리고 다른 손으로 발밑을 가리키며 무게를 옮겨 딛는 몸. stick3d_peer.gd 처럼 주제별 파일

const SETTLE_T := 0.5
const READ_T := 2.0        # 읽는 길이 — 팩의 read_s 3.2 = 손 올리기 + 읽기 + 바로 서기
const RISE_T := 0.7
const SQUINT_T := 3.2
const ENTER_T := 0.1
const SWAY_P := 1.6        # 무게가 한 번 왕복하는 박자(초)
const NOD_AT := 1.9

## 자세에 든 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, ENTER_T, f.pose_t)

## 자세의 시계 — 팩·점검이 적어 준 값, 없으면 pose_t
static func at(f: Stick3D) -> float:
	return float(f.get_meta("squint_t", f.pose_t))

## 읽기가 끝났나 — 로더가 자세를 비운다
static func done(f: Stick3D) -> bool:
	return at(f) >= SQUINT_T

## [up, sway, nod, gaze, rise] — 손이 이마에 오른 몫 0..1(손 올리기에 오르고 바로 서기에 내려간다), 무게 −1..1(+ 는 오른발에; 읽는 동안만), 끄덕 0..1(1.9초의 한 박), 시선 0..1(0 판, 1 해), 바로 선 몫 0..1
static func phases(f: Stick3D) -> Array:
	var u := at(f)
	var rise := smoothstep(SETTLE_T + READ_T, SQUINT_T, u)
	var up := smoothstep(0.0, SETTLE_T, u) * (1.0 - rise)
	var in_read := clampf((u - SETTLE_T) / 0.4, 0.0, 1.0) * (1.0 - rise)
	var sway := sin((u - SETTLE_T) * TAU / SWAY_P) * in_read
	var nod := sin(clampf((u - NOD_AT) / 0.4, 0.0, 1.0) * PI) * (1.0 - rise)
	var gaze := smoothstep(0.35, 0.75, (u - SETTLE_T) / READ_T) * (1.0 - rise)
	return [up, sway, nod, gaze, rise]

## 골반은 무게가 옮겨 가는 가운데(sway 0)에서 조금 내려앉는다; 몸통은 뒤로 젖혀지고 끄덕에 조금 앞으로
static func lean(f: Stick3D) -> float:
	var kk := k(f); var ph := phases(f); var up := float(ph[0]); var sway := float(ph[1]); var nod := float(ph[2])
	f.pelvis.position.y = StickRig.HIP_Y - 0.02 * (1.0 - absf(sway)) * up * kk
	return (-0.2 * up + 0.1 * nod) * kk

## 팔다리 — 오른팔: 이마 위에 납작한 손(빛을 가린다); 왼팔: 그림자 끝을 가리켜 앞으로 내려간다(그림자 쪽으로 조금 돈다); 다리: 무게를 딛는 다리는 곧고 쉬는 다리는 접힌다; 고개는 판으로 내려가 해로 올라가고 그림자 쪽으로 돌며 끄덕인다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "squint": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var ph := phases(f); var up := float(ph[0]); var sway := float(ph[1]); var nod := float(ph[2]); var gaze := float(ph[3])
	var dir := clampf(float(f.get_meta("squint_dir", 0.5)), -1.0, 1.0)
	var b := up * kk
	var load := 0.5 + 0.5 * s * sway   # 이 다리가 무게를 딛는 몫
	hip.rotation.x = 0.12 * (1.0 - load) * b; knee.rotation.x = 0.35 * (1.0 - load) * b
	if s > 0.0:
		sh.rotation.x = -(2.35 * b); sh.rotation.z = -0.3 * b             # 이마 위의 손 — 팔이 높이 들려
		el.rotation.x = -(1.75 * b)
		f.neck.rotation.x += (0.45 * (1.0 - gaze) - 0.4 * gaze) * b + 0.3 * nod * kk   # 판으로 내려가, 해로 올라가, 끄덕
		f.neck.rotation.y += 0.25 * dir * b
		f.torso.rotation.y = 0.1 * dir * b
	else:
		sh.rotation.x = -(0.55 * b); sh.rotation.z = (0.1 + 0.15 * dir) * b   # 가리키는 팔 — 앞으로 내려가 그림자 쪽으로
		el.rotation.x = -(0.15 * b)
	return true
