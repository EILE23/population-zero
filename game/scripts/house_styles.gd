class_name HouseStyles
extends RefCounted
## 집 바깥 모양(운영자 2026-10-06: "집이나 카페들의 형태도 다양해야") — 같은 _house(문·실내·컷어웨이·자리)에 덧채를 붙여 모양을 바꾼다.
## 오두막(울타리·창 화분) · 타운하우스(좁고 2층) · 방갈로(넓고 낮은, 베란다) · 차고 집 · 날개채 집(뒤로 ㄱ자) · 탑 집(모서리 둥근 탑) · 옥상 정원 집.
## 가게는 종류마다 가게 앞이 다르다: 카페 테라스, 빵집 굴뚝·빵 바구니, 식료품 상자, 책 수레, 생선 얼음 상자, 신문대, 우산 꽂이
## 필지 폭 7.4m 안에 들어가게(덧채는 옆으론 좁게, 길게는 뒤로)

const STYLES := ["cottage", "townhouse", "bungalow", "garage", "wing", "turret", "terrace", "cottage", "townhouse"]

static func style_of(l: Dictionary) -> String:
	var rng := RandomNumberGenerator.new(); rng.seed = hash("style/" + String(l["id"]))
	return STYLES[rng.randi() % STYLES.size()]

## 집 하나 — 크기는 모양이 정하고 나머지(벽 빛깔·지붕·시드)는 사양(TownPlan.house_spec)
static func build(t: Node, c: Vector3, l: Dictionary, sp: Dictionary, style := "") -> Vector3:
	if style == "": style = style_of(l)
	var rng := RandomNumberGenerator.new(); rng.seed = int(sp["seed"]) * 31 + 7
	var s: Vector3 = sp["size"]; var wall: Color = sp["wall"]; var roof: String = sp["roof"]; var seed: int = sp["seed"]
	var m := func(col: Color) -> Material: return t.call("_mat", col)
	match style:
		"townhouse":
			s = Vector3(3.5, 2.7, 3.6); t.call("_house", c, s, wall, roof, false, seed, "", 2)
			for wx in [-0.9, 0.9]: t.call("_box", Vector3(0.8, 0.18, 0.25), c + Vector3(wx, 3.1, s.z / 2.0 + 0.12), m.call(Color("8a6a4a")), false)   # 2층 창 화분
		"bungalow":
			s = Vector3(5.4, 2.4, 3.4); t.call("_house", c, s, wall, roof, false, seed, "", 1)
			var deck := c + Vector3(0, 0, s.z / 2.0 + 0.9)
			t.call("_box", Vector3(s.x + 0.2, 0.14, 1.3), deck + Vector3(0, 0, 0.15), m.call(Color("b48a5a")))
			for px in [-s.x / 2.0, s.x / 2.0]: t.call("_box", Vector3(0.12, 2.2, 0.12), deck + Vector3(px, 0.14, 0.7), m.call(Color("efe9e2")))
			var vr: MeshInstance3D = t.call("_box", Vector3(s.x + 0.5, 0.08, 1.6), deck + Vector3(0, 2.32, 0.2), m.call(Color("6b4a35")), false); vr.rotation.x = 0.12
		"garage":
			s = Vector3(3.9, 2.6, 3.6); var hc := c - Vector3(0.9, 0, 0)
			t.call("_house", hc, s, wall, roof, false, seed, "", 1)
			var gx := hc.x + s.x / 2.0 + 1.15
			t.call("_box", Vector3(2.2, 2.3, s.z), Vector3(gx, 0, hc.z), m.call(wall.darkened(0.08)))
			t.call("_box", Vector3(1.8, 1.8, 0.05), Vector3(gx, 0, hc.z + s.z / 2.0 + 0.03), m.call(Color("cfc7c2")), false)   # 셔터
			for k in 6: t.call("_box", Vector3(1.8, 0.02, 0.06), Vector3(gx, 0.3 * k + 0.15, hc.z + s.z / 2.0 + 0.06), m.call(Color("8a8a92")), false)
			t.call("_box", Vector3(2.3, 0.12, s.z + 0.1), Vector3(gx, 2.3, hc.z), m.call(Color("5a4a52")), false)
			s.x += 2.2
		"wing":
			t.call("_house", c, s, wall, roof, false, seed, "", 1)
			var wz := c.z - s.z / 2.0 - 1.4; var wx := c.x + (1.0 if rng.randf() < 0.5 else -1.0) * s.x * 0.22
			t.call("_box", Vector3(s.x * 0.55, 2.2, 2.8), Vector3(wx, 0, wz), m.call(wall))
			t.call("_box", Vector3(s.x * 0.55 + 0.2, 0.12, 3.0), Vector3(wx, 2.2, wz), m.call(Color("5a4a52")), false)
			t.call("_box", Vector3(0.05, 0.8, 0.9), Vector3(wx + s.x * 0.275 + 0.01, 1.0, wz), m.call(Color("bfe3f2")), false)
		"turret":
			t.call("_house", c, s, wall, roof, false, seed, "", 1)
			var tp := c + Vector3(-s.x / 2.0 + 0.1, 0, s.z / 2.0 - 0.3)
			var tw := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.75; cm.bottom_radius = 0.75; cm.height = s.y + 1.3; tw.mesh = cm; tw.material_override = m.call(wall.lightened(0.05))
			tw.position = tp + Vector3(0, cm.height / 2.0, 0); t.call("_add", tw)
			var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.75; cy.height = cm.height; cs.shape = cy; sb.add_child(cs); tw.add_child(sb)
			var cone := MeshInstance3D.new(); var cn := CylinderMesh.new(); cn.top_radius = 0.0; cn.bottom_radius = 0.95; cn.height = 1.3; cone.mesh = cn; cone.material_override = m.call(Color("7b526c"))
			cone.position = tp + Vector3(0, cm.height + 0.65, 0); t.call("_add", cone)
			t.call("_box", Vector3(0.4, 0.6, 0.04), tp + Vector3(0, s.y + 0.2, 0.74), m.call(Color("bfe3f2")), false)
		"terrace":
			t.call("_house", c, Vector3(s.x, 2.6, s.z), wall, roof, true, seed, "", 1)
			for k in 4: t.call("_scatter", ["Bush_Common_Flowers", "Plant_1", "Flower_3_Group", "Bush_Common"][k], c + Vector3(-s.x / 2.0 + 0.6 + k * (s.x - 1.2) / 3.0, 2.78, -s.z / 2.0 + 0.6), 0.55)
		_:   # cottage
			t.call("_house", c, s, wall, roof, false, seed, "", 1)
			var fz := c.z + s.z / 2.0 + 1.9
			for side in [-1.0, 1.0]:
				for k in 5: t.call("_box", Vector3(0.06, 0.6, 0.06), Vector3(c.x + side * (0.9 + k * 0.42), 0, fz), m.call(Color("f7f4ef")), false)   # 울타리(문길은 비운다)
				t.call("_box", Vector3(1.8, 0.05, 0.04), Vector3(c.x + side * 1.75, 0.45, fz), m.call(Color("f7f4ef")), false)
	return s

## 가게 앞 — 종류마다(가게 방 안은 town_interior)
static func shop_front(t: Node, c: Vector3, s: Vector3, type: String, item: String) -> void:
	var hd := s.z / 2.0
	var m := func(col: Color) -> Material: return t.call("_mat", col)
	var disp := func(kind: String, at: Vector3) -> void:
		var it: Node3D = t.call("make_item", kind, at); t.call("_add_display", it)
	match type:
		"CAFE":
			for k in 2:
				var tb := c + Vector3(-1.4 + k * 2.8, 0, hd + 2.0)
				var top := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.38; cm.bottom_radius = 0.38; cm.height = 0.04; top.mesh = cm; top.material_override = m.call(Color("f7f4ef")); top.position = tb + Vector3(0, 0.72, 0); t.call("_add", top)
				t.call("_box", Vector3(0.06, 0.7, 0.06), tb, m.call(Color("4a4a52")), false)
				for sx in [-0.55, 0.55]: t.call("_box", Vector3(0.36, 0.45, 0.36), tb + Vector3(sx, 0, 0), m.call(Color("ad7096")), false)
				disp.call("cup", tb + Vector3(0.1, 0.74, 0.05))
			var ab: MeshInstance3D = t.call("_box", Vector3(0.6, 0.85, 0.05), c + Vector3(1.9, 0, hd + 1.0), m.call(Color("2f3a2f")), false); ab.rotation.x = -0.2
			var lb := Label3D.new(); lb.text = "COFFEE 2\nTEA 2"; lb.font_size = 36; lb.pixel_size = 0.003; lb.modulate = Color("f7f4ef"); lb.outline_size = 0; lb.position = c + Vector3(1.9, 0.55, hd + 1.04); t.call("_add", lb)
		"BAKERY":
			t.call("_box", Vector3(0.5, 1.6, 0.5), c + Vector3(s.x / 2.0 - 0.5, s.y, -0.4), m.call(Color("b56a5a")), false)
			t.call("_box", Vector3(0.9, 0.5, 0.6), c + Vector3(1.6, 0, hd + 0.9), m.call(Color("c9a27a")))
			for k in 3: disp.call("bread", c + Vector3(1.35 + k * 0.25, 0.5, hd + 0.9))
		"GROCER":
			for k in 3:
				var cr: MeshInstance3D = t.call("_box", Vector3(0.7, 0.45, 0.5), c + Vector3(-1.9 + k * 0.8, 0, hd + 1.1), m.call(Color("b48a5a"))); cr.rotation.x = -0.15
				for q in 3: disp.call("apple", c + Vector3(-2.1 + k * 0.8 + q * 0.18, 0.47, hd + 1.1))
		"BOOKSHOP":
			t.call("_box", Vector3(1.2, 0.8, 0.5), c + Vector3(1.7, 0, hd + 1.0), m.call(Color("8a6a4a")))
			for k in 4: disp.call("book", c + Vector3(1.25 + k * 0.28, 0.8, hd + 1.0))
		"FISHMONGER":
			t.call("_box", Vector3(1.2, 0.7, 0.6), c + Vector3(1.6, 0, hd + 1.0), m.call(Color("dfe6ea")))
			for k in 3: disp.call("fish", c + Vector3(1.25 + k * 0.33, 0.72, hd + 1.0))
		"CORNER SHOP":
			t.call("_box", Vector3(0.7, 1.1, 0.4), c + Vector3(1.8, 0, hd + 0.9), m.call(Color("b56a5a")))
			for k in 3: disp.call("can", c + Vector3(1.6 + k * 0.2, 1.1, hd + 0.9))
		"UMBRELLAS":
			var bk := MeshInstance3D.new(); var bc := CylinderMesh.new(); bc.top_radius = 0.25; bc.bottom_radius = 0.2; bc.height = 0.5; bk.mesh = bc; bk.material_override = m.call(Color("4a4a52")); bk.position = c + Vector3(1.8, 0.25, hd + 0.9); t.call("_add", bk)
