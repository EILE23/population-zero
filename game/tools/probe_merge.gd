extends SceneTree
## 구역 하나의 자식 — 보이는/숨긴 메시, Merged 수, 재질 종류(합치기가 됐나)
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await process_frame
	while not town._due.is_empty(): await process_frame
	for i in 400: await process_frame
	var best: Node3D = null; var bn := 0
	for d in town.districts:
		var n: Node3D = d["node"]
		if n.get_child_count() > bn: bn = n.get_child_count(); best = n
	var vis := 0; var hid := 0; var merged := 0; var why := {}
	for ch in best.get_children():
		if ch.name.begins_with("Merged"): merged += 1; continue
		if ch is MeshInstance3D:
			if (ch as MeshInstance3D).visible: vis += 1
			else: hid += 1
			if (ch as MeshInstance3D).visible:
				var mi := ch as MeshInstance3D
				var mat: Material = mi.material_override
				var r := "mesh=%s col=%s sz=%s idx=%d" % [mi.mesh.get_class() if mi.mesh else "-", (mat as StandardMaterial3D).albedo_color.to_html().substr(0, 6) if mat is StandardMaterial3D else "", str(mi.get_aabb().size.snapped(Vector3.ONE * 0.5)), ch.get_index() / 200 * 200]
				if mat is StandardMaterial3D: r += " tr=%d" % (mat as StandardMaterial3D).transparency
				r += " live=%s meta=%s" % [str(MeshMerge._has_live_child(mi)), str(mi.get_meta_list())]
				why[r] = int(why.get(r, 0)) + 1
	print("PM %s children=%d mesh_visible=%d hidden=%d merged=%d" % [best.name, bn, vis, hid, merged])
	var ks: Array = why.keys(); ks.sort_custom(func(a, b): return why[a] > why[b])
	for k in ks.slice(0, 25): print("PM  ", why[k], " ", k)
	quit()
