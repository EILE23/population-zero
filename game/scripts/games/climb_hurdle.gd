class_name ClimbHurdle
extends Node3D
## Climb 콘텐츠 팩 '허들 줄'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 바람 절벽(Wind cliffs) 층의 가장 넓은 still 발판 하나 — 가운데에 낮은 가로대 허들 count 개(h 20 px, spacing 60 px)가 줄지어 선다; 가로대는 절벽 쪽에서 rail_d 만큼만 나와 앞쪽 길은 비어 있다. 좁은 위층(55층부터 발판 96..136 px)은 min_count 개.
## 걸어서 가로대를 지나는 틱(앞 틱의 x 와 지금 x 가 가로대를 사이에 둔다): |vx| ≥ vault_v(RUN 의 0.6)면 넘는다(hurdle — 앞다리가 곧게 앞으로, 뒷다리는 옆으로 펴 접히고, 팔은 반대, 골반이 뜨고, 착지 걸음; 자세의 시계는 시간이 아니라 몸의 x — meta hurdle_k, 가로대 위가 0.5 — 라 다음 가로대의 디딤이 착지에서 이어진다),
## 느리면 부딪힌다(bump): 몸이 가로대 앞 step_back 만큼 물러서고 로더가 기존 teeter 를 bump_s 동안 준다, 가로대는 wobble_s 동안 흔들린다, 아무것도 떨어지지 않는다. 가로대 하나는 탑의 하루(day_s)에 한 번만 센다 — 쉼터 판이 note(n) 으로 읽는다(climb_signs.notes). 상은 없다.
## 단단한 것이 없고 값도 없다: 줄 전체를 한 번에 뛰어넘는 맨 점프는 그대로(공중의 몸은 묻지 않는다); std 발판에선 걷는 속도(260)가 vault_v 보다 빨라 지나는 걸음은 늘 넘고, 얼음 발판에서 막 내디딘 0.7 초 안의 걸음만 부딪힌다(평이한 결과 ≥ 40% 규칙: 넘기가 거의 100%).
## 디딤돌(teeter — 서서 팔만)·다이빙 판(bound — 던져진다)과 다르다: 이건 제 걸음의 속도가 넘느냐 부딪히느냐를 가르는 첫 조각. 자세는 hurdle(stick3d_hurdle.gd — 운영자 보드의 '스포츠' 가족).
## 로더가 할 일(climb.gd, 운영자 세션): `var ch := ClimbHurdle.new(); add_child(ch); signs.notes.append(ch.note)`; 층을 지을 때 `ch.build(root, ch.plan(n, plats, cu.plan(n, plats) + ci.plan(n, plats) + ck.plan(n, plats, wind_of(n))))` (통풍구·고드름·연의 계획을 taken 으로 — 가로대는 통풍구 아래에 서지 않고 고드름 턱·연 자리를 비켜 간다); 매 틱 `ch.sync(_t)`;
## 발판에 선 가지의 끝(x 를 옮긴 뒤, _wall_push 뒤)에서 `var r := ch.stride(on, x, z, vx, fig); x = r["x"]; if r["bump"]: vx = 0.0; fig.pose_request = "teeter"; _scene_until = now + ch.bump_s(); _scene_dx = 0.0` (teeter 는 _scene_until 이 지나면 비운다);
## `if r["in_row"]: fig.pose_request = "hurdle"` (팩이 meta hurdle_k 를 적는다), `elif fig.pose_request == "hurdle": fig.pose_request = ""` (줄을 벗어나거나 멈추면 — 팩이 메타를 지운다). 공중(on 이 빈)·매달림·붙잡음에선 부르지 않는다.
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_hurdle.gd

const PACK := "res://data/climb/hurdle.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_LO := 20.0      # taken 조각이 이 발판의 것인가: y 가 발판 윗면 − BAND_LO 부터 윗면 + BAND_HI 앞까지(run 152 의 띠 규칙)
const BAND_HI := 60.0
const BODY_UP := 50.0      # 선 몸의 키(px) — 상자 위쪽 여유

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.hurdle
var rows: Array = []            # 지은 줄 {id, kind "hurdle", n, hop_id, x, w, y, y_top, z, d, count, rails [x…], days [int…], hits [float…], node, bars [Node3D…], thud, tick}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)
var _px := 0.0                  # 앞 틱의 몸 x — 가로대를 사이에 뒀는지 본다
var _on_id := ""                # 앞 틱의 발판 — 바뀌면 _px 를 새로 잡는다

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("hurdle", {})

func sync(now: float) -> void:
	t = now

func h() -> float:
	return maxf(4.0, float(kind.get("h", 20.0)))

func spacing() -> float:
	return maxf(2.0 * C.HW + 4.0, float(kind.get("spacing", 60.0)))

func count() -> int:
	return maxi(1, int(kind.get("count", 3)))

func min_count() -> int:
	return clampi(int(kind.get("min_count", 2)), 1, count())

func margin() -> float:
	return maxf(C.HW, float(kind.get("margin", 24.0)))

func rail_d() -> float:
	return maxf(4.0, float(kind.get("rail_d", 30.0)))

func vault_v() -> float:
	return maxf(0.0, float(kind.get("vault_v", 180.0)))

func bump_s() -> float:
	return maxf(0.05, float(kind.get("bump_s", 0.4)))

func step_back() -> float:
	return maxf(0.0, float(kind.get("step_back", 12.0)))

func day_s() -> float:
	return maxf(1.0, float(kind.get("day_s", 600.0)))

func wobble_s() -> float:
	return maxf(0.05, float(kind.get("wobble_s", 0.5)))

## 탑의 오늘 — 로더의 시계를 day_s 로 나눈 몫
func day() -> int:
	return floori(t / day_s())

## 줄이 서는 데 필요한 발판 폭(px) — 양끝 margin 과 가로대 사이
func need_w(k: int) -> float:
	return margin() * 2.0 + spacing() * float(k - 1)

## 층 n(테마 층)의 still 발판(조각의 on) 중 count(안 되면 min_count 까지 줄여) 개의 가로대가 서는 폭이고, 줄의 상자(바깥 가로대 ± 손 하나, 윗면..선 몸)를 다른 발판이 가르지 않고, taken 조각이 띠 안에 없는 것들 중 가장 넓은 것 하나. 같은 층·같은 taken 은 늘 같은 답
func plan(n: int, plats: Array, taken: Array = []) -> Array:
	var out: Array = []
	if not (String(C.theme(n)[0]) in (pack.get("themes", []) as Array)): return out
	for pv in (pack.get("pieces", []) as Array):
		var piece: Dictionary = pv
		var kinds: Array = piece.get("on", ["std", "ice"])
		var hops: Array = plats.filter(func(p: Dictionary) -> bool: return String(p["kind"]) in kinds and not (String(p["kind"]) in ["rest", "short", "ledge"]))
		var found: Array = []
		for hv in hops:
			var p: Dictionary = hv
			var k := count()
			while k >= min_count() and float(p["w"]) < need_w(k): k -= 1
			if k < min_count(): continue
			var cx := float(p["x"]) + float(p["w"]) / 2.0
			var x0 := cx - spacing() * float(k - 1) / 2.0 - C.HW - 10.0; var x1 := cx + spacing() * float(k - 1) / 2.0 + C.HW + 10.0
			if not _clear(plats, p, x0, x1, float(p["y"]) + 1.0, float(p["y"]) + BODY_UP): continue
			if not _free(taken, x0, x1, float(p["y"]) - BAND_LO, float(p["y"]) + BAND_HI): continue
			var rails: Array = []
			for i in k: rails.append(cx + spacing() * (float(i) - float(k - 1) / 2.0))
			found.append({ "w": float(p["w"]), "hop_id": String(p["id"]), "y": float(p["y"]), "cx": cx, "count": k, "rails": rails, "hz": float(p.get("z", C.WALL_Z + C.DEPTH_HALF)), "hd": float(p.get("d", C.DEPTH_HALF * 2.0)) })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["w"]) > float(q["w"]) if float(p["w"]) != float(q["w"]) else float(p["y"]) < float(q["y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.H%d" % [n, i]; s["kind"] = "hurdle"; s["n"] = n
			s["x"] = float((g["rails"] as Array)[0]) - C.HW; s["w"] = float((g["rails"] as Array)[int(g["count"]) - 1]) - float((g["rails"] as Array)[0]) + 2.0 * C.HW
			s["y_top"] = float(g["y"]) + h()   # 가로대 윗면 — 다른 팩의 _free 가 읽는 키
			s["z"] = C.WALL_Z + rail_d() / 2.0; s["d"] = rail_d()   # 가로대의 깊이 — 절벽에서 rail_d 까지
			out.append(s)
	return out

## 줄의 상자에 그 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x, 있으면 w·rail_y·beam_y·y_top)이 줄의 x 와 겹치고 높이 띠 [ylo, yhi) 에 들면 그 발판은 그 팩의 것 — 통풍구는 발판 가운데(w 없음), 고드름은 턱 위, 연은 틈
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qtop := qy
		for key in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qtop = maxf(qtop, float(q[key]))
		if x1 > qx0 and x0 < qx1 and qtop >= ylo and qy < yhi: return false
	return true

## 이 발판의 줄 — 없으면 빈 사전
func row_on(on: Dictionary) -> Dictionary:
	var oid := String(on.get("id", ""))
	for rv in rows:
		if String((rv as Dictionary)["hop_id"]) == oid: return rv
	return {}

## 선 몸의 매 틱 — {x, bump, vault, in_row, k, rail}: 앞 틱의 x 와 지금 x 사이에 가로대가 있으면 |vx| ≥ vault_v 에 넘고(vault, 오늘 처음이면 센다) 아니면 부딪혀 물러선다(bump, x 가 바뀐다);
## 줄 안(첫 가로대 − spacing/2 .. 마지막 + spacing/2)에서 속도가 있으면 in_row 와 자리 k(가까운 가로대 위가 0.5)를 돌려주고 fig 의 meta hurdle_k 에 적는다; 벗어나거나 멈추면 메타를 지운다
func stride(on: Dictionary, x: float, z: float, vx: float, fig: Stick3D = null) -> Dictionary:
	var none := { "x": x, "bump": false, "vault": false, "in_row": false, "k": 0.0, "rail": -1 }
	var oid := String(on.get("id", ""))
	if oid != _on_id: _on_id = oid; _px = x   # 막 내려선 발판 — 앞 틱의 자리는 지금 자리
	var r := row_on(on)
	if r.is_empty() or absf(z - float(r["z"])) >= rail_d() / 2.0 + C.HZ:
		_px = x; _leave(fig); return none
	var rails: Array = r["rails"]; var dir := signf(x - _px)
	for i in rails.size():
		var rx := float(rails[i])
		if dir == 0.0 or (_px - rx) * (x - rx) > 0.0: continue   # 가로대를 사이에 두지 않았다
		if absf(vx) >= vault_v():
			_count(r, i); _play(r["tick"] as AudioStreamPlayer3D)
			none["vault"] = true; none["rail"] = i
		else:
			(r["hits"] as Array)[i] = t; _play(r["thud"] as AudioStreamPlayer3D)
			x = rx - dir * (C.HW + 2.0 + step_back())
			_px = x; _leave(fig)
			return { "x": x, "bump": true, "vault": false, "in_row": false, "k": 0.0, "rail": i }
		break
	_px = x
	var lo := float(rails[0]) - spacing() / 2.0; var hi := float(rails[rails.size() - 1]) + spacing() / 2.0
	if absf(vx) < vault_v() or x < lo or x > hi:
		_leave(fig); none["x"] = x; return none
	var near := 0
	for i in rails.size():
		if absf(x - float(rails[i])) < absf(x - float(rails[near])): near = i
	var k := clampf((x - float(rails[near])) * signf(vx) / spacing() + 0.5, 0.0, 1.0)
	if fig: fig.set_meta("hurdle_k", k)
	none["x"] = x; none["in_row"] = true; none["k"] = k
	if int(none["rail"]) < 0: none["rail"] = near
	return none

## 줄을 벗어난 몸 — 자세의 메타를 지운다(로더가 pose_request 를 비운다)
func _leave(fig: Stick3D) -> void:
	if fig and fig.has_meta("hurdle_k"): fig.remove_meta("hurdle_k")

## 가로대 i 를 오늘 처음 넘었으면 센다
func _count(r: Dictionary, i: int) -> void:
	var days: Array = r["days"]
	if int(days[i]) != day(): days[i] = day()

## n0..n1 층의 지은 줄에서 오늘 넘은 가로대 수와 전체 — {done, total}
func vaulted_today(n0: int, n1: int) -> Dictionary:
	var done := 0; var total := 0
	for rv in rows:
		var r: Dictionary = rv
		if int(r["n"]) < n0 or int(r["n"]) > n1: continue
		for dv in (r["days"] as Array):
			total += 1
			if int(dv) == day(): done += 1
	return { "done": done, "total": total }

## 쉼터 판(n 층)에 붙는 줄 — 위 다섯 층(n..n+4)의 줄, 없으면 아래 다섯 층(n−5..n−1)의 줄, 그것도 없으면 빈 줄. climb_signs.notes 에 넣는다
func note(n: int) -> String:
	for span in [[n, n + 4], [n - 5, n - 1]]:
		var v := vaulted_today(int(span[0]), int(span[1]))
		if int(v["total"]) > 0:
			return "Hurdles, floors %d–%d: %d of %d vaulted today." % [int(span[0]), int(span[1]), int(v["done"]), int(v["total"])]
	return ""

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	rows = rows.filter(func(r: Dictionary) -> bool: return is_instance_valid(r["node"]))   # 지운 층의 것은 뺀다(climb_telescope 와 같은 식)
	for rv in rows:
		_place(rv)

## 줄을 짓는다 — root 는 그 층의 노드. 노드 원점은 (발판 가운데, 발판 윗면, 절벽); 가로대마다 두 기둥(절벽 쪽·앞쪽)·발판 둘·가로대(강조색 — 가는 선만)·소리 둘
func build(root: Node3D, planned: Array) -> void:
	var hh := h() * C.K; var rd := rail_d() * C.K; var pt := maxf(1.0, float(kind.get("post", 3.0))) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var node := Node3D.new(); node.position = C.to3(float(s["cx"]), float(s["y"]), C.WALL_Z * C.K); root.add_child(node)
		var wood := _mat(Color("6b4a35")); var bar := _mat(Color("ad7096")); var foot := _mat(Color("4a4a52"))
		var bars: Array = []; var days: Array = []; var hits: Array = []
		for rv in (s["rails"] as Array):
			var piv := Node3D.new(); piv.position = Vector3((float(rv) - float(s["cx"])) * C.K, 0.0, 0.0); node.add_child(piv)   # 발치가 축 — 부딪히면 여기서 흔들린다
			for zz in [pt, rd - pt]:
				_box(piv, Vector3(pt, hh, pt), wood).position = Vector3(0.0, hh / 2.0, zz)                      # 기둥
				_box(piv, Vector3(pt * 3.0, pt * 0.6, pt * 1.4), foot).position = Vector3(0.0, pt * 0.3, zz)    # 발
			_box(piv, Vector3(pt * 0.8, pt * 0.8, rd), bar).position = Vector3(0.0, hh - pt * 0.4, rd / 2.0)   # 가로대 — 강조색은 가는 선 하나
			bars.append(piv); days.append(-1); hits.append(-99.0)
		s["node"] = node; s["bars"] = bars; s["days"] = days; s["hits"] = hits
		s["thud"] = _snd(node, float(kind.get("thud_hz", 90)), 0.12, -14.0); s["tick"] = _snd(node, float(kind.get("tick_hz", 900)), 0.04, -18.0)
		rows.append(s)
		_place(s)

## 부딪힌 가로대는 wobble_s 동안 앞뒤로 흔들리다 선다; 바람 있는 층의 떨림은 없다(가로대는 무겁다)
func _place(r: Dictionary) -> void:
	var bars: Array = r["bars"]; var hits: Array = r["hits"]
	for i in bars.size():
		var since := t - float(hits[i])
		var piv: Node3D = bars[i]
		piv.rotation.x = 0.0 if since < 0.0 or since > wobble_s() else sin(since * 22.0) * 0.18 * (1.0 - since / wobble_s())

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

## 소리 — 짧은 기음이 잦아든다: thud(0.12초, 낮게 — 정강이가 가로대를 친다)·tick(0.04초, 높고 메마르게 — 뒷발이 가로대를 스친다). 한 번 재생, 반복 없음
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
