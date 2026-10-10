class_name ClimbPlank
extends Node3D
## Climb 콘텐츠 팩 '다이빙 판'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 구름바다(Cloud sea) 층의 잇단 두 발판 사이 틈(min_gap..max_gap, 높이차 max_dy 안; 아래 발판은 std·ice, 건너편은 선 발판이면 된다) — 아래 발판의 틈 쪽 턱에 쇠 집게, 그 밑에 코일 스프링, 틈 위로 length 만큼 뻗은 물푸레 널(윗면은 발판 윗면과 같은 높이).
## 널은 바닥이다: 걸어 나가는 건 로더의 걸음 그대로(land 가 떨어지는 몸을 발판처럼 받고, stand 가 매 틱 발밑 높이를 준다 — 끝에 선 몸의 무게로 끝이 sag 만큼 휘고(나간 거리의 제곱, bend_s 에 걸쳐), 끝을 지나 걸으면 떨어진다 off).
## 끝 tip_zone 안에 서면 자세가 bound(다이버의 준비 — 팔을 앞으로, 무릎을 풀고, 널과 같이 출렁인다)가 되고 거기선 SPACE 가 로더의 모아 뛰기가 아니라 널의 것이다: 한 번 누를 때마다 끝이 눌렸다 수평 위로 튀어 오르고(creak),
## 탭은 gap_s 안에 이어져야 하며(늦으면 널이 가라앉아 처음부터) loads 번 뒤의 탭 — 네 번째 — 이 몸을 fling_vy 로 위로, fling_vx 로 건너편 쪽으로 던진다(twang): 빈 널은 snap 만큼 튀어 올라 quiver_s 동안 떨린다.
## 날아가는 동안도 bound 자세(팔을 머리 위로 뻗었다 꼭대기를 지나 접고 착지에 무릎이 깊이 받친다, stick3d_bound.gd); 로더는 BoundPoses.done(fig) 면 자세를 비운다.
## 밀지도, 거절하지도, 값을 받지도 않는다 — 발판에서 틈을 그냥 뛰어 건너는 길은 그대로이고 널의 뿌리 쪽에선 SPACE 도 그대로 모아 뛰기; 널은 끝까지 걸어 나간 몸에게만 있다.
## 로더가 할 일(climb.gd, 운영자 세션): `var cp := ClimbPlank.new(); add_child(cp)`; 층을 지을 때 `cp.build(root, cp.plan(n, plats, cr.plan(n, plats) + mu.plan(n, plats)))` (뗏목·버섯의 계획을 taken 으로 — 한 틈을 둘이 안 나눈다); 매 틱 `cp.sync(_t)`;
## 착지 판정에서 landed 가 비었고 vy <= 0 이면 `landed = cp.land(x, y, ny, z)` (돌려준 사전의 x·w 가 널의 자리, y 가 그 x 의 윗면);
## 서 있을 때 `on["kind"] == "plank"` 면 'move' 발판이 실어 가는 자리에서 `var r := cp.stand(on, x, dt, fig, dir); y = r["y"]; fig.pose_request = "bound" if r["poise"] else ""; if r["off"]: on = {}; apex = y; fig.pose_request = ""`;
## 서 있는 가지에서 jump 가 막 눌렸고(`Input.is_action_just_pressed("jump")`) `cp.poised(on, x)` 면 모으지 말고 `var tp := cp.tap(on, x); charge = 0.0; if tp["fling"]: on = {}; vx = tp["vx"]; vy = tp["vy"]; apex = y; face = signf(vx); fig.pose_request = "bound"` (poised 가 아니면 로더의 모아 뛰기 그대로);
## 착지 뒤 `fig.pose_request == "bound" and BoundPoses.done(fig)` 면 비운다. 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_plank.gd

const PACK := "res://data/climb/plank.json"
const C = preload("res://scripts/games/climb.gd")
const BODY_UP := 70.0      # 널 위에 선 몸의 머리까지(px) — 쓸 상자의 높이
const UNDER := 24.0        # 휜 끝 밑으로 비워 두는 높이(px) — 스프링과 집게
const TAKEN_UP := 220.0    # taken 조각(뗏목·버섯) 위로 비워 두는 높이(px)
const OVER_TIP := 4.0      # 몸의 가운데가 끝을 이만큼 지나면 떨어진다(px) — 발끝이 끝에 걸린 채 한 걸음 더
const BOARD_D := 0.5       # 널의 앞뒤 폭(m)

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.plank
var planks: Array = []          # 지은 널 {id, kind "plank", x, y, w, z, d, edge, tip, dir, a_y, b_y, b_x0, b_x1, a_id, b_id, gap, node, board, creak, twang, load, last_tap, tap_t, fling_t, stood, weight}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("plank", {})

func sync(now: float) -> void:
	t = now

func length() -> float:
	return maxf(20.0, float(kind.get("length", 70.0)))

func sag() -> float:
	return float(kind.get("sag", 18.0))

func tip_zone() -> float:
	return float(kind.get("tip_zone", 24.0))

func loads() -> int:
	return maxi(1, int(kind.get("loads", 3)))

func tap_s() -> float:
	return maxf(0.05, float(kind.get("tap_s", 0.35)))

func gap_s() -> float:
	return maxf(0.1, float(kind.get("gap_s", 0.6)))

func bend_s() -> float:
	return maxf(0.05, float(kind.get("bend_s", 0.25)))

func quiver_s() -> float:
	return maxf(0.1, float(kind.get("quiver_s", 1.0)))

## 몸이 널에서 나간 비 0..1 — 집게에서 0, 끝에서 1
func lever(s: Dictionary, x: float) -> float:
	return clampf((x - float(s["edge"])) * float(s["dir"]) / length(), 0.0, 1.0)

## 지금 탭 수 — 마지막 탭에서 gap_s 가 지나면 널이 가라앉아 0
func load_now(s: Dictionary, at: float) -> int:
	return int(s["load"]) if at - float(s["last_tap"]) <= gap_s() else 0

## 끝의 처짐(px, 위가 +): 선 몸의 무게로 −sag·weight, 탭마다 한 번 눌렸다 수평 위로 튀며 잦아들고, 던진 뒤엔 snap 만큼 튀어 올라 quiver_hz 로 떨며 quiver_s 에 잦아든다
func tip_dy(s: Dictionary, at: float) -> float:
	var dy := -sag() * float(s["weight"])
	var tt := at - float(s["tap_t"])
	if float(s["tap_t"]) > -1.0 and tt >= 0.0 and tt < tap_s():
		var amp := sag() * (0.6 + 0.3 * float(s["load"]))   # 쌓일수록 깊이 눌린다
		dy += -amp * sin(TAU * tt / tap_s()) * (1.0 - tt / tap_s())   # 앞 반은 아래로, 뒤 반은 수평 위로
	var ft := at - float(s["fling_t"])
	if float(s["fling_t"]) > -1.0 and ft >= 0.0 and ft < quiver_s():
		dy += float(kind.get("snap", 12.0)) * sin(TAU * ft * float(kind.get("quiver_hz", 6.0))) * exp(-4.0 * ft)
	return dy

## 몸의 x 에서 널의 윗면(px) — 집게 쪽은 발판 윗면 그대로, 끝으로 갈수록 처짐의 제곱으로 따라간다
func surf(s: Dictionary, x: float, at: float) -> float:
	var l := lever(s, x)
	return float(s["a_y"]) + tip_dy(s, at) * l * l

func _process(delta: float) -> void:
	t += delta
	planks = planks.filter(func(s: Dictionary) -> bool: return is_instance_valid(s["node"]))   # 지운 층의 것은 뺀다(climb_raft 와 같은 식)
	for sv in planks:
		var s: Dictionary = sv
		if t - float(s["stood"]) > float(kind.get("settle_s", 0.12)): s["weight"] = move_toward(float(s["weight"]), 0.0, delta / bend_s())   # 아무도 없으면 펴진다
		_place(s)

## 층 n(테마 층만)의 잇단 두 발판(아래는 조각의 on, 건너편은 far) 중 틈이 min_gap..max_gap 이고 높이차가 max_dy 안이며 널의 상자(턱에서 length + 20, 휜 끝 밑..선 몸)를 다른 발판이 가르지 않고 taken 조각(뗏목·버섯)이 닿지 않는 것들 중 가장 넓은 틈 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var hops := plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var only: Dictionary = piece.get("only", {})
		if not only.is_empty() and not _on(n, only): continue
		var kinds: Array = piece.get("on", ["std"]); var fars: Array = piece.get("far", ["std", "ice", "spring", "crumble"])
		var min_gap := float(kind.get("min_gap", 90.0)); var max_gap := float(kind.get("max_gap", 240.0)); var max_dy := float(kind.get("max_dy", 160.0))
		var spans: Array = []
		for i in range(1, hops.size()):
			var a: Dictionary = hops[i - 1]; var b: Dictionary = hops[i]   # a 가 아래 발판(band() 는 오르는 순서로 쌓는다)
			if not (String(a["kind"]) in kinds and String(b["kind"]) in fars): continue
			if absf(float(b["y"]) - float(a["y"])) > max_dy: continue
			var ax0 := float(a["x"]); var ax1 := ax0 + float(a["w"]); var bx0 := float(b["x"]); var bx1 := bx0 + float(b["w"])
			if bx0 < ax1 and bx1 > ax0: continue   # 겹친 발판 — 틈이 없다
			var dir := 1.0 if bx0 >= ax1 else -1.0
			var gap := bx0 - ax1 if dir > 0.0 else ax0 - bx1
			if gap < min_gap or gap > max_gap: continue
			var edge := ax1 if dir > 0.0 else ax0
			var tip := edge + dir * length()
			var x0 := minf(edge, tip + dir * 20.0); var x1 := maxf(edge, tip + dir * 20.0)
			var ay := float(a["y"])
			if not _clear(plats, a, b, x0, x1, ay - sag() - UNDER, ay + BODY_UP): continue
			if not _free(taken, x0, x1, ay - sag() - UNDER, ay + BODY_UP): continue
			var d := minf(float(a.get("d", C.DEPTH_HALF * 2.0)), float(b.get("d", C.DEPTH_HALF * 2.0)))
			spans.append({ "gap": gap, "edge": edge, "tip": tip, "dir": dir, "d": d, "a_y": ay, "b_y": float(b["y"]), "b_x0": bx0, "b_x1": bx1, "a_id": String(a["id"]), "b_id": String(b["id"]) })
		spans.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["gap"]) > float(q["gap"]) if float(p["gap"]) != float(q["gap"]) else float(p["a_y"]) < float(q["a_y"]))
		for i in range(0, mini(int(piece.get("max", 1)), spans.size())):
			var g: Dictionary = spans[i]
			var s: Dictionary = g.duplicate()
			s["id"] = "%d.P%d" % [n, i]; s["kind"] = "plank"; s["x"] = minf(float(g["edge"]), float(g["tip"])); s["y"] = float(g["a_y"]); s["w"] = length(); s["z"] = C.WALL_Z + float(g["d"]) / 2.0
			out.append(s)
	return out

## 층 n 이 {from, every} 에 드나
static func _on(n: int, rule: Dictionary) -> bool:
	var from := int(rule.get("from", 0))
	return n >= from and (n - from) % maxi(1, int(rule.get("every", 1))) == 0

## 널의 상자(턱..끝 + 20, 휜 끝 밑..선 몸)에 두 발판 말고 다른 발판이 걸리지 않나 — 지름길 판이 틈에 있으면 널이 걸린다
static func _clear(plats: Array, a: Dictionary, b: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"] or p["id"] == b["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var px0 := float(p["x"]) - 10.0; var px1 := float(p["x"]) + float(p["w"]) + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: 뗏목 x·w·y, 버섯 x·y)이 널의 상자에 닿지 않나 — 조각 위 TAKEN_UP 까지 그 조각의 몸
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q["x"]) - 10.0; var qx1 := float(q["x"]) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qy0 := qy - 10.0; var qy1 := qy + TAKEN_UP
		if x1 > qx0 and x0 < qx1 and yhi > qy0 and ylo < qy1: return false
	return true

## 로더의 착지 판정과 같은 규칙(HW·HZ) — 이 틱에 널의 윗면(그 x 의 높이)을 지나 떨어지는 몸만 받고 널(발판 모양 사전, y 는 그 x 의 윗면)을 돌려준다. 집게 쪽으로는 발판이 받으니 끝 쪽 OVER_TIP 까지만
func land(x: float, y: float, ny: float, z: float) -> Dictionary:
	for sv in planks:
		var s: Dictionary = sv
		if absf(z - float(s["z"])) >= float(s["d"]) / 2.0 + C.HZ: continue
		var u := (x - float(s["edge"])) * float(s["dir"])
		if u + C.HW <= 0.0 or u > length() + OVER_TIP: continue
		var sy := surf(s, x, t)
		if y >= sy and ny <= sy:
			var hit := s.duplicate(); hit["y"] = sy
			s["stood"] = t
			return hit
	return {}

## 서 있는 매 틱 — {y, off, poise}: y 는 몸의 x 에서 널의 윗면, off 는 몸이 끝을 지났나(널이 사라졌어도), poise 는 끝 tip_zone 안인가(자세 bound, SPACE 는 널의 것). 무게가 bend_s 에 걸쳐 몸의 자리를 따라간다.
## fig 가 있으면 자세의 메타를 적는다: bound_k 쌓인 탭 0..1, bound_dip 끝의 처짐 −1..1(위가 +, sag 가 1)
func stand(on: Dictionary, x: float, dt: float, fig: Stick3D = null, _walk := 0.0) -> Dictionary:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return { "y": float(on.get("y", 0.0)), "off": true, "poise": false }
	var u := (x - float(s["edge"])) * float(s["dir"])
	var off := u > length() + OVER_TIP
	var l := lever(s, x)
	s["weight"] = move_toward(float(s["weight"]), l * l, dt / bend_s())
	s["stood"] = t
	var poise := not off and u >= length() - tip_zone()
	if fig:
		fig.set_meta("bound_k", float(load_now(s, t)) / float(loads()))
		fig.set_meta("bound_dip", clampf(tip_dy(s, t) / sag(), -1.0, 1.0))
	return { "y": surf(s, x, t), "off": off, "poise": poise }

## 끝 tip_zone 안에 선 몸인가 — 거기선 SPACE 가 널의 것
func poised(on: Dictionary, x: float) -> bool:
	var s := _find(String(on.get("id", "")))
	if s.is_empty(): return false
	var u := (x - float(s["edge"])) * float(s["dir"])
	return u >= length() - tip_zone() and u <= length() + OVER_TIP

## SPACE 한 번 — {took, fling, vx, vy, load}: 끝 tip_zone 밖이면 took 이 거짓(로더의 모아 뛰기 그대로). 안이면 탭을 받는다(creak): gap_s 안에 이어진 탭이 loads 를 넘는 순간 — 네 번째 — 던진다(twang, fling 참, vx 는 건너편 쪽)
func tap(on: Dictionary, x: float) -> Dictionary:
	if not poised(on, x): return { "took": false, "fling": false, "vx": 0.0, "vy": 0.0, "load": 0 }
	var s := _find(String(on.get("id", "")))
	var n := load_now(s, t) + 1
	if n > loads():
		s["load"] = 0; s["last_tap"] = -9.0; s["tap_t"] = -9.0; s["fling_t"] = t; s["weight"] = 0.0; s["stood"] = -9.0
		_play(s["twang"])
		return { "took": true, "fling": true, "vx": float(s["dir"]) * float(kind.get("fling_vx", 300.0)), "vy": float(kind.get("fling_vy", 980.0)), "load": 0 }
	s["load"] = n; s["last_tap"] = t; s["tap_t"] = t
	_play(s["creak"])
	return { "took": true, "fling": false, "vx": 0.0, "vy": 0.0, "load": n }

func _find(id: String) -> Dictionary:
	for sv in planks:
		if String((sv as Dictionary)["id"]) == id: return sv
	return {}

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 널을 짓는다 — root 는 그 층의 노드. 노드 원점은 집게(edge, a_y, z); 턱 위의 쇠 집게와 볼트 둘, 그 밑의 코일 스프링, 집게에서 도는 board 노드 안에 물푸레 널·먹줄 셋·끝의 자주 미끄럼막이, creak, twang
func build(root: Node3D, planned: Array) -> void:
	var L := length() * C.K; var th := maxf(2.0, float(kind.get("thick", 6.0))) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate()
		var dir := float(s["dir"])
		var node := Node3D.new(); node.position = C.to3(float(s["edge"]), float(s["a_y"]), float(s["z"]) * C.K); root.add_child(node)
		var iron := _mat(Color("3a3640")); var ash := _mat(Color("e4cfa6")); var ink := _mat(Color("1b0c15")); var grip := _mat(Color("ad7096"))
		_box(node, Vector3(0.3, 0.12, BOARD_D + 0.1), iron).position = Vector3(-dir * 0.12, -0.06, 0)   # 턱을 무는 집게
		for k in [-1.0, 1.0]: _box(node, Vector3(0.05, 0.05, 0.05), ink).position = Vector3(-dir * 0.12, 0.005, (k as float) * (BOARD_D / 2.0 + 0.02))   # 볼트 둘
		var spring := MeshInstance3D.new(); var sm := CylinderMesh.new(); sm.top_radius = 0.07; sm.bottom_radius = 0.09; sm.height = 0.26; sm.radial_segments = 8; spring.mesh = sm
		spring.material_override = iron; spring.position = Vector3(dir * 0.22, -th - 0.13, 0); spring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(spring)   # 뿌리 밑의 코일 스프링
		var board := Node3D.new(); node.add_child(board)
		_box(board, Vector3(L, th, BOARD_D), ash).position = Vector3(dir * L / 2.0, -th / 2.0, 0)   # 널 — 윗면이 원점 높이
		for i in 3: _box(board, Vector3(0.02, 0.006, BOARD_D), ink).position = Vector3(dir * (L - 0.3 - 0.1 * float(i)), 0.003, 0)   # 끝의 먹줄 셋
		_box(board, Vector3(0.2, 0.008, BOARD_D - 0.08), grip).position = Vector3(dir * (L - 0.1), 0.004, 0)   # 끝의 미끄럼막이
		var creak := AudioStreamPlayer3D.new(); creak.stream = _tick_wav(float(kind.get("creak_hz", 140)), 0.2); creak.volume_db = -8.0; creak.unit_size = 6.0; creak.max_distance = 30.0; node.add_child(creak)
		var twang := AudioStreamPlayer3D.new(); twang.stream = _tick_wav(float(kind.get("twang_hz", 520)), 0.3); twang.volume_db = -6.0; twang.unit_size = 6.0; twang.max_distance = 30.0; node.add_child(twang)
		s["node"] = node; s["board"] = board; s["creak"] = creak; s["twang"] = twang
		s["load"] = 0; s["last_tap"] = -9.0; s["tap_t"] = -9.0; s["fling_t"] = -9.0; s["stood"] = -9.0; s["weight"] = 0.0
		planks.append(s)
		_place(s)

## 널을 지금 처짐으로 — 집게에서 돌아 끝이 tip_dy 만큼 오르내린다(dir 쪽 끝이 내려가려면 그쪽으로 돈다)
func _place(s: Dictionary) -> void:
	(s["board"] as Node3D).rotation.z = float(s["dir"]) * atan2(tip_dy(s, t), length())

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

## 탭·던짐 소리 — 짧은 기음이 빠르게 잦아든다(풍향계의 creak 과 같은 식). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var count := int(rate * secs)
	var data := PackedByteArray(); data.resize(count * 2)
	for i in count:
		var k := float(i) / count
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.3) * 0.2) * exp(-k * 9.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
