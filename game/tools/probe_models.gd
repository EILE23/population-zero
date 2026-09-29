extends SceneTree
func _init() -> void:
	var n: Node3D = (load("res://assets/models/vehicles/sedan.glb") as PackedScene).instantiate(); root.add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i) as BaseMaterial3D
			print("PROBE ", m.name, " surf ", i, " tex=", mat.albedo_texture != null if mat else "nomat", " col=", mat.albedo_color if mat else "", " vcol=", mat.vertex_color_use_as_albedo if mat else "")
	quit()
