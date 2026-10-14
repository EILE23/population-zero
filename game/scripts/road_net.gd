class_name RoadNet
extends RefCounted
## 길 그물(운영자 2026-10-14: "도로도 나중에 유저나 AI 주민들이 건설할 텐데 그에 맞춰 도로 주행할 수 있도록 초기 설계부터") —
## 마을의 모든 길이 여기 한 곳에 있다. 처음 길(valley.gd 가 짓는 골짜기 길)도, 나중에 사람·주민이 놓는 길도 add() 하나로 들어온다.
##   길: {pts: PackedVector2Array(약 3m 간격), ys: 높이, w: 폭, kind: "main"|"lane"|"bridge"|"built", by: 누가}
##   가까운 길 찾기(near): 12m 칸 색인
##   차 그래프(graph): 마디 = 길 끝·다른 길과 닿거나 엇갈리는 점(2.5m 안은 한 마디), 가지 = 마디 사이 길 조각(점·폭·길 번호). 길이 더해지면 다음 물음 때 다시 짓는다(version)
## 차(car_rail)는 이 그래프만 본다 — 길이 어떻게 생겼든(굽은 골목·지그재그·새로 놓은 길) 같은 방식으로 달린다

static var roads: Array = []
static var version := 0
static var _grid := {}
static var _g_ver := -1
static var _nodes: Array = []   # Vector2
static var _edges: Array = []   # {a, b, pts, w, road, i0, i1}
static var _adj: Array = []
static var _edge_at := {}       # Vector2i(길, 점) -> 가지

## 길 더하기 — pts 는 대략 3m 간격으로 고르고, 높이(ys)가 없으면 height(Callable(x, z) -> float)로 재서 길 따라 고른다. 길 번호를 돌려준다
static func add(pts: PackedVector2Array, w: float, kind := "lane", ys := PackedFloat32Array(), height := Callable(), by := "") -> int:
	var pts2 := pts.duplicate()
	for end in [0, pts2.size() - 1]:   # 끝이 가까운 길(6m)에 닿게 붙인다 — 놓은 길이 그물과 이어지게
		var nr := near(pts2[end], 1)
		if int(nr[4]) >= 0 and float(nr[0]) + float(roads[int(nr[4])]["w"]) / 2.0 < 6.0: pts2[end] = nr[1]
	var p := _resample(pts2, 3.0)
	if p.size() < 2: return -1
	if ys.size() != p.size():
		ys = PackedFloat32Array()
		for q in p: ys.append(maxf(float(height.call(q.x, q.y)) if height.is_valid() else 0.0, 0.0))
		for pass_ in 3:
			var y2 := ys.duplicate()
			for i in range(1, ys.size() - 1): y2[i] = (ys[i - 1] + ys[i] * 2.0 + ys[i + 1]) / 4.0
			ys = y2
	roads.append({ "pts": p, "ys": ys, "w": w, "kind": kind, "main": kind == "main", "bridge": kind == "bridge", "by": by })
	var ri := roads.size() - 1
	_index_road(ri)
	version += 1
	return ri

static func clear() -> void:
	roads.clear(); _grid.clear(); version += 1

static func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	if pts.size() < 2: return pts
	var out := PackedVector2Array([pts[0]])
	var acc := 0.0
	for i in pts.size() - 1:
		var a := pts[i]; var b := pts[i + 1]; var seg := a.distance_to(b)
		var t := step - acc
		while t <= seg:
			out.append(a.lerp(b, t / seg)); t += step
		acc = seg - (t - step)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > 0.5: out.append(pts[pts.size() - 1])
	else: out[out.size() - 1] = pts[pts.size() - 1]
	return out

static func _index_road(ri: int) -> void:
	var pts: PackedVector2Array = roads[ri]["pts"]
	for i in pts.size() - 1:
		for f in [0.0, 0.5, 1.0]:
			var q := pts[i].lerp(pts[i + 1], f)
			var k := Vector2i(floori(q.x / 12.0), floori(q.y / 12.0))
			if not _grid.has(k): _grid[k] = []
			if not (_grid[k] as Array).has(Vector2i(ri, i)): _grid[k].append(Vector2i(ri, i))

## 가장 가까운 길 — [가장자리까지 거리, 가운데 줄 위 점, 방향, 높이, 길 번호, 점 번호]
static func near(p: Vector2, reach := 1) -> Array:
	var best: Array = [1e9, p, Vector2.RIGHT, 0.0, -1, -1]
	var c := Vector2i(floori(p.x / 12.0), floori(p.y / 12.0))
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			for e in _grid.get(c + Vector2i(dx, dz), []):
				var r: Dictionary = roads[e.x]
				var pts: PackedVector2Array = r["pts"]; var ys: PackedFloat32Array = r["ys"]
				var a := pts[e.y]; var b := pts[e.y + 1]; var ab := b - a
				var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
				var q := a + ab * t
				var de := p.distance_to(q) - float(r["w"]) / 2.0
				if de < float(best[0]): best = [de, q, ab.normalized(), lerpf(ys[e.y], ys[e.y + 1], t), e.x, e.y]
	return best

# ── 차 그래프 ──
static func graph() -> void:
	if _g_ver == version: return
	_g_ver = version
	_nodes.clear(); _edges.clear(); _adj.clear(); _edge_at.clear()
	var cuts := {}   # 길 -> {점 번호: 마디}
	var node_of := func(p: Vector2) -> int:
		for i in _nodes.size():
			if (_nodes[i] as Vector2).distance_to(p) < 2.5: return i
		_nodes.append(p); return _nodes.size() - 1
	var cut := func(ri: int, i: int, nd: int) -> void:
		if not cuts.has(ri): cuts[ri] = {}
		cuts[ri][i] = nd
	for ri in roads.size():
		var pts: PackedVector2Array = roads[ri]["pts"]
		for end in [0, pts.size() - 1]:
			var p := pts[end]
			var nd: int = node_of.call(p)
			cut.call(ri, end, nd)
			for e in _near_pts(p, 3.2):   # 이 끝이 닿는 다른 길(가운데·끝) — 거기서 자른다
				if e.x != ri: cut.call(e.x, e.y, nd)
	for ri in roads.size():   # 엇갈림(X) — 두 길의 토막이 서로 가로지르면 그 점에 마디
		var pa: PackedVector2Array = roads[ri]["pts"]
		for i in pa.size() - 1:
			for e in _near_segs(pa[i].lerp(pa[i + 1], 0.5)):
				if e.x <= ri: continue
				var pb: PackedVector2Array = roads[e.x]["pts"]
				var x: Variant = Geometry2D.segment_intersects_segment(pa[i], pa[i + 1], pb[e.y], pb[e.y + 1])
				if x == null: continue
				var nd: int = node_of.call(x)
				cut.call(ri, i if pa[i].distance_to(x) < pa[i + 1].distance_to(x) else i + 1, nd)
				cut.call(e.x, e.y if pb[e.y].distance_to(x) < pb[e.y + 1].distance_to(x) else e.y + 1, nd)
	for ri in cuts:
		var ks: Array = (cuts[ri] as Dictionary).keys(); ks.sort()
		var pts: PackedVector2Array = roads[ri]["pts"]
		for m in ks.size() - 1:
			var i0: int = ks[m]; var i1: int = ks[m + 1]
			if i1 <= i0 or cuts[ri][i0] == cuts[ri][i1] and i1 - i0 < 2: continue
			var seg := pts.slice(i0, i1 + 1)
			seg[0] = _nodes[cuts[ri][i0]]; seg[seg.size() - 1] = _nodes[cuts[ri][i1]]   # 끝은 마디에 딱 맞춘다(갈림목에서 차선이 끊기지 않게)
			_edges.append({ "a": cuts[ri][i0], "b": cuts[ri][i1], "pts": seg, "w": roads[ri]["w"], "road": ri, "i0": i0, "i1": i1 })
			for k in range(i0, i1): _edge_at[Vector2i(ri, k)] = _edges.size() - 1
	_adj.resize(_nodes.size())
	for i in _adj.size(): _adj[i] = []
	for ei in _edges.size():
		_adj[_edges[ei]["a"]].append(ei); _adj[_edges[ei]["b"]].append(ei)

static func _near_pts(p: Vector2, r: float) -> Array:
	var out: Array = []
	var c := Vector2i(floori(p.x / 12.0), floori(p.y / 12.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for e in _grid.get(c + Vector2i(dx, dz), []):
				var pts: PackedVector2Array = roads[e.x]["pts"]
				for k in [e.y, e.y + 1]:
					if pts[k].distance_to(p) < r and not out.has(Vector2i(e.x, k)): out.append(Vector2i(e.x, k))
	var best := {}   # 길마다 가장 가까운 점 하나
	for e in out:
		var d: float = (roads[e.x]["pts"] as PackedVector2Array)[e.y].distance_to(p)
		if not best.has(e.x) or d < float(best[e.x][1]): best[e.x] = [e, d]
	return best.values().map(func(v: Array) -> Vector2i: return v[0])

static func _near_segs(p: Vector2) -> Array:
	return _grid.get(Vector2i(floori(p.x / 12.0), floori(p.y / 12.0)), [])

static func nodes() -> Array: graph(); return _nodes
static func edges() -> Array: graph(); return _edges
static func adj() -> Array: graph(); return _adj
static func edge_of(road: int, i: int) -> int: graph(); return int(_edge_at.get(Vector2i(road, i), -1))
