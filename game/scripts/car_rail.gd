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
const R := 4.0
const NI := 6           # 격자 반경(노드) — x −224..216
const NJ := 10          # z −198..202
static var _edge := {}  # "i,j|i2,j2" -> bool
static var _edge_at := -1
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
var _slow_since := -1.0
var _merge_since := -1.0
var _back_until := -9.0
var _end_wait := -1.0
var _backs := 0
var why := ""                      # 점검(probe_rail) — 지금 무엇 때문에 느린가, 왜 길을 잃었나

# ── 길 그물 ──
static func npos(n: Vector2i) -> Vector3: return Vector3(TownPlan.OX + n.x * TownPlan.PITCH, 0, TownPlan.OZ + n.y * 20.0)

static func _ok(t, a: Vector2i, b: Vector2i) -> bool:
	if absi(b.x) > NI or absi(b.y) > NJ: return false
	var gen: WorldGen = t.gen
	var stamp: int = gen.flat_limit * 100000 + (t._segs as Dictionary).size()
	if stamp != _edge_at: _edge.clear(); _edge_at = stamp   # 마을이 넓어지면(깎기·찻길) 다시 잰다
	var key := "%d,%d|%d,%d" % ([a.x, a.y, b.x, b.y] if (a.x < b.x or (a.x == b.x and a.y < b.y)) else [b.x, b.y, a.x, a.y])
	if _edge.has(key): return _edge[key]
	var pa := npos(a); var pb := npos(b)
	var ok := true
	var main := a.y == 0 and b.y == 0
	var ns := a.x == b.x
	if ns and mini(a.y, b.y) == 0 and maxi(a.y, b.y) == 1:   # 강을 건너는 토막 — 다리(town_traffic LINKS, |x| > 72)만
		ok = absf(pa.x) > 72.0 and float(pa.x) in TownTraffic.LINKS
	if ok and not main and not (t._segs as Dictionary).has(RoadTiles.seg_key(a, b)): ok = false   # 깔린 찻길만(road_tiles) — 풀밭 위 격자 줄을 달리지 않게
	if ok and not main:
		for k in 7:
			var p := pa.lerp(pb, k / 6.0)
			var in_hub := absf(p.x) < WorldGen.HUB_X + 2.0 and absf(p.z) < WorldGen.HUB_Z + 2.0
			if in_hub: ok = false; break   # 옛 마을은 큰길만(Tower Road 는 좁아 우체국에 박혔다)
			if not in_hub and (gen.wild_k(p.x, p.z) > 0.05 or not gen.car_ground(p)): ok = false; break
			if not ns and posmod(a.y, 2) == 1 and CityMap.whole_block(CityMap.block_of(Vector2(p.x, p.z + 1.0))): ok = false; break   # 관공서·공원 블록 안 뒷골목은 없다
	_edge[key] = ok
	return ok

static func near_node(p: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi((p.x - TownPlan.OX) / TownPlan.PITCH), -NI, NI), clampi(roundi((p.z - TownPlan.OZ) / 20.0), -NJ, NJ))

## 이 점이 놓인 길 토막(양 끝 노드)과 그 위의 가운데 줄 점
static func _seg_of(p: Vector3) -> Array:
	var fx := (p.x - TownPlan.OX) / TownPlan.PITCH; var fz := (p.z - TownPlan.OZ) / 20.0
	var dx := absf(fx - roundf(fx)) * TownPlan.PITCH; var dz := absf(fz - roundf(fz)) * 20.0
	if dz <= dx:   # 동서 길 위
		var j := roundi(fz); var i0 := floori(fx)
		return [Vector2i(i0, j), Vector2i(i0 + 1, j), Vector3(p.x, 0, TownPlan.OZ + j * 20.0)]
	var i := roundi(fx); var j0 := floori(fz)
	return [Vector2i(i, j0), Vector2i(i, j0 + 1), Vector3(TownPlan.OX + i * TownPlan.PITCH, 0, p.z)]

static func _dijkstra(t, start: Vector2i) -> Dictionary:
	var dist := { start: 0.0 }; var prev := {}
	var open: Array = [start]
	while not open.is_empty():
		var bi := 0
		for k in open.size(): if float(dist[open[k]]) < float(dist[open[bi]]): bi = k
		var u: Vector2i = open[bi]; open.remove_at(bi)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var w: Vector2i = u + d
			if not _ok(t, u, w): continue
			var nd := float(dist[u]) + npos(u).distance_to(npos(w)) * (0.85 if u.y == 0 and w.y == 0 else 1.0)   # 큰길을 조금 더 좋아한다
			if nd < float(dist.get(w, 1e9)):
				if not dist.has(w): open.append(w)
				dist[w] = nd; prev[w] = u
	return { "dist": dist, "prev": prev }

## 길 짜기 — 차 자리·앞 방향에서 goal(가운데 줄 근처 점)까지. tail = 그 뒤에 붙일 가운데 줄 점(장소 가는 길). 못 찾으면 null
static func plan(t, car: Node3D, goal: Vector3, tail: Array = [], pull := Vector3.INF) -> CarRail:
	var p := car.global_position
	var fwd := -car.global_transform.basis.z; fwd.y = 0.0
	var s := _seg_of(p); var g := _seg_of(goal)
	var a: Vector2i = s[0]; var b: Vector2i = s[1]
	var ahead: Vector2i = b if (npos(b) - p).dot(fwd) > (npos(a) - p).dot(fwd) else a
	var best: Variant = null; var bd := 1e9; var dj := {}
	for first in [a, b]:   # 앞쪽 노드가 보통 — 뒤쪽은 돌아서야 하니 15m 더 친다(길 끝에서 유턴하던 것)
		var dd := _dijkstra(t, first)
		for n in [g[0], g[1]]:
			if (dd["dist"] as Dictionary).has(n):
				var d: float = float(dd["dist"][n]) + npos(n).distance_to(g[2]) + npos(first).distance_to(s[2]) + (0.0 if first == ahead else 15.0)
				if d < bd: bd = d; best = n; dj = dd
	if best == null: return null
	var path: Array = []
	var n: Variant = best
	while n != null:
		path.push_front(n)
		n = (dj["prev"] as Dictionary).get(n, null)
	var r := CarRail.new(); r.li = 1   # 첫 점(길섶에서 차선으로)은 겨냥하지 않는다 — 차선 위 앞 점을 보며 비스듬히 든다. 첫 점을 겨냥하면 느린 회전에 지나쳐 마당으로 들어갔다
	r.centers.append(s[2]); r.nodes.append(null)
	for q in path:
		if r.centers.size() == 1 and npos(q).distance_to(s[2]) < 0.5: continue
		r.centers.append(npos(q)); r.nodes.append(q)
	if npos(path[path.size() - 1]).distance_to(g[2]) > 0.5: r.centers.append(g[2]); r.nodes.append(null)
	for q in tail: r.centers.append(q); r.nodes.append(null)
	r._build_lane()
	if pull != Vector3.INF and r.lane.size() >= 2:   # 길섶에 댄다 — 차선 끝에서 비스듬히(차선에 세우면 뒤차가 영영 섰다)
		var dl := (r.lane[r.lane.size() - 1] - r.lane[r.lane.size() - 2]).normalized()
		r.lane.append(Vector3(pull.x, 0, pull.z) + dl * 1.0); r.cap.append(1.5)
	return r

func _right(d: Vector3) -> Vector3: return Vector3(-d.z, 0, d.x)

func _w(a: Vector3, b: Vector3) -> float: return W_MAIN if RoadTiles.in_hub(a) and RoadTiles.in_hub(b) else W

func _build_lane() -> void:
	var n := centers.size()
	if n < 2: done = true; return
	var d0 := (centers[1] - centers[0]).normalized()
	lane.append(centers[0] + _right(d0) * _w(centers[0], centers[1])); cap.append(9.0); node_end.append(0)
	for k in range(1, n - 1):
		var d1 := (centers[k] - centers[k - 1]).normalized(); var d2 := (centers[k + 1] - centers[k]).normalized()
		var o1 := _right(d1) * _w(centers[k - 1], centers[k]); var o2 := _right(d2) * _w(centers[k], centers[k + 1])
		if d1.dot(d2) > 0.95:
			lane.append(centers[k] + o1); cap.append(9.0)
		elif d1.dot(d2) < -0.9:   # 되돌기 — 길 끝에서 돌아 나온다
			lane.append(centers[k] + o1 + d1 * 1.5); cap.append(2.5)
			lane.append(centers[k] + d1 * 2.5); cap.append(2.0)
			lane.append(centers[k] + o2 + d1 * 1.5); cap.append(2.5)
		else:
			var corner := centers[k] + o1 + o2
			var right_turn := d1.cross(d2).y < 0.0
			var rr := minf(2.0 if right_turn else R, minf(centers[k].distance_to(centers[k - 1]), centers[k].distance_to(centers[k + 1])) * 0.45)   # 우회전은 안쪽 모서리를 바짝 — 크게 돌면 길섶(가로등·울타리)을 탔다
			var pin := corner - d1 * rr; var pout := corner + d2 * rr
			for q in 5:
				var tt := q / 4.0
				lane.append(pin.lerp(corner, tt).lerp(corner.lerp(pout, tt), tt)); cap.append(2.6 if right_turn else 3.6)
		node_end.append(lane.size() - 1)
	var dl := (centers[n - 1] - centers[n - 2]).normalized()
	lane.append(centers[n - 1] + _right(dl) * _w(centers[n - 2], centers[n - 1])); cap.append(2.0); node_end.append(lane.size() - 1)
	for k in lane.size(): lane[k].y = 0.0

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
	var look := 3.5 + car.v * 0.35
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
		lim = minf(lim, cap[q] + dsum * 0.55)
	if li >= lane.size() - 2: lim = minf(lim, 0.6 + p.distance_to(lane[lane.size() - 1]) * 0.6)   # 다 와 간다 — 세울 자리에 맞춰
	# 앞차. 길섶에서 막 나오는 중(첫 토막)이면 둘레 12m 에 달리는 차가 있는 동안 기다린다(8초까지) — 비스듬히 끼어들다 마주 오는 차와 박았다
	var merging := li <= 1 and car.v < 3.0
	if merging and _merge_since < 0.0: _merge_since = now
	for c in car.town.cars:
		if c == car: continue
		if merging and now - _merge_since < 8.0 and (c as Car3D).v > 0.5 and (c as Node3D).global_position.distance_squared_to(car.global_position) < 144.0:
			lim = 0.0; why = "merge"; continue
		var tc: Vector3 = c.global_position - car.global_position; tc.y = 0.0
		if tc.length_squared() > 196.0: continue
		var ah := tc.dot(fwd)
		var cf := -(c as Node3D).global_transform.basis.z; cf.y = 0.0
		var moving_rail: bool = (c as Car3D).rail != null and not (c as Car3D).rail.done
		if moving_rail and cf.normalized().dot(fwd) < 0.5: continue   # 교차로에서 가로지르는·마주 오는 차는 칸(lock)이 맡는다 — 서로를 앞차로 보고 둘 다 섰다
		if ah > 0.0 and absf(tc.dot(right)) < 1.15 and (ah - 3.4) * 1.1 < lim: lim = maxf(0.0, (ah - 3.4) * 1.1); why = "car:%s" % (c as Car3D).kind
	if why.begins_with("car") and li >= lane.size() - 2 and car.v < 0.3:   # 다 와서 세운 차에 막혔다 — 여기 댄다
		if _end_wait < 0.0: _end_wait = now
		elif now - _end_wait > 5.0: done = true; _release(car); return
	else: _end_wait = -1.0
	# 사람(주민·나) — 앞 4.5m, 차선 폭 안
	var person := false
	for r in car.town.residents:
		if r == car.driver or r.state == "drive": continue
		var tr: Vector3 = r.global_position - car.global_position; tr.y = 0.0
		if tr.length_squared() > 30.0: continue
		var ah := tr.dot(fwd)
		if ah > 0.5 and ah < 4.5 and absf(tr.dot(right)) < 1.0: person = true
	if car.town.driving != car and car.town.body.visible:
		var tb: Vector3 = car.town.body.global_position - car.global_position; tb.y = 0.0
		var ahb := tb.dot(fwd)
		if ahb > 0.5 and ahb < 4.5 and absf(tb.dot(right)) < 1.0: person = true
	if person:
		why = "person"
		if _people_since < 0.0: _people_since = now
		lim = minf(lim, 0.0 if now - _people_since < 4.0 else 0.8)   # 섰다가, 오래 안 비키면 살살(밀며) 간다
		if now - _people_since > 2.0 and fmod(now, 3.0) < delta and car.driver is Resident: (car.driver as Resident).say(["Excuse me.", "Coming through.", "Mind the car."][int(now) % 3], 1.4)
	else: _people_since = -1.0
	# 교차로 칸
	if ni < centers.size() and nodes[ni] != null:
		var nd: Vector2i = nodes[ni]
		var dn := p.distance_to(centers[ni])
		if dn < 9.0 and _held != nd:
			if _take(car, nd): _wait_since = -1.0
			else:
				if _wait_since < 0.0: _wait_since = now
				if now - _wait_since < 6.0: lim = minf(lim, maxf(0.0, (dn - 5.0) * 1.2)); why = "lock"
	# 몰기
	var yaw_want := atan2(-to.x, -to.z)
	var diff := wrapf(yaw_want - car.rotation.y, -PI, PI)
	if absf(diff) > 1.2: lim = minf(lim, 2.0)   # 겨냥이 옆·뒤 — 천천히 크게 돈다(출발 때 돌아서기, 길 끝 유턴)
	var want := lim
	car.v = move_toward(car.v, want, (5.0 if want > car.v else 9.0) * delta)
	var turn := 2.6 * clampf(absf(car.v) / 2.0, 0.15, 1.0) * delta
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
	if want > 1.5 and moved < car.v * delta * 0.2:
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
	if off > 4.0 or (_slow_since > 0.0 and now - _slow_since > 3.0):
		_release(car); done = true; lost = true; car.set_meta("rail_lost", "off %.1f li %d/%d p %s a %s b %s" % [off, li, lane.size(), str(p.snapped(Vector3.ONE)), str(lane[maxi(li - 1, 0)].snapped(Vector3.ONE)), str(lane[li].snapped(Vector3.ONE))] if off > 4.0 else "stuck@%s hit %s" % [str(car.global_position.snapped(Vector3.ONE)), (str(car.get_slide_collision(0).get_collider().name) + "<" + str(car.get_slide_collision(0).get_collider().get_parent().name)) if car.get_slide_collision_count() > 0 and car.get_slide_collision(0).get_collider() is Node else "-"])

static func _seg_d(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * tt)

func _brake(car: Car3D, delta: float) -> void:
	car.v = move_toward(car.v, 0.0, 9.0 * delta)
	car._vy = 0.0 if car.is_on_floor() else car._vy - 20.0 * delta
	car.velocity = -car.global_transform.basis.z * car.v + Vector3(0, car._vy, 0)
	car.move_and_slide()

func _take(car: Car3D, nd: Vector2i) -> bool:
	var axis_in := 0 if absf(centers[ni].x - centers[ni - 1].x) > absf(centers[ni].z - centers[ni - 1].z) else 1
	var straight := ni + 1 < centers.size() and ((centers[ni + 1] - centers[ni]).normalized()).dot((centers[ni] - centers[ni - 1]).normalized()) > 0.95
	var hs: Array = (locks.get(nd, []) as Array).filter(func(h: Dictionary) -> bool:
		var hc: Variant = h["car"]
		return is_instance_valid(hc) and hc != car and (hc as Node3D).global_position.distance_to(npos(nd)) < 12.0 and (hc as Car3D).rail != null and (hc as Car3D).rail._held == nd)
	for h in hs:
		if not (straight and bool(h["straight"]) and int(h["axis"]) == axis_in): locks[nd] = hs; return false
	hs.append({ "car": car, "axis": axis_in, "straight": straight })
	locks[nd] = hs; _held = nd
	return true

func _release(car: Car3D) -> void:
	if _held == null: return
	var nd: Vector2i = _held
	locks[nd] = (locks.get(nd, []) as Array).filter(func(h: Dictionary) -> bool: return h["car"] != car)
	_held = null
