class_name PerchPoses
extends RefCounted
## 뻐꾸기 발판 가족 자세(Climb 콘텐츠 팩 perch, run 142 — data/climb/perch.json, scripts/games/climb_perch.gd; 운영자 보드의 '문간에 웅크리기' 가족 — 낮은 문간에 선 몸): `perch` 뻐꾸기시계 문간의 널빤지에 선 몸 —
## 0.2 무릎이 굽고 골반이 내려앉으며 두 팔이 옆으로 올라 팔꿈치를 꺾어 문틀을 짚고 고개가 상인방 밑으로 숙는다(예비) → 유지, 팩이 적는 메타로:
## 들어감("perch_in" 0..1, 1 − 널빤지가 나온 정도; 없으면 5.6초 박자의 제 네모파): 안이면 손이 문틀에서 무릎으로 내려오고 더 웅크리며 고개가 더 숙는다 — 문이 닫힌 어둠 속에서 기다리는 몸;
## 부르기("perch_call" 0..1, 문이 열린 뒤 0.5초): 뻐꾸기처럼 고개를 앞으로 내밀고 몸통이 조금 따라간다 — 한 모양으로 굳어 있지 않다(유지 중에도 1Hz 로 숨 쉬듯 흔들리고 0.5Hz 로 고개가 좌우를 살핀다).
## 로더가 널빤지를 떠나면 자세를 비우고 stick3d 의 블렌딩이 몸을 편다(회수). 메타가 없으면 5.6초 한 바퀴의 제 박자(주민·시연용).
## duck(머리를 감싸고 떠는 몸)·tread(띠 위에 선 몸)와 다르다: 이건 낮은 문간에 손을 짚고 웅크려 밖을 내다보는 몸. stick3d_duck.gd 처럼 주제별 파일

const IN_T := 0.2
const BEAT := 5.6
const CROUCH := 0.12      # 골반이 내려앉는 높이(문간) — 안에선 0.2
const IN_DEEP := 0.2

## 들어간 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, IN_T, f.pose_t)

## 안에 있는 정도 0..1 — 메타가 없으면 박자의 뒤 반이 '안'
static func ink(f: Stick3D) -> float:
	if f.has_meta("perch_in"): return clampf(float(f.get_meta("perch_in")), 0.0, 1.0)
	return smoothstep(0.4, 0.6, fposmod(f._t, BEAT) / BEAT)

## 뻐꾸기 부르기 0..1
static func callk(f: Stick3D) -> float:
	if f.has_meta("perch_call"): return clampf(float(f.get_meta("perch_call")), 0.0, 1.0)
	return maxf(0.0, 1.0 - fposmod(f._t, BEAT) / 0.5)

## 골반이 내려앉고(안에선 더) 몸통이 앞으로 숙으며 숨 쉬듯 흔들린다; 부르면 조금 더 앞으로
static func lean(f: Stick3D) -> float:
	var kk := k(f); var i := ink(f); var c := callk(f) * (1.0 - i)
	f.pelvis.position.y = StickRig.HIP_Y - lerpf(CROUCH, IN_DEEP, i) * kk
	return (lerpf(0.3, 0.5, i) + 0.15 * c + 0.02 * sin(f._t * TAU)) * kk

## 팔다리 — 허벅지 앞으로·무릎 접힘(웅크림, 안에선 더), 두 팔은 옆으로 올라 팔꿈치를 꺾어 문틀을 짚는다(안에선 무릎으로 내려온다); 고개는 상인방 밑으로 숙고 좌우를 살피며 부를 땐 앞으로 내민다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "perch": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var kk := k(f); var i := ink(f); var c := callk(f) * (1.0 - i)
	hip.rotation.x = -(lerpf(0.5, 0.9, i) * kk); knee.rotation.x = -(-lerpf(0.9, 1.4, i) * kk)
	sh.rotation.x = -(lerpf(0.3, 0.9, i) * kk); sh.rotation.z = -s * lerpf(1.3, 0.2, i) * kk; el.rotation.x = -((0.3 + lerpf(0.6, 1.1, i) * kk))
	if s > 0.0:
		f.neck.rotation.x += (lerpf(0.45, 0.7, i) - 0.5 * c) * kk
		f.neck.rotation.y += sin(f._t * PI) * 0.3 * kk * (1.0 - i)
	return true
