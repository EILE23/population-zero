class_name ClimbChime
extends Node3D
## Climb 콘텐츠 팩 '풍경(風磬)'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 공중 정원(Hanging garden) 층의 잇단 두 still 발판 사이 틈(80..220 px) — 위 발판의 틈 쪽 턱에 선 쇠 받침대가 팔을 틈 위로 내밀고, 거기 대나무 통 다섯이 짧은 줄에 걸려 걷는 선 위에 매달린다: 틈을 뛰는 몸이 통 사이를 지난다.
## 통은 그 층의 바람(로더의 wind_of(n))에 흔들린다 — 바람이 없으면 breeze 만큼 숨 쉬고, 180 px/s 면 breeze + wind_sw 까지; 바람이 세면 이따금 한 통이 '띵' 운다. 소리가 클수록 그 층의 바람이 세다 — 연·풍향계 층이 오는 걸 귀로 먼저 안다.
## 공중의 몸이 통을 지나면(brush): 다섯 통이 한꺼번에 울리고 tangle_s 동안 엉켜 흔들리다 잦아들며, 몸은 brush(stick3d_brush.gd — 한 팔을 들어 통을 옆으로 쓸고 고개를 돌리며 어깨가 움츠러들고 무릎이 조금 올라간다, 착지에 고개를 한 번 턴다). rehit_s 안의 같은 몸은 다시 울리지 않는다.
## 단단한 것이 없고 값도 없다: 뜀은 전과 같은 자리에 내린다(100%) — 통은 소리와 움직임만 더한다. 망원경(눈)·해시계(시각)에 이어 탑이 귀에 주는 첫 조각.
## 로더가 할 일(climb.gd, 운영자 세션): `var cw := ClimbChime.new(); add_child(cw)`; 층을 지을 때 `cw.build(root, cw.plan(n, plats, cu.plan(n, plats) + cpl.plan(n, plats) + ctu.plan(n, plats) + cv.plan(n, plats) + chm.plan(n, plats, wind_of(n)) + cz.plan(n, plats) + sd.plan(n, plats, …), wind_of(n)))`
## (통풍구·시소 화분·튤립·덩굴·해먹·집라인·해시계의 계획을 taken 으로 — 한 턱을 둘이 안 나눈다; 넷째 인자는 그 층의 바람 — 흔들림과 띵 소리의 세기); 매 틱 `cw.sync(_t)`;
## 공중인 틱마다(착지 판정 뒤, on 이 비었을 때) `var r := cw.brush(x, y, z, on.is_empty()); if r["brushed"]: fig.pose_request = "brush"` — 착지 뒤 `BrushPoses.done(fig)` 면 자세를 비운다(lurch 와 같은 식; 자세가 바뀌면 착지 회수가 이어지지 않아도 그만이다).
## 주민 반쪽(run 161): 풍경마다 점퍼 하나(climb_jumper.gd — 풍경의 노드 아래 Stick3D)가 아래 발판 먼 끝에 서서 탑의 1분마다 턱으로 달려가 플레이어처럼 힘을 고른 뜀(G·JUMP_MIN..JUMP_V·RUN 은 로더의 수)으로 통 사이를 지나 위 발판에 내리고(같은 brush() — 제 이름 "jumper" 로 제 rehit, 플레이어의 hits 는 그대로),
## wheel 로 돌아서 턱에서 다시 통 사이로 뛰어내려 아래 발판에 내린 뒤 잦아드는 화음을 듣고(hark, stick3d_hark.gd) 집으로 돌아온다 — 1분에 두 번 울린다. 로더가 더 할 일은 없다 — build 가 세우고 _process 가 몬다.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_chime.gd

const PACK := "res://data/climb/chime.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_IN := 20.0      # taken 조각이 이 턱의 것인가: y 가 위 발판 윗면 − BAND_IN 부터 받침대 꼭대기까지(run 152 의 띠 규칙)
const TUBE_Z := -48.0      # 통의 깊이(px) = climb.gd 의 PLAYER_Z(상수식에선 다른 스크립트의 상수를 안 읽는다) — 걷는 선 그대로: 몸이 통 사이를 지나야 운다
const POST_IN := 4.0       # 받침대 기둥이 턱 안쪽으로 선 거리(px)
const WIND_FULL := 180.0   # 이 바람(px/s)에 흔들림이 다 찬다 — wind_of 의 최대 폭

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.chime
var chimes: Array = []          # 지은 풍경 {id, kind "chime", n, x, w, y, y_top, dir, gap, hinge_x, cx, post_x, a_id, b_id, a_y, b_y, a_x, a_w, a_kind, b_x, b_w, wind_k, phase, hit_t, hit_j, hits, rings, tangle_t0, next_tink, tinks, node, pivots, ring, tink, tones, jumper}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("chime", {})

func sync(now: float) -> void:
	t = now

func out() -> float:
	return maxf(C.HW, float(kind.get("out", 22.0)))

func post_h() -> float:
	return maxf(20.0, float(kind.get("post_h", 56.0)))

func string_px() -> float:
	return maxf(2.0, float(kind.get("string", 8.0)))

func pitch() -> float:
	return maxf(3.0, float(kind.get("pitch", 7.0)))

## 다섯 통의 길이(px) — 긴 것부터; 자료에 넷만 있어도 다섯으로 채운다(마지막 길이로)
func tubes() -> Array:
	var raw: Array = kind.get("tubes", [28.0, 24.0, 20.0, 17.0, 14.0])
	var out_len: Array = []
	for i in 5: out_len.append(maxf(4.0, float(raw[mini(i, raw.size() - 1)])))
	return out_len

func tube_r() -> float:
	return maxf(0.5, float(kind.get("tube_r", 1.6)))

## 통 다섯의 x 폭의 반(px) — 가장자리 통의 바깥면까지
func half_span() -> float:
	return pitch() * 2.0 + tube_r()

func body_h() -> float:
	return maxf(10.0, float(kind.get("body_h", 44.0)))

func breeze() -> float:
	return maxf(0.0, float(kind.get("breeze", 0.06)))

func wind_sw() -> float:
	return maxf(0.0, float(kind.get("wind_sw", 0.35)))

func sway_hz() -> float:
	return maxf(0.05, float(kind.get("sway_hz", 0.45)))

func tangle_s() -> float:
	return maxf(0.2, float(kind.get("tangle_s", 2.0)))

func tangle_amp() -> float:
	return maxf(0.0, float(kind.get("tangle_amp", 0.9)))

func rehit_s() -> float:
	return maxf(0.05, float(kind.get("rehit_s", 0.25)))

func ring_s() -> float:
	return maxf(0.2, float(kind.get("ring_s", 1.2)))

func tink_every() -> float:
	return maxf(0.3, float(kind.get("tink_every", 2.4)))

## 다섯 통의 음(Hz) — 긴 통이 낮다
func hzs() -> Array:
	var raw: Array = kind.get("hz", [523.0, 587.0, 659.0, 784.0, 880.0])
	var out_hz: Array = []
	for i in 5: out_hz.append(maxf(80.0, float(raw[mini(i, raw.size() - 1)])))
	return out_hz

## 바람 0..1 — wind_of(px/s, 부호는 방향)를 세기로
func wind_k(wind: float) -> float:
	return clampf(absf(wind) / WIND_FULL, 0.0, 1.0)

## 흔들림의 폭(rad) — 숨 + 바람
func sway(c: Dictionary) -> float:
	return breeze() + wind_sw() * float(c["wind_k"])

## 엉킴 1..0 — 두드린 순간 1, tangle_s 에 걸쳐 0; 두드린 적 없으면 0
func tangle(c: Dictionary, at: float) -> float:
	var t0 := float(c["tangle_t0"])
	if t0 < 0.0 or at < t0: return 0.0
	return 1.0 - clampf((at - t0) / tangle_s(), 0.0, 1.0)

## 통 i 의 각(rad, 틈 평면 안) — 바람의 숨(통마다 어긋난 위상) + 엉킴의 거친 흔들림(통마다 다른 박자라 줄이 엇갈린다)
func tube_angle(c: Dictionary, i: int, at: float) -> float:
	var ph := float(c["phase"])
	var base := sway(c) * sin(TAU * sway_hz() * at + ph + float(i) * 0.6)
	var wild := tangle_amp() * tangle(c, at) * sin(at * (9.0 + float(i) * 1.3) + ph * 2.0 + float(i) * 1.7)
	return base + wild

## 층 n(테마 층만)의 잇단 두 still 발판(조각의 on; 아래 a·위 b) 중 틈이 min_gap..max_gap 이고 b 가 min_dy..max_dy 높으며 턱의 상자를 다른 발판이 가르지 않고 taken 조각이 닿지 않는 짝들 중 가장 넓은 틈 하나. 같은 층·같은 taken 은 늘 같은 답; wind 는 그 층의 wind_of(흔들림의 세기만, 자리는 아니다)
func plan(n: int, plats: Array, taken: Array = [], wind: float = 0.0) -> Array:
	var out_p: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out_p
	var min_gap := float(kind.get("min_gap", 80.0)); var max_gap := float(kind.get("max_gap", 220.0))
	var min_dy := float(kind.get("min_dy", 30.0)); var max_dy := float(kind.get("max_dy", 150.0))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std", "ice"])
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var found: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in kinds): continue
			var dy := float(b["y"]) - float(a["y"])
			if dy < min_dy or dy > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0   # 아래 발판에서 위 발판 쪽
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			if float(b["w"]) < 2.0 * C.HW + POST_IN * 2.0: continue   # 턱에 기둥과 그 곁의 몸이 설 자리
			var hinge := bx0 if dir > 0.0 else bx1   # 위 발판의 틈 쪽 턱
			var cx := hinge - dir * out()
			var x0 := minf(cx - half_span() - 6.0, hinge + dir * 8.0); var x1 := maxf(cx + half_span() + 6.0, hinge + dir * 8.0)
			var top := float(b["y"]) + post_h() + 6.0
			if not _clear(plats, a, b, x0, x1, float(b["y"]) + 1.0, top): continue
			if not _free(taken, x0, x1, float(b["y"]) - BAND_IN, top): continue
			found.append({ "gap": gap, "dir": dir, "hinge_x": hinge, "cx": cx, "post_x": hinge + dir * POST_IN, "x": x0, "w": x1 - x0,
				"a_id": String(a["id"]), "b_id": String(b["id"]), "a_y": float(a["y"]), "b_y": float(b["y"]), "z": float(b.get("z", 0.0)), "d": float(b.get("d", C.DEPTH_HALF * 2.0)),
				"a_x": ax0, "a_w": float(a["w"]), "a_kind": String(a["kind"]), "b_x": bx0, "b_w": float(b["w"]) })   # 두 발판의 자리 — 점퍼의 집·턱·착지 판정
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["b_y"]) < float(q["b_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.W%d" % [n, i]; s["kind"] = "chime"; s["n"] = n
			s["y"] = float(g["b_y"]); s["y_top"] = float(g["b_y"]) + post_h()   # 받침대 꼭대기 — 다른 팩의 _free 가 읽는 키
			s["wind_k"] = wind_k(wind)
			out_p.append(s)
	return out_p

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 턱의 상자(기둥에서 통 너머 손 하나까지, 위 발판 윗면..받침대 꼭대기)에 두 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var amp := float(p.get("amp", 0.0))
		var px0 := float(p["x"]) - amp - 10.0; var px1 := float(p["x"]) + float(p["w"]) + amp + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: x·w·y, 있으면 rail_y·beam_y·y_top 까지의 키)이 이 턱에 들지 않나 — 턱의 x 와 겹치고 조각의 높이 띠가 [ylo, yhi) 와 겹치면 그 턱은 그 팩의 것(위 발판 높이의 통풍구·화분·해시계, 턱까지 닿는 해먹 줄·집라인; 틈 아래 낮게 걸린 것은 아래 틈의 것)
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qtop := qy
		for key in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qtop = maxf(qtop, float(q[key]))
		if x1 > qx0 and x0 < qx1 and qtop >= ylo and qy < yhi: return false
	return true

## 통의 높이 띠(px): [아래 끝, 줄 매듭] — 가장 긴 통이 가장 낮다
func tube_band(c: Dictionary) -> Array:
	var hi := float(c["b_y"]) + post_h() - string_px()
	return [hi - float(tubes()[0]), hi]

## 공중인 틱 — 걷는 깊이에서 몸의 띠(y..y + body_h)와 통의 띠가 겹치고 x 가 통 폭 + 반폭 안이면 두드린다: {brushed, id}. 선 몸은 아니다; rehit_s 안의 같은 몸도 아니다(통 사이에 머무는 동안 매 틱 울리지 않게)
## who 는 몸의 이름 — 비면 플레이어(hit_t, hits — 판에 적힐 기록), "jumper" 면 점퍼(hit_j — 제 rehit; hits 는 그대로). rings 는 둘 다 센다
func brush(x: float, y: float, z: float, airborne: bool, who := "") -> Dictionary:
	var none := { "brushed": false, "id": "" }
	if not airborne: return none
	var key := "hit_t" if who == "" else "hit_j"
	for cv in chimes:
		var c: Dictionary = cv
		if absf(z - TUBE_Z) >= C.HZ + 6.0: continue
		if absf(x - float(c["cx"])) > half_span() + C.HW: continue
		var band := tube_band(c)
		if y >= float(band[1]) or y + body_h() <= float(band[0]): continue
		if t - float(c[key]) < rehit_s(): return none
		c[key] = t; c["tangle_t0"] = t; c["rings"] = int(c["rings"]) + 1
		if who == "": c["hits"] = int(c["hits"]) + 1
		_play(c["ring"])
		return { "brushed": true, "id": String(c["id"]) }
	return none

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 노드를 지금 자리로; 바람이 있으면 이따금 한 통이 운다
func _process(delta: float) -> void:
	t += delta
	chimes = chimes.filter(func(c: Dictionary) -> bool: return is_instance_valid(c["node"]))   # 지운 층의 것은 뺀다(climb_lens 와 같은 식)
	for cv in chimes:
		_place(cv)
		_tink(cv)
		if cv.has("jumper"): (cv["jumper"] as ClimbJumper).step(delta)   # 점퍼의 틱

## 풍경을 짓는다 — root 는 그 층의 노드. 노드 원점은 (기둥, 위 발판 윗면, 걷는 깊이); 쇠 기둥·팔·팔 끝의 매듭(강조색만)·통 다섯(줄·대나무 통·마디)·소리 둘(두드림의 화음, 바람의 띵)·점퍼(Stick3D)
func build(root: Node3D, planned: Array, wind: float = 0.0) -> void:
	var ph := post_h() * C.K; var reach := out() + POST_IN + half_span() + 2.0
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var dir := float(s["dir"])
		var node := Node3D.new(); node.position = C.to3(float(s["post_x"]), float(s["b_y"]), TUBE_Z * C.K); root.add_child(node)
		var iron := _mat(Color("2f2a4e")); var knot := _mat(Color("ad7096")); var cord := _mat(Color("e9e1cf")); var bamboo := _mat(Color("c9b26a")); var joint := _mat(Color("8a7a3e"))
		_box(node, Vector3(1.8 * C.K, ph, 1.8 * C.K), iron).position = Vector3(0.0, ph / 2.0, 0.0)   # 기둥
		_box(node, Vector3(reach * C.K, 1.6 * C.K, 1.6 * C.K), iron).position = Vector3(-dir * reach * C.K / 2.0, ph, 0.0)   # 팔 — 틈 위로
		_box(node, Vector3(2.5 * C.K, 2.5 * C.K, 2.5 * C.K), knot).position = Vector3(-dir * reach * C.K, ph, 0.0)   # 팔 끝의 매듭 — 강조색만
		var pivots: Array = []
		var lens := tubes(); var st := string_px() * C.K
		for i in 5:
			var pv := Node3D.new(); pv.position = Vector3((float(s["cx"]) - float(s["post_x"]) + (float(i) - 2.0) * pitch()) * C.K, ph - 0.8 * C.K, 0.0); node.add_child(pv)
			var ln := float(lens[i]) * C.K
			_box(pv, Vector3(0.5 * C.K, st, 0.5 * C.K), cord).position = Vector3(0.0, -st / 2.0, 0.0)   # 줄
			var tm := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = tube_r() * C.K; cm.bottom_radius = tube_r() * C.K; cm.height = ln; cm.radial_segments = 8
			tm.mesh = cm; tm.material_override = bamboo; tm.position = Vector3(0.0, -(st + ln / 2.0), 0.0); tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; pv.add_child(tm)   # 대나무 통
			_box(pv, Vector3(tube_r() * 2.4 * C.K, 0.8 * C.K, tube_r() * 2.4 * C.K), joint).position = Vector3(0.0, -(st + ln * 0.55), 0.0)   # 마디 — 통마다 다른 높이
			pivots.append(pv)
		s["wind_k"] = wind_k(wind) if wind != 0.0 else float(s.get("wind_k", 0.0))
		s["phase"] = float(int(s["n"])) * 0.37
		s["hit_t"] = -99.0; s["hit_j"] = -99.0; s["hits"] = 0; s["rings"] = 0; s["tangle_t0"] = -99.0
		s["next_tink"] = t + 1.0; s["tinks"] = 0
		s["node"] = node; s["pivots"] = pivots
		s["ring"] = _snd(node, _chord_wav(hzs(), ring_s()), -8.0)
		var tones: Array = []
		for hz in hzs(): tones.append(_tone_wav(float(hz), 0.5))
		s["tones"] = tones
		s["tink"] = _snd(node, tones[0], -28.0 + 16.0 * float(s["wind_k"]))   # 바람이 셀수록 크게 — 귀로 읽는 바람
		s["jumper"] = ClimbJumper.new(self, s, node)   # 주민 반쪽 — 아래 발판 먼 끝에 선 점퍼
		chimes.append(s)
		_place(s)

## 통은 바람과 엉킴대로 흔들린다(틈 평면 안에서, 깊이로도 조금)
func _place(c: Dictionary) -> void:
	var pivots: Array = c["pivots"]
	for i in pivots.size():
		var pv: Node3D = pivots[i]
		var ang := tube_angle(c, i, t)
		pv.rotation.z = ang
		pv.rotation.x = 0.4 * ang * sin(t * 0.7 + float(i))

## 바람의 띵 — wind_k 0.15 아래선 없다; 그 위론 tink_every / wind_k 마다, 통을 바꿔 가며(결정적 — 같은 층은 같은 노래)
func _tink(c: Dictionary) -> void:
	var wk := float(c["wind_k"])
	if wk < 0.15 or t < float(c["next_tink"]): return
	var k := int(c["tinks"]); var tones: Array = c["tones"]
	var p: AudioStreamPlayer3D = c["tink"]
	p.stream = tones[(k * 3) % tones.size()]
	_play(p)
	c["tinks"] = k + 1
	c["next_tink"] = t + tink_every() / wk * (0.7 + 0.6 * fmod(float(k + 1) * 0.618, 1.0))

func _mat(col: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = 1.0
	if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

func _snd(parent: Node3D, w: AudioStreamWAV, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = w; p.volume_db = db; p.unit_size = 6.0; p.max_distance = 40.0
	parent.add_child(p); return p

## 한 통의 소리 — 기음과 둘째 배음이 잦아든다(대나무: 배음이 적다). 한 번 재생, 반복 없음
static func _tone_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.6 + sin(ph * 2.0) * 0.12) * exp(-k * 5.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w

## 다섯 통이 한꺼번에 — 0.05초씩 어긋나 들어와(몸이 차례로 스친다) 함께 잦아든다
static func _chord_wav(hz_list: Array, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var v := 0.0
		for j in hz_list.size():
			var on := float(j) * 0.05 * rate
			if float(i) < on: continue
			var k := (float(i) - on) / count
			var ph := (float(i) - on) * float(hz_list[j]) * TAU / rate
			v += (sin(ph) * 0.6 + sin(ph * 2.0) * 0.12) * exp(-k * 3.5)
		data.encode_s16(i * 2, int(clampf(v * 0.3, -1.0, 1.0) * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
