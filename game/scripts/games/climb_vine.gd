class_name ClimbVine
extends Node3D
## Climb 콘텐츠 팩 '덩굴 커튼'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 공중 정원(Hanging garden) 층의 넓은 선 발판 하나 — 절벽에서 나온 들보가 발판보다 rise 위에서 격자 막대를 받치고, 거기서 덩굴 strands 가닥이 발판 위 hem 까지 늘어져 width 폭의 커튼이 된다(발판 한가운데).
## 발판 위에서 걸어 들어가면 커튼이 두 쪽으로 갈라지고(part_s) 안에 있는 동안 걸음이 slow 로 느려진다(part 자세 — 두 손으로 덩굴을 젖힌다). 위에서 떨어져 들어오면(기둥 안, catch_vy 보다 빠르게) 덩굴이 몸을 받는다:
## sag 만큼 처졌다가(sag_s) catch_s 동안 멈춰 안고, 그다음 slide_v 로 발판까지 미끄러져 내려 세운다 — 부드러운 착지, 찌부(Splat)가 없다. 안겨 있는 동안 SPACE 는 홀드처럼 0.9 로 뛰고 ↓ 는 미끄러지는 속도를 안고 떨어진다. 방금 놓은 커튼은 grace_s 동안 안 받는다.
## 커튼은 발판(≥ min_w)의 가운데 56px 뿐이라 양 끝은 비어 있다 — 보통의 착지와 보통의 점프는 그대로. 밀지도, 떨어뜨리지도, 거절하지도 않는다 — 느린 길과 안전망.
## 로더가 할 일(climb.gd, 운영자 세션): `var cv := ClimbVine.new(); add_child(cv)`; 층을 지을 때 `cv.build(root, cv.plan(n, plats))`; 매 틱 `cv.sync(_t)`;
## 서 있거나 공중인 틱, vx 가 정해진 다음 `x += vx * dt` 앞에서: `var r := cv.part(x, y, z, fig); if not on.is_empty(): vx *= float(r["f"])`; `if r["in"]: fig.pose_request = "part"; PartPoses.hold(fig)` / `elif fig.pose_request == "part" and PartPoses.done(fig): fig.pose_request = ""` (떠난 뒤 0.25초에 걸쳐 팔이 내려온다);
## 공중에서 로더의 착지 판정이 비었고 vy < 0 이면: `var c := cv.catch(x, y, ny, z, vy); if not c.is_empty(): clinging = c; on = {}; vx = 0.0; vy = 0.0; charge = 0.0; apex = y` (clinging 은 로더의 새 사전 — holding 처럼);
## 안긴 매 틱(`_hold` 와 같은 자리, 맨 앞): `var r := cv.cling(clinging, fig); x = r["x"]; y = r["y"]; apex = y; fig.pose_request = "part"; if r["done"] or r["lost"]: clinging = {}; vy = 0.0` (done 틱의 y 는 발판 윗면 — 로더의 착지 판정이 다음 틱에 받는다);
## SPACE 를 놓으면 `var v := cv.let_go(clinging); vy = (JUMP_MIN + (JUMP_V - JUMP_MIN) * (charge / CHARGE)) * 0.9; vx = dir * RUN * 0.9; clinging = {}; 자세 ""`; ↓ 면 `vy = v["vy"]; clinging = {}`.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 자세는 stick3d_part.gd, 점검은 tools/probe_vine.gd

const PACK := "res://data/climb/vine.json"
const C = preload("res://scripts/games/climb.gd")

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.curtain
var curtains: Array = []        # 지은 커튼 {id, kind "vine", x, y, w, z, d, hx, top, bar, hem_y, node, left, right, rustle, want, part, go, cy, held, rider}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("curtain", {})

func sync(now: float) -> void:
	t = now

func width() -> float:
	return float(kind.get("width", 56.0))

func body() -> float:
	return float(kind.get("body", 44.0))

func slow() -> float:
	return clampf(float(kind.get("slow", 0.45)), 0.1, 1.0)

func sag() -> float:
	return float(kind.get("sag", 10.0))

func sag_s() -> float:
	return maxf(0.05, float(kind.get("sag_s", 0.2)))

func catch_s() -> float:
	return maxf(sag_s(), float(kind.get("catch_s", 0.5)))

func slide_v() -> float:
	return maxf(10.0, float(kind.get("slide_v", 90.0)))

func part_s() -> float:
	return maxf(0.05, float(kind.get("part_s", 0.25)))

## 몸(발 y, 키 body)이 커튼 안인가 — 기둥 폭은 커튼 반폭 + 몸 반폭, 높이는 자락 끝부터 막대까지
func inside(s: Dictionary, x: float, y: float, z: float) -> bool:
	if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: return false
	if absf(x - float(s["hx"])) >= width() / 2.0 + C.HW: return false
	return y + body() > float(s["hem_y"]) and y < float(s["bar"])

## 층 n(테마 층만, 조각의 'only' 층만)의 선 발판(조각의 on, min_w 이상) 중 기둥이 막히지 않은 가장 넓은 것 하나 — 그 한가운데에 커튼. 같은 층은 늘 같은 답
func plan(n: int, plats: Array) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"])
		var min_w := float(kind.get("min_w", 140.0)); var rise := float(kind.get("rise", 150.0)); var hem := float(kind.get("hem", 12.0))
		var half := width() / 2.0 + C.HW + 4.0
		var hops: Array = []
		for hv in plats:
			var p: Dictionary = hv
			if not (String(p["kind"]) in kinds) or float(p["w"]) < min_w: continue
			var hx := float(p["x"]) + float(p["w"]) / 2.0
			if not _clear(plats, p, hx - half, hx + half, float(p["y"]) + 1.0, float(p["y"]) + rise): continue
			hops.append(p)
		hops.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["w"]) > float(q["w"]))
		for i in range(0, mini(int(piece.get("max", 1)), hops.size())):
			var p: Dictionary = hops[i]
			var hx := float(p["x"]) + float(p["w"]) / 2.0; var top := float(p["y"])
			var d := float(p.get("d", C.DEPTH_HALF * 2.0))
			out.append({ "id": "%d.v%d" % [n, i], "kind": "vine", "x": hx - width() / 2.0, "y": top, "w": width(), "z": C.WALL_Z + d / 2.0, "d": d,
				"hx": hx, "top": top, "bar": top + rise, "hem_y": top + hem, "hop_id": String(p["id"]) })
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 커튼 기둥(폭 + 몸, 발판 윗면..막대)에 그 발판 말고 다른 발판이 걸리지 않나 — 지름길 판이나 겹쳐 쌓인 턱이 가르면 못 읽는다
static func _clear(plats: Array, hop: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == hop["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var px0 := float(p["x"]) - 10.0; var px1 := float(p["x"]) + float(p["w"]) + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 매 틱 — 몸이 커튼 안이면 갈라지고 {f: slow, in: true}, fig 에 깊이(part_k 0..1, 가운데가 1)를 적는다; 밖이면 {f: 1, in: false}
func part(x: float, y: float, z: float, fig: Stick3D = null) -> Dictionary:
	for sv in curtains:
		var s: Dictionary = sv
		if not inside(s, x, y, z): continue
		s["want"] = t
		if fig: fig.set_meta("part_k", 1.0 - absf(x - float(s["hx"])) / (width() / 2.0 + C.HW))
		return { "f": slow(), "in": true }
	return { "f": 1.0, "in": false }

## 공중에서 떨어지는 몸(vy < catch_vy) — 로더의 착지 판정이 빈 다음: 기둥 안이면 받는다, 돌려주는 사전의 x·y 가 몸의 자리(커튼 가운데, 받힌 높이 cy). 방금 놓은 커튼(grace_s)은 빈 사전
func catch(x: float, y: float, ny: float, z: float, vy: float) -> Dictionary:
	if vy >= float(kind.get("catch_vy", -140.0)): return {}
	for sv in curtains:
		var s: Dictionary = sv
		if not inside(s, x, y, z) or ny <= float(s["top"]): continue
		if t - float(s.get("held", -9.0)) < float(kind.get("grace_s", 0.4)): continue
		s["go"] = t; s["cy"] = y; s["rider"] = true; s["want"] = t
		var hit := s.duplicate(); hit["x"] = float(s["hx"]); hit["y"] = y
		return hit
	return {}

## 안긴 매 틱 — 덩굴 속 몸의 자리 {x, y, done, lost}: sag_s 에 걸쳐 sag 처지고 catch_s 까지 멈춰 있다가 slide_v 로 발판까지 미끄러진다(done — y 는 발판 윗면). fig 가 있으면 자세가 읽을 안김(part_c 0..1)·미끄러짐(part_v −1..0)·깊이(part_k 1)를 적는다
func cling(on: Dictionary, fig: Stick3D = null) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "x": float(on.get("x", 0.0)), "y": float(on.get("y", 0.0)), "done": false, "lost": true }
	var k := t - float(s["go"]); var cy := float(s["cy"]); var top := float(s["top"])
	var y := cy - sag() * smoothstep(0.0, 1.0, k / sag_s())
	var sliding := k >= catch_s()
	if sliding: y = cy - sag() - slide_v() * (k - catch_s())
	var done := y <= top
	if done: y = top; s["rider"] = false
	if fig:
		fig.set_meta("part_c", smoothstep(0.0, 1.0, k / sag_s()))
		fig.set_meta("part_v", -1.0 if (sliding and not done) else 0.0)
		fig.set_meta("part_k", 1.0)
	return { "x": float(s["hx"]), "y": y, "done": done, "lost": false }

## 놓는 순간 덩굴의 속도 {vy} px/s — 미끄러지는 중이면 −slide_v, 안겨 멈춰 있으면 0; 커튼은 grace_s 동안 다시 안 받는다
func let_go(on: Dictionary) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "vy": 0.0 }
	var sliding := t - float(s["go"]) >= catch_s()
	s["rider"] = false; s["held"] = t
	return { "vy": -slide_v() if sliding else 0.0 }

func _find(id: String) -> Dictionary:
	for sv in curtains:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

## 두 쪽을 젖히고 되돌리며(part_s), 가닥이 늘 조금 흔들린다(살아 있는 건 움직인다); 갈라지기 시작하는 틱과 몸을 받는 틱에 rustle. 안긴 몸의 무게로 가닥이 잘게 떨린다
func _process(delta: float) -> void:
	t += delta
	curtains = curtains.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_bell 과 같은 식)
	for sv in curtains:
		var s: Dictionary = sv
		var open := 1.0 if (t - float(s.get("want", -9.0)) < 0.12 and not bool(s.get("rider", false))) else 0.0
		var was := float(s["part"])
		s["part"] = move_toward(was, open, delta / part_s())
		var caught: bool = bool(s.get("rider", false)) and t - float(s.get("go", -9.0)) < delta
		if (was < 0.02 and float(s["part"]) > was) or caught:
			var ru: AudioStreamPlayer3D = s["rustle"]
			if ru.playing: ru.stop()
			ru.play()
		_place(s)

## 커튼을 짓는다 — root 는 그 층의 노드. 노드 원점은 막대 가운데(hx, bar, z); 절벽에서 나온 들보, 격자 막대, 막대에서 늘어진 두 쪽(왼·오른 가닥 묶음 — 각 가닥은 줄기 상자에 잎 둘, 셋에 하나는 꽃), rustle
func build(root: Node3D, planned: Array) -> void:
	var rise := float(kind.get("rise", 150.0)) * C.K; var hem := float(kind.get("hem", 12.0)) * C.K; var w := width() * C.K
	var n := maxi(2, int(kind.get("strands", 7)))
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var node := Node3D.new(); node.position = C.to3(float(s["hx"]), float(s["bar"]), float(s["z"]) * C.K); root.add_child(node)
		var wood := _mat(Color("8a6a4a")); var leaf := _mat(Color("5f8a3e")); var leaf2 := _mat(Color("7fae4e")); var flower := _mat(Color("f2b632"))
		var beam_len := (float(s["z"]) - C.WALL_Z) * C.K + 0.3
		_box(node, Vector3(0.1, 0.1, beam_len), wood).position = Vector3(0, 0.05, -beam_len / 2.0 + 0.1)   # 절벽에서 나온 들보
		var bar_z := (C.PLAYER_Z - 6.0 - float(s["z"])) * C.K   # 가닥은 몸 바로 뒤
		_box(node, Vector3(w + 0.3, 0.07, 0.07), wood).position = Vector3(0, 0, bar_z)   # 격자 막대
		var left := Node3D.new(); left.position = Vector3(0, 0, bar_z); node.add_child(left)
		var right := Node3D.new(); right.position = Vector3(0, 0, bar_z); node.add_child(right)
		for i in n:
			var stem := Node3D.new(); stem.position = Vector3((float(i) - float(n - 1) / 2.0) * (w / float(n - 1)), 0, 0)
			var len := (rise - hem) * (0.92 + 0.08 * float((i * 7) % 3) / 2.0)   # 가닥마다 길이가 조금 다르다 — 픽셀까지 대칭인 건 없다
			_box(stem, Vector3(0.025, len, 0.025), leaf if i % 2 == 0 else leaf2).position = Vector3(0, -len / 2.0, 0)
			_box(stem, Vector3(0.07, 0.03, 0.05), leaf2).position = Vector3(0.035, -len * 0.35, 0.01)
			_box(stem, Vector3(0.07, 0.03, 0.05), leaf).position = Vector3(-0.035, -len * 0.7, -0.01)
			if i % 3 == 1: _box(stem, Vector3(0.05, 0.05, 0.05), flower).position = Vector3(0.02, -len * 0.55, 0.02)
			(left if i % 2 == 0 else right).add_child(stem)
		var rustle := AudioStreamPlayer3D.new(); rustle.stream = _rustle_wav(float(kind.get("vine_hz", 900))); rustle.volume_db = -10.0; rustle.unit_size = 6.0; rustle.max_distance = 30.0; node.add_child(rustle)
		s["node"] = node; s["left"] = left; s["right"] = right; s["rustle"] = rustle; s["want"] = -9.0; s["part"] = 0.0; s["go"] = -9.0; s["cy"] = 0.0; s["held"] = -9.0; s["rider"] = false
		curtains.append(s)
		_place(s)

## 두 쪽의 각 — 젖힌 만큼 바깥으로(막대 축), 늘 조금 흔들리고, 몸을 안았으면 잘게 떤다
func _place(s: Dictionary) -> void:
	var a := float(kind.get("part_a", 0.55)) * float(s["part"])
	var ph := t * 0.9 + float(s["hx"]) * 0.01
	var tremble := sin(t * 12.0) * 0.02 if bool(s.get("rider", false)) else 0.0
	(s["left"] as Node3D).rotation.z = a + sin(ph) * 0.03 + tremble
	(s["right"] as Node3D).rotation.z = -a + sin(ph + 1.0) * 0.03 - tremble

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 잎 스치는 소리 — 0.3초, 씨앗 고정 잡음을 세 칸 평균으로 눅이고(hz 가 낮을수록 더) 빠르게 일어 천천히 잦아든다(한 번 재생, 반복 없음)
static func _rustle_wav(hz: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * 0.3)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var raw := PackedFloat32Array(); raw.resize(count)
	for i in count: raw[i] = rng.randf_range(-1.0, 1.0)
	var taps := maxi(1, int(rate / maxf(200.0, hz)))
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var sum := 0.0
		for j in taps: sum += raw[maxi(0, i - j)]
		var v := (sum / taps) * (1.0 - exp(-k * 60.0)) * exp(-k * 7.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 12000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
