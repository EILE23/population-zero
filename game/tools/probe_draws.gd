extends SceneTree
## 보이는 메시 수 — 장면 파일(팩 모델)별, 합친 것, 그 밖
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 30: await process_frame
	var by := {}
	for m in town.find_children("*", "GeometryInstance3D", true, false):
		if not (m as Node3D).is_visible_in_tree(): continue
		var p: Node = m; var src := ""
		while p and p != town:
			if p.scene_file_path != "": src = p.scene_file_path.get_file(); break
			p = p.get_parent()
		if src == "":
			var top: Node = m
			while top.get_parent() and top.get_parent() != town: top = top.get_parent()
			var mesh_k := ""
			if m is MeshInstance3D and (m as MeshInstance3D).mesh: mesh_k = (m as MeshInstance3D).mesh.get_class()
			src = "merged" if m.name.begins_with("Merged") else "%s@%s %s" % [m.get_class(), String(top.name).substr(0, 12), mesh_k]
		by[src] = int(by.get(src, 0)) + 1
	var ks: Array = by.keys(); ks.sort_custom(func(a, b): return by[a] > by[b])
	for k in ks.slice(0, 18): print("DRAW %s %d" % [k, by[k]])
	quit()
