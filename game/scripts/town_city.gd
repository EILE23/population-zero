class_name TownCity
extends TownGrowth
## 산골 도시(운영자 2026-10-14: 체르마트 사진 — "싹 다 뒤집어 엎자", "도로도 불규칙하게, 집들도 불규칙하지만 자연스럽게 어우러지게") —
## 길·필지는 valley.gd(골짜기 큰길, 흔들린 골목 그물, 비탈 지그재그 골목, 다리). 여기서는 그린다:
##   길: 지형을 따르는 띠(큰길 아스팔트·가운데 점선, 골목 자갈), 다리(난간), 큰길 가로등·골목 등, 큰길 버스 정류장
##   필지: 집(house_styles — 동네(district) 한 결: 벽·지붕·모양·울타리·나무), 마당(울타리·문 앞 흙길·우편함·뒤뜰), 비탈 집은 제 터와 돌 축대,
##   가게(큰길가), 공방(동서 끝), 쌈지 정원, 관공서(Valley.CIVIC — 광장)
## 지은 것은 40m 칸마다 구역(district) — 멀면 꺼진다(town_systems _stream)

var shops: Array = []          # [{kind "shop", pos, yaw, item, type, id, keeper: {kind "keeper", pos, yaw, shop_id}}]
var _block_nodes := {}         # Vector2i -> Node3D(구역)

func _city_init() -> void:
	var keep := _build_parent
	_roads_init()
	for cv in Valley.CIVIC:
		var at := Vector3((cv[2] as Vector2).x, 0, (cv[2] as Vector2).y)
		_build_parent = _root_for(at)
		var mark := _merge_mark()
		_civic(at, String(cv[0]), String(cv[1]))
		_merge_done(mark)
	for s in WorldGen.SITES: _dress_road(s)
	_build_parent = keep
	for i in doors.size():   # 가게 방은 처음에 다 — 주인이 창구 뒤에 서야 하니까
		if doors[i].has("shop_id"): call("_room", i)
	_hire_shopkeepers()
	gen.rebuild_all(body.global_position)   # 길·터에 맞춰 칸을 다시

# ── 길 ──
## 길마다 40m 조각으로(구역마다 하나 — 멀면 꺼진다). 지형 높이(Valley ys)를 따르는 띠, 큰길은 아스팔트와 가운데 점선, 골목은 자갈, 강 위는 다리
func _roads_init() -> void:
	var rs := Valley.roads()
	var asphalt := _mat(Color(0.42, 0.42, 0.45))
	var cobble := _mat(Color("a59d94"))   # 골목 — 민무늬 돌빛(자갈 무늬는 위에서 보면 흰 줄무늬였다, 운영자 2026-10-14)
	var line := _mat(Color("efe9e2"))
	for ri in rs.size():
		var r: Dictionary = rs[ri]
		var pts: PackedVector2Array = r["pts"]; var ys: PackedFloat32Array = r["ys"]
		var main: bool = r.get("main", false)
		var w: float = r["w"]
		var i := 0
		while i < pts.size() - 1:
			var j := i
			var acc := 0.0
			while j < pts.size() - 1 and acc < 40.0: acc += pts[j].distance_to(pts[j + 1]); j += 1
			var mid := pts[(i + j) / 2]
			if true:
				_build_parent = _root_for(Vector3(mid.x, 0, mid.y))
				if main: _ribbon(pts, ys, i, j, w, asphalt, 0.05)
				else: _lane_ribbon(pts, ys, i, j, w, cobble)
				if main:   # 가운데 점선
					var t := i
					while t < j:
						if t % 2 == 0:
							var a := pts[t]; var b := pts[t + 1]; var d := b - a
							var dash := _box(Vector3(d.length() * 0.6, 0.012, 0.14), Vector3((a.x + b.x) / 2.0, (ys[t] + ys[t + 1]) / 2.0 + 0.055, (a.y + b.y) / 2.0), line, false)
							dash.rotation.y = -atan2(d.y, d.x)
						t += 1
			i = j
		if r.get("bridge", false): _bridge(pts, w)
	_street_furniture()
	Signals.draw(self)

## 골목 띠 — 큰길 아스팔트 위로는 깔지 않는다(자갈 줄무늬가 큰길을 가로질렀다, 운영자 2026-10-14). 큰길 안쪽 0.6m 까지만, 아스팔트보다 낮게
func _lane_ribbon(pts: PackedVector2Array, ys: PackedFloat32Array, i: int, j: int, w: float, mat: Material) -> void:
	var lim := Valley.MAIN_W / 2.0 - 0.6
	var off := func(q: Vector2) -> bool: return absf(q.y - Valley.main_z(q.x)) > lim or absf(q.x) > Valley.END_X + 4.0
	var run := PackedVector2Array(); var ry := PackedFloat32Array()
	for k in range(i, j + 1):
		if off.call(pts[k]):
			if run.is_empty() and k > i and not off.call(pts[k - 1]):   # 큰길에서 나오는 끝 — 가장자리에서 시작
				var f := _edge_f(pts[k - 1], pts[k], lim); run.append(pts[k - 1].lerp(pts[k], f)); ry.append(lerpf(ys[k - 1], ys[k], f))
			run.append(pts[k]); ry.append(ys[k])
		else:
			if not run.is_empty():
				var f := _edge_f(pts[k], pts[k - 1], lim); run.append(pts[k].lerp(pts[k - 1], f)); ry.append(lerpf(ys[k], ys[k - 1], f))
				if run.size() > 1: _ribbon(run, ry, 0, run.size() - 1, w, mat, 0.04)
			run = PackedVector2Array(); ry = PackedFloat32Array()
	if run.size() > 1: _ribbon(run, ry, 0, run.size() - 1, w, mat, 0.04)

## a(큰길 안)→b(밖) 토막에서 큰길 가장자리 lim 에 닿는 비율
func _edge_f(a: Vector2, b: Vector2, lim: float) -> float:
	var da := absf(a.y - Valley.main_z(a.x)); var db := absf(b.y - Valley.main_z(b.x))
	return clampf((lim - da) / maxf(db - da, 0.01), 0.0, 1.0)

## 길 놓기(사람·주민이 짓는 길 — 운영자 2026-10-14: "도로도 나중에 유저나 AI 주민들이 건설할 텐데") — RoadNet 에 넣고(차 그래프는 다음 길 짜기 때 저절로 다시),
## 그리고(띠·등), 그 둘레 칸을 다시 지어 땅을 길 높이로 고른다. 방(멀티)에 실어 보내는 건 부르는 쪽이 한다. 길 번호를 돌려준다
func build_road(pts: PackedVector2Array, w := Valley.LANE_W, by := "") -> int:
	var hf := func(x: float, z: float) -> float: return Valley.base_h(x, z)
	var ri := RoadNet.add(pts, w, "built", PackedFloat32Array(), hf, by)
	if ri < 0: return -1
	var r: Dictionary = RoadNet.roads[ri]
	var rp: PackedVector2Array = r["pts"]; var ys: PackedFloat32Array = r["ys"]
	var keep := _build_parent
	var cobble := _mat(Color("a59d94"))   # 골목 — 민무늬 돌빛(자갈 무늬는 위에서 보면 흰 줄무늬였다, 운영자 2026-10-14)
	var i := 0
	while i < rp.size() - 1:
		var j := mini(i + 13, rp.size() - 1)
		_build_parent = _root_for(Vector3(rp[(i + j) / 2].x, 0, rp[(i + j) / 2].y))
		_ribbon(rp, ys, i, j, w, cobble, 0.05)
		i = j
	_build_parent = keep
	for k in range(0, rp.size(), 8): gen.reflat(rp[k], false)
	return ri

## 띠 한 조각 — 점 i..j, 폭 w, 땅 위 lift. 이음새는 다음 조각과 같은 점이라 끊기지 않는다
func _ribbon(pts: PackedVector2Array, ys: PackedFloat32Array, i: int, j: int, w: float, mat: Material, lift: float) -> void:
	var verts := PackedVector3Array(); var uvs := PackedVector2Array(); var idx := PackedInt32Array()
	var along := 0.0
	for k in range(i, j + 1):
		var a := pts[maxi(k - 1, 0)]; var b := pts[mini(k + 1, pts.size() - 1)]
		var d := (b - a).normalized(); var n := Vector2(-d.y, d.x) * (w / 2.0)
		var y := ys[k] + lift
		if absf(pts[k].y - RIVER_Z) < RIVER_HW + 2.5: y = maxf(y, 0.08)   # 다리 위
		verts.append(Vector3(pts[k].x + n.x, y, pts[k].y + n.y)); verts.append(Vector3(pts[k].x - n.x, y, pts[k].y - n.y))
		if k > i: along += pts[k].distance_to(pts[k - 1])
		uvs.append(Vector2(0, along / 2.0)); uvs.append(Vector2(w / 2.0, along / 2.0))
	for k in (j - i):
		var a := k * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_TEX_UV] = uvs; arr[Mesh.ARRAY_INDEX] = idx
	var st := SurfaceTool.new(); st.create_from_arrays(arr); st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(mi)

## 다리 — 강 위 난간 둘과 바닥 판(띠는 강 위에서 0.32m 로 뜬다)
func _bridge(pts: PackedVector2Array, w: float) -> void:
	var x := pts[0].x
	var at := Vector3(x, 0, RIVER_Z)
	_build_parent = _root_for(at)
	_box(Vector3(w + 0.6, 0.06, RIVER_HW * 2.0 + 4.0), at, _mat(Color("a8a29a")), false)   # 얇은 판(충돌 없음 — 끝 턱에 차가 걸렸다, 밑은 바닥 판) — 차가 턱 없이 넘는다(0.3 이면 끝에 걸렸다)
	for sx in [-1.0, 1.0]: _box(Vector3(0.18, 0.75, RIVER_HW * 2.0 + 4.0), at + Vector3(sx * (w / 2.0 + 0.2), 0.06, 0), _mat(Color("8a7f86")))

static func SQ_NEAR(q: Vector2) -> bool: return Valley.SQUARE.grow(1.0).has_point(q)

## 길가 — 큰길은 30m 마다 가로등(양쪽 번갈아), 다섯에 하나는 버스 정류장. 골목은 45m 마다 낮은 등
func _street_furniture() -> void:
	var rs := Valley.roads()
	for ri in rs.size():
		var r: Dictionary = rs[ri]
		var pts: PackedVector2Array = r["pts"]; var ys: PackedFloat32Array = r["ys"]
		var main: bool = r.get("main", false)
		var gap := 30.0 if main else 45.0
		var acc := 0.0; var next := gap * 0.5; var n := 0
		for k in pts.size() - 1:
			var seg := pts[k].distance_to(pts[k + 1])
			while acc + seg >= next:
				var f := (next - acc) / seg
				var p := pts[k].lerp(pts[k + 1], f)
				var d := (pts[k + 1] - pts[k]).normalized(); var nr := Vector2(-d.y, d.x)
				var side := 1.0 if n % 2 == 0 else -1.0
				var q := p + nr * side * (float(r["w"]) / 2.0 + 0.6)
				var y := lerpf(ys[k], ys[k + 1], f)
				var ok := not SQ_NEAR(q) and absf(q.y - RIVER_Z) > RIVER_HW + 2.0 and float(Valley.near(q)[0]) > 0.3
				if ok:
					var at := Vector3(q.x, y, q.y)
					_build_parent = _root_for(at)
					if main: _street_light(at, atan2(-nr.x * side, -nr.y * side))
					else: _lamp(at)
					if main and n % 5 == 2: _bus_stop(at + Vector3(d.x, 0, d.y) * 3.0, nr * side)
				n += 1; next += gap
			acc += seg

func _bus_stop(at: Vector3, out: Vector2) -> void:
	_box(Vector3(2.6, 0.08, 1.1), at + Vector3(out.x, 2.3, out.y) * Vector3(0.5, 1.0, 0.5), _mat(Color("4a4a52")), false)
	_bench(Vector3(at.x + out.x * 0.6, at.y, at.z + out.y * 0.6))
	_msgboard(at, at - Vector3(out.x, 0, out.y), "s%d_%d" % [int(at.x), int(at.z)], "Bus stop — timetable & notes")

## 문 앞 흙길 — 문에서 길가(가까운 길 가장자리)까지, 지형을 따라 1m 폭
func _footpath(l: Dictionary, c: Vector3) -> void:
	var hd := float((TownPlan.house_spec(l)["size"] as Vector3).z) / 2.0
	var a := Vector2(c.x, c.z + hd + 0.9)
	var nr: Array = Valley.near(a, 2)
	if int(nr[4]) < 0: return
	var rp: Vector2 = nr[1]
	var to: Vector2 = rp + (a - rp).normalized() * (float(Valley.roads()[int(nr[4])]["w"]) / 2.0 - 0.2)
	if a.distance_to(to) < 0.8 or a.distance_to(to) > 40.0: return
	var pts := PackedVector2Array(); var ys := PackedFloat32Array()
	var n := maxi(2, int(a.distance_to(to) / 1.5))
	var rng := RandomNumberGenerator.new(); rng.seed = hash("path/" + String(l["id"]))
	var bend := Vector2(rng.randf_range(-0.7, 0.7), 0)
	for k in n + 1:
		var f := float(k) / n
		var p := a.lerp(to, f) + bend * sin(f * PI)
		pts.append(p); ys.append(gen.height(p.x, p.y))
	var keep := _build_parent; _build_parent = _root_for(c)
	_ribbon(pts, ys, 0, pts.size() - 1, 1.0, _mat(Color("b59a74")), 0.03)
	_build_parent = keep

# ── 필지 ──
func _finish_lot(l: Dictionary, live: bool) -> void:
	var kind := CityMap.lot_kind(l)
	var c := TownPlan.spot_of(l)
	var k := int(l["order"])
	if _done.has(k): return
	_done[k] = true
	if not live: built = maxi(built, k + 1)
	var keep := _build_parent; _build_parent = _root_for(c)
	var mark := _merge_mark()
	var th := District.of_block(l["b"])
	house_hint = { "mat": th["mat"], "roof": th["roof"] }; tree_hint = String(th["tree"])
	var nd := doors.size()
	match kind:
		"shop": _shop_lot(l, c)
		"workshop": _workshop_lot(l, c)
		"green": _green_lot(l, c)
		_:
			var want := _style_for(l)
			var hs := HouseStyles.build(self, c, l, TownPlan.house_spec(l), want if (has_method("_is_me") and call("_is_me", k)) else District.style_in(th, want, String(l["id"])))
			_flower_bed(c + Vector3(-hs.x / 2.0 - 0.6, 0, hs.z / 2.0 + 0.4))
			_valley_yard(l, c, hs)
	house_hint = {}; tree_hint = ""
	if c.y > 0.3: _retaining(c)
	_merge_done(mark)
	_build_parent = keep
	if kind == "house" and doors.size() > nd and not _is_mine(k): _move_in(doors[nd], live, owner_row(k))   # 내가 산 필지면 주민이 들어오지 않는다(내 집)
	if kind != "green": _footpath(l, c)
	if live:
		_dust(c + Vector3(0, 0.5, 0))
		say_toast("A new house is finished." if kind == "house" else ("A new shop opened." if kind == "shop" else "Something new in town."))
		if kind == "shop": _hire_shopkeepers()

## 비탈 집 터의 돌 축대 — 터 둘레(집 앞 6m·뒤 10.5m)에서 땅이 터보다 낮은 쪽만 드러난다
func _retaining(c: Vector3) -> void:
	var stone := _mat(Color("a8a29a"))
	for sd in [[Vector2(0, 6.4), 9.8, false], [Vector2(0, -10.9), 9.8, false], [Vector2(-5.2, -2.25), 17.3, true], [Vector2(5.2, -2.25), 17.3, true]]:
		var o: Vector2 = sd[0]; var len: float = sd[1]; var ns: bool = sd[2]
		var p := Vector2(c.x + o.x, c.z + o.y)
		var out := Vector2(signf(o.x), 0) if ns else Vector2(0, signf(o.y))
		var gy := INF
		for f in [-0.4, 0.0, 0.4]:
			var q := p + (Vector2(0, len * f) if ns else Vector2(len * f, 0)) + out * 0.9
			gy = minf(gy, gen.height(q.x, q.y))
		if gy < c.y - 0.35:
			var wall := _box(Vector3(0.5 if ns else len, c.y - gy + 0.35, len if ns else 0.5), Vector3(p.x, gy - 0.2, p.y), stone, true)

## 마당 — 동네 울타리(앞 문길은 비운다·옆), 뒤 모서리 나무, 빨랫줄, 현관 화분·발판, 우편함(쪽지), 쓰레기통, 뒤뜰(back_yards — 그 집 사람 성미대로)
func _valley_yard(l: Dictionary, c: Vector3, hs: Vector3) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash("yard/" + String(l["id"]))
	var half := 4.4
	var front := c.z + hs.z / 2.0 + 2.0
	var back := c.z - hs.z / 2.0 - 5.4
	var th := District.of_block(l["b"])
	var kind := int(th["fence"])
	var col: Color = [Color("f7f4ef"), Color(String(th["hedge"])), Color("a8a29a")][kind]
	var hgt: float = [0.55, 0.8, 0.5][kind]
	var thick := 0.06 if kind == 0 else 0.35
	var y := c.y
	for side in [-1.0, 1.0]:
		_box(Vector3(half - 0.9, hgt, thick), Vector3(c.x + side * (half + 0.9) / 2.0, y, front), _mat(col), false)
		_box(Vector3(thick, hgt, front - back), Vector3(c.x + side * half, y, (front + back) / 2.0), _mat(col), false)
	_box(Vector3(half * 2.0, hgt, thick), Vector3(c.x, y, back), _mat(col), false)
	_tree(Vector3(c.x + (half - 0.8) * (1.0 if rng.randf() < 0.5 else -1.0), y, back + 0.9), rng.randf_range(0.8, 1.0))
	if rng.randf() < 0.4:   # 빨랫줄
		var lx := c.x + (hs.x / 2.0 + 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
		for e in [-1.2, 1.2]: _box(Vector3(0.05, 1.6, 0.05), Vector3(lx, y, c.z + e), _mat(Color("8a6a4a")), false)
		_box(Vector3(0.02, 0.02, 2.4), Vector3(lx, y + 1.55, c.z), _mat(Color("efe9e2")), false)
		for q in 3: _box(Vector3(0.03, 0.4, 0.35), Vector3(lx, y + 1.15, c.z - 0.6 + q * 0.55), _mat([Color("ad7096"), Color("7a90b0"), Color("f2c84b"), Color("f7f4ef")][(q + rng.randi()) % 4]), false)
	if not doors.is_empty():
		var dp: Vector3 = doors[doors.size() - 1]["pos"]
		if absf(dp.x - c.x) < 4.0:
			for sx in [-0.85, 0.85]: KitProps.f(self, "pottedPlant", Vector3(dp.x + sx, dp.y, dp.z + 0.35), 0.0, false)
			KitProps.f(self, "rugDoormat", Vector3(dp.x, dp.y + 0.01, dp.z + 0.45), 0.0, false)
		var gx := c.x + 1.3
		_box(Vector3(0.08, 1.0, 0.08), Vector3(gx, y, front - 0.25), _mat(Color("4a4a52")), false)
		_box(Vector3(0.3, 0.25, 0.45), Vector3(gx, y + 1.0, front - 0.25), _mat([Color("b56a5a"), Color("4a6a8a"), Color("3f6b2f"), Color("1b0c15")][rng.randi() % 4]))
		var dw: String = String(doors[doors.size() - 1].get("owner", owner_row(int(l["order"])).get("handle", "")))
		_msgboard(Vector3(gx, y, front - 0.25), Vector3(gx, y, front + 0.55), "h%d" % int(l["order"]), "Mailbox — notes for %s" % (dw if dw != "" else "this house"))
		KitProps.f(self, "trashcan", Vector3(c.x - 1.5, y, front - 0.4), 0.0)
	var who: String = String(owner_row(int(l["order"])).get("handle", "")) if not _is_mine(int(l["order"])) else ""
	BackYards.build(self, c, back + 0.4, c.z - hs.z / 2.0 - 0.3, half * 2.0 - 0.5, who, hash("back/" + String(l["id"])))

## 뒤뜰 끝(가게·공방 짐 마당이 쓴다)
static func back_line(l: Dictionary) -> float:
	return (l["c"] as Vector2).y - 9.5

## 가게 — 큰길가. 차양·간판·종류마다 가게 앞·칠판(한 줄 평), 뒤는 짐 마당
func _shop_lot(l: Dictionary, c: Vector3) -> void:
	var sp := TownPlan.house_spec(l)
	var shop := CityMap.shop_of(l)
	var s := HouseStyles.build(self, c, l, sp, ["townhouse", "terrace", "cottage", "bungalow", "townhouse", "turret"][int(l["order"]) % 6])
	doors[doors.size() - 1]["shop_id"] = shops.size()   # 이 문으로 들어가면 가게 방(town_interior)
	var hd := s.z / 2.0
	var aw := _box(Vector3(s.x + 0.3, 0.07, 1.1), c + Vector3(0, 2.25, hd + 0.5), _mat(Color(String(shop["awning"]))), false); aw.rotation.x = 0.28
	_box(Vector3(s.x * 0.8, 0.5, 0.06), c + Vector3(0, 2.45, hd + 0.04), _mat(Color("efe9e2")), false)
	var lb := Label3D.new(); lb.text = String(shop["type"]); lb.font_size = 64; lb.pixel_size = 0.005; lb.modulate = Color("1b0c15"); lb.outline_size = 0
	lb.position = c + Vector3(0, 2.7, hd + 0.08); _add(lb)
	var cx := -s.x / 2.0 + 0.8
	HouseStyles.shop_front(self, c, s, String(shop["type"]), String(shop["item"]))
	BackYards.service(self, c, back_line(l), c.z - s.z / 2.0 - 0.3, int(l["order"]))
	var stand := c + Vector3(s.x / 2.0 + 0.7, 0, hd + 1.3)
	var chalk := _box(Vector3(0.6, 0.9, 0.06), stand, _mat(Color("2f3a2f")), false); chalk.rotation.x = -0.15
	_msgboard(stand, stand + Vector3(0, 0, 0.8), "p%d" % int(l["order"]), "%s — reviews & requests" % String(shop["type"]).capitalize())
	var id := shops.size()
	var sh := { "kind": "shop", "pos": c + Vector3(cx, 0, hd + 1.75), "yaw": PI, "item": String(shop["item"]), "type": String(shop["type"]), "id": id,
		"keeper": { "kind": "keeper", "pos": c + Vector3(0, 0, hd + 1.0), "yaw": 0.0, "shop_id": id } }
	shops.append(sh)

## 진열품 — 집을 수 없게(items 에 안 넣는다) 구역 노드에 그냥 단다
func _add_display(it: Node3D) -> void:
	if it.get_parent(): it.get_parent().remove_child(it)
	_add(it)
	if it in items: items.erase(it)

## 공방(골짜기 동서 끝 큰길가) — 넓고 낮은 평지붕 건물, 간판, 상자·타이어, 큰 쓰레기통·고깔
func _workshop_lot(l: Dictionary, c: Vector3) -> void:
	var sp := TownPlan.house_spec(l)
	_house(c, Vector3(5.4, 2.6, 4.2), Color("cfc7c2"), "iron", true, sp["seed"])
	_box(Vector3(3.0, 0.45, 0.06), c + Vector3(0, 2.3, 2.14), _mat(Color("1b0c15")), false)
	var lb := Label3D.new(); lb.text = ["GARAGE", "TYRES", "PANEL BEATER", "SPARES"][int(l["order"]) % 4]; lb.font_size = 56; lb.pixel_size = 0.005; lb.modulate = Color("f2c84b"); lb.outline_size = 0
	lb.position = c + Vector3(0, 2.53, 2.2); _add(lb)
	for i in 3: _box(Vector3(0.6, 0.6, 0.6), c + Vector3(3.3, (0.6 if i == 2 else 0.0), -1.0 + (i % 2) * 0.7), _mat(Color("b48a5a")))
	for i in 4:
		var t := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.18; tm.outer_radius = 0.34; t.mesh = tm; t.material_override = _mat(Color("2a2a30"))
		t.position = c + Vector3(-3.3, 0.1 + i * 0.16, 0.6); _add(t)
	var rd := "res://assets/models/kenney/roads/"
	KitProps.put(self, rd + "dumpster.glb", c + Vector3(-2.6, 0, -3.6), 0.0, 4.5)
	for i in 3: KitProps.put(self, rd + "construction-cone.glb", c + Vector3(2.0 + i * 0.6, 0, 2.6), 0.0, 4.5, false)
	BackYards.service(self, c, back_line(l), c.z - 2.4, int(l["order"]) * 3)

## 쌈지 정원 — 깎은 생울타리로 두른 작은 정원: 나무 둘, 벤치 둘, 화단, 등(동네 결)
func _green_lot(l: Dictionary, c: Vector3) -> void:
	var th := District.of_block(l["b"])
	var hedge := _mat(Color(String(th["hedge"])))
	var y := c.y
	for side in [-1.0, 1.0]:
		_box(Vector3(0.4, 0.6, 8.0), Vector3(c.x + side * 4.2, y, c.z - 1.0), hedge)
		_box(Vector3(3.0, 0.6, 0.4), Vector3(c.x + side * 2.7, y, c.z + 3.0), hedge)
	_box(Vector3(8.8, 0.6, 0.4), Vector3(c.x, y, c.z - 5.0), hedge)
	_tree(Vector3(c.x - 2.6, y, c.z - 3.2), 1.0); _tree(Vector3(c.x + 2.6, y, c.z - 3.0), 0.95)
	_bench(Vector3(c.x - 1.5, y, c.z + 0.6)); _bench(Vector3(c.x + 1.5, y, c.z + 0.6))
	var bed := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.1; cm.bottom_radius = 1.2; cm.height = 0.25; bed.mesh = cm; bed.material_override = _mat(Color("6a4a32")); bed.position = Vector3(c.x, y + 0.12, c.z - 1.6); _add(bed)
	for f in 8: KitProps.n(self, String(th["flower"]), Vector3(c.x + cos(f * TAU / 8.0) * 0.7, y + 0.25, c.z - 1.6 + sin(f * TAU / 8.0) * 0.7), 0.0, 1.8, false)
	_lamp(Vector3(c.x, y, c.z + 2.6))

## 관공서 — 큰 건물(들어간다), 기둥, 앞 광장(자갈)·분수·벤치·가로등·깃대, 이름판, 알림판(쪽지)
func _civic(c: Vector3, kind: String, name: String) -> void:
	var size: Vector3 = { "town_hall": Vector3(11.0, 3.6, 6.5), "library": Vector3(9.0, 3.2, 6.0), "school": Vector3(12.0, 3.0, 6.0) }.get(kind, Vector3(9, 3, 6))
	var wall: Color = { "town_hall": Color("efe9e2"), "library": Color("b56a5a"), "school": Color("e6d3a5") }.get(kind, Color("dfe6ea"))
	var at := c + Vector3(0, 0, -5.0)
	_house(at, size, wall, "brick", kind != "school", 900 + absi(int(c.x * 3.0 + c.z)))
	doors[doors.size() - 1]["civic"] = kind
	var front := at + Vector3(0, 0, size.z / 2.0)
	for x in [-3.0, -1.0, 1.0, 3.0]:
		if kind == "town_hall": _box(Vector3(0.36, size.y, 0.36), front + Vector3(x * size.x / 9.0, 0, 0.9), _mat(Color("f7f4ef")))
	_box(Vector3(size.x * 0.7, 0.6, 0.08), front + Vector3(0, size.y + 0.1, 0.05), _mat(Color("1b0c15")), false)
	var lb := Label3D.new(); lb.text = name.to_upper(); lb.font_size = 72; lb.pixel_size = 0.005; lb.modulate = Color("f7f4ef"); lb.outline_size = 0
	lb.position = front + Vector3(0, size.y + 0.4, 0.1); _add(lb)
	_path(front + Vector3(0, 0, 0.6), front + Vector3(0, 0, 12.0), 8.0)   # 광장
	water.disc(front + Vector3(0, 0, 7.0), 1.6)
	for s in [-1.0, 1.0]:
		_bench(front + Vector3(s * 5.6, 0, 6.0)); _lamp(front + Vector3(s * 4.6, 0, 10.0))
		_tree(front + Vector3(s * 8.5, 0, 3.0), 1.2); _tree(front + Vector3(s * 8.5, 0, 9.5), 1.1)
	_box(Vector3(0.08, 5.0, 0.08), front + Vector3(size.x / 2.0 + 1.5, 0, 1.5), _mat(Color("4a4a52")), false)
	_box(Vector3(1.0, 0.6, 0.03), front + Vector3(size.x / 2.0 + 2.05, 4.3, 1.5), _mat(Color("ad7096")), false)
	var nb := front + Vector3(-size.x / 2.0 - 1.2, 0, 1.4)
	for sx in [-0.5, 0.5]: _box(Vector3(0.07, 1.4, 0.07), nb + Vector3(sx, 0, 0), _mat(Color("4a4a52")))
	_box(Vector3(1.15, 0.7, 0.05), nb + Vector3(0, 0.7, 0), _mat(Color("2f3a2f")), false)
	_msgboard(nb, nb + Vector3(0, 0, 0.8), "c%s" % kind.substr(0, 10), "%s — notices" % name)
	spots.append({ "pos": front + Vector3(-2.0, 0, 3.0), "kind": "lookout", "yaw": PI })
	match kind:
		"school":
			_swing(at + Vector3(-9.0, 0, 6.0)); _swing(at + Vector3(-6.5, 0, 6.0))
		"library":
			var q := Label3D.new(); q.text = "Quiet, please."; q.font_size = 40; q.pixel_size = 0.004; q.modulate = Color("1b0c15"); q.position = front + Vector3(2.2, 1.6, 0.06); _add(q)

# ── 작은 것들 ──
func _merge_mark() -> Array:
	return [_build_parent, _build_parent.get_child_count(), doors.size(), houses.size()]

func _merge_done(mark: Array) -> void:
	var par: Node3D = mark[0]
	var nodes: Array = []
	for i in range(int(mark[1]), par.get_child_count()): nodes.append(par.get_child(i))
	var ex: Array = []
	for k in range(int(mark[2]), doors.size()): ex.append(doors[k]["hinge"])
	MeshMerge.merge(par, nodes, ex)
	for k in range(int(mark[3]), houses.size()): houses[k]["merged"] = true

## 부술 수 있는 소품의 8m 칸 색인 — 차(car3d _smash_props)가 둘레 아홉 칸만 본다
var _wk_grid := {}
var _wk_count := -1
func wreck_near(p: Vector3) -> Array:
	if wreckables.size() != _wk_count:
		_wk_count = wreckables.size(); _wk_grid.clear()
		for w in wreckables:
			var k := Vector2i(floori((w["at"] as Vector3).x / 8.0), floori((w["at"] as Vector3).z / 8.0))
			if not _wk_grid.has(k): _wk_grid[k] = []
			_wk_grid[k].append(w)
	var out: Array = []
	var c := Vector2i(floori(p.x / 8.0), floori(p.z / 8.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]: out.append_array(_wk_grid.get(c + Vector2i(dx, dz), []))
	return out

## 위층(town_plots)이 정한다 — 사람이 고른 모양, 내 집인가
func _style_for(_l: Dictionary) -> String: return ""
func _is_mine(_k: int) -> bool: return false

## 이 자리를 맡는 구역 — 40m 칸마다 하나(멀면 꺼진다)
func _root_for(at: Vector3) -> Node3D:
	var b := CityMap.block_of(Vector2(at.x, at.z))
	if not _block_nodes.has(b):
		var n := Node3D.new(); n.name = "Block_%d_%d" % [b.x, b.y]; add_child(n)
		_block_nodes[b] = n
		districts.append({ "node": n, "center": CityMap.block_center(b), "on": true })
	return _block_nodes[b]

## 길은 처음에 다 깔려 있다(산골 도시)
func _pave(_l: Dictionary) -> void: pass

## 2초마다(town_traffic) — 성장과 팔 필지 표지판
var _sale_at := 0.0
func _streets_tick() -> void:
	_growth_tick()
	var now := Time.get_ticks_msec() / 1000.0
	if now > _sale_at and has_method("_refresh_sale"):
		_sale_at = now + 6.0; call("_refresh_sale")

func junction_rule(nd: Variant, from: Variant) -> int: return Signals.rule(nd, from)   # 큰길 신호등·골목 멈춤(signals.gd)
func _signal_tick() -> void: Signals.tick()

## 글을 남기는 판 — C 로 보면 시점이 판 앞으로(town_social open_board). 키마다 방에 남는다
func _msgboard(at: Vector3, stand: Vector3, key: String, title: String) -> void:
	var d := at - stand; d.y = 0.0
	spots.append({ "pos": stand, "kind": "msgboard", "yaw": atan2(d.x, d.z), "at": at, "key": key.replace(",", "_").replace("-", "m").substr(0, 20), "title": title })

## 가로등(Kenney light-curved, 9배 = 6m) — 기둥 충돌, 밤엔 켜진다, 차가 받으면 넘어간다
func _street_light(at: Vector3, yaw: float) -> void:
	var g := Node3D.new(); g.set_meta("nomerge", true); _add(g)
	var m := KitProps.mesh_node(RoadTiles.DIR + "light-curved.glb"); m.position = at; m.rotation.y = yaw; m.scale = Vector3.ONE * 9.0; g.add_child(m)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.15; cy.height = 2.0; cs.shape = cy; cs.position = at + Vector3(0, 1.0, 0); sb.add_child(cs); g.add_child(sb)
	var l := OmniLight3D.new(); l.light_color = Color("e8c766"); l.light_energy = 0.8; l.omni_range = 7.0
	l.position = at + Vector3(sin(yaw), 0, cos(yaw)) * -1.6 + Vector3(0, 5.6, 0); g.add_child(l); lamps.append(l)
	var sp := { "pos": at + Vector3(0.3, 0, 0), "kind": "lamp", "yaw": -PI / 2.0 }
	spots.append(sp)
	wreckables.append({ "node": g, "at": at, "r": 0.25, "out": Vector3(0, 0, 1), "spot": sp, "light": l, "whole": true, "rebuild": _street_light.bind(at, yaw) })

## 장소로 가는 길 — 16m 마다 가로등(번갈아 양쪽), 그 사이 나무
func _dress_road(s: Dictionary) -> void:
	var a: Vector3 = s["from"]; var c: Vector3 = s["c"]
	var d := Vector3(c.x - a.x, 0, c.z - a.z); var len := d.length() - 8.0
	var dir := d.normalized(); var side := Vector3(-dir.z, 0, dir.x)
	var off := 2.6 if s["name"] == "tower" else 2.0
	var t := 6.0; var i := 0
	while t < len:
		var p := a + dir * t
		var keep := _build_parent; _build_parent = _root_for(p)
		if absf(p.x) > WorldGen.HUB_X - 2.0 or absf(p.z) > WorldGen.HUB_Z - 2.0:
			_lamp(p + side * off * (1.0 if i % 2 == 0 else -1.0))
			_tree(p + dir * 8.0 + side * (off + 1.4) * (-1.0 if i % 2 == 0 else 1.0), 1.0)
		_build_parent = keep
		t += 16.0; i += 1

## 이정표 — 기둥과 판, 양면 글씨
func _signpost(at: Vector3, text: String) -> void:
	_box(Vector3(0.1, 2.0, 0.1), at, _mat(Color("6b4a35")), false)
	_box(Vector3(1.6, 0.55, 0.05), at + Vector3(0, 1.5, 0), _mat(Color("efe9e2")), false)
	for f in [1.0, -1.0]:
		var lb := Label3D.new(); lb.text = text; lb.font_size = 44; lb.pixel_size = 0.004; lb.modulate = Color("1b0c15"); lb.outline_size = 0
		lb.position = at + Vector3(0, 1.78, 0.03 * f); lb.rotation.y = 0.0 if f > 0.0 else PI; _add(lb)

# ── 가게 주인 ──
func _hire_shopkeepers() -> void:
	for sh in shops:
		if residents.any(func(r: Resident) -> bool: return r.job == "shopkeep" and int(r.get_meta("shop_id", -1)) == int(sh["id"])): continue
		var best: Resident = null; var bd := 1e9
		for r in residents:
			if r.job != "" or r is ResidentKid or r.state == "drive": continue
			var d: float = r.global_position.distance_to(sh["pos"])
			if d < bd: bd = d; best = r
		if best == null: return
		best.job = "shopkeep"; best.set_meta("shop_id", int(sh["id"]))

func shop_open(sh: Dictionary) -> bool:
	for r in residents:
		if r.job == "shopkeep" and int(r.get_meta("shop_id", -1)) == int(sh["id"]) and r.state == "busy" and String(r.spot.get("kind", "")) == "keeper": return true
	return false

func _keeper(sh: Dictionary) -> Resident:
	for r in residents:
		if r.job == "shopkeep" and int(r.get_meta("shop_id", -1)) == int(sh["id"]): return r
	return null
