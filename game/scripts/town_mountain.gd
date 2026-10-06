class_name TownMountain
extends TownSites
## 산(운영자 2026-10-06: "실제 산이 돼야", "산스장도", "차로는 못 올라갈… 사람만 올라갈 수 있게") — 땅 모양은 WorldGen.PEAKS, 여기선 사람이 쓰는 것들:
##   들머리(_site_pell·_site_gorse — WorldGen.SITES 라 큰길에서 자갈길이 이어진다): 표지판, 볼라드 셋(차 폭 1.5m 보다 좁게 1.0m 간격), 벤치
##   돌계단(_trail): 나선 길을 따라 한 단 RISE(28cm)씩 — 경사판이 없어 차는 첫 단에서 선다. 계단은 한 덩어리(MultiMesh 그리기 한 번 + 충돌 한 몸)라 구역 끄기(48m)와 상관없이 늘 있다
##   꼭대기(_summit): Mt. Pell 은 산스장(턱걸이 봉·윗몸일으키기 매트·허리돌리기 원판·스쿼트 자리 — C 로 쓴다, 자세는 gym_poses.gd), 정상석, 벤치, 전망 자리. Gorse Hill 은 정자

const GYM_LINES := {
	"pullup": "Pull-ups. The bar is cold.",
	"situp": "Sit-ups. The mat has seen things.",
	"twist": "The waist twister. It squeaks on the left.",
	"squat": "Squats. The footprints are painted on.",
}

func _mountains() -> void:
	for pk in WorldGen.PEAKS:
		_trail(pk)
		var c: Vector3 = pk["c"]
		var top := Vector3(c.x, gen.summit_y(pk), c.z)
		_district("top_" + String(pk["name"]), top, func(at: Vector3) -> void: _summit(at, pk))

func _peak(name: String) -> Dictionary:
	for pk in WorldGen.PEAKS:
		if pk["name"] == name: return pk
	return {}

func _site_pell(c: Vector3) -> void: _trailhead(c, _peak("pell"))
func _site_gorse(c: Vector3) -> void: _trailhead(c, _peak("gorse"))

## 들머리 — 길 끝에 볼라드 셋(사람은 사이로 지나가고 차는 못 지난다), 표지판(이름·높이·계단뿐), 벤치
func _trailhead(c: Vector3, pk: Dictionary) -> void:
	var from := c
	for s in WorldGen.SITES:
		if s["name"] == pk["name"]: from = s["from"]
	var dir := Vector3(c.x - from.x, 0, c.z - from.z).normalized()   # 마을에서 들머리로 오는 방향 — 볼라드는 이 길을 가로지른다
	var side := Vector3(-dir.z, 0, dir.x)
	c -= dir * 3.0
	var iron := _mat(Color("4a4a52")); var stone := _mat(Color("bfb6b0"))
	for i in [-1.0, 0.0, 1.0]:
		var b := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.09; cm.bottom_radius = 0.11; cm.height = 0.9; b.mesh = cm; b.material_override = iron
		b.position = c - dir * 1.5 + side * i * 1.0 + Vector3(0, 0.45, 0); _add(b)
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.11; cy.height = 0.9; cs.shape = cy; sb.add_child(cs); b.add_child(sb)
	var post := _box(Vector3(0.1, 1.6, 0.1), c - dir * 2.5 + side * 2.2, _mat(Color("6b4a35")), false)
	_box(Vector3(1.5, 0.8, 0.06), c - dir * 2.5 + side * 2.2 + Vector3(0, 1.25, 0), _mat(Color("efe9e2")), false)
	post.rotation.y = atan2(dir.x, dir.z)
	var lb := Label3D.new(); lb.font_size = 56; lb.pixel_size = 0.004; lb.modulate = Color("1b0c15"); lb.outline_size = 0
	lb.text = "%s  %d m\nSTAIRS ONLY. NO VEHICLES.\n%s" % [pk["title"], int(gen.summit_y(pk)), "Outdoor gym at the top." if pk["gym"] else "Pavilion at the top."]
	lb.position = c - dir * 2.5 + side * 2.2 + Vector3(0, 1.68, 0) - dir * 0.05; lb.rotation.y = atan2(-dir.x, -dir.z); _add(lb)
	_bench(c - dir * 3.5 - side * 2.6)
	_path(c - dir * 3.0, c + dir * 3.0, 1.8)   # 자갈길을 볼라드 너머 첫 단까지

## 돌계단 — 나선 점마다 그 자리(가운데·양옆 0.7m) 땅보다 높게, RISE 단위로. 앞뒤 단 차이는 RISE 를 넘지 않게 두 번 고른다(사람의 턱 오르기 0.42 안)
func _trail(pk: Dictionary) -> void:
	var pts := WorldGen.trail_xz(pk)
	var n := pts.size()
	var tops := PackedFloat32Array(); tops.resize(n)
	var lows := PackedFloat32Array(); lows.resize(n)
	for i in n:
		var a := pts[maxi(i - 1, 0)]; var b := pts[mini(i + 1, n - 1)]
		var t := (b - a).normalized(); var sd := Vector2(-t.y, t.x) * 0.7
		var hs := [gen.height(pts[i].x, pts[i].y), gen.height(pts[i].x + sd.x, pts[i].y + sd.y), gen.height(pts[i].x - sd.x, pts[i].y - sd.y)]
		tops[i] = ceilf((hs.max() + 0.12) / WorldGen.RISE) * WorldGen.RISE
		lows[i] = hs.min() - 0.5
	for i in range(n - 2, -1, -1): tops[i] = maxf(tops[i], tops[i + 1] - WorldGen.RISE)   # 오를 때 한 단이 RISE 를 넘지 않게
	for i in range(1, n): tops[i] = maxf(tops[i], tops[i - 1] - WorldGen.RISE)            # 내려올 때도
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	var bm := BoxMesh.new(); bm.size = Vector3.ONE; mm.mesh = bm
	var xs: Array[Transform3D] = []
	var sb := StaticBody3D.new(); sb.name = "Trail_" + String(pk["name"]); add_child(sb)
	var i := 0
	while i < n - 1:
		var j := i
		while j + 1 < n and j - i < 2 and is_equal_approx(tops[j + 1], tops[i]): j += 1   # 같은 높이 셋까지 한 판
		var a := pts[i]; var b := pts[j if j > i else i + 1]
		var mid := (a + b) * 0.5; var len := a.distance_to(b) + WorldGen.TREAD
		var low := lows[i]
		for k in range(i, j + 1): low = minf(low, lows[k])
		var hgt := tops[i] - low
		var yaw := atan2(b.x - a.x, b.y - a.y)
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(mid.x, low + hgt / 2.0, mid.y))
		xs.append(xf * Transform3D(Basis.from_scale(Vector3(1.5, hgt, len)), Vector3.ZERO))
		var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(1.5, hgt, len); cs.shape = bx; cs.transform = xf; sb.add_child(cs)
		i = j + 1
	mm.instance_count = xs.size()
	for k in xs.size():
		mm.set_instance_transform(k, xs[k])
		mm.set_instance_color(k, Color(0.78, 0.74, 0.7) if k % 2 == 0 else Color(0.66, 0.62, 0.6))   # 단마다 번갈아 — 흰 판 한 장으로 읽혔다
	var sm := _mat(Color.WHITE, _tex("ground/cobble"), Vector3(1.3, 1.3, 1.3)); sm.uv1_triplanar = true; sm.uv1_world_triplanar = true; sm.vertex_color_use_as_albedo = true
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = sm; sb.add_child(mmi)

## 꼭대기 마당
func _summit(c: Vector3, pk: Dictionary) -> void:
	var iron := _mat(Color("4a4a52")); var stone := _mat(Color("bfb6b0")); var wood := _mat(Color("8a6a4a"))
	var to_town := Vector3(-c.x, 0, -c.z).normalized()
	var face := atan2(to_town.x, to_town.z)
	# 정상석 — 이름과 높이
	var st := _box(Vector3(0.9, 1.2, 0.5), c + Vector3(0, 0, 0), stone)
	st.rotation.y = face
	var lb := Label3D.new(); lb.font_size = 72; lb.pixel_size = 0.004; lb.modulate = Color("1b0c15"); lb.outline_size = 0
	lb.text = "%s\n%d m" % [pk["title"], int(c.y)]; lb.position = c + Vector3(0, 0.75, 0) + to_town * 0.26; lb.rotation.y = face; _add(lb)
	# 남쪽(마을 쪽) 끝 — 벤치 둘과 전망 자리
	var edge := c + to_town * (float(pk["top"]) - 3.0)
	var side := Vector3(-to_town.z, 0, to_town.x)
	for s in [-1.5, 1.5]:
		_bench(edge + side * s)
	spots.append({ "pos": edge + to_town * 1.4, "kind": "lookout", "yaw": face })
	_lamp(edge - side * 3.4)
	if pk["gym"]: _gym(c, to_town, side, iron, wood)
	else: _pavilion(c - to_town * 4.0, wood)
	for k in 7:   # 마당 가장자리 나무(벼랑 띠 위)
		var a := k * TAU / 7.0 + 0.4
		var p := c + Vector3(cos(a), 0, sin(a)) * (float(pk["top"]) - 1.2)
		if Vector2(p.x - edge.x, p.z - edge.z).length() > 5.0: _tree(Vector3(p.x, gen.height(p.x, p.z), p.z), 1.15)

## 산스장 — 마당 북쪽 절반에 한 줄. 기구마다 C 자리(kind gym, ex = 자세 이름)
func _gym(c: Vector3, fwd: Vector3, side: Vector3, iron: Material, wood: Material) -> void:
	var back := c - fwd * 4.5
	var yaw := atan2(fwd.x, fwd.z)
	# 턱걸이 봉 — 기둥 둘 + 가로봉
	var pb := back - side * 4.5
	for s in [-0.65, 0.65]: _box(Vector3(0.08, 2.3, 0.08), pb + side * s, iron)
	var bar := _box(Vector3(1.4, 0.05, 0.05), pb + Vector3(0, 2.18, 0), iron, false); bar.rotation.y = yaw
	spots.append({ "pos": pb + fwd * 0.05, "kind": "gym", "ex": "pullup", "yaw": yaw })
	# 윗몸일으키기 매트
	var mt := back - side * 1.6
	var mat := _box(Vector3(0.7, 0.04, 1.6), mt, _mat(Color("7b526c")), false); mat.rotation.y = yaw
	spots.append({ "pos": mt + fwd * 0.45, "kind": "gym", "ex": "situp", "yaw": yaw })
	# 허리돌리기 — 원판 + 손잡이 틀
	var tw := back + side * 1.4
	var disc := MeshInstance3D.new(); var dm := CylinderMesh.new(); dm.top_radius = 0.38; dm.bottom_radius = 0.4; dm.height = 0.08; disc.mesh = dm; disc.material_override = _mat(Color("d8a24a"))
	disc.position = tw + Vector3(0, 0.04, 0); _add(disc)
	for s in [-0.35, 0.35]: _box(Vector3(0.06, 1.1, 0.06), tw - fwd * 0.45 + side * s, iron)
	var hb := _box(Vector3(0.76, 0.05, 0.05), tw - fwd * 0.45 + Vector3(0, 1.05, 0), iron, false); hb.rotation.y = yaw
	spots.append({ "pos": tw, "kind": "gym", "ex": "twist", "yaw": yaw })
	# 스쿼트 자리 — 발 모양 칠한 판 + 팻말
	var sq := back + side * 4.2
	var pad := _box(Vector3(0.8, 0.03, 0.6), sq, _mat(Color("efe9e2")), false); pad.rotation.y = yaw
	spots.append({ "pos": sq, "kind": "gym", "ex": "squat", "yaw": yaw })
	# 산스장 간판
	var sp := back - fwd * 1.6
	for s in [-1.1, 1.1]: _box(Vector3(0.08, 1.8, 0.08), sp + side * s, _mat(Color("6b4a35")), false)
	var board := _box(Vector3(2.4, 0.7, 0.06), sp + Vector3(0, 1.2, 0), _mat(Color("efe9e2")), false); board.rotation.y = yaw
	var lb := Label3D.new(); lb.font_size = 56; lb.pixel_size = 0.004; lb.modulate = Color("1b0c15"); lb.outline_size = 0
	lb.text = "OUTDOOR GYM\nWipe the bar after use.  — The Management"; lb.position = sp + Vector3(0, 1.55, 0) + fwd * 0.04; lb.rotation.y = yaw; _add(lb)
	_bench(back + fwd * 2.2 - side * 0.0)

## 정자(Gorse Hill) — 기둥 넷, 지붕 판 둘, 마루
func _pavilion(at: Vector3, wood: Material) -> void:
	_box(Vector3(3.2, 0.3, 3.2), at, wood)
	for x in [-1.4, 1.4]:
		for z in [-1.4, 1.4]: _box(Vector3(0.14, 2.4, 0.14), at + Vector3(x, 0.3, z), wood)
	_box(Vector3(3.8, 0.12, 3.8), at + Vector3(0, 2.7, 0), _mat(Color("5a4a52")), false)
	_box(Vector3(2.6, 0.3, 2.6), at + Vector3(0, 2.82, 0), _mat(Color("5a4a52")), false)
	spots.append({ "pos": at + Vector3(0, 0.3, 1.0), "kind": "lookout", "yaw": 0.0 })

## C 로 기구를 쓴다 — 그 자리에 서서(누워서) 9초 되풀이. 움직이면 그만둔다(감정 표현과 같은 길: town_social._emote)
func gym_use(sp: Dictionary, now: float) -> void:
	body.global_position = (sp["pos"] as Vector3) + Vector3(0, 0.05, 0); body.velocity = Vector3.ZERO
	player.face(float(sp["yaw"]))
	action_until = now - 0.01
	call("_emote", String(sp["ex"]), 9.0)
	say_toast(String(GYM_LINES.get(sp["ex"], "")))
