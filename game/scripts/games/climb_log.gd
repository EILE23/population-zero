class_name ClimbLog
extends Node3D
## Climb 콘텐츠 팩 '구르는 통나무'(운영자 2026-10-06 밤: "Climb는 컨텐츠 자체의 질과 양을 늘리는 거" — 팩은 data/climb/*.json 자료, 로더는 운영자 세션이 잇는다; climb.gd 는 CI 가 안 건드린다).
## 옛 회관(Old hall) 층의 min_w(150) 이상인 가장 넓은 still 발판 하나 — 한가운데에 느슨한 통나무(길이 length, 반지름 radius)가 절벽과 나란히 누워 있고, 발판 양끝 end_in 안쪽에 쇠 말뚝, 그 사이에 닳은 홈.
## 걸어서 통나무에 닿으면(|x − lx| ≤ radius + MOUNT) 그 위에 올라선다(발밑이 2·radius 오른다); 위에서 걸으면 몸의 x 가 걷는 속도의 slow(0.6)배로 나아가고 통나무가 그만큼 굴러 따라간다(미끄러짐 없이 — 각이 moved / radius 만큼 돈다, 사분의 한 바퀴마다 knock).
## 말뚝에 닿은 통나무는 서고 몸은 제 걸음으로 그 위를 넘어 내려선다(|x − lx| > radius + 2). 위에서 stop_s 동안 서 있으면 엎어진다(spill): 통나무가 마지막으로 돌던 쪽으로 kick 만큼 더 굴러 나가고(kick_s) 몸은 발판으로 내려서 로더가 기존 teeter 를 spill_s 동안 준다; grace_s 안엔 다시 못 올라탄다.
## 점프를 모으는 중(charging)엔 엎어지지 않는다 — 웅크린 몸이 통나무를 누른다(모은 점프를 막지 않는다). settle_s 동안 아무도 안 타면 닳은 홈 가운데로 settle_v 로 되돌아간다. ride_px 이상 간 타기와 엎어짐을 탑의 하루(day_s)마다 세어 쉼터 판이 note(n) 으로 읽는다. 상은 없다.
## 단단한 것이 없고 값도 없다: 통나무를 넘는 맨 점프는 그대로(공중의 몸은 묻지 않는다); 걸음을 멈추지 않는 몸은 늘 건넌다(평이한 결과 100%). 허들(제 걸음의 속도)·외줄(제 박자)과 다르다: 이건 제 발밑이 제 걸음에 굴러가는 첫 바닥. 자세는 log(stick3d_log.gd — 운영자 보드의 '균형' 가족).
## 로더가 할 일(climb.gd, 운영자 세션): `var lg := ClimbLog.new(); add_child(lg); signs.notes.append(lg.note)`; 층을 지을 때 `lg.build(root, lg.plan(n, plats, cb.plan(n, plats) + cr.plan(n, plats, cb.plan(n, plats))))` (종 줄·회전문의 계획을 taken 으로 — 회전문이 선 발판은 비켜 간다); 매 틱 `lg.sync(_t)`;
## 발판에 선 가지의 끝(x 를 옮긴 뒤, _wall_push 뒤 — 허들의 stride 자리)에서 `var r := lg.roll(on, x, z, vx, dt, fig, jump_held); x = r["x"]; y = float(on["y"]) + r["dy"]; if r["spill"]: vx = 0.0; fig.pose_request = "teeter"; _scene_until = now + lg.spill_s(); _scene_dx = 0.0` (teeter 는 _scene_until 이 지나면 비운다);
## `if r["riding"]: fig.pose_request = "log"` (팩이 meta log_v 를 적는다), `elif fig.pose_request == "log": fig.pose_request = ""` (내려서거나 엎어지면 — 팩이 메타를 지운다). 공중(on 이 빈)·매달림·붙잡음에선 부르지 않는다.
## roll 의 st: 비우면 플레이어(팩의 _me — 판에 센다), 다른 몸은 제 사전 {on_id, riding, still, ride, last, count} 을 준다(주민 반쪽이 쓴다).
## 단위는 climb.gd 와 같은 px(36px = 1m, +y 위). 점검은 tools/probe_log.gd

const PACK := "res://data/climb/log.json"
const C = preload("res://scripts/games/climb.gd")
const BAND_LO := 20.0      # taken 조각이 이 발판의 것인가: y 가 발판 윗면 − BAND_LO 부터 윗면 + BAND_HI 앞까지(run 152 의 띠 규칙)
const BAND_HI := 60.0
const BODY_UP := 50.0      # 선 몸의 키(px) — 상자 위쪽 여유
const MOUNT := 4.0         # 통나무 가장자리에서 이만큼 안이면 올라선다(px)
const QUARTER := TAU / 4.0

var pack: Dictionary = {}
var kind: Dictionary = {}       # kinds.log
var logs: Array = []            # 지은 통나무 {id, kind "log", n, hop_id, hop_kind, hop_w, cx, x0, x1, lx, a, y, y_top, z, d, rider_t, spill_t, kick_from, kick_dir, day, rides, spills, node, piv, knock, clonk}
var t := 0.0                    # 로더의 _t 와 같이 간다(sync)
var _me := { "on_id": "", "riding": false, "still": 0.0, "ride": 0.0, "last": 1.0, "count": true }   # 플레이어의 roll 상태 — still: 위에서 선 시간, ride: 이번 타기의 거리, last: 마지막 구른 쪽

func _ready() -> void:
	var f := FileAccess.open(PACK, FileAccess.READ)
	if f: pack = JSON.parse_string(f.get_as_text()) as Dictionary
	kind = (pack.get("kinds", {}) as Dictionary).get("log", {})

func sync(now: float) -> void:
	t = now

func length() -> float:
	return maxf(8.0, float(kind.get("length", 40.0)))

func radius() -> float:
	return maxf(2.0, float(kind.get("radius", 8.0)))

func min_w() -> float:
	return maxf(60.0, float(kind.get("min_w", 150.0)))

func end_in() -> float:
	return maxf(radius(), float(kind.get("end_in", 20.0)))

func slow() -> float:
	return clampf(float(kind.get("slow", 0.6)), 0.1, 1.0)

func stop_s() -> float:
	return maxf(0.05, float(kind.get("stop_s", 0.2)))

func spill_s() -> float:
	return maxf(0.05, float(kind.get("spill_s", 0.4)))

func kick() -> float:
	return maxf(0.0, float(kind.get("kick", 30.0)))

func kick_s() -> float:
	return maxf(0.05, float(kind.get("kick_s", 0.4)))

func grace_s() -> float:
	return maxf(0.0, float(kind.get("grace_s", 0.6)))

func settle_s() -> float:
	return maxf(0.5, float(kind.get("settle_s", 6.0)))

func settle_v() -> float:
	return maxf(1.0, float(kind.get("settle_v", 24.0)))

func ride_px() -> float:
	return maxf(1.0, float(kind.get("ride_px", 40.0)))

func day_s() -> float:
	return maxf(1.0, float(kind.get("day_s", 600.0)))

## 탑의 오늘 — 로더의 시계를 day_s 로 나눈 몫
func day() -> int:
	return floori(t / day_s())

## 층 n(테마 층)의 still 발판(조각의 on) 중 min_w 이상이고, 홈의 상자(말뚝 사이 ± 손 하나, 윗면..선 몸)를 다른 발판이 가르지 않고, taken 조각이 띠 안에 없는 것들 중 가장 넓은 것 하나. 같은 층·같은 taken 은 늘 같은 답
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
			if float(p["w"]) < min_w(): continue
			var x0 := float(p["x"]) + end_in(); var x1 := float(p["x"]) + float(p["w"]) - end_in()
			if not _clear(plats, p, x0 - C.HW, x1 + C.HW, float(p["y"]) + 1.0, float(p["y"]) + BODY_UP): continue
			if not _free(taken, x0 - C.HW, x1 + C.HW, float(p["y"]) - BAND_LO, float(p["y"]) + BAND_HI): continue
			found.append({ "w": float(p["w"]), "hop_id": String(p["id"]), "hop_kind": String(p["kind"]), "y": float(p["y"]), "cx": float(p["x"]) + float(p["w"]) / 2.0, "x0": x0, "x1": x1 })
		found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["w"]) > float(q["w"]) if float(p["w"]) != float(q["w"]) else float(p["y"]) < float(q["y"]))
		for i in range(0, mini(int(piece.get("max", 1)), found.size())):
			var g: Dictionary = found[i]
			var s: Dictionary = g.duplicate(true)
			s["id"] = "%d.L%d" % [n, i]; s["kind"] = "log"; s["n"] = n; s["hop_w"] = float(g["w"])   # 발판 폭 — 주민 반쪽의 집·먼 끝
			s["x"] = float(g["x0"]); s["w"] = float(g["x1"]) - float(g["x0"]); s["lx"] = float(g["cx"])   # 홈의 x·폭, 통나무는 가운데서 시작한다
			s["y_top"] = float(g["y"]) + radius() * 2.0   # 통나무 꼭대기 — 다른 팩의 _free 가 읽는 키
			s["z"] = C.PLAYER_Z; s["d"] = length()        # 걷는 길 위에 누워 있다 — 앞길(허들러의 길)은 비어 있다
			out.append(s)
	return out

## 홈의 상자에 그 발판 말고 다른 발판이 걸리지 않나 — 움직이는 발판은 진폭째
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

## 다른 팩의 조각(taken: x, 있으면 w·rail_y·beam_y·y_top)이 홈의 x 와 겹치고 높이 띠 [ylo, yhi) 에 들면 그 발판은 그 팩의 것 — 회전문은 발판 가운데(y 가 윗면), 종 줄은 틈
static func _free(taken: Array, x0: float, x1: float, ylo: float, yhi: float) -> bool:
	for tv in taken:
		var q: Dictionary = tv
		var qx0 := float(q.get("x", 0.0)) - 10.0; var qx1 := float(q.get("x", 0.0)) + float(q.get("w", 0.0)) + 10.0
		var qy := float(q.get("y", 0.0)); var qtop := qy
		for key in ["rail_y", "beam_y", "y_top"]:
			if q.has(key): qtop = maxf(qtop, float(q[key]))
		if x1 > qx0 and x0 < qx1 and qtop >= ylo and qy < yhi: return false
	return true

## 이 발판의 통나무 — 없으면 빈 사전
func log_on(on: Dictionary) -> Dictionary:
	var oid := String(on.get("id", ""))
	for gv in logs:
		if String((gv as Dictionary)["hop_id"]) == oid: return gv
	return {}

## 선 몸의 매 틱 — {x, dy, riding, spill, mounted}: 통나무 발판이 아니거나 앞길이면 아무것도 아니다; 닿으면 올라선다(x 가 통나무 위로, dy = 2·radius);
## 위에선 vx·dt·slow 만큼 통나무가 구르고 몸이 따라간다(말뚝 사이); 말뚝에 막히면 몸은 로더가 옮긴 제 x 그대로 넘어가 radius + 2 를 지나면 내려선다; vx 0 이 stop_s 이어지면(charging 이 아니면) 엎어진다.
## st 는 몸마다의 상태(주민이 제 것을 준다) — 비우면 플레이어의 _me
func roll(on: Dictionary, x: float, z: float, vx: float, dt: float, fig: Stick3D = null, charging := false, st: Dictionary = {}) -> Dictionary:
	var who := _me if st.is_empty() else st
	var oid := String(on.get("id", ""))
	if oid != String(who["on_id"]): who["on_id"] = oid; who["riding"] = false; who["still"] = 0.0; who["ride"] = 0.0   # 막 내려선 발판
	var g := log_on(on)
	if g.is_empty() or absf(z - float(g["z"])) >= length() / 2.0 + C.HZ: return _off(who, fig, x, false)
	var rr := radius(); var lx := float(g["lx"])
	var mounted := false
	if not bool(who["riding"]):
		if t - float(g["spill_t"]) < grace_s() or absf(x - lx) > rr + MOUNT: return _off(who, fig, x, false)
		who["riding"] = true; who["still"] = 0.0; who["ride"] = 0.0; mounted = true
		x = lx; _play(g["knock"] as AudioStreamPlayer3D)
	g["rider_t"] = t
	var lo := float(g["x0"]) + rr; var hi := float(g["x1"]) - rr
	var moved := clampf(lx + vx * dt * slow(), lo, hi) - lx
	if vx != 0.0 and absf(moved) < 1e-6:   # 말뚝에 막혔다 — 몸이 제 걸음으로 넘어간다(x 는 로더가 옮긴 그대로)
		who["still"] = 0.0
		if absf(x - lx) > rr + 2.0: return _off(who, fig, x, true)
		if fig: fig.set_meta("log_v", clampf(absf(vx) / C.WALK, 0.0, 1.0))
		return { "x": x, "dy": rr * 2.0, "riding": true, "spill": false, "mounted": mounted }
	if absf(moved) > 0.0:
		_turn(g, moved); who["ride"] = float(who["ride"]) + absf(moved); who["last"] = signf(moved); who["still"] = 0.0
		x = float(g["lx"])
	elif not charging:
		who["still"] = float(who["still"]) + dt
		if float(who["still"]) >= stop_s(): return _spill(g, who, fig, x)
	else: x = lx
	if fig: fig.set_meta("log_v", clampf(absf(moved) / maxf(1e-6, C.WALK * slow() * dt), 0.0, 1.0))
	return { "x": x, "dy": rr * 2.0, "riding": true, "spill": false, "mounted": mounted }

## 통나무가 moved 만큼 구른다 — 미끄러짐 없이 각이 따라 돌고, 사분의 한 바퀴를 지날 때마다 돌에 knock
func _turn(g: Dictionary, moved: float) -> void:
	var a0 := float(g["a"]); var a1 := a0 + moved / radius()
	g["lx"] = float(g["lx"]) + moved; g["a"] = a1
	if floori(a0 / QUARTER) != floori(a1 / QUARTER): _play(g["knock"] as AudioStreamPlayer3D)

## 내려섰다(또는 통나무 발판이 아니다) — 타기가 ride_px 이상이면 센다, 자세의 메타를 지운다
func _off(who: Dictionary, fig: Stick3D, x: float, counted: bool) -> Dictionary:
	if bool(who["riding"]) and counted and bool(who.get("count", true)) and float(who["ride"]) >= ride_px(): _tally(who, "rides")
	who["riding"] = false; who["still"] = 0.0; who["ride"] = 0.0
	if fig and fig.has_meta("log_v"): fig.remove_meta("log_v")
	return { "x": x, "dy": 0.0, "riding": false, "spill": false, "mounted": false }

## 엎어진다 — 통나무가 마지막으로 돌던 쪽으로 kick 만큼 굴러 나가고(kick_s, _process 가 옮긴다) 몸은 발판으로; 오늘의 spills 에 센다
func _spill(g: Dictionary, who: Dictionary, fig: Stick3D, x: float) -> Dictionary:
	g["spill_t"] = t; g["kick_from"] = float(g["lx"]); g["kick_dir"] = float(who["last"]); g["kick_a"] = float(g["a"])
	_play(g["clonk"] as AudioStreamPlayer3D)
	if bool(who.get("count", true)): _day(g); g["spills"] = int(g["spills"]) + 1
	var r := _off(who, fig, x, false)
	r["spill"] = true
	return r

## 오늘의 수에 하나 — 날이 바뀌었으면 비우고
func _tally(who: Dictionary, key: String) -> void:
	var g := _by_hop(String(who["on_id"]))
	if g.is_empty(): return
	_day(g); g[key] = int(g[key]) + 1

func _day(g: Dictionary) -> void:
	if int(g["day"]) != day(): g["day"] = day(); g["rides"] = 0; g["spills"] = 0

func _by_hop(hop_id: String) -> Dictionary:
	for gv in logs:
		if String((gv as Dictionary)["hop_id"]) == hop_id: return gv
	return {}

## n0..n1 층의 통나무가 오늘 센 것 — {rides, spills, logs}
func today(n0: int, n1: int) -> Dictionary:
	var rides := 0; var spills := 0; var count := 0
	for gv in logs:
		var g: Dictionary = gv
		if int(g["n"]) < n0 or int(g["n"]) > n1: continue
		count += 1
		if int(g["day"]) == day(): rides += int(g["rides"]); spills += int(g["spills"])
	return { "rides": rides, "spills": spills, "logs": count }

## 쉼터 판(n 층)에 붙는 줄 — 위 다섯 층(n..n+4)의 통나무, 없으면 아래 다섯 층(n−5..n−1), 그것도 없으면 빈 줄. climb_signs.notes 에 넣는다
func note(n: int) -> String:
	for span in [[n, n + 4], [n - 5, n - 1]]:
		var v := today(int(span[0]), int(span[1]))
		if int(v["logs"]) > 0:
			return "Rolling log, floors %d–%d: %s, %s today." % [int(span[0]), int(span[1]), _n(int(v["rides"]), "ride"), _n(int(v["spills"]), "spill")]
	return ""

static func _n(k: int, word: String) -> String:
	return "%d %s" % [k, word if k == 1 else word + "s"]

func _play(p: AudioStreamPlayer3D) -> void:
	if p.playing: p.stop()
	p.play()

## 엎어진 통나무의 굴러 나감과 빈 통나무의 되돌아옴, 그리고 노드를 지금 자리로
func _process(delta: float) -> void:
	t += delta
	logs = logs.filter(func(g: Dictionary) -> bool: return is_instance_valid(g["node"]))   # 지운 층의 것은 뺀다(climb_telescope 와 같은 식)
	for gv in logs:
		var g: Dictionary = gv
		var rr := radius(); var lo := float(g["x0"]) + rr; var hi := float(g["x1"]) - rr
		var since := t - float(g["spill_t"])
		if since >= 0.0 and since <= kick_s():   # 굴러 나감 — 빠르게 떠나 느려진다
			var u := since / kick_s(); var want := clampf(float(g["kick_from"]) + float(g["kick_dir"]) * kick() * (1.0 - (1.0 - u) * (1.0 - u)), lo, hi)
			g["a"] = float(g["kick_a"]) + (want - float(g["kick_from"])) / rr; g["lx"] = want
		elif t - float(g["rider_t"]) > settle_s() and absf(float(g["lx"]) - float(g["cx"])) > 0.01:   # 되돌아옴 — 닳은 홈의 가운데로
			var d := clampf(float(g["cx"]) - float(g["lx"]), -settle_v() * delta, settle_v() * delta)
			g["lx"] = float(g["lx"]) + d; g["a"] = float(g["a"]) + d / rr
		_place(g)

## 통나무를 짓는다 — root 는 그 층의 노드. 노드 원점은 (발판 가운데, 발판 윗면, 절벽); 닳은 홈 하나, 말뚝 둘, 통나무(축 하나 — 껍질 통 + 끈 둘), 소리 둘
func build(root: Node3D, planned: Array) -> void:
	var rr := radius() * C.K; var ln := length() * C.K; var zz := (C.PLAYER_Z - C.WALL_Z) * C.K
	for sv in planned:
		var s: Dictionary = (sv as Dictionary).duplicate(true)
		var node := Node3D.new(); node.position = C.to3(float(s["cx"]), float(s["y"]), C.WALL_Z * C.K); root.add_child(node)
		var bark := _mat(Color("6b4a35")); var worn := _mat(Color("8a7f86")); var iron := _mat(Color("4a4a52")); var cord := _mat(Color("ad7096"))
		var tw := (float(s["x1"]) - float(s["x0"])) * C.K
		_box(node, Vector3(tw, 0.01, ln * 0.8), worn).position = Vector3(0.0, 0.005, zz)   # 닳은 홈 — 통나무가 오간 자리
		for sx: float in [-1.0, 1.0]:
			_box(node, Vector3(0.08, 0.14, ln * 0.5), iron).position = Vector3(sx * (tw / 2.0 + 0.04), 0.07, zz)   # 말뚝 — 홈의 끝에서 통나무를 받는다
		var piv := Node3D.new(); node.add_child(piv)   # 통나무의 축 — x 는 lx, 돌림은 a
		var mi := MeshInstance3D.new(); var cm := CylinderMesh.new()
		cm.top_radius = rr; cm.bottom_radius = rr; cm.height = ln; cm.radial_segments = 10; cm.rings = 1   # 모서리가 보이는 통 — 종이와 잉크의 둥글기
		mi.mesh = cm; mi.material_override = bark; mi.rotation.x = PI / 2.0; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; piv.add_child(mi)
		for sz: float in [-0.3, 0.3]:
			var ring := MeshInstance3D.new(); var rm := CylinderMesh.new()
			rm.top_radius = rr * 1.06; rm.bottom_radius = rr * 1.06; rm.height = 0.05; rm.radial_segments = 10; rm.rings = 1
			ring.mesh = rm; ring.material_override = cord; ring.rotation.x = PI / 2.0; ring.position.z = sz * ln; ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; piv.add_child(ring)   # 끈 — 강조색은 가는 띠 둘
		s["node"] = node; s["piv"] = piv; s["a"] = 0.0
		s["rider_t"] = -99.0; s["spill_t"] = -99.0; s["kick_from"] = float(s["lx"]); s["kick_dir"] = 1.0; s["kick_a"] = 0.0
		s["day"] = -1; s["rides"] = 0; s["spills"] = 0
		s["knock"] = _snd(node, float(kind.get("knock_hz", 110)), 0.05, -16.0); s["clonk"] = _snd(node, float(kind.get("clonk_hz", 70)), 0.15, -12.0)
		logs.append(s)
		_place(s)

## 축을 지금 자리로 — +x 로 구르면 시계 방향(z 축 음의 돌림)
func _place(g: Dictionary) -> void:
	var piv: Node3D = g["piv"]
	piv.position = Vector3((float(g["lx"]) - float(g["cx"])) * C.K, radius() * C.K, (C.PLAYER_Z - C.WALL_Z) * C.K)
	piv.rotation.z = -float(g["a"])

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

## 소리 — 짧은 기음이 잦아든다: knock(0.05초, 낮고 메마르게 — 통나무의 모서리가 돌을 친다)·clonk(0.15초, 더 낮게 — 엎어진 통나무가 굴러 나간다). 한 번 재생, 반복 없음
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
