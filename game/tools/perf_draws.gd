extends SceneTree
## 내려다본(줌 12) 화면에 그려지는 것 — 보이는 메시 노드를 이름·메시별로 센다(시야 안·보이는 범위 안)
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await process_frame
	while not town._due.is_empty(): await process_frame
	town.zoom_want = 12.0; town.zoom = 12.0
	for i in 400: await process_frame
	var cam: Camera3D = town.cam
	var cnt := {}; var tri := {}; var total := 0
	var stack: Array = [town]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is Node3D and not (nd as Node3D).visible: continue
		stack.append_array(nd.get_children())
		if not (nd is MeshInstance3D or nd is MultiMeshInstance3D): continue
		var g := nd as GeometryInstance3D
		var p := g.global_position
		if not cam.is_position_in_frustum(p) and g.get_aabb().size.length() < 30.0: continue
		var dcam := p.distance_to(cam.global_position)
		if g.visibility_range_end > 0.0 and dcam > g.visibility_range_end: continue
		var k := ""
		if nd is MeshInstance3D:
			var mi := nd as MeshInstance3D
			k = mi.mesh.resource_path.get_file() if mi.mesh and mi.mesh.resource_path != "" else (("%s %s" % [mi.mesh.get_class(), String(nd.name).substr(0, 8)]) if mi.mesh else "?")
			k = k.substr(0, 40)
			if k.begins_with("BoxMesh") or k.begins_with("Sphere") or k.begins_with("Capsule"):
				k = "%s col=%s par=%s/%s sz=%s" % [k.substr(0, 8), (mi.material_override as StandardMaterial3D).albedo_color.to_html().substr(0, 6) if mi.material_override is StandardMaterial3D else "x", str(nd.get_parent().get_class()), str(nd.get_parent().get_parent().name).substr(0, 10) if nd.get_parent().get_parent() else "", str(mi.get_aabb().size.snapped(Vector3.ONE * 0.5))] + " meta=%s kids=%d vis_end=%.0f" % [str(mi.get_meta_list()), mi.get_child_count(), mi.visibility_range_end]
			if k.begins_with("ArrayMesh @"):
				var a: Node = nd; var why := ""
				while a and a != town:
					if a.has_meta("nomerge"): why += "nomerge "
					if a.has_meta("kind"): why += "kind:%s " % str(a.get_meta("kind"))
					if a.has_meta("flatpack"): why += "flat "
					if String(a.name).begins_with("Block_"): break
					a = a.get_parent()
				var mn := ""
				if mi.mesh.get_surface_count() > 0 and mi.mesh.surface_get_material(0): mn = mi.mesh.surface_get_material(0).resource_name
				var gp: Node = nd.get_parent().get_parent()
				var vc: int = mi.mesh.surface_get_array_len(0) if mi.mesh.get_surface_count() > 0 else 0
				k = "AM gp=%s/%s v=%s sc=%s mat=%s" % [str(gp.get_parent().name).substr(0, 12) if gp and gp.get_parent() else "", str(gp.name).substr(0, 14) if gp else "", str(mini(vc, 9999) / 100 * 100), str(mi.scale.snapped(Vector3.ONE * 0.5)), (mi.material_override as StandardMaterial3D).albedo_color.to_html().substr(0, 6) if mi.material_override is StandardMaterial3D else "x"]
		else: k = "MULTI " + str(nd.name)
		var surf: int = ((nd as MeshInstance3D).mesh.get_surface_count() if nd is MeshInstance3D and (nd as MeshInstance3D).mesh else 1)
		cnt[k] = int(cnt.get(k, 0)) + surf; total += surf
	var ks: Array = cnt.keys(); ks.sort_custom(func(a, b): return cnt[a] > cnt[b])
	print("PD visible surfaces ~%d, draws=%d" % [total, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	for k in ks.slice(0, 30): print("PD %5d %s" % [cnt[k], k])
	quit()
