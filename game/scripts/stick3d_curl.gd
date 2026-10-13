class_name CurlPoses
extends RefCounted
## 튤립 승강기 가족 자세(Climb 콘텐츠 팩 tulip, run 148 — data/climb/tulip.json, scripts/games/climb_tulip.gd; 운영자 보드의 '웅크리기·공처럼 말기' 가족, cling 의 다음): `curl` 꽃잎 속에 말린 채 실려 오르는 몸 —
## 0.4 무릎이 가슴으로 올라오고 골반이 내려앉으며 두 팔이 무릎을 안고 고개가 묻힌다(예비; 접히는 몫은 meta "curl_k" 0..1, 팩이 꽃잎이 닫히는 만큼 적는다 — 없으면 2.4초 주기의 제 박자) → 유지: 줄기가 늘어나는 동안(meta "curl_v" 0/1; 없으면 제 박자) 1.6Hz 로 조금 더 죄었다 푼다(무릎이 가슴에, 골반이 살짝 더, 몸통이 더 말린다)
## → 회수: 꽃잎이 벌어지는 만큼 curl_k 가 0 으로 내려가며 팔이 풀리고 무릎이 내려가고 고개가 들린다; 자세가 비면 stick3d 의 블렌딩이 마저 편다.
## cling(장대를 안고 오른다 — 팔이 머리 위, 무릎이 장대를 죈다)·heave(줄을 당긴다)·ride(선 채 실려 간다)·sky(하늘 보기의 쪼그림)와 다르다: 이건 공처럼 말린 몸, 손이 무릎을 안고 발이 땅에 없다. stick3d_sink.gd 처럼 주제별 파일

const FOLD_T := 0.4
const SQUEEZE_HZ := 1.6
const PERIOD := 2.4

## 자세에 든 정도 0..1
static func k(f: Stick3D) -> float:
	return smoothstep(0.0, FOLD_T, f.pose_t)

## 접힌 몫 0..1 — 팩이 적어 준 값(꽃잎이 닫힌 만큼), 없으면 제 박자(주민·시연용)
static func fold(f: Stick3D) -> float:
	return clampf(float(f.get_meta("curl_k", 0.5 - 0.5 * cos(f._t * TAU / PERIOD))), 0.0, 1.0)

## 줄기가 늘어나는 중 0..1 — 팩이 적어 준 값, 없으면 제 박자(접히는 반 주기)
static func v(f: Stick3D) -> float:
	return clampf(float(f.get_meta("curl_v", 1.0 if sin(f._t * TAU / PERIOD) > 0.0 else 0.0)), 0.0, 1.0)

## 죄는 박자 0..1 — 늘어나는 동안만
static func squeeze(f: Stick3D) -> float:
	return (0.5 + 0.5 * sin(f._t * TAU * SQUEEZE_HZ)) * v(f)

## 골반이 접힌 만큼 내려앉고(무릎을 가슴으로 — 공처럼) 몸통이 앞으로 말린다; 죄는 박자에 조금 더
static func lean(f: Stick3D) -> float:
	var a := k(f) * fold(f); var sq := squeeze(f)
	f.pelvis.position.y = StickRig.HIP_Y - (0.22 + 0.03 * sq) * a
	return (1.1 + 0.15 * sq) * a

## 팔다리 — 무릎이 가슴으로(두 다리가 살짝 엇갈린다), 팔이 무릎을 안고, 고개가 묻힌다; 죄는 박자에 무릎이 조금 더
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "curl": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var a := k(f) * fold(f); var tight := 0.12 * squeeze(f)
	hip.rotation.x = -((1.9 + tight) * a) + 0.05 * s * a
	knee.rotation.x = (2.3 + tight) * a
	sh.rotation.x = -(0.1 + (1.25 + 0.1 * tight) * a); sh.rotation.z = -s * (0.1 - 0.06 * a); el.rotation.x = -(0.4 + 1.3 * a)   # 어깨가 앞으로, 팔꿈치는 깊게 — 무릎을 안는다
	if s > 0.0: f.neck.rotation.x += 0.55 * a
	return true
