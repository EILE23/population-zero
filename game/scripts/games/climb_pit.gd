class_name ClimbPit
extends Node3D
## Climb 콘텐츠 팩 '멀리뛰기 모래밭'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 구름바다(Cloud sea) 층의 min_w 보다 넓은 still 발판 하나 — 걷는 선(PLAYER_Z) 위에 strip_d 깊이의 갈퀴질한 모래 띠가 발판에 sand_h 만큼 돋아 깔리고, 오는 쪽 끝(앞 발판 쪽; 층의 첫 발판은 절벽 가운데 쪽)에 널빤지 구름판이 선다.
## 구름판 위(board_r 안)에서 힘을 끝까지 모아(charge/CHARGE ≥ full_k) 뛴 점프가 도약(flight)이고, 같은 발판의 모래 안에 내리면 plant 자세(뒤꿈치부터, 팔을 앞으로 던지고, 모래에 주저앉았다, 무릎을 털며 일어난다 — 정지화가 아니다)와 함께 구름판에서 x 거리가 기록이다:
## 말뚝(peg)이 그날(day_s — 허들·해시계와 같은 탑의 하루)의 최고 자리에 서고 쉼터 판이 note(n) 으로 읽는다(climb_signs.notes). 상은 없다.
## 짧은 점프·구름판 밖에서 뛴 점프·구름판 위나 모래 끝 너머의 착지는 로더의 평이한 착지 그대로(squash). 단단한 것이 없고 값도 없다: 발판을 그냥 달려 지나는 길은 100% 그대로(평이한 결과 ≥ 40% 규칙).
## 허들(제 걸음의 속도가 가른다)·다이빙 판(널이 던진다)과 다르다: 이건 제 공중 조작이 기록을 가르는 첫 조각 — 힘을 다 모은 점프는 215 px 쯤 날아 발판보다 길므로, 늦게 밀어 모래에 떨어뜨리거나 일찍 밀어 발판 끝을 건다.
## 로더가 할 일(climb.gd, 운영자 세션): `var lj := ClimbPit.new(); add_child(lj); signs.notes.append(lj.note)`; 층을 지을 때 `var tk := cr.plan(n, plats) + mu.plan(n, plats); var pp := cp.plan(n, plats, tk); var bp := ba.plan(n, plats, tk + pp); var lp := ln.plan(n, plats, tk + pp + bp); lj.build(root, lj.plan(n, plats, tk + pp + bp + lp))` (뗏목·버섯·널·열기구·렌즈의 계획을 taken 으로 — 한 발판을 둘이 안 나눈다); 매 틱 `lj.sync(_t)`;
## 모아 뛰는 가지(`elif charge > 0.0:` — `on = {}` 앞)에서 `lj.takeoff(on, x, z, charge / CHARGE)`; 착지(landed 가 있고 was_air, spring 이 아닐 때)에서 `var r := lj.land(landed, x, z); if r["sand"]: fig.pose_request = "plant"`; 그 뒤 `if fig.pose_request == "plant" and PlantPoses.done(fig): fig.pose_request = ""`. 공중·매달림·붙잡음에선 부르지 않는다.
## 몸마다의 상태 st: 비우면 플레이어(팩의 _me — 말뚝에 센다), 다른 몸(리퍼)은 제 사전 {pit, x0, count} 을 준다. 플레이어의 기록은 mark_t 에 남는다(리퍼가 따라 뛴다).
## 주민 반쪽(run 163): 모래밭마다 리퍼 하나(climb_leaper.gd — 모래밭의 노드 아래 Stick3D)가 구름판 뒤에 서서 탑의 1분마다, 그리고 플레이어의 기록 뒤 1.5 s 에 구름판으로 가 다리를 털고(limber, stick3d_limber.gd) 로더의 웅크림으로 힘을 모아 같은 takeoff()/land() 로 뛰어 모래에 내린다(plant — 제 st, 말뚝은 옮기지 않는다),
## 공중에서 플레이어처럼 늦게 밀어(AIR) 모래 안에 내리고 집으로 걸어 돌아와 wheel 로 돌아선다. 로더가 더 할 일은 없다 — build 가 세우고 _process 가 몬다.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_pit.gd

const PACK := "res://data/climb/pit.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_LO := 20.0      # taken 조각이 이 발판의 것인가: y 가 발판 윗면 − BAND_LO 부터 윗면 + BAND_HI 앞까지(run 152 의 띠 규칙)
const BAND_HI := 60.0
const BODY_UP := 50.0      # 선 몸의 키(px) — 상자 위쪽 여유

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.pit
var pits: Array = []            # 지은 모래밭 {id, kind "pit", n, hop_id, hop_kind, cx, x, w, y, y_top, z, d, dir, board_x, sand_x0, sand_x1, best, day, mark_t, node, peg, tap, thump, leaper}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)
var _me := { "pit": "", "x0": 0.0, "count": true }   # 플레이어의 도약 — pit: 구름판에서 뛴 모래밭의 id("" 이면 도약이 아니다), x0: 구름판 x, count: 말뚝에 센다

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("pit", {})

func sync(now: float) -> void:
	t = now

func min_w(n: int) -> float:
	var hi := n >= int(kind.get("high_from", 55))
	return maxf(4.0 * C.HW, float(kind.get("min_w_high" if hi else "min_w", 120.0 if hi else 150.0)))

func margin() -> float:
	return maxf(2.0, float(kind.get("margin", 12.0)))

func board_w() -> float:
	return maxf(4.0, float(kind.get("board_w", 16.0)))

func board_r() -> float:
	return maxf(1.0, float(kind.get("board_r", 12.0)))

func strip_d() -> float:
	return maxf(4.0, float(kind.get("strip_d", 30.0)))

func sand_h() -> float:
	return maxf(0.5, float(kind.get("sand_h", 2.0)))

func full_k() -> float:
	return clampf(float(kind.get("full_k", 0.98)), 0.0, 1.0)

func day_s() -> float:
	return maxf(1.0, float(kind.get("day_s", 600.0)))

func peg_h() -> float:
	return maxf(2.0, float(kind.get("peg_h", 14.0)))

## 탑의 오늘 — 로더의 시계를 day_s 로 나눈 몫
func day() -> int:
	return floori(t / day_s())

## 층 n(테마 층)의 still 발판(조각의 on) 중 min_w 보다 넓고, 띠의 상자(양끝 margin 안쪽 ± 손 하나, 윗면..선 몸)를 다른 발판이 가르지 않고, taken 조각이 띠 안에 없는 것들 중 가장 넓은 것 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	var hops: Array = plats.filter(func(p: Dictionary) -> bool: return not (String(p["kind"]) in ["rest", "short", "ledge"]))
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var kinds: Array = piece.get("on", ["std", "ice"])
		var found: Array = []
		for i in hops.size():
			var p: Dictionary = hops[i]
			if not (String(p["kind"]) in kinds) or float(p["w"]) < min_w(n): continue
			var hx := float(p["x"]); var hw := float(p["w"]); var cx := hx + hw / 2.0; var hy := float(p["y"])
			var x0 := hx + margin() - 10.0; var x1 := hx + hw - margin() + 10.0
			if not _clear(plats, p, x0, x1, hy + 1.0, hy + BODY_UP): continue
			if not _free(taken, x0, x1, hy - BAND_LO, hy + BAND_HI): continue
			# 오는 쪽: 앞 발판(band() 는 오르는 순서로 쌓는다)이 왼쪽이면 왼쪽 끝에 구름판; 층의 첫 발판은 절벽 가운데 쪽에서 온다고 본다(지그재그)
			var from_left := (float((hops[i - 1] as Dictionary)["x"]) + float((hops[i - 1] as Dictionary)["w"]) / 2.0 <= cx) if i > 0 else (cx > C.WORLD_W / 2.0)
			found.append({ "w": hw, "hop_id": String(p["id"]), "hop_kind": String(p["kind"]), "y": hy, "cx": cx, "hx": hx, "dir": 1.0 if from_left else -1.0, "hz": float(p.get("z", C.WALL_Z + C.DEPTH_HALF)), "hd": float(p.get("d", C.DEPTH_HALF * 2.0)) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["w"]) > float(q["w"]) if float(p["w"]) != float(q["w"]) else float(p["y"]) < float(q["y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			var near := float(g["hx"]) + (margin() if float(g["dir"]) > 0.0 else float(g["w"]) - margin())   # 오는 쪽 끝의 안쪽
			var far := float(g["hx"]) + (float(g["w"]) - margin() if float(g["dir"]) > 0.0 else margin())
			s["id"] = "%d.J%d" % [n, i]; s["kind"] = "pit"; s["n"] = n
			s["board_x"] = near + float(g["dir"]) * board_w() / 2.0; s["sand_x0"] = near + float(g["dir"]) * board_w(); s["sand_x1"] = far
			s["x"] = minf(near, far); s["w"] = absf(far - near)
			s["y_top"] = float(g["y"]) + sand_h()   # 모래 윗면 — 다른 팩의 _free 가 읽는 키
			s["z"] = C.PLAYER_Z; s["d"] = strip_d()
			out.append(s)
	return out

## 띠의 상자에 그 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
static func _clear(plats: Array, a: Dictionary, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for pv in plats:
		var p: Dictionary = pv
		if p["id"] == a["id"]: continue
		var py := float(p["y"])
		if py < ylo or py > yhi: continue
		var amp := float(p.get("amp", 0.0))
		var px0 := float(p["x"]) - amp - 10.0; var px1 := float(p["x"]) + float(p["w"]) + amp + 10.0
		if x1 > px0 and x0 < px1: return false
	return true

## 다른 팩의 조각(taken: x, 있으면 w·rail_y·beam_y·y_top)이 띠의 x 와 겹치고 높이 띠 [ylo, yhi) 에 들면 그 발판은 그 팩의 것 — 널은 턱에, 뗏목·뭉치는 틈에 떠 있다
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qtop := qy
		for key in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qtop = maxf(qtop, float(q[key]))
		if x1 > qx0 and x0 < qx1 and qtop >= ylo and qy < yhi: return false
	return true

## 이 발판의 모래밭 — 없으면 빈 사전
func pit_on(on: Dictionary) -> Dictionary:
	var oid := String(on.get("id", ""))
	for pv in pits:
		if String((pv as Dictionary)["hop_id"]) == oid: return pv
	return {}

## 모아 뛰는 틱 — 구름판 위(board_r 안, 걷는 깊이)에서 힘을 끝까지 모았으면(k ≥ full_k) 도약을 적고 true; 아니면 도약을 지우고 false. st 는 몸마다의 상태(점퍼가 제 것을 준다) — 비우면 플레이어의 _me
func takeoff(on: Dictionary, x: float, z: float, k: float, st: Dictionary = {}) -> bool:
	var who := _me if st.is_empty() else st
	who["pit"] = ""
	var p := pit_on(on)
	if p.is_empty() or absf(z - C.PLAYER_Z) >= C.HZ: return false
	if absf(x - float(p["board_x"])) > board_r() or k < full_k(): return false
	who["pit"] = String(p["id"]); who["x0"] = float(p["board_x"])
	_play(p["tap"] as AudioStreamPlayer3D)
	return true

## 착지 틱 — {sand, dist, best}: 도약 중이었고 같은 발판의 모래 안(구름판 너머 .. 모래 끝, 걷는 깊이)에 내렸으면 구름판에서의 거리가 기록(오늘 최고면 말뚝이 옮겨 선다 — count 인 몸만); 어떤 착지든 도약은 끝난다
func land(on: Dictionary, x: float, z: float, st: Dictionary = {}) -> Dictionary:
	var none := { "sand": false, "dist": 0.0, "best": -1.0 }
	var who := _me if st.is_empty() else st
	var fid := String(who.get("pit", "")); who["pit"] = ""
	if fid == "": return none
	var p := pit_on(on)
	if p.is_empty() or String(p["id"]) != fid or absf(z - C.PLAYER_Z) >= C.HZ: return none
	var d := float(p["dir"]); var along := (x - float(p["sand_x0"])) * d
	if along < 0.0 or along > absf(float(p["sand_x1"]) - float(p["sand_x0"])): return none
	var dist := (x - float(p["board_x"])) * d
	if bool(who.get("count", true)):
		if int(p["day"]) != day(): p["day"] = day(); p["best"] = -1.0   # 새 날 — 어제의 말뚝은 뽑힌다
		if dist > float(p["best"]): p["best"] = dist
		p["mark_t"] = t   # 플레이어의 기록 — 리퍼가 REACT 뒤에 따라 뛴다
	_play(p["thump"] as AudioStreamPlayer3D)
	_place(p)
	return { "sand": true, "dist": dist, "best": best_today(p) }

## 오늘의 최고(px) — 없거나 어제 것이면 −1
func best_today(p: Dictionary) -> float:
	return float(p["best"]) if int(p["day"]) == day() else -1.0

## 쉼터 판(n 층)에 붙는 줄 — 위 다섯 층(n..n+4)의 모래밭, 없으면 아래 다섯 층(n−5..n−1), 그것도 없으면 빈 줄. 기록은 m 로(36 px). climb_signs.notes 에 넣는다
func note(n: int) -> String:
	for span in [[n, n + 4], [n - 5, n - 1]]:
		var parts: Array = []
		for pv in pits:
			var p: Dictionary = pv
			if int(p["n"]) < int(span[0]) or int(p["n"]) > int(span[1]): continue
			var b := best_today(p)
			parts.append("floor %d: %s" % [int(p["n"]), "%.1f m today" % (b * C.K) if b >= 0.0 else "no mark today"])
		if parts.size() > 0: return "Long jump, " + "; ".join(parts) + "."
	return ""

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 노드를 지금 자리로(날이 바뀌면 말뚝이 사라진다)
func _process(delta: float) -> void:
	t += delta
	pits = pits.filter(func(p: Dictionary) -> bool: return is_instance_valid(p["node"]))   # 지운 층의 것은 뺀다(climb_hurdle 과 같은 식)
	for pv in pits:
		_place(pv)
		if pv.has("leaper"): (pv["leaper"] as ClimbLeaper).step(delta)   # 리퍼의 틱

## 모래밭을 짓는다 — root 는 그 층의 노드. 노드 원점은 (발판 가운데, 발판 윗면, 절벽); 모래 띠·구름판(강조색 가장자리 선 하나)·갈퀴 줄·말뚝·소리 둘
func build(root: Node3D, planned: Array) -> void:
	var sh := sand_h() * C.K; var sd := strip_d() * C.K; var zz := (C.PLAYER_Z - C.WALL_Z) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var node := Node3D.new(); node.position = C.to3(float(s["cx"]), float(s["y"]), C.WALL_Z * C.K); root.add_child(node)
		var sand := _mat(Color("e9dcc3")); var rake := _mat(Color("d4c3a3")); var wood := _mat(Color("efe9e2")); var acc := _mat(Color("ad7096"))
		var d := float(s["dir"]); var cx := float(s["cx"])
		var sx0 := float(s["sand_x0"]); var sx1 := float(s["sand_x1"]); var slen := absf(sx1 - sx0)
		_box(node, Vector3(slen * C.K, sh, sd), sand).position = Vector3(((sx0 + sx1) / 2.0 - cx) * C.K, sh / 2.0, zz)                       # 모래 띠
		_box(node, Vector3(board_w() * C.K, sh * 1.5, sd), wood).position = Vector3((float(s["board_x"]) - cx) * C.K, sh * 0.75, zz)          # 구름판
		_box(node, Vector3(1.5 * C.K, sh * 1.6, sd), acc).position = Vector3((sx0 - cx) * C.K, sh * 0.8, zz)                                 # 구름판의 모래 쪽 가장자리 — 강조색은 가는 선 하나
		var every := maxf(4.0, float(kind.get("rake_every", 14.0)))
		for i in range(1, int(slen / every) + 1):
			_box(node, Vector3(1.0 * C.K, sh * 0.3, sd * 0.8), rake).position = Vector3((sx0 + d * every * float(i) - cx) * C.K, sh + sh * 0.15, zz)   # 갈퀴 줄
		var peg := _box(node, Vector3(3.0 * C.K, peg_h() * C.K, 3.0 * C.K), acc); peg.position = Vector3(0.0, peg_h() * C.K / 2.0, zz); peg.visible = false
		s["node"] = node; s["peg"] = peg; s["best"] = -1.0; s["day"] = -1; s["mark_t"] = -99.0
		s["tap"] = _snd(node, float(kind.get("tap_hz", 500)), 0.05, -16.0); s["thump"] = _snd(node, float(kind.get("thump_hz", 70)), 0.14, -12.0)
		pits.append(s)
		_place(s)
		s["leaper"] = ClimbLeaper.new(self, s, node)   # 주민 반쪽 — 구름판 뒤에 선 리퍼

## 말뚝은 오늘의 최고 자리에 — 없으면 보이지 않는다
func _place(p: Dictionary) -> void:
	var peg: MeshInstance3D = p["peg"]; var b := best_today(p)
	peg.visible = b >= 0.0
	if b >= 0.0: peg.position.x = (float(p["board_x"]) + float(p["dir"]) * b - float(p["cx"])) * C.K

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _box(parent: Node3D, size: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발판과 같은 규칙 — 그림자는 사람만
	parent.add_child(mi); return mi

func _snd(parent: Node3D, hz: float, secs: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new(); p.stream = _tick_wav(hz, secs); p.volume_db = db; p.unit_size = 6.0; p.max_distance = 30.0
	parent.add_child(p); return p

## 소리 — 짧은 기음이 잦아든다: tap(0.05초, 메마르게 — 구름판이 발밑에서 운다)·thump(0.14초, 낮게 — 뒤꿈치가 모래에 박힌다). 한 번 재생, 반복 없음
static func _tick_wav(hz: float, secs: float) -> AudioStreamWAV:
	var rate := 22050; var n := int(rate * secs)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var k := float(i) / n
		var ph := float(i) * hz * TAU / rate
		var v := (sin(ph) * 0.5 + sin(ph * 2.1) * 0.2) * exp(-k * 7.0)
		data.encode_s16(i * 2, int(v * 22000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = data
	return w
