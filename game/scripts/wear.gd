class_name Wear
extends RefCounted
## 입는 것 — 리그의 소켓(socket_hat · socket_face · socket_back)에 붙는 원시 도형. 전부 코드(운영자 2026-09-28: 꾸미기).
## kind: cap · beanie · tophat · straw · glasses · sunglasses · backpack · scarf. make() 가 Node3D 를 돌려주고 meta "kind"/"slot" 을 단다.

const SLOT := { "cap": "hat", "beanie": "hat", "tophat": "hat", "straw": "hat", "glasses": "face", "sunglasses": "face", "backpack": "back", "scarf": "back" }
const KINDS := ["cap", "beanie", "tophat", "straw", "glasses", "sunglasses", "backpack", "scarf"]

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON; m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED; m.roughness = 1.0
	return m

static func _mesh(parent: Node3D, mesh: Mesh, c: Color, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = _mat(c); mi.position = at; mi.rotation = rot; parent.add_child(mi); return mi

## 종류별 모양 — 머리 반지름 0.19 기준. 원점은 소켓 위치(모자: 머리 꼭대기, 얼굴: 얼굴 앞, 등: 등 뒤)
static func make(kind: String, color := Color("ad7096")) -> Node3D:
	var n := Node3D.new(); n.set_meta("kind", kind); n.set_meta("slot", SLOT.get(kind, "hat")); n.set_meta("wearable", true)
	match kind:
		"cap":
			var cy := CylinderMesh.new(); cy.top_radius = 0.19; cy.bottom_radius = 0.2; cy.height = 0.12
			_mesh(n, cy, color, Vector3(0, -0.05, 0))
			var bill := BoxMesh.new(); bill.size = Vector3(0.22, 0.02, 0.16)
			_mesh(n, bill, color.darkened(0.15), Vector3(0, -0.1, 0.2), Vector3(0.15, 0, 0))
		"beanie":
			var sp := SphereMesh.new(); sp.radius = 0.21; sp.height = 0.3
			_mesh(n, sp, color, Vector3(0, -0.04, 0))
			var pom := SphereMesh.new(); pom.radius = 0.05; pom.height = 0.1
			_mesh(n, pom, Color("f7f4ef"), Vector3(0, 0.15, 0))
		"tophat":
			var brim := CylinderMesh.new(); brim.top_radius = 0.26; brim.bottom_radius = 0.26; brim.height = 0.02
			_mesh(n, brim, Color("1b0c15"), Vector3(0, -0.06, 0))
			var crown := CylinderMesh.new(); crown.top_radius = 0.17; crown.bottom_radius = 0.17; crown.height = 0.26
			_mesh(n, crown, Color("1b0c15"), Vector3(0, 0.08, 0))
			var band := CylinderMesh.new(); band.top_radius = 0.175; band.bottom_radius = 0.175; band.height = 0.04
			_mesh(n, band, color, Vector3(0, -0.02, 0))
		"straw":
			var brim := CylinderMesh.new(); brim.top_radius = 0.32; brim.bottom_radius = 0.32; brim.height = 0.02
			_mesh(n, brim, Color("e6d3a5"), Vector3(0, -0.06, 0))
			var crown := CylinderMesh.new(); crown.top_radius = 0.16; crown.bottom_radius = 0.19; crown.height = 0.14
			_mesh(n, crown, Color("e6d3a5"), Vector3(0, 0.02, 0))
			var band := CylinderMesh.new(); band.top_radius = 0.195; band.bottom_radius = 0.195; band.height = 0.035
			_mesh(n, band, color, Vector3(0, -0.03, 0))
		"glasses", "sunglasses":
			var lens := Color("1b0c15") if kind == "sunglasses" else Color("dfe6ea")
			for ex in [-0.075, 0.075]:
				var ring := TorusMesh.new(); ring.inner_radius = 0.045; ring.outer_radius = 0.06
				_mesh(n, ring, Color("1b0c15"), Vector3(ex, 0, 0), Vector3(PI / 2.0, 0, 0))
				var gl := CylinderMesh.new(); gl.top_radius = 0.045; gl.bottom_radius = 0.045; gl.height = 0.01
				_mesh(n, gl, lens, Vector3(ex, 0, 0), Vector3(PI / 2.0, 0, 0))
			var bridge := BoxMesh.new(); bridge.size = Vector3(0.04, 0.012, 0.012)
			_mesh(n, bridge, Color("1b0c15"), Vector3(0, 0, 0))
			for ex in [-0.13, 0.13]:
				var arm := BoxMesh.new(); arm.size = Vector3(0.012, 0.012, 0.18)
				_mesh(n, arm, Color("1b0c15"), Vector3(ex, 0.0, -0.09))
		"backpack":
			var bag := BoxMesh.new(); bag.size = Vector3(0.24, 0.3, 0.12)
			_mesh(n, bag, color, Vector3(0, 0, -0.06))
			var flap := BoxMesh.new(); flap.size = Vector3(0.24, 0.1, 0.13)
			_mesh(n, flap, color.darkened(0.2), Vector3(0, 0.12, -0.06))
			for ex in [-0.08, 0.08]:
				var strap := BoxMesh.new(); strap.size = Vector3(0.03, 0.28, 0.03)
				_mesh(n, strap, Color("3a2f36"), Vector3(ex, 0.02, 0.05))
		"scarf":
			var ring := TorusMesh.new(); ring.inner_radius = 0.07; ring.outer_radius = 0.13
			_mesh(n, ring, color, Vector3(0, 0.16, 0.02), Vector3(PI / 2.0, 0, 0))
			var tail := BoxMesh.new(); tail.size = Vector3(0.08, 0.26, 0.03)
			_mesh(n, tail, color, Vector3(0.06, 0.02, 0.1), Vector3(0.1, 0, -0.2))
	return n

## 사람 색에 어울리는 소품 색 — 모브·잎·하늘·붉은 벽돌 중에서 시드로
static func palette(seed: int) -> Color:
	return [Color("ad7096"), Color("7a9b4e"), Color("8fb8cc"), Color("b56a5a"), Color("e8c766"), Color("4a4a52")][seed % 6]
