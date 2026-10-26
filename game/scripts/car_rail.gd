class_name CarRail
extends RefCounted
## 주민 차의 차선 주행(운영자 2026-10-08: "차들이 GTA처럼 주행을 하도록", "차들은 운전 똑바로 안 하잖아") —
## 전엔 경유지 몇 개를 향해 핸들을 꺾고 더듬이로 피했다: 차선 없이 길 가운데로, 모퉁이에선 빙빙, 막히면 후진·비켜 가다 집 사이로 샜다.
## 이제는 골목 격자(남북 x = OX+40i, 동서 z = OZ+20j — 블록 경계와 뒷골목)를 길 그물로 보고:
##   길 찾기: 다익스트라(깎인 땅·차가 설 땅 위 토막만, 강은 다리로만, 옛 마을 안은 큰길만)
##   차선: 오른쪽 통행 — 가운데 줄에서 오른쪽으로 0.8m(큰길 0.9). 모퉁이는 둥글게(반지름 4m 베지어)
##   몰기: 차선 위 앞 3~5m 점을 보고 따라간다(pure pursuit) — 물리 조향·미끄러짐 없이 차선을 그대로 탄다
##   속도: 곧은 길 cruise, 모퉁이 앞에선 미리 줄여 3.5m/s 로 돈다. 앞차(같은 차선 1.1m 안)와 3.4m 띄우고, 앞에 사람이면 선다(4초 넘으면 살살 밀고 간다)
##   교차로: 칸마다 한 대씩 들어간다(같은 축으로 곧장 가는 차끼리는 같이). 6초 넘게 못 들어가면 그냥 간다(막힘 방지)
## 사람이 박아 차선에서 4m 넘게 밀려나거나 3초 넘게 못 가면 그 자리에서 길을 다시 찾는다

const W := 1.2                 # 차선 — 찻길 9m(아스팔트 6.7m)의 가운데에서 1.2m. 0.8 이면 마주 오는 두 차(폭 1.4) 사이가 0.2m 라 스쳐 박혔다
const W_MAIN := 1.0           # 옛 마을 안 큰길(3.6m 판)
static var locks := {}  # Vector2i(노드) -> [{car, axis, straight}]

var centers: Array[Vector3] = []   # 가운데 줄 점(시작·노드…·목적지)
var nodes: Array = []              # centers 와 같은 길이 — 노드면 Vector2i, 아니면 null
var lane: Array[Vector3] = []      # 차선 점
var cap: Array[float] = []         # 그 점의 최고 속도
var node_end: Array[int] = []      # centers k 의 모퉁이가 끝나는 lane 번호
var li := 0
var ni := 1
var done := false
var lost := false                  # 밀려나거나 끼여 길을 놓쳤다(다 온 것과 구분)
var cruise := 7.5
var _held: Variant = null
var _wait_since := -1.0
var _people_since := -1.0
var _stall_since := -1.0
var _ghost_until := -9.0   # 꽉 막힘 풀기 — 차끼리 서로 기다려 20초 넘게 섰으면 4초 동안 차를 지나친다(차 충돌·차 기다림 끔)
var _slow_since := -1.0
var _merge_since := -1.0
var _car_wait := -1.0
var _back_until := -9.0
var _end_wait := -1.0
var _stopped_at: Variant = null    # 멈춤 표지에서 이미 한 번 선 노드
var _stop_t := 0.0
var _backs := 0
var why := ""                      # 점검(probe_rail) — 지금 무엇 때문에 느린가, 왜 길을 잃었나

# ── 길 그물(산골 도시 — Valley.graph: 마디·가지) ──
var _ws: Array[float] = []   # centers 마다 길 폭

## 가지 e 의 투영(점 번호 k 의 토막 위 q)에서 끝 마디(to_b)까지의 점들
static func _to_end(pts: PackedVector2Array, k: int, q: Vector2, to_b: bool) -> PackedVector2Array:
	var out := PackedVector2Array([q])
	if to_b:
		for i in range(k + 1, pts.size()): out.append(pts[i])
	else:
		for i in range(k, -1, -1): out.append(pts[i])
	return out

static func _plen(p: PackedVector2Array) -> float:
	var l := 0.0
	for i in p.size() - 1: l += p[i].distance_to(p[i + 1])
	return l

## 길 짜기 — 차 자리에서 goal 까지(길 그물을 따라). tail = 끝에 붙일 점(장소 가는 길), pull = 길섶에 댈 자리. 못 찾으면 null
static func plan(_t, car: Node3D, goal: Vector3, tail: Array = [], pull := Vector3.INF) -> CarRail:
	var edges: Array = Valley.g_edges(); var adj: Array = Valley.g_adj(); var gn: Array = Valley.g_nodes()
	var p2 := Vector2(car.global_position.x, car.global_position.z); var g2 := Vector2(goal.x, goal.z)
	var s: Array = Valley.near(p2, 2); var g: Array = Valley.near(g2, 3)
	if int(s[4]) < 0 or int(g[4]) < 0: return null
	var es := Valley.edge_of(int(s[4]), int(s[5])); var eg := Valley.edge_of(int(g[4]), int(g[5]))
	if es < 0 or eg < 0: return null
	var E: Dictionary = edges[es]; var G: Dictionary = edges[eg]
	var ks := int(s[5]) - int(E["i0"]); var kg := int(g[5]) - int(G["i0"])
	var path2 := PackedVector2Array(); var widths: Array[float] = []
	var fwd := -car.global_transform.basis.z; var f2 := Vector2(fwd.x, fwd.z)
	if es == eg:   # 같은 가지 — 곧장
		var pts: PackedVector2Array = E["pts"]
		path2 = _to_end(pts, ks, s[1], kg > ks or (kg == ks and (g2 - p2).dot(pts[mini(ks + 1, pts.size() - 1)] - pts[ks]) > 0.0))
		var cut := PackedVector2Array()
		for q in path2:
			cut.append(q)
			if q.distance_to(g[1]) < 3.5: break
		cut.append(g[1]); path2 = cut
		for q in path2: widths.append(float(E["w"]))
	else:
		# 시작: 가지의 두 끝 중 — 앞쪽은 그대로, 뒤쪽은 돌아서야 하니 15m 더
		var dist := {}; var prev := {}; var via := {}
		var ept: PackedVector2Array = E["pts"]
		for to_b in [false, true]:
			var leg := _to_end(ept, ks, s[1], to_b)
			var nd: int = E["b"] if to_b else E["a"]
			var ahead := leg.size() > 1 and (leg[1] - leg[0]).dot(f2) > 0.0
			var c := _plen(leg) + (0.0 if ahead else 15.0)
			if c < float(dist.get(nd, 1e9)): dist[nd] = c; prev[nd] = -1; via[nd] = leg
		var open: Array = dist.keys()
		var seen := {}
		while not open.is_empty():
			var bi := 0
			for i in open.size(): if float(dist[open[i]]) < float(dist[open[bi]]): bi = i
			var u: int = open[bi]; open.remove_at(bi)
			if seen.has(u): continue
			seen[u] = true
			for ei in adj[u]:
				var e: Dictionary = edges[ei]
				var v: int = e["b"] if int(e["a"]) == u else e["a"]
				var nd2 := float(dist[u]) + _plen(e["pts"]) * (0.85 if int(e["road"]) == 0 else 1.0)
				if nd2 < float(dist.get(v, 1e9)):
					dist[v] = nd2; prev[v] = ei
					if not open.has(v): open.append(v)
		var best := -1; var bd := 1e9; var last_leg := PackedVector2Array()
		var gpt: PackedVector2Array = G["pts"]
		for to_b in [false, true]:
			var nd: int = G["b"] if to_b else G["a"]
			if not dist.has(nd): continue
			var leg := _to_end(gpt, kg, g[1], to_b)
			var c := float(dist[nd]) + _plen(leg)
			if c < bd: bd = c; best = nd; last_leg = leg
		if best < 0: return null
		var chain: Array = []   # 마디 거꾸로
		var n := best
		while int(prev.get(n, -1)) >= 0:
			var e: Dictionary = edges[prev[n]]
			var from: int = e["a"] if int(e["b"]) == n else e["b"]
			var pts: PackedVector2Array = e["pts"]
			var seg := pts.duplicate() if int(e["a"]) == from else _rev(pts)
			chain.push_front([seg, float(e["w"])])
			n = from
		var first: PackedVector2Array = via[n]
		for q in first: path2.append(q); widths.append(float(E["w"]))
		for c in chain:
			for q in (c[0] as PackedVector2Array): path2.append(q); widths.append(float(c[1]))
		var lr := _rev(last_leg)
		for q in lr: path2.append(q); widths.append(float(G["w"]))
	var r := CarRail.new(); r.li = 1
	for i in path2.size():
		if not r.centers.is_empty() and Vector2(r.centers[r.centers.size() - 1].x, r.centers[r.centers.size() - 1].z).distance_to(path2[i]) < 0.6: continue
		r.centers.append(Vector3(path2[i].x, 0, path2[i].y)); r.nodes.append(null); r._ws.append(widths[i])
	for q in tail: r.centers.append(Vector3((q as Vector3).x, 0, (q as Vector3).z)); r.nodes.append(null); r._ws.append(5.0)
	if r.centers.size() < 2: return null
	r._build_lane()
	if pull != Vector3.INF and r.lane.size() >= 2:   # 길섶에 댄다 — 차선 끝에서 비스듬히
		var dl := (r.lane[r.lane.size() - 1] - r.lane[r.lane.size() - 2]).normalized()
		r.lane.append(Vector3(pull.x, 0, pull.z) + dl * 1.0); r.cap.append(1.5)
	return r

static var _ngrid := {}; static var _ngrid_ver := -1
static func _node_near(p: Vector2, r := 0.7) -> Array:
	if _ngrid_ver != RoadNet.version:
		_ngrid_ver = RoadNet.version; _ngrid.clear()
		var ns := RoadNet.nodes()
		for i in ns.size():
			var k := Vector2i(floori((ns[i] as Vector2).x / 8.0), floori((ns[i] as Vector2).y / 8.0))
			if not _ngrid.has(k): _ngrid[k] = []
			_ngrid[k].append(i)
	var out: Array = []
	var c := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for i in _ngrid.get(c + Vector2i(dx, dz), []):
				if (RoadNet.nodes()[i] as Vector2).distance_to(p) < r: out.append(i)
	return out

static func _rev(p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(p.size() - 1, -1, -1): out.append(p[i])
	return out

func _right(d: Vector3) -> Vector3: return Vector3(-d.z, 0, d.x)

## 차선 — 가운데 줄에서 오른쪽으로(큰길 1.6m, 골목 1.0m), 꺾이는 만큼 느리게
func _build_lane() -> void:
	# 가운데 줄을 1.5m 로 다시 고르고 모퉁이를 두 번 깎아(Chaikin) 둥글게 — 갈림목에서 꺾일 때 차선이 각지지 않게
	var src: Array[Vector3] = centers.duplicate(); var srcw: Array[float] = _ws.duplicate()
	var pts: Array[Vector3] = []; var ws: Array[float] = []
	for k in src.size() - 1:
		var a := src[k]; var b := src[k + 1]; var n := maxi(1, int(a.distance_to(b) / 1.5))
		for t in n: pts.append(a.lerp(b, float(t) / n)); ws.append(srcw[k])
	pts.append(src[src.size() - 1]); ws.append(srcw[srcw.size() - 1])
	for it in 2:
		var p2: Array[Vector3] = [pts[0]]; var w2: Array[float] = [ws[0]]
		for k in pts.size() - 1:
			p2.append(pts[k].lerp(pts[k + 1], 0.25)); p2.append(pts[k].lerp(pts[k + 1], 0.75)); w2.append(ws[k]); w2.append(ws[k])
		p2.append(pts[pts.size() - 1]); w2.append(ws[ws.size() - 1])
		pts = p2; ws = w2
	centers = pts; _ws = ws
	nodes.clear(); nodes.resize(centers.size())
	var n2 := centers.size()
	for k in n2:
		var a := centers[maxi(k - 1, 0)]; var b := centers[mini(k + 1, n2 - 1)]
		var d := (b - a); d.y = 0.0; d = d.normalized()
		var off := 1.6 if _ws[k] >= 7.0 else 1.0
		lane.append(centers[k] + _right(d) * off)
		var d1 := (centers[k] - centers[maxi(k - 6, 0)]); d1.y = 0.0
		var d2 := (centers[mini(k + 6, n2 - 1)] - centers[k]); d2.y = 0.0
		var turn := acos(clampf(d1.normalized().dot(d2.normalized()), -1.0, 1.0)) if d1.length() > 0.1 and d2.length() > 0.1 else 0.0
		cap.append(clampf(9.0 - turn * 8.0, 2.2, 9.0))   # 앞뒤 4.5m 사이 꺾임만큼
		node_end.append(lane.size() - 1)
		if k > 0 and k < n2 - 1:
			for nd in _node_near(Vector2(centers[k].x, centers[k].z), 1.0):
				if (RoadNet.adj()[nd] as Array).size() >= 3 and (k < 2 or nodes[k - 1] != nd and nodes[k - 2] != nd): nodes[k] = nd
	cap[cap.size() - 1] = 2.0
	done = n2 < 2

static func _seg_of(p: Vector3) -> Array:   # 옛 이름(town_traffic _pull_over) — [가지 끝 둘 대신 쓰지 않음, 쓰지 않음, 길 가운데 점]
	var nr: Array = Valley.near(Vector2(p.x, p.z))
	return [Vector2i.ZERO, Vector2i.ZERO, Vector3((nr[1] as Vector2).x, 0, (nr[1] as Vector2).y)]

# ── 몰기(Car3D._physics_process 가 부른다) ──
func step(car: Car3D, delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var p := car.global_position; p.y = 0.0
	if done or lane.is_empty(): _brake(car, delta); return
	if now < _back_until:   # 박혀서 뒤로 뺀다 — 앞 코를 차선 쪽으로 살짝 돌리며
		car.v = move_toward(car.v, -1.6, 8.0 * delta)
		car.velocity = -car.global_transform.basis.z * car.v + Vector3(0, car._vy, 0)
		car.move_and_slide()
		return
	# 지나간 점은 넘긴다
	while li < lane.size() - 1:   # li = 다음에 닿을 점. 그 점을 0.5m 앞두고 넘긴다
		var seg := lane[li] - (lane[li - 1] if li > 0 else p)
		if p.distance_to(lane[li]) < 1.5 or (seg.length() > 0.01 and (p - lane[li]).dot(seg.normalized()) > -0.5): li += 1
		else: break
	if li >= lane.size() - 1 and p.distance_to(lane[lane.size() - 1]) < 2.0: done = true; _release(car); _brake(car, delta); return
	# 교차로 칸 놓기 — 지나간 노드는 놓아 준다
	while ni < centers.size() and li > node_end[ni]:
		if _held == nodes[ni]: _release(car)
		ni += 1
	# 앞 점(lookahead)
	var look := 2.6 + car.v * 0.3
	var a0 := lane[li - 1] if li > 0 else p
	var ab := lane[li] - a0
	var proj := a0 + ab * clampf((p - a0).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)   # 차선 위 내 자리 — 거기서 look 만큼 앞
	var tgt := lane[li]
	var rem := look - proj.distance_to(lane[li]); var k := li
	if rem < 0.0: tgt = proj + (lane[li] - proj).normalized() * look
	while rem > 0.0 and k < lane.size() - 1:
		var sl := lane[k].distance_to(lane[k + 1])
		if sl >= rem: tgt = lane[k] + (lane[k + 1] - lane[k]).normalized() * rem; break
		rem -= sl; k += 1; tgt = lane[k]
	var to := tgt - p
	var fwd := -car.global_transform.basis.z; fwd.y = 0.0; fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0, fwd.x)
	# 속도: 앞 12m 안의 모퉁이 최고 속도(거리만큼 여유)
	var lim := cruise
	why = ""
	var dsum := p.distance_to(lane[li])
	for q in range(li, mini(li + 14, lane.size())):
		if q > li: dsum += lane[q - 1].distance_to(lane[q])
		if dsum > 16.0: break
		if cap[q] + dsum * 0.55 < lim: lim = cap[q] + dsum * 0.55; why = "corner"
	if li >= lane.size() - 2 and 0.6 + p.distance_to(lane[lane.size() - 1]) * 0.6 < lim: lim = 0.6 + p.distance_to(lane[lane.size() - 1]) * 0.6; why = "end"   # 다 와 간다 — 세울 자리에 맞춰
	# 앞차. 길섶에서 막 나오는 중(첫 토막)이면 둘레 12m 에 달리는 차가 있는 동안 기다린다(8초까지) — 비스듬히 끼어들다 마주 오는 차와 박았다
	var merging := li <= 1 and car.v < 3.0
	if li <= 1 and lim > 2.4: lim = 2.4; why = "pullout"   # 빠져나오는 동안은 천천히
	if merging and _merge_since < 0.0: _merge_since = now
	if why != "cross" and car.v > 0.5: _car_wait = -1.0
	var ghost := now < _ghost_until
	car.collision_mask = 1 if ghost else 3
	for c in ([] if ghost else car.town.cars):
		if c == car: continue
		if merging and now - _merge_since < 8.0 and (c as Car3D).v > 0.5 and (c as Node3D).global_position.distance_squared_to(car.global_position) < 144.0:
			lim = 0.0; why = "merge"; continue
		var tc: Vector3 = c.global_position - car.global_position; tc.y = 0.0
		if tc.length_squared() > 196.0: continue
		var ah := tc.dot(fwd)
		var cf := -(c as Node3D).global_transform.basis.z; cf.y = 0.0
		var moving_rail: bool = (c as Car3D).rail != null and not (c as Car3D).rail.done
		if moving_rail and cf.normalized().dot(fwd) < 0.5:   # 가로지르는·마주 오는 차 — 바로 코앞(4m, 차 폭 안)일 때만 선다(멀면 교차로 칸이 맡는다)
			var head_on := cf.normalized().dot(fwd) < -0.7   # 마주 오는 차는 내 차선 한가운데일 때만(굽은 골목에서 비켜 지나갈 차 앞에 서서 출근길의 열여섯이 갔다)
			if ah > 0.0 and ah < 4.2 and absf(tc.dot(right)) < (0.9 if head_on else 1.5):
				lim = 0.0; why = "cross"
				if _car_wait < 0.0: _car_wait = now
				elif now - _car_wait > 5.0 and (car.get_instance_id() < c.get_instance_id() or now - _car_wait > 11.0):   # 맞물렸다 — 한쪽(번호 작은 쪽)이 물러난다. 그쪽이 안 물러나면(저쪽은 기다리는 게 아니라 끼었다) 11초에 이쪽도
					_back_until = now + 1.4; _car_wait = -1.0
			continue
		if ah > 0.0 and absf(tc.dot(right)) < 1.15 and (ah - 3.4) * 1.1 < lim: lim = maxf(0.0, (ah - 3.4) * 1.1); why = "car:%s" % (c as Car3D).kind
	if why.begins_with("car") and li >= lane.size() - 2 and car.v < 0.3:   # 다 와서 세운 차에 막혔다 — 여기 댄다
		if _end_wait < 0.0: _end_wait = now
		elif now - _end_wait > 5.0: done = true; _release(car); return
	else: _end_wait = -1.0
	# 사람(주민·나) — 앞 4.5m, 차선 폭 안
	var person := false
	var who: Resident = null; var who_side := 1.0
	for r in car.town.residents:
		if r == car.driver or r.state == "drive" or not r.visible: continue   # 일터 안(안 보이는) 주민은 길에 없다
		var tr: Vector3 = r.global_position - car.global_position; tr.y = 0.0
		if tr.length_squared() > 30.0: continue
		var ah := tr.dot(fwd)
		if ah > 0.0 and ah < 4.5 and absf(tr.dot(right)) < 1.35:   # 차 폭(1.4)만큼 — 옆구리로 사람을 긁고 섰다
			person = true; who = r; who_side = 1.0 if tr.dot(right) >= 0.0 else -1.0
	if car.town.driving != car and car.town.body.visible:
		var tb: Vector3 = car.town.body.global_position - car.global_position; tb.y = 0.0
		var ahb := tb.dot(fwd)
		if ahb > 0.0 and ahb < 4.5 and absf(tb.dot(right)) < 1.35: person = true
	if person:
		why = "person"
		if _people_since < 0.0: _people_since = now
		lim = minf(lim, 0.0 if now - _people_since < 2.5 else 0.8)   # 섰다가, 오래 안 비키면 살살(밀며) 간다
		if who and now - _people_since > 0.8 and who.state == "walk" and now > float(who.get_meta("yield_until", 0.0)):   # 걷던 사람은 길섶으로 한 발 비킨다(출근길 시간의 열에 하나가 사람 앞에서 섰다, 2026-10-26)
			who.set_meta("yield_until", now + 4.0)
			var side_pt: Vector3 = who.global_position + right * who_side * 2.4; side_pt.y = 0.0
			who.route.push_front({ "pos": side_pt, "act": "" }); who.target = side_pt
		if now - _people_since > 2.0 and fmod(now, 3.0) < delta and car.driver is Resident: (car.driver as Resident).say(["Excuse me.", "Coming through.", "Mind the car."][int(now) % 3], 1.4)
	else: _people_since = -1.0
	var hold_back := false   # 빨간불·멈춤 전 — 교차로 칸을 잡지 않는다(잡고 서 있으면 초록불 쪽이 칸을 못 얻었다)
	# 신호·멈춤 표지(town_city junction_rule) — 빨간불이면 정지선(노드에서 6m)에 서고, 멈춤 표지면 한 번 완전히 섰다(0.8초) 간다. 이미 들어선 차는 그대로
	if ni < centers.size() and nodes[ni] != null and _held != nodes[ni] and car.town.has_method("junction_rule"):
		var nd2: Variant = nodes[ni]
		var dn2 := p.distance_to(centers[ni])
		var back := centers[maxi(ni - 4, 0)] - centers[ni]   # 6m 뒤 — 바로 앞 점은 모퉁이 둥글림에 비스듬했다
		var from := Vector2(back.x, back.z)
		var rule: int = car.town.call("junction_rule", nd2, from)
		if dn2 > 4.8 and dn2 < 20.0:
			if rule == 1: lim = minf(lim, maxf(0.0, (dn2 - 6.2) * 1.3)); why = "red"; hold_back = true
			elif rule == 2 and _stopped_at != nd2:
				hold_back = true
				lim = minf(lim, maxf(0.0, (dn2 - 6.2) * 1.3)); why = "stop"
				if dn2 < 8.0 and car.v < 0.3:
					_stop_t += delta
					if _stop_t > 0.8: _stopped_at = nd2; _stop_t = 0.0
	# 교차로 칸
	if ni < centers.size() and nodes[ni] != null:
		var nd: Variant = nodes[ni]
		var dn := p.distance_to(centers[ni])
		if dn < 9.0 and _held != nd and not hold_back:
			if _take(car, nd): _wait_since = -1.0
			else:
				if _wait_since < 0.0: _wait_since = now
				if now - _wait_since < 6.0: lim = minf(lim, maxf(0.0, (dn - 5.0) * 1.2)); why = "lock"
	if car.v < 0.3 and (why == "cross" or why == "lock" or why.begins_with("car")):   # 차끼리 맞물려 오래 섰다(교차로 꽉 막힘 — 퇴근길 차 열둘이 서로를 기다렸다, 2026-10-19)
		if _stall_since < 0.0: _stall_since = now
		elif now - _stall_since > 20.0: _ghost_until = now + 4.0; _stall_since = -1.0
	else: _stall_since = -1.0
	# 몰기
	var yaw_want := atan2(-to.x, -to.z)
	var diff := wrapf(yaw_want - car.rotation.y, -PI, PI)
	if absf(diff) > 1.2 and lim > 2.6: lim = 2.6; why = "aim"   # 겨냥이 옆·뒤 — 천천히 크게 돈다(출발 때 돌아서기, 길 끝 유턴)
	var want := lim
	car.v = move_toward(car.v, want, (5.0 if want > car.v else 9.0) * delta)
	var turn := 2.6 * clampf(absf(car.v) / 2.0, 0.15 if li > 1 else 0.6, 1.0) * delta   # 길섶에서 빠져나올 땐 느려도 핸들을 크게(앞차 꽁무니로 곧장 들이받고 뒤로 빼기를 되풀이했다)
	car.rotation.y += clampf(diff, -turn, turn)
	car.steer = clampf(diff * 2.0, -1.0, 1.0)
	var nf := -car.global_transform.basis.z
	car.side = 0.0
	car._vy = 0.0 if car.is_on_floor() else car._vy - 20.0 * delta
	var before := car.global_position
	if car.is_on_floor():   # 바닥 기울기를 따라 — 수평으로만 밀면 칸 이음매·둔덕에 벽처럼 걸렸다
		var fn := car.get_floor_normal()
		nf = (nf - fn * nf.dot(fn)).normalized()
	car.velocity = nf * car.v + Vector3(0, car._vy, 0)
	car.move_and_slide()
	if absf(car.v) > 2.5: car._hit_people(nf)
	elif absf(car.v) > 0.2: car._nudge_people(nf, delta)
	var moved := car.global_position.distance_to(before)
	if car.v > 1.0 and moved < car.v * delta * 0.3 and car.get_slide_collision_count() > 0:   # 땅 칸 이음매(높이 맵 모서리)에 걸렸다 — 살짝 들어 넘긴다
		var hc := car.get_slide_collision(0).get_collider()
		if hc is StaticBody3D and (hc as Node).get_parent() and (hc as Node).get_parent().get_parent() and (hc as Node).get_parent().get_parent().name == "World":
			car.global_position += nf * car.v * delta + Vector3.UP * 0.06; moved = car.v * delta
	car._spin += moved / 0.3
	for wh in car._wheels: wh.rotation.x = car._spin
	for wh in car._front: wh.rotation.y = -car.steer * 0.55
	# 밀려났나·끼었나 — 다시 길 찾기는 바깥(town_traffic)이 한다
	if want > 0.6 and moved < maxf(car.v, want * 0.5) * delta * 0.2:   # 굽은 데서 느리게(1.5 아래) 가려다 낀 차도(모퉁이 앞에서 73초 섰다)
		if _slow_since < 0.0: _slow_since = now
	else:
		_slow_since = -1.0
		if moved > 0.05 and now > _back_until + 4.0: _backs = 0
	var off := p.distance_to(lane[li]) if li == 0 else _seg_d(p, lane[li - 1], lane[li])
	if li <= 1 or li >= lane.size() - 1: off = 0.0   # 길섶에서 차선으로 드는 첫 토막·길섶에 대는 끝 토막은 차선 밖이 맞다
	if _slow_since > 0.0 and now - _slow_since > 1.5 and _backs < 3 and off <= 4.0:   # 끼었다 — 1.2초 뒤로 뺐다가 다시(GTA 차처럼). 세 번째에도 끼면 길을 다시 찾는다
		_back_until = now + 1.2; _backs += 1; _slow_since = -1.0
		if car.driver is Resident and randf() < 0.4: (car.driver as Resident).say(["Hm. Tight.", "Reversing.", "Who put that there."][randi() % 3], 1.6)
		return
	if off > 5.5 or (_slow_since > 0.0 and now - _slow_since > 3.0):
		_release(car); done = true; lost = true; car.set_meta("rail_lost", "off %.1f li %d/%d p %s a %s b %s" % [off, li, lane.size(), str(p.snapped(Vector3.ONE)), str(lane[maxi(li - 1, 0)].snapped(Vector3.ONE)), str(lane[li].snapped(Vector3.ONE))] if off > 5.5 else "stuck@%s hit %s" % [str(car.global_position.snapped(Vector3.ONE)), (str(car.get_slide_collision(0).get_collider().name) + "<" + str(car.get_slide_collision(0).get_collider().get_parent().name) + " at " + str(car.get_slide_collision(0).get_position().snapped(Vector3.ONE * 0.1)) + " n " + str(car.get_slide_collision(0).get_normal().snapped(Vector3.ONE * 0.1))) if car.get_slide_collision_count() > 0 and car.get_slide_collision(0).get_collider() is Node else "-"])

static func _seg_d(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * tt)

func _brake(car: Car3D, delta: float) -> void:
	car.v = move_toward(car.v, 0.0, 9.0 * delta)
	car._vy = 0.0 if car.is_on_floor() else car._vy - 20.0 * delta
	car.velocity = -car.global_transform.basis.z * car.v + Vector3(0, car._vy, 0)
	car.move_and_slide()

func _take(car: Car3D, nd: Variant) -> bool:
	var axis_in := 0 if absf(centers[ni].x - centers[ni - 1].x) > absf(centers[ni].z - centers[ni - 1].z) else 1
	var straight := ni + 1 < centers.size() and ((centers[ni + 1] - centers[ni]).normalized()).dot((centers[ni] - centers[ni - 1]).normalized()) > 0.95
	var hs: Array = (locks.get(nd, []) as Array).filter(func(h: Dictionary) -> bool:
		var hc: Variant = h["car"]
		return is_instance_valid(hc) and hc != car and true and (hc as Car3D).rail != null and (hc as Car3D).rail._held == nd)
	for h in hs:
		if not (straight and bool(h["straight"]) and int(h["axis"]) == axis_in): locks[nd] = hs; return false
	hs.append({ "car": car, "axis": axis_in, "straight": straight })
	locks[nd] = hs; _held = nd
	return true

func _release(car: Car3D) -> void:
	if _held == null: return
	var nd: Variant = _held
	locks[nd] = (locks.get(nd, []) as Array).filter(func(h: Dictionary) -> bool: return h["car"] != car)
	_held = null
