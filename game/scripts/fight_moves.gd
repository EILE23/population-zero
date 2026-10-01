class_name FightMoves
extends RefCounted
## 기술표(운영자 2026-10-01: "두 번째 발차기는 더 세게, Z→X 연계, 더 다양하고 디테일하게, 돌려차기는 훨씬 역동적으로, 점프 공격, 주민 싸움 실력").
## 사람과 주민이 같은 표를 쓴다 — 자세는 FightPoses.move(), 맞히기는 town_combat._strike(사람) · town_critters.resident_hits_player(주민).
## 열쇠: dur 길이(초) · hit 맞는 순간(0..1) · reach 사거리(m) · push 맞은 쪽이 밀리는 속도(m/s) · lift 띄우는 속도 · lunge 내가 앞으로 나가는 속도 ·
## heavy 한 방에 넘어뜨림 · side 쓰는 손발(1 오른, -1 왼) · x / z 이 기술 끝(또는 도중)에 X / Z 를 누르면 이어지는 기술("" 이면 처음부터)
##   주먹: 잽 → 스트레이트 → 훅 → 어퍼컷(띄움)   발: 앞차기 → 밀어차기(깡충, 넘어뜨림) → 360° 돌려차기
##   섞기: 주먹 뒤 Z = 무릎, 발 뒤 X = 돌아 등주먹, 무릎 뒤 X = 훅 / Z = 앞차기, 등주먹 뒤 Z = 돌려차기   공중: X = 내려찍기, Z = 날아차기

const MOVES := {
	"jab":      { "dur": 0.28, "hit": 0.32, "reach": 0.95, "push": 2.0, "lift": 0.0, "lunge": 0.5, "heavy": false, "side": -1.0, "x": "cross", "z": "knee" },
	"cross":    { "dur": 0.32, "hit": 0.34, "reach": 1.0, "push": 2.8, "lift": 0.0, "lunge": 0.8, "heavy": false, "side": 1.0, "x": "hook", "z": "knee" },
	"hook":     { "dur": 0.4, "hit": 0.42, "reach": 0.95, "push": 3.4, "lift": 0.0, "lunge": 0.4, "heavy": false, "side": -1.0, "x": "upper", "z": "round" },
	"upper":    { "dur": 0.46, "hit": 0.4, "reach": 0.9, "push": 1.6, "lift": 5.5, "lunge": 0.5, "heavy": true, "side": 1.0, "x": "", "z": "round" },
	"front":    { "dur": 0.46, "hit": 0.4, "reach": 1.15, "push": 3.2, "lift": 0.0, "lunge": 0.4, "heavy": false, "side": 1.0, "x": "backfist", "z": "push" },
	"push":     { "dur": 0.6, "hit": 0.44, "reach": 1.3, "push": 7.0, "lift": 1.2, "lunge": 2.4, "heavy": true, "side": -1.0, "x": "backfist", "z": "round" },
	"round":    { "dur": 0.78, "hit": 0.42, "reach": 1.4, "push": 6.0, "lift": 2.0, "lunge": 0.9, "heavy": true, "side": 1.0, "x": "", "z": "" },
	"knee":     { "dur": 0.42, "hit": 0.42, "reach": 0.8, "push": 2.6, "lift": 2.6, "lunge": 0.9, "heavy": false, "side": 1.0, "x": "hook", "z": "front" },
	"backfist": { "dur": 0.56, "hit": 0.5, "reach": 1.15, "push": 4.0, "lift": 0.0, "lunge": 0.6, "heavy": false, "side": 1.0, "x": "cross", "z": "round" },
	"fly":      { "dur": 0.55, "hit": 0.36, "reach": 1.3, "push": 6.5, "lift": 1.5, "lunge": 4.5, "heavy": true, "side": 1.0, "x": "", "z": "" },
	"hammer":   { "dur": 0.5, "hit": 0.52, "reach": 1.05, "push": 2.0, "lift": 0.0, "lunge": 0.6, "heavy": true, "side": 1.0, "x": "", "z": "" },
}
const CHAIN_WINDOW := 0.38   # 기술이 끝난 뒤 이만큼 안에 누르면 다음 기술(도중에 누르면 버퍼에 담겼다 끝나자마자)
const BLOCK_T := 0.45
const DODGE_T := 0.35

static func get_move(m: String) -> Dictionary:
	return MOVES.get(m, MOVES["jab"])

static func dur(m: String) -> float:
	return float(get_move(m)["dur"])

## 다음 기술 — 연계 창 안이면 표를 따라, 아니면 처음 기술. 공중이면 공중 기술
static func next_move(last: String, x: bool, chained: bool, grounded: bool) -> String:
	if not grounded: return "hammer" if x else "fly"
	if chained and last != "":
		var n: String = get_move(last)["x" if x else "z"]
		if n != "": return n
	return "jab" if x else "front"

## 주민의 다음 기술 — 싸움 실력(0..1)이 높을수록 연계를 길게 잇고 센 기술을 섞는다. 낮으면 잽·스트레이트만 번갈아
static func resident_pick(last: String, skill: float, chained: bool) -> String:
	if chained and last != "" and randf() < 0.35 + 0.55 * skill:
		var n: String = get_move(last)["x" if randf() < 0.6 else "z"]
		if n != "" and (skill > 0.55 or not (n in ["round", "upper", "backfist", "push"])): return n
	if skill > 0.6 and randf() < 0.35: return ["front", "hook", "knee"][randi() % 3]
	return "jab" if randf() < 0.6 else "cross"
