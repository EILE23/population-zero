class_name SleevePoses
extends RefCounted
## 소매를 걷는 자세(Climb 팩 drift 의 주민 반쪽 — 파는 이, run 177; 운영자 보드의 '일하는 몸' 시트들, shovel 의 앞): `sleeve` 삽을 잡기 전에 한 손이 다른 팔의 소매를 손목에서 팔꿈치로 밀어 올리고(0.4 s), 손을 바꿔 또 한 번(0.4 s), 두 손으로 깃을 한 번 당겨 바로잡는(0.2 s) 몸 — 몸은 카메라를 보고 선다.
## 시계는 하나고 파는 이(climb_digger.gd)가 적는다: meta "sleeve_t"(자세에 든 뒤 시간). 메타가 없으면 pose_t 로 혼자 한 번 돈다(점검·시연용).
## 오른소매(0..0.4): 왼팔이 앞으로 뻗고(어깨 −0.9, 조금 안으로) 오른손이 몸을 가로질러 왼 손목을 잡아(어깨 −0.9, 안으로 z 0.25) 팔꿈치가 −0.8 에서 −1.5 로 접히며 소매를 밀어 올린다 — 두 번 밀어서(5 Hz 의 잔물결), 고개는 그 팔을 본다
## → 왼소매(0.4..0.8): 거울 → 깃(0.8..1.0): 두 손이 깃으로 올라가(어깨 −1.7, 팔꿈치 −2.3) 두 번 당긴다(10 Hz 의 산 둘, 팔꿈치가 0.2 풀렸다 돈다), 고개가 조금 든다 → 끝에 팔이 내려온다 — 정지화가 아니다(무릎은 늘 0.8 Hz 로 숨쉰다).
## chalk(두 손바닥을 맞부딪쳐 가루를 낸다)·don(모자를 쓴다)·wipe(소매로 닦는다)와 다르다: 이건 소매 자체를 올리는 몸 — 끝나면 바로 shovel 이 온다. stick3d_chalk.gd 처럼 주제별 파일

const ROLL_T := 0.4                       # 한 소매(s)
const COLLAR_T := 0.2                     # 깃 당김(s)
const TOTAL := ROLL_T * 2.0 + COLLAR_T    # 자세 전체(s) — 파는 이가 이만큼 뒤 shovel 로
const BLEND := 0.04                       # 소매에서 소매로·깃으로 넘어가는 반폭(s)
const END := 0.04                         # 끝에 팔이 내려오는 시간(s)
const PUSH_HZ := 5.0                      # 소매를 밀어 올리는 손의 잔물결 — 두 번 민다
const TUG_HZ := 10.0                      # 깃 당김 — 두 번
const BREATHE_HZ := 0.8
const REACH := 0.9                        # 뻗은·가로지른 팔의 어깨 x(rad)
const CROSS := 0.25                       # 가로지른 손의 안쪽 z(rad)
const HOLD := 0.1                         # 소매를 걷히는 팔의 안쪽 z(rad)
const EL_WRIST := 0.8                     # 손목을 잡은 팔꿈치(rad)
const EL_ELBOW := 1.5                     # 팔꿈치까지 밀어 올린 팔꿈치(rad)
const COLLAR_SH := 1.7
const COLLAR_Z := 0.15
const COLLAR_EL := 2.3
const TUG := 0.2                          # 당김에 팔꿈치가 풀리는 폭(rad)

## 자세에 든 뒤 시간(s) — 파는 이의 메타, 없으면 pose_t
static func since(f: Stick3D) -> float:
	if f.has_meta("sleeve_t"): return maxf(0.0, float(f.get_meta("sleeve_t")))
	return f.pose_t

## 다 했나
static func done(f: Stick3D) -> bool:
	return since(f) >= TOTAL

## [a, b, c] — 오른소매·왼소매·깃의 몫(사이는 BLEND 로 섞이고 끝에 END 로 다 내려온다)
static func phases(u: float) -> Array:
	var ta := smoothstep(ROLL_T - BLEND, ROLL_T + BLEND, u)
	var tb := smoothstep(ROLL_T * 2.0 - BLEND, ROLL_T * 2.0 + BLEND, u)
	var te := smoothstep(TOTAL - END, TOTAL, u)
	return [1.0 - ta, ta * (1.0 - tb), tb * (1.0 - te)]

## 소매를 밀어 올린 정도 0..1 — 그 소매의 진행에 두 번의 밀기(잔물결)를 얹는다
static func push(p: float) -> float:
	return clampf(p + 0.06 * sin(p * TAU * 2.0), 0.0, 1.0)

## 깃 당김 0..1 — 깃 동안 두 번의 산
static func tug(u: float) -> float:
	var cu := clampf((u - ROLL_T * 2.0) / COLLAR_T, 0.0, 1.0)
	return 0.5 - 0.5 * cos(cu * TAU * 2.0)

## 상체 — 소매를 보는 동안 조금 숙인다, 깃에 선다
static func lean(f: Stick3D) -> float:
	var ph := phases(since(f))
	return 0.1 * (float(ph[0]) + float(ph[1]))

## 팔다리 — 한 팔은 앞으로 뻗어 소매를 내주고(어깨 −0.9, 안으로 0.1) 다른 팔은 가로질러(어깨 −0.9, 안으로 0.25) 팔꿈치를 −0.8 에서 −1.5 로 접어 소매를 밀어 올린다, 0.4 s 에 바꾼다; 깃엔 두 팔이 깃으로(−1.7, 0.15, −2.3) 두 번 당긴다; 다리는 선 채 무릎이 숨쉰다; 고개는 소매를 보다 깃에 든다
static func limbs(f: Stick3D, s: float) -> bool:
	if f.pose_request != "sleeve": return false
	var hip: Node3D = f.hips[s]; var knee: Node3D = f.knees[s]
	var sh: Node3D = f.shoulders[s]; var el: Node3D = f.elbows[s]
	var u := since(f); var ph := phases(u); var a := float(ph[0]); var b := float(ph[1]); var c := float(ph[2])
	var wk := a if s > 0.0 else b          # 이쪽이 미는 손인 몫 — 오른손이 먼저
	var rl := b if s > 0.0 else a          # 이쪽이 걷히는 팔인 몫
	var p := push(clampf(u / ROLL_T, 0.0, 1.0)) if s > 0.0 else push(clampf((u - ROLL_T) / ROLL_T, 0.0, 1.0))
	var tg := tug(u)
	var breathe := sin(f._t * TAU * BREATHE_HZ) * 0.03   # 무릎의 숨 — 정지화가 아니다
	sh.rotation.x = -REACH * (wk + rl) - COLLAR_SH * c
	sh.rotation.z = -s * (-CROSS * wk + HOLD * rl + COLLAR_Z * c)
	el.rotation.x = -(EL_WRIST + (EL_ELBOW - EL_WRIST) * p) * wk - 0.1 * rl - (COLLAR_EL - TUG * tg) * c
	hip.rotation.x = -0.05 * (wk + rl + c); knee.rotation.x = 0.1 * (wk + rl + c) + breathe
	if s > 0.0: f.neck.rotation.x += 0.35 * (a + b) - 0.15 * c   # 소매를 본다(+), 깃에 조금 든다(−)
	return true
