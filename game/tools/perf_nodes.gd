extends SceneTree
## 매 프레임 도는 노드 세기 — 스크립트(또는 클래스)별 process/physics 노드 수
func _init() -> void:
	var town: Node3D = (load("res://scenes/town3d.tscn") as PackedScene).instantiate(); root.add_child(town)
	for i in 60: await process_frame
	var proc := {}; var phys := {}
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		var key: String = n.get_script().resource_path.get_file() if n.get_script() else n.get_class()
		if n.is_processing(): proc[key] = int(proc.get(key, 0)) + 1
		if n.is_physics_processing(): phys[key] = int(phys.get(key, 0)) + 1
	var pk := proc.keys(); pk.sort_custom(func(a, b): return proc[a] > proc[b])
	var fk := phys.keys(); fk.sort_custom(func(a, b): return phys[a] > phys[b])
	print("PROC ", ", ".join(pk.slice(0, 12).map(func(k): return "%s=%d" % [k, proc[k]])))
	print("PHYS ", ", ".join(fk.slice(0, 12).map(func(k): return "%s=%d" % [k, phys[k]])))
	quit()
