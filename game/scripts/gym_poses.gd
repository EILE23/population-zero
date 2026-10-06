class_name GymPoses
## 산스장 자세(Mt. Pell 꼭대기, town_mountain) — FightPoses.move 가 이름으로 부른다. a 는 0..1 을 되풀이(한 번 = 한 회)
## 사람도 남의 화면의 나도(poz_net) 같은 자세 — 감정 표현과 같은 길(town_social LOOPS)

## 턱걸이 — 두 팔을 머리 위로 뻗어 봉을 잡고, 팔을 굽혀 몸(골반째)을 끌어올렸다 내린다. 다리는 모아 살짝 굽힌다
static func pullup(f: Stick3D, a: float) -> void:
	var k := 0.5 - 0.5 * cos(a * TAU)
	for s in [-1.0, 1.0]:
		f.shoulders[s].rotation.x = -(3.0 - 0.9 * k); f.shoulders[s].rotation.z = -s * (0.25 + 0.35 * k); f.elbows[s].rotation.x = -(0.15 + 1.6 * k)
		f.hips[s].rotation.x = -0.15; f.knees[s].rotation.x = 0.5
	f.pelvis.position.y = Stick3D.HIP_Y + 0.12 + 0.32 * k; f.neck.rotation.x = -0.25

## 윗몸일으키기 — 매트에 앉아 무릎 세우고, 등을 대고 누웠다(a 0) 일어나 무릎에 가슴(a 0.5). 손은 머리 뒤
static func situp(f: Stick3D, a: float) -> void:
	var k := 0.5 - 0.5 * cos(a * TAU)
	f.pelvis.position.y = 0.14
	for s in [-1.0, 1.0]:
		f.hips[s].rotation.x = -(1.0 + 0.5 * k); f.knees[s].rotation.x = 1.9
		f.shoulders[s].rotation.x = -2.6; f.shoulders[s].rotation.z = -s * 0.9; f.elbows[s].rotation.x = -2.2
	f.torso.rotation.x = -1.35 + 1.6 * k; f.neck.rotation.x = 0.3 * k

## 허리돌리기 — 원판 위에 서서 손잡이를 잡고 골반과 어깨를 반대로 비튼다
static func twist(f: Stick3D, a: float) -> void:
	var w := sin(a * TAU)
	f.pelvis.rotation.y = 0.55 * w; f.torso.rotation.y = -0.75 * w; f.neck.rotation.y = 0.2 * w
	for s in [-1.0, 1.0]:
		f.shoulders[s].rotation.x = -1.25; f.shoulders[s].rotation.z = -s * 0.2; f.elbows[s].rotation.x = -0.5

## 스쿼트 — 팔을 앞으로 뻗으며 엉덩이를 뒤로 빼고 앉았다 선다
static func squat(f: Stick3D, a: float) -> void:
	var k := 0.5 - 0.5 * cos(a * TAU)
	f.pelvis.position.y = Stick3D.HIP_Y - 0.38 * k
	for s in [-1.0, 1.0]:
		f.hips[s].rotation.x = -1.35 * k; f.knees[s].rotation.x = 2.1 * k
		f.shoulders[s].rotation.x = -1.5 * k; f.shoulders[s].rotation.z = -s * 0.1
	f.torso.rotation.x = 0.55 * k; f.neck.rotation.x = -0.35 * k
